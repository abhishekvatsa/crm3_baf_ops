import {createHash} from "crypto";

import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import {stableJson} from "./stableJson";
import {canonicalApprovedUserAuthority} from "./userAuthority";

type JsonMap = {[key: string]: unknown};
type SnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => JsonMap | undefined;
};
type QuerySnapshotLike = {docs: SnapshotLike[]};
type DocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<SnapshotLike>;
};
type QueryLike = {
  where: (field: string, op: string, value: unknown) => QueryLike;
  orderBy: (field: string, direction: "asc" | "desc") => QueryLike;
  limit: (value: number) => QueryLike;
};
type CollectionLike = {
  doc: (id: string) => DocumentRefLike;
  where: (field: string, op: string, value: unknown) => QueryLike;
};
type TransactionLike = {
  get: (
    ref: DocumentRefLike | QueryLike,
  ) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
};

export type BurnerDirectiveComplianceFirestoreLike = {
  collection: (name: string) => CollectionLike;
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

export const COMPLETE_BURNER_RED_HOT_DIRECTIVE =
  "COMPLETE_BURNER_RED_HOT_DIRECTIVE" as const;
export type BurnerDirectiveComplianceOperation =
  typeof COMPLETE_BURNER_RED_HOT_DIRECTIVE;

type ComplianceDisposition =
  "restoredInService" | "uvMelted" | "uvMissing" | "uvHungRemoved";
type FlameObservation = "seen" | "notSeen" | "notOperating" | "notChecked";
type UvCondition = "serviceable" | "melted" | "missing" | "hanging";
type BurnerObservation = {
  position: number;
  flameObservation: FlameObservation;
  redHotObserved: boolean;
  microampReading: number | null;
  remarks: string | null;
};
type UvObservation = {
  position: number;
  condition: UvCondition;
  remarks: string | null;
};
type ParsedDisposition = {
  position: number;
  disposition: ComplianceDisposition;
};
type ParsedRequest = {
  requestId: string;
  operation: BurnerDirectiveComplianceOperation;
  assetClassId: string;
  assetInstanceId: string;
  expectedAssetVersion: number;
  expectedCurrentRoundId: string;
  directiveId: string;
  expectedDirectiveVersion: number;
  dispositions: ReadonlyArray<ParsedDisposition>;
  closureRemarks: string | null;
  fingerprint: string;
};
type DirectiveBinding = {
  sourceRoundId: string;
  burnerPositions: ReadonlyArray<number>;
};
type RoundState = {
  data: JsonMap;
  roundId: string;
  observations: ReadonlyArray<BurnerObservation>;
  uvObservations: ReadonlyArray<UvObservation>;
  draftSealRedHotObserved: boolean;
  hotAirAtDraftSealObserved: boolean;
  observedAtMillis: number;
};

export interface BurnerDirectiveComplianceMutationResult {
  ok: true;
  requestId: string;
  operation: BurnerDirectiveComplianceOperation;
  roundId: string;
  assetClassId: string;
  assetInstanceId: string;
  closedDirectiveId: string;
  closedDirectiveVersion: number;
  newDirectiveId: string | null;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FLAME_OBSERVATIONS = new Set<FlameObservation>([
  "seen",
  "notSeen",
  "notOperating",
  "notChecked",
]);
const UV_CONDITIONS = new Set<UvCondition>([
  "serviceable",
  "melted",
  "missing",
  "hanging",
]);
const DISPOSITIONS = new Set<ComplianceDisposition>([
  "restoredInService",
  "uvMelted",
  "uvMissing",
  "uvHungRemoved",
]);
const RECORD_ROLES = new Set([
  "admin",
  "si",
  "shiftSupervisor",
  "operations",
  "seniorInstrumentation",
]);
const CLOSE_ANY_ROLES = new Set([
  "admin",
  "si",
  "contractSupervisor",
  "shiftSupervisor",
]);
const MAX_MICROAMP_READING = 1_000_000;

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-burner-directive-compliance", field},
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
  return requiredString(value, field, max);
}

function documentId(value: unknown, field: string): string {
  const result = requiredString(value, field, 128);
  if (result === "." || result === ".." || result.includes("/")) {
    invalid(field, "is invalid");
  }
  return result;
}

function positiveInteger(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    invalid(field, "must be a positive integer");
  }
  return value as number;
}

function parseDisposition(value: unknown, index: number): ParsedDisposition {
  const field = `dispositions[${index}]`;
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid(field, "must be an object");
  }
  const raw = value as JsonMap;
  if (Object.keys(raw).length !== 2 || !("position" in raw) ||
      !("disposition" in raw)) {
    invalid(field, "must contain exactly position and disposition");
  }
  if (!Number.isSafeInteger(raw.position) || (raw.position as number) < 1 ||
      (raw.position as number) > 8) {
    invalid(`${field}.position`, "must be an integer from 1 to 8");
  }
  const disposition = requiredString(
    raw.disposition,
    `${field}.disposition`,
    32,
  ) as ComplianceDisposition;
  if (!DISPOSITIONS.has(disposition)) {
    invalid(`${field}.disposition`, "is unsupported");
  }
  return {position: raw.position as number, disposition};
}

export function parseBurnerDirectiveComplianceRequest(raw: JsonMap): ParsedRequest {
  const allowed = new Set([
    "requestId",
    "operation",
    "assetClassId",
    "assetInstanceId",
    "expectedAssetVersion",
    "expectedCurrentRoundId",
    "directiveId",
    "expectedDirectiveVersion",
    "dispositions",
    "closureRemarks",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(key, "is unsupported");
  }
  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  if (raw.operation !== COMPLETE_BURNER_RED_HOT_DIRECTIVE) {
    invalid("operation", "is unsupported");
  }
  if (!Array.isArray(raw.dispositions) || raw.dispositions.length === 0 ||
      raw.dispositions.length > 8) {
    invalid("dispositions", "must contain one to eight burner outcomes");
  }
  const dispositions = raw.dispositions.map(parseDisposition)
    .sort((left, right) => left.position - right.position);
  if (new Set(dispositions.map((item) => item.position)).size !==
      dispositions.length) {
    invalid("dispositions", "must contain each burner position once");
  }
  const request = {
    requestId,
    operation: COMPLETE_BURNER_RED_HOT_DIRECTIVE,
    assetClassId: documentId(raw.assetClassId, "assetClassId"),
    assetInstanceId: documentId(raw.assetInstanceId, "assetInstanceId"),
    expectedAssetVersion: positiveInteger(
      raw.expectedAssetVersion,
      "expectedAssetVersion",
    ),
    expectedCurrentRoundId: documentId(
      raw.expectedCurrentRoundId,
      "expectedCurrentRoundId",
    ),
    directiveId: documentId(raw.directiveId, "directiveId"),
    expectedDirectiveVersion: positiveInteger(
      raw.expectedDirectiveVersion,
      "expectedDirectiveVersion",
    ),
    dispositions,
    closureRemarks: optionalString(raw.closureRemarks, "closureRemarks", 1000),
  };
  if (!request.directiveId.startsWith("burner_round_red_hot_")) {
    invalid("directiveId", "is not a governed burner-round directive");
  }
  const fingerprint = `burnercompliance1-sha256:${createHash("sha256")
    .update(stableJson(request), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

export function isBurnerDirectiveComplianceOperation(
  value: unknown,
): value is BurnerDirectiveComplianceOperation {
  return value === COMPLETE_BURNER_RED_HOT_DIRECTIVE;
}

export function userCanCompleteBurnerDirective(data: JsonMap): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null &&
    [...authority.roles].some((role) => RECORD_ROLES.has(role));
}

function asSnapshot(
  value: SnapshotLike | QuerySnapshotLike,
  label: string,
): SnapshotLike {
  if ("docs" in value) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a query.`);
  }
  return value;
}

function asQuery(
  value: SnapshotLike | QuerySnapshotLike,
  label: string,
): QuerySnapshotLike {
  if (!("docs" in value)) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a document.`);
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

function actorAuthority(value: SnapshotLike): {
  data: JsonMap;
  roles: ReadonlySet<string>;
} {
  const data = record(value, "Burner-compliance actor");
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null ||
      ![...authority.roles].some((role) => RECORD_ROLES.has(role))) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Only approved Operations, I&A, Shift Supervisor, SI, or Admin users can complete burner compliance.",
      {reasonCode: "burner-directive-compliance-role-denied"},
    );
  }
  return {data, roles: authority.roles};
}

function actorName(data: JsonMap): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : "Approved user";
}

function timestampMillis(value: unknown, field: string): number {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      const millis = Date.prototype.getTime.call(value);
      if (Number.isFinite(millis)) return millis;
    } catch {
      // Continue into the common malformed-timestamp failure below.
    }
  }
  if (value != null && typeof value === "object") {
    const toMillis = (value as {toMillis?: unknown}).toMillis;
    if (typeof toMillis === "function") {
      const millis = (toMillis as () => unknown).call(value);
      if (typeof millis === "number" && Number.isFinite(millis)) return millis;
    }
  }
  if (typeof value === "string") {
    const millis = Date.parse(value);
    if (Number.isFinite(millis)) return millis;
  }
  throw new AssetHierarchyMutationError(
    "data-loss",
    `Burner-round ${field} is malformed.`,
    {reasonCode: "burner-directive-compliance-round-malformed", field},
  );
}

function instantIso(value: unknown): string | null {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      const millis = Date.prototype.getTime.call(value);
      return Number.isFinite(millis) ? new Date(millis).toISOString() : null;
    } catch {
      return null;
    }
  }
  if (value != null && typeof value === "object") {
    const toDate = (value as {toDate?: unknown}).toDate;
    if (typeof toDate === "function") {
      try {
        const date = (toDate as () => unknown).call(value);
        if (date == null || typeof date !== "object" ||
            Object.prototype.toString.call(date) !== "[object Date]") {
          return null;
        }
        const millis = Date.prototype.getTime.call(date);
        return Number.isFinite(millis) ? new Date(millis).toISOString() : null;
      } catch {
        return null;
      }
    }
    const toMillis = (value as {toMillis?: unknown}).toMillis;
    if (typeof toMillis === "function") {
      try {
        const millis = (toMillis as () => unknown).call(value);
        return typeof millis === "number" && Number.isFinite(millis) ?
          new Date(millis).toISOString() : null;
      } catch {
        return null;
      }
    }
  }
  if (typeof value === "string") {
    const millis = Date.parse(value);
    return Number.isFinite(millis) ? new Date(millis).toISOString() : null;
  }
  return null;
}

function parseStoredObservation(value: unknown, index: number): BurnerObservation {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throwRoundMalformed(`observations[${index}]`);
  }
  const raw = value as JsonMap;
  const position = raw.position;
  const flame = raw.flameObservation;
  if (position !== index + 1 || typeof flame !== "string" ||
      !FLAME_OBSERVATIONS.has(flame as FlameObservation) ||
      typeof raw.redHotObserved !== "boolean") {
    throwRoundMalformed(`observations[${index}]`);
  }
  let microampReading: number | null = null;
  if (raw.microampReading != null) {
    if (typeof raw.microampReading !== "number" ||
        !Number.isFinite(raw.microampReading) || raw.microampReading < 0 ||
        raw.microampReading > MAX_MICROAMP_READING) {
      throwRoundMalformed(`observations[${index}].microampReading`);
    }
    microampReading = raw.microampReading;
  }
  const remarks = raw.remarks == null ? null :
    typeof raw.remarks === "string" && raw.remarks.trim().length > 0 ?
      raw.remarks.trim() : throwRoundMalformed(`observations[${index}].remarks`);
  return {
    position,
    flameObservation: flame as FlameObservation,
    redHotObserved: raw.redHotObserved,
    microampReading,
    remarks,
  };
}

function parseStoredUv(value: unknown, index: number): UvObservation {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throwRoundMalformed(`uvObservations[${index}]`);
  }
  const raw = value as JsonMap;
  if (raw.position !== index + 1 || typeof raw.condition !== "string" ||
      !UV_CONDITIONS.has(raw.condition as UvCondition)) {
    throwRoundMalformed(`uvObservations[${index}]`);
  }
  const remarks = raw.remarks == null ? null :
    typeof raw.remarks === "string" && raw.remarks.trim().length > 0 ?
      raw.remarks.trim() : throwRoundMalformed(`uvObservations[${index}].remarks`);
  return {
    position: raw.position,
    condition: raw.condition as UvCondition,
    remarks,
  };
}

function throwRoundMalformed(field: string): never {
  throw new AssetHierarchyMutationError(
    "data-loss",
    `The authoritative burner round has malformed ${field}.`,
    {reasonCode: "burner-directive-compliance-round-malformed", field},
  );
}

function roundState(snapshot: SnapshotLike, request: ParsedRequest): RoundState {
  const data = record(snapshot, "Authoritative burner round");
  const roundId = typeof snapshot.id === "string" ? snapshot.id : data.roundId;
  if (typeof roundId !== "string" || data.roundId !== roundId ||
      data.operation !== "RECORD_BURNER_CONDITION_ROUND" ||
      data.assetClassId !== request.assetClassId ||
      data.assetInstanceId !== request.assetInstanceId ||
      !Number.isSafeInteger(data.assetInstanceVersion) ||
      (data.assetInstanceVersion as number) < 1 ||
      !Array.isArray(data.observations) || data.observations.length !== 8) {
    throwRoundMalformed("identity");
  }
  const observations = data.observations.map(parseStoredObservation);
  let uvObservations: ReadonlyArray<UvObservation>;
  let draftSealRedHotObserved = false;
  let hotAirAtDraftSealObserved = false;
  if (data.schemaVersion === 1) {
    uvObservations = Array.from({length: 8}, (_, index) => ({
      position: index + 1,
      condition: "serviceable" as const,
      remarks: null,
    }));
  } else if (data.schemaVersion === 2 && Array.isArray(data.uvObservations) &&
      data.uvObservations.length === 8 &&
      typeof data.draftSealRedHotObserved === "boolean" &&
      typeof data.hotAirAtDraftSealObserved === "boolean") {
    uvObservations = data.uvObservations.map(parseStoredUv);
    draftSealRedHotObserved = data.draftSealRedHotObserved;
    hotAirAtDraftSealObserved = data.hotAirAtDraftSealObserved;
  } else {
    throwRoundMalformed("extended condition evidence");
  }
  return {
    data,
    roundId,
    observations,
    uvObservations,
    draftSealRedHotObserved,
    hotAirAtDraftSealObserved,
    observedAtMillis: timestampMillis(data.observedAt, "observedAt"),
  };
}

function latestRound(
  query: QuerySnapshotLike,
  request: ParsedRequest,
): RoundState {
  const rounds = query.docs.map((snapshot) => roundState(snapshot, request));
  if (rounds.length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "A governed burner audit is required before directive compliance.",
      {reasonCode: "burner-directive-compliance-current-round-missing"},
    );
  }
  rounds.sort((left, right) =>
    right.observedAtMillis - left.observedAtMillis ||
    right.roundId.localeCompare(left.roundId));
  return rounds[0];
}

function currentRoundIdFromProjection(
  value: SnapshotLike,
  request: ParsedRequest,
): string | null {
  if (!value.exists) return null;
  const data = value.data() ?? {};
  if (data.schemaVersion !== 1 ||
      data.assetInstanceId !== request.assetInstanceId ||
      typeof data.roundId !== "string" || data.roundId.trim().length === 0 ||
      data.observedAt == null || data.updatedAt == null) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The current burner-round projection is malformed.",
      {reasonCode: "burner-condition-current-projection-malformed"},
    );
  }
  return data.roundId;
}

function verifyRoundAssetIdentity(round: RoundState, asset: JsonMap): void {
  if (round.data.assetNumber !== asset.assetNumber ||
      round.data.assetClassCode !== asset.assetClassCode ||
      round.data.assetClassName !== asset.assetClassName ||
      round.data.assetName !== asset.name) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The authoritative burner round belongs to inconsistent asset evidence.",
      {reasonCode: "burner-directive-compliance-round-asset-drift"},
    );
  }
}

function directiveBinding(data: JsonMap, directiveId: string): DirectiveBinding {
  if (typeof data.metadataJson !== "string") {
    throwDirectiveMalformed("metadataJson");
  }
  let decoded: unknown;
  try {
    decoded = JSON.parse(data.metadataJson);
  } catch {
    throwDirectiveMalformed("metadataJson");
  }
  if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
    throwDirectiveMalformed("metadataJson");
  }
  const metadata = decoded as JsonMap;
  const expectedKeys = new Set([
    "schemaVersion",
    "trigger",
    "sourceRoundId",
    "burnerPositions",
    "automaticPlantActuation",
  ]);
  if (Object.keys(metadata).length !== expectedKeys.size ||
      Object.keys(metadata).some((key) => !expectedKeys.has(key)) ||
      metadata.schemaVersion !== 1 ||
      metadata.trigger !== "burnerConditionRoundRedHot" ||
      metadata.automaticPlantActuation !== false ||
      !Array.isArray(metadata.burnerPositions) ||
      metadata.burnerPositions.length === 0) {
    throwDirectiveMalformed("metadataJson");
  }
  const sourceRoundId = documentId(
    metadata.sourceRoundId,
    "metadataJson.sourceRoundId",
  );
  if (directiveId !== `burner_round_red_hot_${sourceRoundId}`) {
    throwDirectiveMalformed("sourceRoundId");
  }
  const positions = metadata.burnerPositions;
  if (positions.some((value, index) => !Number.isSafeInteger(value) ||
      (value as number) < 1 || (value as number) > 8 ||
      (index > 0 && (positions[index - 1] as number) >= (value as number)))) {
    throwDirectiveMalformed("burnerPositions");
  }
  return {
    sourceRoundId,
    burnerPositions: positions as ReadonlyArray<number>,
  };
}

function throwDirectiveMalformed(field: string): never {
  throw new AssetHierarchyMutationError(
    "data-loss",
    `The burner directive has malformed ${field}.`,
    {reasonCode: "burner-directive-compliance-source-malformed", field},
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
    assetClass.legacyAssetTypeKey === "furnace";
  const validAsset = asset.schemaVersion === 1 &&
    asset.assetInstanceId === request.assetInstanceId &&
    asset.assetClassId === request.assetClassId &&
    asset.assetClassCode === assetClass.code &&
    asset.assetClassName === assetClass.name &&
    asset.status === "active" &&
    ["inService", "standby"].includes(asset.serviceState as string) &&
    Number.isSafeInteger(asset.assetNumber) &&
    Number.isSafeInteger(asset.version) &&
    (asset.version as number) >= 1;
  if (!validClass || !validAsset) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The selected governed asset is not an active Furnace.",
      {reasonCode: "burner-directive-compliance-furnace-invalid"},
    );
  }
  if (asset.version !== request.expectedAssetVersion) {
    throw new AssetHierarchyMutationError(
      "aborted",
      "The Furnace identity changed before compliance was committed.",
      {
        reasonCode: "burner-directive-compliance-asset-version-mismatch",
        currentVersion: asset.version,
      },
    );
  }
}

function canCloseDirective(
  data: JsonMap,
  actorUid: string,
  roles: ReadonlySet<string>,
): boolean {
  if ([...roles].some((role) => CLOSE_ANY_ROLES.has(role))) return true;
  if (data.createdByUid === actorUid || data.issuedByUid === actorUid) return true;
  return data.status === "acknowledged" &&
    data.acknowledgedByUid === actorUid &&
    typeof data.directedTo === "string" && roles.has(data.directedTo);
}

function verifyDirective(
  data: JsonMap,
  request: ParsedRequest,
  asset: JsonMap,
  actorUid: string,
  roles: ReadonlySet<string>,
): DirectiveBinding {
  const valid = data.firestoreId === request.directiveId &&
    ["open", "acknowledged"].includes(data.status as string) &&
    data.isActive === true && data.isDeleted === false &&
    data.assetType === "furnace" && data.assetNumber === asset.assetNumber &&
    data.component === "Burner block" && data.subsystem === "Burner system" &&
    data.directedTo === "seniorInstrumentation" &&
    Number.isSafeInteger(data.version) &&
    (data.version as number) === request.expectedDirectiveVersion;
  if (!valid) {
    throw new AssetHierarchyMutationError(
      "aborted",
      "The burner directive changed before compliance was committed.",
      {
        reasonCode: "burner-directive-compliance-directive-mismatch",
        currentVersion: data.version,
      },
    );
  }
  if (!canCloseDirective(data, actorUid, roles)) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "The approved user cannot close this burner directive.",
      {reasonCode: "burner-directive-compliance-close-role-denied"},
    );
  }
  return directiveBinding(data, request.directiveId);
}

function verifySourceRound(
  source: RoundState,
  binding: DirectiveBinding,
  directiveId: string,
): void {
  const sourceDirectivePositions = source.data.schemaVersion === 2 ?
    source.data.directivePositions : source.data.redHotPositions;
  if (source.roundId !== binding.sourceRoundId ||
      source.data.directiveId !== directiveId ||
      stableJson(sourceDirectivePositions) !== stableJson(binding.burnerPositions)) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The burner directive no longer matches its source round.",
      {reasonCode: "burner-directive-compliance-source-drift"},
    );
  }
}

function dispositionUv(value: ComplianceDisposition): UvCondition {
  switch (value) {
  case "restoredInService": return "serviceable";
  case "uvMelted": return "melted";
  case "uvMissing": return "missing";
  case "uvHungRemoved": return "hanging";
  }
}

function dispositionLabel(value: ComplianceDisposition): string {
  switch (value) {
  case "restoredInService": return "Block corrected; UV in service";
  case "uvMelted": return "UV melted";
  case "uvMissing": return "UV missing";
  case "uvHungRemoved": return "UV hung / removed";
  }
}

function projectCompliance(
  current: RoundState,
  request: ParsedRequest,
  binding: DirectiveBinding,
): {
  observations: ReadonlyArray<BurnerObservation>;
  uvObservations: ReadonlyArray<UvObservation>;
} {
  if (stableJson(request.dispositions.map((item) => item.position)) !==
      stableJson(binding.burnerPositions)) {
    throw new AssetHierarchyMutationError(
      "invalid-argument",
      "Record one compliance outcome for every directed burner position.",
      {reasonCode: "burner-directive-compliance-position-mismatch"},
    );
  }
  const byPosition = new Map(
    request.dispositions.map((item) => [item.position, item.disposition]),
  );
  const observations: BurnerObservation[] = [];
  const uvObservations: UvObservation[] = [];
  for (let position = 1; position <= 8; position++) {
    const before = current.observations[position - 1];
    const beforeUv = current.uvObservations[position - 1];
    const disposition = byPosition.get(position);
    const restored = disposition === "restoredInService";
    const abnormalUv = disposition != null && !restored;
    observations.push({
      position,
      flameObservation: abnormalUv ? "notOperating" : before.flameObservation,
      redHotObserved: restored ? false : before.redHotObserved,
      microampReading: abnormalUv ? null : before.microampReading,
      remarks: disposition == null ? before.remarks :
        `Directive compliance: ${dispositionLabel(disposition)}.`,
    });
    uvObservations.push({
      position,
      condition: disposition == null ? beforeUv.condition :
        dispositionUv(disposition),
      remarks: disposition == null ? beforeUv.remarks : null,
    });
  }
  return {observations, uvObservations};
}

function positionsWhere(
  observations: ReadonlyArray<BurnerObservation>,
  predicate: (item: BurnerObservation) => boolean,
): number[] {
  return observations.filter(predicate).map((item) => item.position);
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

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  receipt: JsonMap,
): BurnerDirectiveComplianceMutationResult {
  const expectedSuccessorId = `burner_round_red_hot_${request.requestId}`;
  const committedAtIso = typeof receipt.committedAtIso === "string" ?
    instantIso(receipt.committedAtIso) : null;
  if (receipt.schemaVersion !== 2 || receipt.requestId !== request.requestId ||
      receipt.actorUid !== actorUid || receipt.fingerprint !== request.fingerprint ||
      receipt.operation !== request.operation ||
      receipt.roundId !== request.requestId ||
      receipt.assetClassId !== request.assetClassId ||
      receipt.assetInstanceId !== request.assetInstanceId ||
      receipt.closedDirectiveId !== request.directiveId ||
      receipt.closedDirectiveVersion !== request.expectedDirectiveVersion + 1 ||
      !(receipt.newDirectiveId == null ||
        receipt.newDirectiveId === expectedSuccessorId) ||
      committedAtIso == null || committedAtIso !== receipt.committedAtIso ||
      instantIso(receipt.committedAt) !== committedAtIso) {
    throw new AssetHierarchyMutationError(
      "already-exists",
      "The burner-compliance request ID belongs to different evidence.",
      {reasonCode: "burner-directive-compliance-request-id-collision"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    roundId: request.requestId,
    assetClassId: request.assetClassId,
    assetInstanceId: request.assetInstanceId,
    closedDirectiveId: request.directiveId,
    closedDirectiveVersion: receipt.closedDirectiveVersion as number,
    newDirectiveId: receipt.newDirectiveId as string | null,
    committedAt: receipt.committedAtIso,
    idempotentReplay: true,
  };
}

function validateReplay(
  request: ParsedRequest,
  actorUid: string,
  result: BurnerDirectiveComplianceMutationResult,
  roundValue: SnapshotLike,
  closedDirectiveValue: SnapshotLike,
  newDirectiveValue: SnapshotLike,
): void {
  const round = roundState(roundValue, request);
  const closed = record(closedDirectiveValue, "Closed burner directive");
  const binding = directiveBinding(closed, request.directiveId);
  const dispositionPositions = request.dispositions.map((item) => item.position);
  const redHotPositions = positionsWhere(
    round.observations,
    (item) => item.redHotObserved,
  );
  const microampPositions = positionsWhere(
    round.observations,
    (item) => item.microampReading != null,
  );
  const directivePositions = round.observations
    .filter((item) => item.redHotObserved)
    .filter((item) =>
      round.uvObservations[item.position - 1].condition === "serviceable")
    .map((item) => item.position);
  const dispositionsValid = request.dispositions.every((item) => {
    const observation = round.observations[item.position - 1];
    const uv = round.uvObservations[item.position - 1];
    if (item.disposition === "restoredInService") {
      return observation.redHotObserved === false &&
        uv.condition === "serviceable";
    }
    return observation.redHotObserved === true &&
      observation.flameObservation === "notOperating" &&
      observation.microampReading == null &&
      uv.condition === dispositionUv(item.disposition);
  });
  const roundValid = round.data.schemaVersion === 2 &&
    round.roundId === request.requestId &&
    round.data.assetInstanceVersion === request.expectedAssetVersion &&
    round.data.fingerprint ===
      `burnerround2-sha256:${request.fingerprint.slice(-64)}` &&
    round.data.recordedByUid === actorUid &&
    typeof round.data.recordedByName === "string" &&
    round.data.recordedByName.trim().length > 0 &&
    round.data.directiveId === result.newDirectiveId &&
    round.data.roundNote ===
      `I&A compliance for directive ${request.directiveId}.` &&
    instantIso(round.data.observedAt) === result.committedAt &&
    stableJson(round.data.redHotPositions) === stableJson(redHotPositions) &&
    stableJson(round.data.microampPositions) === stableJson(microampPositions) &&
    stableJson(round.data.directivePositions) ===
      stableJson(directivePositions) &&
    stableJson(binding.burnerPositions) === stableJson(dispositionPositions) &&
    dispositionsValid;
  const closedValid = closed.firestoreId === request.directiveId &&
    closed.status === "closed" && closed.isActive === false &&
    closed.closedByUid === actorUid &&
    typeof closed.closedByName === "string" &&
    closed.closedByName.trim().length > 0 &&
    instantIso(closed.closedAt) === result.committedAt &&
    instantIso(closed.updatedAt) === result.committedAt &&
    closed.version === result.closedDirectiveVersion &&
    (request.closureRemarks == null ||
      closed.remarks === request.closureRemarks);
  let successorValid = !newDirectiveValue.exists &&
    result.newDirectiveId == null && directivePositions.length === 0;
  if (result.newDirectiveId != null && newDirectiveValue.exists) {
    const successor = newDirectiveValue.data() ?? {};
    const successorBinding = directiveBinding(
      successor,
      result.newDirectiveId,
    );
    successorValid = result.newDirectiveId ===
        `burner_round_red_hot_${request.requestId}` &&
      round.data.directiveId === result.newDirectiveId &&
      stableJson(successorBinding.burnerPositions) ===
        stableJson(directivePositions) &&
      successorBinding.sourceRoundId === request.requestId &&
      successor.assetType === "furnace" &&
      successor.assetNumber === round.data.assetNumber &&
      successor.component === "Burner block" &&
      successor.subsystem === "Burner system" &&
      successor.directedTo === "seniorInstrumentation" &&
      successor.createdByUid === actorUid &&
      successor.issuedByUid === actorUid &&
      instantIso(successor.createdAt) === result.committedAt &&
      instantIso(successor.issuedAt) === result.committedAt &&
      successor.isDeleted === false;
  }
  if (!roundValid || !closedValid || !successorValid) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "Retained burner-compliance evidence no longer matches its receipt.",
      {reasonCode: "burner-directive-compliance-replay-evidence-drift"},
    );
  }
}

export async function mutateBurnerDirectiveComplianceWithDb(args: {
  db: BurnerDirectiveComplianceFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<BurnerDirectiveComplianceMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before completing burner compliance.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseBurnerDirectiveComplianceRequest(args.data);
  const db = args.db;
  const actorRef = db.collection("users").doc(actorUid);
  const assetClassRef = db.collection("asset_classes").doc(request.assetClassId);
  const assetRef = db.collection("asset_instances").doc(request.assetInstanceId);
  const roundRef = db.collection("burner_condition_rounds").doc(request.requestId);
  const receiptRef = db.collection("burner_condition_round_receipts")
    .doc(request.requestId);
  const currentRoundRef = db.collection("burner_condition_current")
    .doc(request.assetInstanceId);
  const closedDirectiveRef = db.collection("directives").doc(request.directiveId);
  const successorDirectiveId = `burner_round_red_hot_${request.requestId}`;
  const successorDirectiveRef = db.collection("directives")
    .doc(successorDirectiveId);
  const roundsQuery = db.collection("burner_condition_rounds")
    .where("assetInstanceId", "==", request.assetInstanceId)
    .orderBy("observedAt", "desc")
    .limit(1);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  actorAuthority(await actorRef.get());

  return db.runTransaction(async (transaction) => {
    const actor = actorAuthority(asSnapshot(
      await transaction.get(actorRef),
      "Burner-compliance actor lookup",
    ));
    const receiptValue = asSnapshot(
      await transaction.get(receiptRef),
      "Burner-compliance receipt lookup",
    );
    const roundValue = asSnapshot(
      await transaction.get(roundRef),
      "Burner-compliance round lookup",
    );
    const currentRoundValue = asSnapshot(
      await transaction.get(currentRoundRef),
      "Current burner-round projection lookup",
    );
    const closedDirectiveValue = asSnapshot(
      await transaction.get(closedDirectiveRef),
      "Burner-compliance directive lookup",
    );
    const successorDirectiveValue = asSnapshot(
      await transaction.get(successorDirectiveRef),
      "Burner-compliance successor directive lookup",
    );

    if (receiptValue.exists) {
      const result = resultFromReceipt(
        request,
        actorUid,
        receiptValue.data() ?? {},
      );
      validateReplay(
        request,
        actorUid,
        result,
        roundValue,
        closedDirectiveValue,
        successorDirectiveValue,
      );
      return result;
    }
    if (roundValue.exists || successorDirectiveValue.exists) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "Burner-compliance evidence exists without its request receipt.",
        {reasonCode: "burner-directive-compliance-orphan-evidence"},
      );
    }

    const assetClass = record(asSnapshot(
      await transaction.get(assetClassRef),
      "Burner-compliance asset-class lookup",
    ), "Governed asset class");
    const asset = record(asSnapshot(
      await transaction.get(assetRef),
      "Burner-compliance asset lookup",
    ), "Governed Furnace");
    verifyFurnace(assetClass, asset, request);
    const directive = record(closedDirectiveValue, "Governed burner directive");
    const binding = verifyDirective(
      directive,
      request,
      asset,
      actorUid,
      actor.roles,
    );
    const sourceRoundRef = db.collection("burner_condition_rounds")
      .doc(binding.sourceRoundId);
    const sourceRoundValue = asSnapshot(
      await transaction.get(sourceRoundRef),
      "Burner-compliance source-round lookup",
    );
    const projectedCurrentRoundId = currentRoundIdFromProjection(
      currentRoundValue,
      request,
    );
    if (projectedCurrentRoundId != null &&
        projectedCurrentRoundId !== request.expectedCurrentRoundId) {
      throw new AssetHierarchyMutationError(
        "aborted",
        "A newer burner audit exists. Review it before completing compliance.",
        {
          reasonCode: "burner-directive-compliance-current-round-mismatch",
          currentRoundId: projectedCurrentRoundId,
        },
      );
    }
    const current = projectedCurrentRoundId == null ?
      latestRound(asQuery(
        await transaction.get(roundsQuery),
        "Burner-compliance current-round bootstrap lookup",
      ), request) :
      roundState(asSnapshot(
        await transaction.get(
          db.collection("burner_condition_rounds")
            .doc(projectedCurrentRoundId),
        ),
        "Burner-compliance projected current-round lookup",
      ), request);
    if (current.roundId !== request.expectedCurrentRoundId) {
      throw new AssetHierarchyMutationError(
        "aborted",
        "A newer burner audit exists. Review it before completing compliance.",
        {
          reasonCode: "burner-directive-compliance-current-round-mismatch",
          currentRoundId: current.roundId,
        },
      );
    }
    const source = roundState(sourceRoundValue, request);
    verifyRoundAssetIdentity(current, asset);
    verifyRoundAssetIdentity(source, asset);
    verifySourceRound(source, binding, request.directiveId);
    const projection = projectCompliance(current, request, binding);
    const redHotPositions = positionsWhere(
      projection.observations,
      (item) => item.redHotObserved,
    );
    const microampPositions = positionsWhere(
      projection.observations,
      (item) => item.microampReading != null,
    );
    const directivePositions = projection.observations
      .filter((item) => item.redHotObserved)
      .filter((item) =>
        projection.uvObservations[item.position - 1].condition === "serviceable")
      .map((item) => item.position);
    const newDirectiveId = directivePositions.length === 0 ? null :
      successorDirectiveId;
    const committed = now();
    const committedAt = timestampFromDate(committed);
    const committedAtIso = committed.toISOString();
    const recordedByName = actorName(actor.data);
    const roundFingerprint =
      `burnerround2-sha256:${request.fingerprint.slice(-64)}`;
    const round: JsonMap = {
      schemaVersion: 2,
      roundId: request.requestId,
      operation: "RECORD_BURNER_CONDITION_ROUND",
      assetClassId: request.assetClassId,
      assetClassCode: asset.assetClassCode,
      assetClassName: asset.assetClassName,
      assetInstanceId: request.assetInstanceId,
      assetInstanceVersion: asset.version,
      assetNumber: asset.assetNumber,
      assetName: asset.name,
      observations: projection.observations.map((item) => ({...item})),
      redHotPositions,
      microampPositions,
      draftSealRedHotObserved: current.draftSealRedHotObserved,
      hotAirAtDraftSealObserved: current.hotAirAtDraftSealObserved,
      uvObservations: projection.uvObservations.map((item) => ({...item})),
      directivePositions,
      roundNote: `I&A compliance for directive ${request.directiveId}.`,
      observedAt: committedAt,
      recordedByUid: actorUid,
      recordedByName,
      directiveId: newDirectiveId,
      fingerprint: roundFingerprint,
    };
    const closedDirectiveVersion = request.expectedDirectiveVersion + 1;
    const receipt: JsonMap = {
      schemaVersion: 2,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      roundId: request.requestId,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      closedDirectiveId: request.directiveId,
      closedDirectiveVersion,
      newDirectiveId,
      committedAt,
      committedAtIso,
    };

    transaction.set(roundRef, round);
    transaction.set(currentRoundRef, {
      schemaVersion: 1,
      assetInstanceId: request.assetInstanceId,
      roundId: request.requestId,
      observedAt: committedAt,
      updatedAt: committedAt,
    });
    if (newDirectiveId != null) {
      transaction.set(successorDirectiveRef, directiveProjection({
        roundId: request.requestId,
        directiveId: newDirectiveId,
        asset,
        positions: directivePositions,
        actorUid,
        actorName: recordedByName,
        committedAt,
      }));
    }
    transaction.set(closedDirectiveRef, {
      status: "closed",
      isActive: false,
      closedByUid: actorUid,
      closedByName: recordedByName,
      closedAt: committedAt,
      closedWithoutAcknowledgement: directive.status !== "acknowledged",
      ...(request.closureRemarks == null ? {} : {
        remarks: request.closureRemarks,
      }),
      updatedAt: committedAt,
      version: closedDirectiveVersion,
    }, {merge: true});
    transaction.set(receiptRef, receipt);
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      roundId: request.requestId,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      closedDirectiveId: request.directiveId,
      closedDirectiveVersion,
      newDirectiveId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
