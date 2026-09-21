import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
// Synthetic local checks only. Does not execute the live collector or assembler.
const test=require('node:test'),assert=require('node:assert/strict'),cp=require('node:child_process');
const helper=require('./reviewedBackendControls.js');
// These15-plus4 controls belong to the preserved historical deployment. New
// source now has19 existing endpoints and must not reinterpret this fixture.
const root=process.cwd(),source='fc0ac09fc51b370bee419909ad510b044765b540';
const options=helper.sourceOptions(root,source),newNames=Object.keys(options.policy.runtimeIdentityAliases);
const ts=require('../../functions/node_modules/typescript');
function capTexts(){return {'synthetic-fleet.ts':Object.entries(options.policy.functionBindings).map(([name,b])=>
 `export const ${name} = ${b.workloadClass.includes('CALLABLE')?'onCall':b.workloadClass==='SCHEDULED_FIRESTORE_MUTATION'?'onSchedule':'onDocumentCreated'}({maxInstances: 20}, async () => {});`).join('\n')};}
test('source cap parser admits all19 direct literal20 definitions',()=>{const p=helper.explicitFleetMaxInstances(ts,capTexts(),options.policy);assert.equal(p.declaredMaxInstances,20);assert.equal(p.functionNames.length,19);assert.equal(p.capPolicy,'explicit-literal20-v1');});
for(const [name,change]of [
 ['one omitted cap',t=>t.replace('maxInstances: 20','')],
 ['one larger cap',t=>t.replace('maxInstances: 20','maxInstances: 100')],
 ['dynamic cap',t=>t.replace('maxInstances: 20','maxInstances: Number(20)')],
 ['equivalent nonliteral spelling',t=>t.replace('maxInstances: 20','maxInstances: 2e1')],
 ['computed property',t=>t.replace('maxInstances: 20','["maxInstances"]: 20')],
 ['spread cap',t=>t.replace('maxInstances: 20','...{maxInstances: 20}')],
 ['spread after direct cap',t=>t.replace('maxInstances: 20','maxInstances: 20, ...JSON.parse(\'{"maxInstances":100}\')')],
 ['computed override after direct cap',t=>t.replace('maxInstances: 20','maxInstances: 20, [\'max\' + \'Instances\']: 100')],
 ['getter override after direct cap',t=>t.replace('maxInstances: 20','maxInstances: 20, get [\'max\' + \'Instances\']() { return 100; }')],
 ['duplicate cap',t=>t.replace('maxInstances: 20','maxInstances: 20, maxInstances: 20')],
 ['extra cap outside endpoints',t=>t+'\nconst extra = {maxInstances: 20};'],
 ['missing endpoint',t=>t.slice(t.indexOf('\n')+1)],
 ])test(`source cap parser refuses ${name}`,()=>{const texts=capTexts();texts['synthetic-fleet.ts']=change(texts['synthetic-fleet.ts']);assert.throws(()=>helper.explicitFleetMaxInstances(ts,texts,options.policy));});
test('historical comparator refuses the successor explicit20 mode',()=>{const d=fixture();d.options=structuredClone(options);d.options.sdkReset.sourceMaxInstancesOmitted=false;d.options.declaredMaxInstances=20;assert.throws(()=>helper.compareFunctionViews(d),/Historical15-plus4/);});
function fixture(){const after=Object.entries(options.policy.functionBindings).map(([name,binding])=>({
 name:`projects/crm3-baf-ops-b8638/locations/asia-south1/functions/${name}`,state:'ACTIVE',environment:'GEN_2',
 buildConfig:{runtime:options.runtime,entryPoint:name},labels:{'firebase-functions-hash':'a'.repeat(40)},
 serviceConfig:{environmentVariables:{CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:'false',GCLOUD_PROJECT:'crm3-baf-ops-b8638',
 FUNCTION_TARGET:name,EVENTARC_CLOUD_EVENT_SOURCE:`projects/crm3-baf-ops-b8638/locations/asia-south1/services/${name}`,
 LOG_EXECUTION_ID:'true',FUNCTION_SIGNATURE_TYPE:'http',FIREBASE_CONFIG:'{"projectId":"crm3-baf-ops-b8638"}'},
 serviceAccountEmail:`${binding.runtimeServiceAccountId}@crm3-baf-ops-b8638.iam.gserviceaccount.com`,ingressSettings:'ALLOW_ALL',
 availableMemory:options.mutating[name]?.availableMemory??'256Mi',timeoutSeconds:60,maxInstanceRequestConcurrency:20,availableCpu:'1',maxInstanceCount:newNames.includes(name)?100:20,allTrafficOnLatestRevision:true},
 ...(binding.workloadClass.startsWith('FIRESTORE_')?{eventTrigger:{serviceAccountEmail:`${binding.runtimeServiceAccountId}@crm3-baf-ops-b8638.iam.gserviceaccount.com`}}:{}),
}));return {options,after,before:structuredClone(after.filter(x=>!newNames.includes(x.buildConfig.entryPoint)))};}
const find=(data,name)=>data.after.find(x=>x.buildConfig.entryPoint===name);
test('historical Git source options distinguish 15 existing and four new controls',()=>{
 const result=helper.compareFunctionViews(fixture());assert.equal(result.existingFunctionCount,15);assert.equal(result.newFunctionCount,4);
 assert.equal(result.allMutatingCallableAppCheckEnforcementFalse,true);assert.equal(result.existingBackendIdentityAppCheckEnforcementTruePreserved,true);
 assert.equal(Object.hasOwn(result,'allAppCheckEnforcementFalse'),false);
 assert.equal(result.newFunctionSourceOptions.every(row=>row.maxInstanceCount===100),true);
});
for(const mode of ['environment','generated identity','secret metadata'])test(`private ${mode} rejection does not log actual or expected values`,()=>{
 const d=fixture(),f=find(d,'mutateAssetHierarchyV2');
 const canary='PRIVATE_COMPARISON_CANARY@example.invalid';
 if(mode==='environment')f.serviceConfig.environmentVariables.PRIVATE=canary;
 if(mode==='generated identity')f.serviceConfig.environmentVariables.FUNCTION_TARGET=canary;
 if(mode==='secret metadata')f.serviceConfig.secretEnvironmentVariables=[{key:canary}];
 assert.throws(()=>helper.compareFunctionViews(d),error=>{
  assert.equal(error.message.includes(canary),false);
  assert.equal(error.message.includes('actual:'),false);
  assert.equal(error.message.includes('expected:'),false);
  return true;
 });
});
test('malformed private JSON fails without echoing nearby data',()=>{
 const canary='PRIVATE_MALFORMED_JSON_CANARY';
 assert.throws(()=>helper.parsePrivateEvidenceJson(Buffer.from(`{"private":"${canary}" trailing`)),error=>{
  assert.equal(error.message.includes(canary),false);return true;
 });
});
test('existing20 may reset to source-default100 only with explicit authorization',()=>{
 const d=fixture();find(d,'mutateAssetHierarchy').serviceConfig.maxInstanceCount=100;
 assert.throws(()=>helper.compareFunctionViews(d));
 const result=helper.compareFunctionViews({...d,allowExistingMaxInstanceReset:true});
 assert.deepEqual(result.scalingObservations.find(row=>row.name==='mutateAssetHierarchy'),{
  name:'mutateAssetHierarchy',beforeMaxInstanceCount:20,afterMaxInstanceCount:100,disposition:'approved-source-default-reset',
 });
 find(d,'mutateAssetHierarchy').serviceConfig.maxInstanceCount=77;
 assert.throws(()=>helper.compareFunctionViews({...d,allowExistingMaxInstanceReset:true}));
});
test('private environment values used for equality never enter the public summary',()=>{
 const d=fixture();
 for(const row of [...d.before,...d.after])row.serviceConfig.environmentVariables.PRIVATE_OPERATOR='private-reviewer@example.invalid';
 const output=JSON.stringify(helper.compareFunctionViews(d));
 assert.equal(output.includes('PRIVATE_OPERATOR'),false);
 assert.equal(output.includes('private-reviewer@example.invalid'),false);
 assert.equal(output.includes('environmentVariables'),false);
});
for(const [name,mutate]of [
 ['existing environment',(d)=>{find(d,'mutateAssetHierarchy').serviceConfig.environmentVariables.EXTRA='unexpected';}],
 ['existing trigger actor',(d)=>{find(d,'onTicketCreated').eventTrigger.serviceAccountEmail='other@example.test';}],
 ['existing runtime actor',(d)=>{find(d,'mutateAssetHierarchy').serviceConfig.serviceAccountEmail='other@example.test';}],
 ['existing ingress',(d)=>{find(d,'mutateAssetHierarchy').serviceConfig.ingressSettings='ALLOW_INTERNAL_ONLY';}],
 ['new memory',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.availableMemory='512Mi';}],
 ['new creation max-instance override',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.maxInstanceCount=20;}],
 ['new App Check parameter',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK='true';}],
 ['new old-V1 function target',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.FUNCTION_TARGET='mutateAssetHierarchy';}],
 ['new wrong-case event source',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.EVENTARC_CLOUD_EVENT_SOURCE='projects/crm3-baf-ops-b8638/locations/asia-south1/services/mutateassethierarchyv2';}],
 ['new missing generated identity',(d)=>{delete find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.FUNCTION_TARGET;}],
 ['new unknown extra environment',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.EXTRA='unapproved';}],
 ['new common environment drift',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.FIREBASE_CONFIG='{"projectId":"wrong-project"}';}],
 ['new trigger',(d)=>{find(d,'mutateAssetHierarchyV2').eventTrigger={serviceAccountEmail:'other@example.test'};}],
 ['new VPC',(d)=>{find(d,'mutateAssetHierarchyV2').serviceConfig.vpcConnector='unapproved';}],
 ['wrong source runtime',(d)=>{find(d,'mutateAssetHierarchyV2').buildConfig.runtime='nodejs20';}],
 ['new endpoint missing',(d)=>{d.after=d.after.filter(x=>x.buildConfig.entryPoint!=='mutateAssetHierarchyV2');}],
])test(`refuses ${name} drift`,()=>{const d=fixture();mutate(d);assert.throws(()=>helper.compareFunctionViews(d));});

// Actual API-shaped synthetic records, not production observations: the GCF
// maximum is omitted while the bound, ready Run service explicitly reports20.
// Every negative begins with a passing complete control so a malformed baseline
// cannot make a refusal test vacuous.
const project='crm3-baf-ops-b8638',region='asia-south1';
const changedHttpNames=['beginGlobalPullRun','completePlannedJobExecution'];
const privateCanary='PRIVATE_OBSERVED_CONTROL_CANARY@example.invalid';
function runService(f){
 const name=f.buildConfig.entryPoint,service=`projects/${project}/locations/${region}/services/${name.toLowerCase()}`;
 const revision=`${name.toLowerCase()}-00002-abc`;
 f.serviceConfig.service=service;f.serviceConfig.revision=revision;
 return {name:service,uid:'12345678-1234-1234-1234-123456789abc',generation:'2',observedGeneration:'2',
  reconciling:false,terminalCondition:{type:'Ready',state:'CONDITION_SUCCEEDED'},
  latestCreatedRevision:`${service}/revisions/${revision}`,latestReadyRevision:`${service}/revisions/${revision}`,
  ingress:'INGRESS_TRAFFIC_ALL',scaling:{maxInstanceCount:20},
  traffic:[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:100}],
  trafficStatuses:[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:100}],
  template:{revision,serviceAccount:f.serviceConfig.serviceAccountEmail,
   annotations:{'cloudfunctions.googleapis.com/trigger-type':'HTTP_TRIGGER'},
   containers:[{name:'worker',image:'asia-south1-docker.pkg.dev/synthetic-release/functions/source@sha256:'+'a'.repeat(64),
    env:Object.entries(f.serviceConfig.environmentVariables).map(([name,value])=>({name,value}))}]}};
}
function observedFixture(){
 const d=fixture();d.options=structuredClone(options);d.controlMode=helper.OBSERVED_CONTROL_MODE;
 for(const name of changedHttpNames)delete d.before.find(row=>row.buildConfig.entryPoint===name).serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;
 d.runServices=[...changedHttpNames,...newNames].map(name=>runService(find(d,name)));
 for(const name of newNames)delete find(d,name).serviceConfig.maxInstanceCount;
 return d;
}
const runFor=(d,name='mutateAssetHierarchyV2')=>d.runServices.find(row=>row.name.endsWith(`/services/${name.toLowerCase()}`));
function mirrorEnv(d,name){runFor(d,name).template.containers[0].env=Object.entries(find(d,name).serviceConfig.environmentVariables).map(([name,value])=>({name,value}));}
function assertObservedPass(d){
 const result=helper.compareFunctionViews(d);
 assert.equal(result.controlMode,helper.OBSERVED_CONTROL_MODE);
 assert.equal(result.existingProjectEnvironmentVariablesUnchanged,true);
 assert.equal(Object.hasOwn(result,'existingFunctionEnvironmentVariablesUnchanged'),false,
  'Platform signature additions must not be described as complete environment equality.');
 assert.equal(result.reservedHttpSignatureMetadataValidated,true);
 assert.equal(result.newFunctionEffectiveInstanceCapsValidated,true);
 assert.equal(result.existingFunctionCount,15);assert.equal(result.newFunctionCount,4);
 assert.equal(result.newFunctionEffectiveInstanceCaps.length,4);
 for(const row of result.newFunctionEffectiveInstanceCaps){
  assert.equal(row.cloudFunctionsMaxInstanceCount,null);
  assert.equal(row.runServiceMaxInstanceCount,20);assert.equal(row.effectiveMaxInstanceCount,20);
  assert.equal(row.runRevisionMaxInstanceCount,null);assert.equal(row.maximumApprovedBound,100);
  assert.equal(row.serviceResource,find(d,row.name).serviceConfig.service);
  assert.equal(row.revision,find(d,row.name).serviceConfig.revision);
 }
 for(const row of result.newFunctionSourceOptions){
  assert.equal(Object.hasOwn(row,'maxInstanceCount'),false);
  assert.equal(row.sourceMaxInstancesOmitted,true);assert.equal(row.maximumApprovedBound,100);
 }
 assert.deepEqual(result.reservedHttpSignatureObservations.filter(row=>row.disposition==='platform-http-added')
  .map(row=>({name:row.name,before:row.before,after:row.after})),
 changedHttpNames.toSorted((a,b)=>a.localeCompare(b)).map(name=>({name,before:null,after:'http'})));
 assert.equal(JSON.stringify(result).includes(privateCanary),false);
 return result;
}
test('observed controls preserve configured Run20 and absent GCF maximum without inventing100',()=>{
 const d=observedFixture();assertObservedPass(d);
 assert.equal(newNames.every(name=>!Object.hasOwn(find(d,name).serviceConfig,'maxInstanceCount')),true);
});
test('source-defined App Check read-only callable may add HTTP metadata without changing its security policy',()=>{
 const d=observedFixture();assertObservedPass(d);
 delete d.before.find(row=>row.buildConfig.entryPoint==='getBackendReleaseIdentity').serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;
 d.runServices.push(runService(find(d,'getBackendReleaseIdentity')));
 const result=helper.compareFunctionViews(d);
 assert.equal(result.existingBackendIdentityAppCheckEnforcementTruePreserved,true);
 assert.deepEqual(result.reservedHttpSignatureObservations.find(row=>row.name==='getBackendReleaseIdentity'),
  {name:'getBackendReleaseIdentity',before:null,after:'http',disposition:'platform-http-added'});
});
test('legacy mode still refuses actual-shaped absent GCF cap and separately refuses signature additions',()=>{
 const actual=observedFixture();assertObservedPass(actual);
 assert.throws(()=>helper.compareFunctionViews({...actual,controlMode:undefined}),/Existing environment changed/);
 const onlyCap=observedFixture();assertObservedPass(onlyCap);
 for(const name of changedHttpNames)onlyCap.before.find(row=>row.buildConfig.entryPoint===name)
  .serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE='http';
 assert.throws(()=>helper.compareFunctionViews({...onlyCap,controlMode:undefined}),/maxInstanceCount/);
});
test('observed controls accept exact GCF20 corroboration and a measured cap100 without claiming a reset',()=>{
 const d=observedFixture();assertObservedPass(d);
 for(const name of newNames)find(d,name).serviceConfig.maxInstanceCount=20;
 let result=helper.compareFunctionViews(d);
 assert.equal(result.newFunctionEffectiveInstanceCaps.every(row=>row.cloudFunctionsMaxInstanceCount===20&&row.effectiveMaxInstanceCount===20),true);
 for(const name of newNames){delete find(d,name).serviceConfig.maxInstanceCount;runFor(d,name).scaling.maxInstanceCount=100;}
 result=helper.compareFunctionViews(d);
 assert.equal(result.newFunctionEffectiveInstanceCaps.every(row=>row.cloudFunctionsMaxInstanceCount===null&&row.effectiveMaxInstanceCount===100),true);
 assert.equal(result.scalingObservations.filter(row=>newNames.includes(row.name)).every(row=>row.disposition==='observed-run-service-cap'),true);
});
test('new HTTP signature may remain absent while observed project environment remains exact',()=>{
 const d=observedFixture();assertObservedPass(d);
 for(const name of newNames){delete find(d,name).serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;mirrorEnv(d,name);}
 const result=helper.compareFunctionViews(d);
 assert.equal(result.reservedHttpSignatureObservations.filter(row=>row.disposition==='new-http-callable').every(row=>row.after===null),true);
});
test('unchanged private values remain absent from observed public controls',()=>{
 const d=observedFixture();assertObservedPass(d);
 for(const row of [...d.before,...d.after])row.serviceConfig.environmentVariables.PRIVATE_OPERATOR=privateCanary;
 for(const name of [...changedHttpNames,...newNames])mirrorEnv(d,name);
 const result=assertObservedPass(d),text=JSON.stringify(result);
 assert.equal(text.includes('PRIVATE_OPERATOR'),false);assert.equal(text.includes('environmentVariables'),false);
});
const observedNegatives=[
 ['changed existing project environment',d=>{find(d,'completePlannedJobExecution').serviceConfig.environmentVariables.FIREBASE_CONFIG=privateCanary;mirrorEnv(d,'completePlannedJobExecution');}],
 ['changed existing private environment',d=>{find(d,'completePlannedJobExecution').serviceConfig.environmentVariables.PRIVATE_OPERATOR=privateCanary;mirrorEnv(d,'completePlannedJobExecution');}],
 ['changed new project environment',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.GCLOUD_PROJECT=privateCanary;mirrorEnv(d,'mutateAssetHierarchyV2');}],
 ['extra new private environment',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.PRIVATE_OPERATOR=privateCanary;mirrorEnv(d,'mutateAssetHierarchyV2');}],
 ['incorrect existing HTTP signature',d=>{find(d,'completePlannedJobExecution').serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE=privateCanary;mirrorEnv(d,'completePlannedJobExecution');}],
 ['removed existing HTTP signature',d=>{delete find(d,'mutateAssetHierarchy').serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;}],
 ['incorrect new HTTP signature',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE=privateCanary;mirrorEnv(d,'mutateAssetHierarchyV2');}],
 ['signature addition to a Firestore event',d=>{delete d.before.find(row=>row.buildConfig.entryPoint==='onTicketCreated').serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;}],
 ['signature addition with a newly attached event trigger',d=>{find(d,'completePlannedJobExecution').eventTrigger={serviceAccountEmail:privateCanary};}],
 ['missing complete Run inventory',d=>{delete d.runServices;}],
 ['missing bound new Run service',d=>{d.runServices=d.runServices.filter(row=>row!==runFor(d));}],
 ['missing bound changed-existing Run service',d=>{d.runServices=d.runServices.filter(row=>row!==runFor(d,'completePlannedJobExecution'));}],
 ['duplicate bound Run service',d=>{d.runServices.push(structuredClone(runFor(d)));}],
 ['wrong function-to-service binding',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.service=privateCanary;}],
 ['wrong measured service name',d=>{runFor(d).name=`projects/${project}/locations/${region}/services/other`;}],
 ['invalid Run identity',d=>{runFor(d).uid=privateCanary;}],
 ['missing measured service maximum',d=>{delete runFor(d).scaling.maxInstanceCount;}],
 ['absent service-level scaling',d=>{delete runFor(d).scaling;}],
 ['unbounded measured service maximum',d=>{runFor(d).scaling.maxInstanceCount=101;}],
 ['zero measured service maximum',d=>{runFor(d).scaling.maxInstanceCount=0;}],
 ['fractional measured service maximum',d=>{runFor(d).scaling.maxInstanceCount=20.5;}],
 ['string measured service maximum',d=>{runFor(d).scaling.maxInstanceCount=privateCanary;}],
 ['unreviewed service minimum',d=>{runFor(d).scaling.minInstanceCount=1;}],
 ['unreviewed revision scaling',d=>{runFor(d).template.scaling={maxInstanceCount:20};}],
 ['GCF maximum conflicts with measured Run20',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.maxInstanceCount=100;}],
 ['malformed explicit GCF maximum',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.maxInstanceCount=privateCanary;}],
 ['wrong function serving revision',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.revision='wrong-function-00002-abc';}],
 ['mismatched latest-created revision',d=>{runFor(d).latestCreatedRevision+='/wrong';}],
 ['mismatched latest-ready revision',d=>{runFor(d).latestReadyRevision+='/wrong';}],
 ['mismatched template revision',d=>{runFor(d).template.revision='mutateassethierarchyv2-00001-abc';}],
 ['non-latest function routing',d=>{find(d,'mutateAssetHierarchyV2').serviceConfig.allTrafficOnLatestRevision=false;}],
 ['tagged traffic route',d=>{runFor(d).traffic[0].tag='old-route';}],
 ['split traffic route',d=>{runFor(d).traffic=[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:99},{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION',percent:1,revision:'older'}];}],
 ['traffic readback differs',d=>{runFor(d).trafficStatuses[0].percent=99;}],
 ['missing observed traffic',d=>{delete runFor(d).trafficStatuses;}],
 ['unready service',d=>{runFor(d).terminalCondition.state='CONDITION_PENDING';}],
 ['wrong readiness condition',d=>{runFor(d).terminalCondition.type='ConfigurationsReady';}],
 ['reconciling service',d=>{runFor(d).reconciling=true;}],
 ['unobserved generation',d=>{runFor(d).observedGeneration='1';}],
 ['missing observed generation',d=>{delete runFor(d).observedGeneration;}],
 ['invalid generation',d=>{runFor(d).generation='0';runFor(d).observedGeneration='0';}],
 ['different Run ingress',d=>{runFor(d).ingress='INGRESS_TRAFFIC_INTERNAL_ONLY';}],
 ['different Run runtime principal',d=>{runFor(d).template.serviceAccount=privateCanary;}],
 ['non-HTTP Run trigger type',d=>{runFor(d).template.annotations['cloudfunctions.googleapis.com/trigger-type']='EVENT_TRIGGER';}],
 ['extra runtime container',d=>{runFor(d).template.containers.push(structuredClone(runFor(d).template.containers[0]));}],
 ['Run-only environment drift',d=>{runFor(d).template.containers[0].env.push({name:'PRIVATE_OPERATOR',value:privateCanary});}],
 ['Run value differs from GCF',d=>{runFor(d).template.containers[0].env[0].value=privateCanary;}],
 ['duplicate Run environment key',d=>{runFor(d).template.containers[0].env.push(structuredClone(runFor(d).template.containers[0].env[0]));}],
 ['unmeasured Run environment secret binding',d=>{runFor(d).template.containers[0].env[0]={name:'PRIVATE_OPERATOR',valueSource:{secretKeyRef:{secret:privateCanary}}};}],
 ['source maximum omission is unproven',d=>{d.options.sdkReset.sourceMaxInstancesOmitted=false;}],
 ['global source options are not absent',d=>{d.options.sdkReset.sourceGlobalOptionsAbsent=false;}],
 ['source ceiling has changed',d=>{d.options.mutating.mutateAssetHierarchyV2.maxInstanceCount=101;}],
 ['unknown comparator mode',d=>{d.controlMode='unknown-controls';}],
];
for(const [name,mutate] of observedNegatives)test(`observed controls refuse ${name} without leaking private values`,()=>{
 const d=observedFixture();assertObservedPass(d);mutate(d);
 assert.throws(()=>helper.compareFunctionViews(d),error=>{
  assert.equal(error.message.includes(privateCanary),false);
  assert.equal(error.message.includes('actual:'),false);assert.equal(error.message.includes('expected:'),false);
  return true;
 });
});
