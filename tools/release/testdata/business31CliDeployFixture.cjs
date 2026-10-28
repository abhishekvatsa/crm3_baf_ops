"use strict";
// Runs only in an unchanged, freshly copied bootstrap. No production admission is fabricated.
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { isDeepStrictEqual } = require("node:util");
const kernel = require("./business31CliSyntheticKernel.cjs");
const discoveryPhysical = require("./business31CliDiscoveryWire.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const PROJECT = "crm3-baf-ops-b8638", NUMBER = "123456789";
const PERMISSIONS = ["firebase.projects.get", "cloudfunctions.functions.list", "cloudfunctions.functions.create",
  "cloudfunctions.functions.get", "cloudfunctions.functions.update", "cloudfunctions.functions.delete", "cloudfunctions.operations.get"].sort();
// Synthetic observed-shaped baseline only; never production IAM authority.
const identityBaseline = {
  project: { method: "GET", url: "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT, httpStatus: 200,
    bodyText: JSON.stringify({ projectId: PROJECT, projectNumber: NUMBER }) },
  projectIam: { method: "POST", url: "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT + ":getIamPolicy", httpStatus: 200,
    bodyText: JSON.stringify({ bindings: ["pubsub", "eventarc"].map(name => ({ role: "roles/" + name + ".serviceAgent",
      members: ["serviceAccount:service-" + NUMBER + "@gcp-sa-" + name + ".iam.gserviceaccount.com"] })) }) }
};
const STOP_PREPARE = "BUSINESS31_OFFLINE_PREPARE_ENTRY_STOP";
const STOP_RELEASE = "BUSINESS31_OFFLINE_RELEASE_ENTRY_STOP";
async function runCase(caseId, componentData) {
  assert.equal(caseId, "installed-positive");
  assert.deepEqual(Object.keys(componentData), ["runtime"]);
  const selection = JSON.parse(fs.readFileSync(path.join(__dirname, "CASE.json"), "utf8"));
  assert(["prepare-entry", "pre-release", "credential-refresh"].includes(selection.mode));
  const realAuth = selection.mode === "credential-refresh", fullPrepare = selection.mode !== "prepare-entry";
  assert(["callables", "events", "fleet"].includes(selection.phase));
  assert.equal(selection.fleet.synthetic, true);
  assert.equal(selection.fleet.currentProductionStateClaimed, false);
  assert(require("./business31CliFleetFixture.cjs").VARIANTS.includes(selection.fleet.variant));
  const runtime = componentData.runtime, scratch = selection.scratch;
  const rawWrite = fs.writeSync, fd = fs.openSync(path.join(scratch, "events.jsonl"), "wx");
  let sequence = 0;
  const event = value => {
    const bytes = Buffer.from(JSON.stringify({ sequence: ++sequence, ...value }) + "\n");
    if (sequence > 1024 || bytes.length > 65536 || rawWrite(fd, bytes) !== bytes.length) throw Error("OFFLINE_EVENT_BOUND_OR_WRITE");
  };
  const state = { prepareEntries: 0, originalPrepareEntries: 0, originalPrepareCompleted: 0, releaseEntries: 0,
    fixtureCalls: [], unmatched: [], guardRejections: [], errors: [], preIdentityRefusals: 0,
    identityCaptureCompleted: false, firstIdentityAdmissionFailure: null,
    sentinel: null, guardHealthy: false, cleanupComplete: false };
  const errorView = error => ({ name: error.name, code: error.code ?? null, message: error.message, stack: error.stack });
  const error = (kind, value) => { const row = { kind, ...errorView(value) }; state.errors.push(row); event(row); };
  process.on("uncaughtExceptionMonitor", value => error("UNCAUGHT_ERROR", value));
  const cliRoot = path.dirname(path.dirname(path.dirname(path.dirname(runtime.cliEntrypoint))));
  const safety = require("./business31CliOfflineFence.cjs").installOfflineFence({
    scratch, source: __dirname, cliRoot, readFiles: [runtime.cliFileBindings.path, process.execPath], event
  });
  let lease, api, prepare, release, prepareDescriptor, releaseDescriptor, prepareWrapper, releaseWrapper, credentialWire, discoveryWire;
  let nativeAdmission, identityCapture, identityBoundary, packaging;
  let requestDescriptor, requestWrapper, networkSlots = [], finishRegistered = false;
  const registerFinish = () => { if (!finishRegistered) { finishRegistered = true; process.once("exit", finish); } };
  const ownedSlots = [];
  function retainOwned(object, key, action) {
    const before = Object.getOwnPropertyDescriptor(object, key);
    action();
    ownedSlots.push({ object, key, before, owned: Object.getOwnPropertyDescriptor(object, key) });
  }
  function installBoundary(action) {
    const http = require("node:http"), https = require("node:https"), net = require("node:net");
    const tls = require("node:tls"), Module = require("node:module");
    const slots = [[https, "request"], [https, "get"], [http, "request"], [http, "get"],
      [net.Socket.prototype, "connect"], [tls, "connect"], [Module, "_load"], [globalThis, "fetch"],
      [api.Client.prototype, "request"]];
    const frames = slots.map(([object, key]) => ({ object, key, before: Object.getOwnPropertyDescriptor(object, key) }));
    let value;
    try { value = action(); }
    catch (error) {
      for (const { object, key, before } of frames) {
        if (before) Object.defineProperty(object, key, before); else delete object[key];
      }
      throw error;
    }
    frames.forEach(frame => { frame.owned = Object.getOwnPropertyDescriptor(frame.object, frame.key); });
    ownedSlots.push(...frames);
    let restored = false;
    return { value, restore() {
      assert.equal(restored, false, "identity boundary cannot restore twice");
      assert.deepEqual(ownedSlots.slice(-frames.length), frames, "identity boundary ownership order changed");
      for (const { object, key, owned } of frames)
        assert(isDeepStrictEqual(Object.getOwnPropertyDescriptor(object, key), owned), "foreign identity boundary hook retained: " + key);
      for (const { object, key, before } of frames) {
        if (before) Object.defineProperty(object, key, before); else delete object[key];
      }
      ownedSlots.splice(-frames.length); restored = true;
    } };
  }
  function wrapPreIdentityRefusals() {
    const guarded = api.Client.prototype.request;
    api.Client.prototype.request = async function (request) {
      try { return await guarded.call(this, request); }
      catch (caught) {
        state.preIdentityRefusals++;
        const safe = require("./runtimeDeploymentTransportGuard31.cjs").safeRequestMetadata31(this, request);
        event({ kind: "PRE_IDENTITY_REQUEST_REFUSED", ...safe });
        throw caught;
      }
    };
  }
  // Substitute one declared synthetic metadata request; every other read still reaches the fence.
  // Observe and rethrow the identical error for delegated denials; no host read root is added.
  const fencedReadFileSync = fs.readFileSync;
  const metadataReader = kernel.createSyntheticKernelReader({ readFileSync: fencedReadFileSync,
    fixture: selection.kernelMetadata, scratch, event });
  retainOwned(fs, "readFileSync", () => {
    fs.readFileSync = function (file, ...args) {
      try { return metadataReader.apply(this, arguments); }
      catch (caught) {
        if (caught.code === "OFFLINE_BOUNDARY_DENIED") {
          event({ kind: "DENIED_FILESYSTEM_READ", api: "fs.readFileSync",
            suppliedPath: typeof file === "string" ? file : Buffer.isBuffer(file) ? file.toString() : file instanceof URL ? file.href : null,
            resolvedPath: typeof file === "string" ? path.resolve(file) : null,
            pathValueType: typeof file, message: caught.message, stack: caught.stack });
        }
        throw caught;
      }
    };
  });
  let cleanupDone = false;
  function verifyProjectFixtures() {
    kernel.verifySyntheticKernelFixture({ readFileSync: fencedReadFileSync, fixture: selection.kernelMetadata, scratch });
    assert(selection.projectFiles && Object.keys(selection.projectFiles).length > 0);
    for (const [name, digest] of Object.entries(selection.projectFiles)) {
      assert(name && !path.isAbsolute(name) && !name.split(/[\\/]/).includes(".."));
      assert.equal(sha(fs.readFileSync(path.join(selection.project, name))), digest, "synthetic project fixture changed: " + name);
    }
  }
  function cleanup() {
    if (cleanupDone) return;
    cleanupDone = true;
    if (credentialWire) {
      try { credentialWire.assertComplete(); }
      catch (caught) { error("CREDENTIAL_ASSERTION_ERROR", caught); process.exitCode = 1; }
    }
    try {
      if (credentialWire) credentialWire.restore();
      if (discoveryWire) { discoveryWire.assertComplete(state.prepareEntries > 0); discoveryWire.restore(); }
      if (packaging) packaging.restore();
      for (const { object, key, before, owned } of [...ownedSlots].reverse()) {
        assert(isDeepStrictEqual(Object.getOwnPropertyDescriptor(object, key), owned), "foreign fixture hook retained: " + key);
        if (before) Object.defineProperty(object, key, before);
        else delete object[key];
      }
      if (prepare) {
        assert.equal(prepare.prepare, prepareWrapper, "foreign prepare hook retained");
        Object.defineProperty(prepare, "prepare", prepareDescriptor);
      }
      if (release) {
        assert.equal(release.release, releaseWrapper, "foreign release hook retained");
        Object.defineProperty(release, "release", releaseDescriptor);
      }
      if (api) {
        assert.equal(api.Client.prototype.request, requestWrapper, "foreign request fixture retained");
        Object.defineProperty(api.Client.prototype, "request", requestDescriptor);
      }
      verifyProjectFixtures();
      if (lease) { lease.assertHealthy(); state.guardHealthy = true; lease.release(); }
      state.cleanupComplete = true;
    } catch (caught) { error("CLEANUP_ERROR", caught); process.exitCode = 1; }
  }
  function finish(code) {
    if (selection.initializationScenario === "min-version-too-high" && code === 1 && state.prepareEntries === 0) {
      state.sentinel = "BUSINESS31_OFFLINE_EXPECTED_MOTD_MIN_VERSION_STOP";
      event({ kind: "EXPECTED_MOTD_MIN_VERSION_STOP", pinnedVersion: "15.22.4", cachedMinVersion: "15.22.5",
        identityRequestsSent: 0, uploadRequestsSent: 0 });
    }
    cleanup();
    if (safety.denials.length || state.errors.length || state.unmatched.length || state.guardRejections.length) process.exitCode = 1;
    event({ kind: "PROCESS_EXIT", code, effectiveExitCode: process.exitCode ?? code, ...state,
      denials: safety.denials, controllerInvoked: false, controllerTraversalSucceeded: false,
      deploymentAuthorized: false, networkForwarded: false, externalNetworkForwarded: false,
      physicalLoopbackDiscoveryUsed: discoveryWire?.executed() ?? false });
    // Keep this descriptor open until OS closure: a later exit listener must still log a denial.
  }
  try {
    lease = require("./business31CaptureBootstrap.cjs").installCliLoadBoundary31(runtime);
    const lib = path.dirname(path.dirname(runtime.cliEntrypoint));
    assert.equal(JSON.parse(fs.readFileSync(path.join(lib, "../package.json"), "utf8")).version, "15.22.4");
    event({ kind: "INSTALLED_POPULATION_ADMITTED", cliEntrypoint: runtime.cliEntrypoint,
      cliMapSha256: runtime.cliFileBindings.sha256, bootstrapSha256: sha(fs.readFileSync(path.join(__dirname, "business31CaptureBootstrap.cjs"))) });
    verifyProjectFixtures();
    // Real auth selection and requireAuth read this newly created synthetic profile.
    // No auth function, parser, deploy command, before-hook or dispatcher is replaced.
    const { configstore } = require(path.join(lib, "configstore.js"));
    assert.equal(path.resolve(configstore.path).startsWith(path.resolve(scratch) + path.sep), true);
    configstore.set("user", { email: "offline-fixture@example.invalid" });
    configstore.set("tokens", realAuth
      ? require("./business31CliCredentialWire.cjs").initialTokens(selection.credentialScenario, selection.fixtureNow)
      : { access_token: "NON_SECRET_OFFLINE_FIXTURE", expires_at: Date.now() + 3600000 });
    configstore.set("usage", false);
    const day = 24 * 60 * 60 * 1000, initialization = selection.initializationScenario;
    if (initialization !== "absent-cold") configstore.set("motd", {
      minVersion: initialization === "min-version-too-high" ? "15.22.5" : "15.22.4",
      fetched: initialization === "exact-day-cold" ? selection.fixtureNow - day
        : initialization === "cross-entry-warm" ? selection.fixtureNow - day + 60000
          : ["stale-warm", "motd-failure", "delayed-high-min-version"].includes(initialization) ? selection.fixtureNow - day - 60000
            : selection.fixtureNow
    });
    if (!initialization.endsWith("cold")) configstore.set("apiEnablementCache", {
      [PROJECT]: { "cloudfunctions.googleapis.com": true, "cloudbuild.googleapis.com": true,
        "artifactregistry.googleapis.com": true },
      [NUMBER]: { "run.googleapis.com": true, "eventarc.googleapis.com": true }
    });
    event({ kind: "SYNTHETIC_CLI_INITIALIZATION_STATE", scenario: initialization,
      motdPresent: initialization !== "absent-cold", motdMinVersion: configstore.get("motd.minVersion") ?? null,
      apiEnablementCache: initialization.endsWith("cold") ? "absent" : "mixed-existing-and-absent",
      fixtureClockControlled: realAuth });
    api = require(path.join(lib, "apiv2.js"));
    requestDescriptor = Object.getOwnPropertyDescriptor(api.Client.prototype, "request");
    assert(requestDescriptor && typeof requestDescriptor.value === "function");
    requestWrapper = async function (request) {
      const url = new URL(this.opts.urlPrefix + (this.opts.apiVersion ? "/" + this.opts.apiVersion : "") + "/" + request.path.replace(/^\//, ""));
      const method = (request.method ?? "GET").toUpperCase();
      const query = request.queryParams instanceof URLSearchParams ? Object.fromEntries(request.queryParams) : request.queryParams ?? {};
      const key = method + " " + url.href;
      const row = { key, body: request.body ?? null, query };
      let body;
      if (key === "GET https://firebase-public.firebaseio.com/cli.json" && this.opts.auth === false
          && request.body === undefined && Object.keys(query).length === 0) {
        body = { minVersion: "15.22.4" };
      } else if (key === "POST https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT + ":testIamPermissions"
          && isDeepStrictEqual(request.body, { permissions: PERMISSIONS }) && Object.keys(query).length === 0
          && isDeepStrictEqual(request.headers, { "x-goog-user-project": PROJECT })) {
        body = { permissions: PERMISSIONS };
      } else if (key === "POST https://iam.googleapis.com/v1/projects/" + PROJECT + "/serviceAccounts/" + PROJECT + "@appspot.gserviceaccount.com:testIamPermissions"
          && isDeepStrictEqual(request.body, { permissions: ["iam.serviceAccounts.actAs"] }) && Object.keys(query).length === 0
          && isDeepStrictEqual(request.headers, {})) {
        body = { permissions: ["iam.serviceAccounts.actAs"] };
      } else if (fullPrepare && method === "POST"
          && ["pubsub.googleapis.com", "eventarc.googleapis.com"].some(service => url.href === "https://serviceusage.googleapis.com/v1beta1/projects/" + NUMBER + "/services/" + service + ":generateServiceIdentity")
          && isDeepStrictEqual(request.body, {}) && Object.keys(query).length === 0
          && isDeepStrictEqual(request.headers, { "x-goog-user-project": NUMBER })) {
        const service = url.pathname.split("/").at(-1).split(":")[0];
        const bound = require("./runtimeDeploymentTransportGuard31.cjs").existingServiceIdentityBindings31(identityBaseline);
        body = { done: true, response: { "@type": "type.googleapis.com/google.api.serviceusage.v1beta1.ServiceIdentity", email: bound.emails[service] } };
      } else if (fullPrepare && method === "GET" && request.body === undefined) {
        // Finite synthetic control reads. The real guard runs outside this fixture first.
        const enabledServices = [
          ...["cloudresourcemanager.googleapis.com", "cloudfunctions.googleapis.com", "runtimeconfig.googleapis.com",
            "cloudbuild.googleapis.com", "artifactregistry.googleapis.com"].map(name => PROJECT + "/services/" + name),
          ...["run.googleapis.com", "eventarc.googleapis.com", "pubsub.googleapis.com", "storage.googleapis.com"].map(name => NUMBER + "/services/" + name)
        ];
        if (url.origin === "https://serviceusage.googleapis.com" && enabledServices.some(name => url.pathname === "/v1/projects/" + name)
            && Object.keys(query).length === 0) {
          body = { state: "ENABLED" };
        } else if (url.href === "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT && Object.keys(query).length === 0) {
          body = { projectId: PROJECT, projectNumber: NUMBER, lifecycleState: "ACTIVE" };
        } else if (url.href === "https://firebase.googleapis.com/v1beta1/projects/" + PROJECT + "/adminSdkConfig" && Object.keys(query).length === 0) {
          body = { projectId: PROJECT, storageBucket: PROJECT + ".appspot.com", locationId: "asia-south1" };
        } else if (url.href === "https://firestore.googleapis.com/v1/projects/" + PROJECT + "/databases/(default)"
            && Object.keys(query).length === 0) {
          body = { locationId: "asia-south1" };
        } else if (url.href === "https://cloudfunctions.googleapis.com/v1/projects/" + PROJECT + "/locations/-/functions"
            && Object.keys(query).length === 0) {
          body = { functions: [], unreachable: [] };
        } else if (url.href === "https://cloudfunctions.googleapis.com/v2/projects/" + PROJECT + "/locations/-/functions"
            && isDeepStrictEqual(query, { filter: 'environment="GEN_2"' })) {
          body = { functions: structuredClone(selection.fleet.existingFunctions), unreachable: [] };
        }
      }
      if (body === undefined) {
        state.unmatched.push(row); event({ kind: "UNMATCHED_FIXTURE_REQUEST", ...row });
        throw Error("OFFLINE_UNMATCHED_FIXTURE_REQUEST: " + key);
      }
      state.fixtureCalls.push(row); event({ kind: "FIXTURE_RESPONSE", ...row });
      return { status: 200, body, headers: {} };
    };
    if (realAuth) {
      if (selection.dynamicDiscovery) discoveryWire = discoveryPhysical.install({ selection, lib, event, retainOwned });
      credentialWire = require("./business31CliCredentialWire.cjs").install({
        selection, lib, configstore, event, state, retainOwned, respond: requestWrapper
      });
      // Only the physical HTTPS transport is faked; Client.request/auth/prepare stay original.
      requestWrapper = requestDescriptor.value;
    } else Object.defineProperty(api.Client.prototype, "request", { ...requestDescriptor, value: requestWrapper });
    prepare = require(path.join(lib, "deploy/functions/prepare.js"));
    if (realAuth) {
      packaging = require("./business31CohortProcess.cjs").isolateNativePackagingConfig31(
        require(path.join(lib, "deploy/functions/prepareFunctionsUpload.js")));
      event({ kind: "REAL_NATIVE_PACKAGING_CONFIG_ISOLATION_INSTALLED", phase: selection.phase });
    }
    prepareDescriptor = Object.getOwnPropertyDescriptor(prepare, "prepare");
    assert(prepareDescriptor && typeof prepareDescriptor.value === "function");
    const { FirebaseError } = require(path.join(lib, "error.js"));
    prepareWrapper = async function (context, options, payload) {
      state.prepareEntries++;
      assert.equal(state.prepareEntries, 1, "prepare retry refused");
      assert.equal(options.project, PROJECT); assert.equal(options.projectId, PROJECT);
      assert.equal(options.nonInteractive, true);
      assert.equal(options.only, selection.names.map(name => "functions:" + name).join(","));
      assert.deepEqual(options.filteredTargets, ["functions"]);
      assert.equal(options.config.projectDir, selection.project);
      assert.deepEqual(options.config.src.functions, selection.functionsConfiguration);
      assert(Array.isArray(options.config.src.functions) && options.config.src.functions.length === 1);
      assert.equal(options.config.src.functions[0].disallowLegacyRuntimeConfig, true);
      assert.equal(Object.hasOwn(options.config.src.functions[0], "runtime"), false);
      assert.equal(options.config.src.hosting, undefined);
      assert.equal(options.user.email, "offline-fixture@example.invalid");
      if (credentialWire) credentialWire.enterPrepare(options);
      else assert.equal(options.tokens.access_token, "NON_SECRET_OFFLINE_FIXTURE");
      assert.deepEqual(process.argv, [process.execPath, runtime.cliEntrypoint, ...selection.cliArguments]);
      assert.deepEqual(state.fixtureCalls.filter(call => selection.permissionRoutes.includes(call.key)).map(call => call.key), selection.permissionRoutes);
      if (nativeAdmission) { packaging.assertOwned(); nativeAdmission.bind(options); }
      event({ kind: "PREPARE_ENTRY", phase: selection.phase, names: selection.names, originalBodyInvoked: fullPrepare,
        config: options.config.src, project: options.project, nonInteractive: options.nonInteractive, only: options.only });
      if (selection.mode === "prepare-entry") {
        state.sentinel = STOP_PREPARE; event({ kind: "EXPECTED_STOP", marker: STOP_PREPARE });
        throw new FirebaseError(STOP_PREPARE, { exit: 1 });
      }
      state.originalPrepareEntries++;
      try {
        const result = await prepareDescriptor.value.apply(this, arguments);
        if (nativeAdmission) { packaging.assertOwned(); nativeAdmission.check("AFTER_ORIGINAL_PREPARE"); }
        state.originalPrepareCompleted++;
        const endpoints = backend => Object.values(backend.endpoints).flatMap(region => Object.values(region))
          .map(endpoint => ({ id: endpoint.id, serviceAccount: endpoint.serviceAccount ?? null,
            eventType: endpoint.eventTrigger?.eventType ?? null, secretEnvironmentVariables: endpoint.secretEnvironmentVariables ?? [] }))
          .sort((a, b) => a.id.localeCompare(b.id));
        event({ kind: "ORIGINAL_PREPARE_COMPLETED", fleetVariant: selection.fleet.variant,
          backends: Object.entries(payload.functions).map(([codebase, value]) => ({
            codebase, want: endpoints(value.wantBackend), have: endpoints(value.haveBackend) })) });
        return result;
      } catch (caught) {
        if (!credentialWire?.isExpectedStop(caught)) error("ORIGINAL_PREPARE_ERROR", caught);
        throw caught;
      }
    };
    Object.defineProperty(prepare, "prepare", { ...prepareDescriptor, value: prepareWrapper });
    if (fullPrepare) {
      release = require(path.join(lib, "deploy/functions/release/index.js"));
      releaseDescriptor = Object.getOwnPropertyDescriptor(release, "release");
      assert(releaseDescriptor && typeof releaseDescriptor.value === "function");
      releaseWrapper = async function () {
        state.releaseEntries++;
        state.sentinel = STOP_RELEASE;
        event({ kind: "EXPECTED_STOP", marker: STOP_RELEASE, originalReleaseInvoked: false });
        throw new FirebaseError(STOP_RELEASE, { exit: 1 });
      };
      Object.defineProperty(release, "release", { ...releaseDescriptor, value: releaseWrapper });
      const neutral = require("./runtimeDeploymentTransportGuard31.cjs");
      const guard = new neutral.RuntimeDeploymentTransportGuard31({
        names: selection.names, allNames: selection.cohorts.fleet, phase: selection.phase,
        baselineFunctions: Object.fromEntries(selection.fleet.existingFunctions.map(fn => [fn.name.split("/").at(-1), fn])),
        projectNumber: NUMBER, serviceIdentityBaseline: identityBaseline
      });
      if (credentialWire) credentialWire.bindGuard(guard);
      if (discoveryWire) discoveryWire.bindGuard(guard);
      if (realAuth) nativeAdmission = require("./business31CliAdmissionFixture.cjs").create({
        selection, Config: require(path.join(lib, "config.js")).Config, identityBaseline,
        event, state, verifyProjectFixtures
      });
      // Diagnostic wrapper retains the original predicate and never converts a refusal to a response.
      const originalBefore = guard.before;
      guard.before = function (...args) {
        const request = { method: args[1].method ?? "GET", path: args[1].path,
          urlPrefix: args[0].opts.urlPrefix, apiVersion: args[0].opts.apiVersion ?? "" };
        event({ kind: "GUARDED_API_REQUEST_ATTEMPT", request });
        try { return originalBefore.apply(this, args); }
        catch (caught) {
          const row = { ...errorView(caught), request };
          state.guardRejections.push(row); event({ kind: "TRANSPORT_GUARD_REJECTION", ...row }); throw caught;
        }
      };
      if (realAuth) {
        // The exact installed hash still runs. Before it, complete the real pre-hash
        // capture and restore its owned boundary, then retain the existing upload guard.
        const apply = require(path.join(lib, "deploy/functions/cache/applyHash.js"));
        const originalHash = apply.applyBackendHashToBackends;
        retainOwned(apply, "applyBackendHashToBackends", () => {
          apply.applyBackendHashToBackends = function (...args) {
            packaging.assertOwned(); nativeAdmission.check("BEFORE_ORIGINAL_HASH");
            const completion = identityCapture.finish();
            state.identityCaptureCompleted = true;
            event({ kind: "REAL_SERVICE_IDENTITY_CAPTURE_COMPLETED", phase: selection.phase,
              records: 2, completion, parentControllerAdmitted: false });
            identityBoundary.restore(); identityBoundary = null;
            installBoundary(() => {
              neutral.installNetworkBoundary31(guard);
              neutral.installApiBoundary31(api.Client, guard, operation => credentialWire.beforeUpload(operation));
            });
            return originalHash.apply(this, args);
          };
        });
        identityBoundary = installBoundary(() => {
          const capture = require("./business31ServiceIdentityCapture.cjs").installServiceIdentityCapture31({
            Client: api.Client, guard, phase: selection.phase, source: nativeAdmission.source,
            approvalPointer: nativeAdmission.approvalPointer, baselinePointer: nativeAdmission.baselinePointer,
            now: nativeAdmission.now, assertWindow: nativeAdmission.assertWindow, save: nativeAdmission.saveIdentity,
            assertAdmission: operation => {
              packaging.assertOwned();
              assert.equal(state.preIdentityRefusals, 0, "Every earlier Client refusal is fatal before identity");
              assert.equal(state.guardRejections.length, 0, "Every earlier guard refusal is fatal before identity");
              if (discoveryWire) discoveryWire.beforeIdentity(guard);
              return nativeAdmission.admission(operation);
            }
          });
          wrapPreIdentityRefusals();
          return capture;
        });
        identityCapture = identityBoundary.value;
        event({ kind: "REAL_SERVICE_IDENTITY_CAPTURE_INSTALLED", phase: selection.phase,
          nativeConfigChecks: true, syntheticCustodyOnly: true, fullControllerSourceAndControlsReplay: false });
      } else {
      const http = require("node:http"), https = require("node:https"), net = require("node:net"), tls = require("node:tls"), Module = require("node:module");
      networkSlots = [[https, "request"], [https, "get"], [http, "request"], [http, "get"],
        [net.Socket.prototype, "connect"], [tls, "connect"], [Module, "_load"], [globalThis, "fetch"]];
      const previous = networkSlots.map(([object, key]) => Object.getOwnPropertyDescriptor(object, key));
      neutral.installNetworkBoundary31(guard);
      networkSlots.forEach(([object, key], i) => ownedSlots.push({ object, key, before: previous[i], owned: Object.getOwnPropertyDescriptor(object, key) }));
      retainOwned(api.Client.prototype, "request", () => neutral.installApiBoundary31(api.Client, guard,
        operation => {
          if (credentialWire && operation.kind !== "existing-service-identity") return credentialWire.beforeUpload(operation);
          assert.equal(state.preIdentityRefusals, 0, "Every earlier Client refusal is fatal before identity");
          assert.equal(state.guardRejections.length, 0, "Every earlier guard refusal is fatal before identity");
          if (discoveryWire) discoveryWire.beforeIdentity(guard);
          return require("./business31ServiceIdentityCapture.cjs").admitServiceIdentity31(operation, {
          currentControls: { fixtureOnly: true },
          verifyControls: () => { assert.deepEqual(neutral.existingServiceIdentityBindings31(identityBaseline).projectNumber, NUMBER); },
          assertClean: () => verifyProjectFixtures(),
          assertWindow: () => { event({ kind: "SYNTHETIC_EXISTING_IDENTITY_ADMISSION", service: operation.service,
            fixtureOnly: true, productionControllerControlsOrWindowVerified: false }); }
          });
        }));
      retainOwned(api.Client.prototype, "request", () => {
        wrapPreIdentityRefusals();
      });
      }
      event({ kind: "REAL_UNPREPARED_TRANSPORT_GUARD_INSTALLED", preparedComparisonFabricated: false });
    }
    lease.assertHealthy();
    process.chdir(selection.project);
    if (credentialWire?.failureCase) {
      registerFinish();
      await credentialWire.runFailure();
      return await new Promise(() => {});
    }
    process.argv = [process.execPath, runtime.cliEntrypoint, ...selection.cliArguments];
    assert.deepEqual(process.execArgv, realAuth ? ["--no-global-search-paths"] : []);
    if (credentialWire) credentialWire.beforeCliEntry();
    event({ kind: "REAL_CLI_ENTRY_START", arguments: selection.cliArguments, execArgv: process.execArgv,
      mode: selection.mode, phase: selection.phase });
    if (selection.initializationScenario === "min-version-too-high") registerFinish();
    require(runtime.cliEntrypoint);
    registerFinish();
    // The CLI completes asynchronously and calls its unchanged errorOut/process.exit.
    // Keep the bootstrap's await pending so the strict loader remains active until native closure.
    return await new Promise(() => {});
  } catch (caught) {
    error("FIXTURE_OR_ENTRY_ERROR", caught);
    // Release our installed hooks while the original bootstrap still owns its registrar.
    // Its own catch/finally can then finish the component guard without a second lease cleanup.
    cleanup();
    registerFinish();
    throw caught;
  } finally {
    // This finally runs on synchronous setup failure only; the asynchronous CLI exit is registered below.
  }
}
module.exports = { runCase };
