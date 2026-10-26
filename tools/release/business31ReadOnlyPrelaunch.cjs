"use strict";
// Read-only primitive, not an admission or standalone command. A future private
// caller must independently bind qualified source/account and genuine ROOT
// admission before invoking this function. No such live caller is created here.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const { isDeepStrictEqual: same } = require("node:util");
const transport = require("./runtimeDeploymentTransportGuard31.cjs");
const PROJECT = "crm3-baf-ops-b8638", REGION = "asia-south1";
const MOTD = "https://firebase-public.firebaseio.com/cli.json";
const TOKEN = "https://www.googleapis.com/oauth2/v3/token";
const PERMISSIONS = Object.freeze(["cloudfunctions.functions.list", "firebase.projects.get", "run.services.list"]);
const PERMISSION_URL = "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT + ":testIamPermissions";
const V1 = "https://cloudfunctions.googleapis.com/v1/projects/" + PROJECT + "/locations/-/functions";
const V2 = "https://cloudfunctions.googleapis.com/v2/projects/" + PROJECT + "/locations/-/functions?filter=environment%3D%22GEN_2%22";
const PERMISSION_BODY = Buffer.from(JSON.stringify({ permissions: PERMISSIONS }));
const hash = value => crypto.createHash("sha256").update(value).digest("hex");
const need = (ok, code) => { if (!ok) { const e = Error("Read-only prelaunch refused: " + code); e.code = code; throw e; } };
const normalizedPath = value => { const p = path.resolve(value).replaceAll("\\", "/"); return process.platform === "win32" ? p.toLowerCase() : p; };
function normalizeEnv31(env, platform = process.platform) {
  need(env && typeof env === "object" && !Array.isArray(env), "EXPLICIT_ENVIRONMENT_REQUIRED");
  const out = {};
  for (const [key, value] of Object.entries(env)) {
    need(typeof value === "string", "EXPLICIT_ENVIRONMENT_VALUES_REQUIRED");
    const name = platform === "win32" ? key.toUpperCase() : key;
    need(!Object.hasOwn(out, name) || out[name] === value, "CONFLICTING_ENVIRONMENT_ALIASES");
    out[name] = value;
  }
  return out;
}
function refreshEligible31(expiresAt, now = Date.now()) {
  need(Number.isSafeInteger(expiresAt) && Number.isSafeInteger(now) && now >= 0, "INVALID_TOKEN_EXPIRY");
  return expiresAt < now + 15 * 60000;
}
function route31(url, method) {
  need(url.protocol === "https:" && !url.username && !url.password && !url.port && !url.hash, "UNREVIEWED_READ_ORIGIN");
  if (method === "GET" && url.href === MOTD) return "motd";
  if (method === "POST" && url.href === TOKEN) return "credential-refresh";
  if (method === "POST" && url.href === PERMISSION_URL) return "permissions";
  if (method === "GET" && url.href === V1) return "functions-v1";
  if (method === "GET" && url.href === V2) return "functions-v2";
  need(false, "UNREVIEWED_READ_REQUEST");
}
function safeMetadata31(url, method, status = null) {
  const known = [MOTD, TOKEN, PERMISSION_URL, V1, V2].includes(url?.href);
  return { method: method === "GET" || method === "POST" ? method : "UNKNOWN",
    host: known ? url.hostname : "UNKNOWN", path: known ? url.pathname : "/UNREVIEWED",
    status: Number.isInteger(status) ? status : null };
}

class ReadOnlyPrelaunchGuard31 extends transport.RuntimeDeploymentTransportGuard31 {
  constructor(names, emit = () => {}) {
    need(Array.isArray(names) && names.length === 19 && new Set(names).size === 19 &&
      names.every(n => typeof n === "string" && /^[A-Za-z][A-Za-z0-9_]*$/.test(n)), "EXACT_NINETEEN_NAMES_REQUIRED");
    super({ names, allNames: names, baselineFunctions: {}, phase: "read-only-prelaunch" });
    this.failed = false; this.sealed = false; this.onLateRefusal = null; this.apiCalls = new Set(); this.physicalCalls = new Set();
    this.inFlight = 0; this.emit = emit;
  }
  metadata(kind, url, method, status) {
    const row = { kind, ...safeMetadata31(url, method, status) };
    this.events.push(row); this.emit(row);
  }
  refused(url, method) { this.failed = true; if (this.sealed && this.onLateRefusal) this.onLateRefusal(); if (this.motdRequested && !this.motdAccepted) this.finishMotd31(false); this.metadata("read-only-refused", url, method, null); }
  read(url, method) {
    try {
      need(!this.failed && !this.sealed, "STICKY_READ_ONLY_REFUSAL");
      const route = route31(url, method);
      if (route === "motd" || route === "credential-refresh") return super.read(url, method);
      return { kind: "read" };
    } catch (e) { this.refused(url, method); throw e; }
  }
  before(client, request) {
    let url, method = request?.method ?? "GET";
    try {
      need(!this.failed && !this.sealed, "STICKY_READ_ONLY_REFUSAL");
      url = transport.urlOf(client, request);
      const rawBase = client.opts.urlPrefix + (client.opts.apiVersion ? "/" + client.opts.apiVersion : "") + "/" + request.path.replace(/^\//, "");
      need(rawBase === url.origin + url.pathname, "NONCANONICAL_READ_PATH");
      const route = route31(url, method);
      need(!this.apiCalls.has(route), "READ_ONLY_RETRY_OR_REDIRECT");
      if (route === "credential-refresh") need(client.opts.auth === false, "UNAUTHENTICATED_REFRESH_REQUIRED");
      if (route === "motd" || route === "credential-refresh") super.before(client, request);
      else {
        need(client.opts.auth !== false, "AUTHENTICATED_READ_REQUIRED");
        if (route === "permissions") need(same(request.body, { permissions: PERMISSIONS }) &&
          same(request.headers, { "x-goog-user-project": PROJECT }), "EXACT_READ_PERMISSIONS_REQUIRED");
        else need(request.body === undefined || request.body === null, "BODYLESS_FUNCTION_LIST_REQUIRED");
      }
      this.apiCalls.add(route);
      return { kind: route === "motd" ? "cli-motd" : route === "credential-refresh" ? route : "read",
        route, url: url.href, method };
    } catch (e) { this.refused(url, method); throw e; }
  }
  after(operation, result) {
    const url = new URL(operation.url);
    try {
      need(result?.status === 200, "READ_ONLY_RESPONSE_STATUS");
      const body = result.body;
      if (operation.route === "motd") { super.after(operation, result); this.emit(this.events.at(-1)); return; }
      else if (operation.route === "permissions") need(same(body?.permissions, PERMISSIONS), "READ_PERMISSIONS_NOT_CONFIRMED");
      else if (operation.route === "functions-v1") need(body && typeof body === "object" && !Array.isArray(body) &&
        (body.functions === undefined || Array.isArray(body.functions)) && (body.unreachable === undefined || Array.isArray(body.unreachable)) &&
        (body.functions ?? []).length === 0 && (body.unreachable ?? []).length === 0 && !body.nextPageToken, "UNEXPECTED_GEN_ONE_OR_UNREACHABLE_FUNCTIONS");
      else if (operation.route === "functions-v2") {
        const functions = body?.functions;
        need(Array.isArray(functions) && functions.length === 19 && !body.nextPageToken &&
          (body.unreachable ?? []).length === 0, "INCOMPLETE_FUNCTION_COHORT");
        const names = functions.map(f => {
          need(f?.environment === "GEN_2" && f.state === "ACTIVE" && typeof f.name === "string" &&
            f.name.startsWith(`projects/${PROJECT}/locations/${REGION}/functions/`), "UNEXPECTED_FUNCTION_STATE_OR_REGION");
          const name = f.name.split("/").at(-1); need(f.name === `projects/${PROJECT}/locations/${REGION}/functions/` + name, "EXACT_FUNCTION_RESOURCE_REQUIRED"); return name;
        });
        need(new Set(names).size === 19 && same([...names].sort(), [...this.names].sort()), "FUNCTION_COHORT_DIFFERS");
      }
      this.metadata(operation.route, url, operation.method, result.status);
    } catch (e) { this.refused(url, operation.method); throw e; }
  }
  finish() {
    need(!this.failed && this.inFlight === 0, "READ_ONLY_REQUEST_OR_CLEANUP_FAILED");
    this.assertInitializationSettled31();
    for (const route of ["credential-refresh", "permissions", "functions-v1", "functions-v2"])
      need(this.apiCalls.has(route) && this.physicalCalls.has(route), "REQUIRED_REAL_CLI_READ_NOT_OBSERVED");
    need(this.events.filter(e => e.kind === "credential-refresh" && e.status === 200).length === 1, "REFRESH_NOT_OBSERVED");
    return true;
  }
}

function installReadOnlyPhysicalBoundary31(guard) {
  const https = require("node:https"), http = require("node:http"), descriptor = Object.getOwnPropertyDescriptor(https, "request");
  const httpDescriptor = Object.getOwnPropertyDescriptor(http, "request");
  const original = descriptor.value;
  const wrapped = function (input, options) {
    const base = typeof input === "object" && !(input instanceof URL) ? input : {};
    for (const candidate of [base, options && typeof options === "object" ? options : {}])
      need(candidate.port === undefined || candidate.port === null || candidate.port === "", "READ_EXPLICIT_PORT_REFUSED");
    const effective = transport.effectiveRequest31(input, options, "https:"), url = effective.url, method = effective.method;
    let route;
    try {
      need(!guard.failed && !guard.sealed, "STICKY_READ_ONLY_REFUSAL"); route = route31(url, method);
      need(!guard.physicalCalls.has(route), "READ_ONLY_WIRE_RETRY_OR_REDIRECT"); guard.physicalCalls.add(route);
    } catch (e) { guard.refused(url, method); throw e; }
    const req = original.apply(this, arguments), write = req.write, end = req.end;
    const originalSet = req.setHeader, originalAppend = req.appendHeader;
    let chunks = [], size = 0, refused = false;
    const checkHeaders = () => {
      let hosts = 0;
      for (const [key, value] of Object.entries(req.getHeaders())) {
        const name = key.toLowerCase();
        need(!["cookie", "cookie2", "proxy-authorization"].includes(name), "UNREVIEWED_READ_HEADER");
        if (name === "host") need(++hosts === 1 && value === url.hostname, "READ_HOST_HEADER_DIFFERS");
        if (route !== "credential-refresh") {
          need(!["transfer-encoding", "trailer"].includes(name), "READ_BODY_FRAMING_REFUSED");
          if (name === "content-length") need(String(value) === String(route === "permissions" ? PERMISSION_BODY.length : 0), "READ_CONTENT_LENGTH_DIFFERS");
        }
        if (route === "motd" || route === "credential-refresh") need(name !== "authorization", "UNAUTHENTICATED_PUBLIC_REQUEST_REQUIRED");
      }
    };
    const checked = action => {
      try { need(!refused && !guard.failed && !guard.sealed, "STICKY_READ_ONLY_REFUSAL"); checkHeaders(); return action(); }
      catch (e) { refused = true; guard.refused(url, method); req.destroy(); throw e; }
    };
    req.write = function (chunk, encoding, cb) {
      return checked(() => {
        const data = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, typeof encoding === "string" ? encoding : undefined);
        if (route === "credential-refresh") { size += data.length; need(size <= 16384, "REFRESH_BODY_BOUND"); return write.call(req, chunk, encoding, cb); }
        size += data.length; need(size <= (route === "permissions" ? PERMISSION_BODY.length : 0), "READ_BODY_REFUSED");
        chunks.push(data); const callback = typeof encoding === "function" ? encoding : cb; if (callback) queueMicrotask(callback); return true;
      });
    };
    req.end = function (chunk, encoding, cb) {
      return checked(() => {
        if (chunk !== undefined && chunk !== null && typeof chunk !== "function") req.write(chunk, encoding);
        if (route !== "credential-refresh") {
          const body = Buffer.concat(chunks);
          need(route === "permissions" ? body.equals(PERMISSION_BODY) : body.length === 0, "READ_WIRE_BODY_DIFFERS");
          if (body.length) write.call(req, body);
        }
        return end.call(req, undefined, undefined, typeof chunk === "function" ? chunk : typeof encoding === "function" ? encoding : cb);
      });
    };
    for (const [name, originalHeader] of [["setHeader", originalSet], ["appendHeader", originalAppend]]) if (originalHeader) req[name] = function () {
      const args = arguments; return checked(() => { const value = originalHeader.apply(req, args); checkHeaders(); return value; });
    };
    req.addTrailers = () => checked(() => { need(false, "READ_TRAILERS_REFUSED"); });
    req.flushHeaders = () => checked(() => { need(false, "READ_UNVERIFIED_FLUSH_REFUSED"); });
    checked(() => {});
    return req;
  };
  const installed = { ...descriptor, value: wrapped };
  const denyHttp = function () { guard.refused(null, "UNKNOWN"); need(false, "NO_PRELAUNCH_HTTP_ALLOWED"); };
  const installedHttp = { ...httpDescriptor, value: denyHttp };
  Object.defineProperty(https, "request", installed);
  Object.defineProperty(http, "request", installedHttp);
  return { assertOwned() { need(same(Object.getOwnPropertyDescriptor(https, "request"), installed) && same(Object.getOwnPropertyDescriptor(http, "request"), installedHttp), "FOREIGN_READ_WIRE_BOUNDARY"); },
    restore() {
      let failed = false;
      for (const [object, expected, original] of [[https, installed, descriptor], [http, installedHttp, httpDescriptor]]) {
        if (same(Object.getOwnPropertyDescriptor(object, "request"), expected)) Object.defineProperty(object, "request", original);
        else failed = true;
      }
      need(!failed, "FOREIGN_READ_WIRE_BOUNDARY");
    } };
}

async function runReadOnlyPrelaunch31({ runtime, node, environment, cwd, account, names, emit = () => {} }) {
  const bootstrap = require("./business31CaptureBootstrap.cjs");
  bootstrap.assertBootstrap31();
  need(normalizedPath(process.execPath) === normalizedPath(node?.path ?? "") && hash(fs.readFileSync(process.execPath)).toUpperCase() === node?.sha256, "BOUND_NODE_REQUIRED");
  need(normalizedPath(process.cwd()) === normalizedPath(cwd) && same(normalizeEnv31(process.env), normalizeEnv31(environment)), "EXACT_SELECTED_ENVIRONMENT_REQUIRED");
  need(environment.CI === "true" && environment.NO_COLOR === "1", "FIXED_NONINTERACTIVE_ENVIRONMENT_REQUIRED");
  // Pinned @pnpm/npm-conf/lib/defaults.js:20-23 assigns HOME=os.homedir()
  // during real CLI initialization. Observe that value while the original
  // controller environment is still exact; do not preseed or inherit a home.
  const selectedHomedir = require("node:os").homedir();
  const selectedHome = process.platform === "win32" ? environment.USERPROFILE : environment.HOME;
  need(typeof selectedHome === "string" && selectedHome.length > 0 && selectedHomedir === selectedHome, "SELECTED_HOMEDIR_REQUIRED");
  need(!process.env.NODE_OPTIONS && !process.env.NODE_PATH && !process.env.DEBUG && !process.env.FIREBASE_TOKEN && !process.env.GOOGLE_APPLICATION_CREDENTIALS, "CREDENTIAL_OR_STARTUP_OVERRIDE_REFUSED");
  need(typeof account?.email === "string" && account.email.includes("@") && typeof account.firebaseConfigPath === "string", "SELECTED_ACCOUNT_REQUIRED");
  need(runtime?.cliEntrypoint?.replaceAll("\\", "/").endsWith("/firebase-tools/lib/bin/firebase.js"), "PINNED_REAL_CLI_ENTRY_REQUIRED");
  const guard = new ReadOnlyPrelaunchGuard31(names, emit), slots = [];
  guard.onLateRefusal = () => { process.exitCode = process.exitCode || 1; };
  const lease = bootstrap.installCliLoadBoundary31(runtime), lib = path.dirname(path.dirname(runtime.cliEntrypoint));
  let debugLease, api, requestOwned, cleanupDone = false, result = null;
  let requestedExit = null, exitRequests = 0, originalExit = null;
  const save = (object, key, releaseBeforeBootstrapFinish = false) => slots.push({ object, key, before: Object.getOwnPropertyDescriptor(object, key), releaseBeforeBootstrapFinish });
  const own = () => { for (const row of slots) row.owned = Object.getOwnPropertyDescriptor(row.object, row.key); };
  const cleanup = () => {
    if (cleanupDone) return; cleanupDone = true;
    const failures = [], attempt = (code, action) => { try { action(); } catch { failures.push(code); } };
    guard.sealed = true;
    for (const row of [...slots].reverse()) attempt("FOREIGN_READ_ONLY_HOOK", () => {
      need(same(Object.getOwnPropertyDescriptor(row.object, row.key), row.owned), "FOREIGN_READ_ONLY_HOOK");
      if (row.releaseBeforeBootstrapFinish) Object.defineProperty(row.object, row.key, row.before);
    });
    // Keep every physical/API/debug fence through real CLI exit callbacks.
    // Only module loading and the exit-intent adapter return to the bootstrap.
    if (debugLease) attempt("DEBUG_LEASE_OWNERSHIP_FAILED", () => debugLease.assertOwned());
    if (api && requestOwned) attempt("FOREIGN_READ_API_BOUNDARY", () => { need(same(Object.getOwnPropertyDescriptor(api.Client.prototype, "request"), requestOwned), "FOREIGN_READ_API_BOUNDARY"); });
    attempt("LOAD_LEASE_OWNERSHIP_FAILED", () => lease.assertOwned());
    attempt("LOAD_LEASE_HEALTH_FAILED", () => lease.assertHealthy());
    if (!lease.isReleased()) attempt("LOAD_LEASE_RELEASE_FAILED", () => lease.release());
    emit({ kind: "read-only-prelaunch-cleanup", cleanupComplete: failures.length === 0, failureCodes: failures,
      terminalTransportFencesHeldUntilNativeExit: true });
    if (failures.length) { const error = new AggregateError(failures.map(code => Object.assign(Error(code), { code })), "Read-only prelaunch cleanup failed"); error.code = "READ_ONLY_CLEANUP_FAILED"; throw error; }
  };
  const exit = () => { try { cleanup(); } catch { process.exitCode = 1; } };
  process.once("exit", exit);
  try {
    need(JSON.parse(fs.readFileSync(path.join(lib, "../package.json"), "utf8")).version === transport.PINNED_CLI_VERSION, "PINNED_CLI_VERSION_REQUIRED");
    const configstore = require(path.join(lib, "configstore.js")).configstore;
    need(normalizedPath(configstore.path) === normalizedPath(account.firebaseConfigPath), "SELECTED_CONFIGSTORE_PATH_REQUIRED");
    const auth = require(path.join(lib, "auth.js"));
    const selected = auth.getProjectDefaultAccount(cwd);
    need(selected?.user?.email === account.email && typeof selected.tokens?.access_token === "string" && typeof selected.tokens.refresh_token === "string", "SELECTED_ACCOUNT_OR_TOKENS_REQUIRED");
    need(refreshEligible31(selected.tokens.expires_at), "WAIT_FOR_GENUINE_REFRESH_MARGIN");
    const originalTokenHash = hash(selected.tokens.access_token), originalRefreshHash = hash(selected.tokens.refresh_token);
    const beforeMotd = transport.inspectMotdCache31(configstore.get("motd"));
    api = require(path.join(lib, "apiv2.js"));
    debugLease = transport.installCredentialRefreshDebugBoundary31(require(path.join(lib, "logger.js")).logger);
    installReadOnlyPhysicalBoundary31(guard);
    const http = require("node:http"), https = require("node:https"), net = require("node:net"), tls = require("node:tls"), Module = require("node:module");
    for (const [object, keys] of [[https, ["request", "get"]], [http, ["request", "get"]], [net.Socket.prototype, ["connect"]], [tls, ["connect"]], [Module, ["_load"]], [globalThis, ["fetch"]]]) for (const key of keys) save(object, key, object === Module && key === "_load");
    transport.installNetworkBoundary31(guard);
    // Fail closed even when an outer transport rejects before the physical
    // wrapper is reached (for example an invalid origin or a late exit hook).
    for (const [object, key] of [[https, "request"], [https, "get"], [http, "request"], [http, "get"],
      [net.Socket.prototype, "connect"], [tls, "connect"], [globalThis, "fetch"]]) {
      const bounded = object[key];
      object[key] = function () {
        if (guard.sealed) { guard.refused(null, "UNKNOWN"); need(false, "TERMINAL_READ_ONLY_TRANSPORT"); }
        try {
          const returned = bounded.apply(this, arguments);
          if (key === "fetch") return Promise.resolve(returned).catch(() => { guard.refused(null, "UNKNOWN"); need(false, "READ_ONLY_TRANSPORT_REFUSED"); });
          return returned;
        } catch { guard.refused(null, "UNKNOWN"); need(false, "READ_ONLY_TRANSPORT_REFUSED"); }
      };
    }
    own();
    transport.installApiBoundary31(api.Client, guard, () => { need(false, "NO_PRELAUNCH_WRITE_ALLOWED"); });
    const guarded = api.Client.prototype.request;
    api.Client.prototype.request = async function (request) {
      guard.inFlight++;
      try { return await guarded.call(this, { ...request, timeout: request.path === "/cli.json" ? 15000 : 30000 }); }
      catch { guard.failed = true; throw Object.assign(Error("READ_ONLY_CLI_REQUEST_FAILED"), { code: "READ_ONLY_CLI_REQUEST_FAILED" }); }
      finally { guard.inFlight--; }
    };
    requestOwned = Object.getOwnPropertyDescriptor(api.Client.prototype, "request");
    save(process, "exit", true); originalExit = Object.getOwnPropertyDescriptor(process, "exit").value;
    process.exit = function (code) {
      const actual = code === undefined ? (process.exitCode ?? 0) : code;
      if (!Number.isInteger(actual) || actual < 0 || actual > 255 || ++exitRequests !== 1) guard.failed = true;
      if (requestedExit === null) requestedExit = Number.isInteger(actual) && actual >= 0 && actual <= 255 ? actual : 1;
      if (requestedExit !== 0) guard.failed = true;
      process.exitCode = requestedExit || (guard.failed ? 1 : 0);
      emit({ kind: "read-only-cli-exit-intent", code: requestedExit, requestCount: exitRequests });
      // The pinned command exits after its async result. Delay only this owned
      // exit intent so all finite reads drain and the bootstrap can close.
    };
    own();
    process.argv = [process.execPath, runtime.cliEntrypoint, "functions:list", "--project", PROJECT, "--non-interactive", "--json"];
    require(runtime.cliEntrypoint);
    process.once("exit", () => {
      if (guard.failed || guard.inFlight !== 0 || !cleanupDone || !guard.sealed) process.exitCode = process.exitCode || 1;
    });
    await new Promise(resolve => process.once("beforeExit", resolve));
    need(exitRequests === 1 && requestedExit === 0, "REAL_CLI_ZERO_EXIT_INTENT_REQUIRED");
    need((process.exitCode ?? 0) === 0, "REAL_CLI_COMMAND_FAILED");
    guard.finish();
    const afterMotd = transport.inspectMotdCache31(configstore.get("motd"));
    need(afterMotd.cachePresent && afterMotd.fresh, "FRESH_REVIEWED_MOTD_CACHE_REQUIRED");
    const persisted = auth.getProjectDefaultAccount(cwd);
    need(persisted?.user?.email === account.email && typeof persisted.tokens?.access_token === "string" &&
      hash(persisted.tokens.access_token) !== originalTokenHash && hash(persisted.tokens.refresh_token) === originalRefreshHash &&
      !refreshEligible31(persisted.tokens.expires_at), "REFRESH_TOKEN_NOT_PERSISTED");
    const expectedAfter = { ...environment, IS_FIREBASE_CLI: "true", HOME: selectedHomedir };
    need(same(normalizeEnv31(process.env), normalizeEnv31(expectedAfter)), "CLI_CHANGED_SELECTED_ENVIRONMENT");
    result = { status: "READ_ONLY_REAL_CLI_REFRESH_AND_LIST_CONFIRMED", pinnedCliVersion: transport.PINNED_CLI_VERSION,
      beforeMotd, afterMotd, tokenPersisted: true, functionsObserved: 19, refusalCount: 0,
      events: guard.events, sourceAdmissionEstablished: false, platformIdentityAuthenticated: false,
      productionMutationAuthorized: false, deploymentAttemptConsumed: false, cleanupComplete: false,
      cleanupScope: "CLI/load lease closed; terminal API/physical/debug fences held through native exit; caller must require native zero/full EOF/owned-tree closure" };
    return result;
  } catch (error) {
    process.exitCode = process.exitCode || requestedExit || 1;
    const code = typeof error?.code === "string" && /^[A-Z_]{1,64}$/.test(error.code)
      ? error.code : typeof error?.message === "string" && error.message.startsWith("Business31 MOTD:")
        ? "MOTD_VERSION_REFUSED" : "READ_ONLY_SESSION_FAILED";
    throw Object.assign(Error("Read-only prelaunch did not complete"), { code });
  } finally {
    let clean = false;
    try { cleanup(); clean = true; if (result) result.cleanupComplete = true; }
    finally {
      process.removeListener("exit", exit);
      if (originalExit && requestedExit !== null) {
        if (!clean) process.exitCode = process.exitCode || 1;
        // Bootstrap main resolves/catches before this turn. Its nonzero cleanup
        // result must never be overwritten by an earlier CLI zero exit intent.
        setImmediate(() => originalExit.call(process, process.exitCode || requestedExit));
      }
    }
  }
}

module.exports = { PROJECT, REGION, PERMISSIONS, MOTD, TOKEN, PERMISSION_URL, V1, V2,
  refreshEligible31, normalizeEnv31, route31, ReadOnlyPrelaunchGuard31, installReadOnlyPhysicalBoundary31, runReadOnlyPrelaunch31 };
