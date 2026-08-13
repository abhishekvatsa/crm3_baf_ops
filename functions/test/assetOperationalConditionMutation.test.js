const {
  mutateAssetOperationalConditionWithDb,
  parseAssetOperationalConditionMutationRequest,
  userCanMutateAssetOperationalCondition,
} = require('../lib/assetOperationalConditionMutation');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {
      exists: value != null,
      id,
      data: () => clone(value),
    };
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() {
        return snapshot(path, id);
      },
    };
  }

  return {
    store,
    writes,
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); }};
      },
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(documentRef) {
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({path: documentRef.path, data: clone(data)});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
      },
    },
  };
}

const IDS = {
  asset: '11111111-1111-4111-8111-111111111111',
  class: '22222222-2222-4222-8222-222222222222',
  declare: '33333333-3333-4333-8333-333333333333',
  restore: '44444444-4444-4444-8444-444444444444',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function asset(overrides = {}) {
  return {
    schemaVersion: 1,
    assetInstanceId: IDS.asset,
    assetClassId: IDS.class,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 7,
    name: 'Furnace 7',
    status: 'active',
    serviceState: 'inService',
    version: 2,
    ...overrides,
  };
}

function issueReference(assetInstanceId = IDS.asset) {
  return JSON.stringify({
    schemaVersion: 2,
    scope: 'installedComponent',
    assetInstanceId,
    assetClassId: IDS.class,
    assetNumber: 7,
  });
}

function declareRequest(overrides = {}) {
  return {
    requestId: IDS.declare,
    operation: 'DECLARE_ASSET_CONDITION',
    assetClassId: IDS.class,
    assetInstanceId: IDS.asset,
    expectedVersion: 0,
    condition: 'down',
    causeKeys: ['breakdown'],
    reason: 'Drive fault prevents safe operation.',
    linkedIssueIds: ['issue-1'],
    ...overrides,
  };
}

function persistedCondition(overrides = {}) {
  return {
    schemaVersion: 1,
    assetInstanceId: IDS.asset,
    assetClassId: IDS.class,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 7,
    assetName: 'Furnace 7',
    condition: 'down',
    active: true,
    causeKeys: ['breakdown'],
    reason: 'Drive fault prevents safe operation.',
    linkedIssueIds: ['issue-1'],
    declaredAt: new Date('2026-08-14T11:00:00.000Z'),
    declaredByUid: 'ops-1',
    declaredByName: 'Operations One',
    restoredAt: null,
    restoredByUid: null,
    restoredByName: null,
    previousCondition: 'available',
    version: 1,
    updatedAt: new Date('2026-08-14T11:00:00.000Z'),
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    lastMutationId: 'prior-mutation',
    ...overrides,
  };
}

function baseSeed() {
  return {
    'users/ops-1': user('operations', 'Operations One'),
    'users/shift-1': user('shiftSupervisor', 'Shift Supervisor'),
    'users/contract-1': user('contractSupervisor', 'Contract Supervisor'),
    [`asset_instances/${IDS.asset}`]: asset(),
    'maintenance_records/issue-1': {
      isDeleted: false,
      isResolved: false,
      assetHierarchyRefJson: issueReference(),
    },
  };
}

async function invoke(memory, authUid, data) {
  return mutateAssetOperationalConditionWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => new Date('2026-08-14T12:00:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('asset operational condition mutation', () => {
  test('parses a bounded declaration and rejects unknown request fields', () => {
    expect(parseAssetOperationalConditionMutationRequest(declareRequest()))
      .toMatchObject({condition: 'down', causeKeys: ['breakdown']});
    expect(() => parseAssetOperationalConditionMutationRequest({
      ...declareRequest(),
      surprise: true,
    })).toThrow('surprise is unsupported');
  });

  test('authority distinguishes declaration from restoration', () => {
    expect(userCanMutateAssetOperationalCondition(
      user('operations'),
      'DECLARE_ASSET_CONDITION',
    )).toBe(true);
    expect(userCanMutateAssetOperationalCondition(
      user('operations'),
      'RESTORE_ASSET_CONDITION',
    )).toBe(false);
    expect(userCanMutateAssetOperationalCondition(
      user('shiftSupervisor'),
      'RESTORE_ASSET_CONDITION',
    )).toBe(true);
    expect(userCanMutateAssetOperationalCondition(
      user('contractSupervisor'),
      'DECLARE_ASSET_CONDITION',
    )).toBe(false);
  });

  test('Operations declares a linked asset down and exact replay is write-free', async () => {
    const memory = fakeDb(baseSeed());
    const first = await invoke(memory, 'ops-1', declareRequest());
    const writesAfterFirst = memory.writes.length;
    const replay = await invoke(memory, 'ops-1', declareRequest());

    expect(first).toMatchObject({
      condition: 'down',
      version: 1,
      idempotentReplay: false,
    });
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writesAfterFirst);
    expect(memory.store.get(`asset_operational_conditions/${IDS.asset}`))
      .toMatchObject({
        active: true,
        condition: 'down',
        linkedIssueIds: ['issue-1'],
        declaredByUid: 'ops-1',
        version: 1,
      });
  });

  test('linked issue must carry the same governed asset identity', async () => {
    const seed = baseSeed();
    seed['maintenance_records/issue-1'].assetHierarchyRefJson =
      issueReference('different-asset');
    await expect(invoke(fakeDb(seed), 'ops-1', declareRequest()))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'asset-condition-linked-issue-asset-mismatch'},
      });
  });

  test('linked issue must remain open with complete lifecycle state', async () => {
    for (const [override, reasonCode] of [
      [{isResolved: true}, 'asset-condition-linked-issue-resolved'],
      [{isDeleted: true}, 'asset-condition-linked-issue-deleted'],
      [{isResolved: undefined}, 'asset-condition-linked-issue-lifecycle-malformed'],
      [{isDeleted: 'false'}, 'asset-condition-linked-issue-lifecycle-malformed'],
    ]) {
      const seed = baseSeed();
      seed['maintenance_records/issue-1'] = {
        ...seed['maintenance_records/issue-1'],
        ...override,
      };
      const memory = fakeDb(seed);
      await expect(invoke(memory, 'ops-1', declareRequest()))
        .rejects.toMatchObject({
          code: 'failed-precondition',
          details: {reasonCode},
        });
      expect(memory.writes).toHaveLength(0);
    }
  });

  test('stale declaration fails without writes', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`asset_operational_conditions/${IDS.asset}`]: persistedCondition({
        version: 2,
      }),
    });
    await expect(invoke(memory, 'ops-1', declareRequest({expectedVersion: 1})))
      .rejects.toMatchObject({
        code: 'aborted',
        details: {reasonCode: 'asset-condition-version-mismatch'},
      });
    expect(memory.writes).toHaveLength(0);
  });

  test('orphan audit fails closed instead of being overwritten', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`asset_operational_condition_audits/asset_condition_${IDS.declare}`]: {
        requestId: IDS.declare,
      },
    });
    await expect(invoke(memory, 'ops-1', declareRequest()))
      .rejects.toMatchObject({
        code: 'data-loss',
        details: {reasonCode: 'asset-condition-orphan-audit'},
      });
    expect(memory.writes).toHaveLength(0);
  });

  test('partial existing condition fails closed instead of being overwritten', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`asset_operational_conditions/${IDS.asset}`]: {
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        assetClassId: IDS.class,
        condition: 'down',
        active: true,
        version: 1,
      },
    });
    await expect(invoke(memory, 'ops-1', declareRequest({expectedVersion: 1})))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'asset-condition-projection-malformed'},
      });
    expect(memory.writes).toHaveLength(0);
  });

  test('Operations cannot restore; Shift Supervisor restores active condition', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'ops-1', declareRequest());
    const restore = {
      requestId: IDS.restore,
      operation: 'RESTORE_ASSET_CONDITION',
      assetClassId: IDS.class,
      assetInstanceId: IDS.asset,
      expectedVersion: 1,
      reason: 'Operations proved safe readiness after repair.',
    };
    await expect(invoke(memory, 'ops-1', restore))
      .rejects.toMatchObject({code: 'permission-denied'});
    const result = await invoke(memory, 'shift-1', restore);
    expect(result).toMatchObject({condition: 'available', version: 2});
    expect(memory.store.get(`asset_operational_conditions/${IDS.asset}`))
      .toMatchObject({
        active: false,
        condition: 'available',
        restoredByUid: 'shift-1',
        version: 2,
      });
  });

  test('retired and administratively out-of-service assets reject declarations', async () => {
    for (const override of [
      {status: 'retired'},
      {serviceState: 'outOfService'},
    ]) {
      const memory = fakeDb({
        ...baseSeed(),
        [`asset_instances/${IDS.asset}`]: asset(override),
      });
      await expect(invoke(memory, 'ops-1', declareRequest()))
        .rejects.toMatchObject({code: 'failed-precondition'});
      expect(memory.writes).toHaveLength(0);
    }
  });

  test('active condition can be closed after the asset becomes out of service', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      [`asset_instances/${IDS.asset}`]: asset({serviceState: 'outOfService'}),
      [`asset_operational_conditions/${IDS.asset}`]: persistedCondition(),
    });
    const result = await invoke(memory, 'shift-1', {
      requestId: IDS.restore,
      operation: 'RESTORE_ASSET_CONDITION',
      assetClassId: IDS.class,
      assetInstanceId: IDS.asset,
      expectedVersion: 1,
      reason: 'Operational condition closed under out-of-service custody.',
    });
    expect(result).toMatchObject({condition: 'available', version: 2});
  });
});
