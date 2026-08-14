#!/usr/bin/env node
/**
 * Reconciles legacy governed-custom workflow projections before schema-v5
 * clients require class-scoped physical asset identity.
 *
 * The default mode is read-only. Production writes require an exact clean
 * main commit, explicit project and mutation confirmations, and an
 * environment token bound to that commit.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const WRITE_CONFIRMATION = 'RECONCILE_GOVERNED_CUSTOM_PROJECTIONS';
const WRITE_TOKEN_ENV = 'CRM3_GOVERNED_ASSET_IDENTITY_WRITE_TOKEN';
const SERVER_TIMESTAMP = '$SERVER_TIMESTAMP';
const MAX_ENTITY_MUTATIONS = 200;
const IGNORED_UNTRACKED_PREFIXES = Object.freeze([
  'output/',
  'outputs/',
  'preview-governed-hierarchy/',
  'tmp/',
]);
const TERMINAL_WORKFLOW_STATUSES = new Set(['completed', 'cancelled']);
const WORKFLOW_STATUSES = new Set([
  'pendingLaneClassification',
  'assigned',
  'partiallyAcknowledged',
  'fullyAcknowledged',
  'inProgress',
  'awaitingCompliance',
  'readyForClosure',
  'completed',
  'cancelled',
]);
const EQUIPMENT_STATES = new Set([
  'available',
  'inService',
  'underMaintenance',
  'underRED',
  'awaitingPreparation',
]);

class ReconciliationEvidenceError extends Error {
  constructor(code, detail) {
    super(detail);
    this.name = 'ReconciliationEvidenceError';
    this.code = code;
  }
}

function objectValue(value, label) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new ReconciliationEvidenceError(
      'malformed-object',
      `${label} must be an object.`,
    );
  }
  return value;
}

function nonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ReconciliationEvidenceError(
      'missing-string',
      `${label} must be a non-empty string.`,
    );
  }
  return value.trim();
}

function optionalString(value, label) {
  if (value == null) return null;
  return nonEmptyString(value, label);
}

function documentId(value, label) {
  const result = nonEmptyString(value, label);
  if (result === '.' || result === '..' || result.includes('/') || result.length > 512) {
    throw new ReconciliationEvidenceError(
      'invalid-document-id',
      `${label} is not a valid Firestore document ID.`,
    );
  }
  return result;
}

function positiveInteger(value, label) {
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new ReconciliationEvidenceError(
      'invalid-positive-integer',
      `${label} must be a positive integer.`,
    );
  }
  return value;
}

function nonNegativeInteger(value, label) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new ReconciliationEvidenceError(
      'invalid-counter',
      `${label} must be a non-negative integer.`,
    );
  }
  return value;
}

function integer(value, label, minimum = null) {
  if (!Number.isSafeInteger(value) || (minimum != null && value < minimum)) {
    throw new ReconciliationEvidenceError(
      'invalid-integer',
      `${label} must be an integer${minimum == null ? '' : ` of at least ${minimum}`}.`,
    );
  }
  return value;
}

function optionalBoolean(value, label) {
  if (value != null && typeof value !== 'boolean') {
    throw new ReconciliationEvidenceError(
      'invalid-boolean',
      `${label} must be a boolean when present.`,
    );
  }
}

function optionalNonEmptyString(value, label) {
  if (value != null) nonEmptyString(value, label);
}

function persistedTimestamp(value, label, optional = false) {
  if (value == null && optional) return;
  const valid =
    (typeof value === 'string' && Number.isFinite(Date.parse(value))) ||
    value instanceof Date ||
    (value != null && typeof value.toMillis === 'function' &&
      Number.isFinite(value.toMillis()));
  if (!valid) {
    throw new ReconciliationEvidenceError(
      'invalid-timestamp',
      `${label} must be a persisted timestamp.`,
    );
  }
}

function parseJsonObject(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ReconciliationEvidenceError(
      'missing-json-evidence',
      `${label} must contain JSON object evidence.`,
    );
  }
  try {
    return objectValue(JSON.parse(value), label);
  } catch (error) {
    if (error instanceof ReconciliationEvidenceError) throw error;
    throw new ReconciliationEvidenceError(
      'malformed-json-evidence',
      `${label} is not valid JSON object evidence.`,
    );
  }
}

function canonicalValue(value) {
  if (value == null || typeof value === 'string' || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('Non-finite numbers are unsupported.');
    return value;
  }
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (typeof value.toMillis === 'function') {
    return {$timestampMillis: value.toMillis()};
  }
  if (typeof value.path === 'string' && value.constructor?.name === 'DocumentReference') {
    return {$documentReference: value.path};
  }
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalValue(value[key])]),
    );
  }
  throw new Error(`Unsupported canonical value type: ${typeof value}`);
}

function stableJson(value) {
  return JSON.stringify(canonicalValue(value));
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function sourceHash(data) {
  return data == null ? null : `sha256:${sha256(stableJson(data))}`;
}

function rowPath(collection, id) {
  return `${collection}/${id}`;
}

function normalizeRows(rows, collection, blockers) {
  const byId = new Map();
  for (const raw of rows ?? []) {
    try {
      const row = objectValue(raw, `${collection} row`);
      const id = documentId(row.id, `${collection} row ID`);
      if (byId.has(id)) {
        blockers.push({
          code: 'duplicate-row-id',
          path: rowPath(collection, id),
          detail: 'The input contains the same document twice.',
        });
        continue;
      }
      byId.set(id, {id, data: objectValue(row.data, rowPath(collection, id))});
    } catch (error) {
      blockers.push({
        code: error.code ?? 'malformed-row',
        path: collection,
        detail: error.message,
      });
    }
  }
  return byId;
}

function identityKey(identity) {
  return `${identity.assetClassId}\u0000${identity.assetInstanceId}`;
}

function canonicalEquipmentId(identity) {
  return `governedCustom_${identity.assetClassId}_${identity.assetInstanceId}`;
}

function registryIdentity(row, expected = {}) {
  const data = row.data;
  const assetInstanceId = documentId(
    data.assetInstanceId,
    `${rowPath('asset_instances', row.id)}.assetInstanceId`,
  );
  const assetClassId = documentId(
    data.assetClassId,
    `${rowPath('asset_instances', row.id)}.assetClassId`,
  );
  const assetNumber = positiveInteger(
    data.assetNumber,
    `${rowPath('asset_instances', row.id)}.assetNumber`,
  );
  if (row.id !== assetInstanceId) {
    throw new ReconciliationEvidenceError(
      'registry-document-identity-mismatch',
      `Asset instance ${row.id} does not match its stored identity.`,
    );
  }
  if (expected.assetClassId != null && assetClassId !== expected.assetClassId) {
    throw new ReconciliationEvidenceError(
      'registry-class-mismatch',
      `Asset instance ${row.id} belongs to another asset class.`,
    );
  }
  if (expected.assetNumber != null && assetNumber !== expected.assetNumber) {
    throw new ReconciliationEvidenceError(
      'registry-number-mismatch',
      `Asset instance ${row.id} has another asset number.`,
    );
  }
  return {assetClassId, assetInstanceId, assetNumber};
}

function exactRegistryIdentity({assetRows, assetClassId, assetInstanceId, assetNumber}) {
  if (assetInstanceId != null) {
    const row = assetRows.get(assetInstanceId);
    if (row == null) {
      throw new ReconciliationEvidenceError(
        'asset-instance-not-found',
        `Referenced asset instance ${assetInstanceId} does not exist.`,
      );
    }
    return registryIdentity(row, {assetClassId, assetNumber});
  }

  const matches = [];
  for (const row of assetRows.values()) {
    try {
      const identity = registryIdentity(row);
      if (identity.assetClassId === assetClassId && identity.assetNumber === assetNumber) {
        matches.push(identity);
      }
    } catch {
      // A malformed registry row is not admissible identity evidence.
    }
  }
  if (matches.length !== 1) {
    throw new ReconciliationEvidenceError(
      matches.length === 0 ? 'asset-instance-not-found' : 'asset-instance-ambiguous',
      `Expected exactly one registry match for class ${assetClassId}, asset ${assetNumber}; found ${matches.length}.`,
    );
  }
  return matches[0];
}

function hierarchyEvidence(execution, workflow) {
  const pathLabel = rowPath('job_executions', execution.id);
  if (execution.data.assetType != null && execution.data.assetType !== 'governedCustom') {
    throw new ReconciliationEvidenceError(
      'execution-asset-type-mismatch',
      `${pathLabel} does not describe a governed custom asset.`,
    );
  }
  if (execution.data.assetNumber != null &&
      execution.data.assetNumber !== workflow.data.assetNumber) {
    throw new ReconciliationEvidenceError(
      'execution-asset-number-mismatch',
      `${pathLabel} has another asset number.`,
    );
  }
  const metadata = parseJsonObject(execution.data.metadataJson, `${pathLabel}.metadataJson`);
  const snapshot = objectValue(
    metadata.jobTemplateSnapshot,
    `${pathLabel}.metadataJson.jobTemplateSnapshot`,
  );
  const reference = parseJsonObject(
    snapshot.assetHierarchyRefJson,
    `${pathLabel}.metadataJson.jobTemplateSnapshot.assetHierarchyRefJson`,
  );
  const schemaVersion = positiveInteger(
    reference.schemaVersion,
    `${pathLabel} hierarchy schemaVersion`,
  );
  if (schemaVersion !== 1 && schemaVersion !== 2) {
    throw new ReconciliationEvidenceError(
      'unsupported-hierarchy-reference',
      `${pathLabel} uses unsupported hierarchy reference schema ${schemaVersion}.`,
    );
  }
  const scope = schemaVersion === 1 ? 'definition' : reference.scope;
  if (scope !== 'definition' && scope !== 'installedComponent') {
    throw new ReconciliationEvidenceError(
      'unsupported-hierarchy-scope',
      `${pathLabel} has unsupported hierarchy scope.`,
    );
  }
  const assetClassId = documentId(reference.assetClassId, `${pathLabel} assetClassId`);
  const assetInstanceId = optionalString(reference.assetInstanceId, `${pathLabel} assetInstanceId`);
  const referencedNumber = reference.assetNumber == null
    ? null
    : positiveInteger(reference.assetNumber, `${pathLabel} hierarchy assetNumber`);
  if (referencedNumber != null && referencedNumber !== workflow.data.assetNumber) {
    throw new ReconciliationEvidenceError(
      'hierarchy-asset-number-mismatch',
      `${pathLabel} hierarchy evidence has another asset number.`,
    );
  }
  if (scope === 'installedComponent' && assetInstanceId == null) {
    throw new ReconciliationEvidenceError(
      'installed-reference-missing-asset',
      `${pathLabel} installed-component evidence has no physical asset identity.`,
    );
  }
  return {
    assetClassId,
    assetInstanceId: assetInstanceId == null
      ? null
      : documentId(assetInstanceId, `${pathLabel} assetInstanceId`),
  };
}

function workflowFacts(workflows) {
  let activeNonRedMaintenanceCount = 0;
  let activeRedWorkCount = 0;
  let awaitingPreparationCount = 0;
  for (const workflow of workflows) {
    const data = workflow.data;
    if (TERMINAL_WORKFLOW_STATUSES.has(data.status) || data.cancelled === true) continue;
    if (data.activeRedWork === true) activeRedWorkCount += 1;
    else if (data.awaitingPreparation === true) awaitingPreparationCount += 1;
    else activeNonRedMaintenanceCount += 1;
  }
  return {
    activeNonRedMaintenanceCount,
    activeRedWorkCount,
    awaitingPreparationCount,
  };
}

function validateWorkflowProjection(row) {
  const label = rowPath('maintenance_workflows', row.id);
  documentId(row.data.jobExecutionId, `${label}.jobExecutionId`);
  positiveInteger(row.data.assetNumber, `${label}.assetNumber`);
  const status = nonEmptyString(row.data.status, `${label}.status`);
  if (!WORKFLOW_STATUSES.has(status)) {
    throw new ReconciliationEvidenceError(
      'invalid-workflow-status',
      `${label} has an unsupported workflow status.`,
    );
  }
  integer(row.data.workflowSchemaVersion, `${label}.workflowSchemaVersion`, 1);
  integer(row.data.version, `${label}.version`);
  integer(row.data.laneSetVersion, `${label}.laneSetVersion`);
  optionalBoolean(row.data.activeRedWork, `${label}.activeRedWork`);
  optionalBoolean(row.data.awaitingPreparation, `${label}.awaitingPreparation`);
  optionalBoolean(row.data.cancelled, `${label}.cancelled`);
  persistedTimestamp(row.data.createdAt, `${label}.createdAt`);
  persistedTimestamp(row.data.updatedAt, `${label}.updatedAt`);
  persistedTimestamp(row.data.completedAt, `${label}.completedAt`, true);
  persistedTimestamp(row.data.laneSetFinalizedAt, `${label}.laneSetFinalizedAt`, true);
  optionalNonEmptyString(row.data.laneSetFinalizedByUid, `${label}.laneSetFinalizedByUid`);
  optionalNonEmptyString(row.data.laneSetFinalizedByName, `${label}.laneSetFinalizedByName`);
}

function equipmentState(facts, zeroState = 'inService') {
  if (facts.activeRedWorkCount > 0) return 'underRED';
  if (facts.awaitingPreparationCount > 0) return 'awaitingPreparation';
  if (facts.activeNonRedMaintenanceCount > 0) return 'underMaintenance';
  return zeroState === 'available' || zeroState === 'inService'
    ? zeroState
    : 'inService';
}

function sameFacts(data, facts) {
  return data.activeNonRedMaintenanceCount === facts.activeNonRedMaintenanceCount &&
    data.activeRedWorkCount === facts.activeRedWorkCount &&
    data.awaitingPreparationCount === facts.awaitingPreparationCount;
}

function validateLegacyEquipment(row, facts) {
  const label = rowPath('equipment_status', row.id);
  if (row.id !== `governedCustom_${positiveInteger(dataValue(row, 'assetNumber'), `${label}.assetNumber`)}`) {
    throw new ReconciliationEvidenceError(
      'legacy-equipment-document-id-mismatch',
      `${label} is not the canonical legacy projection ID.`,
    );
  }
  positiveInteger(dataValue(row, 'version'), `${label}.version`);
  nonNegativeInteger(dataValue(row, 'activeNonRedMaintenanceCount'), `${label}.activeNonRedMaintenanceCount`);
  nonNegativeInteger(dataValue(row, 'activeRedWorkCount'), `${label}.activeRedWorkCount`);
  nonNegativeInteger(dataValue(row, 'awaitingPreparationCount'), `${label}.awaitingPreparationCount`);
  const state = nonEmptyString(dataValue(row, 'state'), `${label}.state`);
  const previousState = nonEmptyString(
    dataValue(row, 'previousState'),
    `${label}.previousState`,
  );
  if (!EQUIPMENT_STATES.has(state)) {
    throw new ReconciliationEvidenceError('invalid-equipment-state', `${label} has an invalid state.`);
  }
  if (!EQUIPMENT_STATES.has(previousState)) {
    throw new ReconciliationEvidenceError(
      'invalid-equipment-state',
      `${label} has an invalid previous state.`,
    );
  }
  persistedTimestamp(row.data.updatedAt, `${label}.updatedAt`);
  persistedTimestamp(row.data.lastTransitionAt, `${label}.lastTransitionAt`, true);
  optionalNonEmptyString(row.data.transitionTrigger, `${label}.transitionTrigger`);
  optionalNonEmptyString(row.data.lastTransitionByUid, `${label}.lastTransitionByUid`);
  optionalNonEmptyString(row.data.lastTransitionByName, `${label}.lastTransitionByName`);
  if (!sameFacts(row.data, facts) || equipmentState(facts, state) !== state) {
    throw new ReconciliationEvidenceError(
      'legacy-equipment-facts-mismatch',
      `${label} does not match the complete workflow facts for its legacy number.`,
    );
  }
}

function dataValue(row, field) {
  return row.data[field];
}

function mutation(operation, collection, row, data = null) {
  return {
    operation,
    path: rowPath(collection, row.id),
    expectedSourceHash: sourceHash(row.data),
    data,
  };
}

function sortMutations(values) {
  return values.sort((left, right) => left.path.localeCompare(right.path));
}

export function buildReconciliationPlan(input) {
  const blockers = [];
  const workflowRows = normalizeRows(input.maintenanceWorkflows, 'maintenance_workflows', blockers);
  const executionRows = normalizeRows(input.jobExecutions, 'job_executions', blockers);
  const assetRows = normalizeRows(input.assetInstances, 'asset_instances', blockers);
  const equipmentRows = normalizeRows(input.equipmentStatus, 'equipment_status', blockers);
  const resolvedWorkflows = new Map();
  const workflowUpdates = [];
  const executionUpdates = [];
  const executionOwnerWorkflow = new Map();

  for (const workflow of workflowRows.values()) {
    if (workflow.data.assetTypeKey !== 'governedCustom') continue;
    try {
      validateWorkflowProjection(workflow);
      const assetNumber = positiveInteger(
        workflow.data.assetNumber,
        `${rowPath('maintenance_workflows', workflow.id)}.assetNumber`,
      );
      const storedClassId = optionalString(workflow.data.assetClassId, 'workflow assetClassId');
      const storedInstanceId = optionalString(workflow.data.assetInstanceId, 'workflow assetInstanceId');
      if ((storedClassId == null) !== (storedInstanceId == null)) {
        throw new ReconciliationEvidenceError(
          'partial-workflow-identity',
          'A governed custom workflow contains only one identity field.',
        );
      }
      const jobExecutionId = documentId(
        workflow.data.jobExecutionId,
        `${rowPath('maintenance_workflows', workflow.id)}.jobExecutionId`,
      );
      const execution = executionRows.get(jobExecutionId);
      if (execution == null) {
        throw new ReconciliationEvidenceError(
          'job-execution-not-found',
          `Linked job execution ${jobExecutionId} does not exist.`,
        );
      }
      const existingExecutionOwner = executionOwnerWorkflow.get(jobExecutionId);
      if (existingExecutionOwner != null && existingExecutionOwner !== workflow.id) {
        throw new ReconciliationEvidenceError(
          'job-execution-linked-by-several-workflows',
          `Job execution ${jobExecutionId} is linked by several workflows.`,
        );
      }
      executionOwnerWorkflow.set(jobExecutionId, workflow.id);

      let identity;
      if (storedClassId != null) {
        identity = exactRegistryIdentity({
          assetRows,
          assetClassId: documentId(storedClassId, 'workflow assetClassId'),
          assetInstanceId: documentId(storedInstanceId, 'workflow assetInstanceId'),
          assetNumber,
        });
      } else {
        const evidence = hierarchyEvidence(execution, workflow);
        identity = exactRegistryIdentity({assetRows, ...evidence, assetNumber});
        workflowUpdates.push(mutation(
          'update',
          'maintenance_workflows',
          workflow,
          {
            assetClassId: identity.assetClassId,
            assetInstanceId: identity.assetInstanceId,
            identityMigrationVersion: 1,
            identityMigratedAt: SERVER_TIMESTAMP,
            version: positiveInteger(workflow.data.version, 'workflow version') + 1,
            updatedAt: SERVER_TIMESTAMP,
          },
        ));
      }
      resolvedWorkflows.set(workflow.id, {row: workflow, identity});

      const executionClassId = optionalString(execution.data.assetClassId, 'execution assetClassId');
      const executionInstanceId = optionalString(execution.data.assetInstanceId, 'execution assetInstanceId');
      if ((executionClassId == null) !== (executionInstanceId == null)) {
        throw new ReconciliationEvidenceError(
          'partial-execution-identity',
          'The linked job execution contains only one identity field.',
        );
      }
      if (executionClassId != null &&
          (executionClassId !== identity.assetClassId ||
           executionInstanceId !== identity.assetInstanceId)) {
        throw new ReconciliationEvidenceError(
          'execution-identity-mismatch',
          'The linked job execution identifies another physical asset.',
        );
      }
      if (executionClassId == null) {
        executionUpdates.push(mutation(
          'update',
          'job_executions',
          execution,
          {
            assetClassId: identity.assetClassId,
            assetInstanceId: identity.assetInstanceId,
            identityMigrationVersion: 1,
            identityMigratedAt: SERVER_TIMESTAMP,
            updatedAt: SERVER_TIMESTAMP,
          },
        ));
      }
    } catch (error) {
      blockers.push({
        code: error.code ?? 'workflow-identity-unresolved',
        path: rowPath('maintenance_workflows', workflow.id),
        detail: error.message,
      });
    }
  }

  const workflowsByIdentity = new Map();
  for (const resolved of resolvedWorkflows.values()) {
    const key = identityKey(resolved.identity);
    const group = workflowsByIdentity.get(key) ?? {
      identity: resolved.identity,
      workflows: [],
    };
    group.workflows.push(resolved.row);
    workflowsByIdentity.set(key, group);
  }

  const currentEquipmentByIdentity = new Map();
  const legacyEquipment = [];
  for (const row of equipmentRows.values()) {
    if (row.data.assetTypeKey !== 'governedCustom') continue;
    try {
      const assetClassId = optionalString(row.data.assetClassId, 'equipment assetClassId');
      const assetInstanceId = optionalString(row.data.assetInstanceId, 'equipment assetInstanceId');
      if ((assetClassId == null) !== (assetInstanceId == null)) {
        throw new ReconciliationEvidenceError(
          'partial-equipment-identity',
          'A governed custom equipment projection contains only one identity field.',
        );
      }
      if (assetClassId == null) {
        legacyEquipment.push(row);
        continue;
      }
      const identity = exactRegistryIdentity({
        assetRows,
        assetClassId: documentId(assetClassId, 'equipment assetClassId'),
        assetInstanceId: documentId(assetInstanceId, 'equipment assetInstanceId'),
        assetNumber: positiveInteger(row.data.assetNumber, 'equipment assetNumber'),
      });
      if (row.id !== canonicalEquipmentId(identity)) {
        throw new ReconciliationEvidenceError(
          'equipment-document-identity-mismatch',
          'A current custom equipment projection is stored under the wrong document ID.',
        );
      }
      const key = identityKey(identity);
      if (currentEquipmentByIdentity.has(key)) {
        throw new ReconciliationEvidenceError(
          'duplicate-equipment-identity',
          'More than one current equipment projection represents this physical asset.',
        );
      }
      currentEquipmentByIdentity.set(key, {row, identity});
    } catch (error) {
      blockers.push({
        code: error.code ?? 'equipment-identity-invalid',
        path: rowPath('equipment_status', row.id),
        detail: error.message,
      });
    }
  }

  const legacySourceByIdentity = new Map();
  for (const legacy of legacyEquipment) {
    try {
      const assetNumber = positiveInteger(legacy.data.assetNumber, 'legacy equipment assetNumber');
      let groups = [...workflowsByIdentity.values()].filter(
        (group) => group.identity.assetNumber === assetNumber,
      );
      if (groups.length === 0) {
        const identities = [];
        for (const asset of assetRows.values()) {
          try {
            const identity = registryIdentity(asset);
            if (identity.assetNumber === assetNumber) identities.push(identity);
          } catch {
            // Invalid registry rows cannot supply migration evidence.
          }
        }
        if (identities.length !== 1) {
          throw new ReconciliationEvidenceError(
            identities.length === 0
              ? 'legacy-equipment-identity-not-found'
              : 'legacy-equipment-identity-ambiguous',
            `Legacy equipment ${legacy.id} maps to ${identities.length} registry assets.`,
          );
        }
        groups = [{identity: identities[0], workflows: []}];
        workflowsByIdentity.set(identityKey(identities[0]), groups[0]);
      }
      const aggregateFacts = workflowFacts(groups.flatMap((group) => group.workflows));
      validateLegacyEquipment(legacy, aggregateFacts);
      for (const group of groups) {
        const key = identityKey(group.identity);
        if (legacySourceByIdentity.has(key)) {
          throw new ReconciliationEvidenceError(
            'duplicate-legacy-equipment-source',
            'More than one legacy projection maps to the same physical asset.',
          );
        }
        legacySourceByIdentity.set(key, legacy);
      }
    } catch (error) {
      blockers.push({
        code: error.code ?? 'legacy-equipment-unresolved',
        path: rowPath('equipment_status', legacy.id),
        detail: error.message,
      });
    }
  }

  const equipmentUpserts = [];
  for (const [key, group] of workflowsByIdentity) {
    const facts = workflowFacts(group.workflows);
    const current = currentEquipmentByIdentity.get(key);
    const legacy = legacySourceByIdentity.get(key);
    if (current != null) {
      try {
        const label = rowPath('equipment_status', current.row.id);
        try {
          validateLegacyEquipment(
            {
              ...current.row,
              id: `governedCustom_${current.row.data.assetNumber}`,
            },
            facts,
          );
        } catch (error) {
          if (error.code === 'legacy-equipment-facts-mismatch') {
            throw new ReconciliationEvidenceError(
              'current-equipment-facts-mismatch',
              `${label} does not match the complete workflow facts.`,
            );
          }
          throw error;
        }
        const state = nonEmptyString(current.row.data.state, `${label}.state`);
        if (!sameFacts(current.row.data, facts) || equipmentState(facts, state) !== state) {
          throw new ReconciliationEvidenceError(
            'current-equipment-facts-mismatch',
            `${label} does not match the complete workflow facts.`,
          );
        }
      } catch (error) {
        blockers.push({
          code: error.code ?? 'current-equipment-invalid',
          path: rowPath('equipment_status', current.row.id),
          detail: error.message,
        });
      }
      continue;
    }
    const zeroState = legacy?.data.state;
    const state = equipmentState(facts, zeroState);
    const version = legacy == null
      ? 1
      : positiveInteger(legacy.data.version, 'legacy equipment version') + 1;
    const targetId = canonicalEquipmentId(group.identity);
    equipmentUpserts.push({
      operation: 'create',
      path: rowPath('equipment_status', targetId),
      expectedSourceHash: null,
      data: {
        assetTypeKey: 'governedCustom',
        assetNumber: group.identity.assetNumber,
        assetClassId: group.identity.assetClassId,
        assetInstanceId: group.identity.assetInstanceId,
        previousState: EQUIPMENT_STATES.has(legacy?.data.state)
          ? legacy.data.state
          : 'inService',
        state,
        ...facts,
        transitionTrigger: 'governedAssetIdentityMigration:v1',
        lastTransitionAt: SERVER_TIMESTAMP,
        lastTransitionByUid: 'system:governed-asset-identity-migration',
        lastTransitionByName: 'Governed asset identity migration',
        availableSince: state === 'available' ? SERVER_TIMESTAMP : null,
        inServiceSince: state === 'inService' ? SERVER_TIMESTAMP : null,
        identityMigrationVersion: 1,
        version,
        updatedAt: SERVER_TIMESTAMP,
      },
    });
  }

  const equipmentDeletes = legacyEquipment.map((row) =>
    mutation('delete', 'equipment_status', row));
  const mutations = sortMutations([
    ...workflowUpdates,
    ...executionUpdates,
    ...equipmentUpserts,
    ...equipmentDeletes,
  ]);
  if (mutations.length > MAX_ENTITY_MUTATIONS) {
    blockers.push({
      code: 'mutation-budget-exceeded',
      path: 'migration',
      detail: `The plan contains ${mutations.length} entity mutations; the governed limit is ${MAX_ENTITY_MUTATIONS}.`,
    });
  }
  blockers.sort((left, right) =>
    `${left.path}|${left.code}`.localeCompare(`${right.path}|${right.code}`));
  const planCore = {
    schemaVersion: 1,
    blockers,
    mutations,
    inventory: {
      governedCustomWorkflowCount: [...resolvedWorkflows.values()].length,
      legacyWorkflowUpdateCount: workflowUpdates.length,
      executionUpdateCount: executionUpdates.length,
      legacyEquipmentDeleteCount: equipmentDeletes.length,
      equipmentCreateCount: equipmentUpserts.length,
    },
  };
  return {
    ...planCore,
    decision: blockers.length === 0
      ? (mutations.length === 0 ? 'CLEAN' : 'READY_TO_RECONCILE')
      : 'HOLD_AMBIGUOUS_OR_MALFORMED_EVIDENCE',
    planHash: `sha256:${sha256(stableJson(planCore))}`,
  };
}

function requiredArg(argv, index, name) {
  const value = argv[index + 1];
  if (value == null || value.startsWith('--')) {
    throw new Error(`${name} requires a value.`);
  }
  return value;
}

export function parseArgs(argv) {
  const args = {mode: 'dry-run'};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (['--project', '--output', '--confirm-project', '--expected-source-commit',
      '--expected-source-tree', '--mode', '--confirm-mutation'].includes(arg)) {
      const key = arg.slice(2).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
      args[key] = requiredArg(argv, i, arg);
      i += 1;
    } else if (arg === '--allow-production-read-only') {
      args.allowProductionReadOnly = true;
    } else if (arg === '--allow-production-write') {
      args.allowProductionWrite = true;
    } else if (arg === '--help') {
      args.help = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (!['dry-run', 'apply'].includes(args.mode)) {
    throw new Error('--mode must be dry-run or apply.');
  }
  return args;
}

function gitOutput(args) {
  return execFileSync('git', args, {cwd: ROOT, encoding: 'utf8'}).trim();
}

export function readGitSourceAuthority() {
  const statusLines = gitOutput(['status', '--porcelain=v1', '--untracked-files=all'])
    .split(/\r?\n/)
    .filter(Boolean)
    .filter((line) => {
      const relative = line.slice(3).replaceAll('\\', '/');
      return !IGNORED_UNTRACKED_PREFIXES.some((prefix) => relative.startsWith(prefix));
    });
  let originMainCommit = null;
  try {
    originMainCommit = gitOutput(['rev-parse', 'origin/main']);
  } catch {
    // Production write custody rejects an unavailable origin/main authority.
  }
  return {
    commit: gitOutput(['rev-parse', 'HEAD']),
    tree: gitOutput(['rev-parse', 'HEAD^{tree}']),
    branch: gitOutput(['branch', '--show-current']),
    originMainCommit,
    cleanWorktree: statusLines.length === 0,
    unexpectedChanges: statusLines,
  };
}

export function assertCustody(args, env, source) {
  if (args.project == null || args.output == null) {
    throw new Error('--project and --output are required.');
  }
  if (args.expectedSourceCommit !== source.commit || args.expectedSourceTree !== source.tree) {
    throw new Error('The expected source commit/tree does not match the executing source.');
  }
  if (!source.cleanWorktree) {
    throw new Error('The source worktree contains uncommitted governed changes.');
  }
  if (args.project !== PRODUCTION_PROJECT) return;
  if (args.confirmProject !== PRODUCTION_PROJECT) {
    throw new Error('Production requires exact --confirm-project custody.');
  }
  if (args.mode === 'dry-run') {
    if (args.allowProductionReadOnly !== true) {
      throw new Error('Production dry-run requires --allow-production-read-only.');
    }
    return;
  }
  const expectedToken = `${WRITE_CONFIRMATION}:${PRODUCTION_PROJECT}:${source.commit}`;
  if (args.allowProductionWrite !== true ||
      args.confirmMutation !== WRITE_CONFIRMATION ||
      env[WRITE_TOKEN_ENV] !== expectedToken) {
    throw new Error('Production apply custody is incomplete.');
  }
  if (source.branch !== 'main' || source.originMainCommit !== source.commit) {
    throw new Error('Production apply requires exact clean origin/main source authority.');
  }
}

function assertNewOutput(output) {
  const resolved = path.resolve(output);
  if (fs.existsSync(resolved)) throw new Error('Evidence output already exists.');
  fs.mkdirSync(path.dirname(resolved), {recursive: true});
  return resolved;
}

async function loadRows(db, collection) {
  const snapshot = await db.collection(collection).get();
  return snapshot.docs.map((doc) => ({id: doc.id, data: doc.data()}));
}

export async function loadInventory(db) {
  const [maintenanceWorkflows, jobExecutions, assetInstances, equipmentStatus] =
    await Promise.all([
      loadRows(db, 'maintenance_workflows'),
      loadRows(db, 'job_executions'),
      loadRows(db, 'asset_instances'),
      loadRows(db, 'equipment_status'),
    ]);
  return {maintenanceWorkflows, jobExecutions, assetInstances, equipmentStatus};
}

function materialize(value, fieldValue) {
  if (value === SERVER_TIMESTAMP) return fieldValue.serverTimestamp();
  if (Array.isArray(value)) return value.map((item) => materialize(item, fieldValue));
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, materialize(item, fieldValue)]),
    );
  }
  return value;
}

export async function applyPlan({db, fieldValue, plan, source}) {
  if (plan.blockers.length > 0) throw new Error('A blocked plan cannot be applied.');
  const contractRef = db.collection('governed_migration_contracts')
    .doc('governed_asset_identity_v1');
  const proposedMigrationId = `gaip1-${plan.planHash.slice(-24)}`;
  let authority = null;
  await db.runTransaction(async (transaction) => {
    const marker = await transaction.get(contractRef);
    if (marker.exists) {
      authority = marker.data();
      return;
    }
    authority = {
      schemaVersion: 1,
      status: 'prepared',
      migrationId: proposedMigrationId,
      migrationPlanHash: plan.planHash,
      plannedEntityMutationCount: plan.mutations.length,
      sourceCommit: source.commit,
      sourceTree: source.tree,
      workflowIdentityContract: 'assetClassId+assetInstanceId',
      strictClientSchemaVersion: 5,
      preparedAt: fieldValue.serverTimestamp(),
      completedAt: null,
    };
    transaction.create(contractRef, authority);
  });
  if (authority?.status === 'complete') {
    if (plan.decision !== 'CLEAN' ||
        authority.schemaVersion !== 1 ||
        typeof authority.migrationId !== 'string' ||
        typeof authority.migrationPlanHash !== 'string' ||
        !Number.isSafeInteger(authority.plannedEntityMutationCount) ||
        authority.plannedEntityMutationCount < 0 ||
        authority.workflowIdentityContract !== 'assetClassId+assetInstanceId' ||
        authority.strictClientSchemaVersion !== 5) {
      throw new Error('A completed migration marker conflicts with current projections.');
    }
    const audits = await db.collection('governed_migration_audits')
      .where('migrationId', '==', authority.migrationId)
      .get();
    if (audits.size !== authority.plannedEntityMutationCount) {
      throw new Error('The completed migration marker has incomplete audit evidence.');
    }
    return {
      migrationId: authority.migrationId,
      readback: plan,
      replay: true,
    };
  }
  if (authority?.status !== 'prepared' ||
      typeof authority.migrationId !== 'string' ||
      typeof authority.migrationPlanHash !== 'string' ||
      !Number.isSafeInteger(authority.plannedEntityMutationCount) ||
      authority.sourceCommit !== source.commit || authority.sourceTree !== source.tree) {
    throw new Error('The migration preparation marker is malformed or source-incompatible.');
  }
  if (plan.mutations.length > 0 && authority.migrationPlanHash !== plan.planHash) {
    throw new Error('The current mutation plan differs from the prepared migration authority.');
  }
  const migrationId = authority.migrationId;
  if (plan.mutations.length > 0) {
    await db.runTransaction(async (transaction) => {
      const refs = plan.mutations.map((item) => db.doc(item.path));
      const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
      for (let index = 0; index < plan.mutations.length; index += 1) {
        const item = plan.mutations[index];
        const snapshot = snapshots[index];
        const actualHash = snapshot.exists ? sourceHash(snapshot.data()) : null;
        if (actualHash !== item.expectedSourceHash) {
          throw new Error(`Projection changed after preflight: ${item.path}`);
        }
      }
      for (let index = 0; index < plan.mutations.length; index += 1) {
        const item = plan.mutations[index];
        const ref = refs[index];
        if (item.operation === 'delete') transaction.delete(ref);
        else if (item.operation === 'create') {
          transaction.create(ref, materialize(item.data, fieldValue));
        } else {
          transaction.update(ref, materialize(item.data, fieldValue));
        }
        const auditId = sha256(`${migrationId}|${item.operation}|${item.path}`);
        transaction.create(db.collection('governed_migration_audits').doc(auditId), {
          schemaVersion: 1,
          migrationId,
          migrationType: 'governedCustomProjectionIdentityV1',
          operation: item.operation,
          targetPath: item.path,
          expectedSourceHash: item.expectedSourceHash,
          planHash: plan.planHash,
          sourceCommit: source.commit,
          sourceTree: source.tree,
          committedAt: fieldValue.serverTimestamp(),
        });
      }
    });
  }

  const readback = buildReconciliationPlan(await loadInventory(db));
  if (readback.decision !== 'CLEAN') {
    throw new Error(`Post-migration readback is not clean: ${readback.decision}`);
  }
  const audits = await db.collection('governed_migration_audits')
    .where('migrationId', '==', migrationId)
    .get();
  if (audits.size !== authority.plannedEntityMutationCount) {
    throw new Error(
      `Migration audit readback expected ${authority.plannedEntityMutationCount} records; found ${audits.size}.`,
    );
  }
  await contractRef.set({
    status: 'complete',
    completedAt: fieldValue.serverTimestamp(),
  }, {merge: true});
  const marker = await contractRef.get();
  if (!marker.exists || marker.data()?.status !== 'complete' ||
      marker.data()?.migrationId !== migrationId) {
    throw new Error('Migration completion marker readback failed.');
  }
  return {migrationId, readback, replay: false};
}

function usage() {
  return [
    'Usage:',
    '  node tools/v4/governed_asset_identity_projection_reconciliation.mjs',
    '    --project <id> --output <new-file> --mode dry-run',
    '    --expected-source-commit <sha> --expected-source-tree <sha>',
    '',
    'Production dry-run additionally requires:',
    `  --confirm-project ${PRODUCTION_PROJECT} --allow-production-read-only`,
    '',
    'Production apply additionally requires:',
    `  --confirm-project ${PRODUCTION_PROJECT} --allow-production-write`,
    `  --confirm-mutation ${WRITE_CONFIRMATION}`,
    `  ${WRITE_TOKEN_ENV}=${WRITE_CONFIRMATION}:${PRODUCTION_PROJECT}:<commit>`,
  ].join('\n');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  const source = readGitSourceAuthority();
  assertCustody(args, process.env, source);
  const output = assertNewOutput(args.output);
  const require = createRequire(import.meta.url);
  const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));
  const app = admin.initializeApp(
    {projectId: args.project},
    `governed-asset-identity-reconciliation-${process.pid}-${Date.now()}`,
  );
  try {
    const db = app.firestore();
    const startedAt = new Date().toISOString();
    const plan = buildReconciliationPlan(await loadInventory(db));
    let application = null;
    if (args.mode === 'apply') {
      if (plan.blockers.length > 0) {
        throw new Error(`Migration is blocked by ${plan.blockers.length} evidence defect(s).`);
      }
      application = await applyPlan({
        db,
        fieldValue: admin.firestore.FieldValue,
        plan,
        source,
      });
    }
    const evidence = canonicalValue({
      schemaVersion: 1,
      tool: 'governed_asset_identity_projection_reconciliation',
      mode: args.mode,
      readOnly: args.mode === 'dry-run',
      projectId: args.project,
      source,
      startedAt,
      completedAt: new Date().toISOString(),
      plan,
      application,
    });
    fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`, {flag: 'wx'});
    process.stdout.write(`${plan.decision} ${plan.planHash}\n`);
  } finally {
    await app.delete();
  }
}

if (process.argv[1] != null &&
    path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  });
}
