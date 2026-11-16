'use strict';
// Outer transport is a successor profile; the recorded M replay is executed by
// an isolated Node22 worker using only its preserved, separately bound helpers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process'),{isDeepStrictEqual:same,TextDecoder}=require('node:util');
const SELF='tools/release/business31OriginalPathReplayV2.cjs',WORKER='tools/release/business31CoreWorkerV2.cjs';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function need(v,m){if(!v)throw Error('Business original-path replay v2: '+m);}
// Strictly bounded failure data only; never a worker result or raw stderr.
const FAILURE_STAGES=Object.freeze(["WORKER_ENTRY","WORKER_INPUT","WORKER_RUNTIME","WORKER_INVENTORY","WORKER_RELOCATION","WORKER_CORE_BINDING","WORKER_CORE_LOAD","WORKER_RELOCATION_CONTEXT","WORKER_GIT","WORKER_BACKEND_CLOSURE","WORKER_RESULT","WORKER_FINAL_INVENTORY","WORKER_FINAL_RUNTIME","WORKER_OUTPUT"]),FAILURE_REASONS=Object.freeze(["M_REFUSAL_001","M_REFUSAL_002","M_REFUSAL_003","M_REFUSAL_004","M_REFUSAL_005","M_REFUSAL_006","M_REFUSAL_007","M_REFUSAL_008","M_REFUSAL_009","M_REFUSAL_010","M_REFUSAL_011","M_REFUSAL_012","M_REFUSAL_013","M_REFUSAL_014","M_REFUSAL_015","M_REFUSAL_016","M_REFUSAL_017","M_REFUSAL_018","M_REFUSAL_019","M_REFUSAL_020","M_REFUSAL_021","M_REFUSAL_022","M_REFUSAL_023","M_REFUSAL_024","M_REFUSAL_025","M_REFUSAL_026","M_REFUSAL_027","M_REFUSAL_028","M_REFUSAL_029","M_REFUSAL_030","M_REFUSAL_031","M_REFUSAL_032","M_REFUSAL_033","M_REFUSAL_034","M_REFUSAL_035","M_REFUSAL_036","M_REFUSAL_037","M_REFUSAL_038","M_REFUSAL_039","M_REFUSAL_040","M_REFUSAL_041","M_REFUSAL_042","M_REFUSAL_043","M_REFUSAL_044","M_REFUSAL_045","M_REFUSAL_046","M_REFUSAL_047","M_REFUSAL_048","M_REFUSAL_049","M_REFUSAL_050","M_REFUSAL_051","M_REFUSAL_052","M_REFUSAL_053","M_REFUSAL_054","M_REFUSAL_055","M_REFUSAL_056","M_REFUSAL_057","M_REFUSAL_058","M_REFUSAL_059","M_REFUSAL_060","M_REFUSAL_061","M_REFUSAL_062","M_REFUSAL_063","M_REFUSAL_064","M_REFUSAL_065","M_REFUSAL_066","M_REFUSAL_067","M_REFUSAL_068","M_REFUSAL_069","M_REFUSAL_070","M_REFUSAL_071","M_REFUSAL_072","M_REFUSAL_073","M_REFUSAL_074","M_REFUSAL_075","M_REFUSAL_076","M_REFUSAL_077","M_REFUSAL_078","M_REFUSAL_079","M_REFUSAL_080","M_REFUSAL_081","M_REFUSAL_082","M_REFUSAL_083","M_REFUSAL_084","M_REFUSAL_085","M_REFUSAL_086","M_REFUSAL_087","M_REFUSAL_088","M_REFUSAL_089","M_REFUSAL_090","M_REFUSAL_091","M_REFUSAL_092","M_REFUSAL_093","M_REFUSAL_094","M_REFUSAL_095","M_REFUSAL_096","M_REFUSAL_097","M_REFUSAL_098","M_REFUSAL_099","M_REFUSAL_100","M_REFUSAL_101","M_REFUSAL_102","M_REFUSAL_103","M_REFUSAL_104","M_REFUSAL_105","M_REFUSAL_106","M_REFUSAL_107","M_REFUSAL_108","M_REFUSAL_109","M_REFUSAL_110","M_REFUSAL_111","M_REFUSAL_112","M_REFUSAL_113","M_REFUSAL_114","M_REFUSAL_115","M_REFUSAL_116","M_REFUSAL_117","M_REFUSAL_118","M_REFUSAL_119","M_REFUSAL_120","M_REFUSAL_121","M_REFUSAL_122","M_REFUSAL_123","M_REFUSAL_124","M_REFUSAL_125","M_REFUSAL_126","M_REFUSAL_127","M_REFUSAL_128","M_REFUSAL_129","M_REFUSAL_130","M_REFUSAL_131","M_REFUSAL_132","M_REFUSAL_133","M_REFUSAL_134","M_REFUSAL_135","M_REFUSAL_136","M_REFUSAL_137","M_REFUSAL_138","M_REFUSAL_139","M_REFUSAL_140","M_REFUSAL_141","M_REFUSAL_142","M_REFUSAL_143","M_REFUSAL_144","M_REFUSAL_145","M_REFUSAL_146","M_REFUSAL_147","M_REFUSAL_148","M_REFUSAL_149","M_REFUSAL_150","M_REFUSAL_151","M_REFUSAL_152","M_REFUSAL_153","M_REFUSAL_154","M_REFUSAL_155","M_REFUSAL_156","M_REFUSAL_157","M_REFUSAL_158","M_REFUSAL_159","M_REFUSAL_160","M_REFUSAL_161","M_REFUSAL_162","M_REFUSAL_163","M_REFUSAL_164","M_REFUSAL_165","M_REFUSAL_166","M_REFUSAL_167","M_REFUSAL_168","M_REFUSAL_169","M_REFUSAL_170","M_REFUSAL_171","M_REFUSAL_172","M_REFUSAL_173","M_REFUSAL_174","M_REFUSAL_175","M_REFUSAL_176","M_REFUSAL_177","M_REFUSAL_178","M_REFUSAL_179","M_REFUSAL_180","M_REFUSAL_181","M_REFUSAL_182","M_REFUSAL_183","M_REFUSAL_184","M_REFUSAL_185","M_REFUSAL_186","M_REFUSAL_187","M_REFUSAL_188","M_REFUSAL_189","M_REFUSAL_190","M_REFUSAL_191","M_REFUSAL_192","M_REFUSAL_193","M_REFUSAL_194","M_REFUSAL_195","M_REFUSAL_196","M_REFUSAL_197","M_REFUSAL_198","M_REFUSAL_199","M_REFUSAL_200","M_REFUSAL_201","M_REFUSAL_202","M_REFUSAL_203","M_REFUSAL_204","M_REFUSAL_205","M_REFUSAL_206","M_REFUSAL_207","M_REFUSAL_208","M_REFUSAL_209","M_REFUSAL_210","M_REFUSAL_211","M_REFUSAL_212","M_REFUSAL_213","M_REFUSAL_214","M_REFUSAL_215","M_REFUSAL_216","M_REFUSAL_217","M_REFUSAL_218","M_REFUSAL_219","M_REFUSAL_220","M_REFUSAL_221","M_REFUSAL_222","M_REFUSAL_223","M_REFUSAL_224","M_REFUSAL_225","M_REFUSAL_226","M_REFUSAL_227","M_REFUSAL_228","M_REFUSAL_229","M_REFUSAL_230","M_REFUSAL_231","M_REFUSAL_232","M_REFUSAL_233","M_REFUSAL_234","M_REFUSAL_235","NATIVE_FAILURE","PARSE_REFUSAL","UNCLASSIFIED","WORKER_ABSOLUTE_PHYSICAL_PATH_REQUIRED","WORKER_BUNDLE_REDIRECTS","WORKER_CLOSED_WORKER_INPUT_REQUIRED","WORKER_COMPLETE_EXTRACTED_INVENTORY_DIFFERS","WORKER_COMPLETE_INVENTORY_CARDINALITY_DIFFERS","WORKER_EXACT_INPUT_BINDING_REQUIRED","WORKER_FINITE_RECORDED_PRODUCER_MAP_REQUIRED","WORKER_FINITE_REGULAR_BUNDLE_POPULATION_REQUIRED","WORKER_FIXED_FRESH_PROCESS_FLAGS_REQUIRED","WORKER_LOADER_ENVIRONMENT_REFUSED","WORKER_MEMBER_CASE_COLLISION","WORKER_MEMBER_CHANGED_DURING_INVENTORY","WORKER_MEMBER_PREFIX_COLLISION","WORKER_ORIGINAL_PATH_REMAINS_AVAILABLE","WORKER_PHYSICAL_PATH_IDENTITY_DIFFERS","WORKER_PHYSICAL_PATH_REDIRECTS","WORKER_PINNED_NODE22_REQUIRED","WORKER_PRIVATE_POPULATION_CHANGED_DURING_CORE_REPLAY","WORKER_RECORDED_CLOSURE_SUBSET_DIFFERS","WORKER_RECORDED_CORE_SOURCE_DIFFERS","WORKER_RECORDED_HELPER_NOT_SELECTED","WORKER_RECORDED_PRODUCER_BINDING_INVALID","WORKER_REGULAR_PHYSICAL_PATH_REQUIRED","WORKER_RELOCATION_COMMITMENT_DIFFERS","WORKER_RUNTIME_CHANGED_DURING_CORE_REPLAY","WORKER_SAFE_MEMBER_REQUIRED","WORKER_SELECTED_RUNTIME_CHANGED","WORKER_SOURCE_MANIFEST_COMMITMENT_DIFFERS","WORKER_UNCHANGED_CORE_REPLAY_INCOMPLETE","WORKER_UNCHANGED_MEMBER_EXPANDED_BYTE_CAP_EXCEEDED","WORKER_UNIQUE_ORIGINAL_ROLE_ROOT_REQUIRED","WORKER_WORKER_INPUT_CHANGED","WORKER_WORKER_METADATA_BOUND_EXCEEDED","WORKER_WORKER_PROFILE_DIFFERS","WORKER_WORKER_RESULT_BOUND_EXCEEDED"]);
const NATIVE_CODES=Object.freeze(["EACCES","EAGAIN","EBADF","EBUSY","ECHILD","ECONNREFUSED","ECONNRESET","EEXIST","EFAULT","EFBIG","EINTR","EINVAL","EIO","EISDIR","EMFILE","ENAMETOOLONG","ENFILE","ENOENT","ENOMEM","ENOSPC","ENOTDIR","ENOTEMPTY","ENOTSUP","EPERM","EPIPE","ETIMEDOUT","ERR_BUFFER_TOO_LARGE","ERR_FS_FILE_TOO_LARGE","ERR_INVALID_ARG_TYPE","ERR_OUT_OF_RANGE","ENOBUFS"]),SIGNALS=Object.freeze(["SIGABRT","SIGALRM","SIGBUS","SIGFPE","SIGHUP","SIGILL","SIGINT","SIGKILL","SIGPIPE","SIGQUIT","SIGSEGV","SIGTERM","SIGTRAP"]);
const OWN_REFUSALS=Object.freeze({"Business original-path replay v2: outer helper not selected":"ORIGINAL_OUTER_HELPER_NOT_SELECTED","Business original-path replay v2: outer helper redirects":"ORIGINAL_OUTER_HELPER_REDIRECTS","Business original-path replay v2: outer helper bytes differ":"ORIGINAL_OUTER_HELPER_BYTES_DIFFER","Business original-path replay v2: pinned Node22 required":"ORIGINAL_PINNED_NODE22_REQUIRED","Business original-path replay v2: bounded worker metadata required":"ORIGINAL_BOUNDED_WORKER_METADATA_REQUIRED","Business original-path replay v2: pinned Node changed before worker":"ORIGINAL_PINNED_NODE_CHANGED_BEFORE_WORKER","Business original-path replay v2: fresh recorded core worker failed":"ORIGINAL_FRESH_RECORDED_CORE_WORKER_FAILED","Business original-path replay v2: bounded clean worker result required":"ORIGINAL_BOUNDED_CLEAN_WORKER_RESULT_REQUIRED","Business original-path replay v2: worker result profile/authority differs":"ORIGINAL_WORKER_RESULT_PROFILE_AUTHORITY_DIFFERS","Business original-path replay v2: closed offline input required":"ORIGINAL_CLOSED_OFFLINE_INPUT_REQUIRED","Business original-path replay v2: exact pinned Node22 identity required":"ORIGINAL_EXACT_PINNED_NODE22_IDENTITY_REQUIRED","Business original-path replay v2: explicit caller clock required":"ORIGINAL_EXPLICIT_CALLER_CLOCK_REQUIRED","Business original-path replay v2: bounded existing bundle bytes required":"ORIGINAL_BOUNDED_EXISTING_BUNDLE_BYTES_REQUIRED","Business original-path replay v2: descriptor changed":"ORIGINAL_DESCRIPTOR_CHANGED","Business original-path replay v2: source manifest object differs":"ORIGINAL_SOURCE_MANIFEST_OBJECT_DIFFERS","Business original-path replay v2: complete extracted population differs":"ORIGINAL_COMPLETE_EXTRACTED_POPULATION_DIFFERS","Business original-path replay v2: selected runtime differs":"ORIGINAL_SELECTED_RUNTIME_DIFFERS","Business original-path replay v2: worker commitments differ":"ORIGINAL_WORKER_COMMITMENTS_DIFFER","Business original-path replay v2: core closure source/custody differs":"ORIGINAL_CORE_CLOSURE_SOURCE_CUSTODY_DIFFERS","Business original-path replay v2: private evidence changed during replay":"ORIGINAL_PRIVATE_EVIDENCE_CHANGED_DURING_REPLAY","Business original-path replay v2: runtime changed during replay":"ORIGINAL_RUNTIME_CHANGED_DURING_REPLAY","Business original-path replay v2: candidate moved during replay":"ORIGINAL_CANDIDATE_MOVED_DURING_REPLAY"});
function ownData31(value,key){
 if(value===null||(typeof value!=='object'&&typeof value!=='function'))return undefined;
 const descriptor=Object.getOwnPropertyDescriptor(value,key);
 if(descriptor&&!Object.hasOwn(descriptor,'value'))throw Error('BUSINESS_DIAGNOSTIC_ACCESSOR');
 return descriptor?descriptor.value:undefined;
}
function childFailure31(child,stage,error){
 const fallback={schemaVersion:1,stage:['CORE_WORKER_PREPARE','CORE_WORKER_PROCESS','CORE_WORKER_RESULT','CORE_WORKER_INPUT_CLEANUP'].includes(stage)?stage:'CORE_WORKER_PROCESS',reason:'UNCLASSIFIED',nativeCode:null,workerExit:null,workerSignal:null,workerCleanupFailed:false,cleanupFailed:false};
 try{
  const numeric=v=>Number.isInteger(v)&&v>=0&&v<=4294967295?v:null;
  const childError=ownData31(child,'error'),status=ownData31(child,'status'),signal=ownData31(child,'signal'),raw=ownData31(child,'stderr');
  const childCode=ownData31(childError,'code'),code=ownData31(error,'code'),message=ownData31(error,'message');
  const record={...fallback,reason:typeof message==='string'&&Object.hasOwn(OWN_REFUSALS,message)?OWN_REFUSALS[message]:
   (error!==null&&typeof error==='object'&&Object.getPrototypeOf(error)===SyntaxError.prototype)?'PARSE_REFUSAL':'UNCLASSIFIED',
   nativeCode:NATIVE_CODES.includes(childCode)?childCode:NATIVE_CODES.includes(code)?code:null,workerExit:numeric(status),workerSignal:SIGNALS.includes(signal)?signal:null};
  const prefix='BUSINESS31_RECORDED_CORE_WORKER_FAILED ';
  if(Buffer.isBuffer(raw)&&raw.length>0&&raw.length<=512){try{
   const text=new TextDecoder('utf-8',{fatal:true}).decode(raw);if(!text.startsWith(prefix))return record;
   const value=JSON.parse(text.slice(prefix.length));
   if(value&&same(Object.keys(value).sort(),['schemaVersion','stage','reason','nativeCode','workerExit','workerSignal','workerCleanupFailed','cleanupFailed'].sort())&&value.schemaVersion===1&&FAILURE_STAGES.includes(value.stage)&&FAILURE_REASONS.includes(value.reason)&&(value.nativeCode===null||NATIVE_CODES.includes(value.nativeCode))&&value.workerExit===null&&value.workerSignal===null&&value.workerCleanupFailed===false&&value.cleanupFailed===false&&prefix+JSON.stringify(value)+'\n'===text){record.stage=value.stage;record.reason=value.reason;record.nativeCode=value.nativeCode;}
  }catch{ /* Unknown private output is never re-emitted. */ }}
  if(record.nativeCode&&record.reason==='UNCLASSIFIED')record.reason='NATIVE_FAILURE';
  return record;
 }catch{return fallback;}
}
function failureWrapper31(diagnostic){
 const wrapped=Error('Business original-path replay v2: fresh recorded core worker failed');
 Object.defineProperty(wrapped,'business31Diagnostic',{value:Object.freeze(diagnostic)});
 return wrapped;
}
function initialBind(map,file){
 need(map&&/^[A-F0-9]{64}$/.test(map[file]),'outer helper not selected');const full=path.resolve(__dirname,path.basename(file));let cursor=path.parse(full).root;
 for(const part of full.slice(cursor.length).split(path.sep).filter(Boolean)){cursor=path.join(cursor,part);need(!fs.lstatSync(cursor).isSymbolicLink(),'outer helper redirects');}
 need(fs.lstatSync(full).isFile()&&sha(fs.readFileSync(full))===map[file],'outer helper bytes differ');return full;
}
function workerEnvironment31(){
 const env={};for(const key of ['SystemRoot','SYSTEMROOT','WINDIR','COMSPEC','TEMP','TMP','PATH','PATHEXT','LANG','LC_ALL'])if(process.env[key]!==undefined)env[key]=process.env[key];
 Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null',GIT_TERMINAL_PROMPT:'0',GIT_PAGER:'cat',GIT_OPTIONAL_LOCKS:'0',GIT_NO_LAZY_FETCH:'1'});return env;
}
function invokeCoreWorker31({workerFile,input,ownedDirectory,nodeSha256}){
 need(Number(process.versions.node.split('.')[0])===22,'pinned Node22 required');
 const raw=Buffer.from(JSON.stringify(input));need(raw.length>0&&raw.length<=2*1024*1024,'bounded worker metadata required');
 const inputFile=path.join(ownedDirectory,'.business31-core-'+crypto.randomUUID()+'.json');
 fs.writeFileSync(inputFile,raw,{flag:'wx',mode:0o600});
 let primaryDiagnostic=null,child=null,stage='CORE_WORKER_PREPARE';
 try{
  need(sha(fs.readFileSync(process.execPath))===nodeSha256,'pinned Node changed before worker');
  stage='CORE_WORKER_PROCESS';
  child=spawnSync(process.execPath,['--no-global-search-paths',workerFile,inputFile,sha(raw)],{
   cwd:ownedDirectory,env:workerEnvironment31(),windowsHide:true,timeout:600000,maxBuffer:2*1024*1024,encoding:null,stdio:['ignore','pipe','pipe']});
  need(!child.error&&!child.signal&&child.status===0,'fresh recorded core worker failed');
  stage='CORE_WORKER_RESULT';
  need(Buffer.isBuffer(child.stdout)&&child.stdout.length>0&&child.stdout.length<=2*1024*1024&&Buffer.isBuffer(child.stderr)&&child.stderr.length===0,'bounded clean worker result required');
  const out=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(child.stdout));
  need(out.schemaVersion===1&&out.profile==='build31-business-recorded-core-worker-v2'&&out.recordedSemanticsReplayed===true&&out.originalPathsUnavailable===true&&out.deploymentAuthorized===false&&out.constructionAuthorized===false&&out.distributionAuthorized===false,'worker result profile/authority differs');
  return out;
 }catch(error){
  primaryDiagnostic=childFailure31(child,stage,error);throw failureWrapper31(primaryDiagnostic);
 }finally{
  try{fs.unlinkSync(inputFile);}catch(cleanupError){
   const prior=primaryDiagnostic||childFailure31(child,'CORE_WORKER_INPUT_CLEANUP',cleanupError);
   throw failureWrapper31({...prior,workerCleanupFailed:true});
  }
 }
}
function verifyBusiness31OriginalPathReplayV2(options){
 need(options&&same(Object.keys(options).sort(),['repositoryRoot','gitExecutable','gitSha256','nodeSha256','envelope','descriptorPointer','sourceManifest','expectedSourceManifestSha256','bundleBytes','extractionRoot','nowUtc'].sort()),'closed offline input required');
 const {repositoryRoot,gitExecutable,gitSha256,nodeSha256,envelope,descriptorPointer,sourceManifest,expectedSourceManifestSha256,bundleBytes,extractionRoot,nowUtc}=options;
 need(/^[A-F0-9]{64}$/.test(nodeSha256)&&Number(process.versions.node.split('.')[0])===22,'exact pinned Node22 identity required');
 need(typeof nowUtc==='string'&&/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?Z$/.test(nowUtc)&&Number.isFinite(Date.parse(nowUtc)),'explicit caller clock required');
 need(Buffer.isBuffer(bundleBytes)&&bundleBytes.length>0&&bundleBytes.length<=512*1024*1024,'bounded existing bundle bytes required');
 const map=envelope?.verifier?.files;initialBind(map,SELF);initialBind(map,'tools/release/business31TrustedInputV2.cjs');
 const trusted=require('./business31TrustedInputV2.cjs');
 trusted.bindLocal31(map,[WORKER,'tools/release/business31PrivateDescriptorV2.cjs','tools/release/business31PrivateDescriptor.cjs',
  'tools/release/business31OriginalPathReplay.cjs','tools/release/privateEvidenceBundle31.cjs','tools/release/privateEvidenceBundle31V2.cjs','tools/release/business31TrustedInput.cjs','tools/release/backendRuntimeEvidenceAccess31.cjs']);
 const legacy=require('./business31OriginalPathReplay.cjs');legacy.executingBindings31(map);
 const descriptorApi=require('./business31PrivateDescriptorV2.cjs'),transport=require('./privateEvidenceBundle31V2.cjs'),worker=require('./business31CoreWorkerV2.cjs');
 const proof=descriptorApi.verifyBusiness31DescriptorPreparationV2({repositoryRoot,gitExecutable,gitSha256,envelope,descriptorPointer,expectedSourceManifestSha256});
 const repository=require('./business31TrustedInput.cjs').openTrustedGitRepository31({repositoryRoot,gitExecutable,gitSha256});
 const descriptorBytes=repository.readBlob(descriptorPointer.commit,descriptorPointer.file);need(sha(descriptorBytes)===proof.descriptorSha256,'descriptor changed');
 const d=descriptorApi.validateBusiness31PrivateDescriptorV2(descriptorApi.json(descriptorBytes));
 need(sha(Buffer.from(worker.canonical(sourceManifest)))===expectedSourceManifestSha256,'source manifest object differs');
 const verified=transport.verifyBundleBytesV2(bundleBytes,d,'business');legacy.validateRelocation31(verified.relocation,verified.inventory);legacy.originalPathsUnavailable31(verified.relocation);
 const extracted=transport.extractVerifiedBundleV2(bundleBytes,d,extractionRoot,'business');
 need(same(worker.inventoryV2(extracted.root),verified.inventory),'complete extracted population differs');
 worker.coreFiles(extracted.root,verified.relocation,d.coreVerifier.files);
 const node=worker.regular(process.execPath),git=worker.regular(gitExecutable);need(sha(fs.readFileSync(node))===nodeSha256&&sha(fs.readFileSync(git))===gitSha256,'selected runtime differs');
 const result=invokeCoreWorker31({workerFile:initialBind(map,WORKER),ownedDirectory:worker.regular(path.dirname(extracted.root),true),nodeSha256,
  input:{schemaVersion:1,profile:'build31-business-recorded-core-worker-v2',extractionRoot:extracted.root,relocation:verified.relocation,descriptor:d,
   sourceManifest,expectedSourceManifestSha256,gitExecutable:git,gitSha256,nodeSha256,nowUtc}});
 need(same(result.coreVerifier,{commit:d.coreVerifier.commit,tree:d.coreVerifier.tree})&&result.membersSha256===d.membersSha256&&result.relocationSha256===d.relocationSha256,'worker commitments differ');
 need(result.closure?.recordedSemanticsReplayed===true&&same(result.closure.source,d.source)&&same(result.closure.decisionPointer,d.approvalPointer)&&same(result.closure.closurePointer,d.closurePointer),'core closure source/custody differs');
 need(same(worker.inventoryV2(extracted.root),verified.inventory),'private evidence changed during replay');legacy.originalPathsUnavailable31(verified.relocation);
 legacy.executingBindings31(map);need(sha(fs.readFileSync(node))===nodeSha256&&sha(fs.readFileSync(git))===gitSha256,'runtime changed during replay');
 need(repository.readRef(envelope.candidate.ref)===envelope.candidate.commit,'candidate moved during replay');
 return Object.freeze({schemaVersion:2,documentType:'build31-business-offline-original-path-replay',profile:d.profile,source:structuredClone(d.source),
  coreVerifier:{commit:d.coreVerifier.commit,tree:d.coreVerifier.tree},coreProducerBindingsSha256:sha(Buffer.from(worker.canonical(d.coreVerifier.files))),
  sourceIntegrationSha256:sha(Buffer.from(worker.canonical(d.sourceIntegration))),descriptorSha256:sha(descriptorBytes),membersSha256:d.membersSha256,
  relocationSha256:d.relocationSha256,memberCount:Object.keys(verified.inventory).length,originalPathsUnavailable:true,
  descriptorPreparationVerified:true,completeProducerBindingsVerified:true,recordedSemanticsReplayed:true,closure:result.closure,
  platformIdentityAuthenticated:false,humanIdentityAuthenticated:false,processExecutionAuthenticated:false,trustedClockAuthenticated:false,
  privateHostedReplayAuthenticated:false,credentialAccessAuthorized:false,deploymentAuthorized:false,constructionAuthorized:false,distributionAuthorized:false});
}
module.exports={SELF,WORKER,workerEnvironment31,invokeCoreWorker31,verifyBusiness31OriginalPathReplayV2};
