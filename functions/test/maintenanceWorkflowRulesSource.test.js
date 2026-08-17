const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const rules = fs.readFileSync(path.join(repoRoot, 'firestore.rules'), 'utf8');
const indexes = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'firestore.indexes.json'), 'utf8'),
);

function collectionBlock(name, length = 300) {
  const marker = `match /${name}/{docId}`;
  const start = rules.indexOf(marker);
  expect(start).toBeGreaterThanOrEqual(0);
  return rules.slice(start, start + length);
}

function hasIndex(collectionGroup, fields) {
  return indexes.indexes.some((index) => {
    if (index.collectionGroup !== collectionGroup) return false;
    const names = index.fields.map((field) => field.fieldPath);
    return fields.every((field) => names.includes(field));
  });
}

describe('maintenance workflow Firestore source contract', () => {
  test.each([
    'maintenance_workflows',
    'job_lanes',
    'compliance_requests',
    'compliance_attempts',
    'equipment_status',
    'equipment_prompt_master',
    'maintenance_workflow_events',
  ])('%s is readable by approved users but lifecycle writes are server-only', (name) => {
    const block = collectionBlock(name);
    expect(block).toContain('allow read: if isApprovedUser();');
    expect(block).toContain('allow create, update, delete: if false;');
  });

  test('module work is pinned to the exact workflow lane document and Firestore status', () => {
    expect(rules).toContain("resource.data.get('workflowLaneFirestoreId', '')");
    expect(rules).toContain('documents/job_lanes/$(laneDocId)');
    expect(rules).toContain(".data.get('status', '') == 'acknowledged'");
  });

  test('EMD authority is explicit and evaluated before generic supervisor authority', () => {
    const saveStart = rules.indexOf('function rolesCanSaveJobModuleWork');
    const moderatorStart = rules.indexOf('rolesAreModuleLifecycleModerator(roles)', saveStart);
    const emdStart = rules.indexOf("discipline == 'emd'", saveStart);
    expect(saveStart).toBeGreaterThanOrEqual(0);
    expect(emdStart).toBeGreaterThan(saveStart);
    expect(emdStart).toBeLessThan(moderatorStart);
    expect(rules.slice(emdStart, moderatorStart)).toContain("roles.hasAny(['admin', 'si'])");
  });

  test('identical submit and work role policy is compiled through one expression', () => {
    const submitStart = rules.indexOf(
      'function rolesCanSubmitJobModuleDiscipline',
    );
    const submitEnd = rules.indexOf(
      '// END GENERATED WORKFLOW MODULE AUTHORITY',
      submitStart,
    );
    expect(submitStart).toBeGreaterThanOrEqual(0);
    expect(rules.slice(submitStart, submitEnd)).toContain(
      'return rolesCanSaveJobModuleWork(roles, discipline);',
    );
    expect(rules.slice(submitStart, submitEnd)).not.toContain(
      "discipline == 'electrical'",
    );
  });

  test('unreachable legacy helpers stay absent from compiler input', () => {
    for (const helper of [
      'isModuleLifecycleModerator',
      'canAddJobModuleDuringExecution',
      'validJobExecutionComplete',
      'jobModuleSoftDeleteChangedFieldsOnly',
      'maintenanceWorkflowFields()',
      'validMaintenanceAdminSoftDelete',
    ]) {
      expect(rules).not.toContain(`function ${helper}`);
    }
  });

  test('maintenance creation is server-only and deferred tickets block legacy lifecycle writes', () => {
    const maintenanceBlock = collectionBlock('maintenance_records', 500);
    expect(maintenanceBlock).toContain('allow create: if false;');
    expect(maintenanceBlock).toContain('validMaintenanceUpdate()');
    expect(rules).toContain('function maintenanceWorkflowFieldsUnchanged()');
    expect(rules).toContain("resource.data.get('workflowDeferred', false) == false");
    expect(rules).toContain('maintenanceWorkflowAllowsClientLifecycle()');
  });

  test('workflow-v1 job creation is denied to direct client writes', () => {
    expect(rules).toContain("request.resource.data.get('workflowSchemaVersion', 0) == 0");
  });

  test('workflow indexes cover lanes, compliance queues, events and module lane guards', () => {
    expect(hasIndex('job_lanes', ['workflowId', 'displayOrder'])).toBe(true);
    expect(hasIndex('compliance_requests', ['targetLaneKey', 'status', 'becameDueAt'])).toBe(true);
    expect(hasIndex('maintenance_workflow_events', ['aggregateId', 'occurredAt'])).toBe(true);
    expect(hasIndex('job_modules', ['jobExecutionFirestoreId', 'laneKey', 'isOpenForWork'])).toBe(true);
  });
});
