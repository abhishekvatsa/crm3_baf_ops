const admin = require('firebase-admin');
const {mutateAssetHierarchyWithDb} = require('../lib/assetHierarchyMutation');
const {mutateInnerCoverLifecycleWithDb} = require('../lib/innerCoverLifecycleMutation');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId = process.env.GCLOUD_PROJECT || 'crm3-baf-ops-b8638';
const id = (n) => `${String(n).padStart(8, '0')}-1111-4111-8111-111111111111`;
const classId = id(1);
const createClass = (role = 'innerCover', extra = {}) => ({requestId: id(10),
  operation: 'CREATE_CLASS', assetClassId: classId, reason: 'Create reviewed class.',
  classDraft: {code: role === 'innerCover' ? 'INNER_COVER' : 'FURNACE', name: role,
    majorArea: 'BAF', shortDescription: null, longDescription: null, legacyAssetTypeKey: role}, ...extra});
const retireClass = () => ({requestId: id(12), operation: 'SET_CLASS_STATUS', assetClassId: classId,
  expectedVersion: 1, status: 'retired', reason: 'Retire empty class.'});
const registration = () => ({requestId: id(500), operation: 'REGISTER_INNER_COVER',
  innerCoverId: id(501), innerCoverAssetClassId: classId, reason: 'Register received serial inventory.',
  registrationDraft: {serialNumber: 'IC-501', sourceType: 'purchased',
    originClassification: 'documentedPurchase', supplierOrFabricator: 'Approved supplier',
    receivedOrCompletedOn: '2026-09-01T00:00:00.000Z', incorporatedOn: '2026-09-01T12:00:00.000Z',
    drawingReference: 'IC-001', materialGrade: 'SS 321', notes: null, fabricationSections: []}});
const nodeDraft = (name, parentNodeId = null) => ({parentNodeId, nodeType: 'component', name,
  componentTag: null, shortDescription: null, longDescription: null, discipline: null,
  operatingType: null, normalState: null, failState: null, contactArrangement: 'notStated',
  manufacturer: null, model: null, applicability: null, sourceReference: null,
  ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: [], sortOrder: 1});

describeWithEmulator('master-data transaction and client boundary regressions', () => {
  let app; let db; let environment; let client; let assertFails;
  const args = (data) => ({db, data, authUid: 'admin-1',
    now: () => new Date('2026-09-12T12:00:00.000Z'), timestampFromDate: admin.firestore.Timestamp.fromDate});
  const invoke = (data) => mutateAssetHierarchyWithDb(args(data));
  const invokeCover = (data) => mutateInnerCoverLifecycleWithDb(args(data));
  beforeAll(async () => {
    const {initializeTestEnvironment, assertFails: rejectsRules} = require('@firebase/rules-unit-testing');
    const fs = require('fs'); const path = require('path');
    client = require('firebase/firestore'); assertFails = rejectsRules;
    const endpoint = new URL(`http://${emulatorHost}`);
    environment = await initializeTestEnvironment({projectId, firestore: {
      host: endpoint.hostname, port: Number(endpoint.port),
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
    }});
    app = admin.initializeApp({projectId}, `master-integrity-${process.pid}-${Date.now()}`);
    db = admin.firestore(app);
  }, 120000);
  beforeEach(async () => {
    await environment.clearFirestore();
    await db.doc('users/admin-1').set({name: 'Admin One', email: 'admin-1@test.local',
      isApproved: true, roles: ['admin'], createdAt: new Date('2026-09-01T00:00:00Z')});
  });
  afterAll(async () => { if (environment) await environment.cleanup(); if (app) await app.delete(); });

  test('distinct class IDs/codes race for one role: exactly one real transaction commits', async () => {
    const a = createClass('furnace');
    const b = createClass('furnace', {requestId: id(20), assetClassId: id(21),
      classDraft: {...a.classDraft, code: 'FURNACE_ALTERNATE'}});
    const results = await Promise.allSettled([invoke(a), invoke(b)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.find((r) => r.status === 'rejected').reason.details.reasonCode)
      .toBe('asset-class-legacy-role-collision');
    const owners = await db.collection('asset_classes').where('legacyAssetTypeKey', '==', 'furnace').get();
    expect(owners.docs.filter((doc) => doc.data().status === 'active')).toHaveLength(1);
    expect((await db.collection('asset_hierarchy_mutation_receipts').get()).size).toBe(1);
  }, 60000);

  test.each([false, true])('serial registration and retirement race safely, reversed launch=%s', async (reversed) => {
    await invoke(createClass());
    const operations = [() => invoke(retireClass()), () => invokeCover(registration())];
    if (reversed) operations.reverse();
    const results = await Promise.allSettled(operations.map((operation) => operation()));
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const owner = (await db.doc(`asset_classes/${classId}`).get()).data();
    const profile = await db.doc(`inner_cover_profiles/${id(501)}`).get();
    expect(owner.status === 'retired' && profile.exists).toBe(false);
    expect((await db.doc(`asset_class_mutation_guards/serialInventory:${classId}`).get()).exists).toBe(true);
  }, 60000);

  test('root move reads back canonical ancestry/counters; parent acceptance survives child mutations', async () => {
    await invoke(createClass('furnace'));
    const parent = {requestId: id(101), operation: 'CREATE_NODE', assetClassId: classId,
      nodeId: id(2), expectedAssetClassVersion: 1, reason: 'Create parent.', nodeDraft: nodeDraft('Parent')};
    const accepted = await invoke(parent);
    await invoke({...parent, requestId: id(102), nodeId: id(3), nodeDraft: nodeDraft('Leaf', id(2))});
    await invoke({requestId: id(103), operation: 'UPDATE_NODE', assetClassId: classId,
      nodeId: id(3), expectedVersion: 1, reason: 'Move to class root.', nodeDraft: nodeDraft('Leaf', null)});
    const parentBefore = await db.doc(`asset_hierarchy_nodes/${id(2)}`).get();
    const leaf = (await db.doc(`asset_hierarchy_nodes/${id(3)}`).get()).data();
    expect(leaf).toMatchObject({parentNodeId: null, ancestorNodeIds: [], hierarchyPath: ['Leaf']});
    expect(parentBefore.data()).toMatchObject({activeChildCount: 0, version: 3});
    expect(await invoke(parent)).toEqual({...accepted, idempotentReplay: true});
    expect((await db.doc(`asset_hierarchy_nodes/${id(2)}`).get()).updateTime.isEqual(parentBefore.updateTime)).toBe(true);
    const auditRef = db.doc(`asset_hierarchy_audits/asset_hierarchy_${parent.requestId}`);
    const stamp = (await auditRef.get()).data().performedAt;
    await auditRef.update({performedAt: new admin.firestore.Timestamp(stamp.seconds, stamp.nanoseconds + 1000)});
    expect((await auditRef.get()).data().performedAt.nanoseconds).toBe(stamp.nanoseconds + 1000);
    await expect(invoke(parent)).rejects.toMatchObject({code: 'data-loss'});
  });

  test.each(['legacyRole:innerCover', `serialInventory:${classId}`])(
    'approved Admin clients cannot read or mutate server guard %s', async (guardId) => {
      await invoke(createClass()); await invokeCover(registration());
      const api = environment.authenticatedContext('admin-1').firestore();
      const ref = client.doc(api, `asset_class_mutation_guards/${guardId}`);
      await assertFails(client.getDoc(ref));
      await assertFails(client.setDoc(ref, {schemaVersion: 1, version: 999}));
      await assertFails(client.deleteDoc(ref));
    });
});
