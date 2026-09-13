const {MaintenanceWorkflowCommandService, MemoryWorkflowStore, at, seedActor,
  seedFurnaceHierarchy, upsertDefinition, createCampaign, observation} = require('./helpers/inspectionFixture');
const campaignId = 'campaign-furnace-pt-august';
async function setup() {
  const store = new MemoryWorkflowStore(); seedFurnaceHierarchy(store);
  const actor = seedActor(store, 'admin-1', ['admin']);
  const secondActor = seedActor(store, 'admin-2', ['admin']);
  const service = new MaintenanceWorkflowCommandService(store);
  const run = (command, who = actor) => service.execute(command, {actor: who, serverNow: at('2026-08-21T07:00:00.000Z')});
  await run(upsertDefinition()); await run(createCampaign({targetAssetNumbers: [1]}));
  const campaign = () => store.read(`inspection_campaigns/${campaignId}`);
  const read = (id, minute, value, replaces, who = actor) => {
    const command = observation({commandId: id, observationId: id, expectedVersion: campaign().version,
      observedAt: `2026-08-21T${minute}:00.000Z`, numericValue: value});
    if (replaces) command.payload.supersedesObservationId = replaces;
    return run(command, who);
  };
  const finding = (id = 'inspection-finding-first') => store.read(`inspection_findings/${id}`);
  const adjudicate = (id, findingId, status, who = actor) => run({commandId: id,
    commandType: 'adjudicateInspectionFinding', aggregateId: campaignId, expectedVersion: campaign().version,
    payload: {findingId, expectedFindingVersion: finding(findingId).version, status, reason: 'Review the original episode without merging histories.'}}, who);
  const verify = (id, observationId, outcome = 'resolved', findingId = 'inspection-finding-first') => run({commandId: id,
    commandType: 'verifyInspectionFinding', aggregateId: campaignId, expectedVersion: campaign().version,
    payload: {findingId, expectedFindingVersion: finding(findingId).version, observationId, outcome,
      reason: 'Certify only effective surviving physical evidence.'}});
  return {store, run, campaign, read, finding, adjudicate, verify, secondActor};
}

test('PBA01: earlier correction preserves later adverse current evidence and refuses false resolution', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8); await f.read('later-adverse', '05:10', 1.7);
  await f.read('mistimed', '05:20', 1.9);
  const original = f.store.read('inspection_observations/mistimed');
  const result = await f.read('corrected', '05:00', 3, 'mistimed', f.secondActor);
  expect(result.result).toMatchObject({observationId: 'corrected', effectiveObservationId: 'later-adverse', issueRecommended: false});
  expect(f.campaign().targetPopulation[0].lastObservationId).toBe('later-adverse');
  expect(f.campaign().latestObservationAt).toBe('2026-08-21T05:10:00.000Z');
  expect(f.finding()).toMatchObject({currentObservationId: 'later-adverse', status: 'open', recurrenceCount: 2,
    firstObservationId: 'first', latestObservedAt: '2026-08-21T05:10:00.000Z'});
  expect(f.store.read('inspection_observations/mistimed')).toEqual(original);
  const before = f.store.entries();
  await expect(f.verify('false-resolution', 'corrected')).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(f.verify('adverse-resolution', 'later-adverse')).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.store.entries()).toEqual(before);
  await f.read('healthy-followup', '05:30', 3);
  await expect(f.verify('real-resolution', 'healthy-followup')).resolves.toMatchObject({resultKey: 'inspection-finding-verifiedResolved'});
});

test.each(['04:40', '04:50', '05:00', '05:10', '05:15', '05:20', '05:25'])(
  'correction at %s chooses latest unsuperseded physical evidence and derives recurrence without correction inflation', async (minute) => {
    const f = await setup(); await f.read('first', '04:50', 1.8); await f.read('later-adverse', '05:10', 1.7);
    await f.read('mistimed', '05:20', 1.9); await f.read('correction', minute, 3, 'mistimed');
    const expected = minute > '05:10' ? 'correction' : 'later-adverse';
    expect(f.campaign().targetPopulation[0].lastObservationId).toBe(expected);
    expect(f.finding()).toMatchObject({currentObservationId: expected, recurrenceCount: 2,
      status: expected === 'correction' ? 'awaitingVerification' : 'open'});
  });

test('same-instant tie uses observation identity, and correction chains never revive a superseded reading', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8); await f.read('later-adverse', '05:10', 1.7);
  await f.read('mistimed', '05:20', 1.9); await f.read('z-correction', '05:10', 3, 'mistimed');
  expect(f.finding().currentObservationId).toBe('z-correction');
  await f.read('chain-correction', '05:00', 2.8, 'z-correction');
  expect(f.finding().currentObservationId).toBe('later-adverse');
  expect(f.finding().recurrenceCount).toBe(2);
  await expect(f.read('wrong-old-correction', '05:25', 3, 'z-correction')).rejects.toMatchObject({code: 'failed-precondition'});
});

test('correcting away the entire adverse basis retains the finding for explicit adjudication', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8);
  await f.read('corrected-first', '05:00', 3, 'first');
  expect(f.finding()).toMatchObject({episodeOriginObservationId: 'first', recurrenceCount: 1, effectiveAdverseObservationCount: 0,
    evidenceReviewRequired: true, evidenceReviewReason: 'inspection-episode-adverse-basis-corrected', status: 'awaitingVerification'});
  await f.read('later-healthy', '05:10', 3);
  await expect(f.verify('no-adverse-basis', 'later-healthy')).rejects.toMatchObject({details: {
    reasonCode: 'inspection-finding-effective-evidence-review-required'}});
  await f.adjudicate('invalidate-error', 'inspection-finding-first', 'invalidated');
  await f.read('new-episode', '05:20', 1.8);
  expect(f.finding('inspection-finding-new-episode')).toMatchObject({episodeOriginObservationId: 'new-episode',
    firstObservationId: 'new-episode', recurrenceCount: 1, evidenceReviewRequired: false});
});

test('a correction chain that remains latest retains only its effective reading and original episode basis', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8); await f.read('mistimed', '05:10', 1.9);
  await f.read('correction-one', '05:20', 3, 'mistimed');
  await f.read('correction-two', '05:30', 2.8, 'correction-one');
  expect(f.campaign().targetPopulation[0].lastObservationId).toBe('correction-two');
  expect(f.finding()).toMatchObject({episodeOriginObservationId: 'first', firstObservationId: 'first',
    currentObservationId: 'correction-two', recurrenceCount: 1, effectiveAdverseObservationCount: 1,
    evidenceReviewRequired: false, status: 'awaitingVerification'});
  await expect(f.verify('verify-effective-chain', 'correction-two')).resolves.toMatchObject({
    resultKey: 'inspection-finding-verifiedResolved'});
});

test('linking corrective work cannot settle a corrected-away adverse basis without explicit adjudication', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8);
  await f.read('corrected-first', '05:00', 3, 'first');
  f.store.seed('asset_classes/class-furnace', {...f.store.read('asset_classes/class-furnace'), code: 'FURNACE', name: 'Furnace'});
  f.store.seed('asset_instances/furnace-1', {...f.store.read('asset_instances/furnace-1'), assetClassCode: 'FURNACE',
    assetClassName: 'Furnace', ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: []});
  await f.run({commandId: 'create-corrective-ticket', commandType: 'createMaintenanceTicket',
    aggregateId: 'review-ticket', expectedVersion: 0, payload: {ticket: {
      schemaVersion: 1, version: 1, assetType: 'furnace', assetNumber: 1,
      component: 'Pressure transmitter', subsystem: null, tag: null, hierarchyPath: [],
      assetHierarchyRefJson: JSON.stringify({schemaVersion: 3, scope: 'physicalAsset', assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-1', assetInstanceVersion: 1}), maintenanceType: 'breakdown', classification: null,
      description: 'Review the corrected pressure history.', routedTo: 'instrumentation', otherDepartment: null,
      isCritical: false, startDate: '2026-08-21T05:10:00.000Z', chargeNoAtEvent: null,
      qualityIntentSchemaVersion: 1, qualityImpactAssessment: 'notSuspected', qualityWarningReason: null,
    }}});
  await f.run({commandId: 'link-corrective-ticket', commandType: 'linkInspectionObservationIssue',
    aggregateId: campaignId, expectedVersion: f.campaign().version,
    payload: {observationId: 'corrected-first', ticketId: 'review-ticket', reason: 'Retain the separate maintenance investigation.'}});
  expect(f.finding()).toMatchObject({status: 'correctiveActionLinked', evidenceReviewRequired: true,
    effectiveAdverseObservationCount: 0, recurrenceCount: 1});
  const close = {commandId: 'close-without-adjudication', commandType: 'setInspectionCampaignStatus', aggregateId: campaignId,
    expectedVersion: f.campaign().version, payload: {status: 'closed', reason: 'Try to settle through the ticket link alone.'}};
  const before = f.store.entries();
  await expect(f.run(close)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.store.entries()).toEqual(before);
  await f.adjudicate('explicit-basis-review', 'inspection-finding-first', 'invalidated');
  await expect(f.run({...close, commandId: 'close-after-adjudication'})).resolves.toMatchObject({
    resultKey: 'inspection-campaign-closed'});
});

test('first adverse reading is derived from the surviving episode while its origin stays immutable', async () => {
  const f = await setup(); await f.read('first', '05:00', 1.8); await f.read('mistimed', '05:20', 1.9);
  await f.read('earlier-adverse', '04:50', 1.7, 'mistimed');
  expect(f.finding()).toMatchObject({episodeOriginObservationId: 'first', firstObservationId: 'earlier-adverse',
    firstObservedAt: '2026-08-21T04:50:00.000Z', currentObservationId: 'first', recurrenceCount: 2});
  await f.read('healthy', '05:30', 3);
  expect(f.finding().recurrenceCount).toBe(2);
  await expect(f.verify('resolve-correct-episode', 'healthy')).resolves.toMatchObject({resultKey: 'inspection-finding-verifiedResolved'});
});

test.each(['acceptedCondition', 'invalidated', 'verifiedResolved'])(
  'PBA02: %s historical finding cannot reopen over another active episode', async (status) => {
    const f = await setup(); await f.read('first', '04:50', 1.8);
    if (status === 'verifiedResolved') { await f.read('healthy', '05:00', 3); await f.verify('verify-first', 'healthy'); }
    else await f.adjudicate('finalize-first', 'inspection-finding-first', status);
    await f.read('recurrence', '05:10', 1.7);
    const before = f.store.entries();
    await expect(f.adjudicate('reopen-old', 'inspection-finding-first', 'open', f.secondActor)).rejects.toMatchObject({
      details: {reasonCode: 'inspection-finding-population-conflict', competingFindingIds: ['inspection-finding-recurrence']}});
    expect(f.store.entries()).toEqual(before);
    await f.read('followup', '05:30', 3);
    expect(f.finding('inspection-finding-recurrence').status).toBe('awaitingVerification');
  });

test('single historical finding can reopen, while a closed campaign must reopen first', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8);
  await f.adjudicate('accept', 'inspection-finding-first', 'acceptedCondition');
  await f.run({commandId: 'close-campaign', commandType: 'setInspectionCampaignStatus', aggregateId: campaignId,
    expectedVersion: f.campaign().version, payload: {status: 'closed', reason: 'All findings explicitly accounted.'}});
  await expect(f.adjudicate('closed-reopen', 'inspection-finding-first', 'open')).rejects.toMatchObject({details: {
    reasonCode: 'inspection-finding-campaign-not-open'}});
  await f.run({commandId: 'reopen-campaign', commandType: 'setInspectionCampaignStatus', aggregateId: campaignId,
    expectedVersion: f.campaign().version, payload: {status: 'open', reason: 'Review the original campaign again.'}});
  await f.adjudicate('reopen', 'inspection-finding-first', 'open');
  await f.read('followup', '05:10', 3);
  expect(f.finding().status).toBe('awaitingVerification');
});

test('two terminal episodes retain separate histories: only the latest can reopen and receive follow-up', async () => {
  const f = await setup(); await f.read('first', '04:50', 1.8);
  await f.adjudicate('accept-first', 'inspection-finding-first', 'acceptedCondition');
  await f.read('second', '05:10', 1.7);
  await f.adjudicate('accept-second', 'inspection-finding-second', 'acceptedCondition');
  const before = f.store.entries();
  await expect(f.adjudicate('reopen-older', 'inspection-finding-first', 'open')).rejects.toMatchObject({
    details: {reasonCode: 'inspection-finding-newer-episode-exists', newerFindingIds: ['inspection-finding-second']}});
  expect(f.store.entries()).toEqual(before);
  await f.adjudicate('reopen-newest', 'inspection-finding-second', 'open');
  await f.read('newest-followup', '05:30', 3);
  expect(f.finding('inspection-finding-second')).toMatchObject({firstObservationId: 'second',
    episodeOriginObservationId: 'second', effectiveAdverseObservationCount: 1, recurrenceCount: 1});
  expect(f.finding()).toMatchObject({status: 'acceptedCondition', firstObservationId: 'first', recurrenceCount: 1});
  await expect(f.verify('verify-newest-only', 'newest-followup', 'resolved', 'inspection-finding-second'))
    .resolves.toMatchObject({resultKey: 'inspection-finding-verifiedResolved'});
});

test('a backdated new input cannot recreate a finding from already adjudicated current evidence', async () => {
  const f = await setup(); await f.read('first', '05:10', 1.8);
  await f.adjudicate('accept', 'inspection-finding-first', 'acceptedCondition');
  const terminal = f.finding();
  const receipt = await f.read('backdated-adverse', '05:00', 1.9);
  expect(receipt.result).toMatchObject({findingId: null, effectiveObservationId: 'first', currentEvidenceAdvanced: false});
  expect(f.finding()).toEqual(terminal);
  expect(f.store.entries().filter(([path]) => path.startsWith('inspection_findings/'))).toHaveLength(1);
  expect(f.campaign().targetPopulation[0].lastObservationId).toBe('first');
});

test.each(['verifiedResolved', 'acceptedCondition', 'invalidated'])(
  'correcting terminal %s follow-up preserves and reopens its original episode instead of recreating its ID', async (status) => {
    const f = await setup(); await f.read('first', '05:10', 1.8); await f.read('healthy', '05:20', 3);
    if (status === 'verifiedResolved') await f.verify('terminal-decision', 'healthy');
    else await f.adjudicate('terminal-decision', 'inspection-finding-first', status);
    const prior = f.finding(), original = f.store.read('inspection_observations/healthy');
    const decision = f.store.read('inspection_finding_events/terminal-decision');
    const correction = await f.read('corrected-healthy', '05:00', 3, 'healthy');
    expect(correction.result).toMatchObject({findingId: prior.findingId, effectiveObservationId: 'first'});
    expect(f.finding()).toMatchObject({findingId: prior.findingId, version: prior.version + 1,
      episodeOriginObservationId: 'first', currentObservationId: 'first', status: 'open',
      createdAt: prior.createdAt, createdByUid: prior.createdByUid, verificationCount: prior.verificationCount});
    expect(f.store.read('inspection_observations/healthy')).toEqual(original);
    expect(f.store.read('inspection_finding_events/terminal-decision')).toEqual(decision);
    expect(f.store.read('inspection_finding_events/corrected-healthy')).toMatchObject({
      operation: 'reopen-after-observation-correction', previousStatus: status, resultingStatus: 'open',
      previousFindingVersion: prior.version, resultingFindingVersion: prior.version + 1,
      supersededObservationId: 'healthy', effectiveObservationId: 'first'});
    for (const key of ['adjudicationReason', 'adjudicatedAt', 'adjudicatedByUid',
      'lastVerificationId', 'lastVerifiedObservationId', 'lastVerificationOutcome']) {
      expect(f.finding()[key]).toEqual(prior[key]);
    }
    expect(f.store.entries().filter(([path]) => path.startsWith('inspection_findings/'))).toHaveLength(1);
    expect(f.campaign().targetPopulation[0].lastObservationId).toBe('first');
  });

test('terminal correction uses the reviewed episode even when its surviving adverse reading never had a finding ID', async () => {
  const f = await setup(); await f.read('first', '05:00', 1.8); await f.read('later-adverse', '05:10', 1.7);
  await f.read('healthy', '05:20', 3); await f.verify('terminal', 'healthy');
  await f.read('corrected-healthy', '05:05', 3, 'healthy');
  expect(f.finding()).toMatchObject({status: 'open', episodeOriginObservationId: 'first',
    currentObservationId: 'later-adverse', recurrenceCount: 2, effectiveAdverseObservationCount: 2});
  expect(f.finding('inspection-finding-later-adverse')).toBeNull();
});

test('correcting a later unowned reading restores terminal evidence without undoing its adjudication', async () => {
  const f = await setup(); await f.read('first', '05:10', 1.8);
  await f.adjudicate('terminal', 'inspection-finding-first', 'acceptedCondition');
  const prior = f.finding(); await f.read('later-unowned', '05:20', 3);
  const result = await f.read('corrected-unowned', '05:00', 3, 'later-unowned');
  expect(result.result).toMatchObject({findingId: null, effectiveObservationId: 'first', currentEvidenceAdvanced: true});
  expect(f.finding()).toEqual(prior);
  expect(f.campaign().targetPopulation[0].lastObservationId).toBe('first');
  expect(f.store.read('inspection_finding_events/corrected-unowned')).toBeNull();
  await f.read('new-adverse', '05:30', 1.7);
  expect(f.finding('inspection-finding-new-adverse')).toMatchObject({status: 'open',
    episodeOriginObservationId: 'new-adverse', recurrenceCount: 1});
  expect(f.finding()).toEqual(prior);
});

test('correcting terminal adverse evidence to normal retains its zero-basis explicit review hold', async () => {
  const f = await setup(); await f.read('first', '05:10', 1.8);
  await f.adjudicate('terminal', 'inspection-finding-first', 'acceptedCondition');
  await f.read('corrected-first', '05:20', 3, 'first');
  expect(f.finding()).toMatchObject({status: 'awaitingVerification', recurrenceCount: 1,
    effectiveAdverseObservationCount: 0, evidenceReviewRequired: true,
    evidenceReviewReason: 'inspection-episode-adverse-basis-corrected', currentObservationId: 'corrected-first'});
  const before = f.store.entries();
  await expect(f.verify('invalid-technical-resolution', 'corrected-first')).rejects.toMatchObject({details: {
    reasonCode: 'inspection-finding-effective-evidence-review-required'}});
  expect(f.store.entries()).toEqual(before);
  await f.adjudicate('explicit-new-review', 'inspection-finding-first', 'invalidated');
});

test.each(['open', 'acceptedCondition'])(
  'a correction cannot merge earlier terminal evidence into a newer %s episode', async (status) => {
    const f = await setup(); await f.read('first', '05:10', 1.8);
    await f.adjudicate('terminal-first', 'inspection-finding-first', 'acceptedCondition');
    await f.read('second', '05:20', 1.7);
    if (status !== 'open') await f.adjudicate('terminal-second', 'inspection-finding-second', status);
    const before = f.store.entries();
    await expect(f.read('exposes-earlier', '05:00', 3, 'second')).rejects.toMatchObject({details: {
      reasonCode: 'inspection-correction-earlier-episode-review', findingId: 'inspection-finding-second'}});
    expect(f.store.entries()).toEqual(before);
  });

test('terminal history keeps the current-only correction contract and ambiguous ownership fails closed', async () => {
  const f = await setup(); await f.read('first', '05:10', 1.8); await f.read('healthy', '05:20', 3);
  await f.verify('terminal', 'healthy');
  const before = f.store.entries();
  await expect(f.read('non-current-basis', '05:30', 3, 'first')).rejects.toMatchObject({details: {
    reasonCode: 'inspection-correction-not-current'}});
  expect(f.store.entries()).toEqual(before);
  f.store.seed('inspection_findings/ambiguous', {...f.finding(), findingId: 'ambiguous'});
  const ambiguous = f.store.entries();
  await expect(f.read('ambiguous-correction', '05:00', 3, 'healthy')).rejects.toMatchObject({details: {
    reasonCode: 'inspection-observation-history-invalid'}});
  expect(f.store.entries()).toEqual(ambiguous);
});

test('accepted terminal correction replays its original receipt after a later follow-up without duplicate history', async () => {
  const f = await setup(); await f.read('first', '05:10', 1.8); await f.read('healthy', '05:20', 3);
  await f.verify('terminal', 'healthy');
  const command = observation({commandId: 'correction', observationId: 'correction', expectedVersion: f.campaign().version,
    observedAt: '2026-08-21T05:00:00.000Z', numericValue: 3});
  command.payload.supersedesObservationId = 'healthy';
  const receipt = await f.run(command); await f.read('next-healthy', '05:30', 3);
  const before = f.store.entries();
  await expect(f.run(command)).resolves.toEqual(receipt);
  await expect(f.run({...command, payload: {...command.payload, note: 'Altered intent'}})).rejects.toMatchObject({code: 'command-idempotency-conflict'});
  expect(f.store.entries()).toEqual(before);
});

test.each(['missing-parent', 'cycle', 'branched-correction', 'wrong-physical-subject', 'wrong-current-projection'])(
  'malformed %s history cannot support verification', async (kind) => {
    const f = await setup(); await f.read('first', '04:50', 1.8); await f.read('healthy', '05:10', 3);
    const row = f.store.read('inspection_observations/healthy');
    if (kind === 'missing-parent') row.supersedesObservationId = 'absent';
    if (kind === 'cycle') row.supersedesObservationId = 'healthy';
    if (kind === 'wrong-physical-subject') { row.supersedesObservationId = 'first'; row.assetInstanceId = 'another'; }
    if (kind === 'branched-correction') { row.supersedesObservationId = 'first'; f.store.seed('inspection_observations/branch', {...row, observationId: 'branch'}); }
    if (kind === 'wrong-current-projection') f.store.seed(`inspection_campaigns/${campaignId}`, {...f.campaign(),
      targetPopulation: f.campaign().targetPopulation.map(t => ({...t, lastObservationId: 'first', lastObservedAt: '2026-08-21T04:50:00.000Z'}))});
    f.store.seed('inspection_observations/healthy', row);
    const before = f.store.entries();
    await expect(f.verify('refuse-corrupt-history', 'healthy')).rejects.toMatchObject({code: 'failed-precondition'});
    expect(f.store.entries()).toEqual(before);
  });
