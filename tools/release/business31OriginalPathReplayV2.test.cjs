'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const replay=require('./business31OriginalPathReplayV2.cjs'),worker=require('./business31CoreWorkerV2.cjs');
const {spawnSync}=require('node:child_process');
const temporary=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'business31-v2-worker-'));
test('worker environment uses explicit keys and strips loaders credentials and inherited Git state',()=>{
 const keys=['NODE_OPTIONS','NODE_PATH','GOOGLE_APPLICATION_CREDENTIALS','GIT_CONFIG_COUNT','GIT_CONFIG_KEY_0','AWS_SECRET_ACCESS_KEY'];
 const old=Object.fromEntries(keys.map(k=>[k,process.env[k]]));try{for(const k of keys)process.env[k]='synthetic';
 const env=replay.workerEnvironment31();for(const k of keys)assert.equal(Object.hasOwn(env,k),false);
 assert.equal(env.GIT_CONFIG_NOSYSTEM,'1');assert.equal(env.GIT_TERMINAL_PROMPT,'0');
 }finally{for(const k of keys)if(old[k]===undefined)delete process.env[k];else process.env[k]=old[k];}
});
test('fresh native worker refuses unbound input before any original helper import',()=>{
 const file=path.join(temporary,'input.json');fs.writeFileSync(file,'{}');
 const child=spawnSync(process.execPath,['--no-global-search-paths',path.join(__dirname,'business31CoreWorkerV2.cjs'),file,'F'.repeat(64)],
  {env:replay.workerEnvironment31(),windowsHide:true,encoding:'utf8',timeout:30000});
 assert.equal(child.status,1);assert.equal(child.stdout,'');
 assert.ok(Buffer.byteLength(child.stderr,'utf8')<=512);
 assert.equal(child.stderr,'BUSINESS31_RECORDED_CORE_WORKER_FAILED '+JSON.stringify({
  schemaVersion:1,stage:'WORKER_INPUT',reason:'WORKER_WORKER_INPUT_CHANGED',nativeCode:null,
  workerExit:null,workerSignal:null,workerCleanupFailed:false,cleanupFailed:false
 })+'\n');
});
test('worker inventory retains prototype names and detects changes or added files',()=>{
 const root=path.join(temporary,'population');fs.mkdirSync(root);for(const name of ['ordinary','__proto__','constructor'])fs.writeFileSync(path.join(root,name),name);
 const before=worker.inventoryV2(root);assert.equal(Object.keys(before).length,3);assert.equal(Object.hasOwn(before,'__proto__'),true);
 fs.writeFileSync(path.join(root,'ordinary'),'changed');assert.notDeepEqual(worker.inventoryV2(root),before);
 fs.writeFileSync(path.join(root,'extra'),'new');assert.equal(Object.keys(worker.inventoryV2(root)).length,4);
});
test('unbound or changed recorded helper fails before it is imported',()=>{
 const root=path.join(temporary,'core');fs.mkdirSync(path.join(root,'retained','tools','release'),{recursive:true});
 const file=path.join(root,'retained','tools','release','synthetic.cjs');fs.writeFileSync(file,'throw Error("must never import");');
 const relocation={roots:[{original:'/original-absent',memberRoot:'retained'}],roles:{authorityRoot:'/original-absent'}};
 assert.throws(()=>worker.coreFiles(root,relocation,{'tools/release/synthetic.cjs':'F'.repeat(64)}),/recorded producer differs/);
});
test('recorded core worker bound covers the measured Windows replay with margin',()=>{
 // The full recorded core replay measured 622 s and 641 s on Windows; 600 s would end it mid-replay.
 assert.equal(replay.WORKER_TIMEOUT_MS,30*60*1000);
 assert.ok(replay.WORKER_TIMEOUT_MS>=2*641*1000);
 const source=fs.readFileSync(path.join(__dirname,'business31OriginalPathReplayV2.cjs'),'utf8');
 assert.match(source,/timeout:WORKER_TIMEOUT_MS,/);assert.doesNotMatch(source,/timeout:600000/);
});
test('outer entry refuses callback/PASS/token and unversioned input substitutions',()=>{
 for(const value of [{verifyClosure:()=>({recordedSemanticsReplayed:true})},{ok:true},{accessToken:'synthetic'}])assert.throws(()=>replay.verifyBusiness31OriginalPathReplayV2(value),/closed offline input/);
});
