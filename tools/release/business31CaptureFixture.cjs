'use strict';
// Synthetic two-file Git/ZIP fixture for local and CI tests; never deployment evidence.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const CONTENTS=Object.freeze({
 'package.json':'{"name":"synthetic-capture-fixture","version":"1.0.0"}\r\n',
 'src/index.ts':'export const synthetic = true;\r\n',
});
const ZIP='UEsDBBQAAAAAAAAARF3iRWKlOAAAADgAAAAMAAAAcGFja2FnZS5qc29ueyJuYW1lIjoic3ludGhldGljLWNhcHR1cmUtZml4dHVyZSIsInZlcnNpb24iOiIxLjAuMCJ9DQpQSwMEFAAAAAAAAABEXb8lGOUgAAAAIAAAAAwAAABzcmMvaW5kZXgudHNleHBvcnQgY29uc3Qgc3ludGhldGljID0gdHJ1ZTsNClBLAQIUABQAAAAAAAAARF3iRWKlOAAAADgAAAAMAAAAAAAAAAAAAACkgQAAAABwYWNrYWdlLmpzb25QSwECFAAUAAAAAAAAAERdvyUY5SAAAAAgAAAADAAAAAAAAAAAAAAApIFiAAAAc3JjL2luZGV4LnRzUEsFBgAAAAACAAIAdAAAAKwAAAAAAA==';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
function createCaptureFixture31(parent,gitExecutable='git'){
 if(typeof parent!=='string'||!path.isAbsolute(parent))throw Error('Absolute existing fixture parent required');
 const real=fs.realpathSync(parent);
 if(real!==path.resolve(parent)||!fs.statSync(real).isDirectory())throw Error('Regular existing fixture parent required');
 const directory=fs.mkdtempSync(path.join(real,'capture-source-')),repository=path.join(directory,'repository');
 fs.mkdirSync(repository);fs.mkdirSync(path.join(repository,'functions/src'),{recursive:true});
 for(const [name,value]of Object.entries(CONTENTS))fs.writeFileSync(path.join(repository,'functions',name),value,{flag:'wx'});
 const env={};
 for(const key of ['SystemRoot','SYSTEMROOT','WINDIR','COMSPEC','TEMP','TMP','PATH','PATHEXT','LANG','LC_ALL'])if(process.env[key]!==undefined)env[key]=process.env[key];
 Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null',GIT_TERMINAL_PROMPT:'0',GIT_OPTIONAL_LOCKS:'0',GIT_NO_LAZY_FETCH:'1',
 GIT_AUTHOR_NAME:'Synthetic fixture',GIT_AUTHOR_EMAIL:'fixture@example.invalid',GIT_COMMITTER_NAME:'Synthetic fixture',GIT_COMMITTER_EMAIL:'fixture@example.invalid',
 GIT_AUTHOR_DATE:'2026-01-01T00:00:00Z',GIT_COMMITTER_DATE:'2026-01-01T00:00:00Z'});
 const git=args=>execFileSync(gitExecutable,['--no-replace-objects','--no-pager','--no-optional-locks','-c','core.autocrlf=false','-c','core.fsmonitor=false',
 '-c','core.hooksPath='+path.join(repository,'.git','disabled-hooks'),'-c','credential.helper=','-c','protocol.allow=never','-C',repository,...args],
 {env,windowsHide:true,timeout:30000,maxBuffer:1024*1024,stdio:['ignore','pipe','pipe']}).toString('utf8').trim();
 git(['init','--quiet','--initial-branch=main','--template=']);
 git(['add','--','functions/package.json','functions/src/index.ts']);
 git(['commit','--quiet','-m','Synthetic capture fixture only']);
 const commit=git(['rev-parse','HEAD']);git(['update-ref','refs/remotes/origin/main',commit]);
 const source={commit,tree:git(['rev-parse','HEAD^{tree}']),functionsTree:git(['rev-parse','HEAD:functions'])};
 if(git(['status','--porcelain=v1','--untracked-files=all'])!=='')throw Error('Fixture repository is not clean');
 const bytes=Buffer.from(ZIP,'base64'),archive=path.join(directory,'original-source.zip');
 fs.writeFileSync(archive,bytes,{flag:'wx'});
 const archiveExpectedFiles=Object.fromEntries(Object.entries(CONTENTS).map(([name,text])=>{const b=Buffer.from(text);return[name,{sha256:sha(b),bytes:b.length}];}));
 const result={directory,repository,source,archive,archiveSha256:sha(bytes),archiveExpectedFiles,syntheticLocalFixture:true,actualDeploymentEvidence:false};
 fs.writeFileSync(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 return result;
}
// Copy once per test worker; never rewrite the caller's installed dependency tree.
function createBoundCliFixture31(repositoryRoot,parent){
 const materializer=require("./business31NpmBinMaterialization.cjs"),writer=require("./captureBusiness31PreparedInputs.cjs");
 const assert=require("node:assert/strict");
 const buildRoot=fs.mkdtempSync(path.join(fs.realpathSync(parent),"bound-cli-"));
 for(const relative of ["node_modules","functions/node_modules","tooling/firebase-cli"])fs.mkdirSync(path.join(buildRoot,relative),{recursive:true});
 const source=path.join(repositoryRoot,"tooling/firebase-cli/node_modules"),destination=path.join(buildRoot,"tooling/firebase-cli/node_modules");
 const sourceBefore=materializer.scan31(source,true);
 fs.cpSync(source,destination,{recursive:true,dereference:false,verbatimSymlinks:true,errorOnExist:true,force:false});
 assert.deepEqual(materializer.scan31(destination,true),sourceBefore,"copied CLI population and aliases match the installed originals");
 // Real npm aliases remain aliases until the unchanged materializer validates them.
 const materialization=materializer.materializeNpmBins31({buildRoot}),files=materializer.scan31(destination).files;
 const materializationFile=path.join(buildRoot,"materialization.json"),mapFile=path.join(buildRoot,"cli-file-bindings.json");
 fs.writeFileSync(materializationFile,JSON.stringify(materialization,null,2)+"\n",{flag:"wx"});
 const raw=Buffer.from(JSON.stringify(files,null,2)+"\n");fs.writeFileSync(mapFile,raw,{flag:"wx"});
 const cli=path.join(destination,"firebase-tools/lib"),runtime={cliEntrypoint:path.join(cli,"bin/firebase.js"),cliFileBindings:{path:mapFile,sha256:sha(raw)}};
 const assertOriginalUnchanged=()=>assert.deepEqual(materializer.scan31(source,true),sourceBefore,"installed CLI dependencies remain unchanged");
 assertOriginalUnchanged();
 const lease=writer.installCliLoadBoundary31(runtime);
 return {buildRoot,cli,runtime,lease,materializationFile,assertOriginalUnchanged};
}
module.exports={createCaptureFixture31,createBoundCliFixture31};
