import contextlib
import io
import json
from pathlib import Path
import re
import subprocess
import unittest
from unittest.mock import patch

import run_source_preflight as preflight

ROOT = Path(__file__).resolve().parents[2]


class SourcePreflightTest(unittest.TestCase):
    def test_actual_checks_are_fixed_and_do_not_install_or_build(self):
        checks = preflight.commands()
        self.assertEqual(len(checks), 9)
        self.assertIn("tools/v4/a02_architecture_inventory.py", checks[3][1])
        self.assertIn("tools/isar/verify_v4_isar_schema.py", checks[0][1])
        self.assertIn("--release", checks[0][1])
        self.assertIn("tools/testing/verify_test_evidence_taxonomy.py", checks[2][1])
        for _, argv in checks:
            self.assertNotIn("ci", argv)
            self.assertNotIn("install", argv)
            self.assertNotIn("flutter", argv)
            self.assertNotIn("deploy", argv)

    def run_fake(self, returns):
        output = io.StringIO()
        with patch.object(preflight.subprocess, "run", side_effect=returns) as run, contextlib.redirect_stdout(output):
            code = preflight.main()
        return code, run, json.loads(output.getvalue().splitlines()[-1])

    def test_every_success_is_required(self):
        code, run, report = self.run_fake([subprocess.CompletedProcess([], 0)] * 9)
        self.assertEqual(code, 0)
        self.assertEqual(run.call_count, 9)
        self.assertEqual([x["status"] for x in report["checks"]], ["passed"] * 9)
        self.assertIn("distribution", report["notEstablished"])

    def test_failure_stops_before_expensive_or_later_checks(self):
        code, run, report = self.run_fake([subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 17)])
        self.assertEqual(code, 17)
        self.assertEqual(run.call_count, 2)
        self.assertEqual([x["status"] for x in report["checks"]], ["passed", "failed"] + ["untested"] * 7)

    def test_architecture_failure_leaves_later_checks_untested(self):
        code, run, report = self.run_fake([subprocess.CompletedProcess([], 0)] * 3 + [subprocess.CompletedProcess([], 31)])
        self.assertEqual(code, 31)
        self.assertEqual(run.call_count, 4)
        self.assertEqual([x["status"] for x in report["checks"]], ["passed"] * 3 + ["failed"] + ["untested"] * 5)
        self.assertEqual(report["checks"][3]["name"], "Architecture ownership inventory")
        self.assertIn("dependency-ready A03 persistence audit", report["notEstablished"])

    def test_unavailable_tool_is_a_failure_not_skip(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code, run, report = self.run_fake([FileNotFoundError("synthetic missing tool")])
        self.assertEqual(code, 1)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(report["checks"][0]["status"], "failed")

    def test_all_five_jobs_gate_before_setup_with_same_names(self):
        workflow = (ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8")
        sections = re.split(r"(?m)^  ([a-z][a-z-]+):\s*$", workflow.split("jobs:", 1)[1])
        jobs = dict(zip(sections[1::2], sections[2::2]))
        self.assertEqual(set(jobs), {"flutter-gates", "android-package", "android-emulator", "firestore-rules", "functions"})
        for job, text in jobs.items():
            with self.subTest(job=job):
                steps = re.findall(r"(?m)^      - name: (.+)$", text)
                self.assertEqual(steps[:2], ["Checkout", "Cheap checked-in source preflight (no install or device)"])
                self.assertEqual(text.count("run: python3 tools/testing/run_source_preflight.py"), 1)
                self.assertNotIn("continue-on-error: true", text)


    def assert_dependency_ready_audit_order(self, workflow):
        sections = re.split(r"(?m)^  ([a-z][a-z-]+):\s*$", workflow.split("jobs:", 1)[1])
        jobs = dict(zip(sections[1::2], sections[2::2]))
        for job, expensive in (("flutter-gates", "Regenerate current Isar bindings"),
                               ("android-package", "Build and verify secret-isolated release packages"),
                               ("android-emulator", "Prepare the pinned local business backend")):
            steps = re.findall(r"(?m)^      - name: (.+)$", jobs[job])
            self.assertIn("Install Flutter dependencies", steps)
            self.assertIn("Persistence boundary audit before construction", steps)
            self.assertLess(steps.index("Install Flutter dependencies"), steps.index("Persistence boundary audit before construction"))
            self.assertLess(steps.index("Persistence boundary audit before construction"), steps.index(expensive))
            self.assertEqual(jobs[job].count("run: dart run tools/v4/a03_persistence_boundary_inventory.dart"), 1)
        for job in ("firestore-rules", "functions"):
            self.assertNotIn("a03_persistence_boundary_inventory.dart", jobs[job])

    def test_dependency_ready_audit_precedes_each_flutter_construction_path(self):
        self.assert_dependency_ready_audit_order((ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8"))
        local = (ROOT / "release_gate.ps1").read_text(encoding="utf-8")
        self.assertLess(local.index('Run-Gate "Flutter dependency resolution"'), local.index('Run-Gate "A03 persistence boundary audit"'))
        self.assertLess(local.index('Run-Gate "A03 persistence boundary audit"'), local.index('Run-Gate "flutter analyze"'))

    def test_missing_or_late_dependency_audit_is_rejected(self):
        workflow = (ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8")
        block = "      - name: Persistence boundary audit before construction\n        run: dart run tools/v4/a03_persistence_boundary_inventory.dart\n"
        for broken in (workflow.replace(block, "", 1),
                       workflow.replace(block, "", 1).replace("      - name: Regenerate current Isar bindings", "      - name: Regenerate current Isar bindings\n" + block, 1)):
            with self.subTest(broken=broken[:40]), self.assertRaises(AssertionError):
                self.assert_dependency_ready_audit_order(broken)


if __name__ == "__main__":
    unittest.main()
