"use strict";
// Isolated synthetic CommonJS boundary regressions. No installed CLI, network,
// credentials, package manager, Git fixture, or operational authority is used.
const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os"),cp=require("node:child_process");
const CASES=["early-api", "early-apply", "valid-session", "import-throws", "persistence-fails", "late-new", "late-cached", "unknown-cache", "replaced-exports", "nested", "foreign-owner", "escaped-require", "bad-map", "optional-missing", "cycle-positive", "evaluated-cjs-swap", "evaluated-json-swap", "json-positive", "native-refused", "esm-refused", "cached-esm-refused", "dynamic-esm-refused", "dynamic-cjs-refused", "optional-integrity-caught", "later-hook-registration", "returned-source-accessor", "returned-source-mutable-buffer", "accessor-export-positive", "accessor-export-replaced"];
if(process.argv[2]==="--child") {
  assert.equal(process.argv.length,5);
  runChild(process.argv[3],process.argv[4],__dirname).catch(error=>{console.error(error);process.exitCode=1;});
} else {
  const test=require("node:test");
  const scratch=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-cli-load-boundary-"));
  for(const kind of CASES)test("CLI load boundary: "+kind,()=>{
    const root=path.join(scratch,kind);fs.mkdirSync(root);
    const env=Object.fromEntries(Object.entries(process.env).filter(([name])=>["SYSTEMROOT","WINDIR"].includes(name.toUpperCase())));
    for(const name of ["HOME","USERPROFILE","APPDATA","LOCALAPPDATA","XDG_CONFIG_HOME","TEMP","TMP"]){const dir=path.join(root,name);fs.mkdirSync(dir);env[name]=dir;}
    env.CI="true";env.FIREBASE_CLI_DISABLE_UPDATE_CHECK="true";
    const output=cp.execFileSync(process.execPath,[__filename,"--child",kind,root],{cwd:root,env,encoding:"utf8",timeout:30000,maxBuffer:2*1024*1024});
    const result=JSON.parse(output);assert.equal(result.passed,true);assert.equal(result.inertUnboundMarkerExecuted,false);assert.equal(result.hookSlotsRestored,true);
  });
}
async function runChild(kind,root,tools) {
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const {pathToFileURL}=require("node:url");
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

const writer=require(path.join(tools,"captureBusiness31PreparedInputs.cjs")),install=writer.installCliLoadBoundary31;
assert.equal(typeof install,"function");
const entry=path.join(lib,"apiv2.js"),apiDependency=path.join(lib,"api-dependency.js"),applyDependency=path.join(lib,"deploy/functions/cache/apply-dependency.js"),late=path.join(lib,"late.js");
const options={evidenceDirectory:evidence,source,approvalPointer,cohorts,admission,envelopeBytes,archiveExpectedFiles:{},guardInputs:{},observeLive:()=>{throw Error("OBSERVER_FORBIDDEN");}};
function marker(file){fs.writeFileSync(file,'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; throw Error("INERT_UNBOUND_DEPENDENCY_EXECUTED");\n');}
function unchanged(){return slots.every(([o,k],i)=>require("node:util").isDeepStrictEqual(Object.getOwnPropertyDescriptor(o,k),before[i]));}
function mapUpdate(){for(const n of Object.keys(files))delete files[n];walk(cliRoot);fs.writeFileSync(mapPath,JSON.stringify(files));runtime.cliFileBindings.sha256=hash(fs.readFileSync(mapPath));runtime.instrumentationProducerSha256.api=hash(fs.readFileSync(entry));}
let lease=null,session=null,foreignPreserved=false;const outcomes=[];
if(kind==="early-api"||kind==="early-apply"){
 marker(kind==="early-api"?apiDependency:applyDependency);
 if(kind==="early-api")assert.throws(()=>new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options),/unbound or changed CLI|CLI.*population|CLI.*binding/i);
 else{const w=new writer.BusinessCapture31(options);assert.throws(()=>require(path.join(tools,"captureBusiness31PreparedHook.cjs")).installBusinessPreparedHook31({writer:w,phase:"callables",admission,envelopeBytes,archiveExpectedFiles:{},guardInputs:{}}),/unbound or changed CLI|CLI.*population|CLI.*binding/i);}
 assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.equal(require.cache[entry],undefined);assert.equal(unchanged(),true);outcomes.push("refused before first marker or CLI entry evaluation");
}else if(kind==="valid-session"){
 session=new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options);assert.equal(typeof session.api.Client,"function");assert.equal(require(late).good,true);session.dispose();assert.equal(unchanged(),true);outcomes.push("actual Session constructor, guarded late load and incomplete-session cleanup succeed without authority claim");
}else if(kind==="import-throws"){
 fs.writeFileSync(apiDependency,'throw Error("APPROVED_INERT_IMPORT_FAILURE");\n');mapUpdate();
 assert.throws(()=>new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options),/APPROVED_INERT_IMPORT_FAILURE/);assert.equal(unchanged(),true);outcomes.push("approved failing import preserves error and releases owned boundary");
}else if(kind==="persistence-fails"){
 const write=fs.writeFileSync;fs.writeFileSync=function(file,...args){if(String(file).endsWith("session-start.json"))throw Error("INJECTED_SESSION_START_WRITE_FAILURE");return write.call(this,file,...args);};
 try{assert.throws(()=>new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options),/INJECTED_SESSION_START_WRITE_FAILURE/);}finally{fs.writeFileSync=write;}
 assert.equal(unchanged(),true);outcomes.push("constructor persistence refusal releases loader before any shared capture hooks remain");
}else if(kind==="late-new"||kind==="late-cached"){
 lease=install(runtime);require(entry);if(kind==="late-cached")assert.equal(require(late).good,true);
 marker(late);assert.throws(()=>require(late),/unbound or changed CLI/);assert.throws(()=>lease.assertHealthy(),/CLI/);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);lease.release();assert.equal(unchanged(),true);outcomes.push("changed "+kind+" dependency refused before evaluation/cache return");
}else if(kind==="unknown-cache"){
 require(entry);const cached=require.cache[entry];assert.throws(()=>install(runtime),/unverified or replaced cached CLI/);assert.equal(require.cache[entry],cached);assert.equal(unchanged(),true);outcomes.push("matching but previously unguarded cache rejected without deletion");
}else if(kind==="replaced-exports"){
 lease=install(runtime);require(entry);lease.release();const cached=require.cache[entry],replacement={foreign:true};cached.exports=replacement;
 assert.throws(()=>install(runtime),/unverified or replaced cached CLI/);assert.equal(require.cache[entry],cached);assert.equal(cached.exports,replacement);assert.equal(unchanged(),true);outcomes.push("foreign exports identity preserved and rejected");
}else if(kind==="nested"){
 const first=install(runtime),owned=Object.getOwnPropertyDescriptor(Module,"_load"),second=install(runtime);assert.equal(require(entry).Client instanceof Function,true);
 assert.throws(()=>first.release(),/reverse order/);assert.deepEqual(Object.getOwnPropertyDescriptor(Module,"_load"),owned);second.release();assert.deepEqual(Object.getOwnPropertyDescriptor(Module,"_load"),owned);assert.throws(()=>second.release(),/once/);first.release();assert.equal(unchanged(),true);
 const reused=install(runtime);assert.equal(require(entry).Client instanceof Function,true);reused.release();assert.equal(unchanged(),true);outcomes.push("LIFO leases, rejected double release, prior guard-admitted cache and final exact restoration");
}else if(kind==="foreign-owner"){
 lease=install(runtime);const owned=Object.getOwnPropertyDescriptor(Module,"_load"),foreign=function(){throw Error("FOREIGN_LOADER_NOT_TO_BE_CALLED");};Object.defineProperty(Module,"_load",{...owned,value:foreign});
 assert.throws(()=>lease.release(),/ownership/);assert.equal(Module._load,foreign);foreignPreserved=true;
 // Other independently owned cleanup must finish even while this test's foreign
 // loader remains. Using the retained original loader here only verifies removal
 // of our source hook with an inert file; it is not an admission bypass API.
 const registrationIndex=slots.findIndex(([object,key])=>object===Module&&key==="registerHooks"),loadIndex=slots.findIndex(([object,key])=>object===Module&&key==="_load");
 assert.deepEqual(Object.getOwnPropertyDescriptor(Module,"registerHooks"),before[registrationIndex]);assert.throws(()=>lease.assertHealthy(),/CLI/);
 assert.equal(before[loadIndex].value.call(Module,late,module,false).good,true);assert.equal(Module._load,foreign);
 // Only this child-created foreign layer is removed by its owning test after refusal.
 Object.defineProperty(Module,"_load",owned);lease.release();assert.equal(unchanged(),true);outcomes.push("foreign loader preserved; own source hook and registrar removed independently; cleanup-only retry restores original loader");
}else if(kind==="escaped-require"){
 const outside=put(path.join(root,"outside.js"),'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; throw Error("INERT_OUTSIDE_DEPENDENCY");\n');
 fs.writeFileSync(entry,'require('+JSON.stringify(outside)+'); exports.Client=class Client{};\n');mapUpdate();lease=install(runtime);
 assert.throws(()=>require(entry),/escaped admitted population/);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);lease.release();assert.equal(unchanged(),true);outcomes.push("CLI parent cannot escape bound population");
}else if(kind==="bad-map"){
 fs.writeFileSync(mapPath,"{}");assert.throws(()=>new(require(path.join(tools,"business31CaptureSession.cjs")).BusinessCaptureSession31)(options),/CLI inventory bytes changed/);assert.equal(require.cache[entry],undefined);assert.equal(unchanged(),true);outcomes.push("altered map refused before CLI evaluation");
}else if(kind==="optional-missing"){
 put(path.join(lib,"optional.js"),'try{require("./intentionally-absent-optional.js");}catch(error){if(error.code!=="MODULE_NOT_FOUND")throw error;} exports.good=true;\n');mapUpdate();lease=install(runtime);assert.equal(require(path.join(lib,"optional.js")).good,true);assert.doesNotThrow(()=>lease.assertHealthy());lease.release();assert.equal(unchanged(),true);outcomes.push("ordinary missing optional dependency does not poison the healthy guard");
}else if(kind==="cycle-positive"){
 put(path.join(lib,"cycle-a.js"),'exports.name="a";exports.b=require("./cycle-b.js").name;\n');put(path.join(lib,"cycle-b.js"),'exports.name="b";exports.a=require("./cycle-a.js").name;\n');mapUpdate();lease=install(runtime);assert.deepEqual(require(path.join(lib,"cycle-a.js")),{name:"a",b:"b"});lease.release();assert.equal(unchanged(),true);outcomes.push("ordinary admitted CommonJS cycle completes without unknown-cache bypass");
 }else if(kind==="evaluated-cjs-swap"||kind==="evaluated-json-swap"){
 const json=kind==="evaluated-json-swap",file=json?put(path.join(lib,"evaluated.json"),'{"value":42}\n'):late;
 const original=fs.readFileSync(file),altered=Buffer.from(json?'{"value":99}\n':'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; exports.good=false;\n');mapUpdate();
 assert.equal(typeof Module.registerHooks,"function","synchronous evaluated-source hooks are required, not skipped");
 const url=pathToFileURL(file).href;let returnedSource=null;
 // The lower hook retains the altered bytes Node actually read, then restores disk
 // before the boundary receives them. A second disk hash cannot detect this case.
 const lower=Module.registerHooks({load(found,context,nextLoad){if(found!==url)return nextLoad(found,context);fs.writeFileSync(file,altered);try{const result=nextLoad(found,context);returnedSource=typeof result.source==="string"?Buffer.from(result.source):Buffer.from(result.source);return result;}finally{fs.writeFileSync(file,original);}}});
 try{lease=install(runtime);assert.throws(()=>require(file),/CLI.*(source|evaluat|bytes|binding|integrity)/i);assert.deepEqual(returnedSource,altered);assert.deepEqual(fs.readFileSync(file),original);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.throws(()=>lease.assertHealthy(),/CLI/);lease.release();lease=null;}finally{if(lease)lease.release();lower.deregister();}
 assert.equal(unchanged(),true);outcomes.push("actual returned "+(json?"JSON":"CommonJS")+" bytes refused with admitted disk bytes restored before validation");
}else if(kind==="json-positive"){
 const file=put(path.join(lib,"valid.json"),'{"value":42}\n');mapUpdate();lease=install(runtime);assert.deepEqual(require(file),{value:42});assert.deepEqual(require(file),{value:42});lease.assertHealthy();lease.release();assert.equal(unchanged(),true);outcomes.push("bound JSON evaluation and guarded cache reuse succeed");
}else if(kind==="native-refused"){
 const file=put(path.join(lib,"native.node"),'INERT_NOT_A_NATIVE_LIBRARY\n');mapUpdate();const prior=Object.getOwnPropertyDescriptor(process,"dlopen");let attempted=false;
 Object.defineProperty(process,"dlopen",{...prior,value:()=>{attempted=true;throw Error("INERT_NATIVE_LOADER_MUST_NOT_BE_CALLED");}});
 try{lease=install(runtime);assert.throws(()=>require(file),/CLI.*(format|native|unsupported|admitted)/i);assert.equal(attempted,false);assert.throws(()=>lease.assertHealthy(),/CLI/);lease.release();lease=null;}finally{if(lease)lease.release();Object.defineProperty(process,"dlopen",prior);}
 assert.equal(unchanged(),true);outcomes.push("bound native filename is refused before even an inert native-loader callback");
}else if(kind==="esm-refused"||kind==="cached-esm-refused"||kind==="dynamic-esm-refused"){
 const cached=kind==="cached-esm-refused",file=put(path.join(lib,"inert-module.mjs"),cached?'export const value=42;\n':'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; export const value=99;\n'),url=pathToFileURL(file).href;
 let parentFile=null;if(kind==="dynamic-esm-refused")parentFile=put(path.join(lib,"dynamic-parent.cjs"),'module.exports=()=>import('+JSON.stringify(url)+');\n');mapUpdate();
 if(cached)assert.equal((await import(url)).value,42);
 lease=install(runtime);const action=parentFile?require(parentFile):()=>import(url);
 await assert.rejects(action(),/CLI.*(format|ESM|module|dynamic|admitted|unsupported)/i);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.throws(()=>lease.assertHealthy(),/CLI/);lease.release();assert.equal(unchanged(),true);outcomes.push(cached?"pre-existing ESM namespace refused before cached return":parentFile?"admitted CommonJS cannot dynamically import ESM outside finite evaluator":"new ESM refused before marker evaluation");
}else if(kind==="dynamic-cjs-refused"){
 const file=put(path.join(lib,"dynamic-child.cjs"),'globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; exports.good=false;\n');
 const parentFile=put(path.join(lib,"dynamic-cjs-parent.cjs"),'module.exports=()=>import('+JSON.stringify(pathToFileURL(file).href)+');\n');mapUpdate();lease=install(runtime);const action=require(parentFile);
 await assert.rejects(action(),/CLI.*(format|import|dynamic|admitted|unsupported)/i);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.throws(()=>lease.assertHealthy(),/CLI/);lease.release();assert.equal(unchanged(),true);outcomes.push("dynamic CommonJS import is refused, only synchronous require provenance is supported");
} else if(kind==="optional-integrity-caught"){
 const file=put(path.join(lib,"optional-integrity.cjs"),'module.exports=()=>{try{return require("./late.js");}catch(error){return {caught:error.code};}};\n');mapUpdate();lease=install(runtime);const action=require(file);marker(late);assert.equal(action().caught,"BUSINESS_CLI_LOAD_INTEGRITY");assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.throws(()=>lease.assertHealthy(),/CLI/);
 const w=new writer.BusinessCapture31(options);w.bindExecutionWindow({notBeforeUtc:new Date(Date.now()-1000).toISOString(),notAfterUtc:new Date(Date.now()+60000).toISOString()});assert.throws(()=>w.assertExecutionWindow(),/CLI/);lease.release();assert.equal(unchanged(),true);outcomes.push("optional catch cannot turn an integrity refusal into a healthy capture boundary");
}else if(kind==="later-hook-registration"){
 const originalRegistration=Object.getOwnPropertyDescriptor(Module,"registerHooks");lease=install(runtime);let foreignCalls=0;
 assert.throws(()=>Module.registerHooks({load(url,context,nextLoad){foreignCalls++;return nextLoad(url,context);}}),/CLI.*(hook|registration|ownership|source)/i);assert.equal(foreignCalls,0);assert.throws(()=>lease.assertHealthy(),/CLI/);lease.release();assert.deepEqual(Object.getOwnPropertyDescriptor(Module,"registerHooks"),originalRegistration);assert.equal(unchanged(),true);outcomes.push("later source-hook registration refused and terminal; exact original registration descriptor restored");
}else if(kind==="returned-source-accessor"||kind==="returned-source-mutable-buffer"){
 const file=put(path.join(lib,"owned-source.cjs"),'exports.value=42;\n');mapUpdate();const original=fs.readFileSync(file),altered=Buffer.from('globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true; exports.value=99;\n'),url=pathToFileURL(file).href;
 let sourceReads=0,formatReads=0;const shared=Buffer.from(original),mutable=kind==="returned-source-mutable-buffer";
 const lower=Module.registerHooks({load(found,context,nextLoad){const loaded=nextLoad(found,context);if(found!==url)return loaded;
   return {...loaded,get source(){sourceReads++;return mutable?shared:sourceReads===1?original:altered;},get format(){formatReads++;if(mutable)shared.fill(0x21);return loaded.format;}};
 }});
 try{lease=install(runtime);if(!mutable){assert.deepEqual(require(file),{value:42});assert(sourceReads>0,"the native hook must exercise the source accessor");lease.assertHealthy();}else{
   // A hostile metadata accessor mutates the supplied Buffer. Either fail closed
   // before evaluation, or evaluate an already-owned admitted-byte snapshot.
   let result=null,refusal=null;try{result=require(file);}catch(error){refusal=error;}
   assert(formatReads>0);assert.equal(shared.includes(0x21),true);if(refusal){assert.equal(refusal.code,"BUSINESS_CLI_LOAD_INTEGRITY");assert.match(refusal.message,/CLI.*(source|bytes|binding|integrity)/i);assert.throws(()=>lease.assertHealthy(),/CLI/);}else{assert.deepEqual(result,{value:42});lease.assertHealthy();}
 }
 assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);assert.deepEqual(fs.readFileSync(file),original);lease.release();lease=null;}finally{if(lease)lease.release();lower.deregister();}
 assert.equal(unchanged(),true);outcomes.push(mutable?"mutable loader result cannot change admitted evaluated bytes after checking":"foreign source accessor cannot replace the admitted evaluated bytes");
}else if(kind==="accessor-export-positive"||kind==="accessor-export-replaced"){
 // ansi-styles 4.x legitimately exports a new object through an own getter on
 // every access. Verify the descriptor identity without invoking it again.
 const file=put(path.join(lib,"accessor-export.cjs"),'Object.defineProperty(module,"exports",{enumerable:true,configurable:true,get(){return {value:42};}});\n');mapUpdate();lease=install(runtime);
 const first=require(file),second=require(file),cached=require.cache[file],descriptor=Object.getOwnPropertyDescriptor(cached,"exports");assert.deepEqual(first,{value:42});assert.deepEqual(second,{value:42});assert.notEqual(first,second);assert.equal(typeof descriptor.get,"function");lease.assertHealthy();lease.release();
 if(kind==="accessor-export-positive"){
  lease=install(runtime);const third=require(file);assert.deepEqual(third,{value:42});assert.notEqual(third,second);assert.equal(require.cache[file],cached);assert.deepEqual(Object.getOwnPropertyDescriptor(cached,"exports"),descriptor);lease.assertHealthy();lease.release();outcomes.push("admitted stable accessor exports may return new objects through repeated require and later guarded cache reuse");
 }else{
  const foreign=()=>{globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__=true;return {value:99};};Object.defineProperty(cached,"exports",{...descriptor,get:foreign});
  assert.throws(()=>install(runtime),/unverified or replaced cached CLI|CLI.*export.*(changed|differ|identity)/i);assert.equal(require.cache[file],cached);assert.equal(Object.getOwnPropertyDescriptor(cached,"exports").get,foreign);assert.equal(globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__,undefined);outcomes.push("replaced accessor identity refused without executing or overwriting the foreign getter");
 }
 assert.equal(unchanged(),true);
}else throw Error("Unknown independent case");
const result={kind,passed:true,outcomes,foreignPreserved,hookSlotsRestored:unchanged(),inertUnboundMarkerExecuted:globalThis.__INERT_UNBOUND_DEPENDENCY_EXECUTED__===true,fullAuthorityValidated:false,realCliImported:false,networkOrInstallOrChildUsed:false};
fs.writeFileSync(path.join(root,"OBSERVATION.json"),JSON.stringify(result,null,2)+"\n");console.log(JSON.stringify(result));

}
