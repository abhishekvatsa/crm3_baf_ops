"""Exercise the actual ultimate-audit basic-ftp guard without running unrelated audits."""
import ast
import copy
import json
from pathlib import Path
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
