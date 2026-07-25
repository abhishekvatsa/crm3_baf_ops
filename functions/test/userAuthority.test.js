const {
  canonicalApprovedUserAuthority,
  canonicalRoleUniverseForTest,
  canonicalUserHasAnyRole,
} = require('../lib/userAuthority');

describe('canonical backend user authority', () => {
  test('accepts only canonical isApproved plus recognised non-empty roles', () => {
    const data = {
      isApproved: true,
      roles: ['admin', 'operations'],
      fcmToken: 'token-1',
    };
    const authority = canonicalApprovedUserAuthority(data);
    expect(authority).not.toBeNull();
    expect(authority.data).toBe(data);
    expect(authority.data.fcmToken).toBe('token-1');
    expect([...authority.roles].sort()).toEqual(['admin', 'operations']);
  });

  test.each([
    null,
    {},
    {approved: true, roles: ['admin']},
    {status: 'approved', roles: ['admin']},
    {isApproved: true, role: 'admin'},
    {isApproved: true, roles: []},
    {isApproved: true, roles: ['unknownRole']},
    {isApproved: true, roles: ['admin', 7]},
    {isApproved: false, roles: ['admin']},
  ])('fails closed for legacy or malformed authority: %p', (value) => {
    expect(canonicalApprovedUserAuthority(value)).toBeNull();
  });

  test('role checks cannot bypass malformed authority', () => {
    const allowed = new Set(['admin']);
    expect(canonicalUserHasAnyRole({isApproved: true, roles: ['admin']}, allowed)).toBe(true);
    expect(canonicalUserHasAnyRole({approved: true, roles: ['admin']}, allowed)).toBe(false);
    expect(canonicalUserHasAnyRole({isApproved: true, roles: ['admin', 'bogus']}, allowed)).toBe(false);
  });

  test('role universe is generated-policy aligned and contains all operational roles', () => {
    expect(canonicalRoleUniverseForTest()).toEqual(expect.arrayContaining([
      'admin',
      'si',
      'contractSupervisor',
      'shiftSupervisor',
      'seniorElectrical',
      'seniorMechanical',
      'seniorInstrumentation',
      'seniorRefractory',
      'refractory',
      'operations',
    ]));
  });
});
