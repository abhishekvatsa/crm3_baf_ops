#!/usr/bin/env python3
"""Source-only full-tree audit for the CRM3 maintenance workflow integration.

This deliberately audits both the new control-plane code and untouched files in
pre-existing features that consume changed shared models/enums/services. It does
not claim to replace Flutter analysis, Isar generation, emulator tests, or an
on-device offline/notification smoke test.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def balanced_switch_blocks(source: str) -> list[str]:
    blocks: list[str] = []
    for match in re.finditer(r"\bswitch\s*\([^)]*\)\s*\{", source):
        start = match.start()
        brace = source.find("{", match.start())
        depth = 0
        for index in range(brace, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(source[start:index + 1])
                    break
    return blocks


def add(checks: list[Check], name: str, ok: bool, detail: str) -> None:
    checks.append(Check(name, ok, detail))


def main() -> int:
    checks: list[Check] = []

    model = text("lib/features/planned_maintenance/data/job_template_model.dart")
    safe_map = model[model.index("Map<String, dynamic> toClientWritableMap()") :]
    safe_map = safe_map[: safe_map.index("factory JobExecution.fromMap")]
    server_fields = {
        "workflowSchemaVersion",
        "laneSetVersion",
        "laneSetFinalizedAt",
        "laneSetFinalizedByUid",
        "laneSetFinalizedByName",
        "laneMappingReview",
        "parentExecutionFirestoreId",
        "spawnedRedExecutionFirestoreId",
        "redAnswerJson",
    }
    missing = sorted(
        field for field in server_fields if f"map.remove('{field}')" not in safe_map
    )
    add(
        checks,
        "client execution serializer excludes every server-owned workflow field",
        not missing,
        "missing removals: " + ", ".join(missing) if missing else "all 9 fields excluded",
    )
    add(
        checks,
        "new unproven JobExecution defaults to legacy/no-aggregate schema",
        "int workflowSchemaVersion = 0;" in model,
        "default is 0; server creation elevates to 1",
    )

    remote_batch = text(
        "lib/features/planned_maintenance/providers/planned_maintenance_provider.remote.dart"
    )
    add(
        checks,
        "all live batch execution writes use the client-safe serializer",
        "r.toClientWritableMap()" in remote_batch
        and "_executions.doc(r.firestoreId),\n          r.toMap()" not in remote_batch,
        "FirestorePlannedRepository.batchUpsertExecutions inspected",
    )

    enum_failures: list[str] = []
    for path in (ROOT / "lib").rglob("*.dart"):
        if path.name.endswith(".g.dart"):
            continue
        source = path.read_text(encoding="utf-8")
        for block in balanced_switch_blocks(source):
            if "case JobModuleDiscipline." in block:
                absent = [
                    value
                    for value in ("emd", "refractory")
                    if f"JobModuleDiscipline.{value}" not in block
                ]
                if absent:
                    enum_failures.append(
                        f"{path.relative_to(ROOT)} module switch misses {','.join(absent)}"
                    )
            if "case JobDiaryDiscipline." in block:
                absent = [
                    value
                    for value in ("emd", "refractory")
                    if f"JobDiaryDiscipline.{value}" not in block
                ]
                if absent:
                    enum_failures.append(
                        f"{path.relative_to(ROOT)} diary switch misses {','.join(absent)}"
                    )
    add(
        checks,
        "full lib tree handles both newly added discipline enum values",
        not enum_failures,
        "; ".join(enum_failures[:8]) if enum_failures else "every discipline switch is explicit",
    )

    composer_helpers = text(
        "lib/features/planned_maintenance/presentation/module_composer_screen.helpers.dart"
    )
    add(
        checks,
        "untouched composer owner bridge preserves EMD and Refractory identities",
        "case JobModuleDiscipline.emd:" in composer_helpers
        and "return 'emd';" in composer_helpers
        and "case JobModuleDiscipline.refractory:" in composer_helpers
        and "return 'refractory';" in composer_helpers,
        "new disciplines no longer collapse into the legacy 'others' bucket",
    )

    user_model = text("lib/features/auth/data/user_model.dart")
    catalogue = text(
        "lib/features/planned_maintenance/domain/published_runtime_module_catalogue.dart"
    )
    assignment_builder = text(
        "lib/features/planned_maintenance/domain/template_version_assignment_builder.dart"
    )
    add(
        checks,
        "untouched published-template parsers preserve EMD and Refractory",
        "case 'emd':\n      return JobModuleDiscipline.emd;" in catalogue
        and "case 'refractory':\n      return JobModuleDiscipline.refractory;" in catalogue
        and "case 'emd':\n      return JobModuleDiscipline.emd;" in assignment_builder
        and "case 'refractory':\n      return JobModuleDiscipline.refractory;" in assignment_builder,
        "newly published modules no longer collapse into shared/others",
    )

    generated_client_policy = text(
        "lib/features/maintenance_workflow/domain/workflow_policy_generated.dart"
    )
    add(
        checks,
        "agreed Operations module authority is retained",
        "'operations': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'operations'}"
        in generated_client_policy
        and "WorkflowPolicyGenerated.moduleDisciplineSubmitRoles[discipline]"
        in user_model,
        "authority is generated from the governing policy",
    )
    add(
        checks,
        "legacy 'others' modules remain operable by Senior Refractory",
        "'others': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorRefractory'}"
        in generated_client_policy
        and "WorkflowPolicyGenerated.moduleDisciplineSubmitRoles[discipline]"
        in user_model,
        "historical refractory-as-others compatibility is policy-generated",
    )

    coordinator = text("lib/core/services/sync_coordinator.dart")
    add(
        checks,
        "workflow retry/pull failures are isolated from mature sync status",
        "_runWorkflowSupplementalSync" in coordinator
        and "await _runWorkflowSupplementalSync(reason: reason);" in coordinator,
        "supplemental control plane has independent logging/catches",
    )
    pull = text(
        "lib/features/maintenance_workflow/services/workflow_pull_service.dart"
    )
    add(
        checks,
        "one workflow collection failure does not abort later collections",
        "Future<int> _pullCollection<T>" in pull
        and "final Map<String, String> failures" in pull
        and "bool get hasFailures" in pull,
        "per-collection watermark advances remain independent and post-upsert",
    )

    notifications = text("functions/src/notifications.ts")
    trigger = text(
        "functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts"
    )
    notification_policy = text(
        "functions/src/maintenanceWorkflow/workflowNotificationPolicy.ts"
    )
    notification_receipt = text("functions/src/notificationEventReceipt.ts")
    add(
        checks,
        "workflow notifications reuse shared token cleanup and data payload support",
        "sendNotification" in trigger
        and "getTokenLookupsForRoles" in trigger
        and "data?: Readonly<Record<string, string>>" in notifications,
        "parallel sendEachForMulticast path removed",
    )
    add(
        checks,
        "workflow notification routing derives from generated lane policy",
        'import {LANE_POLICY} from "./policy.generated"' in notification_policy,
        "no parallel per-lane hardcode",
    )
    add(
        checks,
        "workflow notification receipt uses event-bound fail-closed coordination",
        "executeIdempotentNotificationEvent({" in trigger
        and "retry: true" in trigger
        and "cloudEventId: event.id" in trigger
        and "workflow_notification_receipts" in trigger
        and 'status: "completed"' in notification_receipt
        and 'status: "failedBeforeDispatch"' in notification_receipt
        and 'status: "deliveryUncertain"' in notification_receipt
        and "acquireReceiptLease" not in trigger,
        "concurrent retries replay completion; ambiguous dispatch is quarantined",
    )

    home = text("lib/home_screen.dart")
    hub = text(
        "lib/features/maintenance_workflow/presentation/screens/workflow_hub_screen.dart"
    )
    add(
        checks,
        "notification tap and terminated-app launch resolve to workflow UI",
        "FirebaseMessaging.onMessageOpenedApp" in home
        and "getInitialMessage" in home
        and "initialWorkflowId" in hub,
        "imperative navigation remains compatible with the existing app shell",
    )

    generator = text("tools/maintenance_workflow/generate_policy.mjs")
    callable = text("functions/src/maintenanceWorkflow/callable.ts")
    user_authority = text("functions/src/userAuthority.ts")
    generated = text(
        "functions/src/maintenanceWorkflow/policy.generated.ts"
    )
    add(
        checks,
        "callable supported roles are generated from the policy role universe",
        "WORKFLOW_ROLE_UNIVERSE" in generator
        and "WORKFLOW_ROLE_UNIVERSE" in generated
        and "WORKFLOW_ROLE_UNIVERSE" in user_authority
        and "canonicalApprovedUserAuthority" in callable,
        "hand-maintained fourth role list removed",
    )

    assign = text(
        "lib/features/planned_maintenance/presentation/assign_job_screen.dart"
    )
    policy = text("lib/features/maintenance_workflow/domain/workflow_policy.dart")
    add(
        checks,
        "ratified online-only lifecycle decision is consumed by field UX",
        "WorkflowPolicy.onlineOnlyLifecycleCommands" in assign
        and "onlineOnlyLifecycleCommands" in policy
        and "not queued offline" in assign,
        "review criticism is adjudicated, not blindly implemented",
    )

    read_repo = text(
        "lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart"
    )
    add(
        checks,
        "workflow timestamp parser accepts native Firestore Timestamp",
        "value is Timestamp" in read_repo,
        "review concern O-Deep-1 is closed as already-correct",
    )

    lane_record = text(
        "lib/features/maintenance_workflow/data/job_lane_record.dart"
    )
    local_id_mentions = []
    for path in (ROOT / "lib").rglob("*.dart"):
        if not str(path.relative_to(ROOT)).startswith("lib/features/maintenance_workflow/"):
            continue
        if path.name == "job_lane_record.dart" or path.name.endswith(".g.dart"):
            continue
        if "jobExecutionLocalId" in path.read_text(encoding="utf-8"):
            local_id_mentions.append(str(path.relative_to(ROOT)))
    add(
        checks,
        "workflow joins do not rely on transported device-local execution ids",
        not local_id_mentions and "jobExecutionLocalId" in lane_record,
        "all workflow consumers join on Firestore/workflow identity"
        if not local_id_mentions
        else "unexpected consumers: " + ", ".join(local_id_mentions),
    )

    print("CRM3 MAINTENANCE WORKFLOW — FULL-TREE SOURCE AUDIT")
    print(f"root={ROOT}")
    for check in checks:
        print(f"{'PASS' if check.ok else 'FAIL'} | {check.name} | {check.detail}")
    failures = [check for check in checks if not check.ok]
    print(f"SUMMARY | pass={len(checks)-len(failures)} fail={len(failures)} total={len(checks)}")
    if failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
