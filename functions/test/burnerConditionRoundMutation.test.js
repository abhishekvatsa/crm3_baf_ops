'use strict';

const {
  mutateBurnerConditionRoundWithDb,
  parseBurnerConditionRoundMutationRequest,
  userCanRecordBurnerConditionRound,
} = require('../lib/burnerConditionRoundMutation');

const clone = (value) => value == null ? value : structuredClone(value);

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];
  let transactionCalls = 0;

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
    get transactionCalls() { return transactionCalls; },
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); }};
      },
      async runTransaction(fn) {
        transactionCalls++;
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
  round: '11111111-1111-4111-8111-111111111111',
  asset: '22222222-2222-4222-8222-222222222222',
  class: '33333333-3333-4333-8333-333333333333',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function assetClass(overrides = {}) {
  return {
    schemaVersion: 1,
    assetClassId: IDS.class,
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
    version: 2,
    ...overrides,
  };
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
    version: 4,
    ...overrides,
  };
}

function observations(overrides = {}) {
  return Array.from({length: 8}, (_, index) => ({
    position: index + 1,
    flameObservation: 'seen',
    redHotObserved: false,
    microampReading: index === 0 ? 3.7 : null,
    remarks: null,
    ...(overrides[index + 1] ?? {}),
  }));
}

function uvObservations(overrides = {}) {
  return Array.from({length: 8}, (_, index) => ({
    position: index + 1,
    condition: 'serviceable',
    remarks: null,
    ...(overrides[index + 1] ?? {}),
  }));
}

function request(overrides = {}) {
  return {
    requestId: IDS.round,
    operation: 'RECORD_BURNER_CONDITION_ROUND',
    assetClassId: IDS.class,
    assetInstanceId: IDS.asset,
    expectedAssetVersion: 4,
    observations: observations(),
    roundNote: 'Routine shift condition round.',
    ...overrides,
  };
}

function seed(role = 'operations') {
  return {
    'users/actor-1': user(role, 'Actor One'),
    [`asset_classes/${IDS.class}`]: assetClass(),
    [`asset_instances/${IDS.asset}`]: asset(),
  };
}

async function invoke(memory, data = request(), authUid = 'actor-1') {
  return mutateBurnerConditionRoundWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => new Date('2026-08-16T18:30:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('burner condition round mutation', () => {
  test('requires an exact eight-position observation set', () => {
    expect(parseBurnerConditionRoundMutationRequest(request()).observations)
      .toHaveLength(8);
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      observations: observations().slice(0, 7),
    }))).toThrow('exactly eight');
    const duplicate = observations();
    duplicate[7].position = 7;
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      observations: duplicate,
    }))).toThrow('each position');
  });

  test('microamp remains bounded observation evidence', () => {
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      observations: observations({1: {
        flameObservation: 'notChecked',
        microampReading: 3.4,
      }}),
    }))).toThrow('without an observed flame signal');
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      observations: observations({1: {microampReading: -0.1}}),
    }))).toThrow('finite value');
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      observations: observations({1: {
        flameObservation: 'notChecked',
        microampReading: null,
        remarks: null,
      }}),
    }))).toThrow('must explain');
  });

  test('authority admits Operations and I&A but fails malformed users closed', () => {
    expect(userCanRecordBurnerConditionRound(user('operations'))).toBe(true);
    expect(userCanRecordBurnerConditionRound(user('seniorInstrumentation')))
      .toBe(true);
    expect(userCanRecordBurnerConditionRound(user('seniorMechanical')))
      .toBe(false);
    expect(userCanRecordBurnerConditionRound({
      isApproved: true,
      roles: ['operations', 'unknown'],
    })).toBe(false);
  });

  test('records immutable round evidence and exact replay is write-free', async () => {
    const memory = fakeDb(seed());
    const first = await invoke(memory);
    const writesAfterFirst = memory.writes.length;
    const replay = await invoke(memory);

    expect(first).toMatchObject({
      roundId: IDS.round,
      directiveId: null,
      idempotentReplay: false,
    });
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writesAfterFirst);
    expect(memory.store.get(`burner_condition_rounds/${IDS.round}`))
      .toMatchObject({
        assetNumber: 7,
        recordedByUid: 'actor-1',
        redHotPositions: [],
        microampPositions: [1],
      });
    expect(memory.store.get(`burner_condition_round_receipts/${IDS.round}`))
      .toMatchObject({
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        assetInstanceVersion: 4,
        assetNumber: 7,
        assetName: 'Furnace 7',
        recordedByName: 'Actor One',
      });
  });

  test('red-hot evidence atomically creates an I&A directive', async () => {
    const memory = fakeDb(seed('seniorInstrumentation'));
    const result = await invoke(memory, request({
      observations: observations({3: {redHotObserved: true}}),
    }));
    const directive = memory.store.get(`directives/${result.directiveId}`);

    expect(result.directiveId).toBe(`burner_round_red_hot_${IDS.round}`);
    expect(directive).toMatchObject({
      directedTo: 'seniorInstrumentation',
      priority: 'critical',
      status: 'open',
      assetType: 'furnace',
      assetNumber: 7,
    });
    expect(JSON.parse(directive.metadataJson)).toEqual({
      schemaVersion: 1,
      trigger: 'burnerConditionRoundRedHot',
      sourceRoundId: IDS.round,
      burnerPositions: [3],
      automaticPlantActuation: false,
    });
  });

  test('extended audit records draft-seal and UV state and routes only exposed UVs', async () => {
    const memory = fakeDb(seed('seniorInstrumentation'));
    const data = request({
      observations: observations({
        2: {redHotObserved: true},
        3: {redHotObserved: true},
      }),
      draftSealRedHotObserved: true,
      hotAirAtDraftSealObserved: false,
      uvObservations: uvObservations({3: {condition: 'missing'}}),
    });
    const result = await invoke(memory, data);
    const round = memory.store.get(`burner_condition_rounds/${IDS.round}`);
    const directive = memory.store.get(`directives/${result.directiveId}`);

    expect(round).toMatchObject({
      schemaVersion: 2,
      redHotPositions: [2, 3],
      directivePositions: [2],
      draftSealRedHotObserved: true,
      hotAirAtDraftSealObserved: false,
    });
    expect(round.uvObservations[2]).toMatchObject({
      position: 3,
      condition: 'missing',
    });
    expect(JSON.parse(directive.metadataJson).burnerPositions).toEqual([2]);
  });

  test('extended audit fields are accepted only as one complete set', () => {
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      draftSealRedHotObserved: false,
    }))).toThrow('must accompany');
    expect(() => parseBurnerConditionRoundMutationRequest(request({
      draftSealRedHotObserved: false,
      hotAirAtDraftSealObserved: false,
      uvObservations: uvObservations().slice(0, 7),
    }))).toThrow('exactly eight');
  });

  test('red-hot directive rejects a Furnace number outside legacy support', async () => {
    const data = seed('seniorInstrumentation');
    data[`asset_instances/${IDS.asset}`].assetNumber = 27;
    data[`asset_instances/${IDS.asset}`].name = 'Furnace 27';
    await expect(invoke(fakeDb(data), request({
      observations: observations({3: {redHotObserved: true}}),
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode:
          'burner-condition-round-directive-furnace-number-unsupported',
      },
    });
  });

  test('non-Furnace and stale asset identity fail closed', async () => {
    const wrongClass = seed();
    wrongClass[`asset_classes/${IDS.class}`].legacyAssetTypeKey = 'base';
    await expect(invoke(fakeDb(wrongClass))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'burner-condition-round-furnace-invalid'},
    });
    await expect(invoke(fakeDb(seed()), request({
      expectedAssetVersion: 3,
    }))).rejects.toMatchObject({
      code: 'aborted',
      details: {
        reasonCode: 'burner-condition-round-asset-version-mismatch',
      },
    });
  });

  test('unauthorized actor is rejected before transaction work', async () => {
    const memory = fakeDb(seed('seniorMechanical'));
    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'permission-denied',
    });
    expect(memory.transactionCalls).toBe(0);
    expect(memory.writes).toHaveLength(0);
  });

  test('replay fails closed when immutable evidence drifts', async () => {
    const memory = fakeDb(seed());
    await invoke(memory);
    memory.store.get(`burner_condition_rounds/${IDS.round}`).recordedByUid =
      'different-actor';
    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'burner-condition-round-replay-evidence-drift'},
    });
  });

  test('replay rejects drift in frozen Furnace display identity', async () => {
    const memory = fakeDb(seed());
    await invoke(memory);
    memory.store.get(`burner_condition_rounds/${IDS.round}`).assetName =
      'Different Furnace';
    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'burner-condition-round-replay-evidence-drift'},
    });
  });

  test('replay fails closed when the red-hot directive loses source binding', async () => {
    const memory = fakeDb(seed());
    const data = request({
      observations: observations({3: {redHotObserved: true}}),
    });
    const first = await invoke(memory, data);
    const directive = memory.store.get(`directives/${first.directiveId}`);
    directive.metadataJson = JSON.stringify({
      schemaVersion: 1,
      trigger: 'burnerConditionRoundRedHot',
      sourceRoundId: 'different-round',
      burnerPositions: [3],
      automaticPlantActuation: false,
    });

    await expect(invoke(memory, data)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'burner-condition-round-directive-drift'},
    });
  });
});
