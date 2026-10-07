"use strict";
// Private output-hook proposal only. No prepare/deploy/process/credential entry.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),{isDeepStrictEqual:same,TextDecoder}=require("node:util");
const bootstrap=require("./business31CaptureBootstrap.cjs");
bootstrap.assertBootstrap31();
const writerModule=require("./captureBusiness31PreparedInputs.cjs"),old=require("./backendRuntimeAdmission31.cjs"),business=require("./business31BackendAuthority.cjs");
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const need=(ok,message)=>{if(!ok)throw Error("Business prepared hook: "+message);};
function json(bytes){need(Buffer.isBuffer(bytes)&&bytes.length<=8*1024*1024,"bounded original JSON required");const value=JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(bytes));need(value&&typeof value==="object"&&!Array.isArray(value),"original object required");return value;}
function sameSource(a,b){need(same(a,b)&&same(Object.keys(a).sort(),["commit","functionsTree","tree"]),"exact business source differs");}
function bindIntent31({writer,envelopeBytes}) {
  need(writer.approval.file===business.DECISION_FILE&&sha(envelopeBytes)===writer.approval.sha256,"exact decision custody path/bytes required");
  const envelope=json(envelopeBytes);need(envelope.schemaVersion===1&&envelope.documentType==="build31-business-private-record-custody"&&envelope.recordKind==="decision","business decision custody envelope required");sameSource(envelope.source,writer.source);
  const read=p=>business.readPrivate(writer.root,p),decisionBytes=read(envelope.privateRecord),decision=json(decisionBytes);
  need(decision.schemaVersion===2&&decision.documentType==="build31-business-backend-deployment-decision"&&decision.profile===business.PROFILE,"schema2 business decision required");sameSource(decision.source,writer.source);
  const contractBytes=read(decision.executionContract),contract=json(contractBytes);
  need([1,2].includes(contract.schemaVersion)&&contract.documentType==="build31-business-execution-contract"&&contract.profile===business.PROFILE,"decision-covered execution contract required");sameSource(contract.source,writer.source);
  need(contract.sourceManifestSha256===decision.sourceManifestSha256&&same(contract.runtimeProof,decision.runtimeProof),"execution manifest/runtime binding differs");
  const intentBytes=read(contract.intendedHashInputs),intent=json(intentBytes);
  need(intent.schemaVersion===1&&intent.documentType==="firebase-cli-approved-intended-hash-inputs"&&intent.codebase==="default","ordered original intent required");
  for(const p of [intent.source,intent.sourceBefore,intent.sourceAfter])sameSource(p,writer.source);
  need(old.helpers.time(intent.completedAtUtc)<=old.helpers.time(contract.preparedAtUtc)&&old.helpers.time(contract.preparedAtUtc)<=old.helpers.time(decision.decidedAtUtc),"intent was not covered before decision");
  writer.bindExecutionWindow(decision.executionWindow);
  return {envelopeBytes,decision,contract,intent,decisionPointer:envelope.privateRecord,contractPointer:decision.executionContract,intentPointer:contract.intendedHashInputs,
    originalHashes:{envelope:sha(envelopeBytes),decision:sha(decisionBytes),contract:sha(contractBytes),intent:sha(intentBytes)}};
}
function verifyIntentUnchanged(writer,bound){need(sha(bound.envelopeBytes)===bound.originalHashes.envelope,"custody bytes changed");for(const [kind,p]of [["decision",bound.decisionPointer],["contract",bound.contractPointer],["intent",bound.intentPointer]])need(sha(business.readPrivate(writer.root,p))===bound.originalHashes[kind],"original "+kind+" changed");}
function installBusinessPreparedHook31({writer,phase,admission,envelopeBytes,archiveExpectedFiles,guardInputs}) {
  need(["callables","events","fleet"].includes(phase)&&!writer.active&&!writer.failed,"new exact cohort preparation required");
  sameSource(admission.source,writer.source);need(same(admission.approvalPointer,writer.approval)&&same(admission.cohorts,writer.cohorts)&&admission.projectId==="crm3-baf-ops-b8638"&&admission.region==="asia-south1","prepared identity differs");
  const bound=bindIntent31({writer,envelopeBytes}),library=path.dirname(path.dirname(admission.runtime.cliEntrypoint));
  const producers={api:"apiv2.js",apply:"deploy/functions/cache/applyHash.js",prepare:"deploy/functions/prepare.js",backend:"deploy/functions/backend.js"};
  need(same(Object.keys(admission.runtime.instrumentationProducerSha256).sort(),Object.keys(producers).sort()),"exact instrumentation population required");
  function verifyProducers(){for(const [name,relative]of Object.entries(producers))need(sha(fs.readFileSync(path.join(library,relative)))===admission.runtime.instrumentationProducerSha256[name],"installed instrumentation differs: "+name);}
  verifyProducers();
  const cliLoadLease=writerModule.installCliLoadBoundary31(admission.runtime);
  try {
  const applyFile=fs.realpathSync(path.join(library,producers.apply)),module=require(applyFile),original=module.applyBackendHashToBackends;
  need(typeof original==="function","real hash function export required");
  const startedAtUtc=new Date().toISOString(),sourceBefore=old.helpers.source(admission.repoRoot,old.helpers.gtext(admission.repoRoot,["rev-parse","HEAD"]));sameSource(sourceBefore,writer.source);
  const privateDir=path.join(writer.base,"prepared-hook-"+phase);fs.mkdirSync(privateDir,{mode:0o700});
  const save=(name,value)=>{const file=path.join(privateDir,name);fs.writeFileSync(file,JSON.stringify(value,null,2)+"\n",{flag:"wx",mode:0o600});return {file:path.relative(writer.root,file).split(path.sep).join("/"),sha256:sha(fs.readFileSync(file)),bytes:fs.statSync(file).size};};
  save("start.json",{schemaVersion:1,source:writer.source,approvalPointer:writer.approval,phase,startedAtUtc,originalHashes:bound.originalHashes,applyFile,applySha256:admission.runtime.instrumentationProducerSha256.apply,prepareCalled:false});
  let state="installed",result=null,loaderReleased=false;
  const wrapper=function(wantBackends,context){
    cliLoadLease.assertOwned();cliLoadLease.assertHealthy();need(state==="installed","prepared hash hook cannot run or retry twice");state="running";
    const originalPath=context?.sources?.default?.functionsSourceV2;
    try {
      verifyProducers();verifyIntentUnchanged(writer,bound);
      need(typeof originalPath==="string"&&path.isAbsolute(originalPath),"original actual ZIP path required");
      const before=fs.statSync(originalPath,{bigint:true});need(before.isFile()&&before.size>0n&&before.size<=64n*1024n*1024n,"bounded original ZIP required");
      // This is the real installed hash function. Its result is returned unchanged.
      const originalResult=original.apply(this,arguments);
      cliLoadLease.assertHealthy();
      need(!(originalResult&&typeof originalResult.then==="function"),"pinned hash function unexpectedly became async");
      const capture=writerModule.captureActualPreparedInputs31({wantBackends,context,admission,intent:bound.intent,archiveExpectedFiles,startedAtUtc,sourceBefore,phase});
      need(capture.archivePath===originalPath,"actual capture switched original ZIP identity");
      const bytes=fs.readFileSync(originalPath),after=fs.statSync(originalPath,{bigint:true});
      need(before.ino===after.ino&&before.size===after.size&&before.mtimeNs===after.mtimeNs&&before.ctimeNs===after.ctimeNs&&bytes.length===capture.archiveBytes&&sha(bytes)===capture.archiveSha256,"original ZIP changed during actual capture");
      delete capture.archivePath;
      const retained=writer.startCohort({phase,capture,archive:bytes,guardInputs}),copied=fs.readFileSync(retained.archivePath);
      need(copied.equals(bytes)&&sha(copied)===capture.archiveSha256,"retained ZIP differs from original");
      verifyProducers();verifyIntentUnchanged(writer,bound);
      need(context.sources.default.functionsSourceV2===originalPath,"CLI source path changed before retained selection");
      // Explicit in-memory selection only; the original context/path is retained separately.
      context.sources.default.functionsSourceV2=retained.archivePath;
      result={schemaVersion:1,documentType:"build31-business-prepared-output-hook",source:writer.source,approvalPointer:writer.approval,phase,
        startedAtUtc,completedAtUtc:new Date().toISOString(),originalArchivePath:originalPath,retainedArchivePath:retained.archivePath,archiveSha256:capture.archiveSha256,archiveBytes:capture.archiveBytes,
        originalHashes:bound.originalHashes,capture:writer.active.capturePointer,archive:writer.active.archivePointer,actualHashFunctionCalled:true,hashFunctionReturnType:typeof originalResult,
        ...(bound.contract.schemaVersion===1?{fullFirebasePrepareCalled:false}:{prepareEntryInvokedByThisHook:false}),authenticatedDecision:false,deploymentAuthorized:false};
      save("captured.json",result);state="captured";return originalResult;
    }catch(error){state="failed";writer.failed=true;if(writer.active)writer.active.failed=true;save("failed.json",{schemaVersion:1,phase,source:writer.source,approvalPointer:writer.approval,startedAtUtc,completedAtUtc:new Date().toISOString(),originalArchivePath:typeof originalPath==="string"?originalPath:null,error:"PREPARED_OUTPUT_REFUSED",automaticRetryAllowed:false,rawErrorMessageRetained:false});throw error;}
  };
  module.applyBackendHashToBackends=wrapper;
  return {module,applyFile,getResult(){need(state==="captured","actual prepared output is not captured");return structuredClone(result);},restore(){
    need(state!=="running","hook is still running");let error;
    try{need(module.applyBackendHashToBackends===wrapper,"hook ownership changed");module.applyBackendHashToBackends=original;}catch(e){error=e;}
    finally{if(!loaderReleased){try{cliLoadLease.release();loaderReleased=true;}catch(e){error=error?new AggregateError([error,e],"Business prepared hook: method and loader cleanup failed"):e;}finally{loaderReleased=cliLoadLease.isReleased();}}}
    if(error)throw error;
  },state:()=>state};
  } catch(error) { try{cliLoadLease.release();}catch(cleanup){throw new AggregateError([error,cleanup],"Business prepared hook: initialization and loader cleanup failed");}throw error; }
}
if(require.main===module){process.stderr.write("Private prepared-output adapter has no operational entry.\n");process.exitCode=1;}
module.exports={bindIntent31,installBusinessPreparedHook31};
