'use strict';
// Synthetic test fixture only: not readbacks, CI provenance or release authority.
const crypto=require('node:crypto');
const {sealReceipt}=require('./collectProductionGlobalPullBackend.js');
const {PLAN,TYPE,BOUNDARY,SELF}=require('./collectClientBuildToolingRuntime31.cjs');
const H='A'.repeat(64),M='a'.repeat(40),TREE='b'.repeat(40),F='2aa30de56cfdb960da3eeefd8956d8cbbae57b46';
const hash=x=>crypto.createHash('sha256').update(x).digest('hex').toUpperCase();
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
const byteRecord=x=>({sha256:hash(x),bytes:Buffer.byteLength(x)});
function fixture(overrides={}){
 const base=Date.now()-10*60*1000,iso=n=>new Date(base+n).toISOString();
 const jobs=['Flutter host analysis + tests + no-loss contracts','Android release package + cold-start proof (non-production)','Android emulator shell + business integration (not physical-device evidence)','Firestore Rules + governed callable emulator','Cloud Functions host build + non-emulator tests'];
 function ci(kind,names,id){return {schemaVersion:1,evidenceType:kind==='release'?'github-exact-main-release-gate':'github-exact-main-codeql',repository:'abhishekvatsa/crm3_baf_ops',sourceCommit:M,sourceTree:TREE,capturedAtUtc:iso(4000),pullRequest:{number:1,merged:true,merge_commit_sha:M,merged_at:iso(0),base:{ref:'main',repo:{full_name:'abhishekvatsa/crm3_baf_ops'}}},run:{id,run_attempt:1,repository:{full_name:'abhishekvatsa/crm3_baf_ops'},head_sha:M,head_branch:'main',event:'push',path:kind==='release'?'.github/workflows/release-gate.yml':'.github/workflows/codeql.yml',status:'completed',conclusion:'success',created_at:iso(1000),updated_at:iso(3000)},jobs:{total_count:names.length,jobs:names.map((name,i)=>({id:id*100+i+1,name,run_id:id,run_attempt:1,head_sha:M,status:'completed',conclusion:'success',completed_at:iso(2000)}))}};}
 const releaseCi=ci('release',jobs,1),securityCi=ci('security',['CodeQL (actions)','CodeQL (java-kotlin)','CodeQL (javascript-typescript)','CodeQL (python)'],2);
 const sourceInventories={baseline:[{path:'functions/src/index.ts',mode:'100644',blob:'c'.repeat(40),sha256:H,bytes:1}],candidate:[{path:'functions/src/index.ts',mode:'100644',blob:'c'.repeat(40),sha256:H,bytes:1}]};
 const gitProof={ok:true,baselineCommit:F,candidateCommit:M,constructionAuthority:false},producers={[SELF]:H};
 const installed={name:'synthetic-functions',dependencies:{'firebase-admin':{version:'13.10.0'}}};
 const runtimeInputs={baseline:{manifest:{name:'synthetic-functions',dependencies:{'firebase-admin':'13.10.0'}},lock:{packages:{'node_modules/firebase-admin':{version:'13.10.0'}}}},candidate:{manifest:{name:'synthetic-functions',dependencies:{'firebase-admin':'13.10.0'}},lock:{packages:{'node_modules/firebase-admin':{version:'13.10.0'}}}}};
 const emitted={'index.js':{sha256:H,bytes:1},'index.js.map':{sha256:H,bytes:1}};
 const audit={auditReportVersion:2,vulnerabilities:{},metadata:{vulnerabilities:{info:0,low:0,moderate:0,high:0,critical:0,total:0}}};
 const tools={node:{version:'v22.15.0',sha256:H},npm:{version:'10.9.2',sha256:H},baselineCompiler:{version:'5.9.3',sha256:H},candidateCompiler:{version:'5.9.3',sha256:H}};
 const commands=PLAN.map(([id,role,tool,args],i)=>{let structuredResult=null,stdoutText=null;
  if(id.endsWith('-emitted'))structuredResult={sourceCount:1,expectedFiles:['index.js','index.js.map'],actualFiles:['index.js','index.js.map']};
  if(id.endsWith('-installed'))structuredResult=structuredClone(installed);
  if(['root-full','root-runtime','functions-full','functions-runtime','cli-full'].includes(id))structuredResult=structuredClone(audit);
  if(structuredResult)stdoutText=JSON.stringify(structuredResult)+'\n';else if(id==='node-version')stdoutText=tools.node.version+'\n';else if(id==='npm-version')stdoutText=tools.npm.version+'\n';
  return {id,role,tool,args:[...args],startedAtUtc:iso(10000+i*1000),completedAtUtc:iso(10500+i*1000),exitCode:0,stdout:byteRecord(stdoutText??'synthetic command completed\n'),stderr:byteRecord(''),stdoutText,structuredResult};});
 const point={commit:M,tree:TREE,branch:'main',originMain:M,clean:true};
 const receipt=sealReceipt({schemaVersion:1,evidenceType:TYPE,candidateCommit:M,candidateTree:TREE,baselineCommit:F,startedAtUtc:iso(9000),completedAtUtc:iso(30000),sourceBefore:point,sourceAfter:structuredClone(point),producerHashes:producers,ciHashes:{release:hash(canonical(releaseCi)),security:hash(canonical(securityCi))},gitProof,exportedSources:sourceInventories,tools,commands,emitted:{baseline:structuredClone(emitted),candidate:structuredClone(emitted)},installed:{baseline:structuredClone(installed),candidate:structuredClone(installed)},audits:Object.fromEntries(['root-full','root-runtime','functions-full','functions-runtime','cli-full'].map(k=>[k,structuredClone(audit)])),boundary:structuredClone(BOUNDARY)});
 return {receipt,context:{candidateCommit:M,tree:TREE,lastCi:BigInt(Date.parse(iso(3000)))*1000000n,decision:BigInt(Date.parse(iso(40000)))*1000000n,releaseCi,securityCi,gitProof,producers,sourceInventories,runtimeInputs},releaseCi,securityCi,...overrides};
}
function reseal(value){const {receiptSha256,...body}=value;return sealReceipt(body);}
function installedFixtureFromLock(manifest,lock){
 // Explicitly fabricated test graph from a real fixture lock, never npm evidence.
 const posix=require('node:path').posix,seen=new Set();
 const find=(from,name)=>{let current=from;while(true){if(posix.basename(current)!=='node_modules'){const key=(current?current+'/':'')+'node_modules/'+name;if(Object.hasOwn(lock.packages,key))return key;}if(!current)return null;const next=posix.dirname(current);current=next==='.'?'':next;}};
 function children(pkg,from){const result={};for(const name of Object.keys({...pkg.dependencies,...pkg.optionalDependencies,...pkg.peerDependencies}).sort()){const key=find(from,name);if(!key)continue;const row=lock.packages[key],node={version:row.version};if(!seen.has(key)){seen.add(key);const nested=children(row,key);if(Object.keys(nested).length)node.dependencies=nested;}result[name]=node;}return result;}
 const result={name:manifest.name,dependencies:children(manifest,'')};if(manifest.version)result.version=manifest.version;return result;
}
module.exports={fixture,reseal,byteRecord,installedFixtureFromLock};
