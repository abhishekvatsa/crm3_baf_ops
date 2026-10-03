'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const crypto=require('node:crypto'),https=require('node:https');
const {gzipSync}=require('node:zlib'),{EventEmitter}=require('node:events');
const api=require('./privateEvidenceBundle31.cjs');
const old=require('./runtimeBackendPrivateReplay31.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const canonical=old.canonical;
const TOKEN='synthetic-unprivileged-local-test-token';
function bind(m){
 m.descriptor.expandedBytes=m.bundle.members.reduce((n,r)=>n+r.bytes,0);
 const inventory=Object.fromEntries(m.bundle.members.map(r=>[r.path,{bytes:r.bytes,sha256:r.sha256}]));
 m.descriptor.membersSha256=sha(Buffer.from(canonical(inventory)));
 m.descriptor.relocationSha256=sha(Buffer.from(canonical(m.bundle.relocation)));
 m.bytes=Buffer.from(JSON.stringify(m.bundle));
 Object.assign(m.descriptor.custody,{bytes:m.bytes.length,sha256:sha(m.bytes)});return m;
}
function fixture(kind='business'){
 const raw=Buffer.from('Synthetic exact evidence; no deployment or credential authority.'),z=gzipSync(raw);
 const source={commit:'a'.repeat(40),tree:'b'.repeat(40),functionsTree:'c'.repeat(40)};
 const descriptor={bundleEncoding:api.BUNDLE_ENCODING,expandedBytes:0,source,membersSha256:'',relocationSha256:'',
  custody:{provider:'gcs',bucket:api.BUCKET,objectName:`release-custody/build-31/${kind}-backend/${source.commit}/synthetic/private-replay-bundle.json`,generation:'123',bytes:1,sha256:'A'.repeat(64)}};
 const bundle={schemaVersion:2,encoding:api.BUNDLE_ENCODING,documentType:`build31-private-${kind}-evidence-bundle`,source,
  members:[{path:'original/evidence.json',bytes:raw.length,sha256:sha(raw),encoding:'gzip',compressedBytes:z.length,compressedSha256:sha(z),base64:z.toString('base64')}],
  relocation:{schemaVersion:1,roots:[],files:[]}};
 return bind({descriptor,bundle,raw});
}
for(const kind of ['runtime','business']) test(kind+' exact byte custody works without an authority verdict',()=>{
 const m=fixture(kind),r=api.verifyBundleBytes31(m.bytes,m.descriptor,kind);
 assert.deepEqual(r.records[0].raw,m.raw);
 for(const key of ['ok','deploymentAuthorized','credentialAccessAuthorized','constructionAuthorized'])assert.equal(Object.hasOwn(r,key),false);
});
for(const [name,mutate]of[
 ['another project',d=>d.custody.bucket='untrusted'],
 ['another source',d=>d.source.commit='d'.repeat(40)],
 ['unbound generation alias',d=>d.custody.generation='latest'],
 ['query injection',d=>d.custody.objectName+='?alt=media'],
 ['unbounded bytes',d=>d.custody.bytes=api.MAX_BUNDLE+1],
 ['negative expanded bound',d=>d.expandedBytes=-1],
 ['invalid source',d=>d.source.tree='invalid'],
 ['custody extra host',d=>d.custody.host='evil.invalid'],
])test('neutral transport rejects '+name,()=>{const m=fixture();mutate(m.descriptor);assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,'business'));});
test('cross-profile bundle and namespace substitution fails even with rehashed custody',()=>{
 for(const kind of ['runtime','business']){const m=fixture(kind),other=kind==='runtime'?'business':'runtime';
  assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,other));
  m.bundle.documentType=`build31-private-${other}-evidence-bundle`;bind(m);
  assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,kind),/Unsupported private bundle/);
 }
});
test('arbitrary kind and fallback are rejected',()=>{
 const m=fixture();for(const kind of [undefined,'','constructor','toString','unknown'])assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,kind));
});
test('business descriptor cannot become the historical runtime profile',()=>{
 const m=fixture();assert.throws(()=>old.validateDescriptor(m.descriptor));
 assert.throws(()=>old.verifyBundleBytes(m.bytes,m.descriptor));
});
test('business extraction retains exact bytes and refuses destination reuse',()=>{
 const m=fixture(),parent=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'crm31-business-bundle-'));
 const target=path.join(parent,'fresh'),r=api.extractVerifiedBundle31(m.bytes,m.descriptor,target,'business');
 assert.deepEqual(fs.readFileSync(path.join(r.root,'original/evidence.json')),m.raw);
 assert.throws(()=>api.extractVerifiedBundle31(m.bytes,m.descriptor,target,'business'));
});
test('rehashed unsafe members remain refused before extraction',()=>{
 for(const file of ['../escape','a\\b','/absolute','con','a/COM1.txt']){
  const m=fixture();m.bundle.members[0].path=file;bind(m);assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,'business'));
 }
});
async function network(items,fn){const original=https.get,calls=[];
 https.get=(options,cb)=>{calls.push(options);const req=new EventEmitter();req.destroy=()=>{};
  const item=items.shift();setImmediate(()=>{const res=new EventEmitter();res.statusCode=item.status??200;res.resume=()=>{};cb(res);if(res.statusCode===200){res.emit('data',item.bytes);res.emit('end');}});return req;};
 try{return await fn(calls);}finally{https.get=original;}
}
function meta(m){return Buffer.from(JSON.stringify({bucket:api.BUCKET,name:m.descriptor.custody.objectName,generation:'123',size:String(m.bytes.length)}));}
test('business fetch shares fixed-host exact-generation transport',async()=>{
 const m=fixture();await network([{bytes:meta(m)},{bytes:m.bytes}],async calls=>{
  assert.deepEqual(await api.downloadExactGeneration31(m.descriptor,TOKEN,'business'),m.bytes);assert.equal(calls.length,2);
  for(const c of calls){assert.equal(c.hostname,'storage.googleapis.com');assert.equal(c.method,'GET');assert.match(c.path,/\?generation=123/);assert.equal(c.headers.Authorization,'Bearer '+TOKEN);}
 });
});
test('invalid business scope and unavailable token make zero requests',async()=>{
 for(const token of ['',TOKEN]){const m=fixture();if(token)m.descriptor.custody.bucket='another-project';
  await network([],async calls=>{await assert.rejects(api.downloadExactGeneration31(m.descriptor,token,'business'));assert.equal(calls.length,0);});
 }
});
test('business fetch refuses redirect and changed metadata generation',async()=>{
 const m=fixture();await network([{status:302}],async()=>assert.rejects(api.downloadExactGeneration31(m.descriptor,TOKEN,'business')));
 const changed=JSON.parse(meta(m));changed.generation='124';
 await network([{bytes:Buffer.from(JSON.stringify(changed))}],async calls=>{await assert.rejects(api.downloadExactGeneration31(m.descriptor,TOKEN,'business'));assert.equal(calls.length,1);});
});
test('shared helper is an explicit old-route producer binding',()=>assert(old.CORE_PRODUCERS.includes('tools/release/privateEvidenceBundle31.cjs')));

test('portable member identity rejects differently cased directory prefixes',()=>{
 for(const kind of ['runtime','business']){
  const m=fixture(kind);m.bundle.members=[{...m.bundle.members[0],path:'A/one'},{...m.bundle.members[0],path:'a/two'}];bind(m);
  assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,kind),/prefix case collision/);
 }
});
test('portable member identity rejects trailing-dot components before extraction',()=>{
 for(const kind of ['runtime','business'])for(const file of ['a./file','a/file.']){
  const m=fixture(kind);m.bundle.members[0].path=file;bind(m);
  assert.throws(()=>api.verifyBundleBytes31(m.bytes,m.descriptor,kind),/Unsafe portable member/);
 }
});
