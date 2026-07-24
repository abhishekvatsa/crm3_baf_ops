import {JsonMap, JsonValue, LaneKey} from "./types";
import {WorkflowError} from "./errors";

export const cleanText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError("invalid-argument", `${field} is required.`);
  }
  return value.trim();
};

export const optionalText = (value: unknown): string | null =>
  typeof value === "string" && value.trim().length > 0 ? value.trim() : null;

export const intValue = (value: unknown, field: string, min = 0): number => {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < min) {
    throw new WorkflowError("invalid-argument", `${field} must be an integer >= ${min}.`);
  }
  return value;
};

export const laneKey = (value: unknown, field = "laneKey"): LaneKey => {
  const v = cleanText(value, field);
  if (v === "elec" || v === "mech" || v === "inst" || v === "oprn" || v === "emd" || v === "red" || v === "shared") {
    return v;
  }
  throw new WorkflowError("invalid-argument", `${field} is not a supported maintenance lane.`, {value: v});
};

export const stringArray = (value: unknown, field: string): string[] => {
  if (!Array.isArray(value)) throw new WorkflowError("invalid-argument", `${field} must be an array.`);
  return value.map((item, index) => cleanText(item, `${field}[${index}]`));
};

const stable = (value: JsonValue | undefined): string => {
  if (value === undefined) return "undefined";
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  const object = value as JsonMap;
  return `{${Object.keys(object).sort().map((key) => `${JSON.stringify(key)}:${stable(object[key])}`).join(",")}}`;
};

export const stableJson = (value: JsonValue): string => stable(value);

export const fnv1a64 = (text: string): string => {
  let high = 0xcbf29ce4;
  let low = 0x84222325;
  for (let i = 0; i < text.length; i += 1) {
    low ^= text.charCodeAt(i);
    const lowMul = low * 0x1b3;
    const carry = Math.floor(lowMul / 0x100000000);
    low = lowMul >>> 0;
    high = (high * 0x1b3 + carry) >>> 0;
  }
  return high.toString(16).padStart(8, "0") + low.toString(16).padStart(8, "0");
};

export const payloadHash = (command: JsonMap): string => fnv1a64(stableJson(command));
export const iso = (date: Date): string => date.toISOString();
export const plusMinutes = (date: Date, minutes: number): string =>
  new Date(date.getTime() + minutes * 60_000).toISOString();
