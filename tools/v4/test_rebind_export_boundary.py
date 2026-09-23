"""The proposal exporter must not write outside its own directory.

Review reproduced two ways it did: a custody path whose parent components
reached back into the checkout and overwrote an active record while the tool
reported activeRecordsUnchanged, and a custody path equal to a proposed
record's path, which overwrote that record and left the manifest
self-consistent while the cross-record references were broken.

Both must be refused before a single file is created.
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rebind_artifact_baseline as rebind  # noqa: E402
from test_rebind_artifact_baseline import APPROVAL, Fixture  # noqa: E402

INTRUDER_BYTES = b"written by another process\n"


class ExportBoundary(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = Fixture()
        self._root = rebind.ROOT
        rebind.ROOT = self.fixture.repo
        self.out = self.fixture.workspace / "proposal"

    def tearDown(self) -> None:
        rebind.ROOT = self._root
        self.fixture.close()

    def prepared(self, **decision_overrides):
        target = self.fixture.make_target()
        inputs = rebind.inspect_inputs(
            target, self.fixture.manifest(target),
            self.fixture.decision(target, **decision_overrides),
            self.fixture.evidence(target), "refs/remotes/origin/main")
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        return inputs, proposal

    def assert_nothing_written(self):
        if self.out.exists():
            self.assertEqual(list(self.out.rglob("*")), [],
                             "files were created despite the refusal")

    # --- escaping the proposal directory ------------------------------------

    def test_a_traversing_custody_path_is_refused(self):
        escape = "release/approvals/../../../../escaped.json"
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused) as refusal:
            rebind.inspect_inputs(
                target, self.fixture.manifest(target),
                self.fixture.decision(target, custodyPath=escape),
                self.fixture.evidence(target), "refs/remotes/origin/main")
        self.assertIn("parent or current directory components", str(refusal.exception))

    def test_a_traversing_custody_path_cannot_reach_an_active_record(self):
        # the exact shape review used: a custody path leading back to a live record
        escape = "release/approvals/../current-successor-state.json"
        target = self.fixture.make_target()
        state_before = (self.fixture.repo / rebind.STATE).read_bytes()
        with self.assertRaises(rebind.RebindRefused):
            rebind.inspect_inputs(
                target, self.fixture.manifest(target),
                self.fixture.decision(target, custodyPath=escape),
                self.fixture.evidence(target), "refs/remotes/origin/main")
        self.assertEqual((self.fixture.repo / rebind.STATE).read_bytes(), state_before,
                         "an active record was written during a refused export")
        self.assert_nothing_written()

    def test_an_absolute_custody_path_is_refused(self):
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            rebind.inspect_inputs(
                target, self.fixture.manifest(target),
                self.fixture.decision(target, custodyPath="/etc/passwd.json"),
                self.fixture.evidence(target), "refs/remotes/origin/main")

    # --- colliding inside the proposal directory ----------------------------

    def test_a_custody_path_colliding_with_a_proposed_record_is_refused(self):
        inputs, proposal = self.prepared(custodyPath=APPROVAL)
        with self.assertRaises(rebind.RebindRefused) as refusal:
            rebind.write_proposal(inputs, proposal, str(self.out))
        self.assertIn("already claims", str(refusal.exception))
        self.assert_nothing_written()

    def test_a_custody_path_claiming_the_manifest_name_is_refused(self):
        target = self.fixture.make_target()
        with self.assertRaises(rebind.RebindRefused):
            rebind.inspect_inputs(
                target, self.fixture.manifest(target),
                self.fixture.decision(target, custodyPath="PROPOSAL.json"),
                self.fixture.evidence(target), "refs/remotes/origin/main")

    # --- the decision bytes that were validated ------------------------------

    def test_a_decision_changed_after_validation_is_refused(self):
        target = self.fixture.make_target()
        decision_path = self.fixture.decision(target)
        inputs = rebind.inspect_inputs(
            target, self.fixture.manifest(target), decision_path,
            self.fixture.evidence(target), "refs/remotes/origin/main")
        proposal = rebind.build_proposal(inputs)
        rebind.validate_proposal(inputs, proposal)
        # someone edits the external decision between validation and export
        document = json.loads(Path(decision_path).read_text(encoding="utf-8"))
        document["ownerConfirmation"]["confirmed"] = False
        Path(decision_path).write_text(json.dumps(document, indent=2),
                                       encoding="utf-8", newline="\n")
        with self.assertRaises(rebind.RebindRefused) as refusal:
            rebind.write_proposal(inputs, proposal, str(self.out))
        self.assertIn("changed after it was validated", str(refusal.exception))
        self.assert_nothing_written()

    def test_the_exported_decision_is_the_validated_snapshot(self):
        inputs, proposal = self.prepared()
        manifest = rebind.write_proposal(inputs, proposal, str(self.out))
        custody = manifest["decisionCustodyPath"]
        exported = (self.out / custody).read_bytes()
        self.assertEqual(rebind.digest(exported), inputs["decisionDigest"],
                         "the exported decision is not the one that was validated")
        self.assertEqual(manifest["proposedSha256"][custody], inputs["decisionDigest"])

    # --- exclusive creation --------------------------------------------------

    def test_a_destination_appearing_after_preflight_is_not_overwritten(self):
        """Review showed this case can be tested, so the earlier gap is closed.

        The output map is assembled, then something else creates one of the
        intended destinations. Exclusive creation must refuse rather than
        overwrite it, and the other process's bytes must survive.
        """
        inputs, proposal = self.prepared()
        intruder = self.out / APPROVAL
        real_serialise = rebind.serialise

        def serialise_then_intrude(document):
            data = real_serialise(document)
            if not intruder.exists():
                intruder.parent.mkdir(parents=True, exist_ok=True)
                intruder.write_bytes(INTRUDER_BYTES)
            return data

        rebind.serialise = serialise_then_intrude
        try:
            with self.assertRaises(FileExistsError):
                rebind.write_proposal(inputs, proposal, str(self.out))
        finally:
            rebind.serialise = real_serialise
        self.assertEqual(intruder.read_bytes(), INTRUDER_BYTES,
                         "another process's file was overwritten")

    # --- the ordinary case still works --------------------------------------

    def test_a_normal_proposal_is_written_whole(self):
        inputs, proposal = self.prepared()
        manifest = rebind.write_proposal(inputs, proposal, str(self.out))
        written = sorted(p.relative_to(self.out).as_posix()
                         for p in self.out.rglob("*") if p.is_file())
        self.assertIn("PROPOSAL.json", written)
        self.assertIn(manifest["decisionCustodyPath"], written)
        for record in proposal["files"]:
            self.assertIn(record, written)
        for path, expected in manifest["proposedSha256"].items():
            self.assertEqual(rebind.digest((self.out / path).read_bytes()), expected)
        self.assertEqual(manifest["status"], "PROPOSAL_ONLY_NOT_APPLIED")


if __name__ == "__main__":
    unittest.main()
