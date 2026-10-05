"use strict";
// Local runtime measurement only. Trusted selection of this source/interpreter,
// source admission, CI, owner and deployment authority remain external gates.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const cp = require("node:child_process"), {isDeepStrictEqual: same} = require("node:util");
const SUPERVISOR_SHA = "4AE021C13E2FDC0D3FAD18ADBF5D7D796FD2DA946E8C907288BA0A83C585F37C";
const PLAN = Object.freeze(["node-version", "npm-version", "root-install", "functions-install", "cli-install",
  "dependency-bin-materialization", "functions-build", "functions-host-tests", "governed-emulator-tests",
  "dependency-compatibility", "installed-runtime", "audit-root-full", "audit-root-runtime",
  "audit-functions-full", "audit-functions-runtime", "audit-cli-full"]);
const HASH = /^[A-F0-9]{64}$/;
const sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const need = (v, m) => { if (!v) throw Error("Business runtime collector: " + m); };
const utc = () => new Date().toISOString();
function exact(v, names, label) {
  need(v && typeof v === "object" && !Array.isArray(v) &&
    same(Object.keys(v).sort(), [...names].sort()), label + " fields differ");
}
function regular(p, directory = false) {
  need(typeof p === "string" && path.isAbsolute(p), "absolute path required");
  p = path.resolve(p); let at = path.parse(p).root;
  for (const part of p.slice(at.length).split(path.sep).filter(Boolean)) {
    at = path.join(at, part); need(!fs.lstatSync(at).isSymbolicLink(), "redirected path refused");
  }
  need(directory ? fs.statSync(p).isDirectory() : fs.statSync(p).isFile(), "regular path required"); return p;
}
function read(p, max = 128 * 1024 * 1024) {
  p = regular(p); const a = fs.statSync(p, {bigint:true}); need(a.size <= BigInt(max), "file bound exceeded");
  const b = fs.readFileSync(p), z = fs.statSync(p, {bigint:true});
  need(a.size === z.size && a.ino === z.ino && a.mtimeNs === z.mtimeNs && a.ctimeNs === z.ctimeNs &&
    BigInt(b.length) === z.size, "file changed during read"); return b;
}
function supportHash(p) {
  p=regular(p);const fd=fs.openSync(p,"r"),hash=crypto.createHash("sha256");
  try {
    const before=fs.fstatSync(fd,{bigint:true});need(before.size<=512n*1024n*1024n,"support member exceeds512MiB");
    const buffer=Buffer.alloc(1024*1024);let total=0,count;
    while((count=fs.readSync(fd,buffer,0,buffer.length,null))>0){hash.update(buffer.subarray(0,count));total+=count;}
    const after=fs.fstatSync(fd,{bigint:true});need(before.size===after.size&&before.ino===after.ino&&
      before.mtimeNs===after.mtimeNs&&before.ctimeNs===after.ctimeNs&&BigInt(total)===after.size,"support bytes changed");
    return hash.digest("hex").toUpperCase();
  } finally {fs.closeSync(fd);}
}
function supportMap(root) {
  root=regular(root,true);const rows=[];let total=0;
  function walk(dir,prefix="") {
    for(const row of fs.readdirSync(dir,{withFileTypes:true})) {
      need(!row.isSymbolicLink(),"support redirect refused");const p=path.join(dir,row.name),name=prefix+row.name;
      if(row.isDirectory())walk(p,name+"/");
      else {need(row.isFile()&&rows.length<10000,"support population differs");total+=fs.statSync(p).size;
        need(total<=2*1024*1024*1024,"support population exceeds2GiB");rows.push([name,supportHash(p)]);}
    }
  }
  walk(root);return Object.fromEntries(rows);
}
function binding(v) {
  exact(v, ["path", "sha256"], "file binding"); need(HASH.test(v.sha256) && sha(read(v.path)) === v.sha256, "bound file differs"); return v;
}
function json(p) { return JSON.parse(new TextDecoder("utf8", {fatal:true}).decode(read(p, 64 * 1024 * 1024))); }
function write(p, value) {
  fs.mkdirSync(path.dirname(p), {recursive:true});
  fs.writeFileSync(p, Buffer.isBuffer(value) ? value : JSON.stringify(value, null, 2) + "\n", {flag:"wx"});
  return p;
}
function contracts() {
  const hashes = json(path.join(__dirname, "runtime_contract_bindings.json"));
  need(Object.keys(hashes).length === 14, "fixed contract population differs");
  for (const [n,h] of Object.entries(hashes)) {
    need(/^[A-Za-z0-9]+\.cjs$/.test(n) && HASH.test(h), "contract path/hash differs");
    need(sha(read(path.join(__dirname,n))) === h, "executing contract differs: " + n);
  }
  return {hashes, authority:require("./business31BackendAuthority.cjs"),
    toolchain:require("./business31ToolchainIdentity.cjs"), bins:require("./business31NpmBinMaterialization.cjs"),
    git:require("./business31TrustedInput.cjs")};
}
function absentAncestorBins(buildRoot) {
  for (let at=path.dirname(buildRoot);;at=path.dirname(at)) {
    need(!fs.existsSync(path.join(at,"node_modules/.bin")), "outside-build ancestor npm bin population refused: " + at);
    if (path.dirname(at) === at) break;
  }
}
function copyFile(p, to, expected) {
  const bytes=read(p); need(sha(bytes)===expected,"copy source differs");
  write(to,bytes); need(sha(read(to))===expected,"retained copy differs");
}
function verifySupport(config, api, policy) {
  exact(config.python,["executable","files"],"Python"); binding(config.python.executable);
  need(config.python.files && Object.keys(config.python.files).length > 0 && Object.keys(config.python.files).length <= 100,
    "bound Python runtime files required");
  need(config.python.files[config.python.executable.path]===config.python.executable.sha256,"Python executable not in runtime map");
  for(const [p,h] of Object.entries(config.python.files)) binding({path:p,sha256:h});
  exact(config.windows,["systemRoot","commandProcessor","java","firestoreJar"],"Windows inputs");
  const systemRoot=regular(config.windows.systemRoot,true); binding(config.windows.commandProcessor);
  need(path.resolve(config.windows.commandProcessor.path)===path.join(systemRoot,"System32/cmd.exe"),"fixed Windows command processor required");
  if(config.windows.java!==null) {
    exact(config.windows.java,["home","files"],"Java binding"); regular(config.windows.java.home,true);
    need(same(supportMap(config.windows.java.home),config.windows.java.files),"complete Java population differs");
    need(Object.hasOwn(config.windows.java.files,"bin/java.exe"),"Java executable absent");
    const release=read(path.join(config.windows.java.home,"release")).toString("utf8");
    const semantic=/^SEMANTIC_VERSION="([^"\r\n]+)"$/m.exec(release)?.[1];
    need(typeof policy.toolchain.javaVersion==="string"&&semantic===policy.toolchain.javaVersion,"Java release differs from source policy");
  }
  if(config.windows.firestoreJar!==null) {
    exact(config.windows.firestoreJar,["path","sha256","fileName"],"Firestore cache binding");
    need(HASH.test(config.windows.firestoreJar.sha256)&&supportHash(config.windows.firestoreJar.path)===config.windows.firestoreJar.sha256,"Firestore cache bytes differ");
    need(/^cloud-firestore-emulator-v[0-9.]+\.jar$/.test(config.windows.firestoreJar.fileName),"fixed Firestore cache member required");
  }
}
function sourceCheck(ctx, buildRoot) {
  const again=ctx.repository.snapshot(ctx.config.source.commit);
  need(same(again,ctx.snapshot),"source Git identity changed");
  if(buildRoot) ctx.api.authority.verifyMaterializedSource31(buildRoot,ctx.snapshot);
  absentAncestorBins(path.join(ctx.config.attemptRoot,"build"));
  binding({path:ctx.config.gitExecutable,sha256:ctx.config.gitSha256});
  for(const [n,h] of Object.entries(ctx.api.hashes)) need(sha(read(path.join(__dirname,n)))===h,"contract changed");
  need(sha(read(path.join(__dirname,"runtime_supervisor.py")))===SUPERVISOR_SHA,"supervisor changed");
  need(sha(read(path.join(__dirname,"runtime_process_runner.py")))===ctx.runnerSha256,"runner changed");
  need(sha(read(path.join(__dirname,"runtime_contract_bindings.json")))===ctx.contractBindingsSha256,"contract binding table changed");
  need(sha(read(__filename))===ctx.collectorSha256,"collector changed");
}
function runtimeCheck(ctx,runtime) {
  ctx.api.toolchain.verifyToolchainIdentity31({runtime,source:ctx.config.source,snapshot:ctx.snapshot,
    repository:ctx.repository,policy:ctx.policy});
  if(runtime.npmPackageRoot!==ctx.config.runtime.npmPackageRoot)
    ctx.api.toolchain.verifyToolchainIdentity31({runtime:ctx.config.runtime,source:ctx.config.source,snapshot:ctx.snapshot,
      repository:ctx.repository,policy:ctx.policy});
  verifySupport(ctx.config,ctx.api,ctx.policy);
  if(ctx.wrapperBindings)for(const value of ctx.wrapperBindings)binding(value);
}
function checkPorts(config) {
  const result=cp.spawnSync(config.python.executable.path,["-I","-S",path.join(__dirname,"runtime_process_runner.py"),"--check-ports"],
    {env:{SystemRoot:config.windows.systemRoot,WINDIR:config.windows.systemRoot},windowsHide:true,encoding:null,timeout:15000,maxBuffer:65536});
  need(!result.error&&result.status===0&&result.stderr.length===0,"Windows listener read failed");
  const value=JSON.parse(result.stdout.toString("utf8"));
  exact(value,["documentType","ports","occupied"],"listener read");
  need(value.documentType==="local-windows-listener-read"&&same(value.ports,[8080,4400,9150])&&Array.isArray(value.occupied),"listener read schema differs");
  need(value.occupied.length===0,"required emulator ports already occupied; owners left untouched");return result.stdout;
}
function checkEmulatorInputs(ctx,buildRoot,environment) {
  if(!ctx.requiresEmulator)return;
  const metadata=json(path.join(buildRoot,"tooling/firebase-cli/node_modules/firebase-tools/lib/emulator/downloadableEmulatorInfo.json")).firestore;
  const selected=ctx.config.windows.firestoreJar,file=path.join(environment.FIREBASE_EMULATORS_PATH,selected.fileName);
  need(metadata&&metadata.downloadPathRelativeToCacheDir===selected.fileName&&metadata.expectedChecksumSHA256?.toUpperCase()===selected.sha256 &&
    metadata.expectedSize===fs.statSync(regular(file)).size && supportHash(file)===selected.sha256,"selected Firestore cache differs from installed pinned CLI metadata");
}
function preflightBusinessRuntime31(config) {
  exact(config,["schemaVersion","repositoryRoot","gitExecutable","gitSha256","source","runtime","attemptRoot",
    "afterCi","python","windows","limits"],"collector input");
  need(config.schemaVersion===1 && process.platform==="win32","Windows collector input required");
  exact(config.source,["commit","tree","functionsTree"],"source identity");
  need(Object.values(config.source).every(v=>typeof v==="string"&&/^[a-f0-9]{40}$/.test(v)),"exact Git identities required");
  exact(config.runtime,["nodeVersion","npmVersion","toolchainProfileId","nodeExecutable","npmCliFile","npmPackageRoot"],"runtime input");
  exact(config.limits,["commandSeconds","cleanupSeconds","outputBytes"],"limits");
  need(Number.isFinite(config.limits.commandSeconds)&&config.limits.commandSeconds>0&&config.limits.commandSeconds<=3600 &&
    Number.isFinite(config.limits.cleanupSeconds)&&config.limits.cleanupSeconds>0&&config.limits.cleanupSeconds<=30 &&
    Number.isSafeInteger(config.limits.outputBytes)&&config.limits.outputBytes>0&&config.limits.outputBytes<=64*1024*1024,"finite supervisor limits required");
  need(typeof config.attemptRoot==="string"&&path.isAbsolute(config.attemptRoot)&&!/[\x00-\x1f% !^&|<>\"]/.test(config.attemptRoot),"safe new Windows attempt root required");
  regular(path.dirname(config.attemptRoot),true); need(!fs.existsSync(config.attemptRoot),"attempt already exists; no retry");
  absentAncestorBins(path.join(config.attemptRoot,"build"));
  const api=contracts(); api.authority.instant(config.afterCi);
  need(api.authority.instant(config.afterCi)<=api.authority.instant(utc()),"future CI bound refused");
  const repository=api.git.openTrustedGitRepository31({repositoryRoot:config.repositoryRoot,gitExecutable:config.gitExecutable,gitSha256:config.gitSha256});
  const snapshot=repository.snapshot(config.source.commit);
  need(snapshot.tree===config.source.tree && api.authority.subtreeOid31(snapshot.files,"functions")===config.source.functionsTree,"source tree differs");
  const sourceBytes=new Map();
  for(const name of Object.keys(snapshot.files).sort()) {
    const bytes=repository.readBlob(snapshot.commit,name);
    need(!["node_modules","functions/node_modules","functions/lib","tooling/firebase-cli/node_modules",".dart_tool"].some(p=>name===p||name.startsWith(p+"/")),"source contains generated runtime files");
    sourceBytes.set(name,bytes);
  }
  for(const [n,h] of Object.entries(api.hashes)) need(sha(sourceBytes.get("tools/release/"+n)??Buffer.alloc(0))===h,"source contract differs: "+n);
  for(const n of ["collectBusinessRuntime31.cjs","runtime_process_runner.py","runtime_supervisor.py","runtime_contract_bindings.json"])
    need(sourceBytes.get("tools/release/"+n)?.equals(read(path.join(__dirname,n))),"executing collector producer differs from source: "+n);
  const policy=JSON.parse(sourceBytes.get("release/production-release-policy.json"));
  const identity=api.toolchain.verifyToolchainIdentity31({runtime:config.runtime,source:config.source,snapshot,repository,policy});
  need(identity.platform==="win32","Windows approved Node required");
  // The collector's own Node is selected externally, then joined to the same
  // approved bytes. It cannot self-authenticate its launch or a hostile host.
  need(sha(read(process.execPath))===config.runtime.nodeExecutable.sha256,"collector interpreter differs from approved Node");
  binding(config.runtime.nodeExecutable);binding(config.runtime.npmCliFile);
  const npmMap=api.bins.scan31(config.runtime.npmPackageRoot).files;
  need(Object.hasOwn(npmMap,"bin/npm.cmd"),"approved package-owned npm.cmd required for nested scripts");
  const pkg=JSON.parse(sourceBytes.get("package.json"));
  const governed=pkg.scripts?.["emulator:test:governed"]??"";
  const requiresEmulator=governed.includes("emulators:exec");
  if(requiresEmulator) {
    need(governed==='node tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --only firestore --project demo-crm3-governed "npm run test:rules && npm run test:governed-asset-identity-reconciliation:emulator && npm --prefix functions run test:emulator:governed"',"governed emulator script changed; review its runtime inputs");
    need(config.windows.java!==null&&config.windows.firestoreJar!==null,"governed Java/cache prerequisites required");
    const firebase=JSON.parse(sourceBytes.get("firebase.json"));
    need(firebase.emulators?.firestore?.port===8080&&[undefined,9150].includes(firebase.emulators?.firestore?.websocketPort)&&
      [undefined,4400].includes(firebase.emulators?.hub?.port),"source emulator port contract changed");
  }
  verifySupport(config,api,policy);
  need(sha(read(path.join(__dirname,"runtime_supervisor.py")))===SUPERVISOR_SHA,"supervisor differs");
  const preflightPorts=requiresEmulator?checkPorts(config):null;
  return {config,api,repository,snapshot,sourceBytes,policy,identity,npmMap,requiresEmulator,
    preflightPorts,runnerSha256:sha(read(path.join(__dirname,"runtime_process_runner.py"))),collectorSha256:sha(read(__filename)),
    contractBindingsSha256:sha(read(path.join(__dirname,"runtime_contract_bindings.json")))};
}
function pointer(root,file) {
  const bytes=read(file,64*1024*1024),relative=path.relative(root,file).split(path.sep).join("/");
  need(relative&&!relative.startsWith("../")&&!path.isAbsolute(relative),"evidence pointer escaped");
  return {file:relative,sha256:sha(bytes),bytes:bytes.length};
}
function createEnvironment(ctx,root,runtime) {
  const home=path.join(root,"home"),temp=path.join(root,"temp"),cache=path.join(root,"npm-cache"),emulators=path.join(root,"emulator-cache");
  for(const dir of [home,temp,cache,emulators])fs.mkdirSync(dir);
  const user=write(path.join(home,"user.npmrc"),Buffer.alloc(0)),global=write(path.join(home,"global.npmrc"),Buffer.alloc(0));
  const windows=ctx.config.windows;
  if(windows.firestoreJar) {
    const file=path.join(emulators,windows.firestoreJar.fileName);fs.copyFileSync(windows.firestoreJar.path,file,fs.constants.COPYFILE_EXCL);
    need(supportHash(file)===windows.firestoreJar.sha256,"retained Firestore cache differs");
  }
  const paths=[path.dirname(runtime.nodeExecutable.path),path.dirname(ctx.config.gitExecutable)];
  if(windows.java)paths.push(path.join(windows.java.home,"bin"));
  paths.push(path.join(windows.systemRoot,"System32"));
  const env={SystemRoot:windows.systemRoot,WINDIR:windows.systemRoot,ComSpec:windows.commandProcessor.path,
    PATHEXT:".COM;.EXE;.BAT;.CMD",PATH:paths.join(path.delimiter),HOME:home,USERPROFILE:home,APPDATA:home,LOCALAPPDATA:home,
    XDG_CONFIG_HOME:home,TEMP:temp,TMP:temp,TMPDIR:temp,CI:"true",NPM_CONFIG_USERCONFIG:user,NPM_CONFIG_GLOBALCONFIG:global,
    NPM_CONFIG_CACHE:cache,NPM_CONFIG_PREFIX:path.dirname(runtime.nodeExecutable.path),NPM_CONFIG_REGISTRY:"https://registry.npmjs.org/",
    FIREBASE_EMULATORS_PATH:emulators,NO_UPDATE_NOTIFIER:"1"};
  if(windows.java)env.JAVA_HOME=windows.java.home;
  return env;
}
function archiveGeneratedLogs(ctx,buildRoot,evidence,kind) {
  if(kind!=="governed-emulator-tests")return [];
  const moved=[];
  const names=["firebase-debug.log",...Array.from({length:9},(_,i)=>`firebase-debug.${i+1}.log`),"firestore-debug.log","ui-debug.log"];
  for(const name of names) {
    const from=path.join(buildRoot,name);if(!fs.existsSync(from))continue;
    need(!ctx.snapshot.files[name],"generated log path belongs to source");
    const bytes=read(from,64*1024*1024),stat=fs.statSync(from,{bigint:true}),to=path.join(evidence,"generated-logs",kind,name);
    fs.mkdirSync(path.dirname(to),{recursive:true});need(!fs.existsSync(to),"generated log custody already exists");
    fs.renameSync(from,to);need(read(to).equals(bytes),"generated log changed while retaining");
    moved.push({originalPath:from,retained:pointer(evidence,to),mtimeNs:stat.mtimeNs.toString(),renamedAtUtc:utc()});
  }
  return moved;
}
function collectBusinessRuntime31(config) {
  const ctx=preflightBusinessRuntime31(config),root=path.resolve(config.attemptRoot);
  fs.mkdirSync(root);const evidence=path.join(root,"evidence"),buildRoot=path.join(root,"build"),prefix=path.join(root,"runtime");
  fs.mkdirSync(evidence);fs.mkdirSync(buildRoot);fs.mkdirSync(prefix);
  const progress=[];let current="source-export",proof,proofWritten=false;
  try {
    write(path.join(root,"ownership.json"),{type:"private-runtime-collection",createdAtUtc:utc(),source:config.source,collectorSha256:ctx.collectorSha256,authenticated:false});
    if(ctx.preflightPorts)write(path.join(evidence,"preflight-listeners.json"),ctx.preflightPorts);
    for(const [name,bytes]of ctx.sourceBytes)write(path.join(buildRoot,name),bytes);
    sourceCheck(ctx,buildRoot);
    const node=path.join(prefix,"node.exe"),npmRoot=path.join(prefix,"node_modules/npm");
    copyFile(config.runtime.nodeExecutable.path,node,config.runtime.nodeExecutable.sha256);
    for(const [name,h]of Object.entries(ctx.npmMap))copyFile(path.join(config.runtime.npmPackageRoot,name),path.join(npmRoot,name),h);
    ctx.wrapperBindings=[];
    for(const name of ["npm.cmd","npx.cmd"])if(ctx.npmMap["bin/"+name]) {
      const to=path.join(prefix,name);copyFile(path.join(npmRoot,"bin",name),to,ctx.npmMap["bin/"+name]);
      ctx.wrapperBindings.push({path:to,sha256:ctx.npmMap["bin/"+name]});
    }
    const runtime={...config.runtime,nodeExecutable:{path:node,sha256:config.runtime.nodeExecutable.sha256},npmPackageRoot:npmRoot,
      npmCliFile:{path:path.join(npmRoot,"bin/npm-cli.js"),sha256:config.runtime.npmCliFile.sha256},firebaseCliVersion:"15.22.4"};
    runtimeCheck(ctx,runtime);const environment=createEnvironment(ctx,root,runtime),startedAtUtc=utc();
    proof={schemaVersion:3,documentType:"build31-business-runtime-proof",profile:ctx.api.authority.PROFILE,source:config.source,
      startedAtUtc,completedAtUtc:null,buildRoot,runtime,commands:{},audits:{},emittedFiles:{},installedDependencies:null,
      installedFiles:{},toolchainProbes:{},binMaterialization:null,testedEmittedFiles:{}};
    for(const kind of PLAN) {
      current=kind; sourceCheck(ctx,buildRoot);runtimeCheck(ctx,runtime);
      if(kind==="governed-emulator-tests"&&ctx.requiresEmulator) {
        checkEmulatorInputs(ctx,buildRoot,environment);
        write(path.join(evidence,"governed-listeners-before.json"),checkPorts(config));
      }
      const argv=kind.endsWith("-version")?ctx.api.toolchain.probeArguments31(kind.split("-")[0],runtime):
        kind.startsWith("audit-")?ctx.api.authority.auditArguments31(kind.slice(6),runtime.npmCliFile.path):
        ctx.api.authority.commandArguments31(kind,runtime.npmCliFile.path,buildRoot);
      const processDir=path.join(evidence,"processes",kind),requestFile=path.join(evidence,"requests",kind+".json");
      fs.mkdirSync(path.dirname(processDir),{recursive:true});
      write(requestFile,{schemaVersion:1,parentPid:process.pid,supervisorSha256:SUPERVISOR_SHA,executable:runtime.nodeExecutable.path,
        arguments:argv,cwd:buildRoot,environment,outputDirectory:processDir,timeoutSeconds:config.limits.commandSeconds,
        maxOutputBytes:config.limits.outputBytes,cleanupSeconds:config.limits.cleanupSeconds});
      const run=cp.spawnSync(config.python.executable.path,["-I","-S",path.join(__dirname,"runtime_process_runner.py"),requestFile],
        {cwd:root,env:environment,windowsHide:true,encoding:null,maxBuffer:1024*1024,
          timeout:(config.limits.commandSeconds+config.limits.cleanupSeconds*3+15)*1000});
      write(path.join(evidence,"runner",kind+".stdout.bin"),run.stdout??Buffer.alloc(0));
      write(path.join(evidence,"runner",kind+".stderr.bin"),run.stderr??Buffer.alloc(0));
      const physical=path.join(processDir,"result.json");
      need(fs.existsSync(physical),"supervisor produced no completed record for "+kind);
      const measured=json(physical),raw={stdout:pointer(evidence,path.join(processDir,"stdout.bin")),stderr:pointer(evidence,path.join(processDir,"stderr.bin"))};
      progress.push({kind,supervisor:pointer(evidence,physical),...raw});
      write(path.join(evidence,"progress",String(progress.length).padStart(2,"0")+".json"),progress);
      need(measured.treeComplete&&measured.outputComplete,"owned process tree/output incomplete: "+kind);
      const logs=archiveGeneratedLogs(ctx,buildRoot,evidence,kind);if(logs.length)write(path.join(evidence,"generated-logs",kind,"custody.json"),logs);
      sourceCheck(ctx,buildRoot);runtimeCheck(ctx,runtime);
      need(!run.error&&run.status===0&&measured.status==="SUCCESS"&&measured.exitCode===0,"original command failed: "+kind);
      need(measured.executable===runtime.nodeExecutable.path&&same(measured.arguments,argv)&&measured.cwd===buildRoot&&
        measured.jobAssigned&&measured.resumed&&measured.rootExited&&measured.activeProcesses===0&&measured.cleanupErrors.length===0,"supervisor command/ownership differs");
      const record={schemaVersion:1,documentType:"build31-business-original-process",kind,sourceBefore:config.source,sourceAfter:config.source,
        executable:runtime.nodeExecutable.path,executableSha256:runtime.nodeExecutable.sha256,argv,cwd:buildRoot,
        startedAtUtc:measured.startedAtUtc,completedAtUtc:measured.completedAtUtc,exitCode:measured.exitCode,signal:null,error:null,...raw};
      if(ctx.api.authority.OUTPUT_COMMANDS.includes(kind)) {
        const map=Object.fromEntries(Object.entries(ctx.api.authority.fileMap31(path.join(buildRoot,"functions/lib"))).map(([p,h])=>["lib/"+p,h]));
        need(same(Object.keys(map).sort(),ctx.api.authority.expectedEmittedFiles31(ctx.snapshot,JSON.parse(ctx.sourceBytes.get("functions/tsconfig.json")))),"unexpected emitted output");
        const file=write(path.join(evidence,"tested-emitted",kind+".json"),map);proof.testedEmittedFiles[kind]=pointer(evidence,file);
        record.schemaVersion=2;record.emittedFilesAfterSha256=proof.testedEmittedFiles[kind].sha256;
      }
      const recordPointer=pointer(evidence,write(path.join(evidence,"commands",kind+".json"),record));
      if(kind.endsWith("-version")) {
        const name=kind.split("-")[0];ctx.api.toolchain.verifyProbeOutput31(name,{stdout:read(path.join(processDir,"stdout.bin")),stderr:read(path.join(processDir,"stderr.bin"))},ctx.identity);
        proof.toolchainProbes[name]=recordPointer;
      } else if(kind.startsWith("audit-")) {
        ctx.api.authority.verifyStrictAudit31(read(path.join(processDir,"stdout.bin")));proof.audits[kind.slice(6)]={report:raw.stdout,command:recordPointer};
      } else proof.commands[kind]=recordPointer;
      if(kind==="dependency-bin-materialization")proof.binMaterialization=raw.stdout;
      if(kind==="installed-runtime")proof.installedDependencies=raw.stdout;
    }
    current="final-verification";
    for(const [name,relative]of Object.entries(ctx.api.bins.ROOTS))proof.installedFiles[name]=pointer(evidence,write(path.join(evidence,"installed",name+".json"),ctx.api.authority.fileMap31(path.join(buildRoot,relative))));
    for(const name of ctx.api.authority.expectedEmittedFiles31(ctx.snapshot,JSON.parse(ctx.sourceBytes.get("functions/tsconfig.json")))) {
      const file=write(path.join(evidence,"emitted",name),read(path.join(buildRoot,"functions",name)));proof.emittedFiles[name]=pointer(evidence,file);
    }
    const cli=path.join(buildRoot,"tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js");runtime.cliEntrypoint={path:cli,sha256:sha(read(cli))};
    proof.completedAtUtc=utc();sourceCheck(ctx,buildRoot);runtimeCheck(ctx,runtime);
    const verification=ctx.api.authority.verifyRuntimeProof31({proof,source:config.source,snapshot:ctx.snapshot,repository:ctx.repository,
      evidenceDirectory:evidence,afterCi:config.afterCi,beforeDecision:utc()});
    sourceCheck(ctx,buildRoot);runtimeCheck(ctx,runtime);
    const proofFile=write(path.join(evidence,"runtime-proof.json"),proof);
    proofWritten=true;
    write(path.join(evidence,"collection-result.json"),{status:"COMPLETE_LOCAL_MEASUREMENT",proof:pointer(evidence,proofFile),commands:progress.length,
      verifiedAtUtc:utc(),authenticated:false,deploymentAuthorized:false});
    return {proofFile,sha256:sha(read(proofFile)),evidenceDirectory:evidence,buildRoot,verification};
  } catch(error) {
    write(path.join(evidence,"failure.json"),{status:"FAILED",kind:current,atUtc:utc(),error:String(error.message),completedProcessRecords:progress,
      successfulProofWritten:proofWritten,collectionComplete:false,authenticated:false,deploymentAuthorized:false});throw error;
  }
}
module.exports={PLAN,preflightBusinessRuntime31,collectBusinessRuntime31};
if(require.main===module) {
  try { need(process.argv.length===3,"one explicit data-only collector input file required");
    const result=collectBusinessRuntime31(json(process.argv[2]));process.stdout.write(JSON.stringify(result)+"\n");
  } catch(error) {process.stderr.write(String(error.message)+"\n");process.exitCode=1;}
}
