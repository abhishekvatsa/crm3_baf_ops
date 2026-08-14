import test from 'node:test';
import assert from 'node:assert/strict';

import {
  assertCustody,
  buildReconciliationPlan,
  parseArgs,
} from './governed_asset_identity_projection_reconciliation.mjs';

const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const WRITE_CONFIRMATION = 'RECONCILE_GOVERNED_CUSTOM_PROJECTIONS';

function asset({
  id = 'asset-furnace-3',
  assetClassId = 'class-furnace',
  assetNumber = 3,
} = {}) {
  return {
    id,
    data: {
      assetInstanceId: id,
      assetClassId,
      assetNumber,
      status: 'active',
      isDeleted: false,
    },
  };
}

function hierarchyReference({
  schemaVersion = 2,
  scope = 'definition',
  assetClassId = 'class-furnace',
  assetInstanceId = null,
  assetNumber = 3,
} = {}) {
  return {
    schemaVersion,
    scope,
    assetClassId,
    assetClassCode: 'FUR',
    assetClassName: 'Furnace',
    nodeId: 'node-shell',
    nodeVersion: 1,
    nodeName: 'Shell',
    assetInstanceId,
    assetNumber,
  };
}

function execution({
  id = 'execution-1',
  reference = hierarchyReference(),
  assetClassId,
  assetInstanceId,
} = {}) {
  return {
    id,
    data: {
      assetType: 'governedCustom',
      assetNumber: 3,
      metadataJson: JSON.stringify({
        source: 'server_governed_published_template_assignment',
        jobTemplateSnapshot: {
          assetType: 'governedCustom',
          assetHierarchyRefJson: JSON.stringify(reference),
        },
      }),
      ...(assetClassId == null ? {} : {assetClassId}),
      ...(assetInstanceId == null ? {} : {assetInstanceId}),
      updatedAt: '2026-08-14T00:00:00.000Z',
    },
  };
}

function workflow({
  id = 'workflow-1',
  assetClassId,
  assetInstanceId,
  status = 'assigned',
  activeRedWork = false,
  awaitingPreparation = false,
} = {}) {
  return {
    id,
    data: {
      jobExecutionId: 'execution-1',
      assetTypeKey: 'governedCustom',
      assetNumber: 3,
      status,
      activeRedWork,
      awaitingPreparation,
      cancelled: false,
      workflowSchemaVersion: 1,
      laneSetVersion: 0,
      version: 4,
      createdAt: '2026-08-14T00:00:00.000Z',
      updatedAt: '2026-08-14T00:00:00.000Z',
      ...(assetClassId == null ? {} : {assetClassId}),
      ...(assetInstanceId == null ? {} : {assetInstanceId}),
    },
  };
}

function legacyEquipment(overrides = {}) {
  return {
    id: 'governedCustom_3',
    data: {
      assetTypeKey: 'governedCustom',
      assetNumber: 3,
      previousState: 'inService',
      state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 5,
      updatedAt: '2026-08-14T00:00:00.000Z',
      ...overrides,
    },
  };
}

function currentEquipment() {
  return {
    id: 'governedCustom_class-furnace_asset-furnace-3',
    data: {
      ...legacyEquipment().data,
      assetClassId: 'class-furnace',
      assetInstanceId: 'asset-furnace-3',
    },
  };
}

function inventory(overrides = {}) {
  return {
    maintenanceWorkflows: [workflow()],
    jobExecutions: [execution()],
    assetInstances: [asset()],
    equipmentStatus: [legacyEquipment()],
    ...overrides,
  };
}

function applyPlanInMemory(source, plan) {
  const collections = {
    maintenance_workflows: new Map(
      source.maintenanceWorkflows.map((row) => [row.id, structuredClone(row.data)]),
    ),
    job_executions: new Map(
      source.jobExecutions.map((row) => [row.id, structuredClone(row.data)]),
    ),
    asset_instances: new Map(
      source.assetInstances.map((row) => [row.id, structuredClone(row.data)]),
    ),
    equipment_status: new Map(
      source.equipmentStatus.map((row) => [row.id, structuredClone(row.data)]),
    ),
  };
  for (const item of plan.mutations) {
    const [collection, id] = item.path.split('/');
    if (item.operation === 'delete') {
      collections[collection].delete(id);
      continue;
    }
    const data = structuredClone(item.data);
    for (const [key, value] of Object.entries(data)) {
      if (value === '$SERVER_TIMESTAMP') data[key] = '2026-08-15T00:00:00.000Z';
    }
    if (item.operation === 'create') collections[collection].set(id, data);
    else collections[collection].set(id, {
      ...collections[collection].get(id),
      ...data,
    });
  }
  const rows = (name) => [...collections[name]].map(([id, data]) => ({id, data}));
  return {
    maintenanceWorkflows: rows('maintenance_workflows'),
    jobExecutions: rows('job_executions'),
    assetInstances: rows('asset_instances'),
    equipmentStatus: rows('equipment_status'),
  };
}

test('legacy definition-scoped projections produce an exact atomic plan', () => {
  const source = inventory();
  const plan = buildReconciliationPlan(source);

  assert.equal(plan.decision, 'READY_TO_RECONCILE');
  assert.deepEqual(plan.blockers, []);
  assert.equal(plan.inventory.legacyWorkflowUpdateCount, 1);
  assert.equal(plan.inventory.executionUpdateCount, 1);
  assert.equal(plan.inventory.equipmentCreateCount, 1);
  assert.equal(plan.inventory.legacyEquipmentDeleteCount, 1);
  assert.deepEqual(
    plan.mutations.map((item) => `${item.operation}:${item.path}`),
    [
      'delete:equipment_status/governedCustom_3',
      'create:equipment_status/governedCustom_class-furnace_asset-furnace-3',
      'update:job_executions/execution-1',
      'update:maintenance_workflows/workflow-1',
    ],
  );
  const workflowUpdate = plan.mutations.find(
    (item) => item.path === 'maintenance_workflows/workflow-1',
  );
  assert.equal(workflowUpdate.data.assetClassId, 'class-furnace');
  assert.equal(workflowUpdate.data.assetInstanceId, 'asset-furnace-3');
  assert.equal(workflowUpdate.data.version, 5);

  const readback = buildReconciliationPlan(applyPlanInMemory(source, plan));
  assert.equal(readback.decision, 'CLEAN');
  assert.equal(readback.mutations.length, 0);
});

test('installed-component evidence selects its exact physical asset', () => {
  const first = asset();
  const second = asset({id: 'asset-furnace-3-replacement'});
  const reference = hierarchyReference({
    scope: 'installedComponent',
    assetInstanceId: first.id,
  });
  const plan = buildReconciliationPlan(inventory({
    assetInstances: [first, second],
    jobExecutions: [execution({reference})],
  }));

  assert.equal(plan.decision, 'READY_TO_RECONCILE');
  assert.equal(
    plan.mutations.find((item) => item.path === 'maintenance_workflows/workflow-1')
      .data.assetInstanceId,
    first.id,
  );
});

test('definition evidence fails closed when class and number are ambiguous', () => {
  const plan = buildReconciliationPlan(inventory({
    assetInstances: [asset(), asset({id: 'asset-furnace-3-replacement'})],
  }));

  assert.equal(plan.decision, 'HOLD_AMBIGUOUS_OR_MALFORMED_EVIDENCE');
  assert.ok(plan.blockers.some((item) => item.code === 'asset-instance-ambiguous'));
});

test('partial workflow identity and mismatched legacy counters both block', () => {
  const partial = buildReconciliationPlan(inventory({
    maintenanceWorkflows: [workflow({assetClassId: 'class-furnace'})],
  }));
  assert.ok(partial.blockers.some((item) => item.code === 'partial-workflow-identity'));

  const counters = buildReconciliationPlan(inventory({
    equipmentStatus: [legacyEquipment({activeNonRedMaintenanceCount: 0})],
  }));
  assert.ok(counters.blockers.some((item) => item.code === 'legacy-equipment-facts-mismatch'));
});

test('a different malformed strict-projection field blocks completion', () => {
  const malformedStatus = workflow();
  malformedStatus.data.status = 'active';
  const statusPlan = buildReconciliationPlan(inventory({
    maintenanceWorkflows: [malformedStatus],
  }));
  assert.ok(statusPlan.blockers.some((item) => item.code === 'invalid-workflow-status'));

  const malformedTime = legacyEquipment({updatedAt: 'not-a-time'});
  const timePlan = buildReconciliationPlan(inventory({
    equipmentStatus: [malformedTime],
  }));
  assert.ok(timePlan.blockers.some((item) => item.code === 'invalid-timestamp'));
});

test('one execution cannot authorize identity for several workflows', () => {
  const second = workflow({id: 'workflow-2'});
  const plan = buildReconciliationPlan(inventory({
    maintenanceWorkflows: [workflow(), second],
    equipmentStatus: [legacyEquipment({activeNonRedMaintenanceCount: 2})],
  }));
  assert.ok(
    plan.blockers.some(
      (item) => item.code === 'job-execution-linked-by-several-workflows',
    ),
  );
});

test('a current exact projection is clean and a stale current counter blocks', () => {
  const currentWorkflow = workflow({
    assetClassId: 'class-furnace',
    assetInstanceId: 'asset-furnace-3',
  });
  const currentExecution = execution({
    assetClassId: 'class-furnace',
    assetInstanceId: 'asset-furnace-3',
  });
  const clean = buildReconciliationPlan(inventory({
    maintenanceWorkflows: [currentWorkflow],
    jobExecutions: [currentExecution],
    equipmentStatus: [currentEquipment()],
  }));
  assert.equal(clean.decision, 'CLEAN');

  const stale = currentEquipment();
  stale.data.activeNonRedMaintenanceCount = 0;
  const blocked = buildReconciliationPlan(inventory({
    maintenanceWorkflows: [currentWorkflow],
    jobExecutions: [currentExecution],
    equipmentStatus: [stale],
  }));
  assert.ok(blocked.blockers.some((item) => item.code === 'current-equipment-facts-mismatch'));
});

test('production custody separates read-only preflight from exact-main apply', () => {
  const source = {
    commit: 'a'.repeat(40),
    tree: 'b'.repeat(40),
    branch: 'main',
    originMainCommit: 'a'.repeat(40),
    cleanWorktree: true,
    unexpectedChanges: [],
  };
  const base = {
    project: PRODUCTION_PROJECT,
    output: 'evidence.json',
    expectedSourceCommit: source.commit,
    expectedSourceTree: source.tree,
    confirmProject: PRODUCTION_PROJECT,
  };
  assert.doesNotThrow(() => assertCustody({
    ...base,
    mode: 'dry-run',
    allowProductionReadOnly: true,
  }, {}, source));
  assert.throws(() => assertCustody({...base, mode: 'apply'}, {}, source));

  const token = `${WRITE_CONFIRMATION}:${PRODUCTION_PROJECT}:${source.commit}`;
  assert.doesNotThrow(() => assertCustody({
    ...base,
    mode: 'apply',
    allowProductionWrite: true,
    confirmMutation: WRITE_CONFIRMATION,
  }, {CRM3_GOVERNED_ASSET_IDENTITY_WRITE_TOKEN: token}, source));
  assert.throws(() => assertCustody({
    ...base,
    mode: 'apply',
    allowProductionWrite: true,
    confirmMutation: WRITE_CONFIRMATION,
  }, {CRM3_GOVERNED_ASSET_IDENTITY_WRITE_TOKEN: token}, {
    ...source,
    branch: 'codex/not-main',
  }));
});

test('argument parser defaults to dry-run and rejects unknown modes', () => {
  assert.deepEqual(parseArgs(['--project', 'demo', '--output', 'out.json']), {
    mode: 'dry-run',
    project: 'demo',
    output: 'out.json',
  });
  assert.throws(() => parseArgs(['--mode', 'unsafe']), /dry-run or apply/);
});
