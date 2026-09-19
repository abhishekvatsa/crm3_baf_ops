'use strict';

const {
  mutateBurnerDirectiveComplianceWithDb,
  parseBurnerDirectiveComplianceRequest,
  userCanCompleteBurnerDirective,
} = require('../lib/burnerDirectiveComplianceMutation');
const {mutateBurnerConditionRoundWithDb} = require('../lib/burnerConditionRoundMutation');

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
      version: 1,
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
  test.each(Array.from({length: 8}, (_, index) => index + 1).flatMap((position) =>
    ['restoredInService', 'uvMelted', 'uvMissing', 'uvHungRemoved']
      .map((disposition) => [position, disposition])))(
    'B%i %s recovers after a genuine later-clear survey and another later round',
    async (position, disposition) => {
      const memory = fakeDb(seed());
      memory.store.delete(`burner_condition_rounds/${IDS.source}`);
      memory.store.delete(`directives/${directiveId}`);
      const survey = (id, redHot, instant) => mutateBurnerConditionRoundWithDb({
        db: memory.db, authUid: 'actor-1',
        data: {requestId: id, operation: 'RECORD_BURNER_CONDITION_ROUND',
          assetClassId: IDS.class, assetInstanceId: IDS.asset, expectedAssetVersion: 4,
          observations: observations(redHot), uvObservations: uvObservations(),
          draftSealRedHotObserved: false, hotAirAtDraftSealObserved: false},
        now: () => new Date(instant), timestampFromDate: (date) => date,
      });
      await survey(IDS.source, [position], '2026-08-28T09:00:00.000Z');
      await survey(IDS.newer, [], '2026-08-28T10:00:00.000Z');
      const command = request({expectedCurrentRoundId: IDS.newer,
        dispositions: [{position, disposition}]});
      const accepted = await invoke(memory, command);
      const acceptedRound = memory.store.get(`burner_condition_rounds/${IDS.closure}`);
      expect(acceptedRound.observations[position - 1].redHotObserved).toBe(false);
      const writes = memory.writes.length;
      expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
      expect(memory.writes).toHaveLength(writes);
      await survey('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', [], '2026-08-28T12:00:00.000Z');
      const afterLater = memory.writes.length;
      expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
      expect(memory.writes).toHaveLength(afterLater);
    },
  );

  test('compliance keeps untouched measurement and UV ages from the actual latest round', async () => {
    const current = round(IDS.newer, '2026-08-28T10:30:00.000Z');
    current.uvObservations[1].condition = 'melted';
    const memory = fakeDb(seed({[`burner_condition_rounds/${IDS.newer}`]: current}));
    await invoke(memory, request({expectedCurrentRoundId: IDS.newer}));
    const result = memory.store.get(`burner_condition_rounds/${IDS.closure}`);
    expect(result).toMatchObject({evidenceKind: 'directiveCompliance', baselineRoundId: IDS.newer});
    expect(result.evidenceProvenance['uv.2.condition']).toEqual({
      kind: 'inherited', sourceRoundId: IDS.newer,
      observedAt: '2026-08-28T10:30:00.000Z',
      observerUid: 'operations-1', observerName: 'Operations One',
    });
    expect(result.evidenceProvenance['burners.1.microampReading'])
      .toMatchObject({kind: 'inherited', sourceRoundId: IDS.newer,
        observedAt: '2026-08-28T10:30:00.000Z'});
    expect(result.evidenceProvenance['burners.3.redHotObserved'])
      .toMatchObject({kind: 'directiveDisposition', sourceRoundId: IDS.closure});
    expect(current.uvObservations[1].condition).toBe('melted');
  });

  test.each(['uvMelted', 'uvMissing', 'uvHungRemoved'])(
    'legacy accepted later-clear %s remains recoverable from its retained baseline',
    async (disposition) => {
      const memory = fakeDb(seed({[`burner_condition_rounds/${IDS.newer}`]:
        round(IDS.newer, '2026-08-28T10:30:00.000Z', [])}));
      const command = request({expectedCurrentRoundId: IDS.newer,
        dispositions: [{position: 3, disposition}]});
      const accepted = await invoke(memory, command);
      const stored = memory.store.get(`burner_condition_rounds/${IDS.closure}`);
      for (const key of ['evidenceKind', 'evidenceProvenance', 'baselineRoundId']) delete stored[key];
      const receipt = memory.store.get(`burner_condition_round_receipts/${IDS.closure}`);
      for (const key of ['evidenceVersion', 'roundEvidenceSha256', 'baselineRoundId',
        'baselineEvidenceSha256', 'sourceRoundEvidenceSha256']) delete receipt[key];
      const writes = memory.writes.length;
      expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
      expect(memory.writes).toHaveLength(writes);
    },
  );

  test.each(['microamp', 'flame', 'seal', 'observer', 'baseline', 'missingBaseline', 'downgrade'])(
    'replay rejects valid-shaped %s changes to accepted inherited evidence', async (tamper) => {
      const memory = fakeDb(seed());
      await invoke(memory);
      const stored = memory.store.get(`burner_condition_rounds/${IDS.closure}`);
      if (tamper === 'microamp') stored.observations[0].microampReading = 9.2;
      if (tamper === 'flame') stored.observations[0].flameObservation = 'notSeen';
      if (tamper === 'seal') stored.hotAirAtDraftSealObserved = true;
      if (tamper === 'observer') stored.recordedByName = 'Someone Else';
      if (tamper === 'baseline') {
        memory.store.get(`burner_condition_rounds/${IDS.source}`).observations[0].microampReading = 9.2;
        stored.observations[0].microampReading = 9.2;
      }
      if (tamper === 'missingBaseline') memory.store.delete(`burner_condition_rounds/${IDS.source}`);
      if (tamper === 'downgrade') {
        const receipt = memory.store.get(`burner_condition_round_receipts/${IDS.closure}`);
        delete receipt.evidenceVersion;
        delete receipt.roundEvidenceSha256;
      }
      const writes = memory.writes.length;
      await expect(invoke(memory)).rejects.toMatchObject({code: 'data-loss',
        details: {reasonCode: 'burner-directive-compliance-replay-evidence-drift'}});
      expect(memory.writes).toHaveLength(writes);
    },
  );

  test('same Furnace descriptive rename preserves source history and exact replay', async () => {
    const current = {...round(IDS.newer, '2026-08-28T10:30:00.000Z'),
      assetName: 'Heating Furnace Seven', assetInstanceVersion: 5};
    const memory = fakeDb(seed({[`burner_condition_rounds/${IDS.newer}`]: current}));
    Object.assign(memory.store.get(`asset_instances/${IDS.asset}`), {
      name: 'Heating Furnace Seven', version: 5,
    });
    const command = request({expectedAssetVersion: 5, expectedCurrentRoundId: IDS.newer});
    const accepted = await invoke(memory, command);
    expect(memory.store.get(`burner_condition_rounds/${IDS.source}`).assetName).toBe('Furnace 7');
    expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
  });

  test('replay tolerates supported timestamp representations without weakening content binding', async () => {
    const memory = fakeDb(seed());
    const accepted = await invoke(memory);
    const stored = memory.store.get(`burner_condition_rounds/${IDS.closure}`);
    stored.observedAt = stored.observedAt.toISOString();
    for (const entry of Object.values(stored.evidenceProvenance)) {
      if (entry.observedAt != null) entry.observedAt = new Date(entry.observedAt);
    }
    const source = memory.store.get(`burner_condition_rounds/${IDS.source}`);
    source.observedAt = new Date(source.observedAt);
    expect(await invoke(memory)).toEqual({...accepted, idempotentReplay: true});
  });

  test('a physical Furnace number conflict is still refused after a descriptive rename', async () => {
    const memory = fakeDb(seed());
    memory.store.get(`burner_condition_rounds/${IDS.source}`).assetNumber = 8;
    await expect(invoke(memory)).rejects.toMatchObject({code: 'data-loss',
      details: {reasonCode: 'burner-directive-compliance-round-asset-drift'}});
    expect(memory.writes).toHaveLength(0);
  });

  test('accepted compliance remains bound to the original actor and request contents', async () => {
    const memory = fakeDb(seed());
    await invoke(memory);
    memory.store.set('users/actor-2', {isApproved: true, roles: ['admin'], name: 'Other Admin'});
    await expect(mutateBurnerDirectiveComplianceWithDb({db: memory.db,
      authUid: 'actor-2', data: request()})).rejects.toMatchObject({code: 'already-exists'});
    await expect(invoke(memory, request({closureRemarks: 'Different closure intent.'})))
      .rejects.toMatchObject({code: 'already-exists'});
  });

  test('a refreshed asset display snapshot does not relabel or invalidate the historical source round', async () => {
    const m = fakeDb(seed());
    m.store.get(`asset_classes/${IDS.class}`).name = 'BAF Heating Furnaces';
    m.store.get(`asset_instances/${IDS.asset}`).assetClassName = 'BAF Heating Furnaces';
    const previous = [...m.store].filter(([key]) => key.startsWith('burner_condition_rounds/'));
    expect((await invoke(m)).ok).toBe(true);
    for (const [key, value] of previous) expect(m.store.get(key)).toEqual(value);
  });

  test.each([null, '', '   '])('malformed current class display still fails closed: %s', async (name) => {
    const m = fakeDb(seed()); m.store.get(`asset_classes/${IDS.class}`).name = name;
    await expect(invoke(m)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(m.writes).toHaveLength(0);
  });

  test('class display rename does not change the stable operational identity', async () => {
    const m = fakeDb(seed());
    m.store.get(`asset_classes/${IDS.class}`).name = 'BAF Heating Furnaces';
    expect((await invoke(m)).ok).toBe(true);
  });

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

  test('a round without UV evidence cannot have it inferred by compliance', async () => {
    const legacy = round();
    // A round recorded before UV and draft-seal evidence was captured carries
    // none of it.
    delete legacy.uvObservations;
    delete legacy.draftSealRedHotObserved;
    delete legacy.hotAirAtDraftSealObserved;
    legacy.schemaVersion = 1;
    const memory = fakeDb({
      ...seed(),
      [`burner_condition_rounds/${IDS.source}`]: legacy,
    });

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'burner-directive-compliance-round-evidence-unavailable',
      }),
    });
    // Nothing was recorded, so no position nobody examined is now on record as
    // examined and normal.
    expect(memory.store.get(`burner_condition_rounds/${IDS.closure}`))
      .toBeUndefined();
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

test('administrative review accepts the actual burner compliance receipt', async () => {
  const memory = fakeDb(seed());
  await invoke(memory);
  await require('./submissionRecoveryFixtures.cjs').inspectProducedReceipt('burnerEvidence', memory.store.get(`burner_condition_round_receipts/${IDS.closure}`));
});
