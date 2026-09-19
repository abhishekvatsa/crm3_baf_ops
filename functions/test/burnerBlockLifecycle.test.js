'use strict';

const {
  applyBurnerBlockInstallationCorrection,
  applyBurnerBlockLifecycleWritePlan,
  prepareBurnerBlockInstallationCorrection,
  prepareBurnerBlockLifecycleWritePlan,
} = require('../lib/maintenanceWorkflow/burnerBlockLifecycle');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  workflowFirestoreDataForTest,
} = require('../lib/maintenanceWorkflow/firebaseStore');

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

describe('burner-block lifecycle projection', () => {
  test.each(['maintenanceIssue', 'legacyPlannedJob', 'workflowPlannedJob'])(
    '%s accepts legacy Indian action time and preserves the actual replacement instant', async (sourceType) => {
      const store = seedStore();
      const row = action({createdAt: '2026-08-28T13:30:00.000'});
      await prepare(store, row, {sourceType});
      const [, event] = store.entries().find(([entryPath]) =>
        entryPath.startsWith('burner_block_lifecycle_events/'));
      expect(event).toMatchObject({
        actionPerformedAt: '2026-08-28T08:00:00.000Z',
        completedAt: '2026-08-28T09:00:00.000Z',
        sourceType,
      });
      expect(row.createdAt).toBe('2026-08-28T13:30:00.000');
    },
  );

  test('legacy Indian time still cannot move replacement after closure', async () => {
    const store = seedStore();
    await expect(prepare(store, action({createdAt: '2026-08-28T14:36:00.000'})))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.entries().filter(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_events/'))).toHaveLength(0);
  });

  test('rejects a receipt time that precedes authoritative closure', async () => {
    const store = seedStore();

    await expect(prepare(store, action(), {
      recordedAt: '2026-08-28T08:59:00.000Z',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-closure-time-mismatch',
      },
    });
  });

  test('work entered after it finished keeps both times', async () => {
    const store = seedStore();

    const plan = await prepare(store, action(), {
      recordedAt: '2026-08-28T12:00:00.000Z',
    });

    // When the work finished and when it was entered are different facts, and
    // a late entry must not read as contemporaneous evidence.
    expect(plan.events[0].data).toMatchObject({
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T12:00:00.000Z',
    });
  });

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

  test('a late older physical installation stays in history and cannot silently replace current', async () => {
    const store = seedStore();
    await prepare(store, action({
      id: 'first-recorded',
      createdAt: '2026-08-28T08:00:00.000Z',
    }), {
      sourceId: 'execution-first-recorded',
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T09:00:00.000Z',
    });

    await prepare(store, action({
      id: 'later-recorded-backdated-action',
      createdAt: '2026-08-27T08:00:00.000Z',
    }), {
      sourceId: 'execution-later-recorded',
      completedAt: '2026-08-28T10:00:00.000Z',
      recordedAt: '2026-08-28T10:00:00.000Z',
    });
    const current = store.entries().find(([path]) =>
      path.startsWith('burner_block_lifecycle_current/'))[1];

    expect(current.sourceId).toBe('execution-first-recorded');
    expect(current.actionPerformedAt).toBe('2026-08-28T08:00:00.000Z');
    expect(current.recordedAt).toBe('2026-08-28T09:00:00.000Z');
    const history = store.entries().filter(([path]) => path.includes('_lifecycle_events/'));
    expect(history).toHaveLength(2);
    expect(history.some(([, event]) => event.sourceId === 'execution-later-recorded' &&
      event.actionPerformedAt === '2026-08-27T08:00:00.000Z')).toBe(true);
  });

  test('physical-time ties use receipt time, then event identity independent of delivery order', async () => {
    const run = async (order, sameReceiptTime) => {
      const store = seedStore();
      for (const n of order) {
        const receiptTime = sameReceiptTime || n === 1 ?
          '2026-08-28T09:00:00.000Z' : '2026-08-28T10:00:00.000Z';
        await prepare(store, action({id: `tie-${n}`, createdAt: '2026-08-28T08:00:00.000Z'}), {
          sourceId: `execution-tie-${n}`, completedAt: receiptTime, recordedAt: receiptTime,
        });
      }
      return store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1];
    };
    expect((await run([1, 2], false)).sourceId).toBe('execution-tie-2');
    expect((await run([2, 1], false)).sourceId).toBe('execution-tie-2');
    expect((await run([1, 2], true)).currentEventId).toBe((await run([2, 1], true)).currentEventId);
  });

  test('a revised-part disposition does not authorize correction of the current installation', async () => {
    const store = seedStore();
    await prepare(store, action({id: 'physical-later', createdAt: '2026-08-28T08:00:00.000Z'}), {
      sourceId: 'execution-physical-later',
    });
    const before = store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1];
    await prepare(store, action({id: 'late-revised-part', replacement: 'revised',
      createdAt: '2026-08-27T08:00:00.000Z'}), {sourceId: 'execution-revised-history',
      completedAt: '2026-08-28T10:00:00.000Z', recordedAt: '2026-08-28T10:00:00.000Z'});
    expect(store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1]).toEqual(before);
    expect(store.entries().filter(([path]) => path.includes('_lifecycle_events/'))).toHaveLength(2);
  });

  test('renamed class remains compatible with an existing physical asset and frozen action reference', async () => {
    const store = seedStore();
    const path = `asset_classes/${IDS.assetClass}`;
    const current = store.entries().find(([key]) => key === path)[1];
    store.seed(path, {...current, name: 'BAF Heating Furnaces'});
    const plan = await prepare(store);
    expect(plan.events).toHaveLength(1);
    expect(plan.events[0].data.assetClassName).toBe('BAF Heating Furnaces');
    expect(store.entries().find(([key]) => key === `asset_instances/${IDS.asset}`)[1].assetClassName)
      .toBe('Furnace');
  });

  test('accepts Firestore timestamps in an existing current projection', async () => {
    const store = seedStore();
    await prepare(store, action({id: 'first-persisted'}), {
      sourceId: 'execution-first-persisted',
    });
    const [path, current] = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_current/'));
    const persisted = workflowFirestoreDataForTest(current);
    expect(typeof persisted.recordedAt.toDate).toBe('function');
    expect(typeof persisted.actionPerformedAt.toDate).toBe('function');
    store.seed(path, persisted);

    await prepare(store, action({
      id: 'second-persisted',
      createdAt: '2026-08-28T09:30:00.000Z',
    }), {
      sourceId: 'execution-second-persisted',
      completedAt: '2026-08-28T10:00:00.000Z',
      recordedAt: '2026-08-28T10:00:00.000Z',
    });

    const after = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_current/'))[1];
    expect(after.sourceId).toBe('execution-second-persisted');
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
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan.events).toEqual([]);
  });

  test('one physical action referenced twice is one installation', async () => {
    const store = seedStore();
    const row = action();

    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-1',
        assetType: 'furnace',
        assetNumber: 7,
        // The closure carries the same physical action at execution scope and
        // again under the module that recorded it.
        actionSources: [
          {
            sourceModuleId: null,
            discipline: 'mechanical',
            actionsJson: JSON.stringify([row]),
          },
          {
            sourceModuleId: 'module-1',
            discipline: 'mechanical',
            actionsJson: JSON.stringify([row]),
          },
        ],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan.events).toHaveLength(1);
    expect(plan.events[0].data).toMatchObject({sourceActionId: 'action-1'});
    expect(plan.currentStates).toHaveLength(1);
  });

  test('one action claimed at two different times is a contradiction', async () => {
    const store = seedStore();

    // The time an action was performed is evidence about it, not part of its
    // name, so a second reference claiming a different time contradicts the
    // first rather than describing another installation.
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-1',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [
          {
            sourceModuleId: null,
            discipline: 'mechanical',
            actionsJson: JSON.stringify([action()]),
          },
          {
            sourceModuleId: 'module-1',
            discipline: 'mechanical',
            actionsJson: JSON.stringify([
              action({createdAt: '2026-08-28T07:15:00.000Z'}),
            ]),
          },
        ],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-action-conflict'},
    });
  });

  test('one action described two ways in one closure is refused', async () => {
    const store = seedStore();

    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-1',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [
          {
            sourceModuleId: null,
            discipline: 'mechanical',
            actionsJson: JSON.stringify([action()]),
          },
          {
            sourceModuleId: 'module-1',
            discipline: 'mechanical',
            actionsJson: JSON.stringify([action({replacement: 'repaired'})]),
          },
        ],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-action-conflict'},
    });
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
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan).toEqual({events: [], currentStates: []});
    expect(store.entries().some(([path]) =>
      path.startsWith('burner_block_lifecycle_events/') ||
      path.startsWith('burner_block_lifecycle_current/'))).toBe(false);
  });

  test('rejects a replacement action that contradicts an explicit no-change response', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-contradictory-block-change',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: JSON.stringify([action()]),
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: false,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-action-conflicts-with-response',
      },
    });
  });

  test('uses the first nonempty supported response-key alias', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-legacy-response-alias',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: JSON.stringify([action()]),
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: '',
            fieldId: 'burnerBlockChanged',
            value: false,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-action-conflicts-with-response',
      },
    });
  });

  test('ignores an optional investigation target without a lifecycle decision', async () => {
    const store = seedStore();
    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-f03-investigation-only',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03',
          discipline: 'instrumentation',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerTarget',
            value: null,
          }, {
            schemaVersion: 1,
            key: 'UVCondition',
            value: 'Serviceable',
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }));

    expect(plan).toEqual({events: [], currentStates: []});
  });

  test('rejects an explicitly invalid burner target', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-invalid-burner-target',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: JSON.stringify([action()]),
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerTarget',
            value: 'Burner 9',
          }, {
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: true,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-response-target-invalid',
      },
    });
  });

  test('reconciles a no-change module response with execution-level actions', async () => {
    const store = seedStore();
    await expect(store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-level-contradictory-block-change',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([action()]),
        }, {
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerTarget',
            value: 'Burner 3',
          }, {
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: false,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
        executionLevelMechanicalEvidence: true,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-action-conflicts-with-response',
      },
    });
  });

  test('allows no-change evidence for a different burner position', async () => {
    const store = seedStore();
    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-distinct-burner-change',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([action()]),
        }, {
          sourceModuleId: 'module-f03m-burner-2',
          discipline: 'mechanical',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerTarget',
            value: 'Burner 2',
          }, {
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: false,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
        executionLevelMechanicalEvidence: true,
      }));

    expect(plan.events).toHaveLength(1);
    expect(plan.events[0].data.burnerPosition).toBe(3);
  });

  test('accepts an execution-level replacement for a changed module target', async () => {
    const store = seedStore();
    const plan = await store.runTransaction((tx) =>
      prepareBurnerBlockLifecycleWritePlan({
        tx,
        sourceType: 'workflowPlannedJob',
        sourceId: 'execution-level-confirmed-block-change',
        assetType: 'furnace',
        assetNumber: 7,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([action()]),
        }, {
          sourceModuleId: 'module-f03m',
          discipline: 'mechanical',
          actionsJson: '[]',
          responsesJson: JSON.stringify([{
            schemaVersion: 1,
            key: 'burnerTarget',
            value: 'Burner 3',
          }, {
            schemaVersion: 1,
            key: 'burnerBlockChanged',
            value: true,
          }]),
        }],
        completedAt: '2026-08-28T09:00:00.000Z',
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
        executionLevelMechanicalEvidence: true,
      }));

    expect(plan.events).toHaveLength(1);
    expect(plan.events[0].data.burnerPosition).toBe(3);
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
        recordedAt: '2026-08-28T09:00:00.000Z',
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
        recordedAt: '2026-08-28T09:00:00.000Z',
        completedBy: actor,
      }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-mechanical-work-required'},
    });
  });
});

describe('correcting a mistaken installation time', () => {
  function currentOf(store) {
    const entry = store.entries().find(([entryPath]) =>
      entryPath.startsWith('burner_block_lifecycle_current/'));
    return entry == null ? null : entry[1];
  }

  function eventsOf(store) {
    return store.entries()
      .filter(([entryPath]) =>
        entryPath.startsWith('burner_block_lifecycle_events/'))
      .map(([, data]) => data);
  }

  function correctionsOf(store) {
    return store.entries()
      .filter(([entryPath]) =>
        entryPath.startsWith('burner_block_lifecycle_corrections/'))
      .map(([, data]) => data);
  }

  async function correct(store, overrides = {}) {
    const events = eventsOf(store);
    const current = currentOf(store);
    return store.runTransaction(async (tx) => {
      const plan = await prepareBurnerBlockInstallationCorrection({
        tx,
        eventId: overrides.eventId ?? events[0].eventId,
        expectedCurrentEventId:
          overrides.expectedCurrentEventId ?? current.currentEventId,
        correctedActionPerformedAt:
          overrides.correctedActionPerformedAt ?? '2026-08-10T08:00:00.000Z',
        reason: 'The register shows the block was fitted on the 10th, not the 12th.',
        correctedBy: actor,
        correctedAt: '2026-08-29T09:00:00.000Z',
        correctionId: 'correction-1',
        supersedesCorrectionId: overrides.supersedesCorrectionId ?? null,
        ...overrides,
      });
      applyBurnerBlockInstallationCorrection(tx, plan);
      return plan;
    });
  }

  test('the corrected time becomes current and the original is kept', async () => {
    const store = seedStore();
    await prepare(store, action({createdAt: '2026-08-12T08:00:00.000Z'}));
    const original = eventsOf(store)[0];

    await correct(store);

    // The original event is exactly as it was recorded. It is what somebody
    // entered, and the correction does not pretend otherwise.
    const kept = eventsOf(store).find((data) =>
      data.eventId === original.eventId);
    expect(kept).toMatchObject({
      actionPerformedAt: '2026-08-12T08:00:00.000Z',
      isDeleted: false,
    });

    // The correction names what it replaces and carries its reason.
    const correction = correctionsOf(store).find((data) =>
      data.correctsEventId === original.eventId);
    expect(correction).toMatchObject({
      correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
      reason:
        'The register shows the block was fitted on the 10th, not the 12th.',
      burnerPosition: original.burnerPosition,
    });

    // What is installed now is rebuilt from the surviving evidence, and a
    // correction that moves the date earlier still wins over what it replaced.
    expect(currentOf(store)).toMatchObject({
      currentEventId: original.eventId,
      actionPerformedAt: '2026-08-10T08:00:00.000Z',
    });
  });

  test('a correction restores an earlier installation as current', async () => {
    const store = seedStore();
    // Two replacements at the same position. The later one was entered with
    // the wrong date and is actually the earlier work.
    await prepare(store, action({id: 'a', createdAt: '2026-08-10T08:00:00.000Z'}));
    await prepare(store, action({id: 'b', createdAt: '2026-08-12T08:00:00.000Z'}), {
      sourceId: 'execution-2',
      completedAt: '2026-08-12T09:00:00.000Z',
      recordedAt: '2026-08-12T09:00:00.000Z',
    });
    const later = eventsOf(store).find((data) =>
      data.actionPerformedAt === '2026-08-12T08:00:00.000Z');
    expect(currentOf(store).currentEventId).toBe(later.eventId);

    await correct(store, {
      eventId: later.eventId,
      correctedActionPerformedAt: '2026-08-08T08:00:00.000Z',
    });

    // With the mistaken date corrected backwards, the block fitted on the 10th
    // is what is installed now. The projection has to be able to go back.
    expect(currentOf(store)).toMatchObject({
      actionPerformedAt: '2026-08-10T08:00:00.000Z',
    });
  });

  test('a correction needs its reason', async () => {
    const store = seedStore();
    await prepare(store);
    const before = store.entries();

    await expect(correct(store, {reason: '   '})).rejects.toThrow();
    expect(store.entries()).toEqual(before);
  });

  test('an event that was already corrected is not corrected again', async () => {
    const store = seedStore();
    await prepare(store, action({createdAt: '2026-08-12T08:00:00.000Z'}));
    const original = eventsOf(store)[0];
    await correct(store);

    await expect(correct(store, {correctionId: 'correction-2'}))
      .rejects.toMatchObject({
        details: {reasonCode: 'burner-block-lifecycle-correction-stale'},
      });
    expect(original.eventId).toBeDefined();
  });

  test('a no-change correction is refused without a second correction record', async () => {
    const store = seedStore();
    await prepare(store, action({createdAt: '2026-08-12T08:00:00.000Z'}));
    await correct(store);
    const before = store.entries();

    await expect(correct(store, {
      correctionId: 'correction-2',
      correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
      supersedesCorrectionId: 'correction-1',
    })).rejects.toMatchObject({
      details: {reasonCode: 'burner-block-lifecycle-correction-no-change'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('a stale current projection is refused without mutation', async () => {
    const store = seedStore();
    await prepare(store);
    const before = store.entries();

    await expect(correct(store, {
      expectedCurrentEventId: 'different-current-event',
    })).rejects.toMatchObject({
      code: 'workflow-version-conflict',
      details: {
        reasonCode: 'burner-block-lifecycle-current-version-conflict',
      },
    });
    expect(store.entries()).toEqual(before);
  });

  test('an unknown event cannot be corrected', async () => {
    const store = seedStore();
    await prepare(store);

    await expect(correct(store, {eventId: 'no-such-event'}))
      .rejects.toMatchObject({
        details: {reasonCode: 'burner-block-lifecycle-event-unknown'},
      });
  });
});

describe('burner-block installation correction command', () => {
  const commandActor = {
    uid: 'admin-1',
    name: 'Admin One',
    roles: new Set(['admin']),
  };

  const eventRows = (store) => store.entries()
    .filter(([entryPath]) => entryPath.startsWith('burner_block_lifecycle_events/'))
    .map(([, data]) => data);
  const currentRow = (store) => store.entries()
    .find(([entryPath]) => entryPath.startsWith('burner_block_lifecycle_current/'))?.[1];

  async function seededCommandState() {
    const store = seedStore();
    await prepare(store, action({createdAt: '2026-08-12T08:00:00.000Z'}));
    store.seed(`users/${commandActor.uid}`, {
      isApproved: true,
      roles: ['admin'],
      name: commandActor.name,
    });
    const event = eventRows(store)[0];
    const current = currentRow(store);
    const command = {
      commandId: 'correction-command-1',
      commandType: 'correctBurnerBlockInstallation',
      aggregateId: 'correction-1',
      expectedVersion: 0,
      payload: {
        eventId: event.eventId,
        expectedCurrentEventId: current.currentEventId,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
        reason: 'The register shows the block was fitted on the 10th, not the 12th.',
        supersedesCorrectionId: null,
      },
    };
    return {store, command, event, current};
  }

  test('writes correction evidence, rebuilds current state and replays without writes', async () => {
    const {store, command, event} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    };

    const receipt = await service.execute(command, context);
    expect(receipt.result).toMatchObject({
      correctionId: 'correction-1',
      correctsEventId: event.eventId,
      currentEventId: event.eventId,
      currentActionPerformedAt: '2026-08-10T08:00:00.000Z',
    });
    expect(store.read('burner_block_lifecycle_corrections/correction-1'))
      .toMatchObject({
        correctsEventId: event.eventId,
        expectedCurrentEventId: event.eventId,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
      });
    expect(store.read('audit_logs/server_burner_block_correction_correction-command-1'))
      .toMatchObject({entityType: 'burnerBlockInstallationCorrection'});

    // A real Firestore round trip changes ISO strings into Timestamp-shaped
    // values. Replay must compare the instant, not the JavaScript object.
    const correctionPath =
      'burner_block_lifecycle_corrections/correction-1';
    store.seed(
      correctionPath,
      workflowFirestoreDataForTest(store.read(correctionPath)),
    );
    const afterFirst = store.entries();
    await expect(service.execute(command, context)).resolves.toEqual(receipt);
    expect(store.entries()).toEqual(afterFirst);
  });

  test('refuses a future physical installation before any write', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const before = store.entries();

    await expect(service.execute({
      ...command,
      commandId: 'future-correction-command',
      aggregateId: 'future-correction',
      payload: {
        ...command.payload,
        correctedActionPerformedAt: '2026-09-01T08:00:00.000Z',
      },
    }, {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'burner-block-correction-future-dated'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('refuses a correction that installed clients cannot decode', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const before = store.entries();

    await expect(service.execute({
      ...command,
      commandId: 'after-closure-correction-command',
      aggregateId: 'after-closure-correction',
      payload: {
        ...command.payload,
        correctedActionPerformedAt: '2026-08-29T08:00:00.000Z',
      },
    }, {
      actor: commandActor,
      serverNow: new Date('2026-09-01T09:00:00.000Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-correction-after-completion',
      },
    });
    expect(store.entries()).toEqual(before);
  });

  test('refuses a command that would make no change without writing evidence', async () => {
    const {store, command, event} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    };
    await service.execute(command, context);
    const before = store.entries();
    const current = currentRow(store);

    await expect(service.execute({
      ...command,
      commandId: 'correction-command-no-change',
      aggregateId: 'correction-2',
      payload: {
        ...command.payload,
        expectedCurrentEventId: current.currentEventId,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
        supersedesCorrectionId: 'correction-1',
      },
    }, context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-block-lifecycle-correction-no-change'},
    });
    expect(event.eventId).toBeDefined();
    expect(store.entries()).toEqual(before);
  });
});
