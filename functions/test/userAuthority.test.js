const {
  canonicalApprovedUserAuthority,
  canonicalRoleUniverseForTest,
  canonicalUserAuthorityCapsule,
  canonicalUserAuthorityDigest,
  canonicalUserHasAnyRole,
  normalizeCanonicalUserRoles,
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

  test('unapproved intended roles remain a canonical non-authorizing capsule', () => {
    const capsule = canonicalUserAuthorityCapsule({
      isApproved: false,
      roles: ['operations'],
    });
    expect(capsule).not.toBeNull();
    expect(capsule.isApproved).toBe(false);
    expect([...capsule.roles]).toEqual(['operations']);
    expect(canonicalApprovedUserAuthority({
      isApproved: false,
      roles: ['operations'],
    })).toBeNull();
  });

  test('authority digest is semantic across role order and duplicates', () => {
    const first = canonicalUserAuthorityCapsule({
      isApproved: true,
      roles: ['operations', 'admin', 'admin'],
    });
    const second = canonicalUserAuthorityCapsule({
      isApproved: true,
      roles: ['admin', 'operations'],
    });
    expect(canonicalUserAuthorityDigest(first)).toBe(
      canonicalUserAuthorityDigest(second),
    );
    expect(canonicalUserAuthorityDigest(first)).toMatch(
      /^auth1-sha256:[0-9a-f]{64}$/,
    );
    expect(normalizeCanonicalUserRoles(first.roles)).toEqual([
      'admin',
      'operations',
    ]);
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
