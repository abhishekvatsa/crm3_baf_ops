"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const {sealReceipt} = require("./collectProductionGlobalPullBackend.js");
const {
  collectSourceBinding,
  isPathInside,
  sha256,
} = require("./collectFirestoreRulesIndexesReadback.js");

const POLICY_PATH =
  "release/lr07-distribution-installation-readback-policy.json";
const EXPECTED_REPOSITORY = "abhishekvatsa/crm3_baf_ops";
const EXPECTED_PROJECT_ID = "crm3-baf-ops-b8638";

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const options = {observe: false, ghCommand: "gh"};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--observe") {
      options.observe = true;
      continue;
    }
    const fields = {
      "--repository-root": "repositoryRoot",
      "--repository": "repository",
      "--project-id": "projectId",
      "--installation-receipt": "installationReceiptPath",
      "--output": "outputPath",
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
  for (const field of [
    "repositoryRoot",
    "repository",
    "projectId",
    "installationReceiptPath",
    "outputPath",
  ]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.installationReceiptPath = path.resolve(
    options.installationReceiptPath,
  );
  options.outputPath = path.resolve(options.outputPath);
  if (options.repository !== EXPECTED_REPOSITORY) {
    fail(`Only the exact repository ${EXPECTED_REPOSITORY} is supported.`);
  }
  if (options.projectId !== EXPECTED_PROJECT_ID) {
    fail(`Only the exact project ${EXPECTED_PROJECT_ID} is supported.`);
  }
  return options;
}

function runText(command, args, options = {}) {
  return childProcess
    .execFileSync(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        GH_PAGER: "cat",
        NO_COLOR: "1",
      },
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

function fileAuthority(repositoryRoot, expected) {
  const filePath = path.join(repositoryRoot, expected.path);
  if (!fs.existsSync(filePath)) {
    return {path: expected.path, exists: false, exact: false};
  }
  const bytes = fs.statSync(filePath).size;
  const fileSha256 = sha256(fs.readFileSync(filePath));
  return {
    path: expected.path,
    exists: true,
    bytes,
    sha256: fileSha256,
    exact: bytes === expected.bytes && fileSha256 === expected.sha256,
  };
}

function summarizeMutableSourceAuthority({policy, releasePolicy, buildLedger}) {
  const expectedArtifacts = policy.expectedArtifactsForContainment;
  const latestExpectedArtifact = expectedArtifacts.reduce(
    (latest, entry) =>
      latest == null || entry.buildNumber > latest.buildNumber ? entry : latest,
    null,
  );
  const completedArtifacts = expectedArtifacts.filter(
    (entry) => entry.dualCustodyCompleted === true,
  );
  const latestCompletedArtifact = completedArtifacts.reduce(
    (latest, entry) =>
      latest == null || entry.buildNumber > latest.buildNumber ? entry : latest,
    null,
  );
  const receiptPathFor = (artifact) =>
    artifact?.authorityReceiptPath ??
    `release/evidence/build-${artifact?.buildNumber}-finalization-closure.json`;
  const completedReceiptAuthority = policy.sourceEvidence.find(
    (entry) => entry.path === receiptPathFor(latestCompletedArtifact),
  );
  const latestReceiptAuthority = policy.sourceEvidence.find(
    (entry) => entry.path === receiptPathFor(latestExpectedArtifact),
  );
  const finalization = releasePolicy.finalization ?? {};
  const currentBuildNumber = releasePolicy.release?.buildNumber;
  let preservedFinalization = null;
  if (
    latestCompletedArtifact != null &&
    finalization.status === "completed-non-distributable" &&
    currentBuildNumber === latestCompletedArtifact.buildNumber
  ) {
    preservedFinalization = {
      ...finalization,
      buildNumber: currentBuildNumber,
    };
  } else if (
    latestCompletedArtifact != null &&
    finalization.status === "pending-source-authorized" &&
    Number.isInteger(currentBuildNumber) &&
    currentBuildNumber > latestCompletedArtifact.buildNumber
  ) {
    preservedFinalization = finalization.priorCompletedBuild ?? null;
  }

  const preservedFinalizationExact =
    latestCompletedArtifact != null &&
    completedReceiptAuthority != null &&
    preservedFinalization?.buildNumber === latestCompletedArtifact.buildNumber &&
    preservedFinalization?.status === "completed-non-distributable" &&
    preservedFinalization?.completionReceiptFile ===
      completedReceiptAuthority.path &&
    preservedFinalization?.completionReceiptSha256 ===
      completedReceiptAuthority.sha256 &&
    preservedFinalization?.sourceCommit === latestCompletedArtifact.headSha &&
    preservedFinalization?.githubRunId ===
      latestCompletedArtifact.workflowRunId &&
    preservedFinalization?.governedPackageSha256 ===
      latestCompletedArtifact.governedPackageSha256 &&
    preservedFinalization?.dualCustodyCompleted === true;
  const failedAttempt = finalization.priorFailedAttempt ?? null;
  const historicalFailedAttempts = [
    ...(finalization.historicalFailedAttempts ?? []),
    ...(failedAttempt == null ? [] : [failedAttempt]),
  ];
  const failedArtifactsWithReceipts = expectedArtifacts.filter(
    (artifact) =>
      artifact.dualCustodyCompleted !== true &&
      artifact.authorityReceiptPath != null,
  );
  const historicalFailedAttemptsExact = failedArtifactsWithReceipts.every(
    (artifact) => {
      const authority = policy.sourceEvidence.find(
        (entry) => entry.path === receiptPathFor(artifact),
      );
      const attempt = historicalFailedAttempts.find(
        (entry) => entry.buildNumber === artifact.buildNumber,
      );
      return (
        authority != null &&
        attempt?.status === "blocked-non-distributable" &&
        attempt?.evidenceFile === authority.path &&
        attempt?.evidenceSha256 === authority.sha256 &&
        attempt?.sourceCommit === artifact.headSha &&
        attempt?.githubRunId === artifact.workflowRunId &&
        attempt?.githubArtifactId === artifact.id &&
        attempt?.githubArtifactDigest === artifact.digest &&
        attempt?.governedPackageSha256 === artifact.governedPackageSha256 &&
        attempt?.independentVerificationCompleted === true &&
        attempt?.dualCustodyCompleted === false &&
        attempt?.distributionPerformed === false
      );
    },
  );
  const latestContainmentAttemptExact =
    latestExpectedArtifact != null &&
    (latestExpectedArtifact.dualCustodyCompleted === true
      ? latestExpectedArtifact.buildNumber === latestCompletedArtifact?.buildNumber &&
        preservedFinalizationExact
      : latestReceiptAuthority != null &&
        failedAttempt?.buildNumber === latestExpectedArtifact.buildNumber &&
        failedAttempt?.status === "blocked-non-distributable" &&
        failedAttempt?.evidenceFile === latestReceiptAuthority.path &&
        failedAttempt?.evidenceSha256 === latestReceiptAuthority.sha256 &&
        failedAttempt?.sourceCommit === latestExpectedArtifact.headSha &&
        failedAttempt?.githubRunId === latestExpectedArtifact.workflowRunId &&
        failedAttempt?.githubArtifactId === latestExpectedArtifact.id &&
        failedAttempt?.githubArtifactDigest === latestExpectedArtifact.digest &&
        failedAttempt?.governedPackageSha256 ===
          latestExpectedArtifact.governedPackageSha256 &&
        failedAttempt?.independentVerificationCompleted === true &&
        failedAttempt?.dualCustodyCompleted === false &&
        failedAttempt?.distributionPerformed === false);

  const expectedLedgerEntriesExact = expectedArtifacts.every((expected) => {
    const entry = buildLedger.entries?.find(
      (candidate) => candidate.buildNumber === expected.buildNumber,
    );
    return (
      entry != null &&
      entry.githubArtifactId === expected.id &&
      entry.githubArtifactName === expected.name &&
      entry.githubArtifactSizeBytes === expected.sizeBytes &&
      entry.githubArtifactDigest === expected.digest &&
      entry.githubRunId === expected.workflowRunId &&
      entry.remoteReservationCommit === expected.headSha &&
      entry.disposition === expected.ledgerDisposition &&
      entry.dualCustodyCompleted === expected.dualCustodyCompleted &&
      entry.distributionPerformed !== true
    );
  });
  const successorEntries = (buildLedger.entries ?? []).filter(
    (entry) =>
      latestExpectedArtifact != null &&
      entry.buildNumber > latestExpectedArtifact.buildNumber,
  );
  const sourceOnlySuccessorsExact = successorEntries.every(
    (entry) =>
      entry.status === "source-reserved-awaiting-remote-consumption" &&
      entry.disposition == null &&
      entry.githubRunId == null &&
      entry.githubArtifactId == null &&
      entry.githubArtifactDigest == null &&
      entry.governedPackageSha256 == null &&
      entry.artifactConstructed == null &&
      entry.distributionPerformed !== true,
  );
  const pendingSuccessorExact =
    finalization.status !== "pending-source-authorized" ||
    (successorEntries.length === 1 &&
      successorEntries[0].buildNumber === currentBuildNumber);

  return {
    releasePolicyExact:
      releasePolicy.firebaseProjectId === policy.productionProjectId &&
      releasePolicy.permanentApplicationId === policy.applicationId &&
      releasePolicy.github?.repository === policy.repository &&
      releasePolicy.github?.environmentReviewControl?.repositoryVisibility ===
        "public" &&
      preservedFinalizationExact &&
      latestContainmentAttemptExact &&
      historicalFailedAttemptsExact &&
      pendingSuccessorExact &&
      releasePolicy.distribution?.approved === false &&
      releasePolicy.distribution?.unrestrictedPlantReleaseApproved === false,
    buildLedgerExact:
      expectedLedgerEntriesExact &&
      sourceOnlySuccessorsExact &&
      pendingSuccessorExact,
    latestContainmentAttemptExact,
  };
}

function summarizeSource(repositoryRoot, policy) {
  const deploymentScope = readJson(
    path.join(
      repositoryRoot,
      "release/stage2d-f-internal-controlled-deployment-scope.json",
    ),
  );
  const platformScope = readJson(
    path.join(repositoryRoot, "release/client-platform-scope.prod.json"),
  );
  const releasePolicy = readJson(
    path.join(repositoryRoot, "release/production-release-policy.json"),
  );
  const buildLedger = readJson(
    path.join(repositoryRoot, "release/build-number-ledger.json"),
  );
  const build8Finalization = readJson(
    path.join(
      repositoryRoot,
      "release/evidence/build-8-finalization-closure.json",
    ),
  );
  const latestExpectedArtifact = policy.expectedArtifactsForContainment.reduce(
    (latest, entry) =>
      latest == null || entry.buildNumber > latest.buildNumber ? entry : latest,
    null,
  );
  const latestAuthorityReceipt = readJson(
    path.join(
      repositoryRoot,
      latestExpectedArtifact.authorityReceiptPath ??
        `release/evidence/build-${latestExpectedArtifact.buildNumber}-finalization-closure.json`,
    ),
  );
  const installationAdjudication = readJson(
    path.join(
      repositoryRoot,
      "release/evidence/build-8-f4-intermittent-connectivity-adjudication.json",
    ),
  );
  const workflow = fs.readFileSync(
    path.join(repositoryRoot, policy.workflow.path),
    "utf8",
  );
  const expectedArtifacts = policy.expectedArtifactsForContainment;
  const ledgerArtifacts = expectedArtifacts.map((expected) => {
    const entry = buildLedger.entries.find(
      (candidate) => candidate.buildNumber === expected.buildNumber,
    );
    const exact =
      entry != null &&
      entry.githubArtifactId === expected.id &&
      entry.githubArtifactName === expected.name &&
      entry.githubArtifactSizeBytes === expected.sizeBytes &&
      entry.githubArtifactDigest === expected.digest &&
      entry.githubRunId === expected.workflowRunId &&
      entry.remoteReservationCommit === expected.headSha &&
      entry.disposition === expected.ledgerDisposition &&
      entry.dualCustodyCompleted === expected.dualCustodyCompleted &&
      entry.distributionPerformed !== true;
    return {buildNumber: expected.buildNumber, exact};
  });
  const mutableAuthority = summarizeMutableSourceAuthority({
    policy,
    releasePolicy,
    buildLedger,
  });
  const semanticAuthority = new Map([
    [
      "release/production-release-policy.json",
      mutableAuthority.releasePolicyExact,
    ],
    ["release/build-number-ledger.json", mutableAuthority.buildLedgerExact],
  ]);
  const files = policy.sourceEvidence.map((entry) => {
    const measured = fileAuthority(repositoryRoot, entry);
    if (!semanticAuthority.has(entry.path)) return measured;
    return {
      ...measured,
      byteExact: measured.exact,
      authorityMode: "SEMANTIC_PRESERVED_BUILD",
      exact: semanticAuthority.get(entry.path) === true,
    };
  });
  return {
    files,
    workflowRetentionExact: workflow.includes(
      `retention-days: ${policy.workflow.requiredArtifactRetentionDays}`,
    ),
    distributionScopeExact:
      deploymentScope.projectId === policy.productionProjectId &&
      deploymentScope.application?.packageId === policy.applicationId &&
      deploymentScope.distribution?.playConsole ===
        policy.strictReadback.requiredPlayConsoleState &&
      deploymentScope.distribution?.playStore ===
        policy.strictReadback.requiredPlayStoreState &&
      deploymentScope.distribution?.webDistribution ===
        policy.strictReadback.requiredWebDistributionState &&
      deploymentScope.distribution?.externalOrPublicDistribution ===
        policy.strictReadback.requiredExternalDistributionState,
    platformScopeExact:
      platformScope.projectId === policy.productionProjectId &&
      JSON.stringify(platformScope.currentReleasePlatforms) ===
        JSON.stringify(policy.strictReadback.requiredCurrentReleasePlatforms),
    releasePolicyExact: mutableAuthority.releasePolicyExact,
    buildLedgerExact: mutableAuthority.buildLedgerExact,
    buildLedgerArtifacts: ledgerArtifacts,
    build8FinalizationExact:
      build8Finalization.status === "passed-non-distributable" &&
      build8Finalization.release?.buildNumber === 8 &&
      build8Finalization.governedPackage?.sha256 ===
        policy.installationReceipt.governedPackageSha256 &&
      build8Finalization.governedPackage?.apkSha256 ===
        policy.installationReceipt.installedApkSha256 &&
      build8Finalization.dualCustody?.status === "passed" &&
      build8Finalization.releaseBoundary?.distributionPerformed === false,
    latestContainmentFinalizationExact:
      mutableAuthority.latestContainmentAttemptExact === true &&
      latestAuthorityReceipt != null,
    installationAdjudicationExact:
      installationAdjudication.decision ===
        "PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_ADJUDICATED" &&
      installationAdjudication.externalReceipt?.sha256 ===
        policy.installationReceipt.sha256 &&
      installationAdjudication.externalReceipt?.bytes ===
        policy.installationReceipt.bytes &&
      installationAdjudication.verifiedFacts?.installedApkSha256 ===
        policy.installationReceipt.installedApkSha256 &&
      installationAdjudication.verifiedFacts?.physicalDeviceVerified === true &&
      installationAdjudication.verifiedFacts?.productionSignerVerified === true &&
      installationAdjudication.executionBoundary?.distributionPerformed ===
        false,
  };
}

function summarizeInstallationReceipt(receiptPath, policy) {
  const expected = policy.installationReceipt;
  const bytes = fs.statSync(receiptPath).size;
  const fileSha256 = sha256(fs.readFileSync(receiptPath));
  const receipt = readJson(receiptPath);
  const exact =
    path.basename(receiptPath) === expected.fileName &&
    bytes === expected.bytes &&
    fileSha256 === expected.sha256 &&
    receipt.schemaVersion === 1 &&
    receipt.evidenceType === "build-8-f4-intermittent-connectivity" &&
    receipt.decision === expected.decision &&
    receipt.artifact?.versionCode === expected.versionCode &&
    receipt.artifact?.governedPackageSha256 ===
      expected.governedPackageSha256 &&
    receipt.artifact?.installedApkSha256 === expected.installedApkSha256 &&
    receipt.artifact?.productionSignerVerified === true &&
    receipt.target?.physicalDevice === true &&
    receipt.target?.rawIdentifiersRetained === false &&
    receipt.session?.approvedHomeReached === true &&
    receipt.session?.accountIdentityRetained === false &&
    receipt.mutationBoundary?.distributionPerformed === false &&
    receipt.privacyBoundary?.businessPayloadRetained === false;
  return {
    fileName: path.basename(receiptPath),
    bytes,
    sha256: fileSha256,
    capturedAtUtc: receipt.capturedAtUtc ?? null,
    decision: receipt.decision ?? null,
    versionCode: receipt.artifact?.versionCode ?? null,
    physicalDevice: receipt.target?.physicalDevice === true,
    productionSignerVerified:
      receipt.artifact?.productionSignerVerified === true,
    approvedSessionVerified: receipt.session?.approvedHomeReached === true,
    rawIdentifiersRetained: receipt.target?.rawIdentifiersRetained !== false,
    accountIdentityRetained: receipt.session?.accountIdentityRetained !== false,
    exact,
  };
}

function selectProductionArtifacts(artifacts, workflowRuns) {
  const productionRunIds = new Set(workflowRuns.map((run) => run.id));
  return artifacts
    .filter(
      (artifact) =>
        artifact.expired !== true &&
        productionRunIds.has(artifact.workflow_run?.id),
    )
    .map((artifact) => ({
      id: artifact.id,
      name: artifact.name,
      sizeBytes: artifact.size_in_bytes,
      digest: artifact.digest ?? null,
      workflowRunId: artifact.workflow_run?.id ?? null,
      headSha: artifact.workflow_run?.head_sha ?? null,
      expiresAtUtc: artifact.expires_at ?? null,
      expired: artifact.expired === true,
    }))
    .sort((left, right) => left.id - right.id);
}

function collectLiveState(options, policy) {
  const endpoint = `repos/${options.repository}`;
  const repository = runJson(
    options.ghCommand,
    ["api", endpoint],
    options.repositoryRoot,
  );
  const retention = runJson(
    options.ghCommand,
    ["api", `${endpoint}/actions/permissions/artifact-and-log-retention`],
    options.repositoryRoot,
  );
  const releasePages = runJson(
    options.ghCommand,
    ["api", "--paginate", "--slurp", `${endpoint}/releases?per_page=100`],
    options.repositoryRoot,
  );
  const artifactPages = runJson(
    options.ghCommand,
    [
      "api",
      "--paginate",
      "--slurp",
      `${endpoint}/actions/artifacts?per_page=100`,
    ],
    options.repositoryRoot,
  );
  const workflowFile = path.basename(policy.workflow.path);
  const productionRunPages = runJson(
    options.ghCommand,
    [
      "api",
      "--paginate",
      "--slurp",
      `${endpoint}/actions/workflows/${workflowFile}/runs?per_page=100`,
    ],
    options.repositoryRoot,
  );
  const build8 = policy.expectedArtifactsForContainment.find(
    (artifact) => artifact.buildNumber === 8,
  );
  const build8Run = runJson(
    options.ghCommand,
    ["api", `${endpoint}/actions/runs/${build8.workflowRunId}`],
    options.repositoryRoot,
  );
  const latestExpectedArtifact = policy.expectedArtifactsForContainment.reduce(
    (latest, entry) =>
      latest == null || entry.buildNumber > latest.buildNumber ? entry : latest,
    null,
  );
  const latestContainmentRun = runJson(
    options.ghCommand,
    [
      "api",
      `${endpoint}/actions/runs/${latestExpectedArtifact.workflowRunId}`,
    ],
    options.repositoryRoot,
  );
  const releases = releasePages.flatMap((page) => page);
  const artifacts = artifactPages.flatMap((page) => page.artifacts ?? []);
  const productionWorkflowRuns = productionRunPages.flatMap(
    (page) => page.workflow_runs ?? [],
  );
  const productionArtifacts = selectProductionArtifacts(
    artifacts,
    productionWorkflowRuns,
  ).map((artifact) => ({
    id: artifact.id,
    nameSha256: sha256(artifact.name),
    sizeBytes: artifact.sizeBytes,
    digest: artifact.digest,
    workflowRunId: artifact.workflowRunId,
    headSha: artifact.headSha,
    expiresAtUtc: artifact.expiresAtUtc,
  }));
  return {
    repository: {
      fullName: repository.full_name ?? null,
      visibility:
        typeof repository.visibility === "string"
          ? repository.visibility.toUpperCase()
          : null,
      defaultBranch: repository.default_branch ?? null,
      archived: repository.archived === true,
    },
    artifactAndLogRetention: {
      days: retention.days ?? null,
      maximumAllowedDays: retention.maximum_allowed_days ?? null,
    },
    githubReleases: {count: releases.length},
    productionWorkflowRuns: {count: productionWorkflowRuns.length},
    productionArtifacts: {
      count: productionArtifacts.length,
      totalBytes: productionArtifacts.reduce(
        (total, artifact) => total + artifact.sizeBytes,
        0,
      ),
      artifacts: productionArtifacts,
    },
    build8WorkflowRun: {
      id: build8Run.id ?? null,
      event: build8Run.event ?? null,
      status: build8Run.status ?? null,
      conclusion: build8Run.conclusion ?? null,
      headSha: build8Run.head_sha ?? null,
      path: build8Run.path ?? null,
    },
    latestContainmentWorkflowRun: {
      buildNumber: latestExpectedArtifact.buildNumber,
      id: latestContainmentRun.id ?? null,
      event: latestContainmentRun.event ?? null,
      status: latestContainmentRun.status ?? null,
      conclusion: latestContainmentRun.conclusion ?? null,
      headSha: latestContainmentRun.head_sha ?? null,
      path: latestContainmentRun.path ?? null,
    },
  };
}

function adjudicateReadback({
  policy,
  sourceBefore,
  sourceAfter,
  source,
  installation,
  live,
  observe,
}) {
  const checks = {
    policyIdentityExact:
      policy.schemaVersion === 1 &&
      policy.policyId ===
        "LR07-DISTRIBUTION-INSTALLATION-READBACK-POLICY-V1" &&
      policy.repository === EXPECTED_REPOSITORY &&
      policy.productionProjectId === EXPECTED_PROJECT_ID &&
      policy.executionAuthority?.artifactDeletionRequiresExplicitOwnerApproval ===
        true &&
      policy.executionAuthority?.deleteOnlyExactArtifactIds === true,
    sourceBranchMain: sourceBefore.branch === "main",
    sourceCommitMatchesOriginMain:
      sourceBefore.commit === sourceBefore.originMain,
    sourceBindingStable:
      JSON.stringify(sourceBefore) === JSON.stringify(sourceAfter),
    governedSourceClean:
      sourceBefore.governedWorktreeClean === true &&
      sourceBefore.materialChangeCount === 0,
    sourceEvidenceExact: source.files.every((entry) => entry.exact === true),
    workflowRetentionExact: source.workflowRetentionExact === true,
    distributionScopeExact: source.distributionScopeExact === true,
    platformScopeExact: source.platformScopeExact === true,
    releasePolicyExact: source.releasePolicyExact === true,
    buildLedgerArtifactsExact: source.buildLedgerArtifacts.every(
      (entry) => entry.exact === true,
    ),
    build8FinalizationExact: source.build8FinalizationExact === true,
    latestContainmentFinalizationExact:
      source.latestContainmentFinalizationExact === true,
    installationAdjudicationExact:
      source.installationAdjudicationExact === true,
    externalInstallationReceiptExact: installation.exact === true,
    repositoryExact:
      live.repository.fullName === policy.repository &&
      live.repository.visibility === policy.expectedRepositoryVisibility &&
      live.repository.defaultBranch === policy.expectedDefaultBranch &&
      live.repository.archived === false,
    githubReleaseInventoryEmpty:
      live.githubReleases.count ===
      policy.strictReadback.requiredGitHubReleaseCount,
    liveProductionArtifactInventoryEmpty:
      live.productionArtifacts.count ===
      policy.strictReadback.requiredLiveProductionArtifactCount,
    build8WorkflowRunExact:
      live.build8WorkflowRun.id ===
        policy.expectedArtifactsForContainment.find(
          (artifact) => artifact.buildNumber === 8,
        ).workflowRunId &&
      live.build8WorkflowRun.status === "completed" &&
      live.build8WorkflowRun.conclusion === "success" &&
      live.build8WorkflowRun.headSha ===
        policy.expectedArtifactsForContainment.find(
          (artifact) => artifact.buildNumber === 8,
        ).headSha,
    latestContainmentWorkflowRunExact:
      live.latestContainmentWorkflowRun.id ===
        policy.expectedArtifactsForContainment.at(-1).workflowRunId &&
      live.latestContainmentWorkflowRun.buildNumber ===
        policy.expectedArtifactsForContainment.at(-1).buildNumber &&
      live.latestContainmentWorkflowRun.status === "completed" &&
      live.latestContainmentWorkflowRun.conclusion === "success" &&
      live.latestContainmentWorkflowRun.headSha ===
        policy.expectedArtifactsForContainment.at(-1).headSha,
    readbackMutationBoundaryExact: Object.values(
      policy.readbackMutationBoundary,
    ).every((value) => value === false),
  };
  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value !== true)
    .map(([name]) => name);
  const holds = [];
  if (live.productionArtifacts.count > 0) {
    holds.push("publicProductionArtifactsRetained");
  }
  if (live.githubReleases.count > 0) holds.push("githubReleasesPresent");
  if (!installation.exact) holds.push("installationReceiptNotExact");
  const pass = failedChecks.length === 0;
  return {
    evidence: {
      schemaVersion: 1,
      evidenceType: "lr07-distribution-installation-live-readback",
      mode: observe ? "OBSERVE" : "STRICT",
      repository: policy.repository,
      projectId: policy.productionProjectId,
      applicationId: policy.applicationId,
      gateIds: ["LR-07"],
      source: {before: sourceBefore, after: sourceAfter, summary: source},
      commands: [
        {kind: "LOCAL_READ", command: "git status/rev-parse"},
        {
          kind: "LOCAL_READ",
          command: "read exact distribution and installation authorities",
        },
        {kind: "GH_READ", command: "repository metadata"},
        {kind: "GH_READ", command: "artifact and log retention settings"},
        {kind: "GH_READ", command: "complete GitHub Release inventory"},
        {kind: "GH_READ", command: "complete Actions artifact inventory"},
        {kind: "GH_READ", command: "complete production workflow run inventory"},
        {kind: "GH_READ", command: "exact Build 8 workflow run"},
        {
          kind: "GH_READ",
          command: "exact latest containment workflow run",
        },
      ],
      outputs: {installation, live},
      posture: {
        decision: pass
          ? "PASS_LR07_DISTRIBUTION_INSTALLATION_POSTURE"
          : "HOLD_LR07_DISTRIBUTION_INSTALLATION_POSTURE",
        holds,
      },
      checks,
      failedChecks,
      decision: observe
        ? "OBSERVE_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK"
        : pass
          ? "PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK"
          : "HOLD_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK",
      closureScope: {
        lr07Closed: false,
        collectorAuthorizesClosure: false,
        separateAdjudicationRequired: true,
      },
      mutationBoundary: policy.readbackMutationBoundary,
      privacyBoundary: {
        artifactBytesDownloaded: false,
        secretNamesOrValuesRetained: false,
        rawDeviceIdentifiersRetained: false,
        accountIdentityRetained: false,
        businessPayloadRetained: false,
        artifactNamesRepresentedBySha256Only: true,
      },
    },
    pass,
  };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("The append-only readback output must be outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail(`Output already exists: ${options.outputPath}`);
  }
  if (!fs.existsSync(options.installationReceiptPath)) {
    fail("The exact external installation receipt is absent.");
  }
  const policy = readJson(path.join(options.repositoryRoot, POLICY_PATH));
  const sourceBefore = collectSourceBinding(options.repositoryRoot);
  const source = summarizeSource(options.repositoryRoot, policy);
  const installation = summarizeInstallationReceipt(
    options.installationReceiptPath,
    policy,
  );
  const live = collectLiveState(options, policy);
  const sourceAfter = collectSourceBinding(options.repositoryRoot);
  const result = adjudicateReadback({
    policy,
    sourceBefore,
    sourceAfter,
    source,
    installation,
    live,
    observe: options.observe,
  });
  const receipt = sealReceipt({
    ...result.evidence,
    capturedAtUtc: new Date().toISOString(),
  });
  fs.mkdirSync(path.dirname(options.outputPath), {recursive: true});
  fs.writeFileSync(options.outputPath, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  process.stdout.write(
    `${JSON.stringify({
      decision: receipt.decision,
      postureDecision: receipt.posture.decision,
      outputPath: options.outputPath,
      receiptSha256: receipt.receiptSha256,
      failedChecks: receipt.failedChecks,
      postureHolds: receipt.posture.holds,
    })}\n`,
  );
  if (!options.observe && !result.pass) process.exitCode = 1;
}

module.exports = {
  EXPECTED_PROJECT_ID,
  EXPECTED_REPOSITORY,
  POLICY_PATH,
  adjudicateReadback,
  collectLiveState,
  parseArgs,
  selectProductionArtifacts,
  summarizeInstallationReceipt,
  summarizeMutableSourceAuthority,
  summarizeSource,
};

if (require.main === module) {
  try {
    main();
  } catch (error) {
    process.stderr.write(
      `LR07_DISTRIBUTION_INSTALLATION_READBACK_FAILED: ${error.message}\n`,
    );
    process.exitCode = 1;
  }
}
