'use strict';

const {createHash} = require('crypto');
const {parseConditionBasis, verifyConditionBasis} = require('../lib/burnerConditionBasis');

const ASSET = 'furnace-7';
const CLASS = 'class-furnace';
const TIME = '2026-09-20T08:00:00.000Z';
const empty = () => ({expectedInstallationBasis: {burner: [], uv: []}, expectedOpenIssueBasis: []});

function projection(kind, position, overrides = {}) {
  const prefix = kind === 'burner' ? 'bblc' : 'uvlc';
  const projectionId = `${prefix}_${createHash('sha256').update(`${ASSET}|${position}`).digest('hex').slice(0, 40)}`;
  const eventId = `${kind}-event-${position}`;
  return {id: projectionId, value: {
    schemaVersion: 1, projectionSchemaVersion: 1, projectionId,
    assetInstanceId: ASSET, burnerPosition: position, eventId, currentEventId: eventId,
    installationDiscipline: kind === 'burner' ? 'mechanical' : 'instrumentation',
    ...(kind === 'uv' ? {resultingCondition: 'serviceable'} : {}),
    actionPerformedAt: TIME, isDeleted: false, ...overrides,
  }};
}

function issue(overrides = {}) {
  return {id: 'issue-1', value: {firestoreId: 'issue-1', assetType: 'furnace', assetNumber: 7,
    status: 'open', isResolved: false, isDeleted: false, burnerRedHotPositions: [3],
    version: 2, updatedAt: TIME, ...overrides}};
}

function reference(overrides = {}) {
  return JSON.stringify({schemaVersion: 3, scope: 'physicalAsset',
    assetClassId: CLASS, assetClassCode: 'FR', assetClassName: 'Furnace',
    nodeId: ASSET, nodeVersion: 1, nodeName: 'Furnace 7',
    assetInstanceId: ASSET, assetInstanceVersion: 1, assetNumber: 7, assetInstanceName: 'Furnace 7',
    componentInstanceId: null, componentInstanceVersion: null, componentTag: null,
    hierarchyPath: ['Furnace', 'Furnace 7'], ownershipStatus: 'confirmed',
    ownerDiscipline: 'Operations', accountableRoleKeys: ['operations'], innerCoverAssociation: null,
    ...overrides});
}

function definitionReference(overrides = {}) {
  return reference({schemaVersion: 2, scope: 'definition', nodeId: 'burner-system', nodeName: 'Burner system',
    assetInstanceId: null, assetInstanceVersion: null, assetNumber: null, assetInstanceName: null,
    ...overrides});
}

function fixture(records = {}) {
  const reads = [];
  const collections = {
    asset_classes: [{id: CLASS, value: {schemaVersion: 1, assetClassId: CLASS, legacyAssetTypeKey: 'furnace'}}],
    asset_instances: [{id: ASSET, value: {schemaVersion: 1, assetInstanceId: ASSET, assetClassId: CLASS, assetNumber: 7}}],
    ...records,
  };
  return {
    reads,
    db: {collection: (collection) => ({where: (field, op, value) => ({collection, field, op, value})})},
    transaction: {get: async (query) => {
      reads.push(query);
      return {docs: (collections[query.collection] ?? [])
        .filter((row) => row.value[query.field] === query.value)
        .map((row) => ({exists: true, id: row.id, data: () => row.value}))};
    }},
  };
}

function expectedFor(kind, position, overrides = {}) {
  return {position, eventId: `${kind}-event-${position}`, actionPerformedAt: TIME, ...overrides};
}

async function verify(records, expected = empty()) {
  const setup = fixture(records);
  await verifyConditionBasis({...setup, request: {assetClassId: CLASS, assetInstanceId: ASSET, ...expected}, assetNumber: 7});
  return setup;
}

describe('reviewed burner condition dependencies', () => {
  test('empty confirmed sources are checked in the same transaction', async () => {
    const {reads} = await verify({});
    expect(reads.map((row) => [row.collection, row.field, row.value])).toEqual([
      ['burner_block_lifecycle_current', 'assetInstanceId', ASSET],
      ['uv_detector_lifecycle_current', 'assetInstanceId', ASSET],
      ['maintenance_records', 'assetType', 'furnace'],
      ['asset_classes', 'legacyAssetTypeKey', 'furnace'],
      ['asset_instances', 'assetNumber', 7],
    ]);
  });

  test('basis sorts identities and normalizes supported timestamp representations', async () => {
    const timestamp = {seconds: Date.parse(TIME) / 1000, nanoseconds: 0};
    const expected = {
      expectedInstallationBasis: {
        burner: [expectedFor('burner', 5), expectedFor('burner', 3)],
        uv: [expectedFor('uv', 2)],
      },
      expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}],
    };
    await expect(verify({
      burner_block_lifecycle_current: [projection('burner', 3, {actionPerformedAt: timestamp}), projection('burner', 5)],
      uv_detector_lifecycle_current: [projection('uv', 2, {actionPerformedAt: new Date(TIME)})],
      maintenance_records: [issue({updatedAt: timestamp})],
    }, expected)).resolves.toBeDefined();
    expect(parseConditionBasis(expected).expectedInstallationBasis.burner.map((row) => row.position)).toEqual([3, 5]);
  });

  test.each([
    ['new installation', {eventId: 'later-event', currentEventId: 'later-event'}],
    ['corrected effective installation time', {actionPerformedAt: '2026-09-19T08:00:00.000Z'}],
    ['inconsistent current identity', {currentEventId: 'different-event'}],
    ['wrong projection identity', {projectionId: 'wrong-projection'}],
  ])('%s refuses the reviewed installation basis', async (_, changed) => {
    await expect(verify({burner_block_lifecycle_current: [projection('burner', 3, changed)]}, {
      ...empty(), expectedInstallationBasis: {burner: [expectedFor('burner', 3)], uv: []},
    })).rejects.toMatchObject({code: 'aborted', details: {reasonCode: 'burner-condition-round-installation-basis-mismatch'}});
  });

  test('a newly installed UV detector invalidates an empty reviewed UV basis', async () => {
    await expect(verify({uv_detector_lifecycle_current: [projection('uv', 3)]}))
      .rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-installation-basis-mismatch'}});
  });

  test('duplicate current positions fail closed', async () => {
    await expect(verify({burner_block_lifecycle_current: [projection('burner', 3), projection('burner', 3)]}, {
      ...empty(), expectedInstallationBasis: {burner: [expectedFor('burner', 3)], uv: []},
    })).rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-installation-basis-mismatch'}});
  });

  test.each([
    ['new issue', [issue()], []],
    ['new issue version', [issue({version: 3})], [{id: 'issue-1', version: 2, updatedAt: TIME}]],
    ['issue timestamp change', [issue({updatedAt: '2026-09-20T09:00:00.000Z'})], [{id: 'issue-1', version: 2, updatedAt: TIME}]],
    ['issue closed after review', [issue({status: 'resolved', isResolved: true})], [{id: 'issue-1', version: 2, updatedAt: TIME}]],
    ['malformed red-hot scope', [issue({burnerRedHotPositions: '3'})], []],
  ])('%s refuses the reviewed open-issue basis', async (_, records, expectedIssues) => {
    await expect(verify({maintenance_records: records}, {...empty(), expectedOpenIssueBasis: expectedIssues}))
      .rejects.toMatchObject({code: 'aborted', details: {reasonCode: 'burner-condition-round-issue-basis-mismatch'}});
  });

  test('closed, deleted, unrelated-asset and non-red-hot issues are excluded', async () => {
    await expect(verify({maintenance_records: [
      issue({status: 'closedWithoutResolution', isResolved: true}),
      issue({isDeleted: true}), issue({assetType: 'base'}), issue({assetNumber: 8}),
      issue({burnerRedHotPositions: []}),
    ]})).resolves.toBeDefined();
  });

  test.each([
    ['current physical asset', {assetHierarchyRefJson: reference()}],
    ['same physical asset before renumbering', {assetNumber: 6, assetHierarchyRefJson: reference({assetNumber: 6})}],
    ['legacy number-only evidence', {}],
    ['legacy schema-1 definition evidence', {assetHierarchyRefJson: definitionReference({schemaVersion: 1, scope: undefined})}],
    ['legacy schema-2 definition evidence', {assetHierarchyRefJson: definitionReference()}],
    ['retained administrative closure', {assetHierarchyRefJson: reference(), status: 'closedWithoutResolution', isResolved: true,
      issueClosureSchemaVersion: 1, issueClosureDisposition: 'stillRelevant'}],
  ])('%s remains part of the reviewed red-hot basis', async (_, fields) => {
    const records = {maintenance_records: [issue(fields)]};
    await expect(verify(records, {...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}]}))
      .resolves.toBeDefined();
    await expect(verify(records)).rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-issue-basis-mismatch'}});
  });

  test.each([
    ['retired different instance sharing the number', {assetHierarchyRefJson: reference({assetInstanceId: 'retired-furnace', nodeId: 'retired-furnace'})}],
    ['retired different class sharing the number', {assetHierarchyRefJson: reference({assetClassId: 'retired-class'})}],
    ['definition in another class', {assetHierarchyRefJson: definitionReference({assetClassId: 'retired-class'})}],
    ['administrative relevance ended', {status: 'closedWithoutResolution', isResolved: true,
      issueClosureSchemaVersion: 1, issueClosureDisposition: 'relevanceEnded'}],
  ])('%s does not transfer a concern onto the current Furnace', async (_, fields) => {
    await expect(verify({maintenance_records: [issue(fields)]})).resolves.toBeDefined();
  });

  test.each([
    ['invalid JSON', 'bad-json'], ['array reference', '[]'],
    ['missing identity', '{}'], ['wrong source number', reference({assetNumber: 6})],
    ['contradictory physical node', reference({nodeId: 'other-furnace'})],
    ['definition claiming a physical instance', definitionReference({assetInstanceId: 'retired-furnace'})],
  ])('%s cannot fall back to the legacy number', async (_, raw) => {
    await expect(verify({maintenance_records: [issue({assetHierarchyRefJson: raw})]}))
      .rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-issue-basis-mismatch'}});
  });

  test('a retired Furnace class makes unreferenced legacy evidence ambiguous', async () => {
    const records = {maintenance_records: [issue()], asset_classes: [
      {id: CLASS, value: {assetClassId: CLASS, legacyAssetTypeKey: 'furnace', status: 'active'}},
      {id: 'old-class', value: {assetClassId: 'old-class', legacyAssetTypeKey: 'furnace', status: 'retired'}},
    ]};
    await expect(verify(records, {...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}]}))
      .rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-issue-basis-mismatch'}});
    records.maintenance_records = [issue({assetHierarchyRefJson: definitionReference()})];
    await expect(verify(records, {...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}]}))
      .resolves.toBeDefined();
  });

  test.each([undefined, definitionReference()])('a reused asset number cannot establish legacy physical identity: %s', async (raw) => {
    const records = {maintenance_records: [issue({assetHierarchyRefJson: raw})], asset_instances: [
      {id: ASSET, value: {assetInstanceId: ASSET, assetClassId: CLASS, assetNumber: 7, status: 'active'}},
      {id: 'old-furnace', value: {assetInstanceId: 'old-furnace', assetClassId: CLASS, assetNumber: 7, status: 'retired'}},
    ]};
    await expect(verify(records, {...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}]}))
      .rejects.toMatchObject({details: {reasonCode: 'burner-condition-round-issue-basis-mismatch'}});
    records.maintenance_records = [issue({assetHierarchyRefJson: reference()})];
    await expect(verify(records, {...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 2, updatedAt: TIME}]}))
      .resolves.toBeDefined();
  });

  test.each([
    [{expectedInstallationBasis: {burner: []}}],
    [{...empty(), expectedInstallationBasis: {burner: [expectedFor('burner', 3), expectedFor('burner', 3)], uv: []}}],
    [{...empty(), expectedInstallationBasis: {burner: [expectedFor('burner', 9)], uv: []}}],
    [{...empty(), expectedInstallationBasis: {burner: [expectedFor('burner', 3, {extra: 'unsupported'})], uv: []}}],
    [{...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 1, updatedAt: 'not a date'}]}],
    [{...empty(), expectedOpenIssueBasis: [{id: 'issue-1', version: 1, updatedAt: TIME}, {id: 'issue-1', version: 1, updatedAt: TIME}]}],
  ])('malformed reviewed basis is not accepted: %j', (raw) => {
    expect(() => parseConditionBasis(raw)).toThrow(expect.objectContaining({code: 'invalid-argument'}));
  });
});
