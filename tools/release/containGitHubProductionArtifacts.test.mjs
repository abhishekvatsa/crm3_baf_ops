import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {sealReceipt} = require("./collectProductionGlobalPullBackend.js");
const {
  assertExecutionAuthority,
  classifyInventory,
  createPreflightEvidence,
  parseArgs,
  verifyPreflightReceipt,
} = require("./containGitHubProductionArtifacts.js");

const here = path.dirname(fileURLToPath(import.meta.url));

function artifact(id = 10) {
  return {
    id,
    name: `crm3-baf-ops-build-${id}`,
    sizeBytes: 123,
    digest: `sha256:${"a".repeat(64)}`,
    workflowRunId: 20,
    headSha: "b".repeat(40),
    expired: false,
  };
}

function expected(id = 10) {
  const value = artifact(id);
  delete value.expired;
  return value;
}

test("inventory classifier requires exact IDs and metadata", () => {
  assert.deepEqual(classifyInventory([artifact()], [expected()]), {
    present: [10],
    absent: [],
    mismatched: [],
    unexpected: [],
    exact: true,
  });
  const changed = artifact();
  changed.digest = `sha256:${"c".repeat(64)}`;
  assert.equal(classifyInventory([changed], [expected()]).exact, false);
  assert.deepEqual(
    classifyInventory([], [expected()], {allowAbsent: true}),
    {
      present: [],
      absent: [10],
      mismatched: [],
      unexpected: [],
      exact: true,
    },
  );
});

test("sealed exact preflight authorizes only the same source and policy", () => {
  const source = {
    branch: "main",
    commit: "d".repeat(40),
    tree: "e".repeat(40),
    originMain: "d".repeat(40),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
  };
  const policy = {
    repository: "abhishekvatsa/crm3_baf_ops",
    policyId: "policy",
    expectedArtifactsForContainment: [expected()],
    executionAuthority: {requiredPresentArtifactIds: [10]},
  };
  const evidence = createPreflightEvidence({
    policy,
    policyHash: "F".repeat(64),
    source,
    inventory: [artifact()],
  });
  const receipt = sealReceipt({...evidence, capturedAtUtc: "2026-08-06T00:00:00Z"});
  assert.equal(
    verifyPreflightReceipt(receipt, "F".repeat(64), source),
    true,
  );
  assert.throws(
    () =>
      verifyPreflightReceipt(
        receipt,
        "F".repeat(64),
        {...source, commit: "0".repeat(40)},
      ),
    /does not authorize/,
  );
  assert.throws(
    () => verifyPreflightReceipt({...receipt, receiptSha256: "bad"}, "F".repeat(64), source),
    /seal is invalid/,
  );
  assert.throws(
    () =>
      createPreflightEvidence({
        policy,
        policyHash: "F".repeat(64),
        source,
        inventory: [],
      }),
    /differs from exact policy/,
  );
});

test("contain phase requires a preflight receipt", () => {
  assert.throws(
    () =>
      parseArgs([
        "--phase",
        "contain",
        "--repository-root",
        ".",
        "--repository",
        "abhishekvatsa/crm3_baf_ops",
        "--output",
        "out.json",
      ]),
    /preflight-receipt is required/,
  );
});

test("contain phase requires the exact explicit owner approval phrase", () => {
  assert.throws(
    () =>
      parseArgs([
        "--phase",
        "contain",
        "--repository-root",
        ".",
        "--repository",
        "abhishekvatsa/crm3_baf_ops",
        "--output",
        "out.json",
        "--preflight-receipt",
        "preflight.json",
      ]),
    /--owner-approval is required/,
  );
  const policy = {
    executionAuthority: {
      artifactDeletionRequiresExplicitOwnerApproval: true,
      deleteOnlyExactArtifactIds: true,
      requiredPresentArtifactIds: [10],
      requiredOwnerApprovalPhrase: "APPROVE-LR07-DELETE-EXACT-ARTIFACTS-10",
    },
  };
  assert.throws(
    () =>
      assertExecutionAuthority(
        {phase: "contain", ownerApproval: "wrong"},
        policy,
      ),
    /exact owner approval phrase/,
  );
  assert.doesNotThrow(() =>
    assertExecutionAuthority(
      {
        phase: "contain",
        ownerApproval: policy.executionAuthority.requiredOwnerApprovalPhrase,
      },
      policy,
    ),
  );
});

test("tool can delete only exact artifact endpoints and never workflow runs", () => {
  const source = fs.readFileSync(
    path.join(here, "containGitHubProductionArtifacts.js"),
    "utf8",
  );
  assert.match(
    source,
    /actions\/artifacts\/\$\{artifact\.id\}/,
  );
  assert.doesNotMatch(source, /--method[\s\S]{0,80}actions\/runs\//);
  assert.match(source, /inventoryAfter\.length !== 0/);
  assert.match(source, /artifactDeletionRequiresExplicitOwnerApproval/);
});
