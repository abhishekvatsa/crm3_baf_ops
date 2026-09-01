const {
  isMorningReviewOperation,
  morningReviewCommandContractSnapshot,
  morningReviewPlantClock,
  mutateMorningReviewWithDb,
  parseMorningReviewMutationRequest,
  userCanMutateMorningReview,
} = require('../lib/morningReviewMutation');
const morningReviewCommandContract = require(
  '../../test/fixtures/morning_review_command_contract_v1.json'
);

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];
  const reads = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function query(collection, filters = [], maximum = Number.MAX_SAFE_INTEGER) {
    return {
      where(field, op, value) {
        if (op !== '==') throw new Error(`Unsupported fake query ${op}`);
        return query(collection, [...filters, {field, value}], maximum);
      },
      limit(value) {
        return query(collection, filters, value);
      },
      async get() {
        reads.push({kind: 'query', collection});
        const prefix = `${collection}/`;
        const docs = [];
        for (const [path, data] of store.entries()) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes('/')) {
            continue;
          }
          if (filters.some(({field, value}) => data?.[field] !== value)) continue;
          docs.push(snapshot(path, path.slice(prefix.length)));
          if (docs.length >= maximum) break;
        }
        return {docs};
      },
    };
  }

  function collection(name) {
    const base = query(name);
    return {
      ...base,
      doc(id) {
        const path = `${name}/${id}`;
        return {id, path, async get() {
          reads.push({kind: 'document', path});
          return snapshot(path, id);
        }};
      },
    };
  }

  return {
    store,
    writes,
    reads,
    db: {
      collection,
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(ref) {
            if (typeof ref.get === 'function' && ref.path == null) {
              return ref.get();
            }
            reads.push({kind: 'document', path: ref.path});
            return snapshot(ref.path, ref.id);
          },
          set(ref, data, options) {
            staged.push({path: ref.path, data: clone(data), merge: options?.merge});
          },
          delete(ref) {
            staged.push({path: ref.path, delete: true});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          if (write.delete) {
            store.delete(write.path);
          } else if (write.merge) {
            store.set(write.path, {
              ...(store.get(write.path) ?? {}),
              ...clone(write.data),
            });
          } else {
            store.set(write.path, clone(write.data));
          }
          writes.push(write);
        }
        return result;
      },
    },
  };
}

const IDS = {
  start: '11111111-1111-4111-8111-111111111111',
  join: '22222222-2222-4222-8222-222222222222',
  entry: '33333333-3333-4333-8333-333333333333',
  action: '44444444-4444-4444-8444-444444444444',
  accept: '55555555-5555-4555-8555-555555555555',
  complete: '66666666-6666-4666-8666-666666666666',
  concern: '77777777-7777-4777-8777-777777777777',
  check: '88888888-8888-4888-8888-888888888888',
  finalize: '99999999-9999-4999-8999-999999999999',
  lateEntry: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  notHeld: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  addendum: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  takeover: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  extra: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
  lateAddendum: 'abababab-abab-4bab-8bab-abababababab',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function baseSeed() {
  return {
    'users/admin-1': user('admin', 'Admin One'),
    'users/si-1': user('si', 'SI One'),
    'users/si-2': user('si', 'SI Two'),
    'users/contract-1': user('contractSupervisor', 'Contract One'),
    'users/mech-1': user('seniorMechanical', 'Mechanical One'),
    'users/ops-1': user('operations', 'Operations One'),
    'critical_alarms/alarm-1': {
      status: 'raised',
      alarmTypeName: 'Fire',
      details: 'Fire alarm near the furnace bay.',
      raisedAt: new Date('2026-08-30T03:15:00.000Z'),
    },
    'maintenance_records/ticket-1': {
      status: 'open',
      isResolved: false,
      isDeleted: false,
      assetType: 'furnace',
      assetNumber: 12,
      description: 'Draft seal requires inspection.',
      createdAt: new Date('2026-08-30T06:00:00.000Z'),
    },
  };
}

const meetingTime = new Date('2026-08-31T03:00:00.000Z'); // 08:30 IST
const sessionId = '2026-08-31';

function invoke(memory, authUid, data, at = meetingTime) {
  return mutateMorningReviewWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => at,
    timestampFromDate: (date) => date,
  });
}

function startRequest(requestId = IDS.start) {
  return {requestId, operation: 'START_MORNING_REVIEW'};
}

function entryRequest(overrides = {}) {
  return {
    requestId: IDS.entry,
    operation: 'ADD_MORNING_REVIEW_ENTRY',
    sessionId,
    entryDraft: {
      section: 'furnace',
      kind: 'update',
      text: 'Furnace 12 inspection is planned before the next cycle.',
      assetClassId: 'furnace-class',
      assetClassName: 'Furnace',
      assetInstanceId: 'furnace-12',
      assetNumber: '12',
      sourceReferences: ['maintenance_records/ticket-1'],
    },
    ...overrides,
  };
}

describe('Morning Review governed lifecycle', () => {
  test('server request shapes match the shared mobile command contract', () => {
    expect(morningReviewCommandContractSnapshot()).toEqual({
      operations: morningReviewCommandContract.operations,
      entryDraftFields: morningReviewCommandContract.entryDraftFields,
      actionDraftFields: morningReviewCommandContract.actionDraftFields,
      concernDraftFields: morningReviewCommandContract.concernDraftFields,
    });
  });

  test('uses the India plant day and inclusive 08:00-10:00 start window', () => {
    expect(morningReviewPlantClock(new Date('2026-08-31T02:30:00.000Z')))
      .toMatchObject({plantDay: sessionId, minuteOfDay: 480, canStart: true});
    expect(morningReviewPlantClock(new Date('2026-08-31T04:30:00.000Z')))
      .toMatchObject({minuteOfDay: 600, canStart: true, windowMissed: false});
    expect(morningReviewPlantClock(new Date('2026-08-31T04:31:00.000Z')))
      .toMatchObject({minuteOfDay: 601, canStart: false, windowMissed: true});
  });

  test.each([
    new Date('2026-08-31T02:00:00.000Z'), // 07:30 IST
    new Date('2026-08-31T04:31:00.000Z'), // 10:01 IST
  ])('allows an approved Admin to start outside the standard window', async (at) => {
    const memory = fakeDb(baseSeed());
    const created = await invoke(memory, 'admin-1', startRequest(), at);
    expect(created).toMatchObject({status: 'open', version: 1});
    expect(memory.store.get(`morning_review_sessions/${sessionId}`))
      .toMatchObject({facilitatorUid: 'admin-1', status: 'open'});
  });

  test('keeps SI start authority inside the standard window', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(
      memory,
      'si-1',
      startRequest(),
      new Date('2026-08-31T04:31:00.000Z'),
    )).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'morning-review-start-window-closed'},
    });
    expect(memory.reads.some((read) => read.kind === 'query')).toBe(false);
  });

  test('strictly parses operation envelopes and role admission', () => {
    expect(isMorningReviewOperation('JOIN_MORNING_REVIEW')).toBe(true);
    expect(isMorningReviewOperation('DELETE_EVERYTHING')).toBe(false);
    expect(userCanMutateMorningReview(user('admin'), 'START_MORNING_REVIEW'))
      .toBe(true);
    expect(userCanMutateMorningReview(user('operations'), 'START_MORNING_REVIEW'))
      .toBe(false);
    expect(userCanMutateMorningReview(user('operations'), 'JOIN_MORNING_REVIEW'))
      .toBe(true);
    expect(() => parseMorningReviewMutationRequest({
      ...startRequest(),
      clientTime: '2026-08-31T03:00:00.000Z',
    })).toThrow('clientTime is unsupported');
    expect(() => parseMorningReviewMutationRequest(entryRequest({
      entryDraft: {...entryRequest().entryDraft, kind: 'addendum'},
    }))).toThrow('reserved for a finalized-session addendum');
    expect(() => parseMorningReviewMutationRequest({
      requestId: IDS.action,
      operation: 'CREATE_MORNING_REVIEW_ACTION',
      sessionId,
      actionDraft: {
        section: 'plantWide',
        text: 'Invalid role route.',
        assigneeUid: null,
        assigneeRole: 'inventedSupervisor',
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        dueAt: null,
      },
    })).toThrow('not a canonical application role');
    expect(() => parseMorningReviewMutationRequest({
      requestId: IDS.action,
      operation: 'CREATE_MORNING_REVIEW_ACTION',
      sessionId,
      actionDraft: {
        section: 'plantWide',
        text: 'Invalid due time.',
        assigneeUid: null,
        assigneeRole: 'operations',
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        dueAt: 'not-a-date',
      },
    })).toThrow('must be a canonical UTC instant');
  });

  test('rejects unauthorized starts before reading any agenda source collection', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(memory, 'ops-1', startRequest()))
      .rejects.toMatchObject({code: 'permission-denied'});
    expect(memory.reads.some((read) => read.kind === 'query')).toBe(false);
  });

  test('starts one session, snapshots source facts, and joins the facilitator', async () => {
    const memory = fakeDb(baseSeed());
    const created = await invoke(memory, 'si-1', startRequest());
    expect(created).toMatchObject({
      sessionId,
      entityId: sessionId,
      status: 'open',
      version: 1,
      idempotentReplay: false,
    });
    const session = memory.store.get(`morning_review_sessions/${sessionId}`);
    expect(session).toMatchObject({
      facilitatorUid: 'si-1',
      sourceFactCount: 2,
      status: 'open',
    });
    expect(session.sourceFacts.map((fact) => fact.sourceCollection))
      .toEqual(expect.arrayContaining(['critical_alarms', 'maintenance_records']));
    expect(session.sourceFacts.every((fact) =>
      fact.factId === `${fact.sourceCollection}/${fact.sourceDocumentId}`,
    )).toBe(true);
    expect(memory.store.get(
      `morning_review_participants/${sessionId}_si-1`,
    )).toMatchObject({state: 'joined', userName: 'SI One'});

    const writeCount = memory.writes.length;
    const sourceQueryCount = memory.reads.filter((read) => read.kind === 'query').length;
    const replay = await invoke(memory, 'si-1', startRequest());
    expect(replay.idempotentReplay).toBe(true);
    expect(memory.writes).toHaveLength(writeCount);
    expect(memory.reads.filter((read) => read.kind === 'query'))
      .toHaveLength(sourceQueryCount);

    await expect(invoke(
      memory,
      'admin-1',
      startRequest('cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
    )).rejects.toMatchObject({code: 'already-exists'});
  });

  test('captures active condition projections and prior-day burner closure evidence', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_burner_closures/burner-1': {
        sourceMaintenanceId: 'burner-1',
        updatedAt: '2026-08-30T06:30:00.000Z',
      },
      'maintenance_records/burner-1': {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 26,
        description: 'Burner lockouts attended and returned to service.',
        endDate: '2026-08-30T06:30:00.000Z',
      },
      'asset_operational_conditions/base-201': {
        active: true,
        condition: 'unfit',
        assetClassId: 'base-class',
        assetClassName: 'Base',
        assetInstanceId: 'base-201',
        assetNumber: 201,
        reason: 'Inner Cover inspection pending.',
      },
      'asset_availability_current/furnace-12': {
        availabilityState: 'temporarilyBlocked',
        assetType: 'furnace',
        assetClassId: 'furnace-class',
        assetInstanceId: 'furnace-12',
        assetNumber: 12,
        reasonType: 'furnaceStuckup',
      },
      'job_executions/job-1': {
        isCompleted: false,
        isCancelled: false,
        isDeleted: false,
        assetType: 'forcedCooler',
        assetNumber: 7,
        templateName: 'Forced Cooler inspection',
        createdAt: '2026-08-29T06:00:00.000Z',
      },
      'morning_review_actions/prior-action': {
        status: 'accepted',
        section: 'base',
        text: 'Confirm Base 201 Inner Cover availability.',
        assetClassName: 'Base',
        assetNumber: '201',
        createdAt: '2026-08-30T04:00:00.000Z',
      },
    });
    await invoke(memory, 'si-1', startRequest());
    const facts = memory.store.get(`morning_review_sessions/${sessionId}`).sourceFacts;
    expect(facts.map((fact) => fact.sourceCollection)).toEqual(
      expect.arrayContaining([
        'maintenance_burner_closures',
        'asset_operational_conditions',
        'asset_availability_current',
        'job_executions',
        'morning_review_actions',
      ]),
    );
    expect(facts.find((fact) => fact.factId ===
      'maintenance_burner_closures/burner-1'))
      .toMatchObject({assetNumber: '26', section: 'furnace'});
  });

  test('requires explicit attendance and preserves attributed append-only entries', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    await expect(invoke(memory, 'contract-1', entryRequest()))
      .rejects.toMatchObject({code: 'failed-precondition'});

    await invoke(memory, 'contract-1', {
      requestId: IDS.join,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    });
    const recorded = await invoke(memory, 'contract-1', entryRequest());
    expect(recorded).toMatchObject({status: 'recorded', version: 3});
    expect(memory.store.get(`morning_review_entries/${IDS.entry}`))
      .toMatchObject({
        authorUid: 'contract-1',
        authorName: 'Contract One',
        kind: 'update',
        assetNumber: '12',
      });
  });

  test('enforces source provenance, maintenance-update roles, and joined takeover', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'admin-1', startRequest());
    await invoke(memory, 'ops-1', {
      requestId: IDS.join,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    });
    await expect(invoke(memory, 'ops-1', entryRequest({
      requestId: IDS.extra,
      entryDraft: {
        ...entryRequest().entryDraft,
        kind: 'maintenanceUpdate',
      },
    }))).rejects.toMatchObject({code: 'permission-denied'});
    await expect(invoke(memory, 'ops-1', entryRequest({
      requestId: IDS.extra,
      entryDraft: {
        ...entryRequest().entryDraft,
        sourceReferences: ['maintenance_records/not-captured'],
      },
    }))).rejects.toMatchObject({code: 'failed-precondition'});

    await expect(invoke(memory, 'si-2', {
      requestId: IDS.takeover,
      operation: 'TAKE_OVER_MORNING_REVIEW',
      sessionId,
      expectedVersion: 2,
      reason: 'Facilitator handover requested by the room.',
    })).rejects.toMatchObject({code: 'failed-precondition'});
    await invoke(memory, 'si-2', {
      requestId: IDS.extra,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    });
    const session = memory.store.get(`morning_review_sessions/${sessionId}`);
    const takeover = await invoke(memory, 'si-2', {
      requestId: IDS.takeover,
      operation: 'TAKE_OVER_MORNING_REVIEW',
      sessionId,
      expectedVersion: session.version,
      reason: 'Facilitator handover requested by the room.',
    });
    expect(takeover).toMatchObject({status: 'open'});
    expect(memory.store.get(`morning_review_sessions/${sessionId}`))
      .toMatchObject({facilitatorUid: 'si-2'});
  });

  test('records the approved user name with user-assigned actions', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    await invoke(memory, 'si-1', {
      requestId: IDS.action,
      operation: 'CREATE_MORNING_REVIEW_ACTION',
      sessionId,
      actionDraft: {
        section: 'plantWide',
        text: 'Confirm crane availability before the shift plan.',
        assigneeUid: 'mech-1',
        assigneeRole: null,
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        dueAt: null,
      },
    });
    expect(memory.store.get(`morning_review_actions/${IDS.action}`))
      .toMatchObject({assigneeUid: 'mech-1', assigneeName: 'Mechanical One'});
    const sessionVersion = memory.store.get(
      `morning_review_sessions/${sessionId}`,
    ).version;
    await invoke(memory, 'mech-1', {
      requestId: IDS.accept,
      operation: 'ACCEPT_MORNING_REVIEW_ACTION',
      sessionId,
      actionId: IDS.action,
      expectedVersion: 1,
    });
    expect(memory.store.get(`morning_review_sessions/${sessionId}`).version)
      .toBe(sessionVersion + 1);
  });

  test('keeps routed actions usable without converting ownership into attendance', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    await invoke(memory, 'si-1', {
      requestId: IDS.action,
      operation: 'CREATE_MORNING_REVIEW_ACTION',
      sessionId,
      actionDraft: {
        section: 'furnace',
        text: 'Inspect Furnace 12 draft seal before charging.',
        assigneeUid: null,
        assigneeRole: 'seniorMechanical',
        assetClassId: 'furnace-class',
        assetClassName: 'Furnace',
        assetInstanceId: 'furnace-12',
        assetNumber: '12',
        dueAt: '2026-08-31T12:30:00.000Z',
      },
    });
    memory.store.delete(`morning_review_sessions/${sessionId}`);
    const accepted = await invoke(memory, 'mech-1', {
      requestId: IDS.accept,
      operation: 'ACCEPT_MORNING_REVIEW_ACTION',
      sessionId,
      actionId: IDS.action,
      expectedVersion: 1,
    }, new Date('2026-09-15T03:00:00.000Z'));
    expect(accepted).toMatchObject({status: 'accepted', version: 2});
    expect(memory.store.get(`morning_review_actions/${IDS.action}`))
      .toMatchObject({
        acceptedByUid: 'mech-1',
        acceptedByName: 'Mechanical One',
        status: 'accepted',
        expiresAt: null,
      });
    expect(memory.store.has(
      `morning_review_participants/${sessionId}_mech-1`,
    )).toBe(false);
  });

  test('rejects an action that would make finalization exceed capacity', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    for (let index = 0; index < 100; index += 1) {
      memory.store.set(`morning_review_actions/existing-${index}`, {
        sessionId,
      });
    }

    await expect(invoke(memory, 'si-1', {
      requestId: IDS.action,
      operation: 'CREATE_MORNING_REVIEW_ACTION',
      sessionId,
      actionDraft: {
        section: 'plantWide',
        text: 'This action must be rejected before the meeting is overfull.',
        assigneeUid: null,
        assigneeRole: 'seniorMechanical',
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        dueAt: null,
      },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'morning-review-action-capacity-reached'},
    });
    expect(memory.store.has(`morning_review_actions/${IDS.action}`))
      .toBe(false);
  });

  test('carries a standing concern, records the daily check, and retains it while active', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'admin-1', startRequest());
    await invoke(memory, 'admin-1', {
      requestId: IDS.concern,
      operation: 'CREATE_MORNING_REVIEW_STANDING_CONCERN',
      sessionId,
      concernDraft: {
        title: 'Sheath purge valves',
        detail: 'Confirm that sheath purge valves remain open on all bases.',
        criticality: 'safety',
      },
    });
    expect(memory.store.get(`morning_review_standing_concerns/${IDS.concern}`))
      .toMatchObject({status: 'active', expiresAt: null});

    await invoke(memory, 'admin-1', {
      requestId: IDS.check,
      operation: 'CHECK_MORNING_REVIEW_STANDING_CONCERN',
      sessionId,
      concernId: IDS.concern,
      checkState: 'exception',
      reason: 'Base 109 remains to be checked by the shift team.',
    });
    expect(memory.store.get(
      `morning_review_concern_checks/${sessionId}_${IDS.concern}`,
    )).toMatchObject({state: 'exception', checkedByUid: 'admin-1'});
    const sessionVersion = memory.store.get(
      `morning_review_sessions/${sessionId}`,
    ).version;
    await invoke(memory, 'admin-1', {
      requestId: IDS.extra,
      operation: 'RESOLVE_MORNING_REVIEW_STANDING_CONCERN',
      sessionId,
      concernId: IDS.concern,
      expectedVersion: 1,
      reason: 'All bases were verified by the shift team.',
    });
    expect(memory.store.get(`morning_review_sessions/${sessionId}`).version)
      .toBe(sessionVersion + 1);
  });

  test('freezes a complete document and rejects late ordinary contributions', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    await invoke(memory, 'contract-1', {
      requestId: IDS.join,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    });
    await invoke(memory, 'contract-1', entryRequest());
    await invoke(memory, 'si-1', {
      requestId: IDS.concern,
      operation: 'CREATE_MORNING_REVIEW_STANDING_CONCERN',
      sessionId,
      concernDraft: {
        title: 'Sheath purge valves',
        detail: 'Confirm that sheath purge valves remain open on all bases.',
        criticality: 'safety',
      },
    });
    const session = memory.store.get(`morning_review_sessions/${sessionId}`);
    const finalized = await invoke(memory, 'si-1', {
      requestId: IDS.finalize,
      operation: 'FINALIZE_MORNING_REVIEW',
      sessionId,
      expectedVersion: session.version,
      summary: 'Review completed with one furnace inspection carried forward.',
    });
    expect(finalized).toMatchObject({status: 'finalized'});
    expect(memory.store.get(`morning_review_documents/${sessionId}`))
      .toMatchObject({
        status: 'finalized',
        finalSummary: 'Review completed with one furnace inspection carried forward.',
      });
    expect(memory.store.get(`morning_review_documents/${sessionId}`).entries)
      .toHaveLength(1);
    expect(memory.store.get(
      `morning_review_documents/${sessionId}`,
    ).standingConcerns).toHaveLength(1);
    await expect(invoke(memory, 'contract-1', entryRequest({
      requestId: IDS.lateEntry,
    }))).rejects.toMatchObject({code: 'failed-precondition'});
    const retainedUntil = memory.store.get(
      `morning_review_sessions/${sessionId}`,
    ).expiresAt;
    expect(retainedUntil).toEqual(new Date('2026-09-14T03:00:00.000Z'));
    await invoke(memory, 'si-1', {
      requestId: IDS.addendum,
      operation: 'ADD_MORNING_REVIEW_ADDENDUM',
      sessionId,
      reason: 'Late clarification.',
      entryDraft: {
        section: 'plantWide',
        kind: 'addendum',
        text: 'This should not outlive the retained meeting record.',
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        sourceReferences: [],
      },
    }, new Date('2026-09-01T03:00:00.000Z'));
    expect(memory.store.get(`morning_review_entries/${IDS.addendum}`).expiresAt)
      .toEqual(retainedUntil);
    expect(memory.store.get(`morning_review_sessions/${sessionId}`).expiresAt)
      .toEqual(retainedUntil);
    await expect(invoke(memory, 'si-1', {
      requestId: IDS.lateAddendum,
      operation: 'ADD_MORNING_REVIEW_ADDENDUM',
      sessionId,
      reason: 'Late clarification.',
      entryDraft: {
        section: 'plantWide',
        kind: 'addendum',
        text: 'This should not outlive the retained meeting record.',
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        sourceReferences: [],
      },
    }, new Date('2026-09-15T03:00:00.000Z')))
      .rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('expired resolved concern history cannot block finalization', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    await invoke(memory, 'si-1', {
      requestId: IDS.concern,
      operation: 'CREATE_MORNING_REVIEW_STANDING_CONCERN',
      sessionId,
      concernDraft: {
        title: 'Sheath purge valves',
        detail: 'Confirm that sheath purge valves remain open on all bases.',
        criticality: 'safety',
      },
    });
    for (let index = 0; index < 251; index += 1) {
      memory.store.set(`morning_review_standing_concerns/expired-${index}`, {
        status: 'resolved',
        expiresAt: new Date('2026-08-30T00:00:00.000Z'),
      });
    }

    const session = memory.store.get(`morning_review_sessions/${sessionId}`);
    await expect(invoke(memory, 'si-1', {
      requestId: IDS.finalize,
      operation: 'FINALIZE_MORNING_REVIEW',
      sessionId,
      expectedVersion: session.version,
      summary: 'Review completed with the standing safety concern retained.',
    })).resolves.toMatchObject({status: 'finalized'});
    expect(memory.store.get(
      `morning_review_documents/${sessionId}`,
    ).standingConcerns).toHaveLength(1);
  });

  test('records a not-held day only after the governed window', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(
      memory,
      'admin-1',
      {requestId: IDS.notHeld, operation: 'RECORD_MORNING_REVIEW_NOT_HELD', reason: 'Plant shutdown.'},
    )).rejects.toMatchObject({code: 'failed-precondition'});

    const recorded = await invoke(
      memory,
      'admin-1',
      {requestId: IDS.notHeld, operation: 'RECORD_MORNING_REVIEW_NOT_HELD', reason: 'Plant shutdown.'},
      new Date('2026-08-31T04:31:00.000Z'),
    );
    expect(recorded).toMatchObject({status: 'notHeld'});
  });
});
