'use strict';
// Read-only evidence addressing. Never edits original receipts or authority.
const nativeFs=require('node:fs'),nativePath=require('node:path'),crypto=require('node:crypto');
const {AsyncLocalStorage}=require('node:async_hooks');
const store=new AsyncLocalStorage();
const digest=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function need(x,m){if(!x)throw Error(m);}
function normalizeOriginal(p){need(typeof p==='string'&&(nativePath.isAbsolute(p)||nativePath.win32.isAbsolute(p)),'Absolute original identity required');const n=p.replaceAll('\\','/').replace(/\/$/,'');need(!n.split('/').includes('..'),'Parent traversal forbidden');return n;}
function physicalMember(root,member){need(typeof member==='string'&&!member.includes('\\')&&!member.includes(':')&&!member.startsWith('/')&&member.split('/').every(x=>x&&x!=='.'&&x!=='..'),'Safe bundle member required');const p=nativePath.resolve(root,member),r=nativePath.relative(root,p);need(r&&!r.startsWith('..')&&!nativePath.isAbsolute(r),'Bundle member escaped root');return p;}
function current(){return store.getStore();}
function resolveOriginal(p){
  const context=current();if(!context?.relocation||typeof p!=='string')return p;
  const physical=nativePath.isAbsolute(p)?nativePath.resolve(p):null;
  if(physical&&Object.hasOwn(context.verifierFiles??{},physical))return physical;
  if(physical&&(physical===context.bundleRoot||physical.startsWith(context.bundleRoot+nativePath.sep)))return physical;
  const original=normalizeOriginal(p),exact=context.files.get(original);
  if(exact)return exact;
  const matches=context.roots.filter(x=>original===x.original||original.startsWith(x.original+'/'));
  need(matches.length===1,'Original path has no unique immutable relocation: '+original);
  const root=matches[0],suffix=original.slice(root.original.length).replace(/^\//,'');return suffix?physicalMember(context.bundleRoot,root.memberRoot+'/'+suffix):physicalMember(context.bundleRoot,root.memberRoot);
}
function runEvidence31(config,action){const parent=current()??{};return store.run({...parent,evidenceDirectory:config.evidenceDirectory??parent.evidenceDirectory},action);}
function runRelocated31({privateBundleRoot,relocation,members,evidenceDirectory,verifierFiles={}},action){
  const bundleRoot=nativeFs.realpathSync(privateBundleRoot);need(relocation?.schemaVersion===1&&Array.isArray(relocation.roots)&&Array.isArray(relocation.files),'Exact relocation schema required');
  const roots=relocation.roots.map(r=>({original:normalizeOriginal(r.original),memberRoot:r.memberRoot}));
  need(roots.length>0&&roots.length<=16&&new Set(roots.map(x=>x.original)).size===roots.length,'Finite unique original roots required');
  for(const r of roots){const p=physicalMember(bundleRoot,r.memberRoot);need(nativeFs.realpathSync(p)===p&&nativeFs.statSync(p).isDirectory(),'Mapped original root is not a regular directory');for(const q of roots)if(q!==r)need(!q.original.startsWith(r.original+'/'),'Overlapping original roots forbidden');}
  const files=new Map();for(const f of relocation.files){const original=normalizeOriginal(f.original);need(!files.has(original)&&!roots.some(r=>original===r.original||original.startsWith(r.original+'/')),'Overlapping original file mapping');const actual=physicalMember(bundleRoot,f.member),binding=members.find(x=>x.path===f.member);need(binding&&binding.bytes===f.bytes&&binding.sha256===f.sha256&&nativeFs.realpathSync(actual)===actual,'Mapped file binding differs');const raw=nativeFs.readFileSync(actual);need(raw.length===f.bytes&&digest(raw)===f.sha256,'Mapped file changed');files.set(original,actual);}
  const index=new Map(members.map(m=>[nativePath.resolve(physicalMember(bundleRoot,m.path)),m]));
  function validateFile(file){const physical=resolveOriginal(file);if(typeof physical!=='string')return physical;const real=nativeFs.realpathSync(physical);need(real===physical,'Relocated evidence cannot follow symlinks');const stat=nativeFs.statSync(real);if(stat.isFile()){const raw=nativeFs.readFileSync(real);if(Object.hasOwn(verifierFiles,real)){need(digest(raw)===verifierFiles[real],'Source-bound replay producer changed');return real;}const row=index.get(real);need(row,'Unlisted evidence file');need(raw.length===row.bytes&&digest(raw)===row.sha256,'Relocated evidence changed');}return real;}
  return store.run({bundleRoot,roots,files,relocation,evidenceDirectory,index,validateFile,verifierFiles},action);
}
const fs={...nativeFs};
for(const name of ['readFileSync','statSync','lstatSync','readdirSync','existsSync','realpathSync'])fs[name]=function(p,...rest){let mapped=resolveOriginal(p);if(current()?.relocation&&name==='readFileSync')mapped=current().validateFile(p);return nativeFs[name](mapped,...rest);};
const path={...nativePath};
for(const key of ['dirname','basename','extname','normalize'])path[key]=p=>(typeof p==='string'&&nativePath.win32.isAbsolute(p)?nativePath.win32:nativePath)[key](p);
path.join=(first,...rest)=>(typeof first==='string'&&nativePath.win32.isAbsolute(first)?nativePath.win32:nativePath).join(first,...rest);
path.resolve=(first,...rest)=>(typeof first==='string'&&nativePath.win32.isAbsolute(first)?nativePath.win32:nativePath).resolve(first,...rest);
path.isAbsolute=p=>nativePath.isAbsolute(p)||nativePath.win32.isAbsolute(p);
function resolveAuthorityRecord31(envelope){
  if(envelope?.documentType!=='build31-runtime-private-record-custody')return envelope;
  need(envelope.schemaVersion===2&&['approval','owner','runtime','release-ci','security-ci','closure','client','client-owner'].includes(envelope.recordKind),'Unknown private authority envelope');
  const p=envelope.privateRecord;need(p&&typeof p.file==='string'&&/^[A-F0-9]{64}$/.test(p.sha256)&&Number.isSafeInteger(p.bytes)&&p.bytes>0,'Immutable private record pointer required');
  need(current()?.evidenceDirectory,'Private authority needs authenticated evidence context');const file=physicalMember(resolveOriginal(current().evidenceDirectory),p.file),raw=fs.readFileSync(file);need(raw.length===p.bytes&&digest(raw)===p.sha256,'Private authority record differs from public custody');const value=JSON.parse(raw.toString('utf8'));
  need(value&&typeof value==='object'&&!Array.isArray(value),'Private authority must be an object');
  if(value.source)need(JSON.stringify(value.source)===JSON.stringify(envelope.source),'Private authority source differs from public custody');
  if(value.recordedAtUtc)need(value.recordedAtUtc===envelope.recordedAtUtc,'Private authority chronology differs from public custody');
  return value;
}
function archiveInterpreter(runtime){if(!current()?.relocation)return runtime.nodeExecutable;need(Number(process.versions.node.split('.')[0])===22,'Replay requires the release workflow Node22 interpreter');return process.execPath;}
module.exports={fs,path,current,resolveOriginal,runEvidence31,runRelocated31,resolveAuthorityRecord31,archiveInterpreter,physicalMember,normalizeOriginal};
