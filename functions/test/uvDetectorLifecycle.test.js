'use strict';

const {
  workflowFirestoreDataForTest,
} = require('../lib/maintenanceWorkflow/firebaseStore');

const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');

const {IDS, actor, action, reference, lockoutAction, seedStore, prepare} = require('./fixtures/uvDetectorLifecycleFixture');

describe('UV-detector lifecycle projection', () => {
  test.each(['maintenanceIssue', 'legacyPlannedJob', 'workflowPlannedJob'])(
    '%s accepts legacy Indian action time and preserves the actual installation instant', async (sourceType) => {
      const store = seedStore();
      const row = action({createdAt: '2026-08-28T13:30:00.000'});
      await prepare(store, row, {sourceType});
      const [, event] = store.entries().find(([entryPath]) =>
        entryPath.startsWith('uv_detector_lifecycle_events/'));
      expect(event).toMatchObject({
        actionPerformedAt: '2026-08-28T08:00:00.000Z',
        completedAt: '2026-08-28T09:00:00.000Z',
        sourceType,
      });
      expect(row.createdAt).toBe('2026-08-28T13:30:00.000');
    },
  );

  test('legacy Indian time still cannot move installation after closure', async () => {
    const store = seedStore();
    await expect(prepare(store, action({createdAt: '2026-08-28T14:36:00.000'})))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.entries().filter(([entryPath]) =>
      entryPath.startsWith('uv_detector_lifecycle_events/'))).toHaveLength(0);
  });

  test('rejects a receipt time that precedes authoritative closure', async () => {
    const store = seedStore();

    await expect(prepare(store, action(), {
      recordedAt: '2026-08-28T08:59:00.000Z',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'uv-detector-lifecycle-closure-time-mismatch',
      },
    });
  });

  test('work entered after it finished keeps both times', async () => {
    const store = seedStore();

    const plan = await prepare(store, action(), {
      recordedAt: '2026-08-28T12:00:00.000Z',
    });

    // When the work finished and when it was entered are different facts, and
    // a late entry must not read as contemporaneous evidence.
    expect(plan.events[0].data).toMatchObject({
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T12:00:00.000Z',
    });
  });

  test('projects a governed numbered UV replacement to In service', async () => {
    const store = seedStore();
    const plan = await prepare(store);
    const [, event] = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_events/'));
    const [currentPath, current] = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'));

    expect(plan.events).toHaveLength(1);
    expect(currentPath).toMatch(
      /^uv_detector_lifecycle_current\/uvlc_[a-f0-9]{40}$/,
    );
    expect(event).toMatchObject({
      assetInstanceId: IDS.asset,
      burnerPosition: 3,
      resultingCondition: 'serviceable',
      replacementDisposition: 'newPart',
      installationDiscipline: 'instrumentation',
      sourceType: 'workflowPlannedJob',
      sourceModuleId: 'module-1',
    });
    expect(current).toMatchObject({
      projectionSchemaVersion: 1,
      currentEventId: event.eventId,
      resultingCondition: 'serviceable',
    });
  });

  test('projects burner-lockout UV replacement using the ticket asset identity', async () => {
    const store = seedStore();
    const sourceReference = JSON.stringify({
      ...reference(),
      schemaVersion: 3,
      scope: 'physicalAsset',
      nodeId: IDS.asset,
      nodeVersion: 4,
      nodeName: 'Furnace 7',
      hierarchyPath: ['Furnace', 'Furnace 7'],
    });
    const plan = await prepare(store, lockoutAction(), {
      sourceType: 'maintenanceIssue',
      sourceId: 'ticket-1',
      sourceAssetReferenceJson: sourceReference,
      actionSources: [{
        sourceModuleId: null,
        actionsJson: JSON.stringify([lockoutAction()]),
      }],
      executionLevelInstrumentationEvidence: true,
    });
    const event = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_events/'))[1];

    expect(plan.events).toHaveLength(1);
    expect(event).toMatchObject({
      burnerPosition: 3,
      hierarchyNodeId: null,
      hierarchyNodeName: 'UV detector at Burner 3',
      sourceType: 'maintenanceIssue',
      sourceId: 'ticket-1',
      resultingCondition: 'serviceable',
    });
  });

  test.each(['remainsLockedOut', 'isolatedForFollowUp'])(
    'does not mark a burner-lockout UV replacement serviceable when outcome is %s',
    async (burnerOutcome) => {
      const store = seedStore();
      const sourceReference = JSON.stringify({
        ...reference(),
        schemaVersion: 3,
        scope: 'physicalAsset',
        nodeId: IDS.asset,
        nodeVersion: 4,
        nodeName: 'Furnace 7',
        hierarchyPath: ['Furnace', 'Furnace 7'],
      });
      const row = lockoutAction({burnerOutcome});

      const plan = await prepare(store, row, {
        sourceType: 'maintenanceIssue',
        sourceId: `ticket-${burnerOutcome}`,
        sourceAssetReferenceJson: sourceReference,
        actionSources: [{
          sourceModuleId: null,
          actionsJson: JSON.stringify([row]),
        }],
        executionLevelInstrumentationEvidence: true,
      });

      expect(plan.events).toHaveLength(0);
      expect(plan.currentStates).toHaveLength(0);
      expect(store.entries().some(([path]) =>
        path.startsWith('uv_detector_lifecycle_'))).toBe(false);
    },
  );

  test('rejects generic UV installation outside I&A work', async () => {
    const store = seedStore();
    await expect(prepare(store, action(), {
      actionSources: [{
        sourceModuleId: 'module-1',
        discipline: 'mechanical',
        actionsJson: JSON.stringify([action()]),
      }],
    })).rejects.toMatchObject({
      details: {
        reasonCode: 'uv-detector-lifecycle-instrumentation-work-required',
      },
    });
  });

  test('retains the newest physical installation as current', async () => {
    const store = seedStore();
    await prepare(store, action({
      id: 'newer',
      createdAt: '2026-08-28T08:00:00.000Z',
    }), {sourceId: 'execution-newer'});
    const before = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    await prepare(store, action({
      id: 'older',
      createdAt: '2026-08-28T07:00:00.000Z',
    }), {sourceId: 'execution-older'});
    const after = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    expect(after.currentEventId).toBe(before.currentEventId);
  });

  test('a late older physical installation stays in history and cannot silently replace current', async () => {
    const store = seedStore();
    await prepare(store, action({
      id: 'first-recorded',
      createdAt: '2026-08-28T08:00:00.000Z',
    }), {
      sourceId: 'execution-first-recorded',
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T09:00:00.000Z',
    });

    await prepare(store, action({
      id: 'later-recorded-backdated-action',
      createdAt: '2026-08-27T08:00:00.000Z',
    }), {
      sourceId: 'execution-later-recorded',
      completedAt: '2026-08-28T10:00:00.000Z',
      recordedAt: '2026-08-28T10:00:00.000Z',
    });
    const current = store.entries().find(([path]) =>
      path.startsWith('uv_detector_lifecycle_current/'))[1];

    expect(current.sourceId).toBe('execution-first-recorded');
    expect(current.actionPerformedAt).toBe('2026-08-28T08:00:00.000Z');
    expect(current.recordedAt).toBe('2026-08-28T09:00:00.000Z');
    const history = store.entries().filter(([path]) => path.includes('_lifecycle_events/'));
    expect(history).toHaveLength(2);
    expect(history.some(([, event]) => event.sourceId === 'execution-later-recorded' &&
      event.actionPerformedAt === '2026-08-27T08:00:00.000Z')).toBe(true);
  });

  test('physical-time ties use receipt time, then event identity independent of delivery order', async () => {
    const run = async (order, sameReceiptTime) => {
      const store = seedStore();
      for (const n of order) {
        const receiptTime = sameReceiptTime || n === 1 ?
          '2026-08-28T09:00:00.000Z' : '2026-08-28T10:00:00.000Z';
        await prepare(store, action({id: `tie-${n}`, createdAt: '2026-08-28T08:00:00.000Z'}), {
          sourceId: `execution-tie-${n}`, completedAt: receiptTime, recordedAt: receiptTime,
        });
      }
      return store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1];
    };
    expect((await run([1, 2], false)).sourceId).toBe('execution-tie-2');
    expect((await run([2, 1], false)).sourceId).toBe('execution-tie-2');
    expect((await run([1, 2], true)).currentEventId).toBe((await run([2, 1], true)).currentEventId);
  });

  test('a revised-part disposition does not authorize correction of the current installation', async () => {
    const store = seedStore();
    await prepare(store, action({id: 'physical-later', createdAt: '2026-08-28T08:00:00.000Z'}), {
      sourceId: 'execution-physical-later',
    });
    const before = store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1];
    await prepare(store, action({id: 'late-revised-part', replacement: 'revised',
      createdAt: '2026-08-27T08:00:00.000Z'}), {sourceId: 'execution-revised-history',
      completedAt: '2026-08-28T10:00:00.000Z', recordedAt: '2026-08-28T10:00:00.000Z'});
    expect(store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1]).toEqual(before);
    expect(store.entries().filter(([path]) => path.includes('_lifecycle_events/'))).toHaveLength(2);
  });

  test('renamed class remains compatible with an existing physical asset and frozen action reference', async () => {
    const store = seedStore();
    const path = `asset_classes/${IDS.assetClass}`;
    const current = store.entries().find(([key]) => key === path)[1];
    store.seed(path, {...current, name: 'BAF Heating Furnaces'});
    const plan = await prepare(store);
    expect(plan.events).toHaveLength(1);
    expect(plan.events[0].data.assetClassName).toBe('BAF Heating Furnaces');
    expect(store.entries().find(([key]) => key === `asset_instances/${IDS.asset}`)[1].assetClassName)
      .toBe('Furnace');
  });

  test('accepts Firestore timestamps in an existing current projection', async () => {
    const store = seedStore();
    await prepare(store, action({id: 'first-persisted'}), {
      sourceId: 'execution-first-persisted',
    });
    const [path, current] = store.entries().find(([entryPath]) =>
      entryPath.startsWith('uv_detector_lifecycle_current/'));
    const persisted = workflowFirestoreDataForTest(current);
    expect(typeof persisted.recordedAt.toDate).toBe('function');
    expect(typeof persisted.actionPerformedAt.toDate).toBe('function');
    store.seed(path, persisted);

    await prepare(store, action({
      id: 'second-persisted',
      createdAt: '2026-08-28T09:30:00.000Z',
    }), {
      sourceId: 'execution-second-persisted',
      completedAt: '2026-08-28T10:00:00.000Z',
      recordedAt: '2026-08-28T10:00:00.000Z',
    });

    const after = store.entries().find(([entryPath]) =>
      entryPath.startsWith('uv_detector_lifecycle_current/'))[1];
    expect(after.sourceId).toBe('execution-second-persisted');
  });
});


describe('UV-detector parent-scoped physical action identity', () => {
  const duplicateReferences = (first, second) => [
    {sourceModuleId: null, discipline: 'instrumentation', actionsJson: JSON.stringify([first])},
    {sourceModuleId: 'module-1', discipline: 'instrumentation', actionsJson: JSON.stringify([second])},
  ];

  test.each([
    ['position', {burnerPosition: 4}],
    ['physical time', {createdAt: '2026-08-28T07:15:00.000Z'}],
    ['disposition', {replacement: 'repaired'}],
    ['performer evidence', {performedBy: 'A different technician'}],
  ])('one action with conflicting %s refuses the entire plan', async (_, changedFacts) => {
    const store = seedStore();
    const before = store.entries();
    await expect(prepare(store, action(), {
      actionSources: duplicateReferences(action(), action(changedFacts)),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'uv-detector-lifecycle-action-conflict'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('a different governed asset cannot manufacture a second identity', async () => {
    const store = seedStore();
    const alternateAssetId = 'different-physical-furnace';
    // Both records pass the individual target validation. The repeated action
    // must still reject their contradictory physical IDs, even at one number.
    store.seed(`asset_instances/${alternateAssetId}`, {
      ...store.read(`asset_instances/${IDS.asset}`),
      assetInstanceId: alternateAssetId,
    });
    const row = action();
    const alternative = action({
      assetHierarchyRef: {...row.assetHierarchyRef, assetInstanceId: alternateAssetId},
    });
    const before = store.entries();
    await expect(prepare(store, row, {
      actionSources: duplicateReferences(row, alternative),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'uv-detector-lifecycle-action-conflict'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('exact repeated references count once without rewriting either source payload', async () => {
    const store = seedStore();
    const sources = duplicateReferences(action(), action());
    const retained = JSON.stringify(sources);
    const plan = await prepare(store, action(), {actionSources: sources});
    expect(plan.events).toHaveLength(1);
    expect(plan.currentStates).toHaveLength(1);
    expect(JSON.stringify(sources)).toBe(retained);
    expect(sources.map((source) => source.sourceModuleId)).toEqual([null, 'module-1']);
    expect(sources.every((source) => JSON.parse(source.actionsJson).length === 1)).toBe(true);
  });

  test('distinct action IDs at the same position and time remain separate installations', async () => {
    const store = seedStore();
    const plan = await prepare(store, action(), {
      actionSources: duplicateReferences(action({id: 'first-action'}), action({id: 'second-action'})),
    });
    expect(plan.events).toHaveLength(2);
    expect(plan.events.map((event) => event.data.sourceActionId)).toEqual(['first-action', 'second-action']);
  });

  test('legacy rows without action identity are not heuristically coalesced', async () => {
    const store = seedStore();
    const plan = await prepare(store, action(), {
      actionSources: duplicateReferences(action({id: null}), action({id: null})),
    });
    expect(plan.events).toHaveLength(2);
    expect(plan.events.every((event) => event.data.sourceActionId == null)).toBe(true);
  });

  test('the same local action ID in different parent sources is separate work', async () => {
    const store = seedStore();
    const sources = [
      {sourceType: 'workflowPlannedJob', sourceId: 'parent-a'},
      {sourceType: 'workflowPlannedJob', sourceId: 'parent-b'},
      {sourceType: 'maintenanceIssue', sourceId: 'parent-a'},
    ];
    const ids = [];
    for (const source of sources) {
      const plan = await prepare(store, action(), source);
      expect(plan.events).toHaveLength(1);
      ids.push(plan.events[0].data.eventId);
    }
    expect(new Set(ids).size).toBe(3);
  });
});

describe('uv-detector installation correction command', () => {
  const commandActor = {
    uid: 'admin-1',
    name: 'Admin One',
    roles: new Set(['admin']),
  };

  const eventRows = (store) => store.entries()
    .filter(([entryPath]) => entryPath.startsWith('uv_detector_lifecycle_events/'))
    .map(([, data]) => data);
  const currentRow = (store) => store.entries()
    .find(([entryPath]) => entryPath.startsWith('uv_detector_lifecycle_current/'))?.[1];

  async function seededCommandState(producerOverrides = {}) {
    const store = seedStore();
    await prepare(store, action({createdAt: '2026-08-12T08:00:00.000Z'}), producerOverrides);
    store.seed(`users/${commandActor.uid}`, {
      isApproved: true,
      roles: ['admin'],
      name: commandActor.name,
    });
    const event = eventRows(store)[0];
    const current = currentRow(store);
    const command = {
      commandId: 'correction-command-1',
      commandType: 'correctUvDetectorInstallation',
      aggregateId: 'correction-1',
      expectedVersion: 0,
      payload: {
        eventId: event.eventId,
        expectedCurrentEventId: current.currentEventId,
        expectedCurrentActionPerformedAt: current.actionPerformedAt,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
        reason: 'The register shows the UV detector was fitted on the 10th, not the 12th.',
        supersedesCorrectionId: null,
      },
    };
    return {store, command, event, current};
  }

  test('writes correction evidence, rebuilds current state and replays without writes', async () => {
    const {store, command, event} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    };

    const receipt = await service.execute(command, context);
    expect(receipt.result).toMatchObject({
      correctionId: 'correction-1',
      correctsEventId: event.eventId,
      currentEventId: event.eventId,
      currentActionPerformedAt: '2026-08-10T08:00:00.000Z',
    });
    expect(store.read('uv_detector_lifecycle_corrections/correction-1'))
      .toMatchObject({
        correctsEventId: event.eventId,
        expectedCurrentEventId: event.eventId,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
      });
    expect(store.read('audit_logs/server_uv_detector_correction_correction-command-1'))
      .toMatchObject({entityType: 'uvDetectorInstallationCorrection'});

    // A real Firestore round trip changes ISO strings into Timestamp-shaped
    // values. Replay must compare the instant, not the JavaScript object.
    const correctionPath =
      'uv_detector_lifecycle_corrections/correction-1';
    store.seed(
      correctionPath,
      workflowFirestoreDataForTest(store.read(correctionPath)),
    );
    const afterFirst = store.entries();
    await expect(service.execute(command, context)).resolves.toEqual(receipt);
    expect(store.entries()).toEqual(afterFirst);
  });

  test.each([
    ['target', false], ['target', true],
    ['historical sibling', false], ['historical sibling', true],
  ])('corrects actual producer history with a late-recorded %s (native timestamps: %s)', async (lateEntry, native) => {
    const lateRecording = {recordedAt: '2026-08-28T12:00:00.000Z'};
    const {store, command, event} = await seededCommandState(
      lateEntry === 'target' ? lateRecording : {},
    );
    let expectedCurrentEventId = event.eventId;
    if (lateEntry === 'historical sibling') {
      const plan = await prepare(store, action({
        id: 'late-entered-earlier-installation',
        createdAt: '2026-08-11T08:00:00.000Z',
      }), {...lateRecording, sourceId: 'late-entered-earlier-work'});
      expectedCurrentEventId = plan.events[0].data.eventId;
    }
    expect(eventRows(store).find(row => row.recordedAt === lateRecording.recordedAt))
      .toMatchObject({completedAt: '2026-08-28T09:00:00.000Z'});
    if (native) {
      for (const [path, data] of store.entries()) {
        if (path.startsWith('uv_detector_lifecycle_events/') ||
            path.startsWith('uv_detector_lifecycle_current/')) {
          store.seed(path, workflowFirestoreDataForTest(data));
        }
      }
    }
    const originals = eventRows(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    const receipt = await new MaintenanceWorkflowCommandService(store).execute(command, context);
    expect(receipt.result).toMatchObject({
      correctionId: 'correction-1',
      correctsEventId: event.eventId,
      currentEventId: expectedCurrentEventId,
      currentActionPerformedAt: lateEntry === 'target' ?
        '2026-08-10T08:00:00.000Z' : '2026-08-11T08:00:00.000Z',
    });
    expect(eventRows(store)).toEqual(originals);
    const afterCorrection = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, context))
      .resolves.toEqual(receipt);
    expect(store.entries()).toEqual(afterCorrection);
  });

  test.each(['target', 'historical sibling'])(
    'correction refuses a %s recorded before completion without partial writes', async invalidEntry => {
      const {store, command, event} = await seededCommandState();
      let invalidEventId = event.eventId;
      if (invalidEntry === 'historical sibling') {
        const plan = await prepare(store, action({
          id: 'earlier-installation', createdAt: '2026-08-11T08:00:00.000Z',
        }), {sourceId: 'earlier-work'});
        invalidEventId = plan.events[0].data.eventId;
      }
      const path = `uv_detector_lifecycle_events/${invalidEventId}`;
      store.seed(path, workflowFirestoreDataForTest({
        ...store.read(path), recordedAt: '2026-08-28T08:59:00.000Z',
      }));
      const before = store.entries();
      await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
        actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z'),
      })).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'uv-detector-correction-history-invalid'},
      });
      expect(store.entries()).toEqual(before);
    },
  );

  test.each([
    ['reason', 'A different unreviewed explanation'],
    ['supersedesCorrectionId', 'a-different-predecessor'],
    ['correctedByUid', 'another-reviewer'],
    ['correctedByName', 'Another reviewer'],
    ['recordedActionPerformedAt', '2026-08-11T08:00:00.000Z'],
    ['correctedAt', '2026-08-30T09:00:00.000Z'],
    ['assetInstanceId', 'a-different-furnace'],
    ['version', 2],
  ])('replay refuses changed retained correction %s without rewriting evidence', async (field, value) => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    await service.execute(command, context);
    const path = 'uv_detector_lifecycle_corrections/correction-1';
    store.seed(path, {...store.read(path), [field]: value});
    const before = store.entries();
    await expect(service.execute(command, context)).rejects.toMatchObject({
      details: {reasonCode: 'uv-detector-correction-replay-invalid'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('replay binds the original audit fingerprint and tolerates its Firestore timestamp', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    const receipt = await service.execute(command, context);
    const path = 'audit_logs/server_uv_detector_correction_correction-command-1';
    store.seed(path, workflowFirestoreDataForTest(store.read(path)));
    const beforeReplay = store.entries();
    await expect(service.execute(command, context)).resolves.toEqual(receipt);
    expect(store.entries()).toEqual(beforeReplay);
    const audit = store.read(path);
    const alteredAfter = JSON.parse(audit.afterJson);
    alteredAfter.currentInstallation.actionPerformedAt = '2026-08-09T08:00:00.000Z';
    store.seed(path, {...audit, afterJson: JSON.stringify(alteredAfter)});
    const beforeRefusal = store.entries();
    await expect(service.execute(command, context)).rejects.toMatchObject({
      details: {reasonCode: 'uv-detector-correction-replay-invalid'},
    });
    expect(store.entries()).toEqual(beforeRefusal);
  });

  test('an installation committed after correction review makes that new command stale', async () => {
    const {store, command} = await seededCommandState();
    await prepare(store, action({id: 'later-installation', createdAt: '2026-08-28T08:00:00.000Z'}), {
      sourceId: 'execution-after-review',
    });
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
      actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z'),
    })).rejects.toMatchObject({
      details: {reasonCode: 'uv-detector-lifecycle-current-version-conflict'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('accepted correction replay preserves a later legitimate installation', async () => {
    const {store, command} = await seededCommandState();
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    const receipt = await new MaintenanceWorkflowCommandService(store).execute(command, context);
    await prepare(store, action({id: 'later-installation', createdAt: '2026-08-30T08:00:00.000Z'}), {
      sourceId: 'execution-after-correction',
      completedAt: '2026-08-30T09:00:00.000Z',
      recordedAt: '2026-08-30T09:00:00.000Z',
    });
    const before = store.entries();
    const current = currentRow(store);
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
      ...context, serverNow: new Date('2026-08-31T09:00:00.000Z'),
    })).resolves.toEqual(receipt);
    expect(currentRow(store)).toEqual(current);
    expect(current.sourceId).toBe('execution-after-correction');
    expect(store.entries()).toEqual(before);
  });

  test('a restarted successor names the exact predecessor while older accepted replay remains valid', async () => {
    const {store, command} = await seededCommandState();
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    const firstReceipt = await new MaintenanceWorkflowCommandService(store).execute(command, context);
    const successor = {...command, commandId: 'correction-command-2', aggregateId: 'correction-2', payload: {
      ...command.payload, expectedCurrentActionPerformedAt: currentRow(store).actionPerformedAt, supersedesCorrectionId: 'correction-1', correctedActionPerformedAt: '2026-08-11T08:00:00.000Z',
    }};
    await new MaintenanceWorkflowCommandService(store).execute(successor, context);
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, context)).resolves.toEqual(firstReceipt);
    await expect(new MaintenanceWorkflowCommandService(store).execute({
      ...successor, commandId: 'correction-command-3', aggregateId: 'correction-3',
      payload: {...successor.payload, expectedCurrentActionPerformedAt: currentRow(store).actionPerformedAt, correctedActionPerformedAt: '2026-08-09T08:00:00.000Z'},
    }, context)).rejects.toMatchObject({details: {reasonCode: 'uv-detector-lifecycle-correction-stale'}});
    expect(currentRow(store).actionPerformedAt).toBe('2026-08-11T08:00:00.000Z');
    expect(store.entries()).toEqual(before);
  });

  test('refuses a future physical installation before any write', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const before = store.entries();

    await expect(service.execute({
      ...command,
      commandId: 'future-correction-command',
      aggregateId: 'future-correction',
      payload: {
        ...command.payload,
        correctedActionPerformedAt: '2026-09-01T08:00:00.000Z',
      },
    }, {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'uv-detector-correction-future-dated'},
    });
    expect(store.entries()).toEqual(before);
  });

  test('refuses a correction that installed clients cannot decode', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const before = store.entries();

    await expect(service.execute({
      ...command,
      commandId: 'after-closure-correction-command',
      aggregateId: 'after-closure-correction',
      payload: {
        ...command.payload,
        correctedActionPerformedAt: '2026-08-29T08:00:00.000Z',
      },
    }, {
      actor: commandActor,
      serverNow: new Date('2026-09-01T09:00:00.000Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'uv-detector-lifecycle-correction-after-completion',
      },
    });
    expect(store.entries()).toEqual(before);
  });

  test('refuses a command that would make no change without writing evidence', async () => {
    const {store, command, event} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {
      actor: commandActor,
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    };
    await service.execute(command, context);
    const before = store.entries();
    const current = currentRow(store);

    await expect(service.execute({
      ...command,
      commandId: 'correction-command-no-change',
      aggregateId: 'correction-2',
      payload: {
        ...command.payload,
        expectedCurrentEventId: current.currentEventId,
        expectedCurrentActionPerformedAt: current.actionPerformedAt,
        correctedActionPerformedAt: '2026-08-10T08:00:00.000Z',
        supersedesCorrectionId: 'correction-1',
      },
    }, context)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'uv-detector-lifecycle-correction-no-change'},
    });
    expect(event.eventId).toBeDefined();
    expect(store.entries()).toEqual(before);
  });
  test('a correction changing only current time invalidates another reviewed basis', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    await service.execute(command, context);
    const before = store.entries();
    await expect(service.execute({...command, commandId: 'stale-time', aggregateId: 'stale-time', payload: {
      ...command.payload, supersedesCorrectionId: 'correction-1',
      correctedActionPerformedAt: '2026-08-09T08:00:00.000Z',
    }}, context)).rejects.toMatchObject({details: {reasonCode: 'uv-detector-lifecycle-current-version-conflict'}});
    expect(store.entries()).toEqual(before);
  });

  test('correction rebuilds the actual current event and keeps both original installations immutable', async () => {
    const {store, command, event} = await seededCommandState();
    await prepare(store, action({id: 'earlier-install', createdAt: '2026-08-11T08:00:00.000Z'}), {
      sourceId: 'earlier-work-late-report',
    });
    const originals = eventRows(store);
    const receipt = await new MaintenanceWorkflowCommandService(store).execute(command, {
      actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z'),
    });
    expect(receipt.result.currentEventId).not.toBe(event.eventId);
    expect(currentRow(store).actionPerformedAt).toBe('2026-08-11T08:00:00.000Z');
    expect(eventRows(store)).toEqual(originals);
  });

  test('correcting old history leaves a later physical installation current', async () => {
    const {store, command} = await seededCommandState();
    await prepare(store, action({id: 'later-install', createdAt: '2026-08-20T08:00:00.000Z'}), {sourceId: 'later-work'});
    const reviewed = currentRow(store);
    const originals = eventRows(store);
    const result = await new MaintenanceWorkflowCommandService(store).execute({...command, payload: {
      ...command.payload, expectedCurrentEventId: reviewed.currentEventId,
      expectedCurrentActionPerformedAt: reviewed.actionPerformedAt,
    }}, {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')});
    expect(result.result.currentEventId).toBe(reviewed.eventId);
    expect(currentRow(store)).toEqual(reviewed);
    expect(eventRows(store)).toEqual(originals);
  });

  test('audit failure commits neither correction nor changed current projection nor receipt', async () => {
    const {store, command} = await seededCommandState();
    store.seed('audit_logs/server_uv_detector_correction_correction-command-1', {reserved: true});
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
      actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z'),
    })).rejects.toThrow('already-exists');
    expect(store.entries()).toEqual(before);
  });

  test.each(['operations', 'seniorInstrumentation'])('ordinary %s authority cannot correct an installation', async (role) => {
    const {store, command} = await seededCommandState();
    store.seed('users/operator', {isApproved: true, roles: [role], name: 'Operator'});
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
      actor: {uid: 'operator', name: 'Operator', roles: new Set([role])},
      serverNow: new Date('2026-08-29T09:00:00.000Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.entries()).toEqual(before);
  });

  test.each([
    ['aggregateVersion', 2], ['currentEventId', 'fabricated-event'], ['burnerPosition', 8],
    ['assetInstanceId', 'another-furnace'], ['currentActionPerformedAt', '2026-08-09T08:00:00.000Z'],
    ['expectedCurrentActionPerformedAt', '2026-08-09T08:00:00.000Z'],
  ])('replay refuses mutated acceptance result %s', async (field, value) => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    await service.execute(command, context);
    const path = `maintenance_workflow_command_receipts/${command.commandId}`;
    const receipt = store.read(path);
    store.seed(path, field === 'aggregateVersion' ? {...receipt, aggregateVersion: value} :
      {...receipt, result: {...receipt.result, [field]: value}});
    const before = store.entries();
    await expect(service.execute(command, context)).rejects.toMatchObject({details: {reasonCode: 'uv-detector-correction-replay-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test.each(['audit', 'correction', 'receipt'])('native sub-millisecond %s tampering cannot replay as the same accepted instant', async (target) => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    await service.execute(command, context);
    const path = target === 'audit' ? 'audit_logs/server_uv_detector_correction_correction-command-1' :
      target === 'correction' ? 'uv_detector_lifecycle_corrections/correction-1' :
      'maintenance_workflow_command_receipts/correction-command-1';
    const row = workflowFirestoreDataForTest(store.read(path));
    const field = target === 'audit' ? 'timestamp' : target === 'correction' ? 'correctedAt' : 'currentActionPerformedAt';
    const container = target === 'receipt' ? row.result : row;
    const stamp = container[field];
    container[field] = {_seconds: stamp.seconds, _nanoseconds: stamp.nanoseconds + 1};
    store.seed(path, row);
    const before = store.entries();
    await expect(service.execute(command, context)).rejects.toMatchObject({details: {reasonCode: 'uv-detector-correction-replay-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test('a correction chain with a missing predecessor is held rather than normalized', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    const context = {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')};
    await service.execute(command, context);
    const path = 'uv_detector_lifecycle_corrections/correction-1';
    store.seed(path, {...store.read(path), supersedesCorrectionId: 'missing-original'});
    const before = store.entries();
    await expect(service.execute({...command, commandId: 'successor', aggregateId: 'successor', payload: {
      ...command.payload, expectedCurrentActionPerformedAt: currentRow(store).actionPerformedAt,
      supersedesCorrectionId: 'correction-1', correctedActionPerformedAt: '2026-08-09T08:00:00.000Z',
    }}, context)).rejects.toMatchObject({details: {reasonCode: 'uv-detector-correction-history-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test('a backward recording clock refuses a correction without partial writes', async () => {
    const {store, command} = await seededCommandState();
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(command, {
      actor: commandActor, serverNow: new Date('2026-08-27T09:00:00.000Z'),
    })).rejects.toMatchObject({details: {reasonCode: 'uv-detector-lifecycle-correction-chronology-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test('a successor cannot be recorded before the correction it supersedes', async () => {
    const {store, command} = await seededCommandState();
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(command, {actor: commandActor, serverNow: new Date('2026-08-30T09:00:00.000Z')});
    const before = store.entries();
    await expect(service.execute({...command, commandId: 'clock-regression', aggregateId: 'clock-regression', payload: {
      ...command.payload, expectedCurrentActionPerformedAt: currentRow(store).actionPerformedAt,
      supersedesCorrectionId: 'correction-1', correctedActionPerformedAt: '2026-08-11T08:00:00.000Z',
    }}, {actor: commandActor, serverNow: new Date('2026-08-29T09:00:00.000Z')})).rejects.toMatchObject({
      details: {reasonCode: 'uv-detector-lifecycle-correction-chronology-invalid'},
    });
    expect(store.entries()).toEqual(before);
  });

});
