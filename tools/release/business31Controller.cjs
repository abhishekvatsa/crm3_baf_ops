'use strict';
// Public data and independently enrolled controller configuration only. This
// helper grants no signing/deployment permission and imports no candidate code.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const p = require('./business31HostedProtocol.cjs');
const PROFILE = 'build31-business-prerequisite-controller-v1';
const ENTRY = 'tools/release/business31Prerequisite.cjs';
const REQUIRED = Object.freeze(['business31Controller.cjs', 'business31Prerequisite.cjs',
  'business31PolicyResult.cjs', 'business31HostedProtocol.cjs', 'business31HostedClient.cjs',
  'business31ClientPolicy.cjs', 'business31ClientCustody.cjs', 'business31ClientSemantics.cjs',
  'business31TrustedInput.cjs', 'business31PrivateDescriptor.cjs', 'privateEvidenceBundle31.cjs',
  'business31SourceAdmission.cjs'].map(name => 'tools/release/' + name));
const isDigest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
const isId = value => typeof value === 'string' && /^[1-9][0-9]{0,19}$/.test(value);
function readController31(file, expectedSha256) {
  p.need(isDigest(expectedSha256), 'CONTROLLER_CONFIG_COMMITMENT');
  file = p.regular(file);
  p.need(fs.statSync(file).size <= 2 * 1024 * 1024, 'CONTROLLER_CONFIG_BOUND');
  const raw = fs.readFileSync(file);
  p.need(p.sha(raw) === expectedSha256, 'CONTROLLER_CONFIG_COMMITMENT');
  return validateController31(p.json(raw));
}
function validateController31(c) {
  p.exact(c, ['schemaVersion', 'profile', 'replayTrust', 'controller', 'selected', 'requester',
    'maximumWaitSeconds'], 'CONTROLLER_CONFIG');
  p.need(c.schemaVersion === 1 && c.profile === PROFILE, 'CONTROLLER_PROFILE');
  p.validateTrust31(c.replayTrust);
  p.exact(c.controller, ['nodeSha256', 'gitSha256', 'files'], 'CONTROLLER_RUNTIME');
  p.need(isDigest(c.controller.nodeSha256) && isDigest(c.controller.gitSha256), 'CONTROLLER_RUNTIME');
  p.same(c.controller.files, c.replayTrust.verifier.files, 'CONTROLLER_VERIFIER_POPULATION');
  p.need(REQUIRED.every(file => Object.hasOwn(c.controller.files, file)), 'CONTROLLER_REQUIRED_PRODUCERS');
  p.exact(c.selected, ['candidate', 'descriptorPointer', 'clientSelectionSha256'], 'CONTROLLER_SELECTION');
  p.validateRequest31({schemaVersion: 1, candidate: c.selected.candidate,
    descriptorPointer: c.selected.descriptorPointer, runId: '1', runAttempt: '1'});
  p.need(isDigest(c.selected.clientSelectionSha256), 'CONTROLLER_CLIENT_SELECTION');
  p.exact(c.requester, ['workflowId', 'path', 'jobName', 'actorIds'], 'CONTROLLER_REQUESTER');
  p.need(isId(c.requester.workflowId) && c.requester.path === '.github/workflows/production-artifact.yml' &&
    typeof c.requester.jobName === 'string' && /^[A-Za-z0-9 ()_-]{1,100}$/.test(c.requester.jobName) &&
    Array.isArray(c.requester.actorIds) && c.requester.actorIds.length > 0 && c.requester.actorIds.length <= 8 &&
    c.requester.actorIds.every(isId) && new Set(c.requester.actorIds).size === c.requester.actorIds.length,
  'CONTROLLER_REQUESTER');
  p.need(Number.isInteger(c.maximumWaitSeconds) && c.maximumWaitSeconds >= 60 &&
    c.maximumWaitSeconds <= 9000, 'CONTROLLER_WAIT_BOUND');
  return c;
}
function verifyController31(c, root = path.resolve(__dirname, '../..')) {
  validateController31(c);
  // The portable consumer may run on Windows. Its approved Node/Git binaries
  // have their own independent commitments; V's Linux replay runtime is intact.
  p.need(p.sha(fs.readFileSync(p.regular(process.execPath))) === c.controller.nodeSha256,
    'CONTROLLER_NODE');
  root = p.regular(root, true);
  for (const [file, digest] of Object.entries(c.controller.files))
    p.need(p.sha(fs.readFileSync(p.regular(path.join(root, ...file.split('/'))))) === digest,
      'CONTROLLER_PRODUCER');
  return true;
}
function selectedRequest31(c, r) {
  p.validateRequest31(r);
  p.need(r.schemaVersion === 2, 'CONTROLLER_REQUEST_VERSION');
  p.same(r.candidate, c.selected.candidate, 'CONTROLLER_CANDIDATE');
  p.same(r.descriptorPointer, c.selected.descriptorPointer, 'CONTROLLER_DESCRIPTOR');
  p.need(r.challenge.clientSelectionSha256 === c.selected.clientSelectionSha256, 'CONTROLLER_CLIENT_SELECTION');
  return r;
}
function openRepository31(c, input) {
  verifyController31(c);
  return require('./business31TrustedInput.cjs').openTrustedGitRepository31({
    repositoryRoot: input.repositoryRoot, gitExecutable: input.gitExecutable,
    gitSha256: c.controller.gitSha256});
}
function verifyLocalSelection31(c, input) {
  const repo = openRepository31(c, input), S = c.selected.candidate, M = c.replayTrust.source;
  p.same(repo.snapshot(S.commit).tree, S.tree, 'CONTROLLER_LOCAL_S');
  p.same(repo.snapshot(M.commit).tree, M.tree, 'CONTROLLER_LOCAL_M');
  repo.requireAncestor(M.commit, S.commit);
  const descriptor = c.selected.descriptorPointer;
  p.need(p.sha(repo.readBlob(descriptor.commit, descriptor.file)) === descriptor.sha256 &&
    p.sha(repo.readBlob(S.commit, descriptor.file)) === descriptor.sha256, 'CONTROLLER_DESCRIPTOR_BYTES');
  const policyBytes = repo.readBlob(S.commit, 'release/production-release-policy.json');
  return {policySha256: p.sha(policyBytes), policy: p.json(policyBytes)};
}
function verifyCommittedPolicy31(c, input, measured) {
  const repo = openRepository31(c, input), S = c.selected.candidate, M = c.replayTrust.source;
  p.same(repo.snapshot(S.commit).tree, S.tree, 'CONTROLLER_LOCAL_S');
  p.same(repo.snapshot(M.commit).tree, M.tree, 'CONTROLLER_LOCAL_M');
  repo.requireAncestor(M.commit, S.commit);
  p.need(measured?.schemaVersion === 1 && measured.profile === 'build31-business-client-policy-v1' &&
    measured.policySourceVerified === true && measured.appCheckSourcePolicyVerified === true,
  'CONTROLLER_POLICY_MEASUREMENT');
  p.same(measured.source, M, 'CONTROLLER_POLICY_SOURCE');
  p.same(measured.candidate, S, 'CONTROLLER_POLICY_CANDIDATE');
  p.same(measured.descriptorPointer, c.selected.descriptorPointer, 'CONTROLLER_POLICY_DESCRIPTOR');
  const paths = {policy: ['release/production-release-policy.json', S.commit],
    versionApproval: ['release/approvals/version-policy-approval.json', S.commit],
    successorApproval: ['release/approvals/build-number-31-successor-approval.json', S.commit],
    currentSuccessor: ['release/current-successor-state.json', S.commit],
    appCheckApproval: ['release/approvals/build31-app-check-client-approval.json', S.commit],
    pubspec: ['pubspec.yaml', S.commit], backendPolicy: ['release/production-release-policy.json', M.commit],
    rulesReadback: ['release/evidence/build30-current-source-firestore-rules-indexes-live-readback.json', M.commit],
    identitySource: ['functions/src/stage2dSecurityConfig.ts', M.commit]};
  p.exact(measured.bindings, Object.keys(paths), 'CONTROLLER_POLICY_BINDINGS');
  let policy;
  for (const [name, [file, commit]] of Object.entries(paths)) {
    const pointer = measured.bindings[name];
    p.exact(pointer, ['commit', 'file', 'sha256'], 'CONTROLLER_POLICY_BINDING');
    p.need(pointer.commit === commit && pointer.file === file && isDigest(pointer.sha256), 'CONTROLLER_POLICY_BINDING');
    const bytes = repo.readBlob(commit, file);
    p.need(p.sha(bytes) === pointer.sha256, 'CONTROLLER_POLICY_BYTES');
    if (name === 'policy') policy = p.json(bytes);
  }
  const d = c.selected.descriptorPointer;
  p.need(p.sha(repo.readBlob(d.commit, d.file)) === d.sha256 &&
    p.sha(repo.readBlob(S.commit, d.file)) === d.sha256, 'CONTROLLER_DESCRIPTOR_BYTES');
  verifyController31(c);
  return policy;
}
function hashFile31(file, role) {
  file = p.regular(file);
  const before = fs.statSync(file, {bigint: true});
  p.need(before.size > 0n && before.size <= 4n * 1024n ** 3n, 'CONTROLLER_FILE_BOUND');
  const fd = fs.openSync(file, 'r'), hash = crypto.createHash('sha256'), buffer = Buffer.alloc(1024 * 1024);
  let count = 0;
  try {
    for (;;) {
      const size = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (!size) break;
      count += size; p.need(BigInt(count) <= before.size, 'CONTROLLER_FILE_CHANGED');
      hash.update(buffer.subarray(0, size));
    }
  } finally { fs.closeSync(fd); }
  const after = fs.statSync(p.regular(file), {bigint: true});
  p.need(['size', 'ino', 'mtimeNs', 'ctimeNs'].every(key => before[key] === after[key]) &&
    BigInt(count) === before.size, 'CONTROLLER_FILE_CHANGED');
  return {role, name: path.basename(file), sha256: hash.digest('hex').toUpperCase(), bytes: count};
}
function measureFiles31(input) {
  p.exact(input, ['schemaVersion', 'purpose', 'repositoryRoot', 'gitExecutable',
    'sourceArchivePath', 'manifestPath', 'packagePaths'], 'CONTROLLER_INPUT');
  p.need(input.schemaVersion === 1 && ['construction', 'policy', 'package-verification'].includes(input.purpose),
    'CONTROLLER_INPUT_PURPOSE');
  p.regular(input.repositoryRoot, true); p.regular(input.gitExecutable);
  p.need(Array.isArray(input.packagePaths) && input.packagePaths.length <= 8, 'CONTROLLER_PACKAGES');
  if (input.purpose !== 'package-verification') {
    p.need(input.sourceArchivePath === null && input.manifestPath === null && input.packagePaths.length === 0,
      'CONTROLLER_UNEXPECTED_PACKAGE');
    return [];
  }
  p.need(input.packagePaths.length > 0, 'CONTROLLER_PACKAGE_ABSENT');
  const parent = path.dirname(p.regular(input.manifestPath));
  const files = [[input.sourceArchivePath, 'source-archive'], [input.manifestPath, 'manifest'],
    ...input.packagePaths.map(file => [file, 'package'])];
  p.need(new Set(files.map(([file]) => path.resolve(file).toLowerCase())).size === files.length,
    'CONTROLLER_DUPLICATE_PACKAGE');
  return files.map(([file, role]) => {
    p.need(path.dirname(p.regular(file)) === parent, 'CONTROLLER_PACKAGE_LOCATION');
    return hashFile31(file, role);
  });
}
module.exports = Object.freeze({PROFILE, ENTRY, REQUIRED, readController31, validateController31,
  verifyController31, selectedRequest31, verifyLocalSelection31, verifyCommittedPolicy31, hashFile31, measureFiles31});
