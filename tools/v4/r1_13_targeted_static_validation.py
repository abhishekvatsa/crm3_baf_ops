#!/usr/bin/env python3
"""Targeted source checks for the bounded R1.13 correction."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def _block(text: str, marker: str) -> str:
    start = text.index(marker)
    opening = text.index("{", start)
    depth = 0
    for index in range(opening, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[opening : index + 1]
    raise ValueError(f"Unbalanced block: {marker}")


def _quoted(text: str) -> set[str]:
    return set(re.findall(r"'([^']+)'", text))


def validate(root: Path) -> list[tuple[str, bool, str]]:
    checks: list[tuple[str, bool, str]] = []

    def check(name: str, condition: bool, detail: str = "") -> None:
        checks.append((name, bool(condition), detail))

    sync = (root / "lib/core/services/sync_service.job_modules.dart").read_text(
        encoding="utf-8"
    )
    rules = (root / "firestore.rules").read_text(encoding="utf-8")
    for kind in ("Submit", "Accept"):
        payload = _block(sync, f"Map<String, dynamic> _jobModule{kind}ReplayStepData")
        whitelist = _block(rules, f"function jobModule{kind}ChangedFieldsOnly")
        payload_fields = _quoted(payload)
        rule_fields = _quoted(whitelist)
        check(
            f"{kind.lower()} replay payload exactly mirrors Rules whitelist",
            payload_fields == rule_fields,
            f"payload-only={sorted(payload_fields-rule_fields)}; "
            f"rules-only={sorted(rule_fields-payload_fields)}",
        )
        check(
            f"{kind.lower()} replay explicitly clears isOpenForWork",
            "'isOpenForWork': false" in payload,
        )

    violations: list[str] = []
    banned = (
        "controller ?? TextEditingController",
        "final controller = TextEditingController",
        "final reasonController = TextEditingController",
        "final remarksController = TextEditingController",
        "final notesController = TextEditingController",
        "Intentionally no immediate controller.dispose",
        "Intentionally no immediate reasonController.dispose",
    )
    local_controller = re.compile(
        r"\b(?:final|var)\s+(?!_)[A-Za-z0-9]*Controller\s*=\s*"
        r"TextEditingController\s*\("
    )
    for path in (root / "lib").rglob("*.dart"):
        source = path.read_text(encoding="utf-8")
        for marker in banned:
            if marker in source:
                violations.append(f"{path.relative_to(root)}: {marker}")
        for match in local_controller.finditer(source):
            violations.append(f"{path.relative_to(root)}: {match.group(0)}")
    check("controller ownership guard has zero violations", not violations, "; ".join(violations))

    owned_controllers = {
        "lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart": (
            "class _ComplianceTextPromptDialogState",
            "_controller.dispose();",
        ),
        "lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart": (
            "class _WorkflowTextPromptDialogState",
            "_controller.dispose();",
        ),
        "lib/features/maintenance_workflow/presentation/widgets/raise_compliance_dialog.dart": (
            "class _RaiseComplianceDialogState",
            "_titleController.dispose();",
            "_descriptionController.dispose();",
            "_conditionRefController.dispose();",
        ),
    }
    for relative, markers in owned_controllers.items():
        source = (root / relative).read_text(encoding="utf-8")
        check(
            f"{relative} uses State-owned disposed controllers",
            all(marker in source for marker in markers),
        )

    assignment = (
        root / "lib/features/planned_maintenance/presentation/assign_job_screen.dart"
    ).read_text(encoding="utf-8")
    command = "await ref.read(workflowCommandControllerProvider.notifier).execute("
    sync_capture = "final syncCoordinator = ref.read(syncCoordinatorProvider);"
    check(
        "assignment uses current command-controller contract",
        command in assignment
        and sync_capture in assignment
        and assignment.index(sync_capture) < assignment.index(command)
        and "repository.saveExecution(" not in assignment
        and "workflow_job_assigned" in assignment,
    )

    collections = (
        "maintenance_workflows",
        "job_lanes",
        "compliance_requests",
        "compliance_attempts",
        "equipment_status",
        "equipment_prompt_master",
        "maintenance_workflow_events",
        "maintenance_workflow_command_receipts",
        "workflow_notification_receipts",
    )
    for collection in collections:
        match = re.search(
            r"match\s+/" + re.escape(collection) + r"/\{[^}]+\}\s*\{([\s\S]*?)\n\s*\}",
            rules,
        )
        body = match.group(1) if match else ""
        explicit_deny = "allow write: if false" in body or bool(
            re.search(
                r"allow\s+(?:read,\s*)?create,\s*update,\s*delete\s*:\s*if\s+false\s*;",
                body,
            )
        )
        check(f"{collection} explicitly denies direct writes", explicit_deny)

    lane = (
        root / "lib/features/maintenance_workflow/domain/maintenance_lane.dart"
    ).read_text(encoding="utf-8")
    generated = (
        root / "lib/features/maintenance_workflow/domain/workflow_policy_generated.dart"
    ).read_text(encoding="utf-8")
    values_match = re.search(
        r"static const values = <MaintenanceLaneId>\[([\s\S]*?)\];", lane
    )
    lane_count = (
        len(re.findall(r"^\s{4}[A-Za-z]+,$", values_match.group(1), re.MULTILINE))
        if values_match
        else -1
    )
    check("seven governed maintenance lanes are present", lane_count == 7, str(lane_count))
    check(
        "shared lane is generated with explicit delegation basis",
        "'shared': WorkflowLanePolicyGenerated(" in generated
        and "delegationBasis: 'plant-v2-shared-coordination'" in generated,
    )

    package = json.loads((root / "package.json").read_text(encoding="utf-8"))
    package_lock = json.loads((root / "package-lock.json").read_text(encoding="utf-8"))
    security_test = (root / "test/stage2d_source_security_contract_test.dart").read_text(
        encoding="utf-8"
    )
    check("protobufjs override is 7.6.5", package["overrides"]["protobufjs"] == "7.6.5")
    check(
        "protobufjs lock entry is 7.6.5",
        package_lock["packages"]["node_modules/protobufjs"]["version"] == "7.6.5",
    )
    check(
        "Stage-2D security contract expects 7.6.5",
        "expect(overrides['protobufjs'], '7.6.5')" in security_test
        and "'7.6.4'" not in security_test,
    )

    lock_text = (root / "pubspec.lock").read_text(encoding="utf-8")
    locked_isar_archive_sha = "BC6768CC4B9C61AABFF77152E7F33B4B17D2FC93134F7AF1C3DD51500FE8D5E8"

    isar_helper = (root / "tool/test_support/test_isar_core.dart").read_text(
        encoding="utf-8"
    )
    isar_stager = (root / "tools/isar/stage_governed_test_isar_core.py").read_text(
        encoding="utf-8"
    )
    lab = (root / "tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1").read_text(
        encoding="utf-8"
    )
    check(
        "Isar helper supports fail-closed governed mode",
        "CRM_ISAR_CORE_REQUIRED" in isar_helper
        and "download: libraries.isEmpty && !configuredCoreRequired" in isar_helper,
    )
    check(
        "laboratory stages and requires governed Isar DLL",
        all(
            marker in lab
            for marker in (
                "30_isar_test_core_custody",
                "stage_governed_test_isar_core.py",
                "CRM_ISAR_CORE_PATH",
                "CRM_ISAR_CORE_REQUIRED",
                "flutter test --concurrency=1",
            )
        ),
    )
    check(
        "Isar archive SHA is exact and consistent across lock and harness",
        locked_isar_archive_sha.lower() in lock_text.lower()
        and locked_isar_archive_sha in lab,
    )
    check(
        "Isar stager verifies resolved package identity and architecture",
        "_package_pubspec_identity" in isar_stager
        and "PE_MACHINE_AMD64 = 0x8664" in isar_stager
        and 'package_identity["version"] != expected_version' in isar_stager,
    )
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    checks = validate(root)
    for name, passed, detail in checks:
        suffix = f" | {detail}" if detail else ""
        print(f"{'PASS' if passed else 'FAIL'} | {name}{suffix}")
    passed = sum(result for _, result, _ in checks)
    failed = len(checks) - passed
    print(f"SUMMARY passed={passed} failed={failed} total={len(checks)}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
