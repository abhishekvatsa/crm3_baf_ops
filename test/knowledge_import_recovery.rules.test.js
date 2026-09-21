const fs = require('node:fs');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  runTransaction, serverTimestamp, Timestamp, setLogLevel,
} = require('firebase/firestore');

let environment;
const auditPath = 'audit_logs/knowledge_revision_KB-001_1';

beforeAll(async () => {
  setLogLevel('error');
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  environment = await initializeTestEnvironment({
    projectId: 'demo-knowledge-import-recovery',
    firestore: {host, port: Number(port), rules: fs.readFileSync('firestore.rules', 'utf8')},
  });
}, 120000);

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    for (const [uid, roles, isApproved] of [
      ['si', ['si'], true], ['admin', ['admin'], true],
      ['operations', ['operations'], true], ['unapproved', ['si'], false],
    ]) {
      await setDoc(doc(context.firestore(), `users/${uid}`), {
        name: uid, email: `${uid}@test.invalid`, roles, isApproved,
        createdAt: Timestamp.now(),
      });
    }
  });
});

afterAll(async () => {
  if (environment) await environment.cleanup();
  setLogLevel('warn');
});

function dbAs(uid) { return environment.authenticatedContext(uid).firestore(); }

function row() {
  return {
    rowCode: 'KB-001', schemaVersion: 1,
    taskText: 'Inspect hydraulic clamp pressure before furnace cycle.',
    moduleCandidateCode: 'KB-MOD-001', ownerDisciplines: ['mechanical'],
    safetyClasses: ['hydraulic'], procedureRefs: ['SOP-BAF-CLAMP'],
    partRefs: [], deviceTags: [], targetRefs: ['base:101'],
    suggestedFields: ['Observation'], composerReadiness: 'readyPreset',
    confidence: 'confirmedManual', lifecycleStatus: 'active', matrixVersion: 'v1',
    changeSummary: 'Reviewed controlled knowledge import.',
    updatedByUid: 'si', updatedAt: serverTimestamp(), version: 1,
    createdByUid: 'si', createdAt: serverTimestamp(), isDeleted: false,
  };
}

function audit() {
  return {
    entityType: 'knowledge_base', entityId: 'KB-001', action: 'create',
    performedByUid: 'si', performedByName: 'Section in-charge',
    timestamp: serverTimestamp(), reason: 'other',
    reasonNotes: 'Reviewed controlled knowledge import.',
    summary: 'Imported KB-001', severity: 'low', beforeJson: null,
    afterJson: JSON.stringify({version: 1, governanceAction: 'importedFromExternal'}),
  };
}

test('SI import transaction checks absent revision and reads its accepted atomic audit', async () => {
  const db = dbAs('si');
  const auditRef = doc(db, auditPath);
  expect((await assertSucceeds(getDoc(auditRef))).exists()).toBe(false);
  await assertSucceeds(runTransaction(db, async (transaction) => {
    expect((await transaction.get(auditRef)).exists()).toBe(false);
    const rowRef = doc(db, 'knowledge_base/KB-001');
    expect((await transaction.get(rowRef)).exists()).toBe(false);
    transaction.set(rowRef, row());
    transaction.set(auditRef, audit());
  }));
  const accepted = await assertSucceeds(getDoc(auditRef));
  expect(accepted.data().entityType).toBe('knowledge_base');
  expect(accepted.data().timestamp).toBeInstanceOf(Timestamp);
  await assertFails(getDocs(collection(db, 'audit_logs')));
  await assertFails(updateDoc(auditRef, {summary: 'Changed after acceptance'}));
  await assertFails(deleteDoc(auditRef));
});

test.each([
  'ordinary-audit', 'knowledge_revision_KB-001_0',
  'knowledge_revision_KB-001_01', 'knowledge_revision_KB-001_-1',
  'knowledge_revision_KB-001_', 'knowledge_revision_K_1',
  `knowledge_revision_${'K'.repeat(65)}_1`, 'knowledge_revision_KB 001_1',
])('SI cannot probe an absent ordinary or malformed audit ID: %s', async (id) => {
  await assertFails(getDoc(doc(dbAs('si'), `audit_logs/${id}`)));
});

test.each(['user', 'maintenance', null])(
  'reserved-looking existing unrelated audit remains private (%s)', async (entityType) => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), auditPath), {entityType, entityId: 'private-subject'});
    });
    await assertFails(getDoc(doc(dbAs('si'), auditPath)));
  },
);

test.each(['operations', 'unapproved'])('non-governor %s cannot probe or impersonate knowledge audits', async (uid) => {
  const db = dbAs(uid);
  await assertFails(getDoc(doc(db, auditPath)));
  await assertFails(setDoc(doc(db, auditPath), {...audit(), performedByUid: uid}));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), auditPath), {
      ...audit(), timestamp: Timestamp.now(),
    });
  });
  await assertFails(getDoc(doc(db, auditPath)));
});

test('anonymous callers cannot probe absent revision audits', async () => {
  await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), auditPath)));
});

test('SI cannot pre-create a revision audit without its matching atomic row write', async () => {
  await assertFails(setDoc(doc(dbAs('si'), auditPath), audit()));
});
