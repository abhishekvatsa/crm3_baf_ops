"use strict";
// Fixed three-child implementation. Protected input selection is an external trust root.
const fs = require("node:fs"), path = require("node:path");
const {isDeepStrictEqual:same} = require("node:util");
const bootstrap = require("./business31CaptureBootstrap.cjs");
bootstrap.assertBootstrap31();
const x = require("./business31ExecutionContract.cjs"), a = require("./business31BackendAuthority.cjs");
const replay = require("./business31BackendClosure.cjs"), custody = require("./business31CohortProcess.cjs");
const old = require("./backendRuntimeAdmission31.cjs"), controls = require("./backendRuntimeControls31.cjs");
const live = require("./backendRuntimeExecutionAdmission31.cjs"), neutral = require("./runtimeDeploymentTransportGuard31.cjs");
const recorder = require("./business31CaptureRecorder.cjs");
const pythonRuntime = require("./collectBusinessRuntime31.cjs");
const {need, keys, sha, json, privateBytes} = x;
const SUPERVISOR_SHA = "4AE021C13E2FDC0D3FAD18ADBF5D7D796FD2DA946E8C907288BA0A83C585F37C";
const utc = () => new Date().toISOString();
const read = (root,pointer) => json(privateBytes(root,pointer));
const phases = custody.PHASES;

// Business collection uses the unchanged raw schema and comparators. The historical
// collector remains frozen; live Run inventories now include two-digit region suffixes.
async function collectCurrentBusinessControls31({sourceCommit,approvalSha256,read,unavailableRunRegion}){
 const {PROJECT,REGION,SCHEDULER_URL}=controls;
 const raw={schemaVersion:1,projectId:PROJECT,region:REGION,sourceCommit,approvalSha256,startedAtUtc:new Date().toISOString()};
 async function list(url,field,optionalRegion){const rows=[],entries=[],seen=new Set();let token='';do{need(rows.length<1000,'Readback pagination exceeds bound');const response=await read(url+'?pageSize=100'+(token?'&pageToken='+encodeURIComponent(token):''));if(response.httpStatus!==200){if(optionalRegion&&rows.length===0&&response.httpStatus===403){unavailableRunRegion(response,optionalRegion,project.projectNumber);return {unavailable:response,entries:[]};}throw Error('Complete current controls readback unavailable');}const value=JSON.parse(response.bodyText);need(!value.error&&!(value.unreachable?.length),'Current controls response incomplete');rows.push(response);need(Array.isArray(value[field]??[]),'Current controls population invalid');entries.push(...(value[field]??[]));token=value.nextPageToken??'';need(typeof token==='string'&&(!token||!seen.has(token)),'Current controls repeated pagination token');if(token)seen.add(token);}while(token);return {rows,entries};}
 async function map(rows,action){const output=new Array(rows.length);let next=0;await Promise.all(Array.from({length:Math.min(4,rows.length)},async()=>{while(next<rows.length){const i=next++;output[i]=await action(rows[i]);}}));return output;}
 raw.project=await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`);need(raw.project.httpStatus===200,'Current project unavailable');const project=JSON.parse(raw.project.bodyText);need(project.projectId===PROJECT&&/^[1-9][0-9]*$/.test(String(project.projectNumber)),'Current project identity differs');const normal=n=>n.replace(`projects/${project.projectNumber}/`,`projects/${PROJECT}/`);
 raw.functions=(await list(`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions')).rows;
 const locations=await list(`https://run.googleapis.com/v1/projects/${PROJECT}/locations`,'locations');raw.runLocations=locations.rows;
 const inventories=await map(locations.entries,async location=>{const name=location.locationId;need(typeof name==='string'&&name.match(/^[a-z]+-[a-z]+[0-9]{1,2}$/)?.[0]===name,'Unexpected Run region');return {location:location.locationId,...await list(`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location.locationId}/services`,'services',location.locationId)};});
 raw.runInventories=inventories.map(row=>row.unavailable?{location:row.location,unavailable:row.unavailable}:{location:row.location,pages:row.rows});
 raw.runIam=await map(inventories.flatMap(row=>row.entries),async service=>{const resource=normal(service.name);need(resource.startsWith(`projects/${PROJECT}/locations/`),'Current Run resource outside project');return {resource,response:await read(`https://run.googleapis.com/v2/${resource}:getIamPolicy?options.requestedPolicyVersion=3`)};});
 const accounts=await list(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`,'accounts');raw.accounts=accounts.rows;
 raw.accountIam=await map(accounts.entries,async account=>{need(typeof account.email==='string'&&/^[a-zA-Z0-9@._-]+$/.test(account.email),'Invalid account identity');return {email:account.email,response:await read(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${account.email}:getIamPolicy?options.requestedPolicyVersion=3`,'POST')};});
 raw.projectIam=await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`,'POST',{options:{requestedPolicyVersion:3}});raw.absence=[];
 const scheduler=await read(SCHEDULER_URL);need(scheduler.httpStatus===200,'Existing exact scheduler unavailable');raw.completedAtUtc=new Date().toISOString();
 return {raw,scheduler};
}

function selectedFile(binding) {
  keys(binding,["path","sha256"],"selected executable");
  need(path.isAbsolute(binding.path)&&/^[A-F0-9]{64}$/.test(binding.sha256),"absolute selected executable/hash required");
  const file=x.physical(binding.path);
  need(sha(fs.readFileSync(file))===binding.sha256,"selected executable changed");
  return file;
}
function authorityOptions(configuration) {
  keys(configuration,["schemaVersion","documentType","authority","execution"],"protected selection");
  need(configuration.schemaVersion===1&&configuration.documentType==="build31-business-protected-selection","fixed protected selection required");
  keys(configuration.authority,["repositoryRoot","gitExecutable","gitSha256","trustedVerifier","sourceCommit","sourceManifest",
    "trustedManifestSha256","evidenceDirectory","decisionPointer"],"original authority inputs");
  return {...configuration.authority,nowUtc:utc()};
}
function verifySelection(configuration,common) {
  const e=configuration.execution,ctx=common.ctx;
  keys(e,["sourceRoot","helperFiles","nodeExecutable","python","environment","limits"],"selected execution");
  need(e.sourceRoot===path.join(ctx.repoRoot,"tools/release")&&e.sourceRoot===__dirname,"controller must execute selected M producer bytes");
  need(selectedFile(e.nodeExecutable)===process.execPath&&e.nodeExecutable.sha256===ctx.runtime.nodeSha256&&e.nodeExecutable.path===ctx.runtime.nodeExecutable,"approved Node differs");
  const snapshot=common.repository.snapshot(ctx.source.commit);
  const expected=Object.keys(snapshot.files).filter(name=>name.startsWith("tools/release/")).map(name=>name.slice(14)).sort();
  need(same(Object.keys(e.helperFiles).sort(),expected),"complete selected helper population differs from M");
  for(const [name,hash] of Object.entries(e.helperFiles)) need(hash===sha(common.repository.readBlob(ctx.source.commit,"tools/release/"+name))&&hash===sha(fs.readFileSync(x.physical(path.join(e.sourceRoot,name)))),"source-selected helper changed");
  pythonRuntime.verifyPythonRuntime31(e.python);
  need(sha(fs.readFileSync(path.join(__dirname,"runtime_supervisor.py")))===SUPERVISOR_SHA,"owned supervisor source changed");
  keys(e.limits,["commandSeconds","outputBytes","cleanupSeconds"],"process limits");
  need(Number.isSafeInteger(e.limits.commandSeconds)&&e.limits.commandSeconds>=1&&e.limits.commandSeconds<=21600&&
    Number.isSafeInteger(e.limits.outputBytes)&&e.limits.outputBytes>=1024&&e.limits.outputBytes<=64*1024*1024&&
    Number.isSafeInteger(e.limits.cleanupSeconds)&&e.limits.cleanupSeconds>=1&&e.limits.cleanupSeconds<=60,"bounded process limits required");
  // No ambient environment is merged. Credential selection belongs to the protected launcher;
  // values/tokens cannot be passed as environment fields through this controller.
  const allowed=["SystemRoot","WINDIR","COMSPEC","PATHEXT","PATH","HOME","USERPROFILE","APPDATA","LOCALAPPDATA",
    "XDG_CONFIG_HOME","GH_CONFIG_DIR","TEMP","TMP","TMPDIR","CI","NO_COLOR"];
  need(e.environment&&typeof e.environment==="object"&&!Array.isArray(e.environment)&&
    Object.keys(e.environment).every(k=>allowed.includes(k))&&Object.values(e.environment).every(v=>typeof v==="string"&&!/[\0\r\n]/.test(v)),"finite explicit child environment required");
  for(const name of ["SystemRoot","WINDIR","COMSPEC","PATH","HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","GH_CONFIG_DIR","TEMP","TMP"])
    need(typeof e.environment[name]==="string"&&e.environment[name].length>0,"missing selected environment path: "+name);
  need(e.environment.CI==="true"&&e.environment.NO_COLOR==="1","fixed noninteractive environment required");
  const actualEnvironment=Object.fromEntries(Object.entries(process.env).map(([name,value])=>[name.toUpperCase(),value]));
  const selectedEnvironment=Object.fromEntries(Object.entries(e.environment).map(([name,value])=>[name.toUpperCase(),value]));
  need(Object.keys(selectedEnvironment).length===Object.keys(e.environment).length,"duplicate environment key casing refused");
  if(Object.hasOwn(actualEnvironment,"BUSINESS31_PHASE_CONTEXT_SHA256"))delete actualEnvironment.BUSINESS31_PHASE_CONTEXT_SHA256;
  need(same(actualEnvironment,selectedEnvironment),"actual clean process environment differs from protected selection");
  // PATH contains only explicit already measured executables plus Windows System32.
  const expectedPath=[path.dirname(ctx.runtime.nodeExecutable),path.dirname(configuration.authority.gitExecutable),
    path.dirname(ctx.runtime.githubExecutable),path.join(e.environment.SystemRoot,"System32")];
  need(same(e.environment.PATH.split(path.delimiter),[...new Set(expectedPath)]),"selected child PATH differs");
  need(path.resolve(e.environment.COMSPEC)===path.join(e.environment.SystemRoot,"System32","cmd.exe"),"selected command interpreter differs");
  return e;
}
function windowNow(ctx) {
  bootstrap.assertOperational31();
  const now=utc(),t=a.instant(now);
  need(a.instant(ctx.decision.executionWindow.notBeforeUtc)<=t&&t<=a.instant(ctx.decision.executionWindow.notAfterUtc),"outside actual decision execution window");
  return now;
}
function cleanPoint(ctx) {
  const g=args=>old.helpers.gtext(ctx.repoRoot,args);
  need(g(["branch","--show-current"])==="main"&&g(["rev-parse","HEAD"])===ctx.source.commit&&
    g(["rev-parse","refs/remotes/origin/main"])===ctx.source.commit&&g(["status","--porcelain","--untracked-files=normal"])==="","actual M/main/origin checkout is not clean");
  need(same(old.helpers.source(ctx.repoRoot,ctx.source.commit),ctx.source),"actual source identity differs");
  return {...ctx.source,branch:"main",originMain:ctx.source.commit,liveMain:ctx.source.commit,clean:true};
}
function observerAdmission(common) {
  const release=read(common.evidenceDirectory,common.decision.mainCi);
  return {...common.ctx,mainCi:{pullRequestNumber:release.pullRequest.number}};
}
function observe(common) {
  cleanPoint(common.ctx);
  const result=live.observeLiveGitHub31(observerAdmission(common),common.ctx.liveApproval,utc());
  cleanPoint(common.ctx);windowNow(common.ctx);return result;
}
function replayPrefix(common,predecessors,latestUtc) {
  let previous=common.decision.executionWindow.notBeforeUtc;
  for(let i=0;i<predecessors.length;i++) {
    const row=predecessors[i],record=read(common.evidenceDirectory,row.pointer);
    need(record.schemaVersion===2,"new controller requires genuine cohort2 predecessors");
    previous=replay.replayRecordedCohort31({ctx:common.ctx,phase:row.phase,commandPointer:row.pointer,earliestUtc:previous,latestUtc,
      endpointRuntimeHashes:common.intentResult.labels,baseline:common.baseline,intent:common.intent,archiveExpectedFiles:common.inventory,
      predecessors:predecessors.slice(0,i)}).completedAtUtc;
  }
  return previous;
}
function write(root,file,value){return custody.save31(root,file,value);}
function supervise(configuration,common,phase,contextPointer) {
  const e=verifySelection(configuration,common),ctx=common.ctx,dir=custody.phaseDirectory31(ctx,phase);
  const outputDirectory=path.join(dir,"process"),requestFile=path.join(dir,"process-request.json");
  const environment={...e.environment,BUSINESS31_PHASE_CONTEXT_SHA256:contextPointer.sha256};
  write(ctx.evidenceDirectory,requestFile,{schemaVersion:1,parentPid:process.pid,supervisorSha256:SUPERVISOR_SHA,
    executable:ctx.runtime.nodeExecutable,arguments:custody.commandArguments31(ctx,phase),cwd:ctx.repoRoot,environment,outputDirectory,
    timeoutSeconds:e.limits.commandSeconds,maxOutputBytes:e.limits.outputBytes,cleanupSeconds:e.limits.cleanupSeconds});
  windowNow(ctx); // Last synchronous gate before launching the fixed owned child.
  const result=custody.runCohortSupervisor31({python:e.python,requestFile,evidenceDirectory:ctx.evidenceDirectory,
    directory:dir,environment:e.environment,limits:e.limits});
  const processPointer=custody.pointer31(ctx.evidenceDirectory,path.join(outputDirectory,"result.json"));
  const actual=read(ctx.evidenceDirectory,processPointer);
  need(!result.error&&result.status===0&&result.signal===null&&actual.status==="SUCCESS","owned phase process failed; automatic retry forbidden");
  verifySelection(configuration,common);
  return {processPointer,actual,stdout:custody.pointer31(ctx.evidenceDirectory,path.join(outputDirectory,"stdout.bin")),
    stderr:custody.pointer31(ctx.evidenceDirectory,path.join(outputDirectory,"stderr.bin"))};
}
async function runController31({configuration,configurationFile,configurationSha256}) {
  bootstrap.assertOperational31();
  need(sha(fs.readFileSync(x.physical(configurationFile)))===configurationSha256,"protected selection bytes changed");
  const common=replay.prepareBusinessOperationalCaptureContext31(authorityOptions(configuration));
  let failure;
  try { return await runControllerWithContext31(configuration,common); }
  catch(error) { failure=error;throw error; }
  finally {
    try { if(!common.cliLoadLease.isReleased())common.cliLoadLease.release(); }
    catch(cleanup) { throw failure?new AggregateError([failure,cleanup],"controller and CLI cleanup failed"):cleanup; }
  }
}
async function runControllerWithContext31(configuration,common) {
  const ctx=common.ctx;
  need(common.contract.schemaVersion===2,"new controller requires post-runtime contract2");
  verifySelection(configuration,common);cleanPoint(ctx);observe(common);
  const base=path.join(ctx.evidenceDirectory,"deployment-attempts",ctx.approvalPointer.sha256),attempts=path.dirname(base);
  if(!fs.existsSync(attempts))fs.mkdirSync(attempts,{mode:0o700});x.physical(attempts,true);
  fs.mkdirSync(base,{mode:0o700}); // Any partial or prior attempt forbids another launch.
  const configPointer=write(ctx.evidenceDirectory,path.join(base,"protected-selection.json"),configuration),predecessors=[];
  try {
    for(const phase of phases) {
      replayPrefix(common,predecessors,utc());verifySelection(configuration,common);observe(common);
      const dir=custody.phaseDirectory31(ctx,phase);fs.mkdirSync(dir,{mode:0o700});
      const claim=write(ctx.evidenceDirectory,path.join(dir,"phase-claim.json"),{schemaVersion:1,documentType:"build31-business-phase-claim",
        phase,source:ctx.source,approvalPointer:ctx.approvalPointer,predecessors:[...predecessors],claimedAtUtc:windowNow(ctx)});
      const parameterConfig=custody.createParameterConfig31(ctx,phase);
      const context=write(ctx.evidenceDirectory,path.join(dir,"context.json"),{schemaVersion:1,documentType:"build31-business-phase-context",
        phase,source:ctx.source,approvalPointer:ctx.approvalPointer,evidenceDirectory:ctx.evidenceDirectory,
        configuration:configPointer,claim,predecessors:[...predecessors],parameterConfig});
      const sourceBefore=cleanPoint(ctx),startedAtUtc=windowNow(ctx);
      const startValue={schemaVersion:1,documentType:"build31-business-cohort-start",phase,source:ctx.source,approvalPointer:ctx.approvalPointer,
        context,claim,predecessors:[...predecessors],startedAtUtc,executable:ctx.runtime.nodeExecutable,nodeSha256:ctx.runtime.nodeSha256,
        cwd:ctx.repoRoot,arguments:custody.commandArguments31(ctx,phase),sourceBefore,producerBindings:ctx.producerBindings,parameterConfig};
      const start=write(ctx.evidenceDirectory,path.join(dir,"attempt-start.json"),startValue);
      const measured=supervise(configuration,common,phase,context),child=read(ctx.evidenceDirectory,custody.pointer31(ctx.evidenceDirectory,path.join(dir,"phase-capture-result.json")));
      keys(child,["schemaVersion","documentType","phase","source","approvalPointer","context","start","capture","archive","mutations","completion","currentControls"],"phase output");
      need(child.schemaVersion===1&&child.documentType==="build31-business-phase-capture-result"&&child.phase===phase&&same(child.source,ctx.source)&&
        same(child.approvalPointer,ctx.approvalPointer)&&same(child.context,context)&&same(child.start,start),"actual child output identity differs");
      const names=phase==="fleet"?ctx.cohorts.schedulers:ctx.cohorts[phase];
      const record={schemaVersion:2,documentType:"build31-business-original-cohort",source:ctx.source,approvalPointer:ctx.approvalPointer,
        executionContractSha256:ctx.decision.executionContract.sha256,phase,functions:names,attempt:1,startedAtUtc,
        completedAtUtc:measured.actual.completedAtUtc,exitCode:0,signal:null,error:null,executable:ctx.runtime.nodeExecutable,nodeSha256:ctx.runtime.nodeSha256,
        cwd:ctx.repoRoot,arguments:startValue.arguments,cliArguments:["deploy","--only",names.map(n=>"functions:"+n).join(","),"--project","crm3-baf-ops-b8638","--non-interactive"],
        sourceBefore,sourceAfter:cleanPoint(ctx),producerBindings:ctx.producerBindings,stdout:measured.stdout,stderr:measured.stderr,
        capture:child.capture,archive:child.archive,currentControls:child.currentControls,mutations:child.mutations,completion:child.completion,
        context,start,process:measured.processPointer};
      const commandPointer=write(ctx.evidenceDirectory,path.join(dir,"attempt-result.json"),record);
      replay.replayRecordedCohort31({ctx,phase,commandPointer,earliestUtc:predecessors.length?read(ctx.evidenceDirectory,predecessors.at(-1).pointer).completedAtUtc:startedAtUtc,
        latestUtc:utc(),endpointRuntimeHashes:common.intentResult.labels,baseline:common.baseline,intent:common.intent,archiveExpectedFiles:common.inventory,predecessors});
      predecessors.push({phase,pointer:commandPointer});
    }
    return write(ctx.evidenceDirectory,path.join(base,"controller-complete.json"),{schemaVersion:1,documentType:"build31-business-controller-completion",
      source:ctx.source,approvalPointer:ctx.approvalPointer,commands:Object.fromEntries(predecessors.map(row=>[row.phase,row.pointer])),completedAtUtc:utc(),
      closureRecorded:false,postDeploymentReadbacksComplete:false,platformAuthenticationEstablishedByThisRecord:false});
  } catch(error) {
    try{write(ctx.evidenceDirectory,path.join(base,"controller-failed.json"),{schemaVersion:1,documentType:"build31-business-controller-failure",
      source:ctx.source,approvalPointer:ctx.approvalPointer,completedPhases:predecessors.map(row=>row.phase),failedAtUtc:utc(),automaticRetryAllowed:false,rawErrorRetained:false});}catch{}
    throw error;
  }
}

// Exact descriptor ownership lets cleanup preserve a foreign replacement even after failure.
function hookSlots(Client) {
  const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),Module=require("node:module");
  return [[Client.prototype,"request"],[https,"request"],[https,"get"],[http,"request"],[http,"get"],
    [net.Socket.prototype,"connect"],[tls,"connect"],[Module,"_load"],[globalThis,"fetch"]];
}
function denyParameterWrites() {
  const slots=[...['writeFileSync','writeFile','appendFileSync','appendFile'].map(name=>[fs,name]),
    [fs.promises,'writeFile'],[fs.promises,'appendFile']];
  return installOwned(slots,()=>{for(const [object,name] of slots){const original=object[name];object[name]=function(file,...args){
    const supplied=file instanceof URL?require('node:url').fileURLToPath(file):file;
    need(typeof supplied!=="string"||!path.basename(supplied).startsWith(".env"),"parameter env-file mutation is outside the approved scope");
    return original.call(this,file,...args);
  };}});
}
function installOwned(slots,action) {
  const frames=slots.map(([object,key])=>{const descriptor=Object.getOwnPropertyDescriptor(object,key);
    need(descriptor&&Object.hasOwn(descriptor,"value")&&descriptor.writable&&descriptor.configurable,"writable owned hook slot required");
    const f={object,key,descriptor,current:descriptor.value};f.get=()=>f.current;f.set=value=>{f.current=value;};return f;});
  let result,error,installed=0;
  try{for(const f of frames){Object.defineProperty(f.object,f.key,{configurable:true,enumerable:f.descriptor.enumerable,get:f.get,set:f.set});installed++;}result=action();}
  catch(e){error=e;}
  finally{for(const f of frames.slice(0,installed)){const d=Object.getOwnPropertyDescriptor(f.object,f.key);
    if(same(d,{configurable:true,enumerable:f.descriptor.enumerable,get:f.get,set:f.set}))Object.defineProperty(f.object,f.key,{...f.descriptor,value:f.current});else error??=Error("hook replaced during installation");}}
  const owned=frames.map(f=>({...f.descriptor,value:f.current}));
  const restore=()=>{let failed=false;frames.forEach((f,i)=>{const d=Object.getOwnPropertyDescriptor(f.object,f.key);if(same(d,f.descriptor))return;
    if(!same(d,owned[i])){failed=true;return;}Object.defineProperty(f.object,f.key,f.descriptor);});need(!failed,"foreign hook preserved; cleanup incomplete");};
  if(error){try{restore();}catch(cleanup){throw new AggregateError([error,cleanup],"hook installation/cleanup failed");}throw error;}
  return {result,assertOwned(){need(slots.every(([o,k],i)=>same(Object.getOwnPropertyDescriptor(o,k),owned[i])),"hook ownership changed");},restore};
}
async function runPhaseChild31({contextFile,contextSha256,configuration}) {
  bootstrap.assertOperational31();
  const input=json(fs.readFileSync(x.physical(contextFile))),phase=input.phase;
  const measured=recorder.createBusinessPhaseCapture31({authorityOptions:authorityOptions(configuration),phase,contextFile,contextSha256});
  const {writer,common,guardInputs}=measured,ctx=common.ctx;
  const admission={...ctx,projectId:"crm3-baf-ops-b8638",region:"asia-south1"};
  const lease=common.cliLoadLease,library=path.dirname(path.dirname(ctx.runtime.cliEntrypoint));
  let hook=null,boundary=null,parameterWrites=null,preparation=null,originalPrepare=null,prepareWrapper=null,currentControls=null,nativeConfig=null,active=false,finished=false;
  const fail=()=>{writer.failed=true;if(writer.active)writer.active.failed=true;};
  const cleanup=()=>{const errors=[];if(boundary){try{boundary.restore();}catch(e){errors.push(e);}boundary=null;}
    if(parameterWrites){try{parameterWrites.restore();}catch(e){errors.push(e);}parameterWrites=null;}
    if(preparation&&preparation.prepare===prepareWrapper)preparation.prepare=originalPrepare;
    else if(preparation&&preparation.prepare!==originalPrepare)errors.push(Error("foreign prepare wrapper retained"));
    if(hook){try{hook.restore();}catch(e){errors.push(e);}hook=null;}
    if(!lease.isReleased())try{lease.release();}catch(e){errors.push(e);}
    if(errors.length)throw new AggregateError(errors,"phase cleanup incomplete");};
  try {
    verifySelection(configuration,common);lease.assertHealthy();
    const api=require(path.join(library,"apiv2.js")),slots=hookSlots(api.Client);
    preparation=require(path.join(library,"deploy/functions/prepare.js"));originalPrepare=preparation.prepare;
    const unprepared=new neutral.RuntimeDeploymentTransportGuard31({...guardInputs,names:phase==="fleet"?ctx.cohorts.schedulers:ctx.cohorts[phase],allNames:ctx.cohorts.fleet,phase});
    const envelopeBytes=common.repository.readBlob(ctx.approvalPointer.commit,ctx.approvalPointer.file);
    hook=require("./captureBusiness31PreparedHook.cjs").installBusinessPreparedHook31({writer,phase,admission,envelopeBytes,
      archiveExpectedFiles:common.inventory,guardInputs});
    const actualHashWrapper=hook.module.applyBackendHashToBackends;
    const preparedTransition=function(...args){
      need(!active&&currentControls!==null,"fresh controls must precede actual hash invocation");
      need(nativeConfig,"governed native Config required before hash invocation");nativeConfig.assertUnchanged();
      boundary.assertOwned();boundary.restore();boundary=null;
      try{const value=actualHashWrapper.apply(this,args);hook.module.applyBackendHashToBackends=actualHashWrapper;hook.restore();hook=null;
        boundary=installOwned(slots,()=>recorder.installBusinessCapture31({Client:api.Client,writer,observeLive:()=>observe(common)}));
        active=true;return value;
      }catch(error){fail();throw error;}
    };
    hook.module.applyBackendHashToBackends=preparedTransition;
    // The hook's restore owns its original wrapper. Restore that reference only when this transition still owns it.
    const originalHookRestore=hook.restore;
    hook.restore=function(){if(hook.module.applyBackendHashToBackends===preparedTransition)hook.module.applyBackendHashToBackends=actualHashWrapper;return originalHookRestore();};
    let preparing=false;
    prepareWrapper=async function(...args){
      need(!preparing&&!active,"prepare cannot retry");preparing=true;windowNow(ctx);cleanPoint(ctx);
      const sourceConfig=json(common.repository.readBlob(ctx.source.commit,"firebase.json"));
      const {Config}=require(path.join(library,"config.js"));
      nativeConfig=custody.bindNativeConfig31({ctx,phase,parameterConfig:measured.context.parameterConfig,
        options:args[1],sourceFunctions:sourceConfig.functions,Config});
      const fixed=require("./scopedCallableInvokerIam.js");
      const raw=await collectCurrentBusinessControls31({sourceCommit:ctx.source.commit,approvalSha256:ctx.approvalPointer.sha256,
        read:(url,method,body)=>recorder.readCurrentControlResponse31(api.Client,url,method,body),unavailableRunRegion:fixed.unavailableRunRegion});
      currentControls=write(ctx.evidenceDirectory,path.join(custody.phaseDirectory31(ctx,phase),"current-cohort-controls.json"),raw);
      controls.verifyCurrentCohortControls31({repoRoot:ctx.repoRoot,sourceCommit:ctx.source.commit,evidenceDirectory:ctx.evidenceDirectory,
        beforePointer:x.pointerView(ctx.evidenceDirectory,common.baseline.controlsPointer),currentPointer:x.pointerView(ctx.evidenceDirectory,currentControls),
        schedulerBaseline:x.pointerView(ctx.evidenceDirectory,common.baseline.schedulerPointer),approvalSha256:ctx.approvalPointer.sha256,
        decisionAtUtc:ctx.decision.decidedAtUtc,phase,cohorts:ctx.cohorts,endpointRuntimeHashes:common.intentResult.labels,
        requiredProducerBindings:ctx.runtime.requiredProducerBindings,installedControlRuntime:ctx.runtime.installedControlRuntime});
      cleanPoint(ctx);windowNow(ctx);nativeConfig.assertUnchanged();
      const result=await originalPrepare.apply(this,args);nativeConfig.assertUnchanged();return result;
    };
    preparation.prepare=prepareWrapper;
    parameterWrites=denyParameterWrites();
    boundary=installOwned(slots,()=>{neutral.installNetworkBoundary31(unprepared);neutral.installApiBoundary31(api.Client,unprepared,()=>{throw Error("write before prepared comparison");});});
    process.once("exit",code=>{
      if(finished)return;finished=true;
      try{
        need(code===0&&active&&currentControls&&!writer.failed&&(writer.active?.pending??-1)===0,"actual CLI did not settle one complete phase");
        nativeConfig.assertUnchanged();boundary.assertOwned();const result=writer.finishCohort();need(result.complete,"phase capture incomplete");writer.finishPhase();
        cleanPoint(ctx);cleanup();
        write(ctx.evidenceDirectory,path.join(custody.phaseDirectory31(ctx,phase),"phase-capture-result.json"),{schemaVersion:1,documentType:"build31-business-phase-capture-result",
          phase,source:ctx.source,approvalPointer:ctx.approvalPointer,context:measured.contextPointer,start:measured.startPointer,
          capture:result.capture,archive:result.archive,mutations:result.mutations,completion:result.completion,currentControls});
      }catch(error){fail();try{cleanup();}catch{}process.exitCode=1;
        try{write(ctx.evidenceDirectory,path.join(custody.phaseDirectory31(ctx,phase),"phase-failed.json"),{schemaVersion:1,phase,failedAtUtc:utc(),automaticRetryAllowed:false,rawErrorRetained:false});}catch{}
      }
    });
    cleanPoint(ctx);windowNow(ctx);process.chdir(ctx.repoRoot);
    const names=phase==="fleet"?ctx.cohorts.schedulers:ctx.cohorts[phase];
    process.argv=[ctx.runtime.nodeExecutable,ctx.runtime.cliEntrypoint,"deploy","--only",names.map(n=>"functions:"+n).join(","),"--project","crm3-baf-ops-b8638","--non-interactive"];
    require(ctx.runtime.cliEntrypoint);
  }catch(error){fail();finished=true;try{cleanup();}catch(cleanupError){throw new AggregateError([error,cleanupError],"phase initialization and cleanup failed");}throw error;}
}
module.exports={runController31,runPhaseChild31,installOwned,denyParameterWrites,collectCurrentBusinessControls31};
