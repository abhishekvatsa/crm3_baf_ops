'use strict';

const {
  applyUvDetectorLifecycleWritePlan,
  prepareUvDetectorLifecycleWritePlan,
} = require('../lib/maintenanceWorkflow/uvDetectorLifecycle');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const IDS = {
  assetClass: 'class-furnace',
  asset: 'furnace-7',
  node: 'node-uv-detector',
};

const actor = {
  uid: 'supervisor-1',
  name: 'Supervisor One',
  roles: new Set(['shiftSupervisor']),
};

function reference() {
  return {
    schemaVersion: 4,
    scope: 'componentDefinitionOnAsset',
    assetClassId: IDS.assetClass,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: IDS.node,
    nodeVersion: 3,
    nodeName: 'UV flame scanner and peep sight',
    assetInstanceId: IDS.asset,
    assetInstanceVersion: 4,
    assetNumber: 7,
    assetInstanceName: 'Furnace 7',
    componentInstanceId: null,
    componentInstanceVersion: null,
    componentTag: null,
    hierarchyPath: [
      'Furnace',
      'Burner and flame supervision',
      'UV flame scanner and peep sight',
    ],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Instrumentation & Automation',
    accountableRoleKeys: ['seniorInstrumentation'],
    innerCoverAssociation: null,
  };
}

function action(overrides = {}) {
  return {
    schemaVersion: 1,
    id: 'action-uv-1',
    asset: 'Furnace 7',
    component: 'UV flame scanner and peep sight',
    hierarchyPath: reference().hierarchyPath,
    assetHierarchyRef: reference(),
    system: 'Furnace',
    subsystem: 'Burner and flame supervision',
    subComponent: null,
    tag: null,
    instance: null,
    actionType: 'replacement',
    replacement: 'newPart',
    issue: 'UV detector was missing.',
    resolution: 'UV detector installed.',
    remarks: null,
    templateFieldKey: null,
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-08-28T08:00:00.000Z',
    severity: 'high',
    performedBy: 'I&A Technician One',
    updatedAt: null,
    version: 1,
    metadataJson: null,
    attendanceSessionId: null,
    burnerPosition: 3,
    burnerActionCode: null,
    burnerOutcome: null,
    burnerMicroampReading: null,
    burnerBlockSupplyMode: null,
    burnerBlockSupplierName: null,
    burnerBlockPurchaseOrderNumber: null,
    ...overrides,
  };
}

function lockoutAction(overrides = {}) {
  return action({
    id: 'burner_ticket-1_3_uvDetectorReplacement',
    component: 'Burner 3',
    hierarchyPath: null,
    assetHierarchyRef: null,
    system: 'Combustion system',
    subsystem: 'Burner system',
    subComponent: 'UV detector replacement',
    tag: 'FR-07-B03',
    instance: '3',
    attendanceSessionId: 'burner_ticket-1_3',
    burnerActionCode: 'uvDetectorReplacement',
    burnerOutcome: 'returnedToService',
    ...overrides,
  });
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
    name: 'UV flame scanner and peep sight',
    hierarchyPath: reference().hierarchyPath,
    nodeType: 'component',
    componentTag: null,
    status: 'active',
    version: 3,
  });
  return store;
}

async function prepare(store, row = action(), overrides = {}) {
  return store.runTransaction(async (tx) => {
    const plan = await prepareUvDetectorLifecycleWritePlan({
      tx,
      sourceType: 'workflowPlannedJob',
      sourceId: 'execution-1',
      assetType: 'furnace',
      assetNumber: 7,
      actionSources: [{
        sourceModuleId: 'module-1',
        discipline: 'instrumentation',
        actionsJson: JSON.stringify([row]),
      }],
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T09:00:00.000Z',
      completedBy: actor,
      ...overrides,
    });
    applyUvDetectorLifecycleWritePlan(tx, plan);
    return plan;
  });
}

describe('UV-detector lifecycle projection', () => {
  test.each(['maintenanceIssue', 'legacyPlannedJob', 'workflowPlannedJob'])(
    '%s accepts legacy Indian action time and preserves the actual installation instant', async (sourceType) => {
      const store = seedStore();
      const row = action({createdAt: '2026-08-28T13:30:00.000'});
      await prepare(store, row, {sourceType});
      const [, event] = store.entries().find(([entryPath]) =>
        entryPath.startsWith('uv_detector_lifecycle_events/'));
      expect(event).toMatchObject({
        actionPerformedAt: '2026-08-28T08:00:00.000Z',
        completedAt: '2026-08-28T09:00:00.000Z',
        sourceType,
      });
      expect(row.createdAt).toBe('2026-08-28T13:30:00.000');
    },
  );

  test('legacy Indian time still cannot move installation after closure', async () => {
    const store = seedStore();
    await expect(prepare(store, action({createdAt: '2026-08-28T14:36:00.000'})))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.entries().filter(([entryPath]) =>
      entryPath.startsWith('uv_detector_lifecycle_events/'))).toHaveLength(0);
  });

  test('rejects a receipt time that differs from authoritative closure', async () => {
    const store = seedStore();

    await expect(prepare(store, action(), {
      recordedAt: '2026-08-28T09:01:00.000Z',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'uv-detector-lifecycle-closure-time-mismatch',
      },
    });
  });

  test('projects a governed numbered UV replacement to In service', async () => {
    const store = seedStore();
    const plan = await prepare(store);
    const [, event] = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_events/'));
    const [currentPath, current] = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'));

    expect(plan.events).toHaveLength(1);
    expect(currentPath).toMatch(
      /^uv_detector_lifecycle_current\/uvlc_[a-f0-9]{40}$/,
    );
    expect(event).toMatchObject({
      assetInstanceId: IDS.asset,
      burnerPosition: 3,
      resultingCondition: 'serviceable',
      replacementDisposition: 'newPart',
      installationDiscipline: 'instrumentation',
      sourceType: 'workflowPlannedJob',
      sourceModuleId: 'module-1',
    });
    expect(current).toMatchObject({
      projectionSchemaVersion: 1,
      currentEventId: event.eventId,
      resultingCondition: 'serviceable',
    });
  });

  test('projects burner-lockout UV replacement using the ticket asset identity', async () => {
    const store = seedStore();
    const sourceReference = JSON.stringify({
      ...reference(),
      schemaVersion: 3,
      scope: 'physicalAsset',
      nodeId: IDS.asset,
      nodeVersion: 4,
      nodeName: 'Furnace 7',
      hierarchyPath: ['Furnace', 'Furnace 7'],
    });
    const plan = await prepare(store, lockoutAction(), {
      sourceType: 'maintenanceIssue',
      sourceId: 'ticket-1',
      sourceAssetReferenceJson: sourceReference,
      actionSources: [{
        sourceModuleId: null,
        actionsJson: JSON.stringify([lockoutAction()]),
      }],
      executionLevelInstrumentationEvidence: true,
    });
    const event = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_events/'))[1];

    expect(plan.events).toHaveLength(1);
    expect(event).toMatchObject({
      burnerPosition: 3,
      hierarchyNodeId: null,
      hierarchyNodeName: 'UV detector at Burner 3',
      sourceType: 'maintenanceIssue',
      sourceId: 'ticket-1',
      resultingCondition: 'serviceable',
    });
  });

  test.each(['remainsLockedOut', 'isolatedForFollowUp'])(
    'does not mark a burner-lockout UV replacement serviceable when outcome is %s',
    async (burnerOutcome) => {
      const store = seedStore();
      const sourceReference = JSON.stringify({
        ...reference(),
        schemaVersion: 3,
        scope: 'physicalAsset',
        nodeId: IDS.asset,
        nodeVersion: 4,
        nodeName: 'Furnace 7',
        hierarchyPath: ['Furnace', 'Furnace 7'],
      });
      const row = lockoutAction({burnerOutcome});

      const plan = await prepare(store, row, {
        sourceType: 'maintenanceIssue',
        sourceId: `ticket-${burnerOutcome}`,
        sourceAssetReferenceJson: sourceReference,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([row]),
        }],
        executionLevelInstrumentationEvidence: true,
      });

      expect(plan.events).toHaveLength(0);
      expect(plan.currentStates).toHaveLength(0);
      expect(store.entries().some(([path]) =>
        path.startsWith('uv_detector_lifecycle_'))).toBe(false);
    },
  );

  test('rejects generic UV installation outside I&A work', async () => {
    const store = seedStore();
    await expect(prepare(store, action(), {
      actionSources: [{
        sourceModuleId: 'module-1',
        discipline: 'mechanical',
        actionsJson: JSON.stringify([action()]),
      }],
    })).rejects.toMatchObject({
      details: {
        reasonCode: 'uv-detector-lifecycle-instrumentation-work-required',
      },
    });
  });

  test('retains the newest physical installation as current', async () => {
    const store = seedStore();
    await prepare(store, action({
      id: 'newer',
      createdAt: '2026-08-28T08:00:00.000Z',
    }), {sourceId: 'execution-newer'});
    const before = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    await prepare(store, action({
      id: 'older',
      createdAt: '2026-08-28T07:00:00.000Z',
    }), {sourceId: 'execution-older'});
    const after = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    expect(after.currentEventId).toBe(before.currentEventId);
  });

  test('a later server receipt wins even when its device action time is older', async () => {
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
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    expect(current.sourceId).toBe('execution-later-recorded');
    expect(current.actionPerformedAt).toBe('2026-08-27T08:00:00.000Z');
    expect(current.recordedAt).toBe('2026-08-28T10:00:00.000Z');
  });
});
