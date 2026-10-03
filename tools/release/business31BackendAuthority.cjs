"use strict";
// Preparation measurement only. No credential, network or deployment operation.
// The caller must independently authenticate its selected verifier/manifest and
// human/platform records. This module deliberately cannot grant release authority.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const {isDeepStrictEqual: same, TextDecoder} = require("node:util");
const PROFILE = "build31-exact-business-backend-v1";
const DECISION_FILE = "release/approvals/build31-business-backend-deployment-approval.json";
const IMMUTABLE_COMMIT = "406d7407aa2d2ee6d8e6008e5cd3964df000ea85";
const IMMUTABLE = Object.freeze(["backendRuntimeExecutionAdmission31.cjs", "executeBackendRuntime31.cjs",
  "captureBackendRuntimePreparedInputs31.cjs", "runtimeDeploymentTransportGuard31.cjs", "backendRuntimeClosedReplay31.cjs",
  "backendRuntimeEvidenceAccess31.cjs", "backendRuntimeAdmission31.cjs", "backendRuntimeProof31.cjs",
  "backendRuntimeReadbacks31.cjs", "backendRuntimeClosure31.cjs", "backendRuntimeControls31.cjs",
  "backendRuntimeExecution31.cjs", "closure-preflight31.cjs", "clientRuntimeCompatibility31.cjs"].map(v => "tools/release/" + v));
const PRODUCERS = Object.freeze([...IMMUTABLE, "business31TrustedInput.cjs", "business31SourceAdmission.cjs",
  "business31BackendAuthority.cjs", "clientBuildToolingCompatibility31.cjs"].map(v => v.startsWith("tools/") ? v : "tools/release/" + v).sort());
const SCOPE = Object.freeze({buildNumber: 31, functionsOnly: true, existingFunctionCount: 19,
  businessLogicChanged: true, finiteSourceManifestRequired: true, firestoreRulesDeployment: false,
  firestoreIndexesDeployment: false, iamMutation: false, enforcementMutation: false,
  manualSchedulerExecution: false, clientConstruction: false, distribution: false});
const AUDITS = Object.freeze(["root-full", "root-runtime", "functions-full", "functions-runtime", "cli-full"]);
const COMMANDS = Object.freeze(["root-install", "functions-install", "cli-install", "functions-build",
  "functions-host-tests", "governed-emulator-tests", "dependency-compatibility", "installed-runtime"]);
function need(value, message) { if (!value) throw new Error("Business31 preparation: " + message); }
function keys(value, expected, label) {
  need(value && typeof value === "object" && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    same(Object.keys(value).sort(), [...expected].sort()), label + " fields differ");
}
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const hex = (value, count) => typeof value === "string" && new RegExp("^[a-f0-9]{" + count + "}$", "i").test(value);
function instant(value) {
  const match = typeof value === "string" && /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.(\d{1,9}))?Z$/.exec(value);
  need(match && !match[1].startsWith("0000-"), "explicit UTC required");
  const ms = Date.parse(match[1] + "Z");
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 19) === match[1], "invalid UTC calendar");
  return BigInt(ms) * 1000000n + BigInt((match[2] || "").padEnd(9, "0"));
}
function safeRelative(value) {
  need(typeof value === "string" && value.length > 0 && value.length <= 400 && /^[A-Za-z0-9_@+.~/-]+$/.test(value) &&
    !value.startsWith("/") && value.split("/").every(v => v && v !== "." && v !== ".." && !/[. ]$/.test(v) &&
      !/^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(v)), "unsafe evidence path");
  return value;
}
function regular(value, directory = false) {
  need(typeof value === "string" && path.isAbsolute(value), "absolute local path required");
  const full = path.resolve(value); let current = path.parse(full).root;
  for (const part of full.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part); need(!fs.lstatSync(current).isSymbolicLink(), "redirected local path");
  }
  const stat = fs.lstatSync(full);
  need(directory ? stat.isDirectory() : stat.isFile(), "regular local object required"); return full;
}
function pointer(value) {
  keys(value, ["file", "sha256", "bytes"], "private pointer"); safeRelative(value.file);
  need(hex(value.sha256, 64) && Number.isSafeInteger(value.bytes) && value.bytes >= 0 && value.bytes <= 64 * 1024 * 1024,
    "private pointer bound differs"); return value;
}
function readPrivate(root, value) {
  pointer(value); root = regular(root, true);
  const file = regular(path.join(root, value.file));
  const before = fs.statSync(file, {bigint: true});
  need(before.size === BigInt(value.bytes), "private byte count differs");
  const bytes = fs.readFileSync(file), after = fs.statSync(file, {bigint: true});
  need(before.size === after.size && before.mtimeNs === after.mtimeNs && before.ctimeNs === after.ctimeNs &&
    before.ino === after.ino && bytes.length === value.bytes && sha(bytes) === value.sha256.toUpperCase(), "private original bytes differ");
  return bytes;
}
function json(bytes) {
  const value = JSON.parse(new TextDecoder("utf-8", {fatal: true}).decode(bytes));
  need(value && typeof value === "object" && !Array.isArray(value), "JSON object required");
  const pending = [[value, 0]]; let count = 0;
  while (pending.length) { const [item, depth] = pending.pop(); need(++count <= 100000 && depth <= 40, "JSON bound exceeded");
    if (item && typeof item === "object") for (const child of Object.values(item)) pending.push([child, depth + 1]); }
  return value;
}
function verifyStrictAudit31(bytes) {
  const report = json(bytes);
  need(report.auditReportVersion === 2 && !Object.hasOwn(report, "error") && report.vulnerabilities &&
    !Array.isArray(report.vulnerabilities) && Object.keys(report.vulnerabilities).length === 0, "original audit is not clean");
  for (const name of ["info", "low", "moderate", "high", "critical", "total"])
    need(report.metadata?.vulnerabilities?.[name] === 0, "audit count is not numeric zero");
  return true;
}
function ownerQuestion31(source) {
  return `Authorize deployment of exact business backend ${source.commit} (tree ${source.tree}) to the existing 19 Functions in crm3-baf-ops-b8638/asia-south1, preserving Rules, indexes, IAM, App Check enforcement and scheduler controls, with no manual scheduler invocation, client signing or distribution?`;
}
function validateDecision31({decision, source, manifestSha256, nowUtc}) {
  keys(decision, ["schemaVersion", "documentType", "profile", "source", "sourceManifestSha256", "scope", "decidedAtUtc",
    "recordedAtUtc", "executionWindow", "ownerAuthorization", "mainCi", "securityCi", "runtimeProof", "preflightPointers", "schedulerBaseline"], "decision");
  need(decision.schemaVersion === 1 && decision.documentType === "build31-business-backend-deployment-decision" &&
    decision.profile === PROFILE && same(decision.source, source) && decision.sourceManifestSha256 === manifestSha256 &&
    same(decision.scope, SCOPE), "exact decision scope/source differs");
  keys(decision.executionWindow, ["notBeforeUtc", "notAfterUtc"], "window");
  const decided = instant(decision.decidedAtUtc), recorded = instant(decision.recordedAtUtc), now = instant(nowUtc);
  const start = instant(decision.executionWindow.notBeforeUtc), end = instant(decision.executionWindow.notAfterUtc);
  need(decided <= recorded && recorded <= start && start < end && end - start <= 6n * 3600n * 1000000000n &&
    recorded <= now, "decision chronology/window differs");
  for (const name of ["ownerAuthorization", "mainCi", "securityCi", "runtimeProof", "schedulerBaseline"]) pointer(decision[name]);
  keys(decision.preflightPointers, ["controls", "functionFleet", "iamDependencies", "firestoreRulesAndIndexes"], "preflight population");
  for (const value of Object.values(decision.preflightPointers)) pointer(value);
  return {decided, recorded};
}
function validateOwner31({owner, original, source, decisionAtUtc, lastCiAtUtc}) {
  keys(owner, ["schemaVersion", "documentType", "source", "scope", "authorizedAtUtc", "recordedAtUtc", "originalMessage"], "owner");
  need(owner.schemaVersion === 1 && owner.documentType === "build31-business-source-specific-owner-record" &&
    same(owner.source, source) && same(owner.scope, SCOPE), "owner source/scope differs"); pointer(owner.originalMessage);
  keys(original, ["schemaVersion", "documentType", "source", "question", "answer", "messageId", "conversationId",
    "receivedAtUtc", "provenance", "humanIdentityMachineAuthenticated"], "original owner message");
  need(original.schemaVersion === 1 && original.documentType === "retained-direct-human-production-deployment-instruction" &&
    same(original.source, source) && original.question === ownerQuestion31(source) && original.answer === "Approve exact-source production backend deployment" &&
    typeof original.messageId === "string" && original.messageId.trim().length > 0 && original.messageId.length <= 400 &&
    typeof original.conversationId === "string" && original.conversationId.trim().length > 0 && original.conversationId.length <= 400 &&
    original.provenance === "operator-retained-direct-human-message" && original.humanIdentityMachineAuthenticated === false,
    "retained original exact-source human instruction differs");
  need(instant(lastCiAtUtc) <= instant(original.receivedAtUtc) && instant(original.receivedAtUtc) === instant(owner.authorizedAtUtc) &&
    instant(owner.authorizedAtUtc) <= instant(owner.recordedAtUtc) && instant(owner.recordedAtUtc) <= instant(decisionAtUtc), "owner chronology differs");
}

function commandArguments31(kind, npmCliFile) {
  if (["root-install", "functions-install", "cli-install"].includes(kind)) return [npmCliFile, "ci", "--ignore-scripts", "--no-audit", "--fund=false",
    ...(kind === "root-install" ? [] : ["--prefix", kind === "functions-install" ? "functions" : "tooling/firebase-cli"])];
  if (kind === "installed-runtime") return [npmCliFile, "ls", "--omit=dev", "--all", "--long", "--json", "--prefix", "functions"];
  const script = {"functions-build": "build", "functions-host-tests": "test", "governed-emulator-tests": "emulator:test:governed",
    "dependency-compatibility": "test:dependency-compat"}[kind];
  need(script, "unknown runtime command");
  return [npmCliFile, "run", script, ...(kind.startsWith("functions-") ? ["--prefix", "functions"] : [])];
}
function auditArguments31(name, npmCliFile) {
  need(AUDITS.includes(name), "unknown audit population");
  return [npmCliFile, "audit", "--json", ...(name.endsWith("runtime") ? ["--omit=dev"] : []),
    ...(name.startsWith("functions") ? ["--prefix", "functions"] : name === "cli-full" ? ["--prefix", "tooling/firebase-cli"] : [])];
}
function verifyRecordedCommand31({record, source, kind, argv, root, runtime, start, end, evidenceDirectory}) {
  keys(record, ["schemaVersion", "documentType", "kind", "sourceBefore", "sourceAfter", "executable", "executableSha256",
    "argv", "cwd", "startedAtUtc", "completedAtUtc", "exitCode", "signal", "error", "stdout", "stderr"], "runtime command");
  need(record.schemaVersion === 1 && record.documentType === "build31-business-original-process" && record.kind === kind &&
    same(record.sourceBefore, source) && same(record.sourceAfter, source) && record.executable === runtime.nodeExecutable.path &&
    record.executableSha256 === runtime.nodeExecutable.sha256 && same(record.argv, argv) && regular(record.cwd, true) === root &&
    record.exitCode === 0 && record.signal === null && record.error === null, "original successful exact command differs");
  need(instant(start) <= instant(record.startedAtUtc) && instant(record.startedAtUtc) <= instant(record.completedAtUtc) &&
    instant(record.completedAtUtc) <= instant(end), "runtime command chronology differs");
  return {stdout: readPrivate(evidenceDirectory, record.stdout), stderr: readPrivate(evidenceDirectory, record.stderr)};
}
function fileMap31(root) {
  root = regular(root, true); const rows = {}; let count = 0, total = 0;
  function walk(directory) {
    for (const row of fs.readdirSync(directory, {withFileTypes: true})) {
      const full = path.join(directory, row.name); need(!row.isSymbolicLink(), "regular materialized files required");
      if (row.isDirectory()) walk(full);
      else { need(row.isFile(), "unsupported filesystem member"); const stat = fs.statSync(full);
        need(++count <= 100000 && (total += stat.size) <= 2 * 1024 * 1024 * 1024 && stat.size <= 128 * 1024 * 1024, "file population exceeds bound");
        const relative = path.relative(root, full).split(path.sep).join("/"); safeRelative(relative); rows[relative] = sha(fs.readFileSync(full)); }
    }
  }
  walk(root); return rows;
}
function verifyMaterializedSource31(root, snapshot) {
  root = regular(root, true); const seen = [];
  const skipped = new Set([".git", ".dart_tool", "node_modules", "functions/node_modules", "functions/lib", "tooling/firebase-cli/node_modules"]);
  function walk(directory, prefix = "") {
    for (const row of fs.readdirSync(directory, {withFileTypes: true})) {
      const rel = prefix + row.name, full = path.join(directory, row.name);
      need(!row.isSymbolicLink(), "source materialization redirects");
      if (skipped.has(rel)) { need(row.isDirectory(), "excluded build path must be a directory"); continue; }
      if (row.isDirectory()) walk(full, rel + "/");
      else {
        need(row.isFile() && Object.hasOwn(snapshot.files, rel), "unlisted materialized source");
        const size = fs.statSync(full).size; need(size <= 128 * 1024 * 1024, "materialized source too large");
        const bytes = fs.readFileSync(full), oid = crypto.createHash("sha1").update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest("hex");
        need(oid === snapshot.files[rel].oid, "materialized source bytes differ: " + rel); seen.push(rel);
      }
    }
  }
  walk(root); need(same(seen.sort(), Object.keys(snapshot.files).sort()), "complete materialized source population differs");
}
function expectedEmittedFiles31(snapshot, compilerConfig) {
  need(same(compilerConfig, {compilerOptions: {module: "commonjs", noImplicitReturns: true, noUnusedLocals: false,
    outDir: "lib", sourceMap: true, strict: true, target: "es2022"}, compileOnSave: true, include: ["src"]}), "compiler contract changed");
  const sources = Object.keys(snapshot.files).filter(file => file.startsWith("functions/src/"));
  need(sources.length > 0 && sources.every(file => file.endsWith(".ts")), "compiler source population differs");
  const outputs = sources.filter(file => !file.endsWith(".d.ts")).flatMap(file => {
    const base = "lib/" + file.slice("functions/src/".length, -3); return [base + ".js", base + ".js.map"]; }).sort();
  need(outputs.includes("lib/index.js") && new Set(outputs).size === outputs.length, "compiler output collision/missing entry");
  return outputs;
}
function verifyCandidateOutputs31({buildRoot, snapshot, compilerConfig, emittedFiles, evidenceDirectory}) {
  const expected = expectedEmittedFiles31(snapshot, compilerConfig);
  need(emittedFiles && same(Object.keys(emittedFiles).sort(), expected), "declared M emitted population differs");
  const actual = fileMap31(path.join(buildRoot, "functions/lib"));
  need(same(Object.keys(actual).map(p => "lib/" + p).sort(), expected), "actual M emitted population differs");
  for (const file of expected) need(sha(readPrivate(evidenceDirectory, emittedFiles[file])) === actual[file.slice(4)], "retained M output bytes differ");
  return expected.length;
}
function verifyRuntimeProof31({proof, source, snapshot, repository, evidenceDirectory, afterCi, beforeDecision}) {
  keys(proof, ["schemaVersion", "documentType", "profile", "source", "startedAtUtc", "completedAtUtc", "buildRoot", "runtime",
    "commands", "audits", "emittedFiles", "installedDependencies", "installedFiles"], "runtime proof");
  need(proof.schemaVersion === 1 && proof.documentType === "build31-business-runtime-proof" && proof.profile === PROFILE &&
    same(proof.source, source), "runtime source/profile differs");
  need(instant(afterCi) <= instant(proof.startedAtUtc) && instant(proof.startedAtUtc) <= instant(proof.completedAtUtc) &&
    instant(proof.completedAtUtc) <= instant(beforeDecision), "runtime proof chronology differs");
  const buildRoot = regular(proof.buildRoot, true); verifyMaterializedSource31(buildRoot, snapshot);
  const runtime = proof.runtime;
  keys(runtime, ["nodeVersion", "firebaseCliVersion", "nodeExecutable", "npmCliFile", "cliEntrypoint"], "runtime identity");
  const policy = json(repository.readBlob(source.commit, "release/production-release-policy.json"));
  need(runtime.nodeVersion === policy.toolchain.nodeVersion && runtime.firebaseCliVersion === "15.22.4", "runtime versions differ from source policy");
  for (const binding of [runtime.nodeExecutable, runtime.npmCliFile, runtime.cliEntrypoint]) {
    keys(binding, ["path", "sha256"], "executable binding"); need(hex(binding.sha256, 64) && sha(fs.readFileSync(regular(binding.path))) === binding.sha256,
      "actual runtime executable bytes differ");
  }
  need(regular(runtime.cliEntrypoint.path) === path.join(buildRoot, "tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js"), "CLI entrypoint differs");
  keys(proof.installedFiles, ["functions", "cli"], "installed file populations");
  for (const [kind, prefix] of [["functions", "functions/node_modules"], ["cli", "tooling/firebase-cli/node_modules"]])
    need(same(json(readPrivate(evidenceDirectory, proof.installedFiles[kind])), fileMap31(path.join(buildRoot, prefix))), "installed complete file population differs");
  need(json(fs.readFileSync(path.join(buildRoot, "tooling/firebase-cli/node_modules/firebase-tools/package.json"))).version === "15.22.4", "installed CLI version differs");
  keys(proof.commands, COMMANDS, "command population"); keys(proof.audits, AUDITS, "audit population");
  const common = {source, root: buildRoot, runtime, start: proof.startedAtUtc, end: proof.completedAtUtc, evidenceDirectory};
  let installedStdout;
  for (const kind of COMMANDS) {
    const record = json(readPrivate(evidenceDirectory, proof.commands[kind]));
    const output = verifyRecordedCommand31({...common, kind, record, argv: commandArguments31(kind, runtime.npmCliFile.path)});
    if (kind === "installed-runtime") installedStdout = output.stdout;
  }
  for (const name of AUDITS) {
    const item = proof.audits[name]; keys(item, ["report", "command"], "audit originals");
    const bytes = readPrivate(evidenceDirectory, item.report); verifyStrictAudit31(bytes);
    const output = verifyRecordedCommand31({...common, kind: "audit-" + name, record: json(readPrivate(evidenceDirectory, item.command)),
      argv: auditArguments31(name, runtime.npmCliFile.path)});
    need(bytes.equals(output.stdout), "audit report is not original command stdout");
  }
  const installedBytes = readPrivate(evidenceDirectory, proof.installedDependencies);
  need(installedBytes.equals(installedStdout), "installed graph is not original npm stdout");
  const installed = json(installedBytes), manifest = json(repository.readBlob(source.commit, "functions/package.json")),
    lock = json(repository.readBlob(source.commit, "functions/package-lock.json"));
  need(regular(installed.path, true) === path.join(buildRoot, "functions"), "installed graph root differs");
  const expected = require("./clientBuildToolingCompatibility31.cjs").runtimeReachability(manifest, lock);
  const rows = require("./backendRuntimeProof31.cjs").verifyInstalledGraph31(installed, manifest, lock, expected);
  const emittedFileCount = verifyCandidateOutputs31({buildRoot, snapshot,
    compilerConfig: json(repository.readBlob(source.commit, "functions/tsconfig.json")), emittedFiles: proof.emittedFiles, evidenceDirectory});
  return {buildRoot, runtime, emittedFileCount, installedRuntimePathCount: rows.size};
}

function subtreeOid31(files, prefix) {
  const root = new Map();
  for (const [file, identity] of Object.entries(files)) {
    if (!file.startsWith(prefix + "/")) continue;
    const parts = file.slice(prefix.length + 1).split("/"); let node = root;
    parts.forEach((part, index) => {
      if (index === parts.length - 1) { need(!node.has(part), "tree collision"); node.set(part, identity); }
      else { if (!node.has(part)) node.set(part, new Map()); need(node.get(part) instanceof Map, "tree prefix collision"); node = node.get(part); }
    });
  }
  need(root.size > 0, "required source subtree absent");
  function tree(node) {
    const names = [...node.keys()].sort((a, b) => Buffer.compare(Buffer.from(a + (node.get(a) instanceof Map ? "/" : "")),
      Buffer.from(b + (node.get(b) instanceof Map ? "/" : ""))));
    const bytes = Buffer.concat(names.map(name => {
      const item = node.get(name), directory = item instanceof Map;
      return Buffer.concat([Buffer.from(`${directory ? "40000" : item.mode} ${name}\0`), Buffer.from(directory ? tree(item) : item.oid, "hex")]);
    }));
    return crypto.createHash("sha1").update(Buffer.from(`tree ${bytes.length}\0`)).update(bytes).digest("hex");
  }
  return tree(root);
}
function verifyCustodyDelta31(source, custody) {
  const changed = [...new Set([...Object.keys(source.files), ...Object.keys(custody.files)])]
    .filter(file => !same(source.files[file], custody.files[file])).sort();
  need(custody.commit !== source.commit && same(changed, [DECISION_FILE]) && custody.files[DECISION_FILE]?.mode === "100644" &&
    (!source.files[DECISION_FILE] || source.files[DECISION_FILE].mode === "100644"), "decision custody must change only its named regular envelope");
}
function bindControlOriginals31({decision, source, evidenceDirectory, lastCiAtUtc}) {
  const pointers = {};
  for (const [kind, bound] of Object.entries(decision.preflightPointers)) {
    const envelope = json(readPrivate(evidenceDirectory, bound));
    keys(envelope, ["schemaVersion", "documentType", "source", "observedAtUtc", "capturedAtUtc", "measurement", "process"], "before-state envelope");
    need(envelope.schemaVersion === 1 && envelope.documentType === "build31-business-before-" + kind && same(envelope.source, source), "before-state source/kind differs");
    const observed = instant(envelope.observedAtUtc), captured = instant(envelope.capturedAtUtc), decided = instant(decision.decidedAtUtc);
    need(instant(lastCiAtUtc) <= observed && observed <= captured && captured <= decided && decided - observed <= 24n * 3600n * 1000000000n,
      "before-state source/time differs");
    json(readPrivate(evidenceDirectory, envelope.measurement));
    if (kind === "iamDependencies") json(readPrivate(evidenceDirectory, envelope.process));
    else need(envelope.process === null, "unexpected before-state process");
    pointers[kind] = {envelope: bound, measurement: envelope.measurement, process: envelope.process};
  }
  const scheduler = json(readPrivate(evidenceDirectory, decision.schedulerBaseline));
  keys(scheduler, ["schemaVersion", "documentType", "source", "observedAtUtc", "capturedAtUtc", "response"], "scheduler baseline");
  need(scheduler.schemaVersion === 1 && scheduler.documentType === "build31-business-scheduler-baseline" && same(scheduler.source, source) &&
    instant(lastCiAtUtc) <= instant(scheduler.observedAtUtc) && instant(scheduler.observedAtUtc) <= instant(scheduler.capturedAtUtc) &&
    instant(scheduler.capturedAtUtc) <= instant(decision.decidedAtUtc), "scheduler source/time differs");
  json(readPrivate(evidenceDirectory, scheduler.response));
  return {preflightPointers: pointers, schedulerBaseline: decision.schedulerBaseline};
}
function verifyBusiness31BackendAuthority(options) {
  keys(options, ["repositoryRoot", "gitExecutable", "gitSha256", "trustedVerifier", "sourceCommit", "sourceManifest",
    "trustedManifestSha256", "evidenceDirectory", "decisionPointer", "nowUtc"], "preparation input");
  const {repositoryRoot, gitExecutable, gitSha256, trustedVerifier, sourceCommit, sourceManifest,
    trustedManifestSha256, evidenceDirectory, decisionPointer, nowUtc} = options;
  instant(nowUtc); keys(trustedVerifier, ["commit", "tree", "files"], "trusted verifier");
  keys(decisionPointer, ["commit", "file", "sha256"], "decision custody pointer");
  need(decisionPointer.file === DECISION_FILE && hex(decisionPointer.commit, 40) && hex(decisionPointer.sha256, 64), "exact decision custody required");
  // Bootstrap code is an independently selected unprivileged entry, not loaded
  // from a path named by candidate evidence. Its own byte binding is checked below.
  const repository = require("./business31TrustedInput.cjs").openTrustedGitRepository31({repositoryRoot, gitExecutable, gitSha256});
  const verifier = repository.snapshot(trustedVerifier.commit), snapshot = repository.snapshot(sourceCommit), custody = repository.snapshot(decisionPointer.commit);
  need(verifier.tree === trustedVerifier.tree && snapshot.parents.length === 2, "verifier tree/normal source merge differs");
  repository.requireAncestor(verifier.commit, sourceCommit); repository.requireAncestor(sourceCommit, custody.commit);
  verifyCustodyDelta31(snapshot, custody);
  keys(trustedVerifier.files, PRODUCERS, "trusted producer population");
  for (const file of PRODUCERS) {
    const identity = verifier.files[file];
    need(identity?.mode === "100644" && same(identity, snapshot.files[file]) && same(identity, custody.files[file]), "producer identity/mode changed");
    const digest = trustedVerifier.files[file];
    need(hex(digest, 64) && sha(repository.readBlob(verifier.commit, file)) === digest.toUpperCase() &&
      sha(fs.readFileSync(regular(path.join(__dirname, path.basename(file))))) === digest.toUpperCase(), "executing producer differs from V");
  }
  for (const file of IMMUTABLE) need(repository.readBlob(IMMUTABLE_COMMIT, file).equals(repository.readBlob(verifier.commit, file)), "original immutable verifier changed");
  const measurement = require("./business31SourceAdmission.cjs").verifyBusiness31Source({repositoryRoot, gitExecutable, gitSha256,
    sourceCommit, manifest: sourceManifest, trustedManifestSha256});
  const source = {commit: snapshot.commit, tree: snapshot.tree, functionsTree: subtreeOid31(snapshot.files, "functions")};
  const rawEnvelope = repository.readBlob(custody.commit, DECISION_FILE);
  need(sha(rawEnvelope) === decisionPointer.sha256.toUpperCase(), "decision envelope Git bytes differ");
  const envelope = json(rawEnvelope);
  keys(envelope, ["schemaVersion", "documentType", "recordKind", "source", "recordedAtUtc", "privateRecord"], "public custody envelope");
  need(envelope.schemaVersion === 1 && envelope.documentType === "build31-business-private-record-custody" && envelope.recordKind === "decision" &&
    same(envelope.source, source), "decision envelope source/type differs");
  const decision = json(readPrivate(evidenceDirectory, envelope.privateRecord));
  validateDecision31({decision, source, manifestSha256: measurement.trustedManifestSha256, nowUtc});
  need(envelope.recordedAtUtc === decision.recordedAtUtc, "decision envelope timestamp differs");
  const release = json(readPrivate(evidenceDirectory, decision.mainCi)), security = json(readPrivate(evidenceDirectory, decision.securityCi));
  const {verifyCi31} = require("./backendRuntimeAdmission31.cjs");
  const releaseResult = verifyCi31(release, source, "release", decision.decidedAtUtc), securityResult = verifyCi31(security, source, "security", decision.decidedAtUtc);
  need(releaseResult.pullRequestNumber === securityResult.pullRequestNumber && release.pullRequest.head?.sha === snapshot.parents[1] &&
    security.pullRequest.head?.sha === snapshot.parents[1], "CI normal merge head differs");
  const lastCiAtUtc = [release.capturedAtUtc, security.capturedAtUtc].sort((a, b) => instant(a) < instant(b) ? -1 : instant(a) > instant(b) ? 1 : 0).at(-1);
  const owner = json(readPrivate(evidenceDirectory, decision.ownerAuthorization));
  validateOwner31({owner, original: json(readPrivate(evidenceDirectory, owner.originalMessage)), source,
    decisionAtUtc: decision.decidedAtUtc, lastCiAtUtc});
  const runtime = verifyRuntimeProof31({proof: json(readPrivate(evidenceDirectory, decision.runtimeProof)), source, snapshot, repository,
    evidenceDirectory, afterCi: lastCiAtUtc, beforeDecision: decision.decidedAtUtc});
  const controls = bindControlOriginals31({decision, source, evidenceDirectory, lastCiAtUtc});
  // The complete original control meanings, deployment captures and closure must
  // be replayed by the separate closed-chain adapter. Bound bytes alone cannot pass it.
  return Object.freeze({schemaVersion: 1, documentType: "build31-business-preparation-measurement", profile: PROFILE,
    source, sourceMeasurement: measurement, verifierCommit: verifier.commit, decisionPointer, originalDecision: envelope.privateRecord,
    executionWindow: decision.executionWindow, runtime, controlOriginals: controls,
    preparationOnly: true, sourceAndRecordBindingsVerified: true, rawControlSemanticsReplayed: false,
    privateClosedChainVerified: false, platformIdentityAuthenticated: false, humanIdentityAuthenticated: false,
    trustedClockAuthenticated: false, decisionCustodyTimestampAuthenticated: false,
    deploymentAuthorized: false, credentialAccessAuthorized: false, constructionAuthorized: false, distributionAuthorized: false});
}
module.exports = {PROFILE, DECISION_FILE, IMMUTABLE, PRODUCERS, SCOPE, AUDITS, COMMANDS,
  verifyBusiness31BackendAuthority, validateDecision31, validateOwner31, ownerQuestion31, verifyStrictAudit31,
  commandArguments31, auditArguments31, verifyRecordedCommand31, verifyCandidateOutputs31,
  expectedEmittedFiles31, verifyMaterializedSource31, subtreeOid31, verifyCustodyDelta31, bindControlOriginals31,
  readPrivate, instant};
