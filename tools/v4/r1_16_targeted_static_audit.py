#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
passed: list[str] = []
failed: list[str] = []


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def check(name: str, condition: bool, detail: str = "") -> None:
    line = f"{name}" + (f" | {detail}" if detail else "")
    if condition:
        passed.append(name)
        print(f"PASS | {line}")
    else:
        failed.append(name)
        print(f"FAIL | {line}", file=sys.stderr)


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


rules = text("firestore.rules")
contract = text("test/maintenance_lifecycle_replay_contract_test.dart")
budget_contract = text("test/firestore_rules_expression_budget_contract_test.dart")
harness = text("tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1")

maintenance_match = block(rules, "match /maintenance_records/{docId}")

check(
    "R1.15 evidence defect is exactly the marker-owned brace bug",
    "final openBrace = source.indexOf('{', markerIndex + marker.length);" in contract
    and "final openBrace = source.indexOf('{', markerIndex);" not in contract,
)
check(
    "maintenance parser statement matches the passing budget guard",
    contract.count("final openBrace = source.indexOf('{', markerIndex + marker.length);") == 1
    and budget_contract.count("final openBrace = source.indexOf('{', markerIndex + marker.length);") == 1,
)
check(
    "corrected source extraction sees the complete maintenance match",
    maintenance_match.count("allow update:") == 1
    and "allow update: if validMaintenanceUpdate();" in maintenance_match,
)
check(
    "R1.15 router assertions remain intact",
    "'match /maintenance_records/{docId}'" in contract
    and r"RegExp(r'allow\s+update\s*:')" in contract
    and "contains('allow update: if validMaintenanceUpdate();')" in contract
    and "'function validMaintenanceUpdate'" in contract,
)
check(
    "Firestore Rules bytes retain the single routed maintenance update",
    maintenance_match.count("allow update:") == 1
    and "validMaintenanceCloseUpdate()" in rules
    and "validMaintenanceReopenUpdate()" in rules
    and "validMaintenanceSoftDeleteUpdate()" in rules
    and "validMaintenanceAdminEditUpdate()" in rules,
)
check(
    "R1.16 harness emits distinct evidence identity",
    "CRM3_V42_R1_16_CANONICAL_LOCAL_LAB_$stamp" in harness
    and "CRM3 v4.2_R1.16 canonical-main local laboratory" in harness,
)
check(
    "R1.16 documentation preserves emulator and production boundaries",
    "R1.16 maintenance-match parser correction" in text("README.md")
    and "PASS_AUTHORITATIVE_BUILD_AND_EMULATOR" in text("docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md")
    and "shared parser" in text("docs/v4_2_r1/R1_16_MAINTENANCE_MATCH_PARSER_CORRECTION.md").lower(),
)
check(
    "R1.16 correction remains parser-only with respect to authority-bearing source",
    "No Firestore Rules, application, Functions, dependency, Firebase, Android or release-policy bytes are changed" in text("README.md"),
)

print(f"SUMMARY | pass={len(passed)} fail={len(failed)} total={len(passed)+len(failed)}")
raise SystemExit(1 if failed else 0)
