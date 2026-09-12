const {Timestamp} = require('firebase-admin/firestore');
const {reviewSavedSubmissionWithDb, withSubmissionRecoveryFence, submissionRecoveryFenceId,
  submissionRecoveryEvidenceHash, SUBMISSION_RECOVERY_DOMAINS} = require('../lib/submissionRecovery');
const f = require('./submissionRecoveryFixtures.cjs');
const receiptPath = (domain) => `${SUBMISSION_RECOVERY_DOMAINS[domain].receipts}/${f.requestId}`;
const invoke = (m, data, extra = {}) => reviewSavedSubmissionWithDb({db: m.db,
  endpoint: SUBMISSION_RECOVERY_DOMAINS[data.domain].endpoint, authUid: 'admin', data,
  now: () => new Date('2026-09-13T01:00:00.000Z'), ...extra});
const finalize = (m, request, observation) => invoke(m, {...request, phase: 'finalize', reviewToken: observation.reviewToken});

describe.each(f.domains)('%s administrative recovery', (domain) => {
  test('inspection is read-only; accepted evidence needs activation and a permanent distinct execution hold', async () => {
    const m = f.memory(); const request = f.review(domain);
    const original = f.receipt(domain); m.store.set(receiptPath(domain), original);
    const observation = await invoke(m, request);
    expect(Object.keys(observation).sort()).toEqual(f.inspectionKeys);
    expect(observation).toMatchObject({observation: 'receiptPresent', originalActorUid: null,
      receiptSummary: {actorUid: 'original'}});
    expect(m.writes).toEqual([]);
    await expect(finalize(m, request, observation)).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
    expect(m.writes).toEqual([]);
    m.store.set('submission_recovery_controls/activation', f.activation());
    const proof = await finalize(m, request, observation);
    expect(proof).toMatchObject({outcome: 'reviewedExisting', reason: request.reason, originalActorUid: null});
    expect(m.writes).toHaveLength(2);
    const holdPath = `submission_recovery_fences/${submissionRecoveryFenceId(domain, f.requestId)}`;
    expect(m.store.get(holdPath)).toMatchObject({...proof, protocol: 'savedSubmissionReview.v1'});
    expect(m.store.get(holdPath).expiresAt).toBeUndefined();
    expect(m.store.get(receiptPath(domain))).toEqual(original);
    // Lost final replies and disabled future reviews never erase either proof.
    m.store.delete('submission_recovery_controls/activation');
    const before = f.clone(m.writes);
    expect(await finalize(m, request, observation)).toEqual(proof);
    // Historical receipts may expire; the separate immutable review remains.
    m.store.delete(receiptPath(domain));
    expect(await invoke(m, request)).toEqual(proof);
    const guarded = withSubmissionRecoveryFence(m.db, SUBMISSION_RECOVERY_DOMAINS[domain].endpoint.replace(/V2$/, ''), f.original(domain));
    await expect(guarded.runTransaction(async (tx) => tx.create(m.db.collection('business').doc('expired-replay'), {})))
      .rejects.toMatchObject({details: {reasonCode: 'saved-submission-reviewed-existing'}});
    expect(m.writes).toEqual(before);
  });
  test('absent receipt is not final until activation; permanent fence blocks original V1 transaction', async () => {
    const m = f.memory(); const request = f.review(domain);
    const observation = await invoke(m, request);
    expect(observation).toMatchObject({observation: 'receiptAbsent', receiptSha256: null, receiptSummary: null});
    expect(m.writes).toEqual([]);
    await expect(finalize(m, request, observation)).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
    expect(m.writes).toEqual([]);
    m.store.set('submission_recovery_controls/activation', f.activation());
    const proof = await finalize(m, request, observation);
    expect(proof).toMatchObject({outcome: 'cancelled', originalActorUid: null, reason: request.reason, receiptSha256: null});
    expect(m.writes).toHaveLength(2);
    expect(m.writes.every(([, data]) => data.expiresAt === undefined)).toBe(true);
    const guarded = withSubmissionRecoveryFence(m.db, SUBMISSION_RECOVERY_DOMAINS[domain].endpoint.replace(/V2$/, ''), f.original(domain));
    const writes = m.writes.length;
    await expect(guarded.runTransaction(async (tx) => tx.create(m.db.collection('business').doc('delayed'), {})))
      .rejects.toMatchObject({details: {reasonCode: 'saved-submission-cancelled'}});
    expect(m.writes).toHaveLength(writes);
    // Disabling future cancellations never disables an existing fence.
    m.store.delete('submission_recovery_controls/activation');
    expect(await finalize(m, request, observation)).toEqual(proof);
    await expect(guarded.runTransaction(async () => true)).rejects.toMatchObject({code: 'failed-precondition'});
  });
  test('late acceptance defeats an earlier absence observation without being discarded', async () => {
    const m = f.memory(); const request = f.review(domain);
    m.store.set('submission_recovery_controls/activation', f.activation());
    const observation = await invoke(m, request);
    const accepted = f.receipt(domain); m.store.set(receiptPath(domain), accepted);
    await expect(finalize(m, request, observation)).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-observation-changed'}});
    expect(m.writes).toEqual([]); expect(m.store.get(receiptPath(domain))).toEqual(accepted);
    expect((await finalize(m, request, await invoke(m, request))).outcome).toBe('reviewedExisting');
  });
  test('corrupt receipt and known original-actor disagreement remain a hold', async () => {
    const m = f.memory(); m.store.set('submission_recovery_controls/activation', f.activation());
    for (const receipt of [{}, {...f.receipt(domain), actorUid: ''}]) {
      m.store.set(receiptPath(domain), receipt);
      await expect(invoke(m, f.review(domain))).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-receipt-malformed'}});
    }
    m.store.set(receiptPath(domain), f.receipt(domain));
    await expect(invoke(m, f.review(domain, {originalActorUid: 'someone-else'})))
      .rejects.toMatchObject({details: {reasonCode: 'submission-recovery-original-actor-mismatch'}});
    expect(m.writes).toEqual([]);
    expect((await invoke(m, f.review(domain, {originalActorUid: 'original'}))).originalActorUid).toBe('original');
  });
  test('review reason, evidence, actor and stored decision are not silently rebound', async () => {
    const m = f.memory(); const request = f.review(domain);
    m.store.set('submission_recovery_controls/activation', f.activation());
    const observation = await invoke(m, request);
    await expect(finalize(m, {...request, reason: 'Different reviewed reason.'}, observation))
      .rejects.toMatchObject({details: {reasonCode: 'submission-recovery-observation-changed'}});
    const proof = await finalize(m, request, observation);
    const writes = f.clone(m.writes);
    expect(await invoke(m, {...request, reason: 'Retrieve the already completed review.'})).toEqual(proof);
    await expect(finalize(m, {...request, reason: 'Different reviewed reason.'}, observation))
      .rejects.toMatchObject({details: {reasonCode: 'submission-recovery-decision-conflict'}});
    expect(m.writes).toEqual(writes);
    const path = `submission_recovery_decisions/${proof.decisionId}`;
    m.store.set(path, {...m.store.get(path), originalActorUid: 'invented-origin'});
    await expect(invoke(m, request)).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

test.each([null, {isApproved: false, roles: ['admin']}, {isApproved: true, roles: ['operations']}, {approved: true, role: 'admin'}])(
  'only a canonical approved Admin may inspect even an absent receipt: %j', async (user) => {
    const m = f.memory(); m.store.set('users/admin', user);
    await expect(invoke(m, f.review('morningReview'))).rejects.toMatchObject({code: 'permission-denied'});
    expect(m.writes).toEqual([]);
  });
test.each(['legacyWorkersDrained', 'rollbackRetainsFences', 'enabled'])('activation %s cannot be omitted', async (field) => {
  const m = f.memory(); const activation = f.activation(); delete activation[field];
  m.store.set('submission_recovery_controls/activation', activation);
  const request = f.review('morningReview');
  await expect(finalize(m, request, await invoke(m, request))).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
  expect(m.writes).toEqual([]);
});

test('future activation evidence cannot authorize finalization', async () => {
  const m = f.memory(); m.store.set('submission_recovery_controls/activation', {...f.activation(), verifiedAt: '2026-09-14T00:00:00.000Z'});
  const request = f.review('morningReview');
  await expect(finalize(m, request, await invoke(m, request))).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-finalization-not-activated'}});
  expect(m.writes).toEqual([]);
});

test('malformed operation and timestamp objects stay a structured hold', async () => {
  const m = f.memory(); const original = f.receipt('morningReview');
  for (const changed of [
    {...original, result: {...original.result, operation: '__proto__'}},
    {...original, committedAt: new Date('invalid')},
    {...original, committedAt: {seconds: original.committedAt.seconds, nanoseconds: original.committedAt.nanoseconds}},
  ]) {
    m.store.set(receiptPath('morningReview'), changed);
    await expect(invoke(m, f.review('morningReview'))).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-receipt-malformed'}});
  }
  expect(m.writes).toEqual([]);
});

test.each([
  ['innerCoverAcceptance', {auditId: 'other-audit'}],
  ['innerCoverAcceptance', {secondaryVersion: '2'}],
  ['qualityMonitoring', {auditId: 'other-audit'}],
  ['burnerEvidence', {assetClassName: ''}],
  ['burnerEvidence', {recordedByName: null}],
  ['inspectionCampaign', {authorityScope: {schemaVersion: 1, capability: 'inspectionDefinition.manage'}}],
  ['morningReview', {result: {...f.receipt('morningReview').result, extra: true}}],
  ['morningReview', {result: {...f.receipt('morningReview').result, status: ['open']}}],
])('producer-required receipt fields remain an investigation hold: %s %j', async (domain, changed) => {
  const m = f.memory(); m.store.set(receiptPath(domain), {...f.receipt(domain), ...changed});
  await expect(invoke(m, f.review(domain))).rejects.toMatchObject({details: {reasonCode: 'submission-recovery-receipt-malformed'}});
  expect(m.writes).toEqual([]);
});
test('strict domain/endpoint and key/phase binding', async () => {
  const m = f.memory();
  for (const request of [f.review('morningReview', {extra: true}), f.review('morningReview', {phase: 'cancel'}), f.review('morningReview', {originalActorUid: undefined})]) {
    await expect(invoke(m, request)).rejects.toMatchObject({code: 'invalid-argument'});
  }
  await expect(invoke(m, f.review('morningReview'), {endpoint: 'mutateChargeAbnormalityV2'})).rejects.toMatchObject({code: 'invalid-argument'});
  expect(m.writes).toEqual([]);
});
test('both burner operations share one global request fence; transaction options are preserved', async () => {
  const m = f.memory(); const request = f.review('burnerEvidence');
  m.store.set('submission_recovery_controls/activation', f.activation());
  await finalize(m, request, await invoke(m, request));
  const guarded = withSubmissionRecoveryFence(m.db, 'mutateAssetHierarchy', {
    requestId: ` ${f.requestId} `, operation: 'COMPLETE_BURNER_RED_HOT_DIRECTIVE'});
  await expect(guarded.runTransaction(async () => true, {maxAttempts: 7})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(m.db.lastOptions).toEqual({maxAttempts: 7});
  expect(m.reads).toContain(`submission_recovery_fences/${submissionRecoveryFenceId('burnerEvidence', f.requestId)}`);
});

test.each([
  ['innerCoverAcceptance', 'mutateAssetHierarchy', {operation: 'REGISTER_INNER_COVER'}],
  ['innerCoverAcceptance', 'mutateAssetHierarchy', {operation: 'LINK_INNER_COVER'}],
  ['qualityMonitoring', 'mutateChargeAbnormality', {operation: 'CLOSE_QUALITY_MONITORING_REQUEST'}],
  ['qualityMonitoring', 'mutateChargeAbnormality', {operation: 'REQUEST_QUALITY_WARNING_CLOSURE'}],
  ['inspectionCampaign', 'executeMaintenanceWorkflowCommand', {commandType: 'upsertInspectionDefinition'}],
  ['inspectionCampaign', 'executeMaintenanceWorkflowCommand', {commandType: 'createMaintenanceTicket'}],
].flatMap((row) => ['cancelled', 'reviewedExisting'].map((outcome) => [...row, outcome])))('the %s receipt namespace reserves its ID for %j %j (%s)', async (domain, endpoint, changed, outcome) => {
  const m = f.memory(); m.store.set('submission_recovery_controls/activation', f.activation());
  if (outcome === 'reviewedExisting') m.store.set(receiptPath(domain), f.receipt(domain));
  const request = f.review(domain); await finalize(m, request, await invoke(m, request));
  if (outcome === 'reviewedExisting') m.store.delete(receiptPath(domain));
  const guarded = withSubmissionRecoveryFence(m.db, endpoint, {...f.original(domain), ...changed});
  const writes = f.clone(m.writes);
  await expect(guarded.runTransaction(async (tx) => tx.create(m.db.collection('business').doc('other-operation'), {})))
    .rejects.toMatchObject({details: {reasonCode: outcome === 'cancelled' ? 'saved-submission-cancelled' : 'saved-submission-reviewed-existing'}});
  expect(m.writes).toEqual(writes);
});
test('recorded-time hashes retain native nanoseconds and nested date evidence', () => {
  const first = {timestamp: new Timestamp(1789257600, 1000), nested: {date: new Date(f.at)}};
  expect(submissionRecoveryEvidenceHash(first)).not.toBe(submissionRecoveryEvidenceHash({...first, timestamp: new Timestamp(1789257600, 1001)}));
  expect(submissionRecoveryEvidenceHash(first)).not.toBe(submissionRecoveryEvidenceHash({...first, nested: {date: new Date(Date.parse(f.at) + 1)}}));
  expect(() => submissionRecoveryEvidenceHash({unsupported: undefined})).toThrow();
  expect(submissionRecoveryEvidenceHash({time: new Date(f.at)})).not.toBe(
    submissionRecoveryEvidenceHash({time: {$dateMillis: Date.parse(f.at)}}));
  expect(submissionRecoveryEvidenceHash({time: new Timestamp(1789257600, 1000)})).not.toBe(
    submissionRecoveryEvidenceHash({time: {$timestampSeconds: 1789257600, $timestampNanoseconds: 1000}}));
  expect(submissionRecoveryEvidenceHash({time: new Date(f.at)})).not.toBe(
    submissionRecoveryEvidenceHash({time: ['date', Date.parse(f.at)]}));
  expect(submissionRecoveryEvidenceHash(JSON.parse('{"__proto__":{"retained":"yes"}}'))).not.toBe(submissionRecoveryEvidenceHash({}));
  expect(() => submissionRecoveryEvidenceHash(new Map())).toThrow();
});
test('genuine frozen legacy quality creation receipt is reviewable without rewriting its history', async () => {
  const fixture = require('./fixtures/quality_monitoring_legacy_creation.json');
  const [path, raw] = fixture.documents.find(([path]) => path.startsWith('quality_mutation_receipts/'));
  const data = {...raw, committedAt: new Timestamp(raw.committedAt._seconds, raw.committedAt._nanoseconds)};
  const m = f.memory(); m.store.set(path, data);
  m.store.set('submission_recovery_controls/activation', f.activation());
  const request = f.review('qualityMonitoring', {originalActorUid: fixture.actorUid});
  expect((await finalize(m, request, await invoke(m, request))).outcome).toBe('reviewedExisting');
  expect(m.store.get(path)).toEqual(data);
});

test('administrative review accepts the actual campaign creation receipt without rewriting it', async () => {
  const h = require('./helpers/inspectionFixture');
  const store = new h.MemoryWorkflowStore(); h.seedFurnaceHierarchy(store);
  const actor = h.seedActor(store, 'admin-1', ['admin']);
  const service = new h.MaintenanceWorkflowCommandService(store);
  await service.execute(h.upsertDefinition(), {actor, serverNow: h.at('2026-08-21T04:00:00Z')});
  const command = h.createCampaign();
  await service.execute(command, {actor, serverNow: h.at('2026-08-21T04:10:00Z')});
  await f.inspectProducedReceipt('inspectionCampaign', store.read(`maintenance_workflow_command_receipts/${command.commandId}`));
});

test.each(['missing', 'different-outcome', 'changed-receipt', 'malformed'])('an accepted review with %s permanent hold remains a retained investigation case', async (change) => {
  const m = f.memory(); const request = f.review('morningReview');
  m.store.set(receiptPath('morningReview'), f.receipt('morningReview'));
  m.store.set('submission_recovery_controls/activation', f.activation());
  const proof = await finalize(m, request, await invoke(m, request));
  const holdPath = `submission_recovery_fences/${submissionRecoveryFenceId('morningReview', f.requestId)}`;
  if (change === 'missing') m.store.delete(holdPath);
  else {
    const hold = {...m.store.get(holdPath)};
    if (change === 'malformed') hold.proofSha256 = '0'.repeat(64);
    else {
      if (change === 'different-outcome') {
        hold.outcome = 'cancelled'; hold.receiptSha256 = null; hold.receiptSummary = null;
      } else hold.receiptSha256 = '0'.repeat(64);
      const {proofSha256, protocol, ...changedProof} = hold;
      hold.proofSha256 = submissionRecoveryEvidenceHash(changedProof);
    }
    m.store.set(holdPath, hold);
  }
  const before = f.clone([...m.store]);
  await expect(invoke(m, request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect([...m.store]).toEqual(before);
  expect(m.store.get(`submission_recovery_decisions/${proof.decisionId}`).outcome).toBe('reviewedExisting');
});

test('an expired accepted hold cannot be repurposed as cancellation for different local evidence', async () => {
  const m = f.memory(); const request = f.review('morningReview');
  m.store.set(receiptPath('morningReview'), f.receipt('morningReview'));
  m.store.set('submission_recovery_controls/activation', f.activation());
  const proof = await finalize(m, request, await invoke(m, request));
  m.store.delete(receiptPath('morningReview'));
  const before = f.clone([...m.store]);
  await expect(invoke(m, {...request, evidenceSha256: 'b'.repeat(64)}))
    .rejects.toMatchObject({details: {reasonCode: 'submission-recovery-reviewed-receipt-expired'}});
  expect(await invoke(m, {...request, reason: 'Recover the original completed result.'})).toEqual(proof);
  expect([...m.store]).toEqual(before);
});

test('actual unpinned Morning Review acceptance stays read-only after review and cannot recreate a later day after receipt TTL', async () => {
  const {mutateMorningReviewWithDb, lookupMorningReviewReceiptWithDb} = require('../lib/morningReviewMutation');
  const m = f.memory();
  // The real NOT_HELD handler needs document point reads and transaction.set;
  // every write in this creation fixture uses a previously absent document.
  const collection = m.db.collection.bind(m.db);
  m.db.collection = (name) => ({doc(id) {
    const ref = collection(name).doc(id);
    return {...ref, get: async () => ({exists: m.store.has(ref.path), data: () => f.clone(m.store.get(ref.path))})};
  }});
  const run = m.db.runTransaction.bind(m.db);
  m.db.runTransaction = (body, ...options) => run((tx) => body({...tx, set: tx.create}), ...options);
  const request = {requestId: f.requestId, operation: 'RECORD_MORNING_REVIEW_NOT_HELD', reason: 'Planned plant shutdown'};
  const mutate = (now) => mutateMorningReviewWithDb({
    db: withSubmissionRecoveryFence(m.db, 'mutateAssetHierarchy', request), authUid: 'admin', data: request,
    now: () => new Date(now), timestampFromDate: Timestamp.fromDate,
  });
  const accepted = await mutate('2026-08-31T05:00:00.000Z');
  expect(accepted.sessionId).toBe('2026-08-31');
  expect(m.store.get(receiptPath('morningReview')).expiresAt.toDate().toISOString()).toBe('2026-09-14T05:00:00.000Z');
  m.store.set('submission_recovery_controls/activation', f.activation());
  const reviewed = f.review('morningReview', {originalActorUid: 'admin'});
  const proof = await finalize(m, reviewed, await invoke(m, reviewed));
  const beforeLookup = f.clone(m.writes);
  expect(await lookupMorningReviewReceiptWithDb({db: m.db, authUid: 'admin', data: request}))
    .toEqual({...accepted, idempotentReplay: true});
  expect(m.writes).toEqual(beforeLookup);
  m.store.delete(receiptPath('morningReview')); // Simulates the declared TTL, not a production deletion.
  const before = f.clone([...m.store]);
  await expect(mutate('2026-09-15T05:00:00.000Z'))
    .rejects.toMatchObject({details: {reasonCode: 'saved-submission-reviewed-existing'}});
  expect(await invoke(m, reviewed)).toEqual(proof);
  expect([...m.store]).toEqual(before);
  expect(m.store.has('morning_review_sessions/2026-09-15')).toBe(false);
});

test('actual recovery wire fixture remains compatible with the native saved-evidence consumer', async () => {
  const {createHash} = require('crypto'); const fs = require('fs'); const path = require('path');
  const sourceBytes = JSON.stringify({requestId: f.requestId, payloadFingerprint: 'old-hash'});
  const row = {schemaVersion: 1, submissionId: 'legacy-wire-fixture', actorUid: null,
    requestId: 'unknown', aggregateId: 'unknown', resourceKey: 'morningReview:admin',
    protocol: 'legacy.reviewOnly', envelopeJson: '{}', displayMetadataJson: null,
    legacySourceKey: 'PENDING_MORNING_REVIEW_COMMAND::fixture',
    legacySourceBase64: Buffer.from(sourceBytes).toString('base64')};
  const evidenceSha256 = createHash('sha256').update(JSON.stringify(row), 'utf8').digest('hex');
  const m = f.memory(); m.store.set('submission_recovery_controls/activation', f.activation());
  const request = f.review('morningReview', {evidenceSha256});
  const inspection = await invoke(m, request);
  expect(Object.keys(inspection).sort()).toEqual(f.inspectionKeys);
  const proof = await finalize(m, request, inspection);
  const fixture = {schemaVersion: 1, provenance: 'Generated by actual reviewSavedSubmissionWithDb; native consumer verifies the same imported evidence hash and exact reply shapes.',
    actorUid: 'admin', row, sourceBytes, evidenceSha256, reason: request.reason, inspection, proof};
  const target = path.resolve(__dirname, '../../test/fixtures/saved_submission_review_actual_handler.json');
  if (process.env.UPDATE_SUBMISSION_REVIEW_WIRE_FIXTURE === 'true') fs.writeFileSync(target, `${JSON.stringify(fixture, null, 2)}\n`);
  expect(JSON.parse(fs.readFileSync(target, 'utf8'))).toEqual(fixture);
});
