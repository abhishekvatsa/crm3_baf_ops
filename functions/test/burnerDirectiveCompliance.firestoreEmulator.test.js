'use strict';

const {createHash, randomUUID} = require('crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {mutateBurnerConditionRoundWithDb} = require('../lib/burnerConditionRoundMutation');
const {mutateBurnerDirectiveComplianceWithDb} = require('../lib/burnerDirectiveComplianceMutation');

jest.setTimeout(60000);
const host = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = host ? describe : describe.skip;
const PROJECT = 'demo-crm3-burner-compliance';
const SOURCE_AT = '2026-09-20T08:00:00.000Z';
const LATER_AT = '2026-09-20T09:00:00.000Z';
const CLOSED_AT = '2026-09-20T10:00:00.000Z';
const timestamp = (value) => Timestamp.fromDate(new Date(value));

// Real Admin SDK transactions, not fakeDb. Fixtures have unique identities in
// a dedicated demo namespace; cleanup removes only this suite's own documents.
// This does not claim callable/Auth transport or physical-device coverage.
describeWithEmulator('burner directive compliance real Firestore boundaries', () => {
  let app;
  let db;
  const paths = new Set();

  beforeAll(() => {
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
      throw new Error('Burner compliance tests require a loopback Firestore emulator.');
    }
    app = initializeApp({projectId: PROJECT}, `burner-compliance-${randomUUID()}`);
    db = getFirestore(app);
  });

  afterEach(async () => {
    if (!db) return;
    const batch = db.batch();
    for (const path of paths) batch.delete(db.doc(path));
    if (paths.size > 0) await batch.commit();
    paths.clear();
  });

  afterAll(async () => {
    if (db) await db.terminate();
    if (app) await deleteApp(app);
  });

  function track(path) {
    paths.add(path);
    return path;
  }

  function trackRound(id) {
    for (const collection of ['burner_condition_rounds', 'burner_condition_round_receipts']) {
      track(`${collection}/${id}`);
    }
    track(`directives/burner_round_red_hot_${id}`);
    return id;
  }

  async function state({except = []} = {}) {
    const keys = [...paths].filter((path) => !except.includes(path)).sort();
    const snapshots = await db.getAll(...keys.map((path) => db.doc(path)));
    return Object.fromEntries(snapshots.map((snapshot) => [snapshot.ref.path, {
      exists: snapshot.exists,
      data: snapshot.data() ?? null,
      updateTime: snapshot.updateTime ?? null,
    }]));
  }

  const read = async (path) => (await db.doc(path).get()).data();

  async function fixture({legacy = false} = {}) {
    const ids = {
      actor: `ia-${randomUUID()}`,
      observer: `operations-${randomUUID()}`,
      other: `other-${randomUUID()}`,
      asset: randomUUID(),
      assetClass: randomUUID(),
      source: trackRound(randomUUID()),
      closure: trackRound(randomUUID()),
    };
    const directiveId = `burner_round_red_hot_${ids.source}`;
    const actorPath = track(`users/${ids.actor}`);
    const assetPath = track(`asset_instances/${ids.asset}`);
    const pointerPath = track(`burner_condition_current/${ids.asset}`);
    const profile = (uid, roles) => ({
      uid, name: `DEV ${roles[0]} fixture`, email: `${uid}@example.invalid`,
      roles, isApproved: true, createdAt: timestamp(SOURCE_AT),
      photoUrl: null, fcmToken: null, authorityRevision: 1,
    });
    const rows = {
      [actorPath]: profile(ids.actor, ['seniorInstrumentation']),
      [track(`users/${ids.observer}`)]: profile(ids.observer, ['operations']),
      [track(`users/${ids.other}`)]: profile(ids.other, ['admin']),
      [track(`asset_classes/${ids.assetClass}`)]: {
        schemaVersion: 1, assetClassId: ids.assetClass, code: 'FURNACE',
        name: 'Furnace', legacyAssetTypeKey: 'furnace', status: 'active', version: 1,
      },
      [assetPath]: {
        schemaVersion: 1, assetInstanceId: ids.asset, assetClassId: ids.assetClass,
        assetClassCode: 'FURNACE', assetClassName: 'Furnace', assetNumber: 7,
        name: 'DEV Furnace 7', status: 'active', serviceState: 'inService', version: 4,
      },
    };
    const batch = db.batch();
    for (const [path, value] of Object.entries(rows)) batch.set(db.doc(path), value);
    await batch.commit();

    function roundRequest(id, {redHot = [3], damagedUv = [2], ...overrides} = {}) {
      trackRound(id);
      return {
        requestId: id, operation: 'RECORD_BURNER_CONDITION_ROUND',
        assetClassId: ids.assetClass, assetInstanceId: ids.asset, expectedAssetVersion: 4,
        observations: Array.from({length: 8}, (_, index) => ({
          position: index + 1, flameObservation: 'seen',
          redHotObserved: redHot.includes(index + 1),
          microampReading: index === 0 ? 3.7 : null, remarks: null,
        })),
        ...(legacy ? {} : {
          uvObservations: Array.from({length: 8}, (_, index) => ({
            position: index + 1,
            condition: damagedUv.includes(index + 1) ? 'melted' : 'serviceable',
            remarks: null,
          })),
          draftSealRedHotObserved: false, hotAirAtDraftSealObserved: false,
        }),
        roundNote: 'Synthetic real-transaction condition survey.',
        ...overrides,
      };
    }

    const survey = (data, at = LATER_AT) => mutateBurnerConditionRoundWithDb({
      db, authUid: ids.observer, data, now: () => new Date(at),
      timestampFromDate: Timestamp.fromDate,
    });
    await survey(roundRequest(ids.source), SOURCE_AT);
    // Acknowledge the actual producer's directive as a fixture prerequisite;
    // every compliance transition below still uses the real transaction handler.
    await db.doc(`directives/${directiveId}`).update({
      status: 'acknowledged', acknowledgedByUid: ids.actor,
      acknowledgedByName: 'DEV I&A fixture', acknowledgedAt: timestamp(SOURCE_AT),
      updatedAt: timestamp(SOURCE_AT), version: 2,
    });

    function request(overrides = {}) {
      if (overrides.requestId) trackRound(overrides.requestId);
      return {
        requestId: ids.closure, operation: 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
        assetClassId: ids.assetClass, assetInstanceId: ids.asset, expectedAssetVersion: 4,
        expectedCurrentRoundId: ids.source, directiveId, expectedDirectiveVersion: 2,
        dispositions: [{position: 3, disposition: 'restoredInService'}],
        closureRemarks: 'Recorded I&A compliance; no automatic plant actuation.',
        ...overrides,
      };
    }
    const invoke = (data = request(), {database = db, actorUid = ids.actor} = {}) =>
      mutateBurnerDirectiveComplianceWithDb({db: database, authUid: actorUid, data,
        now: () => new Date(CLOSED_AT), timestampFromDate: Timestamp.fromDate});
    return {ids, directiveId, actorPath, assetPath, pointerPath, roundRequest, survey, request, invoke};
  }

  test.each([
    ['restoredInService', 'serviceable'], ['uvMelted', 'melted'],
    ['uvMissing', 'missing'], ['uvHungRemoved', 'hanging'],
  ])('later-clear %s closes atomically and replays after another round without writes', async (disposition, condition) => {
    const f = await fixture();
    const laterId = randomUUID();
    await f.survey(f.roundRequest(laterId, {redHot: []}));
    const sourceBefore = await read(`burner_condition_rounds/${f.ids.source}`);
    expect(sourceBefore.observedAt).toBeInstanceOf(Timestamp);
    const data = f.request({expectedCurrentRoundId: laterId,
      dispositions: [{position: 3, disposition}]});
    const accepted = await f.invoke(data);
    expect(accepted).toMatchObject({ok: true, idempotentReplay: false,
      closedDirectiveId: f.directiveId, closedDirectiveVersion: 3, newDirectiveId: null});
    const recorded = await read(`burner_condition_rounds/${f.ids.closure}`);
    expect(recorded).toMatchObject({evidenceKind: 'directiveCompliance', baselineRoundId: laterId,
      recordedByUid: f.ids.actor, redHotPositions: [], directivePositions: []});
    expect(recorded.observedAt).toEqual(timestamp(CLOSED_AT));
    expect(recorded.uvObservations[2].condition).toBe(condition);
    expect(recorded.observations[2]).toMatchObject({redHotObserved: false,
      flameObservation: disposition === 'restoredInService' ? 'seen' : 'notOperating'});
    expect(await read(`directives/${f.directiveId}`)).toMatchObject({status: 'closed',
      isActive: false, closedByUid: f.ids.actor, closedAt: timestamp(CLOSED_AT), version: 3});
    expect(await read(f.pointerPath)).toMatchObject({roundId: f.ids.closure});
    expect(await read(`burner_condition_round_receipts/${f.ids.closure}`)).toMatchObject({
      actorUid: f.ids.actor, evidenceVersion: 1, committedAt: timestamp(CLOSED_AT),
      baselineRoundId: laterId, roundEvidenceSha256: expect.stringMatching(/^[a-f0-9]{64}$/),
    });
    expect(await read(`burner_condition_rounds/${f.ids.source}`)).toEqual(sourceBefore);
    let beforeReplay = await state();
    expect(await f.invoke(data)).toEqual({...accepted, idempotentReplay: true});
    expect(await state()).toEqual(beforeReplay);

    const newestId = randomUUID();
    await f.survey(f.roundRequest(newestId, {redHot: []}), '2026-09-20T11:00:00.000Z');
    beforeReplay = await state();
    expect(await f.invoke(data)).toEqual({...accepted, idempotentReplay: true});
    expect(await state()).toEqual(beforeReplay);
    expect(await read(f.pointerPath)).toMatchObject({roundId: newestId});
  });

  test('partial baseline retains old UV damage and measurement ages while another red-hot position receives a successor', async () => {
    const f = await fixture();
    const partialId = randomUUID();
    await f.survey(f.roundRequest(partialId, {redHot: [4], damagedUv: [],
      expectedCurrentRoundId: f.ids.source, observedFields: ['burners.4.redHotObserved'],
      expectedInstallationBasis: {burner: [], uv: []}, expectedOpenIssueBasis: [],
    }));
    const baseline = await read(`burner_condition_rounds/${partialId}`);
    expect(baseline).toMatchObject({evidenceKind: 'partialInspection', redHotPositions: [3, 4]});
    expect(baseline.uvObservations[1].condition).toBe('melted');
    const sourceBefore = await read(`burner_condition_rounds/${f.ids.source}`);
    const accepted = await f.invoke(f.request({expectedCurrentRoundId: partialId}));
    const after = await read(`burner_condition_rounds/${f.ids.closure}`);
    expect(after.uvObservations[1]).toEqual(baseline.uvObservations[1]);
    for (const field of ['uv.2.condition', 'burners.1.microampReading']) {
      expect(after.evidenceProvenance[field]).toMatchObject({kind: 'inherited',
        sourceRoundId: f.ids.source, observedAt: SOURCE_AT, observerUid: f.ids.observer});
    }
    expect(after.evidenceProvenance['burners.3.redHotObserved']).toMatchObject({
      kind: 'directiveDisposition', sourceRoundId: f.ids.closure,
      observedAt: CLOSED_AT, observerUid: f.ids.actor,
    });
    expect(after.redHotPositions).toEqual([4]);
    expect(accepted.newDirectiveId).toBe(`burner_round_red_hot_${f.ids.closure}`);
    const successor = await read(`directives/${accepted.newDirectiveId}`);
    expect(successor).toMatchObject({status: 'open', directedTo: 'seniorInstrumentation'});
    expect(JSON.parse(successor.metadataJson)).toMatchObject({burnerPositions: [4], automaticPlantActuation: false});
    expect(await read(`burner_condition_rounds/${partialId}`)).toEqual(baseline);
    expect(await read(`burner_condition_rounds/${f.ids.source}`)).toEqual(sourceBefore);
    const beforeReplay = await state();
    expect(await f.invoke(f.request({expectedCurrentRoundId: partialId})))
      .toEqual({...accepted, idempotentReplay: true});
    expect(await state()).toEqual(beforeReplay);
  });

  test.each(['current pointer', 'legacy query fallback'])('%s refuses a stale round without any business or receipt write', async (mode) => {
    const f = await fixture();
    const laterId = randomUUID();
    await f.survey(f.roundRequest(laterId, {redHot: [3, 4]}));
    if (mode === 'legacy query fallback') await db.doc(f.pointerPath).delete();
    const before = await state();
    await expect(f.invoke()).rejects.toMatchObject({code: 'aborted', details: {
      reasonCode: 'burner-directive-compliance-current-round-mismatch', currentRoundId: laterId,
    }});
    expect(await state()).toEqual(before);
  });

  test('partial-round prerequisite fences changed installed UV evidence before compliance can use that baseline', async () => {
    const f = await fixture();
    const partialId = randomUUID();
    const data = f.roundRequest(partialId, {expectedCurrentRoundId: f.ids.source,
      observedFields: ['burners.4.redHotObserved'], expectedInstallationBasis: {burner: [], uv: []},
      expectedOpenIssueBasis: [],
    });
    const projectionId = `uvlc_${createHash('sha256').update(`${f.ids.asset}|2`).digest('hex').slice(0, 40)}`;
    const projectionPath = track(`uv_detector_lifecycle_current/${projectionId}`);
    const installedAt = '2026-09-20T08:30:00.000Z';
    const eventId = `installation-${randomUUID()}`;
    await db.doc(projectionPath).set({schemaVersion: 1, projectionSchemaVersion: 1,
      projectionId, assetInstanceId: f.ids.asset, burnerPosition: 2, eventId, currentEventId: eventId,
      installationDiscipline: 'instrumentation', resultingCondition: 'serviceable',
      actionPerformedAt: timestamp(installedAt),
    });
    const before = await state();
    await expect(f.survey(data)).rejects.toMatchObject({code: 'aborted',
      details: {reasonCode: 'burner-condition-round-installation-basis-mismatch'}});
    expect(await state()).toEqual(before);
    // A new reviewed intent with the actual installation basis is admissible;
    // the inherited damaged observation is still not relabelled as a new survey.
    await f.survey({...data, expectedInstallationBasis: {burner: [], uv: [
      {position: 2, eventId, actionPerformedAt: installedAt},
    ]}});
    expect((await read(`burner_condition_rounds/${partialId}`)).uvObservations[1].condition).toBe('melted');
    await f.invoke(f.request({expectedCurrentRoundId: partialId}));
    expect(await read(projectionPath)).toEqual(before[projectionPath].data);
  });

  test('current asset version and missing legacy UV evidence refuse write-free', async () => {
    const f = await fixture({legacy: true});
    let before = await state();
    await expect(f.invoke()).rejects.toMatchObject({code: 'failed-precondition',
      details: {reasonCode: 'burner-directive-compliance-round-evidence-unavailable'}});
    expect(await state()).toEqual(before);
    await db.doc(f.assetPath).update({version: 5});
    before = await state();
    await expect(f.invoke()).rejects.toMatchObject({code: 'aborted',
      details: {reasonCode: 'burner-directive-compliance-asset-version-mismatch'}});
    expect(await state()).toEqual(before);
  });

  test.each([{isApproved: false}, {roles: ['seniorMechanical']}])('transaction rechecks current actor after preflight: %j', async (change) => {
    const f = await fixture();
    const before = await state({except: [f.actorPath]});
    const database = {collection: (name) => db.collection(name), runTransaction: async (body) => {
      await db.doc(f.actorPath).update(change);
      return db.runTransaction(body);
    }};
    await expect(f.invoke(f.request(), {database})).rejects.toMatchObject({code: 'permission-denied',
      details: {reasonCode: 'burner-directive-compliance-role-denied'}});
    expect(await state({except: [f.actorPath]})).toEqual(before);
    expect(await read(f.actorPath)).toMatchObject(change);
  });

  test('current I&A role alone cannot close another recipient\'s acknowledgement', async () => {
    const f = await fixture();
    await db.doc(`directives/${f.directiveId}`).update({acknowledgedByUid: f.ids.other});
    const before = await state();
    await expect(f.invoke()).rejects.toMatchObject({code: 'permission-denied',
      details: {reasonCode: 'burner-directive-compliance-close-role-denied'}});
    expect(await state()).toEqual(before);
  });

  test.each(['different actor', 'changed payload', 'revoked original actor'])('accepted replay refuses %s without changing retained evidence', async (kind) => {
    const f = await fixture();
    await f.invoke();
    if (kind === 'revoked original actor') await db.doc(f.actorPath).update({isApproved: false});
    const before = await state();
    const data = kind === 'changed payload' ? f.request({closureRemarks: 'Different intent.'}) : f.request();
    await expect(f.invoke(data, {actorUid: kind === 'different actor' ? f.ids.other : f.ids.actor}))
      .rejects.toMatchObject({code: kind === 'revoked original actor' ? 'permission-denied' : 'already-exists'});
    expect(await state()).toEqual(before);
  });

  test.each(['accepted round', 'retained baseline'])('replay detects valid-shaped inherited-evidence tampering in %s', async (target) => {
    const f = await fixture();
    await f.invoke();
    const path = `burner_condition_rounds/${target === 'accepted round' ? f.ids.closure : f.ids.source}`;
    const changed = await read(path);
    changed.observations[0].microampReading = 9.2;
    await db.doc(path).set(changed);
    const before = await state();
    await expect(f.invoke()).rejects.toMatchObject({code: 'data-loss',
      details: {reasonCode: 'burner-directive-compliance-replay-evidence-drift'}});
    expect(await state()).toEqual(before);
  });

  test('failure before receipt commit leaves no partial closure, round, pointer or receipt', async () => {
    const f = await fixture();
    const before = await state();
    const database = {collection: (name) => db.collection(name), runTransaction: (body) =>
      db.runTransaction((transaction) => body({get: (ref) => transaction.get(ref), set: (ref, data, options) => {
        if (ref.path === `burner_condition_round_receipts/${f.ids.closure}`) throw new Error('Injected receipt write failure');
        return options ? transaction.set(ref, data, options) : transaction.set(ref, data);
      }}))};
    await expect(f.invoke(f.request(), {database})).rejects.toThrow('Injected receipt write failure');
    expect(await state()).toEqual(before);
  });

  test('competing closures serialize to one accepted outcome and one write-free refusal', async () => {
    const f = await fixture();
    const otherId = randomUUID();
    const commands = [f.request(), f.request({requestId: otherId})];
    const sourceBefore = await read(`burner_condition_rounds/${f.ids.source}`);
    const results = await Promise.allSettled(commands.map((data) => f.invoke(data)));
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    const rejectedIndex = results.findIndex((result) => result.status === 'rejected');
    expect(results[rejectedIndex].reason).toMatchObject({code: 'aborted'});
    const loser = commands[rejectedIndex].requestId;
    for (const collection of ['burner_condition_rounds', 'burner_condition_round_receipts']) {
      expect((await db.doc(`${collection}/${loser}`).get()).exists).toBe(false);
    }
    expect((await db.doc(`directives/burner_round_red_hot_${loser}`).get()).exists).toBe(false);
    const accepted = results.find((result) => result.status === 'fulfilled').value;
    expect(await read(f.pointerPath)).toMatchObject({roundId: accepted.roundId});
    expect(await read(`directives/${f.directiveId}`)).toMatchObject({status: 'closed', version: 3});
    expect(await read(`burner_condition_rounds/${f.ids.source}`)).toEqual(sourceBefore);
  });
});
