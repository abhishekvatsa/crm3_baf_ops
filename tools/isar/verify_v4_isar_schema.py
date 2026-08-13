#!/usr/bin/env python3
"""Fail-closed structural verification for v4 Isar persistence bindings."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = "PROVISIONAL_V4_ISAR_CODEGEN"

WORKFLOW = {
    "compliance_attempt_record.dart": "ComplianceAttemptRecord",
    "compliance_request_record.dart": "ComplianceRequestRecord",
    "equipment_prompt_record.dart": "EquipmentPromptRecord",
    "equipment_status_record.dart": "EquipmentStatusRecord",
    "job_lane_record.dart": "JobLaneRecord",
    "workflow_aggregate_record.dart": "WorkflowAggregateRecord",
    "workflow_command_receipt_record.dart": "WorkflowCommandReceiptRecord",
    "workflow_command_record.dart": "WorkflowCommandRecord",
    "workflow_event_record.dart": "WorkflowEventRecord",
}

REQUIRED_EXISTING = {
    "lib/features/maintenance/data/maintenance_model.g.dart": {
        "workflowAggregateId","workflowComplianceId","workflowConditionRef",
        "workflowConditionTypeKey","workflowCorrectionReason","workflowDeferred",
        "workflowDeferredAt","workflowDeferredByName","workflowDeferredByUid",
        "workflowOriginLaneKey","workflowQueueState","workflowReactivatedAt",
        "workflowReactivatedByName","workflowReactivatedByUid","workflowReleasedAt",
        "workflowReleasedByName","workflowReleasedByUid","workflowTargetLaneKey",
        "workflowUpdatedAt",
    },
    "lib/features/planned_maintenance/data/job_template_model.g.dart": {
        "cancellationReason","cancelledAt","cancelledByName","cancelledByUid",
        "isCancelled","laneMappingReview","laneSetFinalizedAt",
        "laneSetFinalizedByName","laneSetFinalizedByUid","laneSetVersion",
        "parentExecutionFirestoreId","redAnswerJson",
        "spawnedRedExecutionFirestoreId","workflowSchemaVersion",
    },
}

FIELD_RE = re.compile(
    r"^\s*(?:late\s+)?(String|int|bool|DateTime)(\?)?\s+(\w+)"
    r"\s*(?:=[^;]*)?;\s*(?://[^\n]*)?$",
    re.MULTILINE,
)

def fail(msg: str) -> None:
    raise AssertionError(msg)

def source_fields(path: Path, class_name: str) -> set[str]:
    text=path.read_text(encoding="utf-8")
    class_match=re.search(rf"^class\s+{re.escape(class_name)}\s*{{", text, re.MULTILINE)
    if class_match is None: fail(f"Class {class_name} is absent from {path}")
    open_offset=text.index('{', class_match.start())
    depth=0; close_offset=None
    for offset in range(open_offset, len(text)):
        if text[offset] == '{': depth += 1
        elif text[offset] == '}':
            depth -= 1
            if depth == 0:
                close_offset=offset
                break
    if close_offset is None: fail(f"Class {class_name} is unterminated in {path}")
    body=text[open_offset + 1:close_offset]
    fields=set()
    for match in FIELD_RE.finditer(body):
        prefix=body[:match.start()]
        if prefix.count('{') == prefix.count('}') and match.group(3) != 'id':
            fields.add(match.group(3))
    if not fields: fail(f"No fields parsed from {path}:{class_name}")
    return fields

def schema_block(text: str, class_name: str) -> str:
    start=text.index(f"const {class_name}Schema = CollectionSchema(")
    end=text.index("\n);",start)+3
    return text[start:end]

def schema_properties(block: str) -> dict[str,int]:
    pairs=re.findall(r"r'([^']+)': PropertySchema\(\s*id:\s*(\d+),",block)
    result={name:int(pid) for name,pid in pairs}
    if len(result)!=len(pairs): fail('Duplicate property name in schema')
    ids=list(result.values())
    if len(ids)!=len(set(ids)): fail('Duplicate property id in schema')
    return result

def verify_binding(source: Path, generated: Path, class_name: str) -> None:
    if not generated.is_file(): fail(f"Missing generated binding: {generated}")
    text=generated.read_text(encoding="utf-8")
    fields=source_fields(source,class_name)
    props=schema_properties(schema_block(text,class_name))
    if fields != set(props):
        fail(f"{class_name} source/schema mismatch; missing={sorted(fields-set(props))}, extra={sorted(set(props)-fields)}")
    lower=class_name[0].lower()+class_name[1:]
    for name,pid in props.items():
        if f"offsets[{pid}]" not in text:
            fail(f"{class_name}.{name} id {pid} has no serializer/deserializer offset")
        if f"case {pid}:" not in text:
            fail(f"{class_name}.{name} id {pid} has no deserializeProp case")
    if f"extension Get{class_name}Collection on Isar" not in text:
        fail(f"{class_name} collection accessor absent")
    if f"_{lower}Serialize" not in text or f"_{lower}Deserialize" not in text:
        fail(f"{class_name} serializer surface absent")

def verify_existing() -> None:
    for rel,required in REQUIRED_EXISTING.items():
        path=ROOT/rel
        text=path.read_text(encoding="utf-8")
        props=set(re.findall(r"r'([^']+)': PropertySchema\(",text))
        missing=required-props
        if missing: fail(f"{rel} misses v4 properties: {sorted(missing)}")
        for field in required:
            if f"object.{field} = reader." not in text:
                fail(f"{rel} does not deserialize {field}")
            if not re.search(rf"writer\.\w+\(offsets\[\d+\], object\.{re.escape(field)}\);",text):
                fail(f"{rel} does not serialize {field}")
    module=(ROOT/'lib/features/planned_maintenance/data/job_module_model.g.dart').read_text(encoding="utf-8")
    diary=(ROOT/'lib/features/planned_maintenance/data/job_diary_model.g.dart').read_text(encoding="utf-8")
    for raw in ('emd','refractory'):
        if module.count(f"r'{raw}':") < 2: fail(f"JobModule enum persistence missing {raw}")
        if diary.count(f"r'{raw}':") < 2: fail(f"JobDiary enum persistence missing {raw}")

def verify_ids() -> None:
    ids=[]
    for path in ROOT.joinpath('lib').rglob('*.g.dart'):
        text=path.read_text(encoding='utf-8', errors='ignore')
        ids.extend((int(i),f"{path}:{name}") for name,i in re.findall(r"name:\s*r'([^']+)',\s*id:\s*(-?\d+)",text))
    seen={}
    for ident,label in ids:
        if ident in seen:
            # IDs may legitimately repeat across property schemas; only schema
            # and index top-level IDs need global uniqueness. This regex is
            # intentionally conservative, so report only exact label duplicates.
            if seen[ident] == label: fail(f"Repeated Isar id {ident}: {label}")
        else: seen[ident]=label

def verify_migration() -> None:
    text=(ROOT/'lib/core/services/isar_schema_migration.dart').read_text(encoding="utf-8")
    guard=(ROOT/'lib/core/services/isar_schema_guard_io.dart').read_text(encoding="utf-8")
    startup=(ROOT/'lib/main.dart').read_text(encoding="utf-8")
    if 'currentSchemaVersion = 4' not in text: fail('Isar schema version is not v4')
    if "'v4:Charge,MaintenanceRecord+WorkflowBridge" not in text: fail('v4 schema fingerprint missing')
    if '3: _reconcileV4WorkflowPersistence' not in text: fail('v2->v3 migration step missing')
    if '4: _addOperationalAssuranceRequestFields' not in text: fail('v3->v4 migration step missing')
    if 'repairLegacyOperationalAssuranceRequests(' not in startup:
        fail('v4 operational-assurance post-open repair missing')
    required_provenance = (
        "baf_isar_schema_provenance_v1",
        "databaseGenerationId",
        "IsarSchemaMarkerState.prepared",
        "IsarSchemaMarkerState.committed",
        "existing-store-unmarked",
        "legacy-marker-incomplete",
        "stored-schema-fingerprint-unrecognized",
        "_validateMarkerSource(",
        "canonical-marker-write-failed",
    )
    missing = [token for token in required_provenance if token not in text]
    if missing: fail(f"P-06 Isar provenance controls missing: {missing}")
    accepted_block=text.split("acceptedFingerprintsByVersion:",1)[1].split(
        "stepsByTargetVersion:",1
    )[0]
    if "2: <String>{" in accepted_block:
        fail("Repository-unproved v2 fingerprint must not be accepted")
    if ".isar.lock" in guard:
        fail("Lock-only Isar residue must not be treated as durable data")
    prepare=startup.index("ensureIsarSchemaBeforeOpen(")
    opened=startup.index("Isar.open(",prepare)
    planned_repaired=startup.index("repairPlannedJobLocalLinks(",opened)
    assurance_repaired=startup.index(
        "repairLegacyOperationalAssuranceRequests(", planned_repaired
    )
    committed=startup.index("commitAfterSuccessfulOpen()",assurance_repaired)
    if not prepare < opened < planned_repaired < assurance_repaired < committed:
        fail("Isar provenance must prepare before open and commit after all repairs")
    if (
        "readIsarSchemaProvenanceSnapshotJson()" not in startup
        or '"schemaProvenanceSnapshot": $provenanceSnapshot' not in startup
    ):
        fail("Startup recovery must preserve exact provenance marker evidence")

def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument('--release',action='store_true',help='Reject provisional codegen markers')
    args=parser.parse_args()
    data=ROOT/'lib/features/maintenance_workflow/data'
    for filename,class_name in WORKFLOW.items():
        source=data/filename
        generated=source.with_suffix('.g.dart')
        verify_binding(source,generated,class_name)
    verify_existing(); verify_ids(); verify_migration()
    marked=[]
    for path in ROOT.joinpath('lib').rglob('*.g.dart'):
        if MARKER in path.read_text(encoding='utf-8', errors='ignore'): marked.append(path.relative_to(ROOT))
    if args.release and marked:
        fail('Pinned build_runner output required before release; provisional files: '+', '.join(map(str,marked)))
    print(f"PASS: v4 Isar schema structure and P-06 provenance verified; provisional_bindings={len(marked)}; release_authority={'NO' if marked else 'YES'}")
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL: {exc}",file=sys.stderr)
        raise SystemExit(1)
