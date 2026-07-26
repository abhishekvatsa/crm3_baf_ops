const admin = require('firebase-admin');

const {
  CALLABLE_ABUSE_CONTROL_COLLECTION,
  CALLABLE_ABUSE_POLICIES,
  executeWithCallableAbuseControl,
} = require('../lib/callableAbuseControl');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `abuse-control-emulator-${process.pid}-${Date.now()}`;

describeWithEmulator('S-03 callable abuse-control transactions', () => {
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

  async function records() {
    const snapshot = await db
      .collection(CALLABLE_ABUSE_CONTROL_COLLECTION)
      .get();
    return snapshot.docs.map((doc) => ({id: doc.id, data: doc.data()}));
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  afterAll(async () => {
    if (app) await app.delete();
  });

  test('concurrent admission commits exactly the burst limit', async () => {
    const actorUid = 'approved-concurrent-user';
    const callableName = 'assignPublishedTemplateVersion';
    const policy = CALLABLE_ABUSE_POLICIES[callableName];
    const now = () => new Date('2026-07-26T06:00:00.000Z');
    let executions = 0;

    const results = await Promise.allSettled(
      Array.from({length: policy.burstRequestLimit + 4}, () =>
        executeWithCallableAbuseControl({
          db,
          actorUid,
          callableName,
          now,
          execute: async () => {
            executions += 1;
            return {ok: true};
          },
        }),
      ),
    );

    expect(results.filter(({status}) => status === 'fulfilled')).toHaveLength(
      policy.burstRequestLimit,
    );
    expect(results.filter(({status}) => status === 'rejected')).toHaveLength(4);
    expect(results.filter(({status}) => status === 'rejected').every(
      ({reason}) =>
        reason.code === 'resource-exhausted' &&
        reason.details.reasonCode === 'callable-burst-limit-exceeded',
    )).toBe(true);
    expect(executions).toBe(policy.burstRequestLimit);

    const stored = await records();
    expect(stored).toHaveLength(1);
    expect(stored[0].id).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(stored[0])).not.toContain(actorUid);
    expect(stored[0].data).toMatchObject({
      burstRequestCount: policy.burstRequestLimit + 4,
      dailyRequestCount: policy.burstRequestLimit + 4,
      blockedRequestCount: 4,
    });
  });

  test('caller anomalies persist and gate the next transaction', async () => {
    const actorUid = 'approved-anomaly-user';
    const callableName = 'assignPublishedTemplateVersion';
    const policy = CALLABLE_ABUSE_POLICIES[callableName];
    let nowMs = new Date('2026-07-26T07:00:00.000Z').getTime();
    let executions = 0;

    for (let index = 0; index < policy.anomalyLimit; index += 1) {
      await expect(executeWithCallableAbuseControl({
        db,
        actorUid,
        callableName,
        now: () => new Date(nowMs),
        execute: async () => {
          executions += 1;
          throw Object.assign(new Error('bad input'), {
            code: 'invalid-argument',
          });
        },
      })).rejects.toMatchObject({code: 'invalid-argument'});
      nowMs += policy.burstWindowSeconds * 1000;
    }

    await expect(executeWithCallableAbuseControl({
      db,
      actorUid,
      callableName,
      now: () => new Date(nowMs),
      execute: async () => {
        executions += 1;
        return {ok: true};
      },
    })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: {reasonCode: 'callable-anomaly-limit-exceeded'},
    });
    expect(executions).toBe(policy.anomalyLimit);
    expect((await records())[0].data).toMatchObject({
      anomalyCount: policy.anomalyLimit,
      lastAnomalyCode: 'invalid-argument',
      blockedRequestCount: 1,
    });
  });

  test('partial persisted state fails closed before execution', async () => {
    const actorUid = 'approved-corrupt-state-user';
    const callableName = 'mutateUserAuthority';
    const now = () => new Date('2026-07-26T08:00:00.000Z');

    await executeWithCallableAbuseControl({
      db,
      actorUid,
      callableName,
      now,
      execute: async () => ({ok: true}),
    });
    const [stored] = await records();
    await db
      .collection(CALLABLE_ABUSE_CONTROL_COLLECTION)
      .doc(stored.id)
      .update({dailyRequestCount: admin.firestore.FieldValue.delete()});

    let executed = false;
    await expect(executeWithCallableAbuseControl({
      db,
      actorUid,
      callableName,
      now,
      execute: async () => {
        executed = true;
        return {ok: true};
      },
    })).rejects.toMatchObject({
      code: 'internal',
      details: {reasonCode: 'abuse-control-shape-invalid'},
    });
    expect(executed).toBe(false);
  });
});
