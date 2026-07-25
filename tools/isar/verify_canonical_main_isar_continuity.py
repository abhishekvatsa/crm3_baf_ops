#!/usr/bin/env python3
"""Verify successor Isar schemas against canonical-main semantic continuity.

Generated PropertySchema.id values are generator-local positions. They may move
when additive fields sort before inherited fields. The migration contract is
therefore enforced on stable collection identity, inherited property names and
types, and inherited index definitions. Generated position changes remain fully
reported but are not treated as semantic continuity failures.

The initial v4 pilot remains a clean-cutover/fresh-local-database trial by
programme decision. This verifier nonetheless keeps inherited schema semantics
strict rather than allowing missing, renamed or type-changed properties.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json"


def collection_blocks(text: str):
    header = re.compile(
        r"const\s+(\w+)Schema\s*=\s*CollectionSchema\(\s*"
        r"name:\s*r'([^']+)',\s*id:\s*(-?\d+),",
        re.S,
    )
    for match in header.finditer(text):
        start = match.start()
        pos = text.find("CollectionSchema(", start)
        depth = 0
        end = None
        for i in range(pos, len(text)):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        if end is None:
            raise ValueError(f"Unterminated CollectionSchema for {match.group(2)}")
        yield match.group(2), int(match.group(3)), text[start:end]


def parse_schema_tree() -> dict[str, dict]:
    result: dict[str, dict] = {}
    for path in (ROOT / "lib").rglob("*.g.dart"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for name, collection_id, block in collection_blocks(text):
            if name in result:
                raise ValueError(f"Duplicate collection schema name: {name}")
            properties: dict[str, dict] = {}
            prop_match = re.search(
                r"properties:\s*\{(.*?)\}\s*,\s*estimateSize:", block, re.S
            )
            if prop_match:
                for item in re.finditer(
                    r"r'([^']+)':\s*PropertySchema\(\s*id:\s*(\d+),\s*"
                    r"name:\s*r'[^']+',\s*type:\s*IsarType\.(\w+)",
                    prop_match.group(1),
                    re.S,
                ):
                    properties[item.group(1)] = {
                        "id": int(item.group(2)),
                        "type": item.group(3),
                    }
            indexes: dict[str, dict] = {}
            index_match = re.search(
                r"indexes:\s*\{(.*?)\}\s*,\s*links:", block, re.S
            )
            if index_match:
                for item in re.finditer(
                    r"r'([^']+)':\s*IndexSchema\(\s*id:\s*(-?\d+),\s*"
                    r"name:\s*r'[^']+',\s*unique:\s*(true|false),\s*"
                    r"replace:\s*(true|false),\s*properties:\s*\[(.*?)\]\s*,?\s*\)",
                    index_match.group(1),
                    re.S,
                ):
                    index_properties = []
                    for prop in re.finditer(
                        r"IndexPropertySchema\(\s*name:\s*r'([^']+)',\s*"
                        r"type:\s*IndexType\.(\w+),\s*caseSensitive:\s*(true|false)",
                        item.group(5),
                        re.S,
                    ):
                        index_properties.append(
                            {
                                "name": prop.group(1),
                                "type": prop.group(2),
                                "caseSensitive": prop.group(3) == "true",
                            }
                        )
                    indexes[item.group(1)] = {
                        "id": int(item.group(2)),
                        "unique": item.group(3) == "true",
                        "replace": item.group(4) == "true",
                        "properties": index_properties,
                    }
            result[name] = {
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "collectionId": collection_id,
                "properties": properties,
                "indexes": indexes,
            }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", help="Optional JSON report path")
    args = parser.parse_args()

    baseline_doc = json.loads(BASELINE.read_text(encoding="utf-8"))
    baseline = baseline_doc["collections"]
    actual = parse_schema_tree()
    failures: list[dict] = []
    additions: dict[str, dict] = {}
    property_position_changes: list[dict] = []

    ids: dict[int, str] = {}
    for name, schema in actual.items():
        collection_id = schema["collectionId"]
        if collection_id in ids:
            failures.append(
                {
                    "collection": name,
                    "reason": "duplicate-collection-id",
                    "id": collection_id,
                    "other": ids[collection_id],
                }
            )
        ids[collection_id] = name

    for name, expected in baseline.items():
        found = actual.get(name)
        if found is None:
            failures.append(
                {"collection": name, "reason": "inherited-collection-missing"}
            )
            continue
        if found["collectionId"] != expected["collectionId"]:
            failures.append(
                {
                    "collection": name,
                    "reason": "collection-id-changed",
                    "expected": expected["collectionId"],
                    "actual": found["collectionId"],
                }
            )

        for prop_name, prop_expected in expected["properties"].items():
            prop_found = found["properties"].get(prop_name)
            if prop_found is None:
                failures.append(
                    {
                        "collection": name,
                        "property": prop_name,
                        "reason": "inherited-property-missing",
                    }
                )
                continue
            if prop_found["type"] != prop_expected["type"]:
                failures.append(
                    {
                        "collection": name,
                        "property": prop_name,
                        "reason": "inherited-property-type-changed",
                        "expected": prop_expected["type"],
                        "actual": prop_found["type"],
                    }
                )
            elif prop_found["id"] != prop_expected["id"]:
                property_position_changes.append(
                    {
                        "collection": name,
                        "property": prop_name,
                        "classification": "generated-property-position-changed",
                        "expectedPosition": prop_expected["id"],
                        "actualPosition": prop_found["id"],
                        "type": prop_found["type"],
                    }
                )

        for index_name, index_expected in expected["indexes"].items():
            index_found = found["indexes"].get(index_name)
            if index_found is None:
                failures.append(
                    {
                        "collection": name,
                        "index": index_name,
                        "reason": "inherited-index-missing",
                    }
                )
            elif index_found != index_expected:
                failures.append(
                    {
                        "collection": name,
                        "index": index_name,
                        "reason": "inherited-index-definition-changed",
                        "expected": index_expected,
                        "actual": index_found,
                    }
                )

        additions[name] = {
            "newProperties": sorted(
                set(found["properties"]) - set(expected["properties"])
            ),
            "newIndexes": sorted(set(found["indexes"]) - set(expected["indexes"])),
        }

    new_collections = sorted(set(actual) - set(baseline))
    report = {
        "schemaVersion": 2,
        "canonicalMainCommit": baseline_doc["canonicalMainCommit"],
        "canonicalMainTree": baseline_doc["canonicalMainTree"],
        "continuityContract": {
            "collectionIdStable": True,
            "inheritedPropertyNameAndTypeStable": True,
            "inheritedIndexDefinitionStable": True,
            "generatedPropertyPositionIsStableMigrationIdentity": False,
            "initialPilotLocalDataPolicy": "clean-cutover-fresh-local-database",
        },
        "inheritedCollectionCount": len(baseline),
        "actualCollectionCount": len(actual),
        "newCollections": new_collections,
        "additionsByInheritedCollection": additions,
        "generatedPropertyPositionChanges": property_position_changes,
        "failures": failures,
        "status": (
            "PASS_CANONICAL_ISAR_SEMANTIC_CONTINUITY"
            if not failures
            else "FAIL_CANONICAL_ISAR_SEMANTIC_CONTINUITY"
        ),
    }
    if args.report:
        target = Path(args.report)
        if not target.is_absolute():
            target = ROOT / target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(
        f"{report['status']}: inherited={len(baseline)} actual={len(actual)} "
        f"new={len(new_collections)} positionChanges={len(property_position_changes)} "
        f"failures={len(failures)}"
    )
    if failures:
        print(json.dumps(failures, indent=2), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
