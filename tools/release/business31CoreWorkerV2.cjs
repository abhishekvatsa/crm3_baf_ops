'use strict';
// Fresh-process adapter only. All recorded helpers are loaded from the extracted
// M source after its independently selected complete producer map is checked.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {isDeepStrictEqual:same,TextDecoder}=require('node:util');
const MAX_MEMBERS=53000,MAX_MEMBER=128*1024*1024,MAX_EXPANDED=1024*1024*1024;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function need(v,m){if(!v)throw Error('Business core worker v2: '+m);}
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
function regular(file,directory=false){
 need(typeof file==='string'&&path.isAbsolute(file),'absolute physical path required');
 const full=path.resolve(file);let cursor=path.parse(full).root;
 for(const part of full.slice(cursor.length).split(path.sep).filter(Boolean)){cursor=path.join(cursor,part);need(!fs.lstatSync(cursor).isSymbolicLink(),'physical path redirects');}
 const s=fs.lstatSync(full);need(directory?s.isDirectory():s.isFile(),'regular physical path required');
 need(fs.realpathSync(full)===full,'physical path identity differs');return full;
}
function portable(file){need(typeof file==='string'&&file.length<=400&&/^[A-Za-z0-9_@+.~/-]+$/.test(file)&&!file.startsWith('/')&&file.split('/').every(p=>p&&p!=='.'&&p!=='..'&&!/[. ]$/.test(p)&&!/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)),'safe member required');return file;}
function inventoryV2(root){
 regular(root,true);const rows={},folded=new Set(),prefixes=new Map();let count=0,total=0;
 function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  const file=path.join(dir,e.name);need(!e.isSymbolicLink(),'bundle redirects');
  if(e.isDirectory())walk(file);else{
   need(e.isFile()&&++count<=MAX_MEMBERS,'finite regular bundle population required');
   const stat=fs.statSync(file);need(stat.size<=MAX_MEMBER&&(total+=stat.size)<=MAX_EXPANDED,'unchanged member/expanded byte cap exceeded');
   const name=portable(path.relative(root,file).split(path.sep).join('/'));need(!folded.has(name.toLowerCase()),'member case collision');folded.add(name.toLowerCase());
   let prefix='';for(const part of name.split('/')){prefix=prefix?prefix+'/'+part:part;const key=prefix.toLowerCase();need(!prefixes.has(key)||prefixes.get(key)===prefix,'member prefix collision');prefixes.set(key,prefix);}
   const bytes=fs.readFileSync(file);need(bytes.length===stat.size,'member changed during inventory');
   Object.defineProperty(rows,name,{value:{bytes:bytes.length,sha256:sha(bytes)},enumerable:true});
  }
 }}walk(root);need(Object.keys(rows).length===count,'complete inventory cardinality differs');return rows;
}
function originalPathsUnavailable(relocation){for(const r of [...relocation.roots,...relocation.files])need(!fs.existsSync(r.original),'original path remains available');return true;}
function memberForOriginal(root,relocation,original){
 const normalize=v=>v.replaceAll('\\','/').replace(/\/$/,'');const wanted=normalize(original);
 const matches=relocation.roots.filter(r=>wanted===normalize(r.original)||wanted.startsWith(normalize(r.original)+'/'));
 need(matches.length===1,'unique original role root required');const r=matches[0],suffix=wanted.slice(normalize(r.original).length).replace(/^\//,'');
 const member=r.memberRoot+(suffix?'/'+suffix:'');portable(member);return path.join(root,...member.split('/'));
}
function coreFiles(root,relocation,map){
 need(map&&typeof map==='object'&&!Array.isArray(map)&&Object.keys(map).length>0&&Object.keys(map).length<=256,'finite recorded producer map required');
 const authority=regular(memberForOriginal(root,relocation,relocation.roles.authorityRoot),true),result={};
 for(const [file,hash]of Object.entries(map)){
  portable(file);need(file.startsWith('tools/')&&/^[A-F0-9]{64}$/.test(hash),'recorded producer binding invalid');
  const physical=regular(path.join(authority,...file.split('/')));need(sha(fs.readFileSync(physical))===hash,'recorded producer differs: '+file);result[physical]=hash;
 }
 return {authority,files:result};
}
function runCoreWorkerV2(input){
 need(Number(process.versions.node.split('.')[0])===22,'pinned Node22 required');
 need(input&&same(Object.keys(input).sort(),['schemaVersion','profile','extractionRoot','relocation','descriptor','sourceManifest','expectedSourceManifestSha256','gitExecutable','gitSha256','nodeSha256','nowUtc'].sort()),'closed worker input required');
 need(input.schemaVersion===1&&input.profile==='build31-business-recorded-core-worker-v2','worker profile differs');
 const {descriptor:d,relocation,sourceManifest,expectedSourceManifestSha256,gitSha256,nowUtc}=input;
 const root=regular(input.extractionRoot,true),node=regular(process.execPath),git=regular(input.gitExecutable);
 need(sha(fs.readFileSync(node))===input.nodeSha256&&sha(fs.readFileSync(git))===gitSha256,'selected runtime changed');
 need(d.schemaVersion===3&&d.profile==='build31-exact-business-backend-v2'&&d.coreVerifier.commit===d.source.commit&&d.coreVerifier.tree===d.source.tree,'recorded core/source differs');
 need(sha(Buffer.from(canonical(sourceManifest)))===expectedSourceManifestSha256&&d.sourceManifestSha256===expectedSourceManifestSha256,'source manifest commitment differs');
 const before=inventoryV2(root);need(sha(Buffer.from(canonical(before)))===d.membersSha256&&Object.values(before).reduce((n,r)=>n+r.bytes,0)===d.expandedBytes,'complete extracted inventory differs');
 need(sha(Buffer.from(canonical(relocation)))===d.relocationSha256,'relocation commitment differs');originalPathsUnavailable(relocation);
 const bound=coreFiles(root,relocation,d.coreVerifier.files),load=file=>{
  need(Object.hasOwn(d.coreVerifier.files,'tools/release/'+file),'recorded helper not selected');
  return require(path.join(bound.authority,'tools','release',file));
 };
 // No outer helper or modified core is imported in this process.
 const legacy=load('business31OriginalPathReplay.cjs');legacy.validateRelocation31(relocation,before);
 const subset=legacy.deriveClosureProducerBindings31(d.coreVerifier.files),access=load('backendRuntimeEvidenceAccess31.cjs');
 const verifierFiles={...bound.files,[git]:gitSha256,[node]:input.nodeSha256};
 const members=Object.entries(before).map(([file,binding])=>({path:file,...binding}));
 const result=access.runRelocated31({privateBundleRoot:root,relocation,members,evidenceDirectory:relocation.roles.evidenceDirectory,verifierFiles},()=>{
  const repository=load('business31TrustedInput.cjs').openTrustedGitRepository31({repositoryRoot:bound.authority,gitExecutable:git,gitSha256});
  legacy.joinOriginalExecutionRoot31({decisionEnvelopeBytes:repository.readBlob(d.approvalPointer.commit,d.approvalPointer.file),descriptor:d,relocation});
  need(same(load('business31BackendAuthority.cjs').PRODUCERS,legacy.CLOSURE_PRODUCERS),'recorded closure subset differs');
  return load('business31BackendClosure.cjs').verifyBusiness31BackendClosure({authorityOptions:{repositoryRoot:relocation.roles.authorityRoot,
   gitExecutable:git,gitSha256,trustedVerifier:{commit:d.coreVerifier.commit,tree:d.coreVerifier.tree,files:subset},
   sourceCommit:d.source.commit,sourceManifest,trustedManifestSha256:expectedSourceManifestSha256,evidenceDirectory:relocation.roles.evidenceDirectory,
   decisionPointer:d.approvalPointer,nowUtc},closurePointer:d.closurePointer});
 });
 need(result.recordedSemanticsReplayed===true&&same(result.source,d.source)&&same(result.decisionPointer,d.approvalPointer)&&same(result.closurePointer,d.closurePointer),'unchanged core replay incomplete');
 need(same(inventoryV2(root),before),'private population changed during core replay');originalPathsUnavailable(relocation);coreFiles(root,relocation,d.coreVerifier.files);
 need(sha(fs.readFileSync(git))===gitSha256&&sha(fs.readFileSync(node))===input.nodeSha256,'runtime changed during core replay');
 return {schemaVersion:1,profile:input.profile,coreVerifier:{commit:d.coreVerifier.commit,tree:d.coreVerifier.tree},membersSha256:d.membersSha256,
  relocationSha256:d.relocationSha256,recordedSemanticsReplayed:true,originalPathsUnavailable:true,closure:result,
  deploymentAuthorized:false,constructionAuthorized:false,distributionAuthorized:false};
}
function main(){
 need(process.execArgv.length===1&&process.execArgv[0]==='--no-global-search-paths','fixed fresh-process flags required');
 need(!['NODE_OPTIONS','NODE_PATH','LD_PRELOAD','LD_LIBRARY_PATH','DYLD_INSERT_LIBRARIES'].some(k=>process.env[k]),'loader environment refused');
 need(process.argv.length===4&&/^[A-F0-9]{64}$/.test(process.argv[3]),'exact input binding required');
 const file=regular(process.argv[2]);need(fs.statSync(file).size<=2*1024*1024,'worker metadata bound exceeded');
 const raw=fs.readFileSync(file);need(sha(raw)===process.argv[3],'worker input changed');
 const result=runCoreWorkerV2(JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw))),out=Buffer.from(JSON.stringify(result));
 need(out.length<=2*1024*1024,'worker result bound exceeded');process.stdout.write(out);
}
// Private parse/read errors may contain evidence fragments. The adapter exposes
// only a fixed failure code; callers must never publish a raw core diagnostic.
if(require.main===module){try{main();}catch{process.stderr.write('BUSINESS31_RECORDED_CORE_WORKER_FAILED\n');process.exitCode=1;}}
module.exports={MAX_MEMBERS,MAX_MEMBER,MAX_EXPANDED,sha,canonical,regular,portable,inventoryV2,originalPathsUnavailable,memberForOriginal,coreFiles,runCoreWorkerV2};
