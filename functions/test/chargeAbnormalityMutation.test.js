const {
  mutateChargeAbnormalityWithDb,
  parseChargeAbnormalityMutationRequest,
  userCanMutateChargeAbnormality,
} = require('../lib/chargeAbnormalityMutation');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([key, value]) => [
    key,
    clone(value),
  ]));
  const writes = [];
  const directReads = [];
  let transactionRuns = 0;

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
        directReads.push(path);
        return snapshot(path, id);
      },
    };
  }

  const db = {
    collection(name) {
      return {
        doc(id) {
          return ref(name, id);
        },
      };
    },
    async runTransaction(fn) {
      transactionRuns++;
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
  };

  return {
    db,
    store,
    writes,
    directReads,
    get transactionRuns() {
      return transactionRuns;
    },
  };
}

function admin(overrides = {}) {
  return {
    isApproved: true,
    roles: ['admin'],
    name: 'Admin One',
    ...overrides,
  };
}

function abnormality(overrides = {}) {
  return {
    firestoreId: 'abn-1',
    sourceChargeNo: 12001,
    abnormalityTypeId: 'TYPE_OLD',
    abnormalityTypeTitle: 'Old title',
    abnormalityTypeCode: 'TYPE_OLD',
    category: 'equipment',
    severity: 'medium',
    affectedAssets: [{assetType: 'base', assetNumber: 12}],
    component: null,
    observedReason: 'Original observation',
    description: null,
    possibleRootReasonCategory: 'unknown',
    possibleRootReasonNotes: null,
    reannealingStatus: 'required',
    reannealedToChargeNo: null,
    loggedAt: '2026-07-20T08:00:00.000Z',
    updatedAt: '2026-07-20T08:00:00.000Z',
    loggedByUid: 'operator-1',
    loggedByName: 'Operator One',
    updatedByUid: 'operator-1',
    updatedByName: 'Operator One',
    linkedTicketFirestoreId: null,
    linkedExecutionFirestoreId: null,
    version: 4,
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    ...overrides,
  };
}

function abnormalityType(overrides = {}) {
  return {
    firestoreId: 'TYPE_NEW',
    code: 'NEW-CODE',
    title: 'Canonical new title',
    category: 'process',
    severity: 'high',
    isActive: true,
    isDeleted: false,
    ...overrides,
  };
}

function warningForAbnormality(record, overrides = {}) {
  return {
    schemaVersion: 1,
    warningId: `abnormality_${record.firestoreId}`,
    sourceType: 'abnormality',
    sourceId: record.firestoreId,
    sourceVersion: record.version,
    sourceChargeNo: record.sourceChargeNo,
    sourceSummary: record.abnormalityTypeTitle,
    sourceSeverity: record.severity,
    warningReason: record.observedReason,
    affectedAssets: record.affectedAssets,
    component: record.component,
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
    createdAt: record.loggedAt,
    createdByUid: record.loggedByUid,
    createdByName: record.loggedByName,
    updatedAt: record.loggedAt,
    updatedByUid: record.loggedByUid,
    updatedByName: record.loggedByName,
    version: 1,
    ...overrides,
  };
}

function standaloneCase(record = abnormality(), warningOverrides = {}) {
  return {
    [`charge_abnormalities/${record.firestoreId}`]: record,
    [`quality_warnings/abnormality_${record.firestoreId}`]:
      warningForAbnormality(record, warningOverrides),
  };
}

function linkedIssueCase(
  record = abnormality({
    firestoreId: 'issue_quality_ticket-1',
    linkedTicketFirestoreId: 'ticket-1',
  }),
  warningOverrides = {},
) {
  const warningId = 'issue_ticket-1';
  return {
    [`charge_abnormalities/${record.firestoreId}`]: record,
    'maintenance_records/ticket-1': {
      chargeNoAtEvent: record.sourceChargeNo,
      qualityAbnormalityId: record.firestoreId,
      qualityWarningId: warningId,
      chargeQualityCaseId: warningId,
    },
    [`quality_warnings/${warningId}`]: warningForAbnormality(record, {
      warningId,
      sourceType: 'issue',
      sourceId: 'ticket-1',
      sourceVersion: 1,
      ...warningOverrides,
    }),
  };
}

function closedWarning(overrides = {}) {
  return {
    status: 'closed',
    closedAt: '2026-07-25T09:00:00.000Z',
    closedByUid: 'admin-1',
    closedByName: 'Admin One',
    closureDisposition: 'qualityAdjudication',
    decisionReason: 'Duplicate disposition evidence was confirmed.',
    updatedAt: '2026-07-25T09:00:00.000Z',
    updatedByUid: 'admin-1',
    updatedByName: 'Admin One',
    ...overrides,
  };
}

function updateRequest(overrides = {}) {
  return {
    requestId: '11111111-1111-4111-8111-111111111111',
    abnormalityId: 'abn-1',
    operation: 'UPDATE',
    expectedVersion: 4,
    reason: 'Corrected after Admin review',
    abnormalityTypeId: 'TYPE_NEW',
    severity: 'critical',
    affectedAssets: [
      {assetType: 'furnace', assetNumber: 7},
      {assetType: 'innerCover', assetNumber: 19},
    ],
    component: 'Burner assembly',
    observedReason: 'Revised observation',
    description: 'Detailed correction',
    possibleRootReasonCategory: 'furnaceRelated',
    possibleRootReasonNotes: 'Inspection confirmed the source',
    reannealingStatus: 'completed',
    reannealedToChargeNo: 12002,
    ...overrides,
  };
}

function governedAffectedAsset(assetNumber = 7) {
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

function deleteRequest(overrides = {}) {
  return {
    requestId: '22222222-2222-4222-8222-222222222222',
    abnormalityId: 'abn-1',
    operation: 'SOFT_DELETE',
    expectedVersion: 4,
    reason: 'Duplicate record confirmed',
    ...overrides,
  };
}

function invoke(db, data, extra = {}) {
  return mutateChargeAbnormalityWithDb({
    db,
    authUid: 'admin-1',
    data,
    now: () => new Date('2026-07-26T10:00:00.000Z'),
    timestampFromDate: (date) => ({
      seconds: Math.floor(date.valueOf() / 1000),
      nanoseconds: (date.valueOf() % 1000) * 1000000,
    }),
    ...extra,
  });
}

describe('charge-abnormality admin mutation', () => {
  function creation(overrides = {}) {
    return {requestId: '77777777-7777-4777-8777-777777777777',
      abnormalityId: 'abn-1', operation: 'CREATE', expectedVersion: 0,
      reason: 'Created charge abnormality',
      abnormality: abnormality({version: 1, ...overrides})};
  }

  function creationDb() {
    return fakeDb({'users/operator-1': admin({roles: ['operations'], name: 'Operator One'}),
      'abnormality_types/TYPE_OLD': abnormalityType({firestoreId: 'TYPE_OLD'})});
  }

  test('Operations creates a governed case atomically and replays without duplicates', async () => {
    const fixture = creationDb();
    const data = creation({affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governedAffectedAsset()]});
    const first = await invoke(fixture.db, data, {authUid: 'operator-1'});
    const replay = await invoke(fixture.db, data, {authUid: 'operator-1'});
    expect(first.version).toBe(1);
    expect(replay.idempotentReplay).toBe(true);
    expect(fixture.writes).toHaveLength(4);
    expect(first.abnormality.affectedAssets).toEqual([{assetType: 'furnace', assetNumber: 7}]);
    expect(first.abnormality.affectedAssetHierarchyRefs).toEqual([governedAffectedAsset()]);
    const warning = fixture.store.get('quality_warnings/abnormality_abn-1');
    expect(warning.sourceSummary).toBe('Canonical new title');
    expect(warning.sourceChargeNo).toBe(first.abnormality.sourceChargeNo);
  });

  test.each([
    {affectedAssets: [{assetType: 'oops', assetNumber: 7}]},
    {affectedAssets: [{assetType: 'base', assetNumber: -1}]},
    {affectedAssets: [{assetType: 'base', assetNumber: 1.5}]},
    {affectedAssets: [{assetType: 'base', assetNumber: 1, surprise: true}]},
    {affectedAssets: [{assetType: 'base', assetNumber: 1}, {assetType: 'base', assetNumber: 1}]},
    {affectedAssetHierarchyRefs: [governedAffectedAsset()]},
    {affectedAssets: [{...governedAffectedAsset(), assetHierarchyRef: {schemaVersion: 4}}]},
    {linkedTicketFirestoreId: 'other-ticket'},
    {_globalPullServerUpdatedAt: '2026-07-20T08:00:00.000Z'},
  ])('rejects malformed CREATE data without partial writes: %j', async (overrides) => {
    const fixture = creationDb();
    await expect(invoke(fixture.db, creation(overrides), {authUid: 'operator-1'}))
      .rejects.toMatchObject({code: 'invalid-argument'});
    expect(fixture.writes).toHaveLength(0);
  });

  test('original actor is required and retired types cannot create new cases', async () => {
    const fixture = creationDb();
    await expect(invoke(fixture.db, creation({loggedByUid: 'someone-else'}), {authUid: 'operator-1'}))
      .rejects.toMatchObject({code: 'permission-denied'});
    fixture.store.set('abnormality_types/TYPE_OLD', abnormalityType({firestoreId: 'TYPE_OLD', isActive: false}));
    await expect(invoke(fixture.db, creation(), {authUid: 'operator-1'})).rejects.toBeDefined();
    expect(fixture.writes).toHaveLength(0);
  });

  test('legacy offline draft starts canonical version one', async () => {
    const fixture = creationDb();
    const result = await invoke(fixture.db, creation({version: 4}), {authUid: 'operator-1'});
    expect(result.version).toBe(1);
  });

  test.each(['admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'operations'])(
    '%s retains CREATE authority at both callable boundaries', async (role) => {
      const actor = admin({roles: [role]});
      expect(userCanMutateChargeAbnormality(actor, 'CREATE')).toBe(true);
      expect(userCanMutateChargeAbnormality(actor, 'UPDATE')).toBe(role === 'admin');
      const fixture = creationDb();
      fixture.store.set('users/operator-1', actor);
      await expect(invoke(fixture.db, creation(), {authUid: 'operator-1'})).resolves.toMatchObject({version: 1});
    });

  test.each([0, 50])('%i-asset legacy saved draft migrates through governed CREATE', async (count) => {
    const fixture = creationDb();
    const result = await invoke(fixture.db, creation({version: 4,
      affectedAssets: Array.from({length: count}, (_, i) => ({assetType: 'base', assetNumber: i + 1}))}),
    {authUid: 'operator-1'});
    expect(result.abnormality.affectedAssets).toHaveLength(count);
  });

  test('governed affected component is accepted and identity-bound', () => {
    const parsed = parseChargeAbnormalityMutationRequest(updateRequest({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governedAffectedAsset(7)],
    }));
    expect(parsed.update.affectedAssets[0]).toEqual({
      assetType: 'furnace',
      assetNumber: 7,
    });
    expect(parsed.update.affectedAssetHierarchyRefs[0])
      .toEqual(governedAffectedAsset(7));

    const legacyInline = parseChargeAbnormalityMutationRequest(updateRequest({
      affectedAssets: [governedAffectedAsset(7)],
    }));
    expect(legacyInline.update.affectedAssets[0]).toEqual({
      assetType: 'furnace',
      assetNumber: 7,
    });
    expect(legacyInline.update.affectedAssetHierarchyRefs[0])
      .toEqual(governedAffectedAsset(7));

    const mismatched = governedAffectedAsset(7);
    mismatched.assetNumber = 8;
    expect(() => parseChargeAbnormalityMutationRequest(updateRequest({
      affectedAssets: [{assetType: 'furnace', assetNumber: 8}],
      affectedAssetHierarchyRefs: [mismatched],
    }))).toThrow('hierarchy reference is malformed');
    expect(() => parseChargeAbnormalityMutationRequest(updateRequest({
      affectedAssets: [],
    }))).toThrow('between 1 and 50');
  });

  test('mixed legacy and canonical Inner Cover instants retain IST chronology', () => {
    const governed = governedAffectedAsset(7);
    governed.assetHierarchyRef.innerCoverAssociation = {
      baseAssetInstanceId: 'furnace-7',
      baseAssetNumber: 7,
      positionState: 'linked',
      innerCoverId: 'inner-cover-gr26',
      innerCoverSerialNumber: 'GR26',
      linkageId: 'link-furnace-7-gr26',
      assignmentVersion: 2,
      linkedAt: '2026-07-26T14:00:00.000',
      eventAt: '2026-07-26T09:00:00.000Z',
      confirmedAt: '2026-07-26T09:05:00.000Z',
      confirmedByUid: 'admin-1',
      confirmedByName: 'Admin One',
    };

    const parsed = parseChargeAbnormalityMutationRequest(updateRequest({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governed],
    }));

    expect(parsed.update.affectedAssetHierarchyRefs[0]).toEqual(governed);
  });

  test('update atomically canonicalizes type data and writes audit plus receipt', async () => {
    const serverStamp = {seconds: 1785056400, nanoseconds: 0};
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        _globalPullServerUpdatedAt: serverStamp,
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    const result = await invoke(state.db, updateRequest());

    expect(result).toMatchObject({
      ok: true,
      operation: 'UPDATE',
      version: 5,
      idempotentReplay: false,
      auditId:
        'server_charge_abnormality_11111111-1111-4111-8111-111111111111',
    });
    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      abnormalityTypeId: 'TYPE_NEW',
      abnormalityTypeCode: 'NEW-CODE',
      abnormalityTypeTitle: 'Canonical new title',
      category: 'process',
      severity: 'critical',
      version: 5,
      updatedByUid: 'admin-1',
      updatedByName: 'Admin One',
      updatedAt: '2026-07-26T10:00:00.000Z',
      isDeleted: false,
      _globalPullServerUpdatedAt: serverStamp,
    });
    expect(state.store.get('quality_warnings/abnormality_abn-1'))
      .toMatchObject({
        sourceVersion: 5,
        sourceSummary: 'Canonical new title',
        status: 'closureRequested',
        closureRequestReason: 'Corrected after Admin review',
        closureRequestedByUid: 'admin-1',
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        version: 2,
      });
    expect(state.store.get(result.auditId)).toBeUndefined();
    expect(state.store.get(`audit_logs/${result.auditId}`)).toMatchObject({
      eventType: 'chargeAbnormalityMutation',
      entityId: 'abn-1',
      action: 'update',
      requestId: result.requestId,
      expectedVersion: 4,
      resultVersion: 5,
      timestamp: {seconds: 1785060000, nanoseconds: 0},
    });
    expect(
      state.store.get(
        'charge_abnormality_mutation_receipts/' + result.requestId,
      ),
    ).toMatchObject({
      actorUid: 'admin-1',
      abnormalityId: 'abn-1',
      operation: 'UPDATE',
      resultVersion: 5,
      auditId: result.auditId,
    });
    expect(state.writes).toHaveLength(4);
  });

  test('older identity-only updates preserve unchanged hierarchy evidence', async () => {
    const governed = governedAffectedAsset(7);
    const record = abnormality({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governed],
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
    }));

    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governed],
    });
    expect(state.store.get('quality_warnings/abnormality_abn-1'))
      .toMatchObject({
        affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      });
  });

  test('an explicit empty legacy hierarchy list cannot erase current evidence', async () => {
    const governed = governedAffectedAsset(7);
    const record = abnormality({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governed],
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [],
    }));

    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
      affectedAssetHierarchyRefs: [governed],
    });
  });

  test('a partial hierarchy correction preserves other governed evidence', async () => {
    const furnace7 = governedAffectedAsset(7);
    const furnace8 = governedAffectedAsset(8);
    const revisedFurnace7 = {
      ...furnace7,
      assetHierarchyRef: {
        ...furnace7.assetHierarchyRef,
        nodeId: 'burner-block-2',
        nodeName: 'Burner block 2',
        hierarchyPath: ['Furnace', 'Combustion system', 'Burner block 2'],
      },
    };
    const affectedAssets = [
      {assetType: 'furnace', assetNumber: 7},
      {assetType: 'furnace', assetNumber: 8},
    ];
    const record = abnormality({
      affectedAssets,
      affectedAssetHierarchyRefs: [furnace7, furnace8],
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest({
      affectedAssets,
      affectedAssetHierarchyRefs: [revisedFurnace7],
    }));

    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      affectedAssets,
      affectedAssetHierarchyRefs: [revisedFurnace7, furnace8],
    });
  });

  test('historical empty-asset abnormality remains repairable', async () => {
    const record = abnormality({affectedAssets: []});
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest());

    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      affectedAssets: [
        {assetType: 'furnace', assetNumber: 7},
        {assetType: 'innerCover', assetNumber: 19},
      ],
      version: 5,
    });
  });

  test('future-dated abnormality and warning fail without clock regression', async () => {
    const futureAbnormality = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        updatedAt: '2026-07-27T10:00:00.000Z',
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(futureAbnormality.db, updateRequest()))
      .rejects.toMatchObject({
        code: 'aborted',
        details: {reasonCode: 'charge-abnormality-clock-regression'},
      });
    expect(futureAbnormality.writes).toHaveLength(0);

    const record = abnormality();
    const futureWarning = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record, {
        updatedAt: '2026-07-27T10:00:00.000Z',
      }),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(futureWarning.db, updateRequest()))
      .rejects.toMatchObject({
        code: 'aborted',
        details: {reasonCode: 'charge-quality-warning-clock-regression'},
      });
    expect(futureWarning.writes).toHaveLength(0);
  });

  test('legacy timezone-less plant timestamps retain their IST meaning', async () => {
    const record = abnormality({
      loggedAt: '2026-07-26T14:30:00.000',
      updatedAt: '2026-07-26T15:00:00.000',
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record, {
        createdAt: record.loggedAt,
        updatedAt: record.updatedAt,
      }),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    const result = await invoke(state.db, updateRequest());

    expect(result).toMatchObject({ok: true, version: 5});
    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      updatedAt: '2026-07-26T10:00:00.000Z',
      version: 5,
    });
  });

  test('soft delete preserves origin fields and atomically records evidence', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality(), closedWarning()),
    });

    const result = await invoke(state.db, deleteRequest());
    const deleted = state.store.get('charge_abnormalities/abn-1');

    expect(result).toMatchObject({
      operation: 'SOFT_DELETE',
      version: 5,
      idempotentReplay: false,
    });
    expect(deleted).toMatchObject({
      firestoreId: 'abn-1',
      sourceChargeNo: 12001,
      loggedByUid: 'operator-1',
      loggedAt: '2026-07-20T08:00:00.000Z',
      isDeleted: true,
      deletedByUid: 'admin-1',
      deletedByName: 'Admin One',
      deleteReason: 'Duplicate record confirmed',
      updatedByUid: 'admin-1',
      version: 5,
    });
    expect(state.store.get(`audit_logs/${result.auditId}`)).toMatchObject({
      action: 'delete',
      operation: 'SOFT_DELETE',
    });
    expect(state.writes).toHaveLength(3);
  });

  test('linked issue abnormality updates the same quality case', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...linkedIssueCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest({
      abnormalityId: 'issue_quality_ticket-1',
      reannealingStatus: 'notRequired',
      reannealedToChargeNo: null,
    }));

    expect(state.store.get('charge_abnormalities/issue_quality_ticket-1'))
      .toMatchObject({reannealingStatus: 'notRequired', version: 5});
    expect(state.store.get('quality_warnings/issue_ticket-1')).toMatchObject({
      sourceType: 'issue',
      sourceId: 'ticket-1',
      sourceVersion: 1,
      status: 'closureRequested',
      closureRequestReason: 'Corrected after Admin review',
      closureRequestedByUid: 'admin-1',
      closureDisposition: null,
      version: 2,
    });
  });

  test('Admin can correct the target charge of a completed RA case', async () => {
    const record = abnormality({
      reannealingStatus: 'completed',
      reannealedToChargeNo: 12002,
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(record, {
        status: 'closed',
        closedAt: '2026-07-25T09:00:00.000Z',
        closedByUid: 'admin-1',
        closedByName: 'Admin One',
        closureDisposition: 'reannealingCompleted',
        linkedReannealingChargeNos: [12002],
        decisionReason: 'The first recorded target charge was accepted.',
        updatedAt: '2026-07-25T09:00:00.000Z',
        updatedByUid: 'admin-1',
        updatedByName: 'Admin One',
      }),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await invoke(state.db, updateRequest({
      reannealingStatus: 'completed',
      reannealedToChargeNo: 12003,
      reason: 'Corrected the resulting charge against the production record.',
    }));

    expect(state.store.get('charge_abnormalities/abn-1')).toMatchObject({
      reannealingStatus: 'completed',
      reannealedToChargeNo: 12003,
      version: 5,
    });
    expect(state.store.get('quality_warnings/abnormality_abn-1'))
      .toMatchObject({
        status: 'closureRequested',
        closureRequestReason:
          'Corrected the resulting charge against the production record.',
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        version: 2,
      });
  });

  test('Admin RA completion requires a prior required decision', async () => {
    const record = abnormality({
      firestoreId: 'issue_quality_ticket-1',
      linkedTicketFirestoreId: 'ticket-1',
      reannealingStatus: 'pendingDecision',
    });
    const state = fakeDb({
      'users/admin-1': admin(),
      ...linkedIssueCase(record),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(invoke(state.db, updateRequest({
      abnormalityId: record.firestoreId,
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'charge-quality-ra-not-required'},
    });
    expect(state.writes).toHaveLength(0);
    expect(state.store.get(`charge_abnormalities/${record.firestoreId}`))
      .toMatchObject({
        reannealingStatus: 'pendingDecision',
        reannealedToChargeNo: null,
        version: 4,
      });
    expect(state.store.get('quality_warnings/issue_ticket-1'))
      .toMatchObject({
        status: 'open',
        linkedReannealingChargeNos: [],
        version: 1,
      });
  });

  test('missing warnings and independent deletion of linked cases fail closed', async () => {
    const missing = fakeDb({
      'users/admin-1': admin(),
      'charge_abnormalities/abn-1': abnormality(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(missing.db, updateRequest())).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'charge-quality-warning-missing'},
    });
    expect(missing.writes).toHaveLength(0);

    const linked = fakeDb({
      'users/admin-1': admin(),
      ...linkedIssueCase(abnormality({
        firestoreId: 'issue_quality_ticket-1',
        linkedTicketFirestoreId: 'ticket-1',
      }), closedWarning()),
    });
    await expect(invoke(linked.db, deleteRequest({
      abnormalityId: 'issue_quality_ticket-1',
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'linked-charge-abnormality-delete-denied'},
    });
    expect(linked.writes).toHaveLength(0);

    const open = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
    });
    await expect(invoke(open.db, deleteRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'charge-quality-warning-open'},
    });
    expect(open.writes).toHaveLength(0);
  });

  test('exact replay returns verified evidence without additional writes', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    const request = updateRequest();

    const first = await invoke(state.db, request);
    const second = await invoke(state.db, request);

    expect(first.idempotentReplay).toBe(false);
    expect(second).toMatchObject({
      requestId: first.requestId,
      auditId: first.auditId,
      version: 5,
      idempotentReplay: true,
    });
    expect(state.writes).toHaveLength(4);
  });

  test('request identity cannot be rebound to another payload', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    const request = updateRequest();
    await invoke(state.db, request);

    await expect(
      invoke(state.db, updateRequest({
        observedReason: 'Different payload',
      })),
    ).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'abnormality-request-id-conflict'},
    });
    expect(state.writes).toHaveLength(4);
  });

  test('unauthorized actor is rejected before target read or transaction', async () => {
    const state = fakeDb({
      'users/admin-1': admin({roles: ['si']}),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(invoke(state.db, updateRequest())).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'approved-admin-required'},
    });
    expect(state.directReads).toEqual(['users/admin-1']);
    expect(state.transactionRuns).toBe(0);
    expect(state.writes).toHaveLength(0);
  });

  test('authority is revalidated inside the transaction', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(
      invoke(state.db, updateRequest(), {
        beforeTransactionForTest: async () => {
          state.store.set('users/admin-1', admin({isApproved: false}));
        },
      }),
    ).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'approved-admin-required'},
    });
    expect(state.writes).toHaveLength(0);
  });

  test('stale version and inactive type both fail before any write', async () => {
    const stale = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(
      invoke(stale.db, updateRequest({expectedVersion: 3})),
    ).rejects.toMatchObject({
      code: 'aborted',
      details: expect.objectContaining({
        reasonCode: 'abnormality-preimage-mismatch',
        currentVersion: 4,
      }),
    });
    expect(stale.writes).toHaveLength(0);

    const inactive = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType({isActive: false}),
    });
    await expect(invoke(inactive.db, updateRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-type-invalid',
      }),
    });
    expect(inactive.writes).toHaveLength(0);
  });

  test('incomplete existing records fail closed', async () => {
    const malformed = abnormality();
    delete malformed.possibleRootReasonNotes;
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(malformed),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(invoke(state.db, updateRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-record-malformed',
        field: 'possibleRootReasonNotes',
      }),
    });
    expect(state.writes).toHaveLength(0);
  });

  test('malformed global-pull server clock fails closed', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        _globalPullServerUpdatedAt: 'not-a-timestamp',
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(invoke(state.db, updateRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-record-malformed',
        field: '_globalPullServerUpdatedAt',
      }),
    });
    expect(state.writes).toHaveLength(0);
  });

  test('inconsistent existing RA or deletion metadata fails closed', async () => {
    const invalidRa = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        reannealingStatus: 'completed',
        reannealedToChargeNo: null,
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(invalidRa.db, updateRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-record-malformed',
        field: 'reannealingStatus',
      }),
    });
    expect(invalidRa.writes).toHaveLength(0);

    const invalidRaCharge = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        reannealingStatus: 'completed',
        reannealedToChargeNo: 123,
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(invalidRaCharge.db, updateRequest()))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: expect.objectContaining({
          reasonCode: 'abnormality-record-malformed',
          field: 'reannealedToChargeNo',
        }),
      });
    expect(invalidRaCharge.writes).toHaveLength(0);

    const invalidDelete = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(abnormality({
        deletedAt: '2026-07-25T10:00:00.000Z',
      })),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    await expect(invoke(invalidDelete.db, updateRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'abnormality-record-malformed',
        field: 'isDeleted',
      }),
    });
    expect(invalidDelete.writes).toHaveLength(0);
  });

  test('re-annealed target cannot equal the immutable source charge', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });

    await expect(invoke(state.db, updateRequest({
      reannealedToChargeNo: 12001,
    }))).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'reannealed-charge-matches-source'},
    });
    expect(state.writes).toHaveLength(0);
  });

  test('inconsistent re-annealing state is rejected before database access', async () => {
    expect(() =>
      parseChargeAbnormalityMutationRequest(updateRequest({
        reannealingStatus: 'completed',
        reannealedToChargeNo: null,
      })),
    ).toThrow(expect.objectContaining({
      code: 'invalid-argument',
      details: expect.objectContaining({
        reasonCode: 'inconsistent-reannealing-state',
      }),
    }));
  });

  test('replay fails closed when immutable audit evidence disappears', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    const request = updateRequest();
    const result = await invoke(state.db, request);
    state.store.delete(`audit_logs/${result.auditId}`);

    await expect(invoke(state.db, request)).rejects.toMatchObject({
      code: 'data-loss',
      details: {reasonCode: 'abnormality-audit-missing'},
    });
    expect(state.writes).toHaveLength(4);
  });

  test('old replay aborts after a later governed version changes the target', async () => {
    const state = fakeDb({
      'users/admin-1': admin(),
      ...standaloneCase(),
      'abnormality_types/TYPE_NEW': abnormalityType(),
    });
    const request = updateRequest();
    await invoke(state.db, request);
    state.store.set('charge_abnormalities/abn-1', {
      ...state.store.get('charge_abnormalities/abn-1'),
      observedReason: 'Later governed correction',
      updatedAt: '2026-07-26T11:00:00.000Z',
      version: 6,
    });

    await expect(invoke(state.db, request)).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'abnormality-replay-evidence-drift'},
    });
    expect(state.writes).toHaveLength(4);
  });
});
