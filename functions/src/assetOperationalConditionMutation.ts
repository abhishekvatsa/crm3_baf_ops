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

export type AssetOperationalConditionOperation =
  | "DECLARE_ASSET_CONDITION"
  | "RESTORE_ASSET_CONDITION";

type ActiveCondition = "down" | "unfit";
type ConditionBasis =
  | "pendingMaintenance"
  | "spareUnavailable"
  | "innerCoverUnavailable"
  | "otherOperationalConstraint";

interface ParsedRequest {
  requestId: string;
  operation: AssetOperationalConditionOperation;
  assetClassId: string;
  assetInstanceId: string;
  expectedVersion: number;
  condition: ActiveCondition | null;
  causeKeys: ReadonlyArray<string>;
  basis: ConditionBasis | null;
  componentHierarchyRefJson: string | null;
  requestContractVersion: 1 | 2;
  reason: string;
  linkedIssueIds: ReadonlyArray<string>;
  fingerprint: string;
}

export interface AssetOperationalConditionMutationResult {
  ok: true;
  requestId: string;
  operation: AssetOperationalConditionOperation;
  assetClassId: string;
  assetInstanceId: string;
  condition: "available" | ActiveCondition;
  version: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<AssetOperationalConditionOperation>([
  "DECLARE_ASSET_CONDITION",
  "RESTORE_ASSET_CONDITION",
]);
const ACTIVE_CONDITIONS = new Set<ActiveCondition>(["down", "unfit"]);
const CONDITION_BASES = new Set<ConditionBasis>([
  "pendingMaintenance",
  "spareUnavailable",
  "innerCoverUnavailable",
  "otherOperationalConstraint",
]);
const CAUSES = new Set([
  "breakdown",
  "safety",
  "quality",
  "utilities",
  "process",
  "inspection",
  "compliance",
  "other",
]);
const DECLARE_ROLES = new Set([
  "admin", "si", "shiftSupervisor", "operations",
]);
const RESTORE_ROLES = new Set(["admin", "si", "shiftSupervisor"]);

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-asset-condition-request", field},
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

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) invalid(field, "is invalid");
  return id;
}

function stringSet(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<string> {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > maximum) {
    invalid(field, `must be a list of at most ${maximum} values`);
  }
  const output: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const cleaned = documentId(item, field);
    if (seen.has(cleaned)) invalid(field, "must not contain duplicates");
    seen.add(cleaned);
    output.push(cleaned);
  }
  return output.sort();
}

export function isAssetOperationalConditionOperation(
  value: unknown,
): value is AssetOperationalConditionOperation {
  return typeof value === "string" &&
    OPERATIONS.has(value as AssetOperationalConditionOperation);
}

export function parseAssetOperationalConditionMutationRequest(
  raw: JsonMap,
): ParsedRequest {
  const allowed = new Set([
    "requestId", "operation", "assetClassId", "assetInstanceId",
    "expectedVersion", "condition", "causeKeys", "basis",
    "componentHierarchyRefJson", "reason", "linkedIssueIds",
  ]);
  for (const key of Object.keys(raw)) if (!allowed.has(key)) invalid(key, "is unsupported");

  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  const operation = requiredString(
    raw.operation,
    "operation",
    40,
  ) as AssetOperationalConditionOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  if (!Number.isSafeInteger(raw.expectedVersion) ||
      (raw.expectedVersion as number) < 0) {
    invalid("expectedVersion", "must be a non-negative integer");
  }
  const reason = requiredString(raw.reason, "reason", 1000);
  const condition = raw.condition == null ? null :
    requiredString(raw.condition, "condition", 16) as ActiveCondition;
  const basis = raw.basis == null ? null :
    requiredString(raw.basis, "basis", 40) as ConditionBasis;
  const componentHierarchyRefJson = raw.componentHierarchyRefJson == null ? null :
    requiredString(
      raw.componentHierarchyRefJson,
      "componentHierarchyRefJson",
      12000,
    );
  const causeKeys = stringSet(raw.causeKeys, "causeKeys", 8);
  const linkedIssueIds = stringSet(raw.linkedIssueIds, "linkedIssueIds", 20);
  const hasBasis = Object.prototype.hasOwnProperty.call(raw, "basis");
  const hasComponentReference = Object.prototype.hasOwnProperty.call(
    raw,
    "componentHierarchyRefJson",
  );
  if (hasBasis !== hasComponentReference) {
    invalid(
      "basis",
      "and componentHierarchyRefJson must be supplied together",
    );
  }
  const requestContractVersion: 1 | 2 = hasBasis ? 2 : 1;

  if (operation === "DECLARE_ASSET_CONDITION") {
    if (condition == null || !ACTIVE_CONDITIONS.has(condition)) {
      invalid("condition", "must be down or unfit for a declaration");
    }
    if (causeKeys.length === 0 || causeKeys.some((cause) => !CAUSES.has(cause))) {
      invalid("causeKeys", "must contain at least one supported cause");
    }
    if (requestContractVersion === 2) {
      if (basis == null || !CONDITION_BASES.has(basis)) {
        invalid("basis", "must identify the operational availability constraint");
      }
      if (basis === "innerCoverUnavailable" ?
        componentHierarchyRefJson != null : componentHierarchyRefJson == null) {
        invalid(
          "componentHierarchyRefJson",
          "must identify a governed component unless Inner Cover availability is selected",
        );
      }
    }
  } else if (condition != null || basis != null ||
      componentHierarchyRefJson != null || causeKeys.length > 0 ||
      linkedIssueIds.length > 0) {
    invalid(
      "condition",
      "cause and linked-issue fields are not allowed when restoring an asset",
    );
  }

  const legacyRequest = {
    requestId,
    operation,
    assetClassId: documentId(raw.assetClassId, "assetClassId"),
    assetInstanceId: documentId(raw.assetInstanceId, "assetInstanceId"),
    expectedVersion: raw.expectedVersion as number,
    condition,
    causeKeys,
    reason,
    linkedIssueIds,
  };
  const fingerprintRequest = requestContractVersion === 1 ? legacyRequest : {
    ...legacyRequest,
    basis,
    componentHierarchyRefJson,
  };
  const fingerprint = `assetcondition${requestContractVersion}-sha256:${
    createHash("sha256")
      .update(stableJson(fingerprintRequest), "utf8").digest("hex")
  }`;
  return {
    ...legacyRequest,
    basis,
    componentHierarchyRefJson,
    requestContractVersion,
    fingerprint,
  };
}

export function userCanMutateAssetOperationalCondition(
  data: JsonMap,
  operation: AssetOperationalConditionOperation,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null) return false;
  const allowed = operation === "DECLARE_ASSET_CONDITION" ?
    DECLARE_ROLES : RESTORE_ROLES;
  return [...authority.roles].some((role) => allowed.has(role));
}

function asSnapshot(value: SnapshotLike | QuerySnapshotLike, label: string): SnapshotLike {
  if ("docs" in value) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a query.`);
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

function actor(
  value: SnapshotLike,
  operation: AssetOperationalConditionOperation,
): JsonMap {
  const data = record(value, "Asset-condition actor");
  if (!userCanMutateAssetOperationalCondition(data, operation)) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      operation === "DECLARE_ASSET_CONDITION" ?
        "Only approved Operations, Shift Supervisor, SI, or Admin users can declare asset condition." :
        "Only an approved Shift Supervisor, SI, or Admin can restore asset availability.",
    );
  }
  return data;
}

function actorName(data: JsonMap): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : "Approved user";
}

function isTimestampLike(value: unknown): boolean {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      return !Number.isNaN(Date.prototype.getTime.call(value));
    } catch {
      return false;
    }
  }
  if (value == null || typeof value !== "object" || Array.isArray(value) ||
      typeof (value as {toDate?: unknown}).toDate !== "function") return false;
  try {
    const date = (value as {toDate: () => unknown}).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime());
  } catch {
    return false;
  }
}

function conditionVersion(data: JsonMap | null): number {
  if (data == null) return 0;
  if (!Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The asset-condition projection has a malformed version.",
      {reasonCode: "asset-condition-version-malformed"},
    );
  }
  return data.version as number;
}

function requireStringList(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length > maximum ||
      value.some((item) => typeof item !== "string" || item.trim().length === 0) ||
      new Set(value).size !== value.length) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `The asset-condition projection has malformed ${field}.`,
      {reasonCode: "asset-condition-projection-malformed", field},
    );
  }
  return value as string[];
}

function validPersistedComponentReference(
  value: unknown,
  identity: {assetInstanceId: string; assetClassId: string},
): boolean {
  if (typeof value !== "string" || value.trim().length === 0) return false;
  try {
    const decoded = JSON.parse(value);
    if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
      return false;
    }
    const map = decoded as JsonMap;
    return Object.keys(map).length === COMPONENT_REFERENCE_KEYS.size &&
      Object.keys(map).every((key) => COMPONENT_REFERENCE_KEYS.has(key)) &&
      map.schemaVersion === 4 && map.scope === "componentDefinitionOnAsset" &&
      map.assetInstanceId === identity.assetInstanceId &&
      map.assetClassId === identity.assetClassId &&
      Number.isSafeInteger(map.assetInstanceVersion) &&
      (map.assetInstanceVersion as number) >= 1 &&
      Number.isSafeInteger(map.assetNumber) && (map.assetNumber as number) >= 1 &&
      typeof map.nodeId === "string" && map.nodeId.trim().length > 0 &&
      Number.isSafeInteger(map.nodeVersion) && (map.nodeVersion as number) >= 1 &&
      typeof map.nodeName === "string" && map.nodeName.trim().length > 0 &&
      map.componentInstanceId == null && map.componentInstanceVersion == null &&
      map.componentTag == null && map.innerCoverAssociation == null &&
      Array.isArray(map.hierarchyPath) && Array.isArray(map.accountableRoleKeys);
  } catch {
    return false;
  }
}

function validateCurrentCondition(
  data: JsonMap | null,
  identity: {assetInstanceId: string; assetClassId: string},
): number {
  const version = conditionVersion(data);
  if (data == null) return version;
  const condition = data.condition;
  const active = data.active;
  const causes = requireStringList(data.causeKeys, "causeKeys", 8);
  const linkedIssues = requireStringList(data.linkedIssueIds, "linkedIssueIds", 20);
  const declarationComplete = isTimestampLike(data.declaredAt) &&
    typeof data.declaredByUid === "string" &&
    data.declaredByUid.trim().length > 0 &&
    typeof data.declaredByName === "string" && data.declaredByName.trim().length > 0;
  const restorationValues = [
    data.restoredAt,
    data.restoredByUid,
    data.restoredByName,
  ];
  const restorationAbsent = restorationValues.every((value) => value == null);
  const restorationComplete = isTimestampLike(data.restoredAt) &&
    typeof data.restoredByUid === "string" && data.restoredByUid.trim().length > 0 &&
    typeof data.restoredByName === "string" && data.restoredByName.trim().length > 0;
  const validActive = active === true && ACTIVE_CONDITIONS.has(condition as ActiveCondition) &&
    causes.length > 0 && causes.every((cause) => CAUSES.has(cause)) &&
    restorationAbsent;
  const validRestored = active === false && condition === "available" &&
    causes.length === 0 && linkedIssues.length === 0 && restorationComplete &&
    ACTIVE_CONDITIONS.has(data.previousCondition as ActiveCondition);
  const schemaOne = data.schemaVersion === 1;
  const schemaTwo = data.schemaVersion === 2;
  const basis = data.basis;
  const componentEvidenceValid = schemaOne ||
    (schemaTwo && CONDITION_BASES.has(basis as ConditionBasis) &&
      (basis === "innerCoverUnavailable" ?
        data.componentHierarchyRefJson == null :
        validPersistedComponentReference(
          data.componentHierarchyRefJson,
          identity,
        )));
  if ((!schemaOne && !schemaTwo) || !componentEvidenceValid ||
      data.assetInstanceId !== identity.assetInstanceId ||
      data.assetClassId !== identity.assetClassId ||
      typeof data.assetClassCode !== "string" ||
      typeof data.assetClassName !== "string" ||
      !Number.isSafeInteger(data.assetNumber) || (data.assetNumber as number) < 1 ||
      typeof data.assetName !== "string" || data.assetName.trim().length === 0 ||
      (!validActive && !validRestored) || !declarationComplete ||
      typeof data.reason !== "string" || data.reason.trim().length === 0 ||
      data.reason.trim().length > 1000 ||
      !["available", "down", "unfit"].includes(data.previousCondition as string) ||
      !isTimestampLike(data.updatedAt) || typeof data.updatedByUid !== "string" ||
      data.updatedByUid.trim().length === 0 || typeof data.updatedByName !== "string" ||
      data.updatedByName.trim().length === 0 || typeof data.lastMutationId !== "string" ||
      data.lastMutationId.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The existing asset-condition projection is incomplete or malformed.",
      {reasonCode: "asset-condition-projection-malformed"},
    );
  }
  return version;
}

export function activeAssetOperationalConditionForRegistry(
  data: JsonMap | null,
  identity: {assetInstanceId: string; assetClassId: string},
): boolean {
  validateCurrentCondition(data, identity);
  return data?.active === true;
}

function conditionSnapshot(data: JsonMap | null): JsonMap | null {
  if (data == null) return null;
  return {
    condition: data.condition,
    active: data.active,
    causeKeys: data.causeKeys,
    basis: data.basis ?? null,
    componentHierarchyRefJson: data.componentHierarchyRefJson ?? null,
    reason: data.reason,
    linkedIssueIds: data.linkedIssueIds,
    version: data.version,
    declaredAt: data.declaredAt,
    declaredByUid: data.declaredByUid,
    declaredByName: data.declaredByName,
  };
}

function verifyAsset(data: JsonMap, request: ParsedRequest): void {
  if (data.schemaVersion !== 1 || data.assetInstanceId !== request.assetInstanceId ||
      data.assetClassId !== request.assetClassId ||
      typeof data.assetClassCode !== "string" ||
      typeof data.assetClassName !== "string" ||
      !Number.isSafeInteger(data.assetNumber) || (data.assetNumber as number) < 1 ||
      typeof data.name !== "string" || data.status !== "active" ||
      !["inService", "standby", "outOfService"].includes(data.serviceState as string) ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The governed asset identity is malformed, mismatched, or retired.",
      {reasonCode: "asset-condition-asset-invalid"},
    );
  }
  if (data.serviceState === "outOfService" &&
      request.operation === "DECLARE_ASSET_CONDITION") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "An administratively out-of-service asset cannot receive an operational condition declaration.",
      {reasonCode: "asset-condition-administratively-out-of-service"},
    );
  }
}

function verifyAssetClass(data: JsonMap, asset: JsonMap, request: ParsedRequest): void {
  if (data.schemaVersion !== 1 || data.assetClassId !== request.assetClassId ||
      data.status !== "active" || data.code !== asset.assetClassCode ||
      data.name !== asset.assetClassName || typeof data.legacyAssetTypeKey !== "string") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The governed asset class is malformed, changed, or retired.",
      {reasonCode: "asset-condition-asset-class-invalid"},
    );
  }
}

const COMPONENT_REFERENCE_KEYS = new Set([
  "schemaVersion", "scope", "assetClassId", "assetClassCode",
  "assetClassName", "nodeId", "nodeVersion", "nodeName",
  "assetInstanceId", "assetInstanceVersion", "assetNumber",
  "assetInstanceName", "componentInstanceId", "componentInstanceVersion",
  "componentTag", "hierarchyPath", "ownershipStatus", "ownerDiscipline",
  "accountableRoleKeys", "innerCoverAssociation",
]);

function componentReference(value: string | null): JsonMap | null {
  if (value == null) return null;
  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch {
    invalid("componentHierarchyRefJson", "must contain valid JSON");
  }
  if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
    invalid("componentHierarchyRefJson", "must contain an object");
  }
  const map = decoded as JsonMap;
  if (Object.keys(map).length !== COMPONENT_REFERENCE_KEYS.size ||
      Object.keys(map).some((key) => !COMPONENT_REFERENCE_KEYS.has(key))) {
    invalid(
      "componentHierarchyRefJson",
      "has missing or unsupported reference fields",
    );
  }
  if (map.schemaVersion !== 4 || map.scope !== "componentDefinitionOnAsset") {
    invalid(
      "componentHierarchyRefJson",
      "must be a component-on-physical-asset reference",
    );
  }
  return map;
}

function storedStringList(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length > maximum ||
      value.some((item) => typeof item !== "string" || item.trim().length === 0) ||
      new Set(value).size !== value.length) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `The governed hierarchy component has malformed ${field}.`,
      {reasonCode: "asset-condition-component-definition-malformed", field},
    );
  }
  return value as string[];
}

function canonicalComponentReference(args: {
  reference: JsonMap;
  asset: JsonMap;
  node: JsonMap;
}): string {
  const {reference, asset, node} = args;
  const hierarchyPath = storedStringList(node.hierarchyPath, "hierarchyPath", 20);
  const accountableRoleKeys = storedStringList(
    node.accountableRoleKeys,
    "accountableRoleKeys",
    10,
  );
  const ownerDiscipline = node.ownerDiscipline == null ? null : node.ownerDiscipline;
  if (node.schemaVersion !== 1 || typeof node.nodeId !== "string" ||
      node.nodeId !== reference.nodeId || node.assetClassId !== asset.assetClassId ||
      node.status !== "active" ||
      !["component", "subcomponent"].includes(node.nodeType as string) ||
      !Number.isSafeInteger(node.version) || (node.version as number) < 1 ||
      typeof node.name !== "string" || node.name.trim().length === 0 ||
      !["unassigned", "provisional", "confirmed"].includes(
        node.ownershipStatus as string,
      ) ||
      (ownerDiscipline != null &&
        (typeof ownerDiscipline !== "string" || ownerDiscipline.trim().length === 0))) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The selected governed component is malformed, changed, or retired.",
      {reasonCode: "asset-condition-component-definition-changed"},
    );
  }
  const canonical: JsonMap = {
    schemaVersion: 4,
    scope: "componentDefinitionOnAsset",
    assetClassId: asset.assetClassId,
    assetClassCode: asset.assetClassCode,
    assetClassName: asset.assetClassName,
    nodeId: node.nodeId,
    nodeVersion: node.version,
    nodeName: node.name,
    assetInstanceId: asset.assetInstanceId,
    assetInstanceVersion: asset.version,
    assetNumber: asset.assetNumber,
    assetInstanceName: asset.name,
    componentInstanceId: null,
    componentInstanceVersion: null,
    componentTag: null,
    hierarchyPath,
    ownershipStatus: node.ownershipStatus,
    ownerDiscipline,
    accountableRoleKeys,
    innerCoverAssociation: null,
  };
  if (stableJson(reference) !== stableJson(canonical)) {
    throw new AssetHierarchyMutationError(
      "aborted",
      "The selected governed component changed before the condition was recorded.",
      {reasonCode: "asset-condition-component-definition-changed"},
    );
  }
  return stableJson(canonical);
}

function verifyLinkedIssue(data: JsonMap, issueId: string, asset: JsonMap): void {
  if (typeof data.isDeleted !== "boolean" ||
      typeof data.isResolved !== "boolean") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} has malformed lifecycle state.`,
      {reasonCode: "asset-condition-linked-issue-lifecycle-malformed", issueId},
    );
  }
  if (data.isDeleted) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} is deleted.`,
      {reasonCode: "asset-condition-linked-issue-deleted", issueId},
    );
  }
  if (data.isResolved) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} is already resolved.`,
      {reasonCode: "asset-condition-linked-issue-resolved", issueId},
    );
  }
  if (typeof data.assetHierarchyRefJson !== "string") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} has no governed asset identity.`,
      {reasonCode: "asset-condition-linked-issue-unbound", issueId},
    );
  }
  let reference: unknown;
  try {
    reference = JSON.parse(data.assetHierarchyRefJson);
  } catch {
    reference = null;
  }
  const map = reference == null || typeof reference !== "object" ||
      Array.isArray(reference) ? null : reference as JsonMap;
  if (map == null ||
      (map.schemaVersion !== 2 && map.schemaVersion !== 3) ||
      map.assetInstanceId !== asset.assetInstanceId ||
      map.assetClassId !== asset.assetClassId ||
      map.assetNumber !== asset.assetNumber) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} belongs to a different or malformed asset identity.`,
      {reasonCode: "asset-condition-linked-issue-asset-mismatch", issueId},
    );
  }
  const association = map.innerCoverAssociation;
  if (association == null) return;
  const innerCover = association != null && typeof association === "object" &&
      !Array.isArray(association) ? association as JsonMap : null;
  const positionState = innerCover?.positionState;
  const linkedValues = innerCover == null ? [] : [
    innerCover.innerCoverId,
    innerCover.innerCoverSerialNumber,
    innerCover.linkageId,
    innerCover.assignmentVersion,
    innerCover.linkedAt,
  ];
  const linkedComplete = linkedValues.length === 5 &&
    linkedValues.slice(0, 3).every(
      (value) => typeof value === "string" && value.trim().length > 0,
    ) && Number.isSafeInteger(linkedValues[3]) &&
    (linkedValues[3] as number) >= 1 && validSerializedInstant(linkedValues[4]);
  const linkedAbsent = linkedValues.length === 5 &&
    linkedValues.every((value) => value == null);
  const eventAt = serializedInstant(innerCover?.eventAt);
  const confirmedAt = serializedInstant(innerCover?.confirmedAt);
  const linkedAt = serializedInstant(innerCover?.linkedAt);
  const validPosition = positionState === "linked" ? linkedComplete :
    positionState === "noneLinked" && linkedAbsent;
  if (innerCover == null || map.schemaVersion !== 3 ||
      innerCover.baseAssetInstanceId !== asset.assetInstanceId ||
      innerCover.baseAssetNumber !== asset.assetNumber || !validPosition ||
      eventAt == null || confirmedAt == null || eventAt > confirmedAt ||
      (linkedAt != null && linkedAt > confirmedAt) ||
      typeof innerCover.confirmedByUid !== "string" ||
      innerCover.confirmedByUid.trim().length === 0 ||
      typeof innerCover.confirmedByName !== "string" ||
      innerCover.confirmedByName.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Linked issue ${issueId} has malformed Inner Cover event evidence.`,
      {
        reasonCode: "asset-condition-linked-issue-inner-cover-malformed",
        issueId,
      },
    );
  }
}

function serializedInstant(value: unknown): number | null {
  if (typeof value !== "string" ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(value)) {
    return null;
  }
  const milliseconds = Date.parse(value);
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function validSerializedInstant(value: unknown): boolean {
  return serializedInstant(value) != null;
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): AssetOperationalConditionMutationResult {
  if (data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation ||
      data.assetInstanceId !== request.assetInstanceId ||
      data.assetClassId !== request.assetClassId ||
      !Number.isSafeInteger(data.version) ||
      !["available", "down", "unfit"].includes(data.condition as string) ||
      typeof data.auditId !== "string" || typeof data.committedAtIso !== "string") {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The asset-condition receipt is malformed or mismatched.",
      {reasonCode: "asset-condition-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    assetClassId: request.assetClassId,
    assetInstanceId: request.assetInstanceId,
    condition: data.condition as "available" | ActiveCondition,
    version: data.version as number,
    auditId: data.auditId as string,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

export async function mutateAssetOperationalConditionWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<AssetOperationalConditionMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before changing an asset operational condition.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseAssetOperationalConditionMutationRequest(args.data);
  const db = args.db;
  const users = db.collection("users");
  const assetClasses = db.collection("asset_classes");
  const assets = db.collection("asset_instances");
  const hierarchyNodes = db.collection("asset_hierarchy_nodes");
  const innerCoverAssignments = db.collection("base_inner_cover_assignments");
  const issues = db.collection("maintenance_records");
  const conditions = db.collection("asset_operational_conditions");
  const audits = db.collection("asset_operational_condition_audits");
  const receipts = db.collection("asset_operational_condition_receipts");
  const actorRef = users.doc(actorUid);
  const assetClassRef = request.requestContractVersion === 2 ?
    assetClasses.doc(request.assetClassId) : null;
  const assetRef = assets.doc(request.assetInstanceId);
  const requestedComponentReference = componentReference(
    request.componentHierarchyRefJson,
  );
  const componentNodeRef = requestedComponentReference == null ? null :
    hierarchyNodes.doc(documentId(
      requestedComponentReference.nodeId,
      "componentHierarchyRefJson.nodeId",
    ));
  const innerCoverAssignmentRef = request.basis === "innerCoverUnavailable" ?
    innerCoverAssignments.doc(request.assetInstanceId) : null;
  const conditionRef = conditions.doc(request.assetInstanceId);
  const auditId = `asset_condition_${request.requestId}`;
  const auditRef = audits.doc(auditId);
  const receiptRef = receipts.doc(request.requestId);
  const issueRefs = request.linkedIssueIds.map((id) => ({id, ref: issues.doc(id)}));
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  actor(await actorRef.get(), request.operation);

  return db.runTransaction(async (rawTransaction) => {
    const transaction = rawTransaction as unknown as TransactionLike;
    const receiptValue = asSnapshot(
      await transaction.get(receiptRef),
      "Asset-condition receipt lookup",
    );
    const auditValue = asSnapshot(
      await transaction.get(auditRef),
      "Asset-condition audit lookup",
    );
    const actorData = actor(
      asSnapshot(await transaction.get(actorRef), "Asset-condition actor lookup"),
      request.operation,
    );
    const conditionValue = asSnapshot(
      await transaction.get(conditionRef),
      "Asset-condition lookup",
    );
    const current = conditionValue.exists ? conditionValue.data() ?? {} : null;
    const currentVersion = validateCurrentCondition(current, request);

    if (receiptValue.exists) {
      const replay = resultFromReceipt(request, actorUid, receiptValue.data() ?? {});
      const auditData = record(
        auditValue,
        "Recorded asset-condition audit",
      );
      if (current == null || current.version !== replay.version ||
          current.lastMutationId !== request.requestId ||
          auditData.requestId !== request.requestId ||
          auditData.performedByUid !== actorUid ||
          auditData.assetInstanceId !== request.assetInstanceId) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "The asset-condition receipt no longer matches its state and audit evidence.",
          {reasonCode: "asset-condition-replay-evidence-drift"},
        );
      }
      return replay;
    }
    if (auditValue.exists) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "An asset-condition audit exists without its request receipt.",
        {reasonCode: "asset-condition-orphan-audit"},
      );
    }

    const assetData = record(
      asSnapshot(await transaction.get(assetRef), "Asset-condition asset lookup"),
      "Governed asset",
    );
    verifyAsset(assetData, request);
    const assetClassData = assetClassRef == null ? null : record(
      asSnapshot(
        await transaction.get(assetClassRef),
        "Asset-condition asset-class lookup",
      ),
      "Governed asset class",
    );
    if (assetClassData != null) verifyAssetClass(assetClassData, assetData, request);
    if (currentVersion !== request.expectedVersion) {
      throw new AssetHierarchyMutationError(
        "aborted",
        "The asset condition changed before this command was committed.",
        {
          reasonCode: "asset-condition-version-mismatch",
          currentVersion,
        },
      );
    }

    for (const issue of issueRefs) {
      const issueData = record(
        asSnapshot(
          await transaction.get(issue.ref),
          `Linked issue ${issue.id} lookup`,
        ),
        `Linked issue ${issue.id}`,
      );
      verifyLinkedIssue(issueData, issue.id, assetData);
    }

    let canonicalReferenceJson: string | null = null;
    if (componentNodeRef != null && requestedComponentReference != null) {
      const nodeData = record(
        asSnapshot(
          await transaction.get(componentNodeRef),
          "Asset-condition component lookup",
        ),
        "Governed hierarchy component",
      );
      canonicalReferenceJson = canonicalComponentReference({
        reference: requestedComponentReference,
        asset: assetData,
        node: nodeData,
      });
    }
    if (request.operation === "DECLARE_ASSET_CONDITION" &&
        request.basis === "innerCoverUnavailable") {
      if (assetClassData?.legacyAssetTypeKey !== "base") {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "Inner Cover unavailability can only be declared against a governed Base.",
          {reasonCode: "asset-condition-inner-cover-basis-not-base"},
        );
      }
      const assignment = asSnapshot(
        await transaction.get(innerCoverAssignmentRef!),
        "Base Inner Cover assignment lookup",
      );
      if (assignment.exists) {
        const assignmentData = assignment.data() ?? {};
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "Delink or retire the currently assigned Inner Cover before declaring it unavailable.",
          {
            reasonCode: "asset-condition-inner-cover-still-linked",
            innerCoverSerialNumber:
              typeof assignmentData.innerCoverSerialNumber === "string" ?
                assignmentData.innerCoverSerialNumber : null,
          },
        );
      }
    }

    if (request.operation === "RESTORE_ASSET_CONDITION" &&
        (current == null || current.active !== true ||
         !ACTIVE_CONDITIONS.has(current.condition as ActiveCondition))) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "Only an actively down or unfit asset can be restored.",
        {reasonCode: "asset-condition-not-active"},
      );
    }

    const committed = now();
    const committedAt = timestampFromDate(committed);
    const version = currentVersion + 1;
    const active = request.operation === "DECLARE_ASSET_CONDITION";
    const nextCondition = active ? request.condition! : "available";
    const nextSchemaVersion = active ?
      request.requestContractVersion : current?.schemaVersion ?? 1;
    const next: JsonMap = {
      schemaVersion: nextSchemaVersion,
      assetInstanceId: request.assetInstanceId,
      assetClassId: assetData.assetClassId,
      assetClassCode: assetData.assetClassCode,
      assetClassName: assetData.assetClassName,
      assetNumber: assetData.assetNumber,
      assetName: assetData.name,
      condition: nextCondition,
      active,
      causeKeys: active ? request.causeKeys : [],
      ...(nextSchemaVersion === 2 ? {
        basis: active ? request.basis : current?.basis,
        componentHierarchyRefJson: active ?
          canonicalReferenceJson : current?.componentHierarchyRefJson ?? null,
      } : {}),
      reason: request.reason,
      linkedIssueIds: active ? request.linkedIssueIds : [],
      declaredAt: active ? committedAt : current?.declaredAt ?? null,
      declaredByUid: active ? actorUid : current?.declaredByUid ?? null,
      declaredByName: active ? actorName(actorData) : current?.declaredByName ?? null,
      restoredAt: active ? null : committedAt,
      restoredByUid: active ? null : actorUid,
      restoredByName: active ? null : actorName(actorData),
      previousCondition: current?.condition ?? "available",
      version,
      updatedAt: committedAt,
      updatedByUid: actorUid,
      updatedByName: actorName(actorData),
      lastMutationId: request.requestId,
    };
    const audit: JsonMap = {
      schemaVersion: 1,
      auditId,
      requestId: request.requestId,
      operation: request.operation,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      before: conditionSnapshot(current),
      after: conditionSnapshot(next),
      performedAt: committedAt,
      performedByUid: actorUid,
      performedByName: actorName(actorData),
      reason: request.reason,
      linkedIssueIds: request.linkedIssueIds,
    };
    const receipt: JsonMap = {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      condition: nextCondition,
      version,
      auditId,
      committedAt,
      committedAtIso: committed.toISOString(),
    };

    transaction.set(conditionRef as unknown as DocumentRefLike, next);
    transaction.set(auditRef as unknown as DocumentRefLike, audit);
    transaction.set(receiptRef as unknown as DocumentRefLike, receipt);
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      assetClassId: request.assetClassId,
      assetInstanceId: request.assetInstanceId,
      condition: nextCondition,
      version,
      auditId,
      committedAt: committed.toISOString(),
      idempotentReplay: false,
    };
  });
}
