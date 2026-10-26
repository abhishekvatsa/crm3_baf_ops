"use strict";
// Offline-only adapter below the real pinned CLI Client/auth/node-fetch stack.
// Tokens are synthetic canaries. Neither credentials nor request/response bodies enter events.
const assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path");
const crypto = require("node:crypto"), { Writable, Readable } = require("node:stream");
const INITIAL = "CANARY_INITIAL_ACCESS_31_DO_NOT_LOG", REFRESH = "CANARY_REFRESH_31_DO_NOT_LOG";
const RENEWED = "CANARY_RENEWED_ACCESS_31_DO_NOT_LOG";
const CLIENT_SECRET = "CANARY_CLIENT_SECRET_31_DO_NOT_LOG";
const CANARIES = [INITIAL, REFRESH, RENEWED, CLIENT_SECRET];
const PROJECT = "crm3-baf-ops-b8638";
const SIGNED = "https://storage.googleapis.com/offline-credential-fixture/source.zip?Signature=synthetic";
const digest = (raw, algorithm = "sha256") => crypto.createHash(algorithm).update(raw).digest("hex");
function initialTokens(scenario, now = Date.now()) {
  assert(["expired", "refresh-margin", "later-phase", "failed-refresh"].includes(scenario));
  const lifetime = scenario === "later-phase" ? 3600000 : scenario === "refresh-margin" ? 14 * 60000 : -60000;
  return { access_token: INITIAL, refresh_token: REFRESH, expires_at: now + lifetime, scopes: [] };
}
function install({ selection, lib, configstore, event, state, retainOwned, respond }) {
  const transport = require("./runtimeDeploymentTransportGuard31.cjs");
  const closure = require("./backendRuntimeClosure31.cjs");
  const https = require("node:https");
  const failureCase = selection.credentialScenario.startsWith("failed-refresh");
  const loggerModule = require(path.join(lib, "logger.js"));
  loggerModule.useFileLogger(path.join(selection.scratch, "credential-debug.log"));
  let loggerLease;
  const initialRemainingMs = configstore.get("tokens").expires_at - selection.fixtureNow;
  if (selection.credentialScenario === "expired" || failureCase) assert(initialRemainingMs < 0);
  if (selection.credentialScenario === "refresh-margin") assert(initialRemainingMs > 0 && initialRemainingMs < 15 * 60000);
  if (selection.credentialScenario === "later-phase") assert(initialRemainingMs > 15 * 60000);
  event({ kind: "SYNTHETIC_TOKEN_FRESHNESS", scenario: selection.credentialScenario, initialRemainingMs, apiScopeCount: 0 });
  assert.equal(process.env.FIREBASE_CLIENT_SECRET, undefined);
  retainOwned(process.env, "FIREBASE_CLIENT_SECRET", () => { process.env.FIREBASE_CLIENT_SECRET = CLIENT_SECRET; });
  // The SDK advisory is a separate, exact synthetic subprocess boundary. No native command runs.
  const cp = require("node:child_process"), fencedSpawnSync = cp.spawnSync;
  const bin = path.join(selection.scratch, "synthetic-npm-bin");
  fs.mkdirSync(bin);
  const npm = path.join(bin, process.platform === "win32" ? "npm.exe" : "npm");
  fs.writeFileSync(npm, "", { flag: "wx", mode: 0o700 });
  const selectedPath = bin + path.delimiter + path.dirname(process.execPath);
  retainOwned(process.env, "PATH", () => { process.env.PATH = selectedPath; });
  let advisoryCalls = 0;
  retainOwned(cp, "spawnSync", () => {
    cp.spawnSync = function (command, args, options) {
      if (command !== npm && command !== "npm") return fencedSpawnSync.apply(this, arguments);
      assert.equal(process.env.PATH, selectedPath);
      assert.equal(fs.readFileSync(npm).length, 0);
      assert.deepEqual(args, ["show", "firebase-functions", "--json=true"]);
      assert.deepEqual(Object.keys(options).sort(), ["encoding", "timeout"]);
      assert.equal(options.encoding, "utf8"); assert.equal(options.timeout, 10000);
      assert.equal(++advisoryCalls, 1);
      event({ kind: "SYNTHETIC_NPM_ADVISORY", exactCommand: "npm show firebase-functions --json=true",
        syntheticExecutableMetadataInsideScratch: true, externalCommandExecuted: false, networkForwarded: false });
      const stdout = JSON.stringify({ "dist-tags": { latest: "7.0.0" } });
      return { status: 0, signal: null, pid: 0, output: [null, stdout, ""], stdout, stderr: "" };
    };
  });
  let guard, refreshes = 0, uploads = 0, hashes = 0, archive, enterRefreshCount = null, authenticatedCallsAfterRefresh = 0, motdRequests = 0;
  let clockOffset = 0;
  retainOwned(Date, "now", () => { Date.now = () => selection.fixtureNow + clockOffset; });
  // Independently bound source inventory, before real CLI packaging/hash execution.
  const inventory = {};
  for (const name of Object.keys(selection.projectFiles).sort()) {
    if (!name.startsWith("functions/") || name.startsWith("functions/node_modules/")) continue;
    const raw = fs.readFileSync(path.join(selection.project, name));
    inventory[name.slice("functions/".length)] = { sha256: digest(raw).toUpperCase(), bytes: raw.length };
  }
  assert.deepEqual(Object.keys(inventory).sort(), selection.dynamicDiscovery ? ["index.js", "package.json"] : ["functions.yaml", "index.js", "package.json"]);
  const expectedSourceHash = digest(Object.keys(inventory).map(name =>
    digest(fs.readFileSync(path.join(selection.project, "functions", name)), "sha1")).sort().join(""), "sha1");
  const apply = require(path.join(lib, "deploy/functions/cache/applyHash.js"));
  const hash = require(path.join(lib, "deploy/functions/cache/hash.js"));
  const originalApply = apply.applyBackendHashToBackends;
  retainOwned(apply, "applyBackendHashToBackends", () => {
    apply.applyBackendHashToBackends = function (wantBackends, context) {
      assert.equal(++hashes, 1);
      assert.deepEqual(Object.keys(wantBackends), ["default"]);
      const backend = wantBackends.default;
      const endpoints = Object.values(backend.endpoints).flatMap(region => Object.values(region));
      assert.deepEqual(endpoints.map(row => row.id).sort(), [...selection.cohorts.fleet].sort());
      const source = context.sources.default;
      assert.equal(source.functionsSourceV1, undefined);
      archive = fs.readFileSync(source.functionsSourceV2);
      const verified = closure.verifyArchiveBytes31(archive, inventory);
      assert.equal(verified.sourceArchiveHash, expectedSourceHash);
      assert.equal(source.functionsSourceV2Hash, expectedSourceHash);
      const environmentHash = hash.getEnvironmentVariablesHash(backend);
      const expectedLabels = Object.fromEntries(endpoints.map(endpoint => [endpoint.id,
        hash.getEndpointHash(expectedSourceHash, environmentHash, hash.getSecretsHash(endpoint))]));
      const returned = originalApply.apply(this, arguments);
      for (const endpoint of endpoints) assert.equal(endpoint.hash, expectedLabels[endpoint.id]);
      guard.sourceArchiveHash = expectedSourceHash;
      guard.endpointRuntimeHashes = expectedLabels;
      guard.preparedMatches({ sourceArchiveHash: expectedSourceHash, endpointRuntimeHashes: expectedLabels,
        archiveSha256: verified.archiveSha256, archiveBytes: archive.length });
      event({ kind: "ORIGINAL_HASH_AND_ZIP_VERIFIED", phase: selection.phase, actualHashFunctionCalled: true,
        sourceArchiveHash: expectedSourceHash, archiveSha256: verified.archiveSha256, archiveBytes: archive.length,
        endpointCount: endpoints.length, independentlyVerifiedSourceMembers: verified.fileCount });
      return returned;
    };
  });
  retainOwned(https, "request", () => {
    https.request = function (input, options, callback) {
      if (typeof options === "function") callback = options;
      const effective = transport.effectiveRequest31(input, options, "https:");
      const chunks = [];
      const req = new Writable({
        write(chunk, encoding, done) { chunks.push(Buffer.from(chunk)); done(); },
        final(done) {
          (async () => {
            const raw = Buffer.concat(chunks), url = effective.url, method = effective.method;
            const motd = url.href === "https://firebase-public.firebaseio.com/cli.json";
            if (motd) {
              assert.equal(method, "GET"); assert.equal(raw.length, 0);
              assert.equal(headerMap.has("authorization"), false); assert.equal(headerMap.has("cookie"), false);
            } else if (url.href !== "https://www.googleapis.com/oauth2/v3/token" && url.href !== SIGNED) {
              const authorization = String(headerMap.get("authorization"));
              assert(authorization === "Bearer " + (refreshes ? RENEWED : INITIAL), "physical API request did not use the selected synthetic access token");
              if (refreshes) authenticatedCallsAfterRefresh++;
            }
            let body;
            if (url.href === "https://www.googleapis.com/oauth2/v3/token") {
              assert.equal(method, "POST"); assert.equal(++refreshes, 1);
              // firebase-tools uses its original multipart FormData serialization.
              const form = raw.toString("utf8");
              assert(form.includes('name="refresh_token"\r\n\r\n' + REFRESH));
              assert(form.includes('name="grant_type"\r\n\r\nrefresh_token'));
              assert(form.includes('name="client_id"'));
              assert(form.includes('name="client_secret"\r\n\r\n' + CLIENT_SECRET));
              body = { access_token: RENEWED, token_type: "Bearer", expires_in: 3600 };
              event({ kind: "OFFLINE_CREDENTIAL_TRANSPORT", method, host: url.hostname, path: url.pathname, status: failureCase ? null : 200 });
              if (failureCase) throw Error("SYNTHETIC_CREDENTIAL_TRANSPORT_FAILURE");
            } else if (motd) {
              assert.equal(++motdRequests, 1);
              event({ kind: "OFFLINE_MOTD_TRANSPORT", method, host: url.hostname, path: url.pathname,
                status: selection.initializationScenario === "motd-failure" ? null : 200, authenticated: false, bodyless: true });
              if (selection.initializationScenario === "motd-failure") throw Error("SYNTHETIC_MOTD_TRANSPORT_FAILURE");
              if (selection.initializationScenario === "delayed-high-min-version") await new Promise(resolve => setTimeout(resolve, 2500));
              body = { minVersion: selection.initializationScenario === "delayed-high-min-version" ? "15.22.5" : "15.22.4" };
            } else if (url.href === "https://cloudfunctions.googleapis.com/v2/projects/" + PROJECT + "/locations/asia-south1/functions:generateUploadUrl") {
              assert.equal(method, "POST"); assert.equal(raw.length, 0); assert.equal(hashes, 1);
              body = { uploadUrl: SIGNED, storageSource: { bucket: "offline-credential-fixture", object: "source.zip", generation: "1" } };
            } else if (url.href === SIGNED) {
              assert.equal(method, "PUT"); assert.equal(++uploads, 1); assert.equal(hashes, 1);
              assert(raw.equals(archive), "physical signed upload body differs from the verified original CLI ZIP");
              event({ kind: "ACTUAL_SIGNED_UPLOAD_BODY_VERIFIED", phase: selection.phase,
                archiveSha256: digest(raw).toUpperCase(), archiveBytes: raw.length, networkForwarded: false });
              body = {};
            } else {
              const request = { method, path: url.pathname, queryParams: url.searchParams,
                headers: url.hostname === "cloudresourcemanager.googleapis.com" && url.pathname.endsWith(":testIamPermissions")
                  ? { "x-goog-user-project": PROJECT }
                  : url.hostname === "serviceusage.googleapis.com" && url.pathname.endsWith(":generateServiceIdentity")
                    ? { "x-goog-user-project": "123456789" } : {} };
              if (raw.length) request.body = JSON.parse(raw.toString("utf8"));
              const response = await respond.call({ opts: { urlPrefix: url.origin } }, request);
              body = response.body;
            }
            const response = Readable.from([Buffer.from(JSON.stringify(body))]);
            Object.assign(response, { statusCode: 200, statusMessage: "OK", headers: { "content-type": "application/json" },
              rawHeaders: ["content-type", "application/json"], httpVersion: "1.1" });
            req.emit("response", response); done();
          })().catch(done);
        }
      });
      req.abort = () => req.destroy(); req.setTimeout = () => req;
      const headers = { ...(typeof input === "object" && !(input instanceof URL) ? input.headers : {}),
        ...(options && typeof options === "object" ? options.headers : {}) };
      const headerMap = new Map(Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]));
      req.setHeader = (key, value) => { headerMap.set(key.toLowerCase(), value); return req; };
      req.appendHeader = (key, value) => { const lower = key.toLowerCase(); headerMap.set(lower,
        headerMap.has(lower) ? [].concat(headerMap.get(lower), value) : value); return req; };
      req.getHeader = key => headerMap.get(key.toLowerCase());
      req.getHeaders = () => Object.fromEntries(headerMap);
      req.flushHeaders = () => {};
      if (callback) req.on("response", callback);
      return req;
    };
  });
  return {
    failureCase,
    beforeCliEntry() {
      if (selection.initializationScenario === "cross-entry-warm") {
        assert(configstore.get("motd.fetched") > Date.now() - 24 * 3600000);
        clockOffset = 61000;
        assert(configstore.get("motd.fetched") <= Date.now() - 24 * 3600000);
        event({ kind: "MOTD_EXPIRED_BETWEEN_LAUNCH_AND_REAL_CLI_ENTRY", phase: selection.phase });
      }
    },
    bindGuard(value) {
      assert.equal(guard, undefined); guard = value;
      loggerLease = transport.installCredentialRefreshDebugBoundary31(loggerModule.logger);
    },
    restore() { if (loggerLease) loggerLease.restore(); },
    async runFailure() {
      assert.equal(failureCase, true);
      event({ kind: "REAL_AUTH_MODULE_REFRESH_START", realCliEntry: false });
      let refused;
      try { await require(path.join(lib, "auth.js")).getAccessToken(REFRESH, []); }
      catch (caught) { refused = caught; }
      assert(refused && refused.message.startsWith("Authentication Error: Your credentials are no longer valid."),
        "only the real pinned auth failure is expected");
      state.sentinel = "BUSINESS31_OFFLINE_EXPECTED_REFRESH_FAILURE";
      event({ kind: "EXPECTED_REFRESH_FAILURE", genericAuthenticationFailure: true, originalPrepareInvoked: false });
      require(path.join(lib, "errorOut.js")).errorOut(refused);
    },
    enterPrepare(options) {
      enterRefreshCount = refreshes;
      assert([INITIAL, RENEWED].includes(options.tokens.access_token));
      if (selection.credentialScenario === "later-phase") {
        assert(["events", "fleet"].includes(selection.phase)); assert.equal(refreshes, 0);
        clockOffset = 46 * 60000;
        event({ kind: "LATER_PHASE_TOKEN_ENTERED_REFRESH_MARGIN", phase: selection.phase, refreshesBeforePrepare: 0 });
      } else assert.equal(refreshes, 1);
    },
    beforeUpload(operation) {
      assert(["generate-upload", "source-upload"].includes(operation.kind), "fixture stops before all Function/control mutations");
      assert.equal(hashes, 1); assert.equal(guard.prepared, true);
      assert.equal(guard.archiveSha256, digest(archive).toUpperCase());
      assert.equal(guard.archiveBytes, archive.length);
      event({ kind: "OFFLINE_VERIFIED_UPLOAD_ADMISSION", operation: operation.kind, phase: selection.phase,
        productionAuthority: false, controlsOrWindowVerified: false });
    },
    isExpectedStop() { return false; },
    assertComplete() {
      if (loggerLease) loggerLease.assertOwned();
      if (selection.initializationScenario === "min-version-too-high") {
        assert.equal(refreshes, 0); assert.equal(hashes, 0); assert.equal(uploads, 0); assert.equal(motdRequests, 0);
        assert.equal(advisoryCalls, 0); assert.equal(state.prepareEntries, 0); assert.equal(state.releaseEntries, 0);
        assert.equal(state.sentinel, "BUSINESS31_OFFLINE_EXPECTED_MOTD_MIN_VERSION_STOP");
        assert.equal(guard.events.length, 0); assert.equal(state.preIdentityRefusals, 0);
        event({ kind: "CACHED_MOTD_MIN_VERSION_NEGATIVE_VERIFIED", phase: selection.phase,
          realCliEntry: true, identityRequestsSent: 0, uploadRequestsSent: 0 });
        return;
      }
      if (failureCase) {
        assert.equal(refreshes, 1); assert.equal(hashes, 0); assert.equal(uploads, 0); assert.equal(advisoryCalls, 0);
        assert.equal(state.sentinel, "BUSINESS31_OFFLINE_EXPECTED_REFRESH_FAILURE");
        assert.equal(state.prepareEntries, 0); assert.equal(state.releaseEntries, 0);
        assert(JSON.parse(fs.readFileSync(configstore.path, "utf8")).tokens.access_token === INITIAL,
          "failed physical refresh must not persist a replacement token");
        event({ kind: "REAL_FAILED_REFRESH_VERIFIED", filtered: true, actualPhysicalAttempts: 1,
          realAuthFunctionsReplaced: false, realClientRequestStubbed: false, realCliEntry: false, productionAuthority: false });
        return;
      }
      if (["motd-failure", "delayed-high-min-version"].includes(selection.initializationScenario)) {
        assert.equal(motdRequests, 1); assert.equal(hashes, 0); assert.equal(uploads, 0);
        assert.equal(state.originalPrepareCompleted, 0); assert.equal(state.releaseEntries, 0);
        assert(state.preIdentityRefusals >= 1);
        assert.equal(guard.events.filter(row => row.kind === "existing-service-identity").length, 0);
        assert.equal(guard.events.filter(row => row.kind === "source-upload").length, 0);
        event({ kind: "CAUGHT_MOTD_FAILURE_STOPS_BEFORE_IDENTITY_SEND", phase: selection.phase,
          identityRequestsSent: 0, uploadRequestsSent: 0, stickyFailurePreserved: true });
        return;
      }
      assert.equal(refreshes, 1); assert.equal(hashes, 1); assert.equal(uploads, 1);
      assert.equal(state.preIdentityRefusals, 0);
      const expectedMotdRequests = selection.initializationScenario === "fresh-warm" ? 0 : 1;
      assert.equal(motdRequests, expectedMotdRequests);
      assert.equal(guard.events.filter(row => row.kind === "cli-motd").length, expectedMotdRequests);
      assert.equal(guard.events.filter(row => row.kind === "discovery-shutdown-admitted").length, 1);
      assert.equal(guard.events.filter(row => row.kind === "discovery-stopped").length, 1);
      assert.equal(advisoryCalls, 1);
      assert(authenticatedCallsAfterRefresh > 0);
      assert.notEqual(enterRefreshCount, null);
      assert.equal(state.originalPrepareCompleted, 1); assert.equal(state.releaseEntries, 1);
      const saved = JSON.parse(fs.readFileSync(configstore.path, "utf8"));
      assert.equal(path.resolve(configstore.path).startsWith(path.resolve(selection.scratch) + path.sep), true);
      assert(saved.tokens.access_token === RENEWED, "real refresh did not persist the synthetic renewed token");
      assert(saved.tokens.refresh_token === REFRESH, "real refresh changed the synthetic refresh token");
      assert(saved.tokens.expires_at > Date.now() + 15 * 60000);
      const credentialEvents = guard.events.filter(row => row.kind === "credential-refresh");
      assert.deepEqual(credentialEvents, [{ kind: "credential-refresh", method: "POST", host: "www.googleapis.com", path: "/oauth2/v3/token", status: 200 }]);
      assert.equal(guard.events.filter(row => row.kind === "source-upload").length, 1);
      event({ kind: "REAL_REFRESH_PERSISTENCE_VERIFIED", phase: selection.phase, configstoreInsideScratch: true,
        refreshCount: refreshes, actualHashCalls: hashes, actualUploadBodies: uploads,
        authenticatedCallsAfterRefresh,
        credentialEvents, realAuthFunctionsReplaced: false, realClientRequestStubbed: false,
        fullControllerTraversalClaimed: false, productionAuthority: false });
    }
  };
}
module.exports = { initialTokens, install, CANARIES };
