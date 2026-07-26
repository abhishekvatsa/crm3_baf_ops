/**
 * S-09 adjudication witnesses: maintenance-workflow authority and replay.
 *
 * These tests assert the INTENDED post-remediation behaviour. Against
 * unmodified `main` they are expected to FAIL, and each failure is the
 * executable proof of one defect:
 *
 *   W1  actor authority is captured outside the business transaction and is
 *       never re-read, so revocation cannot stop the mutation.
 *   W2  the same defect expressed as a real race: revocation lands while the
 *       command is in flight and the transaction still commits.
 *   W3  command receipts are not owner-bound, so any approved user who learns
 *       a commandId can obtain another actor's receipt.
 *   W4  receipt replay returns before command-specific authorisation, so an
 *       actor who has lost the required role can still replay it.
 *
 * No production source change is required to run these. The defect is reached
 * through the existing `MaintenanceWorkflowCommandService(store)` seam.
 *
 * Probe command: `deployEquipment`. Its authority check
 * (equipmentHandlers.ts) is a payload-independent role test, so the witnesses
 * isolate authority from business state.
 */
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
const appName = `workflow-s09-${process.pid}-${Date.now()}`;

// deployEquipment: ["admin","si","operations","shiftSupervisor"]
const DEPLOY_ROLE = 'operations';
const NON_DEPLOY_ROLE = 'refractory';

function deferred() {
  let resolve;
  const promise = new Promise((r) => {
    resolve = r;
  });
  return {promise, resolve};
}

/**
 * Wraps the real store so a test can suspend execution in the window between
 * actor capture and transaction start. Requires no production change: the
 * service already accepts any WorkflowStore.
 */
class PausingWorkflowStore {
  constructor(inner, beforeTransaction) {
    this.inner = inner;
    this.beforeTransaction = beforeTransaction;
  }

  async runTransaction(work) {
    await this.beforeTransaction();
    return this.inner.runTransaction(work);
  }
}

function actorFor(uid, roles) {
  return {uid, name: uid, roles: new Set(roles)};
}

function deployCommand(commandId, assetNumber, expectedVersion) {
  return {
    commandId,
    commandType: 'deployEquipment',
    aggregateId: `base_${assetNumber}`,
    expectedVersion,
    payload: {assetTypeKey: 'base', assetNumber},
  };
}

describeWithEmulator('S-09 workflow authority and replay adjudication', () => {
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

  async function seedUser(uid, roles) {
    await db.collection('users').doc(uid).set({
      name: uid,
      email: `${uid}@example.test`,
      isApproved: true,
      roles,
      createdAt: new Date().toISOString(),
    });
  }

  async function revokeUser(uid) {
    await db.collection('users').doc(uid).update({isApproved: false, roles: []});
  }

  async function seedEquipment(assetNumber, version) {
    await db.collection('equipment_status').doc(`base_${assetNumber}`).set({
      assetTypeKey: 'base',
      assetNumber,
      state: 'available',
      version,
      updatedAt: new Date().toISOString(),
    });
  }

  async function equipmentState(assetNumber) {
    const snap = await db
      .collection('equipment_status')
      .doc(`base_${assetNumber}`)
      .get();
    return snap.exists ? snap.data() : null;
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

  // ── W1 ──────────────────────────────────────────────────────────────────
  test('W1: revoked actor cannot commit using authority captured before the transaction', async () => {
    const uid = 's09_revoked_actor';
    await seedUser(uid, [DEPLOY_ROLE]);
    await seedEquipment(201, 3);

    // Authority captured while still approved — exactly what callable.ts does
    // before it hands the resolved Actor to the service.
    const captured = actorFor(uid, [DEPLOY_ROLE]);

    // Authority is withdrawn before the command is dispatched.
    await revokeUser(uid);

    const before = await equipmentState(201);

    await expect(
      service.execute(deployCommand('s09-w1', 201, 3), {
        actor: captured,
        serverNow: new Date(),
      }),
    ).rejects.toMatchObject({code: 'permission-denied'});

    // No business mutation may survive a denied command.
    expect(await equipmentState(201)).toEqual(before);
  });

  // ── W2 ──────────────────────────────────────────────────────────────────
  test('W2: revocation during the in-flight window fails closed', async () => {
    const uid = 's09_race_actor';
    await seedUser(uid, [DEPLOY_ROLE]);
    await seedEquipment(202, 4);

    const reachedTransaction = deferred();
    const mayProceed = deferred();

    const racingService = new MaintenanceWorkflowCommandService(
      new PausingWorkflowStore(new FirebaseWorkflowStore(db), async () => {
        reachedTransaction.resolve();
        await mayProceed.promise;
      }),
    );

    const before = await equipmentState(202);
    const inFlight = racingService.execute(deployCommand('s09-w2', 202, 4), {
      actor: actorFor(uid, [DEPLOY_ROLE]),
      serverNow: new Date(),
    });

    await reachedTransaction.promise;
    await revokeUser(uid);
    mayProceed.resolve();

    await expect(inFlight).rejects.toMatchObject({code: 'permission-denied'});
    expect(await equipmentState(202)).toEqual(before);
  });

  // ── W3 ──────────────────────────────────────────────────────────────────
  test('W3: an approved non-owner cannot obtain another actor owner\'s receipt', async () => {
    const owner = 's09_owner';
    const stranger = 's09_stranger';
    await seedUser(owner, [DEPLOY_ROLE]);
    await seedUser(stranger, [DEPLOY_ROLE]);
    await seedEquipment(203, 5);

    const command = deployCommand('s09-w3', 203, 5);
    const ownerReceipt = await service.execute(command, {
      actor: actorFor(owner, [DEPLOY_ROLE]),
      serverNow: new Date(),
    });
    expect(ownerReceipt.resultKey).toBe('equipment-deployed');

    // commandId is discoverable: maintenance_workflow_events is readable by
    // every approved user (firestore.rules) and each event carries commandId.
    await expect(
      service.execute(command, {
        actor: actorFor(stranger, [DEPLOY_ROLE]),
        serverNow: new Date(),
      }),
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  // ── W4 ──────────────────────────────────────────────────────────────────
  test('W4: replay is refused after the required role is withdrawn', async () => {
    const uid = 's09_narrowed_actor';
    await seedUser(uid, [DEPLOY_ROLE]);
    await seedEquipment(204, 6);

    const command = deployCommand('s09-w4', 204, 6);
    const receipt = await service.execute(command, {
      actor: actorFor(uid, [DEPLOY_ROLE]),
      serverNow: new Date(),
    });
    expect(receipt.resultKey).toBe('equipment-deployed');

    // Role narrowed: still approved, but no longer permitted to deploy.
    await db.collection('users').doc(uid).update({roles: [NON_DEPLOY_ROLE]});

    await expect(
      service.execute(command, {
        actor: actorFor(uid, [NON_DEPLOY_ROLE]),
        serverNow: new Date(),
      }),
    ).rejects.toMatchObject({code: 'permission-denied'});
  });
});
