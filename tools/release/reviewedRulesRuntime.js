"use strict";

// Read-only runtime measurement and offline evidence validation. No install or
// deployment is performed by this module. Local absolute paths stay private.
const {isDeepStrictEqual} = require("node:util");
const {measureByteTree,sourceIdentity,inspectInstallInputs,measureRulesInstaller,measureRulesRuntime} = require("./reviewedRulesRuntimeCollector.js");
const CLI = "tooling/firebase-cli";
const INSTALL_ARGUMENTS = Object.freeze(["--prefix", CLI, "ci", "--ignore-scripts",
  "--install-links=true", "--no-audit", "--no-fund", "--json", "--global=false"]);
const hash = (v) => typeof v === "string" && /^[A-F0-9]{64}$/.test(v);
const need = (v, label) => { if (!v) throw new Error(`Rules runtime proof: ${label}.`); };
const same = (a, b, label) => need(isDeepStrictEqual(a, b), label);
const object = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
function keys(v, expected, label) {
  need(object(v), label);same(Object.keys(v).sort(), [...expected].sort(), label);
}
function instant(v) {
  need(typeof v === "string", "UTC time required");
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(v);
  need(match && !match[1].startsWith("0000-"), "UTC time malformed");
  const ms = Date.parse(`${match[1]}Z`);
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 19) === match[1], "UTC calendar invalid");
  return BigInt(ms) * 1000000n + BigInt((match[2] ?? "").padEnd(9, "0"));
}
function exactCheckout(v, source) {
  need(v?.commit === source.commit && v.tree === source.tree && v.originMain === source.commit &&
    v.branch === "main" && v.governedWorktreeClean === true && v.materialChangeCount === 0 &&
    Array.isArray(v.materialPathSha256) && v.materialPathSha256.length === 0, "exact clean main checkout required");
}
function validateTree(v) {
  keys(v,["sha256","fileCount","byteCount","symlinkCount"],"tree identity shape");
  need(hash(v.sha256) && Number.isSafeInteger(v.fileCount) && v.fileCount > 0 &&
    Number.isSafeInteger(v.byteCount) && v.byteCount > 0 && Number.isSafeInteger(v.symlinkCount) && v.symlinkCount >= 0,
  "tree identity invalid");
}
function validateMeasurement(value, expectedSource, expectedIdentity = null) {
  keys(value,["schemaVersion","collectionStartedAtUtc","capturedAtUtc","identity"],"runtime measurement shape");
  need(value.schemaVersion === 1,"runtime schema differs");
  const start = instant(value.collectionStartedAtUtc), end = instant(value.capturedAtUtc);
  need(start <= end && end <= BigInt(Date.now())*1000000n,"runtime measurement window invalid");
  const v = value.identity;
  keys(v,["source","node","npm","installedTree","ancestorNodeModulesAbsent","nodeOptionsAbsent","nodePathAbsent"],"runtime identity shape");
  same(v.source,expectedSource,"runtime source/input identity differs");
  keys(v.node,["pathSha256","sha256","byteCount","version"],"Node identity shape");
  const nodeVersion = typeof v.node.version === "string" && /^v(\d+)\.(\d+)\.(\d+)$/.exec(v.node.version);
  need(hash(v.node.pathSha256) && hash(v.node.sha256) && Number.isSafeInteger(v.node.byteCount) && v.node.byteCount > 0 &&
    nodeVersion && (+nodeVersion[1] > 22 || (+nodeVersion[1] === 22 && +nodeVersion[2] >= 12)),"Node identity malformed/unsupported");
  keys(v.npm,["pathSha256","version","tree","treeScope","treeRootPathSha256"],"npm identity shape");
  need(hash(v.npm.pathSha256) && hash(v.npm.treeRootPathSha256) &&
    ["installation-node-modules","standalone-npm-package"].includes(v.npm.treeScope) &&
    typeof v.npm.version === "string" && /^\d+\.\d+\.\d+$/.test(v.npm.version),"npm identity malformed");
  validateTree(v.npm.tree);validateTree(v.installedTree);
  need(v.ancestorNodeModulesAbsent === true && v.nodeOptionsAbsent === true && v.nodePathAbsent === true,
    "unmeasured module lookup/injection admitted");
  if (expectedIdentity) same(v,expectedIdentity,"runtime differs from approved clean install");
  return {start,end};
}
function validateCleanInstall({repoRoot,sourceCommit,sourceTree,executionRootSha256,proof,readBound,decisionAtUtc}) {
  keys(proof,["schemaVersion","evidenceType","source","startedAtUtc","completedAtUtc","command","inputObservation",
    "installerBefore","sourceAfter","exitCode","stdout","installedRuntime","receiptSha256"],"clean install proof shape");
  const source = {...sourceIdentity(repoRoot,sourceCommit,sourceTree),executionRootSha256};
  need(proof.schemaVersion === 1 && proof.evidenceType === "reviewed-rules-cli-clean-install", "clean install type differs");
  same(proof.source,source,"clean install source differs");
  keys(proof.inputObservation,["source","checkout","nodeModulesAbsent","untrackedInputsAbsent","collectionStartedAtUtc","capturedAtUtc"],"initial install inputs shape");
  same(proof.inputObservation.source,source,"initial install source differs");
  need(proof.inputObservation.nodeModulesAbsent === true && proof.inputObservation.untrackedInputsAbsent === true,
    "installation did not begin with clean absent dependencies");
  exactCheckout(proof.inputObservation.checkout,source);exactCheckout(proof.sourceAfter,source);
  const window = validateMeasurement(proof.installedRuntime,source);
  keys(proof.installerBefore,["schemaVersion","collectionStartedAtUtc","capturedAtUtc","node","npm"],"installer before measurement shape");
  need(proof.installerBefore.schemaVersion === 1,"installer schema differs");
  keys(proof.command,["nodeArguments","arguments","node","npm"],"clean install command shape");
  same(proof.command.nodeArguments,["--no-global-search-paths"],"installer Node global lookup must be disabled");
  same(proof.command.arguments,INSTALL_ARGUMENTS,"only locked npm ci with disabled scripts is permitted");
  same(proof.command.node,proof.installerBefore.node,"installer Node was not independently measured before install");
  same(proof.command.npm,proof.installerBefore.npm,"installer npm was not independently measured before install");
  same(proof.command.node,proof.installedRuntime.identity.node,"installer Node identity changed");
  same(proof.command.npm,proof.installedRuntime.identity.npm,"installer npm identity changed");
  need(proof.exitCode === 0,"clean install failed or is ambiguous");
  const stdout = readBound(proof.stdout,false);
  need(object(stdout) && !Object.hasOwn(stdout,"error") && Number.isSafeInteger(stdout.added) && stdout.added > 0 &&
    stdout.removed === 0 && stdout.changed === 0, "actual npm output does not confirm a fresh clean install");
  const started = instant(proof.startedAtUtc), completed = instant(proof.completedAtUtc);
  const inputStart = instant(proof.inputObservation.collectionStartedAtUtc), inputEnd = instant(proof.inputObservation.capturedAtUtc);
  const installerStart = instant(proof.installerBefore.collectionStartedAtUtc), installerEnd = instant(proof.installerBefore.capturedAtUtc);
  need(inputStart <= inputEnd && inputEnd <= installerStart && installerStart <= installerEnd && installerEnd <= started &&
    started <= completed && completed <= window.start && window.end <= instant(decisionAtUtc),
    "clean install/measurement did not finish before approval");
  return {identity:proof.installedRuntime.identity,source};
}
function validateCommandRuntime({runtime,approved,startedAtUtc,completedAtUtc,notBeforeUtc,closureAtUtc}) {
  keys(runtime,["before","after"],"command runtime shape");
  const before = validateMeasurement(runtime.before,approved.source,approved.identity);
  const after = validateMeasurement(runtime.after,approved.source,approved.identity);
  need(instant(notBeforeUtc) <= before.start && before.end <= instant(startedAtUtc) &&
    instant(completedAtUtc) <= after.start && after.end <= instant(closureAtUtc),
    "runtime measurements do not bracket the command");
}
module.exports = {INSTALL_ARGUMENTS,measureByteTree,inspectInstallInputs,measureRulesInstaller,measureRulesRuntime,
  sourceIdentity,validateCleanInstall,validateCommandRuntime};
