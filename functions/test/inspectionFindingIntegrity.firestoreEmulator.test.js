const admin = require('firebase-admin');
const {MaintenanceWorkflowCommandService, MemoryWorkflowStore, seedActor,
  seedFurnaceHierarchy, upsertDefinition, createCampaign, observation} = require('./helpers/inspectionFixture');
const {FirebaseWorkflowStore, workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || '';
const describeLocal = emulatorHost ? describe : describe.skip;
const campaignId = 'campaign-furnace-pt-august';
jest.setTimeout(60000);

describeLocal('inspection effective history and shared finding activation on real Firestore transactions', () => {
  let app, db, service, actor, secondActor;
  const now = new Date('2026-08-21T07:00:00.000Z');
  const run = (command, who = actor) => service.execute(command, {actor: who, serverNow: now});
  const read = async (path) => (await db.doc(path).get()).data();
  const campaign = () => read(`inspection_campaigns/${campaignId}`);
  const finding = (id = 'inspection-finding-first') => read(`inspection_findings/${id}`);
  async function record(id, minute, value, replaces, who = actor) {
    const command = observation({commandId: id, observationId: id, expectedVersion: (await campaign()).version,
      observedAt: `2026-08-21T${minute}:00.000Z`, numericValue: value});
    if (replaces) command.payload.supersedesObservationId = replaces;
    return run(command, who);
  }
  async function adjudication(id, findingId, status) {
    return {commandId: id, commandType: 'adjudicateInspectionFinding', aggregateId: campaignId,
      expectedVersion: (await campaign()).version, payload: {findingId, expectedFindingVersion: (await finding(findingId)).version,
        status, reason: 'Review the original finding while preserving every other episode.'}};
  }
  async function active() {
    return (await db.collection('inspection_findings').where('campaignId', '==', campaignId).get()).docs
      .map(d => d.data()).filter(d => !['acceptedCondition', 'invalidated', 'verifiedResolved'].includes(d.status));
  }
  beforeAll(async () => {
    if (!projectId.startsWith('demo-') || !/^127\.0\.0\.1:\d+$/.test(emulatorHost)) {
      throw new Error('This regression requires a local Firestore emulator and isolated demo project.');
    }
    app = admin.initializeApp({projectId}, `inspection-integrity-${process.pid}`); db = app.firestore();
    service = new MaintenanceWorkflowCommandService(new FirebaseWorkflowStore(db));
  });
  beforeEach(async () => {
    const response = await fetch(`http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error(`Local fixture reset failed: ${response.status}`);
    const seed = new MemoryWorkflowStore(); seedFurnaceHierarchy(seed);
    actor = seedActor(seed, 'inspector-a', ['admin']); secondActor = seedActor(seed, 'inspector-b', ['admin']);
    await Promise.all(seed.entries().map(([path, value]) => db.doc(path).set(workflowFirestoreDataForTest(value))));
    await run(upsertDefinition()); await run(createCampaign({targetAssetNumbers: [1]}));
  });
  afterAll(async () => { if (app) await app.delete(); });

  test('PBA01: stored Timestamp correction selects surviving adverse evidence; real follow-up can resolve', async () => {
    await record('first', '04:50', 1.8); await record('later-adverse', '05:10', 1.7); await record('mistimed', '05:20', 1.9);
    const original = await read('inspection_observations/mistimed');
    await record('corrected', '05:00', 3, 'mistimed', secondActor);
    const c = await campaign(), f = await finding();
    expect(c.targetPopulation[0].lastObservationId).toBe('later-adverse');
    expect(c.latestObservationAt.toDate().toISOString()).toBe('2026-08-21T05:10:00.000Z');
    expect(f).toMatchObject({currentObservationId: 'later-adverse', status: 'open', recurrenceCount: 2});
    expect(f.latestObservedAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(await read('inspection_observations/mistimed')).toEqual(original);
    const verify = (commandId, observationId, expectedVersion, expectedFindingVersion) => ({commandId,
      commandType: 'verifyInspectionFinding', aggregateId: campaignId, expectedVersion,
      payload: {findingId: f.findingId, observationId, expectedFindingVersion, outcome: 'resolved', reason: 'Check effective physical evidence.'}});
    await expect(run(verify('wrong-resolution', 'corrected', c.version, f.version))).rejects.toMatchObject({code: 'failed-precondition'});
    expect((await db.doc('inspection_verifications/wrong-resolution').get()).exists).toBe(false);
    await record('healthy', '05:30', 3);
    await expect(run(verify('real-resolution', 'healthy', (await campaign()).version, (await finding()).version)))
      .resolves.toMatchObject({resultKey: 'inspection-finding-verifiedResolved'});
  });

  test.each([0, 1, 2])('two concurrent historical reopeners serialize to one active episode, run%s', async () => {
    await record('first', '04:50', 1.8); await run(await adjudication('accept-a', 'inspection-finding-first', 'acceptedCondition'));
    await record('second', '05:10', 1.7); await run(await adjudication('accept-b', 'inspection-finding-second', 'acceptedCondition'));
    const a = await adjudication('reopen-a', 'inspection-finding-first', 'open');
    const b = await adjudication('reopen-b', 'inspection-finding-second', 'open');
    const results = await Promise.allSettled([run(a), run(b, secondActor)]);
    expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
    expect(['inspection-finding-population-conflict', 'inspection-finding-newer-episode-exists'])
      .toContain(results.find(r => r.status === 'rejected').reason.details.reasonCode);
    const live = await active(); expect(live).toHaveLength(1);
    expect(live[0].findingId).toBe('inspection-finding-second');
    const winner = results[0].status === 'fulfilled' ? [a, actor] : [b, secondActor];
    const before = await finding(live[0].findingId), beforeCampaign = await campaign();
    await expect(run(...winner)).resolves.toEqual(results.find(r => r.status === 'fulfilled').value);
    expect(await finding(live[0].findingId)).toEqual(before);
    expect(await campaign()).toEqual(beforeCampaign);
    await record('followup', '05:30', 3);
    expect(await active()).toHaveLength(1);
    expect(await finding('inspection-finding-second')).toMatchObject({episodeOriginObservationId: 'second', recurrenceCount: 1});
  });

  test.each([0, 1, 2])('recurrence versus historical reopen cannot create two active findings, run%s', async () => {
    await record('first', '04:50', 1.8); await run(await adjudication('accept', 'inspection-finding-first', 'acceptedCondition'));
    const reopen = await adjudication('reopen', 'inspection-finding-first', 'open');
    const recurrence = observation({commandId: 'recurrence', observationId: 'recurrence', expectedVersion: (await campaign()).version,
      observedAt: '2026-08-21T05:10:00.000Z', numericValue: 1.7});
    const results = await Promise.allSettled([run(reopen), run(recurrence, secondActor)]);
    expect(results.some(r => r.status === 'fulfilled')).toBe(true);
    expect(await active()).toHaveLength(1);
    await record('ordinary-followup', '05:30', 3);
    expect(await active()).toHaveLength(1);
  });

  test('reopening versus campaign closure cannot leave a closed campaign with an active finding', async () => {
    await record('first', '04:50', 1.8); await run(await adjudication('accept', 'inspection-finding-first', 'acceptedCondition'));
    const reopen = await adjudication('reopen', 'inspection-finding-first', 'open');
    const close = {commandId: 'close', commandType: 'setInspectionCampaignStatus', aggregateId: campaignId,
      expectedVersion: (await campaign()).version, payload: {status: 'closed', reason: 'Close only accounted findings.'}};
    const results = await Promise.allSettled([run(reopen), run(close, secondActor)]);
    expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
    expect((await campaign()).status === 'closed' && (await active()).length > 0).toBe(false);
  });
});
