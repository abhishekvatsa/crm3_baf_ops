const admin = require('firebase-admin');

const {
  mutateChargeAbnormalityWithDb,
} = require('../lib/chargeAbnormalityMutation');

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

  async function seed() {
    await db.collection('users').doc('admin-1').set({
      name: 'Admin One',
      email: 'admin-1@test.local',
      isApproved: true,
      roles: ['admin'],
      createdAt: new Date('2026-07-20T00:00:00.000Z'),
    });
    await db.collection('charge_abnormalities').doc('abn-1').set(
      abnormality(),
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
    await seed();
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
