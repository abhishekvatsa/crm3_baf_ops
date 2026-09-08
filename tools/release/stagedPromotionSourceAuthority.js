"use strict";

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");

const PROJECT = "crm3-baf-ops-b8638";
const DEPLOYED = "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK";
const SHA256 = /^[0-9a-f]{64}$/i;
const COMMIT = /^[0-9a-f]{40}$/i;

function requireEvidence(condition, message) {
  if (!condition) throw new Error(message);
}

function sameHash(left, right) {
  return typeof left === "string" && typeof right === "string" &&
    SHA256.test(left) && SHA256.test(right) &&
    left.toUpperCase() === right.toUpperCase();
}

function inside(root, target) {
  const relative = path.relative(root, target);
  return relative !== "" && relative !== ".." &&
    !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function readChild(repoRoot, file, expectedHash, label) {
  requireEvidence(typeof file === "string" && file.length > 0 &&
    !path.isAbsolute(file) && !path.win32.isAbsolute(file) &&
    !file.includes(":") && !file.split(/[\\/]/).includes(".."),
  `${label}: path must stay inside the repository.`);
  const absolute = path.resolve(repoRoot, file);
  requireEvidence(inside(repoRoot, absolute), `${label}: path escapes the repository.`);
  const real = fs.realpathSync(absolute);
  requireEvidence(inside(repoRoot, real), `${label}: resolved path escapes the repository.`);
  const bytes = fs.readFileSync(real);
  const hash = crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
  if (expectedHash !== undefined) {
    requireEvidence(sameHash(hash, expectedHash), `${label}: physical SHA-256 differs from authority.`);
  }
  const value = JSON.parse(bytes.toString("utf8").replace(/^\uFEFF/, ""));
  requireEvidence(value !== null && typeof value === "object" && !Array.isArray(value),
    `${label}: expected a JSON object.`);
  return {value, hash};
}

function commitTree(repoRoot, commit, label) {
  requireEvidence(typeof commit === "string" && COMMIT.test(commit),
    `${label}: source commit must be exactly 40 hexadecimal characters.`);
  const tree = execFileSync("git", ["-C", repoRoot, "rev-parse", "--verify", `${commit}^{tree}`],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  requireEvidence(COMMIT.test(tree), `${label}: source tree could not be verified.`);
  return tree;
}

function verifyDeployment(receipt, label) {
  requireEvidence(receipt.firebaseProjectId === PROJECT && receipt.decision === DEPLOYED &&
    receipt.deployment?.functionCount === 15 &&
    receipt.deployment?.allFunctionsExactSourceVerified === true &&
    receipt.deployment?.finalRuntimeIdentityReadbackPassed === true &&
    receipt.deployment?.finalIamDependencyReadbackPassed === true &&
    receipt.controlBoundary?.productionBusinessDataMutated === false &&
    receipt.controlBoundary?.distributionPerformed === false,
  `${label}: exact deployment evidence is incomplete.`);
}

/**
 * Local, read-only authority verification for the staged-promotion collector.
 * Call only for staged promotions. A successor checkout need not be deployed:
 * neither HEAD nor the finalized APK source is the backend source authority.
 */
function verifyStagedPromotionSourceAuthority({repoRoot, releasePolicy}) {
  try {
    const root = fs.realpathSync(repoRoot);
    requireEvidence(releasePolicy?.firebaseProjectId === PROJECT,
      "Release policy: Firebase project differs from production authority.");
    const versionPolicy = releasePolicy.versionPolicy;
    requireEvidence(SHA256.test(versionPolicy?.sourceDocumentSha256 ?? ""),
      "Version source: physical SHA-256 authority is absent.");
    const version = readChild(root, versionPolicy.sourceDocumentFile,
      versionPolicy.sourceDocumentSha256, "Version source").value;
    const required = version.requiredSource;
    const finalization = releasePolicy.finalization;
    requireEvidence(required?.exactFunctionFleetDeploymentReceiptFile ===
      finalization?.exactFunctionFleetDeploymentReceiptFile &&
      sameHash(required?.exactFunctionFleetDeploymentReceiptSha256,
        finalization?.exactFunctionFleetDeploymentReceiptSha256),
    "Historical backend: finalization and version-source receipt authorities differ.");
    const historicalRead = readChild(root, finalization.exactFunctionFleetDeploymentReceiptFile,
      finalization.exactFunctionFleetDeploymentReceiptSha256, "Historical backend");
    const historical = historicalRead.value;
    const expectedCommit = required.exactFunctionFleetDeploymentSourceCommit ?? version.sourceBaseline?.commit;
    const expectedPr = required.exactFunctionFleetDeploymentPullRequest ?? 265;
    requireEvidence(Number.isSafeInteger(expectedPr) && expectedPr > 0,
      "Historical backend: deployment pull request is invalid.");
    const expectedTree = commitTree(root, expectedCommit, "Historical backend");
    verifyDeployment(historical, "Historical backend");
    requireEvidence(historical.sourceAuthority?.commit === expectedCommit &&
      historical.sourceAuthority?.tree === expectedTree &&
      historical.sourceAuthority?.pullRequestNumber === expectedPr,
    "Historical backend: deployed commit, Git tree or pull request differs from version authority.");

    const state = readChild(root, "release/current-successor-state.json", undefined,
      "Current successor state").value;
    const deployed = state.authorityPlanes?.deployedBackend;
    requireEvidence(deployed && SHA256.test(deployed.functionFleetEvidenceSha256 ?? "") &&
      SHA256.test(deployed.deploymentApprovalSha256 ?? ""),
    "Current backend: receipt or approval SHA-256 authority is absent.");
    const current = readChild(root, deployed.functionFleetEvidenceFile,
      deployed.functionFleetEvidenceSha256, "Current backend");
    const receipt = current.value;
    const approval = readChild(root, deployed.deploymentApprovalFile,
      deployed.deploymentApprovalSha256, "Backend approval").value;
    verifyDeployment(receipt, "Current backend");
    const currentTree = commitTree(root, deployed.functionFleetSourceCommit, "Current backend");
    requireEvidence(receipt.sourceAuthority?.commit === deployed.functionFleetSourceCommit &&
      receipt.sourceAuthority?.tree === currentTree &&
      approval.approved === true && approval.firebaseProjectId === PROJECT &&
      approval.sourceAuthority?.commit === receipt.sourceAuthority.commit &&
      approval.approvedDeployment?.preserveExistingIamRequired === true &&
      approval.approvedDeployment?.appCheckEnforcement === false &&
      receipt.approvalAuthority?.file === deployed.deploymentApprovalFile &&
      sameHash(receipt.approvalAuthority?.sha256, deployed.deploymentApprovalSha256) &&
      receipt.deployment.existingIamPreservationEnforced === true &&
      receipt.deployment.appCheckEnforcement === false &&
      receipt.controlBoundary.iamMutated === false &&
      receipt.controlBoundary.artifactConstructed === false,
    "Current backend: source, approval or preserved control boundary differs from authority.");

    for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
      const authority = receipt.cleanMainLiveReadbacks?.[key];
      requireEvidence(authority && SHA256.test(authority.physicalSha256 ?? ""),
        `${key}: physical SHA-256 authority is absent.`);
      const child = readChild(root, authority.file, authority.physicalSha256, key).value;
      verifyReceiptSeal(child, key);
      requireEvidence(sameHash(authority.canonicalReceiptSha256, child.receiptSha256),
        `${key}: canonical seal differs from parent authority.`);
    }
    return {ok: true, reasons: [],
      historicalBackendReceiptFile: finalization.exactFunctionFleetDeploymentReceiptFile,
      historicalBackendReceiptSha256: historicalRead.hash,
      currentBackendReceiptFile: deployed.functionFleetEvidenceFile,
      currentBackendReceiptSha256: current.hash};
  } catch (error) {
    return {ok: false, reasons: [error instanceof Error ? error.message : String(error)]};
  }
}

module.exports = {verifyStagedPromotionSourceAuthority};
