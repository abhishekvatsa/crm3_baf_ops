import {createHash} from "crypto";
import {JsonMap, JsonValue, LaneKey} from "./types";
import {WorkflowError} from "./errors";
import {stableJson as sharedStableJson} from "../stableJson";

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

export const stableJson = (value: JsonValue): string => sharedStableJson(value);

export const payloadFingerprint = (command: JsonMap): string =>
  `sha256:${createHash("sha256")
    .update(stableJson(command), "utf8")
    .digest("hex")}`;
export const iso = (date: Date): string => date.toISOString();
export const plusMinutes = (date: Date, minutes: number): string =>
  new Date(date.getTime() + minutes * 60_000).toISOString();

const FIRESTORE_MIN_SECONDS = -62_135_596_800;
const FIRESTORE_MAX_SECONDS = 253_402_300_799;

export const isPersistedInstant = (value: unknown): boolean => {
  if (typeof value === "string") {
    return value.trim().length > 0 && Number.isFinite(Date.parse(value));
  }
  if (value instanceof Date) return Number.isFinite(value.getTime());
  if (value == null || typeof value !== "object") return false;

  const candidate = value as {
    toDate?: unknown;
    _seconds?: unknown;
    _nanoseconds?: unknown;
  };
  if (typeof candidate.toDate === "function") {
    try {
      const date = (candidate.toDate as () => Date)();
      return date instanceof Date && Number.isFinite(date.getTime());
    } catch {
      return false;
    }
  }

  return Number.isSafeInteger(candidate._seconds) &&
    (candidate._seconds as number) >= FIRESTORE_MIN_SECONDS &&
    (candidate._seconds as number) <= FIRESTORE_MAX_SECONDS &&
    Number.isSafeInteger(candidate._nanoseconds) &&
    (candidate._nanoseconds as number) >= 0 &&
    (candidate._nanoseconds as number) < 1_000_000_000;
};
