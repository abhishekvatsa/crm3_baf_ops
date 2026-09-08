import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {createRequire} from "node:module";
import {execFileSync} from "node:child_process";
import fs from "node:fs";
import {createHash} from "node:crypto";

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

const backendClosureDecisions = [
  ['authorityChronology.allObservedFunctionUpdatesPostdateOwnerInstruction', true],
  ['authorityChronology.deploymentWasRetroactivelyAuthorized', false],
  ['controlBoundary.aggregateBacklogQueriesPerformed', true],
  ['sourceAuthority.postMergeReleaseGateConclusion', 'success'],
  ['firestoreDeployment.rulesActiveByteExact', true],
  ['firestoreDeployment.allIndexesReady', true],
  ['firestoreDeployment.indexesAlreadyExactNoMutationRequired', true],
  ['firestoreDeployment.strictLiveReadbackPassed', true],
  ['firestoreDeployment.rulesAlreadyExactNoMutationRequired', true],
  ['firestoreDeployment.rulesDeploymentPerformed', false],
  ['cleanMainLiveReadbacks.functionFleet.decision', 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL'],
  ['cleanMainLiveReadbacks.iamDependencies.decision', 'PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK'],
  ['cleanMainLiveReadbacks.firestoreRulesAndIndexes.decision', 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK'],
  ['cleanMainLiveReadbacks.firestoreRulesAndIndexes.verified', true],
  ['cleanMainLiveReadbacks.firestoreRulesAndIndexes.allIndexesReady', true],
];

function measuredPromotionFixture() {
  const read = (file) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, file), 'utf8'));
  const hashFile = (file) => createHash('sha256')
    .update(fs.readFileSync(path.join(repositoryRoot, file))).digest('hex').toUpperCase();
  const input = {policy: read('release/lr07-distribution-installation-readback-policy.json'),
    releasePolicy: read('release/production-release-policy.json'),
    buildLedger: read('release/build-number-ledger.json')};
  input.promotionReceipt = read(input.releasePolicy.postBuildPromotion.promotionReceiptFile);
  input.measuredPromotionReceiptSha256 = hashFile(input.releasePolicy.postBuildPromotion.promotionReceiptFile);
  const receiptPaths = [
    ['FinalizationReceipt', input.promotionReceipt.admittedEvidence.governedBuild.finalizationReceipt],
    ['DeviceAcceptanceReceipt', input.promotionReceipt.admittedEvidence.deviceAcceptance.receipt],
    ['OwnerApproval', input.promotionReceipt.ownerApproval.receipt],
    ['BackendReceipt', input.promotionReceipt.admittedEvidence.productionBackend.receipt],
    ['FirestoreReceipt', input.promotionReceipt.admittedEvidence.firestoreRulesAndIndexes.receipt],
  ];
  for (const [key, file] of receiptPaths) {
    input[`promotion${key}`] = read(file);
    input[`measuredPromotion${key}Sha256`] = hashFile(file);
  }
  return input;
}

function rebindMeasuredReceipt(input, receiptKey = 'BackendReceipt') {
  const hash = (value) => createHash('sha256').update(JSON.stringify(value)).digest('hex').toUpperCase();
  const replace = (object, before, after) => {
    for (const key of Object.keys(object)) {
      if (object[key] === before) object[key] = after;
      else if (object[key] != null && typeof object[key] === 'object') replace(object[key], before, after);
    }
  };
  replace(input, input[`measuredPromotion${receiptKey}Sha256`], hash(input[`promotion${receiptKey}`]));
  if (receiptKey === 'FinalizationReceipt') {
    replace(input, input.measuredPromotionDeviceAcceptanceReceiptSha256, hash(input.promotionDeviceAcceptanceReceipt));
  }
  if (receiptKey !== 'Receipt') replace(input, input.measuredPromotionReceiptSha256, hash(input.promotionReceipt));
}

test('measured backend authorization and readback decisions cannot contradict pilot authority', () => {
  const healthy = measuredPromotionFixture();
  assert.equal(summarizeMutableSourceAuthority(healthy).controlledPilotPromotionExact, true);
  for (const [field, expected] of backendClosureDecisions) {
    const badValues = typeof expected === 'boolean' ?
      [!expected, String(expected), 0, 1, null, undefined, [expected]] :
      ['FAIL', expected === expected.toUpperCase() ? expected.toLowerCase() : expected.toUpperCase(), false, null, undefined, [expected]];
    for (const value of badValues) {
      const input = structuredClone(healthy);
      const parts = field.split('.');
      let target = input.promotionBackendReceipt;
      for (const key of parts.slice(0, -1)) target = target[key];
      if (value === undefined) delete target[parts.at(-1)];
      else target[parts.at(-1)] = value;
      rebindMeasuredReceipt(input);
      const result = summarizeMutableSourceAuthority(input);
      assert.equal(result.releasePolicyExact, false, `${field}: ${JSON.stringify(value)}`);
      assert.equal(result.controlledPilotPromotionExact, false, `${field}: ${JSON.stringify(value)}`);
    }
  }
});

const promotionAndCustodyDecisions = [
  ['Receipt', 'sourceAuthority.postMergeCi.allRequiredJobsPassed', true],
  ['Receipt', 'sourceAuthority.postMergeCi.conclusion', 'success'],
  ['Receipt', 'programmeDecision.internalControlledPilot', 'GO_STAGED'],
  ['Receipt', 'programmeDecision.pilotHandout', 'AUTHORIZED_EXACT_BUILD27_FROZEN_ROSTER_UP_TO_25'],
  ['Receipt', 'programmeDecision.canary', 'TWO_USERS_TWO_PHYSICAL_DEVICES_BEFORE_EXPANSION'],
  ['Receipt', 'programmeDecision.mutatingBusinessFlowValidation', 'OPEN_COLLECT_DURING_CANARY'],
  ['Receipt', 'programmeDecision.unrestrictedDistribution', 'NO_GO'],
  ['FinalizationReceipt', 'governedPackage.independentVerificationCompleted', true],
  ['FinalizationReceipt', 'dualCustody.allFileHashesMatched', true],
  ['FinalizationReceipt', 'dualCustody.status', 'passed'],
];

test('measured promotion and custody verdicts cannot contradict retained pilot authority', () => {
  const healthy = measuredPromotionFixture();
  assert.equal(summarizeMutableSourceAuthority(healthy).controlledPilotPromotionExact, true);
  for (const [receiptKey, field, expected] of promotionAndCustodyDecisions) {
    const badValues = typeof expected === 'boolean' ?
      [!expected, String(expected), 0, null, undefined, [expected]] :
      ['FAIL', expected === expected.toUpperCase() ? expected.toLowerCase() : expected.toUpperCase(), false, null, undefined, [expected]];
    for (const value of badValues) {
      const input = structuredClone(healthy);
      const parts = field.split('.');
      let target = input[`promotion${receiptKey}`];
      for (const key of parts.slice(0, -1)) target = target[key];
      if (value === undefined) delete target[parts.at(-1)];
      else target[parts.at(-1)] = value;
      rebindMeasuredReceipt(input, receiptKey);
      const result = summarizeMutableSourceAuthority(input);
      assert.equal(result.releasePolicyExact, false, `${field}: ${JSON.stringify(value)}`);
      assert.equal(result.controlledPilotPromotionExact, false, `${field}: ${JSON.stringify(value)}`);
    }
  }
});

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

  for (const extraEntries of [
    [structuredClone(build9Ledger)],
    [{...build9Ledger, distributionPerformed: true}],
    [{buildNumber: 8}, {buildNumber: 8, distributionPerformed: true}],
  ]) {
    assert.equal(summarizeMutableSourceAuthority({
      policy, releasePolicy,
      buildLedger: {entries: [build9Ledger, build10Ledger, ...extraEntries]},
    }).buildLedgerExact, false, 'every historical build number must be unique');
  }
  for (const buildNumber of ['8', null, false, 0, -1, 8.5, 2147483648, undefined]) {
    assert.equal(summarizeMutableSourceAuthority({
      policy, releasePolicy,
      buildLedger: {entries: [{buildNumber}, build9Ledger, build10Ledger]},
    }).buildLedgerExact, false, 'ledger identities must be positive int32 numbers');
  }

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
  const certificateSha = "5".repeat(64).toUpperCase();
  const backendReceiptPath =
    "release/evidence/build11-backend-deployment-closure.json";
  const backendReceiptSha = "2".repeat(64).toUpperCase();
  const firestoreReceiptPath =
    "release/evidence/build11-firestore-rules-indexes-live-readback.json";
  const firestoreReceiptSha = "3".repeat(64).toUpperCase();
  const rulesSha = "7".repeat(64).toUpperCase();
  const indexSetSha = "8".repeat(64).toUpperCase();
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
    maximumApprovedUsers: 25,
    canaryUserCeiling: 2,
    canaryPhysicalDeviceCeiling: 2,
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
    sourceAuthority: {postMergeCi: {allRequiredJobsPassed: true, conclusion: 'success'}},
    programmeDecision: {
      internalControlledPilot: 'GO_STAGED',
      pilotHandout: 'AUTHORIZED_EXACT_BUILD11_FROZEN_ROSTER_UP_TO_25',
      canary: 'TWO_USERS_TWO_PHYSICAL_DEVICES_BEFORE_EXPANSION',
      mutatingBusinessFlowValidation: 'OPEN_COLLECT_DURING_CANARY',
      unrestrictedDistribution: 'NO_GO',
    },
    ownerApproval: {
      receipt:
        "release/approvals/build11-staged-controlled-pilot-approval.json",
      sha256: "4".repeat(64).toUpperCase(),
      approvalReference: "BAF-REF-004-C11-PILOT",
      maximumApprovedUsers: 25,
    },
    admittedEvidence: {
      governedBuild: {
        buildNumber: completed.buildNumber,
        sourceCommit: completed.headSha,
        governedPackageSha256: completed.governedPackageSha256,
        apkSha256: apkSha,
        certificateSha256: certificateSha,
        finalizationReceipt: completionPath,
        finalizationReceiptSha256: completionSha,
        dualCustodyCompleted: true,
        oneTargetInPlaceValidationPassed: true,
        mutatingBusinessFlowValidationCompleted: false,
      },
      deviceAcceptance: {
        receipt: deviceAcceptancePath,
        sha256: deviceAcceptanceSha,
        decision: runtimeDisposition,
        physicalTargetCount: 1,
        appDataPreserved: true,
        automaticSyncPassed: true,
        unsyncedRows: 0,
        unresolvedRejections: 0,
        businessDataMutated: false,
      },
      productionBackend: {
        receipt: backendReceiptPath,
        sha256: backendReceiptSha,
        decision: "PASS_BUILD11_BACKEND_DEPLOYMENT_CLOSED",
      },
      firestoreRulesAndIndexes: {
        receipt: firestoreReceiptPath,
        sha256: firestoreReceiptSha,
        decision: "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK",
        rulesSha256: rulesSha,
        indexSetSha256: indexSetSha,
        indexCount: 66,
        allIndexesReady: true,
      },
    },
    promotion: {
      status: "STAGED_CONTROLLED_PILOT_AUTHORIZED",
      authorizedBuildNumber: completed.buildNumber,
      authorizedPackageSha256: completed.governedPackageSha256,
      authorizedApkSha256: apkSha,
      authorizedChannel: "direct-dual-custody-controlled-pilot",
      pilotHandoutAuthorized: true,
      pilotHandoutPerformedByThisRecord: false,
      publicArtifactAuthorized: false,
      githubActionsArtifactAsDistributionChannelAuthorized: false,
      githubReleaseAuthorized: false,
      firebaseAppDistributionAuthorized: false,
      playConsoleAuthorized: false,
      playStoreAuthorized: false,
      webDistributionAuthorized: false,
      unrestrictedDistributionAuthorized: false,
      appCheckActivationAuthorized: false,
      maximumApprovedUsers: 25,
      canaryUserCeiling: 2,
      canaryPhysicalDeviceCeiling: 2,
    },
    closureBoundary: {
      deviceAcceptanceRecorded: true,
      controlledPilotAuthorized: true,
      pilotHandoutPerformed: false,
      approvedRosterFrozenByThisRecord: false,
      githubArtifactDeleted: false,
      githubReleaseCreated: false,
      firebaseMutationPerformed: false,
      deviceMutationPerformed: false,
      businessDataReadOrWritten: false,
      unrestrictedDistributionAuthorized: false,
      appCheckDeferralChanged: false,
    },
  };
  const promotionFinalizationReceipt = {
    release: {buildNumber: completed.buildNumber},
    sourceAuthority: {commit: completed.headSha},
    governedPackage: {
      sha256: completed.governedPackageSha256,
      apkSha256: apkSha,
      independentVerificationCompleted: true,
    },
    dualCustody: {allFileHashesMatched: true, status: 'passed'},
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
    physicalDevice: {
      targetCount: 1,
      installedVersionCode: completed.buildNumber,
      installationResult: "success",
      exactGovernedApkMatch: true,
      signerContinuityVerifiedByInPlaceUpdate: true,
      firstInstallTimePreserved: true,
      applicationDataPreserved: true,
      applicationDataCleared: false,
      applicationUninstalled: false,
    },
    runtime: {
      coldLaunchResult: "passed",
      processRemainedAlive: true,
      androidCrashObserved: false,
      androidAnrObserved: false,
      flutterFatalErrorObserved: false,
      firebaseCallableFailureObserved: false,
      permissionDenialObserved: false,
      approvedAuthenticatedSessionPreserved: true,
      authenticatedHomeRendered: true,
    },
    localStoreMigration: {
      governedOpenCompleted: true,
      applicationDataPreserved: true,
      isarOpenFailureObserved: false,
    },
    businessMutationBoundary: {
      productionBusinessDataCreatedUpdatedOrDeleted: false,
      ticketSubmitted: false,
    },
    synchronization: {
      automaticStartupSyncPassesObserved: 2,
      syncStateAtInventory: "idle",
      globalPullConflict: 0,
      likelyPermanentRejections: 0,
      lastSyncResult: "success",
      unsyncedRows: 0,
      unresolvedRejections: 0,
      pushFailed: 0,
      fullSyncConflicts: 0,
      processingErrors: 0,
    },
    adjudication: {
      physicalInPlaceMigrationPassed: true,
      authenticatedReadOnlySurfaceValidationCompleted: true,
      mutatingBusinessFlowValidationCompleted: false,
      runtimeValidationPassed: true,
      fullBusinessFlowValidationCompleted: false,
    },
    releaseBoundary: {
      build11FinalizationReceiptChanged: false,
      controlledPilotApprovedByThisReceipt: false,
      pilotHandoutPerformed: false,
      unrestrictedDistributionApproved: false,
      productionBusinessMutationAuthorizedByThisReceipt: false,
      firebaseBusinessDataChanged: false,
      appCheckActivationPerformed: false,
      deviceDataClearPerformed: false,
    },
  };
  const promotionOwnerApproval = {
    schemaVersion: 1,
    approvalClass: "EXACT_BUILD11_STAGED_CONTROLLED_PILOT_PROMOTION",
    approvalReference: "BAF-REF-004-C11-PILOT",
    exactArtifact: {
      buildNumber: completed.buildNumber,
      applicationId: policy.applicationId,
      sourceCommit: completed.headSha,
      governedPackageSha256: completed.governedPackageSha256,
      apkSha256: apkSha,
      certificateSha256: certificateSha,
    },
    authorizedPilot: {
      channel: "direct-dual-custody-controlled-pilot",
      maximumApprovedUsers: 25,
      maximumCanaryUsers: 2,
      maximumCanaryPhysicalDevices: 2,
      rosterAndRolesFrozenAtEachHandout: true,
      privacySafeUserAndDeviceIdentifiersRequired: true,
      perHandoutExecutionReceiptRequired: true,
      inPlaceUpgradeRequiredWhereAppAlreadyInstalled: true,
      deviceDataClearAllowed: false,
      publicArtifactAuthorized: false,
      githubActionsArtifactAsDistributionChannelAuthorized: false,
      githubReleaseAuthorized: false,
      firebaseAppDistributionAuthorized: false,
      playConsoleAuthorized: false,
      playStoreAuthorized: false,
      webDistributionAuthorized: false,
      unrestrictedDistributionAuthorized: false,
      appCheckActivationAuthorized: false,
    },
    mutationBoundary: {
      firebaseBusinessDataMutationAuthorizedByThisApproval: false,
      firebaseConfigurationMutationAuthorized: false,
      iamMutationAuthorized: false,
      appCheckActivationAuthorized: false,
      deviceDataClearAuthorized: false,
      githubArtifactDeletionAuthorized: false,
      pilotHandoutPerformedByThisApproval: false,
      unrestrictedDistributionAuthorized: false,
    },
  };
  const promotionBackendReceipt = {
    schemaVersion: 1,
    evidenceType: "exact-current-source-backend-deployment-closure",
    decision: "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK",
    firebaseProjectId: policy.productionProjectId,
    region: "asia-south1",
    authorityChronology: {
      ownerInstructionReceivedAtUtc: '2026-09-08T00:48:30.433Z',
      earliestFunctionUpdateTime: '2026-09-08T00:50:50.909069859Z',
      latestFunctionUpdateTime: '2026-09-08T00:57:47.774550619Z',
      allObservedFunctionUpdatesPostdateOwnerInstruction: true,
      deploymentWasRetroactivelyAuthorized: false,
    },
    sourceAuthority: {postMergeReleaseGateConclusion: 'success'},
    firestoreDeployment: {
      rulesActiveByteExact: true,
      allIndexesReady: true,
      indexesAlreadyExactNoMutationRequired: true,
      strictLiveReadbackPassed: true,
      rulesAlreadyExactNoMutationRequired: true,
      rulesDeploymentPerformed: false,
    },
    cleanMainLiveReadbacks: {
      functionFleet: {failedChecks: 0, decision: 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL'},
      iamDependencies: {failedChecks: 0, postureHolds: 0, decision: 'PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK'},
      firestoreRulesAndIndexes: {failedChecks: 0, verified: true, allIndexesReady: true, decision: 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK'},
    },
    deployment: {
      allFunctionsExactSourceVerified: true,
      finalRuntimeIdentityReadbackPassed: true,
      finalIamDependencyReadbackPassed: true,
      existingIamPreservationEnforced: true,
      appCheckEnforcement: false,
      legacyMutatingFinalizeWrapperExecuted: false,
      schedulerBacklogZeroVerified: true,
      schedulerSmokeResult: {
        invoked: false,
        workflowEscalationCandidateCount: 0,
        changed: 0,
      },
    },
    controlBoundary: {
      schedulerSmokeChangedRecordCount: 0,
      aggregateBacklogQueriesPerformed: true,
      serviceAccountsMutated: false,
      iamMutated: false,
      appCheckActivated: false,
      firestoreDocumentsRead: false,
      firestoreDocumentsWritten: false,
      productionBusinessDataMutated: false,
      schedulerManuallyInvoked: false,
      deviceDataMutated: false,
      artifactConstructed: false,
      pilotPromotionPerformed: false,
      distributionPerformed: false,
      securityRulesMutated: false,
      indexesMutated: false,
    },
  };
  const promotionFirestoreReceipt = {
    schemaVersion: 1,
    evidenceType: "firestore-rules-indexes-live-readback",
    mode: "STRICT",
    projectId: policy.productionProjectId,
    decision: "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK",
    outputs: {
      rules: {
        sourceSha256: rulesSha,
        activeSha256: rulesSha,
        byteExact: true,
      },
      indexes: {
        sourceCount: 66,
        sourceSetSha256: indexSetSha,
        cliSetSha256: indexSetSha,
        apiSetSha256: indexSetSha,
        allApiIndexesReady: true,
      },
    },
    mutationBoundary: {
      firestoreRulesDeployed: false,
      firestoreIndexesDeployed: false,
      firestoreDocumentsRead: false,
      firestoreDocumentsWritten: false,
      functionsMutated: false,
      iamMutated: false,
      appCheckMutated: false,
      businessDataMutated: false,
    },
  };
  const promotionRuntimeAuthority = {
    promotionDeviceAcceptanceReceipt,
    measuredPromotionDeviceAcceptanceReceiptSha256: deviceAcceptanceSha,
    promotionOwnerApproval,
    measuredPromotionOwnerApprovalSha256:
      promotionReceipt.ownerApproval.sha256,
    promotionBackendReceipt,
    measuredPromotionBackendReceiptSha256: backendReceiptSha,
    promotionFirestoreReceipt,
    measuredPromotionFirestoreReceiptSha256: firestoreReceiptSha,
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

  for (const section of ['distribution', 'postBuildPromotion']) {
    for (const cap of [26, 0, 24, '25', null]) {
      const mismatchedCap = structuredClone(promotedPolicy);
      mismatchedCap[section].maximumApprovedUsers = cap;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: mismatchedCap, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
      }).releasePolicyExact, false, `${section} cap ${cap} must match approval`);
    }
    for (const field of ['canaryUserCeiling', 'canaryPhysicalDeviceCeiling']) {
      for (const cap of [3, 1, '2', null]) {
        const mismatchedCap = structuredClone(promotedPolicy);
        mismatchedCap[section][field] = cap;
        assert.equal(summarizeMutableSourceAuthority({
          policy, releasePolicy: mismatchedCap, buildLedger: {entries: ledgers},
          promotionReceipt, ...promotionFinalizationAuthority,
        }).releasePolicyExact, false, `${section}.${field} must match approval`);
      }
    }
  }

  for (const counter of ['likelyPermanentRejections', 'pushFailed', 'fullSyncConflicts', 'processingErrors', 'globalPullConflict']) {
    for (const value of [1, -1, '0', null, false, undefined]) {
      const badSync = structuredClone(promotionDeviceAcceptanceReceipt);
      badSync.synchronization[counter] = value;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
        promotionDeviceAcceptanceReceipt: badSync,
      }).releasePolicyExact, false, `${counter} must be numeric zero`);
    }
  }

  for (const [field, values] of [
    ['automaticStartupSyncPassesObserved', [0, -1, 0.5, '2', null, false, undefined]],
    ['syncStateAtInventory', ['running', 'error', 'IDLE', null, undefined]],
  ]) {
    for (const value of values) {
      const badSync = structuredClone(promotionDeviceAcceptanceReceipt);
      badSync.synchronization[field] = value;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
        promotionDeviceAcceptanceReceipt: badSync,
      }).releasePolicyExact, false, `${field} must substantiate completed automatic sync`);
    }
  }

  for (const field of ['physicalInPlaceMigrationPassed', 'authenticatedReadOnlySurfaceValidationCompleted']) {
    for (const value of [false, null, 'true', undefined]) {
      const badDevice = structuredClone(promotionDeviceAcceptanceReceipt);
      badDevice.adjudication[field] = value;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
        promotionDeviceAcceptanceReceipt: badDevice,
      }).releasePolicyExact, false, `${field} must be a measured pass`);
    }
  }

  for (const [field, value] of [
    ['dualCustodyCompleted', false],
    ['oneTargetInPlaceValidationPassed', false],
    ['mutatingBusinessFlowValidationCompleted', true],
  ]) {
    const badPromotion = structuredClone(promotionReceipt);
    badPromotion.admittedEvidence.governedBuild[field] = value;
    assert.equal(summarizeMutableSourceAuthority({
      policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
      promotionReceipt: badPromotion, ...promotionFinalizationAuthority,
    }).releasePolicyExact, false, `${field} must agree with admitted evidence`);
  }

  for (const segments of [
    ['controlBoundary', 'schedulerSmokeChangedRecordCount'],
    ['deployment', 'schedulerSmokeResult', 'changed'],
    ['deployment', 'schedulerSmokeResult', 'workflowEscalationCandidateCount'],
    ['cleanMainLiveReadbacks', 'functionFleet', 'failedChecks'],
    ['cleanMainLiveReadbacks', 'iamDependencies', 'failedChecks'],
    ['cleanMainLiveReadbacks', 'iamDependencies', 'postureHolds'],
    ['cleanMainLiveReadbacks', 'firestoreRulesAndIndexes', 'failedChecks'],
  ]) {
    for (const value of [1, -1, '0', null, false, undefined]) {
      const badBackend = structuredClone(promotionBackendReceipt);
      let target = badBackend;
      for (const segment of segments.slice(0, -1)) target = target[segment];
      target[segments.at(-1)] = value;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
        promotionBackendReceipt: badBackend,
      }).releasePolicyExact, false, `${segments.join('.')} must be numeric zero`);
    }
  }

  for (const [segments, values] of [
    [['deployment', 'schedulerSmokeResult', 'invoked'], [true, 0, 'false', null, undefined]],
    [['deployment', 'schedulerBacklogZeroVerified'], [false, 1, 'true', null, undefined]],
  ]) {
    for (const value of values) {
      const badBackend = structuredClone(promotionBackendReceipt);
      let target = badBackend;
      for (const segment of segments.slice(0, -1)) target = target[segment];
      target[segments.at(-1)] = value;
      assert.equal(summarizeMutableSourceAuthority({
        policy, releasePolicy: promotedPolicy, buildLedger: {entries: ledgers},
        promotionReceipt, ...promotionFinalizationAuthority,
        promotionBackendReceipt: badBackend,
      }).releasePolicyExact, false, `${segments.join('.')} must substantiate scheduler boundaries`);
    }
  }

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

  for (const mutateBusinessAcceptance of [
    (receipt) => {
      receipt.businessMutationBoundary.productionBusinessDataCreatedUpdatedOrDeleted =
        true;
    },
    (receipt) => {
      receipt.adjudication.mutatingBusinessFlowValidationCompleted = true;
    },
    (receipt) => {
      receipt.releaseBoundary.productionBusinessMutationAuthorizedByThisReceipt =
        true;
    },
    (receipt) => {
      receipt.releaseBoundary.firebaseBusinessDataChanged = true;
    },
  ]) {
    const mutatedBusinessAcceptance = structuredClone(
      promotionDeviceAcceptanceReceipt,
    );
    mutateBusinessAcceptance(mutatedBusinessAcceptance);
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
  }

  for (const mutateDevicePreservation of [
    (receipt) => {
      receipt.physicalDevice.applicationDataCleared = true;
    },
    (receipt) => {
      receipt.physicalDevice.applicationUninstalled = true;
    },
    (receipt) => {
      receipt.releaseBoundary.deviceDataClearPerformed = true;
    },
    (receipt) => {
      receipt.runtime.androidCrashObserved = true;
    },
    (receipt) => {
      receipt.localStoreMigration.isarOpenFailureObserved = true;
    },
  ]) {
    const weakenedDeviceAcceptance = structuredClone(
      promotionDeviceAcceptanceReceipt,
    );
    mutateDevicePreservation(weakenedDeviceAcceptance);
    const weakenedDeviceSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt,
      ...promotionFinalizationAuthority,
      promotionDeviceAcceptanceReceipt: weakenedDeviceAcceptance,
    });
    assert.equal(weakenedDeviceSummary.releasePolicyExact, false);
    assert.equal(weakenedDeviceSummary.controlledPilotPromotionExact, false);
  }

  for (const weakenOwnerApproval of [
    ({receipt}) => {
      receipt.ownerApproval.receipt =
        "release/approvals/unmeasured-pilot-approval.json";
    },
    ({approval}) => {
      approval.exactArtifact.apkSha256 = "7".repeat(64).toUpperCase();
    },
    ({approval}) => {
      approval.authorizedPilot.deviceDataClearAllowed = true;
    },
  ]) {
    const weakenedReceipt = structuredClone(promotionReceipt);
    const weakenedApproval = structuredClone(promotionOwnerApproval);
    weakenOwnerApproval({receipt: weakenedReceipt, approval: weakenedApproval});
    const weakenedOwnerSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt: weakenedReceipt,
      ...promotionFinalizationAuthority,
      promotionOwnerApproval: weakenedApproval,
    });
    assert.equal(weakenedOwnerSummary.releasePolicyExact, false);
    assert.equal(weakenedOwnerSummary.controlledPilotPromotionExact, false);
  }

  for (const weakenInfrastructure of [
    ({backend}) => {
      backend.controlBoundary.serviceAccountsMutated = true;
    },
    ({backend}) => {
      delete backend.controlBoundary.serviceAccountsMutated;
    },
    ({backend}) => {
      backend.controlBoundary.productionBusinessDataMutated = true;
    },
    ({firestore}) => {
      firestore.mutationBoundary.businessDataMutated = true;
    },
    ({receipt}) => {
      receipt.admittedEvidence.productionBackend.receipt =
        "release/evidence/unmeasured-backend.json";
    },
  ]) {
    const weakenedReceipt = structuredClone(promotionReceipt);
    const weakenedBackend = structuredClone(promotionBackendReceipt);
    const weakenedFirestore = structuredClone(promotionFirestoreReceipt);
    weakenInfrastructure({
      receipt: weakenedReceipt,
      backend: weakenedBackend,
      firestore: weakenedFirestore,
    });
    const weakenedInfrastructureSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {entries: [...ledgers, pendingLedger]},
      promotionReceipt: weakenedReceipt,
      ...promotionFinalizationAuthority,
      promotionBackendReceipt: weakenedBackend,
      promotionFirestoreReceipt: weakenedFirestore,
    });
    assert.equal(weakenedInfrastructureSummary.releasePolicyExact, false);
    assert.equal(
      weakenedInfrastructureSummary.controlledPilotPromotionExact,
      false,
    );
  }

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

  for (const insertDuplicate of [
    (entries, duplicate) => [duplicate, ...entries],
    (entries, duplicate) => [...entries, duplicate],
  ]) {
    const duplicatePromotedLedger = {
      buildNumber: completed.buildNumber,
      distributionPerformed: false,
    };
    const duplicatePromotionSummary = summarizeMutableSourceAuthority({
      policy,
      releasePolicy: pendingPolicy,
      buildLedger: {
        entries: insertDuplicate(
          [...ledgers, pendingLedger],
          duplicatePromotedLedger,
        ),
      },
      promotionReceipt,
      ...promotionFinalizationAuthority,
    });
    assert.equal(duplicatePromotionSummary.buildLedgerExact, false);
    assert.equal(duplicatePromotionSummary.releasePolicyExact, false);
    assert.equal(
      duplicatePromotionSummary.controlledPilotPromotionExact,
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
    (receipt) => {
      receipt.promotion.githubActionsArtifactAsDistributionChannelAuthorized =
        true;
    },
    (receipt) => {
      receipt.promotion.appCheckActivationAuthorized = true;
    },
    (receipt) => {
      receipt.closureBoundary.pilotHandoutPerformed = true;
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

test("the fixed Build 11 exception cannot relabel a later promotion", () => {
  const policy = structuredClone(
    require("../../release/lr07-distribution-installation-readback-policy.json"),
  );
  const releasePolicy = structuredClone(
    require("../../release/production-release-policy.json"),
  );
  const buildLedger = structuredClone(
    require("../../release/build-number-ledger.json"),
  );
  const promotionReceipt = structuredClone(
    require("../../release/evidence/build-27-staged-controlled-pilot-authorization.json"),
  );
  const relabeledReceiptSha = "8".repeat(64).toUpperCase();
  promotionReceipt.evidenceType =
    "stage2d-f6-build11-controlled-pilot-authorization";
  promotionReceipt.decision =
    "PASS_LR07_CLOSED_AND_STAGE2D_F6_CONTROLLED_PILOT_AUTHORIZED";
  releasePolicy.postBuildPromotion.status = "completed-controlled-pilot-only";
  releasePolicy.postBuildPromotion.promotionReceiptSha256 = relabeledReceiptSha;
  releasePolicy.distribution.authority =
    "exact-build11-sealed-small-group-pilot";
  releasePolicy.distribution.promotionReceiptSha256 = relabeledReceiptSha;
  buildLedger.entries.find(
    (entry) => entry.buildNumber === 27,
  ).pilotPromotionReceiptSha256 = relabeledReceiptSha;

  const summary = summarizeMutableSourceAuthority({
    policy,
    releasePolicy,
    buildLedger,
    promotionReceipt,
    measuredPromotionReceiptSha256: relabeledReceiptSha,
  });
  assert.equal(summary.releasePolicyExact, false);
  assert.equal(summary.controlledPilotPromotionExact, false);
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

test("PowerShell current and successor sync counters reject missing and nonnumeric evidence", () => {
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1')
    .replaceAll("'", "''");
  const script = `
    $ErrorActionPreference = 'Stop'
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Verifier does not parse' }
    foreach ($name in @('Get-OptionalPropertyValue','Get-UtcEvidenceInstant','Get-BackendChronologyInstantKey','ConvertFrom-BackendReceiptJson','Test-ZeroSynchronizationFailureCounters','Test-CompletedAutomaticSynchronization','Test-ZeroBackendReadbackFailures')) {
      $definition = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
      if ($null -eq $definition) { throw "Missing runtime predicate: $name" }
      Invoke-Expression $definition.Extent.Text
    }
    $healthy = '{"pushFailed":0,"fullSyncConflicts":0,"processingErrors":0,"likelyPermanentRejections":0,"globalPullConflict":0}'
    if (-not (Test-ZeroSynchronizationFailureCounters ($healthy | ConvertFrom-Json))) { throw 'Healthy rejected' }
    foreach ($counter in @('pushFailed','fullSyncConflicts','processingErrors','likelyPermanentRejections','globalPullConflict')) {
      foreach ($badValue in @(1, -1, '0', $null, $false)) {
        $bad = $healthy | ConvertFrom-Json
        $bad.$counter = $badValue
        if (Test-ZeroSynchronizationFailureCounters $bad) { throw "Accepted invalid $counter" }
      }
      $missing = $healthy | ConvertFrom-Json
      $missing.PSObject.Properties.Remove($counter)
      if (Test-ZeroSynchronizationFailureCounters $missing) { throw "Accepted missing $counter" }
    }
    $automatic = '{"automaticStartupSyncPassesObserved":2,"syncStateAtInventory":"idle"}'
    if (-not (Test-CompletedAutomaticSynchronization ($automatic | ConvertFrom-Json))) { throw 'Completed automatic sync rejected' }
    foreach ($badValue in @(0, -1, 0.5, '2', $null, $false)) {
      $bad = $automatic | ConvertFrom-Json
      $bad.automaticStartupSyncPassesObserved = $badValue
      if (Test-CompletedAutomaticSynchronization $bad) { throw 'Accepted absent or invalid automatic pass count' }
    }
    foreach ($badValue in @('running', 'error', 'IDLE', $null)) {
      $bad = $automatic | ConvertFrom-Json
      $bad.syncStateAtInventory = $badValue
      if (Test-CompletedAutomaticSynchronization $bad) { throw 'Accepted incomplete sync inventory' }
    }
    $bad = $automatic | ConvertFrom-Json
    $bad.syncStateAtInventory = @('idle', 'running')
    if (Test-CompletedAutomaticSynchronization $bad) { throw 'Accepted nonscalar sync state' }
    foreach ($field in @('automaticStartupSyncPassesObserved','syncStateAtInventory')) {
      $bad = $automatic | ConvertFrom-Json
      $bad.PSObject.Properties.Remove($field)
      if (Test-CompletedAutomaticSynchronization $bad) { throw "Accepted missing $field" }
    }
    $backend = [IO.File]::ReadAllText('${path.join(repositoryRoot, 'release/evidence/build27-backend-deployment-closure.json').replaceAll("'", "''")}')
    if (-not (Test-ZeroBackendReadbackFailures (ConvertFrom-BackendReceiptJson -Text $backend))) { throw 'Healthy backend rejected' }
    foreach ($path in @('controlBoundary.schedulerSmokeChangedRecordCount','deployment.schedulerSmokeResult.changed','deployment.schedulerSmokeResult.workflowEscalationCandidateCount','cleanMainLiveReadbacks.functionFleet.failedChecks','cleanMainLiveReadbacks.iamDependencies.failedChecks','cleanMainLiveReadbacks.iamDependencies.postureHolds','cleanMainLiveReadbacks.firestoreRulesAndIndexes.failedChecks')) {
      foreach ($badValue in @(1, -1, '0', $null, $false)) {
        $bad = ConvertFrom-BackendReceiptJson -Text $backend
        $parts = $path.Split('.')
        $target = $bad
        foreach ($part in $parts[0..($parts.Length - 2)]) { $target = $target.$part }
        $target.($parts[-1]) = $badValue
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted invalid backend $path" }
        $target.PSObject.Properties.Remove($parts[-1])
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted missing backend $path" }
      }
    }
    foreach ($path in @('deployment.schedulerSmokeResult.invoked','deployment.schedulerBacklogZeroVerified')) {
      foreach ($badValue in @(0, 1, 'false', 'true', $null, @($true, $false))) {
        $bad = ConvertFrom-BackendReceiptJson -Text $backend
        $parts = $path.Split('.')
        $target = $bad
        foreach ($part in $parts[0..($parts.Length - 2)]) { $target = $target.$part }
        $target.($parts[-1]) = $badValue
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted invalid scheduler boundary $path" }
        $target.PSObject.Properties.Remove($parts[-1])
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted missing scheduler boundary $path" }
      }
      $bad = ConvertFrom-BackendReceiptJson -Text $backend
      if ($path.EndsWith('.invoked')) { $bad.deployment.schedulerSmokeResult.invoked = $true }
      else { $bad.deployment.schedulerBacklogZeroVerified = $false }
      if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted adverse scheduler boundary $path" }
    }
    'PASS_RUNTIME_SYNC_COUNTERS'
  `;
  const output = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'});
  assert.match(output, /PASS_RUNTIME_SYNC_COUNTERS/);
});

test("PowerShell rejects duplicate build numbers anywhere in the ledger", () => {
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1')
    .replaceAll("'", "''");
  const script = `
    $ErrorActionPreference = 'Stop'
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Verifier does not parse' }
    $definition = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-UniqueBuildLedgerNumbers'}, $true)
    if ($null -eq $definition) { throw 'Missing whole-ledger uniqueness predicate' }
    Invoke-Expression $definition.Extent.Text
    $healthy = '{"entries":[{"buildNumber":26},{"buildNumber":27},{"buildNumber":28}]}'
    if (-not (Test-UniqueBuildLedgerNumbers ($healthy | ConvertFrom-Json))) { throw 'Unique ledger rejected' }
    foreach ($number in @(26, 27, 28)) {
      $bad = $healthy | ConvertFrom-Json
      $bad.entries += [pscustomobject]@{buildNumber=$number; distributionPerformed=$true}
      if (Test-UniqueBuildLedgerNumbers $bad) { throw "Accepted duplicate build $number" }
    }
    foreach ($number in @('26', $null, $false, 0, -1, 26.5, 2147483648)) {
      $bad = $healthy | ConvertFrom-Json
      $bad.entries[0].buildNumber = $number
      if (Test-UniqueBuildLedgerNumbers $bad) { throw 'Accepted invalid ledger identity' }
    }
    $bad = $healthy | ConvertFrom-Json
    $bad.entries[0].PSObject.Properties.Remove('buildNumber')
    if (Test-UniqueBuildLedgerNumbers $bad) { throw 'Accepted missing ledger identity' }
    'PASS_WHOLE_LEDGER_UNIQUENESS'
  `;
  const output = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'});
  assert.match(output, /PASS_WHOLE_LEDGER_UNIQUENESS/);
});

const backendChronologyFields = [
  'ownerInstructionReceivedAtUtc', 'earliestFunctionUpdateTime', 'latestFunctionUpdateTime',
];
const backendChronologyBadCases = backendChronologyFields.flatMap((field) =>
  [null, false, 0, [], '', 'not-a-time', '2026-02-30T00:00:00Z',
    '2026-09-08T00:48:30.433', '2026-09-08T00:48:30.433+00:00']
    .map((value) => ({field, value})),
).concat([
  {field: 'ownerInstructionReceivedAtUtc', value: '2026-09-08T01:00:00Z'},
  {field: 'earliestFunctionUpdateTime', value: '2026-09-08T01:00:00Z'},
  {field: 'latestFunctionUpdateTime', value: '2026-09-08T00:49:00Z'},
]);

test('measured backend chronology must prove authorization before ordered updates', () => {
  const healthy = measuredPromotionFixture();
  assert.equal(summarizeMutableSourceAuthority(healthy).controlledPilotPromotionExact, true);
  for (const {field, value} of backendChronologyBadCases) {
    const input = structuredClone(healthy);
    input.promotionBackendReceipt.authorityChronology[field] = value;
    rebindMeasuredReceipt(input);
    assert.equal(summarizeMutableSourceAuthority(input).controlledPilotPromotionExact, false,
      `${field}: ${JSON.stringify(value)}`);
  }
  for (const field of backendChronologyFields) {
    const input = structuredClone(healthy);
    delete input.promotionBackendReceipt.authorityChronology[field];
    rebindMeasuredReceipt(input);
    assert.equal(summarizeMutableSourceAuthority(input).controlledPilotPromotionExact, false, `missing ${field}`);
  }
  const equal = structuredClone(healthy);
  for (const field of backendChronologyFields) {
    equal.promotionBackendReceipt.authorityChronology[field] = '2026-09-08T00:48:30.433Z';
  }
  rebindMeasuredReceipt(equal);
  assert.equal(summarizeMutableSourceAuthority(equal).controlledPilotPromotionExact, true);
});

test('PowerShell backend chronology must prove authorization before ordered updates', () => {
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1').replaceAll("'", "''");
  const backendPath = path.join(repositoryRoot, 'release/evidence/build27-backend-deployment-closure.json').replaceAll("'", "''");
  const script = `
    $ErrorActionPreference = 'Stop'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$null, [ref]$null)
    foreach ($name in @('Get-OptionalPropertyValue','Get-UtcEvidenceInstant','Get-BackendChronologyInstantKey','ConvertFrom-BackendReceiptJson','Test-ZeroBackendReadbackFailures')) {
      $definition = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
      Invoke-Expression $definition.Extent.Text
    }
    $healthy = [IO.File]::ReadAllText('${backendPath}')
    if (-not (Test-ZeroBackendReadbackFailures (ConvertFrom-BackendReceiptJson -Text $healthy))) { throw 'Healthy chronology rejected' }
    $cases = '${JSON.stringify(backendChronologyBadCases)}' | ConvertFrom-Json
    foreach ($case in $cases) {
      $bad = ConvertFrom-BackendReceiptJson -Text $healthy
      $bad.authorityChronology.($case.field) = $case.value
      if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted chronology $($case.field): $($case.value)" }
    }
    foreach ($field in @('ownerInstructionReceivedAtUtc','earliestFunctionUpdateTime','latestFunctionUpdateTime')) {
      $bad = ConvertFrom-BackendReceiptJson -Text $healthy
      $bad.authorityChronology.PSObject.Properties.Remove($field)
      if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted missing chronology $field" }
    }
    $equal = ConvertFrom-BackendReceiptJson -Text $healthy
    foreach ($field in @('ownerInstructionReceivedAtUtc','earliestFunctionUpdateTime','latestFunctionUpdateTime')) {
      $equal.authorityChronology.$field = '2026-09-08T00:48:30.433Z'
    }
    if (-not (Test-ZeroBackendReadbackFailures $equal)) { throw 'Equal ordered timestamps rejected' }
    'PASS_MEASURED_BACKEND_CHRONOLOGY'
  `;
  const output = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'});
  assert.match(output, /PASS_MEASURED_BACKEND_CHRONOLOGY/);
});

test('backend chronology rejects scalar coercion and preserves nanosecond order', () => {
  const healthy = measuredPromotionFixture();
  const scalarArray = structuredClone(healthy);
  scalarArray.promotionBackendReceipt.authorityChronology.ownerInstructionReceivedAtUtc =
    [healthy.promotionBackendReceipt.authorityChronology.ownerInstructionReceivedAtUtc];
  const reversed = structuredClone(healthy);
  reversed.promotionBackendReceipt.authorityChronology.earliestFunctionUpdateTime = '2026-09-08T00:50:50.123456789Z';
  reversed.promotionBackendReceipt.authorityChronology.latestFunctionUpdateTime = '2026-09-08T00:50:50.123456788Z';
  for (const input of [scalarArray, reversed]) {
    rebindMeasuredReceipt(input);
    assert.equal(summarizeMutableSourceAuthority(input).controlledPilotPromotionExact, false);
  }
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1').replaceAll("'", "''");
  const backendPath = path.join(repositoryRoot, 'release/evidence/build27-backend-deployment-closure.json').replaceAll("'", "''");
  const script = `
    $ErrorActionPreference = 'Stop'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$null, [ref]$null)
    foreach ($name in @('Get-OptionalPropertyValue','Get-UtcEvidenceInstant','Get-BackendChronologyInstantKey','ConvertFrom-BackendReceiptJson','Test-ZeroBackendReadbackFailures')) {
      $definition = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
      Invoke-Expression $definition.Extent.Text
    }
    $healthy = [IO.File]::ReadAllText('${backendPath}')
    $reversed = ConvertFrom-BackendReceiptJson -Text $healthy
    $reversed.authorityChronology.earliestFunctionUpdateTime = '2026-09-08T00:50:50.123456789Z'
    $reversed.authorityChronology.latestFunctionUpdateTime = '2026-09-08T00:50:50.123456788Z'
    $reversed = ConvertFrom-BackendReceiptJson -Text ($reversed | ConvertTo-Json -Depth 20)
    if (Test-ZeroBackendReadbackFailures $reversed) { throw 'Accepted reverse nanosecond order' }
    $array = ConvertFrom-BackendReceiptJson -Text $healthy
    $array.authorityChronology.ownerInstructionReceivedAtUtc = @('2026-09-08T00:48:30.433Z')
    if (Test-ZeroBackendReadbackFailures $array) { throw 'Accepted timestamp array' }
    'PASS_SCALAR_NANOSECOND_CHRONOLOGY'
  `;
  assert.match(execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'}),
    /PASS_SCALAR_NANOSECOND_CHRONOLOGY/);
});

test('PowerShell rejects every measured backend authorization/readback contradiction', () => {
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1').replaceAll("'", "''");
  const backendPath = path.join(repositoryRoot, 'release/evidence/build27-backend-deployment-closure.json').replaceAll("'", "''");
  const cases = backendClosureDecisions.map(([field, expected]) => ({
    field,
    badValues: typeof expected === 'boolean' ?
      [!expected, String(expected), 0, 1, null, [expected]] :
      ['FAIL', expected === expected.toUpperCase() ? expected.toLowerCase() : expected.toUpperCase(), false, null, [expected]],
  }));
  const script = `
    $ErrorActionPreference = 'Stop'
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Verifier does not parse' }
    foreach ($name in @('Get-OptionalPropertyValue','Get-UtcEvidenceInstant','Get-BackendChronologyInstantKey','ConvertFrom-BackendReceiptJson','Test-ZeroBackendReadbackFailures')) {
      $definition = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
      if ($null -eq $definition) { throw "Missing predicate: $name" }
      Invoke-Expression $definition.Extent.Text
    }
    $healthy = [IO.File]::ReadAllText('${backendPath}')
    if (-not (Test-ZeroBackendReadbackFailures (ConvertFrom-BackendReceiptJson -Text $healthy))) { throw 'Healthy measured backend rejected' }
    $cases = '${JSON.stringify(cases)}' | ConvertFrom-Json
    foreach ($case in $cases) {
      foreach ($badValue in $case.badValues) {
        $bad = ConvertFrom-BackendReceiptJson -Text $healthy
        $parts = $case.field.Split('.')
        $target = $bad
        foreach ($part in $parts[0..($parts.Length - 2)]) { $target = $target.$part }
        $target.($parts[-1]) = $badValue
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted contradictory backend $($case.field)" }
        $target.PSObject.Properties.Remove($parts[-1])
        if (Test-ZeroBackendReadbackFailures $bad) { throw "Accepted missing backend $($case.field)" }
      }
    }
    'PASS_MEASURED_BACKEND_CLOSURE_DECISIONS'
  `;
  const output = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'});
  assert.match(output, /PASS_MEASURED_BACKEND_CLOSURE_DECISIONS/);
});

test('PowerShell promotion and custody guards reject contradictory measured verdicts', () => {
  const verifierPath = path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1').replaceAll("'", "''");
  const policyPath = path.join(repositoryRoot, 'release/production-release-policy.json').replaceAll("'", "''");
  const rootPath = repositoryRoot.replaceAll("'", "''");
  const cases = promotionAndCustodyDecisions.map(([receiptKey, field, expected]) => ({
    receiptKey, field,
    badValues: typeof expected === 'boolean' ?
      [!expected, String(expected), 0, null, [expected]] :
      ['FAIL', expected === expected.toUpperCase() ? expected.toLowerCase() : expected.toUpperCase(), false, null, [expected]],
  }));
  const script = `
    $ErrorActionPreference = 'Stop'
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${verifierPath}', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Verifier does not parse' }
    $promotionGuard = $ast.Find({param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Extent.Text.Contains("throw 'Post-build promotion exceeds or differs from the exact staged-pilot boundary.'")}, $true)
    $custodyGuard = $ast.Find({param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Extent.Text.Contains("throw 'Promoted build retained finalization authority is incomplete or divergent.'")}, $true)
    if ($null -eq $promotionGuard -or $null -eq $custodyGuard) { throw 'Missing measured receipt guard' }
    $policy = [IO.File]::ReadAllText('${policyPath}') | ConvertFrom-Json
    $promotionReceiptPath = $policy.postBuildPromotion.promotionReceiptFile
    $promotionJson = [IO.File]::ReadAllText((Join-Path '${rootPath}' $promotionReceiptPath))
    $promotionReceipt = $promotionJson | ConvertFrom-Json
    $promotionBuildNumber = $policy.postBuildPromotion.buildNumber
    $approvedPilotBuildNumber = $policy.distribution.approvedBuildNumber
    $promotionAuthorityBuild = $promotionReceipt.admittedEvidence.governedBuild
    $expectedPromotionDecision = "PASS_BUILD$($promotionBuildNumber)_STAGED_CONTROLLED_PILOT_AUTHORIZED"
    $finalizationJson = [IO.File]::ReadAllText((Join-Path '${rootPath}' $promotionAuthorityBuild.finalizationReceipt))
    $promotionFinalizationReceipt = $finalizationJson | ConvertFrom-Json
    Invoke-Expression $promotionGuard.Extent.Text
    Invoke-Expression $custodyGuard.Extent.Text
    $cases = '${JSON.stringify(cases)}' | ConvertFrom-Json
    foreach ($case in $cases) {
      foreach ($badValue in $case.badValues) {
        $promotionReceipt = $promotionJson | ConvertFrom-Json
        $promotionFinalizationReceipt = $finalizationJson | ConvertFrom-Json
        $target = if ($case.receiptKey -eq 'Receipt') { $promotionReceipt } else { $promotionFinalizationReceipt }
        $guard = if ($case.receiptKey -eq 'Receipt') { $promotionGuard } else { $custodyGuard }
        $parts = $case.field.Split('.')
        foreach ($part in $parts[0..($parts.Length - 2)]) { $target = $target.$part }
        $target.($parts[-1]) = $badValue
        $rejected = $false
        try { Invoke-Expression $guard.Extent.Text } catch { $rejected = $true }
        if (-not $rejected) { throw "Accepted contradictory verdict $($case.field)" }
        $target.PSObject.Properties.Remove($parts[-1])
        $rejected = $false
        try { Invoke-Expression $guard.Extent.Text } catch { $rejected = $true }
        if (-not $rejected) { throw "Accepted missing verdict $($case.field)" }
      }
    }
    'PASS_MEASURED_PROMOTION_CUSTODY_DECISIONS'
  `;
  const output = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {encoding: 'utf8'});
  assert.match(output, /PASS_MEASURED_PROMOTION_CUSTODY_DECISIONS/);
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
