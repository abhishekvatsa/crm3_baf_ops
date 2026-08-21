import {createHash} from "crypto";

import {canonicalApprovedUserAuthority, normalizeCanonicalUserRoles} from "./userAuthority";
import {
  AssetHierarchyMutationError,
  AssetHierarchyMutationFirestoreLike,
  normalizeAssetHierarchyTag,
} from "./assetHierarchyMutation";
import {stableJson} from "./stableJson";
import {activeAssetOperationalConditionForRegistry} from
  "./assetOperationalConditionMutation";

type JsonMap = {[key: string]: unknown};
type SnapshotLike = {exists: boolean; id?: string; data: () => JsonMap | undefined};
type DocumentRefLike = {id?: string; path?: string; get: () => Promise<SnapshotLike>};
type QuerySnapshotLike = {docs: SnapshotLike[]};
type TransactionLike = {
  get: (ref: unknown) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
  delete: (ref: DocumentRefLike) => void;
};

type RegistryOperation =
  | "CREATE_ASSET_INSTANCE"
  | "UPDATE_ASSET_INSTANCE"
  | "SET_ASSET_INSTANCE_STATUS"
  | "CREATE_COMPONENT_INSTANCE"
  | "UPDATE_COMPONENT_INSTANCE"
  | "REPLACE_COMPONENT_INSTANCE"
  | "SET_COMPONENT_INSTANCE_STATUS";

interface AssetDraft {
  assetNumber: number;
  name: string;
  plantTag: string | null;
  location: string | null;
  manufacturer: string | null;
  model: string | null;
  serialNumber: string | null;
  commissionedOn: Date | null;
  serviceState: "inService" | "standby" | "outOfService";
  ownershipStatus: "unassigned" | "provisional" | "confirmed";
  ownerDiscipline: string | null;
  accountableRoleKeys: ReadonlyArray<string>;
}

interface ComponentDraft {
  definitionNodeId: string;
  componentTag: string | null;
  normalizedComponentTag: string | null;
  manufacturer: string | null;
  model: string | null;
  serialNumber: string | null;
  installedOn: Date | null;
  serviceState: "inService" | "standby" | "outOfService";
  ownershipStatus: "unassigned" | "provisional" | "confirmed";
  ownerDiscipline: string | null;
  accountableRoleKeys: ReadonlyArray<string>;
}

type ReplacementEvidenceSource = "maintenanceIssue" | "plannedJob";

interface ReplacementEvidenceReference {
  sourceType: ReplacementEvidenceSource;
  sourceId: string;
  expectedVersion: number;
}

interface RegistryRequest {
  requestId: string;
  operation: RegistryOperation;
  assetClassId: string;
  assetInstanceId: string;
  componentInstanceId: string | null;
  replacementComponentInstanceId: string | null;
  expectedVersion: number | null;
  expectedAssetClassVersion: number | null;
  expectedAssetInstanceVersion: number | null;
  status: "active" | "retired" | null;
  reason: string;
  allowTagTransfer: boolean;
  expectedTagOwnerComponentId: string | null;
  evidenceReference: ReplacementEvidenceReference | null;
  assetDraft: AssetDraft | null;
  componentDraft: ComponentDraft | null;
  fingerprint: string;
}

export interface AssetRegistryMutationResult {
  ok: true;
  requestId: string;
  operation: RegistryOperation;
  assetClassId: string;
  nodeId: string;
  version: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<RegistryOperation>([
  "CREATE_ASSET_INSTANCE", "UPDATE_ASSET_INSTANCE", "SET_ASSET_INSTANCE_STATUS",
  "CREATE_COMPONENT_INSTANCE", "UPDATE_COMPONENT_INSTANCE", "REPLACE_COMPONENT_INSTANCE",
  "SET_COMPONENT_INSTANCE_STATUS",
]);
const SERVICE_STATES = new Set(["inService", "standby", "outOfService"]);
const OWNERSHIP = new Set(["unassigned", "provisional", "confirmed"]);
const REPLACEMENT_EVIDENCE_SOURCES = new Set<ReplacementEvidenceSource>([
  "maintenanceIssue", "plannedJob",
]);

export function isAssetRegistryOperation(value: unknown): value is RegistryOperation {
  return typeof value === "string" && OPERATIONS.has(value as RegistryOperation);
}

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument", `${field} ${detail}.`,
    {reasonCode: "invalid-asset-registry-request", field},
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
  if (typeof value !== "string") invalid(field, "must be a string or null");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > max) invalid(field, `cannot exceed ${max} characters`);
  return cleaned;
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) invalid(field, "is invalid");
  return id;
}

function uuid(value: unknown, field: string): string {
  const id = requiredString(value, field, 64);
  if (!UUID.test(id)) invalid(field, "must be a canonical UUID");
  return id;
}

function optionalVersion(value: unknown, field: string): number | null {
  if (value == null) return null;
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    invalid(field, "must be a positive integer");
  }
  return value as number;
}

function optionalDate(value: unknown, field: string): Date | null {
  if (value == null) return null;
  const text = requiredString(value, field, 40);
  const date = new Date(text);
  if (Number.isNaN(date.getTime()) || date.toISOString() !== text) {
    invalid(field, "must be a canonical UTC ISO timestamp");
  }
  return date;
}

function parseOwnership(map: JsonMap, prefix: string) {
  const ownershipStatus = requiredString(
    map.ownershipStatus, `${prefix}.ownershipStatus`, 32,
  );
  if (!OWNERSHIP.has(ownershipStatus)) {
    invalid(`${prefix}.ownershipStatus`, "is unsupported");
  }
  if (!Array.isArray(map.accountableRoleKeys) ||
      map.accountableRoleKeys.length > 10 ||
      map.accountableRoleKeys.some((item) => typeof item !== "string")) {
    invalid(`${prefix}.accountableRoleKeys`, "must be a list of at most 10 roles");
  }
  let roles: ReadonlyArray<string>;
  try {
    roles = map.accountableRoleKeys.length === 0 ? [] :
      normalizeCanonicalUserRoles(map.accountableRoleKeys as string[]);
  } catch {
    invalid(`${prefix}.accountableRoleKeys`, "contains an unknown role");
  }
  const ownerDiscipline = optionalString(
    map.ownerDiscipline, `${prefix}.ownerDiscipline`, 120,
  );
  if (ownershipStatus === "confirmed" &&
      (ownerDiscipline == null || roles.length === 0)) {
    invalid(
      `${prefix}.ownershipStatus`,
      "requires an owner discipline and accountable role when confirmed",
    );
  }
  if (ownershipStatus === "provisional" &&
      ownerDiscipline == null && roles.length === 0) {
    invalid(
      `${prefix}.ownershipStatus`,
      "requires an owner discipline or accountable role when provisional",
    );
  }
  if (ownershipStatus === "unassigned" &&
      (ownerDiscipline != null || roles.length > 0)) {
    invalid(
      `${prefix}.ownershipStatus`,
      "cannot carry an owner discipline or accountable roles when unassigned",
    );
  }
  return {
    ownershipStatus: ownershipStatus as AssetDraft["ownershipStatus"],
    ownerDiscipline,
    accountableRoleKeys: roles,
  };
}

function parseServiceState(value: unknown, field: string): AssetDraft["serviceState"] {
  const state = requiredString(value, field, 32);
  if (!SERVICE_STATES.has(state)) invalid(field, "is unsupported");
  return state as AssetDraft["serviceState"];
}

function parseAssetDraft(value: unknown): AssetDraft {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid("assetDraft", "must be an object");
  }
  const map = value as JsonMap;
  const allowed = new Set([
    "assetNumber", "name", "plantTag", "location", "manufacturer", "model",
    "serialNumber", "commissionedOn", "serviceState", "ownershipStatus",
    "ownerDiscipline", "accountableRoleKeys",
  ]);
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`assetDraft.${key}`, "is unsupported");
  }
  if (!Number.isSafeInteger(map.assetNumber) ||
      (map.assetNumber as number) < 1 || (map.assetNumber as number) > 9999) {
    invalid("assetDraft.assetNumber", "must be an integer from 1 to 9999");
  }
  return {
    assetNumber: map.assetNumber as number,
    name: requiredString(map.name, "assetDraft.name", 160),
    plantTag: optionalString(map.plantTag, "assetDraft.plantTag", 160),
    location: optionalString(map.location, "assetDraft.location", 240),
    manufacturer: optionalString(map.manufacturer, "assetDraft.manufacturer", 160),
    model: optionalString(map.model, "assetDraft.model", 160),
    serialNumber: optionalString(map.serialNumber, "assetDraft.serialNumber", 160),
    commissionedOn: optionalDate(map.commissionedOn, "assetDraft.commissionedOn"),
    serviceState: parseServiceState(map.serviceState, "assetDraft.serviceState"),
    ...parseOwnership(map, "assetDraft"),
  };
}

function parseComponentDraft(value: unknown): ComponentDraft {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid("componentDraft", "must be an object");
  }
  const map = value as JsonMap;
  const allowed = new Set([
    "definitionNodeId", "componentTag", "manufacturer", "model", "serialNumber",
    "installedOn", "serviceState", "ownershipStatus", "ownerDiscipline",
    "accountableRoleKeys",
  ]);
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`componentDraft.${key}`, "is unsupported");
  }
  const componentTag = optionalString(
    map.componentTag, "componentDraft.componentTag", 160,
  );
  const normalizedComponentTag = componentTag == null ? null :
    normalizeAssetHierarchyTag(componentTag);
  if (componentTag != null && normalizedComponentTag?.length === 0) {
    invalid("componentDraft.componentTag", "must contain letters or numbers");
  }
  return {
    definitionNodeId: documentId(map.definitionNodeId, "componentDraft.definitionNodeId"),
    componentTag,
    normalizedComponentTag,
    manufacturer: optionalString(map.manufacturer, "componentDraft.manufacturer", 160),
    model: optionalString(map.model, "componentDraft.model", 160),
    serialNumber: optionalString(map.serialNumber, "componentDraft.serialNumber", 160),
    installedOn: optionalDate(map.installedOn, "componentDraft.installedOn"),
    serviceState: parseServiceState(map.serviceState, "componentDraft.serviceState"),
    ...parseOwnership(map, "componentDraft"),
  };
}

function parseReplacementEvidenceReference(
  value: unknown,
): ReplacementEvidenceReference | null {
  if (value == null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    invalid("evidenceReference", "must be an object or null");
  }
  const map = value as JsonMap;
  const allowed = new Set(["sourceType", "sourceId", "expectedVersion"]);
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`evidenceReference.${key}`, "is unsupported");
  }
  const sourceType = requiredString(
    map.sourceType, "evidenceReference.sourceType", 32,
  ) as ReplacementEvidenceSource;
  if (!REPLACEMENT_EVIDENCE_SOURCES.has(sourceType)) {
    invalid("evidenceReference.sourceType", "is unsupported");
  }
  const expectedVersion = optionalVersion(
    map.expectedVersion, "evidenceReference.expectedVersion",
  );
  if (expectedVersion == null) {
    invalid("evidenceReference.expectedVersion", "is required");
  }
  return {
    sourceType,
    sourceId: documentId(map.sourceId, "evidenceReference.sourceId"),
    expectedVersion,
  };
}

export function parseAssetRegistryMutationRequest(raw: JsonMap): RegistryRequest {
  const allowed = new Set([
    "requestId", "operation", "assetClassId", "assetInstanceId",
    "componentInstanceId", "replacementComponentInstanceId", "expectedVersion",
    "expectedAssetClassVersion",
    "expectedAssetInstanceVersion", "status", "reason", "allowTagTransfer",
    "expectedTagOwnerComponentId", "evidenceReference", "assetDraft", "componentDraft",
  ]);
  for (const key of Object.keys(raw)) if (!allowed.has(key)) invalid(key, "is unsupported");
  const operation = requiredString(raw.operation, "operation", 40) as RegistryOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  const componentOperation = operation.includes("COMPONENT_INSTANCE");
  const create = operation.startsWith("CREATE_");
  const request: Omit<RegistryRequest, "fingerprint"> = {
    requestId: uuid(raw.requestId, "requestId"),
    operation,
    assetClassId: documentId(raw.assetClassId, "assetClassId"),
    assetInstanceId: documentId(raw.assetInstanceId, "assetInstanceId"),
    componentInstanceId: raw.componentInstanceId == null ? null :
      documentId(raw.componentInstanceId, "componentInstanceId"),
    replacementComponentInstanceId: raw.replacementComponentInstanceId == null ? null :
      documentId(raw.replacementComponentInstanceId, "replacementComponentInstanceId"),
    expectedVersion: optionalVersion(raw.expectedVersion, "expectedVersion"),
    expectedAssetClassVersion: optionalVersion(
      raw.expectedAssetClassVersion, "expectedAssetClassVersion",
    ),
    expectedAssetInstanceVersion: optionalVersion(
      raw.expectedAssetInstanceVersion, "expectedAssetInstanceVersion",
    ),
    status: raw.status == null ? null : requiredString(raw.status, "status", 16) as "active" | "retired",
    reason: requiredString(raw.reason, "reason", 500),
    allowTagTransfer: raw.allowTagTransfer === true,
    expectedTagOwnerComponentId: raw.expectedTagOwnerComponentId == null ? null :
      documentId(raw.expectedTagOwnerComponentId, "expectedTagOwnerComponentId"),
    evidenceReference: parseReplacementEvidenceReference(raw.evidenceReference),
    assetDraft: raw.assetDraft == null ? null : parseAssetDraft(raw.assetDraft),
    componentDraft: raw.componentDraft == null ? null : parseComponentDraft(raw.componentDraft),
  };
  if (request.reason.length < 8) invalid("reason", "must contain at least 8 characters");
  if (raw.allowTagTransfer != null && typeof raw.allowTagTransfer !== "boolean") {
    invalid("allowTagTransfer", "must be a boolean");
  }
  if (request.allowTagTransfer !== (request.expectedTagOwnerComponentId != null)) {
    invalid(
      "expectedTagOwnerComponentId",
      "must name the reviewed current owner exactly when tag transfer is approved",
    );
  }
  if (!componentOperation && request.expectedTagOwnerComponentId != null) {
    invalid("expectedTagOwnerComponentId", "is allowed only for installed components");
  }
  if ((request.componentInstanceId != null) !== componentOperation) {
    invalid("componentInstanceId", componentOperation ? "is required" : "is not allowed");
  }
  const replacementOperation = operation === "REPLACE_COMPONENT_INSTANCE";
  if (request.evidenceReference != null && !replacementOperation) {
    invalid("evidenceReference", "is allowed only for component replacement");
  }
  if ((request.replacementComponentInstanceId != null) !== replacementOperation) {
    invalid(
      "replacementComponentInstanceId",
      replacementOperation ? "is required" : "is not allowed",
    );
  }
  if (replacementOperation &&
      request.replacementComponentInstanceId === request.componentInstanceId) {
    invalid("replacementComponentInstanceId", "must differ from componentInstanceId");
  }
  const assetDraftOperation = operation === "CREATE_ASSET_INSTANCE" ||
    operation === "UPDATE_ASSET_INSTANCE";
  const componentDraftOperation = operation === "CREATE_COMPONENT_INSTANCE" ||
    operation === "UPDATE_COMPONENT_INSTANCE" || replacementOperation;
  if ((request.assetDraft != null) !== assetDraftOperation) {
    invalid("assetDraft", assetDraftOperation ? "is required" : "is not allowed");
  }
  if ((request.componentDraft != null) !== componentDraftOperation) {
    invalid("componentDraft", componentDraftOperation ? "is required" : "is not allowed");
  }
  if (replacementOperation && request.componentDraft?.installedOn == null) {
    invalid("componentDraft.installedOn", "is required for component replacement");
  }
  const statusOperation = operation.startsWith("SET_");
  if ((request.status != null) !== statusOperation ||
      (request.status != null && !["active", "retired"].includes(request.status))) {
    invalid("status", statusOperation ? "is required and must be active or retired" : "is not allowed");
  }
  if (create && (!UUID.test(request.assetInstanceId) ||
      (componentOperation && !UUID.test(request.componentInstanceId!)))) {
    invalid("identity", "must be a canonical UUID for creation");
  }
  if (replacementOperation && !UUID.test(request.replacementComponentInstanceId!)) {
    invalid("replacementComponentInstanceId", "must be a canonical UUID");
  }
  const {
    replacementComponentInstanceId,
    evidenceReference,
    ...legacyRequest
  } = request;
  const replacementLegacyRequest = {
    ...legacyRequest,
    replacementComponentInstanceId,
  };
  const fingerprintPayload = replacementOperation ?
    (evidenceReference == null ? replacementLegacyRequest : request) : legacyRequest;
  const fingerprintVersion = replacementOperation ?
    (evidenceReference == null ? "assetreg2" : "assetreg3") : "assetreg1";
  const fingerprint = `${fingerprintVersion}-sha256:${createHash("sha256")
    .update(stableJson(fingerprintPayload), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

function asSnapshot(value: SnapshotLike | QuerySnapshotLike, label: string): SnapshotLike {
  if ("docs" in value) throw new AssetHierarchyMutationError("internal", `${label} returned a query.`);
  return value;
}

function asQuery(value: SnapshotLike | QuerySnapshotLike, label: string): QuerySnapshotLike {
  if (!("docs" in value)) throw new AssetHierarchyMutationError("internal", `${label} returned a document.`);
  return value;
}

function record(snapshot: SnapshotLike, label: string): JsonMap {
  if (!snapshot.exists || snapshot.data() == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return snapshot.data()!;
}

function version(data: JsonMap, expected: number | null, label: string): number {
  if (!Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", `${label} has a malformed version.`,
      {reasonCode: "asset-registry-version-malformed"},
    );
  }
  if (expected == null || data.version !== expected) {
    throw new AssetHierarchyMutationError(
      "aborted", `${label} changed before this command was committed.`,
      {reasonCode: "asset-registry-version-mismatch", currentVersion: data.version},
    );
  }
  return data.version as number;
}

function snapshotJson(data: JsonMap): JsonMap {
  const copy = {...data};
  delete copy.createdAt;
  delete copy.updatedAt;
  return copy;
}

function tagClaimId(tag: string): string {
  return createHash("sha256").update(tag, "utf8").digest("hex");
}

function currentTag(data: JsonMap | null): string | null {
  return typeof data?.normalizedComponentTag === "string" &&
    data.normalizedComponentTag.length > 0 ? data.normalizedComponentTag : null;
}

function resultEntityId(request: RegistryRequest): string {
  return request.replacementComponentInstanceId ??
    request.componentInstanceId ?? request.assetInstanceId;
}

function componentLineageId(data: JsonMap | null, fallbackId: string): string {
  const value = data?.componentLineageId;
  if (value == null) return fallbackId;
  if (typeof value !== "string" || value.length === 0 || value.includes("/")) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", "The installed component has malformed lifecycle lineage.",
      {reasonCode: "asset-component-lineage-malformed"},
    );
  }
  return value;
}

function timestampOrNull(date: Date | null, convert: (date: Date) => unknown): unknown {
  return date == null ? null : convert(date);
}

function timestampIso(value: unknown, field: string): string {
  let date: unknown = value;
  if (typeof value === "string") {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)?$/.exec(value);
    const parts = match?.slice(1, 7).map(Number) ?? [];
    const calendar = parts.length === 6 ? new Date(Date.UTC(
      parts[0], parts[1] - 1, parts[2], parts[3], parts[4], parts[5],
    )) : null;
    const candidate = match == null ? null : new Date(value);
    date = candidate != null && calendar != null &&
      !Number.isNaN(candidate.getTime()) &&
      calendar.getUTCFullYear() === parts[0] &&
      calendar.getUTCMonth() === parts[1] - 1 &&
      calendar.getUTCDate() === parts[2] &&
      calendar.getUTCHours() === parts[3] &&
      calendar.getUTCMinutes() === parts[4] &&
      calendar.getUTCSeconds() === parts[5] ? candidate : null;
  } else if (value != null && typeof value === "object" &&
      typeof (value as {toDate?: unknown}).toDate === "function") {
    try {
      date = (value as {toDate: () => unknown}).toDate();
    } catch {
      date = null;
    }
  }
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", `Replacement evidence has malformed ${field}.`,
      {reasonCode: "asset-component-replacement-evidence-malformed", field},
    );
  }
  return date.toISOString();
}

function parsedJsonObject(value: unknown, field: string): JsonMap {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", `Replacement evidence has no ${field}.`,
      {reasonCode: "asset-component-replacement-evidence-unbound", field},
    );
  }
  try {
    const parsed: unknown = JSON.parse(value);
    if (parsed != null && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as JsonMap;
    }
  } catch {
    // The stable failure below is intentionally shared with non-object JSON.
  }
  throw new AssetHierarchyMutationError(
    "failed-precondition", `Replacement evidence has malformed ${field}.`,
    {reasonCode: "asset-component-replacement-evidence-malformed", field},
  );
}

function requireReplacementEvidenceIdentity(args: {
  reference: JsonMap;
  asset: JsonMap;
  outgoingComponentInstanceId: string;
  sourceId: string;
}): string | null {
  const {reference, asset, outgoingComponentInstanceId, sourceId} = args;
  if ((reference.schemaVersion !== 2 && reference.schemaVersion !== 3) ||
      !["physicalAsset", "installedComponent"].includes(reference.scope as string) ||
      reference.assetClassId !== asset.assetClassId ||
      reference.assetInstanceId !== asset.assetInstanceId ||
      reference.assetNumber !== asset.assetNumber) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Replacement evidence ${sourceId} belongs to a different or malformed asset identity.`,
      {
        reasonCode: "asset-component-replacement-evidence-asset-mismatch",
        sourceId,
      },
    );
  }
  if (reference.scope === "installedComponent" &&
      reference.componentInstanceId !== outgoingComponentInstanceId) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Replacement evidence ${sourceId} identifies a different installed component.`,
      {
        reasonCode: "asset-component-replacement-evidence-component-mismatch",
        sourceId,
      },
    );
  }
  return reference.scope === "installedComponent" ?
    outgoingComponentInstanceId : null;
}

function verifyReplacementEvidence(args: {
  data: JsonMap;
  reference: ReplacementEvidenceReference;
  asset: JsonMap;
  outgoingComponentInstanceId: string;
}): JsonMap {
  const {data, reference, asset, outgoingComponentInstanceId} = args;
  if (!Number.isSafeInteger(data.version) || data.version !== reference.expectedVersion) {
    throw new AssetHierarchyMutationError(
      "aborted", "The selected replacement evidence changed before commit.",
      {
        reasonCode: "asset-component-replacement-evidence-version-mismatch",
        sourceType: reference.sourceType,
        sourceId: reference.sourceId,
        currentVersion: data.version,
      },
    );
  }
  if (data.isDeleted !== false) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", "Deleted or malformed work cannot justify replacement.",
      {
        reasonCode: "asset-component-replacement-evidence-lifecycle-invalid",
        sourceType: reference.sourceType,
        sourceId: reference.sourceId,
      },
    );
  }

  let hierarchyReference: JsonMap | null = null;
  let completedAtIso: string;
  let completedByUid: unknown;
  let completedByName: unknown;
  let summary: unknown;
  if (reference.sourceType === "maintenanceIssue") {
    if (data.isResolved !== true || data.status !== "resolved") {
      throw new AssetHierarchyMutationError(
        "failed-precondition", "Only a resolved issue can justify component replacement.",
        {
          reasonCode: "asset-component-replacement-evidence-lifecycle-invalid",
          sourceType: reference.sourceType,
          sourceId: reference.sourceId,
        },
      );
    }
    completedAtIso = timestampIso(data.endDate, "issue endDate");
    completedByUid = data.closedByUid;
    completedByName = data.closedByName;
    summary = data.description;
    hierarchyReference = parsedJsonObject(
      data.assetHierarchyRefJson, "issue assetHierarchyRefJson",
    );
  } else {
    const cancellationStateValid = data.isCancelled === undefined ||
      data.isCancelled === false;
    if (data.isCompleted !== true || !cancellationStateValid) {
      throw new AssetHierarchyMutationError(
        "failed-precondition", "Only a completed, non-cancelled planned job can justify replacement.",
        {
          reasonCode: "asset-component-replacement-evidence-lifecycle-invalid",
          sourceType: reference.sourceType,
          sourceId: reference.sourceId,
        },
      );
    }
    completedAtIso = timestampIso(data.completedAt, "job completedAt");
    completedByUid = data.completedByUid;
    completedByName = data.completedByName;
    summary = data.templateName;
    const metadata = parsedJsonObject(data.metadataJson, "job metadataJson");
    const identity = metadata.assignmentAssetIdentity;
    if (identity == null || typeof identity !== "object" || Array.isArray(identity) ||
        (identity as JsonMap).assetClassId !== asset.assetClassId ||
        (identity as JsonMap).assetInstanceId !== asset.assetInstanceId ||
        (identity as JsonMap).assetNumber !== asset.assetNumber) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        `Replacement evidence ${reference.sourceId} belongs to a different or malformed asset identity.`,
        {
          reasonCode: "asset-component-replacement-evidence-asset-mismatch",
          sourceId: reference.sourceId,
        },
      );
    }
    const jobSnapshot = metadata.jobTemplateSnapshot;
    if (jobSnapshot != null && typeof jobSnapshot === "object" && !Array.isArray(jobSnapshot)) {
      const encoded = (jobSnapshot as JsonMap).assetHierarchyRefJson;
      if (encoded != null) {
        const candidate = parsedJsonObject(encoded, "job assetHierarchyRefJson");
        if (candidate.scope === "physicalAsset" || candidate.scope === "installedComponent") {
          hierarchyReference = candidate;
        }
      }
    }
  }

  if (typeof completedByUid !== "string" || completedByUid.trim().length === 0 ||
      typeof completedByName !== "string" || completedByName.trim().length === 0 ||
      typeof summary !== "string" || summary.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", "Replacement evidence has incomplete closure attribution.",
      {
        reasonCode: "asset-component-replacement-evidence-malformed",
        sourceType: reference.sourceType,
        sourceId: reference.sourceId,
      },
    );
  }
  const componentInstanceId = hierarchyReference == null ? null :
    requireReplacementEvidenceIdentity({
      reference: hierarchyReference,
      asset,
      outgoingComponentInstanceId,
      sourceId: reference.sourceId,
    });
  return {
    sourceType: reference.sourceType,
    sourceId: reference.sourceId,
    sourceVersion: reference.expectedVersion,
    assetClassId: asset.assetClassId,
    assetInstanceId: asset.assetInstanceId,
    assetNumber: asset.assetNumber,
    componentInstanceId,
    summary: summary.trim(),
    completedAtIso,
    completedByUid: completedByUid.trim(),
    completedByName: completedByName.trim(),
  };
}

function acceptedEvidenceSnapshotJson(
  data: JsonMap,
  request: RegistryRequest,
): string | null {
  const evidence = request.evidenceReference;
  if (evidence == null) return null;
  const encoded = data.acceptedEvidenceSnapshotJson;
  let snapshot: unknown;
  try {
    snapshot = typeof encoded === "string" ? JSON.parse(encoded) : null;
  } catch {
    snapshot = null;
  }
  const map = snapshot != null && typeof snapshot === "object" &&
      !Array.isArray(snapshot) ? snapshot as JsonMap : null;
  if (data.acceptedEvidenceType !== evidence.sourceType ||
      data.acceptedEvidenceId !== evidence.sourceId ||
      data.acceptedEvidenceVersion !== evidence.expectedVersion ||
      map == null || stableJson(map) !== encoded ||
      map.sourceType !== evidence.sourceType ||
      map.sourceId !== evidence.sourceId ||
      map.sourceVersion !== evidence.expectedVersion ||
      map.assetClassId !== request.assetClassId ||
      map.assetInstanceId !== request.assetInstanceId ||
      (map.componentInstanceId != null &&
       map.componentInstanceId !== request.componentInstanceId)) {
    throw new AssetHierarchyMutationError(
      "data-loss", "The accepted replacement-evidence snapshot is malformed or mismatched.",
      {reasonCode: "asset-registry-replay-evidence-drift"},
    );
  }
  return encoded as string;
}

function replayResult(
  request: RegistryRequest,
  actorUid: string,
  data: JsonMap,
): AssetRegistryMutationResult {
  const entityId = resultEntityId(request);
  const sourceEntityId = request.operation === "REPLACE_COMPONENT_INSTANCE" ?
    request.componentInstanceId : null;
  acceptedEvidenceSnapshotJson(data, request);
  if (data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation || data.entityId !== entityId ||
      !Number.isSafeInteger(data.version) || typeof data.auditId !== "string" ||
      typeof data.committedAtIso !== "string" ||
      (sourceEntityId != null &&
       (data.sourceEntityId !== sourceEntityId || !Number.isSafeInteger(data.sourceVersion)))) {
    throw new AssetHierarchyMutationError(
      "data-loss", "The asset-registry receipt is malformed or mismatched.",
      {reasonCode: "asset-registry-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    assetClassId: request.assetClassId,
    nodeId: entityId,
    version: data.version as number,
    auditId: data.auditId as string,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

export async function mutateAssetRegistryWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<AssetRegistryMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError("unauthenticated", "Sign in before changing the asset registry.");
  }
  const actorUid = args.authUid.trim();
  const request = parseAssetRegistryMutationRequest(args.data);
  const db = args.db;
  const users = db.collection("users");
  const classes = db.collection("asset_classes");
  const nodes = db.collection("asset_hierarchy_nodes");
  const assets = db.collection("asset_instances");
  const operationalConditions = db.collection("asset_operational_conditions");
  const numberClaims = db.collection("asset_instance_numbers");
  const components = db.collection("asset_component_instances");
  const maintenanceIssues = db.collection("maintenance_records");
  const plannedJobs = db.collection("job_executions");
  const tagClaims = db.collection("asset_tag_claims");
  const audits = db.collection("asset_hierarchy_audits");
  const receipts = db.collection("asset_hierarchy_mutation_receipts");
  const actorRef = users.doc(actorUid);
  const classRef = classes.doc(request.assetClassId);
  const assetRef = assets.doc(request.assetInstanceId);
  const operationalConditionRef = operationalConditions.doc(request.assetInstanceId);
  const componentRef = request.componentInstanceId == null ? null :
    components.doc(request.componentInstanceId);
  const replacementComponentRef = request.replacementComponentInstanceId == null ? null :
    components.doc(request.replacementComponentInstanceId);
  const entityRef = replacementComponentRef ?? componentRef ?? assetRef;
  const receiptRef = receipts.doc(request.requestId);
  const auditId = `asset_registry_${request.requestId}`;
  const auditRef = audits.doc(auditId);
  const replacementSourceAuditRef = audits.doc(`${auditId}_replacement_source`);
  const evidenceRef = request.evidenceReference == null ? null :
    (request.evidenceReference.sourceType === "maintenanceIssue" ?
      maintenanceIssues : plannedJobs).doc(request.evidenceReference.sourceId);

  const preflight = record(await actorRef.get(), "Registry actor");
  const preflightAuthority = canonicalApprovedUserAuthority(preflight);
  if (preflightAuthority == null || !preflightAuthority.roles.has("admin")) {
    throw new AssetHierarchyMutationError(
      "permission-denied", "Only an approved Admin can change the asset registry.",
    );
  }

  return db.runTransaction(async (rawTransaction) => {
    const transaction = rawTransaction as unknown as TransactionLike;
    const receiptSnapshot = asSnapshot(
      await transaction.get(receiptRef), "Registry receipt lookup",
    );
    const actor = record(
      asSnapshot(await transaction.get(actorRef), "Registry actor lookup"),
      "Registry actor",
    );
    const authority = canonicalApprovedUserAuthority(actor);
    if (authority == null || !authority.roles.has("admin")) {
      throw new AssetHierarchyMutationError(
        "permission-denied", "Only an approved Admin can change the asset registry.",
      );
    }
    if (receiptSnapshot.exists) {
      const receiptData = receiptSnapshot.data() ?? {};
      const replay = replayResult(request, actorUid, receiptData);
      const recordedEvidenceSnapshot = acceptedEvidenceSnapshotJson(
        receiptData, request,
      );
      const currentEntity = record(
        asSnapshot(await transaction.get(entityRef), "Registry replay entity lookup"),
        "Recorded registry entity",
      );
      const audit = record(
        asSnapshot(await transaction.get(auditRef), "Registry replay audit lookup"),
        "Recorded registry audit",
      );
      if (currentEntity.version !== replay.version ||
          currentEntity.lastMutationId !== request.requestId ||
          audit.requestId !== request.requestId || audit.performedByUid !== actorUid ||
          acceptedEvidenceSnapshotJson(audit, request) !== recordedEvidenceSnapshot) {
        throw new AssetHierarchyMutationError(
          "data-loss", "The registry receipt no longer matches its evidence.",
          {reasonCode: "asset-registry-replay-evidence-drift"},
        );
      }
      if (request.operation === "REPLACE_COMPONENT_INSTANCE") {
        const source = record(
          asSnapshot(await transaction.get(componentRef!), "Registry replacement source lookup"),
          "Recorded replacement source",
        );
        const sourceAudit = record(
          asSnapshot(
            await transaction.get(replacementSourceAuditRef),
            "Registry replacement-source audit lookup",
          ),
          "Recorded replacement-source audit",
        );
        if (source.version !== receiptData.sourceVersion ||
            source.lastMutationId !== request.requestId || source.status !== "retired" ||
            source.replacedByComponentInstanceId !== request.replacementComponentInstanceId ||
            sourceAudit.requestId !== request.requestId ||
            sourceAudit.entityId !== request.componentInstanceId ||
            sourceAudit.performedByUid !== actorUid ||
            acceptedEvidenceSnapshotJson(sourceAudit, request) !== recordedEvidenceSnapshot) {
          throw new AssetHierarchyMutationError(
            "data-loss", "The replacement receipt no longer matches its source evidence.",
            {reasonCode: "asset-registry-replay-evidence-drift"},
          );
        }
      }
      return replay;
    }

    const classSnapshot = asSnapshot(
      await transaction.get(classRef), "Registry asset-class lookup",
    );
    const assetSnapshot = asSnapshot(
      await transaction.get(assetRef), "Registry asset-instance lookup",
    );
    const classData = classSnapshot.exists ? classSnapshot.data() ?? {} : null;
    const assetData = assetSnapshot.exists ? assetSnapshot.data() ?? {} : null;
    const componentSnapshot = componentRef == null ? null : asSnapshot(
      await transaction.get(componentRef), "Installed component lookup",
    );
    const componentData = componentSnapshot?.exists === true ?
      componentSnapshot.data() ?? {} : null;
    const replacementComponentSnapshot = replacementComponentRef == null ? null : asSnapshot(
      await transaction.get(replacementComponentRef), "Replacement component lookup",
    );
    const evidenceSnapshot = evidenceRef == null ? null : asSnapshot(
      await transaction.get(evidenceRef), "Replacement evidence lookup",
    );
    if (request.operation === "SET_COMPONENT_INSTANCE_STATUS" &&
        request.status === "active" &&
        componentData?.replacedByComponentInstanceId != null) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "A replaced component is a terminal historical identity and cannot be restored.",
        {reasonCode: "asset-component-replaced-terminal"},
      );
    }

    const componentDraft = request.componentDraft ?? (componentData == null ? null : {
      definitionNodeId: componentData.definitionNodeId as string,
      componentTag: componentData.componentTag as string | null,
      normalizedComponentTag: currentTag(componentData),
      manufacturer: componentData.manufacturer as string | null,
      model: componentData.model as string | null,
      serialNumber: componentData.serialNumber as string | null,
      installedOn: null,
      serviceState: componentData.serviceState as ComponentDraft["serviceState"],
      ownershipStatus: componentData.ownershipStatus as ComponentDraft["ownershipStatus"],
      ownerDiscipline: componentData.ownerDiscipline as string | null,
      accountableRoleKeys: componentData.accountableRoleKeys as string[],
    });
    const definitionRef = componentDraft == null ? null :
      nodes.doc(componentDraft.definitionNodeId);
    const definitionData = definitionRef == null ? null : record(
      asSnapshot(await transaction.get(definitionRef), "Component definition lookup"),
      "Component definition",
    );

    const assetDraft = request.assetDraft;
    const numberClaimRef = assetDraft == null ? null : numberClaims.doc(
      createHash("sha256")
        .update(`${request.assetClassId}:${assetDraft.assetNumber}`, "utf8")
        .digest("hex"),
    );
    const numberClaim = numberClaimRef == null ? null : asSnapshot(
      await transaction.get(numberClaimRef), "Asset-number claim lookup",
    );

    const desiredTag = componentDraft?.normalizedComponentTag ?? null;
    const oldTag = currentTag(componentData);
    const desiredClaimRef = desiredTag == null ? null : tagClaims.doc(tagClaimId(desiredTag));
    const desiredClaim = desiredClaimRef == null ? null : asSnapshot(
      await transaction.get(desiredClaimRef), "Installed-component tag claim lookup",
    );
    if (request.expectedTagOwnerComponentId != null && desiredClaim?.exists !== true) {
      throw new AssetHierarchyMutationError(
        "aborted", "The reviewed tag owner changed before transfer.",
        {reasonCode: "asset-tag-transfer-owner-changed", normalizedTag: desiredTag},
      );
    }
    let displacedRef: DocumentRefLike | null = null;
    let displacedData: JsonMap | null = null;
    if (desiredClaim?.exists === true) {
      const claim = desiredClaim.data() ?? {};
      const ownerId = typeof claim.componentInstanceId === "string" ?
        claim.componentInstanceId : null;
      if (ownerId == null) {
        throw new AssetHierarchyMutationError(
          "already-exists", `Tag ${desiredTag} is owned by a legacy hierarchy record.`,
          {
            reasonCode: "asset-tag-collision",
            normalizedTag: desiredTag,
            existingNodeId: claim.nodeId,
            existingNodeName: claim.nodeName,
            existingAssetClassId: claim.assetClassId,
            existingAssetClassName: claim.assetClassName,
            existingPath: claim.hierarchyPath,
            existingOwnerKind: "legacy_definition",
            transferSupported: false,
          },
        );
      }
      if (componentData?.status === "active" && oldTag === desiredTag &&
          ownerId !== request.componentInstanceId) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The installed component's current tag claim is inconsistent.",
          {reasonCode: "asset-tag-claim-owner-drift", normalizedTag: desiredTag},
        );
      }
      if (ownerId !== request.componentInstanceId) {
        displacedRef = components.doc(ownerId);
        displacedData = record(
          asSnapshot(await transaction.get(displacedRef), "Previous installed tag owner lookup"),
          "Previous installed tag owner",
        );
        const displacedOwnership = parseOwnership(
          displacedData, "existingComponent",
        );
        if (currentTag(displacedData) !== desiredTag ||
            displacedData.status !== "active" ||
            claim.ownerType !== "installed_component" ||
            claim.normalizedTag !== desiredTag ||
            claim.assetInstanceId !== displacedData.assetInstanceId ||
            claim.assetClassId !== displacedData.assetClassId) {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "The tag claim and existing installed component disagree.",
            {reasonCode: "asset-tag-claim-owner-drift", normalizedTag: desiredTag},
          );
        }
        if (!request.allowTagTransfer) {
          throw new AssetHierarchyMutationError(
            "already-exists", `Tag ${desiredTag} already has an installed owner.`,
            {
              reasonCode: "asset-tag-collision",
              normalizedTag: desiredTag,
              existingNodeId: displacedData.definitionNodeId,
              existingNodeName: displacedData.definitionName,
              existingAssetClassId: displacedData.assetClassId,
              existingAssetClassName: displacedData.assetClassName,
              existingPath: displacedData.hierarchyPath,
              existingAssetInstanceId: displacedData.assetInstanceId,
              existingAssetInstanceName: displacedData.assetInstanceName,
              existingComponentInstanceId: ownerId,
              existingOwnerKind: "installed_component",
              existingOwnershipStatus: displacedOwnership.ownershipStatus,
              existingOwnerDiscipline: displacedOwnership.ownerDiscipline,
              existingAccountableRoleKeys: displacedOwnership.accountableRoleKeys,
              transferSupported: true,
            },
          );
        }
        if (request.expectedTagOwnerComponentId !== ownerId) {
          throw new AssetHierarchyMutationError(
            "aborted", "The reviewed tag owner changed before transfer.",
            {
              reasonCode: "asset-tag-transfer-owner-changed",
              normalizedTag: desiredTag,
              reviewedComponentInstanceId: request.expectedTagOwnerComponentId,
              currentComponentInstanceId: ownerId,
            },
          );
        }
      } else if (request.expectedTagOwnerComponentId != null) {
        throw new AssetHierarchyMutationError(
          "aborted", "The reviewed tag owner changed before transfer.",
          {
            reasonCode: "asset-tag-transfer-owner-changed",
            normalizedTag: desiredTag,
            reviewedComponentInstanceId: request.expectedTagOwnerComponentId,
            currentComponentInstanceId: ownerId,
          },
        );
      }
    }
    const oldClaimRef = oldTag == null ? null : tagClaims.doc(tagClaimId(oldTag));
    const oldClaim = oldClaimRef != null && oldTag !== desiredTag ? asSnapshot(
      await transaction.get(oldClaimRef), "Previous installed tag claim lookup",
    ) : null;
    if (oldClaim != null &&
        (!oldClaim.exists || oldClaim.data()?.componentInstanceId !== request.componentInstanceId)) {
      throw new AssetHierarchyMutationError(
        "failed-precondition", "The installed component's prior tag claim is inconsistent.",
        {reasonCode: "asset-tag-claim-missing", normalizedTag: oldTag},
      );
    }

    const activeComponents = request.operation === "SET_ASSET_INSTANCE_STATUS" &&
      request.status === "retired" ? asQuery(
        await transaction.get(
          components.where("assetInstanceId", "==", request.assetInstanceId)
            .where("status", "==", "active").limit(1),
        ),
        "Active installed-component lookup",
      ) : null;
    const operationalCondition = request.operation === "SET_ASSET_INSTANCE_STATUS" &&
      request.status === "retired" ? asSnapshot(
        await transaction.get(operationalConditionRef),
        "Asset operational-condition lookup",
      ) : null;

    const acceptedEvidenceSnapshot = request.evidenceReference == null ? null :
      verifyReplacementEvidence({
        data: record(evidenceSnapshot!, "Replacement work evidence"),
        reference: request.evidenceReference,
        asset: assetData ?? record(assetSnapshot, "Replacement asset"),
        outgoingComponentInstanceId: request.componentInstanceId!,
      });
    const acceptedEvidenceFields = acceptedEvidenceSnapshot == null ? {} : {
      acceptedEvidenceType: request.evidenceReference!.sourceType,
      acceptedEvidenceId: request.evidenceReference!.sourceId,
      acceptedEvidenceVersion: request.evidenceReference!.expectedVersion,
      acceptedEvidenceSnapshotJson: stableJson(acceptedEvidenceSnapshot),
    };

    const nowDate = args.now?.() ?? new Date();
    const committedAtIso = nowDate.toISOString();
    const toTimestamp = args.timestampFromDate ?? ((date: Date) => date);
    const committedAt = toTimestamp(nowDate);
    const actorName = typeof actor.name === "string" && actor.name.trim().length > 0 ?
      actor.name.trim() : actorUid;
    let before: JsonMap | null = null;
    let after: JsonMap | null = null;
    let nextVersion: number;
    let sourceVersion: number | null = null;
    let action: string;
    let entityType: string;
    let wasActive = false;
    let willBeActive = false;

    if (request.operation.includes("ASSET_INSTANCE") &&
        !request.operation.includes("COMPONENT_INSTANCE")) {
      if (classData == null || classData.status !== "active") {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The owning asset class must be active.",
        );
      }
      entityType = "asset_instance";
      if (request.operation === "CREATE_ASSET_INSTANCE") {
        const createDraft = request.assetDraft!;
        if (assetData != null) throw new AssetHierarchyMutationError("already-exists", "Asset instance already exists.");
        version(classData, request.expectedAssetClassVersion, "Asset class");
        if (numberClaim?.exists === true) {
          throw new AssetHierarchyMutationError(
            "already-exists", `Asset number ${createDraft.assetNumber} already exists in this class.`,
            {reasonCode: "asset-instance-number-collision", assetNumber: createDraft.assetNumber},
          );
        }
        nextVersion = 1;
        action = "create";
        after = {
          schemaVersion: 1,
          assetInstanceId: request.assetInstanceId,
          assetClassId: request.assetClassId,
          assetClassCode: classData.code,
          assetClassName: classData.name,
          ...createDraft,
          commissionedOn: timestampOrNull(createDraft.commissionedOn, toTimestamp),
          status: "active",
          activeComponentCount: 0,
          version: nextVersion,
          createdAt: committedAt,
          createdByUid: actorUid,
          createdByName: actorName,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        transaction.set(assetRef, after);
        transaction.set(numberClaimRef!, {
          schemaVersion: 1,
          assetClassId: request.assetClassId,
          assetNumber: createDraft.assetNumber,
          assetInstanceId: request.assetInstanceId,
          createdAt: committedAt,
        });
      } else {
        const current = assetData ?? record(assetSnapshot, "Asset instance");
        const currentVersion = version(current, request.expectedVersion, "Asset instance");
        before = snapshotJson(current);
        const currentAssetNumber = current.assetNumber;
        const currentNumberClaimRef = Number.isSafeInteger(currentAssetNumber) ?
          numberClaims.doc(
            createHash("sha256")
              .update(`${request.assetClassId}:${currentAssetNumber}`, "utf8")
              .digest("hex"),
          ) : null;
        const currentNumberClaim = currentNumberClaimRef == null ? null : asSnapshot(
          await transaction.get(currentNumberClaimRef),
          "Current asset-number claim lookup",
        );
        if (currentNumberClaim == null || !currentNumberClaim.exists ||
            currentNumberClaim.data()?.assetInstanceId !== request.assetInstanceId) {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "The asset-number claim is inconsistent.",
            {reasonCode: "asset-instance-number-claim-drift"},
          );
        }
        if (activeComponents != null && activeComponents.docs.length > 0) {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "Retire installed components before retiring this asset.",
            {reasonCode: "asset-instance-active-components"},
          );
        }
        if (operationalCondition?.exists === true &&
            activeAssetOperationalConditionForRegistry(
              operationalCondition.data() ?? {},
              {
                assetInstanceId: request.assetInstanceId,
                assetClassId: request.assetClassId,
              },
            )) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Restore the active operational condition before retiring this asset.",
            {reasonCode: "asset-instance-active-operational-condition"},
          );
        }
        const draft = request.assetDraft ?? {
          assetNumber: current.assetNumber as number,
          name: current.name as string,
          plantTag: current.plantTag as string | null,
          location: current.location as string | null,
          manufacturer: current.manufacturer as string | null,
          model: current.model as string | null,
          serialNumber: current.serialNumber as string | null,
          commissionedOn: null,
          serviceState: current.serviceState as AssetDraft["serviceState"],
          ownershipStatus: current.ownershipStatus as AssetDraft["ownershipStatus"],
          ownerDiscipline: current.ownerDiscipline as string | null,
          accountableRoleKeys: current.accountableRoleKeys as string[],
        };
        if (draft.assetNumber !== current.assetNumber) {
          throw new AssetHierarchyMutationError("failed-precondition", "Asset number is immutable.");
        }
        nextVersion = currentVersion + 1;
        action = request.operation === "UPDATE_ASSET_INSTANCE" ? "update" : request.status!;
        after = {
          ...current,
          ...draft,
          commissionedOn: request.assetDraft == null ? current.commissionedOn :
            timestampOrNull(draft.commissionedOn, toTimestamp),
          status: request.operation === "SET_ASSET_INSTANCE_STATUS" ? request.status : current.status,
          version: nextVersion,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        transaction.set(assetRef, after);
      }
    } else {
      if (classData == null || classData.status !== "active" ||
          assetData == null || assetData.status !== "active") {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The asset class and physical asset must both be active.",
        );
      }
      if (assetData.assetClassId !== request.assetClassId ||
          definitionData?.assetClassId !== request.assetClassId ||
          definitionData?.status !== "active") {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The component definition must be active in the asset's class.",
        );
      }
      if (componentData != null &&
          (componentData.assetInstanceId !== request.assetInstanceId ||
           componentData.assetClassId !== request.assetClassId)) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The installed component does not belong to the selected asset.",
          {reasonCode: "asset-component-owner-mismatch"},
        );
      }
      entityType = "installed_component";
      const lineageId = componentLineageId(componentData, request.componentInstanceId!);
      if (request.operation === "REPLACE_COMPONENT_INSTANCE") {
        if (replacementComponentSnapshot?.exists === true) {
          throw new AssetHierarchyMutationError(
            "already-exists", "The replacement component identity already exists.",
          );
        }
        if (componentData == null || componentData.status !== "active") {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "Only an active installed component can be replaced.",
          );
        }
        if (componentDraft!.definitionNodeId !== componentData.definitionNodeId) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "A replacement must use the same governed component definition.",
            {reasonCode: "asset-component-replacement-definition-mismatch"},
          );
        }
        const currentComponentVersion = version(
          componentData, request.expectedVersion, "Installed component",
        );
        const currentAssetVersion = version(
          assetData, request.expectedAssetInstanceVersion, "Asset instance",
        );
        const activeCount = assetData.activeComponentCount;
        if (!Number.isSafeInteger(activeCount) || (activeCount as number) < 1) {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "The asset's installed-component count is invalid.",
            {reasonCode: "asset-component-count-invalid"},
          );
        }
        sourceVersion = currentComponentVersion + 1;
        const sourceAfter = {
          ...componentData,
          componentLineageId: lineageId,
          status: "retired",
          replacedByComponentInstanceId: request.replacementComponentInstanceId,
          version: sourceVersion,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        nextVersion = 1;
        action = "replacement_installed";
        after = {
          schemaVersion: 1,
          componentInstanceId: request.replacementComponentInstanceId,
          componentLineageId: lineageId,
          replacesComponentInstanceId: request.componentInstanceId,
          assetInstanceId: request.assetInstanceId,
          assetInstanceVersionAtMutation: currentAssetVersion,
          assetNumber: assetData.assetNumber,
          assetInstanceName: assetData.name,
          assetClassId: request.assetClassId,
          assetClassCode: classData.code,
          assetClassName: classData.name,
          ...componentDraft!,
          definitionNodeVersion: definitionData!.version,
          definitionName: definitionData.name,
          hierarchyPath: definitionData.hierarchyPath,
          installedOn: timestampOrNull(componentDraft!.installedOn, toTimestamp),
          status: "active",
          version: nextVersion,
          createdAt: committedAt,
          createdByUid: actorUid,
          createdByName: actorName,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        wasActive = true;
        willBeActive = true;
        transaction.set(componentRef!, sourceAfter);
        transaction.set(replacementComponentRef!, after);
        transaction.set(assetRef, {
          ...assetData,
          activeComponentCount: activeCount,
          version: currentAssetVersion + 1,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        });
        transaction.set(replacementSourceAuditRef, {
          schemaVersion: 1,
          auditId: `${auditId}_replacement_source`,
          entityType: "installed_component",
          entityId: request.componentInstanceId,
          componentLineageId: lineageId,
          relatedEntityId: request.replacementComponentInstanceId,
          assetClassId: request.assetClassId,
          assetInstanceId: request.assetInstanceId,
          action: "replaced",
          reason: request.reason,
          beforeJson: JSON.stringify(snapshotJson(componentData)),
          afterJson: JSON.stringify(snapshotJson(sourceAfter)),
          performedByUid: actorUid,
          performedByName: actorName,
          performedAt: committedAt,
          requestId: request.requestId,
          ...acceptedEvidenceFields,
        });
      } else if (request.operation === "CREATE_COMPONENT_INSTANCE") {
        if (componentData != null) throw new AssetHierarchyMutationError("already-exists", "Installed component already exists.");
        version(assetData, request.expectedAssetInstanceVersion, "Asset instance");
        nextVersion = 1;
        action = "create";
      } else {
        if (componentData == null) throw new AssetHierarchyMutationError("not-found", "Installed component was not found.");
        if (request.operation === "UPDATE_COMPONENT_INSTANCE" && componentData.status !== "active") {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "Restore this installed component before editing it.",
          );
        }
        nextVersion = version(componentData, request.expectedVersion, "Installed component") + 1;
        action = request.operation === "UPDATE_COMPONENT_INSTANCE" ? "update" : request.status!;
        before = snapshotJson(componentData);
      }
      if (request.operation !== "REPLACE_COMPONENT_INSTANCE") {
        const resultingStatus = request.operation === "SET_COMPONENT_INSTANCE_STATUS" ?
          request.status! : (componentData?.status as string | undefined) ?? "active";
        after = {
          ...(componentData ?? {}),
          schemaVersion: 1,
          componentInstanceId: request.componentInstanceId,
          componentLineageId: lineageId,
          assetInstanceId: request.assetInstanceId,
          assetInstanceVersionAtMutation: assetData.version,
          assetNumber: assetData.assetNumber,
          assetInstanceName: assetData.name,
          assetClassId: request.assetClassId,
          assetClassCode: classData.code,
          assetClassName: classData.name,
          ...componentDraft!,
          definitionNodeVersion: definitionData!.version,
          definitionName: definitionData.name,
          hierarchyPath: definitionData.hierarchyPath,
          installedOn: request.componentDraft == null ? componentData?.installedOn ?? null :
            timestampOrNull(componentDraft!.installedOn, toTimestamp),
          status: resultingStatus,
          version: nextVersion,
          createdAt: componentData?.createdAt ?? committedAt,
          createdByUid: componentData?.createdByUid ?? actorUid,
          createdByName: componentData?.createdByName ?? actorName,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        transaction.set(componentRef!, after);
        wasActive = componentData?.status === "active";
        willBeActive = resultingStatus === "active";
      }
      if (wasActive && desiredTag != null && oldTag === desiredTag &&
          desiredClaim?.exists !== true) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The installed component's current tag claim is missing.",
          {reasonCode: "asset-tag-claim-missing", normalizedTag: desiredTag},
        );
      }
      if (wasActive && desiredClaim?.exists === true &&
          desiredClaim.data()?.componentInstanceId === request.componentInstanceId &&
          (desiredClaim.data()?.ownerType !== "installed_component" ||
           desiredClaim.data()?.normalizedTag !== desiredTag ||
           desiredClaim.data()?.assetInstanceId !== request.assetInstanceId ||
           desiredClaim.data()?.assetClassId !== request.assetClassId)) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The installed component's current tag claim is inconsistent.",
          {reasonCode: "asset-tag-claim-owner-drift", normalizedTag: desiredTag},
        );
      }
      if (wasActive !== willBeActive) {
        const count = assetData.activeComponentCount;
        if (!Number.isSafeInteger(count) || (count as number) < 0 ||
            (wasActive && (count as number) === 0)) {
          throw new AssetHierarchyMutationError(
            "failed-precondition", "The asset's installed-component count is invalid.",
            {reasonCode: "asset-component-count-invalid"},
          );
        }
        transaction.set(assetRef, {
          ...assetData,
          activeComponentCount: (count as number) + (willBeActive ? 1 : -1),
          version: (assetData.version as number) + 1,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        });
      }
      if (oldClaimRef != null && (oldTag !== desiredTag || !willBeActive)) {
        transaction.delete(oldClaimRef);
      }
      if (displacedRef != null && displacedData != null) {
        const displacedVersion = version(
          displacedData,
          displacedData.version as number,
          "Previous installed tag owner",
        );
        const displacedAfter = {
          ...displacedData,
          componentTag: null,
          normalizedComponentTag: null,
          version: displacedVersion + 1,
          updatedAt: committedAt,
          updatedByUid: actorUid,
          updatedByName: actorName,
          lastMutationId: request.requestId,
        };
        transaction.set(displacedRef, displacedAfter);
        transaction.set(audits.doc(`${auditId}_tag_source`), {
          schemaVersion: 1,
          auditId: `${auditId}_tag_source`,
          entityType: "installed_component",
          entityId: displacedData.componentInstanceId,
          componentLineageId: componentLineageId(
            displacedData,
            displacedData.componentInstanceId as string,
          ),
          relatedEntityId: resultEntityId(request),
          assetClassId: displacedData.assetClassId,
          assetInstanceId: displacedData.assetInstanceId,
          action: "tag_transferred_out",
          reason: request.reason,
          beforeJson: JSON.stringify(snapshotJson(displacedData)),
          afterJson: JSON.stringify(snapshotJson(displacedAfter)),
          performedByUid: actorUid,
          performedByName: actorName,
          performedAt: committedAt,
          requestId: request.requestId,
        });
      }
      if (desiredClaimRef != null && willBeActive) {
        transaction.set(desiredClaimRef, {
          schemaVersion: 2,
          ownerType: "installed_component",
          normalizedTag: desiredTag,
          displayTag: componentDraft!.componentTag,
          componentInstanceId: resultEntityId(request),
          definitionNodeId: componentDraft!.definitionNodeId,
          definitionName: definitionData.name,
          assetInstanceId: request.assetInstanceId,
          assetInstanceName: assetData.name,
          assetNumber: assetData.assetNumber,
          assetClassId: request.assetClassId,
          assetClassName: classData.name,
          hierarchyPath: definitionData.hierarchyPath,
          ownershipStatus: componentDraft!.ownershipStatus,
          ownerDiscipline: componentDraft!.ownerDiscipline,
          accountableRoleKeys: componentDraft!.accountableRoleKeys,
          claimedAt: committedAt,
          claimedByUid: actorUid,
          lastMutationId: request.requestId,
        });
      }
    }

    if (after == null) {
      throw new AssetHierarchyMutationError(
        "internal", "The asset-registry mutation did not produce an after-state.",
      );
    }
    transaction.set(auditRef, {
      schemaVersion: 1,
      auditId,
      entityType,
      entityId: resultEntityId(request),
      componentLineageId: entityType === "installed_component" ?
        componentLineageId(after, resultEntityId(request)) : null,
      relatedEntityId: request.operation === "REPLACE_COMPONENT_INSTANCE" ?
        request.componentInstanceId : null,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      action,
      reason: request.reason,
      beforeJson: before == null ? null : JSON.stringify(before),
      afterJson: JSON.stringify(snapshotJson(after)),
      performedByUid: actorUid,
      performedByName: actorName,
      performedAt: committedAt,
      requestId: request.requestId,
      tagTransferApproved: request.allowTagTransfer,
      ...acceptedEvidenceFields,
    });
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      entityId: resultEntityId(request),
      version: nextVersion,
      sourceEntityId: request.operation === "REPLACE_COMPONENT_INSTANCE" ?
        request.componentInstanceId : null,
      sourceVersion,
      auditId,
      committedAt,
      committedAtIso,
      ...acceptedEvidenceFields,
    });
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      assetClassId: request.assetClassId,
      nodeId: resultEntityId(request),
      version: nextVersion,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
