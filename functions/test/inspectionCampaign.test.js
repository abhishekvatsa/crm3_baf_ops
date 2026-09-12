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

function seedInstalledInnerCoverHierarchy(store) {
  store.seed('asset_classes/class-base', {
    schemaVersion: 1,
    assetClassId: 'class-base',
    status: 'active',
    legacyAssetTypeKey: 'base',
  });
  store.seed('asset_classes/class-inner-cover', {
    schemaVersion: 1,
    assetClassId: 'class-inner-cover',
    status: 'active',
    legacyAssetTypeKey: 'innerCover',
  });
  store.seed('asset_hierarchy_nodes/inner-cover-shell', {
    schemaVersion: 1,
    nodeId: 'inner-cover-shell',
    assetClassId: 'class-inner-cover',
    nodeType: 'component',
    name: 'Inner Cover shell',
    version: 3,
    status: 'active',
  });
  store.seed('asset_instances/base-205', {
    schemaVersion: 1,
    assetInstanceId: 'base-205',
    assetClassId: 'class-base',
    assetNumber: 205,
    name: 'Base 205',
    version: 2,
    status: 'active',
  });
  store.seed('inner_cover_profiles/inner-cover-n4', {
    schemaVersion: 1,
    innerCoverId: 'inner-cover-n4',
    assetClassId: 'class-inner-cover',
    serialNumber: 'N4',
    lifecycleState: 'installed',
    currentBaseAssetInstanceId: 'base-205',
    currentBaseAssetNumber: 205,
    currentLinkageId: 'link-n4-base-205',
    version: 7,
  });
  store.seed('base_inner_cover_assignments/base-205', {
    schemaVersion: 1,
    baseAssetInstanceId: 'base-205',
    baseAssetClassId: 'class-base',
    baseAssetNumber: 205,
    baseAssetName: 'Base 205',
    innerCoverId: 'inner-cover-n4',
    innerCoverSerialNumber: 'N4',
    linkageId: 'link-n4-base-205',
    linkedAt: '2026-08-21T04:00:00.000Z',
    version: 4,
  });
  store.seed('inner_cover_linkages/link-n4-base-205', {
    schemaVersion: 1,
    linkageId: 'link-n4-base-205',
    baseAssetInstanceId: 'base-205',
    baseAssetClassId: 'class-base',
    baseAssetNumber: 205,
    baseAssetName: 'Base 205',
    innerCoverId: 'inner-cover-n4',
    innerCoverSerialNumber: 'N4',
    installedAt: '2026-08-21T04:00:00.000Z',
    active: true,
    version: 1,
  });
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

function deleteUnusedCampaign({
  commandId = 'delete-unused-campaign',
  campaignId = 'campaign-furnace-pt-august',
  expectedVersion = 1,
} = {}) {
  return {
    commandId,
    commandType: 'deleteUnusedInspectionCampaign',
    aggregateId: campaignId,
    expectedVersion,
    payload: {
      confirmation: `DELETE ${campaignId}`,
      reason: 'Remove an unused trial inspection audit.',
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
  test('admin permanently deletes only a never-used campaign with replay evidence', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign(), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    const command = deleteUnusedCampaign();

    const receipt = await service.execute(command, {
      actor: admin,
      serverNow: at('2026-08-21T04:20:00Z'),
    });

    expect(receipt).toMatchObject({
      resultKey: 'inspection-campaign-unused-deleted',
      aggregateVersion: 1,
      result: {
        campaignId: 'campaign-furnace-pt-august',
        auditId: 'delete-unused-campaign',
      },
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august'))
      .toBeNull();
    const deletionAudit = store.read(
      'inspection_campaign_audits/delete-unused-campaign',
    );
    expect(deletionAudit).toMatchObject({
      entityId: 'campaign-furnace-pt-august',
      operation: 'delete-unused',
      performedByUid: 'admin-1',
    });
    store.seed('inspection_campaign_audits/delete-unused-campaign', {
      ...deletionAudit,
      performedAt: persistedTimestamp('2026-08-21T04:20:00.000Z'),
    });

    await expect(service.execute(command, {
      actor: admin,
      serverNow: at('2026-08-21T04:30:00Z'),
    })).resolves.toEqual(receipt);
  });

  test('non-admin campaign managers cannot delete an unused campaign', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const supervisor = seedActor(
      store,
      'supervisor-1',
      ['shiftSupervisor'],
    );
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition(), {
      actor: admin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await service.execute(createCampaign(), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });

    await expect(service.execute(deleteUnusedCampaign(), {
      actor: supervisor,
      serverNow: at('2026-08-21T04:20:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august'))
      .not.toBeNull();
  });

  test('a reading or target disposition permanently protects the campaign', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(
      store,
      'instrument-1',
      ['seniorInstrumentation'],
    );
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

    await expect(service.execute(deleteUnusedCampaign({expectedVersion: 2}), {
      actor: admin,
      serverNow: at('2026-08-21T05:20:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-campaign-not-unused'},
    });

    const storeWithDisposition = new MemoryWorkflowStore();
    seedFurnaceHierarchy(storeWithDisposition);
    const secondAdmin = seedActor(storeWithDisposition, 'admin-1', ['admin']);
    const secondService = new MaintenanceWorkflowCommandService(
      storeWithDisposition,
    );
    await secondService.execute(upsertDefinition(), {
      actor: secondAdmin,
      serverNow: at('2026-08-21T04:00:00Z'),
    });
    await secondService.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: secondAdmin,
      serverNow: at('2026-08-21T04:10:00Z'),
    });
    const targetKey = storeWithDisposition.read(
      'inspection_campaigns/campaign-furnace-pt-august',
    ).targetPopulation[0].targetKey;
    await secondService.execute({
      commandId: 'defer-target-before-delete',
      commandType: 'setInspectionTargetDisposition',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 1,
      payload: {
        targetKey,
        disposition: 'deferred',
        reason: 'Target will be checked later.',
      },
    }, {actor: secondAdmin, serverNow: at('2026-08-21T04:20:00Z')});

    await expect(secondService.execute(
      deleteUnusedCampaign({expectedVersion: 2}),
      {actor: secondAdmin, serverNow: at('2026-08-21T04:30:00Z')},
    )).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-campaign-not-unused'},
    });
  });

  test('linked downstream evidence protects an otherwise empty campaign', async () => {
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
    store.seed('inspection_issue_links/legacy-link', {
      campaignId: 'campaign-furnace-pt-august',
    });

    await expect(service.execute(deleteUnusedCampaign(), {
      actor: admin,
      serverNow: at('2026-08-21T04:20:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-campaign-not-unused'},
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august'))
      .not.toBeNull();
  });

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

  test('rejects evidence after the governed asset identity version changes', async () => {
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
    store.seed('asset_instances/furnace-1', {
      ...store.read('asset_instances/furnace-1'),
      version: 2,
    });

    await expect(service.execute(observation(), {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-asset-context-changed'},
    });
    expect(store.read('inspection_observations/observation-1')).toBeNull();
  });

  test('freezes installed Inner Cover identity by Base and rejects changed governed context', async () => {
    const store = new MemoryWorkflowStore();
    seedInstalledInnerCoverHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const mechanical = seedActor(store, 'mechanical-1', ['seniorMechanical']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition({
      commandId: 'definition-inner-cover',
      overrides: {
        code: 'INNER_COVER_SHELL_CONDITION',
        title: 'Installed Inner Cover shell condition',
        description: 'Audit installed Inner Covers at their governed Base positions.',
        assetTypeKeys: ['innerCover'],
        assetClassIds: ['class-inner-cover'],
        componentNodeIds: ['inner-cover-shell'],
        valueType: 'boolean',
        unit: null,
        minimumValue: null,
        maximumValue: null,
        preconditions: [],
      },
    }), {actor: admin, serverNow: at('2026-08-21T04:05:00Z')});
    const createResult = await service.execute({
      commandId: 'campaign-inner-cover',
      commandType: 'createInspectionCampaign',
      aggregateId: 'campaign-inner-cover-shell',
      expectedVersion: 0,
      payload: {
        definitionId: 'inspection-definition-furnace-pt',
        definitionVersion: 1,
        purpose: 'Audit each currently installed Inner Cover without losing its Base context.',
        assetTypeKey: 'innerCover',
        assetClassId: 'class-inner-cover',
        populationMode: 'installedInnerCoversByBase',
        hostAssetClassId: 'class-base',
        targetAssetNumbers: [205],
        expectedPopulation: 1,
        physicalPositionLabels: ['Shell'],
        baselineCampaignId: null,
        observerRoleKeys: ['seniorMechanical'],
        reason: 'Open the governed installed Inner Cover audit.',
      },
    }, {actor: admin, serverNow: at('2026-08-21T04:10:00Z')});
    expect(createResult).toMatchObject({
      resultKey: 'inspection-campaign-created',
      aggregateVersion: 1,
    });
    const target = store.read('inspection_campaigns/campaign-inner-cover-shell')
      .targetPopulation[0];
    expect(target).toMatchObject({
      assetTypeKey: 'innerCover',
      assetNumber: 205,
      assetInstanceId: 'inner-cover-n4',
      hostAssetNumber: 205,
      subjectSerialNumber: 'N4',
      linkageId: 'link-n4-base-205',
      assetInstanceVersion: 7,
      hostAssetInstanceVersion: 2,
      linkageVersion: 1,
      linkedAt: '2026-08-21T04:00:00.000Z',
    });
    expect(target.targetKey).toBe(
      'class-inner-cover:inner-cover-n4|inner-cover-shell|Shell|link:link-n4-base-205',
    );

    const record = (commandId, expectedVersion) => ({
      commandId,
      commandType: 'recordInspectionObservation',
      aggregateId: 'campaign-inner-cover-shell',
      expectedVersion,
      payload: {
        observationId: commandId,
        targetKey: target.targetKey,
        definitionVersion: 1,
        assetTypeKey: 'innerCover',
        assetNumber: 205,
        assetClassId: 'class-inner-cover',
        assetInstanceId: 'inner-cover-n4',
        componentNodeId: 'inner-cover-shell',
        componentNodeVersion: 3,
        componentName: 'Inner Cover shell',
        hierarchyPath: ['Inner Cover', 'Shell'],
        physicalPosition: 'Shell',
        observedAt: '2026-08-21T05:00:00.000Z',
        value: {
          valueType: 'boolean',
          numericValue: null,
          booleanValue: true,
          textValue: null,
          choiceValue: null,
        },
        unit: null,
        operatingConditions: {},
        chargeNo: null,
        note: 'Observed against the serial shown beside Base 205.',
        evidenceUrls: [],
        supersedesObservationId: null,
      },
    });
    const legacyCompatibleRecord = record('inner-cover-observation-1', 1);
    delete legacyCompatibleRecord.payload.targetKey;
    legacyCompatibleRecord.payload.assetClassId = null;
    legacyCompatibleRecord.payload.assetInstanceId = null;
    await expect(service.execute(legacyCompatibleRecord, {
      actor: mechanical,
      serverNow: at('2026-08-21T05:05:00Z'),
    })).resolves.toMatchObject({
      resultKey: 'inspection-observation-recorded',
      aggregateVersion: 2,
    });
    expect(store.read('inspection_observations/inner-cover-observation-1'))
      .toMatchObject({
        hostAssetNumber: 205,
        subjectSerialNumber: 'N4',
        linkageId: 'link-n4-base-205',
      });

    const profile = store.read('inner_cover_profiles/inner-cover-n4');
    store.seed('inner_cover_profiles/inner-cover-n4', {
      ...profile,
      version: 8,
    });
    await expect(service.execute(record('inner-cover-observation-profile-changed', 2), {
      actor: mechanical,
      serverNow: at('2026-08-21T05:08:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-inner-cover-context-changed'},
    });
    store.seed('inner_cover_profiles/inner-cover-n4', profile);

    const linkage = store.read('inner_cover_linkages/link-n4-base-205');
    store.seed('inner_cover_linkages/link-n4-base-205', {
      ...linkage,
      version: 2,
    });
    await expect(service.execute(record('inner-cover-observation-link-version-changed', 2), {
      actor: mechanical,
      serverNow: at('2026-08-21T05:09:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-inner-cover-context-changed'},
    });
    store.seed('inner_cover_linkages/link-n4-base-205', linkage);

    store.seed('inner_cover_linkages/link-n4-base-205', {
      ...linkage,
      active: false,
    });
    await expect(service.execute(record('inner-cover-observation-2', 2), {
      actor: mechanical,
      serverNow: at('2026-08-21T05:10:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-inner-cover-context-changed'},
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

    await expect(service.execute(observation({
      commandId: 'stale-correction',
      observationId: 'stale-correction',
      expectedVersion: 3,
      numericValue: 3.1,
      supersedesObservationId: 'observation-1',
    }), {actor: observer, serverNow: at('2026-08-21T05:30:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'inspection-correction-not-current'},
      });
    expect(store.read('inspection_observations/stale-correction')).toBeNull();
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

  test('honours an exact definition class and registry document identity', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    store.seed('asset_classes/class-furnace-alternate', {
      schemaVersion: 1,
      assetClassId: 'class-furnace-alternate',
      status: 'active',
      legacyAssetTypeKey: 'furnace',
    });
    store.seed('asset_instances/furnace-alternate-1', {
      schemaVersion: 1,
      assetInstanceId: 'furnace-alternate-1',
      assetClassId: 'class-furnace-alternate',
      assetNumber: 1,
      name: 'Alternate Furnace 1',
      version: 1,
      status: 'active',
    });
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition({
      overrides: {assetClassIds: ['class-furnace']},
    }), {actor: admin, serverNow: at('2026-08-21T04:00:00Z')});
    const wrongClassCampaign = createCampaign({targetAssetNumbers: [1]});
    wrongClassCampaign.payload.assetClassId = 'class-furnace-alternate';
    await expect(service.execute(wrongClassCampaign, {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    })).rejects.toMatchObject({code: 'failed-precondition'});

    store.seed('asset_instances/furnace-1', {
      ...store.read('asset_instances/furnace-1'),
      assetInstanceId: 'different-document-identity',
    });
    await expect(service.execute(createCampaign({
      commandId: 'campaign-malformed-identity',
      campaignId: 'campaign-malformed-identity',
      targetAssetNumbers: [1],
    }), {
      actor: admin,
      serverNow: at('2026-08-21T04:11:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-campaign-asset-identity-malformed'},
    });
  });

  test('allows an exact class-only definition without weakening its scope', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertDefinition({
      overrides: {assetTypeKeys: [], assetClassIds: ['class-furnace']},
    }), {actor: admin, serverNow: at('2026-08-21T04:00:00Z')});

    await expect(service.execute(createCampaign({targetAssetNumbers: [1]}), {
      actor: admin,
      serverNow: at('2026-08-21T04:10:00Z'),
    })).resolves.toMatchObject({
      resultKey: 'inspection-campaign-created',
      aggregateVersion: 1,
    });
  });

  test('binds an explicit target key to its governed component and position', async () => {
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
    const request = observation();
    request.payload.targetKey = store.read(
      'inspection_campaigns/campaign-furnace-pt-august',
    ).targetPopulation[0].targetKey;
    request.payload.physicalPosition = 'Different test point';

    await expect(service.execute(request, {
      actor: observer,
      serverNow: at('2026-08-21T05:10:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inspection-target-not-in-population'},
    });
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

  test('closed corrective campaign reopens with history and reaches same-finding verification', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const service = new MaintenanceWorkflowCommandService(store);
    const id = 'campaign-furnace-pt-august';
    const path = `inspection_campaigns/${id}`;
    const run = (command, actor, time) => service.execute(command, {actor, serverNow: at(time)});
    await run(upsertDefinition(), admin, '2026-08-21T04:00:00Z');
    await run(createCampaign({targetAssetNumbers: [1]}), supervisor, '2026-08-21T04:10:00Z');
    await run(observation(), observer, '2026-08-21T05:10:00Z');
    const originalReading = structuredClone(store.read('inspection_observations/observation-1'));
    store.seed('maintenance_records/repair-1', {
      firestoreId: 'repair-1', assetType: 'furnace', assetNumber: 1,
      isDeleted: false, isResolved: false,
    });
    await run({
      commandId: 'link-repair', commandType: 'linkInspectionObservationIssue',
      aggregateId: id, expectedVersion: 2,
      payload: {observationId: 'observation-1', ticketId: 'repair-1', reason: 'Complete corrective maintenance before verification.'},
    }, supervisor, '2026-08-21T05:15:00Z');
    const close = {
      commandId: 'close-before-repair', commandType: 'setInspectionCampaignStatus',
      aggregateId: id, expectedVersion: 2,
      payload: {status: 'closed', reason: 'Population accounted, corrective work remains linked.'},
    };
    await run(close, supervisor, '2026-08-21T05:20:00Z');
    const closureAudit = structuredClone(store.read('inspection_campaign_audits/close-before-repair'));
    const definitionBefore = structuredClone(store.read(path).definition);
    const populationBefore = structuredClone(store.read(path).targetPopulation);
    await expect(run(observation({
      commandId: 'blocked-closed-reading', observationId: 'blocked-closed-reading',
      expectedVersion: 3, observedAt: '2026-08-22T05:00:00.000Z', numericValue: 2.8,
    }), observer, '2026-08-22T05:10:00Z')).rejects.toMatchObject({code: 'failed-precondition'});
    const reopen = {
      commandId: 'reopen-for-verification', commandType: 'setInspectionCampaignStatus',
      aggregateId: id, expectedVersion: 3,
      payload: {status: 'open', reason: 'Inspect the corrective repair for effectiveness.'},
    };
    await expect(run(reopen, observer, '2026-08-22T05:20:00Z')).rejects.toMatchObject({code: 'permission-denied'});
    await expect(run({...reopen, commandId: 'stale-reopen', expectedVersion: 2}, supervisor, '2026-08-22T05:20:00Z'))
      .rejects.toMatchObject({code: 'aborted'});
    await expect(run({...reopen, commandId: 'blank-reopen', payload: {status: 'open', reason: ''}}, supervisor, '2026-08-22T05:20:00Z'))
      .rejects.toMatchObject({code: 'invalid-argument'});
    const reopened = await run(reopen, supervisor, '2026-08-22T05:20:00Z');
    expect(reopened.aggregateVersion).toBe(4);
    expect(store.read(path)).toMatchObject({
      status: 'open', closedAt: null, lastClosedAt: '2026-08-21T05:20:00.000Z',
      reopenedAt: '2026-08-22T05:20:00.000Z', reopenedByUid: supervisor.uid,
      reopeningReason: reopen.payload.reason,
    });
    expect(store.read(path).definition).toEqual(definitionBefore);
    expect(store.read(path).targetPopulation).toEqual(populationBefore);
    expect(store.read('inspection_campaign_audits/reopen-for-verification')).toMatchObject({operation: 'reopen'});
    const replay = await run(reopen, supervisor, '2026-08-22T05:21:00Z');
    expect(replay.aggregateVersion).toBe(4);
    expect(store.read(path).version).toBe(4);
    await run(observation({
      commandId: 'post-repair-reading', observationId: 'post-repair-reading',
      expectedVersion: 4, numericValue: 2.8, observedAt: '2026-08-22T05:30:00.000Z',
    }), observer, '2026-08-22T05:40:00Z');
    const verify = {
      commandId: 'verify-repaired-finding', commandType: 'verifyInspectionFinding',
      aggregateId: id, expectedVersion: 5,
      payload: {
        findingId: 'inspection-finding-observation-1', observationId: 'post-repair-reading',
        expectedFindingVersion: store.read('inspection_findings/inspection-finding-observation-1').version,
        outcome: 'resolved', reason: 'The same test point is now within the governed range.',
      },
    };
    await expect(run({...verify, commandId: 'verify-before-repair-complete'}, observer, '2026-08-22T05:45:00Z'))
      .rejects.toThrow('must be resolved');
    // Represents the independent corrective-maintenance completion boundary.
    store.seed('maintenance_records/repair-1', {
      ...store.read('maintenance_records/repair-1'), isResolved: true, status: 'resolved',
    });
    await expect(run(verify, observer, '2026-08-22T05:50:00Z'))
      .resolves.toMatchObject({resultKey: 'inspection-finding-verifiedResolved'});
    expect(store.read('inspection_findings/inspection-finding-observation-1'))
      .toMatchObject({status: 'verifiedResolved', lastVerifiedObservationId: 'post-repair-reading', linkedTicketId: 'repair-1'});
    await run({...close, commandId: 'close-after-verification', expectedVersion: 5}, supervisor, '2026-08-22T06:00:00Z');
    expect(store.read(path)).toMatchObject({status: 'closed', closedAt: '2026-08-22T06:00:00.000Z', version: 6});
    expect(store.read('inspection_campaign_audits/close-before-repair')).toEqual(closureAudit);
    expect(store.read('inspection_observations/observation-1')).toEqual(originalReading);
  });

  test.each([false, true])('reopening cannot move an existing re-audit baseline (legacy=%s)', async (legacy) => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    const run = (command, actor, time) => service.execute(command, {actor, serverNow: at(time)});
    await run(upsertDefinition(), admin, '2026-08-21T04:00:00Z');
    await run(createCampaign({campaignId: 'baseline', targetAssetNumbers: [1]}), admin, '2026-08-21T04:10:00Z');
    await run(observation({campaignId: 'baseline', numericValue: 2.8}), observer, '2026-08-21T05:10:00Z');
    await run({
      commandId: 'baseline-close-freeze', commandType: 'setInspectionCampaignStatus',
      aggregateId: 'baseline', expectedVersion: 2,
      payload: {status: 'closed', reason: 'Preserve the completed baseline.'},
    }, admin, '2026-08-21T05:20:00Z');
    await run(createCampaign({commandId: 'reaudit-freeze', campaignId: 'reaudit', targetAssetNumbers: [1], baselineCampaignId: 'baseline'}), admin, '2026-08-22T04:10:00Z');
    if (legacy) {
      const legacyCampaign = {...store.read('inspection_campaigns/reaudit')};
      delete legacyCampaign.baselineRecordedThrough;
      store.seed('inspection_campaigns/reaudit', legacyCampaign);
    }
    await run({
      commandId: 'reopen-baseline', commandType: 'setInspectionCampaignStatus',
      aggregateId: 'baseline', expectedVersion: 3,
      payload: {status: 'open', reason: 'Append a corrected reading without rewriting history.'},
    }, admin, '2026-08-22T04:20:00Z');
    await run(observation({
      commandId: 'late-correction', observationId: 'late-correction', campaignId: 'baseline',
      expectedVersion: 4, numericValue: 1.0, observedAt: '2026-08-21T05:15:00.000Z',
      supersedesObservationId: 'observation-1',
    }), observer, '2026-08-22T04:30:00Z');
    await run(observation({
      commandId: 'reaudit-current', observationId: 'reaudit-current', campaignId: 'reaudit',
      numericValue: 1.8, observedAt: '2026-08-22T05:00:00.000Z',
    }), observer, '2026-08-22T05:10:00Z');
    expect(store.read('inspection_observations/reaudit-current')).toMatchObject({
      baselineObservationId: 'observation-1', comparisonOutcome: 'recurred',
    });
  });

  test('reopening refuses contradictory future closure evidence without changing the closed campaign', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);
    const run = (command) => service.execute(command, {actor: admin, serverNow: at('2026-08-22T04:10:00Z')});
    await run(upsertDefinition());
    await run(createCampaign({campaignId: 'closed-future', targetAssetNumbers: [1]}));
    store.seed('inspection_campaigns/closed-future', {
      ...store.read('inspection_campaigns/closed-future'), status: 'closed',
      closedAt: '2026-08-23T04:10:00.000Z',
    });
    const before = store.entries();
    await expect(run({
      commandId: 'reopen-future-closure', commandType: 'setInspectionCampaignStatus',
      aggregateId: 'closed-future', expectedVersion: 1,
      payload: {status: 'open', reason: 'Reopen for a subsequent verification.'},
    })).rejects.toMatchObject({
      code: 'failed-precondition', details: {reasonCode: 'inspection-campaign-closure-evidence-missing'},
    });
    expect(store.entries()).toEqual(before);
  });

  test.each([undefined, null, 'not-an-instant', '2026-08-23T04:10:00.000Z'])(
    'new re-audits reject absent, malformed or future baseline closure (%s)', async (closedAt) => {
      const store = new MemoryWorkflowStore();
      seedFurnaceHierarchy(store);
      const admin = seedActor(store, 'admin-1', ['admin']);
      const service = new MaintenanceWorkflowCommandService(store);
      const run = (command, time) => service.execute(command, {actor: admin, serverNow: at(time)});
      await run(upsertDefinition(), '2026-08-21T04:00:00Z');
      await run(createCampaign({campaignId: 'baseline', targetAssetNumbers: [1]}), '2026-08-21T04:10:00Z');
      const baseline = {...store.read('inspection_campaigns/baseline'), status: 'closed'};
      if (closedAt !== undefined) baseline.closedAt = closedAt;
      store.seed('inspection_campaigns/baseline', baseline);
      await expect(run(createCampaign({
        commandId: 'invalid-baseline-create', campaignId: 'reaudit',
        targetAssetNumbers: [1], baselineCampaignId: 'baseline',
      }), '2026-08-22T04:10:00Z')).rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'inspection-baseline-closure-evidence-invalid'},
      });
      expect(store.read('inspection_campaigns/reaudit')).toBeNull();
      expect(store.read('inspection_campaign_audits/invalid-baseline-create')).toBeNull();
    },
  );

  test.each([
    {baselineRecordedThrough: null},
    {baselineRecordedThrough: 'not-an-instant'},
    {baselineRecordedThrough: '2026-08-22T04:11:00.000Z'},
    {createdAt: '2026-08-23T04:10:00.000Z'},
  ])('re-audit does not silently replace invalid persisted cutoff evidence (%j)', async (patch) => {
    const store = new MemoryWorkflowStore();
    seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const observer = seedActor(store, 'instrument-1', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    const run = (command, actor, time) => service.execute(command, {actor, serverNow: at(time)});
    await run(upsertDefinition(), admin, '2026-08-21T04:00:00Z');
    await run(createCampaign({campaignId: 'baseline', targetAssetNumbers: [1]}), admin, '2026-08-21T04:10:00Z');
    store.seed('inspection_campaigns/baseline', {
      ...store.read('inspection_campaigns/baseline'), status: 'closed', closedAt: '2026-08-21T05:20:00.000Z',
    });
    await run(createCampaign({
      commandId: 'reaudit-create-cutoff', campaignId: 'reaudit',
      targetAssetNumbers: [1], baselineCampaignId: 'baseline',
    }), admin, '2026-08-22T04:10:00Z');
    store.seed('inspection_campaigns/reaudit', {...store.read('inspection_campaigns/reaudit'), ...patch});
    await expect(run(observation({
      commandId: 'reaudit-invalid-cutoff', observationId: 'reaudit-invalid-cutoff', campaignId: 'reaudit',
      numericValue: 2.8, observedAt: '2026-08-22T05:00:00.000Z',
    }), observer, '2026-08-22T05:10:00Z')).rejects.toMatchObject({
      code: 'failed-precondition', details: {reasonCode: 'inspection-baseline-cutoff-missing'},
    });
    expect(store.read('inspection_observations/reaudit-invalid-cutoff')).toBeNull();
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

  test('retains a late historical reading without replacing newer fault evidence', async () => {
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
      commandId: 'newer-fault',
      observationId: 'newer-fault',
      expectedVersion: 2,
      numericValue: 1.6,
      observedAt: '2026-08-21T05:40:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-21T05:45:00Z')});

    const late = await service.execute(observation({
      commandId: 'late-healthy',
      observationId: 'late-healthy',
      expectedVersion: 3,
      numericValue: 2.8,
      observedAt: '2026-08-21T05:30:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-21T05:50:00Z')});

    expect(late.result).toMatchObject({
      observationId: 'late-healthy',
      outOfRange: false,
      currentEvidenceAdvanced: false,
      issueRecommended: false,
      findingId: null,
    });
    expect(store.read('inspection_observations/late-healthy')).toMatchObject({
      observedAt: '2026-08-21T05:30:00.000Z',
      outOfRange: false,
    });
    const campaign = store.read('inspection_campaigns/campaign-furnace-pt-august');
    expect(campaign.targetPopulation[0]).toMatchObject({
      lastObservationId: 'newer-fault',
      lastObservedAt: '2026-08-21T05:40:00.000Z',
    });
    expect(store.read('inspection_findings/inspection-finding-observation-1'))
      .toMatchObject({
        version: 2,
        status: 'open',
        currentObservationId: 'newer-fault',
        latestObservedAt: '2026-08-21T05:40:00.000Z',
      });

    await expect(service.execute({
      commandId: 'verify-late-healthy',
      commandType: 'verifyInspectionFinding',
      aggregateId: 'campaign-furnace-pt-august',
      expectedVersion: 4,
      payload: {
        findingId: 'inspection-finding-observation-1',
        observationId: 'late-healthy',
        expectedFindingVersion: 2,
        outcome: 'resolved',
        reason: 'A historical healthy reading must not clear the newer fault.',
      },
    }, {actor: observer, serverNow: at('2026-08-21T05:55:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('orders native Firestore baseline timestamps chronologically', async () => {
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
      commandId: 'baseline-create-native',
      campaignId: 'baseline-native',
      targetAssetNumbers: [1],
    }), {actor: admin, serverNow: at('2026-08-21T04:10:00Z')});
    await service.execute(observation({
      commandId: 'baseline-older',
      observationId: 'baseline-older',
      campaignId: 'baseline-native',
      numericValue: 2.8,
      observedAt: '2026-08-21T05:00:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-21T05:10:00Z')});
    await service.execute({
      commandId: 'baseline-close-native',
      commandType: 'setInspectionCampaignStatus',
      aggregateId: 'baseline-native',
      expectedVersion: 2,
      payload: {status: 'closed', reason: 'Close the complete baseline.'},
    }, {actor: admin, serverNow: at('2026-08-21T05:15:00Z')});

    const older = store.read('inspection_observations/baseline-older');
    store.seed('inspection_observations/baseline-older', {
      ...older,
      observedAt: persistedTimestamp('2026-08-21T05:00:00.000Z'),
    });
    store.seed('inspection_observations/baseline-newer', {
      ...older,
      observationId: 'baseline-newer',
      observedAt: persistedTimestamp('2026-08-21T05:30:00.000Z'),
      numericValue: 1.5,
      value: {...older.value, numericValue: 1.5},
    });

    await service.execute(createCampaign({
      commandId: 'reaudit-native-create',
      campaignId: 'reaudit-native',
      targetAssetNumbers: [1],
      baselineCampaignId: 'baseline-native',
    }), {actor: admin, serverNow: at('2026-08-22T04:10:00Z')});
    const result = await service.execute(observation({
      commandId: 'reaudit-native-observation',
      observationId: 'reaudit-native-observation',
      campaignId: 'reaudit-native',
      numericValue: 2.8,
      observedAt: '2026-08-22T05:00:00.000Z',
    }), {actor: observer, serverNow: at('2026-08-22T05:10:00Z')});

    expect(result.result).toMatchObject({comparisonOutcome: 'resolved'});
    expect(store.read('inspection_observations/reaudit-native-observation'))
      .toMatchObject({
        baselineObservationId: 'baseline-newer',
        comparisonOutcome: 'resolved',
      });
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

describe('Corrective completion semantics for new inspection verification', () => {
  test.each(['resolved', 'closedWithoutResolution', 'deleted', 'reopened',
    'mismatched-identity', 'missing-status', 'missing-deletion-flag', 'unresolved-flag'])(
    'real maintenance lifecycle %s supplies the correct verification prerequisite', async (mode) => {
      const store = new MemoryWorkflowStore();
      seedFurnaceHierarchy(store);
      store.seed('asset_classes/class-furnace', {
        ...store.read('asset_classes/class-furnace'), code: 'FURNACE', name: 'Furnace',
      });
      store.seed('asset_instances/furnace-1', {
        ...store.read('asset_instances/furnace-1'), assetClassCode: 'FURNACE',
        assetClassName: 'Furnace', ownershipStatus: 'unassigned',
        ownerDiscipline: null, accountableRoleKeys: [],
      });
      const admin = seedActor(store, 'admin', ['admin']);
      const service = new MaintenanceWorkflowCommandService(store);
      const run = (command, time = '2026-08-21T07:00:00.000Z') =>
        service.execute(command, {actor: admin, serverNow: at(time)});
      await run(upsertDefinition());
      await run(createCampaign({targetAssetNumbers: [1]}));
      await run(observation());
      await run({
        commandId: 'create-real-repair', commandType: 'createMaintenanceTicket',
        aggregateId: 'real-repair', expectedVersion: 0,
        payload: {ticket: {
          schemaVersion: 1, version: 1, assetType: 'furnace', assetNumber: 1,
          component: 'Pressure transmitter', subsystem: null, tag: null,
          hierarchyPath: [], assetHierarchyRefJson: JSON.stringify({
            schemaVersion: 3, scope: 'physicalAsset', assetClassId: 'class-furnace',
            assetInstanceId: 'furnace-1', assetInstanceVersion: 1,
          }), maintenanceType: 'breakdown', classification: null,
          description: 'Correct pressure outside the inspection limits.', routedTo: 'instrumentation',
          otherDepartment: null, isCritical: false, startDate: '2026-08-21T05:10:00.000Z',
          chargeNoAtEvent: null, qualityIntentSchemaVersion: 1,
          qualityImpactAssessment: 'notSuspected', qualityWarningReason: null,
        }},
      });
      await run({
        commandId: 'link-real-repair', commandType: 'linkInspectionObservationIssue',
        aggregateId: 'campaign-furnace-pt-august', expectedVersion: 2,
        payload: {observationId: 'observation-1', ticketId: 'real-repair', reason: 'Correct the finding.'},
      });
      await run({
        commandId: 'complete-real-repair',
        commandType: mode === 'closedWithoutResolution' ? 'closeMaintenanceTicketWithoutResolution' : 'resolveMaintenanceTicket',
        aggregateId: 'real-repair', expectedVersion: 1,
        payload: mode === 'closedWithoutResolution' ? {
          disposition: 'stillRelevant', reason: 'Administrative closure retains the unresolved condition.',
        } : {
          endDate: '2026-08-21T05:30:00.000Z', remarks: 'Pressure corrected and checked.',
          teamsInvolved: ['instrumentation'], actionsJson: '[]',
        },
      });
      if (mode === 'deleted') {
        // Logical deletion is a separate boundary, represented explicitly here.
        store.seed('maintenance_records/real-repair', {
          ...store.read('maintenance_records/real-repair'), isDeleted: true,
        });
      }
      if (mode === 'reopened') await run({
        commandId: 'reopen-real-repair', commandType: 'reopenMaintenanceTicket',
        aggregateId: 'real-repair', expectedVersion: 2,
        payload: {remarks: 'The corrective issue needs further work.'},
      });
      const malformedPatch = {
        'mismatched-identity': {firestoreId: 'different-ticket'},
        'missing-status': {status: null},
        'missing-deletion-flag': {isDeleted: null},
        'unresolved-flag': {isResolved: false},
      }[mode];
      if (malformedPatch != null) store.seed('maintenance_records/real-repair', {
        ...store.read('maintenance_records/real-repair'), ...malformedPatch,
      });
      await run(observation({
        commandId: 'followup', observationId: 'followup', expectedVersion: 2,
        numericValue: 2.8, observedAt: '2026-08-21T06:00:00.000Z',
      }));
      const command = {
        commandId: 'verify-real-repair', commandType: 'verifyInspectionFinding',
        aggregateId: 'campaign-furnace-pt-august', expectedVersion: 3,
        payload: {findingId: 'inspection-finding-observation-1', observationId: 'followup',
          expectedFindingVersion: store.read('inspection_findings/inspection-finding-observation-1').version,
          outcome: 'resolved', reason: 'Follow-up reading is within range.'},
      };
      if (mode === 'resolved') {
        const receipt = await run(command);
        expect(receipt.result.status).toBe('verifiedResolved');
        // A later real reopen does not rewrite or invalidate the accepted verification.
        await run({commandId: 'later-reopen', commandType: 'reopenMaintenanceTicket',
          aggregateId: 'real-repair', expectedVersion: 2, payload: {remarks: 'A later recurrence.'}});
        const before = store.entries();
        await expect(run(command)).resolves.toEqual(receipt);
        expect(store.entries()).toEqual(before);
      } else {
        const before = store.entries();
        await expect(run(command)).rejects.toMatchObject({
          code: 'failed-precondition', details: {reasonCode: 'inspection-corrective-maintenance-not-completed'},
        });
        expect(store.entries()).toEqual(before);
      }
    },
  );

  test('a historical accepted command is replayed without rejudging linked work', async () => {
    const fixture = require('./fixtures/inspectionLegacyVerification.json');
    const store = new MemoryWorkflowStore();
    for (const [path, data] of fixture.documents) store.seed(path, data);
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(fixture.command, {
      actor: {uid: 'si', name: 'SI'}, serverNow: at('2026-09-12T12:00:00.000Z'),
    })).resolves.toEqual(fixture.receipt);
    expect(store.entries()).toEqual(before);
  });
});
