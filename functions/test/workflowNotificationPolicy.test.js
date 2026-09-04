const {
  complianceHandoverRecipientRoles,
  complianceHandoverSide,
  isCriticalAlarmEventType,
  isNotifiableCriticalAlarmStatus,
  samePersistedNotificationInstant,
  shouldRetryCriticalAlarmRecipientFailure,
  shouldRetryKnownWorkflowNotificationFailure,
  workflowRecipientRoles,
} = require('../lib/maintenanceWorkflow/workflowNotificationPolicy');
const {
  LANE_POLICY,
  WORKFLOW_ROLE_UNIVERSE,
} = require('../lib/maintenanceWorkflow/policy.generated');

describe('workflow notification routing', () => {
  const request = {linkedWorkflowId: 'workflow-1', originLaneKey: 'mech',
    targetLaneKey: 'oprn', raisedUnderCoordination: true};

  test.each(['issue.coordinationStarted', 'compliance.raised',
    'compliance.returnedForCorrection', 'compliance.counterAccepted',
    'compliance.confirmedClosed', 'red.preparationConfirmed'])(
    '%s reaches Operations rather than the event actor lane', (type) => {
      const roles = complianceHandoverRecipientRoles(type, 'workflow-1', request);
      expect(roles).toEqual(expect.arrayContaining(['operations', 'shiftSupervisor', 'admin', 'si']));
      expect(roles).not.toContain('seniorMechanical');
    },
  );
  test.each(['compliance.acknowledged', 'compliance.complied',
    'compliance.conditionConfirmedAndWorkReactivated', 'compliance.counterProposed'])(
    '%s reaches the origin and authorized coordinating supervisor', (type) => {
      expect(complianceHandoverRecipientRoles(type, 'workflow-1', request))
        .toEqual(expect.arrayContaining(['seniorMechanical', 'contractSupervisor', 'shiftSupervisor', 'admin', 'si']));
      expect(complianceHandoverRecipientRoles(type, 'workflow-1', {...request, raisedUnderCoordination: false}))
        .not.toContain('contractSupervisor');
    },
  );
  test('handover skips missing, deleted, foreign and invalid requests', () => {
    for (const invalid of [null, {...request, isDeleted: true},
      {...request, linkedWorkflowId: 'other-workflow'}, {...request, targetLaneKey: 'invalid'},
      {...request, targetLaneKey: 'toString'}]) {
      expect(complianceHandoverRecipientRoles('issue.coordinationStarted', 'workflow-1', invalid)).toBeNull();
    }
    expect(complianceHandoverRecipientRoles('compliance.complied', 'workflow-1', {...request, originLaneKey: null}))
      .toEqual(['admin', 'si']);
    expect(complianceHandoverSide('compliance.completionEscalated')).toBeNull();
  });

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

  test('non-raise critical-alarm events never enter generic maintenance routing', () => {
    expect(isCriticalAlarmEventType('criticalAlarm.raised')).toBe(true);
    expect(isCriticalAlarmEventType('criticalAlarm.detailsProvided')).toBe(true);
    expect(isCriticalAlarmEventType('criticalAlarm.supportConfirmed')).toBe(true);
    expect(isCriticalAlarmEventType('criticalAlarm.resolved')).toBe(true);
    expect(isCriticalAlarmEventType('criticalAlarm.withdrawnInError')).toBe(true);
    expect(isCriticalAlarmEventType('lane.closed')).toBe(false);
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

  test('critical alarm retries an exact failed recipient delivery', () => {
    const retryableRecipient = {
      attempted: 1,
      succeeded: 0,
      failed: 1,
      retryableFailures: 1,
      staleTokensCleared: 0,
      unknownAgencies: [],
    };
    expect(shouldRetryCriticalAlarmRecipientFailure(retryableRecipient))
      .toBe(true);
    expect(shouldRetryCriticalAlarmRecipientFailure({
      ...retryableRecipient,
      succeeded: 1,
      failed: 0,
      retryableFailures: 0,
    })).toBe(false);
    expect(shouldRetryCriticalAlarmRecipientFailure({
      ...retryableRecipient,
      attempted: 2,
      failed: 2,
      retryableFailures: 2,
    })).toBe(false);
  });

});
