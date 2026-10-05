"use strict";
// Private synthetic Git records only. No credentials, downloads or candidate execution.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {execFileSync}=require('node:child_process');
const subject=require('./business31PrivateDescriptor.cjs');
const trusted=require('./business31TrustedInput.cjs');
const {sha}=subject;
const temporaryParent=fs.realpathSync(os.tmpdir());
const temporary=fs.mkdtempSync(path.join(temporaryParent,'business31-descriptor-custody-'));
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
const env={};for(const k of ['SystemRoot','SYSTEMROOT','WINDIR','COMSPEC','TEMP','TMP','PATH','PATHEXT'])if(process.env[k]!==undefined)env[k]=process.env[k];
Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null',GIT_TERMINAL_PROMPT:'0',GIT_AUTHOR_NAME:'Synthetic negative fixture',GIT_AUTHOR_EMAIL:'fixture@example.invalid',GIT_COMMITTER_NAME:'Synthetic negative fixture',GIT_COMMITTER_EMAIL:'fixture@example.invalid',GIT_AUTHOR_DATE:'2026-01-01T00:00:00Z',GIT_COMMITTER_DATE:'2026-01-01T00:00:00Z'});
function git(args,input){return execFileSync(gitExecutable,['--no-replace-objects','-c','core.autocrlf=false','-c','core.hooksPath='+path.join(root,'absent-hooks'),'-c','commit.gpgsign=false','-c','credential.helper=','-c','protocol.allow=never','-C',root,...args],{env,input,encoding:'utf8',windowsHide:true,timeout:30000,stdio:['pipe','pipe','pipe']}).trim();}
git(['init','--initial-branch=main']);
function put(file,bytes){const oid=git(['hash-object','-w','--stdin'],bytes);git(['update-index','--add','--cacheinfo','100644,'+oid+','+file]);}
let serial=0;const commit=parents=>git(['commit-tree',git(['write-tree']),...parents.flatMap(p=>['-p',p]),'-m','SYNTHETIC negative fixture '+(++serial)]);
const tree=commit=>git(['rev-parse',commit+'^{tree}']);
const files={};
for(const file of subject.CORE){const local=path.join(__dirname,path.basename(file));const bytes=fs.existsSync(local)?fs.readFileSync(local):Buffer.from('// synthetic nonloaded producer\n');files[file]=sha(bytes);put(file,bytes);}
const audit='tools/v4/v4_2_r1_canonical_audit.py',auditBytes=Buffer.from('# synthetic nonloaded audit\n');files[audit]=sha(auditBytes);put(audit,auditBytes);
// This nested file really exists in V/M/S, contains the exact reviewed helper bytes,
// and participates in Git identities; it is never loaded as candidate code.
const nested='tools/release/nested/bound-helper.cjs',nestedBytes=fs.readFileSync(path.join(__dirname,'privateEvidenceBundle31.cjs'));
files[nested]=sha(nestedBytes);put(nested,nestedBytes);
const historicalBytes=fs.readFileSync(path.resolve(__dirname,'../..',subject.HISTORICAL.file));
assert.equal(sha(historicalBytes),subject.HISTORICAL.sha256);put(subject.HISTORICAL.file,historicalBytes);
put('functions/index.js','// synthetic source A; never executed\n');put('pubspec.yaml','name: fixture\nversion: 1.0.0+30\n');
const V=commit([]),verifierTree=tree(V);
function make(kind){
 git(['read-tree',V]);put('README.md','Synthetic normal main parent\n');const main=commit([V]);
 git(['read-tree',V]);put('functions/index.js','// synthetic source B; never executed\n');
 if(kind==='historical')put(subject.HISTORICAL.file,Buffer.concat([historicalBytes,Buffer.from('\n')]));
 const branch=commit([V]);git(['read-tree',main]);put('functions/index.js','// synthetic source B; never executed\n');
 if(kind==='historical')put(subject.HISTORICAL.file,Buffer.concat([historicalBytes,Buffer.from('\n')]));
 const M=commit([main,branch]);
 const approvalBytes=Buffer.from(JSON.stringify({synthetic:true,kind:'decision'})+'\n');put(subject.FILES.approvalPointer,approvalBytes);
 if(kind==='decision-extra')put('README.md','Unrelated admitted metadata mixed into decision custody\n');
 const Q=commit([M]);
 const closureBytes=Buffer.from(JSON.stringify({synthetic:true,kind:'closure'})+'\n');put(subject.FILES.closurePointer,closureBytes);
 if(kind==='closure-extra')put('README.md','Unrelated admitted metadata mixed into closure custody\n');
 const C=commit([Q]);let approvalCommit=Q,descriptorParent=C;
 if(kind==='order'){approvalCommit=commit([C]);descriptorParent=approvalCommit;}
 const bindings=structuredClone(files);if(kind==='nested-omitted')delete bindings[nested];
 const d={schemaVersion:2,documentType:'build31-business-backend-private-replay',profile:subject.PROFILE,verifier:{commit:V,tree:verifierTree},source:{commit:M,tree:tree(M),functionsTree:git(['rev-parse',M+':functions'])},sourceManifestSha256:'A'.repeat(64),approvalPointer:{commit:approvalCommit,file:subject.FILES.approvalPointer,sha256:sha(approvalBytes)},closurePointer:{commit:C,file:subject.FILES.closurePointer,sha256:sha(closureBytes)},custody:{provider:'gcs',bucket:'crm3-baf-ops-b8638-firestore-restore',objectName:'release-custody/build-31/business-backend/'+M+'/fixture/private-replay-bundle.json',generation:'1',bytes:1,sha256:'B'.repeat(64)},bundleEncoding:'gzip-members-v1',expandedBytes:1,membersSha256:'C'.repeat(64),relocationSha256:'D'.repeat(64),producerBindings:bindings,historicalBaseline:subject.HISTORICAL};
 if(kind==='descriptor-extra')put('README.md','Unrelated admitted metadata mixed into descriptor custody\n');
 const descriptorBytes=Buffer.from(JSON.stringify(d)+'\n');put(subject.DESCRIPTOR,descriptorBytes);const D=commit([descriptorParent]);
 put('pubspec.yaml','name: fixture\nversion: 1.0.1+31\n');const S=commit([D]);git(['update-ref','refs/heads/candidate',S]);
 // Every altered public object is retained in actual Git with matching raw SHA;
 // failures must come from the intended semantic join, not stale pointer bytes.
 for(const p of [d.approvalPointer,d.closurePointer])assert.equal(sha(Buffer.from(git(['show',p.commit+':'+p.file])+'\n')),p.sha256);
 assert.equal(git(['rev-parse',M+':'+nested]),git(['rev-parse',V+':'+nested]));
 const args={repositoryRoot:root,gitExecutable,gitSha256,expectedSourceManifestSha256:'A'.repeat(64),envelope:{schemaVersion:1,profile:trusted.PROFILE,verifier:{commit:V,tree:verifierTree,files:bindings},source:{commit:M,tree:tree(M)},candidate:{commit:S,tree:tree(S),ref:'refs/heads/candidate'}},descriptorPointer:{commit:D,file:subject.DESCRIPTOR,sha256:sha(descriptorBytes)}};
 fs.writeFileSync(path.join(root,kind+'-input.json'),JSON.stringify(args,null,2)+'\n',{flag:'wx'});return args;
}
const cases=[
 ['order','reversed decision and closure ancestry refuses despite matching public pointer bytes',/Required Git ancestry absent/],
 ['decision-extra','decision custody refuses an unrelated allowed metadata change',/custody delta must change only its exact named record/],
 ['closure-extra','closure custody refuses an unrelated allowed metadata change',/custody delta must change only its exact named record/],
 ['descriptor-extra','descriptor custody refuses an unrelated allowed metadata change',/custody delta must change only its exact named record/],
 ['historical','M historical closure byte alteration refuses despite valid Git and stable M to S',/historical closure bytes differ/],
 ['nested-omitted','real nested producer omission from descriptor and external map refuses',/descriptor must bind complete release producer population/]
];
for(const [kind,name,expected]of cases)test(name,()=>{const args=make(kind);let refusal;assert.throws(()=>subject.verifyBusiness31DescriptorPreparation(args),e=>{refusal={name:e.name,message:e.message};return expected.test(e.message);});fs.writeFileSync(path.join(root,kind+'-refusal.json'),JSON.stringify({synthetic:true,expectedRefusal:expected.source,actual:refusal},null,2)+'\n',{flag:'wx'});});


test('dedicated descriptor custody measures preparation without operational authority',()=>{
 const args=make('dedicated-descriptor');
 const result=subject.verifyBusiness31DescriptorPreparation(args);
 assert.equal(result.descriptorStructureVerified,true);
 assert.equal(result.pointerBytesVerified,true);
 assert.equal(result.inputBoundaryVerified,true);
 assert.equal(result.functionsTreeVerified,true);
 assert.equal(result.historicalClosureBytesVerified,true);
 assert.equal(result.sourceManifestCommitmentJoined,true);
 for(const key of ['metadataSemanticsVerified','platformIdentityAuthenticated','ownerAuthenticated',
  'privateReplayVerified','credentialAccessAuthorized','deploymentAuthorized','constructionAuthorized','distributionAuthorized'])
  assert.equal(result[key],false,key);
});
