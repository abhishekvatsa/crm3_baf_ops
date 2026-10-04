"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os"),cp=require("node:child_process"),zlib=require("node:zlib"),crypto=require("node:crypto");
const api=require("./business31NpmBinMaterialization.cjs"),authority=require("./business31BackendAuthority.cjs"),transport=require("./privateEvidenceBundle31.cjs");
const scratch=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-npm-bins-"));let serial=0;
// These fresh, bounded fixture trees are retained, including every failed case.
const make=label=>{const root=path.join(scratch,(++serial)+"-"+label);fs.mkdirSync(root);return root;};
function put(root,name,raw,mode){const file=path.join(root,...name.split("/"));fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw,mode?{mode}:undefined);return file;}
function roots(root){for(const directory of Object.values(api.ROOTS))fs.mkdirSync(path.join(root,directory),{recursive:true});}
function maps(root){return Object.fromEntries(Object.entries(api.ROOTS).map(([k,d])=>[k,api.scan31(path.join(root,d)).files]));}
const binding=()=>({path:fs.realpathSync(process.execPath),sha256:api.sha(fs.readFileSync(process.execPath))});
function verify(root,receipt){return api.verifyNpmBinMaterialization31({receipt,buildRoot:root,nodeExecutable:binding(),producerSha256:api.sha(fs.readFileSync(require.resolve("./business31NpmBinMaterialization.cjs"))),fileMaps:maps(root)});}
function packageFiles(root,prefix="",name="probe",bin="probe",code="#!/usr/bin/env node\nconsole.log(JSON.stringify(process.argv.slice(2)));\n"){
  put(root,prefix+name+"/package.json",JSON.stringify({name,version:"1.0.0",bin:{[bin]:"bin/run.js"}}));put(root,prefix+name+"/bin/run.js",code,0o755);
  const file=prefix+".bin/"+bin;fs.mkdirSync(path.dirname(path.join(root,file)),{recursive:true});fs.symlinkSync("../"+name+"/bin/run.js",path.join(root,file),"file");return file;
}
function regularTree(){const root=make("regular");roots(root);for(const directory of Object.values(api.ROOTS))put(root,directory+"/probe/package.json",'{"name":"probe","version":"1.0.0"}');return root;}
test("authority map retains root and nested special own keys and exact cardinality",()=>{
  const root=make("keys");for(const name of ["__proto__","constructor","toString","deep/__proto__"])put(root,name,name);
  const result=authority.fileMap31(root);assert.equal(Object.getPrototypeOf(result),Object.prototype);assert.deepEqual(Object.keys(result).sort(),["__proto__","constructor","deep/__proto__","toString"]);for(const name of Object.keys(result))assert.equal(result[name],api.sha(Buffer.from(name)));assert.deepEqual(JSON.parse(JSON.stringify(result)),result);
});
test("regular three-root preparation is complete measured evidence without operational authority",()=>{
  const root=regularTree(),receipt=api.materializeNpmBins31({buildRoot:root});assert.equal(verify(root,receipt).recordedMaterializationVerified,true);assert.equal(verify(root,receipt).processExecutionAuthenticated,false);
  for(const row of Object.values(receipt.roots)){assert.equal(row.aliases.length,0);assert.equal(row.beforeFilesSha256,row.afterFilesSha256);assert.equal(row.fileCount,1);}
});
test("native nested npm link remains forbidden generically and is materialized only on POSIX",()=>{
  const root=regularTree(),directory=path.join(root,api.ROOTS.functions),file=packageFiles(directory,"outer/node_modules/");
  assert.throws(()=>authority.fileMap31(directory),/regular materialized/);
  if(process.platform==="win32"){assert.throws(()=>api.materializeNpmBins31({buildRoot:root}),/relative alias target|Windows npm/);assert.equal(fs.lstatSync(path.join(directory,file)).isSymbolicLink(),true);return;}
  const receipt=api.materializeNpmBins31({buildRoot:root});assert.equal(receipt.roots.functions.aliases[0].file,file);assert.equal(fs.lstatSync(path.join(directory,file)).isFile(),true);assert.equal(fs.statSync(path.join(directory,file)).mode&0o777,0o755);assert.equal(verify(root,receipt).recordedMaterializationVerified,true);
  for(const key of ["targetMode","shimMode"]){const bad=structuredClone(receipt);bad.roots.functions.aliases[0][key]=0o600;assert.throws(()=>verify(root,bad),/recorded alias mode/);}
  assert.deepEqual(JSON.parse(cp.execFileSync(path.join(directory,file),["with spaces","quote'",'dollar$'],{encoding:"utf8"})),["with spaces","quote'",'dollar$']);
});
for(const [label,arrange,error] of [
  ["non-bin file link",root=>{put(root,"target","x");fs.symlinkSync("target",path.join(root,"alias"),"file");},/only npm/],
  ["directory link",root=>{fs.mkdirSync(path.join(root,"dir"));fs.symlinkSync("dir",path.join(root,"redirect"),process.platform==="win32"?"junction":"dir");},/only npm|relative alias/],
  ["undeclared command",root=>{packageFiles(root);put(root,"probe/package.json",'{"name":"probe","version":"1.0.0","bin":{"other":"bin/run.js"}}');},/package-declared|relative alias/],
  ["unsupported interpreter flags",root=>packageFiles(root,"","probe","probe","#!/usr/bin/env node --require other\n"),/interpreter|relative alias/],
  ["different declared target",root=>{packageFiles(root);put(root,"probe/package.json",'{"name":"probe","version":"1.0.0","bin":{"probe":"bin/other.js"}}');},/declaration|relative alias/],
  ["backslash target spelling",root=>{put(root,"probe/package.json",'{"name":"probe","bin":{"probe":"bin/run.js"}}');put(root,"probe/bin/run.js","#!/usr/bin/env node\n");fs.mkdirSync(path.join(root,".bin"));fs.symlinkSync("..\\probe\\bin\\run.js",path.join(root,".bin/probe"),"file");},/relative alias target/],
])test("refuses "+label+" before any materialization",()=>{const root=make(label.replaceAll(" ","-"));arrange(root);assert.throws(()=>api.scan31(root,true),error);});
test("receipt refuses altered producer and omitted or tampered populations",()=>{
  const root=regularTree(),good=api.materializeNpmBins31({buildRoot:root});for(const mutate of [r=>r.producer.sha256="A".repeat(64),r=>r.roots.root.fileCount++,r=>r.roots.cli.afterFilesSha256="A".repeat(64),r=>r.roots.functions.beforeFilesSha256="A".repeat(64),r=>delete r.roots.root]){const bad=structuredClone(good);mutate(bad);assert.throws(()=>verify(root,bad));}
  put(root,"node_modules/.bin/unrecorded",api.MARKER+"exit 0\n");const changed=structuredClone(good),map=maps(root).root;changed.roots.root.afterFilesSha256=api.sha(api.canonical(map));changed.roots.root.beforeFilesSha256=changed.roots.root.afterFilesSha256;changed.roots.root.fileCount=Object.keys(map).length;assert.throws(()=>verify(root,changed),/unrecorded materialized|unrecorded POSIX|Windows npm shim/);
});
function runtimeFixture(){
  const root=make("schema3"),evidence=path.join(root,".dart_tool/evidence"),runtimeRoot=make("runtime"),source={commit:"a".repeat(40),tree:"b".repeat(40),functionsTree:"c".repeat(40)},sourceBytes={};roots(root);fs.mkdirSync(evidence,{recursive:true});
  const sourceFile=(name,value)=>{const raw=Buffer.isBuffer(value)?value:Buffer.from(typeof value==="string"?value:JSON.stringify(value));sourceBytes[name]=raw;put(root,name,raw);};
  const toolchain=require("./business31ToolchainIdentity.cjs"),npmVersion="10.9.8",npmPackageRoot=path.join(runtimeRoot,"npm");
  const npm=put(npmPackageRoot,"bin/npm-cli.js","// inert synthetic process record target; never executed\n");
  put(npmPackageRoot,"package.json",JSON.stringify({name:"npm",version:npmVersion}));
  const npmFiles=api.scan31(npmPackageRoot).files,nodeExecutable=binding();
  // This synthetic profile belongs only to this synthetic source, not the empty
  // checked-in production profile table. Its process outputs are parser fixtures.
  const approved={...toolchain.format31(fs.readFileSync(process.execPath)),nodeVersion:process.versions.node,npmVersion,nodeSha256:nodeExecutable.sha256,npmEntry:"bin/npm-cli.js",npmFiles,npmFileCount:Object.keys(npmFiles).length,npmFilesSha256:api.sha(api.canonical(npmFiles)),provenance:{nodeDistribution:{url:"https://example.invalid/synthetic-node",sha256:"A".repeat(64)},npmDistribution:{url:"https://example.invalid/synthetic-npm",sha256:"B".repeat(64),integrity:"sha512-"+Buffer.alloc(64).toString("base64")},reviewEvidenceSha256:"C".repeat(64)}};
  const config={compilerOptions:{module:"commonjs",noImplicitReturns:true,noUnusedLocals:false,outDir:"lib",sourceMap:true,strict:true,target:"es2022"},compileOnSave:true,include:["src"]};
  const manifest={name:"fixture-functions",version:"1.0.0",dependencies:{"@grpc/grpc-js":"1.14.5"}},pkg={name:"@grpc/grpc-js",version:"1.14.5"},lock={packages:{"":manifest,"node_modules/@grpc/grpc-js":pkg}};
  for(const helper of [api.SELF,toolchain.SELF])sourceFile(helper,fs.readFileSync(require.resolve("./"+path.basename(helper))));
  sourceFile(toolchain.PROFILES,{schemaVersion:1,documentType:"build31-approved-toolchain-profiles",profiles:{"synthetic-host-case":approved}});
  sourceFile("release/production-release-policy.json",{toolchain:{nodeVersion:process.versions.node,npmVersion}});sourceFile("functions/package.json",manifest);sourceFile("functions/package-lock.json",lock);sourceFile("functions/tsconfig.json",config);sourceFile("functions/src/index.ts","export const value = 1;\n");
  put(root,"node_modules/probe/package.json",'{"name":"probe","version":"1.0.0"}');put(root,"functions/node_modules/@grpc/grpc-js/package.json",JSON.stringify(pkg));put(root,"tooling/firebase-cli/node_modules/firebase-tools/package.json",'{"name":"firebase-tools","version":"15.22.4"}');const cli=put(root,"tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js","// inert fixture CLI\n");
  put(root,"functions/lib/index.js","exports.value=1;\n");put(root,"functions/lib/index.js.map","{}\n");
  const runtime={nodeVersion:process.versions.node,npmVersion,toolchainProfileId:"synthetic-host-case",npmPackageRoot,firebaseCliVersion:"15.22.4",nodeExecutable,npmCliFile:{path:npm,sha256:api.sha(fs.readFileSync(npm))},cliEntrypoint:{path:cli,sha256:api.sha(fs.readFileSync(cli))}};
  let id=0;const retain=value=>{const raw=Buffer.isBuffer(value)?value:Buffer.from(typeof value==="string"?value:JSON.stringify(value)),file="original-"+(++id)+".json";put(evidence,file,raw);return {file,bytes:raw.length,sha256:api.sha(raw)};};
  if(process.platform!=="win32")packageFiles(path.join(root,api.ROOTS.root),"","runtime-bin","runtime-bin");
  const normalization=Buffer.from(JSON.stringify(api.materializeNpmBins31({buildRoot:root}))+"\n"),installed=Buffer.from(JSON.stringify({name:manifest.name,path:path.join(root,"functions"),dependencies:{"@grpc/grpc-js":{version:"1.14.5",path:path.join(root,"functions/node_modules/@grpc/grpc-js")}}}));
  const time=n=>"2026-01-02T02:"+String(n).padStart(2,"0")+":00Z";
  const outputMap=Object.fromEntries(["lib/index.js","lib/index.js.map"].map(name=>[name,api.sha(fs.readFileSync(path.join(root,"functions",name)))]));
  const testedEmittedFiles=Object.fromEntries(authority.OUTPUT_COMMANDS.map(kind=>[kind,retain(outputMap)]));
  const minutes={"node-version":1,"npm-version":3,"functions-build":9,"functions-host-tests":11,"governed-emulator-tests":13,"dependency-compatibility":15,"installed-runtime":17};
  const record=(kind,argv,stdout)=>{const output=authority.OUTPUT_COMMANDS.includes(kind),minute=kind.endsWith("-install")?5:kind==="dependency-bin-materialization"?7:kind.startsWith("audit-")?19:minutes[kind];return {schemaVersion:output?2:1,documentType:"build31-business-original-process",kind,sourceBefore:source,sourceAfter:source,executable:runtime.nodeExecutable.path,executableSha256:runtime.nodeExecutable.sha256,argv,cwd:root,startedAtUtc:time(minute),completedAtUtc:time(minute+1),exitCode:0,signal:null,error:null,stdout:retain(stdout??"synthetic original stdout"),stderr:retain(""),...(output?{emittedFilesAfterSha256:testedEmittedFiles[kind].sha256}:{})};};
  const clean={auditReportVersion:2,vulnerabilities:{},metadata:{vulnerabilities:{info:0,low:0,moderate:0,high:0,critical:0,total:0}}},commands=[...authority.COMMANDS,"dependency-bin-materialization"];
  const proof={schemaVersion:3,documentType:"build31-business-runtime-proof",profile:authority.PROFILE,source,startedAtUtc:time(0),completedAtUtc:time(30),buildRoot:root,runtime,testedEmittedFiles,toolchainProbes:Object.fromEntries(["node","npm"].map(kind=>[kind,retain(record(kind+"-version",toolchain.probeArguments31(kind,runtime),Buffer.from((kind==="node"?process.version:npmVersion)+"\n")))])),binMaterialization:retain(normalization),commands:Object.fromEntries(commands.map(kind=>[kind,retain(record(kind,authority.commandArguments31(kind,npm,root),kind==="installed-runtime"?installed:kind==="dependency-bin-materialization"?normalization:undefined))])),audits:Object.fromEntries(authority.AUDITS.map(kind=>{const raw=Buffer.from(JSON.stringify(clean));return [kind,{report:retain(raw),command:retain(record("audit-"+kind,authority.auditArguments31(kind,npm),raw))}];})),emittedFiles:Object.fromEntries(["lib/index.js","lib/index.js.map"].map(name=>[name,retain(fs.readFileSync(path.join(root,"functions",name)))])),installedDependencies:retain(installed),installedFiles:Object.fromEntries(Object.entries(maps(root)).map(([kind,map])=>[kind,retain(map)]))};
  const snapshot={files:Object.fromEntries(Object.entries(sourceBytes).map(([name,raw])=>[name,{mode:"100644",oid:crypto.createHash("sha1").update(Buffer.from("blob "+raw.length+"\0")).update(raw).digest("hex")}]))},repository={readBlob:(commit,file)=>{assert.equal(commit,source.commit);assert.ok(Object.hasOwn(sourceBytes,file));return sourceBytes[file];}};
  const input={proof,source,snapshot,repository,evidenceDirectory:evidence,afterCi:"2026-01-02T01:00:00Z",beforeDecision:"2026-01-02T04:00:00Z"};return {input,retain,read:p=>JSON.parse(fs.readFileSync(path.join(evidence,p.file))),normalization};
}
test("schema3 actual runtime verifier joins complete root maps, producer, receipt and process chronology",()=>{const f=runtimeFixture(),result=authority.verifyRuntimeProof31(f.input);assert.equal(result.installedRuntimePathCount,1);assert.equal(result.emittedFileCount,2);assert.equal(Object.hasOwn(result,"deploymentAuthorized"),false);});
for(const [name,mutate,pattern] of [
  ["schema downgrade",f=>{f.input.proof.schemaVersion=1;delete f.input.proof.binMaterialization;},/runtime proof|runtime source/],
  ["root map omission",f=>delete f.input.proof.installedFiles.root,/installed file populations/],
  ["install after normalization",f=>{const r=f.read(f.input.proof.commands["root-install"]);r.completedAtUtc="2026-01-02T02:08:00Z";f.input.proof.commands["root-install"]=f.retain(r);},/precedes completed clean installs/],
  ["build before normalization",f=>{const r=f.read(f.input.proof.commands["functions-build"]);r.startedAtUtc="2026-01-02T02:07:00Z";f.input.proof.commands["functions-build"]=f.retain(r);},/precedes materialization/],
  ["audit before normalization",f=>{const r=f.read(f.input.proof.audits["cli-full"].command);r.startedAtUtc="2026-01-02T02:07:00Z";f.input.proof.audits["cli-full"].command=f.retain(r);},/audit precedes/],
  ["receipt not stdout",f=>{const r=f.read(f.input.proof.commands["dependency-bin-materialization"]);r.stdout=f.retain("other receipt");f.input.proof.commands["dependency-bin-materialization"]=f.retain(r);},/not original command stdout/],
])test("schema3 refuses "+name,()=>{const f=runtimeFixture();mutate(f);assert.throws(()=>authority.verifyRuntimeProof31(f.input),pattern);});
test("schema3 original-path replay retains command JSON with originals absent and extracted bytes regular",()=>{
  const f=runtimeFixture(),original=f.input.proof.buildRoot,runtimeRoot=path.dirname(f.input.proof.runtime.npmPackageRoot),proofBytes=Buffer.from(JSON.stringify(f.input.proof));
  put(original,".dart_tool/retained-runtime-proof.json",proofBytes);put(original,".dart_tool/test-owned.json",JSON.stringify({fixtureOnly:true,root:original}));put(runtimeRoot,"test-owned.json",JSON.stringify({fixtureOnly:true,root:runtimeRoot}));
  const rawMembers=[];function collect(root,prefix){for(const [name]of Object.entries(api.scan31(root).files)){const raw=fs.readFileSync(path.join(root,name));rawMembers.push({file:prefix+"/"+name,raw});}}
  collect(original,"build");collect(runtimeRoot,"runtime");
  const members=rawMembers.map(({file,raw})=>{const gzip=zlib.gzipSync(raw);return {path:file,bytes:raw.length,sha256:api.sha(raw),encoding:"gzip",compressedBytes:gzip.length,compressedSha256:api.sha(gzip),base64:gzip.toString("base64")};});
  const relocation={schemaVersion:1,roots:[{original,memberRoot:"build"},{original:runtimeRoot,memberRoot:"runtime"}],files:[]},inventory=Object.fromEntries(members.map(row=>[row.path,{bytes:row.bytes,sha256:row.sha256}])),source=f.input.source;
  const raw=Buffer.from(JSON.stringify({schemaVersion:2,documentType:"build31-private-business-evidence-bundle",encoding:transport.BUNDLE_ENCODING,source,members,relocation})),descriptor={source,bundleEncoding:transport.BUNDLE_ENCODING,expandedBytes:members.reduce((n,row)=>n+row.bytes,0),membersSha256:api.sha(api.canonical(inventory)),relocationSha256:api.sha(api.canonical(relocation)),custody:{provider:"gcs",bucket:transport.BUCKET,objectName:"release-custody/build-31/business-backend/"+source.commit+"/fixture/private-replay-bundle.json",generation:"1",bytes:raw.length,sha256:api.sha(raw)}};
  const destination=path.join(make("extraction-parent"),"extracted"),extracted=transport.extractVerifiedBundle31(raw,descriptor,destination,"business");
  // Only these freshly created, exclusively owned direct scratch children move.
  for(const root of [original,runtimeRoot]){assert.equal(fs.realpathSync(path.dirname(root)),scratch);assert.equal(fs.lstatSync(root).isSymbolicLink(),false);const retained=root+"-retained";assert.equal(fs.existsSync(retained),false);const before=api.scan31(root).files;fs.renameSync(root,retained);assert.deepEqual(api.scan31(retained).files,before);assert.equal(fs.existsSync(root),false);}
  const access=require("./backendRuntimeEvidenceAccess31.cjs"),node=f.input.proof.runtime.nodeExecutable,verifierFiles={[node.path]:node.sha256};
  const result=access.runRelocated31({privateBundleRoot:extracted.root,relocation,members:Object.entries(inventory).map(([file,b])=>({path:file,...b})),evidenceDirectory:f.input.evidenceDirectory,verifierFiles},()=>{
    const retained=access.fs.readFileSync(path.join(original,".dart_tool/retained-runtime-proof.json"));assert.deepEqual(retained,proofBytes);
    return authority.verifyRuntimeProof31({...f.input,proof:JSON.parse(retained)});
  });assert.equal(result.installedRuntimePathCount,1);assert.equal(result.buildRoot,original);assert.equal(fs.existsSync(original),false);assert.deepEqual(fs.readFileSync(path.join(extracted.root,"build/.dart_tool/retained-runtime-proof.json")),proofBytes);
  for(const member of rawMembers){const file=path.join(destination,member.file);assert.equal(fs.lstatSync(file).isFile(),true);assert.equal(fs.lstatSync(file).isSymbolicLink(),false);if(process.platform!=="win32")assert.equal(fs.statSync(file).mode&0o777,0o600);}
  if(process.platform==="win32") {
    const before=api.scan31(path.join(extracted.root,"build")).files;
    fs.mkdirSync(path.join(extracted.root,"build/node_modules/.bin/NoDe.ExE"),{recursive:true});
    assert.deepEqual(api.scan31(path.join(extracted.root,"build")).files,before);
    assert.throws(()=>access.runRelocated31({privateBundleRoot:extracted.root,relocation,members:Object.entries(inventory).map(([file,b])=>({path:file,...b})),evidenceDirectory:f.input.evidenceDirectory,verifierFiles},()=>authority.verifyRuntimeProof31(f.input)),/Windows npm shim interpreter shadow/);
    assert.equal(fs.existsSync(original),false);assert.deepEqual(fs.readFileSync(path.join(extracted.root,"build/.dart_tool/retained-runtime-proof.json")),proofBytes);
  }
});

test("complete finite Node shebang rejects unsupported flags hidden beyond the old truncation",()=>{
  for(const header of ["#!/usr/bin/env node\n","#!/usr/bin/node\r\n","#!/usr/local/bin/node\n"])assert.equal(api.verifyNodeShebang31(Buffer.from(header+"// body\n")),true);
  assert.throws(()=>api.verifyNodeShebang31(Buffer.from("#!/usr/bin/env node"+" ".repeat(300)+"--require other\n")),/complete bin shebang/);
  assert.throws(()=>api.verifyNodeShebang31(Buffer.from("#!/usr/bin/env node --require other\n")),/unsupported bin interpreter/);
  assert.throws(()=>api.verifyNodeShebang31(Buffer.from("#!/usr/bin/env node")),/lacks newline/);
  assert.throws(()=>api.verifyNodeShebang31(Buffer.from("#!/usr/bin/env node\u00a0\n")),/unsupported bin interpreter/);
});

function platformBranch(platform) {
  const filename=require.resolve("./business31NpmBinMaterialization.cjs"),moduleValue={exports:{}};
  // Exercises only the platform branch on local inert fixtures. The actual
  // native clean-install test remains the Linux/Windows execution qualification.
  new Function("require","module","exports","__filename","__dirname","process",fs.readFileSync(filename,"utf8"))
    (require,moduleValue,moduleValue.exports,filename,path.dirname(filename),{...process,platform});
  return moduleValue.exports;
}
function elfHeader() {
  const raw=Buffer.alloc(64);Buffer.from([0x7f,0x45,0x4c,0x46,2,1,1,0]).copy(raw);raw.writeUInt16LE(3,16);raw.writeUInt16LE(62,18);raw.writeUInt32LE(1,20);raw.writeUInt16LE(64,52);return raw;
}
function syntheticPosixReceipt(root) {
  // Header-only fixture is never executed or described as an installed Node.
  const executable=put(make("synthetic-executable"),"node",elfHeader()),nodeExecutable={path:executable,sha256:api.sha(fs.readFileSync(executable))},fileMaps=maps(root);
  const receipt={schemaVersion:1,documentType:"build31-npm-bin-materialization",producer:{file:api.SELF,sha256:api.sha(fs.readFileSync(require.resolve("./business31NpmBinMaterialization.cjs")))},nodeExecutable,platform:"linux",roots:{}};
  for(const [kind,directory] of Object.entries(api.ROOTS)){const map=fileMaps[kind],digest=api.sha(api.canonical(map));receipt.roots[kind]={directory,beforeFilesSha256:digest,afterFilesSha256:digest,fileCount:Object.keys(map).length,aliases:[]};}
  return {receipt,buildRoot:root,nodeExecutable,producerSha256:receipt.producer.sha256,fileMaps};
}
test("POSIX preparation refuses regular root and nested bin entries before changing any bytes",()=>{
  for(const name of ["node_modules/.bin/unowned","functions/node_modules/outer/node_modules/.bin/unowned","tooling/firebase-cli/node_modules/.bin/deep/unowned"]){
    const root=regularTree();put(root,name,"#!/bin/sh\nexit 0\n",0o755);const before=maps(root),linux=platformBranch("linux");
    assert.throws(()=>linux.materializeNpmBins31({buildRoot:root}),/POSIX npm .bin preparation requires original package aliases/);assert.deepEqual(maps(root),before);
  }
});
// Canonical Windows triplet regressions below replace the old arbitrary-shim acceptance case.
test("POSIX receipt refuses arbitrary regular bin entries even with complete recomputed maps",()=>{
  for(const name of ["node_modules/.bin/unowned","functions/node_modules/outer/node_modules/.bin/unowned"]){const root=regularTree();put(root,name,"#!/bin/sh\nexit 0\n");const options=syntheticPosixReceipt(root);assert.throws(()=>api.verifyNpmBinMaterialization31(options),/unrecorded POSIX .bin launcher/);}
});
test("receipt cannot change platform or executable bytes to evade POSIX alias coverage",()=>{
  const root=regularTree();put(root,"node_modules/.bin/unowned","#!/bin/sh\nexit 0\n");const options=syntheticPosixReceipt(root);
  for(const platform of ["win32","darwin"]){const receipt=structuredClone(options.receipt);receipt.platform=platform;assert.throws(()=>api.verifyNpmBinMaterialization31({...options,receipt}),/platform differs from bound Node executable/);}
  fs.appendFileSync(options.nodeExecutable.path,"tamper");assert.throws(()=>api.verifyNpmBinMaterialization31(options),/Node bytes differ/);
});
test("POSIX replay retains regular launchers only with complete package-owned alias evidence",()=>{
  const root=regularTree(),directory=path.join(root,api.ROOTS.root),options=syntheticPosixReceipt(root),file=".bin/probe",target="probe/bin/run.js",packageJson="probe/package.json",linkTarget="../probe/bin/run.js";
  const manifest=Buffer.from('{"name":"probe","version":"1.0.0","bin":{"probe":"bin/run.js"}}'),targetBytes=Buffer.from("#!/usr/bin/env node\n// retained fixture, never executed\n");
  put(directory,packageJson,manifest);put(directory,target,targetBytes,0o600);
  const launcher=api.launcherBytes31(options.nodeExecutable.path,file,target);put(directory,file,launcher,0o600);
  // Recorded original0755 modes differ deliberately from regular0600 replay
  // bytes. This is semantic fixture evidence, not a POSIX execution claim.
  const alias={file,linkTarget,target,packageJson,packageJsonSha256:api.sha(manifest),binName:"probe",declaredBin:"bin/run.js",targetSha256:api.sha(targetBytes),targetMode:0o755,shimSha256:api.sha(launcher),shimMode:0o755};
  options.fileMaps=maps(root);const after=options.fileMaps.root,before={...after,[file]:api.sha(Buffer.from(linkTarget))};
  options.receipt.roots.root={directory:api.ROOTS.root,beforeFilesSha256:api.sha(api.canonical(before)),afterFilesSha256:api.sha(api.canonical(after)),fileCount:Object.keys(after).length,aliases:[alias]};
  assert.equal(api.verifyNpmBinMaterialization31(options).recordedMaterializationVerified,true);
  const omitted=structuredClone(options.receipt);omitted.roots.root.aliases=[];omitted.roots.root.beforeFilesSha256=omitted.roots.root.afterFilesSha256;
  assert.throws(()=>api.verifyNpmBinMaterialization31({...options,receipt:omitted}),/unrecorded POSIX .bin launcher/);
  for(const key of ["targetMode","shimMode"]){const bad=structuredClone(options.receipt);bad.roots.root.aliases[0][key]=0o600;assert.throws(()=>api.verifyNpmBinMaterialization31({...options,receipt:bad}),/recorded alias mode/);}
});
test("format classifier binds actual host Node and bounded supported synthetic executable headers",()=>{
  assert.equal(api.executablePlatform31(fs.readFileSync(process.execPath)),process.platform);assert.equal(api.executablePlatform31(elfHeader()),"linux");
  const pe=Buffer.alloc(256);pe.write("MZ");pe.writeUInt32LE(64,0x3c);pe.writeUInt32LE(0x4550,64);pe.writeUInt16LE(0x8664,68);pe.writeUInt16LE(1,70);pe.writeUInt16LE(112,84);pe.writeUInt16LE(2,86);pe.writeUInt16LE(0x20b,88);assert.equal(api.executablePlatform31(pe),"win32");
  const mach=Buffer.alloc(40);mach.writeUInt32LE(0xfeedfacf,0);mach.writeUInt32LE(2,12);mach.writeUInt32LE(1,16);mach.writeUInt32LE(8,20);assert.equal(api.executablePlatform31(mach),"darwin");
  for(const raw of [Buffer.from("MZ"),Buffer.from("#!/bin/sh\n"),Buffer.from(pe),Buffer.from(elfHeader()),Buffer.from(mach)]){
    if(raw.length===256)raw.writeUInt32LE(0xffffffff,0x3c);else if(raw.length===64)raw.writeUInt16LE(1,16);else if(raw.length===40)raw.writeUInt32LE(0xffffffff,20);
    assert.throws(()=>api.executablePlatform31(raw),/executable/);
  }
});

const retainedWindowsNpmTemplates={"":"#!/bin/sh\nbasedir=$(dirname \"$(echo \"$0\" | sed -e 's,\\\\,/,g')\")\n\ncase `uname` in\n    *CYGWIN*|*MINGW*|*MSYS*)\n        if command -v cygpath > /dev/null 2>&1; then\n            basedir=`cygpath -w \"$basedir\"`\n        fi\n    ;;\nesac\n\nif [ -x \"$basedir/node\" ]; then\n  exec \"$basedir/node\"  \"$basedir/__BUILD31_POSIX_TARGET__\" \"$@\"\nelse \n  exec node  \"$basedir/__BUILD31_POSIX_TARGET__\" \"$@\"\nfi\n",".cmd":"@ECHO off\r\nGOTO start\r\n:find_dp0\r\nSET dp0=%~dp0\r\nEXIT /b\r\n:start\r\nSETLOCAL\r\nCALL :find_dp0\r\n\r\nIF EXIST \"%dp0%\\node.exe\" (\r\n  SET \"_prog=%dp0%\\node.exe\"\r\n) ELSE (\r\n  SET \"_prog=node\"\r\n  SET PATHEXT=%PATHEXT:;.JS;=;%\r\n)\r\n\r\nendLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & \"%_prog%\"  \"%dp0%\\__BUILD31_WIN_TARGET__\" %*\r\n",".ps1":"#!/usr/bin/env pwsh\n$basedir=Split-Path $MyInvocation.MyCommand.Definition -Parent\n\n$exe=\"\"\nif ($PSVersionTable.PSVersion -lt \"6.0\" -or $IsWindows) {\n  # Fix case when both the Windows and Linux builds of Node\n  # are installed in the same directory\n  $exe=\".exe\"\n}\n$ret=0\nif (Test-Path \"$basedir/node$exe\") {\n  # Support pipeline input\n  if ($MyInvocation.ExpectingInput) {\n    $input | & \"$basedir/node$exe\"  \"$basedir/__BUILD31_POSIX_TARGET__\" $args\n  } else {\n    & \"$basedir/node$exe\"  \"$basedir/__BUILD31_POSIX_TARGET__\" $args\n  }\n  $ret=$LASTEXITCODE\n} else {\n  # Support pipeline input\n  if ($MyInvocation.ExpectingInput) {\n    $input | & \"node$exe\"  \"$basedir/__BUILD31_POSIX_TARGET__\" $args\n  } else {\n    & \"node$exe\"  \"$basedir/__BUILD31_POSIX_TARGET__\" $args\n  }\n  $ret=$LASTEXITCODE\n}\nexit $ret\n"};

function windowsPackage(root,{prefix="node_modules/",packageName="probe",bin="probe",target="bin/run.js"}={}) {
  const packageRoot=prefix+packageName,relative="../"+packageName+"/"+target;
  put(root,packageRoot+"/package.json",JSON.stringify({name:packageName,version:"1.0.0",bin:{[bin]:target}}));
  put(root,packageRoot+"/"+target,"#!/usr/bin/env node\n// inert package-owned target; never executed\n");
  for(const [extension,template]of Object.entries(retainedWindowsNpmTemplates))
    put(root,prefix+".bin/"+bin+extension,template.replaceAll("__BUILD31_POSIX_TARGET__",relative).replaceAll("__BUILD31_WIN_TARGET__",relative.replaceAll("/","\\")));
  return {file:prefix+".bin/"+bin,packageRoot,target:packageRoot+"/"+target};
}
function verifyWindowsFixture(root,receipt) {
  if(process.platform==="win32")return verify(root,receipt);
  // Off Windows, exercise receipt semantics with an inert PE header; this is
  // never executed and is not an authenticated Windows/Node runtime claim.
  const pe=Buffer.alloc(256);pe.write("MZ");pe.writeUInt32LE(64,0x3c);pe.writeUInt32LE(0x4550,64);pe.writeUInt16LE(0x8664,68);pe.writeUInt16LE(1,70);pe.writeUInt16LE(112,84);pe.writeUInt16LE(2,86);pe.writeUInt16LE(0x20b,88);
  const executable=put(make("windows-header-only"),"node.exe",pe),nodeExecutable={path:executable,sha256:api.sha(pe)},copy=structuredClone(receipt);copy.nodeExecutable=nodeExecutable;
  return api.verifyNpmBinMaterialization31({receipt:copy,buildRoot:root,nodeExecutable,producerSha256:api.sha(fs.readFileSync(require.resolve("./business31NpmBinMaterialization.cjs"))),fileMaps:maps(root)});
}
test("Windows preparation refuses tampered package-owned cmd shim",()=>{
  const root=regularTree(),row=windowsPackage(root);fs.appendFileSync(path.join(root,row.file+".cmd"),"\r\necho arbitrary-command\r\n");
  const before=maps(root);assert.throws(()=>platformBranch("win32").materializeNpmBins31({buildRoot:root}),/Windows npm shim/);assert.deepEqual(maps(root),before);
});
test("Windows package shims retain exact canonical triplets for root nested and scoped bins",()=>{
  const root=regularTree();windowsPackage(root);windowsPackage(root,{prefix:"functions/node_modules/outer/node_modules/",packageName:"@scope/pkg",bin:"scoped"});windowsPackage(root,{prefix:"tooling/firebase-cli/node_modules/",packageName:"cli",bin:"tool.cmd"});
  const before=maps(root),receipt=platformBranch("win32").materializeNpmBins31({buildRoot:root});assert.deepEqual(maps(root),before);assert.equal(receipt.roots.root.aliases.length,0);
  assert.equal(verifyWindowsFixture(root,receipt).recordedMaterializationVerified,true);
});
test("Windows preparation refuses every noncanonical shim branch and incomplete triplet",()=>{
  for(const [extension,change]of [
    ["",b=>b.replace('exec node  ','exec other  ')],["",b=>b.replace('exec "$basedir/node"','exec "$basedir/other"')],
    [".cmd",b=>b.replace('SET "_prog=node"','SET "_prog=other"')],[".cmd",b=>b.replace('node.exe','other.exe')],
    [".ps1",b=>b.replace('"node$exe"','"other$exe"')],[".ps1",b=>b.replace('$input | &','$input | Invoke-Expression')],
    [".cmd",b=>b.replace('..\\probe\\bin\\run.js','..\\probe\\bin\\other.js')],
    [".ps1",b=>b+'\nWrite-Output injected\n'],["",()=>null],[".cmd",()=>null],[".ps1",()=>null]
  ]){
    const root=regularTree(),row=windowsPackage(root),file=path.join(root,row.file+extension),before=fs.readFileSync(file,"utf8"),after=change(before);
    if(after===null)fs.unlinkSync(file);else{assert.notEqual(after,before);fs.writeFileSync(file,after);}
    const original=maps(root);assert.throws(()=>platformBranch("win32").materializeNpmBins31({buildRoot:root}),/Windows npm shim/);assert.deepEqual(maps(root),original);
  }
});
test("Windows preparation refuses undeclared targets extra entries and interpreter shadows",()=>{
  for(const arrange of [
    (root,row)=>put(root,row.packageRoot+"/package.json",JSON.stringify({name:"probe",bin:{other:"bin/run.js"}})),
    (root,row)=>put(root,row.packageRoot+"/package.json",JSON.stringify({name:"probe",bin:{probe:"bin/other.js"}})),
    (root,row)=>put(root,row.target,"#!/usr/bin/env node --require injected\n"),
    root=>put(root,"node_modules/.bin/unowned.cmd","@echo injected\n"),
    root=>put(root,"node_modules/.bin/deep/probe.cmd","@echo injected\n"),
    root=>put(root,"node_modules/.bin/node.exe","inert executable shadow, never executed"),
    root=>put(root,"node_modules/.bin/Node.CMD","inert interpreter shadow, never executed"),
    (root,row)=>{for(const extension of ["",".cmd",".ps1"]){const file=path.join(root,row.file+extension);fs.writeFileSync(file,fs.readFileSync(file,"utf8").replaceAll("../probe/bin/run.js","../../outside/run.js").replaceAll("..\\probe\\bin\\run.js","..\\..\\outside\\run.js"));}},
    root=>windowsPackage(root,{packageName:"node-shadow",bin:"node"})
  ]){const root=regularTree(),row=windowsPackage(root);arrange(root,row);const before=maps(root);assert.throws(()=>platformBranch("win32").materializeNpmBins31({buildRoot:root}),/Windows npm shim/);assert.deepEqual(maps(root),before);}
});
test("Windows receipt rejects rehashed arbitrary shims and lost package ownership",()=>{
  for(const arrange of [
    (root,row)=>fs.appendFileSync(path.join(root,row.file+".cmd"),"\r\necho injected\r\n"),
    (root,row)=>put(root,row.packageRoot+"/package.json",JSON.stringify({name:"probe",bin:{different:"bin/run.js"}})),
    root=>put(root,"node_modules/.bin/orphan.ps1","Write-Output injected\n")
  ]){
    const root=regularTree(),row=windowsPackage(root),receipt=platformBranch("win32").materializeNpmBins31({buildRoot:root});arrange(root,row);
    const current=maps(root);for(const [kind,map]of Object.entries(current)){const digest=api.sha(api.canonical(map));receipt.roots[kind].beforeFilesSha256=digest;receipt.roots[kind].afterFilesSha256=digest;receipt.roots[kind].fileCount=Object.keys(map).length;}
    assert.throws(()=>verifyWindowsFixture(root,receipt),/Windows npm shim/);
  }
});

test("Windows casing cannot bypass preparation or retained receipt shim validation",()=>{
  for(const file of ["node_modules/.BIN/unowned.cmd","functions/node_modules/outer/NODE_MODULES/.bin/unowned.cmd","functions/node_modules/outer/node_modules/.BIN/unowned.cmd","tooling/firebase-cli/node_modules/outer/Node_Modules/.bIn/unowned.ps1"]){
    const root=regularTree(),receipt=platformBranch("win32").materializeNpmBins31({buildRoot:root});put(root,file,"inert arbitrary shim, never executed\n");const before=maps(root);
    assert.throws(()=>platformBranch("win32").materializeNpmBins31({buildRoot:root}),/Windows npm shim/);assert.deepEqual(maps(root),before);
    for(const [kind,map]of Object.entries(before)){const digest=api.sha(api.canonical(map));receipt.roots[kind].beforeFilesSha256=digest;receipt.roots[kind].afterFilesSha256=digest;receipt.roots[kind].fileCount=Object.keys(map).length;}
    assert.throws(()=>verifyWindowsFixture(root,receipt),/Windows npm shim/);
  }
});

for(const [label,mutate,pattern] of [
  ["standalone build later than both tests",f=>{const k="functions-build",r=f.read(f.input.proof.commands[k]);r.startedAtUtc="2026-01-02T02:16:00Z";r.completedAtUtc="2026-01-02T02:17:00Z";f.input.proof.commands[k]=f.retain(r);},/tests must follow/],
  ["standalone build overlaps host test",f=>{const k="functions-build",r=f.read(f.input.proof.commands[k]);r.completedAtUtc="2026-01-02T02:12:00Z";f.input.proof.commands[k]=f.retain(r);},/tests must follow/],
  ["host tested different output even with self-consistent evidence hashes",f=>{const k="functions-host-tests",r=f.read(f.input.proof.commands[k]),map=f.read(f.input.proof.testedEmittedFiles[k]);map["lib/index.js"]="A".repeat(64);f.input.proof.testedEmittedFiles[k]=f.retain(map);r.emittedFilesAfterSha256=f.input.proof.testedEmittedFiles[k].sha256;f.input.proof.commands[k]=f.retain(r);},/final emitted bytes/],
  ["schema2 runtime downgrade",f=>{f.input.proof.schemaVersion=2;},/runtime source/],
])test("schema3 full runtime refuses "+label,()=>{const f=runtimeFixture();mutate(f);assert.throws(()=>authority.verifyRuntimeProof31(f.input),pattern);});

for(const [label,mutate,pattern] of [
  ["self-hashed replacement npm entry",f=>{const p=f.input.proof.runtime.npmCliFile;fs.appendFileSync(p.path,"// tampered\n");p.sha256=api.sha(fs.readFileSync(p.path));},/complete npm implementation/],
  ["self-hashed replacement Node executable",f=>{const runtime=f.input.proof.runtime,file=path.join(make("fake-node"),"node");fs.writeFileSync(file,"fake executable");runtime.nodeExecutable={path:file,sha256:api.sha(fs.readFileSync(file))};},/Node differs from independently approved/],
  ["proof-selected unknown profile",f=>f.input.proof.runtime.toolchainProfileId="not-approved",/no independently approved/],
  ["wrong recorded Node version despite approved bytes",f=>{const p=f.input.proof.toolchainProbes,r=f.read(p.node);r.stdout=f.retain("v99.0.0\n");p.node=f.retain(r);},/probe stdout/],
  ["wrong recorded npm version despite approved bytes",f=>{const p=f.input.proof.toolchainProbes,r=f.read(p.npm);r.stdout=f.retain("99.0.0\n");p.npm=f.retain(r);},/probe stdout/],
  ["install before version probes finish",f=>{const k="root-install",r=f.read(f.input.proof.commands[k]);r.startedAtUtc="2026-01-02T02:02:00Z";f.input.proof.commands[k]=f.retain(r);},/probe|install/],
])test("schema3 full runtime refuses "+label,()=>{const f=runtimeFixture();mutate(f);assert.throws(()=>authority.verifyRuntimeProof31(f.input),pattern);});


// Metadata-only shadows are absent from ordinary file maps. Retain the map from
// before insertion so receipt refusal cannot accidentally depend on caller rescans.
function windowsShadowOptions(root,receipt,fileMaps) {
  let nodeExecutable=receipt.nodeExecutable;
  if(process.platform!=="win32") {
    const pe=Buffer.alloc(256);pe.write("MZ");pe.writeUInt32LE(64,0x3c);pe.writeUInt32LE(0x4550,64);pe.writeUInt16LE(0x8664,68);pe.writeUInt16LE(1,70);pe.writeUInt16LE(112,84);pe.writeUInt16LE(2,86);pe.writeUInt16LE(0x20b,88);
    const executable=put(make("shadow-pe-header"),"node.exe",pe);nodeExecutable={path:executable,sha256:api.sha(pe)};receipt={...receipt,nodeExecutable};
  }
  return {receipt,buildRoot:root,nodeExecutable,producerSha256:api.sha(fs.readFileSync(require.resolve("./business31NpmBinMaterialization.cjs"))),fileMaps};
}
const shadowPrefixes=["node_modules/","functions/node_modules/","tooling/firebase-cli/node_modules/","functions/node_modules/outer/node_modules/"];
const shadowNames=["node",..."COM EXE BAT CMD VBS VBE JS JSE WSF WSH MSC ps1".split(" ").map(extension=>"NoDe."+extension)];
const windowsShadowApi=process.platform==="win32"?api:platformBranch("win32");
test("Windows interpreter occupancy preparation rejects root nested and case-varied empty directories",()=>{
  for(const prefix of shadowPrefixes)for(const name of shadowNames) {
    const root=regularTree();windowsPackage(root,{prefix});const before=maps(root);fs.mkdirSync(path.join(root,prefix,".bin",name));
    const install=path.join(root,prefix.startsWith("functions/")?api.ROOTS.functions:prefix.startsWith("tooling/")?api.ROOTS.cli:api.ROOTS.root);
    assert.throws(()=>windowsShadowApi.scan31(install,true),/Windows npm shim interpreter shadow/);
    assert.throws(()=>windowsShadowApi.materializeNpmBins31({buildRoot:root}),/Windows npm shim interpreter shadow/);assert.deepEqual(maps(root),before);
  }
});
test("Windows interpreter occupancy receipt rejects later empty directories with original maps on any replay host",()=>{
  for(const prefix of shadowPrefixes)for(const name of shadowNames) {
    const root=regularTree();windowsPackage(root,{prefix});const receipt=windowsShadowApi.materializeNpmBins31({buildRoot:root}),fileMaps=maps(root),options=windowsShadowOptions(root,receipt,fileMaps);
    assert.equal(api.verifyNpmBinMaterialization31(options).recordedMaterializationVerified,true);
    fs.mkdirSync(path.join(root,prefix,".bin",name));assert.deepEqual(maps(root),fileMaps);
    assert.throws(()=>api.verifyNpmBinMaterialization31(options),/Windows npm shim interpreter shadow/);
    assert.throws(()=>platformBranch("linux").verifyNpmBinMaterialization31(options),/Windows npm shim interpreter shadow/);
  }
});
test("Windows interpreter occupancy refuses file nonempty directory and junction without following redirects",()=>{
  for(const prefix of [shadowPrefixes[0],shadowPrefixes[3]])for(const type of ["file","nonempty-directory","junction"]) {
    const root=regularTree();windowsPackage(root,{prefix});const receipt=windowsShadowApi.materializeNpmBins31({buildRoot:root}),options=windowsShadowOptions(root,receipt,maps(root)),shadow=path.join(root,prefix,".bin/NoDe.ExE");
    let target;
    if(type==="file")fs.writeFileSync(shadow,"inert shadow; never executed\n");
    else if(type==="nonempty-directory"){fs.mkdirSync(shadow);fs.writeFileSync(path.join(shadow,"retained.txt"),"unchanged\n");}
    else {target=make("shadow-junction-target");put(target,"retained.txt","unchanged\n");fs.symlinkSync(target,shadow,process.platform==="win32"?"junction":"dir");}
    assert.throws(()=>windowsShadowApi.materializeNpmBins31({buildRoot:root}),/Windows npm shim interpreter shadow/);
    assert.throws(()=>api.verifyNpmBinMaterialization31(options),/Windows npm shim interpreter shadow/);
    if(target){assert.equal(fs.lstatSync(shadow).isSymbolicLink(),true);assert.equal(fs.readFileSync(path.join(target,"retained.txt"),"utf8"),"unchanged\n");}
  }
});
test("Windows interpreter occupancy rejects shadows in otherwise empty bin directories including alternate casing",()=>{
  for(const file of ["node_modules/.BIN/NoDe","functions/node_modules/outer/NODE_MODULES/.bin/NODE.EXE","tooling/firebase-cli/node_modules/outer/node_modules/.bIn/node.cmd"]) {
    const root=regularTree(),receipt=windowsShadowApi.materializeNpmBins31({buildRoot:root}),fileMaps=maps(root),options=windowsShadowOptions(root,receipt,fileMaps);
    fs.mkdirSync(path.join(root,file),{recursive:true});assert.deepEqual(maps(root),fileMaps);
    assert.throws(()=>windowsShadowApi.materializeNpmBins31({buildRoot:root}),/Windows npm shim interpreter shadow/);
    assert.throws(()=>api.verifyNpmBinMaterialization31(options),/Windows npm shim interpreter shadow/);
  }
});
test("Windows interpreter occupancy preserves no-shadow and unrelated empty package-directory controls",()=>{
  const root=regularTree();for(const prefix of shadowPrefixes)windowsPackage(root,{prefix});windowsPackage(root,{packageName:"node-gyp",bin:"node-gyp"});
  const receipt=windowsShadowApi.materializeNpmBins31({buildRoot:root}),fileMaps=maps(root),options=windowsShadowOptions(root,receipt,fileMaps);
  for(const file of ["node_modules/probe/node","functions/node_modules/outer/node_modules/probe/Node.Exe","tooling/firebase-cli/node_modules/.bin/node-other"])fs.mkdirSync(path.join(root,file),{recursive:true});
  assert.deepEqual(maps(root),fileMaps);assert.deepEqual(windowsShadowApi.materializeNpmBins31({buildRoot:root}),receipt);
  assert.equal(api.verifyNpmBinMaterialization31(options).recordedMaterializationVerified,true);
  assert.equal(platformBranch("linux").verifyNpmBinMaterialization31(options).recordedMaterializationVerified,true);
});

test("Windows interpreter occupancy rejects canonical package triplets for default interpreter extensions",()=>{
  const acceptedPreparation=[],acceptedDescription=[];
  for(const name of shadowNames) {
    const root=regularTree(),row=windowsPackage(root,{packageName:"interpreter-shadow",bin:name});
    try{windowsShadowApi.materializeNpmBins31({buildRoot:root});acceptedPreparation.push(name);}catch(error){assert.match(String(error),/Windows npm shim interpreter shadow/);}
    try{api.windowsShimDescription31(path.join(root,"node_modules"),".bin/"+name);acceptedDescription.push(name);}catch(error){assert.match(String(error),/Windows npm shim interpreter shadow/);}
  }
  console.log("canonical interpreter extension refusals",JSON.stringify({nativePlatform:process.platform,acceptedPreparation,acceptedDescription}));
  assert.deepEqual(acceptedPreparation,[]);assert.deepEqual(acceptedDescription,[]);
});
