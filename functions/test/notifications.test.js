const {
  AGENCY_TO_ROLES,
  agenciesToRoles,
  buildJobAssignedNotification,
  buildTicketCreatedNotification,
  buildTicketResolvedNotification,
  FCM_DEAD_TOKEN_CODES,
  getTokenLookupsForRoles,
  sendNotification,
} = require('../lib/notifications');

// ─── Test harness: minimal Firestore double with transactions ────────────────

function buildFirestoreDouble(initialUsers = {}) {
  const users = JSON.parse(JSON.stringify(initialUsers));
  const docUpdates = [];

  function makeDocRef(collectionName, id) {
    return {
      path: `${collectionName}/${id}`,
      async get() {
        const data = collectionName === 'users' ? users[id] : undefined;
        return {
          id,
          exists: data != null,
          data: () => (data == null ? undefined : {...data}),
        };
      },
      async update(patch) {
        docUpdates.push({path: `${collectionName}/${id}`, patch: {...patch}});
        if (collectionName === 'users' && users[id] != null) {
          Object.assign(users[id], patch);
        }
      },
    };
  }

  function makeQuery(collectionName) {
    const q = {
      where: () => q,
      async get() {
        if (collectionName !== 'users') {
          return {docs: [], forEach: () => {}};
        }
        const docs = Object.entries(users).map(([uid, data]) => ({
          id: uid,
          exists: true,
          data: () => ({...data}),
        }));
        return {docs, forEach: (cb) => docs.forEach(cb)};
      },
    };
    return q;
  }

  return {
    db: {
      collection(name) {
        return {
          ...makeQuery(name),
          doc: (id) => makeDocRef(name, id),
        };
      },
      async runTransaction(fn) {
        const stagedUpdates = [];
        const txn = {
          async get(ref) { return ref.get(); },
          update(ref, patch) { stagedUpdates.push({ref, patch}); },
        };
        const result = await fn(txn);
        for (const {ref, patch} of stagedUpdates) {
          await ref.update(patch);
        }
        return result;
      },
    },
    users,
    docUpdates,
  };
}

function buildFakeFcm(responses) {
  return {
    sendEach: async () => ({
      successCount: responses.filter((r) => r.success).length,
      failureCount: responses.filter((r) => !r.success).length,
      responses,
    }),
  };
}

// ─── agenciesToRoles ─────────────────────────────────────────────────────────

describe('agenciesToRoles', () => {
  test('canonical agencies map correctly', () => {
    expect(agenciesToRoles(['mechanical']).roles).toEqual(['seniorMechanical']);
    expect(agenciesToRoles(['electrical']).roles).toEqual(['seniorElectrical']);
    expect(agenciesToRoles(['instrumentation']).roles).toEqual(['seniorInstrumentation']);
    expect(agenciesToRoles(['refractory']).roles).toEqual(['refractory', 'seniorRefractory']);
  });

  test('emd temporary fallback maps to admin/si', () => {
    expect(agenciesToRoles(['emd']).roles).toEqual(['admin', 'si']);
  });

  test('legacy agencies (operations, shiftInCharge, others) are covered', () => {
    expect(agenciesToRoles(['operations']).roles).toEqual(
      expect.arrayContaining(['operations', 'shiftSupervisor']),
    );
    expect(agenciesToRoles(['shiftInCharge']).roles).toEqual(['shiftSupervisor']);
    expect(agenciesToRoles(['others']).roles).toEqual(['admin', 'si']);
  });

  test('shared and safety are NOT agencies (they are module disciplines)', () => {
    expect(AGENCY_TO_ROLES['shared']).toBeUndefined();
    expect(AGENCY_TO_ROLES['safety']).toBeUndefined();
    const result = agenciesToRoles(['shared', 'safety']);
    expect(result.roles).toEqual([]);
    expect(result.unknownAgencies).toEqual(['shared', 'safety']);
  });

  test('multiple agencies dedupe overlapping roles', () => {
    const result = agenciesToRoles(['emd', 'others']);
    expect(result.roles).toEqual(['admin', 'si']);
  });

  test('unknown agency surfaces in unknownAgencies, does not throw', () => {
    expect(agenciesToRoles(['mechanical', 'unicorn', 'rocket'])).toEqual({
      roles: ['seniorMechanical'],
      unknownAgencies: ['unicorn', 'rocket'],
    });
  });

  test('empty input returns empty result', () => {
    expect(agenciesToRoles([])).toEqual({roles: [], unknownAgencies: []});
  });

  test('mapping table covers every agency surfaced by the Dart UI', () => {
    const canonicalAgencies = ['electrical', 'mechanical', 'instrumentation', 'refractory', 'emd'];
    const legacyAgencies = ['operations', 'shiftInCharge', 'others'];
    for (const agency of [...canonicalAgencies, ...legacyAgencies]) {
      expect(AGENCY_TO_ROLES[agency]).toBeDefined();
      expect(AGENCY_TO_ROLES[agency].length).toBeGreaterThan(0);
    }
  });
});

// ─── buildJobAssignedNotification — over-notification regression ─────────────

describe('buildJobAssignedNotification governance fallback', () => {
  test('REGRESSION: mechanical job does NOT cc admin/si', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1, assignedAgencies: ['mechanical'],
    });
    expect(plan.roles).toEqual(['seniorMechanical']);
    expect(plan.roles).not.toContain('admin');
    expect(plan.roles).not.toContain('si');
  });

  test('REGRESSION: electrical+mechanical job does NOT cc admin/si', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1, assignedAgencies: ['mechanical', 'electrical'],
    });
    expect(plan.roles.sort()).toEqual(['seniorElectrical', 'seniorMechanical']);
  });

  test('emd job DOES notify admin/si because that IS the emd mapping', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1, assignedAgencies: ['emd'],
    });
    expect(plan.roles).toEqual(['admin', 'si']);
  });

  test('all-unknown agency list falls back to admin/si governance', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1, assignedAgencies: ['unknown1', 'unknown2'],
    });
    expect(plan.roles).toEqual(['admin', 'si']);
    expect(plan.unknownAgencies).toEqual(['unknown1', 'unknown2']);
  });

  test('mix of known + unknown does NOT trigger governance fallback', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1, assignedAgencies: ['mechanical', 'wizardry'],
    });
    expect(plan.roles).toEqual(['seniorMechanical']);
    expect(plan.unknownAgencies).toEqual(['wizardry']);
  });

  test('returns null for empty agencies', () => {
    expect(buildJobAssignedNotification({assetType: 'baf', assignedAgencies: []})).toBe(null);
    expect(buildJobAssignedNotification({assetType: 'baf'})).toBe(null);
  });

  test('non-string entries in assignedAgencies are filtered', () => {
    const plan = buildJobAssignedNotification({
      assetType: 'baf', assetNumber: 1,
      assignedAgencies: ['mechanical', null, 123, 'electrical'],
    });
    expect(plan.roles.sort()).toEqual(['seniorElectrical', 'seniorMechanical']);
  });
});

// ─── buildTicketCreatedNotification / buildTicketResolvedNotification ────────

describe('buildTicketCreatedNotification', () => {
  test('routedTo refractory adds refractory roles', () => {
    const plan = buildTicketCreatedNotification({
      assetType: 'baf', assetNumber: 3, description: 'Vibration', routedTo: 'refractory',
    });
    expect(plan.title).toBe('🔴 Breakdown: BAF 3');
    expect(plan.roles).toEqual(
      expect.arrayContaining(['admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'refractory', 'seniorRefractory']),
    );
  });

  test('non-refractory routing uses governance roles only', () => {
    const plan = buildTicketCreatedNotification({
      assetType: 'baf', assetNumber: 1, description: 'X', routedTo: 'mechanical',
    });
    expect(plan.roles).toEqual(['admin', 'si', 'contractSupervisor', 'shiftSupervisor']);
  });

  test('empty description falls back to "New breakdown"', () => {
    const plan = buildTicketCreatedNotification({
      assetType: 'baf', assetNumber: 1, description: '', routedTo: '',
    });
    expect(plan.body).toContain('New breakdown');
  });
});

describe('buildTicketResolvedNotification', () => {
  test('happy path', () => {
    const plan = buildTicketResolvedNotification({
      assetType: 'baf', assetNumber: 2, closedByName: 'Ravi',
      remarks: 'Replaced bearing', loggedByUid: 'user1',
    });
    expect(plan.title).toBe('✅ Resolved: BAF 2');
    expect(plan.body).toBe('Closed by Ravi — Replaced bearing');
    expect(plan.roles).toEqual(['admin', 'si']);
    expect(plan.loggedByUid).toBe('user1');
  });

  test('missing loggedByUid returns null', () => {
    expect(
      buildTicketResolvedNotification({
        assetType: 'baf', assetNumber: 1, closedByName: 'X', remarks: 'Y',
      }).loggedByUid,
    ).toBe(null);
  });
});

// ─── getTokenLookupsForRoles ─────────────────────────────────────────────────

describe('getTokenLookupsForRoles', () => {
  test('returns approved users with matching roles and a token', async () => {
    const {db} = buildFirestoreDouble({
      u1: {isApproved: true, roles: ['seniorMechanical'], fcmToken: 'tok1'},
      u2: {isApproved: true, roles: ['admin'], fcmToken: 'tok2'},
      u3: {isApproved: true, roles: ['shiftSupervisor'], fcmToken: 'tok3'},
    });
    const result = await getTokenLookupsForRoles(db, ['admin', 'seniorMechanical']);
    expect(result.map((r) => r.uid).sort()).toEqual(['u1', 'u2']);
  });

  test('skips users without a token', async () => {
    const {db} = buildFirestoreDouble({
      u1: {isApproved: true, roles: ['admin'], fcmToken: null},
      u2: {isApproved: true, roles: ['admin'], fcmToken: ''},
      u3: {isApproved: true, roles: ['admin'], fcmToken: 'good'},
    });
    const result = await getTokenLookupsForRoles(db, ['admin']);
    expect(result).toEqual([{uid: 'u3', fcmToken: 'good'}]);
  });

  test('empty roles → empty list, no DB call', async () => {
    let called = false;
    const db = {
      collection: () => {
        called = true;
        return {
          where: () => ({get: async () => ({docs: [], forEach: () => {}})}),
          doc: () => ({
            get: async () => ({exists: false, data: () => undefined}),
            update: async () => {},
          }),
        };
      },
      runTransaction: async () => {},
    };
    expect(await getTokenLookupsForRoles(db, [])).toEqual([]);
    expect(called).toBe(false);
  });
});

// ─── sendNotification + V2 cleanup behaviour ─────────────────────────────────

describe('sendNotification', () => {
  test('counts successes and failures', async () => {
    const {db} = buildFirestoreDouble({u1: {fcmToken: 't1'}, u2: {fcmToken: 't2'}});
    const messaging = buildFakeFcm([{success: true}, {success: true}]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 't1'}, {uid: 'u2', fcmToken: 't2'}],
      title: 'T', body: 'B',
    });
    expect(outcome).toMatchObject({attempted: 2, succeeded: 2, failed: 0, staleTokensCleared: 0});
  });

  test('clears fcmToken on user with not-registered error', async () => {
    const {db, users, docUpdates} = buildFirestoreDouble({
      u1: {fcmToken: 't1'}, u2: {fcmToken: 't2_dead'},
    });
    const messaging = buildFakeFcm([
      {success: true},
      {success: false, error: {code: 'messaging/registration-token-not-registered'}},
    ]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 't1'}, {uid: 'u2', fcmToken: 't2_dead'}],
      title: 'T', body: 'B',
    });
    expect(outcome.staleTokensCleared).toBe(1);
    expect(users.u2.fcmToken).toBe(null);
    expect(docUpdates).toContainEqual({path: 'users/u2', patch: {fcmToken: null}});
  });

  test('does NOT clear token on transient/unknown errors', async () => {
    const {db, users} = buildFirestoreDouble({u1: {fcmToken: 't1'}, u2: {fcmToken: 't2'}});
    const messaging = buildFakeFcm([
      {success: false, error: {code: 'messaging/server-unavailable'}},
      {success: false, error: {code: 'messaging/internal-error'}},
    ]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 't1'}, {uid: 'u2', fcmToken: 't2'}],
      title: 'T', body: 'B',
    });
    expect(outcome.failed).toBe(2);
    expect(outcome.staleTokensCleared).toBe(0);
    expect(users.u1.fcmToken).toBe('t1');
    expect(users.u2.fcmToken).toBe('t2');
  });

  test('V2: clears dead token from ALL users sharing it (shared tablet)', async () => {
    const {db, users} = buildFirestoreDouble({
      u1: {fcmToken: 'shared_dead'},
      u2: {fcmToken: 'shared_dead'},
      u3: {fcmToken: 'unique_dead'},
    });
    const messaging = buildFakeFcm([
      {success: false, error: {code: 'messaging/registration-token-not-registered'}},
      {success: false, error: {code: 'messaging/invalid-registration-token'}},
    ]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [
        {uid: 'u1', fcmToken: 'shared_dead'},
        {uid: 'u2', fcmToken: 'shared_dead'},
        {uid: 'u3', fcmToken: 'unique_dead'},
      ],
      title: 'T', body: 'B',
    });
    expect(outcome.staleTokensCleared).toBe(3);
    expect(users.u1.fcmToken).toBe(null);
    expect(users.u2.fcmToken).toBe(null);
    expect(users.u3.fcmToken).toBe(null);
  });

  test('V2: race-safe — does NOT clear if token changed between lookup and cleanup', async () => {
    const {db, users, docUpdates} = buildFirestoreDouble({
      u1: {fcmToken: 'fresh_after_refresh'},
    });
    const messaging = buildFakeFcm([
      {success: false, error: {code: 'messaging/registration-token-not-registered'}},
    ]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 'old_dead'}],
      title: 'T', body: 'B',
    });
    expect(outcome.staleTokensCleared).toBe(0);
    expect(users.u1.fcmToken).toBe('fresh_after_refresh');
    expect(docUpdates.filter((u) => u.path === 'users/u1')).toEqual([]);
  });

  test('V2: skips cleanup if user doc no longer exists', async () => {
    const {db, docUpdates} = buildFirestoreDouble({});
    const messaging = buildFakeFcm([
      {success: false, error: {code: 'messaging/registration-token-not-registered'}},
    ]);
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'ghost', fcmToken: 'dead'}],
      title: 'T', body: 'B',
    });
    expect(outcome.staleTokensCleared).toBe(0);
    expect(docUpdates).toEqual([]);
  });

  test('deduplicates sendEach by token', async () => {
    const {db} = buildFirestoreDouble({});
    let messagesSent = null;
    const messaging = {
      sendEach: async (msgs) => {
        messagesSent = msgs;
        return {
          successCount: msgs.length, failureCount: 0,
          responses: msgs.map(() => ({success: true})),
        };
      },
    };
    await sendNotification({
      db, messaging,
      recipients: [
        {uid: 'u1', fcmToken: 'shared'},
        {uid: 'u2', fcmToken: 'shared'},
        {uid: 'u3', fcmToken: 'unique'},
      ],
      title: 'T', body: 'B',
    });
    expect(messagesSent).toHaveLength(2);
  });

  test('empty recipients short-circuits without calling FCM', async () => {
    const {db} = buildFirestoreDouble();
    let fcmCalled = false;
    const messaging = {
      sendEach: async () => {
        fcmCalled = true;
        return {successCount: 0, failureCount: 0, responses: []};
      },
    };
    const outcome = await sendNotification({
      db, messaging, recipients: [], title: 'T', body: 'B',
    });
    expect(fcmCalled).toBe(false);
    expect(outcome.attempted).toBe(0);
  });

  test('FCM_DEAD_TOKEN_CODES exposes the known permanently-dead codes', () => {
    expect(FCM_DEAD_TOKEN_CODES).toEqual(
      expect.arrayContaining([
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
        'messaging/invalid-argument',
      ]),
    );
  });

  test('transaction failure during cleanup does not crash the trigger', async () => {
    const messaging = buildFakeFcm([
      {success: false, error: {code: 'messaging/registration-token-not-registered'}},
    ]);
    const db = {
      collection: () => ({
        where: () => ({get: async () => ({docs: [], forEach: () => {}})}),
        doc: () => ({
          get: async () => ({exists: true, data: () => ({fcmToken: 'dead'})}),
          update: async () => {},
        }),
      }),
      runTransaction: async () => { throw new Error('Firestore down'); },
    };
    const outcome = await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 'dead'}],
      title: 'T', body: 'B',
    });
    expect(outcome.failed).toBe(1);
    expect(outcome.staleTokensCleared).toBe(0);
  });
});
