'use strict';
// Explicit successor boundary. The recorded M verifier remains a separate,
// unchanged identity; an independently enrolled later verifier owns integration.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {isDeepStrictEqual:same,TextDecoder}=require('node:util');
const PROFILE='build31-business-trusted-input-v2';
const SELF='tools/release/business31TrustedInputV2.cjs';
// Closed client transport scope. Enrollment additionally fixes every actual blob.
// Deployment/runtime controls outside this list cannot enter via enrollment.
const INTEGRATION_PATHS=Object.freeze([
 '.github/workflows/business-private-replay.yml',
 'tools/v4/v4_2_r1_canonical_audit.py',
 ...[
 'BUILD31_RELEASE_PATH.md','business31PolicyResult.md','BUILD31_BUSINESS_BACKEND.md',
 'Initialize-Business31Controller.ps1','Initialize-Business31Controller.test.cjs',
 'Business-BackendPrivateReplay31.ps1','Production-AppCheckPolicy.ps1','Production-AppCheckPolicy.test.mjs',
 'Test-ProductionReleasePolicy.ps1','New-ProductionArtifact.ps1','Test-ProductionReleaseManifest.ps1',
 'business31CallerIntegration.test.cjs','privateEvidenceBundle31V2.cjs','privateEvidenceBundle31.test.cjs',
 'business31TrustedInputV2.cjs','business31PrivateDescriptorV2.cjs','business31OriginalPathReplayV2.cjs','business31CoreWorkerV2.cjs',
 'business31TransportV2.test.cjs','business31TrustedInputV2.test.cjs','business31OriginalPathReplayV2.test.cjs',
 'business31PrivateDescriptor.cjs','business31HostedProtocol.cjs','business31HostedProtocol.test.cjs',
 'business31HostedReplay.cjs','business31HostedReplay.test.cjs','business31HostedResult.cjs','business31HostedResult.test.cjs','business31HostedTransportV2.test.cjs',
 'business31HostedLauncher.py','business31HostedLauncher.test.cjs','business31HostedLauncher.test.py','test_business31_hosted_launcher.py',
 'business31HostedClient.cjs','business31HostedClient.test.cjs','business31ClientCustody.cjs','business31ClientCustody.test.cjs',
 'business31ClientPolicy.cjs','business31ClientPolicy.test.cjs','business31Controller.cjs','business31Controller.test.cjs',
 'business31Prerequisite.cjs','business31Prerequisite.test.cjs','business31PolicyResult.cjs','business31PolicyResult.test.cjs',
 'business31PolicyInvocation.cjs','business31PolicyInvocation.test.cjs','business31ClientRoute.test.cjs',
 'clientBackendCompatibility31.js','clientBackendCompatibility31.test.cjs',
 'fixtures/business31ClientPolicyFixture.cjs','fixtures/business31HostedFixture.cjs'
 ].map(file=>'tools/release/'+file)
]);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const oid=v=>typeof v==='string'&&/^[a-f0-9]{40}$/.test(v);
const digest=v=>typeof v==='string'&&/^[A-F0-9]{64}$/.test(v);
function need(v,m){if(!v)throw Error('Business input v2: '+m);}
function exact(v,keys,label){need(v&&typeof v==='object'&&!Array.isArray(v)&&[Object.prototype,null].includes(Object.getPrototypeOf(v))&&
 same(Object.keys(v).sort(),[...keys].sort()),label+' fields differ');}
function bindLocal31(map,files){
 for(const file of files){
  need(map&&digest(map[file]),'independently bound helper missing: '+file);
  const target=path.resolve(__dirname,path.basename(file));let cursor=path.parse(target).root;
  for(const part of target.slice(cursor.length).split(path.sep).filter(Boolean)){cursor=path.join(cursor,part);need(!fs.lstatSync(cursor).isSymbolicLink(),'helper redirects');}
  need(fs.lstatSync(target).isFile()&&sha(fs.readFileSync(target))===map[file],'bound helper bytes differ: '+file);
 }
}
function libraries(map){
 bindLocal31(map,[SELF,'tools/release/business31TrustedInput.cjs','tools/release/business31PrivateDescriptor.cjs','tools/release/business31OriginalPathReplay.cjs']);
 return {legacy:require('./business31TrustedInput.cjs'),producer:require('./business31PrivateDescriptor.cjs').producer,
  CLOSURE_PRODUCERS:require('./business31OriginalPathReplay.cjs').CLOSURE_PRODUCERS};
}
function validateVerifierPair31(verifier,coreVerifier,source,sourceIntegration){
 const {legacy,producer,CLOSURE_PRODUCERS}=libraries(verifier?.files);
 for(const [v,label]of [[verifier,'outer verifier'],[coreVerifier,'core verifier']]){
  exact(v,['commit','tree','files'],label);need(oid(v.commit)&&oid(v.tree),label+' identity invalid');
  need(v.files&&typeof v.files==='object'&&!Array.isArray(v.files)&&Object.keys(v.files).length>0&&Object.keys(v.files).length<=256,label+' population invalid');
  for(const [file,hash]of Object.entries(v.files))need(producer(file)&&!file.split('/').some(p=>!p||p==='.'||p==='..')&&digest(hash),label+' member invalid');
 }
 need(coreVerifier.commit===source.commit&&coreVerifier.tree===source.tree&&verifier.commit!==coreVerifier.commit,'distinct outer and recorded M required');
 need(sourceIntegration&&typeof sourceIntegration==='object'&&!Array.isArray(sourceIntegration)&&Object.keys(sourceIntegration).length>0&&Object.keys(sourceIntegration).length<=256,'finite exact integration required');
 for(const [file,value]of Object.entries(sourceIntegration)){
  exact(value,['mode','oid','sha256'],'integration member');
  need(integrationPath(file,legacy,CLOSURE_PRODUCERS)&&value.mode==='100644'&&oid(value.oid)&&digest(value.sha256),'integration member invalid');
 }
 return true;
}
function integrationPath(file,legacy,CLOSURE_PRODUCERS){
 return typeof file==='string'&&/^[A-Za-z0-9_+./-]+$/.test(file)&&file.split('/').every(p=>p&&p!=='.'&&p!=='..')&&
  !legacy.METADATA_PATHS.includes(file)&&!CLOSURE_PRODUCERS.includes(file)&&
  INTEGRATION_PATHS.includes(file);
}
function createTrustedEnvelopeV2(trust,candidate){
 need(trust.schemaVersion===2&&trust.profile==='build31-business-hosted-recorded-replay-v2','closed hosted v2 trust required');
 const source={commit:trust.source.commit,tree:trust.source.tree};
 validateVerifierPair31(trust.verifier,trust.coreVerifier,source,trust.sourceIntegration);
 return {schemaVersion:2,profile:PROFILE,verifier:trust.verifier,coreVerifier:trust.coreVerifier,sourceIntegration:trust.sourceIntegration,
  source,candidate:{commit:candidate.commit,tree:candidate.tree,ref:'refs/heads/business31-admitted-'+candidate.commit}};
}
function verifyBusiness31TrustedInputV2({repositoryRoot,gitExecutable,gitSha256,envelope}){
 exact(envelope,['schemaVersion','profile','verifier','coreVerifier','sourceIntegration','source','candidate'],'envelope');
 need(envelope.schemaVersion===2&&envelope.profile===PROFILE,'explicit successor profile required');
 exact(envelope.source,['commit','tree'],'source');exact(envelope.candidate,['commit','tree','ref'],'candidate');
 need([envelope.source.commit,envelope.source.tree,envelope.candidate.commit,envelope.candidate.tree].every(oid),'source/candidate identity invalid');
 validateVerifierPair31(envelope.verifier,envelope.coreVerifier,envelope.source,envelope.sourceIntegration);
 const {legacy,producer,CLOSURE_PRODUCERS}=libraries(envelope.verifier.files);
 const repo=legacy.openTrustedGitRepository31({repositoryRoot,gitExecutable,gitSha256});
 const before=repo.readRef(envelope.candidate.ref),M=repo.snapshot(envelope.source.commit),V=repo.snapshot(envelope.verifier.commit),S=repo.snapshot(envelope.candidate.commit);
 need(before===S.commit&&M.tree===envelope.source.tree&&V.tree===envelope.verifier.tree&&S.tree===envelope.candidate.tree,'declared tree/ref differs');
 need(M.parents.length===2,'recorded M must be a normal merge');repo.requireAncestor(M.commit,V.commit);repo.requireAncestor(V.commit,S.commit);
 const all=new Set([...Object.keys(M.files),...Object.keys(V.files)]);
 const integrated=[...all].filter(file=>!same(M.files[file],V.files[file])&&file!=='pubspec.yaml'&&!legacy.METADATA_PATHS.includes(file)).sort();
 need(same(integrated,Object.keys(envelope.sourceIntegration).sort()),'integration must exactly equal enrolled M-to-V source delta');
 for(const file of integrated){
  const identity=V.files[file];need(integrationPath(file,legacy,CLOSURE_PRODUCERS)&&identity?.mode==='100644'&&(!M.files[file]||M.files[file].mode==='100644'),'integration source/mode refused');
  need(same(envelope.sourceIntegration[file],{mode:identity.mode,oid:identity.oid,sha256:sha(repo.readBlob(V.commit,file))})&&same(S.files[file],identity),'integration object/hash changed in V/S');
 }
 for(const file of CLOSURE_PRODUCERS)need(same(M.files[file],V.files[file])&&same(M.files[file],S.files[file]),'recorded core changed: '+file);
 for(const [snapshot,map,label]of [[M,envelope.coreVerifier.files,'recorded core'],[V,envelope.verifier.files,'outer']]){
  const files=Object.keys(snapshot.files).filter(producer).sort();need(same(files,Object.keys(map).sort()),label+' complete producer population differs');
  for(const file of files)need(snapshot.files[file].mode==='100644'&&sha(repo.readBlob(snapshot.commit,file))===map[file],label+' producer digest/mode differs: '+file);
 }
 for(const [file,hash]of Object.entries(envelope.verifier.files))need(same(V.files[file],S.files[file]),'outer producer changed in S: '+file);
 need(envelope.verifier.files[SELF]===sha(fs.readFileSync(__filename)),'executing successor bootstrap differs');
 const changed=[];
 for(const file of new Set([...Object.keys(M.files),...Object.keys(S.files)])){
  if(same(M.files[file],S.files[file]))continue;
  need(S.files[file]?.mode==='100644'&&(!M.files[file]||M.files[file].mode==='100644'),'deletion/mode change refused');
  if(Object.hasOwn(envelope.sourceIntegration,file)){need(same(V.files[file],S.files[file]),'integration differs');}
  else if(file==='pubspec.yaml'){
   const decoder=new TextDecoder('utf-8',{fatal:true}),old=decoder.decode(repo.readBlob(M.commit,file)),next=decoder.decode(repo.readBlob(S.commit,file));
   const version=/^version: [0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\+[0-9]+\r?$/gm;
   const a=old.match(version),b=next.match(version);need(a?.length===1&&b?.length===1&&/\+31\r?$/.test(b[0])&&old.replace(version,'version: <bound>')===next.replace(version,'version: <bound>'),'version-only Build31 delta required');
  }else need(legacy.METADATA_PATHS.includes(file),'unapproved source delta: '+file);
  changed.push(file);
 }
 need(repo.readRef(envelope.candidate.ref)===before,'candidate ref changed');
 return Object.freeze({schemaVersion:2,profile:PROFILE,sourceCommit:M.commit,sourceTree:M.tree,verifierCommit:V.commit,
  coreVerifier:{commit:M.commit,tree:M.tree},candidateCommit:S.commit,candidateTree:S.tree,changedPaths:changed.sort(),
  inputBoundaryVerified:true,sourceIntegrationVerified:true,platformIdentityAuthenticated:false,privateReplayVerified:false,
  deploymentAuthorized:false,constructionAuthorized:false});
}
module.exports={PROFILE,SELF,INTEGRATION_PATHS,createTrustedEnvelopeV2,validateVerifierPair31,verifyBusiness31TrustedInputV2,bindLocal31};
