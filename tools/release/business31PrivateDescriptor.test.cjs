'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {execFileSync}=require('node:child_process');
const subject=require('./business31PrivateDescriptor.cjs');
const trusted=require('./business31TrustedInput.cjs');
const {sha}=subject;
const temporaryParent=fs.realpathSync(os.tmpdir());
const temporary=fs.mkdtempSync(path.join(temporaryParent,'business31-descriptor-'));
const root=path.join(temporary,'repository');
fs.mkdirSync(root);
test.after(() => {
  const stats = fs.lstatSync(temporary);
  assert.equal(stats.isDirectory(), true);
  assert.equal(stats.isSymbolicLink(), false);
  assert.equal(fs.realpathSync(temporary), path.resolve(temporary));
  assert.equal(path.dirname(temporary), temporaryParent);
  fs.rmSync(temporary, {recursive: true, force: true});
});

const gitExecutable=process.env.BUSINESS31_TEST_GIT || (process.platform==='win32'?'C:/Program Files/Git/mingw64/bin/git.exe':'/usr/bin/git');
const gitSha256=sha(fs.readFileSync(gitExecutable));
const env=Object.fromEntries(Object.entries(process.env).filter(([k])=>!/^GIT_/i.test(k)));
Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null',GIT_AUTHOR_NAME:'Synthetic descriptor fixture',
GIT_AUTHOR_EMAIL:'fixture@example.invalid',GIT_COMMITTER_NAME:'Synthetic descriptor fixture',
GIT_COMMITTER_EMAIL:'fixture@example.invalid',GIT_AUTHOR_DATE:'2026-01-01T00:00:00Z',GIT_COMMITTER_DATE:'2026-01-01T00:00:00Z'});
function git(args,input){return execFileSync(gitExecutable,['-c','core.autocrlf=false','-c','commit.gpgsign=false','-c','core.hooksPath='+path.join(root,'absent-hooks'),'-C',root,...args],
  {env,input,encoding:'utf8',windowsHide:true,timeout:30000,stdio:['pipe','pipe','pipe']}).trim();}
git(['init','--initial-branch=main']);
function put(file,bytes){const oid=git(['hash-object','-w','--stdin'],bytes);git(['update-index','--add','--cacheinfo','100644,'+oid+','+file]);}
function commit(parents=[]){return git(['commit-tree',git(['write-tree']),...parents.flatMap(p=>['-p',p]),'-m','Synthetic descriptor data only']);}
const tree=c=>git(['rev-parse',c+'^{tree}']);
const files={};
for(const file of subject.CORE){
  const real=path.join(__dirname,path.basename(file));
  // Nonloaded future producers are inert data, not a full closure/writer fixture.
  const bytes=fs.existsSync(real)?fs.readFileSync(real):Buffer.from('// synthetic nonloaded producer fixture\n');
  files[file]=sha(bytes);put(file,bytes);
}
put('tools/v4/v4_2_r1_canonical_audit.py','# synthetic nonloaded audit fixture\n');
files['tools/v4/v4_2_r1_canonical_audit.py']=sha(Buffer.from('# synthetic nonloaded audit fixture\n'));
put(subject.HISTORICAL.file,fs.readFileSync(path.resolve(__dirname,'../..',subject.HISTORICAL.file)));
put('functions/index.js','// source A, never executed\n');put('pubspec.yaml','name: fixture\nversion: 1.0.0+30\n');
const V=commit();
put('functions/index.js','// source B, never executed\n');const branch=commit([V]);
git(['read-tree',V]);put('README.md','Synthetic fixture\n');const mainParent=commit([V]);
put('functions/index.js','// source B, never executed\n');const M=commit([mainParent,branch]);
git(['update-ref','refs/heads/main',M]);
let previous=M;const pointers={};
for(const [key,file]of Object.entries(subject.FILES)){
  const bytes=Buffer.from(JSON.stringify({synthetic:true,kind:key})+'\n');
  put(file,bytes);previous=commit([previous]);pointers[key]={commit:previous,file,sha256:sha(bytes)};
}
const base=previous;
const source={commit:M,tree:tree(M),functionsTree:git(['rev-parse',M+':functions'])};
const descriptor={schemaVersion:2,documentType:'build31-business-backend-private-replay',profile:subject.PROFILE,
  verifier:{commit:V,tree:tree(V)},source,sourceManifestSha256:'A'.repeat(64),...pointers,
  custody:{provider:'gcs',bucket:'crm3-baf-ops-b8638-firestore-restore',
    objectName:'release-custody/build-31/business-backend/'+M+'/fixture/private-replay-bundle.json',generation:'1',bytes:1,sha256:'B'.repeat(64)},
  bundleEncoding:'gzip-members-v1',expandedBytes:1,membersSha256:'C'.repeat(64),relocationSha256:'D'.repeat(64),
  producerBindings:files,historicalBaseline:subject.HISTORICAL};
const clone=()=>structuredClone(descriptor);
const invalid=[
  ['old route',d=>d.profile='build31-exact-grpc-runtime-backend-v1'],
  ['unknown field',d=>d.accessToken='not-a-real-token'],
  ['runtime namespace',d=>d.custody.objectName=d.custody.objectName.replace('business-backend','runtime-backend')],
  ['wrong bucket',d=>d.custody.bucket='untrusted'],
  ['nonexact generation',d=>d.custody.generation='latest'],
  ['oversized bundle',d=>d.custody.bytes=512*1024*1024+1],
  ['foreign pointer',d=>d.approvalPointer.file='release/approvals/other.json'],
  ['historical rewrite',d=>d.historicalBaseline.sha256='0'.repeat(64)],
  ['historical source',d=>d.source.commit=subject.HISTORICAL.commit],
  ['missing writer',d=>delete d.producerBindings['tools/release/captureBusiness31PreparedInputs.cjs']],
  ['missing npm-bin materializer',d=>delete d.producerBindings['tools/release/business31NpmBinMaterialization.cjs']],
  ['missing toolchain identity helper',d=>delete d.producerBindings['tools/release/business31ToolchainIdentity.cjs']],
  ['unsafe producer',d=>d.producerBindings['tools/release/../outside.cjs']='F'.repeat(64)],
  ['malformed verifier',d=>d.verifier.commit='HEAD']
];
for(const [name,change]of invalid)test('descriptor refuses '+name,()=>{const d=clone();change(d);assert.throws(()=>subject.validateBusiness31PrivateDescriptor(d));});
test('structural descriptor has no operational result',()=>assert.equal(subject.validateBusiness31PrivateDescriptor(descriptor),descriptor));
function candidate(d=clone(),changes={}){
  git(['read-tree',base]);const bytes=Buffer.from(JSON.stringify(d)+'\n');put(subject.DESCRIPTOR,bytes);
  const D=commit([base]);for(const [file,value]of Object.entries(changes))put(file,value);
  put('pubspec.yaml','name: fixture\nversion: 1.0.1+31\n');const S=commit([D]);git(['update-ref','refs/heads/candidate',S]);
  return {repositoryRoot:root,gitExecutable,gitSha256,expectedSourceManifestSha256:'A'.repeat(64),
    envelope:{schemaVersion:1,profile:trusted.PROFILE,verifier:{commit:V,tree:tree(V),files:structuredClone(files)},
      source:{commit:M,tree:tree(M)},candidate:{commit:S,tree:tree(S),ref:'refs/heads/candidate'}},
    descriptorPointer:{commit:D,file:subject.DESCRIPTOR,sha256:sha(bytes)}};
}
const verify=args=>subject.verifyBusiness31DescriptorPreparation(args);
test('actual Git verifies pointer bytes and preserves every unresolved authority',()=>{
  const result=verify(candidate());assert.equal(result.descriptorStructureVerified,true);assert.equal(result.pointerBytesVerified,true);assert.equal(result.functionsTreeVerified,true);assert.equal(result.historicalClosureBytesVerified,true);
  for(const key of ['metadataSemanticsVerified','platformIdentityAuthenticated','ownerAuthenticated',
    'privateReplayVerified','credentialAccessAuthorized','deploymentAuthorized','constructionAuthorized','distributionAuthorized'])assert.equal(result[key],false,key);
  fs.writeFileSync(path.join(temporary,'ACTUAL_GIT_POSITIVE_RESULT.json'),JSON.stringify(result,null,2)+'\n');
});
test('reject changed public approval bytes after pointer custody',()=>{
  assert.throws(()=>verify(candidate(clone(),{[subject.FILES.approvalPointer]:'{"synthetic":"changed"}\n'})),/pointer bytes differ/);
});
test('reject fake descriptor source and producer digest at actual Git boundary',()=>{
  const d=clone();d.source.tree='0'.repeat(40);assert.throws(()=>verify(candidate(d)),/descriptor source differs/);
  const e=clone();e.producerBindings['tools/release/business31BackendClosure.cjs']='0'.repeat(64);
  assert.throws(()=>verify(candidate(e)),/producer digest differs/);
});
test('reject caller narrowing verifier population',()=>{
  const args=candidate();delete args.envelope.verifier.files['tools/release/captureBusiness31PreparedInputs.cjs'];
  assert.throws(()=>verify(args),/external verifier binding/);
});
test('reject candidate producer change without loading candidate code',()=>{
  const marker=path.join(temporary,'CANDIDATE_EXECUTED');
  const malicious='require("node:fs").writeFileSync('+JSON.stringify(marker)+',"bad");\n';
  assert.throws(()=>verify(candidate(clone(),{'tools/release/captureBusiness31PreparedInputs.cjs':malicious})),/Trusted verifier source changed/);
  assert.equal(fs.existsSync(marker),false);
});
test('reject stale candidate reference',()=>{
  const args=candidate();git(['update-ref','refs/heads/candidate',M]);assert.throws(()=>verify(args),/Candidate reference differs/);
});
test('strict JSON bounds reject malformed UTF8, deep and oversized metadata',()=>{
  for(const bytes of [Buffer.from([0xff]),Buffer.from('['.repeat(40)+'0'+']'.repeat(40)),Buffer.alloc(2*1024*1024+1)])assert.throws(()=>subject.json(bytes));
});

test('actual functions subtree and external manifest cannot be replaced by descriptor claims',()=>{
  const d=clone();d.source.functionsTree='0'.repeat(40);assert.throws(()=>verify(candidate(d)),/functions tree differs/);
  const args=candidate();args.expectedSourceManifestSha256='F'.repeat(64);assert.throws(()=>verify(args),/source manifest differs/);
});
test('safe nested producers participate in complete inventory',()=>{
  assert.equal(subject.producer('tools/release/nested/entry.cjs'),true);
  const d=clone();d.producerBindings['tools/release/nested/../entry.cjs']='F'.repeat(64);
  assert.throws(()=>subject.validateBusiness31PrivateDescriptor(d),/producer identity/);
});
