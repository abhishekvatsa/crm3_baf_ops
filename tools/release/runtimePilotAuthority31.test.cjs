'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const sourceRoot=path.resolve(__dirname,'../..');
const repo=execFileSync('git',['-C',sourceRoot,'rev-parse','--show-toplevel'],{encoding:'utf8',windowsHide:true}).trim();
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const json=file=>JSON.parse(fs.readFileSync(file,'utf8'));
test('all14 historical Rules verifier files retain exact immutable bytes',()=>{
  const method=json(path.join(repo,'release/approvals/build30-rules-observed-state-method-approval.json'));
  assert.equal(Object.keys(method.reviewedVerifier.files).length,14);
  for(const [file,hash]of Object.entries(method.reviewedVerifier.files)){
    const candidate=path.join(sourceRoot,file),actual=fs.existsSync(candidate)?candidate:path.join(repo,file);
    assert.equal(sha(fs.readFileSync(actual)),hash,file);
    const committed=execFileSync('git',['-C',repo,'show',method.reviewedVerifier.commit+':'+file],{windowsHide:true});
    assert.equal(sha(committed),hash,'immutable custody '+file);
  }
});
function run(t,mutate){
  const parent=path.join(repo,'.dart_tool');fs.mkdirSync(parent,{recursive:true});
  const root=fs.mkdtempSync(path.join(parent,'runtime-pilot31-test-'));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  fs.cpSync(path.join(repo,'release'),path.join(root,'release'),{recursive:true});
  const policy=json(path.join(root,'release/production-release-policy.json'));
  policy.release={...policy.release,buildNumber:31};policy.versionPolicy={...policy.versionPolicy,buildNumber:31};
  const promotion=json(path.join(root,policy.postBuildPromotion.promotionReceiptFile));
  const backend=json(path.join(root,promotion.admittedEvidence.productionBackend.receipt));
  const rewrite=(file,change)=>{const p=path.join(root,file),v=json(p);change(v);fs.writeFileSync(p,JSON.stringify(v));};
  mutate?.({root,policy,promotion,backend,rewrite});
  return require('./runtimePilotAuthority31.cjs').verifyPreservedPilotForRuntime31({repoRoot:root,releasePolicy:policy});
}
test('runtime31 independently verifies the actual anchored historical pilot',t=>{
  const result=run(t);assert.match(result.historicalBackendReceiptSha256,/^[A-F0-9]{64}$/);
  assert.equal(result.promotionReceiptFile,'release/evidence/build-27-staged-controlled-pilot-authorization.json');
});
for(const [name,mutate]of [
  ['altered owner',({promotion,rewrite})=>rewrite(promotion.ownerApproval.receipt,v=>{v.approved=false;})],
  ['altered backend',({promotion,rewrite})=>rewrite(promotion.admittedEvidence.productionBackend.receipt,v=>{v.deployment.functionCount=999;})],
  ['altered raw readback',({backend,rewrite})=>rewrite(backend.cleanMainLiveReadbacks.functionFleet.file,v=>{v.decision='NOT-PASS';})],
  ['retargeted promotion',({policy})=>{policy.postBuildPromotion.promotionReceiptSha256='A'.repeat(64);}],
  ['wrong generation',({policy})=>{policy.release.buildNumber=32;}],
])test('runtime31 pilot refuses '+name,t=>assert.throws(()=>run(t,mutate)));

// This isolated caller-boundary test substitutes a clearly synthetic transport
// result only to reach the actual pre-load adapter check. Full transport proof
// and real historical pilot adjudication are tested separately.
for(const tampered of [false,true])test('shared caller '+(tampered?'rejects substituted':'loads Git-bound')+' pilot adapter before evaluation',t=>{
  const parent=path.join(repo,'.dart_tool'),root=fs.mkdtempSync(path.join(parent,'runtime-pilot31-bootstrap-'));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const git=(...args)=>execFileSync('git',['-C',root,...args],{encoding:'utf8',windowsHide:true});
  git('init','-q');git('config','user.name','Synthetic boundary test');git('config','user.email','fixture@invalid.example');
  const dir=path.join(root,'tools/release');fs.mkdirSync(dir,{recursive:true});
  fs.writeFileSync(path.join(dir,'runtimeBackendPrivateReplay31.cjs'),"module.exports={verifyRuntime31RepositoryAuthoritySync:()=>({ok:true,testOnly:true})};\n");
  const adapter=path.join(dir,'runtimePilotAuthority31.cjs');
  fs.writeFileSync(adapter,"module.exports={verifyPreservedPilotForRuntime31:()=>({testPilot:true})};\n");
  git('add','.');git('commit','-qm','Synthetic boundary only');
  if(tampered)fs.writeFileSync(adapter,"global.__runtime31UntrustedPilotExecuted=true;module.exports={};\n");
  const Module=require('node:module'),filename=path.join(repo,'tools/release/clientBackendCompatibility31.js');
  const loaded=new Module(filename,module);loaded.filename=filename;loaded.paths=Module._nodeModulePaths(path.dirname(filename));
  loaded._compile(fs.readFileSync(path.join(__dirname,'clientBackendCompatibility31.js'),'utf8'),filename);
  const result=loaded.exports.verifyClientBackendSourceAuthority({repoRoot:root,releasePolicy:{release:{buildNumber:31},versionPolicy:{buildNumber:31},runtimeBackendPrivateReplay:{}}});
  if(tampered){assert.equal(result.ok,false);assert.match(result.reasons.join(' '),/pilot adapter must match immutable source before loading/);assert.notEqual(global.__runtime31UntrustedPilotExecuted,true);}
  else{assert.equal(result.ok,true);assert.equal(result.testPilot,true);}
});
