'use strict';
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process'),{createHash}=require('node:crypto'),assert=require('node:assert/strict'),test=require('node:test');
const {DEPLOYED_BASELINE,verifyDevelopmentToolingSnapshots,runtimeReachability,verifyLocalRuntimeProof}=require('./clientBuildToolingCompatibility31.cjs');
const repo=execFileSync('git',['-C',__dirname,'rev-parse','--show-toplevel'],{encoding:'utf8',windowsHide:true}).trim();
const jsonPaths=new Set(['package.json','package-lock.json','functions/package.json','functions/package-lock.json','tooling/brace-expansion-compat/package.json']);
const roots=['.npmrc','tooling/firebase-cli/.npmrc','functions','android','firestore.rules','firestore.indexes.json',...jsonPaths,'tooling/brace-expansion-compat/index.cjs','tooling/brace-expansion-compat/index.mjs'];
const entries=execFileSync('git',['--no-replace-objects','-C',repo,'ls-tree','-r','-z',DEPLOYED_BASELINE,'--',...roots],{encoding:'utf8'}).split('\0').filter(Boolean);
const before={},after={};
for(const entry of entries){
 const [,mode,blob,p]=/^(\d+) blob ([0-9a-f]+)\t(.+)$/.exec(entry);
 if(jsonPaths.has(p)){
  before[p]=execFileSync('git',['--no-replace-objects','-C',repo,'show',DEPLOYED_BASELINE+':'+p],{encoding:'utf8'});
  after[p]=p==='functions/package.json'?before[p]:fs.readFileSync(path.join(__dirname,'../..',p),'utf8');
 }else before[p]=after[p]='git-blob:'+mode+':'+blob;
}
function fixture(){return {baselineCommit:DEPLOYED_BASELINE,before:structuredClone(before),after:structuredClone(after)};}
function mutateJson(f,p,action){const o=JSON.parse(f.after[p]);action(o);f.after[p]=JSON.stringify(o);}
const lock='functions/package-lock.json';
test('real minimal dev-only proposal passes exact snapshots and independent runtime reachability',()=>{const r=verifyDevelopmentToolingSnapshots(fixture());assert.equal(r.ok,true);assert.equal(r.runtimeReachablePaths,252);assert.equal(r.constructionAuthority,false);});
const negatives=[
 ['wrong deployed baseline',f=>{f.baselineCommit='0'.repeat(40)}],
 ['Functions source changed',f=>{f.after['functions/src/index.ts']='different'}],
 ['Functions tool changed',f=>{f.after['functions/tools/emitted_output_custody.mjs']='different'}],
 ['Functions file omitted',f=>{delete f.after['functions/src/index.ts']}],
 ['Functions file added',f=>{f.after['functions/src/unreviewed.ts']='new'}],
 ['native byte change',f=>{f.after[Object.keys(f.after).find(p=>p.startsWith('android/'))]='changed'}],
 ['Rules change',f=>{f.after['firestore.rules']='changed'}],
 ['indexes change',f=>{f.after['firestore.indexes.json']='changed'}],
 ['runtime declaration changed',f=>mutateJson(f,'functions/package.json',o=>{o.dependencies.uuid='12.0.0'})],
 ['root manifest changed',f=>mutateJson(f,'package.json',o=>{o.overrides={}})],
 ['adapter executable changed',f=>{f.after['tooling/brace-expansion-compat/index.cjs']='changed'}],
 ['adapter extra dependency',f=>mutateJson(f,'tooling/brace-expansion-compat/package.json',o=>{o.dependencies.extra='1.0.0'})],
 ['adapter exports changed',f=>mutateJson(f,'tooling/brace-expansion-compat/package.json',o=>{o.exports={}})],
 ['dev numeric-one substituted',f=>mutateJson(f,lock,o=>{o.packages['node_modules/brace-expansion'].dev=1})],
 ['dev flag removed',f=>mutateJson(f,lock,o=>{delete o.packages['node_modules/brace-expansion-modern'].dev})],
 ['registry URL changed',f=>mutateJson(f,lock,o=>{o.packages['node_modules/brace-expansion-modern'].resolved='https://example.invalid/package.tgz'})],
 ['registry integrity changed',f=>mutateJson(f,lock,o=>{o.packages['node_modules/brace-expansion-modern'].integrity='sha512-wrong'})],
 ['upstream package aliased elsewhere',f=>mutateJson(f,lock,o=>{o.packages['node_modules/brace-expansion-modern'].name='other'})],
 ['nested override added',f=>mutateJson(f,lock,o=>{o.packages['node_modules/x/node_modules/brace-expansion']={version:'5.0.12',dev:true}})],
 ['unrelated dev package changed',f=>mutateJson(f,lock,o=>{o.packages['node_modules/typescript'].version='9.0.0'})],
 ['runtime package changed',f=>mutateJson(f,lock,o=>{o.packages['node_modules/uuid'].version='12.0.0'})],
 ['runtime package removed',f=>mutateJson(f,lock,o=>{delete o.packages['node_modules/uuid']})],
 ['balanced-match edge changed',f=>mutateJson(f,lock,o=>{o.packages['node_modules/brace-expansion-modern'].dependencies['balanced-match']='*'})],
 ['root lock not fixed',f=>{f.after['package-lock.json']=f.before['package-lock.json']}],
 ['Functions lock not fixed',f=>{f.after[lock]=f.before[lock]}],
 ['lock schema differs',f=>mutateJson(f,lock,o=>{o.lockfileVersion=2})],
 ['extra lock top-level key',f=>mutateJson(f,lock,o=>{o.unreviewed=true})],
];
for(const[name,action]of negatives)test('rejects '+name,()=>{const f=fixture();action(f);assert.throws(()=>verifyDevelopmentToolingSnapshots(f));});
test('reachability rejects a runtime-reachable package marked dev',()=>{const pkg={dependencies:{consumer:'1'}};const l={packages:{'node_modules/consumer':{version:'1',dependencies:{hidden:'1'}},'node_modules/hidden':{version:'1',dev:true}}};assert.throws(()=>runtimeReachability(pkg,l),/falsely classified/);});
test('reachability follows nested resolution and peer dependency edges',()=>{const l={packages:{'node_modules/consumer':{version:'1',dependencies:{shared:'1'},peerDependencies:{peer:'1'}},'node_modules/consumer/node_modules/shared':{version:'1'},'node_modules/shared':{version:'2',dev:true},'node_modules/peer':{version:'1'}}};assert.deepEqual(Object.keys(runtimeReachability({dependencies:{consumer:'1'}},l)),['node_modules/consumer','node_modules/consumer/node_modules/shared','node_modules/peer']);});
test('reachability rejects unresolved mandatory dependencies',()=>assert.throws(()=>runtimeReachability({dependencies:{missing:'1'}},{packages:{}}),/Unresolved/));
// Explicitly synthetic corroboration fixture. Genuine local compilation/audit
// receipts remain separate; generated equality here is never source authority.
const cleanAudit={auditReportVersion:2,vulnerabilities:{},metadata:{vulnerabilities:{info:0,low:0,moderate:0,high:0,critical:0,total:0}}};
const output={'index.js':'A'.repeat(64),'index.js.map':'B'.repeat(64)};
const local={baselineFiles:structuredClone(output),candidateFiles:structuredClone(output),baselineInstalledRuntime:{name:'synthetic',dependencies:{runtime:{version:'1.0.0'}}},candidateInstalledRuntime:{name:'synthetic',dependencies:{runtime:{version:'1.0.0'}}},audits:Object.fromEntries(['root-runtime','root-full','functions-full','functions-runtime','cli-full'].map(name=>[name,structuredClone(cleanAudit)]))};
test('synthetic emitted/installed/audit equality is corroboration only',()=>{const r=verifyLocalRuntimeProof(local);assert.equal(r.emittedFileCount,2);assert.equal(r.constructionAuthority,false);});
for(const[name,action]of [
 ['emitted JS drift',f=>{f.candidateFiles[Object.keys(f.candidateFiles)[0]]='C'.repeat(64)}],
 ['emitted file omission',f=>{delete f.candidateFiles[Object.keys(f.candidateFiles)[0]]}],
 ['installed runtime drift',f=>{f.candidateInstalledRuntime.dependencies.extra={version:'1'}}],
 ['installed runtime errors',f=>{f.candidateInstalledRuntime.problems=['missing dependency']}],
 ['missing audit',f=>{delete f.audits['root-full']}],
 ['audit numeric-zero replaced by false',f=>{f.audits['functions-full'].metadata.vulnerabilities.high=false}],
 ['audit error envelope',f=>{f.audits['cli-full'].error={code:'EFAIL'}}],
 ['audit unknown schema',f=>{f.audits['cli-full'].auditReportVersion=3}],
 ['audit actual finding',f=>{f.audits['root-full'].vulnerabilities.extra={severity:'high'}}],
])test('rejects local proof '+name,()=>{const f=structuredClone(local);action(f);assert.throws(()=>verifyLocalRuntimeProof(f));});

test('missing root manifest from both snapshots fails',()=>{const f=fixture();delete f.before['package.json'];delete f.after['package.json'];assert.throws(()=>verifyDevelopmentToolingSnapshots(f),/Missing required/);});
test('optional peer cannot hide an absent mandatory dependency',()=>assert.throws(()=>runtimeReachability({dependencies:{consumer:'1'}},{packages:{'node_modules/consumer':{version:'1',dependencies:{missing:'1'},peerDependencies:{missing:'1'},peerDependenciesMeta:{missing:{optional:true}}}}}),/Unresolved/));
for(const p of ['', 'C:/escape.js', 'back\\slash.js', '../escape.js', '/root.js', 'double//slash.js'])test('rejects unsafe emitted path '+JSON.stringify(p),()=>{const f=structuredClone(local);f.baselineFiles[p]='A'.repeat(64);f.candidateFiles[p]='A'.repeat(64);assert.throws(()=>verifyLocalRuntimeProof(f),/Invalid emitted/);});
for(const p of ['C:/escape','back\\slash','../escape','double//slash'])test('rejects unsafe source path '+JSON.stringify(p),()=>{const f=fixture();f.before[p]='same';f.after[p]='same';assert.throws(()=>verifyDevelopmentToolingSnapshots(f),/Unsafe protected/);});
test('oversized runtime inventory rejected before traversal',()=>{const packages=Object.fromEntries(Array.from({length:10001},(_,i)=>['node_modules/p'+i,{version:'1'}]));assert.throws(()=>runtimeReachability({}, {packages}),/bounded/);});

const deployedRoot=execFileSync('git',['-C',repo,'show',DEPLOYED_BASELINE+':package.json'],{encoding:'utf8'});
test('only exact previously reviewed custody-script insertion admitted from deployed F',()=>{const f=fixture();f.before['package.json']=deployedRoot;const r=verifyDevelopmentToolingSnapshots(f);assert.ok(r.changedFiles.includes('package.json'));assert.equal(r.constructionAuthority,false);});
for(const[name,action]of [
 ['second script change',o=>{o.scripts.test='node arbitrary.js'}],
 ['additional compatibility test',o=>{o.scripts['test:distribution-readback-custody']+=' tools/release/other.test.mjs'}],
 ['runtime dependency addition',o=>{o.dependencies={extra:'1'}}],
 ['script non-string',o=>{o.scripts['test:distribution-readback-custody']=true}],
])test('root exact-script route rejects '+name,()=>{const f=fixture();f.before['package.json']=deployedRoot;mutateJson(f,'package.json',action);assert.throws(()=>verifyDevelopmentToolingSnapshots(f),/Root manifest delta/);});

for(const p of ['.npmrc','functions/.npmrc','tooling/firebase-cli/.npmrc'])test('install topology config required and immutable '+p,()=>{const f=fixture();delete f.before[p];delete f.after[p];assert.throws(()=>verifyDevelopmentToolingSnapshots(f),/Missing required/);const changed=fixture();changed.after[p]='install-links=false';assert.throws(()=>verifyDevelopmentToolingSnapshots(changed),/content differs/);});
