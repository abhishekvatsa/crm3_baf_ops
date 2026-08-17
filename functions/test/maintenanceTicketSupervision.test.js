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

function serviceFor(currentActor, ticket = {}) {
  const store = new MemoryWorkflowStore();
  for (const current of [admin, electrical, mechanical, contractSupervisor]) {
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
  for (const current of [admin, electrical, mechanical, contractSupervisor]) {
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

  test('creates a quality warning with the issue in the same command', async () => {
    const {store, service, context} = createServiceFor(electrical);
    const command = createCommand({
      commandId: 'create-quality-ticket',
      ticketId: 'quality-ticket',
      ticket: {
        isCritical: true,
        chargeNoAtEvent: 123456,
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
      sourceChargeNo: 123456,
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

  test('replay fails closed when derived evidence no longer matches', async () => {
    const {store, service, context} = createServiceFor(admin);
    const command = createCommand({
      commandId: 'create-replay-quality',
      ticketId: 'replay-quality',
      ticket: {
        chargeNoAtEvent: 223344,
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

  test('acknowledgement fails closed on stale, deferred, or partial evidence', async () => {
    for (const ticket of [
      {workflowDeferred: true},
      {acknowledgedByUid: 'old-actor'},
      {status: 'resolved', isResolved: false},
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
});
