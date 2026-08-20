const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const at = (value) => new Date(value);

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

function createCampaign() {
  return {
    commandId: 'campaign-1',
    commandType: 'createInspectionCampaign',
    aggregateId: 'campaign-furnace-pt-august',
    expectedVersion: 0,
    payload: {
      definitionId: 'inspection-definition-furnace-pt',
      definitionVersion: 1,
      purpose: 'Verify pressure-transmitter settings without stopping every Furnace together.',
      assetTypeKey: 'furnace',
      assetClassId: null,
      targetAssetNumbers: [1, 2, 3],
      expectedPopulation: 26,
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
} = {}) {
  return {
    commandId,
    commandType: 'recordInspectionObservation',
    aggregateId: 'campaign-furnace-pt-august',
    expectedVersion,
    payload: {
      observationId,
      definitionVersion: 1,
      assetTypeKey: 'furnace',
      assetNumber,
      assetClassId: null,
      assetInstanceId: null,
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
      targetKey: 'furnace:1|furnace-pressure-transmitter|Gas train',
    });
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august')).toMatchObject({
      expectedPopulation: 26,
      observationCount: 1,
      distinctTargetKeys: ['furnace:1|furnace-pressure-transmitter|Gas train'],
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

  test('supports early campaign closure and links a finding only to the same asset', async () => {
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
      payload: {status: 'closed', reason: 'Close with documented partial coverage.'},
    }, {actor: supervisor, serverNow: at('2026-08-21T05:30:00Z')}))
      .resolves.toMatchObject({resultKey: 'inspection-campaign-closed'});
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august')).toMatchObject({
      status: 'closed',
      expectedPopulation: 26,
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
});
