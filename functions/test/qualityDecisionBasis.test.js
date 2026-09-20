const {
  decisionBasisChange,
  decisionSubjects,
  warningDecisionBasisStale,
} = require('../lib/qualityDecisionBasis');

function innerCoverAssociation(overrides = {}) {
  return {
    baseAssetInstanceId: 'base-12',
    baseAssetNumber: 12,
    positionState: 'linked',
    innerCoverId: 'cover-n3',
    innerCoverSerialNumber: 'N3',
    linkageId: 'link-1',
    assignmentVersion: 4,
    linkedAt: '2026-07-01T06:00:00.000Z',
    eventAt: '2026-07-01T06:00:00.000Z',
    confirmedAt: '2026-07-01T06:05:00.000Z',
    confirmedByUid: 'operator-1',
    confirmedByName: 'Operator One',
    ...overrides,
  };
}

function governedSubject(overrides = {}, association = innerCoverAssociation()) {
  return {
    assetType: 'base',
    assetNumber: 12,
    assetHierarchyRef: {
      schemaVersion: 4,
      scope: 'physicalAsset',
      assetClassId: 'base-class',
      assetClassCode: 'BASE',
      assetClassName: 'Base',
      nodeId: 'base-12',
      nodeVersion: 2,
      nodeName: 'Base 12',
      assetInstanceId: 'base-12',
      assetInstanceVersion: 3,
      assetNumber: 12,
      assetInstanceName: 'Base 12',
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: ['Base', 'Base 12'],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Operations',
      accountableRoleKeys: ['operations'],
      innerCoverAssociation: association,
      ...overrides,
    },
  };
}

function record(overrides = {}) {
  return {
    abnormalityTypeId: 'TYPE_OLD',
    severity: 'medium',
    component: 'Atmosphere control',
    observedReason: 'Original observation',
    affectedAssets: [
      {assetType: 'furnace', assetNumber: 7},
      {assetType: 'base', assetNumber: 12},
    ],
    affectedAssetHierarchyRefs: [governedSubject()],
    ...overrides,
  };
}

describe('what a quality decision was made about', () => {
  test('the same subjects in another order describe one case', () => {
    expect(decisionBasisChange(record(), record({
      affectedAssets: [
        {assetType: 'base', assetNumber: 12},
        {assetType: 'furnace', assetNumber: 7},
      ],
    }))).toBeNull();
  });

  test('an absent optional value and an explicit null are one value', () => {
    const absent = record();
    delete absent.component;
    expect(decisionBasisChange(absent, record({component: null}))).toBeNull();
    expect(decisionBasisChange(record({component: null}), absent)).toBeNull();
  });

  test.each([
    ['a renamed asset', {assetInstanceName: 'Base 12 (north)'}],
    ['a republished class', {assetClassName: 'Base frame', assetClassCode: 'BS'}],
    ['a bumped revision', {assetInstanceVersion: 9, nodeVersion: 7}],
    ['a redrawn hierarchy path', {hierarchyPath: ['Plant', 'Base', 'Base 12']}],
    ['a transferred ownership label', {ownerDiscipline: 'Mechanical'}],
  ])('%s is not a change of evidence', (_label, overrides) => {
    expect(decisionBasisChange(record(), record({
      affectedAssetHierarchyRefs: [governedSubject(overrides)],
    }))).toBeNull();
  });

  test('a corrected Inner Cover serial is a label, not a subject', () => {
    expect(decisionBasisChange(record(), record({
      affectedAssetHierarchyRefs: [governedSubject({}, innerCoverAssociation({
        innerCoverSerialNumber: 'N-3',
        assignmentVersion: 5,
        confirmedByName: 'Operator Two',
      }))],
    }))).toBeNull();
  });

  test.each([
    ['another Inner Cover on the same base', governedSubject({}, innerCoverAssociation({
      innerCoverId: 'cover-n4',
      innerCoverSerialNumber: 'N4',
      linkageId: 'link-2',
    }))],
    ['no Inner Cover at all', governedSubject({}, innerCoverAssociation({
      positionState: 'noneLinked',
      innerCoverId: null,
      linkageId: null,
    }))],
    ['another component on the same asset', governedSubject({
      scope: 'componentDefinitionOnAsset',
      nodeId: 'recuperator',
      nodeName: 'Recuperator',
    })],
  ])('%s changes the recorded physical subject', (_label, subject) => {
    expect(decisionBasisChange(record(), record({
      affectedAssetHierarchyRefs: [subject],
    }))).toBe('affectedAssetHierarchyRefs');
  });

  test('a different asset changes the subjects themselves', () => {
    expect(decisionBasisChange(record(), record({
      affectedAssets: [
        {assetType: 'furnace', assetNumber: 7},
        {assetType: 'base', assetNumber: 13},
      ],
      affectedAssetHierarchyRefs: [],
    }))).toBe('affectedAssets');
  });

  test.each([
    ['severity', {severity: 'critical'}],
    ['abnormalityTypeId', {abnormalityTypeId: 'TYPE_NEW'}],
    ['observedReason', {observedReason: 'A different observation'}],
    ['component', {component: 'Burner assembly'}],
  ])('%s is evidence a decision rests on', (field, overrides) => {
    expect(decisionBasisChange(record(), record(overrides))).toBe(field);
  });

  test('subjects are listed once the same way whatever their order', () => {
    expect(decisionSubjects(record())).toEqual(decisionSubjects(record({
      affectedAssets: [
        {assetType: 'base', assetNumber: 12},
        {assetType: 'furnace', assetNumber: 7},
      ],
    })));
  });
});

describe('whether a warning still describes its case', () => {
  const warning = (overrides = {}) => ({
    sourceSummary: 'Atmosphere deviation',
    sourceSeverity: 'medium',
    warningReason: 'Original observation',
    component: 'Atmosphere control',
    affectedAssets: [
      {assetType: 'furnace', assetNumber: 7},
      {assetType: 'base', assetNumber: 12},
    ],
    ...overrides,
  });

  test('a classification renamed in the master is not a difference', () => {
    expect(warningDecisionBasisStale(
      warning({sourceSummary: 'The title it used to carry'}),
      record(),
    )).toBe(false);
  });

  test('a warning that records the subjects in another order agrees', () => {
    expect(warningDecisionBasisStale(
      warning({affectedAssets: [
        {assetType: 'base', assetNumber: 12},
        {assetType: 'furnace', assetNumber: 7},
      ]}),
      record(),
    )).toBe(false);
  });

  test('the governed context the warning never recorded is not a difference', () => {
    expect(warningDecisionBasisStale(warning(), record({
      affectedAssetHierarchyRefs: [governedSubject({}, innerCoverAssociation({
        innerCoverId: 'cover-n4',
      }))],
    }))).toBe(false);
  });

  test.each([
    ['severity', {sourceSeverity: 'critical'}],
    ['observation', {warningReason: 'A different observation'}],
    ['component', {component: 'Burner assembly'}],
    ['subjects', {affectedAssets: [{assetType: 'furnace', assetNumber: 7}]}],
  ])('a warning carrying a different %s has been outgrown', (_label, overrides) => {
    expect(warningDecisionBasisStale(warning(overrides), record())).toBe(true);
  });
});
