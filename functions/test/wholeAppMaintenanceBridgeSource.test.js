const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

function readDartLibrary(relative) {
  const source = read(relative);
  const directory = path.dirname(relative);
  const parts = [...source.matchAll(/^\s*part\s+['"]([^'"]+)['"];\s*$/gm)]
    .map((match) => read(path.join(directory, match[1])));
  return [source, ...parts].join('\n');
}

const workflowFields = [
  'workflowDeferred',
  'workflowQueueState',
  'workflowAggregateId',
  'workflowComplianceId',
  'workflowOriginLaneKey',
  'workflowTargetLaneKey',
  'workflowConditionTypeKey',
  'workflowConditionRef',
  'workflowDeferredAt',
  'workflowDeferredByUid',
  'workflowDeferredByName',
  'workflowReactivatedAt',
  'workflowReactivatedByUid',
  'workflowReactivatedByName',
  'workflowReleasedAt',
  'workflowReleasedByUid',
  'workflowReleasedByName',
  'workflowCorrectionReason',
  'workflowUpdatedAt',
];

function functionBody(source, name, nextName) {
  const start = source.indexOf(name);
  expect(start).toBeGreaterThanOrEqual(0);
  const end = nextName == null ? source.length : source.indexOf(nextName, start + name.length);
  expect(end).toBeGreaterThan(start);
  return source.slice(start, end);
}

describe('whole-app maintenance workflow bridge source contract', () => {
  test('all server-owned workflow fields exist in model, both pull paths, and Rules', () => {
    const model = read('lib/features/maintenance/data/maintenance_model.dart');
    const livePull = read('lib/core/services/live_remote_sync_service.dart');
    const repository = readDartLibrary(
      'lib/features/maintenance/providers/maintenance_provider.dart',
    );
    const rules = read('firestore.rules');
    for (const field of workflowFields) {
      expect(model).toContain(field);
      expect(livePull).toContain(field);
      expect(repository).toContain(field);
      expect(rules).toContain(`'${field}'`);
    }
  });

  test('client command and replay serializers omit server-owned workflow fields', () => {
    const sync = read('lib/core/services/sync_service.tickets_templates.dart');
    const create = read('lib/features/maintenance/services/maintenance_issue_create_command.dart');
    const close = functionBody(sync, '_maintenanceCloseReplayStepData', '_maintenanceReopenReplayStepData');
    const reopen = functionBody(sync, '_maintenanceReopenReplayStepData', '_maintenanceCloseEvidence');
    for (const body of [create, close, reopen]) {
      for (const field of workflowFields) expect(body).not.toContain(`'${field}'`);
    }
  });

  test('original maintenance actions are blocked locally and by Rules while deferred', () => {
    const provider = readDartLibrary(
      'lib/features/maintenance/providers/maintenance_provider.dart',
    );
    const resolve = read('lib/features/maintenance/presentation/resolve_form.dart');
    const closed = read('lib/features/maintenance/presentation/closed_tickets_screen.dart');
    const ticket = read('lib/features/maintenance/presentation/ticket_screen.dart');
    const rules = read('firestore.rules');
    expect(provider).toContain('_requireMaintenanceWorkflowAllowsAction');
    expect(provider).toContain('_requireMaintenanceWorkflowMapAllowsAction');
    expect(resolve).toContain('widget.ticket.workflowDeferred');
    expect(closed).toContain('ticket.workflowDeferred');
    expect(ticket).toContain('!ticket.workflowDeferred');
    expect(rules).toContain('maintenanceWorkflowAllowsClientLifecycle()');
    expect(rules).toContain("resource.data.get('workflowDeferred', false) == false");
  });

  test('compliance UI suppresses actions after workflow terminal state', () => {
    const detail = read('lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart');
    expect(detail).toContain('snapshot?.workflow.isFinal');
    expect(detail).toContain('This workflow is completed or cancelled');
    expect(detail.indexOf('else if (workflowFinal)')).toBeLessThan(detail.indexOf('..._actions('));
  });
});
