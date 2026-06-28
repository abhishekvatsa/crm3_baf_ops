const {
  COMPOSITE_BACKEND_IDENTITY_V2,
  buildCompositeBackendReleaseIdentity,
} = require("../lib/backendReleaseIdentityComposite");

describe("backendReleaseIdentityComposite schema v2", () => {
  test("records the approved composite authority identity", () => {
    expect(COMPOSITE_BACKEND_IDENTITY_V2.schemaVersion).toBe(2);
    expect(COMPOSITE_BACKEND_IDENTITY_V2.authorityClass)
      .toBe("verified-production-backend-composite");
    expect(COMPOSITE_BACKEND_IDENTITY_V2.authorityStatus)
      .toBe("CURRENT_LIVE_STATE_RECORDED");
    expect(COMPOSITE_BACKEND_IDENTITY_V2.authorityDigest)
      .toBe("8F369ADB7BE04AC64B39E199E668C6841D1B5C0048CBCDA1827D411192AD0CF6");
    expect(COMPOSITE_BACKEND_IDENTITY_V2.releaseModel.identityProjectionStatus)
      .toBe("SCHEMA_V2_SOURCE_ADOPTED_PENDING_DEPLOYMENT");
  });

  test("honestly represents a mixed deployment fleet", () => {
    const fleet = COMPOSITE_BACKEND_IDENTITY_V2.functionFleet;
    expect(fleet.status).toBe("MIXED_DEPLOYMENT_FLEET");
    expect(fleet.singleHomogeneousDeployment).toBe(false);
    expect(fleet.expectedExports).toBe(7);
    expect(fleet.liveExports).toBe(7);
    expect(fleet.entries).toHaveLength(7);
    expect(fleet.entries.filter((entry) =>
      entry.strictBundleComparison === "EXACT")).toHaveLength(3);
    expect(fleet.entries.filter((entry) =>
      entry.strictBundleComparison === "DIFFERENT")).toHaveLength(4);
    expect(fleet.entries.every((entry) =>
      entry.entryImplementationStatus === "EXACT")).toBe(true);
  });

  test("projects the exact current Rules and index authority", () => {
    const firestore = COMPOSITE_BACKEND_IDENTITY_V2.firestore;
    expect(firestore.rules.status).toBe("EXACT");
    expect(firestore.rules.deployedRawSha256)
      .toBe("DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C");
    expect(firestore.rules.rulesetName)
      .toContain("0b3868bf-d7bb-405b-9a32-eef175b61af7");
    expect(firestore.indexes.status).toBe("EXACT");
    expect(firestore.indexes.sourceCompositeIndexes).toBe(28);
    expect(firestore.indexes.deployedCompositeIndexes).toBe(28);
    expect(firestore.indexes.fieldOverrideCount).toBe(0);
  });

  test("contains no stale scalar Rules identity", () => {
    const serialized = JSON.stringify(COMPOSITE_BACKEND_IDENTITY_V2);
    expect(serialized).not.toContain(
      "C897AA6056ADD67174F0DD6E786F85709280BE3CE77D182401153C428268286F",
    );
    expect(serialized).not.toContain(
      "b8d615f5-2f18-44b4-8845-bcf4cd0e1310",
    );
    expect(serialized).not.toContain(
      "prod-4132b83-20260620_001612",
    );
  });

  test("overrides ambiguous legacy scalars while preserving unrelated metadata", () => {
    const projected = buildCompositeBackendReleaseIdentity({
      releaseId: "legacy-release",
      backendGitCommit: "legacy-commit",
      firestoreRulesDigest: "legacy-rules",
      functionsDeployedDigest: "legacy-functions",
      callerRole: "admin",
    });

    expect(projected.callerRole).toBe("admin");
    expect(projected.schemaVersion).toBe(2);
    expect(projected.releaseId)
      .toBe("prod-composite-20260628T171115Z-rules-0b3868bf");
    expect(projected.backendGitCommit)
      .toBe("17f433b93b596e7730b58b337a42733a05f297a3");
    expect(projected.firestoreRulesDigest)
      .toBe("DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C");
    expect(projected.functionsDeployedDigest)
      .toBe(COMPOSITE_BACKEND_IDENTITY_V2.functionFleet.fleetDigest);
    expect(projected.legacyScalarProjectionStatus)
      .toBe("SUPERSEDED_BY_SCHEMA_V2");
  });

  test("keeps evidence custody and digest semantics explicit", () => {
    const projected = buildCompositeBackendReleaseIdentity({});
    expect(projected.evidenceChain).toHaveLength(3);
    expect(projected.functionsDigestSemantics)
      .toBe("CANONICAL_COMPOSITE_PER_FUNCTION_DEPLOYMENT_IDENTITY_DIGEST");
    expect(projected.backendGitCommitSemantics)
      .toBe("CURRENT_GOVERNED_SOURCE_TARGET_NOT_HOMOGENEOUS_DEPLOYMENT_CLAIM");
    expect(projected.sourceCustody.functionFleetDigest)
      .toBe(COMPOSITE_BACKEND_IDENTITY_V2.functionFleet.fleetDigest);
  });
});
