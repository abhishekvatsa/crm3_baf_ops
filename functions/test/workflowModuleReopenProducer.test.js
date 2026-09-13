const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

test('actual governed reopen handler matches the cross-runtime native adoption fixture', async () => {
  const destination = path.resolve(__dirname, '../../test/fixtures/workflow_module_reopen_actual_handler.json');
  const existing = fs.existsSync(destination) ? JSON.parse(fs.readFileSync(destination, 'utf8')) : null;
  const beforeModule = existing?.beforeModule ?? {...JSON.parse(fs.readFileSync(path.resolve(__dirname,
    '../../build/review-20260913/workflow-module-before-seed.json'), 'utf8')), laneKey: 'mech', workflowLaneFirestoreId: 'job-7__mech'};
  const store = new MemoryWorkflowStore();
  const actor = {uid: 'admin-1', name: 'admin-1'};
  store.seed('users/admin-1', {isApproved: true, roles: ['admin'], name: actor.name});
  store.seed('maintenance_workflows/job-7', {jobExecutionId: 'job-7', status: 'readyForClosure', version: 10,
    assetTypeKey: 'base', assetNumber: 107, laneSetFinalizedAt: '2026-09-12T00:00:00.000Z', cancelled: false});
  store.seed('job_executions/job-7', {version: 2, workflowSchemaVersion: 1, isCompleted: false, isCancelled: false});
  store.seed('job_lanes/job-7__mech', {workflowId: 'job-7', jobExecutionId: 'job-7', laneKey: 'mech', status: 'closed',
    activationGeneration: 1, version: 3, progressRevision: 1});
  store.seed('job_modules/module-7', beforeModule);
  const command = {commandId: 'reopen-module-command', commandType: 'reopenWorkflowModule', aggregateId: 'job-7',
    expectedVersion: 10, payload: {moduleFirestoreId: 'module-7', reason: 'Reinspect seal'}};
  const service = new MaintenanceWorkflowCommandService(store);
  const receipt = await service.execute(command,
    {actor, serverNow: new Date('2026-09-13T06:00:00.000Z')});
  const result = {provenance: {
    producer: 'MaintenanceWorkflowCommandService.execute -> reopenWorkflowModule; MemoryWorkflowStore',
    handlerNormalizedLfSha256: createHash('sha256').update(fs.readFileSync(path.resolve(__dirname,
      '../src/maintenanceWorkflow/moduleLifecycleHandlers.ts'), 'utf8').replace(/\r\n/g, '\n')).digest('hex'),
    moduleSeed: 'Actual Dart JobModule.toMap() from native adoption test; canonical governed laneKey mech and lane reference applied before dispatch.',
  }, actor, command, receipt, beforeModule,
  audit: store.read('audit_logs/workflow_module_reopen_module-7_11'), module: store.read('job_modules/module-7')};
  expect(receipt.resultKey).toBe('workflow-module-reopened');
  expect(result.module).toMatchObject({version: 5, status: 'reopened', isOpenForWork: true});
  expect(JSON.parse(result.audit.beforeJson)).toEqual(beforeModule);
  if (process.env.GENERATE_WORKFLOW_REOPEN_FIXTURE === '1') fs.writeFileSync(destination, `${JSON.stringify(result, null, 2)}\n`);
  else expect(result).toEqual(existing);
  // Real command B advances the workflow beyond A's acceptance. Its stored
  // receipt must win before the stale-version guard is reached on A's retry.
  const context = {actor, serverNow: new Date('2026-09-13T06:05:00.000Z')};
  await service.execute({commandId: 'add-electrical-after-reopen', commandType: 'addLane', aggregateId: 'job-7',
    expectedVersion: 11, payload: {laneKey: 'elec', reason: 'Electrical follow-up now required.'}}, context);
  expect(store.read('maintenance_workflows/job-7').version).toBe(12);
  let before = store.entries();
  await expect(service.execute(command, context)).resolves.toEqual(receipt);
  expect(store.entries()).toEqual(before);
  const receiptPath = 'maintenance_workflow_command_receipts/reopen-module-command';
  const savedReceipt = store.read(receiptPath);
  for (const [patch, code] of [[{receiptSchemaVersion: 99}, 'failed-precondition'],
    [{payloadFingerprint: `sha256:${'0'.repeat(64)}`}, 'command-idempotency-conflict']]) {
    store.seed(receiptPath, {...savedReceipt, ...patch}); before = store.entries();
    await expect(service.execute(command, context)).rejects.toMatchObject({code});
    expect(store.entries()).toEqual(before);
  }
  store.seed(receiptPath, savedReceipt); before = store.entries();
  await expect(service.execute({...command, commandId: 'fresh-stale-reopen'}, context)).rejects.toMatchObject({
    code: 'workflow-version-conflict', details: {expectedVersion: 10, actualVersion: 12}});
  expect(store.entries()).toEqual(before);
});
