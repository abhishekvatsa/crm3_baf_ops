'use strict';
// No network, emulator or Jest dependency. Runs against the TypeScript compiler's
// actual emitted workflow implementation. BAF_COMPILED_ROOT is used only for
// untouched-baseline comparison; normal execution reads functions/lib.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.env.BAF_COMPILED_ROOT || path.resolve(__dirname, '../lib');
const {MemoryWorkflowStore} = require(path.join(root, 'maintenanceWorkflow/memoryStore'));
const {MaintenanceWorkflowCommandService} = require(path.join(root, 'maintenanceWorkflow/dispatcher'));
const {readExistingReceipt, receiptPath} = require(path.join(root, 'maintenanceWorkflow/idempotency'));
const {payloadFingerprint} = require(path.join(root, 'maintenanceWorkflow/utils'));
const {prepareBurnerBlockLifecycleWritePlan, applyBurnerBlockLifecycleWritePlan} =
  require(path.join(root, 'maintenanceWorkflow/burnerBlockLifecycle'));
const IDS = {
  assetClass: 'class-furnace',
  asset: 'furnace-7',
  node: 'node-burner-block',
  component: 'component-burner-block-3',
};

const actor = {
  uid: 'supervisor-1',
  name: 'Supervisor One',
  roles: new Set(['shiftSupervisor']),
};

function action(overrides = {}) {
  return {
    schemaVersion: 1,
    id: 'action-1',
    asset: 'Furnace 7',
    component: 'Burner blocks and firing tubes',
    hierarchyPath: [
      'Furnace',
      'Refractory system',
      'Burner blocks and firing tubes',
    ],
    assetHierarchyRef: {
      schemaVersion: 4,
      scope: 'componentDefinitionOnAsset',
      assetClassId: IDS.assetClass,
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      nodeId: IDS.node,
      nodeVersion: 3,
      nodeName: 'Burner blocks and firing tubes',
      assetInstanceId: IDS.asset,
      assetInstanceVersion: 4,
      assetNumber: 7,
      assetInstanceName: 'Furnace 7',
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: [
        'Furnace',
        'Refractory system',
        'Burner blocks and firing tubes',
      ],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'RED',
      accountableRoleKeys: ['seniorRefractory'],
      innerCoverAssociation: null,
    },
    system: 'Furnace',
    subsystem: 'Refractory system',
    subComponent: null,
    tag: null,
    instance: null,
    actionType: 'replacement',
    replacement: 'newPart',
    issue: 'Burner block was cracked.',
    resolution: null,
    remarks: null,
    templateFieldKey: null,
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-08-28T08:00:00.000Z',
    severity: 'medium',
    performedBy: 'Mechanical Technician One',
    updatedAt: null,
    version: 1,
    metadataJson: null,
    attendanceSessionId: null,
    burnerPosition: 3,
    burnerActionCode: null,
    burnerOutcome: null,
    burnerMicroampReading: null,
    burnerBlockSupplyMode: 'sailRed',
    burnerBlockSupplierName: null,
    burnerBlockPurchaseOrderNumber: null,
    ...overrides,
  };
}

function seedStore() {
  const store = new MemoryWorkflowStore();
  store.seed(`asset_classes/${IDS.assetClass}`, {
    schemaVersion: 1,
    assetClassId: IDS.assetClass,
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
  });
  store.seed(`asset_instances/${IDS.asset}`, {
    schemaVersion: 1,
    assetInstanceId: IDS.asset,
    assetClassId: IDS.assetClass,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 7,
    name: 'Furnace 7',
    status: 'active',
    version: 4,
  });
  store.seed(`asset_hierarchy_nodes/${IDS.node}`, {
    schemaVersion: 1,
    nodeId: IDS.node,
    assetClassId: IDS.assetClass,
    name: 'Burner blocks and firing tubes',
    hierarchyPath: [
      'Furnace',
      'Refractory system',
      'Burner blocks and firing tubes',
    ],
    nodeType: 'component',
    status: 'active',
    version: 3,
  });
  return store;
}

async function prepare(store, row = action(), overrides = {}) {
  return store.runTransaction(async (tx) => {
    const plan = await prepareBurnerBlockLifecycleWritePlan({
      tx,
      sourceType: 'workflowPlannedJob',
      sourceId: 'execution-1',
      assetType: 'furnace',
      assetNumber: 7,
      actionSources: [{
        sourceModuleId: 'module-1',
        discipline: 'mechanical',
        actionsJson: JSON.stringify([row]),
      }],
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T09:00:00.000Z',
      completedBy: actor,
      ...overrides,
    });
    applyBurnerBlockLifecycleWritePlan(tx, plan);
    return plan;
  });
}


// The lifecycle fixture above is derived from burnerBlockLifecycle.test.js in
// the uploaded snapshot; it retains the native governed hierarchy contract.
const nextTurn = () => new Promise((resolve) => setImmediate(resolve));

test('memory: a late duplicate create rolls back all preceding writes', async () => {
  const store = new MemoryWorkflowStore();
  store.seed('things/existing', {version: 1});
  const before = store.entries();
  await assert.rejects(store.runTransaction(async (tx) => {
    tx.set('things/first', {version: 2});
    tx.create('things/existing', {version: 3});
  }), /already-exists/);
  assert.deepEqual(store.entries(), before);
});
test('memory: a missing update rolls back preceding delete and set', async () => {
  const store = new MemoryWorkflowStore();
  store.seed('things/existing', {version: 1});
  const before = store.entries();
  await assert.rejects(store.runTransaction(async (tx) => {
    tx.delete('things/existing');
    tx.set('things/new', {version: 2});
    tx.update('things/missing', {version: 3});
  }), /not-found/);
  assert.deepEqual(store.entries(), before);
});
test('memory: callback rejection does not commit scheduled writes', async () => {
  const store = new MemoryWorkflowStore();
  await assert.rejects(store.runTransaction(async (tx) => {
    tx.set('things/a', {ok: true});
    throw new Error('cancel');
  }), /cancel/);
  assert.equal(store.read('things/a'), null);
});
test('memory: write captures nested data when enqueued', async () => {
  const store = new MemoryWorkflowStore();
  await store.runTransaction(async (tx) => {
    const data = {nested: {value: 1}};
    tx.set('things/a', data);
    data.nested.value = 2;
  });
  assert.deepEqual(store.read('things/a'), {nested: {value: 1}});
});
test('memory: concurrent read/modify/write operations do not lose an increment', async () => {
  const store = new MemoryWorkflowStore();
  store.seed('things/counter', {count: 0});
  const increment = () => store.runTransaction(async (tx) => {
    const current = await tx.get('things/counter');
    await nextTurn();
    tx.update('things/counter', {count: current.data.count + 1});
  });
  await Promise.all([increment(), increment(), increment()]);
  assert.equal(store.read('things/counter').count, 3);
});
test('memory: a rejected transaction does not poison the next transaction', async () => {
  const store = new MemoryWorkflowStore();
  await assert.rejects(store.runTransaction(async () => { throw new Error('no'); }));
  await store.runTransaction(async (tx) => tx.set('things/next', {ok: true}));
  assert.equal(store.read('things/next').ok, true);
});
test('memory: read-after-write guard is preserved', async () => {
  const store = new MemoryWorkflowStore();
  await assert.rejects(store.runTransaction(async (tx) => {
    tx.set('things/a', {v: 1});
    await tx.get('things/a');
  }), /read-after-write/);
  assert.deepEqual(store.entries(), []);
});

function inspectionStore() {
  const store = new MemoryWorkflowStore();
  store.seed('users/admin-1', {isApproved: true, roles: ['admin'], name: 'Reviewer'});
  store.seed('inspection_campaigns/campaign-1', {version: 3});
  store.seed('inspection_findings/finding-1', {
    campaignId: 'campaign-1', version: 5, status: 'open',
    currentObservationId: 'observation-new',
  });
  return store;
}
function adjudication(payload = {}, overrides = {}) {
  return {
    commandId: 'finding-adjudication-1', commandType: 'adjudicateInspectionFinding',
    aggregateId: 'campaign-1', expectedVersion: 3,
    payload: {findingId: 'finding-1', expectedFindingVersion: 5,
      status: 'acceptedCondition', reason: 'Reviewed latest evidence.', ...payload},
    ...overrides,
  };
}
const inspectionContext = {actor: {uid: 'admin-1', name: 'Reviewer'},
  serverNow: new Date('2026-09-11T08:00:00.000Z')};
test('inspection: fresh adjudication binds and records the reviewed finding revision', async () => {
  const store = inspectionStore();
  const receipt = await new MaintenanceWorkflowCommandService(store).execute(adjudication(), inspectionContext);
  assert.equal(receipt.result.findingVersion, 6);
  assert.equal(store.read('inspection_findings/finding-1').version, 6);
  assert.equal(store.read('inspection_campaigns/campaign-1').version, 3);
  assert.equal(store.read('inspection_finding_events/finding-adjudication-1').previousFindingVersion, 5);
});
test('inspection: stale finding is rejected even while the campaign version matches', async () => {
  const store = inspectionStore(); const before = store.entries();
  await assert.rejects(new MaintenanceWorkflowCommandService(store).execute(
    adjudication({expectedFindingVersion: 4}), inspectionContext),
    (error) => error.code === 'aborted');
  assert.deepEqual(store.entries(), before);
});
test('inspection: missing finding precondition does not silently target the latest revision', async () => {
  const store = inspectionStore(); const before = store.entries();
  const command = adjudication(); delete command.payload.expectedFindingVersion;
  await assert.rejects(new MaintenanceWorkflowCommandService(store).execute(command, inspectionContext),
    (error) => error.code === 'failed-precondition' &&
      error.details?.reasonCode === 'inspection-finding-client-update-required' &&
      error.details?.requiredCapability === 'inspectionFindingExpectedVersion.v1');
  assert.equal(Object.hasOwn(command.payload, 'expectedFindingVersion'), false);
  assert.deepEqual(store.entries(), before);
});
test('inspection: exact accepted replay remains idempotent after finding advances', async () => {
  const store = inspectionStore(); const service = new MaintenanceWorkflowCommandService(store);
  const command = adjudication();
  const receipt = await service.execute(command, inspectionContext);
  store.seed('inspection_findings/finding-1', {campaignId: 'campaign-1', version: 7, status: 'open'});
  assert.deepEqual(await service.execute(command, inspectionContext), receipt);
  assert.equal(store.read('inspection_findings/finding-1').version, 7);
});

function source(id, rows, changed, burner = 3) {
  return {sourceModuleId: id, discipline: 'mechanical', actionsJson: JSON.stringify(rows),
    responsesJson: JSON.stringify([{key:'burnerBlockChanged', value:changed},
      {key:'burnerTarget', value:burner}])};
}
test('burner: another module cannot satisfy a missing changed-module action', async () => {
  const store = seedStore(); const before = store.entries();
  await assert.rejects(prepare(store, action(), {actionSources: [
    source('needs-own-evidence', [], true),
    {sourceModuleId:'unrelated', discipline:'mechanical', actionsJson:JSON.stringify([action()])},
  ]}), (error) => error.details?.reasonCode === 'burner-block-lifecycle-action-required');
  assert.deepEqual(store.entries(), before);
});
test('burner: unchanged in one module does not veto replacement in another module', async () => {
  const store = seedStore();
  const plan = await prepare(store, action(), {actionSources: [
    source('inspection-only', [], false), source('replacement-work', [action()], true),
  ]});
  assert.equal(plan.events.length, 1);
  assert.equal(plan.events[0].data.sourceModuleId, 'replacement-work');
});
test('burner: changed and matching action in the same source succeeds', async () => {
  const store = seedStore();
  const plan = await prepare(store, action(), {actionSources:[source('module-1', [action()], true)]});
  assert.equal(plan.events.length, 1);
});
test('burner: own contradictory unchanged response remains rejected', async () => {
  await assert.rejects(prepare(seedStore(), action(), {actionSources:[source('module-1', [action()], false)]}),
    (error) => error.details?.reasonCode === 'burner-block-lifecycle-action-conflicts-with-response');
});
test('burner: own changed response for a different burner remains rejected', async () => {
  await assert.rejects(prepare(seedStore(), action(), {actionSources:[source('module-1', [action()], true, 4)]}),
    (error) => error.details?.reasonCode === 'burner-block-lifecycle-action-required');
});
// Execution-level evidence is deliberately still admissible. The operator can
// record component work inside the module or on the job completion screen, and
// executionLevelMechanicalEvidence exists so the latter supports a module
// declaration; test/burnerBlockLifecycle.test.js specifies both the accepting
// and the contradicting case. Scoping it out would force the same repair to be
// entered twice and would stop an execution-level replacement from
// contradicting an "unchanged" answer. The source-scope rule is therefore
// about other MODULES, not about execution level.
test('burner: an execution-level action still supports a module declaration', async () => {
  const plan = await prepare(seedStore(), action(), {actionSources: [
    source('module-1', [], true),
    {sourceModuleId:null, discipline:'mechanical', actionsJson:JSON.stringify([action()])},
  ]});
  assert.ok(plan.events.length > 0);
});
test('burner: duplicate source labels cannot share another source occurrence evidence', async () => {
  await assert.rejects(prepare(seedStore(), action(), {actionSources: [
    source('same-label', [], true), source('same-label', [action()], true),
  ]}), (error) => error.details?.reasonCode === 'burner-block-lifecycle-action-required');
});

for (const field of ['commandId', 'aggregateId']) {
  for (const bad of ['', ' ', '.', '..', 'nested/path', 'a\nb', 'é'.repeat(751)]) {
    test(`envelope: rejects unsafe ${field} ${JSON.stringify(bad).slice(0,40)} before store access`, async () => {
      let opened = false;
      const store = {runTransaction:async () => { opened = true; throw new Error('unexpected store access'); }};
      await assert.rejects(new MaintenanceWorkflowCommandService(store).execute(
        adjudication({}, {[field]:bad}), inspectionContext), (error) => error.code === 'invalid-argument');
      assert.equal(opened, false);
    });
  }
}
for (const commandType of ['constructor', '__proto__', 'toString']) {
  test(`envelope: inherited property ${commandType} is not a handler`, async () => {
    let opened = false;
    await assert.rejects(new MaintenanceWorkflowCommandService({runTransaction:async () => {
      opened = true; throw new Error('unexpected store access');
    }}).execute(adjudication({}, {commandType}), inspectionContext),
      (error) => error.code === 'unsupported-workflow-command');
    assert.equal(opened, false);
  });
}
function replayFixture(overrides = {}) {
  const store = new MemoryWorkflowStore(); const command = adjudication();
  const data = {receiptSchemaVersion:2, commandId:command.commandId,
    commandType:command.commandType, aggregateId:command.aggregateId,
    actorUid:'admin-1', authorityScope:{schemaVersion:1, capability:'inspectionFinding.adjudicate'},
    payloadFingerprint:payloadFingerprint(command), resultKey:'inspection-finding-acceptedCondition',
    aggregateVersion:3, result:{campaignId:'campaign-1', findingId:'finding-1', status:'acceptedCondition'},
    appliedAt:'2026-09-11T08:00:00.000Z', ...overrides};
  store.seed(receiptPath(command.commandId), data);
  return {store, command, data};
}
async function replay(overrides) {
  const {store, command} = replayFixture(overrides);
  const before = store.entries();
  try { return await store.runTransaction((tx) => readExistingReceipt(tx, command,
      {uid:'admin-1', name:'Reviewer', roles:new Set(['admin'])})); }
  finally { assert.deepEqual(store.entries(), before); }
}
for (const [label, overrides] of [
  ['blank result key', {resultKey:' '}],
  ['negative version', {aggregateVersion:-1}],
  ['zero nonterminal version', {aggregateVersion:0}],
  ['invalid instant', {appliedAt:'not-a-time'}],
  ['noncanonical instant', {appliedAt:'2026-09-11T08:00:00Z'}],
  ['normalized invalid calendar date', {appliedAt:'2026-02-30T08:00:00.000Z'}],
  ['array result', {result:[]}],
]) {
  test(`replay: rejects ${label} without rewriting stored evidence`, async () => {
    await assert.rejects(replay(overrides),
      (error) => error.details?.reasonCode === 'workflow-receipt-result-malformed');
  });
}
test('replay: preserves a valid complete result payload', async () => {
  const result = {ticketId:'ticket-1', auditId:'audit-1', lane:'mech', correctedFields:['description']};
  const receipt = await replay({result});
  assert.deepEqual(receipt.result, result);
});
test('replay: retains supported zero-version terminal replay', async () => {
  const receipt = await replay({aggregateVersion:0, resultKey:'workflow-already-finalized'});
  assert.equal(receipt.aggregateVersion, 0);
});
