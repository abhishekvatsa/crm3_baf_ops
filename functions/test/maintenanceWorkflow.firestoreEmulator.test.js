const admin = require('firebase-admin');

const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  FirebaseWorkflowStore,
} = require('../lib/maintenanceWorkflow/firebaseStore');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `workflow-emulator-${process.pid}-${Date.now()}`;

const actor = {
  uid: 'admin1',
  name: 'Admin',
  roles: new Set(['admin']),
};

function createCommand(id) {
  return {
    commandId: `create-${id}`,
    commandType: 'createLegacyWorkflowJob',
    aggregateId: id,
    expectedVersion: 0,
    payload: {
      executionId: id,
      templateFirestoreId: 'legacy-template',
      templateName: 'Legacy PM',
      assetTypeKey: 'base',
      assetNumber: 101,
      assignedAgencies: ['mechanical'],
    },
  };
}

describeWithEmulator('maintenance workflow Firestore serialization', () => {
  let app;
  let db;
  let service;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = app.firestore();
    db.settings({ignoreUndefinedProperties: true});
    service = new MaintenanceWorkflowCommandService(
      new FirebaseWorkflowStore(db),
    );
  });

  beforeEach(clearFirestore);

  afterAll(async () => {
    await db.terminate();
    await app.delete();
  });

  test('concurrent same-equipment creates preserve both workflow contributions', async () => {
    await Promise.all([
      service.execute(
        createCommand('workflow-a'),
        {actor, serverNow: new Date('2026-07-25T12:00:00.000Z')},
      ),
      service.execute(
        createCommand('workflow-b'),
        {actor, serverNow: new Date('2026-07-25T12:00:01.000Z')},
      ),
    ]);

    const workflows = await db.collection('maintenance_workflows').get();
    const equipment = await db.collection('equipment_status').doc('base_101').get();

    expect(workflows.size).toBe(2);
    expect(equipment.data()).toMatchObject({
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });
  });
});
