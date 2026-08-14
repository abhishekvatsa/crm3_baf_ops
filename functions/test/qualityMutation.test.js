const {
  mutateQualityWithDb,
  parseQualityMutationRequest,
  userCanMutateQuality,
} = require('../lib/qualityMutation');

function clone(value) {
  if (value == null || typeof value !== 'object') return value;
  if (value instanceof Date) return new Date(value.valueOf());
  if (Array.isArray(value)) return value.map(clone);
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, clone(item)])
  );
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {
      exists: value != null,
      id,
      data: () => clone(value),
    };
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() { return snapshot(path, id); },
    };
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
  request: '11111111-1111-4111-8111-111111111111',
  close: '22222222-2222-4222-8222-222222222222',
  reopen: '33333333-3333-4333-8333-333333333333',
  monitoring: '44444444-4444-4444-8444-444444444444',
  monitoringClose: '55555555-5555-4555-8555-555555555555',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function warning(overrides = {}) {
  return {
    schemaVersion: 1,
    warningId: 'issue_ticket-1',
    sourceType: 'issue',
    sourceId: 'ticket-1',
    sourceVersion: 1,
    sourceChargeNo: 12001,
    sourceSummary: 'Atmosphere interruption during cycle',
    sourceSeverity: 'critical',
    warningReason: 'Atmosphere interruption may affect coil quality.',
    affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
    component: 'Atmosphere control',
    status: 'open',
    closureRequestReason: null,
    closureRequestedAt: null,
    closureRequestedByUid: null,
    closureRequestedByName: null,
    closedAt: null,
    closedByUid: null,
    closedByName: null,
    closureDisposition: null,
    linkedReannealingChargeNos: [],
    decisionReason: null,
    createdAt: new Date('2026-08-14T08:00:00.000Z'),
    createdByUid: 'ops-1',
    createdByName: 'Operations One',
    updatedAt: new Date('2026-08-14T08:00:00.000Z'),
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    version: 1,
    ...overrides,
  };
}

function seed() {
  return {
    'users/ops-1': user('operations', 'Operations One'),
    'users/shift-1': user('shiftSupervisor', 'Shift One'),
    'users/si-1': user('si', 'SI One'),
    'users/admin-1': user('admin', 'Admin One'),
    'quality_warnings/issue_ticket-1': warning(),
  };
}

function monitoring(overrides = {}) {
  return {
    schemaVersion: 1,
    requestId: IDS.monitoring,
    baseNumber: 12,
    grade: 'CRGO M4',
    cycleReference: 'Cycle family 7A',
    chargeNumbers: [12001, 12002],
    reason: 'Monitor atmosphere stability during the campaign.',
    status: 'active',
    createdAt: new Date('2026-08-14T08:00:00.000Z'),
    createdByUid: 'si-1',
    createdByName: 'SI One',
    closedAt: null,
    closedByUid: null,
    closedByName: null,
    closeReason: null,
    updatedAt: new Date('2026-08-14T08:00:00.000Z'),
    updatedByUid: 'si-1',
    updatedByName: 'SI One',
    version: 1,
    lastMutationId: IDS.monitoring,
    ...overrides,
  };
}

function requestClosure(overrides = {}) {
  return {
    requestId: IDS.request,
    operation: 'REQUEST_QUALITY_WARNING_CLOSURE',
    warningId: 'issue_ticket-1',
    expectedVersion: 1,
    reason: 'Post-warning coil inspection was satisfactory.',
    ...overrides,
  };
}

async function invoke(memory, authUid, data) {
  return mutateQualityWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => new Date('2026-08-14T12:00:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('quality mutation', () => {
  test('authority separates operational closure requests from decisions', () => {
    expect(userCanMutateQuality(
      user('operations'),
      'REQUEST_QUALITY_WARNING_CLOSURE',
    )).toBe(true);
    expect(userCanMutateQuality(
      user('operations'),
      'CLOSE_QUALITY_WARNING',
    )).toBe(false);
    expect(userCanMutateQuality(
      user('si'),
      'CLOSE_QUALITY_WARNING',
    )).toBe(true);
    expect(userCanMutateQuality(
      user('si'),
      'CREATE_QUALITY_MONITORING_REQUEST',
    )).toBe(true);
  });

  test('Operations requests closure and exact replay is write-free', async () => {
    const memory = fakeDb(seed());
    const first = await invoke(memory, 'ops-1', requestClosure());
    const writesAfterFirst = memory.writes.length;
    const replay = await invoke(memory, 'ops-1', requestClosure());

    expect(first).toMatchObject({version: 2, idempotentReplay: false});
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writesAfterFirst);
    expect(memory.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      status: 'closureRequested',
      closureRequestedByUid: 'ops-1',
      version: 2,
    });
  });

  test('SI closes requested warning with explicit coil disposition', async () => {
    const memory = fakeDb(seed());
    await invoke(memory, 'ops-1', requestClosure());
    const result = await invoke(memory, 'si-1', {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 2,
      reason: 'Inspection and downstream checks found the coil acceptable.',
      disposition: 'coilFoundAcceptable',
      linkedReannealingChargeNos: [],
    });

    expect(result).toMatchObject({version: 3});
    expect(memory.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      status: 'closed',
      closureDisposition: 'coilFoundAcceptable',
      closedByUid: 'si-1',
    });
  });

  test('re-annealing closure requires one or more distinct target charges', () => {
    expect(() => parseQualityMutationRequest({
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'The affected material completed re-annealing.',
      disposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [],
    })).toThrow('at least one RA charge');
    expect(parseQualityMutationRequest({
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'The affected material completed re-annealing.',
      disposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [13001, 13002],
    })).toMatchObject({linkedReannealingChargeNos: [13001, 13002]});
  });

  test('wrong-role, stale, and malformed warning decisions are write-free', async () => {
    const wrongRole = fakeDb(seed());
    await expect(invoke(wrongRole, 'ops-1', {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'Attempted quality closure without adjudication authority.',
      disposition: 'qualityAdjudication',
      linkedReannealingChargeNos: [],
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(wrongRole.writes).toHaveLength(0);

    const stale = fakeDb(seed());
    await expect(invoke(stale, 'ops-1', requestClosure({expectedVersion: 0})))
      .rejects.toMatchObject({code: 'aborted'});
    expect(stale.writes).toHaveLength(0);

    const malformedSeed = seed();
    delete malformedSeed['quality_warnings/issue_ticket-1'].warningReason;
    const malformed = fakeDb(malformedSeed);
    await expect(invoke(malformed, 'ops-1', requestClosure()))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(malformed.writes).toHaveLength(0);
  });

  test('partial closure-request evidence is rejected without writes', async () => {
    const malformedSeed = seed();
    malformedSeed['quality_warnings/issue_ticket-1'] = warning({
      status: 'closureRequested',
      closureRequestReason: 'Coils appear satisfactory.',
    });
    const memory = fakeDb(malformedSeed);

    await expect(invoke(memory, 'si-1', {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'Attempted decision over incomplete request evidence.',
      disposition: 'qualityAdjudication',
      linkedReannealingChargeNos: [],
    })).rejects.toMatchObject({code: 'failed-precondition'});
    expect(memory.writes).toHaveLength(0);
  });

  test('malformed persisted monitoring record is rejected without writes', async () => {
    const malformedSeed = seed();
    malformedSeed[`quality_monitoring_requests/${IDS.monitoring}`] = monitoring({
      chargeNumbers: [12001, 12001],
    });
    const memory = fakeDb(malformedSeed);

    await expect(invoke(memory, 'si-1', {
      requestId: IDS.monitoringClose,
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 1,
      reason: 'Attempted closure over malformed monitoring evidence.',
    })).rejects.toMatchObject({code: 'failed-precondition'});
    expect(memory.writes).toHaveLength(0);
  });

  test('SI creates and closes a bounded Base/Grade/cycle monitoring request', async () => {
    const memory = fakeDb(seed());
    const created = await invoke(memory, 'si-1', {
      requestId: IDS.request,
      operation: 'CREATE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 0,
      reason: 'Monitor atmosphere stability for the selected product campaign.',
      baseNumber: 12,
      grade: 'CRGO M4',
      cycleReference: 'Cycle family 7A',
      chargeNumbers: [12011, 12012],
    });
    expect(created).toMatchObject({version: 1});
    expect(memory.store.get(
      `quality_monitoring_requests/${IDS.monitoring}`,
    )).toMatchObject({status: 'active', baseNumber: 12, grade: 'CRGO M4'});

    const closed = await invoke(memory, 'admin-1', {
      requestId: IDS.monitoringClose,
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 1,
      reason: 'The planned monitoring campaign has been completed.',
    });
    expect(closed).toMatchObject({version: 2});
    expect(memory.store.get(
      `quality_monitoring_requests/${IDS.monitoring}`,
    )).toMatchObject({status: 'closed', closedByUid: 'admin-1'});
  });
});
