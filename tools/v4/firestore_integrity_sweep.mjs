#!/usr/bin/env node
/**
 * Read-only Firestore integrity sweep for CRM3 v4.2_R1.
 *
 * The sweep deliberately performs collection-wide reads without orderBy so
 * malformed/missing ordered fields cannot disappear before validation.
 * It never writes, deletes, imports, exports, deploys, or changes indexes.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const ROLE_SET = new Set([
  'admin', 'si', 'contractSupervisor', 'shiftSupervisor',
  'seniorElectrical', 'seniorMechanical', 'seniorInstrumentation',
  'seniorRefractory', 'refractory', 'operations',
]);
const USER_KEYS = new Set([
  'name', 'email', 'photoUrl', 'roles', 'isApproved', 'fcmToken', 'createdAt',
]);

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--project') out.project = argv[++i];
    else if (arg === '--output') out.output = argv[++i];
    else if (arg === '--allow-production-read-only') out.allowProduction = true;
    else if (arg === '--confirm-project') out.confirmProject = argv[++i];
    else if (arg === '--help') out.help = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
}

function isTimestamp(value) {
  return value != null && typeof value.toDate === 'function' && Number.isFinite(value.toMillis?.());
}
function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}
function isSafeInteger(value) {
  return Number.isSafeInteger(value);
}
function finding(collection, id, field, reason, actual = null) {
  return {collection, id, field, reason, actualType: actual == null ? String(actual) : typeof actual};
}

export function validateUserDocument(id, data) {
  const findings = [];
  for (const key of Object.keys(data)) {
    if (!USER_KEYS.has(key)) findings.push(finding('users', id, key, 'unexpected-top-level-field', data[key]));
  }
  for (const key of ['name', 'email', 'roles', 'isApproved', 'createdAt']) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) findings.push(finding('users', id, key, 'required-field-missing'));
  }
  if (!isNonEmptyString(data.name)) findings.push(finding('users', id, 'name', 'invalid-required-string', data.name));
  if (!isNonEmptyString(data.email)) findings.push(finding('users', id, 'email', 'invalid-required-string', data.email));
  if (data.photoUrl != null && typeof data.photoUrl !== 'string') findings.push(finding('users', id, 'photoUrl', 'invalid-optional-string', data.photoUrl));
  if (data.fcmToken != null && typeof data.fcmToken !== 'string') findings.push(finding('users', id, 'fcmToken', 'invalid-optional-string', data.fcmToken));
  if (data.isApproved !== true && data.isApproved !== false) findings.push(finding('users', id, 'isApproved', 'invalid-boolean', data.isApproved));
  if (!Array.isArray(data.roles) || data.roles.length === 0) {
    findings.push(finding('users', id, 'roles', 'invalid-nonempty-role-list', data.roles));
  } else {
    for (const role of data.roles) {
      if (typeof role !== 'string' || !ROLE_SET.has(role)) findings.push(finding('users', id, 'roles', 'unknown-or-malformed-role', role));
    }
  }
  if (!isTimestamp(data.createdAt)) findings.push(finding('users', id, 'createdAt', 'invalid-firestore-timestamp', data.createdAt));
  return findings;
}

const COLLECTION_CONTRACTS = {
  maintenance_workflows: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  job_lanes: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'laneKey', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  compliance_requests: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'laneKey', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  compliance_attempts: {
    strings: ['firestoreId', 'complianceRequestFirestoreId'],
    integers: ['attemptNumber'],
    timestamps: ['createdAt'],
  },
  equipment_status: {
    strings: ['firestoreId', 'assetTypeKey', 'state'],
    integers: ['assetNumber', 'version'],
    timestamps: ['updatedAt'],
  },
  workflow_commands: {
    strings: ['commandId', 'commandType', 'aggregateId'],
    integers: ['expectedVersion'],
    timestamps: ['createdAt'],
  },
  workflow_command_receipts: {
    strings: ['commandId', 'aggregateId'],
    timestamps: ['appliedAt'],
  },
  workflow_events: {
    strings: ['firestoreId', 'aggregateId', 'eventType'],
    timestamps: ['timestamp'],
  },
};

export function validateContractDocument(collection, id, data, contract) {
  const findings = [];
  for (const field of contract.strings ?? []) {
    if (!isNonEmptyString(data[field])) findings.push(finding(collection, id, field, 'invalid-required-string', data[field]));
  }
  for (const field of contract.integers ?? []) {
    if (!isSafeInteger(data[field])) findings.push(finding(collection, id, field, 'invalid-required-integer', data[field]));
  }
  for (const field of contract.timestamps ?? []) {
    if (!isTimestamp(data[field])) findings.push(finding(collection, id, field, 'invalid-firestore-timestamp', data[field]));
  }
  return findings;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('Usage: node tools/v4/firestore_integrity_sweep.mjs --project <id> --output <file> [--allow-production-read-only --confirm-project <id>]');
    return;
  }
  const projectId = args.project || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) throw new Error('A Firebase project ID is required.');
  if (!args.output) throw new Error('--output is required.');
  if (projectId === PRODUCTION_PROJECT && (!args.allowProduction || args.confirmProject !== PRODUCTION_PROJECT)) {
    throw new Error('Production project read is refused unless both --allow-production-read-only and exact --confirm-project are supplied.');
  }

  const require = createRequire(import.meta.url);
  const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));
  if (admin.apps.length === 0) admin.initializeApp({projectId});
  const db = admin.firestore();
  const collections = ['users', ...Object.keys(COLLECTION_CONTRACTS)];
  const result = {
    schemaVersion: 1,
    projectId,
    emulatorHost: process.env.FIRESTORE_EMULATOR_HOST || null,
    readOnly: true,
    startedAt: new Date().toISOString(),
    collectionCounts: {},
    findings: [],
  };

  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    result.collectionCounts[collection] = snapshot.size;
    for (const doc of snapshot.docs) {
      const data = doc.data() ?? {};
      const findings = collection === 'users'
        ? validateUserDocument(doc.id, data)
        : validateContractDocument(collection, doc.id, data, COLLECTION_CONTRACTS[collection]);
      result.findings.push(...findings);
    }
  }
  result.completedAt = new Date().toISOString();
  result.findingCount = result.findings.length;
  result.status = result.findingCount === 0 ? 'PASS_READ_ONLY_INTEGRITY_SWEEP' : 'HOLD_MALFORMED_DOCUMENTS_FOUND';
  fs.mkdirSync(path.dirname(path.resolve(args.output)), {recursive: true});
  fs.writeFileSync(path.resolve(args.output), `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  console.log(`${result.status}: findings=${result.findingCount}; output=${path.resolve(args.output)}`);
  process.exitCode = result.findingCount === 0 ? 0 : 2;
}

if (import.meta.url === `file://${process.argv[1]}` || fileURLToPath(import.meta.url) === path.resolve(process.argv[1] ?? '')) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
