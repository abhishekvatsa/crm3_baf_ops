/**
 * The semantic contract of one published work requirement.
 *
 * Labels, ordering and presentation hints are deliberately excluded. They may
 * change how a requirement is displayed, but they must not change what the
 * operator is being asked to prove.
 */
export type RequirementContract = {
  readonly key: string;
  readonly normalizedKey: string;
  readonly type: string;
  readonly required: boolean;
  readonly unit: string | null;
  readonly options: readonly string[];
  readonly validation: unknown;
  readonly evidence: unknown;
};

export type RequirementContractDifference = {
  readonly field: "type" | "required" | "unit" | "options" | "validation" | "evidence";
  readonly left: unknown;
  readonly right: unknown;
};

const FIELD_KEY_ALIASES = [
  "key",
  "fieldKey",
  "fieldId",
  "id",
  "name",
] as const;

const TYPE_ALIASES: Record<string, string> = {
  text: "text",
  string: "text",
  plaintext: "text",
  longtext: "longText",
  textarea: "longText",
  number: "number",
  numeric: "number",
  numericwithunit: "number",
  boolean: "boolean",
  yesno: "boolean",
  checkbox: "checkbox",
  passfail: "boolean",
  enum: "enum",
  dropdown: "enum",
  devicetagpicklist: "enum",
  procedureref: "enum",
  targetrule: "enum",
  multiselect: "multiSelect",
  multitag: "multiSelect",
  datetime: "dateTime",
  date: "dateTime",
  sectionheader: "display",
  instruction: "display",
  safetygate: "display",
  safetyconfirmation: "display",
};

const EVIDENCE_KEYS = [
  "evidence",
  "evidenceRequirement",
  "evidenceRole",
  "evidenceType",
  "requiresEvidence",
  "requiresPhoto",
  "requiresAttachment",
  "photoRequired",
  "attachmentRequired",
] as const;

const normalizeToken = (value: string): string =>
  value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "");

const normalizeText = (value: string): string =>
  value.trim().toLowerCase().replace(/\s+/g, " ");

const canonicalJsonValue = (value: unknown): unknown => {
  if (value == null || typeof value === "string" ||
      typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  if (Array.isArray(value)) return value.map(canonicalJsonValue);
  if (typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      result[key] = canonicalJsonValue(
        (value as Record<string, unknown>)[key],
      );
    }
    return result;
  }
  return String(value);
};

const parseJsonObject = (value: unknown): unknown => {
  if (value == null) return null;
  if (typeof value === "object" && !Array.isArray(value)) {
    return canonicalJsonValue(value);
  }
  if (typeof value !== "string" || value.trim().length === 0) return null;
  try {
    const parsed = JSON.parse(value);
    return parsed != null && typeof parsed === "object" &&
      !Array.isArray(parsed) ? canonicalJsonValue(parsed) : null;
  } catch (_) {
    return null;
  }
};

const firstText = (
  row: Record<string, unknown>,
  aliases: readonly string[],
): string | null => {
  for (const alias of aliases) {
    if (typeof row[alias] === "string" && row[alias].trim().length > 0) {
      return row[alias].trim();
    }
  }
  return null;
};

export const canonicalRequirementType = (value: unknown): string => {
  if (typeof value !== "string" || value.trim().length === 0) return "text";
  return TYPE_ALIASES[normalizeToken(value)] ?? normalizeToken(value);
};

export const normalizedRequirementKey = (value: unknown): string =>
  typeof value === "string" ? normalizeToken(value) : "";

const evidenceContract = (row: Record<string, unknown>): unknown => {
  const meta = row.meta;
  const metaMap = meta != null && typeof meta === "object" &&
    !Array.isArray(meta) ? meta as Record<string, unknown> : null;
  const selected: Record<string, unknown> = {};
  for (const key of EVIDENCE_KEYS) {
    if (Object.prototype.hasOwnProperty.call(row, key)) selected[key] = row[key];
    else if (metaMap != null && Object.prototype.hasOwnProperty.call(metaMap, key)) {
      selected[key] = metaMap[key];
    }
  }
  return canonicalJsonValue(selected);
};

const optionsContract = (row: Record<string, unknown>): readonly string[] => {
  if (!Array.isArray(row.options)) return [];
  return row.options
    .filter((value): value is string => typeof value === "string")
    .map(normalizeText)
    .sort();
};

export function requirementContractForField(
  value: unknown,
): RequirementContract {
  const row = value as Record<string, unknown>;
  const key = firstText(row, FIELD_KEY_ALIASES) ?? "";
  return {
    key,
    normalizedKey: normalizedRequirementKey(key),
    type: canonicalRequirementType(row.type ?? row.fieldType),
    required: row.required === true || row.isRequired === true,
    unit: typeof row.unit === "string" && row.unit.trim().length > 0
      ? normalizeText(row.unit)
      : null,
    options: optionsContract(row),
    validation: parseJsonObject(row.validation ?? row.validationJson),
    evidence: evidenceContract(row),
  };
}

const equalContractValue = (left: unknown, right: unknown): boolean =>
  JSON.stringify(canonicalJsonValue(left)) ===
  JSON.stringify(canonicalJsonValue(right));

export function compareRequirementContracts(
  left: unknown,
  right: unknown,
): RequirementContractDifference | null {
  const a = requirementContractForField(left);
  const b = requirementContractForField(right);
  const comparisons: Array<[
    RequirementContractDifference["field"],
    unknown,
    unknown,
  ]> = [
    ["type", a.type, b.type],
    ["required", a.required, b.required],
    ["unit", a.unit, b.unit],
    ["options", a.options, b.options],
    ["validation", a.validation, b.validation],
    ["evidence", a.evidence, b.evidence],
  ];
  for (const [field, valueA, valueB] of comparisons) {
    if (!equalContractValue(valueA, valueB)) {
      return {field, left: valueA, right: valueB};
    }
  }
  return null;
}

export function responseTypeMatchesRequirement(
  definition: unknown,
  response: unknown,
): boolean {
  const responseMap = response as Record<string, unknown>;
  if (responseMap.type == null && responseMap.fieldType == null) return true;
  return canonicalRequirementType(
    responseMap.type ?? responseMap.fieldType,
  ) === requirementContractForField(definition).type;
}

export function responseValueMatchesRequirement(
  definition: unknown,
  value: unknown,
): boolean {
  const contract = requirementContractForField(definition);
  if (value == null) return true;
  switch (contract.type) {
  case "number":
    return (typeof value === "number" && Number.isFinite(value)) ||
      (typeof value === "string" &&
        value.trim().length > 0 &&
        Number.isFinite(Number(value.trim())));
  case "boolean":
  case "checkbox":
    return typeof value === "boolean" ||
      (typeof value === "string" &&
        ["true", "false"].includes(normalizeText(value)));
  case "multiSelect":
    return Array.isArray(value) && value.every((entry) => typeof entry === "string");
  case "dateTime":
    return typeof value === "string" && !Number.isNaN(Date.parse(value));
  case "enum":
    if (typeof value !== "string") return false;
    if (contract.options.length === 0) return true;
    return contract.options.includes(normalizeText(value));
  default:
    return typeof value === "string" || typeof value === "number" ||
      typeof value === "boolean" || Array.isArray(value) ||
      (typeof value === "object" && value != null);
  }
}

export function firstRequirementContractDifference(
  definitions: readonly unknown[],
  responses: readonly unknown[],
): {readonly key: string; readonly reason: "type" | "value"} | null {
  const byKey = new Map<string, unknown>();
  for (const definition of definitions) {
    const contract = requirementContractForField(definition);
    if (contract.normalizedKey.length > 0) byKey.set(contract.normalizedKey, definition);
  }
  for (const response of responses) {
    const responseMap = response as Record<string, unknown>;
    const key = firstText(responseMap, FIELD_KEY_ALIASES);
    if (key == null) continue;
    const definition = byKey.get(normalizedRequirementKey(key));
    if (definition == null) continue;
    if (!responseTypeMatchesRequirement(definition, response)) {
      return {key, reason: "type"};
    }
    const value = Object.prototype.hasOwnProperty.call(responseMap, "value")
      ? responseMap.value
      : responseMap.answer;
    if (!responseValueMatchesRequirement(definition, value)) {
      return {key, reason: "value"};
    }
  }
  return null;
}
