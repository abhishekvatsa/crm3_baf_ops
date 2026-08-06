"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const {
  canonicalJson,
  sealReceipt,
} = require("./collectProductionGlobalPullBackend.js");
const {
  collectSourceBinding,
  isPathInside,
  sha256,
} = require("./collectFirestoreRulesIndexesReadback.js");
const {
  EXPECTED_REPOSITORY,
  POLICY_PATH,
  selectProductionArtifacts,
  summarizeSource,
} = require("./collectDistributionInstallationReadback.js");

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const options = {ghCommand: "gh"};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    const fields = {
      "--phase": "phase",
      "--repository-root": "repositoryRoot",
      "--repository": "repository",
      "--output": "outputPath",
      "--preflight-receipt": "preflightReceiptPath",
      "--owner-approval": "ownerApproval",
      "--gh": "ghCommand",
    };
    const field = fields[argument];
    if (field == null) fail(`Unsupported argument: ${argument}`);
    if (field !== "ghCommand" && options[field] != null) {
      fail(`Duplicate argument: ${argument}`);
    }
    const value = argv[index + 1];
    if (value == null || value.startsWith("--")) {
      fail(`${argument} requires a value.`);
    }
    options[field] = value;
    index += 1;
  }
  for (const field of ["phase", "repositoryRoot", "repository", "outputPath"]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  if (!new Set(["preflight", "contain"]).has(options.phase)) {
    fail("--phase must be preflight or contain.");
  }
  if (options.phase === "contain" && options.preflightReceiptPath == null) {
    fail("--preflight-receipt is required for contain.");
  }
  if (options.phase === "contain" && options.ownerApproval == null) {
    fail("--owner-approval is required for contain.");
  }
  if (options.phase === "preflight" && options.preflightReceiptPath != null) {
    fail("--preflight-receipt is not accepted for preflight.");
  }
  if (options.phase === "preflight" && options.ownerApproval != null) {
    fail("--owner-approval is not accepted for preflight.");
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.outputPath = path.resolve(options.outputPath);
  if (options.preflightReceiptPath != null) {
    options.preflightReceiptPath = path.resolve(options.preflightReceiptPath);
  }
  if (options.repository !== EXPECTED_REPOSITORY) {
    fail(`Only the exact repository ${EXPECTED_REPOSITORY} is supported.`);
  }
  return options;
}

function runText(command, args, options = {}) {
  return childProcess
    .execFileSync(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      env: {...process.env, GH_PAGER: "cat", NO_COLOR: "1"},
      maxBuffer: 64 * 1024 * 1024,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    })
    .trim();
}

function runJson(command, args, repositoryRoot) {
  const raw = runText(command, args, {cwd: repositoryRoot});
  try {
    return JSON.parse(raw);
  } catch (error) {
    fail(`Command returned malformed JSON: ${error.message}`);
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function policySha256(repositoryRoot) {
  return sha256(fs.readFileSync(path.join(repositoryRoot, POLICY_PATH)));
}

function listProductionArtifacts(options, policy) {
  const artifactPages = runJson(
    options.ghCommand,
    [
      "api",
      "--paginate",
      "--slurp",
      `repos/${options.repository}/actions/artifacts?per_page=100`,
    ],
    options.repositoryRoot,
  );
  const workflowFile = path.basename(policy.workflow.path);
  const runPages = runJson(
    options.ghCommand,
    [
      "api",
      "--paginate",
      "--slurp",
      `repos/${options.repository}/actions/workflows/${workflowFile}/runs?per_page=100`,
    ],
    options.repositoryRoot,
  );
  return selectProductionArtifacts(
    artifactPages.flatMap((page) => page.artifacts ?? []),
    runPages.flatMap((page) => page.workflow_runs ?? []),
  );
}

function artifactExact(actual, expected) {
  return (
    actual.id === expected.id &&
    actual.name === expected.name &&
    actual.sizeBytes === expected.sizeBytes &&
    actual.digest === expected.digest &&
    actual.workflowRunId === expected.workflowRunId &&
    actual.headSha === expected.headSha &&
    actual.expired === false
  );
}

function classifyInventory(actualArtifacts, expectedArtifacts, options = {}) {
  const actualById = new Map(
    actualArtifacts.map((artifact) => [artifact.id, artifact]),
  );
  const expectedIds = new Set(expectedArtifacts.map((artifact) => artifact.id));
  const unexpected = actualArtifacts.filter(
    (artifact) => !expectedIds.has(artifact.id),
  );
  const mismatched = [];
  const present = [];
  const absent = [];
  for (const expected of expectedArtifacts) {
    const actual = actualById.get(expected.id);
    if (actual == null) {
      absent.push(expected.id);
    } else if (!artifactExact(actual, expected)) {
      mismatched.push(expected.id);
    } else {
      present.push(expected.id);
    }
  }
  const allowAbsent = options.allowAbsent === true;
  return {
    present,
    absent,
    mismatched,
    unexpected: unexpected.map((artifact) => artifact.id),
    exact:
      mismatched.length === 0 &&
      unexpected.length === 0 &&
      (allowAbsent || absent.length === 0),
  };
}

function verifyPreflightReceipt(receipt, policyHash, currentSource) {
  if (receipt == null || typeof receipt !== "object") {
    fail("Preflight receipt is malformed.");
  }
  const body = {...receipt};
  delete body.receiptSha256;
  const computed = sealReceipt(body).receiptSha256;
  if (computed !== receipt.receiptSha256) {
    fail("Preflight receipt seal is invalid.");
  }
  if (
    receipt.evidenceType !== "lr07-public-production-artifact-containment" ||
    receipt.phase !== "PREFLIGHT" ||
    receipt.decision !== "PASS_LR07_PUBLIC_ARTIFACT_CONTAINMENT_PREFLIGHT" ||
    receipt.policySha256 !== policyHash ||
    receipt.source?.commit !== currentSource.commit ||
    receipt.source?.originMain !== currentSource.originMain ||
    receipt.source?.tree !== currentSource.tree ||
    receipt.inventory?.exact !== true ||
    receipt.mutationBoundary?.githubArtifactsDeleted !== false
  ) {
    fail("Preflight receipt does not authorize this exact containment.");
  }
  return true;
}

function assertSourceAuthority(source, sourceSummary) {
  if (
    source.branch !== "main" ||
    source.commit !== source.originMain ||
    source.governedWorktreeClean !== true ||
    source.materialChangeCount !== 0 ||
    !sourceSummary.files.every((entry) => entry.exact === true) ||
    sourceSummary.workflowRetentionExact !== true ||
    !sourceSummary.buildLedgerArtifacts.every((entry) => entry.exact === true)
  ) {
    fail("Clean exact merged main and source authority are required.");
  }
}

function assertExecutionAuthority(options, policy) {
  const authority = policy.executionAuthority;
  if (
    authority?.artifactDeletionRequiresExplicitOwnerApproval !== true ||
    authority?.deleteOnlyExactArtifactIds !== true ||
    typeof authority?.requiredOwnerApprovalPhrase !== "string" ||
    authority.requiredOwnerApprovalPhrase.length < 32
  ) {
    fail("Policy does not carry exact explicit-owner deletion authority.");
  }
  if (
    options.phase === "contain" &&
    options.ownerApproval !== authority.requiredOwnerApprovalPhrase
  ) {
    fail("The exact owner approval phrase was not supplied.");
  }
}

function createPreflightEvidence({policy, policyHash, source, inventory}) {
  const classification = classifyInventory(
    inventory,
    policy.expectedArtifactsForContainment,
  );
  if (!classification.exact) {
    fail("Live production artifact inventory differs from exact policy.");
  }
  return {
    schemaVersion: 1,
    evidenceType: "lr07-public-production-artifact-containment",
    phase: "PREFLIGHT",
    repository: policy.repository,
    policyId: policy.policyId,
    policySha256: policyHash,
    source,
    inventory: {
      count: inventory.length,
      totalBytes: inventory.reduce(
        (total, artifact) => total + artifact.sizeBytes,
        0,
      ),
      artifactIds: inventory.map((artifact) => artifact.id),
      artifactDigests: inventory.map((artifact) => artifact.digest),
      ...classification,
    },
    decision: "PASS_LR07_PUBLIC_ARTIFACT_CONTAINMENT_PREFLIGHT",
    mutationBoundary: {
      githubArtifactsDeleted: false,
      workflowRunsDeleted: false,
      repositoryVisibilityChanged: false,
      releasesChanged: false,
      tagsChanged: false,
      sourceChanged: false,
      firebaseChanged: false,
      deviceChanged: false,
    },
  };
}

function deleteExactArtifacts(options, policy, inventory) {
  const classification = classifyInventory(
    inventory,
    policy.expectedArtifactsForContainment,
    {allowAbsent: true},
  );
  if (!classification.exact) {
    fail("Containment inventory contains an unexpected or changed artifact.");
  }
  const deletedNow = [];
  for (const artifact of inventory) {
    if (!classification.present.includes(artifact.id)) continue;
    runText(
      options.ghCommand,
      [
        "api",
        "--method",
        "DELETE",
        `repos/${options.repository}/actions/artifacts/${artifact.id}`,
      ],
      {cwd: options.repositoryRoot},
    );
    deletedNow.push(artifact.id);
  }
  return {deletedNow, alreadyAbsent: classification.absent};
}

function writeReceipt(outputPath, evidence) {
  const receipt = sealReceipt({
    ...evidence,
    capturedAtUtc: new Date().toISOString(),
  });
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  process.stdout.write(
    `${JSON.stringify({
      decision: receipt.decision,
      outputPath,
      receiptSha256: receipt.receiptSha256,
    })}\n`,
  );
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("Containment evidence must be written outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail(`Output already exists: ${options.outputPath}`);
  }
  const policy = readJson(path.join(options.repositoryRoot, POLICY_PATH));
  assertExecutionAuthority(options, policy);
  const policyHash = policySha256(options.repositoryRoot);
  const sourceBefore = collectSourceBinding(options.repositoryRoot);
  const sourceSummary = summarizeSource(options.repositoryRoot, policy);
  assertSourceAuthority(sourceBefore, sourceSummary);
  const inventoryBefore = listProductionArtifacts(options, policy);

  if (options.phase === "preflight") {
    writeReceipt(
      options.outputPath,
      createPreflightEvidence({
        policy,
        policyHash,
        source: sourceBefore,
        inventory: inventoryBefore,
      }),
    );
    return;
  }

  const preflight = readJson(options.preflightReceiptPath);
  verifyPreflightReceipt(preflight, policyHash, sourceBefore);
  const mutation = deleteExactArtifacts(options, policy, inventoryBefore);
  const inventoryAfter = listProductionArtifacts(options, policy);
  if (inventoryAfter.length !== 0) {
    fail("Production artifact inventory is not empty after containment.");
  }
  const sourceAfter = collectSourceBinding(options.repositoryRoot);
  if (canonicalJson(sourceAfter) !== canonicalJson(sourceBefore)) {
    fail("Source authority changed during remote containment.");
  }
  writeReceipt(options.outputPath, {
    schemaVersion: 1,
    evidenceType: "lr07-public-production-artifact-containment",
    phase: "CONTAIN",
    repository: policy.repository,
    policyId: policy.policyId,
    policySha256: policyHash,
    source: sourceAfter,
    preflightReceiptSha256: preflight.receiptSha256,
    inventoryBefore: {
      count: inventoryBefore.length,
      artifactIds: inventoryBefore.map((artifact) => artifact.id),
    },
    result: {
      deletedNow: mutation.deletedNow,
      alreadyAbsent: mutation.alreadyAbsent,
      remainingProductionArtifactCount: inventoryAfter.length,
      ownerApprovalAcknowledged: true,
      ownerApprovalPhraseSha256: sha256(
        policy.executionAuthority.requiredOwnerApprovalPhrase,
      ),
      workflowRunsPreserved: true,
      repositoryVisibilityChanged: false,
    },
    decision: "PASS_LR07_PUBLIC_PRODUCTION_ARTIFACTS_CONTAINED",
    mutationBoundary: {
      githubArtifactsDeleted: mutation.deletedNow.length > 0,
      githubArtifactDeleteCount: mutation.deletedNow.length,
      workflowRunsDeleted: false,
      repositoryVisibilityChanged: false,
      releasesChanged: false,
      tagsChanged: false,
      sourceChanged: false,
      firebaseChanged: false,
      deviceChanged: false,
    },
  });
}

module.exports = {
  artifactExact,
  assertExecutionAuthority,
  classifyInventory,
  createPreflightEvidence,
  parseArgs,
  verifyPreflightReceipt,
};

if (require.main === module) {
  try {
    main();
  } catch (error) {
    process.stderr.write(
      `LR07_PUBLIC_ARTIFACT_CONTAINMENT_FAILED: ${error.message}\n`,
    );
    process.exitCode = 1;
  }
}
