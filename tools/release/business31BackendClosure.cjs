"use strict";
// Proposed raw-record replay only. No network, credential, deployment or client authority.
const {isDeepStrictEqual:same,TextDecoder} = require("node:util");
const zlib = require("node:zlib");
const x = require("./business31ExecutionContract.cjs"), access = require("./backendRuntimeEvidenceAccess31.cjs");
const path = access.path, {need,keys,sha,json,pointer,privateBytes,pointerView} = x;
const a = require("./business31BackendAuthority.cjs"), neutral = require("./backendRuntimeClosure31.cjs");
const controls = require("./backendRuntimeControls31.cjs"), readbacks = require("./backendRuntimeReadbacks31.cjs");
const live = require("./backendRuntimeExecutionAdmission31.cjs"), {RuntimeDeploymentTransportGuard31,bodyBinding31} = require("./runtimeDeploymentTransportGuard31.cjs");
const PHASES = Object.freeze(["callables","events","fleet"]);
const CLOSURE_FILE = "release/evidence/build31-business-backend-deployment-closure.json";
const t = a.instant;
const eq = (left,right,message) => need(same(left,right),message);
function read(root,p) { return json(privateBytes(root,p)); }
function exactTime(left,right,message) { need(t(left) === t(right),message); }
function before(ctx) {
  const {decision,source,evidenceDirectory,repoRoot,runtime,approvalPointer,cohorts} = ctx;
  const raw = {};
  for (const [kind,p] of Object.entries(decision.preflightPointers)) {
    const e = read(evidenceDirectory,p); raw[kind] = read(evidenceDirectory,e.measurement);
    let r;
    if (kind === "controls") r = controls.verifyPreservedControlsBefore31({repoRoot,sourceCommit:source.commit,evidenceDirectory,
      beforePointer:pointerView(evidenceDirectory,e.measurement),requiredProducerBindings:runtime.requiredProducerBindings,installedControlRuntime:runtime.installedControlRuntime});
    else { r = readbacks.verifyMeasuredReadback31({repoRoot,candidateSource:source,backendCommit:x.BASELINE,child:raw[kind],key:kind,
      earliestUtc:ctx.lastCiAtUtc,latestUtc:decision.decidedAtUtc,expectedRuntimeHash:ctx.historical.deployment.sourceRuntimeHash,
      collectionEnvelope:kind === "iamDependencies" ? read(evidenceDirectory,e.process) : undefined}); }
    exactTime(e.observedAtUtc,r.observedAtUtc,"before raw observation differs from bound envelope");
    exactTime(e.capturedAtUtc,r.capturedAtUtc,"before raw capture differs from bound envelope");
  }
  const schedulerEnvelope = read(evidenceDirectory,decision.schedulerBaseline), scheduler = read(evidenceDirectory,schedulerEnvelope.response);
  // The original payload must retain its response wrapper; never manufacture it.
  controls.schedulerControl31(scheduler.response);
  return {raw,controlsPointer:read(evidenceDirectory,decision.preflightPointers.controls).measurement,schedulerPointer:schedulerEnvelope.response,
    scheduler:scheduler.response,baselineFunctions:Object.fromEntries(raw.controls.functions.flatMap(page=>JSON.parse(page.bodyText).functions).map(f=>[f.name.split("/").at(-1),f]))};
}
function verifyIntent31({ctx,intent,archiveExpectedFiles}) {
  keys(intent,["schemaVersion","documentType","source","sourceBefore","sourceAfter","sourceArchiveHash","codebase","startedAtUtc","completedAtUtc","environmentVariables","endpoints","archive"],"approved intent");
  need(intent.documentType === "firebase-cli-approved-intended-hash-inputs" && intent.schemaVersion === 1,"intent type differs");
  if(ctx.contract?.schemaVersion===2) {
    const preparation=read(ctx.evidenceDirectory,ctx.contract.intentPreparation);
    eq(preparation.intendedHashInputs,ctx.contract.intendedHashInputs,"prepared intent pointer differs");
    eq(preparation.runtimeProof,ctx.contract.runtimeProof,"prepared runtime pointer differs");
    need(preparation.startedAtUtc===intent.startedAtUtc&&preparation.completedAtUtc===intent.completedAtUtc&&
      t(ctx.proof.completedAtUtc)<=t(intent.startedAtUtc)&&t(intent.startedAtUtc)<=t(intent.completedAtUtc)&&
      t(intent.completedAtUtc)<=t(ctx.contract.preparedAtUtc)&&t(ctx.contract.preparedAtUtc)<=t(ctx.ownerReceivedAtUtc),"post-runtime intent chronology differs");
    eq(read(ctx.evidenceDirectory,preparation.archiveExpectedFiles),archiveExpectedFiles,"prepared package population differs from actual source");
  } else {
    need(t(ctx.proof.startedAtUtc) <= t(intent.startedAtUtc) && t(intent.startedAtUtc) <= t(intent.completedAtUtc) &&
      t(intent.completedAtUtc) <= t(ctx.proof.completedAtUtc) && t(intent.completedAtUtc) <= t(ctx.ownerReceivedAtUtc),"intent chronology differs");
  }
  verifyOrderedIntent31(intent,intent,ctx.cohorts.fleet);
  const archive = privateBytes(ctx.evidenceDirectory,intent.archive), checked = neutral.verifyArchiveBytes31(archive,archiveExpectedFiles);
  need(checked.sourceArchiveHash === intent.sourceArchiveHash,"approved ZIP source differs");
  const labels = neutral.endpointRuntimeHashes31({sourceArchiveHash:intent.sourceArchiveHash,inputs:intent,runtime:ctx.runtime,names:ctx.cohorts.fleet,source:ctx.source});
  need(intent.environmentVariables.GCLOUD_PROJECT === "crm3-baf-ops-b8638" && JSON.parse(intent.environmentVariables.FIREBASE_CONFIG).projectId === "crm3-baf-ops-b8638" &&
    intent.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK === "false","intent project/enforcement differs");
  return {labels,archive};
}
// Matches the capture writer's retained and decoded response bounds. The sidecar
// is immutable mutation evidence, not an independently trusted success assertion.
const RESPONSE_BYTES = 16 * 1024 * 1024;
function verifyMutationResponse31(evidenceDirectory,responsePointer,bindingPointer) {
  const response=read(evidenceDirectory,responsePointer);
  keys(response,["httpStatus","bodyText"],"original response");
  need(Number.isSafeInteger(response.httpStatus) && response.httpStatus>=200 && response.httpStatus<300 &&
    typeof response.bodyText==="string","successful original response required");
  pointer(bindingPointer); need(bindingPointer.bytes<=8192,"wire response binding exceeds bound");
  const binding=read(evidenceDirectory,bindingPointer);
  keys(binding,["responseRaw","contentEncoding","responseComplete","retainedBytes","httpStatus"],"wire response binding");
  need(binding.responseComplete===true,"retained wire response is incomplete");
  need(Number.isSafeInteger(binding.httpStatus) && binding.httpStatus===response.httpStatus,"retained wire response status differs");
  need([null,"","identity","gzip","deflate","br"].includes(binding.contentEncoding),"unsupported wire response encoding");
  pointer(binding.responseRaw);
  need(Number.isSafeInteger(binding.retainedBytes) && binding.retainedBytes>=0 && binding.retainedBytes<=RESPONSE_BYTES &&
    binding.responseRaw.bytes===binding.retainedBytes,"retained wire response byte count differs or exceeds bound");
  const wire=privateBytes(evidenceDirectory,binding.responseRaw); let decoded=wire,bodyText;
  try {
    if(binding.contentEncoding==="gzip") decoded=zlib.gunzipSync(wire,{maxOutputLength:RESPONSE_BYTES});
    else if(binding.contentEncoding==="deflate") decoded=zlib.inflateSync(wire,{maxOutputLength:RESPONSE_BYTES});
    else if(binding.contentEncoding==="br") decoded=zlib.brotliDecompressSync(wire,{maxOutputLength:RESPONSE_BYTES});
    need(decoded.length<=RESPONSE_BYTES,"decoded wire response exceeds bound");
    bodyText=new TextDecoder("utf-8",{fatal:true}).decode(decoded);
  } catch { need(false,"retained wire response cannot be decoded within bound"); }
  need(bodyText===response.bodyText,"derived response body differs from retained wire response");
  return response;
}
// Version3 records the live guard's samples, not the earlier measurement clock.
// Historical records lack this evidence and never gain late-settlement permission.
function verifyMutationInitiation31(record,window) {
  need(record.schemaVersion===3 && record.error===null,"mutation live initiation evidence required");
  const start=t(record.startedAtUtc),admitted=t(record.requestAdmittedAtUtc),outbound=t(record.firstOutboundAtUtc),completed=t(record.completedAtUtc);
  need(t(window.notBeforeUtc)<=start && start<=admitted && admitted<=outbound && outbound<=t(window.notAfterUtc) && outbound<=completed,"mutation live initiation/window differs");
}
function verifyClosureExecutionWindow31({closure,executionWindow,nowUtc}) {
  // Only initiation is deadline-bound. Exact raw mutation samples are mandatory
  // in replayRecordedCohorts31; settlement, readbacks and custody keep their order.
  need(t(executionWindow.notBeforeUtc)<=t(closure.startedAtUtc) && t(closure.startedAtUtc)<=t(executionWindow.notAfterUtc) &&
    t(closure.startedAtUtc)<=t(closure.completedAtUtc) && t(closure.completedAtUtc)<=t(closure.recordedAtUtc) &&
    t(closure.recordedAtUtc)<=t(nowUtc),"closure chronology/window differs");
}
function replayMutationTranscript31({ctx,phase,command,capture,baseline,records,archivePointer}) {
  const names = phase === "fleet" ? ctx.cohorts.schedulers : ctx.cohorts[phase];
  need(Array.isArray(records) && records.length === names.length + 2,"complete generate/upload/update transcript required");
  const guard = new RuntimeDeploymentTransportGuard31({names,allNames:ctx.cohorts.fleet,baselineFunctions:baseline.baselineFunctions,
    baselineScheduler:baseline.scheduler,sourceArchiveHash:capture.sourceArchiveHash,endpointRuntimeHashes:capture.endpointRuntimeHashes,phase,
    projectNumber:JSON.parse(baseline.raw.controls.project.bodyText).projectNumber});
  guard.preparedMatches(capture); let previous=t(capture.completedAtUtc); const completions=[]; let uploadedAt=null, justGeneratedAt=null; const expectedKinds=["generate-upload","source-upload",...names.map(()=>"function-update")];
  for (let index=0;index<records.length;index++) {
    const r = read(ctx.evidenceDirectory,records[index]);
    keys(r,["schemaVersion","documentType","phase","sequence","completionSequence","kind","name","startedAtUtc","requestAdmittedAtUtc","firstOutboundAtUtc","completedAtUtc","request","wireBody","response","responseBinding","liveObservation","error"],"mutation transcript");
    // Schema1 lacks response-wire proof; schema2 lacks live forwarding times. Both are refused.
    need(r.schemaVersion===3 && r.documentType==="build31-business-original-mutation" && r.phase===phase && r.sequence===index+1 && r.kind===expectedKinds[index] &&
      (index<2?r.name===null:names.includes(r.name)) && Number.isSafeInteger(r.completionSequence) && r.completionSequence>=1 && r.completionSequence<=records.length && r.error===null,"mutation order/completion differs");
    need(previous<=t(r.startedAtUtc) && t(r.startedAtUtc)<=t(r.completedAtUtc) && t(r.completedAtUtc)<=t(command.completedAtUtc),"mutation interval differs"); previous=t(r.startedAtUtc);
    verifyMutationInitiation31(r,ctx.decision.executionWindow);
    if(index===1) need(t(justGeneratedAt)<=t(r.startedAtUtc),"upload started before generation completed");
    if(index>=2) need(uploadedAt<=t(r.startedAtUtc),"function update preceded completed ZIP upload");
    const observed=read(ctx.evidenceDirectory,r.liveObservation);
    need(t(capture.completedAtUtc)<=t(observed.observedAtUtc) && t(observed.completedAtUtc)<=t(r.startedAtUtc),"fresh per-write observation missing");
    live.verifyPreservedLiveGitHub31(observed,ctx,ctx.liveApproval);
    const request=read(ctx.evidenceDirectory,r.request), response=verifyMutationResponse31(ctx.evidenceDirectory,r.response,r.responseBinding), wire=privateBytes(ctx.evidenceDirectory,r.wireBody);
    keys(request,["client","request"],"original request"); keys(request.client,["urlPrefix","apiVersion"],"original client");
    keys(request.request,["method","path","queryParams","body"],"original request options");
    const options=structuredClone(request.request);
    if(r.kind==="source-upload") {
      keys(options.body,["path"],"upload original path");
      need(options.body.path===path.join(ctx.evidenceDirectory,archivePointer.file),"upload original archive identity differs");
      const uploaded=privateBytes(ctx.evidenceDirectory,archivePointer); need(uploaded.equals(wire),"uploaded wire bytes differ");
      // Only the helper's ephemeral filesystem view is relocated. Saved JSON is unchanged.
      options.body.path=x.physical(options.body.path);
    } else need(wire.equals(options.body===null?Buffer.alloc(0):Buffer.from(JSON.stringify(options.body))),"original wire body differs from original request");
    const operation=guard.before({opts:request.client},options); need(operation.kind===r.kind && (operation.name??null)===r.name,"pure transport classification differs");
    need(bodyBinding31(options)===sha(wire),"pure transport wire binding differs"); operation.sequence=r.sequence;
    // GCS PUT can succeed with Content-Length:0. Only generation needs JSON.
    const responseValue=r.kind==="generate-upload"?json(Buffer.from(response.bodyText)):undefined; guard.after(operation,{body:responseValue});
    if(index===0) justGeneratedAt=r.completedAtUtc; if(index===1) uploadedAt=t(r.completedAtUtc);
    completions.push({ordinal:r.completionSequence,completed:t(r.completedAtUtc),completedAtUtc:r.completedAtUtc,event:guard.events.at(-1)});
  }
  guard.assertComplete(); completions.sort((a,b)=>a.ordinal-b.ordinal);
  need(completions.every((c,i)=>c.ordinal===i+1 && (i===0 || completions[i-1].completed<=c.completed)),"completion population/order differs");
  return {mutationCount:records.length,events:completions.map(c=>c.event),completedAtUtc:completions.at(-1).completedAtUtc};
}
function verifyOrderedIntent31(capture,intent,names) {
  keys(capture.endpoints,names,"actual captured endpoint population");
  keys(intent.endpoints,names,"approved endpoint population");
  for(const inputs of [capture,intent]) for(const name of names) {
    const e=inputs.endpoints[name]; keys(e,["id","platform","project","region","secretEnvironmentVariables"],"endpoint intent");
    need(Array.isArray(e.secretEnvironmentVariables),"secret metadata array required");
    for(const secret of e.secretEnvironmentVariables) keys(secret,["key","secret","projectId","version"],"secret intent");
  }
  need(JSON.stringify(capture.environmentVariables)===JSON.stringify(intent.environmentVariables) &&
    names.every(name=>JSON.stringify(capture.endpoints[name])===JSON.stringify(intent.endpoints[name])) &&
    capture.sourceArchiveHash===intent.sourceArchiveHash,"ordered prepared env/secret inputs changed");
}
// The same raw cohort replay is used by closure and live predecessor admission.
// Bounds are supplied by their measured context, never by a fabricated closure.
function replayRecordedCohort31({ctx,phase,commandPointer,earliestUtc,latestUtc,endpointRuntimeHashes,baseline,intent,archiveExpectedFiles,predecessors}) {
  need(PHASES.includes(phase),"exact cohort required");
  const r=read(ctx.evidenceDirectory,commandPointer), names=phase==="fleet"?ctx.cohorts.schedulers:ctx.cohorts[phase];
  keys(r,["schemaVersion","documentType","source","approvalPointer","executionContractSha256","phase","functions","attempt","startedAtUtc","completedAtUtc","exitCode","signal","error","executable","nodeSha256","cwd","arguments","cliArguments","sourceBefore","sourceAfter","producerBindings","stdout","stderr","capture","archive","currentControls","mutations","completion",...(r.schemaVersion===2?["context","start","process"]:[])],"cohort receipt");
  need([1,2].includes(r.schemaVersion) && r.documentType==="build31-business-original-cohort" && r.phase===phase && r.attempt===1 && r.exitCode===0 && r.signal===null && r.error===null,"single successful cohort required");
  need([1,2].includes(ctx.contract?.schemaVersion) && r.schemaVersion===ctx.contract.schemaVersion,
    "cohort schema differs from execution contract");
  eq(r.source,ctx.source,"cohort source differs"); eq(r.approvalPointer,ctx.approvalPointer,"cohort decision differs"); eq(r.functions,names,"cohort functions differ");
  need(r.executionContractSha256===ctx.decision.executionContract.sha256,"cohort execution contract differs");
  need(t(earliestUtc)<=t(r.startedAtUtc) && t(r.startedAtUtc)<=t(r.completedAtUtc) && t(r.completedAtUtc)<=t(latestUtc),"cohort order differs");
  need(t(ctx.decision.executionWindow.notBeforeUtc)<=t(r.startedAtUtc) && t(r.startedAtUtc)<=t(ctx.decision.executionWindow.notAfterUtc),"cohort initiation outside execution window");
  need(r.executable===ctx.runtime.nodeExecutable && r.nodeSha256===ctx.runtime.nodeSha256 && r.cwd===ctx.proof.buildRoot,"cohort runtime/original cwd differs");
  eq(r.arguments,["--no-global-search-paths",path.join(r.cwd,x.CAPTURE),"--config",path.join(ctx.evidenceDirectory,"deployment-attempts",ctx.approvalPointer.sha256,phase,"context.json")],"cohort capture command differs");
  eq(r.cliArguments,["deploy","--only",names.map(n=>"functions:"+n).join(","),"--project","crm3-baf-ops-b8638","--non-interactive"],"cohort CLI differs");
  eq(r.producerBindings,ctx.producerBindings,"cohort producers differ");
  if(r.schemaVersion===2) {
    need(Array.isArray(predecessors),"measured predecessor pointers required");
    require("./business31CohortProcess.cjs").verifyCohortProcess31({ctx,record:r,predecessors});
  }
  for(const point of [r.sourceBefore,r.sourceAfter]) eq(point,{...ctx.source,branch:"main",originMain:ctx.source.commit,liveMain:ctx.source.commit,clean:true},"cohort clean source differs");
  privateBytes(ctx.evidenceDirectory,r.stdout); privateBytes(ctx.evidenceDirectory,r.stderr);
  const capture=read(ctx.evidenceDirectory,r.capture), completion=read(ctx.evidenceDirectory,r.completion);
  need(capture.actualCliPreparationCaptured===true && capture.phase===phase,"actual preparation capture missing");
  eq(capture.approvalPointer,ctx.approvalPointer,"capture approval differs"); eq(capture.instrumentationProducerSha256,ctx.runtime.instrumentationProducerSha256,"capture runtime producer differs");
  verifyOrderedIntent31(capture,intent,ctx.cohorts.fleet);
  const labels=neutral.endpointRuntimeHashes31({sourceArchiveHash:capture.sourceArchiveHash,inputs:capture,runtime:ctx.runtime,names:ctx.cohorts.fleet,source:ctx.source});
  eq(labels,endpointRuntimeHashes,"cohort endpoint labels differ"); eq(labels,capture.endpointRuntimeHashes,"captured endpoint labels differ");
  const uploaded=privateBytes(ctx.evidenceDirectory,r.archive); need(sha(uploaded)===capture.archiveSha256 && uploaded.length===capture.archiveBytes,"actual uploaded ZIP differs");
  need(neutral.verifyArchiveBytes31(uploaded,archiveExpectedFiles).sourceArchiveHash===intent.sourceArchiveHash,"uploaded M ZIP differs");
  const current=controls.verifyCurrentCohortControls31({repoRoot:ctx.repoRoot,sourceCommit:ctx.source.commit,evidenceDirectory:ctx.evidenceDirectory,
    beforePointer:pointerView(ctx.evidenceDirectory,baseline.controlsPointer),currentPointer:pointerView(ctx.evidenceDirectory,r.currentControls),schedulerBaseline:pointerView(ctx.evidenceDirectory,baseline.schedulerPointer),
    approvalSha256:ctx.approvalPointer.sha256,decisionAtUtc:ctx.decision.decidedAtUtc,phase,cohorts:ctx.cohorts,endpointRuntimeHashes:labels,requiredProducerBindings:ctx.runtime.requiredProducerBindings,installedControlRuntime:ctx.runtime.installedControlRuntime});
  neutral.verifyCohortControlChronology31(r,capture,current);
  need(t(capture.startedAtUtc)>=t(r.startedAtUtc) && t(capture.completedAtUtc)<=t(r.completedAtUtc),"capture interval differs");
  need(t(ctx.decision.executionWindow.notBeforeUtc)<=t(capture.startedAtUtc) && t(capture.startedAtUtc)<=t(ctx.decision.executionWindow.notAfterUtc),"preparation initiation outside execution window");
  const replay=replayMutationTranscript31({ctx,phase,command:r,capture,baseline,records:r.mutations,archivePointer:r.archive});
  keys(completion,["schemaVersion","documentType","phase","source","approvalPointer","capture","archive","mutations","events","completedAtUtc","exitCode","error"],"completion");
  need(completion.schemaVersion===1 && completion.documentType==="build31-business-instrumented-completion" && completion.phase===phase && completion.exitCode===0 && completion.error===null,"instrumented completion missing");
  eq(completion.source,ctx.source,"completion source differs"); eq(completion.approvalPointer,ctx.approvalPointer,"completion decision differs");
  eq(completion.capture,r.capture,"completion capture differs");eq(completion.archive,r.archive,"completion ZIP differs");eq(completion.mutations,r.mutations,"completion transcript differs");eq(completion.events,replay.events,"completion events differ from raw replay");
  need(t(r.completedAtUtc)>=t(completion.completedAtUtc) && t(completion.completedAtUtc)>=t(capture.completedAtUtc) && t(completion.completedAtUtc)>=t(replay.completedAtUtc),"completion time differs");
  return {phase,completedAtUtc:r.completedAtUtc,functions:names,uploadedArchiveSha256:r.archive.sha256,record:r};
}
function replayRecordedCohorts31({ctx,closure,baseline,intent,archiveExpectedFiles}) {
  keys(closure.commands,PHASES,"cohort population"); let previous=closure.startedAtUtc; const covered=[],uploads=[];
  for(const phase of PHASES) {
    const checked=replayRecordedCohort31({ctx,phase,commandPointer:closure.commands[phase],earliestUtc:previous,
      latestUtc:closure.completedAtUtc,endpointRuntimeHashes:closure.endpointRuntimeHashes,baseline,intent,archiveExpectedFiles,
      predecessors:PHASES.slice(0,PHASES.indexOf(phase)).map(p=>({phase:p,pointer:closure.commands[p]}))});
    previous=checked.completedAtUtc;covered.push(...checked.functions);uploads.push(checked.uploadedArchiveSha256);
  }
  eq(covered.sort(),ctx.cohorts.fleet,"exact once-only19 cohort union required"); return {cohortCount:3,functionCount:covered.length,uploadedArchiveSha256:uploads};
}


function verifyClosureChronology31({closure,custodySeconds,nowUtc,afterControls}) {
  need(typeof custodySeconds==="string" && /^[0-9]+$/.test(custodySeconds),"closure custody time malformed");
  const custody=BigInt(custodySeconds)*1000000000n;
  need(t(closure.recordedAtUtc)<custody+1000000000n && custody<=t(nowUtc),"closure custody predates recording or postdates trusted observation");
  if(afterControls) need(t(closure.completedAtUtc)<=t(afterControls.startedAtUtc) && t(afterControls.startedAtUtc)<=t(afterControls.completedAtUtc) &&
    t(afterControls.completedAtUtc)<=t(closure.recordedAtUtc),"after-controls postdate closure recording");
}
function prepareBusinessCaptureBase31(authorityOptions) {
  const prepared=a.verifyBusiness31BackendAuthority(authorityOptions), evidenceDirectory=authorityOptions.evidenceDirectory;
  const decision=read(evidenceDirectory,prepared.originalDecision); need(decision.schemaVersion===2 && prepared.executionInputs,"schema1 preparation cannot become a closure");
  const contract=read(evidenceDirectory,decision.executionContract), proof=read(evidenceDirectory,decision.runtimeProof);
  const owner=read(evidenceDirectory,decision.ownerAuthorization), originalOwner=read(evidenceDirectory,owner.originalMessage);
  const repository=require("./business31TrustedInput.cjs").openTrustedGitRepository31({repositoryRoot:x.physical(authorityOptions.repositoryRoot,true),gitExecutable:x.physical(authorityOptions.gitExecutable),gitSha256:authorityOptions.gitSha256});
  const sourceSnapshot=repository.snapshot(prepared.source.commit);
  const policy=json(repository.readBlob(prepared.source.commit,"release/function-fleet-runtime-identity-policy.json"));
  const cohorts=x.cohortsFromPolicy(policy), historicalBytes=repository.readBlob(prepared.source.commit,"release/evidence/build30-current-source-backend-deployment-closure.json");
  need(sha(historicalBytes)==="3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45","historical F closure changed");
  const release=read(evidenceDirectory,decision.mainCi), security=read(evidenceDirectory,decision.securityCi);
  const runtime=x.deriveRuntime31({proof,executionContract:contract,evidenceDirectory,read:p=>privateBytes(evidenceDirectory,p),repository,source:prepared.source,producerBindings:authorityOptions.trustedVerifier.files});
  const ctx={source:prepared.source,decision,contract,proof,evidenceDirectory,repoRoot:proof.buildRoot,runtime,cohorts,approvalPointer:prepared.decisionPointer,producerBindings:authorityOptions.trustedVerifier.files,
    lastCiAtUtc:[release.capturedAtUtc,security.capturedAtUtc].sort((l,r)=>t(l)<t(r)?-1:1).at(-1),historical:json(historicalBytes),ownerReceivedAtUtc:originalOwner.receivedAtUtc,liveApproval:prepared.executionInputs.approval};
  return {prepared,evidenceDirectory,decision,contract,proof,owner,originalOwner,repository,sourceSnapshot,cohorts,runtime,ctx};
}
function finishBusinessCaptureContext31(common) {
  const {prepared,evidenceDirectory,decision,contract,proof,owner,originalOwner,repository,sourceSnapshot,cohorts,runtime,ctx}=common;
  // Inventory is enumerated by the exact installed CLI against materialized M.
  // Every source member and emitted byte must additionally bind to immutable M.
  const inventory=neutral.actualArchiveInventory31({repoRoot:ctx.repoRoot,sourceCommit:ctx.source.commit,buildRoot:proof.buildRoot,runtime});
  const expectedOutputs=a.expectedEmittedFiles31(sourceSnapshot,json(repository.readBlob(ctx.source.commit,"functions/tsconfig.json")));
  eq(Object.keys(inventory).filter(n=>n.startsWith("lib/")).sort(),expectedOutputs,"package complete emitted population differs");
  for(const [name,binding] of Object.entries(inventory)) {
    const bytes=name.startsWith("lib/")?privateBytes(evidenceDirectory,proof.emittedFiles[name]):repository.readBlob(ctx.source.commit,"functions/"+name);
    need(binding.bytes===bytes.length && binding.sha256===sha(bytes),"package member differs from exact M/build");
  }
  const sourceNames=Object.keys(sourceSnapshot.files).filter(n=>n.startsWith("functions/src/")).map(n=>n.slice(10)); need(sourceNames.every(n=>Object.hasOwn(inventory,n)),"package omits M source");
  for(const name of ["package.json","package-lock.json"]) need(inventory[name]?.sha256===sha(repository.readBlob(ctx.source.commit,"functions/"+name)),"package dependencies do not bind M");
  const intent=read(evidenceDirectory,contract.intendedHashInputs), intentResult=verifyIntent31({ctx,intent,archiveExpectedFiles:inventory});
  const baseline=before(ctx);
  return {prepared,evidenceDirectory,decision,contract,proof,owner,originalOwner,repository,sourceSnapshot,
    cohorts,runtime,ctx,inventory,intent,intentResult,baseline};
}
function prepareBusinessCaptureContext31(authorityOptions) {
  return finishBusinessCaptureContext31(prepareBusinessCaptureBase31(authorityOptions));
}
function prepareBusinessOperationalCaptureContext31(authorityOptions) {
  const bootstrap=require("./business31CaptureBootstrap.cjs");
  bootstrap.assertOperational31();
  // Authority and the complete runtime proof are verified before admission. The
  // original hash helper then imports through the same owned CLI lifetime that
  // the operational controller/phase retains until its final cleanup.
  const common=prepareBusinessCaptureBase31(authorityOptions);
  const cliLoadLease=bootstrap.installCliLoadBoundary31(common.runtime);
  try {
    const result=finishBusinessCaptureContext31(common);
    cliLoadLease.assertHealthy();
    return {...result,cliLoadLease};
  } catch(error) {
    try { if(!cliLoadLease.isReleased())cliLoadLease.release(); }
    catch(cleanup) { throw new AggregateError([error,cleanup],"capture context and CLI cleanup failed"); }
    throw error;
  }
}
function verifyBusiness31BackendClosure({authorityOptions,closurePointer}) {
  // The public entry recomputes the preparation and source/custody facts itself;
  // a caller-supplied PASS/admission object is never accepted.
  const {prepared,evidenceDirectory,decision,contract,proof,repository,sourceSnapshot,cohorts,runtime,
    ctx,inventory,intent,intentResult,baseline}=prepareBusinessCaptureContext31(authorityOptions);
  keys(closurePointer,["commit","file","sha256"],"closure custody pointer"); need(closurePointer.file===CLOSURE_FILE && /^[0-9a-f]{40}$/i.test(closurePointer.commit) && /^[0-9a-f]{64}$/i.test(closurePointer.sha256),"closure custody identity differs");
  const decisionSnapshot=repository.snapshot(prepared.decisionPointer.commit), closureSnapshot=repository.snapshot(closurePointer.commit);
  repository.requireAncestor(prepared.decisionPointer.commit,closureSnapshot.commit); need(closureSnapshot.commit!==prepared.decisionPointer.commit,"closure custody must follow decision custody");
  const changed=[...new Set([...Object.keys(decisionSnapshot.files),...Object.keys(closureSnapshot.files)])].filter(file=>!same(decisionSnapshot.files[file],closureSnapshot.files[file]));
  eq(changed,[CLOSURE_FILE],"closure custody may change only its exact metadata path"); need(closureSnapshot.files[CLOSURE_FILE].mode==="100644","closure custody mode differs");
  const envelopeBytes=repository.readBlob(closureSnapshot.commit,CLOSURE_FILE); need(sha(envelopeBytes)===closurePointer.sha256,"closure custody bytes differ"); const envelope=json(envelopeBytes);
  keys(envelope,["schemaVersion","documentType","recordKind","source","recordedAtUtc","privateRecord"],"closure envelope");
  need(envelope.schemaVersion===1 && envelope.documentType==="build31-business-private-record-custody" && envelope.recordKind==="closure","closure envelope type differs"); eq(envelope.source,prepared.source,"closure envelope source differs");
  const closure=read(evidenceDirectory,envelope.privateRecord);
  const custodySeconds=require("./backendRuntimeAdmission31.cjs").helpers.gtext(authorityOptions.repositoryRoot,["show","-s","--format=%ct",closurePointer.commit]);
  verifyClosureChronology31({closure,custodySeconds,nowUtc:authorityOptions.nowUtc});
  keys(closure,["schemaVersion","documentType","profile","source","baseline","approvalPointer","executionContractSha256","startedAtUtc","completedAtUtc","recordedAtUtc","scope","commands","sourceArchiveHash","endpointRuntimeHashes","archiveExpectedFiles","readbacks","iamCollectionProcess","controlsAfter","schedulerAfter","archives"],"business closure");
  need(closure.schemaVersion===1 && closure.documentType==="build31-business-backend-deployment-closure" && closure.profile===a.PROFILE,"business closure type differs");
  eq(closure.source,prepared.source,"closure source differs");eq(closure.baseline,contract.baseline,"closure F baseline differs");eq(closure.approvalPointer,prepared.decisionPointer,"closure decision differs");
  need(closure.executionContractSha256===decision.executionContract.sha256 && envelope.recordedAtUtc===closure.recordedAtUtc,"closure approved contract/custody differs");
  eq(closure.scope,{functionsChanged:true,businessLogicChanged:true,rulesChanged:false,indexesChanged:false,iamChanged:false,enforcementChanged:false,manualSchedulerExecution:false,businessDataMutation:false},"closure mutation scope differs");
  verifyClosureExecutionWindow31({closure,executionWindow:decision.executionWindow,nowUtc:authorityOptions.nowUtc});
  eq(inventory,closure.archiveExpectedFiles,"closure package population differs from exact installed CLI");
  need(closure.sourceArchiveHash===intent.sourceArchiveHash,"closure source archive differs");eq(closure.endpointRuntimeHashes,intentResult.labels,"closure endpoint identity differs");
  const replay=replayRecordedCohorts31({ctx,closure,baseline,intent,archiveExpectedFiles:inventory});
  keys(closure.readbacks,["functionFleet","iamDependencies","firestoreRulesAndIndexes"],"final readbacks"); const final={};
  for(const [key,p] of Object.entries(closure.readbacks)) { const child=read(evidenceDirectory,p);
    readbacks.verifyMeasuredReadback31({repoRoot:ctx.repoRoot,candidateSource:ctx.source,backendCommit:ctx.source.commit,child,key,earliestUtc:closure.completedAtUtc,latestUtc:closure.recordedAtUtc,
      expectedRuntimeHash:intentResult.labels,collectionEnvelope:key==="iamDependencies"?read(evidenceDirectory,closure.iamCollectionProcess):undefined}); final[key]=child;
  }
  const rows=final.iamDependencies.outputs.functions; eq(rows.map(r=>r.name).sort(),cohorts.fleet,"final IAM fleet differs");
  const archiveDigests=[...new Set(rows.map(r=>r.sourceArchive.sha256))].sort();eq(Object.keys(closure.archives).sort(),archiveDigests,"deployed ZIP population differs");
  for(const [digest,p] of Object.entries(closure.archives)) {need(p.sha256===digest,"deployed ZIP pointer differs");const checked=neutral.verifyArchiveBytes31(privateBytes(evidenceDirectory,p),inventory);need(checked.sourceArchiveHash===intent.sourceArchiveHash,"deployed ZIP source differs");}
  for(const row of rows) {need(t(closure.startedAtUtc)<=t(row.updateTime) && t(row.updateTime)<=t(closure.completedAtUtc) && row.sourceArchive.generationPinnedDownload===true &&
    /^[1-9][0-9]*$/.test(row.source.generation) && row.source.object===row.name+"/function-source.zip","deployed generation/time differs");
    need(row.dependencies.packageManifestSha256===inventory["package.json"].sha256 && row.dependencies.packageLockSha256===inventory["package-lock.json"].sha256,"deployed dependency bytes differ from M");}
  const afterRaw=read(evidenceDirectory,closure.controlsAfter); verifyClosureChronology31({closure,custodySeconds,nowUtc:authorityOptions.nowUtc,afterControls:afterRaw});
  neutral.bindPreparedHashInputsToControls31({inputs:intent,raw:afterRaw,names:cohorts.fleet,expectedHashes:intentResult.labels});
  const preserved=controls.verifyPreservedControls31({repoRoot:ctx.repoRoot,sourceCommit:ctx.source.commit,evidenceDirectory,beforePointer:pointerView(evidenceDirectory,baseline.controlsPointer),
    afterPointer:pointerView(evidenceDirectory,closure.controlsAfter),approvalSha256:ctx.approvalPointer.sha256,decisionAtUtc:decision.decidedAtUtc,completedAtUtc:closure.completedAtUtc,
    requiredProducerBindings:runtime.requiredProducerBindings,installedControlRuntime:runtime.installedControlRuntime});
  const schedulerAfter=read(evidenceDirectory,closure.schedulerAfter);eq(controls.schedulerControl31(baseline.scheduler),controls.schedulerControl31(schedulerAfter.response),"final scheduler controls differ");
  need(t(closure.completedAtUtc)<=t(schedulerAfter.observedAtUtc) && t(schedulerAfter.observedAtUtc)<=t(schedulerAfter.capturedAtUtc) && t(schedulerAfter.capturedAtUtc)<=t(closure.recordedAtUtc),"final scheduler chronology differs");
  return Object.freeze({schemaVersion:1,documentType:"build31-business-recorded-closure-replay",profile:a.PROFILE,source:ctx.source,baseline:contract.baseline,
    decisionPointer:prepared.decisionPointer,closurePointer,recordedSemanticsReplayed:true,cohorts:replay,controlsPreserved:preserved.summary,
    businessDeltaManifestSha256:decision.sourceManifestSha256,businessLogicPreserved:false,
    platformIdentityAuthenticated:false,humanIdentityAuthenticated:false,processExecutionAuthenticated:false,trustedClockAuthenticated:false,
    privateHostedReplayAuthenticated:false,deploymentAuthorized:false,credentialAccessAuthorized:false,constructionAuthorized:false,distributionAuthorized:false});
}
module.exports={CLOSURE_FILE,PHASES,verifyMutationInitiation31,verifyClosureExecutionWindow31,verifyMutationResponse31,verifyIntent31,verifyClosureChronology31,verifyOrderedIntent31,replayMutationTranscript31,replayRecordedCohort31,replayRecordedCohorts31,prepareBusinessCaptureContext31,prepareBusinessOperationalCaptureContext31,verifyBusiness31BackendClosure};
