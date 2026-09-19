/**
 * One effective disposition for every operational-event consumer.
 *
 * Older event documents do not have isWithdrawn. They remain effective. A
 * present true value is the only state that removes an entry from current
 * work and impact calculations; the raw document and its audit still remain
 * readable.
 */
export type OperationalEventDisposition = "effective" | "withdrawn";

export function operationalEventDisposition(
  data: Readonly<Record<string, unknown>> | null,
): OperationalEventDisposition {
  return data?.isWithdrawn === true ? "withdrawn" : "effective";
}

export function isOperationalEventEffective(
  data: Readonly<Record<string, unknown>> | null,
): boolean {
  return operationalEventDisposition(data) === "effective";
}
