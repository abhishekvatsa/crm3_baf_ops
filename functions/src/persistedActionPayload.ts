export class PersistedActionPayloadError extends Error {
  readonly field: string;
  readonly detail: string;

  constructor(field: string, detail: string) {
    super(`Invalid persisted component-action field ${field}: ${detail}.`);
    this.name = "PersistedActionPayloadError";
    this.field = field;
    this.detail = detail;
  }
}

export type ComponentActionPayload = {
  readonly text: string;
  readonly rows: readonly Record<string, unknown>[];
};

const ACTION_TYPES = new Set(["issue", "repair", "replacement", "inspection"]);
const REPLACEMENT_TYPES = new Set(["newPart", "repaired", "revised"]);
const BURNER_BLOCK_SUPPLY_MODES = new Set(["sailRed", "purchased"]);
const ACTION_SEVERITIES = new Set(["low", "medium", "high", "critical"]);
const ACTION_STATUSES = new Set(["issue", "inProgress", "resolved"]);
const PAYLOAD_SCHEMA_VERSION = 1;
const ACTION_FIELDS = new Set([
  "schemaVersion", "id", "asset", "component", "hierarchyPath",
  "assetHierarchyRef", "system", "subsystem", "subComponent", "tag",
  "instance", "actionType", "action", "replacement", "issue", "resolution",
  "remarks", "templateFieldKey", "isAutoResolved", "status", "createdAt",
  "severity", "performedBy", "updatedAt", "version", "metadataJson",
  "attendanceSessionId", "burnerPosition", "burnerActionCode",
  "burnerOutcome", "burnerMicroampReading", "burnerBlockSupplyMode",
  "burnerBlockSupplierName", "burnerBlockPurchaseOrderNumber",
]);

const requiredText = (value: unknown, field: string): void => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new PersistedActionPayloadError(field, "required non-empty string");
  }
};

const optionalText = (value: unknown, field: string): void => {
  if (value != null && typeof value !== "string") {
    throw new PersistedActionPayloadError(field, "expected string or null");
  }
};

const assertBoundedJsonValue = (
  value: unknown,
  field: string,
  depth = 0,
): void => {
  if (depth > 6) {
    throw new PersistedActionPayloadError(field, "JSON nesting exceeds 6 levels");
  }
  if (value == null || typeof value === "boolean") return;
  if (typeof value === "number") {
    if (Number.isFinite(value)) return;
    throw new PersistedActionPayloadError(field, "JSON number must be finite");
  }
  if (typeof value === "string") {
    if (value.length <= 8192) return;
    throw new PersistedActionPayloadError(field, "JSON string exceeds 8192 characters");
  }
  if (Array.isArray(value)) {
    if (value.length > 128) {
      throw new PersistedActionPayloadError(field, "JSON array exceeds 128 entries");
    }
    value.forEach((entry, index) =>
      assertBoundedJsonValue(entry, `${field}[${index}]`, depth + 1));
    return;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length > 128) {
      throw new PersistedActionPayloadError(field, "JSON object exceeds 128 fields");
    }
    for (const [key, entry] of entries) {
      if (key.trim().length === 0 || key.length > 128) {
        throw new PersistedActionPayloadError(field, "invalid JSON object key");
      }
      assertBoundedJsonValue(entry, `${field}.${key}`, depth + 1);
    }
    return;
  }
  throw new PersistedActionPayloadError(field, "unsupported JSON value");
};

const assertBoundedJson = (value: unknown, field: string): void => {
  assertBoundedJsonValue(value, field);
  if (Buffer.byteLength(JSON.stringify(value), "utf8") > 32768) {
    throw new PersistedActionPayloadError(field, "encoded JSON exceeds 32768 bytes");
  }
};

const requiredEnum = (
  value: unknown,
  allowed: ReadonlySet<string>,
  field: string,
): void => {
  if (typeof value !== "string" || !allowed.has(value)) {
    throw new PersistedActionPayloadError(field, "unknown enum value");
  }
};

const optionalEnum = (
  value: unknown,
  allowed: ReadonlySet<string>,
  field: string,
): void => {
  if (value != null) requiredEnum(value, allowed, field);
};

const normalizedActionType = (value: unknown): unknown =>
  value === "inspect" ? "inspection" : value;

const validInstant = (value: unknown): boolean =>
  typeof value === "string" &&
  value.trim().length > 0 &&
  !Number.isNaN(Date.parse(value));

const assertAction = (
  value: unknown,
  field: string,
): Record<string, unknown> => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new PersistedActionPayloadError(field, "expected JSON object");
  }
  const action = value as Record<string, unknown>;
  if (Object.prototype.hasOwnProperty.call(action, "schemaVersion") &&
      action.schemaVersion !== PAYLOAD_SCHEMA_VERSION) {
    throw new PersistedActionPayloadError(
      `${field}.schemaVersion`,
      `supported payload schema version is ${PAYLOAD_SCHEMA_VERSION}`,
    );
  }
  const unknown = Object.keys(action).find((key) => !ACTION_FIELDS.has(key));
  if (unknown != null) {
    throw new PersistedActionPayloadError(
      `${field}.${unknown}`,
      "unregistered extension field",
    );
  }
  requiredText(action.asset, `${field}.asset`);
  requiredText(action.component, `${field}.component`);
  const rawActionType = action.actionType ?? action.action;
  if (action.actionType != null && action.action != null &&
      normalizedActionType(action.actionType) !== normalizedActionType(action.action)) {
    throw new PersistedActionPayloadError(
      `${field}.actionType`,
      "conflicts with legacy action alias",
    );
  }
  requiredEnum(
    normalizedActionType(rawActionType),
    ACTION_TYPES,
    `${field}.actionType`,
  );
  requiredEnum(action.severity, ACTION_SEVERITIES, `${field}.severity`);
  optionalEnum(action.replacement, REPLACEMENT_TYPES, `${field}.replacement`);
  optionalEnum(
    action.burnerBlockSupplyMode,
    BURNER_BLOCK_SUPPLY_MODES,
    `${field}.burnerBlockSupplyMode`,
  );
  optionalEnum(action.status, ACTION_STATUSES, `${field}.status`);

  if (typeof action.isAutoResolved !== "boolean") {
    throw new PersistedActionPayloadError(
      `${field}.isAutoResolved`,
      "required boolean",
    );
  }
  if (!validInstant(action.createdAt)) {
    throw new PersistedActionPayloadError(
      `${field}.createdAt`,
      "required timestamp",
    );
  }
  if (
    typeof action.version !== "number" ||
    !Number.isSafeInteger(action.version) ||
    action.version < 1
  ) {
    throw new PersistedActionPayloadError(
      `${field}.version`,
      "required integer >= 1",
    );
  }

  if (action.hierarchyPath != null) {
    if (
      !Array.isArray(action.hierarchyPath) ||
      action.hierarchyPath.some(
        (item) => typeof item !== "string" || item.trim().length === 0,
      )
    ) {
      throw new PersistedActionPayloadError(
        `${field}.hierarchyPath`,
        "expected non-empty string array or null",
      );
    }
  }

  for (const optionalField of [
    "id",
    "system",
    "subsystem",
    "subComponent",
    "tag",
    "instance",
    "issue",
    "resolution",
    "remarks",
    "templateFieldKey",
    "performedBy",
    "attendanceSessionId",
    "burnerActionCode",
    "burnerOutcome",
    "burnerBlockSupplierName",
    "burnerBlockPurchaseOrderNumber",
  ]) {
    optionalText(action[optionalField], `${field}.${optionalField}`);
  }
  for (const provenanceField of [
    "burnerBlockSupplierName",
    "burnerBlockPurchaseOrderNumber",
  ]) {
    const value = action[provenanceField];
    if (typeof value === "string" &&
        (value.trim().length === 0 || value.trim().length > 160)) {
      throw new PersistedActionPayloadError(
        `${field}.${provenanceField}`,
        "expected 1-160 characters or null",
      );
    }
  }
  if (action.updatedAt != null && !validInstant(action.updatedAt)) {
    throw new PersistedActionPayloadError(
      `${field}.updatedAt`,
      "expected timestamp or null",
    );
  }
  if (action.assetHierarchyRef != null) {
    if (typeof action.assetHierarchyRef !== "object" ||
        Array.isArray(action.assetHierarchyRef)) {
      throw new PersistedActionPayloadError(
        `${field}.assetHierarchyRef`,
        "expected JSON object or null",
      );
    }
    assertBoundedJson(action.assetHierarchyRef, `${field}.assetHierarchyRef`);
  }
  if (action.metadataJson != null) {
    optionalText(action.metadataJson, `${field}.metadataJson`);
    if ((action.metadataJson as string).trim().length === 0) {
      throw new PersistedActionPayloadError(
        `${field}.metadataJson`,
        "expected non-empty JSON object string",
      );
    }
    let metadata: unknown;
    try {
      metadata = JSON.parse(action.metadataJson as string);
    } catch (_) {
      throw new PersistedActionPayloadError(
        `${field}.metadataJson`,
        "malformed JSON object string",
      );
    }
    if (metadata == null || typeof metadata !== "object" || Array.isArray(metadata)) {
      throw new PersistedActionPayloadError(
        `${field}.metadataJson`,
        "expected JSON object string",
      );
    }
    assertBoundedJson(metadata, `${field}.metadataJson`);
  }
  if (action.burnerPosition != null &&
      (typeof action.burnerPosition !== "number" ||
        !Number.isSafeInteger(action.burnerPosition) ||
        action.burnerPosition < 1 || action.burnerPosition > 8)) {
    throw new PersistedActionPayloadError(
      `${field}.burnerPosition`,
      "expected integer between 1 and 8",
    );
  }
  if (action.burnerMicroampReading != null &&
      (typeof action.burnerMicroampReading !== "number" ||
        !Number.isFinite(action.burnerMicroampReading) ||
        action.burnerMicroampReading < 0 ||
        action.burnerMicroampReading > 1000000)) {
    throw new PersistedActionPayloadError(
      `${field}.burnerMicroampReading`,
      "expected finite number between 0 and 1000000",
    );
  }
  const burnerAttendanceEvidence = [
    action.attendanceSessionId,
    action.burnerActionCode,
    action.burnerOutcome,
    action.burnerMicroampReading,
  ];
  const hasBurnerAttendanceEvidence = burnerAttendanceEvidence.some(
    (entry) => entry != null,
  );
  if (hasBurnerAttendanceEvidence &&
      (action.attendanceSessionId == null || action.burnerPosition == null ||
        action.burnerActionCode == null || action.burnerOutcome == null)) {
    throw new PersistedActionPayloadError(
      `${field}.burnerEvidence`,
      "burner evidence is incomplete",
    );
  }
  const hasBurnerBlockLifecycleEvidence = [
    action.burnerBlockSupplyMode,
    action.burnerBlockSupplierName,
    action.burnerBlockPurchaseOrderNumber,
  ].some((entry) => entry != null);
  if (hasBurnerBlockLifecycleEvidence) {
    if (action.burnerBlockSupplyMode == null ||
        action.burnerPosition == null ||
        normalizedActionType(rawActionType) !== "replacement" ||
        action.replacement == null ||
        action.status !== "resolved" ||
        !isFurnaceBurnerBlockTarget(action)) {
      throw new PersistedActionPayloadError(
        `${field}.burnerBlockLifecycle`,
        "requires a resolved, numbered governed Furnace burner-block replacement and replacement disposition",
      );
    }
    if (action.burnerBlockSupplyMode !== "purchased" &&
        (action.burnerBlockSupplierName != null ||
          action.burnerBlockPurchaseOrderNumber != null)) {
      throw new PersistedActionPayloadError(
        `${field}.burnerBlockSupplyMode`,
        "supplier and purchase-order evidence is only valid for purchased burner blocks",
      );
    }
  }
  if (action.burnerPosition != null &&
      !hasBurnerAttendanceEvidence &&
      !hasBurnerBlockLifecycleEvidence) {
    throw new PersistedActionPayloadError(
      `${field}.burnerPosition`,
      "requires burner attendance or burner-block lifecycle evidence",
    );
  }
  return action;
};

const isFurnaceBurnerBlockTarget = (
  action: Record<string, unknown>,
): boolean => {
  const reference = action.assetHierarchyRef;
  if (reference == null || typeof reference !== "object" ||
      Array.isArray(reference)) return false;
  const raw = reference as Record<string, unknown>;
  const classIdentity = `${String(raw.assetClassCode ?? "")} ` +
    `${String(raw.assetClassName ?? "")}`;
  if (!classIdentity.toLowerCase().includes("furnace")) return false;
  const path = Array.isArray(raw.hierarchyPath) ? raw.hierarchyPath : [];
  const targetIdentity = [
    action.component,
    raw.nodeName,
    ...path,
  ].map((value) => String(value ?? "")).join(" ").toLowerCase();
  return targetIdentity.includes("burner block") ||
    targetIdentity.includes("firing tube");
};

export const readComponentActionPayload = (
  value: unknown,
  options: {readonly field: string; readonly allowMissing?: boolean},
): ComponentActionPayload => {
  if (value == null && options.allowMissing === true) {
    return {text: "[]", rows: []};
  }
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new PersistedActionPayloadError(
      options.field,
      "required JSON array string",
    );
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch (_) {
    throw new PersistedActionPayloadError(options.field, "malformed JSON");
  }
  if (!Array.isArray(decoded)) {
    throw new PersistedActionPayloadError(options.field, "expected JSON array");
  }

  return {
    text: value,
    rows: decoded.map((row, index) =>
      assertAction(row, `${options.field}[${index}]`)),
  };
};
