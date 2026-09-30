'use strict';
// Post-CI local evidence collector; its receipt alone grants no release authority.
const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto');
const {execFileSync,spawnSync}=require('node:child_process');
const {isDeepStrictEqual,TextDecoder}=require('node:util');
const {sealReceipt,verifyReceiptSeal}=require('./collectProductionGlobalPullBackend.js');
const {DEPLOYED_BASELINE,runtimeReachability,verifyLocalRuntimeProof}=require('./clientBuildToolingCompatibility31.cjs');
const {verifyGitDevelopmentTooling}=require('./clientBuildToolingGitSnapshots31.cjs');
const SELF='tools/release/collectClientBuildToolingRuntime31.cjs';
const PRODUCERS=[SELF,'tools/release/clientBuildToolingCompatibility31.cjs','tools/release/clientBuildToolingGitSnapshots31.cjs','tools/release/collectProductionGlobalPullBackend.js'];
const REPO='abhishekvatsa/crm3_baf_ops', REGISTRY='https://registry.npmjs.org/';
const TYPE='build31-development-tool-runtime-proof-v1';
const BOUNDARY=Object.freeze({generation:31,backendDeploymentPerformed:false,productionCredentialsUsed:false,signingPerformed:false,distributionPerformed:false,constructionAuthority:false});
const SHA=/^[A-F0-9]{64}$/, COMMIT=/^[a-f0-9]{40}$/;
const decoder=new TextDecoder('utf-8',{fatal:true});
const RELEASE_JOBS=['Flutter host analysis + tests + no-loss contracts','Android release package + cold-start proof (non-production)','Android emulator shell + business integration (not physical-device evidence)','Firestore Rules + governed callable emulator','Cloud Functions host build + non-emulator tests'].sort();
const SECURITY_JOBS=['CodeQL (actions)','CodeQL (java-kotlin)','CodeQL (javascript-typescript)','CodeQL (python)'].sort();
const EXPECTED_CODE="import {auditEmittedOutput} from './tools/emitted_output_custody.mjs'; const x=auditEmittedOutput(); console.log(JSON.stringify({sourceCount:x.sourceCount,expectedFiles:x.expectedFiles,actualFiles:x.actualFiles}));";
const PLAN=Object.freeze([
 ['node-version','tool','node',['--version']],['npm-version','tool','npm',['--version']],
 ['baseline-functions-install','baseline/functions','npm',['ci','--no-audit','--no-fund','--registry='+REGISTRY]],
 ['candidate-root-install','candidate','npm',['ci','--no-audit','--no-fund','--registry='+REGISTRY]],
 ['candidate-functions-install','candidate/functions','npm',['ci','--no-audit','--no-fund','--registry='+REGISTRY]],
 ['candidate-cli-install','candidate/tooling/firebase-cli','npm',['ci','--no-audit','--no-fund','--registry='+REGISTRY]],
 ['baseline-build','baseline/functions','npm',['run','build']],['candidate-build','candidate/functions','npm',['run','build']],
 ['baseline-emitted','baseline/functions','node',['--input-type=module','-e',EXPECTED_CODE]],['candidate-emitted','candidate/functions','node',['--input-type=module','-e',EXPECTED_CODE]],
 ['baseline-installed','baseline/functions','npm',['ls','--omit=dev','--all','--json']],['candidate-installed','candidate/functions','npm',['ls','--omit=dev','--all','--json']],
 ['root-full','candidate','npm',['audit','--json','--registry='+REGISTRY]],['root-runtime','candidate','npm',['audit','--omit=dev','--json','--registry='+REGISTRY]],
 ['functions-full','candidate/functions','npm',['audit','--json','--registry='+REGISTRY]],['functions-runtime','candidate/functions','npm',['audit','--omit=dev','--json','--registry='+REGISTRY]],
 ['cli-full','candidate/tooling/firebase-cli','npm',['audit','--json','--registry='+REGISTRY]],
]);
for(const row of PLAN){Object.freeze(row[3]);Object.freeze(row);}
function must(v,m){if(!v)throw new Error(m);}
function object(v){return v!==null&&typeof v==='object'&&!Array.isArray(v);}
function keys(v,expected,label){must(object(v)&&isDeepStrictEqual(Object.keys(v).sort(),[...expected].sort()),label+': exact object keys required');}
function hash(v){return crypto.createHash('sha256').update(v).digest('hex').toUpperCase();}
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(object(v))return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
function valueHash(v){return hash(canonical(v));}
function utc(v){must(typeof v==='string','Explicit UTC instant required');const m=/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(v);must(m&&!m[1].startsWith('0000-'),'Explicit UTC instant required');const n=Date.parse(m[1]+'Z');must(Number.isFinite(n)&&new Date(n).toISOString().slice(0,19)===m[1],'Invalid UTC instant');return BigInt(n)*1000000n+BigInt((m[2]??'').padEnd(9,'0'));}
function safe(p){return typeof p==='string'&&p.length>0&&p.length<1024&&!/[\\:\x00-\x1f\x7f]/.test(p)&&!p.startsWith('/')&&p.split('/').every(s=>s&&s!=='.'&&s!=='..'&&s.toLowerCase()!=='.git');}
function git(r,a,input){return execFileSync('git',['--no-replace-objects','-C',r,...a],{input,windowsHide:true,timeout:30000,maxBuffer:64*1024*1024,stdio:[input===undefined?'ignore':'pipe','pipe','pipe']});}
function text(r,a){return decoder.decode(git(r,a)).trim();}
function sourcePoint(r,m){
 must(COMMIT.test(m),'Immutable candidate commit required');
 must(path.isAbsolute(r)&&fs.realpathSync(r)===fs.realpathSync(text(r,['rev-parse','--show-toplevel'])),'Actual absolute repository root required');
 const point={commit:text(r,['rev-parse','HEAD']),tree:text(r,['rev-parse','HEAD^{tree}']),branch:text(r,['symbolic-ref','--short','HEAD']),originMain:text(r,['rev-parse','refs/remotes/origin/main']),clean:text(r,['status','--porcelain','--untracked-files=all'])===''};
 must(point.commit===m&&point.originMain===m&&point.branch==='main'&&point.clean===true,'Actual clean literal main at candidate and origin/main required');return point;
}
function ciCompletion(release,security,m,tree,limit){
 let last=0n;
 for(const[ci,type,workflow,names]of [[release,'github-exact-main-release-gate','.github/workflows/release-gate.yml',RELEASE_JOBS],[security,'github-exact-main-codeql','.github/workflows/codeql.yml',SECURITY_JOBS]]){
  must(ci?.schemaVersion===1&&ci.evidenceType===type&&ci.repository===REPO&&ci.sourceCommit===m&&ci.sourceTree===tree,'Exact source CI envelope required');
  const pr=ci.pullRequest,run=ci.run,jobs=ci.jobs;
  must(Number.isSafeInteger(pr?.number)&&pr.number>0&&pr.merged===true&&pr.merge_commit_sha===m&&pr.base?.ref==='main'&&pr.base?.repo?.full_name===REPO,'Normal merged-main CI source required');
  must(Number.isSafeInteger(run?.id)&&run.id>0&&Number.isSafeInteger(run.run_attempt)&&run.run_attempt>0&&run.repository?.full_name===REPO&&run.head_sha===m&&run.head_branch==='main'&&run.event==='push'&&run.path===workflow&&run.status==='completed'&&run.conclusion==='success','Successful exact main run required');
  const merged=utc(pr.merged_at),started=utc(run.created_at),ended=utc(run.updated_at),captured=utc(ci.capturedAtUtc);
  must(merged<=started&&started<=ended&&ended<=captured&&captured<=limit,'Actual CI chronology invalid');
  must(jobs?.total_count===names.length&&Array.isArray(jobs.jobs)&&jobs.jobs.length===names.length&&isDeepStrictEqual(jobs.jobs.map(j=>j.name).sort(),names),'Complete exact CI job set required');
  must(new Set(jobs.jobs.map(j=>j.id)).size===names.length&&jobs.jobs.every(j=>Number.isSafeInteger(j.id)&&j.id>0&&j.run_id===run.id&&j.run_attempt===run.run_attempt&&j.head_sha===m&&j.status==='completed'&&j.conclusion==='success'&&started<=utc(j.completed_at)&&utc(j.completed_at)<=ended),'Actual successful job evidence required');
  last=last>ended?last:ended;
 }
 must(release.pullRequest.number===security.pullRequest.number,'CI source PR differs');return last;
}

function validateExactMainCiPair({candidateCommit,sourceTree,releaseCi,securityCi}){must(COMMIT.test(candidateCommit)&&COMMIT.test(sourceTree),'Exact source commit/tree required');ciCompletion(releaseCi,securityCi,candidateCommit,sourceTree,BigInt(Date.now())*1000000n);return {lastCompletionUtc:utc(releaseCi.run.updated_at)>=utc(securityCi.run.updated_at)?releaseCi.run.updated_at:securityCi.run.updated_at};}
function producerHashes(r,m){return Object.fromEntries(PRODUCERS.map(p=>[p,hash(git(r,['show',m+':'+p]))]));}
function recordBytes(bytes){return {sha256:hash(bytes),bytes:bytes.length};}
function validBytes(v){keys(v,['sha256','bytes'],'Measured bytes');must(typeof v.sha256==='string'&&SHA.test(v.sha256)&&Number.isSafeInteger(v.bytes)&&v.bytes>=0,'Measured digest/byte count invalid');}
function inventory(dir){
 const result={};function visit(root,rel=''){for(const name of fs.readdirSync(root).sort()){
  must(safe(name),'Unsafe emitted file name');const p=path.join(root,name),next=rel?rel+'/'+name:name,st=fs.lstatSync(p);
  must(!st.isSymbolicLink(),'Emitted symlink/reparse point rejected');
  if(st.isDirectory())visit(p,next);else{must(st.isFile()&&/\.js(?:\.map)?$/.test(next),'Unexpected emitted file');result[next]=recordBytes(fs.readFileSync(p));}
 }}visit(dir);must(Object.hasOwn(result,'index.js')&&Object.hasOwn(result,'index.js.map'),'Complete emitted index files required');return result;
}
function gitSourceRows(r,commit){
 must(COMMIT.test(commit),'Exact source commit required');const rows=[],folded=new Set();
 for(const e of decoder.decode(git(r,['ls-tree','-rz','--full-tree',commit])).split('\0').filter(Boolean)){
  const m=/^(100644|100755) blob ([a-f0-9]{40})\t(.+)$/.exec(e);must(m,'Unsupported Git export entry');const[,mode,blob,file]=m;
  must(safe(file)&&!folded.has(file.toLowerCase()),'Unsafe/ambiguous Git source path');folded.add(file.toLowerCase());
  if(file==='.npmrc'||file==='package.json'||file==='package-lock.json'||file.startsWith('functions/')||file.startsWith('tooling/'))rows.push({path:file,mode,blob});
 }must(rows.length>0&&rows.length<=10000,'Bounded complete Git source inventory required');return rows;
}
function gitBlobs(r,ids){
 const ordered=[...new Set(ids)];must(ordered.length>0&&ordered.length<=10000&&ordered.every(x=>COMMIT.test(x)),'Bounded exact blob IDs required');
 const raw=git(r,['cat-file','--batch'],Buffer.from(ordered.join('\n')+'\n')),result=new Map();let offset=0;
 for(const id of ordered){const end=raw.indexOf(10,offset);must(end>=offset,'Incomplete Git blob header');const m=/^([a-f0-9]{40}) blob (\d+)$/.exec(raw.subarray(offset,end).toString('ascii'));must(m&&m[1]===id,'Git blob identity differs');const size=Number(m[2]);must(Number.isSafeInteger(size)&&size>=0&&end+1+size<raw.length,'Git blob size differs');const bytes=raw.subarray(end+1,end+1+size);must(raw[end+1+size]===10,'Git blob delimiter absent');result.set(id,bytes);offset=end+size+2;}
 must(offset===raw.length,'Unexpected Git batch output');return result;
}
function exportGit(r,commit,destination){
 const rows=gitSourceRows(r,commit),blobs=gitBlobs(r,rows.map(x=>x.blob));fs.mkdirSync(destination,{recursive:false});const files=[];
 for(const row of rows){const target=path.join(destination,...row.path.split('/')),bytes=blobs.get(row.blob);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});if(process.platform!=='win32')fs.chmodSync(target,row.mode==='100755'?0o755:0o644);files.push({...row,sha256:hash(bytes),bytes:bytes.length});}
 must(!fs.existsSync(path.join(destination,'functions/lib')),'Fresh exported source must not contain stale compiled output');return files;
}
function sourceInventory(r,commit){const rows=gitSourceRows(r,commit),blobs=gitBlobs(r,rows.map(x=>x.blob));return rows.map(row=>({...row,sha256:hash(blobs.get(row.blob)),bytes:blobs.get(row.blob).length}));}
function runtimeInputs(r,commit){const config=JSON.parse(decoder.decode(git(r,['show',commit+':functions/tsconfig.json'])));must(isDeepStrictEqual(config,{compilerOptions:{module:'commonjs',noImplicitReturns:true,noUnusedLocals:false,outDir:'lib',sourceMap:true,strict:true,target:'es2022'},compileOnSave:true,include:['src']}),'Immutable emitted-layout compiler configuration differs');return {manifest:JSON.parse(decoder.decode(git(r,['show',commit+':functions/package.json']))),lock:JSON.parse(decoder.decode(git(r,['show',commit+':functions/package-lock.json'])))};}
function verifyInstalledAgainstLock({manifest,lock,graph}){
 const reachable=runtimeReachability(manifest,lock),observed=new Map(),expanded=new Map();let visits=0;
 const dependency=(from,name)=>{let current=from;while(true){if(path.posix.basename(current)!=='node_modules'){const key=(current?current+'/':'')+'node_modules/'+name;if(Object.hasOwn(lock.packages,key))return key;}if(!current)return null;const next=path.posix.dirname(current);current=next==='.'?'':next;}};
 const declarations=p=>({...p.dependencies,...p.optionalDependencies,...p.peerDependencies});
 const optional=(p,n)=>Object.hasOwn(p.optionalDependencies??{},n)||(!Object.hasOwn(p.dependencies??{},n)&&p.peerDependenciesMeta?.[n]?.optional===true);
 must(object(graph)&&graph.name===manifest.name&&object(graph.dependencies),'Installed root identity/population differs');
 function visit(parent,from,dependencies,depth){
  must(depth<=100&&object(dependencies),'Installed graph nesting/population invalid');const expected=declarations(parent);
  for(const[name,node]of Object.entries(dependencies)){
   must(++visits<=20000&&/^(?:@[a-z0-9._-]+\/)?[a-z0-9._-]+$/i.test(name)&&Object.hasOwn(expected,name)&&object(node),'Unexpected installed dependency');
   const key=dependency(from,name);
   if(Object.keys(node).length===0){must(optional(parent,name),'Required installed dependency absent');continue;}
   must(key&&Object.hasOwn(reachable,key),'Installed package not reachable in runtime lock');const locked=reachable[key];
   must(Object.keys(node).every(k=>['version','resolved','overridden','dependencies'].includes(k))&&node.version===locked.version,'Installed version/metadata differs');
   if(Object.hasOwn(node,'resolved'))must(node.resolved===locked.resolved,'Installed resolution differs');
   if(Object.hasOwn(node,'overridden'))must(typeof node.overridden==='boolean','Installed override flag invalid');
   observed.set(key,node.version);
   if(Object.hasOwn(node,'dependencies')){expanded.set(key,new Set([...(expanded.get(key)??[]),...Object.keys(node.dependencies).filter(n=>Object.keys(node.dependencies[n]).length>0)]));visit(locked,key,node.dependencies,depth+1);}
  }
 }
 must(Object.keys(graph).every(k=>['name','version','dependencies'].includes(k)),'Unexpected installed root fields');
 if(Object.hasOwn(graph,'version'))must(graph.version===manifest.version,'Installed root version differs');
 visit(manifest,'',graph.dependencies,0);
 const requireEdges=(pkg,from,names)=>{for(const name of Object.keys(declarations(pkg))){if(optional(pkg,name))continue;const key=dependency(from,name);must(key&&observed.has(key)&&names.has(name),'Required runtime dependency omitted: '+from+' -> '+name);}};
 requireEdges(manifest,'',new Set(Object.keys(graph.dependencies)));
 for(const key of observed.keys())requireEdges(reachable[key],key,expanded.get(key)??new Set());
 return {runtimeInstalledPaths:observed.size,constructionAuthority:false};
}
function expectedEmittedFiles(sourceFiles){
 // This is deliberately bounded to the immutable deployed tsconfig: include src,
 // commonjs + sourceMap, no declaration/JS inputs and common source root src.
 const inputs=sourceFiles.filter(x=>x.path.startsWith('functions/src/')).map(x=>x.path.slice('functions/src/'.length));
 must(inputs.length>0&&inputs.every(p=>safe(p)&&/\.ts$/.test(p)&&!p.endsWith('.d.ts'))&&inputs.includes('index.ts'),'Fixed TypeScript source population required');
 const outputs=inputs.flatMap(p=>[p.slice(0,-3)+'.js',p.slice(0,-3)+'.js.map']).sort();
 must(new Set(outputs.map(p=>p.toLowerCase())).size===outputs.length,'Ambiguous compiler output names');return outputs;
}
function assertExportPreserved(root,files){
 const base=path.resolve(root);const rootStat=fs.lstatSync(base);must(rootStat.isDirectory()&&!rootStat.isSymbolicLink(),'Export root replaced');
 for(const file of files){must(safe(file.path),'Unsafe exported source path');let target=base;const parts=file.path.split('/');
  for(let i=0;i<parts.length;i++){target=path.join(target,parts[i]);const st=fs.lstatSync(target);must(!st.isSymbolicLink(),'Exported source reparse point detected');if(i<parts.length-1)must(st.isDirectory(),'Exported parent changed');else{must(st.isFile(),'Exported source file type changed');if(process.platform!=='win32')must((st.mode&0o777)===(file.mode==='100755'?0o755:0o644),'Exported source mode changed');must(st.size===file.bytes&&hash(fs.readFileSync(target))===file.sha256,'Install/build mutated exported source bytes: '+file.path);}}
 }return true;
}
function measureToolPackage(root,expectedName){
 const files={};let count=0,total=0;const initial=fs.lstatSync(root);must(initial.isDirectory()&&!initial.isSymbolicLink(),'Tool package root must be a real directory');
 function walk(dir,rel=''){for(const name of fs.readdirSync(dir).sort()){must(safe(name)&&++count<=20000,'Unsafe/oversized tool package');const f=path.join(dir,name),key=rel?rel+'/'+name:name,st=fs.lstatSync(f);must(!st.isSymbolicLink(),'Tool package symlink rejected');if(st.isDirectory())walk(f,key);else{must(st.isFile(),'Invalid tool package file');total+=st.size;must(total<=256*1024*1024,'Tool package exceeds measurement bound');files[key]=recordBytes(fs.readFileSync(f));}}}walk(root);
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8'));must(manifest.name===expectedName&&typeof manifest.version==='string','Tool package identity differs');return {version:manifest.version,sha256:valueHash(files)};
}
function recordCommandRun({run,entry,startedAtUtc,completedAtUtc,logs,outputDirectory,commands}){
 const [id,role,tool,args]=entry,stdout=run.stdout??Buffer.alloc(0),stderr=run.stderr??Buffer.alloc(0);
 fs.writeFileSync(path.join(logs,id+'.stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(logs,id+'.stderr.log'),stderr,{flag:'wx'});
 const c={id,role,tool,args,startedAtUtc,completedAtUtc,exitCode:run.status,stdout:recordBytes(stdout),stderr:recordBytes(stderr),stdoutText:null,structuredResult:null};commands.push(c);
 const save=()=>fs.writeFileSync(path.join(outputDirectory,'commands-progress.json'),JSON.stringify(commands,null,2)+'\n');save();
 // Persist the actual command status and raw bytes before decoding/parsing or
 // raising a failure. A failed audit with non-JSON output remains diagnosable.
 must(!run.error&&run.status===0,'Fixed command failed: '+id);
 const structured=['baseline-emitted','candidate-emitted','baseline-installed','candidate-installed','root-full','root-runtime','functions-full','functions-runtime','cli-full'].includes(id);
 if(structured||id==='node-version'||id==='npm-version')c.stdoutText=decoder.decode(stdout);
 if(structured)c.structuredResult=JSON.parse(c.stdoutText);save();return c.structuredResult??decoder.decode(stdout).trim();
}
function validateMeasured(receipt,{candidateCommit,tree,lastCi,decision,gitProof,producers,releaseCi,securityCi,sourceInventories,runtimeInputs:actualRuntimeInputs}){
 keys(receipt,['schemaVersion','evidenceType','candidateCommit','candidateTree','baselineCommit','startedAtUtc','completedAtUtc','sourceBefore','sourceAfter','producerHashes','ciHashes','gitProof','exportedSources','tools','commands','emitted','installed','audits','boundary','receiptSha256'],'Runtime receipt');
 verifyReceiptSeal(receipt,'Build31 runtime proof');
 must(receipt.schemaVersion===1&&receipt.evidenceType===TYPE&&receipt.candidateCommit===candidateCommit&&receipt.candidateTree===tree&&receipt.baselineCommit===DEPLOYED_BASELINE,'Runtime identity/schema differs');
 const started=utc(receipt.startedAtUtc),ended=utc(receipt.completedAtUtc);must(lastCi<=started&&started<=ended&&ended<=decision&&decision<=BigInt(Date.now())*1000000n&&decision-ended<=86400000000000n,'Post-CI runtime proof chronology differs');
 const expectedPoint={commit:candidateCommit,tree,branch:'main',originMain:candidateCommit,clean:true};must(isDeepStrictEqual(receipt.sourceBefore,expectedPoint)&&isDeepStrictEqual(receipt.sourceAfter,expectedPoint),'Actual before/after clean main bindings differ');
 must(isDeepStrictEqual(receipt.boundary,BOUNDARY)&&isDeepStrictEqual(receipt.gitProof,gitProof)&&isDeepStrictEqual(receipt.producerHashes,producers),'Runtime source/producer/boundary differs');
 must(isDeepStrictEqual(receipt.ciHashes,{release:valueHash(releaseCi),security:valueHash(securityCi)}),'Runtime CI child binding differs');
 must(isDeepStrictEqual(receipt.exportedSources,sourceInventories),'Complete exported Git inventories differ');
 keys(receipt.tools,['node','npm','baselineCompiler','candidateCompiler'],'Tools');
 for(const [name,t]of Object.entries(receipt.tools)){keys(t,['version','sha256'],'Tool '+name);must(typeof t.version==='string'&&typeof t.sha256==='string'&&SHA.test(t.sha256),'Actual tool evidence required');}
 must(/^v22\.\d+\.\d+$/.test(receipt.tools.node.version)&&/^\d+\.\d+\.\d+$/.test(receipt.tools.npm.version)&&/^\d+\.\d+\.\d+$/.test(receipt.tools.baselineCompiler.version),'Actual supported tool versions required');
 must(isDeepStrictEqual(receipt.tools.baselineCompiler,receipt.tools.candidateCompiler),'Compiler differs between builds');
 must(Array.isArray(receipt.commands)&&receipt.commands.length===PLAN.length,'Complete command sequence required');let previous=started;
 const structured={};
 for(let i=0;i<PLAN.length;i++){
  const c=receipt.commands[i],[id,role,tool,args]=PLAN[i];keys(c,['id','role','tool','args','startedAtUtc','completedAtUtc','exitCode','stdout','stderr','stdoutText','structuredResult'],'Command');
  must(c.id===id&&c.role===role&&c.tool===tool&&isDeepStrictEqual(c.args,args)&&c.exitCode===0,'Fixed successful command required');const a=utc(c.startedAtUtc),b=utc(c.completedAtUtc);must(previous<=a&&a<=b&&b<=ended,'Command execution chronology differs');previous=b;validBytes(c.stdout);validBytes(c.stderr);
  const needs=['baseline-emitted','candidate-emitted','baseline-installed','candidate-installed','root-full','root-runtime','functions-full','functions-runtime','cli-full'].includes(id);
  must(needs?object(c.structuredResult):c.structuredResult===null,'Unexpected/missing structured command result');
  const needsText=needs||id==='node-version'||id==='npm-version';must(needsText?typeof c.stdoutText==='string':c.stdoutText===null,'Measured structured stdout text required');if(needsText){must(isDeepStrictEqual(c.stdout,recordBytes(Buffer.from(c.stdoutText,'utf8'))),'Structured stdout digest differs');if(needs)must(isDeepStrictEqual(JSON.parse(c.stdoutText),c.structuredResult),'Structured stdout parsing differs');else must(c.stdoutText.trim()===receipt.tools[id==='node-version'?'node':'npm'].version,'Tool version not bound to actual stdout');}if(needs)structured[id]=c.structuredResult;
 }
 keys(receipt.emitted,['baseline','candidate'],'Emitted populations');keys(receipt.installed,['baseline','candidate'],'Installed populations');keys(receipt.audits,['root-full','root-runtime','functions-full','functions-runtime','cli-full'],'Audit populations');
 for(const side of ['baseline','candidate']){
  const emitted=receipt.emitted[side];must(object(emitted)&&Object.keys(emitted).length>0&&Object.keys(emitted).length<=10000&&Object.hasOwn(emitted,'index.js')&&Object.hasOwn(emitted,'index.js.map'),'Complete bounded emitted inventory required');for(const[p,v]of Object.entries(emitted)){must(safe(p)&&/\.js(?:\.map)?$/.test(p),'Invalid emitted path');validBytes(v);}
  const info=structured[side+'-emitted'];keys(info,['sourceCount','expectedFiles','actualFiles'],'Emitted compiler report');must(Number.isSafeInteger(info.sourceCount)&&info.sourceCount>0&&Array.isArray(info.expectedFiles)&&Array.isArray(info.actualFiles)&&isDeepStrictEqual(info.expectedFiles,info.actualFiles)&&isDeepStrictEqual([...info.expectedFiles].sort(),Object.keys(emitted).sort()),'Compiler expected/actual/emitted set differs');
  const sourceCount=sourceInventories[side].filter(x=>x.path.startsWith('functions/src/')&&/\.ts$/.test(x.path)).length;must(info.sourceCount===sourceCount,'Compiler source population differs from Git');must(isDeepStrictEqual(info.expectedFiles,expectedEmittedFiles(sourceInventories[side])),'Compiler expected output names differ from immutable Git sources');
  must(isDeepStrictEqual(receipt.installed[side],structured[side+'-installed']),'Installed graph not bound to command');verifyInstalledAgainstLock({...actualRuntimeInputs[side],graph:receipt.installed[side]});
 }
 for(const id of Object.keys(receipt.audits))must(isDeepStrictEqual(receipt.audits[id],structured[id]),'Audit not bound to command');
 const hashes=side=>Object.fromEntries(Object.entries(receipt.emitted[side]).map(([p,v])=>[p,v.sha256]));
 verifyLocalRuntimeProof({baselineFiles:hashes('baseline'),candidateFiles:hashes('candidate'),baselineInstalledRuntime:receipt.installed.baseline,candidateInstalledRuntime:receipt.installed.candidate,audits:receipt.audits});
 must(isDeepStrictEqual(receipt.emitted.baseline,receipt.emitted.candidate),'Emitted byte counts differ');return {ok:true,emittedFileCount:Object.keys(receipt.emitted.baseline).length,constructionAuthority:false};
}
function verifyRuntimeProof31({repoRoot,candidateCommit,receipt,releaseCi,securityCi,decisionAtUtc}){
 must(COMMIT.test(candidateCommit),'Immutable candidate commit required');const tree=text(repoRoot,['rev-parse',candidateCommit+'^{tree}']),decision=utc(decisionAtUtc),lastCi=ciCompletion(releaseCi,securityCi,candidateCommit,tree,decision);
 return validateMeasured(receipt,{candidateCommit,tree,lastCi,decision,releaseCi,securityCi,gitProof:verifyGitDevelopmentTooling({repoRoot,candidateCommit}),producers:producerHashes(repoRoot,candidateCommit),sourceInventories:{baseline:sourceInventory(repoRoot,DEPLOYED_BASELINE),candidate:sourceInventory(repoRoot,candidateCommit)},runtimeInputs:{baseline:runtimeInputs(repoRoot,DEPLOYED_BASELINE),candidate:runtimeInputs(repoRoot,candidateCommit)}});
}
function verifyRuntimeProof({repoRoot,candidateCommit,proofFile,expectedSha256,releaseCi,securityCi,decisionAtUtc}){
 must(typeof expectedSha256==='string'&&SHA.test(expectedSha256),'Expected physical proof SHA required');const proofStat=fs.lstatSync(proofFile);must(proofStat.isFile()&&!proofStat.isSymbolicLink()&&proofStat.size<=64*1024*1024,'Bounded physical proof file required');const bytes=fs.readFileSync(proofFile);must(hash(bytes)===expectedSha256,'Physical proof hash differs');return verifyRuntimeProof31({repoRoot,candidateCommit,receipt:JSON.parse(decoder.decode(bytes)),releaseCi,securityCi,decisionAtUtc});
}
function collectRuntimeProof({repoRoot,candidateCommit,releaseCiFile,securityCiFile,outputDirectory,nodeExecutable=process.execPath,npmCliFile}){
 // All source/CI gates precede output creation, installations or network work.
 const startedAtUtc=new Date().toISOString(),sourceBefore=sourcePoint(repoRoot,candidateCommit),releaseCi=JSON.parse(fs.readFileSync(releaseCiFile,'utf8')),securityCi=JSON.parse(fs.readFileSync(securityCiFile,'utf8'));
 ciCompletion(releaseCi,securityCi,candidateCommit,sourceBefore.tree,utc(startedAtUtc));
 const gitProof=verifyGitDevelopmentTooling({repoRoot,candidateCommit}),producers=producerHashes(repoRoot,candidateCommit);
 must(hash(fs.readFileSync(__filename))===producers[SELF],'Executing collector differs from candidate Git producer');
 for(const file of PRODUCERS)must(hash(fs.readFileSync(path.join(repoRoot,file)))===producers[file],'Loaded producer differs from candidate Git');
 must(path.isAbsolute(outputDirectory)&&!fs.existsSync(outputDirectory),'New exclusive absolute output directory required');
 must(path.isAbsolute(nodeExecutable)&&path.isAbsolute(npmCliFile??''),'Explicit absolute Node/npm executable paths required');
 must(path.basename(npmCliFile)==='npm-cli.js'&&path.basename(path.dirname(npmCliFile))==='bin','Exact npm CLI package entry required');const npmPackageRoot=path.dirname(path.dirname(npmCliFile)),npmBefore=measureToolPackage(npmPackageRoot,'npm');
 const nodeVersion=execFileSync(nodeExecutable,['--version'],{encoding:'utf8',windowsHide:true,timeout:10000}).trim();must(/^v22\.\d+\.\d+$/.test(nodeVersion),'Approved actual Node22 required before installs');
 fs.mkdirSync(outputDirectory,{recursive:false});const commands=[],logs=path.join(outputDirectory,'logs');fs.mkdirSync(logs);
 const profile=path.join(outputDirectory,'profile');fs.mkdirSync(profile);const blank=path.join(profile,'empty-npmrc');fs.writeFileSync(blank,'',{flag:'wx'});
 const env={};for(const k of ['SystemRoot','SYSTEMROOT','WINDIR','ComSpec','COMSPEC','PATHEXT','TEMP','TMP'])if(process.env[k])env[k]=process.env[k];
 env.PATH=path.dirname(nodeExecutable)+path.delimiter+(process.env.PATH??'');env.USERPROFILE=profile;env.APPDATA=profile;env.LOCALAPPDATA=profile;env.CI='true';env.npm_config_userconfig=blank;env.npm_config_globalconfig=blank;env.npm_config_cache=path.join(profile,'cache');env.npm_config_registry=REGISTRY;
 const dirs={baseline:path.join(outputDirectory,'baseline'),candidate:path.join(outputDirectory,'candidate')};
 try{
  const exportedSources={baseline:exportGit(repoRoot,DEPLOYED_BASELINE,dirs.baseline),candidate:exportGit(repoRoot,candidateCommit,dirs.candidate)};
  // Lock URLs are source-reviewed and must not introduce an unapproved registry.
  for(const [role,rel]of [['baseline','functions/package-lock.json'],['candidate','functions/package-lock.json'],['candidate','package-lock.json'],['candidate','tooling/firebase-cli/package-lock.json']]){
   const lock=JSON.parse(fs.readFileSync(path.join(dirs[role],rel),'utf8'));for(const pkg of Object.values(lock.packages??{}))if(typeof pkg.resolved==='string')must(pkg.resolved.startsWith('file:')||pkg.resolved.startsWith(REGISTRY),'Non-official npm destination rejected');
  }
  const results={};let compilerBefore=null;const compiler=side=>measureToolPackage(path.join(dirs[side],'functions/node_modules/typescript'),'typescript');
  const originalNode=hash(fs.readFileSync(nodeExecutable));
  for(const[id,role,tool,args]of PLAN){
   if(id==='baseline-build'){compilerBefore={baseline:compiler('baseline'),candidate:compiler('candidate')};must(isDeepStrictEqual(compilerBefore.baseline,compilerBefore.candidate),'Installed compilers differ before builds');}
   const cwd=role==='tool'?outputDirectory:path.join(outputDirectory,...role.split('/'));const argv=tool==='npm'?[npmCliFile,...args]:args;const a=new Date().toISOString();
   const run=spawnSync(nodeExecutable,argv,{cwd,env,windowsHide:true,timeout:900000,maxBuffer:64*1024*1024,encoding:null});const b=new Date().toISOString();
   results[id]=recordCommandRun({run,entry:[id,role,tool,args],startedAtUtc:a,completedAtUtc:b,logs,outputDirectory,commands});
  }
  for(const side of ['baseline','candidate'])assertExportPreserved(dirs[side],exportedSources[side]);
  must(compilerBefore&&isDeepStrictEqual(compilerBefore,{baseline:compiler('baseline'),candidate:compiler('candidate')}),'Compiler changed during builds');must(originalNode===hash(fs.readFileSync(nodeExecutable))&&isDeepStrictEqual(npmBefore,measureToolPackage(npmPackageRoot,'npm'))&&results['npm-version']===npmBefore.version,'Node/npm changed during collection');
  const emitted={baseline:inventory(path.join(dirs.baseline,'functions/lib')),candidate:inventory(path.join(dirs.candidate,'functions/lib'))};
  const receipt=sealReceipt({schemaVersion:1,evidenceType:TYPE,candidateCommit,candidateTree:sourceBefore.tree,baselineCommit:DEPLOYED_BASELINE,startedAtUtc,completedAtUtc:new Date().toISOString(),sourceBefore,sourceAfter:sourcePoint(repoRoot,candidateCommit),producerHashes:producers,ciHashes:{release:valueHash(releaseCi),security:valueHash(securityCi)},gitProof,exportedSources,tools:{node:{version:results['node-version'],sha256:hash(fs.readFileSync(nodeExecutable))},npm:npmBefore,baselineCompiler:compiler('baseline'),candidateCompiler:compiler('candidate')},commands,emitted,installed:{baseline:results['baseline-installed'],candidate:results['candidate-installed']},audits:Object.fromEntries(['root-full','root-runtime','functions-full','functions-runtime','cli-full'].map(k=>[k,results[k]])),boundary:BOUNDARY});
  verifyRuntimeProof31({repoRoot,candidateCommit,receipt,releaseCi,securityCi,decisionAtUtc:new Date().toISOString()});
  const file=path.join(outputDirectory,'runtime-proof.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});return {file,sha256:hash(fs.readFileSync(file)),constructionAuthority:false};
 }catch(error){fs.writeFileSync(path.join(outputDirectory,'failure.json'),JSON.stringify({recordedAtUtc:new Date().toISOString(),status:'FAILED',error:String(error.message),completedCommands:commands,boundary:BOUNDARY},null,2)+'\n',{flag:'wx'});throw error;}
}
module.exports={collectRuntimeProof,verifyRuntimeProof,verifyRuntimeProof31,validateMeasured,ciCompletion,validateExactMainCiPair,PLAN,TYPE,BOUNDARY,SELF,sourcePoint,inventory,exportGit,sourceInventory,producerHashes,expectedEmittedFiles,assertExportPreserved,recordCommandRun,runtimeInputs,verifyInstalledAgainstLock,gitBlobs,measureToolPackage};
if(require.main===module){console.error('Invoke collectRuntimeProof with explicit reviewed arguments after actual source and CI exist.');process.exitCode=2;}
