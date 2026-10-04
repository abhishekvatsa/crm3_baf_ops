"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os"),crypto=require("node:crypto");
const api=require("./business31ToolchainIdentity.cjs"),bins=require("./business31NpmBinMaterialization.cjs");
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),"business31-identity-")),nodeBytes=fs.readFileSync(process.execPath);
const oid=raw=>crypto.createHash("sha1").update(Buffer.from(`blob ${raw.length}\0`)).update(raw).digest("hex");
let count=0;
function put(root,file,raw){const target=path.join(root,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);return target;}
function fixture(){
 const root=path.join(scratch,String(++count)),npmRoot=path.join(root,"npm");
 put(npmRoot,"package.json",JSON.stringify({name:"npm",version:"10.9.8"}));put(npmRoot,"bin/npm-cli.js","// synthetic never-executed npm entry\n");put(npmRoot,"node_modules/dep/index.js","// complete synthetic bundled dependency\n");
 const map=bins.scan31(npmRoot).files,source={commit:"a".repeat(40)},format=api.format31(nodeBytes);
 const profile={...format,nodeVersion:process.versions.node,npmVersion:"10.9.8",nodeSha256:api.sha(nodeBytes),npmEntry:"bin/npm-cli.js",npmFiles:map,npmFileCount:Object.keys(map).length,npmFilesSha256:api.sha(bins.canonical(map)),provenance:{nodeDistribution:{url:"https://example.invalid/synthetic-node",sha256:"A".repeat(64)},npmDistribution:{url:"https://example.invalid/synthetic-npm",sha256:"B".repeat(64),integrity:"sha512-"+Buffer.alloc(64).toString("base64")},reviewEvidenceSha256:"C".repeat(64)}};
 const table={schemaVersion:1,documentType:"build31-approved-toolchain-profiles",profiles:{"synthetic-host-case":profile}},runtime={nodeVersion:profile.nodeVersion,npmVersion:profile.npmVersion,toolchainProfileId:"synthetic-host-case",npmPackageRoot:npmRoot,nodeExecutable:{path:process.execPath,sha256:profile.nodeSha256},npmCliFile:{path:path.join(npmRoot,"bin/npm-cli.js"),sha256:map["bin/npm-cli.js"]}};
 let bytes;const snapshot={files:{[api.SELF]:{mode:"100644",oid:"f".repeat(40)}}};
 const bind=()=>{bytes=Buffer.from(JSON.stringify(table));snapshot.files[api.PROFILES]={mode:"100644",oid:oid(bytes)};};bind();
 const repository={readBlob:(commit,file)=>{assert.equal(commit,source.commit);assert.equal(file,api.PROFILES);return bytes;}};
 const input={runtime,source,snapshot,repository,policy:{toolchain:{nodeVersion:profile.nodeVersion,npmVersion:profile.npmVersion}}};
 return {root,npmRoot,profile,table,runtime,bind,input,check:()=>api.verifyToolchainIdentity31(input)};
}
test("explicit synthetic source identity binds whole npm implementation without executing or authenticating it",()=>{const f=fixture(),result=f.check();assert.equal(result.sourceApprovedBytesVerified,true);assert.equal(result.processExecutionAuthenticated,false);assert.equal(result.deploymentAuthorized,false);});
test("checked-in production profile table is deliberately closed",()=>{const bytes=fs.readFileSync(path.join(__dirname,"business31ToolchainProfiles.json"));assert.deepEqual(api.profileTable31(bytes).profiles,{});const f=fixture();f.table.profiles={};f.bind();assert.throws(f.check,/no independently approved/);});
for(const [name,mutate,error]of [
 ["fake Node self-hash",f=>{const file=put(f.root,"fake-node",nodeBytes.subarray(0,512));f.runtime.nodeExecutable={path:file,sha256:api.sha(fs.readFileSync(file))};},/Node differs from independently approved/],
 ["fake npm entry and self-hash",f=>{put(f.npmRoot,"bin/npm-cli.js","process.stdout.write('success');\n");f.runtime.npmCliFile.sha256=api.sha(fs.readFileSync(f.runtime.npmCliFile.path));},/complete npm implementation differs/],
 ["changed bundled npm dependency",f=>put(f.npmRoot,"node_modules/dep/index.js","fabricated success implementation"),/complete npm implementation differs/],
 ["extra bundled npm member",f=>put(f.npmRoot,"extra.js","unexpected"),/complete npm implementation differs/],
 ["missing bundled npm member",f=>{const original=path.join(f.npmRoot,"node_modules/dep/index.js");fs.renameSync(original,path.join(f.root,"retained-missing-dependency.js"));},/complete npm implementation differs/],
 ["different executable architecture",f=>{f.profile.arch=f.profile.arch==="x64"?"arm64":"x64";f.bind();},/platform\/architecture differs/],
 ["different executable platform",f=>{f.profile.platform=f.profile.platform==="win32"?"linux":"win32";f.bind();},/platform\/architecture differs/],
 ["caller changes npm version label",f=>{f.runtime.npmVersion="10.9.2";},/approved versions differ/],
 ["policy changes npm version",f=>{f.input.policy.toolchain.npmVersion="10.9.2";},/approved versions differ/],
 ["different npm entry",f=>{f.runtime.npmCliFile.path=put(f.npmRoot,"other.js","same promise");},/npm entry must be fixed/],
 ["profile map digest mismatch",f=>{f.profile.npmFilesSha256="F".repeat(64);f.bind();},/population digest differs/],
 ["profile source blob mismatch",f=>{f.input.snapshot.files[api.PROFILES].oid="f".repeat(40);},/source profile blob identity differs/],
 ["profile data symlink mode",f=>{f.input.snapshot.files[api.PROFILES].mode="120000";},/fixed toolchain helper and profiles/],
 ["source helper missing",f=>{delete f.input.snapshot.files[api.SELF];},/fixed toolchain helper and profiles/],
])test("refuses "+name,()=>{const f=fixture();mutate(f);assert.throws(f.check,error);});
test("correct file hashes do not excuse npm package name/version disagreement",()=>{const f=fixture();put(f.npmRoot,"package.json",JSON.stringify({name:"not-npm",version:f.profile.npmVersion}));f.profile.npmFiles=bins.scan31(f.npmRoot).files;f.profile.npmFilesSha256=api.sha(bins.canonical(f.profile.npmFiles));f.bind();assert.throws(f.check,/package name\/version differs/);});
test("complete npm implementation rejects linked indirection",()=>{const f=fixture();fs.symlinkSync(path.join(f.npmRoot,"bin/npm-cli.js"),path.join(f.npmRoot,"linked-entry"),"file");assert.throws(f.check,/regular installed population/);});
test("source-owned profile table must be identical regular data at V, M and custody",()=>{const f=fixture(),identity=f.input.snapshot.files[api.PROFILES],verifier={commit:f.input.source.commit,files:{[api.PROFILES]:identity}},snapshot=structuredClone(verifier),custody=structuredClone(verifier);assert.equal(api.verifyProfileSource31({repository:f.input.repository,verifier,snapshot,custody}),api.sha(f.input.repository.readBlob(verifier.commit,api.PROFILES)));for(const target of [snapshot,custody]){const saved=target.files[api.PROFILES];target.files[api.PROFILES]={...saved,oid:"f".repeat(40)};assert.throws(()=>api.verifyProfileSource31({repository:f.input.repository,verifier,snapshot,custody}),/identical regular V\/M\/custody/);target.files[api.PROFILES]=saved;}});
test("version probes have finite exact argv, raw stdout and empty stderr",()=>{const f=fixture(),identity=f.check();assert.deepEqual(api.probeArguments31("node",f.runtime),["--version"]);assert.deepEqual(api.probeArguments31("npm",f.runtime),[f.runtime.npmCliFile.path,"--version"]);for(const kind of ["node","npm"]){const text=(kind==="node"?"v"+identity.nodeVersion:identity.npmVersion)+"\n";api.verifyProbeOutput31(kind,{stdout:Buffer.from(text),stderr:Buffer.alloc(0)},identity);for(const output of [{stdout:Buffer.from(text.trim()),stderr:Buffer.alloc(0)},{stdout:Buffer.from(text+"fabricated"),stderr:Buffer.alloc(0)},{stdout:Buffer.from(text),stderr:Buffer.from("warning")}])assert.throws(()=>api.verifyProbeOutput31(kind,output,identity),/probe/);}});

test("version probes preserve genuine Windows CRLF and POSIX LF while refusing added output",()=>{
 const f=fixture(),identity=f.check();
 const actual=require("node:child_process").execFileSync(process.execPath,["--version"]);
 // The already-running test Node is an explicitly synthetic profile fixture;
 // this format observation cannot approve the host for production collection.
 api.verifyProbeOutput31("node",{stdout:actual,stderr:Buffer.alloc(0)},identity);
 for(const kind of ["node","npm"]){const version=kind==="node"?"v"+identity.nodeVersion:identity.npmVersion;
  for(const ending of ["\n","\r\n"])api.verifyProbeOutput31(kind,{stdout:Buffer.from(version+ending),stderr:Buffer.alloc(0)},identity);
  assert.throws(()=>api.verifyProbeOutput31(kind,{stdout:Buffer.from("prefix"+version+"\n"),stderr:Buffer.alloc(0)},identity),/stdout differs/);
  for(const ending of ["\r"," \n","\n\n","\r\nextra","suffix\n"])assert.throws(()=>api.verifyProbeOutput31(kind,{stdout:Buffer.from(version+ending),stderr:Buffer.alloc(0)},identity),/stdout differs/);
 }
});
