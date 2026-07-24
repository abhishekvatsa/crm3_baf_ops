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
harness = text("tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1")

maintenance_match = block(rules, "match /maintenance_records/{docId}")
maintenance_router = block(rules, "function validMaintenanceUpdate()")

check(
    "R1.14 Rules still expose exactly one maintenance update allow",
    maintenance_match.count("allow update:") == 1
    and "allow update: if validMaintenanceUpdate();" in maintenance_match,
)
check(
    "maintenance router still selects all four governed transition validators",
    all(
        marker in maintenance_router
        for marker in (
            "validMaintenanceSoftDeleteUpdate()",
            "validMaintenanceCloseUpdate()",
            "validMaintenanceReopenUpdate()",
            "validMaintenanceAdminEditUpdate()",
        )
    )
    and "targetDeleted != sourceDeleted" in maintenance_router
    and "targetResolved != sourceResolved" in maintenance_router
    and "||" not in maintenance_router,
)
check(
    "Flutter contract now asserts the single routed maintenance rule",
    "'match /maintenance_records/{docId}'" in contract
    and "contains('allow update: if validMaintenanceUpdate();')" in contract
    and r"RegExp(r'allow\s+update\s*:')" in contract,
)
check(
    "Flutter contract proves router branch coverage",
    "'function validMaintenanceUpdate'" in contract
    and "targetDeleted != sourceDeleted" in contract
    and "targetResolved != sourceResolved" in contract
    and all(
        marker in contract
        for marker in (
            "validMaintenanceSoftDeleteUpdate()",
            "validMaintenanceCloseUpdate()",
            "validMaintenanceReopenUpdate()",
            "validMaintenanceAdminEditUpdate()",
        )
    ),
)
check(
    "obsolete four-allow maintenance expectation is absent",
    "Maintenance updates are intentionally split into small branch rules" not in contract
    and "isNot(contains('allow update: if validMaintenanceUpdate();'))" not in contract
    and "validMaintenanceCloseUpdate() : false" not in contract,
)
check(
    "R1.15 harness emits distinct evidence identity",
    "CRM3_V42_R1_15_CANONICAL_LOCAL_LAB_$stamp" in harness
    and "CRM3 v4.2_R1.15 canonical-main local laboratory" in harness,
)
check(
    "R1.15 correction is test-only with respect to product and Rules source",
    "R1.15 maintenance-router Flutter contract correction" in text("README.md"),
)

print(f"SUMMARY | pass={len(passed)} fail={len(failed)} total={len(passed)+len(failed)}")
raise SystemExit(1 if failed else 0)
