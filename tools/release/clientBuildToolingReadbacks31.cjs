"use strict";
// Offline-verifiable IAM receipt adapter. This creates no release or
// construction authority. The original collector and its F-era receipts stay intact.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const original = require("./collectFunctionsIamDependenciesReadback.js");
const {sealReceipt, verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const {verifyGitDevelopmentTooling} = require("./clientBuildToolingGitSnapshots31.cjs");
const {DEPLOYED_BASELINE} = require("./clientBuildToolingCompatibility31.cjs");
const TYPE = "build31-candidate-deployed-iam-dependencies-readback";
const PROJECT = "crm3-baf-ops-b8638";
const REGION = "asia-south1";
const COLLECTOR = "tools/release/collectFunctionsIamDependenciesReadback.js";
const RECEIPT = "release/evidence/build30-current-source-backend-deployment-closure.json";
const RECEIPT_SHA = "3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45";
const COMMIT = /^[0-9a-f]{40}$/;
const WRAPPING_PRODUCERS = Object.freeze([
  "tools/release/collectClientDevelopmentToolIam31.cjs",
  "tools/release/clientBuildToolingReadbacks31.cjs",
  "tools/release/clientBuildToolingGitSnapshots31.cjs",
  "tools/release/clientBuildToolingCompatibility31.cjs",
  "tools/release/collectClientBuildToolingRuntime31.cjs",
  "tools/release/collectProductionGlobalPullBackend.js",
  "tools/release/collectFirestoreRulesIndexesReadback.js",
  COLLECTOR,
]);
function must(ok, message) { if (!ok) throw new Error(message); }
function same(a, b, message) { must(isDeepStrictEqual(a, b), message); }
function hash(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase(); }
function utc(text) {
  must(typeof text === "string", "Explicit UTC timestamp required");
  const match = /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.(\d{1,9}))?Z$/.exec(text);
  must(match && !text.startsWith("0000-"), "Explicit UTC timestamp required");
  const seconds = Date.parse(match[1] + "Z"); must(Number.isFinite(seconds) && new Date(seconds).toISOString().slice(0, 19) === match[1], "Invalid UTC instant");
  return BigInt(seconds) * 1000000n + BigInt((match[2] || "").padEnd(9, "0"));
}
function git(repo, args) { return execFileSync("git", ["--no-replace-objects", "-C", repo, ...args], {windowsHide: true, maxBuffer: 32 * 1024 * 1024}); }
function read(repo, commit, file) { must(COMMIT.test(commit), "Exact commit required"); return git(repo, ["show", `${commit}:${file}`]); }
function json(bytes) { return JSON.parse(bytes.toString("utf8").replace(/^\uFEFF/, "")); }
function snapshot(point, proof) {
  must(point && point.commit === proof.candidateCommit && point.tree === proof.candidateTree && point.originMain === proof.candidateCommit && point.branch === "main" && point.governedWorktreeClean === true && point.materialChangeCount === 0 && Array.isArray(point.materialPathSha256) && point.materialPathSha256.length === 0, "Candidate observation must bind clean literal main M");
}
function fields(value) {
  const {receiptSha256, capturedAtUtc, ...body} = value;
  return body;
}
function assessment(evidence) {
  const {schemaVersion, evidenceType, source, outputs, ...rest} = evidence;
  return {dependencyBaselineCommit: DEPLOYED_BASELINE, ...rest};
}
function verifyWrappingCode(repoRoot, candidateCommit) {
  return Object.fromEntries(WRAPPING_PRODUCERS.map(file => {
    const expected = read(repoRoot, candidateCommit, file);
    same(fs.readFileSync(path.join(__dirname, path.basename(file))), expected, "Executing wrapper/helper differs from actual M: " + file);
    return [file, hash(expected)];
  }));
}
function createDualSourceIamReceipt({repoRoot, candidateCommit, rawCapture, collectionStartedAtUtc, capturedAtUtc}) {
  const wrappingCode = verifyWrappingCode(repoRoot, candidateCommit);
  const proof = verifyGitDevelopmentTooling({repoRoot, candidateCommit});
  snapshot(rawCapture.source?.before, proof); snapshot(rawCapture.source?.after, proof);
  verifyReceiptSeal(rawCapture, "Build31 original IAM observation");
  must(rawCapture.mode === "OBSERVE", "Preserve the actual original observe capture, including its candidate dependency mismatch");
  must(utc(collectionStartedAtUtc) <= utc(rawCapture.capturedAtUtc) && utc(rawCapture.capturedAtUtc) <= utc(capturedAtUtc) && utc(capturedAtUtc) <= BigInt(Date.now()) * 1000000n, "IAM collection/capture chronology differs");
  const policyRaw = read(repoRoot, DEPLOYED_BASELINE, original.POLICY_PATH);
  same(read(repoRoot, candidateCommit, original.POLICY_PATH), policyRaw, "Deployed IAM policy changed");
  same(read(repoRoot, DEPLOYED_BASELINE, COLLECTOR), read(repoRoot, candidateCommit, COLLECTOR), "Original F collector changed");
  same(read(repoRoot, candidateCommit, COLLECTOR), fs.readFileSync(path.join(__dirname, "collectFunctionsIamDependenciesReadback.js")), "Original collector implementation differs from candidate source");
  const backendRaw = read(repoRoot, candidateCommit, RECEIPT);
  must(hash(backendRaw) === RECEIPT_SHA, "Original backend closure changed");
  const backend = json(backendRaw), policy = json(policyRaw);
  const summary = commit => original.summarizePackageState({packageJsonRaw: read(repoRoot, commit, "functions/package.json").toString("utf8"), packageLockRaw: read(repoRoot, commit, "functions/package-lock.json").toString("utf8"), trackedPackages: policy.trackedRuntimePackages});
  const candidateDependencies = summary(candidateCommit), deployedDependencies = summary(DEPLOYED_BASELINE);
  same(rawCapture.outputs?.currentSourceDependencies, candidateDependencies, "Raw collector current source inventory is not candidate M");
  const sourceExports = [...policy.sourceFunctionExports].sort();
  same(rawCapture.outputs.discoveredSourceFunctionExports, sourceExports, "Raw source export inventory differs");
  const common = {projectId: PROJECT, region: REGION, sourceBefore: rawCapture.source.before, sourceAfter: rawCapture.source.after, policy, project: rawCapture.outputs.project, iam: rawCapture.outputs.iam, functions: rawCapture.outputs.functions, discoveredSourceExports: sourceExports};
  const candidateReplay = original.adjudicateReadback({...common, currentDependencies: candidateDependencies, observe: true});
  same(fields(rawCapture), candidateReplay.evidence, "Raw observation differs from complete original adjudication");
  const deployedReplay = original.adjudicateReadback({...common, currentDependencies: deployedDependencies, observe: false});
  must(deployedReplay.failedChecks.length === 0 && Object.values(deployedReplay.evidence.checks).every(value => value === true) && deployedReplay.evidence.posture.holds.length === 0 && deployedReplay.evidence.posture.decision === "PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE", "Fresh deployed F dependency/IAM replay fails");
  const historicPointer = backend.cleanMainLiveReadbacks.iamDependencies;
  const historicBytes = read(repoRoot, candidateCommit, historicPointer.file);
  must(hash(historicBytes) === historicPointer.physicalSha256, "Historical deployed IAM child hash differs");
  const historic = json(historicBytes); verifyReceiptSeal(historic, "Historical deployed IAM readback");
  const sortedRows = rows => [...rows].sort((a,b)=>a.name.localeCompare(b.name));
  same(sortedRows(rawCapture.outputs.functions), sortedRows(historic.outputs.functions), "Historical per-function identity/archive/update records differ");
  const records = rawCapture.outputs.functions;
  must(Array.isArray(records) && records.length > 0 && records.every(row => row.firebaseFunctionsHash === backend.deployment.sourceRuntimeHash), "Deployed runtime source changed");
  const updates = records.map(row => utc(row.updateTime));
  must(updates.reduce((a,b)=>a<b?a:b) === utc(backend.authorityChronology.earliestFunctionUpdateTime) && updates.reduce((a,b)=>a>b?a:b) === utc(backend.authorityChronology.latestFunctionUpdateTime), "Deployed runtime update chronology changed");
  const functionsObject = commit => git(repoRoot, ["rev-parse", "--verify", `${commit}:functions`]).toString("utf8").trim();
  return sealReceipt({schemaVersion: 1, evidenceType: TYPE, intendedBuildNumber: 31, projectId: PROJECT, region: REGION, collectionStartedAtUtc, capturedAtUtc, candidateSource: rawCapture.source,
    deployedBackend: {commit: DEPLOYED_BASELINE, tree: proof.baselineTree, functionsGitObjectId: functionsObject(DEPLOYED_BASELINE), closure: {file: RECEIPT, sha256: RECEIPT_SHA}, dependencies: deployedDependencies},
    candidateBuild: {commit: candidateCommit, tree: proof.candidateTree, functionsGitObjectId: functionsObject(candidateCommit), dependencies: candidateDependencies},
    wrappingCode,
    collectorBinding: {file: COLLECTOR, sha256: hash(read(repoRoot, candidateCommit, COLLECTOR)), policyFile: original.POLICY_PATH, policySha256: hash(policyRaw)},
    protectedInventorySha256: proof.inventorySha256,
    rawCapture,
    deployedBackendAssessment: assessment(deployedReplay.evidence),
    scope: {backendRuntimeChanged: false, backendBuildTestDependenciesChanged: true, backendDeploymentAuthorized: false, constructionAuthority: false, distributionAuthorized: false}});
}
function verifyDualSourceIamReceipt({repoRoot, candidateCommit, receipt, lastCiCompletionAtUtc, decisionAtUtc}) {
  verifyReceiptSeal(receipt, "Build31 dual-source IAM readback");
  must(receipt.evidenceType === TYPE && receipt.intendedBuildNumber === 31 && receipt.schemaVersion === 1, "Wrong dual-source IAM schema/generation");
  must(utc(lastCiCompletionAtUtc) <= utc(receipt.collectionStartedAtUtc) && utc(receipt.capturedAtUtc) <= utc(decisionAtUtc) && utc(decisionAtUtc) <= BigInt(Date.now()) * 1000000n && utc(decisionAtUtc) - utc(receipt.collectionStartedAtUtc) <= 86400n * 1000000000n, "Dual-source IAM readback must start after both current main gates and precede decision by at most 24 hours");
  const expected = createDualSourceIamReceipt({repoRoot, candidateCommit, rawCapture: receipt.rawCapture, collectionStartedAtUtc: receipt.collectionStartedAtUtc, capturedAtUtc: receipt.capturedAtUtc});
  same(receipt, expected, "Dual-source receipt contents differ from current Git and unchanged original adjudication");
  return {ok: true, candidateCommit, deployedCommit: DEPLOYED_BASELINE, constructionAuthority: false};
}
// Collection is deliberately not invoked by import or tests. A future reviewed
// invocation runs the unchanged collector once in OBSERVE, retains its sealed
// output and then calls createDualSourceIamReceipt. No failed capture is hidden.
module.exports = {createDualSourceIamReceipt, verifyDualSourceIamReceipt, verifyWrappingCode, WRAPPING_PRODUCERS};
