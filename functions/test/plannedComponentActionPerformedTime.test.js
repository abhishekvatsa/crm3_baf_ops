'use strict';

const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  prepareBurnerBlockLifecycleWritePlan,
  applyBurnerBlockLifecycleWritePlan,
} = require('../lib/maintenanceWorkflow/burnerBlockLifecycle');
const {
  prepareUvDetectorLifecycleWritePlan,
  applyUvDetectorLifecycleWritePlan,
} = require('../lib/maintenanceWorkflow/uvDetectorLifecycle');

// Produced by the real Flutter sheet/date/time pickers in
// test/action_bottom_sheet_performed_time_test.dart. Only random action IDs
// are replaced by stable specimen IDs; timestamps and physical fields are not.
const specimens = require('./fixtures/planned_component_action_performed_times.json');

describe.each([
  ['burner', prepareBurnerBlockLifecycleWritePlan, applyBurnerBlockLifecycleWritePlan, 'mechanical'],
  ['uv', prepareUvDetectorLifecycleWritePlan, applyUvDetectorLifecycleWritePlan, 'instrumentation'],
])('actual planned-action UI time → %s lifecycle', (kind, prepare, apply, discipline) => {
  test.each([['newer', 'older'], ['older', 'newer']])(
    'recording order %s → %s retains both installations and selects physical newer',
    async (first, second) => {
      const store = new MemoryWorkflowStore();
      const ref = specimens[`${kind}-older`].assetHierarchyRef;
      store.seed(`asset_classes/${ref.assetClassId}`, {
        schemaVersion: 1, assetClassId: ref.assetClassId,
        code: ref.assetClassCode, name: ref.assetClassName,
        legacyAssetTypeKey: 'furnace', status: 'active',
      });
      store.seed(`asset_instances/${ref.assetInstanceId}`, {
        schemaVersion: 1, assetInstanceId: ref.assetInstanceId,
        assetClassId: ref.assetClassId, assetClassCode: ref.assetClassCode,
        assetClassName: ref.assetClassName, assetNumber: ref.assetNumber,
        name: ref.assetInstanceName, status: 'active', version: ref.assetInstanceVersion,
      });
      store.seed(`asset_hierarchy_nodes/${ref.nodeId}`, {
        schemaVersion: 1, nodeId: ref.nodeId, assetClassId: ref.assetClassId,
        name: ref.nodeName, hierarchyPath: ref.hierarchyPath,
        nodeType: 'component', componentTag: null,
        status: 'active', version: ref.nodeVersion,
      });
      for (const [index, label] of [first, second].entries()) {
        const row = specimens[`${kind}-${label}`];
        const recordingTime = `2026-09-13T0${8 + index}:00:00.000Z`;
        await store.runTransaction(async (tx) => {
          const plan = await prepare({
            tx, sourceType: 'workflowPlannedJob', sourceId: `execution-${label}`,
            assetType: 'furnace', assetNumber: 7,
            actionSources: [{sourceModuleId: 'module-1', discipline,
              actionsJson: JSON.stringify([row])}],
            completedAt: recordingTime, recordedAt: recordingTime,
            completedBy: {uid: 'supervisor', name: 'Supervisor', roles: new Set(['shiftSupervisor'])},
          });
          apply(tx, plan);
        });
      }
      const history = store.entries().filter(([path]) => path.includes('_lifecycle_events/'));
      expect(history).toHaveLength(2);
      for (const label of ['older', 'newer']) {
        const event = history.find(([, row]) => row.sourceId === `execution-${label}`)[1];
        expect(event.actionPerformedAt).toBe(specimens[`${kind}-${label}`].createdAt);
        expect(event.recordedAt).not.toBe(event.actionPerformedAt);
        expect(event.sourceActionId).toBe(specimens[`${kind}-${label}`].id);
      }
      const current = store.entries().find(([path]) => path.includes('_lifecycle_current/'))[1];
      expect(current.sourceId).toBe('execution-newer');
      expect(current.actionPerformedAt).toBe(specimens[`${kind}-newer`].createdAt);
    },
  );
});
