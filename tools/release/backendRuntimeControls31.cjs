'use strict';
// Private Build31 proposal. Pure comparison only; no cloud reader or writer.
// Existing 19-function comparisons are derived from the preserved Build30 pure
// measurement helpers. No Build30 approval or authority code is loaded.
const access=require('./backendRuntimeEvidenceAccess31.cjs'),{fs,path}=access;
const {isDeepStrictEqual:same}=require('node:util');
const {helpers}=require('./backendRuntimeAdmission31.cjs');
const {need,hash:sha,time:instant,git}=helpers;
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
const sorted=v=>[...v].sort();
const OUTPUT_FIELDS=Object.freeze(['name','sourceLocation','imageUri']);
const BUILD_KEYS=Object.freeze(['baseImage','enableAutomaticUpdates','environmentVariables','functionTarget','imageUri','name','serviceAccount','sourceLocation']);
const SCHEDULER_URL=`https://cloudscheduler.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}/jobs/firebase-schedule-maintenanceWorkflowEscalationSweep-${REGION}`;
// Finite raw enumeration only. The caller supplies an authenticated read-only
// transport after actual execution admission; this function grants no authority.
async function collectCurrentRawControls31({sourceCommit,approvalSha256,read,unavailableRunRegion}){
 const raw={schemaVersion:1,projectId:PROJECT,region:REGION,sourceCommit,approvalSha256,startedAtUtc:new Date().toISOString()};
 async function list(url,field,optionalRegion){const rows=[],entries=[],seen=new Set();let token='';do{need(rows.length<1000,'Readback pagination exceeds bound');const response=await read(url+'?pageSize=100'+(token?'&pageToken='+encodeURIComponent(token):''));if(response.httpStatus!==200){if(optionalRegion&&rows.length===0&&response.httpStatus===403){unavailableRunRegion(response,optionalRegion,project.projectNumber);return {unavailable:response,entries:[]};}throw Error('Complete current controls readback unavailable');}const value=JSON.parse(response.bodyText);need(!value.error&&!(value.unreachable?.length),'Current controls response incomplete');rows.push(response);need(Array.isArray(value[field]??[]),'Current controls population invalid');entries.push(...(value[field]??[]));token=value.nextPageToken??'';need(typeof token==='string'&&(!token||!seen.has(token)),'Current controls repeated pagination token');if(token)seen.add(token);}while(token);return {rows,entries};}
 async function map(rows,action){const output=new Array(rows.length);let next=0;await Promise.all(Array.from({length:Math.min(4,rows.length)},async()=>{while(next<rows.length){const i=next++;output[i]=await action(rows[i]);}}));return output;}
 raw.project=await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`);need(raw.project.httpStatus===200,'Current project unavailable');const project=JSON.parse(raw.project.bodyText);need(project.projectId===PROJECT&&/^[1-9][0-9]*$/.test(String(project.projectNumber)),'Current project identity differs');const normal=n=>n.replace(`projects/${project.projectNumber}/`,`projects/${PROJECT}/`);
 raw.functions=(await list(`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions')).rows;
 const locations=await list(`https://run.googleapis.com/v1/projects/${PROJECT}/locations`,'locations');raw.runLocations=locations.rows;
 const inventories=await map(locations.entries,async location=>{need(/^[a-z]+-[a-z]+[0-9]$/.test(location.locationId),'Unexpected Run region');return {location:location.locationId,...await list(`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location.locationId}/services`,'services',location.locationId)};});
 raw.runInventories=inventories.map(row=>row.unavailable?{location:row.location,unavailable:row.unavailable}:{location:row.location,pages:row.rows});
 raw.runIam=await map(inventories.flatMap(row=>row.entries),async service=>{const resource=normal(service.name);need(resource.startsWith(`projects/${PROJECT}/locations/`),'Current Run resource outside project');return {resource,response:await read(`https://run.googleapis.com/v2/${resource}:getIamPolicy?options.requestedPolicyVersion=3`)};});
 const accounts=await list(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`,'accounts');raw.accounts=accounts.rows;
 raw.accountIam=await map(accounts.entries,async account=>{need(typeof account.email==='string'&&/^[a-zA-Z0-9@._-]+$/.test(account.email),'Invalid account identity');return {email:account.email,response:await read(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${account.email}:getIamPolicy?options.requestedPolicyVersion=3`,'POST')};});
 raw.projectIam=await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`,'POST',{options:{requestedPolicyVersion:3}});raw.absence=[];
 const scheduler=await read(SCHEDULER_URL);need(scheduler.httpStatus===200,'Existing exact scheduler unavailable');raw.completedAtUtc=new Date().toISOString();
 return {raw,scheduler};
}
function schedulerControl31(response){need(response?.url===SCHEDULER_URL&&response.method==='GET'&&response.httpStatus===200,'Exact existing scheduler read required');const job=JSON.parse(response.bodyText);need(job.name===SCHEDULER_URL.replace('https://cloudscheduler.googleapis.com/v1/','')&&job.state==='ENABLED'&&job.httpTarget&&typeof job.schedule==='string'&&typeof job.timeZone==='string','Existing enabled scheduler identity required');const volatile=new Set(['lastAttemptTime','scheduleTime','status']);return Object.fromEntries(Object.entries(job).filter(([key])=>!volatile.has(key)));}
function unique(rows,key,label){need(Array.isArray(rows),label+' must be an array');const m=new Map();for(const row of rows){const id=key(row);need(typeof id==='string'&&id&&!m.has(id),label+' duplicate/missing identity');m.set(id,row);}return m;}
function summarizeRaw({raw,policy,sourceCommit,approvalSha256,guard}){
  need(raw?.schemaVersion===1&&raw.projectId===PROJECT&&raw.region===REGION&&raw.sourceCommit===sourceCommit,'Raw context differs');
  need(instant(raw.startedAtUtc)<=instant(raw.completedAtUtc),'Capture chronology reversed');
  const project=guard.body(raw.project,`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`);
  need(project.projectId===PROJECT&&/^\d+$/.test(String(project.projectNumber)),'Project identity differs');
  const normalize=n=>{need(typeof n==='string','Resource identity absent');return n.replace(`projects/${project.projectNumber}/`,`projects/${PROJECT}/`);};
  const names=sorted(Object.keys(policy.functionBindings));need(names.length===19&&new Set(names.map(n=>policy.functionBindings[n].runtimeServiceAccountId)).size===15,'Exact19/15 source policy required');
  const functions=unique(guard.pages(raw.functions,`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions'),x=>normalize(x?.name),'Functions');
  need(same(sorted(functions.keys()),names.map(n=>`projects/${PROJECT}/locations/${REGION}/functions/${n}`).sort()),'Missing/extra existing Functions');
  const locations=unique(guard.pages(raw.runLocations,`https://run.googleapis.com/v1/projects/${PROJECT}/locations`,'locations'),x=>x.locationId,'Run locations');
  need(locations.has(REGION),'Target Run region missing');
  const inventories=unique(raw.runInventories,x=>x.location,'Run inventories');need(same(sorted(locations.keys()),sorted(inventories.keys())),'Incomplete Run region coverage');
  const runRows=[],excluded=[];
  for(const [location,row]of inventories){if(row.unavailable){excluded.push(guard.unavailableRunRegion(row.unavailable,location,project.projectNumber));continue;}for(const service of guard.pages(row.pages,`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location}/services`,'services')){need(normalize(service.name).startsWith(`projects/${PROJECT}/locations/${location}/services/`),'Run service belongs to different listing region');runRows.push(service);}}
  const runs=unique(runRows,x=>normalize(x.name),'Run services'),runIam=unique(raw.runIam,x=>x.resource,'Run IAM');need(same(sorted(runs.keys()),sorted(runIam.keys())),'Missing/extra Run IAM');
  const servicePolicies={};for(const [name,row]of runs){need(typeof row.uid==='string'&&row.uid&&!row.deleteTime,'Run identity absent/deleted');servicePolicies[name]={uid:row.uid,policy:guard.policyValue(guard.body(runIam.get(name).response,`https://run.googleapis.com/v2/${name}:getIamPolicy?options.requestedPolicyVersion=3`))};}
  const accounts=unique(guard.pages(raw.accounts,`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`,'accounts'),x=>x.email,'Accounts'),accountIam=unique(raw.accountIam,x=>x.email,'Account IAM');need(same(sorted(accounts.keys()),sorted(accountIam.keys())),'Incomplete account IAM');
  const accountPolicies={};for(const [email,row]of accounts){need(row.projectId===PROJECT&&typeof row.uniqueId==='string'&&row.uniqueId,'Account identity differs');accountPolicies[email]={uniqueId:row.uniqueId,disabled:row.disabled??false,policy:guard.policyValue(guard.body(accountIam.get(email).response,`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${email}:getIamPolicy?options.requestedPolicyVersion=3`,'POST'))};}
  const mapping={};for(const [resource,f]of functions){const n=resource.split('/').at(-1),service=normalize(f.serviceConfig?.service),sa=f.serviceConfig.serviceAccountEmail;need(service===`projects/${PROJECT}/locations/${REGION}/services/${n.toLowerCase()}`&&runs.has(service)&&sa===`${policy.functionBindings[n].runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`&&accountPolicies[sa]?.disabled===false,'Runtime/service identity differs');mapping[n]=service;}
  need(Array.isArray(raw.absence)&&raw.absence.length===0,'No absent/new services admitted');
  return {projectNumber:String(project.projectNumber),mapping,servicePolicies,accountPolicies,projectPolicy:guard.policyValue(guard.body(raw.projectIam,`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`,'POST')),excluded:excluded.sort((a,b)=>a.location.localeCompare(b.location)),functions:Object.fromEntries(functions),runs:Object.fromEntries(runs)};
}
function omit(o,keys){return Object.fromEntries(Object.entries(o??{}).filter(([k])=>!keys.includes(k)));}
function controlView(f,run,name,expectedRuntime,expectedIdentity){
  need(f.state==='ACTIVE'&&f.environment==='GEN_2'&&f.buildConfig?.runtime===expectedRuntime&&f.buildConfig.entryPoint===name,'Function runtime/state differs');
  const s=f.serviceConfig;need(s.serviceAccountEmail===expectedIdentity&&s.environmentVariables?.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK==='false','Runtime identity/AppCheck parameter differs');
  need(run?.template?.serviceAccount===expectedIdentity&&run.observedGeneration===run.generation&&typeof run.generation==='string'&&/^[1-9][0-9]*$/.test(run.generation)&&!run.reconciling&&run.terminalCondition?.type==='Ready'&&run.terminalCondition.state==='CONDITION_SUCCEEDED','Run runtime/readiness differs');
  const service=s.service,revision=s.revision;need(typeof revision==='string'&&revision.startsWith(name.toLowerCase()+'-')&&run.latestCreatedRevision===`${service}/revisions/${revision}`&&run.latestReadyRevision===run.latestCreatedRevision&&run.template.revision===revision,'Run/Function serving revision differs');
  const traffic=[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:100}];
  // Cloud Run may resolve LATEST in observed status to the already-bound serving
  // revision. Keep requested traffic exact and retain the original raw response.
  const resolvedTraffic=[{...traffic[0],revision}];
  need(s.allTrafficOnLatestRevision===true&&same(run.traffic,traffic)&&
    (same(run.trafficStatuses,traffic)||same(run.trafficStatuses,resolvedTraffic)),
    'Latest-only traffic required');
  need(Array.isArray(run.template.containers)&&run.template.containers.length===1,'Single measured container required');
  const container=run.template.containers[0],env={};for(const e of container.env??[]){need(same(sorted(Object.keys(e)),['name','value'])&&typeof e.name==='string'&&typeof e.value==='string'&&!Object.hasOwn(env,e.name),'Container env malformed/secret-bound');Object.defineProperty(env,e.name,{value:e.value,enumerable:true});}need(same(env,s.environmentVariables),'Run/Function environment differs');
  const caps=[run.scaling?.maxInstanceCount,run.template.scaling?.maxInstanceCount].filter(v=>v!==undefined);need(caps.length>0&&caps.every(v=>Number.isSafeInteger(v)&&v>0&&v<=100),'Measured serving cap absent/invalid');
  const gcf=Object.hasOwn(s,'maxInstanceCount')?s.maxInstanceCount:null;need(gcf===null||(Number.isSafeInteger(gcf)&&gcf>0&&gcf<=100&&caps.includes(gcf)),'Function/Run maximum differs');
  const effectiveMaxInstanceCount=Math.min(...caps);
  const volatileLabels=['firebase-functions-hash'];
  const labels=o=>omit(o,volatileLabels);
  const annotations=o=>omit(o,['cloudfunctions.googleapis.com/build-name','cloudfunctions.googleapis.com/build-id','run.googleapis.com/operation-id']);
  const templateScaling=run.template?.scaling?{...run.template.scaling}:undefined;
  const template={...omit(run.template,['revision','scaling']),...(templateScaling?{scaling:templateScaling}:{}),labels:labels(run.template.labels),annotations:annotations(run.template.annotations),containers:[omit(container,['image'])]};
  let eventTrigger=null;
  if(f.eventTrigger){
    eventTrigger={...f.eventTrigger};
    if(Array.isArray(f.eventTrigger.eventFilters)){
      const attrs=f.eventTrigger.eventFilters.map(x=>{
        need(object(x)&&typeof x.attribute==='string'&&x.attribute.length>0,'Event filter attribute must be a non-empty string');
        return x.attribute;
      });
      need(new Set(attrs).size===attrs.length,'Duplicate event filter attribute');
      eventTrigger.eventFilters=[...f.eventTrigger.eventFilters].map(x=>({...x})).sort((a,b)=>a.attribute.localeCompare(b.attribute));
    }
  }
  return {otherFunctionControls:omit(f,['name','state','environment','serviceConfig','eventTrigger','labels','buildConfig','createTime','updateTime','url']),functionService:omit(s,['revision']),eventTrigger,functionLabels:labels(f.labels),buildControls:omit(f.buildConfig,['build','source','sourceProvenance','sourceToken']),runControls:{...omit(run,['generation','observedGeneration','reconciling','createTime','updateTime','terminalCondition','conditions','latestCreatedRevision','latestReadyRevision','template','labels','annotations','trafficStatuses','etag']),labels:labels(run.labels),annotations:annotations(run.annotations),template},cap:{cloudFunctionsMaxInstanceCount:gcf,runServiceMaxInstanceCount:run.scaling?.maxInstanceCount??null,runRevisionMaxInstanceCount:run.template.scaling?.maxInstanceCount??null,effectiveMaxInstanceCount}};
}
function compareMeasurements({before,after,policy,runtime,declaredMaxInstances=null}){
  for(const key of ['projectNumber','mapping','servicePolicies','accountPolicies','projectPolicy','excluded'])need(same(before[key],after[key]),'Preserved IAM/identity/inventory drift: '+key);
  const rows=[],capRepresentationChanges=[];for(const name of sorted(Object.keys(policy.functionBindings))){const binding=policy.functionBindings[name],resource=`projects/${PROJECT}/locations/${REGION}/functions/${name}`,service=before.mapping[name],identity=`${binding.runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`;
    const a=controlView(before.functions[resource],before.runs[service],name,runtime,identity),b=controlView(after.functions[resource],after.runs[service],name,runtime,identity);
    need(a.cap.effectiveMaxInstanceCount===20&&b.cap.effectiveMaxInstanceCount===20,'Existing explicit20 cap required: '+name);
    const actualAfterCap={...b.cap};
    need(same(a,b),'Existing runtime/environment/scaling drift: '+name);rows.push({name,...actualAfterCap});}
  return {functionCount:19,existingFunctionCount:19,newFunctionCount:0,measuredProjectRunAndServiceAccountIamPreserved:true,allExistingFunctionEffectiveControlsPreserved:true,capRepresentationChanges,scalingObservations:rows,unavailableRunRegions:before.excluded};
}
function normalizeMeasurement(measurement,policy,runtime){
  const result=structuredClone(measurement),observations=[];
  for(const name of sorted(Object.keys(policy.functionBindings))){
    const resource=`projects/${PROJECT}/locations/${REGION}/functions/${name}`;
    const f=measurement.functions[resource],service=measurement.mapping[name],run=measurement.runs[service];
    const identity=`${policy.functionBindings[name].runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`;
    // The original strict runtime/traffic/environment/cap checks run on unmodified input.
    controlView(f,run,name,runtime,identity);
    const b=run.buildConfig,s=f.buildConfig.source?.storageSource;
    need(b&&same(sorted(Object.keys(b)),BUILD_KEYS),'Unexpected Run build configuration fields');
    need(typeof f.buildConfig.build==='string'&&/^projects\/[^/]+\/locations\/asia-south1\/builds\/[^/]+$/.test(f.buildConfig.build)&&b.name===f.buildConfig.build,'Run build output is not bound to GCF build');
    need(s&&same(sorted(Object.keys(s)),['bucket','generation','object'])&&typeof s.bucket==='string'&&typeof s.object==='string'&&/^[1-9][0-9]*$/.test(s.generation)&&b.sourceLocation===`gs://${s.bucket}/${s.object}#${s.generation}`,'Run source output is not bound to exact GCF generation');
    const repository=f.buildConfig.dockerRepository;
    need(typeof repository==='string'&&repository===`projects/${PROJECT}/locations/${REGION}/repositories/gcf-artifacts`,'Unexpected Function artifact repository');
    const prefix=`${REGION}-docker.pkg.dev/${PROJECT}/gcf-artifacts/`;
    need(typeof b.imageUri==='string'&&b.imageUri.startsWith(prefix)&&b.imageUri.length>prefix.length&&!/\s|\.\./.test(b.imageUri)&&b.imageUri===run.template.containers[0].image,'Run image output is not bound to serving container/repository');
    need(b.functionTarget===f.buildConfig.entryPoint&&b.functionTarget===name,'Run build target differs from Function entry point');
    const copy={...b};for(const key of OUTPUT_FIELDS)delete copy[key];
    result.runs[service].buildConfig=copy;
    observations.push({name,buildNameBoundToGcf:true,sourceBoundToExactGeneration:true,imageBoundToServingContainerAndRepository:true,functionTargetBound:true});
  }
  return {measurement:result,observations};
}

function compareWithSupplement({before,after,policy,runtime,declaredMaxInstances}){
  const a=normalizeMeasurement(before,policy,runtime),b=normalizeMeasurement(after,policy,runtime);
  // Reuse every original IAM, inventory, runtime, scaling and other-field comparison.
  const summary=compareMeasurements({before:a.measurement,after:b.measurement,policy,runtime,declaredMaxInstances});
  const changed=sorted(Object.keys(policy.functionBindings)).map(name=>{
    const service=before.mapping[name];
    return {name,fields:OUTPUT_FIELDS.filter(k=>!same(before.runs[service].buildConfig[k],after.runs[service].buildConfig[k]))};
  }).filter(x=>x.fields.length);
  // A no-change observation is valid controls evidence, not proof that deployment occurred.
  return {...summary,normalizedDeploymentOutputs:{fields:[...OUTPUT_FIELDS],validatedFunctionPairs:a.observations.length+b.observations.length,changedFunctions:changed}};
}


function filePointer(evidence,pointer){
 need(pointer&&same(sorted(Object.keys(pointer)),['file','sha256']),'Exact raw pointer required');
 const raw=helpers.fileBinding(evidence,pointer);return {raw,value:helpers.object(raw)};
}
function loadSourceModule(repoRoot,sourceCommit,bindings,file){
 const declared=bindings?.[file];need(typeof declared==='string'&&/^[A-F0-9]{64}$/.test(declared),'Source producer binding missing: '+file);
 const actual=fs.realpathSync(path.join(repoRoot,file));need(sha(git(repoRoot,['show',sourceCommit+':'+file]))===declared&&sha(fs.readFileSync(actual))===declared,'Executing producer differs: '+file);
 return require(actual);
}

function installedMember(prefix,file){
 if(typeof file!=='string'||!path.isAbsolute(file))return false;
 const relative=path.relative(prefix,file);
 return Boolean(relative&&!relative.startsWith('..')&&!path.isAbsolute(relative));
}
function verifyAdmittedReplayProducer(file){
 const bindings=access.current()?.verifierFiles;
 if(bindings&&Object.hasOwn(bindings,file))need(sha(fs.readFileSync(file))===bindings[file],'Source-bound replay producer changed');
}
function verifyInstalledControlsRuntime(repoRoot,bindings){
 repoRoot=fs.realpathSync(repoRoot);
 need(bindings&&object(bindings),'Installed controls runtime bindings required');
 const mandatory=['functions/node_modules/typescript/package.json','functions/node_modules/typescript/lib/typescript.js','functions/node_modules/firebase-functions/package.json','functions/node_modules/firebase-functions/lib/runtime/manifest.js'];
 for(const file of mandatory)need(Object.hasOwn(bindings,file),'Mandatory installed controls file missing: '+file);
 const prefix=fs.realpathSync(path.join(repoRoot,'functions/node_modules'));
 for(const[file,digest]of Object.entries(bindings)){
  need(file.startsWith('functions/node_modules/')&&!file.includes('..')&&!file.includes('\\')&&!file.includes(':')&&typeof digest==='string'&&/^[A-F0-9]{64}$/.test(digest),'Invalid installed controls binding');
  const resolved=fs.realpathSync(path.join(repoRoot,file)),relative=path.relative(prefix,resolved);
  need(relative&&!relative.startsWith('..')&&!path.isAbsolute(relative),'Installed controls file escapes runtime');
  need(sha(fs.readFileSync(resolved))===digest,'Installed controls byte drift: '+file);
 }
 const ts=fs.realpathSync(require.resolve(path.join(repoRoot,'functions/node_modules/typescript')));
 need(ts===fs.realpathSync(path.join(repoRoot,'functions/node_modules/typescript/lib/typescript.js')),'TypeScript entrypoint substitution');
 for(const file of Object.keys(require.cache)){
  // Unrelated caller modules are not original evidence. Classify first; every
  // admitted producer and measured dependency still receives its own byte check.
  verifyAdmittedReplayProducer(file);
  if(!installedMember(prefix,file))continue;
  const real=fs.realpathSync(file);need(installedMember(prefix,real),'Installed controls dependency escaped the measured runtime');
  const key='functions/node_modules/'+path.relative(prefix,real).split(path.sep).join('/');
  need(Object.hasOwn(bindings,key)&&sha(fs.readFileSync(real))===bindings[key],'Unbound loaded controls dependency: '+key);
 }
}
function withInstalledControlsRuntime31(repoRoot,bindings,action){
 repoRoot=fs.realpathSync(repoRoot);
 const Module=require('node:module'),originalLoad=Module._load,prefix=fs.realpathSync(path.join(repoRoot,'functions/node_modules'));
 Module._load=function(request,parent,isMain){
  const resolved=Module._resolveFilename(request,parent,isMain);
  if(typeof resolved==='string'&&path.isAbsolute(resolved)){
   verifyAdmittedReplayProducer(resolved);
   const fromInstalled=parent?.filename&&(parent.filename===prefix||installedMember(prefix,parent.filename));
   if(installedMember(prefix,resolved)||installedMember(prefix,request)||fromInstalled){
    need(installedMember(prefix,resolved),'Installed controls dependency escaped the measured runtime');
    const real=fs.realpathSync(resolved);need(installedMember(prefix,real),'Installed controls dependency escaped the measured runtime');
    const key='functions/node_modules/'+path.relative(prefix,real).split(path.sep).join('/');
    need(Object.hasOwn(bindings,key)&&sha(fs.readFileSync(real))===bindings[key],'Unbound installed dependency refused before evaluation: '+key);
   }
  }
  return originalLoad.apply(this,arguments);
 };
 try{return action();}finally{Module._load=originalLoad;}
}
function context({repoRoot,sourceCommit,requiredProducerBindings,installedControlRuntime}){
 // Native legacy producers receive the verified physical root. Original
 // receipt identities remain untouched in the caller and evidence envelopes.
 repoRoot=fs.realpathSync(repoRoot);
 const policy=helpers.object(git(repoRoot,['show',sourceCommit+':release/function-fleet-runtime-identity-policy.json']));
 const guard=loadSourceModule(repoRoot,sourceCommit,requiredProducerBindings,'tools/release/scopedCallableInvokerIam.js');
 loadSourceModule(repoRoot,sourceCommit,requiredProducerBindings,'tools/release/collectProductionGlobalPullBackend.js');
 const controls=loadSourceModule(repoRoot,sourceCommit,requiredProducerBindings,'tools/release/reviewedBackendControls.js');
 verifyInstalledControlsRuntime(repoRoot,installedControlRuntime);
 const options=withInstalledControlsRuntime31(repoRoot,installedControlRuntime,()=>controls.sourceOptions(repoRoot,sourceCommit));
 verifyInstalledControlsRuntime(repoRoot,installedControlRuntime);
 need(options.runtime==='nodejs22'&&options.declaredMaxInstances===20,'Exact source runtime and explicit cap required');
 return {policy,guard,options};
}
function verifyPreservedControlsBefore31(input){
 const {repoRoot,sourceCommit,evidenceDirectory,beforePointer}=input;
 const before=filePointer(evidenceDirectory,beforePointer),{policy,guard,options}=context(input);
 const value=summarizeRaw({raw:before.value,policy,sourceCommit,guard});
 const result=compareWithSupplement({before:value,after:value,policy,runtime:options.runtime,declaredMaxInstances:options.declaredMaxInstances});
 return {ok:true,sourceCommit,beforeSha256:sha(before.raw),observedAtUtc:before.value.startedAtUtc,capturedAtUtc:before.value.completedAtUtc,summary:result};
}
function verifyCurrentCohortControls31(input){
 const {repoRoot,sourceCommit,evidenceDirectory,beforePointer,currentPointer,schedulerBaseline,approvalSha256,decisionAtUtc,phase,cohorts,endpointRuntimeHashes}=input;
 need(['callables','events','fleet'].includes(phase),'Exact cohort required');const before=filePointer(evidenceDirectory,beforePointer),current=filePointer(evidenceDirectory,currentPointer),baselineScheduler=filePointer(evidenceDirectory,schedulerBaseline),{policy,guard,options}=context(input);
 const capture=current.value;need(capture.raw?.approvalSha256===approvalSha256&&instant(capture.raw.startedAtUtc)>=instant(decisionAtUtc),'Fresh post-decision cohort capture required');
 const old=summarizeRaw({raw:before.value,policy,sourceCommit,guard}),now=summarizeRaw({raw:capture.raw,policy,sourceCommit,guard});
 const summary=compareWithSupplement({before:old,after:now,policy,runtime:options.runtime,declaredMaxInstances:options.declaredMaxInstances});
 need(same(schedulerControl31(baselineScheduler.value.response),schedulerControl31(capture.scheduler)),'Scheduler control or identity drift before cohort');
 const prior=phase==='callables'?[]:phase==='events'?cohorts.callables:[...cohorts.callables,...cohorts.events];
 for(const name of cohorts.fleet){const key=`projects/${PROJECT}/locations/${REGION}/functions/${name}`,left=old.functions[key],right=now.functions[key];if(prior.includes(name)){need(right.labels?.['firebase-functions-hash']===endpointRuntimeHashes[name],'Prior cohort no longer has the approved endpoint identity');continue;}need(same(left.buildConfig,right.buildConfig)&&same(left.labels,right.labels),'Unadmitted Function source/control changed before cohort: '+name);}
 return {ok:true,sourceCommit,currentSha256:sha(current.raw),startedAtUtc:capture.raw.startedAtUtc,completedAtUtc:capture.raw.completedAtUtc,summary};
}
function verifyPreservedControls31(input){
 const {repoRoot,sourceCommit,evidenceDirectory,beforePointer,afterPointer,approvalSha256,decisionAtUtc,completedAtUtc}=input;
 const before=filePointer(evidenceDirectory,beforePointer),after=filePointer(evidenceDirectory,afterPointer),{policy,guard,options}=context(input);
 need(after.value.approvalSha256===approvalSha256,'After-state approval binding differs');
 need(instant(before.value.completedAtUtc)<=instant(decisionAtUtc)&&instant(decisionAtUtc)<=instant(completedAtUtc)&&instant(completedAtUtc)<=instant(after.value.startedAtUtc),'Controls chronology differs');
 const measure=raw=>summarizeRaw({raw,policy,sourceCommit,guard});
 const result=compareWithSupplement({before:measure(before.value),after:measure(after.value),policy,runtime:options.runtime,declaredMaxInstances:options.declaredMaxInstances});
 return {ok:true,sourceCommit,beforeSha256:sha(before.raw),afterSha256:sha(after.raw),observedAtUtc:after.value.completedAtUtc,summary:result};
}
module.exports={withInstalledControlsRuntime31,collectCurrentRawControls31,verifyCurrentCohortControls31,schedulerControl31,SCHEDULER_URL,verifyPreservedControls31,verifyPreservedControlsBefore31,verifyInstalledControlsRuntime,PROJECT,REGION,summarizeRaw,controlView,compareMeasurements,normalizeMeasurement,compareWithSupplement};
