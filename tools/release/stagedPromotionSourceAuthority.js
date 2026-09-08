"use strict";

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const {verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const fleetReadback = require("./collectFunctionFleetRuntimeIdentityReadback.js");
const iamReadback = require("./collectFunctionsIamDependenciesReadback.js");
const firestoreReadback = require("./collectFirestoreRulesIndexesReadback.js");

const PROJECT = "crm3-baf-ops-b8638";
const DEPLOYED = "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK";
const SHA256 = /^[0-9a-f]{64}$/i;
const COMMIT = /^[0-9a-f]{40}$/i;
// The completed Build27 governance gate recorded in
// docs/v4_2_r1/BUILD27_STAGED_CONTROLLED_PILOT_PROMOTION.md and its device receipt.
// This authority belongs to the retained artifact; a successor HEAD is permitted.
const BUILD27_GOVERNANCE = Object.freeze({
  repository: "abhishekvatsa/crm3_baf_ops",
  commit: "41adfaecd7974f3f48b9f023a90890c860ab44af",
  tree: "249c6c1555d422cd0ac43384a47b34b2743c5804",
  runId: 34187627918,
  requiredJobCount: 5,
});
// The owner-designated PR snapshot retains the separate pilot instruction.
// Unlike the backend's merged main authority, this is approval custody in the
// explicitly designated proposal snapshot. New approvals require new anchors.
const BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT = "d95e399de07d43051d94debf36098e7998fe76d4";
const BUILD27_PROMOTION_RECEIPT_PATH = "release/evidence/build-27-staged-controlled-pilot-authorization.json";

function promotionCiAuthorityExact(promotionReceipt, deviceReceipt) {
  const source = promotionReceipt?.sourceAuthority;
  const ci = source?.postMergeCi;
  const device = deviceReceipt?.sourceAndCiAuthority;
  const expected = BUILD27_GOVERNANCE;
  return source?.repository === expected.repository &&
    typeof source?.artifactSourceCommit === "string" && COMMIT.test(source.artifactSourceCommit) &&
    source.artifactSourceCommit === promotionReceipt?.admittedEvidence?.governedBuild?.sourceCommit &&
    source?.governanceMainCommit === expected.commit && source?.governanceMainTree === expected.tree &&
    ci?.headSha === expected.commit && ci?.runId === expected.runId &&
    ci?.conclusion === "success" && ci?.requiredJobCount === expected.requiredJobCount &&
    ci?.allRequiredJobsPassed === true &&
    device?.governanceMainCommit === expected.commit && device?.governanceMainTree === expected.tree &&
    device?.postMergeReleaseGateHeadSha === expected.commit && device?.postMergeReleaseGateRunId === expected.runId &&
    device?.postMergeReleaseGateConclusion === "success" && device?.requiredJobCount === expected.requiredJobCount &&
    device?.allRequiredJobsPassed === true;
}

function explicitUtcInstant(value) {
  if (typeof value !== "string") return null;
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  if (match == null || match[1].startsWith("0000-")) return null;
  const seconds = Date.parse(`${match[1]}Z`);
  if (!Number.isFinite(seconds) || new Date(seconds).toISOString().slice(0, 19) !== match[1]) return null;
  return BigInt(seconds) * 1000000n + BigInt((match[2] ?? "").padEnd(9, "0"));
}

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
  const tree = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "--verify", `${commit}^{tree}`],
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

function gitSourceValue(repoRoot, commit, file) {
  return execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "show", `${commit}:${file}`],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
}

function readApprovalCustody(repoRoot, commit, authority, label) {
  const bytes = gitSourceValue(repoRoot, commit, authority.file);
  const hash = crypto.createHash("sha256").update(bytes, "utf8").digest("hex").toUpperCase();
  requireEvidence(sameHash(hash, authority.sha256), `${label}: committed approval custody digest differs.`);
  return {file: authority.file, sha256: hash};
}

function requireApprovalCustody(receiptAuthority, measuredApproval, custody, label) {
  requireEvidence(receiptAuthority?.file === custody.file &&
    sameHash(receiptAuthority?.sha256, custody.sha256) && sameHash(measuredApproval.hash, custody.sha256),
  `${label}: approval differs from immutable owner-instruction custody.`);
}

function verifyApproval(repoRoot, receipt, approval) {
  const source = receipt.sourceAuthority;
  const admitted = approval.sourceAuthority;
  const scope = approval.approvedDeployment;
  const approvedAt = explicitUtcInstant(approval.approvedAtUtc);
  const ownerAt = explicitUtcInstant(receipt.authorityChronology?.ownerInstructionReceivedAtUtc);
  const earliest = explicitUtcInstant(receipt.authorityChronology?.earliestFunctionUpdateTime);
  const latest = explicitUtcInstant(receipt.authorityChronology?.latestFunctionUpdateTime);
  const functionTree = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "--verify", `${source.commit}:functions`],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  requireEvidence(approval.schemaVersion === 1 &&
    approval.documentType === "governed-current-source-backend-deployment-approval" &&
    approval.approved === true && approval.firebaseProjectId === PROJECT &&
    approval.region === "asia-south1" && receipt.region === approval.region &&
    approval.approvalEvidence?.authorityType === "project-owner instruction" &&
    approvedAt != null && ownerAt === approvedAt &&
    explicitUtcInstant(approval.approvalEvidence.messageReceivedAtUtc) === approvedAt &&
    earliest != null && latest != null && ownerAt <= earliest && earliest <= latest &&
    receipt.authorityChronology.allObservedFunctionUpdatesPostdateOwnerInstruction === true &&
    receipt.authorityChronology.deploymentWasRetroactivelyAuthorized === false &&
    admitted?.commit === source.commit && admitted?.tree === source.tree &&
    COMMIT.test(functionTree) && admitted?.functionTree === functionTree &&
    source.functionsGitObjectId === functionTree &&
    Number.isSafeInteger(admitted?.pullRequestNumber) && admitted.pullRequestNumber > 0 &&
    admitted.pullRequestNumber === source.pullRequestNumber &&
    Number.isSafeInteger(admitted.requiredPostMergeReleaseGateRunId) &&
    admitted.requiredPostMergeReleaseGateRunId > 0 &&
    admitted.requiredPostMergeReleaseGateRunId === source.postMergeReleaseGateRunId &&
    source.postMergeReleaseGateConclusion === "success" &&
    scope?.functionCount === 15 && scope.functionCount === receipt.deployment.functionCount &&
    scope.existingDedicatedServiceAccountsRequired === true &&
    scope.preserveExistingIamRequired === true && scope.appCheckEnforcement === false &&
    scope.scheduledFunctionDeploymentAuthorized === true && receipt.deployment.schedulerCount === 1 &&
    scope.scheduledFunctionManualInvocationAuthorized === false &&
    receipt.deployment.schedulerSmokeResult?.invoked === false &&
    scope.firestoreRulesMutationAuthorized === false &&
    sameHash(scope.firestoreRulesSha256, receipt.firestoreDeployment?.rulesSha256) &&
    receipt.firestoreDeployment?.rulesDeploymentPerformed === false &&
    scope.firestoreIndexMutationAuthorized === false &&
    Number.isSafeInteger(scope.firestoreIndexCount) && scope.firestoreIndexCount > 0 &&
    scope.firestoreIndexCount === receipt.firestoreDeployment?.indexCount &&
    sameHash(scope.firestoreIndexSetSha256, receipt.firestoreDeployment?.indexSetSha256) &&
    scope.strictLiveReadbackRequired === true && receipt.firestoreDeployment?.strictLiveReadbackPassed === true &&
    scope.postMergeReleaseGateMustPassBeforeDeployment === true &&
    ["iamMutated", "serviceAccountsMutated", "appCheckActivated", "productionBusinessDataMutated",
      "firestoreDocumentsWritten", "schedulerManuallyInvoked", "deviceDataMutated", "artifactConstructed",
      "pilotPromotionPerformed", "distributionPerformed", "securityRulesMutated", "indexesMutated"]
      .every((field) => receipt.controlBoundary?.[field] === false),
  "Backend approval: source, owner authorization, schedule or deployment scope differs from measured authority.");
}

function verifyReadbackDecision(repoRoot, receipt, key, child) {
  const source = receipt.sourceAuthority;
  requireEvidence([child.source?.before, child.source?.after].every((point) =>
    point?.commit === source.commit && point?.tree === source.tree &&
    point?.originMain === source.commit && point?.branch === "main" &&
    point?.governedWorktreeClean === true && point?.materialChangeCount === 0 &&
    Array.isArray(point?.materialPathSha256) && point.materialPathSha256.length === 0),
  `${key}: measured source does not match the exact deployed clean main tree.`);
  if (key === "firestoreRulesAndIndexes") {
    const {rules, indexes} = child.outputs;
    const rulesRaw = gitSourceValue(repoRoot, source.commit, "firestore.rules");
    const indexRaw = gitSourceValue(repoRoot, source.commit, "firestore.indexes.json");
    const binding = firestoreReadback.sourceIndexSetBinding(JSON.parse(indexRaw), indexRaw);
    requireEvidence(sameHash(rules.sourceSha256, firestoreReadback.sha256(rulesRaw)) &&
      rules.sourceByteCount === Buffer.byteLength(rulesRaw) &&
      sameHash(rules.sourceSha256, receipt.firestoreDeployment?.rulesSha256) &&
      indexes.sourceCount === binding.count && indexes.sourceCount === receipt.firestoreDeployment?.indexCount &&
      sameHash(indexes.sourceSetSha256, binding.indexSetSha256) &&
      sameHash(indexes.sourceSetSha256, receipt.firestoreDeployment?.indexSetSha256) &&
      indexes.sourceFieldOverrideCount === binding.fieldOverrideCount &&
      sameHash(indexes.sourceFieldOverrideSha256, binding.fieldOverrideSetSha256),
    `${key}: rules or index definitions differ from the deployed Git source and parent receipt.`);
    const result = firestoreReadback.adjudicateReadback({projectId: PROJECT,
      sourceBefore: child.source.before, sourceAfter: child.source.after, rules, indexes, observe: false});
    requireEvidence(result.failedChecks.length === 0 && Object.values(result.evidence.checks).every((value) => value === true) &&
      ["schemaVersion", "evidenceType", "mode", "projectId", "decision", "failedChecks", "checks", "mutationBoundary", "privacyBoundary"]
        .every((field) => isDeepStrictEqual(child[field], result.evidence[field])),
    `${key}: decision, checks or boundaries do not match successful adjudication of measured evidence.`);
    return;
  }
  const collector = key === "functionFleet" ? fleetReadback : iamReadback;
  // Replay pure adjudication using the deployed policy, never a successor checkout's policy.
  const policy = JSON.parse(gitSourceValue(repoRoot, source.commit, collector.POLICY_PATH));
  const outputs = child.outputs;
  const sourceExports = key === "functionFleet"
    ? Object.keys(policy.functionBindings).sort() : [...policy.sourceFunctionExports].sort();
  const updates = outputs.functions.map((record) => explicitUtcInstant(record.updateTime));
  requireEvidence(typeof receipt.deployment.sourceRuntimeHash === "string" &&
    COMMIT.test(receipt.deployment.sourceRuntimeHash) &&
    outputs.functions.every((record) => record.firebaseFunctionsHash === receipt.deployment.sourceRuntimeHash) &&
    updates.length === 15 && updates.every((value) => value != null) &&
    updates.reduce((left, right) => left < right ? left : right) ===
      explicitUtcInstant(receipt.authorityChronology.earliestFunctionUpdateTime) &&
    updates.reduce((left, right) => left > right ? left : right) ===
      explicitUtcInstant(receipt.authorityChronology.latestFunctionUpdateTime),
  `${key}: measured function source hashes or update times differ from the owner-authorized deployment.`);
  let sourceDependencies;
  if (key === "iamDependencies") {
    sourceDependencies = iamReadback.summarizePackageState({
      packageJsonRaw: gitSourceValue(repoRoot, source.commit, "functions/package.json"),
      packageLockRaw: gitSourceValue(repoRoot, source.commit, "functions/package-lock.json"),
      trackedPackages: policy.trackedRuntimePackages,
    });
    requireEvidence(isDeepStrictEqual(outputs.currentSourceDependencies, sourceDependencies),
      `${key}: dependency inventory does not match the deployed Git manifests.`);
  }
  const common = {projectId: PROJECT, region: "asia-south1", policy,
    sourceBefore: child.source.before, sourceAfter: child.source.after};
  const result = key === "functionFleet"
    ? collector.adjudicateReadback({...common, phase: "final", probeCallables: true,
      discoveredSourceExports: sourceExports,
      live: {...outputs, backlog: outputs.schedulerBacklog,
        emailMap: collector.accountEmailMap(policy, PROJECT),
        expectedRoles: collector.expectedProjectRoles(policy, PROJECT)}})
    : collector.adjudicateReadback({...common, observe: false,
      project: outputs.project, iam: outputs.iam, functions: outputs.functions,
      currentDependencies: sourceDependencies,
      discoveredSourceExports: sourceExports});
  const evidence = result.evidence;
  const fields = ["schemaVersion", "evidenceType", "projectId", "region", "decision", "failedChecks",
    "checks", "posture", "mutationBoundary", "privacyBoundary"];
  fields.push(...(key === "functionFleet" ? ["phase"] : ["mode", "gateIds", "closureScope"]));
  requireEvidence(result.failedChecks.length === 0 &&
    (key !== "iamDependencies" || isDeepStrictEqual(outputs.discoveredSourceFunctionExports, sourceExports)) &&
    Object.values(evidence.checks).every((value) => value === true) &&
    (key !== "iamDependencies" || (evidence.posture.holds.length === 0 &&
      evidence.posture.decision === "PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE")) &&
    fields.every((field) => isDeepStrictEqual(child[field], evidence[field])),
  `${key}: decision, checks, posture or boundaries do not match successful adjudication of measured evidence.`);
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
    const approvalRead = readChild(root, deployed.deploymentApprovalFile,
      deployed.deploymentApprovalSha256, "Backend approval");
    const approval = approvalRead.value;
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
    verifyApproval(root, receipt, approval);
    const anchoredBackend = JSON.parse(gitSourceValue(root, BUILD27_GOVERNANCE.commit,
      "release/current-successor-state.json")).authorityPlanes.deployedBackend;
    const backendApprovalCustody = readApprovalCustody(root, BUILD27_GOVERNANCE.commit,
      {file: anchoredBackend.deploymentApprovalFile, sha256: anchoredBackend.deploymentApprovalSha256}, "Backend");
    requireEvidence(receipt.sourceAuthority.commit === anchoredBackend.functionFleetSourceCommit &&
      historical.sourceAuthority.commit === anchoredBackend.functionFleetSourceCommit,
    "Backend approval custody: this source has no separately admitted immutable owner approval.");
    requireApprovalCustody(receipt.approvalAuthority, approvalRead, backendApprovalCustody, "Current backend");

    const deployments = historicalRead.hash === current.hash ? [receipt] : [historical, receipt];
    for (const measured of deployments) {
      if (measured !== receipt) {
        requireEvidence(sameHash(measured.approvalAuthority?.sha256, measured.approvalAuthority?.sha256),
          "Historical backend approval: physical SHA-256 authority is absent.");
        const historicalApproval = readChild(root, measured.approvalAuthority?.file,
          measured.approvalAuthority?.sha256, "Historical backend approval");
        verifyApproval(root, measured, historicalApproval.value);
        requireApprovalCustody(measured.approvalAuthority, historicalApproval, backendApprovalCustody, "Historical backend");
      }
      for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
        const authority = measured.cleanMainLiveReadbacks?.[key];
        requireEvidence(authority && SHA256.test(authority.physicalSha256 ?? ""),
          `${key}: physical SHA-256 authority is absent.`);
        const child = readChild(root, authority.file, authority.physicalSha256, key).value;
        verifyReceiptSeal(child, key);
        requireEvidence(sameHash(authority.canonicalReceiptSha256, child.receiptSha256),
          `${key}: canonical seal differs from parent authority.`);
        verifyReadbackDecision(root, measured, key, child);
      }
    }
    let pilotApprovalCustody;
    let promotionDecisionCustody;
    if (releasePolicy.postBuildPromotion?.status === "completed-staged-controlled-pilot-only") {
      const promotionRead = readChild(root, releasePolicy.postBuildPromotion.promotionReceiptFile,
        releasePolicy.postBuildPromotion.promotionReceiptSha256, "Staged promotion");
      const promotion = promotionRead.value;
      const deviceAuthority = promotion.admittedEvidence?.deviceAcceptance;
      const device = readChild(root, deviceAuthority?.receipt, deviceAuthority?.sha256, "Promotion device evidence").value;
      const anchoredPromotionBytes = gitSourceValue(root, BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT,
        BUILD27_PROMOTION_RECEIPT_PATH);
      const anchoredPilot = JSON.parse(anchoredPromotionBytes).ownerApproval;
      pilotApprovalCustody = readApprovalCustody(root, BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT,
        {file: anchoredPilot.receipt, sha256: anchoredPilot.sha256}, "Pilot");
      const pilotApproval = readChild(root, promotion.ownerApproval?.receipt,
        promotion.ownerApproval?.sha256, "Pilot owner approval");
      requireApprovalCustody({file: promotion.ownerApproval?.receipt, sha256: promotion.ownerApproval?.sha256},
        pilotApproval, pilotApprovalCustody, "Pilot owner");
      requireEvidence(promotionCiAuthorityExact(promotion, device) &&
        commitTree(root, BUILD27_GOVERNANCE.commit, "Promotion governance") === BUILD27_GOVERNANCE.tree,
      "Promotion governance: commit, Git tree or complete CI authority differs from the recorded Build27 gate and device evidence.");
      // This is the historical authorization, not an evolving handout log.
      // Roster, canary and later backend observations belong in separate records.
      promotionDecisionCustody = {file: BUILD27_PROMOTION_RECEIPT_PATH,
        sha256: crypto.createHash("sha256").update(anchoredPromotionBytes, "utf8").digest("hex").toUpperCase()};
      requireEvidence(releasePolicy.postBuildPromotion.promotionReceiptFile === promotionDecisionCustody.file &&
        sameHash(promotionRead.hash, promotionDecisionCustody.sha256),
      "Promotion decision custody: the complete historical authorization differs from its admitted fixed snapshot.");
    }
    return {ok: true, reasons: [],
      historicalBackendReceiptFile: finalization.exactFunctionFleetDeploymentReceiptFile,
      historicalBackendReceiptSha256: historicalRead.hash,
      currentBackendReceiptFile: deployed.functionFleetEvidenceFile,
      currentBackendReceiptSha256: current.hash,
      ...(pilotApprovalCustody ? {pilotOwnerApprovalFile: pilotApprovalCustody.file,
        pilotOwnerApprovalSha256: pilotApprovalCustody.sha256} : {}),
      ...(promotionDecisionCustody ? {promotionReceiptFile: promotionDecisionCustody.file,
        promotionReceiptSha256: promotionDecisionCustody.sha256} : {})};
  } catch (error) {
    return {ok: false, reasons: [error instanceof Error ? error.message : String(error)]};
  }
}

module.exports = {verifyStagedPromotionSourceAuthority, promotionCiAuthorityExact, BUILD27_GOVERNANCE};

if (require.main === module) {
  try {
    const [repoRoot, policyFile, ...extra] = process.argv.slice(2);
    requireEvidence(repoRoot && policyFile && extra.length === 0, "Expected repository root and release-policy path.");
    const releasePolicy = JSON.parse(fs.readFileSync(policyFile, "utf8").replace(/^\uFEFF/, ""));
    const result = verifyStagedPromotionSourceAuthority({repoRoot, releasePolicy});
    process.stdout.write(`${JSON.stringify(result)}\n`);
    process.exitCode = result.ok ? 0 : 1;
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
