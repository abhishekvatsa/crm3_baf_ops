const admin = require('firebase-admin');
const {FieldValue, GeoPoint, Timestamp} = require('firebase-admin/firestore');
const {
  GLOBAL_PULL_COLLECTIONS,
  GLOBAL_PULL_PROTOCOL_VERSION,
  GLOBAL_PULL_PROTOCOL_FINGERPRINT,
  GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
  GLOBAL_PULL_WRITER_VERSION,
} = require('../lib/globalPullServerClock');

// Firebase CLI binds the Admin namespace accessor in its Functions runtime.
// Admin 13's accessor returns an arrow function with class properties, which
// Function.bind does not carry over. Exercise the deployed entrypoints under
// that shape so normal SDK-only unit tests cannot conceal the runtime failure.
const originalDescriptor = Object.getOwnPropertyDescriptor(admin, 'firestore');
const boundFirestore = admin.firestore.bind(admin);
Object.defineProperty(admin, 'firestore', {
  configurable: true,
  value: boundFirestore,
});
const originalProject = process.env.GCLOUD_PROJECT;
process.env.GCLOUD_PROJECT = 'demo-firestore-binding-regression';
const endpoints = require('../lib/index');
const {workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');

afterAll(async () => {
  if (originalDescriptor) Object.defineProperty(admin, 'firestore', originalDescriptor);
  else delete admin.firestore;
  if (originalProject == null) delete process.env.GCLOUD_PROJECT;
  else process.env.GCLOUD_PROJECT = originalProject;
  await Promise.all(admin.apps.map(app => app.delete()));
});

test('workflow persistence preserves SDK values and converts instants with a bound namespace', () => {
  expect(admin.firestore.Timestamp).toBeUndefined();
  expect(admin.firestore.FieldValue).toBeUndefined();
  const date = new Date('2026-09-01T08:00:00.123Z');
  const timestamp = Timestamp.fromDate(date);
  const sentinel = FieldValue.serverTimestamp();
  const point = new GeoPoint(23.6693, 86.1511);
  const reference = admin.firestore().doc('maintenance_records/binding-regression');
  const converted = workflowFirestoreDataForTest({
    createdAt: date,
    nextEscalationAt: date.toISOString(),
    nested: {timestamp, sentinel, point, reference},
  });
  expect(converted.createdAt).toEqual(timestamp);
  expect(converted.nextEscalationAt).toEqual(timestamp);
  for (const [name, value] of Object.entries({timestamp, sentinel, point, reference})) {
    expect(converted.nested[name]).toBe(value);
  }
});

test('global pull callable creates its server anchor with a bound namespace', async () => {
  const activatedAt = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
  const documents = {
    'users/binding-regression': {isApproved: true, roles: ['admin']},
    'runtime_contracts/global_pull_v1': {
      state: 'ACTIVE',
      protocolVersion: GLOBAL_PULL_PROTOCOL_VERSION,
      protocolFingerprint: GLOBAL_PULL_PROTOCOL_FINGERPRINT,
      writerVersion: GLOBAL_PULL_WRITER_VERSION,
      serverStampField: GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
      collections: [...GLOBAL_PULL_COLLECTIONS],
      activatedAt,
      sourceCommit: 'a'.repeat(40),
      backfillReceiptSha256: 'b'.repeat(64),
    },
  };
  const reader = jest.spyOn(admin.firestore(), 'doc').mockImplementation(path => ({
    get: async () => ({exists: documents[path] != null, data: () => documents[path]}),
  }));
  try {
    const before = Date.now();
    const result = await endpoints.beginGlobalPullRun.run({auth: {uid: 'binding-regression'}, data: {}});
    expect(result.actorUid).toBe('binding-regression');
    expect(Date.parse(result.serverAnchor)).toBeGreaterThanOrEqual(before);
    expect(Date.parse(result.serverAnchor)).toBeLessThanOrEqual(Date.now());
    expect(result.activatedAt).toBe(activatedAt.toDate().toISOString());
  } finally {
    reader.mockRestore();
  }
});

test('global pull trigger writes a native server timestamp with a bound namespace', async () => {
  const update = jest.fn(async () => undefined);
  await endpoints.stampGlobalPullServerClock.run({
    params: {collectionId: 'charge_abnormalities', documentId: 'binding-regression'},
    data: {
      before: {exists: false, data: () => undefined},
      after: {exists: true, data: () => ({status: 'open'}), ref: {update}},
    },
  });
  expect(update).toHaveBeenCalledTimes(1);
  const stamp = update.mock.calls[0][0][GLOBAL_PULL_SERVER_UPDATED_AT_FIELD];
  expect(stamp).toBeInstanceOf(FieldValue);
  expect(stamp.isEqual(FieldValue.serverTimestamp())).toBe(true);
});
