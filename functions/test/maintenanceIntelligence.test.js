const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const now = new Date('2026-08-21T08:00:00.000Z');

function persistedTimestamp(value) {
  const millis = Date.parse(value);
  return {
    _seconds: Math.floor(millis / 1000),
    _nanoseconds: (millis % 1000) * 1000000,
  };
}

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
  store.seed('asset_instances/furnace-7', {
    schemaVersion: 1,
    assetInstanceId: 'furnace-7',
    assetClassId: 'class-furnace',
    assetNumber: 7,
    name: 'Furnace 07',
    version: 3,
    status: 'active',
    isDeleted: false,
  });
}

function seedInnerCoverClassAndProfile(store, overrides = {}) {
  store.seed('asset_classes/class-inner-cover', {
    schemaVersion: 1,
    assetClassId: 'class-inner-cover',
    status: 'active',
    legacyAssetTypeKey: 'innerCover',
  });
  store.seed('inner_cover_profiles/inner-cover-gr26', {
    schemaVersion: 1,
    innerCoverId: 'inner-cover-gr26',
    assetClassId: 'class-inner-cover',
    serialNumber: 'GR26',
    normalizedSerialNumber: 'GR26',
    lifecycleState: 'available',
    version: 4,
    ...overrides,
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

function innerCoverClassCommand() {
  return {
    commandId: 'inner-cover-class-1',
    commandType: 'upsertMaintenanceClassDefinition',
    aggregateId: 'maintenance-class-inner-cover-cleaning',
    expectedVersion: 0,
    payload: {
      definition: classDefinition({
        code: 'INNER_COVER_CLEANING',
        title: 'Inner Cover Cleaning',
        description: 'Serial-based cleaning cadence across Base transfers.',
        assetTypeKeys: ['innerCover'],
        resetCounters: [
          {key: 'INNER_COVER_CLEANING', label: 'Inner Cover cleaning', thresholdDays: 30},
        ],
      }),
      reason: 'Govern serial-based Inner Cover cleaning.',
    },
  };
}

function innerCoverPlanCommand() {
  return {
    commandId: 'inner-cover-plan-1',
    commandType: 'upsertMaintenancePlan',
    aggregateId: 'plan-inner-cover-gr26',
    expectedVersion: 0,
    payload: {
      assetTypeKey: 'innerCover',
      assetNumber: null,
      assetClassId: 'class-inner-cover',
      assetInstanceId: 'inner-cover-gr26',
      assetInstanceVersion: 4,
      maintenanceClassDefinitionId: 'maintenance-class-inner-cover-cleaning',
      maintenanceClassDefinitionVersion: 1,
      targetWindowStart: '2026-08-21T02:00:00.000Z',
      targetWindowEnd: '2026-08-21T10:00:00.000Z',
      sourceDueStateId: null,
      templatePackageId: null,
      templateVersionId: null,
      templateContentHash: null,
      planningNotes: 'Clean the pool cover and retain its serial identity.',
      reason: 'Plan serial-based Inner Cover cleaning.',
    },
  };
}

function planStatus(version, status, commandId) {
  return {
    commandId,
    commandType: 'setMaintenancePlanStatus',
    aggregateId: 'plan-inner-cover-gr26',
    expectedVersion: version,
    payload: {
      status,
      reason: `Move serial Inner Cover plan to ${status}.`,
      executionId: null,
    },
  };
}

function resolvedFurnaceTicket(overrides = {}) {
  return {
    firestoreId: 'ticket-furnace-7',
    version: 2,
    assetType: 'furnace',
    assetNumber: 7,
    assetHierarchyRefJson: JSON.stringify({
      schemaVersion: 3,
      scope: 'physicalAsset',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-7',
      assetInstanceVersion: 3,
      assetInstanceName: 'Furnace 07',
      assetNumber: 7,
    }),
    status: 'resolved',
    isResolved: true,
    isDeleted: false,
    endDate: '2026-08-21T01:00:00.000Z',
    closedByUid: 'supervisor-1',
    closedByName: 'Supervisor 1',
    metadataJson: '{}',
    ...overrides,
  };
}

function historicalMaintenanceCommand({
  recordId = 'history-furnace-7-20260810',
  commandId = 'record-history-1',
  completedAt = '2026-08-10T06:30:00.000Z',
} = {}) {
  return {
    commandId,
    commandType: 'recordHistoricalMaintenance',
    aggregateId: recordId,
    expectedVersion: 0,
    payload: {
      assetTypeKey: 'furnace',
      assetNumber: 7,
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-7',
      assetInstanceVersion: 3,
      definitionId: 'maintenance-class-furnace-mid',
      definitionVersion: 1,
      completedAt,
      performedByName: 'Mechanical maintenance team',
      evidenceNote: 'Copied from the signed Furnace maintenance register.',
      sourceReference: 'Furnace register page 114',
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
      classificationPending: false,
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

    const execution = store.read('job_executions/execution-7');
    store.seed('job_executions/execution-7', {
      ...execution,
      completedAt: persistedTimestamp(execution.completedAt),
    });
    for (const [path, source] of store.entries().filter(([path]) =>
      path.startsWith('maintenance_completion_sources/'))) {
      store.seed(path, {
        ...source,
        completedAt: persistedTimestamp(source.completedAt),
      });
    }
    for (const [path, due] of store.entries().filter(([path]) =>
      path.startsWith('maintenance_due_states/'))) {
      store.seed(path, {
        ...due,
        lastCompletionAt: persistedTimestamp(due.lastCompletionAt),
      });
    }

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
      schemaVersion: 1,
      assetIdentityKey: 'furnace:7',
      assetTypeKey: 'furnace',
      assetNumber: 7,
      counterKey: 'FURNACE_MID',
      counterLabel: 'Furnace Mid maintenance',
      thresholdDays: null,
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

  test.each([
    [
      'cancelled',
      {
        isCancelled: true,
        cancelledAt: '2026-08-21T07:30:00.000Z',
      },
      'maintenance-execution-cancelled',
    ],
    [
      'deleted',
      {
        isDeleted: true,
        deletedAt: '2026-08-21T07:30:00.000Z',
      },
      'maintenance-execution-deleted',
    ],
  ])('%s maintenance cannot be classified or reset due counters', async (
    _label,
    terminalState,
    reasonCode,
  ) => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    store.seed('job_executions/execution-7', {
      firestoreId: 'execution-7',
      assetType: 'furnace',
      assetNumber: 7,
      workflowSchemaVersion: 1,
      isCompleted: false,
      isCancelled: false,
      isDeleted: false,
      metadataJson: '{}',
      version: 2,
      ...terminalState,
    });
    const before = store.read('job_executions/execution-7');

    await expect(service.execute(classify(2, 1), {
      actor: admin,
      serverNow: now,
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode},
    });

    expect(store.read('job_executions/execution-7')).toEqual(before);
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_completion_events/'))).toHaveLength(0);
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_classification_audits/'))).toHaveLength(0);
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
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-7',
        assetInstanceVersion: 3,
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
      schemaVersion: 2,
      status: 'proposed',
      assetIdentityKey: 'class-furnace:furnace-7',
      assetInstanceName: 'Furnace 07',
      maintenanceClassCode: 'FURNACE_MID',
    });
  });

  test('generic plan status cannot bypass governed template assignment', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['shiftSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    await service.execute({
      commandId: 'plan-release-guard-create',
      commandType: 'upsertMaintenancePlan',
      aggregateId: 'plan-furnace-7',
      expectedVersion: 0,
      payload: {
        assetTypeKey: 'furnace',
        assetNumber: 7,
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-7',
        assetInstanceVersion: 3,
        maintenanceClassDefinitionId: 'maintenance-class-furnace-mid',
        maintenanceClassDefinitionVersion: 1,
        targetWindowStart: '2026-08-25T02:00:00.000Z',
        targetWindowEnd: '2026-08-25T10:00:00.000Z',
        sourceDueStateId: null,
        templatePackageId: 'package-furnace-mid',
        templateVersionId: 'version-furnace-mid-1',
        templateContentHash: 'tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        planningNotes: 'Release only through the governed assignment transaction.',
        reason: 'Prepare an exact governed release-path regression.',
      },
    }, {actor: supervisor, serverNow: now});
    for (const [version, status] of [[1, 'scheduled'], [2, 'ready']]) {
      await service.execute({
        commandId: `plan-release-guard-${status}`,
        commandType: 'setMaintenancePlanStatus',
        aggregateId: 'plan-furnace-7',
        expectedVersion: version,
        payload: {
          status,
          reason: `Move the governed plan to ${status}.`,
          executionId: null,
        },
      }, {actor: supervisor, serverNow: now});
    }

    await expect(service.execute({
      commandId: 'plan-release-bypass-attempt',
      commandType: 'setMaintenancePlanStatus',
      aggregateId: 'plan-furnace-7',
      expectedVersion: 3,
      payload: {
        status: 'released',
        reason: 'Attempt the deprecated generic release route.',
        executionId: 'unbound-execution-7',
      },
    }, {actor: supervisor, serverNow: now})).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    expect(store.read('maintenance_plans/plan-furnace-7')).toMatchObject({
      status: 'ready',
      version: 3,
      releasedExecutionId: null,
    });
    expect(store.read('maintenance_plan_audits/plan-release-bypass-attempt'))
      .toBeNull();
  });

  test('pool Inner Cover cleaning follows serial identity into immutable due evidence', async () => {
    const store = new MemoryWorkflowStore();
    seedInnerCoverClassAndProfile(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(innerCoverClassCommand(), {actor: admin, serverNow: now});
    await expect(service.execute(innerCoverPlanCommand(), {
      actor: supervisor,
      serverNow: now,
    })).resolves.toMatchObject({resultKey: 'maintenance-plan-created'});
    expect(store.read('maintenance_plans/plan-inner-cover-gr26')).toMatchObject({
      assetIdentityKey: 'class-inner-cover:inner-cover-gr26',
      assetNumber: null,
      assetInstanceName: 'Inner Cover GR26',
      status: 'proposed',
    });
    await service.execute(planStatus(1, 'scheduled', 'inner-cover-plan-scheduled'), {
      actor: supervisor,
      serverNow: now,
    });
    await service.execute(planStatus(2, 'ready', 'inner-cover-plan-ready'), {
      actor: supervisor,
      serverNow: now,
    });
    const receipt = await service.execute({
      commandId: 'inner-cover-plan-complete',
      commandType: 'completeMaintenancePlan',
      aggregateId: 'plan-inner-cover-gr26',
      expectedVersion: 3,
      payload: {
        completedAt: '2026-08-21T07:45:00.000Z',
        completionEvidence: 'Cleaned, visually inspected and returned to the available pool.',
        reason: 'Record governed Inner Cover cleaning completion.',
      },
    }, {actor: supervisor, serverNow: now});
    expect(receipt).toMatchObject({
      resultKey: 'maintenance-plan-completed',
      aggregateVersion: 4,
    });
    expect(store.read('maintenance_plans/plan-inner-cover-gr26')).toMatchObject({
      status: 'completed',
      completedAt: '2026-08-21T07:45:00.000Z',
      completedByUid: 'supervisor-1',
    });
    const event = store.entries().find(([path]) =>
      path.startsWith('maintenance_completion_events/'))?.[1];
    expect(event).toMatchObject({
      sourceType: 'maintenancePlanDirect',
      sourceId: 'plan-inner-cover-gr26',
      assetIdentityKey: 'class-inner-cover:inner-cover-gr26',
      assetNumber: null,
      maintenanceClassCode: 'INNER_COVER_CLEANING',
    });
    const due = store.entries().find(([path]) =>
      path.startsWith('maintenance_due_states/'))?.[1];
    expect(due).toMatchObject({
      assetIdentityKey: 'class-inner-cover:inner-cover-gr26',
      assetNumber: null,
      counterKey: 'INNER_COVER_CLEANING',
      nextDueAt: '2026-09-20T07:45:00.000Z',
    });
  });

  test('direct completion fails closed when the Inner Cover changed after planning', async () => {
    const store = new MemoryWorkflowStore();
    seedInnerCoverClassAndProfile(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['shiftSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(innerCoverClassCommand(), {actor: admin, serverNow: now});
    await service.execute(innerCoverPlanCommand(), {actor: supervisor, serverNow: now});
    await service.execute(planStatus(1, 'scheduled', 'inner-cover-plan-scheduled'), {
      actor: supervisor,
      serverNow: now,
    });
    await service.execute(planStatus(2, 'ready', 'inner-cover-plan-ready'), {
      actor: supervisor,
      serverNow: now,
    });
    store.seed('inner_cover_profiles/inner-cover-gr26', {
      ...store.read('inner_cover_profiles/inner-cover-gr26'),
      lifecycleState: 'retiredForSalvage',
      version: 5,
    });
    await expect(service.execute({
      commandId: 'inner-cover-plan-complete',
      commandType: 'completeMaintenancePlan',
      aggregateId: 'plan-inner-cover-gr26',
      expectedVersion: 3,
      payload: {
        completedAt: '2026-08-21T07:45:00.000Z',
        completionEvidence: 'Attempted completion after the profile changed.',
        reason: 'This completion must fail closed.',
      },
    }, {actor: supervisor, serverNow: now})).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-plan-inner-cover-identity-changed'},
    });
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_completion_events/'))).toHaveLength(0);
  });

  test('Admin classification puts a final resolved issue into the common completion ledger', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    store.seed('maintenance_records/ticket-furnace-7', resolvedFurnaceTicket({
      endDate: persistedTimestamp('2026-08-21T01:00:00.000Z'),
    }));

    const receipt = await service.execute({
      commandId: 'classify-ticket-1',
      commandType: 'classifyMaintenanceTicket',
      aggregateId: 'ticket-furnace-7',
      expectedVersion: 2,
      payload: {
        definitionId: 'maintenance-class-furnace-mid',
        definitionVersion: 1,
        reason: 'Classify final issue work as Furnace Mid maintenance.',
      },
    }, {actor: admin, serverNow: now});

    expect(receipt).toMatchObject({
      resultKey: 'completed-maintenance-issue-classified',
      aggregateVersion: 3,
      result: {completionEffectiveAt: '2026-08-21T01:00:00.000Z'},
    });
    expect(store.read('maintenance_records/ticket-furnace-7')).toMatchObject({
      version: 3,
      maintenanceClassificationPending: false,
    });
    const event = store.entries().find(([path]) =>
      path.startsWith('maintenance_completion_events/'))?.[1];
    expect(event).toMatchObject({
      sourceType: 'maintenanceIssue',
      sourceId: 'ticket-furnace-7',
      assetIdentityKey: 'class-furnace:furnace-7',
      completedAt: '2026-08-21T01:00:00.000Z',
      completedByUid: 'supervisor-1',
    });
    const due = store.entries()
      .filter(([path]) => path.startsWith('maintenance_due_states/'))
      .map(([, data]) => data)
      .find((row) => row.counterKey === 'FURNACE_ANY');
    expect(due).toMatchObject({
      lastCompletionSourceType: 'maintenanceIssue',
      nextDueAt: '2026-09-20T01:00:00.000Z',
    });
  });

  test('resolved issue classification waits for the reopen window and rejects Inner Cover position identity', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});
    const command = {
      commandId: 'classify-ticket-1',
      commandType: 'classifyMaintenanceTicket',
      aggregateId: 'ticket-furnace-7',
      expectedVersion: 2,
      payload: {
        definitionId: 'maintenance-class-furnace-mid',
        definitionVersion: 1,
        reason: 'Attempt classification before the record is final.',
      },
    };
    store.seed('maintenance_records/ticket-furnace-7', resolvedFurnaceTicket({
      endDate: '2026-08-21T06:00:00.000Z',
    }));
    await expect(service.execute(command, {actor: admin, serverNow: now}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'maintenance-ticket-reopen-window-active'},
      });

    store.seed('maintenance_records/ticket-furnace-7', resolvedFurnaceTicket({
      assetType: 'innerCover',
      endDate: '2026-08-21T01:00:00.000Z',
    }));
    await expect(service.execute(command, {actor: admin, serverNow: now}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'maintenance-ticket-inner-cover-serial-required'},
      });
  });

  test('Admin can add immutable previous maintenance against exact asset and class', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});

    const receipt = await service.execute(historicalMaintenanceCommand(), {
      actor: admin,
      serverNow: now,
    });

    expect(receipt).toMatchObject({
      resultKey: 'historical-maintenance-recorded',
      aggregateVersion: 1,
      result: {maintenanceClassCode: 'FURNACE_MID'},
    });
    expect(store.read(
      'historical_maintenance_records/history-furnace-7-20260810',
    )).toMatchObject({
      schemaVersion: 1,
      assetDisplayName: 'Furnace 07',
      maintenanceClassTitle: 'Furnace Mid Maintenance',
      completedAt: '2026-08-10T06:30:00.000Z',
      datePrecision: 'date',
      recordedByUid: 'admin-1',
    });
    const event = store.entries().find(([path]) =>
      path.startsWith('maintenance_completion_events/'))?.[1];
    expect(event).toMatchObject({
      sourceType: 'historicalMaintenance',
      sourceId: 'history-furnace-7-20260810',
      completedByUid: null,
      completedByName: 'Mechanical maintenance team',
    });
  });

  test('previous records are Admin-only and an older addition cannot rewind due state', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceClass(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertClass(), {actor: admin, serverNow: now});

    await expect(service.execute(historicalMaintenanceCommand(), {
      actor: supervisor,
      serverNow: now,
    })).rejects.toMatchObject({code: 'permission-denied'});

    await service.execute(historicalMaintenanceCommand(), {
      actor: admin,
      serverNow: now,
    });
    await service.execute(historicalMaintenanceCommand({
      recordId: 'history-furnace-7-20260701',
      commandId: 'record-history-older',
      completedAt: '2026-07-01T06:30:00.000Z',
    }), {actor: admin, serverNow: now});

    const due = store.entries()
      .filter(([path]) => path.startsWith('maintenance_due_states/'))
      .map(([, data]) => data)
      .find((row) => row.counterKey === 'FURNACE_ANY');
    expect(due).toMatchObject({
      lastCompletionAt: '2026-08-10T06:30:00.000Z',
      lastCompletionSourceId: 'history-furnace-7-20260810',
    });
  });
});
