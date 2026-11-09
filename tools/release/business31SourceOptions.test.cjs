"use strict";
// Pure source and synthetic Git checks for the Build31-only policy.
const test=require('node:test'),assert=require('node:assert/strict'),cp=require('node:child_process');
const helper=require('./business31SourceOptions.cjs');
const historical=require('./reviewedBackendControls.js');
const root=process.cwd(),source='fc0ac09fc51b370bee419909ad510b044765b540';
const options=historical.sourceOptions(root,source);
const ts=require('../../functions/node_modules/typescript');
const fs=require('node:fs'),path=require('node:path');
const entry=()=>fs.readFileSync(path.join(root,'functions/src/index.ts'),'utf8');
const declaredPreservation={sourcePreserveExternalChangesOmitted:false,sourceGlobalOptionsAbsent:false,
 sourcePreserveExternalChangesDeclared:true,sourceGlobalOptionsPolicy:'entrypoint-preserve-external-changes-v1'};
test('only the exact early entrypoint preservation call is admitted',()=>{
 assert.deepEqual(helper.sourcePreservationPolicy({'functions/src/index.ts':entry()}),declaredPreservation);
 assert.deepEqual(helper.sourcePreservationPolicy({'functions/src/index.ts':entry().replace(/\r?\n/g,'\r\n')}),declaredPreservation);
 const compiled=ts.transpileModule(entry(),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const call=compiled.indexOf('(0, v2_1.setGlobalOptions)({ preserveExternalChanges: true });');
 assert.ok(call>compiled.indexOf('require("firebase-functions/v2")'));
 const imports=[...compiled.matchAll(/require\("([^"\n]+)"\)/g)].filter(([,name])=>name!=='firebase-functions/v2');
 assert.ok(imports.length>0);assert.ok(imports.every(row=>row.index>call),'The setting must execute before every other compiled import');
});
for(const [name,change]of [
 ['false preservation',t=>t.replace('preserveExternalChanges: true','preserveExternalChanges: false')],
 ['another option',t=>t.replace('preserveExternalChanges: true','preserveExternalChanges: true, minInstances: 0')],
 ['spread option',t=>t.replace('{preserveExternalChanges: true}','{...{preserveExternalChanges: true}}')],
 ['computed option',t=>t.replace('preserveExternalChanges: true','["preserveExternalChanges"]: true')],
 ['aliased setter',t=>t.replace('{setGlobalOptions}','{setGlobalOptions as configure}')],
 ['extra argument',t=>t.replace('preserveExternalChanges: true});','preserveExternalChanges: true}, {});')],
 ['import before setting',t=>'import "./maintenanceWorkflow/firebaseExports";\n'+t],
 ['statement before setting',t=>'void 0;\n'+t],
 ['late setter',t=>t.replace('setGlobalOptions({preserveExternalChanges: true});','')+'\nsetGlobalOptions({preserveExternalChanges: true});'],
 ['duplicate setter',t=>t+'\nsetGlobalOptions({preserveExternalChanges: true});'],
 ['extra word in comment',t=>t+'\n// preserveExternalChanges is not another approved occurrence'],
 ['extra word in string',t=>t+'\nconst extra = "setGlobalOptions";'],
 ])test(`preservation source policy refuses ${name}`,()=>assert.throws(()=>helper.sourcePreservationPolicy({'functions/src/index.ts':change(entry())})));
test('preservation source policy refuses another source file or a duplicate location',()=>{
 assert.throws(()=>helper.sourcePreservationPolicy({'functions/src/other.ts':entry()}));
 assert.throws(()=>helper.sourcePreservationPolicy({'functions/src/index.ts':entry(),'functions/src/other.ts':'// setGlobalOptions'}));
});
test('historical preservation facts remain absent rather than being relabelled',()=>{
 assert.deepEqual(helper.sourcePreservationPolicy({'functions/src/index.ts':'export const noGlobalOptions = true;'}),{
  sourcePreserveExternalChangesOmitted:true,sourceGlobalOptionsAbsent:true});
 assert.equal(options.sdkReset.sourcePreserveExternalChangesOmitted,true);
 assert.equal(options.sdkReset.sourceGlobalOptionsAbsent,true);
 assert.equal(Object.hasOwn(options.sdkReset,'sourcePreserveExternalChangesDeclared'),false);
});
test('exact Git source extraction admits the new setting and rejects a second file occurrence',()=>{
 const parent=path.join(root,'build');fs.mkdirSync(parent,{recursive:true});
 const base=path.join(parent,'build31-source-policy-'),directory=fs.mkdtempSync(base);
 const git=(args,extra={})=>cp.execFileSync('git',['--no-replace-objects','-C',directory,...args],{encoding:'utf8',windowsHide:true,...extra}).trim();
 try{
  git(['init','--quiet']);const objects=path.resolve(root,cp.execFileSync('git',['-C',root,'rev-parse','--git-path','objects'],{encoding:'utf8'}).trim());
  fs.writeFileSync(path.join(directory,'.git/objects/info/alternates'),objects.replaceAll('\\','/')+'\n');
  git(['read-tree','49cd181eed60010cc6438ef8a9b769bdde62c4b4']);
  const put=(file,text)=>{const blob=git(['hash-object','-w','--stdin'],{input:text});git(['update-index','--add','--cacheinfo',`100644,${blob},${file}`]);};
  const commit=()=>git(['commit-tree',git(['write-tree'])],{input:'Synthetic source policy fixture only\n',env:{...process.env,
   GIT_AUTHOR_NAME:'Fixture',GIT_AUTHOR_EMAIL:'fixture@example.invalid',GIT_COMMITTER_NAME:'Fixture',GIT_COMMITTER_EMAIL:'fixture@example.invalid'}});
  put('functions/src/index.ts',entry());fs.mkdirSync(path.join(directory,'functions'));
  fs.symlinkSync(path.join(root,'functions/node_modules'),path.join(directory,'functions/node_modules'),process.platform==='win32'?'junction':'dir');
  const exactCommit=commit(),current=helper.sourceOptions(directory,exactCommit);
  assert.throws(()=>historical.sourceOptions(directory,exactCommit),/Global runtime options require a separately reviewed creation-default policy/);
  for(const [key,value]of Object.entries(declaredPreservation))assert.equal(current.sdkReset[key],value);
  assert.equal(current.sdkReset.sourceMaxInstancesOmitted,false);assert.equal(current.declaredMaxInstances,20);
  assert.equal(current.sdkReset.sourceExplicitMaxInstanceFunctionCount,19);
  put('functions/src/extra-global.ts','// preserveExternalChanges\n');
  assert.throws(()=>helper.sourceOptions(directory,commit()),/outside the reviewed entrypoint/);
 }finally{
  const link=path.join(directory,'functions/node_modules');if(fs.existsSync(link))fs.unlinkSync(link);
  assert.ok(directory.startsWith(base));fs.rmSync(directory,{recursive:true,force:true});
 }
});
