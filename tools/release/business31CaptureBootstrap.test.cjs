"use strict";
// Fixed, credential-free component cases. Component source/Node hashes are local
// measurements, never deployment approval or a hostile-host sandbox.
const fs=require("node:fs"),path=require("node:path"),os=require("node:os"),crypto=require("node:crypto"),assert=require("node:assert/strict"),cp=require("node:child_process");
const sha=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const CASES=["package-main","package-exports","cached-client","cached-apply","cached-writer","cached-hook","escaped-registrar","extension-before","extension-after","compile-before","compile-after"];
const SHARED=new Set(["cached-writer","cached-hook","extension-before","compile-before"]);
function cleanEnv(dir){const env={};for(const key of ["SystemRoot","SYSTEMROOT","WINDIR"])if(process.env[key]!==undefined)env[key]=process.env[key];for(const key of ["HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","TEMP","TMP"]){const value=path.join(dir,key);fs.mkdirSync(value);env[key]=value;}return env;}
function writeObservation(root,value){fs.writeFileSync(path.join(root,"OBSERVATION.json"),JSON.stringify(value,null,2)+"\n",{flag:"wx"});process.stdout.write(JSON.stringify(value)+"\n");}
function blockExternal(){const http=require("node:http"),https=require("node:https"),net=require("node:net"),tls=require("node:tls");for(const api of [http,https])for(const key of ["request","get"])api[key]=()=>{throw Error("NETWORK_FORBIDDEN");};net.Socket.prototype.connect=tls.connect=()=>{throw Error("SOCKET_FORBIDDEN");};globalThis.fetch=()=>{throw Error("FETCH_FORBIDDEN");};for(const key of ["exec","execSync","execFile","execFileSync","spawn","spawnSync","fork"])cp[key]=()=>{throw Error("CHILD_FORBIDDEN");};}
async function runCase(kind,componentData){
 assert(CASES.includes(kind)||kind==="installed-positive"||kind==="environment-positive");const root=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-bootstrap-case-"));
 if(kind==="environment-positive"){
  assert.equal(componentData,null);assert.equal(process.env.NODE_OPTIONS,undefined);assert.equal(process.env.NODE_PATH,undefined);assert.equal(globalThis.__BOOTSTRAP_PRELOAD_MARKER__,undefined);blockExternal();
  const cliRoot=path.join(root,"node_modules"),lib=path.join(cliRoot,"firebase-tools/lib"),file=path.join(lib,"bin/firebase.js");fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,"exports.value=42;\n",{flag:"wx"});
  const map=path.join(root,"cli-map.json"),bytes=Buffer.from(JSON.stringify({"firebase-tools/lib/bin/firebase.js":sha(fs.readFileSync(file))}));fs.writeFileSync(map,bytes,{flag:"wx"});
  const lease=require("./captureBusiness31PreparedInputs.cjs").installCliLoadBoundary31({cliEntrypoint:file,cliFileBindings:{path:map,sha256:sha(bytes)}});assert.equal(require(file).value,42);lease.assertHealthy();lease.release();
  writeObservation(root,{kind,passed:true,inertValue:42,preloadMarkerExecuted:false,nodeOptionsStripped:true,nodePathStripped:true,operationalAuthority:false});return;
 }
 if(kind!=="installed-positive"){assert.equal(componentData,null);return runSynthetic(kind,root,__dirname);}
 assert.deepEqual(Object.keys(componentData),["runtime"]);blockExternal();
 const runtime=componentData.runtime,writer=require("./captureBusiness31PreparedInputs.cjs"),lease=writer.installCliLoadBoundary31(runtime),lib=path.dirname(path.dirname(runtime.cliEntrypoint));
 const api=require(path.join(lib,"apiv2.js")),apply=require(path.join(lib,"deploy/functions/cache/applyHash.js"));
 assert.equal(typeof api.Client,"function");assert.equal(typeof apply.applyBackendHashToBackends,"function");assert.equal(JSON.parse(fs.readFileSync(path.join(lib,"../package.json"),"utf8")).version,"15.22.4");lease.assertHealthy();
 const cliRoot=path.dirname(path.dirname(lib)),loaded=Object.keys(require.cache).filter(file=>file.startsWith(cliRoot+path.sep)).length;assert(loaded>10);lease.release();
 writeObservation(root,{kind,passed:true,actualInstalledCliVersion:"15.22.4",loadedModules:loaded,apiLoaded:true,applyHashLoaded:true,apiInvoked:false,prepareInvoked:false,networkUsed:false,credentialsUsed:false,operationalAuthority:false});
}
module.exports={runCase};
if(process.argv[2]==="--untrusted-child")runCase(process.argv[3],null).catch(error=>{console.error(error);process.exitCode=1;});
else if(process.argv[2]!=="--component-child"){
 const test=require("node:test"),bootstrap=require("./business31CaptureBootstrap.cjs"),scratch=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-bootstrap-regressions-"));
 for(const kind of CASES)test("trusted bootstrap closes original18f: "+kind,()=>{
  const dir=path.join(scratch,kind);fs.mkdirSync(dir);
  if(SHARED.has(kind)){const text=cp.execFileSync(process.execPath,[__filename,"--untrusted-child",kind],{cwd:dir,env:cleanEnv(dir),encoding:"utf8",timeout:30000});assert.equal(JSON.parse(text.trim()).passed,true);}
  else{const result=bootstrap.launchComponentSuite31({suite:"bootstrap-regressions",caseId:kind,outputDirectory:dir,nodeExecutable:process.execPath,nodeSha256:sha(fs.readFileSync(process.execPath)),sourceFiles:bootstrap.sourceMap(__dirname)});assert.equal(result.status,0,fs.readFileSync(path.join(dir,"stderr.log"),"utf8"));}
 });
 test("fresh fixed child strips inherited preload options and module search path",()=>{
  const dir=path.join(scratch,"environment-positive");fs.mkdirSync(dir);const preload=path.join(dir,"preload.cjs"),marker=path.join(dir,"PRELOAD_EXECUTED");fs.writeFileSync(preload,'globalThis.__BOOTSTRAP_PRELOAD_MARKER__=true;require("node:fs").writeFileSync('+JSON.stringify(marker)+',"unexpected");\n',{flag:"wx"});
  const previous=Object.fromEntries(["NODE_OPTIONS","NODE_PATH"].map(key=>[key,{present:Object.hasOwn(process.env,key),value:process.env[key]}]));
  try{process.env.NODE_OPTIONS="--require "+JSON.stringify(preload);process.env.NODE_PATH=dir;const result=bootstrap.launchComponentSuite31({suite:"bootstrap-regressions",caseId:"environment-positive",outputDirectory:dir,nodeExecutable:process.execPath,nodeSha256:sha(fs.readFileSync(process.execPath)),sourceFiles:bootstrap.sourceMap(__dirname)});assert.equal(result.status,0,fs.readFileSync(path.join(dir,"stderr.log"),"utf8"));assert.equal(fs.existsSync(marker),false);assert.equal(JSON.parse(fs.readFileSync(path.join(dir,"stdout.log"),"utf8").trim()).inertValue,42);}
  finally{for(const [key,old]of Object.entries(previous)){if(old.present)process.env[key]=old.value;else delete process.env[key];}}
 });
 test("fresh fixed child loads real installed API and hash modules without execution",()=>{
  const materializer=require("./business31NpmBinMaterialization.cjs"),repo=path.resolve(__dirname,"../.."),source=path.join(repo,"tooling/firebase-cli/node_modules"),build=path.join(scratch,"installed-copy");
  fs.mkdirSync(build);for(const rel of ["node_modules","functions/node_modules","tooling/firebase-cli"])fs.mkdirSync(path.join(build,rel),{recursive:true});
  const before=materializer.scan31(source,true),destination=path.join(build,"tooling/firebase-cli/node_modules");fs.cpSync(source,destination,{recursive:true,dereference:false,verbatimSymlinks:true,errorOnExist:true,force:false});assert.deepEqual(materializer.scan31(destination,true),before);
  materializer.materializeNpmBins31({buildRoot:build});const bytes=Buffer.from(JSON.stringify(materializer.scan31(destination).files)),map=path.join(build,"cli-map.json");fs.writeFileSync(map,bytes,{flag:"wx"});
  const runtime={cliEntrypoint:path.join(destination,"firebase-tools/lib/bin/firebase.js"),cliFileBindings:{path:map,sha256:sha(bytes)}},dir=path.join(scratch,"installed-positive");fs.mkdirSync(dir);
  const result=bootstrap.launchComponentSuite31({suite:"bootstrap-regressions",caseId:"installed-positive",componentData:{runtime},outputDirectory:dir,nodeExecutable:process.execPath,nodeSha256:sha(fs.readFileSync(process.execPath)),sourceFiles:bootstrap.sourceMap(__dirname)});assert.equal(result.status,0,fs.readFileSync(path.join(dir,"stderr.log"),"utf8"));assert.deepEqual(materializer.scan31(source,true),before);
 });
}
async function runSynthetic(kind,root,tools) {
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const {pathToFileURL}=require("node:url");
if(kind==="cached-writer"||kind==="cached-hook"){const own=path.join(root,"own-tools");fs.mkdirSync(own);for(const name of fs.readdirSync(tools))fs.copyFileSync(path.join(tools,name),path.join(own,name));tools=own;}
const hash=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const cp=require("node:child_process");for(const n of ["exec","execSync","execFile","execFileSync","spawn","spawnSync","fork"])cp[n]=()=>{throw Error("CHILD_PROCESS_FORBIDDEN");};
const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),Module=require("node:module");
for(const api of [https,http])for(const n of ["request","get"])api[n]=()=>{throw Error("NETWORK_FORBIDDEN");};net.Socket.prototype.connect=tls.connect=()=>{throw Error("SOCKET_FORBIDDEN");};globalThis.fetch=()=>{throw Error("FETCH_FORBIDDEN");};
const slots=[[https,"request"],[https,"get"],[http,"request"],[http,"get"],[net.Socket.prototype,"connect"],[tls,"connect"],[Module,"_load"],[Module,"registerHooks"],[globalThis,"fetch"]],before=slots.map(([o,k])=>Object.getOwnPropertyDescriptor(o,k));
function put(file,value){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,value,{flag:"wx"});return file;}
const evidence=path.join(root,"evidence"),cliRoot=path.join(root,"node_modules"),lib=path.join(cliRoot,"firebase-tools/lib");fs.mkdirSync(evidence);
const producers={api:"apiv2.js",apply:"deploy/functions/cache/applyHash.js",prepare:"deploy/functions/prepare.js",backend:"deploy/functions/backend.js"};
put(path.join(lib,"bin/firebase.js"),'throw Error("ENTRY_MUST_NEVER_EXECUTE");\n');
put(path.join(cliRoot,"firebase-tools/package.json"),JSON.stringify({name:"firebase-tools",version:"synthetic-inert"}));
put(path.join(lib,"apiv2.js"),'require("./api-dependency.js"); exports.Client=class Client { request(){} };\n');
put(path.join(lib,"api-dependency.js"),'module.exports={synthetic:true};\n');
put(path.join(lib,"deploy/functions/cache/applyHash.js"),'require("./apply-dependency.js"); exports.applyBackendHashToBackends=function(){throw Error("HASH_MUST_NEVER_EXECUTE");};\n');
put(path.join(lib,"deploy/functions/cache/apply-dependency.js"),'module.exports={synthetic:true};\n');
put(path.join(lib,"deploy/functions/prepare.js"),'exports.prepare=function(){throw Error("PREPARE_FORBIDDEN");};\n');
put(path.join(lib,"deploy/functions/backend.js"),'module.exports={synthetic:true};\n');
put(path.join(lib,"late.js"),'exports.good=true;\n');
const files={};function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())walk(f);else files[path.relative(cliRoot,f).split(path.sep).join("/")]=hash(fs.readFileSync(f));}}walk(cliRoot);
const mapPath=put(path.join(evidence,"cli-map.json"),JSON.stringify(files)),mapBytes=fs.readFileSync(mapPath);
const runtime={cliEntrypoint:path.join(lib,"bin/firebase.js"),cliFileBindings:{path:mapPath,sha256:hash(mapBytes)},instrumentationProducerSha256:Object.fromEntries(Object.entries(producers).map(([k,f])=>[k,hash(fs.readFileSync(path.join(lib,f)))]))};
const source={commit:"a".repeat(40),tree:"b".repeat(40),functionsTree:"c".repeat(40)};
const cohorts={callables:Array.from({length:13},(_,i)=>"callable"+String(i).padStart(2,"0")),events:Array.from({length:5},(_,i)=>"event"+String(i).padStart(2,"0")),schedulers:["scheduler00"]};cohorts.fleet=[...cohorts.callables,...cohorts.events,...cohorts.schedulers].sort();
function retain(name,value){const raw=Buffer.from(JSON.stringify(value));put(path.join(evidence,name),raw);return {file:name,bytes:raw.length,sha256:hash(raw)};}
const proof=retain("runtime.json",{syntheticParserFixture:true}),intent=retain("intent.json",{schemaVersion:1,documentType:"firebase-cli-approved-intended-hash-inputs",codebase:"default",source,sourceBefore:source,sourceAfter:source,completedAtUtc:"2026-10-04T00:00:00Z"});
const contract=retain("contract.json",{schemaVersion:1,documentType:"build31-business-execution-contract",profile:"build31-exact-business-backend-v1",source,sourceManifestSha256:"A".repeat(64),runtimeProof:proof,preparedAtUtc:"2026-10-04T00:00:01Z",intendedHashInputs:intent});
const decision=retain("decision.json",{schemaVersion:2,documentType:"build31-business-backend-deployment-decision",profile:"build31-exact-business-backend-v1",source,sourceManifestSha256:"A".repeat(64),runtimeProof:proof,decidedAtUtc:"2026-10-04T00:00:02Z",executionWindow:{notBeforeUtc:"2026-10-04T00:00:03Z",notAfterUtc:"2026-10-04T01:00:03Z"},executionContract:contract});
const envelopeBytes=Buffer.from(JSON.stringify({schemaVersion:1,documentType:"build31-business-private-record-custody",recordKind:"decision",source,privateRecord:decision}));
const approvalPointer={commit:"d".repeat(40),file:"release/approvals/build31-business-backend-deployment-approval.json",sha256:hash(envelopeBytes)};
const admission={repoRoot:root,source,approvalPointer,cohorts,projectId:"crm3-baf-ops-b8638",region:"asia-south1",runtime};



const entry=path.join(lib,"apiv2.js"),applyFile=path.join(lib,"deploy/functions/cache/applyHash.js");
const options={evidenceDirectory:evidence,source,approvalPointer,cohorts,admission,envelopeBytes,archiveExpectedFiles:{},guardInputs:{},observeLive:()=>{throw Error("OBSERVER_FORBIDDEN");}};
const markerSource='globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; exports.Client=class Client{};\n';
function mapUpdate(){for(const n of Object.keys(files))delete files[n];walk(cliRoot);fs.writeFileSync(mapPath,JSON.stringify(files));runtime.cliFileBindings.sha256=hash(fs.readFileSync(mapPath));runtime.instrumentationProducerSha256.api=hash(fs.readFileSync(entry));}
const originalExtension=Module._extensions[".js"],originalCompile=Module.prototype._compile,savedRegister=Module.registerHooks;
let lease=null,session=null,foreignHook=null,error=null,cleanupError=null,observed=null;
function replaceExtension(){Module._extensions[".js"]=function(mod,file){if(file===entry)return mod._compile(markerSource,file);return originalExtension.apply(this,arguments);};}
function replaceCompile(){Module.prototype._compile=function(content,file){return originalCompile.call(this,file===entry?markerSource:content,file);};}
try {
 if(kind==="extension-before")replaceExtension();if(kind==="compile-before")replaceCompile();
 if(kind==="cached-writer"||kind==="cached-hook"){
  const name=kind==="cached-writer"?"captureBusiness31PreparedInputs.cjs":"captureBusiness31PreparedHook.cjs",file=path.join(tools,name),bytes=fs.readFileSync(file),prop=kind==="cached-writer"?"installCliLoadBoundary31":"installBusinessPreparedHook31";
  try{fs.writeFileSync(file,Buffer.concat([bytes,Buffer.from('\nmodule.exports.'+prop+'=function(){globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true;throw Error("INERT_PRELOADED_HELPER_EXECUTED");};\n')]));require(file);}finally{fs.writeFileSync(file,bytes);}
  assert.equal(hash(fs.readFileSync(file)),hash(bytes));session=new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options);
  if(kind==="cached-hook")session.hookModule.installBusinessPreparedHook31({writer:session.writer,phase:"callables",admission,envelopeBytes,archiveExpectedFiles:{},guardInputs:{}});
 }else{
  const install=require(path.join(tools,"captureBusiness31PreparedInputs.cjs")).installCliLoadBoundary31;
  if(kind.startsWith("package-")){
   const pkg=path.join(cliRoot,"probe-package"),field=kind==="package-main"?"main":"exports";
   put(path.join(pkg,"good.js"),'exports.value="GOOD";\n');put(path.join(pkg,"alternate.js"),'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true;exports.value="ALTERNATE";\n');put(path.join(pkg,"package.json"),JSON.stringify({name:"probe-package",[field]:"./good.js"}));fs.writeFileSync(entry,'exports.Client=class Client{};exports.probe=()=>require("probe-package");\n');mapUpdate();lease=install(runtime);
   fs.writeFileSync(path.join(pkg,"package.json"),JSON.stringify({name:"probe-package",[field]:"./alternate.js"}));observed=require(entry).probe().value;
  }else if(kind==="cached-client"||kind==="cached-apply"){
   lease=install(runtime);const file=kind==="cached-client"?entry:applyFile,value=require(file);lease.release();lease=null;
   if(kind==="cached-client")value.Client=class ForeignClient{constructor(){globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true;}};else value.applyBackendHashToBackends=function(){globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true;};
   lease=install(runtime);const retained=require(file);if(kind==="cached-client")new retained.Client();else retained.applyBackendHashToBackends();
  }else if(kind==="escaped-registrar"){
   // No caller code runs before the fixed bootstrap. The only registrar a suite
   // can retain before CLI admission is the already protected public capability.
   lease=install(runtime);const url=pathToFileURL(entry).href;foreignHook=savedRegister({load(found,context,nextLoad){const result=nextLoad(found,context);return found===url?{...result,source:markerSource}:result;}});require(entry);
  }else{
   lease=install(runtime);if(kind==="extension-after")replaceExtension();if(kind==="compile-after")replaceCompile();require(entry);
  }
 }
}catch(caught){error={name:caught.name,code:caught.code??null,message:caught.message};}
finally{Module._extensions[".js"]=originalExtension;Module.prototype._compile=originalCompile;try{if(foreignHook)foreignHook.deregister();if(session)session.dispose();if(lease)lease.release();}catch(caught){cleanupError={code:caught.code??null,message:caught.message};}}
const effect=globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__===true;
assert.equal(effect,false,"foreign marker must not run");assert(error,"the action must explicitly refuse");
if(SHARED.has(kind))assert.match(error.message,/capture requires the fixed fresh bootstrap|fresh fixed process entry required/);else assert.equal(error.code,"BUSINESS_CLI_LOAD_INTEGRITY");
if(cleanupError)assert.equal(cleanupError.code,"BUSINESS_CLI_LOAD_INTEGRITY");
writeObservation(root,{kind,passed:true,effectExecuted:effect,error,cleanupError,observed,entryScope:SHARED.has(kind)?"shared process refused before capture; not a guarded evaluation proof":"inside fixed fresh bootstrap",sourceOnlyComponent:true,operationalAuthority:false});
}
