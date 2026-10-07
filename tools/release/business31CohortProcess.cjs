"use strict";
// Original process/phase custody only. These joins do not authenticate a host.
const fs = require("node:fs"), nativePath = require("node:path");
const {isDeepStrictEqual: same} = require("node:util");
const pythonRuntime = require("./collectBusinessRuntime31.cjs");
const x = require("./business31ExecutionContract.cjs");
const {need, keys, sha, json, privateBytes} = x;
const path = require("./backendRuntimeEvidenceAccess31.cjs").path;
const time = require("./business31BackendAuthority.cjs").instant;
const PHASES = Object.freeze(["callables", "events", "fleet"]);
const PARAMETER = "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK";
const PROJECT = "crm3-baf-ops-b8638";
const PARAMETER_FILE = ".env." + PROJECT;
const PROCESS_KEYS = Object.freeze(["schemaVersion", "documentType", "executable", "arguments", "cwd",
  "startedAtUtc", "resumedAtUtc", "completedAtUtc", "processId", "jobAssigned", "resumed", "exitCode",
  "failure", "cleanupErrors", "terminationRequested", "rootExited", "activeProcesses", "treeComplete",
  "outputComplete", "status", "authenticated", "deploymentAuthorized", "streams"]);
const read = (root, pointer) => json(privateBytes(root, pointer));
const equal = (left, right, label) => need(same(left, right), label);

function phaseDirectory31(ctx, phase) {
  need(PHASES.includes(phase), "fixed phase required");
  return path.join(ctx.evidenceDirectory, "deployment-attempts", ctx.approvalPointer.sha256, phase);
}

function commandArguments31(ctx, phase) {
  return ["--no-global-search-paths", path.join(ctx.repoRoot, x.CAPTURE), "--config",
    path.join(phaseDirectory31(ctx, phase), "context.json")];
}

// Only the already joined contract2 original selects this nonsecret value.
// This local artifact never establishes owner or process authority by itself.
function governedParameter31(ctx) {
  need(ctx.contract.schemaVersion === 2, "governed parameters require contract2");
  const envelope = read(ctx.evidenceDirectory, ctx.contract.intentPreparation);
  need(envelope.schemaVersion === 1 && envelope.documentType === "build31-business-intent-preparation",
    "original intent preparation required");
  equal(envelope.source, ctx.source, "parameter preparation source differs");
  equal(envelope.intendedHashInputs, ctx.contract.intendedHashInputs, "parameter intent differs");
  const parameters = read(ctx.evidenceDirectory, envelope.parametersOriginal);
  keys(parameters, ["schemaVersion", "documentType", "source", "parameters"], "governed parameter original");
  need(parameters.schemaVersion === 1 && parameters.documentType === "build31-business-intent-parameters",
    "original governed parameter input required");
  equal(parameters.source, ctx.source, "governed parameter source differs");
  equal(parameters.parameters, {[PARAMETER]: "false"}, "exact governed AppCheck parameter required");
  return {parametersOriginal: envelope.parametersOriginal, bytes: Buffer.from(PARAMETER + "=false\n")};
}

function parameterDirectory31(ctx, phase) {
  const directory = path.join(phaseDirectory31(ctx, phase), "parameters");
  const semantics = !nativePath.isAbsolute(ctx.repoRoot) && nativePath.win32.isAbsolute(ctx.repoRoot) ? nativePath.win32 : nativePath;
  for (const root of [ctx.repoRoot, ...(ctx.runtime?.nodeExecutable ? [semantics.dirname(ctx.runtime.nodeExecutable)] : [])]) {
    const relative = semantics.relative(root, directory);
    need(relative === ".." || relative.startsWith(".." + semantics.sep) || semantics.isAbsolute(relative),
      "governed parameter directory must be outside source/package/runtime tree");
  }
  return directory;
}

function createParameterConfig31(ctx, phase) {
  const original = governedParameter31(ctx), directory = parameterDirectory31(ctx, phase);
  x.physical(path.dirname(directory), true);
  fs.mkdirSync(directory, {mode: 0o700}); // Exclusive phase ownership; never reuse a directory.
  const file = path.join(directory, PARAMETER_FILE);
  fs.writeFileSync(file, original.bytes, {flag: "wx", mode: 0o600});
  const artifact = {schemaVersion: 1, documentType: "build31-business-governed-parameter-config", phase,
    source: ctx.source, approvalPointer: ctx.approvalPointer, intentPreparation: ctx.contract.intentPreparation,
    parametersOriginal: original.parametersOriginal, directory, file: pointer31(ctx.evidenceDirectory, file)};
  verifyParameterConfig31(ctx, phase, artifact);
  return artifact;
}

function verifyParameterConfig31(ctx, phase, artifact) {
  keys(artifact, ["schemaVersion", "documentType", "phase", "source", "approvalPointer", "intentPreparation",
    "parametersOriginal", "directory", "file"], "governed parameter config");
  need(artifact.schemaVersion === 1 && artifact.documentType === "build31-business-governed-parameter-config" &&
    artifact.phase === phase, "original governed parameter config required");
  equal(artifact.source, ctx.source, "parameter config source differs");
  equal(artifact.approvalPointer, ctx.approvalPointer, "parameter config decision differs");
  equal(artifact.intentPreparation, ctx.contract.intentPreparation, "parameter config preparation pointer differs");
  const original = governedParameter31(ctx), directory = parameterDirectory31(ctx, phase);
  equal(artifact.parametersOriginal, original.parametersOriginal, "parameter config original pointer differs");
  need(artifact.directory === directory && path.join(ctx.evidenceDirectory, artifact.file.file) === path.join(directory, PARAMETER_FILE),
    "parameter config original path differs");
  // Use the physical mapping for replay; the retained original path stays unchanged.
  const physicalDirectory = x.physical(directory, true);
  equal(fs.readdirSync(physicalDirectory), [PARAMETER_FILE], "sole governed dotenv file required");
  need(privateBytes(ctx.evidenceDirectory, artifact.file).equals(original.bytes), "governed dotenv bytes differ");
  return directory;
}

function bindNativeConfig31({ctx, phase, parameterConfig, options, sourceFunctions, Config}) {
  const directory = verifyParameterConfig31(ctx, phase, parameterConfig), config = options?.config;
  need(typeof Config === "function" && config && Object.getPrototypeOf(config) === Config.prototype,
    "actual installed Config required");
  need(options.project === PROJECT && options.projectAlias === undefined && config.projectDir === ctx.repoRoot &&
    config.path("functions") === path.join(ctx.repoRoot, "functions"), "selected project/source root or alias differs");
  need(Array.isArray(sourceFunctions) && sourceFunctions.length === 1 && sourceFunctions[0].source === "functions" &&
    sourceFunctions[0].codebase === "default" && !Object.hasOwn(sourceFunctions[0], "configDir"), "exact local source Functions config required");
  equal(config.src.functions, sourceFunctions, "loaded source Functions config differs");
  equal(config.get("functions"), sourceFunctions, "materialized source Functions config differs");
  const before = structuredClone(config.src), functions = structuredClone(sourceFunctions);
  functions[0].configDir = directory;
  // Invoke the admitted native implementation, never persist firebase.json.
  Config.prototype.set.call(config, "functions", functions);
  const expected = {...before, functions: structuredClone(functions)};
  const assertUnchanged = () => {
    verifyParameterConfig31(ctx, phase, parameterConfig);
    need(options.config === config && Object.getPrototypeOf(config) === Config.prototype && options.project === PROJECT &&
      options.projectAlias === undefined && config.projectDir === ctx.repoRoot, "governed Config identity changed");
    equal(config.src, expected, "governed native Config changed");
    equal(config.get("functions"), expected.functions, "governed materialized Config changed");
    need(config.path(directory) === directory && config.path("functions") === path.join(ctx.repoRoot, "functions"),
      "governed Config paths changed");
  };
  assertUnchanged();
  return {assertUnchanged};
}

function verifyPrefix31(predecessors, phase, expected) {
  need(Array.isArray(predecessors), "original predecessor pointers required");
  equal(predecessors.map(row => row.phase), PHASES.slice(0, PHASES.indexOf(phase)), "exact predecessor prefix required");
  for (const row of predecessors) {
    keys(row, ["phase", "pointer"], "predecessor");
    x.pointer(row.pointer);
  }
  if (expected !== undefined) equal(predecessors, expected, "original predecessor pointers changed");
}

function verifyPhaseStart31({ctx, record, predecessors}) {
  const root = ctx.evidenceDirectory, phase = record.phase, directory = phaseDirectory31(ctx, phase);
  const context = read(root, record.context), start = read(root, record.start);
  keys(context, ["schemaVersion", "documentType", "phase", "source", "approvalPointer", "evidenceDirectory", "configuration", "claim", "predecessors", "parameterConfig"], "phase context");
  need(context.schemaVersion === 1 && context.documentType === "build31-business-phase-context", "original phase context required");
  equal(context.source, ctx.source, "phase context source differs");
  equal(context.approvalPointer, ctx.approvalPointer, "phase context decision differs");
  need(context.phase === phase && context.evidenceDirectory === root, "phase context phase/root differs");
  need(path.join(root, record.context.file) === path.join(directory, "context.json"), "original context path differs");
  verifyPrefix31(context.predecessors, phase, predecessors);
  verifyParameterConfig31(ctx, phase, context.parameterConfig);
  const configuration = read(root, context.configuration), claim = read(root, context.claim);
  // Protected selection is external. Replaying this original config authenticates no issuer.
  keys(configuration, ["schemaVersion", "documentType", "authority", "execution"], "protected selection");
  need(configuration.schemaVersion === 1 && configuration.documentType === "build31-business-protected-selection", "fixed protected selection required");
  equal(configuration.authority.decisionPointer, ctx.approvalPointer, "selected decision differs");
  need(configuration.authority.sourceCommit === ctx.source.commit, "selected source differs");
  equal(configuration.authority.trustedVerifier.files, ctx.producerBindings, "selected producer population differs");
  keys(claim, ["schemaVersion", "documentType", "phase", "source", "approvalPointer", "predecessors", "claimedAtUtc"], "phase claim");
  need(claim.schemaVersion === 1 && claim.documentType === "build31-business-phase-claim" && claim.phase === phase, "original phase claim required");
  equal(claim.source, ctx.source, "phase claim source differs");
  equal(claim.approvalPointer, ctx.approvalPointer, "phase claim decision differs");
  verifyPrefix31(claim.predecessors, phase, context.predecessors);
  need(path.join(root, context.claim.file) === path.join(directory, "phase-claim.json"), "phase claim path differs");
  keys(start, ["schemaVersion", "documentType", "phase", "source", "approvalPointer", "context", "claim", "predecessors",
    "startedAtUtc", "executable", "nodeSha256", "cwd", "arguments", "sourceBefore", "producerBindings", "parameterConfig"], "cohort start");
  need(start.schemaVersion === 1 && start.documentType === "build31-business-cohort-start" && start.phase === phase, "original cohort start required");
  equal(start.source, ctx.source, "phase start measured source differs");
  equal(start.approvalPointer, ctx.approvalPointer, "phase start measured approval differs");
  equal(start.producerBindings, ctx.producerBindings, "phase start producer population differs");
  need(start.executable === ctx.runtime.nodeExecutable && start.nodeSha256 === ctx.runtime.nodeSha256 && start.cwd === ctx.repoRoot,
    "phase start selected runtime differs");
  for (const name of ["source", "approvalPointer", "context", "startedAtUtc", "executable", "nodeSha256", "cwd", "arguments", "sourceBefore", "producerBindings"])
    equal(start[name], record[name], "cohort start differs: " + name);
  equal(start.claim, context.claim, "cohort claim differs");
  equal(start.parameterConfig, context.parameterConfig, "cohort parameter config differs");
  verifyPrefix31(start.predecessors, phase, context.predecessors);
  need(path.join(root, record.start.file) === path.join(directory, "attempt-start.json"), "cohort start path differs");
  equal(record.arguments, commandArguments31(ctx, phase), "actual fixed child argv differs");
  need(time(claim.claimedAtUtc) <= time(start.startedAtUtc) &&
    time(ctx.decision.executionWindow.notBeforeUtc) <= time(start.startedAtUtc) &&
    time(start.startedAtUtc) <= time(ctx.decision.executionWindow.notAfterUtc), "phase start outside approved interval");
  return {context, start, claim};
}

function verifyCohortProcess31({ctx, record, predecessors}) {
  need(record.schemaVersion === 2, "owned-process cohort2 required");
  const {context, start, claim} = verifyPhaseStart31({ctx, record, predecessors});
  const root = ctx.evidenceDirectory, process = read(root, record.process);

  verifyOwnedProcess31({root,process,executable:record.executable,args:record.arguments,cwd:record.cwd,
    earliestUtc:start.startedAtUtc,latestUtc:record.completedAtUtc,stdout:record.stdout,stderr:record.stderr});
  need(time(claim.claimedAtUtc)<=time(start.startedAtUtc)&&process.completedAtUtc===record.completedAtUtc,"original cohort process chronology differs");
  return {context, start, process, claim};
}

function verifyOwnedProcess31({root,process,executable,args,cwd,earliestUtc,latestUtc,stdout,stderr}) {
  keys(process, PROCESS_KEYS, "owned process result");
  need(process.schemaVersion === 1 && process.documentType === "private-windows-owned-process-result" &&
    process.status === "SUCCESS" && process.exitCode === 0 && process.failure === null &&
    process.jobAssigned === true && process.resumed === true && process.rootExited === true &&
    process.treeComplete === true && process.activeProcesses === 0 && process.outputComplete === true &&
    process.terminationRequested === false && same(process.cleanupErrors, []) &&
    process.authenticated === false && process.deploymentAuthorized === false &&
    Number.isSafeInteger(process.processId) && process.processId > 0, "complete owned child/tree/streams required");
  equal(process.executable, executable, "original process executable differs");
  equal(process.arguments, args, "original process argv differs");
  equal(process.cwd, cwd, "original process cwd differs");
  need(time(earliestUtc) <= time(process.startedAtUtc) &&
    time(process.startedAtUtc) <= time(process.resumedAtUtc) && time(process.resumedAtUtc) <= time(process.completedAtUtc) &&
    time(process.completedAtUtc) <= time(latestUtc), "original process chronology differs");
  keys(process.streams, ["stdout", "stderr"], "owned streams");
  for (const name of ["stdout", "stderr"]) {
    const original={stdout,stderr}[name],stream = process.streams[name], bytes = privateBytes(root, original);
    keys(stream, ["bytes", "observedBytes", "eof", "error", "sha256", "path"], "original stream");
    need(stream.eof === true && stream.error === null && stream.bytes === bytes.length &&
      stream.observedBytes === bytes.length && stream.sha256 === sha(bytes) &&
      stream.path === path.join(root, original.file), "original complete stream differs");
  }
  return process;
}

// The selected complete installation is rechecked by the shared boundary before
// and after every child. These measurements do not authenticate its selector.
function runCohortSupervisor31({python,requestFile,evidenceDirectory,directory,environment,limits}) {
  const root=nativePath.resolve(evidenceDirectory),dir=nativePath.resolve(directory);
  const relative=nativePath.relative(root,dir);
  need(relative&&relative!==".."&&!relative.startsWith(".."+nativePath.sep)&&!nativePath.isAbsolute(relative),"supervisor output escaped evidence root");
  x.physical(root,true);x.physical(dir,true);
  need(requestFile===nativePath.join(dir,"process-request.json"),"fixed cohort process request required");
  x.physical(requestFile);
  const retain=result=>{
    for(const name of ["stdout","stderr"])fs.writeFileSync(nativePath.join(dir,"supervisor-"+name+".bin"),
      result[name]??Buffer.alloc(0),{flag:"wx",mode:0o600});
  };
  let result;
  try {
    result=pythonRuntime.runPythonRunner31(python,requestFile,
      {cwd:dir,env:environment,windowsHide:true,encoding:null,maxBuffer:1024*1024,
        timeout:(limits.commandSeconds+limits.cleanupSeconds*3+15)*1000});
  } catch(error) {
    if(error.pythonResult) {
      try {retain(error.pythonResult);}
      catch(persistence) {throw new AggregateError([error,persistence],"Python boundary and original-output retention failed");}
    }
    throw error;
  }
  retain(result);
  return result;
}

function pointer31(root, file) {
  root = nativePath.resolve(root); file = nativePath.resolve(file);
  const relative = nativePath.relative(root, file).split(nativePath.sep).join("/");
  need(relative && !relative.startsWith("../") && !nativePath.isAbsolute(relative), "private path escaped evidence");
  x.physical(root,true);x.physical(file);
  const stat = fs.lstatSync(file); need(stat.isFile() && !stat.isSymbolicLink() && stat.size<=64*1024*1024, "bounded regular original required");
  const bytes = fs.readFileSync(file);
  return {file: relative, sha256: sha(bytes), bytes: bytes.length};
}

function save31(root, file, value) {
  root=nativePath.resolve(root);file=nativePath.resolve(file);
  const relative=nativePath.relative(root,file);
  need(relative&&relative!==".."&&!relative.startsWith(".."+nativePath.sep)&&!nativePath.isAbsolute(relative),"write escaped evidence root");
  x.physical(root,true);x.physical(nativePath.dirname(file),true);
  const bytes=Buffer.from(JSON.stringify(value,null,2)+"\n");
  need(bytes.length<=64*1024*1024,"evidence write bound exceeded");
  fs.writeFileSync(file, bytes, {flag:"wx", mode:0o600});
  return pointer31(root, file);
}

module.exports = {PHASES, PROCESS_KEYS, phaseDirectory31, commandArguments31, verifyPrefix31,
  verifyPhaseStart31, verifyOwnedProcess31, verifyCohortProcess31, runCohortSupervisor31, pointer31, save31,
  governedParameter31, createParameterConfig31, verifyParameterConfig31, bindNativeConfig31};
