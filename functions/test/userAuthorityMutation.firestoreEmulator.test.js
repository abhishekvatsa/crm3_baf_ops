const admin = require('firebase-admin');

const {
  canonicalUserAuthorityCapsule,
  canonicalUserAuthorityDigest,
} = require('../lib/userAuthority');
const {
  mutateUserAuthorityWithDb,
} = require('../lib/userAuthorityMutation');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `authority-emulator-${process.pid}-${Date.now()}`;

const IDS = {
  demoteA: '11111111-1111-4111-8111-111111111111',
  demoteB: '22222222-2222-4222-8222-222222222222',
  replay: '33333333-3333-4333-8333-333333333333',
  stale: '44444444-4444-4444-8444-444444444444',
  actorLoss: '55555555-5555-4555-8555-555555555555',
  malformed: '66666666-6666-4666-8666-666666666666',
  collision: '77777777-7777-4777-8777-777777777777',
  approveRace: '88888888-8888-4888-8888-888888888888',
  demoteRace: '99999999-9999-4999-8999-999999999999',
};

function authorityDigest(isApproved, roles) {
  return canonicalUserAuthorityDigest(
    canonicalUserAuthorityCapsule({isApproved, roles}),
  );
}

function requestFixture({
  requestId,
  targetUid,
  operation = 'REPLACE_ROLES',
  isApproved = true,
  currentRoles = ['admin'],
  roles = ['operations'],
  reason = 'Governed authority change for emulator verification.',
}) {
  return {
    requestId,
    targetUid,
    operation,
    expectedAuthorityDigest: authorityDigest(isApproved, currentRoles),
    ...(operation === 'REPLACE_ROLES' ? {roles} : {}),
    reason,
  };
}

describeWithEmulator('S-05 atomic user-authority mutation', () => {
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

  async function seedUser(
    uid,
    {isApproved = true, roles = ['admin'], ...profile} = {},
  ) {
    await db.collection('users').doc(uid).set({
      name: profile.name || uid,
      email: profile.email || `${uid}@test.local`,
      isApproved,
      roles,
      createdAt: new Date('2026-07-26T00:00:00.000Z'),
      ...profile,
    });
  }

  async function invoke(actorUid, data, extra = {}) {
    return mutateUserAuthorityWithDb({
      db,
      authUid: actorUid,
      data,
      now: () => new Date('2026-07-26T01:00:00.000Z'),
      ...extra,
    });
  }

  async function collectionState(name) {
    const snapshot = await db.collection(name).get();
    return snapshot.docs
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .sort((a, b) => a.id.localeCompare(b.id));
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

  test('concurrent cross-demotion leaves exactly one approved Admin and one atomic evidence set', async () => {
    await seedUser('adminA');
    await seedUser('adminB');

    const results = await Promise.allSettled([
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.demoteB,
          targetUid: 'adminB',
        }),
      ),
      invoke(
        'adminB',
        requestFixture({
          requestId: IDS.demoteA,
          targetUid: 'adminA',
        }),
      ),
    ]);

    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);

    const users = await collectionState('users');
    const approvedAdmins = users.filter(
      ({data}) => data.isApproved === true && data.roles.includes('admin'),
    );
    expect(approvedAdmins).toHaveLength(1);

    const demoted = users.filter(({data}) => !data.roles.includes('admin'));
    expect(demoted).toHaveLength(1);
    expect(demoted[0].data.roles).toEqual(['operations']);

    const receipts = await collectionState('user_authority_mutation_receipts');
    const audits = (await collectionState('audit_logs')).filter(({id}) =>
      id.startsWith('server_authority_'),
    );
    expect(receipts).toHaveLength(1);
    expect(audits).toHaveLength(1);
    expect(audits[0].data.requestId).toBe(receipts[0].data.requestId);
    expect(audits[0].data.authorityDigest).toBe(receipts[0].data.authorityDigest);
  });

  test('exact replay returns the same evidence and conflicting replay fails', async () => {
    await seedUser('adminA');
    await seedUser('target', {isApproved: false, roles: ['operations']});
    const request = requestFixture({
      requestId: IDS.replay,
      targetUid: 'target',
      operation: 'APPROVE',
      isApproved: false,
      currentRoles: ['operations'],
    });

    const first = await invoke('adminA', request);
    const replay = await invoke('adminA', request);

    expect(first.idempotentReplay).toBe(false);
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(1);
    expect(
      (await collectionState('audit_logs')).filter(({id}) =>
        id.startsWith('server_authority_'),
      ),
    ).toHaveLength(1);

    await expect(
      invoke('adminA', {...request, reason: 'A different governed reason.'}),
    ).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'authority-request-id-conflict'},
    });
  });

  test('replay fails closed when immutable audit evidence drifts', async () => {
    await seedUser('adminA');
    await seedUser('target', {isApproved: false, roles: ['operations']});
    const request = requestFixture({
      requestId: IDS.replay,
      targetUid: 'target',
      operation: 'APPROVE',
      isApproved: false,
      currentRoles: ['operations'],
    });

    await invoke('adminA', request);
    await db
      .collection('audit_logs')
      .doc(`server_authority_${IDS.replay}`)
      .update({authorityDigest: authorityDigest(false, ['operations'])});

    await expect(invoke('adminA', request)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'authority-replay-evidence-malformed'},
    });
    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(1);
    expect((await db.collection('users').doc('target').get()).data().isApproved).toBe(
      true,
    );
  });

  test('stale target preimage fails without audit, receipt, or target mutation', async () => {
    await seedUser('adminA');
    await seedUser('target', {roles: ['operations']});
    const before = (await db.collection('users').doc('target').get()).data();

    await expect(
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.stale,
          targetUid: 'target',
          currentRoles: ['admin'],
        }),
      ),
    ).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'authority-preimage-mismatch'},
    });

    expect((await db.collection('users').doc('target').get()).data()).toEqual(before);
    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(0);
    expect(await collectionState('audit_logs')).toHaveLength(0);
  });

  test('actor authority is revalidated after preflight and before transaction writes', async () => {
    await seedUser('adminA');
    await seedUser('adminB');
    await seedUser('target', {roles: ['operations']});

    await expect(
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.actorLoss,
          targetUid: 'target',
          currentRoles: ['operations'],
          roles: ['operations', 'si'],
        }),
        {
          beforeTransactionForTest: async () => {
            await db.collection('users').doc('adminA').update({isApproved: false});
          },
        },
      ),
    ).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'approved-admin-required'},
    });

    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(0);
    expect(await collectionState('audit_logs')).toHaveLength(0);
    expect((await db.collection('users').doc('target').get()).data().roles).toEqual([
      'operations',
    ]);
  });

  test('malformed target authority fails closed', async () => {
    await seedUser('adminA');
    await seedUser('target', {roles: ['operations', 'unknownRole']});

    await expect(
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.malformed,
          targetUid: 'target',
          currentRoles: ['operations'],
        }),
      ),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'authority-target-malformed'},
    });

    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(0);
    expect(await collectionState('audit_logs')).toHaveLength(0);
  });

  test('pre-existing immutable audit identity aborts before target mutation', async () => {
    await seedUser('adminA');
    await seedUser('target', {roles: ['operations']});
    await db
      .collection('audit_logs')
      .doc(`server_authority_${IDS.collision}`)
      .set({occupied: true});

    await expect(
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.collision,
          targetUid: 'target',
          currentRoles: ['operations'],
          roles: ['operations', 'si'],
        }),
      ),
    ).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'authority-audit-collision'},
    });

    expect((await db.collection('users').doc('target').get()).data().roles).toEqual([
      'operations',
    ]);
    expect(await collectionState('user_authority_mutation_receipts')).toHaveLength(0);
  });

  test('approval and demotion race preserves an approved Admin under either serialization', async () => {
    await seedUser('adminA');
    await seedUser('adminB');
    await seedUser('candidate', {isApproved: false, roles: ['admin']});

    const results = await Promise.allSettled([
      invoke(
        'adminA',
        requestFixture({
          requestId: IDS.approveRace,
          targetUid: 'candidate',
          operation: 'APPROVE',
          isApproved: false,
          currentRoles: ['admin'],
        }),
      ),
      invoke(
        'adminB',
        requestFixture({
          requestId: IDS.demoteRace,
          targetUid: 'adminA',
        }),
      ),
    ]);
    expect(results.some((result) => result.status === 'fulfilled')).toBe(true);

    const users = await collectionState('users');
    expect(
      users.filter(
        ({data}) => data.isApproved === true && data.roles.includes('admin'),
      ).length,
    ).toBeGreaterThanOrEqual(1);
    const receipts = await collectionState('user_authority_mutation_receipts');
    const audits = (await collectionState('audit_logs')).filter(({id}) =>
      id.startsWith('server_authority_'),
    );
    expect(audits).toHaveLength(receipts.length);
  });
});
