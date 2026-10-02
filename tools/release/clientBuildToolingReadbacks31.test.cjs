"use strict";
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{execFileSync}=require('node:child_process'),assert=require('node:assert/strict'),test=require('node:test');
const original=require('./collectFunctionsIamDependenciesReadback.js');
const {sealReceipt}=require('./collectProductionGlobalPullBackend.js');
const {createDualSourceIamReceipt,verifyDualSourceIamReceipt,WRAPPING_PRODUCERS}=require('./clientBuildToolingReadbacks31.cjs');
const {HISTORICAL_DEVELOPMENT_FILES,readHistoricalDevelopmentFile}=require('./clientBuildTooling31.historical-fixture.cjs');
const candidate=path.resolve(__dirname,'../..'),primary=execFileSync('git',['-C',__dirname,'rev-parse','--show-toplevel'],{encoding:'utf8',windowsHide:true}).trim();
const repo=fs.mkdtempSync(path.join(os.tmpdir(),'dual-source-fixture-'));
test.after(()=>{const resolved=fs.realpathSync(repo);assert.equal(path.dirname(resolved),fs.realpathSync(os.tmpdir()));assert.match(path.basename(resolved),/^dual-source-fixture-/);fs.rmSync(resolved,{recursive:true});});
const source='78ec2f40a1253bdb7f641b60023ba6c810d4ae8f',baseline='2aa30de56cfdb960da3eeefd8956d8cbbae57b46';
const env={...process.env,GIT_AUTHOR_NAME:'Synthetic fixture',GIT_AUTHOR_EMAIL:'fixture@example.invalid',GIT_COMMITTER_NAME:'Synthetic fixture',GIT_COMMITTER_EMAIL:'fixture@example.invalid'};
function git(args,input){return execFileSync('git',['--no-replace-objects','-C',repo,...args],{encoding:'utf8',windowsHide:true,env,input,stdio:['pipe','pipe','pipe']}).trim();}
execFileSync('git',['init','--quiet',repo],{windowsHide:true});
const objects=execFileSync('git',['-C',primary,'rev-parse','--path-format=absolute','--git-path','objects'],{encoding:'utf8'}).trim();fs.mkdirSync(path.join(repo,'.git/objects/info'),{recursive:true});fs.writeFileSync(path.join(repo,'.git/objects/info/alternates'),objects.replaceAll('\\','/')+'\n');
git(['read-tree',source]);
for(const file of ['package.json','package-lock.json','functions/package-lock.json','tooling/brace-expansion-compat/package.json',...WRAPPING_PRODUCERS]){const bytes=HISTORICAL_DEVELOPMENT_FILES.includes(file)?readHistoricalDevelopmentFile(primary,file):fs.readFileSync(path.join(candidate,file));const blob=git(['hash-object','-w','--stdin'],bytes);git(['update-index','--add','--cacheinfo',`100644,${blob},${file}`]);}
const candidateCommit=git(['commit-tree',git(['write-tree']),'-p',source], 'Synthetic dual-source readback fixture; never production authority.\n');
const tree=git(['rev-parse',candidateCommit+'^{tree}']);
const backend=JSON.parse(fs.readFileSync(path.join(primary,'release/evidence/build30-current-source-backend-deployment-closure.json')));
const historical=JSON.parse(fs.readFileSync(path.join(primary,backend.cleanMainLiveReadbacks.iamDependencies.file)));
const policy=JSON.parse(git(['show',baseline+':'+original.POLICY_PATH]));
const point={...historical.source.before,commit:candidateCommit,tree,originMain:candidateCommit,branch:'main',governedWorktreeClean:true,materialChangeCount:0,materialPathSha256:[]};
const rawSource=file=>execFileSync('git',['--no-replace-objects','-C',repo,'show',candidateCommit+':'+file],{encoding:'utf8',windowsHide:true});
const candidateDependencies=original.summarizePackageState({packageJsonRaw:rawSource('functions/package.json'),packageLockRaw:rawSource('functions/package-lock.json'),trackedPackages:policy.trackedRuntimePackages});
const replay=original.adjudicateReadback({projectId:'crm3-baf-ops-b8638',region:'asia-south1',policy,sourceBefore:point,sourceAfter:point,project:historical.outputs.project,iam:historical.outputs.iam,functions:historical.outputs.functions,currentDependencies:candidateDependencies,discoveredSourceExports:[...policy.sourceFunctionExports].sort(),observe:true});
const now=Date.now(),instant=offset=>new Date(now+offset).toISOString();
const rawCapture=sealReceipt({...replay.evidence,capturedAtUtc:instant(-30000)});
const input={repoRoot:repo,candidateCommit,rawCapture,collectionStartedAtUtc:instant(-40000),capturedAtUtc:instant(-20000)};
const good=createDualSourceIamReceipt(input);
function verify(receipt=good,extra={}){return verifyDualSourceIamReceipt({repoRoot:repo,candidateCommit,receipt,lastCiCompletionAtUtc:instant(-50000),decisionAtUtc:instant(-10000),...extra});}
function reseal(receipt){const{receiptSha256,...body}=receipt;return sealReceipt(body);}
test('synthetic changed M tools and immutable F deployed inventory remain explicit and separate',()=>{assert.equal(verify().ok,true);assert.equal(good.deployedBackend.commit,baseline);assert.equal(good.candidateBuild.commit,candidateCommit);assert.notEqual(good.deployedBackend.dependencies.dependencyInventorySha256,good.candidateBuild.dependencies.dependencyInventorySha256);assert.equal(good.rawCapture.posture.decision,'HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE');assert.equal(good.deployedBackendAssessment.posture.decision,'PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE');assert.equal(verify().constructionAuthority,false);assert.equal(Object.hasOwn(good,'outputs'),false);});
for(const[name,change]of [
 ['generation',r=>{r.intendedBuildNumber=32}],['schema',r=>{r.schemaVersion=2}],['F relabelled as M',r=>{r.deployedBackend.commit=candidateCommit}],['M dependencies substituted with F',r=>{r.candidateBuild.dependencies=r.deployedBackend.dependencies}],['extra authority',r=>{r.scope.constructionAuthority=true}],['backend assessment tampered',r=>{r.deployedBackendAssessment.posture.holds=['drift']}],['unknown field',r=>{r.unverified=true}],['inventory hash altered',r=>{r.protectedInventorySha256='0'.repeat(64)}],['old observation under fresh seal',r=>{r.collectionStartedAtUtc=instant(-60000)}],['decision predates capture',r=>{r.capturedAtUtc=instant(-5000)}],['future capture',r=>{r.capturedAtUtc='2999-01-01T00:00:00Z'}],
])test('rejects coherently resealed '+name,()=>{const r=structuredClone(good);change(r);assert.throws(()=>verify(reseal(r)));});
for(const[name,change]of [
 ['dirty M',r=>{r.source.before.governedWorktreeClean=false}],['wrong current source',r=>{r.source.before.commit=baseline}],['wrong original mode',r=>{r.mode='STRICT'}],['invented clean raw posture',r=>{r.posture.holds=[]}],['missing archive generation',r=>{r.outputs.functions[0].sourceArchive.generationPinnedDownload=false}],['runtime hash drift',r=>{r.outputs.functions[0].firebaseFunctionsHash='0'.repeat(40)}],['raw deployed dependencies mislabeled current M',r=>{r.outputs.currentSourceDependencies=good.deployedBackend.dependencies}],
])test('rejects resealed raw '+name,()=>{const r=structuredClone(rawCapture);change(r);assert.throws(()=>createDualSourceIamReceipt({...input,rawCapture:reseal(r)}));});
test('rejects stale pre-main-CI readback regardless of fresh receipt capture',()=>assert.throws(()=>verify(good,{lastCiCompletionAtUtc:instant(-25000)})));
test('preserves nanosecond deployed update timestamps',()=>assert.match(historical.outputs.functions[0].updateTime,/\.\d{7,9}Z$/));

for(const[name,change]of [
 ['middle function update preserving extrema',r=>{r.outputs.functions[0].updateTime='2026-09-27T18:18:08.344423212Z'}],
 ['archive generation',r=>{r.outputs.functions[0].source.generation='9999999999'}],
 ['archive digest',r=>{r.outputs.functions[0].sourceArchive.sha256='A'.repeat(64)}],
 ['Cloud Build identity',r=>{r.outputs.functions[0].build='different'}],
])test('rejects otherwise valid original-adjudication '+name,()=>{const r=structuredClone(rawCapture);change(r);const result=original.adjudicateReadback({projectId:'crm3-baf-ops-b8638',region:'asia-south1',policy,sourceBefore:point,sourceAfter:point,project:r.outputs.project,iam:r.outputs.iam,functions:r.outputs.functions,currentDependencies:candidateDependencies,discoveredSourceExports:[...policy.sourceFunctionExports].sort(),observe:true});const raw=sealReceipt({...result.evidence,capturedAtUtc:rawCapture.capturedAtUtc});assert.throws(()=>createDualSourceIamReceipt({...input,rawCapture:raw}),/Historical per-function/);});
