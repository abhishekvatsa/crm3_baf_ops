"use strict";
// Version-selection tests call actual replay, stopping at the next genuine guard.
// They do not construct successful authority, controls, capture, or process proof.
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os");
const closure=require("./business31BackendClosure.cjs"),x=require("./business31ExecutionContract.cjs");
function fixture(t,contractVersion,cohortVersion) {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),"business-cohort-version-"));
  t.diagnostic("Retained version-selection originals: "+root);
  let serial=0;
  const retain=value=>{const bytes=Buffer.from(JSON.stringify(value)),file="original-"+(++serial)+".json";fs.writeFileSync(path.join(root,file),bytes);return {file,sha256:x.sha(bytes),bytes:bytes.length};};
  const source={commit:"1".repeat(40),tree:"2".repeat(40),functionsTree:"3".repeat(40)};
  const approvalPointer={commit:source.commit,file:"decision.json",sha256:"A".repeat(64)};
  const start="2026-10-06T00:00:01.000Z",end="2026-10-06T00:00:02.000Z";
  const ctx={repoRoot:root,evidenceDirectory:root,source,approvalPointer,contract:{schemaVersion:contractVersion},
    cohorts:{callables:["fixtureCallable"]},decision:{executionContract:{sha256:"B".repeat(64)},executionWindow:{notBeforeUtc:start,notAfterUtc:end}},
    runtime:{nodeExecutable:process.execPath,nodeSha256:"C".repeat(64)},proof:{buildRoot:root},producerBindings:{}};
  const record={schemaVersion:cohortVersion,documentType:"build31-business-original-cohort",source,approvalPointer,
    executionContractSha256:ctx.decision.executionContract.sha256,phase:"callables",functions:ctx.cohorts.callables,attempt:1,
    startedAtUtc:start,completedAtUtc:end,exitCode:0,signal:null,error:null,executable:process.execPath,nodeSha256:ctx.runtime.nodeSha256,cwd:root,
    arguments:["--no-global-search-paths",path.join(root,x.CAPTURE),"--config",path.join(root,"deployment-attempts",approvalPointer.sha256,"callables","context.json")],
    cliArguments:["deploy","--only","functions:fixtureCallable","--project","crm3-baf-ops-b8638","--non-interactive"],
    sourceBefore:null,sourceAfter:null,producerBindings:{},stdout:null,stderr:null,capture:null,archive:null,currentControls:null,mutations:[],completion:null};
  if(cohortVersion===2)Object.assign(record,{context:retain({intentionallyIncomplete:true}),start:retain({}),process:retain({})});
  return {ctx,record,run(){return closure.replayRecordedCohort31({ctx,phase:"callables",commandPointer:retain(record),
    earliestUtc:start,latestUtc:end,endpointRuntimeHashes:{},baseline:{},intent:{},archiveExpectedFiles:{},predecessors:[]});}};
}
for(const [contract,cohort] of [[2,1],[1,2],[undefined,1],[3,1],["2",2]]) {
  test("refuses contract/cohort version mismatch "+String(contract)+"/"+cohort+" before the optional process join",t=>{
    const f=fixture(t,contract,cohort);
    assert.throws(()=>f.run(),/cohort schema differs from execution contract/);
  });
}
test("legacy contract1/cohort1 selection retains the original clean-source guard",t=>{
  const f=fixture(t,1,1);
  assert.throws(()=>f.run(),/cohort clean source differs/);
});
test("new contract2/cohort2 selection requires original owned-process context",t=>{
  const f=fixture(t,2,2);
  assert.throws(()=>f.run(),/phase context fields differ/);
});
