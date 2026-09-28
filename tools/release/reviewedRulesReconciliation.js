"use strict";

// Read-only outcome adjudication. Never deploys, rewrites CLI results, or grants
// retrospective deployment authority. The original approval remains mandatory.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual: same} = require("node:util");
const runtimeProof = require("./reviewedRulesRuntime.js");
const PROJECT = "crm3-baf-ops-b8638";
const RELEASE = `projects/${PROJECT}/releases/cloud.firestore`;
const METHOD_FILE = "release/approvals/build30-rules-observed-state-method-approval.json";
const EVIDENCE_FILE = "release/evidence/build30-rules-observed-state-reconciliation.json";
const VERIFIER_FILES = Object.freeze([
  "tools/release/collectFirestoreRulesIndexesReadback.js",
  "tools/release/collectFunctionFleetRuntimeIdentityReadback.js",
  "tools/release/collectFunctionsIamDependenciesReadback.js",
  "tools/release/collectProductionGlobalPullBackend.js",
  "tools/release/deploymentFleetContract.js",
  "tools/release/reviewedBackendControls.js",
  "tools/release/reviewedBackendVerifierAuthority.js",
  "tools/release/reviewedFirestoreRulesDeployment.js",
  "tools/release/reviewedRulesReconciliation.js",
  "tools/release/reviewedRulesRuntime.js",
  "tools/release/reviewedRulesRuntimeCollector.js",
  "tools/release/scopedCallableInvokerIam.js",
  "tools/release/scopedCallableInvokerIamPublic.js",
  "tools/release/stagedPromotionSourceAuthority.js",
]);
const CONFLICT = `Request to https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases had HTTP Error: 409, Requested entity already exists`;
const need = (value, message) => { if (!value) throw Error(`Rules reconciliation: ${message}.`); };
const sha = value => crypto.createHash("sha256").update(value).digest("hex").toUpperCase();
const oid = value => typeof value === "string" && /^[0-9a-f]{40}$/.test(value);
const hash = value => typeof value === "string" && /^[0-9a-f]{64}$/i.test(value);
const equalHash = (a,b) => hash(a) && hash(b) && a.toUpperCase() === b.toUpperCase();
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
function keys(value, expected, label) {need(object(value) && same(Object.keys(value).sort(), [...expected].sort()), label);}
function text(value) {return typeof value === "string" && value.trim().length > 0 && value.length <= 12000;}
function accountable(value) {
  if (!text(value) || value.length > 4000) return false;
  // Comparison only, matching the existing App Check identity admission.
  // Preserve exact original names/references in their hash-bound Git record.
  let normalized=value.normalize("NFKD").replace(/[\p{Default_Ignorable_Code_Point}\p{M}]/gu,"")
    .replace(/[\p{P}\p{S}\s]+/gu," ").trim();
  const stems=["TODO","FIXTURE","REPLACE"];
  for(const marker of [...stems.flatMap(stem=>[`${stem}APPROVER`,`${stem}REFERENCE`]),...stems]) {
    normalized=normalized.replace(new RegExp(`^${[...marker].join("\\s*")}`,"iu"),marker);
  }
  return normalized.length>0 && !/^(TODO|FIXTURE|REPLACE)($|[^\p{L}\p{N}]|\d|APPROVER|REFERENCE)/iu.test(normalized);
}
function instant(value) {
  need(typeof value === "string", "UTC timestamp missing");
  const m = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  need(m && !m[1].startsWith("0000-"), "explicit UTC timestamp required");
  const ms = Date.parse(m[1]+"Z");
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0,19) === m[1], "invalid UTC calendar");
  return BigInt(ms)*1000000n + BigInt((m[2] ?? "").padEnd(9,"0"));
}
function git(root,args) {return execFileSync("git",["--no-replace-objects","-C",root,...args],{windowsHide:true,stdio:["ignore","pipe","pipe"]});}
function ancestor(root,a,b,label) {
  need(oid(a) && oid(b),label);
  try {git(root,["merge-base","--is-ancestor",a,b]);} catch {throw Error(`Rules reconciliation: ${label}.`);}
}
const MEASUREMENT_KEYS = ["executionRoot","authorityRoot","evidenceRoot","sourceCommit","sourceTree","functionsTree","approvalAuthority","startedAtUtc","completedAtUtc","exitCode","command","runtime","before","after"];
const PRIVATE_PATHS = ["executionRoot","authorityRoot","evidenceRoot"];
const PROJECTION = Object.freeze({algorithm:"sha256-utf8-forward-slash-path",fields:PRIVATE_PATHS});
function projectRetainedMeasurements(rawBytes) {
  need(Buffer.isBuffer(rawBytes),"exact retained measurement bytes required");
  const raw=JSON.parse(rawBytes.toString("utf8"));
  keys(raw,MEASUREMENT_KEYS,"retained measurement field inventory differs");
  const measurements=structuredClone(raw);
  for(const name of PRIVATE_PATHS) {
    need(typeof raw[name] === "string" && (/^[A-Za-z]:[\\/]/.test(raw[name]) || raw[name].startsWith("/")),"retained path must be absolute text");
    measurements[`${name}Sha256`]=sha(raw[name].replaceAll("\\","/"));delete measurements[name];
  }
  return {schemaVersion:1,evidenceType:"rules-failed-command-public-measurements",projection:structuredClone(PROJECTION),
    sourceMeasurementsSha256:sha(rawBytes),measurements};
}
function validateRetainedArtifacts(command, evidenceRoot, readBound, functionTree) {
  const projected=readBound(evidenceRoot,command.measurements,false);
  keys(projected,["schemaVersion","evidenceType","projection","sourceMeasurementsSha256","measurements"],"public measurement projection shape");
  need(projected.schemaVersion === 1 && projected.evidenceType === "rules-failed-command-public-measurements" && same(projected.projection,PROJECTION) && equalHash(projected.sourceMeasurementsSha256,command.measurementsSha256),"declared privacy projection/raw hash differs");
  const m=projected.measurements;
  keys(m,MEASUREMENT_KEYS.map(key=>PRIVATE_PATHS.includes(key)?`${key}Sha256`:key),"projected measurement fields differ");
  for(const name of PRIVATE_PATHS) need(hash(m[`${name}Sha256`]),"projected path hash missing");
  need(equalHash(m.executionRootSha256,command.executionSource.rootSha256) && m.sourceCommit === command.source.commit && m.sourceTree === command.source.tree && m.functionsTree === functionTree,"projected source/path binding differs");
  for(const field of ["approvalAuthority","startedAtUtc","completedAtUtc","exitCode","command","runtime"]) need(same(m[field],command[field]),"projected command/window/runtime differs");
  need(same(m.before,command.executionSource.before) && same(m.after,command.executionSource.after),"projected execution source differs");
  need(equalHash(command.processResult.physicalSha256,command.processResultSha256),"actual process hash differs");
  const result=readBound(evidenceRoot,command.processResult,false);
  keys(result,["startedAtUtc","completedAtUtc","exitCode","status","resolvedNode"],"actual process fields differ");
  need(result.status === "ACTUAL_PROCESS_RESULT_NOT_COMPLETION_EVIDENCE" && same(result.resolvedNode,command.command.resolvedNode) &&
    ["startedAtUtc","completedAtUtc","exitCode"].every(field=>same(result[field],command[field])),"actual process window/exit/Node differs");
}
function verifyMethodAuthority({repoRoot, methodAuthorityRoot, pointer, reconciliation, command, failedPointer, receipt, successorDecision}) {
  keys(pointer,["commit","file","sha256"],"method authority pointer shape");
  need(oid(pointer.commit) && pointer.file === METHOD_FILE && hash(pointer.sha256),"named immutable method decision required");
  const bytes = git(methodAuthorityRoot,["show",`${pointer.commit}:${pointer.file}`]);
  need(equalHash(sha(bytes),pointer.sha256),"method decision Git bytes differ");
  const decision = JSON.parse(bytes.toString("utf8"));
  keys(decision,["schemaVersion","documentType","approved","intendedBuildNumber","projectId","releaseName","source","deploymentApprovalAuthority","reviewedVerifier","failedCommand","retainedSourceEvidence","acceptedRulesetName","acceptedRulesetCreateTime","approvedBy","ownerInstruction","ownerInstructionReference","decidedAtUtc","recordedAtUtc","furtherMutationAuthorized","cliSuccessClaimed"],"method decision shape");
  need(decision.schemaVersion === 1 && decision.documentType === "governed-rules-observed-state-method-approval" && decision.approved === true && decision.intendedBuildNumber === 30 && decision.projectId === PROJECT && decision.releaseName === RELEASE && decision.furtherMutationAuthorized === false && decision.cliSuccessClaimed === false,"method scope differs");
  need(same(decision.source,reconciliation.source) && same(decision.deploymentApprovalAuthority,receipt.approvalAuthority) && same(decision.failedCommand,failedPointer),"method source/original approval/failed evidence differs");
  need(accountable(decision.approvedBy) && accountable(decision.ownerInstructionReference) && text(decision.ownerInstruction),"actual non-placeholder approver and fresh instruction evidence required");
  const retained=decision.retainedSourceEvidence;
  keys(retained,["measurementsSha256","measurementsProjectionSha256","processResultSha256","privacyReviewReference","derivationReviewReference"],"retained evidence review shape");
  need(equalHash(retained.measurementsSha256,command.measurementsSha256) && equalHash(retained.measurementsProjectionSha256,command.measurements.physicalSha256) && equalHash(retained.processResultSha256,command.processResultSha256) && accountable(retained.privacyReviewReference) && accountable(retained.derivationReviewReference),"explicit exact raw/projection/privacy review required");
  keys(decision.reviewedVerifier,["commit","files","reviewReference"],"reviewed verifier custody shape");
  const verifier = decision.reviewedVerifier;
  need(oid(verifier.commit) && accountable(verifier.reviewReference),"reviewed verifier commit/reference missing or placeholder");
  keys(verifier.files,VERIFIER_FILES,"exact verifier file inventory required");
  ancestor(methodAuthorityRoot,successorDecision.sourceCommit,verifier.commit,"verifier does not descend from deployed source");
  ancestor(methodAuthorityRoot,verifier.commit,pointer.commit,"method review must follow verifier custody");
  need(verifier.commit !== pointer.commit,"method review cannot be self-custodied with verifier");
  ancestor(methodAuthorityRoot,receipt.approvalAuthority.commit,pointer.commit,"method review must retain original deployment approval");
  const head=git(repoRoot,["rev-parse","HEAD"]).toString("utf8").trim();
  // Exact-T read-only preparation is allowed before the later artifact source N.
  // An artifact descendant must itself contain the committed method decision R.
  if(head !== verifier.commit) ancestor(repoRoot,pointer.commit,head,"artifact source does not retain method custody");
  for(const file of VERIFIER_FILES) {
    const committed = git(methodAuthorityRoot,["show",`${verifier.commit}:${file}`]);
    need(equalHash(sha(committed),verifier.files[file]) && equalHash(sha(fs.readFileSync(path.join(repoRoot,file))),verifier.files[file]),"loaded reviewed verifier bytes differ");
  }
  const decided=instant(decision.decidedAtUtc),recorded=instant(decision.recordedAtUtc);
  const custody=BigInt(git(methodAuthorityRoot,["show","-s","--format=%ct",pointer.commit]).toString("utf8").trim())*1000000000n;
  const verifierCustody=BigInt(git(methodAuthorityRoot,["show","-s","--format=%ct",verifier.commit]).toString("utf8").trim())*1000000000n;
  need(instant(command.completedAtUtc) <= decided && verifierCustody+1000000000n <= decided && decided <= recorded && recorded < custody+1000000000n && custody <= BigInt(Date.now())*1000000n,"method decision/custody chronology invalid");
  need(typeof decision.acceptedRulesetName === "string" && new RegExp(`^projects/${PROJECT}/rulesets/[A-Za-z0-9_-]+$`).test(decision.acceptedRulesetName),"accepted Ruleset identity invalid");
  const created=instant(decision.acceptedRulesetCreateTime);
  need(instant(command.startedAtUtc) <= created && created <= instant(command.completedAtUtc),"accepted new Ruleset was not created within actual failed command");
  return {decision,decided,recorded,custody};
}
function validateRulesReconciliation({repoRoot,evidenceRoot,methodAuthorityRoot,approval,receipt,successorDecision,declaration,source,runtimeAuthority,readBound,validateObservation}) {
  need(approval.intendedBuildNumber === 30 && successorDecision.buildNumber === 30,"original authority must approve Build30");
  const pointer=receipt.firestoreDeployment.rulesReconciliationEvidence;
  need(pointer?.file === EVIDENCE_FILE,"distinct named reconciliation evidence required");
  const reconciliation=readBound(evidenceRoot,pointer);
  keys(reconciliation,["schemaVersion","evidenceType","decision","projectId","source","approvalAuthority","methodApprovalAuthority","failedCommand","recordedAtUtc","receiptSha256"],"reconciliation evidence shape");
  need(reconciliation.schemaVersion === 1 && reconciliation.evidenceType === "reviewed-firestore-rules-observed-state-reconciliation" && reconciliation.decision === "PASS_APPROVED_RULES_OBSERVED_STATE_RECONCILED" && reconciliation.projectId === PROJECT,"reconciliation type/project differs");
  const expectedSource={commit:successorDecision.sourceCommit,tree:successorDecision.sourceTree};
  need(same(reconciliation.source,expectedSource) && same(reconciliation.approvalAuthority,receipt.approvalAuthority),"reconciliation source/original approval differs");
  need(reconciliation.failedCommand?.file !== declaration.commandEvidenceFile && reconciliation.failedCommand?.file !== EVIDENCE_FILE,"failed attempt cannot impersonate a successful command");
  const command=readBound(evidenceRoot,reconciliation.failedCommand);
  keys(command,["schemaVersion","evidenceType","decision","projectId","source","approvalAuthority","ciAuthority","target","attemptNumber","startedAtUtc","completedAtUtc","command","executionSource","runtime","exitCode","cliResult","beforeReadback","measurementsSha256","processResultSha256","measurements","processResult","receiptSha256"],"failed command shape");
  need(command.schemaVersion === 1 && command.evidenceType === "reviewed-firestore-rules-failed-command" && command.decision === "ACTUAL_RULES_CLI_RELEASE_CONFLICT" && command.projectId === PROJECT && command.target === "firestore:rules" && command.attemptNumber === 13 && command.exitCode === 1 && hash(command.measurementsSha256) && hash(command.processResultSha256),"only retained actual attempt13 exit1 release-conflict is admitted");
  need(same(command.source,expectedSource) && same(command.approvalAuthority,receipt.approvalAuthority) && equalHash(command.approvalAuthority.sha256,successorDecision.approvalSha256) && command.approvalAuthority.commit === successorDecision.approvalCommit,"failed command source/approval differs");
  need(same(command.ciAuthority,{file:successorDecision.ciFile,sha256:successorDecision.ciSha256,commit:successorDecision.approvalCommit}),"failed command original CI differs");
  need(same(command.command,{executable:"node",arguments:require("./reviewedFirestoreRulesDeployment.js").RULES_COMMAND,resolvedNode:runtimeAuthority.identity.node}),"failed command is not exact reviewed Rules-only invocation");
  keys(command.executionSource,["rootSha256","before","after"],"failed execution source shape");
  need(equalHash(command.executionSource.rootSha256,declaration.executionRootSha256),"failed execution checkout differs");
  for(const point of [command.executionSource.before,command.executionSource.after]) need(point?.commit === expectedSource.commit && point.tree === expectedSource.tree && point.originMain === expectedSource.commit && point.branch === "main" && point.governedWorktreeClean === true && point.materialChangeCount === 0 && same(point.materialPathSha256,[]),"failed execution source is not exact clean main");
  validateRetainedArtifacts(command,evidenceRoot,readBound,receipt.sourceAuthority.functionsGitObjectId);
  need(same(readBound(evidenceRoot,command.cliResult,false),{status:"error",error:CONFLICT}),"only exact project release409 is admitted, never compiler503 or generic error");
  const before=readBound(evidenceRoot,command.beforeReadback);
  const beforeWindow=validateObservation(before,{sourceCommit:expectedSource.commit,sourceTree:expectedSource.tree,declaration,source,before:true});
  const started=instant(command.startedAtUtc),completed=instant(command.completedAtUtc);
  need(instant(successorDecision.recordedAtUtc) <= beforeWindow.start && instant(successorDecision.custodyCommitTimeUtc) <= beforeWindow.start && beforeWindow.end <= started && started <= completed && completed <= BigInt(Date.now())*1000000n,"failed attempt predates original custody or has invalid chronology");
  runtimeProof.validateCommandRuntime({runtime:command.runtime,approved:runtimeAuthority,startedAtUtc:command.startedAtUtc,completedAtUtc:command.completedAtUtc,notBeforeUtc:before.capturedAtUtc,closureAtUtc:receipt.recordedAtUtc});
  const reviewed=verifyMethodAuthority({repoRoot,methodAuthorityRoot,pointer:reconciliation.methodApprovalAuthority,reconciliation,command,failedPointer:reconciliation.failedCommand,receipt,successorDecision});
  const finalPointer=receipt.cleanMainLiveReadbacks?.firestoreRulesAndIndexes;
  const after=readBound(evidenceRoot,{file:finalPointer?.file,physicalSha256:finalPointer?.physicalSha256,canonicalReceiptSha256:finalPointer?.canonicalReceiptSha256});
  const afterWindow=validateObservation(after,{sourceCommit:expectedSource.commit,sourceTree:expectedSource.tree,declaration,source,before:false});
  const recorded=instant(reconciliation.recordedAtUtc),closure=instant(receipt.recordedAtUtc);
  need(reviewed.recorded <= afterWindow.start && reviewed.custody+1000000000n <= afterWindow.start && completed <= afterWindow.start && afterWindow.end <= recorded && recorded <= closure && closure <= BigInt(Date.now())*1000000n,"fresh STRICT observation must follow committed method review and precede honest closure");
  const rules=after.outputs.rules,deployed=receipt.firestoreDeployment;
  need(rules.rulesetName === reviewed.decision.acceptedRulesetName && rules.rulesetCreateTime === reviewed.decision.acceptedRulesetCreateTime && rules.rulesetName !== declaration.priorRulesetName && deployed.rulesActiveByteExact === true && deployed.strictLiveReadbackPassed === true && deployed.rulesetName === rules.rulesetName && deployed.rulesetCreateTime === rules.rulesetCreateTime,"final observed Ruleset differs from expressly accepted exact outcome");
  return {ok:true,decision:"PASS_REVIEWED_RULES_OBSERVED_STATE_RECONCILIATION"};
}
function validateBoundaryInput(input) {
  need(object(input) && input.expectedBuildNumber === 30,"explicit Build30 validation input required");
  const {repoRoot,evidenceRoot=repoRoot,methodAuthorityRoot=repoRoot,approval,receipt}=input;
  const successorDecision=require("./stagedPromotionSourceAuthority.js").verifySuccessorDelegatedDecision({repoRoot,approval,approvalAuthority:receipt.approvalAuthority,sourceAuthority:receipt.sourceAuthority,expectedBuildNumber:30});
  need(successorDecision.ok === true,"original source/CI/deployment authority invalid");
  return require("./reviewedFirestoreRulesDeployment.js").validateRulesDeploymentBoundary({repoRoot,evidenceRoot,methodAuthorityRoot,approval,receipt,successorDecision});
}
module.exports={validateRulesReconciliation,validateBoundaryInput,verifyMethodAuthority,projectRetainedMeasurements,VERIFIER_FILES,METHOD_FILE,EVIDENCE_FILE,CONFLICT};
if(require.main === module) {
  try {
    const args=process.argv.slice(2);
    need(args.length === 2 && args[0] === "--validate-boundary","use --validate-boundary INPUT.json");
    console.log(JSON.stringify(validateBoundaryInput(JSON.parse(fs.readFileSync(args[1],"utf8")))));
  } catch(error) {console.error(error.message);process.exitCode=1;}
}
