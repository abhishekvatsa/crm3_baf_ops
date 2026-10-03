'use strict';

// Exact generation download plus full replay; a PASS attestation is insufficient.
// No credential is created here. Without an already-authorized read token this
// route fails before construction. Raw evidence and diagnostics are never printed.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {isDeepStrictEqual} = require('node:util');
const PROFILE = 'build31-exact-grpc-runtime-backend-v1';
const CLIENT = 'release/approvals/build31-runtime-client-compatibility-approval.json';
const DESCRIPTOR = 'release/evidence/build31-runtime-private-replay.json';
const BUCKET = 'crm3-baf-ops-b8638-firestore-restore';
const MAX_BUNDLE = 512 * 1024 * 1024;
const MAX_MEMBERS = 50000;
const MAX_EXPANDED = 1024 * 1024 * 1024;
const MAX_MEMBER = 128 * 1024 * 1024;
const BUNDLE_ENCODING = 'gzip-members-v1';
const CORE_PRODUCERS = Object.freeze([
  'backendRuntimeAdmission31.cjs','backendRuntimeProof31.cjs','backendRuntimeReadbacks31.cjs',
  'backendRuntimeClosure31.cjs','backendRuntimeControls31.cjs','backendRuntimeExecution31.cjs',
  'closure-preflight31.cjs','clientRuntimeCompatibility31.cjs',
  'backendRuntimeExecutionAdmission31.cjs','executeBackendRuntime31.cjs',
  'captureBackendRuntimePreparedInputs31.cjs','runtimeDeploymentTransportGuard31.cjs',
  'backendRuntimeClosedReplay31.cjs','backendRuntimeEvidenceAccess31.cjs',
  'runtimeBackendPrivateReplay31.cjs','privateEvidenceBundle31.cjs','clientBackendCompatibility31.js','runtimePilotAuthority31.cjs',
  'stagedPromotionSourceAuthority.js','collectFunctionFleetRuntimeIdentityReadback.js',
  'collectFunctionsIamDependenciesReadback.js','collectFirestoreRulesIndexesReadback.js',
  'reviewedBackendControls.js','collectProductionGlobalPullBackend.js',
  'scopedCallableInvokerIam.js','deploymentFleetContract.js',
  'Production-AppCheckPolicy.ps1','Runtime-BackendPrivateReplay31.ps1',
  'Test-ProductionReleasePolicy.ps1','New-ProductionArtifact.ps1',
  'Test-ProductionReleaseManifest.ps1','collectDistributionInstallationReadback.js',
].map(file=>'tools/release/'+file));
const HISTORICAL = Object.freeze({commit:'2aa30de56cfdb960da3eeefd8956d8cbbae57b46',
  file:'release/evidence/build30-current-source-backend-deployment-closure.json',
  sha256:'3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45'});
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(value, message) { if (!value) throw new Error(message); }
function same(a,b,message) { need(isDeepStrictEqual(a,b),message); }
function keys(value,names,label) {
  need(value && typeof value==='object' && !Array.isArray(value),label+' must be an object');
  same(Object.keys(value).sort(),[...names].sort(),label+' fields differ');
}
function canonical(value) {
  if (Array.isArray(value)) return '['+value.map(canonical).join(',')+']';
  if (value && typeof value==='object') return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
  return JSON.stringify(value);
}
function relative(value) {
  need(typeof value==='string' && value.length<=400 && /^[A-Za-z0-9_@+.~/-]+$/.test(value) &&
    !value.startsWith('/') && value.split('/').every(p=>p && p!=='.' && p!=='..' &&
      !/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)), 'Unsafe portable member path');
  return value;
}
function pointer(value,file) {
  keys(value,['commit','file','sha256'],'Immutable pointer');
  need(/^[a-f0-9]{40}$/.test(value.commit) && /^[A-F0-9]{64}$/.test(value.sha256) && value.file===file,
    'Exact immutable pointer differs');
}
function routeSelected(policy) {
  const pointer = policy?.clientBackendCompatibility;
  return pointer?.file===CLIENT || policy?.runtimeBackendPrivateReplay!==undefined ||
    pointer?.profile===PROFILE;
}
function validateDescriptor(value) {
  keys(value,['schemaVersion','documentType','profile','source','approvalPointer','closurePointer',
    'clientPointer','custody','bundleEncoding','expandedBytes','membersSha256','relocationSha256','producerBindings','historicalBaseline'],'Private replay descriptor');
  need(value.schemaVersion===2 && value.bundleEncoding===BUNDLE_ENCODING &&
    Number.isSafeInteger(value.expandedBytes) && value.expandedBytes>=0 && value.expandedBytes<=MAX_EXPANDED && value.documentType==='build31-runtime-backend-private-replay' && value.profile===PROFILE,
    'Unsupported runtime replay descriptor');
  keys(value.source,['commit','tree','functionsTree'],'Source');
  for (const hash of Object.values(value.source)) need(/^[a-f0-9]{40}$/.test(hash),'Invalid immutable source identity');
  pointer(value.approvalPointer,'release/approvals/build31-runtime-backend-deployment-approval.json');
  pointer(value.closurePointer,'release/evidence/build31-runtime-backend-deployment-closure.json');
  pointer(value.clientPointer,CLIENT);
  keys(value.custody,['provider','bucket','objectName','generation','bytes','sha256'],'Private custody');
  const c=value.custody;
  need(c.provider==='gcs' && c.bucket===BUCKET &&
    new RegExp('^release-custody/build-31/runtime-backend/'+value.source.commit+'/[A-Za-z0-9][A-Za-z0-9._-]{0,127}/private-replay-bundle\\.json$').test(c.objectName) &&
    typeof c.generation==='string' && /^[1-9][0-9]*$/.test(c.generation) && Number.isSafeInteger(c.bytes) && c.bytes>0 && c.bytes<=MAX_BUNDLE &&
    /^[A-F0-9]{64}$/.test(c.sha256), 'Private custody must name one bounded exact generation');
  for (const key of ['membersSha256','relocationSha256']) need(/^[A-F0-9]{64}$/.test(value[key]),'Invalid bundle commitment');
  need(value.producerBindings && typeof value.producerBindings==='object' && !Array.isArray(value.producerBindings) &&
    Object.keys(value.producerBindings).length>0,'Source-bound producer inventory required');
  for (const [file,digest] of Object.entries(value.producerBindings)) {
    relative(file); need((/^tools\/release\/.+\.(?:js|cjs|ps1)$/.test(file) ||
      file==='tools/v4/v4_2_r1_canonical_audit.py') && /^[A-F0-9]{64}$/.test(digest),'Invalid source-bound producer');
  }
  need([...CORE_PRODUCERS,'tools/v4/v4_2_r1_canonical_audit.py'].every(file=>Object.hasOwn(value.producerBindings,file)),
    'Complete runtime entrypoint producer set is required');
  same(value.historicalBaseline,HISTORICAL,'Historical backend baseline cannot be rewritten');
  return value;
}
// Load the shared helper only after profile validation. The repository entrypoint
// checks its complete source-bound producer inventory before calling download.
function verifyBundleBytes(bytes,descriptor) {
  validateDescriptor(descriptor);
  return require('./privateEvidenceBundle31.cjs').verifyBundleBytes31(bytes,descriptor,'runtime');
}
function extractVerifiedBundle(bytes,descriptor,destination) {
  validateDescriptor(descriptor);
  return require('./privateEvidenceBundle31.cjs').extractVerifiedBundle31(bytes,descriptor,destination,'runtime');
}
async function downloadExactGeneration(descriptor,token) {
  validateDescriptor(descriptor);
  return require('./privateEvidenceBundle31.cjs').downloadExactGeneration31(descriptor,token,'runtime');
}
function safeGitEnvironment31(root) {
  const dot=path.join(root,'.git');
  need(fs.lstatSync(dot).isDirectory() && !fs.lstatSync(dot).isSymbolicLink(), 'Runtime31 requires a regular local Git directory');
  for(const name of ['commondir','gitdir','objects/info/alternates','info/grafts']) need(!fs.existsSync(path.join(dot,name)), 'Runtime31 Git cannot redirect to external state');
  const config=path.join(dot,'config');
  if(fs.existsSync(config)) need(!/^\s*\[\s*(?:include(?:If)?|filter|diff)\b/im.test(fs.readFileSync(config,'utf8')) &&
    !/^\s*worktree\s*=/im.test(fs.readFileSync(config,'utf8')),
    'Executable or external Git configuration is not admitted');
  const env=Object.fromEntries(Object.entries(process.env).filter(([key])=>!/^GIT_/i.test(key)));
  Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null',
    GIT_TERMINAL_PROMPT:'0',GIT_PAGER:'cat',GIT_OPTIONAL_LOCKS:'0'});
  const settings={'core.longpaths':'true','core.fsmonitor':'false','core.hooksPath':path.join(dot,'crm31-disabled-hooks'),
    'core.untrackedCache':'false','core.preloadIndex':'false','diff.external':'','credential.helper':'','protocol.allow':'never'};
  env.GIT_CONFIG_COUNT=String(Object.keys(settings).length);
  Object.entries(settings).forEach(([key,value],index)=>{env['GIT_CONFIG_KEY_'+index]=key;env['GIT_CONFIG_VALUE_'+index]=value;});
  return env;
}
function git(root,args) { return execFileSync('git',['--no-replace-objects','--no-pager','--no-optional-locks','-C',root,...args],
  {windowsHide:true,stdio:['ignore','pipe','pipe'],maxBuffer:128*1024*1024,env:safeGitEnvironment31(root)}); }
function readCommitted(root,p,fixedFile) {
  pointer(p,fixedFile);const raw=git(root,['show',p.commit+':'+p.file]);
  need(sha(raw)===p.sha256,'Immutable public proof pointer differs');return JSON.parse(raw.toString('utf8'));
}
function validateCurrentBackend(value,descriptor,descriptorSha256) {
  keys(value,['source','approvalPointer','closurePointer','completedAtUtc','recordedAtUtc',
    'fleet','preserved','appCheck','rawProofCommitment'],'Sanitized current backend');
  same(value.source,descriptor.source,'Current backend source differs');
  same(value.approvalPointer,descriptor.approvalPointer,'Current backend approval differs');
  same(value.closurePointer,descriptor.closurePointer,'Current backend closure differs');
  same(value.fleet,{callables:13,events:5,schedulers:1,total:19},'Current backend fleet differs');
  same(value.preserved,{rules:true,indexes:true,iam:true,enforcement:true,businessLogic:true},'Preserved controls differ');
  same(value.appCheck,{clientRequired:true,androidProvider:'playIntegrity',mutatingEnforcementChanged:false},'App Check scope differs');
  same(value.rawProofCommitment,{descriptorSha256,membersSha256:descriptor.membersSha256,
    relocationSha256:descriptor.relocationSha256},'Raw replay commitments differ');
  for(const date of [value.completedAtUtc,value.recordedAtUtc]) need(typeof date==='string' &&
    /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?Z$/.test(date) && Number.isFinite(Date.parse(date)) &&
    Date.parse(date)<=Date.now(),'Backend chronology must be explicit completed UTC');
  need(Date.parse(value.completedAtUtc)<=Date.parse(value.recordedAtUtc),'Backend closure predates completion');
  return value;
}
async function verifyRuntime31RepositoryAuthority({repoRoot,releasePolicy}) {
  need(routeSelected(releasePolicy),'Runtime route was not selected');
  need(releasePolicy.release?.buildNumber===31 && releasePolicy.versionPolicy?.buildNumber===31 &&
    releasePolicy.clientBackendCompatibility?.file===CLIENT,'Runtime route cannot change generation or fall back');
  const root=fs.realpathSync(repoRoot),policyBytes=fs.readFileSync(path.join(root,'release/production-release-policy.json'));
  need(fs.realpathSync(git(root,['rev-parse','--show-toplevel']).toString('utf8').trim())===root,
    'Replay repository must be the actual Git top-level');
  need(git(root,['status','--porcelain=v1','--untracked-files=all']).toString('utf8').trim()==='',
    'Replay repository must be clean');
  same(JSON.parse(policyBytes),releasePolicy,'Loaded policy differs from repository');
  const versionPointer=releasePolicy.versionPolicy;
  relative(versionPointer.sourceDocumentFile);
  const versionBytes=fs.readFileSync(path.join(root,versionPointer.sourceDocumentFile));
  need(sha(versionBytes)===versionPointer.sourceDocumentSha256.toUpperCase(),'Version source digest differs');
  const version=JSON.parse(versionBytes);
  same(version.requiredSource?.runtimeBackendPrivateReplay,releasePolicy.runtimeBackendPrivateReplay,'Version and policy private proof differ');
  same(version.requiredSource?.clientBackendCompatibility,releasePolicy.clientBackendCompatibility,'Version and policy client decision differ');
  need(releasePolicy.appCheckBuild?.clientEnabled===true && releasePolicy.appCheckBuild?.androidProvider==='playIntegrity' &&
    releasePolicy.appCheckBuild?.approvalFile==='release/approvals/build31-app-check-client-approval.json' &&
    /^[A-F0-9]{64}$/.test(releasePolicy.appCheckBuild?.approvalSha256??''),
    'Runtime31 requires the actual source-bound enabled Play Integrity choice');
  const descriptor=validateDescriptor(readCommitted(root,releasePolicy.runtimeBackendPrivateReplay,DESCRIPTOR));
  same(descriptor.clientPointer,releasePolicy.clientBackendCompatibility,'Private replay selects another client decision');
  const signingCommit=git(root,['rev-parse','HEAD']).toString('utf8').trim();
  need(sha(git(root,['show',signingCommit+':release/production-release-policy.json']))===sha(policyBytes) &&
    sha(git(root,['show',signingCommit+':'+versionPointer.sourceDocumentFile]))===sha(versionBytes),
    'Policy/version source differs from immutable signing source');
  git(root,['merge-base','--is-ancestor',descriptor.source.commit,signingCommit]);
  git(root,['merge-base','--is-ancestor',releasePolicy.runtimeBackendPrivateReplay.commit,signingCommit]);
  const sourceEntries={};
  sourceEntries['release/production-release-policy.json']=policyBytes;
  sourceEntries[versionPointer.sourceDocumentFile]=versionBytes;
  const appCheckFile=releasePolicy.appCheckBuild.approvalFile;
  const appCheckRaw=git(root,['show',signingCommit+':'+appCheckFile]);
  need(sha(appCheckRaw)===releasePolicy.appCheckBuild.approvalSha256 &&
    sha(fs.readFileSync(path.join(root,appCheckFile)))===sha(appCheckRaw),'App Check approval source bytes differ');
  const appCheck=JSON.parse(appCheckRaw);
  need(appCheck.schemaVersion===1 && appCheck.documentType==='governed-app-check-client-build-approval' &&
    appCheck.approved===true && appCheck.intendedBuildNumber===31 &&
    appCheck.releaseId===releasePolicy.release.releaseId && appCheck.reservationId===releasePolicy.versionPolicy.reservationId &&
    appCheck.clientEnabled===true && appCheck.androidProvider==='playIntegrity' &&
    appCheck.backendSourceCommit===descriptor.source.commit && appCheck.backendReceiptSha256===descriptor.closurePointer.sha256 &&
    appCheck.enforcementChangeAuthorized===false && appCheck.serverEnforcementAtBuild===false,
    'Actual App Check source-specific decision differs from replayed runtime source');
  same(appCheck.serverEnforcementScopesAtBuild,{defaultMutatingEnforced:false,identityCallable:'getBackendReleaseIdentity',
    identityCallableEnforced:true,identitySourceFile:'functions/src/stage2dSecurityConfig.ts',
    identitySourceSha256:'1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F'},
    'Actual App Check enforcement scopes differ');
  sourceEntries[appCheckFile]=appCheckRaw;
  const expectedProducers=git(root,['ls-tree','-r','--name-only',descriptor.source.commit,'--','tools/release','tools/v4/v4_2_r1_canonical_audit.py'])
    .toString('utf8').trim().split(/\r?\n/).filter(file=>/^tools\/release\/.+\.(?:js|cjs|ps1)$/.test(file)||file==='tools/v4/v4_2_r1_canonical_audit.py').sort();
  same(Object.keys(descriptor.producerBindings).sort(),expectedProducers,'Executing producer inventory must cover the complete immutable release-tool population');
  for (const [file,digest] of Object.entries(descriptor.producerBindings)) {
    const atSource=git(root,['show',descriptor.source.commit+':'+file]);
    const atSigning=git(root,['show',signingCommit+':'+file]);
    const local=path.join(root,file);need(fs.lstatSync(local).isFile()&&!fs.lstatSync(local).isSymbolicLink(),'Verifier is not a regular file');
    need(sha(atSource)===digest && sha(atSigning)===digest && sha(fs.readFileSync(local))===digest,'Verifier source/loaded bytes differ');
    sourceEntries[file]=atSigning;
  }
  const descriptorRaw=git(root,['show',releasePolicy.runtimeBackendPrivateReplay.commit+':'+DESCRIPTOR]);
  need(sha(descriptorRaw)===releasePolicy.runtimeBackendPrivateReplay.sha256,'Descriptor bytes changed');
  need(sha(git(root,['show',signingCommit+':'+DESCRIPTOR]))===sha(descriptorRaw) &&
    sha(fs.readFileSync(path.join(root,DESCRIPTOR)))===sha(descriptorRaw),'Signing descriptor differs from immutable custody');
  sourceEntries[DESCRIPTOR]=descriptorRaw;
  const required=['tools/release/runtimeBackendPrivateReplay31.cjs','tools/release/backendRuntimeClosedReplay31.cjs'];
  need(required.every(file=>Object.hasOwn(sourceEntries,file)),'Required replay verifier is not source-bound');
  need(sha(fs.readFileSync(__filename))===descriptor.producerBindings[required[0]],'Executing transport differs from source');
  const downloaded=await downloadExactGeneration(descriptor,process.env.CRM3_RUNTIME31_EVIDENCE_ACCESS_TOKEN);
  if(process.env.CRM3_RUNTIME31_PRIVATE_BUNDLE){
    const supplied=process.env.CRM3_RUNTIME31_PRIVATE_BUNDLE;
    need(path.isAbsolute(supplied)&&fs.lstatSync(supplied).isFile()&&!fs.lstatSync(supplied).isSymbolicLink(),'Supplied bundle must be an absolute regular file');
    need(sha(fs.readFileSync(supplied))===sha(downloaded),'Supplied bundle differs from authenticated generation');
  }
  const parent=fs.mkdtempSync(path.join(os.tmpdir(),'crm3-runtime31-private-'));
  const extracted=extractVerifiedBundle(downloaded,descriptor,path.join(parent,'evidence'));
  const replay=require(path.join(root,required[1])).verifyClosedRuntimeClientChain31;
  need(typeof replay==='function','Closed-chain replay API unavailable');
  const proof=await replay({repositoryRoot:root,sourceEntries,descriptor,privateBundleRoot:extracted.root,
    relocation:extracted.relocation,nowUtc:new Date().toISOString()});
  need(proof?.ok===true && proof.deploymentAuthorized===false && proof.constructionAuthority===false &&
    proof.distributionAuthorized===false,'Private chain replay did not verify exact closed authority');
  same(proof.source,descriptor.source,'Replayed source differs');
  same(proof.approvalPointer,descriptor.approvalPointer,'Replayed deployment approval differs');
  same(proof.closurePointer,descriptor.closurePointer,'Replayed closure differs');
  same(proof.clientPointer,descriptor.clientPointer,'Replayed client decision differs');
  same(proof.historicalBaseline,HISTORICAL,'Replayed historical backend differs');
  validateCurrentBackend(proof.currentBackend,descriptor,sha(descriptorRaw));
  const closure=readCommitted(root,descriptor.closurePointer,descriptor.closurePointer.file);
  keys(closure,['schemaVersion','documentType','recordKind','source','recordedAtUtc','privateRecord','summary'],'Public closure envelope');
  need(closure.schemaVersion===2 && closure.documentType==='build31-runtime-private-record-custody' &&
    closure.recordKind==='closure','Public closure envelope identity differs');
  same(closure.source,descriptor.source,'Public closure source differs');
  keys(closure.privateRecord,['file','sha256','bytes'],'Private closure record pointer');
  need(closure.privateRecord.file==='authority/closure.json' && /^[A-F0-9]{64}$/.test(closure.privateRecord.sha256) &&
    Number.isSafeInteger(closure.privateRecord.bytes) && closure.privateRecord.bytes>0,'Private closure logical identity differs');
  const {closurePointer,rawProofCommitment,...summary}=proof.currentBackend;
  same(closure.summary,summary,'Public closure summary differs from complete private replay');
  same(closure.recordedAtUtc,summary.recordedAtUtc,'Public closure timestamp differs');
  // Replay validated the privateRecord pointer against the original private bytes.
  // Recheck loaded source after replay as well as before it.
  for(const [file,digest] of Object.entries(descriptor.producerBindings))
    need(sha(fs.readFileSync(path.join(root,file)))===digest,'Executing producer changed during replay');
  // No raw member/path/credential field may cross this publication boundary.
  return {ok:true,route:'runtime-backend31',currentBackendReceiptFile:descriptor.closurePointer.file,
    currentBackendReceiptSha256:descriptor.closurePointer.sha256,candidateBackendReceiptFile:descriptor.closurePointer.file,
    candidateBackendReceiptSha256:descriptor.closurePointer.sha256,
    runtimeBackend31:{source:proof.source,approvalPointer:proof.approvalPointer,closurePointer:proof.closurePointer,
      clientPointer:proof.clientPointer,descriptorPointer:releasePolicy.runtimeBackendPrivateReplay,
      privateEvidenceReplayed:true,currentBackend:proof.currentBackend},
    clientBackendCompatibility:{file:descriptor.clientPointer.file,sha256:descriptor.clientPointer.sha256,
      commit:descriptor.clientPointer.commit,sourceCommit:descriptor.source.commit}};
}
function verifyRuntime31RepositoryAuthoritySync(args) {
  try {
    same(JSON.parse(fs.readFileSync(path.join(args.repoRoot,'release/production-release-policy.json'),'utf8').replace(/^\uFEFF/,'')),
      args.releasePolicy,'Caller policy differs from exact repository policy');
    const output=execFileSync(process.execPath,['--no-global-search-paths',__filename,'--repository',fs.realpathSync(args.repoRoot)],
      {windowsHide:true,stdio:['ignore','pipe','pipe'],maxBuffer:8*1024*1024,env:{...process.env,NODE_OPTIONS:'',NODE_PATH:''}});
    const proof=JSON.parse(output.toString('utf8'));need(proof.ok===true,'Private replay failed');return proof;
  } catch { return {ok:false,reasons:['Runtime31 source-bound private evidence replay failed; inspect authorized private diagnostics.'],constructionAuthority:false}; }
}
module.exports={BUNDLE_ENCODING,MAX_BUNDLE,MAX_EXPANDED,MAX_MEMBER,MAX_MEMBERS,PROFILE,CLIENT,DESCRIPTOR,HISTORICAL,CORE_PRODUCERS,routeSelected,validateDescriptor,validateCurrentBackend,verifyBundleBytes,
  extractVerifiedBundle,downloadExactGeneration,verifyRuntime31RepositoryAuthority,verifyRuntime31RepositoryAuthoritySync,safeGitEnvironment31,safeGitRead31:git,sha,canonical};
if(require.main===module){
  const [flag,root,...extra]=process.argv.slice(2);
  (async()=>{need(flag==='--repository'&&root&&extra.length===0,'Exact repository argument required');
    const releasePolicy=JSON.parse(fs.readFileSync(path.join(root,'release/production-release-policy.json'),'utf8').replace(/^\uFEFF/,''));
    const proof=await verifyRuntime31RepositoryAuthority({repoRoot:root,releasePolicy});process.stdout.write(JSON.stringify(proof)+'\n');
  })().catch(()=>{process.stderr.write('Runtime31 private replay failed; no authority granted.\n');process.exitCode=1;});
}
