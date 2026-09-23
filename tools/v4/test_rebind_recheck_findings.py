"""The four boundaries the second review round found still open.

Each test corresponds to a behaviour that was reproduced against the previous
implementation: a candidate choosing its own inspection scope, a decision that
left no trace in the output, a failure part-way through replacement, and
lifecycle checks that accepted contradictory states.
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rebind_artifact_baseline as rebind  # noqa: E402
from test_rebind_artifact_baseline import (  # noqa: E402
    APPROVAL, BUILD, PATHS, Fixture, run, sha_of, write,
)


class RecheckFindings(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = Fixture()
        self._root = rebind.ROOT
        rebind.ROOT = self.fixture.repo

    def tearDown(self) -> None:
        rebind.ROOT = self._root
        self.fixture.close()

    def inspect(self, target, manifest=None, decision=None, evidence=None):
        return rebind.inspect_inputs(
            target, manifest or self.fixture.manifest(target), decision, evidence,
            "refs/remotes/origin/main")

    def read(self, relative):
        return json.loads((self.fixture.repo / relative).read_text(encoding="utf-8"))

    def commit(self, message):
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", message)

    # --- 1. trusted source inspection ---------------------------------------

    def test_a_candidate_cannot_narrow_the_inspected_path_list(self):
        def mutate(repo):
            # Change an application file, then drop lib from the candidate's own
            # protected-path list. A tool that trusts the candidate's list would
            # never look at lib and would report a clean delta.
            write(repo, "lib/keep.txt", "unreviewed application change")
            narrowed = [p for p in PATHS if p != "lib"]
            body = "$ApprovedArtifactExactSourcePaths = @(" + os.linesep
            body = "$ApprovedArtifactExactSourcePaths = @(\n"
            for path in narrowed:
                body += "  '" + path + "'\n"
            body += ")\n"
            write(repo, "tools/release/Test-ProductionReleasePolicy.ps1", body)

        target = self.fixture.make_target(mutate)
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("removes protected artifact source paths", str(refusal.exception))

    def test_the_approved_list_governs_the_inspection(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target)
        self.assertIn("lib", inputs["inspectedPaths"])
        self.assertIn("functions", inputs["inspectedPaths"])

    # --- 2. retained decision authority -------------------------------------

    def test_the_decision_is_recorded_into_the_approval(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target, decision=self.fixture.decision(target))
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        recorded = json.loads(proposal["files"][APPROVAL])["artifactBaselineRebind"]
        self.assertEqual(recorded["decisionSha256"], inputs["decisionDigest"])
        self.assertEqual(recorded["targetCommit"], target)
        self.assertEqual(recorded["ownerStatementInOwnWords"],
                         "I confirm the fixture target as the baseline")
        self.assertEqual(recorded["deployedBackendCommitUnchanged"], inputs["deployed"])

    def test_the_proposal_differs_with_and_without_a_decision(self):
        target = self.fixture.make_target()
        without = rebind.build_proposal(self.inspect(target))
        with_decision = rebind.build_proposal(
            self.inspect(target, decision=self.fixture.decision(target)))
        self.assertNotEqual(
            without["files"][APPROVAL], with_decision["files"][APPROVAL],
            "the decision leaves no trace in the emitted approval")
        self.assertNotEqual(without["approvalDigest"], with_decision["approvalDigest"])

    def test_emitting_a_proposal_requires_post_merge_evidence(self):
        target = self.fixture.make_target()
        code = rebind.main(["--target-commit", target,
                            "--expected-delta", self.fixture.manifest(target),
                            "--decision", self.fixture.decision(target),
                            "--main-ref", "refs/remotes/origin/main",
                            "--out", str(self.fixture.workspace / "p")])
        self.assertEqual(code, 1)

    def test_failed_post_merge_checks_are_refused(self):
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=self.fixture.decision(target),
                         evidence=self.fixture.evidence(target, conclusion="failure"))

    def test_a_target_off_the_main_line_is_refused(self):
        target = self.fixture.make_target()
        run(self.fixture.repo, "update-ref", "refs/remotes/origin/main",
            self.fixture.previous)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    # --- 3. safe publication -------------------------------------------------

    def test_the_proposal_never_writes_to_the_checkout(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target, decision=self.fixture.decision(target),
                              evidence=self.fixture.evidence(target))
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        before = {name: (self.fixture.repo / name).read_bytes()
                  for name in proposal["files"]}
        rebind.write_proposal(inputs, proposal,
                              str(self.fixture.workspace / "proposal"))
        for name, data in before.items():
            self.assertEqual((self.fixture.repo / name).read_bytes(), data,
                             name + " was written; the tool must not touch active records")

    def test_the_proposal_directory_must_be_fresh(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target, decision=self.fixture.decision(target),
                              evidence=self.fixture.evidence(target))
        proposal = rebind.build_proposal(inputs)
        out = self.fixture.workspace / "proposal"
        out.mkdir(parents=True, exist_ok=True)
        (out / "something.txt").write_text("existing", encoding="utf-8")
        with self.assertRaises(rebind.RebindRefused):
            rebind.write_proposal(inputs, proposal, str(out))

    # --- decision provenance -------------------------------------------------

    def test_a_contradictory_owner_confirmation_is_refused(self):
        target = self.fixture.make_target()
        decision = self.fixture.decision(
            target, ownerConfirmation={"confirmed": False,
                                       "ownerStatementInOwnWords": "looks fine",
                                       "confirmedAtUtc": "2026-09-23T00:00:00.000Z"})
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target, decision=decision)
        self.assertIn("confirmed true", str(refusal.exception))

    def test_an_invalid_confirmation_time_is_refused(self):
        target = self.fixture.make_target()
        decision = self.fixture.decision(
            target, ownerConfirmation={"confirmed": True,
                                       "ownerStatementInOwnWords": "I confirm",
                                       "confirmedAtUtc": "not-a-timestamp"})
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=decision)

    def test_a_decision_without_a_custody_path_is_refused(self):
        target = self.fixture.make_target()
        decision = self.fixture.decision(target, custodyPath=None)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=decision)

    def test_a_tampered_annotation_is_refused(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target, decision=self.fixture.decision(target),
                              evidence=self.fixture.evidence(target))
        proposal = rebind.build_proposal(inputs)
        approval = json.loads(proposal["files"][APPROVAL])
        approval["artifactBaselineRebind"]["ownerStatementInOwnWords"] = "something else"
        approval["artifactBaselineRebind"]["confirmedAtUtc"] = "2020-01-01T00:00:00.000Z"
        proposal["files"][APPROVAL] = rebind.serialise(approval)
        tampered = rebind.digest(proposal["files"][APPROVAL])
        proposal["approvalDigest"] = tampered
        # recompute the ordinary pointers so every coherence check still passes and
        # only the annotation comparison can refuse it
        policy = json.loads(proposal["files"][rebind.POLICY])
        policy["versionPolicy"]["sourceDocumentSha256"] = tampered
        proposal["files"][rebind.POLICY] = rebind.serialise(policy)
        pointer = json.loads(proposal["files"][rebind.VERSION_POINTER])
        pointer["sourceDocumentSha256"] = tampered
        proposal["files"][rebind.VERSION_POINTER] = rebind.serialise(pointer)
        ledger = json.loads(proposal["files"][rebind.LEDGER])
        for entry in ledger["entries"]:
            if entry.get("buildNumber") == BUILD:
                entry["versionApprovalDocumentSha256"] = tampered
        proposal["files"][rebind.LEDGER] = rebind.serialise(ledger)
        with self.assertRaises(rebind.RebindRefused) as refusal:
            rebind.validate_proposal(inputs, proposal)
        self.assertIn("does not match the decision", str(refusal.exception))

    # --- post-merge evidence -------------------------------------------------

    def test_evidence_without_a_run_identity_is_refused(self):
        target = self.fixture.make_target()
        path = self.fixture.workspace / "thin.json"
        path.write_text(json.dumps({"headSha": target, "conclusion": "success"}),
                        encoding="utf-8")
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target, decision=self.fixture.decision(target),
                         evidence=str(path))
        self.assertIn("run identity", str(refusal.exception))

    def test_evidence_contradicting_itself_is_refused(self):
        target = self.fixture.make_target()
        path = self.fixture.workspace / "contradictory.json"
        path.write_text(json.dumps({
            "headSha": target, "conclusion": "success", "status": "in_progress",
            "runId": 1, "repository": "someone/else",
            "jobs": [{"name": "a job", "conclusion": "failure"}]}), encoding="utf-8")
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=self.fixture.decision(target),
                         evidence=str(path))

    def test_a_local_reference_cannot_stand_in_for_main(self):
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            rebind.inspect_inputs(target, self.fixture.manifest(target), None, None, "HEAD")
        self.assertIn("remote-tracking", str(refusal.exception))

    # --- 4. exact lifecycle validation --------------------------------------

    def test_a_status_for_another_build_is_refused(self):
        state = self.read(rebind.STATE)
        state["status"] = ("BUILD30_SOURCE_SUCCESSOR_BACKEND_READY"
                           "_AWAITING_ARTIFACT_SOURCE_REBIND")
        write(self.fixture.repo, rebind.STATE, state)
        self.commit("a status for another build")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("expected BUILD29", str(refusal.exception))

    def test_a_cancelled_next_candidate_is_refused(self):
        state = self.read(rebind.STATE)
        state["authorityPlanes"]["nextCandidate"]["status"] = "CANCELLED_DO_NOT_CONSTRUCT"
        write(self.fixture.repo, rebind.STATE, state)
        self.commit("a cancelled next candidate")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    def test_an_unapproved_source_approval_is_refused(self):
        approval = self.read(APPROVAL)
        approval["approved"] = False
        write(self.fixture.repo, APPROVAL, approval)
        # keep every pointer coherent, so the refusal is about the approval
        # itself rather than a stale pin
        digest = sha_of(self.fixture.repo, APPROVAL)
        policy = self.read(rebind.POLICY)
        policy["versionPolicy"]["sourceDocumentSha256"] = digest
        write(self.fixture.repo, rebind.POLICY, policy)
        pointer = self.read(rebind.VERSION_POINTER)
        pointer["sourceDocumentSha256"] = digest
        write(self.fixture.repo, rebind.VERSION_POINTER, pointer)
        ledger = self.read(rebind.LEDGER)
        for entry in ledger["entries"]:
            if entry.get("buildNumber") == BUILD:
                entry["versionApprovalDocumentSha256"] = digest
        write(self.fixture.repo, rebind.LEDGER, ledger)
        self.commit("an unapproved source approval")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("approved true", str(refusal.exception))


if __name__ == "__main__":
    unittest.main()
