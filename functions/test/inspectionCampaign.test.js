const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const at = (value) => new Date(value);

const persistedTimestamp = (value) => {
  const millis = Date.parse(value);
  return {
    _seconds: Math.floor(millis / 1000),
    _nanoseconds: (millis % 1000) * 1000000,
  };
};

function seedActor(store, uid, roles) {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
}

function seedFurnaceHierarchy(store) {
  store.seed('asset_classes/class-furnace', {
    schemaVersion: 1,
    assetClassId: 'class-furnace',
    status: 'active',
    legacyAssetTypeKey: 'furnace',
  });
  store.seed('asset_hierarchy_nodes/furnace-pressure-transmitter', {
    schemaVersion: 1,
    nodeId: 'furnace-pressure-transmitter',
    assetClassId: 'class-furnace',
    nodeType: 'component',
    name: 'Pressure transmitter',
    version: 2,
    status: 'active',
  });
  for (const assetNumber of [1, 2, 3, 4]) {
    store.seed(`asset_instances/furnace-${assetNumber}`, {
      schemaVersion: 1,
      assetInstanceId: `furnace-${assetNumber}`,
      assetClassId: 'class-furnace',
      assetNumber,
      name: `Furnace ${assetNumber}`,
      version: 1,
      status: 'active',
    });
  }
}

function definition(overrides = {}) {
  return {
    schemaVersion: 1,
    code: 'FURNACE_PT_SETTING',
    title: 'Furnace pressure-transmitter setting',
    description: 'Audit the governed pressure setting on selected Furnaces.',
    assetTypeKeys: ['furnace'],
    assetClassIds: [],
    componentNodeIds: ['furnace-pressure-transmitter'],
    valueType: 'number',
    unit: 'bar',
    choiceValues: [],
    minimumValue: 2,
    maximumValue: 4,
    preconditions: ['Furnace isolated', 'Instrument impulse line available'],
    requiresChargeNo: false,
    ...overrides,
  };
}

function upsertDefinition({expectedVersion = 0, commandId = 'definition-1', overrides = {}} = {}) {
  return {
    commandId,
    commandType: 'upsertInspectionDefinition',
    aggregateId: 'inspection-definition-furnace-pt',
    expectedVersion,
    payload: {
      definition: definition(overrides),
      reason: 'Govern the repeatable Furnace pressure-setting audit.',
    },
  };
}

function createCampaign({
  commandId = 'campaign-1',
  campaignId = 'campaign-furnace-pt-august',
  targetAssetNumbers = [1, 2, 3],
  baselineCampaignId = null,
} = {}) {
  return {
    commandId,
    commandType: 'createInspectionCampaign',
    aggregateId: campaignId,
    expectedVersion: 0,
    payload: {
      definitionId: 'inspection-definition-furnace-pt',
      definitionVersion: 1,
      purpose: 'Verify pressure-transmitter settings without stopping every Furnace together.',
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      targetAssetNumbers,
      expectedPopulation: targetAssetNumbers.length,
      physicalPositionLabels: ['Gas train'],
      baselineCampaignId,
      observerRoleKeys: ['seniorInstrumentation'],
      reason: 'Open the August cross-Furnace instrument audit.',
    },
  };
}

function observation({
  commandId = 'observation-1',
  observationId = 'observation-1',
  expectedVersion = 1,
  assetNumber = 1,
  numericValue = 1.8,
  observedAt = '2026-08-21T05:00:00.000Z',
  supersedesObservationId = null,
  campaignId = 'campaign-furnace-pt-august',
} = {}) {
  return {
    commandId,
    commandType: 'recordInspectionObservation',
    aggregateId: campaignId,
    expectedVersion,
    payload: {
      observationId,
      definitionVersion: 1,
      assetTypeKey: 'furnace',
      assetNumber,
      assetClassId: 'class-furnace',
      assetInstanceId: `furnace-${assetNumber}`,
      componentNodeId: 'furnace-pressure-transmitter',
      componentNodeVersion: 2,
      componentName: 'Pressure transmitter',
      hierarchyPath: ['Combustion system', 'Pressure control', 'Pressure transmitter'],
      physicalPosition: 'Gas train',
      observedAt,
      value: {
        valueType: 'number',
        numericValue,
        booleanValue: null,
        textValue: null,
        choiceValue: null,
      },
      unit: 'bar',
      operatingConditions: {furnaceState: 'isolated', source: 'field gauge'},
      chargeNo: null,
      note: 'Reading witnessed at the governed test point.',
      evidenceUrls: [],
      supersedesObservationId,
    },
  };
}

describe('cross-asset inspection campaigns', () => {
  test('freezes the definition and records partial, out-of-range coverage', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);

    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign(), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    await service.execute(upsertDefinition({
      expectedVersion: 1,
      commandId: 'definition-2',
      overrides: {maximumValue: 5},
    }), {
      actor: admin,
      serverNow: at('2026-08-21T04:20:00Z'),
    });

    const receipt = await service.execute(observation(), {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    });
    expect(receipt).toMatchObject({
      resultKey: 'inspection-observation-recorded',
      aggregateVersion: 2,
      result: {
        outOfRange: true,
        issueRecommended: true,
        observationCount: 1,
        distinctTargetCount: 1,
      },
    });
    expect(store.read('inspection_observations/observation-1')).toMatchObject({
      definitionVersion: 1,
      maximumValue: 4,
      outOfRange: true,
      targetKey: 'class-furnace:furnace-1|furnace-pressure-transmitter|Gas train',
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august')).toMatchObject({
      expectedPopulation: 3,
      observationCount: 1,
      distinctTargetKeys: ['class-furnace:furnace-1|furnace-pressure-transmitter|Gas train'],
      targetDispositionCounts: {
        pending: 2,
        observed: 1,
        deferred: 0,
        unavailable: 0,
        excludedWithReason: 0,
        requiresReaudit: 0,
      },
    });
  });

  test('corrections are immutable, target-bound and preserve the latest timestamp', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {actor: admin, serverNow: at('2026-08-21T04:00:00Z')});
    await service.execute(createCampaign(), {actor: admin, serverNow: at('2026-08-21T04:10:00Z')});
    await service.execute(observation(), {actor: observer, serverNow: at('2026-08-21T05:10:00Z')});

    await expect(service.execute(observation({
      commandId: 'bad-correction',
      observationId: 'bad-correction',
      expectedVersion: 2,
      assetNumber: 2,
      supersedesObservationId: 'observation-1',
    }), {actor: observer, serverNow: at('2026-08-21T05:20:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    const corrected = await service.execute(observation({
      commandId: 'correction-1',
      observationId: 'correction-1',
      expectedVersion: 2,
      numericValue: 2.8,
      observedAt: '2026-08-21T04:50:00.000Z',
      supersedesObservationId: 'observation-1',
    }), {actor: observer, serverNow: at('2026-08-21T05:20:00Z')});
    expect(corrected).toMatchObject({
      resultKey: 'inspection-observation-correction-recorded',
      aggregateVersion: 3,
      result: {outOfRange: false, distinctTargetCount: 1},
    });
    expect(store.read('inspection_observations/observation-1').numericValue).toBe(1.8);
    expect(store.read('inspection_observations/correction-1')).toMatchObject({
      numericValue: 2.8,
      supersedesObservationId: 'observation-1',
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august')).toMatchObject({
      observationCount: 2,
      latestObservationAt: '2026-08-21T05:00:00.000Z',
    });
  });

  test('blocks silent partial closure and links a finding only to the same asset', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {actor: admin, serverNow: at('2026-08-21T04:00:00Z')});
    await service.execute(createCampaign(), {actor: supervisor, serverNow: at('2026-08-21T04:10:00Z')});
    await service.execute(observation(), {actor: observer, serverNow: at('2026-08-21T05:10:00Z')});
    store.seed('maintenance_records/ticket-other', {
      firestoreId: 'ticket-other', assetType: 'furnace', assetNumber: 2,
      isDeleted: false,
    });
    store.seed('maintenance_records/ticket-1', {
      firestoreId: 'ticket-1', assetType: 'furnace', assetNumber: 1,
      isDeleted: false,
    });

    await expect(service.execute({
      commandId: 'link-other',
      commandType: 'linkInspectionObservationIssue',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 2,
      payload: {observationId: 'observation-1', ticketId: 'ticket-other', reason: 'Wrong asset.'},
    }, {actor: supervisor, serverNow: at('2026-08-21T05:20:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    await expect(service.execute({
      commandId: 'link-1',
      commandType: 'linkInspectionObservationIssue',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 2,
      payload: {
        observationId: 'observation-1',
        ticketId: 'ticket-1',
        reason: 'Track the out-of-range setting as maintenance work.',
      },
    }, {actor: supervisor, serverNow: at('2026-08-21T05:20:00Z')}))
      .resolves.toMatchObject({resultKey: 'inspection-observation-issue-linked'});

    await expect(service.execute({
      commandId: 'close-1',
      commandType: 'setInspectionCampaignStatus',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 2,
      payload: {status: 'closed', reason: 'Attempt to close with missing targets.'},
    }, {actor: supervisor, serverNow: at('2026-08-21T05:30:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'inspection-campaign-population-incomplete'},
      });

    await service.execute({
      commandId: 'defer-2',
      commandType: 'setInspectionTargetDisposition',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 2,
      payload: {
        targetKey: 'class-furnace:furnace-2|furnace-pressure-transmitter|Gas train',
        disposition: 'deferred',
        reason: 'Furnace 2 remains in a heating cycle during this campaign window.',
      },
    }, {actor: supervisor, serverNow: at('2026-08-21T05:31:00Z')});
    await service.execute({
      commandId: 'unavailable-3',
      commandType: 'setInspectionTargetDisposition',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 3,
      payload: {
        targetKey: 'class-furnace:furnace-3|furnace-pressure-transmitter|Gas train',
        disposition: 'unavailable',
        reason: 'Furnace 3 was not safely accessible during the campaign window.',
      },
    }, {actor: supervisor, serverNow: at('2026-08-21T05:32:00Z')});
    await expect(service.execute({
      commandId: 'close-2',
      commandType: 'setInspectionCampaignStatus',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 4,
      payload: {status: 'closed', reason: 'Close with every target and finding accounted.'},
    }, {actor: supervisor, serverNow: at('2026-08-21T05:33:00Z')}))
      .resolves.toMatchObject({resultKey: 'inspection-campaign-closed'});
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august')).toMatchObject({
      status: 'closed',
      expectedPopulation: 3,
      observationCount: 1,
    });
  });

  test('rejects a component whose hierarchy class is outside the asset scope', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    store.seed('asset_classes/class-base', {
      schemaVersion: 1,
      assetClassId: 'class-base',
      status: 'active',
      legacyAssetTypeKey: 'base',
    });
    store.seed('asset_hierarchy_nodes/base-water-jacket', {
      schemaVersion: 1,
      nodeId: 'base-water-jacket',
      assetClassId: 'class-base',
      nodeType: 'component',
      name: 'Water jacket',
      version: 1,
      status: 'active',
    });
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await expect(service.execute(upsertDefinition({
      overrides: {componentNodeIds: ['base-water-jacket']},
    }), {actor: admin, serverNow: at('2026-08-21T04:00:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('adds later campaign targets without hiding the population change', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });

    const result = await service.execute({
      commandId: 'add-target-4',
      commandType: 'addInspectionCampaignTargets',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 1,
      payload: {
        assetNumbers: [4],
        physicalPositionLabels: ['North test point'],
        reason: 'Furnace 4 entered the governed inspection population.',
      },
    }, {actor: admin, serverNow: at('2026-08-21T04:20:00Z')});

    expect(result).toMatchObject({
      resultKey: 'inspection-campaign-targets-added',
      aggregateVersion: 2,
      result: {addedTargetCount: 1, expectedPopulation: 2},
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august'))
      .toMatchObject({
        targetAssetNumbers: [1, 4],
        physicalPositionLabels: ['Gas train', 'North test point'],
        expectedPopulation: 2,
        targetDispositionCounts: {
          pending: 2,
          observed: 0,
          deferred: 0,
          unavailable: 0,
          excludedWithReason: 0,
          requiresReaudit: 0,
        },
      });
    expect(store.read('inspection_campaign_audits/add-target-4')).toMatchObject({
      operation: 'add-targets',
      campaignId: 'campaign-furnace-pt-august',
    });
  });

  test('requires a later same-target observation to verify a finding', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    await service.execute(observation(), {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    });
    const campaign = store.read(
      'inspection_campaigns/campaign-furnace-pt-august',
    );
    store.seed('inspection_campaigns/campaign-furnace-pt-august', {
      ...campaign,
      latestObservationAt: persistedTimestamp(campaign.latestObservationAt),
    });
    const finding = store.read(
      'inspection_findings/inspection-finding-observation-1',
    );
    store.seed('inspection_findings/inspection-finding-observation-1', {
      ...finding,
      firstObservedAt: persistedTimestamp(finding.firstObservedAt),
      latestObservedAt: persistedTimestamp(finding.latestObservedAt),
    });
    await service.execute(observation({
      commandId: 'correction-1',
      observationId: 'correction-1',
      expectedVersion: 2,
      numericValue: 2.8,
      observedAt: '2026-08-21T05:30:00.000Z',
      supersedesObservationId: 'observation-1',
    }), {actor: observer, serverNow: at('2026-08-21T05:40:00Z')});

    await expect(service.execute({
      commandId: 'verify-1',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 3,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'correction-1',
        expectedFindingVersion: 2,
        outcome: 'resolved',
        reason: 'The corrected setting was rechecked at the same governed test point.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:45:00Z')}))
      .resolves.toMatchObject({
        resultKey: 'inspection-finding-verifiedResolved',
        result: {status: 'verifiedResolved'},
      });
    expect(store.read('inspection_findings/inspection-finding-observation-1'))
      .toMatchObject({
        version: 3,
        status: 'verifiedResolved',
        currentObservationId: 'correction-1',
        verificationCount: 1,
        lastVerifiedObservationId: 'correction-1',
      });

    await expect(service.execute({
      commandId: 'verify-stale-finding-version',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 3,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'correction-1',
        expectedFindingVersion: 2,
        outcome: 'improved',
        reason: 'A stale finding version cannot append a second verification decision.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:46:00Z')}))
      .rejects.toMatchObject({code: 'aborted'});

    await expect(service.execute({
      commandId: 'verify-same-observation-again',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 3,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'correction-1',
        expectedFindingVersion: 3,
        outcome: 'improved',
        reason: 'Even a current client cannot reverse the decision without a later observation.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:47:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    expect(store.read('inspection_findings/inspection-finding-observation-1'))
      .toMatchObject({
        version: 3,
        status: 'verifiedResolved',
        verificationCount: 1,
        lastVerificationId: 'verify-1',
        lastVerifiedObservationId: 'correction-1',
      });
    expect(store.read('inspection_verifications/verify-stale-finding-version'))
      .toBeNull();
    expect(store.read('inspection_verifications/verify-same-observation-again'))
      .toBeNull();
  });

  test('fails closed on malformed prior verification state', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    await service.execute(observation(), {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    });
    store.seed('inspection_findings/inspection-finding-observation-1', {
      ...store.read('inspection_findings/inspection-finding-observation-1'),
      verificationCount: '1',
      lastVerificationId: null,
    });

    await expect(service.execute({
      commandId: 'verify-malformed-prior-state',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 2,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'observation-1',
        expectedFindingVersion: 1,
        outcome: 'deteriorated',
        reason: 'Malformed persisted counters must not be normalized by verification.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:44:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});

    expect(store.read('inspection_verifications/verify-malformed-prior-state'))
      .toBeNull();
  });

  test('rejects verification against an observation superseded by a later fault', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    await service.execute(observation(), {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    });
    await service.execute(observation({
      commandId: 'in-range-2',
      observationId: 'in-range-2',
      expectedVersion: 2,
      numericValue: 2.8,
      observedAt: '2026-08-21T05:30:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-21T05:35:00Z')});
    await service.execute(observation({
      commandId: 'fault-3',
      observationId: 'fault-3',
      expectedVersion: 3,
      numericValue: 1.7,
      observedAt: '2026-08-21T05:40:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-21T05:45:00Z')});

    await expect(service.execute({
      commandId: 'stale-verification-attempt',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 4,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'in-range-2',
        expectedFindingVersion: 3,
        outcome: 'resolved',
        reason: 'Attempt to reuse an older in-range reading after recurrence.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:50:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('inspection_findings/inspection-finding-observation-1'))
      .toMatchObject({
        status: 'open',
        currentObservationId: 'fault-3',
        latestObservedAt: '2026-08-21T05:40:00.000Z',
        verificationCount: 0,
      });
    expect(store.read('inspection_verifications/stale-verification-attempt'))
      .toBeNull();
  });

  test('compares a re-audit against the latest baseline observation', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign({
      commandId: 'baseline-create',
      campaignId: 'baseline-campaign',
      targetAssetNumbers: [1],
    }), {actor: admin, serverNow: at('2026-08-21T04:10:00Z')});
    await service.execute(observation({
      commandId: 'baseline-observation',
      observationId: 'baseline-observation',
      campaignId: 'baseline-campaign',
      numericValue: 2.8,
    }), {actor: observer, serverNow: at('2026-08-21T05:10:00Z')});
    await service.execute({
      commandId: 'baseline-close',
      commandType: 'setInspectionCampaignStatus',
      aggregateId: 'baseline-campaign',
      expectedVersion: 2,
      payload: {status: 'closed', reason: 'Close the fully observed baseline.'},
    }, {actor: admin, serverNow: at('2026-08-21T05:20:00Z')});

    await service.execute(createCampaign({
      commandId: 'reaudit-create',
      campaignId: 'reaudit-campaign',
      targetAssetNumbers: [1],
      baselineCampaignId: 'baseline-campaign',
    }), {actor: admin, serverNow: at('2026-08-22T04:10:00Z')});
    const result = await service.execute(observation({
      commandId: 'reaudit-observation',
      observationId: 'reaudit-observation',
      campaignId: 'reaudit-campaign',
      numericValue: 1.8,
      observedAt: '2026-08-22T05:00:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-22T05:10:00Z')});
    expect(result.result).toMatchObject({comparisonOutcome: 'recurred'});
    expect(store.read('inspection_observations/reaudit-observation')).toMatchObject({
      baselineCampaignId: 'baseline-campaign',
      baselineObservationId: 'baseline-observation',
      comparisonOutcome: 'recurred',
    });
  });
});
