'use strict';

// Byte custody and transport only. Calling profile validators must separately
// authenticate the descriptor and replay its originals. No result here grants
// deployment, credential, client-compatibility or construction authority.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const crypto = require('node:crypto');
const {gunzipSync} = require('node:zlib');
const {isDeepStrictEqual} = require('node:util');
const BUCKET = 'crm3-baf-ops-b8638-firestore-restore';
const MAX_BUNDLE = 512 * 1024 * 1024;
const MAX_MEMBERS = 50000;
const MAX_EXPANDED = 1024 * 1024 * 1024;
const MAX_MEMBER = 128 * 1024 * 1024;
const BUNDLE_ENCODING = 'gzip-members-v1';
const KINDS = Object.freeze({
  runtime: Object.freeze({namespace:'runtime-backend', documentType:'build31-private-runtime-evidence-bundle'}),
  business: Object.freeze({namespace:'business-backend', documentType:'build31-private-business-evidence-bundle'}),
});
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(value, message) { if (!value) throw new Error(message); }
function same(a,b,message) { need(isDeepStrictEqual(a,b),message); }
function keys(value,names,label) {
  need(value && typeof value==='object' && !Array.isArray(value),label+' must be an object');
  same(Object.keys(value).sort(),[...names].sort(),label+' fields differ');
}
function canonical(value) {
  if (Array.isArray(value)) return '['+value.map(canonical).join(',')+']';
  if (value && typeof value==='object') return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
  return JSON.stringify(value);
}
function relative(value) {
  need(typeof value==='string' && value.length<=400 && /^[A-Za-z0-9_@+.~/-]+$/.test(value) &&
    !value.startsWith('/') && value.split('/').every(p=>p && p!=='.' && p!=='..' && !/[. ]$/.test(p) &&
      !/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)), 'Unsafe portable member path');
  return value;
}

function validateTransportDescriptor31(value,kind) {
  need(typeof kind==='string' && Object.hasOwn(KINDS,kind),'Unsupported private bundle kind');
  need(value && typeof value==='object' && !Array.isArray(value),'Private transport descriptor required');
  need(value.bundleEncoding===BUNDLE_ENCODING && Number.isSafeInteger(value.expandedBytes) &&
    value.expandedBytes>=0 && value.expandedBytes<=MAX_EXPANDED,'Invalid expanded private bundle bound');
  keys(value.source,['commit','tree','functionsTree'],'Source');
  for(const hash of Object.values(value.source)) need(typeof hash==='string' && /^[a-f0-9]{40}$/.test(hash),'Invalid immutable source identity');
  keys(value.custody,['provider','bucket','objectName','generation','bytes','sha256'],'Private custody');
  const c=value.custody;
  need(c.provider==='gcs' && c.bucket===BUCKET &&
    new RegExp('^release-custody/build-31/'+KINDS[kind].namespace+'/'+value.source.commit+'/[A-Za-z0-9][A-Za-z0-9._-]{0,127}/private-replay-bundle\\.json$').test(c.objectName) &&
    typeof c.generation==='string' && /^[1-9][0-9]*$/.test(c.generation) && Number.isSafeInteger(c.bytes) &&
    c.bytes>0 && c.bytes<=MAX_BUNDLE && typeof c.sha256==='string' && /^[A-F0-9]{64}$/.test(c.sha256),
    'Private custody must name one bounded exact generation');
  for(const key of ['membersSha256','relocationSha256']) need(typeof value[key]==='string' && /^[A-F0-9]{64}$/.test(value[key]),'Invalid bundle commitment');
  return value;
}
function verifyBundleBytes31(bytes,descriptor,kind) {
  validateTransportDescriptor31(descriptor,kind);
  need(Buffer.isBuffer(bytes) && bytes.length===descriptor.custody.bytes && sha(bytes)===descriptor.custody.sha256,
    'Private bundle bytes differ from immutable custody');
  const bundle=JSON.parse(bytes.toString('utf8'));
  keys(bundle,['schemaVersion','documentType','encoding','source','members','relocation'],'Private bundle');
  need(bundle.schemaVersion===2 && bundle.encoding===BUNDLE_ENCODING && bundle.documentType===KINDS[kind].documentType,
    'Unsupported private bundle; no encoding fallback is permitted');
  same(bundle.source,descriptor.source,'Private bundle source differs');
  need(Array.isArray(bundle.members) && bundle.members.length>0 && bundle.members.length<=MAX_MEMBERS,'Invalid private member population');
  const seen=new Set(), prefixes=new Map(), inventory={}, records=[], compressed=[];
  let declaredTotal=0;
  // Validate the entire declared population before any decompression.
  for (const member of bundle.members) {
    keys(member,['path','bytes','sha256','encoding','compressedBytes','compressedSha256','base64'],'Private member');
    const file=relative(member.path), folded=file.toLowerCase();
    need(!seen.has(folded),'Repeated or case-colliding private member'); seen.add(folded);
    // A/one and a/two share one directory on Windows. Require the same
    // spelling for every prefix, not just for complete member paths.
    let exactPrefix='';
    for(const part of file.split('/')) {
      exactPrefix=exactPrefix ? exactPrefix+'/'+part : part;
      const foldedPrefix=exactPrefix.toLowerCase();
      need(!prefixes.has(foldedPrefix) || prefixes.get(foldedPrefix)===exactPrefix,
        'Private member path prefix case collision');
      prefixes.set(foldedPrefix,exactPrefix);
    }
    need(member.encoding==='gzip' && Number.isSafeInteger(member.bytes) && member.bytes>=0 && member.bytes<=MAX_MEMBER &&
      Number.isSafeInteger(member.compressedBytes) && member.compressedBytes>0 && member.compressedBytes<=MAX_BUNDLE &&
      member.bytes<=Math.max(4096,128*member.compressedBytes) && /^[A-F0-9]{64}$/.test(member.sha256) &&
      /^[A-F0-9]{64}$/.test(member.compressedSha256) && typeof member.base64==='string',
      'Invalid bounded private member encoding');
    const encoded=Buffer.from(member.base64,'base64');
    need(encoded.toString('base64')===member.base64 && encoded.length===member.compressedBytes &&
      sha(encoded)===member.compressedSha256, 'Compressed private member size/digest/encoding differs');
    declaredTotal+=member.bytes;
    need(declaredTotal<=MAX_EXPANDED,'Expanded private population exceeds its fixed bound');
    Object.defineProperty(inventory,file,{value:{bytes:member.bytes,sha256:member.sha256},enumerable:true,writable:true,configurable:true});compressed.push({file,member,encoded});
  }
  need(Object.keys(inventory).length===bundle.members.length && compressed.length===bundle.members.length,'Private member inventory cardinality differs');
  need(declaredTotal===descriptor.expandedBytes,'Expanded private population differs from immutable descriptor');
  for(const file of seen) for(let at=file.indexOf('/');at!==-1;at=file.indexOf('/',at+1))
    need(!seen.has(file.slice(0,at)),'Private member file/directory collision');
  same(sha(Buffer.from(canonical(inventory))),descriptor.membersSha256,'Private member inventory differs');
  same(sha(Buffer.from(canonical(bundle.relocation))),descriptor.relocationSha256,'Original path relocation commitments differ');
  let actualTotal=0;
  for(const {file,member,encoded} of compressed){
    const raw=gunzipSync(encoded,{maxOutputLength:Math.max(1,member.bytes)});
    actualTotal+=raw.length;
    need(actualTotal<=MAX_EXPANDED && raw.length===member.bytes && sha(raw)===member.sha256,
      'Expanded private member size/digest differs');
    records.push({file,raw});
  }
  need(actualTotal===descriptor.expandedBytes,'Actual expanded population differs');
  return {records,inventory,relocation:bundle.relocation};
}
function extractVerifiedBundle31(bytes,descriptor,destination,kind) {
  const verified=verifyBundleBytes31(bytes,descriptor,kind);
  need(path.isAbsolute(destination) && !fs.existsSync(destination),'Private extraction requires a fresh absolute directory');
  const parent=fs.realpathSync(path.dirname(destination));
  need(path.dirname(path.resolve(destination))===parent,'Private extraction parent must not be a symlink');
  fs.mkdirSync(destination,{mode:0o700});
  const root=fs.realpathSync(destination);
  for (const {file,raw} of verified.records) {
    const target=path.join(root,...file.split('/'));
    const relativeTarget=path.relative(root,target);
    need(relativeTarget && !relativeTarget.startsWith('..') && !path.isAbsolute(relativeTarget),'Private member escapes extraction');
    let directory=root;
    for (const component of file.split('/').slice(0,-1)) {
      directory=path.join(directory,component);
      if (!fs.existsSync(directory)) fs.mkdirSync(directory,{mode:0o700});
      need(fs.lstatSync(directory).isDirectory() && !fs.lstatSync(directory).isSymbolicLink(),'Private member traverses symlink');
    }
    fs.writeFileSync(target,raw,{flag:'wx',mode:0o600});
    need(fs.lstatSync(target).isFile() && !fs.lstatSync(target).isSymbolicLink() && sha(fs.readFileSync(target))===sha(raw),
      'Private extraction did not preserve exact regular-file bytes');
  }
  // Git requires refs/ even when every reference is in packed-refs. Empty
  // directories have no object identity and are absent from the file manifest.
  // Derive only this fixed structural directory from complete bound Git files.
  const members=Object.keys(verified.inventory);
  for(const head of members.filter(file=>file==='.git/HEAD'||file.endsWith('/.git/HEAD'))){
    const prefix=head.slice(0,-4);
    if(!Object.hasOwn(verified.inventory,prefix+'config')||!members.some(file=>file.startsWith(prefix+'objects/')))continue;
    const refs=path.join(root,...(prefix+'refs').split('/'));
    if(!fs.existsSync(refs))fs.mkdirSync(refs,{mode:0o700});
    need(fs.lstatSync(refs).isDirectory()&&!fs.lstatSync(refs).isSymbolicLink(),'Git refs must remain a directory');
  }
  return {...verified,root};
}
function getGoogleStorage(pathname,token,maxBytes) {
  need(typeof token==='string' && token.length>20 && token.length<16384 && !/[\r\n]/.test(token),'Authorized private-evidence read credential is unavailable');
  need(pathname.startsWith('/storage/v1/b/'+BUCKET+'/o/'),'Unsupported evidence host/path');
  return new Promise((resolve,reject)=>{
    const request=https.get({hostname:'storage.googleapis.com',port:443,path:pathname,method:'GET',
      headers:{Authorization:'Bearer '+token,Accept:'application/json'},timeout:60000},response=>{
      if(response.statusCode!==200){response.resume();reject(new Error('Authenticated exact-generation evidence read failed'));return;}
      let length=0;const chunks=[];
      response.on('data',chunk=>{length+=chunk.length;if(length>maxBytes){request.destroy();reject(new Error('Evidence response exceeds committed bound'));}else chunks.push(chunk);});
      response.on('end',()=>resolve(Buffer.concat(chunks)));
      response.on('error',()=>reject(new Error('Private evidence response failed')));
    });
    request.on('timeout',()=>request.destroy(new Error('Private evidence read timed out')));
    request.on('error',()=>reject(new Error('Private evidence read failed')));
  });
}
async function downloadExactGeneration31(descriptor,token,kind) {
  validateTransportDescriptor31(descriptor,kind);const c=descriptor.custody;
  const base='/storage/v1/b/'+BUCKET+'/o/'+encodeURIComponent(c.objectName)+'?generation='+c.generation;
  const metadata=JSON.parse((await getGoogleStorage(base,token,1024*1024)).toString('utf8'));
  need(metadata.bucket===BUCKET && metadata.name===c.objectName && metadata.generation===c.generation &&
    metadata.size===String(c.bytes),'Google object metadata differs from immutable generation');
  const raw=await getGoogleStorage(base+'&alt=media',token,c.bytes);
  need(raw.length===c.bytes && sha(raw)===c.sha256,'Google generation bytes differ from immutable custody');
  return raw;
}

module.exports={BUCKET,MAX_BUNDLE,MAX_MEMBERS,MAX_EXPANDED,MAX_MEMBER,BUNDLE_ENCODING,
  validateTransportDescriptor31,verifyBundleBytes31,extractVerifiedBundle31,downloadExactGeneration31};
