#!/usr/bin/env python3
"""Verify and print the governed A-05 strict timestamp-reader inventory."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from dart_structural_audit import strip_strings_and_comments


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance" / "a05-persisted-timestamp-surface-v2.json"
READER_TOKENS = (
    "readRequiredPersistedDateTime",
    "readOptionalPersistedDateTime",
)


def _git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _function_span(path: Path, marker: str) -> tuple[int, int, str]:
    source = path.read_text(encoding="utf-8")
    cleaned = strip_strings_and_comments(source)
    marker_offset = cleaned.find(marker)
    if marker_offset < 0:
        raise ValueError(f"missing reader marker {marker!r}")
    if cleaned.find(marker, marker_offset + 1) >= 0:
        raise ValueError(f"reader marker {marker!r} is not unique")

    open_offset = -1
    arrow_offset = -1
    parenthesis_depth = 0
    for offset in range(marker_offset, len(cleaned)):
        token = cleaned[offset]
        if token == "(":
            parenthesis_depth += 1
        elif token == ")":
            parenthesis_depth -= 1
        elif (
            token == "="
            and offset + 1 < len(cleaned)
            and cleaned[offset + 1] == ">"
            and parenthesis_depth == 0
        ):
            arrow_offset = offset
            break
        elif token == "{" and parenthesis_depth == 0:
            open_offset = offset
            break

    if arrow_offset >= 0:
        depths = {"(": 0, "[": 0, "{": 0}
        closing = {")": "(", "]": "[", "}": "{"}
        for offset in range(arrow_offset + 2, len(cleaned)):
            token = cleaned[offset]
            if token in depths:
                depths[token] += 1
            elif token in closing:
                opener = closing[token]
                depths[opener] -= 1
                if depths[opener] < 0:
                    raise ValueError(
                        f"unbalanced expression-bodied reader for {marker!r}"
                    )
            elif token == ";" and all(depth == 0 for depth in depths.values()):
                return marker_offset, offset + 1, source[arrow_offset : offset + 1]
        raise ValueError(f"unterminated expression-bodied reader for {marker!r}")

    if open_offset < 0:
        raise ValueError(f"missing reader body for {marker!r}")
    depth = 0
    for offset in range(open_offset, len(cleaned)):
        token = cleaned[offset]
        if token == "{":
            depth += 1
        elif token == "}":
            depth -= 1
            if depth == 0:
                return marker_offset, offset + 1, source[open_offset : offset + 1]
    raise ValueError(f"unterminated reader body for {marker!r}")


def _reader_fields(body: str, reader: str) -> list[str]:
    pattern = re.compile(
        rf"{reader}\(\s*(?:map|data|composer|json)\['([^']+)'\]\s*,"
        rf".*?field:\s*'([^']+)'",
        re.DOTALL,
    )
    fields: list[str] = []
    for value_field, named_field in pattern.findall(body):
        if value_field != named_field and not named_field.endswith(f".{value_field}"):
            raise ValueError(
                f"timestamp input {value_field!r} is labelled as {named_field!r}"
            )
        fields.append(named_field)
    return fields


def _line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    inventory: list[dict[str, object]] = []
    classified_spans: dict[str, list[tuple[int, int, str]]] = {}

    entries = manifest.get("readers", [])
    if manifest.get("schemaVersion") != 2:
        failures.append("manifest schemaVersion must be 2")
    if not entries:
        failures.append("manifest readers must not be empty")

    required_metadata = (
        "owner",
        "purpose",
        "authorityBoundary",
        "regression",
        "reArmCondition",
    )
    seen_ids: set[str] = set()
    for entry in entries:
        entry_id = entry.get("id", "<missing-id>")
        if entry_id in seen_ids:
            failures.append(f"duplicate reader id {entry_id}")
        seen_ids.add(entry_id)
        for field in required_metadata:
            if not isinstance(entry.get(field), str) or not entry[field].strip():
                failures.append(f"{entry_id}: missing classification field {field}")

        reader_path = ROOT / entry["readerFile"]
        try:
            start, end, body = _function_span(reader_path, entry["readerMarker"])
            required = _reader_fields(body, "readRequiredPersistedDateTime")
            optional = _reader_fields(body, "readOptionalPersistedDateTime")
        except (OSError, ValueError) as exc:
            failures.append(f"{entry_id}: {exc}")
            continue

        expected_required = entry["requiredFields"]
        expected_optional = entry["optionalFields"]
        if required != expected_required:
            failures.append(
                f"{entry_id}: required fields {required} != {expected_required}"
            )
        if optional != expected_optional:
            failures.append(
                f"{entry_id}: optional fields {optional} != {expected_optional}"
            )
        if not required and not optional:
            failures.append(f"{entry_id}: classified body has no strict timestamp calls")

        relative = reader_path.relative_to(ROOT).as_posix()
        classified_spans.setdefault(relative, []).append((start, end, entry_id))
        for label, token in {
            "local-clock fallback": "DateTime.now()",
            "inline permissive parser": "DateTime.tryParse(",
        }.items():
            if token in body:
                failures.append(f"{entry_id}: {label} remains")

        inventory.append(
            {
                "id": entry_id,
                "readerFile": relative,
                "readerMarker": entry["readerMarker"],
                "authorityBoundary": entry["authorityBoundary"],
                "requiredFields": required,
                "optionalFields": optional,
                "readerSha256": hashlib.sha256(reader_path.read_bytes()).hexdigest(),
            }
        )

    unclassified_reader_sites: list[dict[str, object]] = []
    duplicate_reader_sites: list[dict[str, object]] = []
    direct_call_count = 0
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        if path.name.endswith(".g.dart") or path == ROOT / (
            "lib/core/serialization/persisted_data_reader.dart"
        ):
            continue
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        cleaned = strip_strings_and_comments(source)
        spans = classified_spans.get(relative, [])
        for token in READER_TOKENS:
            for match in re.finditer(rf"\b{token}\s*\(", cleaned):
                direct_call_count += 1
                owners = [
                    entry_id
                    for start, end, entry_id in spans
                    if start <= match.start() < end
                ]
                site = {
                    "file": relative,
                    "line": _line_number(source, match.start()),
                    "reader": token,
                }
                if not owners:
                    unclassified_reader_sites.append(site)
                elif len(owners) > 1:
                    duplicate_reader_sites.append({**site, "owners": owners})

    if unclassified_reader_sites:
        failures.append(
            "unclassified strict persisted timestamp calls remain: "
            + ", ".join(
                f"{item['file']}:{item['line']}" for item in unclassified_reader_sites
            )
        )
    if duplicate_reader_sites:
        failures.append("strict persisted timestamp calls have duplicate ownership")

    direct_parser_candidates: list[dict[str, object]] = []
    parser_pattern = re.compile(
        r"\bDateTime\.(?:tryParse|parse|fromMillisecondsSinceEpoch)\s*\("
    )
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        cleaned = strip_strings_and_comments(source)
        for match in parser_pattern.finditer(cleaned):
            direct_parser_candidates.append(
                {
                    "file": relative,
                    "line": _line_number(source, match.start()),
                    "expression": match.group(0).strip(),
                }
            )

    report = {
        "inventoryVersion": manifest["schemaVersion"],
        "findingId": manifest["findingId"],
        "scope": manifest["scope"],
        "sourceCommit": _git("rev-parse", "HEAD"),
        "workingTreeClean": not bool(_git("status", "--porcelain")),
        "readerCount": len(inventory),
        "directCallCount": direct_call_count,
        "requiredFieldCount": sum(len(item["requiredFields"]) for item in inventory),
        "optionalFieldCount": sum(len(item["optionalFields"]) for item in inventory),
        "readers": inventory,
        "unclassifiedReaderSites": unclassified_reader_sites,
        "duplicateReaderSites": duplicate_reader_sites,
        "directParserCandidates": direct_parser_candidates,
        "result": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
