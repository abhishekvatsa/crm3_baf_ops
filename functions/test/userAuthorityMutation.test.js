const {
  legacyUserAuthorityMutationFingerprintV1,
  parseUserAuthorityMutationRequest,
  userAuthorityMutationFingerprintV2,
} = require("../lib/userAuthorityMutation");

const fixture = {
  requestId: "33333333-3333-4333-8333-333333333333",
  targetUid: "target",
  operation: "REPLACE_ROLES",
  expectedAuthorityDigest:
    "auth1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  roles: ["operations", "shiftSupervisor"],
  reason: "Governed authority change for fingerprint verification.",
};

describe("versioned user-authority request fingerprints", () => {
  test("v2 canonical JSON is independent of object insertion order", () => {
    const reordered = {
      reason: fixture.reason,
      roles: fixture.roles,
      expectedAuthorityDigest: fixture.expectedAuthorityDigest,
      operation: fixture.operation,
      targetUid: fixture.targetUid,
      requestId: fixture.requestId,
    };

    expect(userAuthorityMutationFingerprintV2(reordered))
      .toBe(userAuthorityMutationFingerprintV2(fixture));
  });

  test("v1 and v2 algorithms retain frozen, distinct vectors", () => {
    expect(legacyUserAuthorityMutationFingerprintV1(fixture)).toBe(
      "authreq1-sha256:cde70d25a54c90e924ea302bae5f19f9fa42ac038e703deb966453655c565461",
    );
    expect(userAuthorityMutationFingerprintV2(fixture)).toBe(
      "authreq2-sha256:2ca2c1cccb5b0fe28b34fa11e30fbf8e2adbd40e4f8d796a4c16fc58744469c7",
    );
  });

  test("the parser carries both current and historical replay fingerprints", () => {
    const parsed = parseUserAuthorityMutationRequest(fixture);

    expect(parsed.payloadFingerprint).toBe(
      userAuthorityMutationFingerprintV2(fixture),
    );
    expect(parsed.legacyPayloadFingerprint).toBe(
      legacyUserAuthorityMutationFingerprintV1(fixture),
    );
  });
});

const {userAuthorityCallableEnvelope} = require('../lib/userAuthorityMutation');
describe('authority transport origin', () => {
  test('binds both mutation and confirmation to the frozen origin', () => {
    for (const key of ['request', 'receiptLookup']) {
      const envelope = {protocolVersion: 2, originActorUid: 'original', [key]: fixture};
      expect(() => userAuthorityCallableEnvelope(envelope, 'another')).toThrow(/originating account/);
      expect(userAuthorityCallableEnvelope(envelope, 'original')).toEqual({data: fixture, confirmationOnly: key === 'receiptLookup'});
    }
  });
  test('refuses ambiguous transport modes', () => {
    expect(() => userAuthorityCallableEnvelope({protocolVersion: 2, originActorUid: 'original', request: fixture, receiptLookup: fixture}, 'original')).toThrow(/invalid/);
  });
});
