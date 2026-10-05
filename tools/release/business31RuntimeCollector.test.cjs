"use strict";
// Independent private collector tests. Every accepted source/profile below is
// expressly synthetic. Processes really run; npm/build/audit/emulator semantics
// remain inert fixtures, never operational evidence or actual clean installs.
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os");
if(process.platform!=="win32") {
  test("Windows owned-process collector integration",{skip:"Requires Windows job objects; this platform cannot qualify the Windows collector"},()=>{});
} else {
const {createFixture,binding,sha,put}=require("./fixtures/business31CollectorFixture.cjs");
const candidate=__dirname;
const collector=require(path.join(candidate,"collectBusinessRuntime31.cjs"));
const toolsDirectory=__dirname;
const hostConfigFile=process.env.BUSINESS31_COLLECTOR_TEST_HOST_CONFIG;
assert.ok(hostConfigFile&&path.isAbsolute(hostConfigFile),"Set BUSINESS31_COLLECTOR_TEST_HOST_CONFIG to explicitly selected host tool paths");
const host=JSON.parse(fs.readFileSync(hostConfigFile,"utf8"));
assert.deepEqual(Object.keys(host).sort(),["gitExecutable","pythonRoot","systemRoot"]);
for(const value of Object.values(host))assert.ok(typeof value==="string"&&path.isAbsolute(value),"Host tools must have explicit absolute paths");
const parent=fs.mkdtempSync(path.join(os.tmpdir(),"business31-collector-tests-"));
process.stdout.write("Retained synthetic collector evidence: "+parent+"\n");
const authority=require(path.join(toolsDirectory,"business31BackendAuthority.cjs"));
const trusted=require(path.join(toolsDirectory,"business31TrustedInput.cjs"));
const {gitExecutable,pythonRoot,systemRoot}=host;
const pythonFiles=Object.fromEntries(["python.exe","python313.dll","DLLs/_ctypes.pyd","DLLs/libffi-8.dll"].map(name=>{const full=path.join(pythonRoot,name);return [full,binding(full).sha256];}));
function make(name,behaviour={}){
  const f=createFixture({parent,name,toolsDirectory,gitExecutable,behaviour});
  f.config={schemaVersion:1,repositoryRoot:f.repositoryRoot,gitExecutable,gitSha256:f.gitSha256,source:f.source,runtime:f.runtime,attemptRoot:f.attemptRoot,
    afterCi:new Date(Date.now()-60000).toISOString(),python:{executable:binding(path.join(pythonRoot,"python.exe")),files:pythonFiles},windows:{systemRoot,commandProcessor:binding(path.join(systemRoot,"System32/cmd.exe")),java:null,firestoreJar:null},limits:{commandSeconds:20,cleanupSeconds:5,outputBytes:1024*1024}};
  return f;
}
function json(file){return JSON.parse(fs.readFileSync(file,"utf8"));}
function processes(root){const found=[];if(!fs.existsSync(root))return found;function walk(dir){for(const row of fs.readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,row.name);if(row.isDirectory())walk(full);else if(row.name==="result.json"){const result=json(full);if(result.documentType==="private-windows-owned-process-result")found.push({file:full,result});}}}walk(root);return found;}
function invocations(f){const file=path.join(f.attemptRoot,"build/.dart_tool/collector-fixture/invocations.jsonl");return fs.existsSync(file)?fs.readFileSync(file,"utf8").trim().split("\n").filter(Boolean).map(JSON.parse):[];}
function noSuccessfulProof(f){assert.equal(fs.existsSync(path.join(f.attemptRoot,"evidence/runtime-proof.json")),false);}
function allOwnedChildrenTerminated(records){assert.ok(records.length>0);for(const {result}of records){assert.equal(result.treeComplete,true,JSON.stringify(result));assert.equal(result.activeProcesses,0);assert.equal(result.rootExited,true);assert.equal(result.outputComplete,true);assert.deepEqual(result.cleanupErrors,[]);}}
async function expectFailure(f,pattern){await assert.rejects(async()=>collector.collectBusinessRuntime31(f.config),pattern);assert.ok(fs.existsSync(path.join(f.attemptRoot,"evidence/failure.json")),"Original failure receipt must be retained");noSuccessfulProof(f);f.assertOriginalsUnchanged();}
function verify(result,f,proof){const repository=trusted.openTrustedGitRepository31({repositoryRoot:f.repositoryRoot,gitExecutable,gitSha256:f.gitSha256});return authority.verifyRuntimeProof31({proof,source:f.source,snapshot:repository.snapshot(f.source.commit),repository,evidenceDirectory:result.evidenceDirectory,afterCi:f.config.afterCi,beforeDecision:new Date(Date.now()+1000).toISOString()});}
let positive;
test("synthetic source: collector records real inert processes and unchanged schema3 verifier accepts complete proof",{timeout:180000},async()=>{
  const f=make("complete-inert"),result=await collector.collectBusinessRuntime31(f.config),proof=json(result.proofFile);
  assert.equal(sha(fs.readFileSync(result.proofFile)),result.sha256);assert.equal(proof.schemaVersion,3);
  const independent=verify(result,f,proof);assert.equal(independent.emittedFileCount,2);assert.equal(independent.installedRuntimePathCount,1);
  assert.equal(independent.approvedToolchain.processExecutionAuthenticated,false);assert.equal(independent.approvedToolchain.deploymentAuthorized,false);
  const records=processes(f.attemptRoot);assert.equal(records.length,16);allOwnedChildrenTerminated(records);
  for(const {result:r}of records){assert.equal(r.status,"SUCCESS");assert.equal(r.exitCode,0);assert.equal(r.authenticated,false);assert.equal(r.deploymentAuthorized,false);}
  const calls=invocations(f);assert.equal(calls.length,14);assert.deepEqual(calls[0].argv,["--version"]);
  assert.equal(Object.keys(proof.testedEmittedFiles).length,3);assert.equal(Object.keys(proof.audits).length,5);assert.equal(Object.keys(proof.commands).length,9);
  f.assertOriginalsUnchanged();positive={f,result,proof};
});
test("independent verifier rejects changed command chronology without rewriting the original proof",()=>{
  assert.ok(positive,"Real positive prerequisite must have succeeded");const {f,result,proof}=positive,copy=structuredClone(proof),original=fs.readFileSync(result.proofFile);
  const recordFile=path.join(result.evidenceDirectory,copy.commands["functions-host-tests"].file),record=json(recordFile);
  record.startedAtUtc=proof.startedAtUtc;record.completedAtUtc=proof.startedAtUtc;
  const raw=Buffer.from(JSON.stringify(record)),name="independent-host-chronology-negative.json";put(result.evidenceDirectory,name,raw);copy.commands["functions-host-tests"]={file:name,sha256:sha(raw),bytes:raw.length};
  assert.throws(()=>verify(result,f,copy),/must follow completed build|precedes materialization/);assert.deepEqual(fs.readFileSync(result.proofFile),original);
});
for(const [name,change,pattern]of [
  ["absent source-approved profile",f=>{f.config.runtime.toolchainProfileId="not-approved";},/no independently approved source toolchain profile/],
  ["wrong approved Node bytes",f=>{f.config.runtime.nodeExecutable={...f.config.runtime.nodeExecutable,sha256:"0".repeat(64)};},/Node differs from independently approved bytes/],
  ["wrong exact source tree",f=>{f.config.source={...f.config.source,tree:"0".repeat(40)};},/source tree differs/],
])test("preflight refuses "+name+" before launching any runtime child",{timeout:60000},async()=>{
  const f=make(name.toLowerCase().replaceAll(" ","-"),name==="absent source-approved profile"?{noProfile:true}:{});change(f);await assert.rejects(async()=>collector.preflightBusinessRuntime31(f.config),pattern);assert.equal(processes(f.attemptRoot).length,0);assert.deepEqual(invocations(f),[]);noSuccessfulProof(f);f.assertOriginalsUnchanged();
});
test("preflight refuses a different source-bound collector producer before runtime launch",{timeout:60000},async()=>{
  const f=make("source-producer-mismatch",{producerMismatch:true});await assert.rejects(async()=>collector.preflightBusinessRuntime31(f.config),/executing collector producer differs from source/);assert.equal(processes(f.attemptRoot).length,0);assert.deepEqual(invocations(f),[]);noSuccessfulProof(f);f.assertOriginalsUnchanged();
});
test("preflight refuses an external ancestor .bin directory without launching or deleting it",()=>{
  const f=make("ancestor-bin"),external=path.join(f.root,"node_modules/.bin");fs.mkdirSync(external,{recursive:true});assert.throws(()=>collector.preflightBusinessRuntime31(f.config),/outside-build ancestor npm bin population refused/);
  assert.equal(fs.statSync(external).isDirectory(),true);assert.equal(processes(f.attemptRoot).length,0);assert.deepEqual(invocations(f),[]);noSuccessfulProof(f);f.assertOriginalsUnchanged();
});
test("first actual child failure retains exact binary streams and prevents every later command",{timeout:120000},async()=>{
  const f=make("first-failure",{failAt:"functions-install"});await expectFailure(f,/fail|exit|process|command/i);
  const records=processes(f.attemptRoot);assert.equal(records.length,4);allOwnedChildrenTerminated(records);
  const failed=records.filter(r=>r.result.exitCode===23);assert.equal(failed.length,1);assert.equal(failed[0].result.status,"FAILED");
  assert.deepEqual(fs.readFileSync(failed[0].result.streams.stdout.path),Buffer.from([0x66,0x61,0x69,0x6c,0x00,0xff]));assert.equal(fs.readFileSync(failed[0].result.streams.stderr.path,"utf8"),"retained inert failure\n");
  assert.equal(invocations(f).length,3);assert.equal(fs.existsSync(path.join(f.attemptRoot,"build/tooling/firebase-cli/node_modules")),false);
});
for(const [name,behaviour,pattern]of [
  ["source-change",{changeSourceAt:"build"},/source|materialized|blob/i],
  ["changed-test-output",{changedOutputAt:"test"},/output|emitted|tested/i],
  ["extra-build-output",{extraOutputAt:"build"},/output|emitted|population/i],
])test("collector refuses "+name+" and retains failure without authenticating fixture output",{timeout:180000},async()=>{
  const f=make(name,behaviour);await expectFailure(f,pattern);allOwnedChildrenTerminated(processes(f.attemptRoot));
});
}
