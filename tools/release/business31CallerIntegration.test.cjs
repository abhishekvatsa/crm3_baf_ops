'use strict';
// Source-wiring contracts and PowerShell parsing only. No build, signing,
// workflow dispatch, emulator, credential or production script is executed.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const workflow = read('.github/workflows/production-artifact.yml');
const builder = read('tools/release/New-ProductionArtifact.ps1');
const manifest = read('tools/release/Test-ProductionReleaseManifest.ps1');
const appcheck = read('tools/release/Production-AppCheckPolicy.ps1');
const initializer = read('tools/release/Initialize-Business31Controller.ps1');
function between(text, first, last) {
  const start = text.indexOf(first), end = text.indexOf(last, start + first.length);
  assert.ok(start >= 0 && end > start, 'Required bounded source section: ' + first);
  return text.slice(start, end);
}
function ordered(text, parts) {
  let at = -1;
  for (const part of parts) {
    const next = text.indexOf(part, at + 1);
    assert.ok(next > at, 'Missing or reordered call boundary: ' + part);
    at = next;
  }
}
function step(name) {
  // readFile preserves CRLF in source; normalize only this textual selector.
  const text = workflow.replaceAll('\r\n', '\n');
  const offset = text.indexOf('      - name: ' + name + '\n');
  assert.ok(offset >= 0, name);
  const end = text.indexOf('\n      - name:', offset + 1);
  return text.slice(offset, end < 0 ? undefined : end);
}

test('construction replay precedes signing-secret materialization and irreversible reservation', () => {
  ordered(workflow, ['- name: Prepare independently enrolled business verifier',
    '- name: Prove production policy before dependencies and reservation',
    '- name: Fresh business replay before signing secrets and reservation',
    '- name: Prove production environment secrets before reservation',
    '- name: Atomically consume the build number', '- name: Build once and independently verify']);
  const prefix = workflow.slice(0, workflow.indexOf('- name: Prove production environment secrets before reservation'));
  assert.doesNotMatch(prefix, /\$\{\{\s*secrets\.CRM_ANDROID_RELEASE_/);
});

test('initial workflow dispatch uses externally bound V bridge and exports only request locator', () => {
  const body = step('Fresh business replay before signing secrets and reservation');
  ordered(body, ['HashData($configBytes)', "$entry = 'tools/release/Business-BackendPrivateReplay31.ps1'",
    '(Get-FileHash -LiteralPath $bridge', '. $bridge',
    'Invoke-ProductionBusiness31PrerequisiteReplay -Purpose Construction', '-RequestOutputPath $request',
    "$proof.replayMode -cne 'fresh-dispatch'", 'BUSINESS31_CONSTRUCTION_REQUEST=$request']);
  assert.doesNotMatch(body, /-ResumeRequestPath|CRM_ANDROID_RELEASE_|-Proof\b|-Callback\b/);
});

test('initializer is externally hash selected before it is invoked', () => {
  const body = step('Prepare independently enrolled business verifier');
  ordered(body, ['HashData($bytes)', "$entry = 'tools/release/Initialize-Business31Controller.ps1'",
    '(Get-FileHash -LiteralPath $entry', '& $entry -RepositoryRoot', '-ExportGitHubEnvironment']);
  assert.match(body, /vars\.BUSINESS31_CONTROLLER_CONFIG_SHA256/);
  assert.doesNotMatch(body, /secrets\./);
});

test('builder requires same live parent reauthentication before production builds', () => {
  const business = between(builder, 'if (Test-ProductionAppCheckBusiness31Selected $policy)', '$appCheckEvidence = $null');
  ordered(business, ['BUSINESS31_CONSTRUCTION_REQUEST', 'clientBackendCompatibility31.js',
    "$business31Proof.businessBackend31.prerequisiteResult.purpose -cne 'construction'",
    "$business31Proof.businessBackend31.prerequisiteResult.replayMode -cne 'same-parent-reauthentication'",
    '$env:GITHUB_RUN_ID', '$env:GITHUB_RUN_ATTEMPT']);
  assert.doesNotMatch(business, /Invoke-ProductionBusiness31PrerequisiteReplay|-Purpose Construction/);
  assert.ok(builder.indexOf(business) < builder.indexOf('flutter build apk'));
  assert.match(business, /else\s*\{\s*\$runtime31Proof = Get-ProductionRuntime31RepositoryEvidence/);
});

test('builder preserves independent owner, reservation and non-distribution gates', () => {
  for (const item of ['$ExpectedApprovalReference', '$ExpectedReservationId', '$ExpectedBuildNumber',
    '-RequireArtifactConstructionAuthority', 'postBuildPromotionRequiredForAnyDistribution',
    'distributionApproved -ne $false', 'controlledPilotApproved -ne $false']) assert.ok(builder.includes(item), item);
  assert.ok(builder.indexOf('-RequireArtifactConstructionAuthority') < builder.indexOf('flutter build apk'));
});

test('builder retains the original observed output separately from manifest commitments', () => {
  const body = between(builder, "if ($null -ne $business31Proof) {\n  # A retained observation".replaceAll('\n', builder.includes('\r\n') ? '\r\n' : '\n'),
    'Write-Utf8NoBom `');
  ordered(body, ["'business31-construction-observation.json'", '([string]$businessOutput[0]',
    "'build31-business-construction-record-v2'", "'build31-business-construction-record-v1'", 'constructionObservationSha256 = Get-Sha256']);
  assert.doesNotMatch(body, /constructionAuthorized\s*=\s*\$true|signingAuthorized\s*=\s*\$true/);
});

test('package verifier refuses mixed branches and binds both helpers to external V and real S before import', () => {
  const body = between(manifest, 'if ($business31Selected) {', 'Assert-ProductionRuntime31SourceArchive');
  ordered(body, ['$runtime31Selected', 'HashData($configBytes)',
    "foreach ($name in @('Runtime-BackendPrivateReplay31.ps1', 'Business-BackendPrivateReplay31.ps1'))",
    '$businessConfig.controller.files[$entry]', 'Get-ZipEntrySha256', 'Assert-Runtime31HelperGitBinding',
    ". (Join-Path $packageDirectory 'Runtime-BackendPrivateReplay31.ps1')",
    ". (Join-Path $packageDirectory 'Business-BackendPrivateReplay31.ps1')"]);
  assert.match(manifest, /elseif \(\$null -ne \$manifest\.PSObject\.Properties\['businessBackend31'\]\)\s*\{\s*throw/);
});

test('package source/artifact checks precede a separate fresh package replay', () => {
  const body = between(manifest, 'if ($business31Selected) {', '} elseif ($null -ne $manifest.PSObject.Properties');
  ordered(body, ['Assert-ProductionRuntime31SourceArchive', 'Business31 package/policy population differs.',
    'Business31 package bytes changed before replay.', 'Invoke-ProductionBusiness31PrerequisiteReplay -Purpose PackageVerification',
    '-SourceArchivePath $sourceArchivePath -ManifestPath $ManifestPath', "$fresh.replayMode -cne 'fresh-dispatch'"]);
  assert.doesNotMatch(body, /-ResumeRequestPath/);
});

test('historical construction comparison uses stable commitments, never old nonce as fresh authority', () => {
  const body = between(manifest, '$record = (Read-Business31Json', '  $descriptor = (Get-ZipEntryText');
  ordered(body, ['constructionObservationSha256', 'Read-Business31Json $observationPath',
    "$observed.replayMode -cne 'same-parent-reauthentication'", '$manifest.ciAuthority.runId', '$manifest.ciAuthority.runAttempt']);
  const fields = body.match(/foreach \(\$field in @\(([^\r\n]+)\)\)/);
  assert.ok(fields);
  assert.deepEqual([...fields[1].matchAll(/'([^']+)'/g)].map(m => m[1]),
    ['verifier', 'source', 'candidate', 'descriptorPointer', 'closurePointer', 'commitments', 'client', 'limits']);
  assert.match(body, /Assert-Business31Same \$observed\[\$field\] \$fresh\.\$field/);
});

test('package AppCheck uses fresh package proof and archived source choices', () => {
  const body = between(manifest, '$business31Proof = [pscustomobject]@{ok=$true', 'if ([int]$authority.schemaVersion');
  assert.match(body, /prerequisiteResult=\$fresh/);
  ordered(body, ['Get-ProductionAppCheckBuildEvidence -Policy $policy', '-Runtime31Proof $runtime31Proof -Business31Proof $business31Proof',
    'Assert-ProductionAppCheckManifest -Manifest $manifest']);
});

test('AppCheck distinguishes authenticated policy and operational prerequisite results without grants', () => {
  const body = between(appcheck, 'function Get-ProductionAppCheckBusiness31Measurement', 'function Get-ProductionAppCheckRepositoryEvidence');
  assert.match(body, /\$hasPolicy -eq \$hasPrerequisite/);
  assert.match(body, /build31-business-policy-result-v1/);
  assert.match(body, /build31-business-prerequisite-measurement-v1/);
  assert.match(body, /\$result\.purpose -ceq 'package-verification' -and \$result\.replayMode -cne 'fresh-dispatch'/);
  assert.match(body, /constructionAuthorized=\$false;[\s\S]*signingAuthorized=\$false; distributionAuthorized=\$false/);
});

test('initializer binds runtime and selected source before exporting verifier paths', () => {
  ordered(initializer, ['HashData($raw)', 'Get-FileHash -LiteralPath $PSCommandPath',
    "foreach ($entry in @('commondir', 'gitdir', 'shallow', 'objects/info/alternates', 'info/grafts'))",
    'Get-FileHash -LiteralPath $runtime[0]', "@('rev-parse', '--verify'", "@('archive', '--format=zip'",
    'Get-FileHash -LiteralPath $destination', '$selection = [ordered]@{', 'if ($ExportGitHubEnvironment)']);
  assert.match(initializer, /ReparsePoint/); assert.match(initializer, /GIT_NO_LAZY_FETCH/);
  assert.match(initializer, /\$start\.Environment\.Clear\(\)/);
});

test('all four PowerShell caller sources parse without executing their bodies', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-caller-parse-'));
  const script = path.join(temporary, 'parse.ps1');
  fs.writeFileSync(script, `param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Files)
$ErrorActionPreference='Stop'
if($Files.Count -ne 4){throw 'Expected the exact four caller paths'}
foreach($file in $Files){$tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw ($errors|ForEach-Object Message|Out-String)}
}
Write-Output 'PARSED_ONLY'
`);
  const pwsh = process.env.BUSINESS31_TEST_PWSH || 'pwsh';
  const env = {PATH: process.env.PATH, HOME: temporary, USERPROFILE: temporary, TEMP: temporary, TMP: temporary};
  for (const key of ['SystemRoot', 'WINDIR']) if (process.env[key]) env[key] = process.env[key];
  const files = ['New-ProductionArtifact.ps1', 'Test-ProductionReleaseManifest.ps1',
    'Production-AppCheckPolicy.ps1', 'Initialize-Business31Controller.ps1'].map(name => path.join(__dirname, name));
  const run = spawnSync(pwsh, ['-NoProfile', '-File', script, ...files], {env, encoding: 'utf8',
    windowsHide: true, timeout: 15000, maxBuffer: 1024 * 1024});
  assert.equal(run.error, undefined); assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stdout.trim(), 'PARSED_ONLY');
});

test('v2 construction and package record retain distinct core-verifier comparison',()=>{
 assert.match(builder,/build31-business-construction-record-v2/);
 assert.match(manifest,/\$record\.schemaVersion -cne \$recordVersion/);
 assert.match(manifest,/\$observed\.schemaVersion -cne \$recordVersion/);
 assert.match(manifest,/Assert-Business31Same \$observed\.coreVerifier \$fresh\.coreVerifier/);
 assert.match(manifest,/legacy construction observation contains a versioned verifier/);
});

// Everything that can fail on the network before the build runs before the
// irreversible reservation, with bounded retries; what runs after it is either
// retried or re-proven first. Source contracts plus isolated PowerShell runs.
function stepIn(source, name) {
  const text = source.replaceAll('\r\n', '\n');
  const offset = text.indexOf('      - name: ' + name + '\n');
  assert.ok(offset >= 0, name);
  assert.equal(text.indexOf('      - name: ' + name + '\n', offset + 1), -1, 'step is singular: ' + name);
  const end = text.indexOf('\n      - name:', offset + 1);
  return text.slice(offset, end < 0 ? undefined : end);
}
function pwshScript(prefix, body) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  const script = path.join(temporary, 'check.ps1');
  fs.writeFileSync(script, body(temporary));
  const env = {PATH: process.env.PATH, HOME: temporary, USERPROFILE: temporary, TEMP: temporary, TMP: temporary};
  for (const key of ['SystemRoot', 'WINDIR']) if (process.env[key]) env[key] = process.env[key];
  const run = spawnSync(process.env.BUSINESS31_TEST_PWSH || 'pwsh', ['-NoProfile', '-File', script],
    {env, encoding: 'utf8', windowsHide: true, timeout: 60000, maxBuffer: 1024 * 1024});
  assert.equal(run.error, undefined); assert.equal(run.status, 0, run.stderr);
  return run.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
}
const quote = value => "'" + String(value).replaceAll("'", "''") + "'";
test('every build download precedes the replay and the irreversible reservation, retried and digest-bound', () => {
  ordered(workflow, ['- name: Prove Android dependency configuration before reservation',
    '- name: Download and verify approved bundletool', '- name: Provision and prove approved Linux Isar core',
    '- name: Prefetch approved Firestore emulator before reservation',
    '- name: Fresh business replay before signing secrets and reservation',
    '- name: Reauthenticate construction replay and prove clean checkout before reservation',
    '- name: Prove production environment secrets before reservation', '- name: Atomically consume the build number',
    '- name: Restore approved production keystore', '- name: Build once and independently verify']);
  for (const name of ['Download and verify approved bundletool', 'Provision and prove approved Linux Isar core',
    'Prefetch approved Firestore emulator before reservation'])
    assert.doesNotMatch(stepIn(workflow, name), /secrets\.|CRM_ANDROID_RELEASE_/, name);
  ordered(stepIn(workflow, 'Download and verify approved bundletool'), ['for ($attempt = 1; $attempt -le 4; $attempt++)',
    'Invoke-WebRequest -Uri $policy.toolchain.bundletoolUrl -OutFile $jar -TimeoutSec 300',
    'Get-FileHash -LiteralPath $jar -Algorithm SHA256', 'if ($actual -eq $expected) { break }', 'if ($attempt -eq 4) { throw }',
    'if ($actual -ne $expected)', 'throw "bundletool hash mismatch: $actual"', 'CRM_BUNDLETOOL_PATH=$jar', 'CRM_BUNDLETOOL_SHA256=$actual']);
  ordered(stepIn(workflow, 'Provision and prove approved Linux Isar core'), ['for attempt in 1 2 3 4; do',
    'timeout 300 dart run .dart_tool/ci/prepare_isar.dart', 'if [ "$attempt" -eq 4 ]; then', 'exit 1',
    'rm -f .dart_tool/ci/libisar.so', 'done', 'if [ "$actual" = "$CRM_EXPECTED_ISAR_CORE_SHA256" ]; then',
    'test "$actual_sha" = "$CRM_EXPECTED_ISAR_CORE_SHA256"', 'sudo install -m 0755 "$selected" /usr/lib/libisar.so',
    'Isar native-core load probe: PASS', 'CRM_ISAR_CORE_PATH=/usr/lib/libisar.so']);
  const cli = 'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js';
  ordered(stepIn(workflow, 'Prefetch approved Firestore emulator before reservation'), ['firebase_cli="$PWD/' + cli + '"',
    'test -f "$firebase_cli"', 'cd "$RUNNER_TEMP"', 'for attempt in 1 2 3 4; do',
    'timeout 600 node "$firebase_cli" setup:emulators:firestore', 'if [ "$attempt" -eq 4 ]; then', 'exit 1']);
  // The prefetch fills the cache of the very CLI the post-reservation gates start.
  const scripts = JSON.parse(read('package.json')).scripts;
  for (const name of ['emulator:test:governed', 'emulator:test:closure'])
    assert.ok(scripts[name].startsWith('node ' + cli + ' emulators:exec --only firestore '), name);
  assert.match(read('release_gate.ps1'), /npm run emulator:test:governed/);
  assert.match(builder, /npm run emulator:test:closure/);
  // Nothing after the reservation downloads a tool.
  const after = workflow.slice(workflow.indexOf('- name: Atomically consume the build number'));
  assert.doesNotMatch(after, /Invoke-WebRequest|prepare_isar|setup:emulators/);
});
test('the builder construction reauthentication and clean-checkout refusal run once before the reservation', () => {
  const body = stepIn(workflow, 'Reauthenticate construction replay and prove clean checkout before reservation');
  ordered(body, ['Set-StrictMode -Version Latest', "$ErrorActionPreference = 'Stop'", 'Production-AppCheckPolicy.ps1',
    'if (Test-ProductionAppCheckBusiness31Selected $policy)', 'BUSINESS31_CONSTRUCTION_REQUEST',
    "node --no-global-search-paths (Join-Path $PWD 'tools/release/clientBackendCompatibility31.js')",
    "-cne 'same-parent-reauthentication'", '$env:GITHUB_RUN_ID', '$env:GITHUB_RUN_ATTEMPT',
    'Test-ProductionReleasePolicy.ps1', '-RequireArtifactConstructionAuthority', 'if ($LASTEXITCODE -ne 0)',
    'git status --porcelain=v1 --untracked-files=all', '$unclean.Count -gt 0']);
  assert.match(body, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  assert.doesNotMatch(body, /secrets\.|CRM_ANDROID_RELEASE_|Invoke-ProductionBusiness31PrerequisiteReplay|-ResumeRequestPath|-RequestOutputPath|-AuthorityPath/);
  // The acceptance condition is the builder's own, token for token.
  const business = between(builder, 'if (Test-ProductionAppCheckBusiness31Selected $policy)', '$appCheckEvidence = $null');
  const condition = text => {
    const start = text.indexOf('.ok -isnot [bool]');
    assert.ok(start > 0);
    return text.slice(start, text.indexOf(') {', start)).replaceAll('$business31Proof', '$proof').replace(/\s+/g, ' ');
  };
  assert.equal(condition(body), condition(business));
  ordered(business, ['clientBackendCompatibility31.js', "$repo (Join-Path $repo 'release/production-release-policy.json')"]);
  // The same policy proof the builder runs right after the reservation.
  ordered(builder, ['-File tools/release/Test-ProductionReleasePolicy.ps1', '-PolicyPath $PolicyPath', '-RepositoryRoot $repo',
    '-RequireArtifactConstructionAuthority', "throw 'Production policy verification failed.'"]);
  assert.match(builder, /@\(git status --porcelain=v1 --untracked-files=all\)\.Count -gt 0\) \{\s*throw 'Repository must be clean\.'/);
});
test('hosted credential reads repeat only transport faults; the controller dispatch is never repeated', () => {
  const replay = read('tools/release/business31HostedReplay.cjs'), entry = read('tools/release/business31Prerequisite.cjs');
  for (const call of ['p.retry31(() => p.request31(u.href', "p.retry31(() => p.request31(p.ISSUER + '/.well-known/jwks'",
    "p.retry31(() => p.request31('https://sts.googleapis.com/v1/token'"]) assert.ok(replay.includes(call), call);
  assert.equal((replay.match(/p\.request31\(/g) || []).length, 3);
  assert.equal((entry.match(/p\.request31\(/g) || []).length, 1);
  ordered(entry, ["p.request31('https://api.github.com/repos/' + trust.repository.name + '/actions/workflows/'", "method: 'POST'"]);
  assert.doesNotMatch(entry, /retry31/);
});
test('hosted replay fetches its pinned Git with bounded retries and accepts only the pinned digest', () => {
  const digest = '4A92850B6E917DA4FD010669B614B55DCCF5B0EC333A534CC4BE4700DFEFDAFD';
  const body = stepIn(read('.github/workflows/business-private-replay.yml'), 'Install pinned Git runtime');
  ordered(body, ['for ($attempt = 1; $attempt -le 4; $attempt++)', 'Invoke-WebRequest', '-TimeoutSec 300',
    "-ceq '" + digest + "') { break }", 'if ($attempt -eq 4) { throw }', "-cne '" + digest + "'",
    "throw 'Pinned MinGit archive differs'", 'Expand-Archive']);
});
test('builder reads remote refs with bounded retries and never answers absent for a failed read', () => {
  const builderPath = path.join(__dirname, 'New-ProductionArtifact.ps1');
  const rows = pwshScript('b31-remote-ref-', () => `Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(${quote(builderPath)}, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'builder does not parse' }
$found = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Get-RemoteRefCommit' }, $true))
if ($found.Count -ne 1) { throw 'expected exactly one Get-RemoteRefCommit' }
. ([scriptblock]::Create($found[0].Extent.Text))
$script:calls = 0; $script:failures = 0; $script:lines = @(); $script:slept = 0
function Start-Sleep { param([int]$Seconds) $script:slept += $Seconds }
function git { $script:calls++; if ($script:calls -le $script:failures) { $global:LASTEXITCODE = 128; return }; $global:LASTEXITCODE = 0; $script:lines }
function Test-Case([string]$name, [int]$failures, [string[]]$lines, [string]$ref) {
  $script:calls = 0; $script:failures = $failures; $script:lines = $lines; $script:slept = 0
  try { $value = Get-RemoteRefCommit -RefName $ref; $outcome = if ($null -eq $value) { 'absent' } else { $value } }
  catch { $outcome = 'refused: ' + $_.Exception.Message }
  [ordered]@{name=$name; outcome=$outcome; calls=$script:calls; slept=$script:slept} | ConvertTo-Json -Compress
}
$main = ('a' * 40) + [char]9 + 'refs/heads/main'
$tag = ('b' * 40) + [char]9 + 'refs/tags/t'
$peeled = ('c' * 40) + [char]9 + 'refs/tags/t^{}'
Test-Case 'clean read' 0 @($main) 'refs/heads/main'
Test-Case 'two transport failures' 2 @($main) 'refs/heads/main'
Test-Case 'persistent failure' 99 @($main) 'refs/heads/main'
Test-Case 'genuinely absent' 0 @() 'refs/tags/t'
Test-Case 'failed read of an absent tag' 99 @() 'refs/tags/t'
Test-Case 'annotated tag peels' 1 @($tag, $peeled) 'refs/tags/t'
`);
  assert.deepEqual(rows, [
    {name: 'clean read', outcome: 'a'.repeat(40), calls: 1, slept: 0},
    {name: 'two transport failures', outcome: 'a'.repeat(40), calls: 3, slept: 15},
    {name: 'persistent failure', outcome: 'refused: Remote ref read failed: refs/heads/main', calls: 4, slept: 30},
    {name: 'genuinely absent', outcome: 'absent', calls: 1, slept: 0},
    {name: 'failed read of an absent tag', outcome: 'refused: Remote ref read failed: refs/tags/t', calls: 4, slept: 30},
    {name: 'annotated tag peels', outcome: 'c'.repeat(40), calls: 2, slept: 5}]);
});
test('a failed controller reports only its fixed reason vocabulary in the bridge refusal', () => {
  const bridge = path.join(__dirname, 'Business-BackendPrivateReplay31.ps1');
  const prefix = 'Fresh exact-source business prerequisite did not complete; no action is authorized. ';
  const cases = [prefix + '{"reason":"BUSINESS_HOSTED_HTTP_STATUS","httpStatus":404}\n',
    prefix + '{"reason":"UNCLASSIFIED","httpStatus":null}\n',
    'Error: ENOENT, open /home/runner/private/path\n',
    prefix + '{"reason":"business_hosted_lowercase","httpStatus":404}\n',
    prefix + '{"reason":"BUSINESS_HOSTED_HTTP_STATUS","httpStatus":4040}\n', ''];
  const rows = pwshScript('b31-bridge-reason-', temporary => {
    const files = cases.map((text, i) => { const file = path.join(temporary, 'stderr-' + i + '.txt'); fs.writeFileSync(file, text); return file; });
    return `Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. ${quote(bridge)}
foreach ($file in @(${files.map(quote).join(', ')})) {
  $start = [Diagnostics.ProcessStartInfo]::new(${quote(process.execPath)})
  $start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
  $start.Environment.Clear(); if ($env:SystemRoot) { $start.Environment['SystemRoot'] = $env:SystemRoot }
  foreach ($argument in @('-e', "process.stderr.write(require('node:fs').readFileSync(process.argv[1]));process.exitCode=1", $file)) { $start.ArgumentList.Add($argument) }
  $directory = Join-Path ${quote(temporary)} ([Guid]::NewGuid().ToString('N')); [void][IO.Directory]::CreateDirectory($directory)
  try { Invoke-Business31OwnedController $start $directory 30; $message = 'NOT_REFUSED' } catch { $message = $_.Exception.Message }
  [ordered]@{message=$message; retained=(Test-Path -LiteralPath (Join-Path $directory 'controller-stderr.bin'))} | ConvertTo-Json -Compress
}
`;
  });
  const base = 'Business31 protected controller failed; retained stderr is diagnostic only.';
  assert.deepEqual(rows.map(row => row.message), [base + ' Reason: BUSINESS_HOSTED_HTTP_STATUS; HTTP status: 404.',
    base + ' Reason: UNCLASSIFIED; HTTP status: null.', base, base, base, base]);
  assert.ok(rows.every(row => row.retained === true));
});

test('versioned verifier-map hashes use ordinal key ordering across Node and PowerShell',()=>{
 const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'b31-map-order-'));
 const sample={'tools/release/a.cjs':{sha256:'B'.repeat(64),oid:'b'.repeat(40),mode:'100644'},
  'tools/release/Z.cjs':{oid:'a'.repeat(40),mode:'100644',sha256:'A'.repeat(64)}};
 const canonical=v=>v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
 const input=path.join(temporary,'map.json'),script=path.join(temporary,'check.ps1');fs.writeFileSync(input,JSON.stringify(sample));
 const q=v=>"'"+v.replaceAll("'","''")+"'";
 fs.writeFileSync(script,"$ErrorActionPreference='Stop'\n. "+q(path.join(root,'tools/release/Business-BackendPrivateReplay31.ps1'))+"\n$m=Get-Content -LiteralPath "+q(input)+" -Raw|ConvertFrom-Json -AsHashtable\nConvertTo-Business31CanonicalJson $m -Ordinal\n");
 const run=spawnSync(process.env.BUSINESS31_TEST_PWSH||'pwsh',['-NoProfile','-File',script],{encoding:'utf8',windowsHide:true,timeout:15000});
 assert.equal(run.error,undefined);assert.equal(run.status,0,run.stderr);assert.equal(run.stdout.trim(),canonical(sample));
});
