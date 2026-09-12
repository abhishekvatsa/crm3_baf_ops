const admin = require('firebase-admin');

const {
  mutateInnerCoverLifecycleWithDb,
} = require('../lib/innerCoverLifecycleMutation');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `inner-cover-emulator-${process.pid}-${Date.now()}`;

const IDS = {
  innerClass: '11111111-1111-4111-8111-111111111111',
  baseClass: '22222222-2222-4222-8222-222222222222',
  donor: '33333333-3333-4333-8333-333333333333',
  cover: '44444444-4444-4444-8444-444444444444',
  base: '55555555-5555-4555-8555-555555555555',
  register: '66666666-6666-4666-8666-666666666666',
  accept: '77777777-7777-4777-8777-777777777777',
  link: '88888888-8888-4888-8888-888888888888',
  delink: '99999999-9999-4999-8999-999999999999',
};

describeWithEmulator('Inner Cover lifecycle transaction', () => {
  let app;
  let db;
  let rulesEnvironment;
  let clientApi;
  let assertRulesFail;
  let secondClient;
  let unapprovedClient;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
  }

  async function invoke(data) {
    return mutateInnerCoverLifecycleWithDb({
      db,
      authUid: 'admin-1',
      data,
      now: () => new Date('2026-08-15T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  beforeAll(async () => {
    // Root Rules-test dependencies are needed only for an emulator run. Host
    // Functions jobs skip this hook and do not need the root node_modules.
    const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
    const fs = require('node:fs');
    const path = require('node:path');
    clientApi = require('firebase/firestore');
    assertRulesFail = assertFails;
    const endpoint = new URL(`http://${emulatorHost}`);
    rulesEnvironment = await initializeTestEnvironment({
      projectId,
      firestore: {
        host: endpoint.hostname,
        port: Number(endpoint.port),
        rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
      },
    });
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  }, 120000);

  beforeEach(async () => {
    await clearFirestore();
    const batch = db.batch();
    batch.set(db.collection('users').doc('admin-1'), {
      name: 'Admin One',
      email: 'admin-1@test.local',
      isApproved: true,
      roles: ['admin'],
      createdAt: new Date('2026-08-15T00:00:00.000Z'),
    });
    for (const [uid, isApproved] of [
      ['pool-reader-2', true],
      ['pool-reader-unapproved', false],
    ]) {
      batch.set(db.collection('users').doc(uid), {
        name: uid,
        email: `${uid}@test.local`,
        isApproved,
        roles: ['operations'],
        createdAt: new Date('2026-08-15T00:00:00.000Z'),
      });
    }
    batch.set(db.collection('asset_classes').doc(IDS.innerClass), {
      schemaVersion: 1,
      assetClassId: IDS.innerClass,
      code: 'INNER_COVER',
      name: 'Inner Cover',
      legacyAssetTypeKey: 'innerCover',
      status: 'active',
      version: 1,
    });
    batch.set(db.collection('asset_classes').doc(IDS.baseClass), {
      schemaVersion: 1,
      assetClassId: IDS.baseClass,
      code: 'BASE',
      name: 'Base',
      legacyAssetTypeKey: 'base',
      status: 'active',
      version: 1,
    });
    batch.set(db.collection('asset_instances').doc(IDS.base), {
      schemaVersion: 1,
      assetInstanceId: IDS.base,
      assetClassId: IDS.baseClass,
      assetClassCode: 'BASE',
      assetClassName: 'Base',
      assetNumber: 201,
      name: 'Base 201',
      status: 'active',
      serviceState: 'inService',
      version: 1,
    });
    batch.set(db.collection('inner_cover_profiles').doc(IDS.donor), {
      schemaVersion: 1,
      innerCoverId: IDS.donor,
      assetClassId: IDS.innerClass,
      assetClassCode: 'INNER_COVER',
      assetClassName: 'Inner Cover',
      serialNumber: 'GR20',
      normalizedSerialNumber: 'GR20',
      sourceType: 'legacyExisting',
      lifecycleState: 'retiredForSalvage',
      traceabilityGrade: 'T0',
      currentBaseAssetInstanceId: null,
      currentBaseAssetNumber: null,
      currentBaseAssetName: null,
      currentLinkageId: null,
      version: 6,
      lastMutationId: 'seed',
    });
    await batch.commit();
    secondClient = rulesEnvironment.authenticatedContext('pool-reader-2').firestore();
    unapprovedClient = rulesEnvironment.authenticatedContext('pool-reader-unapproved').firestore();
  });

  afterAll(async () => {
    try {
      if (rulesEnvironment) await rulesEnvironment.cleanup();
    } finally {
      if (app) await app.delete();
    }
  });

  async function readSecondClientProfiles() {
    // The Flutter repository reads this collection before applying pool filters.
    // Force the client read to the emulator server so a cached snapshot cannot
    // satisfy the cross-client visibility assertions.
    const snapshot = await clientApi.getDocsFromServer(
      clientApi.collection(secondClient, 'inner_cover_profiles'),
    );
    expect(snapshot.metadata.fromCache).toBe(false);
    return snapshot.docs.map((document) => ({id: document.id, ...document.data()}));
  }

  test.each([
    ['inner_cover_acceptance_dart_request.json', '2026-09-12T08:30:00.123Z'],
    ['inner_cover_acceptance_legacy_dart_request.json', '2026-09-12T08:30:00.123456Z'],
  ])('actual Dart wire fixture %s reaches a second authorized client pool and stays replayable after installation', async (file, instant) => {
    const request = require(`./fixtures/${file}`);
    const send = (data) => mutateInnerCoverLifecycleWithDb({
      db, authUid: 'admin-1', data,
      now: () => new Date('2026-09-12T08:30:01.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
    // The shared fixture uses this id. Replace the unrelated donor seed for
    // this test with an actual governed registration of the same serial.
    await db.collection('inner_cover_profiles').doc(request.innerCoverId).delete();
    await send({
      requestId: IDS.register, operation: 'REGISTER_INNER_COVER',
      innerCoverId: request.innerCoverId, innerCoverAssetClassId: IDS.innerClass,
      reason: 'Register the acceptance regression cover.',
      registrationDraft: {
        serialNumber: 'MICRO-30', sourceType: 'purchased',
        originClassification: 'documentedPurchase', supplierOrFabricator: 'Test supplier',
        receivedOrCompletedOn: '2026-09-11T00:00:00.000Z',
        incorporatedOn: '2026-09-11T12:00:00.000Z', drawingReference: 'IC-30',
        materialGrade: 'SS 321', notes: null, fabricationSections: [],
      },
    });
    const awaitingProfiles = await readSecondClientProfiles();
    expect(awaitingProfiles.find((profile) => profile.id === request.innerCoverId))
      .toMatchObject({serialNumber: 'MICRO-30', lifecycleState: 'awaitingInspection', version: 1});
    expect(awaitingProfiles.filter((profile) => profile.lifecycleState === 'available'))
      .not.toEqual(expect.arrayContaining([expect.objectContaining({id: request.innerCoverId})]));
    await assertRulesFail(clientApi.getDocsFromServer(
      clientApi.collection(unapprovedClient, 'inner_cover_profiles'),
    ));
    expect(request.acceptanceDraft.inspectedOn).toBe(instant);
    const accepted = await send(request);
    const profileRef = db.collection('inner_cover_profiles').doc(request.innerCoverId);
    const acceptedProfile = (await profileRef.get()).data();
    expect(acceptedProfile).toMatchObject({
      serialNumber: 'MICRO-30', version: 2, lifecycleState: 'available',
      acceptedByUid: 'admin-1', acceptanceReference: request.acceptanceDraft.acceptanceReference,
    });
    expect(acceptedProfile.acceptedAt.toDate().toISOString())
      .toBe('2026-09-12T08:30:00.123Z');
    const acceptedProfiles = await readSecondClientProfiles();
    expect(acceptedProfiles.filter((profile) => profile.lifecycleState === 'available'))
      .toEqual(expect.arrayContaining([expect.objectContaining({
        id: request.innerCoverId, innerCoverId: request.innerCoverId,
        serialNumber: 'MICRO-30', normalizedSerialNumber: 'MICRO30',
        lifecycleState: 'available', version: 2,
        currentBaseAssetInstanceId: null,
      })]));
    const receipt = (await db.collection('inner_cover_lifecycle_receipts')
      .doc(request.requestId).get()).data();
    const audit = (await db.collection('inner_cover_lifecycle_audits')
      .doc(accepted.auditId).get()).data();
    expect(receipt.timestampInstants).toEqual({inspectedOn: instant});
    expect(audit.timestampInstants).toEqual(receipt.timestampInstants);
    const linked = await send({
      requestId: 'aaaaaaaa-1234-4234-8234-123456789abc',
      operation: 'LINK_INNER_COVER', innerCoverId: request.innerCoverId,
      expectedVersion: 2, targetBaseAssetInstanceId: IDS.base,
      reason: 'Install the exactly accepted regression cover.',
    });
    expect(linked.version).toBe(3);
    const installedProfiles = await readSecondClientProfiles();
    expect(installedProfiles.find((profile) => profile.id === request.innerCoverId))
      .toMatchObject({
        serialNumber: 'MICRO-30', lifecycleState: 'installed', version: 3,
        currentBaseAssetInstanceId: IDS.base, currentBaseAssetNumber: 201,
      });
    for (const pool of [
      installedProfiles.filter((profile) => profile.lifecycleState === 'available'),
      installedProfiles.filter((profile) => profile.lifecycleState !== 'installed'),
    ]) {
      expect(pool)
        .not.toEqual(expect.arrayContaining([expect.objectContaining({id: request.innerCoverId})]));
    }
    await assertRulesFail(clientApi.getDocsFromServer(
      clientApi.collection(unapprovedClient, 'inner_cover_profiles'),
    ));
    const beforeReplay = await profileRef.get();
    expect(await send(request)).toEqual({...accepted, idempotentReplay: true});
    const afterReplay = await profileRef.get();
    expect(afterReplay.updateTime.isEqual(beforeReplay.updateTime)).toBe(true);
    expect(afterReplay.data()).toMatchObject({
      lifecycleState: 'installed', currentBaseAssetInstanceId: IDS.base, version: 3,
    });
    expect((await db.collection('base_inner_cover_assignments').doc(IDS.base).get()).data())
      .toMatchObject({innerCoverId: request.innerCoverId});
    expect((await db.collection('inner_cover_lifecycle_receipts').get()).size).toBe(3);
    expect((await db.collection('inner_cover_lifecycle_audits').get()).size).toBe(3);
  });

  test('fabrication, acceptance, installation and removal preserve exact custody', async () => {
    const fabricatedSections = [
      {
        sectionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        sectionType: 'lowerAssembly',
        materialSource: 'reusedKnownDonor',
        donorInnerCoverId: IDS.donor,
        donorSectionKey: 'lower-01',
        donorExpectedVersion: 6,
        lengthMm: 1200,
        cutCount: 1,
        notes: null,
      },
      {
        sectionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        sectionType: 'flatVertical',
        materialSource: 'newPurchased',
        donorInnerCoverId: null,
        donorSectionKey: null,
        donorExpectedVersion: null,
        lengthMm: 2200,
        cutCount: 1,
        notes: null,
      },
      {
        sectionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        sectionType: 'corrugatedShell',
        materialSource: 'newFabricated',
        donorInnerCoverId: null,
        donorSectionKey: null,
        donorExpectedVersion: null,
        lengthMm: 4400,
        cutCount: 2,
        notes: null,
      },
      {
        sectionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        sectionType: 'topCover',
        materialSource: 'newFabricated',
        donorInnerCoverId: null,
        donorSectionKey: null,
        donorExpectedVersion: null,
        lengthMm: null,
        cutCount: 1,
        notes: null,
      },
    ];
    const registered = await invoke({
      requestId: IDS.register,
      operation: 'REGISTER_INNER_COVER',
      innerCoverId: IDS.cover,
      innerCoverAssetClassId: IDS.innerClass,
      reason: 'Register fabricated Inner Cover with exact donor genealogy.',
      registrationDraft: {
        serialNumber: 'GR30',
        sourceType: 'fabricated',
        originClassification: 'documentedFabrication',
        supplierOrFabricator: 'BAF approved fabricator',
        receivedOrCompletedOn: '2026-08-14T00:00:00.000Z',
        incorporatedOn: '2026-08-14T12:00:00.000Z',
        drawingReference: 'IC-001',
        materialGrade: 'SS 321',
        notes: null,
        fabricationSections: fabricatedSections,
      },
    });
    expect(registered).toMatchObject({version: 1});
    expect((await db.collection('inner_cover_profiles').doc(IDS.donor).get()).data())
      .toMatchObject({lifecycleState: 'partiallyDismantled', version: 7});
    expect((await db.collection('inner_cover_donor_part_claims').get()).size)
      .toBe(1);

    await invoke({
      requestId: IDS.accept,
      operation: 'ACCEPT_INNER_COVER',
      innerCoverId: IDS.cover,
      expectedVersion: 1,
      reason: 'Accept after dimensional inspection and leak testing.',
      acceptanceDraft: {
        inspectedOn: '2026-08-15T00:00:00.000Z',
        acceptanceReference: 'ACC-GR30',
        leakTestReference: 'LT-GR30',
        ndtReference: null,
        notes: 'Accepted for installation.',
      },
    });
    await invoke({
      requestId: IDS.link,
      operation: 'LINK_INNER_COVER',
      innerCoverId: IDS.cover,
      expectedVersion: 2,
      targetBaseAssetInstanceId: IDS.base,
      reason: 'Install fabricated Inner Cover on Base 201.',
    });
    const linked = (
      await db.collection('base_inner_cover_assignments').doc(IDS.base).get()
    ).data();
    expect(linked).toMatchObject({
      baseAssetNumber: 201,
      innerCoverId: IDS.cover,
      innerCoverSerialNumber: 'GR30',
      version: 1,
    });

    await invoke({
      requestId: IDS.delink,
      operation: 'DELINK_INNER_COVER',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      sourceBaseAssetInstanceId: IDS.base,
      expectedSourceAssignmentVersion: 1,
      targetState: 'awaitingInspection',
      reason: 'Remove after service and return for inspection.',
    });
    expect((await db.collection('base_inner_cover_assignments').doc(IDS.base).get()).exists)
      .toBe(false);
    expect((await db.collection('inner_cover_profiles').doc(IDS.cover).get()).data())
      .toMatchObject({
        lifecycleState: 'awaitingInspection',
        currentBaseAssetInstanceId: null,
        version: 4,
      });
    const history = await db.collection('inner_cover_linkages')
      .where('innerCoverId', '==', IDS.cover).get();
    expect(history.size).toBe(1);
    expect(history.docs[0].data()).toMatchObject({
      active: false,
      removalAction: 'DELINK_INNER_COVER',
    });
  });
});
