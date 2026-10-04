"use strict";
// Actual pinned modules; only HTTPS is replaced. No Firebase CLI entry or auth call.
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),zlib=require("node:zlib"),{Writable,PassThrough}=require("node:stream");
const root=path.resolve(__dirname,"../.."),cliRoot=path.join(root,"tooling/firebase-cli/node_modules/firebase-tools"),dependencyRoot=path.dirname(cliRoot);
const out=fs.mkdtempSync(path.join(fs.realpathSync(require("node:os").tmpdir()),"business31-capture-installed-"));
// This Node test worker owns the isolated profile; no user profile is changed.
const environmentKeys=new Set(["PATH","SYSTEMROOT","WINDIR","COMSPEC","PATHEXT","NODE_TEST_CONTEXT"]);
for(const key of Object.keys(process.env))if(!environmentKeys.has(key.toUpperCase()))delete process.env[key];
for(const key of ["HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","TEMP","TMP"]){
 const directory=path.join(out,key);fs.mkdirSync(directory);process.env[key]=directory;
}
process.env.CI="true";process.env.FIREBASE_CLI_DISABLE_UPDATE_CHECK="true";

const hash=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const net=require("node:net"),tls=require("node:tls"),cp=require("node:child_process");
net.Socket.prototype.connect=function(){throw Error("REAL SOCKET FORBIDDEN");};tls.connect=function(){throw Error("REAL TLS FORBIDDEN");};
for(const n of ["spawn","spawnSync","exec","execSync","execFile","execFileSync","fork"])cp[n]=()=>{throw Error("CHILD PROCESS FORBIDDEN");};
globalThis.fetch=()=>{throw Error("REAL FETCH FORBIDDEN");};
const api=require(path.join(cliRoot,"lib/apiv2.js")),storage=require(path.join(cliRoot,"lib/gcp/storage.js"));
assert.equal(require(path.join(cliRoot,"package.json")).version,"15.22.4");
const auth=require(path.join(cliRoot,"lib/auth.js"));auth.getAccessToken=()=>{throw Error("CREDENTIAL ACCESS FORBIDDEN");};auth.haveValidTokens=()=>{throw Error("CREDENTIAL ACCESS FORBIDDEN");};
const candidate=require("./captureBusiness31PreparedInputs.cjs"),neutral=require("./runtimeDeploymentTransportGuard31.cjs");
const x=require("./business31ExecutionContract.cjs");
const cohorts=x.cohortsFromPolicy(JSON.parse(fs.readFileSync(path.join(root,"release/function-fleet-runtime-identity-policy.json"))));
const SOURCE={commit:"a".repeat(40),tree:"b".repeat(40),functionsTree:"f".repeat(40)},APPROVAL={commit:"c".repeat(40),file:"release/approvals/build31-business-backend-deployment-approval.json",sha256:"D".repeat(64)};
const prefix="projects/crm3-baf-ops-b8638/locations/asia-south1/functions/",ZIP=Buffer.from("SYNTHETIC ZIP STREAM actual storage.upload path"),labels=Object.fromEntries(cohorts.fleet.map(n=>[n,hash(Buffer.from(n))]));
const baseline=Object.fromEntries(cohorts.fleet.map(n=>[n,{name:prefix+n,labels:{"firebase-functions-hash":"prior",preserved:"synthetic"},buildConfig:{source:{storageSource:{bucket:"old",object:"old",generation:"1"}}},serviceConfig:{maxInstanceCount:20}}]));
function make(name){const dir=path.join(out,name);fs.mkdirSync(dir);let tick=0;const epoch=Date.now(),now=()=>new Date(epoch+tick++).toISOString();const writer=new candidate.BusinessCapture31({evidenceDirectory:dir,source:SOURCE,approvalPointer:APPROVAL,cohorts,now});writer.bindExecutionWindow({notBeforeUtc:new Date(epoch-1000).toISOString(),notAfterUtc:new Date(epoch+3600000).toISOString()});return {dir,now,writer};}
function start(f,phase){return f.writer.startCohort({phase,capture:{schemaVersion:1,documentType:"firebase-cli-prepared-backend-hash-inputs",actualCliPreparationCaptured:true,approvalPointer:APPROVAL,phase,source:SOURCE,sourceArchiveHash:"synthetic",endpointRuntimeHashes:labels,archiveSha256:hash(ZIP),archiveBytes:ZIP.length,completedAtUtc:f.now()},archive:ZIP,guardInputs:{baselineFunctions:baseline,projectNumber:"123456789"}});}
function fakeHttps(f,{gzip=false,lost=false,status=200,parallel=false}={}) {
 const https=require("node:https"),http=require("node:http"),original={https:https.request,http:http.request};const calls=[],pending=[];
 https.request=function(input,opts,callback){const effective=neutral.effectiveRequest31(input,opts,"https:"),url=effective.url,method=effective.method;const row={url:url.href,method,wire:[]};calls.push(row);
  const dispatch=req=>{
   if(lost){const e=Error("synthetic lost response");e.code="ECONNRESET";req.emit("error",e);return;}
   const generated={uploadUrl:"https://storage.googleapis.com/synthetic?GoogleAccessId=SYNTHETIC&Signature=synthetic-private-query",storageSource:{bucket:"synthetic",object:"source.zip",generation:"1"}};
   const body=url.pathname.endsWith(":generateUploadUrl")?JSON.stringify(generated):method==="PUT"?"":JSON.stringify({name:"synthetic-operation"});
   const bytes=gzip&&body?zlib.gzipSync(Buffer.from(body)):Buffer.from(body),res=new PassThrough();
   res.statusCode=status;res.statusMessage=status===200?"OK":"synthetic failure";res.headers={"content-type":"application/json","content-length":String(bytes.length),"x-goog-generation":"1",...(gzip&&body?{"content-encoding":"gzip"}:{})};res.rawHeaders=Object.entries(res.headers).flat();res.complete=true;res.httpVersion="1.1";
   req.emit("response",res);res.end(bytes);
  };
  const req=new Writable({write(chunk,encoding,cb){row.wire.push(Buffer.from(chunk));cb();},final(cb){if(parallel&&method==="PATCH"){pending.push(()=>dispatch(req));if(pending.length===f.writer.active.guard.names.length)for(const d of [...pending].reverse())queueMicrotask(d);}else queueMicrotask(()=>dispatch(req));cb();}});
  req.abort=()=>req.destroy();req.setTimeout=()=>req;req.getHeader=()=>undefined;
  if(typeof opts==="function")req.once("response",opts);if(callback)req.once("response",callback);return req;
 };
 http.request=()=>{throw Error("UNEXPECTED HTTP FORBIDDEN");};
 const restore=candidate.installBusinessCapture31({Client:api.Client,writer:f.writer,observeLive:async()=>({observedAtUtc:f.now(),completedAtUtc:f.now(),syntheticObservation:true})});
 return {calls,restore(){restore();https.request=original.https;http.request=original.http;}};
}
async function execute(f,phase,options={}){const retained=start(f,phase),network=fakeHttps(f,options);try{
 const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});
 // Actual generateUploadUrl implementation calls Client.post with undefined body.
 const generated=await client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl");
 assert.equal(network.calls[0].wire.reduce((n,b)=>n+b.length,0),0);
 const upload=await storage.upload({stream:fs.createReadStream(retained.archivePath)},generated.body.uploadUrl,{},true);assert.equal(upload.generation,"1");
 assert.equal(Buffer.concat(network.calls[1].wire).equals(ZIP),true);
 await Promise.all(f.writer.active.guard.names.map(name=>client.patch(prefix+name,{...structuredClone(baseline[name]),labels:{"firebase-functions-hash":labels[name],preserved:"synthetic"},buildConfig:{source:{storageSource:generated.body.storageSource}}},{queryParams:{updateMask:"buildConfig.source,labels"}})));
 const result=f.writer.finishCohort();assert.equal(result.complete,true);return {result,calls:network.calls};
 }finally{network.restore();}}
test("actual installed apiv2, node-fetch and storage.upload produce all25 captured raw events",async()=>{const f=make("all25"),results=[];for(const phase of ["callables","events","fleet"])results.push(await execute(f,phase,{parallel:true}));const final=f.writer.finish();assert.equal(final.mutationCount,25);assert.equal(results.reduce((n,v)=>n+v.calls.length,0),25);assert.ok(results[0].result.mutations.map(p=>JSON.parse(fs.readFileSync(path.join(f.dir,p.file)))).some(r=>r.sequence!==r.completionSequence));fs.writeFileSync(path.join(f.dir,"RESULT.json"),JSON.stringify(final,null,2));});
test("actual installed node-fetch decompresses while writer retains raw gzip originals",async()=>{const f=make("gzip");const {result}=await execute(f,"callables",{gzip:true});const first=JSON.parse(fs.readFileSync(path.join(f.dir,result.mutations[0].file)));assert.match(JSON.parse(fs.readFileSync(path.join(f.dir,first.response.file))).bodyText,/uploadUrl/);});
test("actual installed CLI retries remain zero after lost response",async()=>{const f=make("lost");start(f,"callables");const network=fakeHttps(f,{lost:true});try{const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});await assert.rejects(client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl"));assert.equal(network.calls.length,1);assert.equal(f.writer.finishCohort().complete,false);}finally{network.restore();}});
test("actual installed CLI non2xx response remains a retained failure",async()=>{const f=make("status503");start(f,"callables");const network=fakeHttps(f,{status:503});try{const client=new api.Client({urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2",auth:false});await assert.rejects(client.post("projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl"));assert.equal(network.calls.length,1);const result=f.writer.finishCohort(),record=JSON.parse(fs.readFileSync(path.join(f.dir,result.mutations[0].file)));assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,record.response.file))).httpStatus,503);assert.equal(result.complete,false);}finally{network.restore();}});
test.after(()=>{const loaded={};for(const name of Object.keys(require.cache))if(name.startsWith(dependencyRoot+path.sep))loaded[path.relative(dependencyRoot,name).split(path.sep).join("/")]=hash(fs.readFileSync(name));assert.ok(loaded["firebase-tools/lib/apiv2.js"]);assert.ok(loaded["firebase-tools/lib/gcp/storage.js"]);assert.ok(Object.keys(loaded).some(p=>p.endsWith("node-fetch/lib/index.js")));assert.equal(Object.keys(loaded).some(p=>p.endsWith("firebase-tools/lib/bin/firebase.js")),false);fs.writeFileSync(path.join(out,"INSTALLED_MODULE_BINDINGS.json"),JSON.stringify({firebaseToolsVersion:"15.22.4",loaded,network:"All HTTPS supplied by local fake Writable/PassThrough; real net/TLS/child processes throw",auth:"Every Client auth:false; signed storage.upload auth:false; fresh empty private config/home",cliEntryLoaded:false,completePrepareHookTested:false},null,2));});
