const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {FirebaseWorkflowStore, workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
const memory = require('../../test/fixtures/workflow_module_reopen_actual_handler.json');
const destination = path.resolve(__dirname, '../../test/fixtures/workflow_module_reopen_firestore_handler.json');
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || '';
const describeLocal = emulatorHost ? describe : describe.skip;
const json = value => JSON.parse(JSON.stringify(value));
jest.setTimeout(60000);

describeLocal('real Firestore module reopen producer for Dart and Rules consumers', () => {
  let app, db;
  beforeAll(async () => {
    if (!projectId.startsWith('demo-') || !/^127\.0\.0\.1:\d+$/.test(emulatorHost)) {
      throw new Error('A loopback Firestore emulator with an isolated demo project is required.');
    }
    app = admin.initializeApp({projectId}, `reopen-producer-${process.pid}`); db = app.firestore();
  });
  afterAll(async () => { await app?.delete(); });
  test('native Timestamp audit and its exact embedded JSON come from the actual transaction adapter', async () => {
    const response = await fetch(`http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error(`Local fixture reset failed: ${response.status}`);
    const seed = async (where, data) => db.doc(where).set(workflowFirestoreDataForTest(data));
    await seed('users/admin-1', {isApproved: true, roles: ['admin'], name: memory.actor.name});
    await seed('maintenance_workflows/job-7', {jobExecutionId: 'job-7', status: 'readyForClosure', version: 10,
      assetTypeKey: 'base', assetNumber: 107, laneSetFinalizedAt: '2026-09-12T00:00:00.000Z', cancelled: false});
    await seed('job_executions/job-7', {version: 2, workflowSchemaVersion: 1, isCompleted: false, isCancelled: false});
    await seed('job_lanes/job-7__mech', {workflowId: 'job-7', jobExecutionId: 'job-7', laneKey: 'mech', status: 'closed',
      activationGeneration: 1, version: 3, progressRevision: 1});
    await seed('job_modules/module-7', {...memory.beforeModule,
      createdAt: new admin.firestore.Timestamp(admin.firestore.Timestamp.fromDate(new Date(memory.beforeModule.createdAt)).seconds, 123456000),
      updatedAt: new admin.firestore.Timestamp(admin.firestore.Timestamp.fromDate(new Date(memory.beforeModule.updatedAt)).seconds, 654321000)});
    const beforeModule = (await db.doc('job_modules/module-7').get()).data();
    expect(beforeModule.createdAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(beforeModule.updatedAt).toBeInstanceOf(admin.firestore.Timestamp);
    const receipt = await new MaintenanceWorkflowCommandService(new FirebaseWorkflowStore(db)).execute(memory.command,
      {actor: memory.actor, serverNow: new Date(memory.receipt.appliedAt)});
    const audit = (await db.doc('audit_logs/workflow_module_reopen_module-7_11').get()).data();
    const module = (await db.doc('job_modules/module-7').get()).data();
    expect(receipt).toEqual(memory.receipt);
    expect(audit.timestamp).toBeInstanceOf(admin.firestore.Timestamp);
    expect(audit.timestamp.toDate().toISOString()).toBe(receipt.appliedAt);
    expect(module.reopenedAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(JSON.parse(audit.beforeJson)).toEqual(json(beforeModule));
    expect(JSON.parse(audit.beforeJson).createdAt).toEqual(json(beforeModule.createdAt));
    expect(JSON.parse(audit.afterJson)).toEqual({...json(beforeModule), status: 'reopened', isOpenForWork: true});
    const produced = json({provenance: {
      producer: 'MaintenanceWorkflowCommandService.execute -> reopenWorkflowModule -> FirebaseWorkflowStore; loopback Firestore emulator',
      timestampEvidence: 'Outer native Timestamp values use their actual Admin SDK toJSON representation; audit beforeJson/afterJson strings are retained exactly as stored.',
      nativeSeedPrecision: 'createdAt uses nanoseconds123456000 and updatedAt654321000, both representable as exact Dart microseconds.',
      handlerNormalizedLfSha256: memory.provenance.handlerNormalizedLfSha256,
    }, actor: memory.actor, command: memory.command, receipt, beforeModule, audit, module});
    if (process.env.GENERATE_WORKFLOW_REOPEN_FIRESTORE_FIXTURE === '1') {
      fs.writeFileSync(destination, `${JSON.stringify(produced, null, 2)}\n`);
    } else {
      const expected = JSON.parse(fs.readFileSync(destination, 'utf8'));
      // Firestore map ordering is not a protocol guarantee. Preserve captured
      // strings in the fixture, but compare their actual JSON values here.
      const semantic = data => ({...data, audit: {...data.audit,
        beforeJson: JSON.parse(data.audit.beforeJson), afterJson: JSON.parse(data.audit.afterJson)}});
      expect(semantic(produced)).toEqual(semantic(expected));
    }
  });
});
