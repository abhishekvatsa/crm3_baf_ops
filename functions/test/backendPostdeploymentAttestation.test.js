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

function validateExactSchema(instance, schema, location = "$") {
  if (Object.prototype.hasOwnProperty.call(schema, "const")) {
    expect(instance).toEqual(schema.const);
  }

  if (schema.type === "object") {
    expect(instance).not.toBeNull();
    expect(Array.isArray(instance)).toBe(false);
    expect(typeof instance).toBe("object");
    expect(schema.additionalProperties).toBe(false);

    const properties = schema.properties || {};
    const expectedKeys = Object.keys(properties).sort();
    expect((schema.required || []).slice().sort()).toEqual(expectedKeys);
    expect(Object.keys(instance).sort()).toEqual(expectedKeys);

    for (const key of expectedKeys) {
      validateExactSchema(instance[key], properties[key], `${location}.${key}`);
    }
  } else if (schema.type === "array") {
    expect(Array.isArray(instance)).toBe(true);
    expect(Object.prototype.hasOwnProperty.call(schema, "const")).toBe(true);
  } else if (schema.type === "string") {
    expect(typeof instance).toBe("string");
  } else if (schema.type === "integer") {
    expect(Number.isInteger(instance)).toBe(true);
  } else if (schema.type === "boolean") {
    expect(typeof instance).toBe("boolean");
  } else if (schema.type === "null") {
    expect(instance).toBeNull();
  } else {
    throw new Error(`Unsupported schema type at ${location}: ${schema.type}`);
  }
}

function assertNoOpenObjectSchemas(schema, location = "$") {
  if (schema.type === "object") {
    expect(schema.additionalProperties).toBe(false);
    expect(schema.properties).toBeDefined();
    const keys = Object.keys(schema.properties).sort();
    expect(schema.required.slice().sort()).toEqual(keys);
    for (const key of keys) {
      assertNoOpenObjectSchemas(
        schema.properties[key],
        `${location}.properties.${key}`,
      );
    }
  } else if (schema.type === "array") {
    expect(Object.prototype.hasOwnProperty.call(schema, "const")).toBe(true);
  }
}

const authority = readJson("backend-authority.prod.json");
const attestation = readJson(
  "backend-identity-deployment-attestation.prod.json",
);
const attestationSchema = readJson(
  "backend-identity-deployment-attestation-v1.schema.json",
);
const security = readJson("backend-security-readiness.prod.json");
const securitySchema = readJson("backend-security-readiness-v1.schema.json");
const currentState = readJson("backend-current-state.prod.json");
const currentStateSchema = readJson("backend-current-state-v1.schema.json");

describe("postdeployment exact attestation and security baseline", () => {
  test("all production records validate against fully closed exact schemas", () => {
    for (const [document, schema] of [
      [attestation, attestationSchema],
      [security, securitySchema],
      [currentState, currentStateSchema],
    ]) {
      assertNoOpenObjectSchemas(schema);
      validateExactSchema(document, schema);
    }
  });

  test("all canonical digests reproduce and join without recursion", () => {
    expect(authority.authorityDigest).toBe(
      "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525",
    );
    expect(recomputeDigest(attestation, "attestationDigest"))
      .toBe(attestation.attestationDigest);
    expect(recomputeDigest(security, "securityDigest"))
      .toBe(security.securityDigest);
    expect(recomputeDigest(currentState, "indexDigest"))
      .toBe(currentState.indexDigest);

    expect(attestation.authorityDefinition.authorityDigest)
      .toBe(authority.authorityDigest);
    expect(currentState.authorityDefinition.digest)
      .toBe(authority.authorityDigest);
    expect(currentState.deploymentAttestation.digest)
      .toBe(attestation.attestationDigest);
    expect(currentState.securityReadiness.digest)
      .toBe(security.securityDigest);
  });

  test("deployment and private archive custody remain exact", () => {
    expect(attestation.deployment).toEqual({
      availableCpu: "1",
      availableMemory: "256Mi",
      buildServiceAccountResource:
        "projects/crm3-baf-ops-b8638/serviceAccounts/" +
        "894346496105-compute@developer.gserviceaccount.com",
      callableDeploymentLabel: true,
      currentRevision: "getbackendreleaseidentity-00002-wud",
      currentSourceGeneration: "1782928076881189",
      deployedArchiveEntryCount: 41,
      deployedArchiveSha256:
        "692E41AAD6755B362D391736947434FD0BAFBE4F78F57C0D49056BE452FE158D",
      functionName: "getBackendReleaseIdentity",
      functionUpdateTimeUtc: "2026-07-01T17:48:43.938588044Z",
      ingressSettings: "ALLOW_ALL",
      maxInstanceCount: 20,
      maxInstanceRequestConcurrency: 40,
      previousRevision: "getbackendreleaseidentity-00001-dos",
      previousSourceGeneration: "1781896431141186",
      region: "asia-south1",
      runtime: "nodejs22",
      runtimeServiceAccountEmail:
        "894346496105-compute@developer.gserviceaccount.com",
      sourceCommit: "08afc4f3020359fcdfeed472d7f4ba6b01084d44",
      sourceTree: "e831d1ac4c78c787430fa712a0f053aea7c7bc73",
      state: "ACTIVE",
      timeoutSeconds: 15,
      trafficPercentToCurrentRevision: 100,
    });

    expect(attestation.evidence.privateArchiveCustody).toEqual({
      archiveIncludedInSafeEvidence: false,
      archiveSha256:
        "692E41AAD6755B362D391736947434FD0BAFBE4F78F57C0D49056BE452FE158D",
      containsProjectEnvironmentFile: true,
      handlingRequirement: "KEEP_PRIVATE_DO_NOT_UPLOAD",
      projectEnvironmentFilename: ".env.crm3-baf-ops-b8638",
    });
  });

  test("five blockers remain open with unambiguous mutation semantics", () => {
    expect(security.securityReady).toBe(false);
    expect(security.overallStatus).toBe("NOT_SECURITY_READY");
    expect(security.openBlockerCount).toBe(5);

    const expectedCloudControlPlane = new Map([
      ["runtime-service-account-least-privilege", true],
      ["dedicated-runtime-identity-source-binding", true],
      ["app-check-client-activation", true],
      ["callable-app-check-enforcement", false],
      ["high-severity-node-dependency-advisories", false],
    ]);

    expect(security.controls).toHaveLength(5);
    for (const control of security.controls) {
      expect(control.status).toBe("OPEN_BLOCKER");
      expect(control.stage2dSourceChangeRequired).toBe(true);
      expect(control.futureDeploymentOrClientReleaseRequired).toBe(true);
      expect(control.separateCloudControlPlaneCampaignRequired)
        .toBe(expectedCloudControlPlane.get(control.id));
      expect(control.cloudMutationRequired).toBeUndefined();
      expect(control.separateGovernedCloudCampaignRequired).toBeUndefined();
    }
  });

  test("this source record authorizes no cloud or future security mutation", () => {
    expect(security.mutationAuthorization).toEqual({
      thisRecordCampaignSourceOnly: true,
      thisRecordCampaignDeploymentAuthorized: false,
      thisRecordCampaignIamMutationAuthorized: false,
      thisRecordCampaignAppCheckControlPlaneMutationAuthorized: false,
      futureSecurityStageMutationsAuthorizedByThisRecord: false,
    });

    expect(security.sequencing).toEqual({
      recordActivationGate:
        "MERGE_THIS_POSTDEPLOYMENT_BASELINE_TO_MAIN",
      nextSourceStageAfterActivation:
        "REBUILD_STAGE2D_FROM_RECONCILED_MAIN",
      stage2dSourceScope: [
        "APP_CHECK_CLIENT_SOURCE",
        "CALLABLE_ENFORCE_APP_CHECK",
        "DEDICATED_RUNTIME_SERVICE_ACCOUNT_SOURCE_BINDING",
        "FORM_DATA_AND_PROTOBUFJS_ADVISORY_REMEDIATION",
      ],
      separateCloudControlPlaneCampaigns: [
        "DEDICATED_SERVICE_ACCOUNT_CREATION_AND_IAM_BINDING",
        "DEFAULT_COMPUTE_ROLES_EDITOR_REMOVAL_AFTER_CUTOVER",
        "FIREBASE_APP_CHECK_PROVIDER_REGISTRATION_AND_STAGED_ENFORCEMENT",
      ],
      sourceMergeDoesNotAuthorizeCloudMutation: true,
      stage2dSourceMergeDoesNotActivateProductionControls: true,
    });
  });

  test("transport and dependency findings remain truthfully open", () => {
    expect(security.transportExposure).toEqual({
      classification:
        "INTENTIONAL_PUBLIC_TRANSPORT_FOR_FIREBASE_CALLABLE",
      cloudRunInvokerMembers: ["allUsers"],
      currentCompensatingControls: [
        "CALLABLE_AUTHENTICATION_REQUIRED",
        "ROLE_AND_FIRESTORE_AUTHORIZATION_GATE",
        "UNAUTHENTICATED_REQUESTS_REJECTED",
      ],
      futureCompensatingControl: "FIREBASE_APP_CHECK_ENFORCEMENT",
      reason:
        "Firebase callable transport remains publicly reachable while " +
        "authentication and authorization are enforced in the callable " +
        "protocol. App Check is the planned additional abuse-control layer.",
      removalRequired: false,
    });

    expect(security.dependencyAudit).toEqual({
      critical: 0,
      expectedHighSeverityPackages: ["form-data", "protobufjs"],
      high: 2,
      low: 1,
      moderate: 1,
      packageManager: "npm",
      remediationStage: "Stage2D",
      status: "OPEN",
      totalVulnerabilities: 4,
    });
  });
});
