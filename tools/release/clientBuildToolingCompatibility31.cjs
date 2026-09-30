'use strict';
// Exact dev-tool delta verifier. Callers must obtain complete snapshots from the actual Git
// objects at deployed F and candidate M. This pure module creates no authority.
const {isDeepStrictEqual}=require('node:util');
const path=require('node:path').posix;
const DEPLOYED_BASELINE='2aa30de56cfdb960da3eeefd8956d8cbbae57b46';
const ADAPTER='tooling/brace-expansion-compat/package.json';
const LOCKS=['package-lock.json','functions/package-lock.json'];
const ROOT_SCRIPT='test:distribution-readback-custody';
const ROOT_SCRIPT_BEFORE="node --test tools/release/collectDistributionInstallationReadback.test.mjs tools/release/containGitHubProductionArtifacts.test.mjs tools/release/currentSourceRuntimeAuthority.test.mjs tools/release/stagedPromotionSourceAuthority.test.mjs tools/release/Private-GcsReleaseCustody.test.mjs tools/release/Private-GcsReleaseCustodySuccessor.test.mjs tools/release/Production-AppCheckPolicy.test.mjs tools/release/scopedCallableInvokerIam.test.mjs tools/release/scopedCallableInvokerIamPublic.test.mjs tools/release/reviewedBackendControls.test.mjs tools/release/reviewedBackendVerifierAuthority.test.mjs tools/release/reviewedRulesRuntimeCollector.test.mjs";
const ROOT_SCRIPT_AFTER="node --test tools/release/collectDistributionInstallationReadback.test.mjs tools/release/containGitHubProductionArtifacts.test.mjs tools/release/currentSourceRuntimeAuthority.test.mjs tools/release/stagedPromotionSourceAuthority.test.mjs tools/release/clientBackendCompatibility31.test.mjs tools/release/Private-GcsReleaseCustody.test.mjs tools/release/Private-GcsReleaseCustodySuccessor.test.mjs tools/release/Production-AppCheckPolicy.test.mjs tools/release/scopedCallableInvokerIam.test.mjs tools/release/scopedCallableInvokerIamPublic.test.mjs tools/release/reviewedBackendControls.test.mjs tools/release/reviewedBackendVerifierAuthority.test.mjs tools/release/reviewedRulesRuntimeCollector.test.mjs";
const OLD_INTEGRITY='sha512-ScQ4IuvIEF1TMlP7Zt+vjJ//9zlPb2SDcxWxM3bk8s6t6GGdJ7KO1dCcTidOPJKePW30LE/2cT7wCyPho9/Wxg==';
const FIXED={version:'5.0.12',resolved:'https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.12.tgz',integrity:'sha512-YovQ3rzhaLMIrDjNDMkNS01tea93qhEhG5xy8f6+R0l+dw3Ki+5sCoIoI942iuLZTHWogWktgwVDhU09iNEimQ=='};
function must(value,message){if(!value)throw new Error(message);}
function safePath(value){return typeof value==='string'&&value.length>0&&value.length<=1024&&!value.includes('\\')&&!value.includes(':')&&!value.startsWith('/')&&value.split('/').every(part=>part!==''&&part!=='.'&&part!=='..');}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function json(value,label){must(typeof value==='string',label+': raw source text required');const result=JSON.parse(value);must(plain(result),label+': object required');return result;}
function equal(a,b,label){must(isDeepStrictEqual(a,b),label);}
function checkLock(before,after,label){
  must(before.lockfileVersion===3&&after.lockfileVersion===3,label+': exact lockfile schema required');
  must(plain(before.packages)&&plain(after.packages),label+': package map required');
  must(Object.keys(before.packages).length<=10000&&Object.keys(after.packages).length<=10000,label+': package inventory too large');
  for(const key of new Set([...Object.keys(before.packages),...Object.keys(after.packages)]))must(key===''||safePath(key),label+': unsafe package path');
  const adapter=before.packages['node_modules/brace-expansion'];
  const upstream=before.packages['node_modules/brace-expansion-modern'];
  must(adapter?.version==='5.0.9'&&adapter.dev===true&&adapter.dependencies?.['brace-expansion-modern']==='npm:brace-expansion@5.0.9',label+': original dev adapter differs');
  const originalPath=label==='package-lock.json'?'file:tooling/brace-expansion-compat':'file:../tooling/brace-expansion-compat';
  must(adapter.resolved===originalPath,label+': original adapter path differs');
  must(upstream?.name==='brace-expansion'&&upstream.version==='5.0.9'&&upstream.dev===true&&upstream.resolved==='https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.9.tgz'&&upstream.integrity===OLD_INTEGRITY,label+': original upstream differs');
  const expected=structuredClone(before);
  expected.packages['node_modules/brace-expansion'].version=FIXED.version;
  expected.packages['node_modules/brace-expansion'].dependencies['brace-expansion-modern']='npm:brace-expansion@'+FIXED.version;
  Object.assign(expected.packages['node_modules/brace-expansion-modern'],FIXED);
  equal(after,expected,label+': delta exceeds the exact two development-only nodes');
}
function validName(name){return typeof name==='string'&&/^(?:@[a-z0-9._-]+\/)?[a-z0-9._-]+$/i.test(name);}
function declarations(pkg,field,label){const entries=pkg[field]??{};must(plain(entries)&&Object.keys(entries).length<=1000,label+': invalid or oversized '+field);for(const[name,spec]of Object.entries(entries))must(validName(name)&&typeof spec==='string'&&spec.length>0,label+': invalid dependency declaration');return entries;}
function findDependency(packages,from,name){
  let current=from;
  while(true){
    if(path.basename(current)!=='node_modules'){
      const key=(current?current+'/':'')+'node_modules/'+name;
      if(Object.hasOwn(packages,key))return key;
    }
    if(current==='')return null;
    const next=path.dirname(current);current=next==='.'?'':next;
  }
}
function runtimeReachability(manifest,lock){
  must(plain(lock.packages)&&Object.keys(lock.packages).length<=10000,'Runtime lock package map required/bounded');
  for(const key of Object.keys(lock.packages))must(key===''||safePath(key),'Unsafe runtime package path');
  const rows={},active=new Set();
  function visitDependencies(pkg,from){
    const required=declarations(pkg,'dependencies',from),optional=declarations(pkg,'optionalDependencies',from),peers=from?declarations(pkg,'peerDependencies',from):{};
    const all={...required,...optional,...peers};
    for(const name of Object.keys(all)){
      const key=findDependency(lock.packages,from,name);
      const mayBeAbsent=Object.hasOwn(optional,name)||(!Object.hasOwn(required,name)&&Object.hasOwn(peers,name)&&pkg.peerDependenciesMeta?.[name]?.optional===true);
      if(key===null){must(mayBeAbsent,'Unresolved runtime dependency '+from+' -> '+name);continue;}
      const row=lock.packages[key];must(plain(row)&&typeof row.version==='string','Invalid runtime package '+key);
      must(row.dev!==true,'Runtime dependency falsely classified dev-only: '+key);
      rows[key]=row;
      if(active.has(key))continue;active.add(key);visitDependencies(row,key);
    }
  }
  visitDependencies(manifest,'');
  return Object.fromEntries(Object.entries(rows).sort(([a],[b])=>a.localeCompare(b)));
}
function verifyDevelopmentToolingSnapshots({baselineCommit,before,after}){
  must(baselineCommit===DEPLOYED_BASELINE,'Wrong deployed backend baseline');
  must(plain(before)&&plain(after),'Complete source maps required');
  must(Object.keys(before).length<=10000&&Object.keys(after).length<=10000,'Protected source inventory too large');
  for(const key of new Set([...Object.keys(before),...Object.keys(after)]))must(safePath(key),'Unsafe protected source path');
  equal(Object.keys(after).sort(),Object.keys(before).sort(),'Protected source file set differs');
  for(const required of ['.npmrc','functions/.npmrc','tooling/firebase-cli/.npmrc','package.json','functions/package.json',...LOCKS,ADAPTER,'tooling/brace-expansion-compat/index.cjs','tooling/brace-expansion-compat/index.mjs','firestore.rules','firestore.indexes.json'])must(Object.hasOwn(before,required),'Missing required protected file '+required);
  must(Object.keys(before).some(p=>p.startsWith('functions/src/'))&&Object.keys(before).some(p=>p.startsWith('android/')),'Complete source/native inventory required');
  const permitted=new Set([...LOCKS,ADAPTER,'package.json']);
  for(const[file,bytes]of Object.entries(before)){
    must(typeof bytes==='string'&&typeof after[file]==='string','Non-text source entry '+file);
    if(!permitted.has(file))equal(after[file],bytes,'Protected source content differs: '+file);
  }
  const originalRoot=json(before['package.json'],'Original root manifest'),candidateRoot=json(after['package.json'],'Candidate root manifest');
  if(!isDeepStrictEqual(originalRoot,candidateRoot)){
    must(originalRoot.scripts?.[ROOT_SCRIPT]===ROOT_SCRIPT_BEFORE,'Original root custody script differs');
    const expectedRoot=structuredClone(originalRoot);expectedRoot.scripts[ROOT_SCRIPT]=ROOT_SCRIPT_AFTER;
    equal(candidateRoot,expectedRoot,'Root manifest delta exceeds the exact reviewed test-script insertion');
  }
  const originalAdapter=json(before[ADAPTER],ADAPTER);must(originalAdapter.name==='brace-expansion'&&originalAdapter.version==='5.0.9'&&originalAdapter.dependencies?.['brace-expansion-modern']==='npm:brace-expansion@5.0.9','Original adapter package differs');
  const fixedAdapter=structuredClone(originalAdapter);fixedAdapter.version=FIXED.version;fixedAdapter.dependencies['brace-expansion-modern']='npm:brace-expansion@'+FIXED.version;
  equal(json(after[ADAPTER],ADAPTER),fixedAdapter,'Shared adapter change exceeds version/upstream pin');
  for(const file of LOCKS)checkLock(json(before[file],file),json(after[file],file),file);
  const manifest=json(before['functions/package.json'],'Functions manifest'),oldLock=json(before['functions/package-lock.json'],'Original Functions lock'),newLock=json(after['functions/package-lock.json'],'Candidate Functions lock');
  const oldRuntime=runtimeReachability(manifest,oldLock),newRuntime=runtimeReachability(manifest,newLock);equal(newRuntime,oldRuntime,'Reachable runtime dependency graph differs');
  const ordinary=l=>Object.fromEntries(Object.entries(l.packages).filter(([key,value])=>key!==''&&value.dev!==true));equal(ordinary(newLock),ordinary(oldLock),'Runtime/optional lock metadata differs');
  return {ok:true,admittedGeneration:31,developmentDependencyChange:true,backendRuntimeChange:false,changedFiles:[...permitted].filter(file=>before[file]!==after[file]),runtimeReachablePaths:Object.keys(newRuntime).length,constructionAuthority:false};
}
function verifyLocalRuntimeProof({baselineFiles,candidateFiles,baselineInstalledRuntime,candidateInstalledRuntime,audits}){
  must(plain(baselineFiles)&&Object.keys(baselineFiles).length>0&&plain(candidateFiles),'Emitted file hashes required');
  must(Object.entries(baselineFiles).every(([p,h])=>safePath(p)&&/\.js(?:\.map)?$/.test(p)&&/^[a-f0-9]{64}$/i.test(h)),'Invalid emitted file hash');
  equal(candidateFiles,baselineFiles,'Emitted file set/content differs');
  must(plain(baselineInstalledRuntime)&&plain(baselineInstalledRuntime.dependencies)&&Object.keys(baselineInstalledRuntime.dependencies).length>0,'Installed runtime graph absent');
  must(!Object.hasOwn(baselineInstalledRuntime,'problems')&&!Object.hasOwn(candidateInstalledRuntime,'problems'),'Installed runtime graph has problems');
  equal(candidateInstalledRuntime,baselineInstalledRuntime,'Actual installed runtime graph differs');
  const populations=['root-full','root-runtime','functions-full','functions-runtime','cli-full'];equal(Object.keys(audits??{}).sort(),populations.sort(),'Required audit populations differ');
  for(const key of populations){const report=audits[key];must(plain(report)&&!Object.hasOwn(report,'error')&&report.auditReportVersion===2&&plain(report.vulnerabilities)&&Object.keys(report.vulnerabilities).length===0&&plain(report.metadata?.vulnerabilities),key+': clean actual audit required');for(const severity of ['info','low','moderate','high','critical','total'])must(report.metadata.vulnerabilities[severity]===0,key+': vulnerability count not numeric zero');}
  return {ok:true,emittedFileCount:Object.keys(baselineFiles).length,constructionAuthority:false};
}
module.exports={DEPLOYED_BASELINE,verifyDevelopmentToolingSnapshots,runtimeReachability,verifyLocalRuntimeProof};
