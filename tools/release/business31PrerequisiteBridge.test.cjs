'use strict';
// Synthetic process-contract tests only. The selected controller below is an
// inert fixture, not a GitHub authenticator or a source of release permission.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const helper = path.join(__dirname, 'Business-BackendPrivateReplay31.ps1');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const H = 'A'.repeat(64), M = 'a'.repeat(40), V = 'b'.repeat(40), S = 'c'.repeat(40);
const source = {commit: M, tree: 'd'.repeat(40), functionsTree: 'e'.repeat(40)};
const candidate = {commit: S, tree: 'f'.repeat(40), ref: 'refs/heads/main', kind: 'main', pullRequest: null};
const pointer = (file, commit = '1'.repeat(40)) => ({commit, file, sha256: H});
const descriptor = pointer('release/evidence/build31-business-private-replay.json');
const closure = pointer('release/evidence/build31-business-backend-deployment-closure.json');
const decision = pointer('release/approvals/build31-business-client-compatibility-approval.json', '2'.repeat(40));
const parent = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-bridge-retained-'));
const quote = text => "'" + text.replaceAll("'", "''") + "'";
function write(file, value) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, typeof value === 'string' ? value : JSON.stringify(value));
}
function fixture(mode = 'valid') {
  const root = fs.mkdtempSync(path.join(parent, 'case-'));
  const repo = path.join(root, 'source'), verifier = path.join(root, 'verifier');
  fs.mkdirSync(repo); fs.mkdirSync(verifier);
  const policy = {
    release: {buildNumber: 31}, versionPolicy: {buildNumber: 31},
    clientBackendCompatibility: {profile: 'build31-business-client-compatibility-v1', ...decision},
    businessBackendPrivateReplay: {profile: 'build31-exact-business-backend-v1', ...descriptor},
    finalization: {exactFunctionFleetDeploymentReceiptFile: closure.file,
      exactFunctionFleetDeploymentReceiptSha256: closure.sha256}
  };
  const marker = path.join(root, 'inert-child.json');
  const entry = path.join(verifier, 'tools/release/business31Prerequisite.cjs');
  const program = `'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const argv=process.argv.slice(2),options={};
assert.deepEqual(argv.filter((_,i)=>i%2===0),['--config','--config-sha256','--input','--output',...(argv.length===10?['--resume-request']:[])]);
for(let i=0;i<argv.length;i+=2)options[argv[i]]=argv[i+1];
assert.ok(process.execArgv.includes('--no-global-search-paths'));
for(const name of ['NODE_OPTIONS','NODE_PATH','GH_TOKEN','GOOGLE_APPLICATION_CREDENTIALS','FIREBASE_TOKEN','BRIDGE_UNRELATED_SECRET'])assert.equal(process.env[name],undefined);
assert.equal(process.env.GITHUB_TOKEN,'synthetic-inert-no-network');
assert.equal(process.env.GITHUB_ACTIONS,'true');
assert.equal(process.env.GITHUB_REPOSITORY,'fixture/repository');
assert.equal(process.env.GITHUB_SHA,'${S}');
assert.equal(process.env.GITHUB_REF,'refs/heads/main');
assert.equal(process.env.GITHUB_WORKFLOW_REF,'fixture/repository/.github/workflows/production-artifact.yml@refs/heads/main');
assert.notEqual(process.env.HOME,${JSON.stringify(root)});
const input=JSON.parse(fs.readFileSync(options['--input'],'utf8'));
assert.deepEqual(Object.keys(input).sort(),['schemaVersion','purpose','repositoryRoot','gitExecutable','sourceArchivePath','manifestPath','packagePaths'].sort());
assert.equal(input.repositoryRoot,${JSON.stringify(repo)});
fs.writeFileSync(${JSON.stringify(marker)},JSON.stringify({input,argv,environmentKeys:Object.keys(process.env).sort()}),{flag:'wx'});
const mode=${JSON.stringify(mode)};
if(mode==='nonzero'){process.stderr.write('synthetic refusal');process.exit(23);}
if(mode==='overflow'){process.stdout.write(Buffer.alloc(1100000,65));process.exit(0);}
if(mode==='missing-output')process.exit(0);
const config=JSON.parse(fs.readFileSync(options['--config'],'utf8'));
const falseClient=Object.fromEntries(['independentlySelectedInputsAuthenticated','executingHostAuthenticated','humanIdentityAuthenticated','trustedClockAuthenticated','platformIdentityAuthenticated','credentialAccessAuthorized','backendDeploymentAuthorized','constructionAuthorized','signingAuthorized','distributionAuthorized'].map(k=>[k,false]));
const result={schemaVersion:1,profile:'build31-business-prerequisite-measurement-v1',purpose:input.purpose,
verifier:{commit:config.replayTrust.verifier.commit,tree:config.replayTrust.verifier.tree},source:config.replayTrust.source,candidate:config.selected.candidate,
descriptorPointer:config.selected.descriptorPointer,closurePointer:${JSON.stringify(closure)},
commitments:{bundleSha256:'${H}',membersSha256:'${H}',relocationSha256:'${H}',sourceManifestSha256:'${H}'},
client:{schemaVersion:2,profile:'build31-business-client-compatibility-v1',decisionPointer:${JSON.stringify(decision)},appCheckSourcePolicyVerified:true,...falseClient},
challenge:{schemaVersion:1,nonce:'0'.repeat(64),purpose:input.purpose,requestedAtUtc:new Date().toISOString(),expiresAtUtc:new Date(Date.now()+60000).toISOString(),
requester:{kind:'github-actions',runId:process.env.GITHUB_RUN_ID,runAttempt:process.env.GITHUB_RUN_ATTEMPT,invocationId:'1'.repeat(64)},clientSelectionSha256:config.selected.clientSelectionSha256,
fileBindings:input.purpose==='package-verification'?[...['source-archive','manifest'].map((role,i)=>({role,file:[input.sourceArchivePath,input.manifestPath][i]})),...input.packagePaths.map(file=>({role:'package',file}))].map(({role,file})=>({role,name:require('node:path').basename(file),sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex').toUpperCase(),bytes:fs.statSync(file).size})):[]},
runId:'1',runAttempt:'1',artifactId:'2',resultSha256:'${H}',freshHostedReplayVerified:true,
replayMode:options['--resume-request']?'same-parent-reauthentication':'fresh-dispatch',
limits:{deploymentAuthorized:false,constructionAuthorized:false,signingAuthorized:false,distributionAuthorized:false}};
if(options['--resume-request']){
 const previous=JSON.parse(fs.readFileSync(options['--resume-request'],'utf8')).request;
 result.challenge=previous.challenge;result.runId=previous.runId;result.runAttempt=previous.runAttempt;
}
if(mode==='wrong-purpose')result.purpose='policy';
if(mode==='wrong-source')result.source={...result.source,commit:'9'.repeat(40)};
if(mode==='wrong-candidate')result.candidate={...result.candidate,commit:'9'.repeat(40)};
if(mode==='wrong-descriptor')result.descriptorPointer={...result.descriptorPointer,sha256:'B'.repeat(64)};
if(mode==='wrong-client')result.client.decisionPointer={...result.client.decisionPointer,commit:'9'.repeat(40)};
if(mode==='wrong-closure')result.closurePointer={...result.closurePointer,sha256:'B'.repeat(64)};
if(mode==='unmeasured-policy')result.client.appCheckSourcePolicyVerified=false;
if(mode==='grant')result.limits.constructionAuthorized=true;
if(mode==='client-grant')result.client.signingAuthorized=true;
if(mode==='string-grant')result.limits.signingAuthorized='False';
if(mode==='old-challenge')result.challenge.requestedAtUtc='2026-01-01T00:00:00.000Z';
if(mode==='wrong-challenge-selection')result.challenge.clientSelectionSha256='B'.repeat(64);
if(mode==='wrong-requester')result.challenge.requester.runId='99';
if(mode==='wrong-files')result.challenge.fileBindings=[];
if(mode==='wrong-replay-mode')result.replayMode='same-parent-reauthentication';
if(mode==='extra')result.callback='not allowed';
if(mode==='changed-input')fs.appendFileSync(options['--input'],' ');
if(mode==='changed-helper')fs.appendFileSync(__filename,String.fromCharCode(10));
fs.writeFileSync(options['--output'],JSON.stringify(result),{flag:'wx'});
`;
  write(entry, program);
  const files = {'tools/release/business31Prerequisite.cjs': sha(fs.readFileSync(entry))};
  const nodeHash = sha(fs.readFileSync(process.execPath));
  const config = {
    schemaVersion: 1, profile: 'build31-business-prerequisite-controller-v1',
    replayTrust: {verifier: {commit: V, tree: '3'.repeat(40), files}, source,
      gitSha256: nodeHash, sourceManifestSha256: H},
    controller: {nodeSha256: nodeHash, gitSha256: nodeHash, files},
    selected: {candidate, descriptorPointer: descriptor, clientSelectionSha256: H},
    requester: {workflowId: '1', path: '.github/workflows/production-artifact.yml', jobName: 'Synthetic', actorIds: ['1']},
    maximumWaitSeconds: 9000
  };
  const configFile = path.join(root, 'selected.json'), policyFile = path.join(repo, 'release/production-release-policy.json');
  write(configFile, config); write(policyFile, policy);
  const env = {PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, WINDIR: process.env.WINDIR,
    HOME: root, USERPROFILE: root, TEMP: root, TMP: root,
    GH_TOKEN: 'synthetic-inert-no-network', BRIDGE_UNRELATED_SECRET: 'must-not-cross',
    GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: 'fixture/repository', GITHUB_SHA: S,
    GITHUB_REF: 'refs/heads/main', GITHUB_WORKFLOW_REF: 'fixture/repository/.github/workflows/production-artifact.yml@refs/heads/main',
    GITHUB_RUN_ID: '10', GITHUB_RUN_ATTEMPT: '2',
    GOOGLE_APPLICATION_CREDENTIALS: path.join(root, 'must-not-read'), FIREBASE_TOKEN: 'must-not-cross',
    BUSINESS31_CONTROLLER_CONFIG: configFile, BUSINESS31_CONTROLLER_CONFIG_SHA256: sha(fs.readFileSync(configFile)),
    BUSINESS31_VERIFIER_ROOT: verifier, BUSINESS31_CONTROLLER_NODE: process.execPath, BUSINESS31_CONTROLLER_GIT: process.execPath};
  for (const key of Object.keys(env)) if (env[key] === undefined) delete env[key];
  function refresh() {
    write(configFile, config); write(policyFile, policy);
    env.BUSINESS31_CONTROLLER_CONFIG_SHA256 = sha(fs.readFileSync(configFile));
  }
  function run(extra = '', suffix = '', purpose = 'Construction') {
    const script = path.join(root, 'run.ps1');
    write(script, `Set-StrictMode -Version Latest\n$ErrorActionPreference='Stop'\n. ${quote(helper)}\n$policy=Get-Content -LiteralPath ${quote(policyFile)} -Raw|ConvertFrom-Json -Depth 50\n${suffix}\nInvoke-ProductionBusiness31PrerequisiteReplay -Purpose ${purpose} -RepositoryRoot ${quote(repo)} -Policy $policy ${extra}|ConvertTo-Json -Depth 50 -Compress\n`);
    return cp.spawnSync(process.env.BUSINESS31_TEST_PWSH || 'pwsh', ['-NoProfile', '-File', script],
      {env, encoding: 'utf8', windowsHide: true, timeout: 20000, maxBuffer: 2 * 1024 * 1024});
  }
  return {root, repo, verifier, config, configFile, policy, policyFile, marker, entry, env, refresh, run};
}
test('bridge exposes only fixed caller arguments and finite launcher environment', () => {
  const text = fs.readFileSync(helper, 'utf8');
  assert.match(text, /ValidateSet\('Construction', 'PackageVerification'\)/);
  assert.doesNotMatch(text, /\[scriptblock\]|\$Proof\b|\$Callback\b|Invoke-Expression/);
  assert.match(text, /\.Environment\.Clear\(\)/);
  assert.match(text, /'--no-global-search-paths'/);
  assert.match(text, /Get-Business31FileHash \$file/);
});
test('actual PowerShell bridge joins only its selected inert child output and preserves false grants', () => {
  const f = fixture(); const r = f.run();
  assert.equal(r.status, 0, r.stderr); const value = JSON.parse(r.stdout);
  assert.equal(value.freshHostedReplayVerified, true);
  assert.equal(value.limits.constructionAuthorized, false);
  assert.equal(value.replayMode, 'fresh-dispatch');
  const called = JSON.parse(fs.readFileSync(f.marker, 'utf8'));
  assert.equal(called.input.purpose, 'construction'); assert.deepEqual(called.input.packagePaths, []);
});

test('construction locator stores only selected original request and resumed child reauthenticates it', () => {
  const f = fixture(), locator = path.join(f.root, 'original-request.json');
  const first = f.run('-RequestOutputPath ' + quote(locator));
  assert.equal(first.status, 0, first.stderr);
  const original = JSON.parse(first.stdout), saved = JSON.parse(fs.readFileSync(locator, 'utf8'));
  assert.deepEqual(Object.keys(saved).sort(), ['schemaVersion', 'profile', 'controllerConfigSha256', 'request'].sort());
  assert.equal(saved.controllerConfigSha256, f.env.BUSINESS31_CONTROLLER_CONFIG_SHA256);
  assert.equal(saved.request.schemaVersion, 2);
  assert.deepEqual(saved.request.challenge, original.challenge);
  assert.equal(Object.hasOwn(saved, 'result'), false);
  // A second real inert child, not a returned local saved measurement.
  fs.renameSync(f.marker, f.marker + '.first');
  const second = f.run('-ResumeRequestPath ' + quote(locator));
  assert.equal(second.status, 0, second.stderr);
  const resumed = JSON.parse(second.stdout);
  assert.equal(resumed.replayMode, 'same-parent-reauthentication');
  assert.deepEqual(resumed.challenge, original.challenge);
  assert.equal(resumed.limits.constructionAuthorized, false);
  const called = JSON.parse(fs.readFileSync(f.marker, 'utf8'));
  assert.deepEqual(called.argv.slice(-2), ['--resume-request', locator]);
});

test('construction refuses existing locator output before child and preserves original bytes', () => {
  const f = fixture(), locator = path.join(f.root, 'original.json'); write(locator, 'original');
  const r = f.run('-RequestOutputPath ' + quote(locator));
  assert.notEqual(r.status, 0); assert.equal(fs.readFileSync(locator, 'utf8'), 'original');
  assert.equal(fs.existsSync(f.marker), false);
});

test('resume refuses a different externally selected configuration before child', () => {
  const f = fixture(), locator = path.join(f.root, 'original.json');
  write(locator, {schemaVersion: 1, profile: 'build31-business-prerequisite-resume-v1', controllerConfigSha256: 'F'.repeat(64), request: {}});
  const r = f.run('-ResumeRequestPath ' + quote(locator));
  assert.notEqual(r.status, 0); assert.equal(fs.existsSync(f.marker), false);
});

test('package verification cannot request a construction locator', () => {
  const f = fixture(), locator = path.join(f.root, 'original.json');
  const r = f.run('-RequestOutputPath ' + quote(locator), '', 'PackageVerification');
  assert.notEqual(r.status, 0); assert.equal(fs.existsSync(f.marker), false);
  assert.equal(fs.existsSync(locator), false);
});
test('portable controller keeps its own pinned Git distinct from the remote replay runtime', () => {
  const f = fixture(); f.config.replayTrust.gitSha256 = 'B'.repeat(64);
  f.config.maximumWaitSeconds = 60; f.refresh();
  const r = f.run(); assert.equal(r.status, 0, r.stderr);
});
for (const [name, change] of [
  ['missing selector', f => {delete f.env.BUSINESS31_CONTROLLER_CONFIG;}],
  ['relative selector', f => {f.env.BUSINESS31_CONTROLLER_CONFIG = 'selected.json';}],
  ['wrong config hash', f => {f.env.BUSINESS31_CONTROLLER_CONFIG_SHA256 = 'B'.repeat(64);}],
  ['wrong Node bytes', f => {f.config.controller.nodeSha256 = 'B'.repeat(64); f.refresh();}],
  ['unselected entry', f => {f.config.controller.files = {}; f.config.replayTrust.verifier.files = {}; f.refresh();}],
  ['changed selected entry', f => {fs.appendFileSync(f.entry, '\n');}],
  ['different controller/replay files', f => {f.config.replayTrust.verifier.files = {}; f.refresh();}],
  ['mixed legacy pointer', f => {f.policy.runtimeBackendPrivateReplay = null; f.refresh();}],
  ['partial business pointer', f => {delete f.policy.clientBackendCompatibility; f.refresh();}],
  ['wrong build', f => {f.policy.versionPolicy.buildNumber = 30; f.refresh();}],
  ['policy-selected external config ignored', f => {f.policy.businessControllerConfig = f.configFile; delete f.env.BUSINESS31_CONTROLLER_CONFIG; f.refresh();}],
  ['missing dispatch credential', f => {delete f.env.GH_TOKEN;}]
]) test('prelaunch refusal: ' + name, () => {
  const f = fixture(); change(f); const r = f.run();
  assert.notEqual(r.status, 0, r.stdout); assert.equal(fs.existsSync(f.marker), false, 'no child may start');
});
test('an unrelated legacy policy does not require selectors or launch a child', () => {
  const f = fixture(); delete f.policy.businessBackendPrivateReplay;
  f.policy.clientBackendCompatibility = {file: 'release/old-client.json'}; f.refresh();
  delete f.env.BUSINESS31_CONTROLLER_CONFIG;
  const r = f.run(); assert.equal(r.status, 0, r.stderr); assert.equal(fs.existsSync(f.marker), false);
});
for (const mode of ['nonzero', 'overflow', 'missing-output', 'wrong-purpose', 'wrong-source',
  'wrong-candidate', 'wrong-descriptor', 'wrong-client', 'wrong-closure', 'unmeasured-policy',
  'grant', 'client-grant', 'string-grant', 'old-challenge', 'wrong-challenge-selection', 'wrong-requester', 'wrong-replay-mode',
  'extra', 'changed-input', 'changed-helper']) {
  test('original child result refusal: ' + mode, () => {
    const f = fixture(mode); const r = f.run();
    assert.notEqual(r.status, 0, r.stdout); assert.equal(fs.existsSync(f.marker), true, r.stderr);
  });
}
test('construction refuses future package inputs before launching', () => {
  const f = fixture(); const r = f.run('-SourceArchivePath ' + quote(path.join(f.root, 'future.zip')));
  assert.notEqual(r.status, 0, r.stdout); assert.equal(fs.existsSync(f.marker), false);
});
function packageFiles(f) {
  const archive = path.join(f.root, 'source.zip'), manifest = path.join(f.root, 'manifest.json');
  write(archive, 'inert source archive bytes');
  write(path.join(f.root, 'app.apk'), 'inert APK bytes'); write(path.join(f.root, 'app.aab'), 'inert AAB bytes');
  write(manifest, {source: {gitCommit: S, gitTree: candidate.tree}, artifacts: [{file: 'app.apk'}, {file: 'app.aab'}]});
  return {archive, manifest, args: '-SourceArchivePath ' + quote(archive) + ' -ManifestPath ' + quote(manifest)};
}
test('package purpose binds exact original source, manifest and artifact bytes', () => {
  const f = fixture(); const files = packageFiles(f);
  const r = f.run(files.args, '', 'PackageVerification'); assert.equal(r.status, 0, r.stderr);
  const result = JSON.parse(r.stdout); assert.equal(result.challenge.fileBindings.length, 4);
  assert.equal(result.limits.distributionAuthorized, false);
});
test('package purpose rejects swapped challenged file list after actual inert child', () => {
  const f = fixture('wrong-files'); const files = packageFiles(f);
  const r = f.run(files.args, '', 'PackageVerification'); assert.notEqual(r.status, 0, r.stdout);
  assert.equal(fs.existsSync(f.marker), true, r.stderr);
});
test('package rejects escaping manifest artifact before child', () => {
  const f = fixture(); const files = packageFiles(f);
  const record = JSON.parse(fs.readFileSync(files.manifest)); record.artifacts[0].file = '../outside.apk'; write(files.manifest, record);
  const r = f.run(files.args, '', 'PackageVerification'); assert.notEqual(r.status, 0, r.stdout);
  assert.equal(fs.existsSync(f.marker), false);
});
test('redirected verifier root is refused before inert child launch', () => {
  const f = fixture(), link = path.join(f.root, 'redirected-verifier');
  fs.symlinkSync(f.verifier, link, process.platform === 'win32' ? 'junction' : 'dir');
  f.env.BUSINESS31_VERIFIER_ROOT = link;
  const r = f.run(); assert.notEqual(r.status, 0, r.stdout);
  assert.match(r.stderr, /redirected paths/); assert.equal(fs.existsSync(f.marker), false);
});
test('bounded process timeout stops only its actual inert child and retains diagnostic streams', () => {
  const f = fixture(), child = path.join(f.root, 'wait.cjs'), pidFile = path.join(f.root, 'owned.pid');
  write(child, `require('node:fs').writeFileSync(${JSON.stringify(pidFile)},String(process.pid));setInterval(()=>{},1000);`);
  const script = path.join(f.root, 'timeout.ps1');
  write(script, `Set-StrictMode -Version Latest\n$ErrorActionPreference='Stop'\n. ${quote(helper)}
$start=[Diagnostics.ProcessStartInfo]::new(${quote(process.execPath)})
$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$start.Environment.Clear();$start.Environment['SystemRoot']=$env:SystemRoot
$start.ArgumentList.Add(${quote(child)})
try { Invoke-Business31OwnedController $start ${quote(f.root)} 3;throw 'TIMEOUT WAS NOT REFUSED' }
catch { if($_.Exception.Message -notmatch 'controller timed out'){throw} }
$ownedPid=[int][IO.File]::ReadAllText(${quote(pidFile)})
if(Get-Process -Id $ownedPid -ErrorAction SilentlyContinue){throw 'OWNED CHILD STILL RUNNING'}
'TIMED_OUT_AND_CLEANED'
`);
  const r = cp.spawnSync(process.env.BUSINESS31_TEST_PWSH || 'pwsh', ['-NoProfile', '-File', script],
    {env: f.env, encoding: 'utf8', windowsHide: true, timeout: 20000, maxBuffer: 1024 * 1024});
  assert.equal(r.status, 0, r.stderr); assert.match(r.stdout, /TIMED_OUT_AND_CLEANED/);
  assert.equal(fs.existsSync(path.join(f.root, 'controller-stdout.bin')), true);
  assert.equal(fs.existsSync(path.join(f.root, 'controller-stderr.bin')), true);
});
