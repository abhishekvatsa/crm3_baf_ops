'use strict';
const fs=require('node:fs'),path=require('node:path');
const a=require('./backendRuntimeAdmission31.cjs');
const {need,eq,hash,object,fileBinding,committed,child,source}=a.helpers;
const c=require('./backendRuntimeClosure31.cjs');
const {verifyBackendRuntimeExecutionAdmission31,observeLiveGitHub31}=require('./backendRuntimeExecutionAdmission31.cjs');
const {RuntimeDeploymentTransportGuard31,installApiBoundary31,installNetworkBoundary31}=require('./runtimeDeploymentTransportGuard31.cjs');

function captureActualPreparedInputs31({wantBackends,context,admission,intent,archiveExpectedFiles,startedAtUtc,sourceBefore,phase}){
  eq(Object.keys(wantBackends),['default'],'Only the existing default codebase is admitted');
  const backend=wantBackends.default,inputs=Object.values(backend.endpoints??{}).flatMap(region=>Object.values(region));
  eq(inputs.map(e=>e.id).sort(),admission.cohorts.fleet,'Actual prepared endpoint population differs');
  const endpoints={};for(const e of inputs){need(e.platform==='gcfv2'&&e.project===admission.projectId&&e.region===admission.region,'Actual prepared endpoint identity differs');endpoints[e.id]={id:e.id,platform:e.platform,project:e.project,region:e.region,secretEnvironmentVariables:structuredClone(e.secretEnvironmentVariables??[])};}
  const packageSource=context?.sources?.default;need(packageSource&&typeof packageSource.functionsSourceV2==='string'&&!packageSource.functionsSourceV1,'Exact V2 source package required');
  const archive=fs.readFileSync(packageSource.functionsSourceV2),verified=c.verifyArchiveBytes31(archive,archiveExpectedFiles);
  need(verified.sourceArchiveHash===packageSource.functionsSourceV2Hash&&verified.sourceArchiveHash===intent.sourceArchiveHash,'Actual complete ZIP/source hash differs from approved intent');
  need(a.helpers.gtext(admission.repoRoot,['branch','--show-current'])==='main'&&a.helpers.gtext(admission.repoRoot,['rev-parse','HEAD'])===admission.source.commit&&a.helpers.gtext(admission.repoRoot,['rev-parse','refs/remotes/origin/main'])===admission.source.commit&&a.helpers.gtext(admission.repoRoot,['status','--porcelain','--untracked-files=normal'])==='','Actual clean checkout changed during preparation');
  const point=source(admission.repoRoot,a.helpers.gtext(admission.repoRoot,['rev-parse','HEAD']));eq(point,admission.source,'Source changed during preparation');
  eq(sourceBefore,admission.source,'Original pre-prepare source observation differs');
  const record={schemaVersion:1,documentType:'firebase-cli-prepared-backend-hash-inputs',actualCliPreparationCaptured:true,approvalPointer:admission.approvalPointer,phase,instrumentationProducerSha256:admission.runtime.instrumentationProducerSha256,source:admission.source,sourceBefore,sourceAfter:point,sourceArchiveHash:verified.sourceArchiveHash,codebase:'default',startedAtUtc,completedAtUtc:new Date().toISOString(),environmentVariables:structuredClone(backend.environmentVariables??{}),endpoints};
  need(record.environmentVariables.GCLOUD_PROJECT===admission.projectId&&JSON.parse(record.environmentVariables.FIREBASE_CONFIG).projectId===admission.projectId,'Actual automatic Firebase environment differs');
  need(record.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK==='false','Mutating App Check enforcement cannot change');
  need(JSON.stringify(record.environmentVariables)===JSON.stringify(intent.environmentVariables),'Actual ordered prepared environment differs from approved intent');
  for(const name of admission.cohorts.fleet)need(JSON.stringify(record.endpoints[name])===JSON.stringify(intent.endpoints[name]),'Actual endpoint/resolved secret versions differ from approved intent: '+name);
  const endpointRuntimeHashes=c.endpointRuntimeHashes31({sourceArchiveHash:record.sourceArchiveHash,inputs:record,runtime:admission.runtime,names:admission.cohorts.fleet,source:admission.source});
  for(const e of inputs)need(e.hash===endpointRuntimeHashes[e.id],'Actual pinned CLI endpoint hash differs');
  return {...record,endpointRuntimeHashes,archiveSha256:hash(archive),archiveBytes:archive.length,archivePath:packageSource.functionsSourceV2};
}

async function readCurrentControlResponse31(Client,url,method='GET',body){
  const u=new URL(url),client=new Client({urlPrefix:u.origin});
  // Pinned apiv2 calls this mode xml, but returns the original response text.
  const response=await client.request({method,path:u.pathname,queryParams:u.searchParams,body,responseType:'xml',resolveOnHTTPError:true});
  need(typeof response.body==='string','Original raw current-control response required');
  return {url,method,httpStatus:response.status,bodyText:response.body};
}

function appendJson(file,value){fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx',mode:0o600});}
function exactPhaseDirectory(admission,phase){need(['callables','events','fleet'].includes(phase),'Unknown cohort');return path.join(admission.evidenceDirectory,'deployment-attempts',admission.approvalPointer.sha256,phase);}
function privateBinding(admission,file){const rel=path.relative(admission.evidenceDirectory,file).split(path.sep).join('/');need(rel&&!rel.startsWith('..')&&!path.isAbsolute(rel),'Private capture escaped evidence directory');return {file:rel,sha256:hash(fs.readFileSync(file))};}

function runInstrumentedCli31(configFile){
  const config=object(fs.readFileSync(configFile));eq(Object.keys(config).sort(),['repoRoot','authorityRoot','evidenceDirectory','approvalPointer','phase'].sort(),'No instrumented CLI overrides allowed');
  const {phase,...base}=config,admission=verifyBackendRuntimeExecutionAdmission31(base),directory=exactPhaseDirectory(admission,phase);
  const cliRoot=fs.realpathSync(path.dirname(path.dirname(path.dirname(path.dirname(admission.runtime.cliEntrypoint))))),cliMapRaw=fs.readFileSync(admission.runtime.cliFileBindings.path);need(hash(cliMapRaw)===admission.runtime.cliFileBindings.sha256,'Installed CLI proof changed');const cliBindings=object(cliMapRaw),Module=require('node:module'),loadModule=Module._load;
  Module._load=function(id,parent,isMain){const resolved=Module._resolveFilename(id,parent,isMain);if(path.isAbsolute(resolved)){const relative=path.relative(cliRoot,fs.realpathSync(resolved)),fromCli=parent?.filename&&(parent.filename===cliRoot||parent.filename.startsWith(cliRoot+path.sep));if(fromCli||relative&&!relative.startsWith('..')&&!path.isAbsolute(relative)){const key=relative.split(path.sep).join('/');need(relative&&!relative.startsWith('..')&&!path.isAbsolute(relative)&&Object.hasOwn(cliBindings,key)&&hash(fs.readFileSync(resolved))===cliBindings[key],'Unbound CLI module refused before evaluation: '+key);}}return loadModule.apply(this,arguments);};
  need(fs.realpathSync(path.dirname(configFile))===fs.realpathSync(directory),'Context must belong to this exclusive attempt');
  need(fs.existsSync(path.join(directory,'attempt-start.json'))&&!fs.existsSync(path.join(directory,'attempt-result.json')),'Exclusive unfinished attempt required');
  const decision=committed(admission.authorityRoot,admission.approvalPointer,a.PATHS.approval),proof=child(admission.authorityRoot,admission.approvalPointer.commit,decision.runtimeProof,a.PATHS.runtime),intent=object(fileBinding(admission.evidenceDirectory,proof.intendedHashInputs));
  const library=path.dirname(path.dirname(admission.runtime.cliEntrypoint)),expected=c.actualArchiveInventory31({repoRoot:admission.repoRoot,sourceCommit:admission.source.commit,buildRoot:proof.candidateBuildRoot,runtime:admission.runtime});
  const before=object(fileBinding(admission.evidenceDirectory,object(fileBinding(admission.evidenceDirectory,admission.preflightPointers.controls)).measurementPointer));
  const baselineFunctions=Object.fromEntries(before.functions.flatMap(p=>JSON.parse(p.bodyText).functions??[]).map(v=>[v.name.split('/').at(-1),v]));
  const names=phase==='fleet'?admission.cohorts.schedulers:admission.cohorts[phase],labels=c.endpointRuntimeHashes31({sourceArchiveHash:intent.sourceArchiveHash,inputs:intent,runtime:admission.runtime,names:admission.cohorts.fleet,source:admission.source});
  const guard=new RuntimeDeploymentTransportGuard31({names,allNames:admission.cohorts.fleet,baselineFunctions,sourceArchiveHash:intent.sourceArchiveHash,endpointRuntimeHashes:labels,phase,projectNumber:decision.projectNumber});
  const required={api:'apiv2.js',apply:'deploy/functions/cache/applyHash.js',prepare:'deploy/functions/prepare.js',backend:'deploy/functions/backend.js'};
  eq(Object.keys(admission.runtime.instrumentationProducerSha256??{}).sort(),Object.keys(required).sort(),'Exact actual CLI instrumentation producers required');
  for(const[k,rel]of Object.entries(required))need(hash(fs.readFileSync(path.join(library,rel)))===admission.runtime.instrumentationProducerSha256[k],'Pinned CLI instrumentation producer differs: '+rel);
  installNetworkBoundary31(guard);
  const api=require(path.join(library,required.api));
  let currentControlsPointer=null;
  installApiBoundary31(api.Client,guard,operation=>{const live=observeLiveGitHub31(admission,decision,new Date().toISOString());appendJson(path.join(directory,'mutation-intent-'+String(operation.sequence).padStart(4,'0')+'.json'),{phase,kind:operation.kind,name:operation.name??null,sequence:operation.sequence,atUtc:new Date().toISOString(),requestBodySha256:operation.bodySha256});appendJson(path.join(directory,'live-before-write-'+String(operation.sequence).padStart(4,'0')+'.json'),JSON.parse(JSON.stringify(live,(_k,v)=>Buffer.isBuffer(v)?v.toString('utf8'):v)));const t=a.helpers.time(new Date().toISOString());need(t<=a.helpers.time(admission.executionWindow.notAfterUtc),'Deployment window expired before mutation');need(a.helpers.gtext(admission.repoRoot,['branch','--show-current'])==='main'&&a.helpers.gtext(admission.repoRoot,['rev-parse','HEAD'])===admission.source.commit&&a.helpers.gtext(admission.repoRoot,['rev-parse','refs/remotes/origin/main'])===admission.source.commit&&a.helpers.gtext(admission.repoRoot,['status','--porcelain','--untracked-files=normal'])==='','Exact branch/local/origin/source changed before mutation');});
  const apply=require(path.join(library,required.apply)),original=apply.applyBackendHashToBackends,startedAtUtc=new Date().toISOString(),sourceBefore=source(admission.repoRoot,a.helpers.gtext(admission.repoRoot,['rev-parse','HEAD']));
  const preparation=require(path.join(library,required.prepare)),originalPrepare=preparation.prepare;
  preparation.prepare=async function(...args){need(currentControlsPointer===null,'One fresh cohort capture required');const controls=require('./backendRuntimeControls31.cjs'),sourceGuard=require(path.join(admission.repoRoot,'tools/release/scopedCallableInvokerIam.js'));
    const read=(url,method='GET',body)=>readCurrentControlResponse31(api.Client,url,method,body);
    const capture=await controls.collectCurrentRawControls31({sourceCommit:admission.source.commit,approvalSha256:admission.approvalPointer.sha256,read,unavailableRunRegion:sourceGuard.unavailableRunRegion});const file=path.join(directory,'current-cohort-controls.json');appendJson(file,capture);currentControlsPointer=privateBinding(admission,file);
    controls.verifyCurrentCohortControls31({repoRoot:admission.repoRoot,sourceCommit:admission.source.commit,evidenceDirectory:admission.evidenceDirectory,beforePointer:object(fileBinding(admission.evidenceDirectory,admission.preflightPointers.controls)).measurementPointer,currentPointer:currentControlsPointer,schedulerBaseline:admission.schedulerBaseline,approvalSha256:admission.approvalPointer.sha256,decisionAtUtc:admission.decisionAtUtc,phase,cohorts:admission.cohorts,endpointRuntimeHashes:labels,requiredProducerBindings:admission.requiredProducerBindings,installedControlRuntime:admission.installedControlRuntime});
    return originalPrepare.apply(this,args);
  };
  apply.applyBackendHashToBackends=function(wantBackends,context){original(wantBackends,context);const capture=captureActualPreparedInputs31({wantBackends,context,admission,intent,archiveExpectedFiles:expected,startedAtUtc,sourceBefore,phase});
    need(currentControlsPointer!==null,'Current cohort controls were not compared before actual preparation');
    fs.copyFileSync(capture.archivePath,path.join(directory,'actual-source.zip'),fs.constants.COPYFILE_EXCL);
    const copiedZip=fs.readFileSync(path.join(directory,'actual-source.zip'));need(copiedZip.length===capture.archiveBytes&&hash(copiedZip)===capture.archiveSha256,'Retained actual prepared ZIP changed while copying');
    delete capture.archivePath;appendJson(path.join(directory,'actual-prepared-inputs.json'),capture);guard.preparedMatches(capture);
  };
  // Never let resolved parameters silently author a new local env input.
  const write=fs.writeFileSync;fs.writeFileSync=function(file,...rest){if(typeof file==='string'&&path.basename(file).startsWith('.env'))throw Error('Parameter env-file mutation is outside this deployment scope');return write.call(this,file,...rest);};
  const asyncWrite=fs.promises.writeFile;fs.promises.writeFile=async function(file,...rest){if(typeof file==='string'&&path.basename(String(file)).startsWith('.env'))throw Error('Parameter env-file mutation is outside this deployment scope');return asyncWrite.call(this,file,...rest);};
  for(const name of ['appendFileSync','appendFile']){const originalWrite=fs[name];fs[name]=function(file,...rest){if(typeof file==='string'&&path.basename(file).startsWith('.env'))throw Error('Parameter env-file append is outside this deployment scope');return originalWrite.call(this,file,...rest);};}
  const asyncAppend=fs.promises.appendFile;fs.promises.appendFile=async function(file,...rest){if(typeof file==='string'&&path.basename(file).startsWith('.env'))throw Error('Parameter env-file append is outside this deployment scope');return asyncAppend.call(this,file,...rest);};
  process.once('exit',code=>{if(code!==0)return;try{guard.assertComplete();appendJson(path.join(directory,'instrumented-cli-complete.json'),{schemaVersion:1,source:admission.source,approvalPointer:admission.approvalPointer,phase,actualPreparationCaptured:true,currentControls:currentControlsPointer,completedAtUtc:new Date().toISOString(),capture:privateBinding(admission,path.join(directory,'actual-prepared-inputs.json')),archive:privateBinding(admission,path.join(directory,'actual-source.zip')),events:guard.events,liveObservations:guard.events.filter(e=>e.sequence).map(e=>({sequence:e.sequence,kind:e.kind,name:e.name??null,observation:privateBinding(admission,path.join(directory,'live-before-write-'+String(e.sequence).padStart(4,'0')+'.json')),mutationIntent:privateBinding(admission,path.join(directory,'mutation-intent-'+String(e.sequence).padStart(4,'0')+'.json'))}))});}catch(e){process.stderr.write('Guarded completion refused: '+e.message+'\n');process.exitCode=1;}});
  process.chdir(admission.repoRoot);
  process.argv=[admission.runtime.nodeExecutable,admission.runtime.cliEntrypoint,'deploy','--only',names.map(n=>'functions:'+n).join(','),'--project',admission.projectId,'--non-interactive'];
  require(admission.runtime.cliEntrypoint);
}
if(require.main===module){try{need(process.argv.length===4&&process.argv[2]==='--config','Exact private config argument required');runInstrumentedCli31(process.argv[3]);}catch(e){process.stderr.write(e.message+'\n');process.exitCode=1;}}
module.exports={readCurrentControlResponse31,captureActualPreparedInputs31,runInstrumentedCli31,exactPhaseDirectory,privateBinding};
