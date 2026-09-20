const {
  qualityCaseHealth,
  withQualityCaseHealth,
} = require('../lib/qualityCaseHealth');

describe('quality case health', () => {
  test.each([
    ['charge-quality-case-malformed', 'caseAndWarningDisagree'],
    ['quality-warning-malformed', 'recordUnreadable'],
    ['charge-quality-abnormality-malformed', 'recordUnreadable'],
    ['abnormality-record-malformed', 'recordUnreadable'],
    ['charge-quality-abnormality-missing', 'evidenceUnavailable'],
    ['quality-replay-evidence-malformed', 'evidenceUnavailable'],
    ['abnormality-replay-evidence-drift', 'evidenceUnavailable'],
    [
      'quality-replay-accepted-linked-history-unavailable',
      'evidenceUnavailable',
    ],
    ['charge-quality-decision-reopen-required', 'decisionClosed'],
    ['charge-quality-case-postcondition-failed', 'caseNotCreatable'],
    ['duplicate-asset-hierarchy-reference', 'repeatedSubjectReference'],
  ])('%s is reported as %s', (reasonCode, caseHealth) => {
    expect(qualityCaseHealth({reasonCode})).toBe(caseHealth);
  });

  test('a wrapped refusal is classified by the cause it kept', () => {
    expect(qualityCaseHealth({
      reasonCode: 'abnormality-create-payload-invalid',
      causeReasonCode: 'duplicate-asset-hierarchy-reference',
    })).toBe('repeatedSubjectReference');
  });

  test('a refusal that classifies itself keeps its own category', () => {
    // Nothing was written, so the creation refusal is not reported as two
    // stored records disagreeing.
    expect(qualityCaseHealth({
      reasonCode: 'charge-quality-case-postcondition-failed',
      causeReasonCode: 'charge-quality-case-malformed',
      field: 'warningProjection',
    })).toBe('caseNotCreatable');
  });

  test.each([
    ['a refusal about authority', {reasonCode: 'quality-authority-required'}],
    ['a version conflict', {reasonCode: 'quality-version-conflict'}],
    ['details without a reason', {field: 'severity'}],
    ['no details', undefined],
    ['a non-object', 'charge-quality-case-malformed'],
    ['an array', ['charge-quality-case-malformed']],
  ])('%s says nothing about case health', (_label, details) => {
    expect(qualityCaseHealth(details)).toBeNull();
  });

  test('the category joins the details a refusal already carries', () => {
    expect(withQualityCaseHealth({
      reasonCode: 'charge-quality-decision-reopen-required',
      field: 'severity',
    })).toEqual({
      reasonCode: 'charge-quality-decision-reopen-required',
      field: 'severity',
      caseHealth: 'decisionClosed',
    });
  });

  test('details that say nothing about a case are passed through unchanged', () => {
    const details = {reasonCode: 'quality-authority-required'};
    expect(withQualityCaseHealth(details)).toBe(details);
    expect(withQualityCaseHealth(undefined)).toBeUndefined();
  });
});
