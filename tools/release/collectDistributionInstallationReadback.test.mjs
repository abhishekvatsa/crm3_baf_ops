import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  adjudicateReadback,
  parseArgs,
  selectProductionArtifacts,
  summarizeMutableSourceAuthority,
  summarizeSource,
} = require("./collectDistributionInstallationReadback.js");

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function fixture() {
  const build8 = {
    buildNumber: 8,
    workflowRunId: 30839125687,
    headSha: "731a02980d38e4e3a8f61ff2bca74a1e85771478",
    governedPackageSha256: "a".repeat(64).toUpperCase(),
  };
  const policy = {
    schemaVersion: 1,
    policyId: "LR07-DISTRIBUTION-INSTALLATION-READBACK-POLICY-V1",
    repository: "abhishekvatsa/crm3_baf_ops",
    productionProjectId: "crm3-baf-ops-b8638",
    applicationId: "in.co.sail.bsl.crm3.bafops",
    expectedRepositoryVisibility: "PUBLIC",
    expectedDefaultBranch: "main",
    expectedArtifactsForContainment: [build8],
    strictReadback: {
      requiredGitHubReleaseCount: 0,
      requiredLiveProductionArtifactCount: 0,
    },
    executionAuthority: {
      artifactDeletionRequiresExplicitOwnerApproval: true,
      deleteOnlyExactArtifactIds: true,
    },
    readbackMutationBoundary: {
      githubArtifactDeleted: false,
      repositoryVisibilityChanged: false,
    },
  };
  const binding = {
    branch: "main",
    commit: "a".repeat(40),
    tree: "b".repeat(40),
    originMain: "a".repeat(40),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
  };
  return {
    policy,
    sourceBefore: binding,
    sourceAfter: {...binding},
    source: {
      files: [{path: "authority.json", exact: true}],
      workflowRetentionExact: true,
      distributionScopeExact: true,
      platformScopeExact: true,
      releasePolicyExact: true,
      buildLedgerArtifacts: [{buildNumber: 8, exact: true}],
      build8FinalizationExact: true,
      latestContainmentFinalizationExact: true,
      installationAdjudicationExact: true,
    },
    installation: {exact: true},
    live: {
      repository: {
        fullName: "abhishekvatsa/crm3_baf_ops",
        visibility: "PUBLIC",
        defaultBranch: "main",
        archived: false,
      },
      githubReleases: {count: 0},
      productionArtifacts: {count: 0, totalBytes: 0, artifacts: []},
      build8WorkflowRun: {
        id: 30839125687,
        status: "completed",
        conclusion: "success",
        headSha: build8.headSha,
      },
      latestContainmentWorkflowRun: {
        buildNumber: 8,
        id: 30839125687,
        status: "completed",
        conclusion: "success",
        headSha: build8.headSha,
      },
    },
    observe: false,
  };
}

test("strict readback passes only with empty public distribution surfaces", () => {
  const result = adjudicateReadback(fixture());
  assert.equal(result.pass, true);
  assert.equal(
    result.evidence.decision,
    "PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK",
  );
  assert.deepEqual(result.evidence.failedChecks, []);
  assert.deepEqual(result.evidence.posture.holds, []);
});

test("a retained production artifact fails the strict readback", () => {
  const input = fixture();
  input.live.productionArtifacts = {
    count: 1,
    totalBytes: 100,
    artifacts: [{id: 1}],
  };
  const result = adjudicateReadback(input);
  assert.equal(result.pass, false);
  assert.ok(
    result.evidence.failedChecks.includes(
      "liveProductionArtifactInventoryEmpty",
    ),
  );
  assert.deepEqual(result.evidence.posture.holds, [
    "publicProductionArtifactsRetained",
  ]);
});

test("production artifacts are discovered by workflow run instead of filename", () => {
  const artifacts = [
    {
      id: 1,
      name: "renamed-production-package",
      size_in_bytes: 10,
      digest: `sha256:${"a".repeat(64)}`,
      expired: false,
      workflow_run: {id: 50, head_sha: "b".repeat(40)},
    },
    {
      id: 2,
      name: "crm3-baf-ops-lookalike",
      size_in_bytes: 20,
      digest: `sha256:${"c".repeat(64)}`,
      expired: false,
      workflow_run: {id: 60, head_sha: "d".repeat(40)},
    },
  ];
  const selected = selectProductionArtifacts(artifacts, [{id: 50}]);
  assert.deepEqual(selected.map((artifact) => artifact.id), [1]);
  assert.equal(selected[0].name, "renamed-production-package");
});

test("observe mode records adverse posture without claiming closure", () => {
  const input = fixture();
  input.observe = true;
  input.installation = {exact: false};
  const result = adjudicateReadback(input);
  assert.equal(result.pass, false);
  assert.equal(
    result.evidence.decision,
    "OBSERVE_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK",
  );
  assert.equal(result.evidence.closureScope.lr07Closed, false);
  assert.equal(result.evidence.closureScope.collectorAuthorizesClosure, false);
});

test("preserved latest authority admits only a source-reserved successor", () => {
  const expected = {
    buildNumber: 9,
    id: 90,
    name: "build-9",
    sizeBytes: 900,
    digest: `sha256:${"9".repeat(64)}`,
    workflowRunId: 909,
    headSha: "9".repeat(40),
    ledgerDisposition:
      "successful-build-finalized-runtime-failed-non-distributable",
    dualCustodyCompleted: true,
  };
  const receiptPath =
    "release/evidence/build-9-finalization-closure.json";
  const receiptSha256 = "c".repeat(64).toUpperCase();
  const packageSha256 = "a".repeat(64).toUpperCase();
  expected.governedPackageSha256 = packageSha256;
  const policy = {
    repository: "abhishekvatsa/crm3_baf_ops",
    productionProjectId: "crm3-baf-ops-b8638",
    applicationId: "in.co.sail.bsl.crm3.bafops",
    expectedArtifactsForContainment: [expected],
    sourceEvidence: [
      {path: receiptPath, sha256: receiptSha256},
    ],
  };
  const releasePolicy = {
    firebaseProjectId: policy.productionProjectId,
    permanentApplicationId: policy.applicationId,
    github: {
      repository: policy.repository,
      environmentReviewControl: {repositoryVisibility: "public"},
    },
    release: {buildNumber: 10},
    finalization: {
      status: "pending-source-authorized",
      priorCompletedBuild: {
        buildNumber: 9,
        status: "completed-non-distributable",
        completionReceiptFile: receiptPath,
        completionReceiptSha256: receiptSha256,
        sourceCommit: expected.headSha,
        githubRunId: expected.workflowRunId,
        governedPackageSha256: packageSha256,
        dualCustodyCompleted: true,
      },
    },
    distribution: {
      approved: false,
      unrestrictedPlantReleaseApproved: false,
    },
  };
  const build9Ledger = {
    buildNumber: 9,
    githubArtifactId: expected.id,
    githubArtifactName: expected.name,
    githubArtifactSizeBytes: expected.sizeBytes,
    githubArtifactDigest: expected.digest,
    githubRunId: expected.workflowRunId,
    remoteReservationCommit: expected.headSha,
    disposition: expected.ledgerDisposition,
    dualCustodyCompleted: true,
    distributionPerformed: false,
  };
  const build10Ledger = {
    buildNumber: 10,
    status: "source-reserved-awaiting-remote-consumption",
  };

  const exact = summarizeMutableSourceAuthority({
    policy,
    releasePolicy,
    buildLedger: {entries: [build9Ledger, build10Ledger]},
  });
  assert.deepEqual(exact, {
    releasePolicyExact: true,
    buildLedgerExact: true,
    latestContainmentAttemptExact: true,
    controlledPilotPromotionExact: false,
  });

  const malformedPrior = structuredClone(releasePolicy);
  delete malformedPrior.finalization.priorCompletedBuild.completionReceiptSha256;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: malformedPrior,
      buildLedger: {entries: [build9Ledger, build10Ledger]},
    }).releasePolicyExact,
    false,
  );

  const artifactBearingSuccessor = {
    ...build10Ledger,
    status: "remote-consumed-artifact-built",
    githubArtifactId: 90,
  };
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy,
      buildLedger: {entries: [build9Ledger, artifactBearingSuccessor]},
    }).buildLedgerExact,
    false,
  );
});

test("completed successor still requires every retained failed-attempt receipt", () => {
  const completed = {
    buildNumber: 11,
    id: 111,
    name: "build-11",
    sizeBytes: 1100,
    digest: `sha256:${"b".repeat(64)}`,
    workflowRunId: 1111,
    headSha: "b".repeat(40),
    ledgerDisposition: "successful-build-finalized-non-distributable",
    dualCustodyCompleted: true,
    governedPackageSha256: "d".repeat(64).toUpperCase(),
  };
  const failed = {
    buildNumber: 10,
    id: 101,
    name: "build-10",
    sizeBytes: 1000,
    digest: `sha256:${"a".repeat(64)}`,
    workflowRunId: 1010,
    headSha: "a".repeat(40),
    ledgerDisposition:
      "successful-build-finalization-authority-mismatch-non-distributable",
    dualCustodyCompleted: false,
    governedPackageSha256: "c".repeat(64).toUpperCase(),
    authorityReceiptPath: "release/evidence/build-10-finalization-block.json",
  };
  const completionPath =
    "release/evidence/build-11-finalization-closure.json";
  const failurePath = failed.authorityReceiptPath;
  const completionSha = "e".repeat(64).toUpperCase();
  const failureSha = "f".repeat(64).toUpperCase();
  const deviceAcceptancePath =
    "release/evidence/build-11-device-acceptance.json";
  const deviceAcceptanceSha = "6".repeat(64).toUpperCase();
  const runtimeDisposition =
    "passed-exact-build11-physical-in-place-authenticated-read-only-surfaces";
  const policy = {
    repository: "abhishekvatsa/crm3_baf_ops",
    productionProjectId: "crm3-baf-ops-b8638",
    applicationId: "in.co.sail.bsl.crm3.bafops",
    expectedArtifactsForContainment: [failed, completed],
    sourceEvidence: [
      {path: failurePath, sha256: failureSha},
      {path: completionPath, sha256: completionSha},
    ],
  };
  const historicalFailure = {
    buildNumber: failed.buildNumber,
    status: "blocked-non-distributable",
    evidenceFile: failurePath,
    evidenceSha256: failureSha,
    sourceCommit: failed.headSha,
    githubRunId: failed.workflowRunId,
    githubArtifactId: failed.id,
    githubArtifactDigest: failed.digest,
    governedPackageSha256: failed.governedPackageSha256,
    independentVerificationCompleted: true,
    dualCustodyCompleted: false,
    distributionPerformed: false,
  };
  const releasePolicy = {
    firebaseProjectId: policy.productionProjectId,
    permanentApplicationId: policy.applicationId,
    github: {
      repository: policy.repository,
      environmentReviewControl: {repositoryVisibility: "public"},
    },
    release: {buildNumber: completed.buildNumber},
    finalization: {
      status: "completed-non-distributable",
      completionReceiptFile: completionPath,
      completionReceiptSha256: completionSha,
      sourceCommit: completed.headSha,
      githubRunId: completed.workflowRunId,
      governedPackageSha256: completed.governedPackageSha256,
      dualCustodyCompleted: true,
      physicalInstallationConditionPassed: true,
      physicalInstallationReceiptFile: deviceAcceptancePath,
      physicalInstallationReceiptSha256: deviceAcceptanceSha,
      deviceAcceptanceReceiptFile: deviceAcceptancePath,
      deviceAcceptanceReceiptSha256: deviceAcceptanceSha,
      runtimeValidationPassed: true,
      runtimeDisposition,
      fullBusinessFlowValidationCompleted: false,
      historicalFailedAttempts: [historicalFailure],
    },
    distribution: {
      approved: false,
      unrestrictedPlantReleaseApproved: false,
    },
  };
  const ledgers = [failed, completed].map((artifact) => ({
    buildNumber: artifact.buildNumber,
    githubArtifactId: artifact.id,
    githubArtifactName: artifact.name,
    githubArtifactSizeBytes: artifact.sizeBytes,
    githubArtifactDigest: artifact.digest,
    githubRunId: artifact.workflowRunId,
    remoteReservationCommit: artifact.headSha,
    disposition: artifact.ledgerDisposition,
    dualCustodyCompleted: artifact.dualCustodyCompleted,
    distributionPerformed: false,
  }));
  Object.assign(
    ledgers.find((entry) => entry.buildNumber === completed.buildNumber),
    {
      physicalInstallationConditionPassed: true,
      physicalInstallationReceiptFile: deviceAcceptancePath,
      physicalInstallationReceiptSha256: deviceAcceptanceSha,
      runtimeValidationPassed: true,
      runtimeDisposition,
      fullBusinessFlowValidationCompleted: false,
      controlledPilotApproved: false,
    },
  );

  assert.deepEqual(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy,
      buildLedger: {entries: ledgers},
    }),
    {
      releasePolicyExact: true,
      buildLedgerExact: true,
      latestContainmentAttemptExact: true,
      controlledPilotPromotionExact: false,
    },
  );

  const promotionPath =
    "release/evidence/build-11-staged-controlled-pilot-authorization.json";
  const promotionSha = "1".repeat(64).toUpperCase();
  const apkSha = "a".repeat(64).toUpperCase();
  policy.sourceEvidence.push({path: promotionPath, sha256: promotionSha});
  const promotedPolicy = structuredClone(releasePolicy);
  promotedPolicy.finalization.controlledPilotApproved = true;
  ledgers.find(
    (entry) => entry.buildNumber === completed.buildNumber,
  ).controlledPilotApproved = true;
  Object.assign(
    ledgers.find((entry) => entry.buildNumber === completed.buildNumber),
    {
      pilotPromotionReceiptFile: promotionPath,
      pilotPromotionReceiptSha256: promotionSha,
    },
  );
  promotedPolicy.postBuildPromotion = {
    status: "completed-staged-controlled-pilot-only",
    promotionReceiptFile: promotionPath,
    promotionReceiptSha256: promotionSha,
    buildNumber: completed.buildNumber,
    sourceCommit: completed.headSha,
    governedPackageSha256: completed.governedPackageSha256,
    controlledPilotApproved: true,
    maximumApprovedUsers: 25,
    canaryUserCeiling: 2,
    canaryPhysicalDeviceCeiling: 2,
    pilotHandoutPerformed: false,
    publicArtifactApproved: false,
    githubReleaseApproved: false,
    firebaseAppDistributionApproved: false,
    playConsoleApproved: false,
    playStoreApproved: false,
    webDistributionApproved: false,
    unrestrictedPlantReleaseApproved: false,
  };
  promotedPolicy.distribution = {
    authority: "exact-build11-staged-controlled-pilot",
    approved: true,
    approvedBuildNumber: completed.buildNumber,
    approvedPackageSha256: completed.governedPackageSha256,
    approvedApkSha256: apkSha,
    promotionReceiptFile: promotionPath,
    promotionReceiptSha256: promotionSha,
    pilotHandoutPerformed: false,
    unrestrictedPlantReleaseApproved: false,
    postBuildPromotionRequiredForAnyDistribution: true,
  };
  const promotionReceipt = {
    schemaVersion: 1,
    evidenceType: "production-build-staged-controlled-pilot-authorization",
    decision: "PASS_BUILD11_STAGED_CONTROLLED_PILOT_AUTHORIZED",
    admittedEvidence: {
      governedBuild: {
        buildNumber: completed.buildNumber,
        sourceCommit: completed.headSha,
        governedPackageSha256: completed.governedPackageSha256,
        apkSha256: apkSha,
        finalizationReceipt: completionPath,
        finalizationReceiptSha256: completionSha,
      },
      deviceAcceptance: {
        receipt: deviceAcceptancePath,
        sha256: deviceAcceptanceSha,
        decision: runtimeDisposition,
        appDataPreserved: true,
        automaticSyncPassed: true,
        unsyncedRows: 0,
        unresolvedRejections: 0,
        businessDataMutated: false,
      },
    },
    promotion: {
      authorizedBuildNumber: completed.buildNumber,
      authorizedPackageSha256: completed.governedPackageSha256,
      authorizedApkSha256: apkSha,
      pilotHandoutAuthorized: true,
      pilotHandoutPerformedByThisRecord: false,
      publicArtifactAuthorized: false,
      githubReleaseAuthorized: false,
      firebaseAppDistributionAuthorized: false,
      playConsoleAuthorized: false,
      playStoreAuthorized: false,
      webDistributionAuthorized: false,
      unrestrictedDistributionAuthorized: false,
      maximumApprovedUsers: 25,
      canaryUserCeiling: 2,
      canaryPhysicalDeviceCeiling: 2,
    },
  };
  const promotionFinalizationReceipt = {
    release: {buildNumber: completed.buildNumber},
    sourceAuthority: {commit: completed.headSha},
    governedPackage: {
      sha256: completed.governedPackageSha256,
      apkSha256: apkSha,
    },
  };
  const promotionFinalizationAuthority = {
    promotionFinalizationReceipt,
    measuredPromotionFinalizationReceiptSha256: completionSha,
  };
  const promotionDeviceAcceptanceReceipt = {
    evidenceType: "production-build-device-acceptance",
    status: runtimeDisposition,
    release: {
      buildNumber: completed.buildNumber,
      sourceCommit: completed.headSha,
      finalizationReceiptFile: completionPath,
      finalizationReceiptSha256: completionSha,
      governedPackageSha256: completed.governedPackageSha256,
      apkSha256: apkSha,
    },
    physicalDevice: {applicationDataPreserved: true},
    businessMutationBoundary: {
      productionBusinessDataCreatedUpdatedOrDeleted: false,
      ticketSubmitted: false,
    },
    synchronization: {
      lastSyncResult: "success",
      unsyncedRows: 0,
      unresolvedRejections: 0,
    },
    adjudication: {
      runtimeValidationPassed: true,
      fullBusinessFlowValidationCompleted: false,
    },
  };
  const promotionRuntimeAuthority = {
    promotionDeviceAcceptanceReceipt,
    measuredPromotionDeviceAcceptanceReceiptSha256: deviceAcceptanceSha,
  };
  Object.assign(promotionFinalizationAuthority, promotionRuntimeAuthority);
  assert.deepEqual(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: promotedPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }),
    {
      releasePolicyExact: true,
      buildLedgerExact: true,
      latestContainmentAttemptExact: true,
      controlledPilotPromotionExact: true,
    },
  );

  const mismatchedPolicyApk = structuredClone(promotedPolicy);
  mismatchedPolicyApk.distribution.approvedApkSha256 = "b"
    .repeat(64)
    .toUpperCase();
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: mismatchedPolicyApk,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  const fallbackPolicy = structuredClone(policy);
  fallbackPolicy.sourceEvidence = fallbackPolicy.sourceEvidence.filter(
    (entry) => entry.path !== promotionPath,
  );
  assert.equal(
    summarizeMutableSourceAuthority({
      policy: fallbackPolicy,
      releasePolicy: promotedPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      measuredPromotionReceiptSha256: promotionSha,
      ...promotionFinalizationAuthority,
    }).controlledPilotPromotionExact,
    true,
  );
  assert.equal(
    summarizeMutableSourceAuthority({
      policy: fallbackPolicy,
      releasePolicy: promotedPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      measuredPromotionReceiptSha256: "9".repeat(64).toUpperCase(),
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  const successor = {
    buildNumber: 12,
    id: 121,
    name: "build-12",
    sizeBytes: 1200,
    digest: `sha256:${"2".repeat(64)}`,
    workflowRunId: 1212,
    headSha: "2".repeat(40),
    ledgerDisposition: "successful-build-finalized-non-distributable",
    dualCustodyCompleted: true,
    governedPackageSha256: "2".repeat(64).toUpperCase(),
  };
  const successorReceiptPath =
    "release/evidence/build-12-finalization-closure.json";
  const successorReceiptSha = "3".repeat(64).toUpperCase();
  const preservedPolicy = structuredClone(promotedPolicy);
  preservedPolicy.release.buildNumber = successor.buildNumber;
  preservedPolicy.finalization = {
    ...preservedPolicy.finalization,
    status: "completed-non-distributable",
    completionReceiptFile: successorReceiptPath,
    completionReceiptSha256: successorReceiptSha,
    sourceCommit: successor.headSha,
    githubRunId: successor.workflowRunId,
    governedPackageSha256: successor.governedPackageSha256,
    dualCustodyCompleted: true,
    controlledPilotApproved: false,
  };
  preservedPolicy.distribution.preservedHistoricalAuthority = true;
  preservedPolicy.distribution.appliesToCurrentCandidate = false;
  const successorPolicy = structuredClone(policy);
  successorPolicy.expectedArtifactsForContainment.push(successor);
  successorPolicy.sourceEvidence.push({
    path: successorReceiptPath,
    sha256: successorReceiptSha,
  });
  const successorLedger = {
    buildNumber: successor.buildNumber,
    githubArtifactId: successor.id,
    githubArtifactName: successor.name,
    githubArtifactSizeBytes: successor.sizeBytes,
    githubArtifactDigest: successor.digest,
    githubRunId: successor.workflowRunId,
    remoteReservationCommit: successor.headSha,
    disposition: successor.ledgerDisposition,
    dualCustodyCompleted: true,
    controlledPilotApproved: false,
    distributionPerformed: false,
  };
  assert.deepEqual(
    summarizeMutableSourceAuthority({
      policy: successorPolicy,
      releasePolicy: preservedPolicy,
      buildLedger: {entries: [...ledgers, successorLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }),
    {
      releasePolicyExact: true,
      buildLedgerExact: true,
      latestContainmentAttemptExact: true,
      controlledPilotPromotionExact: true,
    },
  );

  const pendingPolicy = structuredClone(promotedPolicy);
  pendingPolicy.release.buildNumber = successor.buildNumber;
  pendingPolicy.finalization = {
    status: "pending-source-authorized",
    controlledPilotApproved: false,
    priorCompletedBuild: {
      ...promotedPolicy.finalization,
      buildNumber: completed.buildNumber,
    },
    historicalFailedAttempts: [historicalFailure],
  };
  pendingPolicy.distribution.preservedHistoricalAuthority = true;
  pendingPolicy.distribution.appliesToCurrentCandidate = false;
  const pendingLedger = {
    buildNumber: successor.buildNumber,
    status: "source-reserved-awaiting-remote-consumption",
    distributionPerformed: false,
  };
  assert.deepEqual(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }),
    {
      releasePolicyExact: true,
      buildLedgerExact: true,
      latestContainmentAttemptExact: true,
      controlledPilotPromotionExact: true,
    },
  );

  const droppedPendingPredecessorPilot = structuredClone(pendingPolicy);
  droppedPendingPredecessorPilot.finalization.priorCompletedBuild.controlledPilotApproved =
    false;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: droppedPendingPredecessorPilot,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  for (const mutateRuntimeAuthority of [
    (prior) => {
      prior.runtimeValidationPassed = false;
    },
    (prior) => {
      delete prior.runtimeDisposition;
    },
    (prior) => {
      delete prior.deviceAcceptanceReceiptFile;
    },
    (prior) => {
      prior.deviceAcceptanceReceiptSha256 = "5".repeat(64).toUpperCase();
    },
  ]) {
    const weakenedPendingAcceptance = structuredClone(pendingPolicy);
    mutateRuntimeAuthority(
      weakenedPendingAcceptance.finalization.priorCompletedBuild,
    );
    const weakenedSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: weakenedPendingAcceptance,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    });
    assert.equal(weakenedSummary.releasePolicyExact, false);
    assert.equal(weakenedSummary.controlledPilotPromotionExact, false);
  }

  const coordinatedRuntimeWeakening = structuredClone(pendingPolicy);
  coordinatedRuntimeWeakening.finalization.priorCompletedBuild.runtimeValidationPassed =
    false;
  const coordinatedRuntimeLedger = structuredClone(ledgers);
  coordinatedRuntimeLedger.find(
    (entry) => entry.buildNumber === completed.buildNumber,
  ).runtimeValidationPassed = false;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: coordinatedRuntimeWeakening,
      buildLedger: {entries: [...coordinatedRuntimeLedger, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  const weakenedMeasuredAcceptance = structuredClone(
    promotionDeviceAcceptanceReceipt,
  );
  weakenedMeasuredAcceptance.adjudication.runtimeValidationPassed = false;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
      promotionDeviceAcceptanceReceipt: weakenedMeasuredAcceptance,
    }).releasePolicyExact,
    false,
  );

  const mutatedBusinessAcceptance = structuredClone(
    promotionDeviceAcceptanceReceipt,
  );
  mutatedBusinessAcceptance.businessMutationBoundary.productionBusinessDataCreatedUpdatedOrDeleted =
    true;
  const mutatedBusinessSummary = summarizeMutableSourceAuthority({
    policy,
    releasePolicy: pendingPolicy,
    buildLedger: {entries: [...ledgers, pendingLedger]},
    promotionReceipt,
    ...promotionFinalizationAuthority,
    promotionDeviceAcceptanceReceipt: mutatedBusinessAcceptance,
  });
  assert.equal(mutatedBusinessSummary.releasePolicyExact, false);
  assert.equal(mutatedBusinessSummary.controlledPilotPromotionExact, false);

  for (const mutateLedgerPromotionReceipt of [
    (ledger) => {
      delete ledger.pilotPromotionReceiptFile;
    },
    (ledger) => {
      ledger.pilotPromotionReceiptSha256 = "7".repeat(64).toUpperCase();
    },
  ]) {
    const unrelatedPromotionLedger = structuredClone(ledgers);
    mutateLedgerPromotionReceipt(
      unrelatedPromotionLedger.find(
        (entry) => entry.buildNumber === completed.buildNumber,
      ),
    );
    const unrelatedPromotionSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...unrelatedPromotionLedger, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    });
    assert.equal(unrelatedPromotionSummary.buildLedgerExact, false);
    assert.equal(unrelatedPromotionSummary.releasePolicyExact, false);
    assert.equal(
      unrelatedPromotionSummary.controlledPilotPromotionExact,
      false,
    );
  }

  const broadenedPromotion = structuredClone(promotedPolicy);
  broadenedPromotion.postBuildPromotion.publicArtifactApproved = true;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: broadenedPromotion,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  for (const mutateReceipt of [
    (receipt) => {
      receipt.admittedEvidence.governedBuild.buildNumber += 1;
    },
    (receipt) => {
      receipt.admittedEvidence.governedBuild.sourceCommit = "f".repeat(40);
    },
    (receipt) => {
      receipt.admittedEvidence.governedBuild.governedPackageSha256 =
        "f".repeat(64).toUpperCase();
    },
    (receipt) => {
      receipt.admittedEvidence.governedBuild.apkSha256 = "f"
        .repeat(64)
        .toUpperCase();
    },
    (receipt) => {
      receipt.promotion.authorizedApkSha256 = "f"
        .repeat(64)
        .toUpperCase();
    },
  ]) {
    const mismatchedReceipt = structuredClone(promotionReceipt);
    mutateReceipt(mismatchedReceipt);
    assert.equal(
      summarizeMutableSourceAuthority({
        policy,
        releasePolicy: promotedPolicy,
        buildLedger: {entries: ledgers},
        promotionReceipt: mismatchedReceipt,
        ...promotionFinalizationAuthority,
      }).releasePolicyExact,
      false,
    );
  }

  const coordinatedApkSha = "7".repeat(64).toUpperCase();
  const coordinatedApkPolicy = structuredClone(promotedPolicy);
  coordinatedApkPolicy.distribution.approvedApkSha256 = coordinatedApkSha;
  const coordinatedApkReceipt = structuredClone(promotionReceipt);
  coordinatedApkReceipt.admittedEvidence.governedBuild.apkSha256 =
    coordinatedApkSha;
  coordinatedApkReceipt.promotion.authorizedApkSha256 = coordinatedApkSha;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: coordinatedApkPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt: coordinatedApkReceipt,
      ...promotionFinalizationAuthority,
    }).releasePolicyExact,
    false,
  );

  const mismatchedFinalizationReceipt = structuredClone(
    promotionFinalizationReceipt,
  );
  mismatchedFinalizationReceipt.governedPackage.apkSha256 = coordinatedApkSha;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: promotedPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt,
      promotionFinalizationReceipt: mismatchedFinalizationReceipt,
      measuredPromotionFinalizationReceiptSha256: completionSha,
    }).releasePolicyExact,
    false,
  );

  const redirectedFinalizationReceipt = structuredClone(promotionReceipt);
  redirectedFinalizationReceipt.admittedEvidence.governedBuild.finalizationReceipt =
    "release/evidence/unmeasured-finalization.json";
  redirectedFinalizationReceipt.admittedEvidence.governedBuild.finalizationReceiptSha256 =
    "8".repeat(64).toUpperCase();
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: promotedPolicy,
      buildLedger: {entries: ledgers},
      promotionReceipt: redirectedFinalizationReceipt,
      promotionFinalizationReceipt,
      measuredPromotionFinalizationReceiptSha256: "8"
        .repeat(64)
        .toUpperCase(),
    }).releasePolicyExact,
    false,
  );

  const missingFailure = structuredClone(releasePolicy);
  missingFailure.finalization.historicalFailedAttempts = [];
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: missingFailure,
      buildLedger: {entries: ledgers},
    }).releasePolicyExact,
    false,
  );
});

test("source summary semantically revalidates mutable authority after byte drift", () => {
  const policy = structuredClone(
    require("../../release/lr07-distribution-installation-readback-policy.json"),
  );
  const mutablePaths = new Set([
    "release/production-release-policy.json",
    "release/build-number-ledger.json",
  ]);
  for (const entry of policy.sourceEvidence) {
    if (!mutablePaths.has(entry.path)) continue;
    entry.bytes = 1;
    entry.sha256 = "0".repeat(64);
  }

  const source = summarizeSource(repositoryRoot, policy);
  const mutableEvidence = source.files.filter((entry) =>
    mutablePaths.has(entry.path),
  );

  assert.equal(source.releasePolicyExact, true);
  assert.equal(source.buildLedgerExact, true);
  assert.equal(mutableEvidence.length, 2);
  assert.ok(mutableEvidence.every((entry) => entry.byteExact === false));
  assert.ok(
    mutableEvidence.every(
      (entry) =>
        entry.authorityMode === "SEMANTIC_PRESERVED_BUILD" &&
        entry.exact === true,
    ),
  );
});

test("argument parser rejects the wrong repository and missing receipt", () => {
  assert.throws(
    () =>
      parseArgs([
        "--repository-root",
        ".",
        "--repository",
        "somewhere/else",
        "--project-id",
        "crm3-baf-ops-b8638",
        "--installation-receipt",
        "receipt.json",
        "--output",
        "out.json",
      ]),
    /Only the exact repository/,
  );
  assert.throws(
    () =>
      parseArgs([
        "--repository-root",
        ".",
        "--repository",
        "abhishekvatsa/crm3_baf_ops",
        "--project-id",
        "crm3-baf-ops-b8638",
        "--output",
        "out.json",
      ]),
    /installationReceiptPath/,
  );
});
