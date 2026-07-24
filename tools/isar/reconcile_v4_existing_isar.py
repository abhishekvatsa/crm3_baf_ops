#!/usr/bin/env python3
"""Append v4 persistence fields to pre-existing Isar generated bindings.

The existing collection/property IDs are preserved exactly; new persisted
fields are appended with stable IDs so the source candidate can represent v4
state without reinterpreting old rows. These files remain provisional until
replaced by pinned Flutter 3.44.0 build_runner output.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = "PROVISIONAL_V4_ISAR_CODEGEN"

@dataclass(frozen=True)
class Field:
    name: str
    type_name: str
    nullable: bool
    indexed: bool = False

MAINTENANCE = [
    Field("workflowAggregateId", "String", True, True),
    Field("workflowComplianceId", "String", True, True),
    Field("workflowConditionRef", "String", True),
    Field("workflowConditionTypeKey", "String", True),
    Field("workflowCorrectionReason", "String", True),
    Field("workflowDeferred", "bool", False, True),
    Field("workflowDeferredAt", "DateTime", True),
    Field("workflowDeferredByName", "String", True),
    Field("workflowDeferredByUid", "String", True),
    Field("workflowOriginLaneKey", "String", True),
    Field("workflowQueueState", "String", False, True),
    Field("workflowReactivatedAt", "DateTime", True),
    Field("workflowReactivatedByName", "String", True),
    Field("workflowReactivatedByUid", "String", True),
    Field("workflowReleasedAt", "DateTime", True),
    Field("workflowReleasedByName", "String", True),
    Field("workflowReleasedByUid", "String", True),
    Field("workflowTargetLaneKey", "String", True),
    Field("workflowUpdatedAt", "DateTime", True),
]

JOB_EXECUTION = [
    Field("cancellationReason", "String", True),
    Field("cancelledAt", "DateTime", True),
    Field("cancelledByName", "String", True),
    Field("cancelledByUid", "String", True),
    Field("isCancelled", "bool", False, True),
    Field("laneMappingReview", "bool", False, True),
    Field("laneSetFinalizedAt", "DateTime", True),
    Field("laneSetFinalizedByName", "String", True),
    Field("laneSetFinalizedByUid", "String", True),
    Field("laneSetVersion", "int", False),
    Field("parentExecutionFirestoreId", "String", True, True),
    Field("redAnswerJson", "String", True),
    Field("spawnedRedExecutionFirestoreId", "String", True),
    Field("workflowSchemaVersion", "int", False),
]

ISAR_TYPE = {"String":"IsarType.string","bool":"IsarType.bool","int":"IsarType.long","DateTime":"IsarType.dateTime"}
WRITER = {"String":"writeString","bool":"writeBool","int":"writeLong","DateTime":"writeDateTime"}
READER = {
    ("String",True):"readStringOrNull",("String",False):"readString",
    ("bool",True):"readBoolOrNull",("bool",False):"readBool",
    ("int",True):"readLongOrNull",("int",False):"readLong",
    ("DateTime",True):"readDateTimeOrNull",("DateTime",False):"readDateTime",
}

def stable_int64(value: str) -> int:
    raw=int.from_bytes(hashlib.sha256(value.encode()).digest()[:8],"big")
    return raw-(1<<64) if raw >= (1<<63) else raw

def add_marker(text: str) -> str:
    if MARKER in text: return text
    needle="// GENERATED CODE - DO NOT MODIFY BY HAND\n"
    return text.replace(needle, needle+f"// {MARKER}: v4 additive schema reconciliation; replace with pinned build_runner output before release.\n",1)

def prop(field: Field, pid: int) -> str:
    return f"    r'{field.name}': PropertySchema(\n      id: {pid},\n      name: r'{field.name}',\n      type: {ISAR_TYPE[field.type_name]},\n    ),\n"

def index(field: Field, class_name: str) -> str:
    idx=stable_int64(f"v4-provisional-existing-index:{class_name}:{field.name}")
    typ="IndexType.hash" if field.type_name=="String" else "IndexType.value"
    cs="true" if field.type_name=="String" else "false"
    return f"    r'{field.name}': IndexSchema(\n      id: {idx},\n      name: r'{field.name}',\n      unique: false,\n      replace: false,\n      properties: [\n        IndexPropertySchema(\n          name: r'{field.name}',\n          type: {typ},\n          caseSensitive: {cs},\n        )\n      ],\n    ),\n"

def estimate(field: Field) -> str:
    if field.type_name != "String": return ""
    if field.nullable:
        return f"  {{\n    final value = object.{field.name};\n    if (value != null) {{\n      bytesCount += 3 + value.length * 3;\n    }}\n  }}\n"
    return f"  bytesCount += 3 + object.{field.name}.length * 3;\n"

def patch(path: Path, class_name: str, lower: str, fields: list[Field], first_id: int) -> None:
    text=add_marker(path.read_text(encoding="utf-8"))
    if all(f"r'{field.name}': PropertySchema(" in text for field in fields):
        path.write_text(text, encoding="utf-8")
        return
    schema_start=text.index(f"const {class_name}Schema = CollectionSchema(")
    estimate_marker=f"\n  }},\n  estimateSize: _{lower}EstimateSize,"
    property_end=text.index(estimate_marker,schema_start)
    missing=[f for f in fields if f"r'{f.name}': PropertySchema(" not in text[schema_start:property_end]]
    if not missing:
        path.write_text(text, encoding="utf-8"); return
    prop_text="".join(prop(f,first_id+fields.index(f)) for f in missing)
    text=text[:property_end]+"\n"+prop_text.rstrip("\n")+text[property_end:]

    schema_start=text.index(f"const {class_name}Schema = CollectionSchema(")
    links_marker="\n  },\n  links: {},"
    index_end=text.index(links_marker,schema_start)
    index_text="".join(index(f,class_name) for f in missing if f.indexed)
    if index_text:
        text=text[:index_end]+"\n"+index_text.rstrip("\n")+text[index_end:]

    est_start=text.index(f"int _{lower}EstimateSize(")
    est_return=text.index("  return bytesCount;",est_start)
    est_text="".join(estimate(f) for f in missing)
    text=text[:est_return]+est_text+text[est_return:]

    ser_start=text.index(f"void _{lower}Serialize(")
    deser_marker=f"\n}}\n\n{class_name} _{lower}Deserialize("
    ser_end=text.index(deser_marker,ser_start)
    ser_text="".join(f"  writer.{WRITER[f.type_name]}(offsets[{first_id+fields.index(f)}], object.{f.name});\n" for f in missing)
    text=text[:ser_end]+ser_text+text[ser_end:]

    deser_start=text.index(f"{class_name} _{lower}Deserialize(")
    deser_return=text.index("  return object;",deser_start)
    deser_text="".join(f"  object.{f.name} = reader.{READER[(f.type_name,f.nullable)]}(offsets[{first_id+fields.index(f)}]);\n" for f in missing)
    text=text[:deser_return]+deser_text+text[deser_return:]

    prop_start=text.index(f"P _{lower}DeserializeProp<P>(")
    default_pos=text.index("    default:",prop_start)
    cases="".join(
        f"    case {first_id+fields.index(f)}:\n      return (reader.{READER[(f.type_name,f.nullable)]}(offset)) as P;\n"
        for f in missing
    )
    text=text[:default_pos]+cases+text[default_pos:]
    path.write_text(text, encoding="utf-8")


def patch_enum(path: Path, enum_prefix: str, values: list[tuple[str,str]]) -> None:
    text=add_marker(path.read_text(encoding="utf-8"))
    enum_name=f"const _{enum_prefix}EnumValueMap = {{"
    value_name=f"const _{enum_prefix}ValueEnumMap = {{"
    for marker, is_value in [(enum_name,False),(value_name,True)]:
        start=text.index(marker)
        end=text.index("\n};",start)
        block=text[start:end]
        additions=[]
        for raw,expr in values:
            if f"r'{raw}':" not in block:
                rhs=expr if is_value else f"r'{raw}'"
                additions.append(f"  r'{raw}': {rhs},")
        if additions:
            text=text[:end]+"\n"+"\n".join(additions)+text[end:]
    path.write_text(text, encoding="utf-8")


def main() -> None:
    patch(ROOT/'lib/features/maintenance/data/maintenance_model.g.dart','MaintenanceRecord','maintenanceRecord',MAINTENANCE,46)
    patch(ROOT/'lib/features/planned_maintenance/data/job_template_model.g.dart','JobExecution','jobExecution',JOB_EXECUTION,33)
    patch_enum(
        ROOT/'lib/features/planned_maintenance/data/job_module_model.g.dart',
        'JobModuleInstancediscipline',
        [('emd','JobModuleDiscipline.emd'),('refractory','JobModuleDiscipline.refractory')],
    )
    patch_enum(
        ROOT/'lib/features/planned_maintenance/data/job_diary_model.g.dart',
        'JobDiaryEntrydiscipline',
        [('emd','JobDiaryDiscipline.emd'),('refractory','JobDiaryDiscipline.refractory')],
    )
    print('reconciled provisional existing Isar bindings')

if __name__=='__main__': main()
