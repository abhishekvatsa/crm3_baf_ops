const admin = require('firebase-admin');

const {
  completePlannedJobWithDb,
} = require('../lib/plannedJobClosure');
const {
  mutateRuntimeJobModulePopulationWithDb,
} = require('../lib/runtimeJobModulePopulation');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `population-fence-${process.pid}-${Date.now()}`;

function runtimeModule(executionId, moduleId = 'runtime_new', overrides = {}) {
  const now = '2026-06-24T00:00:00.000Z';
  return {
    firestoreId: moduleId,
    jobExecutionFirestoreId: executionId,
    templateFirestoreId: 'legacy-template',
    templateName: 'Runtime template',
    templatePackageId: null,
    templateVersionId: null,
    templateModuleId: null,
    moduleCode: 'RUNTIME-01',
    moduleSnapshotJson: '{}',
    fieldDefinitionsJson: '[]',
    assetType: 'base',
    assetNumber: 209,
    chargeNoAtEvent: 240624,
    pairedEquipmentJson: null,
    moduleTitle: 'Runtime closure-critical module',
    moduleDescription: null,
    status: 'notStarted',
    useMode: 'scheduledPM',
    discipline: 'mechanical',
    safetyClass: 'normal',
    isRequired: true,
    requiredForClosure: true,
    addedDuringExecution: true,
    displayOrder: 99,
    functionalSection: 'O-08',
    componentGroup: null,
    subsystem: null,
    targetRef: null,
    targetRefs: [],
    procedureRefs: [],
    safetyConfirmations: [],
    tags: ['o08'],
    operationalStatePreconditions: [],
    responsesJson: '[]',
    actionsJson: '[]',
    draftNote: null,
    submissionNote: null,
    acceptanceNote: null,
    reopenReason: null,
    notApplicableReason: null,
    pendingIssue: null,
    requiresFollowUp: false,
    addedByUid: 'supervisor1',
    addedByName: 'Shift Supervisor',
    addedAt: now,
    addReason: 'Observed during execution',
    createdByUid: 'supervisor1',
    createdByName: 'Shift Supervisor',
    createdAt: now,
    updatedByUid: 'supervisor1',
    updatedByName: 'Shift Supervisor',
    updatedAt: now,
    submittedByUid: null,
    submittedByName: null,
    submittedAt: null,
    acceptedByUid: null,
    acceptedByName: null,
    acceptedAt: null,
    reopenedByUid: null,
    reopenedByName: null,
    reopenedAt: null,
    notApplicableByUid: null,
    notApplicableByName: null,
    notApplicableAt: null,
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    version: 1,
    metadataJson: null,
    ...overrides,
  };
}

function acceptedModule(executionId, moduleId = `accepted_${executionId}`) {
  const now = '2026-06-24T00:00:00.000Z';
  return runtimeModule(executionId, moduleId, {
    moduleTitle: 'Already accepted module',
    status: 'accepted',
    version: 2,
    addedDuringExecution: false,
    submittedByUid: 'supervisor1',
    submittedByName: 'Shift Supervisor',
    submittedAt: now,
    acceptedByUid: 'supervisor1',
    acceptedByName: 'Shift Supervisor',
    acceptedAt: now,
  });
}

function tombstone(module) {
  return {
    ...module,
    isDeleted: true,
    deletedByUid: 'supervisor1',
    deletedByName: 'Shift Supervisor',
    deletedAt: '2026-06-24T12:00:00.000Z',
    deleteReason: 'Race proof delete',
    updatedByUid: 'supervisor1',
    updatedByName: 'Shift Supervisor',
    updatedAt: '2026-06-24T12:00:00.000Z',
    version: module.version + 1,
  };
}

describeWithEmulator('O-08 complete parent/child population fence', () => {
  let app;
  let db;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  async function seed(executionId) {
    await db.collection('users').doc('supervisor1').set({
      isApproved: true,
      roles: ['shiftSupervisor'],
      name: 'Shift Supervisor',
    });
    await db.collection('job_executions').doc(executionId).set({
      firestoreId: executionId,
      assetType: 'base',
      assetNumber: 209,
      chargeNoAtEvent: 240624,
      isDeleted: false,
      isCompleted: false,
      version: 6,
      modulePopulationVersion: 0,
      modulePopulationSchemaVersion: 1,
      metadataJson: '{}',
      createdAt: '2026-06-24T00:00:00.000Z',
      updatedAt: '2026-06-24T00:00:00.000Z',
    });
    const accepted = acceptedModule(executionId);
    await db.collection('job_modules').doc(accepted.firestoreId).set(accepted);
    return accepted;
  }

  async function state(executionId) {
    const execution = await db.collection('job_executions').doc(executionId).get();
    const modules = await db.collection('job_modules')
      .where('jobExecutionFirestoreId', '==', executionId)
      .get();
    const audits = await db.collection('audit_logs')
      .where('entityType', '==', 'planned_job_module')
      .get();
    return {
      execution: execution.data(),
      modules: modules.docs.map((doc) => ({id: doc.id, ...doc.data()}))
        .sort((a, b) => a.id.localeCompare(b.id)),
      audits: audits.docs.map((doc) => ({id: doc.id, ...doc.data()}))
        .sort((a, b) => a.id.localeCompare(b.id)),
    };
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = app.firestore();
    db.settings({ignoreUndefinedProperties: true});
  });

  beforeEach(clearFirestore);

  afterAll(async () => {
    await db.terminate();
    await app.delete();
  });

  test('create-first ordering rejects closure after the newly-open required module', async () => {
    const executionId = 'ordering_create_first';
    await seed(executionId);

    const mutation = await mutateRuntimeJobModulePopulationWithDb({
      db,
      authUid: 'supervisor1',
      data: {operation: 'create', module: runtimeModule(executionId)},
      now: () => new Date('2026-06-24T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    expect(mutation.currentParentPopulationVersion).toBe(1);

    await expect(
      completePlannedJobWithDb({
        db,
        authUid: 'supervisor1',
        data: {executionId, expectedCompletionVersion: 7},
        timestampFromDate: admin.firestore.Timestamp.fromDate,
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        issues: expect.arrayContaining([
          expect.objectContaining({type: 'openRequiredModule'}),
        ]),
      },
    });

    const after = await state(executionId);
    expect(after.execution).toMatchObject({
      isCompleted: false,
      modulePopulationVersion: 1,
    });
    expect(after.modules.some((module) => module.id === 'runtime_new')).toBe(true);
    expect(after.audits.some((audit) => audit.action === 'create')).toBe(true);
  });

  test('closure-first ordering rejects a later create', async () => {
    const executionId = 'ordering_closure_first_create';
    await seed(executionId);

    const closure = await completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId, expectedCompletionVersion: 7},
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    expect(closure).toMatchObject({ok: true, alreadyCompleted: false});

    await expect(
      mutateRuntimeJobModulePopulationWithDb({
        db,
        authUid: 'supervisor1',
        data: {operation: 'create', module: runtimeModule(executionId)},
        now: () => new Date('2026-06-24T12:00:00.000Z'),
        timestampFromDate: admin.firestore.Timestamp.fromDate,
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'parent-execution-completed'},
    });

    const after = await state(executionId);
    expect(after.execution).toMatchObject({
      isCompleted: true,
      modulePopulationVersion: 0,
    });
    expect(after.modules.some((module) => module.id === 'runtime_new')).toBe(false);
  });

  test('soft-delete-first ordering allows closure and binds schema-2 revision', async () => {
    const executionId = 'ordering_delete_first';
    const accepted = await seed(executionId);

    const deletion = await mutateRuntimeJobModulePopulationWithDb({
      db,
      authUid: 'supervisor1',
      data: {operation: 'softDelete', module: tombstone(accepted)},
      now: () => new Date('2026-06-24T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    expect(deletion.currentParentPopulationVersion).toBe(1);

    const closure = await completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId, expectedCompletionVersion: 7},
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    expect(closure).toMatchObject({ok: true, alreadyCompleted: false});

    const after = await state(executionId);
    const metadata = JSON.parse(after.execution.metadataJson);

    expect(after.execution).toMatchObject({
      isCompleted: true,
      modulePopulationVersion: 1,
    });
    expect(metadata.closureAttestation.schemaVersion).toBe(2);
    const canonicalAttestation = JSON.parse(
      metadata.closureAttestation.canonicalJson,
    );
    expect(canonicalAttestation).toMatchObject({
      modulePopulationVersionAtCompletion: 1,
      modulePopulationSchemaVersionAtCompletion: 1,
    });
    expect(
      after.modules.find((module) => module.id === accepted.firestoreId),
    ).toMatchObject({isDeleted: true});
    expect(after.audits.some((audit) => audit.action === 'delete')).toBe(true);
  });

  test('closure-first ordering rejects a later soft delete', async () => {
    const executionId = 'ordering_closure_first_delete';
    const accepted = await seed(executionId);

    const closure = await completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId, expectedCompletionVersion: 7},
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    expect(closure).toMatchObject({ok: true, alreadyCompleted: false});

    await expect(
      mutateRuntimeJobModulePopulationWithDb({
        db,
        authUid: 'supervisor1',
        data: {operation: 'softDelete', module: tombstone(accepted)},
        now: () => new Date('2026-06-24T12:00:00.000Z'),
        timestampFromDate: admin.firestore.Timestamp.fromDate,
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'parent-execution-completed'},
    });

    const after = await state(executionId);
    expect(after.execution).toMatchObject({
      isCompleted: true,
      modulePopulationVersion: 0,
    });
    expect(
      after.modules.find((module) => module.id === accepted.firestoreId),
    ).toMatchObject({isDeleted: false});
  });

  test('unpaused concurrent create and closure serialize to one authoritative winner', async () => {
    const executionId = 'concurrent_create_and_close';
    await seed(executionId);

    const mutationPromise = mutateRuntimeJobModulePopulationWithDb({
      db,
      authUid: 'supervisor1',
      data: {operation: 'create', module: runtimeModule(executionId)},
      now: () => new Date('2026-06-24T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    const closurePromise = completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId, expectedCompletionVersion: 7},
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    const [mutationResult, closureResult] = await Promise.allSettled([
      mutationPromise,
      closurePromise,
    ]);

    const after = await state(executionId);

    if (mutationResult.status === 'fulfilled') {
      expect(mutationResult.value.currentParentPopulationVersion).toBe(1);
      expect(closureResult.status).toBe('rejected');
      expect(closureResult.reason).toMatchObject({
        code: 'failed-precondition',
        details: {
          issues: expect.arrayContaining([
            expect.objectContaining({type: 'openRequiredModule'}),
          ]),
        },
      });
      expect(after.execution).toMatchObject({
        isCompleted: false,
        modulePopulationVersion: 1,
      });
      expect(after.modules.some((module) => module.id === 'runtime_new')).toBe(true);
    } else {
      expect(closureResult.status).toBe('fulfilled');
      expect(closureResult.value).toMatchObject({
        ok: true,
        alreadyCompleted: false,
      });
      expect(mutationResult.reason).toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'parent-execution-completed'},
      });
      expect(after.execution).toMatchObject({
        isCompleted: true,
        modulePopulationVersion: 0,
      });
      expect(after.modules.some((module) => module.id === 'runtime_new')).toBe(false);
    }
  });

  test('unpaused concurrent soft delete and closure preserve one coherent final population', async () => {
    const executionId = 'concurrent_delete_and_close';
    const accepted = await seed(executionId);

    const deletionPromise = mutateRuntimeJobModulePopulationWithDb({
      db,
      authUid: 'supervisor1',
      data: {operation: 'softDelete', module: tombstone(accepted)},
      now: () => new Date('2026-06-24T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    const closurePromise = completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId, expectedCompletionVersion: 7},
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });

    const [deletionResult, closureResult] = await Promise.allSettled([
      deletionPromise,
      closurePromise,
    ]);

    expect(closureResult.status).toBe('fulfilled');
    expect(closureResult.value).toMatchObject({
      ok: true,
      alreadyCompleted: false,
    });

    const after = await state(executionId);
    const metadata = JSON.parse(after.execution.metadataJson);
    expect(metadata.closureAttestation.schemaVersion).toBe(2);
    const canonicalAttestation = JSON.parse(
      metadata.closureAttestation.canonicalJson,
    );

    if (deletionResult.status === 'fulfilled') {
      expect(deletionResult.value.currentParentPopulationVersion).toBe(1);
      expect(after.execution).toMatchObject({
        isCompleted: true,
        modulePopulationVersion: 1,
      });
      expect(
        canonicalAttestation.modulePopulationVersionAtCompletion,
      ).toBe(1);
      expect(
        after.modules.find((module) => module.id === accepted.firestoreId),
      ).toMatchObject({isDeleted: true});
    } else {
      expect(deletionResult.reason).toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'parent-execution-completed'},
      });
      expect(after.execution).toMatchObject({
        isCompleted: true,
        modulePopulationVersion: 0,
      });
      expect(
        canonicalAttestation.modulePopulationVersionAtCompletion,
      ).toBe(0);
      expect(
        after.modules.find((module) => module.id === accepted.firestoreId),
      ).toMatchObject({isDeleted: false});
    }
  });
});
