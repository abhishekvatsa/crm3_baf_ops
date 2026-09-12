"use strict";
// Read-only local comparison of already captured Google function records.
// No credentials, remote requests, deploy, build, or business operations.
// Pure source-bound comparison; the campaign CLI wrapper is kept separate.
// The complete raw evidence is input only and is never returned.

const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const assert=require('node:assert/strict'),{execFileSync,spawnSync}=require('node:child_process');
const {isDeepStrictEqual}=require('node:util');
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function parsePrivateEvidenceJson(input){try{return JSON.parse(input.toString('utf8').replace(/^\uFEFF/,''));}catch{throw new Error('Private evidence is not valid JSON; body withheld.');}}
const object=x=>x!=null&&typeof x==='object'&&!Array.isArray(x);
const sorted=x=>[...x].sort();
const eq=(a,b,message='Comparison differs')=>assert.ok(isDeepStrictEqual(a,b),message);
const equal=(a,b,message='Scalar comparison differs')=>assert.ok(Object.is(a,b),message);
function sourceOptions(repoRoot,sourceCommit){
 assert.ok(/^[a-f0-9]{40}$/.test(sourceCommit),'Exact source commit required');
 const globalOptions=spawnSync('git',['--no-replace-objects','-C',repoRoot,'grep','-l','-w','-e','setGlobalOptions','-e','maxInstances','-e','preserveExternalChanges',sourceCommit,'--','functions/src'],{encoding:'utf8',windowsHide:true});
 assert.ok(globalOptions.status===1 && globalOptions.stdout.trim()==='', 'Global runtime options require a separately reviewed creation-default policy');
 const ts=require(path.join(repoRoot,'functions/node_modules/typescript'));
 const files={},read=file=>{const bytes=execFileSync('git',['--no-replace-objects','-C',repoRoot,'show',`${sourceCommit}:${file}`],{windowsHide:true});files[file]=hash(bytes);return bytes.toString('utf8');};
 const policy=JSON.parse(read('release/function-fleet-runtime-identity-policy.json'));
 const runtime=`nodejs${JSON.parse(read('functions/package.json')).engines.node}`;
 const lock=JSON.parse(read('functions/package-lock.json'));
 const sdkPackage=JSON.parse(fs.readFileSync(path.join(repoRoot,'functions/node_modules/firebase-functions/package.json'),'utf8'));
 equal(sdkPackage.version,lock.packages['node_modules/firebase-functions'].version,'Installed SDK differs from the source lock');
 const manifestPath=path.join(repoRoot,'functions/node_modules/firebase-functions/lib/runtime/manifest.js');
 const manifest=require(manifestPath);
 equal(manifest.initV2Endpoint({}).maxInstances?.toJSON(),null,'Installed SDK does not reset omitted maxInstances');
 equal(Object.hasOwn(manifest.initV2Endpoint({preserveExternalChanges:true}),'maxInstances'),false,'Installed SDK external-state preservation differs');
 const sdkReset={version:sdkPackage.version,manifestSha256:hash(fs.readFileSync(manifestPath)),maxInstancesResetVerified:true,
  sourceMaxInstancesOmitted:true,sourcePreserveExternalChangesOmitted:true,sourceGlobalOptionsAbsent:true};
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
  eq(Object.keys(values).sort(),['concurrency','memory','region','serviceAccount','timeoutSeconds']);
  equal(values.region.getText(),'CALLABLE_REGION');equal(text(initializer(file,'CALLABLE_REGION')),REGION);
  const alias=policy.runtimeIdentityAliases?.[name]??name;
  equal(values.serviceAccount.getText(),`FUNCTION_RUNTIME_SERVICE_ACCOUNTS.${alias}`);
  const memory=text(values.memory);assert.ok(/^\d+(MiB|GiB)$/.test(memory),'Explicit source memory required');
  result[name]={runtime,entryPoint:name,region:REGION,availableMemory:memory.replace(/B$/,''),maxInstanceCount:100,
   timeoutSeconds:number(values.timeoutSeconds),maxInstanceRequestConcurrency:number(values.concurrency),
   serviceAccountEmail:`${binding.runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com`,ingressSettings:'ALLOW_ALL',enforceAppCheck:false};
 }
 return {policy,runtime,mutating:result,files,sdkReset};
}
function compareFunctionViews({before,after,options,allowExistingMaxInstanceReset=false}){
 const policy=options.policy,names=sorted(Object.keys(policy.functionBindings)),newNames=sorted(Object.keys(policy.runtimeIdentityAliases)),oldNames=names.filter(n=>!newNames.includes(n));
 eq([names.length,newNames.length,oldNames.length],[19,4,15]);
 const map=rows=>{const entries=rows.map(f=>{assert.ok(typeof f.name==='string'&&f.name.startsWith(`projects/${PROJECT}/locations/${REGION}/functions/`));return [f.name.split('/').at(-1),f];});equal(new Set(entries.map(x=>x[0])).size,entries.length);return Object.fromEntries(entries);};
 const a=map(before),b=map(after);eq(sorted(Object.keys(a)),oldNames);eq(sorted(Object.keys(b)),names);
 const env=f=>{assert.ok(object(f.serviceConfig?.environmentVariables),'Full measured function environment is required');return f.serviceConfig.environmentVariables;};
 const trigger=f=>f.eventTrigger?.serviceAccountEmail??null;
 const scalingObservations=[];
 for(const name of oldNames){
  const x=a[name],y=b[name];eq(env(x),env(y),`Existing environment changed: ${name}`);
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
  for(const k of ['availableMemory','timeoutSeconds','maxInstanceRequestConcurrency','serviceAccountEmail','ingressSettings','maxInstanceCount'])equal(f.serviceConfig[k],expected[k],`New source option differs: ${name}.${k}`);
  // Pinned Firebase CLI prepare.js and cloudfunctionsv2.js generate these two
  // endpoint identities. Validate their exact values; only the remaining shared
  // environment is equal to V1. Never ignore arbitrary new environment keys.
  const sharedEnvironment=(row,entryPoint)=>{
   const {FUNCTION_TARGET,EVENTARC_CLOUD_EVENT_SOURCE,...shared}=env(row);
   equal(FUNCTION_TARGET,entryPoint.replaceAll('-','.'),`Generated function target differs: ${entryPoint}`);
   equal(EVENTARC_CLOUD_EVENT_SOURCE,`projects/${PROJECT}/locations/${REGION}/services/${entryPoint}`,`Generated event source differs: ${entryPoint}`);
   equal(shared.FUNCTION_SIGNATURE_TYPE,'http',`Callable signature differs: ${entryPoint}`);
   equal(shared.LOG_EXECUTION_ID,'true',`Execution logging identity differs: ${entryPoint}`);
   return shared;
  };
  eq(sharedEnvironment(f,name),sharedEnvironment(a[alias],alias),`New callable shared environment differs from the preserved V1 project environment: ${name}`);
  eq(f.serviceConfig.secretEnvironmentVariables??[],[],`Unexpected new secret environment: ${name}`);
  for(const k of ['availableCpu','minInstanceCount','vpcConnector','vpcConnectorEgressSettings','allTrafficOnLatestRevision'])eq(f.serviceConfig[k]??null,a[alias].serviceConfig[k]??null,`Unexpected new default/control differs from V1: ${name}.${k}`);
  newOptions.push({name,alias,...expected});
  scalingObservations.push({name,beforeMaxInstanceCount:null,afterMaxInstanceCount:f.serviceConfig.maxInstanceCount,disposition:'new-source-default'});
 }
 return {functionCount:names.length,existingFunctionCount:oldNames.length,newFunctionCount:newNames.length,existingFunctionNames:oldNames,newFunctionNames:newNames,
  allFunctionMutatingAppCheckParametersFalse:true,allMutatingCallableAppCheckEnforcementFalse:true,
  existingBackendIdentityAppCheckEnforcementTruePreserved:true,
  existingFunctionEnvironmentVariablesUnchanged:true,existingRuntimeAndTriggerServiceAccountsUnchanged:true,existingIngressSettingsUnchanged:true,
  allFunctionsMatchSourceRuntimeIdentities:true,allFunctionsActiveGen2:true,newFunctionsMatchApprovedSourceOptions:true,newFunctionSourceOptions:newOptions,
  scalingObservations:scalingObservations.sort((x,y)=>x.name.localeCompare(y.name)),scalingSourceEvidence:options.sdkReset,
  scalingScope:'New callables require source-default max instances100. Existing measured limits remain unchanged or reset to100 only under explicit current approval and verified source/SDK omission semantics; unchanged scaling is not claimed for a reset.'};
}
function compareReviewedBackendControls({repoRoot,approval,approvalSha256,sourceCommit,proof}){
 const guard=require(path.join(repoRoot,'tools/release/scopedCallableInvokerIam.js'));
 const seals=require(path.join(repoRoot,'tools/release/collectProductionGlobalPullBackend.js'));
 const result=guard.validateProof({repoRoot,approval,approvalSha256,sourceCommit,proof});equal(result.ok,true);equal(result.decision,'PASS_NEW_CALLABLE_INVOKER_IAM_ONLY');
 const before=guard.pages(proof.before.raw.functions,`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions');
 const after=guard.pages(proof.after.raw.functions,`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions');
 const resetApproval=approval.approvedDeployment.existingMaxInstanceCountReset;
 if(resetApproval!==undefined)eq(resetApproval,{authorized:true,targetMaxInstanceCount:100,sourceMaxInstancesOmitted:true,sourcePreserveExternalChangesOmitted:true},'Unsupported max-instance reset approval');
 const opts=sourceOptions(repoRoot,sourceCommit);
 const scalingAuthority=approval.approvedDeployment.sourceScalingAuthority;
 if(resetApproval!==undefined||scalingAuthority!==undefined)eq(scalingAuthority,opts.sdkReset,'Approved source/SDK scaling authority differs from current verification');
 const controls=compareFunctionViews({before,after,options:opts,allowExistingMaxInstanceReset:resetApproval!==undefined});
 const runtimes=sorted(new Set(after.map(f=>{const value=f.labels?.['firebase-functions-hash'];assert.ok(/^[a-f0-9]{40,64}$/i.test(value),'Invalid deployed source digest');return value;})));
 return seals.sealReceipt({schemaVersion:1,evidenceType:'reviewed-current-source-backend-control-comparison',decision:'PASS_BACKEND_PRE_POST_CONTROL_COMPARISON',
  observedAtUtc:proof.after.raw.completedAtUtc,sourceCommit,approvalSha256:approvalSha256.toUpperCase(),functionCount:controls.functionCount,
  sourceRuntimeHash:runtimes.length===1?runtimes[0]:null,sourceRuntimeHashes:runtimes,...controls,
  projectIamBindingsSemanticallyUnchanged:true,scopedIamProofReceiptSha256:proof.receiptSha256,
  sourceOptionsFiles:Object.entries(opts.files).map(([file,sha256])=>({file,sha256})),
  appCheckScope:'The shared mutating parameter is false on all function deployments; source-bound mutating callables enforce false. The existing read-only backend identity callable retains its explicit true enforcement. No claim that every endpoint disables App Check.',
  controlComparisonScope:'Existing 15 environments/runtime and trigger identities/ingress are compared before and after. Four new endpoints are compared with approved source options and preserved V1 project environment; they did not exist before.',
  iamScope:'Complete observed IAM and environment evidence is privately revalidated; private raw observations may contain sensitive environment/IAM values. Only approved new invoker bindings and sanitized control observations are public. Unavailable regions listed in the proof are excluded; no unchanged or absence claim is made there.',
  unavailableRunRegions:proof.before.measurement.unavailableRunRegions??[],controlPlaneMutationPerformedByThisReadback:false,businessPayloadsRead:false});
}
module.exports={sourceOptions,compareFunctionViews,compareReviewedBackendControls,parsePrivateEvidenceJson};
