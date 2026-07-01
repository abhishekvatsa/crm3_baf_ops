const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const {
  COMPOSITE_BACKEND_IDENTITY_V2,
  buildCompositeBackendReleaseIdentity,
  evaluateIdentityDeploymentBinding,
} = require("../lib/backendReleaseIdentityComposite");

const authorityPath = path.resolve(
  __dirname,
  "../../release/backend-authority.prod.json",
);
const authority = JSON.parse(fs.readFileSync(authorityPath, "utf8"));

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function recomputeAuthorityDigest(document) {
  const clone = JSON.parse(JSON.stringify(document));
  delete clone.authorityDigest;
  return crypto
    .createHash("sha256")
    .update(canonicalJson(clone), "utf8")
    .digest("hex")
    .toUpperCase();
}

describe("backendReleaseIdentityComposite strict schema v2", () => {
  test("binds release identity to both Rules and the mixed Function fleet", () => {
    expect(COMPOSITE_BACKEND_IDENTITY_V2.releaseId)
      .toBe("prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd");
    expect(COMPOSITE_BACKEND_IDENTITY_V2.releaseId)
      .toContain("rules-0b3868bf-fleet-d57d11bd");
    expect(COMPOSITE_BACKEND_IDENTITY_V2.mixedFleetDigest)
      .toBe("D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1");
  });

  test("authority digest is independently reproducible", () => {
    expect(authority.authorityDigest).toBe("59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525");
    expect(recomputeAuthorityDigest(authority)).toBe(authority.authorityDigest);
  });

  test("records all seven deployed archive identities", () => {
    const archives = new Map(
      authority.functions.entries.map((entry) => [
        entry.name,
        entry.deployedArchiveSha256,
      ]),
    );
    expect(archives.size).toBe(7);
    expect(archives.get("assignPublishedTemplateVersion"))
      .toBe("B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD");
    expect(archives.get("completePlannedJobExecution"))
      .toBe("B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD");
    expect(archives.get("mutateRuntimeJobModulePopulation"))
      .toBe("B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD");
    expect(archives.get("onJobAssigned")).toBe("818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F");
    expect(archives.get("onTicketCreated")).toBe("818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F");
    expect(archives.get("onTicketResolved")).toBe("818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F");
    expect(archives.get("getBackendReleaseIdentity"))
      .toBe("121FD191C5324B5857B494C774134C0C7F5CA51624AA3DA83797730E26E2965F");
  });

  test("records explicit backend source custody", () => {
    const custody = new Map(
      authority.sourceCustody.files.map((entry) => [entry.path, entry.sha256]),
    );
    for (const requiredPath of [
      "functions/src/index.ts",
      "functions/package.json",
      "functions/package-lock.json",
      "functions/tsconfig.json",
      "functions/src/runtimeJobModulePopulation.ts",
      "firestore.rules",
      "firestore.indexes.json",
    ]) {
      expect(custody.has(requiredPath)).toBe(true);
    }
  });

  test("records the current over-privileged runtime IAM posture", () => {
    expect(authority.runtimeIam.serviceAccountEmail)
      .toBe("894346496105-compute@developer.gserviceaccount.com");
    expect(authority.runtimeIam.posture)
      .toBe("OVER_PRIVILEGED_DEFAULT_COMPUTE_SERVICE_ACCOUNT");
    expect(authority.runtimeIam.appliesToFunctions).toHaveLength(7);
    expect(authority.runtimeIam.observedRoleBindings.map((binding) =>
      binding.role).sort()).toEqual([
        "roles/editor",
        "roles/eventarc.eventReceiver",
        "roles/run.invoker",
      ].sort());
    expect(authority.runtimeIam.leastPrivilegeRemediationAuthorized)
      .toBe(false);
  });

  test("reports pending when deployment bindings are wholly absent", () => {
    const binding = evaluateIdentityDeploymentBinding({});
    expect(binding.status).toBe("SOURCE_DEFINED_PENDING_DEPLOYMENT");
    expect(binding.identityFunctionDeployedSourceCommit).toBeNull();

    const projected = buildCompositeBackendReleaseIdentity({
      callerRole: "admin",
      backendGitCommit: "legacy-ambiguous-commit",
    }, {});
    expect(projected.callerRole).toBe("admin");
    expect(projected.backendGitCommit).toBeNull();
    expect(projected.productionReconstructionSourceCommit)
      .toBe("17f433b93b596e7730b58b337a42733a05f297a3");
    expect(projected.mixedFleetDigest).toBe("D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1");
  });

  test("reports exact only when every runtime binding is exact", () => {
    const commit = "0123456789abcdef0123456789abcdef01234567";
    const environment = {
      BACKEND_AUTHORITY_SCHEMA_VERSION: "2",
      BACKEND_AUTHORITY_DIGEST: "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525",
      BACKEND_AUTHORITY_RELEASE_ID: "prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd",
      BACKEND_IDENTITY_DEPLOYED_SOURCE_COMMIT: commit,
    };
    const binding = evaluateIdentityDeploymentBinding(environment);
    expect(binding.status).toBe("SCHEMA_V2_DEPLOYED_EXACT");
    expect(binding.mismatches).toEqual([]);

    const projected = buildCompositeBackendReleaseIdentity({}, environment);
    expect(projected.identityProjectionStatus)
      .toBe("SCHEMA_V2_DEPLOYED_EXACT");
    expect(projected.backendGitCommit).toBe(commit);
    expect(projected.backendGitCommitScope)
      .toBe("IDENTITY_FUNCTION_DEPLOYED_SOURCE_COMMIT_ONLY");
  });

  test("reports mismatch for partial or incorrect deployment configuration", () => {
    const binding = evaluateIdentityDeploymentBinding({
      BACKEND_AUTHORITY_SCHEMA_VERSION: "2",
      BACKEND_AUTHORITY_DIGEST: "WRONG",
    });
    expect(binding.status).toBe("DEPLOYMENT_CONFIGURATION_MISMATCH");
    expect(binding.mismatches).toContain("BACKEND_AUTHORITY_DIGEST");
    expect(binding.mismatches)
      .toContain("BACKEND_AUTHORITY_RELEASE_ID");
    expect(binding.mismatches)
      .toContain("BACKEND_IDENTITY_DEPLOYED_SOURCE_COMMIT");
  });

  test("records merged source adoption without implying deployment", () => {
    expect(authority.sourceAdoption.status)
      .toBe("SOURCE_MERGED_PENDING_DEPLOYMENT");
    expect(authority.sourceAdoption.sourceProposalHeadCommit)
      .toBe("527fbd9c135bc6ed57493defeba2c877baa13021");
    expect(authority.sourceAdoption.mergeCommit)
      .toBe("096d8e5644b0be3dc6cda625648aa31522a49ce5");
    expect(authority.sourceAdoption.mergeTree)
      .toBe("6e2427b0855ae896a8e89b849246adc9d78d2266");
    expect(authority.sourceAdoption.mergeMethod).toBe("MERGE_COMMIT");
    expect(authority.sourceAdoption.mergedPrNumber).toBe(26);
    expect(authority.sourceAdoption.postmergeCiRunId).toBe(28530946482);
    expect(authority.sourceAdoption.postmergeCiStatus).toBe("PASS");
    expect(authority.sourceAdoption.productionDeploymentPerformed).toBe(false);
    expect(authority.sourceAdoption.iamMutationPerformed).toBe(false);
    expect(authority.releaseModel.identityProjectionSourceStatus)
      .toBe("SOURCE_DEFINED_PENDING_DEPLOYMENT");
    expect(authority.repositoryAuthority.identityFunctionDeployedSourceCommit)
      .toBeNull();

    const evidenceByRole = new Map(
      authority.evidenceChain.map((entry) => [entry.role, entry.sha256]),
    );
    expect(evidenceByRole.get("STAGE2B_V2_MERGE_AND_POSTMERGE_CI_CUSTODY"))
      .toBe("096AED1DA366E3698008C579DE6B3875039DE76A95D8D97360AE6D583B12C529");
    expect(authority.openIndependentGates).toEqual([
      "identity Function deployment preflight with exact runtime environment bindings",
      "runtime service-account least-privilege hardening",
      "Firebase App Check staged rollout",
      "dependency, device, recovery and operator-acceptance gates",
    ]);
  });

  test("does not imply one Git commit for the mixed fleet", () => {
    expect(authority.repositoryAuthority.productionReconstructionSourceCommit)
      .toBe("17f433b93b596e7730b58b337a42733a05f297a3");
    expect(authority.repositoryAuthority.identityFunctionDeployedSourceCommit)
      .toBeNull();
    expect(authority.repositoryAuthority.mixedFleetDigest)
      .toBe("D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1");
    expect(authority.functions.singleHomogeneousDeployment).toBe(false);
  });
});
