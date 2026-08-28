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
type TransactionLike = {
  get: (ref: DocumentRefLike) => Promise<SnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap) => void;
  delete: (ref: DocumentRefLike) => void;
};
type CollectionLike = {doc: (id?: string) => DocumentRefLike};
type LifecycleDbLike = {
  collection: (name: string) => CollectionLike;
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

export type InnerCoverLifecycleOperation =
  | "REGISTER_INNER_COVER"
  | "ACCEPT_INNER_COVER"
  | "SET_INNER_COVER_STATE"
  | "LINK_INNER_COVER"
  | "DELINK_INNER_COVER"
  | "TRANSFER_INNER_COVER"
  | "REPLACE_INNER_COVER"
  | "SWAP_INNER_COVERS";

export type InnerCoverLifecycleState =
  | "available"
  | "reserved"
  | "installed"
  | "awaitingInspection"
  | "underInspection"
  | "underRepair"
  | "underFabrication"
  | "quarantined"
  | "rejected"
  | "retiredForSalvage"
  | "partiallyDismantled"
  | "fullyConsumedAsDonor"
  | "disposed";

type InnerCoverSourceType = "purchased" | "fabricated" | "legacyExisting";
type InnerCoverRetirementCondition = "bulged" | "notBulged";
type InnerCoverOriginClassification =
  | "documentedPurchase"
  | "documentedFabrication"
  | "ownerDeclaredNew"
  | "ownerDeclaredFabricated"
  | "legacyUndocumented";
type FabricationSectionType =
  | "lowerAssembly"
  | "flatVertical"
  | "corrugatedShell"
  | "topCover"
  | "catchRing"
  | "liftingRing"
  | "guideArms"
  | "other";
type SectionMaterialSource =
  | "newPurchased"
  | "newFabricated"
  | "reusedKnownDonor"
  | "reusedUnknownLegacyDonor";

interface FabricationSectionDraft {
  sectionId: string;
  sectionType: FabricationSectionType;
  materialSource: SectionMaterialSource;
  donorInnerCoverId: string | null;
  donorSectionKey: string | null;
  donorExpectedVersion: number | null;
  lengthMm: number | null;
  cutCount: number;
  notes: string | null;
}

interface RegistrationDraft {
  serialNumber: string;
  normalizedSerialNumber: string;
  sourceType: InnerCoverSourceType;
  originClassification: InnerCoverOriginClassification;
  supplierOrFabricator: string | null;
  receivedOrCompletedOn: Date | null;
  incorporatedOn: Date | null;
  drawingReference: string | null;
  materialGrade: string | null;
  notes: string | null;
  fabricationSections: ReadonlyArray<FabricationSectionDraft>;
}

interface AcceptanceDraft {
  inspectedOn: Date;
  acceptanceReference: string;
  leakTestReference: string | null;
  ndtReference: string | null;
  notes: string | null;
}

interface ParsedRequest {
  requestId: string;
  operation: InnerCoverLifecycleOperation;
  innerCoverId: string;
  innerCoverAssetClassId: string | null;
  expectedVersion: number | null;
  sourceBaseAssetInstanceId: string | null;
  targetBaseAssetInstanceId: string | null;
  expectedSourceAssignmentVersion: number | null;
  expectedTargetAssignmentVersion: number | null;
  displacedInnerCoverId: string | null;
  expectedDisplacedVersion: number | null;
  targetState: InnerCoverLifecycleState | null;
  retirementCondition: InnerCoverRetirementCondition | null;
  registrationDraft: RegistrationDraft | null;
  acceptanceDraft: AcceptanceDraft | null;
  reason: string;
  fingerprint: string;
}

export interface InnerCoverLifecycleMutationResult {
  ok: true;
  requestId: string;
  operation: InnerCoverLifecycleOperation;
  innerCoverId: string;
  version: number;
  secondaryVersion: number | null;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<InnerCoverLifecycleOperation>([
  "REGISTER_INNER_COVER",
  "ACCEPT_INNER_COVER",
  "SET_INNER_COVER_STATE",
  "LINK_INNER_COVER",
  "DELINK_INNER_COVER",
  "TRANSFER_INNER_COVER",
  "REPLACE_INNER_COVER",
  "SWAP_INNER_COVERS",
]);
const STATES = new Set<InnerCoverLifecycleState>([
  "available",
  "reserved",
  "installed",
  "awaitingInspection",
  "underInspection",
  "underRepair",
  "underFabrication",
  "quarantined",
  "rejected",
  "retiredForSalvage",
  "partiallyDismantled",
  "fullyConsumedAsDonor",
  "disposed",
]);
const RETIREMENT_CONDITIONS = new Set<InnerCoverRetirementCondition>([
  "bulged", "notBulged",
]);
const SOURCE_TYPES = new Set<InnerCoverSourceType>([
  "purchased", "fabricated", "legacyExisting",
]);
const ORIGIN_CLASSIFICATIONS = new Set<InnerCoverOriginClassification>([
  "documentedPurchase",
  "documentedFabrication",
  "ownerDeclaredNew",
  "ownerDeclaredFabricated",
  "legacyUndocumented",
]);
const SECTION_TYPES = new Set<FabricationSectionType>([
  "lowerAssembly",
  "flatVertical",
  "corrugatedShell",
  "topCover",
  "catchRing",
  "liftingRing",
  "guideArms",
  "other",
]);
const MATERIAL_SOURCES = new Set<SectionMaterialSource>([
  "newPurchased",
  "newFabricated",
  "reusedKnownDonor",
  "reusedUnknownLegacyDonor",
]);
const REQUIRED_FABRICATION_SECTIONS = new Set<FabricationSectionType>([
  "lowerAssembly", "flatVertical", "corrugatedShell", "topCover",
]);
const DELINK_STATES = new Set<InnerCoverLifecycleState>([
  "available", "awaitingInspection", "underRepair", "quarantined",
]);

const STATE_TRANSITIONS: Readonly<Record<string, ReadonlySet<string>>> = {
  awaitingInspection: new Set([
    "underInspection", "quarantined", "rejected",
  ]),
  underInspection: new Set([
    "underRepair", "quarantined", "rejected",
  ]),
  underRepair: new Set(["awaitingInspection", "quarantined"]),
  underFabrication: new Set(["awaitingInspection", "quarantined"]),
  available: new Set([
    "reserved", "underInspection", "underRepair", "quarantined",
    "retiredForSalvage",
  ]),
  reserved: new Set(["available", "quarantined"]),
  quarantined: new Set([
    "underInspection", "underRepair", "rejected", "retiredForSalvage",
  ]),
  rejected: new Set(["retiredForSalvage", "disposed"]),
  retiredForSalvage: new Set(["partiallyDismantled", "disposed"]),
  partiallyDismantled: new Set(["fullyConsumedAsDonor", "disposed"]),
  fullyConsumedAsDonor: new Set(["disposed"]),
  installed: new Set(),
  disposed: new Set(),
};

export function isInnerCoverLifecycleOperation(
  value: unknown,
): value is InnerCoverLifecycleOperation {
  return typeof value === "string" &&
    OPERATIONS.has(value as InnerCoverLifecycleOperation);
}

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-inner-cover-lifecycle-request", field},
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

function optionalString(
  value: unknown,
  field: string,
  max: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") invalid(field, "must be a string or null");
  const cleaned = value.trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > max) invalid(field, `cannot exceed ${max} characters`);
  return cleaned;
}

function mapValue(value: unknown, field: string): JsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid(field, "must be an object");
  }
  return value as JsonMap;
}

function onlyKeys(map: JsonMap, allowed: ReadonlySet<string>, field: string) {
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`${field}.${key}`, "is unsupported");
  }
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is invalid");
  }
  return id;
}

function uuid(value: unknown, field: string): string {
  const id = requiredString(value, field, 64);
  if (!UUID.test(id)) invalid(field, "must be a canonical UUID");
  return id;
}

function optionalId(value: unknown, field: string): string | null {
  return value == null ? null : documentId(value, field);
}

function optionalVersion(value: unknown, field: string): number | null {
  if (value == null) return null;
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    invalid(field, "must be a positive integer");
  }
  return value as number;
}

function requiredDate(value: unknown, field: string): Date {
  const text = requiredString(value, field, 40);
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString() !== text) {
    invalid(field, "must be an exact UTC ISO-8601 instant");
  }
  return parsed;
}

function optionalDate(value: unknown, field: string): Date | null {
  return value == null ? null : requiredDate(value, field);
}

function normalizedSerial(value: string): string {
  return value.toUpperCase().replace(/[^A-Z0-9]+/g, "");
}

function parseSection(value: unknown, index: number): FabricationSectionDraft {
  const field = `registrationDraft.fabricationSections[${index}]`;
  const map = mapValue(value, field);
  onlyKeys(map, new Set([
    "sectionId", "sectionType", "materialSource", "donorInnerCoverId",
    "donorSectionKey", "donorExpectedVersion", "lengthMm", "cutCount",
    "notes",
  ]), field);
  const sectionType = requiredString(
    map.sectionType, `${field}.sectionType`, 32,
  ) as FabricationSectionType;
  if (!SECTION_TYPES.has(sectionType)) {
    invalid(`${field}.sectionType`, "is unsupported");
  }
  const materialSource = requiredString(
    map.materialSource, `${field}.materialSource`, 40,
  ) as SectionMaterialSource;
  if (!MATERIAL_SOURCES.has(materialSource)) {
    invalid(`${field}.materialSource`, "is unsupported");
  }
  const donorInnerCoverId = optionalId(
    map.donorInnerCoverId, `${field}.donorInnerCoverId`,
  );
  const donorSectionKey = optionalString(
    map.donorSectionKey, `${field}.donorSectionKey`, 120,
  );
  const donorExpectedVersion = optionalVersion(
    map.donorExpectedVersion, `${field}.donorExpectedVersion`,
  );
  const knownDonor = materialSource === "reusedKnownDonor";
  if (knownDonor !== (donorInnerCoverId != null) ||
      knownDonor !== (donorSectionKey != null) ||
      knownDonor !== (donorExpectedVersion != null)) {
    invalid(
      `${field}.donorInnerCoverId`,
      knownDonor ?
        "and donor section/version are required for a known donor" :
        "is allowed only for a known donor",
    );
  }
  let lengthMm: number | null = null;
  if (map.lengthMm != null) {
    if (typeof map.lengthMm !== "number" ||
        !Number.isFinite(map.lengthMm) || map.lengthMm <= 0 ||
        map.lengthMm > 100000) {
      invalid(`${field}.lengthMm`, "must be greater than 0 and at most 100000");
    }
    lengthMm = map.lengthMm;
  }
  const cutCount = map.cutCount ?? 1;
  if (!Number.isSafeInteger(cutCount) || (cutCount as number) < 1 ||
      (cutCount as number) > 100) {
    invalid(`${field}.cutCount`, "must be an integer from 1 to 100");
  }
  return {
    sectionId: uuid(map.sectionId, `${field}.sectionId`),
    sectionType,
    materialSource,
    donorInnerCoverId,
    donorSectionKey,
    donorExpectedVersion,
    lengthMm,
    cutCount: cutCount as number,
    notes: optionalString(map.notes, `${field}.notes`, 1000),
  };
}

function parseRegistrationDraft(value: unknown): RegistrationDraft {
  const map = mapValue(value, "registrationDraft");
  onlyKeys(map, new Set([
    "serialNumber", "sourceType", "originClassification",
    "supplierOrFabricator", "receivedOrCompletedOn", "incorporatedOn",
    "drawingReference", "materialGrade", "notes", "fabricationSections",
  ]), "registrationDraft");
  const serialNumber = requiredString(
    map.serialNumber, "registrationDraft.serialNumber", 160,
  );
  const normalizedSerialNumber = normalizedSerial(serialNumber);
  if (normalizedSerialNumber.length < 2) {
    invalid(
      "registrationDraft.serialNumber",
      "must contain at least two letters or numbers",
    );
  }
  const sourceType = requiredString(
    map.sourceType, "registrationDraft.sourceType", 32,
  ) as InnerCoverSourceType;
  if (!SOURCE_TYPES.has(sourceType)) {
    invalid("registrationDraft.sourceType", "is unsupported");
  }
  if (!Array.isArray(map.fabricationSections) ||
      map.fabricationSections.length > 100) {
    invalid(
      "registrationDraft.fabricationSections",
      "must be an array containing at most 100 sections",
    );
  }
  const sections = map.fabricationSections.map(parseSection);
  const sectionIds = new Set(sections.map((section) => section.sectionId));
  if (sectionIds.size !== sections.length) {
    invalid("registrationDraft.fabricationSections", "contains duplicate IDs");
  }
  if (sourceType === "fabricated") {
    const present = new Set(sections.map((section) => section.sectionType));
    for (const required of REQUIRED_FABRICATION_SECTIONS) {
      if (!present.has(required)) {
        invalid(
          "registrationDraft.fabricationSections",
          `must include ${required}`,
        );
      }
    }
  } else if (sections.length > 0) {
    invalid(
      "registrationDraft.fabricationSections",
      "is allowed only for fabricated Inner Covers",
    );
  }
  const defaultOriginClassification: InnerCoverOriginClassification =
    sourceType === "purchased" ? "documentedPurchase" :
      sourceType === "fabricated" ?
        (sections.some((section) =>
          section.materialSource === "reusedUnknownLegacyDonor") ?
          "ownerDeclaredFabricated" : "documentedFabrication") :
        "legacyUndocumented";
  const originClassification = map.originClassification == null ?
    defaultOriginClassification : requiredString(
      map.originClassification,
      "registrationDraft.originClassification",
      40,
    ) as InnerCoverOriginClassification;
  if (!ORIGIN_CLASSIFICATIONS.has(originClassification)) {
    invalid("registrationDraft.originClassification", "is unsupported");
  }
  const originMatchesSource =
    (originClassification === "documentedPurchase" &&
      sourceType === "purchased") ||
    (new Set<InnerCoverOriginClassification>([
      "documentedFabrication", "ownerDeclaredFabricated",
    ]).has(originClassification) && sourceType === "fabricated") ||
    (new Set<InnerCoverOriginClassification>([
      "ownerDeclaredNew", "legacyUndocumented",
    ]).has(originClassification) && sourceType === "legacyExisting");
  if (!originMatchesSource) {
    invalid(
      "registrationDraft.originClassification",
      "does not match the compatible source classification",
    );
  }
  if (originClassification === "documentedFabrication" &&
      sections.some((section) =>
        section.materialSource === "reusedUnknownLegacyDonor")) {
    invalid(
      "registrationDraft.originClassification",
      "cannot claim documented fabrication with unknown legacy ancestry",
    );
  }
  return {
    serialNumber,
    normalizedSerialNumber,
    sourceType,
    originClassification,
    supplierOrFabricator: optionalString(
      map.supplierOrFabricator,
      "registrationDraft.supplierOrFabricator",
      240,
    ),
    receivedOrCompletedOn: optionalDate(
      map.receivedOrCompletedOn,
      "registrationDraft.receivedOrCompletedOn",
    ),
    incorporatedOn: optionalDate(
      map.incorporatedOn,
      "registrationDraft.incorporatedOn",
    ),
    drawingReference: optionalString(
      map.drawingReference, "registrationDraft.drawingReference", 240,
    ),
    materialGrade: optionalString(
      map.materialGrade, "registrationDraft.materialGrade", 160,
    ),
    notes: optionalString(map.notes, "registrationDraft.notes", 2000),
    fabricationSections: sections,
  };
}

function parseAcceptanceDraft(value: unknown): AcceptanceDraft {
  const map = mapValue(value, "acceptanceDraft");
  onlyKeys(map, new Set([
    "inspectedOn", "acceptanceReference", "leakTestReference",
    "ndtReference", "notes",
  ]), "acceptanceDraft");
  return {
    inspectedOn: requiredDate(
      map.inspectedOn, "acceptanceDraft.inspectedOn",
    ),
    acceptanceReference: requiredString(
      map.acceptanceReference, "acceptanceDraft.acceptanceReference", 240,
    ),
    leakTestReference: optionalString(
      map.leakTestReference, "acceptanceDraft.leakTestReference", 240,
    ),
    ndtReference: optionalString(
      map.ndtReference, "acceptanceDraft.ndtReference", 240,
    ),
    notes: optionalString(map.notes, "acceptanceDraft.notes", 2000),
  };
}

export function parseInnerCoverLifecycleMutationRequest(
  raw: JsonMap,
): ParsedRequest {
  onlyKeys(raw, new Set([
    "requestId", "operation", "innerCoverId", "innerCoverAssetClassId",
    "expectedVersion", "sourceBaseAssetInstanceId",
    "targetBaseAssetInstanceId", "expectedSourceAssignmentVersion",
    "expectedTargetAssignmentVersion", "displacedInnerCoverId",
    "expectedDisplacedVersion", "targetState", "registrationDraft",
    "retirementCondition", "acceptanceDraft", "reason",
  ]), "request");
  const operation = requiredString(
    raw.operation, "operation", 40,
  ) as InnerCoverLifecycleOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  const targetState = raw.targetState == null ? null : requiredString(
    raw.targetState, "targetState", 40,
  ) as InnerCoverLifecycleState;
  if (targetState != null && !STATES.has(targetState)) {
    invalid("targetState", "is unsupported");
  }
  const retirementCondition = raw.retirementCondition == null ? null :
    requiredString(
      raw.retirementCondition, "retirementCondition", 32,
    ) as InnerCoverRetirementCondition;
  if (retirementCondition != null &&
      !RETIREMENT_CONDITIONS.has(retirementCondition)) {
    invalid("retirementCondition", "is unsupported");
  }
  const request: Omit<ParsedRequest, "fingerprint"> = {
    requestId: uuid(raw.requestId, "requestId"),
    operation,
    innerCoverId: documentId(raw.innerCoverId, "innerCoverId"),
    innerCoverAssetClassId: optionalId(
      raw.innerCoverAssetClassId, "innerCoverAssetClassId",
    ),
    expectedVersion: optionalVersion(raw.expectedVersion, "expectedVersion"),
    sourceBaseAssetInstanceId: optionalId(
      raw.sourceBaseAssetInstanceId, "sourceBaseAssetInstanceId",
    ),
    targetBaseAssetInstanceId: optionalId(
      raw.targetBaseAssetInstanceId, "targetBaseAssetInstanceId",
    ),
    expectedSourceAssignmentVersion: optionalVersion(
      raw.expectedSourceAssignmentVersion,
      "expectedSourceAssignmentVersion",
    ),
    expectedTargetAssignmentVersion: optionalVersion(
      raw.expectedTargetAssignmentVersion,
      "expectedTargetAssignmentVersion",
    ),
    displacedInnerCoverId: optionalId(
      raw.displacedInnerCoverId, "displacedInnerCoverId",
    ),
    expectedDisplacedVersion: optionalVersion(
      raw.expectedDisplacedVersion, "expectedDisplacedVersion",
    ),
    targetState,
    retirementCondition,
    registrationDraft: raw.registrationDraft == null ? null :
      parseRegistrationDraft(raw.registrationDraft),
    acceptanceDraft: raw.acceptanceDraft == null ? null :
      parseAcceptanceDraft(raw.acceptanceDraft),
    reason: requiredString(raw.reason, "reason", 1000),
  };
  if (request.reason.length < 8) {
    invalid("reason", "must contain at least 8 characters");
  }
  const register = operation === "REGISTER_INNER_COVER";
  if (register !== (request.registrationDraft != null) ||
      register !== (request.innerCoverAssetClassId != null)) {
    invalid(
      "registrationDraft",
      register ? "and innerCoverAssetClassId are required" : "is not allowed",
    );
  }
  if (register && !UUID.test(request.innerCoverId)) {
    invalid("innerCoverId", "must be a canonical UUID for registration");
  }
  const accept = operation === "ACCEPT_INNER_COVER";
  if (accept !== (request.acceptanceDraft != null)) {
    invalid("acceptanceDraft", accept ? "is required" : "is not allowed");
  }
  if (!register && request.expectedVersion == null) {
    invalid("expectedVersion", "is required");
  }
  if (register && request.expectedVersion != null) {
    invalid("expectedVersion", "is not allowed during registration");
  }
  const sourceRequired = new Set<InnerCoverLifecycleOperation>([
    "DELINK_INNER_COVER", "TRANSFER_INNER_COVER", "SWAP_INNER_COVERS",
  ]).has(operation);
  if (sourceRequired !== (request.sourceBaseAssetInstanceId != null) ||
      sourceRequired !== (request.expectedSourceAssignmentVersion != null)) {
    invalid(
      "sourceBaseAssetInstanceId",
      sourceRequired ? "and its assignment version are required" :
        "is not allowed",
    );
  }
  const targetRequired = new Set<InnerCoverLifecycleOperation>([
    "LINK_INNER_COVER", "TRANSFER_INNER_COVER", "REPLACE_INNER_COVER",
    "SWAP_INNER_COVERS",
  ]).has(operation);
  if (targetRequired !== (request.targetBaseAssetInstanceId != null)) {
    invalid(
      "targetBaseAssetInstanceId",
      targetRequired ? "is required" : "is not allowed",
    );
  }
  const occupiedTarget = operation === "REPLACE_INNER_COVER" ||
    operation === "SWAP_INNER_COVERS";
  if (occupiedTarget !== (request.expectedTargetAssignmentVersion != null) ||
      occupiedTarget !== (request.displacedInnerCoverId != null) ||
      occupiedTarget !== (request.expectedDisplacedVersion != null)) {
    invalid(
      "displacedInnerCoverId",
      occupiedTarget ? "and target/displaced versions are required" :
        "is not allowed",
    );
  }
  const stateRequired = operation === "SET_INNER_COVER_STATE" ||
    operation === "DELINK_INNER_COVER" ||
    operation === "REPLACE_INNER_COVER";
  if (stateRequired !== (request.targetState != null)) {
    invalid("targetState", stateRequired ? "is required" : "is not allowed");
  }
  if ((operation === "DELINK_INNER_COVER" ||
      operation === "REPLACE_INNER_COVER") &&
      !DELINK_STATES.has(request.targetState!)) {
    invalid("targetState", "is not a safe post-removal state");
  }
  const retirementConditionRequired =
    operation === "SET_INNER_COVER_STATE" &&
    request.targetState === "retiredForSalvage";
  if (retirementConditionRequired !== (request.retirementCondition != null)) {
    invalid(
      "retirementCondition",
      retirementConditionRequired ?
        "is required when retiring an Inner Cover for salvage" :
        "is allowed only when retiring an Inner Cover for salvage",
    );
  }
  if (request.sourceBaseAssetInstanceId != null &&
      request.sourceBaseAssetInstanceId === request.targetBaseAssetInstanceId) {
    invalid("targetBaseAssetInstanceId", "must differ from the source Base");
  }
  if (request.displacedInnerCoverId === request.innerCoverId) {
    invalid("displacedInnerCoverId", "must differ from the incoming Inner Cover");
  }
  const {retirementCondition: condition, ...legacyRequest} = request;
  const fingerprintVersion = condition == null ? "innercover1" : "innercover2";
  const fingerprintPayload = condition == null ? legacyRequest : request;
  const fingerprint = `${fingerprintVersion}-sha256:${createHash("sha256")
    .update(stableJson(fingerprintPayload), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

function record(snapshot: SnapshotLike, label: string): JsonMap {
  if (!snapshot.exists || snapshot.data() == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return snapshot.data()!;
}

function requireVersion(
  data: JsonMap,
  expected: number | null,
  label: string,
): number {
  if (!Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} has a malformed version.`,
      {reasonCode: "inner-cover-version-malformed"},
    );
  }
  if (expected == null || data.version !== expected) {
    throw new AssetHierarchyMutationError(
      "aborted",
      `${label} changed before this command was committed.`,
      {
        reasonCode: "inner-cover-version-mismatch",
        currentVersion: data.version,
      },
    );
  }
  return data.version as number;
}

function requireAdmin(data: JsonMap): JsonMap {
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null || !authority.roles.has("admin")) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Only an approved Admin can change the Inner Cover lifecycle.",
    );
  }
  return data;
}

function requireProfile(
  data: JsonMap,
  innerCoverId: string,
  label: string,
): JsonMap {
  const originClassification = data.originClassification as
    InnerCoverOriginClassification | null | undefined;
  const originMatchesSource = originClassification == null ||
    (originClassification === "documentedPurchase" &&
      data.sourceType === "purchased") ||
    (new Set<InnerCoverOriginClassification>([
      "documentedFabrication", "ownerDeclaredFabricated",
    ]).has(originClassification) && data.sourceType === "fabricated") ||
    (new Set<InnerCoverOriginClassification>([
      "ownerDeclaredNew", "legacyUndocumented",
    ]).has(originClassification) && data.sourceType === "legacyExisting");
  const traceabilityMatchesOrigin = originClassification == null ||
    (originClassification === "documentedPurchase" &&
      data.traceabilityGrade === "T3") ||
    (originClassification === "documentedFabrication" &&
      new Set(["T2", "T3"]).has(data.traceabilityGrade as string)) ||
    (originClassification === "ownerDeclaredNew" &&
      data.traceabilityGrade === "T1") ||
    (new Set<InnerCoverOriginClassification>([
      "ownerDeclaredFabricated", "legacyUndocumented",
    ]).has(originClassification) && data.traceabilityGrade === "T0");
  if (data.schemaVersion !== 1 || data.innerCoverId !== innerCoverId ||
      typeof data.serialNumber !== "string" ||
      typeof data.normalizedSerialNumber !== "string" ||
      normalizedSerial(data.serialNumber) !== data.normalizedSerialNumber ||
      !SOURCE_TYPES.has(data.sourceType as InnerCoverSourceType) ||
      (data.originClassification != null &&
        !ORIGIN_CLASSIFICATIONS.has(
          data.originClassification as InnerCoverOriginClassification,
        )) ||
      !originMatchesSource ||
      !traceabilityMatchesOrigin ||
      (data.incorporatedOn != null &&
        timestampMillis(data.incorporatedOn) == null) ||
      !STATES.has(data.lifecycleState as InnerCoverLifecycleState) ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} is malformed.`,
      {reasonCode: "inner-cover-profile-malformed"},
    );
  }
  const current = [
    data.currentBaseAssetInstanceId,
    data.currentBaseAssetNumber,
    data.currentBaseAssetName,
    data.currentLinkageId,
  ];
  const populated = current.filter((value) => value != null).length;
  const installed = data.lifecycleState === "installed";
  if ((installed && populated !== current.length) || (!installed && populated !== 0)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} has an incomplete or inconsistent Base projection.`,
      {reasonCode: "inner-cover-projection-incomplete"},
    );
  }
  const acceptance = [
    data.acceptanceReference,
    data.acceptedAt,
    data.acceptedByUid,
    data.acceptedByName,
  ];
  const acceptancePopulated = acceptance.filter((value) => value != null).length;
  const acceptedState = new Set(["available", "reserved", "installed"])
    .has(data.lifecycleState as string);
  if ((acceptancePopulated !== 0 && acceptancePopulated !== acceptance.length) ||
      (acceptedState && acceptancePopulated !== acceptance.length) ||
      (data.acceptedAt != null && timestampMillis(data.acceptedAt) == null)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} has incomplete or malformed acceptance evidence.`,
      {reasonCode: "inner-cover-acceptance-incomplete"},
    );
  }
  const retirementCondition = data.retirementCondition;
  const retirementState = new Set([
    "retiredForSalvage", "partiallyDismantled",
    "fullyConsumedAsDonor", "disposed",
  ]).has(data.lifecycleState as string);
  if (retirementCondition != null &&
      (!RETIREMENT_CONDITIONS.has(
        retirementCondition as InnerCoverRetirementCondition,
      ) || !retirementState)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} has malformed retirement-condition evidence.`,
      {reasonCode: "inner-cover-retirement-condition-malformed"},
    );
  }
  return data;
}

function timestampMillis(value: unknown): number | null {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      const milliseconds = Date.prototype.getTime.call(value);
      return Number.isNaN(milliseconds) ? null : milliseconds;
    } catch {
      return null;
    }
  }
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const timestamp = value as {toMillis?: unknown; toDate?: unknown};
  try {
    if (typeof timestamp.toMillis === "function") {
      const milliseconds = timestamp.toMillis.call(value);
      return typeof milliseconds === "number" && Number.isFinite(milliseconds) ?
        milliseconds : null;
    }
    if (typeof timestamp.toDate === "function") {
      const date = timestamp.toDate.call(value);
      return date instanceof Date && !Number.isNaN(date.getTime()) ?
        date.getTime() : null;
    }
  } catch {
    return null;
  }
  return null;
}

function requireBase(data: JsonMap, expectedId: string): JsonMap {
  if (data.schemaVersion !== 1 || data.assetInstanceId !== expectedId ||
      data.status !== "active" || data.serviceState === "outOfService" ||
      !Number.isSafeInteger(data.assetNumber) ||
      typeof data.assetClassId !== "string" || typeof data.name !== "string") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The selected Base is unavailable or malformed.",
      {reasonCode: "inner-cover-base-unavailable"},
    );
  }
  return data;
}

function requireBaseClass(data: JsonMap, expectedId: string) {
  if (data.assetClassId !== expectedId || data.status !== "active" ||
      data.legacyAssetTypeKey !== "base") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The selected physical asset is not an active governed Base.",
      {reasonCode: "inner-cover-base-class-mismatch"},
    );
  }
}

function requireInnerCoverClass(data: JsonMap, expectedId: string) {
  if (data.assetClassId !== expectedId || data.status !== "active" ||
      data.legacyAssetTypeKey !== "innerCover") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Registration requires an active governed Inner Cover asset class.",
      {reasonCode: "inner-cover-class-mismatch"},
    );
  }
}

function requireAssignment(
  data: JsonMap,
  baseId: string,
  cover: JsonMap,
  expectedVersion: number | null,
): JsonMap {
  requireVersion(data, expectedVersion, "Base-to-Inner-Cover assignment");
  if (data.schemaVersion !== 1 || data.baseAssetInstanceId !== baseId ||
      data.innerCoverId !== cover.innerCoverId ||
      data.innerCoverSerialNumber !== cover.serialNumber ||
      data.linkageId !== cover.currentLinkageId) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The Base assignment and Inner Cover projection disagree.",
      {reasonCode: "inner-cover-assignment-drift"},
    );
  }
  return data;
}

function traceabilityGrade(draft: RegistrationDraft): string {
  if (draft.originClassification === "ownerDeclaredNew") return "T1";
  if (draft.originClassification === "ownerDeclaredFabricated" ||
      draft.originClassification === "legacyUndocumented") return "T0";
  if (draft.originClassification === "documentedPurchase") return "T3";
  if (draft.fabricationSections.some(
    (section) => section.materialSource === "reusedUnknownLegacyDonor",
  )) return "T0";
  if (draft.fabricationSections.some(
    (section) => section.materialSource === "reusedKnownDonor",
  )) return "T2";
  return "T3";
}

function profileSnapshot(data: JsonMap | null): JsonMap | null {
  if (data == null) return null;
  return {
    innerCoverId: data.innerCoverId,
    serialNumber: data.serialNumber,
    originClassification: data.originClassification ?? null,
    incorporatedOn: optionalTimestampIso(
      data.incorporatedOn,
      "Inner Cover incorporation date",
    ),
    lifecycleState: data.lifecycleState,
    retirementCondition: data.retirementCondition ?? null,
    currentBaseAssetInstanceId: data.currentBaseAssetInstanceId ?? null,
    currentBaseAssetNumber: data.currentBaseAssetNumber ?? null,
    currentLinkageId: data.currentLinkageId ?? null,
    traceabilityGrade: data.traceabilityGrade,
    version: data.version,
  };
}

function optionalTimestampIso(value: unknown, label: string): string | null {
  if (value == null) return null;
  const milliseconds = timestampMillis(value);
  if (milliseconds == null) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `${label} is malformed.`,
      {reasonCode: "inner-cover-profile-malformed"},
    );
  }
  return new Date(milliseconds).toISOString();
}

function linkRecord(args: {
  linkId: string;
  base: JsonMap;
  cover: JsonMap;
  committedAt: unknown;
  actorUid: string;
  actorName: string;
  requestId: string;
}): JsonMap {
  return {
    schemaVersion: 1,
    linkageId: args.linkId,
    baseAssetInstanceId: args.base.assetInstanceId,
    baseAssetClassId: args.base.assetClassId,
    baseAssetNumber: args.base.assetNumber,
    baseAssetName: args.base.name,
    innerCoverId: args.cover.innerCoverId,
    innerCoverSerialNumber: args.cover.serialNumber,
    installedAt: args.committedAt,
    installedByUid: args.actorUid,
    installedByName: args.actorName,
    removedAt: null,
    removedByUid: null,
    removedByName: null,
    removalAction: null,
    removalReason: null,
    active: true,
    version: 1,
    requestId: args.requestId,
  };
}

function assignmentRecord(args: {
  current: JsonMap | null;
  link: JsonMap;
  committedAt: unknown;
  actorUid: string;
  requestId: string;
}): JsonMap {
  return {
    schemaVersion: 1,
    baseAssetInstanceId: args.link.baseAssetInstanceId,
    baseAssetClassId: args.link.baseAssetClassId,
    baseAssetNumber: args.link.baseAssetNumber,
    baseAssetName: args.link.baseAssetName,
    innerCoverId: args.link.innerCoverId,
    innerCoverSerialNumber: args.link.innerCoverSerialNumber,
    linkageId: args.link.linkageId,
    linkedAt: args.committedAt,
    version: args.current == null ? 1 : (args.current.version as number) + 1,
    updatedAt: args.committedAt,
    updatedByUid: args.actorUid,
    lastMutationId: args.requestId,
  };
}

function installedProfile(
  profile: JsonMap,
  base: JsonMap,
  linkId: string,
  version: number,
  committedAt: unknown,
  actorUid: string,
  actorName: string,
  requestId: string,
): JsonMap {
  return {
    ...profile,
    lifecycleState: "installed",
    currentBaseAssetInstanceId: base.assetInstanceId,
    currentBaseAssetNumber: base.assetNumber,
    currentBaseAssetName: base.name,
    currentLinkageId: linkId,
    version,
    updatedAt: committedAt,
    updatedByUid: actorUid,
    updatedByName: actorName,
    lastMutationId: requestId,
  };
}

function uninstalledProfile(
  profile: JsonMap,
  state: InnerCoverLifecycleState,
  version: number,
  committedAt: unknown,
  actorUid: string,
  actorName: string,
  requestId: string,
): JsonMap {
  return {
    ...profile,
    lifecycleState: state,
    currentBaseAssetInstanceId: null,
    currentBaseAssetNumber: null,
    currentBaseAssetName: null,
    currentLinkageId: null,
    version,
    updatedAt: committedAt,
    updatedByUid: actorUid,
    updatedByName: actorName,
    lastMutationId: requestId,
  };
}

function closeLink(
  current: JsonMap,
  action: string,
  reason: string,
  committedAt: unknown,
  actorUid: string,
  actorName: string,
): JsonMap {
  if (current.schemaVersion !== 1 || current.active !== true ||
      current.removedAt != null || !Number.isSafeInteger(current.version)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The active linkage history record is malformed.",
      {reasonCode: "inner-cover-linkage-history-malformed"},
    );
  }
  return {
    ...current,
    removedAt: committedAt,
    removedByUid: actorUid,
    removedByName: actorName,
    removalAction: action,
    removalReason: reason,
    active: false,
    version: (current.version as number) + 1,
  };
}

function replayResult(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): InnerCoverLifecycleMutationResult {
  if (data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation ||
      data.innerCoverId !== request.innerCoverId ||
      !Number.isSafeInteger(data.version) || typeof data.auditId !== "string" ||
      typeof data.committedAtIso !== "string") {
    throw new AssetHierarchyMutationError(
      "already-exists",
      "This request ID is already bound to a different Inner Cover command.",
      {reasonCode: "inner-cover-request-id-reused"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    innerCoverId: request.innerCoverId,
    version: data.version as number,
    secondaryVersion: Number.isSafeInteger(data.secondaryVersion) ?
      data.secondaryVersion as number : null,
    auditId: data.auditId,
    committedAt: data.committedAtIso,
    idempotentReplay: true,
  };
}

export async function mutateInnerCoverLifecycleWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<InnerCoverLifecycleMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated", "Sign in before changing the Inner Cover lifecycle.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseInnerCoverLifecycleMutationRequest(args.data);
  const db = args.db as unknown as LifecycleDbLike;
  const users = db.collection("users");
  const classes = db.collection("asset_classes");
  const assets = db.collection("asset_instances");
  const profiles = db.collection("inner_cover_profiles");
  const assignments = db.collection("base_inner_cover_assignments");
  const linkages = db.collection("inner_cover_linkages");
  const serialClaims = db.collection("inner_cover_serial_claims");
  const donorClaims = db.collection("inner_cover_donor_part_claims");
  const fabrications = db.collection("inner_cover_fabrications");
  const audits = db.collection("inner_cover_lifecycle_audits");
  const receipts = db.collection("inner_cover_lifecycle_receipts");
  const actorRef = users.doc(actorUid);
  const profileRef = profiles.doc(request.innerCoverId);
  const receiptRef = receipts.doc(request.requestId);
  const auditId = `inner_cover_${request.requestId}`;
  const auditRef = audits.doc(auditId);

  requireAdmin(record(await actorRef.get(), "Inner Cover actor"));

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    const actor = requireAdmin(record(
      await transaction.get(actorRef), "Inner Cover actor",
    ));
    if (receipt.exists) {
      const replay = replayResult(request, actorUid, receipt.data() ?? {});
      const currentProfile = requireProfile(
        record(await transaction.get(profileRef), "Recorded Inner Cover"),
        request.innerCoverId,
        "Recorded Inner Cover",
      );
      const audit = record(
        await transaction.get(auditRef), "Recorded Inner Cover audit",
      );
      if (currentProfile.version !== replay.version ||
          currentProfile.lastMutationId !== request.requestId ||
          audit.requestId !== request.requestId ||
          audit.performedByUid !== actorUid) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "The Inner Cover receipt no longer matches its evidence.",
          {reasonCode: "inner-cover-replay-evidence-drift"},
        );
      }
      return replay;
    }

    const profileDocument = await transaction.get(profileRef);
    const currentProfile = profileDocument.exists ? requireProfile(
      profileDocument.data() ?? {}, request.innerCoverId, "Inner Cover",
    ) : null;
    const displacedRef = request.displacedInnerCoverId == null ? null :
      profiles.doc(request.displacedInnerCoverId);
    const displacedSnapshot = displacedRef == null ? null :
      await transaction.get(displacedRef);
    const displacedProfile = displacedSnapshot?.exists === true ?
      requireProfile(
        displacedSnapshot.data() ?? {},
        request.displacedInnerCoverId!,
        "Displaced Inner Cover",
      ) : null;
    const sourceBaseRef = request.sourceBaseAssetInstanceId == null ? null :
      assets.doc(request.sourceBaseAssetInstanceId);
    const targetBaseRef = request.targetBaseAssetInstanceId == null ? null :
      assets.doc(request.targetBaseAssetInstanceId);
    const sourceBase = sourceBaseRef == null ? null : requireBase(
      record(await transaction.get(sourceBaseRef), "Source Base"),
      request.sourceBaseAssetInstanceId!,
    );
    const targetBase = targetBaseRef == null ? null : requireBase(
      record(await transaction.get(targetBaseRef), "Target Base"),
      request.targetBaseAssetInstanceId!,
    );
    const sourceClassRef = sourceBase == null ? null :
      classes.doc(sourceBase.assetClassId as string);
    const targetClassRef = targetBase == null ? null :
      classes.doc(targetBase.assetClassId as string);
    if (sourceClassRef != null) {
      requireBaseClass(
        record(await transaction.get(sourceClassRef), "Source Base class"),
        sourceBase!.assetClassId as string,
      );
    }
    if (targetClassRef != null &&
        targetBase?.assetClassId !== sourceBase?.assetClassId) {
      requireBaseClass(
        record(await transaction.get(targetClassRef), "Target Base class"),
        targetBase!.assetClassId as string,
      );
    }
    const sourceAssignmentRef = request.sourceBaseAssetInstanceId == null ?
      null : assignments.doc(request.sourceBaseAssetInstanceId);
    const targetAssignmentRef = request.targetBaseAssetInstanceId == null ?
      null : assignments.doc(request.targetBaseAssetInstanceId);
    const sourceAssignmentSnapshot = sourceAssignmentRef == null ? null :
      await transaction.get(sourceAssignmentRef);
    const targetAssignmentSnapshot = targetAssignmentRef == null ? null :
      await transaction.get(targetAssignmentRef);

    const nowDate = args.now?.() ?? new Date();
    const committedAtIso = nowDate.toISOString();
    const toTimestamp = args.timestampFromDate ?? ((date: Date) => date);
    const committedAt = toTimestamp(nowDate);
    const actorName = typeof actor.name === "string" && actor.name.trim() ?
      actor.name.trim() : actorUid;
    let after: JsonMap;
    let secondaryAfter: JsonMap | null = null;
    let nextVersion: number;
    let secondaryVersion: number | null = null;
    const before = profileSnapshot(currentProfile);
    const relatedEntityChanges: JsonMap[] = [];

    if (request.operation === "REGISTER_INNER_COVER") {
      if (currentProfile != null) {
        throw new AssetHierarchyMutationError(
          "already-exists", "The Inner Cover is already registered.",
        );
      }
      const draft = request.registrationDraft!;
      if (draft.receivedOrCompletedOn != null &&
          draft.receivedOrCompletedOn.getTime() > nowDate.getTime()) {
        invalid(
          "registrationDraft.receivedOrCompletedOn",
          "cannot be in the future",
        );
      }
      if (draft.incorporatedOn != null &&
          draft.incorporatedOn.getTime() > nowDate.getTime()) {
        invalid(
          "registrationDraft.incorporatedOn",
          "cannot be in the future",
        );
      }
      if (draft.receivedOrCompletedOn != null &&
          draft.incorporatedOn != null &&
          draft.receivedOrCompletedOn.getTime() >
            draft.incorporatedOn.getTime()) {
        invalid(
          "registrationDraft.incorporatedOn",
          "cannot predate receipt or fabrication completion",
        );
      }
      const classRef = classes.doc(request.innerCoverAssetClassId!);
      const classData = record(
        await transaction.get(classRef), "Inner Cover asset class",
      );
      requireInnerCoverClass(classData, request.innerCoverAssetClassId!);
      const serialClaimId = createHash("sha256")
        .update(draft.normalizedSerialNumber, "utf8").digest("hex");
      const serialClaimRef = serialClaims.doc(serialClaimId);
      if ((await transaction.get(serialClaimRef)).exists) {
        throw new AssetHierarchyMutationError(
          "already-exists",
          `Inner Cover serial ${draft.serialNumber} is already registered.`,
          {
            reasonCode: "inner-cover-serial-collision",
            normalizedSerialNumber: draft.normalizedSerialNumber,
          },
        );
      }
      const donorUpdates = new Map<string, {
        ref: DocumentRefLike;
        profile: JsonMap;
      }>();
      const donorClaimWrites: Array<{
        ref: DocumentRefLike;
        data: JsonMap;
      }> = [];
      const donorClaimIds = new Set<string>();
      for (const section of draft.fabricationSections) {
        if (section.materialSource !== "reusedKnownDonor") continue;
        if (section.donorInnerCoverId === request.innerCoverId) {
          invalid(
            "registrationDraft.fabricationSections",
            "cannot use the resulting Inner Cover as its own donor",
          );
        }
        const donorRef = profiles.doc(section.donorInnerCoverId!);
        let donor = donorUpdates.get(section.donorInnerCoverId!)?.profile;
        if (donor == null) {
          donor = requireProfile(
            record(await transaction.get(donorRef), "Donor Inner Cover"),
            section.donorInnerCoverId!,
            "Donor Inner Cover",
          );
          requireVersion(
            donor, section.donorExpectedVersion, "Donor Inner Cover",
          );
          if (!new Set([
            "retiredForSalvage", "partiallyDismantled",
          ]).has(donor.lifecycleState as string)) {
            throw new AssetHierarchyMutationError(
              "failed-precondition",
              "Known donor material requires a retired salvage Inner Cover.",
              {reasonCode: "inner-cover-donor-not-salvageable"},
            );
          }
          donorUpdates.set(section.donorInnerCoverId!, {ref: donorRef, profile: donor});
        } else if (donor.version !== section.donorExpectedVersion) {
          invalid(
            "registrationDraft.fabricationSections",
            "must use one consistent expected version per donor",
          );
        }
        const claimId = createHash("sha256").update(
          `${section.donorInnerCoverId}:${section.donorSectionKey}`,
          "utf8",
        ).digest("hex");
        const claimRef = donorClaims.doc(claimId);
        if (!donorClaimIds.add(claimId)) {
          invalid(
            "registrationDraft.fabricationSections",
            "cannot allocate the same donor part more than once",
          );
        }
        if ((await transaction.get(claimRef)).exists) {
          throw new AssetHierarchyMutationError(
            "already-exists",
            "A selected donor section has already been allocated.",
            {reasonCode: "inner-cover-donor-part-already-consumed"},
          );
        }
        donorClaimWrites.push({
          ref: claimRef,
          data: {
            schemaVersion: 1,
            claimId,
            donorInnerCoverId: section.donorInnerCoverId,
            donorSerialNumber: donor.serialNumber,
            donorSectionKey: section.donorSectionKey,
            resultingInnerCoverId: request.innerCoverId,
            fabricationSectionId: section.sectionId,
            claimedAt: committedAt,
            claimedByUid: actorUid,
            requestId: request.requestId,
          },
        });
      }
      for (const claim of donorClaimWrites) {
        transaction.set(claim.ref, claim.data);
      }
      for (const donor of donorUpdates.values()) {
        const donorAfter = uninstalledProfile(
          donor.profile,
          "partiallyDismantled",
          (donor.profile.version as number) + 1,
          committedAt,
          actorUid,
          actorName,
          request.requestId,
        );
        transaction.set(donor.ref, donorAfter);
        relatedEntityChanges.push({
          entityType: "inner_cover_donor",
          entityId: donor.profile.innerCoverId,
          before: profileSnapshot(donor.profile),
          after: profileSnapshot(donorAfter),
        });
      }
      nextVersion = 1;
      after = {
        schemaVersion: 1,
        innerCoverId: request.innerCoverId,
        assetClassId: request.innerCoverAssetClassId,
        assetClassCode: classData.code,
        assetClassName: classData.name,
        serialNumber: draft.serialNumber,
        normalizedSerialNumber: draft.normalizedSerialNumber,
        sourceType: draft.sourceType,
        originClassification: draft.originClassification,
        lifecycleState: "awaitingInspection",
        traceabilityGrade: traceabilityGrade(draft),
        supplierOrFabricator: draft.supplierOrFabricator,
        receivedOrCompletedOn: draft.receivedOrCompletedOn == null ? null :
          toTimestamp(draft.receivedOrCompletedOn),
        incorporatedOn: draft.incorporatedOn == null ? null :
          toTimestamp(draft.incorporatedOn),
        drawingReference: draft.drawingReference,
        materialGrade: draft.materialGrade,
        registrationNotes: draft.notes,
        acceptanceReference: null,
        acceptedAt: null,
        acceptedByUid: null,
        acceptedByName: null,
        currentBaseAssetInstanceId: null,
        currentBaseAssetNumber: null,
        currentBaseAssetName: null,
        currentLinkageId: null,
        version: nextVersion,
        createdAt: committedAt,
        createdByUid: actorUid,
        createdByName: actorName,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName,
        lastMutationId: request.requestId,
      };
      transaction.set(profileRef, after);
      transaction.set(serialClaimRef, {
        schemaVersion: 1,
        normalizedSerialNumber: draft.normalizedSerialNumber,
        serialNumber: draft.serialNumber,
        innerCoverId: request.innerCoverId,
        claimedAt: committedAt,
        claimedByUid: actorUid,
      });
      if (draft.sourceType === "fabricated") {
        transaction.set(fabrications.doc(request.innerCoverId), {
          schemaVersion: 1,
          fabricationId: request.innerCoverId,
          resultingInnerCoverId: request.innerCoverId,
          resultingSerialNumber: draft.serialNumber,
          supplierOrFabricator: draft.supplierOrFabricator,
          originClassification: draft.originClassification,
          incorporatedOn: draft.incorporatedOn == null ? null :
            toTimestamp(draft.incorporatedOn),
          completedOn: draft.receivedOrCompletedOn == null ? null :
            toTimestamp(draft.receivedOrCompletedOn),
          drawingReference: draft.drawingReference,
          materialGrade: draft.materialGrade,
          traceabilityGrade: traceabilityGrade(draft),
          sections: draft.fabricationSections.map((section) => ({
            sectionId: section.sectionId,
            sectionType: section.sectionType,
            materialSource: section.materialSource,
            donorInnerCoverId: section.donorInnerCoverId,
            donorSectionKey: section.donorSectionKey,
            lengthMm: section.lengthMm,
            cutCount: section.cutCount,
            notes: section.notes,
          })),
          status: "awaitingInspection",
          acceptanceReference: null,
          createdAt: committedAt,
          createdByUid: actorUid,
          requestId: request.requestId,
        });
      }
    } else {
      const current = currentProfile ?? record(profileDocument, "Inner Cover");
      const currentVersion = requireVersion(
        current, request.expectedVersion, "Inner Cover",
      );
      if (request.operation === "ACCEPT_INNER_COVER") {
        if (!new Set(["awaitingInspection", "underInspection"]).has(
          current.lifecycleState as string,
        )) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Only an inspected or inspection-ready Inner Cover can be accepted.",
            {reasonCode: "inner-cover-not-awaiting-acceptance"},
          );
        }
        const acceptance = request.acceptanceDraft!;
        if (acceptance.inspectedOn.getTime() > nowDate.getTime()) {
          invalid("acceptanceDraft.inspectedOn", "cannot be in the future");
        }
        const receivedAt = timestampMillis(current.receivedOrCompletedOn);
        if (receivedAt != null && acceptance.inspectedOn.getTime() < receivedAt) {
          invalid(
            "acceptanceDraft.inspectedOn",
            "cannot predate receipt or fabrication completion",
          );
        }
        const fabricationRef = fabrications.doc(request.innerCoverId);
        const fabrication = await transaction.get(fabricationRef);
        nextVersion = currentVersion + 1;
        after = {
          ...uninstalledProfile(
            current, "available", nextVersion, committedAt, actorUid,
            actorName, request.requestId,
          ),
          acceptanceReference: acceptance.acceptanceReference,
          acceptedAt: toTimestamp(acceptance.inspectedOn),
          acceptedByUid: actorUid,
          acceptedByName: actorName,
          leakTestReference: acceptance.leakTestReference,
          ndtReference: acceptance.ndtReference,
          acceptanceNotes: acceptance.notes,
        };
        transaction.set(profileRef, after);
        if (fabrication.exists) {
          transaction.set(fabricationRef, {
            ...(fabrication.data() ?? {}),
            status: "accepted",
            acceptanceReference: acceptance.acceptanceReference,
            acceptedAt: toTimestamp(acceptance.inspectedOn),
            acceptedByUid: actorUid,
            lastMutationId: request.requestId,
          });
        }
      } else if (request.operation === "SET_INNER_COVER_STATE") {
        const target = request.targetState!;
        if (current.lifecycleState === "installed") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Delink an installed Inner Cover before changing its pool state.",
            {reasonCode: "inner-cover-installed-state-change"},
          );
        }
        if (!STATE_TRANSITIONS[current.lifecycleState as string]?.has(target)) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            `The ${current.lifecycleState} to ${target} transition is not allowed.`,
            {reasonCode: "inner-cover-state-transition-invalid"},
          );
        }
        nextVersion = currentVersion + 1;
        after = uninstalledProfile(
          current, target, nextVersion, committedAt, actorUid, actorName,
          request.requestId,
        );
        if (target === "retiredForSalvage") {
          after.retirementCondition = request.retirementCondition;
        }
        transaction.set(profileRef, after);
      } else if (request.operation === "LINK_INNER_COVER") {
        if (current.lifecycleState !== "available") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Only an available Inner Cover can be linked to a Base.",
            {reasonCode: "inner-cover-not-available"},
          );
        }
        if (targetAssignmentSnapshot?.exists === true) {
          const targetData = targetAssignmentSnapshot.data() ?? {};
          throw new AssetHierarchyMutationError(
            "already-exists",
            "The target Base already has an Inner Cover. Use replace or swap.",
            {
              reasonCode: "inner-cover-target-base-occupied",
              existingInnerCoverId: targetData.innerCoverId,
              existingSerialNumber: targetData.innerCoverSerialNumber,
            },
          );
        }
        const linkId = `link_${request.requestId}`;
        const link = linkRecord({
          linkId,
          base: targetBase!,
          cover: current,
          committedAt,
          actorUid,
          actorName,
          requestId: request.requestId,
        });
        nextVersion = currentVersion + 1;
        after = installedProfile(
          current, targetBase!, linkId, nextVersion, committedAt, actorUid,
          actorName, request.requestId,
        );
        transaction.set(profileRef, after);
        transaction.set(linkages.doc(linkId), link);
        transaction.set(targetAssignmentRef!, assignmentRecord({
          current: null,
          link,
          committedAt,
          actorUid,
          requestId: request.requestId,
        }));
      } else if (request.operation === "REPLACE_INNER_COVER") {
        if (current.lifecycleState !== "available") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Only an available Inner Cover can replace an installed cover.",
            {reasonCode: "inner-cover-not-available"},
          );
        }
        const displaced = displacedProfile ?? record(
          displacedSnapshot!, "Displaced Inner Cover",
        );
        const displacedVersion = requireVersion(
          displaced, request.expectedDisplacedVersion, "Displaced Inner Cover",
        );
        if (displaced.lifecycleState !== "installed" ||
            displaced.currentBaseAssetInstanceId !==
              request.targetBaseAssetInstanceId) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "The reviewed displaced Inner Cover is no longer on the target Base.",
            {reasonCode: "inner-cover-replacement-target-changed"},
          );
        }
        const targetAssignment = requireAssignment(
          record(targetAssignmentSnapshot!, "Target Base assignment"),
          request.targetBaseAssetInstanceId!,
          displaced,
          request.expectedTargetAssignmentVersion,
        );
        const displacedLinkRef = linkages.doc(
          displaced.currentLinkageId as string,
        );
        const displacedLink = record(
          await transaction.get(displacedLinkRef),
          "Displaced linkage history",
        );
        transaction.set(displacedLinkRef, closeLink(
          displacedLink, request.operation, request.reason, committedAt,
          actorUid, actorName,
        ));
        const linkId = `link_${request.requestId}`;
        const link = linkRecord({
          linkId,
          base: targetBase!,
          cover: current,
          committedAt,
          actorUid,
          actorName,
          requestId: request.requestId,
        });
        nextVersion = currentVersion + 1;
        secondaryVersion = displacedVersion + 1;
        after = installedProfile(
          current, targetBase!, linkId, nextVersion, committedAt, actorUid,
          actorName, request.requestId,
        );
        secondaryAfter = uninstalledProfile(
          displaced,
          request.targetState!,
          secondaryVersion,
          committedAt,
          actorUid,
          actorName,
          request.requestId,
        );
        transaction.set(profileRef, after);
        transaction.set(displacedRef!, secondaryAfter);
        transaction.set(linkages.doc(linkId), link);
        transaction.set(targetAssignmentRef!, assignmentRecord({
          current: targetAssignment,
          link,
          committedAt,
          actorUid,
          requestId: request.requestId,
        }));
      } else {
        if (current.lifecycleState !== "installed") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "This command requires an installed Inner Cover.",
            {reasonCode: "inner-cover-not-installed"},
          );
        }
        const sourceAssignment = requireAssignment(
          record(sourceAssignmentSnapshot!, "Source Base assignment"),
          request.sourceBaseAssetInstanceId!,
          current,
          request.expectedSourceAssignmentVersion,
        );
        const oldLinkRef = linkages.doc(current.currentLinkageId as string);
        const oldLink = record(
          await transaction.get(oldLinkRef), "Current linkage history",
        );
        if (request.operation === "DELINK_INNER_COVER") {
          transaction.set(oldLinkRef, closeLink(
            oldLink, request.operation, request.reason, committedAt, actorUid,
            actorName,
          ));
          nextVersion = currentVersion + 1;
          after = uninstalledProfile(
            current, request.targetState!, nextVersion, committedAt, actorUid,
            actorName, request.requestId,
          );
          transaction.set(profileRef, after);
          transaction.delete(sourceAssignmentRef!);
        } else if (request.operation === "TRANSFER_INNER_COVER") {
          if (targetAssignmentSnapshot?.exists === true) {
            throw new AssetHierarchyMutationError(
              "already-exists",
              "The target Base already has an Inner Cover. Use swap.",
              {reasonCode: "inner-cover-target-base-occupied"},
            );
          }
          const linkId = `link_${request.requestId}`;
          const link = linkRecord({
            linkId,
            base: targetBase!,
            cover: current,
            committedAt,
            actorUid,
            actorName,
            requestId: request.requestId,
          });
          nextVersion = currentVersion + 1;
          after = installedProfile(
            current, targetBase!, linkId, nextVersion, committedAt, actorUid,
            actorName, request.requestId,
          );
          transaction.set(oldLinkRef, closeLink(
            oldLink, request.operation, request.reason, committedAt, actorUid,
            actorName,
          ));
          transaction.set(profileRef, after);
          transaction.delete(sourceAssignmentRef!);
          transaction.set(targetAssignmentRef!, assignmentRecord({
            current: null,
            link,
            committedAt,
            actorUid,
            requestId: request.requestId,
          }));
          transaction.set(linkages.doc(linkId), link);
        } else if (request.operation === "SWAP_INNER_COVERS") {
          const displaced = displacedProfile ?? record(
            displacedSnapshot!, "Displaced Inner Cover",
          );
          const displacedVersion = requireVersion(
            displaced, request.expectedDisplacedVersion,
            "Displaced Inner Cover",
          );
          if (displaced.lifecycleState !== "installed") {
            throw new AssetHierarchyMutationError(
              "failed-precondition", "The displaced Inner Cover is not installed.",
            );
          }
          const targetAssignment = requireAssignment(
            record(targetAssignmentSnapshot!, "Target Base assignment"),
            request.targetBaseAssetInstanceId!,
            displaced,
            request.expectedTargetAssignmentVersion,
          );
          const displacedLinkRef = linkages.doc(
            displaced.currentLinkageId as string,
          );
          const displacedLink = record(
            await transaction.get(displacedLinkRef),
            "Displaced linkage history",
          );
          transaction.set(oldLinkRef, closeLink(
            oldLink, request.operation, request.reason, committedAt, actorUid,
            actorName,
          ));
          transaction.set(displacedLinkRef, closeLink(
            displacedLink, request.operation, request.reason, committedAt,
            actorUid, actorName,
          ));
          const primaryLink = linkRecord({
            linkId: `link_${request.requestId}_primary`,
            base: targetBase!,
            cover: current,
            committedAt,
            actorUid,
            actorName,
            requestId: request.requestId,
          });
          const secondaryLink = linkRecord({
            linkId: `link_${request.requestId}_secondary`,
            base: sourceBase!,
            cover: displaced,
            committedAt,
            actorUid,
            actorName,
            requestId: request.requestId,
          });
          nextVersion = currentVersion + 1;
          secondaryVersion = displacedVersion + 1;
          after = installedProfile(
            current, targetBase!, primaryLink.linkageId as string,
            nextVersion, committedAt, actorUid, actorName, request.requestId,
          );
          secondaryAfter = installedProfile(
            displaced, sourceBase!, secondaryLink.linkageId as string,
            secondaryVersion, committedAt, actorUid, actorName,
            request.requestId,
          );
          transaction.set(profileRef, after);
          transaction.set(displacedRef!, secondaryAfter);
          transaction.set(linkages.doc(primaryLink.linkageId as string), primaryLink);
          transaction.set(linkages.doc(secondaryLink.linkageId as string), secondaryLink);
          transaction.set(sourceAssignmentRef!, assignmentRecord({
            current: sourceAssignment,
            link: secondaryLink,
            committedAt,
            actorUid,
            requestId: request.requestId,
          }));
          transaction.set(targetAssignmentRef!, assignmentRecord({
            current: targetAssignment,
            link: primaryLink,
            committedAt,
            actorUid,
            requestId: request.requestId,
          }));
        } else {
          throw new AssetHierarchyMutationError(
            "internal", "Unsupported installed Inner Cover command.",
          );
        }
      }
    }

    transaction.set(auditRef, {
      schemaVersion: 1,
      auditId,
      entityType: "inner_cover",
      entityId: request.innerCoverId,
      secondaryEntityId: request.displacedInnerCoverId,
      operation: request.operation,
      reason: request.reason,
      beforeJson: before == null ? null : JSON.stringify(before),
      afterJson: JSON.stringify(profileSnapshot(after)),
      secondaryAfterJson: secondaryAfter == null ? null :
        JSON.stringify(profileSnapshot(secondaryAfter)),
      relatedEntityChangesJson: relatedEntityChanges.length === 0 ? null :
        JSON.stringify(relatedEntityChanges),
      performedAt: committedAt,
      performedByUid: actorUid,
      performedByName: actorName,
      requestId: request.requestId,
    });
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      innerCoverId: request.innerCoverId,
      version: nextVersion,
      secondaryVersion,
      auditId,
      committedAt,
      committedAtIso,
    });
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      innerCoverId: request.innerCoverId,
      version: nextVersion,
      secondaryVersion,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
