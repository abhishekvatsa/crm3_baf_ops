const {createHash} = require('crypto');

const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  payloadFingerprint,
  stableJson,
} = require('../lib/maintenanceWorkflow/utils');

const at = (value) => new Date(value);
const staleAdmin = {
  uid: 'admin-a',
  name: 'Stale Admin',
  roles: new Set(['admin']),
};
const otherAdmin = {
  uid: 'admin-b',
  name: 'Other Admin',
  roles: new Set(['admin']),
};

function seedUser(store, actor, {isApproved = true, roles = [...actor.roles]} = {}) {
  store.seed(`users/${actor.uid}`, {
    isApproved,
    roles,
    name: actor.name,
  });
}

function seedPendingWorkflow(store, id = 'wf-replay') {
  store.seed(`maintenance_workflows/${id}`, {
    jobExecutionId: `${id}-exec`,
    status: 'pendingLaneClassification',
    version: 0,
    assetTypeKey: 'furnace',
    assetNumber: 7,
    laneSetFinalizedAt: null,
    cancelled: false,
  });
  store.seed(`job_executions/${id}-exec`, {
    version: 1,
    isCompleted: false,
  });
}

function finalizeCommand(id = 'workflow-replay-command') {
  return {
    commandId: id,
    commandType: 'finalizeLaneSet',
    aggregateId: 'wf-replay',
    expectedVersion: 0,
    payload: {laneKeys: ['elec']},
  };
}

describe('maintenance workflow transaction authority and replay integrity', () => {
  test.each([
    ['revoked', {isApproved: false, roles: ['admin']}],
    ['role-narrowed', {isApproved: true, roles: ['operations']}],
  ])('stale preflight actor fails closed when transaction authority is %s', async (_label, authority) => {
    const store = new MemoryWorkflowStore();
    seedPendingWorkflow(store);
    seedUser(store, staleAdmin, authority);
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(finalizeCommand(), {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:00:00Z'),
    })).rejects.toMatchObject({
      code: 'permission-denied',
    });

    expect(store.read('maintenance_workflows/wf-replay')).toMatchObject({
      status: 'pendingLaneClassification',
      version: 0,
    });
    expect(store.read(
      'maintenance_workflow_command_receipts/workflow-replay-command',
    )).toBeNull();
  });

  test('new receipt is owner-bound, semantic, versioned and SHA-256 fingerprinted', async () => {
    const store = new MemoryWorkflowStore();
    seedPendingWorkflow(store);
    seedUser(store, staleAdmin);
    const service = new MaintenanceWorkflowCommandService(store);
    const command = finalizeCommand();

    const response = await service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:10:00Z'),
    });
    const stored = store.read(
      'maintenance_workflow_command_receipts/workflow-replay-command',
    );

    expect(response).toEqual({
      commandId: 'workflow-replay-command',
      resultKey: 'lane-set-finalized',
      aggregateVersion: 1,
      result: expect.objectContaining({laneKeys: ['elec']}),
      appliedAt: '2026-07-26T08:10:00.000Z',
    });
    expect(stored).toMatchObject({
      receiptSchemaVersion: 2,
      commandId: command.commandId,
      commandType: command.commandType,
      aggregateId: command.aggregateId,
      actorUid: staleAdmin.uid,
      authorityScope: {
        schemaVersion: 1,
        capability: 'laneSet.finalize',
      },
      payloadFingerprint: expect.stringMatching(/^sha256:[0-9a-f]{64}$/),
    });
    expect(stored).not.toHaveProperty('payloadHash');
  });

  test('exact replay is denied after the owner loses the command capability', async () => {
    const store = new MemoryWorkflowStore();
    seedPendingWorkflow(store);
    seedUser(store, staleAdmin);
    const service = new MaintenanceWorkflowCommandService(store);
    const command = finalizeCommand();
    const first = await service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:20:00Z'),
    });

    seedUser(store, staleAdmin, {
      isApproved: true,
      roles: ['operations'],
    });
    await expect(service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:21:00Z'),
    })).rejects.toMatchObject({
      code: 'permission-denied',
    });

    expect(store.read('maintenance_workflows/wf-replay')).toMatchObject({
      version: first.aggregateVersion,
    });
  });

  test('same owner cannot reuse a command ID with a different payload', async () => {
    const store = new MemoryWorkflowStore();
    seedPendingWorkflow(store);
    seedUser(store, staleAdmin);
    const service = new MaintenanceWorkflowCommandService(store);
    const command = finalizeCommand();
    await service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:25:00Z'),
    });

    await expect(service.execute({
      ...command,
      payload: {laneKeys: ['mech']},
    }, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:26:00Z'),
    })).rejects.toMatchObject({
      code: 'command-idempotency-conflict',
    });

    expect(store.read('maintenance_workflows/wf-replay')).toMatchObject({
      version: 1,
    });
  });

  test('cross-actor owner rejection precedes payload fingerprint comparison', async () => {
    const store = new MemoryWorkflowStore();
    seedPendingWorkflow(store);
    seedUser(store, staleAdmin);
    seedUser(store, otherAdmin);
    const service = new MaintenanceWorkflowCommandService(store);
    const command = finalizeCommand();
    await service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:30:00Z'),
    });

    for (const replay of [
      command,
      {...command, payload: {laneKeys: ['mech']}},
    ]) {
      await expect(service.execute(replay, {
        actor: otherAdmin,
        serverNow: at('2026-07-26T08:31:00Z'),
      })).rejects.toMatchObject({
        code: 'permission-denied',
        details: {
          reasonCode: 'workflow-receipt-owner-mismatch',
        },
      });
    }
  });

  test('document-derived replay uses immutable semantic scope without rereading deleted business state', async () => {
    const store = new MemoryWorkflowStore();
    const command = {
      commandId: 'compliance-replay',
      commandType: 'acknowledgeCompliance',
      aggregateId: 'wf-compliance',
      expectedVersion: 4,
      payload: {complianceId: 'compliance-deleted-after-commit'},
    };
    const operations = {
      uid: 'operations-a',
      name: 'Operations',
      roles: new Set(['operations']),
    };
    seedUser(store, operations);
    store.seed(
      'maintenance_workflow_command_receipts/compliance-replay',
      {
        receiptSchemaVersion: 2,
        commandId: command.commandId,
        commandType: command.commandType,
        aggregateId: command.aggregateId,
        actorUid: operations.uid,
        authorityScope: {
          schemaVersion: 1,
          capability: 'lane.work',
          laneKey: 'oprn',
        },
        payloadFingerprint: payloadFingerprint(command),
        resultKey: 'compliance-acknowledged',
        aggregateVersion: 5,
        result: {complianceId: command.payload.complianceId},
        appliedAt: '2026-07-26T08:40:00.000Z',
      },
    );
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(command, {
      actor: operations,
      serverNow: at('2026-07-26T08:41:00Z'),
    })).resolves.toMatchObject({
      resultKey: 'compliance-acknowledged',
      aggregateVersion: 5,
    });

    seedUser(store, operations, {
      isApproved: true,
      roles: ['seniorElectrical'],
    });
    await expect(service.execute(command, {
      actor: operations,
      serverNow: at('2026-07-26T08:42:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('legacy unversioned receipts fail closed for governed reconciliation', async () => {
    const store = new MemoryWorkflowStore();
    seedUser(store, staleAdmin);
    const command = finalizeCommand('legacy-receipt');
    store.seed(
      'maintenance_workflow_command_receipts/legacy-receipt',
      {
        commandId: command.commandId,
        payloadHash: '8d4096998601ec8c',
        resultKey: 'lane-set-finalized',
        aggregateVersion: 1,
        result: {},
        appliedAt: '2026-07-20T00:00:00.000Z',
      },
    );
    const service = new MaintenanceWorkflowCommandService(store);

    await expect(service.execute(command, {
      actor: staleAdmin,
      serverNow: at('2026-07-26T08:50:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'legacy-workflow-receipt-reconciliation-required',
      },
    });
  });

  test('fingerprint is canonical SHA-256 over UTF-8 stable JSON', () => {
    const left = {z: 'évidence', a: {two: 2, one: 1}};
    const right = {a: {one: 1, two: 2}, z: 'évidence'};
    const expected = `sha256:${createHash('sha256')
      .update(stableJson(left), 'utf8')
      .digest('hex')}`;

    expect(payloadFingerprint(left)).toBe(expected);
    expect(payloadFingerprint(right)).toBe(expected);
  });
});
