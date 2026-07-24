#!/usr/bin/env python3
"""Generate constrained provisional Isar bindings for workflow mirror records.

This tool is intentionally narrow. It supports only the primitive field types
used by the nine workflow mirror/outbox records and fails closed on any model
shape it does not understand. The output is compile-oriented and preserves
unique-index upsert semantics, but it is NOT a substitute for the pinned
Flutter 3.44.0 / Dart 3.12.0 / isar_generator 3.1.0+1 build.

Before any release authority is claimed, run the real generator and remove the
PROVISIONAL_V4_ISAR_CODEGEN markers by replacing these outputs with the pinned
build_runner output.
"""
from __future__ import annotations

import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "lib/features/maintenance_workflow/data"
VERSION = "3.1.0+1"
MARKER = "PROVISIONAL_V4_ISAR_CODEGEN"

MODELS = {
    "compliance_attempt_record.dart": ("ComplianceAttemptRecord", "complianceAttemptRecords"),
    "compliance_request_record.dart": ("ComplianceRequestRecord", "complianceRequestRecords"),
    "equipment_prompt_record.dart": ("EquipmentPromptRecord", "equipmentPromptRecords"),
    "equipment_status_record.dart": ("EquipmentStatusRecord", "equipmentStatusRecords"),
    "job_lane_record.dart": ("JobLaneRecord", "jobLaneRecords"),
    "workflow_aggregate_record.dart": ("WorkflowAggregateRecord", "workflowAggregateRecords"),
    "workflow_command_receipt_record.dart": ("WorkflowCommandReceiptRecord", "workflowCommandReceiptRecords"),
    "workflow_command_record.dart": ("WorkflowCommandRecord", "workflowCommandRecords"),
    "workflow_event_record.dart": ("WorkflowEventRecord", "workflowEventRecords"),
}

TYPE_TO_ISAR = {
    "String": "IsarType.string",
    "int": "IsarType.long",
    "bool": "IsarType.bool",
    "DateTime": "IsarType.dateTime",
}
WRITER = {
    "String": "writeString",
    "int": "writeLong",
    "bool": "writeBool",
    "DateTime": "writeDateTime",
}
READER = {
    ("String", False): "readString",
    ("String", True): "readStringOrNull",
    ("int", False): "readLong",
    ("int", True): "readLongOrNull",
    ("bool", False): "readBool",
    ("bool", True): "readBoolOrNull",
    ("DateTime", False): "readDateTime",
    ("DateTime", True): "readDateTimeOrNull",
}

@dataclass(frozen=True)
class Field:
    name: str
    type_name: str
    nullable: bool
    indexed: bool
    unique: bool
    replace: bool


def stable_int64(value: str) -> int:
    raw = int.from_bytes(hashlib.sha256(value.encode("utf-8")).digest()[:8], "big")
    return raw - (1 << 64) if raw >= (1 << 63) else raw


def parse_fields(path: Path, class_name: str) -> list[Field]:
    lines = path.read_text(encoding="utf-8").splitlines()
    in_class = False
    depth = 0
    pending_index: tuple[bool, bool] | None = None
    fields: list[Field] = []
    class_re = re.compile(rf"^class\s+{re.escape(class_name)}\s*{{")
    field_re = re.compile(
        r"^\s*(?:late\s+)?(String|int|bool|DateTime)(\?)?\s+(\w+)\s*(?:=[^;]*)?;\s*(?://.*)?$"
    )
    for line in lines:
        if not in_class:
            if class_re.match(line.strip()):
                in_class = True
                depth = line.count("{") - line.count("}")
            continue
        depth += line.count("{") - line.count("}")
        stripped = line.strip()
        if stripped.startswith("@Index"):
            pending_index = (
                "unique: true" in stripped,
                "replace: true" in stripped,
            )
            continue
        if stripped.startswith("@ignore"):
            pending_index = None
            continue
        match = field_re.match(line)
        if match:
            type_name, nullable_token, name = match.groups()
            if name != "id":
                unique, replace = pending_index or (False, False)
                fields.append(
                    Field(
                        name=name,
                        type_name=type_name,
                        nullable=nullable_token == "?",
                        indexed=pending_index is not None,
                        unique=unique,
                        replace=replace,
                    )
                )
            pending_index = None
        elif stripped and not stripped.startswith("//"):
            # An annotation other than @Index is harmless; a method/constructor
            # is outside the supported data-only record shape and must be seen.
            if stripped.startswith("@"):
                continue
        if depth <= 0:
            break
    if not fields:
        raise RuntimeError(f"No supported fields parsed from {path}")
    names = [f.name for f in fields]
    if len(names) != len(set(names)):
        raise RuntimeError(f"Duplicate fields parsed from {path}: {names}")
    return sorted(fields, key=lambda field: field.name)


def property_schema(field: Field, property_id: int) -> str:
    return (
        f"    r'{field.name}': PropertySchema(\n"
        f"      id: {property_id},\n"
        f"      name: r'{field.name}',\n"
        f"      type: {TYPE_TO_ISAR[field.type_name]},\n"
        f"    ),"
    )


def index_schema(class_name: str, field: Field) -> str:
    index_type = "IndexType.hash" if field.type_name == "String" else "IndexType.value"
    case_sensitive = "true" if field.type_name == "String" else "false"
    index_id = stable_int64(f"v4-provisional-index:{class_name}:{field.name}")
    return (
        f"    r'{field.name}': IndexSchema(\n"
        f"      id: {index_id},\n"
        f"      name: r'{field.name}',\n"
        f"      unique: {str(field.unique).lower()},\n"
        f"      replace: {str(field.replace).lower()},\n"
        f"      properties: [\n"
        f"        IndexPropertySchema(\n"
        f"          name: r'{field.name}',\n"
        f"          type: {index_type},\n"
        f"          caseSensitive: {case_sensitive},\n"
        f"        )\n"
        f"      ],\n"
        f"    ),"
    )


def estimate_block(field: Field) -> str | None:
    if field.type_name != "String":
        return None
    if field.nullable:
        return (
            f"  {{\n"
            f"    final value = object.{field.name};\n"
            f"    if (value != null) {{\n"
            f"      bytesCount += 3 + value.length * 3;\n"
            f"    }}\n"
            f"  }}"
        )
    return f"  bytesCount += 3 + object.{field.name}.length * 3;"


def generate(path: Path, class_name: str, accessor: str) -> str:
    fields = parse_fields(path, class_name)
    lower = class_name[0].lower() + class_name[1:]
    schema_id = stable_int64(f"v4-provisional-collection:{class_name}")
    properties = "\n".join(property_schema(field, i) for i, field in enumerate(fields))
    indexed = [field for field in fields if field.indexed]
    indexes = "\n".join(index_schema(class_name, field) for field in indexed)
    estimates = "\n".join(
        block for field in fields if (block := estimate_block(field)) is not None
    )
    serializers = "\n".join(
        f"  writer.{WRITER[field.type_name]}(offsets[{i}], object.{field.name});"
        for i, field in enumerate(fields)
    )
    deserializers = "\n".join(
        f"  object.{field.name} = reader.{READER[(field.type_name, field.nullable)]}(offsets[{i}]);"
        for i, field in enumerate(fields)
    )
    prop_cases = "\n".join(
        f"    case {i}:\n"
        f"      return (reader.{READER[(field.type_name, field.nullable)]}(offset)) as P;"
        for i, field in enumerate(fields)
    )
    return f"""// GENERATED CODE - DO NOT MODIFY BY HAND
// {MARKER}: replace with Flutter 3.44.0 / Dart 3.12.0 / isar_generator {VERSION} output before release.

part of '{path.name}';

// **************************************************************************
// Constrained v4 provisional Isar binding
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: non_constant_identifier_names, unnecessary_cast, always_specify_types

extension Get{class_name}Collection on Isar {{
  IsarCollection<{class_name}> get {accessor} => this.collection();
}}

const {class_name}Schema = CollectionSchema(
  name: r'{class_name}',
  id: {schema_id},
  properties: {{
{properties}
  }},
  estimateSize: _{lower}EstimateSize,
  serialize: _{lower}Serialize,
  deserialize: _{lower}Deserialize,
  deserializeProp: _{lower}DeserializeProp,
  idName: r'id',
  indexes: {{
{indexes}
  }},
  links: {{}},
  embeddedSchemas: {{}},
  getId: _{lower}GetId,
  getLinks: _{lower}GetLinks,
  attach: _{lower}Attach,
  version: '{VERSION}',
);

int _{lower}EstimateSize(
  {class_name} object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {{
  var bytesCount = offsets.last;
{estimates}
  return bytesCount;
}}

void _{lower}Serialize(
  {class_name} object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {{
{serializers}
}}

{class_name} _{lower}Deserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {{
  final object = {class_name}();
{deserializers}
  object.id = id;
  return object;
}}

P _{lower}DeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {{
  switch (propertyId) {{
{prop_cases}
    default:
      throw IsarError('Unknown property with id $propertyId');
  }}
}}

Id _{lower}GetId({class_name} object) => object.id;

List<IsarLinkBase<dynamic>> _{lower}GetLinks({class_name} object) => [];

void _{lower}Attach(
  IsarCollection<dynamic> col,
  Id id,
  {class_name} object,
) {{
  object.id = id;
}}
"""


def main() -> int:
    for filename, (class_name, accessor) in MODELS.items():
        source = DATA / filename
        if not source.is_file():
            raise FileNotFoundError(source)
        output = source.with_suffix(".g.dart")
        output.write_text(generate(source, class_name, accessor), encoding="utf-8")
        print(output.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
