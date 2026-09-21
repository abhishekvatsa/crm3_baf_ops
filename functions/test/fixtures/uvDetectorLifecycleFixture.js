'use strict';
const {MemoryWorkflowStore} = require('../../lib/maintenanceWorkflow/memoryStore');
const {prepareUvDetectorLifecycleWritePlan, applyUvDetectorLifecycleWritePlan} = require('../../lib/maintenanceWorkflow/uvDetectorLifecycle');

const IDS = {
  assetClass: 'class-furnace',
  asset: 'furnace-7',
  node: 'node-uv-detector',
};

const actor = {
  uid: 'supervisor-1',
  name: 'Supervisor One',
  roles: new Set(['shiftSupervisor']),
};

function reference() {
  return {
    schemaVersion: 4,
    scope: 'componentDefinitionOnAsset',
    assetClassId: IDS.assetClass,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: IDS.node,
    nodeVersion: 3,
    nodeName: 'UV flame scanner and peep sight',
    assetInstanceId: IDS.asset,
    assetInstanceVersion: 4,
    assetNumber: 7,
    assetInstanceName: 'Furnace 7',
    componentInstanceId: null,
    componentInstanceVersion: null,
    componentTag: null,
    hierarchyPath: [
      'Furnace',
      'Burner and flame supervision',
      'UV flame scanner and peep sight',
    ],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Instrumentation & Automation',
    accountableRoleKeys: ['seniorInstrumentation'],
    innerCoverAssociation: null,
  };
}

function action(overrides = {}) {
  return {
    schemaVersion: 1,
    id: 'action-uv-1',
    asset: 'Furnace 7',
    component: 'UV flame scanner and peep sight',
    hierarchyPath: reference().hierarchyPath,
    assetHierarchyRef: reference(),
    system: 'Furnace',
    subsystem: 'Burner and flame supervision',
    subComponent: null,
    tag: null,
    instance: null,
    actionType: 'replacement',
    replacement: 'newPart',
    issue: 'UV detector was missing.',
    resolution: 'UV detector installed.',
    remarks: null,
    templateFieldKey: null,
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-08-28T08:00:00.000Z',
    severity: 'high',
    performedBy: 'I&A Technician One',
    updatedAt: null,
    version: 1,
    metadataJson: null,
    attendanceSessionId: null,
    burnerPosition: 3,
    burnerActionCode: null,
    burnerOutcome: null,
    burnerMicroampReading: null,
    burnerBlockSupplyMode: null,
    burnerBlockSupplierName: null,
    burnerBlockPurchaseOrderNumber: null,
    ...overrides,
  };
}

function lockoutAction(overrides = {}) {
  return action({
    id: 'burner_ticket-1_3_uvDetectorReplacement',
    component: 'Burner 3',
    hierarchyPath: null,
    assetHierarchyRef: null,
    system: 'Combustion system',
    subsystem: 'Burner system',
    subComponent: 'UV detector replacement',
    tag: 'FR-07-B03',
    instance: '3',
    attendanceSessionId: 'burner_ticket-1_3',
    burnerActionCode: 'uvDetectorReplacement',
    burnerOutcome: 'returnedToService',
    ...overrides,
  });
}

function seedStore() {
  const store = new MemoryWorkflowStore();
  store.seed(`asset_classes/${IDS.assetClass}`, {
    schemaVersion: 1,
    assetClassId: IDS.assetClass,
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
  });
  store.seed(`asset_instances/${IDS.asset}`, {
    schemaVersion: 1,
    assetInstanceId: IDS.asset,
    assetClassId: IDS.assetClass,
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 7,
    name: 'Furnace 7',
    status: 'active',
    version: 4,
  });
  store.seed(`asset_hierarchy_nodes/${IDS.node}`, {
    schemaVersion: 1,
    nodeId: IDS.node,
    assetClassId: IDS.assetClass,
    name: 'UV flame scanner and peep sight',
    hierarchyPath: reference().hierarchyPath,
    nodeType: 'component',
    componentTag: null,
    status: 'active',
    version: 3,
  });
  return store;
}

async function prepare(store, row = action(), overrides = {}) {
  return store.runTransaction(async (tx) => {
    const plan = await prepareUvDetectorLifecycleWritePlan({
      tx,
      sourceType: 'workflowPlannedJob',
      sourceId: 'execution-1',
      assetType: 'furnace',
      assetNumber: 7,
      actionSources: [{
        sourceModuleId: 'module-1',
        discipline: 'instrumentation',
        actionsJson: JSON.stringify([row]),
      }],
      completedAt: '2026-08-28T09:00:00.000Z',
      recordedAt: '2026-08-28T09:00:00.000Z',
      completedBy: actor,
      ...overrides,
    });
    applyUvDetectorLifecycleWritePlan(tx, plan);
    return plan;
  });
}


module.exports = {IDS, actor, action, reference, lockoutAction, seedStore, prepare};
