const {
  prepareMaintenanceCompletionWritePlan, applyMaintenanceCompletionWritePlan,
  dueProjectionFromSource, dueStatePath,
} = require('../lib/maintenanceWorkflow/maintenanceIntelligence');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const identity = {
  assetIdentityKey: 'class-furnace:furnace-7', assetTypeKey: 'furnace',
  assetNumber: 7, assetClassId: 'class-furnace', assetInstanceId: 'furnace-7',
};
const fallback = {...identity, assetDisplayName: 'Furnace 7', counterLabel: 'Service', thresholdDays: 30};
const duePath = dueStatePath(identity.assetIdentityKey, 'SERVICE');
const at = '2026-08-20T06:30:00.000Z';
function classification(days) {
  return {schemaVersion: 1, definitionId: `class-${days}`, definitionVersion: 1,
    code: `MAINT_${days}`, title: `Maintenance ${days}`, assetTypeKeys: ['furnace'],
    assetClassIds: [], resetCounters: [{key: 'SERVICE', label: 'Service', thresholdDays: days}], principalLaneKey: 'mech'};
}
async function complete(store, id, days, options = {}) {
  return store.runTransaction(async (tx) => {
    const plan = await prepareMaintenanceCompletionWritePlan({tx,
      execution: {...identity, assetInstanceName: 'Furnace 7'}, executionId: id,
      sourceType: 'historicalMaintenance', completedAt: at,
      completedBy: {uid: null, name: null}, recordedAt: '2026-08-21T08:00:00.000Z',
      classification: classification(days), datePrecision: 'date', ...options});
    applyMaintenanceCompletionWritePlan(tx, plan);
    return plan;
  });
}
function rebuild(store) {
  return dueProjectionFromSource(duePath, 'SERVICE', store.entries()
    .filter(([path]) => path.startsWith('maintenance_completion_sources/'))
    .map(([path, data]) => ({path, data})), '2026-08-21T08:00:00.000Z', fallback);
}

test.each([[30, 90], [90, 30]])('same-day conflict remains held in arrival order %j', async (a, b) => {
  const store = new MemoryWorkflowStore();
  await complete(store, `source-${a}`, a);
  await complete(store, `source-${b}`, b);
  expect(store.read(duePath)).toMatchObject({classificationPending: true,
    reviewReason: 'conflicting-same-day-evidence', nextDueAt: null});
  expect(store.read(duePath)).toEqual(rebuild(store));
  expect(store.read(duePath).conflictingCompletionEventIds).toHaveLength(2);
});

test('different clocks within the same Indian plant day still require review', async () => {
  const store = new MemoryWorkflowStore();
  await complete(store, 'early', 30, {completedAt: '2026-08-19T19:00:00.000Z'});
  await complete(store, 'late', 90, {completedAt: '2026-08-20T17:00:00.000Z'});
  expect(store.read(duePath).classificationPending).toBe(true);
});

test('later physical day settles a previous same-day conflict without deleting evidence', async () => {
  const store = new MemoryWorkflowStore();
  await complete(store, 'a', 30); await complete(store, 'b', 90);
  await complete(store, 'c', 30, {completedAt: '2026-08-21T06:30:00.000Z'});
  expect(store.read(duePath)).toMatchObject({classificationPending: false, reviewReason: null,
    conflictingCompletionEventIds: [], nextDueAt: '2026-09-20T06:30:00.000Z'});
  expect(store.entries().filter(([p]) => p.startsWith('maintenance_completion_events/'))).toHaveLength(3);
});

test('correction replaces one interpretation instead of conflicting with its own prior revision', async () => {
  const store = new MemoryWorkflowStore();
  await complete(store, 'a', 30); await complete(store, 'b', 90);
  await complete(store, 'b', 30, {classificationRevision: 2});
  expect(store.read(duePath).classificationPending).toBe(false);
  expect(store.read(duePath)).toEqual(rebuild(store));
  expect(store.entries().filter(([p]) => p.startsWith('maintenance_completion_events/'))).toHaveLength(3);
});

test('historical-only source retains exclusion in rebuild and later revisions', async () => {
  const store = new MemoryWorkflowStore();
  const original = await complete(store, 'retired', 30, {cadenceApplicability: 'historicalOnly'});
  expect(store.read(duePath)).toBeNull();
  expect(original.eventData).toMatchObject({cadenceApplicability: 'historicalOnly', datePrecision: 'date'});
  expect(rebuild(store)).toMatchObject({classificationPending: true, nextDueAt: null});
  await complete(store, 'retired', 90, {classificationRevision: 2});
  expect(store.read(original.sourcePath).cadenceApplicability).toBe('historicalOnly');
  await complete(store, 'active', 30, {completedAt: '2026-08-01T06:30:00.000Z'});
  expect(store.read(duePath)).toMatchObject({lastCompletionSourceId: 'active', nextDueAt: '2026-08-31T06:30:00.000Z'});
});

test.each([true, false])('legacy and registered tracks are qualified without merging identity (legacy first=%s)', async (legacyFirst) => {
  const store = new MemoryWorkflowStore();
  const legacy = () => complete(store, 'legacy', 30, {
    execution: {assetTypeKey: 'furnace', assetNumber: 7}, sourceType: 'legacyPlannedJob',
  });
  const registered = () => complete(store, 'registered', 30);
  if (legacyFirst) { await legacy(); await registered(); }
  else { await registered(); await legacy(); }
  for (const path of [duePath, dueStatePath('furnace:7', 'SERVICE')]) {
    expect(store.read(path)).toMatchObject({classificationPending: true,
      reviewReason: 'legacy-identity-review-required', nextDueAt: null});
  }
  expect(store.entries().filter(([p]) => p.startsWith('maintenance_completion_events/'))).toHaveLength(2);
});

test('distinct registered assets with reused numbers are not merged or held as legacy aliases', async () => {
  const store = new MemoryWorkflowStore();
  await complete(store, 'first', 30);
  await complete(store, 'replacement', 90, {execution: {...identity, assetInstanceId: 'replacement-7'}});
  expect(store.read(duePath).classificationPending).toBe(false);
  expect(store.read(dueStatePath('class-furnace:replacement-7', 'SERVICE')).classificationPending).toBe(false);
});
