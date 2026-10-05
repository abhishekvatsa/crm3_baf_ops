"use strict";
const bootstrapEntry31 = require("./business31CaptureBootstrap.cjs");
if (!bootstrapEntry31.isComponentChild31("capture-recorder")) {
  bootstrapEntry31.runComponentSuiteTest31("capture-recorder");
} else {
"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),os=require("node:os"),path=require("node:path"),crypto=require("node:crypto"),zlib=require("node:zlib"),{EventEmitter}=require("node:events");
const root=path.resolve(__dirname,"../..");
const modulePath=path.join(__dirname,"captureBusiness31PreparedInputs.cjs");
const {BusinessCapture31,installBusinessCapture31,projectRequest,decodeResponse,LIMITS}=require(modulePath);
const transport=require(path.join(__dirname,"runtimeDeploymentTransportGuard31.cjs"));
const x=require(path.join(__dirname,"business31ExecutionContract.cjs"));
const hash=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const cohorts=x.cohortsFromPolicy(JSON.parse(fs.readFileSync(path.join(root,"release/function-fleet-runtime-identity-policy.json"))));
const SOURCE={commit:"a".repeat(40),tree:"b".repeat(40),functionsTree:"f".repeat(40)},APPROVAL={commit:"c".repeat(40),file:"release/approvals/build31-business-backend-deployment-approval.json",sha256:"D".repeat(64)};
const resource="projects/crm3-baf-ops-b8638/locations/asia-south1/functions/";
const ZIP=Buffer.from("synthetic retained ZIP bytes; archive parser qualified separately"),labels=Object.fromEntries(cohorts.fleet.map(n=>[n,hash(Buffer.from(n))]));
const baseline=Object.fromEntries(cohorts.fleet.map(n=>[n,{name:resource+n,labels:{"firebase-functions-hash":"prior",preserved:"synthetic"},buildConfig:{source:{storageSource:{bucket:"old",object:"old",generation:"1"}}},serviceConfig:{maxInstanceCount:20}}]));
function fixture(t,window){const dir=fs.mkdtempSync(path.join(os.tmpdir(),"business-capture-host-"));const epoch=Date.now(),clock=()=>new Date().toISOString();const writer=new BusinessCapture31({evidenceDirectory:dir,approvalPointer:APPROVAL,source:SOURCE,cohorts,now:clock});if(window!==false)writer.bindExecutionWindow(window??{notBeforeUtc:new Date(epoch-1000).toISOString(),notAfterUtc:new Date(epoch+3600000).toISOString()});t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return {dir,writer,clock};}
function start(f,phase="callables") {const capture={schemaVersion:1,documentType:"firebase-cli-prepared-backend-hash-inputs",actualCliPreparationCaptured:true,approvalPointer:APPROVAL,phase,source:SOURCE,sourceArchiveHash:"synthetic",endpointRuntimeHashes:labels,archiveSha256:hash(ZIP),archiveBytes:ZIP.length,completedAtUtc:f.clock()};return f.writer.startCohort({phase,capture,archive:ZIP,guardInputs:{baselineFunctions:baseline,projectNumber:"123456789"}});}
function read(f,p){return JSON.parse(fs.readFileSync(path.join(f.dir,p.file)));}
function injected(f,options={}) {
 const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),saved={https:https.request,http:http.request,net:net.Socket.prototype.connect,tls:tls.connect};
 // An accidentally attempted real socket cannot run, including a guard regression.
 net.Socket.prototype.connect=function(){throw Error("HOST TEST NETWORK FORBIDDEN");};tls.connect=function(){throw Error("HOST TEST TLS FORBIDDEN");};
 const requests=[],pending=[];
 https.request=function(input,opts,callback){const url=String(input);requests.push({url,method:opts.method,bytes:[]});const row=requests.at(-1),req=new EventEmitter();req.write=b=>{row.bytes.push(Buffer.from(b));return true;};req.destroy=e=>queueMicrotask(()=>req.emit("error",e));req.end=()=>{
  const dispatch=()=>{if(options.beforeResponse)options.beforeResponse();
   if(options.lost&&url.includes(options.lost)){req.emit("error",Error("SENSITIVE_INTERNAL_TOKEN_MUST_NOT_BE_CAPTURED"));return;}
   let status=options.status??200,plain=url.includes(":generateUploadUrl")?JSON.stringify({uploadUrl:"https://storage.googleapis.com/synthetic-upload?X-Goog-Signature=SYNTHETIC_PRIVATE_QUERY",storageSource:{bucket:"synthetic",object:"source.zip",generation:"1"}}):opts.method==="PUT"?"":JSON.stringify({name:"synthetic-operation"});
   const res=new EventEmitter();res.statusCode=status;res.headers={authorization:"SECRET_RESPONSE_HEADER",...(options.encoding?{"content-encoding":options.encoding}:{})};res.destroy=e=>{res.emit("error",e);req.emit("error",e);};
   const data=options.encoding==="gzip"?zlib.gzipSync(Buffer.from(plain)):Buffer.from(plain);res.decoded=plain;
   req.emit("response",res);if(data.length)res.emit("data",data);
   if(options.truncated&&url.includes(options.truncated)){res.emit("aborted");req.emit("error",Error("connection lost"));return;}
   res.emit("end");
  };
  if(options.parallel&&opts.method==="PATCH") {pending.push(dispatch);if(pending.length===f.writer.active.guard.names.length)for(const d of [...pending].reverse())queueMicrotask(d);}
  else queueMicrotask(dispatch);
  return req;
 };if(callback)req.once("response",callback);return req;};
 http.request=function(){throw Error("Unexpected HTTP in injected capture test");};
 class Client {constructor(opts){this.opts=opts;} async request(request){assert.equal(request.retries,0);assert.deepEqual(request.retryCodes,[]);if(options.beforeTransport)await options.beforeTransport();return new Promise((resolve,reject)=>{
   if(options.nestedCredential){const tokenReq=https.request("https://oauth2.googleapis.com/token",{method:"POST"},res=>{res.on("error",reject);});tokenReq.on("error",reject);tokenReq.write(Buffer.from("SECRET_REFRESH_TOKEN_BODY"));tokenReq.end();}
   const req=https.request(transport.urlOf(this,request),{method:request.method,headers:{Authorization:"SECRET_AUTH_HEADER"}},res=>{res.on("error",reject);res.on("end",()=>{if(res.statusCode>=300)return reject(Error("original API failure"));resolve({status:res.statusCode,body:res.decoded?JSON.parse(res.decoded):""});});});req.on("error",reject);
   const bytes=request.body==null?Buffer.alloc(0):request.body.path?fs.readFileSync(request.body.path):Buffer.from(JSON.stringify(request.body));if(options.beforeBody)options.beforeBody();if(bytes.length)req.write(options.changedWire?Buffer.concat([bytes,Buffer.from(" changed")]):bytes);req.end();
  });}}
 const restore=installBusinessCapture31({Client,writer:f.writer,observeLive:options.observeLive??(async()=>({observedAtUtc:f.clock(),completedAtUtc:f.clock(),syntheticObservation:true}))});
 return {Client,requests,restore(){restore();https.request=saved.https;http.request=saved.http;net.Socket.prototype.connect=saved.net;tls.connect=saved.tls;}};
}
async function firstTwo(f,env,startResult){const cli=new env.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",accessToken:"SECRET_CLIENT_TOKEN"});await cli.request({method:"POST",path:"projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl",body:null,headers:{authorization:"SECRET_REQUEST_HEADER"}});const up=new env.Client({urlPrefix:"https://storage.googleapis.com",apiVersion:""});await up.request({method:"PUT",path:"synthetic-upload",queryParams:{"X-Goog-Signature":"SYNTHETIC_PRIVATE_QUERY"},body:{path:startResult.archivePath}});return cli;}
function update(cli,name){return cli.request({method:"PATCH",path:resource+name,queryParams:{updateMask:"buildConfig.source,labels"},body:{...structuredClone(baseline[name]),labels:{"firebase-functions-hash":labels[name],preserved:"synthetic"},buildConfig:{source:{storageSource:{bucket:"synthetic",object:"source.zip",generation:"1"}}}}});}
async function all(f,phase,options={}) {const s=start(f,phase),env=injected(f,options);try{const cli=await firstTwo(f,env,s);await Promise.all(f.writer.active.guard.names.map(n=>update(cli,n)));const result=f.writer.finishCohort();return {result,requests:env.requests};}finally{env.restore();}}
test("all25 original mutations across13/5/1 retain independent parallel completion order",async t=>{const f=fixture(t),results=[];for(const p of ["callables","events","fleet"])results.push(await all(f,p,{parallel:true}));const result=f.writer.finish();assert.equal(result.mutationCount,25);assert.equal(result.deploymentAuthorized,false);assert.equal(results.reduce((n,v)=>n+v.requests.length,0),25);for(const {result:r} of results){const records=r.mutations.map(p=>read(f,p));assert.deepEqual(records.map(v=>v.sequence),records.map((_,i)=>i+1));assert.deepEqual(records.slice(2).map(v=>v.completionSequence),records.slice(2).map((_,i)=>records.length-i));assert.equal(read(f,records[1].response).bodyText,"");assert.equal(fs.readFileSync(path.join(f.dir,records[1].wireBody.file)).equals(ZIP),true);const complete=read(f,r.completion);assert.deepEqual(complete.events.map(v=>v.sequence),[1,2,...records.slice(2).reverse().map(v=>v.sequence)]);}
 const retained=f.writer.allBindings.map(p=>fs.readFileSync(path.join(f.dir,p.file)).toString()).join("\n");for(const secret of ["SECRET_AUTH_HEADER","SECRET_REQUEST_HEADER","SECRET_CLIENT_TOKEN","SECRET_RESPONSE_HEADER"])assert.equal(retained.includes(secret),false);assert.ok(retained.includes("SYNTHETIC_PRIVATE_QUERY"));
});
test("lost response is retained as failed original, forbids retry and later cohorts",async t=>{const f=fixture(t),s=start(f),env=injected(f,{lost:cohorts.callables[0]});try{const cli=await firstTwo(f,env,s);await assert.rejects(update(cli,cohorts.callables[0]));await assert.rejects(update(cli,cohorts.callables[0]));assert.equal(env.requests.length,3);const r=f.writer.finishCohort();assert.equal(r.complete,false);const mutation=read(f,r.mutations[2]);assert.equal(mutation.response,null);assert.equal(mutation.error.responseReceived,false);assert.equal(mutation.error.requestComplete,true);assert.equal(JSON.stringify(mutation).includes("SENSITIVE_INTERNAL_TOKEN"),false);assert.throws(()=>start(f,"events"));assert.throws(()=>f.writer.finish());}finally{env.restore();}});
test("original non2xx body retained without invented successful completion",async t=>{const f=fixture(t);start(f);const env=injected(f,{status:503});try{const cli=new env.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"});await assert.rejects(cli.request({method:"POST",path:"projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl",body:null}));const r=f.writer.finishCohort(),m=read(f,r.mutations[0]);assert.equal(r.complete,false);assert.equal(read(f,m.response).httpStatus,503);}finally{env.restore();}});
test("truncated response preserves bounded original prefix and remains failed",async t=>{const f=fixture(t);start(f);const env=injected(f,{truncated:":generateUploadUrl"});try{const cli=new env.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"});await assert.rejects(cli.request({method:"POST",path:"projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl",body:null}));const r=f.writer.finishCohort();assert.equal(read(f,r.mutations[0]).response,null);assert.equal(r.complete,false);}finally{env.restore();}});
test("bounded gzip response retains raw bytes and exact decoded original body",async t=>{const f=fixture(t);const {result:r}=await all(f,"callables",{encoding:"gzip"});assert.equal(r.complete,true);const first=read(f,r.mutations[0]);assert.match(read(f,first.response).bodyText,/uploadUrl/);const aux=read(f,{file:first.request.file.replace("-request.json","-wire-response-binding.json")});assert.equal(aux.contentEncoding,"gzip");assert.equal(zlib.gunzipSync(fs.readFileSync(path.join(f.dir,aux.responseRaw.file))).toString(),read(f,first.response).bodyText);});
test("unfinished requests cannot produce completion",t=>{const f=fixture(t);start(f);f.writer.active.pending=1;assert.throws(()=>f.writer.finishCohort(),/unfinished/);});
test("missing update remains incomplete even if guard observed other writes",async t=>{const f=fixture(t),s=start(f),env=injected(f);try{const cli=await firstTwo(f,env,s);await update(cli,cohorts.callables[0]);assert.equal(f.writer.finishCohort().complete,false);}finally{env.restore();}});
test("wrong cohort order rejected without an attempt directory",t=>{const f=fixture(t);assert.throws(()=>start(f,"events"));assert.equal(fs.existsSync(path.join(f.writer.base,"events")),false);});
test("existing attempt is never overwritten",t=>{const f=fixture(t);assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:APPROVAL,source:SOURCE,cohorts}));});
test("overlapping cohort populations rejected",t=>{const f=fixture(t);const bad=structuredClone(cohorts);bad.callables[0]=bad.events[0];assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:APPROVAL,source:SOURCE,cohorts:bad}));});
test("retained original tampering prevents final complete measurement",async t=>{const f=fixture(t);for(const p of ["callables","events","fleet"])await all(f,p);fs.appendFileSync(path.join(f.dir,f.writer.allBindings[0].file),"tamper");assert.throws(()=>f.writer.finish(),/original changed/);});
test("request projection excludes all client/request auth headers and options",()=>{assert.deepEqual(projectRequest({opts:{urlPrefix:"https://x.invalid",apiVersion:"v2",token:"SECRET"}},{method:"POST",path:"x",body:null,headers:{Authorization:"SECRET"},accessToken:"SECRET"}),{client:{urlPrefix:"https://x.invalid",apiVersion:"v2"},request:{method:"POST",path:"x",queryParams:null,body:null}});});
test("duplicate query keys refuse rather than changing saved identity",()=>{assert.throws(()=>projectRequest({opts:{urlPrefix:"https://x.invalid"}},{path:"x",queryParams:new URLSearchParams("a=1&a=2")}),/duplicate/);});
test("malformed UTF8 response is never replacement-decoded",()=>{assert.throws(()=>decodeResponse(Buffer.from([0xff]),null));});
test("unsupported compression and decompression expansion refuse",()=>{assert.throws(()=>decodeResponse(Buffer.from("x"),"unknown"));assert.throws(()=>decodeResponse(zlib.gzipSync(Buffer.alloc(LIMITS.response+1)),"gzip"));});
test("unchanged original helpers are reused by identity",()=>{const original=require(path.join(__dirname,"captureBackendRuntimePreparedInputs31.cjs"));const candidate=require(modulePath);assert.equal(candidate.captureActualPreparedInputs31,original.captureActualPreparedInputs31);assert.equal(candidate.readCurrentControlResponse31,original.readCurrentControlResponse31);});

test("nested credential-refresh request/response is excluded from mutation capture",async t=>{const f=fixture(t);const {result:r,requests}=await all(f,"callables",{nestedCredential:true});assert.equal(r.complete,true);assert.equal(r.mutations.length,15);assert.equal(requests.filter(v=>v.url==="https://oauth2.googleapis.com/token").length,15);const retained=f.writer.allBindings.map(p=>fs.readFileSync(path.join(f.dir,p.file)));
 const text=retained.map(bytes=>bytes.toString()).join("\n");assert.equal(text.includes("SECRET_REFRESH_TOKEN_BODY"),false);
 // Check retained evidence bytes for leakage; this is not URL host authorization.
 const retainedBytes=Buffer.concat(retained.flatMap((bytes,index)=>index?[Buffer.from("\n"),bytes]:[bytes]));
 assert.equal(retainedBytes.indexOf(Buffer.from("oauth2.googleapis.com","utf8")),-1);});
test("wire mutation is stopped by unchanged transport before any body is forwarded",async t=>{const f=fixture(t),s=start(f),env=injected(f,{changedWire:true});try{await assert.rejects(firstTwo(f,env,s));const r=f.writer.finishCohort();assert.equal(r.complete,false);const upload=read(f,r.mutations[1]);assert.equal(upload.wireBody.bytes,0);assert.equal(upload.error.requestComplete,false);assert.equal(env.requests[1].bytes.length,0);}finally{env.restore();}});
test("stale live observation prevents the original network request",async t=>{const f=fixture(t),s=start(f),env=injected(f,{observeLive:async()=>({observedAtUtc:"2026-01-01T00:00:00.000Z",completedAtUtc:"2026-01-01T00:00:00.000Z"})});try{await assert.rejects(firstTwo(f,env,s));assert.equal(env.requests.length,0);assert.equal(f.writer.finishCohort().complete,false);}finally{env.restore();}});
test("duplicate update cannot create a second transport or complete the cohort",async t=>{const f=fixture(t),s=start(f),env=injected(f);try{const cli=await firstTwo(f,env,s);await update(cli,cohorts.callables[0]);await assert.rejects(update(cli,cohorts.callables[0]),/retry forbidden/);assert.equal(env.requests.length,3);assert.equal(f.writer.finishCohort().complete,false);}finally{env.restore();}});
test("unapproved IAM mutation is refused with no network request",async t=>{const f=fixture(t);start(f);const env=injected(f);try{const cli=new env.Client({urlPrefix:"https://iam.googleapis.com",apiVersion:"v1"});await assert.rejects(cli.request({method:"POST",path:"projects/crm3-baf-ops-b8638/serviceAccounts/test:setIamPolicy",body:{policy:{}}}));assert.equal(env.requests.length,0);assert.equal(f.writer.finishCohort().complete,false);}finally{env.restore();}});

test("unexpected source or custody fields cannot become private credential storage",t=>{const f=fixture(t);assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:APPROVAL,source:{...SOURCE,token:"SECRET"},cohorts}));assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:{...APPROVAL,token:"SECRET"},source:SOURCE,cohorts}));});
test("OAuth token query is rejected rather than retained",()=>{assert.throws(()=>projectRequest({opts:{urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"}},{method:"POST",path:"x",queryParams:{access_token:"SECRET"},body:null}),/credential query/);});

test("full business source point and exact approval custody path are required",t=>{const f=fixture(t);assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:APPROVAL,source:{commit:SOURCE.commit,tree:SOURCE.tree},cohorts}));assert.throws(()=>new BusinessCapture31({evidenceDirectory:f.dir,approvalPointer:{...APPROVAL,file:"release/evidence/approval.json"},source:SOURCE,cohorts}));});

// Live expiry regressions: local clock and HTTPS peer are injected; no real network.
function deadlineFixture(t){
 const RealDate=globalThis.Date;let at=RealDate.UTC(2026,9,4);const end=at+1000;
 class TestDate extends RealDate{constructor(...args){super(...(args.length?args:[at]));}static now(){return at;}}
 globalThis.Date=TestDate;t.after(()=>{globalThis.Date=RealDate;});
 const window={notBeforeUtc:new RealDate(at-1000).toISOString(),notAfterUtc:new RealDate(end).toISOString()};
 const f=fixture(t,window);f.writer.now=()=>new Date().toISOString();f.clock=f.writer.now;
 return {...f,expire:()=>{at=end+1;},advance:ms=>{at+=ms;},window};
}
function generate(env){const c=new env.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"});return c.request({method:"POST",path:resource.slice(0,-1)+":generateUploadUrl",body:null});}
for(const delay of ["observer","persistence","client","body"]){
 test("deadline regression: "+delay+" crossing refuses original mutation and permits cleanup",async t=>{
  const f=deadlineFixture(t);start(f);const originalWrite=fs.writeFileSync;
  if(delay==="persistence")fs.writeFileSync=function(file,...args){const result=originalWrite.call(this,file,...args);if(String(file).endsWith("-intent.json"))f.expire();return result;};
  const options={};if(delay==="observer")options.observeLive=async()=>{f.expire();return {observedAtUtc:f.clock(),completedAtUtc:f.clock()};};
  if(delay==="client")options.beforeTransport=async()=>{await Promise.resolve();f.expire();};
  if(delay==="body")options.beforeBody=f.expire;
  const env=injected(f,options);let error;
  try{try{await generate(env);}catch(e){error=e;}
   assert.ok(error,"expired mutation was forwarded and returned success");assert.match(error.message,/execution window/);
   assert.equal(env.requests.length,delay==="body"?1:0);assert.equal(env.requests.reduce((n,r)=>n+r.bytes.length,0),0);
   assert.equal(f.writer.active.pending,0);assert.equal(f.writer.failed,true);
   const result=f.writer.finishCohort();assert.equal(result.complete,false);
   for(const p of result.mutations.filter(Boolean)){const record=read(f,p);assert.equal(record.schemaVersion,3);assert.equal(record.response,null);assert.ok(record.error);}
  }finally{fs.writeFileSync=originalWrite;env.restore();}
 });
}
test("deadline regression: serialized update queue cannot release writes after expiry",async t=>{
 const f=deadlineFixture(t),s=start(f);let release,queued=0;const gate=new Promise(r=>release=r);
 const env=injected(f,{observeLive:async operation=>{if(operation.kind==="function-update"){queued++;if(queued===1)await gate;}return {observedAtUtc:f.clock(),completedAtUtc:f.clock()};}});
 try{const c=await firstTwo(f,env,s),a=update(c,cohorts.callables[0]),b=update(c,cohorts.callables[1]);const done=Promise.allSettled([a,b]);
  await new Promise(r=>setImmediate(r));f.expire();release();const results=await done;
  assert.equal(results.every(r=>r.status==="rejected"),true,"queued expired updates succeeded");assert.equal(env.requests.length,2);assert.equal(f.writer.active.pending,0);assert.equal(f.writer.finishCohort().complete,false);
 }finally{env.restore();}
});

function boundDecisionFixture(t,edit){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),"business-deadline-decision-"));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const retain=(file,value)=>{const bytes=Buffer.from(JSON.stringify(value)+"\n");fs.writeFileSync(path.join(dir,file),bytes,{flag:"wx"});return {file,sha256:hash(bytes),bytes:bytes.length};};
 const T=d=>new Date(Date.now()+d).toISOString(),proof=retain("proof.json",{});
 const intent=retain("intent.json",{schemaVersion:1,documentType:"firebase-cli-approved-intended-hash-inputs",codebase:"default",source:SOURCE,sourceBefore:SOURCE,sourceAfter:SOURCE,completedAtUtc:T(-5000)});
 const contract=retain("contract.json",{schemaVersion:1,documentType:"build31-business-execution-contract",profile:"build31-exact-business-backend-v1",source:SOURCE,sourceManifestSha256:"A".repeat(64),runtimeProof:proof,preparedAtUtc:T(-4000),intendedHashInputs:intent});
 const decision={schemaVersion:2,documentType:"build31-business-backend-deployment-decision",profile:"build31-exact-business-backend-v1",source:SOURCE,sourceManifestSha256:"A".repeat(64),runtimeProof:proof,decidedAtUtc:T(-3000),executionContract:contract,executionWindow:{notBeforeUtc:T(-2000),notAfterUtc:T(60000)}};if(edit)edit(decision);
 const pointer=retain("decision.json",decision),envelopeBytes=Buffer.from(JSON.stringify({schemaVersion:1,documentType:"build31-business-private-record-custody",recordKind:"decision",source:SOURCE,privateRecord:pointer}));
 const writer=new BusinessCapture31({evidenceDirectory:dir,source:SOURCE,approvalPointer:{...APPROVAL,sha256:hash(envelopeBytes)},cohorts});
 return {dir,writer,envelopeBytes,decision};
}
test("deadline binding: exact retained decision drives immutable live window",t=>{
 const f=boundDecisionFixture(t),hook=require("./captureBusiness31PreparedHook.cjs");hook.bindIntent31(f);f.writer.assertExecutionWindow();
 f.writer.bindExecutionWindow({...f.decision.executionWindow});
 assert.throws(()=>f.writer.bindExecutionWindow({...f.decision.executionWindow,notAfterUtc:new Date(Date.now()+120000).toISOString()}),/cannot be rebound/);
 f.writer.now=()=>"2099-01-01T00:00:00.000Z";f.writer.assertExecutionWindow(); // Measurement clock is not live authority.
});
for(const [name,edit]of [["missing",d=>delete d.executionWindow],["extra",d=>d.executionWindow.extra=true],["invalid date",d=>d.executionWindow.notAfterUtc="2026-02-31T00:00:00Z"],["overlong",d=>d.executionWindow.notAfterUtc=new Date(Date.now()+7*3600000).toISOString()]])test("deadline binding: "+name+" bound decision refuses",t=>{const f=boundDecisionFixture(t,edit);assert.throws(()=>require("./captureBusiness31PreparedHook.cjs").bindIntent31(f));assert.throws(()=>f.writer.assertExecutionWindow(),/bound decision/);});
test("deadline binding: changed decision bytes refuse before window binding",t=>{const f=boundDecisionFixture(t);fs.appendFileSync(path.join(f.dir,"decision.json")," ");assert.throws(()=>require("./captureBusiness31PreparedHook.cjs").bindIntent31(f));assert.throws(()=>f.writer.assertExecutionWindow(),/bound decision/);});
test("deadline binding: missing live window refuses activation",t=>{const f=fixture(t,false);assert.throws(()=>start(f),/bound decision execution window/);assert.equal(f.writer.active,null);});
test("deadline settlement: a request begun within window may settle after expiry without fake rollback",async t=>{
 const f=deadlineFixture(t);start(f);const env=injected(f,{beforeResponse:f.expire});try{await generate(env);assert.equal(env.requests.length,1);assert.equal(f.writer.active.pending,0);const result=f.writer.finishCohort();assert.equal(result.complete,false);const record=read(f,result.mutations[0]);assert.equal(record.schemaVersion,3);require("./business31BackendClosure.cjs").verifyMutationInitiation31(record,f.window);assert.equal(read(f,record.response).httpStatus,200);assert.equal(record.error,null);assert.ok(record.startedAtUtc<=f.window.notAfterUtc&&record.completedAtUtc>f.window.notAfterUtc);}finally{env.restore();}
});


test("first outbound sample is real guard time after Client and body delays",async t=>{
 const f=deadlineFixture(t);start(f);const env=injected(f,{beforeTransport:async()=>{await Promise.resolve();f.advance(100);},beforeBody:()=>f.advance(100),beforeResponse:f.expire});
 try{await generate(env);const record=read(f,f.writer.finishCohort().mutations[0]);assert.equal(Date.parse(record.requestAdmittedAtUtc)-Date.parse(record.startedAtUtc),100);assert.equal(Date.parse(record.firstOutboundAtUtc)-Date.parse(record.requestAdmittedAtUtc),100);assert.ok(record.completedAtUtc>record.firstOutboundAtUtc);require("./business31BackendClosure.cjs").verifyMutationInitiation31(record,f.window);}finally{env.restore();}
});


for(const field of ["requestAdmittedAtUtc","firstOutboundAtUtc"])test("live boundary refuses prepopulated "+field+" and drains settled capture",async t=>{
 const f=deadlineFixture(t);start(f);const prepopulate=()=>{f.writer.active.records[0].record[field]=f.clock();};
 const env=injected(f,field==="requestAdmittedAtUtc"?{beforeTransport:async()=>prepopulate()}:{beforeBody:prepopulate});
 try{await assert.rejects(generate(env),/second mutation transport|already recorded/);assert.equal(env.requests.length,field==="requestAdmittedAtUtc"?0:1);assert.equal(env.requests.reduce((n,r)=>n+r.bytes.length,0),0);assert.equal(f.writer.active.pending,0);const result=f.writer.finishCohort();assert.equal(result.complete,false);assert.ok(read(f,result.mutations[0]).error);}finally{env.restore();}
});

}
