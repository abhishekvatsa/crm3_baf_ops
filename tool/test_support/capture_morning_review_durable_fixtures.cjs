// Local-only fixture capture from the actual compiled handler and its governed
// transaction test harness. No credentials, Firestore client or network calls.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const handlerPath = path.join(root, 'functions/lib/morningReviewMutation.js');
const sourcePath = path.join(root, 'functions/src/morningReviewMutation.ts');
const harnessPath = path.join(root, 'functions/test/morningReviewMutation.test.js');
const handler = require(handlerPath);
const source = fs.readFileSync(harnessPath, 'utf8');
const helpers = source.slice(source.indexOf('function clone('), source.indexOf("describe('Morning Review governed lifecycle'"));
const {fakeDb, baseSeed, invoke} = new Function('mutateMorningReviewWithDb',
  helpers + '\nreturn {fakeDb, baseSeed, invoke};')(handler.mutateMorningReviewWithDb);
const records = [];
let counter = 1;
const sessionId = '2026-08-31';
const collectionFor = operation => ({
  JOIN_MORNING_REVIEW: 'morning_review_participants',
  ADD_MORNING_REVIEW_ENTRY: 'morning_review_entries',
  ADD_MORNING_REVIEW_ADDENDUM: 'morning_review_entries',
  CREATE_MORNING_REVIEW_ACTION: 'morning_review_actions',
  ACCEPT_MORNING_REVIEW_ACTION: 'morning_review_actions',
  COMPLETE_MORNING_REVIEW_ACTION: 'morning_review_actions',
  CREATE_MORNING_REVIEW_STANDING_CONCERN: 'morning_review_standing_concerns',
  RESOLVE_MORNING_REVIEW_STANDING_CONCERN: 'morning_review_standing_concerns',
  CHECK_MORNING_REVIEW_STANDING_CONCERN: 'morning_review_concern_checks',
  FINALIZE_MORNING_REVIEW: 'morning_review_documents',
})[operation] || 'morning_review_sessions';
async function call(memory, actorUid, operation, extra = {}, at) {
  const request = {requestId: `${String(counter++).padStart(8,'0')}-1111-4111-8111-111111111111`,
    operation, ...(!['START_MORNING_REVIEW','RECORD_MORNING_REVIEW_NOT_HELD'].includes(operation) ? {sessionId} : {}), ...extra};
  const receipt = await invoke(memory, actorUid, request, at);
  const collection = collectionFor(operation);
  records.push({actorUid, request, receipt, collection,
    subject: structuredClone(memory.store.get(`${collection}/${receipt.entityId}`))});
  return receipt;
}
(async () => {
  const memory = fakeDb(baseSeed());
  const version = () => memory.store.get(`morning_review_sessions/${sessionId}`).version;
  await call(memory,'admin-1','START_MORNING_REVIEW');
  await call(memory,'si-2','JOIN_MORNING_REVIEW');
  const entryDraft = {section:'plantWide',kind:'update',text:'Durable captured contribution',assetClassId:null,
    assetClassName:null,assetInstanceId:null,assetNumber:null,sourceReferences:[]};
  await call(memory,'admin-1','ADD_MORNING_REVIEW_ENTRY',{entryDraft});
  const action = await call(memory,'admin-1','CREATE_MORNING_REVIEW_ACTION',{actionDraft:{section:'plantWide',
    text:'Inspect captured work',assigneeUid:'admin-1',assigneeRole:null,assetClassId:null,
    assetClassName:null,assetInstanceId:null,assetNumber:null,dueAt:null}});
  await call(memory,'admin-1','ACCEPT_MORNING_REVIEW_ACTION',{actionId:action.entityId,expectedVersion:1});
  await call(memory,'admin-1','COMPLETE_MORNING_REVIEW_ACTION',{actionId:action.entityId,expectedVersion:2,reason:'Captured completion evidence'});
  const concern = await call(memory,'admin-1','CREATE_MORNING_REVIEW_STANDING_CONCERN',{
    concernDraft:{title:'Captured safety concern',detail:'Review required before close',criticality:'safety'}});
  await call(memory,'admin-1','CHECK_MORNING_REVIEW_STANDING_CONCERN',{concernId:concern.entityId,checkState:'complied',reason:'Captured check'});
  await call(memory,'si-2','TAKE_OVER_MORNING_REVIEW',{expectedVersion:version(),reason:'Captured handover'});
  await call(memory,'admin-1','RESOLVE_MORNING_REVIEW_STANDING_CONCERN',{concernId:concern.entityId,expectedVersion:1,reason:'Captured resolution'});
  await call(memory,'admin-1','FINALIZE_MORNING_REVIEW',{expectedVersion:version(),summary:'Captured final summary'});
  await call(memory,'admin-1','ADD_MORNING_REVIEW_ADDENDUM',{entryDraft:{...entryDraft,kind:'addendum'},reason:'Captured clarification'});
  const advancedSubjects = records.map(record => ({operation:record.request.operation,
    subject:memory.store.get(`${record.collection}/${record.receipt.entityId}`)}));
  await call(fakeDb(baseSeed()),'admin-1','RECORD_MORNING_REVIEW_NOT_HELD',{reason:'Captured plant shutdown'},new Date('2026-08-31T04:31:00.000Z'));
  const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  fs.writeFileSync(path.join(root,'test/fixtures/morning_review_durable_actual_handler.json'),JSON.stringify({
    provenance:{generator:'tool/test_support/capture_morning_review_durable_fixtures.cjs',
      handlerSha256:sha(handlerPath),sourceSha256:sha(sourcePath),harnessSha256:sha(harnessPath),
      note:'Actual compiled handler with local transaction harness; production never accessed.'},records,advancedSubjects},null,2)+'\n');
  process.stdout.write(`Captured ${records.length} actual handler operations and ${advancedSubjects.length} advanced subjects.\n`);
})().catch(error=>{process.stderr.write(String(error.stack || error));process.exitCode=1;});
