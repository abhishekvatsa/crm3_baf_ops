import {createHash} from "crypto";
import {isFiveDigitChargeNumber} from "./chargeNumber";
import {laneForModuleDiscipline} from "./maintenanceWorkflow/modulePolicy";
import {MODULE_DISCIPLINE_SUBMIT_ROLES} from "./maintenanceWorkflow/policy.generated";
import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "./persistedActionPayload";
import {
  PersistedWorkPayloadError,
  readFieldDefinitionPayload,
  readFieldResponsePayload,
} from "./persistedWorkPayload";
import {canonicalApprovedUserAuthority} from "./userAuthority";

export type RuntimePopulationHttpsErrorCode =
  | "invalid-argument"
  | "not-found"
  | "already-exists"
  | "permission-denied"
  | "failed-precondition"
  | "aborted"
  | "data-loss"
  | "internal"
  | "unauthenticated";

export type RuntimePopulationJsonMap = {[key: string]: unknown};

export type RuntimePopulationFirestoreLike = {
  collection: (name: string) => RuntimePopulationCollectionLike;
  runTransaction: <T>(
    fn: (transaction: RuntimePopulationTransactionLike) => Promise<T>,
  ) => Promise<T>;
};

type RuntimePopulationCollectionLike = {
  doc: (id?: string) => RuntimePopulationDocumentRefLike;
};

type RuntimePopulationDocumentRefLike = {
  id?: string;
  path?: string;
};

type RuntimePopulationDocumentSnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => RuntimePopulationJsonMap | undefined;
};

type RuntimePopulationTransactionLike = {
  get: (
    ref: RuntimePopulationDocumentRefLike,
  ) => Promise<RuntimePopulationDocumentSnapshotLike>;
  set: (
    ref: RuntimePopulationDocumentRefLike,
    data: RuntimePopulationJsonMap,
    options?: RuntimePopulationJsonMap,
  ) => void;
  update: (
    ref: RuntimePopulationDocumentRefLike,
    data: RuntimePopulationJsonMap,
  ) => void;
};

const ASSIGNER_ROLES = new Set([
  "admin",
  "si",
  "contractSupervisor",
  "shiftSupervisor",
  "seniorMechanical",
  "seniorElectrical",
  "seniorInstrumentation",
  "seniorRefractory",
]);

const MODERATOR_ROLES = new Set([
  "admin",
  "si",
  "contractSupervisor",
  "shiftSupervisor",
]);

const ALLOWED_OPERATIONS = new Set(["create", "softDelete"]);
const MODULE_POPULATION_SCHEMA_VERSION = 1;
const MAX_MODULE_PAYLOAD_BYTES = 900_000;
const MAX_PRESERVATION_REASON_LENGTH = 2_000;

const MODULE_STATUSES = new Set([
  "notStarted",
  "inProgress",
  "draftSaved",
  "submitted",
  "accepted",
  "reopened",
  "notApplicable",
]);

const MODULE_USE_MODES = new Set([
  "scheduledPM",
  "troubleshooting",
  "correctiveFollowUp",
  "shutdownWork",
  "preStartVerification",
  "postRepairVerification",
  "futurePackage",
  "adHoc",
]);

const MODULE_DISCIPLINES = new Set([
  "mechanical",
  "electrical",
  "instrumentation",
  "instrument",
  "ia",
  "iAndA",
  "instrumentationAndAutomation",
  "instrumentationAutomation",
  "refractory",
  "emd",
  "operations",
  "shiftInCharge",
  "safety",
  "admin",
  "shared",
  "others",
]);

const MODULE_SAFETY_CLASSES = new Set([
  "normal",
  "lotoRequired",
  "gasRisk",
  "hotSurface",
  "pressureTest",
  "liftingRisk",
  "electricalPanel",
  "combustionSpecialist",
  "configurationControl",
]);

// Exact JobModuleInstance.toMap() client contract. Server-owned population
// metadata and audit fields are deliberately excluded.
const CLIENT_MODULE_FIELDS = [
  "firestoreId",
  "jobExecutionFirestoreId",
  "templateFirestoreId",
  "templateName",
  "templatePackageId",
  "templateVersionId",
  "templateModuleId",
  "moduleCode",
  "moduleSnapshotJson",
  "fieldDefinitionsJson",
  "assetType",
  "assetNumber",
  "chargeNoAtEvent",
  "pairedEquipmentJson",
  "moduleTitle",
  "moduleDescription",
  "status",
  "useMode",
  "discipline",
  "laneKey",
  "laneActivationGeneration",
  "workflowLaneFirestoreId",
  "isOpenForWork",
  "safetyClass",
  "isRequired",
  "requiredForClosure",
  "addedDuringExecution",
  "displayOrder",
  "functionalSection",
  "componentGroup",
  "subsystem",
  "targetRef",
  "targetRefs",
  "procedureRefs",
  "safetyConfirmations",
  "tags",
  "operationalStatePreconditions",
  "responsesJson",
  "actionsJson",
  "draftNote",
  "submissionNote",
  "acceptanceNote",
  "reopenReason",
  "notApplicableReason",
  "pendingIssue",
  "requiresFollowUp",
  "addedByUid",
  "addedByName",
  "addedAt",
  "addReason",
  "createdByUid",
  "createdByName",
  "createdAt",
  "updatedByUid",
  "updatedByName",
  "updatedAt",
  "submittedByUid",
  "submittedByName",
  "submittedAt",
  "acceptedByUid",
  "acceptedByName",
  "acceptedAt",
  "reopenedByUid",
  "reopenedByName",
  "reopenedAt",
  "notApplicableByUid",
  "notApplicableByName",
  "notApplicableAt",
  "isDeleted",
  "deletedAt",
  "deletedByUid",
  "deletedByName",
  "deleteReason",
  "version",
  "metadataJson",
] as const;

const CLIENT_MODULE_FIELD_SET = new Set<string>(CLIENT_MODULE_FIELDS);

const ACTOR_UID_FIELDS = [
  "addedByUid",
  "createdByUid",
  "updatedByUid",
  "submittedByUid",
  "acceptedByUid",
  "reopenedByUid",
  "notApplicableByUid",
] as const;

export class RuntimePopulationValidationError extends Error {
  readonly code: RuntimePopulationHttpsErrorCode;
  readonly details?: unknown;

  constructor(
    code: RuntimePopulationHttpsErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "RuntimePopulationValidationError";
    this.code = code;
    this.details = details;
  }
}

interface ParsedPopulationMutation {
  operation: "create" | "softDelete";
  module: RuntimePopulationJsonMap;
  moduleId: string;
  executionId: string;
  requestFingerprint: string;
  preservationReason: string | null;
}

export interface RuntimePopulationMutationResult {
  ok: true;
  operation: "create" | "softDelete";
  idempotentReplay: boolean;
  executionId: string;
  moduleId: string;
  acceptedAtPopulationVersion: number;
  currentParentPopulationVersion: number;
  mutationAt: string;
  module: RuntimePopulationJsonMap;
}

function cleanOptionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function assertCanonicalText(
  value: unknown,
  fieldName: string,
  maximumLength: number,
  optional = false,
): string | null {
  if (value == null && optional) return null;
  const cleaned = cleanOptionalText(value);
  if (
    cleaned == null ||
    value !== cleaned ||
    cleaned.length > maximumLength
  ) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be canonical non-empty text no longer than ${maximumLength} characters.`,
      {reasonCode: "invalid-text", fieldName, maximumLength},
    );
  }
  return cleaned;
}

function assertDocumentId(value: unknown, fieldName: string): string {
  const cleaned = assertCanonicalText(value, fieldName, 512);
  if (
    cleaned == null ||
    cleaned === "." ||
    cleaned === ".." ||
    cleaned.includes("/")
  ) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be a valid Firestore document id.`,
      {reasonCode: "invalid-document-id", fieldName},
    );
  }
  return cleaned;
}

function assertOptionalDocumentId(
  value: unknown,
  fieldName: string,
): string | null {
  if (value == null) return null;
  return assertDocumentId(value, fieldName);
}

function assertPlainObject(
  value: unknown,
  fieldName: string,
): RuntimePopulationJsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be an object.`,
      {reasonCode: "invalid-object", fieldName},
    );
  }
  return {...(value as RuntimePopulationJsonMap)};
}

function assertBoolean(value: unknown, fieldName: string): boolean {
  if (typeof value !== "boolean") {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be a boolean.`,
      {reasonCode: "invalid-boolean", fieldName},
    );
  }
  return value;
}

function assertInteger(
  value: unknown,
  fieldName: string,
  minimum = 0,
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < minimum
  ) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be an integer greater than or equal to ${minimum}.`,
      {reasonCode: "invalid-integer", fieldName, minimum},
    );
  }
  return value;
}

function assertOptionalInteger(
  value: unknown,
  fieldName: string,
  minimum = 0,
): number | null {
  if (value == null) return null;
  return assertInteger(value, fieldName, minimum);
}

function assertEnumText(
  value: unknown,
  fieldName: string,
  allowed: Set<string>,
): string {
  const cleaned = cleanOptionalText(value);
  if (cleaned == null || value !== cleaned || !allowed.has(cleaned)) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} has an unsupported value.`,
      {reasonCode: "invalid-enum", fieldName, value},
    );
  }
  return cleaned;
}

function assertTimestamp(value: unknown, fieldName: string): string {
  const cleaned = assertCanonicalText(value, fieldName, 100);
  if (cleaned == null || Number.isNaN(Date.parse(cleaned))) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be an ISO-8601 timestamp.`,
      {reasonCode: "invalid-timestamp", fieldName},
    );
  }
  return cleaned;
}

function assertOptionalTimestamp(
  value: unknown,
  fieldName: string,
): string | null {
  if (value == null) return null;
  return assertTimestamp(value, fieldName);
}

function assertStringArray(value: unknown, fieldName: string): string[] {
  if (
    !Array.isArray(value) ||
    value.some(
      (item) =>
        typeof item !== "string" ||
        item.length === 0 ||
        item !== item.trim() ||
        item.length > 2_000,
    )
  ) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be an array of canonical non-empty strings.`,
      {reasonCode: "invalid-string-array", fieldName},
    );
  }
  return value as string[];
}

function assertJsonText(
  value: unknown,
  fieldName: string,
  expected: "array" | "object" | "any",
  optional = false,
): void {
  if (value == null && optional) return;
  if (typeof value !== "string") {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must be JSON text.`,
      {reasonCode: "invalid-json-text", fieldName},
    );
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch (_) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must contain valid JSON.`,
      {reasonCode: "malformed-json-text", fieldName},
    );
  }
  if (expected === "array" && !Array.isArray(parsed)) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must contain a JSON array.`,
      {reasonCode: "wrong-json-shape", fieldName, expected},
    );
  }
  if (
    expected === "object" &&
    (parsed == null || typeof parsed !== "object" || Array.isArray(parsed))
  ) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${fieldName} must contain a JSON object.`,
      {reasonCode: "wrong-json-shape", fieldName, expected},
    );
  }
}

function assertJsonCompatible(value: unknown, path: string): void {
  if (
    value == null ||
    typeof value === "string" ||
    typeof value === "boolean"
  ) {
    return;
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new RuntimePopulationValidationError(
        "invalid-argument",
        `${path} contains a non-finite number.`,
        {reasonCode: "non-json-number", path},
      );
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      assertJsonCompatible(item, `${path}[${index}]`),
    );
    return;
  }
  if (typeof value === "object") {
    for (const [key, item] of Object.entries(value as RuntimePopulationJsonMap)) {
      assertJsonCompatible(item, `${path}.${key}`);
    }
    return;
  }
  throw new RuntimePopulationValidationError(
    "invalid-argument",
    `${path} contains a non-JSON value.`,
    {reasonCode: "non-json-value", path},
  );
}

function canonicalValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (value != null && typeof value === "object") {
    const sorted: RuntimePopulationJsonMap = {};
    for (const key of Object.keys(value as RuntimePopulationJsonMap).sort()) {
      sorted[key] = canonicalValue((value as RuntimePopulationJsonMap)[key]);
    }
    return sorted;
  }
  return value;
}

function canonicalJson(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

function fingerprint(prefix: string, value: unknown): string {
  return `${prefix}-sha256:${createHash("sha256")
    .update(canonicalJson(value), "utf8")
    .digest("hex")}`;
}

function sanitizeClientModule(rawModule: unknown): RuntimePopulationJsonMap {
  const raw = assertPlainObject(rawModule, "module");
  const unexpected = Object.keys(raw).filter(
    (key) => !CLIENT_MODULE_FIELD_SET.has(key),
  );
  if (unexpected.length > 0) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      "The module contains fields outside the governed client contract.",
      {reasonCode: "unexpected-module-fields", fields: unexpected.sort()},
    );
  }
  assertJsonCompatible(raw, "module");

  const sanitized: RuntimePopulationJsonMap = {};
  for (const key of CLIENT_MODULE_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(raw, key)) {
      sanitized[key] = raw[key];
    }
  }
  return sanitized;
}

function hasAnyRole(roles: Set<string>, allowed: Set<string>): boolean {
  for (const role of roles) {
    if (allowed.has(role)) return true;
  }
  return false;
}

export function userCanMutateRuntimeJobModulePopulation(
  userData: RuntimePopulationJsonMap | null | undefined,
): boolean {
  const authority = canonicalApprovedUserAuthority(userData);
  return authority != null && hasAnyRole(
    new Set<string>(authority.roles),
    ASSIGNER_ROLES,
  );
}

function validateApprovedUser(
  userSnapshot: RuntimePopulationDocumentSnapshotLike,
): {userData: RuntimePopulationJsonMap; roles: Set<string>} {
  const userData = userSnapshot.exists ? userSnapshot.data() ?? {} : null;
  const authority = canonicalApprovedUserAuthority(userData);
  if (authority == null) {
    throw new RuntimePopulationValidationError(
      "permission-denied",
      "Only canonically approved users may change planned-job module population.",
      {reasonCode: "user-not-approved-or-malformed"},
    );
  }
  const roles = new Set<string>(authority.roles);
  if (!hasAnyRole(roles, ASSIGNER_ROLES)) {
    throw new RuntimePopulationValidationError(
      "permission-denied",
      "You are not authorized to change planned-job module population.",
      {reasonCode: "role-not-authorized"},
    );
  }
  return {userData: authority.data, roles};
}

export function modulePopulationVersionFromExecution(
  execution: RuntimePopulationJsonMap,
): number {
  const value = execution.modulePopulationVersion;
  const schemaVersion = execution.modulePopulationSchemaVersion;
  if (value == null && schemaVersion == null) return 0;

  if (
    typeof schemaVersion !== "number" ||
    !Number.isSafeInteger(schemaVersion) ||
    schemaVersion !== MODULE_POPULATION_SCHEMA_VERSION
  ) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The parent execution has an invalid module-population schema version.",
      {
        reasonCode: "module-population-schema-version-invalid",
        schemaVersion,
        expectedSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
      },
    );
  }
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The parent execution has an invalid module-population version.",
      {reasonCode: "module-population-version-invalid", value},
    );
  }
  return value;
}

function validateParentExists(
  parentSnapshot: RuntimePopulationDocumentSnapshotLike,
  executionId: string,
): RuntimePopulationJsonMap {
  if (!parentSnapshot.exists) {
    throw new RuntimePopulationValidationError(
      "not-found",
      "The parent planned-job execution does not exist.",
      {reasonCode: "parent-execution-missing", executionId},
    );
  }
  return parentSnapshot.data() ?? {};
}

function validateOpenParent(
  parentSnapshot: RuntimePopulationDocumentSnapshotLike,
  executionId: string,
): RuntimePopulationJsonMap {
  const parent = validateParentExists(parentSnapshot, executionId);
  if (parent.isDeleted === true) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "A deleted planned-job execution cannot accept module-population changes.",
      {reasonCode: "parent-execution-deleted", executionId},
    );
  }
  if (parent.isCompleted === true) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "A completed planned-job execution cannot accept module-population changes.",
      {reasonCode: "parent-execution-completed", executionId},
    );
  }
  if (parent.isCancelled === true) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "A cancelled planned-job execution cannot accept module-population changes.",
      {reasonCode: "parent-execution-cancelled", executionId},
    );
  }
  return parent;
}

function userCanSubmitDiscipline(
  roles: Set<string>,
  discipline: unknown,
): boolean {
  if (typeof discipline !== "string") return false;
  const canonicalDiscipline = new Set([
    "instrument",
    "ia",
    "iAndA",
    "instrumentationAndAutomation",
    "instrumentationAutomation",
  ]).has(discipline) ? "instrumentation" : discipline;
  const allowed = MODULE_DISCIPLINE_SUBMIT_ROLES[canonicalDiscipline];
  return allowed?.some((role) => roles.has(role)) ?? false;
}

function laneKeyForDiscipline(discipline: unknown): string {
  return laneForModuleDiscipline(discipline);
}

function moduleStatusIsOpenForWork(status: unknown): boolean {
  return status === "notStarted" ||
    status === "inProgress" ||
    status === "draftSaved" ||
    status === "reopened";
}

type RuntimeWorkflowLaneIdentity = {
  laneKey: string;
  laneActivationGeneration: number;
  workflowLaneFirestoreId: string;
};

function workflowLaneIdentityForCreate(args: {
  parent: RuntimePopulationJsonMap;
  module: RuntimePopulationJsonMap;
  executionId: string;
}): RuntimeWorkflowLaneIdentity | null {
  if (args.parent.workflowSchemaVersion !== 1) return null;

  const laneKey = laneKeyForDiscipline(args.module.discipline);

  const suppliedLaneKey = cleanOptionalText(args.module.laneKey);
  if (suppliedLaneKey != null && suppliedLaneKey !== laneKey) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "The supplied module lane does not match its discipline.",
      {
        reasonCode: "workflow-module-lane-mismatch",
        suppliedLaneKey,
        expectedLaneKey: laneKey,
      },
    );
  }

  const laneActivationGeneration = assertInteger(
    args.module.laneActivationGeneration ?? 1,
    "module.laneActivationGeneration",
    1,
  );
  const expectedId = `${args.executionId}_${laneKey}_${laneActivationGeneration}`;
  const suppliedId = assertOptionalDocumentId(
    args.module.workflowLaneFirestoreId,
    "module.workflowLaneFirestoreId",
  );
  if (suppliedId != null && suppliedId !== expectedId) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "The supplied workflow-lane identity is stale or belongs to another lane generation.",
      {
        reasonCode: "workflow-module-lane-identity-mismatch",
        suppliedWorkflowLaneFirestoreId: suppliedId,
        expectedWorkflowLaneFirestoreId: expectedId,
      },
    );
  }

  return {
    laneKey,
    laneActivationGeneration,
    workflowLaneFirestoreId: expectedId,
  };
}

function validateWorkflowLaneForModuleCreate(args: {
  snapshot: RuntimePopulationDocumentSnapshotLike;
  identity: RuntimeWorkflowLaneIdentity;
  executionId: string;
}): void {
  if (!args.snapshot.exists) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "The accountable workflow lane does not exist.",
      {
        reasonCode: "workflow-module-lane-missing",
        workflowLaneFirestoreId: args.identity.workflowLaneFirestoreId,
      },
    );
  }
  const lane = args.snapshot.data() ?? {};
  if (
    cleanOptionalText(lane.workflowId) !== args.executionId ||
    cleanOptionalText(lane.laneKey) !== args.identity.laneKey ||
    lane.activationGeneration !== args.identity.laneActivationGeneration
  ) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The accountable workflow lane identity is internally inconsistent.",
      {
        reasonCode: "workflow-module-lane-corrupt",
        workflowLaneFirestoreId: args.identity.workflowLaneFirestoreId,
      },
    );
  }
  if (lane.statusKey !== "acknowledged") {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "Runtime module population requires an active acknowledged lane.",
      {
        reasonCode: "workflow-module-lane-not-acknowledged",
        workflowLaneFirestoreId: args.identity.workflowLaneFirestoreId,
        statusKey: lane.statusKey ?? null,
      },
    );
  }
}

function isElevatedRuntimeModule(module: RuntimePopulationJsonMap): boolean {
  return module.requiredForClosure === true ||
    module.discipline === "shared" ||
    module.discipline === "safety" ||
    module.safetyClass !== "normal";
}

function actorClaims(module: RuntimePopulationJsonMap): RuntimePopulationJsonMap {
  const claims: RuntimePopulationJsonMap = {};
  for (const field of ACTOR_UID_FIELDS) {
    const value = cleanOptionalText(module[field]);
    if (value != null) claims[field] = value;
  }
  return claims;
}

function actorMismatches(
  module: RuntimePopulationJsonMap,
  authUid: string,
): string[] {
  return ACTOR_UID_FIELDS.filter((field) => {
    const value = cleanOptionalText(module[field]);
    return value != null && value !== authUid;
  });
}

function requireLifecycleActorAndTime(
  module: RuntimePopulationJsonMap,
  actorField: string,
  timeField: string,
  status: string,
): void {
  assertDocumentId(module[actorField], `module.${actorField}`);
  if (module[timeField] == null) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `module.${timeField} is required for ${status} state.`,
      {
        reasonCode: "module-lifecycle-provenance-missing",
        status,
        field: timeField,
      },
    );
  }
  assertTimestamp(module[timeField], `module.${timeField}`);
}

function assertTimestampOrder(
  earlier: unknown,
  later: unknown,
  reasonCode: string,
  earlierField: string,
  laterField: string,
): void {
  if (earlier == null || later == null) return;
  const earlierMs = Date.parse(String(earlier));
  const laterMs = Date.parse(String(later));
  if (earlierMs > laterMs) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      `${earlierField} cannot be after ${laterField}.`,
      {reasonCode, earlierField, laterField},
    );
  }
}

function validateLifecycleSnapshot(module: RuntimePopulationJsonMap): void {
  const status = String(module.status);
  const terminalFields = [
    "submittedByUid",
    "submittedAt",
    "acceptedByUid",
    "acceptedAt",
    "reopenedByUid",
    "reopenedAt",
    "notApplicableByUid",
    "notApplicableAt",
  ];

  if (status === "notStarted" || status === "inProgress" || status === "draftSaved") {
    const unexpected = terminalFields.filter((field) => module[field] != null);
    if (unexpected.length > 0) {
      throw new RuntimePopulationValidationError(
        "failed-precondition",
        "An open first-sync module cannot carry terminal lifecycle provenance.",
        {
          reasonCode: "module-lifecycle-history-inconsistent",
          status,
          fields: unexpected,
        },
      );
    }
  } else if (status === "submitted") {
    requireLifecycleActorAndTime(
      module,
      "submittedByUid",
      "submittedAt",
      status,
    );
  } else if (status === "accepted") {
    requireLifecycleActorAndTime(
      module,
      "submittedByUid",
      "submittedAt",
      status,
    );
    requireLifecycleActorAndTime(
      module,
      "acceptedByUid",
      "acceptedAt",
      status,
    );
  } else if (status === "reopened") {
    requireLifecycleActorAndTime(
      module,
      "reopenedByUid",
      "reopenedAt",
      status,
    );
    if (
      module.submittedAt == null &&
      module.acceptedAt == null &&
      module.notApplicableAt == null
    ) {
      throw new RuntimePopulationValidationError(
        "failed-precondition",
        "A reopened first-sync module must retain the prior terminal lifecycle event.",
        {reasonCode: "module-reopen-history-missing"},
      );
    }
  } else if (status === "notApplicable") {
    requireLifecycleActorAndTime(
      module,
      "notApplicableByUid",
      "notApplicableAt",
      status,
    );
  }

  assertTimestampOrder(
    module.createdAt,
    module.updatedAt,
    "module-time-order-invalid",
    "createdAt",
    "updatedAt",
  );
  assertTimestampOrder(
    module.submittedAt,
    module.acceptedAt,
    "module-lifecycle-time-order-invalid",
    "submittedAt",
    "acceptedAt",
  );
  for (const lifecycleTime of [
    "addedAt",
    "submittedAt",
    "acceptedAt",
    "reopenedAt",
    "notApplicableAt",
  ]) {
    assertTimestampOrder(
      module.createdAt,
      module[lifecycleTime],
      "module-lifecycle-time-order-invalid",
      "createdAt",
      lifecycleTime,
    );
    assertTimestampOrder(
      module[lifecycleTime],
      module.updatedAt,
      "module-lifecycle-time-order-invalid",
      lifecycleTime,
      "updatedAt",
    );
  }
}

function validateCreateShape(module: RuntimePopulationJsonMap): void {
  assertCanonicalText(module.moduleTitle, "module.moduleTitle", 500);
  assertCanonicalText(module.assetType, "module.assetType", 100);
  assertInteger(module.assetNumber, "module.assetNumber", 0);
  const moduleChargeNo = assertOptionalInteger(
    module.chargeNoAtEvent,
    "module.chargeNoAtEvent",
    10000,
  );
  if (moduleChargeNo != null && !isFiveDigitChargeNumber(moduleChargeNo)) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      "module.chargeNoAtEvent must contain exactly five digits.",
      {
        reasonCode: "charge-number-invalid",
        fieldName: "module.chargeNoAtEvent",
      },
    );
  }
  assertEnumText(module.status, "module.status", MODULE_STATUSES);
  assertEnumText(module.useMode, "module.useMode", MODULE_USE_MODES);
  assertEnumText(module.discipline, "module.discipline", MODULE_DISCIPLINES);
  assertEnumText(module.safetyClass, "module.safetyClass", MODULE_SAFETY_CLASSES);
  assertBoolean(module.isRequired, "module.isRequired");
  assertBoolean(module.requiredForClosure, "module.requiredForClosure");
  assertBoolean(module.addedDuringExecution, "module.addedDuringExecution");
  assertBoolean(module.requiresFollowUp, "module.requiresFollowUp");
  assertBoolean(module.isDeleted, "module.isDeleted");
  assertInteger(module.displayOrder, "module.displayOrder", 0);
  assertInteger(module.version, "module.version", 1);

  if (module.addedDuringExecution !== true) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "Client-originated module population changes must be classified as runtime additions.",
      {reasonCode: "runtime-module-classification-required"},
    );
  }
  if (module.isDeleted === true) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "A module deleted before its first remote acceptance is not written remotely.",
      {reasonCode: "new-module-already-deleted"},
    );
  }

  for (const field of [
    "templateFirestoreId",
    "templatePackageId",
    "templateVersionId",
    "templateModuleId",
  ]) {
    assertOptionalDocumentId(module[field], `module.${field}`);
  }

  const optionalTextLimits: Record<string, number> = {
    templateName: 500,
    moduleCode: 200,
    moduleDescription: 20_000,
    functionalSection: 500,
    componentGroup: 500,
    subsystem: 500,
    targetRef: 1_000,
    draftNote: 20_000,
    submissionNote: 20_000,
    acceptanceNote: 20_000,
    reopenReason: 20_000,
    notApplicableReason: 20_000,
    pendingIssue: 20_000,
    addedByName: 500,
    addReason: 5_000,
    createdByName: 500,
    updatedByName: 500,
    submittedByName: 500,
    acceptedByName: 500,
    reopenedByName: 500,
    notApplicableByName: 500,
  };
  for (const [field, max] of Object.entries(optionalTextLimits)) {
    assertCanonicalText(module[field], `module.${field}`, max, true);
  }

  assertJsonText(module.moduleSnapshotJson, "module.moduleSnapshotJson", "object");
  assertJsonText(
    module.fieldDefinitionsJson,
    "module.fieldDefinitionsJson",
    "array",
  );
  assertJsonText(module.responsesJson, "module.responsesJson", "array");
  try {
    readFieldDefinitionPayload(module.fieldDefinitionsJson, {
      field: "module.fieldDefinitionsJson",
    });
    readFieldResponsePayload(module.responsesJson, {
      field: "module.responsesJson",
    });
  } catch (error) {
    if (error instanceof PersistedWorkPayloadError) {
      throw new RuntimePopulationValidationError(
        "invalid-argument",
        "Module field definitions and responses must preserve valid structured evidence.",
        {reasonCode: "work-payload-invalid", field: error.field},
      );
    }
    throw error;
  }
  assertJsonText(module.actionsJson, "module.actionsJson", "array");
  try {
    readComponentActionPayload(module.actionsJson, {
      field: "module.actionsJson",
    });
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new RuntimePopulationValidationError(
        "invalid-argument",
        "module.actionsJson contains invalid component-action evidence.",
        {reasonCode: "action-payload-invalid", field: error.field},
      );
    }
    throw error;
  }
  assertJsonText(module.metadataJson, "module.metadataJson", "object", true);
  assertJsonText(
    module.pairedEquipmentJson,
    "module.pairedEquipmentJson",
    "any",
    true,
  );

  for (const field of [
    "targetRefs",
    "procedureRefs",
    "safetyConfirmations",
    "tags",
    "operationalStatePreconditions",
  ]) {
    assertStringArray(module[field], `module.${field}`);
  }

  assertDocumentId(module.createdByUid, "module.createdByUid");
  assertDocumentId(module.addedByUid, "module.addedByUid");
  assertDocumentId(module.updatedByUid, "module.updatedByUid");
  assertTimestamp(module.createdAt, "module.createdAt");
  assertTimestamp(module.addedAt, "module.addedAt");
  assertTimestamp(module.updatedAt, "module.updatedAt");

  for (const field of [
    "submittedByUid",
    "acceptedByUid",
    "reopenedByUid",
    "notApplicableByUid",
  ]) {
    assertOptionalDocumentId(module[field], `module.${field}`);
  }
  for (const field of [
    "submittedAt",
    "acceptedAt",
    "reopenedAt",
    "notApplicableAt",
  ]) {
    assertOptionalTimestamp(module[field], `module.${field}`);
  }

  if (
    module.deletedAt != null ||
    module.deletedByUid != null ||
    module.deletedByName != null ||
    module.deleteReason != null
  ) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "A first remote acceptance cannot carry deletion provenance.",
      {reasonCode: "new-module-delete-provenance-present"},
    );
  }

  validateLifecycleSnapshot(module);

  const payloadBytes = Buffer.byteLength(canonicalJson(module), "utf8");
  if (payloadBytes > MAX_MODULE_PAYLOAD_BYTES) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      "The module payload is too large for governed acceptance.",
      {
        reasonCode: "module-payload-too-large",
        payloadBytes,
        maxBytes: MAX_MODULE_PAYLOAD_BYTES,
      },
    );
  }
}

function parseMutationRequest(data: RuntimePopulationJsonMap): ParsedPopulationMutation {
  const operationRaw = assertCanonicalText(data.operation, "operation", 50);
  if (operationRaw == null || !ALLOWED_OPERATIONS.has(operationRaw)) {
    throw new RuntimePopulationValidationError(
      "invalid-argument",
      "operation must be create or softDelete.",
      {reasonCode: "unsupported-operation", operation: operationRaw},
    );
  }
  const operation = operationRaw as "create" | "softDelete";
  const module = sanitizeClientModule(data.module);
  const moduleId = assertDocumentId(module.firestoreId, "module.firestoreId");
  const executionId = assertDocumentId(
    module.jobExecutionFirestoreId,
    "module.jobExecutionFirestoreId",
  );
  const preservationReason = assertCanonicalText(
    data.preservationReason,
    "preservationReason",
    MAX_PRESERVATION_REASON_LENGTH,
    true,
  );

  if (operation === "create") {
    validateCreateShape(module);
  } else {
    if (module.isDeleted !== true) {
      throw new RuntimePopulationValidationError(
        "invalid-argument",
        "A soft-delete request must contain an isDeleted=true tombstone.",
        {reasonCode: "soft-delete-payload-not-deleted"},
      );
    }
    assertInteger(module.version, "module.version", 1);
    assertDocumentId(module.deletedByUid, "module.deletedByUid");
    assertDocumentId(module.updatedByUid, "module.updatedByUid");
    assertTimestamp(module.deletedAt, "module.deletedAt");
    assertTimestamp(module.updatedAt, "module.updatedAt");
    assertCanonicalText(module.deleteReason, "module.deleteReason", 5_000, true);
  }

  return {
    operation,
    module,
    moduleId,
    executionId,
    preservationReason,
    requestFingerprint: fingerprint(
      operation === "create" ? "jmpc2" : "jmpd2",
      {operation, module, preservationReason},
    ),
  };
}

function validateCreateAuthority(args: {
  module: RuntimePopulationJsonMap;
  authUid: string;
  roles: Set<string>;
  preservationReason: string | null;
}): RuntimePopulationJsonMap {
  const {module, authUid, roles, preservationReason} = args;
  const mismatches = actorMismatches(module, authUid);
  if (mismatches.length > 0) {
    if (!hasAnyRole(roles, MODERATOR_ROLES)) {
      throw new RuntimePopulationValidationError(
        "permission-denied",
        "Only a lifecycle moderator may preserve another actor's offline module history.",
        {
          reasonCode: "module-actor-preservation-role-required",
          fields: mismatches,
        },
      );
    }
    if (preservationReason == null) {
      throw new RuntimePopulationValidationError(
        "invalid-argument",
        "A preservation reason is required when actor history differs from the uploader.",
        {
          reasonCode: "module-actor-preservation-reason-required",
          fields: mismatches,
        },
      );
    }
  }

  const status = String(module.status);
  if (
    (status === "accepted" ||
      status === "reopened" ||
      status === "notApplicable") &&
    !hasAnyRole(roles, MODERATOR_ROLES)
  ) {
    throw new RuntimePopulationValidationError(
      "permission-denied",
      "The signed-in role cannot accept this terminal module lifecycle state.",
      {reasonCode: "module-lifecycle-role-denied", status},
    );
  }
  if (status === "submitted" && !userCanSubmitDiscipline(roles, module.discipline)) {
    throw new RuntimePopulationValidationError(
      "permission-denied",
      "The signed-in role cannot submit this module discipline.",
      {reasonCode: "module-lifecycle-role-denied", status},
    );
  }
  if (isElevatedRuntimeModule(module) && !hasAnyRole(roles, MODERATOR_ROLES)) {
    throw new RuntimePopulationValidationError(
      "permission-denied",
      "Only lifecycle moderators may add closure-critical, shared, safety, or elevated-risk runtime modules.",
      {reasonCode: "elevated-runtime-module-role-required"},
    );
  }

  return {
    uploaderUid: authUid,
    preservationReason,
    preservedActorFields: mismatches,
    originalActorClaims: actorClaims(module),
  };
}

function validateParentIdentity(
  parent: RuntimePopulationJsonMap,
  module: RuntimePopulationJsonMap,
): void {
  if (
    module.assetType !== parent.assetType ||
    module.assetNumber !== parent.assetNumber
  ) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "The module asset identity does not match its parent execution.",
      {
        reasonCode: "parent-asset-mismatch",
        executionAssetType: parent.assetType ?? null,
        executionAssetNumber: parent.assetNumber ?? null,
        moduleAssetType: module.assetType ?? null,
        moduleAssetNumber: module.assetNumber ?? null,
      },
    );
  }

  if (
    parent.chargeNoAtEvent != null &&
    module.chargeNoAtEvent !== parent.chargeNoAtEvent
  ) {
    throw new RuntimePopulationValidationError(
      "failed-precondition",
      "The module charge identity does not match its parent execution.",
      {
        reasonCode: "parent-charge-mismatch",
        executionChargeNoAtEvent: parent.chargeNoAtEvent,
        moduleChargeNoAtEvent: module.chargeNoAtEvent ?? null,
      },
    );
  }
}

function matchingParent(
  module: RuntimePopulationJsonMap,
  executionId: string,
): boolean {
  return cleanOptionalText(module.jobExecutionFirestoreId) === executionId;
}

function validateExistingPopulationAudit(args: {
  auditSnapshot: RuntimePopulationDocumentSnapshotLike;
  moduleId: string;
  actorUid: string;
  operation: "create" | "softDelete";
  requestFingerprint: string;
  acceptedAtPopulationVersion: number;
}): void {
  const {
    auditSnapshot,
    moduleId,
    actorUid,
    operation,
    requestFingerprint,
    acceptedAtPopulationVersion,
  } = args;
  if (!auditSnapshot.exists) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The governed module mutation exists without its immutable server audit.",
      {reasonCode: "population-audit-missing", moduleId, operation},
    );
  }
  const audit = auditSnapshot.data() ?? {};
  let after: RuntimePopulationJsonMap | null = null;
  try {
    const decoded = JSON.parse(String(audit.afterJson ?? ""));
    if (decoded != null && typeof decoded === "object" && !Array.isArray(decoded)) {
      after = decoded as RuntimePopulationJsonMap;
    }
  } catch (_) {
    after = null;
  }
  const expectedAction = operation === "create" ? "create" : "delete";
  if (
    audit.entityType !== "planned_job_module" ||
    audit.entityId !== moduleId ||
    audit.action !== expectedAction ||
    audit.performedByUid !== actorUid ||
    after?.requestFingerprint !== requestFingerprint ||
    after?.modulePopulationVersion !== acceptedAtPopulationVersion ||
    after?.modulePopulationSchemaVersion !== MODULE_POPULATION_SCHEMA_VERSION
  ) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The immutable server audit does not match the governed module mutation.",
      {reasonCode: "population-audit-mismatch", moduleId, operation},
    );
  }
}

function storedAcceptanceVersion(
  module: RuntimePopulationJsonMap,
  fieldName: string,
): number {
  const value = module[fieldName];
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The module has invalid governed population evidence.",
      {reasonCode: "module-population-evidence-invalid", fieldName, value},
    );
  }
  return value;
}

function currentPopulationVersionForReplay(args: {
  parent: RuntimePopulationJsonMap;
  acceptedAtPopulationVersion: number;
  moduleId: string;
  operation: "create" | "softDelete";
}): number {
  const current = modulePopulationVersionFromExecution(args.parent);
  if (current < args.acceptedAtPopulationVersion) {
    throw new RuntimePopulationValidationError(
      "data-loss",
      "The parent population revision regressed below immutable mutation evidence.",
      {
        reasonCode: "parent-population-version-regressed",
        moduleId: args.moduleId,
        operation: args.operation,
        acceptedAtPopulationVersion: args.acceptedAtPopulationVersion,
        currentParentPopulationVersion: current,
      },
    );
  }
  return current;
}

export async function mutateRuntimeJobModulePopulationWithDb(args: {
  db: RuntimePopulationFirestoreLike;
  authUid: string | null;
  data: RuntimePopulationJsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
  afterParentReadForTest?: () => Promise<void>;
  beforeMutationWritesForTest?: () => Promise<void>;
}): Promise<RuntimePopulationMutationResult> {
  const {db, authUid, data} = args;
  if (authUid == null || authUid.trim().length === 0) {
    throw new RuntimePopulationValidationError(
      "unauthenticated",
      "Sign in required.",
    );
  }

  const actorUid = authUid.trim();
  const parsed = parseMutationRequest(data);
  const now = args.now ?? (() => new Date());
  const timestampFromDate =
    args.timestampFromDate ?? ((date: Date) => date.toISOString());

  return db.runTransaction(async (transaction) => {
    const userRef = db.collection("users").doc(actorUid);
    const executionRef = db
      .collection("job_executions")
      .doc(parsed.executionId);
    const moduleRef = db.collection("job_modules").doc(parsed.moduleId);
    const auditRef = db
      .collection("audit_logs")
      .doc(
        parsed.operation === "create"
          ? `server_module_population_create_${parsed.moduleId}`
          : `server_module_population_soft_delete_${parsed.moduleId}`,
      );

    const userSnapshot = await transaction.get(userRef);
    const parentSnapshot = await transaction.get(executionRef);
    const moduleSnapshot = await transaction.get(moduleRef);
    const auditSnapshot = await transaction.get(auditRef);
    const {userData, roles} = validateApprovedUser(userSnapshot);
    const existingParent = validateParentExists(
      parentSnapshot,
      parsed.executionId,
    );

    if (args.afterParentReadForTest != null) {
      await args.afterParentReadForTest();
    }

    const existingModule = moduleSnapshot.exists
      ? moduleSnapshot.data() ?? {}
      : null;

    if (parsed.operation === "create" && existingModule != null) {
      if (!matchingParent(existingModule, parsed.executionId)) {
        throw new RuntimePopulationValidationError(
          "data-loss",
          "The existing module identity belongs to another execution.",
          {reasonCode: "module-parent-mismatch", moduleId: parsed.moduleId},
        );
      }
      if (
        existingModule.populationCreateFingerprint ===
        parsed.requestFingerprint
      ) {
        if (cleanOptionalText(existingModule.populationAcceptedByUid) !== actorUid) {
          throw new RuntimePopulationValidationError(
            "already-exists",
            "The exact module acceptance is owned by another uploader.",
            {
              reasonCode: "population-mutation-owner-mismatch",
              moduleId: parsed.moduleId,
            },
          );
        }
        const acceptedAtPopulationVersion = storedAcceptanceVersion(
          existingModule,
          "parentPopulationVersionAtAcceptance",
        );
        validateExistingPopulationAudit({
          auditSnapshot,
          moduleId: parsed.moduleId,
          actorUid,
          operation: parsed.operation,
          requestFingerprint: parsed.requestFingerprint,
          acceptedAtPopulationVersion,
        });
        const currentParentPopulationVersion = currentPopulationVersionForReplay({
          parent: existingParent,
          acceptedAtPopulationVersion,
          moduleId: parsed.moduleId,
          operation: parsed.operation,
        });
        return {
          ok: true,
          operation: parsed.operation,
          idempotentReplay: true,
          executionId: parsed.executionId,
          moduleId: parsed.moduleId,
          acceptedAtPopulationVersion,
          currentParentPopulationVersion,
          mutationAt:
            cleanOptionalText(existingModule.populationAcceptedAt) ??
            cleanOptionalText(existingModule.createdAt) ??
            now().toISOString(),
          module: {...existingModule, firestoreId: parsed.moduleId},
        };
      }
      throw new RuntimePopulationValidationError(
        "already-exists",
        "A planned-job module with this identity already exists with different content.",
        {reasonCode: "module-identity-conflict", moduleId: parsed.moduleId},
      );
    }

    if (
      parsed.operation === "softDelete" &&
      existingModule != null &&
      existingModule.isDeleted === true
    ) {
      if (!matchingParent(existingModule, parsed.executionId)) {
        throw new RuntimePopulationValidationError(
          "data-loss",
          "The existing module identity belongs to another execution.",
          {reasonCode: "module-parent-mismatch", moduleId: parsed.moduleId},
        );
      }
      if (
        existingModule.populationSoftDeleteFingerprint ===
        parsed.requestFingerprint
      ) {
        if (cleanOptionalText(existingModule.populationDeletedByUid) !== actorUid) {
          throw new RuntimePopulationValidationError(
            "already-exists",
            "The exact module deletion is owned by another uploader.",
            {
              reasonCode: "population-mutation-owner-mismatch",
              moduleId: parsed.moduleId,
            },
          );
        }
        const acceptedAtPopulationVersion = storedAcceptanceVersion(
          existingModule,
          "parentPopulationVersionAtMutation",
        );
        validateExistingPopulationAudit({
          auditSnapshot,
          moduleId: parsed.moduleId,
          actorUid,
          operation: parsed.operation,
          requestFingerprint: parsed.requestFingerprint,
          acceptedAtPopulationVersion,
        });
        const currentParentPopulationVersion = currentPopulationVersionForReplay({
          parent: existingParent,
          acceptedAtPopulationVersion,
          moduleId: parsed.moduleId,
          operation: parsed.operation,
        });
        return {
          ok: true,
          operation: parsed.operation,
          idempotentReplay: true,
          executionId: parsed.executionId,
          moduleId: parsed.moduleId,
          acceptedAtPopulationVersion,
          currentParentPopulationVersion,
          mutationAt:
            cleanOptionalText(existingModule.populationDeletedAt) ??
            cleanOptionalText(existingModule.deletedAt) ??
            now().toISOString(),
          module: {...existingModule, firestoreId: parsed.moduleId},
        };
      }
      throw new RuntimePopulationValidationError(
        "failed-precondition",
        "The module is already deleted by a different governed mutation.",
        {
          reasonCode: "module-already-deleted-conflict",
          moduleId: parsed.moduleId,
        },
      );
    }

    if (auditSnapshot.exists) {
      throw new RuntimePopulationValidationError(
        "data-loss",
        "A reserved server population-audit identity already exists without a matching mutation.",
        {
          reasonCode: "population-audit-preexisting",
          moduleId: parsed.moduleId,
          operation: parsed.operation,
        },
      );
    }

    const parent = validateOpenParent(parentSnapshot, parsed.executionId);
    const workflowLaneIdentity = parsed.operation === "create"
      ? workflowLaneIdentityForCreate({
          parent,
          module: parsed.module,
          executionId: parsed.executionId,
        })
      : null;
    if (workflowLaneIdentity != null) {
      const laneRef = db
        .collection("job_lanes")
        .doc(workflowLaneIdentity.workflowLaneFirestoreId);
      const laneSnapshot = await transaction.get(laneRef);
      validateWorkflowLaneForModuleCreate({
        snapshot: laneSnapshot,
        identity: workflowLaneIdentity,
        executionId: parsed.executionId,
      });
    }

    const previousPopulationVersion = modulePopulationVersionFromExecution(parent);
    const nextPopulationVersion = previousPopulationVersion + 1;
    const mutationAtDate = now();
    const mutationAt = mutationAtDate.toISOString();

    if (args.beforeMutationWritesForTest != null) {
      await args.beforeMutationWritesForTest();
    }

    if (parsed.operation === "create") {
      validateParentIdentity(parent, parsed.module);
      const preservation = validateCreateAuthority({
        module: parsed.module,
        authUid: actorUid,
        roles,
        preservationReason: parsed.preservationReason,
      });

      const acceptedModule: RuntimePopulationJsonMap = {
        ...parsed.module,
        firestoreId: parsed.moduleId,
        jobExecutionFirestoreId: parsed.executionId,
        laneKey:
          workflowLaneIdentity?.laneKey ?? parsed.module.laneKey ?? null,
        laneActivationGeneration:
          workflowLaneIdentity?.laneActivationGeneration ??
          parsed.module.laneActivationGeneration ??
          1,
        workflowLaneFirestoreId:
          workflowLaneIdentity?.workflowLaneFirestoreId ??
          parsed.module.workflowLaneFirestoreId ??
          null,
        isOpenForWork: moduleStatusIsOpenForWork(parsed.module.status),
        populationCreateFingerprint: parsed.requestFingerprint,
        populationAcceptedAt: mutationAt,
        populationAcceptedByUid: actorUid,
        populationMutationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
        populationPreservationReason: parsed.preservationReason,
        populationOriginalActorClaims: preservation.originalActorClaims,
        parentPopulationVersionAtAcceptance: nextPopulationVersion,
      };
      transaction.set(moduleRef, acceptedModule);
      transaction.update(executionRef, {
        modulePopulationVersion: nextPopulationVersion,
        modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
        modulePopulationUpdatedAt: mutationAt,
        modulePopulationUpdatedByUid: actorUid,
        modulePopulationLastMutation: "create",
        modulePopulationLastModuleId: parsed.moduleId,
      });
      transaction.set(auditRef, {
        entityType: "planned_job_module",
        entityId: parsed.moduleId,
        action: "create",
        performedByUid: actorUid,
        performedByName:
          cleanOptionalText(userData.name) ??
          cleanOptionalText(userData.email) ??
          actorUid,
        timestamp: timestampFromDate(mutationAtDate),
        reason: parsed.preservationReason == null ? null : "offlineEvidencePreservation",
        reasonNotes:
          parsed.preservationReason ??
          "Server accepted the runtime module and advanced the parent population fence atomically.",
        summary: "Planned-job runtime module accepted by population fence",
        severity: "medium",
        beforeJson: null,
        afterJson: JSON.stringify({
          firestoreId: parsed.moduleId,
          jobExecutionFirestoreId: parsed.executionId,
          status: parsed.module.status ?? null,
          requiredForClosure: parsed.module.requiredForClosure === true,
          addedDuringExecution: true,
          version: parsed.module.version ?? null,
          actorClaims: preservation.originalActorClaims,
          preservedActorFields: preservation.preservedActorFields,
          uploaderUid: actorUid,
          modulePopulationVersion: nextPopulationVersion,
          modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
          requestFingerprint: parsed.requestFingerprint,
        }),
      });

      return {
        ok: true,
        operation: parsed.operation,
        idempotentReplay: false,
        executionId: parsed.executionId,
        moduleId: parsed.moduleId,
        acceptedAtPopulationVersion: nextPopulationVersion,
        currentParentPopulationVersion: nextPopulationVersion,
        mutationAt,
        module: acceptedModule,
      };
    }

    if (!hasAnyRole(roles, MODERATOR_ROLES)) {
      throw new RuntimePopulationValidationError(
        "permission-denied",
        "Only lifecycle moderators may delete planned-job modules.",
        {reasonCode: "module-delete-role-required"},
      );
    }
    if (
      cleanOptionalText(parsed.module.deletedByUid) !== actorUid ||
      cleanOptionalText(parsed.module.updatedByUid) !== actorUid
    ) {
      throw new RuntimePopulationValidationError(
        "permission-denied",
        "Module delete actors must match the signed-in user.",
        {reasonCode: "module-delete-actor-mismatch"},
      );
    }
    if (existingModule == null) {
      throw new RuntimePopulationValidationError(
        "not-found",
        "The planned-job module to delete does not exist.",
        {reasonCode: "module-missing", moduleId: parsed.moduleId},
      );
    }
    if (!matchingParent(existingModule, parsed.executionId)) {
      throw new RuntimePopulationValidationError(
        "data-loss",
        "The module parent identity does not match the delete request.",
        {reasonCode: "module-parent-mismatch", moduleId: parsed.moduleId},
      );
    }
    validateParentIdentity(parent, existingModule);

    const currentModuleVersion = assertInteger(
      existingModule.version,
      "existingModule.version",
      1,
    );
    const requestedModuleVersion = assertInteger(
      parsed.module.version,
      "module.version",
      1,
    );
    if (requestedModuleVersion <= currentModuleVersion) {
      throw new RuntimePopulationValidationError(
        "failed-precondition",
        "The module tombstone is stale; pull latest module state before deleting.",
        {
          reasonCode: "module-delete-version-stale",
          currentModuleVersion,
          requestedModuleVersion,
        },
      );
    }

    const deletedModule: RuntimePopulationJsonMap = {
      ...existingModule,
      isDeleted: true,
      deletedAt: parsed.module.deletedAt ?? mutationAt,
      deletedByUid: actorUid,
      deletedByName: parsed.module.deletedByName ?? null,
      deleteReason: parsed.module.deleteReason ?? null,
      updatedAt: parsed.module.updatedAt ?? mutationAt,
      updatedByUid: actorUid,
      updatedByName: parsed.module.updatedByName ?? null,
      version: requestedModuleVersion,
      metadataJson:
        parsed.module.metadataJson ?? existingModule.metadataJson ?? null,
      populationSoftDeleteFingerprint: parsed.requestFingerprint,
      populationDeletedAt: mutationAt,
      populationDeletedByUid: actorUid,
      populationMutationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
      parentPopulationVersionAtMutation: nextPopulationVersion,
    };
    transaction.update(moduleRef, deletedModule);
    transaction.update(executionRef, {
      modulePopulationVersion: nextPopulationVersion,
      modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
      modulePopulationUpdatedAt: mutationAt,
      modulePopulationUpdatedByUid: actorUid,
      modulePopulationLastMutation: "softDelete",
      modulePopulationLastModuleId: parsed.moduleId,
    });
    transaction.set(auditRef, {
      entityType: "planned_job_module",
      entityId: parsed.moduleId,
      action: "delete",
      performedByUid: actorUid,
      performedByName:
        cleanOptionalText(userData.name) ??
        cleanOptionalText(userData.email) ??
        actorUid,
      timestamp: timestampFromDate(mutationAtDate),
      reason: null,
      reasonNotes:
        cleanOptionalText(parsed.module.deleteReason) ??
        "Server soft-deleted the module and advanced the parent population fence atomically.",
      summary: "Planned-job module soft-deleted by population fence",
      severity: "medium",
      beforeJson: JSON.stringify({
        firestoreId: parsed.moduleId,
        jobExecutionFirestoreId: parsed.executionId,
        status: existingModule.status ?? null,
        version: existingModule.version ?? null,
        isDeleted: existingModule.isDeleted === true,
        modulePopulationVersion: previousPopulationVersion,
      }),
      afterJson: JSON.stringify({
        firestoreId: parsed.moduleId,
        jobExecutionFirestoreId: parsed.executionId,
        status: deletedModule.status ?? null,
        version: requestedModuleVersion,
        isDeleted: true,
        modulePopulationVersion: nextPopulationVersion,
        modulePopulationSchemaVersion: MODULE_POPULATION_SCHEMA_VERSION,
        requestFingerprint: parsed.requestFingerprint,
      }),
    });

    return {
      ok: true,
      operation: parsed.operation,
      idempotentReplay: false,
      executionId: parsed.executionId,
      moduleId: parsed.moduleId,
      acceptedAtPopulationVersion: nextPopulationVersion,
      currentParentPopulationVersion: nextPopulationVersion,
      mutationAt,
      module: {...deletedModule, firestoreId: parsed.moduleId},
    };
  });
}
