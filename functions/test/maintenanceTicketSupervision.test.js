const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  payloadFingerprint,
} = require('../lib/maintenanceWorkflow/utils');
const {
  reopenMaintenanceTicket,
  resolveMaintenanceTicket,
} = require('../lib/maintenanceWorkflow/ticketHandlers');

const at = new Date('2026-08-14T16:30:00.000Z');
const actor = (uid, roles) => ({uid, name: uid, roles: new Set(roles)});
const admin = actor('admin-1', ['admin']);
const si = actor('si-1', ['si']);
const electrical = actor('electrical-1', ['seniorElectrical']);
const mechanical = actor('mechanical-1', ['seniorMechanical']);
const contractSupervisor = actor('contract-1', ['contractSupervisor']);
const operations = actor('operations-1', ['operations']);

function serviceFor(currentActor, ticket = {}) {
  const store = new MemoryWorkflowStore();
  for (const current of [
    admin, si, electrical, mechanical, contractSupervisor, operations,
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
    admin, si, electrical, mechanical, contractSupervisor, operations,
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
  store.seed('abnormality_types/ATMOSPHERE_DEVIATION', {
    firestoreId: 'ATMOSPHERE_DEVIATION',
    code: 'ATMOSPHERE_DEVIATION',
    title: 'Atmosphere deviation',
    category: 'process',
    severity: 'high',
    applicableAssetTypes: ['furnace', 'base'],
    suggestsReannealing: true,
    isActive: true,
    isDeleted: false,
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

function seedFurnaceHierarchy(store) {
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
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: ['seniorMechanical'],
  });
  store.seed('asset_hierarchy_nodes/node-furnace-shell', {
    schemaVersion: 1,
    nodeId: 'node-furnace-shell',
    assetClassId: 'class-furnace',
    status: 'active',
    version: 3,
    nodeType: 'component',
    name: 'Furnace shell',
    componentTag: null,
    hierarchyPath: ['Structure', 'Furnace shell'],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: ['seniorMechanical'],
  });
}

function furnaceShellReference(nodeVersion = 3) {
  return {
    schemaVersion: 4,
    scope: 'componentDefinitionOnAsset',
    assetClassId: 'class-furnace',
    assetInstanceId: 'asset-furnace-7',
    assetInstanceVersion: 4,
    nodeId: 'node-furnace-shell',
    nodeVersion,
  };
}

function hierarchyAction(overrides = {}) {
  return {
    schemaVersion: 1,
    asset: 'Untrusted asset label',
    component: 'Untrusted component label',
    hierarchyPath: ['Untrusted', 'Path'],
    assetHierarchyRef: furnaceShellReference(),
    system: 'Untrusted system',
    subsystem: 'Untrusted subsystem',
    tag: null,
    actionType: 'inspection',
    issue: 'Shell condition inspected.',
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-08-14T15:45:00.000Z',
    severity: 'medium',
    version: 1,
    ...overrides,
  };
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

function burnerResolutionAction({
  position,
  code = 'uvDetectorCleaning',
  reading,
  attendanceSessionId = `burner_ticket-1_${position}`,
}) {
  return {
    schemaVersion: 1,
    asset: 'Furnace 7',
    component: `Burner ${position}`,
    actionType: 'repair',
    isAutoResolved: false,
    createdAt: '2026-08-14T16:00:00.000Z',
    severity: 'high',
    version: 1,
    attendanceSessionId,
    burnerPosition: position,
    burnerActionCode: code,
    burnerOutcome: 'returnedToService',
    burnerMicroampReading: reading,
  };
}

const firestoreTimestamp = (value) => ({
  toDate: () => new Date(value),
});

function directHandlerTransaction(ticketId, ticket) {
  const docs = new Map([[`maintenance_records/${ticketId}`, ticket]]);
  const tx = {
    async get(path) {
      const data = docs.get(path);
      return {path, exists: data != null, data: data ?? null};
    },
    async query() {
      return [];
    },
    create(path, data) {
      if (docs.has(path)) throw new Error(`already-exists:${path}`);
      docs.set(path, data);
    },
    set(path, data, merge = false) {
      const prior = docs.get(path);
      docs.set(path, merge && prior != null ? {...prior, ...data} : data);
    },
    update(path, data) {
      const prior = docs.get(path);
      if (prior == null) throw new Error(`not-found:${path}`);
      docs.set(path, {...prior, ...data});
    },
  };
  return {tx, read: (path) => docs.get(path)};
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

  test('rejects one-character Other-department names on create and reconfiguration', async () => {
    const created = createServiceFor(mechanical);
    await expect(created.service.execute(createCommand({
      commandId: 'create-short-other-department',
      ticketId: 'short-other-department',
      ticket: {
        routedTo: 'others',
        otherDepartment: 'X',
        issueLaneSchemaVersion: 1,
        issueLaneRevision: 1,
        issueAssignedLanes: ['others'],
        issueAcknowledgedLanes: [],
        issueCompletedLanes: [],
      },
    }), created.context)).rejects.toMatchObject({code: 'invalid-argument'});

    const reconfigured = serviceFor(contractSupervisor);
    await expect(reconfigured.service.execute({
      commandId: 'reconfigure-short-other-department',
      commandType: 'reconfigureMaintenanceTicketLanes',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        lanes: ['others'],
        otherDepartment: 'X',
        reason: 'A specialist contractor is now accountable.',
      },
    }, reconfigured.context)).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('creates a quality warning with the issue in the same command', async () => {
    const {store, service, context} = createServiceFor(electrical);
    const command = createCommand({
      commandId: 'create-quality-ticket',
      ticketId: 'quality-ticket',
      ticket: {
        isCritical: true,
        chargeNoAtEvent: 12345,
        qualityIntentSchemaVersion: 2,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'Temperature deviation may have affected the coil.',
        qualityAbnormalityTypeId: 'ATMOSPHERE_DEVIATION',
      },
    });

    const receipt = await service.execute(command, context);

    expect(receipt.result).toMatchObject({
      warningId: 'issue_quality-ticket',
      abnormalityId: 'issue_quality_quality-ticket',
    });
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
    expect(
      store.read('charge_abnormalities/issue_quality_quality-ticket'),
    ).toMatchObject({
      firestoreId: 'issue_quality_quality-ticket',
      sourceChargeNo: 12345,
      abnormalityTypeId: 'ATMOSPHERE_DEVIATION',
      abnormalityTypeTitle: 'Atmosphere deviation',
      category: 'process',
      severity: 'critical',
      reannealingStatus: 'pendingDecision',
      linkedTicketFirestoreId: 'quality-ticket',
      loggedByUid: electrical.uid,
      version: 1,
    });
    expect(store.read('maintenance_records/quality-ticket')).toMatchObject({
      qualityAbnormalityId: 'issue_quality_quality-ticket',
      qualityWarningId: 'issue_quality-ticket',
      chargeQualityCaseId: 'issue_quality-ticket',
    });
  });

  test('suspected quality impact requires an active applicable classification', async () => {
    for (const ticket of [
      {
        chargeNoAtEvent: 12345,
        qualityIntentSchemaVersion: 1,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'Legacy suspected evidence cannot create a new case.',
      },
      {
        chargeNoAtEvent: 12345,
        qualityIntentSchemaVersion: 2,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'Current suspected evidence needs a classification.',
      },
    ]) {
      const missing = createServiceFor(electrical);
      await expect(missing.service.execute(createCommand({
        commandId: `reject-quality-classification-${ticket.qualityIntentSchemaVersion}`,
        ticketId: `reject-quality-classification-${ticket.qualityIntentSchemaVersion}`,
        ticket,
      }), missing.context)).rejects.toMatchObject({
        code: 'invalid-argument',
        details: {
          reasonCode: 'maintenance-ticket-quality-classification-invalid',
        },
      });
    }

    const inactive = createServiceFor(electrical);
    inactive.store.seed('abnormality_types/ATMOSPHERE_DEVIATION', {
      ...inactive.store.read('abnormality_types/ATMOSPHERE_DEVIATION'),
      isActive: false,
    });
    await expect(inactive.service.execute(createCommand({
      commandId: 'reject-inactive-quality-classification',
      ticketId: 'reject-inactive-quality-classification',
      ticket: {
        chargeNoAtEvent: 12345,
        qualityIntentSchemaVersion: 2,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'The inactive classification must not be accepted.',
        qualityAbnormalityTypeId: 'ATMOSPHERE_DEVIATION',
      },
    }), inactive.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-quality-type-unavailable'},
    });

    const inapplicable = createServiceFor(electrical);
    inapplicable.store.seed('abnormality_types/ATMOSPHERE_DEVIATION', {
      ...inapplicable.store.read('abnormality_types/ATMOSPHERE_DEVIATION'),
      applicableAssetTypes: ['base'],
    });
    await expect(inapplicable.service.execute(createCommand({
      commandId: 'reject-inapplicable-quality-classification',
      ticketId: 'reject-inapplicable-quality-classification',
      ticket: {
        chargeNoAtEvent: 12345,
        qualityIntentSchemaVersion: 2,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'The classification does not apply to this furnace.',
        qualityAbnormalityTypeId: 'ATMOSPHERE_DEVIATION',
      },
    }), inapplicable.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-quality-type-inapplicable'},
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
        qualityIntentSchemaVersion: 2,
        qualityImpactAssessment: 'suspected',
        qualityWarningReason: 'The reported deviation requires quality review.',
        qualityAbnormalityTypeId: 'ATMOSPHERE_DEVIATION',
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

    const abnormalityDrift = createServiceFor(admin);
    await abnormalityDrift.service.execute(command, abnormalityDrift.context);
    abnormalityDrift.store.seed(
      'charge_abnormalities/issue_quality_replay-quality',
      {
        ...abnormalityDrift.store.read(
          'charge_abnormalities/issue_quality_replay-quality',
        ),
        linkedTicketFirestoreId: 'another-ticket',
      },
    );
    await expect(abnormalityDrift.service.execute(
      command,
      abnormalityDrift.context,
    )).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-create-replay-abnormality-invalid',
      },
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

  test('reopened issue downtime starts at the latest reopen', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T10:00:00.000Z',
      reopenedByUid: operations.uid,
      reopenedByName: operations.name,
      reopenedAt: '2026-08-14T15:00:00.000Z',
      reopenReason: 'The fault returned after the equipment resumed service.',
      resolutionHistoryJson: JSON.stringify([{
        resolvedByUid: electrical.uid,
        resolvedByName: electrical.name,
        resolvedAt: '2026-08-14T12:00:00.000Z',
        actionsJson: '[]',
        remarks: 'Initial repair completed.',
        downtimeHours: 2,
        teamsInvolved: ['electrical'],
        reopenedByUid: operations.uid,
        reopenedByName: operations.name,
        reopenedAt: '2026-08-14T15:00:00.000Z',
        reopenReason: 'The fault returned after the equipment resumed service.',
      }]),
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-reopened-episode',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'The recurrent fault was repaired and functionally checked.',
        teamsInvolved: ['electrical'],
        actionsJson: '[]',
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 4});

    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'resolved',
      endDate: '2026-08-14T16:00:00.000Z',
      downtimeHours: 1,
    });
  });

  test('resolution waits for complied Operations coordination confirmation', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T14:30:00.000Z',
      workflowDeferred: false,
      workflowQueueState: 'awaitingConfirmation',
      workflowAggregateId: 'workflow-ticket-1',
      workflowComplianceId: 'compliance-ticket-1',
      workflowOriginLaneKey: 'mechanical',
      workflowTargetLaneKey: 'operations',
      workflowConditionTypeKey: 'craneSupport',
      workflowUpdatedAt: '2026-08-14T16:15:00.000Z',
    });
    seeded.store.seed('maintenance_workflows/workflow-ticket-1', {
      workflowKind: 'issueCoordination',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'readyForClosure',
      cancelled: false,
      version: 3,
    });
    seeded.store.seed('compliance_requests/compliance-ticket-1', {
      linkedWorkflowId: 'workflow-ticket-1',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'complied',
      version: 2,
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-before-coordination-confirmation',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Repair work is complete.',
        teamsInvolved: ['mechanical'],
        actionsJson: '[]',
      },
    }, seeded.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-coordination-open',
        queueState: 'awaitingConfirmation',
      },
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'open',
      isResolved: false,
      version: 3,
    });
  });

  test('resolution rejects an unprojected active Operations obligation', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T14:30:00.000Z',
    });
    seeded.store.seed('maintenance_workflows/orphan-workflow', {
      workflowKind: 'issueCoordination',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'inProgress',
      cancelled: false,
      version: 2,
    });
    seeded.store.seed('compliance_requests/orphan-compliance', {
      linkedWorkflowId: 'orphan-workflow',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'acknowledged',
      version: 2,
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-with-orphan-obligation',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Repair work is complete.',
        teamsInvolved: ['mechanical'],
        actionsJson: '[]',
      },
    }, seeded.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-coordination-projection-diverged',
      },
    });
  });

  test('resolution accepts exact terminal Operations coordination evidence', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T14:30:00.000Z',
      workflowDeferred: false,
      workflowQueueState: 'released',
      workflowAggregateId: 'workflow-ticket-1',
      workflowComplianceId: 'compliance-ticket-1',
      workflowOriginLaneKey: 'mechanical',
      workflowTargetLaneKey: 'operations',
      workflowConditionTypeKey: 'craneSupport',
      workflowUpdatedAt: '2026-08-14T16:15:00.000Z',
    });
    seeded.store.seed('maintenance_workflows/workflow-ticket-1', {
      workflowKind: 'issueCoordination',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'completed',
      cancelled: false,
      version: 4,
    });
    seeded.store.seed('compliance_requests/compliance-ticket-1', {
      linkedWorkflowId: 'workflow-ticket-1',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'confirmedClosed',
      version: 3,
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-after-coordination-confirmation',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Repair and Operations support are both complete.',
        teamsInvolved: ['mechanical', 'operations'],
        actionsJson: '[]',
      },
    }, seeded.context)).resolves.toMatchObject({
      resultKey: 'maintenance-ticket-resolved',
      aggregateVersion: 4,
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

  test('admin closes an active issue without manufacturing resolution evidence', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });
    const command = {
      commandId: 'admin-close-unresolved-ticket',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        disposition: '  stillRelevant  ',
        reason: '  The charge has ended, but the unresolved condition remains relevant for engineering review.  ',
      },
    };

    const receipt = await seeded.service.execute(command, seeded.context);
    await expect(seeded.service.execute(command, seeded.context))
      .resolves.toEqual(receipt);

    expect(receipt).toMatchObject({
      resultKey: 'maintenance-ticket-closed-without-resolution',
      aggregateVersion: 4,
      result: {
        ticketId: 'ticket-1',
        disposition: 'stillRelevant',
        cancelledCoordination: false,
        cancelledWorkflowId: null,
        cancelledComplianceId: null,
      },
    });
    const closed = seeded.store.read('maintenance_records/ticket-1');
    expect(closed).toMatchObject({
      status: 'closedWithoutResolution',
      isResolved: true,
      closedByUid: admin.uid,
      endDate: at.toISOString(),
      issueClosureSchemaVersion: 1,
      issueClosureDisposition: 'stillRelevant',
      issueClosureReason:
        'The charge has ended, but the unresolved condition remains relevant for engineering review.',
      issueAssignedLanes: ['electrical', 'mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
      version: 4,
    });
    expect(
      Object.keys(closed).filter((field) => field.startsWith('workflow')),
    ).toEqual([]);
  });

  test.each([
    ['open', false],
    ['acknowledged', true],
    ['inProgress', true],
  ])(
    'administrative closure preserves the canonical lane history of a legacy %s issue',
    async (status, acknowledged) => {
      const seeded = serviceFor(admin, {
        startDate: '2026-08-14T14:30:00.000Z',
        status,
        ...(acknowledged ? {
          acknowledgedByUid: electrical.uid,
          acknowledgedByName: electrical.name,
          acknowledgedAt: '2026-08-14T15:00:00.000Z',
        } : {}),
      });

      const receipt = await seeded.service.execute({
        commandId: `admin-close-legacy-${status}-ticket`,
        commandType: 'closeMaintenanceTicketWithoutResolution',
        aggregateId: 'ticket-1',
        expectedVersion: 3,
        payload: {
          disposition: 'relevanceEnded',
          reason: 'The operating cycle ended before the reported condition was repaired.',
        },
      }, seeded.context);

      expect(receipt.aggregateVersion).toBe(4);
      expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
        status: 'closedWithoutResolution',
        issueLaneSchemaVersion: 1,
        issueLaneRevision: 1,
        issueAssignedLanes: ['electrical'],
        issueAcknowledgedLanes: acknowledged ? ['electrical'] : [],
        issueCompletedLanes: [],
        ...(acknowledged ? {
          acknowledgedByUid: electrical.uid,
          acknowledgedByName: electrical.name,
          acknowledgedAt: '2026-08-14T15:00:00.000Z',
        } : {}),
      });
    },
  );

  test.each(['deferred', 'correctionRequired'])(
    'admin closure atomically cancels %s Operations coordination',
    async (workflowQueueState) => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      status: 'acknowledged',
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T15:00:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 1,
      issueAssignedLanes: ['electrical'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: [],
      workflowDeferred: true,
      workflowQueueState,
      workflowAggregateId: 'issue-workflow-1',
      workflowComplianceId: 'issue-compliance-1',
      workflowOriginLaneKey: 'elec',
      workflowTargetLaneKey: 'oprn',
      workflowConditionTypeKey: 'manual',
      workflowUpdatedAt: '2026-08-14T15:00:00.000Z',
    });
    seeded.store.seed('maintenance_workflows/issue-workflow-1', {
      workflowSchemaVersion: 1,
      workflowKind: 'issueCoordination',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'awaitingCompliance',
      cancelled: false,
      version: 2,
    });
    seeded.store.seed('compliance_requests/issue-compliance-1', {
      linkedWorkflowId: 'issue-workflow-1',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'raised',
      version: 3,
    });

    const receipt = await seeded.service.execute({
      commandId: 'admin-close-deferred-ticket',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        disposition: 'relevanceEnded',
        reason: 'The operating cycle ended and the reported condition no longer requires maintenance action.',
      },
    }, seeded.context);

    expect(receipt.result).toMatchObject({
      cancelledCoordination: true,
      cancelledWorkflowId: 'issue-workflow-1',
      cancelledComplianceId: 'issue-compliance-1',
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'closedWithoutResolution',
      issueClosureDisposition: 'relevanceEnded',
      workflowDeferred: false,
      workflowQueueState: 'released',
      workflowReleasedByUid: admin.uid,
    });
    expect(seeded.store.read('maintenance_workflows/issue-workflow-1'))
      .toMatchObject({
        status: 'cancelled',
        cancelled: true,
        cancelledByUid: admin.uid,
        version: 3,
      });
    expect(seeded.store.read('compliance_requests/issue-compliance-1'))
      .toMatchObject({
        status: 'cancelled',
        cancelledByUid: admin.uid,
        version: 4,
      });
    },
  );

  test('admin closure fails closed on a partial coordination projection', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      workflowDeferred: true,
      workflowQueueState: 'deferred',
      workflowAggregateId: 'partial-workflow',
      workflowComplianceId: 'partial-compliance',
    });

    await expect(seeded.service.execute({
      commandId: 'deny-partial-projection-closure',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        disposition: 'stillRelevant',
        reason: 'The unresolved issue remains relevant after the current charge ended.',
      },
    }, seeded.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-coordination-projection-invalid',
      },
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'open',
      isResolved: false,
      version: 3,
    });
  });

  test('admin closure rejects an active workflow missing from the ticket projection', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
    });
    seeded.store.seed('maintenance_workflows/orphan-active-workflow', {
      workflowSchemaVersion: 1,
      workflowKind: 'issueCoordination',
      linkedMaintenanceFirestoreId: 'ticket-1',
      status: 'awaitingCompliance',
      cancelled: false,
      version: 1,
    });

    await expect(seeded.service.execute({
      commandId: 'deny-orphan-workflow-closure',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        disposition: 'relevanceEnded',
        reason: 'The operating context ended, but orphan workflow evidence remains.',
      },
    }, seeded.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-coordination-projection-diverged',
      },
    });
    expect(seeded.store.read('maintenance_records/ticket-1')).toMatchObject({
      status: 'open',
      isResolved: false,
      version: 3,
    });
  });

  test('non-admin cannot close an issue without resolution', async () => {
    const seeded = serviceFor(contractSupervisor, {
      startDate: '2026-08-14T14:30:00.000Z',
    });
    await expect(seeded.service.execute({
      commandId: 'deny-unresolved-closure',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        disposition: 'stillRelevant',
        reason: 'This attempt must not cross the Admin-only closure boundary.',
      },
    }, seeded.context)).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('resolution accepts persisted timestamps but keeps command time text-only', async () => {
    const ticketId = 'timestamp-resolution';
    const ticket = {
      firestoreId: ticketId,
      version: 3,
      routedTo: 'electrical',
      status: 'open',
      isResolved: false,
      isDeleted: false,
      workflowDeferred: false,
      startDate: firestoreTimestamp('2026-08-14T14:30:00.000Z'),
    };
    const command = {
      commandId: 'resolve-timestamp-ticket',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: ticketId,
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Electrical repair and functional check completed.',
        teamsInvolved: ['electrical'],
        actionsJson: '[]',
      },
    };
    const accepted = directHandlerTransaction(ticketId, ticket);

    await expect(resolveMaintenanceTicket({
      tx: accepted.tx,
      command,
      context: {actor: electrical, serverNow: at},
    })).resolves.toMatchObject({aggregateVersion: 4});
    expect(accepted.read(`maintenance_records/${ticketId}`)).toMatchObject({
      endDate: '2026-08-14T16:00:00.000Z',
      downtimeHours: 1.5,
    });

    const rejected = directHandlerTransaction(ticketId, ticket);
    await expect(resolveMaintenanceTicket({
      tx: rejected.tx,
      command: {
        ...command,
        commandId: 'reject-non-text-command-time',
        payload: {
          ...command.payload,
          endDate: firestoreTimestamp('2026-08-14T16:00:00.000Z'),
        },
      },
      context: {actor: electrical, serverNow: at},
    })).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('resolution canonicalizes each new action from the live asset hierarchy', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      actionsJson: '[]',
    });
    seedFurnaceHierarchy(seeded.store);

    await expect(seeded.service.execute({
      commandId: 'resolve-with-governed-action',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'The governed shell inspection was completed.',
        teamsInvolved: ['mechanical'],
        actionsJson: JSON.stringify([hierarchyAction()]),
        actionTargetContractVersion: 1,
      },
    }, seeded.context)).resolves.toMatchObject({aggregateVersion: 4});

    const [savedAction] = JSON.parse(
      seeded.store.read('maintenance_records/ticket-1').actionsJson,
    );
    expect(savedAction).toMatchObject({
      asset: 'Furnace 7',
      component: 'Furnace shell',
      hierarchyPath: ['Structure', 'Furnace shell'],
      system: 'Furnace',
      subsystem: 'Structure',
      tag: null,
      performedBy: admin.name,
      assetHierarchyRef: {
        schemaVersion: 4,
        scope: 'componentDefinitionOnAsset',
        nodeId: 'node-furnace-shell',
        nodeVersion: 3,
        assetInstanceId: 'asset-furnace-7',
        assetInstanceVersion: 4,
      },
    });
  });

  test('resolution rejects stale action targets and retained-history changes', async () => {
    const stale = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      actionsJson: '[]',
    });
    seedFurnaceHierarchy(stale.store);
    await expect(stale.service.execute({
      commandId: 'reject-stale-action-target',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'This action points at an old hierarchy revision.',
        teamsInvolved: ['mechanical'],
        actionsJson: JSON.stringify([
          hierarchyAction({
            assetHierarchyRef: furnaceShellReference(2),
          }),
        ]),
        actionTargetContractVersion: 1,
      },
    }, stale.context)).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'maintenance-ticket-component-definition-changed'},
    });

    const retained = hierarchyAction({
      asset: 'Historical operator label',
      component: 'Historical shell finding',
    });
    const tampered = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      actionsJson: JSON.stringify([retained]),
    });
    await expect(tampered.service.execute({
      commandId: 'reject-action-history-change',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Attempted closure after changing retained evidence.',
        teamsInvolved: ['mechanical'],
        actionsJson: JSON.stringify([
          {...retained, component: 'Rewritten historical finding'},
        ]),
        actionTargetContractVersion: 1,
      },
    }, tampered.context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-action-history-changed'},
    });
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
          burnerResolutionAction({position: 2, reading: 4.2}),
          burnerResolutionAction({position: 5, reading: 4.8}),
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

  test('rejects burner evidence bound to another attendance session', async () => {
    const seeded = serviceFor(admin, {
      startDate: '2026-08-14T14:30:00.000Z',
      routedTo: 'instrumentation',
      classification: 'furnaceBurnerLockout',
      burnerPositions: [2],
    });

    await expect(seeded.service.execute({
      commandId: 'resolve-mismatched-burner-session',
      commandType: 'resolveMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        endDate: '2026-08-14T16:00:00.000Z',
        remarks: 'Attempted closure with mismatched burner evidence.',
        teamsInvolved: ['instrumentation'],
        actionsJson: JSON.stringify([
          burnerResolutionAction({
            position: 2,
            reading: 4.2,
            attendanceSessionId: 'burner_ticket-1_5',
          }),
        ]),
      },
    }, seeded.context)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'maintenance-ticket-burner-resolution-invalid'},
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
        reopenedByUid: operations.uid,
        reopenedByName: operations.name,
        reopenedAt: at.toISOString(),
        reopenReason: 'The same symptom returned during operation.',
      }),
    ]);
  });

  test('successive reopens preserve each lifecycle reopening event', async () => {
    const seeded = serviceFor(operations, {
      startDate: '2026-08-14T13:00:00.000Z',
      status: 'resolved',
      isResolved: true,
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T14:00:00.000Z',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: ['electrical'],
      endDate: '2026-08-14T15:30:00.000Z',
      closedByUid: electrical.uid,
      closedByName: electrical.name,
      remarks: 'First repair completed.',
      downtimeHours: 1,
      teamsInvolved: ['electrical'],
      actionsJson: '[]',
      resolutionHistoryJson: '[]',
    });
    await seeded.service.execute({
      commandId: 'first-reopen-cycle',
      commandType: 'reopenMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {remarks: 'First recurrence after returning to service.'},
    }, seeded.context);

    const afterFirstReopen = seeded.store.read('maintenance_records/ticket-1');
    seeded.store.seed('maintenance_records/ticket-1', {
      ...afterFirstReopen,
      version: 5,
      status: 'resolved',
      isResolved: true,
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: ['electrical'],
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T16:45:00.000Z',
      endDate: '2026-08-14T17:00:00.000Z',
      closedByUid: contractSupervisor.uid,
      closedByName: contractSupervisor.name,
      remarks: 'Second repair completed.',
      downtimeHours: 0.5,
      teamsInvolved: ['electrical'],
      actionsJson: '[]',
    });
    const secondAt = new Date('2026-08-14T17:30:00.000Z');
    await seeded.service.execute({
      commandId: 'second-reopen-cycle',
      commandType: 'reopenMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 5,
      payload: {remarks: 'Second recurrence after the follow-up repair.'},
    }, {actor: admin, serverNow: secondAt});

    const reopened = seeded.store.read('maintenance_records/ticket-1');
    const history = JSON.parse(reopened.resolutionHistoryJson);
    expect(history).toHaveLength(2);
    expect(history[0]).toMatchObject({
      resolvedAt: '2026-08-14T15:30:00.000Z',
      reopenedByUid: operations.uid,
      reopenedAt: at.toISOString(),
      reopenReason: 'First recurrence after returning to service.',
    });
    expect(history[1]).toMatchObject({
      resolvedAt: '2026-08-14T17:00:00.000Z',
      reopenedByUid: admin.uid,
      reopenedAt: secondAt.toISOString(),
      reopenReason: 'Second recurrence after the follow-up repair.',
    });
    expect(reopened).toMatchObject({
      reopenedByUid: admin.uid,
      reopenedAt: secondAt.toISOString(),
      reopenReason: 'Second recurrence after the follow-up repair.',
      version: 6,
    });
  });

  test('reopen accepts a persisted timestamp and absent legacy history', async () => {
    const ticketId = 'legacy-timestamp-reopen';
    const ticket = {
      firestoreId: ticketId,
      version: 3,
      routedTo: 'electrical',
      status: 'resolved',
      isResolved: true,
      isDeleted: false,
      workflowDeferred: false,
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 2,
      issueAssignedLanes: ['electrical'],
      issueAcknowledgedLanes: ['electrical'],
      issueCompletedLanes: ['electrical'],
      acknowledgedByUid: electrical.uid,
      acknowledgedByName: electrical.name,
      acknowledgedAt: '2026-08-14T14:00:00.000Z',
      endDate: firestoreTimestamp('2026-08-14T15:30:00.000Z'),
      closedByUid: electrical.uid,
      closedByName: electrical.name,
      remarks: 'Initial repair completed.',
      downtimeHours: 2.5,
      teamsInvolved: ['electrical'],
      actionsJson: '[]',
    };
    const state = directHandlerTransaction(ticketId, ticket);

    await expect(reopenMaintenanceTicket({
      tx: state.tx,
      command: {
        commandId: 'reopen-legacy-timestamp-ticket',
        commandType: 'reopenMaintenanceTicket',
        aggregateId: ticketId,
        expectedVersion: 3,
        payload: {remarks: 'The symptom returned during operation.'},
      },
      context: {actor: operations, serverNow: at},
    })).resolves.toMatchObject({aggregateVersion: 4});

    const reopened = state.read(`maintenance_records/${ticketId}`);
    expect(reopened).toMatchObject({
      status: 'open',
      endDate: null,
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });
    expect(JSON.parse(reopened.resolutionHistoryJson)).toEqual([
      expect.objectContaining({
        resolvedAt: '2026-08-14T15:30:00.000Z',
        resolvedByUid: electrical.uid,
        reopenedByUid: operations.uid,
        reopenedAt: at.toISOString(),
      }),
    ]);

    const corrupt = directHandlerTransaction(ticketId, {
      ...ticket,
      resolutionHistoryJson: '',
    });
    await expect(reopenMaintenanceTicket({
      tx: corrupt.tx,
      command: {
        commandId: 'reject-blank-legacy-history',
        commandType: 'reopenMaintenanceTicket',
        aggregateId: ticketId,
        expectedVersion: 3,
        payload: {remarks: 'Attempted reopen with corrupt history.'},
      },
      context: {actor: operations, serverNow: at},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-resolution-history-invalid',
        field: 'resolutionHistoryJson',
      },
    });
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

  test('primary-route correction preserves and deduplicates secondary lanes', async () => {
    const {store, service, context} = serviceFor(admin, {
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 4,
      issueAssignedLanes: ['electrical', 'mechanical', 'instrumentation'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });
    await expect(service.execute({
      commandId: 'correct-multi-lane-primary',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Primary accountability changed after the supervisor review.',
        corrections: {routedTo: 'instrumentation'},
      },
    }, context)).resolves.toMatchObject({
      resultKey: 'maintenance-ticket-corrected',
      aggregateVersion: 4,
    });

    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      routedTo: 'instrumentation',
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 5,
      issueAssignedLanes: ['instrumentation', 'mechanical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
    });
    const audit = store.read(
      'audit_logs/server_maintenance_ticket_correct-multi-lane-primary',
    );
    expect(JSON.parse(audit.beforeJson).issueAssignedLanes).toEqual([
      'electrical', 'mechanical', 'instrumentation',
    ]);
    expect(JSON.parse(audit.afterJson).issueAssignedLanes).toEqual([
      'instrumentation', 'mechanical',
    ]);
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

  test('correction permits SI but rejects non-supervisors and invalid changes', async () => {
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

    const siCorrection = serviceFor(si, {status: 'resolved', isResolved: true});
    await expect(siCorrection.service.execute({
      ...command,
      commandId: 'si-correct-terminal-ticket',
    }, siCorrection.context)).resolves.toMatchObject({
      resultKey: 'maintenance-ticket-corrected',
      aggregateVersion: 4,
    });

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

    const legacyShortDepartment = serviceFor(admin, {
      routedTo: 'others',
      otherDepartment: 'X',
    });
    await expect(legacyShortDepartment.service.execute({
      commandId: 'repair-short-other-department',
      commandType: 'correctMaintenanceTicket',
      aggregateId: 'ticket-1',
      expectedVersion: 3,
      payload: {
        reason: 'Expanded the legacy receiving-department abbreviation.',
        corrections: {otherDepartment: 'QA'},
      },
    }, legacyShortDepartment.context)).resolves.toMatchObject({
      aggregateVersion: 4,
    });
    expect(legacyShortDepartment.store.read('maintenance_records/ticket-1'))
      .toMatchObject({routedTo: 'others', otherDepartment: 'QA'});

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
