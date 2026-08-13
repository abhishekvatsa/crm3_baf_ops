import assert from "node:assert/strict";
import fs from "node:fs";
import {createRequire} from "node:module";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  PRODUCTION_PROJECT_ID,
  PRODUCTION_REGION,
  accountEmailMap,
  adjudicateReadback,
  expectedProjectRoles,
  parseArgs,
  phaseRequiredNames,
} = require("./collectFunctionFleetRuntimeIdentityReadback.js");

const currentFile = fileURLToPath(import.meta.url);
const repositoryRoot = path.resolve(path.dirname(currentFile), "..", "..");
const policy = JSON.parse(fs.readFileSync(path.join(
  repositoryRoot,
  "release",
  "function-fleet-runtime-identity-policy.json",
), "utf8"));
const emails = accountEmailMap(policy, PRODUCTION_PROJECT_ID);
const expectedRoles = expectedProjectRoles(policy, PRODUCTION_PROJECT_ID);
const functionNames = Object.keys(policy.functionBindings).sort();
const defaultCompute = "894346496105-compute@developer.gserviceaccount.com";

function source(overrides = {}) {
  return {
    branch: "main",
    commit: "a".repeat(40),
    tree: "b".repeat(40),
    originMain: "a".repeat(40),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
    ...overrides,
  };
}

function live(overrides = {}) {
  const projectRoles = Object.fromEntries(functionNames.map((name) => [
    emails[name],
    [...expectedRoles[name]],
  ]));
  projectRoles[defaultCompute] = ["roles/cloudbuild.builds.builder"];
  const functions = functionNames.map((name) => ({
    name,
    state: "ACTIVE",
    environment: "GEN_2",
    serviceAccountEmail: emails[name],
    runService: name.toLowerCase(),
    uri: `https://${name.toLowerCase()}.example.test`,
    updateTime: "2026-08-04T00:00:00Z",
  }));
  const triggerNames = functionNames.filter((name) =>
    policy.functionBindings[name].requiredCloudRunServiceRoles != null);
  const callableNames = phaseRequiredNames(policy, "callables");
  return {
    project: {projectNumber: "894346496105", lifecycleState: "ACTIVE"},
    emailMap: emails,
    expectedRoles,
    serviceAccounts: functionNames.map((name) => ({
      email: emails[name],
      exists: true,
      disabled: false,
    })),
    customRole: {
      exists: true,
      name: `projects/${PRODUCTION_PROJECT_ID}/roles/crm3NotificationSender`,
      stage: "GA",
      deleted: false,
      includedPermissions: ["cloudmessaging.messages.create"],
    },
    projectRoles,
    defaultCompute,
    functions,
    cloudRunBindings: triggerNames.map((name) => ({
      functionName: name,
      runService: name.toLowerCase(),
      expectedServiceAccountEmail: emails[name],
      roles: ["roles/run.invoker"],
    })),
    scheduler: {
      name:
        "firebase-schedule-maintenanceWorkflowEscalationSweep-asia-south1",
      state: "ENABLED",
      schedule: "every 15 minutes",
      timeZone: "Asia/Kolkata",
      oidcServiceAccountEmail: emails.maintenanceWorkflowEscalationSweep,
      lastAttemptTime: "2026-08-04T00:15:00Z",
      statusCode: null,
    },
    backlog: {
      observedAtUtc: "2026-08-04T00:00:00Z",
      counts: {
        pendingLaneAcknowledgement: 0,
        raisedComplianceAcknowledgement: 0,
        activeComplianceCompletion: 0,
      },
      total: 0,
      documentIdsRetained: false,
      businessPayloadsRetained: false,
    },
    callableProbes: callableNames.map((name) => ({
      name,
      httpStatus: 401,
      errorStatus: "UNAUTHENTICATED",
      returnedData: false,
      reachedCallableProtocol: true,
      safeNoSuccess: true,
    })),
    ...overrides,
  };
}

function adjudicate(phase, liveState = live(), overrides = {}) {
  return adjudicateReadback({
    phase,
    projectId: PRODUCTION_PROJECT_ID,
    region: PRODUCTION_REGION,
    policy,
    sourceBefore: source(),
    sourceAfter: source(),
    discoveredSourceExports: functionNames,
    live: liveState,
    probeCallables: ["callables", "events", "fleet", "final"].includes(phase),
    ...overrides,
  });
}

test("final phase proves exact fleet, IAM, scheduler and safe callable probes", () => {
  const result = adjudicate("final");
  assert.deepEqual(result.failedChecks, []);
  assert.equal(
    result.evidence.decision,
    "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL",
  );
  assert.equal(result.evidence.posture.expectedFunctionCount, 15);
  assert.equal(result.evidence.outputs.callableProbes.length, 9);
  assert.ok(
    result.evidence.outputs.callableProbes.some(
      (record) => record.name === "mutateAssetHierarchy",
    ),
  );
  assert.equal(result.evidence.outputs.schedulerBacklog.total, 0);
  assert.equal(
    result.evidence.mutationBoundary.unauthenticatedCallableProbesPerformed,
    true,
  );
  assert.equal(
    result.evidence.mutationBoundary.controlPlaneMutationPerformed,
    false,
  );
});

test("provisioned phase requires additive rollback safety and trigger bootstrap", () => {
  const state = live();
  state.projectRoles[defaultCompute] = [
    "roles/cloudbuild.builds.builder",
    "roles/editor",
  ];
  for (const name of functionNames) {
    if (policy.functionBindings[name].requiredCloudRunServiceRoles != null) {
      state.projectRoles[emails[name]].push("roles/run.invoker");
      state.projectRoles[emails[name]].sort();
    }
  }
  const result = adjudicate("provisioned", state, {probeCallables: false});
  assert.deepEqual(result.failedChecks, []);
});

test("final phase fails closed on Editor, a wrong runtime identity or extra role", () => {
  const state = live();
  state.projectRoles[defaultCompute] = [
    "roles/cloudbuild.builds.builder",
    "roles/editor",
  ];
  state.functions.find((record) =>
    record.name === "completePlannedJobExecution").serviceAccountEmail =
      defaultCompute;
  state.projectRoles[emails.beginGlobalPullRun].push("roles/logging.logWriter");
  const result = adjudicate("final", state);
  assert.ok(result.failedChecks.includes("completeFleetActive"));
  assert.ok(result.failedChecks.includes("runtimeProjectRolesExact"));
  assert.ok(result.failedChecks.includes("defaultComputeEditorRemoved"));
  assert.ok(result.failedChecks.includes("defaultComputeRolesReducedToBuildOnly"));
});

test("final phase rejects an extra service-level role on a trigger identity", () => {
  const state = live();
  state.cloudRunBindings[0].roles.push("roles/run.viewer");
  state.cloudRunBindings[0].roles.sort();
  const result = adjudicate("final", state);
  assert.ok(
    result.failedChecks.includes("requiredCloudRunInvokerBindingsReady"),
  );
});

test("preflight and fleet phases stop on an overdue scheduler backlog", () => {
  const state = live();
  state.backlog = {
    ...state.backlog,
    counts: {...state.backlog.counts, pendingLaneAcknowledgement: 1},
    total: 1,
  };
  for (const phase of ["preflight", "fleet"]) {
    const result = adjudicate(phase, state, {
      probeCallables: phase === "fleet",
    });
    assert.ok(result.failedChecks.includes("schedulerBacklogZero"));
  }
});

test("a private or unreachable callable is not mistaken for an application denial", () => {
  const state = live();
  state.callableProbes[0] = {
    name: state.callableProbes[0].name,
    httpStatus: 403,
    errorStatus: null,
    returnedData: false,
    reachedCallableProtocol: false,
    safeNoSuccess: false,
  };
  const result = adjudicate("final", state);
  assert.ok(
    result.failedChecks.includes("unauthenticatedCallableProbesDoNotSucceed"),
  );
});

test("source drift and incomplete policy ownership fail acquisition", () => {
  const detached = adjudicate("preflight", live(), {
    sourceAfter: source({branch: null}),
    probeCallables: false,
  });
  assert.ok(detached.failedChecks.includes("sourceIsCleanMain"));

  const missingExport = adjudicate("preflight", live(), {
    discoveredSourceExports: functionNames.slice(1),
    probeCallables: false,
  });
  assert.ok(
    missingExport.failedChecks.includes("sourceFunctionInventoryMatchesPolicy"),
  );
});

test("an empty deployed fleet cannot satisfy preflight", () => {
  const state = live({functions: [], cloudRunBindings: []});
  const result = adjudicate("preflight", state, {probeCallables: false});
  assert.ok(result.failedChecks.includes("deployedFunctionsPresent"));
});

test("arguments bind collection to the exact project, region and output", () => {
  const parsed = parseArgs([
    "--phase", "preflight",
    "--repository-root", repositoryRoot,
    "--project-id", PRODUCTION_PROJECT_ID,
    "--region", PRODUCTION_REGION,
    "--output", path.join(repositoryRoot, "..", "receipt.json"),
  ]);
  assert.equal(parsed.phase, "preflight");
  assert.equal(parsed.projectId, PRODUCTION_PROJECT_ID);
  assert.throws(() => parseArgs([
    "--phase", "preflight",
    "--repository-root", repositoryRoot,
    "--project-id", "wrong-project",
    "--region", PRODUCTION_REGION,
    "--output", path.join(repositoryRoot, "..", "receipt.json"),
  ]), /Only production project/);
});

test("collector source contains no mutation command", () => {
  const sourceText = fs.readFileSync(path.join(
    repositoryRoot,
    "tools",
    "release",
    "collectFunctionFleetRuntimeIdentityReadback.js",
  ), "utf8");
  for (const forbidden of [
    "add-iam-policy-binding",
    "remove-iam-policy-binding",
    "service-accounts create",
    "functions deploy",
    "scheduler jobs run",
    "firebase deploy",
  ]) {
    assert.equal(sourceText.includes(forbidden), false, forbidden);
  }
});
