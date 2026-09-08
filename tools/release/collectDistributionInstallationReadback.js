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
const HISTORICAL_BUILD11_PROMOTION_PATH =
  "release/evidence/stage2d-f6-build11-controlled-pilot-authorization.json";
const HISTORICAL_BUILD11_PROMOTION_SHA256 =
  "878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400";

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

function summarizeMutableSourceAuthority({
  policy,
  releasePolicy,
  buildLedger,
  promotionReceipt = null,
  measuredPromotionReceiptSha256 = null,
  promotionFinalizationReceipt = null,
  measuredPromotionFinalizationReceiptSha256 = null,
  promotionDeviceAcceptanceReceipt = null,
  measuredPromotionDeviceAcceptanceReceiptSha256 = null,
  promotionOwnerApproval = null,
  measuredPromotionOwnerApprovalSha256 = null,
  promotionBackendReceipt = null,
  measuredPromotionBackendReceiptSha256 = null,
  promotionFirestoreReceipt = null,
  measuredPromotionFirestoreReceiptSha256 = null,
}) {
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
  const promotionReceiptPath =
    releasePolicy.postBuildPromotion?.promotionReceiptFile;
  const promotionReceiptAuthority =
    policy.sourceEvidence.find((entry) => entry.path === promotionReceiptPath) ??
    (typeof promotionReceiptPath === "string" &&
    typeof releasePolicy.postBuildPromotion?.promotionReceiptSha256 === "string" &&
    typeof measuredPromotionReceiptSha256 === "string" &&
    measuredPromotionReceiptSha256 ===
      releasePolicy.postBuildPromotion.promotionReceiptSha256
      ? {
          path: promotionReceiptPath,
          sha256: measuredPromotionReceiptSha256,
        }
      : null);
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
  const latestCompletedLedger = buildLedger.entries?.find(
    (entry) => entry.buildNumber === latestCompletedArtifact?.buildNumber,
  );
  const modernStagedPromotion =
    promotionReceipt?.evidenceType ===
    "production-build-staged-controlled-pilot-authorization";
  const preservedFinalizationIsPromoted =
    latestCompletedArtifact?.buildNumber ===
    releasePolicy.distribution?.approvedBuildNumber;

  const preservedPilotStateExact =
    releasePolicy.distribution?.approved !== true ||
    (preservedFinalization?.controlledPilotApproved ===
      (latestCompletedArtifact?.buildNumber ===
        releasePolicy.distribution?.approvedBuildNumber) &&
      latestCompletedLedger?.controlledPilotApproved ===
        preservedFinalization?.controlledPilotApproved);
  const preservedRuntimeMirrorExact =
    !modernStagedPromotion ||
    !preservedFinalizationIsPromoted ||
    (latestCompletedLedger != null &&
      preservedFinalization?.physicalInstallationConditionPassed === true &&
      preservedFinalization?.physicalInstallationConditionPassed ===
        latestCompletedLedger.physicalInstallationConditionPassed &&
      preservedFinalization?.physicalInstallationReceiptFile ===
        latestCompletedLedger.physicalInstallationReceiptFile &&
      preservedFinalization?.physicalInstallationReceiptSha256 ===
        latestCompletedLedger.physicalInstallationReceiptSha256 &&
      preservedFinalization?.deviceAcceptanceReceiptFile ===
        preservedFinalization?.physicalInstallationReceiptFile &&
      preservedFinalization?.deviceAcceptanceReceiptSha256 ===
        preservedFinalization?.physicalInstallationReceiptSha256 &&
      preservedFinalization?.runtimeValidationPassed === true &&
      preservedFinalization?.runtimeValidationPassed ===
        latestCompletedLedger.runtimeValidationPassed &&
      typeof preservedFinalization?.runtimeDisposition === "string" &&
      preservedFinalization.runtimeDisposition.length > 0 &&
      preservedFinalization.runtimeDisposition ===
        latestCompletedLedger.runtimeDisposition &&
      preservedFinalization?.fullBusinessFlowValidationCompleted === false &&
      preservedFinalization?.fullBusinessFlowValidationCompleted ===
        latestCompletedLedger.fullBusinessFlowValidationCompleted);
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
    preservedFinalization?.dualCustodyCompleted === true &&
    preservedPilotStateExact &&
    preservedRuntimeMirrorExact;
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
  const nonDistributionExact =
    releasePolicy.distribution?.approved === false &&
    releasePolicy.distribution?.unrestrictedPlantReleaseApproved === false;
  const postBuildPromotion = releasePolicy.postBuildPromotion ?? {};
  const promotedArtifact = expectedArtifacts.find(
    (artifact) =>
      artifact.buildNumber === releasePolicy.distribution?.approvedBuildNumber,
  );
  const promotedFinalizationReceiptAuthority = policy.sourceEvidence.find(
    (entry) => entry.path === receiptPathFor(promotedArtifact),
  );
  const promotedReceiptBuild = promotionReceipt?.admittedEvidence?.governedBuild;
  const promotedDeviceAcceptanceAuthority =
    promotionReceipt?.admittedEvidence?.deviceAcceptance;
  const promotedReceiptBoundary = promotionReceipt?.promotion;
  const promotedLedgerEntries = (buildLedger.entries ?? []).filter(
    (entry) => entry.buildNumber === promotedArtifact?.buildNumber,
  );
  const promotedLedgerEntryUnique =
    promotedArtifact == null || promotedLedgerEntries.length === 1;
  const promotedLedger = promotedLedgerEntryUnique
    ? promotedLedgerEntries[0]
    : null;
  const expectedStagedPromotionPath =
    `release/evidence/build-${promotedArtifact?.buildNumber}-` +
    "staged-controlled-pilot-authorization.json";
  const stagedPromotion =
    promotionReceiptPath === expectedStagedPromotionPath &&
    promotionReceipt?.evidenceType ===
      "production-build-staged-controlled-pilot-authorization" &&
    promotionReceipt?.decision ===
      `PASS_BUILD${promotedArtifact?.buildNumber}_STAGED_CONTROLLED_PILOT_AUTHORIZED`;
  const historicalBuild11PromotionExact =
    promotedArtifact?.buildNumber === 11 &&
    promotedReceiptBuild?.buildNumber === 11 &&
    promotionReceiptPath === HISTORICAL_BUILD11_PROMOTION_PATH &&
    promotionReceiptAuthority?.path === HISTORICAL_BUILD11_PROMOTION_PATH &&
    promotionReceiptAuthority?.sha256 ===
      HISTORICAL_BUILD11_PROMOTION_SHA256 &&
    measuredPromotionReceiptSha256 ===
      HISTORICAL_BUILD11_PROMOTION_SHA256 &&
    promotionReceipt?.evidenceType ===
      "stage2d-f6-build11-controlled-pilot-authorization" &&
    promotionReceipt?.decision ===
      "PASS_LR07_CLOSED_AND_STAGE2D_F6_CONTROLLED_PILOT_AUTHORIZED";
  const promotedOwnerApprovalAuthority = promotionReceipt?.ownerApproval;
  const promotedOwnerApprovalArtifact = promotionOwnerApproval?.exactArtifact;
  const promotedOwnerApprovalPilot = promotionOwnerApproval?.authorizedPilot;
  const promotedOwnerApprovalBoundary = promotionOwnerApproval?.mutationBoundary;
  const promotedOwnerApprovalMutationValues =
    promotedOwnerApprovalBoundary == null
      ? []
      : Object.values(promotedOwnerApprovalBoundary);
  const expectedOwnerApprovalPath =
    `release/approvals/build${promotedArtifact?.buildNumber}-` +
    "staged-controlled-pilot-approval.json";
  const stagedPromotionOwnerApprovalExact =
    !stagedPromotion ||
    (promotedOwnerApprovalAuthority?.receipt === expectedOwnerApprovalPath &&
      measuredPromotionOwnerApprovalSha256 ===
        promotedOwnerApprovalAuthority?.sha256 &&
      promotionOwnerApproval?.schemaVersion === 1 &&
      promotionOwnerApproval?.approvalClass ===
        `EXACT_BUILD${promotedArtifact?.buildNumber}_STAGED_CONTROLLED_PILOT_PROMOTION` &&
      promotionOwnerApproval?.approvalReference ===
        promotedOwnerApprovalAuthority?.approvalReference &&
      promotedOwnerApprovalArtifact?.buildNumber ===
        promotedArtifact?.buildNumber &&
      promotedOwnerApprovalArtifact?.sourceCommit === promotedArtifact?.headSha &&
      promotedOwnerApprovalArtifact?.governedPackageSha256 ===
        promotedArtifact?.governedPackageSha256 &&
      promotedOwnerApprovalArtifact?.apkSha256 ===
        promotedReceiptBuild?.apkSha256 &&
      promotedOwnerApprovalArtifact?.certificateSha256 ===
        promotedReceiptBuild?.certificateSha256 &&
      promotedOwnerApprovalArtifact?.applicationId === policy.applicationId &&
      promotedOwnerApprovalPilot?.channel ===
        promotedReceiptBoundary?.authorizedChannel &&
      promotedOwnerApprovalPilot?.maximumApprovedUsers ===
        promotedReceiptBoundary?.maximumApprovedUsers &&
      promotedOwnerApprovalAuthority?.maximumApprovedUsers ===
        promotedReceiptBoundary?.maximumApprovedUsers &&
      promotedOwnerApprovalPilot?.maximumCanaryUsers ===
        promotedReceiptBoundary?.canaryUserCeiling &&
      promotedOwnerApprovalPilot?.maximumCanaryPhysicalDevices ===
        promotedReceiptBoundary?.canaryPhysicalDeviceCeiling &&
      promotedOwnerApprovalPilot?.rosterAndRolesFrozenAtEachHandout === true &&
      promotedOwnerApprovalPilot?.privacySafeUserAndDeviceIdentifiersRequired ===
        true &&
      promotedOwnerApprovalPilot?.perHandoutExecutionReceiptRequired === true &&
      promotedOwnerApprovalPilot?.inPlaceUpgradeRequiredWhereAppAlreadyInstalled ===
        true &&
      promotedOwnerApprovalPilot?.deviceDataClearAllowed === false &&
      promotedOwnerApprovalPilot?.publicArtifactAuthorized === false &&
      promotedOwnerApprovalPilot
        ?.githubActionsArtifactAsDistributionChannelAuthorized === false &&
      promotedOwnerApprovalPilot?.githubReleaseAuthorized === false &&
      promotedOwnerApprovalPilot?.firebaseAppDistributionAuthorized === false &&
      promotedOwnerApprovalPilot?.playConsoleAuthorized === false &&
      promotedOwnerApprovalPilot?.playStoreAuthorized === false &&
      promotedOwnerApprovalPilot?.webDistributionAuthorized === false &&
      promotedOwnerApprovalPilot?.unrestrictedDistributionAuthorized === false &&
      promotedOwnerApprovalPilot?.appCheckActivationAuthorized === false &&
      promotedOwnerApprovalMutationValues.length > 0 &&
      promotedOwnerApprovalMutationValues.every((value) => value === false) &&
      promotedOwnerApprovalBoundary
        ?.firebaseBusinessDataMutationAuthorizedByThisApproval === false &&
      promotedOwnerApprovalBoundary?.firebaseConfigurationMutationAuthorized ===
        false &&
      promotedOwnerApprovalBoundary?.iamMutationAuthorized === false &&
      promotedOwnerApprovalBoundary?.appCheckActivationAuthorized === false &&
      promotedOwnerApprovalBoundary?.deviceDataClearAuthorized === false &&
      promotedOwnerApprovalBoundary?.githubArtifactDeletionAuthorized === false &&
      promotedOwnerApprovalBoundary?.pilotHandoutPerformedByThisApproval ===
        false &&
      promotedOwnerApprovalBoundary?.unrestrictedDistributionAuthorized ===
        false);
  const promotedBackendAuthority =
    promotionReceipt?.admittedEvidence?.productionBackend;
  const promotedBackendBoundary = promotionBackendReceipt?.controlBoundary;
  const promotedFirestoreAuthority =
    promotionReceipt?.admittedEvidence?.firestoreRulesAndIndexes;
  const promotedFirestoreBoundary = promotionFirestoreReceipt?.mutationBoundary;
  const promotedFirestoreBoundaryValues =
    promotedFirestoreBoundary == null
      ? []
      : Object.values(promotedFirestoreBoundary);
  const stagedPromotionInfrastructureExact =
    !stagedPromotion ||
    (promotedBackendAuthority?.receipt ===
      `release/evidence/build${promotedArtifact?.buildNumber}-backend-deployment-closure.json` &&
      measuredPromotionBackendReceiptSha256 ===
        promotedBackendAuthority?.sha256 &&
      promotionBackendReceipt?.schemaVersion === 1 &&
      promotionBackendReceipt?.evidenceType ===
        "exact-current-source-backend-deployment-closure" &&
      promotedBackendAuthority?.decision ===
        `PASS_BUILD${promotedArtifact?.buildNumber}_BACKEND_DEPLOYMENT_CLOSED` &&
      promotionBackendReceipt?.decision ===
        "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK" &&
      promotionBackendReceipt?.firebaseProjectId ===
        policy.productionProjectId &&
      promotionBackendReceipt?.region === "asia-south1" &&
      promotionBackendReceipt?.deployment?.allFunctionsExactSourceVerified ===
        true &&
      promotionBackendReceipt?.deployment?.finalRuntimeIdentityReadbackPassed ===
        true &&
      promotionBackendReceipt?.deployment?.finalIamDependencyReadbackPassed ===
        true &&
      promotionBackendReceipt?.deployment?.existingIamPreservationEnforced ===
        true &&
      promotionBackendReceipt?.deployment?.appCheckEnforcement === false &&
      promotionBackendReceipt?.deployment?.legacyMutatingFinalizeWrapperExecuted ===
        false &&
      promotedBackendBoundary?.iamMutated === false &&
      promotedBackendBoundary?.serviceAccountsMutated === false &&
      promotedBackendBoundary?.appCheckActivated === false &&
      promotedBackendBoundary?.firestoreDocumentsRead === false &&
      promotedBackendBoundary?.firestoreDocumentsWritten === false &&
      promotedBackendBoundary?.productionBusinessDataMutated === false &&
      promotedBackendBoundary?.schedulerManuallyInvoked === false &&
      promotedBackendBoundary?.deviceDataMutated === false &&
      promotedBackendBoundary?.artifactConstructed === false &&
      promotedBackendBoundary?.pilotPromotionPerformed === false &&
      promotedBackendBoundary?.distributionPerformed === false &&
      promotedBackendBoundary?.securityRulesMutated === false &&
      promotedBackendBoundary?.indexesMutated === false &&
      promotedFirestoreAuthority?.receipt ===
        `release/evidence/build${promotedArtifact?.buildNumber}-firestore-rules-indexes-live-readback.json` &&
      measuredPromotionFirestoreReceiptSha256 ===
        promotedFirestoreAuthority?.sha256 &&
      promotionFirestoreReceipt?.schemaVersion === 1 &&
      promotionFirestoreReceipt?.evidenceType ===
        "firestore-rules-indexes-live-readback" &&
      promotionFirestoreReceipt?.mode === "STRICT" &&
      promotionFirestoreReceipt?.projectId === policy.productionProjectId &&
      promotionFirestoreReceipt?.decision ===
        "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK" &&
      promotionFirestoreReceipt?.outputs?.rules?.sourceSha256 ===
        promotedFirestoreAuthority?.rulesSha256 &&
      promotionFirestoreReceipt?.outputs?.rules?.activeSha256 ===
        promotedFirestoreAuthority?.rulesSha256 &&
      promotionFirestoreReceipt?.outputs?.rules?.byteExact === true &&
      promotionFirestoreReceipt?.outputs?.indexes?.sourceCount ===
        promotedFirestoreAuthority?.indexCount &&
      promotionFirestoreReceipt?.outputs?.indexes?.sourceSetSha256 ===
        promotedFirestoreAuthority?.indexSetSha256 &&
      promotionFirestoreReceipt?.outputs?.indexes?.cliSetSha256 ===
        promotedFirestoreAuthority?.indexSetSha256 &&
      promotionFirestoreReceipt?.outputs?.indexes?.apiSetSha256 ===
        promotedFirestoreAuthority?.indexSetSha256 &&
      promotionFirestoreReceipt?.outputs?.indexes?.allApiIndexesReady ===
        true &&
      promotedFirestoreAuthority?.allIndexesReady === true &&
      promotedFirestoreBoundaryValues.length > 0 &&
      promotedFirestoreBoundaryValues.every((value) => value === false));
  const stagedPromotionFinalizationExact =
    !stagedPromotion ||
    (promotedFinalizationReceiptAuthority != null &&
      promotedReceiptBuild?.finalizationReceipt ===
        promotedFinalizationReceiptAuthority.path &&
      promotedReceiptBuild?.finalizationReceiptSha256 ===
        promotedFinalizationReceiptAuthority.sha256 &&
      measuredPromotionFinalizationReceiptSha256 ===
        promotedFinalizationReceiptAuthority.sha256 &&
      promotionFinalizationReceipt?.release?.buildNumber ===
        promotedArtifact?.buildNumber &&
      promotionFinalizationReceipt?.sourceAuthority?.commit ===
        promotedArtifact?.headSha &&
      promotionFinalizationReceipt?.governedPackage?.sha256 ===
        promotedArtifact?.governedPackageSha256 &&
      promotionFinalizationReceipt?.governedPackage?.apkSha256 ===
        promotedReceiptBuild?.apkSha256);
  const promotedMutationBoundary =
    promotionDeviceAcceptanceReceipt?.businessMutationBoundary;
  const promotedMutationValues =
    promotedMutationBoundary == null
      ? []
      : Object.values(promotedMutationBoundary);
  const stagedPromotionMutationClaimsExact =
    !stagedPromotion ||
    (promotionDeviceAcceptanceReceipt?.adjudication
      ?.mutatingBusinessFlowValidationCompleted === false &&
      promotionDeviceAcceptanceReceipt?.releaseBoundary
        ?.productionBusinessMutationAuthorizedByThisReceipt === false &&
      promotionDeviceAcceptanceReceipt?.releaseBoundary
        ?.firebaseBusinessDataChanged === false);
  const stagedPromotionMutationBoundaryExact =
    !stagedPromotion ||
    (promotedMutationValues.length > 0 &&
      promotedMutationValues.every((value) => value === false) &&
      promotedMutationBoundary
        ?.productionBusinessDataCreatedUpdatedOrDeleted === false &&
      promotedDeviceAcceptanceAuthority?.businessDataMutated === false &&
      stagedPromotionMutationClaimsExact);
  const promotedDeviceReleaseBoundary =
    promotionDeviceAcceptanceReceipt?.releaseBoundary;
  const promotedDeviceReleaseBoundaryValues =
    promotedDeviceReleaseBoundary == null
      ? []
      : Object.values(promotedDeviceReleaseBoundary);
  const stagedPromotionDeviceReleaseBoundaryExact =
    !stagedPromotion ||
    (promotedDeviceReleaseBoundaryValues.length > 0 &&
      promotedDeviceReleaseBoundaryValues.every((value) => value === false));
  const promotedClosureBoundary = promotionReceipt?.closureBoundary;
  const stagedPromotionClosureBoundaryExact =
    !stagedPromotion ||
    (promotedClosureBoundary?.deviceAcceptanceRecorded === true &&
      promotedClosureBoundary?.controlledPilotAuthorized === true &&
      promotedClosureBoundary?.pilotHandoutPerformed === false &&
      promotedClosureBoundary?.approvedRosterFrozenByThisRecord === false &&
      promotedClosureBoundary?.githubArtifactDeleted === false &&
      promotedClosureBoundary?.githubReleaseCreated === false &&
      promotedClosureBoundary?.firebaseMutationPerformed === false &&
      promotedClosureBoundary?.deviceMutationPerformed === false &&
      promotedClosureBoundary?.businessDataReadOrWritten === false &&
      promotedClosureBoundary?.unrestrictedDistributionAuthorized === false &&
      promotedClosureBoundary?.appCheckDeferralChanged === false);
  const promotedLedgerPromotionReceiptExact =
    !stagedPromotion ||
    (promotedLedgerEntryUnique &&
      promotedLedger?.pilotPromotionReceiptFile ===
      promotionReceiptAuthority?.path &&
      promotedLedger?.pilotPromotionReceiptSha256 ===
        promotionReceiptAuthority?.sha256);
  const expectedDeviceAcceptancePath =
    `release/evidence/build-${promotedArtifact?.buildNumber}-` +
    "device-acceptance.json";
  const stagedPromotionRuntimeExact =
    !stagedPromotion ||
    (promotedDeviceAcceptanceAuthority != null &&
      promotionDeviceAcceptanceReceipt != null &&
      measuredPromotionDeviceAcceptanceReceiptSha256 ===
        promotedDeviceAcceptanceAuthority.sha256 &&
      promotedDeviceAcceptanceAuthority.receipt ===
        expectedDeviceAcceptancePath &&
      promotionDeviceAcceptanceReceipt.evidenceType ===
        "production-build-device-acceptance" &&
      promotionDeviceAcceptanceReceipt.status ===
        promotedDeviceAcceptanceAuthority.decision &&
      promotionDeviceAcceptanceReceipt.release?.buildNumber ===
        promotedArtifact?.buildNumber &&
      promotionDeviceAcceptanceReceipt.release?.sourceCommit ===
        promotedArtifact?.headSha &&
      promotionDeviceAcceptanceReceipt.release?.finalizationReceiptFile ===
        promotedReceiptBuild?.finalizationReceipt &&
      promotionDeviceAcceptanceReceipt.release?.finalizationReceiptSha256 ===
        promotedReceiptBuild?.finalizationReceiptSha256 &&
      promotionDeviceAcceptanceReceipt.release?.governedPackageSha256 ===
        promotedArtifact?.governedPackageSha256 &&
      promotionDeviceAcceptanceReceipt.release?.apkSha256 ===
        promotedReceiptBuild?.apkSha256 &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.applicationDataPreserved ===
        true &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.targetCount ===
        promotedDeviceAcceptanceAuthority?.physicalTargetCount &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.installedVersionCode ===
        promotedArtifact?.buildNumber &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.installationResult ===
        "success" &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.exactGovernedApkMatch ===
        true &&
      promotionDeviceAcceptanceReceipt.physicalDevice
        ?.signerContinuityVerifiedByInPlaceUpdate === true &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.firstInstallTimePreserved ===
        true &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.applicationDataCleared ===
        false &&
      promotionDeviceAcceptanceReceipt.physicalDevice?.applicationUninstalled ===
        false &&
      promotionDeviceAcceptanceReceipt.releaseBoundary
        ?.deviceDataClearPerformed === false &&
      promotionDeviceAcceptanceReceipt.runtime?.coldLaunchResult === "passed" &&
      promotionDeviceAcceptanceReceipt.runtime?.processRemainedAlive === true &&
      promotionDeviceAcceptanceReceipt.runtime?.androidCrashObserved === false &&
      promotionDeviceAcceptanceReceipt.runtime?.androidAnrObserved === false &&
      promotionDeviceAcceptanceReceipt.runtime?.flutterFatalErrorObserved ===
        false &&
      promotionDeviceAcceptanceReceipt.runtime?.firebaseCallableFailureObserved ===
        false &&
      promotionDeviceAcceptanceReceipt.runtime?.permissionDenialObserved ===
        false &&
      promotionDeviceAcceptanceReceipt.runtime
        ?.approvedAuthenticatedSessionPreserved === true &&
      promotionDeviceAcceptanceReceipt.runtime?.authenticatedHomeRendered ===
        true &&
      promotionDeviceAcceptanceReceipt.localStoreMigration
        ?.governedOpenCompleted ===
        true &&
      promotionDeviceAcceptanceReceipt.localStoreMigration
        ?.applicationDataPreserved === true &&
      promotionDeviceAcceptanceReceipt.localStoreMigration
        ?.isarOpenFailureObserved ===
        false &&
      promotionDeviceAcceptanceReceipt.synchronization?.lastSyncResult ===
        "success" &&
      promotionDeviceAcceptanceReceipt.synchronization?.unsyncedRows === 0 &&
      promotionDeviceAcceptanceReceipt.synchronization
        ?.unresolvedRejections === 0 &&
      promotionDeviceAcceptanceReceipt.synchronization?.pushFailed === 0 &&
      promotionDeviceAcceptanceReceipt.synchronization?.likelyPermanentRejections === 0 &&
      promotionDeviceAcceptanceReceipt.synchronization?.fullSyncConflicts ===
        0 &&
      promotionDeviceAcceptanceReceipt.synchronization?.processingErrors === 0 &&
      promotionDeviceAcceptanceReceipt.adjudication?.runtimeValidationPassed ===
        true &&
      promotionDeviceAcceptanceReceipt.adjudication
        ?.fullBusinessFlowValidationCompleted === false &&
      promotedDeviceAcceptanceAuthority.appDataPreserved === true &&
      promotedDeviceAcceptanceAuthority.automaticSyncPassed === true &&
      promotedDeviceAcceptanceAuthority.unsyncedRows === 0 &&
      promotedDeviceAcceptanceAuthority.unresolvedRejections === 0 &&
      (!preservedFinalizationIsPromoted ||
        (preservedFinalization?.physicalInstallationConditionPassed === true &&
          preservedFinalization?.physicalInstallationReceiptFile ===
            promotedDeviceAcceptanceAuthority.receipt &&
          preservedFinalization?.physicalInstallationReceiptSha256 ===
            promotedDeviceAcceptanceAuthority.sha256 &&
          preservedFinalization?.deviceAcceptanceReceiptFile ===
            promotedDeviceAcceptanceAuthority.receipt &&
          preservedFinalization?.deviceAcceptanceReceiptSha256 ===
            promotedDeviceAcceptanceAuthority.sha256 &&
          preservedFinalization?.runtimeValidationPassed === true &&
          preservedFinalization?.runtimeDisposition ===
            promotedDeviceAcceptanceAuthority.decision &&
          preservedFinalization?.fullBusinessFlowValidationCompleted ===
            false)) &&
      promotedLedger?.physicalInstallationConditionPassed === true &&
      promotedLedger?.physicalInstallationReceiptFile ===
        promotedDeviceAcceptanceAuthority.receipt &&
      promotedLedger?.physicalInstallationReceiptSha256 ===
        promotedDeviceAcceptanceAuthority.sha256 &&
      promotedLedger?.runtimeValidationPassed === true &&
      promotedLedger?.runtimeDisposition ===
        promotedDeviceAcceptanceAuthority.decision &&
      promotedLedger?.fullBusinessFlowValidationCompleted === false &&
      promotedLedger?.controlledPilotApproved === true &&
      stagedPromotionOwnerApprovalExact &&
      stagedPromotionInfrastructureExact &&
      stagedPromotionMutationBoundaryExact &&
      stagedPromotionDeviceReleaseBoundaryExact &&
      stagedPromotionClosureBoundaryExact &&
      promotedLedgerPromotionReceiptExact);
  const promotionReceiptExact =
    promotionReceipt?.schemaVersion === 1 &&
    (stagedPromotion || historicalBuild11PromotionExact) &&
    promotedReceiptBuild?.buildNumber === promotedArtifact?.buildNumber &&
    promotedReceiptBuild?.sourceCommit === promotedArtifact?.headSha &&
    promotedReceiptBuild?.governedPackageSha256 ===
      promotedArtifact?.governedPackageSha256 &&
    promotedReceiptBoundary?.authorizedBuildNumber ===
      promotedArtifact?.buildNumber &&
    promotedReceiptBoundary?.authorizedPackageSha256 ===
      promotedArtifact?.governedPackageSha256 &&
    (!stagedPromotion ||
      (promotedReceiptBuild?.apkSha256 != null &&
        promotedReceiptBoundary?.authorizedApkSha256 ===
          promotedReceiptBuild.apkSha256 &&
        stagedPromotionFinalizationExact &&
        stagedPromotionRuntimeExact)) &&
    promotedReceiptBoundary?.pilotHandoutAuthorized === true &&
    promotedReceiptBoundary?.pilotHandoutPerformedByThisRecord === false &&
    promotedReceiptBoundary?.publicArtifactAuthorized === false &&
    (!stagedPromotion ||
      promotedReceiptBoundary
        ?.githubActionsArtifactAsDistributionChannelAuthorized === false) &&
    promotedReceiptBoundary?.githubReleaseAuthorized === false &&
    promotedReceiptBoundary?.firebaseAppDistributionAuthorized === false &&
    promotedReceiptBoundary?.playConsoleAuthorized === false &&
    promotedReceiptBoundary?.playStoreAuthorized === false &&
    promotedReceiptBoundary?.webDistributionAuthorized === false &&
    promotedReceiptBoundary?.unrestrictedDistributionAuthorized === false &&
    (!stagedPromotion ||
      promotedReceiptBoundary?.appCheckActivationAuthorized === false) &&
    (!stagedPromotion ||
      (promotedReceiptBoundary?.status === "STAGED_CONTROLLED_PILOT_AUTHORIZED" &&
        promotedReceiptBoundary?.maximumApprovedUsers > 0 &&
        promotedReceiptBoundary?.maximumApprovedUsers <= 25 &&
        Number.isInteger(promotedReceiptBoundary?.maximumApprovedUsers) &&
        releasePolicy.distribution?.maximumApprovedUsers ===
          promotedReceiptBoundary.maximumApprovedUsers &&
        postBuildPromotion.maximumApprovedUsers ===
          promotedReceiptBoundary.maximumApprovedUsers &&
        promotedReceiptBoundary?.canaryUserCeiling === 2 &&
        promotedReceiptBoundary?.canaryPhysicalDeviceCeiling === 2));
  const expectedPromotionStatus = stagedPromotion
    ? "completed-staged-controlled-pilot-only"
    : "completed-controlled-pilot-only";
  const expectedDistributionAuthority = stagedPromotion
    ? `exact-build${promotedArtifact?.buildNumber}-staged-controlled-pilot`
    : "exact-build11-sealed-small-group-pilot";
  const controlledPilotPromotionExact =
    promotedArtifact != null &&
    promotionReceiptAuthority != null &&
    promotionReceiptExact &&
    postBuildPromotion.status === expectedPromotionStatus &&
    postBuildPromotion.promotionReceiptFile === promotionReceiptAuthority.path &&
    postBuildPromotion.promotionReceiptSha256 === promotionReceiptAuthority.sha256 &&
    postBuildPromotion.buildNumber === promotedArtifact.buildNumber &&
    postBuildPromotion.sourceCommit === promotedArtifact.headSha &&
    postBuildPromotion.governedPackageSha256 ===
      promotedArtifact.governedPackageSha256 &&
    postBuildPromotion.controlledPilotApproved === true &&
    postBuildPromotion.pilotHandoutPerformed === false &&
    postBuildPromotion.publicArtifactApproved === false &&
    postBuildPromotion.githubReleaseApproved === false &&
    postBuildPromotion.firebaseAppDistributionApproved === false &&
    postBuildPromotion.playConsoleApproved === false &&
    postBuildPromotion.playStoreApproved === false &&
    postBuildPromotion.webDistributionApproved === false &&
    postBuildPromotion.unrestrictedPlantReleaseApproved === false &&
    releasePolicy.distribution?.authority === expectedDistributionAuthority &&
    releasePolicy.distribution?.approved === true &&
    releasePolicy.distribution?.approvedBuildNumber ===
      promotedArtifact.buildNumber &&
    releasePolicy.distribution?.approvedPackageSha256 ===
      promotedArtifact.governedPackageSha256 &&
    (!stagedPromotion ||
      releasePolicy.distribution?.approvedApkSha256 ===
        promotedReceiptBuild?.apkSha256) &&
    releasePolicy.distribution?.promotionReceiptFile ===
      promotionReceiptAuthority.path &&
    releasePolicy.distribution?.promotionReceiptSha256 ===
      promotionReceiptAuthority.sha256 &&
    releasePolicy.distribution?.pilotHandoutPerformed === false &&
    releasePolicy.distribution?.unrestrictedPlantReleaseApproved === false &&
    releasePolicy.distribution?.postBuildPromotionRequiredForAnyDistribution ===
      true &&
    (currentBuildNumber === promotedArtifact.buildNumber ||
      (releasePolicy.distribution?.preservedHistoricalAuthority === true &&
        releasePolicy.distribution?.appliesToCurrentCandidate === false &&
        finalization.controlledPilotApproved === false));

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
      (nonDistributionExact || controlledPilotPromotionExact),
    buildLedgerExact:
      expectedLedgerEntriesExact &&
      sourceOnlySuccessorsExact &&
      pendingSuccessorExact &&
      promotedLedgerEntryUnique &&
      promotedLedgerPromotionReceiptExact,
    latestContainmentAttemptExact,
    controlledPilotPromotionExact,
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
  const promotionReceiptRelativePath =
    releasePolicy.postBuildPromotion?.promotionReceiptFile;
  if (
    typeof promotionReceiptRelativePath !== "string" ||
    promotionReceiptRelativePath.length === 0
  ) {
    fail("Production release policy has no promotion receipt path.");
  }
  const promotionReceiptPath = path.resolve(
    repositoryRoot,
    promotionReceiptRelativePath,
  );
  if (!isPathInside(repositoryRoot, promotionReceiptPath)) {
    fail("Promotion receipt escapes the repository root.");
  }
  const promotionReceipt = readJson(promotionReceiptPath);
  const measuredPromotionReceiptSha256 = sha256(
    fs.readFileSync(promotionReceiptPath),
  );
  const promotionFinalizationRelativePath =
    promotionReceipt?.admittedEvidence?.governedBuild?.finalizationReceipt;
  let promotionFinalizationReceipt = null;
  let measuredPromotionFinalizationReceiptSha256 = null;
  if (
    typeof promotionFinalizationRelativePath === "string" &&
    promotionFinalizationRelativePath.length > 0
  ) {
    const promotionFinalizationPath = path.resolve(
      repositoryRoot,
      promotionFinalizationRelativePath,
    );
    if (!isPathInside(repositoryRoot, promotionFinalizationPath)) {
      fail("Promotion finalization receipt escapes the repository root.");
    }
    if (fs.existsSync(promotionFinalizationPath)) {
      const finalizationBytes = fs.readFileSync(promotionFinalizationPath);
      promotionFinalizationReceipt = JSON.parse(
        finalizationBytes.toString("utf8"),
      );
      measuredPromotionFinalizationReceiptSha256 = sha256(finalizationBytes);
    }
  }
  const promotionDeviceAcceptanceRelativePath =
    promotionReceipt?.admittedEvidence?.deviceAcceptance?.receipt;
  let promotionDeviceAcceptanceReceipt = null;
  let measuredPromotionDeviceAcceptanceReceiptSha256 = null;
  if (
    typeof promotionDeviceAcceptanceRelativePath === "string" &&
    promotionDeviceAcceptanceRelativePath.length > 0
  ) {
    const promotionDeviceAcceptancePath = path.resolve(
      repositoryRoot,
      promotionDeviceAcceptanceRelativePath,
    );
    if (!isPathInside(repositoryRoot, promotionDeviceAcceptancePath)) {
      fail("Promotion device-acceptance receipt escapes the repository root.");
    }
    if (fs.existsSync(promotionDeviceAcceptancePath)) {
      const deviceAcceptanceBytes = fs.readFileSync(
        promotionDeviceAcceptancePath,
      );
      promotionDeviceAcceptanceReceipt = JSON.parse(
        deviceAcceptanceBytes.toString("utf8"),
      );
      measuredPromotionDeviceAcceptanceReceiptSha256 = sha256(
        deviceAcceptanceBytes,
      );
    }
  }
  const promotionOwnerApprovalRelativePath =
    promotionReceipt?.ownerApproval?.receipt;
  let promotionOwnerApproval = null;
  let measuredPromotionOwnerApprovalSha256 = null;
  if (
    typeof promotionOwnerApprovalRelativePath === "string" &&
    promotionOwnerApprovalRelativePath.length > 0
  ) {
    const promotionOwnerApprovalPath = path.resolve(
      repositoryRoot,
      promotionOwnerApprovalRelativePath,
    );
    if (!isPathInside(repositoryRoot, promotionOwnerApprovalPath)) {
      fail("Promotion owner-approval receipt escapes the repository root.");
    }
    if (fs.existsSync(promotionOwnerApprovalPath)) {
      const ownerApprovalBytes = fs.readFileSync(promotionOwnerApprovalPath);
      promotionOwnerApproval = JSON.parse(ownerApprovalBytes.toString("utf8"));
      measuredPromotionOwnerApprovalSha256 = sha256(ownerApprovalBytes);
    }
  }
  const promotionBackendRelativePath =
    promotionReceipt?.admittedEvidence?.productionBackend?.receipt;
  let promotionBackendReceipt = null;
  let measuredPromotionBackendReceiptSha256 = null;
  if (
    typeof promotionBackendRelativePath === "string" &&
    promotionBackendRelativePath.length > 0
  ) {
    const promotionBackendPath = path.resolve(
      repositoryRoot,
      promotionBackendRelativePath,
    );
    if (!isPathInside(repositoryRoot, promotionBackendPath)) {
      fail("Promotion backend receipt escapes the repository root.");
    }
    if (fs.existsSync(promotionBackendPath)) {
      const backendBytes = fs.readFileSync(promotionBackendPath);
      promotionBackendReceipt = JSON.parse(backendBytes.toString("utf8"));
      measuredPromotionBackendReceiptSha256 = sha256(backendBytes);
    }
  }
  const promotionFirestoreRelativePath =
    promotionReceipt?.admittedEvidence?.firestoreRulesAndIndexes?.receipt;
  let promotionFirestoreReceipt = null;
  let measuredPromotionFirestoreReceiptSha256 = null;
  if (
    typeof promotionFirestoreRelativePath === "string" &&
    promotionFirestoreRelativePath.length > 0
  ) {
    const promotionFirestorePath = path.resolve(
      repositoryRoot,
      promotionFirestoreRelativePath,
    );
    if (!isPathInside(repositoryRoot, promotionFirestorePath)) {
      fail("Promotion Firestore receipt escapes the repository root.");
    }
    if (fs.existsSync(promotionFirestorePath)) {
      const firestoreBytes = fs.readFileSync(promotionFirestorePath);
      promotionFirestoreReceipt = JSON.parse(firestoreBytes.toString("utf8"));
      measuredPromotionFirestoreReceiptSha256 = sha256(firestoreBytes);
    }
  }
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
    promotionReceipt,
    measuredPromotionReceiptSha256,
    promotionFinalizationReceipt,
    measuredPromotionFinalizationReceiptSha256,
    promotionDeviceAcceptanceReceipt,
    measuredPromotionDeviceAcceptanceReceiptSha256,
    promotionOwnerApproval,
    measuredPromotionOwnerApprovalSha256,
    promotionBackendReceipt,
    measuredPromotionBackendReceiptSha256,
    promotionFirestoreReceipt,
    measuredPromotionFirestoreReceiptSha256,
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
