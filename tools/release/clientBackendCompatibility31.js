"use strict";

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const historical = require("./stagedPromotionSourceAuthority.js");
const {verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const fleetReadback = require("./collectFunctionFleetRuntimeIdentityReadback.js");
const iamReadback = require("./collectFunctionsIamDependenciesReadback.js");
const firestoreReadback = require("./collectFirestoreRulesIndexesReadback.js");
const {readDeploymentFleetContract, measuredFunctionNamesMatch} = require("./deploymentFleetContract.js");
const PROJECT = "crm3-baf-ops-b8638";
const SHA256 = /^[0-9a-f]{64}$/i;
const COMMIT = /^[0-9a-f]{40}$/i;
const BUILD27_GOVERNANCE = historical.BUILD27_GOVERNANCE;
const CURRENT_EXACT_MAIN_JOBS = Object.freeze([
  "Flutter host analysis + tests + no-loss contracts",
  "Android release package + cold-start proof (non-production)",
  "Android emulator shell + business integration (not physical-device evidence)",
  "Firestore Rules + governed callable emulator",
  "Cloud Functions host build + non-emulator tests",
].sort());

const BUILD31_COMPATIBILITY = Object.freeze({
  buildNumber: 31,
  minimumSource: "7ed87824447f1349cb0481c448e0b21c3fa5856f",
  file: "release/approvals/build31-client-backend-compatibility-approval.json",
  ownerFile: "release/approvals/build31-client-owner-authorization.json",
  ciFile: "release/evidence/build31-client-source-main-ci.json",
  securityFile: "release/evidence/build31-client-source-main-security.json",
  backendFile: "release/evidence/build30-current-source-backend-deployment-closure.json",
  backendSha256: "3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45",
  backendCommit: "2aa30de56cfdb960da3eeefd8956d8cbbae57b46",
});
const CLIENT31_SCOPE = Object.freeze({clientConstructionOnly: true,
  backendDeploymentAuthorized: false, backendSourceChanged: false,
  firestoreRulesOrIndexesChanged: false, iamOrEnforcementChangeAuthorized: false,
  distributionAuthorized: false});


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


function verifyDelegatedSourceGeneration(repoRoot, sourceCommit, contract, approval, expectedBuildNumber) {
  requireEvidence(typeof sourceCommit === "string" && COMMIT.test(sourceCommit),
    "Successor delegated source: source commit must be exactly 40 hexadecimal characters.");
  requireEvidence(expectedBuildNumber === contract.buildNumber && approval.intendedBuildNumber === contract.buildNumber,
    "Successor delegated custody: intended build number and independently selected expected build number must match the contract.");
  // The backend is deployed from F before the app metadata advances in N.
  // Read that predecessor/current generation from immutable source Git, not
  // from the approval or caller's checkout. Future and mixed generations must
  // not borrow the open-ended source ancestry of this decision protocol.
  const policy = JSON.parse(gitSourceValue(repoRoot, sourceCommit, "release/production-release-policy.json"));
  const ledger = JSON.parse(gitSourceValue(repoRoot, sourceCommit, "release/build-number-ledger.json"));
  const versions = [...gitSourceValue(repoRoot, sourceCommit, "pubspec.yaml")
    .matchAll(/^version:[ \t]*[^\r\n+]+\+([1-9][0-9]*)[ \t]*\r?$/gm)];
  const build = policy.versionPolicy?.buildNumber;
  requireEvidence(Number.isSafeInteger(build) && [contract.buildNumber - 1, contract.buildNumber].includes(build) &&
    policy.release?.buildNumber === build && versions.length === 1 && Number(versions[0][1]) === build &&
    Array.isArray(ledger.entries) && ledger.entries.length === build &&
    ledger.entries.every((entry, index) => entry?.buildNumber === index + 1),
  "Successor delegated custody: source generation must be the coherent predecessor or intended build in Git policy, pubspec and ledger.");
}


function canonicalOwnerInstruction(value) {
  // Comparison only: compatibility spelling, invisible formatting, punctuation,
  // symbols, whitespace and case do not turn historical wording into new authorization.
  // Preserve original bytes and the exact instruction/excerpt custody check;
  // this is not semantic paraphrase matching.
  return value.normalize("NFKC").replace(/\p{Default_Ignorable_Code_Point}/gu, "")
    .replace(/[\p{P}\p{S}\s]+/gu, " ").trim().toLowerCase();
}


function verifyReadbackDecision(repoRoot, receipt, key, child, observationSource = receipt.sourceAuthority) {
  const source = receipt.sourceAuthority;
  requireEvidence([child.source?.before, child.source?.after].every((point) =>
    point?.commit === observationSource.commit && point?.tree === observationSource.tree &&
    point?.originMain === observationSource.commit && point?.branch === "main" &&
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


function verifyBuild31ClientCompatibility({repoRoot, releasePolicy, version, backendReceipt}) {
  const contract = BUILD31_COMPATIBILITY;
  const pointer = releasePolicy.clientBackendCompatibility;
  requireEvidence(releasePolicy.versionPolicy?.buildNumber === 31 && releasePolicy.release?.buildNumber === 31 &&
    pointer?.file === contract.file && COMMIT.test(pointer.commit ?? "") && SHA256.test(pointer.sha256 ?? "") &&
    isDeepStrictEqual(pointer, version.requiredSource?.clientBackendCompatibility),
  "Build31 compatibility: exact independently selected policy/version decision custody is required.");
  const decisionRead = readChild(repoRoot, pointer.file, pointer.sha256, "Build31 compatibility");
  readApprovalCustody(repoRoot, pointer.commit, pointer, "Build31 compatibility");
  const approval = decisionRead.value, source = approval.sourceAuthority;
  const decision = explicitUtcInstant(approval.approvedAtUtc);
  const recorded = explicitUtcInstant(approval.approvalEvidence?.recordedAtUtc);
  const tree = commitTree(repoRoot, source?.commit, "Build31 client source");
  requireEvidence(approval.schemaVersion === 1 &&
    approval.documentType === "governed-client-existing-backend-compatibility-approval" &&
    approval.approved === true && approval.intendedBuildNumber === 31 && approval.firebaseProjectId === PROJECT &&
    approval.approverName === "Codex acting under project-owner delegation" &&
    approval.approvalEvidence?.authorityType === "owner-delegated agent decision" &&
    approval.approvalEvidence.delegationPolicyId === "BUILD31-CLIENT-EXISTING-BACKEND-COMPATIBILITY" &&
    ["messageReceivedAtUtc", "ownerInstructionReceivedAtUtc", "codexMessageId", "instructionVerbatim"]
      .every((key) => !Object.hasOwn(approval.approvalEvidence, key)) &&
    isDeepStrictEqual(approval.scope, CLIENT31_SCOPE) && source.tree === tree &&
    version.sourceBaseline?.commit === source.commit && version.sourceBaseline?.tree === tree &&
    decision != null && recorded != null && decision <= recorded && recorded <= BigInt(Date.now()) * 1000000n &&
    explicitUtcInstant(approval.approvalEvidence.delegatedDecisionAtUtc) === decision,
  "Build31 compatibility: source, scope or truthful delegated decision chronology differs.");
  for (const [before, after] of [[contract.minimumSource, source.commit], [source.commit, pointer.commit], [pointer.commit, "HEAD"]]) {
    execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "merge-base", "--is-ancestor", before, after],
      {windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
  }
  const committedSeconds = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "show", "-s", "--format=%ct", pointer.commit],
    {encoding: "utf8", windowsHide: true}).trim();
  requireEvidence(/^[0-9]+$/.test(committedSeconds) &&
    recorded < (BigInt(committedSeconds) + 1n) * 1000000000n &&
    BigInt(committedSeconds) * 1000000000n <= BigInt(Date.now()) * 1000000n,
  "Build31 compatibility: decision must predate its non-future custody commit.");
  verifyDelegatedSourceGeneration(repoRoot, source.commit, contract, approval, 31);
  requireEvidence(approval.existingBackend?.file === contract.backendFile &&
    sameHash(approval.existingBackend.sha256, contract.backendSha256) &&
    approval.existingBackend.sourceCommit === contract.backendCommit &&
    releasePolicy.finalization?.exactFunctionFleetDeploymentReceiptFile === contract.backendFile &&
    sameHash(releasePolicy.finalization.exactFunctionFleetDeploymentReceiptSha256, contract.backendSha256) &&
    backendReceipt.sourceAuthority?.commit === contract.backendCommit,
  "Build31 compatibility: original Build30 deployment receipt and source must remain separate and immutable.");
  const original = readChild(repoRoot, contract.backendFile, contract.backendSha256, "Build31 original backend").value;
  requireEvidence(isDeepStrictEqual(original, backendReceipt), "Build31 compatibility: supplied backend is not the original closure.");
  for (const file of ["functions", "firestore.rules", "firestore.indexes.json"]) {
    const objectAt = (commit) => execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "--verify", `${commit}:${file}`],
      {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
    const deployedObject = objectAt(contract.backendCommit);
    requireEvidence(objectAt(source.commit) === deployedObject &&
      (file !== "functions" || source.functionsGitObjectId === deployedObject),
    `Build31 compatibility: ${file} differs from the actually deployed backend.`);
  }
  const ownerPointer = approval.approvalEvidence.ownerAuthorization;
  requireEvidence(ownerPointer?.file === contract.ownerFile && SHA256.test(ownerPointer.sha256 ?? ""),
    "Build31 compatibility: fresh source-specific owner authorization is required.");
  readApprovalCustody(repoRoot, pointer.commit, ownerPointer, "Build31 owner authorization");
  const owner = readChild(repoRoot, ownerPointer.file, ownerPointer.sha256, "Build31 owner authorization").value;
  const authorized = explicitUtcInstant(owner.authorizedAtUtc), ownerRecorded = explicitUtcInstant(owner.recordedAtUtc);
  requireEvidence(owner.schemaVersion === 1 && owner.documentType === "source-specific-client-existing-backend-owner-authorization" &&
    owner.approved === true && owner.intendedBuildNumber === 31 && owner.firebaseProjectId === PROJECT &&
    owner.sourceCommit === source.commit && owner.sourceTree === tree &&
    isDeepStrictEqual(owner.existingBackend, approval.existingBackend) && isDeepStrictEqual(owner.scope, CLIENT31_SCOPE) &&
    typeof owner.ownerInstruction === "string" && canonicalOwnerInstruction(owner.ownerInstruction).length > 0 &&
    typeof owner.ownerReference === "string" && owner.ownerReference.trim().length > 0 &&
    typeof owner.recordedBy === "string" && owner.recordedBy.trim().length > 0 &&
    approval.approvalEvidence.ownerReference === owner.ownerReference &&
    isDeepStrictEqual(approval.approvalEvidence.instructionExcerpts, [owner.ownerInstruction]) &&
    authorized != null && ownerRecorded != null && authorized <= ownerRecorded && ownerRecorded <= decision,
  "Build31 compatibility: owner instruction/source/scope/chronology is not bound to this decision.");
  let lastCiCompletion = 0n;
  for (const [key, file, type, workflow, expectedJobs] of [
    ["mainCi", contract.ciFile, "github-exact-main-release-gate", ".github/workflows/release-gate.yml", CURRENT_EXACT_MAIN_JOBS],
    ["securityCi", contract.securityFile, "github-exact-main-codeql", ".github/workflows/codeql.yml",
      ["CodeQL (actions)", "CodeQL (java-kotlin)", "CodeQL (javascript-typescript)", "CodeQL (python)"].sort()],
  ]) {
    const ciPointer = source[key];
    requireEvidence(ciPointer?.file === file && SHA256.test(ciPointer.sha256 ?? ""), `Build31 ${key}: exact committed CI pointer required.`);
    readApprovalCustody(repoRoot, pointer.commit, ciPointer, `Build31 ${key}`);
    const ci = readChild(repoRoot, file, ciPointer.sha256, `Build31 ${key}`).value;
    const run = ci.run, jobs = ci.jobs, pr = ci.pullRequest;
    const capture = explicitUtcInstant(ci.capturedAtUtc), completed = explicitUtcInstant(run?.updated_at);
    const merged = explicitUtcInstant(pr?.merged_at), started = explicitUtcInstant(run?.created_at);
    requireEvidence(ci.schemaVersion === 1 && ci.evidenceType === type && ci.repository === BUILD27_GOVERNANCE.repository &&
      ci.sourceCommit === source.commit && ci.sourceTree === tree &&
      pr?.number === source.pullRequestNumber && Number.isSafeInteger(pr.number) && pr.number > 0 &&
      pr.merged === true && pr.merge_commit_sha === source.commit && pr.base?.ref === "main" &&
      pr.base.repo?.full_name === ci.repository && run?.repository?.full_name === ci.repository &&
      run.head_sha === source.commit && run.head_branch === "main" && run.event === "push" && run.path === workflow &&
      Number.isSafeInteger(run.id) && run.id > 0 && run.id === source[key === "mainCi" ? "postMergeReleaseGateRunId" : "postMergeSecurityRunId"] &&
      run.status === "completed" && run.conclusion === "success" && capture != null && completed != null && merged != null && started != null &&
      merged <= started && started <= completed && completed <= capture && capture <= decision &&
      jobs?.total_count === expectedJobs.length && Array.isArray(jobs.jobs) && jobs.jobs.length === expectedJobs.length &&
      isDeepStrictEqual(jobs.jobs.map((job) => job.name).sort(), expectedJobs) &&
      new Set(jobs.jobs.map((job) => job.id)).size === expectedJobs.length && jobs.jobs.every((job) => {
        const time = explicitUtcInstant(job.completed_at);
        return Number.isSafeInteger(job.id) && job.id > 0 && job.run_id === run.id && job.head_sha === source.commit &&
          job.status === "completed" && job.conclusion === "success" && time != null && started <= time && time <= completed;
      }), `Build31 ${key}: exact merged source and every successful main job must precede the decision.`);
    if (completed > lastCiCompletion) lastCiCompletion = completed;
  }
  for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
    const readbackPointer = approval.liveBackendReadbacks?.[key];
    const file = `release/evidence/build31-client-compatibility-${key}.json`;
    requireEvidence(readbackPointer?.file === file && SHA256.test(readbackPointer.sha256 ?? ""),
      `Build31 ${key}: fresh fixed-path readback is required.`);
    readApprovalCustody(repoRoot, pointer.commit, readbackPointer, `Build31 ${key}`);
    const child = readChild(repoRoot, file, readbackPointer.sha256, `Build31 ${key}`).value;
    verifyReceiptSeal(child, `Build31 ${key}`);
    const captured = explicitUtcInstant(child.capturedAtUtc);
    requireEvidence(captured != null && lastCiCompletion <= captured && captured <= decision &&
      decision - captured <= 86400n * 1000000000n,
    `Build31 ${key}: readback must follow actual main CI and be at most 24 hours old at decision.`);
    if (key === "functionFleet" || key === "firestoreRulesAndIndexes") {
      const observed = explicitUtcInstant(key === "functionFleet"
        ? child.outputs?.schedulerBacklog?.observedAtUtc : child.collectionStartedAtUtc);
      requireEvidence(observed != null && lastCiCompletion <= observed && observed <= captured,
        `Build31 ${key}: measured observation must follow main CI, not just its recapture timestamp.`);
    }
    // The observation truthfully uses current main M. The immutable backend
    // policy, dependencies, source hash and deployment times remain those of F.
    verifyReadbackDecision(repoRoot, original, key, child, source);
  }
  return {file: pointer.file, sha256: decisionRead.hash, commit: pointer.commit, sourceCommit: source.commit};
}

// The original verifier is itself hash-bound by the Build30 Rules method.
// Keep those historical bytes and receipts untouched. Selecting30 here verifies
// only that backend plane; the independent31 proof below admits the client.
function verifyClientBackendSourceAuthority({repoRoot, releasePolicy}) {
  if (releasePolicy?.release?.buildNumber !== undefined &&
      releasePolicy.release.buildNumber !== releasePolicy?.versionPolicy?.buildNumber) {
    return {ok: false, reasons: ["Client/backend authority: release and version generations differ."]};
  }
  if (releasePolicy?.versionPolicy?.buildNumber !== 31 && releasePolicy?.release?.buildNumber !== 31) {
    return historical.verifyStagedPromotionSourceAuthority({repoRoot, releasePolicy});
  }
  try {
    const root = fs.realpathSync(repoRoot);
    const backendPolicy = {...releasePolicy,
      versionPolicy: {...releasePolicy.versionPolicy, buildNumber: 30}};
    const backend = historical.verifyStagedPromotionSourceAuthority({repoRoot: root, releasePolicy: backendPolicy});
    requireEvidence(backend.ok, `Build31 historical backend: ${backend.reasons.join("; ")}`);
    requireEvidence(backend.currentBackendReceiptFile === BUILD31_COMPATIBILITY.backendFile &&
      sameHash(backend.currentBackendReceiptSha256, BUILD31_COMPATIBILITY.backendSha256) &&
      backend.candidateBackendReceiptFile === BUILD31_COMPATIBILITY.backendFile &&
      sameHash(backend.candidateBackendReceiptSha256, BUILD31_COMPATIBILITY.backendSha256),
    "Build31 compatibility: selected and current backend must both retain the unchanged original Build30 closure.");
    const version = readChild(root, releasePolicy.versionPolicy.sourceDocumentFile,
      releasePolicy.versionPolicy.sourceDocumentSha256, "Build31 version").value;
    const receipt = readChild(root, BUILD31_COMPATIBILITY.backendFile,
      BUILD31_COMPATIBILITY.backendSha256, "Build31 original backend").value;
    const proof = verifyBuild31ClientCompatibility({repoRoot: root, releasePolicy, version, backendReceipt: receipt});
    return {...backend, clientBackendCompatibility: proof};
  } catch (error) {
    return {ok: false, reasons: [error instanceof Error ? error.message : String(error)]};
  }
}

module.exports = {verifyClientBackendSourceAuthority, verifyBuild31ClientCompatibility};
if (require.main === module) {
  try {
    const [repoRoot, policyFile, ...extra] = process.argv.slice(2);
    requireEvidence(repoRoot && policyFile && extra.length === 0, "Expected repository root and release-policy path.");
    const releasePolicy = JSON.parse(fs.readFileSync(policyFile, "utf8").replace(/^\uFEFF/, ""));
    const result = verifyClientBackendSourceAuthority({repoRoot, releasePolicy});
    process.stdout.write(`${JSON.stringify(result)}\n`);
    process.exitCode = result.ok ? 0 : 1;
  } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
}
