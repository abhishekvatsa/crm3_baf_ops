'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {isDeepStrictEqual:same,TextDecoder}=require('node:util');
const PROFILE='build31-exact-business-backend-v2';
const SELF='tools/release/business31PrivateDescriptorV2.cjs';
const DESCRIPTOR='release/evidence/build31-business-private-replay.json';
const FILES=Object.freeze({approvalPointer:'release/approvals/build31-business-backend-deployment-approval.json',closurePointer:'release/evidence/build31-business-backend-deployment-closure.json'});
const HISTORICAL=Object.freeze({commit:'2aa30de56cfdb960da3eeefd8956d8cbbae57b46',file:'release/evidence/build30-current-source-backend-deployment-closure.json',sha256:'3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45'});
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const oid=v=>typeof v==='string'&&/^[a-f0-9]{40}$/.test(v);
const digest=v=>typeof v==='string'&&/^[A-F0-9]{64}$/.test(v);
function need(v,m){if(!v)throw Error('Business descriptor v2: '+m);}
function exact(v,keys,label){need(v&&typeof v==='object'&&!Array.isArray(v)&&[Object.prototype,null].includes(Object.getPrototypeOf(v))&&same(Object.keys(v).sort(),[...keys].sort()),label+' fields differ');}
function json(bytes){
 need(Buffer.isBuffer(bytes)&&bytes.length>0&&bytes.length<=2*1024*1024,'bounded metadata required');
 const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes)),pending=[[value,0]];let count=0;
 while(pending.length){const [v,d]=pending.pop();need(++count<=50000&&d<=32,'metadata complexity exceeded');if(v&&typeof v==='object')for(const item of Object.values(v))pending.push([item,d+1]);}
 return value;
}
function pointer(v,file){exact(v,['commit','file','sha256'],'pointer');need(oid(v.commit)&&v.file===file&&digest(v.sha256),'exact pointer required');}
function api(map){
 const file='tools/release/business31TrustedInputV2.cjs';need(map&&digest(map[file]),'trusted successor helper missing');
 const physical=path.resolve(__dirname,path.basename(file));let cursor=path.parse(physical).root;
 for(const part of physical.slice(cursor.length).split(path.sep).filter(Boolean)){cursor=path.join(cursor,part);need(!fs.lstatSync(cursor).isSymbolicLink(),'successor helper redirects');}
 need(fs.lstatSync(physical).isFile()&&sha(fs.readFileSync(physical))===map[file],'successor helper bytes differ');
 const trusted=require('./business31TrustedInputV2.cjs');
 trusted.bindLocal31(map,[SELF,'tools/release/business31PrivateDescriptor.cjs','tools/release/privateEvidenceBundle31V2.cjs']);
 return {trusted,legacy:require('./business31PrivateDescriptor.cjs'),transport:require('./privateEvidenceBundle31V2.cjs')};
}
function validateBusiness31PrivateDescriptorV2(d){
 exact(d,['schemaVersion','documentType','profile','verifier','coreVerifier','sourceIntegration','source','sourceManifestSha256',
  'approvalPointer','closurePointer','custody','bundleEncoding','expandedBytes','membersSha256','relocationSha256','producerBindings','historicalBaseline'],'descriptor');
 need(d.schemaVersion===3&&d.documentType==='build31-business-backend-private-replay'&&d.profile===PROFILE,'closed successor descriptor required');
 exact(d.verifier,['commit','tree'],'outer verifier');need(oid(d.verifier.commit)&&oid(d.verifier.tree)&&digest(d.sourceManifestSha256),'verifier/manifest identity invalid');
 const {trusted,transport}=api(d.producerBindings);
 trusted.validateVerifierPair31({...d.verifier,files:d.producerBindings},d.coreVerifier,d.source,d.sourceIntegration);
 for(const [key,file]of Object.entries(FILES))pointer(d[key],file);
 need(same(d.historicalBaseline,HISTORICAL)&&d.source.commit!==HISTORICAL.commit,'historical backend differs');
 transport.validateTransportDescriptorV2(d,'business');return d;
}
function verifyBusiness31DescriptorPreparationV2({repositoryRoot,gitExecutable,gitSha256,envelope,descriptorPointer,expectedSourceManifestSha256}){
 const {trusted,legacy}=api(envelope?.verifier?.files);
 const boundary=trusted.verifyBusiness31TrustedInputV2({repositoryRoot,gitExecutable,gitSha256,envelope});
 const repository=require('./business31TrustedInput.cjs').openTrustedGitRepository31({repositoryRoot,gitExecutable,gitSha256});
 const M=repository.snapshot(envelope.source.commit),V=repository.snapshot(envelope.verifier.commit),S=repository.snapshot(envelope.candidate.commit);
 pointer(descriptorPointer,DESCRIPTOR);
 function committed(p){
  repository.requireAncestor(M.commit,p.commit);repository.requireAncestor(p.commit,S.commit);
  const at=repository.snapshot(p.commit);need(at.files[p.file]?.mode==='100644'&&same(at.files[p.file],S.files[p.file]),'selected regular pointer changed');
  const bytes=repository.readBlob(p.commit,p.file);need(sha(bytes)===p.sha256,'selected pointer digest differs');return bytes;
 }
 const bytes=committed(descriptorPointer),d=validateBusiness31PrivateDescriptorV2(json(bytes));
 need(same(d.verifier,{commit:V.commit,tree:V.tree})&&same(d.producerBindings,envelope.verifier.files)&&same(d.coreVerifier,envelope.coreVerifier)&&same(d.sourceIntegration,envelope.sourceIntegration),'independent dual verifier/integration differs');
 need(d.source.commit===M.commit&&d.source.tree===M.tree&&d.source.functionsTree===legacy.subtreeOid31(M.files,'functions'),'recorded source differs');
 need(d.sourceManifestSha256===expectedSourceManifestSha256&&digest(expectedSourceManifestSha256),'independent manifest differs');
 need(M.files[HISTORICAL.file]?.mode==='100644'&&same(M.files[HISTORICAL.file],S.files[HISTORICAL.file])&&sha(repository.readBlob(M.commit,HISTORICAL.file))===HISTORICAL.sha256,'historical closure changed');
 function only(before,after,file){need(same([...new Set([...Object.keys(before.files),...Object.keys(after.files)])].filter(p=>!same(before.files[p],after.files[p])).sort(),[file]),'dedicated custody delta differs');}
 const A=repository.snapshot(d.approvalPointer.commit),C=repository.snapshot(d.closurePointer.commit),B=repository.snapshot(descriptorPointer.commit);
 need(new Set([M.commit,A.commit,C.commit,B.commit]).size===4,'distinct custody steps required');
 repository.requireAncestor(M.commit,A.commit);repository.requireAncestor(A.commit,C.commit);repository.requireAncestor(C.commit,V.commit);repository.requireAncestor(V.commit,B.commit);
 only(M,A,FILES.approvalPointer);only(A,C,FILES.closurePointer);only(V,B,DESCRIPTOR);
 const pointerDigests={};for(const [key,file]of Object.entries(FILES)){const raw=committed(d[key]);json(raw);pointerDigests[key]={file,sha256:sha(raw),bytes:raw.length};}
 need(repository.readRef(envelope.candidate.ref)===S.commit,'candidate moved');
 return Object.freeze({schemaVersion:2,profile:PROFILE,source:structuredClone(d.source),verifierCommit:V.commit,
  coreVerifier:{commit:M.commit,tree:M.tree},candidateCommit:S.commit,descriptorSha256:sha(bytes),pointerDigests,
  producerCount:Object.keys(d.producerBindings).length,coreProducerCount:Object.keys(d.coreVerifier.files).length,
  inputBoundaryVerified:boundary.inputBoundaryVerified,sourceIntegrationVerified:true,descriptorStructureVerified:true,pointerBytesVerified:true,
  functionsTreeVerified:true,historicalClosureBytesVerified:true,sourceManifestCommitmentJoined:true,metadataSemanticsVerified:false,
  platformIdentityAuthenticated:false,ownerAuthenticated:false,privateReplayVerified:false,credentialAccessAuthorized:false,
  deploymentAuthorized:false,constructionAuthorized:false,distributionAuthorized:false});
}
module.exports={PROFILE,SELF,DESCRIPTOR,FILES,HISTORICAL,json,sha,validateBusiness31PrivateDescriptorV2,verifyBusiness31DescriptorPreparationV2};
