const {
  isMorningReviewOperation,
  morningReviewCommandContractSnapshot,
  morningReviewPlantClock,
  collectMorningReviewSourceFacts,
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

  function query(
    collection,
    filters = [],
    maximum = Number.MAX_SAFE_INTEGER,
    orderedById = false,
    afterId = null,
  ) {
    return {
      where(field, op, value) {
        if (op !== '==') throw new Error(`Unsupported fake query ${op}`);
        return query(
          collection,
          [...filters, {field, value}],
          maximum,
          orderedById,
          afterId,
        );
      },
      orderBy(field) {
        if (field !== '__name__') {
          throw new Error(`Unsupported fake order ${field}`);
        }
        return query(collection, filters, maximum, true, afterId);
      },
      startAfter(value) {
        if (!orderedById || typeof value?.id !== 'string') {
          throw new Error('Fake cursor requires a document-ID ordered snapshot');
        }
        return query(collection, filters, maximum, orderedById, value.id);
      },
      limit(value) {
        return query(collection, filters, value, orderedById, afterId);
      },
      async get() {
        reads.push({kind: 'query', collection});
        const prefix = `${collection}/`;
        const candidates = [];
        for (const [path, data] of store.entries()) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes('/')) {
            continue;
          }
          if (filters.some(({field, value}) => data?.[field] !== value)) continue;
          const id = path.slice(prefix.length);
          if (afterId != null && id <= afterId) continue;
          candidates.push({path, id});
        }
        if (orderedById) candidates.sort((left, right) => left.id.localeCompare(right.id));
        const docs = candidates
          .slice(0, maximum)
          .map(({path, id}) => snapshot(path, id));
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

function governedQualityAsset(assetNumber = 7) {
  return {
    assetType: 'furnace',
    assetNumber,
    assetHierarchyRef: {
      schemaVersion: 4,
      scope: 'componentDefinitionOnAsset',
      assetClassId: 'furnace-class',
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      nodeId: 'burner-block',
      nodeVersion: 2,
      nodeName: 'Burner block',
      assetInstanceId: `furnace-${assetNumber}`,
      assetInstanceVersion: 3,
      assetNumber,
      assetInstanceName: `Furnace ${assetNumber}`,
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: ['Furnace', 'Combustion system', 'Burner block'],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Mechanical',
      accountableRoleKeys: ['contractSupervisor'],
      innerCoverAssociation: null,
    },
  };
}

function qualityWarning(warningId, overrides = {}) {
  const sourceId = warningId.replace(/^issue_/, '');
  return {
    schemaVersion: 1,
    warningId,
    sourceType: 'issue',
    sourceId,
    sourceVersion: 1,
    sourceChargeNo: 51139,
    sourceSummary: 'Atmosphere interruption during the cycle.',
    sourceSeverity: 'high',
    warningReason: 'Review the affected charge before release.',
    affectedAssets: [governedQualityAsset()],
    component: 'Atmosphere control',
    status: 'open',
    closureRequestReason: null,
    closureRequestedAt: null,
    closureRequestedByUid: null,
    closureRequestedByName: null,
    closedAt: null,
    closedByUid: null,
    closedByName: null,
    closureDisposition: null,
    linkedReannealingChargeNos: [],
    decisionReason: null,
    createdAt: '2026-08-29T05:00:00.000Z',
    createdByUid: 'ops-1',
    createdByName: 'Operations One',
    updatedAt: '2026-08-29T05:00:00.000Z',
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    version: 1,
    ...overrides,
  };
}

function inspectionFinding(findingId, overrides = {}) {
  return {
    schemaVersion: 1,
    findingId,
    version: 1,
    campaignId: 'campaign-1',
    targetKey: `target-${findingId}`,
    assetTypeKey: 'furnace',
    assetNumber: 7,
    assetClassId: 'furnace-class',
    assetInstanceId: 'furnace-7',
    hostAssetNumber: null,
    subjectSerialNumber: null,
    componentNodeId: 'burner-block',
    componentName: 'Burner block',
    physicalPosition: 'Burner 3',
    status: 'open',
    firstObservationId: `first-${findingId}`,
    currentObservationId: `current-${findingId}`,
    firstObservedAt: '2026-08-29T05:00:00.000Z',
    latestObservedAt: '2026-08-30T05:00:00.000Z',
    recurrenceCount: 1,
    linkedTicketId: null,
    verificationCount: 0,
    lastVerificationOutcome: null,
    updatedAt: '2026-08-30T05:00:00.000Z',
    ...overrides,
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

  test('rejects malformed replay result identity instead of confirming it', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    const receiptPath = `morning_review_mutation_receipts/${IDS.start}`;
    const receipt = memory.store.get(receiptPath);
    memory.store.set(receiptPath, {
      ...receipt,
      result: {...receipt.result, sessionId: 'wrong-day'},
    });

    await expect(invoke(memory, 'si-1', startRequest())).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'morning-review-receipt-result-malformed'},
    });

    const statusMemory = fakeDb(baseSeed());
    await invoke(statusMemory, 'si-1', startRequest());
    const statusReceipt = statusMemory.store.get(receiptPath);
    statusMemory.store.set(receiptPath, {
      ...statusReceipt,
      result: {...statusReceipt.result, status: 'finalized'},
    });
    await expect(invoke(statusMemory, 'si-1', startRequest()))
      .rejects.toMatchObject({
        code: 'data-loss',
        details: {reasonCode: 'morning-review-receipt-result-malformed'},
      });
  });

  test('captures active condition projections and prior-day burner closure evidence', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_burner_closures/burner-1': {
        sourceMaintenanceId: 'burner-1',
        sourceVersion: 4,
        updatedAt: '2026-08-30T06:30:00.000Z',
      },
      'maintenance_records/burner-1': {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        version: 4,
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
      'asset_operational_conditions/base-202': {
        active: false,
        condition: 'down',
        assetClassId: 'base-class',
        assetClassName: 'Base',
        assetInstanceId: 'base-202',
        assetNumber: 202,
        reason: 'Hydraulic clamp restored.',
        restoredAt: '2026-08-30T07:00:00.000Z',
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
    expect(facts.find((fact) => fact.factId ===
      'asset_operational_conditions/base-202'))
      .toMatchObject({status: 'restored', assetNumber: '202'});
  });

  test('a stale burner closure cannot hide its reopened maintenance issue', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_records/reopened-burner': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        version: 9,
        assetType: 'furnace',
        assetNumber: 12,
        description: 'Burner lockout requires further work.',
        reopenedAt: '2026-08-30T07:00:00.000Z',
      },
      'maintenance_burner_closures/reopened-burner': {
        sourceMaintenanceId: 'reopened-burner',
        sourceVersion: 8,
        updatedAt: '2026-08-30T06:30:00.000Z',
      },
    });

    await invoke(memory, 'si-1', startRequest());
    const facts = memory.store.get(`morning_review_sessions/${sessionId}`).sourceFacts;
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/reopened-burner')).toMatchObject({
      status: 'open',
      assetNumber: '12',
    });
    expect(facts.find((fact) => fact.factId ===
      'maintenance_burner_closures/reopened-burner')).toMatchObject({
      status: 'resolved',
      assetNumber: '12',
    });
  });

  test('captures native quality warning states with truthful asset scope', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'quality_warnings/issue_quality-open': qualityWarning(
        'issue_quality-open',
      ),
      'quality_warnings/issue_quality-requested': qualityWarning(
        'issue_quality-requested',
        {
          status: 'closureRequested',
          closureRequestReason: 'Quality review is ready for adjudication.',
          closureRequestedAt: '2026-08-30T05:30:00.000Z',
          closureRequestedByUid: 'ops-1',
          closureRequestedByName: 'Operations One',
          updatedAt: '2026-08-30T05:30:00.000Z',
        },
      ),
      'quality_warnings/issue_quality-closed': qualityWarning(
        'issue_quality-closed',
        {
          status: 'closed',
          closedAt: '2026-08-30T06:00:00.000Z',
          closedByUid: 'si-1',
          closedByName: 'SI One',
          closureDisposition: 'coilFoundAcceptable',
          decisionReason: 'Inspection confirmed the charge was acceptable.',
          updatedAt: '2026-08-30T06:00:00.000Z',
        },
      ),
      'quality_warnings/issue_quality-old': qualityWarning(
        'issue_quality-old',
        {
          status: 'closed',
          createdAt: '2026-08-01T05:00:00.000Z',
          closedAt: '2026-08-20T06:00:00.000Z',
          closedByUid: 'si-1',
          closedByName: 'SI One',
          closureDisposition: 'coilFoundAcceptable',
          decisionReason: 'Historical warning already reviewed.',
          updatedAt: '2026-08-20T06:00:00.000Z',
        },
      ),
      'quality_warnings/issue_quality-shared': qualityWarning(
        'issue_quality-shared',
        {
          affectedAssets: [
            {assetType: 'furnace', assetNumber: 7},
            {assetType: 'base', assetNumber: 205},
          ],
        },
      ),
      'quality_warnings/issue_quality-malformed': qualityWarning(
        'issue_quality-malformed',
        {sourceSummary: null},
      ),
    });

    const capture = await collectMorningReviewSourceFacts({
      db: memory.db,
      plantDay: sessionId,
      capturedAt: meetingTime,
    });
    const open = capture.facts.find((fact) =>
      fact.factId === 'quality_warnings/issue_quality-open');
    expect(open).toMatchObject({
      sourceType: 'qualityWarning',
      section: 'furnace',
      status: 'open',
      assetClassId: 'furnace-class',
      assetInstanceId: 'furnace-7',
      assetNumber: '7',
    });
    expect(capture.facts.find((fact) =>
      fact.factId === 'quality_warnings/issue_quality-requested'))
      .toMatchObject({status: 'closureRequested'});
    expect(capture.facts.find((fact) =>
      fact.factId === 'quality_warnings/issue_quality-closed'))
      .toMatchObject({
        status: 'closed',
        observedAtIso: '2026-08-30T06:00:00.000Z',
      });
    expect(capture.facts.some((fact) =>
      fact.factId === 'quality_warnings/issue_quality-old')).toBe(false);
    const shared = capture.facts.find((fact) =>
      fact.factId === 'quality_warnings/issue_quality-shared');
    expect(shared).toMatchObject({
      section: 'plantWide',
      assetClassId: null,
      assetInstanceId: null,
      assetNumber: null,
    });
    expect(shared.summary).toContain('Furnace 7');
    expect(shared.summary).toContain('Base 205');
    expect(capture.sourceCollectionsAtLimit).toContain('quality_warnings');
  });

  test('captures native inspection findings and installed cover identity', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'inspection_findings/finding-cooler': inspectionFinding(
        'finding-cooler',
        {
          assetTypeKey: 'forceCooler',
          assetNumber: 4,
          assetClassId: 'cooler-class',
          assetInstanceId: 'cooler-4',
        },
      ),
      'inspection_findings/finding-cover': inspectionFinding(
        'finding-cover',
        {
          assetTypeKey: 'innerCover',
          assetNumber: 205,
          assetClassId: 'inner-cover-class',
          assetInstanceId: 'inner-cover-n4',
          hostAssetNumber: 205,
          subjectSerialNumber: 'N4',
          componentNodeId: 'inner-cover-shell',
          componentName: 'Inner Cover shell',
          physicalPosition: 'Crown',
          status: 'awaitingVerification',
        },
      ),
      'inspection_findings/finding-accepted': inspectionFinding(
        'finding-accepted',
        {
          status: 'acceptedCondition',
          updatedAt: '2026-08-30T06:00:00.000Z',
        },
      ),
      'inspection_findings/finding-old': inspectionFinding(
        'finding-old',
        {
          status: 'verifiedResolved',
          firstObservedAt: '2026-08-01T05:00:00.000Z',
          latestObservedAt: '2026-08-02T05:00:00.000Z',
          updatedAt: '2026-08-20T06:00:00.000Z',
          lastVerificationOutcome: 'resolved',
        },
      ),
      'inspection_findings/finding-malformed': inspectionFinding(
        'finding-malformed',
        {recurrenceCount: 0},
      ),
    });

    const capture = await collectMorningReviewSourceFacts({
      db: memory.db,
      plantDay: sessionId,
      capturedAt: meetingTime,
    });
    expect(capture.facts.find((fact) =>
      fact.factId === 'inspection_findings/finding-cooler')).toMatchObject({
      sourceType: 'inspectionFinding',
      section: 'forcedCooler',
      assetClassName: 'Forced Cooler',
      assetNumber: '4',
    });
    const cover = capture.facts.find((fact) =>
      fact.factId === 'inspection_findings/finding-cover');
    expect(cover).toMatchObject({
      section: 'base',
      status: 'awaitingVerification',
      assetClassName: 'Inner Cover',
      assetInstanceId: 'inner-cover-n4',
      assetNumber: 'N4',
    });
    expect(cover.summary).toContain('installed at Base 205');
    expect(capture.facts.find((fact) =>
      fact.factId === 'inspection_findings/finding-accepted'))
      .toMatchObject({
        status: 'acceptedCondition',
        observedAtIso: '2026-08-30T06:00:00.000Z',
      });
    expect(capture.facts.some((fact) =>
      fact.factId === 'inspection_findings/finding-old')).toBe(false);
    expect(capture.sourceCollectionsAtLimit).toContain('inspection_findings');
  });

  test('bounds incomplete-source markers for existing client readers', async () => {
    const seed = baseSeed();
    const longId = 'x'.repeat(241);
    for (const collection of [
      'critical_alarms',
      'maintenance_records',
      'maintenance_burner_closures',
      'job_executions',
      'asset_operational_conditions',
      'asset_availability_current',
      'quality_warnings',
      'inspection_findings',
      'operational_events',
      'directives',
      'morning_review_actions',
    ]) {
      seed[`${collection}/${longId}`] = {};
    }
    const capture = await collectMorningReviewSourceFacts({
      db: fakeDb(seed).db,
      plantDay: sessionId,
      capturedAt: meetingTime,
    });

    expect(capture.sourceCollectionsAtLimit).toHaveLength(10);
    expect(capture.sourceCollectionsAtLimit).toContain(
      'additional_source_collections',
    );
  });

  test('retains active obligations before terminal history at the fact cap', async () => {
    const seed = {
      ...baseSeed(),
      'inspection_findings/finding-active': inspectionFinding(
        'finding-active',
      ),
    };
    for (let index = 0; index < 220; index += 1) {
      seed[`maintenance_records/resolved-${index}`] = {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: index + 1,
        description: `Resolved issue ${index}`,
        endDate: '2026-08-30T05:00:00.000Z',
      };
    }
    const capture = await collectMorningReviewSourceFacts({
      db: fakeDb(seed).db,
      plantDay: sessionId,
      capturedAt: meetingTime,
    });

    expect(capture.facts).toHaveLength(220);
    expect(capture.facts.some((fact) =>
      fact.factId === 'inspection_findings/finding-active')).toBe(true);
    expect(capture.sourceCollectionsAtLimit).toContain(
      'morning_review_compiled_source_facts',
    );
  });

  test('paginates source capture without treating an exact page as incomplete', async () => {
    const seed = baseSeed();
    for (let index = 0; index < 300; index += 1) {
      seed[`maintenance_records/${String(index).padStart(4, '0')}`] = {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: index + 1,
        endDate: '2026-08-01T00:00:00.000Z',
      };
    }
    const exactPage = await collectMorningReviewSourceFacts({
      db: fakeDb(seed).db,
      plantDay: sessionId,
      capturedAt: new Date('2026-08-31T03:00:00.000Z'),
    });
    expect(exactPage.sourceCollectionsAtLimit).not.toContain(
      'maintenance_records',
    );

    seed['maintenance_records/0300'] = {
      status: 'open',
      isResolved: false,
      isDeleted: false,
      assetType: 'furnace',
      assetNumber: 26,
      description: 'Active issue beyond the first source page.',
    };
    const nextPage = await collectMorningReviewSourceFacts({
      db: fakeDb(seed).db,
      plantDay: sessionId,
      capturedAt: new Date('2026-08-31T03:00:00.000Z'),
    });
    expect(nextPage.sourceCollectionsAtLimit).not.toContain(
      'maintenance_records',
    );
    expect(nextPage.facts.some((fact) =>
      fact.factId === 'maintenance_records/0300',
    )).toBe(true);
  });

  test('does not present a post-capture mutation as opening-time evidence', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_records/known-at-opening': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 21,
        description: 'Known before the meeting opened.',
        updatedAt: '2026-08-31T02:59:00.000Z',
      },
      'maintenance_records/changed-after-opening': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 22,
        description: 'Changed while source capture was running.',
        updatedAt: '2026-08-31T03:01:00.000Z',
      },
    });

    const capture = await collectMorningReviewSourceFacts({
      db: memory.db,
      plantDay: sessionId,
      capturedAt: new Date('2026-08-31T03:00:00.000Z'),
    });

    expect(capture.facts.some((fact) =>
      fact.factId === 'maintenance_records/known-at-opening',
    )).toBe(true);
    expect(capture.facts.some((fact) =>
      fact.factId === 'maintenance_records/changed-after-opening',
    )).toBe(false);
    expect(capture.sourceCollectionsAtLimit).toContain('maintenance_records');
  });

  test('interprets legacy timezone-less source updates as India plant time', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_records/local-before-opening': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 21,
        description: 'Updated at 08:00 India plant time.',
        updatedAt: '2026-08-31T08:00:00.000',
      },
      'maintenance_records/local-after-opening': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 22,
        description: 'Updated at 08:31 India plant time.',
        updatedAt: '2026-08-31T08:31:00.000',
      },
    });

    const capture = await collectMorningReviewSourceFacts({
      db: memory.db,
      plantDay: sessionId,
      capturedAt: new Date('2026-08-31T03:00:00.000Z'),
    });

    expect(capture.facts.some((fact) =>
      fact.factId === 'maintenance_records/local-before-opening')).toBe(true);
    expect(capture.facts.some((fact) =>
      fact.factId === 'maintenance_records/local-after-opening')).toBe(false);
    expect(capture.sourceCollectionsAtLimit).toContain('maintenance_records');
  });

  test('uses governed identity and source-specific relevance without duplicate issues', async () => {
    const hierarchy = {
      schemaVersion: 3,
      scope: 'physicalAsset',
      assetClassId: 'furnace-class',
      assetClassCode: 'FUR',
      assetClassName: 'Furnace',
      nodeId: 'furnace-root',
      nodeVersion: 1,
      nodeName: 'Furnace',
      assetInstanceId: 'furnace-7',
      assetInstanceVersion: 1,
      assetNumber: 7,
      assetInstanceName: 'Furnace 7',
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: ['Furnace'],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Mechanical',
      accountableRoleKeys: ['seniorMechanical'],
      innerCoverAssociation: null,
    };
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_records/hierarchy-ticket': {
        status: 'open',
        isResolved: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 7,
        assetHierarchyRefJson: JSON.stringify(hierarchy),
        description: 'Furnace 7 burner investigation.',
        createdAt: '2026-08-29T05:00:00.000Z',
      },
      'maintenance_records/still-relevant': {
        status: 'closedWithoutResolution',
        isResolved: true,
        isDeleted: false,
        issueClosureDisposition: 'stillRelevant',
        issueClosureReason: 'The shared crane constraint remains active.',
        assetType: 'base',
        assetNumber: 113,
        description: 'Crane constraint remains relevant.',
        endDate: '2026-08-01T05:00:00.000Z',
      },
      'maintenance_records/relevance-ended': {
        status: 'closedWithoutResolution',
        isResolved: true,
        isDeleted: false,
        issueClosureDisposition: 'relevanceEnded',
        assetType: 'base',
        assetNumber: 114,
        description: 'Old constraint no longer relevant.',
        endDate: '2026-08-01T05:00:00.000Z',
        updatedAt: '2026-08-01T05:00:00.000Z',
      },
      'maintenance_records/resolved-this-morning': {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 7,
        description: 'Draft seal restored before the meeting.',
        endDate: '2026-08-31T02:30:00.000Z',
      },
      'maintenance_records/burner-parent': {
        status: 'resolved',
        isResolved: true,
        isDeleted: false,
        version: 8,
        assetType: 'furnace',
        assetNumber: 26,
        description: 'Burner lockout restored.',
        endDate: '2026-08-30T05:00:00.000Z',
      },
      'maintenance_burner_closures/burner-evidence': {
        sourceMaintenanceId: 'burner-parent',
        sourceVersion: 8,
        updatedAt: '2026-08-30T05:00:00.000Z',
      },
      'asset_availability_current/clear-with-generic-update': {
        availabilityState: 'clear',
        assetType: 'furnace',
        assetNumber: 9,
        updatedAt: '2026-08-30T05:00:00.000Z',
      },
      'job_executions/governed-job': {
        isCompleted: false,
        isCancelled: false,
        isDeleted: false,
        assetType: 'furnace',
        assetNumber: 7,
        templateName: 'Furnace pressure inspection',
        metadataJson: JSON.stringify({
          assignmentAssetIdentity: {
            assetClassId: 'furnace-class',
            assetInstanceId: 'furnace-7',
            assetNumber: 7,
          },
          jobTemplateSnapshot: {
            assetHierarchyRefJson: JSON.stringify(hierarchy),
          },
        }),
        createdAt: '2026-08-29T05:00:00.000Z',
      },
      'job_executions/metadata-only-job': {
        isCompleted: false,
        isCancelled: false,
        isDeleted: false,
        templateName: 'Inner Cover inspection',
        metadataJson: JSON.stringify({
          assignmentAssetIdentity: {
            assetClassId: 'inner-cover-class',
            assetClassName: 'Inner Cover',
            assetInstanceId: 'inner-cover-n4',
            assetNumber: 'N4',
          },
        }),
        createdAt: '2026-08-29T05:00:00.000Z',
      },
      'maintenance_records/long-summary': {
        status: 'closedWithoutResolution',
        isResolved: true,
        isDeleted: false,
        issueClosureDisposition: 'stillRelevant',
        issueClosureReason: 'R'.repeat(420),
        assetType: 'base',
        assetNumber: 116,
        description: 'D'.repeat(420),
        endDate: '2026-08-01T05:00:00.000Z',
      },
      'job_executions/completed-job': {
        isCompleted: true,
        isCancelled: false,
        isDeleted: false,
        assetType: 'forcedCooler',
        assetNumber: 8,
        templateName: 'Forced Cooler alignment',
        completedAt: '2026-08-30T06:00:00.000Z',
        updatedAt: '2026-08-30T06:00:00.000Z',
        createdAt: '2026-08-29T05:00:00.000Z',
      },
      'job_executions/cancelled-job': {
        isCompleted: false,
        isCancelled: true,
        isDeleted: false,
        assetType: 'base',
        assetNumber: 115,
        templateName: 'Base seal inspection',
        cancelledAt: '2026-08-30T06:30:00.000Z',
        updatedAt: '2026-08-30T06:30:00.000Z',
        createdAt: '2026-08-29T05:00:00.000Z',
      },
      'morning_review_actions/carried-action': {
        status: 'accepted',
        text: 'Confirm Furnace 7 burner health.',
        assetClassId: 'furnace-class',
        assetClassName: 'Furnace',
        assetInstanceId: 'furnace-7',
        assetNumber: '7',
        createdAt: '2026-08-28T05:00:00.000Z',
        updatedAt: '2026-08-30T05:00:00.000Z',
      },
    });

    await invoke(memory, 'si-1', startRequest());
    const facts = memory.store.get(`morning_review_sessions/${sessionId}`).sourceFacts;
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/hierarchy-ticket')).toMatchObject({
      assetClassId: 'furnace-class',
      assetInstanceId: 'furnace-7',
      assetNumber: '7',
    });
    expect(facts.find((fact) => fact.factId ===
      'job_executions/governed-job')).toMatchObject({
      assetClassId: 'furnace-class',
      assetInstanceId: 'furnace-7',
      assetNumber: '7',
      assetClassName: 'Furnace',
      status: 'open',
    });
    expect(facts.find((fact) => fact.factId ===
      'job_executions/metadata-only-job')).toMatchObject({
      assetClassId: 'inner-cover-class',
      assetClassName: 'Inner Cover',
      assetInstanceId: 'inner-cover-n4',
      assetNumber: 'N4',
      section: 'base',
    });
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/long-summary').summary.length).toBeLessThanOrEqual(500);
    expect(facts.find((fact) => fact.factId ===
      'job_executions/completed-job')).toMatchObject({
      assetClassName: 'Forced Cooler',
      status: 'completed',
      observedAtIso: '2026-08-30T06:00:00.000Z',
    });
    expect(facts.find((fact) => fact.factId ===
      'job_executions/cancelled-job')).toMatchObject({
      assetClassName: 'Base',
      status: 'cancelled',
      observedAtIso: '2026-08-30T06:30:00.000Z',
    });
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/still-relevant')).toMatchObject({
      status: 'closed without resolution · still relevant',
    });
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/still-relevant').summary)
      .toContain('The shared crane constraint remains active.');
    expect(facts.some((fact) => fact.factId ===
      'maintenance_records/relevance-ended')).toBe(false);
    expect(facts.find((fact) => fact.factId ===
      'maintenance_records/resolved-this-morning')).toMatchObject({
      status: 'resolved',
      observedAtIso: '2026-08-31T02:30:00.000Z',
    });
    expect(facts.some((fact) => fact.factId ===
      'asset_availability_current/clear-with-generic-update')).toBe(false);
    expect(facts.some((fact) => fact.factId ===
      'maintenance_records/burner-parent')).toBe(false);
    expect(facts.some((fact) => fact.factId ===
      'maintenance_burner_closures/burner-evidence')).toBe(true);
    expect(facts.find((fact) => fact.factId ===
      'maintenance_burner_closures/burner-evidence')).toMatchObject({
      status: 'resolved',
    });
    expect(facts.find((fact) => fact.factId ===
      'morning_review_actions/carried-action')).toMatchObject({
      observedAtIso: '2026-08-30T05:00:00.000Z',
      status: 'accepted',
    });
  });

  test('records a joined participant carried-action completion in today meeting', async () => {
    const priorActionId = 'prior-action';
    const memory = fakeDb({
      ...baseSeed(),
      [`morning_review_actions/${priorActionId}`]: {
        schemaVersion: 1,
        actionId: priorActionId,
        sessionId: '2026-08-30',
        originPlantDay: '2026-08-30',
        section: 'furnace',
        text: 'Confirm Furnace 7 burner health.',
        assetClassId: 'furnace-class',
        assetClassName: 'Furnace',
        assetInstanceId: 'furnace-7',
        assetNumber: '7',
        assigneeUid: 'ops-1',
        assigneeName: 'Operations One',
        assigneeRole: null,
        status: 'accepted',
        version: 1,
        createdAt: '2026-08-30T03:00:00.000Z',
      },
    });
    await invoke(memory, 'si-1', startRequest());
    await invoke(memory, 'ops-1', {
      requestId: IDS.join,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    });

    await invoke(memory, 'ops-1', {
      requestId: IDS.complete,
      operation: 'COMPLETE_MORNING_REVIEW_ACTION',
      sessionId: '2026-08-30',
      actionId: priorActionId,
      expectedVersion: 1,
      reason: 'Burner health verified in service.',
    });

    expect(memory.store.get(`morning_review_actions/${priorActionId}`))
      .toMatchObject({status: 'completed', version: 2});
    const completionEntryId = `action-completed-v2-${IDS.complete}`;
    expect(memory.store.get(`morning_review_entries/${completionEntryId}`))
      .toMatchObject({
        sessionId,
        kind: 'currentCompliance',
        sourceReferences: [`morning_review_actions/${priorActionId}`],
        authorUid: 'ops-1',
        entryId: completionEntryId,
        createdAt: meetingTime,
      });
    expect(memory.store.get(`morning_review_entries/${completionEntryId}`).text)
      .toContain(priorActionId);
    expect(memory.store.get(`morning_review_sessions/${sessionId}`).version)
      .toBe(3);
    // The Flutter agenda test decodes this same contract. Compare the actual
    // native command output and immutable capture, not a copied transition.
    const contract = require('../../test/fixtures/morning_review_native_completion_v1.json');
    expect(JSON.parse(JSON.stringify(memory.store.get(
      `morning_review_entries/${completionEntryId}`,
    )))).toEqual(contract.entry);
    expect(memory.store.get(`morning_review_sessions/${sessionId}`).sourceFacts
      .find((fact) => fact.factId === `morning_review_actions/${priorActionId}`))
      .toEqual(contract.fact);
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

  test('rejects an entry that would make finalization exceed capacity', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    for (let index = 0; index < 180; index += 1) {
      memory.store.set(`morning_review_entries/existing-${index}`, {
        sessionId,
      });
    }

    await expect(invoke(memory, 'si-1', entryRequest()))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'morning-review-entry-capacity-reached'},
      });
    expect(memory.store.has(`morning_review_entries/${IDS.entry}`))
      .toBe(false);
  });

  test('preserves issue-derived Unfit separately from lifecycle in source capture', async () => {
    const memory = fakeDb({
      ...baseSeed(),
      'maintenance_records/unfit-issue': {
        ...baseSeed()['maintenance_records/ticket-1'],
        plantConditionEffect: 'unfit',
      },
      'maintenance_records/closed-unfit': {
        ...baseSeed()['maintenance_records/ticket-1'],
        status: 'resolved', isResolved: true,
        plantConditionEffect: 'unfit',
        endDate: '2026-08-30T06:30:00.000Z',
      },
    });
    const capture = await collectMorningReviewSourceFacts({
      db: memory.db, plantDay: sessionId, capturedAt: meetingTime,
    });
    expect(capture.facts.find((fact) => fact.sourceDocumentId === 'unfit-issue'))
      .toMatchObject({status: 'open', sourceType: 'maintenanceIssue:unfit'});
    expect(capture.facts.find((fact) => fact.sourceDocumentId === 'closed-unfit')
      .sourceType).toBe('maintenanceIssue');
  });

  test('ordinary entry requests cannot forge the reserved completion identity', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    const requestId = `action-completed-v2-${IDS.entry}`;
    await expect(invoke(memory, 'si-1', entryRequest({requestId})))
      .rejects.toMatchObject({code: 'invalid-argument'});
    expect(memory.store.has(`morning_review_entries/${requestId}`)).toBe(false);
  });

  test('admission rejects excess UTF-8 content while accepted entries can still finalize', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    let rejectedRequestId = null;
    let accepted = 0;
    for (let index = 0; index < 160; index += 1) {
      const requestId = `10000000-0000-4000-8000-${String(index).padStart(12, '0')}`;
      const request = entryRequest({requestId});
      request.entryDraft.text = 'अ'.repeat(2000);
      try {
        await invoke(memory, 'si-1', request);
        accepted += 1;
      } catch (error) {
        expect(error).toMatchObject({
          code: 'failed-precondition',
          details: {reasonCode: 'morning-review-content-capacity-reached'},
        });
        rejectedRequestId = requestId;
        break;
      }
    }
    expect(accepted).toBeGreaterThan(0);
    expect(rejectedRequestId).not.toBeNull();
    expect(memory.store.has(`morning_review_entries/${rejectedRequestId}`)).toBe(false);
    const session = memory.store.get(`morning_review_sessions/${sessionId}`);
    await invoke(memory, 'si-1', {
      requestId: IDS.finalize, operation: 'FINALIZE_MORNING_REVIEW', sessionId,
      expectedVersion: session.version, summary: 'अ'.repeat(2000),
    });
    expect(memory.store.get(`morning_review_documents/${sessionId}`).entries)
      .toHaveLength(accepted);
  });

  test('rejects a join that would make finalization exceed capacity', async () => {
    const memory = fakeDb(baseSeed());
    await invoke(memory, 'si-1', startRequest());
    for (let index = 1; index < 100; index += 1) {
      memory.store.set(`morning_review_participants/existing-${index}`, {
        sessionId,
        userUid: `existing-${index}`,
        state: 'joined',
      });
    }

    await expect(invoke(memory, 'contract-1', {
      requestId: IDS.join,
      operation: 'JOIN_MORNING_REVIEW',
      sessionId,
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'morning-review-participant-capacity-reached'},
    });
    expect(memory.store.has(
      `morning_review_participants/${sessionId}_contract-1`,
    )).toBe(false);
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
