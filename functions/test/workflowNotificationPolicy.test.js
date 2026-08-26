const {
  isNotifiableCriticalAlarmStatus,
  samePersistedNotificationInstant,
  shouldRetryKnownWorkflowNotificationFailure,
  workflowRecipientRoles,
} = require('../lib/maintenanceWorkflow/workflowNotificationPolicy');
const {
  LANE_POLICY,
  WORKFLOW_ROLE_UNIVERSE,
} = require('../lib/maintenanceWorkflow/policy.generated');

describe('workflow notification routing', () => {
  test.each(Object.keys(LANE_POLICY))(
    '%s routing is the generated lane-authority union',
    (laneKey) => {
      const lane = LANE_POLICY[laneKey];
      const expected = new Set([
        'admin',
        'si',
        ...lane.ackRoles,
        ...lane.workRoles,
        ...lane.closeRoles,
      ]);
      expect(new Set(workflowRecipientRoles('lane.updated', laneKey))).toEqual(
        expected,
      );
    },
  );

  test('equipment events reach governance and operations coordination', () => {
    expect(workflowRecipientRoles('equipment.updated', null)).toEqual(
      expect.arrayContaining(['admin', 'si', 'shiftSupervisor', 'operations']),
    );
  });

  test('generated workflow role universe covers every lane role', () => {
    const universe = new Set(WORKFLOW_ROLE_UNIVERSE);
    for (const lane of Object.values(LANE_POLICY)) {
      for (const role of [
        ...lane.ackRoles,
        ...lane.workRoles,
        ...lane.closeRoles,
      ]) {
        expect(universe.has(role)).toBe(true);
      }
    }
  });
  test('escalation routing follows the ratified tier ladder', () => {
    expect(workflowRecipientRoles('lane.escalated', 'elec', 1)).toEqual(['seniorElectrical']);
    expect(workflowRecipientRoles('compliance.acknowledgementEscalated', 'oprn', 1)).toEqual(['shiftSupervisor']);
    expect(workflowRecipientRoles('compliance.completionEscalated', 'red', 1)).toEqual(['seniorRefractory']);
    expect(new Set(workflowRecipientRoles('lane.escalated', 'mech', 2))).toEqual(
      new Set(['shiftSupervisor', 'si']),
    );
    expect(workflowRecipientRoles('lane.escalated', 'inst', 3)).toEqual(['admin']);
  });

  test('a delayed raised event cannot restart ringing after support confirmation', () => {
    expect(isNotifiableCriticalAlarmStatus('raised')).toBe(true);
    expect(isNotifiableCriticalAlarmStatus('supportConfirmed')).toBe(false);
    expect(isNotifiableCriticalAlarmStatus('resolved')).toBe(false);
    expect(isNotifiableCriticalAlarmStatus('withdrawnInError')).toBe(false);
  });

  test('critical notification evidence compares Firestore instants by value', () => {
    const first = {toMillis: () => 1787731200000};
    const same = {toMillis: () => 1787731200000};
    const later = {toMillis: () => 1787731200001};
    expect(first).not.toBe(same);
    expect(samePersistedNotificationInstant(first, same)).toBe(true);
    expect(samePersistedNotificationInstant(first, later)).toBe(false);
    expect(samePersistedNotificationInstant(first, '2026-08-26T08:00:00.000Z'))
      .toBe(false);
    expect(samePersistedNotificationInstant(
      first,
      {toMillis: () => Number.NaN},
    )).toBe(false);
  });

  test('critical fan-out retries only when every attempted delivery failed retryably', () => {
    const allRetryable = {
      attempted: 3,
      succeeded: 0,
      failed: 3,
      retryableFailures: 3,
      staleTokensCleared: 0,
      unknownAgencies: [],
    };
    expect(shouldRetryKnownWorkflowNotificationFailure(
      'criticalAlarm.raised',
      allRetryable,
    )).toBe(true);
    expect(shouldRetryKnownWorkflowNotificationFailure(
      'criticalAlarm.raised',
      {...allRetryable, succeeded: 1, failed: 2, retryableFailures: 2},
    )).toBe(false);
    expect(shouldRetryKnownWorkflowNotificationFailure(
      'criticalAlarm.raised',
      {...allRetryable, attempted: 0, failed: 0, retryableFailures: 0},
    )).toBe(false);
  });

});
