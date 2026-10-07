"use strict";
// Synthetic authority/archive data isolates the real fresh-loader/context seam.
// No credential, actual CLI, cloud request, or deployment is exercised.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const project='crm3-baf-ops-b8638',source={commit:'1'.repeat(40),tree:'2'.repeat(40),functionsTree:'3'.repeat(40)};
function fixture(t,mode) {
  const root=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'b31-capture-startup-')),release=path.join(root,'release'),data=path.join(root,'data'),cli=path.join(root,'cli'),mark=path.join(root,'hash-imported');
  fs.mkdirSync(release);fs.mkdirSync(data);fs.mkdirSync(cli);
  // Copies are private test inputs. Only the controller driver and data-returning
  // authority functions below are substituted; bootstrap, closure and endpoint
  // hashing import logic execute their actual source bytes.
  for(const row of fs.readdirSync(__dirname,{withFileTypes:true}))if(row.isFile()&&/\.(cjs|js|json|py)$/.test(row.name)&&!row.name.includes('.test.'))fs.copyFileSync(path.join(__dirname,row.name),path.join(release,row.name));
  fs.copyFileSync(path.join(__dirname,'business31OperationalController.cjs'),path.join(release,'actual-controller.cjs'));
  const put=(name,value)=>{const bytes=Buffer.isBuffer(value)?value:Buffer.from(JSON.stringify(value)+'\n'),file=path.join(data,name);fs.writeFileSync(file,bytes);return {file:name,sha256:sha(bytes),bytes:bytes.length};};
  const archive=put('archive.bin',Buffer.from('inert archive; archive verification is outside this test'));
  const pkg=Buffer.from('{}'),output=put('output.js',Buffer.from('inert output'));
  const inventory={'package.json':{sha256:sha(pkg),bytes:pkg.length},'package-lock.json':{sha256:sha(pkg),bytes:pkg.length},'lib/index.js':{sha256:output.sha256,bytes:output.bytes}};
  const hashFile=path.join(cli,'firebase-tools/lib/deploy/functions/cache/hash.js');fs.mkdirSync(path.dirname(hashFile),{recursive:true});
  fs.writeFileSync(hashFile,`require('node:fs').writeFileSync(${JSON.stringify(mark)},'imported');module.exports={getEnvironmentVariablesHash:()=> 'env',getEndpointHash:()=> 'endpoint',getSecretsHash:()=> 'secrets'};\n`);
  for(const file of ['firebase-tools/lib/bin/firebase.js','firebase-tools/lib/deploy/functions/cache/applyHash.js','firebase-tools/lib/functions/secrets.js']){fs.mkdirSync(path.dirname(path.join(cli,file)),{recursive:true});fs.writeFileSync(path.join(cli,file),'module.exports={};\n');}
  const cliMap={};function walk(dir,prefix=''){for(const row of fs.readdirSync(dir,{withFileTypes:true})){const name=prefix+row.name;if(row.isDirectory())walk(path.join(dir,row.name),name+'/');else cliMap[name]=sha(fs.readFileSync(path.join(dir,row.name)));}}walk(cli);
  const cliPointer=put('cli-map.json',cliMap),runtime={cliEntrypoint:path.join(cli,'firebase-tools/lib/bin/firebase.js'),cliFileBindings:{path:path.join(data,cliPointer.file),sha256:cliPointer.sha256},endpointHashProducerSha256:{apply:cliMap['firebase-tools/lib/deploy/functions/cache/applyHash.js'],hash:cliMap['firebase-tools/lib/deploy/functions/cache/hash.js'],secrets:cliMap['firebase-tools/lib/functions/secrets.js']}};
  const intent={schemaVersion:1,documentType:'firebase-cli-approved-intended-hash-inputs',source,sourceBefore:source,sourceAfter:source,sourceArchiveHash:'4'.repeat(40),codebase:'default',startedAtUtc:'2026-10-01T00:00:01Z',completedAtUtc:'2026-10-01T00:00:02Z',environmentVariables:{GCLOUD_PROJECT:project,FIREBASE_CONFIG:JSON.stringify({projectId:project}),CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:'false'},endpoints:{inert:{id:'inert',platform:'gcfv2',project,region:'asia-south1',secretEnvironmentVariables:[]}},archive};
  const intentP=put('intent.json',intent),proofP=put('proof.json',{completedAtUtc:'2026-10-01T00:00:00Z',buildRoot:root,emittedFiles:{'lib/index.js':output}});
  const preparation=put('preparation.json',{intendedHashInputs:intentP,runtimeProof:proofP,startedAtUtc:intent.startedAtUtc,completedAtUtc:intent.completedAtUtc,archiveExpectedFiles:put('inventory.json',inventory)});
  const contract=put('contract.json',{schemaVersion:2,intentPreparation:preparation,intendedHashInputs:intentP,runtimeProof:proofP,preparedAtUtc:'2026-10-01T00:00:03Z'});
  const owner=put('owner.json',{originalMessage:put('message.json',{receivedAtUtc:'2026-10-01T00:00:04Z'})});
  const controls=put('controls.json',{functions:[{bodyText:JSON.stringify({functions:[{name:'projects/p/locations/r/functions/inert'}]})}]});
  const observed={observedAtUtc:'2026-10-01T00:00:00Z',capturedAtUtc:'2026-10-01T00:00:00Z'};
  const decision=put('decision.json',{schemaVersion:2,executionContract:contract,runtimeProof:proofP,ownerAuthorization:owner,mainCi:put('ci.json',{capturedAtUtc:observed.capturedAtUtc}),securityCi:put('security.json',{capturedAtUtc:observed.capturedAtUtc}),preflightPointers:{controls:put('controls-envelope.json',{measurement:controls,...observed})},schedulerBaseline:put('scheduler-envelope.json',{response:put('scheduler.json',{response:{}})})});
  const historical=fs.readFileSync(path.resolve(__dirname,'../../release/evidence/build30-current-source-backend-deployment-closure.json'));
  fs.writeFileSync(path.join(data,'historical.json'),historical);
  const facts={root,data,mark,mode,runtime,source,decision,inventory,intent,observed,hashFile};fs.writeFileSync(path.join(data,'facts.json'),JSON.stringify(facts));
  fs.writeFileSync(path.join(release,'business31OperationalController.cjs'),`"use strict";
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const bootstrap=require('./business31CaptureBootstrap.cjs');bootstrap.assertOperational31();
const f=JSON.parse(fs.readFileSync(${JSON.stringify(path.join(data,'facts.json'))}));
const a=require('./business31BackendAuthority.cjs'),x=require('./business31ExecutionContract.cjs'),neutral=require('./backendRuntimeClosure31.cjs'),controls=require('./backendRuntimeControls31.cjs');
a.verifyBusiness31BackendAuthority=()=>({source:f.source,originalDecision:f.decision,executionInputs:{approval:{}},decisionPointer:{commit:f.source.commit,file:'synthetic',sha256:'A'.repeat(64)}});
a.expectedEmittedFiles31=()=>['lib/index.js'];
x.cohortsFromPolicy=()=>({callables:['inert'],events:[],schedulers:[],fleet:['inert']});x.deriveRuntime31=()=>f.runtime;
require('./business31TrustedInput.cjs').openTrustedGitRepository31=()=>({snapshot:()=>({files:{}}),readBlob:(commit,file)=>file.endsWith('build30-current-source-backend-deployment-closure.json')?fs.readFileSync(path.join(f.data,'historical.json')):Buffer.from('{}')});
neutral.actualArchiveInventory31=()=>{if(f.mode==='changed')fs.appendFileSync(f.hashFile,'\\n// changed after admission');return f.inventory;};
neutral.verifyArchiveBytes31=()=>({sourceArchiveHash:f.intent.sourceArchiveHash});
controls.verifyPreservedControlsBefore31=()=>{if(f.mode==='failure')throw Error('synthetic later control refusal');return f.observed;};controls.schedulerControl31=()=>({});
module.exports.runController31=async entry=>{
 const api=require('./business31BackendClosure.cjs'),options={repositoryRoot:f.root,gitExecutable:process.execPath,gitSha256:'A'.repeat(64),evidenceDirectory:f.data,trustedVerifier:{files:{}}};
 if(['controller-cleanup','phase-admission-cleanup','phase-selection-cleanup'].includes(f.mode)){
   let error;try {
     if(f.mode==='controller-cleanup')await require('./actual-controller.cjs').runController31(entry);
     else if(f.mode==='phase-selection-cleanup'){
       const recorder=require('./business31CaptureRecorder.cjs');
       recorder.createBusinessPhaseCapture31=()=>({writer:{},common:api.prepareBusinessOperationalCaptureContext31(options),guardInputs:{}});
       const contextFile=path.join(f.data,'phase-context.json');fs.writeFileSync(contextFile,JSON.stringify({phase:'callables'}));
       await require('./actual-controller.cjs').runPhaseChild31({contextFile,contextSha256:x.sha(fs.readFileSync(contextFile)),configuration:entry.configuration});
     }
     else require('./business31CaptureRecorder.cjs').createBusinessPhaseCapture31({authorityOptions:options,phase:'callables',contextFile:path.join(f.root,'wrong-context.json'),contextSha256:'A'.repeat(64)});
   }catch(e){error=e;}
   assert.ok(error);assert.match(error.message,f.mode==='phase-admission-cleanup'?/exact parent context path required/:/selected execution fields differ/);
   assert.ok(fs.existsSync(f.mark));assert.throws(()=>bootstrap.installCliLoadBoundary31(f.runtime),/terminal|cannot reopen/);
   process.stdout.write(JSON.stringify({mode:f.mode,hashImported:true,closed:true})+'\\n');return;
 }
 let common,error;try{common=(api.prepareBusinessOperationalCaptureContext31??api.prepareBusinessCaptureContext31)(options);}catch(e){error=e;}
 if(f.mode==='success'){if(error)throw error;assert.ok(fs.existsSync(f.mark));common.cliLoadLease.assertHealthy();common.cliLoadLease.release();}
 else {assert.ok(error);assert.match(error.message,f.mode==='failure'?/synthetic later control refusal/:/Endpoint hash producer differs|changed module/);assert.equal(fs.existsSync(f.mark),f.mode==='failure');}
 assert.throws(()=>bootstrap.installCliLoadBoundary31(f.runtime),/terminal|cannot reopen/);
 process.stdout.write(JSON.stringify({mode:f.mode,hashImported:fs.existsSync(f.mark),closed:true})+'\\n');
};\n`);
  const map={};for(const name of fs.readdirSync(release))map[name]=sha(fs.readFileSync(path.join(release,name)));
  const env={};for(const name of ['SystemRoot','WINDIR','COMSPEC','PATHEXT','HOMEDRIVE','HOMEPATH','LOGONSERVER','SYSTEMDRIVE','USERDOMAIN','USERNAME'])if(process.env[name]!==undefined)env[name]=process.env[name];Object.assign(env,{HOME:root,USERPROFILE:root,TEMP:root,TMP:root,PATH:path.dirname(process.execPath)});
  const config=path.join(root,'selection.json');fs.writeFileSync(config,JSON.stringify({schemaVersion:1,documentType:'build31-business-protected-selection',authority:{repositoryRoot:root,gitExecutable:process.execPath,gitSha256:'A'.repeat(64),trustedVerifier:{files:{}},sourceCommit:source.commit,sourceManifest:{},trustedManifestSha256:'A'.repeat(64),evidenceDirectory:data,decisionPointer:{}},execution:{sourceRoot:release,helperFiles:map,nodeExecutable:{path:process.execPath,sha256:sha(fs.readFileSync(process.execPath))},environment:env}}));
  const result=cp.spawnSync(process.execPath,['--no-global-search-paths',path.join(release,'business31CaptureBootstrap.cjs'),'--business-controller',config,sha(fs.readFileSync(config))],{cwd:root,env,windowsHide:true,encoding:'utf8',timeout:60000,maxBuffer:2*1024*1024});
  fs.writeFileSync(path.join(root,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(root,'stderr.log'),result.stderr??'');
  t.diagnostic('Retained synthetic startup fixture: '+root);
  assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,0,result.stderr);return JSON.parse(result.stdout);
}
test('fresh operational context admits the exact CLI before the genuine endpoint hash import',t=>assert.deepEqual(fixture(t,'success'),{mode:'success',hashImported:true,closed:true}));
test('a later context failure releases the admitted CLI lease without reopening the lifetime',t=>assert.deepEqual(fixture(t,'failure'),{mode:'failure',hashImported:true,closed:true}));
test('changed CLI bytes still refuse before evaluation and close the failed context lifetime',t=>assert.deepEqual(fixture(t,'changed'),{mode:'changed',hashImported:false,closed:true}));
test('actual controller releases context admission on selected execution refusal',t=>assert.deepEqual(fixture(t,'controller-cleanup'),{mode:'controller-cleanup',hashImported:true,closed:true}));
test('actual recorder releases context admission on phase custody refusal',t=>assert.deepEqual(fixture(t,'phase-admission-cleanup'),{mode:'phase-admission-cleanup',hashImported:true,closed:true}));
test('actual phase cleanup releases a successful recorder context when selection then refuses',t=>assert.deepEqual(fixture(t,'phase-selection-cleanup'),{mode:'phase-selection-cleanup',hashImported:true,closed:true}));
