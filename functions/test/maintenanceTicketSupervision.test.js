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

describe('governed maintenance-ticket supervision', () => {
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
