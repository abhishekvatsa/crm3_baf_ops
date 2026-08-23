const {
  mutateChargeAbnormalityWithDb,
  parseChargeAbnormalityMutationRequest,
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
    reannealingStatus: 'notApplicable',
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
        status: 'closed',
        closureDisposition: 'reannealingCompleted',
        linkedReannealingChargeNos: [12002],
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
      status: 'closed',
      closureDisposition: 'coilFoundAcceptable',
      version: 2,
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
