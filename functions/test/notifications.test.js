const {
  AGENCY_TO_ROLES,
  agenciesToRoles,
  buildJobAssignedNotification,
  buildTicketCreatedNotification,
  buildTicketResolvedNotification,
  FCM_DEAD_TOKEN_CODES,
  getTokenLookupsForUser,
  getTokenLookupsForRoles,
  MAX_NOTIFICATION_INSTALLATIONS_PER_USER,
  sendNotification,
} = require('../lib/notifications');

// ─── Test harness: minimal Firestore double with transactions ────────────────

function cloneValue(value) {
  if (Array.isArray(value)) return value.map(cloneValue);
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, nested]) => [key, cloneValue(nested)]),
    );
  }
  return value;
}

function fakeTimestamp(iso) {
  const milliseconds = Date.parse(iso);
  return {
    seconds: Math.floor(milliseconds / 1000),
    nanoseconds: 0,
    toMillis: () => milliseconds,
  };
}

function buildFirestoreDouble(initialUsers = {}, initialInstallations = {}) {
  const users = cloneValue(initialUsers);
  const installations = cloneValue(initialInstallations);
  const docUpdates = [];
  const docDeletes = [];

  function dataAtPath(path) {
    const segments = path.split('/');
    if (segments.length === 2 && segments[0] === 'users') {
      return users[segments[1]];
    }
    if (
      segments.length === 4 &&
      segments[0] === 'users' &&
      segments[2] === 'notification_installations'
    ) {
      return installations[segments[1]]?.[segments[3]];
    }
    return undefined;
  }

  function deleteAtPath(path) {
    const segments = path.split('/');
    if (
      segments.length === 4 &&
      segments[0] === 'users' &&
      segments[2] === 'notification_installations'
    ) {
      delete installations[segments[1]]?.[segments[3]];
    }
  }

  function makeDocRef(path) {
    const id = path.split('/').at(-1);
    return {
      path,
      async get() {
        const data = dataAtPath(path);
        return {
          id,
          exists: data != null,
          data: () => (data == null ? undefined : {...data}),
        };
      },
      async update(patch) {
        docUpdates.push({path, patch: {...patch}});
        const data = dataAtPath(path);
        if (data != null) {
          Object.assign(data, patch);
        }
      },
      async delete() {
        docDeletes.push(path);
        deleteAtPath(path);
      },
      collection(name) {
        return makeCollection(`${path}/${name}`);
      },
    };
  }

  function makeQuery(collectionPath) {
    let order = null;
    let maximum = null;
    const q = {
      where: () => q,
      orderBy(field, direction) {
        order = {field, direction};
        return q;
      },
      limit(count) {
        maximum = count;
        return q;
      },
      async get() {
        let entries = [];
        if (collectionPath === 'users') {
          entries = Object.entries(users);
        } else {
          const segments = collectionPath.split('/');
          if (
            segments.length === 3 &&
            segments[0] === 'users' &&
            segments[2] === 'notification_installations'
          ) {
            entries = Object.entries(installations[segments[1]] ?? {});
          }
        }
        if (order != null) {
          entries.sort((left, right) => {
            const leftValue = left[1][order.field];
            const rightValue = right[1][order.field];
            const leftSortable = typeof leftValue?.toMillis === 'function' ?
              leftValue.toMillis() : leftValue;
            const rightSortable = typeof rightValue?.toMillis === 'function' ?
              rightValue.toMillis() : rightValue;
            const comparison = leftSortable < rightSortable ?
              -1 : leftSortable > rightSortable ? 1 : 0;
            return order.direction === 'desc' ? -comparison : comparison;
          });
        }
        if (maximum != null) {
          entries = entries.slice(0, maximum);
        }
        const docs = entries.map(([id, data]) => ({
          id,
          exists: true,
          data: () => ({...data}),
        }));
        return {docs, forEach: (cb) => docs.forEach(cb)};
      },
    };
    return q;
  }

  function makeCollection(path) {
    return {
      ...makeQuery(path),
      doc: (id) => makeDocRef(`${path}/${id}`),
    };
  }

  return {
    db: {
      collection(name) {
        return makeCollection(name);
      },
      async runTransaction(fn) {
        const stagedUpdates = [];
        const stagedDeletes = [];
        const txn = {
          async get(ref) { return ref.get(); },
          update(ref, patch) { stagedUpdates.push({ref, patch}); },
          delete(ref) { stagedDeletes.push(ref); },
        };
        const result = await fn(txn);
        for (const {ref, patch} of stagedUpdates) {
          await ref.update(patch);
        }
        for (const ref of stagedDeletes) {
          await ref.delete();
        }
        return result;
      },
    },
    users,
    installations,
    docUpdates,
    docDeletes,
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

  test('fails closed for legacy or malformed authority records', async () => {
    const {db} = buildFirestoreDouble({
      valid: {isApproved: true, roles: ['admin'], fcmToken: 'valid-token'},
      legacy: {approved: true, roles: ['admin'], fcmToken: 'legacy-token'},
      malformed: {isApproved: true, roles: ['admin', 'bogus'], fcmToken: 'bad-token'},
    });
    const result = await getTokenLookupsForRoles(db, ['admin']);
    expect(result).toEqual([{uid: 'valid', fcmToken: 'valid-token'}]);
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

  test('returns every canonical installation and the legacy migration token', async () => {
    const {db} = buildFirestoreDouble(
      {
        u1: {isApproved: true, roles: ['admin'], fcmToken: 'legacy'},
      },
      {
        u1: {
          phone: {
            schemaVersion: 1,
            token: 'phone-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T01:00:00Z'),
          },
          tablet: {
            schemaVersion: 1,
            token: 'tablet-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T02:00:00Z'),
          },
        },
      },
    );

    const result = await getTokenLookupsForRoles(db, ['admin']);
    expect(result).toEqual(expect.arrayContaining([
      {uid: 'u1', fcmToken: 'legacy'},
      {uid: 'u1', fcmToken: 'phone-token', installationId: 'phone'},
      {uid: 'u1', fcmToken: 'tablet-token', installationId: 'tablet'},
    ]));
    expect(result).toHaveLength(3);
  });

  test('fails closed for malformed installation documents', async () => {
    const {db} = buildFirestoreDouble(
      {u1: {isApproved: true, roles: ['admin']}},
      {
        u1: {
          valid: {
            schemaVersion: 1,
            token: 'valid-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T03:00:00Z'),
          },
          wrongSchema: {
            schemaVersion: 2,
            token: 'wrong-schema',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T02:00:00Z'),
          },
          extraField: {
            schemaVersion: 1,
            token: 'extra-field',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T01:00:00Z'),
            uid: 'u1',
          },
          wrongTimestamp: {
            schemaVersion: 1,
            token: 'wrong-timestamp',
            platform: 'android',
            updatedAt: '2026-08-04T04:00:00Z',
          },
        },
      },
    );

    expect(await getTokenLookupsForRoles(db, ['admin'])).toEqual([
      {uid: 'u1', fcmToken: 'valid-token', installationId: 'valid'},
    ]);
  });

  test('bounds each user to the eight most recently refreshed installations', async () => {
    const installationDocs = Object.fromEntries(
      Array.from({length: 10}, (_, index) => [
        `device-${index}`,
        {
          schemaVersion: 1,
          token: `token-${index}`,
          platform: 'android',
          updatedAt: fakeTimestamp(
            `2026-08-04T${String(index).padStart(2, '0')}:00:00Z`,
          ),
        },
      ]),
    );
    const {db} = buildFirestoreDouble(
      {u1: {isApproved: true, roles: ['admin']}},
      {u1: installationDocs},
    );

    const result = await getTokenLookupsForRoles(db, ['admin']);
    expect(MAX_NOTIFICATION_INSTALLATIONS_PER_USER).toBe(8);
    expect(result).toHaveLength(8);
    expect(result.map((entry) => entry.fcmToken)).toEqual([
      'token-9',
      'token-8',
      'token-7',
      'token-6',
      'token-5',
      'token-4',
      'token-3',
      'token-2',
    ]);
  });

  test('direct-user lookup returns installations only for approved authority', async () => {
    const {db} = buildFirestoreDouble(
      {
        approved: {isApproved: true, roles: ['operations']},
        pending: {isApproved: false, roles: ['operations']},
      },
      {
        approved: {
          phone: {
            schemaVersion: 1,
            token: 'approved-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T01:00:00Z'),
          },
        },
        pending: {
          phone: {
            schemaVersion: 1,
            token: 'pending-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T01:00:00Z'),
          },
        },
      },
    );

    expect(await getTokenLookupsForUser(db, 'approved')).toEqual([
      {
        uid: 'approved',
        fcmToken: 'approved-token',
        installationId: 'phone',
      },
    ]);
    expect(await getTokenLookupsForUser(db, 'pending')).toEqual([]);
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

  test('deletes only the exact stale installation and preserves sibling devices', async () => {
    const {db, installations, docDeletes} = buildFirestoreDouble(
      {u1: {isApproved: true, roles: ['admin']}},
      {
        u1: {
          stale: {
            schemaVersion: 1,
            token: 'dead-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T01:00:00Z'),
          },
          current: {
            schemaVersion: 1,
            token: 'live-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T02:00:00Z'),
          },
        },
      },
    );
    const messaging = buildFakeFcm([
      {
        success: false,
        error: {code: 'messaging/registration-token-not-registered'},
      },
      {success: true},
    ]);

    const outcome = await sendNotification({
      db,
      messaging,
      recipients: [
        {uid: 'u1', fcmToken: 'dead-token', installationId: 'stale'},
        {uid: 'u1', fcmToken: 'live-token', installationId: 'current'},
      ],
      title: 'T',
      body: 'B',
    });

    expect(outcome.staleTokensCleared).toBe(1);
    expect(installations.u1.stale).toBeUndefined();
    expect(installations.u1.current.token).toBe('live-token');
    expect(docDeletes).toEqual([
      'users/u1/notification_installations/stale',
    ]);
  });

  test('does not delete an installation refreshed during FCM delivery', async () => {
    const {db, installations, docDeletes} = buildFirestoreDouble(
      {u1: {isApproved: true, roles: ['admin']}},
      {
        u1: {
          phone: {
            schemaVersion: 1,
            token: 'fresh-token',
            platform: 'android',
            updatedAt: fakeTimestamp('2026-08-04T02:00:00Z'),
          },
        },
      },
    );
    const messaging = buildFakeFcm([
      {
        success: false,
        error: {code: 'messaging/registration-token-not-registered'},
      },
    ]);

    const outcome = await sendNotification({
      db,
      messaging,
      recipients: [
        {uid: 'u1', fcmToken: 'old-token', installationId: 'phone'},
      ],
      title: 'T',
      body: 'B',
    });

    expect(outcome.staleTokensCleared).toBe(0);
    expect(installations.u1.phone.token).toBe('fresh-token');
    expect(docDeletes).toEqual([]);
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

  test('passes workflow deep-link data through to every FCM message', async () => {
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
    const data = {aggregateId: 'wf-1', eventId: 'event-1'};
    await sendNotification({
      db, messaging,
      recipients: [{uid: 'u1', fcmToken: 'token-1'}],
      title: 'T', body: 'B', data,
    });
    expect(messagesSent).toHaveLength(1);
    expect(messagesSent[0].data).toEqual(data);
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
