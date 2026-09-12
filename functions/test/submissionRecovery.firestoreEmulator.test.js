const admin = require('firebase-admin');
const {reviewSavedSubmissionWithDb, withSubmissionRecoveryFence, submissionRecoveryFenceId,
  SUBMISSION_RECOVERY_DOMAINS} = require('../lib/submissionRecovery');
const f = require('./submissionRecoveryFixtures.cjs');
const host = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || 'demo-submission-recovery';
const describeEmulator = host ? describe : describe.skip;
jest.setTimeout(45000);

describeEmulator('saved-submission finality on actual Firestore transactions and V1/V2 callables', () => {
  let db; let endpoints;
  const callRequest = (data, uid = 'admin') => ({data, auth: {uid, token: {name: uid}}});
  const review = (domain, data) => endpoints[SUBMISSION_RECOVERY_DOMAINS[domain].endpoint].run(callRequest({
    protocolVersion: 2, originActorUid: 'admin', recovery: data}));
  const directReview = (data, database = db) => reviewSavedSubmissionWithDb({db: database,
    endpoint: SUBMISSION_RECOVERY_DOMAINS[data.domain].endpoint, authUid: 'admin', data});
  const receiptPath = (domain) => `${SUBMISSION_RECOVERY_DOMAINS[domain].receipts}/${f.requestId}`;
  const evidence = async () => {
    const rows = [];
    for (const collection of await db.listCollections()) {
      for (const snapshot of (await collection.get()).docs) rows.push([snapshot.ref.path, snapshot.data(), snapshot.updateTime]);
    }
    return rows.sort(([a], [b]) => a.localeCompare(b));
  };
  beforeAll(() => {
    if (!projectId.startsWith('demo-')) throw new Error('Isolated demo project required.');
    endpoints = require('../lib/index'); db = admin.firestore();
  });
  beforeEach(async () => {
    const response = await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error('Emulator reset failed.');
    await db.doc('users/admin').set({isApproved: true, roles: ['admin'], name: 'Admin'});
  });
  afterAll(async () => {await admin.app().delete();});

  test.each(f.domains)('%s: actual V2 review is read-only, activation defaults off, permanent cancellation fences both V1/V2', async (domain) => {
    const request = f.review(domain); const before = await evidence();
    const observation = await review(domain, request);
    expect(Object.keys(observation).sort()).toEqual(f.inspectionKeys);
    expect(await evidence()).toEqual(before);
    const finalize = {...request, phase: 'finalize', reviewToken: observation.reviewToken};
    await expect(review(domain, finalize)).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
    expect(await evidence()).toEqual(before);
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const proof = await review(domain, finalize);
    expect(proof).toMatchObject({outcome: 'cancelled', originalActorUid: null, receiptSha256: null});
    const settled = await evidence();
    expect(await review(domain, {...request, reason: 'Retrieve this completed review after a restart.'})).toEqual(proof);
    const endpoint = SUBMISSION_RECOVERY_DOMAINS[domain].endpoint;
    const payload = f.original(domain); const key = domain === 'inspectionCampaign' ? 'command' : 'request';
    for (const [name, data] of [[endpoint.replace(/V2$/, ''), payload], [endpoint, {protocolVersion: 2, originActorUid: 'admin', [key]: payload}]]) {
      await expect(endpoints[name].run(callRequest(data))).rejects.toMatchObject({details: {reasonCode: 'saved-submission-cancelled'}});
      expect(await evidence()).toEqual(settled); // includes quota: refusal precedes even that write.
    }
    expect((await db.doc(`submission_recovery_fences/${submissionRecoveryFenceId(domain, f.requestId)}`).get()).data().expiresAt).toBeUndefined();
  });

  test.each(f.domains)('%s: receipt review remains distinct from replay; origin mismatch, corruption and stored drift fail closed', async (domain) => {
    await db.doc(receiptPath(domain)).set(f.receipt(domain));
    const request = f.review(domain); const observation = await review(domain, request);
    expect(observation.observation).toBe('receiptPresent');
    const before = await evidence();
    await expect(review(domain, {...request, phase: 'finalize', reviewToken: observation.reviewToken}))
      .rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
    expect(await evidence()).toEqual(before);
    await expect(review(domain, {...request, originalActorUid: 'wrong-origin'})).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-original-actor-mismatch'}});
    expect(await evidence()).toEqual(before);
    await db.doc(receiptPath(domain)).update({extraReviewedEvidence: new admin.firestore.Timestamp(1789257600, 1000)});
    const drift = await db.doc(receiptPath(domain)).get();
    expect(drift.data().extraReviewedEvidence.nanoseconds).toBe(1000);
    await expect(review(domain, {...request, phase: 'finalize', reviewToken: observation.reviewToken})).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-observation-changed'}});
    const current = await review(domain, request);
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const proof = await review(domain, {...request, phase: 'finalize', reviewToken: current.reviewToken});
    expect(proof.outcome).toBe('reviewedExisting');
    const hold = (await db.doc(`submission_recovery_fences/${submissionRecoveryFenceId(domain, f.requestId)}`).get()).data();
    expect(hold).toMatchObject({...proof, protocol: 'savedSubmissionReview.v1'});
    expect(hold.expiresAt).toBeUndefined();
    await db.doc(receiptPath(domain)).delete(); // Simulates the receipt's declared TTL.
    await db.doc('submission_recovery_controls/activation').delete();
    const settled = await evidence();
    expect(await review(domain, {...request, reason: 'Retrieve the earlier accepted review after its reply was lost.'})).toEqual(proof);
    const endpoint = SUBMISSION_RECOVERY_DOMAINS[domain].endpoint;
    const payload = f.original(domain); const key = domain === 'inspectionCampaign' ? 'command' : 'request';
    for (const [name, data] of [[endpoint.replace(/V2$/, ''), payload], [endpoint, {protocolVersion: 2, originActorUid: 'admin', [key]: payload}]]) {
      await expect(endpoints[name].run(callRequest(data))).rejects.toMatchObject({details: {reasonCode: 'saved-submission-reviewed-existing'}});
      expect(await evidence()).toEqual(settled);
    }
    await db.doc(receiptPath(domain)).set({schemaVersion: 999, actorUid: 'original'});
    await expect(review(domain, request)).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-receipt-malformed'}});
  });

  test.each([
    ['innerCoverAcceptance', {operation: 'REGISTER_INNER_COVER'}],
    ['qualityMonitoring', {operation: 'CLOSE_QUALITY_MONITORING_REQUEST'}],
    ['inspectionCampaign', {commandType: 'upsertInspectionDefinition'}],
  ].flatMap((row) => ['cancelled', 'reviewedExisting'].map((outcome) => [...row, outcome])))('%s receipt namespace rejects changed operations through actual V1 and V2 (%j, %s)', async (domain, changed, outcome) => {
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    if (outcome === 'reviewedExisting') await db.doc(receiptPath(domain)).set(f.receipt(domain));
    const request = f.review(domain); const inspection = await review(domain, request);
    await review(domain, {...request, phase: 'finalize', reviewToken: inspection.reviewToken});
    if (outcome === 'reviewedExisting') await db.doc(receiptPath(domain)).delete();
    const before = await evidence(); const endpoint = SUBMISSION_RECOVERY_DOMAINS[domain].endpoint;
    const payload = {...f.original(domain), ...changed};
    const key = domain === 'inspectionCampaign' ? 'command' : 'request';
    for (const [name, data] of [[endpoint.replace(/V2$/, ''), payload],
      [endpoint, {protocolVersion: 2, originActorUid: 'admin', [key]: payload}]]) {
      await expect(endpoints[name].run(callRequest(data))).rejects.toMatchObject({details: {reasonCode: outcome === 'cancelled' ? 'saved-submission-cancelled' : 'saved-submission-reviewed-existing'}});
      expect(await evidence()).toEqual(before);
    }
    expect((await db.doc(receiptPath(domain)).get()).exists).toBe(false);
  });

  test('a request already waiting for its transaction cannot commit after cancellation', async () => {
    const domain = 'qualityMonitoring'; const request = f.review(domain);
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const observation = await directReview(request);
    let release; let started;
    const waiting = new Promise((resolve) => {release = resolve;});
    const arrived = new Promise((resolve) => {started = resolve;});
    const delayedDb = new Proxy(db, {get(target, key) {
      if (key === 'runTransaction') return async (...args) => {started(); await waiting; return target.runTransaction(...args);};
      const value = Reflect.get(target, key, target); return typeof value === 'function' ? value.bind(target) : value;
    }});
    const original = withSubmissionRecoveryFence(delayedDb, 'mutateChargeAbnormality', f.original(domain));
    const pending = original.runTransaction(async (tx) => {tx.create(db.doc(receiptPath(domain)), f.receipt(domain)); return 'accepted';});
    const handled = pending.then((value) => ({value}), (error) => ({error}));
    await arrived;
    const proof = await directReview({...request, phase: 'finalize', reviewToken: observation.reviewToken});
    release();
    expect(proof.outcome).toBe('cancelled');
    expect((await handled).error).toMatchObject({details: {reasonCode: 'saved-submission-cancelled'}});
    expect((await db.doc(receiptPath(domain)).get()).exists).toBe(false);
  });

  test('overlapping original transaction and cancellation finalization have one durable winner, never receipt plus cancellation fence', async () => {
    const domain = 'qualityMonitoring'; const request = f.review(domain);
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const observation = await directReview(request);
    const originalDb = withSubmissionRecoveryFence(db, 'mutateChargeAbnormality', f.original(domain));
    let release; let entered;
    const wait = new Promise((resolve) => {release = resolve;});
    const arrival = new Promise((resolve) => {entered = resolve;});
    let attempts = 0;
    const original = originalDb.runTransaction(async (tx) => {
      attempts++; entered(); await wait;
      tx.create(db.doc(receiptPath(domain)), f.receipt(domain)); return 'accepted';
    }).then((value) => ({value}), (error) => ({error}));
    await arrival;
    const finalizing = directReview({...request, phase: 'finalize', reviewToken: observation.reviewToken})
      .then((value) => ({value}), (error) => ({error}));
    // Both transactions are active before the original is allowed to write.
    await new Promise((resolve) => setTimeout(resolve, 50)); release();
    const [accepted, finalized] = await Promise.all([original, finalizing]);
    const receipt = await db.doc(receiptPath(domain)).get();
    const fence = await db.doc(`submission_recovery_fences/${submissionRecoveryFenceId(domain, f.requestId)}`).get();
    expect(Number(receipt.exists) + Number(fence.exists)).toBe(1);
    expect(attempts).toBeGreaterThan(0);
    if (receipt.exists) {
      expect(accepted.value).toBe('accepted');
      expect(finalized.error).toMatchObject({details: {reasonCode: 'submission-recovery-observation-changed'}});
      expect((await directReview(request)).observation).toBe('receiptPresent');
    } else {
      expect(finalized.value.outcome).toBe('cancelled');
      expect(accepted.error).toMatchObject({details: {reasonCode: 'saved-submission-cancelled'}});
    }
  });

  test('an overlapping accepted replay and administrative review retain one acceptance and its permanent hold', async () => {
    const domain = 'qualityMonitoring'; const request = f.review(domain);
    await db.doc(receiptPath(domain)).set(f.receipt(domain));
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const observation = await directReview(request);
    const originalDb = withSubmissionRecoveryFence(db, 'mutateChargeAbnormality', f.original(domain));
    let release; let entered;
    const wait = new Promise((resolve) => {release = resolve;});
    const arrival = new Promise((resolve) => {entered = resolve;});
    const original = originalDb.runTransaction(async (tx) => {
      entered(); await wait;
      const receipt = await tx.get(db.doc(receiptPath(domain)));
      if (!receipt.exists) tx.create(db.doc('business/duplicate'), {});
      return receipt.exists ? 'original-acceptance' : 'duplicate';
    }).then((value) => ({value}), (error) => ({error}));
    await arrival;
    const finalizing = directReview({...request, phase: 'finalize', reviewToken: observation.reviewToken});
    await new Promise((resolve) => setTimeout(resolve, 50)); release();
    const [replay, proof] = await Promise.all([original, finalizing]);
    if (replay.error) expect(replay.error.details.reasonCode).toBe('saved-submission-reviewed-existing');
    else expect(replay.value).toBe('original-acceptance');
    expect(proof.outcome).toBe('reviewedExisting');
    expect((await db.doc('business/duplicate').get()).exists).toBe(false);
    expect((await db.doc(receiptPath(domain)).get()).data()).toEqual(f.receipt(domain));
    expect((await db.doc(`submission_recovery_fences/${submissionRecoveryFenceId(domain, f.requestId)}`).get()).data().outcome).toBe('reviewedExisting');
  });

  test('wrong outer origin and non-Admin recovery are denied without any writes', async () => {
    await db.doc('users/operator').set({isApproved: true, roles: ['operations']});
    const before = await evidence(); const data = {protocolVersion: 2, originActorUid: 'admin', recovery: f.review('morningReview')};
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest(data, 'operator'))).rejects.toMatchObject({details: {reasonCode: 'origin-bound-actor-mismatch'}});
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest({...data, originActorUid: 'operator'}, 'operator'))).rejects.toMatchObject({code: 'permission-denied'});
    expect(await evidence()).toEqual(before);
  });

  test('actual Morning Review receiptLookup recovers an earlier accepted day without execution or quota writes', async () => {
    const {mutateMorningReviewWithDb} = require('../lib/morningReviewMutation');
    const request = {requestId: f.requestId, operation: 'START_MORNING_REVIEW', expectedPlantDay: '2026-09-07'};
    const accepted = await mutateMorningReviewWithDb({db, authUid: 'admin', data: request,
      now: () => new Date('2026-09-07T03:00:00.000Z'), timestampFromDate: admin.firestore.Timestamp.fromDate});
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const reviewRequest = f.review('morningReview', {originalActorUid: 'admin'});
    const observed = await review('morningReview', reviewRequest);
    await review('morningReview', {...reviewRequest, phase: 'finalize', reviewToken: observed.reviewToken});
    const before = await evidence();
    const envelope = {protocolVersion: 2, originActorUid: 'admin', receiptLookup: request};
    expect(await endpoints.mutateAssetHierarchyV2.run(callRequest(envelope))).toEqual({...accepted, idempotentReplay: true});
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest({...envelope, originActorUid: 'another'})))
      .rejects.toMatchObject({details: {reasonCode: 'origin-bound-actor-mismatch'}});
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest({...envelope, request})))
      .rejects.toMatchObject({code: 'invalid-argument'});
    await expect(endpoints.mutateChargeAbnormalityV2.run(callRequest(envelope)))
      .rejects.toMatchObject({code: 'invalid-argument'});
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest({...envelope, receiptLookup: {
      ...request, requestId: '22222222-2222-4222-8222-222222222222'}})))
      .rejects.toMatchObject({code: 'not-found', details: {reasonCode: 'morning-review-receipt-not-found'}});
    expect(await evidence()).toEqual(before);
  });

  test('actual unpinned NOT_HELD request cannot create a later day after accepted review and receipt expiry', async () => {
    const {mutateMorningReviewWithDb} = require('../lib/morningReviewMutation');
    const request = {requestId: f.requestId, operation: 'RECORD_MORNING_REVIEW_NOT_HELD', reason: 'Planned plant shutdown'};
    const mutate = (now) => mutateMorningReviewWithDb({
      db: withSubmissionRecoveryFence(db, 'mutateAssetHierarchy', request), authUid: 'admin', data: request,
      now: () => new Date(now), timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
    expect((await mutate('2026-08-31T05:00:00.000Z')).sessionId).toBe('2026-08-31');
    await db.doc('submission_recovery_controls/activation').set(f.activation());
    const reviewRequest = f.review('morningReview', {originalActorUid: 'admin'});
    const observed = await review('morningReview', reviewRequest);
    const proof = await review('morningReview', {...reviewRequest, phase: 'finalize', reviewToken: observed.reviewToken});
    await db.doc(receiptPath('morningReview')).delete(); // Emulates TTL expiry only in the isolated demo database.
    const before = await evidence();
    await expect(mutate('2026-09-15T05:00:00.000Z'))
      .rejects.toMatchObject({details: {reasonCode: 'saved-submission-reviewed-existing'}});
    expect(await review('morningReview', {...reviewRequest, reason: 'Retrieve the previously recorded review.'})).toEqual(proof);
    await expect(endpoints.mutateAssetHierarchyV2.run(callRequest({protocolVersion: 2, originActorUid: 'admin', receiptLookup: request})))
      .rejects.toMatchObject({details: {reasonCode: 'morning-review-receipt-not-found'}});
    expect((await db.doc('morning_review_sessions/2026-09-15').get()).exists).toBe(false);
    expect(await evidence()).toEqual(before);
  });
});
