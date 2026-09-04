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
  test.each(['deferment', 'operationsSupport'])(
    '%s retains original clocks, every attempt, and the previous coordination cycle',
    async (purpose) => {
      const store = new MemoryWorkflowStore();
      const original = {
        createdAt: '2026-08-19T01:00:00.000Z',
        startDate: '2026-08-19T00:30:00.000Z',
        acknowledgedAt: '2026-08-20T04:00:00.000Z',
        _globalPullServerUpdatedAt: '2026-08-20T04:01:00.000Z',
      };
      seedAcknowledgedTicket(store, original);
      const origin = seedActor(store, 'mechanical-1', ['contractSupervisor']);
      const target = seedActor(store, 'operations-1', ['operations']);
      const service = new MaintenanceWorkflowCommandService(store);
      const times = [];
      let minute = 5;
      const send = async (cmd, actor) => {
        const serverNow = new Date(Date.UTC(2026, 7, 20, 4, minute++));
        const receipt = await service.execute(cmd, {actor, serverNow});
        times.push([cmd.commandId, serverNow.toISOString()]);
        return receipt;
      };
      const request = purpose === 'deferment' ? {} : {
        requestPurposeKey: purpose, conditionTypeKey: 'manual', conditionChargeNo: null,
        defermentBasisKey: null, operationsSupportTypeKey: 'craneMovement',
        operationsResourceKey: 'crane', requestedLocation: 'Stand 2',
      };
      await send(command(request), origin);
      const step = (type, version, actor, payload = {}, suffix = '') => send({
        commandId: `${type}${suffix}`, commandType: type,
        aggregateId: 'issue-coordination-1', expectedVersion: version,
        payload: {complianceId: 'issue-compliance-1', ...payload},
      }, actor);
      await step('acknowledgeCompliance', 1, target);
      const complete = purpose === 'deferment' ? 'confirmConditionAndReactivate' : 'markComplianceComplied';
      await step(complete, 2, target, {note: 'First completion'}, '-1');
      await step('returnComplianceForCorrection', 3, origin, {reason: 'Position not correct'});
      await step(complete, 4, target, {note: 'Position rechecked'}, '-2');
      await step('confirmComplianceClosed', 5, origin);
      expect(store.read('maintenance_records/ticket-1')).toMatchObject(original);
      const firstRequest = store.read('compliance_requests/issue-compliance-1');
      expect(firstRequest).toMatchObject({
        raisedAt: times[0][1], acknowledgedAt: times[1][1],
        compliedAt: times[4][1], confirmedAt: times[5][1],
      });
      expect(store.read('compliance_attempts/issue-compliance-1_1')).toMatchObject({
        attemptedAt: times[2][1], returnedAt: times[3][1], accepted: false,
      });
      expect(store.read('compliance_attempts/issue-compliance-1_2')).toMatchObject({
        attemptedAt: times[4][1], accepted: true,
      });
      const previousWorkflow = store.read('maintenance_workflows/issue-coordination-1');
      const next = command({
        ...request, expectedTicketVersion: store.read('maintenance_records/ticket-1').version,
        complianceId: 'issue-compliance-2',
      });
      next.commandId = 'start-coordination-2';
      next.aggregateId = 'issue-coordination-2';
      await send(next, origin);
      expect(store.read('maintenance_records/ticket-1')).toMatchObject({
        ...original, workflowDeferredAt: times[6][1], workflowComplianceId: 'issue-compliance-2',
      });
      expect(store.read('compliance_requests/issue-compliance-1')).toEqual(firstRequest);
      expect(store.read('maintenance_workflows/issue-coordination-1')).toEqual(previousWorkflow);
      for (const [id, time] of times) {
        expect(store.read(`maintenance_workflow_events/${id}`).occurredAt).toBe(time);
      }
      const beforeReplay = store.entries();
      await service.execute(next, {actor: origin, serverNow: at('2026-08-21T00:00:00Z')});
      expect(store.entries()).toEqual(beforeReplay);
    },
  );

  const setup = async (request = {}) => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(command(request), {actor: supervisor, serverNow: at('2026-08-20T04:05:00Z')});
    const execute = (type, version, actor, payload = {}, id = type) => service.execute({
      commandId: id, commandType: type, aggregateId: 'issue-coordination-1',
      expectedVersion: version, payload: {complianceId: 'issue-compliance-1', ...payload},
    }, {actor, serverNow: at('2026-08-20T05:00:00Z')});
    return {store, supervisor, operations, service, execute};
  };

  test.each([
    ['charge', {}],
    ['activity', {conditionTypeKey: 'activityRef', conditionRef: 'Crane released', conditionChargeNo: null}],
    ['support', {requestPurposeKey: 'operationsSupport', conditionTypeKey: 'manual',
      conditionChargeNo: null, defermentBasisKey: null, operationsSupportTypeKey: 'craneMovement',
      operationsResourceKey: 'crane', requestedLocation: 'Stand 2'}],
  ])('%s completes the return, retry and acceptance loop without resolving maintenance', async (kind, request) => {
    const {store, operations, supervisor, execute} = await setup(request);
    await execute('acknowledgeCompliance', 1, operations);
    const complete = kind === 'support' ? 'markComplianceComplied' : 'confirmConditionAndReactivate';
    await execute(complete, 2, operations, {note: 'First completion.'}, 'attempt-1');
    await execute('returnComplianceForCorrection', 3, supervisor, {reason: 'Final positioning not complete.'});
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: true, workflowQueueState: 'correctionRequired', isResolved: false,
    });
    await execute(complete, 4, operations, {note: 'Positioning verified.'}, 'attempt-2');
    const receipt = await execute('confirmComplianceClosed', 5, supervisor);
    await expect(execute('confirmComplianceClosed', 5, supervisor)).resolves.toEqual(receipt);
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: false, workflowQueueState: 'released', isResolved: false,
      status: 'acknowledged', acknowledgedByUid: 'mechanical-1',
    });
    expect(store.read('maintenance_workflows/issue-coordination-1').status).toBe('completed');
    expect(store.read('compliance_attempts/issue-compliance-1_1')).toMatchObject({
      accepted: false, returnReason: 'Final positioning not complete.',
    });
    expect(store.read('compliance_attempts/issue-compliance-1_2')).toMatchObject({accepted: true});
  });

  test('custom asset coordination retains the identities required by client workflow decoding', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store, {assetType: 'governedCustom', assetHierarchyRefJson: JSON.stringify({
      assetClassId: 'crane-class', assetInstanceId: 'crane-7', assetNumber: 7,
    })});
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    await new MaintenanceWorkflowCommandService(store).execute(command(), {
      actor: supervisor, serverNow: at('2026-08-20T04:05:00Z'),
    });
    expect(store.read('maintenance_workflows/issue-coordination-1')).toMatchObject({
      assetClassId: 'crane-class', assetInstanceId: 'crane-7', assetTypeKey: 'governedCustom',
    });
  });

  test.each([null, '{}', '{broken', '{"assetNumber":7,"assetClassId":"crane-class"}'])(
    'invalid custom reference %s cannot partially defer a ticket', async (reference) => {
      const store = new MemoryWorkflowStore();
      seedAcknowledgedTicket(store, {assetType: 'governedCustom', assetHierarchyRefJson: reference});
      const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
      const before = store.entries();
      await expect(new MaintenanceWorkflowCommandService(store).execute(command(), {
        actor: supervisor, serverNow: at('2026-08-20T04:05:00Z'),
      })).rejects.toBeDefined();
      expect(store.entries()).toEqual(before);
    },
  );

  test('legacy Mark complied for deferment records the same release evidence as condition confirmation', async () => {
    const {store, operations, execute} = await setup();
    await execute('acknowledgeCompliance', 1, operations);
    await execute('markComplianceComplied', 2, operations, {note: 'Charge 12345 completed.'});
    expect(store.read('compliance_requests/issue-compliance-1')).toMatchObject({
      status: 'complied', dueMarkedByUid: operations.uid,
      becameDueAt: '2026-08-20T05:00:00.000Z',
    });
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({
      workflowDeferred: false, workflowQueueState: 'actionable',
    });
  });

  test.each(['confirmConditionAndReactivate', 'markComplianceComplied'])(
    '%s cannot bypass an undecided revised condition', async (type) => {
      const {store, operations, execute} = await setup();
      await execute('acknowledgeCompliance', 1, operations);
      await execute('proposeCounterCondition', 2, operations, {revisedDescription: 'Wait until crane is available.'});
      const before = store.entries();
      await expect(execute(type, 3, operations, {note: 'Original charge is complete.'}))
        .rejects.toMatchObject({code: 'failed-precondition'});
      expect(store.entries()).toEqual(before);
    },
  );

  test('a late revised-condition decision cannot supersede a complied request', async () => {
    const {store, operations, supervisor, execute} = await setup();
    await execute('confirmConditionAndReactivate', 1, operations, {note: 'Cycle completed.'});
    const path = 'compliance_requests/issue-compliance-1';
    store.seed(path, {...store.read(path), counterProposal: {
      revisedDescription: 'Legacy retained proposal', proposedByUid: operations.uid,
      proposedByName: operations.name,
    }});
    const before = store.entries();
    await expect(execute('decideCounterCondition', 2, supervisor, {
      accepted: true, successorComplianceId: 'late-successor',
    })).rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.entries()).toEqual(before);
  });

  test.each([true, false])('counter decision accepted=%s still allows the correct request to finish', async (accepted) => {
    const {store, operations, supervisor, execute} = await setup();
    await execute('acknowledgeCompliance', 1, operations);
    await execute('proposeCounterCondition', 2, operations, {revisedDescription: 'Verify crane positioning as well.'});
    await execute('decideCounterCondition', 3, supervisor, {
      accepted, successorComplianceId: 'revised-request', note: 'Decision recorded.',
    });
    const complianceId = accepted ? 'revised-request' : 'issue-compliance-1';
    expect(store.read('maintenance_records/ticket-1').workflowComplianceId).toBe(complianceId);
    if (accepted) {
      expect(store.read('compliance_requests/issue-compliance-1').status).toBe('superseded');
      await expect(execute('confirmConditionAndReactivate', 4, operations, {note: 'Old request.'}, 'old-request'))
        .rejects.toMatchObject({code: 'failed-precondition'});
    }
    await execute('confirmConditionAndReactivate', 4, operations, {complianceId, note: 'Agreed release verified.'});
    await execute('confirmComplianceClosed', 5, supervisor, {complianceId});
    expect(store.read(`compliance_requests/${complianceId}`).status).toBe('confirmedClosed');
    expect(store.read('maintenance_records/ticket-1')).toMatchObject({workflowDeferred: false, workflowQueueState: 'released'});
  });

  test('an exact start replay succeeds but another stale phone cannot create a second hold', async () => {
    const {store, supervisor, service} = await setup();
    await expect(service.execute(command(), {actor: supervisor, serverNow: at('2026-08-20T04:05:00Z')}))
      .resolves.toMatchObject({resultKey: 'issue-coordination-started', aggregateVersion: 1});
    const next = command({complianceId: 'second-request'});
    next.commandId = 'second-start';
    next.aggregateId = 'second-workflow';
    const before = store.entries();
    await expect(service.execute(next, {actor: supervisor, serverNow: at('2026-08-20T04:06:00Z')}))
      .rejects.toMatchObject({code: 'aborted', details: {reasonCode: 'issue-coordination-ticket-version-changed'}});
    expect(store.entries()).toEqual(before);
  });

  test('a completed accountable lane cannot start a fresh deferment', async () => {
    const {store, supervisor, service} = await setup();
    seedAcknowledgedTicket(store, {
      status: 'inProgress', issueAssignedLanes: ['mechanical', 'electrical'],
      issueAcknowledgedLanes: ['mechanical', 'electrical'], issueCompletedLanes: ['mechanical'],
      issueLaneSchemaVersion: 1, issueLaneRevision: 1,
      issueLaneCompletionEvidence: {mechanical: {
        completedByUid: 'mechanical-1', completedByName: 'Mechanical',
        completedAt: '2026-08-20T04:02:00.000Z',
      }},
    });
    store.seed('compliance_requests/issue-compliance-1', {
      ...store.read('compliance_requests/issue-compliance-1'), status: 'confirmedClosed',
    });
    const start = command({originRoute: 'mechanical', complianceId: 'new-compliance'});
    start.commandId = 'new-coordination';
    start.aggregateId = 'new-workflow';
    const before = store.entries();
    await expect(service.execute(start, {actor: supervisor, serverNow: at('2026-08-20T05:05:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.entries()).toEqual(before);
  });

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
        ticketVersion: 4,
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

  test('accepts acknowledgedAt in the Firestore persisted timestamp shape', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store, {
      acknowledgedAt: {
        _seconds: Math.floor(at('2026-08-20T04:00:00Z').getTime() / 1000),
        _nanoseconds: 0,
      },
    });
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(command(), {
      actor: supervisor,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).resolves.toMatchObject({
      resultKey: 'issue-coordination-started',
      aggregateVersion: 1,
    });
  });

  test('rejects a malformed persisted acknowledgement timestamp', async () => {
    const store = new MemoryWorkflowStore();
    seedAcknowledgedTicket(store, {
      acknowledgedAt: {_seconds: Number.MAX_SAFE_INTEGER, _nanoseconds: 0},
    });
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(command(), {
      actor: supervisor,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'issue-coordination-ticket-not-acknowledged'},
    });
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
