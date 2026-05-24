const fs = require('fs');
const path = require('path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  setDoc,
  updateDoc,
  setLogLevel,
} = require('firebase/firestore');

const PROJECT_ID = 'crm3-baf-ops-b8638';
let testEnv;

function userDoc(roles, isApproved = true) {
  return {
    name: 'Rules Test User',
    email: 'rules-test@example.invalid',
    roles,
    isApproved,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };
}

function userDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function baseModule(overrides = {}) {
  const now = '2026-01-01T00:00:00.000Z';
  const id = overrides.firestoreId || 'module_mech_1';

  return {
    firestoreId: id,
    jobExecutionFirestoreId: 'job_1',
    jobExecutionLocalId: null,
    templateFirestoreId: 'legacy_template_1',
    templateName: 'Test template',
    templatePackageId: 'pkg_1',
    templateVersionId: 'tv_1',
    templateModuleId: 'tm_1',
    moduleCode: 'M-01',
    moduleSnapshotJson: '{}',
    fieldDefinitionsJson: '[]',
    assetType: 'base',
    assetNumber: 1,
    chargeNoAtEvent: null,
    pairedEquipmentJson: null,
    moduleTitle: 'Inspect base fan',
    moduleDescription: null,
    status: 'notStarted',
    useMode: 'scheduledPM',
    discipline: 'mechanical',
    safetyClass: 'normal',
    isRequired: false,
    requiredForClosure: false,
    addedDuringExecution: false,
    displayOrder: 10,
    functionalSection: null,
    componentGroup: null,
    subsystem: null,
    targetRef: null,
    targetRefs: [],
    procedureRefs: [],
    safetyConfirmations: [],
    tags: [],
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
    addedByUid: null,
    addedByName: null,
    addedAt: null,
    addReason: null,
    createdByUid: 'admin',
    createdByName: 'Admin',
    createdAt: now,
    updatedByUid: 'admin',
    updatedByName: 'Admin',
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

async function seedCommonData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/admin'), userDoc(['admin']));
    await setDoc(doc(db, 'users/si'), userDoc(['si']));
    await setDoc(doc(db, 'users/supervisor'), userDoc(['shiftSupervisor']));
    await setDoc(doc(db, 'users/senior_mech'), userDoc(['seniorMechanical']));
    await setDoc(doc(db, 'users/operations'), userDoc(['operations']));

    await setDoc(
      doc(db, 'job_modules/module_mech_1'),
      baseModule({ firestoreId: 'module_mech_1' }),
    );
    await setDoc(
      doc(db, 'job_modules/module_submitted_1'),
      baseModule({
        firestoreId: 'module_submitted_1',
        status: 'submitted',
        submittedByUid: 'senior_mech',
        submittedByName: 'Senior Mechanical',
        submittedAt: '2026-01-01T01:00:00.000Z',
        submissionNote: 'Submitted for review',
      }),
    );
    await setDoc(
      doc(db, 'job_modules/module_accepted_1'),
      baseModule({
        firestoreId: 'module_accepted_1',
        status: 'accepted',
        submittedByUid: 'senior_mech',
        submittedByName: 'Senior Mechanical',
        submittedAt: '2026-01-01T01:00:00.000Z',
        acceptedByUid: 'supervisor',
        acceptedByName: 'Shift Supervisor',
        acceptedAt: '2026-01-01T02:00:00.000Z',
      }),
    );
  });
}

beforeAll(async () => {
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedCommonData();
});

afterAll(async () => {
  await testEnv.cleanup();
  setLogLevel('warn');
});

describe('job_modules update transition rules', () => {
  test('allows senior discipline user to save work fields on an open module', async () => {
    const db = userDb('senior_mech');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'inProgress',
        responsesJson: '[{"fieldId":"f1","value":"ok"}]',
        actionsJson: '[]',
        draftNote: 'Checked locally',
        pendingIssue: 'Monitor vibration',
        requiresFollowUp: true,
        updatedByUid: 'senior_mech',
        updatedByName: 'Senior Mechanical',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });


  test('rejects job module updates that try to write legacy responses array', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'inProgress',
        responses: [{ fieldId: 'f1', value: 'legacy duplicate' }],
        responsesJson: '[{"fieldId":"f1","value":"ok"}]',
        updatedByUid: 'senior_mech',
        updatedByName: 'Senior Mechanical',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('rejects work update that also mutates accept lifecycle fields', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'inProgress',
        acceptedByUid: 'senior_mech',
        updatedByUid: 'senior_mech',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('allows offline combined save-work-and-submit for matching senior discipline', async () => {
    const db = userDb('senior_mech');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'submitted',
        responsesJson: '[{"fieldId":"f1","value":"done"}]',
        actionsJson: '[]',
        pendingIssue: null,
        requiresFollowUp: false,
        submittedByUid: 'senior_mech',
        submittedByName: 'Senior Mechanical',
        submittedAt: '2026-01-01T03:00:00.000Z',
        submissionNote: 'Ready for review',
        updatedByUid: 'senior_mech',
        updatedByName: 'Senior Mechanical',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });


  test('allows FirestoreJobModuleRepository-style remote submit payload without local-only isSynced', async () => {
    const db = userDb('senior_mech');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'submitted',
        submittedByUid: 'senior_mech',
        submittedByName: 'Senior Mechanical',
        submittedAt: '2026-01-01T03:00:00.000Z',
        submissionNote: 'Submitted from direct remote repository',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('rejects FirestoreJobModuleRepository-style remote submit payload with local-only isSynced', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'submitted',
        submittedByUid: 'senior_mech',
        submittedByName: 'Senior Mechanical',
        submittedAt: '2026-01-01T03:00:00.000Z',
        submissionNote: 'Submitted from direct remote repository',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
        isSynced: true,
      }),
    );
  });

  test('allows full toMap-style merged submit push without local-only flags', async () => {
    const db = userDb('senior_mech');
    await assertSucceeds(
      setDoc(
        doc(db, 'job_modules/module_mech_1'),
        baseModule({
          firestoreId: 'module_mech_1',
          status: 'submitted',
          responsesJson: '[{"fieldId":"f1","value":"done"}]',
          actionsJson: '[]',
          pendingIssue: null,
          requiresFollowUp: false,
          submittedByUid: 'senior_mech',
          submittedByName: 'Senior Mechanical',
          submittedAt: '2026-01-01T03:00:00.000Z',
          submissionNote: 'Full merged sync push',
          updatedByUid: 'senior_mech',
          updatedByName: 'Senior Mechanical',
          updatedAt: '2026-01-01T03:00:00.000Z',
          version: 2,
        }),
        { merge: true },
      ),
    );
  });

  test('rejects full toMap-style merged submit push with local-only isSynced', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      setDoc(
        doc(db, 'job_modules/module_mech_1'),
        {
          ...baseModule({
            firestoreId: 'module_mech_1',
            status: 'submitted',
            submittedByUid: 'senior_mech',
            submittedByName: 'Senior Mechanical',
            submittedAt: '2026-01-01T03:00:00.000Z',
            updatedByUid: 'senior_mech',
            updatedByName: 'Senior Mechanical',
            updatedAt: '2026-01-01T03:00:00.000Z',
            version: 2,
          }),
          isSynced: true,
        },
        { merge: true },
      ),
    );
  });

  test('rejects submit that also mutates accept lifecycle fields', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'submitted',
        submittedByUid: 'senior_mech',
        submittedAt: '2026-01-01T03:00:00.000Z',
        acceptedByUid: 'senior_mech',
        updatedByUid: 'senior_mech',
        updatedAt: '2026-01-01T03:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('allows supervisor to accept a submitted module', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_submitted_1'), {
        status: 'accepted',
        acceptedByUid: 'supervisor',
        acceptedByName: 'Shift Supervisor',
        acceptedAt: '2026-01-01T04:00:00.000Z',
        acceptanceNote: 'Accepted',
        updatedByUid: 'supervisor',
        updatedByName: 'Shift Supervisor',
        updatedAt: '2026-01-01T04:00:00.000Z',
        version: 2,
      }),
    );
  });


  test('allows FirestoreJobModuleRepository-style remote accept payload without local-only isSynced', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_submitted_1'), {
        status: 'accepted',
        acceptedByUid: 'supervisor',
        acceptedByName: 'Shift Supervisor',
        acceptedAt: '2026-01-01T04:00:00.000Z',
        acceptanceNote: 'Accepted from direct remote repository',
        updatedAt: '2026-01-01T04:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('rejects FirestoreJobModuleRepository-style remote accept payload with local-only isSynced', async () => {
    const db = userDb('supervisor');
    await assertFails(
      updateDoc(doc(db, 'job_modules/module_submitted_1'), {
        status: 'accepted',
        acceptedByUid: 'supervisor',
        acceptedByName: 'Shift Supervisor',
        acceptedAt: '2026-01-01T04:00:00.000Z',
        acceptanceNote: 'Accepted from direct remote repository',
        updatedAt: '2026-01-01T04:00:00.000Z',
        version: 2,
        isSynced: true,
      }),
    );
  });

  test('allows supervisor to reopen an accepted module', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_accepted_1'), {
        status: 'reopened',
        reopenedByUid: 'supervisor',
        reopenedByName: 'Shift Supervisor',
        reopenedAt: '2026-01-01T05:00:00.000Z',
        reopenReason: 'Need photo evidence',
        updatedByUid: 'supervisor',
        updatedByName: 'Shift Supervisor',
        updatedAt: '2026-01-01T05:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('allows supervisor to mark an open module not applicable', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        status: 'notApplicable',
        notApplicableByUid: 'supervisor',
        notApplicableByName: 'Shift Supervisor',
        notApplicableAt: '2026-01-01T06:00:00.000Z',
        notApplicableReason: 'Equipment not in scope',
        updatedByUid: 'supervisor',
        updatedByName: 'Shift Supervisor',
        updatedAt: '2026-01-01T06:00:00.000Z',
        version: 2,
      }),
    );
  });

  test('allows supervisor to soft-delete a module', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      updateDoc(doc(db, 'job_modules/module_mech_1'), {
        isDeleted: true,
        deletedByUid: 'supervisor',
        deletedByName: 'Shift Supervisor',
        deletedAt: '2026-01-01T07:00:00.000Z',
        deleteReason: 'Duplicate module',
        updatedByUid: 'supervisor',
        updatedByName: 'Shift Supervisor',
        updatedAt: '2026-01-01T07:00:00.000Z',
        version: 2,
      }),
    );
  });
});

describe('job_modules elevated runtime module create rules', () => {
  test('rejects senior discipline direct create of closure-critical runtime module', async () => {
    const db = userDb('senior_mech');
    await assertFails(
      setDoc(
        doc(db, 'job_modules/elevated_by_senior'),
        baseModule({
          firestoreId: 'elevated_by_senior',
          requiredForClosure: true,
          addedDuringExecution: true,
          createdByUid: 'senior_mech',
          updatedByUid: 'senior_mech',
        }),
      ),
    );
  });

  test('allows supervisor create of closure-critical runtime module', async () => {
    const db = userDb('supervisor');
    await assertSucceeds(
      setDoc(
        doc(db, 'job_modules/elevated_by_supervisor'),
        baseModule({
          firestoreId: 'elevated_by_supervisor',
          requiredForClosure: true,
          addedDuringExecution: true,
          createdByUid: 'supervisor',
          updatedByUid: 'supervisor',
        }),
      ),
    );
  });


  test('rejects runtime module create that writes legacy responses array', async () => {
    const db = userDb('supervisor');
    await assertFails(
      setDoc(
        doc(db, 'job_modules/create_with_legacy_responses'),
        baseModule({
          firestoreId: 'create_with_legacy_responses',
          addedDuringExecution: true,
          createdByUid: 'supervisor',
          updatedByUid: 'supervisor',
          responses: [{ fieldId: 'f1', value: 'legacy duplicate' }],
        }),
      ),
    );
  });
});
