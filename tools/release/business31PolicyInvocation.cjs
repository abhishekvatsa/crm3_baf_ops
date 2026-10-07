'use strict';
// Public policy callers select an installed V and controller configuration
// independently. The fresh V child obtains its own authenticated policy result;
// neither a supplied PASS nor a callback can replace that observation.
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {isDeepStrictEqual, TextDecoder} = require('node:util');
const SELF = 'tools/release/business31PolicyInvocation.cjs';
const POLICY_ENTRY = 'tools/release/business31PolicyResult.cjs';
const PREREQUISITE_ENTRY = 'tools/release/business31Prerequisite.cjs';
const POLICY = 'release/production-release-policy.json';
const DESCRIPTOR = 'release/evidence/build31-business-private-replay.json';
const CLIENT = 'release/approvals/build31-business-client-compatibility-approval.json';
const SELECTORS = Object.freeze(['BUSINESS31_CONTROLLER_CONFIG', 'BUSINESS31_CONTROLLER_CONFIG_SHA256',
  'BUSINESS31_VERIFIER_ROOT', 'BUSINESS31_CONTROLLER_NODE', 'BUSINESS31_CONTROLLER_GIT']);
const ACTION_CONTEXT = Object.freeze(['GITHUB_ACTIONS', 'GITHUB_REPOSITORY', 'GITHUB_REPOSITORY_ID',
  'GITHUB_REPOSITORY_OWNER_ID', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_SHA', 'GITHUB_REF',
  'GITHUB_WORKFLOW_REF', 'GITHUB_WORKFLOW', 'GITHUB_JOB', 'GITHUB_ACTOR_ID', 'GITHUB_ACTOR',
  'GITHUB_TRIGGERING_ACTOR', 'GITHUB_EVENT_NAME']);
const PILOT_FILES = Object.freeze(['runtimePilotAuthority31.cjs', 'stagedPromotionSourceAuthority.js',
  'collectProductionGlobalPullBackend.js', 'collectFunctionFleetRuntimeIdentityReadback.js',
  'collectFunctionsIamDependenciesReadback.js', 'collectFirestoreRulesIndexesReadback.js',
  'deploymentFleetContract.js', 'scopedCallableInvokerIam.js', 'scopedCallableInvokerIamPublic.js',
  'reviewedFirestoreRulesDeployment.js', 'reviewedRulesRuntime.js', 'reviewedRulesRuntimeCollector.js',
  'reviewedRulesReconciliation.js', 'reviewedBackendControls.js', 'reviewedBackendVerifierAuthority.js']
  .map(name => 'tools/release/' + name));
const FALSE_FLAGS = Object.freeze(['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated',
  'humanIdentityAuthenticated', 'trustedClockAuthenticated', 'originalProcessExecutionAuthenticated',
  'credentialAccessAuthorized', 'backendDeploymentAuthorized', 'constructionAuthorized',
  'signingAuthorized', 'distributionAuthorized']);
const digest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(value) { if (!value) throw Error('BUSINESS_POLICY_AUTHORITY_REFUSED'); }
function same(a, b) { need(isDeepStrictEqual(a, b)); }
function exact(value, names) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)));
  same(Object.keys(value).sort(), [...names].sort());
}
function businessRouteSelected31(policy) {
  const signal = value => value != null && ['profile', 'file'].some(name =>
    typeof value[name] === 'string' && /business/i.test(value[name]));
  return policy != null && (Object.hasOwn(policy, 'businessBackendPrivateReplay') ||
    signal(policy.clientBackendCompatibility) || signal(policy.runtimeBackendPrivateReplay));
}
function pointer(value, file) {
  exact(value, ['commit', 'file', 'sha256']);
  need(typeof value.commit === 'string' && /^[a-f0-9]{40}$/.test(value.commit) &&
    value.file === file && digest(value.sha256));
  return value;
}
function policyPointer(value, profile, file) {
  exact(value, ['commit', 'file', 'sha256', 'profile']); need(value.profile === profile);
  const {profile: ignored, ...bare} = value; return pointer(bare, file);
}
function validateBusinessPolicyRoute31(policy) {
  need(businessRouteSelected31(policy) && policy?.release?.buildNumber === 31 &&
    policy?.versionPolicy?.buildNumber === 31 && !Object.hasOwn(policy, 'runtimeBackendPrivateReplay'));
  return {descriptorPointer: policyPointer(policy.businessBackendPrivateReplay,
    'build31-exact-business-backend-v1', DESCRIPTOR), clientPointer: policyPointer(policy.clientBackendCompatibility,
    'build31-business-client-compatibility-v1', CLIENT)};
}
function regular(file, directory = false) {
  need(typeof file === 'string' && path.isAbsolute(file));
  const result = path.resolve(file); let current = path.parse(result).root;
  for (const part of result.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part); need(!fs.lstatSync(current).isSymbolicLink());
  }
  need(directory ? fs.lstatSync(result).isDirectory() : fs.lstatSync(result).isFile()); return result;
}
function read(file, limit = 2 * 1024 * 1024) {
  file = regular(file); const before = fs.statSync(file, {bigint: true});
  need(before.size > 0n && before.size <= BigInt(limit));
  const bytes = fs.readFileSync(file), after = fs.statSync(regular(file), {bigint: true});
  need(['dev', 'ino', 'size', 'mtimeNs', 'ctimeNs'].every(key => before[key] === after[key]) &&
    BigInt(bytes.length) === after.size); return bytes;
}
function json(bytes) { return JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes)); }
function selected() {
  for (const name of SELECTORS) need(typeof process.env[name] === 'string' && process.env[name].length > 0);
  const configFile = regular(process.env.BUSINESS31_CONTROLLER_CONFIG);
  const configSha256 = process.env.BUSINESS31_CONTROLLER_CONFIG_SHA256;
  const configBytes = read(configFile); need(digest(configSha256) && sha(configBytes) === configSha256);
  const config = json(configBytes), root = regular(process.env.BUSINESS31_VERIFIER_ROOT, true);
  const node = regular(process.env.BUSINESS31_CONTROLLER_NODE), git = regular(process.env.BUSINESS31_CONTROLLER_GIT);
  need(config?.schemaVersion === 1 && config.profile === 'build31-business-prerequisite-controller-v1' &&
    digest(config.controller?.nodeSha256) && digest(config.controller?.gitSha256));
  need(sha(read(node, 256 * 1024 * 1024)) === config.controller.nodeSha256 &&
    sha(read(git, 256 * 1024 * 1024)) === config.controller.gitSha256);
  const files = config.controller.files;
  need(files && typeof files === 'object' && !Array.isArray(files) && Object.keys(files).length <= 256);
  same(files, config.replayTrust?.verifier?.files);
  const mandatory = [SELF, POLICY_ENTRY, PREREQUISITE_ENTRY, 'tools/release/business31Controller.cjs',
    'tools/release/business31HostedProtocol.cjs', 'tools/release/business31TrustedInput.cjs',
    'tools/release/business31PrivateDescriptor.cjs', ...PILOT_FILES];
  need(mandatory.every(file => Object.hasOwn(files, file)));
  const seen = new Set();
  for (const [file, value] of Object.entries(files)) {
    need(/^[A-Za-z0-9._+/-]+$/.test(file) && !file.startsWith('/') &&
      file.split('/').every(part => part && part !== '.' && part !== '..') && digest(value) &&
      !seen.has(file.toLowerCase())); seen.add(file.toLowerCase());
    need(sha(read(path.join(root, ...file.split('/')))) === value);
  }
  const construction = Object.hasOwn(process.env, 'BUSINESS31_CONSTRUCTION_REQUEST');
  const requestName = construction ? 'BUSINESS31_CONSTRUCTION_REQUEST' : 'BUSINESS31_POLICY_REQUEST';
  const requestFile = regular(process.env[requestName]), requestBytes = read(requestFile, 128 * 1024);
  return {configFile, configSha256, configBytes, config, root, node, git, construction, requestName, requestFile, requestBytes};
}
function childEnvironment(selection, temporary) {
  const env = {};
  for (const name of ['SystemRoot', 'WINDIR', 'COMSPEC', 'LANG', 'LC_ALL'])
    if (process.env[name] !== undefined) env[name] = process.env[name];
  for (const name of SELECTORS) env[name] = process.env[name];
  env[selection.requestName] = selection.requestFile;
  if (selection.construction) for (const name of ACTION_CONTEXT)
    if (process.env[name] !== undefined) env[name] = process.env[name];
  Object.assign(env, {PATH: path.dirname(selection.git) + path.delimiter + path.dirname(selection.node),
    TEMP: temporary, TMP: temporary, HOME: temporary, USERPROFILE: temporary,
    GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
    GIT_TERMINAL_PROMPT: '0', GIT_NO_LAZY_FETCH: '1', GIT_OPTIONAL_LOCKS: '0'});
  const token = selection.construction ? (process.env.GH_TOKEN || process.env.GITHUB_TOKEN) : process.env.GITHUB_TOKEN;
  if (token) env.GITHUB_TOKEN = token;
  return env;
}
function child(node, file, args, selection, temporary) {
  return execFileSync(node, ['--no-global-search-paths', file, ...args], {cwd: selection.root,
    env: childEnvironment(selection, temporary), timeout: 10 * 60 * 1000, maxBuffer: 2 * 1024 * 1024,
    windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
}
function unchanged(selection) {
  const now = selected(); same(now.configBytes, selection.configBytes); same(now.requestBytes, selection.requestBytes);
  for (const name of ['configFile', 'configSha256', 'root', 'node', 'git', 'construction', 'requestName', 'requestFile']) same(now[name], selection[name]);
}
function verifyBusiness31PolicySourceAuthoritySync({repoRoot, releasePolicy}) {
  try {
    validateBusinessPolicyRoute31(releasePolicy);
    const selection = selected(), root = regular(repoRoot, true);
    same(json(read(path.join(root, POLICY))), releasePolicy);
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-public-'));
    try {
      const bytes = child(selection.node, path.join(selection.root, SELF), ['--repository', root], selection, temporary);
      unchanged(selection);
      const result = json(bytes); need(result?.ok === true && result.route === 'business-backend31');
      same(result.businessBackend31.descriptorPointer, validateBusinessPolicyRoute31(releasePolicy).descriptorPointer);
      return result;
    } finally { fs.rmSync(temporary, {recursive: true, force: true}); }
  } catch {
    return {ok: false, reasons: ['Business client route: independently selected authenticated policy replay and preserved pilot are required.'],
      protectedBusinessConsumerRequired: true, constructionAuthority: false};
  }
}
function execute() {
  need(require.main === module && process.execArgv.length === 1 && process.execArgv[0] === '--no-global-search-paths' &&
    Object.keys(require.cache).every(file => file === __filename) &&
    !['NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES'].some(name => process.env[name]));
  need(process.argv.length === 4 && process.argv[2] === '--repository');
  const selection = selected(), repoRoot = regular(process.argv[3], true);
  need(path.resolve(__filename) === path.join(selection.root, SELF));
  const c = require('./business31Controller.cjs'), p = require('./business31HostedProtocol.cjs');
  const config = c.readController31(selection.configFile, selection.configSha256); c.verifyController31(config);
  const locator = p.json(selection.requestBytes, 128 * 1024);
  if (selection.construction) {
    exact(locator, ['schemaVersion', 'profile', 'controllerConfigSha256', 'request']);
    need(locator.schemaVersion === 1 && locator.profile === 'build31-business-prerequisite-resume-v1' &&
      locator.controllerConfigSha256 === selection.configSha256 && process.env.GITHUB_ACTIONS === 'true');
  }
  const request = c.selectedRequest31(config, p.validateRequest31(selection.construction ? locator.request : locator));
  need(request.schemaVersion === 2 && request.challenge.purpose === (selection.construction ? 'construction' : 'policy'));
  const policy = json(read(path.join(repoRoot, POLICY))), pointers = validateBusinessPolicyRoute31(policy);
  same(pointers.descriptorPointer, config.selected.descriptorPointer);
  const input = selection.construction ? {schemaVersion: 1, purpose: 'construction', repositoryRoot: repoRoot,
    gitExecutable: selection.git, sourceArchivePath: null, manifestPath: null, packagePaths: []} :
    {schemaVersion: 1, profile: 'build31-business-policy-result-input-v1', repositoryRoot: repoRoot,
      gitExecutable: selection.git, request};
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-observe-'));
  try {
    const repo = require('./business31TrustedInput.cjs').openTrustedGitRepository31({repositoryRoot: repoRoot,
      gitExecutable: selection.git, gitSha256: config.controller.gitSha256});
    function head() {
      const value = execFileSync(selection.git, ['--no-replace-objects', '--no-pager', '--no-optional-locks',
        '-C', repoRoot, 'rev-parse', '--verify', 'HEAD^{commit}'], {env: childEnvironment(selection, temporary),
        timeout: 30000, maxBuffer: 4096, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']}).toString('ascii').trim();
      need(value === request.candidate.commit);
    }
    head();
    same(repo.readBlob(request.candidate.commit, POLICY), read(path.join(repoRoot, POLICY)));
    const observed = [];
    function committed(pointer) {
      const original = repo.readBlob(pointer.commit, pointer.file), current = repo.readBlob(request.candidate.commit, pointer.file);
      need(sha(original) === pointer.sha256); same(current, original); same(read(path.join(repoRoot, pointer.file)), original);
      observed.push([pointer.file, original]); return p.json(original);
    }
    const descriptor = require('./business31PrivateDescriptor.cjs').validateBusiness31PrivateDescriptor(committed(pointers.descriptorPointer));
    same(descriptor.source, config.replayTrust.source);
    const approval = committed(descriptor.approvalPointer), currentBackend = committed(descriptor.closurePointer);
    same(currentBackend.source, descriptor.source);
    exact(currentBackend, ['schemaVersion', 'documentType', 'recordKind', 'source', 'recordedAtUtc', 'privateRecord']);
    need(currentBackend.schemaVersion === 1 && currentBackend.documentType === 'build31-business-private-record-custody' &&
      currentBackend.recordKind === 'closure' && approval.schemaVersion === 1 &&
      approval.documentType === 'build31-business-private-record-custody' && approval.recordKind === 'decision');
    same(approval.source, descriptor.source);
    // The historical plane stays independent of business source semantics.
    // Every transitive historical module was pinned before this fresh process loaded it.
    const pilot = require('./runtimePilotAuthority31.cjs').verifyPreservedPilotForRuntime31({repoRoot, releasePolicy: policy});
    same(json(read(path.join(repoRoot, POLICY))), policy); head();
    // Run the actual authenticated consumer after local historical/public Git
    // measurement. Operational mode always reauthenticates the same live parent
    // through the fixed prerequisite entry; it never posts another dispatch.
    const file = path.join(temporary, 'input.json'); fs.writeFileSync(file, JSON.stringify(input), {flag: 'wx'});
    let measurement;
    if (selection.construction) {
      const output = path.join(temporary, 'result.json');
      need(child(selection.node, path.join(selection.root, PREREQUISITE_ENTRY), ['--config', selection.configFile,
        '--config-sha256', selection.configSha256, '--input', file, '--output', output,
        '--resume-request', selection.requestFile], selection, temporary).length === 0);
      measurement = p.json(read(output, 128 * 1024), 128 * 1024);
      need(measurement?.schemaVersion === 1 && measurement.profile === 'build31-business-prerequisite-measurement-v1' &&
        measurement.purpose === 'construction' && measurement.replayMode === 'same-parent-reauthentication' &&
        measurement.freshHostedReplayVerified === true);
      same(measurement.challenge, request.challenge);
      same(measurement.limits, {deploymentAuthorized: false, constructionAuthorized: false,
        signingAuthorized: false, distributionAuthorized: false});
    } else {
      measurement = p.json(child(selection.node, path.join(selection.root, POLICY_ENTRY),
        ['--controller-config', selection.configFile, '--controller-config-sha256', selection.configSha256, '--input', file],
        selection, temporary), 128 * 1024);
      need(measurement?.schemaVersion === 1 && measurement.profile === 'build31-business-policy-result-v1' &&
        measurement.purpose === 'policy' && measurement.policyMeasurementVerified === true &&
        FALSE_FLAGS.every(name => measurement[name] === false));
    }
    same(measurement.candidate, request.candidate); same(measurement.source, descriptor.source);
    same(measurement.verifier, {commit: config.replayTrust.verifier.commit, tree: config.replayTrust.verifier.tree});
    same(measurement.descriptorPointer, pointers.descriptorPointer); same(measurement.closurePointer, descriptor.closurePointer);
    same(measurement.client.decisionPointer, pointers.clientPointer);
    same(measurement.runId, request.runId); same(measurement.runAttempt, request.runAttempt);
    require('./business31HostedClient.cjs').validateBusinessHostedClientMeasurement31({trust: config.replayTrust, request, client: measurement.client});
    same(currentBackend.recordedAtUtc, measurement.client.publicClosureRecordedAtUtc);
    head();
    same(require('./runtimePilotAuthority31.cjs').verifyPreservedPilotForRuntime31({repoRoot, releasePolicy: policy}), pilot);
    head();
    need(sha(read(path.join(repoRoot, POLICY))) === measurement.client.policy.bindings.policy.sha256);
    for (const [name, bytes] of observed) same(read(path.join(repoRoot, name)), bytes);
    need(Date.now() <= Date.parse(request.challenge.expiresAtUtc));
    unchanged(selection); c.verifyController31(config);
    return {...pilot, ok: true, route: 'business-backend31',
      currentBackendReceiptFile: descriptor.closurePointer.file, currentBackendReceiptSha256: descriptor.closurePointer.sha256,
      candidateBackendReceiptFile: descriptor.closurePointer.file, candidateBackendReceiptSha256: descriptor.closurePointer.sha256,
      clientBackendCompatibility: {...pointers.clientPointer, sourceCommit: descriptor.source.commit},
      businessBackend31: {source: descriptor.source, approvalPointer: descriptor.approvalPointer,
        closurePointer: descriptor.closurePointer, descriptorPointer: pointers.descriptorPointer,
        clientPointer: pointers.clientPointer,
        [selection.construction ? 'prerequisiteResult' : 'policyResult']: measurement, currentBackend,
        recordedSemanticsReplayAuthenticated: true, ...Object.fromEntries(FALSE_FLAGS.map(name => [name, false]))}};
  } finally { fs.rmSync(temporary, {recursive: true, force: true}); }
}
module.exports = Object.freeze({businessRouteSelected31, validateBusinessPolicyRoute31, verifyBusiness31PolicySourceAuthoritySync});
if (require.main === module) {
  try { process.stdout.write(JSON.stringify(execute()) + '\n'); }
  catch { process.stderr.write('No exact-source business policy and preserved-pilot proof is available.\n'); process.exitCode = 1; }
}
