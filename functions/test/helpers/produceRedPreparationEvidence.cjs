'use strict';

const {MaintenanceWorkflowCommandService} = require('../../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../../lib/maintenanceWorkflow/memoryStore');
const {workflowFirestoreDataForTest} = require('../../lib/maintenanceWorkflow/firebaseStore');
const {computeTemplateVersionContentHash} = require('../../lib/publishedTemplateAssignment');
const {versionFixture, auditFixture} = require('./publishedTemplateV2Fixtures.cjs');

const START = '2026-09-20T00:00:00.000Z';
const actor = (role) => ({uid: `red-reader-${role}`, name: `DEV RED ${role}`, roles: new Set([role])});
const admin = actor('admin');
const operations = actor('operations');
const refractory = actor('refractory');

// The same producer is run with MemoryWorkflowStore for standalone fixture
// freshness and FirebaseWorkflowStore for actual persisted-document equality.
// No expected output record is assembled by hand. Only starting conditions and
// the frozen, already-reviewed publication are fixtures.
async function produceRedPreparationEvidence(options = {}) {
  const store = options.store || new MemoryWorkflowStore();
  const seed = options.seed || ((path, data) => store.seed(path, data));
  const read = options.read || ((path) => store.read(path));
  const service = new MaintenanceWorkflowCommandService(store);
  let sequence = 0;
  const run = async (aggregateId, commandType, payload, user) => {
    const workflow = await read(`maintenance_workflows/${aggregateId}`);
    const compliance = payload.complianceId ? await read(`compliance_requests/${payload.complianceId}`) : null;
    sequence += 1;
    return service.execute({commandId: `red-reader-command-${sequence}`, commandType,
      aggregateId, expectedVersion: workflow.version,
      payload: {...(compliance ? {expectedComplianceVersion: compliance.version} : {}), ...payload}},
    {actor: user, serverNow: new Date(Date.parse('2026-09-20T01:00:00.000Z') + sequence * 1000)});
  };
  for (const user of [admin, operations, refractory]) {
    await seed(`users/${user.uid}`, {name: user.name, roles: [...user.roles], isApproved: true,
      email: `${user.uid}@example.invalid`, createdAt: START,
      authorityRevision: 1, photoUrl: null, fcmToken: null});
  }

  async function initial(id, assetNumber, preselected) {
    await seed(`maintenance_workflows/${id}`, {jobExecutionId: id, assetTypeKey: 'furnace',
      assetNumber, status: preselected ? 'fullyAcknowledged' : 'readyForClosure', version: 1,
      workflowSchemaVersion: 1, laneSetVersion: 1, laneSetFinalizedAt: START,
      laneSetFinalizedByUid: admin.uid, laneSetFinalizedByName: admin.name,
      activeRedWork: false, awaitingPreparation: false, cancelled: false,
      createdAt: START, updatedAt: START});
    await seed(`job_executions/${id}`, {firestoreId: id, assetType: 'furnace', assetNumber,
      version: 1, workflowSchemaVersion: 1, modulePopulationVersion: 1,
      modulePopulationSchemaVersion: 1, isCompleted: false, isCancelled: false,
      isDeleted: false, teamsInvolved: [], responsesJson: '[]', actionsJson: '[]',
      metadataJson: '{}', createdAt: START, updatedAt: START});
    for (const laneKey of ['elec', ...(preselected ? ['red'] : [])]) {
      await seed(`job_lanes/${id}_${laneKey}_1`, {workflowId: id, jobExecutionId: id, laneKey,
        status: laneKey === 'red' ? 'pending' : 'closed', activationGeneration: 1,
        version: 1, progressRevision: 0, assetTypeKey: 'furnace', assetNumber,
        createdAt: START, updatedAt: START});
    }
    await seed(`job_modules/${id}-module`, {firestoreId: `${id}-module`,
      jobExecutionFirestoreId: id, workflowLaneFirestoreId: `${id}_elec_1`, laneKey: 'elec',
      discipline: 'electrical', status: 'accepted', isOpenForWork: false,
      requiredForClosure: true, isDeleted: false, requiresFollowUp: false, pendingIssue: null,
      fieldDefinitionsJson: '[{"key":"condition","required":true,"type":"longText"}]',
      responsesJson: '[{"key":"condition","value":"Inspection complete"}]', actionsJson: '[]',
      version: 1, acceptedByUid: admin.uid, acceptedByName: admin.name, acceptedAt: START,
      createdAt: START, updatedAt: START});
    await seed(`equipment_status/furnace_${assetNumber}`, {state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0,
      awaitingPreparationCount: 0, version: 1});
  }

  await seed('equipment_prompt_master/reader-furnace-red', {assetTypeKey: 'furnace',
    active: true, redSuccessorTemplateCode: 'DEV-READER-RED'});
  await seed('template_packages/reader-red-package', {firestoreId: 'reader-red-package',
    packageCode: 'DEV-READER-RED', title: 'Synthetic RED reader inspection',
    latestVersionNumber: 1, lifecycleStatus: 'active',
    activeVersionFirestoreId: 'reader-red-version', isDeleted: false});
  const version = versionFixture({firestoreId: 'reader-red-version',
    packageFirestoreId: 'reader-red-package',
    jobTemplateSnapshotJson: JSON.stringify({jobName: 'Synthetic RED reader inspection'}),
    moduleSnapshotsJson: JSON.stringify([{moduleCode: 'RED-01', moduleTitle: 'Inspect refractory',
      requiredForClosure: true, safetyClass: 'hotSurface'}]),
    fieldDefinitionsJson: '[{"moduleCode":"RED-01","key":"condition","label":"Condition","type":"longText"}]'});
  version.contentHash = computeTemplateVersionContentHash(version);
  await seed('template_versions/reader-red-version', version);
  await seed('template_publish_audits/reader-red-audit', auditFixture({firestoreId: 'reader-red-audit',
    packageFirestoreId: 'reader-red-package', versionFirestoreId: 'reader-red-version',
    afterHash: version.contentHash}));

  const document = async (path) => ({id: path.split('/').at(-1), data: await read(path)});
  const capture = async (workflowId, complianceId, assetNumber) => ({
    workflow: await document(`maintenance_workflows/${workflowId}`),
    lane: await document(`job_lanes/${workflowId}_red_1`),
    compliance: await document(`compliance_requests/${complianceId}`),
    equipment: await document(`equipment_status/furnace_${assetNumber}`),
  });
  const cases = [];
  for (const [route, id, assetNumber] of [
    ['generatedSuccessor', 'reader-parent', 7],
    ['preselectedLane', 'reader-preselected', 8],
  ]) {
    await initial(id, assetNumber, route === 'preselectedLane');
    const created = await run(id, route === 'generatedSuccessor' ? 'finalizeJob' : 'prepareRedLane',
      {preparationRequired: true, ...(route === 'generatedSuccessor' ? {redRequired: true} : {})}, admin);
    const workflowId = created.result.successorWorkflowId || id;
    const complianceId = created.result.preparationComplianceId || created.result.complianceId;
    const raised = await capture(workflowId, complianceId, assetNumber);
    await run(workflowId, 'acknowledgeCompliance', {complianceId}, operations);
    await run(workflowId, 'markComplianceComplied', {complianceId,
      note: 'Furnace placed on the maintenance stand.'}, operations);
    const confirmed = await run(workflowId, 'confirmComplianceClosed', {complianceId}, refractory);
    const released = await capture(workflowId, complianceId, assetNumber);
    const acknowledged = await run(workflowId, 'acknowledgeLane', {laneKey: 'red'}, refractory);
    cases.push({route, assetNumber, created, confirmed, acknowledged, raised, released,
      readyForWork: await capture(workflowId, complianceId, assetNumber)});
  }
  return JSON.parse(JSON.stringify(workflowFirestoreDataForTest({schemaVersion: 1,
    producer: 'MaintenanceWorkflowCommandService with canonical Firestore persistence; real emulator equality required',
    cases})));
}

module.exports = {produceRedPreparationEvidence};
if (require.main === module) {
  produceRedPreparationEvidence().then((value) => {
    const json = `${JSON.stringify(value, null, 2)}\n`;
    if (process.argv.includes('--write-fixture')) {
      const path = require('node:path').resolve(__dirname, '../../../test/fixtures/red_preparation_dispatcher_records.json');
      require('node:fs').writeFileSync(path, json, 'utf8');
    } else {
      process.stdout.write(json);
    }
  }).catch((error) => { process.stderr.write(String(error)); process.exitCode = 1; });
}
