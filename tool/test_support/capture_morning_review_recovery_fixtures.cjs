// Actual production handler, local transactional harness, no network or credentials.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const handler = require(path.join(root, 'functions/lib/morningReviewMutation'));
const harness = fs.readFileSync(path.join(root, 'functions/test/morningReviewMutation.test.js'), 'utf8');
const helpers = harness.slice(harness.indexOf('function clone('), harness.indexOf('describe('));
const {fakeDb, baseSeed, invoke} = new Function('mutateMorningReviewWithDb', helpers + '\nreturn {fakeDb, baseSeed, invoke};')(handler.mutateMorningReviewWithDb);
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
const day = '2026-08-31';
let next = 100;
const request = (operation, extra = {}) => ({requestId: `12345678-0000-4000-8000-${String(next++).padStart(12,'0')}`,
  operation, recoveryVersion: 1, ...(operation === 'START_MORNING_REVIEW' ? {} : {sessionId: day}), ...extra});
(async () => {
  const memory = fakeDb(baseSeed());
  const actorUid = 'admin-1';
  await invoke(memory, actorUid, request('START_MORNING_REVIEW'));
  const openSession = structuredClone(memory.store.get(`morning_review_sessions/${day}`));
  const normalizedRequest = request('CREATE_MORNING_REVIEW_ACTION', {actionDraft: {section: 'furnace',
    text: 'Original exact action wording', assigneeUid: null, assigneeRole: 'operations',
    assetClassId: 'furnace-class', assetClassName: 'Old registry label', assetInstanceId: 'furnace-12', assetNumber: '012', dueAt: null}});
  const normalizedReceipt = await invoke(memory, actorUid, normalizedRequest);
  const normalizedAction = memory.store.get(`morning_review_actions/${normalizedRequest.requestId}`);
  memory.store.delete(`morning_review_actions/${normalizedRequest.requestId}`);
  const normalizationProof = await handler.lookupMorningReviewReceiptWithDb({db: memory.db, authUid: actorUid,
    data: {acceptanceEvidence: true, request: normalizedRequest}});
  memory.store.set(`morning_review_actions/${normalizedRequest.requestId}`, normalizedAction);
  const cancelRequest = request('AMEND_MORNING_REVIEW_ACTION', {actionId: normalizedRequest.requestId, expectedVersion: 1,
    reason: 'Duplicate planning item', actionCorrection: {kind: 'cancel', assigneeUid: null, assigneeRole: null}});
  const cancelReceipt = await invoke(memory, actorUid, cancelRequest);
  const cancelledAction = memory.store.get(`morning_review_actions/${normalizedRequest.requestId}`);
  const cancelProof = await handler.lookupMorningReviewReceiptWithDb({db: memory.db, authUid: actorUid, data: {acceptanceEvidence: true, request: cancelRequest}});
  const refusedRequest = request('FINALIZE_MORNING_REVIEW', {expectedVersion: 999, summary: 'Carefully written original summary'});
  let refusal;
  try { await invoke(memory, actorUid, refusedRequest); } catch (error) { refusal = {code: error.code, message: error.message, details: error.details}; }
  if (!refusal?.details?.morningReviewRefusal) throw new Error('Missing actual server refusal');
  const output = {provenance: {generator: 'tool/test_support/capture_morning_review_recovery_fixtures.cjs',
    sourceSha256: sha('functions/src/morningReviewMutation.ts'), recoverySha256: sha('functions/src/morningReviewRecovery.ts'),
    note: 'Actual handler and native recovery consumers; this fixture does not prove Firestore concurrency.'},
    actorUid, openSession, normalizedRequest, normalizedReceipt, normalizedAction, normalizationProof,
    cancelRequest, cancelReceipt, cancelProof, cancelledAction, refusedRequest, refusal};
  fs.writeFileSync(path.join(root, 'test/fixtures/morning_review_recovery_actual_handler.json'), JSON.stringify(output, null, 2) + '\n');
  process.stdout.write('Captured actual acceptance, refusal, cancellation and retained-session evidence.\n');
})().catch(error => { process.stderr.write(String(error.stack || error)); process.exitCode = 1; });
