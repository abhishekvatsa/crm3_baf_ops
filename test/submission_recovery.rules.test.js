const fs = require('fs');
const path = require('path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc} = require('firebase/firestore');
// Existing Rules suites use their own emulator namespaces. Never select a real
// project identifier for this new server-control proof, even under that runner.
const projectId = process.env.GCLOUD_PROJECT?.startsWith('demo-') ? process.env.GCLOUD_PROJECT : 'demo-submission-recovery';
const collections = ['submission_recovery_decisions', 'submission_recovery_fences', 'submission_recovery_controls'];
let env;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !projectId.startsWith('demo-')) {
    throw new Error('Recovery Rules proof requires an isolated demo Firestore emulator.');
  }
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port),
    rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8')}});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/admin'), {isApproved: true, roles: ['admin'], name: 'Admin'});
    await setDoc(doc(db, 'users/operator'), {isApproved: true, roles: ['operations'], name: 'Operator'});
    for (const name of collections) await setDoc(doc(db, name, 'existing'), {schemaVersion: 1, serverEvidence: true});
  });
});
afterAll(async () => {if (env) await env.cleanup();});

test.each(collections)('%s is server-owned, including against an approved Admin client', async (name) => {
  for (const uid of ['admin', 'operator', null]) {
    const db = (uid == null ? env.unauthenticatedContext() : env.authenticatedContext(uid)).firestore();
    const ref = doc(db, name, 'existing');
    await assertFails(getDoc(ref));
    await assertFails(getDocs(collection(db, name)));
    await assertFails(setDoc(doc(db, name, 'new'), {schemaVersion: 1}));
    await assertFails(updateDoc(ref, {serverEvidence: false}));
    await assertFails(deleteDoc(ref));
  }
  await env.withSecurityRulesDisabled(async (context) => {
    const snapshot = await assertSucceeds(getDoc(doc(context.firestore(), name, 'existing')));
    expect(snapshot.data()).toEqual({schemaVersion: 1, serverEvidence: true});
  });
});
