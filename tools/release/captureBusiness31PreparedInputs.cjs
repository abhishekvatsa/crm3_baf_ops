"use strict";
// PRIVATE PROPOSAL: records observations; no authority verifier, CLI entry or credential loader.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const {AsyncLocalStorage} = require("node:async_hooks");
const {isDeepStrictEqual: same, TextDecoder} = require("node:util");
const zlib = require("node:zlib");
const neutral = require("./runtimeDeploymentTransportGuard31.cjs");
const prepared = require("./captureBackendRuntimePreparedInputs31.cjs");
const business = require("./business31BackendAuthority.cjs");
const executionWindows = new WeakMap();
const PHASES = Object.freeze(["callables", "events", "fleet"]);
const LIMITS = Object.freeze({wire:64*1024*1024, response:16*1024*1024, json:8*1024*1024});
const digest = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const need = (ok, message) => { if (!ok) throw Error("Business capture: " + message); };
const clone = value => structuredClone(value);
const mutations = kind => ["generate-upload", "source-upload", "function-update"].includes(kind);
const exactTime = value => { need(typeof value==="string" && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value) && new Date(value).toISOString()===value,"invalid observation time"); return value; };
function noLinks(directory) {
  const resolved=path.resolve(directory); let current=path.parse(resolved).root;
  for (const part of resolved.slice(current.length).split(path.sep).filter(Boolean)) {
    current=path.join(current,part); const st=fs.lstatSync(current);
    need(st.isDirectory()&&!st.isSymbolicLink(),"evidence parent is not a regular directory");
  }
  return resolved;
}
// CommonJS source boundary only: it does not authenticate its caller or sandbox a process.
const cliEvaluations = new Map();
let activeCliBoundary = null;
function installCliLoadBoundary31(runtime) {
  let boundary=null;
  const check=(ok,message)=>{if(!ok){const owner=boundary??activeCliBoundary;if(owner)owner.failed=true;const error=Error("Business capture CLI load: "+message);error.code="BUSINESS_CLI_LOAD_INTEGRITY";throw error;}};
  const checkedRead=action=>{try{return action();}catch(error){const owner=boundary??activeCliBoundary;if(owner)owner.failed=true;throw error;}};
  const Module=require("node:module"),pointer=runtime?.cliFileBindings;
  check(typeof runtime?.cliEntrypoint==="string"&&path.isAbsolute(runtime.cliEntrypoint)&&pointer&&
    same(Object.keys(pointer).sort(),["path","sha256"])&&typeof pointer.path==="string"&&path.isAbsolute(pointer.path)&&
    typeof pointer.sha256==="string"&&/^[A-Fa-f0-9]{64}$/.test(pointer.sha256),"complete CLI file binding required before import");
  const root=noLinks(path.dirname(path.dirname(path.dirname(path.dirname(runtime.cliEntrypoint)))));
  noLinks(path.dirname(pointer.path));const mapStat=fs.lstatSync(pointer.path);
  check(mapStat.isFile()&&!mapStat.isSymbolicLink()&&mapStat.size<=LIMITS.json,"regular bounded CLI inventory required");
  const raw=fs.readFileSync(pointer.path);check(digest(raw)===pointer.sha256.toUpperCase(),"CLI inventory bytes changed");
  const bindings=JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(raw));
  check(bindings&&typeof bindings==="object"&&!Array.isArray(bindings),"CLI inventory object required");
  const names=Object.keys(bindings),identity=digest(raw);
  check(names.length>0&&names.length<=50000,"bounded complete CLI population required");
  for(const name of names)check(name.length<=400&&!/[\\\0\r\n]/.test(name)&&name.split("/").every(v=>v&&v!=="."&&v!=="..")&&
    typeof bindings[name]==="string"&&/^[A-Fa-f0-9]{64}$/.test(bindings[name]),"invalid CLI inventory member");
  const inside=file=>{const rel=path.relative(root,path.resolve(file));return rel!==""&&!rel.startsWith(".."+path.sep)&&rel!==".."&&!path.isAbsolute(rel);};
  const key=file=>path.relative(root,file).split(path.sep).join("/");
  function verifyFile(file){
    check(inside(file),"CLI dependency escaped admitted population");noLinks(path.dirname(file));
    const stat=fs.lstatSync(file);check(stat.isFile()&&!stat.isSymbolicLink(),"CLI module is not a regular admitted file");
    const real=fs.realpathSync(file),name=key(real);
    check(inside(real)&&Object.hasOwn(bindings,name)&&digest(fs.readFileSync(real))===bindings[name].toUpperCase(),"unbound or changed CLI module before evaluation");
    return real;
  }
  const found=[];let directories=0;
  function census(dir){check(++directories<=100000,"CLI directory census bound exceeded");for(const row of fs.readdirSync(dir,{withFileTypes:true})){
    const file=path.join(dir,row.name),stat=fs.lstatSync(file);check(!stat.isSymbolicLink(),"CLI inventory redirects are refused");
    if(stat.isDirectory())census(file);else{check(stat.isFile()&&found.length<50000,"CLI inventory member or count differs");found.push(key(verifyFile(file)));}
  }}
  checkedRead(()=>census(root));check(same(found.sort(),[...names].sort()),"complete CLI file population differs");
  verifyFile(runtime.cliEntrypoint);
  function sameExportsDescriptor(a,b){
    return !!a&&!!b&&a.enumerable===b.enumerable&&a.configurable===b.configurable&&
      Object.hasOwn(a,"value")===Object.hasOwn(b,"value")&&
      (Object.hasOwn(a,"value")?a.value===b.value&&a.writable===b.writable:a.get===b.get&&a.set===b.set);
  }
  function verifyCached(file,cached){const known=cliEvaluations.get(file);
    check(known&&known.module===cached&&sameExportsDescriptor(known.exportsDescriptor,Object.getOwnPropertyDescriptor(cached,"exports"))&&known.identity===identity&&known.root===root&&cached.loaded===true,
      "unverified or replaced cached CLI module refused");
  }
  for(const [file,cached]of Object.entries(Module._cache))if(inside(file)){verifyFile(file);verifyCached(file,cached);}
  if(activeCliBoundary){
    check(activeCliBoundary.root===root&&activeCliBoundary.identity===identity,"different CLI population already guarded");
    activeCliBoundary.assertOwned();activeCliBoundary.assertHealthy();return activeCliBoundary.lease();
  }
  const original=Object.getOwnPropertyDescriptor(Module,"_load"),resolver=Object.getOwnPropertyDescriptor(Module,"_resolveFilename"),cache=Module._cache;
  check(original&&Object.hasOwn(original,"value")&&typeof original.value==="function"&&original.writable&&original.configurable&&
    resolver&&Object.hasOwn(resolver,"value")&&typeof resolver.value==="function","ordinary Node module loader required");
  const loading=new Map(),leases=[];
  const loader=function(request,parent,isMain){
    check(Module._cache===cache&&same(Object.getOwnPropertyDescriptor(Module,"_resolveFilename"),resolver),"CLI resolver or cache container changed");
    const resolved=resolver.value.call(Module,request,parent,isMain),fromCli=typeof parent?.filename==="string"&&inside(parent.filename);
    if(Module.isBuiltin(resolved))return original.value.apply(this,arguments);
    const controlled=typeof resolved==="string"&&path.isAbsolute(resolved)&&(inside(resolved)||fromCli);
    check(!fromCli||controlled,"CLI dependency resolution is not admitted");
    if(!controlled)return original.value.apply(this,arguments);
    boundary.assertHealthy();const real=checkedRead(()=>verifyFile(resolved)),cached=cache[resolved];
    if(cached){
      const pending=loading.get(resolved);
      if(pending){check(pending.module===null||pending.module===cached,"in-progress CLI cache identity changed");pending.module=cached;}
      else verifyCached(real,cached);
    }
    const outer=!loading.has(resolved),frame=outer?{module:cached??null}:loading.get(resolved);
    if(outer)loading.set(resolved,frame);
    try{
      const exports=original.value.apply(this,arguments),actual=cache[resolved];
      const exportsDescriptor=actual&&Object.getOwnPropertyDescriptor(actual,"exports");
      // A source-defined accessor may return a fresh object; validate its identity without invoking it again.
      check(actual&&(!frame.module||actual===frame.module)&&exportsDescriptor&&
        (Object.hasOwn(exportsDescriptor,"value")?exportsDescriptor.value===exports:typeof exportsDescriptor.get==="function"),"CLI module cache identity differs after load");
      if(outer){check(actual.loaded===true,"CLI module did not finish evaluation");verifyFile(real);if(cached)verifyCached(real,actual);cliEvaluations.set(real,{root,identity,module:actual,exportsDescriptor});}
      return exports;
    }finally{if(outer)loading.delete(resolved);}
  };
  const {fileURLToPath,pathToFileURL}=require("node:url");
  const registration=Object.getOwnPropertyDescriptor(Module,"registerHooks");
  check(registration&&Object.hasOwn(registration,"value")&&typeof registration.value==="function"&&registration.writable&&registration.configurable,"synchronous Node source hooks required");
  const ownedRegistration={...registration,value:function(){check(false,"later CLI source-hook registration refused");}};
  function urlPath(url){
    if(typeof url!=="string"||!url.startsWith("file:"))return null;
    try{return fileURLToPath(url);}catch{return null;}
  }
  function controlledUrl(url,parentURL){
    const file=urlPath(url),parent=urlPath(parentURL),fromCli=parent!==null&&inside(parent);
    if(typeof url==="string"&&Module.isBuiltin(url))return null;
    if(!(file!==null&&inside(file))&&!fromCli)return null;
    check(file!==null&&inside(file)&&pathToFileURL(file).href===url,"CLI module URL escaped admitted regular population");
    boundary.assertHealthy();return checkedRead(()=>verifyFile(file));
  }
  const sourceHook=registration.value.call(Module,{
    resolve(specifier,context,nextResolve){
      const result=nextResolve(specifier,context),file=controlledUrl(result.url,context.parentURL);
      if(file){
        check(!new Set(context.conditions??[]).has("import")&&result.format!=="module"&&!/\.(?:mjs|node|ts|mts|cts)$/i.test(file),"unsupported CLI module format or import mode");
        const cached=Module._cache[file],pending=loading.get(file);
        if(cached){if(pending){check(pending.module===null||pending.module===cached,"in-progress CLI cache identity changed");pending.module=cached;}else verifyCached(file,cached);}
      }
      return result;
    },
    load(url,context,nextLoad){
      const file=controlledUrl(url);
      if(!file)return nextLoad(url,context);
      check(context.format!=="module"&&!/\.(?:mjs|node|ts|mts|cts)$/i.test(file),"unsupported CLI module format");
      const result=nextLoad(url,context);
      const suppliedFormat=result.format,rawSource=result.source;
      const format=suppliedFormat==null&&file.endsWith(".js")&&loading.has(file)?"commonjs":suppliedFormat;
      check(["commonjs","json"].includes(format),"unsupported CLI evaluated format");
      const source=typeof rawSource==="string"?Buffer.from(rawSource,"utf8"):
        ArrayBuffer.isView(rawSource)?Buffer.from(new Uint8Array(rawSource.buffer,rawSource.byteOffset,rawSource.byteLength)):
        rawSource instanceof ArrayBuffer?Buffer.from(new Uint8Array(rawSource)):null;
      check(source!==null&&digest(source)===bindings[key(file)].toUpperCase(),"actual CLI evaluation source differs");
      // Return the exact owned snapshot we checked, never a foreign getter/buffer.
      return {format,source};
    }
  });
  const owned={...original,value:loader},cleanup={hookRemoved:false,registrarRestored:false,loaderRestored:false};
  boundary={root,identity,failed:false,assertHealthy(){check(!boundary.failed,"CLI load boundary is terminal-failed");check(same(Object.getOwnPropertyDescriptor(Module,"registerHooks"),ownedRegistration),"CLI source-hook registration ownership changed");},assertOwned(){check(same(Object.getOwnPropertyDescriptor(Module,"_load"),owned)&&same(Object.getOwnPropertyDescriptor(Module,"registerHooks"),ownedRegistration),"CLI loader ownership changed");},lease(){
    const token=Symbol("CLI load lease");leases.push(token);let released=false;
    return Object.freeze({release(){
      check(!released&&leases.at(-1)===token,"CLI loader leases must release once in reverse order");
      if(leases.length>1){try{boundary.assertOwned();}finally{leases.pop();released=true;}return;}
      const errors=[];
      // Each resource is independently ours to remove; a foreign loader is preserved.
      if(!cleanup.hookRemoved){try{sourceHook.deregister();cleanup.hookRemoved=true;}catch(error){errors.push(error);}}
      for(const [name,ownedDescriptor,savedDescriptor,flag]of [["registerHooks",ownedRegistration,registration,"registrarRestored"],["_load",owned,original,"loaderRestored"]]){
        const current=Object.getOwnPropertyDescriptor(Module,name);
        if(cleanup[flag]&&same(current,savedDescriptor))continue;
        if(!same(current,ownedDescriptor)){errors.push(Error("CLI loader ownership changed during cleanup"));continue;}
        try{Object.defineProperty(Module,name,savedDescriptor);cleanup[flag]=true;}catch(error){errors.push(error);}
      }
      if(errors.length){boundary.failed=true;throw new AggregateError(errors,"CLI loader ownership cleanup incomplete");}
      activeCliBoundary=null;leases.pop();released=true;
    },isReleased(){return released;},assertOwned(){check(!released&&leases.includes(token),"CLI loader lease is released");boundary.assertOwned();},assertHealthy(){check(!released&&leases.includes(token),"CLI loader lease is released");boundary.assertHealthy();}});
  }};
  try{Object.defineProperty(Module,"registerHooks",ownedRegistration);Object.defineProperty(Module,"_load",owned);activeCliBoundary=boundary;}catch(error){if(same(Object.getOwnPropertyDescriptor(Module,"registerHooks"),ownedRegistration))Object.defineProperty(Module,"registerHooks",registration);sourceHook.deregister();throw error;}
  return boundary.lease();
}
function projectRequest(client, request) {
  const q=request.queryParams;
  if(q instanceof URLSearchParams) need(new Set(q.keys()).size===[...q.keys()].length,"duplicate query keys are not representable");
  const query=q==null?null:q instanceof URLSearchParams?Object.fromEntries(q):clone(q);
  need(query===null || Object.values(query).every(v=>typeof v==="string"),"query values must be exact strings");
  need(query===null || !Object.keys(query).some(k=>/^(access_token|refresh_token|id_token|client_secret|authorization)$/i.test(k)),"credential query cannot be captured");
  // Only these two client fields and four request fields are serialized. Auth/options/headers never are.
  const body=request.body==null?null:request.body && typeof request.body.path==="string"?{path:request.body.path}:clone(request.body);
  const result={client:{urlPrefix:client.opts.urlPrefix,apiVersion:client.opts.apiVersion??""},
    request:{method:(request.method??"GET").toUpperCase(),path:request.path,queryParams:query,body}};
  need(Buffer.byteLength(JSON.stringify(result))<=LIMITS.json,"request JSON bound exceeded");
  return result;
}
function decodeResponse(bytes, encoding) {
  let decoded=bytes;
  if(encoding==="gzip") decoded=zlib.gunzipSync(bytes,{maxOutputLength:LIMITS.response});
  else if(encoding==="deflate") decoded=zlib.inflateSync(bytes,{maxOutputLength:LIMITS.response});
  else if(encoding==="br") decoded=zlib.brotliDecompressSync(bytes,{maxOutputLength:LIMITS.response});
  else need(!encoding||encoding==="identity","unsupported response encoding");
  need(decoded.length<=LIMITS.response,"decoded response bound exceeded");
  return new TextDecoder("utf-8",{fatal:true}).decode(decoded);
}
class BusinessCapture31 {
  constructor({evidenceDirectory, approvalPointer, source, cohorts, now=()=>new Date().toISOString()}) {
    need(path.isAbsolute(evidenceDirectory),"absolute evidence directory required");
    need(source&&same(Object.keys(source).sort(),["commit","functionsTree","tree"])&&Object.values(source).every(v=>typeof v==="string"&&/^[a-f0-9]{40}$/.test(v)),"exact source point required");
    need(approvalPointer&&same(Object.keys(approvalPointer).sort(),["commit","file","sha256"])&&/^[a-f0-9]{40}$/.test(approvalPointer.commit)&&approvalPointer.file==="release/approvals/build31-business-backend-deployment-approval.json","exact custody pointer required");
    this.root=noLinks(evidenceDirectory); this.approval=clone(approvalPointer); this.source=clone(source); this.now=now;
    need(/^[a-f0-9]{64}$/i.test(this.approval.sha256),"decision digest required");
    need(cohorts.callables?.length===13&&cohorts.events?.length===5&&cohorts.schedulers?.length===1&&cohorts.fleet?.length===19,"exact 13/5/1 cohorts required");
    need(same([...cohorts.callables,...cohorts.events,...cohorts.schedulers].sort(),cohorts.fleet)&&new Set(cohorts.fleet).size===19,"exact disjoint cohort union required");
    this.cohorts=clone(cohorts); this.completed=[]; this.active=null; this.failed=false; this.allBindings=[];
    this.base=path.join(this.root,"deployment-attempts",this.approval.sha256);
    const attempts=path.join(this.root,"deployment-attempts");
    if(!fs.existsSync(attempts)) fs.mkdirSync(attempts,{mode:0o700});
    noLinks(attempts); fs.mkdirSync(this.base,{mode:0o700}); // Existing attempt is never reused.
  }
  bindExecutionWindow(window) {
    need(window&&same(Object.keys(window).sort(),["notAfterUtc","notBeforeUtc"]),"exact decision execution window required");
    const start=business.instant(window.notBeforeUtc),end=business.instant(window.notAfterUtc);
    need(start<end&&end-start<=6n*3600n*1000000000n,"decision execution window duration differs");
    const previous=executionWindows.get(this);
    need(!previous||same(previous.window,window),"decision execution window cannot be rebound");
    if(!previous){need(!this.active&&this.completed.length===0&&!this.failed,"execution window must bind before preparation");executionWindows.set(this,{window:Object.freeze(clone(window)),start,end});}
  }
  assertExecutionWindow() {
    try {
      if(activeCliBoundary)activeCliBoundary.assertHealthy();
      const bound=executionWindows.get(this);need(bound,"bound decision execution window required");
      // The record clock is caller-supplied test/measurement data, never the live guard.
      // Sample after all work at each forwarding boundary; no callback or evidence IO follows here.
      const sampledAtUtc=new Date().toISOString(),current=business.instant(sampledAtUtc);
      need(bound.start<=current&&current<=bound.end,"outside bound decision execution window");
      return sampledAtUtc;
    } catch(error) {this.failed=true;if(this.active)this.active.failed=true;throw error;}
  }
  put(name, bytes) {
    need(this.active&&/^[a-z0-9.-]+$/.test(name),"fixed active capture path required");
    const raw=Buffer.isBuffer(bytes)?bytes:Buffer.from(JSON.stringify(bytes,null,2)+"\n");
    need(raw.length<=Math.max(LIMITS.wire,LIMITS.response,LIMITS.json),"capture file bound exceeded");
    noLinks(this.active.directory);const file=path.join(this.active.directory,name);
    fs.writeFileSync(file,raw,{flag:"wx",mode:0o600});
    const after=fs.lstatSync(file);need(after.isFile()&&!after.isSymbolicLink()&&after.size===raw.length&&digest(fs.readFileSync(file))===digest(raw),"capture readback differs");
    const pointer={file:path.relative(this.root,file).split(path.sep).join("/"),sha256:digest(raw),bytes:raw.length};
    this.allBindings.push(pointer);return pointer;
  }
  startCohort({phase,capture,archive,guardInputs}) {
    need(!this.failed&&!this.active&&phase===PHASES[this.completed.length],"cohorts must run once in 13/5/1 order");
    need(Buffer.isBuffer(archive)&&archive.length>0&&archive.length<=LIMITS.wire,"bounded ZIP bytes required");
    need(capture.actualCliPreparationCaptured===true&&capture.phase===phase&&same(capture.source,this.source)&&same(capture.approvalPointer,this.approval),"prepared identity differs");
    need(capture.archiveSha256===digest(archive)&&capture.archiveBytes===archive.length,"prepared ZIP bytes differ");
    exactTime(capture.completedAtUtc);
    const directory=path.join(this.base,phase);fs.mkdirSync(directory,{mode:0o700});
    const names=phase==="fleet"?this.cohorts.schedulers:this.cohorts[phase];
    const guard=new neutral.RuntimeDeploymentTransportGuard31({...guardInputs,names,allNames:this.cohorts.fleet,phase,
      sourceArchiveHash:capture.sourceArchiveHash,endpointRuntimeHashes:capture.endpointRuntimeHashes});
    guard.preparedMatches(capture);
    this.assertExecutionWindow();
    this.active={phase,directory,guard,capture:clone(capture),records:[],completed:0,pending:0,refused:0,failed:false,lastStarted:capture.completedAtUtc,lastCompleted:capture.completedAtUtc,queue:Promise.resolve()};
    this.active.archivePointer=this.put("actual-source.zip",archive);
    this.active.capturePointer=this.put("actual-prepared-inputs.json",capture);
    return {guard,archivePath:path.join(this.root,this.active.archivePointer.file)};
  }
  begin(scope,operation,observation) {
    const s=this.active;need(s&&!s.failed&&!this.failed,"capture already failed");
    need(operation.sequence===s.records.length+1&&operation.sequence<=s.guard.names.length+2,"mutation initiation sequence differs");
    const expected=operation.sequence===1?"generate-upload":operation.sequence===2?"source-upload":"function-update";
    need(operation.kind===expected,"generation and upload must precede updates");
    if(operation.sequence===2) need(s.records[0]?.success===true,"generation has not completed successfully");
    if(operation.sequence>2) need(s.records[1]?.success===true,"upload has not completed successfully");
    need(observation&&typeof observation==="object","fresh live observation required");
    exactTime(observation.observedAtUtc);exactTime(observation.completedAtUtc);
    this.assertExecutionWindow();
    const startedAtUtc=exactTime(this.now());
    need(s.capture.completedAtUtc<=observation.observedAtUtc&&observation.observedAtUtc<=observation.completedAtUtc&&observation.completedAtUtc<=startedAtUtc&&s.lastStarted<=startedAtUtc,"live/start chronology differs");
    s.lastStarted=startedAtUtc; const original=projectRequest(scope.client,scope.request);
    if(operation.kind==="source-upload") need(original.request.body.path===path.join(this.root,s.archivePointer.file),"upload must use retained exact ZIP path");
    const prefix="mutation-"+String(operation.sequence).padStart(4,"0");
    const record={schemaVersion:3,documentType:"build31-business-original-mutation",phase:s.phase,sequence:operation.sequence,
      completionSequence:null,kind:operation.kind,name:operation.name??null,startedAtUtc,requestAdmittedAtUtc:null,firstOutboundAtUtc:null,completedAtUtc:null,
      request:this.put(prefix+"-request.json",original),wireBody:null,response:null,responseBinding:null,liveObservation:this.put(prefix+"-live.json",observation),error:null};
    const item={record,prefix,operation,wire:[],wireBytes:0,responseChunks:[],responseBytes:0,wireEnded:false,responseEnded:false,transportCount:0,success:false};
    s.records.push(item);s.pending++;scope.item=item;
    // Intent is retained before the request; a killed process cannot erase an uncompleted attempt.
    this.put(prefix+"-intent.json",{phase:s.phase,sequence:operation.sequence,kind:operation.kind,name:operation.name??null,startedAtUtc,request:record.request,liveObservation:record.liveObservation});
  }
  refuse() {
    const s=this.active; if(!s)return;this.failed=true;s.failed=true;
    this.put("boundary-refusal-"+String(++s.refused).padStart(4,"0")+".json",{schemaVersion:1,phase:s.phase,observedAtUtc:exactTime(this.now()),reason:"guarded-request-refused",rawErrorMessageRetained:false});
  }
  stampCompletion(item) {
    const s=this.active,r=item.record;need(r.completionSequence===null,"duplicate response completion");
    r.completionSequence=++s.completed;r.completedAtUtc=exactTime(this.now());
    need(r.startedAtUtc<=r.completedAtUtc&&s.lastCompleted<=r.completedAtUtc,"completion chronology differs");s.lastCompleted=r.completedAtUtc;
  }
  end(scope,apiSuccess) {
    const s=this.active,item=scope.item; if(!item)return;
    need(!item.finalized&&s&&Number.isSafeInteger(s.pending)&&s.pending>0,"capture already finalized or pending accounting differs");
    item.finalized=true;
    const r=item.record;
    try {
      if(r.completionSequence===null)this.stampCompletion(item);
      r.wireBody=this.put(item.prefix+"-wire.bin",Buffer.concat(item.wire));
      // Retain raw response bytes/status and bind them before publishing the derived mutation row.
      const responseRaw=this.put(item.prefix+"-response-wire.bin",Buffer.concat(item.responseChunks));
      let bodyText=null;
      try { if(item.responseEnded)bodyText=decodeResponse(Buffer.concat(item.responseChunks),item.encoding); } catch { item.captureError=true; }
      if(bodyText!==null&&Number.isSafeInteger(item.status)) r.response=this.put(item.prefix+"-response.json",{httpStatus:item.status,bodyText});
      const okay=apiSuccess&&!item.captureError&&item.transportCount===1&&item.wireEnded&&item.responseEnded&&item.status>=200&&item.status<300&&r.response!==null&&digest(Buffer.concat(item.wire))===item.operation.bodySha256;
      if(!okay){r.error={code:"ORIGINAL_MUTATION_NOT_PROVEN_SUCCESSFUL",responseReceived:item.responseEnded,requestComplete:item.wireEnded,apiSucceeded:apiSuccess,rawMessageRetained:false};s.failed=true;this.failed=true;}
      r.responseBinding=this.put(item.prefix+"-wire-response-binding.json",{responseRaw,contentEncoding:item.encoding??null,responseComplete:item.responseEnded,retainedBytes:item.responseBytes,httpStatus:item.status??null});
      item.success=okay;item.pointer=this.put(item.prefix+".json",r);
      return okay;
    } catch(error) {
      item.success=false;item.captureError=true;s.failed=true;this.failed=true;
      r.error={code:"ORIGINAL_CAPTURE_FINALIZATION_FAILED",rawMessageRetained:false};
      throw error;
    } finally {
      // The wrapped request has settled, even when durable evidence could not be saved.
      // Do not leave it counted as transport work or let a second finalization drain twice.
      item.wire=[];item.responseChunks=[];s.pending--;
    }
  }
  finishCohort() {
    const s=this.active;need(s&&s.pending===0,"unfinished original requests remain");
    let complete=!s.failed&&!this.failed&&s.records.length===s.guard.names.length+2&&s.records.every(v=>v.success);
    try{s.guard.assertComplete();}catch{complete=false;}
    const ordered=s.records.map(v=>v.pointer),end=exactTime(this.now());need(end>=s.lastCompleted,"instrumented completion preceded response");
    let pointer;
    if(complete){
      const events=[...s.records].sort((a,b)=>a.record.completionSequence-b.record.completionSequence).map(v=>({kind:v.record.kind,sequence:v.record.sequence,...(v.record.name?{name:v.record.name}:{})}));
      need(same([...events].sort((a,b)=>a.sequence-b.sequence),s.guard.events.filter(e=>mutations(e.kind)).sort((a,b)=>a.sequence-b.sequence)),"guard/event population differs");
      pointer=this.put("instrumented-cli-complete.json",{schemaVersion:1,documentType:"build31-business-instrumented-completion",phase:s.phase,source:this.source,approvalPointer:this.approval,capture:s.capturePointer,archive:s.archivePointer,mutations:ordered,events,completedAtUtc:end,exitCode:0,error:null});
    }else{
      this.failed=true;pointer=this.put("instrumented-capture-failed.json",{schemaVersion:1,documentType:"build31-business-instrumented-failure",phase:s.phase,source:this.source,approvalPointer:this.approval,capture:s.capturePointer,archive:s.archivePointer,mutations:ordered,completedAtUtc:end,refusedRequests:s.refused,error:"INCOMPLETE_OR_FAILED_ORIGINAL_TRANSCRIPT",noAutomaticRetry:true});
    }
    const result={phase:s.phase,complete,capture:s.capturePointer,archive:s.archivePointer,mutations:ordered,completion:pointer};
    if(complete)this.completed.push(result);this.active=null;return result;
  }
  finish() {
    need(!this.active&&!this.failed&&this.completed.length===3,"three successful original cohorts required");
    need(this.completed.reduce((n,c)=>n+c.mutations.length,0)===25,"exact25 mutations required");
    for(const p of this.allBindings){const b=fs.readFileSync(path.join(this.root,p.file));need(b.length===p.bytes&&digest(b)===p.sha256,"retained original changed");}
    return {schemaVersion:1,documentType:"build31-business-capture-measurement",cohorts:this.completed,mutationCount:25,functions:19,
      processExecutionAuthenticated:false,platformIdentityAuthenticated:false,trustedClockAuthenticated:false,deploymentAuthorized:false,credentialAccessAuthorized:false};
  }
}
function installBusinessCapture31({Client,writer,observeLive}) {
  need(writer.active&&typeof observeLive==="function","active cohort and observer required");
  const s=writer.active,guard=s.guard,local=new AsyncLocalStorage();
  const https=require("node:https"),http=require("node:http"),net=require("node:net"),tls=require("node:tls"),Module=require("node:module");
  const saved={client:Client.prototype.request,httpsRequest:https.request,httpsGet:https.get,httpRequest:http.request,httpGet:http.get,connect:net.Socket.prototype.connect,tlsConnect:tls.connect,load:Module._load,fetch:globalThis.fetch};
  let released=false;
  for(const api of [https,http]) {
    const request=api.request;
    // This observer is underneath the unchanged network guard: it sees only bytes actually forwarded.
    api.request=function(...args){
      const scope=local.getStore(),candidate=scope?.item;
      const effective=neutral.effectiveRequest31(args[0],args[1],api===https?"https:":"http:");
      const item=candidate&&effective.url.href===candidate.operation.url&&effective.method===candidate.operation.method?candidate:null;
      if(item){need(++item.transportCount===1&&item.record.requestAdmittedAtUtc===null,"second mutation transport refused");item.record.requestAdmittedAtUtc=writer.assertExecutionWindow();}
      const req=request.apply(this,args);if(!item)return req;
      const write=req.write,end=req.end;let outboundStarted=false;
      const beforeOutbound=()=>{
        if(outboundStarted)return;
        try{need(item.record.firstOutboundAtUtc===null,"first outbound timestamp already recorded");item.record.firstOutboundAtUtc=writer.assertExecutionWindow();}catch(error){item.captureError=true;req.destroy(error);throw error;}
        outboundStarted=true;
      };
      const retain=chunk=>{if(chunk===undefined||chunk===null)return;need(Buffer.isBuffer(chunk),"original request wire must be bytes");need(item.wireBytes+chunk.length<=LIMITS.wire,"wire bound exceeded");item.wire.push(Buffer.from(chunk));item.wireBytes+=chunk.length;};
      req.write=function(chunk,...rest){retain(chunk);beforeOutbound();return write.call(this,chunk,...rest);};
      req.end=function(chunk,...rest){retain(chunk);beforeOutbound();item.wireEnded=true;return end.call(this,chunk,...rest);};
      req.prependListener("response",res=>{
        item.status=res.statusCode; item.encoding=res.headers?.["content-encoding"]??null;
        res.prependListener("data",chunk=>{
          if(!Buffer.isBuffer(chunk)||item.responseBytes+chunk.length>LIMITS.response){item.captureError=true;res.destroy(Error("Business capture response bound/type refused"));return;}
          item.responseChunks.push(Buffer.from(chunk));item.responseBytes+=chunk.length;
        });
        res.prependListener("end",()=>{item.responseEnded=true;writer.stampCompletion(item);});
        res.on("aborted",()=>{item.captureError=true;});res.on("error",()=>{item.captureError=true;});
      });
      return req;
    };
  }
  neutral.installNetworkBoundary31(guard);
  neutral.installApiBoundary31(Client,guard,operation=>{
    const scope=local.getStore();need(scope,"capture context missing");
    // Preserve admission initiation order while allowing all admitted updates to remain in flight.
    const run=s.queue.then(async()=>{need(!s.failed&&!writer.failed,"failed cohort cannot initiate another write");const observation=await observeLive(operation);writer.begin(scope,operation,observation);});
    s.queue=run.catch(()=>{});return run;
  });
  const guarded=Client.prototype.request;
  Client.prototype.request=function(request){const scope={client:this,request};
    return local.run(scope,async()=>{let result,success=false;
      try{result=await guarded.call(this,request);success=true;}
      catch(error){if(!scope.item)writer.refuse();throw error;}
      finally{if(scope.item){const okay=writer.end(scope,success);if(success&&!okay)throw Error("Business capture refused incomplete original response");}}
      return result;
    });
  };
  return function restoreAfterCapture(){need(!released&&s.pending===0,"capture still active or already restored");released=true;
    Client.prototype.request=saved.client;https.request=saved.httpsRequest;https.get=saved.httpsGet;http.request=saved.httpRequest;http.get=saved.httpGet;
    net.Socket.prototype.connect=saved.connect;tls.connect=saved.tlsConnect;Module._load=saved.load;globalThis.fetch=saved.fetch;
  };
}
if(require.main===module) { process.stderr.write("Private proposal has no operational entry; authenticated controller integration is required.\n");process.exitCode=1; }
module.exports={BusinessCapture31,installBusinessCapture31,installCliLoadBoundary31,projectRequest,decodeResponse,LIMITS,
  captureActualPreparedInputs31:prepared.captureActualPreparedInputs31,readCurrentControlResponse31:prepared.readCurrentControlResponse31};
