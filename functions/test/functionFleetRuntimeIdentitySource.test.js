const fs = require("node:fs");
const path = require("node:path");

const {
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS,
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS,
  functionRuntimeServiceAccountsForProject,
} = require("../lib/functionFleetRuntimeIdentity");
const {
  normalizeFunctions,
} = require("../../tools/release/collectFunctionFleetRuntimeIdentityReadback");

const root = path.resolve(__dirname, "../..");
const policy = JSON.parse(fs.readFileSync(
  path.join(root, "release", "function-fleet-runtime-identity-policy.json"),
  "utf8",
));
const liveReadbackPolicy = JSON.parse(fs.readFileSync(
  path.join(root, "release", "lr03-lr06-functions-live-readback-policy.json"),
  "utf8",
));

function endpointServiceAccount(endpoint) {
  const value = endpoint.__endpoint.serviceAccountEmail;
  return typeof value?.toCEL === "function" ? value.toCEL() : value;
}

describe("complete Function fleet runtime identity source policy", () => {
  test("binds every exported Function to one exact same-project identity", () => {
    const exported = require("../lib/index");
    const endpointNames = Object.entries(exported)
      .filter(([, value]) => value?.__endpoint != null)
      .map(([name]) => name)
      .sort();
    const governedNames = Object.keys(policy.functionBindings).sort();

    expect(endpointNames).toEqual(governedNames);
    expect(Object.keys(FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS).sort())
      .toEqual(governedNames);
    expect(Object.keys(FUNCTION_RUNTIME_SERVICE_ACCOUNTS).sort())
      .toEqual(governedNames);

    const accountIds = new Set();
    for (const name of governedNames) {
      const binding = policy.functionBindings[name];
      const accountId = FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS[name];
      accountIds.add(accountId);
      expect(binding.runtimeServiceAccountId).toBe(accountId);
      expect(endpointServiceAccount(exported[name])).toBe(
        `${accountId}@{{ params.PROJECT_ID }}.iam.gserviceaccount.com`,
      );
    }
    expect(accountIds.size).toBe(governedNames.length);

    expect(liveReadbackPolicy.sourceDeclaredRuntimeBindings).toEqual(
      functionRuntimeServiceAccountsForProject(policy.productionProjectId),
    );
  });

  test("resolves the full fleet only inside the selected deployment project", () => {
    const production = functionRuntimeServiceAccountsForProject(
      "crm3-baf-ops-b8638",
    );
    const staging = functionRuntimeServiceAccountsForProject(
      "crm3-baf-ops-staging",
    );
    for (const [name, accountId] of Object.entries(
      FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS,
    )) {
      expect(production[name]).toBe(
        `${accountId}@crm3-baf-ops-b8638.iam.gserviceaccount.com`,
      );
      expect(staging[name]).toBe(
        `${accountId}@crm3-baf-ops-staging.iam.gserviceaccount.com`,
      );
    }
    expect(() => functionRuntimeServiceAccountsForProject(
      " crm3-baf-ops-b8638",
    )).toThrow("A canonical Google Cloud project ID is required.");
  });

  test("keeps runtime roles exact and the Editor removal ordered last", () => {
    expect(policy.schemaVersion).toBe(1);
    expect(policy.declarationStatus).toBe(
      "DEPLOYED_AND_LIVE_READBACK_PROVED",
    );
    expect(policy.roleExactnessRequired).toBe(true);
    expect(policy.customRoles.notificationSender.includedPermissions)
      .toEqual(["cloudmessaging.messages.create"]);
    expect(policy.buildIdentity.requiredProjectRolesAfterCutover)
      .toEqual(["roles/cloudbuild.builds.builder"]);
    expect(policy.buildIdentity.runtimeUseAfterCutover).toBe("PROHIBITED");
    expect(policy.temporaryDeploymentProjectRoles).toEqual({
      eventAndScheduleRuntimeIdentities: ["roles/run.invoker"],
      removalRequiredBeforeClosure: true,
    });
    expect(policy.forbiddenProjectRolesForRuntimeIdentities)
      .toContain("roles/editor");
    expect(policy.deploymentOrder.at(-2)).toContain(
      "remove roles/editor from Default Compute",
    );
    expect(Object.values(policy.sourceMutationBoundary).every(
      (value) => value === false,
    )).toBe(true);

    for (const binding of Object.values(policy.functionBindings)) {
      expect(binding.requiredProjectRoles).not.toContain("roles/editor");
      expect(binding.requiredProjectRoles).not.toContain(
        "roles/logging.logWriter",
      );
    }
    for (const binding of Object.values(policy.functionBindings)) {
      if (binding.requiredCloudRunServiceRoles != null) {
        expect(binding.requiredCloudRunServiceRoles)
          .toEqual(["roles/run.invoker"]);
        expect(binding.requiredProjectRoles)
          .not.toContain("roles/run.invoker");
      }
    }
  });

  test("retains the deployed Firebase source hash in fleet readbacks", () => {
    const [record] = normalizeFunctions([{
      name: "projects/crm3-baf-ops-b8638/locations/asia-south1/" +
        "functions/mutateUserAuthority",
      state: "ACTIVE",
      environment: "GEN_2",
      labels: {"firebase-functions-hash": "source-hash-1"},
      serviceConfig: {
        serviceAccountEmail:
          "crm3-fn-user-authority@crm3-baf-ops-b8638.iam.gserviceaccount.com",
        service:
          "projects/crm3-baf-ops-b8638/locations/asia-south1/" +
          "services/mutateuserauthority",
      },
      updateTime: "2026-08-04T13:38:07.912476676Z",
    }], "crm3-baf-ops-b8638", "asia-south1");

    expect(record).toEqual(expect.objectContaining({
      name: "mutateUserAuthority",
      firebaseFunctionsHash: "source-hash-1",
      state: "ACTIVE",
      environment: "GEN_2",
    }));
  });
});
