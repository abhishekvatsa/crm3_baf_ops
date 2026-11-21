'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const trusted=require('./business31TrustedInputV2.cjs'),descriptor=require('./business31PrivateDescriptorV2.cjs');
const {createFixture}=require('./fixtures/business31ClientPolicyFixture.cjs');
let f;
function input(){if(!f)f=createFixture({successor:true});f.reset();const x=f.platformFixture(),ci=f.clientInput();
 return {repositoryRoot:f.root,gitExecutable:ci.gitExecutable,gitSha256:x.trust.gitSha256,envelope:trusted.createTrustedEnvelopeV2(x.trust,x.request.candidate),
  descriptorPointer:x.request.descriptorPointer,expectedSourceManifestSha256:x.trust.sourceManifestSha256};}
test('actual Git source and descriptor custody separate enrolled outer from recorded M',()=>{
 const args=input(),boundary=trusted.verifyBusiness31TrustedInputV2(args),proof=descriptor.verifyBusiness31DescriptorPreparationV2(args);
 assert.equal(boundary.inputBoundaryVerified,true);assert.equal(proof.descriptorStructureVerified,true);
 assert.equal(boundary.coreVerifier.commit,f.M.commit);assert.equal(boundary.verifierCommit,f.Vnew.commit);
 assert.notEqual(boundary.verifierCommit,boundary.coreVerifier.commit);assert.equal(proof.deploymentAuthorized,false);
});
test('wrong core identity/hash and incomplete enrolled delta fail actual source admission',()=>{
 for(const mutate of [a=>a.envelope.coreVerifier.tree='f'.repeat(40),a=>a.envelope.coreVerifier.files[Object.keys(a.envelope.coreVerifier.files)[0]]='F'.repeat(64),
  a=>delete a.envelope.sourceIntegration[Object.keys(a.envelope.sourceIntegration)[0]],a=>a.envelope.sourceIntegration[Object.keys(a.envelope.sourceIntegration)[0]].oid='f'.repeat(40)]){
  const a=input();mutate(a);assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(a));
 }
});
test('source integration is finite and excludes unrelated deployment/source controls',()=>{
 assert.equal(new Set(trusted.INTEGRATION_PATHS).size,trusted.INTEGRATION_PATHS.length);
 for(const file of ['tools/release/deploymentFleetContract.js','tools/release/reviewedBackendControls.js','tools/release/business31BackendAuthority.cjs',
  'functions/src/index.ts','tools/release/unrelated-new-script.cjs','tools/release/privateEvidenceBundle31.cjs']){
  assert.equal(trusted.INTEGRATION_PATHS.includes(file),false);const a=input();a.envelope.sourceIntegration[file]={mode:'100644',oid:'f'.repeat(40),sha256:'F'.repeat(64)};
  assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(a),/integration member invalid/);
 }
});
test('closed envelope refuses mixed profile and candidate-selected helper bytes',()=>{
 const a=input();a.envelope.profile='build31-business-trusted-input-v1';assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(a),/successor profile/);
 const b=input();b.envelope.verifier.files[trusted.SELF]='F'.repeat(64);assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(b),/bound helper bytes/);
});

test('actual Git admission binds only the two newly enrolled workflow integrations',()=>{
 const g=createFixture({successor:true,enrollmentWorkflows:true}),x=g.platformFixture(),ci=g.clientInput();
 const args={repositoryRoot:g.root,gitExecutable:ci.gitExecutable,gitSha256:x.trust.gitSha256,
  envelope:trusted.createTrustedEnvelopeV2(x.trust,x.request.candidate),descriptorPointer:x.request.descriptorPointer,
  expectedSourceManifestSha256:x.trust.sourceManifestSha256};
 assert.equal(trusted.verifyBusiness31TrustedInputV2(args).inputBoundaryVerified,true);
 assert.equal(descriptor.verifyBusiness31DescriptorPreparationV2(args).descriptorStructureVerified,true);
 for(const file of ['.github/workflows/production-artifact.yml','.github/workflows/release-gate.yml']){
  assert.equal(trusted.INTEGRATION_PATHS.includes(file),true);
  assert.ok(Object.hasOwn(args.envelope.sourceIntegration,file));
  const changed=structuredClone(args);changed.envelope.sourceIntegration[file].sha256='F'.repeat(64);
  assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(changed),/integration object\/hash changed/);
  const omitted=structuredClone(args);delete omitted.envelope.sourceIntegration[file];
  assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(omitted),/integration must exactly equal/);
 }
 for(const file of ['.github/workflows/codeql.yml','.github/workflows/verification-artifact.yml','.github/workflows/claude.yml']){
  assert.equal(trusted.INTEGRATION_PATHS.includes(file),false);
  const changed=structuredClone(args);changed.envelope.sourceIntegration[file]={mode:'100644',oid:'f'.repeat(40),sha256:'F'.repeat(64)};
  assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(changed),/integration member invalid/);
 }
});

test('actual Git admission accepts a verifier whose replay workflow actions move the action-reference custody pin',()=>{
 // Verifier v8 changed the replay workflow's pinned actions and therefore the repository-wide
 // action-reference count in workflow_action_ref_custody.test.mjs; that delta must stay admissible.
 const g=createFixture({successor:true,actionCustody:true}),x=g.platformFixture(),ci=g.clientInput();
 const args={repositoryRoot:g.root,gitExecutable:ci.gitExecutable,gitSha256:x.trust.gitSha256,
  envelope:trusted.createTrustedEnvelopeV2(x.trust,x.request.candidate),descriptorPointer:x.request.descriptorPointer,
  expectedSourceManifestSha256:x.trust.sourceManifestSha256};
 assert.equal(trusted.verifyBusiness31TrustedInputV2(args).inputBoundaryVerified,true);
 assert.equal(descriptor.verifyBusiness31DescriptorPreparationV2(args).descriptorStructureVerified,true);
 for(const file of ['.github/workflows/business-private-replay.yml','tools/release/workflow_action_ref_custody.test.mjs']){
  assert.equal(trusted.INTEGRATION_PATHS.includes(file),true);
  assert.ok(Object.hasOwn(args.envelope.sourceIntegration,file));
  const omitted=structuredClone(args);delete omitted.envelope.sourceIntegration[file];
  assert.throws(()=>trusted.verifyBusiness31TrustedInputV2(omitted),/integration must exactly equal/);
 }
});
