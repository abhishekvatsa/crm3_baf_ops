"use strict";
// A reviewed post-main-CI invocation performs only
// read-only cloud observations through the unchanged historical collector.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync, spawnSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const {collectSourceBinding} = require("./collectFirestoreRulesIndexesReadback.js");
const {verifyGitDevelopmentTooling} = require("./clientBuildToolingGitSnapshots31.cjs");
const {createDualSourceIamReceipt, verifyWrappingCode} = require("./clientBuildToolingReadbacks31.cjs");
const {validateExactMainCiPair} = require("./collectClientBuildToolingRuntime31.cjs");
const COLLECTOR = "tools/release/collectFunctionsIamDependenciesReadback.js";
function must(ok, message) { if (!ok) throw new Error(message); }
function hash(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase(); }
function clean(point, proof) { must(point.commit === proof.candidateCommit && point.tree === proof.candidateTree && point.originMain === proof.candidateCommit && point.branch === "main" && point.governedWorktreeClean === true && point.materialChangeCount === 0 && Array.isArray(point.materialPathSha256) && point.materialPathSha256.length === 0, "Fresh IAM collection requires actual clean literal main M"); }
function retainCommandResult(target, command, result) {
  const stdout = result.stdout || Buffer.alloc(0), stderr = result.stderr || Buffer.alloc(0);
  fs.writeFileSync(path.join(target, "stdout.log"), stdout, {flag: "wx"});
  fs.writeFileSync(path.join(target, "stderr.log"), stderr, {flag: "wx"});
  const receipt = {...command, completedAtUtc: new Date().toISOString(), exitCode: Number.isInteger(result.status) ? result.status : null,
    signal: result.signal || null, error: result.error ? String(result.error) : null,
    stdout: {sha256: hash(stdout), bytes: stdout.length}, stderr: {sha256: hash(stderr), bytes: stderr.length}};
  fs.writeFileSync(path.join(target, "command.json"), JSON.stringify(receipt, null, 2) + "\n", {flag: "wx"});
  return receipt;
}
function collectDevelopmentToolIam31({repoRoot, candidateCommit, releaseCi, securityCi, outputDirectory, gcloudCommand, tarCommand}) {
  must(typeof repoRoot === "string" && path.isAbsolute(repoRoot), "Absolute repository root required");
  const actualRoot = fs.realpathSync(repoRoot);
  const proof = verifyGitDevelopmentTooling({repoRoot: actualRoot, candidateCommit});
  const wrappingCode = verifyWrappingCode(actualRoot, candidateCommit);
  const sourceBefore = collectSourceBinding(actualRoot); clean(sourceBefore, proof);
  const {lastCompletionUtc} = validateExactMainCiPair({candidateCommit, sourceTree: proof.candidateTree, releaseCi, securityCi});
  must(typeof outputDirectory === "string" && path.isAbsolute(outputDirectory), "Absolute exclusive private output directory required");
  const parent = fs.realpathSync(path.dirname(outputDirectory));
  const target = path.join(parent, path.basename(outputDirectory));
  const relative = path.relative(actualRoot, target);
  must(relative.startsWith(".." + path.sep) || path.isAbsolute(relative), "Private capture must be outside source repository");
  must(!fs.existsSync(target), "Append-only capture output already exists");
  for (const [name, command] of [["gcloud", gcloudCommand], ["tar", tarCommand]]) must(typeof command === "string" && path.isAbsolute(command) && fs.statSync(command).isFile(), name + " must name an explicit existing executable");
  const actualCollector = fs.readFileSync(path.join(actualRoot, COLLECTOR));
  const expectedCollector = execFileSync("git", ["--no-replace-objects", "-C", actualRoot, "show", `${candidateCommit}:${COLLECTOR}`], {windowsHide: true});
  must(isDeepStrictEqual(actualCollector, expectedCollector), "Working collector bytes differ from exact M");
  const collectionStartedAtUtc = new Date().toISOString();
  must(Date.parse(lastCompletionUtc) <= Date.parse(collectionStartedAtUtc), "Both actual main CI runs must complete before observation starts");
  fs.mkdirSync(target);
  const rawPath = path.join(target, "original-iam-observe.json");
  const args = [path.join(actualRoot, COLLECTOR), "--repository-root", actualRoot, "--project-id", "crm3-baf-ops-b8638", "--region", "asia-south1", "--output", rawPath, "--gcloud", gcloudCommand, "--tar", tarCommand, "--observe"];
  const command = {executable: process.execPath, arguments: args, sourceCommit: candidateCommit, collectorSha256: hash(actualCollector), startedAtUtc: collectionStartedAtUtc, sourceBefore, wrappingCode};
  const result = spawnSync(process.execPath, args, {cwd: actualRoot, windowsHide: true, encoding: null, timeout: 900000, maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"]});
  retainCommandResult(target, command, result);
  must(!result.error && result.status === 0 && !result.signal, "Original IAM observation failed; retained command/output must be inspected before a new attempt");
  const sourceAfter = collectSourceBinding(actualRoot);
  fs.writeFileSync(path.join(target, "source-after.json"), JSON.stringify(sourceAfter, null, 2) + "\n", {flag: "wx"});
  clean(sourceAfter, proof);
  const rawCapture = JSON.parse(fs.readFileSync(rawPath, "utf8").replace(/^\uFEFF/, ""));
  fs.writeFileSync(path.join(target, "raw-capture-hash.json"), JSON.stringify({sha256: hash(fs.readFileSync(rawPath))}) + "\n", {flag: "wx"});
  const receipt = createDualSourceIamReceipt({repoRoot: actualRoot, candidateCommit, rawCapture, collectionStartedAtUtc, capturedAtUtc: new Date().toISOString()});
  const receiptPath = path.join(target, "dual-source-iam-receipt.json");
  fs.writeFileSync(receiptPath, JSON.stringify(receipt, null, 2) + "\n", {flag: "wx"});
  return {receiptPath, sha256: hash(fs.readFileSync(receiptPath)), constructionAuthority: false};
}
module.exports = {collectDevelopmentToolIam31, retainCommandResult};
