'use strict';
// Actual packed Git, immutable historical pilot objects/receipts, current public
// bindings and entry source. Only the authenticated-consumer process boundary is
// synthetic here; PolicyResult and Prerequisite test their real API validators.
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), crypto = require('node:crypto');
const cp = require('node:child_process');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
const client = require('./business31HostedClient.cjs');
const sourceRoot = path.resolve(__dirname, '../..'), entry = path.join(__dirname, 'business31PolicyInvocation.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const raw = value => Buffer.from(JSON.stringify(value) + '\n');
const PILOT = ['runtimePilotAuthority31.cjs', 'stagedPromotionSourceAuthority.js', 'collectProductionGlobalPullBackend.js',
  'collectFunctionFleetRuntimeIdentityReadback.js', 'collectFunctionsIamDependenciesReadback.js', 'collectFirestoreRulesIndexesReadback.js',
  'deploymentFleetContract.js', 'scopedCallableInvokerIam.js', 'scopedCallableInvokerIamPublic.js', 'reviewedFirestoreRulesDeployment.js',
  'reviewedRulesRuntime.js', 'reviewedRulesRuntimeCollector.js', 'reviewedRulesReconciliation.js', 'reviewedBackendControls.js',
  'reviewedBackendVerifierAuthority.js'].map(name => 'tools/release/' + name);
const FLAGS = ['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated', 'humanIdentityAuthenticated',
  'trustedClockAuthenticated', 'originalProcessExecutionAuthenticated', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
  'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized'];
let fixture, platform, measured, constructionClient, git, savedRelease, policyProof, constructionProof;
function checkedGit(root, args, input, maxBuffer = 32 * 1024 * 1024) {
  return cp.execFileSync(git, ['--no-replace-objects', '-c', 'protocol.allow=never', '-C', root, ...args],
    {input, maxBuffer, timeout: 120000, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'],
      env: {...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
        GIT_NO_LAZY_FETCH: '1', GIT_TERMINAL_PROMPT: '0'}});
}
test.before(() => {
  fixture = createFixture({publicApprovalEnvelope: true, extraProducers: [...PILOT,
    'tools/release/business31Controller.cjs', 'tools/release/business31Prerequisite.cjs',
    'tools/release/business31PolicyResult.cjs', 'tools/release/business31PolicyInvocation.cjs']});
  git = fixture.clientInput().gitExecutable;
  // Read-only export from real retained custody into this fixture's own object
  // database. No alternates, shared index or source checkout mutation is used.
  const donor = checkedGit(sourceRoot, ['rev-parse', '--show-toplevel']).toString('utf8').trim();
  const pack = checkedGit(donor, ['pack-objects', '--stdout', '--revs'],
    Buffer.from('d95e399de07d43051d94debf36098e7998fe76d4\n41adfaecd7974f3f48b9f023a90890c860ab44af\n'), 256 * 1024 * 1024);
  checkedGit(fixture.root, ['index-pack', '--stdin', '--strict'], pack, 1024 * 1024);
  savedRelease = new Map();
  function copy(directory, relative = 'release') {
    for (const member of fs.readdirSync(directory, {withFileTypes: true})) {
      const file = path.join(directory, member.name), name = relative + '/' + member.name;
      assert.equal(fs.lstatSync(file).isSymbolicLink(), false);
      if (member.isDirectory()) copy(file, name);
      else {assert.ok(member.isFile()); savedRelease.set(name, fs.readFileSync(file));}
    }
  }
  copy(path.join(sourceRoot, 'release'));
  reset();
  platform = fixture.platformFixture();
  platform.request.schemaVersion = 2;
  platform.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
    requestedAtUtc: new Date(Date.now() - 60000).toISOString(), expiresAtUtc: new Date(Date.now() + 7200000).toISOString(),
    requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
    clientSelectionSha256: sha(raw(fixture.clientInput().selected)), fileBindings: []};
  measured = client.measureBusinessHostedClient31({trust: platform.trust, request: platform.request, input: fixture.clientInput()});
  const request = requestFor(true);
  constructionClient = client.measureBusinessHostedClient31({trust: platform.trust, request, input: fixture.clientInput()});
});
function reset() {
  fixture.reset();
  for (const [name, bytes] of [...savedRelease, ...Object.entries(fixture.S.files)]) {
    const file = path.join(fixture.root, name); fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, bytes);
  }
  fs.writeFileSync(path.join(fixture.root, '.git/HEAD'), fixture.S.commit + '\n');
}
test.beforeEach(() => reset());
function requestFor(construction) {
  const request = structuredClone(platform.request);
  if (construction) {
    request.candidate = {...request.candidate, kind: 'main', ref: 'refs/heads/main', pullRequest: null};
    request.challenge.purpose = 'construction';
    request.challenge.requester = {kind: 'github-actions', runId: '83', runAttempt: '2', invocationId: 'b'.repeat(64)};
  }
  return request;
}
function run(options = {}) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-invoke-'));
  const construction = options.construction === true, request = requestFor(construction);
  const config = {schemaVersion: 1, profile: 'build31-business-prerequisite-controller-v1', replayTrust: platform.trust,
    controller: {nodeSha256: sha(fs.readFileSync(process.execPath)), gitSha256: platform.trust.gitSha256, files: {...platform.trust.verifier.files}},
    selected: {candidate: request.candidate, descriptorPointer: request.descriptorPointer, clientSelectionSha256: request.challenge.clientSelectionSha256},
    requester: {workflowId: '91', path: '.github/workflows/production-artifact.yml', jobName: 'Governed production APK', actorIds: ['9']}, maximumWaitSeconds: 9000};
  const configFile = path.join(temporary, 'config.json'), requestFile = path.join(temporary, 'request.json');
  fs.writeFileSync(configFile, raw(config)); const configSha = sha(fs.readFileSync(configFile));
  const locator = construction ? {schemaVersion: 1, profile: 'build31-business-prerequisite-resume-v1',
    controllerConfigSha256: configSha, request} : request;
  fs.writeFileSync(requestFile, raw(locator));
  const env = {BUSINESS31_CONTROLLER_CONFIG: configFile, BUSINESS31_CONTROLLER_CONFIG_SHA256: configSha,
    BUSINESS31_VERIFIER_ROOT: sourceRoot, BUSINESS31_CONTROLLER_NODE: process.execPath, BUSINESS31_CONTROLLER_GIT: git,
    [construction ? 'BUSINESS31_CONSTRUCTION_REQUEST' : 'BUSINESS31_POLICY_REQUEST']: requestFile,
    GITHUB_TOKEN: 'synthetic-read-only-no-real-credential', NODE_OPTIONS: '',
    ...(construction ? {GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: platform.trust.repository.name, GITHUB_RUN_ID: '83',
      GITHUB_RUN_ATTEMPT: '2', GITHUB_SHA: fixture.S.commit, GITHUB_REF: 'refs/heads/main',
      GITHUB_WORKFLOW_REF: platform.trust.repository.name + '/.github/workflows/production-artifact.yml@refs/heads/main'} : {})};
  options.environment?.(env);
  const measurement = {schemaVersion: 1, profile: construction ? 'build31-business-prerequisite-measurement-v1' : 'build31-business-policy-result-v1',
    purpose: construction ? 'construction' : 'policy', verifier: platform.result.verifier, source: platform.result.source,
    candidate: request.candidate, descriptorPointer: request.descriptorPointer, closurePointer: platform.result.closurePointer,
    commitments: platform.result.commitments, runId: request.runId, runAttempt: request.runAttempt, artifactId: '71', resultSha256: 'E'.repeat(64),
    client: structuredClone(construction ? constructionClient : measured),
    ...(construction ? {challenge: request.challenge, replayMode: 'same-parent-reauthentication', freshHostedReplayVerified: true,
      limits: {deploymentAuthorized: false, constructionAuthorized: false, signingAuthorized: false, distributionAuthorized: false}}
      : {policyMeasurementVerified: true, ...Object.fromEntries(FLAGS.map(name => [name, false]))})};
  options.measurement?.(measurement);
  const calls = []; let stdout = '', stderr = '';
  const boundary = (executable, args, supplied) => {
    if (executable !== process.execPath) return cp.execFileSync(executable, args, supplied);
    calls.push({executable, args, options: supplied});
    assert.equal(args[0], '--no-global-search-paths');
    assert.equal(args[1], path.join(__dirname, construction ? 'business31Prerequisite.cjs' : 'business31PolicyResult.cjs'));
    assert.equal(supplied.env.NODE_OPTIONS, undefined); assert.equal(supplied.env.NODE_PATH, undefined);
    assert.equal(supplied.env.GH_TOKEN, undefined); assert.equal(supplied.env.GOOGLE_APPLICATION_CREDENTIALS, undefined);
    if (construction) {
      assert.deepEqual(args.slice(-2), ['--resume-request', requestFile]);
      assert.equal(supplied.env.GITHUB_RUN_ID, '83'); assert.equal(supplied.env.GITHUB_RUN_ATTEMPT, '2');
      const input = JSON.parse(fs.readFileSync(args[args.indexOf('--input') + 1]));
      assert.deepEqual(input, {schemaVersion: 1, purpose: 'construction', repositoryRoot: fixture.root,
        gitExecutable: path.resolve(git), sourceArchivePath: null, manifestPath: null, packagePaths: []});
      fs.writeFileSync(args[args.indexOf('--output') + 1], raw(measurement), {flag: 'wx'});
    }
    options.afterChild?.({temporary, configFile, requestFile});
    if (options.childFailure) throw Error('synthetic child failure');
    return construction ? Buffer.alloc(0) : raw(measurement);
  };
  const m = {exports: {}};
  const requireEntry = name => name === 'node:child_process' ? {...cp, execFileSync: boundary} :
    require(name.startsWith('./') ? path.resolve(__dirname, name) : name);
  requireEntry.main = m; requireEntry.cache = {[entry]: m};
  const proc = {execPath: process.execPath, platform: process.platform, execArgv: ['--no-global-search-paths'],
    argv: [process.execPath, entry, '--repository', fixture.root], env, exitCode: 0,
    stdout: {write(value) {stdout += value;}}, stderr: {write(value) {stderr += value;}}};
  try {
    new Function('require', 'module', 'exports', '__dirname', '__filename', 'process', fs.readFileSync(entry, 'utf8'))(
      requireEntry, m, m.exports, __dirname, entry, proc);
    return {value: stdout ? JSON.parse(stdout) : null, stderr, exitCode: proc.exitCode, calls};
  } finally {fs.rmSync(temporary, {recursive: true, force: true});}
}
test('public policy joins actual Git/C and unchanged anchored pilot through fixed isolated consumer', () => {
  const result = run(); assert.equal(result.exitCode, 0, result.stderr); assert.equal(result.calls.length, 1);
  policyProof = structuredClone(result.value);
  assert.equal(result.value.route, 'business-backend31');
  assert.ok(result.value.businessBackend31.policyResult); assert.equal(result.value.businessBackend31.prerequisiteResult, undefined);
  assert.equal(result.value.promotionReceiptFile, 'release/evidence/build-27-staged-controlled-pilot-authorization.json');
  for (const name of FLAGS) assert.equal(result.value.businessBackend31[name], false);
});
test('construction selects only same-parent reauthentication and distinct prerequisite measurement', () => {
  const result = run({construction: true}); assert.equal(result.exitCode, 0, result.stderr); assert.equal(result.calls.length, 1);
  constructionProof = structuredClone(result.value);
  assert.ok(result.value.businessBackend31.prerequisiteResult); assert.equal(result.value.businessBackend31.policyResult, undefined);
});
for (const [name, afterChild] of [
  ['HEAD movement', () => fs.writeFileSync(path.join(fixture.root, '.git/HEAD'), fixture.M.commit + '\n')],
  ['closure bytes', () => fs.appendFileSync(path.join(fixture.root, platform.result.closurePointer.file), '\n')],
  ['policy bytes', () => fs.appendFileSync(path.join(fixture.root, 'release/production-release-policy.json'), '\n')],
  ['configuration bytes', ({configFile}) => fs.appendFileSync(configFile, '\n')],
  ['request locator bytes', ({requestFile}) => fs.appendFileSync(requestFile, '\n')],
  ['historical pilot owner bytes', () => {
    const policy = fixture.records.policy;
    const promotion = JSON.parse(fs.readFileSync(path.join(fixture.root, policy.postBuildPromotion.promotionReceiptFile)));
    fs.appendFileSync(path.join(fixture.root, promotion.ownerApproval.receipt), '\n');
  }]
]) test('refuses post-child ' + name, () => {
  const result = run({afterChild}); assert.equal(result.calls.length, 1); assert.equal(result.exitCode, 1);
  assert.equal(result.value, null); assert.match(result.stderr, /^No exact-source business policy/);
});
for (const [name, options] of [
  ['child failure', {childFailure: true}],
  ['source substitution', {measurement: value => {value.source = {...value.source, commit: 'f'.repeat(40)};}}],
  ['grant elevation', {measurement: value => {value.constructionAuthorized = true;}}],
  ['wrong construction replay mode', {construction: true, measurement: value => {value.replayMode = 'fresh-dispatch';}}],
  ['empty operational locator cannot downgrade to public policy', {environment: env => {env.BUSINESS31_CONSTRUCTION_REQUEST = '';}}],
]) test('refuses ' + name, () => {
  const result = run(options); assert.equal(result.exitCode, 1); assert.equal(result.value, null);
  assert.equal(result.stderr.includes('synthetic-read-only-no-real-credential'), false);
});

function publicBindingCases() {
  assert.ok(policyProof && constructionProof, 'Actual Git/pilot positive invocation must complete first');
  return [['actual policy binding', policyProof, true], ['actual construction binding', constructionProof, true],
    ...[
      ['mixed measurement modes', v => {v.businessBackend31.prerequisiteResult = constructionProof.businessBackend31.prerequisiteResult;}],
      ['source mismatch', v => {v.businessBackend31.source.commit = 'f'.repeat(40);}],
      ['approval hash mismatch', v => {v.businessBackend31.approvalPointer.sha256 = 'F'.repeat(64);}],
      ['closure hash mismatch', v => {v.businessBackend31.closurePointer.sha256 = 'F'.repeat(64);}],
      ['changed public C', v => {v.businessBackend31.currentBackend.recordedAtUtc = '2026-01-01T00:00:01Z';}],
      ['descriptor mismatch', v => {v.businessBackend31.descriptorPointer.commit = 'f'.repeat(40);}],
      ['operational grant', v => {v.businessBackend31.constructionAuthorized = true;}],
      ['legacy route disguise', v => {v.route = 'runtime-backend31';}],
      ['policy downgrade', v => {v.businessBackend31.policyResult.profile = 'unselected-profile';}]
    ].map(([name, mutate]) => {const v = structuredClone(policyProof); mutate(v); return [name, v, false];})];
}
test('canonical business branch preserves exact C/source/pointer and scope joins', () => {
  const python = process.env.BUSINESS31_TEST_PYTHON || (process.platform === 'win32' ? 'C:/Python313/python.exe' : 'python3');
  const program = String.raw`import ast, hashlib, json, os, subprocess, sys
from pathlib import Path
from types import SimpleNamespace
d=json.load(sys.stdin)
source=Path(d['source'])
tree=ast.parse(source.read_bytes())
names={'business_backend_route_selected','business_backend_private_authority_exact'}
selected=ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[])
assert len(selected.body)==2
os.environ['BUSINESS31_CONTROLLER_NODE']=d['node']
fake=SimpleNamespace(run=lambda *a,**k:SimpleNamespace(returncode=0,stdout=json.dumps(d['proof'])),TimeoutExpired=subprocess.TimeoutExpired)
scope={'os':os,'Path':Path,'ROOT':Path(d['root']),'subprocess':fake,'json':json,'sha':lambda p:hashlib.sha256(p.read_bytes()).hexdigest().upper()}
exec(compile(selected,str(source),'exec'),scope)
result=scope['business_backend_private_authority_exact'](d['policy'],d['closure'],d['deployed'])
print(json.dumps(bool(result)))
`;
  for (const [name, proof, expected] of publicBindingCases()) {
    const input = {source: path.join(sourceRoot, 'tools/v4/v4_2_r1_canonical_audit.py'), root: fixture.root,
      node: process.execPath, proof, policy: fixture.records.policy, closure: policyProof.businessBackend31.currentBackend,
      deployed: fixture.records.currentSuccessor.authorityPlanes.deployedBackend};
    const output = cp.execFileSync(python, ['-I', '-S', '-B', '-c', program], {input: raw(input), timeout: 30000,
      maxBuffer: 1024 * 1024, windowsHide: true});
    assert.equal(JSON.parse(output), expected, name);
  }
});
test('PowerShell business branch preserves exact C/source/pointer and scope joins', () => {
  const pwsh = process.env.BUSINESS31_TEST_PWSH || (process.platform === 'win32' ? 'C:/Program Files/PowerShell/7/pwsh.exe' : 'pwsh');
  const program = String.raw`$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$d=[Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 50
. $d.bridge
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($d.source,[ref]$tokens,[ref]$errors)
if ($errors) { throw 'Policy source syntax error' }
$fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Assert-ProductionBusiness31PublicBinding'},$true)
if ($null -eq $fn) { throw 'Business public gate absent' }
Invoke-Expression $fn.Extent.Text
function Get-Sha256([string]$File) { return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash }
Push-Location -LiteralPath $d.root
try {
  Assert-ProductionBusiness31PublicBinding -Policy $d.policy -Proof $d.proof -CurrentSuccessorState $d.state
  [Console]::Out.Write('true')
} catch { [Console]::Out.Write('false') } finally { Pop-Location }
`;
  for (const [name, proof, expected] of publicBindingCases()) {
    const input = {source: path.join(__dirname, 'Test-ProductionReleasePolicy.ps1'), root: fixture.root,
      bridge: path.join(__dirname, 'Business-BackendPrivateReplay31.ps1'), proof,
      policy: fixture.records.policy, state: fixture.records.currentSuccessor};
    const output = cp.execFileSync(pwsh, ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', program],
      {input: raw(input), timeout: 30000, maxBuffer: 1024 * 1024, windowsHide: true});
    assert.equal(JSON.parse(output), expected, name);
  }
});
