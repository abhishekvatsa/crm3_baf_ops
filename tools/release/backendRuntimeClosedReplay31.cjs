'use strict';
// Historical, read-only replay. This module never grants deployment/distribution.
const fs=require('node:fs'),path=require('node:path');
const a=require('./backendRuntimeAdmission31.cjs'),access=require('./backendRuntimeEvidenceAccess31.cjs');
const {need,eq,hash,git,gtext,ancestor}=a.helpers;
const METADATA_PATHS=new Set(["README.md","release/production-release-policy.json","release/build-number-ledger.json","release/current-successor-state.json","release/approvals/version-policy-approval.json","release/approvals/build-number-31-successor-approval.json","release/approvals/build31-private-cloud-custody-approval.json","release/approvals/build31-app-check-client-approval.json","release/approvals/public-repository-environment-reviewer-approval-build-31.json","release/approvals/build31-runtime-backend-deployment-approval.json","release/approvals/build31-runtime-backend-owner-authorization.json","release/evidence/build31-runtime-backend-main-ci.json","release/evidence/build31-runtime-backend-main-security.json","release/evidence/build31-runtime-backend-local-proof.json","release/evidence/build31-runtime-backend-deployment-closure.json","release/approvals/build31-runtime-client-compatibility-approval.json","release/approvals/build31-runtime-client-owner-authorization.json","release/evidence/build31-runtime-private-replay.json"]);
const DESCRIPTOR='release/evidence/build31-runtime-private-replay.json';
const HISTORICAL={commit:a.BASELINE,file:'release/evidence/build30-current-source-backend-deployment-closure.json',sha256:'3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45'};
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
function inventory(root){const rows=[];function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);need(!entry.isSymbolicLink(),'Bundle symlinks forbidden');if(entry.isDirectory())walk(file);else{need(entry.isFile(),'Regular bundle members required');const raw=fs.readFileSync(file);rows.push({path:path.relative(root,file).split(path.sep).join('/'),bytes:raw.length,sha256:hash(raw)});}}}walk(root);return rows;}
function verifySourceSuccessor31(repositoryRoot,descriptor,sourceEntries){
  const root=fs.realpathSync(repositoryRoot);need(root===fs.realpathSync(gtext(root,['rev-parse','--show-toplevel'])),'Later-S replay needs an actual Git repository; archive-only ancestry is unavailable');
  const signing=gtext(root,['rev-parse','HEAD']);ancestor(root,descriptor.source.commit,signing);
  for(const pointer of [descriptor.approvalPointer,descriptor.closurePointer,descriptor.clientPointer]){ancestor(root,pointer.commit,signing);need(hash(git(root,['show',pointer.commit+':'+pointer.file]))===pointer.sha256,'Public custody pointer differs');}
  verifyMetadataOnlySuccessor31(root,descriptor.source.commit,signing);
  for(const [file,digest]of Object.entries(descriptor.producerBindings)){need(Buffer.isBuffer(sourceEntries[file])&&hash(sourceEntries[file])===digest&&hash(git(root,['show',descriptor.source.commit+':'+file]))===digest&&hash(git(root,['show',signing+':'+file]))===digest,'Loaded/archive M/S producer differs');}
  need(Buffer.isBuffer(sourceEntries[DESCRIPTOR]),'Exact descriptor Git bytes required');eq(JSON.parse(sourceEntries[DESCRIPTOR]),descriptor,'Descriptor was reserialized or substituted');
  eq(descriptor.historicalBaseline,HISTORICAL,'Historical backend identity differs');need(hash(git(root,['show',descriptor.source.commit+':'+HISTORICAL.file]))===HISTORICAL.sha256,'Historical closure changed');
  return {root,signing};
}
function verifyMetadataOnlySuccessor31(root,sourceCommit,signing){
 const changed=gtext(root,['diff','--name-only',sourceCommit,signing]).split(/\r?\n/).filter(Boolean);
 for(const file of changed){
  if(METADATA_PATHS.has(file)){const row=gtext(root,['ls-tree',signing,'--',file]);need(/^100644 blob [0-9a-f]{40}\t/.test(row),'Metadata must remain a present regular nonexecutable file: '+file);continue;}
  need(file==='pubspec.yaml','Later signing source changed reviewed source: '+file);
  need(/^100644 blob [0-9a-f]{40}\t/.test(gtext(root,['ls-tree',signing,'--',file])),'Pubspec must remain a regular nonexecutable file');
  const old=git(root,['show',sourceCommit+':'+file]).toString('utf8'),next=git(root,['show',signing+':'+file]).toString('utf8');
  const strip=raw=>{let count=0;const result=raw.replace(/^version:[ \t]*[^\r\n]+$/gm,()=>{count++;return 'version: <governed-release-version>';});need(count===1,'Exactly one pubspec release version required');return result;};
  need(strip(old)===strip(next),'Only the governed pubspec version may change after reviewed source');
 }
 return true;
}
function verifyClosedRuntimeClientChain31({repositoryRoot,sourceEntries,descriptor,privateBundleRoot,relocation,nowUtc=new Date().toISOString()}){
  const signing=verifySourceSuccessor31(repositoryRoot,descriptor,sourceEntries);
  const releasePolicy=JSON.parse(git(signing.root,['show',signing.signing+':release/production-release-policy.json']));
  const versionFile=releasePolicy.versionPolicy?.sourceDocumentFile;need(typeof versionFile==='string'&&/^release\/[A-Za-z0-9_./-]+\.json$/.test(versionFile)&&!versionFile.includes('..'),'Exact committed version document required');
  const versionRaw=git(signing.root,['show',signing.signing+':'+versionFile]);need(hash(versionRaw)===releasePolicy.versionPolicy.sourceDocumentSha256.toUpperCase(),'Actual signing version bytes differ');const version=JSON.parse(versionRaw);
  eq(releasePolicy.clientBackendCompatibility,descriptor.clientPointer,'Actual signing policy selects another client decision');
  const bundleRoot=fs.realpathSync(privateBundleRoot),members=inventory(bundleRoot),memberMap=Object.fromEntries(members.map(x=>[x.path,{bytes:x.bytes,sha256:x.sha256}]));
  need(hash(Buffer.from(canonical(memberMap)))===descriptor.membersSha256&&hash(Buffer.from(canonical(relocation)))===descriptor.relocationSha256,'Complete material/relocation commitment differs');
  eq(Object.keys(relocation.roles??{}).sort(),['authorityRoot','evidenceDirectory','executionRoot'],'Exact original replay roles required');
  const verifierFiles={};for(const name of a.PROPOSAL_FILES){const file=path.join(__dirname,name),digest=descriptor.producerBindings['tools/release/'+name];need(digest&&hash(fs.readFileSync(file))===digest,'Executing replay module differs');verifierFiles[fs.realpathSync(file)]=digest;}
  return access.runRelocated31({privateBundleRoot:bundleRoot,relocation,members,evidenceDirectory:relocation.roles.evidenceDirectory,verifierFiles},()=>{
    const repoRoot=relocation.roles.executionRoot,authorityRoot=relocation.roles.authorityRoot,evidenceDirectory=relocation.roles.evidenceDirectory;
    // Full object validation rejects tampered object files and external alternates.
    for(const original of new Set([repoRoot,authorityRoot])){const physical=access.resolveOriginal(original);need(!fs.existsSync(path.join(physical,'.git/objects/info/alternates'))&&!fs.existsSync(path.join(physical,'.git/info/grafts')),'Private Git roots must be self-contained');git(original,['fsck','--strict','--full','--no-reflogs','--no-dangling']);}
    const client=require('./clientRuntimeCompatibility31.cjs').verifyClientRuntimeCompatibility31({repoRoot,authorityRoot,evidenceDirectory,releasePolicy,version,nowUtc});
    eq(client.source,descriptor.source,'Replayed source differs');
    const closure=a.helpers.committed(authorityRoot,descriptor.closurePointer,a.PATHS.closure);
    eq(closure.approvalPointer,descriptor.approvalPointer,'Replayed approval differs');
    const currentBackend={source:client.source,approvalPointer:descriptor.approvalPointer,closurePointer:descriptor.closurePointer,completedAtUtc:closure.completedAtUtc,recordedAtUtc:closure.recordedAtUtc,fleet:{callables:13,events:5,schedulers:1,total:19},preserved:{rules:true,indexes:true,iam:true,enforcement:true,businessLogic:true},appCheck:{clientRequired:true,androidProvider:'playIntegrity',mutatingEnforcementChanged:false},rawProofCommitment:{descriptorSha256:hash(sourceEntries[DESCRIPTOR]),membersSha256:descriptor.membersSha256,relocationSha256:descriptor.relocationSha256}};
    return {ok:true,source:client.source,approvalPointer:descriptor.approvalPointer,closurePointer:descriptor.closurePointer,clientPointer:descriptor.clientPointer,currentBackend,historicalBaseline:HISTORICAL,deploymentAuthorized:false,constructionAuthority:false,distributionAuthorized:false};
  });
}
module.exports={verifyClosedRuntimeClientChain31,verifySourceSuccessor31,verifyMetadataOnlySuccessor31,inventory,canonical,HISTORICAL};
