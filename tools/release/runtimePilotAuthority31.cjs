"use strict";
// Preserves only the fixed Build27 pilot plane for the distinct Runtime31 route.
// The historically hash-bound staged verifier remains byte-for-byte unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {isDeepStrictEqual}=require('node:util');
const {BUILD27_GOVERNANCE,promotionCiAuthorityExact}=require('./stagedPromotionSourceAuthority.js');
const {verifyReceiptSeal}=require('./collectProductionGlobalPullBackend.js');
const fleetReadback=require('./collectFunctionFleetRuntimeIdentityReadback.js');
const iamReadback=require('./collectFunctionsIamDependenciesReadback.js');
const firestoreReadback=require('./collectFirestoreRulesIndexesReadback.js');
const {readDeploymentFleetContract,deploymentCountsMatch,measuredFunctionNamesMatch}=require('./deploymentFleetContract.js');
const {validateDeploymentIamBoundary}=require('./scopedCallableInvokerIam.js');
const {validateRulesDeploymentBoundary}=require('./reviewedFirestoreRulesDeployment.js');
const PROJECT='crm3-baf-ops-b8638';
const DEPLOYED='PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK';
const SHA256=/^[0-9a-f]{64}$/i,COMMIT=/^[0-9a-f]{40}$/i;
const BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT='d95e399de07d43051d94debf36098e7998fe76d4';
const BUILD27_PROMOTION_RECEIPT_PATH='release/evidence/build-27-staged-controlled-pilot-authorization.json';

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

function verifyDeployment(repoRoot, receipt, label) {
  const fleet = readDeploymentFleetContract(repoRoot, receipt.sourceAuthority?.commit);
  requireEvidence(receipt.firebaseProjectId === PROJECT && receipt.decision === DEPLOYED &&
    deploymentCountsMatch(fleet, receipt.deployment) &&
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

function verifyPreservedPilotApproval(repoRoot, receipt, approval) {
  const source = receipt.sourceAuthority;
  const fleet = readDeploymentFleetContract(repoRoot, source.commit);
  const admitted = approval.sourceAuthority;
  const scope = approval.approvedDeployment;
  const approvedAt = explicitUtcInstant(approval.approvedAtUtc);
  const evidence = approval.approvalEvidence;
  const chronology = receipt.authorityChronology;
  // This adapter admits only the immutable project-owner Build27 approval.
  // Later delegated decisions cannot replace that fixed historical pilot.
  const decisionAt=explicitUtcInstant(chronology?.ownerInstructionReceivedAtUtc);
  const earliest=explicitUtcInstant(chronology?.earliestFunctionUpdateTime);
  const latest=explicitUtcInstant(chronology?.latestFunctionUpdateTime);
  const authorityExact=evidence?.authorityType === "project-owner instruction" &&
    explicitUtcInstant(evidence.messageReceivedAtUtc) === approvedAt &&
    !Object.hasOwn(chronology ?? {}, "delegatedDecisionAtUtc") &&
    !Object.hasOwn(chronology ?? {}, "allObservedFunctionUpdatesPostdateDelegatedDecision") &&
    chronology?.allObservedFunctionUpdatesPostdateOwnerInstruction === true;
  const functionTree = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "--verify", `${source.commit}:functions`],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  requireEvidence(approval.schemaVersion === 1 &&
    approval.documentType === "governed-current-source-backend-deployment-approval" &&
    approval.approved === true && approval.firebaseProjectId === PROJECT &&
    approval.region === "asia-south1" && receipt.region === approval.region &&
    authorityExact && approvedAt != null && decisionAt === approvedAt &&
    earliest != null && latest != null && decisionAt <= earliest && earliest <= latest &&
    chronology.deploymentWasRetroactivelyAuthorized === false &&
    admitted?.commit === source.commit && admitted?.tree === source.tree &&
    COMMIT.test(functionTree) && admitted?.functionTree === functionTree &&
    source.functionsGitObjectId === functionTree &&
    Number.isSafeInteger(admitted?.pullRequestNumber) && admitted.pullRequestNumber > 0 &&
    admitted.pullRequestNumber === source.pullRequestNumber &&
    Number.isSafeInteger(admitted.requiredPostMergeReleaseGateRunId) &&
    admitted.requiredPostMergeReleaseGateRunId > 0 &&
    admitted.requiredPostMergeReleaseGateRunId === source.postMergeReleaseGateRunId &&
    source.postMergeReleaseGateConclusion === "success" &&
    scope?.functionCount === fleet.functionCount &&
    deploymentCountsMatch(fleet, receipt.deployment) &&
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
    ["serviceAccountsMutated", "appCheckActivated", "productionBusinessDataMutated",
      "firestoreDocumentsWritten", "schedulerManuallyInvoked", "deviceDataMutated", "artifactConstructed",
      "pilotPromotionPerformed", "distributionPerformed", "indexesMutated"]
      .every((field) => receipt.controlBoundary?.[field] === false) &&
    receipt.controlBoundary?.securityRulesMutated === false,
  "Backend approval: source, owner authorization, schedule or deployment scope differs from measured authority.");
  validateRulesDeploymentBoundary({repoRoot, approval, receipt, successorDecision: null});
  validateDeploymentIamBoundary({repoRoot, approval, approvalSha256: receipt.approvalAuthority.sha256, receipt});
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
  const fleet = readDeploymentFleetContract(repoRoot, source.commit);
  requireEvidence(typeof receipt.deployment.sourceRuntimeHash === "string" &&
    COMMIT.test(receipt.deployment.sourceRuntimeHash) &&
    outputs.functions.every((record) => record.firebaseFunctionsHash === receipt.deployment.sourceRuntimeHash) &&
    measuredFunctionNamesMatch(fleet, outputs.functions) && updates.every((value) => value != null) &&
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

function verifyPreservedPilotForRuntime31({repoRoot, releasePolicy}) {
  const root = fs.realpathSync(repoRoot);
  requireEvidence(releasePolicy?.firebaseProjectId === PROJECT &&
    releasePolicy?.release?.buildNumber === 31 && releasePolicy?.versionPolicy?.buildNumber === 31 &&
    releasePolicy.postBuildPromotion?.status === 'completed-staged-controlled-pilot-only',
  'Runtime31 must preserve the exact existing staged pilot.');
  const anchoredBytes = gitSourceValue(root, BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT, BUILD27_PROMOTION_RECEIPT_PATH);
  const anchored = JSON.parse(anchoredBytes);
  const promotionHash = crypto.createHash('sha256').update(anchoredBytes,'utf8').digest('hex').toUpperCase();
  requireEvidence(releasePolicy.postBuildPromotion.promotionReceiptFile === BUILD27_PROMOTION_RECEIPT_PATH &&
    sameHash(releasePolicy.postBuildPromotion.promotionReceiptSha256,promotionHash),
  'Runtime31 cannot retarget the historical pilot promotion.');
  const promotion = readChild(root,BUILD27_PROMOTION_RECEIPT_PATH,promotionHash,'Preserved promotion').value;
  const backendPointer = promotion.admittedEvidence.productionBackend;
  const backendRead = readChild(root,backendPointer.receipt,backendPointer.sha256,'Preserved pilot backend');
  const backend = backendRead.value;
  verifyDeployment(root,backend,'Preserved pilot backend');
  const anchoredBackend = JSON.parse(gitSourceValue(root,BUILD27_GOVERNANCE.commit,
    'release/current-successor-state.json')).authorityPlanes.deployedBackend;
  requireEvidence(backend.sourceAuthority.commit === anchoredBackend.functionFleetSourceCommit,
    'Preserved pilot backend source changed.');
  const custody = readApprovalCustody(root,BUILD27_GOVERNANCE.commit,
    {file:anchoredBackend.deploymentApprovalFile,sha256:anchoredBackend.deploymentApprovalSha256},'Preserved backend');
  const approval = readChild(root,backend.approvalAuthority.file,backend.approvalAuthority.sha256,'Preserved backend approval');
  verifyPreservedPilotApproval(root,backend,approval.value);
  requireApprovalCustody(backend.approvalAuthority,approval,custody,'Preserved backend');
  for (const key of ['functionFleet','iamDependencies','firestoreRulesAndIndexes']) {
    const pointer=backend.cleanMainLiveReadbacks?.[key];
    requireEvidence(pointer && SHA256.test(pointer.physicalSha256 ?? ''),'Preserved readback binding missing.');
    const child=readChild(root,pointer.file,pointer.physicalSha256,'Preserved '+key).value;
    verifyReceiptSeal(child,key);
    requireEvidence(sameHash(pointer.canonicalReceiptSha256,child.receiptSha256),'Preserved readback seal differs.');
    verifyReadbackDecision(root,backend,key,child);
  }
  const devicePointer=promotion.admittedEvidence.deviceAcceptance;
  const device=readChild(root,devicePointer.receipt,devicePointer.sha256,'Preserved device evidence').value;
  const ownerCustody=readApprovalCustody(root,BUILD27_PILOT_APPROVAL_CUSTODY_COMMIT,
    {file:anchored.ownerApproval.receipt,sha256:anchored.ownerApproval.sha256},'Preserved pilot owner');
  const owner=readChild(root,promotion.ownerApproval.receipt,promotion.ownerApproval.sha256,'Preserved pilot owner');
  requireApprovalCustody({file:promotion.ownerApproval.receipt,sha256:promotion.ownerApproval.sha256},owner,ownerCustody,'Preserved pilot');
  requireEvidence(promotionCiAuthorityExact(promotion,device) &&
    commitTree(root,BUILD27_GOVERNANCE.commit,'Preserved governance') === BUILD27_GOVERNANCE.tree,
  'Preserved pilot governance differs.');
  return {historicalBackendReceiptFile:backendPointer.receipt,historicalBackendReceiptSha256:backendRead.hash,
    pilotOwnerApprovalFile:ownerCustody.file,pilotOwnerApprovalSha256:ownerCustody.sha256,
    promotionReceiptFile:BUILD27_PROMOTION_RECEIPT_PATH,promotionReceiptSha256:promotionHash};
}

module.exports={verifyPreservedPilotForRuntime31};
