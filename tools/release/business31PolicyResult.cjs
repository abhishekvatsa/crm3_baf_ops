'use strict';
// An independently pinned, fresh entry. Public callers receive read-only API
// access; no candidate-selected implementation, private input or PASS is read.
if (require.main !== module || process.execArgv.length !== 1 ||
    process.execArgv[0] !== '--no-global-search-paths' ||
    Object.keys(require.cache).some(file => file !== __filename) ||
    ['NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES']
      .some(name => process.env[name])) {
  throw Error('BUSINESS_POLICY_FRESH_ENTRY_REQUIRED');
}
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {TextDecoder} = require('node:util');
const SELF = 'tools/release/business31PolicyResult.cjs';
const CONTROLLER = 'tools/release/business31Controller.cjs';
const PROTOCOL = 'tools/release/business31HostedProtocol.cjs';
const INPUT_PROFILE = 'build31-business-policy-result-input-v1';
const PROFILE = 'build31-business-policy-result-v1';
const FALSE_FLAGS = Object.freeze(['independentlySelectedInputsAuthenticated',
  'executingHostAuthenticated', 'humanIdentityAuthenticated', 'trustedClockAuthenticated',
  'originalProcessExecutionAuthenticated', 'credentialAccessAuthorized',
  'backendDeploymentAuthorized', 'constructionAuthorized', 'signingAuthorized',
  'distributionAuthorized']);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(ok) { if (!ok) throw Error('BUSINESS_POLICY_INPUT_REFUSED'); }
function regular(file) {
  need(typeof file === 'string' && path.isAbsolute(file));
  const absolute = path.resolve(file);
  let cursor = path.parse(absolute).root;
  for (const part of absolute.slice(cursor.length).split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, part);
    need(!fs.lstatSync(cursor).isSymbolicLink());
  }
  need(fs.lstatSync(absolute).isFile());
  return absolute;
}
function read(file, limit) {
  const absolute = regular(file), before = fs.statSync(absolute, {bigint: true});
  need(before.size > 0n && before.size <= BigInt(limit));
  const bytes = fs.readFileSync(absolute), after = fs.statSync(absolute, {bigint: true});
  need(bytes.length > 0 && bytes.length <= limit && before.dev === after.dev &&
    before.ino === after.ino && before.size === after.size &&
    before.mtimeNs === after.mtimeNs && before.ctimeNs === after.ctimeNs &&
    BigInt(bytes.length) === after.size);
  return bytes;
}
function bootstrap(file, expectedSha256) {
  // The entry itself is pinned by its caller. Bind the first local imports using
  // only built-ins, before executing the shared configuration validator.
  need(typeof expectedSha256 === 'string' && /^[A-F0-9]{64}$/.test(expectedSha256));
  const raw = read(file, 2 * 1024 * 1024);
  need(sha(raw) === expectedSha256);
  const config = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(raw));
  const files = config?.controller?.files;
  need(files && typeof files === 'object' && !Array.isArray(files));
  for (const name of [SELF, CONTROLLER, PROTOCOL]) {
    need(Object.hasOwn(files, name) && /^[A-F0-9]{64}$/.test(files[name]));
    need(sha(read(path.resolve(__dirname, path.basename(name)), 2 * 1024 * 1024)) === files[name]);
  }
  return raw;
}
async function main() {
  need(process.argv.length === 8 && process.argv[2] === '--controller-config' &&
    process.argv[4] === '--controller-config-sha256' && process.argv[6] === '--input');
  const configFile = process.argv[3], configSha256 = process.argv[5], inputFile = process.argv[7];
  const configBytes = bootstrap(configFile, configSha256);
  const controller = require('./business31Controller.cjs');
  const config = controller.readController31(configFile, configSha256);
  controller.verifyController31(config);
  const p = require('./business31HostedProtocol.cjs');
  const inputBytes = read(inputFile, 128 * 1024), input = p.json(inputBytes, 128 * 1024);
  p.exact(input, ['schemaVersion', 'profile', 'repositoryRoot', 'gitExecutable', 'request'], 'POLICY_INPUT');
  p.need(input.schemaVersion === 1 && input.profile === INPUT_PROFILE, 'POLICY_INPUT_PROFILE');
  const request = p.validateRequest31(input.request);
  p.need(request.schemaVersion === 2 && request.challenge.purpose === 'policy', 'POLICY_PURPOSE');
  p.same(request.candidate, config.selected.candidate, 'POLICY_SELECTED_S');
  p.same(request.descriptorPointer, config.selected.descriptorPointer, 'POLICY_SELECTED_DESCRIPTOR');
  p.same(request.challenge.clientSelectionSha256, config.selected.clientSelectionSha256,
    'POLICY_SELECTED_CLIENT');
  // The explicit locator is data, not proof. Only the completed pinned-V run's
  // actual artifact can authenticate its contents. No discovery or dispatch.
  const retrieved = await p.retrieveResult31(config.replayTrust, request, process.env.GITHUB_TOKEN);
  p.need(retrieved.value.schemaVersion === 2 && retrieved.value.client?.schemaVersion === 2,
    'POLICY_CLIENT_SCHEMA');
  controller.verifyCommittedPolicy31(config, {
    repositoryRoot: input.repositoryRoot, gitExecutable: input.gitExecutable
  }, retrieved.value.client.policy);
  // Git measurement can take time. Re-observe the selected remote head after it
  // and refuse expiry or local configuration/input drift before publishing.
  await p.observe31(config.replayTrust, request, process.env.GITHUB_TOKEN, true);
  p.validateResult31(retrieved.value, config.replayTrust, request);
  controller.verifyController31(config);
  need(read(configFile, 2 * 1024 * 1024).equals(configBytes) &&
    read(inputFile, 128 * 1024).equals(inputBytes));
  const value = retrieved.value;
  process.stdout.write(JSON.stringify({schemaVersion: 1, profile: PROFILE, purpose: 'policy',
    verifier: value.verifier, source: value.source, candidate: value.candidate,
    descriptorPointer: value.descriptorPointer, closurePointer: value.closurePointer,
    commitments: value.commitments, runId: request.runId, runAttempt: request.runAttempt,
    artifactId: retrieved.artifactId, resultSha256: retrieved.resultSha256,
    client: value.client, policyMeasurementVerified: true,
    ...Object.fromEntries(FALSE_FLAGS.map(name => [name, false]))}) + '\n');
}
main().catch(() => {
  process.stderr.write('No authenticated exact-source business policy measurement is available.\n');
  process.exitCode = 1;
});
