const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const {fakeDb} = require('./helpers/qualityMemoryFirestore.cjs');
const {mutateQualityWithDb} = require('../lib/qualityMutation');

const fixturePath = path.join(__dirname, 'fixtures/quality_monitoring_legacy_creation.json');
const request = () => ({requestId: '11111111-1111-4111-8111-111111111111',
  operation: 'CREATE_QUALITY_MONITORING_REQUEST', monitoringRequestId: '44444444-4444-4444-8444-444444444444',
  expectedVersion: 0, reason: 'Monitor reviewed atmosphere stability.', baseNumber: 12,
  baseAssetClassId: 'base-class', baseAssetInstanceId: 'base-12', baseAssetInstanceVersion: 4,
  grade: 'CRGO M4', cycleReference: 'Cycle family 7A', chargeNumbers: [12011, 12012]});
const seed = () => ({
  'users/admin-1': {name: 'Admin One', isApproved: true, roles: ['admin']},
  'asset_classes/base-class': {schemaVersion: 1, assetClassId: 'base-class', code: 'BASE', name: 'Base', legacyAssetTypeKey: 'base', status: 'active'},
  'asset_instances/base-12': {schemaVersion: 1, assetInstanceId: 'base-12', assetClassId: 'base-class', assetClassCode: 'BASE', assetClassName: 'Base', assetNumber: 12, name: 'Base 12', status: 'active', version: 4},
});
const invoke = (memory, data, actorUid = 'admin-1') => mutateQualityWithDb({db: memory.db, authUid: actorUid,
  data, now: () => new Date('2026-09-12T12:00:00.000Z'), timestampFromDate: (date) => admin.firestore.Timestamp.fromDate(date)});
const close = () => ({requestId: '22222222-2222-4222-8222-222222222222', operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
  monitoringRequestId: request().monitoringRequestId, expectedVersion: 1, reason: 'Representative later completed monitoring.'});

(process.env.CAPTURE_LEGACY_QUALITY_CREATION === '1' ? test : test.skip)(
  'capture actual deployed quality creation receipt and audit', async () => {
    const memory = fakeDb(seed());
    const {captureLegacyQualityCreation} = require('./helpers/captureLegacyQualityCreation.cjs');
    const fixture = await captureLegacyQualityCreation({db: memory.db, data: request(), actorUid: 'admin-1',
      timestampFromDate: (date) => admin.firestore.Timestamp.fromDate(date)});
    fs.writeFileSync(fixturePath, JSON.stringify({...fixture, documents: [...memory.store.entries()]}, null, 2) + '\n');
  }, 60000);

const normalize = (value) => JSON.parse(JSON.stringify(value));
const legacy = () => JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

describe.each(['legacy', 'modern'])('%s original monitoring creation replay', (generation) => {
  async function accepted() {
    if (generation === 'legacy') {
      const fixture = legacy();
      return {memory: fakeDb(Object.fromEntries(fixture.documents)), expected: fixture.accepted, command: fixture.request};
    }
    const memory = fakeDb(seed()); const command = request();
    return {memory, expected: normalize(await invoke(memory, command)), command};
  }
  test('creation A → close B → retry A returns original acceptance with zero writes', async () => {
    const {memory, expected, command} = await accepted();
    await invoke(memory, close());
    const before = normalize([...memory.store.entries()]); const writes = memory.writes.length;
    expect(normalize(await invoke(memory, command))).toEqual({...expected, idempotentReplay: true});
    expect(normalize([...memory.store.entries()])).toEqual(before); expect(memory.writes.length).toBe(writes);
    expect(memory.store.get(`quality_monitoring_requests/${command.monitoringRequestId}`).status).toBe('closed');
  });
  test.each(['reasonNotes', 'performedByUid', 'afterJson', 'timestamp', 'resultVersion', 'beforeJson'])(
    'corrupt original audit %s is refused without writes after later closure', async (field) => {
      const {memory, command} = await accepted(); await invoke(memory, close());
      const audit = memory.store.get(`audit_logs/server_quality_${command.requestId}`);
      audit[field] = field === 'timestamp' ? new Date('2026-09-07T12:00:01Z') : 'tampered';
      const writes = memory.writes.length;
      await expect(invoke(memory, command)).rejects.toMatchObject({code: 'data-loss'});
      expect(memory.writes.length).toBe(writes);
    });
  test('changed origin or saved request never borrows original acceptance', async () => {
    const {memory, command} = await accepted();
    memory.store.set('users/admin-2', {name: 'Other Admin', isApproved: true, roles: ['admin']});
    await expect(invoke(memory, command, 'admin-2')).rejects.toMatchObject({code: 'aborted'});
    await expect(invoke(memory, {...command, grade: 'Different grade'})).rejects.toMatchObject({code: 'aborted'});
  });
  test.each(['createdByUid', 'createdByName', 'grade', 'baseAssetInstanceVersion', 'createdAt'])(
    'valid-looking original creation snapshot alteration %s cannot borrow acceptance', async (field) => {
      const {memory, command} = await accepted(); await invoke(memory, close());
      const audit = memory.store.get(`audit_logs/server_quality_${command.requestId}`);
      const after = JSON.parse(audit.afterJson);
      after[field] = field === 'createdAt' ? {_seconds: 1788782400, _nanoseconds: 1000} :
        field === 'baseAssetInstanceVersion' ? 5 : 'Different original evidence';
      audit.afterJson = JSON.stringify(after);
      await expect(invoke(memory, command)).rejects.toMatchObject({code: 'data-loss'});
    });
  test.each(['committedAt', 'committedAtIso', 'requestId', 'expectedVersion', 'resultVersion'])(
    'original receipt %s drift cannot become success', async (field) => {
      const {memory, command} = await accepted();
      const receipt = memory.store.get(`quality_mutation_receipts/${command.requestId}`);
      receipt[field] = field === 'committedAt' ? {_seconds: 1788782400, _nanoseconds: 1000} :
        field === 'expectedVersion' ? 1 : field === 'resultVersion' ? 2 : 'Different evidence';
      await expect(invoke(memory, command)).rejects.toMatchObject({code: 'data-loss'});
    });
});

test('new creation proof cannot be downgraded by changing only its receipt fingerprint or removing its audit marker', async () => {
  for (const variant of ['fingerprint', 'audit-marker', 'digest']) {
    const memory = fakeDb(seed()); const command = request(); await invoke(memory, command);
    const receipt = memory.store.get(`quality_mutation_receipts/${command.requestId}`);
    const audit = memory.store.get(`audit_logs/server_quality_${command.requestId}`);
    expect(receipt.payloadFingerprint).toMatch(/^qualitycreate2-sha256:/);
    if (variant === 'fingerprint') receipt.payloadFingerprint = receipt.payloadFingerprint.replace('qualitycreate2-', 'qualityreq1-');
    if (variant === 'audit-marker') delete audit.creationEvidenceVersion;
    if (variant === 'digest') delete receipt.creationAuditSha256;
    await expect(invoke(memory, command)).rejects.toMatchObject({code: 'data-loss'});
  }
});

test('installed number-only request preserves its actual accepted server-resolved Base identity after closure', async () => {
  const memory = fakeDb(seed()); const command = request();
  delete command.baseAssetClassId; delete command.baseAssetInstanceId; delete command.baseAssetInstanceVersion;
  const accepted = normalize(await invoke(memory, command)); await invoke(memory, close());
  expect(normalize(await invoke(memory, command))).toEqual({...accepted, idempotentReplay: true});
});
