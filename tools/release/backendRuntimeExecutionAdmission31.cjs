'use strict';
// Future execution gate. Writing this code is not a deployment authorization.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const a = require('./backendRuntimeAdmission31.cjs');
const {need, eq, hash, time, committed, child, fileBinding, object, gtext} = a.helpers;
const REPOSITORY = 'abhishekvatsa/crm3_baf_ops';
const OWNER_ACTION = 'deploy-existing-19-functions-with-reviewed-grpc-runtime';
const REVIEWER = 'chatgpt-codex-connector[bot]';
const TRUSTED_MESSAGE_TYPE = 'direct-human-exact-source-production-deployment-instruction';

function rejectSynthetic(value) {
  const walk = x => {
    if (!x || typeof x !== 'object') return;
    for (const [k, v] of Object.entries(x)) {
      if (/testFixtureOnly|syntheticFixture|noRealAuthority|notActualExecution|notActualPreparationCapture/.test(k)) need(v === false, 'Synthetic evidence cannot authorize execution');
      walk(v);
    }
  };
  walk(value);
}

function ownerInstruction(source) {
  return `Deploy the reviewed gRPC runtime repair from ${source.commit} to the existing 19 Functions in crm3-baf-ops-b8638 / asia-south1. No Rules, indexes, IAM, App Check enforcement, business logic or manual scheduler changes are authorized.`;
}

function verifyExplicitDeploymentOwner31({approval, owner, originalMessage, source}) {
  rejectSynthetic(approval); rejectSynthetic(owner); rejectSynthetic(originalMessage);
  need(owner.schemaVersion === 2 && owner.authorizationType === 'direct-human-production-deployment' && owner.deploymentAction === OWNER_ACTION, 'Separate direct production-deployment consent required');
  eq(owner.source, source, 'Exact owner-approved source required');
  eq(owner.scope, a.SCOPE, 'Owner scope differs');
  need(owner.actualProductionDeploymentAuthorized === true && owner.codePreparationOnly === false, 'Code preparation is not production authorization');
  need(originalMessage.evidenceType === TRUSTED_MESSAGE_TYPE && originalMessage.actorKind === 'human-owner' && typeof originalMessage.conversationId === 'string' && originalMessage.conversationId.length > 8 && typeof originalMessage.messageId === 'string' && originalMessage.messageId.length > 8, 'Original trusted owner message reference required');
  need(originalMessage.exactQuestion===ownerInstruction(source)&&['Yes\u2014deploy this exact reviewed source','Yes, deploy this exact reviewed source',ownerInstruction(source)].includes(originalMessage.exactText)&&owner.ownerInstruction===originalMessage.exactText,'Owner approval must answer the exact source/action question');
  need(originalMessage.provenanceBasis==='operator-retained-direct-human-message'&&originalMessage.machineAuthenticatedHuman===false&&typeof originalMessage.recordedBy==='string'&&originalMessage.recordedBy.length>0,'Disclose operator-attested provenance; JSON cannot authenticate a human');
  eq(originalMessage.source, source, 'Original owner message source differs');
  need(originalMessage.actualProductionDeploymentAuthorized === true && originalMessage.codePreparationOnly === false, 'Preparation-only message rejected');
  need(['platform-message-timestamp','first-receipt-observation'].includes(originalMessage.receiptTimeBasis)&&owner.authorizedAtUtc===originalMessage.receivedAtUtc,'Owner authorization must bind the original receipt time and disclose its basis');
  need(time(originalMessage.receivedAtUtc) <= time(owner.recordedAtUtc) && time(owner.recordedAtUtc) <= time(approval.decidedAtUtc), 'Original owner receipt chronology differs');
  return true;
}

function cleanEnvironment31(input = process.env) {
  // Keep authenticated account storage, never arbitrary emulator/CLI overrides.
  const allowed = new Set(['SystemRoot', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP', 'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'PATH', 'PATHEXT', 'LANG', 'LC_ALL']);
  const blocked = /^(NODE_OPTIONS|NODE_PATH|NODE_EXTRA_CA_CERTS|NODE_TLS_REJECT_UNAUTHORIZED|SSL_CERT_FILE|SSL_CERT_DIR|FIREBASE_TOKEN|FIREBASE_CONFIG|GOOGLE_APPLICATION_CREDENTIALS|GOOGLE_CLOUD_PROJECT|GCLOUD_PROJECT|CLOUDSDK_CORE_PROJECT|.*_EMULATOR_HOST|FIREBASE_AUTH_EMULATOR_HOST|FIREBASE_EMULATOR_HUB|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|npm_config_.*|NPM_CONFIG_.*)$/i;
  for (const [k,v] of Object.entries(input)) if (blocked.test(k)) need(v === undefined || v === '', 'Unreviewed process environment override: ' + k);
  const out = {};
  for (const [k,v] of Object.entries(input)) if (allowed.has(k) && typeof v === 'string') out[k] = v;
  out.CI = 'true'; out.FIREBASE_CLI_DISABLE_UPDATE_CHECK = 'true';
  return out;
}

function githubRead31(runtime, endpoint, method = 'GET', fields = []) {
  need(path.isAbsolute(runtime.githubExecutable) && /^[A-F0-9]{64}$/.test(runtime.githubExecutableSha256), 'Pinned GitHub CLI required');
  need(hash(fs.readFileSync(fs.realpathSync(runtime.githubExecutable))) === runtime.githubExecutableSha256, 'GitHub CLI bytes differ');
  need(method === 'GET' || (method === 'POST' && endpoint === 'graphql'), 'Read-only GitHub operation required');
  need(endpoint === 'graphql' || endpoint.startsWith('repos/' + REPOSITORY + '/'), 'Fixed repository only');
  const raw = execFileSync(runtime.githubExecutable, ['api', '--hostname', 'github.com', '--method', method, endpoint, ...fields], {env:cleanEnvironment31(), windowsHide:true, maxBuffer:16*1024*1024, timeout:60000, stdio:['ignore','pipe','pipe']});
  return {raw, value:object(raw)};
}

function verifyLiveGitHubRecords31({source, approval, release, security, mainRef, pr, review, reviewRequest, reviewSummary, reviewedHeadCommit, reviews, threads, nowUtc}) {
  need(mainRef.object?.sha === source.commit && mainRef.ref === 'refs/heads/main', 'Live main advanced or differs');
  const parents = approval.normalMergeParents;
  need(Array.isArray(parents) && parents.length === 2 && pr.head?.sha === parents[1]  && pr.merge_commit_sha === source.commit && pr.merged === true, 'Live normal source PR differs');
  for (const [kind, capture] of [['release',release],['security',security]]) {
    a.verifyCi31(capture, source, kind, nowUtc);
    const original = approval[kind === 'release' ? 'mainCiRun' : 'securityCiRun'];
    need(original?.id === capture.run.id && original?.runAttempt === capture.run.run_attempt, 'Live CI run/attempt differs from approved successful run');
  }
  const selected = approval.settledSourceReview;
  need(selected?.kind==='bot-issue-comment-no-findings'&&selected.reviewer===REVIEWER&&selected.headCommit===pr.head.sha,'Exact settled bot comment chain required');
  for(const [key,value]of [['response',review],['request',reviewRequest],...(selected.summary?[['summary',reviewSummary]]:[])]){
    const pointer=selected[key];need(Number.isSafeInteger(pointer?.id)&&pointer.id>0&&value.id===pointer.id&&typeof value.body==='string'&&hash(Buffer.from(value.body))===pointer.bodySha256,'Actual review chain differs: '+key);
    need(value.issue_url===`https://api.github.com/repos/${REPOSITORY}/issues/${pr.number}`,'Review comment belongs to a different PR');
    need(time(value.created_at)<=time(approval.decidedAtUtc),'Review chain postdates decision');
  }
  need(review.user?.login===REVIEWER&&review.performed_via_github_app?.slug==='chatgpt-codex-connector'&&(!selected.summary||reviewSummary.user?.login===REVIEWER),'Expected actual bot identity required');
  need(reviewRequest.body.includes(pr.head.sha)&&reviewedHeadCommit===pr.head.sha,'Actual full request and uniquely resolved reviewed commit must bind exact head');
  need(time(reviewRequest.created_at)<=time(review.created_at)&&(!selected.summary||time(reviewRequest.created_at)<=time(reviewSummary.updated_at)&&time(reviewSummary.updated_at)<=time(approval.decidedAtUtc)),'Bot response predates exact-head request');
  need(/no major issues|didn['’]t find any major issues|no findings/i.test(review.body)&&!/usage.{0,40}(limit|allowance)|credits|quota|review.{0,30}not.{0,10}(performed|complete)/i.test(review.body),'Positive no-findings result required, not arbitrary COMMENTED');
  need(reviews?.pageInfo?.hasNextPage===false&&Array.isArray(reviews.nodes),'Complete review-state population required');
  const latest=new Map();for(const r of reviews.nodes){need(r.author?.login&&r.submittedAt,'Review identity/time absent');const old=latest.get(r.author.login);if(!old||time(old.submittedAt)<time(r.submittedAt))latest.set(r.author.login,r);}
  need([...latest.values()].every(r=>r.state!=='CHANGES_REQUESTED'),'Outstanding latest changes-requested review');
  need(threads.pageInfo?.hasNextPage === false && Array.isArray(threads.nodes) && threads.nodes.every(t => t.isResolved === true), 'Every actual review thread must be resolved');
  return true;
}

function observeLiveGitHub31(admission, approval, nowUtc) {
  const r = admission.runtime, n = admission.mainCi.pullRequestNumber;
  const main = githubRead31(r, `repos/${REPOSITORY}/git/ref/heads/main`);
  const pr = githubRead31(r, `repos/${REPOSITORY}/pulls/${n}`);
  const capture = kind => {
    const p = approval[kind === 'release' ? 'mainCiRun' : 'securityCiRun'];
    need(Number.isSafeInteger(p?.id) && p.id > 0, 'Exact main CI run pointer required');
    const run = githubRead31(r, `repos/${REPOSITORY}/actions/runs/${p.id}`);
    const jobs = githubRead31(r, `repos/${REPOSITORY}/actions/runs/${p.id}/attempts/${p.runAttempt}/jobs?per_page=100`);
    return {raw:{run:run.raw,jobs:jobs.raw}, value:{schemaVersion:1,evidenceType:kind === 'release'?'github-exact-main-release-gate':'github-exact-main-codeql',repository:REPOSITORY,sourceCommit:admission.source.commit,sourceTree:admission.source.tree,capturedAtUtc:nowUtc,pullRequest:pr.value,run:run.value,jobs:jobs.value}};
  };
  const release=capture('release'),security=capture('security');
  const chain=approval.settledSourceReview;const readComment=pointer=>{need(Number.isSafeInteger(pointer?.id)&&pointer.id>0,'Exact review comment pointer required');return githubRead31(r,`repos/${REPOSITORY}/issues/comments/${pointer.id}`);};const review=readComment(chain.response),reviewRequest=readComment(chain.request),reviewSummary=chain.summary?readComment(chain.summary):null;const abbreviated=/\*\*Reviewed commit:\*\*\s*`([0-9a-f]{7,40})`/i.exec(review.value.body??'')?.[1];need(abbreviated,'Actual bot reviewed-commit marker required');const reviewedHeadCommit=gtext(admission.repoRoot,['rev-parse','--verify',abbreviated+'^{commit}']);
  const query=`query { repository(owner:"abhishekvatsa", name:"crm3_baf_ops") { pullRequest(number:${n}) { reviews(first:100) { nodes { state submittedAt author { login } commit { oid } } pageInfo { hasNextPage } } reviewThreads(first:100) { nodes { isResolved } pageInfo { hasNextPage } } } } }`;
  const threads=githubRead31(r,'graphql','POST',['-f','query='+query]);
  const finalMain=githubRead31(r,`repos/${REPOSITORY}/git/ref/heads/main`),completedAtUtc=new Date().toISOString();release.value.capturedAtUtc=completedAtUtc;security.value.capturedAtUtc=completedAtUtc;verifyLiveGitHubRecords31({source:admission.source,approval,release:release.value,security:security.value,mainRef:finalMain.value,pr:pr.value,review:review.value,reviewRequest:reviewRequest.value,reviewSummary:reviewSummary?.value,reviewedHeadCommit,reviews:threads.value.data?.repository?.pullRequest?.reviews,threads:threads.value.data?.repository?.pullRequest?.reviewThreads,nowUtc:completedAtUtc});
  need(main.value.object?.sha===admission.source.commit,'Live main differed at observation start');
  const stringifyRaw=v=>Buffer.isBuffer(v)?v.toString('utf8'):Object.fromEntries(Object.entries(v).map(([k,b])=>[k,b.toString('utf8')]));
  return {observer:a.verifyGithubObserverRuntime31(r),observedAtUtc:nowUtc,completedAtUtc,main:stringifyRaw(main.raw),finalMain:stringifyRaw(finalMain.raw),pr:stringifyRaw(pr.raw),release:stringifyRaw(release.raw),security:stringifyRaw(security.raw),review:stringifyRaw(review.raw),reviewRequest:stringifyRaw(reviewRequest.raw),reviewSummary:reviewSummary?stringifyRaw(reviewSummary.raw):null,threads:stringifyRaw(threads.raw)};
}

function verifyPreservedLiveGitHub31(record,admission,approval){
  eq(record.observer,{executable:admission.runtime.githubExecutable,sha256:admission.runtime.githubExecutableSha256},'Original GitHub observer binding differs');
  const parse=x=>{need(typeof x==='string','Original GitHub response text required');return JSON.parse(x);};
  need(time(record.observedAtUtc)<=time(record.completedAtUtc),'Live observation interval differs');
  const pr=parse(record.pr),review=parse(record.review),request=parse(record.reviewRequest),summary=record.reviewSummary?parse(record.reviewSummary):null,threads=parse(record.threads);
  const prefix=/\*\*Reviewed commit:\*\*\s*`([0-9a-f]{7,40})`/i.exec(review.body??'')?.[1];need(prefix,'Actual reviewed-commit marker absent');
  const capture=kind=>({schemaVersion:1,evidenceType:kind==='release'?'github-exact-main-release-gate':'github-exact-main-codeql',repository:REPOSITORY,sourceCommit:admission.source.commit,sourceTree:admission.source.tree,capturedAtUtc:record.completedAtUtc,pullRequest:pr,run:parse(record[kind].run),jobs:parse(record[kind].jobs)});
  need(parse(record.main).object?.sha===admission.source.commit,'Original live main changed during admission');
  return verifyLiveGitHubRecords31({source:admission.source,approval,release:capture('release'),security:capture('security'),mainRef:parse(record.finalMain),pr,review,reviewRequest:request,reviewSummary:summary,reviewedHeadCommit:gtext(admission.repoRoot,['rev-parse','--verify',prefix+'^{commit}']),reviews:threads.data?.repository?.pullRequest?.reviews,threads:threads.data?.repository?.pullRequest?.reviewThreads,nowUtc:record.completedAtUtc});
}

function rejectConsumedEvidence31(config,approval){
  const seen=new Set();function visit(value){rejectSynthetic(value);if(!value||typeof value!=='object')return;
    if(typeof value.file==='string'&&/^[A-Fa-f0-9]{64}$/.test(value.sha256??'')){
      const key=value.file+':'+value.sha256;if(seen.has(key))return;seen.add(key);
      if(!value.file.startsWith('release/')){const raw=fileBinding(config.evidenceDirectory,value),text=raw.toString('utf8').trim();if(text.startsWith('{')||text.startsWith('['))visit(JSON.parse(text));}
    }
    for(const child of Object.values(value))visit(child);
  }
  visit(approval);for(const[key,file]of [['ownerAuthorization',a.PATHS.owner],['runtimeProof',a.PATHS.runtime],['mainCi',a.PATHS.release],['securityCi',a.PATHS.security]])visit(child(config.authorityRoot,config.approvalPointer.commit,approval[key],file));
}
function verifyBackendRuntimeExecutionAdmission31Inner(config) {
  need(config && !Object.hasOwn(config,'nowUtc') && !Object.hasOwn(config,'requireExecutionHead'), 'Execution time/head checks cannot be caller overridden');
  const approval=committed(config.authorityRoot,config.approvalPointer,a.PATHS.approval);
  const owner=child(config.authorityRoot,config.approvalPointer.commit,approval.ownerAuthorization,a.PATHS.owner);
  const originalMessage=object(fileBinding(config.evidenceDirectory,owner.originalMessage));
  verifyExplicitDeploymentOwner31({approval,owner,originalMessage,source:approval.source});
  rejectConsumedEvidence31(config,approval);
  cleanEnvironment31();
  const nowUtc=new Date().toISOString();
  const admission=a.verifyBackendRuntimeAdmission31({...config,nowUtc,requireExecutionHead:true});
  const parents=gtext(admission.repoRoot,['rev-list','--parents','-n','1',admission.source.commit]).split(' ').slice(1);
  eq(approval.normalMergeParents,parents,'Approved normal merge parents differ');
  const live=observeLiveGitHub31(admission,approval,new Date().toISOString());
  return {...admission,proposalOnly:false,deploymentAuthorized:true,executionAdmissionAtUtc:new Date().toISOString(),live,approval};
}
function verifyBackendRuntimeExecutionAdmission31(config){return require('./backendRuntimeEvidenceAccess31.cjs').runEvidence31(config,()=>verifyBackendRuntimeExecutionAdmission31Inner(config));}
module.exports={verifyPreservedLiveGitHub31,rejectConsumedEvidence31,verifyBackendRuntimeExecutionAdmission31,verifyExplicitDeploymentOwner31,verifyLiveGitHubRecords31,ownerInstruction,cleanEnvironment31,githubRead31,observeLiveGitHub31,rejectSynthetic,OWNER_ACTION,TRUSTED_MESSAGE_TYPE};
