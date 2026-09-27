import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import net from 'node:net';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const project = 'demo-crm3-cf01';
const run = (args, cwd = root, env = process.env) => {
  const result = spawnSync(process.execPath, args, {cwd, env, stdio:'inherit'});
  if (result.error) throw result.error;
  return result.status ?? 1;
};
const flags=process.argv.slice(2);
if(flags.length>1 || flags.some((flag)=>!['--inside','--existing-ci'].includes(flag)))throw Error('Unsupported emulator test mode.');
if (flags.includes('--existing-ci')) {
  if(process.env.GCLOUD_PROJECT!=='demo-crm3-ci-journeys' ||
      process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18080' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19099') {
    throw Error('Existing-CI mode requires the exact isolated CI demo project and loopback ports.');
  }
  const folder=path.join(root,'.dart_tool','cf01-emulator-run');
  fs.mkdirSync(folder,{recursive:true});
  const report=path.join(folder,`http-ci-jest-${process.pid}-${Date.now()}.json`);
  const suite=path.join(root,'functions','test','retainedQueueMutations.httpEmulator.test.js');
  const status=run(['node_modules/jest/bin/jest.js','--runInBand','--runTestsByPath',suite,
    '--json',`--outputFile=${report}`],path.join(root,'functions'),{
    ...process.env,CF01_HTTP_EMULATOR_URL:'http://127.0.0.1:15001',
  });
  if(status!==0 || !fs.existsSync(report))throw Error('CF01 authenticated HTTP suite did not finish successfully.');
  const proof=JSON.parse(fs.readFileSync(report,'utf8'));
  if(proof.success!==true || proof.numTotalTests!==7 || proof.numPassedTests!==7 ||
    proof.numFailedTests!==0 || proof.numPendingTests!==0 || proof.numTodoTests!==0 ||
    proof.numTotalTestSuites!==1 || proof.numPassedTestSuites!==1 ||
    proof.numFailedTestSuites!==0 || proof.numPendingTestSuites!==0 ||
    proof.numRuntimeErrorTestSuites!==0 || proof.testResults?.length!==1 ||
    path.resolve(proof.testResults[0].name)!==suite || proof.testResults[0].status!=='passed' ||
    proof.testResults[0].assertionResults?.length!==7 ||
    proof.testResults[0].assertionResults.some((result)=>result.status!=='passed')) {
    throw Error('CF01 HTTP report is incomplete, skipped, failing, or from another suite.');
  }
  console.log(`CF01_HTTP_BOUNDARY_PASS tests=7 report=${path.relative(root,report)}`);
} else if (flags.includes('--inside')) {
  if (process.env.GCLOUD_PROJECT !== project ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18180' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:19199') {
    throw Error('Refusing to test outside the dedicated CF01 demo emulators.');
  }
  const http = run(['node_modules/jest/bin/jest.js', '--runInBand',
    'test/retainedQueueMutations.httpEmulator.test.js'], path.join(root, 'functions'));
  const rules = run(['node_modules/jest/bin/jest.js', '--runInBand', 'test/firestore.rules.test.js']);
  process.exitCode = http || rules;
} else {
  // Separate processes and ports; no import, export, reset, or interaction with
  // the desktop DEV emulator suite. emulators:exec owns and stops only this run.
  const folder = path.join(root, '.dart_tool', 'cf01-emulator-run');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_TOKEN) {
    throw Error('Refusing ambient cloud credentials for the isolated demo runner.');
  }
  for (const port of [19199,18180,19150,15101,14400,14500,19299,19499]) {
    await new Promise((resolve,reject) => {
      const server=net.createServer();
      server.once('error',()=>reject(Error(`Required isolated emulator port ${port} is occupied.`)));
      server.listen(port,'127.0.0.1',()=>server.close(resolve));
    });
  }
  fs.mkdirSync(folder, {recursive:true});
  const config = path.join(root, 'firebase.cf01.local');
  const generated=[];
  const exactFile=(file,content)=>{
    if(fs.existsSync(file)) {
      if(fs.readFileSync(file,'utf8')!==content) throw Error(`Refusing different existing fixture configuration: ${path.basename(file)}`);
    } else { fs.writeFileSync(file,content,{encoding:'utf8',flag:'wx'});generated.push(file); }
  };
  exactFile(config, JSON.stringify({
    firestore:{rules:'firestore.rules', indexes:'firestore.indexes.json'},
    functions:[{source:'functions', codebase:'default'}],
    emulators:{auth:{host:'127.0.0.1',port:19199}, firestore:{host:'127.0.0.1',port:18180,websocketPort:19150},
      functions:{host:'127.0.0.1',port:15101}, hub:{host:'127.0.0.1',port:14400},
      logging:{host:'127.0.0.1',port:14500}, eventarc:{host:'127.0.0.1',port:19299},
      tasks:{host:'127.0.0.1',port:19499}, ui:{enabled:false},singleProjectMode:false},
  }, null, 2));
  exactFile(path.join(root, 'functions', '.env.demo-crm3-cf01'), 'CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false\n');
  const disabledCredentials=path.join(folder,'nonexistent-cloud-credentials.json');
  if(fs.existsSync(disabledCredentials))throw Error('Credential isolation path must not exist.');
  // Emulator-aware SDK calls need no credential file. Any accidental call to
  // a non-emulated service must fail rather than use cached workstation ADC.
  const env = {...process.env, CF01_HTTP_EMULATOR_URL:'http://127.0.0.1:15101',
    GOOGLE_APPLICATION_CREDENTIALS:disabledCredentials, GCE_METADATA_HOST:'127.0.0.1:9'};
  try {
    process.exitCode = run(['tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js',
      'emulators:exec','--project',project,'--config',config,'--only','auth,firestore,functions',
      'node functions/tools/run_retained_queue_emulator_tests.mjs --inside'], root, env);
  } finally {
    for(const file of generated)fs.unlinkSync(file);
  }
}
