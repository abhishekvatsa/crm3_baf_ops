// Exact governed fixtures shared with the existing assignment emulator suite.
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


module.exports = {requestFixture, packageFixture, versionFixture, auditFixture};
