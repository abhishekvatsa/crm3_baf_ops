const {governedCaseRefusalLogFields} = require('../lib/governedCaseRefusalLog');

describe('governed quality-case refusal log fields', () => {
  test('keeps identifiers and the structured refusal reason', () => {
    expect(governedCaseRefusalLogFields({
      requestId: '11111111-1111-4111-8111-111111111111',
      operation: 'CLOSE_QUALITY_WARNING',
      warningId: 'abnormality_abn-1',
      expectedVersion: 2,
      reason: 'Decision text written by the adjudicator',
    }, {
      code: 'failed-precondition',
      details: {
        reasonCode: 'charge-quality-case-malformed',
        field: 'warningProjection',
      },
    })).toEqual({
      code: 'failed-precondition',
      operation: 'CLOSE_QUALITY_WARNING',
      requestId: '11111111-1111-4111-8111-111111111111',
      warningId: 'abnormality_abn-1',
      reasonCode: 'charge-quality-case-malformed',
      field: 'warningProjection',
    });
  });

  test('keeps the specific cause behind a wrapped creation refusal', () => {
    expect(governedCaseRefusalLogFields({
      requestId: '77777777-7777-4777-8777-777777777777',
      operation: 'CREATE',
      abnormalityId: 'abn-1',
    }, {
      code: 'invalid-argument',
      details: {
        reasonCode: 'abnormality-create-payload-invalid',
        causeReasonCode: 'duplicate-asset-hierarchy-reference',
        field: 'affectedAssetHierarchyRefs',
      },
    })).toEqual({
      code: 'invalid-argument',
      operation: 'CREATE',
      requestId: '77777777-7777-4777-8777-777777777777',
      abnormalityId: 'abn-1',
      reasonCode: 'abnormality-create-payload-invalid',
      causeReasonCode: 'duplicate-asset-hierarchy-reference',
      field: 'affectedAssetHierarchyRefs',
    });
  });

  test('never copies free text, nested evidence or malformed identifiers', () => {
    expect(governedCaseRefusalLogFields({
      operation: 'close the warning',
      requestId: 'r'.repeat(201),
      abnormalityId: 'abn 1',
      abnormality: {
        observedReason: 'Observation text',
        loggedByName: 'Operator One',
      },
    }, {
      code: 'invalid-argument',
      details: {
        reasonCode: 'Not A Code',
        causeReasonCode: 'Observation text',
        field: 'affectedAssets[0] with spaces',
      },
    })).toEqual({code: 'invalid-argument'});
  });

  test('tolerates missing request data and details', () => {
    expect(governedCaseRefusalLogFields(undefined, {code: 'data-loss'}))
      .toEqual({code: 'data-loss'});
  });
});
