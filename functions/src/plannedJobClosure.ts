import {createHash} from "crypto";
import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "./persistedActionPayload";
import {canonicalUserHasAnyRole} from "./userAuthority";

export type HttpsErrorCode =
  | "ok"
  | "cancelled"
  | "unknown"
  | "invalid-argument"
  | "deadline-exceeded"
  | "not-found"
  | "already-exists"
  | "permission-denied"
  | "resource-exhausted"
  | "failed-precondition"
  | "aborted"
  | "out-of-range"
  | "unimplemented"
  | "internal"
  | "unavailable"
  | "data-loss"
  | "unauthenticated";

export type JsonMap = {[key: string]: unknown};

export type FirestoreLike = {
  collection: (name: string) => CollectionLike;
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) => Promise<T>;
};

type CollectionLike = {
  doc: (id?: string) => DocumentRefLike;
  where: (field: string, op: string, value: unknown) => QueryLike;
};

type QueryLike = {
  where: (field: string, op: string, value: unknown) => QueryLike;
};

type DocumentRefLike = {readonly path: string};

type DocumentSnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => JsonMap | undefined;
};

type QuerySnapshotLike = {
  docs: DocumentSnapshotLike[];
};

type TransactionLike = {
  get: (refOrQuery: DocumentRefLike | QueryLike) => Promise<DocumentSnapshotLike | QuerySnapshotLike>;
  update: (ref: DocumentRefLike, data: JsonMap) => void;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
};

const COMPLETER_ROLES = new Set([
  "admin",
  "si",
  "contractSupervisor",
  "shiftSupervisor",
]);

const ISSUE_TYPES = [
  "openRequiredModule",
  "waitingAcceptance",
  "missingRequiredEvidence",
  "pendingIssueOrFollowUp",
] as const;

const CLOSURE_ATTESTATION_METADATA_KEY = "closureAttestation";
const CLOSURE_ATTESTATION_SCHEMA_VERSION = 2;
const MODULE_POPULATION_SCHEMA_VERSION = 1;

export class ClosureValidationError extends Error {
  readonly code: HttpsErrorCode;
  readonly details?: unknown;

  constructor(code: HttpsErrorCode, message: string, details?: unknown) {
    super(message);
    this.name = "ClosureValidationError";
    this.code = code;
    this.details = details;
  }
}

export function cleanOptionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function assertString(value: unknown, fieldName: string): string {
  const cleaned = cleanOptionalText(value);
  if (cleaned == null) {
    throw new ClosureValidationError(
      "invalid-argument",
      `${fieldName} must be a non-empty string.`,
    );
  }
  return cleaned;
}

/**
 * Parses the optional optimistic-concurrency token sent by the client.
 *
 * - Omitted / null / undefined  → null (caller skips the version check).
 * - A non-negative safe integer  → the number.
 * - Anything else (string, float, NaN, negative) → throws invalid-argument.
 *
 * Previously this silently coerced bad input to null, which masked client
 * bugs that should have surfaced as stale-write errors.
 */
export function parseExpectedCompletionVersion(value: unknown): number | null {
  if (value == null) return null;
  if (
    typeof value === "number" &&
    Number.isInteger(value) &&
    value >= 0 &&
    Number.isSafeInteger(value)
  ) {
    return value;
  }
  throw new ClosureValidationError(
    "invalid-argument",
    "expectedCompletionVersion must be a non-negative integer when provided.",
  );
}

export function modulePopulationVersionFromExecution(
  execution: JsonMap,
): number {
  const value = execution.modulePopulationVersion;
  const schemaVersion = execution.modulePopulationSchemaVersion;
  if (value == null && schemaVersion == null) return 0;

  if (
    typeof schemaVersion !== "number" ||
    !Number.isSafeInteger(schemaVersion) ||
    schemaVersion !== MODULE_POPULATION_SCHEMA_VERSION
  ) {
    throw new ClosureValidationError(
      "failed-precondition",
      "The planned-job module-population schema version is invalid.",
      {
        reasonCode: "module-population-schema-version-invalid",
        schemaVersion,
        expectedSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
      },
    );
  }

  if (
    typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value >= 0
  ) {
    return value;
  }
  throw new ClosureValidationError(
    "failed-precondition",
    "The planned-job module-population revision is invalid.",
    {reasonCode: "module-population-version-invalid", value},
  );
}

export function cleanStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}

export function parseJsonArray(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  const cleaned = cleanOptionalText(value);
  if (cleaned == null) return [];
  try {
    const decoded = JSON.parse(cleaned);
    return Array.isArray(decoded) ? decoded : [];
  } catch (_) {
    return [];
  }
}

function parseJsonObject(value: unknown): JsonMap {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return {...(value as JsonMap)};
  }
  const cleaned = cleanOptionalText(value);
  if (cleaned == null) return {};
  try {
    const decoded = JSON.parse(cleaned);
    return decoded && typeof decoded === "object" && !Array.isArray(decoded)
      ? {...(decoded as JsonMap)}
      : {legacyMetadataValue: decoded};
  } catch (_) {
    return {legacyMetadataJson: cleaned};
  }
}

function moduleFieldDefinitions(jsonText: unknown): JsonMap[] {
  return parseJsonArray(jsonText).filter(
    (item): item is JsonMap => item != null && typeof item === "object" && !Array.isArray(item),
  );
}

function fieldDefinitionRequired(definition: JsonMap): boolean {
  return definition.required === true || definition.isRequired === true;
}

function fieldDefinitionKey(definition: JsonMap): string | null {
  for (const key of ["fieldId", "key", "id", "name"]) {
    const raw = definition[key];
    if (typeof raw === "string" && raw.trim().length > 0) {
      return raw.trim();
    }
  }
  return null;
}

function isSafetyGateDefinition(definition: JsonMap): boolean {
  const raw = definition.type ?? definition.fieldType ?? "";
  const key = String(raw)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
  return key === "safetygate" || key === "safetyconfirmation";
}

function responseKey(response: unknown): string | null {
  if (!response || typeof response !== "object" || Array.isArray(response)) {
    return null;
  }
  const map = response as JsonMap;
  for (const key of ["key", "fieldId", "id", "name"]) {
    const raw = map[key];
    if (typeof raw === "string" && raw.trim().length > 0) {
      return raw.trim();
    }
  }
  return null;
}

function responseValue(response: unknown): unknown {
  if (!response || typeof response !== "object" || Array.isArray(response)) {
    return null;
  }
  const map = response as JsonMap;
  if (Object.prototype.hasOwnProperty.call(map, "value")) return map.value;
  if (Object.prototype.hasOwnProperty.call(map, "answer")) return map.answer;
  return null;
}

function responsesByKey(moduleData: JsonMap): JsonMap {
  const result: JsonMap = {};
  for (const response of parseJsonArray(moduleData.responsesJson)) {
    const key = responseKey(response);
    if (key != null) {
      result[key] = responseValue(response);
    }
  }
  return result;
}

export function hasEvidenceValue(value: unknown): boolean {
  if (value == null) return false;
  if (typeof value === "string") return value.trim().length > 0;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === "object") return Object.keys(value).length > 0;
  return true;
}

export function ordinaryRequiredKeysForModule(moduleData: JsonMap): string[] {
  const definitions = moduleFieldDefinitions(moduleData.fieldDefinitionsJson);
  return definitions
    .filter(
      (definition) =>
        fieldDefinitionRequired(definition) && !isSafetyGateDefinition(definition),
    )
    .map(fieldDefinitionKey)
    .filter((key): key is string => key != null && key.length > 0)
    .sort();
}

function moduleHasAnyOrdinaryField(moduleData: JsonMap): boolean {
  return moduleFieldDefinitions(moduleData.fieldDefinitionsJson).some(
    (definition) => !isSafetyGateDefinition(definition),
  );
}

export function moduleMissingRequiredClosureEvidence(moduleData: JsonMap): boolean {
  const requiredKeys = ordinaryRequiredKeysForModule(moduleData);
  const responseMap = responsesByKey(moduleData);

  if (requiredKeys.length > 0) {
    return requiredKeys.some((key) => !hasEvidenceValue(responseMap[key]));
  }

  if (moduleHasAnyOrdinaryField(moduleData)) {
    return parseJsonArray(moduleData.responsesJson).length === 0;
  }

  return false;
}

function isOpenRequiredClosureStatus(status: unknown): boolean {
  return (
    status === "notStarted" ||
    status === "draftSaved" ||
    status === "inProgress" ||
    status === "reopened"
  );
}

function moduleFirestoreIds(modules: JsonMap[]): string[] {
  return modules
    .map((moduleData) => cleanOptionalText(moduleData.firestoreId))
    .filter((id): id is string => id != null);
}

export function collectClosureIssues(modules: JsonMap[]): JsonMap[] {
  const activeModules = modules.filter((moduleData) => moduleData.isDeleted !== true);
  if (activeModules.length === 0) return [];

  const requiredModules = activeModules.filter(
    (moduleData) => moduleData.requiredForClosure === true,
  );
  if (requiredModules.length === 0) return [];

  const issueData = [
    {
      type: "openRequiredModule",
      modules: requiredModules.filter((moduleData) =>
        isOpenRequiredClosureStatus(moduleData.status),
      ),
      message: "required module(s) still open",
    },
    {
      type: "waitingAcceptance",
      modules: requiredModules.filter(
        (moduleData) => moduleData.status === "submitted",
      ),
      message: "required module(s) submitted but not accepted",
    },
    {
      type: "missingRequiredEvidence",
      modules: requiredModules.filter(
        (moduleData) =>
          moduleData.status !== "notApplicable" &&
          moduleMissingRequiredClosureEvidence(moduleData),
      ),
      message: "required module(s) missing required evidence",
    },
    {
      type: "pendingIssueOrFollowUp",
      modules: requiredModules.filter(
        (moduleData) =>
          moduleData.requiresFollowUp === true ||
          cleanOptionalText(moduleData.pendingIssue) != null,
      ),
      message: "required module(s) with pending issue/follow-up",
    },
  ];

  return issueData
    .filter((item) => item.modules.length > 0)
    .map((item) => ({
      type: item.type,
      count: item.modules.length,
      message: `${item.modules.length} ${item.message}`,
      moduleFirestoreIds: moduleFirestoreIds(item.modules),
    }));
}

function issueCountsByType(issues: JsonMap[]): JsonMap {
  const counts: JsonMap = Object.fromEntries(ISSUE_TYPES.map((type) => [type, 0]));
  for (const issue of issues) {
    const type = cleanOptionalText(issue.type);
    if (type != null) {
      counts[type] = issue.count;
    }
  }
  return counts;
}

export function assertClosureReady(modules: JsonMap[]): JsonMap {
  for (const moduleData of modules.filter((module) => module.isDeleted !== true)) {
    try {
      readComponentActionPayload(moduleData.actionsJson, {
        field: "actionsJson",
        allowMissing: true,
      });
    } catch (error) {
      if (error instanceof PersistedActionPayloadError) {
        throw new ClosureValidationError(
          "failed-precondition",
          "Saved module action evidence needs repair before closure.",
          {
            reasonCode: "module-action-payload-invalid",
            moduleFirestoreId: cleanOptionalText(moduleData.firestoreId),
            field: error.field,
          },
        );
      }
      throw error;
    }
  }
  const issues = collectClosureIssues(modules);
  if (issues.length > 0) {
    throw new ClosureValidationError(
      "failed-precondition",
      `Cannot complete planned job: required closure modules are not ready (${issues
        .map((issue) => issue.message)
        .join("; ")}).`,
      {issues},
    );
  }
  return issueCountsByType(issues);
}

function canonicalValue(value: unknown): unknown {
  if (value == null || typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map(canonicalValue);
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === "object") {
    const result: JsonMap = {};
    for (const key of Object.keys(value as JsonMap).sort()) {
      result[key] = canonicalValue((value as JsonMap)[key]);
    }
    return result;
  }
  return String(value);
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

function sha256Hex(value: string): string {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}


function hasToDate(value: unknown): value is {toDate: () => Date} {
  return (
    typeof value === "object" &&
    value !== null &&
    "toDate" in value &&
    typeof (value as {toDate?: unknown}).toDate === "function"
  );
}

export function plainReturnValue(value: unknown): unknown {
  if (
    value == null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (hasToDate(value)) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(plainReturnValue);
  }
  if (typeof value === "object") {
    const result: JsonMap = {};
    for (const key of Object.keys(value as JsonMap)) {
      result[key] = plainReturnValue((value as JsonMap)[key]);
    }
    return result;
  }
  return String(value);
}

export function executionResponse(
  data: JsonMap | undefined,
  executionId: string,
): JsonMap {
  const plain = plainReturnValue(data ?? {});
  if (plain != null && typeof plain === "object" && !Array.isArray(plain)) {
    return {
      ...(plain as JsonMap),
      firestoreId: executionId,
    };
  }
  return {firestoreId: executionId};
}

function responseEvidenceSummary(value: unknown): JsonMap {
  const hasEvidence = hasEvidenceValue(value);
  return {
    hasEvidence,
    valueHash: hasEvidence ? sha256Hex(canonicalJson(value)) : null,
  };
}

function moduleKey(moduleData: JsonMap): string {
  const firestoreId = cleanOptionalText(moduleData.firestoreId);
  if (firestoreId != null) return `firestore:${firestoreId}`;

  const templateModuleId = cleanOptionalText(moduleData.templateModuleId);
  if (templateModuleId != null) {
    return `templateModule:${templateModuleId}:${moduleData.id ?? ""}`;
  }

  return `local:${moduleData.id ?? moduleData.firestoreId ?? "unknown"}`;
}

function moduleSnapshot(moduleData: JsonMap): JsonMap {
  const ordinaryRequiredFieldKeys = ordinaryRequiredKeysForModule(moduleData);
  const responseMap = responsesByKey(moduleData);
  const missingRequiredEvidenceKeys = ordinaryRequiredFieldKeys.filter(
    (key) => !hasEvidenceValue(responseMap[key]),
  );
  const responseEvidenceByRequiredKey: JsonMap = {};
  for (const key of ordinaryRequiredFieldKeys) {
    responseEvidenceByRequiredKey[key] = responseEvidenceSummary(responseMap[key]);
  }

  const hasPendingIssue = cleanOptionalText(moduleData.pendingIssue) != null;
  const fieldDefinitionsJson = cleanOptionalText(moduleData.fieldDefinitionsJson) ?? "[]";
  const responsesJson = cleanOptionalText(moduleData.responsesJson) ?? "[]";
  const snapshot: JsonMap = {
    moduleKey: moduleKey(moduleData),
    firestoreId: cleanOptionalText(moduleData.firestoreId),
    localId: moduleData.id ?? null,
    jobExecutionFirestoreId: cleanOptionalText(moduleData.jobExecutionFirestoreId),
    jobExecutionLocalId: moduleData.jobExecutionLocalId ?? null,
    templateModuleId: cleanOptionalText(moduleData.templateModuleId),
    moduleCode: cleanOptionalText(moduleData.moduleCode),
    moduleTitle: cleanOptionalText(moduleData.moduleTitle) ?? "",
    version: Number.isInteger(moduleData.version) ? moduleData.version : 0,
    status: cleanOptionalText(moduleData.status) ?? "notStarted",
    requiredForClosure: moduleData.requiredForClosure === true,
    isDeleted: moduleData.isDeleted === true,
    requiresFollowUp: moduleData.requiresFollowUp === true,
    hasPendingIssue,
    pendingIssueHash: hasPendingIssue ? sha256Hex(cleanOptionalText(moduleData.pendingIssue) ?? "") : null,
    hasResponses: parseJsonArray(moduleData.responsesJson).length > 0,
    hasAnyOrdinaryField: moduleHasAnyOrdinaryField(moduleData),
    ordinaryRequiredFieldKeys,
    missingRequiredEvidenceKeys,
    responseEvidenceByRequiredKey,
    fieldDefinitionsHash: sha256Hex(fieldDefinitionsJson),
    responsesHash: sha256Hex(responsesJson),
  };

  snapshot.snapshotHash = sha256Hex(canonicalJson(snapshot));
  return snapshot;
}

export function buildClosureAttestation(params: {
  executionFirestoreId: string;
  modules: JsonMap[];
  completedByUid: string;
  completedByName: string | null;
  completedAt: string;
  executionVersionAtCompletion: number;
  modulePopulationVersionAtCompletion: number;
  guardIssueCounts: JsonMap;
}): {payload: JsonMap; canonicalJson: string; hash: string; toMetadataEnvelope: () => JsonMap} {
  const activeModules = params.modules.filter((moduleData) => moduleData.isDeleted !== true);
  const requiredModules = activeModules.filter(
    (moduleData) => moduleData.requiredForClosure === true,
  );
  const moduleSnapshots = params.modules.map(moduleSnapshot).sort((left, right) =>
    String(left.moduleKey).localeCompare(String(right.moduleKey)),
  );

  const payload: JsonMap = {
    schemaVersion: CLOSURE_ATTESTATION_SCHEMA_VERSION,
    executionFirestoreId: cleanOptionalText(params.executionFirestoreId),
    completedByUid: assertString(params.completedByUid, "completedByUid"),
    completedByName: cleanOptionalText(params.completedByName),
    completedAt: params.completedAt,
    executionVersionAtCompletion: params.executionVersionAtCompletion,
    modulePopulationVersionAtCompletion:
      params.modulePopulationVersionAtCompletion,
    modulePopulationSchemaVersionAtCompletion:
      MODULE_POPULATION_SCHEMA_VERSION,
    moduleCounts: {
      total: params.modules.length,
      active: activeModules.length,
      requiredForClosure: requiredModules.length,
      deleted: params.modules.length - activeModules.length,
    },
    guardIssueCounts: Object.fromEntries(
      ISSUE_TYPES.map((type) => [type, params.guardIssueCounts[type] ?? 0]),
    ),
    modules: moduleSnapshots,
  };

  const json = canonicalJson(payload);
  return {
    payload,
    canonicalJson: json,
    hash: sha256Hex(json),
    toMetadataEnvelope: () => ({
      schemaVersion: CLOSURE_ATTESTATION_SCHEMA_VERSION,
      hash: sha256Hex(json),
      canonicalJson: json,
    }),
  };
}

export function mergeAttestationIntoMetadata(existingMetadataJson: unknown, attestation: {toMetadataEnvelope: () => JsonMap}): string {
  const metadata = parseJsonObject(existingMetadataJson);
  metadata[CLOSURE_ATTESTATION_METADATA_KEY] = attestation.toMetadataEnvelope();
  return JSON.stringify(metadata);
}

export function userCanComplete(userData: JsonMap | null | undefined): boolean {
  return canonicalUserHasAnyRole(userData, COMPLETER_ROLES);
}

export function executionAuditMap(data: JsonMap, docId: string, closureAttestationHash: string | null = null): JsonMap {
  const snapshot: JsonMap = {
    firestoreId: docId,
    templateName: data.templateName ?? null,
    templatePackageId: data.templatePackageId ?? null,
    templateVersionId: data.templateVersionId ?? null,
    templateVersionNumber: data.templateVersionNumber ?? null,
    templateContentHash: data.templateContentHash ?? null,
    assetType: data.assetType ?? null,
    assetNumber: data.assetNumber ?? null,
    isCompleted: data.isCompleted ?? null,
    isDeleted: data.isDeleted ?? null,
    completedByUid: data.completedByUid ?? null,
    completedByName: data.completedByName ?? null,
    completedAt: data.completedAt ?? null,
    version: data.version ?? null,
    modulePopulationVersion: data.modulePopulationVersion ?? 0,
    modulePopulationSchemaVersion:
      data.modulePopulationSchemaVersion ?? MODULE_POPULATION_SCHEMA_VERSION,
    metadataHasClosureAttestation:
      closureAttestationHash != null ||
      (typeof data.metadataJson === "string" &&
        data.metadataJson.includes(CLOSURE_ATTESTATION_METADATA_KEY)),
  };

  if (closureAttestationHash != null) {
    snapshot.closureAttestationHash = closureAttestationHash;
    snapshot.closureAttestationVersion = CLOSURE_ATTESTATION_SCHEMA_VERSION;
  }

  return snapshot;
}

function asQuerySnapshot(value: DocumentSnapshotLike | QuerySnapshotLike): QuerySnapshotLike {
  if ("docs" in value && Array.isArray(value.docs)) return value;
  return {docs: []};
}

function asDocumentSnapshot(value: DocumentSnapshotLike | QuerySnapshotLike): DocumentSnapshotLike {
  if ("exists" in value) return value;
  return {exists: false, data: () => undefined};
}

export type AuditTimestampFactory = (date: Date) => unknown;

function requestedActionsJson(data: JsonMap): string | null {
  let raw: unknown = null;
  if (data.actionsJson != null) {
    raw = data.actionsJson;
  } else if (data.actions != null) {
    if (!Array.isArray(data.actions)) {
      throw new ClosureValidationError(
        "invalid-argument",
        "actions must be an array when provided.",
      );
    }
    raw = JSON.stringify(data.actions);
  }
  if (raw == null) return null;

  try {
    return readComponentActionPayload(raw, {field: "actionsJson"}).text;
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new ClosureValidationError(
        "invalid-argument",
        "actionsJson contains invalid component-action evidence.",
        {reasonCode: "action-payload-invalid", field: error.field},
      );
    }
    throw error;
  }
}

function assertExecutionActionsValid(
  value: unknown,
  executionId: string,
): void {
  try {
    readComponentActionPayload(value, {
      field: "actionsJson",
      allowMissing: true,
    });
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new ClosureValidationError(
        "failed-precondition",
        "Saved planned-job action evidence needs repair before closure.",
        {
          reasonCode: "execution-action-payload-invalid",
          executionId,
          field: error.field,
        },
      );
    }
    throw error;
  }
}

export async function completePlannedJobWithDb(params: {
  db: FirestoreLike;
  authUid: string | null;
  data: JsonMap;
  /**
   * Produces the value written to audit_logs.timestamp.
   *
   * Production must pass `admin.firestore.Timestamp.fromDate` so the value
   * satisfies the `audit_logs` rule (`timestamp is timestamp`) and the
   * composite index on `audit_logs(entityType, entityId, timestamp DESC)`.
   * Tests can omit it; the default returns the ISO string and keeps the
   * existing in-memory test harness working without an admin dependency.
   */
  timestampFromDate?: AuditTimestampFactory;
  beforeTransactionForTest?: () => Promise<void>;
  beforeClosureWriteForTest?: () => Promise<void>;
}): Promise<JsonMap> {
  const {db, authUid, data} = params;
  const auditTimestampFromDate: AuditTimestampFactory =
    params.timestampFromDate ?? ((date) => date.toISOString());
  if (authUid == null || authUid.trim().length === 0) {
    throw new ClosureValidationError("unauthenticated", "Sign in required.");
  }

  const executionId = assertString(data.executionId, "executionId");
  const payloadCompletedByUid = cleanOptionalText(data.completedByUid);
  if (payloadCompletedByUid != null && payloadCompletedByUid !== authUid) {
    throw new ClosureValidationError(
      "permission-denied",
      "completedByUid must match the signed-in user.",
    );
  }

  const remarks = cleanOptionalText(data.remarks);
  const teamsInvolved = cleanStringList(data.teamsInvolved);
  const responsesJson = cleanOptionalText(data.responsesJson) ?? (data.responses == null ? null : JSON.stringify(parseJsonArray(data.responses)));
  const actionsJson = requestedActionsJson(data);
  const expectedCompletionVersion = parseExpectedCompletionVersion(
    data.expectedCompletionVersion,
  );

  if (params.beforeTransactionForTest != null) {
    await params.beforeTransactionForTest();
  }

  return db.runTransaction(async (transaction) => {
    const userRef = db.collection("users").doc(authUid);
    const userSnap = asDocumentSnapshot(await transaction.get(userRef));
    const userData = userSnap.exists ? userSnap.data() ?? {} : null;
    if (!userCanComplete(userData)) {
      throw new ClosureValidationError(
        "permission-denied",
        "You are not authorized to complete planned jobs.",
        {reasonCode: "closure-authority-denied"},
      );
    }
    const completedByName =
      cleanOptionalText(userData?.name) ??
      cleanOptionalText(userData?.email) ??
      authUid;

    const executionRef = db.collection("job_executions").doc(executionId);
    const executionSnap = asDocumentSnapshot(await transaction.get(executionRef));
    if (!executionSnap.exists) {
      throw new ClosureValidationError(
        "not-found",
        "Planned job execution not found.",
      );
    }

    const beforeData = executionSnap.data() ?? {};
    assertExecutionActionsValid(beforeData.actionsJson, executionId);
    if (beforeData.isDeleted === true) {
      throw new ClosureValidationError(
        "failed-precondition",
        "Deleted planned job execution cannot be completed.",
      );
    }

    if (beforeData.workflowSchemaVersion === 1) {
      throw new ClosureValidationError(
        "failed-precondition",
        "Workflow-governed jobs must be completed through the maintenance workflow finalizer.",
        {reasonCode: "workflow-finalizer-required", executionId},
      );
    }

    const currentVersion = Number.isInteger(beforeData.version)
      ? beforeData.version as number
      : 0;
    const nextVersion = currentVersion + 1;
    const modulePopulationVersion =
      modulePopulationVersionFromExecution(beforeData);

    if (beforeData.isCompleted === true) {
      const metadata = parseJsonObject(beforeData.metadataJson);
      const existingAttestation = metadata[CLOSURE_ATTESTATION_METADATA_KEY] as JsonMap | undefined;
      if (existingAttestation != null) {
        // Idempotent success: a retrying client may carry a stale expected
        // version after the server already completed the job. Return the
        // canonical server document instead of failing and leaving local Isar
        // dirty. No write is performed in this branch.
        return {
          ok: true,
          alreadyCompleted: true,
          executionId,
          version: currentVersion,
          closureAttestationHash: existingAttestation.hash ?? null,
          execution: executionResponse(beforeData, executionId),
        };
      }

      throw new ClosureValidationError(
        "failed-precondition",
        "Planned job is already completed without a closure attestation.",
      );
    }

    if (
      expectedCompletionVersion != null &&
      expectedCompletionVersion !== nextVersion
    ) {
      throw new ClosureValidationError(
        "failed-precondition",
        "Local completion version is stale; pull latest execution before completing.",
        {currentVersion, expectedCompletionVersion},
      );
    }

    const modulesQuery = db
      .collection("job_modules")
      .where("jobExecutionFirestoreId", "==", executionId)
      .where("isDeleted", "==", false);
    const modulesSnap = asQuerySnapshot(await transaction.get(modulesQuery));
    const modules = modulesSnap.docs.map((doc) => ({
      ...(doc.data() ?? {}),
      firestoreId:
        typeof (doc.data() ?? {}).firestoreId === "string"
          ? (doc.data() ?? {}).firestoreId
          : doc.id,
    }));

    const guardIssueCounts = assertClosureReady(modules);
    const completedAt = new Date().toISOString();
    const attestation = buildClosureAttestation({
      executionFirestoreId: executionId,
      modules,
      completedByUid: authUid,
      completedByName,
      completedAt,
      executionVersionAtCompletion: nextVersion,
      modulePopulationVersionAtCompletion: modulePopulationVersion,
      guardIssueCounts,
    });

    const metadataJson = mergeAttestationIntoMetadata(
      beforeData.metadataJson,
      attestation,
    );

    if (params.beforeClosureWriteForTest != null) {
      await params.beforeClosureWriteForTest();
    }

    const updateData: JsonMap = {
      isCompleted: true,
      completedAt,
      completedByUid: authUid,
      completedByName,
      metadataJson,
      updatedAt: completedAt,
      version: nextVersion,
      modulePopulationVersion,
      modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
    };

    if (remarks != null) updateData.remarks = remarks;
    if (teamsInvolved.length > 0) updateData.teamsInvolved = teamsInvolved;
    if (responsesJson != null) updateData.responsesJson = responsesJson;
    if (actionsJson != null) updateData.actionsJson = actionsJson;

    transaction.update(executionRef, updateData);

    const afterData: JsonMap = {...beforeData, ...updateData, firestoreId: executionId};
    const auditRef = db
      .collection("audit_logs")
      .doc(`server_closure_${executionId}_${nextVersion}`);
    transaction.set(
      auditRef,
      {
        entityType: "execution",
        entityId: executionId,
        action: "resolve",
        performedByUid: authUid,
        performedByName: completedByName,
        // Rule contract: audit_logs.timestamp must be a Firestore Timestamp
        // (see firestore.rules `validStandardAuditCreate`). The execution
        // doc's completedAt/updatedAt are ISO strings by rule, so we keep
        // those as `completedAt` and produce a Timestamp here separately.
        timestamp: auditTimestampFromDate(new Date(completedAt)),
        reason: null,
        reasonNotes:
          "Server-side planned-job closure guard validated all canonical remote modules.",
        summary: "Planned job completed by server-side closure enforcement",
        severity: "medium",
        beforeJson: JSON.stringify(executionAuditMap(beforeData, executionId)),
        afterJson: JSON.stringify(
          executionAuditMap(afterData, executionId, attestation.hash),
        ),
      },
      {merge: true},
    );

    return {
      ok: true,
      alreadyCompleted: false,
      executionId,
      version: nextVersion,
      closureAttestationHash: attestation.hash,
      execution: executionResponse(afterData, executionId),
    };
  });
}
