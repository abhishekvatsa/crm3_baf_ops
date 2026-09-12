const {
  MaintenanceWorkflowCommandService,
} = require('../../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../../lib/maintenanceWorkflow/memoryStore');

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


module.exports = {MaintenanceWorkflowCommandService, MemoryWorkflowStore, at, persistedTimestamp, seedActor, seedFurnaceHierarchy, seedInstalledInnerCoverHierarchy, definition, upsertDefinition, createCampaign, deleteUnusedCampaign, observation};
