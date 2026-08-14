import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

import {
  A05_COLLECTION_REGISTRY,
  A05_DECISIONS,
  assertRegistryCoversRules,
  assertRegistryCoversSource,
  classifyA05Inventory,
  flutterToolsSnapshotCandidates,
  parseArgs,
  reconcileA05DocumentsWithDart,
  sourceDefinedCollectionNames,
  validateGlobalPullRuntimeContract,
} from './a05_production_persisted_integrity_sweep.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const HMAC_KEY = 'a05-test-key-with-at-least-thirty-two-bytes';
const ts = {
  seconds: 1785542400,
  nanoseconds: 0,
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

function hierarchyDocuments() {
  const classId = 'class-1';
  const nodeId = 'node-1';
  const assetId = 'asset-1';
  const componentId = 'component-1';
  const normalizedTag = 'PT101';
  const claimId = createHash('sha256').update(normalizedTag).digest('hex');
  const ownership = {
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Instrumentation',
    accountableRoleKeys: ['seniorInstrumentation'],
  };
  return {
    asset_classes: [{
      id: classId,
      data: {
        schemaVersion: 1,
        assetClassId: classId,
        code: 'FURNACE',
        name: 'Furnace',
        majorArea: 'BAF shop',
        shortDescription: null,
        longDescription: null,
        legacyAssetTypeKey: 'furnace',
        status: 'active',
        version: 1,
        createdAt: ts,
        createdByUid: 'admin-1',
        createdByName: 'Admin',
        updatedAt: ts,
        updatedByUid: 'admin-1',
        updatedByName: 'Admin',
        lastMutationId: 'mutation-1',
      },
    }],
    asset_hierarchy_nodes: [{
      id: nodeId,
      data: {
        schemaVersion: 1,
        nodeId,
        assetClassId: classId,
        parentNodeId: null,
        nodeType: 'component',
        name: 'Pressure transmitter',
        componentTag: null,
        shortDescription: null,
        longDescription: null,
        discipline: 'Instrumentation',
        operatingType: 'Electrical',
        normalState: null,
        failState: null,
        contactArrangement: 'notApplicable',
        manufacturer: null,
        model: null,
        applicability: null,
        sourceReference: null,
        ...ownership,
        sortOrder: 10,
        ancestorNodeIds: [],
        hierarchyPath: ['Pressure transmitter'],
        activeChildCount: 0,
        status: 'active',
        version: 1,
        createdAt: ts,
        createdByUid: 'admin-1',
        createdByName: 'Admin',
        updatedAt: ts,
        updatedByUid: 'admin-1',
        updatedByName: 'Admin',
        lastMutationId: 'mutation-1',
      },
    }],
    asset_instances: [{
      id: assetId,
      data: {
        schemaVersion: 1,
        assetInstanceId: assetId,
        assetClassId: classId,
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        assetNumber: 1,
        name: 'Furnace 1',
        plantTag: 'F-1',
        location: 'BAF shop',
        manufacturer: null,
        model: null,
        serialNumber: null,
        commissionedOn: null,
        serviceState: 'inService',
        ownershipStatus: 'confirmed',
        ownerDiscipline: 'Operations',
        accountableRoleKeys: ['operations'],
        status: 'active',
        activeComponentCount: 1,
        version: 1,
        createdAt: ts,
        updatedAt: ts,
        lastMutationId: 'mutation-1',
      },
    }],
    asset_operational_conditions: [{
      id: assetId,
      data: {
        schemaVersion: 1,
        assetInstanceId: assetId,
        assetClassId: classId,
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        assetNumber: 1,
        assetName: 'Furnace 1',
        condition: 'down',
        active: true,
        causeKeys: ['breakdown'],
        reason: 'Drive fault prevents safe operation.',
        linkedIssueIds: [],
        declaredAt: ts,
        declaredByUid: 'operations-1',
        declaredByName: 'Operations',
        restoredAt: null,
        restoredByUid: null,
        restoredByName: null,
        previousCondition: 'available',
        version: 1,
        updatedAt: ts,
        updatedByUid: 'operations-1',
        updatedByName: 'Operations',
        lastMutationId: 'condition-mutation-1',
      },
    }],
    operational_events: [{
      id: 'event-1',
      data: {
        schemaVersion: 1,
        eventId: 'event-1',
        eventType: 'powerTrip',
        title: 'Incoming power interruption',
        description: 'Incoming power was unavailable across the shop.',
        severity: 'critical',
        scope: 'plantWide',
        affectedAssetClassIds: [],
        affectedAssetInstanceIds: [],
        completedIntervals: [],
        startedAt: ts,
        status: 'open',
        createdAt: ts,
        createdByUid: 'operations-1',
        createdByName: 'Operations',
        resolvedAt: null,
        resolvedByUid: null,
        resolvedByName: null,
        resolutionNote: null,
        version: 1,
        updatedAt: ts,
        updatedByUid: 'operations-1',
        updatedByName: 'Operations',
        lastMutationId: 'event-mutation-1',
      },
    }],
    asset_component_instances: [{
      id: componentId,
      data: {
        schemaVersion: 1,
        componentInstanceId: componentId,
        assetInstanceId: assetId,
        assetInstanceVersionAtMutation: 1,
        assetNumber: 1,
        assetInstanceName: 'Furnace 1',
        assetClassId: classId,
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        definitionNodeId: nodeId,
        definitionNodeVersion: 1,
        definitionName: 'Pressure transmitter',
        hierarchyPath: ['Pressure transmitter'],
        componentTag: 'PT-101',
        manufacturer: null,
        model: null,
        serialNumber: null,
        installedOn: null,
        serviceState: 'inService',
        ...ownership,
        status: 'active',
        version: 1,
        createdAt: ts,
        updatedAt: ts,
        lastMutationId: 'mutation-1',
      },
    }],
    asset_tag_claims: [{
      id: claimId,
      data: {
        schemaVersion: 2,
        ownerType: 'installed_component',
        normalizedTag,
        displayTag: 'PT-101',
        componentInstanceId: componentId,
        definitionNodeId: nodeId,
        definitionName: 'Pressure transmitter',
        assetInstanceId: assetId,
        assetInstanceName: 'Furnace 1',
        assetNumber: 1,
        assetClassId: classId,
        assetClassName: 'Furnace',
        hierarchyPath: ['Pressure transmitter'],
        ...ownership,
        claimedAt: ts,
        claimedByUid: 'admin-1',
        lastMutationId: 'mutation-1',
      },
    }],
  };
}

function qualityDocuments() {
  return {
    quality_warnings: [{
      id: 'issue_ticket-1',
      data: {
        schemaVersion: 1,
        warningId: 'issue_ticket-1',
        sourceType: 'issue',
        sourceId: 'ticket-1',
        sourceVersion: 1,
        sourceChargeNo: 12001,
        sourceSummary: 'Atmosphere interruption during cycle',
        sourceSeverity: 'critical',
        warningReason: 'Atmosphere interruption may affect coil quality.',
        affectedAssets: [{assetType: 'furnace', assetNumber: 7}],
        component: 'Atmosphere control',
        status: 'open',
        closureRequestReason: null,
        closureRequestedAt: null,
        closureRequestedByUid: null,
        closureRequestedByName: null,
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closureDisposition: null,
        linkedReannealingChargeNos: [],
        decisionReason: null,
        createdAt: ts,
        createdByUid: 'operations-1',
        createdByName: 'Operations',
        updatedAt: ts,
        updatedByUid: 'operations-1',
        updatedByName: 'Operations',
        version: 1,
      },
    }],
    quality_monitoring_requests: [{
      id: 'monitoring-1',
      data: {
        schemaVersion: 1,
        requestId: 'monitoring-1',
        baseNumber: 12,
        grade: 'CRGO M4',
        cycleReference: 'Cycle family 7A',
        chargeNumbers: [12001, 12002],
        reason: 'Monitor atmosphere stability during the campaign.',
        status: 'active',
        createdAt: ts,
        createdByUid: 'si-1',
        createdByName: 'SI',
        closedAt: null,
        closedByUid: null,
        closedByName: null,
        closeReason: null,
        updatedAt: ts,
        updatedByUid: 'si-1',
        updatedByName: 'SI',
        version: 1,
        lastMutationId: '44444444-4444-4444-8444-444444444444',
      },
    }],
  };
}

function classify({
  documents = {},
  roots = [],
  subcollections = {},
  reconciliation = [],
} = {}) {
  return classifyA05Inventory({
    documentsByCollection: {...emptyDocuments(), ...documents},
    actualRootCollections: roots,
    subcollectionDocuments: subcollections,
    hmacKey: HMAC_KEY,
    dartReconciliationResults: reconciliation,
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
    'seen.add',
  ]);
  assert.match(source, /await app\.delete\(\);/);
  assert.match(source, /db\.listCollections\(\)/);
  assert.match(source, /db\.collection\(collection\)\.get\(\)/);
});

test('Flutter bridge locates both wrapper and cached Dart SDK layouts', () => {
  const expected = '/opt/flutter/bin/cache/flutter_tools.snapshot';
  assert.ok(
    flutterToolsSnapshotCandidates('/opt/flutter/bin/dart', path.posix)
      .includes(expected),
  );
  assert.ok(
    flutterToolsSnapshotCandidates(
      '/opt/flutter/bin/cache/dart-sdk/bin/dart',
      path.posix,
    ).includes(expected),
  );
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

test('actual Dart readers reconcile valid audit and maintenance records in memory', async () => {
  const documents = {
    ...emptyDocuments(),
    audit_logs: [{
      id: 'private-audit-id',
      data: {
        entityType: 'maintenance_record',
        entityId: 'private-ticket-id',
        action: 'create',
        performedByUid: 'private-actor-id',
        timestamp: ts,
        severity: 'low',
      },
    }],
    maintenance_records: [{
      id: 'ticket-1',
      data: {
        firestoreId: 'ticket-1',
        version: 3,
        assetType: 'base',
        assetNumber: 101,
        maintenanceType: 'breakdown',
        description: 'Private maintenance description',
        routedTo: 'mechanical',
        status: 'open',
        isResolved: false,
        isCritical: false,
        loggedByUid: 'private-actor-id',
        startDate: ts,
        createdAt: ts,
        updatedAt: ts,
        actionsJson: '[]',
        resolutionHistoryJson: '[]',
        isDeleted: false,
      },
    }],
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  assert.equal(reconciliation.length, 2);
  assert.ok(reconciliation.every((result) => result.result === 'PASS'));
  assert.equal(JSON.stringify(reconciliation).includes('private-'), false);

  const result = classify({
    documents,
    roots: ['audit_logs', 'maintenance_records'],
    reconciliation,
  });
  assert.equal(result.decision, A05_DECISIONS.hold);
  assert.equal(
    result.collectionDispositions.audit_logs,
    'DART_STRICT_RECONCILIATION_PASS',
  );
  assert.equal(
    result.collectionDispositions.maintenance_records,
    'DART_STRICT_RECONCILIATION_PASS',
  );
  assert.ok(
    result.blockingFindings.every(
      (finding) => finding.collection !== 'audit_logs' &&
        finding.collection !== 'maintenance_records',
    ),
  );
});

test('actual Dart readers reconcile every hierarchy collection in memory', async () => {
  const hierarchy = hierarchyDocuments();
  const documents = {
    ...emptyDocuments(),
    users: [{id: 'private-user-id', data: user()}],
    runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
    ...hierarchy,
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  assert.equal(reconciliation.length, 7);
  assert.ok(reconciliation.every((result) => result.result === 'PASS'));
  assert.equal(JSON.stringify(reconciliation).includes('component-1'), false);

  const result = classify({
    documents,
    roots: ['users', 'runtime_contracts', ...Object.keys(hierarchy)],
    reconciliation,
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  for (const collection of Object.keys(hierarchy)) {
    assert.equal(
      result.collectionDispositions[collection],
      'DART_STRICT_RECONCILIATION_PASS',
    );
  }
});

test('actual Dart readers reconcile quality warning and monitoring records', async () => {
  const quality = qualityDocuments();
  const documents = {
    ...emptyDocuments(),
    users: [{id: 'private-user-id', data: user()}],
    runtime_contracts: [{id: 'global_pull_v1', data: runtimeContract()}],
    ...quality,
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  assert.equal(reconciliation.length, 2);
  assert.ok(reconciliation.every((result) => result.result === 'PASS'));
  assert.equal(JSON.stringify(reconciliation).includes('ticket-1'), false);

  const result = classify({
    documents,
    roots: ['users', 'runtime_contracts', ...Object.keys(quality)],
    reconciliation,
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  for (const collection of Object.keys(quality)) {
    assert.equal(
      result.collectionDispositions[collection],
      'DART_STRICT_RECONCILIATION_PASS',
    );
  }
});

test('quality warning identity mismatch fails closed in the real Dart reader', async () => {
  const documents = {...emptyDocuments(), ...qualityDocuments()};
  documents.quality_warnings[0] = {
    ...documents.quality_warnings[0],
    data: {...documents.quality_warnings[0].data, sourceId: 'wrong-ticket'},
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  const warning = reconciliation.find(
    (result) => result.collection === 'quality_warnings',
  );
  assert.equal(warning?.result, 'FAIL');
  assert.equal(warning?.errorType, 'PERSISTED_DATA_FORMAT');
  assert.equal(warning?.field, 'sourceId');
});

test('hierarchy tag claims fail closed when document identity is inconsistent', async () => {
  const documents = {...emptyDocuments(), ...hierarchyDocuments()};
  documents.asset_tag_claims[0] = {
    ...documents.asset_tag_claims[0],
    id: 'wrong-claim-id',
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  const claimResult = reconciliation.find(
    (result) => result.collection === 'asset_tag_claims',
  );
  assert.equal(claimResult?.result, 'FAIL');
  assert.equal(claimResult?.errorType, 'PERSISTED_DATA_FORMAT');
  assert.equal(claimResult?.field, 'normalizedTag');
});

test('unsupported nonempty app collections remain fail closed', async () => {
  const documents = {
    ...emptyDocuments(),
    users: [{id: 'private-user-id', data: user()}],
    runtime_contracts: [{
      id: 'global_pull_v1',
      data: runtimeContract(),
    }],
    job_executions: [{id: 'private-execution-id', data: {}}],
  };
  const reconciliation = await reconcileA05DocumentsWithDart({
    documentsByCollection: documents,
    hmacKey: HMAC_KEY,
  });
  assert.deepEqual(reconciliation.map((result) => result.errorType), [
    'UNSUPPORTED_COLLECTION',
  ]);
  const result = classify({
    documents,
    roots: ['users', 'runtime_contracts', 'job_executions'],
    reconciliation,
  });
  assert.equal(result.decision, A05_DECISIONS.hold);
  assert.equal(result.blockingFindingCount, 1);
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
      quality_mutation_receipts: [{id: 'quality-receipt-id', data: {}}],
    },
    roots: [
      'users',
      'runtime_contracts',
      'callable_abuse_controls',
      'quality_mutation_receipts',
    ],
  });
  assert.equal(result.decision, A05_DECISIONS.pass);
  assert.equal(result.collectionCounts.callable_abuse_controls, 1);
  assert.equal(
    result.collectionDispositions.callable_abuse_controls,
    'COUNTED_SERVER_CONTROL_OUTSIDE_APP_DECODER_SCOPE',
  );
  assert.equal(
    result.collectionDispositions.quality_mutation_receipts,
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
