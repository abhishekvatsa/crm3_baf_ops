const {fakeDb} = require('../../functions/test/helpers/qualityMemoryFirestore.cjs');
const {mutateQualityWithDb, validateQualityMonitoringRecord} = require('../../functions/lib/qualityMutation');
const {planQualityMonitoringArchive, archiveDueQualityMonitoringRequests} = require('../../functions/lib/qualityMonitoringRetention');
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


const fs = require('node:fs');
const path = require('node:path');
(async () => {
 const memory = fakeDb(seed());
 const created = await call(memory, create);
 const corrected = await call(memory, correct);
 const cancelled = await call(memory, cancel);
 const replay = await call(memory, correct);
 const closedMemory = fakeDb(seed()); await call(closedMemory, create);
 const closeRequest = {...cancel, operation: 'CLOSE_QUALITY_MONITORING_REQUEST', expectedVersion: 1};
 const closed = await call(closedMemory, closeRequest);
 const closedRecord = closedMemory.store.get(`quality_monitoring_requests/${id}`);
 const archived = {...closedRecord, ...planQualityMonitoringArchive({data: closedRecord, requestId: id,
   now: new Date('2026-09-28T10:00:00.000Z')})};
 const legacyMemory = fakeDb(seed());
 const legacy = {...created.entity, schemaVersion: 1};
 for (const key of ['baseAssetClassId','baseAssetInstanceId','baseAssetInstanceVersion','visibilityState','visibleUntil','archivedAt']) delete legacy[key];
 legacyMemory.store.set(`quality_monitoring_requests/${id}`, legacy);
 const legacyCancelled = await call(legacyMemory, {...cancel, expectedVersion: 1});
 const legacyRequest = {...create};
 for (const key of ['baseAssetClassId','baseAssetInstanceId','baseAssetInstanceVersion']) delete legacyRequest[key];
 const oldMemory = fakeDb(seed()); const oldCreated=await call(oldMemory,legacyRequest);
 const oldRecord={...oldCreated.entity,schemaVersion:1};
 for(const key of ['baseAssetClassId','baseAssetInstanceId','baseAssetInstanceVersion','visibilityState','visibleUntil','archivedAt']) delete oldRecord[key];
 oldMemory.store.set(`quality_monitoring_requests/${id}`,oldRecord);
 const audit=oldMemory.store.get(`audit_logs/server_quality_${createId}`);
 audit.afterJson=JSON.stringify(oldRecord);delete audit.creationEvidenceVersion;delete audit.payloadFingerprint;
 const receipt=oldMemory.store.get(`quality_mutation_receipts/${createId}`);
 receipt.payloadFingerprint=receipt.payloadFingerprint.replace('qualitycreate2-','qualityreq1-');delete receipt.creationEvidenceVersion;delete receipt.creationAuditSha256;
 const legacyCreationReplay=await call(oldMemory,legacyRequest);
 const result = {provenance: 'Emitted by actual current quality mutation handler in local memory; no production access. Legacy input is an explicit schema-1 compatibility control.',
   create, correct, cancel, closeRequest, created, corrected, cancelled, replay, closed, archived, legacyCancelled, legacyCreationReplay};
 fs.writeFileSync(path.join(__dirname, '../../test/fixtures/charge_monitoring_review_actual_handler.json'), JSON.stringify(result, null, 2)+'\n');
})().catch(error => { console.error(error); process.exitCode=1; });
