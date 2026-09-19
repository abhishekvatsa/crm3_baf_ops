import {createHash} from "crypto";
import {
  AssetHierarchyMutationError,
  AssetHierarchyMutationFirestoreLike,
} from "./assetHierarchyMutation";
import {evidenceInstant} from "./burnerConditionEvidence";
import {stableJson} from "./stableJson";

type JsonMap = {[key: string]: unknown};
type QueryLike = ReturnType<ReturnType<
  AssetHierarchyMutationFirestoreLike["collection"]>["where"]>;
type Installation = {position: number; eventId: string; actionPerformedAt: string};
type OpenIssue = {id: string; version: number; updatedAt: string};
export interface ConditionBasis {
  expectedInstallationBasis: {burner: Installation[]; uv: Installation[]};
  expectedOpenIssueBasis: OpenIssue[];
}

function invalid(field: string): never {
  throw new AssetHierarchyMutationError("invalid-argument",
    "The reviewed condition basis is malformed.",
    {reasonCode: "invalid-burner-condition-basis", field});
}

function object(value: unknown, field: string): JsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) invalid(field);
  return value as JsonMap;
}

function exact(value: unknown, keys: readonly string[], field: string): JsonMap {
  const result = object(value, field);
  if (Object.keys(result).sort().join(",") !== [...keys].sort().join(",")) invalid(field);
  return result;
}

function id(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0 ||
      value.length > 160 || value.trim() !== value ||
      value === "." || value === ".." || value.includes("/")) invalid(field);
  return value as string;
}

function position(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1 || (value as number) > 8) invalid(field);
  return value as number;
}

function instant(value: unknown, field: string): string {
  const result = evidenceInstant(value);
  if (result == null) invalid(field);
  return result;
}

function installations(value: unknown, field: string): Installation[] {
  if (!Array.isArray(value) || value.length > 8) invalid(field);
  const seen = new Set<number>();
  return (value as unknown[]).map((entry, index) => {
    const path = `${field}[${index}]`;
    const row = exact(entry, ["position", "eventId", "actionPerformedAt"], path);
    const number = position(row.position, `${path}.position`);
    if (seen.has(number)) invalid(`${path}.position`);
    seen.add(number);
    return {position: number, eventId: id(row.eventId, `${path}.eventId`),
      actionPerformedAt: instant(row.actionPerformedAt, `${path}.actionPerformedAt`)};
  }).sort((left, right) => left.position - right.position);
}

function issues(value: unknown, field: string): OpenIssue[] {
  if (!Array.isArray(value)) invalid(field);
  const seen = new Set<string>();
  return (value as unknown[]).map((entry, index) => {
    const path = `${field}[${index}]`;
    const row = exact(entry, ["id", "version", "updatedAt"], path);
    const issueId = id(row.id, `${path}.id`);
    if (seen.has(issueId) || !Number.isSafeInteger(row.version) ||
        (row.version as number) < 1) invalid(path);
    seen.add(issueId);
    return {id: issueId, version: row.version as number,
      updatedAt: instant(row.updatedAt, `${path}.updatedAt`)};
  }).sort((left, right) => left.id.localeCompare(right.id));
}

/** Parse before fingerprinting so equivalent supported timestamps have one basis. */
export function parseConditionBasis(value: unknown): ConditionBasis {
  const raw = object(value, "conditionBasis");
  const installation = exact(raw.expectedInstallationBasis, ["burner", "uv"],
    "expectedInstallationBasis");
  return {
    expectedInstallationBasis: {
      burner: installations(installation.burner, "expectedInstallationBasis.burner"),
      uv: installations(installation.uv, "expectedInstallationBasis.uv"),
    },
    expectedOpenIssueBasis: issues(raw.expectedOpenIssueBasis, "expectedOpenIssueBasis"),
  };
}

type Snapshot = {exists: boolean; id?: string; data: () => JsonMap | undefined};
function snapshots(value: unknown): Snapshot[] {
  const rows = object(value, "snapshot").docs;
  if (!Array.isArray(rows)) invalid("snapshot.docs");
  return rows as Snapshot[];
}

function projectedInstallations(value: unknown, assetId: string,
  prefix: string, discipline: string): Installation[] {
  return installations(snapshots(value).map((snapshot) => {
    const row = snapshot.data();
    if (!snapshot.exists || row == null || row.schemaVersion !== 1 ||
        row.projectionSchemaVersion !== 1 || row.isDeleted === true ||
        row.assetInstanceId !== assetId || row.installationDiscipline !== discipline ||
        row.currentEventId !== row.eventId) invalid("currentInstallation");
    const number = position(row.burnerPosition, "currentInstallation.position");
    const projectionId = `${prefix}_${createHash("sha256")
      .update(`${assetId}|${number}`, "utf8").digest("hex").slice(0, 40)}`;
    if (snapshot.id !== projectionId || row.projectionId !== projectionId) {
      invalid("currentInstallation.projectionId");
    }
    if (discipline === "instrumentation" && row.resultingCondition !== "serviceable") {
      invalid("currentInstallation.resultingCondition");
    }
    return {position: number, eventId: row.currentEventId,
      actionPerformedAt: row.actionPerformedAt};
  }), "currentInstallations");
}

function openIssues(value: unknown, assetNumber: number): OpenIssue[] {
  const rows: JsonMap[] = [];
  for (const snapshot of snapshots(value)) {
    const row = snapshot.data();
    if (!snapshot.exists || row == null) invalid("openIssue");
    if (row.assetType !== "furnace" || row.assetNumber !== assetNumber || row.isDeleted === true) continue;
    if (row.burnerRedHotPositions == null) continue;
    if (!Array.isArray(row.burnerRedHotPositions)) invalid("openIssue.burnerRedHotPositions");
    if (row.burnerRedHotPositions.length === 0) continue;
    if (row.status === "resolved" || row.status === "closedWithoutResolution") continue;
    if (!["open", "acknowledged", "inProgress"].includes(String(row.status)) ||
        row.isResolved === true) invalid("openIssue.status");
    const positions = row.burnerRedHotPositions.map((entry) => position(entry, "openIssue.position"));
    if (new Set(positions).size !== positions.length) invalid("openIssue.position");
    const issueId = id(snapshot.id, "openIssue.id");
    if (row.firestoreId != null && row.firestoreId !== issueId) invalid("openIssue.id");
    rows.push({id: issueId, version: row.version, updatedAt: row.updatedAt});
  }
  return issues(rows, "openIssues");
}

/** Compare all dependencies inside the same transaction that publishes the round. */
export async function verifyConditionBasis(args: {
  db: Pick<AssetHierarchyMutationFirestoreLike, "collection">;
  transaction: {get: (query: QueryLike) => Promise<unknown>};
  request: {assetInstanceId: string; expectedInstallationBasis: unknown; expectedOpenIssueBasis: unknown};
  assetNumber: number;
}): Promise<void> {
  const expected = parseConditionBasis(args.request);
  const [burner, uv, maintenance] = await Promise.all([
    args.transaction.get(args.db.collection("burner_block_lifecycle_current")
      .where("assetInstanceId", "==", args.request.assetInstanceId)),
    args.transaction.get(args.db.collection("uv_detector_lifecycle_current")
      .where("assetInstanceId", "==", args.request.assetInstanceId)),
    args.transaction.get(args.db.collection("maintenance_records")
      .where("assetNumber", "==", args.assetNumber)),
  ]);
  let currentInstallations;
  try {
    currentInstallations = {
      burner: projectedInstallations(burner, args.request.assetInstanceId, "bblc", "mechanical"),
      uv: projectedInstallations(uv, args.request.assetInstanceId, "uvlc", "instrumentation"),
    };
  } catch (_) {
    throw new AssetHierarchyMutationError("aborted",
      "The installed-component evidence needs refresh before this condition update.",
      {reasonCode: "burner-condition-round-installation-basis-mismatch"});
  }
  if (stableJson(currentInstallations) !== stableJson(expected.expectedInstallationBasis)) {
    throw new AssetHierarchyMutationError("aborted",
      "The installed components changed while this condition update was being prepared.",
      {reasonCode: "burner-condition-round-installation-basis-mismatch"});
  }
  let currentIssues;
  try {
    currentIssues = openIssues(maintenance, args.assetNumber);
  } catch (_) {
    throw new AssetHierarchyMutationError("aborted",
      "The open red-hot issues need refresh before this condition update.",
      {reasonCode: "burner-condition-round-issue-basis-mismatch"});
  }
  if (stableJson(currentIssues) !== stableJson(expected.expectedOpenIssueBasis)) {
    throw new AssetHierarchyMutationError("aborted",
      "The open red-hot issues changed while this condition update was being prepared.",
      {reasonCode: "burner-condition-round-issue-basis-mismatch"});
  }
}
