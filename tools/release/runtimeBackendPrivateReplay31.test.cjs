'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const https=require('node:https'),{EventEmitter}=require('node:events');
const {gzipSync}=require('node:zlib');
const api=require('./runtimeBackendPrivateReplay31.cjs');
const clone=value=>JSON.parse(JSON.stringify(value));
const H='A'.repeat(64),M='a'.repeat(40),TOKEN='synthetic-local-test-token-never-transmitted';
function pointer(file){return{commit:M,file,sha256:H};}
function material(){
  const raw=Buffer.from('Explicit synthetic private proof member, not authority.');
  const encoded=gzipSync(raw);
  const member={path:'authority/closure.json',bytes:raw.length,sha256:api.sha(raw),encoding:'gzip',compressedBytes:encoded.length,compressedSha256:api.sha(encoded),base64:encoded.toString('base64')};
  const relocation={schemaVersion:1,roots:[],files:[]};
  const source={commit:M,tree:'b'.repeat(40),functionsTree:'c'.repeat(40)};
  const bundle={schemaVersion:2,encoding:api.BUNDLE_ENCODING,documentType:'build31-private-runtime-evidence-bundle',source,members:[member],relocation};
  const producers=Object.fromEntries([...api.CORE_PRODUCERS,'tools/v4/v4_2_r1_canonical_audit.py'].map(file=>[file,H]));
  const descriptor={schemaVersion:2,bundleEncoding:api.BUNDLE_ENCODING,expandedBytes:raw.length,documentType:'build31-runtime-backend-private-replay',profile:api.PROFILE,source,
    approvalPointer:pointer('release/approvals/build31-runtime-backend-deployment-approval.json'),
    closurePointer:pointer('release/evidence/build31-runtime-backend-deployment-closure.json'),clientPointer:pointer(api.CLIENT),
    custody:{provider:'gcs',bucket:'crm3-baf-ops-b8638-firestore-restore',
      objectName:`release-custody/build-31/runtime-backend/${M}/synthetic/private-replay-bundle.json`,generation:'123',bytes:1,sha256:H},
    producerBindings:producers,membersSha256:H,relocationSha256:api.sha(Buffer.from(api.canonical(relocation))),historicalBaseline:api.HISTORICAL};
  return bind({descriptor,bundle});
}
function bind(value){
  const {descriptor,bundle}=value;
  descriptor.expandedBytes=bundle.members.reduce((n,m)=>n+m.bytes,0);
  descriptor.membersSha256=api.sha(Buffer.from(api.canonical(Object.fromEntries(bundle.members.map(m=>[m.path,{bytes:m.bytes,sha256:m.sha256}])))));
  descriptor.relocationSha256=api.sha(Buffer.from(api.canonical(bundle.relocation)));
  value.bytes=Buffer.from(JSON.stringify(bundle));descriptor.custody.bytes=value.bytes.length;descriptor.custody.sha256=api.sha(value.bytes);return value;
}
test('complete synthetic descriptor and exact bundle bytes verify without authority',()=>{
  const m=material();assert.equal(api.validateDescriptor(m.descriptor),m.descriptor);
  assert.equal(api.verifyBundleBytes(m.bytes,m.descriptor).records.length,1);
});
for(const [name,mutate] of [
  ['unknown public descriptor field',d=>d.rawIam={}],['wrong schema',d=>d.schemaVersion=1],
  ['wrong source identity',d=>d.source.commit='wrong'],['cross-project bucket',d=>d.custody.bucket='other'],
  ['live object alias',d=>d.custody.generation='latest'],['zero generation',d=>d.custody.generation='0'],
  ['changed fixed object scope',d=>d.custody.objectName='other/private.json'],
  ['numeric instead of string generation',d=>d.custody.generation=123],
  ['unbounded object',d=>d.custody.bytes=1024**3],['wrong original baseline',d=>d.historicalBaseline={...d.historicalBaseline,sha256:H}],
  ['missing source-bound caller',d=>delete d.producerBindings['tools/release/Test-ProductionReleaseManifest.ps1']],
  ['outside producer path',d=>d.producerBindings['elsewhere/helper.cjs']=H],
  ['wrong client record',d=>d.clientPointer.file='other.json'],
]) test('descriptor rejects '+name,()=>{const m=material();mutate(m.descriptor);assert.throws(()=>api.validateDescriptor(m.descriptor));});
for(const name of ['../escape','C:/escape','a\\b','/absolute','a/../b','con','a/COM1.txt','a//b'])
  test('bundle rejects path '+name,()=>{const m=material();m.bundle.members[0].path=name;bind(m);assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));});
for(const [name,mutate] of [
  ['case-colliding members',b=>b.members.push({...b.members[0],path:'AUTHORITY/closure.json'})],
  ['file-directory collision',b=>b.members.push({...b.members[0],path:'authority'})],
  ['unknown member fields',b=>b.members[0].symlink='outside'],
  ['noncanonical base64',b=>b.members[0].base64+='!'],['member hash mismatch',b=>b.members[0].sha256=H],
  ['member size mismatch',b=>b.members[0].bytes++],['source mismatch',b=>b.source={...b.source,commit:'d'.repeat(40)}],
]) test('bundle rejects '+name,()=>{const m=material();mutate(m.bundle);bind(m);assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));});
test('bundle inventory and relocation commitments cannot be replaced',()=>{
  for(const field of ['membersSha256','relocationSha256']){const m=material();m.descriptor[field]=H;assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));}
});
test('private package material accepts ordinary scoped npm paths',()=>{
  const m=material();m.bundle.members[0].path='runtime/node_modules/@grpc/grpc-js/package.json';bind(m);
  assert.equal(api.verifyBundleBytes(m.bytes,m.descriptor).records[0].file,m.bundle.members[0].path);
});
test('extraction preserves regular member bytes and refuses reused destination',()=>{
  const m=material(),parent=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'crm3-replay-extract-test-'));
  const destination=path.join(parent,'fresh');const result=api.extractVerifiedBundle(m.bytes,m.descriptor,destination);
  assert.equal(api.sha(fs.readFileSync(path.join(result.root,'authority/closure.json'))),m.bundle.members[0].sha256);
  assert.throws(()=>api.extractVerifiedBundle(m.bytes,m.descriptor,destination));
});
function backend(d){return{source:d.source,approvalPointer:d.approvalPointer,closurePointer:d.closurePointer,
  completedAtUtc:'2026-09-01T00:00:00Z',recordedAtUtc:'2026-09-01T00:01:00Z',fleet:{callables:13,events:5,schedulers:1,total:19},
  preserved:{rules:true,indexes:true,iam:true,enforcement:true,businessLogic:true},
  appCheck:{clientRequired:true,androidProvider:'playIntegrity',mutatingEnforcementChanged:false},
  rawProofCommitment:{descriptorSha256:H,membersSha256:d.membersSha256,relocationSha256:d.relocationSha256}};}
test('sanitized current backend has an exact allowlist and no authority flags',()=>{
  const m=material();assert.equal(api.validateCurrentBackend(backend(m.descriptor),m.descriptor,H).fleet.total,19);
  for(const mutate of [b=>b.rawIam={},b=>b.deploymentAuthorized=true,b=>b.fleet.total=20,b=>b.preserved.rules=false,
    b=>b.preserved.iam=1,b=>b.appCheck.mutatingEnforcementChanged=true,b=>b.recordedAtUtc='2099-01-01T00:00:00Z',
    b=>b.rawProofCommitment.descriptorSha256='B'.repeat(64)]) {
    const b=backend(m.descriptor);mutate(b);assert.throws(()=>api.validateCurrentBackend(b,m.descriptor,H));
  }
});
async function fakeNetwork(responses,action){
  const original=https.get,calls=[];
  https.get=(options,callback)=>{calls.push(options);const request=new EventEmitter();request.destroy=()=>{};
    const item=responses.shift();setImmediate(()=>{const response=new EventEmitter();response.statusCode=item.status??200;response.resume=()=>{};
      callback(response);if(response.statusCode===200){response.emit('data',item.bytes);response.emit('end');}});return request;};
  try{return await action(calls);}finally{https.get=original;}
}
function metadata(m){return Buffer.from(JSON.stringify({bucket:m.descriptor.custody.bucket,name:m.descriptor.custody.objectName,generation:'123',size:String(m.bytes.length)}));}
test('authenticated fetch uses fixed Google host and same exact generation for metadata and bytes',async()=>{
  const m=material();await fakeNetwork([{bytes:metadata(m)},{bytes:m.bytes}],async calls=>{
    assert.deepEqual(await api.downloadExactGeneration(m.descriptor,TOKEN),m.bytes);assert.equal(calls.length,2);
    for(const call of calls){assert.equal(call.hostname,'storage.googleapis.com');assert.equal(call.port,443);assert.equal(call.method,'GET');assert.match(call.path,/\?generation=123/);assert.equal(call.headers.Authorization,'Bearer '+TOKEN);}
    assert.match(calls[1].path,/&alt=media$/);
  });
});
for(const [name,response] of [['redirect',{status:302}],['unauthorized',{status:403}],['server error',{status:500}]])
  test('authenticated fetch rejects '+name,async()=>{const m=material();await fakeNetwork([response],async()=>assert.rejects(api.downloadExactGeneration(m.descriptor,TOKEN)));});
test('fetch rejects changed generation before requesting media',async()=>{
  const m=material(),changed=JSON.parse(metadata(m));changed.generation='124';
  await fakeNetwork([{bytes:Buffer.from(JSON.stringify(changed))}],async calls=>{await assert.rejects(api.downloadExactGeneration(m.descriptor,TOKEN));assert.equal(calls.length,1);});
});
test('fetch rejects changed committed bytes and bounds response size',async()=>{
  for(const raw of [Buffer.alloc(material().bytes.length),Buffer.alloc(material().bytes.length+1)]){
    const m=material();await fakeNetwork([{bytes:metadata(m)},{bytes:raw}],async()=>assert.rejects(api.downloadExactGeneration(m.descriptor,TOKEN)));
  }
});
test('missing credential fails without any request and never accepts a local receipt',async()=>{
  const m=material();await fakeNetwork([],async calls=>{await assert.rejects(api.downloadExactGeneration(m.descriptor,''));assert.equal(calls.length,0);});
});

function setPayload(m,raw){const member=m.bundle.members[0],encoded=gzipSync(raw);Object.assign(member,{bytes:raw.length,sha256:api.sha(raw),compressedBytes:encoded.length,compressedSha256:api.sha(encoded),base64:encoded.toString('base64')});return bind(m);}
test('valid gzip empty member uses finite nonzero decompression limit',()=>{const m=setPayload(material(),Buffer.alloc(0));assert.equal(api.verifyBundleBytes(m.bytes,m.descriptor).records[0].raw.length,0);});
for(const[name,mutate]of[
 ['old bundle schema',m=>m.bundle.schemaVersion=1],['wrong bundle encoding',m=>m.bundle.encoding='identity'],
 ['wrong member encoding',m=>m.bundle.members[0].encoding='deflate'],['compressed size mismatch',m=>m.bundle.members[0].compressedBytes++],
 ['compressed hash mismatch',m=>m.bundle.members[0].compressedSha256=H],['per-member expanded limit',m=>m.bundle.members[0].bytes=api.MAX_MEMBER+1],
 ['negative expanded length',m=>m.bundle.members[0].bytes=-1],['fractional expanded length',m=>m.bundle.members[0].bytes=1.5],
])test('compressed bundle rejects '+name,()=>{const m=material();mutate(m);bind(m);assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));});
test('gzip expansion ratio is rejected before decompression',()=>{const m=setPayload(material(),Buffer.alloc(1024*1024));assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor),/bounded private member/);});
test('descriptor expanded population cannot lie or exceed aggregate bound',()=>{for(const size of [api.MAX_EXPANDED+1,1]){const m=material();m.descriptor.expandedBytes=size;assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));}});
test('actual gzip expansion cannot exceed its declared finite size',()=>{const m=setPayload(material(),Buffer.from('a'.repeat(2048)));m.bundle.members[0].bytes=1;bind(m);assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));});
test('truncated gzip with rehashed compressed metadata is rejected',()=>{const m=material(),member=m.bundle.members[0],short=Buffer.from(member.base64,'base64').subarray(0,-5);Object.assign(member,{compressedBytes:short.length,compressedSha256:api.sha(short),base64:short.toString('base64')});bind(m);assert.throws(()=>api.verifyBundleBytes(m.bytes,m.descriptor));});


test('pinned npm backup filenames retain literal tilde through verified extraction',()=>{
 const m=material();const names=['.editorconfig~','index.js~','test/test.js~'];
 m.bundle.members=names.map(name=>({...m.bundle.members[0],path:'runtime/node_modules/json-parse-helpfulerror/'+name}));bind(m);
 const parent=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'crm3-replay-tilde-test-'));
 const result=api.extractVerifiedBundle(m.bytes,m.descriptor,path.join(parent,'fresh'));
 for(const member of m.bundle.members) assert.equal(api.sha(fs.readFileSync(path.join(result.root,member.path))),member.sha256);
 assert.equal(result.inventory && Object.keys(result.inventory).length,3);
});

function packedGitMaterial(){
 const {execFileSync}=require('node:child_process'),parent=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'crm31-packed-refs-')),source=path.join(parent,'original');fs.mkdirSync(source);
 const git=(root,...args)=>execFileSync('git',['-C',root,...args],{encoding:'utf8',windowsHide:true});git(source,'init','-q');git(source,'config','user.name','Synthetic fixture');git(source,'config','user.email','fixture@example.invalid');fs.writeFileSync(path.join(source,'proof.txt'),'exact synthetic source\n');git(source,'add','.');git(source,'commit','-qm','synthetic');const head=git(source,'rev-parse','HEAD').trim();git(source,'checkout','--detach','-q');git(source,'pack-refs','--all','--prune');
 const m=material();m.bundle.members=[];function walk(directory){for(const item of fs.readdirSync(directory,{withFileTypes:true})){const file=path.join(directory,item.name);if(item.isDirectory())walk(file);else{const raw=fs.readFileSync(file),encoded=gzipSync(raw);m.bundle.members.push({path:'repository/'+path.relative(source,file).split(path.sep).join('/'),bytes:raw.length,sha256:api.sha(raw),encoding:'gzip',compressedBytes:encoded.length,compressedSha256:api.sha(encoded),base64:encoded.toString('base64')});}}}walk(source);bind(m);assert(!m.bundle.members.some(row=>row.path.startsWith('repository/.git/refs/')));return{m,parent,head,git};
}
test('packed Git refs retain native repository recognition after file-only extraction',()=>{const{m,parent,head,git}=packedGitMaterial();const result=api.extractVerifiedBundle(m.bytes,m.descriptor,path.join(parent,'extracted'));assert.equal(git(path.join(result.root,'repository'),'rev-parse','HEAD').trim(),head);assert(fs.statSync(path.join(result.root,'repository/.git/refs')).isDirectory());for(const member of m.bundle.members)assert.equal(api.sha(fs.readFileSync(path.join(result.root,member.path))),member.sha256);});
test('derived Git refs directory refuses an immutable file collision',()=>{const{m,parent}=packedGitMaterial();m.bundle.members.push({...m.bundle.members[0],path:'repository/.git/refs'});bind(m);assert.throws(()=>api.extractVerifiedBundle(m.bytes,m.descriptor,path.join(parent,'collision')),/Git refs must remain a directory/);});
