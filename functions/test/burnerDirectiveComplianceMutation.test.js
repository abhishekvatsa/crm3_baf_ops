'use strict';

const {
  mutateBurnerDirectiveComplianceWithDb,
  parseBurnerDirectiveComplianceRequest,
  userCanCompleteBurnerDirective,
} = require('../lib/burnerDirectiveComplianceMutation');

const clone = (value) => value == null ? value : structuredClone(value);

function fakeDb(seed = {}, options = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];
  const outsideReads = [];
  const transactionReads = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() {
        outsideReads.push(path);
        const value = snapshot(path, id);
        options.afterOutsideGet?.({path, store});
        return value;
      },
    };
  }

  function collection(name) {
    return {
      doc(id) { return ref(name, id); },
      where(field, op, value) {
        const query = {
          kind: 'query',
          name,
          field,
          op,
          value,
          orderField: null,
          direction: null,
          maximum: null,
          where() { throw new Error('unsupported chained where'); },
          orderBy(orderField, direction) {
            query.orderField = orderField;
            query.direction = direction;
            return query;
          },
          limit(maximum) {
            query.maximum = maximum;
            return query;
          },
        };
        return query;
      },
    };
  }

  return {
    store,
    writes,
    outsideReads,
    transactionReads,
    db: {
      collection,
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(target) {
            transactionReads.push(target.kind === 'query'
              ? `${target.name}:query`
              : target.path);
            if (target.kind === 'query') {
              if (target.op !== '==') throw new Error('unsupported fake query');
              const docs = [];
              for (const [path, value] of store.entries()) {
                const prefix = `${target.name}/`;
                if (!path.startsWith(prefix) || value[target.field] !== target.value) {
                  continue;
                }
                docs.push(snapshot(path, path.slice(prefix.length)));
              }
              if (target.orderField != null) {
                docs.sort((left, right) => {
                  const leftValue = left.data()[target.orderField];
                  const rightValue = right.data()[target.orderField];
                  const order = String(leftValue).localeCompare(String(rightValue));
                  return target.direction === 'desc' ? -order : order;
                });
              }
              if (target.maximum != null) docs.splice(target.maximum);
              return {docs};
            }
            return snapshot(target.path, target.id);
          },
          set(target, data, options) {
            staged.push({
              path: target.path,
              data: clone(data),
              merge: options?.merge === true,
            });
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          const next = write.merge ? {
            ...(store.get(write.path) ?? {}),
            ...write.data,
          } : write.data;
          store.set(write.path, clone(next));
          writes.push(write);
        }
        return result;
      },
    },
  };
}

const IDS = {
  source: '11111111-1111-4111-8111-111111111111',
  closure: '22222222-2222-4222-8222-222222222222',
  newer: '33333333-3333-4333-8333-333333333333',
  asset: '44444444-4444-4444-8444-444444444444',
  class: '55555555-5555-4555-8555-555555555555',
};

const directiveId = `burner_round_red_hot_${IDS.source}`;

function observations(redHot = [3]) {
  return Array.from({length: 8}, (_, index) => ({
    position: index + 1,
    flameObservation: 'seen',
    redHotObserved: redHot.includes(index + 1),
    microampReading: index === 0 ? 3.4 : null,
    remarks: null,
  }));
}

function uvObservations() {
  return Array.from({length: 8}, (_, index) => ({
    position: index + 1,
    condition: 'serviceable',
    remarks: null,
  }));
}

function round(id = IDS.source, observedAt = '2026-08-28T10:00:00.000Z', redHot = [3]) {
  return {
    schemaVersion: 2,
    roundId: id,
    operation: 'RECORD_BURNER_CONDITION_ROUND',
    assetClassId: IDS.class,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetInstanceId: IDS.asset,
    assetInstanceVersion: 4,
    assetNumber: 7,
    assetName: 'Furnace 7',
    observations: observations(redHot),
    redHotPositions: redHot,
    microampPositions: [1],
    draftSealRedHotObserved: false,
    hotAirAtDraftSealObserved: false,
    uvObservations: uvObservations(),
    directivePositions: redHot,
    roundNote: 'Audit',
    observedAt,
    recordedByUid: 'operations-1',
    recordedByName: 'Operations One',
    directiveId: `burner_round_red_hot_${id}`,
    fingerprint: `burnerround2-sha256:${'a'.repeat(64)}`,
  };
}

function directive(overrides = {}) {
  return {
    firestoreId: directiveId,
    assetType: 'furnace',
    assetNumber: 7,
    component: 'Burner block',
    subsystem: 'Burner system',
    directedTo: 'seniorInstrumentation',
    status: 'acknowledged',
    isActive: true,
    acknowledgedByUid: 'actor-1',
    createdByUid: 'operations-1',
    issuedByUid: 'operations-1',
    isDeleted: false,
    version: 1,
    metadataJson: JSON.stringify({
      schemaVersion: 1,
      trigger: 'burnerConditionRoundRedHot',
      sourceRoundId: IDS.source,
      burnerPositions: [3],
      automaticPlantActuation: false,
    }),
    ...overrides,
  };
}

function seed(overrides = {}) {
  return {
    'users/actor-1': {
      isApproved: true,
      roles: ['seniorInstrumentation'],
      name: 'I&A One',
    },
    [`asset_classes/${IDS.class}`]: {
      schemaVersion: 1,
      assetClassId: IDS.class,
      code: 'FURNACE',
      name: 'Furnace',
      legacyAssetTypeKey: 'furnace',
      status: 'active',
    },
    [`asset_instances/${IDS.asset}`]: {
      schemaVersion: 1,
      assetInstanceId: IDS.asset,
      assetClassId: IDS.class,
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      assetNumber: 7,
      name: 'Furnace 7',
      status: 'active',
      serviceState: 'inService',
      version: 4,
    },
    [`burner_condition_rounds/${IDS.source}`]: round(),
    [`directives/${directiveId}`]: directive(),
    ...overrides,
  };
}

function request(overrides = {}) {
  return {
    requestId: IDS.closure,
    operation: 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
    assetClassId: IDS.class,
    assetInstanceId: IDS.asset,
    expectedAssetVersion: 4,
    expectedCurrentRoundId: IDS.source,
    directiveId,
    expectedDirectiveVersion: 1,
    dispositions: [{position: 3, disposition: 'restoredInService'}],
    closureRemarks: 'Burner block corrected and UV returned to service.',
    ...overrides,
  };
}

async function invoke(memory, data = request()) {
  return mutateBurnerDirectiveComplianceWithDb({
    db: memory.db,
    authUid: 'actor-1',
    data,
    now: () => new Date('2026-08-28T11:00:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('burner directive compliance mutation', () => {
  test('parses exact canonical dispositions and rejects partial identity', () => {
    expect(parseBurnerDirectiveComplianceRequest(request()).dispositions)
      .toEqual([{position: 3, disposition: 'restoredInService'}]);
    expect(() => parseBurnerDirectiveComplianceRequest(request({
      dispositions: [],
    }))).toThrow('one to eight');
  });

  test('authority admits I&A but rejects unrelated maintenance roles', () => {
    expect(userCanCompleteBurnerDirective({
      isApproved: true,
      roles: ['seniorInstrumentation'],
    })).toBe(true);
    expect(userCanCompleteBurnerDirective({
      isApproved: true,
      roles: ['seniorMechanical'],
    })).toBe(false);
  });

  test('revalidates authority before every transactional business read', async () => {
    const memory = fakeDb(seed(), {
      afterOutsideGet({path, store}) {
        if (path === 'users/actor-1') {
          store.set(path, {
            isApproved: false,
            roles: ['seniorInstrumentation'],
            name: 'I&A One',
          });
        }
      },
    });

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'burner-directive-compliance-role-denied'},
    });
    expect(memory.outsideReads).toEqual(['users/actor-1']);
    expect(memory.transactionReads).toEqual(['users/actor-1']);
    expect(memory.writes).toHaveLength(0);
  });

  test('atomically records compliance and closes the bound directive', async () => {
    const memory = fakeDb(seed());
    const result = await invoke(memory);
    const closed = memory.store.get(`directives/${directiveId}`);
    const recorded = memory.store.get(
      `burner_condition_rounds/${IDS.closure}`,
    );

    expect(result).toMatchObject({
      roundId: IDS.closure,
      closedDirectiveId: directiveId,
      closedDirectiveVersion: 2,
      newDirectiveId: null,
      idempotentReplay: false,
    });
    expect(closed).toMatchObject({
      status: 'closed',
      isActive: false,
      closedByUid: 'actor-1',
      version: 2,
    });
    expect(recorded).toMatchObject({
      operation: 'RECORD_BURNER_CONDITION_ROUND',
      redHotPositions: [],
      directivePositions: [],
      directiveId: null,
    });
    expect(recorded.observations[2]).toMatchObject({
      redHotObserved: false,
      flameObservation: 'seen',
    });
    expect(memory.store.get(`burner_condition_current/${IDS.asset}`))
      .toMatchObject({
        schemaVersion: 1,
        roundId: IDS.closure,
      });
  });

  test('rejects a stale projection from the serialized current pointer', async () => {
    const memory = fakeDb(seed({
      [`burner_condition_rounds/${IDS.newer}`]: round(
        IDS.newer,
        '2026-08-28T10:30:00.000Z',
        [3, 4],
      ),
      [`burner_condition_current/${IDS.asset}`]: {
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        roundId: IDS.newer,
        observedAt: new Date('2026-08-28T10:30:00.000Z'),
        updatedAt: new Date('2026-08-28T10:30:00.000Z'),
      },
    }));

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'aborted',
      details: {
        reasonCode: 'burner-directive-compliance-current-round-mismatch',
        currentRoundId: IDS.newer,
      },
    });
  });

  test('rejects a stale projection when a newer round is authoritative', async () => {
    const memory = fakeDb(seed({
      [`burner_condition_rounds/${IDS.newer}`]: round(
        IDS.newer,
        '2026-08-28T10:30:00.000Z',
        [3, 4],
      ),
    }));

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'aborted',
      details: {
        reasonCode: 'burner-directive-compliance-current-round-mismatch',
        currentRoundId: IDS.newer,
      },
    });
    expect(memory.store.get(`directives/${directiveId}`).status)
      .toBe('acknowledged');
    expect(memory.store.has(`burner_condition_rounds/${IDS.closure}`))
      .toBe(false);
  });

  test('retains other red-hot evidence through a successor directive', async () => {
    const memory = fakeDb(seed({
      [`burner_condition_rounds/${IDS.newer}`]: round(
        IDS.newer,
        '2026-08-28T10:30:00.000Z',
        [3, 4],
      ),
    }));
    const result = await invoke(memory, request({
      expectedCurrentRoundId: IDS.newer,
    }));
    const successorId = `burner_round_red_hot_${IDS.closure}`;

    expect(result.newDirectiveId).toBe(successorId);
    expect(memory.store.get(`directives/${successorId}`)).toMatchObject({
      status: 'open',
      assetNumber: 7,
      directedTo: 'seniorInstrumentation',
    });
    expect(JSON.parse(
      memory.store.get(`directives/${successorId}`).metadataJson,
    ).burnerPositions).toEqual([4]);
  });

  test('exact replay is write-free and validates retained evidence', async () => {
    const memory = fakeDb(seed());
    const first = await invoke(memory);
    const writes = memory.writes.length;
    const replay = await invoke(memory);

    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writes);
  });

  test('exact replay fails closed when retained compliance evidence drifts', async () => {
    const memory = fakeDb(seed());
    await invoke(memory);
    const path = `burner_condition_rounds/${IDS.closure}`;
    memory.store.get(path).recordedByUid = 'different-user';

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'data-loss',
      details: {
        reasonCode: 'burner-directive-compliance-replay-evidence-drift',
      },
    });
  });
});
