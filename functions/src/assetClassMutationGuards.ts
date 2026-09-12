// Server-only serialization points. The class/profile documents remain the
// authority; a guard never substitutes for querying and validating that data.
export const ASSET_CLASS_GUARDS = "asset_class_mutation_guards";

export const HISTORICAL_INNER_COVER_STATES: ReadonlySet<string> = new Set([
  "retiredForSalvage", "partiallyDismantled", "fullyConsumedAsDonor", "disposed",
]);

type GuardScope = "legacyRole" | "serialInventory";
type JsonMap = {[key: string]: unknown};

export function assetClassGuardId(scope: GuardScope, key: string): string {
  return `${scope}:${key}`;
}

export function assetClassGuardValid(
  data: JsonMap, scope: GuardScope, key: string,
): boolean {
  return data.schemaVersion === 1 && data.scope === scope && data.key === key &&
    Number.isSafeInteger(data.version) && (data.version as number) >= 1 &&
    (data.version as number) < Number.MAX_SAFE_INTEGER &&
    typeof data.lastMutationId === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(data.lastMutationId);
}

export function nextAssetClassGuard(
  previous: JsonMap | null, scope: GuardScope, key: string, requestId: string,
): JsonMap {
  return {
    schemaVersion: 1, scope, key,
    version: previous == null ? 1 : (previous.version as number) + 1,
    lastMutationId: requestId,
  };
}
