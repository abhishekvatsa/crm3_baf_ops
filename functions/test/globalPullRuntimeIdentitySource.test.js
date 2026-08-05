const fs = require("node:fs");
const path = require("node:path");
const {
  stackToWire,
} = require("../node_modules/firebase-functions/lib/runtime/manifest.js");

const {
  GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS,
  GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
  GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID,
  GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS,
  GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
  GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID,
  globalPullRuntimeServiceAccountsForProject,
} = require("../lib/globalPullSecurityConfig");

const root = path.resolve(__dirname, "../..");
const indexSource = fs.readFileSync(
  path.join(root, "functions", "src", "index.ts"),
  "utf8",
);
const policy = JSON.parse(
  fs.readFileSync(
    path.join(root, "release", "global-pull-runtime-identity-policy.json"),
    "utf8",
  ),
);

function functionBlock(startMarker, endMarker) {
  const start = indexSource.indexOf(startMarker);
  const end = indexSource.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) {
    throw new Error(`Missing source boundary: ${startMarker}`);
  }
  return indexSource.slice(start, end);
}

describe("global pull runtime identity source policy", () => {
  test("binds the callable to an exact read-only runtime identity", () => {
    expect(GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID).toBe(
      "crm3-global-pull-reader",
    );
    expect(GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT.toCEL()).toBe(
      "crm3-global-pull-reader@{{ params.PROJECT_ID }}" +
      ".iam.gserviceaccount.com",
    );
    expect(GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS).toEqual({
      enforceAppCheck: false,
      consumeAppCheckToken: false,
      serviceAccount: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
    });
    const block = functionBlock(
      "export const beginGlobalPullRun = onCall(",
      "export const stampGlobalPullServerClock = onDocumentWritten(",
    );
    expect(block).toContain("...GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS");
    expect(block).not.toContain("READ_ONLY_CALLABLE_SECURITY_OPTIONS");
  });

  test("binds the stamp trigger to a separate writer identity", () => {
    expect(GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID).toBe(
      "crm3-global-pull-writer",
    );
    expect(GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT.toCEL()).toBe(
      "crm3-global-pull-writer@{{ params.PROJECT_ID }}" +
      ".iam.gserviceaccount.com",
    );
    expect(GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS).toEqual({
      serviceAccount: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
    });
    const block = functionBlock(
      "export const stampGlobalPullServerClock = onDocumentWritten(",
      "export const mutateRuntimeJobModulePopulation = onCall(",
    );
    expect(block).toContain("...GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS");
  });

  test("resolves production and staging identities inside their own project", () => {
    expect(
      globalPullRuntimeServiceAccountsForProject("crm3-baf-ops-b8638"),
    ).toEqual({
      reader:
        "crm3-global-pull-reader@" +
        "crm3-baf-ops-b8638.iam.gserviceaccount.com",
      writer:
        "crm3-global-pull-writer@" +
        "crm3-baf-ops-b8638.iam.gserviceaccount.com",
    });
    expect(
      globalPullRuntimeServiceAccountsForProject("crm3-baf-ops-staging"),
    ).toEqual({
      reader:
        "crm3-global-pull-reader@" +
        "crm3-baf-ops-staging.iam.gserviceaccount.com",
      writer:
        "crm3-global-pull-writer@" +
        "crm3-baf-ops-staging.iam.gserviceaccount.com",
    });
    expect(() => globalPullRuntimeServiceAccountsForProject(
      " crm3-baf-ops-b8638",
    )).toThrow("A canonical Google Cloud project ID is required.");
    expect(() => globalPullRuntimeServiceAccountsForProject(
      "CRM3-baf-ops-b8638",
    )).toThrow("A canonical Google Cloud project ID is required.");
  });

  test("Firebase wire manifest preserves target-project interpolation", () => {
    const wire = stackToWire({
      endpoints: {
        beginGlobalPullRun: {
          serviceAccountEmail: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
        },
        stampGlobalPullServerClock: {
          serviceAccountEmail: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
        },
      },
    });
    expect(wire.endpoints.beginGlobalPullRun.serviceAccountEmail).toBe(
      "crm3-global-pull-reader@{{ params.PROJECT_ID }}" +
      ".iam.gserviceaccount.com",
    );
    expect(wire.endpoints.stampGlobalPullServerClock.serviceAccountEmail).toBe(
      "crm3-global-pull-writer@{{ params.PROJECT_ID }}" +
      ".iam.gserviceaccount.com",
    );
  });

  test("policy grants only the admitted roles and excludes the old fleet", () => {
    expect(policy.schemaVersion).toBe(3);
    expect(policy.policyId).toBe("GLOBAL-PULL-RUNTIME-IDENTITY-POLICY-V3");
    expect(policy.declarationStatus).toBe(
      "DEPLOYED_SUBSET_SUBSUMED_BY_PROVED_COMPLETE_FLEET",
    );
    expect(policy.completeFleetPolicy).toBe(
      "release/function-fleet-runtime-identity-policy.json",
    );
    expect(policy.productionProjectId).toBe("crm3-baf-ops-b8638");
    expect(policy.targetProjectBinding).toEqual({
      builtInParameter: "PROJECT_ID",
      serviceAccountDomain: "iam.gserviceaccount.com",
      sameProjectRequired: true,
      crossProjectResolutionAllowed: false,
    });
    expect(policy.functionBindings.beginGlobalPullRun).toEqual({
      runtimeServiceAccountId: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID,
      runtimeServiceAccountTemplate:
        "crm3-global-pull-reader@${PROJECT_ID}.iam.gserviceaccount.com",
      productionResolvedRuntimeServiceAccount:
        globalPullRuntimeServiceAccountsForProject("crm3-baf-ops-b8638")
          .reader,
      requiredProjectRoles: [
        "roles/datastore.viewer",
      ],
      firestoreAccess: "READ_ONLY",
    });
    expect(policy.functionBindings.stampGlobalPullServerClock).toEqual({
      runtimeServiceAccountId: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID,
      runtimeServiceAccountTemplate:
        "crm3-global-pull-writer@${PROJECT_ID}.iam.gserviceaccount.com",
      productionResolvedRuntimeServiceAccount:
        globalPullRuntimeServiceAccountsForProject("crm3-baf-ops-b8638")
          .writer,
      requiredProjectRoles: [
        "roles/datastore.user",
        "roles/eventarc.eventReceiver",
      ],
      requiredCloudRunServiceRoles: [
        "roles/run.invoker",
      ],
      firestoreAccess:
        "READ_WRITE_PROTOCOL_COLLECTIONS_ENFORCED_BY_SOURCE",
    });
    expect(policy.forbiddenProjectRoles).toContain("roles/editor");
    expect(policy.deploymentScope).toEqual([
      "beginGlobalPullRun",
      "stampGlobalPullServerClock",
    ]);
    expect(policy.existingFunctionFleetMutationAuthorized).toBe(false);
    expect(policy.defaultComputeRoleMutationAuthorized).toBe(false);
    expect(policy.temporaryProjectRunInvokerRemovalRequired).toBe(true);
    expect(policy.crossProjectGrantAuthorized).toBe(false);
    expect(policy.deploymentTargetRequirements).toHaveLength(4);
  });
});
