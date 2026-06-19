const {
  BackendIdentityValidationError,
  backendReleaseEnvironmentFromProcess,
  buildBackendReleaseIdentity,
  getBackendReleaseIdentityWithDb,
} = require("../lib/backendReleaseIdentity");

function fakeDb(userData) {
  return {
    collection(name) {
      if (name !== "users") throw new Error(`Unexpected collection ${name}`);
      return {
        doc() {
          return {
            async get() {
              return userData == null
                ? {exists: false, data: () => undefined}
                : {exists: true, data: () => userData};
            },
          };
        },
      };
    },
  };
}

describe("backend release identity", () => {
  test("builds complete release identity and normalizes deployment time", () => {
    expect(
      buildBackendReleaseIdentity({
        releaseId: "crm3-baf-ops-70i-rc1",
        firebaseProjectId: "crm3-baf-ops-b8638",
        environment: "production",
        gitCommit: "8d18805",
        functionsRevision: "assignpublishedtemplateversion-00001-abc",
        functionsDigest: "sha256:functions",
        firestoreRulesReleaseId: "ruleset-123",
        firestoreRulesDigest: "sha256:rules",
        firestoreIndexesDigest: "sha256:indexes",
        deployedAt: "2026-06-19T12:00:00Z",
      }),
    ).toEqual({
      releaseId: "crm3-baf-ops-70i-rc1",
      firebaseProjectId: "crm3-baf-ops-b8638",
      environment: "production",
      gitCommit: "8d18805",
      functionsRevision: "assignpublishedtemplateversion-00001-abc",
      functionsDigest: "sha256:functions",
      firestoreRulesReleaseId: "ruleset-123",
      firestoreRulesDigest: "sha256:rules",
      firestoreIndexesDigest: "sha256:indexes",
      deployedAt: "2026-06-19T12:00:00.000Z",
    });
  });

  test("rejects missing backend release identity", () => {
    expect(() =>
      buildBackendReleaseIdentity({
        firebaseProjectId: "crm3-baf-ops-b8638",
        environment: "production",
      }),
    ).toThrow(BackendIdentityValidationError);

    try {
      buildBackendReleaseIdentity({
        firebaseProjectId: "crm3-baf-ops-b8638",
        environment: "production",
      });
    } catch (error) {
      expect(error).toMatchObject({
        code: "not-found",
        details: {reasonCode: "backend-release-id-missing"},
      });
    }
  });

  test("approved user receives identity", async () => {
    const result = await getBackendReleaseIdentityWithDb({
      db: fakeDb({isApproved: true, roles: ["operations"]}),
      authUid: "ops1",
      environment: {
        releaseId: "release-1",
        firebaseProjectId: "crm3-baf-ops-b8638",
        environment: "production",
      },
    });
    expect(result.releaseId).toBe("release-1");
  });

  test("unauthenticated, missing, and unapproved users are rejected", async () => {
    await expect(
      getBackendReleaseIdentityWithDb({
        db: fakeDb(null),
        authUid: null,
        environment: {
          releaseId: "release-1",
          firebaseProjectId: "crm3-baf-ops-b8638",
          environment: "production",
        },
      }),
    ).rejects.toMatchObject({code: "unauthenticated"});

    await expect(
      getBackendReleaseIdentityWithDb({
        db: fakeDb(null),
        authUid: "missing",
        environment: {
          releaseId: "release-1",
          firebaseProjectId: "crm3-baf-ops-b8638",
          environment: "production",
        },
      }),
    ).rejects.toMatchObject({code: "permission-denied"});

    await expect(
      getBackendReleaseIdentityWithDb({
        db: fakeDb({isApproved: false, roles: ["operations"]}),
        authUid: "pending",
        environment: {
          releaseId: "release-1",
          firebaseProjectId: "crm3-baf-ops-b8638",
          environment: "production",
        },
      }),
    ).rejects.toMatchObject({code: "permission-denied"});
  });

  test("maps process environment with project fallback", () => {
    expect(
      backendReleaseEnvironmentFromProcess(
        {
          BACKEND_RELEASE_ID: "release-2",
          BACKEND_ENVIRONMENT: "staging",
          BACKEND_GIT_COMMIT: "abc123",
          K_REVISION: "revision-1",
          BACKEND_DEPLOYED_AT: "2026-06-19T12:00:00.000Z",
        },
        "fallback-project",
      ),
    ).toMatchObject({
      releaseId: "release-2",
      firebaseProjectId: "fallback-project",
      environment: "staging",
      gitCommit: "abc123",
      functionsRevision: "revision-1",
    });
  });
});
