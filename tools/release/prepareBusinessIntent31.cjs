"use strict";
// Credential-free local measurement. Source/interpreter selection, authenticated
// observations, human consent and operational execution remain external gates.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto"), cp = require("node:child_process");
const { isDeepStrictEqual: same, TextDecoder } = require("node:util");
const SELF = "tools/release/prepareBusinessIntent31.cjs", BOOTSTRAP = "tools/release/business31CaptureBootstrap.cjs";
const PROJECT = "crm3-baf-ops-b8638", REGION = "asia-south1", PARAM = "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK";
const SUPERVISOR_SHA = "4AE021C13E2FDC0D3FAD18ADBF5D7D796FD2DA946E8C907288BA0A83C585F37C";
const HASH = /^[A-F0-9]{64}$/, utc = () => new Date().toISOString(), sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const need = (ok, message) => {
    if (!ok)
        throw Error("Business intent preparation: " + message);
};
function exact(value, names, label) {
    need(value && typeof value === "object" && !Array.isArray(value) && same(Object.keys(value).sort(), [...names].sort()), label + " fields differ");
}
function regular(file, directory = false) {
    need(typeof file === "string" && path.isAbsolute(file), "absolute path required");
    file = path.resolve(file);
    let at = path.parse(file).root;
    for (const part of file.slice(at.length).split(path.sep).filter(Boolean)) {
        at = path.join(at, part);
        need(!fs.lstatSync(at).isSymbolicLink(), "redirected path refused");
    }
    need(directory ? fs.statSync(file).isDirectory() : fs.statSync(file).isFile(), "regular path required");
    return file;
}
function read(file, max = 128 * 1024 * 1024) {
    file = regular(file);
    const before = fs.statSync(file, { bigint: true });
    need(before.size <= BigInt(max), "file exceeds bound");
    const bytes = fs.readFileSync(file), after = fs.statSync(file, { bigint: true });
    need(before.ino === after.ino && before.size === after.size && before.mtimeNs === after.mtimeNs && before.ctimeNs === after.ctimeNs && BigInt(bytes.length) === after.size, "file changed during read");
    return bytes;
}
function decode(bytes) {
    return JSON.parse(new TextDecoder("utf8", { fatal: true }).decode(bytes));
}
function bound(item, max) {
    exact(item, ["path", "sha256"], "absolute binding");
    need(HASH.test(item.sha256), "binding hash malformed");
    const bytes = read(item.path, max);
    need(sha(bytes) === item.sha256, "bound bytes differ");
    return bytes;
}
function createDirectory31(directory) {
    need(typeof directory === "string" && path.isAbsolute(directory), "absolute output directory required");
    directory = path.resolve(directory);
    let at = path.parse(directory).root;
    regular(at, true);
    for (const part of directory.slice(at.length).split(path.sep).filter(Boolean)) {
        at = path.join(at, part);
        try {
            fs.mkdirSync(at, { mode: 0o700 });
        }
        catch (error) {
            if (error.code !== "EEXIST")
                throw error;
        }
        regular(at, true);
    }
    return directory;
}
function write(file, value) {
    need(typeof file === "string" && path.isAbsolute(file), "absolute output file required");
    createDirectory31(path.dirname(file));
    fs.writeFileSync(file, Buffer.isBuffer(value) ? value : JSON.stringify(value, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    regular(file);
    return file;
}
function binding(file) {
    return { path: file, sha256: sha(read(file)) };
}
function pointer(root, file) {
    file = regular(file);
    const name = path.relative(root, file).split(path.sep).join("/");
    need(name && !name.startsWith("../") && !path.isAbsolute(name), "evidence outside root");
    const bytes = read(file);
    return { file: name, sha256: sha(bytes), bytes: bytes.length };
}
function time(value) {
    need(typeof value === "string" && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,9})?Z$/.test(value) && Number.isFinite(Date.parse(value)), "explicit UTC required");
    return Date.parse(value);
}
function contracts() {
    const hashes = decode(read(path.join(__dirname, "runtime_contract_bindings.json")));
    need(Object.keys(hashes).length === 14, "fixed contract population differs");
    for (const [name, digest] of Object.entries(hashes)) {
        need(/^[A-Za-z0-9]+\.cjs$/.test(name) && HASH.test(digest) && sha(read(path.join(__dirname, name))) === digest, "executing contract differs: " + name);
    }
    return {
        hashes, authority: require("./business31BackendAuthority.cjs"), trusted: require("./business31TrustedInput.cjs"), neutral: require("./backendRuntimeClosure31.cjs")
    };
}
function validateInputOriginals31({ projectConfigOriginal, parametersOriginal, source, earliestUtc, latestUtc }) {
    const project = decode(projectConfigOriginal), params = decode(parametersOriginal);
    exact(project, ["schemaVersion", "documentType", "source", "observedAtUtc", "request", "response"], "original project configuration");
    exact(project.request, ["method", "url"], "project configuration request");
    exact(project.response, ["httpStatus", "bodyText"], "project configuration response");
    need(project.schemaVersion === 1 && project.documentType === "build31-business-original-admin-sdk-config" && same(project.source, source), "original project configuration source/type differs");
    need(project.request.method === "GET" && project.request.url === "https://firebase.googleapis.com/v1beta1/projects/" + PROJECT + "/adminSdkConfig" && project.response.httpStatus === 200 && typeof project.response.bodyText === "string", "original adminSdkConfig response required");
    need(time(earliestUtc) <= time(project.observedAtUtc) && time(project.observedAtUtc) <= time(latestUtc), "project configuration observation chronology differs");
    const firebaseConfig = decode(Buffer.from(project.response.bodyText));
    need(firebaseConfig && Object.getPrototypeOf(firebaseConfig) === Object.prototype && firebaseConfig.projectId === PROJECT && Object.keys(firebaseConfig).length <= 4 && Object.entries(firebaseConfig).every(([k, v]) => ["projectId", "databaseURL", "storageBucket", "locationId"].includes(k) && typeof v === "string" && v.length <= 2048), "unsupported adminSdkConfig response");
    exact(params, ["schemaVersion", "documentType", "source", "parameters"], "explicit parameters");
    exact(params.parameters, [PARAM], "finite nonsecret parameters");
    need(params.schemaVersion === 1 && params.documentType === "build31-business-intent-parameters" && same(params.source, source) && params.parameters[PARAM] === "false", "explicit source-bound AppCheck=false input required");
    return { firebaseConfig, parameters: params.parameters };
}
function validateManifest31(manifest, names) {
    need(manifest && typeof manifest === "object" && !Array.isArray(manifest) && manifest.specVersion === "v1alpha1" && Object.keys(manifest).every(k => ["specVersion", "endpoints", "params", "requiredAPIs", "extensions"].includes(k)), "unsupported SDK manifest");
    need(manifest.extensions === undefined || (manifest.extensions && typeof manifest.extensions === "object" && !Array.isArray(manifest.extensions) && Object.keys(manifest.extensions).length === 0), "dynamic extensions refused");
    need(Array.isArray(manifest.params) && manifest.params.length === 1 && manifest.params[0].name === PARAM && manifest.params[0].type === "boolean" && manifest.params[0].default === false, "unknown or secret parameters refused");
    need(manifest.endpoints && same(Object.keys(manifest.endpoints).sort(), names), "manifest endpoint population differs");
    for (const [name, e] of Object.entries(manifest.endpoints)) {
        need(e && e.platform === "gcfv2" && same(e.region, [REGION]), "implicit region or unsupported endpoint platform: " + name);
        need(e.secretEnvironmentVariables === undefined || (Array.isArray(e.secretEnvironmentVariables) && e.secretEnvironmentVariables.length === 0), "secret endpoint references refused");
        const triggers = ["httpsTrigger", "callableTrigger", "eventTrigger", "scheduleTrigger"].filter(k => Object.hasOwn(e, k));
        need(triggers.length === 1 && !Object.hasOwn(e, "taskQueueTrigger") && !Object.hasOwn(e, "blockingTrigger"), "unsupported endpoint trigger: " + name);
    }
    return manifest;
}
function runtimePopulation31(ctx) {
    const { api, proof, snapshot, source, evidenceDirectory, repository } = ctx;
    need(repository.snapshot(source.commit).tree === source.tree, "selected source changed");
    api.authority.verifyMaterializedSource31(proof.buildRoot, snapshot);
    const names = Object.keys(snapshot.files).sort(), originals = repository.readSnapshotBlobs(snapshot);
    need(originals instanceof Map && same([...originals.keys()].sort(), names), "complete source blob population differs");
    const sourceFiles = Object.fromEntries(names.map(name => {
        const original = originals.get(name), file = path.join(proof.buildRoot, ...name.split("/"));
        need(Buffer.isBuffer(original), "source blob bytes required: " + name);
        need(read(file).equals(original), "materialized source changed: " + name);
        return [name, sha(original)];
    }));
    const installedFiles = {};
    for (const [k, prefix] of Object.entries({ root: "node_modules", functions: "functions/node_modules", cli: "tooling/firebase-cli/node_modules" })) {
        const original = decode(api.authority.readPrivate(evidenceDirectory, proof.installedFiles[k])), actual = api.authority.fileMap31(path.join(proof.buildRoot, prefix));
        need(same(actual, original), "installed population changed: " + k);
        installedFiles[k] = actual;
    }
    const emittedFiles = Object.fromEntries(Object.entries(api.authority.fileMap31(path.join(proof.buildRoot, "functions/lib"))).map(([n, h]) => ["lib/" + n, h]));
    need(same(Object.keys(emittedFiles).sort(), Object.keys(proof.emittedFiles).sort()), "emitted population changed");
    for (const [n, h] of Object.entries(emittedFiles))
        need(sha(api.authority.readPrivate(evidenceDirectory, proof.emittedFiles[n])) === h, "emitted bytes changed");
    need(sha(read(proof.runtime.nodeExecutable.path)) === proof.runtime.nodeExecutable.sha256 && sha(read(proof.runtime.npmCliFile.path)) === proof.runtime.npmCliFile.sha256, "runtime executable changed");
    const npmPackageFiles = api.authority.fileMap31(proof.runtime.npmPackageRoot);
    return {
        schemaVersion: 1, documentType: "build31-business-intent-runtime-populations", source, buildRoot: proof.buildRoot, sourceFiles, installedFiles, emittedFiles, npmPackageFiles, nodeExecutable: proof.runtime.nodeExecutable, npmCliFile: proof.runtime.npmCliFile
    };
}
function admittedFunctionsMap31(population) {
    const rows = [...Object.entries(population.sourceFiles).filter(([n]) => n.startsWith("functions/")).map(([n, h]) => [n.slice(10), h]), ...Object.entries(population.installedFiles.functions).map(([n, h]) => ["node_modules/" + n, h]), ...Object.entries(population.emittedFiles)], map = Object.fromEntries(rows);
    need(rows.length === Object.keys(map).length, "overlapping Functions source/runtime population");
    return map;
}
function producerCheck31(ctx) {
    for (const [file, digest] of Object.entries(ctx.producers))
        need(sha(read(path.join(__dirname, path.basename(file)))) === digest, "executing preparation producer changed");
    for (const [name, digest] of Object.entries(ctx.api.hashes))
        need(sha(read(path.join(__dirname, name))) === digest, "executing preparation contract changed");
}
function verifyOriginalProcess31(measured, { executable, argv, cwd, processDir, startedAtUtc, latestUtc }) {
    need(measured.treeComplete === true && measured.outputComplete === true && measured.rootExited === true && measured.activeProcesses === 0 && same(measured.cleanupErrors, []), "owned preparation process tree/output incomplete");
    need(measured.status === "SUCCESS" && measured.failure === null && measured.exitCode === 0 && measured.jobAssigned === true && measured.resumed === true && measured.executable === executable && same(measured.arguments, argv) && measured.cwd === cwd, "original preparation command failed or differs");
    need(time(startedAtUtc) <= time(measured.startedAtUtc) && time(measured.startedAtUtc) <= time(measured.resumedAtUtc) && time(measured.resumedAtUtc) <= time(measured.completedAtUtc) && time(measured.completedAtUtc) <= time(latestUtc), "original preparation process chronology differs");
    exact(measured.streams, ["stdout", "stderr"], "original process streams");
    for (const name of ["stdout", "stderr"]) {
        const record = measured.streams[name], file = path.join(processDir, name + ".bin"), bytes = read(file);
        need(record.path === file && record.eof === true && record.error === null && !Object.hasOwn(record, "closeError") && record.bytes === bytes.length && record.observedBytes === bytes.length && record.sha256 === sha(bytes), "original preparation stream differs: " + name);
    }
    return measured;
}
function verifyWorkerResult31({ operation, result, outputDirectory, source, expectedFunctions, temporaryRoot }) {
    if (operation === "manifest") {
        exact(result, ["schemaVersion", "documentType", "source", "manifest", "sdkLoader", "sdkManifest"], "manifest result");
        need(result.schemaVersion === 1 && result.documentType === "build31-business-original-manifest-result" && same(result.source, source) && result.sdkLoader === "firebase-functions/lib/runtime/loader.js" && result.sdkManifest === "firebase-functions/lib/runtime/manifest.js" && result.manifest.path === path.join(outputDirectory, "manifest.json"), "original manifest result differs");
        validateManifest31(decode(bound(result.manifest)), expectedFunctions);
    }
    else {
        exact(result, ["schemaVersion", "documentType", "source", "sourceArchiveHash", "environmentVariables", "endpoints", "originalArchive", "archive", "archiveExpectedFiles"], "package result");
        need(result.schemaVersion === 1 && result.documentType === "build31-business-original-package-result" && same(result.source, source) && /^[a-f0-9]{40}$/.test(result.sourceArchiveHash), "original package result differs");
        need(result.archive.path === path.join(outputDirectory, "archive.zip") && result.archiveExpectedFiles.path === path.join(outputDirectory, "archive-members.json"), "original package output paths differ");
        exact(result.originalArchive, ["path", "sha256", "bytes"], "original archive");
        const relative = path.relative(temporaryRoot, regular(result.originalArchive.path));
        need(relative && !relative.startsWith("..") && !path.isAbsolute(relative), "original archive outside owned temporary root");
        const original = read(result.originalArchive.path), retained = bound(result.archive);
        need(original.equals(retained) && result.originalArchive.sha256 === sha(original) && result.originalArchive.bytes === original.length, "original archive bytes differ");
        bound(result.archiveExpectedFiles);
        need(same(Object.keys(result.endpoints).sort(), expectedFunctions) && result.environmentVariables[PARAM] === "false" && Object.values(result.environmentVariables).every(v => typeof v === "string"), "original package runtime inputs differ");
    }
    return result;
}
function preflightBusinessIntent31(config) {
    exact(config, ["schemaVersion", "repositoryRoot", "gitExecutable", "gitSha256", "source", "evidenceDirectory", "runtimeProof", "projectConfigOriginal", "parametersOriginal", "attemptRoot", "afterCi", "python", "systemRoot", "limits"], "preparation input");
    need(config.schemaVersion === 1 && process.platform === "win32", "Windows preparation input required");
    exact(config.source, ["commit", "tree", "functionsTree"], "source identity");
    need(Object.values(config.source).every(v => typeof v === "string" && /^[a-f0-9]{40}$/.test(v)), "exact source required");
    const evidenceDirectory = regular(config.evidenceDirectory, true), attemptRoot = path.resolve(config.attemptRoot), relative = path.relative(evidenceDirectory, attemptRoot);
    need(path.isAbsolute(config.attemptRoot) && relative && !relative.startsWith("..") && !path.isAbsolute(relative) && !fs.existsSync(attemptRoot), "new private evidence subdirectory required; no retry");
    regular(path.dirname(attemptRoot), true);
    exact(config.limits, ["commandSeconds", "cleanupSeconds", "outputBytes"], "process limits");
    need(Number.isFinite(config.limits.commandSeconds) && config.limits.commandSeconds > 0 && config.limits.commandSeconds <= 600 && Number.isFinite(config.limits.cleanupSeconds) && config.limits.cleanupSeconds > 0 && config.limits.cleanupSeconds <= 30 && Number.isSafeInteger(config.limits.outputBytes) && config.limits.outputBytes > 0 && config.limits.outputBytes <= 16 * 1024 * 1024, "finite process limits required");
    const api = contracts(), repository = api.trusted.openTrustedGitRepository31({ repositoryRoot: config.repositoryRoot, gitExecutable: config.gitExecutable, gitSha256: config.gitSha256 }), snapshot = repository.snapshot(config.source.commit);
    need(snapshot.tree === config.source.tree && api.authority.subtreeOid31(snapshot.files, "functions") === config.source.functionsTree, "selected source differs");
    for (const [name, h] of Object.entries(api.hashes))
        need(sha(repository.readBlob(config.source.commit, "tools/release/" + name)) === h, "source contract differs: " + name);
    const producers = {};
    for (const file of [SELF, BOOTSTRAP, "tools/release/collectBusinessRuntime31.cjs", "tools/release/runtime_contract_bindings.json", "tools/release/runtime_process_runner.py", "tools/release/runtime_supervisor.py"]) {
        const local = path.join(__dirname, path.basename(file)), bytes = read(local);
        need(repository.readBlob(config.source.commit, file).equals(bytes), "executing preparation producer differs from source: " + file);
        producers[file] = sha(bytes);
    }
    need(producers["tools/release/runtime_supervisor.py"] === SUPERVISOR_SHA, "fixed supervisor differs");
    const proof = decode(api.authority.readPrivate(evidenceDirectory, config.runtimeProof)), observedAtUtc = utc();
    const verified = api.authority.verifyRuntimeProof31({
        proof, source: config.source, snapshot, repository, evidenceDirectory, afterCi: config.afterCi, beforeDecision: observedAtUtc
    });
    need(proof.schemaVersion === 3 && verified.approvedToolchain.platform === "win32" && sha(read(process.execPath)) === proof.runtime.nodeExecutable.sha256, "selected approved Windows interpreter required");
    const originals = { project: api.authority.readPrivate(evidenceDirectory, config.projectConfigOriginal), parameters: api.authority.readPrivate(evidenceDirectory, config.parametersOriginal) };
    validateInputOriginals31({
        projectConfigOriginal: originals.project, parametersOriginal: originals.parameters, source: config.source, earliestUtc: proof.completedAtUtc, latestUtc: observedAtUtc
    });
    const firebase = decode(repository.readBlob(config.source.commit, "firebase.json"));
    need(Array.isArray(firebase.functions) && firebase.functions.length === 1 && firebase.functions[0].source === "functions" && firebase.functions[0].codebase === "default" && Array.isArray(firebase.functions[0].ignore), "fixed local default codebase required");
    const fleet = decode(repository.readBlob(config.source.commit, "release/function-fleet-runtime-identity-policy.json"));
    const expectedFunctions = Object.keys(fleet.functionBindings ?? {}).sort();
    need(expectedFunctions.length === 19 && new Set(expectedFunctions).size === 19, "exact19 source-declared functions required");
    // The complete externally selected installation is checked before startup.
    // A caller-selected import subset or Python startup override is not accepted.
    require("./collectBusinessRuntime31.cjs").verifyPythonRuntime31(config.python);
    regular(config.systemRoot, true);
    const ctx = {
        api, repository, snapshot, source: config.source, evidenceDirectory, proof, verified, producers, config, attemptRoot, originals, expectedFunctions
    };
    ctx.population = runtimePopulation31(ctx);
    const admitted = admittedFunctionsMap31(ctx.population);
    need(same(api.authority.fileMap31(path.join(proof.buildRoot, "functions")), admitted), "unapproved extra Functions files refused");
    for (const n of Object.keys(admitted))
        need(!/^\.env(?:\.|$)/.test(n) && n !== "functions.yaml", "ambient dotenv or alternate manifest refused");
    return ctx;
}
function denyWorkerEffects31() {
    const slots = [], save = (object, key) => {
        const before = Object.getOwnPropertyDescriptor(object, key);
        if (!before)
            return;
        need(typeof before.value === "function" && before.configurable !== false, "unsupported worker effect slot");
        const denied = () => {
            throw Error("Business intent preparation: credential-free worker network/process operation refused");
        };
        Object.defineProperty(object, key, { ...before, value: denied });
        slots.push({
            object, key, before, denied
        });
    };
    for (const name of ["node:http", "node:https"]) {
        const m = require(name);
        for (const k of ["request", "get"])
            save(m, k);
    }
    save(require("node:net").Socket.prototype, "connect");
    save(require("node:net").Server.prototype, "listen");
    save(require("node:tls"), "connect");
    save(require("node:dgram"), "createSocket");
    for (const target of [require("node:dns"), require("node:dns/promises")])
        for (const key of Object.keys(target))
            if (/^(lookup|resolve|reverse)/.test(key))
                save(target, key);
    for (const k of ["spawn", "spawnSync", "exec", "execSync", "execFile", "execFileSync", "fork"])
        save(cp, k);
    save(require("node:worker_threads"), "Worker");
    if (typeof globalThis.fetch === "function")
        save(globalThis, "fetch");
    return () => {
        const failures = [];
        for (const { object, key, before, denied } of slots.reverse()) {
            const now = Object.getOwnPropertyDescriptor(object, key);
            if (now?.value !== denied) {
                failures.push(key);
                continue;
            }
            Object.defineProperty(object, key, before);
        }
        need(failures.length === 0, "worker effect guard ownership changed: " + failures.join(","));
    };
}
async function runIntentWorker31({ operation, configurationFile, configurationSha256 }) {
    require("./business31CaptureBootstrap.cjs").assertIntentWorker31(operation);
    need(["manifest", "package"].includes(operation), "fixed worker operation required");
    const c = decode(bound({ path: configurationFile, sha256: configurationSha256 }, 16 * 1024 * 1024));
    exact(c, ["schemaVersion", "documentType", "operation", "source", "buildRoot", "outputDirectory", "projectConfigOriginal", "parametersOriginal", "expectedFunctions", "runtimeBefore", "manifest"], "worker configuration");
    need(c.schemaVersion === 1 && c.documentType === "build31-business-intent-worker-config" && c.operation === operation, "worker configuration type differs");
    regular(c.buildRoot, true);
    regular(c.outputDirectory, true);
    const pop = decode(bound(c.runtimeBefore, 64 * 1024 * 1024));
    need(same(pop.source, c.source) && pop.buildRoot === c.buildRoot, "worker population source differs");
    const inputs = validateInputOriginals31({
        projectConfigOriginal: bound(c.projectConfigOriginal), parametersOriginal: bound(c.parametersOriginal), source: c.source, earliestUtc: "1970-01-01T00:00:00Z", latestUtc: utc()
    });
    const functionsRoot = path.join(c.buildRoot, "functions"), cli = path.join(c.buildRoot, "tooling/firebase-cli/node_modules/firebase-tools/lib"), restore = denyWorkerEffects31();
    let originalError;
    try {
        if (operation === "manifest") {
            need(c.manifest === null, "manifest worker cannot take a supplied manifest");
            const loader = require(path.join(functionsRoot, "node_modules/firebase-functions/lib/runtime/loader.js")), manifestApi = require(path.join(functionsRoot, "node_modules/firebase-functions/lib/runtime/manifest.js"));
            const stack = await loader.loadStack(functionsRoot), manifest = manifestApi.stackToWire(stack);
            validateManifest31(manifest, c.expectedFunctions);
            write(path.join(c.outputDirectory, "manifest.json"), manifest);
            write(path.join(c.outputDirectory, "result.json"), {
                schemaVersion: 1, documentType: "build31-business-original-manifest-result", source: c.source, manifest: binding(path.join(c.outputDirectory, "manifest.json")), sdkLoader: "firebase-functions/lib/runtime/loader.js", sdkManifest: "firebase-functions/lib/runtime/manifest.js"
            });
        }
        else {
            const manifest = validateManifest31(decode(bound(c.manifest)), c.expectedFunctions);
            const discovery = require(path.join(cli, "deploy/functions/runtimes/discovery/index.js")), build = require(path.join(cli, "deploy/functions/build.js")), backend = require(path.join(cli, "deploy/functions/backend.js")), env = require(path.join(cli, "functions/env.js"));
            const wanted = discovery.yamlToBuild(manifest, PROJECT, REGION, "nodejs22"), resolved = await build.resolveBackend({
                build: wanted, firebaseConfig: inputs.firebaseConfig, userEnvs: inputs.parameters, nonInteractive: true, isEmulator: false
            });
            const environmentVariables = { ...inputs.parameters, ...env.loadFirebaseEnvs(inputs.firebaseConfig, PROJECT) };
            for (const name of Object.keys(resolved.envs)) {
                const value = resolved.envs[name], wire = value?.toSDK();
                if (wire && !value.internal && (!Object.hasOwn(environmentVariables, name) || value.legalList))
                    environmentVariables[name] = wire;
            }
            need(environmentVariables[PARAM] === "false" && Object.values(environmentVariables).every(v => typeof v === "string"), "resolved nonsecret environment differs");
            const rows = backend.allEndpoints(resolved.backend);
            need(same(rows.map(e => e.id).sort(), c.expectedFunctions), "resolved endpoint population differs");
            const endpoints = Object.fromEntries(rows.map(e => {
                need(e.platform === "gcfv2" && e.project === PROJECT && e.region === REGION && (!e.secretEnvironmentVariables || e.secretEnvironmentVariables.length === 0), "resolved endpoint identity or secrets differ");
                return [e.id, {
                        id: e.id, platform: e.platform, project: e.project, region: e.region, secretEnvironmentVariables: []
                    }];
            }));
            const config = decode(read(path.join(c.buildRoot, "firebase.json"))).functions[0], ignore = [...config.ignore, "firebase-debug.log", "firebase-debug.*.log", ".runtimeconfig.json"];
            const enumerator = require(path.join(cli, "fsAsync.js")), packager = require(path.join(cli, "deploy/functions/prepareFunctionsUpload.js"));
            const members = await enumerator.readdirRecursive({ path: functionsRoot, ignoreStrings: ignore }), archiveExpectedFiles = Object.fromEntries(members.map(row => {
                const name = path.relative(functionsRoot, row.name).split(path.sep).join("/"), bytes = read(row.name);
                need(Object.hasOwn(pop.sourceFiles, "functions/" + name) || Object.hasOwn(pop.emittedFiles, name), "package contains unapproved member");
                const digest = pop.emittedFiles[name] ?? pop.sourceFiles["functions/" + name];
                need(sha(bytes) === digest, "package member changed");
                return [name, { sha256: digest, bytes: bytes.length }];
            }));
            need(Object.keys(archiveExpectedFiles).length === members.length, "duplicate package member");
            for (const name of ["package.json", "package-lock.json", ...Object.keys(pop.emittedFiles), ...Object.keys(pop.sourceFiles).filter(n => n.startsWith("functions/src/")).map(n => n.slice(10))])
                need(Object.hasOwn(archiveExpectedFiles, name), "package omitted required source/emitted member: " + name);
            const packaged = await packager.prepareFunctionsUpload(c.buildRoot, functionsRoot, structuredClone(config), [], undefined, { exportType: "zip" }), archive = read(packaged.pathToSource), neutral = require("./backendRuntimeClosure31.cjs"), verified = neutral.verifyArchiveBytes31(archive, archiveExpectedFiles);
            need(verified.sourceArchiveHash === packaged.hash, "original package hash differs");
            write(path.join(c.outputDirectory, "archive.zip"), archive);
            write(path.join(c.outputDirectory, "archive-members.json"), archiveExpectedFiles);
            write(path.join(c.outputDirectory, "result.json"), {
                schemaVersion: 1, documentType: "build31-business-original-package-result", source: c.source, sourceArchiveHash: verified.sourceArchiveHash, environmentVariables, endpoints, originalArchive: { path: packaged.pathToSource, sha256: sha(archive), bytes: archive.length }, archive: binding(path.join(c.outputDirectory, "archive.zip")), archiveExpectedFiles: binding(path.join(c.outputDirectory, "archive-members.json"))
            });
        }
    }
    catch (error) {
        originalError = error;
        throw error;
    }
    finally {
        try {
            restore();
        }
        catch (cleanup) {
            throw originalError ? new AggregateError([originalError, cleanup], "intent worker failed and cleanup failed") : cleanup;
        }
    }
}
function runIntentPython31({ python, requestFile, runnerDirectory, operation, cwd, environment, limits }) {
    need(["manifest", "package"].includes(operation), "fixed preparation operation required");
    const retain = result => {
        write(path.join(runnerDirectory, operation + ".stdout.bin"), result.stdout ?? Buffer.alloc(0));
        write(path.join(runnerDirectory, operation + ".stderr.bin"), result.stderr ?? Buffer.alloc(0));
    };
    let result;
    try {
        // This shared boundary verifies the entire schema2 installation before
        // and after launch and fixes -I/-S/-B plus the selected Python root.
        result = require("./collectBusinessRuntime31.cjs").runPythonRunner31(python, requestFile, {
            cwd, env: environment, windowsHide: true, encoding: null, maxBuffer: 1024 * 1024,
            timeout: (limits.commandSeconds + limits.cleanupSeconds * 3 + 15) * 1000
        });
    }
    catch (error) {
        if (error.pythonResult) {
            try {
                retain(error.pythonResult);
            }
            catch (persistence) {
                throw new AggregateError([error, persistence], "Python integrity failure and original stream persistence failed");
            }
        }
        throw error;
    }
    retain(result);
    return result;
}
function prepareBusinessIntent31(config) {
    const ctx = preflightBusinessIntent31(config), root = ctx.attemptRoot, evidence = ctx.evidenceDirectory;
    fs.mkdirSync(root, { mode: 0o700 });
    let current = "initialization";
    const progress = [];
    try {
        const startedAtUtc = utc(), beforeFile = write(path.join(root, "runtime-before.json"), ctx.population), beforeBytes = read(beforeFile);
        const originalProject = write(path.join(root, "inputs/project-config-original.json"), ctx.originals.project), originalParameters = write(path.join(root, "inputs/parameters-original.json"), ctx.originals.parameters);
        const functionsMap = write(path.join(root, "functions-files.json"), admittedFunctionsMap31(ctx.population)), emittedMap = write(path.join(root, "emitted-files.json"), ctx.population.emittedFiles), cliMap = write(path.join(root, "cli-files.json"), ctx.population.installedFiles.cli);
        const sourceRoot = path.join(ctx.proof.buildRoot, "tools/release"), sourceFiles = Object.fromEntries(Object.entries(ctx.population.sourceFiles).filter(([n]) => n.startsWith("tools/release/")).map(([n, h]) => [n.slice(14), h]));
        const temp = path.join(root, "temporary"), home = path.join(root, "home");
        createDirectory31(temp);
        createDirectory31(home);
        createDirectory31(path.join(root, "processes"));
        const explicit = validateInputOriginals31({
            projectConfigOriginal: ctx.originals.project, parametersOriginal: ctx.originals.parameters, source: ctx.source, earliestUtc: ctx.proof.completedAtUtc, latestUtc: startedAtUtc
        });
        const environment = {
            SystemRoot: config.systemRoot, WINDIR: config.systemRoot, HOME: home, USERPROFILE: home, APPDATA: home, LOCALAPPDATA: home, XDG_CONFIG_HOME: home, TEMP: temp, TMP: temp, TMPDIR: temp, PATH: path.dirname(ctx.proof.runtime.nodeExecutable.path), GCLOUD_PROJECT: PROJECT, FIREBASE_CONFIG: JSON.stringify(explicit.firebaseConfig), FUNCTIONS_CONTROL_API: "true", [PARAM]: "false"
        };
        let manifestBinding = null, packageResult;
        for (const operation of ["manifest", "package"]) {
            current = operation;
            producerCheck31(ctx);
            need(same(runtimePopulation31(ctx), ctx.population), "runtime population changed before preparation command");

            const outputDirectory = path.join(root, "outputs", operation);
            createDirectory31(outputDirectory);
            const configuration = {
                schemaVersion: 1, documentType: "build31-business-intent-worker-config", operation, source: ctx.source, buildRoot: ctx.proof.buildRoot, outputDirectory, projectConfigOriginal: binding(originalProject), parametersOriginal: binding(originalParameters), expectedFunctions: ctx.expectedFunctions, runtimeBefore: binding(beforeFile), manifest: manifestBinding
            };
            const configurationFile = write(path.join(root, "configurations", operation + ".json"), configuration);
            const request = {
                schemaVersion: 1, operation, sourceRoot, sourceFiles, nodeExecutable: ctx.proof.runtime.nodeExecutable, runtime: { cliEntrypoint: ctx.proof.runtime.cliEntrypoint.path, cliFileBindings: binding(cliMap) }, functionsRoot: path.join(ctx.proof.buildRoot, "functions"), functionsFiles: binding(functionsMap), emittedFiles: binding(emittedMap), configuration: binding(configurationFile)
            };
            const requestFile = write(path.join(root, "requests", operation + ".json"), request), argv = ["--no-global-search-paths", path.join(ctx.proof.buildRoot, BOOTSTRAP), "--intent-worker", requestFile, sha(read(requestFile))], processDir = path.join(root, "processes", operation);
            const bridgeFile = write(path.join(root, "supervisor-requests", operation + ".json"), {
                schemaVersion: 1, parentPid: process.pid, supervisorSha256: SUPERVISOR_SHA, executable: ctx.proof.runtime.nodeExecutable.path, arguments: argv, cwd: ctx.proof.buildRoot, environment, outputDirectory: processDir, timeoutSeconds: config.limits.commandSeconds, maxOutputBytes: config.limits.outputBytes, cleanupSeconds: config.limits.cleanupSeconds
            });
            const run = runIntentPython31({
                python: config.python, requestFile: bridgeFile, runnerDirectory: path.join(root, "runner"),
                operation, cwd: root, environment, limits: config.limits
            });
            const resultFile = path.join(processDir, "result.json"), measured = decode(read(resultFile));
            progress.push({ operation, supervisor: pointer(evidence, resultFile) });
            write(path.join(root, "progress", operation + ".json"), progress);
            verifyOriginalProcess31(measured, {
                executable: ctx.proof.runtime.nodeExecutable.path, argv, cwd: ctx.proof.buildRoot, processDir, startedAtUtc, latestUtc: utc()
            });
            need(same(runtimePopulation31(ctx), ctx.population), "runtime population changed during preparation command");
            need(!run.error && run.status === 0 && measured.status === "SUCCESS" && measured.exitCode === 0 && measured.jobAssigned && measured.resumed && measured.executable === ctx.proof.runtime.nodeExecutable.path && same(measured.arguments, argv) && measured.cwd === ctx.proof.buildRoot, "original preparation command failed or differs");
            const outputResult = path.join(outputDirectory, "result.json"), originalResult = verifyWorkerResult31({
                operation, result: decode(read(outputResult)), outputDirectory, source: ctx.source, expectedFunctions: ctx.expectedFunctions, temporaryRoot: temp
            });
            const record = {
                schemaVersion: 1, documentType: "build31-business-intent-original-process", kind: operation, sourceBefore: ctx.source, sourceAfter: ctx.source, executable: ctx.proof.runtime.nodeExecutable.path, executableSha256: ctx.proof.runtime.nodeExecutable.sha256, argv, cwd: ctx.proof.buildRoot, startedAtUtc: measured.startedAtUtc, completedAtUtc: measured.completedAtUtc, exitCode: measured.exitCode, signal: null, error: null, request: pointer(evidence, requestFile), configuration: pointer(evidence, configurationFile), supervisor: pointer(evidence, resultFile), stdout: pointer(evidence, path.join(processDir, "stdout.bin")), stderr: pointer(evidence, path.join(processDir, "stderr.bin")), result: pointer(evidence, outputResult)
            };
            progress.at(-1).process = pointer(evidence, write(path.join(root, "commands", operation + ".json"), record));
            if (operation === "manifest") {
                manifestBinding = binding(path.join(outputDirectory, "manifest.json"));
                validateManifest31(decode(bound(manifestBinding)), ctx.expectedFunctions);
            }
            else
                packageResult = originalResult;
        }
        current = "final-verification";
        const after = runtimePopulation31(ctx);
        need(same(after, ctx.population), "runtime population changed at completion");
        const afterFile = write(path.join(root, "runtime-after.json"), after);
        need(read(afterFile).equals(beforeBytes), "before/after population bytes differ");
        const completedAtUtc = utc(), archiveFile = path.join(root, "outputs/package/archive.zip"), membersFile = path.join(root, "outputs/package/archive-members.json"), archive = read(archiveFile), members = decode(read(membersFile)), verified = ctx.api.neutral.verifyArchiveBytes31(archive, members);
        need(packageResult.sourceArchiveHash === verified.sourceArchiveHash && packageResult.archive.sha256 === sha(archive), "retained package result differs");
        const intent = {
            schemaVersion: 1, documentType: "firebase-cli-approved-intended-hash-inputs", source: ctx.source, sourceBefore: ctx.source, sourceAfter: ctx.source, sourceArchiveHash: verified.sourceArchiveHash, codebase: "default", startedAtUtc, completedAtUtc, environmentVariables: packageResult.environmentVariables, endpoints: packageResult.endpoints, archive: pointer(evidence, archiveFile)
        };
        const intentFile = write(path.join(root, "intended-hash-inputs.json"), intent), envelope = {
            schemaVersion: 1, documentType: "build31-business-intent-preparation", source: ctx.source, runtimeProof: config.runtimeProof, startedAtUtc, completedAtUtc, producerBindings: ctx.producers, projectConfigOriginal: pointer(evidence, originalProject), parametersOriginal: pointer(evidence, originalParameters), manifestProcess: progress[0].process, packageProcess: progress[1].process, manifest: pointer(evidence, manifestBinding.path), archiveExpectedFiles: pointer(evidence, membersFile), intendedHashInputs: pointer(evidence, intentFile), runtimeBefore: pointer(evidence, beforeFile), runtimeAfter: pointer(evidence, afterFile), sourceBefore: ctx.source, sourceAfter: ctx.source, processExecutionAuthenticated: false, deploymentAuthorized: false
        };
        const envelopeFile = write(path.join(root, "intent-preparation.json"), envelope);
        return {
            evidenceDirectory: evidence, intendedHashInputs: envelope.intendedHashInputs, intentPreparation: pointer(evidence, envelopeFile), processExecutionAuthenticated: false, deploymentAuthorized: false
        };
    }
    catch (error) {
        try {
            write(path.join(root, "failure.json"), {
                schemaVersion: 1, status: "FAILED", kind: current, atUtc: utc(), error: String(error.message), completedProcessRecords: progress, successfulPreparationWritten: fs.existsSync(path.join(root, "intent-preparation.json")), noAutomaticRetry: true, processExecutionAuthenticated: false, deploymentAuthorized: false
            });
        }
        catch (persistence) {
            throw new AggregateError([error, persistence], "intent preparation and original failure persistence failed");
        }
        throw error;
    }
}
module.exports = {
    SELF, preflightBusinessIntent31, prepareBusinessIntent31, runtimePopulation31, runIntentWorker31, runIntentPython31, validateInputOriginals31, validateManifest31, admittedFunctionsMap31, verifyOriginalProcess31, verifyWorkerResult31
};
if (require.main === module) {
    process.stderr.write("Use the reviewed credential-free preparation caller; worker entry is fixed in business31CaptureBootstrap.cjs.\n");
    process.exitCode = 1;
}
