const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const now = new Date('2026-08-21T08:00:00.000Z');

function seedActor(store, uid, roles) {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
}

function seedFurnaceClass(store) {
  store.seed('asset_classes/class-furnace', {
    schemaVersion: 1,
    assetClassId: 'class-furnace',
    status: 'active',
    legacyAssetTypeKey: 'furnace',
  });
}

function classDefinition(overrides = {}) {
  return {
    schemaVersion: 1,
    code: 'FURNACE_MID',
    title: 'Furnace Mid Maintenance',
    description: 'Routine classified Furnace preventive maintenance.',
    assetTypeKeys: ['furnace'],
    assetClassIds: [],
    principalLaneKey: 'mech',
    resetCounters: [
      {key: 'FURNACE_ANY', label: 'Furnace any maintenance', thresholdDays: 30},
      {key: 'FURNACE_MID', label: 'Furnace Mid maintenance', thresholdDays: null},
    ],
    ...overrides,
  };
}

function upsertClass(expectedVersion = 0, definition = classDefinition(), commandId = 'class-1') {
  return {
    commandId,
    commandType: 'upsertMaintenanceClassDefinition',
    aggregateId: 'maintenance-class-furnace-mid',
    expectedVersion,
    payload: {
      definition,
      reason: 'Govern the Furnace maintenance reset matrix.',
    },
  };
}

function classify(expectedVersion, definitionVersion, commandId = 'classify-1') {
  return {
    commandId,
    commandType: 'classifyMaintenanceExecution',
    aggregateId: 'execution-7',
    expectedVersion,
    payload: {
      definitionId: 'maintenance-class-furnace-mid',
      definitionVersion,
      reason: 'Classify this work against the reviewed maintenance scope.',
    },
  };
}

describe('classified maintenance completion and planning', () => {
  test('completed maintenance creates one immutable event and due projections at actual completion time', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    store.seed('job_executions/execution-7', {
      firestoreId: 'execution-7',
      assetType: 'furnace',
      assetNumber: 7,
      workflowSchemaVersion: 1,
      isCompleted: true,
      completedAt: '2026-08-01T04:00:00.000Z',
      completedByUid: 'supervisor-1',
      completedByName: 'Supervisor 1',
      metadataJson: '{}',
      version: 3,
    });
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});

    const receipt = await service.execute(classify(3, 1), {
      actor: admin,
      serverNow: now,
    });
    expect(receipt).toMatchObject({
      resultKey: 'completed-maintenance-classified',
      aggregateVersion: 4,
      result: {
        maintenanceClassCode: 'FURNACE_MID',
        completionEffectiveAt: '2026-08-01T04:00:00.000Z',
      },
    });
    const events = store.entries().filter(([path]) =>
      path.startsWith('maintenance_completion_events/'));
    expect(events).toHaveLength(1);
    expect(events[0][1]).toMatchObject({
      sourceType: 'workflowPlannedJob',
      sourceId: 'execution-7',
      completedAt: '2026-08-01T04:00:00.000Z',
      completedByUid: 'supervisor-1',
      resetCounterKeys: ['FURNACE_ANY', 'FURNACE_MID'],
    });
    const due = store.entries()
      .filter(([path]) => path.startsWith('maintenance_due_states/'))
      .map(([, data]) => data);
    expect(due).toHaveLength(2);
    expect(due.find((row) => row.counterKey === 'FURNACE_ANY')).toMatchObject({
      lastCompletionAt: '2026-08-01T04:00:00.000Z',
      nextDueAt: '2026-08-31T04:00:00.000Z',
      lastMaintenanceClassCode: 'FURNACE_MID',
    });
  });

  test('classification correction appends evidence and recomputes removed counters', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    store.seed('job_executions/execution-7', {
      firestoreId: 'execution-7',
      assetType: 'furnace',
      assetNumber: 7,
      workflowSchemaVersion: 1,
      isCompleted: true,
      completedAt: '2026-08-01T04:00:00.000Z',
      completedByUid: 'admin-1',
      completedByName: 'admin-1',
      metadataJson: '{}',
      version: 3,
    });
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    await service.execute(classify(3, 1), {actor: admin, serverNow: now});
    await service.execute(upsertClass(
      1,
      classDefinition({
        title: 'Furnace General Maintenance',
        resetCounters: [
          {key: 'FURNACE_ANY', label: 'Furnace any maintenance', thresholdDays: 30},
        ],
      }),
      'class-2',
    ), {actor: admin, serverNow: new Date('2026-08-21T08:10:00.000Z')});

    const receipt = await service.execute(classify(4, 2, 'classify-2'), {
      actor: admin,
      serverNow: new Date('2026-08-21T08:20:00.000Z'),
    });
    expect(receipt.resultKey).toBe('completed-maintenance-classification-corrected');
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_completion_events/'))).toHaveLength(2);
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_classification_audits/'))).toHaveLength(2);
    const midDue = store.entries()
      .filter(([path]) => path.startsWith('maintenance_due_states/'))
      .map(([, data]) => data)
      .find((row) => row.counterKey === 'FURNACE_MID');
    expect(midDue).toMatchObject({
      lastCompletionAt: null,
      classificationPending: true,
    });
  });

  test('supervisor can classify open work but not completed historical work', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    store.seed('job_executions/execution-7', {
      firestoreId: 'execution-7',
      assetType: 'furnace',
      assetNumber: 7,
      workflowSchemaVersion: 1,
      isCompleted: false,
      metadataJson: '{}',
      version: 1,
    });
    await expect(service.execute(classify(1, 1), {
      actor: supervisor,
      serverNow: now,
    })).resolves.toMatchObject({resultKey: 'maintenance-class-assigned'});

    store.seed('job_executions/execution-7', {
      ...store.read('job_executions/execution-7'),
      isCompleted: true,
      completedAt: '2026-08-21T08:30:00.000Z',
      version: 3,
    });
    await expect(service.execute(classify(3, 1, 'classify-complete'), {
      actor: supervisor,
      serverNow: now,
    })).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('a proposed plan does not mutate equipment availability', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['shiftSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    store.seed('equipment_status/furnace_7', {
      assetTypeKey: 'furnace',
      assetNumber: 7,
      state: 'available',
      activeWorkflowCount: 0,
      activeRedCount: 0,
      awaitingPreparationCount: 0,
    });
    const before = store.read('equipment_status/furnace_7');
    const receipt = await service.execute({
      commandId: 'plan-1',
      commandType: 'upsertMaintenancePlan',
      aggregateId: 'plan-furnace-7',
      expectedVersion: 0,
      payload: {
        assetTypeKey: 'furnace',
        assetNumber: 7,
        assetClassId: null,
        assetInstanceId: null,
        maintenanceClassDefinitionId: 'maintenance-class-furnace-mid',
        maintenanceClassDefinitionVersion: 1,
        targetWindowStart: '2026-08-25T02:00:00.000Z',
        targetWindowEnd: '2026-08-25T10:00:00.000Z',
        sourceDueStateId: null,
        templatePackageId: null,
        templateVersionId: null,
        templateContentHash: null,
        planningNotes: 'Target the next available operating window.',
        reason: 'Propose maintenance without changing availability.',
      },
    }, {actor: supervisor, serverNow: now});
    expect(receipt.resultKey).toBe('maintenance-plan-created');
    expect(store.read('equipment_status/furnace_7')).toEqual(before);
    expect(store.read('maintenance_plans/plan-furnace-7')).toMatchObject({
      status: 'proposed',
      maintenanceClassCode: 'FURNACE_MID',
    });
  });
});
