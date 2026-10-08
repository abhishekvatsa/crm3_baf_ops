"use strict";
// Credential-free, synthetic original controls and Git source fixture. The fixed
// fresh bootstrap, immutable nested controls loader, sourceOptions and installed
// TypeScript/SDK execute unchanged. The controller and intent worker drivers
// are synthetic: this exercises import composition, never deployment authority.
const fs=require("node:fs"),path=require("node:path"),os=require("node:os"),cp=require("node:child_process"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const sha=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const TS="typescript/lib/typescript.js",SDK="firebase-functions/lib/runtime/manifest.js",PREFIX="functions/node_modules/";
const modes=["controller","phase","missing-admission","missing-member","extra-member","bad-prefix","repeated","late","pre-cached","overlapping-cli","tamper-typescript","tamper-sdk","tamper-package","changed-cached","replaced-cache","escaped-dependency"];
function map(root){const files={};function walk(dir){for(const row of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){assert.equal(row.isSymbolicLink(),false);const file=path.join(dir,row.name);if(row.isDirectory())walk(file);else{assert.equal(row.isFile(),true);files[path.relative(root,file).split(path.sep).join("/")]=sha(fs.readFileSync(file));}}}walk(root);return files;}
function save(file,value){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,Buffer.isBuffer(value)?value:JSON.stringify(value)+"\n",{flag:"wx"});return file;}
function environment(root,git){const env={};for(const key of ["SystemRoot","WINDIR","COMSPEC","PATHEXT"])if(process.env[key]!==undefined)env[key]=process.env[key];for(const key of ["HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","TEMP","TMP"]){env[key]=path.join(root,key);fs.mkdirSync(env[key]);}Object.assign(env,{PATH:path.dirname(process.execPath)+path.delimiter+path.dirname(git),GIT_CONFIG_NOSYSTEM:"1",GIT_CONFIG_GLOBAL:process.platform==="win32"?"NUL":"/dev/null",GIT_TERMINAL_PROMPT:"0",CI:"true"});assert.equal(new Set(Object.keys(env).map(key=>key.toUpperCase())).size,Object.keys(env).length,"synthetic environment must have unique case-insensitive keys");return env;}
function gitPath(){const name=process.platform==="win32"?"git.exe":"git",choices=process.env.BUSINESS31_TEST_GIT?[process.env.BUSINESS31_TEST_GIT]:(process.env.PATH??"").split(path.delimiter).map(p=>path.join(p,name));const found=choices.find(p=>fs.existsSync(p)&&fs.statSync(p).isFile());assert.ok(found,"actual Git is required");return fs.realpathSync(found);}
function fixture(t){
 const root=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"b31-controls-boundary-")),repo=path.join(root,"repo"),release=path.join(repo,"tools/release"),data=path.join(root,"data"),git=gitPath();
 fs.mkdirSync(repo);fs.mkdirSync(data);const env=environment(root,git),upstream=path.resolve(__dirname,"../..");
 fs.cpSync(__dirname,release,{recursive:true,dereference:false,verbatimSymlinks:true,errorOnExist:true,force:false});
 fs.cpSync(path.join(upstream,"functions/src"),path.join(repo,"functions/src"),{recursive:true,dereference:false,errorOnExist:true,force:false});
 for(const name of ["functions/package.json","functions/package-lock.json","release/function-fleet-runtime-identity-policy.json"]){fs.mkdirSync(path.dirname(path.join(repo,name)),{recursive:true});fs.copyFileSync(path.join(upstream,name),path.join(repo,name),fs.constants.COPYFILE_EXCL);}
 fs.writeFileSync(path.join(release,"business31OperationalController.cjs"),'"use strict";const suite=require("./business31ControlRuntimeBoundary.test.cjs");module.exports={runController31:entry=>suite.dispatchCase(entry.configuration),runPhaseChild31:entry=>suite.dispatchCase(entry.configuration)};\n');
 fs.writeFileSync(path.join(release,"prepareBusinessIntent31.cjs"),'"use strict";module.exports={runIntentWorker31:entry=>require("./business31ControlRuntimeBoundary.test.cjs").runDestinationCase(JSON.parse(require("node:fs").readFileSync(entry.configurationFile)))};\n');
 save(path.join(release,"boundary-source-positive.cjs"),Buffer.from('module.exports={measured:true};\n'));
 const run=args=>cp.execFileSync(git,["--no-replace-objects","-C",repo,...args],{env,windowsHide:true,encoding:"utf8",timeout:30000,maxBuffer:4*1024*1024}).trim();
 run(["init","--quiet"]);run(["config","core.autocrlf","false"]);run(["config","user.name","Synthetic controls fixture"]);run(["config","user.email","synthetic@example.invalid"]);run(["add","--","."]);run(["-c","commit.gpgsign=false","commit","--quiet","-m","Synthetic source bytes for loader composition"]);const commit=run(["rev-parse","HEAD"]);
 const bins=require("./business31NpmBinMaterialization.cjs"),donor=path.join(upstream,"functions/node_modules"),original=bins.scan31(donor,true),installed=path.join(repo,"functions/node_modules");
 fs.cpSync(donor,installed,{recursive:true,dereference:false,verbatimSymlinks:true,errorOnExist:true,force:false});assert.deepEqual(bins.scan31(installed,true),original);
 for(const rel of ["node_modules","tooling/firebase-cli/node_modules"])fs.mkdirSync(path.join(repo,rel),{recursive:true});
 bins.materializeNpmBins31({buildRoot:repo});
 const forbidden=save(path.join(root,"outside.cjs"),Buffer.from('globalThis.__CONTROL_ESCAPE_EXECUTED__=true;module.exports={};\n'));
 save(path.join(installed,"boundary-probe.cjs"),Buffer.from('require('+JSON.stringify(forbidden)+');module.exports={};\n'));
 // An inert CLI entry also exists inside the Functions fixture solely to prove
 // that a later CLI population cannot overlap the admitted controls population.
 save(path.join(installed,"firebase-tools/lib/bin/firebase.js"),Buffer.from('module.exports={inert:true};\n'));
 addDestinationFixtures(installed);
 const functions=map(installed),installedControlRuntime=Object.fromEntries(Object.entries(functions).map(([name,digest])=>[PREFIX+name,digest]));
 const cliRoot=path.join(repo,"tooling/firebase-cli/node_modules"),cli=save(path.join(cliRoot,"firebase-tools/lib/bin/firebase.js"),Buffer.from('module.exports={inert:true};\n'));addDestinationFixtures(cliRoot);const cliFiles=map(cliRoot),cliMap=save(path.join(data,"cli-map.json"),cliFiles);
 const runtime={cliEntrypoint:cli,cliFileBindings:{path:cliMap,sha256:sha(fs.readFileSync(cliMap))}},producerNames=["scopedCallableInvokerIam.js","collectProductionGlobalPullBackend.js","reviewedBackendControls.js"],requiredProducerBindings=Object.fromEntries(producerNames.map(name=>["tools/release/"+name,sha(fs.readFileSync(path.join(release,name)))]));
 const policy=JSON.parse(fs.readFileSync(path.join(repo,"release/function-fleet-runtime-identity-policy.json"))),raw=require("./business31RawControlsFixture.cjs").makeRawControls({policy,sourceCommit:commit,approvalSha256:"A".repeat(64),startedAtUtc:"2026-10-01T00:00:00Z",completedAtUtc:"2026-10-01T00:00:01Z",endpointLabels:Object.fromEntries(Object.keys(policy.functionBindings).map(name=>[name,"1".repeat(40)]))});
 const before=save(path.join(data,"before.json"),raw.raw),beforeBytes=fs.readFileSync(before),beforePointer={file:"before.json",sha256:sha(beforeBytes)};
 const factsFile=save(path.join(data,"facts.json"),{repo,installed,commit,data,runtime,installedControlRuntime,requiredProducerBindings,beforePointer,forbidden,cliRoot,sourcePositive:path.join(release,"boundary-source-positive.cjs")});
 const helperFiles=map(release),node={path:fs.realpathSync(process.execPath),sha256:sha(fs.readFileSync(process.execPath))};
 t.diagnostic("Retained synthetic source/loader fixture: "+root);
 return {root,repo,release,data,env,functions,donor,original,bins,factsFile,helperFiles,node};
}
function blockNetwork(){for(const api of [require("node:http"),require("node:https")])for(const key of ["get","request"])api[key]=()=>{throw Error("NETWORK_FORBIDDEN");};require("node:net").Socket.prototype.connect=require("node:tls").connect=()=>{throw Error("SOCKET_FORBIDDEN");};globalThis.fetch=()=>{throw Error("FETCH_FORBIDDEN");};
 // The unchanged source reader needs only read-only local Git children.
 for(const key of ["spawnSync","execFileSync"]){const original=cp[key];cp[key]=function(file,args,options){assert.equal(path.basename(file).toLowerCase().replace(/\.exe$/,""),"git");assert.ok(args.includes("show")||args.includes("grep"),"only local source reads are permitted");return original.call(this,file,args,options);};}
 for(const key of ["spawn","exec","execSync","execFile","fork"])cp[key]=()=>{throw Error("CHILD_FORBIDDEN");};
}
function runCase(configuration){
 const f=JSON.parse(fs.readFileSync(configuration.fixture.factsFile)),mode=configuration.fixture.mode,bootstrap=require("./business31CaptureBootstrap.cjs"),Module=require("node:module");bootstrap.assertOperational31();blockNetwork();
 const controls=require("./backendRuntimeControls31.cjs"),ownedLoad=Module._load,bindings={...f.installedControlRuntime},ts=path.join(f.installed,TS),sdk=path.join(f.installed,SDK),probe=path.join(f.installed,"boundary-probe.cjs");
 let lease=null,error=null,cleanupError=null,result=null,restored=null,restoreFile=null;
 const options={repoRoot:f.repo,sourceCommit:f.commit,evidenceDirectory:f.data,beforePointer:f.beforePointer,requiredProducerBindings:f.requiredProducerBindings,installedControlRuntime:bindings};
 try {
  if(mode==="missing-member")delete bindings[PREFIX+"boundary-probe.cjs"];
  if(mode==="extra-member")bindings[PREFIX+"nonexistent.js"]="A".repeat(64);
  if(mode==="bad-prefix")bindings["other/node_modules/extra.js"]="A".repeat(64);
  if(mode==="pre-cached")require.cache[ts]={id:ts,filename:ts,loaded:true,exports:{untrusted:true}};
  if(mode==="late")lease=bootstrap.installCliLoadBoundary31(f.runtime);
  if(mode!=="missing-admission")bootstrap.admitInstalledControlsRuntime31(f.repo,bindings);
  if(mode==="repeated")bootstrap.admitInstalledControlsRuntime31(f.repo,bindings);
  if(mode==="overlapping-cli"){
   const file=path.join(f.data,"overlap-map.json");fs.writeFileSync(file,JSON.stringify(Object.fromEntries(Object.entries(bindings).map(([name,digest])=>[name.slice(PREFIX.length),digest]))),{flag:"wx"});
   bootstrap.installCliLoadBoundary31({cliEntrypoint:path.join(f.installed,"firebase-tools/lib/bin/firebase.js"),cliFileBindings:{path:file,sha256:sha(fs.readFileSync(file))}});
  }
  if(!lease)lease=bootstrap.installCliLoadBoundary31(f.runtime);
  assert.equal(require(f.runtime.cliEntrypoint).inert,true);
  if(mode.startsWith("tamper-")){
   restoreFile=mode==="tamper-typescript"?ts:mode==="tamper-sdk"?sdk:path.join(f.installed,"typescript/package.json");restored=fs.readFileSync(restoreFile);
   fs.appendFileSync(restoreFile,mode==="tamper-package"?"\n ":"\nglobalThis.__CONTROL_TAMPER_EXECUTED__=true;\n");
  }
  // This is the actual formerly failing call: context -> installed verification
  // -> immutable nested Module._load -> actual TS/SDK sourceOptions -> comparator.
  result=controls.verifyPreservedControlsBefore31(options);
  assert.equal(result.ok,true);assert.equal(result.sourceCommit,f.commit);assert.ok(require.cache[ts]);assert.ok(require.cache[sdk]);
  if(mode==="changed-cached"){restoreFile=sdk;restored=fs.readFileSync(sdk);fs.appendFileSync(sdk,"\nglobalThis.__CONTROL_TAMPER_EXECUTED__=true;\n");require(sdk);}
  else if(mode==="replaced-cache"){require.cache[sdk].exports={foreign:true};require(sdk);}
  else if(mode==="escaped-dependency")controls.withInstalledControlsRuntime31(f.repo,bindings,()=>require(probe));
  else assert.deepEqual(controls.verifyPreservedControlsBefore31(options),result,"verified cached TS/SDK remain usable during the same lease");
 }catch(e){error=e;}
 finally {
  assert.equal(Module._load,ownedLoad,"the immutable nested loader must restore its outer owner");
  if(restored)fs.writeFileSync(restoreFile,restored);
  try{if(lease&&!lease.isReleased())lease.release();}catch(e){cleanupError=e;}
 }
 assert.equal(globalThis.__CONTROL_ESCAPE_EXECUTED__,undefined);assert.equal(globalThis.__CONTROL_TAMPER_EXECUTED__,undefined);
 if(["controller","phase"].includes(mode)){
  if(error)throw error;if(cleanupError)throw cleanupError;assert.ok(lease.isReleased());
  assert.throws(()=>require(ts),/lifetime is terminal/);
 }else{
  assert.ok(error,"the selected negative must refuse");
  const expected={"missing-admission":/bound module dependency escaped population/,"missing-member":/population bytes differ/,"extra-member":/complete population differs/,"bad-prefix":/controls population prefix differs/,"repeated":/admitted once/,"late":/admitted once/,"pre-cached":/pre-existing controls module cache/,"overlapping-cli":/overlapping CLI population/,"tamper-typescript":/Installed controls byte drift/,"tamper-sdk":/Installed controls byte drift/,"tamper-package":/Installed controls byte drift/,"changed-cached":/unbound or changed module/,"replaced-cache":/unverified or replaced cached module/,"escaped-dependency":/Installed controls dependency escaped the measured runtime/};
  assert.match(error.message,expected[mode]);
  if(cleanupError)assert.equal(cleanupError.code,"BUSINESS_CLI_LOAD_INTEGRITY");
 }
 assert.throws(()=>bootstrap.admitInstalledControlsRuntime31(f.repo,bindings),/terminal|admitted once/);
 process.stdout.write(JSON.stringify({mode,passed:true,actualSourceOptionsReached:result?.ok===true,sourceCommit:f.commit,error:error?.message??null,cleanupError:cleanupError?.message??null,networkUsed:false,operationalAuthority:false})+"\n");
}
// These fixtures test destination admission with ordinary module APIs. The
// outside file is an inert marker and must never execute. The async import case
// reaches the synchronous resolve hook independently of CommonJS _load.
function addDestinationFixtures(root){
 save(path.join(root,"destination-probe.cjs"),Buffer.from('const {createRequire}=require("node:module");module.exports=(parent,target)=>createRequire(parent)(target);\n'));
 save(path.join(root,"destination-positive.json"),Buffer.from('{"measured":true}\n'));
 save(path.join(root,"destination-cycle-a.cjs"),Buffer.from('exports.started=true;exports.peer=require("./destination-cycle-b.cjs").ready;\n'));
 save(path.join(root,"destination-cycle-b.cjs"),Buffer.from('exports.ready=require("./destination-cycle-a.cjs").started;\n'));
}
async function runDestinationCase(configuration){
 const f=JSON.parse(fs.readFileSync(configuration.fixture.factsFile)),{mode,entry}=configuration.fixture;
 const bootstrap=require("./business31CaptureBootstrap.cjs"),Module=require("node:module"),{pathToFileURL}=require("node:url");
 if(entry==="intent")bootstrap.assertIntentWorker31("manifest");else bootstrap.assertOperational31();
 blockNetwork();
 const controls=require("./backendRuntimeControls31.cjs"),ownedLoad=Module._load;
 let lease=null,error=null,cleanupError=null;
 const negative=mode!=="rebased-positive",parent=path.join(path.dirname(f.forbidden),"synthetic-parent.cjs");
 try{
  if(entry!=="intent")bootstrap.admitInstalledControlsRuntime31(f.repo,f.installedControlRuntime);
  // Intent owns its outer lease; this is a real nested lease in that entry.
  lease=bootstrap.installCliLoadBoundary31(f.runtime);
  const functionsLoad=require(path.join(f.installed,"destination-probe.cjs")),cliLoad=require(path.join(f.cliRoot,"destination-probe.cjs"));
  if(mode==="rebased-functions")functionsLoad(parent,f.forbidden);
  else if(mode==="rebased-cli")cliLoad(pathToFileURL(parent),f.forbidden);
  else if(mode==="nested-rebased")controls.withInstalledControlsRuntime31(f.repo,f.installedControlRuntime,()=>functionsLoad(pathToFileURL(parent),f.forbidden));
  else if(mode==="hook-outside")await import(pathToFileURL(f.forbidden).href);
  else{
   assert.equal(mode,"rebased-positive");
   for(const [load,root] of [[functionsLoad,f.installed],[cliLoad,f.cliRoot]]){
    assert.deepEqual(load(parent,path.join(root,"destination-positive.json")),{measured:true});
    assert.equal(load(pathToFileURL(parent),path.join(root,"destination-cycle-a.cjs")).peer,true);
    assert.throws(()=>load(parent,path.join(root,"genuinely-absent-optional.cjs")),{code:"MODULE_NOT_FOUND"});
    assert.deepEqual(load(parent,f.sourcePositive),{measured:true});
   }
   const nested=bootstrap.installCliLoadBoundary31(f.runtime);
   try{assert.equal(controls.withInstalledControlsRuntime31(f.repo,f.installedControlRuntime,()=>functionsLoad(parent,path.join(f.installed,"destination-cycle-a.cjs"))).peer,true);nested.assertHealthy();}
   finally{nested.release();}
   lease.assertHealthy();
  }
 }catch(e){error=e;}
 finally{
  assert.equal(Module._load,ownedLoad,"nested loader restores the outer owner");
  assert.equal(globalThis.__CONTROL_ESCAPE_EXECUTED__,undefined,"unmeasured marker must never execute");
  if(negative&&error){assert.equal(error.code,"BUSINESS_CLI_LOAD_INTEGRITY");assert.match(error.message,/bound module dependency escaped population/);assert.throws(()=>lease.assertHealthy(),/terminal-failed/);}
  try{if(lease&&!lease.isReleased())lease.release();}catch(e){cleanupError=e;}
 }
 if(negative){assert.ok(error,"unmeasured destination must be refused");if(cleanupError)assert.equal(cleanupError.code,"BUSINESS_CLI_LOAD_INTEGRITY");}
 else{if(error)throw error;if(cleanupError)throw cleanupError;assert.ok(lease.isReleased());}
 process.stdout.write(JSON.stringify({mode,entry,passed:true,outsideMarker:false,synchronousResolveHook:mode==="hook-outside",networkUsed:false,operationalAuthority:false})+"\n");
 // The actual entry must also terminate unsuccessfully after an integrity
 // refusal; catching it inside measured code must not certify a healthy run.
 if(error)throw error;
}

module.exports={runCase,runDestinationCase,dispatchCase:configuration=>configuration.fixture.destination?runDestinationCase(configuration):runCase(configuration)};
if(!["--business-controller","--config","--intent-worker"].includes(process.argv[2])){
 const test=require("node:test");
 test("real Functions controls imports compose with the fresh outer boundary",{timeout:900000},async t=>{
  const f=fixture(t);
  for(const mode of modes)await t.test(mode,()=>{
   const dir=path.join(f.root,"cases",mode);fs.mkdirSync(dir,{recursive:true});
   const configuration={schemaVersion:1,documentType:"build31-business-protected-selection",fixture:{factsFile:f.factsFile,mode},execution:{sourceRoot:f.release,helperFiles:f.helperFiles,nodeExecutable:f.node,environment:f.env}};
   const config=save(path.join(dir,"configuration.json"),configuration);let argv=["--no-global-search-paths",path.join(f.release,"business31CaptureBootstrap.cjs"),"--business-controller",config,sha(fs.readFileSync(config))],env=f.env;
   if(mode==="phase"){
    const context=save(path.join(dir,"context.json"),{evidenceDirectory:dir,configuration:{file:"configuration.json",sha256:sha(fs.readFileSync(config))}});
    env={...f.env,BUSINESS31_PHASE_CONTEXT_SHA256:sha(fs.readFileSync(context))};argv=["--no-global-search-paths",path.join(f.release,"captureBusiness31PreparedInputs.cjs"),"--config",context];
   }
   save(path.join(dir,"REQUEST.json"),{argv,cwd:f.repo,environment:env,nodeSha256:f.node.sha256,configurationSha256:sha(fs.readFileSync(config))});
   const r=cp.spawnSync(process.execPath,argv,{cwd:f.repo,env,windowsHide:true,timeout:120000,maxBuffer:4*1024*1024,encoding:"utf8"});
   save(path.join(dir,"stdout.txt"),Buffer.from(r.stdout??""));save(path.join(dir,"stderr.txt"),Buffer.from(r.stderr??""));save(path.join(dir,"RESULT.json"),{status:r.status,signal:r.signal,error:r.error?.code??null});
   assert.equal(r.error,undefined);assert.equal(r.signal,null);assert.equal(r.status,0,r.stderr);const observed=JSON.parse(r.stdout.trim());assert.equal(observed.passed,true);assert.equal(observed.mode,mode);
   assert.deepEqual(map(path.join(f.repo,"functions/node_modules")),f.functions,"private fixture mutation must be restored after every child");assert.deepEqual(map(f.release),f.helperFiles);
  });
  const facts=JSON.parse(fs.readFileSync(f.factsFile));
  const intentFiles=save(path.join(f.data,"intent-functions.json"),map(path.join(f.repo,"functions"))),emitted=save(path.join(f.data,"intent-emitted.json"),{});
  for(const entry of ["controller","phase","intent"])for(const mode of ["rebased-functions","rebased-cli","nested-rebased","hook-outside","rebased-positive"])await t.test(entry+" destination: "+mode,()=>{
   const dir=path.join(f.root,"destinations",entry,mode);fs.mkdirSync(dir,{recursive:true});
   const configuration={schemaVersion:1,documentType:"build31-business-protected-selection",fixture:{factsFile:f.factsFile,mode,entry,destination:true},execution:{sourceRoot:f.release,helperFiles:f.helperFiles,nodeExecutable:f.node,environment:f.env}};
   const config=save(path.join(dir,"configuration.json"),configuration);let argv=["--no-global-search-paths",path.join(f.release,"business31CaptureBootstrap.cjs"),"--business-controller",config,sha(fs.readFileSync(config))],env=f.env;
   if(entry==="phase"){
    const context=save(path.join(dir,"context.json"),{evidenceDirectory:dir,configuration:{file:"configuration.json",sha256:sha(fs.readFileSync(config))}});
    env={...f.env,BUSINESS31_PHASE_CONTEXT_SHA256:sha(fs.readFileSync(context))};argv=["--no-global-search-paths",path.join(f.release,"captureBusiness31PreparedInputs.cjs"),"--config",context];
   }else if(entry==="intent"){
    const request=save(path.join(dir,"intent-request.json"),{schemaVersion:1,operation:"manifest",sourceRoot:f.release,sourceFiles:f.helperFiles,nodeExecutable:f.node,runtime:facts.runtime,functionsRoot:path.join(f.repo,"functions"),functionsFiles:{path:intentFiles,sha256:sha(fs.readFileSync(intentFiles))},emittedFiles:{path:emitted,sha256:sha(fs.readFileSync(emitted))},configuration:{path:config,sha256:sha(fs.readFileSync(config))}});
    argv=["--no-global-search-paths",path.join(f.release,"business31CaptureBootstrap.cjs"),"--intent-worker",request,sha(fs.readFileSync(request))];
   }
   save(path.join(dir,"REQUEST.json"),{argv,cwd:f.repo,environment:env,nodeSha256:f.node.sha256,configurationSha256:sha(fs.readFileSync(config))});
   const r=cp.spawnSync(process.execPath,argv,{cwd:f.repo,env,windowsHide:true,timeout:120000,maxBuffer:4*1024*1024,encoding:"utf8"});
   save(path.join(dir,"stdout.txt"),Buffer.from(r.stdout??""));save(path.join(dir,"stderr.txt"),Buffer.from(r.stderr??""));save(path.join(dir,"RESULT.json"),{status:r.status,signal:r.signal,error:r.error?.code??null});
   assert.equal(r.error,undefined);assert.equal(r.signal,null);assert.equal(r.status,mode==="rebased-positive"?0:1,r.stderr);
   const observed=JSON.parse(r.stdout.trim());assert.equal(observed.passed,true);assert.equal(observed.mode,mode);assert.equal(observed.entry,entry);assert.equal(observed.outsideMarker,false);
   if(mode!=="rebased-positive")assert.match(r.stderr,/bound module dependency escaped population|boundary is terminal-failed/);
   assert.deepEqual(map(path.join(f.repo,"functions/node_modules")),f.functions);assert.deepEqual(map(f.release),f.helperFiles);
  });

  assert.deepEqual(f.bins.scan31(f.donor,true),f.original,"original installed donor remains unchanged");
 });
}
