"""Exercise the actual ultimate-audit basic-ftp guard without running unrelated audits."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "tools/v4/v4_2_ultimate_audit.py"
CANONICAL_AUDIT = ROOT / "tools/v4/v4_2_r1_canonical_audit.py"
FUNCTION_NAME = "basic_ftp_pin_matches"
PINS = {"tooling/firebase-cli/package.json": ()}

KEY = "node_modules/basic-ftp"


class BasicFtpDependencyPolicyTests(unittest.TestCase):
    def setUp(self):
        tree = ast.parse(AUDIT.read_text(encoding="utf-8"))
        guard = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == FUNCTION_NAME)
        self.documents = {}
        for manifest in PINS:
            for rel in (manifest, manifest.replace("package.json", "package-lock.json")):
                self.documents[rel] = json.loads((ROOT / rel).read_text(encoding="utf-8"))
        namespace = {"data": lambda rel: self.documents[rel]}
        exec(compile(ast.Module(body=[guard], type_ignores=[]), str(AUDIT), "exec"), namespace)
        self.guard = namespace[FUNCTION_NAME]

    def check_domain(self, manifest):
        return self.guard()

    def test_current_cli_manifest_is_actually_pinned(self):
        for manifest in PINS:
            with self.subTest(manifest=manifest):
                self.assertTrue(self.check_domain(manifest))

    def assert_cli_lock_bindings(self, workflow, policy):
        expected = re.findall(r'expected_lock_sha="([A-F0-9]{64})"', workflow)
        self.assertEqual(len(expected), 2, "Both emulator jobs must retain their lockfile gate")
        actual = hashlib.sha256((ROOT / "tooling/firebase-cli/package-lock.json").read_bytes()).hexdigest().upper()
        self.assertEqual(expected, [actual, actual], "CI pins must match the committed CLI lockfile")
        self.assertEqual(policy["toolchain"]["firebaseToolsLockfile"], "tooling/firebase-cli/package-lock.json")
        self.assertEqual(policy["toolchain"]["firebaseToolsLockfileSha256"], actual,
                         "Release policy must bind the same CLI lockfile as both CI jobs")

    def test_ci_backend_jobs_bind_the_actual_cli_lockfile_bytes(self):
        workflow = (ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8")
        policy = json.loads((ROOT / "release/production-release-policy.json").read_text(encoding="utf-8"))
        self.assert_cli_lock_bindings(workflow, policy)

    def test_each_single_stale_workflow_copy_is_rejected(self):
        workflow = (ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8")
        policy = json.loads((ROOT / "release/production-release-policy.json").read_text(encoding="utf-8"))
        copies = list(re.finditer(r'expected_lock_sha="([A-F0-9]{64})"', workflow))
        self.assertEqual(len(copies), 2)
        for index, match in enumerate(copies):
            with self.subTest(copy=index):
                changed = workflow[:match.start(1)] + "0" * 64 + workflow[match.end(1):]
                with self.assertRaisesRegex(AssertionError, "CI pins must match"):
                    self.assert_cli_lock_bindings(changed, policy)

    def test_stale_release_policy_is_rejected_with_current_workflow(self):
        workflow = (ROOT / ".github/workflows/release-gate.yml").read_text(encoding="utf-8")
        policy = json.loads((ROOT / "release/production-release-policy.json").read_text(encoding="utf-8"))
        policy["toolchain"]["firebaseToolsLockfileSha256"] = "0" * 64
        with self.assertRaisesRegex(AssertionError, "Release policy must bind"):
            self.assert_cli_lock_bindings(workflow, policy)

    def test_changed_override_or_registry_bytes_fail(self):
        original = copy.deepcopy(self.documents)
        for manifest in PINS:
            for field in ("version", "resolved", "integrity", "override", "missing"):
                with self.subTest(manifest=manifest, field=field):
                    self.documents = copy.deepcopy(original)
                    packages = self.documents[manifest.replace("package.json", "package-lock.json")]["packages"]
                    if field == "override":
                        self.documents[manifest]["overrides"]["basic-ftp"] = "0.0.0-regression"
                    elif field == "missing":
                        for key in list(packages):
                            if key == KEY or key.endswith("/" + KEY):
                                del packages[key]
                    else:
                        packages[KEY][field] = "tampered-regression"
                    self.assertFalse(self.check_domain(manifest))

    def test_extra_nested_vulnerable_copy_cannot_hide_behind_patched_top_level(self):
        original = copy.deepcopy(self.documents)
        for manifest in PINS:
            for field in ("version", "resolved", "integrity"):
                with self.subTest(manifest=manifest, field=field):
                    self.documents = copy.deepcopy(original)
                    packages = self.documents[manifest.replace("package.json", "package-lock.json")]["packages"]
                    nested = copy.deepcopy(packages[KEY])
                    nested[field] = "old-vulnerable-copy"
                    packages["node_modules/fixture/" + KEY] = nested
                    self.assertFalse(self.check_domain(manifest))

    def test_duplicate_matching_copy_and_unrelated_dependency_do_not_false_fail(self):
        for manifest in PINS:
            with self.subTest(manifest=manifest):
                packages = self.documents[manifest.replace("package.json", "package-lock.json")]["packages"]
                packages["node_modules/fixture/" + KEY] = copy.deepcopy(packages[KEY])
                packages["node_modules/other"] = {"version": "0.0.0"}
                self.assertTrue(self.check_domain(manifest))

    def canonical_guard(self):
        tree = ast.parse(CANONICAL_AUDIT.read_text(encoding="utf-8"))
        assignments = []
        collecting = False
        expression = None
        for node in tree.body:
            if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name):
                if node.targets[0].id == "firebase_cli_package":
                    collecting = True
                if collecting:
                    assignments.append(node)
            if collecting and isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
                call = node.value
                if call.args and isinstance(call.args[0], ast.Constant) and call.args[0].value == "Firebase CLI tooling pins only the bounded patched dependency versions":
                    expression = call.args[1]
                    break
        self.assertIsNotNone(expression, "Actual canonical CLI pin check must exist")
        namespace = {"data": lambda rel: self.documents[rel]}
        exec(compile(ast.Module(body=assignments, type_ignores=[]), str(CANONICAL_AUDIT), "exec"), namespace)
        return eval(compile(ast.Expression(body=expression), str(CANONICAL_AUDIT), "eval"), namespace)

    def test_current_cli_also_passes_actual_canonical_check(self):
        self.assertTrue(self.canonical_guard())

    def test_canonical_rejects_changed_cli_basic_ftp_custody_and_nested_copies(self):
        original = copy.deepcopy(self.documents)
        manifest = "tooling/firebase-cli/package.json"
        for field in ("version", "resolved", "integrity", "override", "missing",
                      "nested-version", "nested-resolved", "nested-integrity"):
            with self.subTest(field=field):
                self.documents = copy.deepcopy(original)
                packages = self.documents[manifest.replace("package.json", "package-lock.json")]["packages"]
                if field == "override":
                    self.documents[manifest]["overrides"]["basic-ftp"] = "0.0.0-regression"
                elif field == "missing":
                    del packages[KEY]
                elif field.startswith("nested-"):
                    nested = copy.deepcopy(packages[KEY])
                    nested[field.removeprefix("nested-")] = "tampered-regression"
                    packages["node_modules/fixture/" + KEY] = nested
                else:
                    packages[KEY][field] = "tampered-regression"
                self.assertFalse(self.canonical_guard())


if __name__ == "__main__":
    unittest.main()
