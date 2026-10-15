"use strict";
// Synthetic, credential-free data and local executable entry fixtures only.
// No cloud read, deployment, successful controller rehearsal or production proof.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const crypto = require("node:crypto"), cp = require("node:child_process");
const guard = require("./business31ScopedCallableInvokerIam.cjs");
const controls = require("./business31BackendControls.cjs");
const legacy = require("./scopedCallableInvokerIam.js");
const { makeRawControls } = require("./business31RawControlsFixture.cjs");
const hash = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const SOURCE = "1".repeat(40), APPROVAL = "A".repeat(64), NUMBER = "123456789012";
const policy = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../release/function-fleet-runtime-identity-policy.json")));
const SERVICES = ["", "run.googleapis.com"], LOCATION = "me-central2";
const endpoint = `https://run.googleapis.com/v2/projects/${guard.PROJECT}/locations/${LOCATION}/services?pageSize=100`;
function refusal(service) {
  return { url: endpoint, method: "GET", httpStatus: 403,
    bodyText: JSON.stringify({ error: { code: 403, status: "PERMISSION_DENIED", message: "Synthetic region access refusal.",
      details: [{ "@type": "type.googleapis.com/google.rpc.ErrorInfo", reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com",
        metadata: { location: LOCATION, consumer: "projects/" + NUMBER, service } }] } }) };
}
function edit(row, action) {
  const value = JSON.parse(row.bodyText); action(value); row.bodyText = JSON.stringify(value);
}
function data(service, tag = "before") {
  const result = makeRawControls({ policy, sourceCommit: SOURCE, approvalSha256: APPROVAL,
    startedAtUtc: "2026-10-01T00:00:00Z", completedAtUtc: "2026-10-01T00:00:01Z",
    endpointLabels: Object.fromEntries(Object.keys(policy.functionBindings).map(n => [n, "2".repeat(40)])), outputTag: tag });
  edit(result.raw.runLocations[0], value => value.locations.push({ locationId: LOCATION }));
  result.raw.runInventories.push({ location: LOCATION, unavailable: refusal(service) });
  return result;
}
function transport(fixture) {
  const rows = new Map(), visited = new Set();
  function walk(v) {
    if (v && typeof v === "object" && typeof v.url === "string") {
      assert.equal(rows.has(v.url), false); rows.set(v.url, v);
    } else if (v && typeof v === "object") Object.values(v).forEach(walk);
  }
  walk(fixture);
  return { visited, rows, async read(url, method = "GET", request) {
    const row = rows.get(url); assert.ok(row, "unexpected synthetic read: " + url);
    assert.equal(method, row.method); assert.equal(visited.has(url), false); visited.add(url);
    if (url.startsWith("https://cloudresourcemanager.googleapis.com/") && method === "POST")
      assert.deepEqual(request, { options: { requestedPolicyVersion: 3 } });
    else assert.equal(request, undefined);
    return structuredClone(row);
  } };
}

for (const service of SERVICES) test("versioned guard accepts only the measured service shape " + JSON.stringify(service), () => {
  const row = refusal(service), before = structuredClone(row), bodyHash = hash(Buffer.from(row.bodyText));
  assert.deepEqual(guard.unavailableRunRegion(row, LOCATION, NUMBER), {
    location: LOCATION, reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com", consumer: "projects/" + NUMBER });
  assert.deepEqual(row, before); assert.equal(hash(Buffer.from(row.bodyText)), bodyHash);
  assert.equal(Object.hasOwn(guard.unavailableRunRegion(row, LOCATION, NUMBER), "services"), false);
  assert.equal(Object.hasOwn(guard.unavailableRunRegion(row, LOCATION, NUMBER), "pages"), false);
});
test("legacy producer remains the exact original and retains its original finite predicate", () => {
  assert.equal(hash(fs.readFileSync(path.join(__dirname, "scopedCallableInvokerIam.js"))),
    "0CCF35EE2AE349377A262CD7079553AA0E3FDA82A4FC738D4B6D32DB74548822");
  assert.deepEqual(legacy.unavailableRunRegion(refusal(""), LOCATION, NUMBER), guard.unavailableRunRegion(refusal(""), LOCATION, NUMBER));
  assert.throws(() => legacy.unavailableRunRegion(refusal("run.googleapis.com"), LOCATION, NUMBER), /project\/location identity differs/);
});
const negatives = [
  ["missing service", r => edit(r, v => delete v.error.details[0].metadata.service)],
  ...[null, 0, false, {}, [], "iam.googleapis.com", " run.googleapis.com", "run.googleapis.com ", "RUN.GOOGLEAPIS.COM"].map(service =>
    ["invalid service " + JSON.stringify(service), r => edit(r, v => { v.error.details[0].metadata.service = service; })]),
  ["wrong reason", r => edit(r, v => { v.error.details[0].reason = "IAM_PERMISSION_DENIED"; })],
  ["wrong domain", r => edit(r, v => { v.error.details[0].domain = "run.googleapis.com"; })],
  ["wrong project", r => edit(r, v => { v.error.details[0].metadata.consumer = "projects/999"; })],
  ["wrong location", r => edit(r, v => { v.error.details[0].metadata.location = "us-central1"; })],
  ["missing metadata", r => edit(r, v => delete v.error.details[0].metadata)],
  ["missing ErrorInfo", r => edit(r, v => { v.error.details = []; })],
  ["ambiguous ErrorInfo", r => edit(r, v => v.error.details.push(structuredClone(v.error.details[0])))],
  ["wrong error code", r => edit(r, v => { v.error.code = 404; })],
  ["wrong error status", r => edit(r, v => { v.error.status = "NOT_FOUND"; })],
  ["wrong HTTP status", r => { r.httpStatus = 404; }],
  ["wrong method", r => { r.method = "POST"; }],
  ["wrong endpoint project", r => { r.url = r.url.replace(guard.PROJECT, "synthetic-other-project"); }],
  ["second page", r => { r.url += "&pageToken=next"; }],
  ["malformed body", r => { r.bodyText = "{"; }],
  ["extra top-level body field", r => edit(r, v => { v.extra = true; })],
];
for (const service of SERVICES) for (const [name, mutate] of negatives)
  test("versioned guard rejects " + name + " from " + JSON.stringify(service), () => {
    const row = refusal(service); mutate(row); const original = structuredClone(row);
    assert.throws(() => guard.unavailableRunRegion(row, LOCATION, NUMBER), /Scoped invoker IAM/);
    assert.deepEqual(row, original);
  });
for (const service of SERVICES) for (const location of [guard.REGION, "me-central1"])
  test("versioned guard never excludes target or unreviewed region " + location, () => {
    const row = refusal(service); row.url = row.url.replace(LOCATION, location);
    edit(row, v => { v.error.details[0].metadata.location = location; });
    assert.throws(() => guard.unavailableRunRegion(row, location, NUMBER), /target or invalid Run region/);
  });
for (const service of SERVICES) test("versioned guard requires numeric project identity " + JSON.stringify(service), () => {
  assert.throws(() => guard.unavailableRunRegion(refusal(service), LOCATION, "synthetic-project-number"), /target or invalid Run region/);
});

for (const [beforeService, afterService] of [["", ""], ["run.googleapis.com", "run.googleapis.com"], ["", "run.googleapis.com"]])
  test("real versioned current collector and comparator preserve unknown region " + JSON.stringify([beforeService, afterService]), async () => {
    const measurements = [];
    for (const service of [beforeService, afterService]) {
      const f = data(service), original = structuredClone(f), io = transport(f);
      const collected = await controls.collectCurrentRawControls31({ sourceCommit: SOURCE, approvalSha256: APPROVAL,
        read: io.read, unavailableRunRegion: guard.unavailableRunRegion });
      assert.equal(io.visited.size, io.rows.size, "every real collector read must receive a synthetic original");
      assert.deepEqual(f, original, "injected originals are never normalized or changed");
      assert.deepEqual(collected.raw.runInventories.at(-1), f.raw.runInventories.at(-1));
      assert.equal(Object.hasOwn(collected.raw.runInventories.at(-1), "pages"), false);
      assert.equal(Object.hasOwn(collected.raw.runInventories.at(-1), "services"), false);
      assert.equal(collected.raw.runInventories.at(-1).unavailable.bodyText, f.raw.runInventories.at(-1).unavailable.bodyText);
      assert.deepEqual(collected.scheduler, f.scheduler);
      const measured = controls.summarizeRaw({ raw: collected.raw, policy, sourceCommit: SOURCE, approvalSha256: APPROVAL, guard });
      assert.deepEqual(measured.excluded, [{ location: LOCATION, reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com", consumer: "projects/" + NUMBER }]);
      measurements.push(measured);
    }
    const summary = controls.compareWithSupplement({ before: measurements[0], after: measurements[1], policy,
      runtime: "nodejs22", declaredMaxInstances: 20 });
    assert.equal(summary.functionCount, 19); assert.equal(summary.newFunctionCount, 0);
    assert.equal(summary.measuredProjectRunAndServiceAccountIamPreserved, true);
    assert.equal(summary.allExistingFunctionEffectiveControlsPreserved, true);
    assert.deepEqual(summary.unavailableRunRegions, measurements[0].excluded);
    assert.deepEqual(summary.normalizedDeploymentOutputs.changedFunctions, [], "no-change data is not a deployment proof");
  });
test("current collector refuses generic denial and a later-page region refusal", async () => {
  const generic = data("run.googleapis.com");
  edit(generic.raw.runInventories.at(-1).unavailable, v => { v.error.details[0].reason = "IAM_PERMISSION_DENIED"; });
  await assert.rejects(controls.collectCurrentRawControls31({ sourceCommit: SOURCE, approvalSha256: APPROVAL,
    read: transport(generic).read, unavailableRunRegion: guard.unavailableRunRegion }), /reason/);
  const partial = data("run.googleapis.com"), row = partial.raw.runInventories.at(-1), second = row.unavailable;
  second.url += "&pageToken=next";
  row.pages = [{ url: endpoint, method: "GET", httpStatus: 200, bodyText: JSON.stringify({ services: [], nextPageToken: "next" }) }, second];
  delete row.unavailable;
  await assert.rejects(controls.collectCurrentRawControls31({ sourceCommit: SOURCE, approvalSha256: APPROVAL,
    read: transport(partial).read, unavailableRunRegion: guard.unavailableRunRegion }), /Complete current controls readback unavailable/);
});
test("unknown-region exclusion never hides observed IAM or coverage drift", () => {
  const before = data(""), after = data("run.googleapis.com");
  const summarize = f => controls.summarizeRaw({ raw: f.raw, policy, sourceCommit: SOURCE, approvalSha256: APPROVAL, guard });
  edit(after.raw.runIam[0].response, v => { v.bindings = [{ role: "roles/run.invoker", members: ["allUsers"] }]; });
  assert.throws(() => controls.compareWithSupplement({ before: summarize(before), after: summarize(after), policy,
    runtime: "nodejs22", declaredMaxInstances: 20 }), /Preserved IAM\/identity\/inventory drift/);
  const accessible = data("run.googleapis.com"), row = accessible.raw.runInventories.at(-1);
  row.pages = [{ url: endpoint, method: "GET", httpStatus: 200, bodyText: '{"services":[]}' }]; delete row.unavailable;
  assert.throws(() => controls.compareWithSupplement({ before: summarize(before), after: summarize(accessible), policy,
    runtime: "nodejs22", declaredMaxInstances: 20 }), /Preserved IAM\/identity\/inventory drift: excluded/);
});

// This is the actual CAPTURE executable entry with real bootstrap and new bound
// modules. Its operational driver is an explicitly private synthetic data phase;
// no preparation/deployment CLI, cohort write or full controller is run.
async function localPhase({ configuration }) {
  const assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path");
  require("./business31CaptureBootstrap.cjs").assertOperational31();
  assert.equal(require.main.filename, path.join(__dirname, "captureBusiness31PreparedInputs.cjs"));
  assert.deepEqual(Object.keys(require.main.exports), []);
  let externalCalls = 0;
  const blocked = () => { externalCalls++; throw Error("EXTERNAL_TRANSPORT_FORBIDDEN"); };
  for (const api of [require("node:http"), require("node:https")]) for (const k of ["request", "get"]) api[k] = blocked;
  require("node:net").Socket.prototype.connect = require("node:tls").connect = blocked;
  for (const k of ["lookup", "resolve"]) require("node:dns")[k] = blocked;
  require("node:dgram").createSocket = globalThis.fetch = blocked;
  for (const k of ["spawn", "spawnSync", "exec", "execSync", "execFile", "execFileSync", "fork"]) require("node:child_process")[k] = blocked;
  const guard = require("./business31ScopedCallableInvokerIam.cjs"), controls = require("./business31BackendControls.cjs");
  const operational = require("./actual-business-controller.cjs");
  const fixture = configuration.syntheticRegionFixture, original = structuredClone(fixture.raw);
  const responses = new Map(), visited = new Set();
  const walk = value => {
    if (value && typeof value === "object" && typeof value.url === "string") {
      assert.equal(responses.has(value.url), false); responses.set(value.url, value);
    } else if (value && typeof value === "object") Object.values(value).forEach(walk);
  };
  walk({raw:fixture.raw,scheduler:fixture.scheduler});
  const collected = await operational.collectCurrentBusinessControls31({sourceCommit:fixture.sourceCommit,
    approvalSha256:fixture.approvalSha256,unavailableRunRegion:guard.unavailableRunRegion,
    read:async(url,method="GET",body)=>{
      const row=responses.get(url);assert.ok(row,"unexpected synthetic operational read: "+url);
      assert.equal(method,row.method);assert.equal(visited.has(url),false);visited.add(url);
      if(method==="POST"&&url.startsWith("https://cloudresourcemanager.googleapis.com/"))assert.deepEqual(body,{options:{requestedPolicyVersion:3}});
      else assert.equal(body,undefined);
      return structuredClone(row);
    }});
  assert.equal(visited.size,responses.size);
  assert.deepEqual(collected.raw.runInventories.at(-1),fixture.raw.runInventories.at(-1));
  assert.equal(Object.hasOwn(collected.raw.runInventories.at(-1),"pages"),false);
  assert.deepEqual(collected.scheduler,fixture.scheduler);
  const measured = controls.summarizeRaw({ raw: collected.raw, policy: fixture.policy,
    sourceCommit: fixture.sourceCommit, approvalSha256: fixture.approvalSha256, guard });
  const compared = controls.compareWithSupplement({ before: measured, after: measured, policy: fixture.policy,
    runtime: "nodejs22", declaredMaxInstances: 20 });
  assert.deepEqual(fixture.raw, original); assert.equal(compared.functionCount, 19);
  assert.equal(compared.unavailableRunRegions.length, 1); assert.equal(externalCalls, 0);
  assert.deepEqual(Object.keys(require.main.exports), []);
  fs.writeFileSync(fixture.resultFile, JSON.stringify({ realCaptureEntry: true, versionedGuardAndControlsReached: true, realOperationalCollectorReached: true,
    unknownRegionPreserved: true, externalCalls, syntheticLocalFixture: true, productionAuthority: false }) + "\n", { flag: "wx" });
}
function inventory(root) {
  const files = {};
  function walk(dir) {
    for (const row of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      assert.equal(row.isSymbolicLink(), false); const p = path.join(dir, row.name);
      if (row.isDirectory()) walk(p);
      else { assert.equal(row.isFile(), true); files[path.relative(root, p).split(path.sep).join("/")] = hash(fs.readFileSync(p)); }
    }
  }
  walk(root); return files;
}
function save(file, value) {
  const b = Buffer.from(JSON.stringify(value) + "\n"); fs.writeFileSync(file, b, { flag: "wx" });
  return { file: path.basename(file), sha256: hash(b), bytes: b.length };
}
function environment(root) {
  const env = {};
  for (const [k, v] of Object.entries(process.env)) if (["SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT", "PATH", "LANG", "LC_ALL"].includes(k.toUpperCase())) env[k] = v;
  for (const k of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "TEMP", "TMP"]) {
    env[k] = path.join(root, k); fs.mkdirSync(env[k]);
  }
  return env;
}
function entryFixture(t, service, altered) {
  const directory = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "b31-region-entry-"));
  t.diagnostic("Retained synthetic CAPTURE entry originals: " + directory);
  const sourceRoot = path.join(directory, "release"), evidenceDirectory = path.join(directory, "evidence");
  const originalSource = inventory(__dirname);
  fs.cpSync(__dirname, sourceRoot, { recursive: true, dereference: false, errorOnExist: true, force: false });
  assert.deepEqual(inventory(sourceRoot), originalSource);
  fs.mkdirSync(evidenceDirectory);
  fs.copyFileSync(path.join(sourceRoot,"business31OperationalController.cjs"),path.join(sourceRoot,"actual-business-controller.cjs"),fs.constants.COPYFILE_EXCL);
  fs.writeFileSync(path.join(sourceRoot, "business31OperationalController.cjs"),
    '"use strict";module.exports={runPhaseChild31:' + localPhase.toString() + '};\n');
  const resultFile = path.join(directory, "entry-result.json"), contextFile = path.join(directory, "context.json");
  const env = environment(directory), boundFiles = inventory(sourceRoot);
  for (const name of ["business31BackendControls.cjs", "business31ScopedCallableInvokerIam.cjs"]) assert.ok(boundFiles[name], "versioned helper bound by actual entry");
  const synthetic = data(service);
  const config = save(path.join(evidenceDirectory, "configuration.json"), {
    execution: { sourceRoot, helperFiles: boundFiles, environment: env,
      nodeExecutable: { path: process.execPath, sha256: hash(fs.readFileSync(process.execPath)) } },
    syntheticRegionFixture: { raw: synthetic.raw, scheduler: synthetic.scheduler, policy, sourceCommit: SOURCE, approvalSha256: APPROVAL, resultFile }
  });
  const context = save(contextFile, { evidenceDirectory, configuration: config });
  if (altered) {
    fs.appendFileSync(path.join(sourceRoot, altered), "\n// altered unadmitted helper\n");
    const changedFiles = inventory(sourceRoot);
    assert.deepEqual(Object.keys(changedFiles).sort(), Object.keys(boundFiles).sort(), "private population membership retained");
    assert.deepEqual(Object.keys(changedFiles).filter(name => changedFiles[name] !== boundFiles[name]), [altered], "only the selected bound helper bytes changed");
  }
  const argv = ["--no-global-search-paths", path.join(sourceRoot, "captureBusiness31PreparedInputs.cjs"), "--config", contextFile];
  const result = cp.spawnSync(process.execPath, argv, { cwd: directory, env: { ...env, BUSINESS31_PHASE_CONTEXT_SHA256: context.sha256 },
    windowsHide: true, timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
  fs.writeFileSync(path.join(directory, "stdout.bin"), result.stdout ?? Buffer.alloc(0), { flag: "wx" });
  fs.writeFileSync(path.join(directory, "stderr.bin"), result.stderr ?? Buffer.alloc(0), { flag: "wx" });
  save(path.join(directory, "process-result.json"), { argv, exitCode: result.status, signal: result.signal, error: result.error?.code ?? null,
    syntheticLocalFixture: true, productionAuthority: false });
  assert.deepEqual(inventory(__dirname), originalSource, "selected source preserved");
  assert.equal(result.error, undefined); assert.equal(result.signal, null);
  if (altered) {
    assert.equal(result.status, 1);
    assert.equal(result.stderr.toString("utf8"), "Business cohort failed: Business capture bootstrap: population bytes differ\n");
    assert.equal(result.stdout.length, 0, "bootstrap refusal occurs before the synthetic operational driver");
    assert.equal(fs.existsSync(resultFile), false);
  } else {
    assert.equal(result.status, 0, result.stderr.toString("utf8")); assert.equal(result.stderr.length, 0);
    assert.deepEqual(inventory(sourceRoot), boundFiles, "selected private helper bytes unchanged");
    assert.deepEqual(JSON.parse(fs.readFileSync(resultFile)), { realCaptureEntry: true, versionedGuardAndControlsReached: true, realOperationalCollectorReached: true,
      unknownRegionPreserved: true, externalCalls: 0, syntheticLocalFixture: true, productionAuthority: false });
  }
}

// The real new comparator context must reject missing, legacy-substituted or
// changed new producer bytes before dependency admission/sourceOptions. This
// is a local Git source fixture; it does not fabricate successful controls proof.
function sourceContextFixture(t) {
  const parent=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"b31-region-context-"));
  t.diagnostic("Retained synthetic source-bound controls fixture: "+parent);
  const git=process.env.BUSINESS31_TEST_GIT||(process.platform==="win32"?"C:/Program Files/Git/mingw64/bin/git.exe":"/usr/bin/git");
  const f=require("./business31CaptureFixture.cjs").createCaptureFixture31(parent,git);
  const release=path.join(f.repository,"tools/release"),policyFile=path.join(f.repository,"release/function-fleet-runtime-identity-policy.json");
  fs.mkdirSync(release,{recursive:true});fs.mkdirSync(path.dirname(policyFile),{recursive:true});
  fs.copyFileSync(path.join(__dirname,"business31ScopedCallableInvokerIam.cjs"),path.join(release,"business31ScopedCallableInvokerIam.cjs"),fs.constants.COPYFILE_EXCL);
  fs.writeFileSync(policyFile,JSON.stringify(policy)+"\n",{flag:"wx"});
  const env={};for(const[k,v]of Object.entries(process.env))if(["SYSTEMROOT","WINDIR","COMSPEC","PATH","PATHEXT","TEMP","TMP"].includes(k.toUpperCase()))env[k]=v;
  Object.assign(env,{GIT_CONFIG_NOSYSTEM:"1",GIT_CONFIG_GLOBAL:process.platform==="win32"?"NUL":"/dev/null",GIT_TERMINAL_PROMPT:"0",GIT_OPTIONAL_LOCKS:"0",GIT_NO_LAZY_FETCH:"1",
    GIT_AUTHOR_NAME:"Synthetic controls fixture",GIT_AUTHOR_EMAIL:"fixture@example.invalid",GIT_COMMITTER_NAME:"Synthetic controls fixture",GIT_COMMITTER_EMAIL:"fixture@example.invalid"});
  const command=args=>cp.execFileSync(git,["--no-replace-objects","--no-pager","--no-optional-locks","-c","protocol.allow=never","-c","credential.helper=","-c","core.hooksPath="+path.join(f.repository,".git/disabled-hooks"),"-c","core.autocrlf=false","-c","commit.gpgsign=false","-C",f.repository,...args],
    {env,windowsHide:true,encoding:"utf8",timeout:30000,maxBuffer:1024*1024,stdio:["ignore","pipe","pipe"]}).trim();
  command(["add","--","tools/release/business31ScopedCallableInvokerIam.cjs","release/function-fleet-runtime-identity-policy.json"]);
  command(["commit","--quiet","-m","Synthetic versioned controls source context only"]);
  const sourceCommit=command(["rev-parse","HEAD"]),evidenceDirectory=path.join(parent,"evidence");fs.mkdirSync(evidenceDirectory);
  const raw=data("run.googleapis.com").raw;raw.sourceCommit=sourceCommit;
  const retained=save(path.join(evidenceDirectory,"before.json"),raw),beforePointer={file:retained.file,sha256:retained.sha256};
  return {repository:f.repository,release,sourceCommit,evidenceDirectory,beforePointer};
}
for(const mode of ["missing","legacy-substitution","changed-bytes"])test("new full comparator source context refuses "+mode+" before runtime/control success",t=>{
  const f=sourceContextFixture(t),file="tools/release/business31ScopedCallableInvokerIam.cjs",physical=path.join(f.release,"business31ScopedCallableInvokerIam.cjs");
  const requiredProducerBindings={};
  if(mode==="missing")requiredProducerBindings["tools/release/scopedCallableInvokerIam.js"]="0CCF35EE2AE349377A262CD7079553AA0E3FDA82A4FC738D4B6D32DB74548822";
  else requiredProducerBindings[file]=mode==="legacy-substitution"?"0CCF35EE2AE349377A262CD7079553AA0E3FDA82A4FC738D4B6D32DB74548822":hash(fs.readFileSync(physical));
  if(mode==="changed-bytes")fs.appendFileSync(physical,"\n// unadmitted private fixture alteration\n");
  const input={repoRoot:f.repository,sourceCommit:f.sourceCommit,evidenceDirectory:f.evidenceDirectory,beforePointer:f.beforePointer,requiredProducerBindings,installedControlRuntime:{}};
  assert.throws(()=>controls.verifyPreservedControlsBefore31(input),mode==="missing"?/Source producer binding missing: tools\/release\/business31ScopedCallableInvokerIam\.cjs/:/Executing producer differs: tools\/release\/business31ScopedCallableInvokerIam\.cjs/);
});

for (const service of SERVICES) test("actual CAPTURE entry reaches the new versioned data path " + JSON.stringify(service), t => entryFixture(t, service));
for (const name of ["business31BackendControls.cjs", "business31ScopedCallableInvokerIam.cjs"])
  test("actual CAPTURE entry rejects altered bound " + name, t => entryFixture(t, "run.googleapis.com", name));
