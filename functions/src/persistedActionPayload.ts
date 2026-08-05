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
const ACTION_SEVERITIES = new Set(["low", "medium", "high", "critical"]);
const ACTION_STATUSES = new Set(["issue", "inProgress", "resolved"]);

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
  requiredText(action.asset, `${field}.asset`);
  requiredText(action.component, `${field}.component`);
  requiredEnum(action.actionType, ACTION_TYPES, `${field}.actionType`);
  requiredEnum(action.severity, ACTION_SEVERITIES, `${field}.severity`);
  optionalEnum(action.replacement, REPLACEMENT_TYPES, `${field}.replacement`);
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
    "metadataJson",
  ]) {
    optionalText(action[optionalField], `${field}.${optionalField}`);
  }
  if (action.updatedAt != null && !validInstant(action.updatedAt)) {
    throw new PersistedActionPayloadError(
      `${field}.updatedAt`,
      "expected timestamp or null",
    );
  }
  return action;
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
