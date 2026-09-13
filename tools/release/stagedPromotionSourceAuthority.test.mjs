import assert from "node:assert/strict";
import {test} from "node:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {verifyStagedPromotionSourceAuthority, verifySuccessorDelegatedDecision} = require("./stagedPromotionSourceAuthority.js");
const {readDeploymentFleetContract, deploymentCountsMatch, measuredFunctionNamesMatch} =
  require("./deploymentFleetContract.js");
const {sealReceipt: sealUnsealedReceipt} = require("./collectProductionGlobalPullBackend.js");
const sealReceipt = ({receiptSha256, ...body}) => sealUnsealedReceipt(body);
const PROJECT = "crm3-baf-ops-b8638";
const PASS = "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK";
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readMeasured = (file) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, file), 'utf8'));

test("deployment fleet follows the exact historical or remediation source, not the checkout", () => {
  const historical = readDeploymentFleetContract(repositoryRoot, "c00c77e2a04a0a79a2bfab6d711e5ad2b59e6d56");
  const remediation = readDeploymentFleetContract(repositoryRoot, "c6038fe7ff3200645ab6a55bbe033eb726f1dfc1");
  assert.deepEqual([historical.functionCount, historical.callableCount,
    historical.eventAndProtocolTriggerCount, historical.schedulerCount, historical.runtimePrincipalCount],
  [15, 9, 5, 1, 15]);
  assert.deepEqual([remediation.functionCount, remediation.callableCount,
    remediation.eventAndProtocolTriggerCount, remediation.schedulerCount, remediation.runtimePrincipalCount],
  [19, 13, 5, 1, 15]);
  assert.deepEqual(remediation.functionNames.filter((name) => !historical.functionNames.includes(name)), [
    "assignPublishedTemplateVersionV2", "executeMaintenanceWorkflowCommandV2",
    "mutateAssetHierarchyV2", "mutateChargeAbnormalityV2",
  ]);
  assert.equal(deploymentCountsMatch(historical, historical), true);
  assert.equal(deploymentCountsMatch(remediation, remediation), true);
  assert.equal(deploymentCountsMatch(remediation, historical), false);
  assert.equal(deploymentCountsMatch(historical, remediation), false);
  for (const value of ["19", [19], true, null]) {
    assert.equal(deploymentCountsMatch(remediation, {...remediation, functionCount: value}), false);
  }
  assert.throws(() => readDeploymentFleetContract(repositoryRoot, "HEAD"), /exact source commit/);
});

test("measured fleet requires the exact endpoint set, including duplicate and substitution refusal", () => {
  const contract = readDeploymentFleetContract(repositoryRoot, "c6038fe7ff3200645ab6a55bbe033eb726f1dfc1");
  const records = contract.functionNames.map((name) => ({name}));
  assert.equal(measuredFunctionNamesMatch(contract, [...records].reverse()), true);
  assert.equal(measuredFunctionNamesMatch(contract, records.slice(1)), false);
  assert.equal(measuredFunctionNamesMatch(contract, [records[1], ...records.slice(1)]), false);
  assert.equal(measuredFunctionNamesMatch(contract, [{name: "unapprovedEndpoint"}, ...records.slice(1)]), false);
  assert.equal(measuredFunctionNamesMatch(contract, [{name: [records[0].name]}, ...records.slice(1)]), false);
});

test("a re-sealed duplicate measured endpoint cannot replace a historical endpoint", (t) => {
  const f = delegatedCurrentFixture(t);
  assert.equal(f.verify().ok, true);
  f.currentChildren.functionFleet.outputs.functions[0].name =
    f.currentChildren.functionFleet.outputs.functions[1].name;
  f.persistCurrent();
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons.join(" "), /function source hashes or update times/);
});

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-staged-source-test-"));
  t.after(() => {
    const resolved = fs.realpathSync(root);
    assert.equal(path.dirname(resolved), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(resolved), /^crm3-staged-source-test-/);
    fs.rmSync(resolved, {recursive: true, force: true});
  });
  const git = (...args) => execFileSync("git", ["-C", root, ...args],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  git("init", "--quiet");
  fs.writeFileSync(path.join(root, "backend.txt"), "deployed backend\n");
  fs.mkdirSync(path.join(root, 'functions/src'), {recursive: true});
  fs.writeFileSync(path.join(root, 'functions/src/index.ts'), '// fixture backend\n');
  for (const file of ['release/function-fleet-runtime-identity-policy.json', 'release/lr03-lr06-functions-live-readback-policy.json']) {
    fs.mkdirSync(path.dirname(path.join(root, file)), {recursive: true});
    fs.copyFileSync(path.join(repositoryRoot, file), path.join(root, file));
  }
  for (const file of ['firestore.rules', 'firestore.indexes.json', 'functions/src/index.ts',
    'functions/package.json', 'functions/package-lock.json']) {
    const raw = execFileSync('git', ['-C', repositoryRoot, 'show', `2ab554d143bd778cfa1b4d9ab2ed3c35cf62b056:${file}`]);
    fs.writeFileSync(path.join(root, file), raw);
  }
  git("add", ".");
  git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
    "commit", "--quiet", "-m", "deployed fixture");
  const objects = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'],
    {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(root, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(root, '.git/objects/info/alternates'), `${objects.replace(/\\/g, '/')}\n`);
  const commit = '2ab554d143bd778cfa1b4d9ab2ed3c35cf62b056';
  const tree = git('rev-parse', `${commit}^{tree}`);
  const functionTree = git('rev-parse', `${commit}:functions`);
  function write(file, value) {
    const location = path.join(root, file);
    fs.mkdirSync(path.dirname(location), {recursive: true});
    const bytes = `${JSON.stringify(value, null, 2)}\n`;
    fs.writeFileSync(location, bytes);
    return sha(bytes);
  }
  const approvalPath = "release/approvals/build27-backend-deployment-approval.json";
  const backendPath = "release/backend.json";
  const versionPath = "release/version.json";
  const approval = readMeasured('release/approvals/build27-backend-deployment-approval.json');
  Object.assign(approval.sourceAuthority, {commit, tree, functionTree});
  const receipt = readMeasured('release/evidence/build27-backend-deployment-closure.json');
  Object.assign(receipt.sourceAuthority, {commit, tree, functionsGitObjectId: functionTree});
  receipt.approvalAuthority.file = approvalPath;
  receipt.cleanMainLiveReadbacks = {};
  const children = {};
  for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
    const file = {functionFleet: 'build27-function-fleet-runtime-identity-readback.json',
      iamDependencies: 'build27-functions-iam-dependencies-readback.json',
      firestoreRulesAndIndexes: 'build27-firestore-rules-indexes-live-readback.json'}[key];
    const child = readMeasured(`release/evidence/${file}`);
    for (const point of ['before', 'after']) Object.assign(child.source[point], {commit, tree, originMain: commit});
    children[key] = sealReceipt(child);
    receipt.cleanMainLiveReadbacks[key] = {file: `release/${key}.json`,
      physicalSha256: write(`release/${key}.json`, children[key]),
      canonicalReceiptSha256: children[key].receiptSha256.toUpperCase()};
  }
  const version = {sourceBaseline: {commit}, requiredSource: {
    exactFunctionFleetDeploymentSourceCommit: commit,
    exactFunctionFleetDeploymentPullRequest: 355,
    exactFunctionFleetDeploymentReceiptFile: backendPath}};
  const policy = {firebaseProjectId: PROJECT,
    versionPolicy: {sourceDocumentFile: versionPath},
    finalization: {exactFunctionFleetDeploymentReceiptFile: backendPath}};
  const deployed = {functionFleetEvidenceFile: backendPath,
    functionFleetSourceCommit: commit, deploymentApprovalFile: approvalPath};
  const state = {authorityPlanes: {deployedBackend: deployed}};
  function persist() {
    deployed.deploymentApprovalSha256 = write(approvalPath, approval);
    receipt.approvalAuthority.sha256 = deployed.deploymentApprovalSha256;
    deployed.functionFleetEvidenceSha256 = write(backendPath, receipt);
    version.requiredSource.exactFunctionFleetDeploymentReceiptSha256 = deployed.functionFleetEvidenceSha256;
    policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = deployed.functionFleetEvidenceSha256;
    policy.versionPolicy.sourceDocumentSha256 = write(versionPath, version);
    write("release/current-successor-state.json", state);
  }
  persist();
  return {root, git, commit, tree, write, approval, receipt, children, version, policy,
    deployed, state, persist, verify: () => verifyStagedPromotionSourceAuthority({repoRoot: root, releasePolicy: policy})};
}

// Synthetic later readback, not a production deployment claim. The approval
// and both source Git objects come from their real immutable custody. The
// historical Build27 receipt and children remain unchanged in this fixture.
function delegatedCurrentFixture(t) {
  const f = fixture(t);
  const approvalPath = 'release/approvals/build28-backend-deployment-approval.json';
  const approval = readMeasured(approvalPath);
  const receipt = structuredClone(f.receipt);
  const source = approval.sourceAuthority;
  Object.assign(receipt.sourceAuthority, {commit: source.commit, tree: source.tree,
    functionsGitObjectId: source.functionTree, pullRequestNumber: source.pullRequestNumber,
    postMergeReleaseGateRunId: source.requiredPostMergeReleaseGateRunId});
  receipt.authorityChronology = {
    delegatedDecisionAtUtc: approval.approvalEvidence.delegatedDecisionAtUtc,
    earliestFunctionUpdateTime: '2026-09-08T21:01:00.123456788Z',
    latestFunctionUpdateTime: '2026-09-08T21:02:00.123456789Z',
    allObservedFunctionUpdatesPostdateDelegatedDecision: true,
    deploymentWasRetroactivelyAuthorized: false,
  };
  receipt.recordedAtUtc = '2026-09-08T21:03:00Z';
  receipt.deployment.sourceRuntimeHash = '1'.repeat(40);
  receipt.approvalAuthority.file = approvalPath;
  const children = structuredClone(f.children);
  for (const [key, child] of Object.entries(children)) {
    for (const point of ['before', 'after']) Object.assign(child.source[point], {
      commit: source.commit, tree: source.tree, originMain: source.commit});
    if (key !== 'firestoreRulesAndIndexes') {
      child.outputs.functions.forEach((record, index) => {
        record.updateTime = index === 0 ? receipt.authorityChronology.earliestFunctionUpdateTime
          : receipt.authorityChronology.latestFunctionUpdateTime;
        record.firebaseFunctionsHash = receipt.deployment.sourceRuntimeHash;
      });
    }
  }
  f.deployed.functionFleetSourceCommit = source.commit;
  f.deployed.deploymentApprovalFile = approvalPath;
  f.deployed.functionFleetEvidenceFile = 'release/current-backend28.json';
  const persist = () => {
    f.deployed.deploymentApprovalSha256 = f.write(approvalPath, approval);
    receipt.approvalAuthority.sha256 = f.deployed.deploymentApprovalSha256;
    for (const [key, child] of Object.entries(children)) {
      const sealed = sealReceipt(child);
      const file = `release/current28-${key}.json`;
      receipt.cleanMainLiveReadbacks[key] = {file, physicalSha256: f.write(file, sealed),
        canonicalReceiptSha256: sealed.receiptSha256};
    }
    f.deployed.functionFleetEvidenceSha256 = f.write(f.deployed.functionFleetEvidenceFile, receipt);
    f.write('release/current-successor-state.json', f.state);
  };
  persist();
  return {...f, currentApproval: approval, currentReceipt: receipt, currentChildren: children,
    persistCurrent: persist};
}

// Synthetic successor deployment, with the actual19-endpoint source graph and
// real Git approval/CI custody. Every readback is produced by the real pure
// collector adjudicator. No record here describes a production deployment.
function successorDelegatedFixture(t, {sourceCommit = 'f3d299d03ac9d034272519e7ac52ac4b4a216a9b', childDirectory = 'release'} = {}) {
  const f = delegatedCurrentFixture(t);
  const sourceTree = f.git('rev-parse', `${sourceCommit}^{tree}`);
  const functionTree = f.git('rev-parse', `${sourceCommit}:functions`);
  const getSource = (file) => f.git('show', `${sourceCommit}:${file}`) + '\n';
  const baseTime = Math.floor(Date.now() / 1000) * 1000 - 600000;
  const at = (seconds) => new Date(baseTime + seconds * 1000).toISOString();
  const approval = f.currentApproval, receipt = f.currentReceipt;
  const approvalFile = 'release/approvals/build28-current-source-backend-deployment-approval.json';
  const ciFile = 'release/evidence/build28-current-source-backend-ci.json';
  const runId = 99990001, prNumber = 9999;
  approval.approverName = 'Codex acting under project-owner delegation';
  approval.approvedAtUtc = at(60);
  approval.approvalEvidence = {authorityType: 'owner-delegated agent decision',
    delegationPolicyId: 'BUILD28-OWNER-DELEGATION-20260913', delegatedDecisionAtUtc: at(60), recordedAtUtc: at(61),
    instructionExcerpts: ['you do an audit yourself and go to make a build - phone is connected - you are explicitly authorized to use authorization wording of a choice necessary to go forward']};
  Object.assign(approval.sourceAuthority, {commit: sourceCommit, tree: sourceTree, functionTree,
    pullRequestNumber: prNumber, requiredPostMergeReleaseGateRunId: runId});
  Object.assign(approval.deploymentExecutionAuthority, {commit: sourceCommit, tree: sourceTree, functionTree});
  const fleet = readDeploymentFleetContract(f.root, sourceCommit);
  for (const field of ['functionCount','callableCount','eventAndProtocolTriggerCount','schedulerCount']) {
    approval.approvedDeployment[field] = receipt.deployment[field] = fleet[field];
  }
  Object.assign(receipt.sourceAuthority, {commit: sourceCommit, tree: sourceTree, functionsGitObjectId: functionTree,
    pullRequestNumber: prNumber, postMergeReleaseGateRunId: runId});
  Object.assign(receipt.authorityChronology, {delegatedDecisionAtUtc: at(60), earliestFunctionUpdateTime: at(120), latestFunctionUpdateTime: at(121)});
  receipt.recordedAtUtc = at(125);
  receipt.approvalAuthority.file = approvalFile;
  f.deployed.deploymentApprovalFile = approvalFile;
  f.deployed.functionFleetSourceCommit = sourceCommit;
  const jobNames = ['Flutter host analysis + tests + no-loss contracts',
    'Android release package + cold-start proof (non-production)',
    'Android emulator app-shell integration (not physical-device evidence)',
    'Firestore Rules + governed callable emulator','Cloud Functions host build + non-emulator tests'];
  const ci = {schemaVersion:1,evidenceType:'github-exact-main-release-gate',repository:'abhishekvatsa/crm3_baf_ops',
    sourceCommit,sourceTree,capturedAtUtc:at(50),
    pullRequest:{number:prNumber,merged:true,merge_commit_sha:sourceCommit,merged_at:at(0),
      base:{ref:'main',repo:{full_name:'abhishekvatsa/crm3_baf_ops'}}},
    run:{id:runId,head_sha:sourceCommit,head_branch:'main',event:'push',path:'.github/workflows/release-gate.yml',
      repository:{full_name:'abhishekvatsa/crm3_baf_ops'},status:'completed',conclusion:'success',created_at:at(1),updated_at:at(49)},
    jobs:{total_count:5,jobs:jobNames.map((name,index)=>({name,id:runId+index+1,run_id:runId,head_sha:sourceCommit,
      status:'completed',conclusion:'success',completed_at:at(45+index)}))}};
  const fleetCollector = require('./collectFunctionFleetRuntimeIdentityReadback.js');
  const iamCollector = require('./collectFunctionsIamDependenciesReadback.js');
  const firestoreCollector = require('./collectFirestoreRulesIndexesReadback.js');
  const fleetPolicy = JSON.parse(getSource(fleetCollector.POLICY_PATH));
  const iamPolicy = JSON.parse(getSource(iamCollector.POLICY_PATH));
  const aliases = fleetPolicy.runtimeIdentityAliases;
  for (const [key, child] of Object.entries(f.currentChildren)) {
    for (const point of ['before','after']) Object.assign(child.source[point],{commit:sourceCommit,tree:sourceTree,originMain:sourceCommit});
    child.capturedAtUtc = at(123);
    if (key === 'firestoreRulesAndIndexes') {
      const rulesRaw = getSource('firestore.rules');
      child.outputs.rules = firestoreCollector.summarizeRules({projectId: PROJECT,
        repositoryRules: rulesRaw, release: {name: child.outputs.rules.releaseName,
          rulesetName: child.outputs.rules.rulesetName}, ruleset: {
          createTime: child.outputs.rules.rulesetCreateTime,
          source: {files: [{name: 'firestore.rules', content: rulesRaw}]}}});
      approval.approvedDeployment.firestoreRulesSha256 = child.outputs.rules.sourceSha256;
      receipt.firestoreDeployment.rulesSha256 = child.outputs.rules.sourceSha256;
      const result = firestoreCollector.adjudicateReadback({projectId:PROJECT,sourceBefore:child.source.before,sourceAfter:child.source.after,
        rules:child.outputs.rules,indexes:child.outputs.indexes,observe:false});
      assert.deepEqual(result.failedChecks,[]); Object.assign(child,result.evidence); continue;
    }
    for (const [name, v1] of Object.entries(aliases)) {
      const original = child.outputs.functions.find((record)=>record.name === v1);
      child.outputs.functions.push({...structuredClone(original),name,
        ...(key === 'functionFleet' ? {runService:name.toLowerCase()} : {entryPoint:name,
          resourceName:`projects/${PROJECT}/locations/asia-south1/functions/${name}`})});
    }
    child.outputs.functions.forEach((record,index)=>{record.updateTime=at(index===0?120:121);});
    const common={projectId:PROJECT,region:'asia-south1',sourceBefore:child.source.before,sourceAfter:child.source.after,
      discoveredSourceExports:fleet.functionNames};
    let result;
    if(key==='functionFleet') {
      for(const [name,v1] of Object.entries(aliases)) child.outputs.callableProbes.push({
        ...structuredClone(child.outputs.callableProbes.find((probe)=>probe.name===v1)),name});
      result=fleetCollector.adjudicateReadback({...common,policy:fleetPolicy,phase:'final',probeCallables:true,
        live:{...child.outputs,backlog:child.outputs.schedulerBacklog,
          emailMap:fleetCollector.accountEmailMap(fleetPolicy,PROJECT),expectedRoles:fleetCollector.expectedProjectRoles(fleetPolicy,PROJECT)}});
    } else {
      const dependencies=iamCollector.summarizePackageState({packageJsonRaw:getSource('functions/package.json'),
        packageLockRaw:getSource('functions/package-lock.json'),trackedPackages:iamPolicy.trackedRuntimePackages});
      child.outputs.currentSourceDependencies=dependencies;
      child.outputs.functions.forEach((record)=>{record.dependencies=structuredClone(dependencies);});
      child.outputs.discoveredSourceFunctionExports=child.outputs.policySourceFunctionExports=fleet.functionNames;
      result=iamCollector.adjudicateReadback({...common,policy:iamPolicy,observe:false,project:child.outputs.project,
        iam:child.outputs.iam,functions:child.outputs.functions,currentDependencies:dependencies});
    }
    assert.deepEqual(result.failedChecks,[],`${key} synthetic collector positive control`);
    Object.assign(child,result.evidence);
  }
  function commitCustody() {
    approval.sourceAuthority.requiredPostMergeReleaseGateEvidence={file:ciFile,sha256:f.write(ciFile,ci)};
    f.write(approvalFile,approval);
    f.git('read-tree',sourceCommit);
    for(const file of [ciFile,approvalFile]) {
      const blob=f.git('hash-object','-w',file);
      f.git('update-index','--add','--cacheinfo',`100644,${blob},${file}`);
    }
    const tree=f.git('write-tree');
    const custodyCommit=execFileSync('git',['-C',f.root,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
      'commit-tree',tree,'-p',sourceCommit,'-m','Synthetic immutable delegated approval'],
    {encoding:'utf8',windowsHide:true,env:{...process.env,GIT_AUTHOR_DATE:at(70),GIT_COMMITTER_DATE:at(70)}}).trim();
    receipt.approvalAuthority.commit=custodyCommit;
    f.persistCurrent();
  }
  // The original fixture writer selected the old path; use a new writer whose
  // sole current approval target is this new fixed custody path.
  f.persistCurrent=()=>{
    f.deployed.deploymentApprovalSha256=f.write(approvalFile,approval);
    receipt.approvalAuthority.sha256=f.deployed.deploymentApprovalSha256;
    for(const [key,child] of Object.entries(f.currentChildren)) {
      const sealed=sealReceipt(child),file=`${childDirectory}/successor-${key}.json`;
      receipt.cleanMainLiveReadbacks[key]={file,physicalSha256:f.write(file,sealed),canonicalReceiptSha256:sealed.receiptSha256};
    }
    f.deployed.functionFleetEvidenceSha256=f.write(f.deployed.functionFleetEvidenceFile,receipt);
    f.write('release/current-successor-state.json',f.state);
  };
  commitCustody();
  return {...f,ci,commitCustody};
}

// Synthetic command observations exercise the production verifier with real
// immutable Git approval/CI custody. They are never operational evidence.
function successorRulesFixture(t) {
  const f = successorDelegatedFixture(t, {sourceCommit: '30330c72ca2a92cb0a485e0ced7e3c21f0479292', childDirectory: 'release/evidence'});
  const rulesProof = require('./reviewedFirestoreRulesDeployment.js');
  const rulesCollector = require('./collectFirestoreRulesIndexesReadback.js');
  const a = f.currentApproval, r = f.currentReceipt;
  const sourceCommit = r.sourceAuthority.commit, sourceTree = r.sourceAuthority.tree;
  const at = (seconds) => new Date(Date.parse(a.approvedAtUtc) + (seconds - 60) * 1000).toISOString();
  const source = rulesProof.sourceRulesScope(f.root, sourceCommit, sourceTree);
  const rawRules = execFileSync('git', ['-C', f.root, 'show', `${sourceCommit}:firestore.rules`]).toString('utf8');
  const oldRules = execFileSync('git', ['-C', f.root, 'show', 'f102cbfdcdbfc68ba3cb65d10ddcd3065ebc951f:firestore.rules']).toString('utf8');
  const final = f.currentChildren.firestoreRulesAndIndexes;
  function observation(before, start, end) {
    const original = structuredClone(final);
    const rules = rulesCollector.summarizeRules({projectId: PROJECT, repositoryRules: rawRules,
      release: {name: `projects/${PROJECT}/releases/cloud.firestore`, rulesetName: `projects/${PROJECT}/rulesets/${before ? 'prior-rules' : 'reviewed-rules'}`},
      ruleset: {createTime: before ? at(-100) : at(121.5), source: {files: [{name:'firestore.rules',content:before ? oldRules : rawRules}]}}});
    return sealReceipt({...rulesCollector.adjudicateReadback({projectId:PROJECT,
      sourceBefore: original.source.before, sourceAfter: original.source.after,
      rules, indexes: original.outputs.indexes, observe: before}).evidence,
    collectionStartedAtUtc:at(start),capturedAtUtc:at(end)});
  }
  const preflight = observation(true, 52, 53), before = observation(true, 120, 121);
  Object.assign(final, observation(false, 122, 123));
  const declaration = {schemaVersion:1,target:'firestore:rules',projectId:PROJECT,databaseId:'(default)',
    releaseName:`projects/${PROJECT}/releases/cloud.firestore`,priorRulesetName:preflight.outputs.rules.rulesetName,
    priorRulesSha256:preflight.outputs.rules.activeSha256,rulesSha256:source.rulesSha256,indexes:source.indexes,
    preflight:null,commandEvidenceFile:'release/evidence/fixture-rules-command.json',
    executionRootSha256:rulesProof.executionRootSha256(f.root)};
  a.approvedDeployment.firestoreRulesMutationAuthorized = true;
  a.approvedDeployment.reviewedRulesDeployment = declaration;
  Object.assign(r.firestoreDeployment,{rulesSha256:source.rulesSha256,
    rulesAlreadyExactNoMutationRequired:false,rulesDeploymentPerformed:true,
    rulesetName:final.outputs.rules.rulesetName,rulesetCreateTime:final.outputs.rules.rulesetCreateTime});
  r.controlBoundary.securityRulesMutated = true;
  const cliResult = {status:'success',result:{}};
  const command = {schemaVersion:1,evidenceType:'reviewed-firestore-rules-deployment',
    decision:'PASS_EXACT_SOURCE_RULES_ONLY_DEPLOYED',projectId:PROJECT,source:{commit:sourceCommit,tree:sourceTree},
    approvalAuthority:null,ciAuthority:null,target:'firestore:rules',startedAtUtc:at(121.1),completedAtUtc:at(121.9),
    command:{executable:'node',arguments:[...rulesProof.RULES_COMMAND]},exitCode:0,cliResult:null,beforeReadback:null,
    executionSource:{rootSha256:declaration.executionRootSha256,before:structuredClone(final.source.before),after:structuredClone(final.source.after)}};
  function point(file, value) {
    const sealed = sealReceipt(value);
    return {file,physicalSha256:f.write(file,sealed),canonicalReceiptSha256:sealed.receiptSha256};
  }
  const persistRules = (commitApproval = false) => {
    declaration.preflight = point('release/evidence/fixture-rules-preflight.json',preflight);
    if (commitApproval) f.commitCustody();
    command.approvalAuthority = structuredClone(r.approvalAuthority);
    command.ciAuthority = {file:a.sourceAuthority.requiredPostMergeReleaseGateEvidence.file,
      sha256:a.sourceAuthority.requiredPostMergeReleaseGateEvidence.sha256,commit:r.approvalAuthority.commit};
    command.cliResult = {file:'release/evidence/fixture-rules-cli-result.json',
      physicalSha256:f.write('release/evidence/fixture-rules-cli-result.json',cliResult)};
    command.beforeReadback = point('release/evidence/fixture-rules-immediate-before.json',before);
    r.firestoreDeployment.rulesDeploymentEvidence = point(declaration.commandEvidenceFile,command);
    f.persistCurrent();
  };
  persistRules(true);
  return {...f,at,declaration,preflight,before,final,command,cliResult,persistRules};
}

test('new successor Rules-only proof passes actual shared Git/CI/receipt verification while historical receipts remain unchanged', (t) => {
  const f = successorRulesFixture(t);
  assert.equal(f.verify().ok,true,JSON.stringify(f.verify()));
  assert.equal(f.receipt.controlBoundary.securityRulesMutated,false);
  assert.equal(f.receipt.firestoreDeployment.rulesDeploymentPerformed,false);
});

const rulesNegatives = [
  ['missing approval', f => { f.currentApproval.approvedDeployment.firestoreRulesMutationAuthorized = false; }, true],
  ['missing declaration', f => { delete f.currentApproval.approvedDeployment.reviewedRulesDeployment; }, true],
  ['wrong prior hash', f => { f.declaration.priorRulesSha256 = '1'.repeat(64); }, true],
  ['wrong prior ruleset', f => { f.declaration.priorRulesetName = `projects/${PROJECT}/rulesets/unrelated`; }, true],
  ['wrong new hash', f => { f.declaration.rulesSha256 = '2'.repeat(64); }, true],
  ['wrong database', f => { f.declaration.databaseId = 'other'; }, true],
  ['wrong approved index file', f => { f.declaration.indexes.fileSha256 = '3'.repeat(64); }, true],
  ['wrong approved overrides', f => { f.declaration.indexes.fieldOverrideSetSha256 = '4'.repeat(64); }, true],
  ['wrong target', f => { f.command.command.arguments[3] = 'firestore'; }],
  ['extra configuration argument', f => { f.command.command.arguments.push('--config','unreviewed.json'); }],
  ['wrong project', f => { f.command.projectId = 'other'; }],
  ['wrong command source', f => { f.command.source.commit = '0'.repeat(40); }],
  ['wrong command cwd', f => { f.command.executionSource.rootSha256 = '0'.repeat(64); }],
  ['dirty command checkout', f => { f.command.executionSource.after.governedWorktreeClean = false; }],
  ['moved command checkout', f => { f.command.executionSource.before.commit = '0'.repeat(40); }],
  ['failed exit', f => { f.command.exitCode = 1; }],
  ['missing exit', f => { delete f.command.exitCode; }],
  ['ambiguous result', f => { f.cliResult.result = {hosting:'unexpected'}; }],
  ['failed result', f => { f.cliResult.status = 'error'; }],
  ['missing result', f => { delete f.cliResult.result; }],
  ['predecision command', f => { f.command.startedAtUtc = f.at(55); }],
  ['reversed command interval', f => { f.command.completedAtUtc = f.at(120); }],
  ['future command', f => { f.command.completedAtUtc = '2999-01-01T00:00:00Z'; }],
  ['pre-custody immediate observation', f => { f.before.collectionStartedAtUtc = f.at(65); }],
  ['immediate observation overlaps command', f => { f.before.capturedAtUtc = f.at(122); }],
  ['final observation starts before command ends', f => { f.final.collectionStartedAtUtc = f.at(121); }],
  ['final observation has no start', f => { delete f.final.collectionStartedAtUtc; }],
  ['future closure', f => { f.currentReceipt.recordedAtUtc = '2999-01-01T00:00:00Z'; }],
  ['false performed claim', f => { f.currentReceipt.firestoreDeployment.rulesDeploymentPerformed = false; }],
  ['false no-mutation claim', f => { f.currentReceipt.firestoreDeployment.rulesAlreadyExactNoMutationRequired = true; }],
  ['false security mutation claim', f => { f.currentReceipt.controlBoundary.securityRulesMutated = false; }],
  ['index mutation claim', f => { f.currentReceipt.controlBoundary.indexesMutated = true; }],
];
for (const [label, mutate, recommit] of rulesNegatives) {
  test(`Rules-only proof refuses ${label}`, (t) => {
    const f = successorRulesFixture(t);
    assert.equal(f.verify().ok,true,'positive control');
    mutate(f);f.persistRules(recommit === true);
    assert.equal(f.verify().ok,false,label);
  });
}

for (const [field, hashField] of [['fieldOverridesMatchSource','cliFieldOverrideSha256'],
  ['cliMatchesSource','cliSetSha256'], ['apiMatchesSource','apiSetSha256']]) {
  test(`coherently resealed null ${field} cannot conceal changed before indexes`, (t) => {
    const f = successorRulesFixture(t);
    assert.equal(f.verify().ok,true,'positive control');
    f.before.outputs.indexes[field] = null;
    f.before.outputs.indexes[hashField] = '7'.repeat(64);
    // Re-derive the exact defective truthy map; literal-false filtering alone
    // must not admit null controls in a genuinely sealed observation.
    const result = require('./collectFirestoreRulesIndexesReadback.js').adjudicateReadback({projectId:PROJECT,
      sourceBefore:f.before.source.before,sourceAfter:f.before.source.after,
      rules:f.before.outputs.rules,indexes:f.before.outputs.indexes,observe:true});
    Object.assign(f.before,result.evidence);f.persistRules();
    assert.equal(f.verify().ok,false);
  });
}

test('historical delegated approval cannot opt into Rules mutation by adding new flags', (t) => {
  const f = delegatedCurrentFixture(t);
  f.currentApproval.approvedDeployment.firestoreRulesMutationAuthorized = true;
  f.currentReceipt.firestoreDeployment.rulesDeploymentPerformed = true;
  f.currentReceipt.controlBoundary.securityRulesMutated = true;
  f.persistCurrent();assert.equal(f.verify().ok,false);
});

test('new source delegated custody verifies real Git, exact five-job CI and the actual19-endpoint readback adjudicators', (t)=>{
  const f=successorDelegatedFixture(t);
  const predeployment=verifySuccessorDelegatedDecision({repoRoot:f.root,approval:f.currentApproval,
    approvalAuthority:f.currentReceipt.approvalAuthority,sourceAuthority:f.currentReceipt.sourceAuthority});
  assert.equal(predeployment.ok,true);
  assert.equal(predeployment.ciFile,'release/evidence/build28-current-source-backend-ci.json');
  assert.equal(predeployment.ciSha256,sha(fs.readFileSync(path.join(f.root,predeployment.ciFile))));
  assert.equal(predeployment.sourceCommit,f.currentReceipt.sourceAuthority.commit);
  assert.equal(predeployment.approvalCommit,f.currentReceipt.approvalAuthority.commit);
  for (const field of ['commit','tree','functionsGitObjectId','pullRequestNumber','postMergeReleaseGateRunId']) {
    assert.throws(()=>verifySuccessorDelegatedDecision({repoRoot:f.root,approval:f.currentApproval,
      approvalAuthority:f.currentReceipt.approvalAuthority,sourceAuthority:{...f.currentReceipt.sourceAuthority,
        [field]:typeof f.currentReceipt.sourceAuthority[field]==='number'?1:'0'.repeat(40)}}),undefined,field);
  }
  const result=f.verify(); assert.equal(result.ok,true,result.reasons.join('; '));
});

test('new delegated custody rejects altered approval bytes and invalid CI even when coherently recommitted', (t)=>{
  const f=successorDelegatedFixture(t);
  assert.equal(f.verify().ok,true,f.verify().reasons.join('; '));
  const approval=structuredClone(f.currentApproval),ci=structuredClone(f.ci),receipt=structuredClone(f.currentReceipt);
  const cases=[
    ['changed owner basis',()=>{f.currentApproval.approvalEvidence.instructionExcerpts=['Deploy anything.'];}],
    ['invented owner timestamp',()=>{f.currentApproval.approvalEvidence.messageReceivedAtUtc=f.currentApproval.approvedAtUtc;}],
    ['invented owner identity',()=>{f.currentApproval.approvalEvidence.codexMessageId='invented';}],
    ['different approver',()=>{f.currentApproval.approverName='Abhishek Vatsa';}],
    ['another source',()=>{f.ci.sourceCommit='0'.repeat(40);}],
    ['PR merge tree',()=>{f.ci.run.event='pull_request';}],
    ['duplicate job identity',()=>{f.ci.jobs.jobs[1].id=f.ci.jobs.jobs[0].id;}],
    ['wrong job set',()=>{f.ci.jobs.jobs[0].name='Unrelated check';}],
    ['failed required job',()=>{f.ci.jobs.jobs[0].conclusion='failure';}],
    ['fewer required jobs',()=>{f.ci.jobs.jobs.pop();f.ci.jobs.total_count=4;}],
    ['CI after decision',()=>{f.ci.capturedAtUtc=f.currentReceipt.authorityChronology.latestFunctionUpdateTime;}],
    ['post-hoc custody',()=>{f.currentReceipt.authorityChronology.earliestFunctionUpdateTime=f.currentApproval.approvedAtUtc;}],
  ];
  for(const [label,mutate] of cases) {
    for(const key of Object.keys(f.currentApproval)) delete f.currentApproval[key]; Object.assign(f.currentApproval,structuredClone(approval));
    for(const key of Object.keys(f.ci)) delete f.ci[key]; Object.assign(f.ci,structuredClone(ci));
    Object.assign(f.currentReceipt,structuredClone(receipt)); mutate(); f.commitCustody();
    assert.equal(f.verify().ok,false,label);
  }
  Object.assign(f.currentApproval,structuredClone(approval)); Object.assign(f.ci,structuredClone(ci));
  Object.assign(f.currentReceipt,structuredClone(receipt)); f.commitCustody();
  f.currentApproval.approvalEvidence.agentDecision='An uncommitted different decision'; f.persistCurrent();
  assert.equal(f.verify().ok,false,'uncommitted coherent rehash cannot replace Git custody');
});

function rolloverFixture(t, currentFixture = delegatedCurrentFixture) {
  const f = currentFixture(t);
  const promotionFile = 'release/evidence/build-27-staged-controlled-pilot-authorization.json';
  const promotion = readMeasured(promotionFile);
  const history = promotion.admittedEvidence.productionBackend;
  const historical = readMeasured(history.receipt);
  for (const file of [promotionFile, promotion.ownerApproval.receipt,
    promotion.admittedEvidence.deviceAcceptance.receipt, history.receipt,
    historical.approvalAuthority.file,
    ...Object.values(historical.cleanMainLiveReadbacks).map((value) => value.file)]) {
    fs.mkdirSync(path.dirname(path.join(f.root, file)), {recursive: true});
    fs.copyFileSync(path.join(repositoryRoot, file), path.join(f.root, file));
  }
  f.policy.postBuildPromotion = {status: 'completed-staged-controlled-pilot-only',
    promotionReceiptFile: promotionFile, promotionReceiptSha256: sha(fs.readFileSync(path.join(f.root, promotionFile)))};
  f.policy.versionPolicy.buildNumber = 28;
  f.version.sourceBaseline.commit = f.currentReceipt.sourceAuthority.commit;
  Object.assign(f.version.requiredSource, {
    exactFunctionFleetDeploymentSourceCommit: f.currentReceipt.sourceAuthority.commit,
    exactFunctionFleetDeploymentPullRequest: f.currentReceipt.sourceAuthority.pullRequestNumber,
    exactFunctionFleetDeploymentReceiptFile: f.deployed.functionFleetEvidenceFile,
  });
  const persistCandidate = () => {
    const required = f.version.requiredSource;
    required.exactFunctionFleetDeploymentReceiptSha256 = sha(fs.readFileSync(path.join(f.root,
      required.exactFunctionFleetDeploymentReceiptFile)));
    Object.assign(f.policy.finalization, {
      exactFunctionFleetDeploymentReceiptFile: required.exactFunctionFleetDeploymentReceiptFile,
      exactFunctionFleetDeploymentReceiptSha256: required.exactFunctionFleetDeploymentReceiptSha256,
    });
    f.policy.versionPolicy.sourceDocumentSha256 = f.write('release/version.json', f.version);
  };
  persistCandidate();
  return {...f, history, historical, persistCandidate};
}

test('new source delegated custody supports a Build28 candidate while preserving immutable Build27 history', (t) => {
  const f = rolloverFixture(t, successorDelegatedFixture);
  const result = f.verify();
  assert.equal(result.ok, true, result.reasons.join('; '));
  assert.equal(result.historicalBackendReceiptSha256, f.history.sha256);
  assert.equal(result.candidateBackendReceiptSha256, f.deployed.functionFleetEvidenceSha256);
  assert.notEqual(result.candidateBackendReceiptSha256, result.historicalBackendReceiptSha256);
});

test('Build28 rollover retains fixed Build27 history and separately verifies candidate and current backend', (t) => {
  const f = rolloverFixture(t);
  const result = f.verify();
  assert.equal(result.ok, true, result.reasons.join('; '));
  assert.equal(result.historicalBackendReceiptFile, f.history.receipt);
  assert.equal(result.historicalBackendReceiptSha256, f.history.sha256);
  assert.equal(result.candidateBackendReceiptFile, f.deployed.functionFleetEvidenceFile);
  assert.equal(result.candidateBackendReceiptSha256, f.deployed.functionFleetEvidenceSha256);

  // A later readback remains separate from the already selected candidate.
  f.deployed.functionFleetEvidenceFile = 'release/later-current28.json';
  f.currentReceipt.recordedAtUtc = '2026-09-08T21:04:00Z';
  f.persistCurrent();
  const later = f.verify();
  assert.equal(later.ok, true, later.reasons.join('; '));
  assert.notEqual(later.candidateBackendReceiptSha256, later.currentBackendReceiptSha256);
  assert.equal(later.historicalBackendReceiptSha256, f.history.sha256);
});

test('Build28 rollover rejects coherent candidate, historical and mutable promotion substitutions', (t) => {
  const f = rolloverFixture(t);
  const required = structuredClone(f.version.requiredSource);
  Object.assign(f.version.requiredSource, {
    exactFunctionFleetDeploymentReceiptFile: f.history.receipt,
    exactFunctionFleetDeploymentSourceCommit: f.historical.sourceAuthority.commit,
    exactFunctionFleetDeploymentPullRequest: f.historical.sourceAuthority.pullRequestNumber,
  });
  f.persistCandidate();
  assert.equal(f.verify().ok, false, 'Build28 candidate cannot substitute historical27 deployment');
  Object.assign(f.version.requiredSource, required);
  f.persistCandidate();
  assert.equal(f.verify().ok, true);
  const promotion = readMeasured(f.policy.postBuildPromotion.promotionReceiptFile);
  promotion.admittedEvidence.productionBackend = {receipt: f.deployed.functionFleetEvidenceFile,
    sha256: f.deployed.functionFleetEvidenceSha256, decision: PASS};
  f.policy.postBuildPromotion.promotionReceiptSha256 = f.write(f.policy.postBuildPromotion.promotionReceiptFile, promotion);
  assert.equal(f.verify().ok, false, 'rehashing promotion cannot substitute current28 as historical27');
  delete f.policy.postBuildPromotion;
  assert.equal(f.verify().ok, false, 'rollover cannot omit its preserved promotion authority');
});

test('Build28 rollover adjudicates a distinct candidate child even when current backend passes', (t) => {
  const f = rolloverFixture(t);
  const candidate = structuredClone(f.currentReceipt);
  f.write('release/candidate28.json', candidate);
  f.version.requiredSource.exactFunctionFleetDeploymentReceiptFile = 'release/candidate28.json';
  f.persistCandidate();
  assert.equal(f.verify().ok, true);
  const child = structuredClone(f.currentChildren.functionFleet);
  child.outputs.functions[0].firebaseFunctionsHash = '0'.repeat(40);
  const sealed = sealReceipt(child);
  candidate.cleanMainLiveReadbacks.functionFleet = {file: 'release/candidate-bad-fleet.json',
    physicalSha256: f.write('release/candidate-bad-fleet.json', sealed), canonicalReceiptSha256: sealed.receiptSha256};
  f.write('release/candidate28.json', candidate);
  f.persistCandidate();
  const result = f.verify();
  assert.equal(result.ok, false, 'candidate children cannot borrow a valid current receipt verdict');
  assert.match(result.reasons[0], /functionFleet: measured function source hashes/);
});

test('Build28 rollover keeps candidate version, approval and scope bindings independent from current', (t) => {
  const f = rolloverFixture(t);
  const original = structuredClone(f.currentReceipt);
  f.version.requiredSource.exactFunctionFleetDeploymentReceiptFile = 'release/candidate28.json';
  for (const [mutate, reason] of [
    [(value) => { value.sourceAuthority.pullRequestNumber = 1; }, /version authority/],
    [(value) => { value.deployment.schedulerCount = 2; }, /Candidate backend: exact deployment evidence is incomplete/],
    [(value) => { value.authorityChronology.delegatedDecisionAtUtc = '2026-09-08T20:59:00Z'; }, /authorization/],
    [(value) => {
      const approval = structuredClone(f.currentApproval);
      approval.approvalEvidence.instructionVerbatim = 'Deployment is prohibited.';
      value.approvalAuthority = {file: 'release/substituted-approval.json',
        sha256: f.write('release/substituted-approval.json', approval)};
    }, /immutable owner-instruction custody/],
  ]) {
    const candidate = structuredClone(original);
    mutate(candidate);
    f.write('release/candidate28.json', candidate);
    f.persistCandidate();
    const result = f.verify();
    assert.equal(result.ok, false);
    assert.match(result.reasons[0], reason);
  }
});

test("verifies and returns exact historical/current receipt identities", (t) => {
  const f = fixture(t);
  assert.deepEqual(f.verify(), {ok: true, reasons: [],
    historicalBackendReceiptFile: "release/backend.json",
    historicalBackendReceiptSha256: f.deployed.functionFleetEvidenceSha256,
    currentBackendReceiptFile: "release/backend.json",
    currentBackendReceiptSha256: f.deployed.functionFleetEvidenceSha256});
});

test("permits successor app/backend source pending at HEAD", (t) => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, "backend.txt"), "successor backend pending deployment\n");
  f.git("add", "backend.txt");
  f.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
    "commit", "--quiet", "-m", "pending successor fixture");
  assert.notEqual(f.git("rev-parse", "HEAD"), f.commit);
  f.state.authorityPlanes.currentSource = {backendDeploymentStatus: "PENDING"};
  f.deployed.currentSourceFunctionDeployment = "PENDING_SUCCESSOR_DEPLOYMENT";
  f.policy.finalization.sourceCommit = f.git("rev-parse", "HEAD");
  f.persist();
  assert.equal(f.verify().ok, true);
});

test("supports the deployed-source fallback without relabeling its admitted pull request", (t) => {
  const f = fixture(t);
  delete f.version.requiredSource.exactFunctionFleetDeploymentSourceCommit;
  f.persist();
  assert.equal(f.verify().ok, true);
  delete f.version.requiredSource.exactFunctionFleetDeploymentPullRequest;
  f.receipt.sourceAuthority.pullRequestNumber = 265;
  f.approval.sourceAuthority.pullRequestNumber = 265;
  f.persist();
  assert.equal(f.verify().ok, false);
});

test("rejects coherently rehashed backend source with the wrong Git tree", (t) => {
  const f = fixture(t);
  f.receipt.sourceAuthority.tree = "a".repeat(40);
  f.persist();
  assert.equal(f.verify().ok, false);
  assert.match(f.verify().reasons[0], /Git tree/);
});

test("rejects coherent receipt/approval source changes outside the version authority", (t) => {
  const f = fixture(t);
  f.receipt.sourceAuthority.commit = "b".repeat(40);
  f.approval.sourceAuthority.commit = "b".repeat(40);
  f.deployed.functionFleetSourceCommit = "b".repeat(40);
  f.persist();
  assert.equal(f.verify().ok, false);
  assert.match(f.verify().reasons[0], /version authority/);
});

for (const change of ["approved", "project", "iam", "appCheck", "source", "binding"]) {
  test(`rejects coherently rehashed invalid backend approval: ${change}`, (t) => {
    const f = fixture(t);
    if (change === "approved") f.approval.approved = false;
    if (change === "project") f.approval.firebaseProjectId = "other-project";
    if (change === "iam") f.approval.approvedDeployment.preserveExistingIamRequired = false;
    if (change === "appCheck") f.approval.approvedDeployment.appCheckEnforcement = true;
    if (change === "source") f.approval.sourceAuthority.commit = "c".repeat(40);
    if (change === "binding") f.receipt.approvalAuthority.file = "release/other-approval.json";
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /approval/);
  });
}

for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
  test(`rejects rehashed ${key} child whose canonical seal is invalid`, (t) => {
    const f = fixture(t);
    f.children[key].passed = false;
    f.receipt.cleanMainLiveReadbacks[key].physicalSha256 =
      f.write(`release/${key}.json`, f.children[key]);
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /seal does not match/);
  });
}

test("rejects physical child tampering and canonical parent alias mismatch", (t) => {
  const f = fixture(t);
  f.write("release/functionFleet.json", sealReceipt({fixture: "tampered"}));
  assert.match(f.verify().reasons[0], /physical SHA-256/);
  f.receipt.cleanMainLiveReadbacks.functionFleet.physicalSha256 =
    f.write("release/functionFleet.json", f.children.functionFleet);
  f.receipt.cleanMainLiveReadbacks.functionFleet.canonicalReceiptSha256 = "d".repeat(64);
  f.persist();
  assert.match(f.verify().reasons[0], /canonical seal differs/);
});

for (const escaped of ["../outside.json", "release/../../outside.json", "C:\\outside.json", "/outside.json"]) {
  test(`rejects repository child path escape: ${escaped}`, (t) => {
    const f = fixture(t);
    f.receipt.cleanMainLiveReadbacks.functionFleet.file = escaped;
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /path/);
  });
}

test("validates a full commit before invoking git", (t) => {
  const f = fixture(t);
  f.version.requiredSource.exactFunctionFleetDeploymentSourceCommit = "HEAD^{tree}";
  f.persist();
  assert.match(f.verify().reasons[0], /exactly 40 hexadecimal/);
});

test("allows distinct current and historical receipts for the same admitted approval", (t) => {
  const f = fixture(t);
  const current = structuredClone(f.receipt);
  const currentPath = "release/new-current-backend.json";
  current.recordedAtUtc = "2026-09-09T00:00:00.000Z";
  f.deployed.functionFleetEvidenceFile = currentPath;
  f.deployed.functionFleetEvidenceSha256 = f.write(currentPath, current);
  f.write("release/current-successor-state.json", f.state);
  const result = f.verify();
  assert.equal(result.ok, true);
  assert.equal(result.historicalBackendReceiptFile, "release/backend.json");
  assert.equal(result.currentBackendReceiptFile, currentPath);
  assert.notEqual(result.historicalBackendReceiptSha256, result.currentBackendReceiptSha256);
});

test('admits the fixed delegated c00 backend alongside unchanged historical Build27', (t) => {
  const f = delegatedCurrentFixture(t);
  const historicalHash = f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256;
  const result = f.verify();
  assert.equal(result.ok, true, result.reasons.join('; '));
  assert.equal(result.historicalBackendReceiptFile, 'release/backend.json');
  assert.equal(result.historicalBackendReceiptSha256, historicalHash);
  assert.equal(result.currentBackendReceiptFile, 'release/current-backend28.json');
  assert.equal(result.currentBackendReceiptSha256, f.deployed.functionFleetEvidenceSha256);
  assert.notEqual(result.currentBackendReceiptSha256, result.historicalBackendReceiptSha256);
  assert.equal(Object.hasOwn(f.currentReceipt.authorityChronology, 'ownerInstructionReceivedAtUtc'), false);
  assert.equal(Object.hasOwn(f.currentApproval.approvalEvidence, 'messageReceivedAtUtc'), false);
  assert.equal(f.receipt.authorityChronology.ownerInstructionReceivedAtUtc, '2026-09-08T00:48:30.433Z');
});

test('delegated backend approval custody rejects coherent changes to the entire decision', (t) => {
  const f = delegatedCurrentFixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.currentApproval);
  for (const [field, value] of [
    ['approverName', 'A different decision maker'],
    ['approvalEvidence.codexTaskId', 'unrelated-task'],
    ['approvalEvidence.instructionExcerpts', ['Do not deploy any backend.']],
    ['approvalEvidence.overnightMandateSummary', 'No agent action is authorized.'],
    ['approvalEvidence.agentDecision', 'Deploy a different source and change IAM.'],
    ['approvalEvidence.scopeInterpretation', 'This grants unrestricted publication.'],
    ['executionPrerequisites', []],
    ['notAuthorizedByThisDecision', []],
    ['deploymentExecutionAuthority.stopIfRemoteMainMoves', false],
  ]) {
    Object.assign(f.currentApproval, structuredClone(original));
    const parts = field.split('.');
    const target = parts.slice(0, -1).reduce((value, part) => value[part], f.currentApproval);
    target[parts.at(-1)] = value;
    f.persistCurrent();
    const result = f.verify();
    assert.equal(result.ok, false, field);
    assert.match(result.reasons[0], /approval.*custody/i);
  }
});

test('delegated backend binds source, execution, CI, scope and decision-time semantics', (t) => {
  const f = delegatedCurrentFixture(t);
  const original = structuredClone(f.currentApproval);
  for (const field of [
    'sourceAuthority.tree', 'sourceAuthority.functionTree', 'sourceAuthority.pullRequestNumber',
    'sourceAuthority.requiredPostMergeReleaseGateRunId', 'approvedAtUtc',
    'approvalEvidence.authorityType', 'approvalEvidence.delegatedDecisionAtUtc', 'approvalEvidence.recordedAtUtc',
    'deploymentExecutionAuthority.mode', 'deploymentExecutionAuthority.commit',
    'deploymentExecutionAuthority.tree', 'deploymentExecutionAuthority.functionTree',
    'approvedDeployment.callableCount', 'approvedDeployment.eventAndProtocolTriggerCount',
    'approvedDeployment.functionCount', 'approvedDeployment.preserveExistingIamRequired',
    'approvedDeployment.scheduledFunctionManualInvocationAuthorized', 'approvedDeployment.appCheckEnforcement',
  ]) {
    const parts = field.split('.');
    for (const missing of [false, true]) {
      Object.assign(f.currentApproval, structuredClone(original));
      const target = parts.slice(0, -1).reduce((value, part) => value[part], f.currentApproval);
      const key = parts.at(-1);
      if (missing) delete target[key]; else target[key] = [target[key]];
      f.persistCurrent();
      assert.equal(f.verify().ok, false, `${field}, missing=${missing}`);
    }
  }
});

test('delegated chronology rejects invented message times, mixed authority, invalid dates and nanosecond reversal', (t) => {
  const f = delegatedCurrentFixture(t);
  const original = structuredClone(f.currentReceipt.authorityChronology);
  for (const mutate of [
    (value) => { delete value.delegatedDecisionAtUtc; },
    (value) => { value.delegatedDecisionAtUtc = [value.delegatedDecisionAtUtc]; },
    (value) => { value.delegatedDecisionAtUtc = '2026-09-08T21:00:09Z'; },
    (value) => { value.ownerInstructionReceivedAtUtc = value.delegatedDecisionAtUtc; },
    (value) => { value.allObservedFunctionUpdatesPostdateOwnerInstruction = true; },
    (value) => { value.allObservedFunctionUpdatesPostdateDelegatedDecision = false; },
    (value) => { value.deploymentWasRetroactivelyAuthorized = true; },
    (value) => { value.earliestFunctionUpdateTime = '2026-09-08T20:59:59Z'; },
    (value) => { value.earliestFunctionUpdateTime = '2026-02-30T21:01:00Z'; },
    (value) => { value.earliestFunctionUpdateTime = '2026-09-08T21:01:00.123456789Z';
      value.latestFunctionUpdateTime = '2026-09-08T21:01:00.123456788Z'; },
  ]) {
    f.currentReceipt.authorityChronology = structuredClone(original);
    mutate(f.currentReceipt.authorityChronology);
    f.persistCurrent();
    assert.equal(f.verify().ok, false);
  }
  f.currentReceipt.authorityChronology = structuredClone(original);
  f.currentApproval.approvalEvidence.messageReceivedAtUtc = f.currentApproval.approvedAtUtc;
  f.persistCurrent();
  assert.equal(f.verify().ok, false);
});

test('delegated current authority cannot replace historical Build27 or approve another source', (t) => {
  const f = delegatedCurrentFixture(t);
  f.currentApproval.sourceAuthority.commit = f.git('rev-parse', 'HEAD');
  f.currentApproval.sourceAuthority.tree = f.git('rev-parse', 'HEAD^{tree}');
  f.currentApproval.sourceAuthority.functionTree = f.git('rev-parse', 'HEAD:functions');
  Object.assign(f.currentReceipt.sourceAuthority, {
    commit: f.currentApproval.sourceAuthority.commit, tree: f.currentApproval.sourceAuthority.tree,
    functionsGitObjectId: f.currentApproval.sourceAuthority.functionTree});
  f.deployed.functionFleetSourceCommit = f.currentApproval.sourceAuthority.commit;
  f.persistCurrent();
  assert.equal(f.verify().ok, false, 'a mutable approval must not authorize an unadmitted source');

  const g = delegatedCurrentFixture(t);
  g.receipt.approvalAuthority = structuredClone(g.currentReceipt.approvalAuthority);
  const historicalHash = g.write('release/backend.json', g.receipt);
  g.version.requiredSource.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  g.policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  g.policy.versionPolicy.sourceDocumentSha256 = g.write('release/version.json', g.version);
  assert.equal(g.verify().ok, false, 'historical27 must retain its original owner/source approval');
});

test('a different current source requires its own admitted immutable approval custody', (t) => {
  const f = fixture(t);
  const commit = f.git('rev-parse', 'HEAD');
  const tree = f.git('rev-parse', 'HEAD^{tree}');
  const functionTree = f.git('rev-parse', 'HEAD:functions');
  const approval = structuredClone(f.approval);
  Object.assign(approval.sourceAuthority, {commit, tree, functionTree});
  const receipt = structuredClone(f.receipt);
  Object.assign(receipt.sourceAuthority, {commit, tree, functionsGitObjectId: functionTree});
  // Forge internally consistent counts too, so this still reaches and tests
  // immutable approval refusal rather than an earlier source-count mismatch.
  const fleet = readDeploymentFleetContract(f.root, commit);
  approval.approvedDeployment.functionCount = fleet.functionCount;
  for (const field of ["functionCount", "callableCount", "eventAndProtocolTriggerCount", "schedulerCount"]) {
    receipt.deployment[field] = fleet[field];
  }
  f.deployed.functionFleetSourceCommit = commit;
  f.deployed.deploymentApprovalFile = 'release/approvals/unadmitted-current-source.json';
  f.deployed.deploymentApprovalSha256 = f.write(f.deployed.deploymentApprovalFile, approval);
  receipt.approvalAuthority = {file: f.deployed.deploymentApprovalFile, sha256: f.deployed.deploymentApprovalSha256};
  f.deployed.functionFleetEvidenceFile = 'release/current-backend.json';
  f.deployed.functionFleetEvidenceSha256 = f.write(f.deployed.functionFleetEvidenceFile, receipt);
  f.write('release/current-successor-state.json', f.state);
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /Successor delegated custody: exact path, known delegation and actual agent decision are required/);
});

test('deployment approval binds its entire source, authorization and deployment scope', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.approval);
  const fields = [
    'schemaVersion', 'documentType', 'region', 'sourceAuthority.tree', 'sourceAuthority.functionTree',
    'sourceAuthority.pullRequestNumber', 'sourceAuthority.requiredPostMergeReleaseGateRunId',
    'approvedAtUtc', 'approvalEvidence.authorityType', 'approvalEvidence.messageReceivedAtUtc',
    'approvedDeployment.functionCount',
    'approvedDeployment.existingDedicatedServiceAccountsRequired',
    'approvedDeployment.scheduledFunctionDeploymentAuthorized',
    'approvedDeployment.scheduledFunctionManualInvocationAuthorized',
    'approvedDeployment.firestoreRulesSha256', 'approvedDeployment.firestoreRulesMutationAuthorized',
    'approvedDeployment.firestoreIndexCount', 'approvedDeployment.firestoreIndexSetSha256',
    'approvedDeployment.firestoreIndexMutationAuthorized', 'approvedDeployment.strictLiveReadbackRequired',
    'approvedDeployment.postMergeReleaseGateMustPassBeforeDeployment',
  ];
  for (const field of fields) {
    const parts = field.split('.');
    const get = () => parts.slice(0, -1).reduce((value, part) => value[part], f.approval);
    const expected = get()[parts.at(-1)];
    const wrong = typeof expected === 'boolean' ? !expected : typeof expected === 'number' ? expected + 1 : 'wrong';
    for (const value of [wrong, null, undefined, [expected]]) {
      Object.assign(f.approval, structuredClone(original));
      if (value === undefined) delete get()[parts.at(-1)]; else get()[parts.at(-1)] = value;
      f.persist();
      assert.equal(f.verify().ok, false, `${field}: ${JSON.stringify(value)}`);
    }
  }
});

test('coherently rebound owner evidence cannot replace the admitted deployment instruction', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.approval);
  for (const [field, value] of [
    ['approverName', 'Different owner'],
    ['approvalEvidence.codexTaskId', 'different-task'],
    ['approvalEvidence.codexTurnId', 'different-turn'],
    ['approvalEvidence.codexMessageId', 'different-message'],
    ['approvalEvidence.codexClientMessageId', 'different-client-message'],
    ['approvalEvidence.instructionVerbatim', 'Do not deploy anything. No backend deployment is authorized.'],
    ['approvalEvidence.instructionSummary', 'Deployment is prohibited.'],
    ['approvalEvidence.scopeInterpretation', 'Authorize unrestricted distribution and IAM mutation.'],
  ]) {
    Object.assign(f.approval, structuredClone(original));
    const parts = field.split('.');
    const target = parts.slice(0, -1).reduce((value, part) => value[part], f.approval);
    target[parts.at(-1)] = value;
    f.persist();
    const result = f.verify();
    assert.equal(result.ok, false, field);
    assert.match(result.reasons[0], /approval.*custody/i);
  }
});

test('coherently resealed fleet and IAM children must still contain passing source-bound evidence', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  for (const key of ['functionFleet', 'iamDependencies']) {
    const original = structuredClone(f.children[key]);
    const cases = [
      (child) => { child.decision = 'HOLD'; },
      (child) => { child.failedChecks = ['sourceStable']; },
      (child) => { delete child.failedChecks; },
      (child) => { child.checks = {}; },
      (child) => { child.checks.sourceStable = false; },
      (child) => { child.source.before.commit = '0'.repeat(40); },
      (child) => { child.source.after.tree = '0'.repeat(40); },
      (child) => { child.source.after.governedWorktreeClean = 'true'; },
      (child) => { child.outputs.functions[0].state = 'FAILED'; },
      (child) => { child.mutationBoundary.iamMutated = true; },
      (child) => { child.privacyBoundary.userIdentityRetained = true; },
      (child) => { child.posture.deployedFunctionCount = '15'; },
      (child) => { child.checks.exactProjectAndRegion = [true]; },
      (child) => { child.outputs.functions[0].updateTime = '2020-01-01T00:00:00Z'; },
      (child) => { child.outputs.functions[0].firebaseFunctionsHash = '0'.repeat(40); },
      ...(key === 'iamDependencies' ? [
        (child) => {
          child.outputs.currentSourceDependencies.dependencyInventorySha256 = '0'.repeat(64);
          for (const fn of child.outputs.functions) fn.dependencies.dependencyInventorySha256 = '0'.repeat(64);
        },
      ] : []),
    ];
    for (const [index, mutate] of cases.entries()) {
      const child = structuredClone(original);
      mutate(child);
      const sealed = sealReceipt(child);
      f.receipt.cleanMainLiveReadbacks[key].canonicalReceiptSha256 = sealed.receiptSha256;
      f.receipt.cleanMainLiveReadbacks[key].physicalSha256 = f.write(`release/${key}.json`, sealed);
      f.persist();
      assert.equal(f.verify().ok, false, `${key} coherent case ${index}`);
    }
    f.children[key] = original;
    f.receipt.cleanMainLiveReadbacks[key].canonicalReceiptSha256 = original.receiptSha256;
    f.receipt.cleanMainLiveReadbacks[key].physicalSha256 = f.write(`release/${key}.json`, original);
    f.persist();
  }
});

test('a separate current backend must satisfy each child decision after coherent resealing', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.receipt);
  f.deployed.functionFleetEvidenceFile = 'release/current-backend.json';
  for (const key of ['functionFleet', 'iamDependencies', 'firestoreRulesAndIndexes']) {
    const current = structuredClone(original);
    const child = structuredClone(f.children[key]);
    if (key === 'firestoreRulesAndIndexes') child.outputs.indexes.apiCount -= 1;
    else child.outputs.functions[0].state = 'FAILED';
    const sealed = sealReceipt(child);
    current.cleanMainLiveReadbacks[key] = {...current.cleanMainLiveReadbacks[key],
      file: `release/current-${key}.json`, canonicalReceiptSha256: sealed.receiptSha256,
      physicalSha256: f.write(`release/current-${key}.json`, sealed)};
    f.deployed.functionFleetEvidenceSha256 = f.write(f.deployed.functionFleetEvidenceFile, current);
    f.write('release/current-successor-state.json', f.state);
    const result = f.verify();
    assert.equal(result.ok, false, `${key} current decision`);
    assert.match(result.reasons[0], new RegExp(`${key}: decision`));
  }
});

test('deployment authority timestamps reject arrays, invalid dates and reversed nanoseconds', (t) => {
  const f = fixture(t);
  const original = structuredClone(f.receipt.authorityChronology);
  for (const mutate of [
    (value) => { value.ownerInstructionReceivedAtUtc = [value.ownerInstructionReceivedAtUtc]; },
    (value) => { value.earliestFunctionUpdateTime = '2026-09-08T00:50:50.123456789Z'; value.latestFunctionUpdateTime = '2026-09-08T00:50:50.123456788Z'; },
    (value) => { value.earliestFunctionUpdateTime = '2026-02-30T00:50:50Z'; },
  ]) {
    f.receipt.authorityChronology = structuredClone(original);
    mutate(f.receipt.authorityChronology);
    f.persist();
    assert.equal(f.verify().ok, false);
  }
});

test('a separate historical backend cannot omit its approval digest', (t) => {
  const f = fixture(t);
  const current = structuredClone(f.receipt);
  const currentFile = 'release/current-backend.json';
  const currentHash = f.write(currentFile, current);
  delete f.receipt.approvalAuthority.sha256;
  const historicalHash = f.write('release/backend.json', f.receipt);
  f.version.requiredSource.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  f.policy.versionPolicy.sourceDocumentSha256 = f.write('release/version.json', f.version);
  f.deployed.functionFleetEvidenceFile = currentFile;
  f.deployed.functionFleetEvidenceSha256 = currentHash;
  f.write('release/current-successor-state.json', f.state);
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /Historical backend approval: physical SHA-256/);
});

test('promotion governance remains bound to the recorded Git tree and complete CI evidence in both receipts', (t) => {
  const f = fixture(t);
  const promotion = readMeasured('release/evidence/build-27-staged-controlled-pilot-authorization.json');
  const device = readMeasured(promotion.admittedEvidence.deviceAcceptance.receipt);
  f.write(promotion.ownerApproval.receipt, readMeasured(promotion.ownerApproval.receipt));
  const originalPromotion = structuredClone(promotion);
  const originalDevice = structuredClone(device);
  f.policy.postBuildPromotion = {status: 'completed-staged-controlled-pilot-only',
    promotionReceiptFile: 'release/evidence/build-27-staged-controlled-pilot-authorization.json'};
  const persist = () => {
    promotion.admittedEvidence.deviceAcceptance.sha256 = f.write(promotion.admittedEvidence.deviceAcceptance.receipt, device);
    f.policy.postBuildPromotion.promotionReceiptSha256 = f.write(f.policy.postBuildPromotion.promotionReceiptFile, promotion);
  };
  persist();
  // No foreign Git objects: even otherwise matching receipts must fail closed.
  fs.unlinkSync(path.join(f.root, '.git/objects/info/alternates'));
  assert.equal(f.verify().ok, false);
  const objects = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'],
    {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(f.root, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(f.root, '.git/objects/info/alternates'), `${objects.replace(/\\/g, '/')}\n`);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const policyFile = 'release/test-policy.json';
  f.write(policyFile, f.policy);
  const script = path.join(repositoryRoot, 'tools/release/stagedPromotionSourceAuthority.js');
  const cli = () => execFileSync(process.execPath, [script, f.root, path.join(f.root, policyFile)],
    {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
  assert.equal(JSON.parse(cli()).ok, true);
  for (const mutate of [
    () => { promotion.sourceAuthority.governanceMainCommit = device.sourceAndCiAuthority.governanceMainCommit = '0'.repeat(40); },
    () => { promotion.sourceAuthority.governanceMainTree = device.sourceAndCiAuthority.governanceMainTree = '0'.repeat(40); },
    () => { promotion.sourceAuthority.postMergeCi.runId = device.sourceAndCiAuthority.postMergeReleaseGateRunId = 1; },
    () => { delete promotion.sourceAuthority.postMergeCi.requiredJobCount; },
    () => { delete device.sourceAndCiAuthority.requiredJobCount; },
    () => { device.sourceAndCiAuthority.allRequiredJobsPassed = [true]; },
  ]) {
    Object.assign(promotion, structuredClone(originalPromotion));
    Object.assign(device, structuredClone(originalDevice));
    mutate();
    persist();
    const result = f.verify();
    assert.equal(result.ok, false);
    assert.match(result.reasons[0], /Promotion governance/);
  }
  for (const field of ['instructionVerbatim', 'codexThreadId', 'instructionContext', 'scopeInterpretation']) {
    Object.assign(promotion, structuredClone(originalPromotion));
    Object.assign(device, structuredClone(originalDevice));
    const pilotApproval = readMeasured(promotion.ownerApproval.receipt);
    pilotApproval.authority[field] = 'No pilot distribution is authorized by this owner instruction.';
    promotion.ownerApproval.sha256 = f.write(promotion.ownerApproval.receipt, pilotApproval);
    persist();
    const result = f.verify();
    assert.equal(result.ok, false, field);
    assert.match(result.reasons[0], /Pilot owner: approval.*custody/);
  }
  f.write(policyFile, f.policy);
  assert.throws(cli, /Command failed/);
});

test('mutable Git replacement refs cannot replace the admitted approval custody', (t) => {
  const f = fixture(t);
  f.approval.approverName = 'Different owner';
  f.approval.approvalEvidence.instructionVerbatim = 'Do not deploy anything.';
  f.persist();
  f.git('add', '.');
  f.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
    'commit', '--quiet', '-m', 'Unadmitted replacement custody');
  f.git('replace', '41adfaecd7974f3f48b9f023a90890c860ab44af', f.git('rev-parse', 'HEAD'));
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /approval.*custody/);
});

test('the actual PowerShell policy block rejects coherent changes to the complete promotion scope', (t) => {
  const f = fixture(t);
  const promotionFile = 'release/evidence/build-27-staged-controlled-pilot-authorization.json';
  const original = readMeasured(promotionFile);
  f.write(original.admittedEvidence.deviceAcceptance.receipt, readMeasured(original.admittedEvidence.deviceAcceptance.receipt));
  f.write(original.ownerApproval.receipt, readMeasured(original.ownerApproval.receipt));
  f.policy.postBuildPromotion = {status: 'completed-staged-controlled-pilot-only', promotionReceiptFile: promotionFile};
  const policyFile = path.join(f.root, 'release/test-policy.json');
  const persist = (promotion) => {
    f.policy.postBuildPromotion.promotionReceiptSha256 = f.write(promotionFile, promotion);
    f.write('release/test-policy.json', f.policy);
  };
  const quote = (value) => value.replaceAll("'", "''");
  const script = `
    $ErrorActionPreference = 'Stop'
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('${quote(path.join(repositoryRoot, 'tools/release/Test-ProductionReleasePolicy.ps1'))}', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Verifier does not parse' }
    $statements = $ast.EndBlock.Statements
    $start = -1
    for ($index = 0; $index -lt $statements.Count; $index++) {
      if ($statements[$index].Extent.Text.StartsWith('$stagedAuthorityOutput =')) { $start = $index; break }
    }
    if ($start -lt 0) { throw 'Shared authority predicate is missing' }
    $block = ($statements[$start..($start + 3)] | ForEach-Object { $_.Extent.Text }) -join "\n"
    $RepositoryRoot = '${quote(f.root)}'
    $PolicyPath = '${quote(policyFile)}'
    Invoke-Expression $block
    'PASS_SHARED_STAGED_AUTHORITY'
  `;
  const invoke = () => execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script],
    {cwd: repositoryRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
  persist(original);
  assert.match(invoke(), /PASS_SHARED_STAGED_AUTHORITY/);
  for (const mutate of [
    (value) => { value.promotion.authorizedUsers = 'any users'; value.promotion.authorizedTargets = 'unapproved devices'; },
    (value) => { delete value.promotion.preHandoutRequirements; },
    (value) => { value.reArmConditions = []; },
    (value) => { value.qualification = 'Public distribution is approved.'; },
    (value) => { value.promotion.acceptedResidualGap = 'All mutating business flows are validated.'; },
  ]) {
    const promotion = structuredClone(original);
    mutate(promotion);
    persist(promotion);
    assert.throws(invoke, /Command failed/);
  }
});
