'use strict';

const {randomUUID} = require('crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {FirebaseWorkflowStore, workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
const {computeTemplateVersionContentHash} = require('../lib/publishedTemplateAssignment');
const {versionFixture, auditFixture} = require('./helpers/publishedTemplateV2Fixtures.cjs');
const {produceRedPreparationEvidence} = require('./helpers/produceRedPreparationEvidence.cjs');

jest.setTimeout(60000);
const host = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = host ? describe : describe.skip;
const START = '2026-09-20T00:00:00.000Z';
const actor = (uid, role) => ({uid, name: `DEV ${role}`, roles: new Set([role])});
const admin = actor('red-admin', 'admin');
const operations = actor('red-operations', 'operations');
const electrical = actor('red-electrical', 'seniorElectrical');
const refractory = actor('red-refractory', 'refractory');

// These exercise the real dispatcher + Firestore transaction adapter. The
// frozen, already-reviewed publication is a fixture, not a claim of UI/Auth
// publication coverage. Every test uses a newly named synthetic namespace.
describeWithEmulator('planned RED and closed-job compliance Firestore boundaries', () => {
  let app;
  let db;
  let service;
  let store;
  let sequence;
  const paths = new Set();

  beforeAll(() => {
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
      throw new Error('Planned RED tests require a loopback Firestore emulator.');
    }
  });

  beforeEach(() => {
    const unique = randomUUID().slice(0, 8);
    app = initializeApp({projectId: `demo-red-${unique}`}, `planned-red-${unique}`);
    db = getFirestore(app);
    sequence = 0;
    const actual = new FirebaseWorkflowStore(db);
    // Observe only write paths for owned-document cleanup and complete no-write
    // readback. All reads, queries and writes still use the real adapter.
    store = {runTransaction: (body) => actual.runTransaction((tx) => body({
      get: (path) => tx.get(path),
      query: (collection, filters) => tx.query(collection, filters),
      create: (path, data) => { paths.add(path); return tx.create(path, data); },
      set: (path, data, merge) => { paths.add(path); return tx.set(path, data, merge); },
      update: (path, data) => { paths.add(path); return tx.update(path, data); },
      delete: (path) => { paths.add(path); return tx.delete(path); },
    }))};
    service = new MaintenanceWorkflowCommandService(store);
  });

  afterEach(async () => {
    if (!db) return;
    const batch = db.batch();
    for (const path of paths) batch.delete(db.doc(path));
    if (paths.size > 0) await batch.commit();
    paths.clear();
    await db.terminate();
    await deleteApp(app);
  });

  async function seed(path, data) {
    paths.add(path);
    await db.doc(path).set(workflowFirestoreDataForTest(data));
  }
  const read = async (path) => (await db.doc(path).get()).data();
  async function snapshot({physicalOnly = false} = {}) {
    const ignored = ['compliance_requests/', 'compliance_attempts/',
      'maintenance_workflow_events/', 'maintenance_workflow_command_receipts/'];
    const keys = [...paths].filter((path) => !physicalOnly ||
      !ignored.some((prefix) => path.startsWith(prefix))).sort();
    const rows = await db.getAll(...keys.map((path) => db.doc(path)));
    return Object.fromEntries(rows.filter((row) => row.exists).map((row) => [row.ref.path, {
      data: row.data(), updateTime: row.updateTime,
    }]));
  }

  async function fixture({asset = 'forceCooler', redLane = false} = {}) {
    const number = asset === 'base' ? 101 : 6;
    for (const user of [admin, operations, electrical, refractory]) {
      await seed(`users/${user.uid}`, {name: user.name, isApproved: true,
        roles: [...user.roles], email: `${user.uid}@example.invalid`,
        createdAt: START, authorityRevision: 1, photoUrl: null, fcmToken: null});
    }
    await seed('maintenance_workflows/parent', {jobExecutionId: 'parent-exec',
      status: redLane ? 'fullyAcknowledged' : 'readyForClosure', version: 1,
      assetTypeKey: asset, assetNumber: number, laneSetFinalizedAt: START,
      cancelled: false, activeRedWork: false, awaitingPreparation: false,
      createdAt: START, updatedAt: START});
    await seed('job_executions/parent-exec', {firestoreId: 'parent-exec',
      assetType: asset, assetNumber: number, workflowSchemaVersion: 1, version: 2,
      modulePopulationVersion: 7, modulePopulationSchemaVersion: 1,
      isCompleted: false, isCancelled: false, isDeleted: false,
      metadataJson: '{}', teamsInvolved: [], responsesJson: '[]', actionsJson: '[]',
      createdAt: START, updatedAt: START});
    for (const laneKey of ['elec', 'oprn', ...(redLane ? ['red'] : [])]) {
      await seed(`job_lanes/parent_${laneKey}_1`, {workflowId: 'parent',
        jobExecutionId: 'parent-exec', laneKey, activationGeneration: 1, version: 2,
        status: laneKey === 'red' ? 'pending' : 'closed', createdAt: START, updatedAt: START});
    }
    await seed('job_modules/parent-module', {firestoreId: 'parent-module',
      jobExecutionFirestoreId: 'parent-exec', workflowLaneFirestoreId: 'parent_elec_1',
      laneKey: 'elec', discipline: 'electrical', status: 'accepted',
      isOpenForWork: false, requiredForClosure: true, isDeleted: false,
      fieldDefinitionsJson: '[{"key":"condition","required":true,"type":"longText"}]',
      responsesJson: '[{"key":"condition","value":"Acceptable"}]', actionsJson: '[]',
      requiresFollowUp: false, pendingIssue: null, version: 2,
      createdAt: START, updatedAt: START, acceptedAt: START,
      acceptedByUid: admin.uid, acceptedByName: admin.name});
    await seed(`equipment_status/${asset}_${number}`, {state: 'underMaintenance',
      activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0,
      awaitingPreparationCount: 0, version: 1});
    return {equipmentPath: `equipment_status/${asset}_${number}`};
  }

  async function publishedRed(asset) {
    const code = `RED-${asset.toUpperCase()}-V1`;
    await seed(`equipment_prompt_master/${asset}_red`, {
      assetTypeKey: asset, active: true, redSuccessorTemplateCode: code,
    });
    await seed('template_packages/red-package', {firestoreId: 'red-package',
      latestVersionNumber: 1, packageCode: code, title: 'Synthetic RED work',
      lifecycleStatus: 'active', activeVersionFirestoreId: 'red-version', isDeleted: false});
    const version = versionFixture({firestoreId: 'red-version', packageFirestoreId: 'red-package',
      jobTemplateSnapshotJson: JSON.stringify({jobName: `${asset} RED successor`}),
      moduleSnapshotsJson: JSON.stringify([{moduleCode: 'RED-01',
        moduleTitle: 'Inspect and repair refractory', requiredForClosure: true,
        safetyClass: 'hotSurface'}]),
      fieldDefinitionsJson: JSON.stringify([{moduleCode: 'RED-01', key: 'condition',
        label: 'Refractory condition', type: 'longText'}]),
    });
    version.contentHash = computeTemplateVersionContentHash(version);
    await seed('template_versions/red-version', version);
    await seed('template_publish_audits/red-audit', auditFixture({firestoreId: 'red-audit',
      packageFirestoreId: 'red-package', versionFirestoreId: 'red-version', afterHash: version.contentHash}));
  }

  async function command(commandType, payload = {}, user = admin, aggregateId = 'parent') {
    const workflow = await read(`maintenance_workflows/${aggregateId}`);
    const compliance = payload.complianceId ? await read(`compliance_requests/${payload.complianceId}`) : null;
    return {commandId: `red-proof-${++sequence}`, commandType, aggregateId,
      expectedVersion: workflow.version,
      payload: {...(compliance ? {expectedComplianceVersion: compliance.version} : {}), ...payload},
    };
  }
  const execute = (request, user = admin) => service.execute(request, {actor: user,
    serverNow: new Date(Date.parse('2026-09-20T01:00:00Z') + sequence * 1000)});
  async function run(type, payload = {}, user = admin, aggregate = 'parent') {
    return execute(await command(type, payload, user, aggregate), user);
  }
  const raise = (id, extra = {}) => run('raiseCompliance', {complianceId: id,
    originLaneKey: 'elec', targetLaneKey: 'oprn', title: 'Plant support',
    description: 'Report the requested support evidence.', conditionTypeKey: 'manual', ...extra}, electrical);
  async function comply(id, aggregate = 'parent') {
    await run('acknowledgeCompliance', {complianceId: id}, operations, aggregate);
    await run('markComplianceComplied', {complianceId: id, note: 'Support checked on site.'}, operations, aggregate);
  }

  test('ordinary compliance priority admission cannot persist a client-unreadable enum', async () => {
    await fixture();
    for (const priorityKey of ['urgent', 'HIGH', 7, {}, []]) {
      const before = await snapshot();
      await expect(raise('priority-invalid', {priorityKey}))
        .rejects.toMatchObject({code: 'invalid-argument'});
      expect(await snapshot()).toEqual(before);
    }
    for (const [index, [payload, expected]] of [
      [{}, 'medium'], [{priorityKey: null}, 'medium'],
      [{priorityKey: ''}, 'medium'], [{priorityKey: ' '}, 'medium'],
      ...['low', 'medium', 'high', 'critical'].map((priorityKey) => [{priorityKey}, priorityKey]),
      [{priorityKey: ' high '}, 'high'],
    ].entries()) {
      const id = `priority-valid-${index}`;
      await raise(id, payload);
      expect(await read(`compliance_requests/${id}`)).toMatchObject({
        priorityKey: expected, assetTypeKey: 'forceCooler', assetNumber: 6});
    }
  });

  test.each(['furnace', 'base'])('%s finalization freezes a RED successor with the correct preparation boundary and exact replay', async (asset) => {
    const f = await fixture({asset});
    await publishedRed(asset);
    const final = await command('finalizeJob', {redRequired: true,
      ...(asset === 'furnace' ? {preparationRequired: true} : {})});
    const receipt = await execute(final);
    const child = receipt.result.successorWorkflowId;
    const childExecution = receipt.result.successorExecutionId;
    expect(typeof child).toBe('string');
    expect(await read('job_executions/parent-exec')).toMatchObject({isCompleted: true,
      spawnedRedExecutionFirestoreId: childExecution, completedAt: expect.any(Timestamp)});
    expect(await read(`job_executions/${childExecution}`)).toMatchObject({
      assignedAgencies: ['refractory'], templateVersionId: 'red-version', isCompleted: false});
    const modules = await db.collection('job_modules')
      .where('jobExecutionFirestoreId', '==', childExecution).get();
    expect(modules.size).toBe(1);
    expect(modules.docs[0].data()).toMatchObject({moduleCode: 'RED-01', requiredForClosure: true});
    expect(await read(f.equipmentPath)).toMatchObject({
      state: asset === 'furnace' ? 'awaitingPreparation' : 'underRED',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: asset === 'furnace' ? 0 : 1,
      awaitingPreparationCount: asset === 'furnace' ? 1 : 0});
    const childBeforePreparation = await read(`maintenance_workflows/${child}`);
    expect(childBeforePreparation.redPreparationDecision).toEqual({
      preparationRequired: asset === 'furnace',
      decidedByUid: admin.uid,
      decidedByName: admin.name,
      decidedAt: childBeforePreparation.createdAt,
    });
    expect(childBeforePreparation.redPreparationDecision.decidedAt).toBeInstanceOf(Timestamp);
    const completedParent = await read('job_executions/parent-exec');
    if (asset === 'furnace') {
      const prepId = receipt.result.preparationComplianceId;
      expect(typeof prepId).toBe('string');
      expect(childBeforePreparation).toMatchObject({
        activeRedWork: false, awaitingPreparation: true});
      expect(await read(`job_lanes/${child}_red_1`)).toMatchObject({
        status: 'pending', gatingComplianceRequestId: prepId,
        redPreparationComplianceId: prepId});
      expect(await read(`compliance_requests/${prepId}`)).toMatchObject({
        originLaneKey: 'red', targetLaneKey: 'oprn', linkedWorkflowId: child,
        priorityKey: 'medium', assetTypeKey: 'furnace', assetNumber: 6,
        gatesLaneFirestoreId: `job_lanes/${child}_red_1`,
        raisedByUid: admin.uid, raisedAt: childBeforePreparation.createdAt});
      const before = await snapshot();
      await expect(run('acknowledgeLane', {laneKey: 'red'}, refractory, child))
        .rejects.toMatchObject({code: 'red-preparation-incomplete'});
      expect(await snapshot()).toEqual(before);
      await comply(prepId, child);
      expect((await read(`compliance_requests/${prepId}`)).compliedAt).toBeInstanceOf(Timestamp);
      const beforeUnauthorizedConfirmation = await snapshot();
      await expect(run('confirmComplianceClosed', {complianceId: prepId}, electrical, child))
        .rejects.toMatchObject({code: 'permission-denied'});
      expect(await snapshot()).toEqual(beforeUnauthorizedConfirmation);
      const confirm = await command('confirmComplianceClosed', {complianceId: prepId}, refractory, child);
      const confirmed = await execute(confirm, refractory);
      expect(confirmed.resultKey).toBe('red-preparation-confirmed');
      expect(await read(`maintenance_workflows/${child}`)).toMatchObject({
        activeRedWork: true, awaitingPreparation: false,
        redPreparationDecision: childBeforePreparation.redPreparationDecision});
      expect(await read(`job_lanes/${child}_red_1`)).toMatchObject({
        status: 'pending', gatingComplianceRequestId: null, redPreparationComplianceId: null});
      const beforeConfirmationReplay = await snapshot();
      expect(await execute(confirm, refractory)).toEqual(confirmed);
      expect(await snapshot()).toEqual(beforeConfirmationReplay);
    } else {
      expect(receipt.result.preparationComplianceId).toBeNull();
      expect(await read(`job_lanes/${child}_red_1`)).toMatchObject({
        gatingComplianceRequestId: null, redPreparationComplianceId: null});
    }
    await run('acknowledgeLane', {laneKey: 'red'}, refractory, child);
    expect(await read(f.equipmentPath)).toMatchObject({state: 'underRED',
      activeNonRedMaintenanceCount: 0, activeRedWorkCount: 1, awaitingPreparationCount: 0});
    expect(await read('job_executions/parent-exec')).toEqual(completedParent);
    const beforeReplay = await snapshot();
    expect(await execute(final)).toEqual(receipt);
    expect(await snapshot()).toEqual(beforeReplay);
  });

  test('both RED producers persist the exact raised, released and acknowledged records read by Dart', async () => {
    const expected = require('../../test/fixtures/red_preparation_dispatcher_records.json');
    const produced = await produceRedPreparationEvidence({store, seed, read});
    expect(produced).toEqual(expected);
    for (const row of produced.cases) {
      expect(row.confirmed.resultKey).toBe('red-preparation-confirmed');
      expect(row.readyForWork.workflow.data).toMatchObject({activeRedWork: true, awaitingPreparation: false});
      expect(row.readyForWork.lane.data.status).toBe('acknowledged');
    }
  });

  test('parent replay does not manufacture preparation authority for an existing legacy successor', async () => {
    await fixture({asset: 'furnace'});
    await publishedRed('furnace');
    const final = await command('finalizeJob', {redRequired: true, preparationRequired: true});
    const receipt = await execute(final);
    const child = receipt.result.successorWorkflowId;
    const workflowPath = `maintenance_workflows/${child}`;
    const lanePath = `job_lanes/${child}_red_1`;
    const workflow = await read(workflowPath);
    const lane = await read(lanePath);
    delete workflow.redPreparationDecision;
    delete lane.redPreparationComplianceId;
    // Recreate the historical producer shape. Exact replay must neither infer
    // authority from this ordinary gate nor silently backfill old evidence.
    await seed(workflowPath, workflow);
    await seed(lanePath, lane);
    const before = await snapshot();
    expect(await execute(final)).toEqual(receipt);
    await expect(run('acknowledgeLane', {laneKey: 'red'}, refractory, child))
      .rejects.toMatchObject({code: 'red-preparation-incomplete'});
    expect(await snapshot()).toEqual(before);
  });

  test('a generic RED gate and its counter do not confer the distinct preparation authority', async () => {
    const f = await fixture({asset: 'furnace', redLane: true});
    await raise('generic', {gatesLaneFirestoreId: 'job_lanes/parent_red_1'});
    await run('proposeCounterCondition', {complianceId: 'generic', revisedDescription: 'Revised support method.'}, operations);
    await run('decideCounterCondition', {complianceId: 'generic', accepted: true,
      successorComplianceId: 'generic-successor'}, electrical);
    await run('markComplianceComplied', {complianceId: 'generic-successor', note: 'Revised support completed.'}, operations);
    const ordinary = await run('confirmComplianceClosed', {complianceId: 'generic-successor'}, electrical);
    expect(ordinary.resultKey).toBe('compliance-confirmed-closed');
    expect(await read('maintenance_workflows/parent')).toMatchObject({activeRedWork: false});
    expect(await read(f.equipmentPath)).toMatchObject({state: 'underMaintenance'});

    await run('prepareRedLane', {preparationRequired: true});
    await run('proposeCounterCondition', {complianceId: 'parent_red_preparation',
      revisedDescription: 'Reviewed alternative stand preparation.'}, operations);
    await run('decideCounterCondition', {complianceId: 'parent_red_preparation',
      accepted: true, successorComplianceId: 'stand-successor'}, refractory);
    await run('markComplianceComplied', {complianceId: 'stand-successor', note: 'Stand preparation verified.'}, operations);
    const before = await snapshot();
    await expect(run('confirmComplianceClosed', {complianceId: 'stand-successor'}, electrical))
      .rejects.toMatchObject({code: 'permission-denied'});
    expect(await snapshot()).toEqual(before);
    const prepared = await run('confirmComplianceClosed', {complianceId: 'stand-successor'}, refractory);
    expect(prepared.resultKey).toBe('red-preparation-confirmed');
    expect(await read('maintenance_workflows/parent')).toMatchObject({activeRedWork: true, awaitingPreparation: false});
    expect(await read(f.equipmentPath)).toMatchObject({state: 'underRED'});
  });

  test('nonblocking post-closure response, counter and condition evidence never reopen physical work', async () => {
    await fixture();
    await raise('note');
    await raise('counter-note');
    await seed('maintenance_records/linked-work', {assetType: 'forceCooler', assetNumber: 6,
      version: 1, status: 'open', isResolved: false, updatedAt: START});
    await raise('condition-note', {conditionTypeKey: 'chargeComplete', conditionRef: 'synthetic-charge',
      linkedMaintenanceFirestoreId: 'linked-work', requestPurposeKey: 'deferment', defermentBasisKey: 'ongoingCycle'});
    const final = await run('finalizeJob');
    expect(final.result.closureAttestationHash).toHaveLength(64);
    const physical = await snapshot({physicalOnly: true});

    await comply('note');
    const stale = await command('confirmComplianceClosed', {complianceId: 'note'}, electrical);
    await run('returnComplianceForCorrection', {complianceId: 'note', reason: 'Clarify the follow-up evidence.'}, electrical);
    await run('markComplianceComplied', {complianceId: 'note', note: 'Clarified follow-up evidence.'}, operations);
    const beforeStale = await snapshot();
    await expect(execute(stale, electrical)).rejects.toMatchObject({
      details: {reasonCode: 'compliance-version-conflict'}});
    expect(await snapshot()).toEqual(beforeStale);
    const confirmation = await command('confirmComplianceClosed', {complianceId: 'note'}, electrical);
    const accepted = await execute(confirmation, electrical);
    expect(await read('compliance_attempts/note_1')).toMatchObject({returnedAt: expect.any(Timestamp)});
    expect(await read('compliance_attempts/note_2')).toMatchObject({accepted: true});

    await run('proposeCounterCondition', {complianceId: 'counter-note', revisedDescription: 'Revised follow-up condition.'}, operations);
    await run('decideCounterCondition', {complianceId: 'counter-note', accepted: true,
      successorComplianceId: 'counter-successor'}, electrical);
    await run('markComplianceComplied', {complianceId: 'counter-successor', note: 'Follow-up supplied.'}, operations);
    await run('confirmComplianceClosed', {complianceId: 'counter-successor'}, electrical);
    await run('acknowledgeCompliance', {complianceId: 'condition-note'}, operations);
    const condition = await run('confirmConditionAndReactivate', {complianceId: 'condition-note'}, operations);
    expect(condition).toMatchObject({resultKey: 'condition-confirmed-follow-up',
      result: {physicalWorkReactivated: false}});
    await run('confirmComplianceClosed', {complianceId: 'condition-note'}, electrical);
    expect(await snapshot({physicalOnly: true})).toEqual(physical);
    const beforeReplay = await snapshot();
    expect(await execute(confirmation, electrical)).toEqual(accepted);
    expect(await snapshot()).toEqual(beforeReplay);
  });
});
