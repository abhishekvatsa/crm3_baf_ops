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
  "business31BackendAuthority.cjs": "1E4D671291118C602BD6D98694E46140DB245AFEB955435624B3835E2611C536",
  "business31NpmBinMaterialization.cjs": "AFA843F2091DD4815D53609E93249E2DB8A0426F58F2737B075C79057D64DF2E",
  "business31ExecutionContract.cjs": "08290B0898AC0154E78AD28C3FF285AC7F1B8EA1110BB913D54DEAA9294D70C2",
  "business31SourceAdmission.cjs": "98034CA4E046E663CEB3184F62F94D06230DEFC007240B4E85BA446E3A6D4D30",
  "business31TrustedInput.cjs": "2C26968443646D6962FEFBEEE200F219F8B5D3CAA72F22D6D41D3A3C041997A8",
  "captureBackendRuntimePreparedInputs31.cjs": "23C332B53A97DE7F5C328C9DE8EF63F160231B8ABBE1B99D7E76EB3F5C211387",
  "captureBusiness31PreparedHook.cjs": "0BD2A5D549B424E5EE2C3738A50FBF0958E739164AE306ECE3AAC406FD7D3BAB",
  "captureBusiness31PreparedInputs.cjs": "40312C352572FD8411ACACFD5C7092B1EF77124CAA45D9C3FA73CD5D84B69144",
  "clientBuildTooling31.historical-fixture.cjs": "4675CE35F06DB75334ABCD0841D1C7E07F65B4029CC0363D7FD279B539F829DB",
  "clientBuildToolingCompatibility31.cjs": "41A88310EF277B32056B58C779070B764FD6ACE27CA6C63A074C8B23BF08C7F2",
  "clientBuildToolingGitSnapshots31.cjs": "3549713D8E0F36B0C38324C4DD6BEA8D1FFE52ECF281C62C7AEE49AD552E9A68",
  "clientBuildToolingReadbacks31.cjs": "A36AC3AF221B27C60B30EDD0F78B089E6CD6A7B54D0D7E39A96963A757FB7617",
  "clientBuildToolingRuntime31.synthetic-fixture.cjs": "6DC27DE2DDA5CC3CCA589A8DDA44BAA39C26FC0DCAD0F7443B011878243145C5",
  "clientRuntimeCompatibility31.cjs": "58D846997E8247BC065B4F0435E4FE04E5CBD378CDCB02171EFB43DAAE3574E4",
  "closure-preflight31.cjs": "E3A40331DE2153B12309293558143119F5F75E3D0BE7C50489BAEC494AF33F8D",
  "collectClientBuildToolingRuntime31.cjs": "1DA6A7B21752CDA4C4F0C25BCCA7F0AE85705A8B889584524EF970285E7B1DB4",
  "collectClientDevelopmentToolIam31.cjs": "7B99AABBE4F049535569ECCBCD33031ED77082679259417A11E7C9A41C26A9BA",
  "executeBackendRuntime31.cjs": "E76B812957049096AD4B8BF83E25C7BD4C35A06A4534E78253FC30BE4CFFB2BF",
  "privateEvidenceBundle31.cjs": "B5CE8865DAEA9258F3F1E6B1D406D24605BA69A64D570DC21248FDE120010557",
  "runtimeBackendPrivateReplay31.cjs": "FB1485F922E266F215572C9AD2016BDFC073F5BA3630226BDB8332A3AEC8F828",
  "runtimeDeploymentTransportGuard31.cjs": "CBE08BCBD7EC96306A42586E12A82C4EB0CEC1E4B99AFE209906E5E9AEF426CE",
  "runtimePilotAuthority31.cjs": "37413B1AA0BBC311F5BEA2405C5D4D2AA4FFE62F148D4375127FC19D6A993542"
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
    need(typeof observeLive === "function", "measurement observer required; it confers no authority");
    const library=path.dirname(path.dirname(admission.runtime.cliEntrypoint)),apiFile=path.join(library,"apiv2.js");
    need(sha(fs.readFileSync(apiFile))===admission.runtime.instrumentationProducerSha256.api,"actual API producer differs");
    this.api=require(apiFile);need(typeof this.api.Client==="function","actual installed Client required");
    this.writerModule=require("./captureBusiness31PreparedInputs.cjs");this.hookModule=require("./captureBusiness31PreparedHook.cjs");
    this.writer=new this.writerModule.BusinessCapture31({evidenceDirectory,source,approvalPointer,cohorts,now});
    this.input={admission,envelopeBytes,archiveExpectedFiles,guardInputs};this.observeLive=observeLive;this.now=now;
    const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),Module=require("node:module");
    this.slots=[[this.api.Client.prototype,"request"],[https,"request"],[https,"get"],[http,"request"],[http,"get"],
      [net.Socket.prototype,"connect"],[tls,"connect"],[Module,"_load"],[globalThis,"fetch"]];
    this.state="between";this.failed=false;this.next=0;this.inflight=0;this.phase=null;this.hook=null;
    this.captureRestore=null;this.owner=null;this.boundary=null;this.results=[];this.firstFailure=null;
    this.persistenceFailed=false;this.cleanupIncomplete=false;
    // No shared hooks exist until initial evidence persistence has succeeded.
    this._save("session-start.json",{schemaVersion:1,source,approvalPointer,phaseOrder:PHASES,
      sourceOnlyMeasurement:true,operationalEntryPresent:false,observerAuthenticated:false,clockAuthenticated:false,deploymentAuthorized:false});
    this._installDormant();
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
  _owned(){this._require(this._matches(this.owner),"HOOK_OWNERSHIP_CHANGED");}
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
      this.state="disposed";
    }
    if(error)throw error;
    if(this.cleanupIncomplete||this.persistenceFailed)throw Error("Business capture session: cleanup or failure persistence incomplete");
  }
}
if(require.main===module){process.stderr.write("Private local capture session has no operational entry.\n");process.exitCode=1;}
module.exports={BusinessCaptureSession31,PHASES,verifyCopies};
