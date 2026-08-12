import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  A05_COLLECTION_REGISTRY,
  A05_DECISIONS,
  assertRegistryCoversRules,
  assertRegistryCoversSource,
  classifyA05Inventory,
  parseArgs,
  sourceDefinedCollectionNames,
  validateGlobalPullRuntimeContract,
} from './a05_production_persisted_integrity_sweep.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const HMAC_KEY = 'a05-test-key-with-at-least-thirty-two-bytes';
const ts = {
  toDate: () => new Date('2026-08-01T00:00:00Z'),
  toMillis: () => 1785542400000,
};

function user() {
  return {
    name: 'Admin',
    email: 'admin@example.invalid',
    roles: ['admin'],
    isApproved: true,
    photoUrl: null,
    fcmToken: null,
    createdAt: ts,
  };
}

function runtimeContract(overrides = {}) {
  return {
    state: 'ACTIVE',
    protocolVersion: 1,
    protocolFingerprint:
      'cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321',
    writerVersion: 'global-pull-server-stamp-v1',
    serverStampField: '_globalPullServerUpdatedAt',
    collections: [
      'abnormality_types',
      'charge_abnormalities',
      'directives',
      'job_diary_entries',
      'job_executions',
      'job_modules',
      'job_templates',
      'knowledge_base',
      'maintenance_records',
      'template_packages',
      'template_publish_audits',
      'template_versions',
    ],
    activatedAt: ts,
    sourceCommit: 'a'.repeat(40),
    backfillReceiptSha256: 'b'.repeat(64),
    ...overrides,
  };
}

function emptyDocuments() {
  return Object.fromEntries(
    Object.keys(A05_COLLECTION_REGISTRY).map((collection) => [collection, []]),
  );
}

function classify({documents = {}, roots = [], subcollections = {}} = {}) {
  return classifyA05Inventory({
    documentsByCollection: {...emptyDocuments(), ...documents},
    actualRootCollections: roots,
    subcollectionDocuments: subcollections,
    hmacKey: HMAC_KEY,
  });
}

test('Rules root and nested collection names are all registered', () => {
  const rules = fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8');
  assert.deepEqual(assertRegistryCoversRules(rules), []);
});

test('app and Functions source collection references are all registered', () => {
  const sources = [];
  for (const sourceRoot of [
    path.join(ROOT, 'lib'),
    path.join(ROOT, 'functions', 'src'),
  ]) {
    const pending = [sourceRoot];
    while (pending.length > 0) {
      const current = pending.pop();
      for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
        const absolute = path.join(current, entry.name);
        if (entry.isDirectory()) pending.push(absolute);
        else if (
          (entry.name.endsWith('.ts') || entry.name.endsWith('.dart')) &&
          !entry.name.endsWith('.g.dart')
        ) sources.push(fs.readFileSync(absolute, 'utf8'));
      }
    }
  }
  assert.deepEqual(assertRegistryCoversSource(sources), []);
  assert.deepEqual(
    sourceDefinedCollectionNames([
      "db.collection('literal_root')",
      'export const EVENT_COLLECTION =\n  "constant_group";',
    ]),
    ['constant_group', 'literal_root'],
  );
});

test('production sweep source contains no Firestore mutation API', () => {
  const source = fs.readFileSync(
    path.join(ROOT, 'tools/v4/a05_production_persisted_integrity_sweep.mjs'),
    'utf8',
  );
  for (const pattern of [
    /\bwriteBatch\s*\(/,
    /\bbulkWriter\s*\(/,
    /\brunTransaction\s*\(/,
    /\bsetCustomUserClaims\s*\(/,
    /\bupdateUser\s*\(/,
    /\bdeleteUser\s*\(/,
    /\bcreateUser\s*\(/,
  ]) {
    assert.doesNotMatch(source, pattern);
  }
  const mutationNamedCalls = [
    ...source.matchAll(
      /\b([A-Za-z_$][\w$]*)\.(set|update|delete|create|add)\s*\(/g,
    ),
  ].map((match) => `${match[1]}.${match[2]}`);
  assert.deepEqual([...new Set(mutationNamedCalls)].sort(), [
    'app.delete',
    'result.add',
  ]);
  assert.match(source, /await app\.delete\(\);/);
  assert.match(source, /db\.listCollections\(\)/);
  assert.match(source, /db\.collection\(collection\)\.get\(\)/);
});

test('canonical users, active runtime contract and empty app data pass', () => {
  const result = classify({
    documents: {
      users: [{id: 'private-user-id', data: user()}],
      runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
    },
    roots: ['users', 'runtime_contracts'],
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  assert.equal(result.blockingFindingCount, 0);
  assert.equal(
    result.collectionDispositions.job_executions,
    'EMPTY_NO_REPAIR_REQUIRED',
  );
  assert.equal(JSON.stringify(result).includes('private-user-id'), false);
});

test('non-blocking user warnings do not become strict decoder failures', () => {
  const result = classify({
    documents: {
      users: [{id: 'u1', data: {...user(), roles: ['admin', 'admin']}}],
      runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
    },
    roots: ['users', 'runtime_contracts'],
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  assert.equal(result.warningCount, 1);
  assert.equal(result.collectionDispositions.users, 'STRICT_DECODER_PASS');
});

test('any supported operational record requires Dart reconciliation', () => {
  const result = classify({
    documents: {
      users: [{id: 'u1', data: user()}],
      runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
      job_executions: [{id: 'sensitive-execution-id', data: {}}],
    },
    roots: ['users', 'runtime_contracts', 'job_executions'],
  });
  assert.equal(result.decision, A05_DECISIONS.hold);
  assert.equal(
    result.collectionDispositions.job_executions,
    'DART_RECONCILIATION_REQUIRED',
  );
  assert.equal(JSON.stringify(result).includes('sensitive-execution-id'), false);
  assert.match(
    result.blockingFindings[0].subjectPseudonym,
    /^hmac256:[0-9a-f]{64}$/,
  );
});

test('unknown collections and module revisions fail coverage closed', () => {
  const result = classify({
    documents: {
      users: [{id: 'u1', data: user()}],
      runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
    },
    roots: ['users', 'runtime_contracts', 'unexpected_records'],
    subcollections: {
      revisions: [{path: 'module_registry/family/revisions/revision-1'}],
    },
  });
  assert.equal(result.decision, A05_DECISIONS.hold);
  assert.deepEqual(result.coverage.unregisteredRootCollections, [
    'unexpected_records',
  ]);
  assert.equal(result.subcollectionCounts.revisions, 1);
});

test('server-only receipts are counted without becoming app decoder evidence', () => {
  const result = classify({
    documents: {
      users: [{id: 'u1', data: user()}],
      runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
      callable_abuse_controls: [{id: 'rate-limit-id', data: {}}],
    },
    roots: ['users', 'runtime_contracts', 'callable_abuse_controls'],
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  assert.equal(result.collectionCounts.callable_abuse_controls, 1);
  assert.equal(
    result.collectionDispositions.callable_abuse_controls,
    'COUNTED_SERVER_CONTROL_OUTSIDE_APP_DECODER_SCOPE',
  );
});

test('runtime contract requires exact shape and activation evidence', () => {
  assert.deepEqual(
    validateGlobalPullRuntimeContract('global_pull_v1', runtimeContract()),
    [],
  );
  assert.ok(
    validateGlobalPullRuntimeContract(
      'wrong-id',
      runtimeContract({sourceCommit: 'not-a-commit'}),
    ).includes('invalid-source-commit'),
  );
});

test('CLI parser requires explicit values and recognizes production custody', () => {
  const args = parseArgs([
    '--project',
    'crm3-baf-ops-b8638',
    '--output',
    'evidence.json',
    '--allow-production-read-only',
    '--confirm-project',
    'crm3-baf-ops-b8638',
  ]);
  assert.equal(args.allowProduction, true);
  assert.equal(args.confirmProject, 'crm3-baf-ops-b8638');
  assert.throws(() => parseArgs(['--project']), /requires a value/);
});
