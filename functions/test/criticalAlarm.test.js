const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const actor = (uid, roles) => ({uid, name: uid, roles: new Set(roles)});
const admin = actor('admin-alarm', ['admin']);
const si = actor('si-alarm', ['si']);
const ops = actor('ops-alarm', ['operations']);
const mechanical = actor('mech-alarm', ['seniorMechanical']);
const at = (value) => new Date(value);

function serviceFor(store) {
  for (const current of [admin, si, ops, mechanical]) {
    store.seed(`users/${current.uid}`, {
      isApproved: true,
      roles: [...current.roles],
      name: current.name,
    });
  }
  return new MaintenanceWorkflowCommandService(store);
}

function raiseCommand(id, type = 'fire') {
  return {
    commandId: `raise-${id}`,
    commandType: 'raiseCriticalAlarm',
    aggregateId: id,
    expectedVersion: 0,
    payload: {
      alarmTypeKey: type,
      location: 'Annealing shop north bay',
      assetTypeKey: null,
      assetNumber: null,
      initialDetails: 'Immediate critical-alarm details supplied by the raiser.',
    },
  };
}

describe('critical safety alarm workflow', () => {
  test('approved user raises an alarm with server-derived criticality and exact evidence', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = raiseCommand('alarm-fire-1');

    const first = await service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T10:00:00Z'),
    });
    const replay = await service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T10:01:00Z'),
    });

    expect(replay).toEqual(first);
    expect(store.read('critical_alarms/alarm-fire-1')).toMatchObject({
      schemaVersion: 1,
      alarmId: 'alarm-fire-1',
      alarmTypeKey: 'fire',
      alarmTypeName: 'Fire',
      criticalityKey: 'highest',
      criticalityRank: 1,
      status: 'raised',
      version: 1,
      details: 'Immediate critical-alarm details supplied by the raiser.',
      detailsPending: false,
      raisedByUid: ops.uid,
    });
    expect(store.read('maintenance_workflow_events/raise-alarm-fire-1'))
      .toMatchObject({
        eventType: 'criticalAlarm.raised',
        aggregateId: 'alarm-fire-1',
        payload: {
          alarmTypeKey: 'fire',
          criticalityKey: 'highest',
          status: 'raised',
        },
      });
    expect(store.read('critical_alarm_audits/raise-alarm-fire-1'))
      .toMatchObject({operation: 'raise', aggregateId: 'alarm-fire-1'});
  });

  test('distinct simultaneous incidents are preserved', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute(raiseCommand('alarm-fire-a'), {
      actor: ops,
      serverNow: at('2026-08-26T10:00:00Z'),
    });
    await service.execute(raiseCommand('alarm-fire-b'), {
      actor: mechanical,
      serverNow: at('2026-08-26T10:00:01Z'),
    });
    expect(store.read('critical_alarms/alarm-fire-a')).not.toBeNull();
    expect(store.read('critical_alarms/alarm-fire-b')).not.toBeNull();
  });

  test('stale alarm versions return the established deterministic conflict code', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute(raiseCommand('alarm-version-conflict'), {
      actor: ops,
      serverNow: at('2026-08-26T10:02:00Z'),
    });

    await expect(service.execute({
      commandId: 'stale-alarm-details',
      commandType: 'provideCriticalAlarmDetails',
      aggregateId: 'alarm-version-conflict',
      expectedVersion: 2,
      payload: {details: 'Details entered against a stale alarm version.'},
    }, {
      actor: ops,
      serverNow: at('2026-08-26T10:03:00Z'),
    })).rejects.toMatchObject({
      code: 'workflow-version-conflict',
      details: {reasonCode: 'critical-alarm-version-conflict'},
    });
    expect(store.read('critical_alarms/alarm-version-conflict')).toMatchObject({
      version: 1,
      detailsPending: false,
    });
  });

  test('optional incident details accept concise nonblank evidence', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = raiseCommand('alarm-short-details');
    command.payload.initialDetails = 'x';
    await expect(service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T10:05:00Z'),
    })).resolves.toMatchObject({aggregateVersion: 1});
    expect(store.read('critical_alarms/alarm-short-details')).toMatchObject({
      details: 'x',
      detailsPending: false,
    });
  });

  test('an installed legacy client may raise first and provide details next', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = raiseCommand('alarm-legacy-details');
    command.payload.initialDetails = null;
    const receipt = await service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T10:06:00Z'),
    });
    expect(receipt.result).toMatchObject({detailsPending: true});
    expect(store.read('critical_alarms/alarm-legacy-details')).toMatchObject({
      details: null,
      detailsPending: true,
      detailsProvidedAt: null,
    });
  });

  test('support confirmation requires details and resolution requires support', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute(raiseCommand('alarm-n2', 'nitrogenFailure'), {
      actor: ops,
      serverNow: at('2026-08-26T11:00:00Z'),
    });
    const legacyPending = store.read('critical_alarms/alarm-n2');
    store.seed('critical_alarms/alarm-n2', {
      ...legacyPending,
      details: null,
      detailsPending: true,
      detailsProvidedByUid: null,
      detailsProvidedByName: null,
      detailsProvidedAt: null,
    });

    await expect(service.execute({
      commandId: 'confirm-n2-without-details',
      commandType: 'confirmCriticalAlarmSupport',
      aggregateId: 'alarm-n2',
      expectedVersion: 1,
      payload: {
        basis: 'supportDispatched',
        responderNote: 'Utility support dispatched',
        details: null,
      },
    }, {actor: si, serverNow: at('2026-08-26T11:01:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    await service.execute({
      commandId: 'confirm-n2',
      commandType: 'confirmCriticalAlarmSupport',
      aggregateId: 'alarm-n2',
      expectedVersion: 1,
      payload: {
        basis: 'supportDispatched',
        responderNote: 'Utility support dispatched from control room',
        details: 'Nitrogen header pressure fell below the safe operating band.',
      },
    }, {actor: si, serverNow: at('2026-08-26T11:02:00Z')});

    await service.execute({
      commandId: 'resolve-n2',
      commandType: 'resolveCriticalAlarm',
      aggregateId: 'alarm-n2',
      expectedVersion: 2,
      payload: {
        resolutionSummary: 'Header pressure restored and operations verified stable.',
      },
    }, {actor: admin, serverNow: at('2026-08-26T11:10:00Z')});

    expect(store.read('critical_alarms/alarm-n2')).toMatchObject({
      status: 'resolved',
      version: 3,
      detailsPending: false,
      supportBasis: 'supportDispatched',
      resolvedByUid: admin.uid,
    });
  });

  test('non-governance actor cannot confirm support and unrelated actor cannot withdraw', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute({
      ...raiseCommand('alarm-blast', 'blast'),
      payload: {
        ...raiseCommand('alarm-blast', 'blast').payload,
        initialDetails: 'Blast sound reported near the south transfer bay.',
      },
    }, {actor: ops, serverNow: at('2026-08-26T12:00:00Z')});

    await expect(service.execute({
      commandId: 'confirm-blast-denied',
      commandType: 'confirmCriticalAlarmSupport',
      aggregateId: 'alarm-blast',
      expectedVersion: 1,
      payload: {
        basis: 'supportAlreadyPresent',
        responderNote: 'Attempted by unauthorized actor',
        details: null,
      },
    }, {actor: mechanical, serverNow: at('2026-08-26T12:01:00Z')}))
      .rejects.toMatchObject({code: 'permission-denied'});

    await expect(service.execute({
      commandId: 'withdraw-blast-denied',
      commandType: 'withdrawCriticalAlarmInError',
      aggregateId: 'alarm-blast',
      expectedVersion: 1,
      payload: {reason: 'Unrelated user attempted withdrawal'},
    }, {actor: mechanical, serverNow: at('2026-08-26T12:02:00Z')}))
      .rejects.toMatchObject({code: 'permission-denied'});

    await service.execute({
      commandId: 'withdraw-blast-owner',
      commandType: 'withdrawCriticalAlarmInError',
      aggregateId: 'alarm-blast',
      expectedVersion: 1,
      payload: {reason: 'Confirmed dropped material, not a blast event'},
    }, {actor: ops, serverNow: at('2026-08-26T12:03:00Z')});
    expect(store.read('critical_alarms/alarm-blast')).toMatchObject({
      status: 'withdrawnInError',
      withdrawnByUid: ops.uid,
    });
  });

  test('only Admin manages hazard-specific contacts and numbers are canonicalized', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = {
      commandId: 'contact-fire-create',
      commandType: 'upsertCriticalAlarmContact',
      aggregateId: 'contact-fire-room',
      expectedVersion: 0,
      payload: {
        contact: {
          schemaVersion: 1,
          label: 'Fire control room',
          contactKind: 'landline',
          dialValue: '+91 (11) 2345-6789',
          alarmTypeKeys: ['fire'],
          priority: 1,
          notes: 'Use only for a confirmed or suspected fire.',
        },
        reason: 'Initial governed fire contact',
      },
    };
    await expect(service.execute(command, {
      actor: si,
      serverNow: at('2026-08-26T13:00:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});

    await service.execute(command, {
      actor: admin,
      serverNow: at('2026-08-26T13:01:00Z'),
    });
    expect(store.read('critical_alarm_contacts/contact-fire-room'))
      .toMatchObject({
        status: 'active',
        contactKind: 'landline',
        dialValue: '+911123456789',
        alarmTypeKeys: ['fire'],
      });
  });

  test('retire and restore contact receipts replay with their exact dynamic status', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute({
      commandId: 'contact-lifecycle-create',
      commandType: 'upsertCriticalAlarmContact',
      aggregateId: 'contact-lifecycle',
      expectedVersion: 0,
      payload: {
        contact: {
          schemaVersion: 1,
          label: 'Emergency desk',
          contactKind: 'plantExtension',
          dialValue: '4100',
          alarmTypeKeys: ['fire', 'blast'],
          priority: 1,
          notes: null,
        },
        reason: 'Create contact for lifecycle replay test',
      },
    }, {actor: admin, serverNow: at('2026-08-26T13:10:00Z')});
    const retire = {
      commandId: 'contact-lifecycle-retire',
      commandType: 'setCriticalAlarmContactStatus',
      aggregateId: 'contact-lifecycle',
      expectedVersion: 1,
      payload: {status: 'retired', reason: 'Desk temporarily unavailable'},
    };
    const restore = {
      commandId: 'contact-lifecycle-restore',
      commandType: 'setCriticalAlarmContactStatus',
      aggregateId: 'contact-lifecycle',
      expectedVersion: 2,
      payload: {status: 'active', reason: 'Desk availability verified'},
    };
    await service.execute(retire, {
      actor: admin,
      serverNow: at('2026-08-26T13:11:00Z'),
    });
    const first = await service.execute(restore, {
      actor: admin,
      serverNow: at('2026-08-26T13:12:00Z'),
    });
    const replay = await service.execute(restore, {
      actor: admin,
      serverNow: at('2026-08-26T13:13:00Z'),
    });
    expect(replay).toEqual(first);
    expect(first.resultKey).toBe('critical-alarm-contact-active');
    expect(store.read('critical_alarm_contacts/contact-lifecycle'))
      .toMatchObject({status: 'active', version: 3});
  });

  test('Admin governs custom alarm reasons while raised alarms retain their snapshot', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const create = {
      commandId: 'definition-hydrogen-create',
      commandType: 'upsertCriticalAlarmDefinition',
      aggregateId: 'hydrogenPressureCollapse',
      expectedVersion: 0,
      payload: {
        definition: {
          schemaVersion: 1,
          name: 'Hydrogen pressure collapse',
          criticalityKey: 'highest',
          criticalityRank: 1,
        },
        reason: 'Add the approved hydrogen emergency reason',
      },
    };
    await expect(service.execute(create, {
      actor: si,
      serverNow: at('2026-08-26T13:20:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
    const first = await service.execute(create, {
      actor: admin,
      serverNow: at('2026-08-26T13:21:00Z'),
    });
    expect(await service.execute(create, {
      actor: admin,
      serverNow: at('2026-08-26T13:22:00Z'),
    })).toEqual(first);

    await service.execute(raiseCommand(
      'alarm-custom-hydrogen-old',
      'hydrogenPressureCollapse',
    ), {actor: ops, serverNow: at('2026-08-26T13:23:00Z')});
    await service.execute({
      ...create,
      commandId: 'definition-hydrogen-update',
      expectedVersion: 1,
      payload: {
        ...create.payload,
        definition: {
          ...create.payload.definition,
          name: 'Hydrogen supply collapse',
        },
        reason: 'Use the approved plant terminology',
      },
    }, {actor: admin, serverNow: at('2026-08-26T13:24:00Z')});
    await service.execute(raiseCommand(
      'alarm-custom-hydrogen-new',
      'hydrogenPressureCollapse',
    ), {actor: ops, serverNow: at('2026-08-26T13:25:00Z')});

    expect(store.read('critical_alarms/alarm-custom-hydrogen-old'))
      .toMatchObject({alarmTypeName: 'Hydrogen pressure collapse'});
    expect(store.read('critical_alarms/alarm-custom-hydrogen-new'))
      .toMatchObject({alarmTypeName: 'Hydrogen supply collapse'});
  });

  test('retiring a bootstrap alarm reason creates a blocking governed override', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = {
      commandId: 'definition-fire-retire',
      commandType: 'setCriticalAlarmDefinitionStatus',
      aggregateId: 'fire',
      expectedVersion: 0,
      payload: {
        status: 'retired',
        reason: 'Fire reason temporarily withdrawn by governance',
      },
    };
    const first = await service.execute(command, {
      actor: admin,
      serverNow: at('2026-08-26T13:30:00Z'),
    });
    expect(await service.execute(command, {
      actor: admin,
      serverNow: at('2026-08-26T13:31:00Z'),
    })).toEqual(first);
    expect(store.read('critical_alarm_definitions/fire')).toMatchObject({
      status: 'retired',
      name: 'Fire',
      version: 1,
    });
    await expect(service.execute(raiseCommand('alarm-retired-fire'), {
      actor: ops,
      serverNow: at('2026-08-26T13:32:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'critical-alarm-type-retired'},
    });
  });

  test('later commands fail closed on a partial or severity-tampered alarm record', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute(raiseCommand('alarm-tampered'), {
      actor: ops,
      serverNow: at('2026-08-26T14:00:00Z'),
    });
    const alarm = store.read('critical_alarms/alarm-tampered');
    store.seed('critical_alarms/alarm-tampered', {
      ...alarm,
      criticalityRank: 2,
    });
    await expect(service.execute({
      commandId: 'details-tampered',
      commandType: 'provideCriticalAlarmDetails',
      aggregateId: 'alarm-tampered',
      expectedVersion: 1,
      payload: {details: 'Visible smoke beside the furnace transfer path.'},
    }, {actor: ops, serverNow: at('2026-08-26T14:01:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'critical-alarm-record-malformed'},
      });
    expect(store.read('critical_alarm_audits/details-tampered')).toBeNull();
  });

  test('contact updates fail closed on incomplete persisted contact evidence', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await service.execute({
      commandId: 'contact-create-for-corruption',
      commandType: 'upsertCriticalAlarmContact',
      aggregateId: 'contact-gas-room',
      expectedVersion: 0,
      payload: {
        contact: {
          schemaVersion: 1,
          label: 'Gas control room',
          contactKind: 'plantExtension',
          dialValue: '4210',
          alarmTypeKeys: ['majorGasLeakage'],
          priority: 1,
          notes: null,
        },
        reason: 'Initial governed gas contact',
      },
    }, {actor: admin, serverNow: at('2026-08-26T15:00:00Z')});
    const current = store.read('critical_alarm_contacts/contact-gas-room');
    const {updatedByName: _removed, ...incomplete} = current;
    store.seed('critical_alarm_contacts/contact-gas-room', incomplete);
    await expect(service.execute({
      commandId: 'contact-retire-corrupt',
      commandType: 'setCriticalAlarmContactStatus',
      aggregateId: 'contact-gas-room',
      expectedVersion: 1,
      payload: {status: 'retired', reason: 'Test retirement'},
    }, {actor: admin, serverNow: at('2026-08-26T15:01:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'critical-alarm-contact-malformed'},
      });
  });

  test('idempotent replay rejects altered immutable alarm evidence', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    const command = raiseCommand('alarm-replay-evidence');
    await service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T16:00:00Z'),
    });
    const audit = store.read(
      'critical_alarm_audits/raise-alarm-replay-evidence',
    );
    store.seed('critical_alarm_audits/raise-alarm-replay-evidence', {
      ...audit,
      operation: 'resolve',
    });
    await expect(service.execute(command, {
      actor: ops,
      serverNow: at('2026-08-26T16:01:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'critical-alarm-replay-evidence-invalid'},
    });
  });
});
