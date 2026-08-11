import assert from "node:assert/strict";
import test from "node:test";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  adjudicateReadback,
  parseArgs,
  selectProductionArtifacts,
  summarizeMutableSourceAuthority,
} = require("./collectDistributionInstallationReadback.js");

function fixture() {
  const build8 = {
    buildNumber: 8,
    workflowRunId: 30839125687,
    headSha: "731a02980d38e4e3a8f61ff2bca74a1e85771478",
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

test("preserved Build 8 authority admits only a source-reserved successor", () => {
  const expected = {
    buildNumber: 8,
    id: 80,
    name: "build-8",
    sizeBytes: 800,
    digest: `sha256:${"8".repeat(64)}`,
    workflowRunId: 808,
    headSha: "8".repeat(40),
    ledgerDisposition: "successful-build-finalized-non-distributable",
    dualCustodyCompleted: true,
  };
  const receiptPath =
    "release/evidence/build-8-finalization-closure.json";
  const receiptSha256 = "c".repeat(64).toUpperCase();
  const packageSha256 = "a".repeat(64).toUpperCase();
  const policy = {
    repository: "abhishekvatsa/crm3_baf_ops",
    productionProjectId: "crm3-baf-ops-b8638",
    applicationId: "in.co.sail.bsl.crm3.bafops",
    expectedArtifactsForContainment: [expected],
    sourceEvidence: [
      {path: receiptPath, sha256: receiptSha256},
    ],
    installationReceipt: {governedPackageSha256: packageSha256},
  };
  const releasePolicy = {
    firebaseProjectId: policy.productionProjectId,
    permanentApplicationId: policy.applicationId,
    github: {
      repository: policy.repository,
      environmentReviewControl: {repositoryVisibility: "public"},
    },
    release: {buildNumber: 9},
    finalization: {
      status: "pending-source-authorized",
      priorCompletedBuild: {
        buildNumber: 8,
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
  const build8Ledger = {
    buildNumber: 8,
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
  const build9Ledger = {
    buildNumber: 9,
    status: "source-reserved-awaiting-remote-consumption",
  };

  const exact = summarizeMutableSourceAuthority({
    policy,
    releasePolicy,
    buildLedger: {entries: [build8Ledger, build9Ledger]},
  });
  assert.deepEqual(exact, {
    releasePolicyExact: true,
    buildLedgerExact: true,
  });

  const malformedPrior = structuredClone(releasePolicy);
  delete malformedPrior.finalization.priorCompletedBuild.completionReceiptSha256;
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy: malformedPrior,
      buildLedger: {entries: [build8Ledger, build9Ledger]},
    }).releasePolicyExact,
    false,
  );

  const artifactBearingSuccessor = {
    ...build9Ledger,
    status: "remote-consumed-artifact-built",
    githubArtifactId: 90,
  };
  assert.equal(
    summarizeMutableSourceAuthority({
      policy,
      releasePolicy,
      buildLedger: {entries: [build8Ledger, artifactBearingSuccessor]},
    }).buildLedgerExact,
    false,
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
