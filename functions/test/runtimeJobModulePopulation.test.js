const {
  mutateRuntimeJobModulePopulationWithDb,
} = require('../lib/runtimeJobModulePopulation');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([k, v]) => [k, clone(v)]));
  const writes = [];

  function ref(collection, id) {
    return {id, path: `${collection}/${id}`};
  }

  const db = {
    collection(name) {
      return {doc(id) { return ref(name, id); }};
    },
    async runTransaction(fn) {
      const staged = [];
      const tx = {
        async get(documentRef) {
          const data = store.get(documentRef.path);
          return {
            exists: data != null,
            id: documentRef.id,
            data: () => clone(data),
          };
        },
        set(documentRef, data) {
          staged.push({kind: 'set', path: documentRef.path, data: clone(data)});
        },
        update(documentRef, data) {
          staged.push({kind: 'update', path: documentRef.path, data: clone(data)});
        },
      };
      const result = await fn(tx);
      for (const write of staged) {
        if (write.kind === 'set') {
          store.set(write.path, clone(write.data));
        } else {
          const before = store.get(write.path);
          if (before == null) throw new Error(`Missing ${write.path}`);
          store.set(write.path, {...clone(before), ...clone(write.data)});
        }
        writes.push(write);
      }
      return result;
    },
  };

  return {db, store, writes};
}

function user(roles = ['shiftSupervisor']) {
  return {
    isApproved: true,
    roles,
    name: 'Shift Supervisor',
    email: 'supervisor@example.invalid',
  };
}

function execution(overrides = {}) {
  return {
    firestoreId: 'exec1',
    assetType: 'base',
    assetNumber: 101,
    chargeNoAtEvent: 12345,
    isCompleted: false,
    isDeleted: false,
    version: 4,
    modulePopulationVersion: 0,
    modulePopulationSchemaVersion: 1,
    ...overrides,
  };
}

function modulePayload(overrides = {}) {
  const now = '2026-06-24T00:00:00.000Z';
  return {
    firestoreId: 'module1',
    jobExecutionFirestoreId: 'exec1',
    templateFirestoreId: 'legacy-template',
    templateName: 'Runtime template',
    templatePackageId: null,
    templateVersionId: null,
    templateModuleId: null,
    moduleCode: 'RUNTIME-01',
    moduleSnapshotJson: '{}',
    fieldDefinitionsJson: '[]',
    assetType: 'base',
    assetNumber: 101,
    chargeNoAtEvent: 12345,
    pairedEquipmentJson: null,
    moduleTitle: 'Runtime inspection',
    moduleDescription: null,
    status: 'notStarted',
    useMode: 'scheduledPM',
    discipline: 'mechanical',
    safetyClass: 'normal',
    isRequired: false,
    requiredForClosure: false,
    addedDuringExecution: true,
    displayOrder: 1,
    functionalSection: null,
    componentGroup: null,
    subsystem: null,
    targetRef: null,
    targetRefs: [],
    procedureRefs: [],
    safetyConfirmations: [],
    tags: [],
    operationalStatePreconditions: [],
    responsesJson: '[]',
    actionsJson: '[]',
    draftNote: null,
    submissionNote: null,
    acceptanceNote: null,
    reopenReason: null,
    notApplicableReason: null,
    pendingIssue: null,
    requiresFollowUp: false,
    addedByUid: 'supervisor1',
    addedByName: 'Shift Supervisor',
    addedAt: now,
    addReason: 'Observed during execution',
    createdByUid: 'supervisor1',
    createdByName: 'Shift Supervisor',
    createdAt: now,
    updatedByUid: 'supervisor1',
    updatedByName: 'Shift Supervisor',
    updatedAt: now,
    submittedByUid: null,
    submittedByName: null,
    submittedAt: null,
    acceptedByUid: null,
    acceptedByName: null,
    acceptedAt: null,
    reopenedByUid: null,
    reopenedByName: null,
    reopenedAt: null,
    notApplicableByUid: null,
    notApplicableByName: null,
    notApplicableAt: null,
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    version: 1,
    metadataJson: null,
    ...overrides,
  };
}

function tombstone(existing, overrides = {}) {
  return {
    ...existing,
    isDeleted: true,
    deletedByUid: 'supervisor1',
    deletedByName: 'Shift Supervisor',
    deletedAt: '2026-06-24T11:00:00.000Z',
    deleteReason: 'Duplicate runtime module',
    updatedByUid: 'supervisor1',
    updatedByName: 'Shift Supervisor',
    updatedAt: '2026-06-24T11:00:00.000Z',
    version: existing.version + 1,
    ...overrides,
  };
}

function invoke(db, data, authUid = 'supervisor1', extra = {}) {
  return mutateRuntimeJobModulePopulationWithDb({
    db,
    authUid,
    data,
    now: () => new Date('2026-06-24T12:00:00.000Z'),
    timestampFromDate: (date) => ({timestamp: date.toISOString()}),
    ...extra,
  });
}

function state(store) {
  return clone(Object.fromEntries(store));
}

describe('runtime planned-job module population mutation', () => {
  test('create atomically writes child, parent population revision, and immutable audit', async () => {
    const {db, store} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({version: 7}),
    });

    const result = await invoke(db, {
      operation: 'create',
      module: modulePayload(),
    });

    expect(result).toMatchObject({
      ok: true,
      operation: 'create',
      idempotentReplay: false,
      acceptedAtPopulationVersion: 1,
      currentParentPopulationVersion: 1,
    });
    expect(store.get('job_modules/module1')).toMatchObject({
      jobExecutionFirestoreId: 'exec1',
      parentPopulationVersionAtAcceptance: 1,
      populationAcceptedByUid: 'supervisor1',
    });
    expect(store.get('job_executions/exec1')).toMatchObject({
      version: 7,
      modulePopulationVersion: 1,
      modulePopulationSchemaVersion: 1,
      isCompleted: false,
    });
    expect(store.get('audit_logs/server_module_population_create_module1')).toMatchObject({
      entityType: 'planned_job_module',
      entityId: 'module1',
      action: 'create',
      performedByUid: 'supervisor1',
      timestamp: {timestamp: '2026-06-24T12:00:00.000Z'},
    });
  });

  test('exact create replay returns immutable acceptance revision and current parent revision separately', async () => {
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });

    const first = await invoke(seed.db, {
      operation: 'create',
      module: modulePayload(),
    });
    expect(first.acceptedAtPopulationVersion).toBe(1);

    seed.store.set('job_executions/exec1', {
      ...seed.store.get('job_executions/exec1'),
      modulePopulationVersion: 5,
      isCompleted: true,
    });
    const writeCount = seed.writes.length;

    const replay = await invoke(seed.db, {
      operation: 'create',
      module: modulePayload(),
    });
    expect(replay).toMatchObject({
      idempotentReplay: true,
      acceptedAtPopulationVersion: 1,
      currentParentPopulationVersion: 5,
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test.each([
    ['missing', {}, 'not-found', 'parent-execution-missing'],
    ['deleted', {isDeleted: true}, 'failed-precondition', 'parent-execution-deleted'],
    ['completed', {isCompleted: true}, 'failed-precondition', 'parent-execution-completed'],
  ])('rejects create for %s parent with whole-state no mutation', async (_label, parentOverrides, code, reasonCode) => {
    const seed = {
      'users/supervisor1': user(),
      ...(_label === 'missing' ? {} : {'job_executions/exec1': execution(parentOverrides)}),
    };
    const {db, store, writes} = fakeDb(seed);
    const before = state(store);

    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload(),
    })).rejects.toMatchObject({code, details: {reasonCode}});

    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test.each([
    ['missing audit', null, 'population-audit-missing'],
    [
      'tampered audit',
      {
        entityType: 'planned_job_module',
        entityId: 'module1',
        action: 'create',
        performedByUid: 'supervisor1',
        afterJson: JSON.stringify({requestFingerprint: 'tampered'}),
      },
      'population-audit-mismatch',
    ],
  ])('exact replay fails closed for %s', async (_label, replacementAudit, reasonCode) => {
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    const request = {operation: 'create', module: modulePayload()};
    await invoke(seed.db, request);
    const auditPath = 'audit_logs/server_module_population_create_module1';
    if (replacementAudit == null) {
      seed.store.delete(auditPath);
    } else {
      seed.store.set(auditPath, replacementAudit);
    }
    const writeCount = seed.writes.length;

    await expect(invoke(seed.db, request)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode},
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test('exact replay rejects parent population-version regression', async () => {
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    const request = {operation: 'create', module: modulePayload()};
    await invoke(seed.db, request);
    seed.store.set('job_executions/exec1', {
      ...seed.store.get('job_executions/exec1'),
      modulePopulationVersion: 0,
    });
    const writeCount = seed.writes.length;

    await expect(invoke(seed.db, request)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'parent-population-version-regressed'},
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test('exact replay rejects an audit with mismatched immutable acceptance revision', async () => {
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    const request = {operation: 'create', module: modulePayload()};
    await invoke(seed.db, request);
    const auditPath = 'audit_logs/server_module_population_create_module1';
    const audit = seed.store.get(auditPath);
    const after = JSON.parse(audit.afterJson);
    seed.store.set(auditPath, {
      ...audit,
      afterJson: JSON.stringify({...after, modulePopulationVersion: 99}),
    });
    const writeCount = seed.writes.length;

    await expect(invoke(seed.db, request)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'population-audit-mismatch'},
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test('reserved server audit identity cannot be overwritten by a new mutation', async () => {
    const {db, store, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
      'audit_logs/server_module_population_create_module1': {
        entityType: 'planned_job_module',
        entityId: 'module1',
        action: 'create',
        performedByUid: 'other-user',
        afterJson: '{}',
      },
    });
    const before = state(store);

    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload(),
    })).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'population-audit-preexisting'},
    });
    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test('exact replay is owner-bound and cannot be claimed by another authorized actor', async () => {
    const seed = fakeDb({
      'users/supervisor1': user(),
      'users/supervisor2': user(),
      'job_executions/exec1': execution(),
    });
    await invoke(seed.db, {operation: 'create', module: modulePayload()});
    const writeCount = seed.writes.length;
    await expect(invoke(
      seed.db,
      {operation: 'create', module: modulePayload()},
      'supervisor2',
    )).rejects.toMatchObject({
      code: 'already-exists',
      details: {reasonCode: 'population-mutation-owner-mismatch'},
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test('requires explicit runtime-addition classification', async () => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload({addedDuringExecution: false}),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'runtime-module-classification-required'},
    });
    expect(writes).toEqual([]);
  });

  test.each([
    [{assetNumber: 999}, 'parent-asset-mismatch'],
    [{chargeNoAtEvent: 99999}, 'parent-charge-mismatch'],
  ])('rejects child identity mismatch: %j', async (overrides, reasonCode) => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload(overrides),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode},
    });
    expect(writes).toEqual([]);
  });

  test('ordinary user cannot attribute module history to another actor', async () => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(['seniorMechanical']),
      'job_executions/exec1': execution(),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload({createdByUid: 'other-user'}),
    })).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'module-actor-preservation-role-required'},
    });
    expect(writes).toEqual([]);
  });

  test('moderator preservation requires reason and records uploader plus original actor claims', async () => {
    const module = modulePayload({
      createdByUid: 'offline-user',
      createdByName: 'Offline Maintainer',
      addedByUid: 'offline-user',
      addedByName: 'Offline Maintainer',
      updatedByUid: 'offline-user',
      updatedByName: 'Offline Maintainer',
    });
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });

    await expect(invoke(seed.db, {
      operation: 'create',
      module,
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'module-actor-preservation-reason-required'},
    });

    const result = await invoke(seed.db, {
      operation: 'create',
      module,
      preservationReason: 'Supervisor preserved offline evidence from a controlled shared tablet.',
    });
    expect(result.module).toMatchObject({
      populationAcceptedByUid: 'supervisor1',
      populationPreservationReason: expect.stringContaining('controlled shared tablet'),
      populationOriginalActorClaims: expect.objectContaining({
        createdByUid: 'offline-user',
        updatedByUid: 'offline-user',
      }),
    });
  });

  test('collapsed accepted first-sync state requires complete lifecycle history and moderator authority', async () => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload({status: 'accepted'}),
    })).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    expect(writes).toEqual([]);
  });

  test('valid collapsed accepted first-sync history is accepted only through moderator preservation', async () => {
    const module = modulePayload({
      status: 'accepted',
      createdByUid: 'offline-mechanic',
      addedByUid: 'offline-mechanic',
      updatedByUid: 'offline-supervisor',
      submittedByUid: 'offline-mechanic',
      submittedByName: 'Offline Mechanic',
      submittedAt: '2026-06-24T01:00:00.000Z',
      acceptedByUid: 'offline-supervisor',
      acceptedByName: 'Offline Supervisor',
      acceptedAt: '2026-06-24T02:00:00.000Z',
      updatedAt: '2026-06-24T03:00:00.000Z',
    });
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });

    const result = await invoke(seed.db, {
      operation: 'create',
      module,
      preservationReason:
        'Shift supervisor verified the offline submit and acceptance trail.',
    });

    expect(result.module).toMatchObject({
      status: 'accepted',
      populationAcceptedByUid: 'supervisor1',
      populationOriginalActorClaims: expect.objectContaining({
        submittedByUid: 'offline-mechanic',
        acceptedByUid: 'offline-supervisor',
      }),
    });
    const audit = seed.store.get(
      'audit_logs/server_module_population_create_module1',
    );
    const after = JSON.parse(audit.afterJson);
    expect(after).toMatchObject({
      uploaderUid: 'supervisor1',
      actorClaims: expect.objectContaining({
        createdByUid: 'offline-mechanic',
        acceptedByUid: 'offline-supervisor',
      }),
      preservedActorFields: expect.arrayContaining([
        'createdByUid',
        'updatedByUid',
        'submittedByUid',
        'acceptedByUid',
      ]),
    });
  });

  test('rejects malformed present parent population metadata instead of silently normalizing it', async () => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({
        modulePopulationVersion: 'bad',
        modulePopulationSchemaVersion: 1,
      }),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload(),
    })).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'module-population-version-invalid'},
    });
    expect(writes).toEqual([]);
  });

  test('soft delete atomically writes tombstone, parent revision and immutable audit', async () => {
    const existing = modulePayload({version: 3});
    const {db, store} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({modulePopulationVersion: 5}),
      'job_modules/module1': existing,
    });

    const result = await invoke(db, {
      operation: 'softDelete',
      module: tombstone(existing),
    });

    expect(result).toMatchObject({
      operation: 'softDelete',
      acceptedAtPopulationVersion: 6,
      currentParentPopulationVersion: 6,
    });
    expect(store.get('job_modules/module1')).toMatchObject({
      moduleTitle: existing.moduleTitle,
      isDeleted: true,
      version: 4,
      parentPopulationVersionAtMutation: 6,
    });
    expect(store.get('job_executions/exec1')).toMatchObject({
      modulePopulationVersion: 6,
      modulePopulationLastMutation: 'softDelete',
    });
    expect(store.get('audit_logs/server_module_population_soft_delete_module1')).toMatchObject({
      action: 'delete',
      performedByUid: 'supervisor1',
    });
  });

  test.each([
    [
      'actor mismatch',
      {deletedByUid: 'other-user'},
      'permission-denied',
      'module-delete-actor-mismatch',
    ],
    [
      'stale version',
      {version: 3},
      'failed-precondition',
      'module-delete-version-stale',
    ],
  ])('soft delete rejects %s without mutation', async (_label, overrides, code, reasonCode) => {
    const existing = modulePayload({version: 3});
    const {db, store, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({modulePopulationVersion: 5}),
      'job_modules/module1': existing,
    });
    const before = state(store);

    await expect(invoke(db, {
      operation: 'softDelete',
      module: tombstone(existing, overrides),
    })).rejects.toMatchObject({code, details: {reasonCode}});

    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test('exact soft-delete replay remains idempotent after later completion', async () => {
    const existing = modulePayload({version: 3});
    const seed = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({modulePopulationVersion: 2}),
      'job_modules/module1': existing,
    });
    const request = {operation: 'softDelete', module: tombstone(existing)};
    const first = await invoke(seed.db, request);
    expect(first.acceptedAtPopulationVersion).toBe(3);
    seed.store.set('job_executions/exec1', {
      ...seed.store.get('job_executions/exec1'),
      isCompleted: true,
      modulePopulationVersion: 8,
    });
    const writeCount = seed.writes.length;
    const replay = await invoke(seed.db, request);
    expect(replay).toMatchObject({
      idempotentReplay: true,
      acceptedAtPopulationVersion: 3,
      currentParentPopulationVersion: 8,
    });
    expect(seed.writes).toHaveLength(writeCount);
  });

  test.each([
    ['missing', {}, 'not-found', 'parent-execution-missing'],
    ['deleted', {isDeleted: true}, 'failed-precondition', 'parent-execution-deleted'],
  ])('soft delete rejects %s parent without mutation', async (_label, parentOverrides, code, reasonCode) => {
    const existing = modulePayload({version: 3});
    const seed = {
      'users/supervisor1': user(),
      'job_modules/module1': existing,
      ...(_label === 'missing'
        ? {}
        : {'job_executions/exec1': execution(parentOverrides)}),
    };
    const {db, store, writes} = fakeDb(seed);
    const before = state(store);

    await expect(invoke(db, {
      operation: 'softDelete',
      module: tombstone(existing),
    })).rejects.toMatchObject({code, details: {reasonCode}});

    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test('soft delete after completion is rejected without mutation', async () => {
    const existing = modulePayload({version: 3});
    const {db, store, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution({isCompleted: true}),
      'job_modules/module1': existing,
    });
    const before = state(store);
    await expect(invoke(db, {
      operation: 'softDelete',
      module: tombstone(existing),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'parent-execution-completed'},
    });
    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test('injected failure before writes leaves child, parent revision, and audit unchanged', async () => {
    const {db, store, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    const before = state(store);
    await expect(invoke(
      db,
      {operation: 'create', module: modulePayload()},
      'supervisor1',
      {beforeMutationWritesForTest: async () => { throw new Error('injected'); }},
    )).rejects.toThrow('injected');
    expect(state(store)).toEqual(before);
    expect(writes).toEqual([]);
  });

  test('rejects unexpected client fields because callable bypasses rules', async () => {
    const {db, writes} = fakeDb({
      'users/supervisor1': user(),
      'job_executions/exec1': execution(),
    });
    await expect(invoke(db, {
      operation: 'create',
      module: modulePayload({serverOwnedInjection: true}),
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'unexpected-module-fields'},
    });
    expect(writes).toEqual([]);
  });
});
