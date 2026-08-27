import {createHash} from "crypto";

import {
  AssetHierarchyMutationError,
  AssetHierarchyMutationFirestoreLike,
} from "./assetHierarchyMutation";
import {stableJson} from "./stableJson";
import {canonicalApprovedUserAuthority} from "./userAuthority";

type JsonMap = {[key: string]: unknown};
type SnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => JsonMap | undefined;
};
type DocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<SnapshotLike>;
};
type QuerySnapshotLike = {docs: SnapshotLike[]};
type TransactionLike = {
  get: (ref: unknown) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
};

export const RECORD_BURNER_CONDITION_ROUND =
  "RECORD_BURNER_CONDITION_ROUND" as const;
export type BurnerConditionRoundOperation =
  typeof RECORD_BURNER_CONDITION_ROUND;

type FlameObservation = "seen" | "notSeen" | "notOperating" | "notChecked";
type UvCondition = "serviceable" | "melted" | "missing" | "hanging";
type BurnerObservation = Readonly<{
  position: number;
  flameObservation: FlameObservation;
  redHotObserved: boolean;
  microampReading: number | null;
  remarks: string | null;
}>;
type UvObservation = Readonly<{
  position: number;
  condition: UvCondition;
  remarks: string | null;
}>;

interface ParsedRequest {
  requestId: string;
  operation: BurnerConditionRoundOperation;
  assetClassId: string;
  assetInstanceId: string;
  expectedAssetVersion: number;
  observations: ReadonlyArray<BurnerObservation>;
  draftSealRedHotObserved: boolean | null;
  hotAirAtDraftSealObserved: boolean | null;
  uvObservations: ReadonlyArray<UvObservation> | null;
  roundNote: string | null;
  fingerprint: string;
}

export interface BurnerConditionRoundMutationResult {
  ok: true;
  requestId: string;
  operation: BurnerConditionRoundOperation;
  roundId: string;
  assetClassId: string;
  assetInstanceId: string;
  directiveId: string | null;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FLAME_OBSERVATIONS = new Set<FlameObservation>([
  "seen", "notSeen", "notOperating", "notChecked",
]);
const UV_CONDITIONS = new Set<UvCondition>([
  "serviceable", "melted", "missing", "hanging",
]);
const RECORD_ROLES = new Set([
  "admin",
  "si",
  "shiftSupervisor",
  "operations",
  "seniorInstrumentation",
]);
const MAX_MICROAMP_READING = 1_000_000;

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-burner-condition-round", field},
  );
}

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") invalid(field, "must be a string");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0 || cleaned.length > max) {
    invalid(field, `must contain 1-${max} characters`);
  }
  return cleaned;
}

function optionalString(value: unknown, field: string, max: number): string | null {
  if (value == null) return null;
  const cleaned = requiredString(value, field, max);
  return cleaned;
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is invalid");
  }
  return id;
}

function parseObservation(value: unknown, index: number): BurnerObservation {
  const field = `observations[${index}]`;
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid(field, "must be an object");
  }
  const raw = value as JsonMap;
  const allowed = new Set([
    "position",
    "flameObservation",
    "redHotObserved",
    "microampReading",
    "remarks",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(`${field}.${key}`, "is unsupported");
  }
  if (!Number.isSafeInteger(raw.position) ||
      (raw.position as number) < 1 || (raw.position as number) > 8) {
    invalid(`${field}.position`, "must be an integer from 1 to 8");
  }
  const flameObservation = requiredString(
    raw.flameObservation,
    `${field}.flameObservation`,
    16,
  ) as FlameObservation;
  if (!FLAME_OBSERVATIONS.has(flameObservation)) {
    invalid(`${field}.flameObservation`, "is unsupported");
  }
  if (typeof raw.redHotObserved !== "boolean") {
    invalid(`${field}.redHotObserved`, "must be a boolean");
  }
  let microampReading: number | null = null;
  if (raw.microampReading != null) {
    if (typeof raw.microampReading !== "number" ||
        !Number.isFinite(raw.microampReading) ||
        raw.microampReading < 0 ||
        raw.microampReading > MAX_MICROAMP_READING) {
      invalid(
        `${field}.microampReading`,
        `must be a finite value from 0 to ${MAX_MICROAMP_READING}`,
      );
    }
    microampReading = raw.microampReading;
  }
  const remarks = optionalString(raw.remarks, `${field}.remarks`, 500);
  if (["notChecked", "notOperating"].includes(flameObservation) &&
      microampReading != null) {
    invalid(
      `${field}.microampReading`,
      "cannot be recorded without an observed flame signal",
    );
  }
  if (flameObservation === "notChecked" && remarks == null) {
    invalid(
      `${field}.remarks`,
      "must explain why the burner was not checked",
    );
  }
  return {
    position: raw.position as number,
    flameObservation,
    redHotObserved: raw.redHotObserved,
    microampReading,
    remarks,
  };
}

function parseUvObservation(value: unknown, index: number): UvObservation {
  const field = `uvObservations[${index}]`;
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid(field, "must be an object");
  }
  const raw = value as JsonMap;
  const allowed = new Set(["position", "condition", "remarks"]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(`${field}.${key}`, "is unsupported");
  }
  if (!Number.isSafeInteger(raw.position) || raw.position !== index + 1) {
    invalid(`${field}.position`, "must match its position from 1 to 8");
  }
  const condition = requiredString(
    raw.condition,
    `${field}.condition`,
    20,
  ) as UvCondition;
  if (!UV_CONDITIONS.has(condition)) {
    invalid(`${field}.condition`, "is unsupported");
  }
  return {
    position: raw.position as number,
    condition,
    remarks: optionalString(raw.remarks, `${field}.remarks`, 500),
  };
}

export function isBurnerConditionRoundOperation(
  value: unknown,
): value is BurnerConditionRoundOperation {
  return value === RECORD_BURNER_CONDITION_ROUND;
}

export function parseBurnerConditionRoundMutationRequest(
  raw: JsonMap,
): ParsedRequest {
  const allowed = new Set([
    "requestId",
    "operation",
    "assetClassId",
    "assetInstanceId",
    "expectedAssetVersion",
    "observations",
    "draftSealRedHotObserved",
    "hotAirAtDraftSealObserved",
    "uvObservations",
    "roundNote",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(key, "is unsupported");
  }
  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  if (!isBurnerConditionRoundOperation(raw.operation)) {
    invalid("operation", "is unsupported");
  }
  if (!Number.isSafeInteger(raw.expectedAssetVersion) ||
      (raw.expectedAssetVersion as number) < 1) {
    invalid("expectedAssetVersion", "must be a positive integer");
  }
  if (!Array.isArray(raw.observations) || raw.observations.length !== 8) {
    invalid("observations", "must contain exactly eight burner positions");
  }
  const observations = raw.observations.map(parseObservation)
    .sort((left, right) => left.position - right.position);
  if (new Set(observations.map((item) => item.position)).size !== 8 ||
      observations.some((item, index) => item.position !== index + 1)) {
    invalid("observations", "must contain each position from 1 to 8 once");
  }
  const extendedValues = [
    raw.draftSealRedHotObserved,
    raw.hotAirAtDraftSealObserved,
    raw.uvObservations,
  ];
  const extended = extendedValues.some((value) => value != null);
  if (extended && extendedValues.some((value) => value == null)) {
    invalid(
      "uvObservations",
      "must accompany both draft-seal condition fields",
    );
  }
  if (extended &&
      (typeof raw.draftSealRedHotObserved !== "boolean" ||
        typeof raw.hotAirAtDraftSealObserved !== "boolean")) {
    invalid("draftSealRedHotObserved", "and hot-air state must be booleans");
  }
  let uvObservations: ReadonlyArray<UvObservation> | null = null;
  if (extended) {
    if (!Array.isArray(raw.uvObservations) || raw.uvObservations.length !== 8) {
      invalid("uvObservations", "must contain exactly eight UV positions");
    }
    uvObservations = raw.uvObservations.map(parseUvObservation);
  }
  const request = {
    requestId,
    operation: RECORD_BURNER_CONDITION_ROUND,
    assetClassId: documentId(raw.assetClassId, "assetClassId"),
    assetInstanceId: documentId(raw.assetInstanceId, "assetInstanceId"),
    expectedAssetVersion: raw.expectedAssetVersion as number,
    observations,
    draftSealRedHotObserved: extended ?
      raw.draftSealRedHotObserved as boolean : null,
    hotAirAtDraftSealObserved: extended ?
      raw.hotAirAtDraftSealObserved as boolean : null,
    uvObservations,
    roundNote: optionalString(raw.roundNote, "roundNote", 1000),
  };
  const fingerprint = `burnerround${extended ? 2 : 1}-sha256:${createHash("sha256")
    .update(stableJson(request), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

export function userCanRecordBurnerConditionRound(data: JsonMap): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null &&
    [...authority.roles].some((role) => RECORD_ROLES.has(role));
}

function asSnapshot(
  value: SnapshotLike | QuerySnapshotLike,
  label: string,
): SnapshotLike {
  if ("docs" in value) {
    throw new AssetHierarchyMutationError(
      "internal",
      `${label} returned a query.`,
    );
  }
  return value;
}

function record(value: SnapshotLike, label: string): JsonMap {
  const data = value.data();
  if (!value.exists || data == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return data;
}

function actor(value: SnapshotLike): JsonMap {
  const data = record(value, "Burner-round actor");
  if (!userCanRecordBurnerConditionRound(data)) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Only approved Operations, I&A, Shift Supervisor, SI, or Admin users can record burner rounds.",
      {reasonCode: "burner-condition-round-role-denied"},
    );
  }
  return data;
}

function actorName(data: JsonMap): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : "Approved user";
}

function redHotPositionsFor(request: ParsedRequest): ReadonlyArray<number> {
  return request.observations
    .filter((item) => item.redHotObserved)
    .map((item) => item.position);
}

function directivePositionsFor(request: ParsedRequest): ReadonlyArray<number> {
  const redHotPositions = redHotPositionsFor(request);
  if (request.uvObservations == null) return redHotPositions;
  return redHotPositions.filter(
    (position) =>
      request.uvObservations![position - 1].condition === "serviceable",
  );
}

function verifyFurnace(
  assetClass: JsonMap,
  asset: JsonMap,
  request: ParsedRequest,
): void {
  const validClass = assetClass.schemaVersion === 1 &&
    assetClass.assetClassId === request.assetClassId &&
    assetClass.status === "active" &&
    assetClass.legacyAssetTypeKey === "furnace" &&
    typeof assetClass.code === "string" &&
    typeof assetClass.name === "string" &&
    Number.isSafeInteger(assetClass.version) &&
    (assetClass.version as number) >= 1;
  const validAsset = asset.schemaVersion === 1 &&
    asset.assetInstanceId === request.assetInstanceId &&
    asset.assetClassId === request.assetClassId &&
    asset.assetClassCode === assetClass.code &&
    asset.assetClassName === assetClass.name &&
    asset.status === "active" &&
    asset.serviceState !== "outOfService" &&
    ["inService", "standby"].includes(asset.serviceState as string) &&
    Number.isSafeInteger(asset.assetNumber) &&
    (asset.assetNumber as number) >= 1 &&
    typeof asset.name === "string" && asset.name.trim().length > 0 &&
    Number.isSafeInteger(asset.version) && (asset.version as number) >= 1;
  if (!validClass || !validAsset) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The selected governed asset is not an active Furnace.",
      {reasonCode: "burner-condition-round-furnace-invalid"},
    );
  }
  if (directivePositionsFor(request).length > 0 &&
      (asset.assetNumber as number) > 26) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Red-hot directives require a legacy-compatible Furnace number from 1 to 26.",
      {
        reasonCode: "burner-condition-round-directive-furnace-number-unsupported",
      },
    );
  }
  if (asset.version !== request.expectedAssetVersion) {
    throw new AssetHierarchyMutationError(
      "aborted",
      "The Furnace identity changed before the round was committed.",
      {
        reasonCode: "burner-condition-round-asset-version-mismatch",
        currentVersion: asset.version,
      },
    );
  }
}

function directiveProjection(args: {
  roundId: string;
  directiveId: string;
  asset: JsonMap;
  positions: ReadonlyArray<number>;
  actorUid: string;
  actorName: string;
  committedAt: unknown;
}): JsonMap {
  const burnerList = args.positions.map((position) => `B${position}`).join(", ");
  return {
    firestoreId: args.directiveId,
    title: `Red-hot burner block: ${burnerList}`,
    description:
      `Furnace ${args.asset.assetNumber} has a red-hot burner-block ` +
      `observation at ${burnerList} in condition round ${args.roundId}. ` +
      "I&A must acknowledge, apply the approved plant procedure to take " +
      "the affected position out of firing service, and record compliance. " +
      "This directive does not actuate the PLC.",
    assetType: "furnace",
    assetNumber: args.asset.assetNumber,
    component: "Burner block",
    subsystem: "Burner system",
    tag: null,
    hierarchyPath: ["Furnace", "Combustion system", "Burner block"],
    directedTo: "seniorInstrumentation",
    status: "open",
    priority: "critical",
    createdByUid: args.actorUid,
    createdByName: args.actorName,
    issuedByUid: args.actorUid,
    issuedByName: args.actorName,
    issuedAt: args.committedAt,
    isActive: true,
    acknowledgedByUid: null,
    acknowledgedByName: null,
    acknowledgedAt: null,
    closedByUid: null,
    closedByName: null,
    closedAt: null,
    closedWithoutAcknowledgement: false,
    remarks: null,
    linkedMaintenanceFirestoreId: null,
    linkedExecutionFirestoreId: null,
    metadataJson: JSON.stringify({
      schemaVersion: 1,
      trigger: "burnerConditionRoundRedHot",
      sourceRoundId: args.roundId,
      burnerPositions: args.positions,
      automaticPlantActuation: false,
    }),
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    createdAt: args.committedAt,
    updatedAt: args.committedAt,
    version: 1,
  };
}

function validateCurrentRoundProjection(
  data: JsonMap,
  request: ParsedRequest,
): void {
  if (data.schemaVersion !== 1 ||
      data.assetInstanceId !== request.assetInstanceId ||
      typeof data.roundId !== "string" || data.roundId.trim().length === 0 ||
      data.observedAt == null) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The retained current burner-round projection is malformed.",
      {reasonCode: "burner-condition-current-projection-malformed"},
    );
  }
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): BurnerConditionRoundMutationResult {
  if (data.schemaVersion !== 1 || data.actorUid !== actorUid ||
      data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation ||
      data.roundId !== request.requestId ||
      data.assetClassId !== request.assetClassId ||
      data.assetInstanceId !== request.assetInstanceId ||
      data.assetInstanceVersion !== request.expectedAssetVersion ||
      typeof data.assetClassCode !== "string" ||
      data.assetClassCode.trim().length === 0 ||
      typeof data.assetClassName !== "string" ||
      data.assetClassName.trim().length === 0 ||
      !Number.isSafeInteger(data.assetNumber) ||
      (data.assetNumber as number) < 1 ||
      typeof data.assetName !== "string" || data.assetName.trim().length === 0 ||
      typeof data.recordedByName !== "string" ||
      data.recordedByName.trim().length === 0 ||
      !(data.directiveId == null || typeof data.directiveId === "string") ||
      typeof data.committedAtIso !== "string") {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The burner-round receipt is malformed or mismatched.",
      {reasonCode: "burner-condition-round-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    roundId: request.requestId,
    assetClassId: request.assetClassId,
    assetInstanceId: request.assetInstanceId,
    directiveId: data.directiveId as string | null,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

function instantIso(value: unknown): string | null {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      const milliseconds = Date.prototype.getTime.call(value);
      return Number.isNaN(milliseconds) ? null :
        new Date(milliseconds).toISOString();
    } catch {
      return null;
    }
  }
  if (value == null || typeof value !== "object" || Array.isArray(value) ||
      typeof (value as {toDate?: unknown}).toDate !== "function") return null;
  try {
    const date = (value as {toDate: () => unknown}).toDate();
    if (date == null || typeof date !== "object" ||
        Object.prototype.toString.call(date) !== "[object Date]") return null;
    const milliseconds = Date.prototype.getTime.call(date);
    return Number.isNaN(milliseconds) ? null :
      new Date(milliseconds).toISOString();
  } catch {
    return null;
  }
}

function validateRetainedRound(
  request: ParsedRequest,
  actorUid: string,
  directiveId: string | null,
  data: JsonMap,
  committedAtIso: string,
  receipt: JsonMap,
): void {
  const redHotPositions = redHotPositionsFor(request);
  const directivePositions = directivePositionsFor(request);
  const microampPositions = request.observations
    .filter((item) => item.microampReading != null)
    .map((item) => item.position);
  const mismatches: string[] = [];
  const expectedSchemaVersion = request.uvObservations == null ? 1 : 2;
  if (data.schemaVersion !== expectedSchemaVersion) mismatches.push("schemaVersion");
  if (data.roundId !== request.requestId) mismatches.push("roundId");
  if (data.operation !== request.operation) mismatches.push("operation");
  if (data.assetClassId !== request.assetClassId) mismatches.push("assetClassId");
  if (data.assetInstanceId !== request.assetInstanceId) {
    mismatches.push("assetInstanceId");
  }
  if (data.assetInstanceVersion !== request.expectedAssetVersion) {
    mismatches.push("assetInstanceVersion");
  }
  if (data.assetInstanceVersion !== receipt.assetInstanceVersion) {
    mismatches.push("receipt.assetInstanceVersion");
  }
  if (data.assetClassCode !== receipt.assetClassCode) {
    mismatches.push("assetClassCode");
  }
  if (data.assetClassName !== receipt.assetClassName) {
    mismatches.push("assetClassName");
  }
  if (data.assetNumber !== receipt.assetNumber) mismatches.push("assetNumber");
  if (data.assetName !== receipt.assetName) mismatches.push("assetName");
  if (stableJson(data.observations) !== stableJson(request.observations)) {
    mismatches.push("observations");
  }
  if (stableJson(data.redHotPositions) !== stableJson(redHotPositions)) {
    mismatches.push("redHotPositions");
  }
  if (stableJson(data.microampPositions) !== stableJson(microampPositions)) {
    mismatches.push("microampPositions");
  }
  if (expectedSchemaVersion === 2) {
    if (data.draftSealRedHotObserved !== request.draftSealRedHotObserved) {
      mismatches.push("draftSealRedHotObserved");
    }
    if (data.hotAirAtDraftSealObserved !== request.hotAirAtDraftSealObserved) {
      mismatches.push("hotAirAtDraftSealObserved");
    }
    if (stableJson(data.uvObservations) !== stableJson(request.uvObservations)) {
      mismatches.push("uvObservations");
    }
    if (stableJson(data.directivePositions) !== stableJson(directivePositions)) {
      mismatches.push("directivePositions");
    }
  }
  if (data.roundNote !== request.roundNote) mismatches.push("roundNote");
  if (data.directiveId !== directiveId) mismatches.push("directiveId");
  if (data.fingerprint !== request.fingerprint) mismatches.push("fingerprint");
  if (data.recordedByUid !== actorUid) mismatches.push("recordedByUid");
  if (typeof data.recordedByName !== "string" ||
      data.recordedByName.trim().length === 0) {
    mismatches.push("recordedByName");
  }
  if (data.recordedByName !== receipt.recordedByName) {
    mismatches.push("receipt.recordedByName");
  }
  if (instantIso(data.observedAt) !== committedAtIso) {
    mismatches.push("observedAt");
  }
  if (mismatches.length > 0) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      `The retained burner-round evidence no longer matches its receipt (${mismatches.join(", ")}).`,
      {
        reasonCode: "burner-condition-round-replay-evidence-drift",
        fields: mismatches,
      },
    );
  }
}

function validateRetainedDirective(
  roundId: string,
  directiveId: string,
  actorUid: string,
  round: JsonMap,
  data: JsonMap,
): void {
  let metadata: JsonMap | null = null;
  try {
    const decoded = JSON.parse(data.metadataJson as string) as unknown;
    metadata = decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    metadata = null;
  }
  if (data.firestoreId !== directiveId || data.assetType !== "furnace" ||
      data.assetNumber !== round.assetNumber ||
      data.component !== "Burner block" || data.subsystem !== "Burner system" ||
      data.directedTo !== "seniorInstrumentation" ||
      data.priority !== "critical" || data.createdByUid !== actorUid ||
      data.issuedByUid !== actorUid || data.isDeleted !== false ||
      metadata?.schemaVersion !== 1 ||
      metadata.trigger !== "burnerConditionRoundRedHot" ||
      metadata.sourceRoundId !== roundId ||
      metadata.automaticPlantActuation !== false ||
      stableJson(metadata.burnerPositions) !== stableJson(
        round.schemaVersion === 2 ? round.directivePositions :
          round.redHotPositions,
      )) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The retained burner-round directive no longer matches its source round.",
      {reasonCode: "burner-condition-round-directive-drift"},
    );
  }
}

export async function mutateBurnerConditionRoundWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<BurnerConditionRoundMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before recording a burner condition round.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseBurnerConditionRoundMutationRequest(args.data);
  const db = args.db;
  const actorRef = db.collection("users").doc(actorUid);
  const assetClassRef = db.collection("asset_classes").doc(request.assetClassId);
  const assetRef = db.collection("asset_instances").doc(request.assetInstanceId);
  const roundRef = db.collection("burner_condition_rounds").doc(request.requestId);
  const currentRoundRef = db.collection("burner_condition_current")
    .doc(request.assetInstanceId);
  const receiptRef = db.collection("burner_condition_round_receipts")
    .doc(request.requestId);
  const redHotPositions = redHotPositionsFor(request);
  const directivePositions = directivePositionsFor(request);
  const directiveId = directivePositions.length === 0 ? null :
    `burner_round_red_hot_${request.requestId}`;
  const directiveRef = directiveId == null ? null :
    db.collection("directives").doc(directiveId);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  actor(await actorRef.get());

  return db.runTransaction(async (rawTransaction) => {
    const transaction = rawTransaction as unknown as TransactionLike;
    const actorData = actor(asSnapshot(
      await transaction.get(actorRef),
      "Burner-round actor lookup",
    ));
    const receiptValue = asSnapshot(
      await transaction.get(receiptRef),
      "Burner-round receipt lookup",
    );
    const roundValue = asSnapshot(
      await transaction.get(roundRef),
      "Burner-round evidence lookup",
    );
    const currentRoundValue = asSnapshot(
      await transaction.get(currentRoundRef),
      "Current burner-round projection lookup",
    );
    const directiveValue = directiveRef == null ? null : asSnapshot(
      await transaction.get(directiveRef),
      "Burner-round directive lookup",
    );

    if (receiptValue.exists) {
      const receiptData = receiptValue.data() ?? {};
      const replay = resultFromReceipt(
        request,
        actorUid,
        receiptData,
      );
      const roundData = record(roundValue, "Recorded burner round");
      validateRetainedRound(
        request,
        actorUid,
        replay.directiveId,
        roundData,
        replay.committedAt,
        receiptData,
      );
      if (replay.directiveId == null && directiveValue != null) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "A burner-round directive exists without red-hot source evidence.",
          {reasonCode: "burner-condition-round-replay-evidence-drift"},
        );
      }
      if (replay.directiveId != null) {
        const directiveData = record(
          directiveValue ?? {exists: false, data: () => undefined},
          "Recorded burner-round directive",
        );
        validateRetainedDirective(
          replay.roundId,
          replay.directiveId,
          actorUid,
          roundData,
          directiveData,
        );
      }
      return replay;
    }
    if (roundValue.exists || directiveValue?.exists === true) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "Burner-round evidence exists without its request receipt.",
        {reasonCode: "burner-condition-round-orphan-evidence"},
      );
    }
    if (currentRoundValue.exists) {
      validateCurrentRoundProjection(
        currentRoundValue.data() ?? {},
        request,
      );
    }

    const assetClass = record(
      asSnapshot(
        await transaction.get(assetClassRef),
        "Burner-round asset-class lookup",
      ),
      "Governed asset class",
    );
    const asset = record(
      asSnapshot(
        await transaction.get(assetRef),
        "Burner-round asset lookup",
      ),
      "Governed Furnace",
    );
    verifyFurnace(assetClass, asset, request);

    const committed = now();
    const committedAt = timestampFromDate(committed);
    const committedAtIso = committed.toISOString();
    const recordedByName = actorName(actorData);
    const observations = request.observations.map((item) => ({...item}));
    const microampPositions = observations
      .filter((item) => item.microampReading != null)
      .map((item) => item.position);
    const round: JsonMap = {
      schemaVersion: request.uvObservations == null ? 1 : 2,
      roundId: request.requestId,
      operation: request.operation,
      assetClassId: request.assetClassId,
      assetClassCode: asset.assetClassCode,
      assetClassName: asset.assetClassName,
      assetInstanceId: request.assetInstanceId,
      assetInstanceVersion: asset.version,
      assetNumber: asset.assetNumber,
      assetName: asset.name,
      observations,
      redHotPositions,
      microampPositions,
      ...(request.uvObservations == null ? {} : {
        draftSealRedHotObserved: request.draftSealRedHotObserved,
        hotAirAtDraftSealObserved: request.hotAirAtDraftSealObserved,
        uvObservations: request.uvObservations.map((item) => ({...item})),
        directivePositions,
      }),
      roundNote: request.roundNote,
      observedAt: committedAt,
      recordedByUid: actorUid,
      recordedByName,
      directiveId,
      fingerprint: request.fingerprint,
    };
    const receipt: JsonMap = {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      roundId: request.requestId,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      assetInstanceVersion: asset.version,
      assetClassCode: asset.assetClassCode,
      assetClassName: asset.assetClassName,
      assetNumber: asset.assetNumber,
      assetName: asset.name,
      recordedByName,
      directiveId,
      committedAt,
      committedAtIso,
    };

    transaction.set(roundRef as unknown as DocumentRefLike, round);
    transaction.set(currentRoundRef as unknown as DocumentRefLike, {
      schemaVersion: 1,
      assetInstanceId: request.assetInstanceId,
      roundId: request.requestId,
      observedAt: committedAt,
      updatedAt: committedAt,
    });
    if (directiveRef != null && directiveId != null) {
      transaction.set(
        directiveRef as unknown as DocumentRefLike,
        directiveProjection({
          roundId: request.requestId,
          directiveId,
          asset,
          positions: directivePositions,
          actorUid,
          actorName: recordedByName,
          committedAt,
        }),
      );
    }
    transaction.set(receiptRef as unknown as DocumentRefLike, receipt);
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      roundId: request.requestId,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      directiveId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
