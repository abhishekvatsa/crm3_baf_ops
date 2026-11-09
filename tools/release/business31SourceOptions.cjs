"use strict";
// Build31-only exact source policy. Historical verifiers retain their own bytes.
// Read-only Git/SDK inspection; no cloud calls or business operations.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const assert=require('node:assert/strict'),{execFileSync,spawnSync}=require('node:child_process');
const {isDeepStrictEqual}=require('node:util');
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
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
  const expectedSpread=name==='beginGlobalPullRun'?'GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS':name==='getBackendReleaseIdentity'?'BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS':name==='stampGlobalPullServerClock'?'GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS':bindings[name].workloadClass==='CALLABLE_FIRESTORE_MUTATION'?'MUTATING_CALLABLE_SECURITY_OPTIONS':null;
  const propertyNames=new Set();let spreadCount=0;
  for(const p of opts.properties){
   if(ts.isSpreadAssignment(p)){assert.ok(expectedSpread!==null&&ts.isIdentifier(p.expression)&&p.expression.text===expectedSpread,'Unchecked endpoint spread could override the cap');spreadCount++;equal(spreadCount,1,'Duplicate endpoint spread');continue;}
   assert.ok(ts.isPropertyAssignment(p)&&ts.isIdentifier(p.name),'Computed/method endpoint properties could override the cap');
   assert.ok(!propertyNames.has(p.name.text),'Duplicate endpoint option');propertyNames.add(p.name.text);
  }
  const caps=opts.properties.filter(p=>ts.isPropertyAssignment(p)&&ts.isIdentifier(p.name)&&p.name.text==='maxInstances');
  equal(caps.length,1,'One direct maxInstances per endpoint required');assert.ok(ts.isNumericLiteral(caps[0].initializer)&&caps[0].initializer.getText()==='20','Only literal maxInstances20 admitted');
 }
 return {capPolicy:'explicit-literal20-v1',declaredMaxInstances:20,functionNames:names};
}
const PRESERVATION_PREFIX='import {setGlobalOptions} from "firebase-functions/v2";\n\nsetGlobalOptions({preserveExternalChanges: true});\n\n';
function sourcePreservationPolicy(texts){
 const mentioned=Object.entries(texts).filter(([,text])=>/\b(?:setGlobalOptions|preserveExternalChanges)\b/.test(text));
 if(mentioned.length===0)return {sourcePreserveExternalChangesOmitted:true,sourceGlobalOptionsAbsent:true};
 eq(mentioned.map(([file])=>file),['functions/src/index.ts'],'Global runtime options outside the reviewed entrypoint');
 const text=mentioned[0][1].replace(/\r\n/g,'\n');
 assert.ok(text.startsWith(PRESERVATION_PREFIX),'Exact preservation call must precede every other entrypoint import or statement');
 assert.ok(!/\b(?:setGlobalOptions|preserveExternalChanges)\b/.test(text.slice(PRESERVATION_PREFIX.length)),'Additional global runtime option occurrence');
 return {sourcePreserveExternalChangesOmitted:false,sourceGlobalOptionsAbsent:false,
  sourcePreserveExternalChangesDeclared:true,sourceGlobalOptionsPolicy:'entrypoint-preserve-external-changes-v1'};
}
function sourceOptions(repoRoot,sourceCommit){
 assert.ok(/^[a-f0-9]{40}$/.test(sourceCommit),'Exact source commit required');
 const globalOptions=spawnSync('git',['--no-replace-objects','-C',repoRoot,'grep','-l','-w','-e','setGlobalOptions','-e','preserveExternalChanges',sourceCommit,'--','functions/src'],{encoding:'utf8',windowsHide:true});
 assert.ok(globalOptions.status===0||(globalOptions.status===1&&globalOptions.stdout.trim()===''),'Global-options source search failed');
 const ts=require(path.join(repoRoot,'functions/node_modules/typescript'));
 const files={},read=file=>{const bytes=execFileSync('git',['--no-replace-objects','-C',repoRoot,'show',`${sourceCommit}:${file}`],{windowsHide:true});files[file]=hash(bytes);return bytes.toString('utf8');};
 const globalFiles=globalOptions.status===0?globalOptions.stdout.trim().split(/\r?\n/).map(row=>row.slice(sourceCommit.length+1)):[];
 const preservation=sourcePreservationPolicy(Object.fromEntries(globalFiles.map(file=>[file,read(file)])));
 const policy=JSON.parse(read('release/function-fleet-runtime-identity-policy.json'));
 const maximums=spawnSync('git',['--no-replace-objects','-C',repoRoot,'grep','-l','-w','-e','maxInstances',sourceCommit,'--','functions/src'],{encoding:'utf8',windowsHide:true});
 assert.ok(maximums.status===0||maximums.status===1,'Maximum-options source search failed');
 let capPolicy='historical-omitted-v1',declaredMaxInstances=null;
 if(maximums.status===0){
  const capFiles=['functions/src/index.ts','functions/src/maintenanceWorkflow/callable.ts','functions/src/maintenanceWorkflow/escalationSweep.ts','functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts'].sort();
  eq(maximums.stdout.trim().split(/\r?\n/).map(row=>row.slice(sourceCommit.length+1)).sort(),capFiles,'Maximum options outside reviewed endpoint files');
  ({capPolicy,declaredMaxInstances}=explicitFleetMaxInstances(ts,Object.fromEntries(capFiles.map(file=>[file,read(file)])),policy));
 }
 if(preservation.sourcePreserveExternalChangesDeclared===true)equal(declaredMaxInstances,20,'Preservation requires the reviewed19 explicit endpoint caps');
 const runtime=`nodejs${JSON.parse(read('functions/package.json')).engines.node}`;
 const lock=JSON.parse(read('functions/package-lock.json'));
 const sdkPackage=JSON.parse(fs.readFileSync(path.join(repoRoot,'functions/node_modules/firebase-functions/package.json'),'utf8'));
 equal(sdkPackage.version,lock.packages['node_modules/firebase-functions'].version,'Installed SDK differs from the source lock');
 const manifestPath=path.join(repoRoot,'functions/node_modules/firebase-functions/lib/runtime/manifest.js');
 const manifest=require(manifestPath);
 equal(manifest.initV2Endpoint({}).maxInstances?.toJSON(),null,'Installed SDK does not reset omitted maxInstances');
 equal(Object.hasOwn(manifest.initV2Endpoint({preserveExternalChanges:true}),'maxInstances'),false,'Installed SDK external-state preservation differs');
 const sdkReset={version:sdkPackage.version,manifestSha256:hash(fs.readFileSync(manifestPath)),maxInstancesResetVerified:true,
  sourceMaxInstancesOmitted:declaredMaxInstances===null,...preservation,
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
 eq(Object.keys(identity).sort(),['consumeAppCheckToken','enforceAppCheck','serviceAccount'],'Identity security spread fields differ');
 equal(identity.enforceAppCheck.kind,ts.SyntaxKind.TrueKeyword);
 equal(identity.consumeAppCheckToken.kind,ts.SyntaxKind.FalseKeyword);
 if(declaredMaxInstances!==null){
  const readOnly=properties(initializer(security,'READ_ONLY_CALLABLE_SECURITY_OPTIONS'));
  eq(Object.keys(readOnly).sort(),['consumeAppCheckToken','enforceAppCheck'],'Read-only security spread fields differ');
  equal(readOnly.enforceAppCheck.kind,ts.SyntaxKind.FalseKeyword);equal(readOnly.consumeAppCheckToken.kind,ts.SyntaxKind.FalseKeyword);
  const globalFile='functions/src/globalPullSecurityConfig.ts',globalPull=unwrap(initializer(globalFile,'GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS'));
  assert.ok(ts.isObjectLiteralExpression(globalPull));
  equal(globalPull.properties.length,2,'Global pull security spread fields differ');
  const [readonlySpread,serviceProperty]=globalPull.properties;
  assert.ok(ts.isSpreadAssignment(readonlySpread)&&ts.isIdentifier(readonlySpread.expression)&&readonlySpread.expression.text==='READ_ONLY_CALLABLE_SECURITY_OPTIONS','Global pull security spread differs');
  assert.ok(ts.isPropertyAssignment(serviceProperty)&&ts.isIdentifier(serviceProperty.name)&&serviceProperty.name.text==='serviceAccount','Global pull runtime binding differs');
  const globalTrigger=properties(initializer(globalFile,'GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS'));
  eq(Object.keys(globalTrigger),['serviceAccount'],'Global pull trigger security spread fields differ');
 }
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
module.exports={sourceOptions,sourcePreservationPolicy,explicitFleetMaxInstances};
