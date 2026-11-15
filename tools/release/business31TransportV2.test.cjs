'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {gzipSync}=require('node:zlib');
const api=require('./privateEvidenceBundle31V2.cjs'),oldTransport=require('./privateEvidenceBundle31.cjs'),legacy=require('./business31OriginalPathReplay.cjs'),worker=require('./business31CoreWorkerV2.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase(),canonical=worker.canonical;
function fixture(count=1){
 const raw=Buffer.from('synthetic bytes'),z=gzipSync(raw),member={bytes:raw.length,sha256:sha(raw),encoding:'gzip',compressedBytes:z.length,compressedSha256:sha(z),base64:z.toString('base64')};
 const source={commit:'a'.repeat(40),tree:'b'.repeat(40),functionsTree:'c'.repeat(40)};
 const bundle={schemaVersion:3,documentType:'build31-private-business-evidence-bundle',encoding:'gzip-members-v2',source,
  members:Array.from({length:count},(_,i)=>({path:'retained/m'+i,...member})),relocation:{schemaVersion:1,roots:[],files:[]}};
 const descriptor={source,bundleEncoding:'gzip-members-v2',expandedBytes:0,membersSha256:'',relocationSha256:'',custody:{provider:'gcs',bucket:api.BUCKET,
  objectName:'release-custody/build-31/business-backend/'+source.commit+'/synthetic/private-replay-bundle.json',generation:'1',bytes:1,sha256:'A'.repeat(64)}};
 return bind({bundle,descriptor});
}
function bind(f){f.descriptor.expandedBytes=f.bundle.members.reduce((n,m)=>n+m.bytes,0);f.descriptor.membersSha256=sha(Buffer.from(canonical(Object.fromEntries(f.bundle.members.map(m=>[m.path,{bytes:m.bytes,sha256:m.sha256}])))));
 f.descriptor.relocationSha256=sha(Buffer.from(canonical(f.bundle.relocation)));f.bytes=Buffer.from(JSON.stringify(f.bundle));Object.assign(f.descriptor.custody,{bytes:f.bytes.length,sha256:sha(f.bytes)});return f;}
test('explicit business successor accepts 53000 and legacy still refuses above 50000',()=>{
 const f=fixture(53000);assert.equal(api.verifyBundleBytesV2(f.bytes,f.descriptor,'business').records.length,53000);
 f.bundle.schemaVersion=2;f.bundle.encoding=f.descriptor.bundleEncoding='gzip-members-v1';bind(f);
 assert.throws(()=>oldTransport.verifyBundleBytes31(f.bytes,f.descriptor,'business'),/member population/);
});
test('successor refuses 53001 before member decoding and never accepts runtime kind',()=>{
 const f=fixture(53001);assert.throws(()=>api.verifyBundleBytesV2(f.bytes,f.descriptor,'business'),/member population/);
 for(const kind of ['runtime',undefined,'constructor'])assert.throws(()=>api.verifyBundleBytesV2(f.bytes,f.descriptor,kind),/business-only/);
});
test('encoding/schema pairs are closed and have no legacy fallback',()=>{
 const f=fixture();assert.throws(()=>oldTransport.verifyBundleBytes31(f.bytes,f.descriptor,'business'));
 for(const [version,encoding]of [[2,'gzip-members-v2'],[3,'gzip-members-v1'],[2,'gzip-members-v1']]){
  f.bundle.schemaVersion=version;f.bundle.encoding=encoding;bind(f);assert.throws(()=>api.verifyBundleBytesV2(f.bytes,f.descriptor,'business'),/Unsupported private bundle/);
 }
});
test('successor retains serialized expanded per-member and ratio caps',()=>{
 for(const mutate of [f=>f.descriptor.custody.bytes=api.MAX_BUNDLE+1,f=>f.descriptor.expandedBytes=api.MAX_EXPANDED+1]){
  const f=fixture();mutate(f);assert.throws(()=>api.validateTransportDescriptorV2(f.descriptor,'business'));
 }
 for(const bytes of [api.MAX_MEMBER+1,100000]){const f=fixture();f.bundle.members[0].bytes=bytes;bind(f);assert.throws(()=>api.verifyBundleBytesV2(f.bytes,f.descriptor,'business'),/bounded private member/);}
 assert.equal(api.MAX_BUNDLE,512*1024*1024);assert.equal(api.MAX_EXPANDED,1024*1024*1024);assert.equal(api.MAX_MEMBER,128*1024*1024);
});
test('relocation guard remains 16 roots and 50000 individual files',()=>{
 const roles={authorityRoot:'/absent',executionRoot:'/absent',evidenceDirectory:'/absent'};
 for(const relocation of [{schemaVersion:1,roots:Array(17).fill({}),files:[],roles},{schemaVersion:1,roots:[{}],files:Array(50001).fill({}),roles}])assert.throws(()=>legacy.validateRelocation31(relocation,{}),/finite relocation/);
});
