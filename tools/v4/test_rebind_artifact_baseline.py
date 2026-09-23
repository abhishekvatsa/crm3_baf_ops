"""Acceptance tests for the artifact baseline re-bind.

Each negative case corresponds to a defect or missing precondition that review
reproduced against the first implementation. Every one of them must fail, and
must fail before anything is written: a refusal that has already rewritten the
approval is the defect, not the refusal.

The fixtures are disposable synthetic Git repositories. Nothing here touches the
real checkout, and nothing here performs a production action.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rebind_artifact_baseline as rebind  # noqa: E402

BUILD = 29
APPROVAL = "release/approvals/build-number-29-successor-approval.json"
OLD_VERSION = "1.0.0-rc.18+28"
NEW_VERSION = "1.0.0-rc.19+29"
PATHS = [
    ".firebaserc", "analysis_options.yaml", "android", "assets", "firebase.json",
    "firestore.rules", "functions", "lib", "package.json", "pubspec.yaml",
    "test", "tools/release",
]
POLICY_SCRIPT_BODY = (
    "$ApprovedArtifactExactSourcePaths = @(\n"
    + "".join(f"  '{p}'\n" for p in PATHS)
    + ")\n"
)


def run(repo: Path, *arguments: str) -> str:
    result = subprocess.run(["git", "-C", str(repo), *arguments],
                            capture_output=True, text=True, check=True)
    return result.stdout.strip()


def write(repo: Path, relative: str, data: object) -> None:
    path = repo / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, (dict, list)):
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    else:
        path.write_text(str(data), encoding="utf-8", newline="\n")


def sha_of(repo: Path, relative: str) -> str:
    return rebind.digest((repo / relative).read_bytes())


class Fixture:
    """A synthetic checkout with a previous baseline A and a target M."""

    def __init__(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="rebind-fixture-"))
        # Manifest and decision live outside the checkout: writing them
        # inside would dirty the tree the tool is required to refuse.
        self.workspace = Path(tempfile.mkdtemp(prefix="rebind-workspace-"))
        run(self.repo, "init", "-q", "-b", "main")
        run(self.repo, "config", "user.email", "fixture@example.invalid")
        run(self.repo, "config", "user.name", "Fixture")
        run(self.repo, "remote", "add", "origin",
            "https://github.com/abhishekvatsa/crm3_baf_ops.git")

        for path in PATHS:
            if path in ("pubspec.yaml",):
                continue
            if path == "tools/release":
                write(self.repo, "tools/release/Test-ProductionReleasePolicy.ps1",
                      POLICY_SCRIPT_BODY)
            else:
                write(self.repo, f"{path}/keep.txt" if "." not in Path(path).name
                      else path, "content\n")
        write(self.repo, "pubspec.yaml",
              f"name: crm3\nversion: {OLD_VERSION}\nenvironment:\n  sdk: '>=3.0.0'\n")
        self._records(baseline_commit=None)
        run(self.repo, "add", "-A")
        run(self.repo, "commit", "-qm", "A")
        first = run(self.repo, "rev-parse", "HEAD")
        self._records(baseline_commit=first)
        run(self.repo, "add", "-A")
        run(self.repo, "commit", "-qm", "record baseline A")

    def _records(self, baseline_commit: str | None) -> None:
        commit = baseline_commit or "0" * 40
        tree = "1" * 40
        approval = {
            "schemaVersion": 1,
            "approved": True,
            "sourceBaseline": {"commit": commit, "tree": tree},
        }
        write(self.repo, APPROVAL, approval)
        approval_sha = sha_of(self.repo, APPROVAL)
        write(self.repo, rebind.POLICY, {
            "release": {"buildNumber": BUILD},
            "versionPolicy": {"buildNumber": BUILD, "sourceDocumentFile": APPROVAL,
                              "sourceDocumentSha256": approval_sha},
        })
        write(self.repo, rebind.VERSION_POINTER, {
            "buildNumber": BUILD, "versionName": "1.0.0-rc.19",
            "sourceDocumentFile": APPROVAL, "sourceDocumentSha256": approval_sha,
        })
        write(self.repo, rebind.LEDGER, {"entries": [
            {"buildNumber": 28, "status": "remote-consumed-artifact-built-finalized-non-distributable"},
            {"buildNumber": BUILD, "status": "source-reserved-awaiting-remote-consumption",
             "versionApprovalDocumentSha256": approval_sha, "baselineCommit": commit},
        ]})
        write(self.repo, rebind.STATE, {
            "status": "BUILD29_SOURCE_SUCCESSOR_BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND",
            "authorityPlanes": {
                "currentSource": {"artifactConstructionAuthority": False},
                "deployedBackend": {"functionFleetSourceCommit": "d" * 40},
                "nextCandidate": {"status": "SOURCE_SUCCESSOR_AWAITING_BUILD29_ARTIFACT_SOURCE_REBIND"},
            },
        })

    def make_target(self, mutate=None) -> str:
        write(self.repo, "pubspec.yaml",
              f"name: crm3\nversion: {NEW_VERSION}\nenvironment:\n  sdk: '>=3.0.0'\n")
        write(self.repo, "test/keep.txt", "reviewed test change\n")
        if mutate:
            mutate(self.repo)
        run(self.repo, "add", "-A")
        run(self.repo, "commit", "-qm", "M")
        head = run(self.repo, "rev-parse", "HEAD")
        run(self.repo, "update-ref", "refs/remotes/origin/main", head)
        return head

    @property
    def previous(self) -> str:
        approval = json.loads((self.repo / APPROVAL).read_text(encoding="utf-8"))
        return approval["sourceBaseline"]["commit"]

    def manifest(self, target: str) -> str:
        paths = {}
        for path in PATHS:
            if path == "pubspec.yaml":
                continue
            before = subprocess.run(["git", "-C", str(self.repo), "rev-parse", "--verify",
                                     f"{self.previous}:{path}"], capture_output=True, text=True)
            after = subprocess.run(["git", "-C", str(self.repo), "rev-parse", "--verify",
                                    f"{target}:{path}"], capture_output=True, text=True)
            b = before.stdout.strip() if before.returncode == 0 else None
            a = after.stdout.strip() if after.returncode == 0 else None
            if b != a:
                paths[path] = {"before": b, "after": a}
        path = self.workspace / "delta.json"
        path.write_text(json.dumps(
            {"fromCommit": self.previous, "toCommit": target, "paths": paths},
            indent=2), encoding="utf-8", newline="\n")
        return str(path)

    def decision(self, target: str, **overrides) -> str:
        document = {
            "documentType": "governed-artifact-source-rebind-decision",
            "confirmed": True,
            "previousBaselineCommit": self.previous,
            "targetCommit": target,
            "sourceApprovalSha256AtDecision": sha_of(self.repo, APPROVAL),
            "deployedBackendCommit": "d" * 40,
            "custodyPath": "release/approvals/fixture-rebind-decision.json",
            "ownerConfirmation": {
                "confirmed": True,
                "confirmedByName": "Fixture Owner",
                "ownerStatementInOwnWords": "I confirm the fixture target as the baseline",
                "confirmedAtUtc": "2026-09-23T00:00:00.000Z",
            },
        }
        document.update(overrides)
        path = self.workspace / "decision.json"
        path.write_text(json.dumps(document, indent=2), encoding="utf-8", newline="\n")
        return str(path)

    def evidence(self, target: str, conclusion: str = "success") -> str:
        path = self.workspace / "postmerge.json"
        path.write_text(json.dumps(
            {"runId": 1234567, "headSha": target, "conclusion": conclusion},
            indent=2), encoding="utf-8", newline="\n")
        return str(path)

    def close(self) -> None:
        shutil.rmtree(self.repo, ignore_errors=True)
        shutil.rmtree(self.workspace, ignore_errors=True)


class RebindTests(unittest.TestCase):
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

    # --- the supported transition ------------------------------------------

    def test_valid_transition_is_proposed_and_every_pointer_follows(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target)
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        expected = proposal["approvalDigest"]
        self.assertEqual(rebind.digest(proposal["files"][APPROVAL]), expected)
        for record in (rebind.POLICY, rebind.VERSION_POINTER, rebind.LEDGER):
            self.assertIn(expected.encode(), proposal["files"][record],
                          f"{record} does not carry the proposed approval digest")
        self.assertEqual(len(proposal["files"]), 5)

    def test_a_written_proposal_is_coherent_and_touches_nothing_active(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target, decision=self.fixture.decision(target),
                              evidence=self.fixture.evidence(target))
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        before = {name: (self.fixture.repo / name).read_bytes()
                  for name in proposal["files"]}
        out = self.fixture.workspace / "proposal"
        manifest = rebind.write_proposal(inputs, proposal, str(out))

        applied = manifest["sourceApprovalShaAfter"]
        policy = json.loads((out / rebind.POLICY).read_text(encoding="utf-8"))
        pointer = json.loads((out / rebind.VERSION_POINTER).read_text(encoding="utf-8"))
        ledger = json.loads((out / rebind.LEDGER).read_text(encoding="utf-8"))
        self.assertEqual(policy["versionPolicy"]["sourceDocumentSha256"], applied)
        self.assertEqual(pointer["sourceDocumentSha256"], applied)
        entry = next(e for e in ledger["entries"] if e["buildNumber"] == BUILD)
        self.assertEqual(entry["versionApprovalDocumentSha256"], applied)
        # the decision travels with the proposal at its custody path
        self.assertTrue((out / "release/approvals/fixture-rebind-decision.json").is_file())
        # and nothing in the checkout moved
        for name, data in before.items():
            self.assertEqual((self.fixture.repo / name).read_bytes(), data,
                             name + " was modified; the tool must not write to the checkout")

    # --- finding 1: every active pointer must follow ------------------------

    def test_a_stale_pointer_is_detected_before_anything_is_written(self):
        target = self.fixture.make_target()
        inputs = self.inspect(target)
        for record in (rebind.POLICY, rebind.VERSION_POINTER, rebind.LEDGER):
            proposal = rebind.build_proposal(inputs)
            document = json.loads(proposal["files"][record])
            if record is rebind.LEDGER:
                for entry in document["entries"]:
                    if entry.get("buildNumber") == BUILD:
                        entry["versionApprovalDocumentSha256"] = "0" * 64
            elif record is rebind.POLICY:
                document["versionPolicy"]["sourceDocumentSha256"] = "0" * 64
            else:
                document["sourceDocumentSha256"] = "0" * 64
            proposal["files"][record] = rebind.serialise(document)
            with self.assertRaises(rebind.RebindRefused, msg=f"{record} stale pin accepted"):
                rebind.validate_proposal(inputs, proposal)

    # --- finding 2: compare the source before adopting it -------------------

    def test_non_version_pubspec_change_is_refused(self):
        def mutate(repo):
            write(repo, "pubspec.yaml",
                  f"name: crm3\nversion: {NEW_VERSION}\nenvironment:\n  sdk: '>=3.0.0'\n"
                  "flutter:\n  uses-material-design: true\n")
        target = self.fixture.make_target(mutate)
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("pubspec", str(refusal.exception))

    def test_wrong_target_version_is_refused(self):
        def mutate(repo):
            write(repo, "pubspec.yaml",
                  "name: crm3\nversion: 9.9.9+99\nenvironment:\n  sdk: '>=3.0.0'\n")
        target = self.fixture.make_target(mutate)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    def test_change_outside_the_declared_delta_is_refused(self):
        target = self.fixture.make_target(
            lambda repo: write(repo, "lib/keep.txt", "unreviewed application change\n"))
        manifest = self.fixture.manifest(target)
        document = json.loads(Path(manifest).read_text(encoding="utf-8"))
        document["paths"].pop("lib", None)
        Path(manifest).write_text(json.dumps(document, indent=2), encoding="utf-8", newline="\n")
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target, manifest)
        self.assertIn("delta", str(refusal.exception))

    def test_unreviewed_change_inside_a_permitted_directory_is_refused(self):
        target = self.fixture.make_target(
            lambda repo: write(repo, "tools/release/Test-ProductionReleasePolicy.ps1",
                               POLICY_SCRIPT_BODY + "# an unreviewed gate change\n"))
        manifest = self.fixture.manifest(target)
        document = json.loads(Path(manifest).read_text(encoding="utf-8"))
        document["paths"]["tools/release"]["after"] = "0" * 40
        Path(manifest).write_text(json.dumps(document, indent=2), encoding="utf-8", newline="\n")
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, manifest)

    def test_a_deleted_test_tree_is_refused(self):
        def mutate(repo):
            shutil.rmtree(repo / "test")
        target = self.fixture.make_target(mutate)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    # --- finding 3: lifecycle and generation, before any write --------------

    def test_duplicate_ledger_entries_are_refused(self):
        ledger = json.loads((self.fixture.repo / rebind.LEDGER).read_text(encoding="utf-8"))
        ledger["entries"].append(dict(ledger["entries"][-1]))
        write(self.fixture.repo, rebind.LEDGER, ledger)
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", "duplicate")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("exactly one ledger entry", str(refusal.exception))

    def test_a_consumed_build_is_refused(self):
        ledger = json.loads((self.fixture.repo / rebind.LEDGER).read_text(encoding="utf-8"))
        for entry in ledger["entries"]:
            if entry["buildNumber"] == BUILD:
                entry["status"] = "remote-consumed-artifact-built-finalized-non-distributable"
                entry["githubArtifactId"] = 123
        write(self.fixture.repo, rebind.LEDGER, ledger)
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", "consumed")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    def test_a_state_not_awaiting_rebind_is_refused(self):
        state = json.loads((self.fixture.repo / rebind.STATE).read_text(encoding="utf-8"))
        state["status"] = "BUILD29_SOURCE_AUTHORIZED_BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION"
        write(self.fixture.repo, rebind.STATE, state)
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", "already authorized")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    def test_a_mismatched_generation_is_refused(self):
        pointer = json.loads((self.fixture.repo / rebind.VERSION_POINTER).read_text(encoding="utf-8"))
        pointer["buildNumber"] = 30
        write(self.fixture.repo, rebind.VERSION_POINTER, pointer)
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", "wrong generation")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target)

    def test_an_already_incoherent_starting_state_is_refused(self):
        policy = json.loads((self.fixture.repo / rebind.POLICY).read_text(encoding="utf-8"))
        policy["versionPolicy"]["sourceDocumentSha256"] = "0" * 64
        write(self.fixture.repo, rebind.POLICY, policy)
        run(self.fixture.repo, "add", "-A")
        run(self.fixture.repo, "commit", "-qm", "incoherent start")
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("pin the source approval", str(refusal.exception))

    # --- decision integrity --------------------------------------------------

    def test_emitting_a_proposal_without_a_decision_is_refused(self):
        target = self.fixture.make_target()
        code = rebind.main(["--target-commit", target,
                            "--expected-delta", self.fixture.manifest(target),
                            "--main-ref", "refs/remotes/origin/main",
                            "--out", str(self.fixture.workspace / "p")])
        self.assertEqual(code, 1)

    def test_a_decision_for_another_target_is_refused(self):
        target = self.fixture.make_target()
        decision = self.fixture.decision(target, targetCommit="9" * 40)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=decision)

    def test_an_unconfirmed_decision_is_refused(self):
        target = self.fixture.make_target()
        decision = self.fixture.decision(target, confirmed=False)
        with self.assertRaises(rebind.RebindRefused):
            self.inspect(target, decision=decision)

    # --- write safety --------------------------------------------------------

    def test_the_tool_has_no_in_place_writer(self):
        # Three review rounds found an in-place writer unsafe in a different way
        # each time. Its absence is the fix, so it is asserted.
        self.assertFalse(hasattr(rebind, "emit_proposal"),
                         "an in-place writer has been reintroduced")
        source = (Path(rebind.__file__)).read_text(encoding="utf-8")
        self.assertNotIn("os.replace", source)

    def test_a_dirty_working_tree_is_refused(self):
        target = self.fixture.make_target()
        (self.fixture.repo / "lib" / "keep.txt").write_text("dirty\n", encoding="utf-8")
        with self.assertRaises(rebind.RebindRefused) as refusal:
            self.inspect(target)
        self.assertIn("clean", str(refusal.exception))


if __name__ == "__main__":
    unittest.main()
