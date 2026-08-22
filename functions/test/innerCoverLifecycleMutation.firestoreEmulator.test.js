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
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

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
  });

  afterAll(async () => {
    if (app) await app.delete();
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
