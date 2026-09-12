import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
// Synthetic local checks only. Does not execute the live collector or assembler.
const test=require('node:test'),assert=require('node:assert/strict'),cp=require('node:child_process');
const helper=require('./reviewedBackendControls.js');
const root=process.cwd(),source=cp.execFileSync('git',['--no-replace-objects','rev-parse','HEAD'],{encoding:'utf8'}).trim();
const options=helper.sourceOptions(root,source),newNames=Object.keys(options.policy.runtimeIdentityAliases);
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
test('actual Git source options distinguish 15 existing and four new controls',()=>{
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
