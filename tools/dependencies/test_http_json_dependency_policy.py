"""Exercise both actual audit guards without running the full source audits."""
import ast
import copy
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
FUNCTION = "http_and_json_dependency_pins_match"
ROOT_MANIFEST = "package.json"
FUNCTIONS = "functions/package.json"
CLI = "tooling/firebase-cli/package.json"
ADAPTER = "tooling/stream-json-compat/package.json"
DOCUMENTS = (ROOT_MANIFEST, "package-lock.json", FUNCTIONS, FUNCTIONS.replace("package.json", "package-lock.json"),
             CLI, CLI.replace("package.json", "package-lock.json"), ADAPTER)
REGISTRY_ROWS = ((ROOT_MANIFEST, "js-yaml"), (FUNCTIONS, "js-yaml"), (CLI, "js-yaml"),
                 (FUNCTIONS, "proxy-addr"), (CLI, "proxy-addr"),
                 (CLI, "compression"), (CLI, "stream-json-modern"))
ALL_ROWS = (*REGISTRY_ROWS, (CLI, "stream-json"))


class GuardCases:
    @classmethod
    def setUpClass(cls):
        cls.audit = ROOT / cls.audit_relative
        cls.tree = ast.parse(cls.audit.read_text(encoding="utf-8"))
        cls.function = next(node for node in cls.tree.body
                            if isinstance(node, ast.FunctionDef) and node.name == FUNCTION)
        cls.originals = {name: json.loads((ROOT / name).read_text(encoding="utf-8"))
                         for name in DOCUMENTS}

    def setUp(self):
        self.reset()
        namespace = {"data": lambda name: self.documents[name]}
        exec(compile(ast.Module(body=[self.function], type_ignores=[]),
                     str(self.audit), "exec"), namespace)
        self.guard = namespace[FUNCTION]

    def reset(self):
        self.documents = copy.deepcopy(self.originals)

    def packages(self, manifest):
        return self.documents[manifest.replace("package.json", "package-lock.json")]["packages"]

    def row(self, manifest, name):
        return self.packages(manifest)["node_modules/" + name]

    def test_actual_fixed_manifests_and_locks_pass(self):
        self.assertTrue(self.guard())

    def test_guard_is_connected_to_an_actual_audit_check(self):
        checks = [node for node in ast.walk(self.tree) if isinstance(node, ast.Call)
                  and isinstance(node.func, ast.Name) and node.func.id == "check"]
        self.assertTrue(any(
            isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            and node.func.id == FUNCTION
            for check in checks for condition in check.args[1:2]
            for node in ast.walk(condition)
        ), "The tested guard must gate a real audit check")

    def test_missing_or_changed_manifest_overrides_refuse(self):
        for manifest, name in ((ROOT_MANIFEST, "js-yaml"), (FUNCTIONS, "js-yaml"),
                               (CLI, "js-yaml"), (FUNCTIONS, "proxy-addr"), (CLI, "proxy-addr"),
                               (CLI, "compression"), (CLI, "stream-json")):
            for mutation in ("missing", "changed"):
                with self.subTest(manifest=manifest, package=name, mutation=mutation):
                    self.reset()
                    if mutation == "missing":
                        del self.documents[manifest]["overrides"][name]
                    else:
                        self.documents[manifest]["overrides"][name] = "0.0.0-unreviewed"
                    self.assertFalse(self.guard())

    def test_root_direct_yaml_declaration_must_be_exact(self):
        for version in (None, "3.15.2", "^4.3.2"):
            with self.subTest(version=version):
                self.reset()
                declarations = self.documents[ROOT_MANIFEST]["devDependencies"]
                if version is None:
                    del declarations["js-yaml"]
                else:
                    declarations["js-yaml"] = version
                self.assertFalse(self.guard())

    def test_unpatched_sprintf_copies_refuse_in_both_domains(self):
        for manifest in (ROOT_MANIFEST, FUNCTIONS):
            for key in ("node_modules/sprintf-js",
                        "node_modules/js-yaml/node_modules/argparse/node_modules/sprintf-js"):
                with self.subTest(manifest=manifest, key=key):
                    self.reset()
                    self.packages(manifest)[key] = {"version": "1.0.3"}
                    self.assertFalse(self.guard())

    def test_wrong_registry_version_digest_or_tarball_refuses(self):
        for manifest, name in REGISTRY_ROWS:
            for field, value in (("version", "0.0.0-unreviewed"),
                                 ("integrity", "sha512-wrong-original-bytes"),
                                 ("resolved", "https://untrusted.invalid/package.tgz")):
                with self.subTest(manifest=manifest, package=name, field=field):
                    self.reset()
                    self.row(manifest, name)[field] = value
                    self.assertFalse(self.guard())

    def test_missing_required_lock_population_refuses(self):
        for manifest, name in ALL_ROWS:
            with self.subTest(manifest=manifest, package=name):
                self.reset()
                packages = self.packages(manifest)
                suffix = "node_modules/" + name
                for key in list(packages):
                    if key == suffix or key.endswith("/" + suffix):
                        del packages[key]
                self.assertFalse(self.guard())

    def test_stale_nested_copy_cannot_hide_behind_current_top_level(self):
        old_versions = {"js-yaml": "3.15.2", "proxy-addr": "2.0.7", "compression": "1.8.1",
                        "stream-json": "3.5.0", "stream-json-modern": "3.5.0"}
        for manifest, name in ALL_ROWS:
            with self.subTest(manifest=manifest, package=name):
                self.reset()
                nested = copy.deepcopy(self.row(manifest, name))
                nested["version"] = old_versions[name]
                self.packages(manifest)["node_modules/adversarial/node_modules/" + name] = nested
                self.assertFalse(self.guard())

    def test_nested_registry_copy_must_retain_exact_bytes_and_origin(self):
        for manifest, name in REGISTRY_ROWS:
            for field in ("integrity", "resolved"):
                with self.subTest(manifest=manifest, package=name, field=field):
                    self.reset()
                    nested = copy.deepcopy(self.row(manifest, name))
                    nested[field] = "changed-nested-custody"
                    self.packages(manifest)["node_modules/adversarial/node_modules/" + name] = nested
                    self.assertFalse(self.guard())

    def test_local_adapter_manifest_cannot_claim_an_old_or_different_package(self):
        for field in ("name", "version", "alias"):
            with self.subTest(field=field):
                self.reset()
                adapter = self.documents[ADAPTER]
                if field == "alias":
                    adapter["dependencies"]["stream-json-modern"] = "npm:stream-json@3.5.0"
                else:
                    adapter[field] = "stream-json-unreviewed" if field == "name" else "3.5.0"
                self.assertFalse(self.guard())

    def test_adapter_lock_cannot_redirect_or_retain_old_alias(self):
        for field in ("resolved", "alias"):
            with self.subTest(field=field):
                self.reset()
                row = self.row(CLI, "stream-json")
                if field == "alias":
                    row["dependencies"]["stream-json-modern"] = "npm:stream-json@3.5.0"
                else:
                    row[field] = "file:../different-adapter"
                self.assertFalse(self.guard())

    def test_upstream_alias_name_and_adapter_selection_are_bound(self):
        for field in ("upstream-name", "adapter-selection"):
            with self.subTest(field=field):
                self.reset()
                if field == "upstream-name":
                    self.row(CLI, "stream-json-modern")["name"] = "different-package"
                else:
                    self.documents[CLI]["dependencies"]["stream-json"] = "3.6.0"
                self.assertFalse(self.guard())

    def test_matching_nested_copies_and_unrelated_packages_remain_valid(self):
        for manifest, name in ALL_ROWS:
            self.packages(manifest)["node_modules/valid-nesting/node_modules/" + name] = copy.deepcopy(
                self.row(manifest, name))
        self.packages(CLI)["node_modules/unrelated"] = {"version": "0.0.1"}
        self.assertTrue(self.guard())


class CanonicalDependencyGuardTests(GuardCases, unittest.TestCase):
    audit_relative = "tools/v4/v4_2_r1_canonical_audit.py"


class UltimateDependencyGuardTests(GuardCases, unittest.TestCase):
    audit_relative = "tools/v4/v4_2_ultimate_audit.py"


if __name__ == "__main__":
    unittest.main(verbosity=2)
