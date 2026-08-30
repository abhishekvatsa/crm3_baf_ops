const {
  mutateQualityWithDb,
  parseQualityMutationRequest,
  qualityAuditActionForOperation,
  userCanMutateQuality,
} = require('../lib/qualityMutation');
const {
  planQualityMonitoringArchive,
} = require('../lib/qualityMonitoringRetention');

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
  raRequired: '66666666-6666-4666-8666-666666666666',
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

function linkedAbnormality(overrides = {}) {
  return {
    firestoreId: 'issue_quality_ticket-1',
    sourceChargeNo: 12001,
    abnormalityTypeId: 'ATMOSPHERE_DEVIATION',
    abnormalityTypeTitle: 'Atmosphere deviation',
    abnormalityTypeCode: 'ATM-DEV',
    category: 'process',
    severity: 'critical',
    affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
    component: 'Atmosphere control',
    observedReason: 'Atmosphere interruption may affect coil quality.',
    description: 'Created from maintenance issue ticket-1.',
    possibleRootReasonCategory: 'unknown',
    possibleRootReasonNotes: null,
    reannealingStatus: 'pendingDecision',
    reannealedToChargeNo: null,
    loggedAt: new Date('2026-08-14T08:00:00.000Z'),
    updatedAt: new Date('2026-08-14T08:00:00.000Z'),
    loggedByUid: 'ops-1',
    loggedByName: 'Operations One',
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    linkedTicketFirestoreId: 'ticket-1',
    linkedExecutionFirestoreId: null,
    version: 1,
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    ...overrides,
  };
}

function linkedIssueSeed(overrides = {}) {
  return {
    ...seed(),
    'maintenance_records/ticket-1': {
      qualityAbnormalityId: 'issue_quality_ticket-1',
      qualityWarningId: 'issue_ticket-1',
      chargeQualityCaseId: 'issue_ticket-1',
    },
    'charge_abnormalities/issue_quality_ticket-1': linkedAbnormality(
      overrides,
    ),
  };
}

function monitoring(overrides = {}) {
  return {
    schemaVersion: 2,
    requestId: IDS.monitoring,
    baseNumber: 12,
    grade: 'CRGO M4',
    cycleReference: 'Cycle family 7A',
    chargeNumbers: [12001, 12002],
    reason: 'Monitor atmosphere stability during the campaign.',
    status: 'active',
    visibilityState: 'active',
    visibleUntil: null,
    archivedAt: null,
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

function legacyMonitoring(overrides = {}) {
  const value = monitoring({schemaVersion: 1, ...overrides});
  delete value.visibilityState;
  delete value.visibleUntil;
  delete value.archivedAt;
  return value;
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
  test('quality operations map to persisted audit enums', () => {
    expect(qualityAuditActionForOperation(
      'REQUEST_QUALITY_WARNING_CLOSURE',
    )).toBe('update');
    expect(qualityAuditActionForOperation(
      'DECLARE_QUALITY_CASE_RA_REQUIRED',
    )).toBe('update');
    expect(qualityAuditActionForOperation('CLOSE_QUALITY_WARNING'))
      .toBe('resolve');
    expect(qualityAuditActionForOperation('REOPEN_QUALITY_WARNING'))
      .toBe('reopen');
    expect(qualityAuditActionForOperation(
      'CREATE_QUALITY_MONITORING_REQUEST',
    )).toBe('create');
    expect(qualityAuditActionForOperation(
      'CLOSE_QUALITY_MONITORING_REQUEST',
    )).toBe('resolve');
  });

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
    expect(memory.store.get(`audit_logs/server_quality_${IDS.request}`))
      .toMatchObject({action: 'update', reason: 'other'});
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

  test('stamped linked issue keeps RA and warning lifecycle atomic', async () => {
    const serverStamp = new Date('2026-08-14T09:00:00.000Z');
    const memory = fakeDb(linkedIssueSeed({
      _globalPullServerUpdatedAt: serverStamp,
    }));
    const declared = await invoke(memory, 'si-1', {
      requestId: IDS.raRequired,
      operation: 'DECLARE_QUALITY_CASE_RA_REQUIRED',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'The affected charge requires a governed re-annealing cycle.',
    });
    expect(declared).toMatchObject({version: 2});
    expect(memory.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      status: 'open',
      version: 2,
    });
    expect(
      memory.store.get('charge_abnormalities/issue_quality_ticket-1'),
    ).toMatchObject({
      reannealingStatus: 'required',
      version: 2,
      _globalPullServerUpdatedAt: serverStamp,
    });

    const completedRequest = {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 2,
      reason: 'The charge completed the approved re-annealing cycle.',
      disposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [13001],
    };
    const completed = await invoke(memory, 'si-1', completedRequest);
    const writesAfterCompletion = memory.writes.length;
    const replay = await invoke(memory, 'si-1', completedRequest);
    expect(completed).toMatchObject({version: 3, idempotentReplay: false});
    expect(replay).toEqual({...completed, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writesAfterCompletion);
    expect(memory.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      status: 'closed',
      closureDisposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [13001],
      version: 3,
    });
    expect(
      memory.store.get('charge_abnormalities/issue_quality_ticket-1'),
    ).toMatchObject({
      reannealingStatus: 'completed',
      reannealedToChargeNo: 13001,
      version: 3,
      _globalPullServerUpdatedAt: serverStamp,
    });

    await invoke(memory, 'si-1', {
      requestId: IDS.reopen,
      operation: 'REOPEN_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 3,
      reason: 'New evidence requires the quality case to be reviewed again.',
    });
    expect(memory.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      status: 'open',
      version: 4,
    });
    expect(
      memory.store.get('charge_abnormalities/issue_quality_ticket-1'),
    ).toMatchObject({
      reannealingStatus: 'pendingDecision',
      reannealedToChargeNo: null,
      version: 4,
      _globalPullServerUpdatedAt: serverStamp,
    });
  });

  test('malformed linked abnormality server clock fails closed', async () => {
    const memory = fakeDb(linkedIssueSeed({
      _globalPullServerUpdatedAt: 'not-a-timestamp',
    }));

    await expect(invoke(memory, 'si-1', {
      requestId: IDS.raRequired,
      operation: 'DECLARE_QUALITY_CASE_RA_REQUIRED',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'The affected charge requires a governed re-annealing cycle.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'charge-quality-abnormality-malformed',
        field: '_globalPullServerUpdatedAt',
      },
    });
  });

  test('RA completion requires a prior required decision', async () => {
    const memory = fakeDb(linkedIssueSeed());
    const writesBefore = memory.writes.length;

    await expect(invoke(memory, 'si-1', {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'Attempted completion without a prior RA-required decision.',
      disposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [13001],
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'charge-quality-ra-not-required'},
    });
    expect(memory.writes).toHaveLength(writesBefore);
    expect(memory.store.get('quality_warnings/issue_ticket-1'))
      .toMatchObject({status: 'open', version: 1});
    expect(
      memory.store.get('charge_abnormalities/issue_quality_ticket-1'),
    ).toMatchObject({reannealingStatus: 'pendingDecision', version: 1});
  });

  test('reopening a retired standalone case reactivates its abnormality', async () => {
    const warningId = 'abnormality_abn-1';
    const memory = fakeDb({
      'users/si-1': user('si', 'SI One'),
      [`quality_warnings/${warningId}`]: warning({
        warningId,
        sourceType: 'abnormality',
        sourceId: 'abn-1',
        sourceVersion: 4,
        status: 'closed',
        closedAt: new Date('2026-08-14T10:00:00.000Z'),
        closedByUid: 'si-1',
        closedByName: 'SI One',
        closureDisposition: 'coilFoundAcceptable',
        decisionReason: 'Inspection found the affected coil acceptable.',
        version: 2,
      }),
      'charge_abnormalities/abn-1': linkedAbnormality({
        firestoreId: 'abn-1',
        linkedTicketFirestoreId: null,
        reannealingStatus: 'notRequired',
        version: 5,
        isDeleted: true,
        deletedAt: new Date('2026-08-14T11:00:00.000Z'),
        deletedByUid: 'admin-1',
        deletedByName: 'Admin One',
        deleteReason: 'Duplicate record confirmed after quality closure.',
      }),
    });
    const request = {
      requestId: IDS.reopen,
      operation: 'REOPEN_QUALITY_WARNING',
      warningId,
      expectedVersion: 2,
      reason: 'New evidence requires the retired case to be reviewed again.',
    };

    const first = await invoke(memory, 'si-1', request);
    const writesAfterFirst = memory.writes.length;
    const replay = await invoke(memory, 'si-1', request);

    expect(first).toMatchObject({version: 3, idempotentReplay: false});
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writesAfterFirst);
    expect(memory.store.get(`quality_warnings/${warningId}`)).toMatchObject({
      status: 'open',
      sourceVersion: 6,
      version: 3,
    });
    expect(memory.store.get('charge_abnormalities/abn-1')).toMatchObject({
      reannealingStatus: 'pendingDecision',
      reannealedToChargeNo: null,
      version: 6,
      isDeleted: false,
      deletedAt: null,
      deletedByUid: null,
      deletedByName: null,
      deleteReason: null,
    });
  });

  test('linked issue case rejects ambiguous RA targets and missing linkage', async () => {
    const ambiguous = fakeDb(linkedIssueSeed({reannealingStatus: 'required'}));
    await expect(invoke(ambiguous, 'si-1', {
      requestId: IDS.close,
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'Attempted closure with two resulting charge identities.',
      disposition: 'reannealingCompleted',
      linkedReannealingChargeNos: [13001, 13002],
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'charge-quality-ra-charge-count-invalid'},
    });
    expect(ambiguous.writes).toHaveLength(0);

    const missingSeed = linkedIssueSeed();
    delete missingSeed['charge_abnormalities/issue_quality_ticket-1'];
    const missing = fakeDb(missingSeed);
    await expect(invoke(missing, 'si-1', {
      requestId: IDS.raRequired,
      operation: 'DECLARE_QUALITY_CASE_RA_REQUIRED',
      warningId: 'issue_ticket-1',
      expectedVersion: 1,
      reason: 'The affected charge requires a governed re-annealing cycle.',
    })).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'charge-quality-abnormality-missing'},
    });
    expect(missing.writes).toHaveLength(0);
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

  test('legacy monitoring closes through a governed schema-v2 upgrade', async () => {
    const legacySeed = seed();
    legacySeed[`quality_monitoring_requests/${IDS.monitoring}`] =
      legacyMonitoring();
    const memory = fakeDb(legacySeed);

    await invoke(memory, 'admin-1', {
      requestId: IDS.monitoringClose,
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 1,
      reason: 'Legacy monitoring evidence reviewed and closed.',
    });

    expect(memory.store.get(
      `quality_monitoring_requests/${IDS.monitoring}`,
    )).toMatchObject({
      schemaVersion: 2,
      status: 'closed',
      visibilityState: 'recent',
      visibleUntil: new Date('2026-08-21T12:00:00.000Z'),
    });
  });

  test('partial legacy visibility projection fails closed', async () => {
    const legacySeed = seed();
    legacySeed[`quality_monitoring_requests/${IDS.monitoring}`] = {
      ...legacyMonitoring(),
      visibilityState: 'active',
    };
    const memory = fakeDb(legacySeed);

    await expect(invoke(memory, 'admin-1', {
      requestId: IDS.monitoringClose,
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 1,
      reason: 'This malformed legacy record must not be closed.',
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
    )).toMatchObject({
      schemaVersion: 2,
      status: 'active',
      visibilityState: 'active',
      visibleUntil: null,
      archivedAt: null,
      baseNumber: 12,
      grade: 'CRGO M4',
    });

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
    )).toMatchObject({
      status: 'closed',
      visibilityState: 'recent',
      visibleUntil: new Date('2026-08-21T12:00:00.000Z'),
      archivedAt: null,
      closedByUid: 'admin-1',
    });

    const path = `quality_monitoring_requests/${IDS.monitoring}`;
    const archivedPatch = planQualityMonitoringArchive({
      data: memory.store.get(path),
      requestId: IDS.monitoring,
      now: new Date('2026-08-21T12:00:00.000Z'),
    });
    memory.store.set(path, {...memory.store.get(path), ...archivedPatch});
    const replay = await invoke(memory, 'admin-1', {
      requestId: IDS.monitoringClose,
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: IDS.monitoring,
      expectedVersion: 1,
      reason: 'The planned monitoring campaign has been completed.',
    });
    expect(replay).toMatchObject({
      idempotentReplay: true,
      version: 2,
      entity: {visibilityState: 'archived'},
    });
  });
});
