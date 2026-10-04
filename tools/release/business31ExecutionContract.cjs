"use strict";
// Proposed pure decision-covered inputs. No command, network or approval action.
const fs = require("node:fs"), nativePath = require("node:path"), crypto = require("node:crypto");
const {isDeepStrictEqual: same, TextDecoder} = require("node:util");
const access = require("./backendRuntimeEvidenceAccess31.cjs"), path = access.path;
const PROFILE = "build31-exact-business-backend-v1";
const BASELINE = "2aa30de56cfdb960da3eeefd8956d8cbbae57b46";
const CAPTURE = "tools/release/captureBusiness31PreparedInputs.cjs";
const CONTROL_PRODUCERS = Object.freeze(["collectFunctionFleetRuntimeIdentityReadback.js", "collectFunctionsIamDependenciesReadback.js",
  "collectFirestoreRulesIndexesReadback.js", "reviewedBackendControls.js", "collectProductionGlobalPullBackend.js", "scopedCallableInvokerIam.js", "deploymentFleetContract.js"].map(n => "tools/release/" + n));
function need(v, message) { if (!v) throw Error("Business31 execution contract: " + message); }
function keys(v, expected, label) { need(v && typeof v === "object" && !Array.isArray(v) && same(Object.keys(v).sort(), [...expected].sort()), label + " fields differ"); }
const sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const hex = (v, size) => typeof v === "string" && new RegExp("^[0-9a-f]{" + size + "}$", "i").test(v);
function json(bytes) { let value; try { value = JSON.parse(new TextDecoder("utf-8", {fatal:true}).decode(bytes)); } catch { throw Error("Business31 execution contract: invalid private JSON"); }
  need(value && typeof value === "object" && !Array.isArray(value), "private JSON object required");
  const pending=[[value,0]];let count=0;while(pending.length){const [item,depth]=pending.pop();need(++count<=100000&&depth<=40,"private JSON bound exceeded");if(item&&typeof item==="object")for(const child of Object.values(item))pending.push([child,depth+1]);} return value; }
function pointer(v) { keys(v, ["file", "sha256", "bytes"], "pointer"); need(typeof v.file === "string" && v.file.length<=400 && /^[A-Za-z0-9_@+.~/-]+$/.test(v.file) &&
  !v.file.startsWith("/") && v.file.split("/").every(p => p && p !== "." && p !== ".." && !/[. ]$/.test(p) && !/^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(p)), "unsafe pointer");
  need(hex(v.sha256, 64) && Number.isSafeInteger(v.bytes) && v.bytes >= 0 && v.bytes <= 64 * 1024 * 1024, "pointer bound differs"); return v; }
function physical(original, directory = false) {
  need(path.isAbsolute(original), "absolute original required");
  const mapped = access.resolveOriginal(original), full = nativePath.resolve(mapped);
  let current = nativePath.parse(full).root;
  for (const part of full.slice(current.length).split(nativePath.sep).filter(Boolean)) { current = nativePath.join(current, part); need(!fs.lstatSync(current).isSymbolicLink(), "redirected original"); }
  const stat = fs.lstatSync(full); need(directory ? stat.isDirectory() : stat.isFile(), "regular original required");
  if (!directory && access.current()?.relocation) need(access.current().validateFile(original) === full, "unbound physical member");
  return full;
}
function originalBytes(original) { return fs.readFileSync(physical(original)); }
function privateBytes(root, p) { pointer(p); const full = physical(path.join(root, p.file)); const before = fs.statSync(full, {bigint:true});
  need(before.size===BigInt(p.bytes), "private original bytes changed");
  const bytes = fs.readFileSync(full), after = fs.statSync(full, {bigint:true});
  need(before.ino === after.ino && before.size === after.size && before.mtimeNs === after.mtimeNs && before.ctimeNs === after.ctimeNs &&
    bytes.length === p.bytes && sha(bytes) === p.sha256.toUpperCase(), "private original bytes changed"); return bytes; }
function pointerView(root, p) { privateBytes(root, p); return {file:p.file, sha256:p.sha256}; }
function cohortsFromPolicy(policy) {
  need(policy.productionProjectId === "crm3-baf-ops-b8638", "fleet project differs");
  const out = {callables:[], events:[], schedulers:[], fleet:Object.keys(policy.functionBindings).sort()};
  for (const [name, row] of Object.entries(policy.functionBindings)) { need(/^[A-Za-z][A-Za-z0-9_]*$/.test(name), "unsafe function");
    if (row.workloadClass.includes("CALLABLE")) out.callables.push(name);
    else if (["FIRESTORE_NOTIFICATION_TRIGGER", "FIRESTORE_PROTOCOL_TRIGGER"].includes(row.workloadClass)) out.events.push(name);
    else { need(row.workloadClass === "SCHEDULED_FIRESTORE_MUTATION", "unknown workload"); out.schedulers.push(name); } }
  Object.values(out).forEach(v => v.sort()); need(same([out.callables.length,out.events.length,out.schedulers.length,out.fleet.length],[13,5,1,19]), "exact19 fleet required"); return out;
}
function verifyExecutionContract31({contract, decision, proof, source, baseline, manifestSha256, ownerReceivedAtUtc, read, instant, mergeParents, release, security}) {
  keys(contract,["schemaVersion","documentType","profile","source","baseline","sourceManifestSha256","runtimeProof","preparedAtUtc","intendedHashInputs","githubObserver","settledSourceReview"],"execution contract");
  need(contract.schemaVersion === 1 && contract.documentType === "build31-business-execution-contract" && contract.profile === PROFILE &&
    same(contract.source,source) && baseline.commit === BASELINE && source.commit !== BASELINE && same(contract.baseline,baseline) &&
    contract.sourceManifestSha256 === manifestSha256 && same(contract.runtimeProof,decision.runtimeProof), "execution source/baseline/runtime differs");
  need(instant(proof.completedAtUtc) <= instant(contract.preparedAtUtc) && instant(contract.preparedAtUtc) <= instant(ownerReceivedAtUtc) &&
    instant(ownerReceivedAtUtc) <= instant(decision.decidedAtUtc), "execution contract postdates consent");
  pointer(contract.intendedHashInputs); keys(contract.githubObserver,["path","sha256"],"observer");
  need(path.isAbsolute(contract.githubObserver.path) && hex(contract.githubObserver.sha256,64) && sha(originalBytes(contract.githubObserver.path)) === contract.githubObserver.sha256, "observer bytes differ");
  const selected = contract.settledSourceReview;
  keys(selected,["kind","reviewer","headCommit","request","response","summary"],"settled review");
  need(selected.kind === "bot-issue-comment-no-findings" && selected.reviewer === "chatgpt-codex-connector[bot]" &&
    mergeParents.length === 2 && selected.headCommit === mergeParents[1] && release.pullRequest.head.sha === selected.headCommit && security.pullRequest.head.sha === selected.headCommit, "settled source review differs");
  const legacy = {kind:selected.kind,reviewer:selected.reviewer,headCommit:selected.headCommit}; const originals = {};
  for (const name of ["request","response","summary"]) { const item = selected[name]; if (name === "summary" && item === null) continue;
    keys(item,["id","bodySha256","original"],"review pointer"); pointer(item.original); const value = json(read(item.original));
    need(Number.isSafeInteger(item.id) && item.id > 0 && value.id === item.id && typeof value.body === "string" && sha(Buffer.from(value.body)) === item.bodySha256, "review original differs");
    need(instant(value.created_at) <= instant(contract.preparedAtUtc), "review postdates prepared contract"); legacy[name] = {id:item.id,bodySha256:item.bodySha256}; originals[name] = value;
  }
  const approval = {decidedAtUtc:decision.decidedAtUtc,normalMergeParents:[...mergeParents],mainCiRun:{id:release.run.id,runAttempt:release.run.run_attempt},
    securityCiRun:{id:security.run.id,runAttempt:security.run.run_attempt},settledSourceReview:legacy};
  return {approval,reviewOriginals:originals,intendedHashInputs:contract.intendedHashInputs,githubObserver:contract.githubObserver};
}
function deriveRuntime31({proof, executionContract, evidenceDirectory, read, repository, source, producerBindings}) {
  const cli = json(read(proof.installedFiles.cli)), functions = json(read(proof.installedFiles.functions));
  const requireMember = (map, file) => { need(hex(map[file],64), "mandatory installed runtime member missing: " + file); return map[file]; };
  const controls = Object.fromEntries(Object.entries(functions).map(([file,digest]) => ["functions/node_modules/" + file,digest]));
  for (const file of ["typescript/package.json","typescript/lib/typescript.js","firebase-functions/package.json","firebase-functions/lib/runtime/manifest.js"]) requireMember(functions,file);
  const endpoints = Object.fromEntries(Object.entries({apply:"deploy/functions/cache/applyHash.js",hash:"deploy/functions/cache/hash.js",secrets:"functions/secrets.js"}).map(([name,file]) => [name,requireMember(cli,"firebase-tools/lib/"+file)]));
  const packaging = Object.fromEntries(Object.entries({prepare:"deploy/functions/prepareFunctionsUpload.js",enumerator:"fsAsync.js"}).map(([name,file]) => [name,requireMember(cli,"firebase-tools/lib/"+file)]));
  const requiredProducerBindings = {};
  for (const file of [...CONTROL_PRODUCERS,CAPTURE]) { const digest = producerBindings[file]; need(hex(digest,64) && sha(repository.readBlob(source.commit,file)) === digest, "source producer missing/changed: " + file); requiredProducerBindings[file] = digest; }
  const cliPointer = proof.installedFiles.cli;
  return {nodeExecutable:proof.runtime.nodeExecutable.path,nodeSha256:proof.runtime.nodeExecutable.sha256,cliEntrypoint:proof.runtime.cliEntrypoint.path,
    githubExecutable:executionContract.githubObserver.path,githubExecutableSha256:executionContract.githubObserver.sha256,
    endpointHashProducerSha256:endpoints,packagingProducerSha256:packaging,cliFileBindings:{path:path.join(evidenceDirectory,cliPointer.file),sha256:cliPointer.sha256},
    installedControlRuntime:controls,requiredProducerBindings, instrumentationProducerSha256:Object.fromEntries(Object.entries({api:"apiv2.js",apply:"deploy/functions/cache/applyHash.js",prepare:"deploy/functions/prepare.js",backend:"deploy/functions/backend.js"}).map(([name,file]) => [name,requireMember(cli,"firebase-tools/lib/"+file)]))};
}
module.exports = {PROFILE,BASELINE,CAPTURE,CONTROL_PRODUCERS,keys,need,sha,json,pointer,physical,originalBytes,privateBytes,pointerView,cohortsFromPolicy,verifyExecutionContract31,deriveRuntime31};
