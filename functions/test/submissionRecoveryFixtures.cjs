const {Timestamp} = require('firebase-admin/firestore');
const {SUBMISSION_RECOVERY_DOMAINS} = require('../lib/submissionRecovery');
const requestId = '11111111-1111-4111-8111-111111111111';
const at = '2026-09-13T00:00:00.000Z';
const hash = 'a'.repeat(64);
const domains = Object.keys(SUBMISSION_RECOVERY_DOMAINS);
const inspectionKeys = ['schemaVersion', 'domain', 'requestId', 'evidenceSha256', 'originalActorUid', 'reviewerUid', 'reviewToken', 'observation', 'receiptSha256', 'receiptSummary'].sort();
function review(domain, overrides = {}) {
  return {schemaVersion: 1, phase: 'inspect', domain, requestId,
    evidenceSha256: hash, originalActorUid: null,
    reason: 'Reviewed the retained request and current business records.', ...overrides};
}
function activation() {
  return {schemaVersion: 1, protocol: 'savedSubmissionReview.v1', enabled: true,
    domains, guardedCallableNames: ['mutateAssetHierarchy', 'mutateAssetHierarchyV2',
      'mutateChargeAbnormality', 'mutateChargeAbnormalityV2', 'assignPublishedTemplateVersion',
      'assignPublishedTemplateVersionV2', 'executeMaintenanceWorkflowCommand', 'executeMaintenanceWorkflowCommandV2'],
    sourceCommit: 'b'.repeat(40), evidenceSha256: hash, verifiedAt: '2026-09-07T00:00:00.000Z',
    legacyWorkersDrained: true, rollbackRetainsFences: true};
}
function receipt(domain) {
  const base = {schemaVersion: 1, requestId, actorUid: 'original', committedAt: Timestamp.fromDate(new Date(at)), committedAtIso: at};
  switch (domain) {
    case 'morningReview': return {...base, fingerprint: `morningreview1-sha256:${hash}`,
      result: {requestId, operation: 'START_MORNING_REVIEW', sessionId: '2026-09-13', entityId: '2026-09-13', status: 'open', version: 1, committedAt: at}};
    case 'burnerEvidence': return {...base, fingerprint: `burnerround2-sha256:${hash}`,
      operation: 'RECORD_BURNER_CONDITION_ROUND', roundId: requestId,
      assetClassId: 'class', assetInstanceId: 'furnace-7', assetNumber: 7, assetInstanceVersion: 1,
      assetClassCode: 'FURNACE', assetClassName: 'Furnace', assetName: 'Furnace 7', recordedByName: 'Original Operator', directiveId: null};
    case 'innerCoverAcceptance': return {...base, fingerprint: `innercover3-sha256:${hash}`,
      operation: 'ACCEPT_INNER_COVER', innerCoverId: 'cover-1', version: 2, secondaryVersion: null, auditId: `inner_cover_${requestId}`,
      auditEvidenceSha256: hash, timestampInstants: {inspectedOn: '2026-09-12T10:00:00.123456Z'}};
    case 'qualityMonitoring': return {...base, operation: 'CREATE_QUALITY_MONITORING_REQUEST',
      payloadFingerprint: `qualitycreate2-sha256:${hash}`, entityId: 'quality-1', resultVersion: 1,
      auditId: `server_quality_${requestId}`, creationEvidenceVersion: 2, creationAuditSha256: hash};
    case 'publishedTemplateAssignment': return {schemaVersion: 1, firestoreId: requestId,
      actorUid: 'original', payloadFingerprint: hash, packageId: 'pkg', versionId: 'version', versionNumber: 1,
      contentHash: `tg2-sha256:${hash}`, executionId: 'execution', moduleIds: ['module'],
      publicationAuditId: 'audit-1', assignedAt: at, createdAt: at, status: 'completed'};
    case 'inspectionCampaign': return {receiptSchemaVersion: 2, commandId: requestId,
      commandType: 'createInspectionCampaign', aggregateId: 'campaign', actorUid: 'original',
      authorityScope: {schemaVersion: 1, capability: 'inspectionCampaign.manage'}, payloadFingerprint: `sha256:${hash}`,
      resultKey: 'inspection-campaign-created', aggregateVersion: 1,
      result: {campaignId: 'campaign', status: 'open', definitionCode: 'DEF'}, appliedAt: at};
    default: throw new Error(domain);
  }
}
function original(domain) {
  return domain === 'inspectionCampaign' ? {commandId: requestId, commandType: 'createInspectionCampaign'} :
    {requestId, ...({morningReview: {operation: 'START_MORNING_REVIEW'},
      burnerEvidence: {operation: 'RECORD_BURNER_CONDITION_ROUND'},
      innerCoverAcceptance: {operation: 'ACCEPT_INNER_COVER'},
      qualityMonitoring: {operation: 'CREATE_QUALITY_MONITORING_REQUEST'}}[domain] || {})};
}
function clone(value) {
  if (value instanceof Timestamp) return new Timestamp(value.seconds, value.nanoseconds);
  // structuredClone in other Jest test environments produces cross-realm Dates.
  // Preserve their actual instant instead of enumerating them into empty maps.
  if (Object.prototype.toString.call(value) === '[object Date]') return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  if (value != null && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  return value;
}
function memory() {
  const store = new Map([['users/admin', {isApproved: true, roles: ['admin']}]]);
  const writes = []; const reads = [];
  const db = {collection: (name) => ({doc: (id) => ({path: `${name}/${id}`, id})}),
    async runTransaction(body, options) {
      this.lastOptions = options;
      const staged = [];
      const result = await body({
        get: async (ref) => {
          if (staged.length) throw new Error('read-after-write');
          reads.push(ref.path);
          return {exists: store.has(ref.path), data: () => clone(store.get(ref.path))};
        },
        create: (ref, data) => staged.push([ref.path, clone(data)]),
      });
      for (const [path] of staged) if (store.has(path)) throw new Error('create precondition');
      for (const [path, data] of staged) {store.set(path, data); writes.push([path, data]);}
      return result;
    }};
  return {db, store, writes, reads};
}
async function inspectProducedReceipt(domain, produced) {
  const {reviewSavedSubmissionWithDb} = require('../lib/submissionRecovery');
  const id = produced.requestId ?? produced.commandId ?? produced.firestoreId;
  const m = memory();
  m.store.set(`${SUBMISSION_RECOVERY_DOMAINS[domain].receipts}/${id}`, produced);
  const before = clone([...m.store]);
  const result = await reviewSavedSubmissionWithDb({db: m.db,
    endpoint: SUBMISSION_RECOVERY_DOMAINS[domain].endpoint, authUid: 'admin',
    data: review(domain, {requestId: id, originalActorUid: produced.actorUid})});
  expect(result.observation).toBe('receiptPresent');
  expect(Object.keys(result).sort()).toEqual(inspectionKeys);
  expect(result.receiptSummary.actorUid).toBe(produced.actorUid);
  expect(m.writes).toEqual([]);
  expect([...m.store]).toEqual(before);
  return result;
}
module.exports = {requestId, at, hash, domains, review, activation, receipt, original, clone, memory, inspectProducedReceipt, inspectionKeys};
