"""Execute the real reporting/runner code with all external commands replaced."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def quoted(path):
    return "'" + str(path).replace("'", "''") + "'"


class LocalGateReportingTest(unittest.TestCase):
    def run_fixture(self, body):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            report = root / "report.json"
            code = "$ErrorActionPreference='Stop'; . " + quoted(ROOT / "tools/testing/local_gate_reporting.ps1") + "; " + body.replace("REPORT_PATH", quoted(report))
            result = subprocess.run(["pwsh", "-NoProfile", "-Command", code], cwd=root, capture_output=True, text=True, encoding="utf-8")
            data = json.loads(report.read_text(encoding="utf-8-sig")) if report.exists() else None
            return result, data

    def test_all_green_requires_every_declared_check_to_pass(self):
        result, data = self.run_fixture("$r=New-LocalGateReport @('a','b'); Set-LocalGateResult $r a passed; Set-LocalGateResult $r b passed; Write-LocalGateReport $r REPORT_PATH")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["summary"], "ALL AUTOMATED LOCAL GATES GREEN")
        self.assertEqual(data["counts"]["passed"], 2)

    def test_skipped_and_untested_are_never_green(self):
        for status in ("skipped", "untested"):
            with self.subTest(status=status):
                change = "Set-LocalGateResult $r b skipped;" if status == "skipped" else ""
                result, data = self.run_fixture("$r=New-LocalGateReport @('a','b'); Set-LocalGateResult $r a passed; " + change + " Write-LocalGateReport $r REPORT_PATH")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(data["summary"], "LOCAL VALIDATION PARTIAL")
                self.assertNotIn("ALL AUTOMATED LOCAL GATES GREEN", result.stdout)
                self.assertEqual(data["counts"][status], 1)

    def test_failure_and_warning_are_distinct(self):
        for status, summary in (("failed", "LOCAL VALIDATION FAILED"), ("warning", "LOCAL REQUIRED CHECKS PASSED WITH WARNINGS")):
            with self.subTest(status=status):
                result, data = self.run_fixture("$r=New-LocalGateReport @('a'); Set-LocalGateResult $r a " + status + "; Write-LocalGateReport $r REPORT_PATH")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(data["summary"], summary)

    def test_recorded_failure_cannot_be_overwritten(self):
        result, _ = self.run_fixture("$r=New-LocalGateReport @('a'); Set-LocalGateResult $r a failed; Set-LocalGateResult $r a passed")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already recorded", result.stderr)

    def actual_runner(self, python_body, dart_body="$global:LASTEXITCODE=0"):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            # These are PowerShell functions, not binaries: no external gate runs.
            commands = "function python { " + python_body + " }; function flutter { $global:LASTEXITCODE=0 }; function dart { " + dart_body + " }; function git { $global:LASTEXITCODE=0 }; function pwsh { $global:LASTEXITCODE=0 }; function npm { throw 'unexpected backend command' }; "
            code = "$ErrorActionPreference='Stop'; " + commands + "& " + quoted(ROOT / "release_gate.ps1") + " -SkipRules -SkipFunctions -SkipBuild -EvidenceRoot " + quoted(root / "evidence") + "; exit $LASTEXITCODE"
            result = subprocess.run(["pwsh", "-NoProfile", "-Command", code], cwd=root, capture_output=True, text=True, encoding="utf-8")
            reports = list(root.rglob("gate-results.json"))
            self.assertEqual(len(reports), 1, result.stderr)
            return result, json.loads(reports[0].read_text(encoding="utf-8-sig"))

    def test_actual_runner_reports_all_six_omitted_gate_groups(self):
        result, data = self.actual_runner("$global:LASTEXITCODE=0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["counts"]["skipped"], 6)
        self.assertEqual(data["counts"]["untested"], 0)
        self.assertEqual(data["summary"], "LOCAL VALIDATION PARTIAL")
        self.assertNotIn("ALL AUTOMATED LOCAL GATES GREEN", result.stdout)

    def test_actual_runner_failure_retains_untested_groups_and_exit(self):
        result, data = self.actual_runner("$global:LASTEXITCODE=19")
        self.assertEqual(result.returncode, 19, result.stderr)
        self.assertEqual(data["steps"]["checked-in source preflight"]["status"], "failed")
        self.assertEqual(data["steps"]["flutter host suite (source contracts + unit + widget)"]["status"], "untested")
        self.assertEqual(data["summary"], "LOCAL VALIDATION FAILED")

    def test_actual_runner_exception_is_failure_not_pass(self):
        result, data = self.actual_runner("throw 'synthetic unavailable tool'")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(data["steps"]["checked-in source preflight"]["status"], "failed")
        self.assertIn("synthetic unavailable tool", data["steps"]["checked-in source preflight"]["detail"])


    def test_actual_runner_persistence_failure_stops_before_flutter_and_build(self):
        result, data = self.actual_runner("$global:LASTEXITCODE=0", "if ($args -contains 'tools/v4/a03_persistence_boundary_inventory.dart') { $global:LASTEXITCODE=23 } else { $global:LASTEXITCODE=0 }")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(data["steps"]["Flutter dependency resolution"]["status"], "passed")
        self.assertEqual(data["steps"]["A03 persistence boundary audit"]["status"], "failed")
        self.assertEqual(data["steps"]["flutter analyze"]["status"], "untested")
        self.assertEqual(data["steps"]["flutter host suite (source contracts + unit + widget)"]["status"], "untested")
        self.assertEqual(data["summary"], "LOCAL VALIDATION FAILED")


if __name__ == "__main__":
    unittest.main()
