const {
  mutateOperationalEventIssueLinkWithDb,
  parseOperationalEventIssueLinkRequest,
  userCanLinkOperationalEventIssue,
} = require('../lib/operationalEventIssueLinkMutation');

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
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {id, path, async get() { return snapshot(path, id); }};
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
  event: '11111111-1111-4111-8111-111111111111',
  issue: '22222222-2222-4222-8222-222222222222',
  request: '33333333-3333-4333-8333-333333333333',
  duplicate: '44444444-4444-4444-8444-444444444444',
  eventMutation: '55555555-5555-4555-8555-555555555555',
  asset: '66666666-6666-4666-8666-666666666666',
  assetClass: '77777777-7777-4777-8777-777777777777',
  otherAsset: '88888888-8888-4888-8888-888888888888',
};

function user(role, name = role) {
  return {isApproved: true, roles: [role], name};
}

function persistedEvent(overrides = {}) {
  return {
    schemaVersion: 1,
    eventId: IDS.event,
    eventType: 'powerTrip',
    title: 'Incoming power interruption',
    description: 'Incoming supply was lost across the annealing shop.',
    severity: 'critical',
    scope: 'assets',
    affectedAssetClassIds: [IDS.assetClass],
    affectedAssetInstanceIds: [IDS.asset],
    completedIntervals: [],
    startedAt: new Date('2026-08-14T10:00:00.000Z'),
    status: 'open',
    createdAt: new Date('2026-08-14T10:05:00.000Z'),
    createdByUid: 'ops-1',
    createdByName: 'Operations One',
    resolvedAt: null,
    resolvedByUid: null,
    resolvedByName: null,
    resolutionNote: null,
    version: 1,
    updatedAt: new Date('2026-08-14T10:05:00.000Z'),
    updatedByUid: 'ops-1',
    updatedByName: 'Operations One',
    lastMutationId: IDS.eventMutation,
    ...overrides,
  };
}

function assetReference(overrides = {}) {
  return JSON.stringify({
    schemaVersion: 3,
    scope: 'physicalAsset',
    assetClassId: IDS.assetClass,
    assetInstanceId: IDS.asset,
    ...overrides,
  });
}

function persistedIssue(overrides = {}) {
  return {
    firestoreId: IDS.issue,
    version: 4,
    status: 'open',
    isResolved: false,
    isDeleted: false,
    assetType: 'furnace',
    assetNumber: 7,
    assetHierarchyRefJson: assetReference(),
    description: 'Inspect controls following the incoming power interruption.',
    routedTo: 'electrical',
    component: 'Control panel',
    subsystem: 'Power distribution',
    tag: 'MCC-07',
    startDate: '2026-08-14T10:10:00.000Z',
    createdAt: '2026-08-14T10:12:00.000Z',
    updatedAt: '2026-08-14T10:12:00.000Z',
    ...overrides,
  };
}

function request(overrides = {}) {
  return {
    requestId: IDS.request,
    operation: 'LINK_OPERATIONAL_EVENT_ISSUE',
    eventId: IDS.event,
    issueId: IDS.issue,
    expectedEventVersion: 1,
    expectedIssueVersion: 4,
    relationship: 'responseToEvent',
    reason: 'Electrical inspection was raised to verify safe restoration.',
    ...overrides,
  };
}

function baseSeed(overrides = {}) {
  return {
    'users/ops-1': user('operations', 'Operations One'),
    'users/mech-1': user('mechanical', 'Mechanical One'),
    [`operational_events/${IDS.event}`]: persistedEvent(),
    [`maintenance_records/${IDS.issue}`]: persistedIssue(),
    ...overrides,
  };
}

async function invoke(
  memory,
  authUid = 'ops-1',
  data = request(),
) {
  return mutateOperationalEventIssueLinkWithDb({
    db: memory.db,
    authUid,
    data,
    now: () => new Date('2026-08-14T12:00:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('operational event issue-link mutation', () => {
  test('parses the exact command and enforces operational authority', () => {
    expect(parseOperationalEventIssueLinkRequest(request())).toMatchObject({
      eventId: IDS.event,
      issueId: IDS.issue,
      relationship: 'responseToEvent',
    });
    expect(() => parseOperationalEventIssueLinkRequest({
      ...request(),
      unsupported: true,
    })).toThrow('unsupported is unsupported');
    expect(userCanLinkOperationalEventIssue(user('operations'))).toBe(true);
    expect(userCanLinkOperationalEventIssue(user('contractSupervisor'))).toBe(true);
    expect(userCanLinkOperationalEventIssue(user('mechanical'))).toBe(false);
  });

  test('atomically writes projections, immutable link, audit, and receipt', async () => {
    const memory = fakeDb(baseSeed());
    const result = await invoke(memory);
    expect(result).toMatchObject({
      ok: true,
      eventId: IDS.event,
      issueId: IDS.issue,
      eventVersion: 2,
      issueVersion: 5,
      idempotentReplay: false,
    });
    expect(result.linkId).toMatch(/^event_issue_[0-9a-f]{48}$/);
    expect(memory.store.get(`operational_events/${IDS.event}`)).toMatchObject({
      issueLinkIds: [result.linkId],
      linkedIssueIds: [IDS.issue],
      version: 2,
      lastMutationId: IDS.request,
    });
    expect(memory.store.get(`maintenance_records/${IDS.issue}`)).toMatchObject({
      operationalEventIssueLinkIds: [result.linkId],
      version: 5,
    });
    expect(memory.store.get(
      `operational_event_issue_links/${result.linkId}`,
    )).toMatchObject({
      eventId: IDS.event,
      issueId: IDS.issue,
      eventVersionAtLink: 1,
      issueVersionAtLink: 4,
      issueAssetClassId: IDS.assetClass,
      issueAssetInstanceId: IDS.asset,
      relationship: 'responseToEvent',
      linkedByUid: 'ops-1',
    });
    expect(memory.store.get(
      `operational_event_issue_link_audits/operational_event_issue_${IDS.request}`,
    )).toMatchObject({requestId: IDS.request, linkId: result.linkId});
    expect(memory.store.get(
      `operational_event_issue_link_receipts/${IDS.request}`,
    )).toMatchObject({linkId: result.linkId, eventVersion: 2, issueVersion: 5});

    const writesBeforeReplay = memory.writes.length;
    const replay = await invoke(memory);
    expect(replay).toMatchObject({
      linkId: result.linkId,
      idempotentReplay: true,
    });
    expect(memory.writes).toHaveLength(writesBeforeReplay);
  });

  test('replays from immutable evidence after event and issue lifecycle changes', async () => {
    const memory = fakeDb(baseSeed());
    const first = await invoke(memory);
    const writesBeforeReplay = memory.writes.length;

    memory.store.delete(`operational_events/${IDS.event}`);
    memory.store.delete(`maintenance_records/${IDS.issue}`);

    await expect(invoke(memory)).resolves.toMatchObject({
      linkId: first.linkId,
      eventVersion: first.eventVersion,
      issueVersion: first.issueVersion,
      committedAt: first.committedAt,
      idempotentReplay: true,
    });
    expect(memory.writes).toHaveLength(writesBeforeReplay);
  });

  test('rejects replay when immutable link evidence has drifted', async () => {
    const memory = fakeDb(baseSeed());
    const first = await invoke(memory);
    memory.store.set(`operational_event_issue_links/${first.linkId}`, {
      ...memory.store.get(`operational_event_issue_links/${first.linkId}`),
      relationship: 'affectedByEvent',
    });

    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'data-loss',
      details: {
        reasonCode: 'operational-event-issue-link-replay-evidence-drift',
      },
    });
  });

  test('requires exact event and issue versions', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(memory, 'ops-1', request({
      expectedIssueVersion: 3,
    }))).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'operational-event-issue-link-version-mismatch'},
    });
    expect(memory.writes).toHaveLength(0);
  });

  test('rejects issue identity outside a governed scoped event', async () => {
    const memory = fakeDb(baseSeed({
      [`maintenance_records/${IDS.issue}`]: persistedIssue({
        assetHierarchyRefJson: assetReference({
          assetInstanceId: IDS.otherAsset,
        }),
      }),
    }));
    await expect(invoke(memory)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-link-scope-mismatch'},
    });
    expect(memory.writes).toHaveLength(0);
  });

  test('rejects malformed saved projections and duplicate occurrence links', async () => {
    const malformed = fakeDb(baseSeed({
      [`operational_events/${IDS.event}`]: persistedEvent({
        issueLinkIds: ['duplicate', 'duplicate'],
      }),
    }));
    await expect(invoke(malformed)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-projection-malformed'},
    });

    const memory = fakeDb(baseSeed());
    await invoke(memory);
    await expect(invoke(memory, 'ops-1', request({
      requestId: IDS.duplicate,
      expectedEventVersion: 2,
      expectedIssueVersion: 5,
    }))).rejects.toMatchObject({
      code: 'already-exists',
      details: {reasonCode: 'operational-event-issue-link-already-exists'},
    });
  });

  test('fails closed on malformed optional issue evidence and reference scope', async () => {
    for (const [field, value] of [
      ['component', 42],
      ['subsystem', {name: 'Power distribution'}],
      ['tag', 'x'.repeat(201)],
    ]) {
      const malformed = fakeDb(baseSeed({
        [`maintenance_records/${IDS.issue}`]: persistedIssue({[field]: value}),
      }));
      await expect(invoke(malformed)).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {
          reasonCode: 'operational-event-link-issue-malformed',
          field,
        },
      });
      expect(malformed.writes).toHaveLength(0);
    }

    const malformedScope = fakeDb(baseSeed({
      [`maintenance_records/${IDS.issue}`]: persistedIssue({
        assetHierarchyRefJson: assetReference({scope: 'unsupported'}),
      }),
    }));
    await expect(invoke(malformedScope)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'operational-event-link-issue-asset-reference-malformed',
      },
    });
    expect(malformedScope.writes).toHaveLength(0);
  });

  test('accepts production ISO timestamps and rejects malformed calendar dates', async () => {
    await expect(invoke(fakeDb(baseSeed()))).resolves.toMatchObject({ok: true});

    const malformed = fakeDb(baseSeed({
      [`maintenance_records/${IDS.issue}`]: persistedIssue({
        updatedAt: '2026-02-30T10:12:00.000Z',
      }),
    }));
    await expect(invoke(malformed)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'operational-event-link-issue-malformed'},
    });
    expect(malformed.writes).toHaveLength(0);
  });

  test('fails authority-first without entering the transaction', async () => {
    const memory = fakeDb(baseSeed());
    await expect(invoke(memory, 'mech-1')).rejects.toMatchObject({
      code: 'permission-denied',
    });
    expect(memory.writes).toHaveLength(0);
  });
});
