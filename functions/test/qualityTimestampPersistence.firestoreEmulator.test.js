const {randomUUID} = require('crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {mutateQualityWithDb} = require('../lib/qualityMutation');
const {baseAssociationCase} = require('./qualityTimestampFixtures.cjs');

jest.setTimeout(30000);
const host = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = host ? describe : describe.skip;

describeWithEmulator('persisted Base Quality association timestamp transaction', () => {
  let app;
  let db;
  const cleanup = new Set();
  // Always isolate these fixtures from both production and the interactive DEV
  // dataset. Cleanup deletes only documents created by this test run.
  beforeAll(() => {
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
      throw new Error('This regression requires a loopback Firestore emulator.');
    }
    app = initializeApp({projectId: 'demo-crm3-quality-native-ts'}, `quality-ts-${randomUUID()}`);
    db = getFirestore(app);
  });
  afterAll(async () => {
    if (db) await Promise.all([...cleanup].map((path) => db.doc(path).delete()));
    if (app) await deleteApp(app);
  });

  async function setup({invalidChronology = false} = {}) {
    const fixture = baseAssociationCase(`timestamp-${randomUUID()}`);
    if (invalidChronology) {
      fixture.warning.affectedAssets[0].assetHierarchyRef.innerCoverAssociation.eventAt =
        Timestamp.fromDate(new Date('2026-09-15T00:00:00Z'));
    }
    const actorUid = `timestamp-si-${randomUUID()}`;
    const requestId = randomUUID();
    const rows = {
      [`users/${actorUid}`]: {isApproved: true, roles: ['si'], name: 'SI Timestamp Fixture'},
      [`quality_warnings/${fixture.warningId}`]: fixture.warning,
      [`charge_abnormalities/${fixture.abnormalityId}`]: fixture.abnormality,
      [`maintenance_records/${fixture.issueId}`]: fixture.issue,
    };
    const auditPath = `audit_logs/server_quality_${requestId}`;
    const receiptPath = `quality_mutation_receipts/${requestId}`;
    for (const path of [...Object.keys(rows), auditPath, receiptPath]) cleanup.add(path);
    await Promise.all(Object.entries(rows).map(([path, value]) => db.doc(path).set(value)));
    const data = {
      requestId, operation: 'CLOSE_QUALITY_WARNING', warningId: fixture.warningId,
      expectedVersion: 1, reason: 'Inspection found the affected coil acceptable.',
      disposition: 'coilFoundAcceptable', linkedReannealingChargeNos: [],
    };
    const call = () => mutateQualityWithDb({
      db, authUid: actorUid, data,
      now: () => new Date('2026-09-26T12:00:00Z'),
      timestampFromDate: Timestamp.fromDate,
    });
    return {...fixture, actorUid, call, auditPath, receiptPath};
  }

  test('native Firestore readback closes atomically and replays with original evidence', async () => {
    const fixture = await setup();
    const before = (await db.doc(`quality_warnings/${fixture.warningId}`).get()).data();
    const association = before.affectedAssets[0].assetHierarchyRef.innerCoverAssociation;
    expect(association.eventAt).toBeInstanceOf(Timestamp);
    expect(association.confirmedAt).toBeInstanceOf(Timestamp);
    const first = await fixture.call();
    expect(first).toMatchObject({version: 2, idempotentReplay: false});
    const after = (await db.doc(`quality_warnings/${fixture.warningId}`).get()).data();
    expect(after).toMatchObject({status: 'closed', closureDisposition: 'coilFoundAcceptable',
      closedByUid: fixture.actorUid, version: 2});
    expect(after.affectedAssets).toEqual(before.affectedAssets);
    const linked = (await db.doc(`charge_abnormalities/${fixture.abnormalityId}`).get()).data();
    expect(linked).toMatchObject({reannealingStatus: 'notRequired', version: 2});
    expect(linked.affectedAssets).toEqual(fixture.abnormality.affectedAssets);
    expect(linked.affectedAssetHierarchyRefs).toEqual(before.affectedAssets);
    const audit = await db.doc(fixture.auditPath).get();
    const receipt = await db.doc(fixture.receiptPath).get();
    expect(JSON.parse(audit.data().beforeJson).affectedAssets)
      .toEqual(JSON.parse(JSON.stringify(before.affectedAssets)));
    expect(JSON.parse(audit.data().afterJson).affectedAssets)
      .toEqual(JSON.parse(JSON.stringify(before.affectedAssets)));
    expect(await fixture.call()).toEqual({...first, idempotentReplay: true});
    expect((await db.doc(fixture.auditPath).get()).updateTime).toEqual(audit.updateTime);
    expect((await db.doc(fixture.receiptPath).get()).updateTime).toEqual(receipt.updateTime);
  });

  test('invalid native chronology still fails atomically without audit or receipt', async () => {
    const fixture = await setup({invalidChronology: true});
    await expect(fixture.call()).rejects.toMatchObject({
      code: 'failed-precondition', details: {reasonCode: 'quality-warning-malformed',
        field: 'affectedAssets[0].assetHierarchyRef'},
    });
    expect((await db.doc(`quality_warnings/${fixture.warningId}`).get()).data())
      .toMatchObject({status: 'open', version: 1});
    expect((await db.doc(`charge_abnormalities/${fixture.abnormalityId}`).get()).data())
      .toMatchObject({reannealingStatus: 'pendingDecision', version: 1});
    expect((await db.doc(fixture.auditPath).get()).exists).toBe(false);
    expect((await db.doc(fixture.receiptPath).get()).exists).toBe(false);
  });
});
