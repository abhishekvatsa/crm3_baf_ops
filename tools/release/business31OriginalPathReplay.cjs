'use strict';
// PRIVATE OFFLINE PROPOSAL. Local recorded semantics only; never hosted or operational authority.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const {isDeepStrictEqual} = require('node:util');
const SELF = 'tools/release/business31OriginalPathReplay.cjs';
const PREFIX = 'Business original-path replay: ';
function portableMember(value) {
  need(typeof value==='string' && value.length<=400 && /^[A-Za-z0-9_@+.~/-]+$/.test(value) && !value.startsWith('/') &&
    value.split('/').every(p=>p && p!=='.' && p!=='..' && !/[. ]$/.test(p) && !/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)), 'safe portable member required');
  return value;
}
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const need = (value, message) => { if (!value) throw Error(PREFIX + message); };
const same = (a, b, message) => need(isDeepStrictEqual(a, b), message);
const CLOSURE_PRODUCERS = Object.freeze([
  'backendRuntimeAdmission31.cjs','backendRuntimeClosedReplay31.cjs','backendRuntimeClosure31.cjs',
  'backendRuntimeControls31.cjs','backendRuntimeEvidenceAccess31.cjs','backendRuntimeExecution31.cjs',
  'backendRuntimeExecutionAdmission31.cjs','backendRuntimeProof31.cjs','backendRuntimeReadbacks31.cjs',
  'business31BackendAuthority.cjs','business31BackendClosure.cjs','business31ExecutionContract.cjs',
  'business31SourceAdmission.cjs','business31TrustedInput.cjs','captureBackendRuntimePreparedInputs31.cjs',
  'captureBusiness31PreparedInputs.cjs','clientBuildToolingCompatibility31.cjs','clientRuntimeCompatibility31.cjs',
  'closure-preflight31.cjs','collectFirestoreRulesIndexesReadback.js','collectFunctionFleetRuntimeIdentityReadback.js',
  'collectFunctionsIamDependenciesReadback.js','collectProductionGlobalPullBackend.js','deploymentFleetContract.js',
  'executeBackendRuntime31.cjs','reviewedBackendControls.js','runtimeDeploymentTransportGuard31.cjs','scopedCallableInvokerIam.js'
].map(file=>'tools/release/'+file).sort());
const REQUIRED_EXECUTING = Object.freeze([...CLOSURE_PRODUCERS, SELF,
  'tools/release/business31PrivateDescriptor.cjs','tools/release/privateEvidenceBundle31.cjs']);
function exact(value, fields, label) {
  need(value && typeof value==='object' && !Array.isArray(value) &&
    [Object.prototype,null].includes(Object.getPrototypeOf(value)), label+' must be a plain object');
  same(Object.keys(value).sort(), [...fields].sort(), label+' fields differ');
}
function regular(file, directory=false) {
  need(typeof file==='string' && path.isAbsolute(file), 'physical path must be absolute');
  const full=path.resolve(file);let cursor=path.parse(full).root;
  for(const part of full.slice(cursor.length).split(path.sep).filter(Boolean)) {
    cursor=path.join(cursor,part); need(!fs.lstatSync(cursor).isSymbolicLink(),'physical path redirects');
  }
  const stat=fs.lstatSync(full);need(directory?stat.isDirectory():stat.isFile(),'regular physical path required');
  need(fs.realpathSync(full)===full,'physical path identity differs');return full;
}
function deriveClosureProducerBindings31(completeBindings) {
  need(completeBindings && typeof completeBindings==='object' && !Array.isArray(completeBindings), 'complete bindings required');
  need(Object.keys(completeBindings).length>CLOSURE_PRODUCERS.length &&
    REQUIRED_EXECUTING.every(file=>Object.hasOwn(completeBindings,file)), 'full wrapper/descriptor/bundle population required before closure subset');
  return Object.fromEntries(CLOSURE_PRODUCERS.map(file=>{
    const digest=completeBindings[file];need(typeof digest==='string' && /^[A-F0-9]{64}$/.test(digest),'closure subset binding missing');return [file,digest];
  }));
}
function executingBindings31(completeBindings) {
  deriveClosureProducerBindings31(completeBindings);
  const result={}, sourceRoot=path.resolve(__dirname,'../..');
  for(const [file,digest]of Object.entries(completeBindings)) {
    need((/^tools\/release\/[A-Za-z0-9_+./-]+\.(?:js|cjs|ps1)$/.test(file)||file==='tools/v4/v4_2_r1_canonical_audit.py') &&
      file.split('/').every(p=>p && p!=='.' && p!=='..') && /^[A-F0-9]{64}$/.test(digest),'unsafe complete producer identity');
    const physical=regular(path.join(sourceRoot,...file.split('/')));
    need(sha(fs.readFileSync(physical))===digest,'executing complete producer population differs');result[physical]=digest;
  }
  return result;
}
function validateRelocation31(relocation, inventory) {
  exact(relocation,['schemaVersion','roots','files','roles'],'relocation');
  need(relocation.schemaVersion===1 && Array.isArray(relocation.roots) && relocation.roots.length>0 && relocation.roots.length<=16 &&
    Array.isArray(relocation.files) && relocation.files.length<=50000,'finite relocation population required');
  exact(relocation.roles,['authorityRoot','executionRoot','evidenceDirectory'],'original replay roles');
  const access=require('./backendRuntimeEvidenceAccess31.cjs'), transport=require('./privateEvidenceBundle31.cjs');
  const roots=relocation.roots.map(row=>{exact(row,['original','memberRoot'],'root relocation');return {original:access.normalizeOriginal(row.original),memberRoot:portableMember(row.memberRoot)};});
  need(new Set(roots.map(r=>r.original.toLowerCase())).size===roots.length,'duplicate original root identity');
  for(const root of roots) {
    need(Object.keys(inventory).some(file=>file.startsWith(root.memberRoot+'/')),'mapped root has no bound members');
    for(const other of roots)if(root!==other)need(!other.original.toLowerCase().startsWith(root.original.toLowerCase()+'/') &&
      other.memberRoot!==root.memberRoot && !other.memberRoot.startsWith(root.memberRoot+'/'),'overlapping original/member roots');
  }
  const originals=new Set(), mappedMembers=new Set();
  for(const row of relocation.files) {
    exact(row,['original','member','bytes','sha256'],'file relocation');
    const original=access.normalizeOriginal(row.original),member=portableMember(row.member);
    need(!originals.has(original.toLowerCase()) && !roots.some(r=>original.toLowerCase()===r.original.toLowerCase()||original.toLowerCase().startsWith(r.original.toLowerCase()+'/')),'overlapping original file identity');
    need(!mappedMembers.has(member) && !roots.some(r=>member===r.memberRoot||member.startsWith(r.memberRoot+'/')),'overlapping member mapping');
    same(inventory[member],{bytes:row.bytes,sha256:row.sha256},'mapped file commitment differs');originals.add(original.toLowerCase());mappedMembers.add(member);
  }
  for(const [role,value]of Object.entries(relocation.roles)) {
    const original=access.normalizeOriginal(value);
    need(roots.some(r=>original===r.original || original.startsWith(r.original+'/')),'replay role must have one bound root: '+role);
  }
  for(const member of Object.keys(inventory)) need(mappedMembers.has(member)||roots.some(r=>member.startsWith(r.memberRoot+'/')),'unmapped private member');
  return relocation;
}
function originalPathsUnavailable31(relocation) {
  // Unavailability is a qualification of this offline proof, not simulated filesystem access.
  for(const row of [...relocation.roots,...relocation.files]) need(!fs.existsSync(row.original),'original path remains available; relocation independence not established');
  return true;
}
function inventory31(root) {
  regular(root,true);const rows={}, transport=require('./privateEvidenceBundle31.cjs');let count=0,total=0;
  function walk(directory) {for(const entry of fs.readdirSync(directory,{withFileTypes:true})) {
    const file=path.join(directory,entry.name);need(!entry.isSymbolicLink(),'bundle symlink refused');
    if(entry.isDirectory())walk(file);else {
      need(entry.isFile() && ++count<=transport.MAX_MEMBERS,'finite regular bundle population required');
      const stat=fs.statSync(file);need(stat.size<=transport.MAX_MEMBER && (total+=stat.size)<=transport.MAX_EXPANDED,'private member/expanded bound exceeded');
      const name=portableMember(path.relative(root,file).split(path.sep).join('/')),bytes=fs.readFileSync(file);rows[name]={bytes:bytes.length,sha256:sha(bytes)};
    }
  }}walk(root);return rows;
}
function joinOriginalExecutionRoot31({decisionEnvelopeBytes,descriptor,relocation}) {
  need(sha(decisionEnvelopeBytes)===descriptor.approvalPointer.sha256,'decision envelope differs before role join');
  const execution=require('./business31ExecutionContract.cjs'), envelope=execution.json(decisionEnvelopeBytes);
  const decision=execution.json(execution.privateBytes(relocation.roles.evidenceDirectory,envelope.privateRecord));
  const proof=execution.json(execution.privateBytes(relocation.roles.evidenceDirectory,decision.runtimeProof));
  same(proof.buildRoot,relocation.roles.executionRoot,'executionRoot does not equal retained runtime buildRoot');
  return true;
}
function verifyBusiness31OriginalPathReplay(options) {
  exact(options,['repositoryRoot','gitExecutable','gitSha256','envelope','descriptorPointer','sourceManifest',
    'expectedSourceManifestSha256','bundleBytes','extractionRoot','nowUtc'],'offline replay input');
  const {repositoryRoot,gitExecutable,gitSha256,envelope,descriptorPointer,sourceManifest,expectedSourceManifestSha256,bundleBytes,extractionRoot,nowUtc}=options;
  need(Buffer.isBuffer(bundleBytes) && bundleBytes.length>0 && bundleBytes.length<=512*1024*1024,'bounded existing local bundle bytes required');
  need(typeof nowUtc==='string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?Z$/.test(nowUtc) && Number.isFinite(Date.parse(nowUtc)),'explicit caller clock required');
  // This entry itself and all fixed imports are selected by the outer trusted caller, never candidate paths.
  const descriptorApi=require('./business31PrivateDescriptor.cjs');
  const descriptorProof=descriptorApi.verifyBusiness31DescriptorPreparation({repositoryRoot,gitExecutable,gitSha256,envelope,descriptorPointer,expectedSourceManifestSha256});
  const repository=require('./business31TrustedInput.cjs').openTrustedGitRepository31({repositoryRoot,gitExecutable,gitSha256});
  const descriptorBytes=repository.readBlob(descriptorPointer.commit,descriptorPointer.file);
  need(sha(descriptorBytes)===descriptorProof.descriptorSha256,'descriptor changed after boundary verification');
  const descriptor=descriptorApi.validateBusiness31PrivateDescriptor(descriptorApi.json(descriptorBytes));
  same(descriptor.producerBindings,envelope.verifier.files,'complete independently supplied producer bindings differ');
  const verifierFiles=executingBindings31(descriptor.producerBindings),closureBindings=deriveClosureProducerBindings31(descriptor.producerBindings);
  const admission=require('./business31SourceAdmission.cjs');
  need(sha(admission.canonical(sourceManifest))===expectedSourceManifestSha256,'source manifest object differs from external commitment');
  const transport=require('./privateEvidenceBundle31.cjs'), verified=transport.verifyBundleBytes31(bundleBytes,descriptor,'business');
  validateRelocation31(verified.relocation,verified.inventory);originalPathsUnavailable31(verified.relocation);
  const extracted=transport.extractVerifiedBundle31(bundleBytes,descriptor,extractionRoot,'business');
  same(inventory31(extracted.root),verified.inventory,'complete extracted population differs');
  const members=Object.entries(verified.inventory).map(([file,binding])=>({path:file,...binding}));
  const physicalGit=regular(gitExecutable);need(sha(fs.readFileSync(physicalGit))===gitSha256,'selected Git changed');verifierFiles[physicalGit]=gitSha256;
  const access=require('./backendRuntimeEvidenceAccess31.cjs');
  const result=access.runRelocated31({privateBundleRoot:extracted.root,relocation:verified.relocation,members,
    evidenceDirectory:verified.relocation.roles.evidenceDirectory,verifierFiles},()=>{
    joinOriginalExecutionRoot31({decisionEnvelopeBytes:repository.readBlob(descriptor.approvalPointer.commit,descriptor.approvalPointer.file),descriptor,relocation:verified.relocation});
    const authority=require('./business31BackendAuthority.cjs');same(authority.PRODUCERS,CLOSURE_PRODUCERS,'frozen closure producer population changed');
    return require('./business31BackendClosure.cjs').verifyBusiness31BackendClosure({authorityOptions:{
      repositoryRoot:verified.relocation.roles.authorityRoot,gitExecutable:physicalGit,gitSha256,
      trustedVerifier:{commit:envelope.verifier.commit,tree:envelope.verifier.tree,files:closureBindings},
      sourceCommit:descriptor.source.commit,sourceManifest,trustedManifestSha256:expectedSourceManifestSha256,
      evidenceDirectory:verified.relocation.roles.evidenceDirectory,decisionPointer:descriptor.approvalPointer,nowUtc},closurePointer:descriptor.closurePointer});
  });
  need(result.recordedSemanticsReplayed===true,'genuine full closure replay did not complete');same(result.source,descriptor.source,'full closure source differs');
  same(result.decisionPointer,descriptor.approvalPointer,'full closure decision differs');same(result.closurePointer,descriptor.closurePointer,'full closure custody differs');
  same(inventory31(extracted.root),verified.inventory,'private evidence changed during replay');originalPathsUnavailable31(verified.relocation);
  executingBindings31(descriptor.producerBindings);need(repository.readRef(envelope.candidate.ref)===envelope.candidate.commit,'candidate moved during replay');
  return Object.freeze({schemaVersion:1,documentType:'build31-business-offline-original-path-replay',profile:descriptor.profile,
    source:structuredClone(descriptor.source),descriptorSha256:sha(descriptorBytes),membersSha256:descriptor.membersSha256,
    relocationSha256:descriptor.relocationSha256,memberCount:members.length,originalPathsUnavailable:true,
    descriptorPreparationVerified:true,completeProducerBindingsVerified:true,recordedSemanticsReplayed:true,closure:result,
    platformIdentityAuthenticated:false,humanIdentityAuthenticated:false,processExecutionAuthenticated:false,trustedClockAuthenticated:false,
    privateHostedReplayAuthenticated:false,credentialAccessAuthorized:false,deploymentAuthorized:false,constructionAuthorized:false,distributionAuthorized:false});
}
module.exports={SELF,CLOSURE_PRODUCERS,REQUIRED_EXECUTING,deriveClosureProducerBindings31,executingBindings31,validateRelocation31,
  originalPathsUnavailable31,inventory31,joinOriginalExecutionRoot31,verifyBusiness31OriginalPathReplay};