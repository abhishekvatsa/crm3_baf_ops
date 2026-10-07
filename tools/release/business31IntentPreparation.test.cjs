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
