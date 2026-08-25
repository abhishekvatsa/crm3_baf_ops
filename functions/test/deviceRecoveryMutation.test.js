const {
  DeviceRecoveryMutationError,
  canonicalDeviceInstallationForTest,
  isDeviceRecoveryOperation,
  mutateDeviceRecoveryWithDb,
  userCanMutateDeviceRecovery,
  userCanResumeClaimedDeviceRecovery,
} = require('../lib/deviceRecoveryMutation');

const ADMIN = 'admin-1';
const TARGET = 'operator-1';
const OTHER = 'operator-2';
const INSTALLATION = '11111111-1111-4111-8111-111111111111';
const OTHER_INSTALLATION = '22222222-2222-4222-8222-222222222222';
const REQUEST = '33333333-3333-4333-8333-333333333333';
const NOW = new Date('2026-08-25T12:00:00.000Z');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function user(name, roles = ['operations'], approved = true) {
  return {
    name,
    email: `${name.toLowerCase().replaceAll(' ', '.')}@test.local`,
    roles,
    isApproved: approved,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };
}

function installation(platform = 'android') {
  return {
    schemaVersion: 1,
    token: `private-${platform}-token`,
    platform,
    updatedAt: new Date('2026-08-25T10:00:00.000Z'),
  };
}

function fakeDb(seed = {}) {
  const store = new Map(
    Object.entries(seed).map(([path, value]) => [path, clone(value)]),
  );
  const writes = [];

  function snapshot(path) {
    const value = store.get(path);
    return {
      id: path.split('/').at(-1),
      exists: value != null,
      data: () => clone(value),
    };
  }

  function query(path, direction = 'asc', maximum = null) {
    return {
      path,
      direction,
      maximum,
      orderBy(_field, nextDirection) {
        return query(path, nextDirection, maximum);
      },
      limit(value) {
        return query(path, direction, value);
      },
      async get() {
        const prefix = `${path}/`;
        let docs = [...store.keys()]
          .filter((key) => key.startsWith(prefix) &&
            !key.slice(prefix.length).includes('/'))
          .map(snapshot)
          .sort((left, right) => {
            const leftAt = left.data()?.updatedAt?.getTime?.() ?? 0;
            const rightAt = right.data()?.updatedAt?.getTime?.() ?? 0;
            return direction === 'desc' ? rightAt - leftAt : leftAt - rightAt;
          });
        if (maximum != null) docs = docs.slice(0, maximum);
        return {docs, forEach(callback) { docs.forEach(callback); }};
      },
    };
  }

  function document(path) {
    return {
      id: path.split('/').at(-1),
      path,
      async get() { return snapshot(path); },
      collection(name) { return collection(`${path}/${name}`); },
    };
  }

  function collection(path) {
    return {
      ...query(path),
      doc(id) { return document(`${path}/${id}`); },
    };
  }

  return {
    store,
    writes,
    db: {
      collection,
      async runTransaction(work) {
        const staged = [];
        const transaction = {
          async get(ref) {
            return ref.maximum !== undefined ? ref.get() : snapshot(ref.path);
          },
          create(ref, data) {
            if (store.has(ref.path) ||
                staged.some((entry) => entry.path === ref.path)) {
              throw new Error(`already exists: ${ref.path}`);
            }
            staged.push({kind: 'create', path: ref.path, data: clone(data)});
          },
          set(ref, data) {
            staged.push({kind: 'set', path: ref.path, data: clone(data)});
          },
          update(ref, data) {
            if (!store.has(ref.path)) throw new Error(`missing: ${ref.path}`);
            staged.push({kind: 'update', path: ref.path, data: clone(data)});
          },
        };
        const result = await work(transaction);
        for (const entry of staged) {
          const current = store.get(entry.path) ?? {};
          const value = entry.kind === 'update' ?
            {...clone(current), ...clone(entry.data)} : clone(entry.data);
          store.set(entry.path, value);
          writes.push(entry);
        }
        return result;
      },
    },
  };
}

function seed() {
  return {
    [`users/${ADMIN}`]: user('Admin One', ['admin']),
    [`users/${TARGET}`]: user('Operator One'),
    [`users/${OTHER}`]: user('Operator Two'),
    [`users/${TARGET}/notification_installations/${INSTALLATION}`]:
      installation(),
    [`users/${OTHER}/notification_installations/${OTHER_INSTALLATION}`]:
      installation(),
  };
}

function args(db, authUid, data, now = NOW) {
  return {
    db,
    authUid,
    data,
    timestampFromDate: (value) => value,
    now: () => now,
  };
}

function requestData(overrides = {}) {
  return {
    operation: 'DEVICE_RECOVERY_REQUEST',
    requestId: REQUEST,
    targetUid: TARGET,
    installationId: INSTALLATION,
    reason: 'Pilot device contains stale local synchronization data.',
    ...overrides,
  };
}

function claimData(overrides = {}) {
  return {
    operation: 'DEVICE_RECOVERY_CLAIM',
    requestId: REQUEST,
    installationId: INSTALLATION,
    ...overrides,
  };
}

function statePath(uid = TARGET, installationId = INSTALLATION) {
  const crypto = require('crypto');
  const id = crypto.createHash('sha256')
    .update(`${uid}:${installationId}`, 'utf8')
    .digest('hex');
  return `device_recovery_requests/${id}`;
}

describe('governed remote device recovery', () => {
  test('operation and authority classifiers fail closed', () => {
    expect(isDeviceRecoveryOperation('DEVICE_RECOVERY_REQUEST')).toBe(true);
    expect(isDeviceRecoveryOperation('DEVICE_RECOVERY_CLAIM')).toBe(true);
    expect(isDeviceRecoveryOperation('RESET_EVERYTHING')).toBe(false);
    expect(userCanMutateDeviceRecovery(
      user('Admin', ['admin']),
      'DEVICE_RECOVERY_REQUEST',
    )).toBe(true);
    expect(userCanMutateDeviceRecovery(
      user('Operator'),
      'DEVICE_RECOVERY_REQUEST',
    )).toBe(false);
    expect(userCanMutateDeviceRecovery(
      user('Operator'),
      'DEVICE_RECOVERY_POLL',
    )).toBe(true);
    expect(userCanMutateDeviceRecovery(
      user('Revoked', ['admin'], false),
      'DEVICE_RECOVERY_REQUEST',
    )).toBe(false);
  });

  test('admin list returns bounded metadata without private tokens', async () => {
    const fixture = fakeDb({
      ...seed(),
      [`users/${TARGET}/notification_installations/${OTHER_INSTALLATION}`]: {
        ...installation('ios'),
        unexpected: true,
      },
    });
    expect(canonicalDeviceInstallationForTest(
      fixture.store.get(
        `users/${TARGET}/notification_installations/${INSTALLATION}`,
      ),
    )).toBe(true);
    const result = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      {operation: 'DEVICE_RECOVERY_LIST', targetUid: TARGET},
    ));
    expect(result.installations).toHaveLength(1);
    expect(result.installations[0]).toMatchObject({
      installationId: INSTALLATION,
      platform: 'android',
      recoveryStatus: 'none',
    });
    expect(JSON.stringify(result)).not.toContain('private-android-token');
  });

  test('web installations cannot be selected for local database recovery', async () => {
    const fixture = fakeDb({
      ...seed(),
      [`users/${TARGET}/notification_installations/${OTHER_INSTALLATION}`]:
        installation('web'),
    });

    expect(canonicalDeviceInstallationForTest(installation('web'))).toBe(false);
    const inventory = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      {operation: 'DEVICE_RECOVERY_LIST', targetUid: TARGET},
    ));
    expect(inventory.installations).toHaveLength(1);
    expect(inventory.installations[0].installationId).toBe(INSTALLATION);

    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({installationId: OTHER_INSTALLATION}),
    ))).rejects.toMatchObject({
      code: 'not-found',
      details: {reasonCode: 'device-recovery-installation-not-found'},
    });
  });

  test('only a fresh admin can issue an exact targeted request', async () => {
    const fixture = fakeDb(seed());
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      requestData(),
    ))).rejects.toMatchObject({code: 'permission-denied'});
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({unexpected: true}),
    ))).rejects.toMatchObject({code: 'invalid-argument'});

    const result = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData(),
    ));
    expect(result).toMatchObject({
      ok: true,
      status: 'pending',
      notificationQueued: true,
      idempotentReplay: false,
    });
    expect(fixture.store.get(statePath())).toMatchObject({
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      requestedByUid: ADMIN,
      status: 'pending',
    });
    expect(fixture.store.get(
      `maintenance_workflow_events/device_recovery_${REQUEST}`,
    )).toMatchObject({
      aggregateId: REQUEST,
      eventType: 'deviceRecovery.requested',
      payload: {deviceRecoveryRequestId: REQUEST},
    });
    expect(fixture.store.get(
      `audit_logs/server_authority_device_recovery_${REQUEST}_requested`,
    )).toMatchObject({
      entityType: 'deviceRecovery',
      performedByUid: ADMIN,
      action: 'create',
      severity: 'high',
    });
  });

  test('approved administrator-owned phones remain valid recovery targets', async () => {
    const fixture = fakeDb({
      ...seed(),
      [`users/${ADMIN}/notification_installations/${INSTALLATION}`]:
        installation(),
    });

    const inventory = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      {operation: 'DEVICE_RECOVERY_LIST', targetUid: ADMIN},
    ));
    expect(inventory.installations).toHaveLength(1);

    const result = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({targetUid: ADMIN}),
    ));
    expect(result).toMatchObject({
      status: 'pending',
      targetUid: ADMIN,
      installationId: INSTALLATION,
    });
  });

  test('exact request replay is idempotent and conflicts fail closed', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const writes = fixture.writes.length;
    const replay = await mutateDeviceRecoveryWithDb(
      args(fixture.db, ADMIN, requestData()),
    );
    expect(replay.idempotentReplay).toBe(true);
    expect(fixture.writes).toHaveLength(writes);
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({reason: 'A different reason cannot reuse the same identity.'}),
    ))).rejects.toMatchObject({code: 'aborted'});
  });

  test('only the exact target phone can poll and acknowledge', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));

    const poll = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ));
    expect(poll.request).toMatchObject({
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      status: 'pending',
    });
    const otherPoll = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      OTHER,
      {
        operation: 'DEVICE_RECOVERY_POLL',
        installationId: OTHER_INSTALLATION,
      },
    ));
    expect(otherPoll.request).toBeNull();
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      OTHER,
      {
        operation: 'DEVICE_RECOVERY_COMPLETE',
        requestId: REQUEST,
        installationId: OTHER_INSTALLATION,
        backupFileCount: 1,
        clearedCursorCount: 2,
        backedUpUnsyncedRows: 0,
      },
    ))).rejects.toMatchObject({code: 'not-found'});
  });

  test('completion requires backup evidence and is replay safe', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const completion = {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId: REQUEST,
      installationId: INSTALLATION,
      backupFileCount: 1,
      clearedCursorCount: 3,
      backedUpUnsyncedRows: 2,
    };
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      completion,
    ))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'device-recovery-state-not-claimed'},
    });
    await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, claimData()),
    );
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {...completion, backupFileCount: 0},
    ))).rejects.toMatchObject({code: 'failed-precondition'});

    const first = await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, completion),
    );
    expect(first).toMatchObject({status: 'completed', idempotentReplay: false});
    expect(fixture.store.get(statePath())).toMatchObject({
      status: 'completed',
      backupFileCount: 1,
      clearedCursorCount: 3,
      backedUpUnsyncedRows: 2,
    });
    const replay = await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, completion),
    );
    expect(replay.idempotentReplay).toBe(true);
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {...completion, backedUpUnsyncedRows: 7},
    ))).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'device-recovery-replay-evidence-mismatch'},
    });
  });

  test('a claimed target can finish and replay after its approval is revoked', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, claimData()));
    fixture.store.set(`users/${TARGET}`, user('Operator One', ['operations'], false));

    const resumed = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ));
    expect(resumed.request).toMatchObject({
      requestId: REQUEST,
      status: 'in_progress',
    });

    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, claimData()),
    )).toMatchObject({status: 'in_progress', idempotentReplay: true});

    const completion = {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId: REQUEST,
      installationId: INSTALLATION,
      backupFileCount: 1,
      clearedCursorCount: 2,
      backedUpUnsyncedRows: 3,
    };
    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, completion),
    )).toMatchObject({status: 'completed', idempotentReplay: false});
    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, completion),
    )).toMatchObject({status: 'completed', idempotentReplay: true});
  });

  test('revoked preflight admits only an exact previously claimed recovery', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const revokedActor = user('Operator One', ['operations'], false);
    const authorize = (data) => userCanResumeClaimedDeviceRecovery({
      db: fixture.db,
      actorUid: TARGET,
      actorData: revokedActor,
      data,
    });
    const poll = {
      operation: 'DEVICE_RECOVERY_POLL',
      installationId: INSTALLATION,
    };

    expect(await authorize(poll)).toBe(false);
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, claimData()));
    fixture.store.set(`users/${TARGET}`, revokedActor);

    const completion = {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId: REQUEST,
      installationId: INSTALLATION,
      backupFileCount: 1,
      clearedCursorCount: 2,
      backedUpUnsyncedRows: 3,
    };
    expect(await authorize(poll)).toBe(true);
    expect(await authorize(claimData())).toBe(true);
    expect(await authorize(completion)).toBe(true);
    expect(await authorize({...completion, backupFileCount: 0})).toBe(false);
    expect(await authorize({
      ...claimData(),
      installationId: OTHER_INSTALLATION,
    })).toBe(false);
    expect(await authorize(requestData())).toBe(false);

    const claimPath =
      `audit_logs/server_authority_device_recovery_${REQUEST}_claimed`;
    const claimAudit = fixture.store.get(claimPath);
    fixture.store.delete(claimPath);
    expect(await authorize(poll)).toBe(false);
    fixture.store.set(claimPath, claimAudit);

    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, completion));
    expect(await authorize(completion)).toBe(true);
    expect(await authorize({
      ...completion,
      backedUpUnsyncedRows: 4,
    })).toBe(false);
    expect(await authorize(poll)).toBe(false);
  });

  test('a claimed revoked target can report and replay a safe recovery failure', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, claimData()));
    fixture.store.set(`users/${TARGET}`, user('Operator One', ['operations'], false));

    const failure = {
      operation: 'DEVICE_RECOVERY_FAIL',
      requestId: REQUEST,
      installationId: INSTALLATION,
      failureCode: 'device-recovery-backup-missing',
    };
    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, failure),
    )).toMatchObject({status: 'failed', idempotentReplay: false});
    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, failure),
    )).toMatchObject({status: 'failed', idempotentReplay: true});
  });

  test('revoking a target before its claim never grants reset authority', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    fixture.store.set(`users/${TARGET}`, user('Operator One', ['operations'], false));

    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ))).rejects.toMatchObject({code: 'permission-denied'});
    await expect(mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, claimData()),
    )).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('backup failure is retained and prevents a false completion', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, claimData()));
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, {
      operation: 'DEVICE_RECOVERY_FAIL',
      requestId: REQUEST,
      installationId: INSTALLATION,
      failureCode: 'backup-not-created',
    }));
    expect(fixture.store.get(statePath())).toMatchObject({
      status: 'failed',
      failureCode: 'backup-not-created',
    });
    await expect(mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId: REQUEST,
      installationId: INSTALLATION,
      backupFileCount: 1,
      clearedCursorCount: 1,
      backedUpUnsyncedRows: 0,
    }))).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('admin may cancel only an exact pending request', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const result = await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, {
      operation: 'DEVICE_RECOVERY_CANCEL',
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      reason: 'Pilot operator confirmed that recovery is no longer needed.',
    }));
    expect(result.status).toBe('cancelled');
    expect(fixture.store.get(statePath())).toMatchObject({
      status: 'cancelled',
      cancelledByUid: ADMIN,
    });
    await expect(mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, {
      operation: 'DEVICE_RECOVERY_CANCEL',
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      reason: 'A replacement reason cannot rewrite the cancellation audit.',
    }))).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'device-recovery-cancellation-evidence-mismatch'},
    });
  });

  test('failed recovery replays preserve the original failure evidence', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, claimData()));
    const failure = {
      operation: 'DEVICE_RECOVERY_FAIL',
      requestId: REQUEST,
      installationId: INSTALLATION,
      failureCode: 'backup-not-created',
    };
    await mutateDeviceRecoveryWithDb(args(fixture.db, TARGET, failure));
    expect(await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, failure),
    )).toMatchObject({status: 'failed', idempotentReplay: true});
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {...failure, failureCode: 'a-different-failure'},
    ))).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'device-recovery-replay-evidence-mismatch'},
    });
  });

  test('expired requests do not execute on a phone that returns later', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const poll = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
      new Date(NOW.getTime() + (25 * 60 * 60 * 1000)),
    ));
    expect(poll.request).toBeNull();
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      claimData(),
      new Date(NOW.getTime() + (25 * 60 * 60 * 1000)),
    ))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'device-recovery-request-expired'},
    });
  });

  test('claimed reset cannot be cancelled or replaced during local deletion', async () => {
    const fixture = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, requestData()));
    const claim = await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, claimData()),
    );
    expect(claim).toMatchObject({
      status: 'in_progress',
      targetUid: TARGET,
      idempotentReplay: false,
    });
    expect(fixture.store.get(statePath())).toMatchObject({
      status: 'in_progress',
      startedByUid: TARGET,
    });
    expect(fixture.store.get(
      `audit_logs/server_authority_device_recovery_${REQUEST}_claimed`,
    )).toMatchObject({performedByUid: TARGET, entityType: 'deviceRecovery'});

    const writes = fixture.writes.length;
    const replay = await mutateDeviceRecoveryWithDb(
      args(fixture.db, TARGET, claimData()),
    );
    expect(replay.idempotentReplay).toBe(true);
    expect(fixture.writes).toHaveLength(writes);
    const poll = await mutateDeviceRecoveryWithDb(args(
      fixture.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ));
    expect(poll.request.status).toBe('in_progress');

    await expect(mutateDeviceRecoveryWithDb(args(fixture.db, ADMIN, {
      operation: 'DEVICE_RECOVERY_CANCEL',
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      reason: 'Cancellation must not race a claimed destructive reset.',
    }))).rejects.toMatchObject({code: 'failed-precondition'});
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({requestId: '44444444-4444-4444-8444-444444444444'}),
    ))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'device-recovery-already-in-progress'},
    });
  });

  test('cancelled reset cannot be claimed and revoked issuer blocks claim', async () => {
    const cancelled = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(cancelled.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(cancelled.db, ADMIN, {
      operation: 'DEVICE_RECOVERY_CANCEL',
      requestId: REQUEST,
      targetUid: TARGET,
      installationId: INSTALLATION,
      reason: 'Operator confirmed the pending recovery is no longer needed.',
    }));
    await expect(mutateDeviceRecoveryWithDb(
      args(cancelled.db, TARGET, claimData()),
    )).rejects.toMatchObject({code: 'failed-precondition'});

    const revoked = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(revoked.db, ADMIN, requestData()));
    revoked.store.set(`users/${ADMIN}`, user('Admin One', ['operations']));
    await expect(mutateDeviceRecoveryWithDb(
      args(revoked.db, TARGET, claimData()),
    )).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'device-recovery-issuer-authority-denied'},
    });
  });

  test('issuer revocation blocks pending polling but cannot strand a claimed reset', async () => {
    const pending = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(pending.db, ADMIN, requestData()));
    pending.store.set(`users/${ADMIN}`, user('Admin One', ['operations']));
    const withheld = await mutateDeviceRecoveryWithDb(args(
      pending.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ));
    expect(withheld.request).toBeNull();

    const claimed = fakeDb(seed());
    await mutateDeviceRecoveryWithDb(args(claimed.db, ADMIN, requestData()));
    await mutateDeviceRecoveryWithDb(args(claimed.db, TARGET, claimData()));
    claimed.store.delete(`users/${ADMIN}`);

    const resumed = await mutateDeviceRecoveryWithDb(args(
      claimed.db,
      TARGET,
      {operation: 'DEVICE_RECOVERY_POLL', installationId: INSTALLATION},
    ));
    expect(resumed.request).toMatchObject({
      requestId: REQUEST,
      status: 'in_progress',
    });
    expect(await mutateDeviceRecoveryWithDb(
      args(claimed.db, TARGET, claimData()),
    )).toMatchObject({status: 'in_progress', idempotentReplay: true});
    expect(await mutateDeviceRecoveryWithDb(args(claimed.db, TARGET, {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId: REQUEST,
      installationId: INSTALLATION,
      backupFileCount: 1,
      clearedCursorCount: 3,
      backedUpUnsyncedRows: 2,
    }))).toMatchObject({status: 'completed'});
  });

  test('missing selected installation fails without writing', async () => {
    const fixture = fakeDb(seed());
    await expect(mutateDeviceRecoveryWithDb(args(
      fixture.db,
      ADMIN,
      requestData({installationId: OTHER_INSTALLATION}),
    ))).rejects.toBeInstanceOf(DeviceRecoveryMutationError);
    expect(fixture.writes).toHaveLength(0);
  });
});
