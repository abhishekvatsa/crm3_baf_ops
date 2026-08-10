#!/usr/bin/env python3
"""Fail-closed source audit for the v4.2 ultimate local-trial successor."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
passes: list[tuple[str, str]] = []
failures: list[tuple[str, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    target = passes if condition else failures
    target.append((name, detail))
    print(f"{'PASS' if condition else 'FAIL'} | {name}" + (f" | {detail}" if detail else ""))


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def data(rel: str):
    return json.loads(text(rel))




def powershell_delimiters_balanced(source: str) -> bool:
    pairs = {')': '(', ']': '[', '}': '{'}
    stack: list[str] = []
    quote: str | None = None
    escaped = False
    comment = False
    i = 0
    while i < len(source):
        ch = source[i]
        if comment:
            if ch == "\n":
                comment = False
            i += 1
            continue
        if quote:
            if escaped:
                escaped = False
            elif ch == '`':
                escaped = True
            elif ch == quote:
                # PowerShell doubles a quote to escape it inside the same quote type.
                if i + 1 < len(source) and source[i + 1] == quote:
                    i += 1
                else:
                    quote = None
            i += 1
            continue
        if ch == '#':
            comment = True
        elif ch in ("'", '"'):
            quote = ch
        elif ch in '([{':
            stack.append(ch)
        elif ch in ')]}':
            if not stack or stack.pop() != pairs[ch]:
                return False
        i += 1
    return quote is None and not stack

def lock_version(rel: str, package: str) -> str | None:
    lock = data(rel)
    entry = lock.get("packages", {}).get(f"node_modules/{package}")
    return None if not isinstance(entry, dict) else entry.get("version")


# 1. Governing migration direction: preserve v4, adapt legacy guarantees.
authority = data("governance/v4_successor_programme_authority_v1.json")
capabilities = set(authority.get("nonNegotiableSuccessorCapabilities", []))
check(
    "Successor programme explicitly prioritises migration to the new architecture",
    authority.get("governingPriority") == "MIGRATE_TO_NEW_ARCHITECTURE"
    and authority.get("developmentAuthority", {}).get("successorArchitecture") in {"v4.2", "v4.2_R1"}
    and authority.get("legacyTreatment", {}).get("preserveConflictingAuthorityPath") is False
    and authority.get("legacyTreatment", {}).get("avoidChangeAsDesignGoal") is False,
)
check(
    "Non-negotiable v4 workflow capabilities remain ratified",
    len(capabilities) >= 12
    and "server-authoritative command gateway" in capabilities
    and "maintenance-ticket deferral bridge" in capabilities
    and "canonical closure with module/evidence attestation" in capabilities
    and "escalation, notifications, quarantine and diagnostics" in capabilities,
    f"capabilities={len(capabilities)}",
)

# 2. Persistence boundary preserves native Firestore values and converts ISO deadlines.
adapter = text("functions/src/maintenanceWorkflow/firebaseStore.ts")
adapter_tests = text("functions/test/maintenanceWorkflowFirebaseStore.test.js")
native_types = [
    "admin.firestore.Timestamp",
    "admin.firestore.GeoPoint",
    "admin.firestore.DocumentReference",
    "admin.firestore.FieldValue",
    "Uint8Array",
]
check(
    "Workflow Firestore adapter preserves native special values before object recursion",
    "if (isNativeFirestoreValue(value)) return value;" in adapter
    and adapter.index("if (isNativeFirestoreValue(value)) return value;")
    < adapter.index('if (value != null && typeof value === "object")')
    and all(t in adapter for t in native_types),
)
check(
    "Native-value and command-path persistence regressions are directly tested",
    all(
        phrase in adapter_tests
        for phrase in [
            "preserves native Firestore values",
            "maintenance awaiting-confirmation path",
            "equipment projection preserves inServiceSince",
            "counter-condition successor spread preserves inherited native timestamps",
            "converts all lifecycle deadline fields",
        ]
    ),
)

# 3. Singular approval and role authority across server, Rules and client.
callable_source = text("functions/src/maintenanceWorkflow/callable.ts")
user_authority_source = text("functions/src/userAuthority.ts")
callable_test = text("functions/test/maintenanceWorkflowCallableAuthority.test.js")
rules = text("firestore.rules")
user_model = text("lib/features/auth/data/user_model.dart")
user_test = text("test/user_authority_schema_test.dart")
check(
    "Workflow callable uses the singular canonical backend approval validator",
    "canonicalApprovedUserAuthority(data)" in callable_source
    and "data.approved" not in user_authority_source
    and 'data.status === "approved"' not in user_authority_source
    and 'typeof data.isApproved !== "boolean"' in user_authority_source
    and "capsule == null || !capsule.isApproved" in user_authority_source
    and "WORKFLOW_ROLE_UNIVERSE" in user_authority_source
    and "workflowActorFromUserDataForTest" in callable_source
    and "rejects legacy or malformed authority" in callable_test.lower(),
)
role_vocabulary = [
    "admin", "si", "contractSupervisor", "shiftSupervisor", "seniorElectrical",
    "seniorMechanical", "seniorInstrumentation", "seniorRefractory", "refractory", "operations",
]
check(
    "Firestore Rules enforce exact user shape, optional types and canonical role vocabulary",
    "function validUserDocumentShape" in rules
    and "function validUserRoleList" in rules
    and "keys().hasOnly([" in rules
    and all(f"'{r}'" in rules for r in role_vocabulary)
    and "validOptionalUserString" in rules
    and "validUserDocumentShape(request.resource.data)" in rules,
)
check(
    "Dart user parsing fails closed instead of mapping unknown roles to Operations",
    "AppRole? _parseAppRole" in user_model
    and "data['isApproved'] == true && parsedRoles.isNotEmpty" in user_model
    and "unknown roles fail closed instead of becoming Operations" in user_test,
)

# 4. Authority-critical remote projection parsing fails closed and remains quarantined per record.
projection = text("lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart")
projection_test = text("test/maintenance_workflow/compliance_request_mapper_test.dart")
check(
    "Authority-critical workflow projections use strict required-field validators",
    all(marker in projection for marker in [
        "FormatException", "_requiredString(", "_requiredInt(", "_optionalDate(",
        "allowed: _workflowStatusKeys", "allowed: _laneStatusKeys",
        "allowed: _complianceStatusKeys", "allowed: _equipmentStateKeys",
    ])
    and "DateTime.fromMillisecondsSinceEpoch(0" not in projection,
)
# Ensure observed timestamp parsing is inside the per-document try/catch in _fetchAll.
fetch_start = projection.find("Future<WorkflowRemoteBatch<T>> _fetchAll")
fetch_end = projection.find("Future<List<WorkflowRemoteBatch", fetch_start)
fetch_block = projection[fetch_start: fetch_end if fetch_end > fetch_start else None]
check(
    "Malformed documents, including malformed watermarks, are quarantined individually",
    fetch_start >= 0
    and "for (final document in page.docs)" in fetch_block
    and "try {" in fetch_block
    and "failures.add" in fetch_block
    and "observedAt = _optionalDate" in fetch_block
    and fetch_block.index("try {") < fetch_block.index("observedAt = _optionalDate"),
)
check(
    "Projection mapper has positive parity and negative malformed-data test sources",
    "compliance Firestore projection preserves the complete lifecycle record" in projection_test
    and "authority-critical malformed compliance data fails closed" in projection_test
    and projection_test.count("throwsFormatException") >= 4,
)

# 5. Dependency locks are explicitly remediated in all three trust domains.
root_versions = {
    "protobufjs": lock_version("package-lock.json", "protobufjs"),
    "brace-expansion": lock_version("package-lock.json", "brace-expansion"),
    "js-yaml": lock_version("package-lock.json", "js-yaml"),
}
functions_versions = {
    "protobufjs": lock_version("functions/package-lock.json", "protobufjs"),
    "body-parser": lock_version("functions/package-lock.json", "body-parser"),
    "brace-expansion": lock_version("functions/package-lock.json", "brace-expansion"),
    "js-yaml": lock_version("functions/package-lock.json", "js-yaml"),
}
tooling_versions = {
    "firebase-tools": lock_version("tooling/firebase-cli/package-lock.json", "firebase-tools"),
    "protobufjs": lock_version("tooling/firebase-cli/package-lock.json", "protobufjs"),
    "body-parser": lock_version("tooling/firebase-cli/package-lock.json", "body-parser"),
    "brace-expansion": lock_version("tooling/firebase-cli/package-lock.json", "brace-expansion"),
    "tar": lock_version("tooling/firebase-cli/package-lock.json", "tar"),
    "@hono/node-server": lock_version("tooling/firebase-cli/package-lock.json", "@hono/node-server"),
    "fast-uri": lock_version("tooling/firebase-cli/package-lock.json", "fast-uri"),
    "hono": lock_version("tooling/firebase-cli/package-lock.json", "hono"),
    "ip-address": lock_version("tooling/firebase-cli/package-lock.json", "ip-address"),
    "js-yaml": lock_version("tooling/firebase-cli/package-lock.json", "js-yaml"),
    "re2": lock_version("tooling/firebase-cli/package-lock.json", "re2"),
}
check(
    "Application and Functions lockfiles contain remediated dependency versions",
    root_versions["protobufjs"] == "7.6.5"
    and functions_versions["protobufjs"] == "7.6.5"
    and functions_versions["body-parser"] == "1.20.6"
    and root_versions["brace-expansion"] == "5.0.9"
    and functions_versions["brace-expansion"] == "5.0.9"
    and root_versions["js-yaml"] == "3.15.1"
    and functions_versions["js-yaml"] == "3.15.1",
    f"root={root_versions}; functions={functions_versions}",
)
check(
    "Governed Firebase CLI lockfile is separately remediated",
    tooling_versions["protobufjs"] == "7.6.5"
    and tooling_versions["body-parser"] == "1.20.6"
    and tooling_versions["tar"] == "7.5.21"
    and tooling_versions["brace-expansion"] == "5.0.9"
    and tooling_versions["@hono/node-server"] == "2.0.10"
    and tooling_versions["fast-uri"] == "3.1.5"
    and tooling_versions["hono"] == "4.12.34"
    and tooling_versions["ip-address"] == "10.4.0"
    and tooling_versions["js-yaml"] == "4.3.1"
    and tooling_versions["re2"] == "1.26.1",
    str(tooling_versions),
)

# 6. Historical pre-v4 no-loss evidence is embedded. Generated property
# positions are not asserted here; authentic post-codegen semantic continuity
# is enforced by verify_canonical_main_isar_continuity.py.
continuity = data("docs/v4_2/ISAR_SCHEMA_CONTINUITY.json")
continuity_ok = len(continuity) == 16 and all(
    item.get("collection_id_same") is True
    and not item.get("removed_properties")
    and not item.get("removed_indexes")
    and not item.get("index_mismatches")
    for item in continuity.values()
)
check(
    "Historical v4.2 handoff retains all 16 inherited Isar collections, properties and indexes",
    continuity_ok,
    f"collections={len(continuity)}",
)
reconciliation = text("docs/v4_2/CURRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md")
check(
    "User-supplied pre-v4 source is retained as no-loss and migration evidence",
    "84BB9114C05C29777154E5EA7095DFF00850C478A2DB2048FDE5787CD5EB48CC" in reconciliation
    and "user-supplied current-pre-v4 source" in reconciliation.lower(),
)

# 7. Local trial is useful but cannot silently mutate remote/production state.
trial = ROOT / "tools/v4/Invoke-Crm3V42LocalTrial.ps1"
trial_text = trial.read_text(encoding="utf-8") if trial.exists() else ""
forbidden = ["firebase deploy", "git push", "git merge", "git tag", "adb uninstall", "pm clear"]
check(
    "Tomorrow local trial harness is present and contains no remote/deploy/destructive command",
    trial.exists()
    and "build_runner build --delete-conflicting-outputs" in trial_text
    and "flutter analyze" in trial_text
    and "flutter build apk --debug" in trial_text
    and all(item not in trial_text.lower() for item in forbidden)
    and powershell_delimiters_balanced(trial_text),
)
runbook = ROOT / "docs/v4_2/TOMORROW_LOCAL_TRIAL_RUNBOOK.md"
check(
    "Tomorrow trial runbook preserves production NO-GO boundaries",
    runbook.exists()
    and "NO FIREBASE DEPLOYMENT" in runbook.read_text(encoding="utf-8")
    and "NO GIT REMOTE MUTATION" in runbook.read_text(encoding="utf-8"),
)

# 8. Authentic Isar/release boundary remains fail-closed until real codegen.
isar_verify = text("tools/isar/verify_v4_isar_schema.py")
provisional_count = sum(
    1 for p in (ROOT / "lib").rglob("*.g.dart")
    if "PROVISIONAL_V4_ISAR_CODEGEN" in p.read_text(encoding="utf-8", errors="ignore")
)
check(
    "Authentic pinned Isar generation remains a mandatory release boundary",
    provisional_count in {0, 13}
    and "if args.release and marked" in isar_verify
    and "Pinned build_runner output required before release" in isar_verify,
    f"provisional={provisional_count}; mode={'POST_CODEGEN' if provisional_count == 0 else 'SOURCE_HANDOFF'}",
)

print(f"SUMMARY | pass={len(passes)} fail={len(failures)} total={len(passes)+len(failures)}")
if failures:
    for name, detail in failures:
        print(f"FAILED | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)
raise SystemExit(1 if failures else 0)
