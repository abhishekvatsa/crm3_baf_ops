const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const admin = {uid: 'admin', name: 'Admin', roles: new Set(['admin'])};
const ops = {uid: 'ops', name: 'Operations', roles: new Set(['operations'])};
const at = new Date('2026-09-21T04:00:00.000Z');
const context = (actor = admin) => ({actor, serverNow: at});
const oldIds = {assetClassId: 'retired-furnace-class', assetInstanceId: 'retired-furnace-7'};
const newIds = {assetClassId: 'current-furnace-class', assetInstanceId: 'current-furnace-7'};

function fixture() {
  const store = new MemoryWorkflowStore();
  for (const actor of [admin, ops]) store.seed(`users/${actor.uid}`, {isApproved: true, name: actor.name, roles: [...actor.roles]});
  for (const [ids, status, version] of [[oldIds, 'retired', 5], [newIds, 'active', 2]]) {
    store.seed(`asset_classes/${ids.assetClassId}`, {schemaVersion: 1, assetClassId: ids.assetClassId,
      legacyAssetTypeKey: 'furnace', status, code: 'FR', name: 'Furnace', version: 2});
    store.seed(`asset_instances/${ids.assetInstanceId}`, {schemaVersion: 1, ...ids, assetNumber: 7,
      name: status === 'retired' ? 'Retired Furnace 7' : 'Replacement Furnace 7', status, version,
      serviceState: status === 'retired' ? 'outOfService' : 'inService'});
  }
  store.seed('equipment_status/furnace_7', {assetTypeKey: 'furnace', assetNumber: 7, ...oldIds,
    state: 'inService', previousState: 'available', version: 12, activeNonRedMaintenanceCount: 0,
    activeRedWorkCount: 0, awaitingPreparationCount: 0, inServiceSince: '2026-08-01T04:00:00.000Z',
    availableSince: null, lastTransitionAt: '2026-08-01T04:00:00.000Z', lastTransitionByUid: 'old-operator',
    lastTransitionByName: 'Original operator', transitionTrigger: 'operationsDeploy:old',
    activeExecutionIdsJson: '["old-completed-job"]', retainedOperatorNote: 'Old subject assessment'});
  store.seed(`asset_operational_conditions/${oldIds.assetInstanceId}`, {...oldIds,
    active: true, condition: 'unfit', reason: 'Retired refractory restriction remains unresolved', version: 4});
  store.seed(`asset_operational_conditions/${newIds.assetInstanceId}`, {...newIds,
    active: true, condition: 'down', reason: 'Replacement commissioning restriction', version: 1});
  store.seed('job_templates/template-1', {firestoreId: 'template-1', version: 1,
    jobName: 'Furnace planned maintenance', applicableAssetType: 'furnace', assignedAgencies: ['mechanical'],
    assetHierarchyRefJson: null, isActive: true, isDeprecated: false, isDeleted: false});
  return {store, service: new MaintenanceWorkflowCommandService(store)};
}

function rebind(overrides = {}) {
  return {commandId: 'reviewed-rebinding', commandType: 'reconcileEquipment', aggregateId: 'equipment_furnace_7',
    expectedVersion: 12, payload: {assetTypeKey: 'furnace', assetNumber: 7, ...newIds,
      registryRebinding: {previousAssetClassId: oldIds.assetClassId, previousAssetInstanceId: oldIds.assetInstanceId,
        expectedPreviousAssetVersion: 5, expectedTargetAssetVersion: 2,
        reason: 'Reviewed retired Furnace replacement and current registry identity.'}}, ...overrides};
}

const job = {commandId: 'assign-replacement-job', commandType: 'createLegacyWorkflowJob', aggregateId: 'replacement-job',
  expectedVersion: 0, payload: {assignmentSchemaVersion: 2, executionId: 'replacement-job',
    templateFirestoreId: 'template-1', expectedTemplateVersion: 1, ...newIds}};

test('reviewed rebinding preserves old evidence, enables replacement work, and replays without moving later state', async () => {
  const {store, service} = fixture();
  await expect(service.execute(job, context())).rejects.toMatchObject({details: {reasonCode: 'equipment-projection-identity-mismatch'}});
  const before = store.read('equipment_status/furnace_7');
  const oldCondition = store.read(`asset_operational_conditions/${oldIds.assetInstanceId}`);
  const targetCondition = store.read(`asset_operational_conditions/${newIds.assetInstanceId}`);
  const accepted = await service.execute(rebind(), context());
  expect(accepted).toMatchObject({resultKey: 'equipment-reconciled', aggregateVersion: 13,
    result: {rebound: true, ...newIds, auditId: 'reviewed-rebinding', state: 'available'}});
  const projection = store.read('equipment_status/furnace_7');
  expect(projection).toMatchObject({...newIds, state: 'available', version: 13, availableSince: null,
    inServiceSince: null, lastTransitionAt: null, lastTransitionByUid: null,
    activeNonRedMaintenanceCount: 0, activeRedWorkCount: 0, awaitingPreparationCount: 0});
  expect(projection.activeExecutionIdsJson).toBeUndefined();
  expect(projection.retainedOperatorNote).toBeUndefined();
  const evidence = store.read('maintenance_workflow_events/reviewed-rebinding').payload.registryRebinding;
  expect(JSON.parse(evidence.previousProjectionJson)).toEqual(before);
  expect(JSON.parse(evidence.replacementProjectionJson)).toEqual(projection);
  expect(evidence)
    .toMatchObject({previousAssetClassId: oldIds.assetClassId,
      previousAssetInstanceId: oldIds.assetInstanceId, assetClassId: newIds.assetClassId,
      assetInstanceId: newIds.assetInstanceId, reason: rebind().payload.registryRebinding.reason});
  expect(store.read(`asset_operational_conditions/${oldIds.assetInstanceId}`)).toEqual(oldCondition);
  expect(store.read(`asset_operational_conditions/${newIds.assetInstanceId}`)).toEqual(targetCondition);
  await expect(service.execute(job, context())).resolves.toMatchObject({resultKey: 'workflow-job-created'});
  expect(store.read('equipment_status/furnace_7')).toMatchObject({...newIds, activeNonRedMaintenanceCount: 1});
  const later = store.entries();
  await expect(service.execute(rebind(), context())).resolves.toEqual(accepted);
  expect(store.entries()).toEqual(later);
});

test.each(['ordinary-reconcile', 'ordinary-deploy', 'unprivileged-rebind'])(
  '%s cannot silently transfer the retired projection', async (mode) => {
    const {store, service} = fixture();
    const request = rebind();
    if (mode !== 'unprivileged-rebind') delete request.payload.registryRebinding;
    if (mode === 'ordinary-deploy') request.commandType = 'deployEquipment';
    const before = store.entries();
    await expect(service.execute(request, context(mode === 'unprivileged-rebind' ? ops : admin))).rejects.toBeDefined();
    expect(store.entries()).toEqual(before);
  });

test.each(['old-not-retired', 'stale-old-version', 'stale-target-version', 'stale-status-version',
  'wrong-prior-id', 'missing-prior-id', 'target-retired', 'ambiguous-class', 'ambiguous-instance', 'blank-reason'])(
  'reviewed rebinding rejects %s without writes', async (mode) => {
    const {store, service} = fixture(); const request = rebind();
    const revise = (path, patch) => store.seed(path, {...store.read(path), ...patch});
    if (mode === 'old-not-retired') revise(`asset_instances/${oldIds.assetInstanceId}`, {status: 'active'});
    if (mode === 'stale-old-version') request.payload.registryRebinding.expectedPreviousAssetVersion--;
    if (mode === 'stale-target-version') request.payload.registryRebinding.expectedTargetAssetVersion--;
    if (mode === 'stale-status-version') request.expectedVersion--;
    if (mode === 'wrong-prior-id') request.payload.registryRebinding.previousAssetInstanceId = 'different-old-furnace';
    if (mode === 'missing-prior-id') revise('equipment_status/furnace_7', {assetInstanceId: null});
    if (mode === 'target-retired') revise(`asset_instances/${newIds.assetInstanceId}`, {status: 'retired'});
    if (mode === 'ambiguous-class') store.seed('asset_classes/competing-class',
      {...store.read(`asset_classes/${newIds.assetClassId}`), assetClassId: 'competing-class'});
    if (mode === 'ambiguous-instance') store.seed('asset_instances/competing-furnace',
      {...store.read(`asset_instances/${newIds.assetInstanceId}`), assetInstanceId: 'competing-furnace'});
    if (mode === 'blank-reason') request.payload.registryRebinding.reason = ' ';
    const before = store.entries(); await expect(service.execute(request, context())).rejects.toBeDefined();
    expect(store.entries()).toEqual(before);
  });

test.each(['old-subject', 'unbound', 'partial-identity', 'third-subject'])(
  'active %s workflow blocks reviewed rebinding without transferring work', async (mode) => {
    const {store, service} = fixture();
    const identity = mode === 'unbound' ? {} : mode === 'partial-identity' ? {assetClassId: oldIds.assetClassId} :
      mode === 'third-subject' ? {assetClassId: 'third-class', assetInstanceId: 'third-furnace'} : oldIds;
    store.seed('maintenance_workflows/retained-work', {assetTypeKey: 'furnace', assetNumber: 7,
      ...identity, status: 'inProgress', cancelled: false});
    const before = store.entries(); await expect(service.execute(rebind(), context())).rejects.toMatchObject({
      details: {reasonCode: 'equipment-rebinding-workflow-review-required'}});
    expect(store.entries()).toEqual(before);
  });

test('target work is recomputed while terminal old work and restrictions remain with their subjects', async () => {
  const {store, service} = fixture();
  store.seed('maintenance_workflows/old-completed', {assetTypeKey: 'furnace', assetNumber: 7, ...oldIds,
    status: 'completed', activeRedWork: true});
  store.seed('maintenance_workflows/target-open', {assetTypeKey: 'furnace', assetNumber: 7, ...newIds,
    status: 'inProgress', activeRedWork: true});
  await service.execute(rebind(), context());
  expect(store.read('equipment_status/furnace_7')).toMatchObject({...newIds, state: 'underRED', activeRedWorkCount: 1});
});

test('rebinding never releases a target that the register has withdrawn', async () => {
  const {store, service} = fixture();
  const path = `asset_instances/${newIds.assetInstanceId}`;
  store.seed(path, {...store.read(path), serviceState: 'outOfService'});
  await service.execute(rebind(), context());
  const before = store.entries();
  await expect(service.execute({commandId: 'deploy-replacement', commandType: 'deployEquipment',
    aggregateId: 'equipment_furnace_7', expectedVersion: 13,
    payload: {assetTypeKey: 'furnace', assetNumber: 7, ...newIds}}, context(ops))).rejects.toMatchObject({
    details: {reasonCode: 'equipment-administratively-out-of-service'}});
  expect(store.entries()).toEqual(before);
});

test.each(['target', 'reason'])('reusing accepted command with changed %s refuses', async (field) => {
  const {store, service} = fixture();
  await service.execute(rebind(), context());
  const changed = rebind();
  if (field === 'target') changed.payload.assetInstanceId = 'another-target';
  else changed.payload.registryRebinding.reason = 'Changed reason';
  const before = store.entries();
  await expect(service.execute(changed, context())).rejects.toMatchObject({code: 'command-idempotency-conflict'});
  expect(store.entries()).toEqual(before);
});

test.each(['missing-event', 'changed-archive', 'changed-reason', 'actorName', 'actorRoles',
  'aggregate-version', 'state', 'assetTypeKey', 'assetNumber'])(
  'replay requires intact original rebinding outcome: %s', async (mode) => {
    const {store, service} = fixture();
    await service.execute(rebind(), context());
    const eventPath = 'maintenance_workflow_events/reviewed-rebinding';
    const receiptPath = 'maintenance_workflow_command_receipts/reviewed-rebinding';
    if (mode === 'missing-event') await store.runTransaction(async (tx) => tx.delete(eventPath));
    else if (['changed-archive', 'changed-reason', 'actorName', 'actorRoles'].includes(mode)) {
      const event = store.read(eventPath);
      if (mode === 'changed-archive') event.payload.registryRebinding.previousProjectionJson = '{}';
      else if (mode === 'changed-reason') event.payload.registryRebinding.reason = 'Changed retained review';
      else event[mode] = mode === 'actorRoles' ? ['operations'] : 'Changed reviewer name';
      store.seed(eventPath, event);
    } else {
      const receipt = store.read(receiptPath);
      if (mode === 'aggregate-version') receipt.aggregateVersion = 999;
      else receipt.result[mode] = mode === 'assetNumber' ? 999 : 'changed';
      store.seed(receiptPath, receipt);
    }
    const before = store.entries();
    await expect(service.execute(rebind(), context())).rejects.toMatchObject({details: {
      reasonCode: 'equipment-rebinding-replay-evidence-invalid'}});
    expect(store.entries()).toEqual(before);
  });

test.each(['same-class', 'retired-class', 'explicit-target'])(
  'ordinary reconciliation cannot attribute an unbound historical projection to a replacement: %s', async (mode) => {
    const {store, service} = fixture();
    const current = store.read('equipment_status/furnace_7');
    delete current.assetClassId; delete current.assetInstanceId;
    store.seed('equipment_status/furnace_7', current);
    if (mode === 'same-class') store.seed(`asset_instances/${oldIds.assetInstanceId}`,
      {...store.read(`asset_instances/${oldIds.assetInstanceId}`), assetClassId: newIds.assetClassId});
    const request = rebind();
    delete request.payload.registryRebinding;
    if (mode !== 'explicit-target') {delete request.payload.assetClassId; delete request.payload.assetInstanceId;}
    const before = store.entries();
    await expect(service.execute(request, context())).rejects.toMatchObject({details: {
      reasonCode: 'equipment-registry-subject-ambiguous'}});
    expect(store.entries()).toEqual(before);
  });

test('projection archive retains native nanosecond timestamps and JSON date values without timeline objects', () => {
  const {Timestamp} = require('firebase-admin/firestore');
  const {equipmentProjectionArchive} = require('../lib/maintenanceWorkflow/equipmentRegistrySubject');
  const time = new Timestamp(1790000000, 123456789);
  expect(JSON.parse(equipmentProjectionArchive({updatedAt: time, nested: {at: time}, recorded: at})))
    .toEqual({updatedAt: {type: 'firestoreTimestamp', seconds: time.seconds, nanoseconds: 123456789},
      nested: {at: {type: 'firestoreTimestamp', seconds: time.seconds, nanoseconds: 123456789}},
      recorded: {type: 'date', iso: at.toISOString()}});
});

test('ordinary reconciliation receipts keep their existing replay contract', async () => {
  const {store, service} = fixture();
  store.seed('equipment_status/furnace_7', {...store.read('equipment_status/furnace_7'), ...newIds});
  const command = rebind(); delete command.payload.registryRebinding;
  const accepted = await service.execute(command, context());
  await store.runTransaction(async (tx) => tx.delete('maintenance_workflow_events/reviewed-rebinding'));
  await expect(service.execute(command, context())).resolves.toEqual(accepted);
});

test('accepted event digest normalizes native timestamp storage but binds sub-ms precision', () => {
  const {Timestamp} = require('firebase-admin/firestore');
  const {equipmentRebindingEvidenceDigest: digest} = require('../lib/maintenanceWorkflow/equipmentRegistrySubject');
  const event = {occurredAt: at.toISOString(), actorName: 'Historical reviewer', payload: {}};
  expect(digest({...event, occurredAt: Timestamp.fromDate(at)})).toBe(digest(event));
  const shifted = new Timestamp(Timestamp.fromDate(at).seconds, 1);
  expect(digest({...event, occurredAt: shifted})).not.toBe(digest(event));
});

test('identical replay preserves accepted text normalization without changing the original request fingerprint', async () => {
  const {store, service} = fixture(); const command = rebind();
  for (const key of ['assetTypeKey', 'assetClassId', 'assetInstanceId']) command.payload[key] = ` ${command.payload[key]} `;
  command.payload.registryRebinding.reason = ` ${command.payload.registryRebinding.reason} `;
  const accepted = await service.execute(command, context());
  const before = store.entries();
  await expect(service.execute(command, context())).resolves.toEqual(accepted);
  expect(store.entries()).toEqual(before);
});
