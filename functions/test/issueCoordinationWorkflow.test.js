const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const at = (value) => new Date(value);

const seedActor = (store, uid, roles) => {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
};

const seedAcknowledgedTicket = (store, overrides = {}) => {
  store.seed('maintenance_records/ticket-1', {
    firestoreId: 'ticket-1',
    version: 3,
    assetType: 'furnace',
    assetNumber: 7,
    routedTo: 'mechanical',
    status: 'acknowledged',
    isResolved: false,
    isDeleted: false,
    acknowledgedByUid: 'mechanical-1',
    acknowledgedByName: 'mechanical-1',
    acknowledgedAt: '2026-08-20T04:00:00.000Z',
    workflowQueueState: 'independent',
    workflowDeferred: false,
    chargeNoAtEvent: 12345,
    ...overrides,
  });
};

const command = (overrides = {}) => ({
  commandId: 'start-coordination-1',
  commandType: 'startIssueCoordination',
  aggregateId: 'issue-coordination-1',
  expectedVersion: 0,
  payload: {
    ticketId: 'ticket-1',
    expectedTicketVersion: 3,
    complianceId: 'issue-compliance-1',
    requestPurposeKey: 'deferment',
    conditionTypeKey: 'chargeComplete',
    conditionRef: null,
    conditionChargeNo: 12345,
    defermentBasisKey: 'ongoingCycle',
    operationsSupportTypeKey: null,
    operationsResourceKey: null,
    requestedLocation: null,
    title: 'Await current annealing cycle completion',
    description: 'Release this maintenance issue when charge 12345 is complete.',
    priorityKey: 'high',
    ...overrides,
  },
});

describe('Ordinary issue Operations coordination', () => {
  test('holds an acknowledged issue, reactivates it on condition and closes the receipt trail', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);

    const started = await service.execute(command(), {
      actor: supervisor,
      serverNow: at('2026-08-20T04:05:00Z'),
    });
    expect(started).toMatchObject({
      resultKey: 'issue-coordination-started',
      aggregateVersion: 1,
      result: {
        workflowId: 'issue-coordination-1',
        ticketId: 'ticket-1',
        complianceId: 'issue-compliance-1',
      },
    });
    expect(store.read('maintenance_workflows/issue-coordination-1')).toMatchObject({
      workflowKind: 'issueCoordination',
      status: 'awaitingCompliance',
      jobExecutionId: 'ticket-1',
      version: 1,
    });
    expect(store.read('compliance_requests/issue-compliance-1')).toMatchObject({
      linkedMaintenanceFirestoreId: 'ticket-1',
      requestPurposeKey: 'deferment',
      targetLaneKey: 'oprn',
      conditionRef: '12345',
      assetTypeKey: 'furnace',
      assetNumber: 7,
      chargeNoAtEvent: 12345,
      raisedUnderCoordination: true,
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: true,
      workflowQueueState: 'deferred',
      workflowAggregateId: 'issue-coordination-1',
      workflowComplianceId: 'issue-compliance-1',
      version: 4,
    });

    await service.execute({
      commandId: 'condition-fulfilled-1',
      commandType: 'confirmConditionAndReactivate',
      aggregateId: 'issue-coordination-1',
      expectedVersion: 1,
      payload: {
        complianceId: 'issue-compliance-1',
        note: 'Charge 12345 completed and the Furnace is available for work.',
      },
    }, {
      actor: operations,
      serverNow: at('2026-08-20T05:00:00Z'),
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: false,
      workflowQueueState: 'actionable',
      version: 5,
    });

    await service.execute({
      commandId: 'confirm-coordination-1',
      commandType: 'confirmComplianceClosed',
      aggregateId: 'issue-coordination-1',
      expectedVersion: 2,
      payload: {
        complianceId: 'issue-compliance-1',
        note: 'Maintenance confirms that the Operations prerequisite is met.',
      },
    }, {
      actor: supervisor,
      serverNow: at('2026-08-20T05:05:00Z'),
    });
    expect(store.read('maintenance_workflows/issue-coordination-1')).toMatchObject({
      status: 'completed',
      version: 3,
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: false,
      workflowQueueState: 'released',
      version: 6,
    });
  });

  test('creates an immediate crane-support obligation without equipment-counter mutation', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store);
    const mechanical = seedActor(store, 'mechanical-1', ['seniorMechanical']);
    const service = new MaintenanceWorkflowCommandService(store);

    await service.execute(command({
      requestPurposeKey: 'operationsSupport',
      conditionTypeKey: 'manual',
      conditionChargeNo: null,
      defermentBasisKey: null,
      operationsSupportTypeKey: 'craneMovement',
      operationsResourceKey: 'crane',
      requestedLocation: 'Furnace Stand 2',
      title: 'Move Furnace to stand',
      description: 'Provide crane support and place the Furnace on Stand 2.',
    }), {
      actor: mechanical,
      serverNow: at('2026-08-20T04:05:00Z'),
    });

    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: true,
      workflowQueueState: 'deferred',
    });
    expect(store.read('compliance_requests/issue-compliance-1')).toMatchObject({
      requestPurposeKey: 'operationsSupport',
      operationsSupportTypeKey: 'craneMovement',
      operationsResourceKey: 'crane',
      requestedLocation: 'Furnace Stand 2',
      becameDueAt: '2026-08-20T04:05:00.000Z',
    });
    expect(store.entries().filter(([path]) => path.startsWith('equipment_status/')))
      .toHaveLength(0);
    expect(store.entries().filter(([path]) => path.startsWith('job_lanes/')))
      .toHaveLength(0);
  });

  test('rejects an invalid charge and an unacknowledged issue', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store, {
      status: 'open',
      acknowledgedByUid: null,
      acknowledgedByName: null,
      acknowledgedAt: null,
    });
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(command({conditionChargeNo: 1234}), {
      actor: supervisor,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(service.execute(command(), {
      actor: supervisor,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'issue-coordination-ticket-not-acknowledged'},
    });
  });
});
