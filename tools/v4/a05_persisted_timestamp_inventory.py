#!/usr/bin/env python3
"""Verify and print the governed A-05 persisted timestamp inventory."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from dart_structural_audit import strip_strings_and_comments


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance" / "a05-persisted-timestamp-surface-v1.json"


def _git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _function_body(path: Path, marker: str) -> str:
    source = path.read_text(encoding="utf-8")
    cleaned = strip_strings_and_comments(source)
    marker_offset = cleaned.find(marker)
    if marker_offset < 0:
        raise ValueError(f"missing decoder marker {marker!r}")
    open_offset = -1
    parenthesis_depth = 0
    for offset in range(marker_offset, len(cleaned)):
        token = cleaned[offset]
        if token == "(":
            parenthesis_depth += 1
        elif token == ")":
            parenthesis_depth -= 1
        elif token == "{" and parenthesis_depth == 0:
            open_offset = offset
            break
    if open_offset < 0:
        raise ValueError(f"missing decoder body for {marker!r}")
    depth = 0
    for offset in range(open_offset, len(cleaned)):
        token = cleaned[offset]
        if token == "{":
            depth += 1
        elif token == "}":
            depth -= 1
            if depth == 0:
                return source[open_offset : offset + 1]
    raise ValueError(f"unterminated decoder body for {marker!r}")


def _reader_fields(body: str, reader: str) -> list[str]:
    pattern = re.compile(
        rf"{reader}\(\s*(?:map|data|composer)\['([^']+)'\]\s*,"
        rf".*?field:\s*'([^']+)'",
        re.DOTALL,
    )
    fields: list[str] = []
    for value_field, named_field in pattern.findall(body):
        if value_field != named_field:
            raise ValueError(
                f"timestamp input {value_field!r} is labelled as {named_field!r}"
            )
        fields.append(value_field)
    return fields


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    inventory: list[dict[str, object]] = []
    classified_decoders = {
        (entry["decoderFile"], entry["decoderMarker"])
        for entry in manifest["decoders"]
    }

    for entry in manifest["decoders"]:
        decoder_path = ROOT / entry["decoderFile"]
        reader_path = ROOT / entry["readerFile"]
        try:
            decoder_body = _function_body(decoder_path, entry["decoderMarker"])
            reader_body = _function_body(reader_path, entry["readerFunction"])
        except (OSError, ValueError) as exc:
            failures.append(f"{entry['id']}: {exc}")
            continue

        required = _reader_fields(reader_body, "readRequiredPersistedDateTime")
        optional = _reader_fields(reader_body, "readOptionalPersistedDateTime")
        expected_required = entry["requiredFields"]
        expected_optional = entry["optionalFields"]
        if required != expected_required:
            failures.append(
                f"{entry['id']}: required fields {required} != {expected_required}"
            )
        if optional != expected_optional:
            failures.append(
                f"{entry['id']}: optional fields {optional} != {expected_optional}"
            )

        binding = entry["binding"]
        if binding is not None:
            call_count = len(re.findall(rf"\b{entry['readerFunction']}\s*\(", decoder_body))
            if call_count != 1:
                failures.append(
                    f"{entry['id']}: decoder calls {entry['readerFunction']} "
                    f"{call_count} times"
                )
            for field in [*expected_required, *expected_optional]:
                assignment = re.compile(
                    rf"\.\.{re.escape(field)}\s*=\s*{re.escape(binding)}\.{re.escape(field)}\b"
                )
                if assignment.search(decoder_body) is None:
                    failures.append(
                        f"{entry['id']}: decoder does not bind {field} from {binding}"
                    )

        forbidden = {
            "local-clock fallback": "DateTime.now()",
            "permissive timestamp parser": "_parseTimestamp(",
            "inline timestamp parse": "DateTime.tryParse(",
        }
        for label, token in forbidden.items():
            if token in decoder_body:
                failures.append(f"{entry['id']}: {label} remains")

        inventory.append(
            {
                "id": entry["id"],
                "decoderFile": entry["decoderFile"],
                "readerFile": entry["readerFile"],
                "readerFunction": entry["readerFunction"],
                "requiredFields": required,
                "optionalFields": optional,
                "decoderSha256": hashlib.sha256(
                    decoder_path.read_bytes()
                ).hexdigest(),
                "readerSha256": hashlib.sha256(reader_path.read_bytes()).hexdigest(),
            }
        )

    unclassified_risk_sites: list[dict[str, str]] = []
    factory_pattern = re.compile(r"factory\s+([A-Za-z_]\w*)\.fromMap\s*\(")
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        cleaned = strip_strings_and_comments(source)
        for match in factory_pattern.finditer(cleaned):
            marker = f"factory {match.group(1)}.fromMap"
            body = _function_body(path, marker)
            risks = [
                token
                for token in ("_parseTimestamp(", "DateTime.tryParse(", "DateTime.now()")
                if token in body
            ]
            if risks and (relative, marker) not in classified_decoders:
                unclassified_risk_sites.append(
                    {"file": relative, "decoderMarker": marker, "risks": ",".join(risks)}
                )

    if unclassified_risk_sites:
        failures.append(
            "unclassified fromMap timestamp-risk sites remain: "
            + ", ".join(
                f"{item['file']}::{item['decoderMarker']}"
                for item in unclassified_risk_sites
            )
        )

    report = {
        "inventoryVersion": manifest["schemaVersion"],
        "findingId": manifest["findingId"],
        "sourceCommit": _git("rev-parse", "HEAD"),
        "workingTreeClean": not bool(_git("status", "--porcelain")),
        "decoderCount": len(inventory),
        "requiredFieldCount": sum(
            len(item["requiredFields"]) for item in inventory
        ),
        "optionalFieldCount": sum(
            len(item["optionalFields"]) for item in inventory
        ),
        "decoders": inventory,
        "unclassifiedRiskSites": unclassified_risk_sites,
        "result": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
