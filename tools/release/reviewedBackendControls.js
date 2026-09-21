"use strict";
// Read-only local comparison of already captured Google function records.
// No credentials, remote requests, deploy, build, or business operations.
// Pure source-bound comparison; the campaign CLI wrapper is kept separate.
// The complete raw evidence is input only and is never returned.

const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const assert=require('node:assert/strict'),{execFileSync,spawnSync}=require('node:child_process');
const {isDeepStrictEqual}=require('node:util');
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const OBSERVED_CONTROL_MODE='observed-cloud-run-http-controls-v1';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function parsePrivateEvidenceJson(input){try{return JSON.parse(input.toString('utf8').replace(/^\uFEFF/,''));}catch{throw new Error('Private evidence is not valid JSON; body withheld.');}}
const object=x=>x!=null&&typeof x==='object'&&!Array.isArray(x);
const sorted=x=>[...x].sort();
const eq=(a,b,message='Comparison differs')=>assert.ok(isDeepStrictEqual(a,b),message);
const equal=(a,b,message='Scalar comparison differs')=>assert.ok(Object.is(a,b),message);
// The successor may pin every exported endpoint to the already measured20.
// Admit only literal per-endpoint values; globals, spreads carrying caps,
// partial populations and dynamic expressions remain outside this policy.
function explicitFleetMaxInstances(ts,texts,policy){
 const bindings=policy.functionBindings,names=sorted(Object.keys(bindings));equal(names.length,19,'Exact19 source fleet required');
 const declarations=new Map();let mentions=0;
 for(const [file,text]of Object.entries(texts)){
  const source=ts.createSourceFile(file,text,ts.ScriptTarget.Latest,true);
  function visit(n){
   if((ts.isIdentifier(n)||ts.isStringLiteral(n))&&n.text==='maxInstances')mentions++;
   if(ts.isVariableDeclaration(n)&&ts.isIdentifier(n.name)&&names.includes(n.name.text)){
    assert.ok(!declarations.has(n.name.text),'Duplicate source endpoint declaration');declarations.set(n.name.text,n.initializer);
   }ts.forEachChild(n,visit);
  }visit(source);
 }
 eq(sorted(declarations.keys()),names,'Every exported endpoint needs its literal cap');equal(mentions,19,'Only19 direct maxInstances options admitted');
 for(const name of names){const init=declarations.get(name);assert.ok(init&&ts.isCallExpression(init),'Endpoint initializer must be direct');
  const expected=bindings[name].workloadClass.includes('CALLABLE')?['onCall']:bindings[name].workloadClass==='SCHEDULED_FIRESTORE_MUTATION'?['onSchedule']:['onDocumentCreated','onDocumentUpdated','onDocumentWritten'];
  assert.ok(expected.includes(init.expression.getText()),'Unexpected endpoint provider');
  const opts=init.arguments[0];assert.ok(opts&&ts.isObjectLiteralExpression(opts),'Endpoint options must be a literal');
  const caps=opts.properties.filter(p=>ts.isPropertyAssignment(p)&&ts.isIdentifier(p.name)&&p.name.text==='maxInstances');
  equal(caps.length,1,'One direct maxInstances per endpoint required');assert.ok(ts.isNumericLiteral(caps[0].initializer)&&caps[0].initializer.getText()==='20','Only literal maxInstances20 admitted');
 }
 return {capPolicy:'explicit-literal20-v1',declaredMaxInstances:20,functionNames:names};
}
function sourceOptions(repoRoot,sourceCommit){
 assert.ok(/^[a-f0-9]{40}$/.test(sourceCommit),'Exact source commit required');
 const globalOptions=spawnSync('git',['--no-replace-objects','-C',repoRoot,'grep','-l','-w','-e','setGlobalOptions','-e','preserveExternalChanges',sourceCommit,'--','functions/src'],{encoding:'utf8',windowsHide:true});
 assert.ok(globalOptions.status===1 && globalOptions.stdout.trim()==='', 'Global runtime options require a separately reviewed creation-default policy');
 const ts=require(path.join(repoRoot,'functions/node_modules/typescript'));
 const files={},read=file=>{const bytes=execFileSync('git',['--no-replace-objects','-C',repoRoot,'show',`${sourceCommit}:${file}`],{windowsHide:true});files[file]=hash(bytes);return bytes.toString('utf8');};
 const policy=JSON.parse(read('release/function-fleet-runtime-identity-policy.json'));
 const maximums=spawnSync('git',['--no-replace-objects','-C',repoRoot,'grep','-l','-w','-e','maxInstances',sourceCommit,'--','functions/src'],{encoding:'utf8',windowsHide:true});
 assert.ok(maximums.status===0||maximums.status===1,'Maximum-options source search failed');
 let capPolicy='historical-omitted-v1',declaredMaxInstances=null;
 if(maximums.status===0){
  const capFiles=['functions/src/index.ts','functions/src/maintenanceWorkflow/callable.ts','functions/src/maintenanceWorkflow/escalationSweep.ts','functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts'].sort();
  eq(maximums.stdout.trim().split(/\r?\n/).map(row=>row.slice(sourceCommit.length+1)).sort(),capFiles,'Maximum options outside reviewed endpoint files');
  ({capPolicy,declaredMaxInstances}=explicitFleetMaxInstances(ts,Object.fromEntries(capFiles.map(file=>[file,read(file)])),policy));
 }
 const runtime=`nodejs${JSON.parse(read('functions/package.json')).engines.node}`;
 const lock=JSON.parse(read('functions/package-lock.json'));
 const sdkPackage=JSON.parse(fs.readFileSync(path.join(repoRoot,'functions/node_modules/firebase-functions/package.json'),'utf8'));
 equal(sdkPackage.version,lock.packages['node_modules/firebase-functions'].version,'Installed SDK differs from the source lock');
 const manifestPath=path.join(repoRoot,'functions/node_modules/firebase-functions/lib/runtime/manifest.js');
 const manifest=require(manifestPath);
 equal(manifest.initV2Endpoint({}).maxInstances?.toJSON(),null,'Installed SDK does not reset omitted maxInstances');
 equal(Object.hasOwn(manifest.initV2Endpoint({preserveExternalChanges:true}),'maxInstances'),false,'Installed SDK external-state preservation differs');
 const sdkReset={version:sdkPackage.version,manifestSha256:hash(fs.readFileSync(manifestPath)),maxInstancesResetVerified:true,
  sourceMaxInstancesOmitted:declaredMaxInstances===null,sourcePreserveExternalChangesOmitted:true,sourceGlobalOptionsAbsent:true,
  ...(declaredMaxInstances===null?{}:{sourceExplicitMaxInstanceCount:declaredMaxInstances,sourceExplicitMaxInstanceFunctionCount:19})};
 const parsed={};
 function source(file){return parsed[file]??=ts.createSourceFile(file,read(file),ts.ScriptTarget.Latest,true);}
 function initializer(file,name){const matches=[];function visit(n){if(ts.isVariableDeclaration(n)&&ts.isIdentifier(n.name)&&n.name.text===name)matches.push(n.initializer);ts.forEachChild(n,visit);}visit(source(file));equal(matches.length,1,`One exact source declaration required: ${name}`);return matches[0];}
 const unwrap=n=>ts.isAsExpression(n)?n.expression:n;
 function properties(n){n=unwrap(n);assert.ok(ts.isObjectLiteralExpression(n),'Expected literal source options');const result={};for(const p of n.properties){assert.ok(ts.isPropertyAssignment(p),'Unsupported dynamic source security option');const key=p.name.getText();equal(Object.hasOwn(result,key),false);result[key]=p.initializer;}return result;}
 function text(n){assert.ok(n&&ts.isStringLiteral(n),'Expected explicit source string');return n.text;}
 function number(n){assert.ok(n&&ts.isNumericLiteral(n),'Expected explicit source number');return Number(n.text);}
 const security='functions/src/callableSecurityConfig.ts';
 const parameter=initializer(security,'MUTATING_CALLABLE_ENFORCE_APP_CHECK');
 assert.ok(ts.isCallExpression(parameter));equal(parameter.expression.getText(),'defineBoolean');
 equal(text(parameter.arguments[0]),'CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK');
 equal(properties(parameter.arguments[1]).default.kind,ts.SyntaxKind.FalseKeyword);
 const shared=properties(initializer(security,'MUTATING_CALLABLE_SECURITY_OPTIONS'));
 eq(Object.keys(shared).sort(),['consumeAppCheckToken','enforceAppCheck']);
 equal(shared.enforceAppCheck.getText(),'MUTATING_CALLABLE_ENFORCE_APP_CHECK');
 equal(shared.consumeAppCheckToken.kind,ts.SyntaxKind.FalseKeyword);
 const identity=properties(initializer('functions/src/stage2dSecurityConfig.ts','BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS'));
 equal(identity.enforceAppCheck.kind,ts.SyntaxKind.TrueKeyword);
 equal(identity.consumeAppCheckToken.kind,ts.SyntaxKind.FalseKeyword);
 const identityCallable=initializer('functions/src/index.ts','getBackendReleaseIdentity');
 assert.ok(ts.isCallExpression(identityCallable));equal(identityCallable.expression.getText(),'onCall');
 const identityOptions=identityCallable.arguments[0];assert.ok(ts.isObjectLiteralExpression(identityOptions));
 eq(identityOptions.properties.filter(p=>ts.isSpreadAssignment(p)).map(p=>p.expression.getText()),['BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS']);
 equal(identityOptions.properties.some(p=>ts.isPropertyAssignment(p)&&['enforceAppCheck','consumeAppCheckToken'].includes(p.name.getText())),false);

 const result={};
 for(const [name,binding]of Object.entries(policy.functionBindings)){
  if(binding.workloadClass!=='CALLABLE_FIRESTORE_MUTATION')continue;
  const file=name.startsWith('executeMaintenanceWorkflowCommand')?'functions/src/maintenanceWorkflow/callable.ts':'functions/src/index.ts';
  const init=initializer(file,name);assert.ok(ts.isCallExpression(init));equal(init.expression.getText(),'onCall');
  const arg=init.arguments[0];assert.ok(ts.isObjectLiteralExpression(arg));const values={},spreads=[];
  for(const p of arg.properties){if(ts.isSpreadAssignment(p)){spreads.push(p.expression.getText());continue;}assert.ok(ts.isPropertyAssignment(p));equal(Object.hasOwn(values,p.name.getText()),false);values[p.name.getText()]=p.initializer;}
  eq(spreads,['MUTATING_CALLABLE_SECURITY_OPTIONS']);
  eq(Object.keys(values).sort(),['concurrency','memory','region','serviceAccount','timeoutSeconds',...(declaredMaxInstances===null?[]:['maxInstances'])].sort());
  equal(values.region.getText(),'CALLABLE_REGION');equal(text(initializer(file,'CALLABLE_REGION')),REGION);
  const alias=policy.runtimeIdentityAliases?.[name]??name;
  equal(values.serviceAccount.getText(),`FUNCTION_RUNTIME_SERVICE_ACCOUNTS.${alias}`);
  const memory=text(values.memory);assert.ok(/^\d+(MiB|GiB)$/.test(memory),'Explicit source memory required');
  result[name]={runtime,entryPoint:name,region:REGION,availableMemory:memory.replace(/B$/,''),maxInstanceCount:declaredMaxInstances??100,
   timeoutSeconds:number(values.timeoutSeconds),maxInstanceRequestConcurrency:number(values.concurrency),
   serviceAccountEmail:`${binding.runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`,ingressSettings:'ALLOW_ALL',enforceAppCheck:false};
 }
 return {policy,runtime,mutating:result,files,sdkReset,capPolicy,declaredMaxInstances};
}
function boundHttpService(f,name,runServices){
 const service=`projects/${PROJECT}/locations/${REGION}/services/${name.toLowerCase()}`;
 equal(f.serviceConfig.service,service,'Function/Run service binding differs');
 assert.ok(Array.isArray(runServices),'Complete measured Run inventory required');
 const matches=runServices.filter(row=>row.name===service);equal(matches.length,1,'One exact measured Run service required');
 const run=matches[0],revision=f.serviceConfig.revision;
 assert.ok(typeof run.uid==='string'&&/^[a-f0-9-]{36}$/.test(run.uid),'Measured Run identity required');
 assert.ok(typeof revision==='string'&&revision.startsWith(`${name.toLowerCase()}-`)&&/^[a-z0-9-]+$/.test(revision),'Measured serving revision required');
 assert.ok(typeof run.generation==='string'&&/^[1-9][0-9]*$/.test(run.generation),'Measured generation required');
 equal(run.observedGeneration,run.generation,'Run generation is not observed');
 assert.ok(run.reconciling===undefined||run.reconciling===false,'Run service is still reconciling');
 equal(run.terminalCondition?.type,'Ready','Run readiness type differs');equal(run.terminalCondition?.state,'CONDITION_SUCCEEDED','Run service is not ready');
 equal(run.latestCreatedRevision,`${service}/revisions/${revision}`,'Created revision differs');
 equal(run.latestReadyRevision,run.latestCreatedRevision,'Ready revision differs');
 equal(run.template?.revision,revision,'Template revision differs');
 const latest=[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:100}];
 eq(run.traffic,latest,'Run traffic is not exclusively the latest revision');eq(run.trafficStatuses,latest,'Observed Run traffic differs');
 equal(f.serviceConfig.allTrafficOnLatestRevision,true,'Function traffic is not exclusively latest');
 equal(run.ingress,'INGRESS_TRAFFIC_ALL','Run ingress differs');
 equal(run.template.serviceAccount,f.serviceConfig.serviceAccountEmail,'Run runtime identity differs');
 equal(run.template.annotations?.['cloudfunctions.googleapis.com/trigger-type'],'HTTP_TRIGGER','Run transport is not HTTP');
 assert.ok(Array.isArray(run.template.containers)&&run.template.containers.length===1,'One HTTP runtime container required');
 const entries=run.template.containers[0].env;assert.ok(Array.isArray(entries),'Measured container environment required');
 const env={};for(const entry of entries){
  eq(Object.keys(entry).sort(),['name','value'],'Unsupported container environment binding');
  assert.ok(typeof entry.name==='string'&&typeof entry.value==='string'&&!Object.hasOwn(env,entry.name),'Malformed container environment');
  Object.defineProperty(env,entry.name,{value:entry.value,enumerable:true});
 }
 eq(env,f.serviceConfig.environmentVariables,'Cloud Functions and serving Run environment differ');
 return run;
}
function httpSignature(environment){
 if(!Object.hasOwn(environment,'FUNCTION_SIGNATURE_TYPE'))return null;
 equal(environment.FUNCTION_SIGNATURE_TYPE,'http','Reserved HTTP signature metadata differs');return 'http';
}
function withoutSignature(environment){const {FUNCTION_SIGNATURE_TYPE,...projectEnvironment}=environment;return projectEnvironment;}
function compareFunctionViews({before,after,options,allowExistingMaxInstanceReset=false,controlMode,runServices}){
 assert.ok(options.sdkReset?.sourceMaxInstancesOmitted===true,'Historical15-plus4 comparator requires the historical omitted-cap source');
 assert.ok(controlMode===undefined||controlMode===OBSERVED_CONTROL_MODE,'Unsupported backend control mode');
 const observed=controlMode===OBSERVED_CONTROL_MODE;
 const policy=options.policy,names=sorted(Object.keys(policy.functionBindings)),newNames=sorted(Object.keys(policy.runtimeIdentityAliases)),oldNames=names.filter(n=>!newNames.includes(n));
 eq([names.length,newNames.length,oldNames.length],[19,4,15]);
 const map=rows=>{const entries=rows.map(f=>{assert.ok(typeof f.name==='string'&&f.name.startsWith(`projects/${PROJECT}/locations/${REGION}/functions/`));return [f.name.split('/').at(-1),f];});equal(new Set(entries.map(x=>x[0])).size,entries.length);return Object.fromEntries(entries);};
 const a=map(before),b=map(after);eq(sorted(Object.keys(a)),oldNames);eq(sorted(Object.keys(b)),names);
 const env=f=>{assert.ok(object(f.serviceConfig?.environmentVariables),'Full measured function environment is required');return f.serviceConfig.environmentVariables;};
 const trigger=f=>f.eventTrigger?.serviceAccountEmail??null;
 const scalingObservations=[],reservedHttpSignatureObservations=[],newFunctionEffectiveInstanceCaps=[];
 for(const name of oldNames){
  const x=a[name],y=b[name];
  if(observed&&!isDeepStrictEqual(env(x),env(y))){
   assert.ok(/^(?:APP_CHECKED_)?CALLABLE_/.test(policy.functionBindings[name].workloadClass)&&x.eventTrigger==null&&y.eventTrigger==null,'Changed metadata requires a source-defined HTTP callable');
   equal(httpSignature(env(x)),null,'Existing HTTP signature cannot be replaced or removed');
   equal(httpSignature(env(y)),'http','Only platform HTTP signature addition is admitted');
   eq(withoutSignature(env(x)),withoutSignature(env(y)),`Existing project environment changed: ${name}`);
   boundHttpService(y,name,runServices);
   reservedHttpSignatureObservations.push({name,before:null,after:'http',disposition:'platform-http-added'});
  }else eq(env(x),env(y),`Existing environment changed: ${name}`);
  equal(x.serviceConfig.serviceAccountEmail,y.serviceConfig.serviceAccountEmail,`Existing runtime identity changed: ${name}`);
  equal(trigger(x),trigger(y),`Existing trigger identity changed: ${name}`);
  equal(typeof x.serviceConfig.ingressSettings,'string');equal(x.serviceConfig.ingressSettings,y.serviceConfig.ingressSettings,`Existing ingress changed: ${name}`);
  eq(x.serviceConfig.secretEnvironmentVariables??[],y.serviceConfig.secretEnvironmentVariables??[],`Existing secret environment changed: ${name}`);
  const prior=x.serviceConfig.maxInstanceCount,current=y.serviceConfig.maxInstanceCount;
  assert.ok(Number.isSafeInteger(prior)&&prior>0&&Number.isSafeInteger(current)&&current>0,`Missing measured max-instance limits: ${name}`);
  const reset=prior!==current;
  assert.ok(!reset||(allowExistingMaxInstanceReset===true&&options.sdkReset?.maxInstancesResetVerified===true&&current===100),`Existing max-instance change is not an approved source default reset: ${name}`);
  scalingObservations.push({name,beforeMaxInstanceCount:prior,afterMaxInstanceCount:current,disposition:reset?'approved-source-default-reset':'unchanged'});
 }
 const newOptions=[];
 for(const name of names){
  const f=b[name],binding=policy.functionBindings[name];equal(f.state,'ACTIVE');equal(f.environment,'GEN_2');
  equal(f.serviceConfig.serviceAccountEmail,`${binding.runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`);
  equal(f.buildConfig?.runtime,options.runtime);equal(f.buildConfig?.entryPoint,name);
  equal(env(f).CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK,'false',`Mutating parameter changed: ${name}`);
  if(!newNames.includes(name))continue;
  const expected=options.mutating[name];assert.ok(expected);const alias=policy.runtimeIdentityAliases[name];
  equal(f.eventTrigger==null,true,`New callable unexpectedly owns a trigger: ${name}`);
  for(const k of ['availableMemory','timeoutSeconds','maxInstanceRequestConcurrency','serviceAccountEmail','ingressSettings',...(observed?[]:['maxInstanceCount'])])equal(f.serviceConfig[k],expected[k],`New source option differs: ${name}.${k}`);
  if(observed){
   assert.ok(options.sdkReset?.sourceMaxInstancesOmitted===true&&options.sdkReset.sourceGlobalOptionsAbsent===true&&expected.maxInstanceCount===100,'Source scaling omission is not proven');
   const run=boundHttpService(f,name,runServices),cap=run.scaling?.maxInstanceCount;
   eq(Object.keys(run.scaling??{}),['maxInstanceCount'],'An explicit service-level maximum without other scaling settings is required');
   assert.ok(Number.isSafeInteger(cap)&&cap>0&&cap<=100,'Measured service-level cap exceeds the source-defined ceiling or is absent');
   equal(run.template.scaling,undefined,'Unexpected revision-level scaling requires separate review');
   const gcf=Object.hasOwn(f.serviceConfig,'maxInstanceCount')?f.serviceConfig.maxInstanceCount:null;
   assert.ok(gcf===null||(Number.isSafeInteger(gcf)&&gcf===cap),'Explicit Cloud Functions maximum conflicts with serving Run cap');
   newFunctionEffectiveInstanceCaps.push({name,serviceResource:run.name,serviceUid:run.uid,revision:f.serviceConfig.revision,
    observedGeneration:run.observedGeneration,cloudFunctionsMaxInstanceCount:gcf,runServiceMaxInstanceCount:cap,
    runRevisionMaxInstanceCount:null,effectiveMaxInstanceCount:cap,maximumApprovedBound:100});
   reservedHttpSignatureObservations.push({name,before:null,after:httpSignature(env(f)),disposition:'new-http-callable'});
  }
  // Pinned Firebase CLI prepare.js and cloudfunctionsv2.js generate these two
  // endpoint identities. Validate their exact values; only the remaining shared
  // environment is equal to V1. Never ignore arbitrary new environment keys.
  const sharedEnvironment=(row,entryPoint)=>{
   const {FUNCTION_TARGET,EVENTARC_CLOUD_EVENT_SOURCE,...shared}=env(row);
   equal(FUNCTION_TARGET,entryPoint.replaceAll('-','.'),`Generated function target differs: ${entryPoint}`);
   equal(EVENTARC_CLOUD_EVENT_SOURCE,`projects/${PROJECT}/locations/${REGION}/services/${entryPoint}`,`Generated event source differs: ${entryPoint}`);
   if(observed)httpSignature(shared);else equal(shared.FUNCTION_SIGNATURE_TYPE,'http',`Callable signature differs: ${entryPoint}`);
   equal(shared.LOG_EXECUTION_ID,'true',`Execution logging identity differs: ${entryPoint}`);
   return observed?withoutSignature(shared):shared;
  };
  eq(sharedEnvironment(f,name),sharedEnvironment(a[alias],alias),`New callable shared environment differs from the preserved V1 project environment: ${name}`);
  eq(f.serviceConfig.secretEnvironmentVariables??[],[],`Unexpected new secret environment: ${name}`);
  for(const k of ['availableCpu','minInstanceCount','vpcConnector','vpcConnectorEgressSettings','allTrafficOnLatestRevision'])eq(f.serviceConfig[k]??null,a[alias].serviceConfig[k]??null,`Unexpected new default/control differs from V1: ${name}.${k}`);
  if(observed){const {maxInstanceCount,...sourceDefined}=expected;newOptions.push({name,alias,...sourceDefined,sourceMaxInstancesOmitted:true,maximumApprovedBound:100});}
  else newOptions.push({name,alias,...expected});
  scalingObservations.push({name,beforeMaxInstanceCount:null,afterMaxInstanceCount:observed?newFunctionEffectiveInstanceCaps.at(-1).effectiveMaxInstanceCount:f.serviceConfig.maxInstanceCount,disposition:observed?'observed-run-service-cap':'new-source-default'});
 }
 return {functionCount:names.length,existingFunctionCount:oldNames.length,newFunctionCount:newNames.length,existingFunctionNames:oldNames,newFunctionNames:newNames,
  allFunctionMutatingAppCheckParametersFalse:true,allMutatingCallableAppCheckEnforcementFalse:true,
  existingBackendIdentityAppCheckEnforcementTruePreserved:true,
  ...(observed?{controlMode,existingProjectEnvironmentVariablesUnchanged:true,reservedHttpSignatureMetadataValidated:true,newFunctionEffectiveInstanceCapsValidated:true,
   reservedHttpSignatureObservations:reservedHttpSignatureObservations.sort((x,y)=>x.name.localeCompare(y.name)),
   newFunctionEffectiveInstanceCaps:newFunctionEffectiveInstanceCaps.sort((x,y)=>x.name.localeCompare(y.name))}:{existingFunctionEnvironmentVariablesUnchanged:true}),
  existingRuntimeAndTriggerServiceAccountsUnchanged:true,existingIngressSettingsUnchanged:true,
  allFunctionsMatchSourceRuntimeIdentities:true,allFunctionsActiveGen2:true,newFunctionsMatchApprovedSourceOptions:true,newFunctionSourceOptions:newOptions,
  scalingObservations:scalingObservations.sort((x,y)=>x.name.localeCompare(y.name)),scalingSourceEvidence:options.sdkReset,
  scalingScope:observed?'New callables retain the explicitly measured serving Cloud Run service maximum, bounded by100 with source maxInstances omitted. An absent Cloud Functions field is recorded as absent, never converted to100. Existing measured limits remain unchanged or reset to100 only under explicit approval. Service scaling is a configured limit, not a guarantee about transient platform instance counts.':'New callables require source-default max instances100. Existing measured limits remain unchanged or reset to100 only under explicit current approval and verified source/SDK omission semantics; unchanged scaling is not claimed for a reset.'};
}
function compareReviewedBackendControls({repoRoot,approval,approvalSha256,sourceCommit,proof,controlMode,verificationAuthority,observedAtUtc}){
 const observed=controlMode===OBSERVED_CONTROL_MODE;
 const guard=observed?require('./scopedCallableInvokerIam.js'):require(path.join(repoRoot,'tools/release/scopedCallableInvokerIam.js'));
 const seals=observed?require('./collectProductionGlobalPullBackend.js'):require(path.join(repoRoot,'tools/release/collectProductionGlobalPullBackend.js'));
 const result=guard.validateProof({repoRoot,approval,approvalSha256,sourceCommit,proof});equal(result.ok,true);equal(result.decision,'PASS_NEW_CALLABLE_INVOKER_IAM_ONLY');
 const before=guard.pages(proof.before.raw.functions,`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions');
 const after=guard.pages(proof.after.raw.functions,`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions');
 const resetApproval=approval.approvedDeployment.existingMaxInstanceCountReset;
 if(resetApproval!==undefined)eq(resetApproval,{authorized:true,targetMaxInstanceCount:100,sourceMaxInstancesOmitted:true,sourcePreserveExternalChangesOmitted:true},'Unsupported max-instance reset approval');
 const opts=sourceOptions(repoRoot,sourceCommit);
 const scalingAuthority=approval.approvedDeployment.sourceScalingAuthority;
 if(resetApproval!==undefined||scalingAuthority!==undefined)eq(scalingAuthority,opts.sdkReset,'Approved source/SDK scaling authority differs from current verification');
 if(observed){
  require('./reviewedBackendVerifierAuthority.js').validateVerifierAuthority({repoRoot,verificationAuthority,sourceCommit,approvalSha256,observedAtUtc,verifyLoadedFiles:true});
  assert.ok(Date.parse(observedAtUtc)>=Date.parse(proof.after.raw.completedAtUtc),'Verification predates the captured controls');
 }
 else assert.ok(verificationAuthority===undefined,'Verifier authority requires explicit observed control mode');
 const runServices=observed?proof.after.raw.runInventories.filter(row=>row.location===REGION).flatMap(row=>guard.pages(row.pages,`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${REGION}/services`,'services')):undefined;
 const controls=compareFunctionViews({before,after,options:opts,allowExistingMaxInstanceReset:resetApproval!==undefined,controlMode,runServices});
 const runtimes=sorted(new Set(after.map(f=>{const value=f.labels?.['firebase-functions-hash'];assert.ok(/^[a-f0-9]{40,64}$/i.test(value),'Invalid deployed source digest');return value;})));
 return seals.sealReceipt({schemaVersion:observed?2:1,evidenceType:'reviewed-current-source-backend-control-comparison',decision:'PASS_BACKEND_PRE_POST_CONTROL_COMPARISON',
  observedAtUtc:observed?observedAtUtc:proof.after.raw.completedAtUtc,...(observed?{verificationAuthority}:{}),sourceCommit,approvalSha256:approvalSha256.toUpperCase(),functionCount:controls.functionCount,
  sourceRuntimeHash:runtimes.length===1?runtimes[0]:null,sourceRuntimeHashes:runtimes,...controls,
  projectIamBindingsSemanticallyUnchanged:true,scopedIamProofReceiptSha256:proof.receiptSha256,
  sourceOptionsFiles:Object.entries(opts.files).map(([file,sha256])=>({file,sha256})),
  appCheckScope:'The shared mutating parameter is false on all function deployments; source-bound mutating callables enforce false. The existing read-only backend identity callable retains its explicit true enforcement. No claim that every endpoint disables App Check.',
  controlComparisonScope:observed?'Existing project environment, runtime/trigger identities and ingress are preserved. Only recorded absent-to-http platform signature additions are admitted for bound HTTP callables; full environment byte equality is not claimed. New callables preserve V1 project environment, source options and measured serving Cloud Run caps.':'Existing 15 environments/runtime and trigger identities/ingress are compared before and after. Four new endpoints are compared with approved source options and preserved V1 project environment; they did not exist before.',
  iamScope:'Complete observed IAM and environment evidence is privately revalidated; private raw observations may contain sensitive environment/IAM values. Only approved new invoker bindings and sanitized control observations are public. Unavailable regions listed in the proof are excluded; no unchanged or absence claim is made there.',
  unavailableRunRegions:proof.before.measurement.unavailableRunRegions??[],controlPlaneMutationPerformedByThisReadback:false,businessPayloadsRead:false});
}
module.exports={sourceOptions,explicitFleetMaxInstances,compareFunctionViews,compareReviewedBackendControls,parsePrivateEvidenceJson,OBSERVED_CONTROL_MODE};
