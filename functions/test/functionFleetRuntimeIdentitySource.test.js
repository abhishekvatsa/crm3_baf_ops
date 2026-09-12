const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");

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
const expectedRuntimeAliases = {
  assignPublishedTemplateVersionV2: "assignPublishedTemplateVersion",
  executeMaintenanceWorkflowCommandV2: "executeMaintenanceWorkflowCommand",
  mutateAssetHierarchyV2: "mutateAssetHierarchy",
  mutateChargeAbnormalityV2: "mutateChargeAbnormality",
};

function endpointServiceAccount(endpoint) {
  const value = endpoint.__endpoint.serviceAccountEmail;
  return typeof value?.toCEL === "function" ? value.toCEL() : value;
}

function callableOptionTokens(relativePath, exportName) {
  const filename = path.join(root, "functions", "src", relativePath);
  const source = ts.createSourceFile(filename, fs.readFileSync(filename, "utf8"),
    ts.ScriptTarget.Latest, true);
  let declaration;
  function visit(node) {
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) &&
        node.name.text === exportName) declaration = node;
    ts.forEachChild(node, visit);
  }
  visit(source);
  expect(declaration).toBeDefined();
  const call = declaration.initializer;
  expect(ts.isCallExpression(call)).toBe(true);
  expect(call.expression.getText(source)).toBe("onCall");
  expect(ts.isObjectLiteralExpression(call.arguments[0])).toBe(true);
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true,
    ts.LanguageVariant.Standard, call.arguments[0].getText(source));
  const tokens = [];
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken;
    token = scanner.scan()) tokens.push([token, scanner.getTokenText()]);
  return tokens;
}

describe("complete Function fleet runtime identity source policy", () => {
  test.each(Object.entries(expectedRuntimeAliases))(
    "%s preserves all deployment options of %s without changing origin-bound behavior",
    (alias, original) => {
      const exported = require("../lib/index");
      const relativePath = original === "executeMaintenanceWorkflowCommand" ?
        "maintenanceWorkflow/callable.ts" : "index.ts";
      // Compare the complete option declaration, including security spreads,
      // separately from handlers: V2 must still enforce its stricter origin.
      // Tokenization ignores layout, not options, values or their override order.
      expect(callableOptionTokens(relativePath, alias))
        .toEqual(callableOptionTokens(relativePath, original));
      expect(exported[alias].__endpoint).toEqual(exported[original].__endpoint);
      expect(exported[alias].__trigger).toEqual(exported[original].__trigger);
    },
  );

  test("binds every exported Function to one exact same-project identity", () => {
    const exported = require("../lib/index");
    const endpointNames = Object.entries(exported)
      .filter(([, value]) => value?.__endpoint != null)
      .map(([name]) => name)
      .sort();
    const governedNames = Object.keys(policy.functionBindings).sort();
    expect(policy.runtimeIdentityAliases).toEqual(expectedRuntimeAliases);
    const canonicalNames = governedNames.filter(
      (name) => !Object.hasOwn(expectedRuntimeAliases, name),
    );

    expect(endpointNames).toEqual(governedNames);
    expect(Object.keys(FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS).sort())
      .toEqual(canonicalNames);
    expect(Object.keys(FUNCTION_RUNTIME_SERVICE_ACCOUNTS).sort())
      .toEqual(canonicalNames);

    const accountIds = new Set();
    for (const name of governedNames) {
      const binding = policy.functionBindings[name];
      const canonicalName = expectedRuntimeAliases[name] ?? name;
      const accountId = FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS[canonicalName];
      accountIds.add(accountId);
      if (canonicalName !== name) {
        expect(canonicalNames).toContain(canonicalName);
        expect(binding).toEqual(policy.functionBindings[canonicalName]);
        expect(endpointServiceAccount(exported[name]))
          .toBe(endpointServiceAccount(exported[canonicalName]));
      }
      expect(binding.runtimeServiceAccountId).toBe(accountId);
      expect(endpointServiceAccount(exported[name])).toBe(
        `${accountId}@{{ params.PROJECT_ID }}.iam.gserviceaccount.com`,
      );
    }
    expect(accountIds.size).toBe(canonicalNames.length);
    expect(governedNames).toHaveLength(19);
    expect(accountIds.size).toBe(15);

    const sourceBindings = functionRuntimeServiceAccountsForProject(
      policy.productionProjectId,
    );
    const liveBindingNames = Object.keys(
      liveReadbackPolicy.sourceDeclaredRuntimeBindings,
    );
    expect(liveReadbackPolicy.sourceDeclaredRuntimeBindings).toEqual(
      Object.fromEntries(liveBindingNames.map((name) => [
        name,
        sourceBindings[expectedRuntimeAliases[name] ?? name],
      ])),
    );
    expect(liveBindingNames.sort()).toEqual(governedNames);
    expect([...liveReadbackPolicy.sourcePendingDeploymentExports].sort())
      .toEqual([...policy.deploymentPendingFunctionBindings].sort());
    expect(policy.deploymentPendingFunctionBindings.every(
      (name) => liveBindingNames.includes(name),
    )).toBe(true);
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
      "SOURCE_POLICY_EXTENDED_DEPLOYMENT_PENDING",
    );
    expect([...policy.deploymentPendingFunctionBindings].sort())
      .toEqual(["assignPublishedTemplateVersionV2", "executeMaintenanceWorkflowCommandV2",
        "mutateAssetHierarchy", "mutateAssetHierarchyV2", "mutateChargeAbnormalityV2"]);
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
