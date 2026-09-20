/**
 * Normalizes published semantic keys for comparison without changing the
 * value retained in a published snapshot.
 *
 * Assignment and server-created successor jobs must agree on this exact
 * comparison. The original spelling remains evidence; this is only the
 * lookup key.
 */
export const normalizeSemanticKey = (value: string | null): string =>
  (value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("&", "and")
    .replace(/[^a-z0-9]+/g, "");
