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

function assetClass(overrides = {}) {
  return {
    schemaVersion: 1,
    assetClassId: IDS.class,
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
    ...overrides,
  };
}

function hierarchyNode(overrides = {}) {
  return {
    schemaVersion: 1,
    nodeId: 'burner-system',
    assetClassId: IDS.class,
    status: 'active',
    nodeType: 'component',
    version: 3,
    name: 'Burner system',
    hierarchyPath: ['Combustion system', 'Burner system'],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'I&A',
    accountableRoleKeys: ['seniorInstrumentation'],
    ...overrides,
  };
}

function componentReferenceJson(overrides = {}) {
  return JSON.stringify({
    schemaVersion: 4,
    scope: 'componentDefinitionOnAsset',
    assetClassId: IDS.class,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: 'burner-system',
    nodeVersion: 3,
    nodeName: 'Burner system',
    assetInstanceId: IDS.asset,
    assetInstanceVersion: 2,
    assetNumber: 7,
    assetInstanceName: 'Furnace 7',
    componentInstanceId: null,
    componentInstanceVersion: null,
    componentTag: null,
    hierarchyPath: ['Combustion system', 'Burner system'],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'I&A',
    accountableRoleKeys: ['seniorInstrumentation'],
    innerCoverAssociation: null,
    ...overrides,
  });
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
    basis: 'pendingMaintenance',
    componentHierarchyRefJson: componentReferenceJson(),
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
    [`asset_classes/${IDS.class}`]: assetClass(),
    'asset_hierarchy_nodes/burner-system': hierarchyNode(),
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
    const parsed = parseAssetOperationalConditionMutationRequest(declareRequest());
    expect(parsed)
      .toMatchObject({
        condition: 'down',
        causeKeys: ['breakdown'],
        basis: 'pendingMaintenance',
        requestContractVersion: 2,
      });
    expect(parsed.fingerprint).toMatch(/^assetcondition2-sha256:[0-9a-f]{64}$/);
    expect(() => parseAssetOperationalConditionMutationRequest({
      ...declareRequest(),
      surprise: true,
    })).toThrow('surprise is unsupported');
  });

  test('preserves the legacy request fingerprint and rejects a partial v2 shape', () => {
    const legacy = declareRequest();
    delete legacy.basis;
    delete legacy.componentHierarchyRefJson;
    const parsed = parseAssetOperationalConditionMutationRequest(legacy);
    expect(parsed).toMatchObject({
      requestContractVersion: 1,
      basis: null,
      componentHierarchyRefJson: null,
    });
    expect(parsed.fingerprint).toBe(
      'assetcondition1-sha256:ffe6759e1fa901412e21e1e5d6effed99e4058f72f356d237c11780de0af011e',
    );
    expect(() => parseAssetOperationalConditionMutationRequest({
      ...legacy,
      basis: 'pendingMaintenance',
    })).toThrow('basis and componentHierarchyRefJson must be supplied together');
  });

  test('a legacy declaration remains schema-1 compatible', async () => {
    const memory = fakeDb(baseSeed());
    const legacy = declareRequest();
    delete legacy.basis;
    delete legacy.componentHierarchyRefJson;
    await expect(invoke(memory, 'ops-1', legacy))
      .resolves.toMatchObject({condition: 'down', version: 1});
    expect(memory.store.get(`asset_operational_conditions/${IDS.asset}`))
      .toMatchObject({schemaVersion: 1, active: true, condition: 'down'});
    expect(memory.store.get(`asset_operational_conditions/${IDS.asset}`))
      .not.toHaveProperty('basis');
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
    const storedCondition = memory.store.get(
      `asset_operational_conditions/${IDS.asset}`,
    );
    expect(storedCondition).toMatchObject({
        schemaVersion: 2,
        active: true,
        condition: 'down',
        basis: 'pendingMaintenance',
        linkedIssueIds: ['issue-1'],
        declaredByUid: 'ops-1',
        version: 1,
      });
    expect(JSON.parse(storedCondition.componentHierarchyRefJson)).toMatchObject({
      nodeId: 'burner-system',
      assetInstanceId: IDS.asset,
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

  test('stale governed component evidence fails without writes', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(memory, 'ops-1', declareRequest({
      componentHierarchyRefJson: componentReferenceJson({nodeVersion: 2}),
    }))).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'asset-condition-component-definition-changed'},
    });
    expect(memory.writes).toHaveLength(0);
  });

  test('Inner Cover unavailability is Base-only and requires a vacant assignment', async () => {
    const base = {
      ...baseSeed(),
      [`asset_classes/${IDS.class}`]: assetClass({
        code: 'BASE',
        name: 'Base',
        legacyAssetTypeKey: 'base',
      }),
      [`asset_instances/${IDS.asset}`]: asset({
        assetClassCode: 'BASE',
        assetClassName: 'Base',
        name: 'Base 7',
      }),
    };
    const request = declareRequest({
      basis: 'innerCoverUnavailable',
      componentHierarchyRefJson: null,
    });
    await expect(invoke(fakeDb(base), 'ops-1', request))
      .resolves.toMatchObject({condition: 'down', version: 1});

    const linked = fakeDb({
      ...base,
      [`base_inner_cover_assignments/${IDS.asset}`]: {
        innerCoverSerialNumber: 'GR26',
      },
    });
    await expect(invoke(linked, 'ops-1', request))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {
          reasonCode: 'asset-condition-inner-cover-still-linked',
          innerCoverSerialNumber: 'GR26',
        },
      });
    expect(linked.writes).toHaveLength(0);
  });

  test('schema-3 physical asset issue remains valid condition evidence', async () => {
    const seed = baseSeed();
    seed['maintenance_records/issue-1'].assetHierarchyRefJson = JSON.stringify({
      schemaVersion: 3,
      scope: 'physicalAsset',
      assetInstanceId: IDS.asset,
      assetClassId: IDS.class,
      assetNumber: 7,
      innerCoverAssociation: {
        baseAssetInstanceId: IDS.asset,
        baseAssetNumber: 7,
        positionState: 'linked',
        innerCoverId: 'cover-gr26',
        innerCoverSerialNumber: 'GR26',
        linkageId: 'link-gr26-base-7',
        assignmentVersion: 3,
        linkedAt: '2026-08-01T10:00:00.000Z',
        eventAt: '2026-08-15T10:00:00.000Z',
        confirmedAt: '2026-08-15T10:01:00.000Z',
        confirmedByUid: 'ops-1',
        confirmedByName: 'Operations One',
      },
    });
    await expect(invoke(fakeDb(seed), 'ops-1', declareRequest()))
      .resolves.toMatchObject({condition: 'down', version: 1});
  });

  test('partial Inner Cover event evidence cannot support a declaration', async () => {
    const seed = baseSeed();
    seed['maintenance_records/issue-1'].assetHierarchyRefJson = JSON.stringify({
      schemaVersion: 3,
      scope: 'physicalAsset',
      assetInstanceId: IDS.asset,
      assetClassId: IDS.class,
      assetNumber: 7,
      innerCoverAssociation: {
        baseAssetInstanceId: IDS.asset,
        baseAssetNumber: 7,
        positionState: 'linked',
        innerCoverSerialNumber: 'GR26',
        eventAt: '2026-08-15T10:00:00.000Z',
        confirmedAt: '2026-08-15T10:01:00.000Z',
        confirmedByUid: 'ops-1',
        confirmedByName: 'Operations One',
      },
    });
    await expect(invoke(fakeDb(seed), 'ops-1', declareRequest()))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {
          reasonCode: 'asset-condition-linked-issue-inner-cover-malformed',
        },
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
