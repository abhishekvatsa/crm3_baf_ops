const {
  mutateOperationalEventWithDb,
  parseOperationalEventMutationRequest,
  userCanMutateOperationalEvent,
} = require('../lib/operationalEventMutation');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {id, path, async get() { return snapshot(path, id); }};
  }

  return {
    store,
    writes,
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); }};
      },
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(documentRef) {
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({path: documentRef.path, data: clone(data)});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
      },
    },
  };
}

const IDS = {
  event: '11111111-1111-4111-8111-111111111111',
  create: '22222222-2222-4222-8222-222222222222',
  update: '33333333-3333-4333-8333-333333333333',
  resolve: '44444444-4444-4444-8444-444444444444',
  reopen: '55555555-5555-4555-8555-555555555555',
  asset: '66666666-6666-4666-8666-666666666666',
  assetClass: '77777777-7777-4777-8777-777777777777',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function request(overrides = {}) {
  return {
    requestId: IDS.create,
    operation: 'CREATE_OPERATIONAL_EVENT',
    eventId: IDS.event,
    expectedVersion: 0,
    reason: 'Record a plant utility interruption for coordinated response.',
    eventDraft: {
      eventType: 'powerTrip',
      title: 'Incoming power interruption',
      description: 'Incoming supply was lost across the annealing shop.',
      severity: 'critical',
      scope: 'plantWide',
      affectedAssetClassIds: [],
      affectedAssetInstanceIds: [],
      startedAt: '2026-08-14T10:00:00.000Z',
    },
    ...overrides,
  };
}

function persistedEvent(overrides = {}) {
  return {
    schemaVersion: 1,
    eventId: IDS.event,
    eventType: 'powerTrip',
    title: 'Incoming power interruption',
    description: 'Incoming supply was lost across the annealing shop.',
    severity: 'critical',
    scope: 'plantWide',
    affectedAssetClassIds: [],
    affectedAssetInstanceIds: [],
    completedIntervals: [],
    startedAt: new Date('2026-08-14T10:00:00.000Z'),
    status: 'open',
    createdAt: new Date('2026-08-14T10:05:00.000Z'),
    createdByUid: 'ops-1',
    createdByName: 'Operations One',
    resolvedAt: null,
    resolvedByUid: null,
    resolvedByName: null,
    resolutionNote: null,
    version: 1,
    updatedAt: new Date('2026-08-14T10:05:00.000Z'),
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    lastMutationId: IDS.create,
    ...overrides,
  };
}

function baseSeed() {
  return {
    'users/ops-1': user('operations', 'Operations One'),
    'users/contract-1': user('contractSupervisor', 'Contract Supervisor'),
    'users/admin-1': user('admin', 'Admin One'),
    [`asset_classes/${IDS.assetClass}`]: {
      schemaVersion: 1,
      assetClassId: IDS.assetClass,
      name: 'Furnace',
      status: 'active',
      version: 1,
    },
    [`asset_instances/${IDS.asset}`]: {
      schemaVersion: 1,
      assetInstanceId: IDS.asset,
      assetClassId: IDS.assetClass,
      assetNumber: 7,
      name: 'Furnace 7',
      status: 'active',
      version: 1,
    },
  };
}

async function invoke(
  memory,
  authUid,
  data,
  now = new Date('2026-08-14T12:00:00.000Z'),
) {
  return mutateOperationalEventWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => now,
    timestampFromDate: (date) => date,
  });
}

describe('operational event mutation', () => {
  test('parses bounded scope and rejects unsupported fields', () => {
    expect(parseOperationalEventMutationRequest(request()))
      .toMatchObject({eventId: IDS.event, expectedVersion: 0});
    expect(() => parseOperationalEventMutationRequest({
      ...request(),
      surprise: true,
    })).toThrow('surprise is unsupported');
    expect(() => parseOperationalEventMutationRequest(request({
      eventDraft: {...request().eventDraft, affectedAssetClassIds: [IDS.assetClass]},
    }))).toThrow('plant-wide scope cannot name specific assets');
  });

  test('contract supervisors can record but cannot resolve plant events', () => {
    expect(userCanMutateOperationalEvent(
      user('contractSupervisor'),
      'CREATE_OPERATIONAL_EVENT',
    )).toBe(true);
    expect(userCanMutateOperationalEvent(
      user('contractSupervisor'),
      'RESOLVE_OPERATIONAL_EVENT',
    )).toBe(false);
    expect(userCanMutateOperationalEvent(
      user('operations'),
      'RESOLVE_OPERATIONAL_EVENT',
    )).toBe(true);
  });

  test('creates an event with deterministic audit and receipt evidence', async () => {
    const memory = fakeDb(baseSeed());
    const result = await invoke(memory, 'ops-1', request());
    expect(result).toMatchObject({
      ok: true,
      eventId: IDS.event,
      status: 'open',
      version: 1,
      idempotentReplay: false,
    });
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      eventType: 'powerTrip',
      completedIntervals: [],
      status: 'open',
      version: 1,
      lastMutationId: IDS.create,
    });
    expect(memory.store.get(
      `operational_event_audits/operational_event_${IDS.create}`,
    )).toMatchObject({requestId: IDS.create, before: null});
    expect(memory.store.get(
      `operational_event_receipts/${IDS.create}`,
    )).toMatchObject({eventId: IDS.event, status: 'open'});

    const writesBeforeReplay = memory.writes.length;
    const replay = await invoke(memory, 'ops-1', request());
    expect(replay.idempotentReplay).toBe(true);
    expect(memory.writes).toHaveLength(writesBeforeReplay);
  });

  test('validates selected asset identity before creating scoped event', async () => {
    const memory = fakeDb(baseSeed());
    const scoped = request({
      eventDraft: {
        ...request().eventDraft,
        scope: 'assets',
        affectedAssetClassIds: [IDS.assetClass],
        affectedAssetInstanceIds: [IDS.asset],
      },
    });
    await expect(invoke(memory, 'contract-1', scoped)).resolves.toMatchObject({
      status: 'open',
    });
  });

  test('future event chronology is rejected without writes', async () => {
    const createMemory = fakeDb(baseSeed());
    await expect(invoke(createMemory, 'ops-1', request({
      eventDraft: {
        ...request().eventDraft,
        startedAt: '2026-08-14T13:00:00.000Z',
      },
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-started-at-future'},
    });
    expect(createMemory.writes).toHaveLength(0);

    const future = persistedEvent();
    future.startedAt = new Date('2026-08-14T13:00:00.000Z');
    const resolveMemory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: future,
    });
    await expect(invoke(resolveMemory, 'ops-1', {
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Attempt closure after checking the event chronology.',
      resolutionNote: 'Supply remained stable through verification.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-started-at-future'},
    });
    expect(resolveMemory.writes).toHaveLength(0);
  });

  test('audit snapshots preserve every corrected operational field', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: persistedEvent(),
    });
    await invoke(memory, 'ops-1', {
      requestId: IDS.update,
      operation: 'UPDATE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Correct the event timing and operational impact after review.',
      eventDraft: {
        ...request().eventDraft,
        description: 'Incoming power remained unstable across the BAF shop.',
        startedAt: '2026-08-14T09:45:00.000Z',
      },
    });
    expect(memory.store.get(
      `operational_event_audits/operational_event_${IDS.update}`,
    )).toMatchObject({
      before: {
        description: 'Incoming supply was lost across the annealing shop.',
        startedAt: new Date('2026-08-14T10:00:00.000Z'),
      },
      after: {
        description: 'Incoming power remained unstable across the BAF shop.',
        startedAt: new Date('2026-08-14T09:45:00.000Z'),
      },
    });
  });

  test('resolves and reopens with supervisory evidence', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: persistedEvent(),
    });
    const resolved = await invoke(memory, 'ops-1', {
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm restoration after stable utility observation.',
      resolutionNote: 'Incoming supply remained stable through verification.',
    });
    expect(resolved).toMatchObject({status: 'resolved', version: 2});
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      status: 'resolved',
      resolvedByUid: 'ops-1',
      version: 2,
    });

    const reopened = await invoke(
      memory,
      'admin-1',
      {
        requestId: IDS.reopen,
        operation: 'REOPEN_OPERATIONAL_EVENT',
        eventId: IDS.event,
        expectedVersion: 2,
        reason: 'Power instability recurred during post-restoration monitoring.',
      },
      new Date('2026-08-14T13:00:00.000Z'),
    );
    expect(reopened).toMatchObject({status: 'open', version: 3});
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      status: 'open',
      completedIntervals: [{
        startedAt: new Date('2026-08-14T10:00:00.000Z'),
        resolvedAt: new Date('2026-08-14T12:00:00.000Z'),
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
        resolvedByUid: 'ops-1',
        resolvedByName: 'Operations One',
        resolutionNote: 'Incoming supply remained stable through verification.',
      }],
      startedAt: new Date('2026-08-14T13:00:00.000Z'),
      resolvedAt: null,
      resolutionNote: null,
    });
    expect(memory.store.get(
      `operational_event_audits/operational_event_${IDS.reopen}`,
    )).toMatchObject({
      before: {
        resolvedByUid: 'ops-1',
        resolutionNote: 'Incoming supply remained stable through verification.',
      },
      after: {
        completedIntervals: [{
          startedAt: new Date('2026-08-14T10:00:00.000Z'),
          resolvedAt: new Date('2026-08-14T12:00:00.000Z'),
          scope: 'plantWide',
          affectedAssetClassIds: [],
          affectedAssetInstanceIds: [],
          resolvedByUid: 'ops-1',
          resolvedByName: 'Operations One',
          resolutionNote: 'Incoming supply remained stable through verification.',
        }],
        startedAt: new Date('2026-08-14T13:00:00.000Z'),
        resolvedAt: null,
        resolvedByUid: null,
        resolvedByName: null,
        resolutionNote: null,
      },
    });

    await invoke(memory, 'ops-1', request({
      requestId: IDS.update,
      operation: 'UPDATE_OPERATIONAL_EVENT',
      expectedVersion: 3,
      reason: 'Limit the recurring interruption to the affected furnace.',
      eventDraft: {
        ...request().eventDraft,
        scope: 'assets',
        affectedAssetClassIds: [IDS.assetClass],
        affectedAssetInstanceIds: [IDS.asset],
        startedAt: '2026-08-14T13:00:00.000Z',
      },
    }), new Date('2026-08-14T13:30:00.000Z'));
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      scope: 'assets',
      affectedAssetInstanceIds: [IDS.asset],
      completedIntervals: [{
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
        resolvedByUid: 'ops-1',
        resolvedByName: 'Operations One',
        resolutionNote: 'Incoming supply remained stable through verification.',
      }],
    });
  });

  test('fails closed on an incomplete persisted event', async () => {
    const malformed = persistedEvent();
    delete malformed.affectedAssetClassIds;
    const memory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: malformed,
    });
    await expect(invoke(memory, 'ops-1', {
      requestId: IDS.update,
      operation: 'UPDATE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Correct the operational event after field confirmation.',
      eventDraft: request().eventDraft,
    })).rejects.toMatchObject({
      details: {reasonCode: 'operational-event-projection-malformed'},
    });
    expect(memory.writes).toHaveLength(0);

    for (const field of [
      'affectedAssetClassIds',
      'affectedAssetInstanceIds',
      'completedIntervals',
    ]) {
      const invalid = persistedEvent({[field]: null});
      const invalidMemory = fakeDb({
        ...baseSeed(),
        [`operational_events/${IDS.event}`]: invalid,
      });
      await expect(invoke(invalidMemory, 'ops-1', {
        requestId: IDS.update,
        operation: 'UPDATE_OPERATIONAL_EVENT',
        eventId: IDS.event,
        expectedVersion: 1,
        reason: 'Correct the operational event after field confirmation.',
        eventDraft: request().eventDraft,
      })).rejects.toMatchObject({
        details: {reasonCode: 'operational-event-projection-malformed'},
      });
      expect(invalidMemory.writes).toHaveLength(0);
    }

    const incompleteHistory = persistedEvent({
      completedIntervals: [{
        startedAt: new Date('2026-08-14T08:00:00.000Z'),
        resolvedAt: new Date('2026-08-14T09:00:00.000Z'),
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
      }],
    });
    const incompleteHistoryMemory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: incompleteHistory,
    });
    await expect(invoke(incompleteHistoryMemory, 'ops-1', {
      requestId: IDS.update,
      operation: 'UPDATE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Correct the operational event after field confirmation.',
      eventDraft: request().eventDraft,
    })).rejects.toMatchObject({
      details: {reasonCode: 'operational-event-projection-malformed'},
    });
    expect(incompleteHistoryMemory.writes).toHaveLength(0);
  });
});
