import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const require = createRequire(import.meta.url);
const {verifyBuild31ClientCompatibility, verifyClientBackendSourceAuthority: verifyStagedPromotionSourceAuthority} = require('./clientBackendCompatibility31.js');
const {sealReceipt} = require('./collectProductionGlobalPullBackend.js');
const root = execFileSync('git', ['-C', path.dirname(fileURLToPath(import.meta.url)), 'rev-parse', '--show-toplevel'], {encoding:'utf8',windowsHide:true}).trim();
const baseline = '7ed87824447f1349cb0481c448e0b21c3fa5856f';
const backendFile = 'release/evidence/build30-current-source-backend-deployment-closure.json';
const backendSha256 = '3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45';
const backendCommit = '2aa30de56cfdb960da3eeefd8956d8cbbae57b46';
const decisionFile = 'release/approvals/build31-client-development-tool-compatibility-approval.json';
const ownerFile = 'release/approvals/build31-client-development-tool-owner-authorization.json';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const releaseJobs = ['Flutter host analysis + tests + no-loss contracts',
  'Android release package + cold-start proof (non-production)',
  'Android emulator shell + business integration (not physical-device evidence)',
  'Firestore Rules + governed callable emulator', 'Cloud Functions host build + non-emulator tests'];
const securityJobs = ['CodeQL (actions)', 'CodeQL (java-kotlin)', 'CodeQL (javascript-typescript)', 'CodeQL (python)'];

// Synthetic Git/CI/readbacks test the protocol. They are never production authority.
function fixture(t, options = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-client31-'));
  t.after(() => {
    const actual = fs.realpathSync(directory);
    assert.equal(path.dirname(actual), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(actual), /^crm3-client31-/);
    fs.rmSync(actual, {recursive: true});
  });
  const git = (...args) => execFileSync('git', ['--no-replace-objects', '-C', directory, ...args],
    {encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']}).trim();
  git('init', '--quiet');
  const objects = execFileSync('git', ['-C', root, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'], {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(directory, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(directory, '.git/objects/info/alternates'), `${objects.replaceAll('\\', '/')}\n`);
  const now = Date.now(), instant = delta => new Date(now + delta).toISOString();
  const commit = (parent, delta) => execFileSync('git', ['-C', directory, 'commit-tree', git('write-tree'), '-p', parent, '-m', 'Synthetic client31 fixture'],
    {encoding: 'utf8', windowsHide: true, env: {...process.env,
      GIT_AUTHOR_NAME: 'Synthetic Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
      GIT_COMMITTER_NAME: 'Synthetic Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid',
      GIT_AUTHOR_DATE: instant(delta), GIT_COMMITTER_DATE: instant(delta)}}).trim();
  const write = (file, value) => {
    const bytes = `${JSON.stringify(value, null, 2)}\n`;
    fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});
    fs.writeFileSync(path.join(directory, file), bytes);
    git('add', '--', file); return {file, sha256: sha(bytes)};
  };
  const candidateRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const gitRaw = (...args) => execFileSync('git', ['--no-replace-objects', '-C', directory, ...args], {encoding:'utf8',windowsHide:true});
  const writeRaw = (file, bytes) => {fs.mkdirSync(path.dirname(path.join(directory,file)), {recursive:true});fs.writeFileSync(path.join(directory,file),bytes);const blob=execFileSync('git',['-C',directory,'hash-object','-w','--stdin'],{input:bytes,encoding:'utf8',windowsHide:true}).trim();git('update-index','--add','--cacheinfo',`100644,${blob},${file}`);};
  git('read-tree', baseline);
  for (const file of ['package.json','package-lock.json','functions/package-lock.json','tooling/brace-expansion-compat/package.json','tooling/firebase-cli/package.json','tooling/firebase-cli/package-lock.json',
    'tools/release/collectClientBuildToolingRuntime31.cjs','tools/release/clientBuildToolingCompatibility31.cjs','tools/release/clientBuildToolingGitSnapshots31.cjs','tools/release/clientBuildToolingReadbacks31.cjs','tools/release/collectClientDevelopmentToolIam31.cjs']) writeRaw(file,fs.readFileSync(path.join(candidateRoot,file)));

  write(options.drift ?? 'lib/synthetic_client31_fixture.json', {synthetic: true});
  const sourceCommit = commit(options.unrelatedSource ? backendCommit : baseline, -120000);
  const source = {commit: sourceCommit, tree: git('rev-parse', `${sourceCommit}^{tree}`),
    functionsGitObjectId: git('rev-parse', `${sourceCommit}:functions`), pullRequestNumber: 999,
    postMergeReleaseGateRunId: 1001, postMergeSecurityRunId: 1002};
  const scope = {clientConstructionOnly: true, backendDeploymentAuthorized: false,
    backendRuntimeChanged: false, backendBuildTestDependenciesChanged: true, firestoreRulesOrIndexesChanged: false,
    iamOrEnforcementChangeAuthorized: false, distributionAuthorized: false};
  const originalBytes = fs.readFileSync(path.join(root, backendFile));
  assert.equal(sha(originalBytes), backendSha256);
  fs.mkdirSync(path.dirname(path.join(directory, backendFile)), {recursive: true});
  fs.writeFileSync(path.join(directory, backendFile), originalBytes); git('add', '--', backendFile);
  const backend = JSON.parse(originalBytes);
  const existingBackend = {file: backendFile, sha256: backendSha256, sourceCommit: backendCommit};
  const owner = {schemaVersion: 2, documentType: 'source-specific-client-existing-backend-development-tool-owner-authorization',
    approved: true, intendedBuildNumber: 31, firebaseProjectId: 'crm3-baf-ops-b8638',
    sourceCommit, sourceTree: source.tree, existingBackend, scope, ownerInstruction: 'Synthetic test only: authorize this exact client source over the unchanged backend.',
    ownerReference: 'synthetic-test-only', recordedBy: 'Synthetic Fixture', authorizedAtUtc: instant(-45000), recordedAtUtc: instant(-40000)};
  const decision = {schemaVersion: 2, documentType: 'governed-client-existing-backend-development-tool-compatibility-approval',
    approved: true, intendedBuildNumber: 31, firebaseProjectId: 'crm3-baf-ops-b8638',
    approverName: 'Codex acting under project-owner delegation', approvedAtUtc: instant(-10000),
    sourceAuthority: source, existingBackend, scope,
    approvalEvidence: {authorityType: 'owner-delegated agent decision',
      delegationPolicyId: 'BUILD31-CLIENT-EXISTING-BACKEND-DEVELOPMENT-TOOL-COMPATIBILITY',
      delegatedDecisionAtUtc: instant(-10000), recordedAtUtc: instant(-9000),
      ownerReference: owner.ownerReference, instructionExcerpts: [owner.ownerInstruction]}, liveBackendReadbacks: {}};
  const {verifyGitDevelopmentTooling} = require('./clientBuildToolingGitSnapshots31.cjs');
  const gitProof = verifyGitDevelopmentTooling({repoRoot:directory,candidateCommit:sourceCommit});
  decision.developmentToolingChange = {baselineCommit:gitProof.baselineCommit,baselineTree:gitProof.baselineTree,candidateCommit:gitProof.candidateCommit,candidateTree:gitProof.candidateTree,protectedInventorySha256:gitProof.inventorySha256,protectedFileCount:gitProof.protectedFileCount,changedFiles:gitProof.changedFiles,backendRuntimeChanged:false,backendBuildTestDependenciesChanged:true};
  const ci = {};
  for (const [key, file, evidenceType, workflow, names, id] of [
    ['mainCi', 'release/evidence/build31-client-source-main-ci.json', 'github-exact-main-release-gate', '.github/workflows/release-gate.yml', releaseJobs, 1001],
    ['securityCi', 'release/evidence/build31-client-source-main-security.json', 'github-exact-main-codeql', '.github/workflows/codeql.yml', securityJobs, 1002],
  ]) {
    ci[key] = {schemaVersion: 1, evidenceType, repository: 'abhishekvatsa/crm3_baf_ops', sourceCommit, sourceTree: source.tree,
      capturedAtUtc: instant(-55000), pullRequest: {number: 999, merged: true, merge_commit_sha: sourceCommit,
        merged_at: instant(-115000), base: {ref: 'main', repo: {full_name: 'abhishekvatsa/crm3_baf_ops'}}},
      run: {id, run_attempt: 1, repository: {full_name: 'abhishekvatsa/crm3_baf_ops'}, head_sha: sourceCommit, head_branch: 'main',
        event: 'push', path: workflow, status: 'completed', conclusion: 'success', created_at: instant(-110000), updated_at: instant(-60000)},
      jobs: {total_count: names.length, jobs: names.map((name, index) => ({id: id * 100 + index, name, run_id: id, run_attempt: 1,
        head_sha: sourceCommit, status: 'completed', conclusion: 'success', completed_at: instant(-65000)}))}};
    source[key] = {file};
  }
  const readbacks = {};
  for (const key of ['functionFleet', 'iamDependencies', 'firestoreRulesAndIndexes']) {
    readbacks[key] = JSON.parse(fs.readFileSync(path.join(root, backend.cleanMainLiveReadbacks[key].file), 'utf8'));
    for (const point of ['before', 'after']) Object.assign(readbacks[key].source[point], {commit: sourceCommit, tree: source.tree, originMain: sourceCommit});
    readbacks[key].capturedAtUtc = instant(-30000);
    if (key === 'functionFleet') readbacks[key].outputs.schedulerBacklog.observedAtUtc = instant(-35000);
    if (Object.hasOwn(readbacks[key], 'collectionStartedAtUtc')) readbacks[key].collectionStartedAtUtc = instant(-35000);
  }
  const policy = {firebaseProjectId: 'crm3-baf-ops-b8638', release: {buildNumber: 31}, versionPolicy: {buildNumber: 31},
    finalization: {exactFunctionFleetDeploymentReceiptFile: backendFile, exactFunctionFleetDeploymentReceiptSha256: backendSha256}};
  const version = {sourceBaseline: {commit: sourceCommit, tree: source.tree}, requiredSource: {}};
  const {createDualSourceIamReceipt} = require('./clientBuildToolingReadbacks31.cjs');
  const iam = require('./collectFunctionsIamDependenciesReadback.js');
  const iamPolicy = JSON.parse(gitRaw('show',backendCommit+':'+iam.POLICY_PATH));
  const candidateDependencies = iam.summarizePackageState({packageJsonRaw:gitRaw('show',sourceCommit+':functions/package.json'),packageLockRaw:gitRaw('show',sourceCommit+':functions/package-lock.json'),trackedPackages:iamPolicy.trackedRuntimePackages});
  const oldIam = readbacks.iamDependencies;
  const originalObserve = iam.adjudicateReadback({projectId:'crm3-baf-ops-b8638',region:'asia-south1',sourceBefore:oldIam.source.before,sourceAfter:oldIam.source.after,policy:iamPolicy,project:oldIam.outputs.project,iam:oldIam.outputs.iam,functions:oldIam.outputs.functions,currentDependencies:candidateDependencies,discoveredSourceExports:[...iamPolicy.sourceFunctionExports].sort(),observe:true});
  readbacks.iamDependencies = createDualSourceIamReceipt({repoRoot:directory,candidateCommit:sourceCommit,rawCapture:sealReceipt({...originalObserve.evidence,capturedAtUtc:instant(-30000)}),collectionStartedAtUtc:instant(-35000),capturedAtUtc:instant(-25000)});
  const rt = require('./collectClientBuildToolingRuntime31.cjs');
  const {fixture:runtimeFixture,byteRecord,installedFixtureFromLock} = require('./clientBuildToolingRuntime31.synthetic-fixture.cjs');
  const runtime = runtimeFixture().receipt;
  runtime.installed = Object.fromEntries(['baseline','candidate'].map(side => {const inputs=rt.runtimeInputs(directory,side==='baseline'?backendCommit:sourceCommit);return [side,installedFixtureFromLock(inputs.manifest,inputs.lock)];}));
  const runtimePoint = {commit:sourceCommit,tree:source.tree,branch:'main',originMain:sourceCommit,clean:true};
  const sources = {baseline:rt.sourceInventory(directory,backendCommit),candidate:rt.sourceInventory(directory,sourceCommit)};
  const outputPaths = sources.baseline.filter(r=>r.path.startsWith('functions/src/')&&r.path.endsWith('.ts')).flatMap(r=>{const name=r.path.slice('functions/src/'.length).replace(/\.ts$/,'.js');return[name,name+'.map'];}).sort();
  const emitted = Object.fromEntries(outputPaths.map(p=>[p,{sha256:'A'.repeat(64),bytes:1}]));
  const canonical = value => Array.isArray(value)?'['+value.map(canonical).join(',')+']':value&&typeof value==='object'?'{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}':JSON.stringify(value);
  Object.assign(runtime,{candidateCommit:sourceCommit,candidateTree:source.tree,startedAtUtc:instant(-49000),completedAtUtc:instant(-39000),sourceBefore:runtimePoint,sourceAfter:{...runtimePoint},producerHashes:rt.producerHashes(directory,sourceCommit),gitProof,exportedSources:sources,ciHashes:{release:sha(canonical(ci.mainCi)),security:sha(canonical(ci.securityCi))},emitted:{baseline:emitted,candidate:structuredClone(emitted)}});
  for(const[index,command]of runtime.commands.entries()){
    command.startedAtUtc=instant(-48000+index*500);command.completedAtUtc=instant(-47600+index*500);
    if(command.id.endsWith('-installed')){command.structuredResult=runtime.installed[command.id.startsWith('baseline')?'baseline':'candidate'];command.stdoutText=JSON.stringify(command.structuredResult)+'\n';command.stdout=byteRecord(command.stdoutText);}
    if(command.id.endsWith('-emitted')){command.structuredResult={sourceCount:outputPaths.length/2,expectedFiles:outputPaths,actualFiles:outputPaths};command.stdoutText=JSON.stringify(command.structuredResult)+'\n';command.stdout=byteRecord(command.stdoutText);}
  }
  const persist = () => {
    decision.sourceAuthority = source;
    for (const key of ['mainCi', 'securityCi']) source[key] = write(source[key].file, ci[key]);
    for (const key of Object.keys(readbacks)) {
      const {receiptSha256, ...body} = readbacks[key];
      decision.liveBackendReadbacks[key] = write(key==='iamDependencies'?'release/evidence/build31-client-development-tool-iam-dependencies.json':`release/evidence/build31-client-compatibility-${key}.json`, sealReceipt(body));
    }
    const {receiptSha256:oldRuntimeSeal,...runtimeBody}=runtime;
    decision.runtimeCompatibilityEvidence=write('release/evidence/build31-development-tool-runtime-proof.json',sealReceipt(runtimeBody));
    decision.approvalEvidence.ownerAuthorization = write(ownerFile, owner);
    const pointer = write(decisionFile, decision);
    pointer.commit = commit(options.unrelatedCustody ? baseline : sourceCommit, -5000);
    git('update-ref', 'refs/heads/fixture', pointer.commit);
    git('symbolic-ref', 'HEAD', 'refs/heads/fixture');
    policy.clientBackendCompatibility = pointer;
    version.requiredSource.clientBackendCompatibility = structuredClone(pointer);
  };
  persist();
  return {directory, policy, version, backend, source, owner, decision, ci, readbacks, runtime, persist,
    verify: () => verifyBuild31ClientCompatibility({repoRoot: directory, releasePolicy: policy, version, backendReceipt: backend})};
}


test('private schema2 whole-branch synthetic authority tests',async t=>{
 const f=fixture(t);
 const names=['source','owner','decision','ci','readbacks','runtime'];
 const saved=Object.fromEntries(names.map(name=>[name,structuredClone(f[name])]));
 function restore(){for(const name of names){for(const key of Object.keys(f[name]))delete f[name][key];Object.assign(f[name],structuredClone(saved[name]));}}
 await t.test('accepts fully bound synthetic M tools and separately preserved F backend',()=>{const result=f.verify();assert.equal(result.sourceCommit,f.source.commit);assert.equal(f.decision.scope.backendRuntimeChanged,false);assert.equal(f.decision.scope.backendBuildTestDependenciesChanged,true);assert.equal(f.backend.sourceAuthority.commit,backendCommit);});
 for(const[name,change]of [
 ['unknown decision field',f=>{f.decision.unverified=true;}],
 ['unknown source field',f=>{f.source.backendDeploymentAuthorized=true;}],
 ['unknown owner field',f=>{f.owner.messageReceivedAtUtc=f.owner.authorizedAtUtc;}],
 ['old misleading scope',f=>{delete f.decision.scope.backendRuntimeChanged;f.decision.scope.backendSourceChanged=false;}],
 ['old decision schema',f=>{f.decision.schemaVersion=1;}],
 ['old owner scope',f=>{delete f.owner.scope.backendBuildTestDependenciesChanged;}],
 ['wrong exact Git inventory',f=>{f.decision.developmentToolingChange.protectedInventorySha256='0'.repeat(64);}],
 ['missing runtime command',f=>{f.runtime.commands.pop();}],
 ['truncated equal emitted evidence',f=>{f.runtime.emitted.baseline=f.runtime.emitted.candidate={'index.js':{sha256:'A'.repeat(64),bytes:1}};}],
 ['runtime proof predating CI',f=>{f.runtime.startedAtUtc='2026-09-01T00:00:00Z';}],
 ['old IAM observation resealed',f=>{f.readbacks.iamDependencies.collectionStartedAtUtc='2026-09-01T00:00:00Z';}],
 ['candidate mislabeled deployed inventory',f=>{f.readbacks.iamDependencies.candidateBuild.dependencies=f.readbacks.iamDependencies.deployedBackend.dependencies;}],
 ['distribution authority',f=>{f.decision.scope.distributionAuthorized=true;}],
])await t.test('rejects coherently recustodied '+name,()=>{restore();change(f);f.persist();assert.throws(f.verify);});
});
