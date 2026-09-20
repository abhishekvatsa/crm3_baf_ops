const {fakeDb} = require('./helpers/qualityMemoryFirestore.cjs');
const {mutateQualityWithDb, validateQualityMonitoringRecord} = require('../lib/qualityMutation');
const {planQualityMonitoringArchive, archiveDueQualityMonitoringRequests} = require('../lib/qualityMonitoringRetention');
const id = '44444444-4444-4444-8444-444444444444';
const createId = '11111111-1111-4111-8111-111111111111';
const reviewId = '22222222-2222-4222-8222-222222222222';
const cancelId = '33333333-3333-4333-8333-333333333333';
const now = new Date('2026-09-20T10:00:00.000Z');
const seed = () => ({
  'users/admin': {isApproved: true, roles: ['admin'], name: 'Admin'},
  'users/si': {isApproved: true, roles: ['si'], name: 'SI'},
  'users/operator': {isApproved: true, roles: ['operations'], name: 'Operator'},
  'asset_classes/base': {schemaVersion: 1, assetClassId: 'base', code: 'BASE', name: 'Base', legacyAssetTypeKey: 'base', status: 'active'},
  'asset_instances/base-7': {schemaVersion: 1, assetInstanceId: 'base-7', assetClassId: 'base', assetClassCode: 'BASE', assetClassName: 'Base', assetNumber: 7, name: 'Base 7', status: 'active', version: 3},
});
const create = {requestId: createId, operation: 'CREATE_QUALITY_MONITORING_REQUEST', monitoringRequestId: id, expectedVersion: 0,
  reason: 'Watch the manually supplied cycle', baseNumber: 7, baseAssetClassId: 'base', baseAssetInstanceId: 'base-7', baseAssetInstanceVersion: 3,
  grade: 'Grade A', cycleReference: 'Manual cycle A', chargeNumbers: [12345]};
const correct = {...create, requestId: reviewId, operation: 'CORRECT_QUALITY_MONITORING_REQUEST', expectedVersion: 1,
  reason: 'Correct the transcribed charge and grade against the register', grade: 'Grade B', chargeNumbers: [12346]};
const cancel = {requestId: cancelId, operation: 'CANCEL_QUALITY_MONITORING_REQUEST', monitoringRequestId: id, expectedVersion: 2,
  reason: 'The instruction was entered in error; no monitoring is claimed'};
const call = (memory, request, uid = 'admin', at = now) => mutateQualityWithDb({db: memory.db, authUid: uid, data: request, now: () => at});
const plain = (value) => JSON.parse(JSON.stringify(value));

test('correction and cancellation retain original acceptance, actor and context without touching physical charge state', async () => {
  const memory = fakeDb({...seed(), 'charges/12345': {status: 'heating'}, 'quality_warnings/w': {status: 'open'}});
  const first = await call(memory, create);
  const revised = await call(memory, correct, 'si');
  expect(revised.entity).toMatchObject({schemaVersion: 4, status: 'active', grade: 'Grade B', chargeNumbers: [12346],
    monitoringDisposition: null, createdByUid: 'admin', updatedByUid: 'si', originalMonitoringContext: {grade: 'Grade A', chargeNumbers: [12345]}});
  const cancelled = await call(memory, cancel, 'si');
  expect(cancelled.entity).toMatchObject({status: 'closed', monitoringDisposition: 'cancelled', closedByUid: 'si'});
  expect(memory.store.get('charges/12345')).toEqual({status: 'heating'});
  expect(memory.store.get('quality_warnings/w')).toEqual({status: 'open'});
  const writes = memory.writes.length;
  expect(plain(await call(memory, create))).toEqual({...plain(first), idempotentReplay: true});
  expect(plain(await call(memory, correct, 'si'))).toEqual({...plain(revised), idempotentReplay: true});
  expect(plain(await call(memory, cancel, 'si'))).toEqual({...plain(cancelled), idempotentReplay: true});
  expect(memory.writes.length).toBe(writes);
  const audit = memory.store.get(`audit_logs/server_quality_${reviewId}`);
  expect(JSON.parse(audit.beforeJson).grade).toBe('Grade A');
  expect(JSON.parse(audit.afterJson).grade).toBe('Grade B');
  expect(audit.reasonNotes).toBe(correct.reason);
});

test('archive changes visibility but closure replay is the immutable original outcome', async () => {
  const memory = fakeDb(seed()); await call(memory, create);
  const close = {...cancel, operation: 'CLOSE_QUALITY_MONITORING_REQUEST', expectedVersion: 1};
  const accepted = await call(memory, close);
  const path = `quality_monitoring_requests/${id}`;
  memory.store.set(path, {...memory.store.get(path), ...planQualityMonitoringArchive({data: memory.store.get(path), requestId: id,
    now: new Date('2026-09-28T10:00:00.000Z')})});
  expect(plain(await call(memory, close))).toEqual({...plain(accepted), idempotentReplay: true});
  expect(memory.store.get(path).visibilityState).toBe('archived');
});

test.each(['grade', 'cycleReference', 'reason', 'closeReason', 'version', 'lastMutationId'])(
  'closure does not certify altered live %s as accepted content', async (field) => {
    const memory = fakeDb(seed()); await call(memory, create);
    const close = {...cancel, operation: 'CLOSE_QUALITY_MONITORING_REQUEST', expectedVersion: 1};
    await call(memory, close);
    memory.store.get(`quality_monitoring_requests/${id}`)[field] = field === 'version' ? 3 :
      field === 'lastMutationId' ? reviewId : 'Changed evidence';
    const writes = memory.writes.length;
    await expect(call(memory, close)).rejects.toMatchObject({code: 'data-loss'});
    expect(memory.writes.length).toBe(writes);
  });

test.each(['CORRECT_QUALITY_MONITORING_REQUEST', 'CANCEL_QUALITY_MONITORING_REQUEST'])(
  'review operation %s requires Admin/SI, reason and exact current revision', async (operation) => {
    const memory = fakeDb(seed()); await call(memory, create);
    const request = operation.startsWith('CORRECT') ? correct : {...cancel, expectedVersion: 1};
    await expect(call(memory, request, 'operator')).rejects.toMatchObject({code: 'permission-denied'});
    await expect(call(memory, {...request, reason: ' '})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(memory, {...request, expectedVersion: 9})).rejects.toMatchObject({code: 'aborted'});
    expect(memory.store.get(`quality_monitoring_requests/${id}`).version).toBe(1);
  });

test('corrected active monitoring can complete without being labelled cancelled', async () => {
  const memory = fakeDb(seed()); await call(memory, create); await call(memory, correct);
  const result = await call(memory, {...cancel, operation: 'CLOSE_QUALITY_MONITORING_REQUEST'});
  expect(result.entity.monitoringDisposition).toBe('completed');
  expect(() => validateQualityMonitoringRecord({...result.entity, monitoringDisposition: null}, id)).toThrow();
});

test('legacy replay output satisfies the same backend reader, with zero response-only shape repair', async () => {
  const fixture = require('./fixtures/quality_monitoring_legacy_creation.json');
  const memory = fakeDb(Object.fromEntries(fixture.documents));
  const result = await call(memory, fixture.request, 'admin-1');
  expect(() => validateQualityMonitoringRecord(result.entity, result.entityId)).not.toThrow();
});

test('legacy schema-1 instruction can be cancelled without inventing a registered identity', async()=>{
 const memory=fakeDb(seed()); const created=await call(memory,create);
 const legacy={...created.entity,schemaVersion:1};
 for(const key of ['baseAssetClassId','baseAssetInstanceId','baseAssetInstanceVersion','visibilityState','visibleUntil','archivedAt'])delete legacy[key];
 memory.store.set(`quality_monitoring_requests/${id}`,legacy);
 const result=await call(memory,{...cancel,expectedVersion:1});
 expect(result.entity.monitoringDisposition).toBe('cancelled');expect(result.entity).not.toHaveProperty('baseAssetInstanceId');
 expect(()=>validateQualityMonitoringRecord(result.entity,id)).not.toThrow();
});
test.each(['CLOSE_QUALITY_MONITORING_REQUEST','CORRECT_QUALITY_MONITORING_REQUEST','CANCEL_QUALITY_MONITORING_REQUEST'])(
 'administrative recovery recognises an actual %s receipt',async(operation)=>{
 const m=fakeDb(seed());await call(m,create);
 const request=operation.startsWith('CORRECT')?correct:{...cancel,expectedVersion:1,operation};
 const accepted=await call(m,request);
 const {reviewSavedSubmissionWithDb}=require('../lib/submissionRecovery');
 const f=require('./submissionRecoveryFixtures.cjs');const reviewDb=f.memory();
 reviewDb.store.set(`quality_mutation_receipts/${request.requestId}`,m.store.get(`quality_mutation_receipts/${request.requestId}`));
 const result=await reviewSavedSubmissionWithDb({db:reviewDb.db,authUid:'admin',endpoint:'mutateChargeAbnormalityV2',
 data:f.review('qualityMonitoring',{requestId:request.requestId,originalActorUid:'admin'}),now:()=>now});
 expect(result.receiptSummary).toMatchObject({operation,entityId:id,version:accepted.version});expect(reviewDb.writes).toHaveLength(0);
});

test('legacy Base number lookup sees genuine Base after more than fifty unrelated equipment matches',async()=>{
 const initial=seed(); const base=initial['asset_instances/base-7'];delete initial['asset_instances/base-7'];
 initial['asset_classes/other']={schemaVersion:1,assetClassId:'other',status:'active',legacyAssetTypeKey:'furnace'};
 for(let i=0;i<60;i++)initial[`asset_instances/other-${i}`]={...base,assetInstanceId:`other-${i}`,assetClassId:'other'};
 initial['asset_instances/base-7']=base;
 const request={...create};for(const key of ['baseAssetClassId','baseAssetInstanceId','baseAssetInstanceVersion'])delete request[key];
 const result=await call(fakeDb(initial),request);expect(result.entity.baseAssetInstanceId).toBe('base-7');
 initial['asset_instances/duplicate']={...base,assetInstanceId:'duplicate'};
 await expect(call(fakeDb(initial),request)).rejects.toMatchObject({code:'failed-precondition'});
});

test('reviewed original context cannot smuggle partial governed identity through legacy nullability',async()=>{
 const m=fakeDb(seed());await call(m,create);const result=await call(m,correct);
 expect(()=>validateQualityMonitoringRecord({...result.entity,originalMonitoringContext:{...result.entity.originalMonitoringContext,baseAssetClassId:null}},id)).toThrow();
});
