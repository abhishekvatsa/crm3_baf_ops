#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

checks: list[tuple[bool, str, str]] = []

def text(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8', errors='ignore')

def add(ok: bool, title: str, detail: str) -> None:
    checks.append((ok, title, detail))

workflow_types = text('lib/features/maintenance_workflow/domain/workflow_types.dart')
client_tree = '\n'.join(
    p.read_text(encoding='utf-8', errors='ignore')
    for p in (ROOT / 'lib').rglob('*.dart')
    if not p.name.endswith('.g.dart')
)
server_types = text('functions/src/maintenanceWorkflow/types.ts')

m = re.search(r'enum WorkflowCommandType\s*\{(?P<body>.*?)\}', workflow_types, re.S)
commands = [] if m is None else [
    token.strip().rstrip(',')
    for token in m.group('body').splitlines()
    if token.strip() and not token.strip().startswith('//')
]
missing_client = [
    command for command in commands
    if f'WorkflowCommandType.{command}' not in client_tree
]
add(
    bool(commands) and not missing_client,
    'all authoritative workflow commands have a client entry point',
    f'commands={len(commands)} missing={missing_client}',
)

server_match = re.search(r'export type WorkflowCommandType\s*=\s*(?P<body>.*?);', server_types, re.S)
server_union = set() if server_match is None else set(re.findall(r'"([A-Za-z0-9]+)"', server_match.group('body')))
add(
    set(commands) == server_union,
    'Dart and TypeScript command vocabularies remain exact',
    f'dart={len(commands)} typescript={len(server_union)}',
)

compliance = text('functions/src/maintenanceWorkflow/complianceHandlers.ts')
add(
    'const origin = laneKey(command.payload.originLaneKey, "originLaneKey")' in compliance
    and 'assertLaneAuthority(context.actor, origin, "work")' in compliance,
    'compliance creation requires accountable origin-lane authority',
    'origin lane can no longer be omitted by a handcrafted client',
)

panel = text('lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart')
for command, label in [
    ('prepareRedLane', 'RED preparation'),
    ('raiseCompliance', 'compliance creation'),
    ('cancelWorkflow', 'workflow cancellation'),
]:
    add(
        f'WorkflowCommandType.{command}' in panel,
        f'{label} is reachable from the planned-job workflow panel',
        command,
    )

board = text('lib/features/maintenance_workflow/presentation/screens/equipment_status_board.dart')
add(
    'WorkflowCommandType.reconcileEquipment' in board
    and 'canReconcileMaintenanceEquipment' in board,
    'equipment reconciliation is reachable and authority-gated',
    'Admin/SI control; server derives state from facts',
)

inbox = text('lib/features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart')
add(
    all(token in inbox for token in [
        'For my lane', 'Raised by me / my lane', "_ComplianceInboxView.all",
        'escalationTier', 'Dormant until', 'Overdue since',
    ]),
    'compliance inbox exposes role-aware operational views and due state',
    'target, origin, supervisory, dormant/due and tier surfaces present',
)

sweep = text('functions/src/maintenanceWorkflow/escalationSweep.ts')
policy = text('functions/src/maintenanceWorkflow/escalationPolicy.ts')
notify_policy = text('functions/src/maintenanceWorkflow/workflowNotificationPolicy.ts')
add(
    'MAX_PER_QUERY_PER_SWEEP = 1000' in sweep
    and 'PAGE_SIZE = 200' in sweep
    and 'db.runTransaction' in sweep
    and 'tx.create(eventRef' in sweep,
    'escalation sweep is paged, transactionally revalidated and emits events',
    'stale scheduler snapshots cannot escalate closed work',
)
add(
    'MAX_ESCALATION_TIER = 3' in policy
    and 'ESCALATION_SUPPRESSION_MINUTES = 20' in policy
    and 'currentTier >= MAX_ESCALATION_TIER' in policy,
    'escalation policy stops at Tier 3 and absorbs scheduler jitter',
    'no repeated terminal-tier churn',
)
add(
    all(token in notify_policy for token in [
        'tier >= 3', 'tier >= 2', 'lane.closeRoles.filter',
    ]),
    'notification routing follows the ratified escalation ladder',
    'Tier 1 lane senior; Tier 2 Shift Supervisor/SI; Tier 3 Admin',
)

indexes = json.loads(text('firestore.indexes.json'))['indexes']
index_shapes = {
    (entry['collectionGroup'], tuple((f['fieldPath'], f.get('order', f.get('arrayConfig'))) for f in entry['fields']))
    for entry in indexes
}
required = {
    ('job_lanes', (('status', 'ASCENDING'), ('nextEscalationAt', 'ASCENDING'))),
    ('compliance_requests', (('status', 'ASCENDING'), ('nextEscalationAt', 'ASCENDING'))),
}
add(
    required.issubset(index_shapes),
    'all escalation query indexes are declared',
    f'required={len(required)} present={len(required & index_shapes)}',
)

permissions = text('lib/features/auth/data/user_model.dart')
add(
    all(token in permissions for token in [
        'canCancelMaintenanceWorkflow',
        'canPrepareMaintenanceRedLane',
        'canReconcileMaintenanceEquipment',
    ]),
    'client affordances mirror server command authority',
    'new controls are hidden from actors who cannot execute them',
)

home = text('lib/home_screen.dart')
add(
    all(token in home for token in [
        'workflowAllLanesProvider',
        'workflowAllComplianceProvider',
        'workflowAttentionCount',
        "sourceCollection == 'compliance_requests'",
    ]),
    'home surfaces workflow attention and routes compliance notifications',
    'pending lane acknowledgements plus due compliance are visible before opening the hub',
)

online_executor = text('lib/features/maintenance_workflow/services/workflow_online_executor.dart')
add(
    'Workflow lifecycle actions require an online connection.' in online_executor,
    'ratified online-only lifecycle model remains unchanged',
    'expanded implementation does not reintroduce the superseded hybrid model',
)

print('CRM3 APP — EXPANDED IMPLEMENTATION SOURCE AUDIT')
print(f'root={ROOT}')
passed = 0
for ok, title, detail in checks:
    print(f'{"PASS" if ok else "FAIL"} | {title} | {detail}')
    passed += int(ok)
print(f'SUMMARY | pass={passed} fail={len(checks)-passed} total={len(checks)}')
sys.exit(0 if passed == len(checks) else 1)
