const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const actor = (uid, roles) => ({uid, name: uid, roles: new Set(roles)});
const admin = actor('review-admin', ['admin']);
const ops = actor('review-ops', ['operations']);
const electrical = actor('review-elec', ['seniorElectrical']);
const red = actor('review-red', ['refractory']);

function fixture({redLane = false, closedLanes = false} = {}) {
  const store = new MemoryWorkflowStore();
  for (const a of [admin, ops, electrical, red]) {
    store.seed(`users/${a.uid}`, {name: a.name, isApproved: true, roles: [...a.roles]});
  }
  store.seed('maintenance_workflows/review', {jobExecutionId: 'review-exec',
    status: closedLanes ? 'readyForClosure' : 'fullyAcknowledged', version: 1,
    assetTypeKey: redLane ? 'furnace' : 'forceCooler', assetNumber: 6,
    laneSetFinalizedAt: '2026-09-20T00:00:00.000Z', cancelled: false,
    activeRedWork: false, awaitingPreparation: false});
  store.seed('job_executions/review-exec', {firestoreId: 'review-exec',
    workflowSchemaVersion: 1, version: 2, modulePopulationVersion: 7,
    modulePopulationSchemaVersion: 1, isCompleted: false, isDeleted: false,
    metadataJson: '{}', teamsInvolved: [], responsesJson: '[]', actionsJson: '[]'});
  for (const laneKey of ['elec', 'oprn', ...(redLane ? ['red'] : [])]) {
    store.seed(`job_lanes/review_${laneKey}_1`, {workflowId: 'review',
      jobExecutionId: 'review-exec', laneKey, activationGeneration: 1, version: 2,
      status: laneKey === 'red' ? 'pending' : closedLanes ? 'closed' : 'acknowledged'});
  }
  store.seed('job_modules/review-module', {firestoreId: 'review-module',
    jobExecutionFirestoreId: 'review-exec', workflowLaneFirestoreId: 'review_elec_1',
    laneKey: 'elec', discipline: 'electrical', status: 'accepted',
    isOpenForWork: false, requiredForClosure: true, isDeleted: false,
    fieldDefinitionsJson: '[{"key":"condition","required":true,"type":"longText"}]',
    responsesJson: '[{"key":"condition","value":"Acceptable"}]',
    requiresFollowUp: false, pendingIssue: null, version: 2});
  store.seed(`equipment_status/${redLane ? 'furnace' : 'forceCooler'}_6`, {
    state: 'underMaintenance', activeNonRedMaintenanceCount: 1,
    activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1});
  const service = new MaintenanceWorkflowCommandService(store);
  let sequence = 0;
  const accepted = [];
  async function run(commandType, payload = {}, a = admin, overrides = {}) {
    const compliance = payload.complianceId == null ? null :
      store.read(`compliance_requests/${payload.complianceId}`);
    const command = {commandId: `review-command-${++sequence}`, commandType,
      aggregateId: 'review', expectedVersion: store.read('maintenance_workflows/review').version,
      payload: {...payload, ...(compliance == null ? {} : {
        expectedComplianceVersion: compliance.version,
      })}, ...overrides};
    const receipt = await service.execute(command, {actor: a,
      serverNow: new Date(Date.parse('2026-09-20T01:00:00Z') + sequence * 1000)});
    accepted.push({command, receipt, actor: a});
    return receipt;
  }
  const raise = (id, gated = false, extra = {}) => run('raiseCompliance', {
    complianceId: id, originLaneKey: 'elec', targetLaneKey: 'oprn', title: 'Plant support',
    description: 'Verify and report the requested support.', conditionTypeKey: 'manual',
    ...(gated ? {gatesLaneFirestoreId: `job_lanes/review_${redLane ? 'red' : 'elec'}_1`} : {}),
    ...extra,
  }, electrical);
  const comply = async (id) => {
    await run('acknowledgeCompliance', {complianceId: id}, ops);
    return run('markComplianceComplied', {complianceId: id, note: 'Response verified on site.'}, ops);
  };
  return {store, service, run, raise, comply, accepted};
}

const physicalSnapshot = (store) => store.entries().filter(([path]) =>
  !['compliance_requests/', 'compliance_attempts/', 'maintenance_workflow_events/',
    'maintenance_workflow_command_receipts/'].some((prefix) => path.startsWith(prefix)));

describe('multi-agency review regressions', () => {
  test('closing a non-blocking response cannot subtract another request\'s blocker', async () => {
    const f = fixture();
    await f.raise('blocker', true);
    await f.raise('service-note');
    await f.comply('service-note');
    await f.run('confirmComplianceClosed', {complianceId: 'service-note'}, electrical);
    expect(f.store.read('maintenance_workflows/review').status).toBe('awaitingCompliance');
    await f.comply('blocker');
    await f.run('confirmComplianceClosed', {complianceId: 'blocker'}, electrical);
    expect(f.store.read('maintenance_workflows/review').status).toBe('fullyAcknowledged');
  });

  test('returning a non-blocking response retains the real coordination state', async () => {
    const f = fixture();
    await f.raise('service-note'); await f.comply('service-note');
    await f.run('returnComplianceForCorrection', {complianceId: 'service-note', reason: 'Clarify the response.'}, electrical);
    expect(f.store.read('maintenance_workflows/review').status).toBe('fullyAcknowledged');
  });

  test.each(['confirmComplianceClosed', 'returnComplianceForCorrection'])(
    '%s rejects foreign and older same-request attempts without writes', async (commandType) => {
      const f = fixture();
      await f.raise('a'); await f.comply('a');
      await f.raise('b'); await f.comply('b');
      await f.run('returnComplianceForCorrection', {complianceId: 'a', reason: 'Repeat and clarify.'}, electrical);
      await f.run('markComplianceComplied', {complianceId: 'a', note: 'Second corrected response.'}, ops);
      const current = f.store.read('compliance_requests/a');
      for (const damage of [
        {currentAttemptId: 'b_1'},
        {currentAttemptId: 'a_1'},
        // The otherwise valid, unreviewed A_2 must still be refused if the
        // parent claims a different latest attempt number.
        {attemptCount: 3},
      ]) {
        f.store.seed('compliance_requests/a', {...current, ...damage});
        const before = f.store.entries();
        await expect(f.run(commandType, {complianceId: 'a', reason: 'Needs correction.'}, electrical))
          .rejects.toMatchObject({code: 'failed-precondition',
            details: {reasonCode: 'compliance-attempt-lineage-invalid'}});
        expect(f.store.entries()).toEqual(before);
      }
      f.store.seed('compliance_requests/a', current);
      await f.run(commandType, {complianceId: 'a', reason: 'Needs correction.'}, electrical);
      expect(f.store.read('compliance_attempts/b_1').accepted).toBe(false);
    },
  );

  test('a generic revised RED gate never becomes preparation authority', async () => {
    const f = fixture({redLane: true});
    await f.raise('generic', true);
    await f.run('proposeCounterCondition', {complianceId: 'generic', revisedDescription: 'Use a revised support method.'}, ops);
    await f.run('decideCounterCondition', {complianceId: 'generic', accepted: true, successorComplianceId: 'generic-successor'}, electrical);
    await f.run('markComplianceComplied', {complianceId: 'generic-successor', note: 'Revised support completed.'}, ops);
    const receipt = await f.run('confirmComplianceClosed', {complianceId: 'generic-successor'}, electrical);
    expect(receipt.resultKey).toBe('compliance-confirmed-closed');
    expect(f.store.read('maintenance_workflows/review').activeRedWork).toBe(false);
    expect(f.store.read('equipment_status/furnace_6').state).toBe('underMaintenance');
  });

  test('real preparation and its counter successor retain authority without losing other holds', async () => {
    const f = fixture({redLane: true, closedLanes: true});
    await f.run('prepareRedLane', {preparationRequired: true});
    await f.raise('service-note'); await f.comply('service-note');
    await f.run('confirmComplianceClosed', {complianceId: 'service-note'}, electrical);
    expect(f.store.read('maintenance_workflows/review')).toMatchObject({
      status: 'awaitingCompliance', awaitingPreparation: true, activeRedWork: false});
    await f.run('proposeCounterCondition', {complianceId: 'review_red_preparation', revisedDescription: 'Revised stand preparation method.'}, ops);
    await f.run('decideCounterCondition', {complianceId: 'review_red_preparation', accepted: true, successorComplianceId: 'stand-successor'}, red);
    await f.run('markComplianceComplied', {complianceId: 'stand-successor', note: 'Stand preparation verified.'}, ops);
    const receipt = await f.run('confirmComplianceClosed', {complianceId: 'stand-successor'}, red);
    expect(receipt.resultKey).toBe('red-preparation-confirmed');
    expect(f.store.read('maintenance_workflows/review')).toMatchObject({activeRedWork: true, awaitingPreparation: false});
  });

  test('a conflicting modern preparation marker cannot fall back to a suggestive legacy ID', async () => {
    const f = fixture({redLane: true, closedLanes: true});
    await f.run('prepareRedLane', {preparationRequired: true});
    await f.comply('review_red_preparation');
    const path = 'job_lanes/review_red_1';
    f.store.seed(path, {...f.store.read(path), redPreparationComplianceId: 'different-preparation'});
    const before = f.store.entries();
    await expect(f.run('confirmComplianceClosed', {complianceId: 'review_red_preparation'}, red))
      .rejects.toMatchObject({details: {reasonCode: 'red-preparation-authority-conflict'}});
    expect(f.store.entries()).toEqual(before);
    expect(f.store.read('maintenance_workflows/review').activeRedWork).toBe(false);
    expect(f.store.read(path).redPreparationComplianceId).toBe('different-preparation');
  });

  test('post-finalization responses and repeated reviews preserve every physical record and original receipt', async () => {
    const f = fixture({closedLanes: true});
    await f.raise('raised-note');
    await f.raise('already-complied'); await f.comply('already-complied');
    const preClosureCommand = f.accepted.at(-1);
    const final = await f.run('finalizeJob');
    expect(final.result.validatedModuleCount).toBe(1);
    expect(final.result.closureAttestationHash).toHaveLength(64);
    const physical = physicalSnapshot(f.store);
    await f.comply('raised-note');
    await f.run('returnComplianceForCorrection', {complianceId: 'raised-note', reason: 'Verify the location again.'}, electrical);
    await f.run('markComplianceComplied', {complianceId: 'raised-note', note: 'Location verified again.'}, ops);
    await f.run('confirmComplianceClosed', {complianceId: 'raised-note'}, electrical);
    await f.run('confirmComplianceClosed', {complianceId: 'already-complied'}, electrical);
    expect(f.store.read('compliance_attempts/raised-note_1').returnedAt).toBeTruthy();
    expect(f.store.read('compliance_attempts/raised-note_2').accepted).toBe(true);
    expect(physicalSnapshot(f.store)).toEqual(physical);
    const beforeReplay = f.store.entries();
    await expect(f.service.execute(preClosureCommand.command, {actor: preClosureCommand.actor,
      serverNow: new Date('2026-09-20T03:00:00Z')})).resolves.toEqual(preClosureCommand.receipt);
    expect(f.store.entries()).toEqual(beforeReplay);
  });

  test('post-closure counter succession retains physical source binding without reopening maintenance', async () => {
    const f = fixture({closedLanes: true});
    f.store.seed('maintenance_records/physical-work', {assetType: 'forceCooler', assetNumber: 6,
      version: 1, status: 'open', isResolved: false});
    await f.raise('counter-note', false, {linkedMaintenanceFirestoreId: 'physical-work'});
    await f.run('finalizeJob');
    const physical = physicalSnapshot(f.store);
    await f.run('proposeCounterCondition', {complianceId: 'counter-note', revisedDescription: 'Updated follow-up response requested.'}, ops);
    await f.run('decideCounterCondition', {complianceId: 'counter-note', accepted: true, successorComplianceId: 'counter-note-2'}, electrical);
    await f.run('markComplianceComplied', {complianceId: 'counter-note-2', note: 'Follow-up information supplied.'}, ops);
    await f.run('confirmComplianceClosed', {complianceId: 'counter-note-2'}, electrical);
    expect(f.store.read('compliance_requests/counter-note-2')).toMatchObject({
      status: 'confirmedClosed', physicalSourceComplianceId: 'counter-note'});
    expect(physicalSnapshot(f.store)).toEqual(physical);
  });

  test('condition confirmation after closure records evidence without physical reactivation', async () => {
    const f = fixture({closedLanes: true});
    f.store.seed('maintenance_records/deferred-work', {assetType: 'forceCooler', assetNumber: 6,
      version: 1, status: 'open', isResolved: false});
    await f.raise('condition-note', false, {conditionTypeKey: 'chargeComplete', conditionRef: 'charge-1',
      linkedMaintenanceFirestoreId: 'deferred-work', requestPurposeKey: 'deferment', defermentBasisKey: 'ongoingCycle'});
    await f.run('finalizeJob');
    const physical = physicalSnapshot(f.store);
    await f.run('acknowledgeCompliance', {complianceId: 'condition-note'}, ops);
    const receipt = await f.run('confirmConditionAndReactivate', {complianceId: 'condition-note'}, ops);
    expect(receipt.resultKey).toBe('condition-confirmed-follow-up');
    expect(receipt.result.physicalWorkReactivated).toBe(false);
    expect(f.store.read(`maintenance_workflow_events/${receipt.commandId}`)).toMatchObject({
      eventType: 'compliance.complied', payload: {physicalWorkReactivated: false, conditionConfirmed: true}});
    expect(f.store.read('compliance_requests/condition-note').complianceNote)
      .toBe('Condition confirmed for follow-up; physical job remains closed.');
    expect(f.store.read('compliance_attempts/condition-note_1').note)
      .toBe('Condition confirmed for follow-up; physical job remains closed.');
    await f.run('confirmComplianceClosed', {complianceId: 'condition-note'}, electrical);
    expect(physicalSnapshot(f.store)).toEqual(physical);
  });

  test.each(['missing-version', 'stale-version', 'blocking', 'cancelled-parent'])(
    'post-closure %s is rejected write-free', async (variant) => {
      const f = fixture({closedLanes: true});
      await f.raise('guarded-note');
      await f.run('finalizeJob');
      if (variant === 'blocking') f.store.seed('compliance_requests/guarded-note', {
        ...f.store.read('compliance_requests/guarded-note'), gatesLaneFirestoreId: 'job_lanes/review_elec_1'});
      if (variant === 'cancelled-parent') f.store.seed('job_executions/review-exec', {
        ...f.store.read('job_executions/review-exec'), isCancelled: true});
      const before = f.store.entries();
      const payload = {complianceId: 'guarded-note', expectedComplianceVersion: 1};
      if (variant === 'missing-version') delete payload.expectedComplianceVersion;
      if (variant === 'stale-version') payload.expectedComplianceVersion = 99;
      await expect(f.run('acknowledgeCompliance', payload, ops, {payload}))
        .rejects.toBeInstanceOf(Error);
      expect(f.store.entries()).toEqual(before);
    },
  );

  test('a stale review cannot accept the next response under the frozen parent version', async () => {
    const f = fixture({closedLanes: true});
    await f.raise('revision-note'); await f.comply('revision-note'); await f.run('finalizeJob');
    const stale = {complianceId: 'revision-note', expectedComplianceVersion: f.store.read('compliance_requests/revision-note').version};
    await f.run('returnComplianceForCorrection', {complianceId: 'revision-note', reason: 'Need another response.'}, electrical);
    await f.run('markComplianceComplied', {complianceId: 'revision-note', note: 'New response supplied.'}, ops);
    const before = f.store.entries();
    await expect(f.run('confirmComplianceClosed', stale, electrical, {payload: stale}))
      .rejects.toMatchObject({details: {reasonCode: 'compliance-version-conflict'}});
    expect(f.store.entries()).toEqual(before);
  });

  test('concurrent post-closure confirm and return cannot both judge the same request revision', async () => {
    const f = fixture({closedLanes: true});
    await f.raise('concurrent-note'); await f.comply('concurrent-note');
    await f.run('finalizeJob');
    const physical = physicalSnapshot(f.store);
    const payload = {complianceId: 'concurrent-note',
      expectedComplianceVersion: f.store.read('compliance_requests/concurrent-note').version,
      reason: 'More detail needed.'};
    const results = await Promise.allSettled([
      f.run('confirmComplianceClosed', payload, electrical, {payload}),
      f.run('returnComplianceForCorrection', payload, electrical, {payload}),
    ]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);
    expect(results.find((result) => result.status === 'rejected').reason)
      .toMatchObject({details: {reasonCode: 'compliance-version-conflict'}});
    expect(physicalSnapshot(f.store)).toEqual(physical);
    expect(f.store.read('compliance_attempts/concurrent-note_1')).toMatchObject({accepted: true});
    expect(f.store.read('compliance_attempts/concurrent-note_1').returnedAt).toBeUndefined();
  });
});
