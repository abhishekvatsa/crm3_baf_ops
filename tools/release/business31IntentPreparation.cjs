"use strict";
// Business contract2 joins genuine post-runtime preparation; legacy contract1 is unchanged.
const {isDeepStrictEqual:same}=require("node:util");
const x=require("./business31ExecutionContract.cjs"),path=require("./backendRuntimeEvidenceAccess31.cjs").path;
const {need,keys,sha,json}=x;
const PRODUCERS=Object.freeze(["prepareBusinessIntent31.cjs","collectBusinessRuntime31.cjs","business31CaptureBootstrap.cjs","runtime_contract_bindings.json",
  "runtime_process_runner.py","runtime_supervisor.py"].map(name=>"tools/release/"+name));
const SUPERVISOR_SHA="4AE021C13E2FDC0D3FAD18ADBF5D7D796FD2DA946E8C907288BA0A83C585F37C";
function verifyIntentPreparation31({contract,proof,source,read,instant,repository,snapshot,evidenceDirectory,ownerReceivedAtUtc}) {
  need(contract.schemaVersion===2&&repository&&snapshot&&typeof evidenceDirectory==="string","actual contract2 source context required");
  const get=p=>json(read(p)),envelope=get(contract.intentPreparation),intent=get(contract.intendedHashInputs);
  keys(envelope,["schemaVersion","documentType","source","runtimeProof","startedAtUtc","completedAtUtc","producerBindings","projectConfigOriginal",
    "parametersOriginal","manifestProcess","packageProcess","manifest","archiveExpectedFiles","intendedHashInputs","runtimeBefore","runtimeAfter",
    "sourceBefore","sourceAfter","processExecutionAuthenticated","deploymentAuthorized"],"intent preparation");
  need(envelope.schemaVersion===1&&envelope.documentType==="build31-business-intent-preparation"&&envelope.processExecutionAuthenticated===false&&
    envelope.deploymentAuthorized===false,"original preparation type differs");
  for(const point of [envelope.source,envelope.sourceBefore,envelope.sourceAfter])need(same(point,source),"preparation source differs");
  need(same(envelope.runtimeProof,contract.runtimeProof)&&same(envelope.intendedHashInputs,contract.intendedHashInputs),"preparation runtime/intent pointer differs");
  need(intent.schemaVersion===1&&intent.documentType==="firebase-cli-approved-intended-hash-inputs"&&
    intent.startedAtUtc===envelope.startedAtUtc&&intent.completedAtUtc===envelope.completedAtUtc,"original ordered intent interval differs");
  need(instant(proof.completedAtUtc)<=instant(envelope.startedAtUtc)&&instant(envelope.startedAtUtc)<=instant(envelope.completedAtUtc)&&
    instant(envelope.completedAtUtc)<=instant(contract.preparedAtUtc)&&instant(contract.preparedAtUtc)<=instant(ownerReceivedAtUtc),"post-runtime/pre-owner preparation chronology differs");
  keys(envelope.producerBindings,PRODUCERS,"intent producers");
  for(const file of PRODUCERS)need(envelope.producerBindings[file]===sha(repository.readBlob(source.commit,file)),"preparation producer differs from M");
  need(envelope.producerBindings["tools/release/runtime_supervisor.py"]===SUPERVISOR_SHA,"original owned supervisor differs");
  const beforeBytes=read(envelope.runtimeBefore),afterBytes=read(envelope.runtimeAfter);
  need(beforeBytes.equals(afterBytes),"preparation runtime/source populations changed");
  const population=json(beforeBytes);
  keys(population,["schemaVersion","documentType","source","buildRoot","sourceFiles","installedFiles","emittedFiles","npmPackageFiles","nodeExecutable","npmCliFile"],"preparation runtime population");
  need(population.schemaVersion===1&&population.documentType==="build31-business-intent-runtime-populations"&&same(population.source,source)&&
    population.buildRoot===proof.buildRoot&&same(population.nodeExecutable,proof.runtime.nodeExecutable)&&same(population.npmCliFile,proof.runtime.npmCliFile),"preparation runtime identity differs");
  const sourceFiles=Object.fromEntries(Object.keys(snapshot.files).sort().map(file=>[file,sha(repository.readBlob(source.commit,file))]));
  need(same(population.sourceFiles,sourceFiles),"preparation complete source map differs");
  keys(population.installedFiles,["root","functions","cli"],"preparation installed roots");
  for(const name of ["root","functions","cli"])need(same(population.installedFiles[name],get(proof.installedFiles[name])),"preparation installed population differs");
  const emitted=Object.fromEntries(Object.entries(proof.emittedFiles).map(([name,pointer])=>[name,sha(read(pointer))]));
  need(same(population.emittedFiles,emitted),"preparation emitted population differs");
  const toolchain=require("./business31ToolchainIdentity.cjs"),profiles=toolchain.profileTable31(repository.readBlob(source.commit,toolchain.PROFILES));
  need(Object.hasOwn(profiles.profiles,proof.runtime.toolchainProfileId)&&same(population.npmPackageFiles,profiles.profiles[proof.runtime.toolchainProfileId].npmFiles),"preparation approved npm population differs");
  const producer=require("./prepareBusinessIntent31.cjs");
  producer.validateInputOriginals31({projectConfigOriginal:read(envelope.projectConfigOriginal),parametersOriginal:read(envelope.parametersOriginal),source,
    earliestUtc:proof.completedAtUtc,latestUtc:envelope.startedAtUtc});
  const names=Object.keys(intent.endpoints).sort(),manifest=get(envelope.manifest);
  producer.validateManifest31(manifest,names);
  const expectedFunctions=producer.admittedFunctionsMap31(population);
  const helperFiles=Object.fromEntries(Object.entries(sourceFiles).filter(([name])=>name.startsWith("tools/release/")).map(([name,hash])=>[name.slice(14),hash]));
  const absolute=(pointer)=>path.join(evidenceDirectory,pointer.file);
  function absoluteBytes(binding) {
    keys(binding,["path","sha256"],"original absolute binding");
    need(path.isAbsolute(binding.path)&&/^[A-F0-9]{64}$/.test(binding.sha256),"original absolute binding differs");
    const relative=path.relative(evidenceDirectory,binding.path).replace(/\\/g,"/");
    need(relative&&!relative.startsWith("../")&&!path.isAbsolute(relative),"intent original escapes evidence");
    const bytes=x.originalBytes(binding.path);need(bytes.length<=64*1024*1024&&sha(bytes)===binding.sha256,"original bound bytes changed");return bytes;
  }
  let previous=envelope.startedAtUtc,packageResult;
  for(const kind of ["manifest","package"]) {
    const record=get(envelope[kind+"Process"]);
    keys(record,["schemaVersion","documentType","kind","sourceBefore","sourceAfter","executable","executableSha256","argv","cwd","startedAtUtc","completedAtUtc",
      "exitCode","signal","error","request","configuration","supervisor","stdout","stderr","result"],"intent original process");
    need(record.schemaVersion===1&&record.documentType==="build31-business-intent-original-process"&&record.kind===kind&&record.exitCode===0&&record.signal===null&&record.error===null&&
      same(record.sourceBefore,source)&&same(record.sourceAfter,source)&&record.executable===proof.runtime.nodeExecutable.path&&record.executableSha256===proof.runtime.nodeExecutable.sha256&&
      record.cwd===proof.buildRoot,"intent process identity/result differs");
    const request=get(record.request),configuration=get(record.configuration),measured=get(record.supervisor),result=get(record.result);
    const expectedArgv=["--no-global-search-paths",path.join(proof.buildRoot,"tools/release/business31CaptureBootstrap.cjs"),"--intent-worker",absolute(record.request),record.request.sha256];
    need(same(record.argv,expectedArgv)&&record.startedAtUtc===measured.startedAtUtc&&record.completedAtUtc===measured.completedAtUtc,"original fixed intent command differs");
    require("./business31CohortProcess.cjs").verifyOwnedProcess31({root:evidenceDirectory,process:measured,executable:record.executable,args:expectedArgv,
      cwd:proof.buildRoot,earliestUtc:previous,latestUtc:envelope.completedAtUtc,stdout:record.stdout,stderr:record.stderr});
    previous=record.completedAtUtc;
    keys(request,["schemaVersion","operation","sourceRoot","sourceFiles","nodeExecutable","runtime","functionsRoot","functionsFiles","emittedFiles","configuration"],"intent worker request");
    need(request.schemaVersion===1&&request.operation===kind&&request.sourceRoot===path.join(proof.buildRoot,"tools/release")&&same(request.sourceFiles,helperFiles)&&
      same(request.nodeExecutable,proof.runtime.nodeExecutable)&&request.functionsRoot===path.join(proof.buildRoot,"functions"),"intent worker source/runtime differs");
    keys(request.runtime,["cliEntrypoint","cliFileBindings"],"intent worker CLI");
    need(request.runtime.cliEntrypoint===proof.runtime.cliEntrypoint.path&&same(json(absoluteBytes(request.runtime.cliFileBindings)),population.installedFiles.cli)&&
      same(json(absoluteBytes(request.functionsFiles)),expectedFunctions)&&same(json(absoluteBytes(request.emittedFiles)),emitted),"intent worker complete populations differ");
    need(request.configuration.path===absolute(record.configuration)&&request.configuration.sha256===record.configuration.sha256,"intent worker config pointer differs");
    keys(configuration,["schemaVersion","documentType","operation","source","buildRoot","outputDirectory","projectConfigOriginal","parametersOriginal","expectedFunctions","runtimeBefore","manifest"],"intent worker configuration");
    need(configuration.schemaVersion===1&&configuration.documentType==="build31-business-intent-worker-config"&&configuration.operation===kind&&same(configuration.source,source)&&
      configuration.buildRoot===proof.buildRoot&&same(configuration.expectedFunctions,names),"intent worker configuration differs");
    need(absoluteBytes(configuration.projectConfigOriginal).equals(read(envelope.projectConfigOriginal))&&
      absoluteBytes(configuration.parametersOriginal).equals(read(envelope.parametersOriginal))&&absoluteBytes(configuration.runtimeBefore).equals(beforeBytes),"intent original input joins differ");
    need(absolute(record.result)===path.join(configuration.outputDirectory,"result.json"),"original worker output path differs");
    if(kind==="manifest") {
      need(configuration.manifest===null,"manifest worker cannot accept a supplied manifest");
      keys(result,["schemaVersion","documentType","source","manifest","sdkLoader","sdkManifest"],"original manifest result");
      need(result.schemaVersion===1&&result.documentType==="build31-business-original-manifest-result"&&same(result.source,source)&&
        result.sdkLoader==="firebase-functions/lib/runtime/loader.js"&&result.sdkManifest==="firebase-functions/lib/runtime/manifest.js"&&
        absoluteBytes(result.manifest).equals(read(envelope.manifest)),"original SDK manifest differs");
    } else {
      need(absoluteBytes(configuration.manifest).equals(read(envelope.manifest)),"package consumed a different manifest");
      keys(result,["schemaVersion","documentType","source","sourceArchiveHash","environmentVariables","endpoints","originalArchive","archive","archiveExpectedFiles"],"original package result");
      need(result.schemaVersion===1&&result.documentType==="build31-business-original-package-result"&&same(result.source,source)&&result.sourceArchiveHash===intent.sourceArchiveHash&&
        JSON.stringify(result.environmentVariables)===JSON.stringify(intent.environmentVariables)&&JSON.stringify(result.endpoints)===JSON.stringify(intent.endpoints),"actual ordered package result differs");
      const archive=read(intent.archive);keys(result.originalArchive,["path","sha256","bytes"],"original temporary ZIP");
      need(path.isAbsolute(result.originalArchive.path)&&result.originalArchive.sha256===sha(archive)&&result.originalArchive.bytes===archive.length&&
        absoluteBytes({path:result.originalArchive.path,sha256:result.originalArchive.sha256}).equals(archive)&&
        absoluteBytes(result.archive).equals(archive)&&absoluteBytes(result.archiveExpectedFiles).equals(read(envelope.archiveExpectedFiles)),"actual retained ZIP/member binding differs");
      packageResult=result;
    }
  }
  return {envelope,intent,population,archiveExpectedFiles:get(envelope.archiveExpectedFiles),packageResult};
}
module.exports={PRODUCERS,verifyIntentPreparation31};
