#!/usr/bin/env node
/**
 * A-05 read-only production inventory and reconciliation gate.
 *
 * The tool has no cloud mutation path. It emits only collection counts and
 * HMAC-pseudonymized identities for records that still require reconciliation.
 */
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import process from 'node:process';
import {createHash, randomBytes} from 'node:crypto';
import {spawn, spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

import {
  assertHmacKey,
  assertNewEvidenceOutput,
  assertProductionReadCustody,
  pseudonymizeSubject,
  readGitSourceAuthority,
  validateUserDocument,
} from './firestore_integrity_sweep.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const DEFAULT_HMAC_KEY_ENV = 'CRM3_A05_HMAC_KEY';
const FLUTTER_RECONCILIATION_HARNESS = path.join(
  ROOT,
  'test/tools/a05_persisted_reconciliation_bridge_test.dart',
);
const DART_RECONCILIATION_COLLECTIONS = new Set([
  'asset_classes',
  'asset_component_instances',
  'asset_hierarchy_nodes',
  'asset_instances',
  'asset_availability_current',
  'asset_condition_declarations',
  'asset_operational_conditions',
  'asset_tag_claims',
  'base_inner_cover_assignments',
  'burner_condition_rounds',
  'frequent_issue_definitions',
  'furnace_stuckup_cases',
  'inner_cover_fabrications',
  'inner_cover_linkages',
  'inner_cover_profiles',
  'inspection_campaigns',
  'inspection_definitions',
  'inspection_findings',
  'inspection_observations',
  'audit_logs',
  'maintenance_class_definitions',
  'maintenance_completion_events',
  'maintenance_due_states',
  'maintenance_plans',
  'maintenance_records',
  'operational_events',
  'operational_event_issue_links',
  'quality_monitoring_requests',
  'quality_warnings',
]);

export const A05_DECISIONS = Object.freeze({
  pass: 'PASS_A05_READ_ONLY_PRODUCTION_RECONCILIATION',
  hold: 'HOLD_A05_RECONCILIATION_OR_COVERAGE_REQUIRED',
});

export const A05_COLLECTION_REGISTRY = Object.freeze({
  users: 'STRICT_USER_PROFILE',
  runtime_contracts: 'STRICT_RUNTIME_CONTRACT',
  asset_classes: 'DART_RECONCILIATION_REQUIRED',
  asset_hierarchy_nodes: 'DART_RECONCILIATION_REQUIRED',
  asset_instances: 'DART_RECONCILIATION_REQUIRED',
  asset_component_instances: 'DART_RECONCILIATION_REQUIRED',
  asset_tag_claims: 'DART_RECONCILIATION_REQUIRED',
  asset_availability_current: 'DART_RECONCILIATION_REQUIRED',
  asset_availability_constraints: 'SERVER_CONTROL_RECORD',
  asset_condition_declarations: 'DART_RECONCILIATION_REQUIRED',
  asset_condition_evidence: 'SERVER_CONTROL_RECORD',
  asset_operational_conditions: 'DART_RECONCILIATION_REQUIRED',
  burner_condition_rounds: 'DART_RECONCILIATION_REQUIRED',
  furnace_stuckup_cases: 'DART_RECONCILIATION_REQUIRED',
  inner_cover_profiles: 'DART_RECONCILIATION_REQUIRED',
  base_inner_cover_assignments: 'DART_RECONCILIATION_REQUIRED',
  inner_cover_linkages: 'DART_RECONCILIATION_REQUIRED',
  inner_cover_fabrications: 'DART_RECONCILIATION_REQUIRED',
  inner_cover_serial_claims: 'SERVER_CONTROL_RECORD',
  inner_cover_donor_part_claims: 'SERVER_CONTROL_RECORD',
  inner_cover_lifecycle_audits: 'SERVER_CONTROL_RECORD',
  inner_cover_lifecycle_receipts: 'SERVER_CONTROL_RECORD',
  asset_class_codes: 'SERVER_CONTROL_RECORD',
  asset_instance_numbers: 'SERVER_CONTROL_RECORD',
  asset_hierarchy_audits: 'SERVER_CONTROL_RECORD',
  asset_hierarchy_mutation_receipts: 'SERVER_CONTROL_RECORD',
  asset_operational_condition_audits: 'SERVER_CONTROL_RECORD',
  asset_operational_condition_receipts: 'SERVER_CONTROL_RECORD',
  burner_condition_round_receipts: 'SERVER_CONTROL_RECORD',
  governed_migration_audits: 'SERVER_CONTROL_RECORD',
  governed_migration_contracts: 'SERVER_CONTROL_RECORD',
  frequent_issue_definitions: 'DART_RECONCILIATION_REQUIRED',
  frequent_issue_definition_audits: 'SERVER_CONTROL_RECORD',
  historical_maintenance_records: 'SERVER_CONTROL_RECORD',
  historical_maintenance_audits: 'SERVER_CONTROL_RECORD',
  inspection_definitions: 'DART_RECONCILIATION_REQUIRED',
  inspection_definition_audits: 'SERVER_CONTROL_RECORD',
  inspection_campaigns: 'DART_RECONCILIATION_REQUIRED',
  inspection_campaign_audits: 'SERVER_CONTROL_RECORD',
  inspection_observations: 'DART_RECONCILIATION_REQUIRED',
  inspection_findings: 'DART_RECONCILIATION_REQUIRED',
  inspection_finding_events: 'SERVER_CONTROL_RECORD',
  inspection_issue_links: 'SERVER_CONTROL_RECORD',
  inspection_target_audits: 'SERVER_CONTROL_RECORD',
  inspection_verifications: 'SERVER_CONTROL_RECORD',
  issue_governance_review_queue: 'SERVER_CONTROL_RECORD',
  knowledge_base: 'DART_RECONCILIATION_REQUIRED',
  knowledge_base_meta: 'DART_RECONCILIATION_REQUIRED',
  maintenance_records: 'DART_RECONCILIATION_REQUIRED',
  maintenance_burner_closures: 'SERVER_CONTROL_RECORD',
  maintenance_class_definitions: 'DART_RECONCILIATION_REQUIRED',
  maintenance_class_audits: 'SERVER_CONTROL_RECORD',
  maintenance_classification_audits: 'SERVER_CONTROL_RECORD',
  maintenance_completion_events: 'DART_RECONCILIATION_REQUIRED',
  maintenance_completion_sources: 'SERVER_CONTROL_RECORD',
  maintenance_due_states: 'DART_RECONCILIATION_REQUIRED',
  maintenance_plans: 'DART_RECONCILIATION_REQUIRED',
  maintenance_plan_audits: 'SERVER_CONTROL_RECORD',
  operational_events: 'DART_RECONCILIATION_REQUIRED',
  operational_event_issue_links: 'DART_RECONCILIATION_REQUIRED',
  operational_event_issue_link_audits: 'SERVER_CONTROL_RECORD',
  operational_event_issue_link_receipts: 'SERVER_CONTROL_RECORD',
  template_packages: 'DART_RECONCILIATION_REQUIRED',
  template_versions: 'DART_RECONCILIATION_REQUIRED',
  template_publish_audits: 'DART_RECONCILIATION_REQUIRED',
  module_registry: 'DART_RECONCILIATION_REQUIRED',
  module_registry_audits: 'DART_RECONCILIATION_REQUIRED',
  job_templates: 'DART_RECONCILIATION_REQUIRED',
  job_executions: 'DART_RECONCILIATION_REQUIRED',
  job_diary_entries: 'DART_RECONCILIATION_REQUIRED',
  job_modules: 'DART_RECONCILIATION_REQUIRED',
  directives: 'DART_RECONCILIATION_REQUIRED',
  charges: 'DART_RECONCILIATION_REQUIRED',
  abnormality_types: 'DART_RECONCILIATION_REQUIRED',
  charge_abnormalities: 'DART_RECONCILIATION_REQUIRED',
  maintenance_workflows: 'DART_RECONCILIATION_REQUIRED',
  job_lanes: 'DART_RECONCILIATION_REQUIRED',
  compliance_requests: 'DART_RECONCILIATION_REQUIRED',
  compliance_attempts: 'DART_RECONCILIATION_REQUIRED',
  equipment_status: 'DART_RECONCILIATION_REQUIRED',
  equipment_prompt_master: 'DART_RECONCILIATION_REQUIRED',
  maintenance_workflow_events: 'DART_RECONCILIATION_REQUIRED',
  audit_logs: 'DART_RECONCILIATION_REQUIRED',
  published_template_assignment_requests: 'SERVER_CONTROL_RECORD',
  maintenance_workflow_command_receipts: 'SERVER_CONTROL_RECORD',
  pilot_record_purge_receipts: 'SERVER_CONTROL_RECORD',
  user_authority_mutation_receipts: 'SERVER_CONTROL_RECORD',
  charge_abnormality_mutation_receipts: 'SERVER_CONTROL_RECORD',
  quality_warnings: 'DART_RECONCILIATION_REQUIRED',
  quality_monitoring_requests: 'DART_RECONCILIATION_REQUIRED',
  quality_mutation_receipts: 'SERVER_CONTROL_RECORD',
  operational_event_audits: 'SERVER_CONTROL_RECORD',
  operational_event_receipts: 'SERVER_CONTROL_RECORD',
  workflow_notification_receipts: 'SERVER_CONTROL_RECORD',
  notification_event_receipts: 'SERVER_CONTROL_RECORD',
  callable_abuse_controls: 'SERVER_CONTROL_RECORD',
});

export const A05_SUBCOLLECTION_REGISTRY = Object.freeze({
  revisions: 'DART_RECONCILIATION_REQUIRED',
  notification_installations: 'SERVER_CONTROL_RECORD',
});

const GLOBAL_PULL_COLLECTIONS = Object.freeze([
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
]);
const GLOBAL_PULL_KEYS = new Set([
  'state',
  'protocolVersion',
  'protocolFingerprint',
  'writerVersion',
  'serverStampField',
  'collections',
  'activatedAt',
  'sourceCommit',
  'backfillReceiptSha256',
]);
const GLOBAL_PULL_FINGERPRINT =
  'cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321';

function hasTimestampShape(value) {
  return value != null &&
    typeof value.toDate === 'function' &&
    Number.isFinite(value.toMillis?.()) &&
    !Number.isNaN(value.toDate().getTime());
}

function exactStringArray(left, right) {
  return Array.isArray(left) &&
    left.length === right.length &&
    left.every((value, index) => value === right[index]);
}

export function validateGlobalPullRuntimeContract(documentId, data) {
  const reasons = [];
  const value = data != null && typeof data === 'object' && !Array.isArray(data)
    ? data
    : {};
  if (documentId !== 'global_pull_v1') reasons.push('unexpected-document-id');
  const keys = Object.keys(value);
  if (
    keys.length !== GLOBAL_PULL_KEYS.size ||
    keys.some((key) => !GLOBAL_PULL_KEYS.has(key))
  ) reasons.push('invalid-key-set');
  if (value.state !== 'ACTIVE') reasons.push('state-not-active');
  if (value.protocolVersion !== 1) reasons.push('protocol-version-mismatch');
  if (value.protocolFingerprint !== GLOBAL_PULL_FINGERPRINT) {
    reasons.push('protocol-fingerprint-mismatch');
  }
  if (value.writerVersion !== 'global-pull-server-stamp-v1') {
    reasons.push('writer-version-mismatch');
  }
  if (value.serverStampField !== '_globalPullServerUpdatedAt') {
    reasons.push('server-stamp-field-mismatch');
  }
  if (!exactStringArray(value.collections, GLOBAL_PULL_COLLECTIONS)) {
    reasons.push('collection-set-mismatch');
  }
  if (!hasTimestampShape(value.activatedAt)) reasons.push('invalid-activated-at');
  if (!/^[0-9a-f]{40}$/.test(value.sourceCommit ?? '')) {
    reasons.push('invalid-source-commit');
  }
  if (!/^[0-9a-f]{64}$/.test(value.backfillReceiptSha256 ?? '')) {
    reasons.push('invalid-backfill-receipt');
  }
  return reasons;
}

export function rulesRootCollections(rulesSource) {
  const result = new Set();
  const pattern = /^\s*match \/([^/{]+)\/\{[^}]+\}\s*\{/gm;
  for (const match of rulesSource.matchAll(pattern)) result.add(match[1]);
  return [...result].sort();
}

export function assertRegistryCoversRules(rulesSource) {
  const rootRegistry = new Set(Object.keys(A05_COLLECTION_REGISTRY));
  const subcollections = new Set(Object.keys(A05_SUBCOLLECTION_REGISTRY));
  return rulesRootCollections(rulesSource).filter(
    (collection) => !rootRegistry.has(collection) && !subcollections.has(collection),
  );
}

export function sourceDefinedCollectionNames(sourceTexts) {
  const result = new Set();
  const sources = Array.isArray(sourceTexts) ? sourceTexts : [sourceTexts];
  const literalCall = /\.collection\s*\(\s*(['"])([^'"]+)\1\s*\)/g;
  const namedConstant = /\b(?:(?:static\s+)?const\s+String\s+\w*[Cc]ollection\w*|(?:export\s+)?const\s+\w*COLLECTION\w*)\s*=\s*(['"])([^'"]+)\1/g;
  for (const source of sources) {
    for (const match of String(source).matchAll(literalCall)) result.add(match[2]);
    for (const match of String(source).matchAll(namedConstant)) result.add(match[2]);
  }
  return [...result].sort();
}

export function assertRegistryCoversSource(sourceTexts) {
  const registry = new Set([
    ...Object.keys(A05_COLLECTION_REGISTRY),
    ...Object.keys(A05_SUBCOLLECTION_REGISTRY),
  ]);
  return sourceDefinedCollectionNames(sourceTexts).filter(
    (collection) => !registry.has(collection),
  );
}

function repositoryCollectionSources() {
  const result = [];
  const roots = [path.join(ROOT, 'lib'), path.join(ROOT, 'functions', 'src')];
  for (const sourceRoot of roots) {
    const pending = [sourceRoot];
    while (pending.length > 0) {
      const current = pending.pop();
      for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
        const absolute = path.join(current, entry.name);
        if (entry.isDirectory()) pending.push(absolute);
        else if (
          (entry.name.endsWith('.ts') || entry.name.endsWith('.dart')) &&
          !entry.name.endsWith('.g.dart')
        ) result.push(fs.readFileSync(absolute, 'utf8'));
      }
    }
  }
  return result;
}

function sortedObject(value) {
  return Object.fromEntries(
    Object.entries(value).sort(([left], [right]) => left.localeCompare(right)),
  );
}

export function classifyA05Inventory({
  documentsByCollection,
  actualRootCollections,
  subcollectionDocuments = {},
  hmacKey,
  dartReconciliationResults = [],
}) {
  assertHmacKey(hmacKey);
  const blockingFindings = [];
  const warnings = [];
  const collectionCounts = {};
  const collectionDispositions = {};
  const registeredRoots = new Set(Object.keys(A05_COLLECTION_REGISTRY));
  const reconciliationBySubject = new Map(
    dartReconciliationResults.map((result) => [
      `${result.collection}\u0000${result.subjectPseudonym}`,
      result,
    ]),
  );
  const unregisteredRootCollections = [...new Set(actualRootCollections)]
    .filter((name) => !registeredRoots.has(name))
    .sort();

  for (const [collection, mode] of Object.entries(A05_COLLECTION_REGISTRY)) {
    const documents = documentsByCollection[collection] ?? [];
    collectionCounts[collection] = documents.length;
    if (mode === 'STRICT_USER_PROFILE') {
      let blockingFindingCount = 0;
      for (const document of documents) {
        const subjectPseudonym = pseudonymizeSubject(
          hmacKey,
          `firestore:${collection}`,
          document.id,
        );
        const findings = validateUserDocument(subjectPseudonym, document.data);
        for (const item of findings) {
          const output = {
            collection,
            subjectPseudonym,
            field: item.field,
            reason: item.reason,
            actualType: item.actualType,
          };
          if (item.severity === 'WARNING') warnings.push(output);
          else {
            blockingFindings.push(output);
            blockingFindingCount += 1;
          }
        }
      }
      collectionDispositions[collection] = blockingFindingCount === 0
        ? 'STRICT_DECODER_PASS'
        : 'STRICT_DECODER_FINDINGS';
    } else if (mode === 'STRICT_RUNTIME_CONTRACT') {
      let findingCount = 0;
      if (documents.length !== 1) {
        blockingFindings.push({
          collection,
          reason: 'exactly-one-active-runtime-contract-required',
          observedCount: documents.length,
        });
        findingCount += 1;
      }
      for (const document of documents) {
        const subjectPseudonym = pseudonymizeSubject(
          hmacKey,
          `firestore:${collection}`,
          document.id,
        );
        for (const reason of validateGlobalPullRuntimeContract(
          document.id,
          document.data,
        )) {
          blockingFindings.push({collection, subjectPseudonym, reason});
          findingCount += 1;
        }
      }
      collectionDispositions[collection] = findingCount === 0
        ? 'STRICT_DECODER_PASS'
        : 'STRICT_DECODER_FINDINGS';
    } else if (mode === 'DART_RECONCILIATION_REQUIRED') {
      if (documents.length === 0) {
        collectionDispositions[collection] = 'EMPTY_NO_REPAIR_REQUIRED';
      } else {
        let failed = 0;
        for (const document of documents) {
          const subjectPseudonym = pseudonymizeSubject(
            hmacKey,
            `firestore:${collection}`,
            document.id,
          );
          const reconciliation = reconciliationBySubject.get(
            `${collection}\u0000${subjectPseudonym}`,
          );
          if (reconciliation?.result !== 'PASS') {
            failed += 1;
            blockingFindings.push({
              collection,
              subjectPseudonym,
              reason: 'supported-record-strict-reader-reconciliation-failed',
              reconciliationError:
                reconciliation?.errorType ?? 'MISSING_RECONCILIATION_RESULT',
              ...(reconciliation?.field == null
                ? {}
                : {field: reconciliation.field}),
            });
          }
        }
        collectionDispositions[collection] = failed === 0
          ? 'DART_STRICT_RECONCILIATION_PASS'
          : 'DART_RECONCILIATION_REQUIRED';
      }
    } else {
      collectionDispositions[collection] =
        'COUNTED_SERVER_CONTROL_OUTSIDE_APP_DECODER_SCOPE';
    }
  }

  const subcollectionCounts = {};
  const subcollectionDispositions = {};
  for (const [collection, mode] of Object.entries(A05_SUBCOLLECTION_REGISTRY)) {
    const documents = subcollectionDocuments[collection] ?? [];
    subcollectionCounts[collection] = documents.length;
    if (mode === 'DART_RECONCILIATION_REQUIRED' && documents.length > 0) {
      subcollectionDispositions[collection] = 'DART_RECONCILIATION_REQUIRED';
      for (const document of documents) {
        blockingFindings.push({
          collectionGroup: collection,
          subjectPseudonym: pseudonymizeSubject(
            hmacKey,
            `firestore-group:${collection}`,
            document.path,
          ),
          reason: 'supported-record-requires-strict-reader-reconciliation',
        });
      }
    } else {
      subcollectionDispositions[collection] = documents.length === 0
        ? 'EMPTY_NO_REPAIR_REQUIRED'
        : 'COUNTED_SERVER_CONTROL_OUTSIDE_APP_DECODER_SCOPE';
    }
  }

  for (const collection of unregisteredRootCollections) {
    blockingFindings.push({collection, reason: 'unregistered-root-collection'});
  }
  return {
    coverage: {
      registeredRootCollectionCount: registeredRoots.size,
      enumeratedRootCollectionCount: new Set(actualRootCollections).size,
      registeredSubcollectionGroupCount:
        Object.keys(A05_SUBCOLLECTION_REGISTRY).length,
      unregisteredRootCollections,
    },
    collectionCounts: sortedObject(collectionCounts),
    collectionDispositions: sortedObject(collectionDispositions),
    subcollectionCounts: sortedObject(subcollectionCounts),
    subcollectionDispositions: sortedObject(subcollectionDispositions),
    blockingFindingCount: blockingFindings.length,
    warningCount: warnings.length,
    blockingFindings,
    warnings,
    decision: blockingFindings.length === 0
      ? A05_DECISIONS.pass
      : A05_DECISIONS.hold,
  };
}

function bridgeFirestoreValue(value) {
  if (value == null || typeof value === 'string' || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    if (Number.isFinite(value)) return value;
    return {
      __a05FirestoreType: 'nonFiniteNumber',
      value: Number.isNaN(value) ? 'NaN' : value > 0 ? 'Infinity' : '-Infinity',
    };
  }
  if (Array.isArray(value)) return value.map(bridgeFirestoreValue);
  if (
    typeof value === 'object' &&
    Number.isInteger(value.seconds) &&
    Number.isInteger(value.nanoseconds) &&
    typeof value.toDate === 'function'
  ) {
    return {
      __a05FirestoreType: 'timestamp',
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (typeof value === 'object') {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new TypeError('unsupported Firestore value type');
    }
    return Object.fromEntries(
      Object.entries(value).map(([key, nested]) => [
        key,
        bridgeFirestoreValue(nested),
      ]),
    );
  }
  throw new TypeError('unsupported Firestore value type');
}

export async function reconcileA05DocumentsWithDart({
  documentsByCollection,
  hmacKey,
}) {
  assertHmacKey(hmacKey);
  const records = [];
  const localFailures = [];
  for (const [collection, mode] of Object.entries(A05_COLLECTION_REGISTRY)) {
    if (mode !== 'DART_RECONCILIATION_REQUIRED') continue;
    for (const document of documentsByCollection[collection] ?? []) {
      const subjectPseudonym = pseudonymizeSubject(
        hmacKey,
        `firestore:${collection}`,
        document.id,
      );
      if (!DART_RECONCILIATION_COLLECTIONS.has(collection)) {
        localFailures.push({
          collection,
          subjectPseudonym,
          result: 'FAIL',
          errorType: 'UNSUPPORTED_COLLECTION',
        });
        continue;
      }
      try {
        records.push({
          collection,
          subjectPseudonym,
          documentId: document.id,
          data: bridgeFirestoreValue(document.data),
        });
      } catch (_) {
        localFailures.push({
          collection,
          subjectPseudonym,
          result: 'FAIL',
          errorType: 'UNSUPPORTED_FIRESTORE_VALUE',
        });
      }
    }
  }
  if (records.length === 0) return localFailures;

  const dartExecutable = resolveDartExecutable();
  const flutterToolsSnapshot = dartExecutable == null
    ? null
    : flutterToolsSnapshotCandidates(dartExecutable)
        .find((candidate) => fs.existsSync(candidate)) ?? null;
  if (
    dartExecutable == null ||
    !fs.existsSync(flutterToolsSnapshot) ||
    !fs.existsSync(FLUTTER_RECONCILIATION_HARNESS)
  ) {
    return bridgeUnavailable(localFailures, records);
  }

  const bridgeToken = randomBytes(32).toString('hex');
  const input = JSON.stringify({schemaVersion: 1, records});
  let output = null;
  let completeOutput;
  const outputReceived = new Promise((resolve) => {
    completeOutput = resolve;
  });
  const server = http.createServer((request, response) => {
    if (request.headers.authorization !== `Bearer ${bridgeToken}`) {
      response.statusCode = 403;
      response.end();
      return;
    }
    if (request.method === 'GET' && request.url === '/input') {
      response.statusCode = 200;
      response.setHeader('content-type', 'application/json');
      response.end(input);
      return;
    }
    if (request.method !== 'POST' || request.url !== '/output') {
      response.statusCode = 404;
      response.end();
      return;
    }
    const chunks = [];
    let byteCount = 0;
    request.on('data', (chunk) => {
      byteCount += chunk.length;
      if (byteCount <= 16 * 1024 * 1024) chunks.push(chunk);
    });
    request.on('end', () => {
      try {
        if (byteCount > 16 * 1024 * 1024) throw new Error('response too large');
        output = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        response.statusCode = 204;
      } catch (_) {
        response.statusCode = 400;
      }
      response.end();
      completeOutput();
    });
  });
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address == null || typeof address === 'string') {
      return bridgeUnavailable(localFailures, records);
    }
    const child = spawn(
      dartExecutable,
      [
        flutterToolsSnapshot,
        'test',
        FLUTTER_RECONCILIATION_HARNESS,
        '--no-pub',
        '--reporter=compact',
      ],
      {
        cwd: ROOT,
        env: {
          ...process.env,
          A05_BRIDGE_URL: `http://127.0.0.1:${address.port}`,
          A05_BRIDGE_TOKEN: bridgeToken,
        },
        stdio: ['ignore', 'ignore', 'ignore'],
        windowsHide: true,
      },
    );
    const childStatus = await new Promise((resolve) => {
      const timer = setTimeout(() => {
        child.kill();
        resolve(null);
      }, 180_000);
      child.once('error', () => {
        clearTimeout(timer);
        resolve(null);
      });
      child.once('close', (status) => {
        clearTimeout(timer);
        resolve(status);
      });
    });
    await Promise.race([
      outputReceived,
      new Promise((resolve) => setTimeout(resolve, 1_000)),
    ]);
    if (childStatus !== 0 || output == null) {
      return bridgeUnavailable(localFailures, records);
    }
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  try {
    if (output?.schemaVersion !== 1 || !Array.isArray(output.results)) {
      throw new Error('invalid bridge response');
    }
  } catch (_) {
    return [
      ...localFailures,
      ...records.map((record) => ({
        collection: record.collection,
        subjectPseudonym: record.subjectPseudonym,
        result: 'FAIL',
        errorType: 'INVALID_DART_BRIDGE_RESPONSE',
      })),
    ];
  }
  const expected = new Set(
    records.map((record) => `${record.collection}\u0000${record.subjectPseudonym}`),
  );
  const accepted = [];
  const seen = new Set();
  for (const result of output.results) {
    const key = `${result?.collection}\u0000${result?.subjectPseudonym}`;
    if (!expected.has(key) || seen.has(key)) continue;
    seen.add(key);
    accepted.push(result);
  }
  for (const record of records) {
    const key = `${record.collection}\u0000${record.subjectPseudonym}`;
    if (!seen.has(key)) {
      accepted.push({
        collection: record.collection,
        subjectPseudonym: record.subjectPseudonym,
        result: 'FAIL',
        errorType: 'MISSING_DART_BRIDGE_RESULT',
      });
    }
  }
  return [...localFailures, ...accepted];
}

function bridgeUnavailable(localFailures, records) {
  return [
    ...localFailures,
    ...records.map((record) => ({
      collection: record.collection,
      subjectPseudonym: record.subjectPseudonym,
      result: 'FAIL',
      errorType: 'DART_BRIDGE_UNAVAILABLE',
    })),
  ];
}

export function flutterToolsSnapshotCandidates(
  dartExecutable,
  pathApi = path,
) {
  const binDirectory = pathApi.dirname(dartExecutable);
  return [...new Set([
    pathApi.resolve(
      binDirectory,
      '..',
      '..',
      'flutter_tools.snapshot',
    ),
    pathApi.join(binDirectory, 'cache', 'flutter_tools.snapshot'),
  ])];
}

function resolveDartExecutable() {
  const executableName = process.platform === 'win32' ? 'where.exe' : 'which';
  const located = spawnSync(executableName, ['dart'], {
    encoding: 'utf8',
    windowsHide: true,
  });
  if (located.status !== 0) return null;
  for (const line of located.stdout.split(/\r?\n/)) {
    const candidate = line.trim();
    if (!candidate) continue;
    if (process.platform !== 'win32' && fs.existsSync(candidate)) return candidate;
    const direct = candidate.toLowerCase().endsWith('.exe')
      ? candidate
      : path.join(
          path.dirname(candidate),
          'cache',
          'dart-sdk',
          'bin',
          'dart.exe',
        );
    if (fs.existsSync(direct)) return direct;
  }
  return null;
}

function requiredArgValue(argv, index, argument) {
  const value = argv[index + 1];
  if (value == null || value.startsWith('--')) {
    throw new Error(`${argument} requires a value.`);
  }
  return value;
}

export function parseArgs(argv) {
  const out = {hmacKeyEnv: DEFAULT_HMAC_KEY_ENV};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--project') out.project = requiredArgValue(argv, i++, arg);
    else if (arg === '--output') out.output = requiredArgValue(argv, i++, arg);
    else if (arg === '--confirm-project') {
      out.confirmProject = requiredArgValue(argv, i++, arg);
    } else if (arg === '--expected-source-commit') {
      out.expectedSourceCommit = requiredArgValue(argv, i++, arg);
    } else if (arg === '--expected-source-tree') {
      out.expectedSourceTree = requiredArgValue(argv, i++, arg);
    } else if (arg === '--hmac-key-env') {
      out.hmacKeyEnv = requiredArgValue(argv, i++, arg);
    } else if (arg === '--allow-production-read-only') {
      out.allowProduction = true;
    } else if (arg === '--help') out.help = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
}

function writeEvidence(output, result) {
  const {resolved, digestPath} = assertNewEvidenceOutput(output);
  const body = `${JSON.stringify(result, null, 2)}\n`;
  const digest = createHash('sha256').update(body, 'utf8').digest('hex');
  fs.writeFileSync(resolved, body, {encoding: 'utf8', flag: 'wx'});
  fs.writeFileSync(
    digestPath,
    `${digest}  ${path.basename(resolved)}\n`,
    {encoding: 'utf8', flag: 'wx'},
  );
  return {resolved, digest};
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(
      'Usage: node tools/v4/a05_production_persisted_integrity_sweep.mjs ' +
      '--project <id> --output <new-file> [production custody options]',
    );
    return;
  }
  args.project = args.project || process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT;
  if (!args.project || !args.output) {
    throw new Error('--project and --output are required.');
  }
  assertNewEvidenceOutput(args.output);
  const hmacKey = assertHmacKey(process.env[args.hmacKeyEnv]);
  const sourceAuthority = readGitSourceAuthority();
  assertProductionReadCustody(args, process.env, sourceAuthority);

  const rulesSource = fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8');
  const uncoveredRulesCollections = assertRegistryCoversRules(rulesSource);
  if (uncoveredRulesCollections.length > 0) {
    throw new Error(
      `A-05 collection registry omits Rules paths: ${uncoveredRulesCollections.join(', ')}`,
    );
  }
  const collectionSources = repositoryCollectionSources();
  const sourceCollectionNames = sourceDefinedCollectionNames(collectionSources);
  const uncoveredSourceCollections = assertRegistryCoversSource(collectionSources);
  if (uncoveredSourceCollections.length > 0) {
    throw new Error(
      `A-05 collection registry omits source paths: ${uncoveredSourceCollections.join(', ')}`,
    );
  }

  const require = createRequire(import.meta.url);
  const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));
  const app = admin.initializeApp(
    {projectId: args.project},
    `a05-read-only-${process.pid}-${Date.now()}`,
  );
  const db = app.firestore();
  const startedAt = new Date().toISOString();
  try {
    const actualRootCollections = (await db.listCollections())
      .map((collection) => collection.id);
    const documentsByCollection = {};
    for (const collection of Object.keys(A05_COLLECTION_REGISTRY)) {
      const snapshot = await db.collection(collection).get();
      documentsByCollection[collection] = snapshot.docs.map((document) => ({
        id: document.id,
        data: document.data() ?? {},
      }));
    }
    const subcollectionDocuments = {};
    for (const collection of Object.keys(A05_SUBCOLLECTION_REGISTRY)) {
      const snapshot = await db.collectionGroup(collection).get();
      subcollectionDocuments[collection] = snapshot.docs.map((document) => ({
        path: document.ref.path,
      }));
    }
    const dartReconciliationResults = await reconcileA05DocumentsWithDart({
      documentsByCollection,
      hmacKey,
    });
    const inventory = classifyA05Inventory({
      documentsByCollection,
      actualRootCollections,
      subcollectionDocuments,
      hmacKey,
      dartReconciliationResults,
    });
    const result = {
      schemaVersion: 1,
      evidenceType: 'A05_READ_ONLY_PRODUCTION_PERSISTED_INTEGRITY',
      readOnly: true,
      cloudMutationCapability: 'NONE',
      startedAt,
      completedAt: new Date().toISOString(),
      project: {
        projectId: args.project,
        production: args.project === PRODUCTION_PROJECT,
        exactProductionConfirmation: args.confirmProject ?? null,
        firestoreEmulator: process.env.FIRESTORE_EMULATOR_HOST ?? null,
      },
      sourceAuthority,
      registry: {
        rootCollections: sortedObject(A05_COLLECTION_REGISTRY),
        subcollectionGroups: sortedObject(A05_SUBCOLLECTION_REGISTRY),
        rulesRootCollections: rulesRootCollections(rulesSource),
        uncoveredRulesCollections,
        sourceDefinedCollections: sourceCollectionNames,
        uncoveredSourceCollections,
      },
      privacy: {
        subjectIdentifier: 'HMAC_SHA256',
        rawIdentifiersEmitted: false,
        rawDocumentDataEmitted: false,
        hmacKeyEnvironmentVariable: args.hmacKeyEnv,
      },
      reconciliation: {
        adapter: 'tools/v4/a05_persisted_reconciliation_bridge.dart',
        transport: 'AUTHENTICATED_LOOPBACK_MEMORY_ONLY',
        rawProductionDataPersisted: false,
        attemptedCount: dartReconciliationResults.length,
        passedCount: dartReconciliationResults.filter(
          (result) => result.result === 'PASS',
        ).length,
        failedCount: dartReconciliationResults.filter(
          (result) => result.result !== 'PASS',
        ).length,
        supportedCollections: [...DART_RECONCILIATION_COLLECTIONS].sort(),
      },
      ...inventory,
    };
    const evidence = writeEvidence(args.output, result);
    console.log(
      `${result.decision}: blockers=${result.blockingFindingCount}; ` +
      `output=${evidence.resolved}; sha256=${evidence.digest}`,
    );
    process.exitCode = result.decision === A05_DECISIONS.pass ? 0 : 2;
  } finally {
    await app.delete();
  }
}

if (
  import.meta.url === `file://${process.argv[1]}` ||
  fileURLToPath(import.meta.url) === path.resolve(process.argv[1] ?? '')
) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
