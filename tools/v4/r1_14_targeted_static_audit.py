#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PASS: list[str] = []
FAIL: list[str] = []


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        PASS.append(name)
        print(f"PASS | {name}" + (f" | {detail}" if detail else ""))
    else:
        FAIL.append(name)
        print(f"FAIL | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)


def block(source: str, marker: str) -> str:
    start = source.find(marker)
    if start < 0:
        return ""
    open_brace = source.find("{", start + len(marker))
    if open_brace < 0:
        return ""
    depth = 0
    quote: str | None = None
    escaped = False
    for i in range(open_brace, len(source)):
        ch = source[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in ("'", '"'):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
    return ""


def method_block(source: str, marker: str) -> str:
    start = source.find(marker)
    if start < 0:
        return ""
    open_paren = source.find("(", start)
    if open_paren < 0:
        return ""
    depth = 0
    close_paren = -1
    for i in range(open_paren, len(source)):
        if source[i] == "(":
            depth += 1
        elif source[i] == ")":
            depth -= 1
            if depth == 0:
                close_paren = i
                break
    if close_paren < 0:
        return ""
    body_open = source.find("{", close_paren + 1)
    if body_open < 0:
        return ""
    depth = 0
    quote: str | None = None
    escaped = False
    for i in range(body_open, len(source)):
        ch = source[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in ("'", '"'):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
    return ""


def balanced(source: str) -> bool:
    pairs = {')': '(', ']': '[', '}': '{'}
    stack: list[str] = []
    quote: str | None = None
    escaped = False
    line_comment = False
    for i, ch in enumerate(source):
        if line_comment:
            if ch == "\n":
                line_comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch == "/" and i + 1 < len(source) and source[i + 1] == "/":
            line_comment = True
            continue
        if ch in ("'", '"'):
            quote = ch
        elif ch in "([{":
            stack.append(ch)
        elif ch in ")]}":
            if not stack or stack.pop() != pairs[ch]:
                return False
    return quote is None and not stack


rules = text("firestore.rules")
provider = text("lib/features/planned_maintenance/providers/job_module_provider.dart")
job_rules = text("test/job_module_rules.test.js")
root_rules_test = text("test/firestore.rules.test.js")
harness = text("tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1")
contract = text("test/firestore_rules_expression_budget_contract_test.dart")
lifecycle_contract = text("test/job_module_lifecycle_replay_contract_test.dart")

check("Firestore Rules delimiters are balanced", balanced(rules))
function_names = re.findall(r"\bfunction\s+([A-Za-z0-9_]+)\s*\(", rules)
duplicates = sorted({name for name in function_names if function_names.count(name) > 1})
check("Firestore Rules function names are unique", not duplicates, f"duplicates={duplicates}")

maintenance_match = block(rules, "match /maintenance_records/{docId}")
check(
    "maintenance update has one allow expression",
    maintenance_match.count("allow update:") == 1
    and "allow update: if validMaintenanceUpdate();" in maintenance_match,
)
maintenance_router = block(rules, "function validMaintenanceUpdate()")
for marker in (
    "validMaintenanceSoftDeleteUpdate()",
    "validMaintenanceCloseUpdate()",
    "validMaintenanceReopenUpdate()",
    "validMaintenanceAdminEditUpdate()",
):
    check(f"maintenance router retains {marker}", marker in maintenance_router)

user_authority = block(rules, "function validApprovedUserAuthority(data)")
check(
    "approved-user authority remains full-shape fail-closed",
    "validUserDocumentShape(data)" in user_authority
    and "data.get('isApproved', false) == true" in user_authority,
)

template_router = block(rules, "function validTemplateVersionUpdateDelta()")
check(
    "template lifecycle uses source/target status routing",
    all(
        marker in template_router
        for marker in (
            "sourceStatus == 'draft'",
            "validTemplateVersionPublishDelta()",
            "validDraftTemplateVersionArchiveDelta()",
            "validTemplateVersionRetireDelta()",
            "validRetiredTemplateVersionArchiveDelta()",
            "validTemplateVersionRestoreDelta()",
        )
    ),
)
check(
    "template update wrapper has no parallel OR chain",
    "||" not in block(rules, "function validTemplateVersionUpdate(docId)"),
)

directive_router = block(rules, "function validDirectiveUpdateForRoles(roles)")
check(
    "directive roles are snapshotted and routed",
    directive_router
    and "validDirectiveAdminDeleteForRoles(roles)" in directive_router
    and "validDirectiveAdminEditForRoles(roles)" in directive_router
    and "validDirectiveAcknowledgeForRoles(roles)" in directive_router
    and "validDirectiveCloseForRoles(roles)" in directive_router
    and "function canDirectiveCreatorTarget(role)" not in rules,
)

family_router = block(rules, "function validModuleRegistryFamilyGovernedUpdate(docId)")
check(
    "module family update routes publish versus retire",
    "validModuleRegistryFamilyPublishDelta(docId)" in family_router
    and "validModuleRegistryFamilyRetireDelta()" in family_router
    and "||" not in family_router,
)
revision_router = block(rules, "function validModuleRegistryRevisionUpdateDelta(")
check(
    "module revision update routes one lifecycle transition",
    "validModuleRegistryRevisionDraftEditDelta()" in revision_router
    and "validModuleRegistryRevisionPublishDelta(" in revision_router
    and "validModuleRegistryRevisionRetireDelta()" in revision_router,
)
family_read = block(rules, "function moduleRegistryRevisionPublishMatchesFamily(")
check(
    "module revision publish performs one family getAfter",
    family_read.count("getAfter(") == 1,
    f"getAfter={family_read.count('getAfter(')}",
)

job_router = block(rules, "function validJobModuleUpdatePayload(docId, changedKeys, roles)")
check(
    "job-module update routes one target lifecycle",
    all(
        marker in job_router
        for marker in (
            "targetStatus == 'submitted'",
            "targetStatus == 'accepted'",
            "targetStatus == 'reopened'",
            "targetStatus == 'notApplicable'",
            "isOpenModuleStatus(targetStatus)",
        )
    )
    and "||" not in job_router,
)

remote = provider[provider.find("class FirestoreJobModuleRepository") :]
transitions = {
    "submitModule": ("JobModuleStatus.submitted.name", "'isOpenForWork': false"),
    "reopenModule": ("JobModuleStatus.reopened.name", "'isOpenForWork': true"),
    "markModuleNotApplicable": (
        "JobModuleStatus.notApplicable.name",
        "'isOpenForWork': false",
    ),
    "acceptModule": ("JobModuleStatus.accepted.name", "'isOpenForWork': false"),
}
for method, markers in transitions.items():
    method_block_text = method_block(remote, f"Future<void> {method}(")
    check(
        f"direct {method} persists lifecycle open-state",
        method_block_text and all(marker in method_block_text for marker in markers),
    )

check(
    "job-module fixture materializes derived open-state",
    "data.isOpenForWork =" in job_rules
    and "data.status !== 'submitted'" in job_rules
    and "data.status !== 'accepted'" in job_rules
    and "data.status !== 'notApplicable'" in job_rules,
)
check(
    "positive job-module transitions write explicit persisted state",
    job_rules.count("isOpenForWork: false") >= 5
    and "isOpenForWork: true" in job_rules
    and "isOpenForWork: true" in root_rules_test
    and "isOpenForWork: false" in root_rules_test,
)
check(
    "Dart contracts cover online lifecycle and Rules expression routing",
    "direct Firestore lifecycle transitions persist the open-state invariant"
        in lifecycle_contract
    and "R1.14 Firestore expression-budget contract" in contract,
)
check(
    "laboratory emits R1.14 evidence name",
    'CRM3_V42_R1_14_CANONICAL_LOCAL_LAB_$stamp' in harness,
)
check(
    "Firebase CLI smoke uses capturable output stream",
    'Write-Output "PASS_FIREBASE_CLI_LOAD_SMOKE' in harness
    and 'Write-Host "PASS_FIREBASE_CLI_LOAD_SMOKE' not in harness,
)

print(f"SUMMARY passed={len(PASS)} failed={len(FAIL)} total={len(PASS)+len(FAIL)}")
raise SystemExit(1 if FAIL else 0)
