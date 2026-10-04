'use strict';
// PRIVATE PROPOSAL: validates descriptor structure and committed bytes only.
// No credential, download, candidate-code execution or operational authority.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {isDeepStrictEqual, TextDecoder} = require('node:util');
const PROFILE = 'build31-exact-business-backend-v1';
const SELF = 'tools/release/business31PrivateDescriptor.cjs';
const DESCRIPTOR = 'release/evidence/build31-business-private-replay.json';
const FILES = Object.freeze({
  approvalPointer:'release/approvals/build31-business-backend-deployment-approval.json',
  closurePointer:'release/evidence/build31-business-backend-deployment-closure.json'
});
const HISTORICAL = Object.freeze({commit:'2aa30de56cfdb960da3eeefd8956d8cbbae57b46',
  file:'release/evidence/build30-current-source-backend-deployment-closure.json',
  sha256:'3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45'});
const CORE = Object.freeze([
  'business31PrivateDescriptor.cjs','business31TrustedInput.cjs',
  'business31SourceAdmission.cjs','business31BackendAuthority.cjs','business31NpmBinMaterialization.cjs','business31ToolchainIdentity.cjs',
  'business31ExecutionContract.cjs','business31BackendClosure.cjs',
  'captureBusiness31PreparedInputs.cjs','business31CaptureBootstrap.cjs','privateEvidenceBundle31.cjs',
  'backendRuntimeEvidenceAccess31.cjs','backendRuntimeControls31.cjs',
  'backendRuntimeReadbacks31.cjs','backendRuntimeExecutionAdmission31.cjs',
  'runtimeDeploymentTransportGuard31.cjs'
].map(file=>'tools/release/'+file));
const sha = bytes=>crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(ok,label){if(!ok)throw Error('Business descriptor: '+label);}
function exact(value,names,label){
  need(value && typeof value==='object' && !Array.isArray(value) &&
    [Object.prototype,null].includes(Object.getPrototypeOf(value)) &&
    isDeepStrictEqual(Object.keys(value).sort(),[...names].sort()),label+' fields differ');
}
function same(a,b,label){need(isDeepStrictEqual(a,b),label);}
const hex=(value,size)=>typeof value==='string'&&new RegExp('^[0-9a-f]{'+size+'}$',size===64?'i':'').test(value);
function pointer(value,file){
  exact(value,['commit','file','sha256'],'pointer');
  need(hex(value.commit,40)&&value.file===file&&typeof value.sha256==='string'&&/^[A-F0-9]{64}$/.test(value.sha256),'exact immutable pointer required');
}
function binding(value,label){
  exact(value,['commit','tree'],label);
  need(hex(value.commit,40)&&hex(value.tree,40),label+' identity invalid');
}
function producer(file){
  return typeof file==='string' && (file==='tools/v4/v4_2_r1_canonical_audit.py' || /^tools\/release\/.+\.(?:js|cjs|ps1)$/.test(file));
}
function safeProducer(file){
  return producer(file) && /^[A-Za-z0-9_+./-]+$/.test(file) &&
    file.split('/').every(p=>p&&p!=='.'&&p!=='..'&&!/[. ]$/.test(p)&&
      !/^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(p));
}
function json(bytes){
  need(Buffer.isBuffer(bytes)&&bytes.length>0&&bytes.length<=2*1024*1024,'bounded metadata bytes required');
  const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
  const pending=[[value,0]];let nodes=0;
  while(pending.length){const [item,depth]=pending.pop();need(++nodes<=50000&&depth<=32,'metadata complexity exceeds bound');
    if(item&&typeof item==='object')for(const child of Object.values(item))pending.push([child,depth+1]);}
  return value;
}
function validateBusiness31PrivateDescriptor(value){
  exact(value,['schemaVersion','documentType','profile','verifier','source','sourceManifestSha256',
    'approvalPointer','closurePointer','custody','bundleEncoding','expandedBytes',
    'membersSha256','relocationSha256','producerBindings','historicalBaseline'],'descriptor');
  need(value.schemaVersion===2&&value.documentType==='build31-business-backend-private-replay'&&value.profile===PROFILE,'business profile required; no route fallback');
  binding(value.verifier,'verifier');
  need(hex(value.sourceManifestSha256,64),'source manifest digest invalid');
  for(const [key,file]of Object.entries(FILES))pointer(value[key],file);
  same(value.historicalBaseline,HISTORICAL,'historical backend differs');
  need(value.source?.commit!==HISTORICAL.commit,'business source cannot equal historical deployment');
  const p=value.producerBindings;
  need(p&&typeof p==='object'&&!Array.isArray(p)&&Object.keys(p).length<=256&&
    CORE.every(file=>Object.hasOwn(p,file)),'complete business core producer population required');
  for(const [file,digest]of Object.entries(p))need(safeProducer(file)&&typeof digest==='string'&&/^[A-F0-9]{64}$/.test(digest),'producer identity invalid');
  // This is the reviewed local helper, never a path selected by the descriptor.
  require('./privateEvidenceBundle31.cjs').validateTransportDescriptor31(value,'business');
  return value;
}
// Identical pure tree algorithm from business31BackendAuthority.cjs.
function subtreeOid31(files, prefix) {
  const root = new Map();
  for (const [file, identity] of Object.entries(files)) {
    if (!file.startsWith(prefix + "/")) continue;
    const parts = file.slice(prefix.length + 1).split("/"); let node = root;
    parts.forEach((part, index) => {
      if (index === parts.length - 1) { need(!node.has(part), "tree collision"); node.set(part, identity); }
      else { if (!node.has(part)) node.set(part, new Map()); need(node.get(part) instanceof Map, "tree prefix collision"); node = node.get(part); }
    });
  }
  need(root.size > 0, "required source subtree absent");
  function tree(node) {
    const names = [...node.keys()].sort((a, b) => Buffer.compare(Buffer.from(a + (node.get(a) instanceof Map ? "/" : "")),
      Buffer.from(b + (node.get(b) instanceof Map ? "/" : ""))));
    const bytes = Buffer.concat(names.map(name => {
      const item = node.get(name), directory = item instanceof Map;
      return Buffer.concat([Buffer.from(`${directory ? "40000" : item.mode} ${name}\0`), Buffer.from(directory ? tree(item) : item.oid, "hex")]);
    }));
    return crypto.createHash("sha1").update(Buffer.from(`tree ${bytes.length}\0`)).update(bytes).digest("hex");
  }
  return tree(root);
}
function verifyBusiness31DescriptorPreparation({repositoryRoot,gitExecutable,gitSha256,envelope,descriptorPointer,expectedSourceManifestSha256}){
  const trusted=require('./business31TrustedInput.cjs');
  const boundary=trusted.verifyBusiness31TrustedInput({repositoryRoot,gitExecutable,gitSha256,envelope});
  pointer(descriptorPointer,DESCRIPTOR);
  const repository=trusted.openTrustedGitRepository31({repositoryRoot,gitExecutable,gitSha256});
  const V=repository.snapshot(envelope.verifier.commit),M=repository.snapshot(envelope.source.commit),S=repository.snapshot(envelope.candidate.commit);
  function committed(p){
    repository.requireAncestor(M.commit,p.commit); repository.requireAncestor(p.commit,S.commit);
    const at=repository.snapshot(p.commit);
    need(at.files[p.file]?.mode==='100644'&&S.files[p.file]?.mode==='100644','pointer requires regular immutable metadata');
    const bytes=repository.readBlob(p.commit,p.file);
    need(sha(bytes)===p.sha256&&sha(repository.readBlob(S.commit,p.file))===p.sha256,'pointer bytes differ or changed in candidate');
    return bytes;
  }
  const descriptorBytes=committed(descriptorPointer),d=validateBusiness31PrivateDescriptor(json(descriptorBytes));
  same(d.verifier,{commit:V.commit,tree:V.tree},'descriptor verifier differs from externally supplied envelope');
  need(typeof expectedSourceManifestSha256==='string'&&/^[A-F0-9]{64}$/.test(expectedSourceManifestSha256)&&
    d.sourceManifestSha256===expectedSourceManifestSha256,'independently supplied source manifest differs');
  need(d.source.functionsTree===subtreeOid31(M.files,'functions'),'actual functions tree differs');
  need(M.files[HISTORICAL.file]?.mode==='100644'&&S.files[HISTORICAL.file]?.mode==='100644'&&
    sha(repository.readBlob(M.commit,HISTORICAL.file))===HISTORICAL.sha256&&
    sha(repository.readBlob(S.commit,HISTORICAL.file))===HISTORICAL.sha256,'historical closure bytes differ');
  need(d.approvalPointer.commit!==M.commit&&d.closurePointer.commit!==d.approvalPointer.commit&&
    descriptorPointer.commit!==d.closurePointer.commit,'custody steps must be distinct');
  repository.requireAncestor(d.approvalPointer.commit,d.closurePointer.commit);
  repository.requireAncestor(d.closurePointer.commit,descriptorPointer.commit);
  function custodyDelta(before,after,file){
    const changed=[...new Set([...Object.keys(before.files),...Object.keys(after.files)])]
      .filter(p=>!isDeepStrictEqual(before.files[p],after.files[p])).sort();
    same(changed,[file],'custody delta must change only its exact named record');
  }
  custodyDelta(M,repository.snapshot(d.approvalPointer.commit),FILES.approvalPointer);
  custodyDelta(repository.snapshot(d.approvalPointer.commit),repository.snapshot(d.closurePointer.commit),FILES.closurePointer);
  custodyDelta(repository.snapshot(d.closurePointer.commit),repository.snapshot(descriptorPointer.commit),DESCRIPTOR);

  need(d.source.commit===M.commit&&d.source.tree===M.tree,'descriptor source differs');
  const files=Object.keys(M.files).filter(producer).sort();
  same(Object.keys(d.producerBindings).sort(),files,'descriptor must bind complete release producer population');
  same(Object.keys(envelope.verifier.files).sort(),files,'external verifier binding must cover complete release producer population');
  for(const file of files){
    need(M.files[file].mode==='100644'&&isDeepStrictEqual(V.files[file],M.files[file])&&isDeepStrictEqual(M.files[file],S.files[file]),'producer changed between V/M/S');
    const digest=d.producerBindings[file];
    need(sha(repository.readBlob(V.commit,file))===digest&&envelope.verifier.files[file]===digest,'producer digest differs');
  }
  for(const file of [SELF,'tools/release/business31TrustedInput.cjs','tools/release/privateEvidenceBundle31.cjs']){
    const local=path.join(__dirname,path.basename(file)),stat=fs.lstatSync(local);
    need(stat.isFile()&&!stat.isSymbolicLink()&&sha(fs.readFileSync(local))===d.producerBindings[file],'executing preparation helper differs');
  }
  const pointerDigests={};
  for(const [key,file]of Object.entries(FILES)){
    const bytes=committed(d[key]); json(bytes); pointerDigests[key]={file,sha256:sha(bytes),bytes:bytes.length};
  }
  need(repository.readRef(envelope.candidate.ref)===S.commit,'candidate moved during descriptor checks');
  return Object.freeze({schemaVersion:1,profile:PROFILE,source:structuredClone(d.source),
    verifierCommit:V.commit,candidateCommit:S.commit,descriptorSha256:sha(descriptorBytes),
    pointerDigests,producerCount:files.length,inputBoundaryVerified:boundary.inputBoundaryVerified,
    descriptorStructureVerified:true,pointerBytesVerified:true,
    functionsTreeVerified:true,historicalClosureBytesVerified:true,sourceManifestCommitmentJoined:true,
    metadataSemanticsVerified:false,platformIdentityAuthenticated:false,
    ownerAuthenticated:false,privateReplayVerified:false,credentialAccessAuthorized:false,
    deploymentAuthorized:false,constructionAuthorized:false,distributionAuthorized:false});
}
module.exports={PROFILE,SELF,DESCRIPTOR,FILES,HISTORICAL,CORE,producer,sha,json,validateBusiness31PrivateDescriptor,verifyBusiness31DescriptorPreparation};
