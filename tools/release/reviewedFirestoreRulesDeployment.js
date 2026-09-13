"use strict";

// Offline evidence verification only. This module never deploys, collects live
// state, approves a decision, or changes the existing callable IAM boundary.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const {verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const collector = require("./collectFirestoreRulesIndexesReadback.js");
const PROJECT = "crm3-baf-ops-b8638";
const RELEASE = `projects/${PROJECT}/releases/cloud.firestore`;
const RULES_COMMAND = Object.freeze([
  "tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js",
  "deploy", "--only", "firestore:rules", "--project", PROJECT,
  "--non-interactive", "--json",
]);
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const hash = (value) => typeof value === "string" && /^[0-9a-f]{64}$/i.test(value);
const sameHash = (a, b) => hash(a) && hash(b) && a.toUpperCase() === b.toUpperCase();
const need = (condition, label) => { if (!condition) throw new Error(`Rules deployment proof: ${label}.`); };
const exact = (actual, expected, label) => need(isDeepStrictEqual(actual, expected), label);
const oid = (value) => typeof value === "string" && /^[0-9a-f]{40}$/.test(value);
const object = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const executionRootSha256 = (root) => sha(fs.realpathSync(root).replaceAll("\\", "/"));
function keys(value, expected, label) {
  need(object(value), label);
  exact(Object.keys(value).sort(), [...expected].sort(), label);
}
function instant(value) {
  need(typeof value === "string", "UTC time missing");
  const m = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  need(m !== null && !m[1].startsWith("0000-"), "UTC time shape invalid");
  const ms = Date.parse(`${m[1]}Z`);
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 19) === m[1], "UTC calendar invalid");
  return BigInt(ms) * 1000000n + BigInt((m[2] ?? "").padEnd(9, "0"));
}
function gitBytes(root, commit, file) {
  need(oid(commit), "exact source commit required");
  return execFileSync("git", ["--no-replace-objects", "-C", root, "show", `${commit}:${file}`],
    {windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
}
function sourceRulesScope(repoRoot, sourceCommit, sourceTree) {
  need(oid(sourceCommit) && oid(sourceTree), "source/tree missing");
  const tree = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", `${sourceCommit}^{tree}`],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  need(tree === sourceTree, "source/tree differ");
  const config = JSON.parse(gitBytes(repoRoot, sourceCommit, "firebase.json"));
  need(object(config.firestore) && config.firestore.rules === "firestore.rules" &&
    config.firestore.indexes === "firestore.indexes.json" &&
    Object.keys(config.firestore).every((key) => ["rules", "indexes", "database"].includes(key)) &&
    (config.firestore.database === undefined || config.firestore.database === "(default)"),
  "source configuration must select only the reviewed default database files without hooks");
  const rules = gitBytes(repoRoot, sourceCommit, "firestore.rules");
  const raw = gitBytes(repoRoot, sourceCommit, "firestore.indexes.json").toString("utf8");
  const binding = collector.sourceIndexSetBinding(JSON.parse(raw), raw);
  return {rulesSha256: sha(rules), rulesByteCount: rules.length, indexes: {
    fileSha256: binding.sourceFileSha256, setSha256: binding.indexSetSha256,
    count: binding.count, fieldOverrideSetSha256: binding.fieldOverrideSetSha256,
    fieldOverrideCount: binding.fieldOverrideCount,
  }};
}
function evidencePath(value) {
  return typeof value === "string" && /^release\/evidence\/[A-Za-z0-9_.-]+\.json$/.test(value);
}
function readBound(root, pointer, sealed = true) {
  keys(pointer, sealed ? ["file", "physicalSha256", "canonicalReceiptSha256"] : ["file", "physicalSha256"], "evidence pointer shape");
  need(evidencePath(pointer.file) && hash(pointer.physicalSha256), "evidence path/hash invalid");
  const file = fs.realpathSync(path.join(root, pointer.file));
  const relative = path.relative(fs.realpathSync(root), file);
  need(!relative.startsWith("..") && !path.isAbsolute(relative), "evidence escapes custody root");
  const bytes = fs.readFileSync(file);
  need(sameHash(sha(bytes), pointer.physicalSha256), "physical evidence hash differs");
  let value;
  try { value = JSON.parse(bytes.toString("utf8")); } catch { throw new Error("Rules deployment proof: malformed evidence JSON."); }
  if (sealed) {
    verifyReceiptSeal(value, "Rules deployment evidence");
    need(sameHash(value.receiptSha256, pointer.canonicalReceiptSha256), "canonical evidence hash differs");
  }
  return value;
}
function declareRules({repoRoot, sourceCommit, sourceTree, declaration}) {
  keys(declaration, ["schemaVersion", "target", "projectId", "databaseId", "releaseName", "priorRulesetName",
    "priorRulesSha256", "rulesSha256", "indexes", "preflight", "commandEvidenceFile", "executionRootSha256"], "approval declaration shape");
  const source = sourceRulesScope(repoRoot, sourceCommit, sourceTree);
  need(declaration.schemaVersion === 1 && declaration.target === "firestore:rules" && declaration.projectId === PROJECT &&
    declaration.databaseId === "(default)" && declaration.releaseName === RELEASE &&
    typeof declaration.priorRulesetName === "string" &&
    new RegExp(`^projects/${PROJECT}/rulesets/[A-Za-z0-9_-]+$`).test(declaration.priorRulesetName) &&
    hash(declaration.priorRulesSha256) && sameHash(declaration.rulesSha256, source.rulesSha256) &&
    !sameHash(declaration.priorRulesSha256, declaration.rulesSha256) && evidencePath(declaration.commandEvidenceFile) &&
    hash(declaration.executionRootSha256),
  "approved target or old/new Rules hash differs");
  keys(declaration.indexes, Object.keys(source.indexes), "index approval shape");
  for (const key of Object.keys(source.indexes)) {
    need(key.endsWith("Sha256") ? sameHash(declaration.indexes[key], source.indexes[key]) : declaration.indexes[key] === source.indexes[key],
      "approved index/override inventory differs from exact source");
  }
  return source;
}
function validateObservation(readback, {sourceCommit, sourceTree, declaration, source, before}) {
  verifyReceiptSeal(readback, "Rules observation");
  need(readback.schemaVersion === 1 && readback.evidenceType === "firestore-rules-indexes-live-readback" &&
    readback.projectId === PROJECT && readback.mode === (before ? "OBSERVE" : "STRICT"), "observation type/mode/project");
  for (const point of [readback.source?.before, readback.source?.after]) {
    need(point?.commit === sourceCommit && point.tree === sourceTree && point.originMain === sourceCommit &&
      point.branch === "main" && point.governedWorktreeClean === true && point.materialChangeCount === 0 &&
      Array.isArray(point.materialPathSha256) && point.materialPathSha256.length === 0, "observation source not exact clean main");
  }
  const start = instant(readback.collectionStartedAtUtc), end = instant(readback.capturedAtUtc);
  need(start <= end && end <= BigInt(Date.now()) * 1000000n, "observation window invalid/future");
  const rules = readback.outputs?.rules, indexes = readback.outputs?.indexes;
  need(object(rules) && object(indexes), "observation outputs missing");
  need(sameHash(rules.sourceSha256, source.rulesSha256) && rules.sourceByteCount === source.rulesByteCount &&
    sameHash(rules.activeSha256, before ? declaration.priorRulesSha256 : declaration.rulesSha256) &&
    rules.byteExact === !before && (!before || rules.rulesetName === declaration.priorRulesetName), "observed old/new Rules differ");
  const sourceIndexKeys = {fileSha256: "sourceFileSha256", setSha256: "sourceSetSha256", count: "sourceCount",
    fieldOverrideSetSha256: "sourceFieldOverrideSha256", fieldOverrideCount: "sourceFieldOverrideCount"};
  for (const [key, output] of Object.entries(sourceIndexKeys)) {
    need(key.endsWith("Sha256") ? sameHash(indexes[output], source.indexes[key]) : indexes[output] === source.indexes[key],
      "observed source index file/set/overrides differ");
  }
  const result = collector.adjudicateReadback({projectId: PROJECT, sourceBefore: readback.source.before,
    sourceAfter: readback.source.after, rules, indexes, observe: before});
  exact(result.failedChecks, before ? ["rulesByteExact"] : [], "unexpected observed drift");
  need(Object.entries(result.evidence.checks).every(([key, value]) => value === (key === "rulesByteExact" ? !before : true)),
    "every observed control except the approved Rules difference must be explicitly true");
  for (const key of ["checks", "failedChecks", "decision", "mutationBoundary", "privacyBoundary"]) {
    exact(readback[key], result.evidence[key], "sealed observation differs from actual adjudication");
  }
  return {start, end};
}
function validateRulesPreflight({repoRoot, sourceCommit, sourceTree, declaration, readback}) {
  const source = declareRules({repoRoot, sourceCommit, sourceTree, declaration});
  return validateObservation(readback, {sourceCommit, sourceTree, declaration, source, before: true});
}
function validateRulesDeploymentBoundary({repoRoot, evidenceRoot = repoRoot, approval, receipt, successorDecision = null}) {
  const scope = approval.approvedDeployment, deployed = receipt.firestoreDeployment, boundary = receipt.controlBoundary;
  const declaration = scope?.reviewedRulesDeployment;
  const pointer = deployed?.rulesDeploymentEvidence;
  if (scope?.firestoreRulesMutationAuthorized === false) {
    need(deployed?.rulesDeploymentPerformed === false && boundary?.securityRulesMutated === false &&
      declaration === undefined && pointer === undefined, "unchanged Rules path cannot hide a mutation/proof");
    return {ok: true, decision: "PASS_NO_RULES_MUTATION"};
  }
  need(successorDecision?.ok === true && scope?.firestoreRulesMutationAuthorized === true &&
    deployed?.rulesDeploymentPerformed === true && deployed.rulesAlreadyExactNoMutationRequired === false &&
    boundary?.securityRulesMutated === true && scope.firestoreIndexMutationAuthorized === false &&
    boundary.indexesMutated === false && deployed.indexesAlreadyExactNoMutationRequired === true,
  "only an explicitly approved successor Rules-only mutation is admitted");
  const sourceCommit = receipt.sourceAuthority?.commit, sourceTree = receipt.sourceAuthority?.tree;
  need(successorDecision.sourceCommit === sourceCommit && successorDecision.sourceTree === sourceTree, "successor CI/source authority differs");
  const source = declareRules({repoRoot, sourceCommit, sourceTree, declaration});
  need(sameHash(scope.firestoreRulesSha256, source.rulesSha256) && sameHash(deployed.rulesSha256, source.rulesSha256), "parent Rules hashes differ");
  const preflight = readBound(evidenceRoot, declaration.preflight);
  const beforeApproval = validateObservation(preflight, {sourceCommit, sourceTree, declaration, source, before: true});
  need(beforeApproval.end <= instant(successorDecision.decisionAtUtc), "preflight postdates approval");
  need(pointer?.file === declaration.commandEvidenceFile, "unapproved command evidence path");
  const command = readBound(evidenceRoot, pointer);
  keys(command, ["schemaVersion", "evidenceType", "decision", "projectId", "source", "approvalAuthority", "ciAuthority",
    "target", "startedAtUtc", "completedAtUtc", "command", "executionSource", "exitCode", "cliResult", "beforeReadback", "receiptSha256"], "command evidence shape");
  need(command.schemaVersion === 1 && command.evidenceType === "reviewed-firestore-rules-deployment" &&
    command.decision === "PASS_EXACT_SOURCE_RULES_ONLY_DEPLOYED" && command.projectId === PROJECT &&
    command.target === "firestore:rules" && command.exitCode === 0, "unsuccessful/ambiguous command evidence");
  exact(command.source, {commit: sourceCommit, tree: sourceTree}, "command source differs");
  exact(command.approvalAuthority, receipt.approvalAuthority, "command approval custody differs");
  need(sameHash(command.approvalAuthority.sha256, successorDecision.approvalSha256) &&
    command.approvalAuthority.commit === successorDecision.approvalCommit, "command immutable approval differs");
  exact(command.ciAuthority, {file: successorDecision.ciFile, sha256: successorDecision.ciSha256,
    commit: successorDecision.approvalCommit}, "command CI custody differs");
  exact(command.command, {executable: "node", arguments: RULES_COMMAND}, "command must deploy only reviewed Rules");
  keys(command.executionSource, ["rootSha256", "before", "after"], "command checkout observation shape");
  need(sameHash(command.executionSource.rootSha256, declaration.executionRootSha256), "command checkout path differs from approval");
  for (const point of [command.executionSource.before, command.executionSource.after]) {
    need(point?.commit === sourceCommit && point.tree === sourceTree && point.originMain === sourceCommit &&
      point.branch === "main" && point.governedWorktreeClean === true && point.materialChangeCount === 0 &&
      Array.isArray(point.materialPathSha256) && point.materialPathSha256.length === 0, "command checkout not exact clean main");
  }
  // The pinned CLI emits precisely this result for a successful rules-only
  // deploy. The executor must retain its actual stdout; flags alone cannot pass.
  exact(readBound(evidenceRoot, command.cliResult, false), {status: "success", result: {}}, "actual CLI result is not unambiguous Rules-only success");
  const before = readBound(evidenceRoot, command.beforeReadback);
  const beforeWindow = validateObservation(before, {sourceCommit, sourceTree, declaration, source, before: true});
  const started = instant(command.startedAtUtc), completed = instant(command.completedAtUtc);
  need(instant(successorDecision.recordedAtUtc) <= beforeWindow.start &&
    instant(successorDecision.custodyCommitTimeUtc) <= beforeWindow.start &&
    beforeWindow.end <= started && started <= completed && completed <= BigInt(Date.now()) * 1000000n,
  "command/before observation predates custody, overlaps or is future");
  const finalPointer = receipt.cleanMainLiveReadbacks?.firestoreRulesAndIndexes;
  const after = readBound(evidenceRoot, {file: finalPointer?.file, physicalSha256: finalPointer?.physicalSha256,
    canonicalReceiptSha256: finalPointer?.canonicalReceiptSha256});
  const afterWindow = validateObservation(after, {sourceCommit, sourceTree, declaration, source, before: false});
  const recorded = instant(receipt.recordedAtUtc);
  need(completed <= afterWindow.start && afterWindow.end <= recorded && recorded <= BigInt(Date.now()) * 1000000n,
    "final observation began before command completion or closure time is invalid/future");
  need(deployed.rulesActiveByteExact === true && deployed.strictLiveReadbackPassed === true &&
    deployed.rulesetName === after.outputs.rules.rulesetName && deployed.rulesetCreateTime === after.outputs.rules.rulesetCreateTime,
  "closure omits or contradicts exact deployed Rules identity");
  return {ok: true, decision: "PASS_REVIEWED_RULES_ONLY_DEPLOYMENT"};
}

module.exports = {RULES_COMMAND, executionRootSha256, sourceRulesScope, validateRulesPreflight, validateRulesDeploymentBoundary};
