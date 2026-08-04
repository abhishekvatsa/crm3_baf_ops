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
  adjudicateReadback,
  discoverFunctionExports,
  normalizeFunctionDescriptor,
  parseArgs,
  summarizeIam,
  summarizePackageState,
} = require("./collectFunctionsIamDependenciesReadback.js");

const currentFile = fileURLToPath(import.meta.url);
const repositoryRoot = path.resolve(path.dirname(currentFile), "..", "..");

const trackedPackages = ["brace-expansion", "protobufjs", "tar"];

function packageState(versions = {}) {
  const packages = {"": {name: "functions", version: "1.0.0"}};
  const dependencies = {};
  for (const [name, version] of Object.entries(versions)) {
    packages[`node_modules/${name}`] = {version};
    dependencies[name] = `^${version}`;
  }
  return summarizePackageState({
    packageJsonRaw: JSON.stringify({
      name: "functions",
      version: "1.0.0",
      engines: {node: "22"},
      dependencies,
    }),
    packageLockRaw: JSON.stringify({
      name: "functions",
      version: "1.0.0",
      lockfileVersion: 3,
      packages,
    }),
    trackedPackages,
  });
}

const currentDependencies = packageState({
  "brace-expansion": "5.0.9",
  protobufjs: "7.6.5",
});
const oldDependencies = packageState({
  "brace-expansion": "1.1.14",
  protobufjs: "7.5.8",
});

function sourceBinding(overrides = {}) {
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

function functionEvidence({name, identity, dependencies = currentDependencies}) {
  return {
    name,
    resourceName:
      `projects/${PRODUCTION_PROJECT_ID}/locations/${PRODUCTION_REGION}/` +
      `functions/${name}`,
    state: "ACTIVE",
    environment: "GEN_2",
    runtime: "nodejs22",
    entryPoint: name,
    updateTime: "2026-08-04T00:00:00Z",
    build: `projects/1/locations/${PRODUCTION_REGION}/builds/build-${name}`,
    firebaseFunctionsHash: "f".repeat(40),
    serviceAccountEmail: identity,
    source: {
      bucket: "source-bucket",
      object: `${name}/function-source.zip`,
      generation: "123456789",
    },
    sourceArchive: {
      sha256: "A".repeat(64),
      bytes: 1234,
      generationPinnedDownload: true,
    },
    dependencies,
  };
}

function policy(overrides = {}) {
  return {
    productionProjectId: PRODUCTION_PROJECT_ID,
    productionRegion: PRODUCTION_REGION,
    gateIds: ["LR-03", "LR-06"],
    sourceFunctionExports: ["alpha", "beta"],
    sourceDeclaredRuntimeBindings: {},
    forbiddenBroadProjectRoles: ["roles/editor", "roles/owner"],
    trackedRuntimePackages: trackedPackages,
    mutationBoundary: {
      functionsDeployed: false,
      iamMutated: false,
    },
    privacyBoundary: {
      operatorAccountIdentityRetained: false,
      sourceArchiveContentRetained: false,
    },
    ...overrides,
  };
}

function makeIam(functions, bindings = []) {
  return summarizeIam({
    iamPolicy: {version: 1, etag: "etag", bindings},
    functions,
    projectNumber: "123",
  });
}

function adjudicate({
  functions,
  policyValue = policy(),
  bindings = [],
  before = sourceBinding(),
  after = sourceBinding(),
  discoveredSourceExports,
  observe = false,
} = {}) {
  const records =
    functions ??
    [
      functionEvidence({
        name: "alpha",
        identity: "alpha@crm3-baf-ops-b8638.iam.gserviceaccount.com",
      }),
      functionEvidence({
        name: "beta",
        identity: "beta@crm3-baf-ops-b8638.iam.gserviceaccount.com",
      }),
    ];
  return adjudicateReadback({
    projectId: PRODUCTION_PROJECT_ID,
    region: PRODUCTION_REGION,
    sourceBefore: before,
    sourceAfter: after,
    policy: policyValue,
    project: {projectNumber: "123", lifecycleState: "ACTIVE"},
    iam: makeIam(records, bindings),
    functions: records,
    currentDependencies,
    discoveredSourceExports:
      discoveredSourceExports ?? policyValue.sourceFunctionExports,
    observe,
  });
}

test("AST discovery binds the policy to all current Function exports", () => {
  const policyValue = JSON.parse(
    fs.readFileSync(
      path.join(
        repositoryRoot,
        "release",
        "lr03-lr06-functions-live-readback-policy.json",
      ),
      "utf8",
    ),
  );
  const discovered = discoverFunctionExports(repositoryRoot);
  assert.deepEqual(discovered, policyValue.sourceFunctionExports);
  assert.equal(discovered.length, 14);
});

test("dependency summaries retain hashes, counts and selected versions only", () => {
  assert.equal(currentDependencies.lockfileVersion, 3);
  assert.deepEqual(currentDependencies.selectedVersions["brace-expansion"], [
    "5.0.9",
  ]);
  assert.deepEqual(currentDependencies.selectedVersions.tar, []);
  assert.match(currentDependencies.dependencyInventorySha256, /^[0-9A-F]{64}$/);
  assert.equal(JSON.stringify(currentDependencies).includes("node_modules/"), false);
});

test("adverse posture does not corrupt a valid live-readback acquisition", () => {
  const defaultCompute = "123-compute@developer.gserviceaccount.com";
  const beta = "beta@crm3-baf-ops-b8638.iam.gserviceaccount.com";
  const functions = [
    functionEvidence({
      name: "alpha",
      identity: defaultCompute,
      dependencies: oldDependencies,
    }),
    functionEvidence({name: "beta", identity: beta}),
  ];
  const result = adjudicate({
    functions,
    policyValue: policy({
      sourceDeclaredRuntimeBindings: {beta},
    }),
    bindings: [
      {role: "roles/editor", members: [`serviceAccount:${defaultCompute}`]},
      {role: "roles/datastore.viewer", members: [`serviceAccount:${beta}`]},
    ],
  });
  assert.deepEqual(result.failedChecks, []);
  assert.equal(
    result.evidence.decision,
    "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK",
  );
  assert.equal(
    result.evidence.posture.decision,
    "HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE",
  );
  assert.ok(
    result.evidence.posture.holds.includes(
      "functionsStillUseDefaultComputeIdentity",
    ),
  );
  assert.ok(
    result.evidence.posture.holds.includes(
      "deployedDependencyInventoryDiffersFromCurrentSource",
    ),
  );
  assert.equal(result.evidence.closureScope.s01Closed, false);
  assert.equal(result.evidence.closureScope.d01Closed, false);
});

test("fully matching fixtures distinguish clean posture from evidence capture", () => {
  const alpha = "alpha@crm3-baf-ops-b8638.iam.gserviceaccount.com";
  const beta = "beta@crm3-baf-ops-b8638.iam.gserviceaccount.com";
  const result = adjudicate({
    policyValue: policy({
      sourceDeclaredRuntimeBindings: {alpha, beta},
    }),
  });
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.evidence.posture.decision, "PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE");
  assert.deepEqual(result.evidence.posture.holds, []);
});

test("fleet drift is retained as posture evidence without inventing deployment", () => {
  const result = adjudicate({
    functions: [
      functionEvidence({
        name: "alpha",
        identity: "alpha@crm3-baf-ops-b8638.iam.gserviceaccount.com",
      }),
    ],
  });
  assert.deepEqual(result.failedChecks, []);
  assert.deepEqual(result.evidence.posture.missingFromLive, ["beta"]);
  assert.equal(result.evidence.posture.fleetMatchesSource, false);
  assert.equal(result.evidence.mutationBoundary.functionsDeployed, false);
});

test("strict acquisition fails closed on dirty, detached or incomplete source", () => {
  const dirty = adjudicate({
    after: sourceBinding({
      governedWorktreeClean: false,
      materialChangeCount: 1,
      materialPathSha256: ["C".repeat(64)],
    }),
  });
  assert.ok(dirty.failedChecks.includes("governedSourceClean"));
  assert.equal(
    dirty.evidence.decision,
    "HOLD_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK",
  );

  const detached = adjudicate({
    before: sourceBinding({branch: null}),
    after: sourceBinding({branch: null}),
  });
  assert.ok(detached.failedChecks.includes("sourceBranchMain"));

  const unownedExport = adjudicate({
    discoveredSourceExports: ["alpha", "beta", "newFunction"],
  });
  assert.ok(
    unownedExport.failedChecks.includes("sourceExportInventoryMatchesPolicy"),
  );
});

test("observation mode can never authorize gate evidence", () => {
  const result = adjudicate({observe: true});
  assert.deepEqual(result.failedChecks, []);
  assert.equal(
    result.evidence.decision,
    "OBSERVE_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK",
  );
});

test("IAM evidence retains only deployed runtime service accounts", () => {
  const runtime = "runtime@crm3-baf-ops-b8638.iam.gserviceaccount.com";
  const functions = [functionEvidence({name: "alpha", identity: runtime})];
  const summary = makeIam(functions, [
    {
      role: "roles/datastore.viewer",
      members: [
        `serviceAccount:${runtime}`,
        "serviceAccount:unrelated@crm3-baf-ops-b8638.iam.gserviceaccount.com",
        "user:operator@example.com",
      ],
    },
  ]);
  const serialized = JSON.stringify(summary);
  assert.equal(serialized.includes(runtime), true);
  assert.equal(serialized.includes("unrelated@"), false);
  assert.equal(serialized.includes("operator@example.com"), false);
});

test("Function provenance rejects wrong projects and missing generations", () => {
  const valid = {
    name:
      `projects/${PRODUCTION_PROJECT_ID}/locations/${PRODUCTION_REGION}/` +
      "functions/alpha",
    state: "ACTIVE",
    environment: "GEN_2",
    buildConfig: {
      runtime: "nodejs22",
      entryPoint: "alpha",
      sourceProvenance: {
        resolvedStorageSource: {
          bucket: "bucket",
          object: "alpha/function-source.zip",
          generation: "123",
        },
      },
    },
    serviceConfig: {
      serviceAccountEmail:
        "alpha@crm3-baf-ops-b8638.iam.gserviceaccount.com",
    },
  };
  assert.equal(
    normalizeFunctionDescriptor(
      valid,
      PRODUCTION_PROJECT_ID,
      PRODUCTION_REGION,
    ).source.generation,
    "123",
  );
  assert.throws(
    () =>
      normalizeFunctionDescriptor(
        {
          ...valid,
          name:
            `projects/wrong/locations/${PRODUCTION_REGION}/functions/alpha`,
        },
        PRODUCTION_PROJECT_ID,
        PRODUCTION_REGION,
      ),
    /outside the exact project and region/,
  );
  assert.throws(
    () =>
      normalizeFunctionDescriptor(
        {
          ...valid,
          buildConfig: {
            ...valid.buildConfig,
            sourceProvenance: {resolvedStorageSource: {bucket: "bucket"}},
          },
        },
        PRODUCTION_PROJECT_ID,
        PRODUCTION_REGION,
      ),
    /lacks generation-pinned source provenance/,
  );
});

test("arguments are exact-target and append-only output is explicit", () => {
  const parsed = parseArgs([
    "--repository-root",
    ".",
    "--project-id",
    PRODUCTION_PROJECT_ID,
    "--region",
    PRODUCTION_REGION,
    "--output",
    "../receipt.json",
    "--observe",
  ]);
  assert.equal(parsed.observe, true);
  assert.throws(
    () =>
      parseArgs([
        "--repository-root",
        ".",
        "--project-id",
        "wrong-project",
        "--region",
        PRODUCTION_REGION,
        "--output",
        "../receipt.json",
      ]),
    /Only the exact production project/,
  );
});

test("collector source contains no production mutation command", () => {
  const source = fs.readFileSync(
    path.join(
      path.dirname(currentFile),
      "collectFunctionsIamDependenciesReadback.js",
    ),
    "utf8",
  );
  for (const forbidden of [
    '"functions", "deploy"',
    '"functions", "delete"',
    '"projects", "add-iam-policy-binding"',
    '"projects", "remove-iam-policy-binding"',
    '"iam", "service-accounts", "create"',
    '"iam", "service-accounts", "delete"',
    "firebase deploy",
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
  assert.ok(source.includes('"functions",\n      "list"'));
  assert.ok(source.includes('"projects", "get-iam-policy"'));
  assert.ok(source.includes('"storage",\n      "cp"'));
  assert.ok(source.includes("--if-generation-match="));
});
