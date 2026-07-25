const {
  ESCALATION_SUPPRESSION_MINUTES,
  MAX_ESCALATION_TIER,
  escalationEventId,
  escalationEventType,
  nextEscalationTier,
} = require('../lib/maintenanceWorkflow/escalationPolicy');

describe('maintenance workflow escalation policy', () => {
  test('advances one tier when eligible', () => {
    expect(nextEscalationTier({currentTier: 0, lastEscalatedAtMillis: null, nowMillis: 1000})).toBe(1);
    expect(nextEscalationTier({currentTier: 2, lastEscalatedAtMillis: null, nowMillis: 1000})).toBe(3);
  });

  test('never re-escalates beyond the final tier', () => {
    expect(nextEscalationTier({currentTier: MAX_ESCALATION_TIER, lastEscalatedAtMillis: null, nowMillis: 1000})).toBeNull();
  });

  test('suppresses overlapping or jittered sweeps', () => {
    const now = 1_000_000;
    const insideGuard = now - (ESCALATION_SUPPRESSION_MINUTES * 60 * 1000) + 1;
    expect(nextEscalationTier({currentTier: 1, lastEscalatedAtMillis: insideGuard, nowMillis: now})).toBeNull();
  });

  test('emits deterministic event identity and event type', () => {
    expect(escalationEventType('job_lanes', 'pending')).toBe('lane.escalated');
    expect(escalationEventType('compliance_requests', 'raised')).toBe('compliance.acknowledgementEscalated');
    expect(escalationEventType('compliance_requests', 'acknowledged')).toBe('compliance.completionEscalated');
    expect(escalationEventId({collectionId: 'job_lanes', documentId: 'wf_1_elec', tier: 2}))
      .toBe('escalation_job_lanes_wf_1_elec_tier_2');
  });
});
