"use strict";
// Every cloud/owner/CI record below is SYNTHETIC. Only local Git and pure helpers run.
const test=require("node:test"), assert=require("node:assert/strict"), fs=require("node:fs"), os=require("node:os"), path=require("node:path"), cp=require("node:child_process");
const base=__dirname, x=require(path.join(base,"business31ExecutionContract.cjs")), a=require(path.join(base,"business31BackendAuthority.cjs"));
const closure=require(path.join(base,"business31BackendClosure.cjs")), neutral=require(path.join(base,"backendRuntimeClosure31.cjs")), old=require(path.join(base,"backendRuntimeAdmission31.cjs"));
const gate=require(path.join(base,"backendRuntimeExecutionAdmission31.cjs")),zlib=require("node:zlib");
for(const name of ["node:http","node:https"]) { const api=require(name); api.request=api.get=()=>{throw Error("No network permitted in synthetic closure fixture");}; }
globalThis.fetch=()=>{throw Error("No network permitted in synthetic closure fixture");};
const temp=fs.mkdtempSync(path.join(os.tmpdir(),"business31-closure-")), evidence=path.join(temp,"evidence"), repo=path.join(temp,"repository");
fs.mkdirSync(evidence);fs.mkdirSync(repo);const h=x.sha;let serial=0;
const retain=value=>{const bytes=Buffer.isBuffer(value)?value:Buffer.from(typeof value==="string"?value:JSON.stringify(value));const file="original-"+(++serial)+".json";fs.writeFileSync(path.join(evidence,file),bytes);return {file,bytes:bytes.length,sha256:h(bytes)};};
const read=p=>x.privateBytes(evidence,p), j=p=>x.json(read(p));
test.after(()=>{assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));fs.rmSync(temp,{recursive:true});});
const gitExecutable=process.env.BUSINESS31_TEST_GIT||(process.platform==="win32"?"C:/Program Files/Git/mingw64/bin/git.exe":"/usr/bin/git");
const env={...process.env};for(const key of Object.keys(env))if(/^GIT_/i.test(key))delete env[key];
Object.assign(env,{GIT_CONFIG_NOSYSTEM:"1",GIT_CONFIG_GLOBAL:process.platform==="win32"?"NUL":"/dev/null",GIT_AUTHOR_NAME:"Synthetic only",GIT_AUTHOR_EMAIL:"fixture@example.invalid",GIT_COMMITTER_NAME:"Synthetic only",GIT_COMMITTER_EMAIL:"fixture@example.invalid"});
const git=(args,input)=>cp.execFileSync(gitExecutable,["-c","protocol.allow=never","-c","core.hooksPath="+path.join(temp,"no-hooks"),"-c","commit.gpgsign=false","-C",repo,...args],{env,input,encoding:"utf8",windowsHide:true,timeout:30000}).trim();
git(["init","--initial-branch=main"]);const tree=git(["mktree"],"");const commit=parents=>git(["commit-tree",tree,...parents.flatMap(p=>["-p",p]),"-m","Synthetic raw closure only"]);
const ancestor=commit([]), left=commit([ancestor]), right=git(["commit-tree",tree,"-p",ancestor,"-m","Synthetic reviewed branch"]), M=commit([left,right]);git(["update-ref","refs/heads/main",M]);
const source={commit:M,tree,functionsTree:"3".repeat(40)}, baseline={commit:x.BASELINE,tree:"4".repeat(40),functionsTree:"5".repeat(40)};
const cohorts={callables:Array.from({length:13},(_,i)=>"call"+String(i).padStart(2,"0")),events:Array.from({length:5},(_,i)=>"event"+i),schedulers:["scheduled" ]};cohorts.fleet=[...cohorts.callables,...cohorts.events,...cohorts.schedulers].sort();
const T=n=>new Date(Date.UTC(2026,0,2,2,0,n)).toISOString();
function ci(kind,id,pr){return {schemaVersion:1,evidenceType:kind==="release"?"github-exact-main-release-gate":"github-exact-main-codeql",repository:"abhishekvatsa/crm3_baf_ops",sourceCommit:M,sourceTree:tree,capturedAtUtc:T(50),pullRequest:pr,run:{id,run_attempt:1,repository:{full_name:"abhishekvatsa/crm3_baf_ops"},head_sha:M,head_branch:"main",event:"push",path:kind==="release"?".github/workflows/release-gate.yml":".github/workflows/codeql.yml",status:"completed",conclusion:"success",created_at:T(10),updated_at:T(40)},jobs:{total_count:(kind==="release"?old.RELEASE_JOBS:old.SECURITY_JOBS).length,jobs:(kind==="release"?old.RELEASE_JOBS:old.SECURITY_JOBS).map((name,i)=>({id:id*100+i,run_id:id,run_attempt:1,head_sha:M,name,status:"completed",conclusion:"success",completed_at:T(30)}))}};}
const issue="https://api.github.com/repos/abhishekvatsa/crm3_baf_ops/issues/999",request={id:1,issue_url:issue,body:"Review "+right,created_at:T(-20)},response={id:2,issue_url:issue,body:"No major issues. **Reviewed commit:** `"+right+"`",created_at:T(-10),user:{login:"chatgpt-codex-connector[bot]"},performed_via_github_app:{slug:"chatgpt-codex-connector"}};
const pr={number:999,merged:true,merge_commit_sha:M,merged_at:T(0),head:{sha:right},base:{ref:"main",repo:{full_name:"abhishekvatsa/crm3_baf_ops"}}};
const release=ci("release",11,pr),security=ci("security",12,pr),review={kind:"bot-issue-comment-no-findings",reviewer:"chatgpt-codex-connector[bot]",headCommit:right,request:{id:1,bodySha256:h(Buffer.from(request.body))},response:{id:2,bodySha256:h(Buffer.from(response.body))}};
const liveApproval={decidedAtUtc:T(100),normalMergeParents:[left,right],mainCiRun:{id:11,runAttempt:1},securityCiRun:{id:12,runAttempt:1},settledSourceReview:review};
const runtime={githubExecutable:process.execPath,githubExecutableSha256:h(fs.readFileSync(process.execPath))};
function observation(start){const raw=v=>JSON.stringify(v),main={ref:"refs/heads/main",object:{sha:M}};return {observer:{executable:runtime.githubExecutable,sha256:runtime.githubExecutableSha256},observedAtUtc:T(start),completedAtUtc:T(start+1),main:raw(main),finalMain:raw(main),pr:raw(pr),release:{run:raw(release.run),jobs:raw(release.jobs)},security:{run:raw(security.run),jobs:raw(security.jobs)},review:raw(response),reviewRequest:raw(request),reviewSummary:null,threads:raw({data:{repository:{pullRequest:{reviews:{nodes:[],pageInfo:{hasNextPage:false}},reviewThreads:{nodes:[],pageInfo:{hasNextPage:false}}}}}})};}
function zip(entries){const local=[],central=[];let offset=0;for(const[name,bytes]of Object.entries(entries)){const n=Buffer.from(name),header=Buffer.alloc(30),directory=Buffer.alloc(46),crc=neutral.crc32(bytes);header.writeUInt32LE(0x04034b50);header.writeUInt16LE(20,4);header.writeUInt32LE(crc,14);header.writeUInt32LE(bytes.length,18);header.writeUInt32LE(bytes.length,22);header.writeUInt16LE(n.length,26);directory.writeUInt32LE(0x02014b50);directory.writeUInt16LE(20,4);directory.writeUInt16LE(20,6);directory.writeUInt32LE(crc,16);directory.writeUInt32LE(bytes.length,20);directory.writeUInt32LE(bytes.length,24);directory.writeUInt16LE(n.length,28);directory.writeUInt32LE(offset,42);local.push(header,n,bytes);central.push(directory,n);offset+=header.length+n.length+bytes.length;}
 const c=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(Object.keys(entries).length,8);end.writeUInt16LE(Object.keys(entries).length,10);end.writeUInt32LE(c.length,12);end.writeUInt32LE(offset,16);return Buffer.concat([...local,c,end]);}
const entries={"package.json":Buffer.from('{"synthetic":true}'),"lib/index.js":Buffer.from("// synthetic emitted bytes, never executed\n")};
const manifest=Object.fromEntries(Object.entries(entries).map(([name,b])=>[name,{bytes:b.length,sha256:h(b)}]));const archive=retain(zip(entries)), checked=neutral.verifyArchiveBytes31(read(archive),manifest);
const labels=Object.fromEntries(cohorts.fleet.map(name=>[name,"a".repeat(40)])),resource="projects/crm3-baf-ops-b8638/locations/asia-south1/functions/";
function mutationFixture(phase="callables",endpointLabels=labels) {
 const names=phase==="fleet"?cohorts.schedulers:cohorts[phase], baselineFunctions=Object.fromEntries(cohorts.fleet.map(name=>[name,{name:resource+name,buildConfig:{runtime:"nodejs22",entryPoint:name,source:{storageSource:{bucket:"old",object:"old",generation:"1"}}},labels:{"firebase-functions-hash":"b".repeat(40),preserved:"yes"},serviceConfig:{maxInstanceCount:20,environmentVariables:{CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:"false"}}}]));
 const baselineRaw={controls:{project:{bodyText:'{"projectNumber":"123"}'}}}, baseline={baselineFunctions,raw:baselineRaw,scheduler:{}};
 const capture={sourceArchiveHash:checked.sourceArchiveHash,endpointRuntimeHashes:endpointLabels,archiveSha256:archive.sha256,archiveBytes:archive.bytes,completedAtUtc:T(110)};
 const ctx={repoRoot:repo,evidenceDirectory:evidence,source,runtime,cohorts,liveApproval};const command={completedAtUtc:T(250)};const records=[];
 function append(kind,name,client,options,wire,responseBody){
  const index=records.length,start=112+index*4,bodyText=typeof responseBody==="string"?responseBody:JSON.stringify(responseBody);
  const responseRaw=retain(Buffer.from(bodyText)),responseBinding=retain({responseRaw,contentEncoding:null,responseComplete:true,retainedBytes:responseRaw.bytes,httpStatus:200});
  records.push(retain({schemaVersion:2,documentType:"build31-business-original-mutation",phase,sequence:index+1,completionSequence:index+1,kind,name,startedAtUtc:T(start+2),completedAtUtc:T(start+3),request:retain({client,request:options}),wireBody:retain(wire),response:retain({httpStatus:200,bodyText}),responseBinding,liveObservation:retain(observation(start)),error:null}));
 }
 const location={bucket:"synthetic",object:"source",generation:"2"},uploadUrl="https://storage.googleapis.com/synthetic-"+phase+"?proof=synthetic";
 append("generate-upload",null,{urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"},{method:"POST",path:resource.slice(0,-1)+":generateUploadUrl",queryParams:{},body:null},Buffer.alloc(0),{uploadUrl,storageSource:location});
 append("source-upload",null,{urlPrefix:"https://storage.googleapis.com",apiVersion:""},{method:"PUT",path:"synthetic-"+phase,queryParams:{proof:"synthetic"},body:{path:path.join(evidence,archive.file)}},read(archive),"");
 for(const name of names){const body=structuredClone(baselineFunctions[name]);body.buildConfig.source.storageSource=location;body.labels["firebase-functions-hash"]=endpointLabels[name];append("function-update",name,{urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"},{method:"PATCH",path:resource+name,queryParams:{updateMask:"buildConfig.source,labels"},body},Buffer.from(JSON.stringify(body)),{});}
 return {ctx,phase,command,capture,baseline,records,archivePointer:archive};
}
const replay=f=>closure.replayMutationTranscript31(f);
const change=(f,index,fn)=>{const row=j(f.records[index]);fn(row);f.records[index]=retain(row);};
test("synthetic three-cohort composition replays real ZIP, original live Git/CI/review and all25 pure transport mutations",()=>{const results=["callables","events","fleet"].map(phase=>replay(mutationFixture(phase)));assert.equal(results.reduce((n,r)=>n+r.mutationCount,0),25);assert.equal(results.flatMap(r=>r.events).filter(r=>r.kind==="function-update").length,19);assert.ok(results.every(r=>!Object.hasOwn(r,"deploymentAuthorized")&&!Object.hasOwn(r,"ok")));});
for(const [name,pattern,mutate]of [
 ["missing mutation",/complete generate/,f=>f.records.pop()], ["extra mutation",/complete generate/,f=>f.records.push(f.records[0])], ["reordered mutations",/mutation order/,f=>[f.records[0],f.records[1]]=[f.records[1],f.records[0]]],
 ["retry sequence",/mutation order/,f=>change(f,2,r=>r.sequence=2)], ["failed completion",/mutation order/,f=>change(f,2,r=>r.error="failure")],
 ["wrong cohort",/mutation order/,f=>change(f,2,r=>r.phase="events")], ["wrong endpoint",/mutation order/,f=>change(f,2,r=>r.name="other")],
 ["wire bytes differ",/original wire body differs/,f=>change(f,2,r=>r.wireBody=retain("changed"))],
 ["changed preserved control",/Unapproved Function control/,f=>change(f,2,r=>{const q=j(r.request);q.request.body.serviceConfig.maxInstanceCount=21;r.request=retain(q);r.wireBody=retain(JSON.stringify(q.request.body));})],
 ["failed HTTP response",/successful original response/,f=>change(f,2,r=>r.response=retain({httpStatus:500,bodyText:"{}"}))],
 ["stale live source",/main moved|Current main|source|live main/i,f=>change(f,2,r=>{const o=j(r.liveObservation);o.finalMain=JSON.stringify({ref:"refs/heads/main",object:{sha:"0".repeat(40)}});r.liveObservation=retain(o);})],
 ["unresolved live review",/thread/i,f=>change(f,2,r=>{const o=j(r.liveObservation),q=JSON.parse(o.threads);q.data.repository.pullRequest.reviewThreads.nodes.push({isResolved:false});o.threads=JSON.stringify(q);r.liveObservation=retain(o);})],
 ["changed upload identity",/upload original archive/,f=>change(f,1,r=>{const q=j(r.request);q.request.body.path=path.join(evidence,"other.zip");r.request=retain(q);})],
 ["observation after write",/per-write observation/,f=>change(f,2,r=>{const o=j(r.liveObservation);o.completedAtUtc=r.completedAtUtc;r.liveObservation=retain(o);})],
 ["truncated pointer",/private original bytes/,f=>{f.records[2]={...f.records[2],bytes:f.records[2].bytes-1};}],
 ["malformed generation response",/invalid private JSON/,f=>change(f,0,r=>{r.response=retain({httpStatus:200,bodyText:""});const responseRaw=retain(Buffer.alloc(0));r.responseBinding=retain({responseRaw,contentEncoding:null,responseComplete:true,retainedBytes:0,httpStatus:200});})],
 ["duplicate completion order",/completion population/,f=>change(f,2,r=>r.completionSequence=2)],
 ["update before upload completion",/completed ZIP upload/,f=>change(f,2,r=>{r.startedAtUtc=T(118);r.completedAtUtc=T(123);} )],
])test("raw composition refuses "+name,()=>{const f=mutationFixture("fleet");mutate(f);assert.throws(()=>replay(f),pattern);});
for(const [name,mutate]of [["missing member",m=>delete m["lib/index.js"]],["extra member",m=>m["other"]={bytes:0,sha256:h(Buffer.alloc(0))}],["changed M bytes",m=>m["lib/index.js"].sha256="0".repeat(64)]])test("complete ZIP refuses "+name,()=>{const m=structuredClone(manifest);mutate(m);assert.throws(()=>neutral.verifyArchiveBytes31(read(archive),m));});

test("successful GCS upload keeps its actual empty body; no invented JSON",()=>{const f=mutationFixture("fleet");assert.equal(j(j(f.records[1]).response).bodyText,"");assert.equal(replay(f).mutationCount,3);assert.equal(j(j(f.records[1]).response).bodyText,"");});
test("parallel updates retain initiation order and independently reversed completion order",()=>{
 const f=mutationFixture("events"), count=f.records.length;
 // Start in reverse endpoint order. Complete in opposite order with overlap.
 const updates=f.records.slice(2).reverse().map(j);
 updates.forEach((r,i)=>{r.sequence=i+3;r.completionSequence=count-i;r.startedAtUtc=T(130+i);r.completedAtUtc=T(160-i);r.liveObservation=retain(observation(120+i));f.records[i+2]=retain(r);});
 const r=replay(f);assert.deepEqual(r.events.filter(e=>e.kind==="function-update").map(e=>e.sequence),[7,6,5,4,3]);
});

function contractFixture() {
 const runtimeProof=retain({synthetic:true}), intended=retain({synthetic:true});
 const selected={...review,request:{...review.request,original:retain(request)},response:{...review.response,original:retain(response)},summary:null};
 const contract={schemaVersion:1,documentType:"build31-business-execution-contract",profile:x.PROFILE,source,baseline,sourceManifestSha256:"A".repeat(64),runtimeProof,preparedAtUtc:T(70),intendedHashInputs:intended,githubObserver:{path:process.execPath,sha256:runtime.githubExecutableSha256},settledSourceReview:selected};
 return {contract,decision:{runtimeProof,decidedAtUtc:T(100)},proof:{completedAtUtc:T(60)},source,baseline,manifestSha256:"A".repeat(64),ownerReceivedAtUtc:T(80),read,instant:a.instant,mergeParents:[left,right],release,security};
}
test("versioned intent derives Git/CI selectors from original inputs with distinct F and M",()=>{const f=contractFixture(),r=x.verifyExecutionContract31(f);assert.notEqual(f.baseline.commit,f.source.commit);assert.deepEqual(r.approval.normalMergeParents,[left,right]);assert.deepEqual(r.approval.mainCiRun,{id:11,runAttempt:1});assert.equal(r.approval.settledSourceReview.response.bodySha256,review.response.bodySha256);assert.equal(Object.hasOwn(r,"deploymentAuthorized"),false);});
for(const [name,edit,pattern]of [
 ["extra runtime map",f=>f.contract.installedControlRuntime={},/fields differ/],
 ["wrong baseline",f=>f.contract.baseline={...baseline,commit:M},/source\/baseline/],
 ["late intent",f=>f.contract.preparedAtUtc=T(81),/postdates consent/],
 ["different runtime",f=>f.contract.runtimeProof=retain({changed:true}),/source\/baseline\/runtime/],
 ["different reviewed source",f=>f.contract.settledSourceReview.headCommit=left,/source review differs/],
 ["altered original review",f=>f.contract.settledSourceReview.response.original=retain({...response,body:"Issues found"}),/review original/],
 ["wrong observer bytes",f=>f.contract.githubObserver.sha256="0".repeat(64),/observer bytes/],
])test("execution contract refuses "+name,()=>{const f=contractFixture();edit(f);assert.throws(()=>x.verifyExecutionContract31(f),pattern);});
function ownerFixture(version=2){const executionContract=version===2?retain(contractFixture().contract):undefined,extra=version===2?{executionContractSha256:executionContract.sha256}:{};
 const original={schemaVersion:version,documentType:"retained-direct-human-production-deployment-instruction",source,question:a.ownerQuestion31(source,executionContract?.sha256),answer:"Approve exact-source production backend deployment",messageId:"synthetic-no-human",conversationId:"synthetic-local-test",receivedAtUtc:T(80),provenance:"operator-retained-direct-human-message",humanIdentityMachineAuthenticated:false,...extra};
 const owner={schemaVersion:version,documentType:"build31-business-source-specific-owner-record",source,scope:a.SCOPE,authorizedAtUtc:T(80),recordedAtUtc:T(85),originalMessage:retain(original),...extra};
 return {owner,original,source,decisionAtUtc:T(100),lastCiAtUtc:T(50),executionContract};}
test("schema2 owner binds exact contract in both digest and question; schema1 stays preparation-only compatible",()=>{assert.doesNotThrow(()=>a.validateOwner31(ownerFixture()));assert.doesNotThrow(()=>a.validateOwner31(ownerFixture(1)));});
for(const [name,edit]of [["digest",f=>f.owner.executionContractSha256="0".repeat(64)],["question",f=>f.original.question=a.ownerQuestion31(source)],["synthetic authenticated flag",f=>f.original.humanIdentityMachineAuthenticated=true],["old schema",f=>f.owner.schemaVersion=1]])test("owner contract refuses changed "+name,()=>{const f=ownerFixture();edit(f);assert.throws(()=>a.validateOwner31(f));});

function intended(){return {sourceArchiveHash:checked.sourceArchiveHash,environmentVariables:{GCLOUD_PROJECT:"crm3-baf-ops-b8638",CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:"false"},endpoints:Object.fromEntries(cohorts.fleet.map(id=>[id,{id,platform:"gcfv2",project:"crm3-baf-ops-b8638",region:"asia-south1",secretEnvironmentVariables:[{key:"SYNTHETIC_A",secret:"synthetic-a",projectId:"crm3-baf-ops-b8638",version:"1"},{key:"SYNTHETIC_B",secret:"synthetic-b",projectId:"crm3-baf-ops-b8638",version:"2"}]}]))};}
test("exact ordered environment and secret metadata are retained",()=>{const i=intended();assert.doesNotThrow(()=>closure.verifyOrderedIntent31(structuredClone(i),i,cohorts.fleet));});
for(const [name,edit]of [["environment order",i=>i.environmentVariables=Object.fromEntries(Object.entries(i.environmentVariables).reverse())],["secret order",i=>i.endpoints.call00.secretEnvironmentVariables.reverse()],["secret version",i=>i.endpoints.call00.secretEnvironmentVariables[0].version="2"],["extra endpoint",i=>i.endpoints.other=i.endpoints.call00],["missing endpoint",i=>delete i.endpoints.call00],["extra field",i=>i.endpoints.call00.unapproved=true],["archive",i=>i.sourceArchiveHash="0".repeat(40)]])test("ordered intent refuses "+name,()=>{const i=intended(),c=structuredClone(i);edit(c);assert.throws(()=>closure.verifyOrderedIntent31(c,i,cohorts.fleet));});

const access=require(path.join(base,"backendRuntimeEvidenceAccess31.cjs"));
function relocation(){const bundle=fs.mkdtempSync(path.join(temp,"bundle-")),dir=path.join(bundle,"raw");fs.mkdirSync(dir);const originalRoot="Z:/original-business-proof",bytes=Buffer.from('{"path":"C:/unchanged/original","synthetic":true}'),file="record.json";fs.writeFileSync(path.join(dir,file),bytes);const pointer={file,bytes:bytes.length,sha256:h(bytes)},members=[{path:"raw/"+file,bytes:bytes.length,sha256:h(bytes)}];return {bundle,dir,bytes,pointer,originalRoot,config:{privateBundleRoot:bundle,relocation:{schemaVersion:1,roots:[{original:originalRoot,memberRoot:"raw"}],files:[]},members,evidenceDirectory:originalRoot}};}
test("Windows original strings and pointer3 remain exact during bounded physical relocation and pointer2 view",()=>{const r=relocation();access.runRelocated31(r.config,()=>{assert.deepEqual(x.privateBytes(r.originalRoot,r.pointer),r.bytes);assert.deepEqual(x.pointerView(r.originalRoot,r.pointer),{file:r.pointer.file,sha256:r.pointer.sha256});assert.equal(x.json(x.privateBytes(r.originalRoot,r.pointer)).path,"C:/unchanged/original");});assert.deepEqual(fs.readFileSync(path.join(r.dir,r.pointer.file)),r.bytes);});
for(const [name,edit,pattern]of [["missing mapping",r=>r.originalRoot="Y:/not-mapped",/no unique immutable relocation/],["overlapping mapping",r=>r.config.relocation.roots.push({original:r.originalRoot+"/nested",memberRoot:"raw"}),/Overlapping/],["unlisted file",r=>r.config.members=[],/Unlisted/],["changed mapped bytes",r=>fs.appendFileSync(path.join(r.dir,r.pointer.file)," "),/changed/],["wrong byte count",r=>r.pointer.bytes++,/changed/],["pointer extra field",r=>r.pointer.accepted=true,/fields differ/]])test("relocation refuses "+name,()=>{const r=relocation();edit(r);assert.throws(()=>access.runRelocated31(r.config,()=>x.privateBytes(r.originalRoot,r.pointer)),pattern);});

const projectRoot=path.resolve(process.env.BUSINESS31_TEST_PROJECT_ROOT||path.join(__dirname,"../..")),controls=require(path.join(base,"backendRuntimeControls31.cjs")),iam=require(path.join(projectRoot,"tools/release/scopedCallableInvokerIam.js"));
const policy=JSON.parse(fs.readFileSync(path.join(projectRoot,"release/function-fleet-runtime-identity-policy.json"))),rawFactory=require("./business31RawControlsFixture.cjs");
function rawPair(){const names=Object.keys(policy.functionBindings),opts={policy,sourceCommit:M,approvalSha256:"A".repeat(64)};return {before:rawFactory.makeRawControls({...opts,startedAtUtc:T(51),completedAtUtc:T(52),outputTag:"before",endpointLabels:Object.fromEntries(names.map(n=>[n,"1".repeat(40)]))}),after:rawFactory.makeRawControls({...opts,startedAtUtc:T(251),completedAtUtc:T(252),outputTag:"after",endpointLabels:Object.fromEntries(names.map(n=>[n,"2".repeat(40)]))})};}
function compareRaw(pair){const summary=raw=>controls.summarizeRaw({raw,policy,sourceCommit:M,guard:iam});return controls.compareWithSupplement({before:summary(pair.before.raw),after:summary(pair.after.raw),policy,runtime:"nodejs22",declaredMaxInstances:20});}
test("synthetic original19 raw controls preserve15 identities, caps, env, scheduler with changed deployment outputs",()=>{const f=rawPair(),r=compareRaw(f);assert.equal(r.functionCount,19);assert.equal(r.normalizedDeploymentOutputs.validatedFunctionPairs,38);assert.equal(r.normalizedDeploymentOutputs.changedFunctions.length,19);assert.deepEqual(controls.schedulerControl31(f.before.scheduler),controls.schedulerControl31(f.after.scheduler));assert.equal(Object.hasOwn(r,"deploymentAuthorized"),false);});
for(const [name,edit,pattern]of [["missing function",r=>{const p=JSON.parse(r.functions[0].bodyText);p.functions.pop();r.functions[0].bodyText=JSON.stringify(p);},/Missing\/extra/],["new AppCheck enforcement",r=>{const p=JSON.parse(r.functions[0].bodyText);p.functions[0].serviceConfig.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK="true";r.functions[0].bodyText=JSON.stringify(p);},/AppCheck/],["project IAM mutation",r=>{const p=JSON.parse(r.projectIam.bodyText);p.bindings.push({role:"roles/owner",members:["allUsers"]});r.projectIam.bodyText=JSON.stringify(p);},/IAM\/identity/]])test("raw unchanged-control replay refuses "+name,()=>{const f=rawPair();edit(f.after.raw);assert.throws(()=>compareRaw(f),pattern);});

test("pointer byte bound is checked before any oversized original is read",()=>{const r=relocation();fs.appendFileSync(path.join(r.dir,r.pointer.file),"extra");const prior=fs.readFileSync;let targetReads=0;fs.readFileSync=function(file,...args){if(path.resolve(String(file))===path.join(r.dir,r.pointer.file))targetReads++;return prior.call(this,file,...args);};try{assert.throws(()=>x.privateBytes(r.dir,r.pointer),/private original bytes changed/);assert.equal(targetReads,0);}finally{fs.readFileSync=prior;}});

const custodySeconds=String(Date.parse(T(280))/1000);
function timeline(){return {closure:{completedAtUtc:T(250),recordedAtUtc:T(279)},custodySeconds,nowUtc:T(281),afterControls:{startedAtUtc:T(251),completedAtUtc:T(252)}};}
test("closure timing binds after-controls before recording and immutable commit precision",()=>{assert.doesNotThrow(()=>closure.verifyClosureChronology31(timeline()));});
for(const [name,edit]of [["future after-controls",f=>f.afterControls.completedAtUtc=T(280)],["controls before execution completed",f=>f.afterControls.startedAtUtc=T(249)],["custody before recorded original",f=>f.custodySeconds=String(Date.parse(T(277))/1000)],["future custody",f=>f.nowUtc=T(279)]])test("closure chronology refuses "+name,()=>{const f=timeline();edit(f);assert.throws(()=>closure.verifyClosureChronology31(f));});

// This is OUTER WIRING coverage only. The source/installed-runtime controls context
// is substituted, using real pure raw-control comparison for the returned summary.
// It is explicitly NOT the full default closure entry or authenticated readbacks.
function outerFixture(){
 const cli=path.join(projectRoot,"tooling/firebase-cli/node_modules/firebase-tools/lib"), i=intended();
 i.environmentVariables.FIREBASE_CONFIG=JSON.stringify({projectId:"crm3-baf-ops-b8638"});
 const rtime={...runtime,nodeExecutable:process.execPath,nodeSha256:runtime.githubExecutableSha256,cliEntrypoint:path.join(cli,"bin/firebase.js"),
 endpointHashProducerSha256:Object.fromEntries(Object.entries({apply:"deploy/functions/cache/applyHash.js",hash:"deploy/functions/cache/hash.js",secrets:"functions/secrets.js"}).map(([k,p])=>[k,h(fs.readFileSync(path.join(cli,p)))])),instrumentationProducerSha256:{synthetic:"separately-bound-in-full-entry"}};
 const hashInput={schemaVersion:1,documentType:"firebase-cli-approved-intended-hash-inputs",codebase:"default",source,sourceBefore:source,sourceAfter:source,...i};
 const endpointLabels=neutral.endpointRuntimeHashes31({sourceArchiveHash:checked.sourceArchiveHash,inputs:hashInput,runtime:rtime,names:cohorts.fleet,source});
 const approvalPointer={commit:M,file:a.DECISION_FILE,sha256:"A".repeat(64)},executionContract=retain({synthetic:true});
 const ctx={repoRoot:repo,evidenceDirectory:evidence,source,runtime:rtime,cohorts,liveApproval,approvalPointer,decision:{executionContract,decidedAtUtc:T(100)},proof:{buildRoot:repo},producerBindings:{synthetic:"not-authenticated"}};
 const outer={commands:{},startedAtUtc:T(101),completedAtUtc:T(699),endpointRuntimeHashes:endpointLabels};let baseline;
 const controlPairs={};
 ["callables","events","fleet"].forEach((phase,phaseIndex)=>{
  const f=mutationFixture(phase,endpointLabels),delta=phaseIndex*200,names=phase==="fleet"?cohorts.schedulers:cohorts[phase];baseline??=f.baseline;
  const move=value=>new Date(Date.parse(value)+delta*1000).toISOString();
  const records=f.records.map(p=>{const row=j(p),ob=j(row.liveObservation);ob.observedAtUtc=move(ob.observedAtUtc);ob.completedAtUtc=move(ob.completedAtUtc);row.startedAtUtc=move(row.startedAtUtc);row.completedAtUtc=move(row.completedAtUtc);row.liveObservation=retain(ob);return retain(row);});
  const captured={...hashInput,documentType:"firebase-cli-prepared-backend-hash-inputs",...f.capture,phase,actualCliPreparationCaptured:true,source,sourceBefore:source,sourceAfter:source,startedAtUtc:T(105+delta),completedAtUtc:T(110+delta),approvalPointer,instrumentationProducerSha256:rtime.instrumentationProducerSha256};
  const capture=retain(captured),pair=rawPair();pair.after.raw.startedAtUtc=T(108+delta);pair.after.raw.completedAtUtc=T(109+delta);controlPairs[phase]=pair;
  const currentControls=retain(pair.after.raw),completion=retain({schemaVersion:1,documentType:"build31-business-instrumented-completion",phase,source,approvalPointer,capture,archive,mutations:records,events:records.map(p=>{const r=j(p);return {kind:r.kind,sequence:r.sequence,...(r.name?{name:r.name}:{})};}),completedAtUtc:T(180+delta),exitCode:0,error:null});
  const point={...source,branch:"main",originMain:M,liveMain:M,clean:true};
  outer.commands[phase]=retain({schemaVersion:1,documentType:"build31-business-original-cohort",source,approvalPointer,executionContractSha256:executionContract.sha256,phase,functions:names,attempt:1,startedAtUtc:T(102+delta),completedAtUtc:T(190+delta),exitCode:0,signal:null,error:null,executable:process.execPath,nodeSha256:rtime.nodeSha256,cwd:repo,
  arguments:["--no-global-search-paths",path.join(repo,x.CAPTURE),"--config",path.join(evidence,"deployment-attempts",approvalPointer.sha256,phase,"context.json")],cliArguments:["deploy","--only",names.map(n=>"functions:"+n).join(","),"--project","crm3-baf-ops-b8638","--non-interactive"],sourceBefore:point,sourceAfter:point,producerBindings:ctx.producerBindings,stdout:retain("synthetic only"),stderr:retain(""),capture,archive,currentControls,mutations:records,completion});
 });
 baseline.controlsPointer=retain({synthetic:true});baseline.schedulerPointer=retain({synthetic:true});
 return {args:{ctx,closure:outer,baseline,intent:hashInput,archiveExpectedFiles:manifest},controlPairs};
}
function outerRun(f,implementation=closure){const original=controls.verifyCurrentCohortControls31;let calls=0;
 controls.verifyCurrentCohortControls31=input=>{calls++;const pair=f.controlPairs[input.phase],summary=compareRaw(pair);return {startedAtUtc:pair.after.raw.startedAtUtc,completedAtUtc:pair.after.raw.completedAtUtc,summary,installedRuntimeContextExercised:false};};
 try{return {result:implementation.replayRecordedCohorts31(f.args),controlsCalls:calls};}finally{controls.verifyCurrentCohortControls31=original;}
}
test("OUTER WIRING ONLY: all three actual cohort loop bodies complete with separately tested pure controls substitute",()=>{const f=outerFixture(),r=outerRun(f);assert.equal(r.controlsCalls,3);assert.equal(r.result.cohortCount,3);assert.equal(r.result.functionCount,19);assert.equal(r.result.uploadedArchiveSha256.length,3);});
for(const [name,edit,pattern]of [["overlapping cohorts",f=>{const p=f.args.closure.commands.events,r=j(p);r.startedAtUtc=T(189);f.args.closure.commands.events=retain(r);},/cohort order/],["completion after process",f=>{const p=f.args.closure.commands.callables,r=j(p),c=j(r.completion);c.completedAtUtc=T(191);r.completion=retain(c);f.args.closure.commands.callables=retain(r);},/completion time/],["completion before final response",f=>{const p=f.args.closure.commands.callables,r=j(p),c=j(r.completion);c.completedAtUtc=T(120);r.completion=retain(c);f.args.closure.commands.callables=retain(r);},/completion time/],["missing cohort",f=>delete f.args.closure.commands.events,/cohort population/]])test("OUTER WIRING ONLY refuses "+name,()=>{const f=outerFixture();edit(f);assert.throws(()=>outerRun(f),pattern);});


// The superseded private implementation and its known-failure reproduction remain
// retained locally; the current outer-loop regression above exercises this source.

// Regression from the exact published P1: retained wire evidence must constrain replay.
test("P1 regression: contradictory retained response cannot replay a fabricated successful generation",()=>{
 const f=mutationFixture("fleet"),row=j(f.records[0]);
 const responseRaw=retain(Buffer.from('{"error":"synthetic retained server failure"}'));
 const binding=retain({responseRaw,contentEncoding:null,responseComplete:true,retainedBytes:responseRaw.bytes,httpStatus:500});
 row.responseBinding=binding;f.records[0]=retain(row);
 assert.throws(()=>replay(f),/response|wire|schema/i);
});

function responseFixture(bodyText='{"uploadUrl":"https://storage.googleapis.com/synthetic"}',encoding=null) {
 const raw=Buffer.from(bodyText),encoded=encoding==="gzip"?zlib.gzipSync(raw):encoding==="deflate"?zlib.deflateSync(raw):encoding==="br"?zlib.brotliCompressSync(raw):raw;
 const responseRaw=retain(encoded);return {response:retain({httpStatus:200,bodyText}),binding:retain({responseRaw,contentEncoding:encoding,responseComplete:true,retainedBytes:encoded.length,httpStatus:200})};
}
const replayResponse=f=>closure.verifyMutationResponse31(evidence,f.response,f.binding);
const changeBinding=(f,edit)=>{const b=j(f.binding);edit(b);f.binding=retain(b);};
for(const encoding of [null,"","identity","gzip","deflate","br"])test("wire response preserves exact decoded UTF-8 for "+String(encoding),()=>{
 const body='{"message":"synthetic π 雨"}',f=responseFixture(body,encoding);assert.deepEqual(replayResponse(f),{httpStatus:200,bodyText:body});
});
test("wire response admits a completed zero-byte source upload body",()=>{const f=responseFixture("");assert.equal(replayResponse(f).bodyText,"");});
test("schema1 mutations cannot inherit the new response-wire proof",()=>{const f=mutationFixture("fleet");change(f,0,r=>r.schemaVersion=1);assert.throws(()=>replay(f),/mutation order/);});
for(const [name,edit,pattern]of [
 ["derived status only",f=>{const r=j(f.response);r.httpStatus=201;f.response=retain(r);},/wire response status/],
 ["derived generation body only",f=>{const r=j(f.response);r.bodyText='{"uploadUrl":"https://storage.googleapis.com/forged"}';f.response=retain(r);},/derived response body/],
 ["retained failed status",f=>changeBinding(f,b=>b.httpStatus=500),/wire response status/],
 ["missing retained status",f=>changeBinding(f,b=>delete b.httpStatus),/binding fields/],
 ["incomplete response",f=>changeBinding(f,b=>b.responseComplete=false),/incomplete/],
 ["count differs",f=>changeBinding(f,b=>b.retainedBytes++),/byte count/],
 ["count has wrong type",f=>changeBinding(f,b=>b.retainedBytes=String(b.retainedBytes)),/byte count/],
 ["binding digest differs",f=>f.binding.sha256="0".repeat(64),/private original bytes/],
 ["wire digest differs",f=>changeBinding(f,b=>b.responseRaw.sha256="0".repeat(64)),/private original bytes/],
 ["wire byte count differs",f=>changeBinding(f,b=>b.responseRaw.bytes++),/byte count/],
 ["unsupported encoding",f=>changeBinding(f,b=>b.contentEncoding="compress"),/unsupported wire/],
 ["falsy non-string encoding",f=>changeBinding(f,b=>b.contentEncoding=false),/unsupported wire/],
 ["encoding contradicts bytes",f=>changeBinding(f,b=>b.contentEncoding="gzip"),/cannot be decoded/],
 ["binding success substitute",f=>changeBinding(f,b=>b.PASS=true),/binding fields/],
 ["malformed gzip",f=>changeBinding(f,b=>{b.responseRaw=retain(Buffer.from([31,139,8]));b.retainedBytes=3;b.contentEncoding="gzip";}),/cannot be decoded/],
 ["invalid UTF-8",f=>changeBinding(f,b=>{b.responseRaw=retain(Buffer.from([0xc3,0x28]));b.retainedBytes=2;}),/cannot be decoded/],
 ["decoded response exceeds fixed bound",f=>changeBinding(f,b=>{const raw=zlib.gzipSync(Buffer.alloc(16*1024*1024+1));b.responseRaw=retain(raw);b.retainedBytes=raw.length;b.contentEncoding="gzip";}),/cannot be decoded/],
])test("wire response refuses "+name,()=>{const f=responseFixture();edit(f);assert.throws(()=>replayResponse(f),pattern);});
test("oversized wire response declaration is refused before reading its bytes",()=>{
 const f=responseFixture(),b=j(f.binding),wireFile=path.join(evidence,b.responseRaw.file);b.responseRaw.bytes=b.retainedBytes=16*1024*1024+1;f.binding=retain(b);
 const prior=fs.readFileSync;let reads=0;fs.readFileSync=function(file,...args){if(path.resolve(String(file))===wireFile)reads++;return prior.call(this,file,...args);};
 try{assert.throws(()=>replayResponse(f),/byte count/);assert.equal(reads,0);}finally{fs.readFileSync=prior;}
});
