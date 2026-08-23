const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  payloadFingerprint,
} = require('../lib/maintenanceWorkflow/utils');

const at = new Date('2026-08-14T16:30:00.000Z');
const actor = (uid, roles) => ({uid, name: uid, roles: new Set(roles)});
const admin = actor('admin-1', ['admin']);
const electrical = actor('electrical-1', ['seniorElectrical']);
const mechanical = actor('mechanical-1', ['seniorMechanical']);
const contractSupervisor = actor('contract-1', ['contractSupervisor']);
const operations = actor('operations-1', ['operations']);

function serviceFor(currentActor, ticket = {}) {
  const store = new MemoryWorkflowStore();
  for (const current of [
    admin, electrical, mechanical, contractSupervisor, operations,
  ]) {
    store.seed(`users/${current.uid}`, {
      isApproved: true,
      roles: [...current.roles],
      name: current.name,
    });
  }
  store.seed('maintenance_records/ticket-1', {
    firestoreId: 'ticket-1',
    version: 3,
    assetType: 'furnace',
    assetNumber: 7,
    maintenanceType: 'breakdown',
    description: 'Burner pressure is unstable',
    routedTo: 'electrical',
    status: 'open',
    isResolved: false,
    isCritical: true,
    workflowDeferred: false,
    isDeleted: false,
    ...ticket,
  });
  return {
    store,
    service: new MaintenanceWorkflowCommandService(store),
    context: {actor: currentActor, serverNow: at},
  };
}

const acknowledgeCommand = (commandId = 'ack-ticket-1') => ({
  commandId,
  commandType: 'acknowledgeMaintenanceTicket',
  aggregateId: 'ticket-1',
  expectedVersion: 3,
  payload: {},
});

function createServiceFor(currentActor = admin) {
  const store = new MemoryWorkflowStore();
  for (const current of [
    admin, electrical, mechanical, contractSupervisor, operations,
  ]) {
    store.seed(`users/${current.uid}`, {
      isApproved: true,
      roles: [...current.roles],
      name: current.name,
    });
  }
  store.seed('asset_classes/class-furnace', {
    schemaVersion: 1,
    assetClassId: 'class-furnace',
    status: 'active',
    legacyAssetTypeKey: 'furnace',
    code: 'FR',
    name: 'Furnace',
  });
  store.seed('asset_instances/asset-furnace-7', {
    schemaVersion: 1,
    assetInstanceId: 'asset-furnace-7',
    assetClassId: 'class-furnace',
    assetClassCode: 'FR',
    assetClassName: 'Furnace',
    assetNumber: 7,
    name: 'Furnace 7',
    status: 'active',
    version: 4,
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Operations',
    accountableRoleKeys: ['operations'],
  });
  return {
    store,
    service: new MaintenanceWorkflowCommandService(store),
    context: {actor: currentActor, serverNow: at},
  };
}

function physicalAssetReference(assetVersion = 4) {
  return JSON.stringify({
    schemaVersion: 3,
    scope: 'physicalAsset',
    assetClassId: 'class-furnace',
    assetInstanceId: 'asset-furnace-7',
    assetInstanceVersion: assetVersion,
  });
}

function createCommand({
  commandId = 'create-ticket-2',
  ticketId = 'ticket-2',
  ticket = {},
} = {}) {
  return {
    commandId,
    commandType: 'createMaintenanceTicket',
    aggregateId: ticketId,
    expectedVersion: 0,
    payload: {
      ticket: {
        schemaVersion: 1,
        version: 1,
        assetType: 'furnace',
        assetNumber: 7,
        component: 'Furnace body',
        subsystem: null,
        tag: null,
        hierarchyPath: ['Untrusted', 'Client path'],
        assetHierarchyRefJson: physicalAssetReference(),
        maintenanceType: 'breakdown',
        classification: null,
        description: 'Furnace shell temperature is above the expected range.',
        routedTo: 'mechanical',
        otherDepartment: null,
        isCritical: false,
        startDate: '2026-08-14T16:20:00.000Z',
        chargeNoAtEvent: null,
        qualityIntentSchemaVersion: 1,
        qualityImpactAssessment: 'notSuspected',
        qualityWarningReason: null,
        ...ticket,
      },
    },
  };
}

describe('governed maintenance-ticket supervision', () => {
  test('creates an asset-bound issue atomically with server actor and time', async () => {
    const {store, service, context} = createServiceFor(mechanical);
    const command = createCommand();

    const applied = await service.execute(command, context);
    const replay = await service.execute(command, context);

    expect(replay).toEqual(applied);
    expect(applied).toMatchObject({
      resultKey: 'maintenance-ticket-created',
      aggregateVersion: 1,
      result: {
        ticketId: 'ticket-2',
        auditId: 'server_maintenance_ticket_create-ticket-2',
        warningId: null,
        directiveId: null,
      },
    });
    const created = store.read('maintenance_records/ticket-2');
    expect(created).toMatchObject({
      firestoreId: 'ticket-2',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 1,
      issueAssignedLanes: ['mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
      version: 1,
      loggedByUid: mechanical.uid,
      loggedByName: mechanical.name,
      status: 'open',
      isResolved: false,
      startDate: '2026-08-14T16:20:00.000Z',
      createdAt: at.toISOString(),
      updatedAt: at.toISOString(),
      hierarchyPath: ['Furnace', 'Furnace 7'],
    });
    expect(JSON.parse(created.assetHierarchyRefJson)).toMatchObject({
      schemaVersion: 3,
      scope: 'physicalAsset',
      assetClassId: 'class-furnace',
      assetInstanceId: 'asset-furnace-7',
      assetInstanceVersion: 4,
      hierarchyPath: ['Furnace', 'Furnace 7'],
    });
    expect(store.read('audit_logs/server_maintenance_ticket_create-ticket-2'))
      .toMatchObject({
        action: 'create',
        operation: 'createMaintenanceTicket',
        performedByUid: mechanical.uid,
        resultVersion: 1,
      });
    const audit = store.read(
      'audit_logs/server_maintenance_ticket_create-ticket-2',
    );
    expect(JSON.parse(audit.afterJson)).toMatchObject({
      firestoreId: 'ticket-2',
      assetHierarchyRefJson: created.assetHierarchyRefJson,
      hierarchyPath: ['Furnace', 'Furnace 7'],
      qualityImpactAssessment: 'notSuspected',
      createdAt: at.toISOString(),
    });
  });

  test('creates a multi-lane issue with the selected primary route', async () => {
    const {store, service, context} = createServiceFor(mechanical);
    const receipt = await service.execute(createCommand({
      commandId: 'create-multi-lane-ticket',
      ticketId: 'multi-lane-ticket',
      ticket: {
        routedTo: 'mechanical',
        issueLaneSchemaVersion: 1,
        issueLaneRevision: 1,
        issueAssignedLanes: ['mechanical', 'electrical', 'instrumentation'],
        issueAcknowledgedLanes: [],
        issueCompletedLanes: [],
      },
    }), context);

    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-created',
      aggregateVersion: 1,
    });
    expect(store.read('maintenance_records/multi-lane-ticket')).toMatchObject({
      routedTo: 'mechanical',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 1,
      issueAssignedLanes: ['mechanical', 'electrical', 'instrumentation'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
      status: 'open',
    });
  });

  test('creates a quality warning with the issue in the same command', async () => {
    const {store, service, context} = createServiceFor(electrical);
    const command = createCommand({
      commandId: 'create-quality-ticket',
      ticketId: 'quality-ticket',
      ticket: {
        isCritical: true,
        chargeNoAtEvent: 12345,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'Temperature deviation may have affected the coil.',
      },
    });

    const receipt = await service.execute(command, context);

    expect(receipt.result.warningId).toBe('issue_quality-ticket');
    expect(store.read('quality_warnings/issue_quality-ticket')).toMatchObject({
      warningId: 'issue_quality-ticket',
      sourceType: 'issue',
      sourceId: 'quality-ticket',
      sourceVersion: 1,
      sourceChargeNo: 12345,
      sourceSeverity: 'critical',
      status: 'open',
      createdByUid: electrical.uid,
      createdAt: at.toISOString(),
    });
  });

  test('creates a red-hot burner directive with the specialized issue', async () => {
    const {store, service, context} = createServiceFor(electrical);
    const command = createCommand({
      commandId: 'create-red-hot-ticket',
      ticketId: 'red-hot-ticket',
      ticket: {
        component: 'Burner system',
        maintenanceType: 'breakdown',
        classification: 'furnaceBurnerLockout',
        routedTo: 'instrumentation',
        isCritical: true,
        burnerLockoutSchemaVersion: 1,
        burnerPositions: [2, 5],
        burnerCommonMode: true,
        burnerCycleStage: 'firing',
        burnerHmiAlarm: 'Flame failure',
        burnerFlameObservation: 'notSeen',
        burnerSparkObservation: 'seen',
        burnerRelightAttempts: 1,
        burnerRemainsLockedOut: true,
        burnerRedHotPositions: [5],
        burnerAttendedPositions: [],
        burnerResolutionEvidence: {},
      },
    });

    const receipt = await service.execute(command, context);

    expect(receipt.result.directiveId).toBe('burner_red_hot_red-hot-ticket');
    expect(store.read('directives/burner_red_hot_red-hot-ticket'))
      .toMatchObject({
        status: 'open',
        priority: 'critical',
        directedTo: 'seniorInstrumentation',
        linkedMaintenanceFirestoreId: 'red-hot-ticket',
        createdByUid: electrical.uid,
      });
  });

  test('fails closed on stale asset evidence and orphan projections', async () => {
    const stale = createServiceFor(admin);
    await expect(stale.service.execute(createCommand({
      commandId: 'create-stale-ticket',
      ticketId: 'stale-ticket',
      ticket: {assetHierarchyRefJson: physicalAssetReference(3)},
    }), stale.context)).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'maintenance-ticket-governed-asset-changed'},
    });

    const orphan = createServiceFor(admin);
    orphan.store.seed('quality_warnings/issue_orphan-ticket', {
      warningId: 'issue_orphan-ticket',
    });
    await expect(orphan.service.execute(createCommand({
      commandId: 'create-orphan-ticket',
      ticketId: 'orphan-ticket',
    }), orphan.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-create-orphan-evidence'},
    });
  });

  test('rejects a non-initial client version for a new ticket', async () => {
    const seeded = createServiceFor(admin);
    await expect(seeded.service.execute(createCommand({
      commandId: 'create-version-two-ticket',
      ticketId: 'version-two-ticket',
      ticket: {version: 2},
    }), seeded.context)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'maintenance-ticket-create-version-invalid'},
    });
    expect(seeded.store.read('maintenance_records/version-two-ticket'))
      .toBeNull();
  });

  test('replay fails closed when derived evidence no longer matches', async () => {
    const {store, service, context} = createServiceFor(admin);
    const command = createCommand({
      commandId: 'create-replay-quality',
      ticketId: 'replay-quality',
      ticket: {
        chargeNoAtEvent: 22334,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'The reported deviation requires quality review.',
      },
    });
    await service.execute(command, context);
    store.seed('quality_warnings/issue_replay-quality', {
      warningId: 'issue_replay-quality',
      sourceType: 'issue',
      sourceId: 'another-ticket',
      createdByUid: admin.uid,
    });

    await expect(service.execute(command, context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-create-replay-warning-invalid'},
    });

    const noDerived = createServiceFor(admin);
    const noDerivedCommand = createCommand({
      commandId: 'create-no-derived',
      ticketId: 'no-derived',
    });
    await noDerived.service.execute(noDerivedCommand, noDerived.context);
    noDerived.store.seed('directives/burner_red_hot_no-derived', {
      firestoreId: 'burner_red_hot_no-derived',
    });
    await expect(noDerived.service.execute(
      noDerivedCommand,
      noDerived.context,
    )).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-create-replay-directive-invalid',
      },
    });
  });

  test('route authority acknowledges once with audit and idempotent receipt', async () => {
    const {store, service, context} = serviceFor(electrical);
    const command = acknowledgeCommand();

    const applied = await service.execute(command, context);
    const replay = await service.execute(command, context);

    expect(replay).toEqual(applied);
    expect(applied).toMatchObject({
      resultKey: 'maintenance-ticket-acknowledged',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        auditId: 'server_maintenance_ticket_ack-ticket-1',
      },
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'acknowledged',
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: at.toISOString(),
      version: 4,
    });
    expect(store.read('audit_logs/server_maintenance_ticket_ack-ticket-1'))
      .toMatchObject({
        entityType: 'maintenance',
        entityId: 'ticket-1',
        operation: 'acknowledgeMaintenanceTicket',
        performedByUid: electrical.uid,
        resultVersion: 4,
      });
    expect(store.entries().filter(([path]) =>
      path.startsWith('maintenance_workflow_command_receipts/'))).toHaveLength(1);
  });

  test('wrong discipline is denied while a supervisor may acknowledge', async () => {
    const denied = serviceFor(mechanical);
    await expect(denied.service.execute(
      acknowledgeCommand('wrong-lane'),
      denied.context,
    )).rejects.toMatchObject({code: 'permission-denied'});

    const allowed = serviceFor(contractSupervisor, {routedTo: 'mechanical'});
    await expect(allowed.service.execute(
      acknowledgeCommand('supervisor-ack'),
      allowed.context,
    )).resolves.toMatchObject({aggregateVersion: 4});
  });

  test('multi-lane issue tracks acknowledgement and completion per accountable lane', async () => {
    const seeded = serviceFor(electrical, {
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 1,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });

    await expect(seeded.service.execute({
      ...acknowledgeCommand('ack-electrical'),
      payload: {lane: 'electrical'},
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 4});
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'inProgress',
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: [],
    });

    await expect(seeded.service.execute({
      commandId: 'complete-electrical',
      commandType: 'completeMaintenanceTicketLane',
      aggregateId: 'ticket-1',
      expectedVersion: 4,
      payload: {lane: 'electrical'},
    }, {...seeded.context, actor: mechanical})).rejects.toMatchObject({
      code: 'permission-denied',
    });
    await expect(seeded.service.execute({
      commandId: 'complete-electrical',
      commandType: 'completeMaintenanceTicketLane',
      aggregateId: 'ticket-1',
      expectedVersion: 4,
      payload: {lane: 'electrical'},
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 5});
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'inProgress',
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: ['electrical'],
    });
  });

  test('supervisor can recompose single and multi-lane issues while retaining common progress', async () => {
    const seeded = serviceFor(contractSupervisor, {
      status: 'inProgress',
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: at.toISOString(),
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: [],
    });
    const receipt = await seeded.service.execute({
      commandId: 'reconfigure-ticket-lanes',
      commandType: 'reconfigureMaintenanceTicketLanes',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        lanes: ['electrical', 'instrumentation'],
        otherDepartment: null,
        reason: 'Mechanical support is replaced by I&A attendance.',
      },
    }, seeded.context);

    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-lanes-reconfigured',
      aggregateVersion: 4,
      result: {lanes: ['electrical', 'instrumentation']},
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      routedTo: 'electrical',
      status: 'inProgress',
      issueLaneRevision: 3,
      issueAssignedLanes: ['electrical', 'instrumentation'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: [],
    });
  });

  test('supervisor can transform single to multi, multi to multi, and multi to single', async () => {
    const seeded = serviceFor(contractSupervisor);

    await expect(seeded.service.execute({
      commandId: 'single-to-multi',
      commandType: 'reconfigureMaintenanceTicketLanes',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        lanes: ['electrical', 'mechanical'],
        otherDepartment: null,
        reason: 'Mechanical attendance is now also required.',
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 4});
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical', 'mechanical'],
      routedTo: 'electrical',
    });

    await expect(seeded.service.execute({
      commandId: 'multi-to-another-multi',
      commandType: 'reconfigureMaintenanceTicketLanes',
      aggregateId: 'ticket-1',
      expectedVersion: 4,
      payload: {
        lanes: ['mechanical', 'instrumentation'],
        otherDepartment: null,
        reason: 'I&A replaces Electrical after field triage.',
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 5});
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      issueLaneRevision: 3,
      issueAssignedLanes: ['mechanical', 'instrumentation'],
      routedTo: 'mechanical',
    });

    await expect(seeded.service.execute({
      commandId: 'multi-to-single',
      commandType: 'reconfigureMaintenanceTicketLanes',
      aggregateId: 'ticket-1',
      expectedVersion: 5,
      payload: {
        lanes: ['instrumentation'],
        otherDepartment: null,
        reason: 'Only I&A remains accountable after inspection.',
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 6});
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      issueLaneRevision: 4,
      issueAssignedLanes: ['instrumentation'],
      routedTo: 'instrumentation',
      status: 'open',
    });
  });

  test('supervisor resolves a multi-lane issue atomically with all parties', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T14:30:00.000Z',
      status: 'inProgress',
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T15:00:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: [],
    });
    const command = {
      commandId: 'resolve-multi-lane-ticket',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Both disciplines completed the field repair and checks.',
        teamsInvolved: ['mechanical', 'operations'],
        actionsJson: '[]',
      },
    };

    const receipt = await seeded.service.execute(command, seeded.context);
    await expect(seeded.service.execute(command, seeded.context))
      .resolves.toEqual(receipt);

    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-resolved',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        completedLanes: ['electrical', 'mechanical'],
      },
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'resolved',
      isResolved: true,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: ['electrical', 'mechanical'],
      issueCompletedLanes: ['electrical', 'mechanical'],
      closedByUid: contractSupervisor.uid,
      endDate: '2026-08-14T16:00:00.000Z',
      downtimeHours: 1.5,
      teamsInvolved: ['electrical', 'mechanical', 'operations'],
      version: 4,
    });
    expect(seeded.store.read(
      'audit_logs/server_maintenance_ticket_resolve-multi-lane-ticket',
    )).toMatchObject({
      operation: 'resolveMaintenanceTicket',
      performedByUid: contractSupervisor.uid,
      resultVersion: 4,
    });
  });

  test('discipline closer resolves one lane but cannot finalize multiple lanes', async () => {
    const single = serviceFor(electrical, {
      startDate: '2026-08-14T14:30:00.000Z',
    });
    await expect(single.service.execute({
      commandId: 'resolve-single-lane-ticket',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Electrical repair and functional check completed.',
        teamsInvolved: ['electrical'],
        actionsJson: '[]',
      },
    }, single.context)).resolves.toMatchObject({aggregateVersion: 4});

    const multi = serviceFor(electrical, {
      startDate: '2026-08-14T14:30:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 1,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });
    await expect(multi.service.execute({
      commandId: 'deny-multi-lane-resolution',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Attempted multi-lane closure.',
        teamsInvolved: ['electrical', 'mechanical'],
        actionsJson: '[]',
      },
    }, multi.context)).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('burner resolution derives immutable closure evidence from work actions', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      routedTo: 'instrumentation',
      classification: 'furnaceBurnerLockout',
      burnerPositions: [2, 5],
    });
    seeded.store.seed('maintenance_burner_closures/ticket-1', {
      firestoreId: 'ticket-1',
      sourceMaintenanceId: 'ticket-1',
      sourceVersion: 2,
      closedByUid: 'historical-closer',
      burnerResolutionEvidence: {},
      updatedAt: '2026-08-14T12:00:00.000Z',
    });
    const action = (position, code, reading) => ({
      schemaVersion: 1,
      asset: 'Furnace 7',
      component: `Burner ${position}`,
      actionType: 'repair',
      isAutoResolved: false,
      createdAt: '2026-08-14T16:00:00.000Z',
      severity: 'high',
      version: 1,
      attendanceSessionId: 'ticket-1',
      burnerPosition: position,
      burnerActionCode: code,
      burnerOutcome: 'returnedToService',
      burnerMicroampReading: reading,
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-burner-ticket',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Both burners returned to service after UV cleaning.',
        teamsInvolved: ['instrumentation'],
        actionsJson: JSON.stringify([
          action(2, 'uvDetectorCleaning', 4.2),
          action(5, 'uvDetectorCleaning', 4.8),
        ]),
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 4});

    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      burnerAttendedPositions: [2, 5],
      burnerResolutionEvidence: {
        '2': {
          outcome: 'returnedToService',
          actionCodes: ['uvDetectorCleaning'],
          microampReading: 4.2,
        },
        '5': {
          outcome: 'returnedToService',
          actionCodes: ['uvDetectorCleaning'],
          microampReading: 4.8,
        },
      },
    });
    expect(seeded.store.read('maintenance_burner_closures/ticket-1'))
      .toMatchObject({
        sourceMaintenanceId: 'ticket-1',
        sourceVersion: 4,
        closedByUid: admin.uid,
      });
  });

  test('operations reopens an exact resolved record and preserves closure history', async () => {
    const seeded = serviceFor(operations, {
      startDate: '2026-08-14T13:00:00.000Z',
      status: 'resolved',
      isResolved: true,
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T14:00:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: ['electrical', 'mechanical'],
      issueCompletedLanes: ['electrical', 'mechanical'],
      endDate: '2026-08-14T15:30:00.000Z',
      closedByUid: contractSupervisor.uid,
      closedByName: contractSupervisor.name,
      remarks: 'Initial repair completed.',
      downtimeHours: 2.5,
      teamsInvolved: ['electrical', 'mechanical'],
      actionsJson: '[]',
      resolutionHistoryJson: '[]',
    });
    const command = {
      commandId: 'reopen-maintenance-ticket',
      commandType: 'reopenMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {remarks: 'The same symptom returned during operation.'},
    };

    const receipt = await seeded.service.execute(command, seeded.context);
    await expect(seeded.service.execute(command, seeded.context))
      .resolves.toEqual(receipt);
    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-reopened',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        assignedLanes: ['electrical', 'mechanical'],
      },
    });
    const reopened = seeded.store.read('maintenance_records/ticket-1');
    expect(reopened).toMatchObject({
      status: 'open',
      isResolved: false,
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
      endDate: null,
      closedByUid: null,
      teamsInvolved: [],
      actionsJson: '[]',
      reopenedByUid: operations.uid,
      version: 4,
    });
    expect(JSON.parse(reopened.resolutionHistoryJson)).toEqual([
      expect.objectContaining({
        resolvedByUid: contractSupervisor.uid,
        resolvedAt: '2026-08-14T15:30:00.000Z',
        remarks: 'Initial repair completed.',
        downtimeHours: 2.5,
        teamsInvolved: ['electrical', 'mechanical'],
      }),
    ]);
  });

  test('new lane projections require the complete field set', async () => {
    const {service, context} = createServiceFor(mechanical);
    await expect(service.execute(createCommand({
      commandId: 'partial-lane-create',
      ticketId: 'partial-lane-create',
      ticket: {issueLaneSchemaVersion: 1},
    }), context)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  test('acknowledgement fails closed on stale, deferred, or partial evidence', async () => {
    for (const ticket of [
      {workflowDeferred: true},
      {acknowledgedByUid: 'old-actor'},
      {status: 'resolved', isResolved: false},
      {
        status: 'acknowledged',
        acknowledgedByUid: electrical.uid,
        acknowledgedByName: electrical.name,
        acknowledgedAt: at.toISOString(),
        issueLaneSchemaVersion: 1,
        issueLaneRevision: 1,
        issueAssignedLanes: ['electrical', 'mechanical'],
        issueAcknowledgedLanes: ['electrical'],
        issueCompletedLanes: [],
      },
    ]) {
      const {service, context} = serviceFor(electrical, ticket);
      await expect(service.execute(acknowledgeCommand(), context))
        .rejects.toMatchObject({code: 'failed-precondition'});
    }

    const {service, context} = serviceFor(electrical);
    await expect(service.execute({
      ...acknowledgeCommand(),
      expectedVersion: 2,
    }, context)).rejects.toMatchObject({
      code: 'workflow-version-conflict',
      details: {reasonCode: 'maintenance-ticket-version-conflict'},
    });
  });

  test('admin correction changes only allowed fields and records its reason', async () => {
    const {store, service, context} = serviceFor(admin);
    const receipt = await service.execute({
      commandId: 'correct-ticket-1',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Corrected the receiving discipline after field verification.',
        corrections: {
          routedTo: 'mechanical',
          description: 'Burner gas pressure is unstable',
          tag: ' pt-107 ',
          remarks: null,
        },
      },
    }, context);

    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-corrected',
      aggregateVersion: 4,
      result: {
        correctedFields: ['description', 'routedTo', 'tag'],
      },
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      assetType: 'furnace',
      assetNumber: 7,
      routedTo: 'mechanical',
      description: 'Burner gas pressure is unstable',
      tag: 'PT-107',
      status: 'open',
      isResolved: false,
      version: 4,
    });
    expect(store.read(
      'audit_logs/server_maintenance_ticket_correct-ticket-1',
    )).toMatchObject({
      reason: 'manualOverride',
      reasonNotes: 'Corrected the receiving discipline after field verification.',
      performedByUid: admin.uid,
      resultVersion: 4,
    });
  });

  test('admin correction preserves burner specialization and red-hot criticality', async () => {
    const burnerTicket = {
      classification: 'furnaceBurnerLockout',
      routedTo: 'instrumentation',
      component: 'Burner system',
      maintenanceType: 'breakdown',
      tag: null,
      burnerPositions: [3],
      burnerRedHotPositions: [3],
    };
    const allowed = serviceFor(admin, burnerTicket);
    await expect(allowed.service.execute({
      commandId: 'correct-burner-description',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Description clarified after the burner attendance review.',
        corrections: {description: 'Burner 3 remains locked out'},
      },
    }, allowed.context)).resolves.toMatchObject({aggregateVersion: 4});

    for (const [commandId, corrections] of [
      ['change-burner-route', {routedTo: 'mechanical'}],
      ['change-burner-class', {classification: 'general'}],
      ['change-burner-component', {component: 'Gas valve'}],
      ['add-burner-tag', {tag: 'FR-07-B03'}],
      ['clear-red-hot-criticality', {isCritical: false}],
    ]) {
      const current = serviceFor(admin, burnerTicket);
      await expect(current.service.execute({
        commandId,
        commandType: 'correctMaintenanceTicket',
        aggregateId: 'ticket-1',
        expectedVersion: 3,
        payload: {
          reason: 'Attempted correction was checked against burner identity.',
          corrections,
        },
      }, current.context)).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'maintenance-burner-specialization-immutable'},
      });
    }

    const malformed = serviceFor(admin, {
      ...burnerTicket,
      burnerPositions: [3, 3],
    });
    await expect(malformed.service.execute({
      commandId: 'correct-malformed-burner',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Narrative correction waits for evidence reconciliation.',
        corrections: {description: 'Clarified description'},
      },
    }, malformed.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-burner-evidence-malformed'},
    });
  });

  test('admin correction preserves Furnace stuck-up specialization', async () => {
    const stuckupTicket = {
      classification: 'furnaceStuckup',
      routedTo: 'mechanical',
      component: 'Furnace / Inner Cover interface',
      maintenanceType: 'breakdown',
      tag: null,
    };
    const allowed = serviceFor(admin, stuckupTicket);
    await expect(allowed.service.execute({
      commandId: 'correct-stuckup-description',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Description clarified after the stuck-up field review.',
        corrections: {description: 'Furnace remains held at Base 117'},
      },
    }, allowed.context)).resolves.toMatchObject({aggregateVersion: 4});

    for (const [commandId, corrections] of [
      ['change-stuckup-route', {routedTo: 'electrical'}],
      ['change-stuckup-class', {classification: 'general'}],
      ['change-stuckup-component', {component: 'Furnace shell'}],
      ['change-stuckup-type', {maintenanceType: 'inspection'}],
      ['add-stuckup-tag', {tag: 'FR-07'}],
    ]) {
      const current = serviceFor(admin, stuckupTicket);
      await expect(current.service.execute({
        commandId,
        commandType: 'correctMaintenanceTicket',
        aggregateId: 'ticket-1',
        expectedVersion: 3,
        payload: {
          reason: 'Attempted correction was checked against stuck-up identity.',
          corrections,
        },
      }, current.context)).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'maintenance-stuckup-specialization-immutable'},
      });
    }
  });

  test('correction rejects non-admin, forbidden fields, and no-op changes', async () => {
    const command = {
      commandId: 'correct-ticket-1',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Correction requested after record verification.',
        corrections: {description: 'Updated description'},
      },
    };
    const denied = serviceFor(contractSupervisor);
    await expect(denied.service.execute(command, denied.context))
      .rejects.toMatchObject({code: 'permission-denied'});

    const forbidden = serviceFor(admin);
    await expect(forbidden.service.execute({
      ...command,
      payload: {...command.payload, corrections: {assetNumber: 9}},
    }, forbidden.context)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'maintenance-ticket-corrections-invalid'},
    });

    const noop = serviceFor(admin);
    await expect(noop.service.execute({
      ...command,
      payload: {
        ...command.payload,
        corrections: {description: 'Burner pressure is unstable'},
      },
    }, noop.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-correction-noop'},
    });
  });

  test('correction preserves the coupled route and other-department invariant', async () => {
    const missingDepartment = serviceFor(admin);
    await expect(missingDepartment.service.execute({
      commandId: 'route-to-others-without-department',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Routing was reviewed against the receiving department.',
        corrections: {routedTo: 'others'},
      },
    }, missingDepartment.context)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'maintenance-ticket-route-department-invalid'},
    });

    const staleDepartment = serviceFor(admin, {
      otherDepartment: 'Hydraulics contractor',
    });
    await expect(staleDepartment.service.execute({
      commandId: 'normal-route-with-other-department',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Description was checked while repairing route evidence.',
        corrections: {description: 'Burner pressure remains unstable'},
      },
    }, staleDepartment.context)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'maintenance-ticket-route-department-invalid'},
    });

    const repairedDepartment = serviceFor(admin, {
      otherDepartment: 'Hydraulics contractor',
    });
    await expect(repairedDepartment.service.execute({
      commandId: 'remove-stale-other-department',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Removed stale Other-department evidence from Electrical routing.',
        corrections: {otherDepartment: null},
      },
    }, repairedDepartment.context)).resolves.toMatchObject({aggregateVersion: 4});

    const valid = serviceFor(admin);
    await expect(valid.service.execute({
      commandId: 'route-to-others-with-department',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Routing was reviewed against the receiving department.',
        corrections: {
          routedTo: 'others',
          otherDepartment: 'Hydraulics contractor',
        },
      },
    }, valid.context)).resolves.toMatchObject({aggregateVersion: 4});
  });

  test('correction cannot transfer acknowledged work to a new route', async () => {
    const acknowledged = serviceFor(admin, {
      status: 'acknowledged',
      acknowledgedByUid: 'electrical-1',
      acknowledgedByName: 'electrical-1',
      acknowledgedAt: at.toISOString(),
    });
    await expect(acknowledged.service.execute({
      commandId: 'transfer-acknowledged-ticket',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Requested route transfer after acknowledgement review.',
        corrections: {routedTo: 'mechanical'},
      },
    }, acknowledged.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-route-locked'},
    });

    await expect(acknowledged.service.execute({
      commandId: 'correct-acknowledged-description',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Description correction preserves receiving accountability.',
        corrections: {description: 'Burner gas pressure is unstable'},
      },
    }, acknowledged.context)).resolves.toMatchObject({aggregateVersion: 4});
  });

  test('completed ticket-command receipt without its audit fails closed', async () => {
    const {store, service, context} = serviceFor(electrical);
    const command = acknowledgeCommand('missing-audit');
    store.seed('maintenance_workflow_command_receipts/missing-audit', {
      receiptSchemaVersion: 2,
      commandId: command.commandId,
      commandType: command.commandType,
      aggregateId: command.aggregateId,
      actorUid: electrical.uid,
      authorityScope: {
        schemaVersion: 1,
        capability: 'ticket.acknowledge',
        laneKey: 'elec',
      },
      payloadFingerprint: payloadFingerprint(command),
      resultKey: 'maintenance-ticket-acknowledged',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        auditId: 'server_maintenance_ticket_missing-audit',
      },
      appliedAt: at.toISOString(),
    });

    await expect(service.execute(command, context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-replay-audit-invalid'},
    });
  });

  test('historical single-lane acknowledgement receipt remains replayable', async () => {
    const command = acknowledgeCommand('legacy-acknowledgement');
    const {store, service, context} = serviceFor(electrical, {
      version: 4,
      status: 'acknowledged',
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: at.toISOString(),
    });
    const receipt = {
      receiptSchemaVersion: 2,
      commandId: command.commandId,
      commandType: command.commandType,
      aggregateId: command.aggregateId,
      actorUid: electrical.uid,
      authorityScope: {
        schemaVersion: 1,
        capability: 'ticket.acknowledge',
        laneKey: 'elec',
      },
      payloadFingerprint: payloadFingerprint(command),
      resultKey: 'maintenance-ticket-acknowledged',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        auditId: 'server_maintenance_ticket_legacy-acknowledgement',
      },
      appliedAt: at.toISOString(),
    };
    store.seed(
      'maintenance_workflow_command_receipts/legacy-acknowledgement',
      receipt,
    );
    store.seed(
      'audit_logs/server_maintenance_ticket_legacy-acknowledgement',
      {
        schemaVersion: 1,
        auditId: 'server_maintenance_ticket_legacy-acknowledgement',
        entityType: 'maintenance',
        entityId: 'ticket-1',
        action: 'update',
        operation: 'acknowledgeMaintenanceTicket',
        performedByUid: electrical.uid,
        requestId: command.commandId,
        resultVersion: 4,
        beforeJson: JSON.stringify({
          routedTo: 'electrical',
          status: 'open',
          acknowledgedByUid: null,
          acknowledgedByName: null,
          acknowledgedAt: null,
        }),
        afterJson: JSON.stringify({
          routedTo: 'electrical',
          status: 'acknowledged',
          acknowledgedByUid: electrical.uid,
          acknowledgedByName: electrical.name,
          acknowledgedAt: at.toISOString(),
        }),
      },
    );

    await expect(service.execute(command, context)).resolves.toMatchObject({
      commandId: command.commandId,
      resultKey: receipt.resultKey,
      aggregateVersion: receipt.aggregateVersion,
      result: receipt.result,
    });
  });
});
