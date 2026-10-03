"use strict";
const test = require("node:test"), assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path"), os = require("node:os"), crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const subject = require("./business31BackendAuthority.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "business31-authority-"));
const evidenceDirectory = path.join(temporary, "evidence"); fs.mkdirSync(evidenceDirectory);
const source = {commit: "a".repeat(40), tree: "b".repeat(40), functionsTree: "c".repeat(40)};
let number = 0;
function retain(value) {
  const bytes = Buffer.isBuffer(value) ? value : Buffer.from(typeof value === "string" ? value : JSON.stringify(value));
  const file = `original-${++number}.json`; fs.writeFileSync(path.join(evidenceDirectory, file), bytes);
  return {file, bytes: bytes.length, sha256: sha(bytes)};
}
const dummy = retain("original fixture bytes; no authority");
function decision() { return {schemaVersion: 1, documentType: "build31-business-backend-deployment-decision", profile: subject.PROFILE,
  source: structuredClone(source), sourceManifestSha256: "D".repeat(64), scope: {...subject.SCOPE},
  decidedAtUtc: "2026-01-02T04:00:00Z", recordedAtUtc: "2026-01-02T04:01:00Z",
  executionWindow: {notBeforeUtc: "2026-01-02T04:02:00Z", notAfterUtc: "2026-01-02T06:00:00Z"},
  ownerAuthorization: {...dummy}, mainCi: {...dummy}, securityCi: {...dummy}, runtimeProof: {...dummy}, schedulerBaseline: {...dummy},
  preflightPointers: Object.fromEntries(["controls", "functionFleet", "iamDependencies", "firestoreRulesAndIndexes"].map(k => [k, {...dummy}]))}; }
function checkDecision(value) { return subject.validateDecision31({decision: value, source, manifestSha256: "D".repeat(64), nowUtc: "2026-01-02T05:00:00Z"}); }
function ownerPair() {
  const original = {schemaVersion: 1, documentType: "retained-direct-human-production-deployment-instruction", source: {...source},
    question: subject.ownerQuestion31(source), answer: "Approve exact-source production backend deployment", messageId: "synthetic-host-case", conversationId: "synthetic-host-case",
    receivedAtUtc: "2026-01-02T03:00:00Z", provenance: "operator-retained-direct-human-message", humanIdentityMachineAuthenticated: false};
  const owner = {schemaVersion: 1, documentType: "build31-business-source-specific-owner-record", source: {...source}, scope: {...subject.SCOPE},
    authorizedAtUtc: original.receivedAtUtc, recordedAtUtc: "2026-01-02T03:01:00Z", originalMessage: retain(original)};
  return {owner, original, source, decisionAtUtc: "2026-01-02T04:00:00Z", lastCiAtUtc: "2026-01-02T02:00:00Z"};
}
test.after(() => { assert.equal(path.dirname(temporary), fs.realpathSync(os.tmpdir())); fs.rmSync(temporary, {recursive: true, force: true}); });
test("strict decision measurement admits exact schema without creating operational authority", () => {
  assert.equal(checkDecision(decision()).decided, subject.instant("2026-01-02T04:00:00Z"));
  assert.equal(Object.hasOwn(checkDecision(decision()), "deploymentAuthorized"), false);
});
for (const [name, mutate] of [
  ["old grpc profile", d => d.profile = "build31-exact-grpc-runtime-backend-v1"],
  ["scope expansion", d => d.scope.iamMutation = true], ["different source", d => d.source.commit = "e".repeat(40)],
  ["different manifest", d => d.sourceManifestSha256 = "E".repeat(64)], ["unknown pass", d => d.approved = true],
  ["signing metadata dependency", d => d.signingSource = source], ["missing original CI", d => delete d.mainCi],
  ["missing controls", d => delete d.preflightPointers.controls], ["long execution window", d => d.executionWindow.notAfterUtc = "2026-01-03T06:00:00Z"],
  ["future record", d => d.recordedAtUtc = "2027-01-01T00:00:00Z"], ["invalid calendar", d => d.decidedAtUtc = "2026-02-30T00:00:00Z"],
  ["path traversal", d => d.runtimeProof.file = "../raw.json"], ["drive path", d => d.runtimeProof.file = "C:/raw.json"],
]) test("refuses " + name, () => { const d = decision(); mutate(d); assert.throws(() => checkDecision(d)); });
test("original owner chronology is explicit; host fixture does not authenticate a human", () => subject.validateOwner31(ownerPair()));
for (const [name, mutate] of [
  ["preparation-only instruction", p => p.original.answer = "Approve source preparation only"],
  ["other exact source", p => p.original.source.commit = "f".repeat(40)],
  ["old scope question", p => p.original.question = "Approve gRPC runtime only"],
  ["fabricated machine identity", p => p.original.humanIdentityMachineAuthenticated = true],
  ["pre-CI instruction", p => p.original.receivedAtUtc = p.owner.authorizedAtUtc = "2026-01-02T01:00:00Z"],
  ["owner time after decision", p => p.owner.recordedAtUtc = "2026-01-02T05:00:00Z"],
]) test("refuses owner " + name, () => { const p = ownerPair(); mutate(p); assert.throws(() => subject.validateOwner31(p)); });
function cleanAudit() { return {auditReportVersion: 2, vulnerabilities: {}, metadata: {vulnerabilities: {info: 0, low: 0, moderate: 0, high: 0, critical: 0, total: 0}}}; }
test("original audit has numeric zero counts; no summary or exception substitutes", () => {
  assert.equal(subject.verifyStrictAudit31(Buffer.from(JSON.stringify(cleanAudit()))), true);
  for (const mutate of [a => a.metadata.vulnerabilities.total = "0", a => a.error = {}, a => a.vulnerabilities.issue = {},
    a => a.metadata.vulnerabilities.high = 1, a => delete a.auditReportVersion]) {
    const value = cleanAudit(); mutate(value); assert.throws(() => subject.verifyStrictAudit31(Buffer.from(JSON.stringify(value))));
  }
  assert.throws(() => subject.verifyStrictAudit31(Buffer.from('{"pass":true}')));
});
test("private originals are exact size/hash and confined; empty process stderr is legitimate", () => {
  assert.equal(subject.readPrivate(evidenceDirectory, dummy).toString(), "original fixture bytes; no authority");
  assert.equal(subject.readPrivate(evidenceDirectory, retain("")).length, 0);
  for (const bad of [{...dummy, bytes: 1}, {...dummy, sha256: "F".repeat(64)}, {...dummy, file: "x/../raw"},
    {...dummy, file: "raw\\other"}, {...dummy, file: "NUL.json"}, {...dummy, file: "raw."}, {...dummy, unknown: 1}])
    assert.throws(() => subject.readPrivate(evidenceDirectory, bad));
});
const config = {compilerOptions: {module: "commonjs", noImplicitReturns: true, noUnusedLocals: false, outDir: "lib", sourceMap: true, strict: true, target: "es2022"}, compileOnSave: true, include: ["src"]};
const blob = bytes => crypto.createHash("sha1").update(Buffer.from(`blob ${Buffer.byteLength(bytes)}\0`)).update(bytes).digest("hex");
test("new M output population may differ from F; every actual M byte and map is still required", () => {
  const root = path.join(temporary, "candidate"); fs.mkdirSync(path.join(root, "functions/lib"), {recursive: true});
  const snapshot = {files: {"functions/src/index.ts": {}, "functions/src/newBusiness.ts": {}, "functions/src/types.d.ts": {}}};
  const expected = subject.expectedEmittedFiles31(snapshot, config);
  assert.deepEqual(expected, ["lib/index.js", "lib/index.js.map", "lib/newBusiness.js", "lib/newBusiness.js.map"]);
  const emittedFiles = {};
  for (const file of expected) { const bytes = "new source-specific business output " + file; fs.writeFileSync(path.join(root, "functions", file), bytes); emittedFiles[file] = retain(bytes); }
  const check = value => subject.verifyCandidateOutputs31({buildRoot: root, snapshot, compilerConfig: config, emittedFiles: value, evidenceDirectory});
  assert.equal(check(emittedFiles), 4);
  assert.throws(() => check({...emittedFiles, "lib/unknown.js": dummy}), /population/);
  const missing = {...emittedFiles}; delete missing[expected[0]]; assert.throws(() => check(missing), /population/);
  fs.writeFileSync(path.join(root, "functions/lib/index.js"), "stale original F output"); assert.throws(() => check(emittedFiles), /bytes differ/);
  fs.writeFileSync(path.join(root, "functions/lib/orphan.js"), "orphan"); assert.throws(() => check(emittedFiles), /population/);
  assert.throws(() => subject.expectedEmittedFiles31(snapshot, {...config, exclude: ["src/newBusiness.ts"]}), /compiler/);
});
test("materialization must match complete Git blob content, including newline bytes and no unknown source", () => {
  const root = path.join(temporary, "material"); fs.mkdirSync(root); fs.writeFileSync(path.join(root, "source.txt"), "original\n");
  const snapshot = {files: {"source.txt": {mode: "100644", oid: blob("original\n")}}};
  subject.verifyMaterializedSource31(root, snapshot);
  fs.writeFileSync(path.join(root, "source.txt"), "original\r\n"); assert.throws(() => subject.verifyMaterializedSource31(root, snapshot), /bytes differ/);
  fs.writeFileSync(path.join(root, "source.txt"), "original\n"); fs.writeFileSync(path.join(root, "unlisted.txt"), "extra");
  assert.throws(() => subject.verifyMaterializedSource31(root, snapshot), /unlisted/);
});

test("original process requires exact successful argv/source and retains both streams", () => {
  const runtime = {nodeExecutable: {path: process.execPath, sha256: sha(fs.readFileSync(process.execPath))}, npmCliFile: {path: "/fixture/npm-cli.js"}};
  const argv = subject.commandArguments31("functions-build", runtime.npmCliFile.path);
  const record = {schemaVersion: 1, documentType: "build31-business-original-process", kind: "functions-build", sourceBefore: {...source}, sourceAfter: {...source},
    executable: runtime.nodeExecutable.path, executableSha256: runtime.nodeExecutable.sha256, argv, cwd: temporary,
    startedAtUtc: "2026-01-02T02:10:00Z", completedAtUtc: "2026-01-02T02:11:00Z", exitCode: 0, signal: null, error: null,
    stdout: retain("original process output"), stderr: retain("")};
  const check = value => subject.verifyRecordedCommand31({record: value, source, kind: "functions-build", argv, root: temporary, runtime,
    start: "2026-01-02T02:00:00Z", end: "2026-01-02T03:00:00Z", evidenceDirectory});
  assert.equal(check(record).stdout.toString(), "original process output");
  for (const mutate of [r => r.argv.push("--force"), r => r.exitCode = 1, r => r.error = "original failure", r => r.signal = "SIGTERM",
    r => r.sourceAfter.tree = "d".repeat(40), r => r.completedAtUtc = "2026-01-02T05:00:00Z", r => r.stdout = {...dummy, sha256: "0".repeat(64)}]) {
    const copy = structuredClone(record); mutate(copy); assert.throws(() => check(copy));
  }
  assert.throws(() => subject.commandArguments31("deploy", runtime.npmCliFile.path));
  assert.deepEqual(subject.auditArguments31("functions-runtime", "npm"), ["npm", "audit", "--json", "--omit=dev", "--prefix", "functions"]);
});
test("raw controls are bound and fresh, never claimed semantically replayed by this adapter", () => {
  const d = decision();
  for (const kind of Object.keys(d.preflightPointers)) d.preflightPointers[kind] = retain({schemaVersion: 1, documentType: "build31-business-before-" + kind,
    source, observedAtUtc: "2026-01-02T02:15:00Z", capturedAtUtc: "2026-01-02T02:16:00Z",
    measurement: retain({raw: "unadjudicated synthetic control"}), process: kind === "iamDependencies" ? retain({original: "process envelope"}) : null});
  d.schedulerBaseline = retain({schemaVersion: 1, documentType: "build31-business-scheduler-baseline", source,
    observedAtUtc: "2026-01-02T02:15:00Z", capturedAtUtc: "2026-01-02T02:16:00Z", response: retain({raw: "scheduler response"})});
  const check = value => subject.bindControlOriginals31({decision: value, source, evidenceDirectory, lastCiAtUtc: "2026-01-02T02:00:00Z"});
  assert.deepEqual(Object.keys(check(d).preflightPointers).sort(), ["controls", "firestoreRulesAndIndexes", "functionFleet", "iamDependencies"]);
  const original = JSON.parse(subject.readPrivate(evidenceDirectory, d.preflightPointers.controls));
  for (const mutate of [v => v.source = {...source, commit: "f".repeat(40)}, v => v.observedAtUtc = "2026-01-01T00:00:00Z", v => v.capturedAtUtc = "2026-01-02T05:00:00Z",
    v => v.measurement.sha256 = "0".repeat(64), v => v.process = dummy]) {
    const copy = structuredClone(original); mutate(copy); assert.throws(() => check({...d, preflightPointers: {...d.preflightPointers, controls: retain(copy)}}));
  }
});
test("decision custody is a distinct finite predeployment delta, not signing metadata S", () => {
  const sourceSnapshot = {commit: "a".repeat(40), files: {"functions/index.js": {mode: "100644", oid: "b".repeat(40)}}};
  const custody = {commit: "c".repeat(40), files: {...sourceSnapshot.files, [subject.DECISION_FILE]: {mode: "100644", oid: "d".repeat(40)}}};
  subject.verifyCustodyDelta31(sourceSnapshot, custody);
  for (const mutate of [c => c.commit = sourceSnapshot.commit, c => c.files[subject.DECISION_FILE].mode = "100755",
    c => c.files["functions/index.js"].oid = "e".repeat(40), c => c.files["pubspec.yaml"] = {mode: "100644", oid: "e".repeat(40)}]) {
    const copy = structuredClone(custody); mutate(copy); assert.throws(() => subject.verifyCustodyDelta31(sourceSnapshot, copy));
  }
});
test("subtree identity is actual Git tree hashing, including directory/file ordering", () => {
  const repository = path.join(temporary, "git"); fs.mkdirSync(repository);
  const git = process.env.BUSINESS31_TEST_GIT || (process.platform === "win32" ? "C:/Program Files/Git/mingw64/bin/git.exe" : "/usr/bin/git");
  const env = {...process.env, GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: process.platform === "win32" ? "NUL" : "/dev/null"};
  for (const k of Object.keys(env)) if (/^GIT_(?:DIR|WORK_TREE|INDEX_FILE|CONFIG_COUNT|CONFIG_KEY_|CONFIG_VALUE_|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES)/.test(k)) delete env[k];
  const call = (args, input) => execFileSync(git, ["-c", "core.autocrlf=false", "-c", "core.hooksPath=" + path.join(temporary, "no-hooks"), "-C", repository, ...args],
    {env, input, encoding: "utf8", windowsHide: true, timeout: 30000}).trim();
  call(["init", "--initial-branch=main"]); const files = {};
  for (const name of ["functions/index.ts", "functions/sub-dir/a.ts", "functions/sub-dir.z", "other.txt"]) {
    const oid = call(["hash-object", "-w", "--stdin"], "literal\n"), mode = name.endsWith(".z") ? "100755" : "100644";
    call(["update-index", "--add", "--cacheinfo", `${mode},${oid},${name}`]); files[name] = {mode, oid};
  }
  const actualTree = call(["write-tree"]);
  assert.equal(subject.subtreeOid31(files, "functions"), call(["rev-parse", actualTree + ":functions"]));
  assert.throws(() => subject.subtreeOid31(files, "absent"), /absent/);
});
test("entrypoint refuses caller substitutes before any evidence or operational action", () => {
  assert.throws(() => subject.verifyBusiness31BackendAuthority({approved: true}), /preparation input/);
  assert.equal(subject.PROFILE, "build31-exact-business-backend-v1");
  assert.equal(subject.SCOPE.businessLogicChanged, true); assert.equal(subject.SCOPE.existingFunctionCount, 19);
  assert.equal(subject.IMMUTABLE.length, 14);
});

// This is a complete parser/composition fixture, never a real approval, npm
// process, CI run, control observation or deployment. Real historical F/406
// objects are imported locally because the production entrypoint pins them.
test("complete entry composes real Git V/M/C and synthetic originals without operational authority", {timeout: 360000}, () => {
  const repositoryRoot = path.join(temporary, "whole-entry"), fixtureSource = "6a0bd1a6b3b8de85a92187e84d621ae9bbf222b5";
  const gitExecutable = process.env.BUSINESS31_TEST_GIT || (process.platform === "win32" ? "C:/Program Files/Git/mingw64/bin/git.exe" : "/usr/bin/git");
  const env = {...process.env}; for (const key of Object.keys(env)) if (/^GIT_/i.test(key)) delete env[key];
  Object.assign(env, {GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: process.platform === "win32" ? "NUL" : "/dev/null", GIT_TERMINAL_PROMPT: "0",
    GIT_AUTHOR_NAME: "Synthetic local fixture", GIT_AUTHOR_EMAIL: "fixture@example.invalid", GIT_COMMITTER_NAME: "Synthetic local fixture",
    GIT_COMMITTER_EMAIL: "fixture@example.invalid", GIT_AUTHOR_DATE: "2026-01-02T04:02:00Z", GIT_COMMITTER_DATE: "2026-01-02T04:02:00Z"});
  const args = ["-c", "core.autocrlf=false", "-c", "commit.gpgsign=false", "-c", "protocol.allow=never", "-c", "protocol.file.allow=always",
    "-c", "core.hooksPath=" + path.join(temporary, "absent-hooks")];
  execFileSync(gitExecutable, [...args, "clone", "--no-local", "--no-checkout", path.resolve(__dirname, "../.."), repositoryRoot],
    {env, windowsHide: true, timeout: 60000, stdio: ["ignore", "pipe", "pipe"]});
  const git = (commands, input) => execFileSync(gitExecutable, [...args, "-C", repositoryRoot, ...commands],
    {env, input, encoding: "utf8", windowsHide: true, timeout: 30000, stdio: ["pipe", "pipe", "pipe"]}).trim();
  assert.equal(fs.lstatSync(path.join(repositoryRoot, ".git")).isDirectory(), true);
  assert.equal(fs.existsSync(path.join(repositoryRoot, ".git/objects/info/alternates")), false);
  assert.equal(fs.existsSync(path.join(repositoryRoot, ".git/shallow")), false);
  const put = (name, bytes) => { const oid = git(["hash-object", "-w", "--stdin"], bytes); git(["update-index", "--add", "--cacheinfo", `100644,${oid},${name}`]); };
  const commit = parents => git(["commit-tree", git(["write-tree"]), ...parents.flatMap(p => ["-p", p]), "-m", "Synthetic local preparation fixture only"]);
  git(["read-tree", fixtureSource]);
  const producerBindings = {};
  for (const name of subject.PRODUCERS) { const bytes = fs.readFileSync(path.join(__dirname, path.basename(name))); put(name, bytes); producerBindings[name] = sha(bytes); }
  const V = commit([fixtureSource]);
  put("fixture-main.txt", "synthetic main parent\n"); const main = commit([V]);
  git(["read-tree", V]); put("fixture-branch.txt", "synthetic reviewed parent\n"); const branch = commit([V]);
  git(["read-tree", main]); put("fixture-branch.txt", "synthetic reviewed parent\n"); const M = commit([main, branch]);
  git(["checkout", "--force", "--detach", M]);
  const options = {repositoryRoot, gitExecutable, gitSha256: sha(fs.readFileSync(gitExecutable))};
  const repository = require("./business31TrustedInput.cjs").openTrustedGitRepository31(options);
  const admission = require("./business31SourceAdmission.cjs"), baseline = repository.snapshot(admission.BASELINE), snapshot = repository.snapshot(M);
  for (const file of Object.keys(snapshot.files)) assert.equal(fs.existsSync(path.join(repositoryRoot, file)), true, "Fixture checkout omitted " + file);
  const protectedRows = snapshotValue => Object.fromEntries(Object.keys(snapshotValue.files).sort()
    .filter(file => admission.PROTECTED_ROOTS.some(root => file === root || file.startsWith(root + "/")))
    .map(file => [file, snapshotValue.files[file]]));
  const before = protectedRows(baseline), after = protectedRows(snapshot);
  const sourceManifest = {schemaVersion: 1, documentType: "build31-business-source-inventory", profile: admission.PROFILE,
    baseline: {commit: baseline.commit, tree: baseline.tree, protectedPopulationSha256: sha(admission.canonical(before))},
    source: {commit: M, tree: snapshot.tree, protectedPopulationSha256: sha(admission.canonical(after))}, protectedRoots: [...admission.PROTECTED_ROOTS],
    protectedDelta: [...new Set([...Object.keys(before), ...Object.keys(after)])].sort().filter(file => JSON.stringify(before[file]) !== JSON.stringify(after[file]))
      .map(file => ({path: file, before: before[file] || null, after: after[file] || null})),
    dependencySha256: Object.fromEntries(admission.DEPENDENCIES.map(file => [file, sha(repository.readBlob(M, file))]))};
  const trustedManifestSha256 = sha(admission.canonical(sourceManifest));
  const source = {commit: M, tree: snapshot.tree, functionsTree: subject.subtreeOid31(snapshot.files, "functions")};
  const read = file => JSON.parse(repository.readBlob(M, file));
  const manifest = read("functions/package.json"), lock = read("functions/package-lock.json");
  const expectedGraph = require("./clientBuildToolingCompatibility31.cjs").runtimeReachability(manifest, lock);
  const functionsRoot = path.join(repositoryRoot, "functions");
  for (const [relative, row] of Object.entries(expectedGraph)) {
    const directory = path.join(functionsRoot, relative); fs.mkdirSync(directory, {recursive: true});
    const pkg = {name: row.name || relative.slice(relative.lastIndexOf("node_modules/") + 13), version: row.version};
    for (const name of ["dependencies", "optionalDependencies", "peerDependencies", "peerDependenciesMeta"]) if (row[name]) pkg[name] = row[name];
    fs.writeFileSync(path.join(directory, "package.json"), JSON.stringify(pkg));
  }
  function nearest(from, name) { let cur = from; while (true) {
    if (path.posix.basename(cur) !== "node_modules") { const key = (cur ? cur + "/" : "") + "node_modules/" + name; if (lock.packages[key]) return key; }
    if (!cur) return null; cur = path.posix.dirname(cur); if (cur === ".") cur = "";
  } }
  const expanded = new Set();
  function npmRow(relative, pkg) {
    const result = {name: pkg.name || manifest.name, version: pkg.version, path: path.join(functionsRoot, relative)};
    if (expanded.has(relative)) return result; expanded.add(relative); result.dependencies = {};
    for (const name of Object.keys({...pkg.dependencies, ...pkg.optionalDependencies, ...(relative ? pkg.peerDependencies : {})})) {
      const child = nearest(relative, name); if (child !== null && expectedGraph[child]) result.dependencies[name] = npmRow(child, expectedGraph[child]);
    }
    return result;
  }
  const installed = npmRow("", manifest), installedBytes = Buffer.from(JSON.stringify(installed));
  const cliRoot = path.join(repositoryRoot, "tooling/firebase-cli/node_modules/firebase-tools"); fs.mkdirSync(path.join(cliRoot, "lib/bin"), {recursive: true});
  fs.writeFileSync(path.join(cliRoot, "package.json"), '{"name":"firebase-tools","version":"15.22.4"}');
  fs.writeFileSync(path.join(cliRoot, "lib/bin/firebase.js"), "// synthetic inert file; never executed\n");
  const npmFile = path.join(temporary, "inert-npm-cli.js"); fs.writeFileSync(npmFile, "// synthetic inert file; never executed\n");
  const binding = file => ({path: file, sha256: sha(fs.readFileSync(file))});
  const runtime = {nodeVersion: read("release/production-release-policy.json").toolchain.nodeVersion, firebaseCliVersion: "15.22.4",
    nodeExecutable: binding(process.execPath), npmCliFile: binding(npmFile), cliEntrypoint: binding(path.join(cliRoot, "lib/bin/firebase.js"))};
  function map(directory) { const rows = {}; function walk(dir) { for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, item.name); if (item.isDirectory()) walk(full); else rows[path.relative(directory, full).split(path.sep).join("/")] = sha(fs.readFileSync(full));
  } } walk(directory); return rows; }
  function processRecord(kind, argv, stdout = Buffer.from("synthetic original stdout; no process executed")) {
    return retain({schemaVersion: 1, documentType: "build31-business-original-process", kind, sourceBefore: source, sourceAfter: source,
      executable: runtime.nodeExecutable.path, executableSha256: runtime.nodeExecutable.sha256, argv, cwd: repositoryRoot,
      startedAtUtc: "2026-01-02T02:10:00Z", completedAtUtc: "2026-01-02T02:11:00Z", exitCode: 0, signal: null, error: null, stdout: retain(stdout), stderr: retain("")});
  }
  const emittedFiles = {};
  for (const file of subject.expectedEmittedFiles31(snapshot, read("functions/tsconfig.json"))) {
    const full = path.join(functionsRoot, file), bytes = Buffer.from("synthetic compiler output, not executed: " + file);
    fs.mkdirSync(path.dirname(full), {recursive: true}); fs.writeFileSync(full, bytes); emittedFiles[file] = retain(bytes);
  }
  const proof = {schemaVersion: 1, documentType: "build31-business-runtime-proof", profile: subject.PROFILE, source,
    startedAtUtc: "2026-01-02T02:05:00Z", completedAtUtc: "2026-01-02T02:30:00Z", buildRoot: repositoryRoot, runtime,
    commands: Object.fromEntries(subject.COMMANDS.map(kind => [kind, processRecord(kind, subject.commandArguments31(kind, npmFile), kind === "installed-runtime" ? installedBytes : undefined)])),
    audits: Object.fromEntries(subject.AUDITS.map(kind => { const raw = Buffer.from(JSON.stringify(cleanAudit())); return [kind, {report: retain(raw), command: processRecord("audit-" + kind, subject.auditArguments31(kind, npmFile), raw)}]; })),
    emittedFiles, installedDependencies: retain(installedBytes), installedFiles: {functions: retain(map(path.join(functionsRoot, "node_modules"))), cli: retain(map(path.join(repositoryRoot, "tooling/firebase-cli/node_modules")))}};
  const ciModule = require("./backendRuntimeAdmission31.cjs"), repositoryName = "abhishekvatsa/crm3_baf_ops";
  function ci(kind, id) {
    const jobNames = kind === "release" ? ciModule.RELEASE_JOBS : ciModule.SECURITY_JOBS;
    return retain({schemaVersion: 1, evidenceType: kind === "release" ? "github-exact-main-release-gate" : "github-exact-main-codeql", repository: repositoryName,
      sourceCommit: M, sourceTree: source.tree, capturedAtUtc: "2026-01-02T02:00:00Z",
      pullRequest: {number: 999, merged: true, merge_commit_sha: M, merged_at: "2026-01-02T00:00:00Z", head: {sha: branch}, base: {ref: "main", repo: {full_name: repositoryName}}},
      run: {id, run_attempt: 1, repository: {full_name: repositoryName}, head_sha: M, head_branch: "main", event: "push", path: kind === "release" ? ".github/workflows/release-gate.yml" : ".github/workflows/codeql.yml",
        status: "completed", conclusion: "success", created_at: "2026-01-02T00:01:00Z", updated_at: "2026-01-02T01:00:00Z"},
      jobs: {total_count: jobNames.length, jobs: jobNames.map((name, i) => ({id: id * 10 + i, run_id: id, run_attempt: 1, head_sha: M, name,
        status: "completed", conclusion: "success", completed_at: "2026-01-02T00:50:00Z"}))}});
  }
  const original = {...ownerPair().original, source, question: subject.ownerQuestion31(source)};
  const owner = {...ownerPair().owner, source, originalMessage: retain(original)};
  const d = {...decision(), source, sourceManifestSha256: trustedManifestSha256, ownerAuthorization: retain(owner), mainCi: ci("release", 10), securityCi: ci("security", 20), runtimeProof: retain(proof)};
  for (const kind of Object.keys(d.preflightPointers)) d.preflightPointers[kind] = retain({schemaVersion: 1, documentType: "build31-business-before-" + kind,
    source, observedAtUtc: "2026-01-02T02:40:00Z", capturedAtUtc: "2026-01-02T02:41:00Z", measurement: retain({fixture: "unadjudicated control original"}), process: kind === "iamDependencies" ? retain({fixture: "original process"}) : null});
  d.schedulerBaseline = retain({schemaVersion: 1, documentType: "build31-business-scheduler-baseline", source, observedAtUtc: "2026-01-02T02:40:00Z", capturedAtUtc: "2026-01-02T02:41:00Z", response: retain({fixture: "scheduler response"})});
  const privateRecord = retain(d), envelope = Buffer.from(JSON.stringify({schemaVersion: 1, documentType: "build31-business-private-record-custody", recordKind: "decision", source, recordedAtUtc: d.recordedAtUtc, privateRecord}));
  put(subject.DECISION_FILE, envelope); const C = commit([M]);
  const input = {...options, trustedVerifier: {commit: V, tree: git(["rev-parse", V + "^{tree}"]), files: producerBindings}, sourceCommit: M, sourceManifest,
    trustedManifestSha256, evidenceDirectory, decisionPointer: {commit: C, file: subject.DECISION_FILE, sha256: sha(envelope)}, nowUtc: "2026-01-02T05:00:00Z"};
  const result = subject.verifyBusiness31BackendAuthority(input);
  assert.equal(result.preparationOnly, true); assert.equal(result.sourceAndRecordBindingsVerified, true); assert.deepEqual(result.source, source);
  assert.equal(result.runtime.emittedFileCount, 252); assert.ok(result.runtime.installedRuntimePathCount > 100);
  for (const key of ["rawControlSemanticsReplayed", "privateClosedChainVerified", "platformIdentityAuthenticated", "humanIdentityAuthenticated", "trustedClockAuthenticated",
    "decisionCustodyTimestampAuthenticated", "deploymentAuthorized", "credentialAccessAuthorized", "constructionAuthorized", "distributionAuthorized"]) assert.equal(result[key], false, key);
  assert.equal(Object.hasOwn(result, "ok"), false);
  const changed = structuredClone(input); changed.trustedVerifier.files["tools/release/business31BackendAuthority.cjs"] = "0".repeat(64);
  assert.throws(() => subject.verifyBusiness31BackendAuthority(changed), /executing producer differs/);
  fs.appendFileSync(path.join(evidenceDirectory, privateRecord.file), " ");
  assert.throws(() => subject.verifyBusiness31BackendAuthority(input), /private byte count differs/);
});
