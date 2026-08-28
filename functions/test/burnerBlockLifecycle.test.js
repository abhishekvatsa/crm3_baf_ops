'use strict';

const {
  applyBurnerBlockLifecycleWritePlan,
  prepareBurnerBlockLifecycleWritePlan,
} = require('../lib/maintenanceWorkflow/burnerBlockLifecycle');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

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
      completedBy: actor,
      ...overrides,
    });
    applyBurnerBlockLifecycleWritePlan(tx, plan);
    return plan;
  });
}

describe('burner-block lifecycle projection', () => {
  test('atomically projects governed SAIL/RED replacement evidence', async () => {
    const store = seedStore();
    const plan = await prepare(store);
    const [path, event] = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_events/'));
    const [currentPath, current] = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_current/'));

    expect(plan.events).toHaveLength(1);
    expect(plan.currentStates).toHaveLength(1);
    expect(path).toMatch(/^burner_block_lifecycle_events\/bbl_[a-f0-9]{40}$/);
    expect(currentPath).toMatch(
      /^burner_block_lifecycle_current\/bblc_[a-f0-9]{40}$/,
    );
    expect(event).toMatchObject({
      assetInstanceId: IDS.asset,
      assetNumber: 7,
      burnerPosition: 3,
      supplyMode: 'sailRed',
      installationDiscipline: 'mechanical',
      performedByName: 'Mechanical Technician One',
      sourceType: 'workflowPlannedJob',
      sourceModuleId: 'module-1',
      completedByUid: actor.uid,
      isDeleted: false,
    });
    expect(current).toMatchObject({
      projectionSchemaVersion: 1,
      currentEventId: event.eventId,
      eventId: event.eventId,
      burnerPosition: 3,
      installationDiscipline: 'mechanical',
    });
  });

  test('projects a supported legacy replacement action alias', async () => {
    const store = seedStore();
    const plan = await prepare(store, action({
      actionType: undefined,
      action: 'replacement',
    }));
    const event = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_events/'))[1];

    expect(plan.events).toHaveLength(1);
    expect(event).toMatchObject({
      eventType: 'replacement',
      assetInstanceId: IDS.asset,
      burnerPosition: 3,
      supplyMode: 'sailRed',
    });
  });

  test('current state retains the latest physical replacement across history', async () => {
    const store = seedStore();
    await prepare(store, action({
      id: 'action-newer',
      createdAt: '2026-08-28T08:00:00.000Z',
    }), {sourceId: 'execution-newer'});
    const before = store.entries().find(([path]) =>
      path.startsWith('burner_block_lifecycle_current/'))[1];

    await prepare(store, action({
      id: 'action-older',
      createdAt: '2026-08-28T07:00:00.000Z',
    }), {sourceId: 'execution-older'});
    const after = store.entries().find(([path]) =>
      path.startsWith('burner_block_lifecycle_current/'))[1];

    expect(after.currentEventId).toBe(before.currentEventId);
    expect(store.entries().filter(([path]) =>
      path.startsWith('burner_block_lifecycle_events/'))).toHaveLength(2);
  });

  test('retains optional purchased supplier and purchase-order evidence', async () => {
    const store = seedStore();
    await prepare(store, action({
      burnerBlockSupplyMode: 'purchased',
      burnerBlockSupplierName: 'Industrial Refractories Ltd',
      burnerBlockPurchaseOrderNumber: 'PO-2026-411',
    }));
    const event = store.entries().find(([path]) =>
      path.startsWith('burner_block_lifecycle_events/'))[1];

    expect(event).toMatchObject({
      supplyMode: 'purchased',
      supplierName: 'Industrial Refractories Ltd',
      purchaseOrderNumber: 'PO-2026-411',
    });
  });

  test('binds a definition tag to the exact Furnace hierarchy target', async () => {
    const store = seedStore();
    store.seed(`asset_hierarchy_nodes/${IDS.node}`, {
      schemaVersion: 1,
      nodeId: IDS.node,
      assetClassId: IDS.assetClass,
      name: 'Burner blocks and firing tubes',
      componentTag: 'BB-REF',
      hierarchyPath: [
        'Furnace',
        'Refractory system',
        'Burner blocks and firing tubes',
      ],
      nodeType: 'component',
      status: 'active',
      version: 3,
    });

    await expect(prepare(store, action({tag: 'bb ref'}))).resolves.toMatchObject({
      events: [expect.objectContaining({
        data: expect.objectContaining({componentTag: 'BB-REF'}),
      })],
    });
    await expect(prepare(store, action({tag: 'different-tag'}))).rejects
      .toMatchObject({
        code: 'aborted',
        details: {reasonCode: 'burner-block-lifecycle-target-changed'},
      });
  });

  test('accepts legacy and issue-specific installed-component references', async () => {
    for (const schemaVersion of [2, 3]) {
      const store = seedStore();
      store.seed(`asset_component_instances/${IDS.component}`, {
        schemaVersion: 1,
        componentInstanceId: IDS.component,
        assetClassId: IDS.assetClass,
        assetInstanceId: IDS.asset,
        assetNumber: 7,
        status: 'active',
        version: 2,
        assetInstanceVersionAtMutation: 4,
        definitionNodeId: IDS.node,
        definitionNodeVersion: 3,
        componentTag: 'FR-07-BB-03',
      });
      const row = action({
        tag: 'fr 07 bb 03',
        assetHierarchyRef: {
          ...action().assetHierarchyRef,
          schemaVersion,
          scope: 'installedComponent',
          componentInstanceId: IDS.component,
          componentInstanceVersion: 2,
          componentTag: 'FR-07-BB-03',
        },
      });

      await expect(prepare(store, row)).resolves.toMatchObject({
        events: [expect.objectContaining({
          data: expect.objectContaining({componentTag: 'FR-07-BB-03'}),
        })],
      });
    }
  });

  test.each([
    ['missing provenance', action({burnerBlockSupplyMode: null})],
    ['unresolved replacement', action({status: 'inProgress'})],
    ['wrong asset type', action(), {assetType: 'base'}],
    ['wrong hierarchy schema', action({
      assetHierarchyRef: {...action().assetHierarchyRef, schemaVersion: 3},
    })],
  ])('fails closed for %s', async (_label, row, overrides = {}) => {
    await expect(prepare(seedStore(), row, overrides)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  test('ordinary actions and burner attendance do not invent replacement events', async () => {
    const store = seedStore();
    const ordinary = action({
      actionType: 'inspection',
      replacement: null,
      burnerPosition: null,
      burnerBlockSupplyMode: null,
    });
    const attendance = action({
      component: 'Burner assembly',
      hierarchyPath: null,
      assetHierarchyRef: null,
      actionType: 'repair',
      replacement: null,
      attendanceSessionId: 'burner_ticket-1_3',
      burnerActionCode: 'feedback_reset',
      burnerOutcome: 'resolved',
      burnerBlockSupplyMode: null,
    });
    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'maintenanceIssue',
        sourceId: 'ticket-1',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([ordinary, attendance]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan.events).toEqual([]);
  });

  test('planned maintenance without a burner-block change leaves lifecycle untouched', async () => {
    const store = seedStore();
    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-no-block-change',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: false,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan).toEqual({events: [], currentStates: []});
    expect(store.entries().some(([path]) =>
      path.startsWith('burner_block_lifecycle_events/') ||
      path.startsWith('burner_block_lifecycle_current/'))).toBe(false);
  });

  test('a module-declared block change requires governed replacement evidence', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-1',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03b',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: true,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-action-required'},
    });
  });

  test('rejects replacement evidence outside a Mechanical work context', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-1',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03',
          discipline: 'instrumentation',
          actionsJson: JSON.stringify([action()]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-mechanical-work-required'},
    });
  });
});
