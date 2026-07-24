const {
  workflowActorFromUserDataForTest,
} = require('../lib/maintenanceWorkflow/callable');

describe('maintenance workflow callable user authority', () => {
  test('accepts only canonical isApproved plus supported role list', () => {
    const actor = workflowActorFromUserDataForTest({
      isApproved: true,
      roles: ['seniorMechanical', 'shiftSupervisor'],
      name: '  Supervisor  ',
    }, 'user-1');

    expect(actor.uid).toBe('user-1');
    expect(actor.name).toBe('Supervisor');
    expect([...actor.roles].sort()).toEqual(['seniorMechanical', 'shiftSupervisor']);
  });

  test.each([
    [{approved: true, roles: ['admin']}],
    [{status: 'approved', roles: ['admin']}],
    [{isApproved: true, role: 'admin'}],
    [{isApproved: true, roles: []}],
    [{isApproved: true, roles: ['unknownRole']}],
    [{isApproved: true, roles: ['admin', 7]}],
  ])('rejects legacy or malformed authority payload %#', (payload) => {
    expect(() => workflowActorFromUserDataForTest(payload, 'user-bad'))
      .toThrow();
  });

  test('falls back only for display name, never for authority', () => {
    const actor = workflowActorFromUserDataForTest({
      isApproved: true,
      roles: ['operations'],
      name: '',
    }, 'user-2', 'Token Name');
    expect(actor.name).toBe('Token Name');
    expect([...actor.roles]).toEqual(['operations']);
  });
});
