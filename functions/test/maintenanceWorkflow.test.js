const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  equipmentIdentityFromWorkflow,
  equipmentPathForIdentity,
} = require('../lib/maintenanceWorkflow/paths');

const actor = (uid, roles) => ({uid, name: uid, roles: new Set(roles)});
const admin = actor('admin-1', ['admin']);
const ops = actor('ops-1', ['operations']);
const electrical = actor('elec-1', ['seniorElectrical']);
const refractory = actor('red-1', ['refractory']);
const contractSupervisor = actor('contract-1', ['contractSupervisor']);
const at = (value) => new Date(value);

const serviceFor = (store) => {
  for (const current of [admin, ops, electrical, refractory, contractSupervisor]) {
    store.seed(`users/${current.uid}`, {
      isApproved: true,
      roles: [...current.roles],
      name: current.name,
    });
  }
  return new MaintenanceWorkflowCommandService(store);
};

const seedLegacyAssignmentAuthority = (
  store,
  {assetNumber = 101, assetInstanceId = `base-${assetNumber}`} = {},
) => {
  store.seed('job_templates/template-1', {
    firestoreId: 'template-1',
    version: 1,
    jobName: 'Base planned maintenance',
    applicableAssetType: 'base',
    assignedAgencies: ['mechanical'],
    assetHierarchyRefJson: null,
    isActive: true,
    isDeprecated: false,
    isDeleted: false,
  });
  store.seed('asset_classes/base-class', {
    schemaVersion: 1,
    assetClassId: 'base-class',
    legacyAssetTypeKey: 'base',
    status: 'active',
  });
  store.seed(`asset_instances/${assetInstanceId}`, {
    schemaVersion: 1,
    assetInstanceId,
    assetClassId: 'base-class',
    assetNumber,
    status: 'active',
    version: 1,
  });
};

const governedLegacyPayload = (
  executionId,
  {assetInstanceId = 'base-101'} = {},
) => ({
  assignmentSchemaVersion: 2,
  executionId,
  templateFirestoreId: 'template-1',
  expectedTemplateVersion: 1,
  assetClassId: 'base-class',
  assetInstanceId,
});

const seedWorkflow = (store, id = 'wf1', status = 'pendingLaneClassification', version = 0, assetTypeKey = 'furnace', assetNumber = 7) => {
  store.seed(`maintenance_workflows/${id}`, {
    jobExecutionId: `${id}-exec`, status, version, assetTypeKey, assetNumber,
    laneSetFinalizedAt: null, cancelled: false,
    createdAt: '2026-07-20T00:00:00.000Z', updatedAt: '2026-07-20T00:00:00.000Z',
  });
  store.seed(`job_executions/${id}-exec`, {version: 1, isCompleted: false});
};

const seedRedSuccessorTemplate = (store, assetTypeKey = 'furnace') => {
  const code = assetTypeKey === 'base' ? 'RED-BASE-V1' : 'RED-FURNACE-V1';
  const packageId = assetTypeKey === 'base' ? 'pkg-red-base' : 'pkg-red-furnace';
  const versionId = assetTypeKey === 'base' ? 'ver-red-base' : 'ver-red-furnace';
  store.seed(`equipment_prompt_master/${assetTypeKey}_red`, {
    assetTypeKey, active: true, redSuccessorTemplateCode: code,
  });
  store.seed(`template_packages/${packageId}`, {
    packageCode: code, title: `${assetTypeKey} RED work`, lifecycleStatus: 'active',
    activeVersionFirestoreId: versionId, isDeleted: false,
  });
  store.seed(`template_versions/${versionId}`, {
    packageFirestoreId: packageId, status: 'published', isDeleted: false,
    versionNumber: 1, versionLabel: 'v1', contentHash: `hash-${assetTypeKey}-red`,
    jobTemplateSnapshotJson: JSON.stringify({jobName: `${assetTypeKey} RED successor`}),
    moduleSnapshotsJson: JSON.stringify([{
      moduleCode: 'RED-01', moduleTitle: 'Inspect and repair refractory',
      requiredForClosure: true, safetyClass: 'hotSurface',
    }]),
    fieldDefinitionsJson: JSON.stringify([{
      moduleCode: 'RED-01', key: 'condition', label: 'Refractory condition', type: 'longText',
    }]),
  });
};

describe('maintenance workflow command integration', () => {
  test('governed custom equipment paths include class and physical asset identity', () => {
    const first = equipmentIdentityFromWorkflow({
      assetTypeKey: 'governedCustom',
      assetNumber: 3,
      assetClassId: 'annealing-car-class',
      assetInstanceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    });
    const second = equipmentIdentityFromWorkflow({
      assetTypeKey: 'governedCustom',
      assetNumber: 3,
      assetClassId: 'transfer-car-class',
      assetInstanceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    });
    expect(equipmentPathForIdentity(first)).not.toBe(
      equipmentPathForIdentity(second),
    );
    expect(() => equipmentIdentityFromWorkflow({
      assetTypeKey: 'governedCustom',
      assetNumber: 3,
    })).toThrow('Governed custom equipment identity is incomplete.');
  });

  test('old client payload cannot create another ungoverned legacy job', async () => {
    const store = new MemoryWorkflowStore();
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'legacy-custom-denied',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-custom-exec',
      expectedVersion: 0,
      payload: {
        executionId: 'legacy-custom-exec',
        templateFirestoreId: 'legacy-template',
        templateName: 'Legacy custom job',
        assetTypeKey: 'governedCustom',
        assetNumber: 3,
        assignedAgencies: [],
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:00:00Z'),
    })).rejects.toMatchObject({code: 'invalid-argument'});
    expect(store.read('job_executions/legacy-custom-exec')).toBeNull();
  });

  test('legacy template assignment freezes governed identity atomically', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('equipment_status/base_101', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'legacy-create-1',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-exec-1',
      expectedVersion: 0,
      payload: {
        ...governedLegacyPayload('legacy-exec-1'),
        chargeNoAtEvent: 12345,
        remarks: 'Created pending lane classification',
      },
    }, {actor: admin, serverNow: at('2026-07-20T00:30:00Z')});
    expect(receipt.resultKey).toBe('workflow-job-created');
    expect(store.read('job_executions/legacy-exec-1')).toMatchObject({
      workflowSchemaVersion: 1,
      laneSetVersion: 0,
      assetType: 'base',
      assetNumber: 101,
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
      assignedAgencies: ['mechanical'],
      isCompleted: false,
      isCancelled: false,
    });
    expect(JSON.parse(
      store.read('job_executions/legacy-exec-1').metadataJson,
    )).toMatchObject({
      source: 'server_governed_legacy_template_assignment',
      assignmentSchemaVersion: 2,
      assignmentAssetIdentity: {
        assetClassId: 'base-class',
        assetInstanceId: 'base-101',
        assetNumber: 101,
      },
      jobTemplateSnapshot: {
        firestoreId: 'template-1',
        version: 1,
        jobName: 'Base planned maintenance',
      },
    });
    expect(store.read('maintenance_workflows/legacy-exec-1')).toMatchObject({
      status: 'pendingLaneClassification',
      version: 1,
      jobExecutionId: 'legacy-exec-1',
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
    });
    expect(store.read('equipment_status/base_101')).toMatchObject({
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
    });
    expect(store.read('maintenance_workflow_events/legacy-create-1')).toMatchObject({
      eventType: 'workflow.jobCreatedPendingClassification',
      aggregateId: 'legacy-exec-1',
    });
  });

  test('legacy assignment rejects an unreconciled missing equipment projection', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-create-missing-equipment',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-exec-missing-equipment',
      expectedVersion: 0,
      payload: governedLegacyPayload('legacy-exec-missing-equipment'),
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:45:00Z'),
    })).rejects.toMatchObject({
      code: 'equipment-state-conflict',
      details: {reasonCode: 'equipment-projection-missing'},
    });

    expect(store.read('job_executions/legacy-exec-missing-equipment')).toBeNull();
    expect(store.read('maintenance_workflows/legacy-exec-missing-equipment')).toBeNull();
  });

  test('legacy assignment rejects client-authored template and asset facts', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('equipment_status/base_101', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-client-facts',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-client-facts-exec',
      expectedVersion: 0,
      payload: {
        ...governedLegacyPayload('legacy-client-facts-exec'),
        assetNumber: 102,
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:46:00Z'),
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {
        reasonCode: 'legacy-assignment-server-owned-field',
        field: 'assetNumber',
      },
    });
    expect(store.read('job_executions/legacy-client-facts-exec')).toBeNull();
  });

  test('legacy assignment rejects stale template version with zero writes', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('equipment_status/base_101', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-stale-template',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-stale-template-exec',
      expectedVersion: 0,
      payload: {
        ...governedLegacyPayload('legacy-stale-template-exec'),
        expectedTemplateVersion: 2,
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:47:00Z'),
    })).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'legacy-template-version-changed'},
    });
    expect(store.read('job_executions/legacy-stale-template-exec')).toBeNull();
    expect(store.read('equipment_status/base_101')).toMatchObject({version: 0});
  });

  test('legacy assignment rejects an incomplete saved hierarchy reference', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('job_templates/template-1', {
      firestoreId: 'template-1',
      version: 1,
      jobName: 'Base planned maintenance',
      applicableAssetType: 'base',
      assignedAgencies: ['mechanical'],
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 2,
        scope: 'definition',
        assetClassId: 'base-class',
      }),
      isActive: true,
      isDeprecated: false,
      isDeleted: false,
    });
    store.seed('equipment_status/base_101', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-incomplete-hierarchy',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-incomplete-hierarchy-exec',
      expectedVersion: 0,
      payload: governedLegacyPayload('legacy-incomplete-hierarchy-exec'),
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:47:30Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'legacy-template-hierarchy-reference-invalid'},
    });
    expect(store.read('job_executions/legacy-incomplete-hierarchy-exec'))
      .toBeNull();
  });

  test('legacy assignment rejects contradictory fixed-asset evidence', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('job_templates/template-1', {
      firestoreId: 'template-1',
      version: 1,
      jobName: 'Base planned maintenance',
      applicableAssetType: 'base',
      assignedAgencies: ['mechanical'],
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 3,
        scope: 'physicalAsset',
        assetClassId: 'base-class',
        assetClassCode: 'BASE',
        assetClassName: 'Base',
        nodeId: 'base-101',
        nodeVersion: 1,
        nodeName: 'Base 101',
        assetInstanceId: 'base-101',
        assetInstanceVersion: 1,
        assetNumber: 102,
        assetInstanceName: 'Base 101',
        hierarchyPath: ['Base', 'Base 101'],
        ownershipStatus: 'unassigned',
        accountableRoleKeys: [],
      }),
      isActive: true,
      isDeprecated: false,
      isDeleted: false,
    });
    store.seed('equipment_status/base_101', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-contradictory-fixed-target',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-contradictory-fixed-target-exec',
      expectedVersion: 0,
      payload: governedLegacyPayload('legacy-contradictory-fixed-target-exec'),
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:47:45Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'legacy-template-asset-number-mismatch'},
    });
    expect(store.read('job_executions/legacy-contradictory-fixed-target-exec'))
      .toBeNull();
  });

  test('legacy Inner Cover assignment freezes the current Base linkage', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('job_templates/inner-template', {
      firestoreId: 'inner-template',
      version: 1,
      jobName: 'Inner Cover inspection',
      applicableAssetType: 'innerCover',
      assignedAgencies: ['mechanical'],
      assetHierarchyRefJson: null,
      isActive: true,
      isDeprecated: false,
      isDeleted: false,
    });
    store.seed('asset_classes/base-class', {
      schemaVersion: 1,
      assetClassId: 'base-class',
      legacyAssetTypeKey: 'base',
      status: 'active',
    });
    store.seed('asset_instances/base-201', {
      schemaVersion: 1,
      assetInstanceId: 'base-201',
      assetClassId: 'base-class',
      assetNumber: 201,
      status: 'active',
      version: 3,
    });
    store.seed('base_inner_cover_assignments/base-201', {
      schemaVersion: 1,
      baseAssetInstanceId: 'base-201',
      baseAssetClassId: 'base-class',
      baseAssetNumber: 201,
      innerCoverId: 'inner-gr26',
      innerCoverSerialNumber: 'GR26',
      linkageId: 'link-gr26-base-201',
      version: 4,
    });
    store.seed('inner_cover_profiles/inner-gr26', {
      schemaVersion: 1,
      innerCoverId: 'inner-gr26',
      serialNumber: 'GR26',
      lifecycleState: 'installed',
      currentBaseAssetInstanceId: 'base-201',
      currentBaseAssetNumber: 201,
      currentLinkageId: 'link-gr26-base-201',
    });
    store.seed('equipment_status/innerCover_201', {
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await service.execute({
      commandId: 'legacy-inner-cover',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-inner-cover-exec',
      expectedVersion: 0,
      payload: {
        assignmentSchemaVersion: 2,
        executionId: 'legacy-inner-cover-exec',
        templateFirestoreId: 'inner-template',
        expectedTemplateVersion: 1,
        assetClassId: 'base-class',
        assetInstanceId: 'base-201',
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:48:00Z'),
    });

    const execution = store.read('job_executions/legacy-inner-cover-exec');
    expect(execution).toMatchObject({
      assetType: 'innerCover',
      assetNumber: 201,
      assetClassId: 'base-class',
      assetInstanceId: 'base-201',
    });
    expect(JSON.parse(execution.metadataJson)).toMatchObject({
      assignmentInnerCoverPosition: {
        baseAssetInstanceId: 'base-201',
        innerCoverId: 'inner-gr26',
        innerCoverSerialNumber: 'GR26',
        linkageId: 'link-gr26-base-201',
        assignmentVersion: 4,
      },
    });
    expect(store.read('maintenance_workflows/legacy-inner-cover-exec'))
      .toMatchObject({
        innerCoverId: 'inner-gr26',
        innerCoverSerialNumber: 'GR26',
        innerCoverLinkageId: 'link-gr26-base-201',
        innerCoverAssignmentVersion: 4,
      });
  });

  test('legacy Inner Cover assignment rejects an instance-fixed template', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('job_templates/inner-fixed-template', {
      firestoreId: 'inner-fixed-template',
      version: 1,
      jobName: 'Fixed Inner Cover inspection',
      applicableAssetType: 'innerCover',
      assignedAgencies: ['mechanical'],
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 3,
        scope: 'physicalAsset',
        assetClassId: 'inner-cover-class',
        assetClassCode: 'INNER-COVER',
        assetClassName: 'Inner Cover',
        nodeId: 'inner-gr26',
        nodeVersion: 1,
        nodeName: 'Inner Cover GR26',
        assetInstanceId: 'inner-gr26',
        assetInstanceVersion: 1,
        assetNumber: 26,
        assetInstanceName: 'Inner Cover GR26',
        hierarchyPath: ['Inner Cover', 'Inner Cover GR26'],
        ownershipStatus: 'unassigned',
        accountableRoleKeys: [],
      }),
      isActive: true,
      isDeprecated: false,
      isDeleted: false,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-inner-cover-fixed-target',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-inner-cover-fixed-target-exec',
      expectedVersion: 0,
      payload: {
        assignmentSchemaVersion: 2,
        executionId: 'legacy-inner-cover-fixed-target-exec',
        templateFirestoreId: 'inner-fixed-template',
        expectedTemplateVersion: 1,
        assetClassId: 'base-class',
        assetInstanceId: 'base-201',
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:48:30Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'legacy-template-inner-cover-target-invalid'},
    });
    expect(store.read('job_executions/legacy-inner-cover-fixed-target-exec'))
      .toBeNull();
  });

  test('legacy assignment rejects a partial equipment identity projection', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store);
    store.seed('equipment_status/base_101', {
      state: 'available',
      assetClassId: 'base-class',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'legacy-partial-projection',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-partial-projection-exec',
      expectedVersion: 0,
      payload: governedLegacyPayload('legacy-partial-projection-exec'),
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:49:00Z'),
    })).rejects.toMatchObject({
      code: 'equipment-state-conflict',
      details: {reasonCode: 'equipment-projection-identity-incomplete'},
    });
    expect(store.read('job_executions/legacy-partial-projection-exec')).toBeNull();
  });

  test('Admin reconciliation initializes a new equipment projection before its first workflow', async () => {
    const store = new MemoryWorkflowStore();
    seedLegacyAssignmentAuthority(store, {
      assetNumber: 102,
      assetInstanceId: 'base-102',
    });
    const service = serviceFor(store);

    await service.execute({
      commandId: 'reconcile-new-equipment',
      commandType: 'reconcileEquipment',
      aggregateId: 'equipment_base_102',
      expectedVersion: 0,
      payload: {
        assetTypeKey: 'base',
        assetNumber: 102,
      },
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:50:00Z'),
    });

    expect(store.read('equipment_status/base_102')).toMatchObject({
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });

    await service.execute({
      commandId: 'legacy-create-after-reconcile',
      commandType: 'createLegacyWorkflowJob',
      aggregateId: 'legacy-exec-after-reconcile',
      expectedVersion: 0,
      payload: governedLegacyPayload('legacy-exec-after-reconcile', {
        assetInstanceId: 'base-102',
      }),
    }, {
      actor: admin,
      serverNow: at('2026-07-20T00:51:00Z'),
    });

    expect(store.read('equipment_status/base_102')).toMatchObject({
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });
  });

  test('records Admin action transparently on behalf of EMD', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    await service.execute({commandId: 'emd-finalise', commandType: 'finalizeLaneSet', aggregateId: 'wf1', expectedVersion: 0, payload: {laneKeys: ['emd']}}, {actor: admin, serverNow: at('2026-07-20T01:00:00Z')});
    expect(store.read('job_lanes/wf1_emd_1')).toMatchObject({
      assetTypeKey: 'furnace',
      assetNumber: 7,
    });
    await service.execute({commandId: 'emd-ack', commandType: 'acknowledgeLane', aggregateId: 'wf1', expectedVersion: 1, payload: {laneKey: 'emd'}}, {actor: admin, serverNow: at('2026-07-20T01:01:00Z')});
    expect(store.read('maintenance_workflow_events/emd-ack')).toMatchObject({representedLaneKey: 'emd', actorUid: 'admin-1'});
  });

  test('condition confirmation complies and reactivates the linked maintenance item', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf1', 'awaitingCompliance', 3);
    store.seed('maintenance_records/m1', {version: 1, workflowAggregateId: 'wf1', workflowComplianceId: 'c1', workflowQueueState: 'deferred', workflowDeferred: true});
    store.seed('compliance_requests/c1', {linkedWorkflowId: 'wf1', linkedMaintenanceFirestoreId: 'm1', targetLaneKey: 'elec', status: 'acknowledged', conditionTypeKey: 'chargeComplete', version: 1});
    const service = serviceFor(store);
    await service.execute({commandId: 'reactivate', commandType: 'confirmConditionAndReactivate', aggregateId: 'wf1', expectedVersion: 3, payload: {complianceId: 'c1'}}, {actor: ops, serverNow: at('2026-07-20T02:00:00Z')});
    expect(store.read('compliance_requests/c1').status).toBe('complied');
    expect(store.read('maintenance_records/m1')).toMatchObject({workflowQueueState: 'actionable', workflowDeferred: false});
  });

  test('accepted counter supersedes original and creates one acknowledged successor', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf1', 'awaitingCompliance', 4);
    store.seed('compliance_requests/c1', {linkedWorkflowId: 'wf1', originLaneKey: 'elec', targetLaneKey: 'oprn', status: 'acknowledged', counterDepth: 0, counterProposal: {revisedDescription: 'After crane release', proposedByUid: 'ops-1', proposedByName: 'ops-1'}, version: 2});
    const service = serviceFor(store);
    await service.execute({commandId: 'counter', commandType: 'decideCounterCondition', aggregateId: 'wf1', expectedVersion: 4, payload: {complianceId: 'c1', accepted: true, successorComplianceId: 'c2'}}, {actor: electrical, serverNow: at('2026-07-20T03:00:00Z')});
    expect(store.read('compliance_requests/c1').status).toBe('superseded');
    expect(store.read('compliance_requests/c2')).toMatchObject({status: 'acknowledged', counterConditionOfId: 'c1', targetLaneKey: 'oprn'});
  });

  test('force cooler finalization never asks for or creates RED work', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf1', 'readyForClosure', 7, 'forceCooler', 2);
    store.seed('maintenance_workflows/wf1', {jobExecutionId: 'wf1-exec', status: 'readyForClosure', version: 7, assetTypeKey: 'forceCooler', assetNumber: 2, laneSetFinalizedAt: '2026-07-20T00:00:00Z'});
    store.seed('job_lanes/wf1_mech_1', {workflowId: 'wf1', jobExecutionId: 'wf1-exec', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    store.seed('equipment_status/forceCooler_2', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: 'final-force-cooler', commandType: 'finalizeJob', aggregateId: 'wf1', expectedVersion: 7, payload: {}}, {actor: admin, serverNow: at('2026-07-20T04:00:00Z')});
    expect(receipt.result).toMatchObject({redAction: 'notApplicable', equipmentState: 'available'});
  });

  test('new furnace RED successor is gated by Operations preparation', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf1', 'readyForClosure', 8);
    store.seed('maintenance_workflows/wf1', {jobExecutionId: 'wf1-exec', status: 'readyForClosure', version: 8, assetTypeKey: 'furnace', assetNumber: 7, laneSetFinalizedAt: '2026-07-20T00:00:00Z'});
    store.seed('job_lanes/wf1_mech_1', {workflowId: 'wf1', jobExecutionId: 'wf1-exec', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    store.seed('equipment_status/furnace_7', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });
    seedRedSuccessorTemplate(store, 'furnace');
    const service = serviceFor(store);
    const actionsJson = JSON.stringify([{
      asset: 'furnace-7', component: 'burner', actionType: 'inspection',
      isAutoResolved: false, createdAt: '2026-07-20T04:55:00.000Z',
      severity: 'medium', version: 1,
    }]);
    const receipt = await service.execute({commandId: 'final-red', commandType: 'finalizeJob', aggregateId: 'wf1', expectedVersion: 8, payload: {redRequired: true, preparationRequired: true, remarks: 'Mechanical work complete', teamsInvolved: ['mechanical'], responsesJson: '[{"key":"final","value":"ok"}]', actionsJson}}, {actor: admin, serverNow: at('2026-07-20T05:00:00Z')});
    const successorWorkflowId = receipt.result.successorWorkflowId;
    const successorExecutionId = receipt.result.successorExecutionId;
    expect(store.read(`maintenance_workflows/${successorWorkflowId}`)).toMatchObject({status: 'awaitingCompliance', activeRedWork: false, awaitingPreparation: true});
    expect(store.read(`job_executions/${successorExecutionId}`)).toMatchObject({
      templatePackageCode: 'RED-FURNACE-V1',
      assignedAgencies: ['refractory'],
      isCompleted: false,
      isCancelled: false,
    });
    expect(store.entries().filter(([path]) => path.startsWith('job_modules/red_module_'))).toHaveLength(1);
    expect(store.read('job_executions/wf1-exec')).toMatchObject({
      isCompleted: true, remarks: 'Mechanical work complete', teamsInvolved: ['mechanical'],
      responsesJson: '[{"key":"final","value":"ok"}]',
      actionsJson,
      spawnedRedExecutionFirestoreId: successorExecutionId,
    });
    expect(store.read('equipment_status/furnace_7').state).toBe('awaitingPreparation');
  });

  test('RED successor creation rejects malformed published field definitions', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-red-invalid', 'readyForClosure', 3);
    store.seed('maintenance_workflows/wf-red-invalid', {
      jobExecutionId: 'wf-red-invalid-exec', status: 'readyForClosure', version: 3,
      assetTypeKey: 'furnace', assetNumber: 7,
      laneSetFinalizedAt: '2026-07-20T00:00:00Z', cancelled: false,
    });
    store.seed('job_lanes/wf-red-invalid_mech_1', {
      workflowId: 'wf-red-invalid', jobExecutionId: 'wf-red-invalid-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2,
    });
    store.seed('equipment_status/furnace_7', {
      state: 'underMaintenance', activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 2,
    });
    seedRedSuccessorTemplate(store, 'furnace');
    const version = store.read('template_versions/ver-red-furnace');
    store.seed('template_versions/ver-red-furnace', {
      ...version,
      fieldDefinitionsJson: JSON.stringify([{
        moduleCode: 'RED-01', label: 'Missing key', type: 'longText',
      }]),
    });

    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'reject-red-invalid', commandType: 'finalizeJob',
      aggregateId: 'wf-red-invalid', expectedVersion: 3,
      payload: {redRequired: true, preparationRequired: true},
    }, {actor: admin, serverNow: at('2026-07-20T05:05:00Z')}))
      .rejects.toMatchObject({
        code: 'red-successor-template-unconfigured',
        details: expect.objectContaining({
          reasonCode: 'field-definition-payload-invalid',
        }),
      });

    store.seed('template_versions/ver-red-furnace', {
      ...version,
      fieldDefinitionsJson: null,
    });
    await expect(service.execute({
      commandId: 'reject-red-null', commandType: 'finalizeJob',
      aggregateId: 'wf-red-invalid', expectedVersion: 3,
      payload: {redRequired: true, preparationRequired: true},
    }, {actor: admin, serverNow: at('2026-07-20T05:06:00Z')}))
      .rejects.toMatchObject({
        code: 'red-successor-template-unconfigured',
        details: expect.objectContaining({
          reasonCode: 'field-definition-payload-invalid',
        }),
      });
    expect(store.read('job_executions/wf-red-invalid-exec').isCompleted)
      .toBe(false);
  });

  test('base RED successor starts in situ without preparation compliance', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-base', 'readyForClosure', 2, 'base', 101);
    store.seed('maintenance_workflows/wf-base', {jobExecutionId: 'wf-base-exec', status: 'readyForClosure', version: 2, assetTypeKey: 'base', assetNumber: 101, laneSetFinalizedAt: '2026-07-20T00:00:00Z'});
    store.seed('job_lanes/wf-base_mech_1', {workflowId: 'wf-base', jobExecutionId: 'wf-base-exec', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    store.seed('equipment_status/base_101', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    seedRedSuccessorTemplate(store, 'base');
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: 'final-base-red', commandType: 'finalizeJob', aggregateId: 'wf-base', expectedVersion: 2, payload: {redRequired: true}}, {actor: admin, serverNow: at('2026-07-20T05:30:00Z')});
    const successorId = receipt.result.successorWorkflowId;
    expect(receipt.result.preparationComplianceId).toBeNull();
    expect(store.read(`maintenance_workflows/${successorId}`)).toMatchObject({activeRedWork: true, awaitingPreparation: false, status: 'assigned'});
    expect(store.read(`job_lanes/${successorId}_red_1`)).toMatchObject({status: 'pending', gatingComplianceRequestId: null});
    expect(store.read('equipment_status/base_101').state).toBe('underRED');
  });

  test('ordinary Operations user cannot finalize the overall planned job', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-no-final', 'readyForClosure', 2, 'forceCooler', 1);
    store.seed('maintenance_workflows/wf-no-final', {jobExecutionId: 'wf-no-final-exec', status: 'readyForClosure', version: 2, assetTypeKey: 'forceCooler', assetNumber: 1, laneSetFinalizedAt: '2026-07-20T00:00:00Z'});
    store.seed('job_lanes/wf-no-final_mech_1', {workflowId: 'wf-no-final', jobExecutionId: 'wf-no-final-exec', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    const service = serviceFor(store);
    await expect(service.execute({commandId: 'ops-final-denied', commandType: 'finalizeJob', aggregateId: 'wf-no-final', expectedVersion: 2, payload: {}}, {actor: ops, serverNow: at('2026-07-20T05:45:00Z')})).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('preselected furnace RED cannot acknowledge until preparation is confirmed', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-pre', {jobExecutionId: 'exec-pre', status: 'inProgress', version: 3, assetTypeKey: 'furnace', assetNumber: 8, assetClassId: 'furnace-class', assetInstanceId: 'furnace-8', laneSetFinalizedAt: '2026-07-20T00:00:00Z', activeRedWork: false, awaitingPreparation: false});
    store.seed('job_executions/exec-pre', {
      isCompleted: false, isCancelled: false, isDeleted: false, version: 1,
    });
    store.seed('job_lanes/wf-pre_mech_1', {workflowId: 'wf-pre', jobExecutionId: 'exec-pre', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    store.seed('job_lanes/wf-pre_red_1', {workflowId: 'wf-pre', jobExecutionId: 'exec-pre', laneKey: 'red', status: 'pending', activationGeneration: 1, version: 1});
    store.seed('equipment_status/furnace_8', {
      state: 'underMaintenance',
      assetClassId: 'furnace-class',
      assetInstanceId: 'furnace-8',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    const service = serviceFor(store);
    await service.execute({commandId: 'prepare-red', commandType: 'prepareRedLane', aggregateId: 'wf-pre', expectedVersion: 3, payload: {preparationRequired: true}}, {actor: admin, serverNow: at('2026-07-20T06:00:00Z')});
    expect(store.read('equipment_status/furnace_8')).toMatchObject({
      assetClassId: 'furnace-class', assetInstanceId: 'furnace-8',
    });
    await expect(service.execute({commandId: 'early-red-ack', commandType: 'acknowledgeLane', aggregateId: 'wf-pre', expectedVersion: 4, payload: {laneKey: 'red'}}, {actor: refractory, serverNow: at('2026-07-20T06:01:00Z')})).rejects.toMatchObject({code: 'red-preparation-incomplete'});
    await service.execute({commandId: 'ack-prep', commandType: 'acknowledgeCompliance', aggregateId: 'wf-pre', expectedVersion: 4, payload: {complianceId: 'wf-pre_red_preparation'}}, {actor: ops, serverNow: at('2026-07-20T06:02:00Z')});
    await service.execute({commandId: 'comply-prep', commandType: 'markComplianceComplied', aggregateId: 'wf-pre', expectedVersion: 5, payload: {complianceId: 'wf-pre_red_preparation', note: 'Placed on stand'}}, {actor: ops, serverNow: at('2026-07-20T06:03:00Z')});
    await service.execute({commandId: 'confirm-prep', commandType: 'confirmComplianceClosed', aggregateId: 'wf-pre', expectedVersion: 6, payload: {complianceId: 'wf-pre_red_preparation'}}, {actor: refractory, serverNow: at('2026-07-20T06:04:00Z')});
    expect(store.read('equipment_status/furnace_8')).toMatchObject({
      assetClassId: 'furnace-class', assetInstanceId: 'furnace-8',
    });
    const receipt = await service.execute({commandId: 'red-ack', commandType: 'acknowledgeLane', aggregateId: 'wf-pre', expectedVersion: 7, payload: {laneKey: 'red'}}, {actor: refractory, serverNow: at('2026-07-20T06:05:00Z')});
    expect(receipt.resultKey).toBe('lane-acknowledged');
    expect(store.read('equipment_status/furnace_8').state).toBe('underRED');
  });

  test('equipment remains under maintenance when another job on the asset is open', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-final', {jobExecutionId: 'exec-final', status: 'readyForClosure', version: 4, assetTypeKey: 'furnace', assetNumber: 11, laneSetFinalizedAt: '2026-07-20T00:00:00Z'});
    store.seed('job_lanes/wf-final_mech_1', {workflowId: 'wf-final', jobExecutionId: 'exec-final', laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2});
    store.seed('job_executions/exec-final', {version: 1, isCompleted: false});
    store.seed('maintenance_workflows/wf-other', {jobExecutionId: 'exec-other', status: 'inProgress', version: 2, assetTypeKey: 'furnace', assetNumber: 11, activeRedWork: false, awaitingPreparation: false});
    store.seed('equipment_status/furnace_11', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 3,
    });
    const service = serviceFor(store);
    await service.execute({commandId: 'final-multi', commandType: 'finalizeJob', aggregateId: 'wf-final', expectedVersion: 4, payload: {redRequired: false}}, {actor: admin, serverNow: at('2026-07-20T07:00:00Z')});
    expect(store.read('equipment_status/furnace_11')).toMatchObject({state: 'underMaintenance', activeNonRedMaintenanceCount: 1});
  });

  test('workflow mutation fails closed when serialized equipment counters omit the current workflow', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-counter-conflict', {
      jobExecutionId: 'exec-counter-conflict',
      status: 'readyForClosure',
      version: 4,
      assetTypeKey: 'furnace',
      assetNumber: 12,
      laneSetFinalizedAt: '2026-07-20T00:00:00Z',
      activeRedWork: false,
      awaitingPreparation: false,
    });
    store.seed('job_lanes/wf-counter-conflict_mech_1', {
      workflowId: 'wf-counter-conflict',
      jobExecutionId: 'exec-counter-conflict',
      laneKey: 'mech',
      status: 'closed',
      activationGeneration: 1,
      version: 2,
    });
    store.seed('job_executions/exec-counter-conflict', {
      version: 1,
      isCompleted: false,
    });
    store.seed('equipment_status/furnace_12', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 3,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'final-counter-conflict',
      commandType: 'finalizeJob',
      aggregateId: 'wf-counter-conflict',
      expectedVersion: 4,
      payload: {redRequired: false},
    }, {
      actor: admin,
      serverNow: at('2026-07-20T07:30:00Z'),
    })).rejects.toMatchObject({code: 'equipment-state-conflict'});

    expect(store.read('maintenance_workflows/wf-counter-conflict')).toMatchObject({
      status: 'readyForClosure',
      version: 4,
    });
    expect(store.read('job_executions/exec-counter-conflict')).toMatchObject({
      isCompleted: false,
      version: 1,
    });
  });

  test('workflow mutation fails closed when the equipment counter set is partial', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-partial-counters', {
      jobExecutionId: 'exec-partial-counters',
      status: 'readyForClosure',
      version: 4,
      assetTypeKey: 'furnace',
      assetNumber: 13,
      laneSetFinalizedAt: '2026-07-20T00:00:00Z',
      activeRedWork: false,
      awaitingPreparation: false,
    });
    store.seed('job_lanes/wf-partial-counters_mech_1', {
      workflowId: 'wf-partial-counters',
      jobExecutionId: 'exec-partial-counters',
      laneKey: 'mech',
      status: 'closed',
      activationGeneration: 1,
      version: 2,
    });
    store.seed('job_executions/exec-partial-counters', {
      version: 1,
      isCompleted: false,
    });
    store.seed('equipment_status/furnace_13', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      awaitingPreparationCount: 0,
      version: 3,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: 'final-partial-counters',
      commandType: 'finalizeJob',
      aggregateId: 'wf-partial-counters',
      expectedVersion: 4,
      payload: {redRequired: false},
    }, {
      actor: admin,
      serverNow: at('2026-07-20T07:45:00Z'),
    })).rejects.toMatchObject({
      code: 'equipment-state-conflict',
      details: {
        reasonCode: 'equipment-projection-counter-set-incomplete',
        missingFields: ['activeRedWorkCount'],
      },
    });

    expect(store.read('maintenance_workflows/wf-partial-counters')).toMatchObject({
      status: 'readyForClosure',
      version: 4,
    });
    expect(store.read('job_executions/exec-partial-counters')).toMatchObject({
      isCompleted: false,
      version: 1,
    });
  });

  test('same command id replays the original receipt without reapplying writes', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    const cmd = {commandId: 'replay-one', commandType: 'finalizeLaneSet', aggregateId: 'wf1', expectedVersion: 0, payload: {laneKeys: ['elec']}};
    const first = await service.execute(cmd, {actor: admin, serverNow: at('2026-07-20T08:00:00Z')});
    const second = await service.execute(cmd, {actor: admin, serverNow: at('2026-07-20T08:01:00Z')});
    expect(second).toEqual(first);
    expect(store.entries().filter(([path]) => path.startsWith('job_lanes/'))).toHaveLength(1);
  });

  test('compliance attempts are immutable evidence across correction and acceptance', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-attempt', 'awaitingCompliance', 1);
    store.seed('compliance_requests/c-attempt', {
      linkedWorkflowId: 'wf-attempt', originLaneKey: 'elec', targetLaneKey: 'oprn',
      status: 'acknowledged', version: 1, attemptCount: 0,
    });
    const service = serviceFor(store);
    await service.execute({commandId: 'attempt-1', commandType: 'markComplianceComplied', aggregateId: 'wf-attempt', expectedVersion: 1, payload: {complianceId: 'c-attempt', note: 'Initial placement'}}, {actor: ops, serverNow: at('2026-07-20T11:00:00Z')});
    expect(store.read('compliance_attempts/c-attempt_1')).toMatchObject({attemptNumber: 1, note: 'Initial placement', accepted: false});
    await service.execute({commandId: 'return-1', commandType: 'returnComplianceForCorrection', aggregateId: 'wf-attempt', expectedVersion: 2, payload: {complianceId: 'c-attempt', reason: 'Isolation incomplete'}}, {actor: electrical, serverNow: at('2026-07-20T11:01:00Z')});
    expect(store.read('compliance_attempts/c-attempt_1')).toMatchObject({returnedByUid: 'elec-1', returnReason: 'Isolation incomplete', accepted: false});
    await service.execute({commandId: 'attempt-2', commandType: 'markComplianceComplied', aggregateId: 'wf-attempt', expectedVersion: 3, payload: {complianceId: 'c-attempt', note: 'Isolation completed'}}, {actor: ops, serverNow: at('2026-07-20T11:02:00Z')});
    await service.execute({commandId: 'accept-2', commandType: 'confirmComplianceClosed', aggregateId: 'wf-attempt', expectedVersion: 4, payload: {complianceId: 'c-attempt', note: 'Verified'}}, {actor: electrical, serverNow: at('2026-07-20T11:03:00Z')});
    expect(store.read('compliance_attempts/c-attempt_2')).toMatchObject({accepted: true, acceptedByUid: 'elec-1'});
    expect(store.read('compliance_attempts/c-attempt_1').returnReason).toBe('Isolation incomplete');
  });

  test('accepted counter transfers a blocking lane gate to its successor', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-gate', 'awaitingCompliance', 2);
    store.seed('job_lanes/wf-gate_mech_1', {workflowId: 'wf-gate', laneKey: 'mech', status: 'acknowledged', version: 2, gatingComplianceRequestId: 'c-gate'});
    store.seed('compliance_requests/c-gate', {
      linkedWorkflowId: 'wf-gate', originLaneKey: 'elec', targetLaneKey: 'oprn',
      status: 'acknowledged', gatesLaneFirestoreId: 'job_lanes/wf-gate_mech_1',
      counterDepth: 0, counterProposal: {revisedDescription: 'After crane release', proposedByUid: 'ops-1', proposedByName: 'ops-1'}, version: 1,
    });
    const service = serviceFor(store);
    await service.execute({commandId: 'gate-counter', commandType: 'decideCounterCondition', aggregateId: 'wf-gate', expectedVersion: 2, payload: {complianceId: 'c-gate', accepted: true, successorComplianceId: 'c-gate-2'}}, {actor: electrical, serverNow: at('2026-07-20T12:00:00Z')});
    expect(store.read('job_lanes/wf-gate_mech_1').gatingComplianceRequestId).toBe('c-gate-2');
    expect(store.read('compliance_requests/c-gate-2')).toMatchObject({gatesLaneFirestoreId: 'job_lanes/wf-gate_mech_1', counterDepth: 1});
  });

  test('rejected counter consumes the single revision and a second proposal is denied', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-reject', 'awaitingCompliance', 2);
    store.seed('compliance_requests/c-reject', {
      linkedWorkflowId: 'wf-reject', originLaneKey: 'elec', targetLaneKey: 'oprn', status: 'acknowledged',
      counterDepth: 0, counterProposal: {revisedDescription: 'Later', proposedByUid: 'ops-1'}, version: 1,
    });
    const service = serviceFor(store);
    await service.execute({commandId: 'reject-counter', commandType: 'decideCounterCondition', aggregateId: 'wf-reject', expectedVersion: 2, payload: {complianceId: 'c-reject', accepted: false, note: 'Urgent work cannot wait'}}, {actor: electrical, serverNow: at('2026-07-20T13:00:00Z')});
    expect(store.read('compliance_requests/c-reject')).toMatchObject({counterDepth: 1, escalationTier: 1});
    await expect(service.execute({commandId: 'second-counter', commandType: 'proposeCounterCondition', aggregateId: 'wf-reject', expectedVersion: 3, payload: {complianceId: 'c-reject', revisedDescription: 'Another revision'}}, {actor: ops, serverNow: at('2026-07-20T13:01:00Z')})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('equipment deployment uses optimistic version and reconciliation is Admin/SI only', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('equipment_status/furnace_15', {state: 'available', version: 4});
    const service = serviceFor(store);
    await expect(service.execute({commandId: 'stale-deploy', commandType: 'deployEquipment', aggregateId: 'equipment_furnace_15', expectedVersion: 3, payload: {assetTypeKey: 'furnace', assetNumber: 15}}, {actor: ops, serverNow: at('2026-07-20T14:00:00Z')})).rejects.toMatchObject({code: 'workflow-version-conflict'});
    await service.execute({commandId: 'deploy', commandType: 'deployEquipment', aggregateId: 'equipment_furnace_15', expectedVersion: 4, payload: {assetTypeKey: 'furnace', assetNumber: 15}}, {actor: ops, serverNow: at('2026-07-20T14:01:00Z')});
    expect(store.read('equipment_status/furnace_15')).toMatchObject({state: 'inService', version: 5});
    await expect(service.execute({commandId: 'bad-reconcile', commandType: 'reconcileEquipment', aggregateId: 'equipment_furnace_15', expectedVersion: 5, payload: {assetTypeKey: 'furnace', assetNumber: 15}}, {actor: ops, serverNow: at('2026-07-20T14:02:00Z')})).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('compliance creation requires an accountable origin lane and lane work authority', async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, 'wf-compliance', 'inProgress', 2);
    store.seed('job_lanes/wf-compliance_elec_1', {
      workflowId: 'wf-compliance', laneKey: 'elec', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-compliance_oprn_1', {
      workflowId: 'wf-compliance', laneKey: 'oprn', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'raise-without-origin',
      commandType: 'raiseCompliance',
      aggregateId: 'wf-compliance',
      expectedVersion: 2,
      payload: {
        complianceId: 'c-no-origin',
        targetLaneKey: 'oprn',
        title: 'Confirm isolation',
        description: 'Isolation confirmation is required before work proceeds.',
        conditionTypeKey: 'manual',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T15:00:00Z')})).rejects.toMatchObject({code: 'invalid-argument'});

    const receipt = await service.execute({
      commandId: 'raise-with-origin',
      commandType: 'raiseCompliance',
      aggregateId: 'wf-compliance',
      expectedVersion: 2,
      payload: {
        complianceId: 'c-with-origin',
        originLaneKey: 'elec',
        targetLaneKey: 'oprn',
        title: 'Confirm isolation',
        description: 'Isolation confirmation is required before work proceeds.',
        conditionTypeKey: 'manual',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T15:01:00Z')});
    expect(receipt.resultKey).toBe('compliance-raised');
    expect(store.read('compliance_requests/c-with-origin')).toMatchObject({
      originLaneKey: 'elec',
      targetLaneKey: 'oprn',
      raisedByUid: 'elec-1',
    });
  });

  test('supervisor coordinates Operations support without impersonating the origin discipline', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-support', 'inProgress', 2);
    store.seed('job_lanes/wf-support_mech_1', {
      workflowId: 'wf-support', laneKey: 'mech', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-support_oprn_1', {
      workflowId: 'wf-support', laneKey: 'oprn', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    const service = serviceFor(store);
    await service.execute({
      commandId: 'raise-support', commandType: 'raiseCompliance',
      aggregateId: 'wf-support', expectedVersion: 2,
      payload: {
        complianceId: 'c-support', originLaneKey: 'mech', targetLaneKey: 'oprn',
        requestPurposeKey: 'operationsSupport', title: 'Move furnace for access',
        description: 'Move the furnace to the maintenance bay.',
        conditionTypeKey: 'manual', operationsSupportTypeKey: 'assetRelocation',
        operationsResourceKey: 'crane', requestedLocation: 'Maintenance bay 2',
      },
    }, {actor: contractSupervisor, serverNow: at('2026-07-20T15:02:00Z')});

    expect(store.read('compliance_requests/c-support')).toMatchObject({
      requestPurposeKey: 'operationsSupport',
      operationsSupportTypeKey: 'assetRelocation',
      operationsResourceKey: 'crane', requestedLocation: 'Maintenance bay 2',
      raisedUnderCoordination: true,
      coordinationBasis: 'supervisory-workflow-coordination',
      raisedByUid: 'contract-1', originLaneKey: 'mech', targetLaneKey: 'oprn',
    });
    expect(store.read('maintenance_workflow_command_receipts/raise-support'))
      .toMatchObject({
        authorityScope: {
          schemaVersion: 1, capability: 'compliance.raise', laneKey: 'mech',
        },
      });
  });

  test('typed deferment and Operations support fail closed when their required context is absent', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-purpose', 'inProgress', 1);
    for (const laneKey of ['elec', 'oprn']) {
      store.seed(`job_lanes/wf-purpose_${laneKey}_1`, {
        workflowId: 'wf-purpose', laneKey, status: 'acknowledged',
        activationGeneration: 1, version: 1,
      });
    }
    const service = serviceFor(store);
    const base = {
      commandType: 'raiseCompliance', aggregateId: 'wf-purpose',
      expectedVersion: 1,
    };
    await expect(service.execute({...base, commandId: 'bad-deferment', payload: {
      complianceId: 'c-bad-deferment', originLaneKey: 'elec', targetLaneKey: 'oprn',
      requestPurposeKey: 'deferment', defermentBasisKey: 'ongoingCycle',
      title: 'Wait', description: 'Wait for current operations.',
      conditionTypeKey: 'manual',
    }}, {actor: electrical, serverNow: at('2026-07-20T15:03:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});

    await expect(service.execute({...base, commandId: 'bad-support', payload: {
      complianceId: 'c-bad-support', originLaneKey: 'elec', targetLaneKey: 'oprn',
      requestPurposeKey: 'operationsSupport', title: 'Move asset',
      description: 'Crane movement is required.', conditionTypeKey: 'manual',
      operationsSupportTypeKey: 'craneMovement', operationsResourceKey: 'crane',
    }}, {actor: electrical, serverNow: at('2026-07-20T15:04:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});

    await expect(service.execute({...base, commandId: 'bad-purpose-type', payload: {
      complianceId: 'c-bad-purpose-type', originLaneKey: 'elec', targetLaneKey: 'oprn',
      requestPurposeKey: 7, title: 'Malformed purpose',
      description: 'A non-string purpose must not default to assurance.',
      conditionTypeKey: 'manual',
    }}, {actor: electrical, serverNow: at('2026-07-20T15:05:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});

    await expect(service.execute({...base, commandId: 'bad-location-type', payload: {
      complianceId: 'c-bad-location-type', originLaneKey: 'elec', targetLaneKey: 'oprn',
      requestPurposeKey: 'operationsSupport', title: 'Prepare isolation',
      description: 'A provided location must retain its declared string type.',
      conditionTypeKey: 'manual', operationsSupportTypeKey: 'isolation',
      operationsResourceKey: 'operationsCrew', requestedLocation: 4,
    }}, {actor: electrical, serverNow: at('2026-07-20T15:06:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('deferred compliance governs and releases the linked original maintenance ticket', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-bridge', {
      jobExecutionId: 'wf-bridge', assetTypeKey: 'furnace', assetNumber: 7,
      status: 'inProgress', version: 4,
    });
    store.seed('job_executions/wf-bridge', {
      isCompleted: false, isCancelled: false, isDeleted: false, version: 1,
    });
    store.seed('job_lanes/wf-bridge_elec_1', {
      workflowId: 'wf-bridge', laneKey: 'elec', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-bridge_oprn_1', {
      workflowId: 'wf-bridge', laneKey: 'oprn', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('maintenance_records/m-bridge', {
      firestoreId: 'm-bridge', assetType: 'furnace', assetNumber: 7,
      status: 'open', isResolved: false, isDeleted: false,
      workflowQueueState: 'independent', workflowDeferred: false, version: 2,
    });
    const service = serviceFor(store);
    await service.execute({
      commandId: 'raise-bridge', commandType: 'raiseCompliance',
      aggregateId: 'wf-bridge', expectedVersion: 4,
      payload: {
        complianceId: 'c-bridge', originLaneKey: 'elec', targetLaneKey: 'oprn',
        linkedMaintenanceFirestoreId: 'm-bridge',
        title: 'Wait for charge completion', description: 'Resume after charge 41.',
        conditionTypeKey: 'chargeComplete', conditionRef: '41',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T16:00:00Z')});
    expect(store.read('maintenance_records/m-bridge')).toMatchObject({
      workflowAggregateId: 'wf-bridge', workflowComplianceId: 'c-bridge',
      workflowQueueState: 'deferred', workflowDeferred: true,
      workflowTargetLaneKey: 'oprn', version: 3,
    });

    await service.execute({
      commandId: 'reactivate-bridge', commandType: 'confirmConditionAndReactivate',
      aggregateId: 'wf-bridge', expectedVersion: 5,
      payload: {complianceId: 'c-bridge', note: 'Charge 41 complete'},
    }, {actor: ops, serverNow: at('2026-07-20T16:30:00Z')});
    expect(store.read('maintenance_records/m-bridge')).toMatchObject({
      workflowQueueState: 'actionable', workflowDeferred: false, version: 4,
    });

    await service.execute({
      commandId: 'confirm-bridge', commandType: 'confirmComplianceClosed',
      aggregateId: 'wf-bridge', expectedVersion: 6,
      payload: {complianceId: 'c-bridge', note: 'Verified'},
    }, {actor: electrical, serverNow: at('2026-07-20T16:31:00Z')});
    expect(store.read('maintenance_records/m-bridge')).toMatchObject({
      workflowQueueState: 'released', workflowDeferred: false, version: 5,
    });
  });

  test('compliance correction reopens canonical issue progress atomically', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-correction-bridge', 'awaitingCompliance', 5);
    store.seed('compliance_requests/c-correction-bridge', {
      linkedWorkflowId: 'wf-correction-bridge',
      linkedMaintenanceFirestoreId: 'm-correction-bridge',
      originLaneKey: 'elec',
      targetLaneKey: 'oprn',
      status: 'complied',
      currentAttemptId: 'c-correction-bridge_1',
      version: 3,
    });
    store.seed('compliance_attempts/c-correction-bridge_1', {
      complianceRequestId: 'c-correction-bridge',
      attemptNumber: 1,
      accepted: false,
    });
    store.seed('maintenance_records/m-correction-bridge', {
      firestoreId: 'm-correction-bridge',
      assetType: 'furnace',
      assetNumber: 7,
      routedTo: 'instrumentation',
      classification: 'furnaceBurnerLockout',
      status: 'resolved',
      isResolved: true,
      isDeleted: false,
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 4,
      issueAssignedLanes: ['instrumentation', 'electrical'],
      issueAcknowledgedLanes: ['instrumentation', 'electrical'],
      issueCompletedLanes: ['instrumentation', 'electrical'],
      acknowledgedByUid: 'inst-1',
      acknowledgedByName: 'Instrumentation',
      acknowledgedAt: '2026-07-20T15:00:00.000Z',
      burnerAttendedPositions: [2],
      burnerResolutionEvidence: {
        '2': {
          outcome: 'returnedToService',
          actionCodes: ['uvDetectorCleaning'],
        },
      },
      endDate: '2026-07-20T15:30:00.000Z',
      closedByUid: 'inst-1',
      closedByName: 'Instrumentation',
      teamsInvolved: ['instrumentation', 'electrical'],
      actionsJson: '[]',
      resolutionHistoryJson: '[]',
      workflowAggregateId: 'wf-correction-bridge',
      workflowComplianceId: 'c-correction-bridge',
      workflowQueueState: 'awaitingConfirmation',
      workflowDeferred: false,
      version: 8,
    });
    const service = serviceFor(store);

    await service.execute({
      commandId: 'return-correction-bridge',
      commandType: 'returnComplianceForCorrection',
      aggregateId: 'wf-correction-bridge',
      expectedVersion: 5,
      payload: {
        complianceId: 'c-correction-bridge',
        reason: 'Burner evidence requires another attendance pass',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T16:00:00Z')});

    const reopened = store.read('maintenance_records/m-correction-bridge');
    expect(reopened).toMatchObject({
      status: 'open',
      isResolved: false,
      issueLaneSchemaVersion: 1,
      issueLaneRevision: 4,
      issueAssignedLanes: ['instrumentation', 'electrical'],
      issueAcknowledgedLanes: [],
      issueCompletedLanes: [],
      acknowledgedByUid: null,
      acknowledgedByName: null,
      acknowledgedAt: null,
      burnerAttendedPositions: [],
      burnerResolutionEvidence: {},
      workflowQueueState: 'correctionRequired',
      workflowDeferred: true,
      version: 9,
    });
    expect(JSON.parse(reopened.resolutionHistoryJson)).toHaveLength(1);
  });

  test('compliance cannot bind a maintenance ticket from another asset', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-wrong-asset', {
      jobExecutionId: 'wf-wrong-asset', assetTypeKey: 'furnace', assetNumber: 7,
      status: 'inProgress', version: 1,
    });
    store.seed('job_executions/wf-wrong-asset', {
      isCompleted: false, isCancelled: false, isDeleted: false, version: 1,
    });
    store.seed('job_lanes/wf-wrong-asset_elec_1', {
      workflowId: 'wf-wrong-asset', laneKey: 'elec', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-wrong-asset_oprn_1', {
      workflowId: 'wf-wrong-asset', laneKey: 'oprn', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('maintenance_records/m-wrong-asset', {
      firestoreId: 'm-wrong-asset', assetType: 'base', assetNumber: 7,
      status: 'open', isResolved: false, isDeleted: false, version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'raise-wrong-asset', commandType: 'raiseCompliance',
      aggregateId: 'wf-wrong-asset', expectedVersion: 1,
      payload: {
        complianceId: 'c-wrong-asset', originLaneKey: 'elec', targetLaneKey: 'oprn',
        linkedMaintenanceFirestoreId: 'm-wrong-asset',
        title: 'Wrong asset', description: 'Must be rejected.',
        conditionTypeKey: 'manual',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T17:00:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('compliance commands reject a request belonging to another workflow', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-compliance-a', 'inProgress', 2);
    seedWorkflow(store, 'wf-compliance-b', 'inProgress', 4);
    store.seed('compliance_requests/c-cross-workflow', {
      linkedWorkflowId: 'wf-compliance-a', targetLaneKey: 'elec',
      status: 'raised', version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'ack-cross-workflow', commandType: 'acknowledgeCompliance',
      aggregateId: 'wf-compliance-b', expectedVersion: 4,
      payload: {complianceId: 'c-cross-workflow'},
    }, {actor: electrical, serverNow: at('2026-07-20T17:10:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('compliance_requests/c-cross-workflow').status).toBe('raised');
  });

  test('terminal workflows reject every further compliance mutation', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-terminal-compliance', {
      jobExecutionId: 'wf-terminal-compliance-exec', status: 'completed',
      completedAt: '2026-07-20T17:00:00.000Z', version: 8, cancelled: false,
    });
    store.seed('compliance_requests/c-terminal', {
      linkedWorkflowId: 'wf-terminal-compliance', targetLaneKey: 'elec',
      status: 'raised', version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'ack-terminal-compliance', commandType: 'acknowledgeCompliance',
      aggregateId: 'wf-terminal-compliance', expectedVersion: 8,
      payload: {complianceId: 'c-terminal'},
    }, {actor: electrical, serverNow: at('2026-07-20T17:11:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('compliance_requests/c-terminal').status).toBe('raised');
  });

  test.each([
    ['deleted', {isDeleted: true}, 'parent-execution-deleted'],
    ['completed', {isCompleted: true}, 'parent-execution-completed-workflow-open'],
    ['cancelled', {isCancelled: true}, 'parent-execution-cancelled-workflow-open'],
  ])('mutable workflow commands reject a %s parent execution', async (
    _label,
    executionState,
    reasonCode,
  ) => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-terminal-parent-command', 'inProgress', 2);
    store.seed('job_executions/wf-terminal-parent-command-exec', {
      isDeleted: false, isCompleted: false, isCancelled: false, version: 1,
      ...executionState,
    });
    store.seed('job_lanes/wf-terminal-parent-command_elec_1', {
      workflowId: 'wf-terminal-parent-command', laneKey: 'elec',
      status: 'pending', activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-terminal-parent-command_oprn_1', {
      workflowId: 'wf-terminal-parent-command', laneKey: 'oprn',
      status: 'pending', activationGeneration: 1, version: 1,
    });
    const service = serviceFor(store);

    await expect(service.execute({
      commandId: `reject-terminal-lane-${_label}`,
      commandType: 'acknowledgeLane',
      aggregateId: 'wf-terminal-parent-command',
      expectedVersion: 2,
      payload: {laneKey: 'elec'},
    }, {actor: electrical, serverNow: at('2026-07-20T17:11:30Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: expect.objectContaining({reasonCode}),
      });
    expect(store.read('job_lanes/wf-terminal-parent-command_elec_1').status)
      .toBe('pending');

    store.seed('job_lanes/wf-terminal-parent-command_elec_1', {
      workflowId: 'wf-terminal-parent-command', laneKey: 'elec',
      status: 'acknowledged', activationGeneration: 1, version: 1,
    });
    await expect(service.execute({
      commandId: `reject-terminal-compliance-${_label}`,
      commandType: 'raiseCompliance',
      aggregateId: 'wf-terminal-parent-command',
      expectedVersion: 2,
      payload: {
        complianceId: `terminal-compliance-${_label}`,
        originLaneKey: 'elec',
        targetLaneKey: 'oprn',
        title: 'Operations support',
        description: 'This request must not mutate a terminal execution.',
        conditionTypeKey: 'manual',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T17:11:31Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: expect.objectContaining({reasonCode}),
      });
    expect(store.read(`compliance_requests/terminal-compliance-${_label}`))
      .toBeNull();
  });

  test('condition-based compliance cannot be created without maintenance binding and condition reference', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-condition-contract', 'inProgress', 2);
    store.seed('job_lanes/wf-condition-contract_elec_1', {
      workflowId: 'wf-condition-contract', laneKey: 'elec', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-condition-contract_oprn_1', {
      workflowId: 'wf-condition-contract', laneKey: 'oprn', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'raise-condition-no-maintenance', commandType: 'raiseCompliance',
      aggregateId: 'wf-condition-contract', expectedVersion: 2,
      payload: {
        complianceId: 'c-no-maintenance', originLaneKey: 'elec', targetLaneKey: 'oprn',
        title: 'Wait for charge', description: 'Resume when the charge is complete.',
        conditionTypeKey: 'chargeComplete', conditionRef: '42',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T17:12:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    store.seed('maintenance_records/m-condition-contract', {
      firestoreId: 'm-condition-contract', assetType: 'furnace', assetNumber: 7,
      status: 'open', isResolved: false, isDeleted: false,
      workflowQueueState: 'independent', workflowDeferred: false, version: 1,
    });
    await expect(service.execute({
      commandId: 'raise-condition-no-ref', commandType: 'raiseCompliance',
      aggregateId: 'wf-condition-contract', expectedVersion: 2,
      payload: {
        complianceId: 'c-no-ref', originLaneKey: 'elec', targetLaneKey: 'oprn',
        linkedMaintenanceFirestoreId: 'm-condition-contract',
        title: 'Wait for charge', description: 'Resume when the charge is complete.',
        conditionTypeKey: 'chargeComplete',
      },
    }, {actor: electrical, serverNow: at('2026-07-20T17:13:00Z')}))
      .rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('continuation actions revalidate stored maintenance binding', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-binding-check', 'awaitingCompliance', 3);
    store.seed('compliance_requests/c-binding-check', {
      linkedWorkflowId: 'wf-binding-check', linkedMaintenanceFirestoreId: 'm-binding-check',
      originLaneKey: 'elec', targetLaneKey: 'oprn', status: 'acknowledged',
      conditionTypeKey: 'manual', version: 1,
    });
    store.seed('maintenance_records/m-binding-check', {
      firestoreId: 'm-binding-check', workflowAggregateId: 'wf-other',
      workflowComplianceId: 'c-other', workflowQueueState: 'actionable',
      workflowDeferred: false, isDeleted: false, version: 2,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'comply-wrong-binding', commandType: 'markComplianceComplied',
      aggregateId: 'wf-binding-check', expectedVersion: 3,
      payload: {complianceId: 'c-binding-check', note: 'Attempted completion'},
    }, {actor: ops, serverNow: at('2026-07-20T17:14:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('compliance_requests/c-binding-check').status).toBe('acknowledged');
  });

  test('stored lane gates are revalidated against the command workflow', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-gate-owner', 'awaitingCompliance', 5, 'furnace', 7);
    store.seed('job_lanes/wf-foreign_red_1', {
      workflowId: 'wf-foreign', laneKey: 'red', status: 'acknowledged',
      activationGeneration: 1, version: 1,
    });
    store.seed('compliance_requests/c-foreign-gate', {
      linkedWorkflowId: 'wf-gate-owner', originLaneKey: 'elec', targetLaneKey: 'red',
      gatesLaneFirestoreId: 'job_lanes/wf-foreign_red_1', status: 'complied',
      currentAttemptId: 'c-foreign-gate_1', version: 2,
    });
    store.seed('compliance_attempts/c-foreign-gate_1', {
      complianceRequestId: 'c-foreign-gate', attemptNumber: 1, accepted: false,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'close-foreign-gate', commandType: 'confirmComplianceClosed',
      aggregateId: 'wf-gate-owner', expectedVersion: 5,
      payload: {complianceId: 'c-foreign-gate'},
    }, {actor: admin, serverNow: at('2026-07-20T17:15:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('compliance_requests/c-foreign-gate').status).toBe('complied');
  });

  test('lane closure rejects submitted-but-unaccepted canonical modules', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-lane-guard', 'inProgress', 3, 'forceCooler', 4);
    store.seed('maintenance_workflows/wf-lane-guard', {
      jobExecutionId: 'wf-lane-guard-exec', status: 'inProgress', version: 3,
      assetTypeKey: 'forceCooler', assetNumber: 4,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_lanes/wf-lane-guard_mech_1', {
      workflowId: 'wf-lane-guard', jobExecutionId: 'wf-lane-guard-exec',
      laneKey: 'mech', status: 'acknowledged', activationGeneration: 1, version: 2,
    });
    store.seed('job_modules/module-awaiting-acceptance', {
      firestoreId: 'module-awaiting-acceptance',
      jobExecutionFirestoreId: 'wf-lane-guard-exec',
      workflowLaneFirestoreId: 'wf-lane-guard_mech_1',
      laneKey: 'mech', discipline: 'mechanical', status: 'submitted',
      isOpenForWork: false, requiredForClosure: true, isDeleted: false,
      fieldDefinitionsJson: '[]', responsesJson: '[]', version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'close-unaccepted-lane', commandType: 'closeLane',
      aggregateId: 'wf-lane-guard', expectedVersion: 3,
      payload: {laneKey: 'mech'},
    }, {actor: admin, serverNow: at('2026-07-20T18:00:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('job_lanes/wf-lane-guard_mech_1').status).toBe('acknowledged');
  });

  test('workflow finalization preserves original module guard, attestation and audit', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-canonical-close', 'readyForClosure', 5, 'forceCooler', 6);
    store.seed('maintenance_workflows/wf-canonical-close', {
      jobExecutionId: 'wf-canonical-close-exec', status: 'readyForClosure', version: 5,
      assetTypeKey: 'forceCooler', assetNumber: 6,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-canonical-close-exec', {
      firestoreId: 'wf-canonical-close-exec', workflowSchemaVersion: 1,
      version: 2, modulePopulationVersion: 7, modulePopulationSchemaVersion: 1, isCompleted: false,
      metadataJson: JSON.stringify({source: 'test'}),
      teamsInvolved: [], responsesJson: '[]', actionsJson: '[]',
    });
    store.seed('job_lanes/wf-canonical-close_mech_1', {
      workflowId: 'wf-canonical-close', jobExecutionId: 'wf-canonical-close-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 3,
    });
    store.seed('job_modules/module-ready', {
      firestoreId: 'module-ready', jobExecutionFirestoreId: 'wf-canonical-close-exec',
      workflowLaneFirestoreId: 'wf-canonical-close_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'accepted', isOpenForWork: false,
      requiredForClosure: true, isDeleted: false,
      fieldDefinitionsJson: JSON.stringify([{key: 'condition', required: true, type: 'longText'}]),
      responsesJson: JSON.stringify([{key: 'condition', value: 'Acceptable'}]),
      requiresFollowUp: false, pendingIssue: null, version: 2,
    });
    store.seed('equipment_status/forceCooler_6', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'canonical-close', commandType: 'finalizeJob',
      aggregateId: 'wf-canonical-close', expectedVersion: 5, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:10:00Z')});
    expect(receipt.result).toMatchObject({validatedModuleCount: 1});
    expect(receipt.result.closureAttestationHash).toHaveLength(64);
    const execution = store.read('job_executions/wf-canonical-close-exec');
    expect(execution).toMatchObject({isCompleted: true, version: 3});
    expect(JSON.parse(execution.metadataJson).closureAttestation.hash)
      .toBe(receipt.result.closureAttestationHash);
    expect(store.read('audit_logs/server_closure_wf-canonical-close-exec_3'))
      .toMatchObject({workflowAggregateId: 'wf-canonical-close'});
  });

  test.each([
    ['deleted', {isDeleted: true}, 'parent-execution-deleted'],
    ['cancelled', {isCancelled: true}, 'parent-execution-cancelled'],
    ['completed', {isCompleted: true}, 'parent-execution-completed-workflow-open'],
  ])('workflow finalization rejects a %s parent execution without mutation', async (
    _label,
    executionState,
    reasonCode,
  ) => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-terminal-parent', 'readyForClosure', 4, 'forceCooler', 7);
    store.seed('maintenance_workflows/wf-terminal-parent', {
      jobExecutionId: 'wf-terminal-parent-exec', status: 'readyForClosure', version: 4,
      assetTypeKey: 'forceCooler', assetNumber: 7,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-terminal-parent-exec', {
      version: 2, workflowSchemaVersion: 1, isCompleted: false,
      isCancelled: false, isDeleted: false, metadataJson: '{}',
      teamsInvolved: [], responsesJson: '[]', actionsJson: '[]',
      ...executionState,
    });
    store.seed('job_lanes/wf-terminal-parent_mech_1', {
      workflowId: 'wf-terminal-parent', jobExecutionId: 'wf-terminal-parent-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 2,
    });
    const service = serviceFor(store);
    const before = store.entries();

    await expect(service.execute({
      commandId: `reject-${_label}-parent-finalize`, commandType: 'finalizeJob',
      aggregateId: 'wf-terminal-parent', expectedVersion: 4, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:11:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode},
      });

    expect(store.entries()).toEqual(before);
  });

  test('workflow finalization rejects malformed saved execution responses', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-bad-responses', 'readyForClosure', 2, 'forceCooler', 9);
    store.seed('maintenance_workflows/wf-bad-responses', {
      jobExecutionId: 'wf-bad-responses-exec', status: 'readyForClosure', version: 2,
      assetTypeKey: 'forceCooler', assetNumber: 9,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-bad-responses-exec', {
      version: 1, isCompleted: false, responsesJson: '[{"key":"pressure"}]',
      actionsJson: '[]',
    });
    store.seed('job_lanes/wf-bad-responses_mech_1', {
      workflowId: 'wf-bad-responses', jobExecutionId: 'wf-bad-responses-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 1,
    });
    store.seed('equipment_status/forceCooler_9', {
      state: 'underMaintenance', activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1,
    });

    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'reject-bad-saved-responses', commandType: 'finalizeJob',
      aggregateId: 'wf-bad-responses', expectedVersion: 2, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:12:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: expect.objectContaining({
          reasonCode: 'execution-response-payload-invalid',
        }),
      });
    expect(store.read('job_executions/wf-bad-responses-exec').isCompleted)
      .toBe(false);
  });

  test('workflow finalization rejects explicitly null saved execution actions', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-null-actions', 'readyForClosure', 2, 'forceCooler', 11);
    store.seed('maintenance_workflows/wf-null-actions', {
      jobExecutionId: 'wf-null-actions-exec', status: 'readyForClosure', version: 2,
      assetTypeKey: 'forceCooler', assetNumber: 11,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-null-actions-exec', {
      version: 1, isCompleted: false, responsesJson: '[]', actionsJson: null,
    });
    store.seed('job_lanes/wf-null-actions_mech_1', {
      workflowId: 'wf-null-actions', jobExecutionId: 'wf-null-actions-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 1,
    });
    store.seed('equipment_status/forceCooler_11', {
      state: 'underMaintenance', activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1,
    });

    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'reject-null-saved-actions', commandType: 'finalizeJob',
      aggregateId: 'wf-null-actions', expectedVersion: 2, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:12:30Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: expect.objectContaining({
          reasonCode: 'action-payload-invalid',
        }),
      });
    expect(store.read('job_executions/wf-null-actions-exec').isCompleted)
      .toBe(false);
  });

  test('workflow finalization rejects malformed requested responses', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-bad-request', 'readyForClosure', 2, 'forceCooler', 10);
    store.seed('maintenance_workflows/wf-bad-request', {
      jobExecutionId: 'wf-bad-request-exec', status: 'readyForClosure', version: 2,
      assetTypeKey: 'forceCooler', assetNumber: 10,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-bad-request-exec', {
      version: 1, isCompleted: false, responsesJson: '[]', actionsJson: '[]',
    });
    store.seed('job_lanes/wf-bad-request_mech_1', {
      workflowId: 'wf-bad-request', jobExecutionId: 'wf-bad-request-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 1,
    });
    store.seed('equipment_status/forceCooler_10', {
      state: 'underMaintenance', activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1,
    });

    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'reject-bad-request-responses', commandType: 'finalizeJob',
      aggregateId: 'wf-bad-request', expectedVersion: 2,
      payload: {responsesJson: '[{"key":"pressure"}]'},
    }, {actor: admin, serverNow: at('2026-07-20T18:13:00Z')}))
      .rejects.toMatchObject({
        code: 'invalid-argument',
        details: expect.objectContaining({reasonCode: 'response-payload-invalid'}),
      });
    expect(store.read('job_executions/wf-bad-request-exec').isCompleted)
      .toBe(false);
  });

  test('workflow finalization rejects modules still awaiting acceptance', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-close-guard', 'readyForClosure', 5, 'forceCooler', 8);
    store.seed('maintenance_workflows/wf-close-guard', {
      jobExecutionId: 'wf-close-guard-exec', status: 'readyForClosure', version: 5,
      assetTypeKey: 'forceCooler', assetNumber: 8,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_lanes/wf-close-guard_mech_1', {
      workflowId: 'wf-close-guard', jobExecutionId: 'wf-close-guard-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1, version: 3,
    });
    store.seed('job_modules/module-submitted', {
      firestoreId: 'module-submitted', jobExecutionFirestoreId: 'wf-close-guard-exec',
      workflowLaneFirestoreId: 'wf-close-guard_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'submitted', isOpenForWork: false,
      requiredForClosure: true, isDeleted: false,
      fieldDefinitionsJson: '[]', responsesJson: '[]', version: 2,
    });
    store.seed('equipment_status/forceCooler_8', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'guard-finalize', commandType: 'finalizeJob',
      aggregateId: 'wf-close-guard', expectedVersion: 5, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:20:00Z')}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.read('job_executions/wf-close-guard-exec').isCompleted).toBe(false);
  });

  test('governed module reopen atomically reactivates a closed lane', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-reopen-module', 'readyForClosure', 4, 'base', 17);
    store.seed('maintenance_workflows/wf-reopen-module', {
      jobExecutionId: 'wf-reopen-module-exec', status: 'readyForClosure', version: 4,
      assetTypeKey: 'base', assetNumber: 17,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_executions/wf-reopen-module-exec', {
      version: 2, workflowSchemaVersion: 1, isCompleted: false, isCancelled: false,
    });
    store.seed('job_lanes/wf-reopen-module_mech_1', {
      workflowId: 'wf-reopen-module', jobExecutionId: 'wf-reopen-module-exec',
      laneKey: 'mech', status: 'closed', activationGeneration: 1,
      version: 3, progressRevision: 1,
    });
    store.seed('job_modules/module-to-reopen', {
      firestoreId: 'module-to-reopen', jobExecutionFirestoreId: 'wf-reopen-module-exec',
      workflowLaneFirestoreId: 'wf-reopen-module_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'accepted', isOpenForWork: false,
      requiredForClosure: true, isDeleted: false, version: 4,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'reopen-module-command', commandType: 'reopenWorkflowModule',
      aggregateId: 'wf-reopen-module', expectedVersion: 4,
      payload: {moduleFirestoreId: 'module-to-reopen', reason: 'Inspection requires correction'},
    }, {actor: admin, serverNow: at('2026-07-20T18:30:00Z')});
    expect(receipt.result).toMatchObject({laneReactivated: true, laneKey: 'mech'});
    expect(store.read('job_modules/module-to-reopen')).toMatchObject({
      status: 'reopened', isOpenForWork: true, reopenReason: 'Inspection requires correction',
    });
    expect(store.read('job_lanes/wf-reopen-module_mech_1')).toMatchObject({
      status: 'acknowledged', closedAt: null,
    });
    expect(store.read('maintenance_workflows/wf-reopen-module')).toMatchObject({
      status: 'inProgress', version: 5,
    });
  });

  test('business retry after completion returns canonical result without new terminal writes', async () => {
    const store = new MemoryWorkflowStore();
    store.seed('maintenance_workflows/wf-already-complete', {
      jobExecutionId: 'wf-already-complete-exec', status: 'completed', version: 9,
      completedAt: '2026-07-20T17:00:00.000Z', cancelled: false,
      redSuccessorWorkflowId: null,
    });
    store.seed('job_executions/wf-already-complete-exec', {
      version: 5, isCompleted: true,
      metadataJson: JSON.stringify({closureAttestation: {hash: 'a'.repeat(64)}}),
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'new-command-after-complete', commandType: 'finalizeJob',
      aggregateId: 'wf-already-complete', expectedVersion: 9, payload: {},
    }, {actor: admin, serverNow: at('2026-07-20T18:40:00Z')});
    expect(receipt.resultKey).toBe('workflow-already-finalized');
    expect(receipt.result).toMatchObject({
      alreadyCompleted: true,
      executionId: 'wf-already-complete-exec',
      closureAttestationHash: 'a'.repeat(64),
    });
    expect(store.entries().filter(([path]) => path.startsWith('maintenance_workflow_events/')))
      .toHaveLength(0);
  });

  test('lane finalisation derives mandatory lanes and reconciles every existing module', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-derived-lanes', 'pendingLaneClassification', 0, 'base', 21);
    store.seed('job_modules/module-electrical', {
      firestoreId: 'module-electrical', jobExecutionFirestoreId: 'wf-derived-lanes-exec',
      discipline: 'electrical', laneKey: null, workflowLaneFirestoreId: null,
      isDeleted: false, version: 1,
    });
    store.seed('job_modules/module-safety', {
      firestoreId: 'module-safety', jobExecutionFirestoreId: 'wf-derived-lanes-exec',
      discipline: 'safety', laneKey: null, workflowLaneFirestoreId: null,
      isDeleted: false, version: 1,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'derive-lanes', commandType: 'finalizeLaneSet',
      aggregateId: 'wf-derived-lanes', expectedVersion: 0,
      payload: {laneKeys: ['mech']},
    }, {actor: admin, serverNow: at('2026-07-20T19:00:00Z')});
    expect(new Set(receipt.result.laneKeys)).toEqual(new Set(['mech', 'elec', 'shared']));
    expect(new Set(receipt.result.mandatoryLaneKeys)).toEqual(new Set(['elec', 'shared']));
    expect(store.read('job_modules/module-electrical')).toMatchObject({
      laneKey: 'elec', laneActivationGeneration: 1,
      workflowLaneFirestoreId: 'wf-derived-lanes_elec_1',
    });
    expect(store.read('job_modules/module-safety')).toMatchObject({
      laneKey: 'shared', laneActivationGeneration: 1,
      workflowLaneFirestoreId: 'wf-derived-lanes_shared_1',
    });
    expect(store.read('job_executions/wf-derived-lanes-exec').assignedAgencies)
      .toEqual(expect.arrayContaining(['mechanical', 'electrical', 'shared']));
    for (const laneKey of ['mech', 'elec', 'shared']) {
      expect(store.read(`job_lanes/wf-derived-lanes_${laneKey}_1`))
        .toMatchObject({assetTypeKey: 'base', assetNumber: 21});
    }
  });

  test('a lane added during execution retains the parent asset identity', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-added-lane', 'inProgress', 2, 'furnace', 6);
    const service = serviceFor(store);
    await service.execute({
      commandId: 'add-electrical-lane', commandType: 'addLane',
      aggregateId: 'wf-added-lane', expectedVersion: 2,
      payload: {laneKey: 'elec', reason: 'Electrical support is now required'},
    }, {actor: admin, serverNow: at('2026-07-20T19:02:00Z')});
    expect(store.read('job_lanes/wf-added-lane_elec_1')).toMatchObject({
      workflowId: 'wf-added-lane',
      assetTypeKey: 'furnace',
      assetNumber: 6,
      status: 'pending',
    });
  });

  test('a lane with canonical modules cannot be removed', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-no-remove', 'inProgress', 3, 'base', 22);
    store.seed('maintenance_workflows/wf-no-remove', {
      jobExecutionId: 'wf-no-remove-exec', status: 'inProgress', version: 3,
      assetTypeKey: 'base', assetNumber: 22,
      laneSetFinalizedAt: '2026-07-20T00:00:00.000Z', cancelled: false,
    });
    store.seed('job_lanes/wf-no-remove_mech_1', {
      workflowId: 'wf-no-remove', jobExecutionId: 'wf-no-remove-exec',
      laneKey: 'mech', status: 'pending', activationGeneration: 1, version: 1,
    });
    store.seed('job_lanes/wf-no-remove_oprn_1', {
      workflowId: 'wf-no-remove', jobExecutionId: 'wf-no-remove-exec',
      laneKey: 'oprn', status: 'pending', activationGeneration: 1, version: 1,
    });
    store.seed('job_modules/module-protects-lane', {
      firestoreId: 'module-protects-lane', jobExecutionFirestoreId: 'wf-no-remove-exec',
      workflowLaneFirestoreId: 'wf-no-remove_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'notStarted', isOpenForWork: true,
      isDeleted: false, version: 1,
    });
    const service = serviceFor(store);
    await expect(service.execute({
      commandId: 'remove-protected-lane', commandType: 'removeLane',
      aggregateId: 'wf-no-remove', expectedVersion: 3,
      payload: {laneKey: 'mech', reason: 'No longer needed'},
    }, {actor: admin, serverNow: at('2026-07-20T19:10:00Z')}))
      .rejects.toMatchObject({code: 'lane-progress-open'});
  });

  test('terminating a progressed lane with modules creates a new generation and remaps them atomically', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-remap-lane', 'inProgress', 6, 'base', 23);
    store.seed('maintenance_workflows/wf-remap-lane', {
      jobExecutionId: 'wf-remap-lane-exec', status: 'inProgress', version: 6,
      laneSetVersion: 1, laneSetFinalizedAt: '2026-07-20T00:00:00.000Z',
      assetTypeKey: 'base', assetNumber: 23, cancelled: false,
    });
    store.seed('job_executions/wf-remap-lane-exec', {
      version: 2, laneSetVersion: 1, assignedAgencies: ['mechanical'], isCompleted: false,
    });
    store.seed('job_lanes/wf-remap-lane_mech_1', {
      workflowId: 'wf-remap-lane', jobExecutionId: 'wf-remap-lane-exec',
      laneKey: 'mech', status: 'acknowledged', activationGeneration: 1,
      version: 2, progressRevision: 1, displayOrder: 0,
    });
    store.seed('job_modules/module-remapped', {
      firestoreId: 'module-remapped', jobExecutionFirestoreId: 'wf-remap-lane-exec',
      workflowLaneFirestoreId: 'wf-remap-lane_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'inProgress', isOpenForWork: true,
      isDeleted: false, version: 2,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'replace-mech-generation', commandType: 'terminateLane',
      aggregateId: 'wf-remap-lane', expectedVersion: 6,
      payload: {laneKey: 'mech', replacementLaneKey: 'mech', reason: 'Change executing team'},
    }, {actor: admin, serverNow: at('2026-07-20T19:20:00Z')});
    expect(receipt.result).toMatchObject({replacementLaneKey: 'mech', replacementGeneration: 2, remappedModuleCount: 1});
    expect(store.read('job_lanes/wf-remap-lane_mech_1').status).toBe('terminated');
    expect(store.read('job_lanes/wf-remap-lane_mech_2')).toMatchObject({
      status: 'pending', activationGeneration: 2,
      assetTypeKey: 'base', assetNumber: 23,
    });
    expect(store.read('job_modules/module-remapped')).toMatchObject({
      laneKey: 'mech', laneActivationGeneration: 2,
      workflowLaneFirestoreId: 'wf-remap-lane_mech_2',
    });
  });

  test('workflow cancellation projects to execution, lanes, compliance, modules, maintenance, equipment and audit', async () => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-cancel-all', 'inProgress', 7, 'furnace', 24);
    store.seed('maintenance_workflows/wf-cancel-all', {
      jobExecutionId: 'wf-cancel-all-exec', status: 'inProgress', version: 7,
      laneSetVersion: 1, laneSetFinalizedAt: '2026-07-20T00:00:00.000Z',
      assetTypeKey: 'furnace', assetNumber: 24, cancelled: false,
    });
    store.seed('job_executions/wf-cancel-all-exec', {
      version: 3, workflowSchemaVersion: 1, isCompleted: false,
      assignedAgencies: ['mechanical'],
    });
    store.seed('job_lanes/wf-cancel-all_mech_1', {
      workflowId: 'wf-cancel-all', jobExecutionId: 'wf-cancel-all-exec',
      laneKey: 'mech', status: 'acknowledged', activationGeneration: 1, version: 2,
    });
    store.seed('job_modules/module-cancelled', {
      firestoreId: 'module-cancelled', jobExecutionFirestoreId: 'wf-cancel-all-exec',
      workflowLaneFirestoreId: 'wf-cancel-all_mech_1', laneKey: 'mech',
      discipline: 'mechanical', status: 'inProgress', isOpenForWork: true,
      isDeleted: false, version: 2,
    });
    store.seed('compliance_requests/compliance-cancelled', {
      linkedWorkflowId: 'wf-cancel-all', linkedMaintenanceFirestoreId: 'maintenance-cancelled',
      originLaneKey: 'mech', targetLaneKey: 'mech', status: 'acknowledged', version: 2,
    });
    store.seed('maintenance_records/maintenance-cancelled', {
      workflowAggregateId: 'wf-cancel-all', workflowComplianceId: 'compliance-cancelled',
      workflowQueueState: 'deferred', workflowDeferred: true, version: 2,
    });
    store.seed('equipment_status/furnace_24', {
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 4,
    });
    const service = serviceFor(store);
    const receipt = await service.execute({
      commandId: 'cancel-everything', commandType: 'cancelWorkflow',
      aggregateId: 'wf-cancel-all', expectedVersion: 7,
      payload: {reason: 'Work withdrawn after engineering review'},
    }, {actor: admin, serverNow: at('2026-07-20T19:30:00Z')});
    expect(receipt.resultKey).toBe('workflow-cancelled');
    expect(store.read('maintenance_workflows/wf-cancel-all')).toMatchObject({status: 'cancelled', cancelled: true});
    expect(store.read('job_executions/wf-cancel-all-exec')).toMatchObject({isCancelled: true, assignedAgencies: []});
    expect(store.read('job_lanes/wf-cancel-all_mech_1').status).toBe('terminated');
    expect(store.read('compliance_requests/compliance-cancelled').status).toBe('cancelled');
    expect(store.read('job_modules/module-cancelled')).toMatchObject({isDeleted: true, isOpenForWork: false});
    expect(store.read('maintenance_records/maintenance-cancelled')).toMatchObject({workflowQueueState: 'released', workflowDeferred: false});
    expect(store.read('equipment_status/furnace_24').state).toBe('available');
    expect(store.read('audit_logs/workflow_cancel_wf-cancel-all_8')).toMatchObject({workflowAggregateId: 'wf-cancel-all'});
  });

  test.each([
    ['deleted', {isDeleted: true}, 'parent-execution-deleted'],
    ['completed', {isCompleted: true}, 'parent-execution-completed'],
    ['cancelled', {isCancelled: true}, 'parent-execution-cancelled-workflow-open'],
  ])('workflow cancellation rejects a %s parent execution without mutation', async (
    _label,
    executionState,
    reasonCode,
  ) => {
    const store = new MemoryWorkflowStore();
    seedWorkflow(store, 'wf-cancel-terminal-parent', 'inProgress', 3, 'base', 22);
    store.seed('maintenance_workflows/wf-cancel-terminal-parent', {
      jobExecutionId: 'wf-cancel-terminal-parent-exec', status: 'inProgress', version: 3,
      assetTypeKey: 'base', assetNumber: 22, cancelled: false,
    });
    store.seed('job_executions/wf-cancel-terminal-parent-exec', {
      version: 2, isCompleted: false, isCancelled: false, isDeleted: false,
      ...executionState,
    });
    const service = serviceFor(store);
    const before = store.entries();

    await expect(service.execute({
      commandId: `reject-${_label}-parent-cancel`, commandType: 'cancelWorkflow',
      aggregateId: 'wf-cancel-terminal-parent', expectedVersion: 3,
      payload: {reason: 'Lifecycle consistency check'},
    }, {actor: admin, serverNow: at('2026-07-20T19:31:00Z')}))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode},
      });

    expect(store.entries()).toEqual(before);
  });

});
