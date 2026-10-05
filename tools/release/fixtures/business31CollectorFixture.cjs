"use strict";
// Test-only actual Git source and real inert child inputs. This fixture grants
// no production identity, install/audit result, owner instruction or deployment.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),cp=require("node:child_process");
const assert=require("node:assert/strict");
const sha=b=>crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const binding=file=>({path:file,sha256:sha(fs.readFileSync(file))});
function put(root,name,bytes){const file=path.join(root,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,typeof bytes==="string"||Buffer.isBuffer(bytes)?bytes:JSON.stringify(bytes));return file;}
function regularMap(root){const result={};function visit(dir,prefix=""){for(const row of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){const name=prefix+row.name,file=path.join(dir,row.name);assert.equal(row.isSymbolicLink(),false);if(row.isDirectory())visit(file,name+"/");else{assert.equal(row.isFile(),true);Object.defineProperty(result,name,{value:sha(fs.readFileSync(file)),enumerable:true});}}}visit(root);return result;}
function createFixture({parent,name,toolsDirectory,gitExecutable,behaviour={}}){
  assert.match(name,/^[a-z0-9-]+$/);const root=path.join(parent,name);fs.mkdirSync(root);const repositoryRoot=path.join(root,"source");fs.mkdirSync(repositoryRoot);
  const runtimeRoot=path.join(root,"runtime"),npmPackageRoot=path.join(runtimeRoot,"npm");fs.mkdirSync(npmPackageRoot,{recursive:true});
  const npmVersion="10.9.8",npmCli=put(npmPackageRoot,"bin/npm-cli.js",fs.readFileSync(path.join(__dirname,"fixture_npm.cjs")));
  put(npmPackageRoot,"package.json",{name:"npm",version:npmVersion});
  put(npmPackageRoot,"bin/npm.cmd",'@ECHO off\r\n"%~dp0node.exe" "%~dp0node_modules\\npm\\bin\\npm-cli.js" %*\r\n');
  const bins=require(path.join(toolsDirectory,"business31NpmBinMaterialization.cjs"));
  const identity=require(path.join(toolsDirectory,"business31ToolchainIdentity.cjs"));
  const npmFiles=regularMap(npmPackageRoot),nodeExecutable=binding(process.execPath),profileId="synthetic-inert-collector-test";
  const profile={...identity.format31(fs.readFileSync(process.execPath)),nodeVersion:process.versions.node,npmVersion,nodeSha256:nodeExecutable.sha256,npmEntry:"bin/npm-cli.js",npmFiles,npmFileCount:Object.keys(npmFiles).length,npmFilesSha256:sha(bins.canonical(npmFiles)),provenance:{nodeDistribution:{url:"https://example.invalid/synthetic-node-test-only",sha256:"A".repeat(64)},npmDistribution:{url:"https://example.invalid/synthetic-npm-test-only",sha256:"B".repeat(64),integrity:"sha512-"+Buffer.alloc(64).toString("base64")},reviewEvidenceSha256:"C".repeat(64)}};
  // The fixture's complete source is deliberately small. Include every fixed
  // contract helper and all four collector producers, without altering bytes.
  // Tests never inject validators, process success or alternate collector paths.
  const contracts=JSON.parse(fs.readFileSync(path.join(toolsDirectory,"runtime_contract_bindings.json"),"utf8"));
  const producers=[...Object.keys(contracts),"collectBusinessRuntime31.cjs","runtime_process_runner.py","runtime_supervisor.py","runtime_contract_bindings.json"];
  assert.equal(new Set(producers).size,producers.length);
  for(const name of producers)put(repositoryRoot,"tools/release/"+name,fs.readFileSync(path.join(toolsDirectory,name)));
  if(behaviour.producerMismatch)fs.appendFileSync(path.join(repositoryRoot,"tools/release/collectBusinessRuntime31.cjs"),"\n// Different synthetic producer; must never be admitted.\n");
  put(repositoryRoot,identity.PROFILES,{schemaVersion:1,documentType:"build31-approved-toolchain-profiles",profiles:behaviour.noProfile?{}:{[profileId]:profile}});
  put(repositoryRoot,"release/production-release-policy.json",{toolchain:{nodeVersion:process.versions.node,npmVersion}});
  put(repositoryRoot,"fixture-behaviour.json",{npmVersion,...behaviour});
  put(repositoryRoot,"package.json",{name:"fixture-root",version:"1.0.0",private:true});
  put(repositoryRoot,"package-lock.json",{name:"fixture-root",lockfileVersion:3,packages:{"":{name:"fixture-root",version:"1.0.0"}}});
  const manifest={name:"fixture-functions",version:"1.0.0",dependencies:{"@grpc/grpc-js":"1.14.5"}};
  put(repositoryRoot,"functions/package.json",manifest);put(repositoryRoot,"functions/package-lock.json",{lockfileVersion:3,packages:{"":manifest,"node_modules/@grpc/grpc-js":{name:"@grpc/grpc-js",version:"1.14.5"}}});
  put(repositoryRoot,"functions/tsconfig.json",{compilerOptions:{module:"commonjs",noImplicitReturns:true,noUnusedLocals:false,outDir:"lib",sourceMap:true,strict:true,target:"es2022"},compileOnSave:true,include:["src"]});
  put(repositoryRoot,"functions/src/index.ts","export const value=1;\n");
  put(repositoryRoot,"tooling/firebase-cli/package.json",{name:"fixture-cli",version:"1.0.0",dependencies:{"firebase-tools":"15.22.4"}});
  put(repositoryRoot,"tooling/firebase-cli/package-lock.json",{lockfileVersion:3,packages:{"":{name:"fixture-cli",version:"1.0.0"},"node_modules/firebase-tools":{name:"firebase-tools",version:"15.22.4"}}});
  const env={SystemRoot:process.env.SystemRoot,WINDIR:process.env.WINDIR,GIT_CONFIG_NOSYSTEM:"1",GIT_CONFIG_GLOBAL:"NUL",GIT_TERMINAL_PROMPT:"0",GIT_AUTHOR_NAME:"Synthetic collector test",GIT_AUTHOR_EMAIL:"fixture@example.invalid",GIT_COMMITTER_NAME:"Synthetic collector test",GIT_COMMITTER_EMAIL:"fixture@example.invalid"};
  for(const key of Object.keys(env))if(env[key]===undefined)delete env[key];
  const git=(args,input)=>cp.execFileSync(gitExecutable,["-c","core.autocrlf=false","-c","commit.gpgsign=false","-c","core.hooksPath="+path.join(root,"absent-hooks"),"-c","protocol.allow=never","-C",repositoryRoot,...args],{env,input,encoding:"utf8",windowsHide:true,timeout:30000,stdio:["pipe","pipe","pipe"]}).trim();
  const sourceNames=Object.keys(regularMap(repositoryRoot)).sort();
  git(["init","--initial-branch=main"]);
  // Direct packed construction keeps the unchanged trusted Git layout checks
  // cheap. No pruning/deletion, alternate object store, or shallow history.
  const message="Explicit synthetic inert collector fixture only\n";
  const chunks=[Buffer.from("commit refs/heads/main\ncommitter Synthetic collector test <fixture@example.invalid> "+Math.floor(Date.now()/1000)+" +0000\ndata "+Buffer.byteLength(message)+"\n"+message)];
  for(const name of sourceNames){assert.match(name,/^[A-Za-z0-9_@+.~/-]+$/);const raw=fs.readFileSync(path.join(repositoryRoot,name));chunks.push(Buffer.from("M 100644 inline "+name+"\ndata "+raw.length+"\n"),raw,Buffer.from("\n"));}
  chunks.push(Buffer.from("\ndone\n"));git(["fast-import","--quiet","--done"],Buffer.concat(chunks));git(["read-tree","HEAD"]);
  const source={commit:git(["rev-parse","HEAD"]),tree:git(["rev-parse","HEAD^{tree}"]),functionsTree:git(["rev-parse","HEAD:functions"])};
  const before=regularMap(repositoryRoot),runtimeBefore=regularMap(runtimeRoot);
  return {root,repositoryRoot,source,gitExecutable,gitSha256:binding(gitExecutable).sha256,runtime:{nodeVersion:process.versions.node,npmVersion,toolchainProfileId:profileId,nodeExecutable,npmCliFile:binding(npmCli),npmPackageRoot},attemptRoot:path.join(root,"collection"),before,runtimeBefore,assertOriginalsUnchanged(){assert.deepEqual(regularMap(repositoryRoot),before);assert.deepEqual(regularMap(runtimeRoot),runtimeBefore);},scope:"Synthetic Git profile and actual inert processes only; no real install/audit/emulator/production evidence"};
}
module.exports={createFixture,regularMap,binding,sha,put};
