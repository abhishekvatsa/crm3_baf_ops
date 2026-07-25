import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  CANONICAL_AUTHORITY_ROLES,
  GATE1B_DECISIONS,
  assertHmacKey,
  assertNewEvidenceOutput,
  assertProductionReadCustody,
  buildAuthorityInventory,
  classifyUserAuthority,
  deriveWorkflowRoleUniverse,
  listAllAuthUsers,
  parseArgs,
  pseudonymizeSubject,
  validateContractDocument,
  validateUserDocument,
} from './firestore_integrity_sweep.mjs';

const ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../..',
);
const HMAC_KEY = 'gate-1b-test-key-with-at-least-32-bytes';
const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const ts = {
  toDate: () => new Date('2026-07-22T00:00:00Z'),
  toMillis: () => 1784678400000,
};

function canonicalUser(overrides = {}) {
  return {
    name: 'User',
    email: 'user@example.com',
    roles: ['admin'],
    isApproved: true,
    createdAt: ts,
    photoUrl: null,
    fcmToken: null,
    ...overrides,
  };
}

function build({
  firestoreUsers = [{uid: 'u1', data: canonicalUser()}],
  authUsers = [{uid: 'u1', disabled: false}],
  authCoverageComplete = true,
} = {}) {
  return buildAuthorityInventory({
    firestoreUsers,
    authUsers,
    authCoverageComplete,
    hmacKey: HMAC_KEY,
  });
}

test('canonical approved and Model B unapproved authority are distinct', () => {
  assert.deepEqual(
    classifyUserAuthority(canonicalUser()).classifications,
    ['CANONICAL_APPROVED'],
  );
  assert.deepEqual(
    classifyUserAuthority(canonicalUser({
      isApproved: false,
      roles: ['admin'],
    })).classifications,
    ['CANONICAL_UNAPPROVED_WITH_INTENDED_ROLES'],
  );
});

test('Gate 1B authority defect classes are literal and complete', () => {
  const cases = [
    [{isApproved: true}, 'MISSING_AUTHORITY_FIELDS'],
    [{isApproved: 'true', roles: ['admin']}, 'INVALID_IS_APPROVED_TYPE'],
    [{isApproved: true, roles: 'admin'}, 'ROLES_NOT_LIST'],
    [{isApproved: true, roles: []}, 'EMPTY_APPROVED_ROLES'],
    [{isApproved: false, roles: []}, 'EMPTY_UNAPPROVED_ROLES'],
    [
      {isApproved: true, roles: Array(11).fill('admin')},
      'TOO_MANY_ROLES',
    ],
    [{isApproved: true, roles: ['admin', 7]}, 'NON_STRING_ROLE'],
    [{isApproved: true, roles: ['admin', 'bogus']}, 'UNKNOWN_ROLE'],
  ];
  for (const [value, expected] of cases) {
    assert.ok(
      classifyUserAuthority(value).classifications.includes(expected),
      `Missing ${expected}`,
    );
  }
});

test('duplicate canonical roles are a non-blocking data-quality warning', () => {
  const result = build({
    firestoreUsers: [{
      uid: 'u1',
      data: canonicalUser({roles: ['admin', 'admin']}),
    }],
  });
  assert.equal(result.decision, GATE1B_DECISIONS.pass);
  assert.equal(result.classificationCounts.CANONICAL_APPROVED, 1);
  assert.equal(
    result.classificationCounts.DUPLICATE_CANONICAL_ROLE_WARNING,
    1,
  );
  assert.equal(result.summary.dataQualityWarningCount, 1);
  assert.equal(result.summary.blockingSubjectCount, 0);
});

test('profile-only corruption is separated from authority integrity', () => {
  const result = build({
    firestoreUsers: [{
      uid: 'u1',
      data: canonicalUser({name: '', approved: true}),
    }],
  });
  assert.equal(result.decision, GATE1B_DECISIONS.pass);
  assert.equal(result.classificationCounts.PROFILE_ONLY_CORRUPTION, 1);
  assert.equal(result.summary.authorityDefectSubjectCount, 0);
  assert.equal(result.summary.profileOnlyCorruptionCount, 1);
  assert.ok(
    result.subjects[0].profile.findings.some(
      (item) => item.reason === 'unexpected-top-level-field',
    ),
  );
});

test('Auth population, disabled approval, and custom claims fail closed', () => {
  const result = build({
    firestoreUsers: [
      {uid: 'missing-auth', data: canonicalUser()},
      {uid: 'disabled', data: canonicalUser()},
    ],
    authUsers: [
      {
        uid: 'disabled',
        disabled: true,
        customClaims: {admin: true},
      },
      {uid: 'missing-firestore', disabled: false},
    ],
  });
  assert.equal(result.decision, GATE1B_DECISIONS.authorityHold);
  assert.equal(result.classificationCounts.AUTH_USER_MISSING, 1);
  assert.equal(result.classificationCounts.FIRESTORE_USER_MISSING, 1);
  assert.equal(
    result.classificationCounts.AUTH_USER_DISABLED_WHILE_APPROVED,
    1,
  );
  assert.equal(result.classificationCounts.UNEXPECTED_CUSTOM_CLAIMS, 1);
  assert.deepEqual(
    result.affectedRuleCategories.sort(),
    [
      'AUTHORITY_ADMIN_QUORUM',
      'AUTH_FIRESTORE_POPULATION',
      'CUSTOM_CLAIMS_ABSENCE_ASSERTION',
    ],
  );
});

test('a subject with several defects is counted once as blocking', () => {
  const result = build({
    firestoreUsers: [{
      uid: 'one-subject',
      data: canonicalUser({roles: ['unknown']}),
    }],
    authUsers: [],
  });
  assert.equal(result.summary.authorityDefectSubjectCount, 1);
  assert.equal(result.summary.reconciliationDefectSubjectCount, 1);
  assert.equal(result.summary.blockingSubjectCount, 1);
  assert.equal(result.summary.populationBlockerCount, 1);
  assert.equal(result.summary.blockingFindingCount, 2);
});

test('an admin-less or empty complete population cannot pass Gate 1B', () => {
  const adminLess = build({
    firestoreUsers: [{
      uid: 'operations-user',
      data: canonicalUser({roles: ['operations']}),
    }],
    authUsers: [{uid: 'operations-user', disabled: false}],
  });
  assert.equal(adminLess.decision, GATE1B_DECISIONS.authorityHold);
  assert.equal(adminLess.classificationCounts.NO_ENABLED_APPROVED_ADMIN, 1);
  assert.equal(adminLess.summary.canonicalApprovedAdminCount, 0);
  assert.equal(adminLess.summary.enabledApprovedAdminCount, 0);

  const empty = build({firestoreUsers: [], authUsers: []});
  assert.equal(empty.decision, GATE1B_DECISIONS.authorityHold);
  assert.equal(empty.classificationCounts.NO_ENABLED_APPROVED_ADMIN, 1);
});

test('skipped Auth coverage produces the explicit incomplete-coverage hold', () => {
  const result = build({
    authUsers: [],
    authCoverageComplete: false,
  });
  assert.equal(result.decision, GATE1B_DECISIONS.coverageHold);
  assert.equal(result.coverage.firebaseAuthUsers, 'NOT_RUN');
  assert.equal(result.subjects[0].presence.firebaseAuth, null);
  assert.deepEqual(
    result.subjects[0].authReconciliation.classifications,
    [],
  );
});

test('HMAC pseudonyms are stable, namespaced, and omit raw identity data', () => {
  const first = pseudonymizeSubject(HMAC_KEY, 'user', 'alice-uid');
  const second = pseudonymizeSubject(HMAC_KEY, 'user', 'alice-uid');
  const otherNamespace = pseudonymizeSubject(
    HMAC_KEY,
    'firestore:users',
    'alice-uid',
  );
  assert.equal(first, second);
  assert.notEqual(first, otherNamespace);
  assert.match(first, /^hmac256:[0-9a-f]{64}$/);

  const result = build({
    firestoreUsers: [{
      uid: 'alice-uid',
      data: canonicalUser({
        name: 'Alice Sensitive',
        email: 'alice-sensitive@example.com',
      }),
    }],
    authUsers: [{
      uid: 'alice-uid',
      customClaims: {privateClaim: 'private-value'},
    }],
  });
  const encoded = JSON.stringify(result);
  assert.equal(encoded.includes('alice-uid'), false);
  assert.equal(encoded.includes('Alice Sensitive'), false);
  assert.equal(encoded.includes('alice-sensitive@example.com'), false);
  assert.equal(encoded.includes('privateClaim'), false);
  assert.equal(encoded.includes('private-value'), false);
  assert.equal(encoded.includes(HMAC_KEY), false);
});

test('HMAC custody rejects absent or short keys', () => {
  assert.throws(
    () => assertHmacKey(undefined),
    new RegExp(GATE1B_DECISIONS.custodyHold),
  );
  assert.throws(
    () => assertHmacKey('too-short'),
    new RegExp(GATE1B_DECISIONS.custodyHold),
  );
});

test('evidence output preflight refuses overwrite before cloud access', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-gate1b-'));
  const output = path.join(directory, 'inventory.json');
  try {
    assert.deepEqual(assertNewEvidenceOutput(output), {
      resolved: path.resolve(output),
      digestPath: `${path.resolve(output)}.sha256`,
    });
    fs.writeFileSync(output, 'existing evidence', 'utf8');
    assert.throws(
      () => assertNewEvidenceOutput(output),
      /evidence output already exists/,
    );
    assert.throws(
      () => assertNewEvidenceOutput(
        path.join(directory, 'missing', 'inventory.json'),
      ),
      /evidence output directory must already exist/,
    );
  } finally {
    if (fs.existsSync(output)) fs.unlinkSync(output);
    fs.rmdirSync(directory);
  }
});

test('Firebase Auth inventory consumes every page and detects token loops', async () => {
  const calls = [];
  const auth = {
    async listUsers(limit, token) {
      calls.push([limit, token]);
      return token == null
        ? {users: [{uid: 'u1'}], pageToken: 'next'}
        : {users: [{uid: 'u2'}]};
    },
  };
  assert.deepEqual(
    (await listAllAuthUsers(auth)).map((user) => user.uid),
    ['u1', 'u2'],
  );
  assert.deepEqual(calls, [[1000, undefined], [1000, 'next']]);

  const loopingAuth = {
    async listUsers() {
      return {users: [], pageToken: 'same'};
    },
  };
  await assert.rejects(
    () => listAllAuthUsers(loopingAuth),
    /repeated a page token/,
  );
});

test('production reads require exact source, project, coverage, and custody', () => {
  const source = {
    commit: 'a'.repeat(40),
    tree: 'b'.repeat(40),
    branch: 'main',
    originMainCommit: 'a'.repeat(40),
    cleanWorktree: true,
  };
  const args = {
    project: PRODUCTION_PROJECT,
    allowProduction: true,
    confirmProject: PRODUCTION_PROJECT,
    expectedSourceCommit: source.commit,
    expectedSourceTree: source.tree,
    skipAuth: false,
  };
  assert.doesNotThrow(
    () => assertProductionReadCustody(args, {}, source),
  );
  assert.throws(
    () => assertProductionReadCustody(
      {...args, skipAuth: true},
      {},
      source,
    ),
    new RegExp(GATE1B_DECISIONS.custodyHold),
  );
  assert.throws(
    () => assertProductionReadCustody(
      args,
      {FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080'},
      source,
    ),
    /emulator hosts must be absent/,
  );
  assert.throws(
    () => assertProductionReadCustody(
      {...args, expectedSourceTree: 'c'.repeat(40)},
      {},
      source,
    ),
    /expected source tree mismatch/,
  );
  assert.throws(
    () => assertProductionReadCustody(
      args,
      {},
      {...source, branch: 'feature/gate1b'},
    ),
    /checked-out source branch must be main/,
  );
  assert.throws(
    () => assertProductionReadCustody(
      args,
      {},
      {...source, originMainCommit: 'd'.repeat(40)},
    ),
    /HEAD must equal the fetched origin\/main commit/,
  );
});

test('CLI rejects mutation-like and unknown arguments', () => {
  assert.throws(() => parseArgs(['--repair']), /Unknown argument/);
  assert.throws(() => parseArgs(['--project']), /requires a value/);
  assert.deepEqual(
    parseArgs([
      '--project',
      'demo-project',
      '--output',
      'report.json',
      '--skip-auth',
    ]),
    {
      project: 'demo-project',
      output: 'report.json',
      hmacKeyEnv: 'CRM3_GATE1B_HMAC_KEY',
      includeOperationalContracts: false,
      skipAuth: true,
    },
  );
});

test('role catalogue is identical across policy, Rules, Functions, and Dart', () => {
  const policy = JSON.parse(fs.readFileSync(
    path.join(ROOT, 'governance/maintenance_workflow_policy_v1.json'),
    'utf8',
  ));
  const expected = deriveWorkflowRoleUniverse(policy).sort();
  const rules = fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8');
  const ruleBlock = rules.match(
    /function validUserRoleList\(roles\) \{([\s\S]*?)\n    \}/,
  );
  assert.ok(ruleBlock);
  const ruleRoles = [...ruleBlock[1].matchAll(/'([^']+)'/g)]
    .map((match) => match[1])
    .sort();

  const functionsPolicy = fs.readFileSync(
    path.join(
      ROOT,
      'functions/src/maintenanceWorkflow/policy.generated.ts',
    ),
    'utf8',
  );
  const functionsMatch = functionsPolicy.match(
    /WORKFLOW_ROLE_UNIVERSE = (\[[^\n]+\]) as const/,
  );
  assert.ok(functionsMatch);
  const functionRoles = JSON.parse(functionsMatch[1]).sort();

  const dartPolicy = fs.readFileSync(
    path.join(
      ROOT,
      'lib/features/maintenance_workflow/domain/' +
        'workflow_policy_generated.dart',
    ),
    'utf8',
  );
  const dartMatch = dartPolicy.match(
    /workflowRoleUniverse = <String>\{([^}]+)\};/,
  );
  assert.ok(dartMatch);
  const dartRoles = [...dartMatch[1].matchAll(/'([^']+)'/g)]
    .map((match) => match[1])
    .sort();

  assert.deepEqual(CANONICAL_AUTHORITY_ROLES, expected);
  assert.deepEqual(ruleRoles, expected);
  assert.deepEqual(functionRoles, expected);
  assert.deepEqual(dartRoles, expected);
  assert.match(
    ruleBlock[1],
    new RegExp(`roles\\.size\\(\\) <= ${expected.length}`),
  );
});

test('classifier source contains no Firebase or Firestore mutation API', () => {
  const source = fs.readFileSync(
    path.join(ROOT, 'tools/v4/firestore_integrity_sweep.mjs'),
    'utf8',
  );
  const forbidden = [
    /\bwriteBatch\s*\(/,
    /\bbulkWriter\s*\(/,
    /\brunTransaction\s*\(/,
    /\bsetCustomUserClaims\s*\(/,
    /\bupdateUser\s*\(/,
    /\bdeleteUser\s*\(/,
    /\bcreateUser\s*\(/,
    /\bimportUsers\s*\(/,
    /\brevokeRefreshTokens\s*\(/,
  ];
  for (const pattern of forbidden) {
    assert.doesNotMatch(source, pattern);
  }
  const mutationNamedCalls = [
    ...source.matchAll(
      /\b([A-Za-z_$][\w$]*)\.(set|update|delete|create|add)\s*\(/g,
    ),
  ].map((match) => `${match[1]}.${match[2]}`);
  assert.deepEqual(
    [...new Set(mutationNamedCalls)].sort(),
    [
      'blockingSubjects.add',
      'counts.set',
      'result.set',
      'roles.add',
      'seen.add',
      'seenPageTokens.add',
    ],
  );
  assert.match(source, /db\.collection\('users'\)\.get\(\)/);
  assert.match(source, /auth\.listUsers\(1000, pageToken\)/);
});

test('canonical user document passes', () => {
  assert.deepEqual(validateUserDocument('subject-1', canonicalUser()), []);
});

test('legacy and malformed user fields are reported', () => {
  const findings = validateUserDocument('subject-2', {
    name: '',
    email: 'u@example.com',
    roles: ['admin', 'bogus'],
    isApproved: true,
    approved: true,
    createdAt: '2026-07-22T00:00:00Z',
  });
  assert.ok(findings.some(
    (item) => item.reason === 'unexpected-top-level-field',
  ));
  assert.ok(findings.some(
    (item) => item.reason === 'unknown-or-malformed-role',
  ));
  assert.ok(findings.some(
    (item) => item.reason === 'invalid-firestore-timestamp',
  ));
});

test('collection contract catches missing ordered fields without orderBy', () => {
  const findings = validateContractDocument(
    'compliance_requests',
    'subject-3',
    {
      firestoreId: 'c1',
      jobExecutionFirestoreId: 'j1',
      laneKey: 'mechanical',
      status: 'open',
      version: 1,
      createdAt: ts,
    },
    {
      strings: [
        'firestoreId',
        'jobExecutionFirestoreId',
        'laneKey',
        'status',
      ],
      integers: ['version'],
      timestamps: ['createdAt', 'updatedAt'],
    },
  );
  assert.equal(findings.length, 1);
  assert.equal(findings[0].field, 'updatedAt');
});
