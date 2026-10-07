"use strict";
// Fixed, fresh-process component entry. It is not a deployment controller or a hostile-host sandbox.
// An operational parent must independently select the admitted Node and source bytes.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto"), Module = require("node:module");
const { fileURLToPath, pathToFileURL } = require("node:url"), { isDeepStrictEqual: same, TextDecoder } = require("node:util");
const { spawnSync } = require("node:child_process");
const SELF = "business31CaptureBootstrap.cjs";
const SUITES = Object.freeze({ "controller-primitives": "business31OperationalController.test.cjs", "capture-session": "business31CaptureSession.test.cjs", "prepared-hook": "business31PreparedHook.test.cjs", "load-boundary": "business31CliLoadBoundary.test.cjs", "bootstrap-regressions": "business31CaptureBootstrap.test.cjs", "capture-recorder": "business31Capture.test.cjs", "capture-installed": "business31CaptureInstalled.test.cjs", "capture-pins": "business31CapturePins.test.cjs", "backend-closure": "business31BackendClosure.test.cjs" });
const CASE_IDS = Object.freeze({
    "load-boundary": [
        "early-api",
        "early-apply",
        "valid-session",
        "import-throws",
        "persistence-fails",
        "late-new",
        "late-cached",
        "unknown-cache",
        "replaced-exports",
        "nested",
        "foreign-owner",
        "escaped-require",
        "bad-map",
        "optional-missing",
        "cycle-positive",
        "evaluated-cjs-swap",
        "evaluated-json-swap",
        "json-positive",
        "native-refused",
        "esm-refused",
        "cached-esm-refused",
        "dynamic-esm-refused",
        "dynamic-cjs-refused",
        "optional-integrity-caught",
        "later-hook-registration",
        "returned-source-accessor",
        "returned-source-mutable-buffer",
        "accessor-export-positive",
        "accessor-export-replaced"
    ],
    "bootstrap-regressions": [
        "package-main",
        "package-exports",
        "cached-client",
        "cached-apply",
        "cached-writer",
        "cached-hook",
        "escaped-registrar",
        "extension-before",
        "extension-after",
        "compile-before",
        "compile-after",
        "installed-positive",
        "environment-positive"
    ]
});
function validateDispatch(suite, caseId) {
    need(Object.hasOwn(SUITES, suite), "fixed component suite required");
    need(Object.hasOwn(CASE_IDS, suite) ? CASE_IDS[suite].includes(caseId) : caseId === null, "fixed component case required before import");
}
const sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const need = (x, m) => { if (!x)
    throw Error("Business capture bootstrap: " + m); };
const descriptorSame = (a, b) => !!a && !!b && a.enumerable === b.enumerable && a.configurable === b.configurable && Object.hasOwn(a, "value") === Object.hasOwn(b, "value") && (Object.hasOwn(a, "value") ? Object.is(a.value, b.value) && a.writable === b.writable : a.get === b.get && a.set === b.set);
let active = null;
let selectedSuite = null;
let selectedOperation = null;
let selectedIntentOperation = null;
function regular(file, directory = false) {
    const absolute = path.resolve(file);
    let part = path.parse(absolute).root;
    for (const name of absolute.slice(part.length).split(path.sep).filter(Boolean)) {
        part = path.join(part, name);
        const st = fs.lstatSync(part);
        need(!st.isSymbolicLink(), "redirected path refused");
        need(part === absolute ? (directory ? st.isDirectory() : st.isFile()) : st.isDirectory(), "regular path required");
    }
    return absolute;
}
function exact(value, keys, label) { need(value && typeof value === "object" && !Array.isArray(value) && same(Object.keys(value).sort(), [...keys].sort()), label + " fields differ"); }
function readJson(file, hash) { file = regular(file); const st = fs.statSync(file); need(st.size <= 8 * 1024 * 1024, "request bound exceeded"); const bytes = fs.readFileSync(file); need(sha(bytes) === hash, "request bytes differ"); return JSON.parse(new TextDecoder("utf8", { fatal: true }).decode(bytes)); }
function sourceMap(root) { const result = {}; let directories = 0; function walk(dir) { need(++directories <= 100000, "source directory bound exceeded"); for (const name of fs.readdirSync(dir).sort()) {
    const file = path.join(dir, name), st = fs.lstatSync(file);
    need(!st.isSymbolicLink(), "source redirect refused");
    if (st.isDirectory())
        walk(file);
    else {
        need(st.isFile() && Object.keys(result).length < 50000, "source file bound exceeded");
        Object.defineProperty(result, path.relative(root, file).split(path.sep).join("/"), { value: sha(fs.readFileSync(regular(file))), enumerable: true });
    }
} } walk(root); return result; }
function createPopulation(root, bindings) {
    root = regular(root, true);
    need(bindings && typeof bindings === "object" && !Array.isArray(bindings), "population map required");
    const names = Object.keys(bindings);
    need(names.length > 0 && names.length <= 50000, "population bound exceeded");
    for (const n of names)
        need(n.length <= 400 && !/[\\\0\r\n]/.test(n) && n.split("/").every(v => v && v !== "." && v !== "..") && /^[A-F0-9]{64}$/.test(bindings[n]), "population member differs");
    const found = [];
    let directories = 0;
    function walk(dir) { need(++directories <= 100000, "directory bound exceeded"); for (const row of fs.readdirSync(dir, { withFileTypes: true })) {
        const file = path.join(dir, row.name), st = fs.lstatSync(file);
        need(!st.isSymbolicLink(), "population redirect refused");
        if (st.isDirectory())
            walk(file);
        else {
            need(st.isFile() && found.length < 50000, "population member differs");
            const name = path.relative(root, file).split(path.sep).join("/");
            need(Object.hasOwn(bindings, name) && sha(fs.readFileSync(file)) === bindings[name], "population bytes differ");
            found.push(name);
        }
    } }
    walk(root);
    need(same(found.sort(), names.sort()), "complete population differs");
    return { root, bindings: Object.freeze({ ...bindings }), identity: sha(Buffer.from(JSON.stringify(bindings))) };
}
function installFreshGuard(sourceRoot, sourceFiles, phaseEntry = null) {
    need(active === null, "bootstrap cannot reopen");
    const cacheNames = Object.keys(Module._cache);
    if (phaseEntry === null) {
        need(require.main === module && cacheNames.length === 1 && Module._cache[__filename] === module, "fresh fixed process entry required");
    } else {
        const fixedEntry = path.join(__dirname, "captureBusiness31PreparedInputs.cjs");
        need(phaseEntry === require.main && phaseEntry.filename === fixedEntry && phaseEntry.loaded === true &&
            cacheNames.length === 2 && Module._cache[fixedEntry] === phaseEntry && Module._cache[__filename] === module &&
            module.parent === phaseEntry, "only exact fresh CAPTURE facade/bootstrap cache permitted");
    }
    need(same(process.execArgv, selectedOperation === null ? [] : ["--no-global-search-paths"]) &&
        !process.env.NODE_OPTIONS && !process.env.NODE_PATH, "preloaded Node execution refused");
    const populations = [createPopulation(sourceRoot, sourceFiles)], known = new Map(), loading = new Map(), leases = [];
    need(module.loaded === true, "main module evaluation must finish before startup");
    known.set(__filename, { module, exportsDescriptor: Object.getOwnPropertyDescriptor(module, "exports") });
    if (phaseEntry) known.set(phaseEntry.filename, {module:phaseEntry, exportsDescriptor:Object.getOwnPropertyDescriptor(phaseEntry,"exports")});
    const originalLoad = Object.getOwnPropertyDescriptor(Module, "_load"), originalResolve = Object.getOwnPropertyDescriptor(Module, "_resolveFilename"), originalRegister = Object.getOwnPropertyDescriptor(Module, "registerHooks"), cache = Module._cache;
    const extensions = Module._extensions, extensionDescriptors = Object.getOwnPropertyDescriptors(extensions), compile = Object.getOwnPropertyDescriptor(Module.prototype, "_compile");
    let failed = false, terminal = false, cli = null, hook = null;
    const bad = (ok, message) => { if (!ok) {
        failed = true;
        const error = Error("Business capture CLI load: " + message);
        error.code = "BUSINESS_CLI_LOAD_INTEGRITY";
        throw error;
    } };
    const isInside = (root, file) => { const rel = path.relative(root, path.resolve(file)); return rel !== "" && !path.isAbsolute(rel) && rel !== ".." && !rel.startsWith(".." + path.sep); };
    const population = file => populations.find(p => isInside(p.root, file));
    function verify(file) { try {
        const p = population(file);
        bad(p, "module escaped bound population");
        regular(file);
        const real = fs.realpathSync(file), name = path.relative(p.root, real).split(path.sep).join("/");
        bad(isInside(p.root, real) && Object.hasOwn(p.bindings, name) && sha(fs.readFileSync(real)) === p.bindings[name], "unbound or changed module");
        return { file: real, p };
    }
    catch (error) {
        failed = true;
        throw error;
    } }
    function metadataAt(file) { const p = population(file); if (!p)
        return; let dir = file; try {
        if (!fs.statSync(dir).isDirectory())
            dir = path.dirname(dir);
    }
    catch {
        dir = path.dirname(dir);
    } while (dir === p.root || isInside(p.root, dir)) {
        const pkg = path.join(dir, "package.json"), name = path.relative(p.root, pkg).split(path.sep).join("/");
        if (Object.hasOwn(p.bindings, name) || fs.existsSync(pkg))
            verify(pkg);
        if (dir === p.root)
            break;
        dir = path.dirname(dir);
    } }
    function resolutionMetadata(request, parent) {
        if (parent?.filename)
            metadataAt(parent.filename);
        if (typeof request !== "string" || Module.isBuiltin(request))
            return;
        if (path.isAbsolute(request))
            metadataAt(request);
        else if (request.startsWith("."))
            metadataAt(path.resolve(path.dirname(parent?.filename ?? __filename), request));
        else {
            const name = request.startsWith("@") ? request.split("/").slice(0, 2).join("/") : request.split("/")[0];
            for (const base of parent?.paths ?? []) {
                metadataAt(path.join(base, name));
                metadataAt(path.join(base, request));
            }
        }
    }
    function core() { bad(!failed, "boundary is terminal-failed"); bad(Module._cache === cache && descriptorSame(Object.getOwnPropertyDescriptor(Module, "_resolveFilename"), originalResolve), "resolver/cache changed"); bad(Module._extensions === extensions && same(Object.keys(Object.getOwnPropertyDescriptors(extensions)).sort(), Object.keys(extensionDescriptors).sort()) && Object.keys(extensionDescriptors).every(k => descriptorSame(Object.getOwnPropertyDescriptor(extensions, k), extensionDescriptors[k])) && descriptorSame(Object.getOwnPropertyDescriptor(Module.prototype, "_compile"), compile), "extension/compile path changed"); bad(descriptorSame(Object.getOwnPropertyDescriptor(Module, "registerHooks"), ownedRegister), "registrar changed"); }
    function cached(file, item) { const k = known.get(file); bad(k && k.module === item && descriptorSame(k.exportsDescriptor, Object.getOwnPropertyDescriptor(item, "exports")) && item.loaded === true, "unverified or replaced cached module refused"); }
    const loader = function (request, parent, isMain) {
        if (Module.isBuiltin(request))
            return originalLoad.value.apply(this, arguments);
        core();
        resolutionMetadata(request, parent);
        const resolved = originalResolve.value.call(Module, request, parent, isMain), from = parent?.filename && population(parent.filename);
        if (Module.isBuiltin(resolved))
            return originalLoad.value.apply(this, arguments);
        const p = typeof resolved === "string" && path.isAbsolute(resolved) ? population(resolved) : null;
        bad(!from || p, "bound module dependency escaped population");
        if (!p)
            return originalLoad.value.apply(this, arguments);
        bad(!terminal || p !== cli, "CLI lifetime is terminal");
        metadataAt(resolved);
        const { file } = verify(resolved), item = cache[resolved];
        if (item) {
            const pending = loading.get(resolved);
            if (pending) {
                bad(pending.module === null || pending.module === item, "pending cache changed");
                pending.module = item;
            }
            else
                cached(file, item);
        }
        const outer = !loading.has(resolved), frame = outer ? { module: item ?? null } : loading.get(resolved);
        if (outer)
            loading.set(resolved, frame);
        try {
            const result = originalLoad.value.apply(this, arguments), actual = cache[resolved], d = actual && Object.getOwnPropertyDescriptor(actual, "exports");
            bad(actual && (!frame.module || frame.module === actual) && d && (Object.hasOwn(d, "value") ? Object.is(d.value, result) : typeof d.get === "function"), "module cache identity differs");
            if (outer) {
                bad(actual.loaded, "module evaluation incomplete");
                verify(file);
                if (item)
                    cached(file, actual);
                known.set(file, { module: actual, exportsDescriptor: d });
            }
            return result;
        }
        finally {
            if (outer)
                loading.delete(resolved);
        }
    };
    const ownedLoad = { ...originalLoad, value: loader }, ownedRegister = { ...originalRegister, value: function () { bad(false, "later source-hook registration refused"); } };
    function controlledUrl(url, parentURL) {
        if (typeof url === "string" && Module.isBuiltin(url))
            return null;
        let file = null, parent = null;
        try {
            file = fileURLToPath(url);
        }
        catch { }
        try {
            parent = fileURLToPath(parentURL);
        }
        catch { }
        const p = file && population(file), from = parent && population(parent);
        if (!p && !from)
            return null;
        bad(p && pathToFileURL(file).href === url, "noncanonical module URL refused");
        core();
        bad(!terminal || p !== cli, "CLI lifetime is terminal");
        metadataAt(file);
        return verify(file).file;
    }
    hook = originalRegister.value.call(Module, {
        resolve(specifier, context, nextResolve) { if (Module.isBuiltin(specifier))
            return { url: specifier.startsWith("node:") ? specifier : "node:" + specifier, format: "builtin", shortCircuit: true }; core(); let parent = null; try {
            parent = fileURLToPath(context.parentURL);
        }
        catch { } if (parent)
            resolutionMetadata(specifier, { filename: parent, paths: Module._nodeModulePaths(path.dirname(parent)) }); const result = nextResolve(specifier, context), file = controlledUrl(result.url, context.parentURL); if (file) {
            bad(!new Set(context.conditions ?? []).has("import") && result.format !== "module" && !/\.(mjs|node|ts|mts|cts)$/i.test(file), "unsupported module format/import");
            const item = cache[file], frame = loading.get(file);
            if (item) {
                if (frame) {
                    bad(frame.module === null || frame.module === item, "pending cache changed");
                    frame.module = item;
                }
                else
                    cached(file, item);
            }
        } return result; },
        load(url, context, nextLoad) { const file = controlledUrl(url); if (!file)
            return nextLoad(url, context); bad(context.format !== "module" && !/\.(mjs|node|ts|mts|cts)$/i.test(file), "unsupported module format"); const result = nextLoad(url, context), format0 = result.format, raw = result.source, format = format0 == null && file.endsWith(".js") && loading.has(file) ? "commonjs" : format0; bad(["commonjs", "json"].includes(format), "unsupported evaluated format"); const source = typeof raw === "string" ? Buffer.from(raw, "utf8") : ArrayBuffer.isView(raw) ? Buffer.from(new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength)) : raw instanceof ArrayBuffer ? Buffer.from(new Uint8Array(raw)) : null; const p = population(file), name = path.relative(p.root, file).split(path.sep).join("/"); bad(source && sha(source) === p.bindings[name], "actual evaluation source differs"); return { format, source }; }
    });
    Object.defineProperty(Module, "registerHooks", ownedRegister);
    Object.defineProperty(Module, "_load", ownedLoad);
    active = { assert() { core(); bad(!terminal, "CLI lifetime is terminal"); },
        admitIntentPopulation(root, bindings) {
            try {
                core();
                bad(selectedOperation === "intent" && !cli && !terminal && leases.length === 0,
                    "intent populations must precede the CLI lease");
                const proposed = createPopulation(root, bindings);
                bad(!populations.some(p => p.root === proposed.root || isInside(p.root, proposed.root) || isInside(proposed.root, p.root)), "overlapping intent population");
                for (const file of Object.keys(cache)) bad(!isInside(proposed.root, file), "pre-existing intent cache refused");
                populations.push(proposed);
            } catch (error) { failed = true; terminal = true; throw error; }
        }, bind(runtime) {
            try {
                core();
                bad(!terminal, "CLI lifetime cannot reopen");
                const pointer = runtime?.cliFileBindings;
                exact(pointer, ["path", "sha256"], "CLI inventory pointer");
                const raw = readJson(pointer.path, pointer.sha256);
                const root = path.dirname(path.dirname(path.dirname(path.dirname(runtime.cliEntrypoint))));
                if (cli) {
                    bad(path.resolve(root) === cli.root && same(raw, cli.bindings), "CLI population changed");
                }
                else {
                    const proposed = createPopulation(root, raw);
                    for (const file of Object.keys(cache))
                        bad(!isInside(proposed.root, file), "pre-existing CLI module cache refused");
                    cli = proposed;
                    populations.push(cli);
                    verify(runtime.cliEntrypoint);
                }
                const token = Symbol();
                leases.push(token);
                let released = false;
                return Object.freeze({ assertHealthy() { core(); bad(!released && !terminal, "released CLI lifetime"); }, assertOwned() { core(); bad(!released && descriptorSame(Object.getOwnPropertyDescriptor(Module, "_load"), ownedLoad), "loader ownership changed"); }, isReleased() { return released; }, release() { bad(!released && leases.at(-1) === token, "lease order differs"); let error; try {
                        bad(descriptorSame(Object.getOwnPropertyDescriptor(Module, "_load"), ownedLoad) && descriptorSame(Object.getOwnPropertyDescriptor(Module, "registerHooks"), ownedRegister), "loader ownership changed");
                    }
                    catch (e) {
                        error = e;
                    }
                    finally {
                        leases.pop();
                        released = true;
                        if (!leases.length)
                            terminal = true;
                    } if (error)
                        throw error; } });
            }
            catch (error) {
                failed = true;
                terminal = true;
                throw error;
            }
        }, finish() { terminal = true; const errors = []; try {
            hook.deregister();
        }
        catch (e) {
            errors.push(e);
        } for (const [name, owned, original] of [["_load", ownedLoad, originalLoad], ["registerHooks", ownedRegister, originalRegister]]) {
            if (descriptorSame(Object.getOwnPropertyDescriptor(Module, name), owned))
                Object.defineProperty(Module, name, original);
            else
                errors.push(Error("foreign loader retained"));
        } if (errors.length)
            throw new AggregateError(errors, "bootstrap cleanup incomplete"); } };
    return active;
}
function assertBootstrap31() { need(active, "capture requires the fixed fresh bootstrap; caller flags are not accepted"); active.assert(); }
function installCliLoadBoundary31(runtime) { assertBootstrap31(); return active.bind(runtime); }
function componentEnvironment(directory) { const env = {}; for (const key of ["SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT", "LANG", "LC_ALL"])
    if (process.env[key] !== undefined)
        env[key] = process.env[key]; Object.assign(env, { TEMP: directory, TMP: directory, HOME: directory, USERPROFILE: directory, PATH: path.dirname(process.execPath) }); return env; }
function launchComponentSuite31({ suite, caseId = null, componentData = null, outputDirectory, nodeExecutable = process.execPath, nodeSha256, sourceFiles, gitExecutable = null }) {
    validateDispatch(suite, caseId);
    const directory = regular(outputDirectory, true), node = regular(nodeExecutable);
    need(gitExecutable === null || (typeof gitExecutable === "string" && path.isAbsolute(gitExecutable)), "component Git path must be absolute");
    need(/^[A-F0-9]{64}$/.test(nodeSha256) && sha(fs.readFileSync(node)) === nodeSha256, "component Node bytes differ");
    need(same(sourceMap(__dirname), sourceFiles), "selected component source bytes differ");
    const request = { schemaVersion: 1, operation: "component-test", suite, caseId, componentData, sourceRoot: __dirname, sourceFiles, nodeExecutable: node, nodeSha256, gitExecutable, nonOperational: true };
    const bytes = Buffer.from(JSON.stringify(request) + "\n"), file = path.join(directory, "bootstrap-request.json");
    fs.writeFileSync(file, bytes, { flag: "wx", mode: 0o600 });
    const env = componentEnvironment(directory);
    if (gitExecutable !== null) {
        regular(gitExecutable);
        env.BUSINESS31_TEST_GIT = gitExecutable;
        env.PATH = path.dirname(node) + path.delimiter + path.dirname(gitExecutable);
    }
    const result = spawnSync(node, [__filename, "--component-child", file, sha(bytes)], { cwd: path.resolve(__dirname, "../.."), env, windowsHide: true, encoding: "utf8", timeout: suite === "backend-closure" ? 3600000 : 900000, maxBuffer: 16 * 1024 * 1024 });
    fs.writeFileSync(path.join(directory, "stdout.log"), result.stdout ?? "", { flag: "wx" });
    fs.writeFileSync(path.join(directory, "stderr.log"), result.stderr ?? "", { flag: "wx" });
    const summary = caseId === null ? /^# tests ([1-9]\d*)$/m.exec(result.stdout ?? "") : null;
    const summaryOkay = caseId !== null || (summary && /^# pass [1-9]\d*$/m.test(result.stdout ?? "") && /^# fail 0$/m.test(result.stdout ?? ""));
    return { status: result.status, signal: result.signal,
        error: result.error?.code ?? (result.status === 0 && !summaryOkay ? "EMPTY_OR_INCOMPLETE_COMPONENT_TEST_RUN" : null),
        testCount: summary ? Number(summary[1]) : null, componentOnly: true, processAuthenticated: false, deploymentAuthorized: false };
}
function assertOperational31() {
    assertBootstrap31();
    need(selectedSuite === null && ["controller", "phase"].includes(selectedOperation), "component entry cannot authorize operational dispatch");
}
function assertIntentWorker31(operation) {
    assertBootstrap31();
    need(selectedSuite === null && selectedOperation === "intent" && operation === selectedIntentOperation, "fixed intent worker entry required");
}
function launchBusinessCapture31() {
    throw Error("Business capture requires the fixed --business-controller process entry; a shared-process call is unsupported");
}
function verifySelectedEnvironment31(configuration, extra = {}) {
    const selected=configuration.execution.environment;
    need(selected&&typeof selected==="object"&&!Array.isArray(selected)&&Object.values(selected).every(value=>typeof value==="string"),"explicit protected process environment required");
    const normalized=Object.fromEntries(Object.entries({...selected,...extra}).map(([name,value])=>[name.toUpperCase(),value]));
    need(Object.keys(normalized).length===Object.keys(selected).length+Object.keys(extra).length&&
        same(normalized,Object.fromEntries(Object.entries(process.env).map(([name,value])=>[name.toUpperCase(),value]))),"actual fresh process environment differs from protected selection");
}
async function runOperationalPhaseMain31(entry) {
    need(active === null && process.argv.length === 4 && process.argv[2] === "--config", "fixed CAPTURE --config entry required");
    const digest = process.env.BUSINESS31_PHASE_CONTEXT_SHA256;
    need(typeof digest === "string" && /^[A-F0-9]{64}$/.test(digest), "parent-bound context bytes required");
    const context = readJson(process.argv[3], digest);
    // Exact root is declared and bound by the retained context, not guessed from an arbitrary module path.
    need(context.configuration && typeof context.evidenceDirectory === "string", "retained protected selection required");
    const config = readJson(path.join(context.evidenceDirectory,context.configuration.file), context.configuration.sha256);
    verifySelectedEnvironment31(config,{BUSINESS31_PHASE_CONTEXT_SHA256:digest});
    need(config.execution.sourceRoot === __dirname && config.execution.helperFiles[SELF] === sha(fs.readFileSync(__filename)) &&
        config.execution.nodeExecutable.path === regular(process.execPath) &&
        config.execution.nodeExecutable.sha256 === sha(fs.readFileSync(process.execPath)), "selected phase source/interpreter differs");
    selectedOperation = "phase";
    const guard = installFreshGuard(__dirname, config.execution.helperFiles, entry);
    try {
        await require("./business31OperationalController.cjs").runPhaseChild31({contextFile:process.argv[3], contextSha256:digest, configuration:config});
        process.once("exit",()=>{try{guard.finish();}catch{process.exitCode=1;}});
    } catch (error) {
        try { guard.finish(); } catch (cleanup) { throw new AggregateError([error,cleanup],"phase and cleanup failed"); }
        throw error;
    }
}
async function runOperationalControllerMain31(file, digest) {
    need(active === null, "fresh controller required");
    const config = readJson(file, digest);
    verifySelectedEnvironment31(config);
    need(config.execution.sourceRoot === __dirname && config.execution.helperFiles[SELF] === sha(fs.readFileSync(__filename)) &&
        config.execution.nodeExecutable.path === regular(process.execPath) &&
        config.execution.nodeExecutable.sha256 === sha(fs.readFileSync(process.execPath)), "selected controller source/interpreter differs");
    selectedOperation = "controller";
    const guard = installFreshGuard(__dirname, config.execution.helperFiles);
    try { return await require("./business31OperationalController.cjs").runController31({configuration:config,configurationFile:file,configurationSha256:digest}); }
    finally { guard.finish(); }
}
async function runIntentWorkerMain31(file, digest) {
    need(active === null, "fresh intent worker required");
    const request = readJson(file, digest);
    exact(request, ["schemaVersion", "operation", "sourceRoot", "sourceFiles", "nodeExecutable", "runtime",
        "functionsRoot", "functionsFiles", "emittedFiles", "configuration"], "intent worker request");
    need(request.schemaVersion === 1 && ["manifest", "package"].includes(request.operation), "fixed intent operation required");
    exact(request.nodeExecutable, ["path", "sha256"], "intent interpreter");
    exact(request.runtime, ["cliEntrypoint", "cliFileBindings"], "intent CLI");
    for (const pointer of [request.functionsFiles, request.emittedFiles, request.configuration]) exact(pointer, ["path", "sha256"], "intent pointer");
    need(request.sourceRoot === __dirname && request.sourceFiles[SELF] === sha(fs.readFileSync(__filename)) &&
        request.nodeExecutable.path === regular(process.execPath) && request.nodeExecutable.sha256 === sha(fs.readFileSync(process.execPath)), "selected intent source/interpreter differs");
    selectedOperation = "intent";
    selectedIntentOperation = request.operation;
    const guard = installFreshGuard(__dirname, request.sourceFiles);
    let lease;
    try {
        const root = regular(request.functionsRoot, true);
        guard.admitIntentPopulation(root, readJson(request.functionsFiles.path, request.functionsFiles.sha256));
        const emitted = readJson(request.emittedFiles.path, request.emittedFiles.sha256);
        need(Object.keys(emitted).every(name => name.startsWith("lib/")), "only retained Functions emitted population may load");
        for (const [name, hash] of Object.entries(emitted)) need(sha(fs.readFileSync(regular(path.join(root, name)))) === hash, "retained emitted bytes differ");
        lease = guard.bind(request.runtime);
        await require("./prepareBusinessIntent31.cjs").runIntentWorker31({operation:request.operation,
            configurationFile:request.configuration.path, configurationSha256:request.configuration.sha256});
        lease.assertHealthy();
    } finally {
        try { if (lease && !lease.isReleased()) lease.release(); } finally { guard.finish(); }
    }
}
async function main() {
    if (process.argv.length === 5 && process.argv[2] === "--intent-worker")
        return runIntentWorkerMain31(process.argv[3],process.argv[4]);
    if (process.argv.length === 5 && process.argv[2] === "--business-controller")
        return runOperationalControllerMain31(process.argv[3],process.argv[4]);
    need(process.argv.length === 5 && process.argv[2] === "--component-child", "only fixed component child entry is available; operational capture is closed");
    const input = readJson(process.argv[3], process.argv[4]);
    exact(input, ["schemaVersion", "operation", "suite", "caseId", "componentData", "sourceRoot", "sourceFiles", "nodeExecutable", "nodeSha256", "gitExecutable", "nonOperational"], "component request");
    need(input.schemaVersion === 1 && input.operation === "component-test" && input.nonOperational === true && Object.hasOwn(SUITES, input.suite), "component request differs");
    validateDispatch(input.suite, input.caseId);
    need(input.sourceRoot === __dirname && regular(input.nodeExecutable) === regular(process.execPath) && sha(fs.readFileSync(process.execPath)) === input.nodeSha256, "child Node/source differs");
    need(input.sourceFiles[SELF] === sha(fs.readFileSync(__filename)), "child bootstrap consistency differs");
    // The parent's independently selected bytes are the trust input; this self-check alone authenticates nothing.
    if (input.componentData !== null) {
        need(input.suite === "bootstrap-regressions" && input.caseId === "installed-positive", "component data is not permitted for this case");
        exact(input.componentData, ["runtime"], "component data");
        exact(input.componentData.runtime, ["cliEntrypoint", "cliFileBindings"], "component runtime");
        exact(input.componentData.runtime.cliFileBindings, ["path", "sha256"], "component CLI map");
    }
    const guard = installFreshGuard(__dirname, input.sourceFiles);
    selectedSuite = input.suite;
    try {
        const suite = require(path.join(__dirname, SUITES[input.suite]));
        if (input.caseId !== null) {
            need(typeof suite.runCase === "function", "fixed case entry unavailable");
            await suite.runCase(input.caseId, input.componentData);
        }
    }
    catch (error) {
        try {
            guard.finish();
        }
        catch (cleanup) {
            throw new AggregateError([error, cleanup], "component and cleanup failed");
        }
        throw error;
    }
    if (input.caseId !== null)
        guard.finish();
    else
        process.once("beforeExit", () => { try {
            guard.finish();
        }
        catch (error) {
            process.stderr.write(error.message + "\n");
            process.exitCode = 1;
        } });
}
function isComponentChild31(suite) {
    return active !== null && selectedSuite === suite;
}
function runComponentSuiteTest31(suite) {
    const test = require("node:test"), assert = require("node:assert/strict"), os = require("node:os");
    test("fresh fixed bootstrap: " + suite, t => {
        const outputDirectory = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "business31-component-"));
        const gitName = process.platform === "win32" ? "git.exe" : "git";
        const candidates = process.env.BUSINESS31_TEST_GIT ? [process.env.BUSINESS31_TEST_GIT] :
            (process.env.PATH ?? "").split(path.delimiter).filter(Boolean).map(dir => path.join(dir.replace(/^"|"$/g, ""), gitName));
        const gitExecutable = candidates.find(file => fs.existsSync(file) && fs.statSync(file).isFile()) ?? null;
        const result = launchComponentSuite31({suite, outputDirectory, nodeExecutable:process.execPath,
            nodeSha256:sha(fs.readFileSync(process.execPath)), sourceFiles:sourceMap(__dirname), gitExecutable});
        const stdout = fs.readFileSync(path.join(outputDirectory,"stdout.log"),"utf8");
        const stderr = fs.readFileSync(path.join(outputDirectory,"stderr.log"),"utf8");
        t.diagnostic(stdout);
        assert.equal(result.error, null, stderr);
        assert.equal(result.signal, null, stderr);
        assert.equal(result.status, 0, stdout + "\n" + stderr);
    });
}
module.exports = { SELF, SUITES, sourceMap, isComponentChild31, runComponentSuiteTest31, launchComponentSuite31, launchBusinessCapture31, assertBootstrap31, assertOperational31, assertIntentWorker31, runOperationalPhaseMain31, installCliLoadBoundary31 };
if (require.main === module)
    setImmediate(() => main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; }));
