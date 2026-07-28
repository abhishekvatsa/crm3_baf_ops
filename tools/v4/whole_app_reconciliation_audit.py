#!/usr/bin/env python3
"""Source-level v4 whole-app reconciliation audit.

This verifies that the original app's useful guarantees were absorbed into the
v3.3 workflow architecture instead of leaving parallel authorities. It does not
replace pinned Flutter codegen/analyze, Firestore emulator, Android, or device
proof.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]

@dataclass
class Check:
    title:str
    ok:bool
    detail:str

def read(rel:str)->str:
    return (ROOT/rel).read_text(encoding='utf-8',errors='ignore')

def add(out:list[Check],title:str,ok:bool,detail:str)->None:
    out.append(Check(title,ok,detail))

def main()->int:
    c:list[Check]=[]
    canonical=read('functions/src/maintenanceWorkflow/canonicalClosure.ts')
    finalizer=read('functions/src/maintenanceWorkflow/finalizeJobHandler.ts')
    legacy_close=read('functions/src/plannedJobClosure.ts')
    module_lifecycle=read('functions/src/maintenanceWorkflow/moduleLifecycleHandlers.ts')
    lane=read('functions/src/maintenanceWorkflow/laneHandlers.ts')
    compliance=read('functions/src/maintenanceWorkflow/complianceHandlers.ts')
    bridge=read('functions/src/maintenanceWorkflow/maintenanceBridge.ts')
    rules=read('firestore.rules')
    policy=json.loads(read('governance/maintenance_workflow_policy_v1.json'))
    generated_ts=read('functions/src/maintenanceWorkflow/policy.generated.ts')
    generated_dart=read('lib/features/maintenance_workflow/domain/workflow_policy_generated.dart')

    add(c,'workflow finalizer absorbs canonical module/evidence attestation',
        'buildCanonicalClosurePlan' in finalizer and 'buildClosureAttestation' in canonical
        and 'closureAttestationHash' in finalizer and 'audit_logs/server_closure_' in canonical,
        'one workflow finalizer retains original remote-module and audit guarantees')
    add(c,'legacy completion is fenced from workflow-schema executions',
        'workflow-finalizer-required' in legacy_close and 'workflowSchemaVersion' in legacy_close,
        'old callable remains only for legacy jobs')
    add(c,'module reopen reactivates lane and writes correlated audit',
        'reopenWorkflowModule' in module_lifecycle and 'status: "acknowledged"' in module_lifecycle
        and 'workflowAggregateId' in module_lifecycle and 'audit_logs/workflow_module_reopen_' in module_lifecycle,
        'module/lane states cannot diverge on reopen')

    lane_map=policy.get('moduleDisciplineLaneMap',{})
    expected={'electrical':'elec','mechanical':'mech','instrumentation':'inst','operations':'oprn',
              'shiftInCharge':'oprn','emd':'emd','refractory':'red','safety':'shared',
              'admin':'shared','shared':'shared','others':'shared'}
    add(c,'every module discipline has one canonical accountable lane',lane_map==expected,
        f'mapped={len(lane_map)} expected={len(expected)}')
    add(c,'lane finalisation derives mandatory lanes from module population',
        'mandatoryLaneKeys' in lane and 'const required = new Set<LaneKey>()' in lane
        and 'const lanes = [...new Set<LaneKey>([...requested, ...required])]' in lane
        and 'laneForModuleDiscipline(row.data.discipline)' in lane
        and 'moduleRows' in lane and 'Lane-set finalisation exceeds the governed transaction size' in lane,
        'classification cannot omit lanes already required by work')
    add(c,'lane mutation remaps dependent modules atomically or refuses',
        'A lane with active modules may only be replaced by a new generation of the same canonical lane.' in lane
        and 'workflowLaneFirestoreId' in lane and 'remappedModuleCount' in lane,
        'module identity is never stranded by lane removal')
    add(c,'workflow cancellation projects across old and new data planes',
        all(token in lane for token in ['isCancelled: true','assignedAgencies: []','maintenanceProjectionForRelease',
                                        'isDeleted: true','equipmentProjectionWrite','audit_logs/workflow_cancel_']),
        'execution, lanes, compliance, maintenance, modules, equipment and audit move together')

    add(c,'compliance commands are workflow-bound and terminal guarded',
        'requireComplianceForWorkflow' in compliance and 'requireMutableWorkflow' in compliance
        and 'assertMaintenanceBoundToCompliance' in compliance,
        'continuations cannot trust foreign or historical references blindly')
    add(c,'maintenance bridge validates asset/binding and persists queue states',
        'assertMaintenanceCanBind' in bridge and 'assertMaintenanceBoundToCompliance' in bridge
        and 'workflowQueueState' in bridge and 'workflowAggregateId' in bridge,
        'original ticket and compliance request form one contract')
    add(c,'client and Rules block deferred-ticket legacy mutation',
        'workflowDeferred' in rules and 'maintenanceWorkflowFieldsUnchanged' in rules
        and 'maintenanceWorkflowAllowsClientLifecycle' in rules
        and 'isWorkflowActionBlocked' in read('lib/features/maintenance/data/maintenance_model.dart')
        and 'workflowDeferred' in read('lib/features/maintenance/providers/maintenance_provider.dart'),
        'server and local UI agree on deferred ticket authority')

    assets='\n'.join([read('lib/features/assets/providers/asset_timeline_provider.dart'),
                      read('lib/features/reports/providers/fleet_status_provider.dart')])
    add(c,'original asset/report surfaces consume canonical equipment projection',
        'equipment_status' in assets and 'EquipmentStatus' in assets,
        'workflow board is not a third isolated truth')

    pull=read('lib/features/maintenance_workflow/services/workflow_pull_service.dart')
    remote=read('lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart')
    diagnostics=read('lib/features/maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart')
    add(c,'malformed remote records are quarantined per document',
        'WorkflowRemoteFailure' in remote and 'WorkflowRemoteBatch' in remote
        and 'WorkflowPullQuarantineRecord' in pull and '_appendQuarantine' in pull,
        'one poison projection cannot abort valid sibling records')
    add(c,'workflow diagnostics expose quarantine and manual-review commands read-only',
        'readQuarantine' in diagnostics and 'getPendingCommands' in diagnostics
        and 'does not replay' in diagnostics,
        'supportability does not add an unsafe mutation bypass')

    escalation=read('functions/src/maintenanceWorkflow/escalationSweep.ts')
    add(c,'escalation is paged and transactionally revalidated',
        'PAGE_SIZE = 200' in escalation and 'MAX_PER_QUERY_PER_SWEEP = 1000' in escalation
        and 'db.runTransaction' in escalation and 'sourceIsStillEligible' in escalation
        and 'tx.create(eventRef' in escalation,
        'closed work cannot be escalated from a stale scheduler snapshot')
    indexes=json.loads(read('firestore.indexes.json'))['indexes']
    shapes={(x['collectionGroup'],tuple((f['fieldPath'],f.get('order')) for f in x['fields'])) for x in indexes}
    required={('job_lanes',(('status','ASCENDING'),('nextEscalationAt','ASCENDING'))),
              ('compliance_requests',(('status','ASCENDING'),('nextEscalationAt','ASCENDING')))}
    add(c,'escalation indexes match v4 queries',required.issubset(shapes),
        f'present={len(required & shapes)}/{len(required)}')

    security=read('functions/src/callableSecurityConfig.ts')
    release_guard=read('tools/release/Test-ProductionReleasePolicy.ps1')
    app_check_scope=json.loads(read('release/s02-callable-app-check-source-policy.json'))
    callable_policy=app_check_scope['callableAppCheckPolicy']
    add(c,'App Check is shared across discovered mutating callables and remains deploy-time gated',
        'CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK' in security and 'default: false' in security
        and 'MUTATING_CALLABLE_SECURITY_OPTIONS' in read('functions/src/index.ts')
        and 'MUTATING_CALLABLE_SECURITY_OPTIONS' in read('functions/src/maintenanceWorkflow/callable.ts')
        and len(callable_policy['mutatingCallables']) == 6
        and callable_policy['activationAuthorized'] is False,
        'signed-client readiness remains an explicit production gate')
    add(c,'production release rejects provisional Isar authority',
        'PROVISIONAL_V4_ISAR_CODEGEN' in release_guard,
        'source completeness cannot be mistaken for pinned codegen proof')

    add(c,'policy is single-sourced across TypeScript and Dart',
        'MODULE_DISCIPLINE_LANE_MAP' in generated_ts and 'moduleDisciplineLaneMap' in generated_dart
        and 'shared' in generated_ts and 'shared' in generated_dart,
        'v4 lane/module/role policy remains generated')

    migration=read('lib/core/services/isar_schema_migration.dart')
    isar_guard=read('lib/core/services/isar_schema_guard_io.dart')
    startup=read('lib/main.dart')
    add(c,'Isar migration version explicitly advances to v3',
        'currentSchemaVersion = 3' in migration and '3: _reconcileV4WorkflowPersistence' in migration
        and 'MaintenanceRecord+WorkflowBridge' in migration,
        'same-version schema drift is not hidden')
    add(c,'Isar provenance refuses unmarked stores and commits after open',
        all(token in migration for token in [
            'baf_isar_schema_provenance_v1','databaseGenerationId',
            'existing-store-unmarked','legacy-marker-incomplete',
            '_validateMarkerSource('
        ])
        and '.isar.lock' not in isar_guard
        and startup.index('ensureIsarSchemaBeforeOpen(')
            < startup.index('Isar.open(')
            < startup.index('repairPlannedJobLocalLinks(')
            < startup.index('commitAfterSuccessfulOpen()')
        and 'readIsarSchemaProvenanceSnapshotJson()' in startup
        and '"schemaProvenanceSnapshot": $provenanceSnapshot' in startup,
        'one-key PREPARED/COMMITTED provenance blocks silent adoption and preserves generation plus recovery evidence')

    global_pull=subprocess.run(
        [sys.executable,str(ROOT/'tools/v4/verify_global_pull_server_clock.py')],
        cwd=ROOT,text=True,capture_output=True
    )
    add(c,'R-01/R-02 server clock and scoped cursor verifier passes',
        global_pull.returncode==0 and 'SUMMARY | pass=15 fail=0 total=15' in global_pull.stdout,
        (global_pull.stdout or global_pull.stderr).strip())

    schema=subprocess.run([sys.executable,str(ROOT/'tools/isar/verify_v4_isar_schema.py')],
                          cwd=ROOT,text=True,capture_output=True)
    add(c,'v4 Isar source schema verifier passes',schema.returncode==0,
        (schema.stdout or schema.stderr).strip())
    release=subprocess.run([sys.executable,str(ROOT/'tools/isar/verify_v4_isar_schema.py'),'--release'],
                           cwd=ROOT,text=True,capture_output=True)
    provisional=sum(
        1 for path in (ROOT/'lib').rglob('*.g.dart')
        if 'PROVISIONAL_V4_ISAR_CODEGEN' in path.read_text(encoding='utf-8', errors='ignore')
    )
    release_expected = (release.returncode == 0) if provisional == 0 else (release.returncode != 0)
    add(c,'release authority follows pinned-codegen state',release_expected,
        f'provisional={provisional}; verifier_rc={release.returncode}')

    print('CRM3 v4 — WHOLE-APP RECONCILIATION SOURCE AUDIT')
    print(f'root={ROOT}')
    passed=0
    for x in c:
        print(f'{"PASS" if x.ok else "FAIL"} | {x.title} | {x.detail}')
        passed+=int(x.ok)
    print(f'SUMMARY | pass={passed} fail={len(c)-passed} total={len(c)}')
    return 0 if passed==len(c) else 1

if __name__=='__main__': raise SystemExit(main())
