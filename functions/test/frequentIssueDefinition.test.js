const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  MemoryWorkflowStore,
} = require('../lib/maintenanceWorkflow/memoryStore');

const now = new Date('2026-08-20T09:00:00.000Z');

function seedActor(store, uid, roles) {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
}

function seedFurnace(store) {
  store.seed('asset_classes/class-furnace', {
    schemaVersion: 1,
    assetClassId: 'class-furnace',
    status: 'active',
    legacyAssetTypeKey: 'furnace',
    code: 'FR',
    name: 'Furnace',
  });
  store.seed('asset_hierarchy_nodes/node-burner', {
    schemaVersion: 1,
    nodeId: 'node-burner',
    assetClassId: 'class-furnace',
    status: 'active',
    nodeType: 'component',
    name: 'Burner system',
    componentTag: null,
    version: 2,
    hierarchyPath: ['Furnace', 'Combustion system', 'Burner system'],
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'I&A',
    accountableRoleKeys: ['seniorInstrumentation'],
  });
  store.seed('asset_instances/furnace-7', {
    schemaVersion: 1,
    assetInstanceId: 'furnace-7',
    assetClassId: 'class-furnace',
    assetClassCode: 'FR',
    assetClassName: 'Furnace',
    assetNumber: 7,
    name: 'Furnace 7',
    status: 'active',
    version: 4,
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Operations',
    accountableRoleKeys: ['operations'],
  });
}

const definitionPayload = (overrides = {}) => ({
  schemaVersion: 1,
  code: 'FLAME_UNSTABLE',
  title: 'Unstable burner flame',
  description: 'Burner flame is unstable during normal firing.',
  applicableAssetTypeKeys: ['furnace'],
  applicableAssetClassIds: [],
  applicableComponentNodeIds: ['node-burner'],
  suggestedSeverityKey: 'normal',
  suggestedMaintenanceTypeKey: 'breakdown',
  defaultRouteKey: 'instrumentation',
  requiredEvidenceFields: ['observation'],
  aliases: ['flame hunting'],
  codeOwnedWorkflowProfile: null,
  ...overrides,
});

const upsertCommand = (overrides = {}) => ({
  commandId: 'upsert-frequent-1',
  commandType: 'upsertFrequentIssueDefinition',
  aggregateId: 'frequent-flame-unstable',
  expectedVersion: 0,
  payload: {
    definition: definitionPayload(),
    reason: 'Create the governed Furnace issue choice.',
  },
  ...overrides,
});

function assetReference(nodeId = 'node-burner') {
  return JSON.stringify({
    schemaVersion: 4,
    scope: 'componentDefinitionOnAsset',
    assetClassId: 'class-furnace',
    nodeId,
    nodeVersion: 2,
    assetInstanceId: 'furnace-7',
    assetInstanceVersion: 4,
  });
}

function createTicket(selection) {
  return {
    commandId: `create-ticket-${selection.selectionType}`,
    commandType: 'createMaintenanceTicket',
    aggregateId: `ticket-${selection.selectionType}`,
    expectedVersion: 0,
    payload: {
      ticket: {
        schemaVersion: 1,
        version: 1,
        assetType: 'furnace',
        assetNumber: 7,
        component: 'Burner system',
        subsystem: 'Combustion system',
        tag: null,
        hierarchyPath: ['Untrusted'],
        assetHierarchyRefJson: assetReference(),
        maintenanceType: 'breakdown',
        classification: null,
        description: 'Burner flame is unstable during normal firing.',
        routedTo: 'instrumentation',
        otherDepartment: null,
        isCritical: false,
        startDate: '2026-08-20T08:55:00.000Z',
        chargeNoAtEvent: null,
        qualityIntentSchemaVersion: 1,
        qualityImpactAssessment: 'notSuspected',
        qualityWarningReason: null,
        frequentIssueSelection: selection,
      },
    },
  };
}

describe('governed frequent-issue catalogue', () => {
  test('Admin creates and retires a hierarchy-scoped definition with audit evidence', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnace(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const service = new MaintenanceWorkflowCommandService(store);

    const created = await service.execute(upsertCommand(), {
      actor: admin,
      serverNow: now,
    });
    expect(created).toMatchObject({
      resultKey: 'frequent-issue-definition-created',
      aggregateVersion: 1,
    });
    expect(store.read('frequent_issue_definitions/frequent-flame-unstable'))
      .toMatchObject({
        status: 'active',
        normalizedCode: 'FLAME_UNSTABLE',
        applicableComponentNodeIds: ['node-burner'],
        version: 1,
      });
    expect(store.read('frequent_issue_definition_audits/upsert-frequent-1'))
      .toMatchObject({operation: 'create', performedByUid: 'admin-1'});

    await service.execute({
      commandId: 'retire-frequent-1',
      commandType: 'setFrequentIssueDefinitionStatus',
      aggregateId: 'frequent-flame-unstable',
      expectedVersion: 1,
      payload: {status: 'retired', reason: 'Superseded by a revised diagnosis.'},
    }, {actor: admin, serverNow: new Date('2026-08-20T09:05:00.000Z')});
    expect(store.read('frequent_issue_definitions/frequent-flame-unstable'))
      .toMatchObject({status: 'retired', version: 2});
  });

  test('a selected active definition is frozen into the issue', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnace(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const operator = seedActor(store, 'operator-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertCommand(), {actor: admin, serverNow: now});

    const receipt = await service.execute(createTicket({
      schemaVersion: 1,
      selectionType: 'definition',
      definitionId: 'frequent-flame-unstable',
      definitionVersion: 1,
      unlistedReason: null,
    }), {actor: operator, serverNow: new Date('2026-08-20T09:10:00.000Z')});

    expect(receipt.result.reviewQueueId).toBeNull();
    expect(store.read('maintenance_records/ticket-definition'))
      .toMatchObject({
        frequentIssueSelection: {
          selectionType: 'definition',
          definitionId: 'frequent-flame-unstable',
          definitionVersion: 1,
          definitionCode: 'FLAME_UNSTABLE',
          definitionTitle: 'Unstable burner flame',
        },
      });
  });

  test('Other remains usable but creates a governance review item', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnace(store);
    const operator = seedActor(store, 'operator-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);

    const receipt = await service.execute(createTicket({
      schemaVersion: 1,
      selectionType: 'unlisted',
      definitionId: null,
      definitionVersion: null,
      unlistedReason: 'Observed condition is not represented in the catalogue.',
    }), {actor: operator, serverNow: now});

    expect(receipt.result.reviewQueueId).toBe('ticket-unlisted');
    expect(store.read('issue_governance_review_queue/ticket-unlisted'))
      .toMatchObject({
        status: 'open',
        ticketId: 'ticket-unlisted',
        componentNodeId: 'node-burner',
        raisedByUid: 'operator-1',
      });
  });

  test('stale and out-of-scope definition selections fail closed', async () => {
    const store = new MemoryWorkflowStore();
    seedFurnace(store);
    const admin = seedActor(store, 'admin-1', ['admin']);
    const operator = seedActor(store, 'operator-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(upsertCommand(), {actor: admin, serverNow: now});

    await expect(service.execute(createTicket({
      schemaVersion: 1,
      selectionType: 'definition',
      definitionId: 'frequent-flame-unstable',
      definitionVersion: 2,
      unlistedReason: null,
    }), {actor: operator, serverNow: now})).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'frequent-issue-definition-changed'},
    });

    store.seed('frequent_issue_definitions/frequent-flame-unstable', {
      ...store.read('frequent_issue_definitions/frequent-flame-unstable'),
      applicableComponentNodeIds: ['another-node'],
    });
    await expect(service.execute(createTicket({
      schemaVersion: 1,
      selectionType: 'definition',
      definitionId: 'frequent-flame-unstable',
      definitionVersion: 1,
      unlistedReason: null,
    }), {actor: operator, serverNow: now})).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'frequent-issue-definition-out-of-scope'},
    });
  });
});
