"use strict";
// PRIVATE local capture coordinator. No CLI, prepare, deployment, auth or child entry.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const {isDeepStrictEqual: same} = require("node:util");
const PINS = Object.freeze({
  "backendRuntimeAdmission31.cjs": "5B30540018751B6BF8E3285A163CED4437ABFDC26B5D53CA5BFE70445421F97D",
  "backendRuntimeClosedReplay31.cjs": "062BD7E59A797DE6925644C2E794190F921A07AB85FFBD2C627947F82A65E43E",
  "backendRuntimeClosure31.cjs": "850469920024DC8BC19EDAF1B718F9FD2B70A4AAFD2837632A02E203DBBAA69D",
  "backendRuntimeControls31.cjs": "7A39F7386497C6FF153DE370A806ECD28F7BF22410C73FAB796040214A348D68",
  "backendRuntimeEvidenceAccess31.cjs": "920BAA3F4AEC4B6C9F6CDCF2AE4CA60F4487D4BB9DFEE48898376809E9055CF2",
  "backendRuntimeExecution31.cjs": "9EA9AA28A12372001B06BAB649F5E31A85021B1F05FB5B55C015AA14834512DF",
  "backendRuntimeExecutionAdmission31.cjs": "70D55E9B18A925947E3EE88BE5A5F3729990078F7D6B670A8FEE473620214ED4",
  "backendRuntimeProof31.cjs": "30784A451FDF07CE2BC9CD1BBEEAAE530AEE0C69B71C2A0F3D75D6176C61FBA5",
  "backendRuntimeReadbacks31.cjs": "8A47A14F2F0934E1594F7314DB3FCF2DC1D75D6758884C17BE073780BBF0CB40",
  "business31BackendAuthority.cjs": "9DB79FA9A3E7D4E287D65BBFF31067A2D440F338CEF3D4B7C1A00F6D7CA0D68C",
  "business31ScopedCallableInvokerIam.cjs": "C9BC91C5B6DF9290416E50AA256AEC89AD90B8D58B093020D904A15F997030F7",
  "business31BackendControls.cjs": "0369E04D8AFF0C6FF5B7EC35D3C2A24BBAB4C8352F69448D57120A7F29153940",
  "business31BackendClosure.cjs": "33FF477B422DE568D224A8B03A7665973E99403527F0E1F2A228EC73FED89793",
  "business31CaptureBootstrap.cjs": "12560B1CDB6E9E989EB4150A448AF83F910F3A5344D2A7054B2C625F460411B0",
  "business31CaptureRecorder.cjs": "1A1D007442E52C76EDA50CFC2B3BCD6DCF7745A54BCC87F258D0748C89485CBE",
  "business31ServiceIdentityCapture.cjs": "9D35FF5890F743938A60E487A032C0355E6B9130971D8B993D18AE0AB09FD8CA",
  "business31CohortProcess.cjs": "FCF53ADAD545465425D1798AF3E20E6C20E3A34FBE4EA2AE37E070C5A5A4FB84",
  "business31ExecutionContract.cjs": "CD5725DA082B17CBA85DC02853C8141C54520D615D4E4B773EEAA8E25DB15EC5",
  "business31IntentPreparation.cjs": "008AC33A5CF24BF3F6AFD8835BC98DCF17AFF40136B0B812EEC7557405AF5739",
  "business31NpmBinMaterialization.cjs": "3ABE7C8AC559B4D6DBBEC365871C3F69C3487C19DD4A76D242B9535255A14CDA",
  "business31OperationalController.cjs": "CA0AF68BA0B9FA48F943930BBB5D89BADA8363E6DE05F4374B5D5333042D9054",
  "business31SourceAdmission.cjs": "60B753527F35594C61802885CDA8B867C1EAD571F41760DBABDFD10617E00C11",
  "business31ToolchainIdentity.cjs": "362DE4848F0EFB2807B5AC79498AA4EFAF7CDBF410EF6BAAA50FD9F891AB4A94",
  "business31ToolchainProfiles.json": "F10A11D922FB378471728BB28623D33F64481C8E339950AF9416070A2D01A5B1",
  "business31TrustedInput.cjs": "E4851A48A8A0352E3238CD521D837807990EBBDDF65C719C1AD2E9B43441E73B",
  "captureBackendRuntimePreparedInputs31.cjs": "23C332B53A97DE7F5C328C9DE8EF63F160231B8ABBE1B99D7E76EB3F5C211387",
  "captureBusiness31PreparedHook.cjs": "5CF12047554327C8189D994ACF319A4AB0E4C26A5630D128EC36980196E21417",
  "captureBusiness31PreparedInputs.cjs": "E41E0CA63D2F03E4D46CC5A666C39A94045A1BEE25B6F830FF9F5DFE5057C73A",
  "clientBuildTooling31.historical-fixture.cjs": "4675CE35F06DB75334ABCD0841D1C7E07F65B4029CC0363D7FD279B539F829DB",
  "clientBuildToolingCompatibility31.cjs": "41A88310EF277B32056B58C779070B764FD6ACE27CA6C63A074C8B23BF08C7F2",
  "clientBuildToolingGitSnapshots31.cjs": "3549713D8E0F36B0C38324C4DD6BEA8D1FFE52ECF281C62C7AEE49AD552E9A68",
  "clientBuildToolingReadbacks31.cjs": "A36AC3AF221B27C60B30EDD0F78B089E6CD6A7B54D0D7E39A96963A757FB7617",
  "clientBuildToolingRuntime31.synthetic-fixture.cjs": "6DC27DE2DDA5CC3CCA589A8DDA44BAA39C26FC0DCAD0F7443B011878243145C5",
  "clientRuntimeCompatibility31.cjs": "58D846997E8247BC065B4F0435E4FE04E5CBD378CDCB02171EFB43DAAE3574E4",
  "closure-preflight31.cjs": "E3A40331DE2153B12309293558143119F5F75E3D0BE7C50489BAEC494AF33F8D",
  "collectBusinessRuntime31.cjs": "40CA399C5903AD0DBF9CA66E4A7592D76005D8D173D0CA3929F8B941843E5E1B",
  "collectClientBuildToolingRuntime31.cjs": "1DA6A7B21752CDA4C4F0C25BCCA7F0AE85705A8B889584524EF970285E7B1DB4",
  "collectClientDevelopmentToolIam31.cjs": "7B99AABBE4F049535569ECCBCD33031ED77082679259417A11E7C9A41C26A9BA",
  "executeBackendRuntime31.cjs": "E76B812957049096AD4B8BF83E25C7BD4C35A06A4534E78253FC30BE4CFFB2BF",
  "prepareBusinessIntent31.cjs": "7D36B5709FA055D5F5769641826763F2C2F52C8E098054532AF64741B1E2E289",
  "privateEvidenceBundle31.cjs": "B5CE8865DAEA9258F3F1E6B1D406D24605BA69A64D570DC21248FDE120010557",
  "runtimeBackendPrivateReplay31.cjs": "FB1485F922E266F215572C9AD2016BDFC073F5BA3630226BDB8332A3AEC8F828",
  "runtimeDeploymentTransportGuard31.cjs": "ED67BF123A12B72408072B8CBE138821223078C86F4EAD91A6E1FBC81AA18CBD",
  "runtimePilotAuthority31.cjs": "37413B1AA0BBC311F5BEA2405C5D4D2AA4FFE62F148D4375127FC19D6A993542",
  "runtime_contract_bindings.json": "068538B40781DA3763797B8CF2AB012765F871DE8ABA0BFC2D5F25088540EF2B",
  "runtime_process_runner.py": "68202E1C00626228F85E5AE523AE2675129CA184604792A9BD316B9AD90683FE",
  "runtime_supervisor.py": "4AE021C13E2FDC0D3FAD18ADBF5D7D796FD2DA946E8C907288BA0A83C585F37C"
});
const PHASES = Object.freeze(["callables", "events", "fleet"]);
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const need = (ok, message) => { if (!ok) throw Error("Business capture session: " + message); };
function verifyCopies() {
  for (const [name, expected] of Object.entries(PINS)) {
    const file = path.join(__dirname, name), stat = fs.lstatSync(file);
    need(stat.isFile() && !stat.isSymbolicLink() && sha(fs.readFileSync(file)) === expected, "frozen dependency differs");
  }
}
class BusinessCaptureSession31 {
  constructor({evidenceDirectory, source, approvalPointer, cohorts, admission, envelopeBytes,
    archiveExpectedFiles, guardInputs, observeLive, now = () => new Date().toISOString()}) {
    verifyCopies();
    require("./business31CaptureBootstrap.cjs").assertBootstrap31();
    need(typeof observeLive === "function", "measurement observer required; it confers no authority");
    this.writerModule=require("./business31CaptureRecorder.cjs");
    this.cliLoadLease=this.writerModule.installCliLoadBoundary31(admission.runtime);
    try {
    const library=path.dirname(path.dirname(admission.runtime.cliEntrypoint)),apiFile=path.join(library,"apiv2.js");
    need(sha(fs.readFileSync(apiFile))===admission.runtime.instrumentationProducerSha256.api,"actual API producer differs");
    this.api=require(apiFile);need(typeof this.api.Client==="function","actual installed Client required");
    this.hookModule=require("./captureBusiness31PreparedHook.cjs");
    this.writer=new this.writerModule.BusinessCapture31({evidenceDirectory,source,approvalPointer,cohorts,now});
    this.input={admission,envelopeBytes,archiveExpectedFiles,guardInputs};this.observeLive=observeLive;this.now=now;
    const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),Module=require("node:module");
    this.slots=[[this.api.Client.prototype,"request"],[https,"request"],[https,"get"],[http,"request"],[http,"get"],
      [net.Socket.prototype,"connect"],[tls,"connect"],[Module,"_load"],[globalThis,"fetch"]];
    this.state="between";this.failed=false;this.next=0;this.inflight=0;this.phase=null;this.hook=null;
    this.captureRestore=null;this.owner=null;this.boundary=null;this.results=[];this.firstFailure=null;
    this.persistenceFailed=false;this.cleanupIncomplete=false;
    // No network hooks exist until initial evidence persistence has succeeded.
    this._save("session-start.json",{schemaVersion:1,source,approvalPointer,phaseOrder:PHASES,
      sourceOnlyMeasurement:true,operationalEntryPresent:false,observerAuthenticated:false,clockAuthenticated:false,deploymentAuthorized:false});
    this._installDormant();
    } catch(error) {
      try{this.cliLoadLease.release();this.cliLoadLease=null;}catch(cleanup){throw new AggregateError([error,cleanup],"Business capture session: initialization and loader cleanup failed");}
      throw error;
    }
  }
  _save(name,value) {
    const file=path.join(this.writer.base,name),bytes=Buffer.from(JSON.stringify(value,null,2)+"\n");
    fs.writeFileSync(file,bytes,{flag:"wx",mode:0o600});
    return {file:path.relative(this.writer.root,file).split(path.sep).join("/"),sha256:sha(bytes),bytes:bytes.length};
  }
  _fail(code) {
    this.failed=true;this.writer.failed=true;if(this.writer.active)this.writer.active.failed=true;
    if(this.firstFailure)return;
    const failure={schemaVersion:1,code,phase:this.phase,observedAtUtc:this.now(),noAutomaticRetry:true,
      rawErrorMessageRetained:false,deploymentAuthorized:false,cleanupStatus:"not-yet-evaluated"};
    this.firstFailure={inMemory:true,code};
    try{this.firstFailure=this._save("session-first-failure.json",failure);}
    catch{
      this.persistenceFailed=true;
      // Distinct best-effort receipt; never overwrite an original or expose raw errors.
      try{const file=path.join(this.writer.root,"capture-session-emergency-"+this.writer.approval.sha256+".json");
        fs.writeFileSync(file,JSON.stringify(failure,null,2)+"\n",{flag:"wx",mode:0o600});this.firstFailure={emergencyFile:file};}catch{}
    }
  }
  _require(ok,code){if(!ok){this._fail(code);throw Error("Business capture session: "+code);}}
  _snapshot(){return this.slots.map(([o,k])=>Object.getOwnPropertyDescriptor(o,k));}
  _matches(descriptors){return this.slots.every(([o,k],i)=>same(Object.getOwnPropertyDescriptor(o,k),descriptors[i]));}
  _restoreOwned(saved,owner){
    let okay=true;
    this.slots.forEach(([o,k],i)=>{const d=Object.getOwnPropertyDescriptor(o,k);
      if(same(d,saved[i]))return;
      if(!d||!same(d,owner[i])){okay=false;return;}
      try{Object.defineProperty(o,k,saved[i]);}catch{okay=false;}
    });
    if(!okay)this.cleanupIncomplete=true;return okay;
  }
  _owned(){this._require(this._matches(this.owner),"HOOK_OWNERSHIP_CHANGED");try{this.cliLoadLease.assertHealthy();}catch(error){this._fail("CLI_LOAD_BOUNDARY_FAILED");throw error;}}
  _transaction(action){
    // Record synchronous writes by the frozen installer. No observer or async work runs here.
    const frames=this.slots.map(([object,key])=>{const descriptor=Object.getOwnPropertyDescriptor(object,key);
      need(descriptor&&Object.hasOwn(descriptor,"value")&&descriptor.writable&&descriptor.configurable,"hook data slot is not writable/configurable");
      const frame={object,key,descriptor,current:descriptor.value};frame.get=()=>frame.current;frame.set=value=>{frame.current=value;};return frame;});
    const original=frames.map(f=>f.descriptor);let installed=0,result,error,foreign=false;
    try{
      for(const f of frames){Object.defineProperty(f.object,f.key,{configurable:true,enumerable:f.descriptor.enumerable,get:f.get,set:f.set});installed++;}
      result=action();
    }catch(e){error=e;}
    finally{
      for(const f of frames.slice(0,installed)){const d=Object.getOwnPropertyDescriptor(f.object,f.key);
        if(same(d,{configurable:true,enumerable:f.descriptor.enumerable,get:f.get,set:f.set}))Object.defineProperty(f.object,f.key,{...f.descriptor,value:f.current});else foreign=true;
      }
    }
    const owned=frames.map(f=>({...f.descriptor,value:f.current}));
    if(error||foreign){this._restoreOwned(original,owned);if(foreign)this.cleanupIncomplete=true;throw error??Error("Business capture session: hook descriptor changed during installation");}
    return {result,original,owned};
  }
  _installDormant(){
    const blocked=()=>{this._fail("REQUEST_OUTSIDE_CAPTURE");throw Error("Business capture session: request outside prepared capture");};
    const installed=this._transaction(()=>{for(let i=0;i<this.slots.length;i++){if(i===7)continue;const[o,k]=this.slots[i];o[k]=blocked;}});
    this.base=installed.original;this.owner=installed.owned;this.boundary="dormant";
  }
  _removeDormant(){const okay=this._restoreOwned(this.base,this.owner);this.owner=null;this.boundary=null;if(!okay){this._fail("HOOK_OWNERSHIP_CHANGED");throw Error("Business capture session: cleanup incomplete; foreign hook preserved");}}
  beginPhase(phase){
    this._require(this.state==="between"&&!this.failed&&phase===PHASES[this.next],"PHASE_ORDER_OR_RETRY_REFUSED");
    this._owned();verifyCopies();this.phase=phase;this.state="awaiting-prepared";
    try{this._save("phase-"+phase+"-start.json",{schemaVersion:1,phase,startedAtUtc:this.now(),source:this.writer.source,
      approvalPointer:this.writer.approval,attempt:1,prepareEntryInvokedByAdapter:false,deploymentEntryInvokedByAdapter:false});}
    catch(error){this._fail("PHASE_START_PERSIST_FAILED");try{this._removeDormant();}finally{this.state="failed";}throw error;}
  }
  capturePrepared(wantBackends,context){
    this._require(this.state==="awaiting-prepared"&&!this.failed,"PREPARED_ORDER_OR_RETRY_REFUSED");this._owned();
    try{
      this.hook=this.hookModule.installBusinessPreparedHook31({writer:this.writer,phase:this.phase,...this.input});
      const returned=this.hook.module.applyBackendHashToBackends(wantBackends,context);
      this.prepared=this.hook.getResult();this.hook.restore();this.hook=null;this._removeDormant();
      const installed=this._transaction(()=>this.writerModule.installBusinessCapture31({Client:this.api.Client,writer:this.writer,observeLive:this.observeLive}));
      this.captureRestore=installed.result;this.captureBase=installed.original;
      const session=this,captured=this.api.Client.prototype.request;
      this.api.Client.prototype.request=function(request){session.inflight++;return(async()=>{
        try{return await captured.call(this,request);}catch(error){session._fail("CAPTURE_REQUEST_FAILED");throw error;}finally{session.inflight--;}
      })();};
      this.owner=this._snapshot();this.boundary="active";this.state="capturing";return returned;
    }catch(error){
      this._fail("PREPARED_CAPTURE_FAILED");
      try{if(this.hook){this.hook.restore();this.hook=null;}}
      finally{if(!this.boundary&&!this.cleanupIncomplete)this._installDormant();}
      throw error;
    }
  }
  _releaseCapture(reinstall=true){
    this._require(this.inflight===0&&(this.writer.active?.pending??0)===0,"ORIGINAL_REQUESTS_STILL_PENDING");
    let okay=this._matches(this.owner);
    try{if(okay)this.captureRestore();}
    catch{okay=false;}
    finally{okay=this._restoreOwned(this.captureBase,this.owner)&&okay;this.captureRestore=null;this.owner=null;this.boundary=null;}
    if(!okay){this.cleanupIncomplete=true;this._fail("HOOK_CLEANUP_INCOMPLETE");throw Error("Business capture session: cleanup incomplete; foreign hook preserved");}
    if(reinstall)this._installDormant();
  }
  closePhase(){
    this._require(this.state==="capturing","CLOSE_WITHOUT_PREPARED_CAPTURE");
    this._require(this.inflight===0&&this.writer.active.pending===0,"ORIGINAL_REQUESTS_STILL_PENDING");
    let result,error;
    try{this._owned();result=this.writer.finishCohort();}
    catch(e){error=e;this._fail("COHORT_CLOSE_FAILED");}
    finally{try{this._releaseCapture();}catch(e){error??=e;}}
    if(error){this.state="failed";throw error;}
    try{this.results.push(this._save("phase-"+this.phase+"-session.json",{schemaVersion:1,phase:this.phase,
      preparedOutput:this.prepared,capture:result,closedAtUtc:this.now(),deploymentEntryInvokedByAdapter:false,
      processExecutionAuthenticated:false,observerAuthenticated:false,clockAuthenticated:false}));}
    catch(e){this._fail("COHORT_PERSIST_FAILED");this.state="failed";throw e;}
    if(!result.complete){this._fail("COHORT_INCOMPLETE");this.state="failed";throw Error("Business capture session: cohort incomplete; no retry");}
    this.next++;this.phase=null;this.state="between";return result;
  }
  finish(){
    this._require(this.state==="between"&&!this.failed&&this.next===3,"COMPLETE_THREE_COHORTS_REQUIRED");this._owned();verifyCopies();
    const measurement=this.writer.finish(),result={schemaVersion:1,documentType:"build31-business-local-capture-session",measurement,
      phaseSessions:[...this.results],operationalController:false,prepareEntryInvokedByAdapter:false,processExecutionAuthenticated:false,
      observerAuthenticated:false,clockAuthenticated:false,credentialAccessAuthorized:false,deploymentAuthorized:false};
    try{this._save("session-complete.json",result);}catch(e){this._fail("SESSION_COMPLETE_PERSIST_FAILED");throw e;}
    this.state="complete";return result;
  }
  dispose(){
    this._require(this.state!=="disposed","ALREADY_DISPOSED");this._require(this.inflight===0&&(this.writer.active?.pending??0)===0,"ORIGINAL_REQUESTS_STILL_PENDING");
    let error;
    try{
      if(this.state!=="complete")this._fail("SESSION_DISPOSED_INCOMPLETE");
      if(this.hook){this.hook.restore();this.hook=null;}
      if(this.writer.active)this.writer.finishCohort();
    }catch(e){error=e;this._fail("CLEANUP_PERSIST_FAILED");}
    finally{
      try{if(this.boundary==="active")this._releaseCapture(false);else if(this.boundary==="dormant")this._removeDormant();}catch(e){error??=e;}
      try{if(this.cliLoadLease){this.cliLoadLease.release();this.cliLoadLease=null;}}catch(e){this.cleanupIncomplete=true;error??=e;}
      this.state="disposed";
    }
    if(error)throw error;
    if(this.cleanupIncomplete||this.persistenceFailed)throw Error("Business capture session: cleanup or failure persistence incomplete");
  }
}
if(require.main===module){process.stderr.write("Private local capture session has no operational entry.\n");process.exitCode=1;}
module.exports={BusinessCaptureSession31,PHASES,verifyCopies};
