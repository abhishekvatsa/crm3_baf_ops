"""Exercise the actual canonical diagnostics guard against broken source copies."""
import ast
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "tools/v4/v4_2_r1_canonical_audit.py"
tree = ast.parse(AUDIT.read_text(encoding="utf-8"))
helper = next(node for node in tree.body
              if isinstance(node, ast.FunctionDef)
              and node.name == "local_diagnostics_access_contract")
namespace = {"re": re}
exec(compile(ast.Module(body=[helper], type_ignores=[]), str(AUDIT), "exec"), namespace)
contract = namespace["local_diagnostics_access_contract"]


class CanonicalDiagnosticsContractTest(unittest.TestCase):
    def setUp(self):
        self.screen = (ROOT / "lib/features/admin/presentation/local_diagnostics_screen.dart").read_text(encoding="utf-8")
        self.service = (ROOT / "lib/core/release/backend_release_identity_service.dart").read_text(encoding="utf-8")
        self.actor = (ROOT / "lib/features/auth/data/user_model.dart").read_text(encoding="utf-8")

    def test_current_split_reads_preserve_access_and_deadline(self):
        self.assertTrue(contract(self.screen, self.service, self.actor))

    def test_missing_structure_fails_without_exception(self):
        for field in range(3):
            sources = [self.screen, self.service, self.actor]
            sources[field] = ""
            with self.subTest(field=field):
                self.assertFalse(contract(*sources))

    def test_rejects_weakened_authority_or_local_report_access(self):
        changes = [
            ("authority.isLoading ||", ""),
            ("authority.hasError ||", ""),
            ("actor == null ||", ""),
            ("uid: actor.uid,", "uid: 'fixed',"),
            ("!actor.canManageTemplateGovernance", "false"),
            ("revision: actor.authorityRevision,", "revision: 0,"),
            ("roles: roles.join(','),", "roles: '',"),
            ("if (ref.watch(localDiagnosticsAuthorityProvider) == null)", "if (false)"),
            ("return inventory.whenData(", "return backend.whenData("),
            ("final inventory = ref.watch(localDiagnosticsInventoryProvider);",
             "final inventory = await ref.watch(localDiagnosticsInventoryProvider.future);"),
            ("final persistence = await ref", "await ref.watch(localDiagnosticsBackendIdentityProvider.future); final persistence = await ref"),
        ]
        for old, new in changes:
            with self.subTest(marker=old):
                self.assertIn(old, self.screen)
                self.assertFalse(contract(self.screen.replace(old, new), self.service, self.actor))
        weakened_actor = self.actor.replace(
            "canManageTemplateGovernance => isApproved && (isAdmin || isSI);",
            "canManageTemplateGovernance => isAdmin || isSI;")
        self.assertNotEqual(self.actor, weakened_actor)
        self.assertFalse(contract(self.screen, self.service, weakened_actor))

    def test_each_independent_provider_requires_its_own_guard(self):
        guard = "if (ref.watch(localDiagnosticsAuthorityProvider) == null)"
        for provider in ("localDiagnosticsBackendIdentityProvider", "localDiagnosticsInventoryProvider", "localDiagnosticsReportProvider"):
            start = self.screen.index("final " + provider + " =")
            pos = self.screen.index(guard, start)
            broken = self.screen[:pos] + self.screen[pos:].replace(guard, "if (false)", 1)
            with self.subTest(provider=provider):
                self.assertFalse(contract(broken, self.service, self.actor))

    def test_inventory_guard_cannot_move_after_the_local_read(self):
        start = self.screen.index("final localDiagnosticsInventoryProvider =")
        guard_start = self.screen.index("      if (ref.watch(localDiagnosticsAuthorityProvider) == null)", start)
        guard_end = self.screen.index("\n      }", guard_start) + len("\n      }")
        guard = self.screen[guard_start:guard_end]
        broken = self.screen[:guard_start] + self.screen[guard_end:]
        insertion = broken.index("          .read();", start) + len("          .read();")
        broken = broken[:insertion] + "\n" + guard + broken[insertion:]
        self.assertFalse(contract(broken, self.service, self.actor))

    def test_rejects_missing_shared_deadline_or_session_bounds(self):
        changes = [
            ("this.timeout = const Duration(seconds: 20)", "this.timeout = const Duration(seconds: 60)"),
            ("elapsed.elapsed >= timeout", "false"),
            ("_authClient.currentUser?.uid != uid", "false"),
            ("return timeout - elapsed.elapsed;", "return timeout;"),
            (".timeout(\n          timeout,", ".then("),
            ("HttpsCallableOptions(timeout: remaining())", "HttpsCallableOptions()"),
            ("getIdToken(true).timeout(remaining())", "getIdToken(true)"),
            ("firstError.code != 'unauthenticated'", "false"),
            ("remaining(); // Reject late results", "// Reject late results"),
        ]
        for old, new in changes:
            with self.subTest(marker=old):
                self.assertIn(old, self.service)
                self.assertFalse(contract(self.screen, self.service.replace(old, new), self.actor))


if __name__ == "__main__":
    unittest.main()
