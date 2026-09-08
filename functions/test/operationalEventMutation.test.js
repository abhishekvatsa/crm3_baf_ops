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
  const controls = {beforeCommit: null};

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
    controls,
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); }};
      },
      async runTransaction(fn) {
        // Retry on a changed read, like Firestore's optimistic transaction.
        // This also exercises accepted/rejected contention on one receipt.
        for (let attempt = 0; attempt < 20; attempt++) {
        const staged = [];
        const reads = new Map();
        const transaction = {
          async get(documentRef) {
            reads.set(documentRef.path, JSON.stringify(store.get(documentRef.path)));
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({path: documentRef.path, data: clone(data)});
          },
        };
        const result = await fn(transaction);
        if (controls.beforeCommit != null) await controls.beforeCommit(staged);
        if ([...reads].some(([path, value]) =>
          JSON.stringify(store.get(path)) !== value)) continue;
        for (const write of staged) {
          store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
        }
        throw new Error('Fake transaction retry limit exceeded.');
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
  otherAssetClass: '88888888-8888-4888-8888-888888888888',
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
    [`asset_classes/${IDS.otherAssetClass}`]: {
      schemaVersion: 1,
      assetClassId: IDS.otherAssetClass,
      name: 'Base',
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
  const scopedCreate = () => request({eventDraft: {
    ...request().eventDraft,
    scope: 'assets',
    affectedAssetClassIds: [IDS.assetClass],
    affectedAssetInstanceIds: [IDS.asset],
  }});

  test.each(['retired asset', 'missing asset', 'retired class', 'missing class'])(
    'create commits a terminal receipt for %s before returning its error', async (kind) => {
      const seed = baseSeed();
      const path = kind.includes('class') ? `asset_classes/${IDS.assetClass}` :
        `asset_instances/${IDS.asset}`;
      if (kind.startsWith('missing')) delete seed[path];
      else seed[path].status = 'retired';
      const memory = fakeDb(seed);
      const input = scopedCreate();
      const error = await invoke(memory, 'ops-1', input).catch((value) => value);
      expect(error.code).toBe(kind.startsWith('missing') ? 'not-found' : 'failed-precondition');
      expect(error.details.terminalRejection).toEqual({
        schemaVersion: 1, outcome: 'rejected', requestId: IDS.create,
        eventId: IDS.event, actorUid: 'ops-1', operation: 'CREATE_OPERATIONAL_EVENT',
        fingerprint: parseOperationalEventMutationRequest(input).fingerprint,
        committedAt: '2026-08-14T12:00:00.000Z',
      });
      const receiptPath = `operational_event_receipts/${IDS.create}`;
      expect(memory.store.get(receiptPath)).toMatchObject({outcome: 'rejected'});
      expect(memory.writes.map((write) => write.path)).toEqual([receiptPath]);
      // A lost error response and a later asset restoration cannot resurrect A.
      memory.store.set(path, baseSeed()[path]);
      const replay = await invoke(memory, 'ops-1', input,
        new Date('2026-08-15T12:00:00.000Z')).catch((value) => value);
      expect(replay.code).toBe(error.code);
      expect(replay.details).toEqual(error.details);
      expect(memory.writes).toHaveLength(1);
      expect(memory.store.has(`operational_events/${IDS.event}`)).toBe(false);
      // A genuinely new corrected intent remains possible.
      await expect(invoke(memory, 'ops-1', {...input,
        requestId: IDS.update, eventId: IDS.resolve})).resolves.toMatchObject({ok: true});
    },
  );

  test('concurrent rejected retries commit one terminal outcome', async () => {
    const seed = baseSeed();
    seed[`asset_instances/${IDS.asset}`].status = 'retired';
    const memory = fakeDb(seed);
    const errors = await Promise.all(Array.from({length: 8}, () =>
      invoke(memory, 'ops-1', scopedCreate()).catch((error) => error)));
    expect(memory.writes).toHaveLength(1);
    expect(errors.every((error) => error.code === 'failed-precondition')).toBe(true);
    expect(new Set(errors.map((error) => JSON.stringify(error.details))).size).toBe(1);
  });

  test.each(['accepted', 'rejected'])(
    'an in-flight %s attempt cannot overwrite the other committed outcome', async (firstOutcome) => {
      const seed = baseSeed();
      if (firstOutcome === 'rejected') seed[`asset_instances/${IDS.asset}`].status = 'retired';
      const memory = fakeDb(seed);
      let releaseFirst;
      let firstStaged;
      const blocked = new Promise((resolve) => { releaseFirst = resolve; });
      const staged = new Promise((resolve) => { firstStaged = resolve; });
      let blockedOnce = false;
      memory.controls.beforeCommit = async (writes) => {
        if (!blockedOnce && writes.length > 0) {
          blockedOnce = true;
          firstStaged();
          await blocked;
        }
      };
      const firstAttempt = invoke(memory, 'ops-1', scopedCreate()).catch((error) => error);
      await staged;
      memory.store.get(`asset_instances/${IDS.asset}`).status =
        firstOutcome === 'accepted' ? 'retired' : 'active';
      const winner = await invoke(memory, 'ops-1', scopedCreate()).catch((error) => error);
      releaseFirst();
      const loser = await firstAttempt;
      if (firstOutcome === 'accepted') {
        expect(winner.code).toBe('failed-precondition');
        expect(loser.details).toEqual(winner.details);
        expect(memory.writes).toHaveLength(1);
        expect(memory.store.has(`operational_events/${IDS.event}`)).toBe(false);
      } else {
        expect(winner.ok).toBe(true);
        expect(loser).toEqual({...winner, idempotentReplay: true});
        expect(memory.writes).toHaveLength(3);
      }
    },
  );

  test('an accepted receipt wins over a subsequently retired target', async () => {
    const memory = fakeDb(baseSeed());
    const accepted = await invoke(memory, 'ops-1', scopedCreate());
    memory.store.get(`asset_instances/${IDS.asset}`).status = 'retired';
    expect(await invoke(memory, 'ops-1', scopedCreate()))
      .toEqual({...accepted, idempotentReplay: true});
    expect(memory.writes).toHaveLength(3);
  });

  test('CREATE actor guard stops a callable authenticated as a changed account', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(memory, 'admin-1', request({expectedActorUid: 'ops-1'})))
      .rejects.toMatchObject({code: 'permission-denied',
        details: {reasonCode: 'operational-event-actor-mismatch'}});
    expect(memory.writes).toHaveLength(0);
    await expect(invoke(memory, 'ops-1', request({expectedActorUid: 'ops-1'})))
      .resolves.toMatchObject({ok: true});
  });

  test('actor guard can be added when retrying a legacy accepted CREATE', async () => {
    const memory = fakeDb(baseSeed());
    const accepted = await invoke(memory, 'ops-1', request());
    expect(await invoke(memory, 'ops-1', request({expectedActorUid: 'ops-1'})))
      .toEqual({...accepted, idempotentReplay: true});
    expect(memory.writes).toHaveLength(3);
  });

  test('CREATE fingerprint matches the client golden normalization fixture', () => {
    const parsed = parseOperationalEventMutationRequest(request({
      reason: '  Record affected equipment.  ',
      eventDraft: {...request().eventDraft, title: '  Power interruption  ',
        description: '  Supply lost.  ', scope: 'assets',
        affectedAssetClassIds: ['z-class', 'a-class'],
        affectedAssetInstanceIds: ['z-asset', 'a-asset']},
    }));
    expect(parsed.fingerprint).toBe(
      'operationalevent1-sha256:dd617524615b87af9537a844f02d8ad7d5d5463c501ccb9f5cfcaddd9f3d0c4b');
  });

  test.each([
    ['actorUid', 'admin-1'], ['fingerprint', 'changed'], ['eventId', IDS.resolve],
    ['requestId', IDS.update], ['operation', 'UPDATE_OPERATIONAL_EVENT'],
    ['committedAtIso', 'invalid'], ['outcome', 'accepted'], ['schemaVersion', 2],
    ['rejectionCode', 'unavailable'], ['rejectionMessage', 'changed'],
    ['rejectionDetails', {reasonCode: 'operational-event-asset-invalid', assetId: 'unrelated'}],
    ['committedAt', new Date('2026-08-15T12:00:00.000Z')],
  ])('malformed terminal receipt fails closed: %s', async (field, value) => {
    const seed = baseSeed();
    seed[`asset_instances/${IDS.asset}`].status = 'retired';
    const memory = fakeDb(seed);
    await invoke(memory, 'ops-1', scopedCreate()).catch(() => {});
    const path = `operational_event_receipts/${IDS.create}`;
    expect(memory.store.has(path)).toBe(true);
    memory.store.set(path, {...memory.store.get(path), [field]: value});
    await expect(invoke(memory, 'ops-1', scopedCreate())).rejects.toMatchObject({code: 'data-loss'});
    expect(memory.writes).toHaveLength(1);
  });

  test('a rejected identity cannot be reused by another actor or edited payload', async () => {
    const seed = baseSeed();
    seed[`asset_instances/${IDS.asset}`].status = 'retired';
    const memory = fakeDb(seed);
    await invoke(memory, 'ops-1', scopedCreate()).catch(() => {});
    await expect(invoke(memory, 'admin-1', scopedCreate())).rejects.toMatchObject({code: 'data-loss'});
    await expect(invoke(memory, 'ops-1', {...scopedCreate(), reason: 'A different intent'}))
      .rejects.toMatchObject({code: 'data-loss'});
    expect(memory.writes).toHaveLength(1);
  });

  test('asset reclassification after form entry terminally rejects the old class selection', async () => {
    const memory = fakeDb(baseSeed());
    memory.store.get(`asset_instances/${IDS.asset}`).assetClassId = IDS.otherAssetClass;
    const rejected = await invoke(memory, 'ops-1', scopedCreate()).catch((error) => error);
    expect(rejected.details).toMatchObject({
      reasonCode: 'operational-event-asset-class-mismatch',
      terminalRejection: {requestId: IDS.create, eventId: IDS.event, outcome: 'rejected'},
    });
    expect(memory.writes.map((write) => write.path))
      .toEqual([`operational_event_receipts/${IDS.create}`]);
    memory.store.get(`asset_instances/${IDS.asset}`).assetClassId = IDS.assetClass;
    const replay = await invoke(memory, 'ops-1', scopedCreate()).catch((error) => error);
    expect(replay.details).toEqual(rejected.details);
    expect(memory.writes).toHaveLength(1);
  });

  test('historical acceptance remains readable with missing current event', async () => {
    const memory = fakeDb(baseSeed());
    const first = await invoke(memory, 'ops-1', request());
    memory.store.delete(`operational_events/${IDS.event}`);
    const writes = memory.writes.length;
    expect(await invoke(memory, 'ops-1', request()))
      .toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writes);
    expect(memory.store.has(`operational_events/${IDS.event}`)).toBe(false);
  });

  test.each([
    ['receipt request', 'receipt', {requestId: IDS.update}],
    ['receipt actor', 'receipt', {actorUid: 'admin-1'}],
    ['receipt payload', 'receipt', {fingerprint: 'changed'}],
    ['receipt version', 'receipt', {version: 0}],
    ['receipt audit', 'receipt', {auditId: 'unrelated'}],
    ['receipt time', 'receipt', {committedAtIso: 'not-a-time'}],
    ['audit identity', 'audit', {auditId: 'unrelated'}],
    ['audit operation', 'audit', {operation: 'RESOLVE_OPERATIONAL_EVENT'}],
    ['audit after', 'audit', {after: {eventId: IDS.event, version: 1, status: 'resolved'}}],
  ])('rejects corrupted immutable %s instead of certifying acceptance', async (_, kind, patch) => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'ops-1', request());
    const path = kind === 'receipt'
      ? `operational_event_receipts/${IDS.create}`
      : `operational_event_audits/operational_event_${IDS.create}`;
    memory.store.set(path, {...memory.store.get(path), ...patch});
    const writes = memory.writes.length;
    await expect(invoke(memory, 'ops-1', request()))
      .rejects.toMatchObject({code: 'data-loss'});
    expect(memory.writes).toHaveLength(writes);
  });

  test('receipt replay still checks current account authority and actor identity', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'ops-1', request());
    await expect(invoke(memory, 'admin-1', request()))
      .rejects.toMatchObject({code: 'data-loss'});
    memory.store.set('users/ops-1', {...user('operations'), isApproved: false});
    await expect(invoke(memory, 'ops-1', request()))
      .rejects.toMatchObject({code: 'permission-denied'});
  });

  test('replaying creation after resolution confirms history without reopening the event', async () => {
    const memory = fakeDb(baseSeed());
    const first = await invoke(memory, 'ops-1', request());
    await invoke(memory, 'ops-1', {
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm supply was restored.',
      resolutionNote: 'Supply remained stable after restoration.',
    });
    const beforeReplay = clone([...memory.store]);
    const writesBeforeReplay = memory.writes.length;

    const replay = await invoke(memory, 'ops-1', request());

    expect(replay).toEqual({...first, idempotentReplay: true});
    expect([...memory.store]).toEqual(beforeReplay);
    expect(memory.writes).toHaveLength(writesBeforeReplay);
    expect(memory.store.get(`operational_events/${IDS.event}`))
      .toMatchObject({status: 'resolved', version: 2});
  });

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

    const legacyResolve = parseOperationalEventMutationRequest({
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm that the disruption has ended.',
      resolutionNote: 'Supply remained stable through verification.',
    });
    expect(legacyResolve.resolvedAtIso).toBeNull();
    expect(legacyResolve.fingerprint).toMatch(/^operationalevent1-sha256:/);

    const timedResolve = parseOperationalEventMutationRequest({
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm that the disruption has ended.',
      resolutionNote: 'Supply remained stable through verification.',
      resolvedAt: '2026-08-14T11:45:00.000Z',
    });
    expect(timedResolve.resolvedAtIso).toBe('2026-08-14T11:45:00.000Z');
    expect(timedResolve.fingerprint).toMatch(/^operationalevent2-sha256:/);
    expect(() => parseOperationalEventMutationRequest({
      ...request(),
      resolvedAt: '2026-08-14T11:45:00.000Z',
    })).toThrow('resolvedAt is not allowed');
    expect(() => parseOperationalEventMutationRequest({
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm that the disruption has ended.',
      resolutionNote: 'Supply remained stable through verification.',
      resolvedAt: '14 Aug 2026 11:45',
    })).toThrow('resolvedAt must be a canonical UTC instant');
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

  test('requires exact class metadata for asset-scoped events', async () => {
    const scopedDraft = {
      ...request().eventDraft,
      scope: 'assets',
      affectedAssetInstanceIds: [IDS.asset],
    };
    const missingMemory = fakeDb(baseSeed());
    await expect(invoke(missingMemory, 'contract-1', request({
      eventDraft: {...scopedDraft, affectedAssetClassIds: []},
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-asset-class-mismatch'},
    });
    expect(missingMemory.writes.map((write) => write.path))
      .toEqual([`operational_event_receipts/${IDS.create}`]);

    const surplusMemory = fakeDb(baseSeed());
    await expect(invoke(surplusMemory, 'contract-1', request({
      eventDraft: {
        ...scopedDraft,
        affectedAssetClassIds: [IDS.assetClass, IDS.otherAssetClass],
      },
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-asset-class-mismatch'},
    });
    expect(surplusMemory.writes.map((write) => write.path))
      .toEqual([`operational_event_receipts/${IDS.create}`]);
  });

  test('reopen revalidates persisted targets before writes', async () => {
    const seed = baseSeed();
    seed[`asset_instances/${IDS.asset}`] = {
      ...seed[`asset_instances/${IDS.asset}`],
      status: 'retired',
    };
    seed[`operational_events/${IDS.event}`] = persistedEvent({
      scope: 'assets',
      affectedAssetClassIds: [IDS.assetClass],
      affectedAssetInstanceIds: [IDS.asset],
      status: 'resolved',
      resolvedAt: new Date('2026-08-14T12:00:00.000Z'),
      resolvedByUid: 'ops-1',
      resolvedByName: 'Operations One',
      resolutionNote: 'Supply remained stable through verification.',
    });
    const memory = fakeDb(seed);

    await expect(invoke(memory, 'admin-1', {
      requestId: IDS.reopen,
      operation: 'REOPEN_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Reopen after confirming the operational effect has recurred.',
    }, new Date('2026-08-14T13:00:00.000Z'))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-asset-invalid'},
    });
    expect(memory.writes).toHaveLength(0);
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
      [`operational_events/${IDS.event}`]: persistedEvent({
        issueLinkIds: ['event_issue_existing'],
        linkedIssueIds: ['maintenance_issue_existing'],
      }),
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
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      issueLinkIds: ['event_issue_existing'],
      linkedIssueIds: ['maintenance_issue_existing'],
    });
  });

  test('resolves and reopens with supervisory evidence', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: persistedEvent({
        issueLinkIds: ['event_issue_existing'],
        linkedIssueIds: ['maintenance_issue_existing'],
      }),
    });
    const resolved = await invoke(memory, 'ops-1', {
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm restoration after stable utility observation.',
      resolutionNote: 'Incoming supply remained stable through verification.',
      resolvedAt: '2026-08-14T11:45:00.000Z',
    });
    expect(resolved).toMatchObject({status: 'resolved', version: 2});
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      status: 'resolved',
      resolvedAt: new Date('2026-08-14T11:45:00.000Z'),
      resolvedByUid: 'ops-1',
      updatedAt: new Date('2026-08-14T12:00:00.000Z'),
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
        eventType: 'powerTrip',
        title: 'Incoming power interruption',
        description: 'Incoming supply was lost across the annealing shop.',
        severity: 'critical',
        startedAt: new Date('2026-08-14T10:00:00.000Z'),
        resolvedAt: new Date('2026-08-14T11:45:00.000Z'),
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
        issueLinkIds: ['event_issue_existing'],
        linkedIssueIds: ['maintenance_issue_existing'],
        resolvedByUid: 'ops-1',
        resolvedByName: 'Operations One',
        resolutionNote: 'Incoming supply remained stable through verification.',
      }],
      startedAt: new Date('2026-08-14T13:00:00.000Z'),
      issueLinkIds: [],
      linkedIssueIds: [],
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
          eventType: 'powerTrip',
          title: 'Incoming power interruption',
          description: 'Incoming supply was lost across the annealing shop.',
          severity: 'critical',
          startedAt: new Date('2026-08-14T10:00:00.000Z'),
          resolvedAt: new Date('2026-08-14T11:45:00.000Z'),
          scope: 'plantWide',
          affectedAssetClassIds: [],
          affectedAssetInstanceIds: [],
          issueLinkIds: ['event_issue_existing'],
          linkedIssueIds: ['maintenance_issue_existing'],
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
        eventType: 'crane',
        title: 'Charging crane interruption',
        description: 'The recurring event now affects charging crane support.',
        severity: 'significant',
        scope: 'assets',
        affectedAssetClassIds: [IDS.assetClass],
        affectedAssetInstanceIds: [IDS.asset],
        startedAt: '2026-08-14T13:00:00.000Z',
      },
    }), new Date('2026-08-14T13:30:00.000Z'));
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      eventType: 'crane',
      title: 'Charging crane interruption',
      severity: 'significant',
      scope: 'assets',
      affectedAssetInstanceIds: [IDS.asset],
      completedIntervals: [{
        eventType: 'powerTrip',
        title: 'Incoming power interruption',
        description: 'Incoming supply was lost across the annealing shop.',
        severity: 'critical',
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
        resolvedByUid: 'ops-1',
        resolvedByName: 'Operations One',
        resolutionNote: 'Incoming supply remained stable through verification.',
      }],
    });
  });

  test('rejects selected closure time outside the active server interval', async () => {
    for (const [resolvedAt, reasonCode] of [
      ['2026-08-14T09:59:00.000Z', 'operational-event-resolved-at-before-start'],
      ['2026-08-14T12:01:00.000Z', 'operational-event-resolved-at-future'],
    ]) {
      const memory = fakeDb({
        ...baseSeed(),
        [`operational_events/${IDS.event}`]: persistedEvent(),
      });
      await expect(invoke(memory, 'ops-1', {
        requestId: IDS.resolve,
        operation: 'RESOLVE_OPERATIONAL_EVENT',
        eventId: IDS.event,
        expectedVersion: 1,
        reason: 'Confirm restoration after stable utility observation.',
        resolutionNote: 'Incoming supply remained stable through verification.',
        resolvedAt,
      })).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode},
      });
      expect(memory.writes).toHaveLength(0);
    }
  });

  test('legacy resolve omission keeps server-time replay compatibility', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: persistedEvent(),
    });
    const legacyRequest = {
      requestId: IDS.resolve,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Confirm restoration after stable utility observation.',
      resolutionNote: 'Incoming supply remained stable through verification.',
    };
    await expect(invoke(memory, 'ops-1', legacyRequest)).resolves.toMatchObject({
      status: 'resolved',
      version: 2,
    });
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      resolvedAt: new Date('2026-08-14T12:00:00.000Z'),
    });
    expect(memory.store.get(
      `operational_event_receipts/${IDS.resolve}`,
    ).fingerprint).toMatch(/^operationalevent1-sha256:/);
    await expect(invoke(memory, 'ops-1', legacyRequest)).resolves.toMatchObject({
      idempotentReplay: true,
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

    const partialLinkProjection = persistedEvent({
      issueLinkIds: ['event_issue_existing'],
    });
    const partialLinkMemory = fakeDb({
      ...baseSeed(),
      [`operational_events/${IDS.event}`]: partialLinkProjection,
    });
    await expect(invoke(partialLinkMemory, 'ops-1', {
      requestId: IDS.update,
      operation: 'UPDATE_OPERATIONAL_EVENT',
      eventId: IDS.event,
      expectedVersion: 1,
      reason: 'Correct the operational event after field confirmation.',
      eventDraft: request().eventDraft,
    })).rejects.toMatchObject({
      details: {reasonCode: 'operational-event-projection-malformed'},
    });
    expect(partialLinkMemory.writes).toHaveLength(0);
  });
});
