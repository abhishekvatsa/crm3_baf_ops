const LEGACY_PLANT_LOCAL_ISO =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?$/;

const LEGACY_PLANT_UTC_OFFSET = "+05:30";
const FIRESTORE_MIN_SECONDS = -62_135_596_800;
const FIRESTORE_MAX_SECONDS = 253_402_300_799;

/**
 * Returns the absolute time represented by a persisted app instant.
 *
 * Pilot Android builds wrote local Indian plant time as ISO text without a
 * zone suffix. JavaScript otherwise interprets that text as UTC in Cloud
 * Functions, shifting the instant by 5.5 hours. New clients write canonical
 * UTC, while this compatibility branch keeps those legacy records operable.
 */
export function persistedInstantMillis(value: unknown): number {
  if (value instanceof Date) return value.valueOf();
  if (typeof value === "string") {
    const text = value.trim();
    if (text.length === 0) return Number.NaN;
    return Date.parse(
      LEGACY_PLANT_LOCAL_ISO.test(text) ?
        `${text}${LEGACY_PLANT_UTC_OFFSET}` : text,
    );
  }
  if (value == null || typeof value !== "object") return Number.NaN;
  const timestamp = value as {
    toDate?: () => Date;
    seconds?: unknown;
    nanoseconds?: unknown;
    _seconds?: unknown;
    _nanoseconds?: unknown;
  };
  if (typeof timestamp.toDate === "function") {
    try {
      return timestamp.toDate().valueOf();
    } catch (_) {
      return Number.NaN;
    }
  }
  const seconds = timestamp.seconds ?? timestamp._seconds;
  const nanoseconds = timestamp.nanoseconds ?? timestamp._nanoseconds;
  if (Number.isSafeInteger(seconds) &&
      (seconds as number) >= FIRESTORE_MIN_SECONDS &&
      (seconds as number) <= FIRESTORE_MAX_SECONDS &&
      Number.isSafeInteger(nanoseconds) &&
      (nanoseconds as number) >= 0 &&
      (nanoseconds as number) < 1_000_000_000) {
    return (seconds as number) * 1000 +
      (nanoseconds as number) / 1_000_000;
  }
  return Number.NaN;
}

export function isValidPersistedInstant(value: unknown): boolean {
  return Number.isFinite(persistedInstantMillis(value));
}
