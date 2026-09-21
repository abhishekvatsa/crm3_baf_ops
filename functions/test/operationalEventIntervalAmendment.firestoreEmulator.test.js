const admin = require('firebase-admin');
const {mutateOperationalEventWithDb} = require('../lib/operationalEventMutation');
const {executeOriginBoundCallable} = require('../lib/originBoundCallableProtocol');

jest.setTimeout(60000);
const host = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || 'demo-operational-amendment';
const describeWithEmulator = host ? describe : describe.skip;
const eventId = '11111111-1111-4111-8111-111111111111';
const createId = '22222222-2222-4222-8222-222222222222';
const resolveId = '33333333-3333-4333-8333-333333333333';
const amendmentId = '44444444-4444-4444-8444-444444444444';
const secondId = '55555555-5555-4555-8555-555555555555';
const reopenId = '66666666-6666-4666-8666-666666666666';
const timestamp = iso => admin.firestore.Timestamp.fromDate(new Date(iso));
const command = overrides => ({requestId: amendmentId, operation: 'AMEND_OPERATIONAL_EVENT_INTERVAL', eventId,
  expectedVersion: 2, reason: 'Correct verified shift-log restoration time.', intervalAmendment: {occurrenceIndex: 0,
    expectedEffectiveResolvedAt: '2026-08-14T11:00:00.000Z', correctedResolvedAt: '2026-08-14T10:45:00.000Z', supersedesAmendmentId: null}, ...overrides});

describeWithEmulator('native operational interval amendment', () => {
  let app, db;
  const call = (data, uid = 'admin-1', now = '2026-08-14T12:00:00.000Z') => executeOriginBoundCallable({
    callableName: 'mutateAssetHierarchyV2', authUid: uid,
    data: {protocolVersion: 2, originActorUid: uid, request: data},
    readActor: async actorUid => (await db.collection('users').doc(actorUid).get()).data(),
    execute: request => mutateOperationalEventWithDb({db, authUid: uid, data: request,
      now: () => new Date(now), timestampFromDate: admin.firestore.Timestamp.fromDate}),
  });
  const ref = () => db.collection('operational_events').doc(eventId);
  const correction = () => db.collection('operational_event_interval_amendments').doc(amendmentId);
  const evidence = async () => Promise.all(['operational_events', 'operational_event_interval_amendments',
    'operational_event_audits', 'operational_event_receipts'].map(async collection => {
    const snapshot = await db.collection(collection).get();
    return snapshot.docs.map(doc => ({id: doc.id, data: doc.data(), updateTime: doc.updateTime}))
      .sort((left, right) => left.id.localeCompare(right.id));
  }));
  beforeAll(() => {
    app = admin.initializeApp({projectId}, `interval-amendment-${process.pid}`);
    db = app.firestore();
  });
  beforeEach(async () => {
    const response = await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error(await response.text());
    for (const [uid, role] of [['admin-1', 'admin'], ['si-1', 'si'], ['ops-1', 'operations']]) {
      await db.collection('users').doc(uid).set({name: uid, roles: [role], isApproved: true});
    }
    await call({requestId: createId, operation: 'CREATE_OPERATIONAL_EVENT', eventId, expectedVersion: 0,
      reason: 'Record actual power interruption.', eventDraft: {eventType: 'powerTrip', title: 'Power interrupted',
        description: 'Supply interruption recorded by Operations.', severity: 'critical', scope: 'plantWide',
        affectedAssetClassIds: [], affectedAssetInstanceIds: [], startedAt: '2026-08-14T10:00:00.000Z'}},
    'ops-1', '2026-08-14T10:05:00.000Z');
    await call({requestId: resolveId, operation: 'RESOLVE_OPERATIONAL_EVENT', eventId, expectedVersion: 1,
      reason: 'Operations verified supply restoration.', resolutionNote: 'Supply stable.', resolvedAt: '2026-08-14T11:00:00.000Z'},
    'ops-1', '2026-08-14T11:05:00.000Z');
  });
  afterAll(async () => { if (app) await app.delete(); });

  test('atomic concurrent retry preserves raw native timestamps and replays after recurrence', async () => {
    const original = (await ref().get()).data();
    const outcomes = await Promise.all(Array.from({length: 4}, () => call(command())));
    expect(outcomes.filter(value => !value.idempotentReplay)).toHaveLength(1);
    const first = outcomes.find(value => !value.idempotentReplay);
    const stored = (await ref().get()).data();
    expect(stored.resolvedAt).toEqual(original.resolvedAt);
    expect(stored.completedIntervals).toEqual(original.completedIntervals);
    expect(stored.intervalEndAmendments['0']).toMatchObject({amendmentId, correctedResolvedAt: timestamp('2026-08-14T10:45:00.000Z')});
    expect((await correction().get()).data().amendedAt).toEqual(timestamp('2026-08-14T12:00:00.000Z'));
    expect((await db.collection('operational_event_interval_amendments').get()).size).toBe(1);
    await call({requestId: reopenId, operation: 'REOPEN_OPERATIONAL_EVENT', eventId, expectedVersion: 3,
      reason: 'Supply failed again after physical restoration.'}, 'ops-1', '2026-08-14T12:05:00.000Z');
    const after = await evidence();
    expect(await call(command())).toEqual({...first, idempotentReplay: true});
    expect(await evidence()).toEqual(after);
    expect((await ref().get()).data().completedIntervals[0].resolvedAt).toEqual(original.resolvedAt);
  });

  test('competing different reviewed corrections cannot both commit', async () => {
    const results = await Promise.allSettled([call(command()), call(command({requestId: secondId}), 'si-1')]);
    expect(results.filter(value => value.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter(value => value.status === 'rejected')).toHaveLength(1);
    expect((await db.collection('operational_event_interval_amendments').get()).size).toBe(1);
    expect((await ref().get()).data().version).toBe(3);
  });

  test('archived correction preserves current recurrence and rejects overlap without writes', async () => {
    await call({requestId: reopenId, operation: 'REOPEN_OPERATIONAL_EVENT', eventId, expectedVersion: 2,
      reason: 'Actual recurrence after restoration.'}, 'ops-1', '2026-08-14T11:30:00.000Z');
    const input = command({expectedVersion: 3});
    await call(input, 'si-1');
    const stored = (await ref().get()).data();
    expect(stored.status).toBe('open');
    expect(stored.startedAt).toEqual(timestamp('2026-08-14T11:30:00.000Z'));
    expect(stored.resolvedAt).toBeNull();
    const before = await evidence();
    await expect(call(command({requestId: secondId, expectedVersion: 4, intervalAmendment: {occurrenceIndex: 0,
      expectedEffectiveResolvedAt: '2026-08-14T10:45:00.000Z', correctedResolvedAt: '2026-08-14T11:31:00.000Z', supersedesAmendmentId: amendmentId}})))
      .rejects.toMatchObject({details: {reasonCode: 'operational-interval-amendment-chronology'}});
    expect(await evidence()).toEqual(before);
  });

  test('original actor boundary and explicit supervisory review are enforced', async () => {
    const before = await evidence();
    await expect(call(command(), 'ops-1')).rejects.toMatchObject({code: 'permission-denied'});
    await expect(executeOriginBoundCallable({callableName: 'mutateAssetHierarchyV2', authUid: 'si-1',
      data: {protocolVersion: 2, originActorUid: 'admin-1', request: command()}, readActor: async () => null,
      execute: () => {throw new Error('must not execute');}})).rejects.toMatchObject({code: 'permission-denied'});
    expect(await evidence()).toEqual(before);
  });

  test.each(['archive', 'amendment native precision', 'audit native precision', 'audit after-image precision', 'receipt native precision', 'receipt result', 'missing digest'])(
    'immutable replay refuses %s corruption', async kind => {
      await call(command());
      if (kind === 'archive') await correction().update({originalIntervalJson: '{}'});
      if (kind === 'amendment native precision') await correction().update({amendedAt: new admin.firestore.Timestamp(timestamp('2026-08-14T12:00:00.000Z').seconds, 1000)});
      const audit = db.collection('operational_event_audits').doc(`operational_event_${amendmentId}`);
      const receipt = db.collection('operational_event_receipts').doc(amendmentId);
      if (kind === 'audit native precision') await audit.update({performedAt: new admin.firestore.Timestamp(timestamp('2026-08-14T12:00:00.000Z').seconds, 1000)});
      if (kind === 'audit after-image precision') await audit.update({'after.updatedAt': new admin.firestore.Timestamp(timestamp('2026-08-14T12:00:00.000Z').seconds, 1000)});
      if (kind === 'receipt native precision') await receipt.update({committedAt: new admin.firestore.Timestamp(timestamp('2026-08-14T12:00:00.000Z').seconds, 1000)});
      if (kind === 'receipt result') await receipt.update({occurrenceIndex: 1});
      if (kind === 'missing digest') await receipt.update({evidenceDigest: admin.firestore.FieldValue.delete()});
      // Replay must use retained acceptance even when the live row no longer exists.
      await ref().delete();
      const before = await evidence();
      await expect(call(command())).rejects.toBeDefined();
      expect(await evidence()).toEqual(before);
    });
});
