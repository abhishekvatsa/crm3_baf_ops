"use strict";
const bootstrap=require("./business31CaptureBootstrap.cjs");
if(!bootstrap.isComponentChild31("controller-primitives")) {
  bootstrap.runComponentSuiteTest31("controller-primitives");
} else {
  const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os"),cp=require("node:child_process"),crypto=require("node:crypto");
  const {installOwned,runController31,runPhaseChild31,denyParameterWrites,collectCurrentBusinessControls31}=require("./business31OperationalController.cjs");
  const custody=require("./business31CohortProcess.cjs");
  const root=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-controller-primitives-"));
  const sha=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
  const file=(name,value)=>{const out=path.join(root,name);fs.writeFileSync(out,JSON.stringify(value)+"\n",{flag:"wx"});return out;};
  const env=()=>({SystemRoot:process.env.SystemRoot??process.env.SYSTEMROOT,WINDIR:process.env.WINDIR??process.env.SystemRoot,
    HOME:root,USERPROFILE:root,TEMP:root,TMP:root,PATH:path.dirname(process.execPath),
    ...Object.fromEntries(["HOMEDRIVE","HOMEPATH","LOGONSERVER","SYSTEMDRIVE","USERDOMAIN","USERNAME"]
      .filter(name=>process.env[name]!==undefined).map(name=>[name,process.env[name]]))});
  const run=(argv,environment=env())=>cp.spawnSync(process.execPath,["--no-global-search-paths",...argv],{cwd:root,env:environment,windowsHide:true,encoding:"utf8",timeout:30000,maxBuffer:2*1024*1024});
  const config=()=>({schemaVersion:1,documentType:"build31-business-protected-selection",authority:{},execution:{sourceRoot:__dirname,
    helperFiles:bootstrap.sourceMap(__dirname),environment:env(),nodeExecutable:{path:process.execPath,sha256:sha(fs.readFileSync(process.execPath))}}});
  test("fresh fixed controller reaches original authority validation before any CLI import",()=>{
    const input=file("controller-selection.json",config()),result=run([path.join(__dirname,"business31CaptureBootstrap.cjs"),"--business-controller",input,sha(fs.readFileSync(input))]);
    assert.equal(result.error,undefined);assert.equal(result.status,1);assert.match(result.stderr,/original authority inputs fields differ/);
    assert.doesNotMatch(result.stderr,/fresh fixed process|unverified or replaced cached module/);
  });
  test("actual CAPTURE facade admits only its exact main/bootstrap cache and reaches authority guard",()=>{
    const input=file("phase-selection.json",config()),pointer=custody.pointer31(root,input);
    const context=file("context.json",{phase:"callables",evidenceDirectory:root,configuration:pointer});
    const result=run([path.join(__dirname,"captureBusiness31PreparedInputs.cjs"),"--config",context],{...env(),BUSINESS31_PHASE_CONTEXT_SHA256:sha(fs.readFileSync(context))});
    assert.equal(result.error,undefined);assert.equal(result.status,1);assert.match(result.stderr,/original authority inputs fields differ/);
    assert.doesNotMatch(result.stderr,/fresh CAPTURE|unverified or replaced cached module/);
  });
  test("phase context bytes cannot be replaced after parent binding",()=>{
    const context=file("changed-context.json",{phase:"callables"});const before=sha(fs.readFileSync(context));fs.appendFileSync(context," ");
    const result=run([path.join(__dirname,"captureBusiness31PreparedInputs.cjs"),"--config",context],{...env(),BUSINESS31_PHASE_CONTEXT_SHA256:before});
    assert.equal(result.status,1);assert.match(result.stderr,/request bytes differ/);
  });
  test("missing helper bytes refuse before controller evaluation",()=>{
    const value=config();value.execution.helperFiles={...value.execution.helperFiles};delete value.execution.helperFiles["business31CaptureRecorder.cjs"];
    const input=file("missing-producer.json",value),result=run([path.join(__dirname,"business31CaptureBootstrap.cjs"),"--business-controller",input,sha(fs.readFileSync(input))]);
    assert.equal(result.status,1);assert.match(result.stderr,/population bytes differ/);assert.doesNotMatch(result.stderr,/original authority inputs/);
  });
  test("an arbitrary preloaded wrapper cannot turn facade import into a phase entry",()=>{
    const entry=path.join(root,"unapproved-wrapper.cjs");fs.writeFileSync(entry,"require("+JSON.stringify(path.join(__dirname,"captureBusiness31PreparedInputs.cjs"))+ ");\n");
    const result=run([entry]);assert.equal(result.status,1);assert.match(result.stderr,/fixed fresh bootstrap/);
  });
  test("component dispatch never grants controller, phase, or intent operation",async()=>{
    await assert.rejects(runController31({}),/component entry cannot authorize/);
    await assert.rejects(runPhaseChild31({}),/component entry cannot authorize/);
    assert.throws(()=>bootstrap.assertIntentWorker31("manifest"),/fixed intent worker entry/);
    assert.throws(()=>bootstrap.launchBusinessCapture31(),/shared-process call is unsupported/);
  });
  test("owned hook transaction restores exact descriptors",()=>{
    const before=()=>17,after=()=>23,o={request:before},d=Object.getOwnPropertyDescriptor(o,"request");
    const handle=installOwned([[o,"request"]],()=>{o.request=after;return 42;});
    assert.equal(handle.result,42);handle.assertOwned();assert.equal(o.request(),23);handle.restore();assert.deepEqual(Object.getOwnPropertyDescriptor(o,"request"),d);
  });
  test("partial installation failure restores owned writes and preserves the first error",()=>{
    const before=()=>1,o={request:before};assert.throws(()=>installOwned([[o,"request"]],()=>{o.request=()=>2;throw Error("fixture-persist-failed");}),/fixture-persist-failed/);
    assert.equal(o.request,before);
  });
  test("cleanup preserves a foreign hook descriptor",()=>{
    const before=()=>1,foreign=()=>3,o={request:before};const handle=installOwned([[o,"request"]],()=>{o.request=()=>2;});
    Object.defineProperty(o,"request",{value:foreign,enumerable:false,writable:true,configurable:true});
    assert.throws(()=>handle.assertOwned(),/hook ownership changed/);assert.throws(()=>handle.restore(),/foreign hook preserved/);
    assert.equal(o.request,foreign);assert.equal(Object.getOwnPropertyDescriptor(o,"request").enumerable,false);
  });
  test("predecessor prefix cannot skip, reorder, duplicate or supply a PASS object",()=>{
    const p={file:"a.json",sha256:"A".repeat(64),bytes:1};custody.verifyPrefix31([],"callables");custody.verifyPrefix31([{phase:"callables",pointer:p}],"events");
    for(const rows of [[{phase:"events",pointer:p}],[{phase:"callables",pointer:p},{phase:"callables",pointer:p}],[]])assert.throws(()=>custody.verifyPrefix31(rows,"events"),/exact predecessor prefix/);
    assert.throws(()=>custody.verifyPrefix31([{phase:"callables",pointer:{passed:true}}],"events"),/pointer fields/);
  });
  test("private save refuses escaped and existing paths before writing",()=>{
    const outside=path.join(path.dirname(root),"must-not-write-"+path.basename(root)+".json");
    assert.throws(()=>custody.save31(root,outside,{ok:true}),/write escaped/);assert.equal(fs.existsSync(outside),false);
    const target=path.join(root,"once.json");custody.save31(root,target,{original:1});assert.throws(()=>custody.save31(root,target,{original:2}),/EEXIST/);
    assert.deepEqual(JSON.parse(fs.readFileSync(target)),{original:1});
  });
  test("unsettled owned process cannot become successful cohort evidence",()=>{
    const p={schemaVersion:1,documentType:"private-windows-owned-process-result",executable:process.execPath,arguments:[],cwd:root,
      startedAtUtc:"2026-10-05T00:00:00.000Z",resumedAtUtc:"2026-10-05T00:00:00.001Z",completedAtUtc:"2026-10-05T00:00:00.010Z",
      processId:1,jobAssigned:true,resumed:true,exitCode:0,failure:null,cleanupErrors:[],terminationRequested:false,rootExited:true,activeProcesses:1,
      treeComplete:false,outputComplete:true,status:"SUCCESS",authenticated:false,deploymentAuthorized:false,streams:{stdout:{},stderr:{}}};
    assert.throws(()=>custody.verifyOwnedProcess31({root,process:p,executable:process.execPath,args:[],cwd:root,
      earliestUtc:p.startedAtUtc,latestUtc:p.completedAtUtc,stdout:{},stderr:{}}),/complete owned child/);
  });
  // These installation files are inert text. Only the real exported cohort API
  // runs; its spawn boundary is intercepted before any Python process creation.
  function pythonFixture(t) {
    const owned=fs.mkdtempSync(path.join(root,"python-")),pythonRoot=path.join(owned,"selected"),directory=path.join(owned,"cohort");
    fs.mkdirSync(pythonRoot);fs.mkdirSync(directory);
    const files={};
    const put=(name,bytes)=>{const target=path.join(pythonRoot,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);return target;};
    for(const name of ["python.exe","python3.dll","python313.dll","Lib/os.py","Lib/encodings/__init__.py",
      "Lib/pathlib/__init__.py","DLLs/_ctypes.pyd"]){const bytes=Buffer.from("inert, never execute: "+name);put(name,bytes);files[name]=sha(bytes);}
    const python={schemaVersion:2,root:pythonRoot,executable:{path:path.join(pythonRoot,"python.exe"),sha256:files["python.exe"]},files};
    const requestFile=path.join(directory,"process-request.json");fs.writeFileSync(requestFile,"{}\n");
    const args={python,requestFile,evidenceDirectory:owned,directory,environment:{CI:"true"},limits:{commandSeconds:2,cleanupSeconds:1}};
    t.diagnostic("Retained inert cohort/Python fixture: "+owned);
    return {owned,pythonRoot,python,directory,put,args};
  }
  function intercepted(action,body) {
    const previous=cp.spawnSync,calls=[];
    cp.spawnSync=(...args)=>{calls.push(args);return action(...args);};
    try{return body(calls);}finally{cp.spawnSync=previous;}
  }
  const output=()=>({status:0,signal:null,stdout:Buffer.from([0,255,13]),stderr:Buffer.from("original inert diagnostic")});
  test("cohort API uses merged complete-Python schema and exact isolated runner argv",t=>{
    const f=pythonFixture(t),result=output();
    intercepted((exe,args,options)=>{
      assert.equal(exe,f.python.executable.path);
      assert.deepEqual(args,["-I","-S","-B",path.join(__dirname,"runtime_process_runner.py"),"--python-root",f.pythonRoot,f.args.requestFile]);
      assert.equal(options.cwd,f.directory);assert.deepEqual(options.env,{CI:"true"});assert.equal(options.windowsHide,true);
      assert.equal(options.timeout,20000);assert.equal(options.encoding,null);return result;
    },calls=>{assert.equal(custody.runCohortSupervisor31(f.args),result);assert.equal(calls.length,1);});
    for(const name of ["stdout","stderr"])assert.deepEqual(fs.readFileSync(path.join(f.directory,"supervisor-"+name+".bin")),result[name]);
  });
  for(const [name,mutate,expected] of [
    ["legacy selected subset",f=>{f.args.python={executable:f.python.executable,files:f.python.files};},/Python installation fields differ/],
    ["omitted installed member",f=>{delete f.python.files["Lib/pathlib/__init__.py"];},/complete Python population differs/],
    ["bound startup path override",f=>{const bytes=Buffer.from("inert path override");f.put("python313._pth",bytes);f.python.files["python313._pth"]=sha(bytes);},/Python startup override refused/],
    ["parent virtual-environment override",f=>{fs.writeFileSync(path.join(f.owned,"pyvenv.cfg"),"inert outside path");},/Python startup override refused/],
    ["prelaunch stdlib drift",f=>{f.put("Lib/pathlib/__init__.py","changed before launch");},/complete Python population differs/],
  ])test("cohort refuses "+name+" before any Python launch",t=>{
    const f=pythonFixture(t);mutate(f);
    intercepted(()=>{throw Error("INERT_PYTHON_MUST_NOT_EXECUTE");},calls=>{
      assert.throws(()=>custody.runCohortSupervisor31(f.args),expected);assert.equal(calls.length,0);
      assert.equal(fs.existsSync(path.join(f.directory,"supervisor-stdout.bin")),false);
    });
  });
  test("cohort rechecks the complete installation before each child",t=>{
    const f=pythonFixture(t);
    intercepted(()=>output(),calls=>{
      custody.runCohortSupervisor31(f.args);assert.equal(calls.length,1);
      f.put("Lib/pathlib/__init__.py","changed between cohorts");
      assert.throws(()=>custody.runCohortSupervisor31(f.args),/complete Python population differs/);assert.equal(calls.length,1);
    });
  });
  for(const rebind of [false,true])test("cohort retains unsuccessful post-launch drift output"+(rebind?" despite caller-map rebinding":""),t=>{
    const f=pythonFixture(t),result=output();
    intercepted(()=>{const bytes=Buffer.from("changed during intercepted launch");f.put("Lib/pathlib/__init__.py",bytes);
      if(rebind)f.python.files["Lib/pathlib/__init__.py"]=sha(bytes);return result;
    },calls=>{
      assert.throws(()=>custody.runCohortSupervisor31(f.args),error=>{
        assert.match(error.message,/complete Python population differs/);assert.equal(error.pythonResult,result);return true;
      });assert.equal(calls.length,1);
    });
    for(const name of ["stdout","stderr"])assert.deepEqual(fs.readFileSync(path.join(f.directory,"supervisor-"+name+".bin")),result[name]);
    assert.equal(fs.existsSync(path.join(f.directory,"attempt-result.json")),false);
  });
  // Actual installed Config/env helpers only: no CLI entry, prepare, credentials,
  // network or subprocess. The synthetic pointer graph proves custody, not authority.
  const PARAM="CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK",PROJECT="crm3-baf-ops-b8638";
  let installed;
  function installedConfig() {
    if(installed)return installed;
    const net=require("node:net"),tls=require("node:tls");
    const slots=[[net.Socket.prototype,"connect"],[tls,"connect"],[globalThis,"fetch"],
      ...["spawn","spawnSync","exec","execSync","execFile","execFileSync","fork"].map(name=>[cp,name])];
    const denial=installOwned(slots,()=>{for(const [object,name] of slots)object[name]=()=>{throw Error("REAL_NETWORK_OR_PROCESS_FORBIDDEN");};});
    const bound=require("./business31CaptureFixture.cjs").createBoundCliFixture31(path.resolve(__dirname,"../.."),root);
    test.after(()=>{try{bound.assertOriginalUnchanged();}finally{try{bound.lease.release();}finally{denial.restore();}}});
    assert.equal(require(path.join(path.dirname(bound.cli),"package.json")).version,"15.22.4");
    installed={Config:require(path.join(bound.cli,"config.js")).Config,env:require(path.join(bound.cli,"functions/env.js"))};
    return installed;
  }
  function parameterFixture(t) {
    const owned=fs.mkdtempSync(path.join(root,"parameters-")),repoRoot=path.join(owned,"source"),evidenceDirectory=path.join(owned,"evidence");
    fs.mkdirSync(path.join(repoRoot,"functions"),{recursive:true});fs.mkdirSync(evidenceDirectory);
    const source={commit:"1".repeat(40),tree:"2".repeat(40),functionsTree:"3".repeat(40)},approvalPointer={commit:"4".repeat(40),file:"decision.json",sha256:"A".repeat(64)};
    let count=0;const retain=value=>custody.save31(evidenceDirectory,path.join(evidenceDirectory,"original-"+(++count)+".json"),value);
    const parametersOriginal=retain({schemaVersion:1,documentType:"build31-business-intent-parameters",source,parameters:{[PARAM]:"false"}});
    const intendedHashInputs=retain({syntheticInnerIntent:true});
    const intentPreparation=retain({schemaVersion:1,documentType:"build31-business-intent-preparation",source,intendedHashInputs,parametersOriginal});
    const ctx={repoRoot,evidenceDirectory,source,approvalPointer,contract:{schemaVersion:2,intentPreparation,intendedHashInputs},
      runtime:{nodeExecutable:process.execPath,nodeSha256:sha(fs.readFileSync(process.execPath))},producerBindings:{},
      decision:{executionWindow:{notBeforeUtc:"2026-10-06T00:00:00.000Z",notAfterUtc:"2026-10-06T01:00:00.000Z"}}};
    const phase="callables",directory=custody.phaseDirectory31(ctx,phase);fs.mkdirSync(directory,{recursive:true});
    const parameterConfig=custody.createParameterConfig31(ctx,phase);
    const sourceFunctions=[{source:"functions",codebase:"default",disallowLegacyRuntimeConfig:true,ignore:["node_modules",".git"]}];
    fs.writeFileSync(path.join(repoRoot,"firebase.json"),JSON.stringify({functions:sourceFunctions})+"\n");
    const before=fs.readFileSync(path.join(repoRoot,"firebase.json"));
    t.diagnostic("Retained local parameter custody fixture: "+owned);
    return {owned,ctx,phase,directory,parameterConfig,sourceFunctions,parametersOriginal,retain,before,
      bind(options,Config){return custody.bindNativeConfig31({ctx,phase,parameterConfig,sourceFunctions,options,Config});}};
  }
  function phaseGraph(f) {
    const {ctx,phase,directory,parameterConfig}=f;
    const configuration=f.retain({schemaVersion:1,documentType:"build31-business-protected-selection",authority:{decisionPointer:ctx.approvalPointer,
      sourceCommit:ctx.source.commit,trustedVerifier:{files:ctx.producerBindings}},execution:{}});
    const claim=custody.save31(ctx.evidenceDirectory,path.join(directory,"phase-claim.json"),{schemaVersion:1,documentType:"build31-business-phase-claim",
      phase,source:ctx.source,approvalPointer:ctx.approvalPointer,predecessors:[],claimedAtUtc:"2026-10-06T00:00:01.000Z"});
    const contextValue={schemaVersion:1,documentType:"build31-business-phase-context",phase,source:ctx.source,approvalPointer:ctx.approvalPointer,
      evidenceDirectory:ctx.evidenceDirectory,configuration,claim,predecessors:[],parameterConfig};
    const context=custody.save31(ctx.evidenceDirectory,path.join(directory,"context.json"),contextValue);
    const startValue={schemaVersion:1,documentType:"build31-business-cohort-start",phase,source:ctx.source,approvalPointer:ctx.approvalPointer,
      context,claim,predecessors:[],parameterConfig,startedAtUtc:"2026-10-06T00:00:02.000Z",executable:ctx.runtime.nodeExecutable,nodeSha256:ctx.runtime.nodeSha256,
      cwd:ctx.repoRoot,arguments:custody.commandArguments31(ctx,phase),sourceBefore:{synthetic:true},producerBindings:ctx.producerBindings};
    const start=custody.save31(ctx.evidenceDirectory,path.join(directory,"attempt-start.json"),startValue);
    return {contextValue,startValue,record:{...startValue,context,start},verify(record){return custody.verifyPhaseStart31({ctx,record:record??this.record,predecessors:[]});}};
  }
  test("actual installed Config/env consumes governed false with zero dotenv writes and source unchanged",t=>{
    const {Config,env}=installedConfig(),f=parameterFixture(t),config=new Config({functions:structuredClone(f.sourceFunctions)},{projectDir:f.ctx.repoRoot});
    const options={project:PROJECT,config},binding=f.bind(options,Config),guard=denyParameterWrites();
    try {
      const userEnvOpt={projectId:PROJECT,functionsSource:config.path("functions"),configDir:config.path(config.src.functions[0].configDir)};
      const values=env.loadUserEnvs(userEnvOpt);assert.deepEqual(values,{[PARAM]:"false"});
      env.writeResolvedParams({[PARAM]:{internal:false,toString(){throw Error("ALREADY_BOUND_VALUE_MUST_NOT_BE_WRITTEN");}}},values,userEnvOpt);
      assert.throws(()=>fs.appendFileSync(path.join(userEnvOpt.configDir,".env"),"forbidden"),/parameter env-file mutation/);
      binding.assertUnchanged();assert.deepEqual(fs.readFileSync(path.join(f.ctx.repoRoot,"firebase.json")),f.before);
      assert.deepEqual(fs.readdirSync(userEnvOpt.configDir),[".env."+PROJECT]);assert.deepEqual(fs.readdirSync(config.path("functions")),[]);
    } finally {guard.restore();}
  });
  for(const [name,mutate,pattern] of [
    ["missing dotenv",f=>fs.unlinkSync(path.join(f.parameterConfig.directory,".env."+PROJECT)),/sole governed dotenv/],
    ["changed dotenv",f=>fs.appendFileSync(path.join(f.parameterConfig.directory,".env."+PROJECT),"#changed\n"),/private original bytes changed/],
    ["extra dotenv",f=>fs.writeFileSync(path.join(f.parameterConfig.directory,".env"),"OTHER=false\n"),/sole governed dotenv/],
    ["extra subdirectory",f=>fs.mkdirSync(path.join(f.parameterConfig.directory,"extra")),/sole governed dotenv/],
    ["same-byte swapped original pointer",f=>{f.parameterConfig.parametersOriginal=f.retain(JSON.parse(fs.readFileSync(path.join(f.ctx.evidenceDirectory,f.parametersOriginal.file))));},/original pointer differs/],
    ["rebound preparation pointer",f=>{f.parameterConfig.intentPreparation=f.retain({sameClaim:true});},/preparation pointer differs/],
    ["wrong phase",f=>{f.parameterConfig.phase="events";},/original governed parameter config/],
  ])test("governed custody rejects "+name,t=>{const f=parameterFixture(t);mutate(f);assert.throws(()=>custody.verifyParameterConfig31(f.ctx,f.phase,f.parameterConfig),pattern);});
  test("redirected parameter directory refuses before reading dotenv",t=>{
    const f=parameterFixture(t),original=f.parameterConfig.directory,moved=original+"-original";fs.renameSync(original,moved);
    fs.symlinkSync(moved,original,process.platform==="win32"?"junction":"dir");
    assert.throws(()=>custody.verifyParameterConfig31(f.ctx,f.phase,f.parameterConfig),/redirected original/);
  });
  for(const parameters of [{[PARAM]:"true"},{[PARAM]:"false",OTHER:"false"}])test("bound input cannot select an ungoverned parameter value/population",t=>{
    const f=parameterFixture(t),parametersOriginal=f.retain({schemaVersion:1,documentType:"build31-business-intent-parameters",source:f.ctx.source,parameters});
    const envelope=JSON.parse(fs.readFileSync(path.join(f.ctx.evidenceDirectory,f.ctx.contract.intentPreparation.file)));
    f.ctx.contract.intentPreparation=f.retain({...envelope,parametersOriginal});
    assert.throws(()=>custody.governedParameter31(f.ctx),/exact governed AppCheck parameter required/);
  });
  test("matched context/start binds config; a replay-swapped pointer refuses",t=>{
    const f=parameterFixture(t),graph=phaseGraph(f);assert.equal(graph.verify().context.parameterConfig.file.sha256,f.parameterConfig.file.sha256);
    const changed=structuredClone(graph.startValue);changed.parameterConfig.parametersOriginal=f.retain({unrelated:true});
    const startFile=path.join(f.directory,"attempt-start.json");fs.writeFileSync(startFile,JSON.stringify(changed)+"\n");
    const record={...graph.record,start:custody.pointer31(f.ctx.evidenceDirectory,startFile)};
    assert.throws(()=>graph.verify(record),/cohort parameter config differs/);
  });
  for(const [name,mutate,pattern] of [
    ["project alias",(o,f)=>{o.projectAlias="production";},/project\/source root or alias/],
    ["different project",o=>{o.project="other";},/project\/source root or alias/],
    ["different root",(o,f)=>{o.config.projectDir=f.owned;},/project\/source root or alias/],
    ["preexisting configDir",o=>{o.config.set("functions.0.configDir","elsewhere");},/loaded source Functions config differs/],
    ["changed source entry",o=>{o.config.set("functions.0.source","other");},/loaded source Functions config differs/],
    ["conflicting materialized config",o=>{o.config.data.functions=[{source:"other"}];},/materialized source Functions config differs/],
  ])test("native Config binding refuses "+name,t=>{const {Config}=installedConfig(),f=parameterFixture(t),config=new Config({functions:structuredClone(f.sourceFunctions)},{projectDir:f.ctx.repoRoot});
    const options={project:PROJECT,config};mutate(options,f);assert.throws(()=>f.bind(options,Config),pattern);assert.deepEqual(fs.readFileSync(path.join(f.ctx.repoRoot,"firebase.json")),f.before);});
  test("post-bind native config and dotenv drift are refused at subsequent checkpoints",t=>{
    const {Config}=installedConfig(),f=parameterFixture(t),options={project:PROJECT,config:new Config({functions:structuredClone(f.sourceFunctions)},{projectDir:f.ctx.repoRoot})};
    const binding=f.bind(options,Config);options.config.set("functions.0.configDir",f.owned);assert.throws(()=>binding.assertUnchanged(),/governed native Config changed/);
  });

  // Exact public location IDs observed in the 2026-10-08 Run list response.
  // Transport and all project resources below are synthetic; no cloud authority is claimed.
  const RUN_LOCATIONS=["africa-south1","asia-east1","asia-east2","asia-northeast1","asia-northeast2","asia-northeast3","asia-south1","asia-south2","asia-southeast1","asia-southeast2","asia-southeast3","australia-southeast1","australia-southeast2","europe-central2","europe-north1","europe-north2","europe-southwest1","europe-west1","europe-west10","europe-west12","europe-west2","europe-west3","europe-west4","europe-west6","europe-west8","europe-west9","me-central1","me-central2","me-west1","northamerica-northeast1","northamerica-northeast2","northamerica-south1","southamerica-east1","southamerica-west1","us-central1","us-east1","us-east4","us-east5","us-south1","us-west1","us-west2","us-west3","us-west4"];
  const controlModule=require("./backendRuntimeControls31.cjs"),iamGuard=require("./scopedCallableInvokerIam.js");
  const LOCATION_URL=`https://run.googleapis.com/v1/projects/${PROJECT}/locations?pageSize=100`;
  function controlFixture({locations=RUN_LOCATIONS,amend=()=>undefined}={}) {
    const requests=[];
    const read=async(url,method="GET",body)=>{
      const call={url,method,body:body??null};requests.push(call);
      const override=amend(call,requests);
      if(override!==undefined)return {...call,httpStatus:200,...override};
      let value;
      if(url===`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`)value={projectId:PROJECT,projectNumber:"894346496105"};
      else if(url===`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions?pageSize=100`)value={functions:[]};
      else if(url===LOCATION_URL)value={locations:locations.map(locationId=>({locationId}))};
      else if(locations.some(name=>url===`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${name}/services?pageSize=100`))value={services:[]};
      else if(url===`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts?pageSize=100`)value={accounts:[]};
      else if(url===`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`&&method==="POST"){
        assert.deepEqual(body,{options:{requestedPolicyVersion:3}});value={bindings:[]};
      } else if(url===controlModule.SCHEDULER_URL)value={name:"synthetic existing scheduler"};
      else throw Error("UNSELECTED_SYNTHETIC_TRANSPORT: "+url);
      return {url,method,httpStatus:200,bodyText:JSON.stringify(value)};
    };
    const input={sourceCommit:"1".repeat(40),approvalSha256:"A".repeat(64),read,unavailableRunRegion:iamGuard.unavailableRunRegion};
    return {requests,input};
  }
  const withoutTimes=value=>{const copy=structuredClone(value);delete copy.raw.startedAtUtc;delete copy.raw.completedAtUtc;return copy;};
  test("business controls collect all 43 regions without dropping two-digit locations",async()=>{
    const f=controlFixture(),value=await collectCurrentBusinessControls31(f.input);
    assert.equal(RUN_LOCATIONS.length,43);assert.deepEqual(value.raw.runInventories.map(x=>x.location),RUN_LOCATIONS);
    assert.equal(value.raw.runLocations.length,1);assert.deepEqual(value.raw.runIam,[]);
    for(const name of RUN_LOCATIONS)assert.equal(f.requests.filter(x=>x.url===`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${name}/services?pageSize=100`).length,1);
    assert.equal(value.raw.sourceCommit,f.input.sourceCommit);assert.equal(value.raw.approvalSha256,f.input.approvalSha256);
  });
  test("business controls preserve original collector behavior for prior one-digit inventories",async()=>{
    const locations=RUN_LOCATIONS.filter(x=>!['europe-west10','europe-west12'].includes(x));
    const old=controlFixture({locations}),current=controlFixture({locations});
    assert.deepEqual(withoutTimes(await collectCurrentBusinessControls31(current.input)),withoutTimes(await controlModule.collectCurrentRawControls31(old.input)));
    assert.deepEqual(current.requests,old.requests);
  });
  test("business controls original immutable collector still demonstrates the two-digit refusal",async()=>{
    await assert.rejects(controlModule.collectCurrentRawControls31(controlFixture().input),/Unexpected Run region/);
  });
  for(const location of ["europe-west100","europe-west1/../../projects/other","europe-west1?project=other","europe-west1#fragment","https://evil.example","europe-west1@evil.example","//evil.example","europe-west1%2Fservices","europe-west1\\services","europe-west1\n","europe-west1\r\n","europe-west1\0","europe-west１２",["europe-west1"],null,12,{}]) {
    test("business controls refuse malformed region "+JSON.stringify(location),async()=>{
      const f=controlFixture({locations:[location]});
      await assert.rejects(collectCurrentBusinessControls31(f.input),/Unexpected Run region/);
      assert.equal(f.requests.length,3,"refused before any regional service request");
    });
  }
  test("business controls preserve complete paginated location coverage and encode tokens",async()=>{
    const token="synthetic token/+",second=LOCATION_URL+"&pageToken="+encodeURIComponent(token);
    const f=controlFixture({amend:({url})=>url===LOCATION_URL?{bodyText:JSON.stringify({locations:RUN_LOCATIONS.slice(0,20).map(locationId=>({locationId})),nextPageToken:token})}:url===second?{bodyText:JSON.stringify({locations:RUN_LOCATIONS.slice(20).map(locationId=>({locationId}))})}:undefined});
    const value=await collectCurrentBusinessControls31(f.input);
    assert.deepEqual(value.raw.runInventories.map(x=>x.location),RUN_LOCATIONS);assert.equal(value.raw.runLocations.length,2);
    assert.equal(f.requests.filter(x=>x.url===second).length,1);
    assert.equal(iamGuard.pages(value.raw.runLocations,LOCATION_URL.split('?')[0],'locations').length,43);
  });
  for(const [label,body,pattern] of [
    ["unreachable",{locations:[],unreachable:["europe-west10"]},/response incomplete/],
    ["error",{error:{message:"synthetic error"}},/response incomplete/],
    ["invalid population",{locations:{}},/population invalid/],
    ["invalid token",{locations:[],nextPageToken:12},/pagination token/]
  ])test("business controls preserve "+label+" refusal",async()=>{
    const f=controlFixture({amend:({url})=>url===LOCATION_URL?{bodyText:JSON.stringify(body)}:undefined});
    await assert.rejects(collectCurrentBusinessControls31(f.input),pattern);
  });
  test("business controls refuse repeated page tokens",async()=>{
    const f=controlFixture({amend:({url})=>url.startsWith(LOCATION_URL)?{bodyText:JSON.stringify({locations:[],nextPageToken:"repeat"})}:undefined});
    await assert.rejects(collectCurrentBusinessControls31(f.input),/repeated pagination token/);
    assert.equal(f.requests.filter(x=>x.url.startsWith(LOCATION_URL)).length,2);
  });
  test("business controls retain the finite pagination bound",async()=>{
    let count=0;const f=controlFixture({amend:({url})=>url.startsWith(LOCATION_URL)?{bodyText:JSON.stringify({locations:[],nextPageToken:String(++count)})}:undefined});
    await assert.rejects(collectCurrentBusinessControls31(f.input),/pagination exceeds bound/);assert.equal(count,1000);
  });
  function locationDenial(location) {
    return {httpStatus:403,bodyText:JSON.stringify({error:{code:403,status:"PERMISSION_DENIED",details:[{"@type":"type.googleapis.com/google.rpc.ErrorInfo",reason:"LOCATION_POLICY_VIOLATED",domain:"googleapis.com",metadata:{location,consumer:"projects/894346496105",service:""}}]}})};
  }
  test("business controls retain only the original measured me-central2 exclusion",async()=>{
    const url=`https://run.googleapis.com/v2/projects/${PROJECT}/locations/me-central2/services?pageSize=100`;
    const f=controlFixture({amend:call=>call.url===url?locationDenial("me-central2"):undefined}),value=await collectCurrentBusinessControls31(f.input);
    assert.deepEqual(value.raw.runInventories.map(x=>x.location),RUN_LOCATIONS);
    const row=value.raw.runInventories.find(x=>x.location==="me-central2");assert.equal(row.unavailable.httpStatus,403);assert.equal(row.pages,undefined);
    assert.equal(iamGuard.unavailableRunRegion(row.unavailable,"me-central2","894346496105").location,"me-central2");
  });
  for(const location of ["asia-south1","europe-west10"])test("business controls cannot exclude "+location,async()=>{
    const url=`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location}/services?pageSize=100`;
    await assert.rejects(collectCurrentBusinessControls31(controlFixture({locations:[location],amend:call=>call.url===url?locationDenial(location):undefined}).input),/cannot be excluded/);
  });
  test("business controls reject an unproven me-central2 denial",async()=>{
    const url=`https://run.googleapis.com/v2/projects/${PROJECT}/locations/me-central2/services?pageSize=100`;
    await assert.rejects(collectCurrentBusinessControls31(controlFixture({locations:["me-central2"],amend:call=>call.url===url?{httpStatus:403,bodyText:'{"error":{"code":403,"status":"PERMISSION_DENIED","details":[]}}'}:undefined}).input),/unambiguous ErrorInfo/);
  });
  test("business controls propagate transport failure without retry or a partial result",async()=>{
    const f=controlFixture({amend:({url})=>{if(url===LOCATION_URL)throw Error("SYNTHETIC_TRANSPORT_FAILURE");}});
    await assert.rejects(collectCurrentBusinessControls31(f.input),/SYNTHETIC_TRANSPORT_FAILURE/);
    assert.equal(f.requests.filter(x=>x.url===LOCATION_URL).length,1);
  });

  function populatedControlsFixture() {
    const policy=JSON.parse(fs.readFileSync(path.join(__dirname,"../../release/function-fleet-runtime-identity-policy.json"))),names=Object.keys(policy.functionBindings);
    const original=require("./business31RawControlsFixture.cjs").makeRawControls({policy,sourceCommit:"1".repeat(40),approvalSha256:"A".repeat(64),
      startedAtUtc:"2026-10-08T00:00:00.000Z",completedAtUtc:"2026-10-08T00:00:01.000Z",endpointLabels:Object.fromEntries(names.map(name=>[name,"2".repeat(40)]))});
    original.raw.runLocations[0].bodyText=JSON.stringify({locations:RUN_LOCATIONS.map(locationId=>({locationId}))});
    const target=original.raw.runInventories[0];
    original.raw.runInventories=RUN_LOCATIONS.map(location=>location===target.location?target:{location,pages:[{method:"GET",httpStatus:200,
      url:`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location}/services?pageSize=100`,bodyText:'{"services":[]}'}]});
    const responses=[original.raw.project,...original.raw.functions,...original.raw.runLocations,
      ...original.raw.runInventories.flatMap(x=>x.pages),...original.raw.runIam.map(x=>x.response),
      ...original.raw.accounts,...original.raw.accountIam.map(x=>x.response),original.raw.projectIam,original.scheduler];
    const selected=new Map(responses.map(response=>[response.method+" "+response.url,response]));assert.equal(selected.size,responses.length);
    const requests=[];const read=async(url,method="GET",body)=>{
      const key=method+" "+url;requests.push(key);assert(selected.has(key),"exact fixture transport only: "+key);
      if(url===original.raw.projectIam.url)assert.deepEqual(body,{options:{requestedPolicyVersion:3}});
      return structuredClone(selected.get(key));
    };
    return {policy,original,requests,selected,input:{sourceCommit:"1".repeat(40),approvalSha256:"A".repeat(64),read,unavailableRunRegion:iamGuard.unavailableRunRegion}};
  }
  const summarizeControls=(f,raw)=>controlModule.summarizeRaw({raw,policy:f.policy,sourceCommit:f.input.sourceCommit,guard:iamGuard});
  test("business controls real exported reader roundtrips 19 Functions, 15 identities and all 43 regions through unchanged comparators",async()=>{
    const f=populatedControlsFixture(),actual=await collectCurrentBusinessControls31(f.input);
    assert.deepEqual(f.requests.slice().sort(),[...f.selected.keys()].sort());
    assert.deepEqual(withoutTimes(actual),withoutTimes(f.original));
    const expected=summarizeControls(f,f.original.raw),measured=summarizeControls(f,actual.raw);
    const result=controlModule.compareWithSupplement({before:expected,after:measured,policy:f.policy,runtime:"nodejs22",declaredMaxInstances:20});
    assert.equal(result.functionCount,19);assert.equal(Object.keys(measured.accountPolicies).length,15);
    assert.equal(actual.raw.runInventories.length,43);assert.equal(result.normalizedDeploymentOutputs.validatedFunctionPairs,38);
    assert.deepEqual(result.normalizedDeploymentOutputs.changedFunctions,[]);
    assert.deepEqual(controlModule.schedulerControl31(actual.scheduler),controlModule.schedulerControl31(f.original.scheduler));
    assert.equal(Object.hasOwn(result,"deploymentAuthorized"),false);
  });
  test("business controls unchanged comparator refuses omission of a two-digit region",async()=>{
    const f=populatedControlsFixture(),actual=await collectCurrentBusinessControls31(f.input);
    actual.raw.runInventories=actual.raw.runInventories.filter(x=>x.location!=="europe-west10");
    assert.throws(()=>summarizeControls(f,actual.raw),/Incomplete Run region coverage/);
  });
  test("business controls unchanged comparator still refuses App Check enforcement drift",async()=>{
    const f=populatedControlsFixture(),actual=await collectCurrentBusinessControls31(f.input);
    const page=JSON.parse(actual.raw.functions[0].bodyText);page.functions[0].serviceConfig.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK="true";
    actual.raw.functions[0].bodyText=JSON.stringify(page);
    assert.throws(()=>controlModule.compareWithSupplement({before:summarizeControls(f,f.original.raw),after:summarizeControls(f,actual.raw),policy:f.policy,runtime:"nodejs22",declaredMaxInstances:20}),/AppCheck/);
  });

  test("business controls run through the unchanged cohort verifier before Firebase prepare",()=>{
    const source=fs.readFileSync(path.join(__dirname,"business31OperationalController.cjs"),"utf8");
    const collect=source.indexOf("const raw=await collectCurrentBusinessControls31(");
    const verify=source.indexOf("controls.verifyCurrentCohortControls31(",collect);
    const prepare=source.indexOf("const result=await originalPrepare.apply(",verify);
    assert(collect>0&&verify>collect&&prepare>verify);
  });

  // Scratch originals are retained for diagnosing child startup and refusal results.
}
