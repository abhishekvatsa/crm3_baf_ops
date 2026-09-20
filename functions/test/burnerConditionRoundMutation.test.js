'use strict';

const {
  mutateBurnerConditionRoundWithDb,
  parseBurnerConditionRoundMutationRequest,
  userCanRecordBurnerConditionRound,
} = require('../lib/burnerConditionRoundMutation');

const clone = (value) => value == null ? value : structuredClone(value);

function fakeDb(seed = {}, options = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];
  const outsideReads = [];
  const transactionReads = [];
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
        outsideReads.push(path);
        const value = snapshot(path, id);
        options.afterOutsideGet?.({path, store});
        return value;
      },
    };
  }

  return {
    store,
    writes,
    outsideReads,
    transactionReads,
    get transactionCalls() { return transactionCalls; },
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); },
          where(field, op, value) { return {queryCollection: name, field, op, value}; }};
      },
      async runTransaction(fn) {
        transactionCalls++;
        const staged = [];
        const transaction = {
          async get(documentRef) {
            if (staged.length > 0) throw new Error('Transaction read after write');
            if (documentRef.queryCollection != null) {
              const {queryCollection, field, op, value} = documentRef;
              if (op !== '==') throw new Error('Unsupported fake query');
              return {docs: [...store.entries()]
                .filter(([path, data]) => path.startsWith(`${queryCollection}/`) && data[field] === value)
                .map(([path]) => snapshot(path, path.split('/').pop()))};
            }
            transactionReads.push(documentRef.path);
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

async function invoke(memory, data = request(), authUid = 'actor-1',
  instant = '2026-08-16T18:30:00.000Z') {
  return mutateBurnerConditionRoundWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => new Date(instant),
    timestampFromDate: (date) => date,
  });
}

describe('burner condition round mutation', () => {
  function partialRequest(overrides = {}) {
    return request({
      requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      expectedCurrentRoundId: IDS.round,
      observations: observations({1: {redHotObserved: true, microampReading: 99}}),
      uvObservations: uvObservations(),
      draftSealRedHotObserved: false, hotAirAtDraftSealObserved: false,
      observedFields: ['burners.1.redHotObserved'],
      expectedInstallationBasis: {burner: [], uv: []}, expectedOpenIssueBasis: [],
      ...overrides,
    });
  }

  async function baseline(memory) {
    return invoke(memory, request({uvObservations: uvObservations({2: {condition: 'melted'}}),
      draftSealRedHotObserved: true, hotAirAtDraftSealObserved: false}));
  }

  test('partial inspection preserves untouched values and their original observer/time', async () => {
    const memory = fakeDb(seed());
    await baseline(memory);
    const command = partialRequest();
    const accepted = await invoke(memory, command, 'actor-1', '2026-08-16T20:00:00.000Z');
    const stored = memory.store.get(`burner_condition_rounds/${command.requestId}`);
    expect(stored).toMatchObject({evidenceKind: 'partialInspection', baselineRoundId: IDS.round,
      draftSealRedHotObserved: true});
    expect(stored.observations[0]).toMatchObject({redHotObserved: true, microampReading: 3.7});
    expect(stored.uvObservations[1].condition).toBe('melted');
    expect(stored.evidenceProvenance['uv.2.condition']).toEqual({
      kind: 'inherited', sourceRoundId: IDS.round, observedAt: '2026-08-16T18:30:00.000Z',
      observerUid: 'actor-1', observerName: 'Actor One',
    });
    expect(stored.evidenceProvenance['burners.1.redHotObserved'])
      .toMatchObject({kind: 'observed', sourceRoundId: command.requestId,
        observedAt: '2026-08-16T20:00:00.000Z'});
    const writes = memory.writes.length;
    expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writes);
  });

  test('partial first use marks untouched defaults unknown', async () => {
    const memory = fakeDb(seed());
    const command = partialRequest({expectedCurrentRoundId: null});
    await invoke(memory, command);
    const stored = memory.store.get(`burner_condition_rounds/${command.requestId}`);
    expect(stored.evidenceProvenance['uv.2.condition']).toEqual({kind: 'unknown',
      sourceRoundId: null, observedAt: null, observerUid: null, observerName: null});
    expect(stored.observations[0].microampReading).toBeNull();
    expect(stored.observations[1].flameObservation).toBe('notChecked');
  });

  test('partial changes cannot combine a non-operating flame with an inherited reading', async () => {
    const memory = fakeDb(seed());
    await baseline(memory);
    const writes = memory.writes.length;
    await expect(invoke(memory, partialRequest({
      observations: observations({1: {flameObservation: 'notOperating', microampReading: null}}),
      observedFields: ['burners.1.flameObservation'],
    }))).rejects.toMatchObject({code: 'invalid-argument', details: {
      reasonCode: 'burner-condition-round-partial-observation-conflict',
    }});
    expect(memory.writes).toHaveLength(writes);
    await invoke(memory, partialRequest({
      observations: observations({1: {flameObservation: 'notOperating', microampReading: null}}),
      observedFields: ['burners.1.flameObservation', 'burners.1.microampReading'],
    }));
    expect(memory.store.get('burner_condition_rounds/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
      .observations[0]).toMatchObject({flameObservation: 'notOperating', microampReading: null});
  });

  test.each(['installation', 'issue'])(
    'a new %s invalidates a partial draft even when its round ID is unchanged', async (writer) => {
      const memory = fakeDb(seed());
      await baseline(memory);
      if (writer === 'installation') {
        const {createHash} = require('crypto');
        const projectionId = `uvlc_${createHash('sha256')
          .update(`${IDS.asset}|2`).digest('hex').slice(0, 40)}`;
        memory.store.set(`uv_detector_lifecycle_current/${projectionId}`, {
          schemaVersion: 1, projectionSchemaVersion: 1, projectionId,
          assetInstanceId: IDS.asset, burnerPosition: 2, eventId: 'replacement-2',
          currentEventId: 'replacement-2', installationDiscipline: 'instrumentation',
          resultingCondition: 'serviceable', actionPerformedAt: '2026-08-16T19:00:00.000Z',
        });
      } else {
        memory.store.set('maintenance_records/issue-2', {firestoreId: 'issue-2',
          assetType: 'furnace', assetNumber: 7, status: 'open', isDeleted: false,
          isResolved: false, burnerRedHotPositions: [2], version: 1,
          updatedAt: '2026-08-16T19:00:00.000Z'});
      }
      const writes = memory.writes.length;
      await expect(invoke(memory, partialRequest())).rejects.toMatchObject({code: 'aborted',
        details: {reasonCode: `burner-condition-round-${writer}-basis-mismatch`}});
      expect(memory.writes).toHaveLength(writes);
    },
  );

  test('partial replay remains valid after later installation evidence advances', async () => {
    const memory = fakeDb(seed());
    await baseline(memory);
    const command = partialRequest();
    const accepted = await invoke(memory, command);
    memory.store.set('uv_detector_lifecycle_current/later', {assetInstanceId: IDS.asset});
    const writes = memory.writes.length;
    expect(await invoke(memory, command)).toEqual({...accepted, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writes);
  });

  test('partial input requires its complete reviewed basis', () => {
    const command = partialRequest();
    delete command.expectedInstallationBasis;
    expect(() => parseBurnerConditionRoundMutationRequest(command))
      .toThrow('reviewed round, installation and issue basis');
  });

  test('ordinary legacy-shaped round receipts replay without the additive evidence metadata', async () => {
    const memory = fakeDb(seed());
    const accepted = await invoke(memory);
    const stored = memory.store.get(`burner_condition_rounds/${IDS.round}`);
    delete stored.evidenceKind;
    delete stored.evidenceProvenance;
    const receipt = memory.store.get(`burner_condition_round_receipts/${IDS.round}`);
    delete receipt.evidenceVersion;
    delete receipt.roundEvidenceSha256;
    const writes = memory.writes.length;
    expect(await invoke(memory)).toEqual({...accepted, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writes);
  });

  test('a partial round never promotes malformed inherited observations', async () => {
    const memory = fakeDb(seed());
    await baseline(memory);
    memory.store.get(`burner_condition_rounds/${IDS.round}`).observations[1].redHotObserved = 'false';
    const writes = memory.writes.length;
    await expect(invoke(memory, partialRequest())).rejects.toMatchObject({code: 'data-loss',
      details: {reasonCode: 'burner-condition-round-baseline-malformed'}});
    expect(memory.writes).toHaveLength(writes);
  });

  test('a partial round replay binds both accepted inherited content and the reviewed baseline', async () => {
    const memory = fakeDb(seed());
    await baseline(memory);
    const command = partialRequest();
    await invoke(memory, command);
    memory.store.get(`burner_condition_rounds/${IDS.round}`).observations[0].microampReading = 88;
    memory.store.get(`burner_condition_rounds/${command.requestId}`).observations[0].microampReading = 88;
    const writes = memory.writes.length;
    await expect(invoke(memory, command)).rejects.toMatchObject({code: 'data-loss',
      details: {reasonCode: 'burner-condition-round-replay-evidence-drift'}});
    expect(memory.writes).toHaveLength(writes);
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

  test('revalidates authority before every transactional business read', async () => {
    const memory = fakeDb(seed(), {
      afterOutsideGet({path, store}) {
        if (path === 'users/actor-1') {
          store.set(path, user('operations', 'Actor One'));
          store.get(path).isApproved = false;
        }
      },
    });

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'permission-denied',
    });
    expect(memory.outsideReads).toEqual(['users/actor-1']);
    expect(memory.transactionReads).toEqual(['users/actor-1']);
    expect(memory.writes).toHaveLength(0);
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
    expect(memory.store.get(`burner_condition_current/${IDS.asset}`))
      .toMatchObject({
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        roundId: IDS.round,
      });
  });

  test('a round composed before another round was recorded is refused', async () => {
    const memory = fakeDb({
      ...seed(),
      [`burner_condition_current/${IDS.asset}`]: {
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        roundId: 'round-recorded-by-someone-else',
        observedAt: '2026-09-01T04:00:00.000Z',
      },
    });
    const writesBefore = memory.writes.length;

    // This submission was composed against the furnace as it read before
    // that: eight positions witnessed against a baseline that has moved.
    await expect(invoke(memory, request({
      expectedCurrentRoundId: null,
    }))).rejects.toMatchObject({
      details: {reasonCode: 'burner-condition-round-superseded'},
    });
    expect(memory.writes).toHaveLength(writesBefore);
    expect(memory.store.get(`burner_condition_current/${IDS.asset}`).roundId)
      .toBe('round-recorded-by-someone-else');
  });

  test('a round composed against the current one is recorded', async () => {
    const memory = fakeDb({
      ...seed(),
      [`burner_condition_current/${IDS.asset}`]: {
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        roundId: 'round-the-operator-saw',
        observedAt: '2026-09-01T04:00:00.000Z',
      },
    });

    const result = await invoke(memory, request({
      expectedCurrentRoundId: 'round-the-operator-saw',
    }));

    expect(result.idempotentReplay).toBe(false);
    expect(memory.store.get(`burner_condition_current/${IDS.asset}`).roundId)
      .toBe(IDS.round);
  });

  test('the first round on a furnace expects no current round', async () => {
    const memory = fakeDb(seed());

    const result = await invoke(memory, request({
      expectedCurrentRoundId: null,
    }));

    expect(result.idempotentReplay).toBe(false);
  });

  test('a client that names no expectation is recorded as before', async () => {
    const memory = fakeDb({
      ...seed(),
      [`burner_condition_current/${IDS.asset}`]: {
        schemaVersion: 1,
        assetInstanceId: IDS.asset,
        roundId: 'round-recorded-by-someone-else',
        observedAt: '2026-09-01T04:00:00.000Z',
      },
    });

    // An older client does not carry the field at all. It keeps the behaviour
    // it shipped with rather than being refused by a rule it cannot satisfy.
    const result = await invoke(memory, request());

    expect(result.idempotentReplay).toBe(false);
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

test('administrative review accepts the actual burner round receipt without changing it', async () => {
  const memory = fakeDb(seed());
  await invoke(memory);
  await require('./submissionRecoveryFixtures.cjs').inspectProducedReceipt('burnerEvidence', memory.store.get(`burner_condition_round_receipts/${IDS.round}`));
});
