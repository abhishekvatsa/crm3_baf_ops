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
CANDIDATE_MANIFEST = (
    ROOT / "governance" / "a05-direct-timestamp-candidate-classification-v1.json"
)
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
    indexed_pattern = re.compile(
        rf"{reader}\(\s*(?:map|data|composer|json|normalized|result|payload)\['([^']+)'\]\s*,"
        rf".*?field:\s*'([^']+)'",
        re.DOTALL,
    )
    scalar_pattern = re.compile(
        rf"{reader}\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,"
        rf".*?field:\s*'([^']+)'",
        re.DOTALL,
    )
    fields: list[tuple[int, str]] = []
    for match in indexed_pattern.finditer(body):
        value_field, named_field = match.groups()
        if value_field != named_field and not named_field.endswith(f".{value_field}"):
            raise ValueError(
                f"timestamp input {value_field!r} is labelled as {named_field!r}"
            )
        fields.append((match.start(), named_field))
    for match in scalar_pattern.finditer(body):
        input_name, named_field = match.groups()
        if input_name != "value":
            raise ValueError(
                f"unsupported scalar timestamp input {input_name!r}"
            )
        fields.append((match.start(), named_field))
    return [field for _, field in sorted(fields)]


def _line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def _calls(body: str, reader: str) -> list[str]:
    """Extract complete calls without interpreting string contents as syntax."""
    cleaned = strip_strings_and_comments(body)
    result = []
    for match in re.finditer(rf"\b{re.escape(reader)}\s*\(", cleaned):
        depth = 1
        for offset in range(match.end(), len(cleaned)):
            if cleaned[offset] == "(":
                depth += 1
            elif cleaned[offset] == ")":
                depth -= 1
                if depth == 0:
                    result.append(body[match.start():offset + 1])
                    break
        else:
            raise ValueError(f"unterminated {reader} call")
    return result


def _body_digest(body: str) -> str:
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def _reviewed_dynamic_calls(entry: dict, body: str) -> list[dict]:
    """A dynamic label is an explicitly pinned exception, never a wildcard."""
    declarations = entry.get("dynamicCalls", [])
    if not isinstance(declarations, list):
        raise ValueError("dynamicCalls must be a list")
    if declarations and entry.get("readerBodySha256") != _body_digest(body):
        raise ValueError("reviewed dynamic reader body changed")
    actual = []
    for reader in READER_TOKENS:
        for call in _calls(body, reader):
            try:
                literal_fields = _reader_fields(call, reader)
            except ValueError as error:
                if not str(error).startswith("unsupported scalar timestamp input"):
                    raise  # An incorrectly labelled literal is never exempted.
                literal_fields = []
            if not literal_fields:
                actual.append((reader, call))
    declared = []
    for call in declarations:
        fields = call.get("reviewedFields")
        if (call.get("reader") not in READER_TOKENS or
                not isinstance(call.get("callSource"), str) or
                not isinstance(fields, list) or not fields or
                any(not isinstance(field, str) or not field.strip() for field in fields) or
                len(set(fields)) != len(fields)):
            raise ValueError("dynamic call requires exact source and unique reviewed fields")
        literal_fields = re.findall(r"\bfield:\s*'([^']+)'", call["callSource"])
        if not set(literal_fields).issubset(fields):
            raise ValueError("dynamic call contains an unreviewed literal field")
        declared.append((call["reader"], call["callSource"]))
    if sorted(actual) != sorted(declared):
        raise ValueError("dynamic strict timestamp call count or source changed")
    return declarations


def _without_reviewed_calls(body: str, declarations: list[dict]) -> str:
    reviewed = {(call["reader"], call["callSource"])
                for call in declarations}
    masked = body
    for reader in READER_TOKENS:
        for call in _calls(body, reader):
            if (reader, call) in reviewed:
                masked = masked.replace(call, " " * len(call))
    return masked


def _reviewed_wrapper_callers(entry: dict, root: Path, start: int, end: int) -> None:
    wrapper = entry.get("wrapperName")
    if wrapper is None:
        return
    if not isinstance(wrapper, str) or not re.fullmatch(r"[A-Za-z_]\w*", wrapper):
        raise ValueError("invalid reviewed wrapper name")
    marker = entry.get("readerMarker", "")
    declarations = list(re.finditer(rf"\b{re.escape(wrapper)}\s*\(", marker))
    if len(declarations) != 1:
        raise ValueError("wrapper reader marker must identify its declaration")
    declaration_offset = start + declarations[0].start()
    callers = entry.get("reviewedCallers", [])
    if not callers:
        raise ValueError("dynamic wrapper needs explicit reviewed callers")
    spans = {}
    for caller in callers:
        path = root / caller["file"]
        first, last, body = _function_span(path, caller["marker"])
        if caller.get("bodySha256") != _body_digest(body):
            raise ValueError(f"reviewed wrapper caller changed: {caller['file']} {caller['marker']}")
        calls = _calls(body, wrapper)
        fields = caller.get("fields")
        if (type(caller.get("callCount")) is not int or
                caller["callCount"] < 1 or len(calls) != caller["callCount"] or
                not isinstance(fields, list) or not fields or
                any(not isinstance(field, str) or not field.strip() for field in fields) or
                len(set(fields)) != len(fields)):
            raise ValueError("wrapper caller requires exact call count and reviewed fields")
        literal_fields = [field for call in calls
                          for field in re.findall(r"\bfield:\s*'([^']+)'", call)]
        if not set(literal_fields).issubset(fields):
            raise ValueError("wrapper caller contains an unreviewed literal field")
        spans.setdefault(caller["file"], []).append((first, last))
    for path in sorted((root / "lib").rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(root).as_posix()
        cleaned = strip_strings_and_comments(path.read_text(encoding="utf-8"))
        if relative == entry["readerFile"] and not cleaned.startswith(marker, start):
            raise ValueError("wrapper declaration no longer matches its reader marker")
        # A tear-off can pass the wrapper to an alias or callback without a direct
        # call here. Every executable identifier reference needs reviewed coverage.
        for match in re.finditer(rf"\b{re.escape(wrapper)}\b", cleaned):
            if relative == entry["readerFile"] and match.start() == declaration_offset:
                continue  # Only the declaration name, never its entire body.
            owners = sum(first <= match.start() < last
                         for first, last in spans.get(relative, []))
            if owners != 1:
                raise ValueError(f"wrapper reference needs exactly one reviewed caller: {relative}:{_line_number(cleaned, match.start())}")


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    candidate_manifest = json.loads(CANDIDATE_MANIFEST.read_text(encoding="utf-8"))
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
            dynamic = _reviewed_dynamic_calls(entry, body)
            literal_body = _without_reviewed_calls(body, dynamic)
            required = _reader_fields(literal_body, "readRequiredPersistedDateTime")
            optional = _reader_fields(literal_body, "readOptionalPersistedDateTime")
            _reviewed_wrapper_callers(entry, ROOT, start, end)
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
        if not required and not optional and not dynamic:
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
                **({"dynamicCalls": dynamic,
                    "readerBodySha256": entry["readerBodySha256"],
                    "reviewedCallers": entry.get("reviewedCallers", [])}
                   if dynamic else {}),
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

    allowed_classifications = {
        "STRICT_READER_IMPLEMENTATION",
        "FAIL_CLOSED_AUTHORITY_PARSER",
        "NON_PERSISTED_RUNTIME_SENTINEL",
        "TYPED_LOCAL_STORAGE_INITIALIZER",
        "SORT_ONLY_NULL_ORDERING_SENTINEL",
        "DISPLAY_ONLY_BEST_EFFORT",
        "TYPED_COMMAND_WIRE_SERIALIZATION",
    }
    candidate_classifications: dict[tuple[str, str, int], dict[str, object]] = {}
    classification_groups = candidate_manifest.get("classifications", [])
    if candidate_manifest.get("schemaVersion") != 1:
        failures.append("candidate manifest schemaVersion must be 1")
    if candidate_manifest.get("findingId") != manifest.get("findingId"):
        failures.append("candidate manifest findingId must match reader manifest")
    if not classification_groups:
        failures.append("candidate manifest classifications must not be empty")

    candidate_metadata = (
        "owner",
        "purpose",
        "authorityBoundary",
        "regression",
        "reArmCondition",
    )
    seen_group_ids: set[str] = set()
    for group in classification_groups:
        group_id = group.get("id", "<missing-id>")
        if group_id in seen_group_ids:
            failures.append(f"duplicate candidate classification id {group_id}")
        seen_group_ids.add(group_id)
        classification = group.get("classification")
        if classification not in allowed_classifications:
            failures.append(f"{group_id}: invalid classification {classification!r}")
        for field in candidate_metadata:
            if not isinstance(group.get(field), str) or not group[field].strip():
                failures.append(f"{group_id}: missing classification field {field}")
        sites = group.get("sites", [])
        if not sites:
            failures.append(f"{group_id}: classified sites must not be empty")
        for site in sites:
            key = (
                site.get("file"),
                site.get("expression"),
                site.get("occurrence"),
            )
            if not isinstance(key[0], str) or not isinstance(key[1], str):
                failures.append(f"{group_id}: candidate site file/expression is invalid")
                continue
            if not isinstance(key[2], int) or key[2] < 1:
                failures.append(f"{group_id}: candidate occurrence must be positive")
                continue
            if key in candidate_classifications:
                failures.append(
                    f"candidate site {key[0]} {key[1]} #{key[2]} has duplicate ownership"
                )
                continue
            candidate_classifications[key] = {
                "classificationId": group_id,
                "classification": classification,
                "authorityBoundary": group.get("authorityBoundary"),
            }

    direct_parser_candidates: list[dict[str, object]] = []
    parser_pattern = re.compile(
        r"\bDateTime\.(?:tryParse|parse|fromMillisecondsSinceEpoch|"
        r"fromMicrosecondsSinceEpoch)\s*\("
    )
    candidate_occurrences: dict[tuple[str, str], int] = {}
    discovered_candidate_keys: set[tuple[str, str, int]] = set()
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        cleaned = strip_strings_and_comments(source)
        for match in parser_pattern.finditer(cleaned):
            expression = match.group(0).strip()
            occurrence_key = (relative, expression)
            occurrence = candidate_occurrences.get(occurrence_key, 0) + 1
            candidate_occurrences[occurrence_key] = occurrence
            candidate_key = (relative, expression, occurrence)
            discovered_candidate_keys.add(candidate_key)
            direct_parser_candidates.append({
                "file": relative,
                "line": _line_number(source, match.start()),
                "expression": expression,
                "occurrence": occurrence,
                **candidate_classifications.get(candidate_key, {}),
            })

    unclassified_direct_parser_candidates = [
        candidate
        for candidate in direct_parser_candidates
        if "classification" not in candidate
    ]
    stale_direct_parser_classifications = [
        {
            "file": key[0],
            "expression": key[1],
            "occurrence": key[2],
            **candidate_classifications[key],
        }
        for key in sorted(set(candidate_classifications) - discovered_candidate_keys)
    ]
    if unclassified_direct_parser_candidates:
        failures.append(
            "unclassified direct timestamp candidates remain: "
            + ", ".join(
                f"{item['file']}:{item['line']}"
                for item in unclassified_direct_parser_candidates
            )
        )
    if stale_direct_parser_classifications:
        failures.append("stale direct timestamp candidate classifications remain")

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
        "directParserCandidateCount": len(direct_parser_candidates),
        "directParserClassificationGroupCount": len(classification_groups),
        "unclassifiedDirectParserCandidates": unclassified_direct_parser_candidates,
        "staleDirectParserClassifications": stale_direct_parser_classifications,
        "result": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
