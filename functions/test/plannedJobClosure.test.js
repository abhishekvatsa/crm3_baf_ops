const {
  assertClosureReady,
  buildClosureAttestation,
  collectClosureIssues,
  completePlannedJobWithDb,
  executionResponse,
  mergeAttestationIntoMetadata,
  moduleMissingRequiredClosureEvidence,
  userCanComplete,
} = require('../lib/plannedJobClosure');

function baseModule(overrides = {}) {
  return {
    firestoreId: 'module_1',
    jobExecutionFirestoreId: 'job_1',
    templateModuleId: 'tm_1',
    moduleCode: 'M-01',
    moduleTitle: 'Inspect base fan',
    version: 1,
    status: 'accepted',
    requiredForClosure: true,
    isDeleted: false,
    requiresFollowUp: false,
    pendingIssue: null,
    fieldDefinitionsJson: JSON.stringify([
      {key: 'vt_reading', type: 'number', isRequired: true},
    ]),
    responsesJson: JSON.stringify([
      {key: 'vt_reading', value: '2.1 mm/s'},
    ]),
    ...overrides,
  };
}

describe('planned job server closure validation', () => {

  test('matches Dart golden attestation hash fixture', () => {
    const moduleData = {
      id: 42,
      firestoreId: 'module_gold_1',
      jobExecutionFirestoreId: 'exec_gold_1',
      jobExecutionLocalId: 99,
      templateModuleId: 'template_module_gold_1',
      moduleCode: 'BAF-GOLD-01',
      moduleTitle: 'Golden closure module',
      version: 3,
      status: 'accepted',
      requiredForClosure: true,
      isDeleted: false,
      requiresFollowUp: false,
      pendingIssue: null,
      fieldDefinitionsJson: JSON.stringify([
        {key: 'vt_reading', type: 'number', isRequired: true},
      ]),
      responsesJson: JSON.stringify([
        {
          key: 'vt_reading',
          fieldLabel: 'vt_reading',
          fieldType: 'text',
          value: '2.1 mm/s',
        },
      ]),
    };

    const attestation = buildClosureAttestation({
      executionFirestoreId: 'exec_gold_1',
      modules: [moduleData],
      completedByUid: 'uid_gold',
      completedByName: 'Shift Supervisor',
      completedAt: '2026-05-15T08:30:00.000Z',
      executionVersionAtCompletion: 5,
      guardIssueCounts: assertClosureReady([moduleData]),
    });

    expect(attestation.hash).toBe(
      '1c19c2b037f2e3fa944b7765a6d8d7fbf6c692567987ee49ba899c3cc4f577ae',
    );
    expect(attestation.canonicalJson).toContain(
      '"moduleKey":"firestore:module_gold_1"',
    );
    expect(attestation.payload.modules[0].snapshotHash).toBe(
      '81aab978a5a136d236a673297410c501484f5e6d5ec7b50020462ab783c0bc76',
    );
  });

  test('accepts accepted required module with required evidence', () => {
    expect(assertClosureReady([baseModule()])).toEqual({
      openRequiredModule: 0,
      waitingAcceptance: 0,
      missingRequiredEvidence: 0,
      pendingIssueOrFollowUp: 0,
    });
  });

  test('rejects open required modules', () => {
    const issues = collectClosureIssues([baseModule({status: 'inProgress'})]);
    expect(issues).toHaveLength(1);
    expect(issues[0].type).toBe('openRequiredModule');
  });

  test('rejects submitted modules waiting for acceptance', () => {
    const issues = collectClosureIssues([baseModule({status: 'submitted'})]);
    expect(issues).toHaveLength(1);
    expect(issues[0].type).toBe('waitingAcceptance');
  });

  test('rejects missing explicitly required ordinary evidence', () => {
    const module = baseModule({responsesJson: '[]'});
    expect(moduleMissingRequiredClosureEvidence(module)).toBe(true);
    expect(collectClosureIssues([module])[0].type).toBe('missingRequiredEvidence');
  });

  test('rejects ordinary fields with no responses even when no field is explicitly required', () => {
    const module = baseModule({
      fieldDefinitionsJson: JSON.stringify([
        {key: 'observation', type: 'text', isRequired: false},
      ]),
      responsesJson: '[]',
    });
    expect(moduleMissingRequiredClosureEvidence(module)).toBe(true);
    expect(collectClosureIssues([module])[0].type).toBe('missingRequiredEvidence');
  });

  test('ignores missing evidence for notApplicable modules', () => {
    const module = baseModule({status: 'notApplicable', responsesJson: '[]'});
    expect(collectClosureIssues([module])).toEqual([]);
  });

  test('rejects pending issue/follow-up', () => {
    const issues = collectClosureIssues([baseModule({requiresFollowUp: true})]);
    expect(issues).toHaveLength(1);
    expect(issues[0].type).toBe('pendingIssueOrFollowUp');
  });

  test('attestation hash is deterministic under module order changes', () => {
    const a = baseModule({firestoreId: 'a', moduleCode: 'A'});
    const b = baseModule({firestoreId: 'b', moduleCode: 'B'});

    const first = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [a, b],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      guardIssueCounts: assertClosureReady([a, b]),
    });

    const second = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [b, a],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      guardIssueCounts: assertClosureReady([b, a]),
    });

    expect(first.hash).toBe(second.hash);
  });

  test('attestation hash changes when required evidence changes', () => {
    const firstModule = baseModule({
      responsesJson: JSON.stringify([{key: 'vt_reading', value: '2.1'}]),
    });
    const secondModule = baseModule({
      responsesJson: JSON.stringify([{key: 'vt_reading', value: '4.9'}]),
    });

    const first = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [firstModule],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      guardIssueCounts: assertClosureReady([firstModule]),
    });

    const second = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [secondModule],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      guardIssueCounts: assertClosureReady([secondModule]),
    });

    expect(first.hash).not.toBe(second.hash);
  });

  test('metadata merge preserves existing values', () => {
    const attestation = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [baseModule()],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      guardIssueCounts: assertClosureReady([baseModule()]),
    });

    const merged = JSON.parse(
      mergeAttestationIntoMetadata(
        JSON.stringify({previousKey: 'kept'}),
        attestation,
      ),
    );

    expect(merged.previousKey).toBe('kept');
    expect(merged.closureAttestation.hash).toBe(attestation.hash);
  });

  test('only approved moderator roles can complete', () => {
    expect(userCanComplete({isApproved: true, roles: ['shiftSupervisor']})).toBe(true);
    expect(userCanComplete({isApproved: true, roles: ['operations']})).toBe(false);
    expect(userCanComplete({isApproved: false, roles: ['admin']})).toBe(false);
  });

  test('execution response converts timestamp-like values to ISO strings', () => {
    const response = executionResponse(
      {
        createdAt: {toDate: () => new Date('2026-05-15T08:00:00.000Z')},
        nested: {
          updatedAt: {toDate: () => new Date('2026-05-15T09:00:00.000Z')},
        },
        events: [
          {completedAt: {toDate: () => new Date('2026-05-15T10:00:00.000Z')}},
        ],
      },
      'job_1',
    );

    expect(response.firestoreId).toBe('job_1');
    expect(response.createdAt).toBe('2026-05-15T08:00:00.000Z');
    expect(response.nested.updatedAt).toBe('2026-05-15T09:00:00.000Z');
    expect(response.events[0].completedAt).toBe('2026-05-15T10:00:00.000Z');
  });


  test('already completed execution with attestation returns canonical response even with stale expected version', async () => {
    const executionData = {
      firestoreId: 'job_1',
      isDeleted: false,
      isCompleted: true,
      version: 7,
      metadataJson: JSON.stringify({closureAttestation: {hash: 'existing_hash'}}),
      createdAt: {toDate: () => new Date('2026-05-15T08:00:00.000Z')},
      updatedAt: {toDate: () => new Date('2026-05-15T09:00:00.000Z')},
    };

    const fakeDb = {
      collection(name) {
        return {
          doc(id) {
            return {
              path: `${name}/${id}`,
              async get() {
                if (name === 'users') {
                  return {
                    exists: true,
                    data: () => ({
                      isApproved: true,
                      roles: ['shiftSupervisor'],
                      name: 'Shift Supervisor',
                    }),
                  };
                }
                return {exists: false, data: () => undefined};
              },
            };
          },
          where() {
            throw new Error('module query should not run for idempotent completion');
          },
        };
      },
      async runTransaction(fn) {
        return fn({
          async get(ref) {
            if (ref.path === 'job_executions/job_1') {
              return {exists: true, data: () => executionData};
            }
            return {exists: false, data: () => undefined};
          },
          update() {
            throw new Error('idempotent completion must not write');
          },
          set() {
            throw new Error('idempotent completion must not audit-write');
          },
        });
      },
    };

    const result = await completePlannedJobWithDb({
      db: fakeDb,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 99},
    });

    expect(result.ok).toBe(true);
    expect(result.alreadyCompleted).toBe(true);
    expect(result.version).toBe(7);
    expect(result.closureAttestationHash).toBe('existing_hash');
    expect(result.execution.firestoreId).toBe('job_1');
    expect(result.execution.createdAt).toBe('2026-05-15T08:00:00.000Z');
  });

});

describe('completePlannedJobWithDb unhappy paths do not write', () => {
  function fakeCompletionDb({userData, executionData, modules = []}) {
    const writes = {updates: [], sets: [], moduleQueryReads: 0, transactionRuns: 0};
    const db = {
      collection(name) {
        return {
          doc(id) {
            return {
              path: `${name}/${id}`,
              async get() {
                if (name === 'users') {
                  return userData == null
                    ? {exists: false, data: () => undefined}
                    : {exists: true, data: () => userData};
                }
                return {exists: false, data: () => undefined};
              },
            };
          },
          where(field, op, value) {
            const query = {
              kind: 'query',
              name,
              clauses: [[field, op, value]],
              where(nextField, nextOp, nextValue) {
                this.clauses.push([nextField, nextOp, nextValue]);
                return this;
              },
            };
            return query;
          },
        };
      },
      async runTransaction(fn) {
        writes.transactionRuns += 1;
        return fn({
          async get(refOrQuery) {
            if (refOrQuery && refOrQuery.path === `job_executions/${executionData.firestoreId}`) {
              return {exists: true, data: () => executionData};
            }
            if (refOrQuery && refOrQuery.kind === 'query') {
              writes.moduleQueryReads += 1;
              return {
                docs: modules.map((moduleData, index) => ({
                  id: moduleData.firestoreId ?? `module_${index}`,
                  data: () => moduleData,
                })),
              };
            }
            return {exists: false, data: () => undefined};
          },
          update(ref, data) {
            writes.updates.push({ref, data});
          },
          set(ref, data, options) {
            writes.sets.push({ref, data, options});
          },
        });
      },
    };
    return {db, writes};
  }

  function baseExecution(overrides = {}) {
    return {
      firestoreId: 'job_1',
      isDeleted: false,
      isCompleted: false,
      version: 6,
      metadataJson: '{}',
      createdAt: '2026-05-15T08:00:00.000Z',
      updatedAt: '2026-05-15T08:00:00.000Z',
      ...overrides,
    };
  }

  test('unauthenticated caller rejects before DB or transaction work', async () => {
    const db = {
      collection() { throw new Error('db should not be touched'); },
      async runTransaction() { throw new Error('transaction should not run'); },
    };

    await expect(completePlannedJobWithDb({
      db,
      authUid: null,
      data: {executionId: 'job_1'},
    })).rejects.toMatchObject({code: 'unauthenticated'});
  });

  test('unapproved user rejects before transaction work', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {isApproved: false, roles: ['shiftSupervisor']},
      executionData: baseExecution(),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1'},
    })).rejects.toMatchObject({code: 'permission-denied'});

    expect(writes.transactionRuns).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('operations role rejects before transaction work', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {isApproved: true, roles: ['operations']},
      executionData: baseExecution(),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'ops1',
      data: {executionId: 'job_1'},
    })).rejects.toMatchObject({code: 'permission-denied'});

    expect(writes.transactionRuns).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('stale expected version rejects without module query, execution write, or audit write', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {isApproved: true, roles: ['shiftSupervisor'], name: 'Supervisor'},
      executionData: baseExecution({version: 6}),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 99},
    })).rejects.toMatchObject({code: 'failed-precondition'});

    expect(writes.transactionRuns).toBe(1);
    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('module readiness failure writes no execution update and no audit log', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {isApproved: true, roles: ['shiftSupervisor'], name: 'Supervisor'},
      executionData: baseExecution({version: 6}),
      modules: [baseModule({status: 'inProgress'})],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        issues: expect.arrayContaining([
          expect.objectContaining({type: 'openRequiredModule'}),
        ]),
      },
    });

    expect(writes.transactionRuns).toBe(1);
    expect(writes.moduleQueryReads).toBe(1);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });
});
