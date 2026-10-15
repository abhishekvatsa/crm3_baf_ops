"use strict";
// Synthetic, offline regression fixtures. No credential, network, or deployment authority.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const crypto = require("node:crypto");
const transport = require("./runtimeDeploymentTransportGuard31.cjs");
const PROJECT = "crm3-baf-ops-b8638", NUMBER = "123456789012";
const SERVICES = ["pubsub.googleapis.com", "eventarc.googleapis.com"];
const ROLES = { "pubsub.googleapis.com": "roles/pubsub.serviceAgent", "eventarc.googleapis.com": "roles/eventarc.serviceAgent" };
const EMAILS = Object.fromEntries(SERVICES.map(service => [service,
  "service-" + NUMBER + "@gcp-sa-" + service.split(".")[0] + ".iam.gserviceaccount.com"]));
const TYPE = "type.googleapis.com/google.api.serviceusage.v1beta1.ServiceIdentity";
const sha = raw => crypto.createHash("sha256").update(raw).digest("hex").toUpperCase();
function baseline() {
  return {
    project: { method: "GET", url: "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT,
      httpStatus: 200, bodyText: JSON.stringify({ projectId: PROJECT, projectNumber: NUMBER }) },
    projectIam: { method: "POST", url: "https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT + ":getIamPolicy",
      httpStatus: 200, bodyText: JSON.stringify({ version: 3, bindings: SERVICES.map(service =>
        ({ role: ROLES[service], members: ["serviceAccount:" + EMAILS[service]] })) }) }
  };
}
function bodyEdit(original, key, change) {
  const body = JSON.parse(original[key].bodyText); change(body); original[key].bodyText = JSON.stringify(body);
}
function guard(base = baseline()) {
  const allNames = Array.from({ length: 19 }, (_, i) => "fn" + i);
  return new transport.RuntimeDeploymentTransportGuard31({ names: ["fn0"], allNames,
    baselineFunctions: {}, phase: "callables", projectNumber: NUMBER, serviceIdentityBaseline: base,
    sourceArchiveHash: "a".repeat(40), endpointRuntimeHashes: Object.fromEntries(allNames.map(name => [name, "b".repeat(40)])) });
}
function identityRequest(service = SERVICES[0]) {
  return { method: "POST", path: "projects/" + NUMBER + "/services/" + service + ":generateServiceIdentity",
    body: {}, headers: { "x-goog-user-project": NUMBER } };
}
const client = () => ({ opts: { urlPrefix: "https://serviceusage.googleapis.com", apiVersion: "v1beta1" } });
function response(service = SERVICES[0]) {
  return { body: { done: true, response: { "@type": TYPE, email: EMAILS[service], uniqueId: "1234567890" } } };
}
test("service identities derive only from retained project and unconditional single-member IAM bindings", () => {
  assert.deepEqual(transport.existingServiceIdentityBindings31(baseline()), { projectNumber: NUMBER, emails: EMAILS });
});
for (const [name, edit] of [
  ["wrong project", b => bodyEdit(b, "project", p => p.projectId = "other-project")],
  ["missing project number", b => bodyEdit(b, "project", p => delete p.projectNumber)],
  ["nonnumeric project number", b => bodyEdit(b, "project", p => p.projectNumber = "not-a-number")],
  ["missing service-agent role", b => bodyEdit(b, "projectIam", p => p.bindings.shift())],
  ["duplicate service-agent role", b => bodyEdit(b, "projectIam", p => p.bindings.push(structuredClone(p.bindings[0])))],
  ["conditional role", b => bodyEdit(b, "projectIam", p => p.bindings[0].condition = { expression: "true", title: "conditional" })],
  ["extra role member", b => bodyEdit(b, "projectIam", p => p.bindings[0].members.push("serviceAccount:unapproved@example.invalid"))],
  ["wrong service-agent email", b => bodyEdit(b, "projectIam", p => p.bindings[0].members[0] = "serviceAccount:service-999@gcp-sa-pubsub.iam.gserviceaccount.com")],
  ["wrong retained project method", b => b.project.method = "POST"],
  ["wrong retained IAM origin", b => b.projectIam.url = "https://example.invalid/getIamPolicy"],
  ["failed retained IAM response", b => b.projectIam.httpStatus = 403]
]) test("service identity baseline rejects " + name, () => {
  const b = baseline(); edit(b); assert.throws(() => transport.existingServiceIdentityBindings31(b));
});
for (const service of SERVICES) test("existing " + service + " identity admits its exact request and response once", () => {
  const g = guard(), operation = g.before(client(), identityRequest(service));
  assert.equal(operation.kind, "existing-service-identity"); assert.equal(operation.service, service);
  assert.equal(operation.expectedEmail, EMAILS[service]);
  assert.doesNotThrow(() => transport.verifyServiceIdentityResponse31(operation, response(service)));
  g.after(operation, response(service));
  assert.throws(() => g.before(client(), identityRequest(service)), /retry|once|duplicate/i);
});
for (const [name, editRequest, editClient] of [
  ["missing body", r => delete r.body],
  ["null body", r => r.body = null],
  ["array body", r => r.body = []],
  ["nonplain body", r => r.body = Object.create(null)],
  ["lowercase method", r => r.method = "post"],
  ["GET method", r => r.method = "GET"],
  ["HEAD method", r => r.method = "HEAD"],
  ["nonempty body", r => r.body = { serviceAccount: EMAILS[SERVICES[0]] }],
  ["missing project header", r => delete r.headers],
  ["wrong project header", r => r.headers["x-goog-user-project"] = "999999"],
  ["extra request header", r => r.headers.extra = "unapproved"],
  ["numeric project header", r => r.headers["x-goog-user-project"] = Number(NUMBER)],
  ["query parameter", r => r.queryParams = { alt: "json" }],
  ["fragment", r => r.path += "#fragment"],
  ["different project", r => r.path = r.path.replace(NUMBER, "999999")],
  ["project ID in place of observed number", r => r.path = r.path.replace(NUMBER, PROJECT)],
  ["unapproved service", r => r.path = r.path.replace(SERVICES[0], "storage.googleapis.com")],
  ["noncanonical path", r => r.path = "projects/../" + r.path],
  ["wrong API version", () => {}, c => c.opts.apiVersion = "v1"],
  ["wrong origin", () => {}, c => c.opts.urlPrefix = "https://example.invalid"],
  ["URL credentials", () => {}, c => c.opts.urlPrefix = "https://user:password@serviceusage.googleapis.com"],
  ["nondefault port", () => {}, c => c.opts.urlPrefix = "https://serviceusage.googleapis.com:444"],
  ["explicit default port", () => {}, c => c.opts.urlPrefix = "https://serviceusage.googleapis.com:443"],
  ["noncanonical host case", () => {}, c => c.opts.urlPrefix = "https://SERVICEUSAGE.googleapis.com"]
]) test("service identity request rejects " + name + " before forwarding", () => {
  const g = guard(), r = identityRequest(), c = client(); editRequest(r); editClient?.(c);
  assert.throws(() => g.before(c, r));
});
test("service identity request is refused after actual prepared-input comparison", () => {
  const g = guard(), zip = Buffer.from("synthetic archive");
  g.preparedMatches({ sourceArchiveHash: "a".repeat(40),
    endpointRuntimeHashes: Object.fromEntries(Array.from({ length: 19 }, (_, i) => ["fn" + i, "b".repeat(40)])),
    archiveSha256: sha(zip), archiveBytes: zip.length });
  assert.throws(() => g.before(client(), identityRequest()), /prepar|identity/i);
});
test("service identity request cannot bootstrap absent before-controls", () => {
  const allNames = Array.from({ length: 19 }, (_, i) => "fn" + i);
  const withoutBaseline = new transport.RuntimeDeploymentTransportGuard31({ names: ["fn0"], allNames,
    baselineFunctions: {}, phase: "callables", projectNumber: NUMBER });
  assert.throws(() => withoutBaseline.before(client(), identityRequest()));
});
for (const [name, edit] of [
  ["unfinished operation", b => b.done = false],
  ["missing completion", b => delete b.done],
  ["null error property", b => b.error = null],
  ["reported operation error", b => b.error = { code: 403 }],
  ["missing response", b => delete b.response],
  ["different response type", b => b.response["@type"] = "type.googleapis.com/other"],
  ["different email", b => b.response.email = "unapproved@example.invalid"],
  ["unknown identity response field", b => b.response.extra = true],
  ["wrong unique ID type", b => b.response.uniqueId = 123],
  ["nonnumeric unique ID", b => b.response.uniqueId = "not-a-number"]
]) test("service identity response refuses " + name, () => {
  const operation = guard().before(client(), identityRequest()), r = response(); edit(r.body);
  assert.throws(() => transport.verifyServiceIdentityResponse31(operation, r));
});


const identityCapture = require("./business31ServiceIdentityCapture.cjs");
const closure = require("./business31BackendClosure.cjs");
const https = require("node:https"), http = require("node:http"), net = require("node:net"), tls = require("node:tls");
const Module = require("node:module"), zlib = require("node:zlib"), { EventEmitter } = require("node:events");
const SOURCE = { commit: "1".repeat(40), tree: "2".repeat(40), functionsTree: "3".repeat(40) };
const APPROVAL = { commit: "4".repeat(40), file: "release/approvals/build31-business-backend-deployment-approval.json", sha256: "A".repeat(64) };
const EPOCH = Date.parse("2026-10-01T12:00:00.000Z");
function captureFixture(options = {}) {
  const dir = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "business31-service-identity-"));
  let tick = 0, restored = false;
  const clock = () => new Date(EPOCH + tick++).toISOString();
  const window = { notBeforeUtc: new Date(EPOCH - 1000).toISOString(), notAfterUtc: new Date(EPOCH + 30000).toISOString() };
  const pointer = (file, bytes) => ({ file, sha256: sha(bytes), bytes: bytes.length });
  const save = (file, value) => {
    assert.equal(path.basename(file), file);
    const bytes = Buffer.isBuffer(value) ? value : Buffer.from(JSON.stringify(value, null, 2) + "\n");
    fs.writeFileSync(path.join(dir, file), bytes, { flag: "wx" }); return pointer(file, bytes);
  };
  const readBytes = p => {
    assert.deepEqual(Object.keys(p).sort(), ["bytes", "file", "sha256"]);
    assert.equal(path.basename(p.file), p.file);
    const file = path.join(dir, p.file), st = fs.lstatSync(file);
    assert(st.isFile() && !st.isSymbolicLink()); assert.equal(st.size, p.bytes);
    const bytes = fs.readFileSync(file); assert.equal(bytes.length, p.bytes); assert.equal(sha(bytes), p.sha256); return bytes;
  };
  const read = p => JSON.parse(readBytes(p).toString("utf8"));
  const base = baseline(), baselinePointer = save("baseline.json", base);
  const currentDocument = { project: base.project, projectIam: base.projectIam,
    startedAtUtc: new Date(EPOCH - 500).toISOString(), completedAtUtc: new Date(EPOCH - 100).toISOString() };
  const currentControls = save("current-controls.json", currentDocument);
  const guardInputs = { names: ["fn0"], allNames: Array.from({ length: 19 }, (_, i) => "fn" + i),
    baselineFunctions: {}, projectNumber: NUMBER, serviceIdentityBaseline: base };
  const g = new transport.RuntimeDeploymentTransportGuard31({ ...guardInputs, phase: "callables" });
  const calls = [], admissionChecks = [], deferred = [];
  let nativeWrites = 0, nativeEnds = 0, nativeClientCalls = 0;
  class Client {
    constructor(opts) { this.opts = opts; }
    request(request) {
      nativeClientCalls++;
      assert.equal(request.retries, 0); assert.deepEqual(request.retryCodes, []);
      return new Promise((resolve, reject) => {
        const req = https.request(transport.urlOf(this, request), { method: request.method, headers: request.headers }, res => {
          const chunks = [];
          res.on("error", reject); res.on("aborted", () => reject(Error("SYNTHETIC_RESPONSE_ABORTED")));
          res.on("data", bytes => chunks.push(bytes));
          res.on("end", () => {
            try {
              let raw = Buffer.concat(chunks);
              if (options.encoding === "gzip") raw = zlib.gunzipSync(raw);
              const parsed = JSON.parse(raw.toString("utf8"));
              if (res.statusCode < 200 || res.statusCode >= 300) return reject(Error("SYNTHETIC_NATIVE_HTTP_FAILURE"));
              resolve({ status: res.statusCode, body: options.correctApiProjection ? response(request.path.includes("eventarc") ? SERVICES[1] : SERVICES[0]).body : parsed });
            } catch (error) { reject(error); }
          });
        });
        req.on("error", reject); req.end(Buffer.from(JSON.stringify(request.body)));
      });
    }
  }
  const slots = [[https, "request"], [https, "get"], [http, "request"], [http, "get"],
    [net.Socket.prototype, "connect"], [tls, "connect"], [Module, "_load"], [globalThis, "fetch"], [Client.prototype, "request"]];
  const originals = slots.map(([object, key]) => Object.getOwnPropertyDescriptor(object, key));
  const restoreSlots = () => slots.forEach(([object, key], i) => {
    if (originals[i]) Object.defineProperty(object, key, originals[i]); else delete object[key];
  });
  // Native sockets are refused even if the module under test regresses its boundary.
  net.Socket.prototype.connect = () => { throw Error("TEST_NATIVE_SOCKET_FORBIDDEN"); };
  tls.connect = () => { throw Error("TEST_NATIVE_TLS_FORBIDDEN"); };
  http.request = () => { throw Error("TEST_NATIVE_HTTP_FORBIDDEN"); };
  https.request = function (input, opts, callback) {
    const effective = transport.effectiveRequest31(input, opts, "https:");
    assert.equal(effective.url.origin, "https://serviceusage.googleapis.com");
    assert.equal(effective.method, "POST");
    const row = { url: effective.url.href, method: effective.method, chunks: [] }; calls.push(row);
    const req = new EventEmitter();
    req.write = bytes => { assert(Buffer.isBuffer(bytes)); nativeWrites++; row.chunks.push(Buffer.from(bytes)); return true; };
    req.destroy = error => { if (error) queueMicrotask(() => req.emit("error", error)); return req; };
    req.end = bytes => {
      nativeEnds++; if (bytes !== undefined) req.write(bytes);
      const dispatch = () => {
        if (options.lost) return req.emit("error", Error("SYNTHETIC_SECRET_MUST_NOT_BE_RETAINED"));
        const service = row.url.includes("eventarc.googleapis.com:") ? SERVICES[1] : SERVICES[0];
        const result = response(service).body;
        if (options.mismatch) result.response.email = "unapproved@example.invalid";
        let raw = options.invalidUtf8 ? Buffer.from([0xff]) : Buffer.from(JSON.stringify(result));
        if (options.encoding === "gzip") raw = zlib.gzipSync(raw);
        const res = new EventEmitter(); res.statusCode = options.status ?? 200;
        res.headers = options.encoding ? { "content-encoding": options.encoding } : {};
        res.destroy = error => { res.emit("error", error); req.emit("error", error); };
        req.emit("response", res); res.emit("data", raw);
        if (options.truncated) { res.emit("aborted"); req.emit("error", Error("SYNTHETIC_TRUNCATED_RESPONSE")); }
        else res.emit("end");
      };
      if (options.reverseCompletion) {
        deferred.push(dispatch);
        if (deferred.length === 2) for (const fn of [...deferred].reverse()) queueMicrotask(fn);
      } else queueMicrotask(dispatch);
      return req;
    };
    if (callback) req.on("response", callback); return req;
  };
  const assertWindow = () => {
    const now = clock(); assert(window.notBeforeUtc <= now && now <= window.notAfterUtc); return now;
  };
  let capture;
  try {
    capture = identityCapture.installServiceIdentityCapture31({
      Client, guard: g, phase: "callables", source: SOURCE, approvalPointer: APPROVAL, baselinePointer, save, now: clock, assertWindow,
      assertAdmission: operation => {
        if (options.admissionFailure === "callback") throw Error("SYNTHETIC_CALLBACK_REFUSAL");
        return identityCapture.admitServiceIdentity31(operation, {
          currentControls: options.admissionFailure === "missing-controls" ? null : currentControls,
          verifyControls(p) { admissionChecks.push("controls"); assert.deepEqual(read(p), currentDocument);
            if (options.admissionFailure === "controls") throw Error("SYNTHETIC_CONTROL_DRIFT"); },
          assertClean() { admissionChecks.push("clean"); if (options.admissionFailure === "clean") throw Error("SYNTHETIC_SOURCE_DRIFT"); },
          assertWindow() { admissionChecks.push("window"); if (options.admissionFailure === "window") throw Error("SYNTHETIC_WINDOW_CLOSED"); return assertWindow(); }
        });
      }
    });
  } catch (error) { restoreSlots(); throw error; }
  const f = {
    dir, save, read, readBytes, calls, capture, g, admissionChecks, currentControls, currentDocument, baselinePointer, guardInputs, window,
    now: clock, preparedCapture: null,
    get nativeClientCalls() { return nativeClientCalls; },
    get nativeWrites() { return nativeWrites; }, get nativeEnds() { return nativeEnds; },
    call(service = SERVICES[0], request = identityRequest(service)) { return new Client(client().opts).request(request); },
    replay(p, overrides = {}) {
      assert(this.preparedCapture, "actual synthetic prepared-capture completion required");
      return identityCapture.replayServiceIdentityCapture31({ pointer: p, read, readBytes,
        verifyResponse: (responsePointer, bindingPointer) => closure.verifyMutationResponse31(dir, responsePointer, bindingPointer),
        guardInputs, phase: "callables", source: SOURCE, approvalPointer: APPROVAL, baselinePointer, currentControls,
        executionWindow: window, earliestUtc: currentDocument.completedAtUtc, latestUtc: this.preparedCapture.completedAtUtc, ...overrides });
    },
    restore() {
      if (restored) return; restored = true; restoreSlots();
      save("TEST_NATIVE_RESULT.json", { options, calls: calls.map(row => ({ url: row.url, method: row.method,
        rawBodyHex: Buffer.concat(row.chunks).toString("hex") })), nativeClientCalls, nativeWrites, nativeEnds, admissionChecks });
      console.error("Retained service-identity fixture: " + dir);
    }
  };
  return f;
}
async function withCapture(options, run) {
  const f = captureFixture(options); try { return await run(f); } finally { f.restore(); }
}
async function completeCapture(f) {
  if (f.calls.length) throw Error("A fresh fixture is required");
  const result = await Promise.all(SERVICES.map(service => f.call(service)));
  assert.equal(result.length, 2);
  const pointer = f.capture.finish();
  // The historical hook-install start precedes identity observations; their upper bound is actual later capture completion.
  f.preparedCapture = { startedAtUtc: new Date(EPOCH - 1000).toISOString(), completedAtUtc: f.now() };
  f.save("PREPARED_CAPTURE_CHRONOLOGY.json", f.preparedCapture); return pointer;
}
test("current-controls admission checks controls, source and window before forwarding", () => {
  const order = [], currentControls = { file: "controls.json", sha256: "C".repeat(64), bytes: 10 };
  const result = identityCapture.admitServiceIdentity31({ kind: "existing-service-identity" }, {
    currentControls, verifyControls(p) { assert.equal(p, currentControls); order.push("controls"); },
    assertClean() { order.push("clean"); }, assertWindow() { order.push("window"); } });
  assert.equal(result, currentControls); assert.deepEqual(order, ["controls", "clean", "window"]);
});
for (const failure of ["callback", "missing-controls", "controls", "clean", "window"]) {
  test("service identity " + failure + " refusal prevents the native callback", async () => withCapture({ admissionFailure: failure }, async f => {
    await assert.rejects(f.call()); assert.equal(f.calls.length, 0); assert.equal(f.nativeClientCalls, 0); assert.equal(f.nativeWrites, 0); assert.equal(f.nativeEnds, 0);
    assert.throws(() => f.capture.finish());
    assert(fs.readdirSync(f.dir).some(name => name.startsWith("service-identity-refusal-")));
  }));
}
test("nonidentity admission never invokes current-controls callbacks", () => {
  let calls = 0;
  assert.throws(() => identityCapture.admitServiceIdentity31({ kind: "read" }, {
    currentControls: {}, verifyControls() { calls++; }, assertClean() { calls++; }, assertWindow() { calls++; } }));
  assert.equal(calls, 0);
});
for (const options of [{}, { encoding: "gzip" }, { reverseCompletion: true }]) {
  test("two original identity responses retain exact wire and replay without authority: " + JSON.stringify(options), async () => withCapture(options, async f => {
    const p = await completeCapture(f), completed = f.replay(p);
    assert(f.preparedCapture.startedAtUtc < f.currentDocument.completedAtUtc);
    assert.throws(() => f.replay(p, { latestUtc: f.preparedCapture.startedAtUtc }), /chronolog|completion/i);
    assert.equal(completed.records.length, 2); assert.equal(completed.historicalUniqueIdContinuityClaimed, false);
    assert.equal(Object.hasOwn(completed, "deploymentAuthorized"), false);
    assert.deepEqual(f.admissionChecks, ["controls", "clean", "window", "controls", "clean", "window"]);
    for (const pointer of completed.records) {
      const row = f.read(pointer); assert.equal(row.error, null); assert.equal(f.readBytes(row.wireBody).toString(), "{}");
      assert(f.currentDocument.completedAtUtc <= row.startedAtUtc && row.completedAtUtc <= f.preparedCapture.completedAtUtc);
      const retained = f.read(row.response); assert.equal(JSON.parse(retained.bodyText).response.email, EMAILS[row.service]);
      const binding = f.read(row.responseBinding);
      assert.equal(binding.responseComplete, true); assert.equal(binding.httpStatus, 200);
      assert.equal(binding.retainedBytes, f.readBytes(binding.responseRaw).length);
    }
    assert.throws(() => f.capture.finish(), /complete|finished|original/i);
  }));
}
for (const options of [{ mismatch: true }, { mismatch: true, correctApiProjection: true }, { status: 503 },
  { lost: true }, { truncated: true }, { invalidUtf8: true }, { encoding: "unsupported" }]) {
  test("failed identity response remains original and cannot complete: " + JSON.stringify(options), async () => withCapture(options, async f => {
    await assert.rejects(f.call()); assert.equal(f.calls.length, 1);
    const row = JSON.parse(fs.readFileSync(path.join(f.dir, "service-identity-01.json"), "utf8"));
    assert(row.error); assert.equal(row.error.code, "EXISTING_IDENTITY_NOT_PROVEN");
    assert.equal(f.readBytes(row.wireBody).toString(), "{}");
    const binding = f.read(row.responseBinding), rawResponse = f.readBytes(binding.responseRaw);
    if (options.lost) { assert.equal(rawResponse.length, 0); assert.equal(binding.responseComplete, false); }
    else assert(rawResponse.length > 0, "actual response bytes must remain retained");
    if (options.truncated) assert.equal(binding.responseComplete, false);
    if (options.invalidUtf8) assert.deepEqual(rawResponse, Buffer.from([0xff]));
    if (options.mismatch || options.status) assert(row.response, "a complete invalid body must remain retained");
    const original = fs.readdirSync(f.dir).filter(name => name.endsWith(".json")).map(name => fs.readFileSync(path.join(f.dir, name), "utf8")).join("\n");
    assert(!original.includes("SYNTHETIC_SECRET_MUST_NOT_BE_RETAINED"));
    assert.throws(() => f.capture.finish()); await assert.rejects(f.call(SERVICES[1]));
    assert.equal(f.calls.length, 1, "failed first identity must not allow another native call");
  }));
}
test("duplicate service request cannot cause a second native call or a completion", async () => withCapture({}, async f => {
  await f.call(); await assert.rejects(f.call()); assert.equal(f.calls.length, 1); assert.throws(() => f.capture.finish());
}));
test("inherited toJSON cannot change exact empty-object admission", () => {
  const g = guard(), request = identityRequest(), prior = Object.getOwnPropertyDescriptor(Object.prototype, "toJSON");
  try {
    Object.defineProperty(Object.prototype, "toJSON", { configurable: true, value() { return this === request.body ? { changed: true } : this; } });
    assert.throws(() => g.before(client(), request));
  } finally { if (prior) Object.defineProperty(Object.prototype, "toJSON", prior); else delete Object.prototype.toJSON; }
});
test("changing inherited toJSON after admission cannot forward altered native body bytes", async () => withCapture({}, async f => {
  const request = identityRequest(), prior = Object.getOwnPropertyDescriptor(Object.prototype, "toJSON"); let serializations = 0;
  try {
    Object.defineProperty(Object.prototype, "toJSON", { configurable: true, value() {
      if (this !== request.body) return this; return ++serializations === 1 ? {} : { changed: true };
    } });
    await assert.rejects(f.call(SERVICES[0], request));
    assert.equal(f.nativeWrites, 0); assert.equal(f.nativeEnds, 0);
    assert.equal(Buffer.concat(f.calls.flatMap(row => row.chunks)).length, 0);
    assert.throws(() => f.capture.finish());
  } finally { if (prior) Object.defineProperty(Object.prototype, "toJSON", prior); else delete Object.prototype.toJSON; }
}));
function changedCompletion(f, p, tag, editCompletion, editRow) {
  const completion = structuredClone(f.read(p));
  if (editRow) {
    const row = structuredClone(f.read(completion.records[0])); editRow(row);
    completion.records[0] = f.save(tag + "-row.json", row);
  }
  if (editCompletion) editCompletion(completion);
  return f.save(tag + "-completion.json", completion);
}
test("replay refuses rehashed record, authority, chronology, request and wire substitutions", async () => withCapture({}, async f => {
  const p = await completeCapture(f);
  const cases = [
    ["missing-record", c => c.records.pop()],
    ["duplicate-record", c => c.records[1] = c.records[0]],
    ["extra-record", c => c.records.push(c.records[0])],
    ["authority", c => c.source.commit = "0".repeat(40)],
    ["continuity-claim", c => c.historicalUniqueIdContinuityClaimed = true],
    ["completion-time", c => c.completedAtUtc = new Date(EPOCH - 2000).toISOString()],
    ["phase", null, r => r.phase = "events"],
    ["service", null, r => r.service = SERVICES[1]],
    ["controls", null, r => r.currentControls = f.baselinePointer],
    ["before-current-controls", null, r => r.startedAtUtc = f.preparedCapture.startedAtUtc],
    ["late-initiation", null, r => r.firstOutboundAtUtc = new Date(EPOCH + 30001).toISOString()],
    ["early-response", null, r => r.completedAtUtc = new Date(EPOCH - 2000).toISOString()],
    ["changed-body", null, r => { const q = f.read(r.request); q.request.body = { changed: true }; r.request = f.save("changed-request.json", q); }],
    ["changed-wire", null, r => r.wireBody = f.save("changed-wire.bin", Buffer.from("{} "))],
    ["projection-disagrees-with-wire", null, r => { const body = f.read(r.response); body.bodyText = JSON.stringify(response(SERVICES[1]).body);
      r.response = f.save("false-derived-response.json", body); }]
  ];
  for (const [tag, editCompletion, editRow] of cases) {
    const altered = changedCompletion(f, p, tag, editCompletion, editRow);
    assert.throws(() => f.replay(altered), undefined, tag + ": retained fixture " + f.dir);
  }
}));
test("replay rechecks existing email even when altered raw bytes and projection are consistently rehashed", async () => withCapture({}, async f => {
  const p = await completeCapture(f);
  const altered = changedCompletion(f, p, "wrong-observed-email", null, row => {
    const wrong = response().body; wrong.response.email = "unapproved@example.invalid";
    const bytes = Buffer.from(JSON.stringify(wrong)), binding = f.read(row.responseBinding);
    binding.responseRaw = f.save("wrong-email-wire.bin", bytes); binding.retainedBytes = bytes.length;
    row.responseBinding = f.save("wrong-email-binding.json", binding);
    row.response = f.save("wrong-email-response.json", { httpStatus: 200, bodyText: bytes.toString("utf8") });
  });
  assert.throws(() => f.replay(altered), /existing IAM member|identity/i);
}));
