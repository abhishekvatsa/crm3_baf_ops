const {
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

});
