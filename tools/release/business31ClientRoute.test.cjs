'use strict';
// Route-selection fixtures only: no Git, hosted service, owner authentication,
// private replay, construction or production operation is performed.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const cp = require('node:child_process');
const path = require('node:path');

const effects = [];
function unexpected(name) {
  return () => { effects.push(name); throw Error('TEST_UNEXPECTED_' + name); };
}
// The adapter captures execFileSync at import. Intercept it before loading so
// an accidental legacy route can never create an actual process in this suite.
const savedExec = cp.execFileSync;
let adapter;
try {
  cp.execFileSync = unexpected('EXEC_FILE');
  adapter = require('./clientBackendCompatibility31.js');
} finally {
  cp.execFileSync = savedExec;
}
assert.deepEqual(effects, [], 'loading the common adapter must not launch a process');
const historical = require('./stagedPromotionSourceAuthority.js');

function policy() {
  return {
    release: {buildNumber: 31}, versionPolicy: {buildNumber: 31},
    clientBackendCompatibility: {
      profile: 'build31-business-client-compatibility-v1', commit: 'a'.repeat(40),
      file: 'release/approvals/build31-business-client-compatibility-approval.json', sha256: 'A'.repeat(64)
    },
    businessBackendPrivateReplay: {
      profile: 'build31-exact-business-backend-v1', commit: 'b'.repeat(40),
      file: 'release/evidence/build31-business-private-replay.json', sha256: 'B'.repeat(64)
    }
  };
}

function invoke(releasePolicy, extra = {}) {
  effects.length = 0;
  const legacy = historical.verifyStagedPromotionSourceAuthority;
  const saved = ['readFileSync', 'lstatSync', 'realpathSync'].map(name => [name, fs[name]]);
  try {
    historical.verifyStagedPromotionSourceAuthority = () => {
      effects.push('HISTORICAL');
      return {ok: true, syntheticHistoricalRoute: true};
    };
    for (const [name] of saved) fs[name] = unexpected('FS_' + name);
    const result = adapter.verifyClientBackendSourceAuthority({
      repoRoot: path.resolve(__dirname, '../..'), releasePolicy, ...extra
    });
    return {result, effects: [...effects]};
  } finally {
    historical.verifyStagedPromotionSourceAuthority = legacy;
    for (const [name, value] of saved) fs[name] = value;
  }
}

test('complete business metadata requires the protected consumer without local side effects or grants', () => {
  const input = policy(), before = structuredClone(input);
  const {result, effects} = invoke(input);
  assert.equal(result.ok, false);
  assert.equal(result.protectedBusinessConsumerRequired, true);
  assert.match(result.reasons[0], /independently selected protected business consumer/);
  assert.deepEqual(effects, []);
  assert.deepEqual(input, before);
  for (const grant of ['authenticated', 'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized']) {
    assert.notEqual(result[grant], true);
  }
});

test('a supplied local PASS, file or callback cannot satisfy the protected-consumer requirement', () => {
  let called = false;
  const {result, effects} = invoke(policy(), {
    proof: {ok: true, hostedRecordedReplayResultAuthenticated: true},
    proofFile: 'synthetic-pass.json', consume: () => { called = true; return {ok: true}; }
  });
  assert.equal(result.ok, false);
  assert.equal(result.protectedBusinessConsumerRequired, true);
  assert.equal(called, false);
  assert.deepEqual(effects, []);
});

const refusals = [
  ['client profile only', p => { delete p.businessBackendPrivateReplay; p.clientBackendCompatibility = {profile: p.clientBackendCompatibility.profile}; }],
  ['client file only', p => { delete p.businessBackendPrivateReplay; p.clientBackendCompatibility = {file: p.clientBackendCompatibility.file}; }],
  ['backend only', p => { delete p.clientBackendCompatibility; }],
  ['present null backend', p => { p.businessBackendPrivateReplay = null; delete p.clientBackendCompatibility; }],
  ['present undefined backend', p => { p.businessBackendPrivateReplay = undefined; delete p.clientBackendCompatibility; }],
  ['wrong backend type', p => { p.businessBackendPrivateReplay = 'PASS'; }],
  ['missing client commit', p => { delete p.clientBackendCompatibility.commit; }],
  ['short backend commit', p => { p.businessBackendPrivateReplay.commit = 'b'.repeat(39); }],
  ['non-hex client digest', p => { p.clientBackendCompatibility.sha256 = 'Z'.repeat(64); }],
  ['wrong backend digest type', p => { p.businessBackendPrivateReplay.sha256 = 1; }],
  ['extra client PASS field', p => { p.clientBackendCompatibility.authenticated = true; }],
  ['extra backend path field', p => { p.businessBackendPrivateReplay.path = 'local-pass.json'; }],
  ['backend array', p => { p.businessBackendPrivateReplay = [p.businessBackendPrivateReplay]; }],
  ['legacy client file mixed with business backend', p => { p.clientBackendCompatibility.file = 'release/approvals/build31-runtime-client-compatibility-approval.json'; }],
  ['legacy client profile mixed with business backend', p => { p.clientBackendCompatibility.profile = 'build31-exact-grpc-runtime-backend-v1'; }],
  ['business client wrong case without backend', p => { delete p.businessBackendPrivateReplay; p.clientBackendCompatibility.profile = 'BUILD31-BUSINESS-CLIENT-COMPATIBILITY-V1'; }],
  ['business client altered path without backend', p => { delete p.businessBackendPrivateReplay; delete p.clientBackendCompatibility.profile; p.clientBackendCompatibility.file += '.bak'; }],
  ['legacy runtime object present', p => { p.runtimeBackendPrivateReplay = {}; }],
  ['legacy runtime null present', p => { p.runtimeBackendPrivateReplay = null; }],
  ['legacy runtime undefined present', p => { p.runtimeBackendPrivateReplay = undefined; }],
  ['business profile misplaced in legacy runtime', p => { p.runtimeBackendPrivateReplay = {profile: p.businessBackendPrivateReplay.profile}; delete p.businessBackendPrivateReplay; delete p.clientBackendCompatibility; }],
  ['business file misplaced in legacy runtime', p => { p.runtimeBackendPrivateReplay = {file: p.businessBackendPrivateReplay.file}; delete p.businessBackendPrivateReplay; delete p.clientBackendCompatibility; }],
  ['missing release build', p => { delete p.release; }],
  ['missing version build', p => { delete p.versionPolicy; }],
  ['mixed numeric generations', p => { p.release.buildNumber = 30; }],
  ['string build number', p => { p.versionPolicy.buildNumber = '31'; }],
  ['both legacy build numbers', p => { p.release.buildNumber = p.versionPolicy.buildNumber = 30; }]
];
for (const [name, mutate] of refusals) test('business selection refuses ' + name + ' before legacy effects', () => {
  const input = policy(); mutate(input);
  const {result, effects} = invoke(input);
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /^Business client route:/);
  assert.notEqual(result.protectedBusinessConsumerRequired, true);
  assert.deepEqual(effects, []);
});

test('absent business metadata preserves historical dispatch', () => {
  const {result, effects} = invoke({release: {buildNumber: 30}, versionPolicy: {buildNumber: 30}});
  assert.deepEqual(result, {ok: true, syntheticHistoricalRoute: true});
  assert.deepEqual(effects, ['HISTORICAL']);
});

test('absent business metadata preserves grpc route selection without executing Git', () => {
  const {result, effects} = invoke({release: {buildNumber: 31}, versionPolicy: {buildNumber: 31},
    clientBackendCompatibility: {profile: 'build31-exact-grpc-runtime-backend-v1'}});
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /TEST_UNEXPECTED_/);
  assert.equal(effects.length, 1);
  assert.notEqual(result.protectedBusinessConsumerRequired, true);
});
