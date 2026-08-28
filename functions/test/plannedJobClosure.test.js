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

  test('matches governed schema-2 closure attestation golden fixture', () => {
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
          schemaVersion: 1,
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
      modulePopulationVersionAtCompletion: 0,
      guardIssueCounts: assertClosureReady([moduleData]),
    });

    expect(attestation.hash).toBe(
      '40f61396ca52bc0b1c007209c2ca469301ebedb2877ffdc1bc12a6b91dc4cdea',
    );
    expect(attestation.canonicalJson).toContain(
      '"moduleKey":"firestore:module_gold_1"',
    );
    expect(attestation.payload.modules[0].snapshotHash).toBe(
      '16181a9bf6da5e2399917925c29c6ab29d8631cc3efb310e8eab2a439d1e20b1',
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

  test('treats a required boolean false as supplied evidence', () => {
    const module = baseModule({
      fieldDefinitionsJson: JSON.stringify([{
        key: 'burnerBlockChanged',
        type: 'boolean',
        isRequired: true,
      }]),
      responsesJson: JSON.stringify([{
        schemaVersion: 1,
        key: 'burnerBlockChanged',
        fieldLabel: 'Burner block changed',
        fieldType: 'yesNo',
        value: false,
      }]),
    });

    expect(moduleMissingRequiredClosureEvidence(module)).toBe(false);
    expect(assertClosureReady([module])).toEqual({
      openRequiredModule: 0,
      waitingAcceptance: 0,
      missingRequiredEvidence: 0,
      pendingIssueOrFollowUp: 0,
    });
  });

  test('rejects malformed saved module action evidence before closure', () => {
    let caught;
    try {
      assertClosureReady([baseModule({actionsJson: '[{}]'})]);
    } catch (error) {
      caught = error;
    }
    expect(caught).toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'module-action-payload-invalid',
        moduleFirestoreId: 'module_1',
      }),
    });
  });

  test('rejects malformed saved module field definitions before closure', () => {
    expect(() => assertClosureReady([
      baseModule({fieldDefinitionsJson: '[{"type":"text"}]'}),
    ])).toThrow(expect.objectContaining({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'module-field-definition-payload-invalid',
        moduleFirestoreId: 'module_1',
      }),
    }));
  });

  test('rejects malformed saved module responses before closure', () => {
    expect(() => assertClosureReady([
      baseModule({responsesJson: '[{"key":"vt_reading"}]'}),
    ])).toThrow(expect.objectContaining({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'module-response-payload-invalid',
        moduleFirestoreId: 'module_1',
      }),
    }));
  });

  test('rejects explicitly null saved module work payloads', () => {
    expect(() => assertClosureReady([
      baseModule({actionsJson: null}),
    ])).toThrow(expect.objectContaining({
      details: expect.objectContaining({
        reasonCode: 'module-action-payload-invalid',
      }),
    }));
    expect(() => assertClosureReady([
      baseModule({fieldDefinitionsJson: null}),
    ])).toThrow(expect.objectContaining({
      details: expect.objectContaining({
        reasonCode: 'module-field-definition-payload-invalid',
      }),
    }));
    expect(() => assertClosureReady([
      baseModule({responsesJson: null}),
    ])).toThrow(expect.objectContaining({
      details: expect.objectContaining({
        reasonCode: 'module-response-payload-invalid',
      }),
    }));
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
      modulePopulationVersionAtCompletion: 0,
      guardIssueCounts: assertClosureReady([a, b]),
    });

    const second = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [b, a],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      modulePopulationVersionAtCompletion: 0,
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
      modulePopulationVersionAtCompletion: 0,
      guardIssueCounts: assertClosureReady([firstModule]),
    });

    const second = buildClosureAttestation({
      executionFirestoreId: 'job_1',
      modules: [secondModule],
      completedByUid: 'supervisor',
      completedByName: 'Supervisor',
      completedAt: '2026-05-15T00:00:00.000Z',
      executionVersionAtCompletion: 2,
      modulePopulationVersionAtCompletion: 0,
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
      modulePopulationVersionAtCompletion: 0,
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
    expect(userCanComplete({approved: true, roles: ['admin']})).toBe(false);
    expect(userCanComplete({isApproved: true, roles: ['admin', 'bogus']})).toBe(false);
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
                throw new Error('authority must be read inside the transaction');
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
            if (ref.path === 'users/supervisor1') {
              return {
                exists: true,
                data: () => ({
                  isApproved: true,
                  roles: ['shiftSupervisor'],
                  name: 'Shift Supervisor',
                }),
              };
            }
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
  function fakeCompletionDb({
    userData,
    executionData,
    modules = [],
    documents = {},
  }) {
    const writes = {
      updates: [],
      sets: [],
      outsideDocumentReads: 0,
      authorityReads: 0,
      executionReads: 0,
      moduleQueryReads: 0,
      transactionRuns: 0,
    };
    const db = {
      collection(name) {
        return {
          doc(id) {
            return {
              path: `${name}/${id}`,
              async get() {
                writes.outsideDocumentReads += 1;
                throw new Error('document reads must use the transaction');
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
            if (refOrQuery && refOrQuery.path?.startsWith('users/')) {
              writes.authorityReads += 1;
              return userData == null
                ? {exists: false, data: () => undefined}
                : {exists: true, data: () => userData};
            }
            if (refOrQuery && refOrQuery.path === `job_executions/${executionData.firestoreId}`) {
              writes.executionReads += 1;
              return {exists: true, data: () => executionData};
            }
            if (refOrQuery && Object.prototype.hasOwnProperty.call(
              documents,
              refOrQuery.path,
            )) {
              const path = refOrQuery.path;
              return {
                exists: true,
                id: path.split('/').at(-1),
                data: () => documents[path],
              };
            }
            if (refOrQuery && refOrQuery.kind === 'query') {
              writes.moduleQueryReads += 1;
              return {
                docs: modules.map((moduleData, index) => ({
                  id: moduleData.firestoreId ?? `module_${index}`,
                  exists: true,
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

  test('malformed requested actions reject before DB or transaction work', async () => {
    const db = {
      collection() { throw new Error('db should not be touched'); },
      async runTransaction() { throw new Error('transaction should not run'); },
    };

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', actions: [{}]},
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: expect.objectContaining({reasonCode: 'action-payload-invalid'}),
    });
  });

  test('legacy completion canonicalizes new actions from the live asset hierarchy', async () => {
    const executionData = baseExecution({
      assetType: 'furnace',
      assetNumber: 7,
      actionsJson: '[]',
      responsesJson: '[]',
    });
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Shift Supervisor',
      },
      executionData,
      modules: [baseModule()],
      documents: {
        'asset_classes/class-furnace': {
          schemaVersion: 1,
          assetClassId: 'class-furnace',
          status: 'active',
          legacyAssetTypeKey: 'furnace',
          code: 'FR',
          name: 'Furnace',
        },
        'asset_instances/asset-furnace-7': {
          schemaVersion: 1,
          assetInstanceId: 'asset-furnace-7',
          assetClassId: 'class-furnace',
          assetClassCode: 'FR',
          assetClassName: 'Furnace',
          assetNumber: 7,
          name: 'Furnace 7',
          status: 'active',
          version: 4,
          ownershipStatus: 'confirmed',
          ownerDiscipline: 'Mechanical',
          accountableRoleKeys: ['seniorMechanical'],
        },
        'asset_hierarchy_nodes/node-shell': {
          schemaVersion: 1,
          nodeId: 'node-shell',
          assetClassId: 'class-furnace',
          status: 'active',
          version: 2,
          nodeType: 'component',
          name: 'Furnace shell',
          componentTag: null,
          hierarchyPath: ['Structure', 'Furnace shell'],
          ownershipStatus: 'confirmed',
          ownerDiscipline: 'Mechanical',
          accountableRoleKeys: ['seniorMechanical'],
        },
      },
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {
        executionId: 'job_1',
        expectedCompletionVersion: 7,
        actionTargetContractVersion: 1,
        actions: [{
          schemaVersion: 1,
          asset: 'Untrusted asset',
          component: 'Untrusted component',
          hierarchyPath: ['Untrusted'],
          assetHierarchyRef: {
            schemaVersion: 4,
            scope: 'componentDefinitionOnAsset',
            assetClassId: 'class-furnace',
            assetInstanceId: 'asset-furnace-7',
            assetInstanceVersion: 4,
            nodeId: 'node-shell',
            nodeVersion: 2,
          },
          tag: null,
          actionType: 'inspection',
          isAutoResolved: true,
          status: 'resolved',
          createdAt: '2026-05-15T09:00:00.000Z',
          severity: 'medium',
          version: 1,
        }],
      },
    })).resolves.toMatchObject({ok: true, executionId: 'job_1'});

    const executionWrite = writes.updates.find(
      (write) => write.ref.path === 'job_executions/job_1',
    );
    const [savedAction] = JSON.parse(executionWrite.data.actionsJson);
    expect(savedAction).toMatchObject({
      asset: 'Furnace 7',
      component: 'Furnace shell',
      hierarchyPath: ['Structure', 'Furnace shell'],
      system: 'Furnace',
      subsystem: 'Structure',
      performedBy: 'Shift Supervisor',
    });
  });

  test('malformed requested responses reject before DB or transaction work', async () => {
    const db = {
      collection() { throw new Error('db should not be touched'); },
      async runTransaction() { throw new Error('transaction should not run'); },
    };

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', responses: [{key: 'pressure'}]},
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: expect.objectContaining({reasonCode: 'response-payload-invalid'}),
    });
  });

  test('unapproved user rejects transactionally before execution or module reads', async () => {
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

    expect(writes.transactionRuns).toBe(1);
    expect(writes.outsideDocumentReads).toBe(0);
    expect(writes.authorityReads).toBe(1);
    expect(writes.executionReads).toBe(0);
    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('operations role rejects transactionally before execution or module reads', async () => {
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

    expect(writes.transactionRuns).toBe(1);
    expect(writes.outsideDocumentReads).toBe(0);
    expect(writes.authorityReads).toBe(1);
    expect(writes.executionReads).toBe(0);
    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('malformed module-population version rejects without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({
        version: 6,
        modulePopulationVersion: 'corrupt',
        modulePopulationSchemaVersion: 1,
      }),
      modules: [baseModule()],
    });

    await expect(
      completePlannedJobWithDb({
        db,
        authUid: 'supervisor1',
        data: {executionId: 'job_1', expectedCompletionVersion: 7},
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'module-population-version-invalid'},
    });

    expect(writes.transactionRuns).toBe(1);
    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('cancelled execution rejects before module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({
        isCancelled: true,
        cancelledAt: '2026-05-15T08:30:00.000Z',
      }),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'closure-execution-cancelled'},
    });

    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('malformed existing execution actions reject without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({actionsJson: '[{}]'}),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'execution-action-payload-invalid',
      }),
    });

    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('explicitly null existing execution actions reject without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({actionsJson: null}),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'execution-action-payload-invalid',
      }),
    });

    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('malformed existing execution responses reject without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({responsesJson: '[{"key":"pressure"}]'}),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'execution-response-payload-invalid',
      }),
    });

    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('explicitly null existing execution responses reject without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({responsesJson: null}),
      modules: [baseModule()],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'execution-response-payload-invalid',
      }),
    });

    expect(writes.moduleQueryReads).toBe(0);
    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });

  test('malformed module-population schema rejects without module query or writes', async () => {
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({
        version: 6,
        modulePopulationVersion: 1,
        modulePopulationSchemaVersion: 99,
      }),
      modules: [baseModule()],
    });

    await expect(
      completePlannedJobWithDb({
        db,
        authUid: 'supervisor1',
        data: {executionId: 'job_1', expectedCompletionVersion: 7},
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'module-population-schema-version-invalid'},
    });

    expect(writes.transactionRuns).toBe(1);
    expect(writes.moduleQueryReads).toBe(0);
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

  test('preserves burner lifecycle rejection at the legacy callable boundary', async () => {
    const burnerReplacement = {
      schemaVersion: 1,
      asset: 'Furnace 7',
      component: 'Burner blocks and firing tubes',
      hierarchyPath: [
        'Furnace',
        'Refractory system',
        'Burner blocks and firing tubes',
      ],
      assetHierarchyRef: {
        schemaVersion: 4,
        scope: 'componentDefinitionOnAsset',
        assetClassId: 'class-furnace',
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        nodeId: 'node-burner-block',
        nodeVersion: 1,
        nodeName: 'Burner blocks and firing tubes',
        assetInstanceId: 'furnace-7',
        assetInstanceVersion: 1,
        assetNumber: 7,
        assetInstanceName: 'Furnace 7',
        componentInstanceId: null,
        componentInstanceVersion: null,
        componentTag: null,
        hierarchyPath: [
          'Furnace',
          'Refractory system',
          'Burner blocks and firing tubes',
        ],
        ownershipStatus: 'confirmed',
        ownerDiscipline: 'RED',
        accountableRoleKeys: ['seniorRefractory'],
        innerCoverAssociation: null,
      },
      actionType: 'replacement',
      replacement: 'newPart',
      isAutoResolved: true,
      status: 'resolved',
      createdAt: '2026-05-15T09:00:00.000Z',
      severity: 'medium',
      version: 1,
      burnerPosition: 3,
      burnerBlockSupplyMode: 'sailRed',
    };
    const module = baseModule({
      moduleCode: 'F-03M',
      discipline: 'mechanical',
      fieldDefinitionsJson: JSON.stringify([{
        key: 'burnerTarget',
        type: 'targetRule',
        isRequired: true,
      }, {
        key: 'burnerBlockChanged',
        type: 'boolean',
        isRequired: true,
      }]),
      responsesJson: JSON.stringify([{
        key: 'burnerTarget',
        value: 'Burner 3',
      }, {
        key: 'burnerBlockChanged',
        value: false,
      }]),
      actionsJson: JSON.stringify([burnerReplacement]),
    });
    const {db, writes} = fakeCompletionDb({
      userData: {
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Supervisor',
      },
      executionData: baseExecution({
        assetType: 'furnace',
        assetNumber: 7,
      }),
      modules: [module],
    });

    await expect(completePlannedJobWithDb({
      db,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'burner-block-lifecycle-action-conflicts-with-response',
      },
    });

    expect(writes.updates).toHaveLength(0);
    expect(writes.sets).toHaveLength(0);
  });
});
