const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.resolve(
    __dirname,
    `../../release/${name}`,
  ), "utf8"));
}

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

function recomputeDigest(document, digestField) {
  const clone = JSON.parse(JSON.stringify(document));
  delete clone[digestField];
  return crypto
    .createHash("sha256")
    .update(canonicalJson(clone), "utf8")
    .digest("hex")
    .toUpperCase();
}

const authority = readJson("backend-authority.prod.json");
const attestation = readJson(
  "backend-identity-deployment-attestation.prod.json",
);
const security = readJson("backend-security-readiness.prod.json");
const currentState = readJson("backend-current-state.prod.json");

describe("postdeployment authority attestation and security baseline", () => {
  test("preserves the runtime-bound authority definition digest", () => {
    expect(authority.authorityDigest).toBe(
      "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525",
    );
    expect(attestation.authorityDefinition.authorityDigest)
      .toBe(authority.authorityDigest);
    expect(attestation.authorityDefinition.immutableDeploymentBoundDefinition)
      .toBe(true);
  });

  test("deployment attestation digest and exact deployment facts reproduce", () => {
    expect(recomputeDigest(attestation, "attestationDigest"))
      .toBe(attestation.attestationDigest);
    expect(attestation.status).toBe("IDENTITY_FUNCTION_DEPLOYED_EXACT");
    expect(attestation.deployment.sourceCommit)
      .toBe("08afc4f3020359fcdfeed472d7f4ba6b01084d44");
    expect(attestation.deployment.currentRevision)
      .toBe("getbackendreleaseidentity-00002-wud");
    expect(attestation.deployment.currentSourceGeneration)
      .toBe("1782928076881189");
    expect(attestation.deployment.deployedArchiveSha256)
      .toBe("692E41AAD6755B362D391736947434FD0BAFBE4F78F57C0D49056BE452FE158D");
    expect(attestation.environmentBindingCustody.requiredCandidateBindings)
      .toEqual({
        BACKEND_AUTHORITY_DIGEST:
          "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525",
        BACKEND_AUTHORITY_RELEASE_ID:
          "prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd",
        BACKEND_AUTHORITY_SCHEMA_VERSION: "2",
        BACKEND_IDENTITY_DEPLOYED_SOURCE_COMMIT:
          "08afc4f3020359fcdfeed472d7f4ba6b01084d44",
      });
  });

  test("safe evidence excludes the private environment-bearing archive", () => {
    const custody = attestation.evidence.privateArchiveCustody;
    expect(custody.archiveIncludedInSafeEvidence).toBe(false);
    expect(custody.containsProjectEnvironmentFile).toBe(true);
    expect(custody.projectEnvironmentFilename)
      .toBe(".env.crm3-baf-ops-b8638");
    expect(custody.handlingRequirement).toBe("KEEP_PRIVATE_DO_NOT_UPLOAD");
  });

  test("security ledger remains fail-closed and does not claim readiness", () => {
    expect(recomputeDigest(security, "securityDigest"))
      .toBe(security.securityDigest);
    expect(security.overallStatus).toBe("NOT_SECURITY_READY");
    expect(security.securityReady).toBe(false);
    expect(security.openBlockerCount).toBe(5);
    const controls = new Map(security.controls.map((item) => [item.id, item]));
    for (const id of [
      "runtime-service-account-least-privilege",
      "dedicated-runtime-identity-source-binding",
      "app-check-client-activation",
      "callable-app-check-enforcement",
      "high-severity-node-dependency-advisories",
    ]) {
      expect(controls.get(id).status).toBe("OPEN_BLOCKER");
    }
    expect(security.dependencyAudit.high).toBe(2);
    expect(security.dependencyAudit.expectedHighSeverityPackages.sort())
      .toEqual(["form-data", "protobufjs"].sort());
  });

  test("public callable transport is classified separately from IAM hardening", () => {
    expect(security.transportExposure.cloudRunInvokerMembers)
      .toEqual(["allUsers"]);
    expect(security.transportExposure.classification)
      .toBe("INTENTIONAL_PUBLIC_TRANSPORT_FOR_FIREBASE_CALLABLE");
    expect(security.transportExposure.removalRequired).toBe(false);
    expect(security.transportExposure.futureCompensatingControl)
      .toBe("FIREBASE_APP_CHECK_ENFORCEMENT");
  });

  test("current-state index joins all three records without recursion", () => {
    expect(recomputeDigest(currentState, "indexDigest"))
      .toBe(currentState.indexDigest);
    expect(currentState.authorityDefinition.digest)
      .toBe(authority.authorityDigest);
    expect(currentState.deploymentAttestation.digest)
      .toBe(attestation.attestationDigest);
    expect(currentState.securityReadiness.digest)
      .toBe(security.securityDigest);
    expect(currentState.derivedState.identityFunctionDeploymentStatus)
      .toBe("SCHEMA_V2_DEPLOYED_EXACT");
    expect(currentState.derivedState.securityStatus)
      .toBe("NOT_SECURITY_READY");
    expect(currentState.derivedState.overallStatus)
      .toBe("DEPLOYED_EXACT_SECURITY_GATES_OPEN");
  });
});
