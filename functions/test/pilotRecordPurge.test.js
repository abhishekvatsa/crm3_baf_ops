const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  PILOT_PURGE_RECEIPT_COLLECTION,
  PILOT_PURGE_MANIFEST_COLLECTION,
  isAuthorizedPilotRecordPurge,
  pilotPurgeReceiptId,
  pilotPurgeSourceDigest,
} = require('../lib/pilotRecordPurge');
const {
  applyGlobalPullServerClock,
} = require('../lib/globalPullServerClock');

const now = new Date('2026-08-25T12:00:00.000Z');

function fixture({
  role = 'admin',
  collection = 'maintenance_records',
  id = 'record-1',
  source = {},
} = {}) {
  const store = new MemoryWorkflowStore();
  store.seed('users/actor-1', {
    isApproved: true,
    roles: [role],
    name: 'Approved Actor',
  });
  store.seed(`${collection}/${id}`, {
    firestoreId: id,
    version: 7,
    isDeleted: true,
    deletedAt: '2026-08-25T11:00:00.000Z',
    _globalPullServerUpdatedAt: '2026-08-25T11:00:03.000Z',
    ...source,
  });
  return {
    store,
    service: new MaintenanceWorkflowCommandService(store),
    context: {
      actor: {uid: 'actor-1', name: 'Untrusted client name'},
      serverNow: now,
    },
    command: {
      commandId: `purge_${collection}_${id}`,
      commandType: 'purgePilotBusinessRecord',
      aggregateId: id,
      expectedVersion: 7,
      payload: {
        collectionId: collection,
        documentId: id,
        reason: 'Duplicate test record from the controlled pilot.',
        confirmation: `DELETE ${id}`,
      },
    },
  };
}

function fakeReceiptDb(store) {
  return {
    doc: (path) => ({
      get: async () => {
        const data = store.read(path);
        return {exists: data != null, data: () => data ?? undefined};
      },
    }),
  };
}

function producerFixture() {
  const current = fixture();
  current.store = new MemoryWorkflowStore();
  current.service = new MaintenanceWorkflowCommandService(current.store);
  current.store.seed('users/actor-1', {
    isApproved: true, roles: ['admin'], name: 'Approved Actor',
  });
  current.store.seed('asset_classes/class-furnace', {
    schemaVersion: 1, assetClassId: 'class-furnace', status: 'active',
    legacyAssetTypeKey: 'furnace', code: 'FR', name: 'Furnace',
  });
  current.store.seed('asset_instances/asset-furnace-7', {
    schemaVersion: 1, assetInstanceId: 'asset-furnace-7',
    assetClassId: 'class-furnace', assetClassCode: 'FR', assetClassName: 'Furnace',
    assetNumber: 7, name: 'Furnace 7', status: 'active', version: 4,
    ownershipStatus: 'confirmed', ownerDiscipline: 'Operations',
    accountableRoleKeys: ['operations'],
  });
  return current;
}

function createTicketCommand(id, continuesIssueId) {
  return {
    commandId: `create_${id}`, commandType: 'createMaintenanceTicket',
    aggregateId: id, expectedVersion: 0,
    payload: {ticket: {
      schemaVersion: 1, version: 1, assetType: 'furnace', assetNumber: 7,
      component: 'Furnace body', subsystem: null, tag: null,
      hierarchyPath: ['Furnace', 'Furnace 7'],
      assetHierarchyRefJson: JSON.stringify({schemaVersion: 3, scope: 'physicalAsset',
        assetClassId: 'class-furnace', assetInstanceId: 'asset-furnace-7', assetInstanceVersion: 4}),
      maintenanceType: 'breakdown', classification: null,
      description: 'Furnace shell temperature is above the expected range.',
      routedTo: 'mechanical', otherDepartment: null, isCritical: false,
      startDate: '2026-08-25T10:00:00.000Z', chargeNoAtEvent: null,
      qualityIntentSchemaVersion: 1, qualityImpactAssessment: 'notSuspected',
      qualityWarningReason: null,
      ...(continuesIssueId == null ? {} : {continuesIssueId}),
    }},
  };
}

async function withdrawAndStamp(current, id) {
  const path = `maintenance_records/${id}`;
  const before = current.store.read(path);
  await current.service.execute({
    commandId: `withdraw_${id}`, commandType: 'correctMaintenanceTicket',
    aggregateId: id, expectedVersion: before.version,
    payload: {withdrawInError: true, corrections: {}, reason: 'Duplicate of the verified issue.'},
  }, current.context);
  const after = current.store.read(path);
  const ref = {update: async (stamp) => current.store.runTransaction(async (tx) => tx.update(path, stamp))};
  expect(await applyGlobalPullServerClock({
    collectionId: 'maintenance_records',
    change: {before: {exists: true, data: () => before, ref}, after: {exists: true, data: () => after, ref}},
    serverTimestamp: () => now.toISOString(),
  })).toBe('stamped');
  return current.store.read(path);
}

describe('Admin-only permanent pilot record removal', () => {
  test.each(['maintenance_records', 'directives', 'job_templates'])(
    'removes an already-deleted %s record with immutable exact evidence',
    async (collection) => {
      const current = fixture({collection});
      const before = current.store.read(`${collection}/record-1`);
      const result = await current.service.execute(
        current.command,
        current.context,
      );

      const id = pilotPurgeReceiptId(collection, 'record-1');
      const evidence = current.store.read(
        `${PILOT_PURGE_RECEIPT_COLLECTION}/${id}`,
      );
      const manifest = current.store.read(
        `${PILOT_PURGE_MANIFEST_COLLECTION}/${id}`,
      );

      expect(current.store.read(`${collection}/record-1`)).toBeNull();
      expect(evidence).toEqual({
        schemaVersion: 1,
        sourceCollection: collection,
        sourceDocumentId: 'record-1',
        sourcePath: `${collection}/record-1`,
        sourceVersion: 7,
        sourceDigest: pilotPurgeSourceDigest(before),
        purgedAt: now.toISOString(),
        purgedByUid: 'actor-1',
        purgedByName: 'Approved Actor',
        reason: current.command.payload.reason,
        commandId: current.command.commandId,
      });
      expect(manifest).toEqual({
        schemaVersion: 1,
        sourceCollection: collection,
        sourceDocumentId: 'record-1',
        sourceVersion: 7,
        purgedAt: now.toISOString(),
      });
      expect(result.resultKey).toBe('pilot-record-permanently-removed');
      expect(result.result.purgeReceiptId).toBe(id);
      expect(result.result.sourceDigest).toBe(evidence.sourceDigest);
    },
  );

  test.each(['si', 'operations', 'contractSupervisor'])(
    '%s cannot use the irreversible Admin authority',
    async (role) => {
      const current = fixture({role});

      await expect(
        current.service.execute(current.command, current.context),
      ).rejects.toMatchObject({code: 'permission-denied'});
      expect(current.store.read('maintenance_records/record-1')).not.toBeNull();
    },
  );

  test('rejects every collection outside the narrow pilot allowlist', async () => {
    const current = fixture({collection: 'users'});

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'pilot-record-purge-collection-not-allowed'},
    });
    expect(current.store.read('users/record-1')).not.toBeNull();
  });

  test.each([
    {
      title: 'active record',
      source: {isDeleted: false},
      reasonCode: 'pilot-record-purge-soft-delete-required',
    },
    {
      title: 'missing deletion evidence',
      source: {deletedAt: null},
      reasonCode: 'pilot-record-purge-soft-delete-required',
    },
    {
      title: 'unstamped deletion',
      source: {_globalPullServerUpdatedAt: null},
      reasonCode: 'pilot-record-purge-server-stamp-required',
    },
  ])('preserves an $title', async ({source, reasonCode}) => {
    const current = fixture({source});

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({details: {reasonCode}});
    expect(current.store.read('maintenance_records/record-1')).not.toBeNull();
  });

  test('rejects stale versions and mismatched typed confirmation', async () => {
    const current = fixture();
    await expect(
      current.service.execute(
        {...current.command, expectedVersion: 6},
        current.context,
      ),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-version-conflict'},
    });

    await expect(
      current.service.execute(
        {
          ...current.command,
          payload: {...current.command.payload, confirmation: 'DELETE other'},
        },
        current.context,
      ),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-confirmation-mismatch'},
    });
  });

  test.each([
    ['directives', 'linkedMaintenanceFirestoreId', false],
    ['charge_abnormalities', 'linkedTicketFirestoreId', false],
    ['maintenance_workflows', 'linkedMaintenanceFirestoreId', false],
    ['compliance_requests', 'linkedMaintenanceFirestoreId', false],
    ['operational_event_issue_links', 'issueId', false],
    ['operational_events', 'linkedIssueIds', true],
    ['asset_operational_conditions', 'linkedIssueIds', true],
    ['inspection_issue_links', 'ticketId', false],
    ['inspection_findings', 'linkedTicketId', false],
    ['furnace_stuckup_cases', 'ticketId', false],
  ])('preserves ticket referenced by %s', async (collection, field, list) => {
    const current = fixture();
    current.store.seed(`${collection}/reference-1`, {
      [field]: list ? ['record-1'] : 'record-1',
    });

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({code: 'failed-precondition'});
    expect(current.store.read('maintenance_records/record-1')).not.toBeNull();
  });

  test('preserves a ticket referenced by a same-collection continuation', async () => {
    const current = fixture();
    current.store.seed('maintenance_records/successor-1', {
      firestoreId: 'successor-1',
      continuesIssueId: 'record-1',
      version: 1,
      isDeleted: false,
    });

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-linked-maintenance-continuation'},
    });
    expect(current.store.read('maintenance_records/record-1')).not.toBeNull();
  });

  test('actual retained-concern successor prevents purging its withdrawn predecessor', async () => {
    const current = producerFixture();
    await current.service.execute(createTicketCommand('record-1'), current.context);
    const created = current.store.read('maintenance_records/record-1');
    await current.service.execute({
      commandId: 'retain_record-1', commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'record-1', expectedVersion: created.version,
      payload: {disposition: 'stillRelevant', reason: 'The charge ended, but engineering must review this unresolved condition.'},
    }, current.context);
    await current.service.execute(createTicketCommand('successor-1', 'record-1'), current.context);
    const successor = current.store.read('maintenance_records/successor-1');
    expect(successor).toMatchObject({continuesIssueId: 'record-1', isDeleted: false});
    const beforePurge = await withdrawAndStamp(current, 'record-1');
    const beforeEntries = current.store.entries();
    await expect(current.service.execute({...current.command, expectedVersion: beforePurge.version}, current.context))
      .rejects.toMatchObject({details: {reasonCode: 'pilot-record-purge-linked-maintenance-continuation'}});
    expect(current.store.entries()).toEqual(beforeEntries);
    expect(current.store.read('maintenance_records/successor-1')).toEqual(successor);
  });

  test('actual purge permanently prevents both restored original and fresh create commands after receipt expiry', async () => {
    const current = producerFixture();
    const original = createTicketCommand('record-1');
    await current.service.execute(original, current.context);
    const tombstone = await withdrawAndStamp(current, 'record-1');
    const purge = {...current.command, expectedVersion: tombstone.version};
    await current.service.execute(purge, current.context);
    // Expiring normal command receipts must not expire the permanent manifest.
    await current.store.runTransaction(async (tx) => {
      for (const [path] of current.store.entries()) {
        if (path.startsWith('maintenance_workflow_command_receipts/')) tx.delete(path);
      }
    });
    const manifestPath = `${PILOT_PURGE_MANIFEST_COLLECTION}/${pilotPurgeReceiptId('maintenance_records', 'record-1')}`;
    const manifest = current.store.read(manifestPath);
    expect(manifest).toMatchObject({sourceDocumentId: 'record-1', sourceVersion: tombstone.version});
    expect(manifest.expiresAt).toBeUndefined();
    const restoredService = new MaintenanceWorkflowCommandService(current.store);
    for (const command of [original, {...original, commandId: 'new_create_identity'}]) {
      await expect(restoredService.execute(command, {...current.context, serverNow: new Date('2027-08-25T12:00:00.000Z')}))
        .rejects.toMatchObject({details: {reasonCode: 'maintenance-ticket-identity-permanently-removed'}});
      expect(current.store.read('maintenance_records/record-1')).toBeNull();
      expect(current.store.read(manifestPath)).toEqual(manifest);
    }
  });

  test.each([
    'quality_warnings/issue_record-1',
    'maintenance_burner_closures/record-1',
  ])('preserves ticket with derived evidence %s', async (path) => {
    const current = fixture();
    current.store.seed(path, {exists: true});

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-linked-projection'},
    });
  });

  test.each([
    ['maintenance_completion_events', 'completion-1', {
      sourceType: 'maintenanceIssue',
      sourceId: 'record-1',
    }],
    ['maintenance_completion_sources', 'completion-source-1', {
      sourceType: 'maintenanceIssue',
      sourceId: 'record-1',
    }],
    ['maintenance_due_states', 'due-1', {
      lastCompletionSourceType: 'maintenanceIssue',
      lastCompletionSourceId: 'record-1',
      nextDueAt: '2026-10-13T00:00:00.000Z',
    }],
  ])('preserves a ticket whose classified completion still drives %s',
    async (collection, documentId, data) => {
      const current = fixture();
      current.store.seed(`${collection}/${documentId}`, data);

      // Removing the ticket would leave this record, and the next-due date it
      // carries, pointing at work that no longer exists.
      await expect(
        current.service.execute(current.command, current.context),
      ).rejects.toMatchObject({
        details: {reasonCode: 'pilot-record-purge-linked-maintenance-cadence'},
      });
      expect(current.store.read('maintenance_records/record-1')).not.toBeNull();
    });

  test('a completion belonging to another ticket does not block the purge',
    async () => {
      const current = fixture();
      current.store.seed('maintenance_due_states/due-other', {
        lastCompletionSourceType: 'maintenanceIssue',
        lastCompletionSourceId: 'record-2',
      });
      current.store.seed('maintenance_completion_events/completion-other', {
        sourceType: 'workflowPlannedJob',
        sourceId: 'record-1',
      });

      await expect(
        current.service.execute(current.command, current.context),
      ).resolves.toMatchObject({resultKey: 'pilot-record-permanently-removed'});
    });

  test.each(['job_executions', 'job_modules', 'job_diary_entries'])(
    'preserves a template still referenced by %s',
    async (collection) => {
      const current = fixture({collection: 'job_templates'});
      current.store.seed(`${collection}/reference-1`, {
        templateFirestoreId: 'record-1',
      });

      await expect(
        current.service.execute(current.command, current.context),
      ).rejects.toMatchObject({code: 'failed-precondition'});
    },
  );

  test('preserves a directive retained by burner-condition evidence', async () => {
    const current = fixture({collection: 'directives'});
    current.store.seed('burner_condition_rounds/round-1', {
      directiveId: 'record-1',
    });

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('exact replay succeeds without deleting or creating evidence again', async () => {
    const current = fixture();
    const first = await current.service.execute(
      current.command,
      current.context,
    );
    const second = await current.service.execute(
      current.command,
      current.context,
    );

    expect(second).toEqual(first);
    expect(
      current.store.entries().filter(([path]) =>
        path.startsWith(`${PILOT_PURGE_RECEIPT_COLLECTION}/`),
      ),
    ).toHaveLength(1);
  });

  test('revoked Admin authority cannot replay a completed purge', async () => {
    const current = fixture();
    await current.service.execute(current.command, current.context);
    current.store.seed('users/actor-1', {
      isApproved: true,
      roles: ['si'],
      name: 'Approved Actor',
    });

    await expect(
      current.service.execute(current.command, current.context),
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('replay refuses changed purge evidence or a recreated source record', async () => {
    const altered = fixture();
    await altered.service.execute(altered.command, altered.context);
    const id = pilotPurgeReceiptId('maintenance_records', 'record-1');
    const path = `${PILOT_PURGE_RECEIPT_COLLECTION}/${id}`;
    const receipt = altered.store.read(path);
    altered.store.seed(path, {...receipt, sourceDigest: '0'.repeat(64)});

    await expect(
      altered.service.execute(altered.command, altered.context),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-replay-evidence-invalid'},
    });

    const alteredManifest = fixture();
    await alteredManifest.service.execute(
      alteredManifest.command,
      alteredManifest.context,
    );
    const manifestPath = `${PILOT_PURGE_MANIFEST_COLLECTION}/${id}`;
    const manifest = alteredManifest.store.read(manifestPath);
    alteredManifest.store.seed(manifestPath, {...manifest, sourceVersion: 8});

    await expect(
      alteredManifest.service.execute(
        alteredManifest.command,
        alteredManifest.context,
      ),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-replay-evidence-invalid'},
    });

    const recreated = fixture();
    await recreated.service.execute(recreated.command, recreated.context);
    recreated.store.seed('maintenance_records/record-1', {
      firestoreId: 'record-1',
      version: 8,
      isDeleted: true,
    });

    await expect(
      recreated.service.execute(recreated.command, recreated.context),
    ).rejects.toMatchObject({
      details: {reasonCode: 'pilot-record-purge-replay-evidence-invalid'},
    });
  });
});

describe('server stamp permanent-removal custody', () => {
  test('accepts only an exact immutable receipt bound to the deleted snapshot', async () => {
    const current = fixture();
    const before = current.store.read('maintenance_records/record-1');
    await current.service.execute(current.command, current.context);

    await expect(
      isAuthorizedPilotRecordPurge({
        db: fakeReceiptDb(current.store),
        collectionId: 'maintenance_records',
        documentId: 'record-1',
        before,
      }),
    ).resolves.toBe(true);

    await expect(
      isAuthorizedPilotRecordPurge({
        db: fakeReceiptDb(current.store),
        collectionId: 'maintenance_records',
        documentId: 'record-1',
        before: {...before, version: 8},
      }),
    ).resolves.toBe(false);
  });

  test('an authorized hard delete is not converted back into a tombstone', async () => {
    const writes = [];
    const action = await applyGlobalPullServerClock({
      collectionId: 'directives',
      change: {
        before: {
          exists: true,
          data: () => ({version: 2, isDeleted: true}),
          ref: {set: async (value) => writes.push(value)},
        },
        after: {
          exists: false,
          data: () => undefined,
          ref: {set: async (value) => writes.push(value)},
        },
      },
      serverTimestamp: () => 'SERVER_TIME',
      authorizePermanentDelete: async () => true,
    });

    expect(action).toBe('authorized-permanent-delete');
    expect(writes).toEqual([]);
  });

  test('a stale stamp event cannot recreate a document already purged', async () => {
    const writes = [];
    const action = await applyGlobalPullServerClock({
      collectionId: 'directives',
      change: {
        before: {
          exists: true,
          data: () => ({version: 1}),
          ref: {set: async (value) => writes.push(value)},
        },
        after: {
          exists: true,
          data: () => ({version: 2}),
          ref: {
            get: async () => ({exists: false, data: () => undefined}),
            set: async (value) => writes.push(value),
          },
        },
      },
      serverTimestamp: () => 'SERVER_TIME',
    });

    expect(action).toBe('ignored-empty');
    expect(writes).toEqual([]);
  });

  test('an atomic stamp update cannot recreate a concurrently purged document', async () => {
    const writes = [];
    const action = await applyGlobalPullServerClock({
      collectionId: 'directives',
      change: {
        before: {
          exists: true,
          data: () => ({version: 1}),
          ref: {set: async (value) => writes.push(value)},
        },
        after: {
          exists: true,
          data: () => ({version: 2}),
          ref: {
            update: async () => {
              throw Object.assign(new Error('Document no longer exists'), {
                code: 5,
              });
            },
            set: async (value) => writes.push(value),
          },
        },
      },
      serverTimestamp: () => 'SERVER_TIME',
    });

    expect(action).toBe('ignored-empty');
    expect(writes).toEqual([]);
  });
});
