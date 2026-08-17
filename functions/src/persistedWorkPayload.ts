export class PersistedWorkPayloadError extends Error {
  readonly field: string;
  readonly detail: string;

  constructor(field: string, detail: string) {
    super(`Invalid persisted work field ${field}: ${detail}.`);
    this.name = "PersistedWorkPayloadError";
    this.field = field;
    this.detail = detail;
  }
}

export type PersistedObjectListPayload = {
  readonly text: string;
  readonly rows: readonly Record<string, unknown>[];
};

const FIELD_KEY_ALIASES = [
  "key",
  "fieldKey",
  "fieldId",
  "id",
  "name",
] as const;

const RESPONSE_KEY_ALIASES = [
  "key",
  "fieldId",
  "fieldKey",
  "id",
  "name",
] as const;

const PAYLOAD_SCHEMA_VERSION = 1;
const FIELD_DEFINITION_FIELDS = new Set([
  "schemaVersion", "key", "fieldKey", "fieldId", "id", "name", "label",
  "title", "type", "fieldType", "required", "isRequired", "unit",
  "options", "version", "validation", "validationJson", "instructionText",
  "hint", "order", "meta", "moduleCode", "moduleId", "templateModuleId",
  "parentModuleCode", "ownerModuleCode", "ownerModuleId",
  "isSafetyCriticalPreset",
]);
const FIELD_RESPONSE_FIELDS = new Set([
  "schemaVersion", "key", "fieldId", "fieldKey", "id", "name",
  "fieldLabel", "label", "title", "fieldType", "type", "value", "answer",
]);

const SUPPORTED_FIELD_TYPES = new Set([
  "text",
  "string",
  "plaintext",
  "longtext",
  "textarea",
  "number",
  "numeric",
  "numericwithunit",
  "boolean",
  "yesno",
  "checkbox",
  "passfail",
  "enum",
  "dropdown",
  "devicetagpicklist",
  "procedureref",
  "targetrule",
  "multiselect",
  "multitag",
  "datetime",
  "date",
  "sectionheader",
  "instruction",
  "safetygate",
  "safetyconfirmation",
]);

const hasOwn = (value: Record<string, unknown>, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(value, key);

const normalizeKey = (value: string): string =>
  value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "");

const assertPayloadSchemaVersion = (
  row: Record<string, unknown>,
  field: string,
): void => {
  if (!hasOwn(row, "schemaVersion")) return;
  if (row.schemaVersion !== PAYLOAD_SCHEMA_VERSION) {
    throw new PersistedWorkPayloadError(
      `${field}.schemaVersion`,
      `supported payload schema version is ${PAYLOAD_SCHEMA_VERSION}`,
    );
  }
};

const rejectUnknownFields = (
  row: Record<string, unknown>,
  allowed: ReadonlySet<string>,
  field: string,
): void => {
  const unknown = Object.keys(row).find((key) => !allowed.has(key));
  if (unknown != null) {
    throw new PersistedWorkPayloadError(
      `${field}.${unknown}`,
      "unregistered extension field",
    );
  }
};

const assertBoundedJsonValue = (
  value: unknown,
  field: string,
  depth = 0,
): void => {
  if (depth > 6) {
    throw new PersistedWorkPayloadError(field, "JSON nesting exceeds 6 levels");
  }
  if (value == null || typeof value === "boolean") return;
  if (typeof value === "number") {
    if (Number.isFinite(value)) return;
    throw new PersistedWorkPayloadError(field, "JSON number must be finite");
  }
  if (typeof value === "string") {
    if (value.length <= 8192) return;
    throw new PersistedWorkPayloadError(field, "JSON string exceeds 8192 characters");
  }
  if (Array.isArray(value)) {
    if (value.length > 128) {
      throw new PersistedWorkPayloadError(field, "JSON array exceeds 128 entries");
    }
    value.forEach((entry, index) =>
      assertBoundedJsonValue(entry, `${field}[${index}]`, depth + 1));
    return;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length > 128) {
      throw new PersistedWorkPayloadError(field, "JSON object exceeds 128 fields");
    }
    for (const [key, entry] of entries) {
      if (key.trim().length === 0 || key.length > 128) {
        throw new PersistedWorkPayloadError(field, "invalid JSON object key");
      }
      assertBoundedJsonValue(entry, `${field}.${key}`, depth + 1);
    }
    return;
  }
  throw new PersistedWorkPayloadError(field, "unsupported JSON value");
};

const assertBoundedJson = (value: unknown, field: string): void => {
  assertBoundedJsonValue(value, field);
  if (Buffer.byteLength(JSON.stringify(value), "utf8") > 32768) {
    throw new PersistedWorkPayloadError(field, "encoded JSON exceeds 32768 bytes");
  }
};

const requiredAliasedText = (
  value: Record<string, unknown>,
  aliases: readonly string[],
  field: string,
): string => {
  for (const alias of aliases) {
    const candidate = value[alias];
    if (typeof candidate === "string" && candidate.trim().length > 0) {
      return candidate.trim();
    }
  }
  throw new PersistedWorkPayloadError(
    field,
    `required non-empty string (${aliases.join("/")})`,
  );
};

const assertOptionalText = (
  value: unknown,
  field: string,
): void => {
  if (value != null && typeof value !== "string") {
    throw new PersistedWorkPayloadError(field, "expected string or null");
  }
};

const assertOptionalFieldType = (
  value: unknown,
  field: string,
): void => {
  if (value == null) return;
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    !SUPPORTED_FIELD_TYPES.has(normalizeKey(value))
  ) {
    throw new PersistedWorkPayloadError(field, "unknown field type");
  }
};

const assertOptionalStringList = (
  value: unknown,
  field: string,
): void => {
  if (value == null) return;
  if (
    !Array.isArray(value) ||
    value.some(
      (entry) => typeof entry !== "string" || entry.trim().length === 0,
    )
  ) {
    throw new PersistedWorkPayloadError(
      field,
      "expected non-empty string array or null",
    );
  }
};

const assertOptionalObject = (
  value: unknown,
  field: string,
): void => {
  if (value == null) return;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new PersistedWorkPayloadError(field, "expected JSON object or null");
  }
  assertBoundedJson(value, field);
};

const assertValidationJson = (
  value: unknown,
  field: string,
): void => {
  if (value == null) return;
  if (typeof value !== "string") {
    throw new PersistedWorkPayloadError(field, "expected JSON object string");
  }
  if (value.trim().length === 0) return;
  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch (_) {
    throw new PersistedWorkPayloadError(field, "malformed JSON");
  }
  assertOptionalObject(decoded, field);
};

const asObject = (
  value: unknown,
  field: string,
): Record<string, unknown> => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new PersistedWorkPayloadError(field, "expected JSON object");
  }
  return value as Record<string, unknown>;
};

const assertFieldDefinition = (
  value: unknown,
  field: string,
): {readonly row: Record<string, unknown>; readonly key: string} => {
  const row = asObject(value, field);
  assertPayloadSchemaVersion(row, field);
  rejectUnknownFields(row, FIELD_DEFINITION_FIELDS, field);
  const key = requiredAliasedText(row, FIELD_KEY_ALIASES, `${field}.key`);

  for (const labelField of [
    "label", "title", "hint", "moduleCode", "moduleId", "templateModuleId",
    "parentModuleCode", "ownerModuleCode", "ownerModuleId",
  ]) {
    assertOptionalText(row[labelField], `${field}.${labelField}`);
  }
  for (const typeField of ["type", "fieldType"]) {
    assertOptionalFieldType(row[typeField], `${field}.${typeField}`);
  }
  for (const requiredField of ["required", "isRequired"]) {
    if (row[requiredField] != null && typeof row[requiredField] !== "boolean") {
      throw new PersistedWorkPayloadError(
        `${field}.${requiredField}`,
        "expected boolean or null",
      );
    }
  }
  if (
    row.isSafetyCriticalPreset != null &&
    typeof row.isSafetyCriticalPreset !== "boolean"
  ) {
    throw new PersistedWorkPayloadError(
      `${field}.isSafetyCriticalPreset`,
      "expected boolean or null",
    );
  }
  if (
    typeof row.required === "boolean" &&
    typeof row.isRequired === "boolean" &&
    row.required !== row.isRequired
  ) {
    throw new PersistedWorkPayloadError(
      `${field}.required`,
      "conflicts with isRequired",
    );
  }

  assertOptionalText(row.unit, `${field}.unit`);
  assertOptionalText(row.instructionText, `${field}.instructionText`);
  assertOptionalStringList(row.options, `${field}.options`);
  assertOptionalObject(row.validation, `${field}.validation`);
  assertOptionalObject(row.meta, `${field}.meta`);
  assertValidationJson(row.validationJson, `${field}.validationJson`);

  if (
    row.order != null &&
    (typeof row.order !== "number" || !Number.isSafeInteger(row.order))
  ) {
    throw new PersistedWorkPayloadError(
      `${field}.order`,
      "expected integer or null",
    );
  }
  if (
    row.version != null &&
    (typeof row.version !== "number" ||
      !Number.isSafeInteger(row.version) ||
      row.version < 1)
  ) {
    throw new PersistedWorkPayloadError(
      `${field}.version`,
      "expected integer >= 1 or null",
    );
  }
  return {row, key};
};

const assertFieldResponse = (
  value: unknown,
  field: string,
): {readonly row: Record<string, unknown>; readonly key: string} => {
  const row = asObject(value, field);
  assertPayloadSchemaVersion(row, field);
  rejectUnknownFields(row, FIELD_RESPONSE_FIELDS, field);
  const key = requiredAliasedText(row, RESPONSE_KEY_ALIASES, `${field}.key`);
  if (!hasOwn(row, "value") && !hasOwn(row, "answer")) {
    throw new PersistedWorkPayloadError(
      `${field}.value`,
      "required value/answer field",
    );
  }
  for (const labelField of ["fieldLabel", "label"]) {
    assertOptionalText(row[labelField], `${field}.${labelField}`);
  }
  for (const typeField of ["fieldType", "type"]) {
    assertOptionalFieldType(row[typeField], `${field}.${typeField}`);
  }
  assertOptionalText(row.title, `${field}.title`);
  assertBoundedJson(hasOwn(row, "value") ? row.value : row.answer, `${field}.value`);
  return {row, key};
};

const readObjectListPayload = (
  value: unknown,
  options: {
    readonly field: string;
    readonly allowMissing?: boolean;
    readonly assertRow: (
      value: unknown,
      field: string,
    ) => {readonly row: Record<string, unknown>; readonly key: string};
  },
): PersistedObjectListPayload => {
  if (value == null && options.allowMissing === true) {
    return {text: "[]", rows: []};
  }
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new PersistedWorkPayloadError(
      options.field,
      "required JSON array string",
    );
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch (_) {
    throw new PersistedWorkPayloadError(options.field, "malformed JSON");
  }
  if (!Array.isArray(decoded)) {
    throw new PersistedWorkPayloadError(options.field, "expected JSON array");
  }

  const keys = new Set<string>();
  const rows = decoded.map((entry, index) => {
    const parsed = options.assertRow(
      entry,
      `${options.field}[${index}]`,
    );
    const normalized = normalizeKey(parsed.key);
    if (keys.has(normalized)) {
      throw new PersistedWorkPayloadError(
        `${options.field}[${index}].key`,
        `duplicate key ${parsed.key}`,
      );
    }
    keys.add(normalized);
    return parsed.row;
  });
  return {text: value, rows};
};

export const readFieldDefinitionPayload = (
  value: unknown,
  options: {readonly field: string; readonly allowMissing?: boolean},
): PersistedObjectListPayload => readObjectListPayload(value, {
  ...options,
  assertRow: assertFieldDefinition,
});

export const readFieldResponsePayload = (
  value: unknown,
  options: {readonly field: string; readonly allowMissing?: boolean},
): PersistedObjectListPayload => readObjectListPayload(value, {
  ...options,
  assertRow: assertFieldResponse,
});
