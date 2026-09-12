const {MaintenanceWorkflowCommandService, MemoryWorkflowStore, at, seedActor,
  seedFurnaceHierarchy, seedInstalledInnerCoverHierarchy, upsertDefinition,
  createCampaign, observation} = require('./helpers/inspectionFixture');
const {mutateAssetRegistryWithDb} = require('../lib/assetRegistryMutation');
const {inspectionContextIdentity} = require('../lib/maintenanceWorkflow/inspectionPopulation');

const canonicalTicket = (id, type, classId, instanceId, startDate = '2026-08-21T05:10:00.000Z') => ({
  commandId: `create-${id}`, commandType: 'createMaintenanceTicket', aggregateId: id, expectedVersion: 0,
  payload: {ticket: {schemaVersion: 1, version: 1, assetType: type, assetNumber: type === 'innerCover' ? 205 : 1,
    component: 'Inspection corrective work', subsystem: null, tag: null, hierarchyPath: [],
    assetHierarchyRefJson: JSON.stringify({schemaVersion: 3, scope: 'physicalAsset',
      assetClassId: classId, assetInstanceId: instanceId, assetInstanceVersion: type === 'innerCover' ? 2 : 1}),
    maintenanceType: 'breakdown', classification: null, description: 'Repair the observed physical subject.',
    routedTo: 'instrumentation', otherDepartment: null, isCritical: false, startDate,
    chargeNoAtEvent: null, qualityIntentSchemaVersion: 1, qualityImpactAssessment: 'notSuspected', qualityWarningReason: null}},
});
function enrich(store, classId, assetId, code) {
  store.seed(`asset_classes/${classId}`, {...store.read(`asset_classes/${classId}`), code, name: code, version: 1});
  store.seed(`asset_instances/${assetId}`, {...store.read(`asset_instances/${assetId}`), assetClassCode: code,
    assetClassName: code, ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: []});
}
const link = (campaignId, ticketId, observationId = 'first', expectedVersion = 2) => ({
  commandId: `link-${ticketId}`, commandType: 'linkInspectionObservationIssue', aggregateId: campaignId, expectedVersion,
  payload: {observationId, ticketId, reason: 'Link repair of this physical subject.'},
});

async function installed() {
  const store = new MemoryWorkflowStore(); seedInstalledInnerCoverHierarchy(store);
  enrich(store, 'class-base', 'base-205', 'BASE');
  const actor = seedActor(store, 'admin', ['admin']);
  const service = new MaintenanceWorkflowCommandService(store);
  const run = (command, now = '2026-08-21T07:00:00.000Z') => service.execute(command, {actor, serverNow: at(now)});
  await run(upsertDefinition({overrides: {assetTypeKeys: ['innerCover'], assetClassIds: ['class-inner-cover'],
    componentNodeIds: ['inner-cover-shell'], minimumValue: 2, maximumValue: 4}}));
  const create = createCampaign({campaignId: 'installed', targetAssetNumbers: [205]});
  create.payload = {...create.payload, assetTypeKey: 'innerCover', assetClassId: 'class-inner-cover',
    populationMode: 'installedInnerCoversByBase', hostAssetClassId: 'class-base', physicalPositionLabels: ['Shell']};
  await run(create);
  const target = store.read('inspection_campaigns/installed').targetPopulation[0];
  const reading = (id = 'first', version = 1, numericValue = 1.8, date = '2026-08-21T05:00:00.000Z') => {
    const command = observation({commandId: id, observationId: id, campaignId: 'installed', expectedVersion: version, numericValue, observedAt: date});
    command.payload = {...command.payload, targetKey: target.targetKey, assetTypeKey: 'innerCover', assetClassId: 'class-inner-cover',
      assetInstanceId: 'inner-cover-n4', assetNumber: 205, componentNodeId: 'inner-cover-shell', componentNodeVersion: 3,
      componentName: 'Inner Cover shell', hierarchyPath: ['Inner Cover', 'Shell'], physicalPosition: 'Shell'};
    return command;
  };
  await run(reading());
  return {store, actor, service, run, target, reading};
}

describe('Inspection corrective work binds the physical subject', () => {
  test('real producer: another serial on the same reused Base cannot repair this Inner Cover', async () => {
    const fixture = await installed(); const {store, run} = fixture;
    const current = ['inner_cover_profiles/inner-cover-n4', 'base_inner_cover_assignments/base-205',
      'inner_cover_linkages/link-n4-base-205'].map((path) => [path, store.read(path)]);
    // A historical installation is represented at the producer boundary. The
    // ticket itself is constructed by the real canonical handler, not patched.
    store.seed('inner_cover_profiles/inner-cover-n3', {...current[0][1], innerCoverId: 'inner-cover-n3', serialNumber: 'N3', currentLinkageId: 'link-n3-base-205'});
    store.seed(current[1][0], {...current[1][1], innerCoverId: 'inner-cover-n3', innerCoverSerialNumber: 'N3', linkageId: 'link-n3-base-205'});
    store.seed('inner_cover_linkages/link-n3-base-205', {...current[2][1], linkageId: 'link-n3-base-205', innerCoverId: 'inner-cover-n3', innerCoverSerialNumber: 'N3'});
    await run(canonicalTicket('old-n3', 'innerCover', 'class-base', 'base-205'));
    const produced = JSON.parse(store.read('maintenance_records/old-n3').assetHierarchyRefJson);
    expect(produced.innerCoverAssociation.innerCoverId).toBe('inner-cover-n3');
    for (const [path, row] of current) store.seed(path, row);
    const before = store.entries();
    await expect(run(link('installed', 'old-n3'))).rejects.toMatchObject({code: 'failed-precondition', details: {reasonCode: 'inspection-corrective-subject-mismatch'}});
    expect(store.entries()).toEqual(before);
    await run(canonicalTicket('matching-n4', 'innerCover', 'class-base', 'base-205'));
    await expect(run(link('installed', 'matching-n4'))).resolves.toMatchObject({resultKey: 'inspection-observation-issue-linked'});
  });

  test.each(['missing-reference', 'malformed-reference', 'wrong-class', 'wrong-instance'])(
    'numbered/custom subjects reject %s evidence instead of comparing only numbers', async (mode) => {
      const store = new MemoryWorkflowStore(); seedFurnaceHierarchy(store); enrich(store, 'class-furnace', 'furnace-1', 'FURNACE');
      const actor = seedActor(store, 'admin', ['admin']); const service = new MaintenanceWorkflowCommandService(store);
      const run = (command) => service.execute(command, {actor, serverNow: at('2026-08-21T07:00:00.000Z')});
      await run(upsertDefinition()); await run(createCampaign({targetAssetNumbers: [1]})); await run(observation({observationId: 'first'}));
      await run(canonicalTicket('repair', 'furnace', 'class-furnace', 'furnace-1'));
      const ticket = store.read('maintenance_records/repair'); const reference = JSON.parse(ticket.assetHierarchyRefJson);
      if (mode === 'wrong-class') reference.assetClassId = 'other-custom-class';
      if (mode === 'wrong-instance') reference.assetInstanceId = 'other-physical-asset';
      store.seed('maintenance_records/repair', {...ticket, assetHierarchyRefJson: mode === 'missing-reference' ? null :
        mode === 'malformed-reference' ? '{' : JSON.stringify(reference)});
      await expect(run(link('campaign-furnace-pt-august', 'repair'))).rejects.toMatchObject({code: 'failed-precondition', details: {
        reasonCode: mode.endsWith('reference') ? 'inspection-corrective-subject-review-required' : 'inspection-corrective-subject-mismatch'}});
    });
});

// One shared document store, real registry and workflow handlers. This adapter
// only translates transaction interfaces; no business transition is simulated.
function registryAdapter(store) {
  const snapshot = (path) => ({exists: store.read(path) != null, data: () => store.read(path) ?? undefined});
  const ref = (path) => ({path, get: async () => snapshot(path)});
  return {collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: (body) => store.runTransaction((tx) => body({
      get: async (target) => { const row = await tx.get(target.path); return {exists: row.exists, data: () => row.data ?? undefined}; },
      set: (target, value, options) => tx.set(target.path, value, options?.merge === true),
      delete: (target) => tx.delete(target.path),
    }))};
}
const classId = '11111111-1111-4111-8111-111111111111';
const assetId = '22222222-2222-4222-8222-222222222222';
const translate = (value) => JSON.parse(JSON.stringify(value).replaceAll('class-furnace', classId).replaceAll('furnace-1', assetId));
const draft = {assetNumber: 1, name: 'Furnace 1', plantTag: null, location: 'BAF', manufacturer: null,
  model: null, serialNumber: null, commissionedOn: null, serviceState: 'inService',
  ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: []};

describe('Explicit same-subject context successor', () => {
  function relocate({store, target}) {
    const base = {...store.read('asset_instances/base-205'), assetInstanceId: 'base-206', assetNumber: 206, name: 'Base 206'};
    store.seed('asset_instances/base-206', base);
    store.seed('inner_cover_profiles/inner-cover-n4', {...store.read('inner_cover_profiles/inner-cover-n4'), version: 8,
      currentBaseAssetInstanceId: 'base-206', currentBaseAssetNumber: 206, currentLinkageId: 'link-n4-base-206'});
    store.seed('base_inner_cover_assignments/base-206', {...store.read('base_inner_cover_assignments/base-205'),
      baseAssetInstanceId: 'base-206', baseAssetNumber: 206, baseAssetName: 'Base 206', linkageId: 'link-n4-base-206',
      linkedAt: '2026-08-21T06:00:00.000Z', version: 1});
    store.seed('inner_cover_linkages/link-n4-base-206', {...store.read('inner_cover_linkages/link-n4-base-205'),
      linkageId: 'link-n4-base-206', baseAssetInstanceId: 'base-206', baseAssetNumber: 206, baseAssetName: 'Base 206',
      installedAt: '2026-08-21T06:00:00.000Z'});
    store.seed('inner_cover_linkages/link-n4-base-205', {...store.read('inner_cover_linkages/link-n4-base-205'), active: false, version: 2,
      removedAt: '2026-08-21T05:50:00.000Z'});
    store.seed('base_inner_cover_assignments/base-205', {...store.read('base_inner_cover_assignments/base-205'),
      innerCoverId: null, innerCoverSerialNumber: null, linkageId: null, linkedAt: null, version: 5});
    return {...inspectionContextIdentity(target), assetNumber: 206, assetInstanceVersion: 8,
      hostAssetInstanceId: 'base-206', hostAssetNumber: 206, hostAssetInstanceName: 'Base 206',
      linkageId: 'link-n4-base-206', linkedAt: '2026-08-21T06:00:00.000Z'};
  }
  const reviewInstalled = (target, reviewedContext) => ({commandId: 'review-installed', commandType: 'revalidateInspectionTargetContext',
    aggregateId: 'installed', expectedVersion: 2, payload: {reviewerUid: 'admin', targetKey: target.targetKey, expectedContextRevision: 0,
      reviewedContext, reason: 'Reviewed original serial N4 following its recorded relocation.'}});

  test('correction after relocation retains the superseded baseline installation and time', async () => {
    const f = await installed(); const original = f.store.read('inspection_observations/first');
    await f.run(reviewInstalled(f.target, relocate(f)));
    const correction = f.reading('correction', 3, 2.8, original.observedAt);
    correction.payload.targetContextRevision = 1;
    correction.payload.supersedesObservationId = 'first';
    await f.run(correction);
    expect(f.store.read('inspection_observations/correction')).toMatchObject({
      assetNumber: 205, hostAssetInstanceId: 'base-205', subjectSerialNumber: 'N4',
      linkageId: 'link-n4-base-205', linkageVersion: 1, linkedAt: original.linkedAt,
      targetContextRevision: 0, targetContextAuditId: null, targetContextOriginalLinkageId: null,
      observedAt: original.observedAt, supersedesObservationId: 'first', numericValue: 2.8,
    });
    expect(f.store.read('inspection_observations/first')).toEqual(original);
    expect(f.store.read('inspection_campaigns/installed').targetPopulation[0]).toMatchObject({
      assetNumber: 205, lastObservationId: 'correction', contextReview: {revision: 1, context: {hostAssetNumber: 206}},
    });
    expect(f.store.read('inspection_findings/inspection-finding-first')).toMatchObject({
      currentObservationId: 'correction', assetNumber: 205, linkageId: 'link-n4-base-205',
    });
    const later = f.reading('after-correction', 4, 3, '2026-08-21T06:30:00.000Z');
    later.payload.targetContextRevision = 1; await f.run(later);
    const accepted = f.store.entries(); await f.run(correction); expect(f.store.entries()).toEqual(accepted);
  });

  async function twiceReviewed() {
    const f = await installed();
    const current = relocate(f); await f.run(reviewInstalled(f.target, current));
    const reading = f.reading('reviewed-reading', 3, 1.7, '2026-08-21T06:30:00.000Z');
    reading.payload.targetContextRevision = 1; await f.run(reading);
    f.store.seed('inner_cover_profiles/inner-cover-n4', {...f.store.read('inner_cover_profiles/inner-cover-n4'), version: 9});
    await f.run({...reviewInstalled(f.target, {...current, assetInstanceVersion: 9}),
      commandId: 'review-second', expectedVersion: 4,
      payload: {...reviewInstalled(f.target, {...current, assetInstanceVersion: 9}).payload, expectedContextRevision: 1}});
    const correction = f.reading('reviewed-correction', 5, 2.8, reading.payload.observedAt);
    correction.payload.targetContextRevision = 2; correction.payload.supersedesObservationId = 'reviewed-reading';
    return {...f, correction};
  }

  test('correction keeps the older authenticated review and retired component while latest review stays intact', async () => {
    const f = await twiceReviewed(); const original = f.store.read('inspection_observations/reviewed-reading');
    f.store.seed('asset_hierarchy_nodes/inner-cover-shell', {...f.store.read('asset_hierarchy_nodes/inner-cover-shell'),
      version: 4, name: 'Renamed component', status: 'retired'});
    await f.run(f.correction);
    expect(f.store.read('inspection_observations/reviewed-correction')).toMatchObject({
      assetNumber: 206, hostAssetInstanceId: 'base-206', subjectSerialNumber: 'N4',
      linkageId: 'link-n4-base-206', targetContextRevision: 1, targetContextAuditId: 'review-installed',
      targetContextOriginalLinkageId: 'link-n4-base-205', componentNodeVersion: 3,
      componentName: 'Inner Cover shell', hierarchyPath: ['Inner Cover', 'Shell'], observedAt: original.observedAt,
    });
    expect(f.store.read('inspection_observations/reviewed-reading')).toEqual(original);
    expect(f.store.read('inspection_campaigns/installed').targetPopulation[0]).toMatchObject({
      lastObservationId: 'reviewed-correction', contextReview: {revision: 2, auditId: 'review-second'},
    });
    expect(f.store.read('inspection_findings/inspection-finding-first')).toMatchObject({
      currentObservationId: 'reviewed-correction', assetNumber: 206, linkageId: 'link-n4-base-206',
    });
    if (process.env.INSPECTION_CORRECTION_FIXTURE) require('node:fs').writeFileSync(process.env.INSPECTION_CORRECTION_FIXTURE,
      JSON.stringify({provenance: 'Actual MaintenanceWorkflowCommandService producer: inspectionPhysicalContext.test.js revision 1 correction after review 2.',
        campaign: f.store.read('inspection_campaigns/installed'), original,
        correction: f.store.read('inspection_observations/reviewed-correction'),
        observations: f.store.entries().filter(([path]) => path.startsWith('inspection_observations/')).map(([, row]) => row),
        findings: f.store.entries().filter(([path]) => path.startsWith('inspection_findings/')).map(([, row]) => row)}, null, 2) + '\n');
  });

  test.each(['missing-audit', 'malformed-json', 'wrong-actor', 'wrong-campaign', 'wrong-revision', 'changed-context'])(
    'historical correction rejects %s audit without writes', async (mode) => {
      const f = await twiceReviewed(); const path = 'inspection_target_audits/review-installed';
      const audit = f.store.read(path);
      if (mode === 'missing-audit') await f.store.runTransaction(async (tx) => tx.delete(path));
      else {
        if (mode === 'malformed-json') audit.afterJson = '{';
        if (mode === 'wrong-actor') audit.performedByUid = 'another-manager';
        if (mode === 'wrong-campaign') audit.campaignId = 'another-campaign';
        if (mode === 'wrong-revision' || mode === 'changed-context') {
          const review = JSON.parse(audit.afterJson);
          if (mode === 'wrong-revision') review.revision = 2;
          else review.context.hostAssetNumber = 207;
          audit.afterJson = JSON.stringify(review);
        }
        f.store.seed(path, audit);
      }
      const before = f.store.entries(); await expect(f.run(f.correction)).rejects.toMatchObject({code: 'failed-precondition'});
      expect(f.store.entries()).toEqual(before);
    });

  test.each(['stale-campaign', 'stale-current-review', 'not-current', 'wrong-target', 'wrong-serial', 'wrong-host',
    'forged-component', 'forged-path', 'missing-removal-time', 'after-removal', 'before-installation',
    'historical-link-serial', 'historical-link-host-class', 'historical-link-host-number', 'historical-link-host-name',
    'historical-link-missing', 'historical-link-version', 'malformed-removal-time'])(
    'baseline correction rejects %s without writes', async (mode) => {
      const f = await installed(); await f.run(reviewInstalled(f.target, relocate(f)));
      const command = f.reading('bad-correction', 3, 2.8);
      command.payload.targetContextRevision = 1; command.payload.supersedesObservationId = 'first';
      if (mode === 'stale-campaign') command.expectedVersion = 2;
      if (mode === 'stale-current-review') command.payload.targetContextRevision = 0;
      if (mode === 'not-current') {
        const newer = f.reading('newer', 3, 2.7, '2026-08-21T06:30:00.000Z');
        newer.payload.targetContextRevision = 1; await f.run(newer); command.expectedVersion = 4;
      }
      if (mode === 'wrong-target') command.payload.targetKey = 'other-target';
      if (mode === 'wrong-serial' || mode === 'wrong-host') f.store.seed('inspection_observations/first', {
        ...f.store.read('inspection_observations/first'), [mode === 'wrong-serial' ? 'subjectSerialNumber' : 'hostAssetInstanceId']: 'other'});
      if (mode === 'forged-component') command.payload.componentName = 'A newer component';
      if (mode === 'forged-path') command.payload.hierarchyPath = ['Other'];
      if (mode === 'after-removal') command.payload.observedAt = '2026-08-21T06:30:00.000Z';
      if (mode === 'before-installation') command.payload.observedAt = '2026-08-21T03:59:00.000Z';
      const linkPath = 'inner_cover_linkages/link-n4-base-205';
      const linkRow = f.store.read(linkPath);
      if (mode === 'missing-removal-time') f.store.seed(linkPath, {...linkRow, removedAt: null});
      if (mode === 'historical-link-serial') f.store.seed(linkPath, {...linkRow, innerCoverSerialNumber: 'N3'});
      if (mode === 'historical-link-host-class') f.store.seed(linkPath, {...linkRow, baseAssetClassId: 'other'});
      if (mode === 'historical-link-host-number') f.store.seed(linkPath, {...linkRow, baseAssetNumber: 999});
      if (mode === 'historical-link-host-name') f.store.seed(linkPath, {...linkRow, baseAssetName: 'Other'});
      if (mode === 'historical-link-version') f.store.seed(linkPath, {...linkRow, version: 0});
      if (mode === 'historical-link-missing') await f.store.runTransaction(async (tx) => tx.delete(linkPath));
      if (mode === 'malformed-removal-time') f.store.seed(linkPath, {...linkRow, removedAt: '2026-02-31T05:50:00.000Z'});
      const before = f.store.entries(); await expect(f.run(command)).rejects.toMatchObject({
        code: mode.startsWith('stale') ? 'aborted' : 'failed-precondition'});
      expect(f.store.entries()).toEqual(before);
    });

  test('another ordinary observer cannot correct an old reading after its context review', async () => {
    const f = await installed(); await f.run(reviewInstalled(f.target, relocate(f)));
    const other = seedActor(f.store, 'other-observer', ['seniorInstrumentation']);
    const command = f.reading('unauthorized-correction', 3, 2.8);
    command.payload.targetContextRevision = 1; command.payload.supersedesObservationId = 'first';
    const before = f.store.entries();
    await expect(f.service.execute(command, {actor: other, serverNow: at('2026-08-21T07:00:00.000Z')}))
      .rejects.toMatchObject({code: 'permission-denied'});
    expect(f.store.entries()).toEqual(before);
  });

  test('same serial on a new Base preserves the target and can use its original canonical repair', async () => {
    const f = await installed(); const {store, run, target, reading} = f;
    await run(canonicalTicket('repair-n4', 'innerCover', 'class-base', 'base-205'));
    await run({commandId: 'resolve-n4', commandType: 'resolveMaintenanceTicket', aggregateId: 'repair-n4', expectedVersion: 1,
      payload: {endDate: '2026-08-21T05:30:00.000Z', remarks: 'Shell repaired.', teamsInvolved: ['instrumentation'], actionsJson: '[]'}});
    const current = relocate(f);
    await run(reviewInstalled(target, current));
    const later = reading('later', 3, 3, '2026-08-21T06:30:00.000Z'); later.payload.targetContextRevision = 1;
    await run(later);
    const recorded = store.read('inspection_observations/later');
    expect(recorded).toMatchObject({targetKey: target.targetKey, assetNumber: 206, subjectSerialNumber: 'N4',
      targetContextRevision: 1, targetContextAuditId: 'review-installed', targetContextOriginalLinkageId: 'link-n4-base-205'});
    // The ticket was canonically created on Base 205; identity follows N4.
    await run(link('installed', 'repair-n4', 'later', 4));
    const finding = store.read('inspection_findings/inspection-finding-first');
    await run({commandId: 'verify-n4', commandType: 'verifyInspectionFinding', aggregateId: 'installed', expectedVersion: 4,
      payload: {findingId: finding.findingId, observationId: 'later', expectedFindingVersion: finding.version, outcome: 'resolved', reason: 'Same serial repair verified.'}});
    expect(store.read('inspection_findings/inspection-finding-first').status).toBe('verifiedResolved');
    expect(store.read('inspection_campaigns/installed').targetPopulation[0]).toMatchObject({...target,
      disposition: 'observed', lastObservationId: 'later', lastObservedAt: later.payload.observedAt, dispositionAt: later.payload.observedAt,
      contextReview: {revision: 1, context: {hostAssetNumber: 206}}});
  });

  test('context review never resets the existing latest-reading pointer for an earlier historical reading', async () => {
    const f = await installed(); const {store, run, target, reading} = f;
    store.seed('inner_cover_profiles/inner-cover-n4', {...store.read('inner_cover_profiles/inner-cover-n4'), version: 8});
    await run(reviewInstalled(target, {...inspectionContextIdentity(target), assetInstanceVersion: 8}));
    const earlier = reading('earlier', 3, 1.7, '2026-08-21T04:30:00.000Z'); earlier.payload.targetContextRevision = 1;
    await run(earlier);
    expect(store.read('inspection_campaigns/installed').targetPopulation[0]).toMatchObject({lastObservationId: 'first', lastObservedAt: '2026-08-21T05:00:00.000Z'});
    expect(store.read('inspection_findings/inspection-finding-first').currentObservationId).toBe('first');
  });

  test('another approved manager cannot dispatch the frozen original review', async () => {
    const f = await installed(); const other = seedActor(f.store, 'other-admin', ['admin']);
    const command = reviewInstalled(f.target, relocate(f)); const before = f.store.entries();
    await expect(f.service.execute(command, {actor: other, serverNow: at('2026-08-21T07:00:00Z')})).rejects.toMatchObject({
      code: 'permission-denied', details: {reasonCode: 'inspection-context-review-actor-changed'}});
    expect(f.store.entries()).toEqual(before);
  });

  test.each(['changed-serial', 'stale-version', 'stale-review-revision', 'wrong-host', 'incompatible-definition', 'exact-class-scope', 'retired-component'])(
    'explicit context review rejects %s without any mutation', async (mode) => {
      const f = await installed(); const {store, run, target} = f;
      const current = relocate(f); const command = reviewInstalled(target, current);
      if (mode === 'changed-serial') store.seed('inner_cover_profiles/inner-cover-n4', {...store.read('inner_cover_profiles/inner-cover-n4'), serialNumber: 'N5'});
      if (mode === 'stale-version') command.payload.reviewedContext.assetInstanceVersion = 7;
      if (mode === 'stale-review-revision') command.payload.expectedContextRevision = 1;
      if (mode === 'wrong-host') store.seed('inner_cover_linkages/link-n4-base-206', {...store.read('inner_cover_linkages/link-n4-base-206'), baseAssetInstanceId: 'base-999'});
      if (mode === 'incompatible-definition') { const c = store.read('inspection_campaigns/installed');
        store.seed('inspection_campaigns/installed', {...c, definition: {...c.definition, componentNodeIds: ['another-component']}}); }
      if (mode === 'exact-class-scope') { const c = store.read('inspection_campaigns/installed');
        store.seed('inspection_campaigns/installed', {...c, definition: {...c.definition, assetClassIds: ['another-class']}}); }
      if (mode === 'retired-component') store.seed('asset_hierarchy_nodes/inner-cover-shell', {...store.read('asset_hierarchy_nodes/inner-cover-shell'), status: 'retired'});
      const before = store.entries(); await expect(run(command)).rejects.toMatchObject({code: mode.startsWith('stale') ? 'aborted' : 'failed-precondition'});
      expect(store.entries()).toEqual(before);
    });

  test.each(['missing-audit', 'tampered-audit', 'before-installation', 'missing-revision'])(
    'follow-up rejects %s instead of silently using the successor', async (mode) => {
      const f = await installed(); const {store, run, target, reading} = f;
      await run(reviewInstalled(target, relocate(f)));
      const later = reading('later', 3, 3, mode === 'before-installation' ? '2026-08-21T05:59:00.000Z' : '2026-08-21T06:30:00.000Z');
      if (mode !== 'missing-revision') later.payload.targetContextRevision = 1;
      if (mode === 'missing-audit') await store.runTransaction(async (tx) => tx.delete('inspection_target_audits/review-installed'));
      if (mode === 'tampered-audit') store.seed('inspection_target_audits/review-installed', {...store.read('inspection_target_audits/review-installed'), performedByUid: 'other-manager'});
      const before = store.entries(); await expect(run(later)).rejects.toMatchObject({code: mode === 'missing-revision' ? 'aborted' : 'failed-precondition'});
      expect(store.entries()).toEqual(before);
    });

  test('real registry revision after repair: original campaign reopens, manager reviews and same finding verifies', async () => {
    const store = new MemoryWorkflowStore(); seedFurnaceHierarchy(store);
    const actor = seedActor(store, 'admin', ['admin']);
    for (const [path, data] of store.entries()) if (path.startsWith('asset_classes/') || path.startsWith('asset_hierarchy_nodes/')) store.seed(path.replaceAll('class-furnace', classId), translate(data));
    store.seed(`asset_classes/${classId}`, {...store.read(`asset_classes/${classId}`), version: 1, code: 'FURNACE', name: 'Furnace'});
    const db = registryAdapter(store);
    const registry = (data) => mutateAssetRegistryWithDb({db, authUid: actor.uid, data,
      now: () => at('2026-08-21T08:00:00.000Z'), timestampFromDate: (date) => date.toISOString()});
    await registry({requestId: '33333333-3333-4333-8333-333333333333', operation: 'CREATE_ASSET_INSTANCE',
      assetClassId: classId, assetInstanceId: assetId, expectedAssetClassVersion: 1, reason: 'Register Furnace.', assetDraft: draft});
    const service = new MaintenanceWorkflowCommandService(store);
    const run = (command) => service.execute(translate(command), {actor, serverNow: at('2026-08-22T09:00:00.000Z')});
    await run(upsertDefinition()); await run(createCampaign({targetAssetNumbers: [1]})); await run(observation());
    await run(canonicalTicket('repair', 'furnace', 'class-furnace', 'furnace-1'));
    await run(link('campaign-furnace-pt-august', 'repair', 'observation-1'));
    await run({commandId: 'resolve-repair', commandType: 'resolveMaintenanceTicket', aggregateId: 'repair', expectedVersion: 1,
      payload: {endDate: '2026-08-21T05:30:00.000Z', remarks: 'Pressure corrected.', teamsInvolved: ['instrumentation'], actionsJson: '[]'}});
    const campaignPath = 'inspection_campaigns/campaign-furnace-pt-august';
    const baseline = structuredClone(store.read(campaignPath).targetPopulation[0]);
    const first = store.read('inspection_observations/observation-1');
    await run({commandId: 'close', commandType: 'setInspectionCampaignStatus', aggregateId: 'campaign-furnace-pt-august', expectedVersion: 2,
      payload: {status: 'closed', reason: 'Repair complete; follow-up will be performed.'}});
    await registry({requestId: '44444444-4444-4444-8444-444444444444', operation: 'UPDATE_ASSET_INSTANCE', assetClassId: classId,
      assetInstanceId: assetId, expectedVersion: 1, reason: 'Update location after repair.', assetDraft: {...draft, location: 'BAF line 2'}});
    expect(store.read(`asset_instances/${assetId}`).version).toBe(2);
    await run({commandId: 'reopen', commandType: 'setInspectionCampaignStatus', aggregateId: 'campaign-furnace-pt-august', expectedVersion: 3,
      payload: {status: 'open', reason: 'Perform follow-up on the same physical Furnace.'}});
    const followup = observation({commandId: 'followup', observationId: 'followup', expectedVersion: 4, numericValue: 2.8, observedAt: '2026-08-22T06:00:00.000Z'});
    await expect(run(followup)).rejects.toMatchObject({code: 'failed-precondition'});
    const review = {commandId: 'review', commandType: 'revalidateInspectionTargetContext', aggregateId: 'campaign-furnace-pt-august', expectedVersion: 4,
      payload: {reviewerUid: 'admin', targetKey: baseline.targetKey, expectedContextRevision: 0,
        reviewedContext: {...inspectionContextIdentity(baseline), assetInstanceVersion: 2}, reason: 'Verified the same Furnace after its location record changed.'}};
    const observer = seedActor(store, 'observer', ['seniorInstrumentation']);
    await expect(service.execute(review, {actor: observer, serverNow: at('2026-08-22T09:00:00Z')})).rejects.toMatchObject({code: 'permission-denied'});
    const accepted = await run(review);
    expect(accepted.resultKey).toBe('inspection-target-context-revalidated');
    expect(store.read(campaignPath).targetPopulation[0]).toMatchObject({...baseline, contextReview: {revision: 1}});
    expect(store.read('inspection_observations/observation-1')).toEqual(first);
    await expect(run({...followup, expectedVersion: 5})).rejects.toMatchObject({code: 'aborted', details: {reasonCode: 'inspection-context-review-stale'}});
    await run({...followup, expectedVersion: 5, payload: {...followup.payload, targetContextRevision: 1}});
    expect(store.read(campaignPath).targetPopulation[0].lastObservationId).toBe('followup');
    const finding = store.read('inspection_findings/inspection-finding-observation-1');
    await run({commandId: 'verify', commandType: 'verifyInspectionFinding', aggregateId: 'campaign-furnace-pt-august', expectedVersion: 6,
      payload: {findingId: finding.findingId, observationId: 'followup', expectedFindingVersion: finding.version, outcome: 'resolved', reason: 'Repair effectiveness verified.'}});
    expect(store.read('inspection_findings/inspection-finding-observation-1').status).toBe('verifiedResolved');
    const final = store.entries(); expect(await run(review)).toEqual(accepted); expect(store.entries()).toEqual(final);
  });
});
