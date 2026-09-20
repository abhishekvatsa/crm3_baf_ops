const fs = require('fs');
const path = require('path');

const {mutateQualityWithDb} = require('../lib/qualityMutation');
const {
  mutateChargeAbnormalityWithDb,
} = require('../lib/chargeAbnormalityMutation');

// The committed fixtures are the exact wire responses a retry returns after
// later governed work. test/quality_case_replay_response_contract_test.dart
// decodes these same files with the shipped client decoders.
const FIXTURES = path.join(__dirname, 'fixtures');
const QUALITY_FIXTURE = path.join(
  FIXTURES,
  'quality_decision_replay_response.json',
);
const ABNORMALITY_FIXTURE = path.join(
  FIXTURES,
  'abnormality_replay_response.json',
);

const IDS = {
  close: '22222222-2222-4222-8222-222222222222',
  reopen: '33333333-3333-4333-8333-333333333333',
  update: '11111111-1111-4111-8111-111111111111',
  laterUpdate: '44444444-4444-4444-8444-444444444444',
};

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([key, value]) => [
    key,
    clone(value),
  ]));

  function snapshot(path_, id) {
    const value = store.get(path_);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path_ = `${collection}/${id}`;
    return {id, path: path_, async get() {
      return snapshot(path_, id);
    }};
  }

  return {
    store,
    db: {
      collection(name) {
        return {doc: (id) => ref(name, id)};
      },
      async runTransaction(fn) {
        const staged = [];
        const result = await fn({
          async get(documentRef) {
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({path: documentRef.path, data: clone(data)});
          },
        });
        for (const write of staged) store.set(write.path, clone(write.data));
        return result;
      },
    },
  };
}

// Firestore hands a callable response its timestamps in this shape.
function wireTimestamp(iso) {
  const millis = new Date(iso).valueOf();
  return {
    _seconds: Math.floor(millis / 1000),
    _nanoseconds: (millis % 1000) * 1000000,
  };
}

const wire = (value) => JSON.parse(JSON.stringify(value));

function expectFixture(file, actual) {
  if (process.env.UPDATE_FIXTURES === '1') {
    fs.writeFileSync(file, `${JSON.stringify(actual, null, 2)}\n`);
  }
  expect(actual).toEqual(JSON.parse(fs.readFileSync(file, 'utf8')));
}

function qualitySeed() {
  return {
    'users/si-1': {isApproved: true, roles: ['si'], name: 'SI One'},
    'quality_warnings/abnormality_abn-1': {
      schemaVersion: 1,
      warningId: 'abnormality_abn-1',
      sourceType: 'abnormality',
      sourceId: 'abn-1',
      sourceVersion: 1,
      sourceChargeNo: 12001,
      sourceSummary: 'Atmosphere deviation',
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
      createdAt: wireTimestamp('2026-08-14T08:00:00.000Z'),
      createdByUid: 'ops-1',
      createdByName: 'Operations One',
      updatedAt: wireTimestamp('2026-08-14T08:00:00.000Z'),
      updatedByUid: 'ops-1',
      updatedByName: 'Operations One',
      version: 1,
    },
    'charge_abnormalities/abn-1': {
      firestoreId: 'abn-1',
      sourceChargeNo: 12001,
      abnormalityTypeId: 'ATMOSPHERE_DEVIATION',
      abnormalityTypeTitle: 'Atmosphere deviation',
      abnormalityTypeCode: 'ATM-DEV',
      category: 'process',
      severity: 'critical',
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      component: 'Atmosphere control',
      observedReason: 'Atmosphere interruption may affect coil quality.',
      description: 'Logged from the cycle review.',
      possibleRootReasonCategory: 'unknown',
      possibleRootReasonNotes: null,
      reannealingStatus: 'pendingDecision',
      reannealedToChargeNo: null,
      loggedAt: wireTimestamp('2026-08-14T08:00:00.000Z'),
      updatedAt: wireTimestamp('2026-08-14T08:00:00.000Z'),
      loggedByUid: 'ops-1',
      loggedByName: 'Operations One',
      updatedByUid: 'ops-1',
      updatedByName: 'Operations One',
      linkedTicketFirestoreId: null,
      linkedExecutionFirestoreId: null,
      version: 1,
      isDeleted: false,
      deletedAt: null,
      deletedByUid: null,
      deletedByName: null,
      deleteReason: null,
    },
  };
}

function closeDecision() {
  return {
    requestId: IDS.close,
    operation: 'CLOSE_QUALITY_WARNING',
    warningId: 'abnormality_abn-1',
    expectedVersion: 1,
    reason: 'Inspection found the affected coil acceptable.',
    disposition: 'coilFoundAcceptable',
    linkedReannealingChargeNos: [],
  };
}

function invokeQuality(memory, data, iso) {
  return mutateQualityWithDb({
    db: memory.db,
    authUid: 'si-1',
    data,
    now: () => new Date(iso),
    timestampFromDate: (date) => wireTimestamp(date.toISOString()),
  });
}

function abnormalitySeed() {
  const record = {
    firestoreId: 'abn-1',
    sourceChargeNo: 12001,
    abnormalityTypeId: 'TYPE_OLD',
    abnormalityTypeTitle: 'Old title',
    abnormalityTypeCode: 'TYPE_OLD',
    category: 'equipment',
    severity: 'medium',
    affectedAssets: [{assetType: 'base', assetNumber: 12}],
    component: null,
    observedReason: 'Original observation',
    description: null,
    possibleRootReasonCategory: 'unknown',
    possibleRootReasonNotes: null,
    reannealingStatus: 'required',
    reannealedToChargeNo: null,
    loggedAt: '2026-07-20T08:00:00.000Z',
    updatedAt: '2026-07-20T08:00:00.000Z',
    loggedByUid: 'operator-1',
    loggedByName: 'Operator One',
    updatedByUid: 'operator-1',
    updatedByName: 'Operator One',
    linkedTicketFirestoreId: null,
    linkedExecutionFirestoreId: null,
    version: 4,
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
  };
  return {
    'users/admin-1': {isApproved: true, roles: ['admin'], name: 'Admin One'},
    'charge_abnormalities/abn-1': record,
    'quality_warnings/abnormality_abn-1': {
      schemaVersion: 1,
      warningId: 'abnormality_abn-1',
      sourceType: 'abnormality',
      sourceId: 'abn-1',
      sourceVersion: record.version,
      sourceChargeNo: record.sourceChargeNo,
      sourceSummary: record.abnormalityTypeTitle,
      sourceSeverity: record.severity,
      warningReason: record.observedReason,
      affectedAssets: record.affectedAssets,
      component: record.component,
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
      createdAt: record.loggedAt,
      createdByUid: record.loggedByUid,
      createdByName: record.loggedByName,
      updatedAt: record.loggedAt,
      updatedByUid: record.loggedByUid,
      updatedByName: record.loggedByName,
      version: 1,
    },
    'abnormality_types/TYPE_NEW': {
      firestoreId: 'TYPE_NEW',
      code: 'NEW-CODE',
      title: 'Canonical new title',
      category: 'process',
      severity: 'high',
      isActive: true,
      isDeleted: false,
    },
  };
}

function updateRequest(overrides = {}) {
  return {
    requestId: IDS.update,
    abnormalityId: 'abn-1',
    operation: 'UPDATE',
    expectedVersion: 4,
    reason: 'Corrected after Admin review',
    abnormalityTypeId: 'TYPE_NEW',
    severity: 'critical',
    affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
    component: 'Burner assembly',
    observedReason: 'Revised observation',
    description: 'Detailed correction',
    possibleRootReasonCategory: 'furnaceRelated',
    possibleRootReasonNotes: 'Inspection confirmed the source',
    reannealingStatus: 'completed',
    reannealedToChargeNo: 12002,
    ...overrides,
  };
}

function invokeAbnormality(memory, data, iso) {
  return mutateChargeAbnormalityWithDb({
    db: memory.db,
    authUid: 'admin-1',
    data,
    now: () => new Date(iso),
    timestampFromDate: (date) => wireTimestamp(date.toISOString()),
  });
}

describe('replay responses the shipped client must accept', () => {
  test('a quality decision recovered after a reopening', async () => {
    const memory = fakeDb(qualitySeed());
    await invokeQuality(memory, closeDecision(), '2026-08-14T12:00:00.000Z');
    await invokeQuality(memory, {
      requestId: IDS.reopen,
      operation: 'REOPEN_QUALITY_WARNING',
      warningId: 'abnormality_abn-1',
      expectedVersion: 2,
      reason: 'New evidence requires the case to be reviewed again.',
    }, '2026-08-14T12:30:00.000Z');

    const replay = await invokeQuality(
      memory,
      closeDecision(),
      '2026-08-14T13:00:00.000Z',
    );

    expect(replay).toMatchObject({
      idempotentReplay: true,
      version: 2,
      entity: {status: 'closed'},
      linkedAbnormality: {version: 2, reannealingStatus: 'notRequired'},
    });
    expectFixture(QUALITY_FIXTURE, wire(replay));
  });

  test('an abnormality correction recovered after a later correction', async () => {
    const memory = fakeDb(abnormalitySeed());
    await invokeAbnormality(
      memory,
      updateRequest(),
      '2026-07-26T10:00:00.000Z',
    );
    await invokeAbnormality(memory, updateRequest({
      requestId: IDS.laterUpdate,
      expectedVersion: 5,
      observedReason: 'Later governed correction',
      reason: 'Second Admin correction',
    }), '2026-07-26T11:00:00.000Z');

    const replay = await invokeAbnormality(
      memory,
      updateRequest(),
      '2026-07-26T12:00:00.000Z',
    );

    expect(replay).toMatchObject({
      idempotentReplay: true,
      version: 5,
      abnormality: {observedReason: 'Revised observation'},
    });
    expectFixture(ABNORMALITY_FIXTURE, wire(replay));
  });
});
