#!/usr/bin/env python3
"""Verify and print the governed A-05 non-timestamp decoder inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True

from dart_structural_audit import strip_strings_and_comments


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance" / "a05-persisted-decoder-surface-v1.json"
TIMESTAMP_TOOL = ROOT / "tools" / "v4" / "a05_persisted_timestamp_inventory.py"
SHARED_READER = "lib/core/serialization/persisted_data_reader.dart"

STRICT_PATTERN = re.compile(
    r"\bread(?:Required|Optional|Nullable)Persisted"
    r"(?:String|Bool|Int|Double|StringList|Enum)\s*\("
    r"|\bread(?:Required|Optional)JsonObject(?:List)?\s*\("
)
RAW_JSON_PATTERN = re.compile(r"\bjsonDecode\s*\(")
DECODER_FLOW_PATTERN = re.compile(
    r"\bjsonDecode\s*\("
    r"|\bread(?:Required|Optional|Nullable)Persisted\w*\s*\("
    r"|\bread(?:Required|Optional)JsonObject(?:List)?\s*\("
    r"|\b(?:decode\w*|readRemote\w*|readValidated\w*|parse\w*)\s*\("
    r"|\.(?:fromMap|fromFirestore|fromJson|fromCallableData|fromPayloads|fromRawJson)\s*\("
)
RISK_PATTERNS = {
    "raw-json": RAW_JSON_PATTERN,
    "catch": re.compile(r"\bcatch\s*\("),
    "literal-fallback": re.compile(
        r"\?\?\s*(?:true|false|-?\d+(?:\.\d+)?|''|\"\")"
    ),
    "boolean-coercion": re.compile(r"(?:==\s*true|!=\s*false)"),
    "numeric-coercion": re.compile(r"\.(?:toInt|toDouble)\s*\("),
    "direct-parser": re.compile(
        r"\b(?:DateTime|int|double)\.(?:tryParse|parse)\s*\("
    ),
    "string-coercion": re.compile(r"\.toString\s*\(\s*\)"),
}


def _git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, check=True, capture_output=True, text=True
    )
    return result.stdout.strip()


def _relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _dart_sources() -> list[Path]:
    return sorted(
        path
        for path in (ROOT / "lib").rglob("*.dart")
        if not path.name.endswith(".g.dart")
    )


def _normalise_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def _risk_candidates(source: str) -> list[dict[str, object]]:
    candidates: list[dict[str, object]] = []
    occurrence: Counter[tuple[str, str]] = Counter()
    for line_number, line in enumerate(source.splitlines(), start=1):
        normalised = _normalise_line(line)
        if not normalised or normalised.startswith("//"):
            continue
        for kind, pattern in RISK_PATTERNS.items():
            for match in pattern.finditer(line):
                expression = _normalise_line(match.group(0))
                key = (kind, expression)
                occurrence[key] += 1
                candidates.append(
                    {
                        "kind": kind,
                        "line": line_number,
                        "expression": expression,
                        "occurrence": occurrence[key],
                        "context": normalised,
                    }
                )
    return candidates


def _risk_fingerprint(candidates: list[dict[str, object]]) -> str:
    payload = "\n".join(
        f"{item['kind']}|{item['expression']}|{item['occurrence']}|{item['context']}"
        for item in candidates
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _brace_pairs(cleaned: str) -> tuple[dict[int, int], dict[int, int]]:
    opens: list[int] = []
    forward: dict[int, int] = {}
    backward: dict[int, int] = {}
    for index, character in enumerate(cleaned):
        if character == "{":
            opens.append(index)
        elif character == "}" and opens:
            opening = opens.pop()
            forward[opening] = index
            backward[index] = opening
    return forward, backward


def _decoder_catch_sites(relative: str, source: str) -> list[dict[str, object]]:
    cleaned = strip_strings_and_comments(source)
    forward, backward = _brace_pairs(cleaned)
    sites: list[dict[str, object]] = []
    occurrences: Counter[str] = Counter()
    for match in re.finditer(r"\bcatch\s*\([^)]*\)\s*\{", cleaned):
        prior_close = cleaned.rfind("}", 0, match.start())
        try_open = backward.get(prior_close)
        catch_open = cleaned.find("{", match.start(), match.end())
        catch_close = forward.get(catch_open)
        if try_open is None or catch_close is None:
            continue
        prefix = cleaned[max(0, try_open - 32) : try_open]
        if re.search(r"\btry\s*$", prefix) is None:
            continue
        try_body = source[try_open + 1 : prior_close]
        decoder_matches = list(DECODER_FLOW_PATTERN.finditer(try_body))
        if not decoder_matches:
            continue
        site_source = source[try_open : catch_close + 1]
        normalized_site = re.sub(r"\s+", " ", site_source).strip()
        occurrences[normalized_site] += 1
        fingerprint = hashlib.sha256(
            f"{relative}\n{occurrences[normalized_site]}\n{normalized_site}".encode(
                "utf-8"
            )
        ).hexdigest()
        decoder_contexts: list[str] = []
        for decoder in decoder_matches:
            line_start = try_body.rfind("\n", 0, decoder.start()) + 1
            line_end = try_body.find("\n", decoder.end())
            if line_end < 0:
                line_end = len(try_body)
            context = _normalise_line(try_body[line_start:line_end])
            if context and context not in decoder_contexts:
                decoder_contexts.append(context)
        sites.append(
            {
                "file": relative,
                "line": cleaned.count("\n", 0, match.start()) + 1,
                "catch": _normalise_line(source[match.start() : catch_open]),
                "occurrence": occurrences[normalized_site],
                "decoderContexts": decoder_contexts,
                "siteFingerprint": fingerprint,
            }
        )
    return sites


def _write_fingerprints(manifest: dict[str, object], values: dict[str, str]) -> None:
    for surface in manifest["surfaces"]:
        surface["riskFingerprint"] = values[surface["id"]]
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write-fingerprints",
        action="store_true",
        help="mechanically refresh exact risk-candidate fingerprints",
    )
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    if manifest.get("schemaVersion") != 1:
        failures.append("manifest schemaVersion must be 1")
    if manifest.get("findingId") != "A-05":
        failures.append("manifest findingId must be A-05")

    timestamp = subprocess.run(
        [sys.executable, str(TIMESTAMP_TOOL)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    timestamp_report: dict[str, object] = {}
    try:
        timestamp_report = json.loads(timestamp.stdout)
    except json.JSONDecodeError:
        failures.append("timestamp inventory did not return JSON")
    if timestamp.returncode != 0 or timestamp_report.get("result") != "PASS":
        failures.append("inherited timestamp inventory failed")

    sources = _dart_sources()
    discovered_strict: set[str] = set()
    discovered_json: set[str] = set()
    for path in sources:
        relative = _relative(path)
        if relative == SHARED_READER:
            continue
        source = path.read_text(encoding="utf-8")
        if STRICT_PATTERN.search(source):
            discovered_strict.add(relative)
        if RAW_JSON_PATTERN.search(source):
            discovered_json.add(relative)
    discovered = discovered_strict | discovered_json
    discovered_catch_sites: list[dict[str, object]] = []
    for path in sources:
        relative = _relative(path)
        discovered_catch_sites.extend(
            _decoder_catch_sites(relative, path.read_text(encoding="utf-8"))
        )

    required_metadata = (
        "id",
        "file",
        "classification",
        "owner",
        "authorityBoundary",
        "malformedDisposition",
        "compatibility",
        "regression",
        "reArmCondition",
        "riskFingerprint",
    )
    seen_ids: set[str] = set()
    seen_files: set[str] = set()
    inventory: list[dict[str, object]] = []
    fingerprints: dict[str, str] = {}
    for surface in manifest.get("surfaces", []):
        surface_id = surface.get("id", "<missing-id>")
        for field in required_metadata:
            if not isinstance(surface.get(field), str) or not surface[field].strip():
                failures.append(f"{surface_id}: missing metadata {field}")
        if surface_id in seen_ids:
            failures.append(f"duplicate surface id {surface_id}")
        seen_ids.add(surface_id)
        relative = surface.get("file", "")
        if relative in seen_files:
            failures.append(f"duplicate surface file {relative}")
        seen_files.add(relative)
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"{surface_id}: missing file {relative}")
            continue
        source = path.read_text(encoding="utf-8")
        for marker in surface.get("markers", []):
            count = source.count(marker)
            if count != 1:
                failures.append(
                    f"{surface_id}: marker {marker!r} occurs {count} times"
                )
        candidates = _risk_candidates(source)
        fingerprint = _risk_fingerprint(candidates)
        fingerprints[surface_id] = fingerprint
        expected = surface.get("riskFingerprint")
        if not args.write_fingerprints and expected != fingerprint:
            failures.append(f"{surface_id}: risk fingerprint changed")
        inventory.append(
            {
                "id": surface_id,
                "file": relative,
                "classification": surface.get("classification"),
                "authorityBoundary": surface.get("authorityBoundary"),
                "malformedDisposition": surface.get("malformedDisposition"),
                "compatibility": surface.get("compatibility"),
                "strictReaderConsumer": relative in discovered_strict,
                "rawJsonConsumer": relative in discovered_json,
                "riskCandidateCount": len(candidates),
                "riskCandidateKinds": dict(
                    sorted(Counter(item["kind"] for item in candidates).items())
                ),
                "riskFingerprint": fingerprint,
                "sourceSha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "riskCandidates": candidates,
            }
        )

    unclassified = sorted(discovered - seen_files)
    if unclassified:
        failures.append("unclassified persisted decoder files: " + ", ".join(unclassified))

    catch_required_metadata = (
        "id",
        "file",
        "siteFingerprint",
        "classification",
        "purpose",
        "authorityBoundary",
        "mutability",
        "dataScope",
        "malformedDisposition",
        "regression",
        "reArmCondition",
    )
    catch_policies = manifest.get("catchSites", [])
    policy_by_fingerprint: dict[str, dict[str, object]] = {}
    catch_ids: set[str] = set()
    for policy in catch_policies:
        catch_id = policy.get("id", "<missing-id>")
        for field in catch_required_metadata:
            if not isinstance(policy.get(field), str) or not policy[field].strip():
                failures.append(f"{catch_id}: missing catch metadata {field}")
        if catch_id in catch_ids:
            failures.append(f"duplicate catch id {catch_id}")
        catch_ids.add(catch_id)
        fingerprint = policy.get("siteFingerprint", "")
        if fingerprint in policy_by_fingerprint:
            failures.append(f"duplicate catch fingerprint {fingerprint}")
        policy_by_fingerprint[fingerprint] = policy

    discovered_fingerprints = {
        str(site["siteFingerprint"]) for site in discovered_catch_sites
    }
    unclassified_catches = [
        site
        for site in discovered_catch_sites
        if site["siteFingerprint"] not in policy_by_fingerprint
    ]
    stale_catch_policies = sorted(
        set(policy_by_fingerprint) - discovered_fingerprints
    )
    if unclassified_catches:
        failures.append(
            "unclassified decoder catch sites: "
            + ", ".join(
                f"{site['file']}:{site['line']}" for site in unclassified_catches
            )
        )
    if stale_catch_policies:
        failures.append(
            "stale decoder catch policies: " + ", ".join(stale_catch_policies)
        )

    governed_catch_sites = []
    for site in discovered_catch_sites:
        policy = policy_by_fingerprint.get(str(site["siteFingerprint"]), {})
        governed_catch_sites.append({**site, **policy})

    if args.write_fingerprints:
        _write_fingerprints(manifest, fingerprints)
        failures = [
            failure for failure in failures if not failure.endswith("risk fingerprint changed")
        ]

    report = {
        "inventoryVersion": manifest.get("schemaVersion"),
        "findingId": manifest.get("findingId"),
        "scope": manifest.get("scope"),
        "sourceCommit": _git("rev-parse", "HEAD"),
        "workingTreeClean": not bool(_git("status", "--porcelain")),
        "timestampInventoryResult": timestamp_report.get("result"),
        "timestampReaderCount": timestamp_report.get("readerCount"),
        "timestampDirectParserCandidateCount": timestamp_report.get(
            "directParserCandidateCount"
        ),
        "surfaceCount": len(inventory),
        "strictReaderConsumerFileCount": len(discovered_strict),
        "rawJsonConsumerFileCount": len(discovered_json),
        "riskCandidateCount": sum(item["riskCandidateCount"] for item in inventory),
        "unclassifiedFiles": unclassified,
        "decoderCatchSiteCount": len(discovered_catch_sites),
        "unclassifiedDecoderCatchSites": unclassified_catches,
        "staleDecoderCatchPolicies": stale_catch_policies,
        "decoderCatchSites": governed_catch_sites,
        "surfaces": inventory,
        "result": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
