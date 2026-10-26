"use strict";
// Source-bound component fixture only. The original pinned CLI and auth are
// untouched; fake credentials stay in scratch, and only physical HTTPS is fake.
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const { Writable, Readable } = require("node:stream");
const { isDeepStrictEqual } = require("node:util");
const INITIAL = "CANARY_PRELAUNCH_INITIAL_ACCESS_DO_NOT_LOG";
const REFRESH = "CANARY_PRELAUNCH_REFRESH_DO_NOT_LOG";
const RENEWED = "CANARY_PRELAUNCH_RENEWED_ACCESS_DO_NOT_LOG";

async function runCase(caseId, data) {
  assert.equal(caseId, "installed-positive");
  const bootstrap = require("./business31CaptureBootstrap.cjs");
  assert(bootstrap.isComponentChild31("bootstrap-regressions"));
  const selected = JSON.parse(fs.readFileSync(path.join(__dirname, "CASE.json"), "utf8"));
  const { scratch, scenario } = selected;
  const fd = fs.openSync(path.join(scratch, "events.jsonl"), "wx"), rawWrite = fs.writeSync;
  let sequence = 0, sessionReturned = false, sessionError = null, cleanupObserved = false, foreignHook = null, lateClient = null;
  const event = value => {
    const raw = Buffer.from(JSON.stringify({ sequence: ++sequence, ...value }) + "\n");
    assert(sequence <= 128 && raw.length <= 65536);
    assert.equal(rawWrite(fd, raw), raw.length);
  };
  const cliRoot = path.dirname(path.dirname(path.dirname(path.dirname(data.runtime.cliEntrypoint))));
  const fence = require("./business31CliOfflineFence.cjs").installOfflineFence({
    scratch, source: __dirname, cliRoot, readFiles: [process.execPath, data.runtime.cliFileBindings.path], event
  });
  const kernel = require("./business31CliSyntheticKernel.cjs");
  const originalRead = fs.readFileSync;
  const metadataReader = kernel.createSyntheticKernelReader({ readFileSync: originalRead,
    fixture: selected.kernel, scratch, event });
  fs.readFileSync = metadataReader;
  const module = require("./business31ReadOnlyPrelaunch.cjs");
  const actualEnv = Object.fromEntries(Object.entries(process.env).map(([k,v])=>[k.toUpperCase(),v]));
  const expectedEnv = Object.fromEntries(Object.entries(selected.environment).map(([k,v])=>[k.toUpperCase(),v]));
  event({ kind: "FIXTURE_SELECTED_ENVIRONMENT_KEYS", missing: Object.keys(expectedEnv).filter(k=>!Object.hasOwn(actualEnv,k)),
    extra: Object.keys(actualEnv).filter(k=>!Object.hasOwn(expectedEnv,k)), changed: Object.keys(expectedEnv).filter(k=>Object.hasOwn(actualEnv,k)&&actualEnv[k]!==expectedEnv[k]) });
  const store = selected.account.firebaseConfigPath;
  fs.mkdirSync(path.dirname(store), { recursive: true });
  const motd = { minVersion: scenario === "cached-high" ? "15.22.5" : scenario === "cached-malformed" ? "invalid" : "3.0.5",
    fetched: Date.now() - (scenario === "cached-high" || scenario === "cached-malformed" ? 1000 : 86400000 + 60000) };
  fs.writeFileSync(store, JSON.stringify({ user: { email: selected.account.email }, tokens: {
    access_token: INITIAL, refresh_token: REFRESH, expires_at: Date.now() + (scenario === "not-due" ? 3600000 : scenario === "refresh-margin" ? 14 * 60000 : -60000), scopes: [] },
    motd, usage: false, apiEnablementCache: { [module.PROJECT]: { "cloudfunctions.googleapis.com": true } }
  }), { flag: "wx" });
  const https = require("node:https"), initialRequest = Object.getOwnPropertyDescriptor(https, "request");
  const wire = [];
  const physical = function (input, options, cb) {
    const effective = require("./runtimeDeploymentTransportGuard31.cjs").effectiveRequest31(input, options, "https:");
    const { url, method } = effective;
    const headerMap = new Map(Object.entries({ ...(typeof input === "object" && !(input instanceof URL) ? input.headers : {}),
      ...(options && typeof options === "object" ? options.headers : {}) }).map(([k, v]) => [k.toLowerCase(), v]));
    const chunks = [];
    const req = new Writable({ write(chunk, enc, done) { chunks.push(Buffer.from(chunk)); done(); }, final(done) {
      try {
        let body, status = 200;
        const raw = Buffer.concat(chunks);
        if (url.href === module.TOKEN) {
          assert.equal(method, "POST");
          const form = raw.toString();
          assert(form.includes('name="refresh_token"\r\n\r\n' + REFRESH));
          assert(form.includes('name="client_secret"'));
          body = { access_token: RENEWED, token_type: "Bearer", expires_in: 3600 };
        } else if (url.href === module.MOTD) {
          assert.equal(raw.length, 0); assert.equal(headerMap.has("authorization"), false);
          body = { minVersion: scenario === "fetched-high" ? "15.22.5" : "3.0.5" };
        } else {
          assert.equal(String(headerMap.get("authorization")), "Bearer " + RENEWED);
          if (url.href === module.PERMISSION_URL) {
            assert.deepEqual(JSON.parse(raw), { permissions: module.PERMISSIONS });
            body = { permissions: scenario === "permission-refusal" ? [] : module.PERMISSIONS };
          } else if (url.href === module.V1) { assert.equal(raw.length, 0); body = { functions: [], unreachable: [] }; }
          else if (url.href === module.V2) {
            assert.equal(raw.length, 0);
            body = { functions: scenario === "cohort-mismatch" ? selected.functions.slice(1) : selected.functions, unreachable: [] };
          } else throw Error("UNEXPECTED_OFFLINE_WIRE_REQUEST");
        }
        const row = { method, host: url.hostname, path: url.pathname, status };
        wire.push(row); event({ kind: "OFFLINE_PHYSICAL_READ", ...row });
        const response = Readable.from([Buffer.from(JSON.stringify(body))]);
        Object.assign(response, { statusCode: status, statusMessage: "OK", headers: { "content-type": "application/json" },
          rawHeaders: ["content-type", "application/json"], httpVersion: "1.1" });
        req.emit("response", response); done();
      } catch { done(Error("SYNTHETIC_READ_ONLY_WIRE_FAILURE")); }
    } });
    req.abort = () => req.destroy(); req.setTimeout = () => req; req.flushHeaders = () => {};
    req.getHeaders = () => Object.fromEntries(headerMap); req.getHeader = key => headerMap.get(key.toLowerCase());
    req.setHeader = (key, value) => { headerMap.set(key.toLowerCase(), value); return req; };
    req.appendHeader = (key, value) => { const name = key.toLowerCase(); headerMap.set(name, headerMap.has(name) ? [].concat(headerMap.get(name), value) : value); return req; };
    if (typeof options === "function") req.on("response", options); if (cb) req.on("response", cb);
    return req;
  };
  Object.defineProperty(https, "request", { ...initialRequest, value: physical });
  let restored = false;
  const restoreFixture = () => {
    if (restored) return; restored = true;
    // A completed primitive intentionally retains terminal network fences until
    // the real process exits. Pre-entry refusals have only this fake hook.
    if (https.request === physical) Object.defineProperty(https, "request", initialRequest);
    assert.equal(fs.readFileSync, metadataReader, "Foreign fixture filesystem hook retained");
    fs.readFileSync = originalRead;
  };
  process.once("exit", code => {
    try { restoreFixture(); } catch { process.exitCode = 1; }
    const expected = module.normalizeEnv31({ ...selected.environment, IS_FIREBASE_CLI: "true" });
    const actual = module.normalizeEnv31(process.env);
    event({ kind: "FIXTURE_POST_CLI_ENVIRONMENT_KEYS", missing: Object.keys(expected).filter(k => !Object.hasOwn(actual, k)),
      extra: Object.keys(actual).filter(k => !Object.hasOwn(expected, k)),
      changed: Object.keys(expected).filter(k => Object.hasOwn(actual, k) && actual[k] !== expected[k]) });
    event({ kind: "FIXTURE_EXIT", code, effectiveExitCode: process.exitCode ?? code, sessionReturned,
      sessionError, cleanupObserved, offlineDenials: fence.denials, physicalReadCount: wire.length,
      networkForwarded: false, productionMutationAuthorized: false });
  });
  try {
    const result = await module.runReadOnlyPrelaunch31({ runtime: data.runtime, node: selected.node,
      environment: selected.environment, cwd: selected.cwd, account: selected.account, names: selected.names,
      emit: row => {
        if (row.kind === "read-only-prelaunch-cleanup") cleanupObserved = row.cleanupComplete;
        event(row);
        if (row.kind === "functions-v2" && ["late-exit-api", "late-exit-authenticated-motd"].includes(scenario))
          lateClient = require(path.join(path.dirname(path.dirname(data.runtime.cliEntrypoint)), "apiv2.js")).Client;
        if (row.kind === "functions-v2" && scenario === "unexpected-home")
          process.env.HOME = path.join(scratch, "unselected-home");
        if (row.kind === "functions-v2" && ["foreign-api", "foreign-loader"].includes(scenario)) {
          const target = scenario === "foreign-loader" ? require("node:module") : require(path.join(path.dirname(path.dirname(data.runtime.cliEntrypoint)), "apiv2.js")).Client.prototype;
          const key = scenario === "foreign-loader" ? "_load" : "request", original = target[key];
          const foreign = function () { return original.apply(this, arguments); };
          target[key] = foreign; foreignHook = { target, key, foreign };
          event({ kind: "FOREIGN_FIXTURE_HOOK_INSTALLED", key });
        }
      } });
    sessionReturned = true;
    event({ kind: "READ_ONLY_SESSION_RESULT", ...result });
    if (scenario === "late-exit-read") process.once("exit", () => {
      let blocked = false;
      try { https.request("https://unreviewed.example.invalid/late", { method: "POST", headers: { Authorization: "Bearer " + REFRESH } }).end(REFRESH); }
      catch { blocked = true; }
      event({ kind: "LATE_EXIT_REQUEST_BLOCKED", blocked, networkForwarded: false });
    });
    if (scenario === "late-exit-api") {
      assert.equal(typeof lateClient, "function");
      process.once("exit", () => {
        // Even a previously admitted token endpoint is closed after the result.
        // The owned API wrapper sets the sticky/native failure synchronously;
        // no promise settlement at process exit is claimed as closure evidence.
        new lateClient({ urlPrefix: "https://www.googleapis.com", auth: false }).request({
          method: "POST", path: "/oauth2/v3/token", body: { refresh_token: REFRESH }
        }).catch(() => {});
        event({ kind: "LATE_EXIT_API_REQUEST_ATTEMPTED", networkForwarded: false });
      });
    }
    if (scenario === "late-exit-authenticated-motd") {
      assert.equal(typeof lateClient, "function");
      // Registered after the session returns, hence after its exit auditor.
      // urlOf rejects this authenticated public request before guard.before.
      process.once("exit", () => {
        const pending = new lateClient({ urlPrefix: "https://firebase-public.firebaseio.com", auth: true }).request({
          method: "GET", path: "/cli.json"
        });
        assert(pending instanceof Promise);
        pending.catch(() => {});
        event({ kind: "LATE_EXIT_AUTHENTICATED_MOTD_ATTEMPTED", promiseReturned: true, networkForwarded: false });
      });
    }
  } catch (error) {
    sessionError = typeof error.code === "string" ? error.code : "READ_ONLY_SESSION_REFUSED";
    if (foreignHook) event({ kind: "FOREIGN_FIXTURE_HOOK_PRESERVED", key: foreignHook.key, preserved: foreignHook.target[foreignHook.key] === foreignHook.foreign });
    event({ kind: "READ_ONLY_SESSION_REJECTED", code: sessionError });
    process.exitCode = 1;
  } finally { restoreFixture(); }
}

module.exports = { runCase, CANARIES: [INITIAL, REFRESH, RENEWED] };
