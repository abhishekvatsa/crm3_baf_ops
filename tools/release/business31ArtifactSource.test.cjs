'use strict';
// Business31 binds its artifact baseline to the recorded M, and the hosted verifier admits only enrolled
// integration files that equal V. Three copies decide which approved-path drift that admits: the policy gate
// (Test-ProductionReleasePolicy.ps1), the canonical audit (tools/v4/v4_2_r1_canonical_audit.py) and
// test/successor_engineering_rearm_contract_test.dart. This test runs the first two over one real Git fixture
// and requires both to admit exactly the enrolled integration and nothing else; the Dart copy runs the same
// cases in its own suite. The integration commitment comes from the verifier's own JS canonical form.
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), crypto = require('node:crypto');
const cp = require('node:child_process');
const protocol = require('./business31HostedProtocol.cjs');
const sourceRoot = path.resolve(__dirname, '../..');
const RECORD = 'release/evidence/build31-business-private-replay.json';
const VERSION = '1.0.0-rc.21+31';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const python = process.env.BUSINESS31_TEST_PYTHON || (process.platform === 'win32' ? 'C:/Python313/python.exe' : 'python3');
const pwsh = process.env.BUSINESS31_TEST_PWSH || (process.platform === 'win32' ? 'C:/Program Files/PowerShell/7/pwsh.exe' : 'pwsh');
// Isolated from system and global Git configuration (for example a system core.autocrlf).
const gitEnv = {...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
  GIT_TERMINAL_PROMPT: '0'};

function listed(file, pattern) {
  const match = pattern.exec(fs.readFileSync(path.join(sourceRoot, file), 'utf8'));
  assert.ok(match, 'approved path list absent from ' + file);
  return [...match[1].matchAll(/['"]([^'"]+)['"]/g)].map(item => item[1]);
}
const APPROVED = listed('tools/release/Test-ProductionReleasePolicy.ps1', /\$ApprovedArtifactExactSourcePaths\s*=\s*@\((.*?)\r?\n\)/s);

function createFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-artifact-source-'));
  const git = (...args) => cp.execFileSync('git', ['-c', 'user.name=Build31 fixture', '-c', 'user.email=fixture@invalid',
    '-c', 'core.autocrlf=false', '-c', 'commit.gpgsign=false', ...args],
  {cwd: root, env: gitEnv, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 * 1024 * 1024}).toString('utf8').trim();
  const write = (file, data) => {
    fs.mkdirSync(path.dirname(path.join(root, file)), {recursive: true});
    fs.writeFileSync(path.join(root, file), data);
  };
  git('init', '-q');
  for (const approved of APPROVED) write(approved.split('/').pop().includes('.') ? approved : approved + '/kept.txt', `baseline ${approved}\n`);
  write('android/removable.txt', 'baseline android member\n');
  write('pubspec.yaml', 'name: fixture\nversion: 1.0.0-rc.20+30\n');
  git('add', '-A'); git('commit', '-q', '-m', 'M');
  const M = git('rev-parse', 'HEAD');
  const integrate = () => {
    write('tools/release/integrated.cjs', 'verifier change\n');
    write('test/integrated_test.dart', 'verifier test\n');
  };
  integrate(); git('add', '-A'); git('commit', '-q', '-m', 'V');
  const V = git('rev-parse', 'HEAD');
  git('checkout', '-q', '-b', 'sibling', M);
  integrate(); git('add', '-A'); git('commit', '-q', '-m', 'unrelated V');
  const sibling = git('rev-parse', 'HEAD');
  const blob = (commit, file) => cp.execFileSync('git', ['cat-file', 'blob', `${commit}:${file}`], {cwd: root, env: gitEnv, windowsHide: true});
  const entry = (commit, file) => ({mode: '100644', oid: git('rev-parse', `${commit}:${file}`), sha256: sha(blob(commit, file))});
  const record = ({verifier = V, source = M} = {}) => ({schemaVersion: 3, documentType: 'build31-business-backend-private-replay',
    profile: 'build31-exact-business-backend-v2', verifier: {commit: verifier}, source: {commit: source},
    sourceIntegration: {'test/integrated_test.dart': entry(V, 'test/integrated_test.dart'),
      'tools/release/integrated.cjs': entry(V, 'tools/release/integrated.cjs')}});
  // Candidate S on V with the replay record and the Build 31 version; returns its commit and policy pointer.
  function candidate({change, afterAdd, replay} = {}) {
    git('checkout', '-q', '-f', '-B', 'candidate', V); git('clean', '-q', '-f', '-d');
    write('pubspec.yaml', `name: fixture\nversion: ${VERSION}\n`);
    if (change) change();
    const descriptor = replay || record(), bytes = Buffer.from(JSON.stringify(descriptor, null, 2) + '\n');
    write(RECORD, bytes);
    git('add', '-A');
    if (afterAdd) afterAdd();
    git('commit', '-q', '-m', 'S');
    const commit = git('rev-parse', 'HEAD');
    return {commit, descriptor, pointer: {profile: 'build31-exact-business-backend-v2', file: RECORD, sha256: sha(bytes), commit}};
  }
  return {root, git, write, M, V, sibling, record, candidate};
}

// Exact replay measurement commitment, computed by the verifier's own JS canonical form.
const commitment = descriptor => protocol.transportCommitments31({schemaVersion: 2, profile: protocol.PROFILE_V2,
  coreVerifier: {files: {}}, sourceIntegration: descriptor.sourceIntegration}).sourceIntegrationSha256;

function runPowerShell(root, cases) {
  const program = String.raw`$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$d=[Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 50
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($d.source,[ref]$tokens,[ref]$errors)
if ($errors) { throw 'Policy source syntax error' }
foreach ($fn in $ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] }) { Invoke-Expression $fn.Extent.Text }
$assign=@($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -ceq '$ApprovedArtifactExactSourcePaths' })
if ($assign.Count -ne 1) { throw 'Approved path list absent' }
Invoke-Expression $assign[0].Extent.Text
. $d.bridge
$RepositoryRoot=$d.root
Push-Location -LiteralPath $d.root
$results=[ordered]@{}
try {
  foreach ($case in $d.cases) {
    git checkout -q -f $case.commit 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Fixture checkout failed' }
    $policy=[pscustomobject]@{ businessBackendPrivateReplay=[pscustomobject]$case.pointer }
    $proof=[pscustomobject]@{ businessBackend31=[pscustomobject]@{
      descriptorPointer=[ordered]@{ commit=$case.pointer.commit; file=$case.pointer.file; sha256=$case.pointer.sha256 }
      source=[ordered]@{ commit=$d.baseline }
      policyResult=[ordered]@{ commitments=[ordered]@{ sourceIntegrationSha256=$case.commitment } } } }
    try {
      $integration = if ($case.strict) { $null } else {
        Get-Business31ArtifactSourceIntegration -Policy $policy -Proof $proof -BaselineCommit $d.baseline -CurrentCommit 'HEAD' }
      $status = Get-ApprovedArtifactSourceStatus -BaselineCommit $d.baseline -CurrentCommit 'HEAD' -ExpectedPackageVersion $d.version -SourceIntegration $integration
      $results[$case.name] = [ordered]@{ matches=[bool]$status.matches; integrated=@($status.integratedFiles | Sort-Object); refusal=$null }
    } catch {
      $results[$case.name] = [ordered]@{ matches=$false; integrated=@(); refusal=[string]$_.Exception.Message }
    }
  }
} finally { Pop-Location }
[Console]::Out.Write((ConvertTo-Json -InputObject $results -Depth 10 -Compress))
`;
  const input = {source: path.join(__dirname, 'Test-ProductionReleasePolicy.ps1'), bridge: path.join(__dirname, 'Business-BackendPrivateReplay31.ps1'),
    root, ...cases};
  const output = cp.execFileSync(pwsh, ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', program],
    {input: Buffer.from(JSON.stringify(input)), env: gitEnv, timeout: 300000, maxBuffer: 16 * 1024 * 1024, windowsHide: true});
  return JSON.parse(output.toString('utf8'));
}

function runPython(root, cases) {
  const program = String.raw`
import ast, hashlib, json, re, subprocess, sys
from pathlib import Path
d = json.loads(sys.stdin.read())
source = Path(d['source'])
names = {'bytes_sha', 'normalized_artifact_pubspec', 'git_tree_object_id', 'git_file_text', 'unique_json_object',
         'git_output_lines', 'business31_source_integration', 'approved_artifact_integrated_files',
         'approved_artifact_source_matches'}
consts = {'APPROVED_ARTIFACT_EXACT_SOURCE_PATHS', 'BUSINESS31_REPLAY_RECORD', 'BUSINESS31_INTEGRATION_FILE',
          'GIT_RAW_CHANGE', 'GIT_LS_TREE_BLOB'}
tree = ast.parse(source.read_bytes())
body = [n for n in tree.body if (isinstance(n, ast.FunctionDef) and n.name in names) or
        (isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id in consts for t in n.targets))]
assert len(body) == len(names) + len(consts)
root = Path(d['root'])
scope = {'ROOT': root, 'json': json, 're': re, 'subprocess': subprocess, 'hashlib': hashlib}
exec(compile(ast.Module(body=body, type_ignores=[]), str(source), 'exec'), scope)
results = {}
for case in d['cases']:
    subprocess.run(['git', 'checkout', '-q', '-f', case['commit']], cwd=root, check=True, capture_output=True)
    policy = {'businessBackendPrivateReplay': case['pointer']}
    integration = None if case['strict'] else scope['business31_source_integration'](policy, d['baseline'])
    files = []
    if integration is not None:
        for path in scope['APPROVED_ARTIFACT_EXACT_SOURCE_PATHS']:
            if scope['git_tree_object_id'](d['baseline'], path) != scope['git_tree_object_id']('HEAD', path):
                files += scope['approved_artifact_integrated_files'](d['baseline'], path, integration) or []
    results[case['name']] = {'matches': scope['approved_artifact_source_matches'](d['baseline'], d['version'], integration),
                             'integrated': sorted(files), 'admitted': integration is not None}
sys.stdout.write(json.dumps(results))
`;
  const input = {source: path.join(sourceRoot, 'tools/v4/v4_2_r1_canonical_audit.py'), root, ...cases};
  const output = cp.execFileSync(python, ['-I', '-S', '-B', '-c', program],
    {input: Buffer.from(JSON.stringify(input)), env: gitEnv, timeout: 300000, maxBuffer: 16 * 1024 * 1024, windowsHide: true});
  return JSON.parse(output.toString('utf8'));
}

test('policy gate, canonical audit and Dart contract share one approved artifact path list', () => {
  assert.ok(APPROVED.length >= 20);
  assert.deepEqual(listed('tools/v4/v4_2_r1_canonical_audit.py', /APPROVED_ARTIFACT_EXACT_SOURCE_PATHS = \((.*?)\r?\n\)/s), APPROVED);
  assert.deepEqual(listed('test/successor_engineering_rearm_contract_test.dart', /const _approvedArtifactExactSourcePaths = <String>\[(.*?)\r?\n\];/s), APPROVED);
  for (const integrated of ['tools/release/Test-ProductionReleasePolicy.ps1', 'test/successor_engineering_rearm_contract_test.dart',
    'test/stage2d_f_internal_controlled_deployment_scope_contract_test.dart', 'tools/release/business31ArtifactSource.test.cjs']) {
    assert.ok(require('./business31TrustedInputV2.cjs').INTEGRATION_PATHS.includes(integrated), integrated);
  }
});

test('policy gate and canonical audit admit exactly the enrolled business31 integration drift', () => {
  const f = createFixture();
  try {
    const cases = [];
    const add = (name, built, extra = {}) => cases.push({name, commit: built.commit, pointer: built.pointer,
      commitment: commitment(built.descriptor), strict: false, ...extra});
    const exact = f.candidate();
    add('exact', exact);
    add('strict', exact, {strict: true});
    add('record bytes differ from the pointer', exact, {pointer: {...exact.pointer, sha256: 'F'.repeat(64)}});
    add('integration differs from the authenticated measurement', exact, {commitment: 'F'.repeat(64)});
    add('integration file changed after V', f.candidate({change: () => f.write('tools/release/integrated.cjs', 'candidate\n')}));
    const changed = f.record();
    f.write('tools/release/integrated.cjs', 'candidate\n');
    changed.sourceIntegration['tools/release/integrated.cjs'] = {mode: '100644',
      oid: f.git('hash-object', 'tools/release/integrated.cjs'), sha256: sha(Buffer.from('candidate\n'))};
    add('record admits the candidate blob instead of V', f.candidate({replay: changed,
      change: () => f.write('tools/release/integrated.cjs', 'candidate\n')}));
    add('unlisted file under an integrated path', f.candidate({change: () => f.write('tools/release/unlisted.cjs', 'x\n')}));
    add('drift in another approved path', f.candidate({change: () => f.write('lib/unlisted.dart', 'x\n')}));
    add('deleted approved file', f.candidate({change: () => fs.rmSync(path.join(f.root, 'android/removable.txt'))}));
    add('integrated file mode change', f.candidate({afterAdd: () => f.git('update-index', '--chmod=+x', 'tools/release/integrated.cjs')}));
    add('non-version pubspec change', f.candidate({change: () => f.write('pubspec.yaml', `name: fixture\nversion: ${VERSION}\nextra: true\n`)}));
    add('verifier is not an ancestor', f.candidate({replay: f.record({verifier: f.sibling})}));
    add('record names another baseline', f.candidate({replay: f.record({source: f.V})}));
    const legacy = f.record(); legacy.schemaVersion = 2;
    add('record is not the successor descriptor', f.candidate({replay: legacy}));
    const shared = {baseline: f.M, version: VERSION, cases};
    const powershell = runPowerShell(f.root, shared), audit = runPython(f.root, shared);
    const integrated = ['test/integrated_test.dart', 'tools/release/integrated.cjs'];
    assert.deepEqual(powershell.exact, {matches: true, integrated, refusal: null});
    assert.deepEqual(audit.exact, {matches: true, integrated, admitted: true});
    assert.deepEqual([powershell.strict.matches, audit.strict.matches], [false, false]);
    // The policy gate fails loudly on authenticated-binding errors; the audit, like the Dart copy, stays strict.
    for (const [name, refusal] of [['record bytes differ from the pointer', /differs from its policy pointer/],
      ['integration differs from the authenticated measurement', /differs from the authenticated measurement/],
      ['record names another baseline', /not the exact successor descriptor/],
      ['record is not the successor descriptor', /not the exact successor descriptor/]]) {
      assert.match(powershell[name].refusal || '', refusal, name);
    }
    // The measurement commitment is the policy gate's only extra binding: the audit, without the hosted
    // measurement, relies on the pointer-bound record bytes, so it alone still admits that case.
    const gateOnly = 'integration differs from the authenticated measurement';
    assert.deepEqual(audit[gateOnly], {matches: true, integrated, admitted: true});
    assert.equal(audit['record bytes differ from the pointer'].admitted, false);
    for (const {name} of cases.filter(item => item.name !== 'exact')) {
      assert.equal(powershell[name].matches, false, 'policy gate admitted: ' + name);
      if (name !== gateOnly) assert.equal(audit[name].matches, false, 'canonical audit admitted: ' + name);
    }
  } finally {
    fs.rmSync(f.root, {recursive: true, force: true, maxRetries: 3});
  }
});
