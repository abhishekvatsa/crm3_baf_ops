const fs = require("node:fs");
const path = require("node:path");

const {
  GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS,
  GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
  GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS,
  GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
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
    expect(GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT).toBe(
      "crm3-global-pull-reader@" +
      "crm3-baf-ops-b8638.iam.gserviceaccount.com",
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
    expect(GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT).toBe(
      "crm3-global-pull-writer@" +
      "crm3-baf-ops-b8638.iam.gserviceaccount.com",
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

  test("policy grants only the admitted roles and excludes the old fleet", () => {
    expect(policy.declarationStatus).toBe(
      "SOURCE_IMPLEMENTED_PENDING_IAM_AND_DEPLOYMENT",
    );
    expect(policy.functionBindings.beginGlobalPullRun).toEqual({
      runtimeServiceAccount: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
      requiredProjectRoles: [
        "roles/datastore.viewer",
        "roles/logging.logWriter",
      ],
      firestoreAccess: "READ_ONLY",
    });
    expect(policy.functionBindings.stampGlobalPullServerClock).toEqual({
      runtimeServiceAccount: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
      requiredProjectRoles: [
        "roles/datastore.user",
        "roles/eventarc.eventReceiver",
        "roles/run.invoker",
        "roles/logging.logWriter",
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
    expect(policy.crossProjectGrantAuthorized).toBe(false);
  });
});
