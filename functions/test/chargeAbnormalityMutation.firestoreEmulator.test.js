const admin = require('firebase-admin');

const {
  mutateChargeAbnormalityWithDb,
} = require('../lib/chargeAbnormalityMutation');
const {mutateQualityWithDb} = require('../lib/qualityMutation');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `abnormality-emulator-${process.pid}-${Date.now()}`;

const IDS = {
  raceA: '11111111-1111-4111-8111-111111111111',
  raceB: '22222222-2222-4222-8222-222222222222',
  replay: '33333333-3333-4333-8333-333333333333',
  malformed: '44444444-4444-4444-8444-444444444444',
  deleted: '55555555-5555-4555-8555-555555555555',
  qualityReplay: '66666666-6666-4666-8666-666666666666',
};

function abnormality(overrides = {}) {
  return {
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
    reannealingStatus: 'notApplicable',
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
    ...overrides,
  };
}

function warningForAbnormality(record, overrides = {}) {
  return {
    schemaVersion: 1,
    warningId: `abnormality_${record.firestoreId}`,
    sourceType: 'abnormality',
    sourceId: record.firestoreId,
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
    ...overrides,
  };
}

function updateRequest(requestId, overrides = {}) {
  return {
    requestId,
    abnormalityId: 'abn-1',
    operation: 'UPDATE',
    expectedVersion: 4,
    reason: 'Corrected after governed Admin review',
    abnormalityTypeId: 'TYPE_NEW',
    severity: 'high',
    affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
    component: null,
    observedReason: 'Governed corrected observation',
    description: null,
    possibleRootReasonCategory: 'furnaceRelated',
    possibleRootReasonNotes: null,
    reannealingStatus: 'required',
    reannealedToChargeNo: null,
    ...overrides,
  };
}

describeWithEmulator('S-07 governed charge-abnormality mutation', () => {
  let app;
  let db;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  async function seed({warningOverrides = {}} = {}) {
    const record = abnormality();
    await db.collection('users').doc('admin-1').set({
      name: 'Admin One',
      email: 'admin-1@test.local',
      isApproved: true,
      roles: ['admin'],
      createdAt: new Date('2026-07-20T00:00:00.000Z'),
    });
    await db.collection('charge_abnormalities').doc('abn-1').set(
      record,
    );
    await db.collection('quality_warnings').doc('abnormality_abn-1').set(
      warningForAbnormality(record, warningOverrides),
    );
    await db.collection('abnormality_types').doc('TYPE_NEW').set({
      firestoreId: 'TYPE_NEW',
      code: 'NEW-CODE',
      title: 'Canonical new title',
      category: 'process',
      severity: 'high',
      isActive: true,
      isDeleted: false,
    });
  }

  async function invoke(data, extra = {}) {
    return mutateChargeAbnormalityWithDb({
      db,
      authUid: 'admin-1',
      data,
      now: () => new Date('2026-07-26T10:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
      ...extra,
    });
  }

  async function invokeQuality(data) {
    return mutateQualityWithDb({
      db,
      authUid: 'admin-1',
      data,
      now: () => new Date('2026-07-26T10:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  async function collectionState(name) {
    const snapshot = await db.collection(name).get();
    return snapshot.docs
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .sort((a, b) => a.id.localeCompare(b.id));
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  afterAll(async () => {
    if (app) await app.delete();
  });

  test('concurrent same-version updates permit exactly one atomic evidence set', async () => {
    await seed();

    const results = await Promise.allSettled([
      invoke(updateRequest(IDS.raceA, {
        observedReason: 'First concurrent correction',
      })),
      invoke(updateRequest(IDS.raceB, {
        observedReason: 'Second concurrent correction',
      })),
    ]);

    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);
    expect(
      results.find((result) => result.status === 'rejected').reason,
    ).toMatchObject({
      code: 'aborted',
      details: expect.objectContaining({
        reasonCode: 'abnormality-preimage-mismatch',
        currentVersion: 5,
      }),
    });

    const current = (
      await db.collection('charge_abnormalities').doc('abn-1').get()
    ).data();
    expect(current).toMatchObject({
      version: 5,
      updatedByUid: 'admin-1',
      abnormalityTypeCode: 'NEW-CODE',
      abnormalityTypeTitle: 'Canonical new title',
      category: 'process',
    });
    expect(
      (await db.collection('quality_warnings').doc('abnormality_abn-1').get())
        .data(),
    ).toMatchObject({
      status: 'open',
      sourceVersion: 5,
      sourceSummary: 'Canonical new title',
      warningReason: expect.stringMatching(/concurrent correction$/),
      version: 2,
    });
    expect(await collectionState('charge_abnormality_mutation_receipts'))
      .toHaveLength(1);
    expect(
      (await collectionState('audit_logs')).filter(({id}) =>
        id.startsWith('server_charge_abnormality_'),
      ),
    ).toHaveLength(1);
  });

  test('exact replay returns one receipt and one immutable audit', async () => {
    await seed();
    const request = updateRequest(IDS.replay);

    const first = await invoke(request);
    const replay = await invoke(request);

    expect(first.idempotentReplay).toBe(false);
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(await collectionState('charge_abnormality_mutation_receipts'))
      .toHaveLength(1);
    expect(
      (await collectionState('audit_logs')).filter(({id}) =>
        id.startsWith('server_charge_abnormality_'),
      ),
    ).toHaveLength(1);
  });

  test('connected RA decision atomically advances warning and abnormality', async () => {
    const record = abnormality({
      firestoreId: 'issue_quality_ticket-1',
      linkedTicketFirestoreId: 'ticket-1',
      reannealingStatus: 'pendingDecision',
      version: 1,
    });
    const warningId = 'issue_ticket-1';
    await db.collection('users').doc('admin-1').set({
      name: 'Admin One',
      email: 'admin-1@test.local',
      isApproved: true,
      roles: ['admin'],
      createdAt: new Date('2026-07-20T00:00:00.000Z'),
    });
    await db.collection('maintenance_records').doc('ticket-1').set({
      chargeNoAtEvent: record.sourceChargeNo,
      qualityAbnormalityId: record.firestoreId,
      qualityWarningId: warningId,
      chargeQualityCaseId: warningId,
    });
    await db.collection('charge_abnormalities').doc(record.firestoreId).set(
      record,
    );
    await db.collection('quality_warnings').doc(warningId).set(
      warningForAbnormality(record, {
        warningId,
        sourceType: 'issue',
        sourceId: 'ticket-1',
        sourceVersion: 1,
      }),
    );

    const request = {
      requestId: IDS.qualityReplay,
      operation: 'DECLARE_QUALITY_CASE_RA_REQUIRED',
      warningId,
      expectedVersion: 1,
      reason: 'SI review confirms re-annealing is required.',
    };
    const first = await invokeQuality(request);
    const replay = await invokeQuality(request);

    expect(first).toMatchObject({version: 2, idempotentReplay: false});
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(
      (await db.collection('quality_warnings').doc(warningId).get()).data(),
    ).toMatchObject({status: 'open', version: 2});
    expect(
      (await db.collection('charge_abnormalities').doc(record.firestoreId)
        .get()).data(),
    ).toMatchObject({reannealingStatus: 'required', version: 2});
    expect(await collectionState('quality_mutation_receipts')).toHaveLength(1);
    expect(
      (await collectionState('audit_logs')).filter(({id}) =>
        id.startsWith('server_quality_'),
      ),
    ).toHaveLength(1);
  });

  test('malformed current state rolls back without target, audit, or receipt write', async () => {
    await seed();
    const before = abnormality();
    delete before.possibleRootReasonNotes;
    await db.collection('charge_abnormalities').doc('abn-1').set(before);

    await expect(invoke(updateRequest(IDS.malformed))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-record-malformed',
        field: 'possibleRootReasonNotes',
      }),
    });

    expect(
      (await db.collection('charge_abnormalities').doc('abn-1').get()).data(),
    ).toEqual(before);
    expect(await collectionState('charge_abnormality_mutation_receipts'))
      .toHaveLength(0);
    expect(await collectionState('audit_logs')).toHaveLength(0);
  });

  test('soft delete commits tombstone and evidence in one transaction', async () => {
    await seed({
      warningOverrides: {
        status: 'closed',
        closedAt: '2026-07-25T09:00:00.000Z',
        closedByUid: 'admin-1',
        closedByName: 'Admin One',
        closureDisposition: 'qualityAdjudication',
        decisionReason: 'Duplicate disposition evidence was confirmed.',
      },
    });
    const result = await invoke({
      requestId: IDS.deleted,
      abnormalityId: 'abn-1',
      operation: 'SOFT_DELETE',
      expectedVersion: 4,
      reason: 'Duplicate record confirmed',
    });

    expect(result).toMatchObject({
      operation: 'SOFT_DELETE',
      version: 5,
      idempotentReplay: false,
    });
    expect(
      (await db.collection('charge_abnormalities').doc('abn-1').get()).data(),
    ).toMatchObject({
      isDeleted: true,
      deletedByUid: 'admin-1',
      deleteReason: 'Duplicate record confirmed',
      version: 5,
    });
    expect(
      (await db.collection('audit_logs').doc(result.auditId).get()).data(),
    ).toMatchObject({
      action: 'delete',
      operation: 'SOFT_DELETE',
      resultVersion: 5,
    });
  });
});
