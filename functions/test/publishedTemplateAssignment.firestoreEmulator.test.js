const admin = require('firebase-admin');

const {
  assignPublishedTemplateVersionWithDb,
} = require('../lib/publishedTemplateAssignment');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `assignment-emulator-${process.pid}-${Date.now()}`;
const REQUEST_ID = '11111111-1111-4111-8111-111111111111';
const OTHER_HASH = `tg2-sha256:${'a'.repeat(64)}`;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function versionFixture(overrides = {}) {
  const jobTemplateSnapshotJson =
    '{"jobName":"Base PM","composer":{"closureReviewConfirmed":true,"closureReviewConfirmedByUid":"si1","closureReviewConfirmedByName":"SI User","closureReviewConfirmedAt":"2026-06-19T10:00:00.000Z"},"closureCriticalCount":1}';
  const moduleSnapshotsJson =
    '[{"moduleCode":"M-01","moduleTitle":"Inspect fan","requiredForClosure":true,"discipline":"mechanical"}]';
  const fieldDefinitionsJson =
    '[{"key":"vibration","label":"Vibration","moduleCode":"M-01","type":"number","isRequired":true}]';

  return {
    firestoreId: 'ver1',
    packageFirestoreId: 'pkg1',
    versionNumber: 1,
    versionLabel: 'v1',
    status: 'published',
    contentHash:
      'tg2-sha256:10c47efd30febb9c3938de06ae8ceb5089fa5d73c688041df5fdbc5710554ac9',
    jobTemplateSnapshotJson,
    moduleSnapshotsJson,
    fieldDefinitionsJson,
    checklistJson: '[]',
    closureReviewConfirmed: true,
    closureCriticalModuleCount: 1,
    closureReviewConfirmedByUid: 'si1',
    closureReviewConfirmedByName: 'SI User',
    closureReviewConfirmedAt: '2026-06-19T10:00:00.000Z',
    publishedByUid: 'si1',
    publishedByName: 'SI User',
    publishedAt: '2026-06-19T10:05:00.000Z',
    targetRefs: [],
    deviceTagRefs: [],
    safetyClass: null,
    safetyGatePolicyJson: null,
    procedureRefs: [],
    operationalStatePreconditions: [],
    schemaVersion: 1,
    isDeleted: false,
    ...overrides,
  };
}

function requestFixture(overrides = {}) {
  return {
    requestId: REQUEST_ID,
    packageId: 'pkg1',
    versionId: 'ver1',
    expectedVersionNumber: 1,
    expectedContentHash: versionFixture().contentHash,
    assetType: 'base',
    assetNumber: 101,
    chargeNoAtEvent: 12345,
    remarks: 'Inspect during planned window.',
    ...overrides,
  };
}

function packageFixture(overrides = {}) {
  return {
    firestoreId: 'pkg1',
    packageCode: 'BAF-BASE-PM',
    title: 'Base preventive maintenance',
    disciplineScope: 'mechanical',
    lifecycleStatus: 'active',
    activeVersionFirestoreId: 'ver1',
    latestVersionNumber: 1,
    isDeleted: false,
    ...overrides,
  };
}

function auditFixture(overrides = {}) {
  return {
    firestoreId: 'audit1',
    packageFirestoreId: 'pkg1',
    versionFirestoreId: 'ver1',
    action: 'published',
    performedByUid: 'si1',
    performedAt: '2026-06-19T10:05:01.000Z',
    afterHash: versionFixture().contentHash,
    isDeleted: false,
    ...overrides,
  };
}

describeWithEmulator('O-09 governed assignment real Firestore matrix', () => {
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

  async function seedBase({
    user = {},
    packageData = {},
    versionData = {},
    includeAudit = true,
    audits = null,
  } = {}) {
    await db.collection('users').doc('supervisor1').set({
      isApproved: true,
      roles: ['shiftSupervisor'],
      name: 'Shift Supervisor',
      ...user,
    });
    await db.collection('template_packages').doc('pkg1').set(
      packageFixture(packageData),
    );
    await db.collection('template_versions').doc('ver1').set(
      versionFixture(versionData),
    );
    if (audits != null) {
      for (const [id, data] of Object.entries(audits)) {
        await db.collection('template_publish_audits').doc(id).set(
          auditFixture({firestoreId: id, ...data}),
        );
      }
    } else if (includeAudit) {
      await db.collection('template_publish_audits').doc('audit1').set(
        auditFixture(),
      );
    }
  }

  async function collectionState(name) {
    const snapshot = await db.collection(name).get();
    return snapshot.docs
      .map((doc) => ({id: doc.id, data: clone(doc.data())}))
      .sort((a, b) => a.id.localeCompare(b.id));
  }

  async function captureState() {
    const names = [
      'users',
      'template_packages',
      'template_versions',
      'template_publish_audits',
      'published_template_assignment_requests',
      'job_executions',
      'job_modules',
    ];
    const state = {};
    for (const name of names) state[name] = await collectionState(name);
    return state;
  }

  async function invoke(data = requestFixture(), extra = {}) {
    return assignPublishedTemplateVersionWithDb({
      db,
      authUid: 'supervisor1',
      data,
      now: () => new Date('2026-06-24T10:00:00.000Z'),
      ...extra,
    });
  }

  async function expectRejectedWithoutMutation(expected, call) {
    const before = await captureState();
    await expect(call()).rejects.toMatchObject(expected);
    const after = await captureState();
    expect(after).toEqual(before);
    expect(after.job_executions).toHaveLength(0);
    expect(after.job_modules).toHaveLength(0);
    expect(after.published_template_assignment_requests).toHaveLength(0);
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

  test('valid assignment atomically creates execution, frozen modules, and receipt with population baseline', async () => {
    await seedBase();
    const result = await invoke();
    const state = await captureState();

    expect(result).toMatchObject({ok: true, idempotentReplay: false});
    expect(state.job_executions).toHaveLength(1);
    expect(state.job_modules).toHaveLength(1);
    expect(state.published_template_assignment_requests).toHaveLength(1);
    expect(state.job_executions[0].data).toMatchObject({
      modulePopulationVersion: 1,
      modulePopulationSchemaVersion: 1,
      isCompleted: false,
      templatePackageId: 'pkg1',
      templateVersionId: 'ver1',
    });
    expect(state.job_modules[0].data).toMatchObject({
      addedDuringExecution: false,
      requiredForClosure: true,
      templatePackageId: 'pkg1',
      templateVersionId: 'ver1',
    });
  });

  test('two concurrent identical requests converge to one logical assignment', async () => {
    await seedBase();
    const results = await Promise.all([invoke(), invoke()]);
    const state = await captureState();

    expect(new Set(results.map((item) => item.executionId)).size).toBe(1);
    expect(results.map((item) => item.idempotentReplay).sort()).toEqual([
      false,
      true,
    ]);
    expect(state.job_executions).toHaveLength(1);
    expect(state.job_modules).toHaveLength(1);
    expect(state.published_template_assignment_requests).toHaveLength(1);
  });

  test('same request id with changed payload rejects with whole-state no mutation', async () => {
    await seedBase();
    await invoke();
    const before = await captureState();
    await expect(invoke(requestFixture({remarks: 'Different payload'})))
      .rejects.toMatchObject({
        code: 'already-exists',
        details: {reasonCode: 'request-payload-mismatch'},
      });
    expect(await captureState()).toEqual(before);
  });

  test.each([
    ['unapproved user', {isApproved: false}, 'assignment-role-denied'],
    ['wrong role', {roles: ['operations']}, 'assignment-role-denied'],
  ])('%s rejects without mutation', async (_label, user, reasonCode) => {
    await seedBase({user});
    await expectRejectedWithoutMutation(
      {code: 'permission-denied', details: {reasonCode}},
      () => invoke(),
    );
  });

  test.each([
    ['inactive package', {lifecycleStatus: 'draft'}, {}, 'package-not-active'],
    ['deleted package', {isDeleted: true}, {}, 'package-not-active'],
    ['wrong active version', {activeVersionFirestoreId: 'ver2'}, {}, 'version-not-active'],
    ['unpublished version', {}, {status: 'draft'}, 'version-not-published'],
    ['deleted version', {}, {isDeleted: true}, 'version-not-published'],
  ])('%s rejects without mutation', async (_label, packageData, versionData, reasonCode) => {
    await seedBase({packageData, versionData});
    await expectRejectedWithoutMutation(
      {code: 'failed-precondition', details: {reasonCode}},
      () => invoke(),
    );
  });

  test('stale expected version rejects without mutation', async () => {
    await seedBase();
    await expectRejectedWithoutMutation(
      {
        code: 'failed-precondition',
        details: {reasonCode: 'package-version-number-mismatch'},
      },
      () => invoke(requestFixture({expectedVersionNumber: 2})),
    );
  });

  test('stale expected content hash rejects without mutation', async () => {
    await seedBase();
    await expectRejectedWithoutMutation(
      {code: 'aborted', details: {reasonCode: 'version-hash-changed'}},
      () => invoke(requestFixture({expectedContentHash: OTHER_HASH})),
    );
  });

  test('malformed governed module snapshot rejects without mutation', async () => {
    await seedBase({
      versionData: {moduleSnapshotsJson: '{not-json'},
    });
    await expectRejectedWithoutMutation(
      {
        code: 'failed-precondition',
        details: {reasonCode: 'invalid-snapshot-json'},
      },
      () => invoke(),
    );
  });

  test('stored hash that does not match canonical snapshots rejects without mutation', async () => {
    await seedBase({
      versionData: {contentHash: OTHER_HASH},
      audits: {
        audit1: {afterHash: OTHER_HASH},
      },
    });
    await expectRejectedWithoutMutation(
      {
        code: 'failed-precondition',
        details: {reasonCode: 'version-hash-mismatch'},
      },
      () => invoke(requestFixture({expectedContentHash: OTHER_HASH})),
    );
  });

  test('missing publication audit rejects without mutation', async () => {
    await seedBase({includeAudit: false});
    await expectRejectedWithoutMutation(
      {code: 'not-found', details: {reasonCode: 'publication-audit-missing'}},
      () => invoke(),
    );
  });

  test('equally authoritative matching audits reject as ambiguous without mutation', async () => {
    await seedBase({
      audits: {
        audit_a: {performedAt: '2026-06-19T10:06:01.000Z'},
        audit_b: {performedAt: '2026-06-19T10:06:01.000Z'},
      },
    });
    await expectRejectedWithoutMutation(
      {
        code: 'failed-precondition',
        details: {reasonCode: 'publication-audit-ambiguous'},
      },
      () => invoke(),
    );
  });

  test('multiple matching audits select the newest authority deterministically', async () => {
    await seedBase({
      audits: {
        audit_old: {performedAt: '2026-06-19T10:05:01.000Z'},
        audit_new: {performedAt: '2026-06-19T10:06:01.000Z'},
      },
    });
    const result = await invoke();
    expect(result.publicationAuditId).toBe('audit_new');
    const receipt = await db
      .collection('published_template_assignment_requests')
      .doc(REQUEST_ID)
      .get();
    expect(receipt.data().publicationAuditId).toBe('audit_new');
  });

  test('forced failure before transaction writes leaves no partial execution, module, or receipt', async () => {
    await seedBase();
    await expectRejectedWithoutMutation(
      {message: 'forced-assignment-failure'},
      () => invoke(requestFixture(), {
        beforeAssignmentWritesForTest: async () => {
          throw new Error('forced-assignment-failure');
        },
      }),
    );
  });
});
