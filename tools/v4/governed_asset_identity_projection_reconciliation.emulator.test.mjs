import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

import {
  applyPlan,
  buildReconciliationPlan,
  loadInventory,
} from './governed_asset_identity_projection_reconciliation.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);
const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));
const PROJECT_ID = 'demo-governed-asset-identity';
const COLLECTIONS = [
  'maintenance_workflows',
  'job_executions',
  'asset_instances',
  'equipment_status',
  'governed_migration_audits',
  'governed_migration_contracts',
];

if (process.env.FIRESTORE_EMULATOR_HOST == null) {
  throw new Error('FIRESTORE_EMULATOR_HOST is required for this test.');
}

const app = admin.initializeApp({projectId: PROJECT_ID}, `gaip-test-${Date.now()}`);
const db = app.firestore();
const timestamp = admin.firestore.Timestamp.fromDate(
  new Date('2026-08-14T00:00:00.000Z'),
);
const source = {
  commit: 'a'.repeat(40),
  tree: 'b'.repeat(40),
};

async function clearFirestore() {
  for (const collection of COLLECTIONS) {
    await db.recursiveDelete(db.collection(collection));
  }
}

function hierarchyReference() {
  return {
    schemaVersion: 2,
    scope: 'definition',
    assetClassId: 'class-furnace',
    assetClassCode: 'FUR',
    assetClassName: 'Furnace',
    nodeId: 'node-shell',
    nodeVersion: 1,
    nodeName: 'Shell',
    assetInstanceId: null,
    assetNumber: 3,
  };
}

async function seedLegacyProjection() {
  const batch = db.batch();
  batch.set(db.doc('asset_instances/asset-furnace-3'), {
    assetInstanceId: 'asset-furnace-3',
    assetClassId: 'class-furnace',
    assetNumber: 3,
    status: 'active',
    isDeleted: false,
  });
  batch.set(db.doc('job_executions/execution-1'), {
    assetType: 'governedCustom',
    assetNumber: 3,
    metadataJson: JSON.stringify({
      source: 'server_governed_published_template_assignment',
      jobTemplateSnapshot: {
        assetType: 'governedCustom',
        assetHierarchyRefJson: JSON.stringify(hierarchyReference()),
      },
    }),
    updatedAt: timestamp,
  });
  batch.set(db.doc('maintenance_workflows/workflow-1'), {
    jobExecutionId: 'execution-1',
    assetTypeKey: 'governedCustom',
    assetNumber: 3,
    status: 'assigned',
    activeRedWork: false,
    awaitingPreparation: false,
    cancelled: false,
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    version: 4,
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  batch.set(db.doc('equipment_status/governedCustom_3'), {
    assetTypeKey: 'governedCustom',
    assetNumber: 3,
    previousState: 'inService',
    state: 'underMaintenance',
    activeNonRedMaintenanceCount: 1,
    activeRedWorkCount: 0,
    awaitingPreparationCount: 0,
    version: 5,
    updatedAt: timestamp,
  });
  await batch.commit();
}

test.beforeEach(clearFirestore);
test.after(async () => {
  await clearFirestore();
  await app.delete();
});

test('applies, audits, verifies, and replays as a clean migration', async () => {
  await seedLegacyProjection();
  const plan = buildReconciliationPlan(await loadInventory(db));
  assert.equal(plan.decision, 'READY_TO_RECONCILE');

  const result = await applyPlan({
    db,
    fieldValue: admin.firestore.FieldValue,
    plan,
    source,
  });
  assert.equal(result.readback.decision, 'CLEAN');

  const legacy = await db.doc('equipment_status/governedCustom_3').get();
  const current = await db.doc(
    'equipment_status/governedCustom_class-furnace_asset-furnace-3',
  ).get();
  const workflow = await db.doc('maintenance_workflows/workflow-1').get();
  const execution = await db.doc('job_executions/execution-1').get();
  const audits = await db.collection('governed_migration_audits').get();
  const marker = await db.doc(
    'governed_migration_contracts/governed_asset_identity_v1',
  ).get();

  assert.equal(legacy.exists, false);
  assert.equal(current.exists, true);
  assert.equal(current.data().assetClassId, 'class-furnace');
  assert.equal(current.data().assetInstanceId, 'asset-furnace-3');
  assert.equal(current.data().activeNonRedMaintenanceCount, 1);
  assert.equal(workflow.data().assetInstanceId, 'asset-furnace-3');
  assert.equal(workflow.data().version, 5);
  assert.equal(execution.data().assetInstanceId, 'asset-furnace-3');
  assert.equal(audits.size, 4);
  assert.equal(marker.data().status, 'complete');
  const migrationId = marker.data().migrationId;

  const replayPlan = buildReconciliationPlan(await loadInventory(db));
  assert.equal(replayPlan.decision, 'CLEAN');
  const replay = await applyPlan({
    db,
    fieldValue: admin.firestore.FieldValue,
    plan: replayPlan,
    source,
  });
  assert.equal(replay.replay, true);
  assert.equal(replay.migrationId, migrationId);
  assert.equal((await db.collection('governed_migration_audits').get()).size, 4);
  assert.equal(
    (await db.doc('governed_migration_contracts/governed_asset_identity_v1').get())
      .data().migrationId,
    migrationId,
  );
});

test('ambiguous registry evidence performs no writes', async () => {
  await seedLegacyProjection();
  await db.doc('asset_instances/asset-furnace-3-replacement').set({
    assetInstanceId: 'asset-furnace-3-replacement',
    assetClassId: 'class-furnace',
    assetNumber: 3,
    status: 'active',
    isDeleted: false,
  });
  const plan = buildReconciliationPlan(await loadInventory(db));
  assert.equal(plan.decision, 'HOLD_AMBIGUOUS_OR_MALFORMED_EVIDENCE');
  await assert.rejects(
    applyPlan({db, fieldValue: admin.firestore.FieldValue, plan, source}),
    /blocked plan/,
  );
  assert.equal((await db.doc('equipment_status/governedCustom_3').get()).exists, true);
  assert.equal((await db.collection('governed_migration_audits').get()).empty, true);
});
