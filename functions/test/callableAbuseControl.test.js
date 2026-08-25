const {
  CALLABLE_ABUSE_CONTROL_COLLECTION,
  CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION,
  CALLABLE_ABUSE_POLICIES,
  CallableAbuseControlError,
  executeAuthorizedMutationWithAbuseControl,
  executeWithCallableAbuseControl,
} = require('../lib/callableAbuseControl');
const {
  CALLABLE_SECURITY_CLASSIFICATION,
} = require('../lib/callableInventory');

class MemoryFirestore {
  constructor() {
    this.documents = new Map();
    this.queue = Promise.resolve();
    this.documentReads = 0;
    this.transactionCalls = 0;
  }

  collection(name) {
    return {
      doc: (id) => {
        const path = `${name}/${id}`;
        return {
          id,
          path,
          get: async () => {
            this.documentReads += 1;
            const data = this.documents.get(path);
            return {
              exists: data != null,
              data: () => data == null ? undefined : structuredClone(data),
            };
          },
        };
      },
    };
  }

  async runTransaction(callback) {
    this.transactionCalls += 1;
    const previous = this.queue;
    let release;
    this.queue = new Promise((resolve) => {
      release = resolve;
    });
    await previous;

    const writes = new Map();
    const transaction = {
      get: async (ref) => {
        const data = writes.has(ref.path)
          ? writes.get(ref.path)
          : this.documents.get(ref.path);
        return {
          exists: data != null,
          data: () => data == null ? undefined : structuredClone(data),
        };
      },
      set: (ref, data) => {
        writes.set(ref.path, structuredClone(data));
      },
    };

    try {
      const result = await callback(transaction);
      for (const [path, data] of writes) {
        this.documents.set(path, data);
      }
      return result;
    } finally {
      release();
    }
  }

  abuseRecords() {
    const prefix = `${CALLABLE_ABUSE_CONTROL_COLLECTION}/`;
    return [...this.documents.entries()]
      .filter(([path]) => path.startsWith(prefix))
      .map(([path, data]) => ({
        id: path.slice(prefix.length),
        data: structuredClone(data),
      }));
  }

  seed(path, data) {
    this.documents.set(path, structuredClone(data));
  }
}

function clock(iso = '2026-07-26T00:00:00.000Z') {
  let nowMs = new Date(iso).getTime();
  return {
    now: () => new Date(nowMs),
    advanceSeconds: (seconds) => {
      nowMs += seconds * 1000;
    },
  };
}

function invoke({
  db,
  actorUid = 'approved-user',
  callableName = 'assignPublishedTemplateVersion',
  execute = async () => ({ok: true}),
  now,
}) {
  return executeWithCallableAbuseControl({
    db,
    actorUid,
    callableName,
    execute,
    now,
  });
}

describe('S-03 callable abuse control', () => {
  test('defines bounded policy for every and only mutating callable', () => {
    const mutatingCallables = Object.entries(
      CALLABLE_SECURITY_CLASSIFICATION,
    )
      .filter(([, kind]) => kind === 'mutating')
      .map(([name]) => name)
      .sort();
    expect(Object.keys(CALLABLE_ABUSE_POLICIES).sort())
      .toEqual(mutatingCallables);

    for (const policy of Object.values(CALLABLE_ABUSE_POLICIES)) {
      expect(policy.burstWindowSeconds).toBeGreaterThan(0);
      expect(policy.burstRequestLimit).toBeGreaterThan(0);
      expect(policy.dailyRequestLimit).toBeGreaterThan(
        policy.burstRequestLimit,
      );
      expect(policy.anomalyWindowSeconds).toBeGreaterThan(0);
      expect(policy.anomalyLimit).toBeGreaterThan(0);
      for (const value of Object.values(policy)) {
        expect(Number.isSafeInteger(value)).toBe(true);
      }
    }
  });

  test('stores one strict hashed-principal record after successful admission', async () => {
    const db = new MemoryFirestore();
    const timer = clock();

    await expect(invoke({
      db,
      actorUid: 'sensitive-raw-uid',
      now: timer.now,
    })).resolves.toEqual({ok: true});

    const records = db.abuseRecords();
    expect(records).toHaveLength(1);
    expect(records[0].id).toMatch(/^[0-9a-f]{64}$/);
    expect(records[0].id).not.toContain('sensitive-raw-uid');
    expect(JSON.stringify(records[0].data)).not.toContain('sensitive-raw-uid');
    expect(records[0].data).toMatchObject({
      schemaVersion: CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION,
      callableName: 'assignPublishedTemplateVersion',
      burstRequestCount: 1,
      dailyRequestCount: 1,
      anomalyCount: 0,
      blockedRequestCount: 0,
    });
    expect(Object.keys(records[0].data)).toHaveLength(14);
  });

  test('authentication and authority rejection perform no limiter transaction', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    const authorize = (data) => data.allowed === true;
    let executed = false;

    await expect(executeAuthorizedMutationWithAbuseControl({
      db,
      actorUid: null,
      callableName: 'mutateUserAuthority',
      authorize,
      now: timer.now,
      execute: async () => {
        executed = true;
      },
    })).rejects.toMatchObject({
      code: 'unauthenticated',
      details: {reasonCode: 'callable-preflight-unauthenticated'},
    });
    expect(db.documentReads).toBe(0);
    expect(db.transactionCalls).toBe(0);

    db.seed('users/denied-user', {allowed: false});
    await expect(executeAuthorizedMutationWithAbuseControl({
      db,
      actorUid: 'denied-user',
      callableName: 'mutateUserAuthority',
      authorize,
      now: timer.now,
      execute: async () => {
        executed = true;
      },
    })).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'callable-preflight-authority-denied'},
    });
    expect(db.documentReads).toBe(1);
    expect(db.transactionCalls).toBe(0);
    expect(db.abuseRecords()).toHaveLength(0);
    expect(executed).toBe(false);
  });

  test('authorized boundary admission executes through the shared quota', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    db.seed('users/approved-user', {allowed: true});

    await expect(executeAuthorizedMutationWithAbuseControl({
      db,
      actorUid: 'approved-user',
      callableName: 'completePlannedJobExecution',
      authorize: (data) => data.allowed === true,
      now: timer.now,
      execute: async () => ({ok: true}),
    })).resolves.toEqual({ok: true});

    expect(db.documentReads).toBe(1);
    expect(db.transactionCalls).toBe(1);
    expect(db.abuseRecords()).toHaveLength(1);
  });

  test('asynchronous authority evidence is resolved before limiter admission', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    db.seed('users/recovery-user', {allowed: false});
    let executed = false;

    await expect(executeAuthorizedMutationWithAbuseControl({
      db,
      actorUid: 'recovery-user',
      callableName: 'mutateAssetHierarchy',
      authorize: async () => false,
      now: timer.now,
      execute: async () => {
        executed = true;
      },
    })).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'callable-preflight-authority-denied'},
    });
    expect(db.transactionCalls).toBe(0);
    expect(db.abuseRecords()).toHaveLength(0);
    expect(executed).toBe(false);

    await expect(executeAuthorizedMutationWithAbuseControl({
      db,
      actorUid: 'recovery-user',
      callableName: 'mutateAssetHierarchy',
      authorize: async () => true,
      now: timer.now,
      execute: async () => ({ok: true}),
    })).resolves.toEqual({ok: true});
    expect(db.transactionCalls).toBe(1);
    expect(db.abuseRecords()).toHaveLength(1);
  });

  test('atomically admits only the configured burst limit under concurrency', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    const callableName = 'assignPublishedTemplateVersion';
    const limit = CALLABLE_ABUSE_POLICIES[callableName].burstRequestLimit;
    let executions = 0;

    const results = await Promise.allSettled(
      Array.from({length: limit + 5}, () => invoke({
        db,
        callableName,
        now: timer.now,
        execute: async () => {
          executions += 1;
          return {ok: true};
        },
      })),
    );

    expect(results.filter(({status}) => status === 'fulfilled')).toHaveLength(
      limit,
    );
    const rejected = results.filter(({status}) => status === 'rejected');
    expect(rejected).toHaveLength(5);
    expect(rejected.every(({reason}) =>
      reason instanceof CallableAbuseControlError &&
      reason.code === 'resource-exhausted' &&
      reason.details.reasonCode === 'callable-burst-limit-exceeded'
    )).toBe(true);
    expect(executions).toBe(limit);
    expect(db.abuseRecords()[0].data).toMatchObject({
      burstRequestCount: limit + 5,
      dailyRequestCount: limit + 5,
      blockedRequestCount: 5,
    });
  });

  test('resets the burst window and returns stable retry metadata', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    const callableName = 'completePlannedJobExecution';
    const policy = CALLABLE_ABUSE_POLICIES[callableName];

    for (let index = 0; index < policy.burstRequestLimit; index += 1) {
      await invoke({db, callableName, now: timer.now});
    }
    await expect(invoke({db, callableName, now: timer.now})).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: {
        reasonCode: 'callable-burst-limit-exceeded',
        callableName,
        retryAfterSeconds: policy.burstWindowSeconds,
      },
    });

    timer.advanceSeconds(policy.burstWindowSeconds);
    await expect(invoke({db, callableName, now: timer.now})).resolves.toEqual({
      ok: true,
    });
    expect(db.abuseRecords()[0].data.burstRequestCount).toBe(1);
  });

  test('enforces the daily quota even when every burst window has reset', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    const callableName = 'mutateUserAuthority';
    const policy = CALLABLE_ABUSE_POLICIES[callableName];

    for (let index = 0; index < policy.dailyRequestLimit; index += 1) {
      await invoke({db, callableName, now: timer.now});
      timer.advanceSeconds(policy.burstWindowSeconds);
    }
    await expect(invoke({db, callableName, now: timer.now})).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: {reasonCode: 'callable-daily-limit-exceeded'},
    });
  });

  test('counts stable caller-caused failures and blocks at the anomaly quota', async () => {
    const db = new MemoryFirestore();
    const timer = clock();
    const callableName = 'assignPublishedTemplateVersion';
    const policy = CALLABLE_ABUSE_POLICIES[callableName];
    let executions = 0;
    const rejectedOperation = async () => {
      executions += 1;
      throw Object.assign(new Error('invalid request'), {
        code: 'invalid-argument',
      });
    };

    for (let index = 0; index < policy.anomalyLimit; index += 1) {
      await expect(invoke({
        db,
        callableName,
        execute: rejectedOperation,
        now: timer.now,
      })).rejects.toMatchObject({code: 'invalid-argument'});
      timer.advanceSeconds(policy.burstWindowSeconds);
    }

    await expect(invoke({
      db,
      callableName,
      execute: rejectedOperation,
      now: timer.now,
    })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: {reasonCode: 'callable-anomaly-limit-exceeded'},
    });
    expect(executions).toBe(policy.anomalyLimit);
    expect(db.abuseRecords()[0].data).toMatchObject({
      anomalyCount: policy.anomalyLimit,
      lastAnomalyCode: 'invalid-argument',
      blockedRequestCount: 1,
    });
  });

  test('does not classify server failures or transaction aborts as caller anomalies', async () => {
    const db = new MemoryFirestore();
    const timer = clock();

    for (const code of ['internal', 'unavailable', 'data-loss', 'aborted']) {
      await expect(invoke({
        db,
        now: timer.now,
        execute: async () => {
          throw Object.assign(new Error(code), {code});
        },
      })).rejects.toMatchObject({code});
      timer.advanceSeconds(61);
    }

    expect(db.abuseRecords()[0].data.anomalyCount).toBe(0);
  });

  test('fails closed on partial, unknown-field, negative, or future state', async () => {
    const cases = [
      (state) => {
        delete state.dailyRequestCount;
      },
      (state) => {
        state.unexpected = true;
      },
      (state) => {
        state.anomalyCount = -1;
      },
      (state) => {
        state.burstWindowStartedAtMs += 60_000;
      },
    ];

    for (const corrupt of cases) {
      const db = new MemoryFirestore();
      const timer = clock();
      await invoke({db, now: timer.now});
      const [record] = db.abuseRecords();
      corrupt(record.data);
      db.documents.set(
        `${CALLABLE_ABUSE_CONTROL_COLLECTION}/${record.id}`,
        record.data,
      );
      let executed = false;

      await expect(invoke({
        db,
        now: timer.now,
        execute: async () => {
          executed = true;
          return {ok: true};
        },
      })).rejects.toMatchObject({code: 'internal'});
      expect(executed).toBe(false);
    }
  });

  test('separates quota state by actor and callable', async () => {
    const db = new MemoryFirestore();
    const timer = clock();

    await invoke({db, actorUid: 'actor-a', now: timer.now});
    await invoke({db, actorUid: 'actor-b', now: timer.now});
    await invoke({
      db,
      actorUid: 'actor-a',
      callableName: 'mutateUserAuthority',
      now: timer.now,
    });

    expect(db.abuseRecords()).toHaveLength(3);
    expect(new Set(db.abuseRecords().map(({id}) => id)).size).toBe(3);
  });
});
