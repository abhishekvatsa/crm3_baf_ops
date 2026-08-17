#!/usr/bin/env python3
"""Discover and enforce the governed A-02 architecture hotspot inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from dart_structural_audit import strip_strings_and_comments


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance" / "a02-architecture-boundaries-v1.json"
SIZE_THRESHOLD = 1200
MIXED_MINIMUM_LINES = 500
MIXED_RESPONSIBILITY_COUNT = 4

RESPONSIBILITY_PATTERNS: dict[str, re.Pattern[str]] = {
    "presentation": re.compile(
        r"\b(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|BuildContext|Widget)\b"
    ),
    "state-orchestration": re.compile(
        r"\b(?:WidgetRef|Ref|AsyncValue|StateNotifier)\b|\bref\.(?:read|watch|listen)\s*\("
    ),
    "repository-contract": re.compile(r"\babstract\s+class\s+\w*Repository\b"),
    "repository-implementation": re.compile(
        r"\bclass\s+\w+\s+(?:implements|extends)\s+\w*Repository\b"
    ),
    "local-persistence": re.compile(
        r"\bIsar\b|\bwriteTxn\s*(?:<[^>]+>)?\s*\(|\bIsarCollection\b"
    ),
    "remote-persistence": re.compile(
        r"\bFirebaseFirestore\b|\bCollectionReference\b|\bDocumentReference\b|\bWriteBatch\b|\brunTransaction\s*\("
    ),
    "serialization": re.compile(
        r"\bjson(?:Decode|Encode)\s*\(|\b(?:fromMap|toMap|fromJson|toJson)\s*\(|\bread(?:Required|Optional|Nullable)Persisted"
    ),
    "authority": re.compile(
        r"\bFirebaseAuth\b|\bAppUser\b|\bisApproved\b|\broles\b|\bcan[A-Z]\w*\b"
    ),
    "command-boundary": re.compile(
        r"\bHttpsCallable\b|\bWorkflowCommand\b|\b\w+CommandService\b"
    ),
    "provider-wiring": re.compile(
        r"\b(?:Provider|StreamProvider|FutureProvider|StateNotifierProvider)(?:\.\w+)?\s*(?:<|\()"
    ),
    "transaction-ownership": re.compile(
        r"\bwriteTxn\s*(?:<[^>]+>)?\s*\(|\brunTransaction\s*\(|\bbatch\s*\("
    ),
}


def _relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _source_files() -> list[Path]:
    roots = [ROOT / "lib" / "features"]
    result: list[Path] = []
    for root in roots:
        for path in root.rglob("*.dart"):
            relative = _relative(path)
            if path.name.endswith(".g.dart"):
                continue
            if "/providers/" not in relative and "/presentation/" not in relative:
                continue
            result.append(path)
    return sorted(result)


def _responsibilities(source: str) -> list[str]:
    cleaned = strip_strings_and_comments(source)
    cleaned = re.sub(
        r"(?m)^(?:import|export|part)\s+.*?;\s*$",
        "",
        cleaned,
    )
    return sorted(
        name
        for name, pattern in RESPONSIBILITY_PATTERNS.items()
        if pattern.search(cleaned)
    )


def _is_hotspot(relative: str, lines: int, responsibilities: list[str]) -> bool:
    values = set(responsibilities)
    direct_presentation_persistence = (
        "/presentation/" in relative
        and bool(values & {"local-persistence", "remote-persistence"})
    )
    mixed_persistence = {
        "local-persistence",
        "remote-persistence",
    }.issubset(values)
    broadly_mixed = (
        lines >= MIXED_MINIMUM_LINES
        and len(values) >= MIXED_RESPONSIBILITY_COUNT
    )
    return (
        lines >= SIZE_THRESHOLD
        or direct_presentation_persistence
        or mixed_persistence
        or broadly_mixed
    )


def discover() -> list[dict[str, object]]:
    inventory: list[dict[str, object]] = []
    for path in _source_files():
        source = path.read_text(encoding="utf-8")
        relative = _relative(path)
        lines = len(source.splitlines())
        responsibilities = _responsibilities(source)
        if not _is_hotspot(relative, lines, responsibilities):
            continue
        inventory.append(
            {
                "path": relative,
                "lines": lines,
                "sha256": hashlib.sha256(source.encode("utf-8")).hexdigest().upper(),
                "responsibilities": responsibilities,
            }
        )
    return inventory


def _valid_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def verify(manifest: dict[str, object], inventory: list[dict[str, object]]) -> list[str]:
    failures: list[str] = []
    if manifest.get("schemaVersion") != 1 or manifest.get("findingId") != "A-02":
        failures.append("manifest identity must be schemaVersion 1 for A-02")
    thresholds = manifest.get("thresholds")
    if thresholds != {
        "sizeLines": SIZE_THRESHOLD,
        "mixedMinimumLines": MIXED_MINIMUM_LINES,
        "mixedResponsibilityCount": MIXED_RESPONSIBILITY_COUNT,
    }:
        failures.append("manifest thresholds do not match the audit implementation")

    discovered = {str(item["path"]): item for item in inventory}
    surfaces = manifest.get("surfaces")
    if not isinstance(surfaces, list):
        return [*failures, "manifest surfaces must be a list"]
    declared: dict[str, dict[str, object]] = {}
    required_text = (
        "path",
        "owner",
        "purpose",
        "authorityBoundary",
        "persistenceOwnership",
        "transactionOwnership",
        "rationale",
        "reArmCondition",
    )
    for raw in surfaces:
        if not isinstance(raw, dict):
            failures.append("every surface must be an object")
            continue
        path = raw.get("path")
        if not _valid_text(path):
            failures.append("surface path is required")
            continue
        relative = str(path)
        if relative in declared:
            failures.append(f"duplicate surface {relative}")
            continue
        declared[relative] = raw
        for field in required_text:
            if not _valid_text(raw.get(field)):
                failures.append(f"{relative}: missing {field}")
        if raw.get("disposition") not in {"decomposed", "bounded-exception"}:
            failures.append(f"{relative}: invalid disposition")
        actual = discovered.get(relative)
        if actual is None:
            failures.append(f"{relative}: declared surface is not a current hotspot")
            continue
        if raw.get("responsibilities") != actual["responsibilities"]:
            failures.append(
                f"{relative}: responsibility classification drift; "
                f"expected={raw.get('responsibilities')} actual={actual['responsibilities']}"
            )
        maximum = raw.get("maximumLines")
        if not isinstance(maximum, int) or maximum < int(actual["lines"]):
            failures.append(
                f"{relative}: maximumLines {maximum} is below current {actual['lines']}"
            )
        tests = raw.get("regressionTests")
        if not isinstance(tests, list) or not tests:
            failures.append(f"{relative}: regressionTests must be non-empty")
        else:
            for test in tests:
                if not _valid_text(test) or not (ROOT / str(test)).is_file():
                    failures.append(f"{relative}: missing regression test {test}")
        source = (ROOT / relative).read_text(encoding="utf-8")
        for marker in raw.get("requiredMarkers", []):
            if not _valid_text(marker) or str(marker) not in source:
                failures.append(f"{relative}: missing required marker {marker}")
        for marker in raw.get("forbiddenMarkers", []):
            if _valid_text(marker) and str(marker) in source:
                failures.append(f"{relative}: forbidden marker returned: {marker}")

    missing = sorted(set(discovered) - set(declared))
    extra = sorted(set(declared) - set(discovered))
    if missing:
        failures.append(f"unclassified hotspots: {missing}")
    if extra:
        failures.append(f"stale hotspot declarations: {extra}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--discover", action="store_true")
    args = parser.parse_args()
    inventory = discover()
    if args.discover:
        print(json.dumps({"hotspots": inventory}, indent=2))
        return 0
    if not MANIFEST.is_file():
        print(json.dumps({"result": "FAIL", "failures": ["manifest missing"]}, indent=2))
        return 1
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures = verify(manifest, inventory)
    report = {
        "result": "FAIL" if failures else "PASS",
        "findingId": "A-02",
        "gitHead": _git_head(),
        "hotspotCount": len(inventory),
        "inventoryDigest": hashlib.sha256(
            json.dumps(inventory, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest().upper(),
        "hotspots": inventory,
        "failures": failures,
    }
    print(json.dumps(report, indent=2))
    return 1 if failures else 0


def _git_head() -> str:
    import subprocess

    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())
