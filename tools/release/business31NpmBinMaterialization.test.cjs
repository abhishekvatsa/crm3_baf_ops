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
  put(root,"node_modules/.bin/unrecorded",api.MARKER+"exit 0\n");const changed=structuredClone(good),map=maps(root).root;changed.roots.root.afterFilesSha256=api.sha(api.canonical(map));changed.roots.root.beforeFilesSha256=changed.roots.root.afterFilesSha256;changed.roots.root.fileCount=Object.keys(map).length;assert.throws(()=>verify(root,changed),/unrecorded materialized|unrecorded POSIX/);
});
function runtimeFixture(){
  const root=make("schema2"),evidence=path.join(root,".dart_tool/evidence"),runtimeRoot=make("runtime"),source={commit:"a".repeat(40),tree:"b".repeat(40),functionsTree:"c".repeat(40)},sourceBytes={};roots(root);fs.mkdirSync(evidence,{recursive:true});
  const sourceFile=(name,value)=>{const raw=Buffer.isBuffer(value)?value:Buffer.from(typeof value==="string"?value:JSON.stringify(value));sourceBytes[name]=raw;put(root,name,raw);};
  const config={compilerOptions:{module:"commonjs",noImplicitReturns:true,noUnusedLocals:false,outDir:"lib",sourceMap:true,strict:true,target:"es2022"},compileOnSave:true,include:["src"]};
  const manifest={name:"fixture-functions",version:"1.0.0",dependencies:{"@grpc/grpc-js":"1.14.5"}},pkg={name:"@grpc/grpc-js",version:"1.14.5"},lock={packages:{"":manifest,"node_modules/@grpc/grpc-js":pkg}};
  sourceFile(api.SELF,fs.readFileSync(require.resolve("./business31NpmBinMaterialization.cjs")));sourceFile("release/production-release-policy.json",{toolchain:{nodeVersion:process.version}});sourceFile("functions/package.json",manifest);sourceFile("functions/package-lock.json",lock);sourceFile("functions/tsconfig.json",config);sourceFile("functions/src/index.ts","export const value = 1;\n");
  put(root,"node_modules/probe/package.json",'{"name":"probe","version":"1.0.0"}');put(root,"functions/node_modules/@grpc/grpc-js/package.json",JSON.stringify(pkg));put(root,"tooling/firebase-cli/node_modules/firebase-tools/package.json",'{"name":"firebase-tools","version":"15.22.4"}');const cli=put(root,"tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js","// inert fixture CLI\n");
  put(root,"functions/lib/index.js","exports.value=1;\n");put(root,"functions/lib/index.js.map","{}\n");const npm=put(runtimeRoot,"npm-cli.js","// inert synthetic process record target; never executed\n"),runtime={nodeVersion:process.version,firebaseCliVersion:"15.22.4",nodeExecutable:binding(),npmCliFile:{path:npm,sha256:api.sha(fs.readFileSync(npm))},cliEntrypoint:{path:cli,sha256:api.sha(fs.readFileSync(cli))}};
  let id=0;const retain=value=>{const raw=Buffer.isBuffer(value)?value:Buffer.from(typeof value==="string"?value:JSON.stringify(value)),file="original-"+(++id)+".json";put(evidence,file,raw);return {file,bytes:raw.length,sha256:api.sha(raw)};};
  if(process.platform!=="win32")packageFiles(path.join(root,api.ROOTS.root),"","runtime-bin","runtime-bin");
  const normalization=Buffer.from(JSON.stringify(api.materializeNpmBins31({buildRoot:root}))+"\n"),installed=Buffer.from(JSON.stringify({name:manifest.name,path:path.join(root,"functions"),dependencies:{"@grpc/grpc-js":{version:"1.14.5",path:path.join(root,"functions/node_modules/@grpc/grpc-js")}}}));
  const time=n=>"2026-01-02T02:"+String(n).padStart(2,"0")+":00Z";
  const record=(kind,argv,stdout)=>{const minute=kind.endsWith("-install")?5:kind==="dependency-bin-materialization"?7:kind.startsWith("audit-")?15:9;return {schemaVersion:1,documentType:"build31-business-original-process",kind,sourceBefore:source,sourceAfter:source,executable:runtime.nodeExecutable.path,executableSha256:runtime.nodeExecutable.sha256,argv,cwd:root,startedAtUtc:time(minute),completedAtUtc:time(minute+1),exitCode:0,signal:null,error:null,stdout:retain(stdout??"synthetic original stdout"),stderr:retain("")};};
  const clean={auditReportVersion:2,vulnerabilities:{},metadata:{vulnerabilities:{info:0,low:0,moderate:0,high:0,critical:0,total:0}}},commands=[...authority.COMMANDS,"dependency-bin-materialization"];
  const proof={schemaVersion:2,documentType:"build31-business-runtime-proof",profile:authority.PROFILE,source,startedAtUtc:time(0),completedAtUtc:time(30),buildRoot:root,runtime,binMaterialization:retain(normalization),commands:Object.fromEntries(commands.map(kind=>[kind,retain(record(kind,authority.commandArguments31(kind,npm,root),kind==="installed-runtime"?installed:kind==="dependency-bin-materialization"?normalization:undefined))])),audits:Object.fromEntries(authority.AUDITS.map(kind=>{const raw=Buffer.from(JSON.stringify(clean));return [kind,{report:retain(raw),command:retain(record("audit-"+kind,authority.auditArguments31(kind,npm),raw))}];})),emittedFiles:Object.fromEntries(["lib/index.js","lib/index.js.map"].map(name=>[name,retain(fs.readFileSync(path.join(root,"functions",name)))])),installedDependencies:retain(installed),installedFiles:Object.fromEntries(Object.entries(maps(root)).map(([kind,map])=>[kind,retain(map)]))};
  const snapshot={files:Object.fromEntries(Object.entries(sourceBytes).map(([name,raw])=>[name,{mode:"100644",oid:crypto.createHash("sha1").update(Buffer.from("blob "+raw.length+"\0")).update(raw).digest("hex")}]))},repository={readBlob:(commit,file)=>{assert.equal(commit,source.commit);assert.ok(Object.hasOwn(sourceBytes,file));return sourceBytes[file];}};
  const input={proof,source,snapshot,repository,evidenceDirectory:evidence,afterCi:"2026-01-02T01:00:00Z",beforeDecision:"2026-01-02T04:00:00Z"};return {input,retain,read:p=>JSON.parse(fs.readFileSync(path.join(evidence,p.file))),normalization};
}
test("schema2 actual runtime verifier joins complete root maps, producer, receipt and process chronology",()=>{const f=runtimeFixture(),result=authority.verifyRuntimeProof31(f.input);assert.equal(result.installedRuntimePathCount,1);assert.equal(result.emittedFileCount,2);assert.equal(Object.hasOwn(result,"deploymentAuthorized"),false);});
for(const [name,mutate,pattern] of [
  ["schema downgrade",f=>{f.input.proof.schemaVersion=1;delete f.input.proof.binMaterialization;},/runtime proof|runtime source/],
  ["root map omission",f=>delete f.input.proof.installedFiles.root,/installed file populations/],
  ["install after normalization",f=>{const r=f.read(f.input.proof.commands["root-install"]);r.completedAtUtc="2026-01-02T02:08:00Z";f.input.proof.commands["root-install"]=f.retain(r);},/precedes completed clean installs/],
  ["build before normalization",f=>{const r=f.read(f.input.proof.commands["functions-build"]);r.startedAtUtc="2026-01-02T02:07:00Z";f.input.proof.commands["functions-build"]=f.retain(r);},/precedes materialization/],
  ["audit before normalization",f=>{const r=f.read(f.input.proof.audits["cli-full"].command);r.startedAtUtc="2026-01-02T02:07:00Z";f.input.proof.audits["cli-full"].command=f.retain(r);},/audit precedes/],
  ["receipt not stdout",f=>{const r=f.read(f.input.proof.commands["dependency-bin-materialization"]);r.stdout=f.retain("other receipt");f.input.proof.commands["dependency-bin-materialization"]=f.retain(r);},/not original command stdout/],
])test("schema2 refuses "+name,()=>{const f=runtimeFixture();mutate(f);assert.throws(()=>authority.verifyRuntimeProof31(f.input),pattern);});
test("schema2 original-path replay retains command JSON with originals absent and extracted bytes regular",()=>{
  const f=runtimeFixture(),original=f.input.proof.buildRoot,runtimeRoot=path.dirname(f.input.proof.runtime.npmCliFile.path),proofBytes=Buffer.from(JSON.stringify(f.input.proof));
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
test("Windows preparation retains ordinary regular npm shims",()=>{
  const root=regularTree();for(const extension of ["",".cmd",".ps1"])put(root,"node_modules/.bin/probe"+extension,"inert existing npm shim"+extension);
  const before=maps(root),windows=platformBranch("win32"),receipt=windows.materializeNpmBins31({buildRoot:root});assert.deepEqual(maps(root),before);assert.equal(receipt.roots.root.aliases.length,0);
  if(process.platform==="win32")assert.equal(verify(root,receipt).recordedMaterializationVerified,true);
});
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
