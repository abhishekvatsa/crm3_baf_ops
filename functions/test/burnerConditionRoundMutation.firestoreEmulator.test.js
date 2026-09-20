'use strict';

const admin = require('firebase-admin');
const {createHash} = require('crypto');
const {mutateBurnerConditionRoundWithDb} = require('../lib/burnerConditionRoundMutation');

jest.setTimeout(60000);
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const IDS = {
  round: '11111111-1111-4111-8111-111111111111',
  asset: '22222222-2222-4222-8222-222222222222',
  class: '33333333-3333-4333-8333-333333333333',
  partial: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  competing: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
};

function request(overrides = {}) {
  return {
    requestId: IDS.round, operation: 'RECORD_BURNER_CONDITION_ROUND',
    assetClassId: IDS.class, assetInstanceId: IDS.asset, expectedAssetVersion: 4,
    observations: Array.from({length: 8}, (_, index) => ({
      position: index + 1, flameObservation: 'seen', redHotObserved: false,
      microampReading: index === 0 ? 3.7 : null, remarks: null,
    })),
    uvObservations: Array.from({length: 8}, (_, index) => ({
      position: index + 1, condition: 'serviceable', remarks: null,
    })),
    draftSealRedHotObserved: false, hotAirAtDraftSealObserved: false,
    roundNote: 'Emulator observation', ...overrides,
  };
}

function partial(overrides = {}) {
  return request({requestId: IDS.partial, expectedCurrentRoundId: IDS.round,
    observedFields: ['burners.1.redHotObserved'],
    expectedInstallationBasis: {burner: [], uv: []}, expectedOpenIssueBasis: [],
    ...overrides});
}

describeWithEmulator('Burner partial condition real transaction evidence', () => {
  let app;
  let db;
  const invoke = (data, time = '2026-09-20T09:00:00.000Z') =>
    mutateBurnerConditionRoundWithDb({db, authUid: 'actor-1', data,
      now: () => new Date(time), timestampFromDate: admin.firestore.Timestamp.fromDate});

  beforeAll(() => {
    // This suite only permits a local emulator and an explicitly synthetic project.
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost) ||
        typeof projectId !== 'string' || !projectId.startsWith('demo-')) {
      throw new Error('Use a localhost Firestore emulator with an explicit demo- project.');
    }
    app = admin.initializeApp({projectId}, `burner-condition-emulator-${process.pid}-${Date.now()}`);
    db = admin.firestore(app);
  });

  beforeEach(async () => {
    const response = await fetch(`http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error(`Emulator reset failed: ${response.status}`);
    const batch = db.batch();
    batch.set(db.doc('users/actor-1'), {isApproved: true, roles: ['operations'], name: 'Actor One'});
    batch.set(db.doc(`asset_classes/${IDS.class}`), {schemaVersion: 1,
      assetClassId: IDS.class, code: 'FURNACE', name: 'Furnace',
      legacyAssetTypeKey: 'furnace', status: 'active', version: 2});
    batch.set(db.doc(`asset_instances/${IDS.asset}`), {schemaVersion: 1,
      assetInstanceId: IDS.asset, assetClassId: IDS.class, assetClassCode: 'FURNACE',
      assetClassName: 'Furnace', assetNumber: 7, name: 'Furnace 7',
      status: 'active', serviceState: 'inService', version: 4});
    await batch.commit();
    await invoke(request(), '2026-09-20T08:00:00.000Z');
  });

  afterAll(async () => { if (app) await app.delete(); });

  test('Timestamp-backed inherited observations replay after a later round', async () => {
    const accepted = await invoke(partial());
    const retained = (await db.doc(`burner_condition_rounds/${IDS.partial}`).get()).data();
    expect(retained.observedAt.toDate().toISOString()).toBe('2026-09-20T09:00:00.000Z');
    expect(retained.evidenceProvenance['burners.1.microampReading'].observedAt)
      .toBe('2026-09-20T08:00:00.000Z');
    await invoke(request({requestId: IDS.competing, expectedCurrentRoundId: IDS.partial}), '2026-09-20T10:00:00.000Z');
    expect(await invoke(partial())).toEqual({...accepted, idempotentReplay: true});
    expect((await db.doc(`burner_condition_current/${IDS.asset}`).get()).data().roundId)
      .toBe(IDS.competing);
  });

  test.each(['installation', 'issue'])('a concurrent-source %s refuses the unchanged round basis without a receipt', async (kind) => {
    if (kind === 'installation') {
      const projectionId = `uvlc_${createHash('sha256').update(`${IDS.asset}|2`).digest('hex').slice(0, 40)}`;
      await db.doc(`uv_detector_lifecycle_current/${projectionId}`).set({
        schemaVersion: 1, projectionSchemaVersion: 1, projectionId,
        assetInstanceId: IDS.asset, burnerPosition: 2, eventId: 'replacement-2',
        currentEventId: 'replacement-2', installationDiscipline: 'instrumentation',
        resultingCondition: 'serviceable', actionPerformedAt: admin.firestore.Timestamp.fromDate(new Date('2026-09-20T08:30:00.000Z')),
      });
    } else {
      await db.doc('maintenance_records/issue-1').set({firestoreId: 'issue-1',
        assetType: 'furnace', assetNumber: 7, status: 'open', isResolved: false,
        isDeleted: false, burnerRedHotPositions: [3], version: 1,
        updatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-09-20T08:30:00.000Z'))});
    }
    await expect(invoke(partial())).rejects.toMatchObject({code: 'aborted',
      details: {reasonCode: `burner-condition-round-${kind}-basis-mismatch`}});
    expect((await db.doc(`burner_condition_round_receipts/${IDS.partial}`).get()).exists).toBe(false);
    expect((await db.doc(`burner_condition_rounds/${IDS.partial}`).get()).exists).toBe(false);
  });

  test('two clients composed against one baseline cannot both replace the current round', async () => {
    const results = await Promise.allSettled([
      invoke(partial()), invoke(partial({requestId: IDS.competing})),
    ]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    const rejected = results.find((result) => result.status === 'rejected');
    expect(rejected.reason).toMatchObject({code: 'aborted',
      details: {reasonCode: 'burner-condition-round-superseded'}});
    expect((await db.collection('burner_condition_round_receipts').get()).size).toBe(2);
  });
});
