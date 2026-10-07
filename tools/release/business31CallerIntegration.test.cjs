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
    "profile = 'build31-business-construction-record-v1'", 'constructionObservationSha256 = Get-Sha256']);
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
