"use strict";
// Decision-covered inputs and fixed read-only review observation. No deployment or approval action.
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
// The legacy kind delegates to the immutable Codex verifier without rewriting records.
// Claude is a separate, closed issue-comment protocol, not a configurable bot allowlist.
const CLAUDE_REVIEW_KIND = "claude-issue-comment-no-findings-v1";
const REVIEW_REPOSITORY = "abhishekvatsa/crm3_baf_ops";
function reviewProvider31(selected) {
  if (selected?.kind === "bot-issue-comment-no-findings" && selected.reviewer === "chatgpt-codex-connector[bot]") return "codex";
  need(selected?.kind === CLAUDE_REVIEW_KIND && selected.reviewer === "claude[bot]", "unsupported settled source review provider");
  need(selected.summary === null, "Claude v1 requires summary:null");
  return "claude";
}
function claudeIdentity31(value) {
  const app = value?.performed_via_github_app;
  need(value?.user?.login === "claude[bot]" && value.user.type === "Bot" &&
    app?.id === 1236702 && app.slug === "claude", "official Claude app identity required");
  if (Object.hasOwn(app,"owner")) need(app.owner?.login === "anthropics" && app.owner.id === 76263028,
    "official Claude app owner differs");
}
function claudeReviewedPrefix31(value) {
  need(typeof value?.body === "string", "original Claude response body required");
  const lines = value.body.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  need(lines.length === 2 && /^(?:No findings\.?|No major issues\.?|I didn['\u2019]t find any major issues\.?)$/i.test(lines[0]),
    "standalone Claude no-findings result required");
  const marker = /^\*\*Reviewed commit:\*\*\s*`([0-9a-f]{7,40})`$/i.exec(lines[1]);
  need(marker, "exact unique Claude reviewed-commit marker required");
  return marker[1].toLowerCase();
}
function verifyClaudeChain31({selected,pr,review,reviewRequest,reviewSummary,latestUtc}) {
  const {time} = require("./backendRuntimeAdmission31.cjs").helpers;
  need(reviewProvider31(selected) === "claude", "Claude chain required");
  need(reviewSummary === null || reviewSummary === undefined, "Claude v1 cannot carry a summary");
  keys(selected,["kind","reviewer","headCommit","request","response","summary"],"Claude settled review");
  need(/^[0-9a-f]{40}$/.test(selected.headCommit) && selected.headCommit === pr.head?.sha &&
    Number.isSafeInteger(pr.number) && pr.number > 0, "Claude exact PR head differs");
  const ids = new Set();
  for (const [name,value] of [["request",reviewRequest],["response",review]]) {
    const p = selected[name]; keys(p,["id","bodySha256"],"Claude review pointer");
    need(Number.isSafeInteger(p.id) && p.id > 0 && !ids.has(p.id) && value?.id === p.id &&
      typeof value.body === "string" && /^[A-F0-9]{64}$/.test(p.bodySha256) && sha(Buffer.from(value.body)) === p.bodySha256,
      "actual Claude review chain differs: " + name); ids.add(p.id);
    need(value.issue_url === `https://api.github.com/repos/${REVIEW_REPOSITORY}/issues/${pr.number}`, "Claude review belongs to a different PR");
    need(time(value.created_at) <= time(value.updated_at) && time(value.updated_at) <= time(latestUtc),
      "Claude review update/post-decision chronology differs");
  }
  claudeIdentity31(review);
  need(time(reviewRequest.updated_at) <= time(review.created_at), "Claude response predates exact-head request");
  need(new RegExp("(^|[^0-9a-f])" + selected.headCommit + "([^0-9a-f]|$)","i").test(reviewRequest.body),
    "actual full-head Claude request required");
  const prefix = claudeReviewedPrefix31(review);
  need(selected.headCommit.startsWith(prefix), "Claude reviewed marker differs from selected head");
  return prefix;
}
function verifyBusinessLiveGitHubRecords31(input) {
  const gate = require("./backendRuntimeExecutionAdmission31.cjs");
  if (reviewProvider31(input.approval?.settledSourceReview) === "codex") return gate.verifyLiveGitHubRecords31(input);
  const a = require("./backendRuntimeAdmission31.cjs"), {time} = a.helpers;
  const {source,approval,release,security,mainRef,pr,review,reviewRequest,reviewSummary,reviewedHeadCommit,reviews,threads,nowUtc} = input;
  need(mainRef.object?.sha === source.commit && mainRef.ref === "refs/heads/main", "live main advanced or differs");
  const parents = approval.normalMergeParents;
  need(Array.isArray(parents) && parents.length === 2 && pr.head?.sha === parents[1] &&
    pr.merge_commit_sha === source.commit && pr.merged === true, "live normal source PR differs");
  for (const [kind,capture] of [["release",release],["security",security]]) {
    a.verifyCi31(capture,source,kind,nowUtc);
    const original = approval[kind === "release" ? "mainCiRun" : "securityCiRun"];
    need(original?.id === capture.run.id && original?.runAttempt === capture.run.run_attempt, "live CI run/attempt differs from approved successful run");
  }
  need(time(approval.reviewPreparedAtUtc) <= time(approval.decidedAtUtc) && time(approval.decidedAtUtc) <= time(nowUtc), "Claude contract/decision/observation chronology differs");
  verifyClaudeChain31({selected:approval.settledSourceReview,pr,review,reviewRequest,reviewSummary,latestUtc:approval.reviewPreparedAtUtc});
  need(reviewedHeadCommit === pr.head.sha, "uniquely resolved Claude reviewed commit differs");
  need(reviews?.pageInfo?.hasNextPage === false && Array.isArray(reviews.nodes), "complete review-state population required");
  const latest = new Map();
  for (const r of reviews.nodes) { need(r.author?.login && r.submittedAt, "review identity/time absent");
    const old = latest.get(r.author.login);
    need(!old || time(old.submittedAt) !== time(r.submittedAt) || old.state === r.state, "conflicting equal-time review states");
    if (!old || time(old.submittedAt) < time(r.submittedAt)) latest.set(r.author.login,r); }
  need([...latest.values()].every(r => r.state !== "CHANGES_REQUESTED"), "outstanding latest changes-requested review");
  need(threads?.pageInfo?.hasNextPage === false && Array.isArray(threads.nodes) && threads.nodes.every(t => t.isResolved === true),
    "every actual review thread must be resolved");
  return true;
}
function observeBusinessLiveGitHub31(admission,approval,nowUtc) {
  const gate = require("./backendRuntimeExecutionAdmission31.cjs");
  if (reviewProvider31(approval?.settledSourceReview) === "codex") return gate.observeLiveGitHub31(admission,approval,nowUtc);
  const a = require("./backendRuntimeAdmission31.cjs"), r = admission.runtime, n = admission.mainCi.pullRequestNumber;
  need(Number.isSafeInteger(n) && n > 0, "exact review PR number required");
  const get = endpoint => gate.githubRead31(r,endpoint);
  const main = get(`repos/${REVIEW_REPOSITORY}/git/ref/heads/main`), pr = get(`repos/${REVIEW_REPOSITORY}/pulls/${n}`);
  const capture = kind => {
    const p = approval[kind === "release" ? "mainCiRun" : "securityCiRun"];
    need(Number.isSafeInteger(p?.id) && p.id > 0 && Number.isSafeInteger(p.runAttempt) && p.runAttempt > 0, "exact main CI run pointer required");
    const run = get(`repos/${REVIEW_REPOSITORY}/actions/runs/${p.id}`);
    const jobs = get(`repos/${REVIEW_REPOSITORY}/actions/runs/${p.id}/attempts/${p.runAttempt}/jobs?per_page=100`);
    return {raw:{run:run.raw,jobs:jobs.raw},value:{schemaVersion:1,evidenceType:kind === "release" ? "github-exact-main-release-gate" : "github-exact-main-codeql",
      repository:REVIEW_REPOSITORY,sourceCommit:admission.source.commit,sourceTree:admission.source.tree,capturedAtUtc:nowUtc,pullRequest:pr.value,run:run.value,jobs:jobs.value}};
  };
  const release = capture("release"), security = capture("security"), chain = approval.settledSourceReview;
  const comment = p => { need(Number.isSafeInteger(p?.id) && p.id > 0, "exact review comment pointer required");
    return get(`repos/${REVIEW_REPOSITORY}/issues/comments/${p.id}`); };
  const review = comment(chain.response), request = comment(chain.request), summary = chain.summary === null ? null : comment(chain.summary);
  const prefix = verifyClaudeChain31({selected:chain,pr:pr.value,review:review.value,reviewRequest:request.value,reviewSummary:summary?.value,latestUtc:approval.reviewPreparedAtUtc});
  const reviewedHeadCommit = a.helpers.gtext(admission.repoRoot,["rev-parse","--verify",prefix + "^{commit}"]);
  const query = `query { repository(owner:"abhishekvatsa", name:"crm3_baf_ops") { pullRequest(number:${n}) { reviews(first:100) { nodes { state submittedAt author { login } commit { oid } } pageInfo { hasNextPage } } reviewThreads(first:100) { nodes { isResolved } pageInfo { hasNextPage } } } } }`;
  const threads = gate.githubRead31(r,"graphql","POST",["-f","query=" + query]);
  const finalMain = get(`repos/${REVIEW_REPOSITORY}/git/ref/heads/main`), completedAtUtc = new Date().toISOString();
  release.value.capturedAtUtc = completedAtUtc; security.value.capturedAtUtc = completedAtUtc;
  verifyBusinessLiveGitHubRecords31({source:admission.source,approval,release:release.value,security:security.value,mainRef:finalMain.value,pr:pr.value,
    review:review.value,reviewRequest:request.value,reviewSummary:summary?.value,reviewedHeadCommit,
    reviews:threads.value.data?.repository?.pullRequest?.reviews,threads:threads.value.data?.repository?.pullRequest?.reviewThreads,nowUtc:completedAtUtc});
  need(main.value.object?.sha === admission.source.commit, "live main differed at observation start");
  const raw = v => Buffer.isBuffer(v) ? v.toString("utf8") : Object.fromEntries(Object.entries(v).map(([k,b]) => [k,b.toString("utf8")]));
  return {observer:a.verifyGithubObserverRuntime31(r),observedAtUtc:nowUtc,completedAtUtc,main:raw(main.raw),finalMain:raw(finalMain.raw),pr:raw(pr.raw),
    release:raw(release.raw),security:raw(security.raw),review:raw(review.raw),reviewRequest:raw(request.raw),reviewSummary:summary ? raw(summary.raw) : null,threads:raw(threads.raw)};
}
function verifyPreservedBusinessLiveGitHub31(record,admission,approval) {
  const gate = require("./backendRuntimeExecutionAdmission31.cjs");
  if (reviewProvider31(approval?.settledSourceReview) === "codex") return gate.verifyPreservedLiveGitHub31(record,admission,approval);
  const a = require("./backendRuntimeAdmission31.cjs"), {time} = a.helpers;
  need(same(record.observer,{executable:admission.runtime.githubExecutable,sha256:admission.runtime.githubExecutableSha256}), "original GitHub observer binding differs");
  const parse = value => { need(typeof value === "string", "original GitHub response text required"); return json(Buffer.from(value)); };
  need(time(record.observedAtUtc) <= time(record.completedAtUtc), "live observation interval differs");
  need(record.reviewSummary === null, "Claude v1 requires a null original summary");
  const pr = parse(record.pr), review = parse(record.review), request = parse(record.reviewRequest), summary = record.reviewSummary === null ? null : parse(record.reviewSummary), threads = parse(record.threads);
  const prefix = verifyClaudeChain31({selected:approval.settledSourceReview,pr,review,reviewRequest:request,reviewSummary:summary,latestUtc:approval.reviewPreparedAtUtc});
  const capture = kind => ({schemaVersion:1,evidenceType:kind === "release" ? "github-exact-main-release-gate" : "github-exact-main-codeql",
    repository:REVIEW_REPOSITORY,sourceCommit:admission.source.commit,sourceTree:admission.source.tree,capturedAtUtc:record.completedAtUtc,
    pullRequest:pr,run:parse(record[kind].run),jobs:parse(record[kind].jobs)});
  need(parse(record.main).object?.sha === admission.source.commit, "original live main changed during admission");
  return verifyBusinessLiveGitHubRecords31({source:admission.source,approval,release:capture("release"),security:capture("security"),mainRef:parse(record.finalMain),pr,
    review,reviewRequest:request,reviewSummary:summary,reviewedHeadCommit:a.helpers.gtext(admission.repoRoot,["rev-parse","--verify",prefix + "^{commit}"]),
    reviews:threads.data?.repository?.pullRequest?.reviews,threads:threads.data?.repository?.pullRequest?.reviewThreads,nowUtc:record.completedAtUtc});
}

function verifyExecutionContract31({contract, decision, proof, source, baseline, manifestSha256, ownerReceivedAtUtc, read, instant, mergeParents, release, security, repository, snapshot, evidenceDirectory}) {
  keys(contract,["schemaVersion","documentType","profile","source","baseline","sourceManifestSha256","runtimeProof","preparedAtUtc","intendedHashInputs","githubObserver","settledSourceReview",...(contract.schemaVersion===2?["intentPreparation"]:[])],"execution contract");
  need([1,2].includes(contract.schemaVersion) && contract.documentType === "build31-business-execution-contract" && contract.profile === PROFILE &&
    same(contract.source,source) && baseline.commit === BASELINE && source.commit !== BASELINE && same(contract.baseline,baseline) &&
    contract.sourceManifestSha256 === manifestSha256 && same(contract.runtimeProof,decision.runtimeProof), "execution source/baseline/runtime differs");
  need(instant(proof.completedAtUtc) <= instant(contract.preparedAtUtc) && instant(contract.preparedAtUtc) <= instant(ownerReceivedAtUtc) &&
    instant(ownerReceivedAtUtc) <= instant(decision.decidedAtUtc), "execution contract postdates consent");
  pointer(contract.intendedHashInputs); keys(contract.githubObserver,["path","sha256"],"observer");
  if(contract.schemaVersion===2) {
    pointer(contract.intentPreparation);
    require("./business31IntentPreparation.cjs").verifyIntentPreparation31({contract,proof,source,read,instant,repository,snapshot,evidenceDirectory,ownerReceivedAtUtc});
  }
  need(path.isAbsolute(contract.githubObserver.path) && hex(contract.githubObserver.sha256,64) && sha(originalBytes(contract.githubObserver.path)) === contract.githubObserver.sha256, "observer bytes differ");
  const selected = contract.settledSourceReview;
  keys(selected,["kind","reviewer","headCommit","request","response","summary"],"settled review");
  const provider = reviewProvider31(selected);
  need(    mergeParents.length === 2 && selected.headCommit === mergeParents[1] && release.pullRequest.head.sha === selected.headCommit && security.pullRequest.head.sha === selected.headCommit, "settled source review differs");
  const legacy = {kind:selected.kind,reviewer:selected.reviewer,headCommit:selected.headCommit,...(provider === "claude" ? {summary:null} : {})}; const originals = {};
  for (const name of ["request","response","summary"]) { const item = selected[name]; if (name === "summary" && item === null) continue;
    keys(item,["id","bodySha256","original"],"review pointer"); pointer(item.original); const value = json(read(item.original));
    need(Number.isSafeInteger(item.id) && item.id > 0 && value.id === item.id && typeof value.body === "string" && sha(Buffer.from(value.body)) === item.bodySha256, "review original differs");
    need(instant(value.created_at) <= instant(contract.preparedAtUtc), "review postdates prepared contract"); legacy[name] = {id:item.id,bodySha256:item.bodySha256}; originals[name] = value;
  }
  const approval = {decidedAtUtc:decision.decidedAtUtc,normalMergeParents:[...mergeParents],mainCiRun:{id:release.run.id,runAttempt:release.run.run_attempt},
    securityCiRun:{id:security.run.id,runAttempt:security.run.run_attempt},settledSourceReview:legacy};
  if (provider === "claude") {
    // This binds retained semantics only. The fixed observer/replay resolves the marker in actual Git.
    approval.reviewPreparedAtUtc = contract.preparedAtUtc;
    verifyClaudeChain31({selected:legacy,pr:release.pullRequest,review:originals.response,reviewRequest:originals.request,
      reviewSummary:originals.summary,latestUtc:contract.preparedAtUtc});
  }
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
module.exports = {CLAUDE_REVIEW_KIND,verifyBusinessLiveGitHubRecords31,observeBusinessLiveGitHub31,verifyPreservedBusinessLiveGitHub31,PROFILE,BASELINE,CAPTURE,CONTROL_PRODUCERS,keys,need,sha,json,pointer,physical,originalBytes,privateBytes,pointerView,cohortsFromPolicy,verifyExecutionContract31,deriveRuntime31};
