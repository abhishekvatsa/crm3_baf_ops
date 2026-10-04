"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),cp=require("node:child_process");
const {Writable,PassThrough}=require("node:stream");
const root=path.resolve(__dirname,"../..");
const out=fs.mkdtempSync(path.join(require("node:os").tmpdir(),"business31-capture-session-"));
// Node's test worker owns this environment; the caller's profile is never modified.
const environmentKeys=new Set(["PATH","SYSTEMROOT","WINDIR","COMSPEC","PATHEXT","NODE_TEST_CONTEXT"]);
for(const key of Object.keys(process.env))if(!environmentKeys.has(key.toUpperCase()))delete process.env[key];
for(const key of ["HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","TEMP","TMP"]){
 const directory=path.join(out,key);fs.mkdirSync(directory);process.env[key]=directory;
}
process.env.CI="true";process.env.FIREBASE_CLI_DISABLE_UPDATE_CHECK="true";
const exec=cp.execFileSync;cp.execFileSync=(file,args,options)=>{assert.match(String(file),/(?:^|[\\/])git(?:\.exe)?$/i);const at=Date.now();fs.appendFileSync(path.join(out,"git-observations.jsonl"),JSON.stringify({event:"start",at,arguments:args})+"\n");try{return exec(file,args,{...options,timeout:Math.min(options?.timeout??30000,30000)});}finally{fs.appendFileSync(path.join(out,"git-observations.jsonl"),JSON.stringify({event:"end",elapsedMs:Date.now()-at})+"\n");}};
for(const n of ["spawn","spawnSync","exec","execSync","execFile","fork"])cp[n]=()=>{throw Error("NON-GIT CHILD FORBIDDEN");};
require("node:net").Socket.prototype.connect=()=>{throw Error("REAL SOCKET FORBIDDEN");};require("node:tls").connect=()=>{throw Error("REAL TLS FORBIDDEN");};globalThis.fetch=()=>{throw Error("REAL FETCH FORBIDDEN");};
const BASE=require("./business31CaptureFixture.cjs").createCaptureFixture31(out);
const cli=path.join(root,"tooling/firebase-cli/node_modules/firebase-tools/lib"),api=require(path.join(cli,"apiv2.js")),storage=require(path.join(cli,"gcp/storage.js"));
const auth=require(path.join(cli,"auth.js"));auth.getAccessToken=auth.haveValidTokens=()=>{throw Error("CREDENTIAL ACCESS FORBIDDEN");};
const {BusinessCaptureSession31}=require("./business31CaptureSession.cjs"),neutral=require("./backendRuntimeClosure31.cjs"),transport=require("./runtimeDeploymentTransportGuard31.cjs");
const hash=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const x=require("./business31ExecutionContract.cjs");
const cohorts=x.cohortsFromPolicy(JSON.parse(fs.readFileSync(path.join(root,"release/function-fleet-runtime-identity-policy.json"))));
const runtime={cliEntrypoint:path.join(cli,"bin/firebase.js"),instrumentationProducerSha256:Object.fromEntries(Object.entries({api:"apiv2.js",apply:"deploy/functions/cache/applyHash.js",prepare:"deploy/functions/prepare.js",backend:"deploy/functions/backend.js"}).map(([k,p])=>[k,hash(fs.readFileSync(path.join(cli,p)))])),endpointHashProducerSha256:Object.fromEntries(Object.entries({apply:"deploy/functions/cache/applyHash.js",hash:"deploy/functions/cache/hash.js",secrets:"functions/secrets.js"}).map(([k,p])=>[k,hash(fs.readFileSync(path.join(cli,p)))]))};
const prefix="projects/crm3-baf-ops-b8638/locations/asia-south1/functions/";
function fixture() {
 const dir=fs.mkdtempSync(path.join(out,"fixture-")),evidence=path.join(dir,"evidence");fs.mkdirSync(evidence);
 const archive=path.join(dir,"original-source.zip");fs.copyFileSync(BASE.archive,archive);
 const retain=(name,value)=>{const b=Buffer.from(JSON.stringify(value,null,2)+"\n");fs.writeFileSync(path.join(evidence,name),b,{flag:"wx"});return {file:name,sha256:hash(b),bytes:b.length};};
 const checked=neutral.verifyArchiveBytes31(fs.readFileSync(archive),BASE.archiveExpectedFiles),now=Date.now(),T=d=>new Date(now+d).toISOString();
 const env={GCLOUD_PROJECT:"crm3-baf-ops-b8638",FIREBASE_CONFIG:'{"projectId":"crm3-baf-ops-b8638"}',CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:"false",CRM3_INSPECTION_READING_V2_AUTHORING_ENABLED:"false"};
 const endpoints=Object.fromEntries(cohorts.fleet.map(id=>[id,{id,platform:"gcfv2",project:"crm3-baf-ops-b8638",region:"asia-south1",secretEnvironmentVariables:[{key:"SYNTHETIC_CONFIG",secret:"synthetic-name",projectId:"crm3-baf-ops-b8638",version:"1"}]}]));
 const intent={schemaVersion:1,documentType:"firebase-cli-approved-intended-hash-inputs",codebase:"default",source:BASE.source,sourceBefore:BASE.source,sourceAfter:BASE.source,sourceArchiveHash:checked.sourceArchiveHash,startedAtUtc:T(-4000),completedAtUtc:T(-3000),environmentVariables:env,endpoints};
 const intentPointer=retain("intent.json",intent),proof=retain("runtime-proof.json",{syntheticLocalFixture:true}),contract={schemaVersion:1,documentType:"build31-business-execution-contract",profile:"build31-exact-business-backend-v1",source:BASE.source,sourceManifestSha256:"A".repeat(64),runtimeProof:proof,preparedAtUtc:T(-2000),intendedHashInputs:intentPointer};
 const contractPointer=retain("execution-contract.json",contract),decision={schemaVersion:2,documentType:"build31-business-backend-deployment-decision",profile:contract.profile,source:BASE.source,sourceManifestSha256:contract.sourceManifestSha256,runtimeProof:proof,decidedAtUtc:T(-1000),executionWindow:{notBeforeUtc:T(-500),notAfterUtc:T(3600000)},executionContract:contractPointer};
 const dp=retain("decision.json",decision),envelopeBytes=Buffer.from(JSON.stringify({schemaVersion:1,documentType:"build31-business-private-record-custody",recordKind:"decision",source:BASE.source,privateRecord:dp}));
 const approvalPointer={commit:"c".repeat(40),file:"release/approvals/build31-business-backend-deployment-approval.json",sha256:hash(envelopeBytes)};
 const admission={repoRoot:BASE.repository,source:BASE.source,approvalPointer,cohorts,projectId:"crm3-baf-ops-b8638",region:"asia-south1",runtime};
 const baseline=Object.fromEntries(cohorts.fleet.map(n=>[n,{name:prefix+n,labels:{"firebase-functions-hash":"prior",preserved:"synthetic"},buildConfig:{source:{storageSource:{bucket:"old",object:"old",generation:"1"}}},serviceConfig:{maxInstanceCount:20}}]));
 const options={evidenceDirectory:evidence,source:BASE.source,approvalPointer,cohorts,admission,envelopeBytes,archiveExpectedFiles:BASE.archiveExpectedFiles,guardInputs:{baselineFunctions:baseline,projectNumber:"123456789"},observeLive:async()=>({observedAtUtc:new Date().toISOString(),completedAtUtc:new Date().toISOString(),syntheticObservation:true})};
 return {dir,evidence,archive,intent,baseline,options,executionWindow:decision.executionWindow,newPrepared() {
  return {wantBackends:{default:{environmentVariables:structuredClone(env),endpoints:{"asia-south1":structuredClone(endpoints)}}},
   context:{sources:{default:{functionsSourceV2:archive,functionsSourceV2Hash:checked.sourceArchiveHash}}}};
 }};
}
function network(f,{holdLost=false}={}) {
 const https=require("node:https"),http=require("node:http"),original={https:https.request,http:http.request};const calls=[];let held,started;
 const startedPromise=new Promise(resolve=>started=resolve);
 https.request=function(input,opts,callback){const effective=transport.effectiveRequest31(input,opts,"https:"),url=effective.url,method=effective.method;const row={url:url.href,method,wire:[]};calls.push(row);
  const dispatch=req=>{
   if(holdLost){const e=Error("synthetic lost response");e.code="ECONNRESET";req.emit("error",e);return;}
   const generated={uploadUrl:"https://storage.googleapis.com/synthetic?GoogleAccessId=SYNTHETIC&Signature=synthetic-private-query",storageSource:{bucket:"synthetic",object:"source.zip",generation:"1"}};
   const body=url.pathname.endsWith(":generateUploadUrl")?JSON.stringify(generated):method==="PUT"?"":JSON.stringify({name:"synthetic-operation"});
   const bytes=Buffer.from(body),res=new PassThrough();res.statusCode=200;res.statusMessage="OK";res.headers={"content-type":"application/json","content-length":String(bytes.length),"x-goog-generation":"1"};res.rawHeaders=Object.entries(res.headers).flat();res.complete=true;res.httpVersion="1.1";req.emit("response",res);res.end(bytes);
  };
  const req=new Writable({write(chunk,encoding,cb){row.wire.push(Buffer.from(chunk));cb();},final(cb){
   if(holdLost){held=()=>dispatch(req);started();}
   else if(method==="PATCH"){f.pending.push(()=>dispatch(req));if(f.pending.length===f.session.writer.active.guard.names.length){const pending=f.pending.splice(0);for(const d of pending.reverse())queueMicrotask(d);}}
   else queueMicrotask(()=>dispatch(req));cb();}});
  req.abort=()=>req.destroy();req.setTimeout=()=>req;req.getHeader=()=>undefined;if(typeof opts==="function")req.once("response",opts);if(callback)req.once("response",callback);return req;
 };
 http.request=()=>{throw Error("UNEXPECTED HTTP FORBIDDEN");};
 f.pending=[];return {calls,started:startedPromise,release(){assert.ok(held);held();},restore(){https.request=original.https;http.request=original.http;}};
}
function verifyTranscript(f,result){
 const read=p=>{const b=fs.readFileSync(path.join(f.evidence,p.file));assert.equal(b.length,p.bytes);assert.equal(hash(b),p.sha256);return JSON.parse(b);};
 const capture=read(result.capture),guard=new transport.RuntimeDeploymentTransportGuard31({...f.options.guardInputs,names:result.phase==="fleet"?cohorts.schedulers:cohorts[result.phase],allNames:cohorts.fleet,phase:result.phase,sourceArchiveHash:capture.sourceArchiveHash,endpointRuntimeHashes:capture.endpointRuntimeHashes});guard.preparedMatches(capture);
 const completions=[];
 for(const p of result.mutations){const row=read(p),request=read(row.request),response=read(row.response),wire=fs.readFileSync(path.join(f.evidence,row.wireBody.file));assert.equal(hash(wire),row.wireBody.sha256);assert.equal(row.schemaVersion,3);require("./business31BackendClosure.cjs").verifyMutationInitiation31(row,f.executionWindow);require("./business31BackendClosure.cjs").verifyMutationResponse31(f.evidence,row.response,row.responseBinding);assert.equal(row.error,null);assert.equal(response.httpStatus,200);
  const binding=read(row.responseBinding),raw=fs.readFileSync(path.join(f.evidence,binding.responseRaw.file));assert.equal(raw.length,binding.responseRaw.bytes);assert.equal(hash(raw),binding.responseRaw.sha256);assert.equal(binding.httpStatus,response.httpStatus);assert.equal(binding.responseComplete,true);assert.equal(binding.retainedBytes,raw.length);assert.equal(require("./captureBusiness31PreparedInputs.cjs").decodeResponse(raw,binding.contentEncoding),response.bodyText);const op=guard.before({opts:request.client},request.request);assert.equal(transport.bodyBinding31(request.request),hash(wire));guard.after(op,{body:op.kind==="generate-upload"?JSON.parse(response.bodyText):undefined});completions.push(row);}
 guard.assertComplete();assert.deepEqual(completions.map(x=>x.sequence),Array.from({length:result.mutations.length},(_,i)=>i+1));assert.deepEqual(completions.map(x=>x.completionSequence).sort((a,b)=>a-b),completions.map(x=>x.sequence));
 assert.equal(fs.readFileSync(path.join(f.evidence,result.archive.file)).equals(fs.readFileSync(f.archive)),true);
 const complete=read(result.completion);assert.deepEqual(complete.events,completions.sort((a,b)=>a.completionSequence-b.completionSequence).map(v=>({kind:v.kind,sequence:v.sequence,...(v.name?{name:v.name}:{})})));return completions;
}
async function allMutations(f,phase){
 const prep=f.newPrepared();f.session.beginPhase(phase);assert.equal(f.session.capturePrepared(prep.wantBackends,prep.context),undefined);
 const archive=f.session.prepared.retainedArchivePath;assert.equal(prep.context.sources.default.functionsSourceV2,archive);
 const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});
 const generated=await client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl");
 assert.equal((await storage.upload({stream:fs.createReadStream(archive)},generated.body.uploadUrl,{},true)).generation,"1");
 const capture=f.session.writer.active.capture;
 await Promise.all(f.session.writer.active.guard.names.map(name=>client.patch(prefix+name,{...structuredClone(f.baseline[name]),labels:{"firebase-functions-hash":capture.endpointRuntimeHashes[name],preserved:"synthetic"},buildConfig:{source:{storageSource:generated.body.storageSource}}},{queryParams:{updateMask:"buildConfig.source,labels"}})));
 return f.session.closePhase();
}
test("one actual installed hash/apiv2/storage session captures all13/5/1 and25 raw events",async()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);
 try{const phases=[];for(const phase of ["callables","events","fleet"]){const result=await allMutations(f,phase);phases.push(result);verifyTranscript(f,result);}
  const final=f.session.finish();assert.equal(final.measurement.mutationCount,25);assert.equal(final.measurement.functions,19);assert.equal(n.calls.length,25);assert.equal(final.operationalController,false);assert.equal(final.prepareEntryInvokedByAdapter,false);assert.equal(final.deploymentAuthorized,false);
  assert.ok(phases[0].mutations.map(p=>JSON.parse(fs.readFileSync(path.join(f.evidence,p.file)))).some(row=>row.sequence!==row.completionSequence));
  fs.writeFileSync(path.join(out,"ALL25_RESULT.json"),JSON.stringify(final,null,2)+"\n");
 }finally{f.session.dispose();n.restore();}
});
test("preparation boundary refuses actual Client and direct HTTP before any wire",async()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);try{
  const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});assert.throws(()=>client.post("anything"),/outside prepared/);assert.equal(n.calls.length,0);assert.throws(()=>require("node:https").request("https://example.invalid"),/outside prepared/);assert.equal(n.calls.length,0);assert.throws(()=>f.session.beginPhase("callables"),/RETRY/);assert.throws(()=>f.session.finish(),/COMPLETE/);
 }finally{f.session.dispose();n.restore();}
});
test("wrong cohort and premature finish are irreversible before any expensive capture",()=>{
 for(const action of [s=>s.beginPhase("events"),s=>s.finish()]){const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);try{assert.throws(()=>action(f.session));assert.throws(()=>f.session.beginPhase("callables"),/RETRY/);assert.equal(n.calls.length,0);}finally{f.session.dispose();n.restore();}}
});
test("one pending then lost installed response preserves failure and refuses retry and foreign restoration",async()=>{
 const f=fixture(),n=network(f,{holdLost:true});f.session=new BusinessCaptureSession31(f.options);const prep=f.newPrepared();f.session.beginPhase("callables");f.session.capturePrepared(prep.wantBackends,prep.context);
 try{const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});const pending=client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl");const rejection=assert.rejects(pending);await n.started;assert.throws(()=>f.session.closePhase(),/PENDING/);
  const stillOwned=f.session._snapshot(),pendingCount=f.session.writer.active.pending;
  assert.throws(()=>f.session.dispose(),/PENDING/);assert.deepEqual(f.session._snapshot(),stillOwned);assert.equal(f.session.writer.active.pending,pendingCount);assert.equal(pendingCount,1);assert.equal(f.session.inflight,1);
  assert.equal(n.calls.length,1);n.release();await rejection;
  const foreign=()=>{};require("node:https").request=foreign;
  assert.throws(()=>f.session.closePhase(),/OWNERSHIP|cleanup incomplete/);assert.equal(require("node:https").request,foreign);assert.equal(f.session.cleanupIncomplete,true);
  assert.throws(()=>f.session.beginPhase("callables"),/RETRY/);assert.throws(()=>f.session.beginPhase("events"),/RETRY/);assert.equal(n.calls.length,1);
  assert.throws(()=>f.session.dispose(),/cleanup or failure/);assert.equal(require("node:https").request,foreign);
  const failure=path.join(f.session.writer.base,"callables/mutation-0001.json"),row=JSON.parse(fs.readFileSync(failure));assert.equal(row.error.responseReceived,false);assert.equal(row.error.requestComplete,true);assert.equal(row.response,null);assert.ok(fs.existsSync(path.join(f.session.writer.base,"callables/instrumented-capture-failed.json")));const before=hash(fs.readFileSync(failure));assert.throws(()=>f.session.finish(),/COMPLETE/);assert.equal(hash(fs.readFileSync(failure)),before);
 }finally{if(f.session.state!=="disposed")f.session.dispose();n.restore();}
});

test("existing attempt is never reused and does not install another boundary",()=>{const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);try{const owned=api.Client.prototype.request;assert.throws(()=>new BusinessCaptureSession31(f.options),/EEXIST/);assert.equal(api.Client.prototype.request,owned);}finally{f.session.dispose();n.restore();}});
test("initial receipt failure installs no global hooks",()=>{
 const f=fixture(),n=network(f),request=api.Client.prototype.request,https=require("node:https"),originalHttps=https.request,write=fs.writeFileSync;
 fs.writeFileSync=function(file,...args){if(String(file).endsWith("session-start.json"))throw Error("INJECTED_INITIAL_WRITE_FAILURE");return write.call(this,file,...args);};
 try{assert.throws(()=>new BusinessCaptureSession31(f.options),/INJECTED_INITIAL/);assert.equal(api.Client.prototype.request,request);assert.equal(https.request,originalHttps);}finally{fs.writeFileSync=write;n.restore();}
});
test("exact synchronous install transaction rolls back partial writes after failure",()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);const before=f.session._snapshot();
 try{assert.throws(()=>f.session._transaction(()=>{require("node:https").request=()=>{};api.Client.prototype.request=()=>{};throw Error("INJECTED_PARTIAL_INSTALL_FAILURE");}),/INJECTED_PARTIAL/);assert.deepEqual(f.session._snapshot(),before);}finally{f.session.dispose();n.restore();}
});
test("transaction preserves a foreign descriptor replacement and reports incomplete cleanup",()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);const https=require("node:https"),descriptor=Object.getOwnPropertyDescriptor(https,"request"),foreign=()=>{};
 try{assert.throws(()=>f.session._transaction(()=>{api.Client.prototype.request=()=>{};Object.defineProperty(https,"request",{...descriptor,value:foreign});throw Error("INJECTED_INSTALL_FAILURE_WITH_FOREIGN_HOOK");}),/INJECTED_INSTALL/);assert.equal(https.request,foreign);assert.equal(f.session.cleanupIncomplete,true);
  assert.throws(()=>f.session.dispose(),/cleanup incomplete|cleanup or failure/);assert.equal(https.request,foreign);
 }finally{n.restore();}
});
test("failed failure-receipt persistence cannot skip owned-hook cleanup",()=>{
 const f=fixture(),n=network(f),beforeClient=api.Client.prototype.request,https=require("node:https"),beforeHttps=https.request;f.session=new BusinessCaptureSession31(f.options);const write=fs.writeFileSync;
 fs.writeFileSync=function(file,...args){if(String(file).startsWith(f.evidence))throw Error("INJECTED_EVIDENCE_DISK_FAILURE");return write.call(this,file,...args);};
 try{assert.throws(()=>f.session.dispose(),/persistence incomplete/);assert.equal(api.Client.prototype.request,beforeClient);assert.equal(https.request,beforeHttps);assert.equal(f.session.persistenceFailed,true);assert.equal(f.session.cleanupIncomplete,false);}finally{fs.writeFileSync=write;n.restore();}
});
test("same owned function with foreign descriptor flags is preserved and cleanup reported incomplete",()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);const https=require("node:https"),owned=Object.getOwnPropertyDescriptor(https,"request");
 const foreign={...owned,enumerable:!owned.enumerable};Object.defineProperty(https,"request",foreign);
 try{assert.throws(()=>f.session.dispose(),/cleanup incomplete|cleanup or failure/);assert.deepEqual(Object.getOwnPropertyDescriptor(https,"request"),foreign);assert.equal(f.session.cleanupIncomplete,true);}
 finally{Object.defineProperty(https,"request",owned);n.restore();}
});
for(const failedSuffix of ["mutation-0001-wire.bin","mutation-0001.json"])
test("settled request evidence failure restores owned hooks: "+failedSuffix,async()=>{
 const f=fixture(),n=network(f);f.session=new BusinessCaptureSession31(f.options);
 const baseline=f.session.base,prep=f.newPrepared();f.session.beginPhase("callables");f.session.capturePrepared(prep.wantBackends,prep.context);
 const write=fs.writeFileSync;
 fs.writeFileSync=function(file,...args){if(String(file).endsWith(failedSuffix))throw Error("INJECTED_END_WRITE_FAILURE");return write.call(this,file,...args);};
 try {
  const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});
  await assert.rejects(client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl"),/INJECTED_END_WRITE_FAILURE/);
  fs.writeFileSync=write;assert.equal(n.calls.length,1);assert.equal(f.session.inflight,0);assert.equal(f.session.writer.active.pending,0);
  const settled=f.session.writer.active.records[0];assert.equal(settled.success,false);assert.equal(settled.finalized,true);assert.equal(settled.record.error.code,"ORIGINAL_CAPTURE_FINALIZATION_FAILED");assert.deepEqual(settled.wire,[]);assert.deepEqual(settled.responseChunks,[]);
  assert.throws(()=>f.session.writer.end({item:settled},false),/already finalized/);assert.equal(f.session.writer.active.pending,0);
  assert.doesNotThrow(()=>f.session.dispose());
  assert.deepEqual(f.session._snapshot(),baseline);assert.equal(f.session.writer.failed,true);assert.equal(f.session.cleanupIncomplete,false);
  assert.ok(fs.existsSync(path.join(f.session.writer.base,"callables/instrumented-capture-failed.json")));
  assert.ok(!fs.existsSync(path.join(f.session.writer.base,"callables/instrumented-cli-complete.json")));
  assert.throws(()=>f.session.finish(),/COMPLETE/);
 } finally {
  fs.writeFileSync=write;
  // Test-only cleanup retains the genuine old failure without leaking hooks to the test worker.
  if(f.session.state!=="disposed"){try{f.session.dispose();}catch{}if(f.session.owner)f.session._restoreOwned(baseline,f.session.owner);}
  n.restore();
 }
});

test.after(()=>{const files={};for(const name of Object.keys(require.cache))if(name.startsWith(path.dirname(path.dirname(cli))+path.sep))files[path.relative(path.dirname(path.dirname(cli)),name).split(path.sep).join("/")]=hash(fs.readFileSync(name));assert.ok(files["firebase-tools/lib/deploy/functions/cache/applyHash.js"]);assert.ok(files["firebase-tools/lib/apiv2.js"]);assert.ok(files["firebase-tools/lib/gcp/storage.js"]);assert.ok(Object.keys(files).some(p=>p.endsWith("node-fetch/lib/index.js")));assert.equal(Object.keys(files).some(p=>p.endsWith("/prepare.js")||p.endsWith("/bin/firebase.js")),false);fs.writeFileSync(path.join(out,"INSTALLED_MODULE_BINDINGS.json"),JSON.stringify({files,actualFullPrepare:false,realNetwork:false,authInvoked:false,operationalAuthority:false},null,2)+"\n");});
