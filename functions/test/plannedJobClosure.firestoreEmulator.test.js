const admin = require('firebase-admin');

const {
  completePlannedJobWithDb,
} = require('../lib/plannedJobClosure');

jest.setTimeout(30000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';

const appName = `closure-emulator-${process.pid}-${Date.now()}`;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function deferred() {
  let resolve;
  const promise = new Promise((resolver) => {
    resolve = resolver;
  });
  return {promise, resolve};
}

function baseExecution(executionId, overrides = {}) {
  return {
    firestoreId: executionId,
    assetType: 'base',
    assetNumber: 209,
    isDeleted: false,
    isCompleted: false,
    version: 6,
    modulePopulationVersion: 1,
    modulePopulationSchemaVersion: 1,
    metadataJson: '{}',
    createdAt: '2026-06-21T00:00:00.000Z',
    updatedAt: '2026-06-21T00:00:00.000Z',
    ...overrides,
  };
}

function baseModule(executionId, overrides = {}) {
  return {
    firestoreId: `module_${executionId}`,
    jobExecutionFirestoreId: executionId,
    templateModuleId: 'seed:B-02',
    moduleCode: 'B-02',
    moduleTitle: 'Base Hydraulic Clamping System',
    version: 4,
    status: 'accepted',
    requiredForClosure: true,
    isRequired: true,
    isDeleted: false,
    requiresFollowUp: false,
    pendingIssue: null,
    fieldDefinitionsJson: JSON.stringify([
      {
        key: 'observation',
        type: 'text',
        isRequired: true,
      },
    ]),
    responsesJson: JSON.stringify([
      {
        key: 'observation',
        value: 'verified',
      },
    ]),
    ...overrides,
  };
}

describeWithEmulator(
  'completePlannedJobWithDb with a real Firestore emulator transaction',
  () => {
    let app;
    let db;

    async function clearFirestore() {
      const response = await fetch(
        `http://${emulatorHost}/emulator/v1/projects/` +
          `${projectId}/databases/(default)/documents`,
        {method: 'DELETE'},
      );

      if (!response.ok) {
        throw new Error(
          `Unable to clear Firestore emulator: ` +
            `${response.status} ${await response.text()}`,
        );
      }
    }

    async function seedUser(uid, overrides = {}) {
      await db.collection('users').doc(uid).set({
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Shift Supervisor',
        ...overrides,
      });
    }

    async function seedExecution(executionId, overrides = {}) {
      const data = baseExecution(executionId, overrides);
      await db.collection('job_executions').doc(executionId).set(data);
      return data;
    }

    async function seedModule(executionId, overrides = {}) {
      const data = baseModule(executionId, overrides);
      await db.collection('job_modules').doc(data.firestoreId).set(data);
      return data;
    }

    async function captureState(executionId) {
      const executionSnapshot = await db
        .collection('job_executions')
        .doc(executionId)
        .get();

      const modulesSnapshot = await db
        .collection('job_modules')
        .where('jobExecutionFirestoreId', '==', executionId)
        .get();

      const auditsSnapshot = await db
        .collection('audit_logs')
        .where('entityId', '==', executionId)
        .get();

      return {
        execution: executionSnapshot.exists
          ? clone(executionSnapshot.data())
          : null,
        modules: modulesSnapshot.docs
          .map((doc) => ({
            id: doc.id,
            data: clone(doc.data()),
          }))
          .sort((a, b) => a.id.localeCompare(b.id)),
        audits: auditsSnapshot.docs
          .map((doc) => ({
            id: doc.id,
            data: clone(doc.data()),
          }))
          .sort((a, b) => a.id.localeCompare(b.id)),
      };
    }

    beforeAll(async () => {
      app = admin.initializeApp({projectId}, appName);
      db = app.firestore();
      db.settings({ignoreUndefinedProperties: true});
    });

    beforeEach(async () => {
      await clearFirestore();
    });

    afterAll(async () => {
      await db.terminate();
      await app.delete();
    });

    test(
      'stale version rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_stale_version';
        const uid = 'supervisor_stale';

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 99,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'failed-precondition',
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'open required module rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_open_required';
        const uid = 'supervisor_open';

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId, {status: 'inProgress'});

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 7,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'failed-precondition',
          details: {
            issues: expect.arrayContaining([
              expect.objectContaining({
                type: 'openRequiredModule',
              }),
            ]),
          },
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'unauthorized role rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_unauthorized';
        const uid = 'operations_user';

        await seedUser(uid, {
          roles: ['operations'],
          name: 'Operations User',
        });

        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 7,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'permission-denied',
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'authority revoked before transaction start fails closed with no business mutation',
      async () => {
        const executionId = 'integration_authority_revoked';
        const uid = 'supervisor_revoked';
        const transactionMayStart = deferred();
        const invocationReachedTransaction = deferred();

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);
        const closurePromise = completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
          beforeTransactionForTest: async () => {
            invocationReachedTransaction.resolve();
            await transactionMayStart.promise;
          },
        });

        await invocationReachedTransaction.promise;
        await db.collection('users').doc(uid).update({
          isApproved: false,
          roles: [],
        });
        transactionMayStart.resolve();

        await expect(closurePromise).rejects.toMatchObject({
          code: 'permission-denied',
          details: {reasonCode: 'closure-authority-denied'},
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'successful closure binds attestation to the current module-population version',
      async () => {
        const executionId = 'integration_population_attestation';
        const uid = 'supervisor_population';

        await seedUser(uid);
        await seedExecution(executionId, {
          version: 6,
          modulePopulationVersion: 4,
        });
        await seedModule(executionId);

        const result = await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        });

        expect(result).toMatchObject({
          ok: true,
          alreadyCompleted: false,
          executionId,
          version: 7,
        });

        const after = await captureState(executionId);
        expect(after.execution.isCompleted).toBe(true);
        expect(after.execution.modulePopulationVersion).toBe(4);
        expect(after.execution.modulePopulationSchemaVersion).toBe(1);

        const metadata = JSON.parse(after.execution.metadataJson);
        expect(metadata.closureAttestation.schemaVersion).toBe(2);
        const canonical = JSON.parse(
          metadata.closureAttestation.canonicalJson,
        );
        expect(canonical.modulePopulationVersionAtCompletion).toBe(4);
        expect(after.audits).toHaveLength(1);
      },
    );

    test(
      'already-completed retry returns existing attestation and creates no mutation',
      async () => {
        const executionId = 'integration_idempotent_retry';
        const uid = 'supervisor_retry';
        const existingHash = 'existing_attestation_hash';

        await seedUser(uid);

        await seedExecution(executionId, {
          isCompleted: true,
          version: 7,
          completedAt: '2026-06-21T04:37:12.313Z',
          completedByUid: uid,
          completedByName: 'Shift Supervisor',
          metadataJson: JSON.stringify({
            closureAttestation: {
              schemaVersion: 1,
              hash: existingHash,
              canonicalJson: '{"existing":true}',
            },
          }),
        });

        // Deliberately invalid if evaluated. A correct idempotent path
        // returns before the canonical module query and closure guard.
        await seedModule(executionId, {
          status: 'inProgress',
          responsesJson: '[]',
        });

        const auditId =
          `server_closure_${executionId}_7`;

        await db.collection('audit_logs').doc(auditId).set({
          entityType: 'execution',
          entityId: executionId,
          action: 'resolve',
          timestamp:
            admin.firestore.Timestamp.fromDate(
              new Date('2026-06-21T04:37:12.313Z'),
            ),
          summary: 'existing closure audit',
          marker: 'must remain unchanged',
        });

        const before = await captureState(executionId);

        const result = await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 99,
          },
          timestampFromDate:
            admin.firestore.Timestamp.fromDate,
        });

        expect(result).toMatchObject({
          ok: true,
          alreadyCompleted: true,
          executionId,
          version: 7,
          closureAttestationHash: existingHash,
        });

        const after = await captureState(executionId);

        expect(after).toEqual(before);
        expect(after.audits).toHaveLength(1);
        expect(after.audits[0].id).toBe(auditId);
        expect(after.audits[0].data.marker)
          .toBe('must remain unchanged');
      },
    );
  },
);
