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
