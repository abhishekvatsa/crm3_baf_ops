const admin = require('firebase-admin');
const {mutateMorningReviewWithDb} = require('../lib/morningReviewMutation');
const {executeMorningReviewWithRefusalFence} = require('../lib/morningReviewRecovery');
const {AssetHierarchyMutationError} = require('../lib/assetHierarchyMutation');
const host = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || '';
const local = host ? describe : describe.skip;
jest.setTimeout(60000);

local('Morning Review refusal fence on real Firestore transactions', () => {
  let app, db;
  const now = new Date('2026-09-20T03:00:00Z');
  const id = (n) => `87654321-0000-4000-8000-${String(n).padStart(12, '0')}`;
  const invoke = (data) => mutateMorningReviewWithDb({db, authUid: 'admin', data, now: () => now,
    timestampFromDate: admin.firestore.Timestamp.fromDate});
  const refuse = (request) => executeMorningReviewWithRefusalFence({db, actorUid: 'admin', request,
    execute: async () => { throw new AssetHierarchyMutationError('aborted', 'Version changed in competing attempt'); },
    accepted: (receipt) => ({ok: true, ...receipt.result, idempotentReplay: true}), now: () => now});
  beforeAll(async () => {
    if (!/^127\.0\.0\.1:\d+$/.test(host) ||
        !['demo-morning-review-regression', 'demo-crm3-governed'].includes(projectId)) {
      throw new Error('Only the isolated local demo emulator is authorized for this regression.');
    }
    app = admin.initializeApp({projectId}, `morning-review-${process.pid}`);
    db = app.firestore();
  });
  beforeEach(async () => {
    const response = await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error('Local emulator fixture reset failed');
    await db.doc('users/admin').set({isApproved: true, roles: ['admin'], name: 'Administrator'});
    await db.doc('critical_alarms/emulator-alarm').set({status: 'open', title: 'Retained source alarm',
      raisedAt: admin.firestore.Timestamp.fromDate(new Date(now.valueOf() - 60000)),
      updatedAt: admin.firestore.Timestamp.fromDate(new Date(now.valueOf() - 60000))});
    await invoke({requestId: id(1), operation: 'START_MORNING_REVIEW', recoveryVersion: 1});
  });
  afterAll(async () => { if (app) await app.delete(); });
  const entry = () => ({requestId: id(2), operation: 'ADD_MORNING_REVIEW_ENTRY', sessionId: '2026-09-20', recoveryVersion: 1,
    entryDraft: {section: 'plantWide', kind: 'update', text: 'Exactly one original contribution', assetClassId: null,
      assetClassName: null, assetInstanceId: null, assetNumber: null, sourceReferences: []}});

  test('competing acceptance and refusal cannot both commit', async () => {
    const request = entry();
    const outcomes = await Promise.allSettled([invoke(request), refuse(request)]);
    const [receipt, fence, record] = await Promise.all([
      db.doc(`morning_review_mutation_receipts/${request.requestId}`).get(),
      db.doc(`morning_review_refusals/${request.requestId}`).get(),
      db.doc(`morning_review_entries/${request.requestId}`).get(),
    ]);
    expect(Number(receipt.exists) + Number(fence.exists)).toBe(1);
    expect(record.exists).toBe(receipt.exists);
    if (receipt.exists) {
      expect(outcomes.every((outcome) => outcome.status === 'fulfilled')).toBe(true);
    } else {
      expect(outcomes.every((outcome) => outcome.status === 'rejected' && outcome.reason.details.morningReviewRefusal.request.requestId === request.requestId)).toBe(true);
    }
  });

  test('permanent refusal blocks a late original request and accepted replay wins over a later refusal', async () => {
    const request = entry();
    await expect(refuse(request)).rejects.toMatchObject({code: 'aborted'});
    await expect(invoke(request)).rejects.toMatchObject({details: {morningReviewRefusal: {request}}});
    expect((await db.doc(`morning_review_entries/${request.requestId}`).get()).exists).toBe(false);
    const fresh = {...request, requestId: id(3)};
    const accepted = await invoke(fresh);
    await expect(refuse(fresh)).resolves.toEqual({...accepted, idempotentReplay: true});
    expect((await db.doc(`morning_review_refusals/${fresh.requestId}`).get()).exists).toBe(false);
  });

  test('source integrity survives Firestore conversion and blocks altered capture before finalization', async () => {
    await invoke(entry());
    const ref = db.doc('morning_review_sessions/2026-09-20');
    const original = (await ref.get()).data();
    expect(original.openedAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(original.sourceFacts.length).toBeGreaterThan(0);
    expect(typeof original.sourceFacts[0].observedAtIso).toBe('string');
    await ref.update({sourceFactCount: original.sourceFactCount + 1});
    const finish = {requestId: id(4), operation: 'FINALIZE_MORNING_REVIEW', recoveryVersion: 1,
      sessionId: '2026-09-20', expectedVersion: original.version, summary: 'Reviewed original population'};
    await expect(invoke(finish)).rejects.toMatchObject({code: 'data-loss', details: {reasonCode: 'morning-review-source-integrity-mismatch'}});
    expect((await db.doc('morning_review_documents/2026-09-20').get()).exists).toBe(false);
    await ref.update({sourceFactCount: original.sourceFactCount});
    await expect(invoke(finish)).resolves.toMatchObject({status: 'finalized'});
    const document = (await db.doc('morning_review_documents/2026-09-20').get()).data();
    expect(document.sourceFactDigest).toBe(original.sourceFactDigest);
    expect(document.entries).toHaveLength(1);
    expect(document.finalizedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test('retained population manifest verifies native Timestamp children and detects missing entries', async () => {
    await invoke(entry());
    const session = (await db.doc('morning_review_sessions/2026-09-20').get()).data();
    expect(session.expiresAt).toBeNull();
    await db.doc(`morning_review_entries/${id(2)}`).delete();
    await expect(invoke({requestId: id(4), operation: 'FINALIZE_MORNING_REVIEW', recoveryVersion: 1,
      sessionId: '2026-09-20', expectedVersion: session.version, summary: 'Cannot certify missing minutes'}))
      .rejects.toMatchObject({code: 'data-loss', details: {reasonCode: 'morning-review-population-incomplete'}});
    expect((await db.doc('morning_review_documents/2026-09-20').get()).exists).toBe(false);
  });
});
