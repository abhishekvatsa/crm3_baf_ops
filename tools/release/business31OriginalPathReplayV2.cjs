'use strict';
// Outer transport is a successor profile; the recorded M replay is executed by
// an isolated Node22 worker using only its preserved, separately bound helpers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process'),{isDeepStrictEqual:same,TextDecoder}=require('node:util');
const SELF='tools/release/business31OriginalPathReplayV2.cjs',WORKER='tools/release/business31CoreWorkerV2.cjs';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function need(v,m){if(!v)throw Error('Business original-path replay v2: '+m);}
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
 try{
  need(sha(fs.readFileSync(process.execPath))===nodeSha256,'pinned Node changed before worker');
  const child=spawnSync(process.execPath,['--no-global-search-paths',workerFile,inputFile,sha(raw)],{
   cwd:ownedDirectory,env:workerEnvironment31(),windowsHide:true,timeout:600000,maxBuffer:2*1024*1024,encoding:null,stdio:['ignore','pipe','pipe']});
  need(!child.error&&!child.signal&&child.status===0,'fresh recorded core worker failed');
  need(Buffer.isBuffer(child.stdout)&&child.stdout.length>0&&child.stdout.length<=2*1024*1024&&Buffer.isBuffer(child.stderr)&&child.stderr.length===0,'bounded clean worker result required');
  const out=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(child.stdout));
  need(out.schemaVersion===1&&out.profile==='build31-business-recorded-core-worker-v2'&&out.recordedSemanticsReplayed===true&&out.originalPathsUnavailable===true&&out.deploymentAuthorized===false&&out.constructionAuthorized===false&&out.distributionAuthorized===false,'worker result profile/authority differs');
  return out;
 }finally{fs.unlinkSync(inputFile);}
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
  'tools/release/business31OriginalPathReplay.cjs','tools/release/privateEvidenceBundle31.cjs','tools/release/business31TrustedInput.cjs','tools/release/backendRuntimeEvidenceAccess31.cjs']);
 const legacy=require('./business31OriginalPathReplay.cjs');legacy.executingBindings31(map);
 const descriptorApi=require('./business31PrivateDescriptorV2.cjs'),transport=require('./privateEvidenceBundle31.cjs'),worker=require('./business31CoreWorkerV2.cjs');
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
