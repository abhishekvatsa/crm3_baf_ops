import {WorkflowError} from "./errors";
import {JsonMap} from "./types";
import {stableJson} from "./utils";

export interface InspectionReadingField extends JsonMap {
  readonly id: string;
  readonly label: string;
  readonly valueType: "number" | "boolean" | "text" | "choice" | "date";
  readonly unit: string | null;
  readonly choiceValues: readonly string[];
  readonly minimumValue: number | null;
  readonly maximumValue: number | null;
}
export interface InspectionReading extends JsonMap {
  readonly fieldId: string;
  readonly valueType: InspectionReadingField["valueType"];
  readonly value: string | number | boolean;
}
export interface MultiReadingValue extends JsonMap {
  readonly schemaVersion: 2;
  readonly readings: readonly InspectionReading[];
}

const fail = (field: string): never => {
  throw new WorkflowError("invalid-argument", `${field} is invalid.`,
    {reasonCode: "inspection-reading-contract-invalid", field});
};
const object = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) fail(field);
  return value as JsonMap;
};
const exact = (data: JsonMap, keys: readonly string[], field: string): void => {
  if (Object.keys(data).sort().join(",") !== [...keys].sort().join(",")) fail(field);
};
const text = (value: unknown, field: string, maximum: number): string => {
  if (typeof value !== "string" || !value || value.trim() !== value || value.length > maximum) fail(field);
  return value as string;
};
const limit = (value: unknown, field: string): number | null => {
  if (value === null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) fail(field);
  return value as number;
};

/** Date-only Gregorian value; no timestamp conversion, rollover or local zone. */
export const isInspectionDate = (value: unknown): value is string => {
  if (typeof value !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  if (year < 1 || month < 1 || month > 12 || day < 1) return false;
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= days[month - 1];
};

export const parseInspectionReadingFields = (value: unknown): readonly InspectionReadingField[] => {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20) fail("readingFields");
  const ids = new Set<string>();
  const labels = new Set<string>();
  return (value as unknown[]).map((raw, index) => {
    const path = `readingFields[${index}]`;
    const data = object(raw, path);
    exact(data, ["id", "label", "valueType", "unit", "choiceValues", "minimumValue", "maximumValue"], path);
    if (typeof data.id !== "string" || !/^[a-z][a-z0-9_]{0,47}$/.test(data.id) || ids.has(data.id)) fail(`${path}.id`);
    const id = data.id as string;
    const label = text(data.label, `${path}.label`, 120);
    if (labels.has(label.toLowerCase())) fail(`${path}.label`);
    ids.add(id);
    labels.add(label.toLowerCase());
    if (typeof data.valueType !== "string" ||
        !["number", "boolean", "text", "choice", "date"].includes(data.valueType)) fail(`${path}.valueType`);
    const valueType = data.valueType as InspectionReadingField["valueType"];
    const unit = data.unit === null ? null : text(data.unit, `${path}.unit`, 40);
    if ((valueType === "number") !== (unit !== null)) fail(`${path}.unit`);
    if (!Array.isArray(data.choiceValues) || data.choiceValues.length > 30) fail(`${path}.choiceValues`);
    const choiceValues = (data.choiceValues as unknown[]).map((entry) => text(entry, `${path}.choiceValues`, 120));
    if (new Set(choiceValues).size !== choiceValues.length ||
        (valueType === "choice") !== (choiceValues.length > 0)) fail(`${path}.choiceValues`);
    const minimumValue = limit(data.minimumValue, `${path}.minimumValue`);
    const maximumValue = limit(data.maximumValue, `${path}.maximumValue`);
    if ((valueType !== "number" && (minimumValue !== null || maximumValue !== null)) ||
        (minimumValue !== null && maximumValue !== null && minimumValue > maximumValue)) fail(`${path}.limits`);
    return {id, label, valueType, unit, choiceValues, minimumValue, maximumValue};
  });
};

export const parseMultiReadingValue = (raw: unknown, definition: JsonMap): MultiReadingValue => {
  if (definition.schemaVersion !== 2) fail("definition.schemaVersion");
  const fields = parseInspectionReadingFields(definition.readingFields);
  const data = object(raw, "observation.value");
  exact(data, ["schemaVersion", "readings"], "observation.value");
  if (data.schemaVersion !== 2 || !Array.isArray(data.readings) || data.readings.length !== fields.length) {
    fail("observation.value.readings");
  }
  const readings = (data.readings as unknown[]).map((entry, index): InspectionReading => {
    const path = `observation.value.readings[${index}]`;
    const data = object(entry, path);
    exact(data, ["fieldId", "valueType", "value"], path);
    const field = fields[index];
    if (data.fieldId !== field.id || data.valueType !== field.valueType) fail(path);
    let value = data.value;
    switch (field.valueType) {
    case "number":
      if (typeof value !== "number" || !Number.isFinite(value)) fail(path);
      break;
    case "boolean":
      if (typeof value !== "boolean") fail(path);
      break;
    case "text": value = text(value, path, 1000); break;
    case "choice":
      value = text(value, path, 120);
      if (!field.choiceValues.includes(value)) fail(path);
      break;
    case "date": if (!isInspectionDate(value)) fail(path); break;
    }
    return {fieldId: field.id, valueType: field.valueType, value: value as string | number | boolean};
  });
  return {schemaVersion: 2, readings};
};

export const isMultiReadingValue = (value: JsonMap): value is MultiReadingValue =>
  value.schemaVersion === 2;

const deviation = (value: number, field: InspectionReadingField): number => {
  if (field.minimumValue !== null && value < field.minimumValue) return field.minimumValue - value;
  if (field.maximumValue !== null && value > field.maximumValue) return value - field.maximumValue;
  return 0;
};

export const multiReadingOutOfRange = (value: MultiReadingValue, definition: JsonMap): boolean => {
  const fields = parseInspectionReadingFields(definition.readingFields);
  return fields.some((field, index) => field.valueType === "number" &&
    deviation(value.readings[index].value as number, field) > 0);
};

/** Never combine unlike units into one magnitude or infer health from a date. */
export const compareMultiReadingValue = (
  current: MultiReadingValue, baseline: JsonMap, definition: JsonMap,
): "improved" | "unchanged" | "deteriorated" | "resolved" | "recurred" | "notComparable" => {
  const rawDefinition = baseline.definition;
  if (baseline.schemaVersion !== 2 || rawDefinition == null ||
      typeof rawDefinition !== "object" || Array.isArray(rawDefinition) ||
      (rawDefinition as JsonMap).schemaVersion !== 2) return "notComparable";
  const previousDefinition = rawDefinition as JsonMap;
  let fields: readonly InspectionReadingField[];
  let previous: MultiReadingValue;
  try {
    fields = parseInspectionReadingFields(definition.readingFields);
    if (stableJson(fields) !== stableJson(parseInspectionReadingFields(previousDefinition.readingFields))) return "notComparable";
    previous = parseMultiReadingValue(baseline.value, previousDefinition);
  } catch {
    return "notComparable";
  }
  let improved = false;
  let deteriorated = false;
  let previousBreach = false;
  let nextBreach = false;
  for (let index = 0; index < fields.length; index += 1) {
    const field = fields[index];
    const before = previous.readings[index].value;
    const next = current.readings[index].value;
    if (field.valueType !== "number") {
      if (before !== next) return "notComparable";
      continue;
    }
    const beforeDeviation = deviation(before as number, field);
    const nextDeviation = deviation(next as number, field);
    previousBreach ||= beforeDeviation > 0;
    nextBreach ||= nextDeviation > 0;
    improved ||= nextDeviation < beforeDeviation;
    deteriorated ||= nextDeviation > beforeDeviation;
    if (before !== next && beforeDeviation === nextDeviation) return "notComparable";
  }
  if (improved && deteriorated) return "notComparable";
  if (previousBreach && !nextBreach) return "resolved";
  if (!previousBreach && nextBreach) return "recurred";
  if (improved) return "improved";
  if (deteriorated) return "deteriorated";
  return "unchanged";
};
