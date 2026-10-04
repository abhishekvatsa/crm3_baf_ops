'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{gzipSync}=require('node:zlib');
const subject=require('./business31OriginalPathReplay.cjs');
const transport=require('./privateEvidenceBundle31.cjs');
const access=require('./backendRuntimeEvidenceAccess31.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const canonical=v=>Array.isArray(v)?'['+v.map(canonical).join(',')+']':v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'business31-original-path-'));
// Unique synthetic evidence is retained after a failure for diagnosis.
const absent=path.join(root,'originals-never-created'),map={
  schemaVersion:1,roots:[{original:absent,memberRoot:'retained'}],files:[],
  roles:{authorityRoot:absent,executionRoot:absent,evidenceDirectory:absent}
};
const raw=Buffer.from('{"original":"bytes retained without rewriting an identity"}\n'),compressed=gzipSync(raw);
const inventory={'retained/original.json':{bytes:raw.length,sha256:sha(raw)}};
const source={commit:'1'.repeat(40),tree:'2'.repeat(40),functionsTree:'3'.repeat(40)};
function fixture(relocation=structuredClone(map),members=[{path:'retained/original.json',bytes:raw.length,sha256:sha(raw),encoding:'gzip',compressedBytes:compressed.length,compressedSha256:sha(compressed),base64:compressed.toString('base64')}]) {
  const inventory=Object.fromEntries(members.map(m=>[m.path,{bytes:m.bytes,sha256:m.sha256}]));
  const bundle={schemaVersion:2,documentType:'build31-private-business-evidence-bundle',encoding:'gzip-members-v1',source,members,relocation};
  const bytes=Buffer.from(JSON.stringify(bundle));return {bytes,descriptor:{source,bundleEncoding:'gzip-members-v1',expandedBytes:members.reduce((n,m)=>n+m.bytes,0),membersSha256:sha(Buffer.from(canonical(inventory))),relocationSha256:sha(Buffer.from(canonical(relocation))),custody:{provider:'gcs',bucket:'crm3-baf-ops-b8638-firestore-restore',objectName:'release-custody/build-31/business-backend/'+source.commit+'/test/private-replay-bundle.json',generation:'1',bytes:bytes.length,sha256:sha(bytes)}}};
}
const bindings=Object.fromEntries(subject.REQUIRED_EXECUTING.map(file=>[file,'A'.repeat(64)]));
test('required npm-bin materializer has exact executing bytes before any closure subset',()=>{
 const materializer='tools/release/business31NpmBinMaterialization.cjs',modulePath=require.resolve('./business31NpmBinMaterialization.cjs');
 assert.equal(require.cache[modulePath],undefined);
 assert.ok(subject.CLOSURE_PRODUCERS.includes(materializer));assert.ok(subject.REQUIRED_EXECUTING.includes(materializer));assert.ok(require('./business31PrivateDescriptor.cjs').CORE.includes(materializer));
 const complete=Object.fromEntries(subject.REQUIRED_EXECUTING.map(file=>[file,sha(fs.readFileSync(path.join(__dirname,path.basename(file))))]));
 assert.equal(Object.keys(subject.executingBindings31(complete)).length,subject.REQUIRED_EXECUTING.length);
 const missing={...complete};delete missing[materializer];assert.throws(()=>subject.deriveClosureProducerBindings31(missing),/full wrapper\/descriptor\/bundle population/);
 const changed={...complete,[materializer]:'0'.repeat(64)};assert.throws(()=>subject.executingBindings31(changed),/executing complete producer population differs/);
 assert.equal(require.cache[modulePath],undefined);
});

test('closure population is precisely the required29 subset, with unchanged digests',()=>{
  const actual=require('./business31BackendAuthority.cjs').PRODUCERS;assert.deepEqual(actual,subject.CLOSURE_PRODUCERS);assert.equal(actual.length,29);
  const full={...bindings,'tools/release/another-controller.cjs':'F'.repeat(64)},subset=subject.deriveClosureProducerBindings31(full);
  assert.deepEqual(Object.keys(subset),actual);for(const file of actual)assert.equal(subset[file],full[file]);assert.equal(full['tools/release/another-controller.cjs'],'F'.repeat(64));
});
test('the exact closure29 alone cannot masquerade as complete descriptor authority',()=>{
  const narrowed=Object.fromEntries(subject.CLOSURE_PRODUCERS.map(f=>[f,bindings[f]]));assert.throws(()=>subject.deriveClosureProducerBindings31(narrowed),/full wrapper\/descriptor\/bundle population/);
});
test('missing wrapper or closure binding is rejected',()=>{
  for(const file of [subject.SELF,subject.CLOSURE_PRODUCERS[0],'tools/release/business31NpmBinMaterialization.cjs']){const value={...bindings};delete value[file];assert.throws(()=>subject.deriveClosureProducerBindings31(value));}
});
test('changed executing producer bytes fail before they could become source authority',()=>{
  assert.throws(()=>subject.executingBindings31(bindings),/executing complete producer population differs/);
});
test('complete relocation must bind every role and every member',()=>{
  assert.equal(subject.validateRelocation31(map,inventory),map);
  const noRole=structuredClone(map);delete noRole.roles.executionRoot;assert.throws(()=>subject.validateRelocation31(noRole,inventory),/roles fields differ/);
  const foreign=structuredClone(map);foreign.roles.executionRoot=path.join(root,'foreign');assert.throws(()=>subject.validateRelocation31(foreign,inventory),/one bound root/);
  assert.throws(()=>subject.validateRelocation31(map,{...inventory,'unmapped.json':inventory['retained/original.json']}),/unmapped private member/);
});
test('finite populations, unknown fields and portable traversal are refused',()=>{
  const cases=[r=>r.roots=[],r=>r.files=Array(50001).fill({}),r=>r.accessToken='not-real',r=>r.roots[0].memberRoot='../escape',r=>r.roots[0].memberRoot='retained.'];
  for(const change of cases){const v=structuredClone(map);change(v);assert.throws(()=>subject.validateRelocation31(v,inventory));}
});
test('overlapping and case-colliding original roots refuse ambiguous addressing',()=>{
  for(const other of [absent.toUpperCase(),path.join(absent,'nested')]){
    const v=structuredClone(map);v.roots.push({original:other,memberRoot:'other'});assert.throws(()=>subject.validateRelocation31(v,{...inventory,'other/item':inventory['retained/original.json']}),/duplicate|overlapping/);
  }
});
test('file maps cannot overlap a root or change a committed file digest',()=>{
  const other=path.join(root,'other-original'),binding=inventory['retained/original.json'];
  const badRoot=structuredClone(map);badRoot.files.push({original:path.join(absent,'one'),member:'single',...binding});assert.throws(()=>subject.validateRelocation31(badRoot,{...inventory,single:binding}),/overlapping original/);
  const badDigest=structuredClone(map);badDigest.files.push({original:other,member:'single',bytes:binding.bytes,sha256:'0'.repeat(64)});assert.throws(()=>subject.validateRelocation31(badDigest,{...inventory,single:binding}),/commitment differs/);
});
test('actual absent originals are required, not an unchecked caller statement',()=>{
  assert.equal(subject.originalPathsUnavailable31(map),true);const existing=path.join(root,'existing');fs.mkdirSync(existing);
  const v=structuredClone(map);v.roots[0].original=existing;assert.throws(()=>subject.originalPathsUnavailable31(v),/original path remains available/);
});
test('original-path read uses unchanged access/helper bytes and leaves JSON bytes intact',()=>{
  const f=fixture(),verified=transport.verifyBundleBytes31(f.bytes,f.descriptor,'business');subject.validateRelocation31(verified.relocation,verified.inventory);subject.originalPathsUnavailable31(verified.relocation);
  const destination=path.join(root,'extracted');const extracted=transport.extractVerifiedBundle31(f.bytes,f.descriptor,destination,'business');assert.deepEqual(subject.inventory31(extracted.root),inventory);
  const members=Object.entries(inventory).map(([p,b])=>({path:p,...b}));
  const read=access.runRelocated31({privateBundleRoot:extracted.root,relocation:map,members,evidenceDirectory:absent},()=>access.fs.readFileSync(path.join(absent,'original.json')));
  assert.deepEqual(read,raw);assert.equal(fs.existsSync(absent),false);assert.deepEqual(fs.readFileSync(path.join(destination,'retained/original.json')),raw);
  fs.writeFileSync(path.join(destination,'retained/original.json'),'changed');
  assert.throws(()=>access.runRelocated31({privateBundleRoot:extracted.root,relocation:map,members,evidenceDirectory:absent},()=>access.fs.readFileSync(path.join(absent,'original.json'))),/Relocated evidence changed/);
});
test('changed custody, compressed bytes and extra material cannot be admitted',()=>{
  const f=fixture();const bytes=Buffer.from(f.bytes);bytes[bytes.length-2]^=1;assert.throws(()=>transport.verifyBundleBytes31(bytes,f.descriptor,'business'),/immutable custody/);
  const v=JSON.parse(f.bytes);v.members[0].base64=Buffer.from('not gzip').toString('base64');const changed=Buffer.from(JSON.stringify(v)),d=structuredClone(f.descriptor);d.custody.bytes=changed.length;d.custody.sha256=sha(changed);assert.throws(()=>transport.verifyBundleBytes31(changed,d,'business'),/Compressed private member/);
  const dir=path.join(root,'extra-material');fs.mkdirSync(dir);fs.writeFileSync(path.join(dir,'extra'),'extra');assert.notDeepEqual(subject.inventory31(dir),inventory);
});
test('full entry rejects callback/PASS/token substitutes at the public input boundary',()=>{
  for(const extra of [{verifyClosure:()=>({recordedSemanticsReplayed:true})},{accessToken:'not-real'},{admission:{ok:true}}])assert.throws(()=>subject.verifyBusiness31OriginalPathReplay(extra),/input fields differ/);
});
test('full entry requires existing bounded bytes and explicit clock',()=>{
  const input={repositoryRoot:root,gitExecutable:'fake',gitSha256:'0'.repeat(64),envelope:{},descriptorPointer:{},sourceManifest:{},expectedSourceManifestSha256:'0'.repeat(64),bundleBytes:Buffer.alloc(0),extractionRoot:path.join(root,'not-created'),nowUtc:'2026-01-02T00:00:00Z'};
  assert.throws(()=>subject.verifyBusiness31OriginalPathReplay(input),/bounded existing local bundle/);input.bundleBytes=Buffer.from('x');input.nowUtc='now';assert.throws(()=>subject.verifyBusiness31OriginalPathReplay(input),/caller clock/);assert.equal(fs.existsSync(input.extractionRoot),false);
});
test('declared execution role must equal the actual retained decision runtime build root',()=>{
  const folder=path.join(root,'role-join');fs.mkdirSync(folder);fs.mkdirSync(path.join(folder,'retained'));
  function retain(name,value){const bytes=Buffer.from(JSON.stringify(value));fs.writeFileSync(path.join(folder,'retained',name),bytes);return {file:name,bytes:bytes.length,sha256:sha(bytes)};}
  const proof=retain('runtime.json',{buildRoot:absent}),decision=retain('decision.json',{runtimeProof:proof});
  const original=Buffer.from(JSON.stringify({privateRecord:decision})),descriptor={approvalPointer:{sha256:sha(original)}};
  const members=Object.entries(subject.inventory31(folder)).map(([p,b])=>({path:p,...b}));
  access.runRelocated31({privateBundleRoot:folder,relocation:map,members,evidenceDirectory:absent},()=>{
    assert.equal(subject.joinOriginalExecutionRoot31({decisionEnvelopeBytes:original,descriptor,relocation:map}),true);
    const bad=structuredClone(map);bad.roles.executionRoot=path.join(absent,'wrong');
    assert.throws(()=>subject.joinOriginalExecutionRoot31({decisionEnvelopeBytes:original,descriptor,relocation:bad}),/runtime buildRoot/);
    assert.throws(()=>subject.joinOriginalExecutionRoot31({decisionEnvelopeBytes:Buffer.from('{}'),descriptor,relocation:map}),/decision envelope differs/);
  });
});
test('filesystem inventory owns special names and detects every changed removed or added file',()=>{
 const folder=path.join(root,'special-inventory');fs.mkdirSync(path.join(folder,'nested'),{recursive:true});
 const names=['__proto__','constructor','toString','hasOwnProperty','nested/__proto__','nested/constructor','nested/toString','nested/hasOwnProperty'];
 const originals=new Map(names.map((name,index)=>[name,Buffer.from('original '+index)]));
 for(const [name,bytes]of originals)fs.writeFileSync(path.join(folder,name),bytes);
 const expected=Object.fromEntries([...originals].map(([name,bytes])=>[name,{bytes:bytes.length,sha256:sha(bytes)}]));
 const before=subject.inventory31(folder);assert.equal(Object.getPrototypeOf(before),Object.prototype);assert.deepEqual(before,expected);assert.equal(Object.keys(before).length,names.length);
 for(const name of names)assert.equal(Object.hasOwn(before,name),true);
 assert.deepEqual(subject.inventory31(folder),before);
 for(const [name,bytes]of originals){
  fs.writeFileSync(path.join(folder,name),'mutated');assert.notDeepEqual(subject.inventory31(folder),before);
  fs.unlinkSync(path.join(folder,name));assert.notDeepEqual(subject.inventory31(folder),before);
  fs.writeFileSync(path.join(folder,name),bytes);assert.deepEqual(subject.inventory31(folder),before);
 }
 const extra=path.join(root,'added-proto-inventory');fs.mkdirSync(extra);fs.writeFileSync(path.join(extra,'ordinary'),'original');const initial=subject.inventory31(extra);
 fs.writeFileSync(path.join(extra,'__proto__'),'extra');const after=subject.inventory31(extra);assert.notDeepEqual(after,initial);assert.equal(Object.keys(after).length,Object.keys(initial).length+1);assert.equal(Object.hasOwn(after,'__proto__'),true);
});
test('complete special-name bundle inventory joins original-path extraction and guarded reads',()=>{
 const names=['retained/original.json','__proto__','constructor','toString','hasOwnProperty','retained/__proto__','retained/constructor','retained/toString','retained/hasOwnProperty'];
 const members=names.map((name,index)=>{const bytes=Buffer.from('exact original '+index),z=gzipSync(bytes);return {path:name,bytes:bytes.length,sha256:sha(bytes),encoding:'gzip',compressedBytes:z.length,compressedSha256:sha(z),base64:z.toString('base64')};});
 const relocation=structuredClone(map);relocation.files=members.filter(m=>!m.path.includes('/')).map((m,index)=>({original:path.join(root,'absent-special-'+index),member:m.path,bytes:m.bytes,sha256:m.sha256}));
 const f=fixture(relocation,members),verified=transport.verifyBundleBytes31(f.bytes,f.descriptor,'business');subject.validateRelocation31(verified.relocation,verified.inventory);subject.originalPathsUnavailable31(verified.relocation);
 const extracted=transport.extractVerifiedBundle31(f.bytes,f.descriptor,path.join(root,'special-extracted'),'business');assert.deepEqual(subject.inventory31(extracted.root),verified.inventory);assert.equal(Object.keys(verified.inventory).length,members.length);
 const bound=Object.entries(verified.inventory).map(([name,binding])=>({path:name,...binding}));assert.equal(bound.length,members.length);
 access.runRelocated31({privateBundleRoot:extracted.root,relocation,members:bound,evidenceDirectory:absent},()=>{
  for(const entry of relocation.files)assert.equal(sha(access.fs.readFileSync(entry.original)),entry.sha256);
  const proto=relocation.files.find(entry=>entry.member==='__proto__');fs.writeFileSync(path.join(extracted.root,'__proto__'),'changed');
  assert.throws(()=>access.fs.readFileSync(proto.original),/Relocated evidence changed/);
 });
 assert.notDeepEqual(subject.inventory31(extracted.root),verified.inventory);
});
