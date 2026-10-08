"use strict";
// Inert SDK/CLI-shaped modules exercise real fixed-worker and owned-process
// wiring. They are not Firebase SDK discovery, installed-CLI or release proof.
const test = require("node:test"), assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path"), os = require("node:os"), crypto = require("node:crypto");
const subject = require("./prepareBusinessIntent31.cjs");
const sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const source = { commit: "1".repeat(40), tree: "2".repeat(40), functionsTree: "3".repeat(40) }, PARAM = "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK";
const names = Array.from({ length: 19 }, (_, i) => "inertFunction" + String(i).padStart(2, "0"));
const suiteRoot = fs.mkdtempSync(path.join(os.tmpdir(), "business31-intent-tests-"));
function write(file, value) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === "string" || Buffer.isBuffer(value) ? value : JSON.stringify(value, null, 2) + "\n", { flag: "wx" });
    return file;
}
function map(root) {
    const rows = [];
    function walk(dir, prefix = "") {
        for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
            assert(!e.isSymbolicLink());
            const n = prefix + e.name, p = path.join(dir, e.name);
            if (e.isDirectory())
                walk(p, n + "/");
            else {
                assert(e.isFile());
                rows.push([n, sha(fs.readFileSync(p))]);
            }
        }
    }
    walk(root);
    return Object.fromEntries(rows);
}
function binding(file) {
    return { path: file, sha256: sha(fs.readFileSync(file)) };
}
function manifest() {
    return { specVersion: "v1alpha1", params: [{ name: PARAM, type: "boolean", default: false }], endpoints: Object.fromEntries(names.map(id => [id, { platform: "gcfv2", region: ["asia-south1"], callableTrigger: {} }])) };
}
function originals() {
    return { project: {
            schemaVersion: 1, documentType: "build31-business-original-admin-sdk-config", source, observedAtUtc: "2026-01-01T00:00:01Z", request: { method: "GET", url: "https://firebase.googleapis.com/v1beta1/projects/crm3-baf-ops-b8638/adminSdkConfig" }, response: { httpStatus: 200, bodyText: JSON.stringify({ projectId: "crm3-baf-ops-b8638", storageBucket: "synthetic.invalid" }) }
        }, parameters: {
            schemaVersion: 1, documentType: "build31-business-intent-parameters", source, parameters: { [PARAM]: "false" }
        } };
}
function validateOriginals(v = originals()) {
    return subject.validateInputOriginals31({
        projectConfigOriginal: Buffer.from(JSON.stringify(v.project)), parametersOriginal: Buffer.from(JSON.stringify(v.parameters)), source, earliestUtc: "2026-01-01T00:00:00Z", latestUtc: "2026-01-01T00:00:02Z"
    });
}
test("finite original nonsecret inputs preserve supplied configuration without invention", () => {
    assert.equal(validateOriginals().firebaseConfig.storageBucket, "synthetic.invalid");
});
test("missing project configuration response refuses", () => {
    const v = originals();
    delete v.project.response;
    assert.throws(() => validateOriginals(v), /fields differ/);
});
test("unknown or secret parameters refuse", () => {
    const v = originals();
    v.parameters.parameters.SECRET = "x";
    assert.throws(() => validateOriginals(v), /finite nonsecret parameters/);
});
test("original configuration must follow runtime and precede preparation", () => {
    const v = originals();
    v.project.observedAtUtc = "2026-01-01T00:00:03Z";
    assert.throws(() => validateOriginals(v), /chronology/);
});
test("explicit fleet regions and supported manifest pass", () => {
    assert.equal(subject.validateManifest31(manifest(), names).specVersion, "v1alpha1");
});
for (const [label, alter, pattern] of [
    ["implicit region", m => delete m.endpoints[names[0]].region, /implicit region/],
    ["unknown parameter", m => m.params.push({ name: "NEW", type: "string" }), /unknown or secret/],
    ["secret endpoint", m => m.endpoints[names[0]].secretEnvironmentVariables = [{ key: "KEY" }], /secret endpoint/],
    ["unsupported trigger", m => {
            delete m.endpoints[names[0]].callableTrigger;
            m.endpoints[names[0]].taskQueueTrigger = {};
        }, /unsupported endpoint trigger/],
    ["extensions", m => m.extensions = { newExtension: {} }, /dynamic extensions/],
])
    test(label + " refuses before packaging", () => {
        const m = manifest();
        alter(m);
        assert.throws(() => subject.validateManifest31(m, names), pattern);
    });
test("source and generated Functions maps cannot overlap", () => {
    assert.throws(() => subject.admittedFunctionsMap31({ sourceFiles: { "functions/lib/index.js": "A" }, installedFiles: { functions: {} }, emittedFiles: { "lib/index.js": "A" } }), /overlapping/);
});
const python = process.env.BUSINESS31_TEST_PYTHON ?? "C:/Python313/python.exe";
const ownedAvailable = process.platform === "win32" && fs.existsSync(python);
const ownedOptions = { skip: ownedAvailable ? false : "Windows owned-process fixture requires an explicitly available Python runtime" };
let selectedPython;
function pythonInstallation() {
    if (!selectedPython) {
        const root = path.dirname(path.resolve(python));
        // Local test measurement only, never an approved production interpreter.
        selectedPython = { schemaVersion: 2, root, executable: binding(python), files: map(root) };
    }
    return selectedPython;
}
function inertPython(label) {
    const root = path.join(suiteRoot, "python-" + label, "installation");
    for (const name of ["python.exe", "python313.dll", "python3.dll", "Lib/os.py", "Lib/encodings/__init__.py"]) {
        write(path.join(root, name), "Inert test bytes; must never execute: " + name);
    }
    fs.mkdirSync(path.join(root, "DLLs"));
    return { schemaVersion: 2, root, executable: binding(path.join(root, "python.exe")), files: map(root) };
}
for (const [label, alter, pattern] of [
    ["caller-subset", p => delete p.files["Lib/os.py"], /standard Python landmark absent/],
    ["added-file", p => write(path.join(p.root, "DLLs/added.pyd"), "inert addition"), /complete Python population differs/],
    ["changed-member", p => fs.appendFileSync(path.join(p.root, "Lib/os.py"), "changed"), /complete Python population differs/],
    ["startup-override", p => { write(path.join(p.root, "python._pth"), "Lib"); p.files = map(p.root); }, /Python startup override refused/],
    ["legacy-subset-schema", p => { delete p.schemaVersion; delete p.root; }, /Python installation fields differ/],
]) {
    test("intent refuses Python " + label + " before any runner or child", () => {
        const selected = inertPython(label), evidence = path.join(suiteRoot, "refusal-" + label);
        fs.mkdirSync(evidence);
        alter(selected);
        assert.throws(() => subject.runIntentPython31({
            python: selected, requestFile: path.join(evidence, "request-must-not-be-read.json"),
            runnerDirectory: path.join(evidence, "runner"), operation: "manifest", cwd: evidence,
            environment: {}, limits: { commandSeconds: 1, cleanupSeconds: 1, outputBytes: 1024 }
        }), pattern);
        assert.deepEqual(fs.readdirSync(evidence), []);
    });
}
const zipSource = String.raw `
const fs=require('node:fs'),crypto=require('node:crypto');
const crc=b=>{let c=0xffffffff;for(const v of b){c^=v;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (c^0xffffffff)>>>0;};
exports.zip=rows=>{const locals=[],central=[],hashes=[];let offset=0;for(const[n,b]of rows){const name=Buffer.from(n),c=crc(b),l=Buffer.alloc(30),d=Buffer.alloc(46);l.writeUInt32LE(0x04034b50,0);l.writeUInt16LE(20,4);l.writeUInt32LE(c,14);l.writeUInt32LE(b.length,18);l.writeUInt32LE(b.length,22);l.writeUInt16LE(name.length,26);d.writeUInt32LE(0x02014b50,0);d.writeUInt16LE(20,4);d.writeUInt16LE(20,6);d.writeUInt32LE(c,16);d.writeUInt32LE(b.length,20);d.writeUInt32LE(b.length,24);d.writeUInt16LE(name.length,28);d.writeUInt32LE(offset,42);locals.push(l,name,b);central.push(d,name);offset+=l.length+name.length+b.length;hashes.push(crypto.createHash('sha1').update(b).digest('hex'));}const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50,0);end.writeUInt16LE(rows.length,8);end.writeUInt16LE(rows.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);return {bytes:Buffer.concat([...locals,cd,end]),hash:crypto.createHash('sha1').update(hashes.sort().join('')).digest('hex')};};
`;
function fixture(label, alter = {}) {
    const root = path.join(suiteRoot, label), build = path.join(root, "build"), release = path.join(build, "tools/release"), fn = path.join(build, "functions"), cli = path.join(build, "tooling/firebase-cli/node_modules"), outputs = path.join(root, "outputs"), temp = path.join(root, "temporary");
    fs.mkdirSync(release, { recursive: true });
    fs.mkdirSync(outputs, { recursive: true });
    fs.mkdirSync(temp);
    fs.mkdirSync(path.join(root, "processes"));
    const fixed = JSON.parse(fs.readFileSync(path.join(__dirname, "runtime_contract_bindings.json"), "utf8"));
    for (const name of [...Object.keys(fixed), "business31CaptureBootstrap.cjs", "prepareBusinessIntent31.cjs"]) {
        write(path.join(release, name), fs.readFileSync(path.join(__dirname, name)));
    }
    write(path.join(build, "firebase.json"), { functions: [{ source: "functions", codebase: "default", ignore: ["node_modules", ".git"] }] });
    write(path.join(fn, "package.json"), { name: "synthetic-intent-functions", main: "lib/index.js" });
    write(path.join(fn, "package-lock.json"), { lockfileVersion: 3 });
    write(path.join(fn, "src/index.ts"), "// inert source\n");
    const m = manifest();
    if (alter.manifest)
        alter.manifest(m);
    write(path.join(fn, "lib/index.js"), (alter.effects ?? "") + "module.exports=" + JSON.stringify(m) + ";\n");
    write(path.join(fn, "node_modules/firebase-functions/package.json"), { name: "firebase-functions", version: "0.0.0-synthetic" });
    write(path.join(fn, "node_modules/firebase-functions/lib/runtime/loader.js"), "const path=require('node:path');exports.loadStack=async root=>require(path.join(root,'lib/index.js'));\n");
    write(path.join(fn, "node_modules/firebase-functions/lib/runtime/manifest.js"), "exports.stackToWire=value=>value;\n");
    const lib = path.join(cli, "firebase-tools/lib");
    write(path.join(lib, "bin/firebase.js"), "throw Error('inert CLI entry must not execute');\n");
    write(path.join(cli, "firebase-tools/package.json"), { name: "firebase-tools", version: "0.0.0-synthetic" });
    write(path.join(lib, "deploy/functions/runtimes/discovery/index.js"), "exports.yamlToBuild=(manifest,project,region,runtime)=>({manifest,project,region,runtime});\n");
    write(path.join(lib, "deploy/functions/build.js"), "exports.resolveBackend=async o=>({envs:{},backend:Object.keys(o.build.manifest.endpoints).map(id=>({id,platform:'gcfv2',project:o.build.project,region:o.build.region,secretEnvironmentVariables:[]}))});\n");
    write(path.join(lib, "deploy/functions/backend.js"), "exports.allEndpoints=x=>x;\n");
    write(path.join(lib, "functions/env.js"), "exports.loadFirebaseEnvs=(config,project)=>({FIREBASE_CONFIG:JSON.stringify(config),GCLOUD_PROJECT:project});\n");
    write(path.join(lib, "fsAsync.js"), "const fs=require('node:fs'),path=require('node:path');exports.readdirRecursive=async({path:root})=>" + JSON.stringify(alter.omitEmitted ? ["package.json", "package-lock.json", "src/index.ts"] : ["package.json", "package-lock.json", "src/index.ts", "lib/index.js"]) + ".map(n=>({name:path.join(root,n)}));\n");
    write(path.join(lib, "inertZip.js"), zipSource);
    write(path.join(lib, "deploy/functions/prepareFunctionsUpload.js"), "const fs=require('node:fs'),path=require('node:path'),zip=require('../../inertZip.js').zip;exports.prepareFunctionsUpload=async(c,root)=>{const rows=await require('../../fsAsync.js').readdirRecursive({path:root}),out=zip(rows.map(r=>[path.relative(root,r.name).split(path.sep).join('/'),fs.readFileSync(r.name)])),file=path.join(process.env.TEMP,'original.zip');" + (alter.badZip ? "out.bytes[30]^=1;" : "") + "fs.writeFileSync(file,out.bytes,{flag:'wx'});return {pathToSource:file,hash:out.hash};};\n");
    const o = originals(), project = write(path.join(root, "project.json"), o.project), parameters = write(path.join(root, "parameters.json"), o.parameters);
    const functions = map(fn), emitted = Object.fromEntries(Object.entries(functions).filter(([n]) => n.startsWith("lib/"))), sourceFiles = Object.fromEntries(Object.entries(functions).filter(([n]) => !n.startsWith("lib/") && !n.startsWith("node_modules/")).map(([n, h]) => ["functions/" + n, h]));
    const population = {
        schemaVersion: 1, documentType: "build31-business-intent-runtime-populations", source, buildRoot: build, sourceFiles, installedFiles: { root: {}, functions: Object.fromEntries(Object.entries(functions).filter(([n]) => n.startsWith("node_modules/")).map(([n, h]) => [n.slice(13), h])), cli: map(cli) }, emittedFiles: emitted, npmPackageFiles: {}, nodeExecutable: binding(process.execPath), npmCliFile: { path: "synthetic-unused", sha256: "0".repeat(64) }
    };
    const before = write(path.join(root, "runtime-before.json"), population), fnMap = write(path.join(root, "functions-map.json"), functions), emittedMap = write(path.join(root, "emitted-map.json"), emitted), cliMap = write(path.join(root, "cli-map.json"), map(cli));
    return {
        root, build, release, fn, cli, outputs, temp, project, parameters, before, fnMap, emittedMap, cliMap
    };
}
function run(f, operation, manifestBinding = null) {
    const out = path.join(f.outputs, operation);
    fs.mkdirSync(out);
    const configuration = {
        schemaVersion: 1, documentType: "build31-business-intent-worker-config", operation, source, buildRoot: f.build, outputDirectory: out, projectConfigOriginal: binding(f.project), parametersOriginal: binding(f.parameters), expectedFunctions: names, runtimeBefore: binding(f.before), manifest: manifestBinding
    };
    const configFile = write(path.join(f.root, operation + "-configuration.json"), configuration), request = {
        schemaVersion: 1, operation, sourceRoot: f.release, sourceFiles: map(f.release), nodeExecutable: binding(process.execPath), runtime: { cliEntrypoint: path.join(f.cli, "firebase-tools/lib/bin/firebase.js"), cliFileBindings: binding(f.cliMap) }, functionsRoot: f.fn, functionsFiles: binding(f.fnMap), emittedFiles: binding(f.emittedMap), configuration: binding(configFile)
    };
    const requestFile = write(path.join(f.root, operation + "-request.json"), request), argv = ["--no-global-search-paths", path.join(f.release, "business31CaptureBootstrap.cjs"), "--intent-worker", requestFile, sha(fs.readFileSync(requestFile))], processDir = path.join(f.root, "processes", operation), startedAtUtc = new Date().toISOString();
    const environment = {
        SystemRoot: process.env.SystemRoot, WINDIR: process.env.SystemRoot, TEMP: f.temp, TMP: f.temp, HOME: f.root, USERPROFILE: f.root, PATH: path.dirname(process.execPath)
    };
    const supervisor = {
        schemaVersion: 1, parentPid: process.pid, supervisorSha256: sha(fs.readFileSync(path.join(__dirname, "runtime_supervisor.py"))), executable: process.execPath, arguments: argv, cwd: f.build, environment, outputDirectory: processDir, timeoutSeconds: 20, maxOutputBytes: 1048576, cleanupSeconds: 5
    };
    const supervisorFile = write(path.join(f.root, operation + "-supervisor.json"), supervisor);
    const child = subject.runIntentPython31({
        python: pythonInstallation(), requestFile: supervisorFile, runnerDirectory: path.join(f.root, "runner"),
        operation, cwd: f.root, environment, limits: { commandSeconds: 20, cleanupSeconds: 5, outputBytes: 1048576 }
    });
    assert.equal(child.error, undefined);
    const record = JSON.parse(fs.readFileSync(path.join(processDir, "result.json"), "utf8")), stderr = fs.readFileSync(path.join(processDir, "stderr.bin"), "utf8");
    assert.equal(record.treeComplete, true);
    assert.equal(record.activeProcesses, 0);
    assert.equal(record.outputComplete, true);
    assert.deepEqual(record.cleanupErrors, []);
    return {
        child, record, stderr, out, processDir, argv, startedAtUtc, latestUtc: new Date().toISOString()
    };
}
test("two genuine owned inert workers discover then package; original ZIP and process streams bind", ownedOptions, () => {
    const f = fixture("positive"), before = map(f.build), first = run(f, "manifest");
    assert.equal(first.child.status, 0, first.stderr);
    const manifestResult = JSON.parse(fs.readFileSync(path.join(first.out, "result.json"), "utf8"));
    subject.verifyWorkerResult31({
        operation: "manifest", result: manifestResult, outputDirectory: first.out, source, expectedFunctions: names, temporaryRoot: f.temp
    });
    subject.verifyOriginalProcess31(first.record, { ...first, executable: process.execPath, cwd: f.build });
    const second = run(f, "package", manifestResult.manifest);
    assert.equal(second.child.status, 0, second.stderr);
    const result = JSON.parse(fs.readFileSync(path.join(second.out, "result.json"), "utf8"));
    subject.verifyWorkerResult31({
        operation: "package", result, outputDirectory: second.out, source, expectedFunctions: names, temporaryRoot: f.temp
    });
    subject.verifyOriginalProcess31(second.record, { ...second, executable: process.execPath, cwd: f.build });
    assert.deepEqual(map(f.build), before);
    const altered = structuredClone(second.record);
    altered.streams.stdout.sha256 = "F".repeat(64);
    assert.throws(() => subject.verifyOriginalProcess31(altered, { ...second, executable: process.execPath, cwd: f.build }), /stream differs/);
});
for (const [label, alter, pattern] of [
    ["network", { effects: "require('node:https').get('https://example.invalid/');" }, /network\/process operation refused/],
    ["process", { effects: "require('node:child_process').spawnSync(process.execPath,['--version']);" }, /network\/process operation refused/],
    ["implicit-region", { manifest: m => delete m.endpoints[names[0]].region }, /implicit region/],
])
    test("owned inert manifest " + label + " refusal leaves no successful output", ownedOptions, () => {
        const f = fixture(label, alter), r = run(f, "manifest");
        assert.notEqual(r.child.status, 0);
        assert.match(r.stderr, pattern);
        assert(!fs.existsSync(path.join(r.out, "result.json")));
    });
test("package cannot omit required emitted bytes", ownedOptions, () => {
    const f = fixture("omitted", { omitEmitted: true }), a = run(f, "manifest");
    assert.equal(a.child.status, 0, a.stderr);
    const b = run(f, "package", binding(path.join(a.out, "manifest.json")));
    assert.notEqual(b.child.status, 0);
    assert.match(b.stderr, /omitted required source\/emitted member/);
    assert(!fs.existsSync(path.join(b.out, "result.json")));
});
test("actual malformed ZIP refuses immutable member verification", ownedOptions, () => {
    const f = fixture("badzip", { badZip: true }), a = run(f, "manifest");
    assert.equal(a.child.status, 0, a.stderr);
    const b = run(f, "package", binding(path.join(a.out, "manifest.json")));
    assert.notEqual(b.child.status, 0);
    assert.match(b.stderr, /Local ZIP member mismatch/);
    assert(!fs.existsSync(path.join(b.out, "result.json")));
});
test("changed admitted Functions bytes refuse before manifest evaluation", ownedOptions, () => {
    const f = fixture("changed");
    fs.appendFileSync(path.join(f.fn, "lib/index.js"), "\n// changed\n");
    const r = run(f, "manifest");
    assert.notEqual(r.child.status, 0);
    assert.match(r.stderr, /differs|changed/);
    assert(!fs.existsSync(path.join(r.out, "result.json")));
});
test.after(() => process.stdout.write("# Retained inert intent fixture: " + suiteRoot + "\n"));

// These small real-Git fixtures exercise the actual runtime population function.
// Their proof-shaped data is synthetic: no runtime proof, authority or deployment
// is asserted, and their npm/dependency bytes are never imported or executed.
const populationAuthority = require("./business31BackendAuthority.cjs");
const populationTrusted = require("./business31TrustedInput.cjs");
const populationGit = path.resolve(process.env.BUSINESS31_TEST_GIT || (process.platform === "win32" ? "C:/Program Files/Git/mingw64/bin/git.exe" : "/usr/bin/git"));
const populationGitSha = sha(fs.readFileSync(populationGit));
function populationFixture() {
    const root = path.join(suiteRoot, "population"), repositoryRoot = path.join(root, "repository"), buildRoot = path.join(root, "build"), evidenceDirectory = path.join(root, "evidence"), npmPackageRoot = path.join(root, "npm");
    for (const directory of [repositoryRoot, buildRoot, evidenceDirectory, npmPackageRoot]) fs.mkdirSync(directory, { recursive: true });
    const environment = { GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: process.platform === "win32" ? "NUL" : "/dev/null", GIT_TERMINAL_PROMPT: "0", GIT_NO_LAZY_FETCH: "1" };
    for (const name of ["SystemRoot", "WINDIR", "PATH", "TEMP", "TMP"]) if (process.env[name] !== undefined) environment[name] = process.env[name];
    const git = (args, input) => require("node:child_process").execFileSync(populationGit, ["-c", "core.autocrlf=false", "-c", "commit.gpgsign=false", "-c", "protocol.allow=never", "-c", "core.hooksPath=" + path.join(root, "absent-hooks"), "-C", repositoryRoot, ...args], { env: environment, input, timeout: 30000, windowsHide: true, stdio: ["pipe", "pipe", "pipe"] });
    git(["init", "--initial-branch=main"]);
    const rows = Array.from({ length: 15 }, (_, i) => ["functions/src/file-" + String(i).padStart(2, "0") + ".ts", i === 0 ? Buffer.alloc(0) : i === 1 ? Buffer.from([0, 255, 10, 13, 128]) : Buffer.from("synthetic source " + i + "\n"), i === 14 ? "100755" : "100644"]);
    rows.push(["shared.bin", Buffer.from(rows[1][1]), "100644"]);
    const message = "Synthetic intent population fixture only\n", parts = [Buffer.from("commit refs/heads/main\ncommitter Fixture <fixture@example.invalid> 1767225600 +0000\ndata " + Buffer.byteLength(message) + "\n" + message)];
    for (const [name, bytes, mode] of rows) {
        parts.push(Buffer.from(`M ${mode} inline ${name}\ndata ${bytes.length}\n`), bytes, Buffer.from("\n"));
        write(path.join(buildRoot, ...name.split("/")), bytes);
    }
    parts.push(Buffer.from("\ndone\n")); git(["fast-import", "--quiet", "--done"], Buffer.concat(parts));
    const commit = git(["rev-parse", "HEAD"]).toString("utf8").trim();
    const repositoryOptions = { repositoryRoot, gitExecutable: populationGit, gitSha256: populationGitSha };
    const repository = populationTrusted.openTrustedGitRepository31(repositoryOptions), snapshot = repository.snapshot(commit);
    const source = { commit, tree: snapshot.tree, functionsTree: populationAuthority.subtreeOid31(snapshot.files, "functions") };
    const retain = (name, bytes) => { const file = write(path.join(evidenceDirectory, name), bytes), raw = fs.readFileSync(file); return { file: name, sha256: sha(raw), bytes: raw.length }; };
    const installedFiles = {};
    for (const [name, prefix] of Object.entries({ root: "node_modules", functions: "functions/node_modules", cli: "tooling/firebase-cli/node_modules" })) {
        write(path.join(buildRoot, prefix, "inert.txt"), "Never executed: " + name);
        installedFiles[name] = retain(name + "-installed.json", map(path.join(buildRoot, prefix)));
    }
    const emitted = Buffer.from("// synthetic emitted bytes; never executed\n");
    write(path.join(buildRoot, "functions/lib/index.js"), emitted);
    const emittedFiles = { "lib/index.js": retain("emitted.js", emitted) };
    const npmCliFile = binding(write(path.join(npmPackageRoot, "npm-cli.js"), "// inert npm; never executed\n"));
    const proof = { buildRoot, installedFiles, emittedFiles, runtime: { nodeExecutable: binding(process.execPath), npmCliFile, npmPackageRoot } };
    const ctx = { api: { authority: populationAuthority }, proof, snapshot, source, evidenceDirectory, repository };
    return { root, rows, ctx, repositoryOptions };
}
let populationData;
function population() { return populationData ??= populationFixture(); }
test("runtime population preserves complete real-Git scalar bytes, binary/empty/shared blobs and both regular modes", () => {
    const { ctx, rows } = population(), actual = subject.runtimePopulation31(ctx);
    const scalar = Object.fromEntries(Object.keys(ctx.snapshot.files).sort().map(name => [name, sha(ctx.repository.readBlob(ctx.source.commit, name))]));
    assert.deepEqual(actual.sourceFiles, scalar);
    assert.deepEqual(actual.sourceFiles, Object.fromEntries(rows.map(([name, bytes]) => [name, sha(bytes)]).sort(([a], [b]) => a.localeCompare(b))));
    assert.equal(ctx.snapshot.files[rows[0][0]].mode, "100644");
    assert.equal(ctx.snapshot.files[rows[14][0]].mode, "100755");
    assert.deepEqual(Object.keys(actual.sourceFiles), Object.keys(ctx.snapshot.files).sort());
    assert.equal(actual.sourceFiles[rows[1][0]], actual.sourceFiles["shared.bin"]);
    assert.deepEqual(actual.source, ctx.source);
    for (const [name, pointer] of Object.entries(ctx.proof.installedFiles)) assert.deepEqual(actual.installedFiles[name], JSON.parse(populationAuthority.readPrivate(ctx.evidenceDirectory, pointer)));
    assert.equal(actual.emittedFiles["lib/index.js"], sha(populationAuthority.readPrivate(ctx.evidenceDirectory, ctx.proof.emittedFiles["lib/index.js"])));
    assert.deepEqual(actual.npmPackageFiles, map(ctx.proof.runtime.npmPackageRoot));
    assert.deepEqual(actual.nodeExecutable, ctx.proof.runtime.nodeExecutable);
    assert.deepEqual(actual.npmCliFile, ctx.proof.runtime.npmCliFile);
});
test("each of six runtime population invocations performs a fresh real batch read and no scalar retrieval", () => {
    const { ctx } = population(); let batchCalls = 0, scalarCalls = 0;
    const repository = { ...ctx.repository,
        readSnapshotBlobs(snapshot) { ++batchCalls; return ctx.repository.readSnapshotBlobs(snapshot); },
        readBlob(...args) { ++scalarCalls; return ctx.repository.readBlob(...args); }
    };
    // Observation wrappers call the unchanged real reader; they do not supply bytes.
    const before = subject.runtimePopulation31({ ...ctx, repository });
    for (let i = 1; i < 6; ++i) assert.deepEqual(subject.runtimePopulation31({ ...ctx, repository }), before);
    assert.equal(batchCalls, 6); assert.equal(scalarCalls, 0);
});
for (const [label, relative, operation, pattern] of [
    ["changed source", "functions/src/file-02.ts", "change", /materialized source bytes differ/],
    ["missing source", "shared.bin", "remove", /complete materialized source population/],
    ["extra source", "extra.txt", "add", /unlisted materialized source/],
    ["installed bytes", "node_modules/inert.txt", "change", /installed population changed/],
    ["emitted bytes", "functions/lib/index.js", "change", /emitted bytes changed/]
]) test("runtime population rechecks " + label + " after a successful census", () => {
    const { ctx } = population(), file = path.join(ctx.proof.buildRoot, relative);
    subject.runtimePopulation31(ctx);
    const before = operation === "add" ? null : fs.readFileSync(file);
    try {
        if (operation === "remove") fs.unlinkSync(file);
        else fs.writeFileSync(file, "synthetic drift", { flag: operation === "add" ? "wx" : "w" });
        assert.throws(() => subject.runtimePopulation31(ctx), pattern);
    } finally { if (before === null) fs.unlinkSync(file); else fs.writeFileSync(file, before); }
});
test("runtime population refuses a copied or foreign snapshot at the real reader boundary", () => {
    const { ctx, repositoryOptions } = population(), other = populationTrusted.openTrustedGitRepository31(repositoryOptions);
    for (const snapshot of [structuredClone(ctx.snapshot), other.snapshot(ctx.source.commit)]) {
        assert.throws(() => subject.runtimePopulation31({ ...ctx, snapshot }), /not issued/);
    }
});
test("runtime population refuses repository config drift after a successful census", () => {
    const { ctx, repositoryOptions } = population(), config = path.join(repositoryOptions.repositoryRoot, ".git/config"), before = fs.readFileSync(config);
    subject.runtimePopulation31(ctx);
    try { fs.appendFileSync(config, "\n[include]\n path = /untrusted\n"); assert.throws(() => subject.runtimePopulation31(ctx), /configuration/); }
    finally { fs.writeFileSync(config, before); }
});
for (const [label, mutate, pattern] of [
    ["missing member", map => { map.delete(map.keys().next().value); }, /complete source blob population/],
    ["extra member", map => { map.set("unexpected", Buffer.alloc(0)); }, /complete source blob population/],
    ["non-byte member", map => { map.set(map.keys().next().value, "not raw bytes"); }, /source blob bytes required/]
]) test("runtime population refuses " + label + " in a corrupted real-reader return", () => {
    const { ctx } = population();
    const repository = { ...ctx.repository, readSnapshotBlobs(snapshot) {
        const result = ctx.repository.readSnapshotBlobs(snapshot); mutate(result); return result;
    } };
    // Deliberate corruption is only in returned fixture data, never Git/runtime bytes.
    let returned;
    assert.throws(() => { returned = subject.runtimePopulation31({ ...ctx, repository }); }, pattern);
    assert.equal(returned, undefined, "no partial population may escape");
});
