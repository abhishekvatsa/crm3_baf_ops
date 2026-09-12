const fs = require('fs');
const path = require('path');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const fixturePath = path.join(__dirname, 'fixtures/finding_adjudication_legacy_receipt.json');

(process.env.CAPTURE_LEGACY_ADJUDICATION === '1' ? test : test.skip)(
  'capture actual c00 accepted old-client adjudication once', async () => {
    const {captureLegacyFindingAdjudication} = require('./helpers/captureLegacyFindingAdjudication.cjs');
    fs.writeFileSync(fixturePath, JSON.stringify(await captureLegacyFindingAdjudication(), null, 2) + '\n');
  }, 60000);

const fixture = () => JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const seeded = (accepted) => {
  const source = fixture(); const store = new MemoryWorkflowStore();
  for (const [key, value] of source.documents) {
    if (accepted || !key.startsWith('maintenance_workflow_command_receipts/') && !key.startsWith('inspection_finding_events/')) {
      store.seed(key, value);
    }
  }
  return {source, store, service: new MaintenanceWorkflowCommandService(store)};
};

test('never-accepted Build21/27-shaped adjudication asks for app update and explicit review without manufacturing a revision', async () => {
  const {source, store, service} = seeded(false); const before = store.entries();
  await expect(service.execute(source.command, {actor: source.actor, serverNow: new Date('2026-09-12T12:00:00Z')}))
    .rejects.toMatchObject({code: 'failed-precondition', details: {
      reasonCode: 'inspection-finding-client-update-required', requiredCapability: 'inspectionFindingExpectedVersion.v1'}});
  expect(store.entries()).toEqual(before);
  expect(source.command.payload).not.toHaveProperty('expectedFindingVersion');
});

test('actual old accepted command replays before new revision capability gate, unchanged after later finding evidence', async () => {
  const {source, store, service} = seeded(true);
  store.seed('inspection_findings/legacy-finding', {...store.read('inspection_findings/legacy-finding'), version: 8, status: 'open'});
  const before = store.entries();
  expect(await service.execute(source.command, {actor: source.actor, serverNow: new Date('2026-09-12T12:00:00Z')}))
    .toEqual(source.accepted);
  expect(store.entries()).toEqual(before);
});

test('legacy receipt is neither borrowed by another account nor rewritten with a newly invented revision', async () => {
  const {source, store, service} = seeded(true);
  store.seed('users/another-admin', {isApproved: true, roles: ['admin'], name: 'Another Admin'});
  await expect(service.execute(source.command, {actor: {uid: 'another-admin', name: 'Another Admin'}, serverNow: new Date()}))
    .rejects.toMatchObject({code: 'permission-denied'});
  await expect(service.execute({...source.command, payload: {...source.command.payload, expectedFindingVersion: 3}},
    {actor: source.actor, serverNow: new Date()})).rejects.toMatchObject({code: 'command-idempotency-conflict'});
});

test('fresh reviewed command retains the finding revision fence and uses a distinct explicit command ID', async () => {
  const {source, store, service} = seeded(false);
  const request = {...source.command, commandId: 'explicit-reviewed-current', payload: {
    ...source.command.payload, expectedFindingVersion: 2, status: 'invalidated'}};
  await expect(service.execute(request, {actor: source.actor, serverNow: new Date()}))
    .rejects.toMatchObject({code: 'aborted', details: {reasonCode: 'inspection-finding-version-conflict'}});
  request.payload.expectedFindingVersion = store.read('inspection_findings/legacy-finding').version;
  const result = await service.execute(request, {actor: source.actor, serverNow: new Date('2026-09-12T12:00:00Z')});
  expect(result.resultKey).toBe('inspection-finding-invalidated');
});
