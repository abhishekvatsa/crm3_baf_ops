import {createHash} from "crypto";

import {
  canonicalApprovedUserAuthority,
  normalizeCanonicalUserRoles,
} from "./userAuthority";
import {stableJson} from "./stableJson";

type JsonMap = {[key: string]: unknown};

export type AssetHierarchyMutationErrorCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "already-exists"
  | "failed-precondition"
  | "aborted"
  | "data-loss"
  | "internal";

type Operation =
  | "CREATE_CLASS"
  | "UPDATE_CLASS"
  | "SET_CLASS_STATUS"
  | "CREATE_NODE"
  | "UPDATE_NODE"
  | "SET_NODE_STATUS";

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

type QueryLike = {
  where: (field: string, op: string, value: unknown) => QueryLike;
  limit: (value: number) => QueryLike;
};

type CollectionLike = {
  doc: (id?: string) => DocumentRefLike;
  where: (field: string, op: string, value: unknown) => QueryLike;
};

type TransactionLike = {
  get: (
    ref: DocumentRefLike | QueryLike,
  ) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
  delete: (ref: DocumentRefLike) => void;
};

export type AssetHierarchyMutationFirestoreLike = {
  collection: (name: string) => CollectionLike;
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

interface ClassDraft {
  code: string;
  name: string;
  majorArea: string;
  shortDescription: string | null;
  longDescription: string | null;
  legacyAssetTypeKey: "base" | "furnace" | "forceCooler" | "innerCover" | null;
}

interface NodeDraft {
  parentNodeId: string | null;
  nodeType: "grouping" | "assembly" | "component" | "subcomponent";
  name: string;
  componentTag: string | null;
  normalizedComponentTag: string | null;
  shortDescription: string | null;
  longDescription: string | null;
  discipline: string | null;
  operatingType: string | null;
  normalState: string | null;
  failState: string | null;
  contactArrangement:
    | "notStated"
    | "notApplicable"
    | "normallyOpen"
    | "normallyClosed"
    | "changeover";
  manufacturer: string | null;
  model: string | null;
  applicability: string | null;
  sourceReference: string | null;
  ownershipStatus: "unassigned" | "provisional" | "confirmed";
  ownerDiscipline: string | null;
  accountableRoleKeys: ReadonlyArray<string>;
  sortOrder: number;
}

interface ParsedRequest {
  requestId: string;
  operation: Operation;
  assetClassId: string;
  nodeId: string | null;
  expectedVersion: number | null;
  expectedAssetClassVersion: number | null;
  status: "active" | "retired" | null;
  reason: string;
  allowTagTransfer: boolean;
  classDraft: ClassDraft | null;
  nodeDraft: NodeDraft | null;
  fingerprint: string;
}

export interface AssetHierarchyMutationResult {
  ok: true;
  requestId: string;
  operation: Operation;
  assetClassId: string;
  nodeId: string | null;
  version: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CLASS_CODE = /^[A-Z0-9][A-Z0-9_-]{1,39}$/;
const OPERATIONS = new Set<Operation>([
  "CREATE_CLASS",
  "UPDATE_CLASS",
  "SET_CLASS_STATUS",
  "CREATE_NODE",
  "UPDATE_NODE",
  "SET_NODE_STATUS",
]);
const NODE_TYPES = new Set([
  "grouping", "assembly", "component", "subcomponent",
]);
const CONTACTS = new Set([
  "notStated", "notApplicable", "normallyOpen", "normallyClosed", "changeover",
]);
const OWNERSHIP = new Set(["unassigned", "provisional", "confirmed"]);

export class AssetHierarchyMutationError extends Error {
  readonly code: AssetHierarchyMutationErrorCode;
  readonly details?: unknown;

  constructor(
    code: AssetHierarchyMutationErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "AssetHierarchyMutationError";
    this.code = code;
    this.details = details;
  }
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
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is not a valid document identity");
  }
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

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-asset-hierarchy-request", field},
  );
}

export function normalizeAssetHierarchyTag(value: string): string {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");
}

function parseClassDraft(value: unknown): ClassDraft {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid("classDraft", "must be an object");
  }
  const map = value as JsonMap;
  const allowed = new Set([
    "code", "name", "majorArea", "shortDescription", "longDescription",
    "legacyAssetTypeKey",
  ]);
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`classDraft.${key}`, "is unsupported");
  }
  const code = requiredString(map.code, "classDraft.code", 40).toUpperCase();
  if (!CLASS_CODE.test(code)) invalid("classDraft.code", "has an invalid format");
  const legacyAssetTypeKey = optionalString(
    map.legacyAssetTypeKey, "classDraft.legacyAssetTypeKey", 32,
  );
  if (legacyAssetTypeKey != null && ![
    "base", "furnace", "forceCooler", "innerCover",
  ].includes(legacyAssetTypeKey)) {
    invalid("classDraft.legacyAssetTypeKey", "is not recognized");
  }
  return {
    code,
    name: requiredString(map.name, "classDraft.name", 160),
    majorArea: requiredString(map.majorArea, "classDraft.majorArea", 160),
    shortDescription: optionalString(
      map.shortDescription, "classDraft.shortDescription", 500,
    ),
    longDescription: optionalString(
      map.longDescription, "classDraft.longDescription", 4000,
    ),
    legacyAssetTypeKey: legacyAssetTypeKey as ClassDraft["legacyAssetTypeKey"],
  };
}

function parseRoles(value: unknown): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length > 10 ||
      value.some((item) => typeof item !== "string")) {
    invalid("nodeDraft.accountableRoleKeys", "must be a list of at most 10 roles");
  }
  if (value.length === 0) return [];
  try {
    return normalizeCanonicalUserRoles(value as string[]);
  } catch {
    invalid("nodeDraft.accountableRoleKeys", "contains an unknown role");
  }
}

function parseNodeDraft(value: unknown): NodeDraft {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid("nodeDraft", "must be an object");
  }
  const map = value as JsonMap;
  const allowed = new Set([
    "parentNodeId", "nodeType", "name", "componentTag", "shortDescription",
    "longDescription", "discipline", "operatingType", "normalState",
    "failState", "contactArrangement", "manufacturer", "model",
    "applicability", "sourceReference", "ownershipStatus", "ownerDiscipline",
    "accountableRoleKeys", "sortOrder",
  ]);
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) invalid(`nodeDraft.${key}`, "is unsupported");
  }
  const nodeType = requiredString(map.nodeType, "nodeDraft.nodeType", 32);
  if (!NODE_TYPES.has(nodeType)) invalid("nodeDraft.nodeType", "is unsupported");
  const contact = requiredString(
    map.contactArrangement, "nodeDraft.contactArrangement", 32,
  );
  if (!CONTACTS.has(contact)) {
    invalid("nodeDraft.contactArrangement", "is unsupported");
  }
  const ownership = requiredString(
    map.ownershipStatus, "nodeDraft.ownershipStatus", 32,
  );
  if (!OWNERSHIP.has(ownership)) {
    invalid("nodeDraft.ownershipStatus", "is unsupported");
  }
  const roles = parseRoles(map.accountableRoleKeys);
  const ownerDiscipline = optionalString(
    map.ownerDiscipline, "nodeDraft.ownerDiscipline", 120,
  );
  if (ownership === "confirmed" &&
      (ownerDiscipline == null || roles.length === 0)) {
    invalid(
      "nodeDraft.ownershipStatus",
      "requires an owner discipline and accountable roles when confirmed",
    );
  }
  if (ownership === "provisional" &&
      ownerDiscipline == null && roles.length === 0) {
    invalid(
      "nodeDraft.ownershipStatus",
      "requires an owner discipline or accountable role when provisional",
    );
  }
  if (ownership === "unassigned" &&
      (ownerDiscipline != null || roles.length > 0)) {
    invalid(
      "nodeDraft.ownershipStatus",
      "cannot carry an owner discipline or accountable roles when unassigned",
    );
  }
  if (!Number.isSafeInteger(map.sortOrder) ||
      (map.sortOrder as number) < 0 || (map.sortOrder as number) > 999999) {
    invalid("nodeDraft.sortOrder", "must be an integer from 0 to 999999");
  }
  const componentTag = optionalString(
    map.componentTag, "nodeDraft.componentTag", 160,
  );
  const normalizedComponentTag = componentTag == null ?
    null : normalizeAssetHierarchyTag(componentTag);
  if (componentTag != null && normalizedComponentTag?.length === 0) {
    invalid("nodeDraft.componentTag", "must contain letters or numbers");
  }
  return {
    parentNodeId: map.parentNodeId == null ?
      null : documentId(map.parentNodeId, "nodeDraft.parentNodeId"),
    nodeType: nodeType as NodeDraft["nodeType"],
    name: requiredString(map.name, "nodeDraft.name", 200),
    componentTag,
    normalizedComponentTag,
    shortDescription: optionalString(
      map.shortDescription, "nodeDraft.shortDescription", 500,
    ),
    longDescription: optionalString(
      map.longDescription, "nodeDraft.longDescription", 4000,
    ),
    discipline: optionalString(map.discipline, "nodeDraft.discipline", 120),
    operatingType: optionalString(
      map.operatingType, "nodeDraft.operatingType", 160,
    ),
    normalState: optionalString(map.normalState, "nodeDraft.normalState", 160),
    failState: optionalString(map.failState, "nodeDraft.failState", 160),
    contactArrangement: contact as NodeDraft["contactArrangement"],
    manufacturer: optionalString(map.manufacturer, "nodeDraft.manufacturer", 160),
    model: optionalString(map.model, "nodeDraft.model", 160),
    applicability: optionalString(map.applicability, "nodeDraft.applicability", 500),
    sourceReference: optionalString(
      map.sourceReference, "nodeDraft.sourceReference", 500,
    ),
    ownershipStatus: ownership as NodeDraft["ownershipStatus"],
    ownerDiscipline,
    accountableRoleKeys: roles,
    sortOrder: map.sortOrder as number,
  };
}

export function parseAssetHierarchyMutationRequest(raw: JsonMap): ParsedRequest {
  const allowed = new Set([
    "requestId", "operation", "assetClassId", "nodeId", "expectedVersion",
    "expectedAssetClassVersion", "status", "reason", "allowTagTransfer",
    "classDraft", "nodeDraft",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(key, "is unsupported");
  }
  const requestId = uuid(raw.requestId, "requestId");
  const operation = requiredString(raw.operation, "operation", 32) as Operation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  const assetClassId = documentId(raw.assetClassId, "assetClassId");
  const nodeId = raw.nodeId == null ? null : documentId(raw.nodeId, "nodeId");
  const expectedVersion = optionalVersion(raw.expectedVersion, "expectedVersion");
  const expectedAssetClassVersion = optionalVersion(
    raw.expectedAssetClassVersion, "expectedAssetClassVersion",
  );
  const status = raw.status == null ? null : requiredString(raw.status, "status", 16);
  if (status != null && status !== "active" && status !== "retired") {
    invalid("status", "is unsupported");
  }
  if (raw.allowTagTransfer != null && typeof raw.allowTagTransfer !== "boolean") {
    invalid("allowTagTransfer", "must be a boolean");
  }
  const request: Omit<ParsedRequest, "fingerprint"> = {
    requestId,
    operation,
    assetClassId,
    nodeId,
    expectedVersion,
    expectedAssetClassVersion,
    status: status as ParsedRequest["status"],
    reason: requiredString(raw.reason, "reason", 500),
    allowTagTransfer: raw.allowTagTransfer === true,
    classDraft: raw.classDraft == null ? null : parseClassDraft(raw.classDraft),
    nodeDraft: raw.nodeDraft == null ? null : parseNodeDraft(raw.nodeDraft),
  };
  const classOperation = operation === "CREATE_CLASS" || operation === "UPDATE_CLASS";
  if (classOperation !== (request.classDraft != null)) {
    invalid("classDraft", classOperation ? "is required" : "is not allowed");
  }
  const nodeDraftOperation = operation === "CREATE_NODE" || operation === "UPDATE_NODE";
  if (nodeDraftOperation !== (request.nodeDraft != null)) {
    invalid("nodeDraft", nodeDraftOperation ? "is required" : "is not allowed");
  }
  const nodeOperation = operation.includes("NODE");
  if (nodeOperation !== (request.nodeId != null)) {
    invalid("nodeId", nodeOperation ? "is required" : "is not allowed");
  }
  const statusOperation = operation === "SET_CLASS_STATUS" || operation === "SET_NODE_STATUS";
  if (statusOperation !== (request.status != null)) {
    invalid("status", statusOperation ? "is required" : "is not allowed");
  }
  if (operation === "CREATE_CLASS" || operation === "CREATE_NODE") {
    if (operation === "CREATE_CLASS" && !UUID.test(assetClassId)) {
      invalid("assetClassId", "must be a canonical UUID for creation");
    }
    if (operation === "CREATE_NODE" && !UUID.test(nodeId!)) {
      invalid("nodeId", "must be a canonical UUID for creation");
    }
  }
  const fingerprint = `assetreq1-sha256:${createHash("sha256")
    .update(stableJson(request), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

export function userCanMutateAssetHierarchy(data: JsonMap): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null && authority.roles.has("admin");
}

function snapshot(value: SnapshotLike | QuerySnapshotLike, label: string): SnapshotLike {
  if ("docs" in value) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a query.`);
  }
  return value;
}

function querySnapshot(
  value: SnapshotLike | QuerySnapshotLike,
  label: string,
): QuerySnapshotLike {
  if (!("docs" in value)) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a document.`);
  }
  return value;
}

function requireRecord(record: SnapshotLike, label: string): JsonMap {
  if (!record.exists || record.data() == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return record.data()!;
}

function requireVersion(data: JsonMap, expected: number | null, label: string): number {
  const current = data.version;
  if (!Number.isSafeInteger(current) || (current as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", `${label} has a malformed version.`,
      {reasonCode: "asset-hierarchy-version-malformed"},
    );
  }
  if (expected == null || current !== expected) {
    throw new AssetHierarchyMutationError(
      "aborted", `${label} changed before this command was committed.`,
      {reasonCode: "asset-hierarchy-version-mismatch", currentVersion: current},
    );
  }
  return current as number;
}

function actorAuthority(record: SnapshotLike): JsonMap {
  const data = requireRecord(record, "Hierarchy actor");
  if (!userCanMutateAssetHierarchy(data)) {
    throw new AssetHierarchyMutationError(
      "permission-denied", "Only an approved Admin can change the asset hierarchy.",
    );
  }
  return data;
}

function tagClaimId(normalizedTag: string): string {
  return createHash("sha256").update(normalizedTag, "utf8").digest("hex");
}

function stringList(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new AssetHierarchyMutationError(
      "failed-precondition", `${field} is malformed.`,
      {reasonCode: "asset-hierarchy-record-malformed", field},
    );
  }
  return value as string[];
}

function nodeTag(data: JsonMap): string | null {
  return typeof data.normalizedComponentTag === "string" &&
    data.normalizedComponentTag.length > 0 ? data.normalizedComponentTag : null;
}

function nodeSnapshot(data: JsonMap): JsonMap {
  const copy = {...data};
  delete copy.createdAt;
  delete copy.updatedAt;
  return copy;
}

function collisionDetails(claim: JsonMap, normalizedTag: string): JsonMap {
  return {
    reasonCode: "asset-tag-collision",
    normalizedTag,
    existingNodeId: claim.nodeId,
    existingNodeName: claim.nodeName,
    existingAssetClassId: claim.assetClassId,
    existingAssetClassName: claim.assetClassName,
    existingPath: claim.hierarchyPath,
  };
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): AssetHierarchyMutationResult {
  if (data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation || data.assetClassId !== request.assetClassId ||
      data.nodeId !== request.nodeId || !Number.isSafeInteger(data.version) ||
      typeof data.auditId !== "string" || typeof data.committedAtIso !== "string") {
    throw new AssetHierarchyMutationError(
      "data-loss", "The hierarchy mutation receipt is malformed or does not match this request.",
      {reasonCode: "asset-hierarchy-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    assetClassId: request.assetClassId,
    nodeId: request.nodeId,
    version: data.version as number,
    auditId: data.auditId as string,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

export async function mutateAssetHierarchyWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<AssetHierarchyMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated", "Sign in before changing the asset hierarchy.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseAssetHierarchyMutationRequest(args.data);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);
  const db = args.db;
  const users = db.collection("users");
  const classes = db.collection("asset_classes");
  const codes = db.collection("asset_class_codes");
  const nodes = db.collection("asset_hierarchy_nodes");
  const assets = db.collection("asset_instances");
  const installedComponents = db.collection("asset_component_instances");
  const audits = db.collection("asset_hierarchy_audits");
  const receipts = db.collection("asset_hierarchy_mutation_receipts");
  const actorRef = users.doc(actorUid);
  const classRef = classes.doc(request.assetClassId);
  const nodeRef = request.nodeId == null ? null : nodes.doc(request.nodeId);
  const receiptRef = receipts.doc(request.requestId);
  const auditId = `asset_hierarchy_${request.requestId}`;
  const auditRef = audits.doc(auditId);

  actorAuthority(await actorRef.get());

  return db.runTransaction(async (transaction) => {
    const receipt = snapshot(
      await transaction.get(receiptRef), "Hierarchy receipt lookup",
    );
    const actorRecord = snapshot(
      await transaction.get(actorRef), "Hierarchy actor lookup",
    );
    const actor = actorAuthority(actorRecord);
    if (receipt.exists) {
      const replay = resultFromReceipt(
        request,
        actorUid,
        receipt.data() ?? {},
      );
      const entityRef = nodeRef ?? classRef;
      const entity = snapshot(
        await transaction.get(entityRef),
        "Hierarchy replay entity lookup",
      );
      const audit = snapshot(
        await transaction.get(auditRef),
        "Hierarchy replay audit lookup",
      );
      const entityData = requireRecord(entity, "Recorded hierarchy entity");
      const auditData = requireRecord(audit, "Recorded hierarchy audit");
      if (
        entityData.version !== replay.version ||
        entityData.lastMutationId !== request.requestId ||
        auditData.requestId !== request.requestId ||
        auditData.performedByUid !== actorUid ||
        auditData.entityId !== (request.nodeId ?? request.assetClassId)
      ) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "The hierarchy mutation receipt no longer matches its entity and audit evidence.",
          {reasonCode: "asset-hierarchy-replay-evidence-drift"},
        );
      }
      return replay;
    }

    const classRecord = snapshot(
      await transaction.get(classRef), "Asset class lookup",
    );
    const currentClass = classRecord.exists ? classRecord.data() ?? {} : null;
    let activeClassNodes: QuerySnapshotLike | null = null;
    let activeClassAssets: QuerySnapshotLike | null = null;
    if (request.operation === "SET_CLASS_STATUS" && request.status === "retired") {
      activeClassNodes = querySnapshot(
        await transaction.get(
          nodes.where("assetClassId", "==", request.assetClassId)
            .where("status", "==", "active").limit(1),
        ),
        "Active asset-class node lookup",
      );
      activeClassAssets = querySnapshot(
        await transaction.get(
          assets.where("assetClassId", "==", request.assetClassId)
            .where("status", "==", "active").limit(1),
        ),
        "Active asset-instance lookup",
      );
    }
    let currentNode: JsonMap | null = null;
    if (nodeRef != null) {
      const nodeRecord = snapshot(
        await transaction.get(nodeRef), "Hierarchy node lookup",
      );
      currentNode = nodeRecord.exists ? nodeRecord.data() ?? {} : null;
    }

    let parent: JsonMap | null = null;
    let oldParent: JsonMap | null = null;
    const desiredParentId = request.nodeDraft?.parentNodeId ??
      (typeof currentNode?.parentNodeId === "string" ? currentNode.parentNodeId : null);
    const oldParentId = typeof currentNode?.parentNodeId === "string" ?
      currentNode.parentNodeId : null;
    if (desiredParentId != null) {
      parent = requireRecord(
        snapshot(await transaction.get(nodes.doc(desiredParentId)), "Parent lookup"),
        "Hierarchy parent",
      );
    }
    if (oldParentId != null && oldParentId !== desiredParentId) {
      oldParent = requireRecord(
        snapshot(await transaction.get(nodes.doc(oldParentId)), "Old parent lookup"),
        "Previous hierarchy parent",
      );
    } else if (oldParentId != null) {
      oldParent = parent;
    }

    let activeChildren: QuerySnapshotLike | null = null;
    let activeInstallations: QuerySnapshotLike | null = null;
    const mustCheckChildren = currentNode != null && (
      request.operation === "SET_NODE_STATUS" && request.status === "retired" ||
      request.operation === "UPDATE_NODE" &&
        (request.nodeDraft!.parentNodeId !== oldParentId ||
         request.nodeDraft!.name !== currentNode.name)
    );
    if (mustCheckChildren) {
      activeChildren = querySnapshot(
        await transaction.get(
          nodes.where("parentNodeId", "==", request.nodeId)
            .where("status", "==", "active").limit(1),
        ),
        "Active child lookup",
      );
    }
    if (currentNode != null && request.operation === "SET_NODE_STATUS" &&
        request.status === "retired") {
      activeInstallations = querySnapshot(
        await transaction.get(
          installedComponents.where("definitionNodeId", "==", request.nodeId)
            .where("status", "==", "active").limit(1),
        ),
        "Active component-installation lookup",
      );
    }

    const committedAtDate = now();
    const committedAtIso = committedAtDate.toISOString();
    const committedAt = timestampFromDate(committedAtDate);
    const actorName = typeof actor.name === "string" && actor.name.trim().length > 0 ?
      actor.name.trim() : actorUid;
    let before: JsonMap | null = null;
    let after: JsonMap;
    let version: number;
    let action: string;

    if (request.operation === "CREATE_CLASS") {
      if (classRecord.exists) {
        throw new AssetHierarchyMutationError("already-exists", "Asset class already exists.");
      }
      const draft = request.classDraft!;
      const codeRef = codes.doc(draft.code.toLowerCase());
      const codeRecord = snapshot(
        await transaction.get(codeRef), "Asset class code lookup",
      );
      if (codeRecord.exists) {
        throw new AssetHierarchyMutationError(
          "already-exists", `Asset-class code ${draft.code} is already reserved.`,
          {reasonCode: "asset-class-code-collision", code: draft.code},
        );
      }
      version = 1;
      action = "create";
      after = {
        schemaVersion: 1,
        assetClassId: request.assetClassId,
        ...draft,
        status: "active",
        version,
        createdAt: committedAt,
        createdByUid: actorUid,
        createdByName: actorName,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName,
        lastMutationId: request.requestId,
      };
      transaction.set(classRef, after);
      transaction.set(codeRef, {
        schemaVersion: 1,
        code: draft.code,
        assetClassId: request.assetClassId,
        createdAt: committedAt,
        createdByUid: actorUid,
      });
    } else if (request.operation === "UPDATE_CLASS" ||
        request.operation === "SET_CLASS_STATUS") {
      const current = currentClass ?? requireRecord(classRecord, "Asset class");
      const currentVersion = requireVersion(
        current, request.expectedVersion, "Asset class",
      );
      if (activeClassNodes != null && activeClassNodes.docs.length > 0) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "Retire the active hierarchy nodes before retiring this asset class.",
          {reasonCode: "asset-class-active-nodes"},
        );
      }
      if (activeClassAssets != null && activeClassAssets.docs.length > 0) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "Retire physical assets before retiring this asset class.",
          {reasonCode: "asset-class-active-instances"},
        );
      }
      before = nodeSnapshot(current);
      const draft = request.operation === "UPDATE_CLASS" ? request.classDraft! : {
        code: current.code as string,
        name: current.name as string,
        majorArea: current.majorArea as string,
        shortDescription: current.shortDescription as string | null,
        longDescription: current.longDescription as string | null,
        legacyAssetTypeKey: current.legacyAssetTypeKey as ClassDraft["legacyAssetTypeKey"],
      };
      if (draft.code !== current.code) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "Asset-class code is immutable.",
        );
      }
      version = currentVersion + 1;
      action = request.operation === "UPDATE_CLASS" ? "update" : request.status!;
      after = {
        ...current,
        ...draft,
        status: request.operation === "SET_CLASS_STATUS" ? request.status : current.status,
        version,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName,
        lastMutationId: request.requestId,
      };
      transaction.set(classRef, after);
    } else {
      if (currentClass == null || currentClass.status !== "active") {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The owning asset class must be active.",
        );
      }
      if (request.operation === "CREATE_NODE") {
        if (currentNode != null) {
          throw new AssetHierarchyMutationError("already-exists", "Hierarchy node already exists.");
        }
        requireVersion(
          currentClass, request.expectedAssetClassVersion, "Asset class",
        );
        version = 1;
        action = "create";
      } else {
        if (currentNode == null) {
          throw new AssetHierarchyMutationError("not-found", "Hierarchy node was not found.");
        }
        if (request.operation === "UPDATE_NODE" && currentNode.status !== "active") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Restore this hierarchy node before editing it.",
            {reasonCode: "asset-hierarchy-node-retired"},
          );
        }
        version = requireVersion(
          currentNode, request.expectedVersion, "Hierarchy node",
        ) + 1;
        action = request.operation === "UPDATE_NODE" ? "update" : request.status!;
        before = nodeSnapshot(currentNode);
      }
      if (activeChildren != null && activeChildren.docs.length > 0) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          request.operation === "SET_NODE_STATUS" ?
            "Retire or move active child nodes first." :
            "Move child nodes before renaming or moving this branch.",
          {reasonCode: "asset-hierarchy-active-children"},
        );
      }
      if (activeInstallations != null && activeInstallations.docs.length > 0) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "Retire installed components before retiring this definition.",
          {reasonCode: "asset-definition-active-installations"},
        );
      }
      const draft = request.nodeDraft ?? {
        parentNodeId: currentNode!.parentNodeId as string | null,
        nodeType: currentNode!.nodeType as NodeDraft["nodeType"],
        name: currentNode!.name as string,
        componentTag: currentNode!.componentTag as string | null,
        normalizedComponentTag: nodeTag(currentNode!),
        shortDescription: currentNode!.shortDescription as string | null,
        longDescription: currentNode!.longDescription as string | null,
        discipline: currentNode!.discipline as string | null,
        operatingType: currentNode!.operatingType as string | null,
        normalState: currentNode!.normalState as string | null,
        failState: currentNode!.failState as string | null,
        contactArrangement: currentNode!.contactArrangement as NodeDraft["contactArrangement"],
        manufacturer: currentNode!.manufacturer as string | null,
        model: currentNode!.model as string | null,
        applicability: currentNode!.applicability as string | null,
        sourceReference: currentNode!.sourceReference as string | null,
        ownershipStatus: currentNode!.ownershipStatus as NodeDraft["ownershipStatus"],
        ownerDiscipline: currentNode!.ownerDiscipline as string | null,
        accountableRoleKeys: stringList(
          currentNode!.accountableRoleKeys, "accountableRoleKeys",
        ),
        sortOrder: currentNode!.sortOrder as number,
      };
      const resultingStatus = request.operation === "SET_NODE_STATUS" ?
        request.status! : (currentNode?.status as string | undefined) ?? "active";
      if (draft.parentNodeId === request.nodeId) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "A hierarchy node cannot be its own parent.",
        );
      }
      const ancestorIds = parent == null ? [] : [
        ...stringList(parent.ancestorNodeIds, "parent.ancestorNodeIds"),
        draft.parentNodeId!,
      ];
      const parentPath = parent == null ? [] :
        stringList(parent.hierarchyPath, "parent.hierarchyPath");
      if (parent != null &&
          (parent.assetClassId !== request.assetClassId || parent.status !== "active")) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "Parent must be active and belong to this asset class.",
        );
      }
      if (ancestorIds.includes(request.nodeId!) || ancestorIds.length > 8) {
        throw new AssetHierarchyMutationError(
          "failed-precondition", "The requested parent would create a cycle or exceed eight levels.",
        );
      }
      const hierarchyPath = [...parentPath, draft.name];
      after = {
        ...(currentNode ?? {}),
        ...draft,
        schemaVersion: 1,
        nodeId: request.nodeId,
        assetClassId: request.assetClassId,
        ancestorNodeIds: ancestorIds,
        hierarchyPath,
        activeChildCount: currentNode?.activeChildCount ?? 0,
        status: resultingStatus,
        version,
        createdAt: currentNode?.createdAt ?? committedAt,
        createdByUid: currentNode?.createdByUid ?? actorUid,
        createdByName: currentNode?.createdByName ?? actorName,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName,
        lastMutationId: request.requestId,
      };
      if (resultingStatus === "retired") {
        after.componentTag = draft.componentTag;
        after.normalizedComponentTag = draft.normalizedComponentTag;
      }
      transaction.set(nodeRef!, after);

      const wasActive = currentNode?.status === "active";
      const willBeActive = resultingStatus === "active";
      if (oldParentId !== desiredParentId || wasActive !== willBeActive) {
        if (oldParent != null && wasActive) {
          const count = oldParent.activeChildCount;
          if (!Number.isSafeInteger(count) || (count as number) <= 0) {
            throw new AssetHierarchyMutationError(
              "failed-precondition", "The previous parent child count is invalid.",
              {reasonCode: "asset-hierarchy-child-count-invalid"},
            );
          }
          transaction.set(nodes.doc(oldParentId!), {
            ...oldParent,
            activeChildCount: (count as number) - 1,
            version: (oldParent.version as number) + 1,
            updatedAt: committedAt,
            updatedByUid: actorUid,
            updatedByName: actorName,
            lastMutationId: request.requestId,
          });
        }
        if (parent != null && willBeActive) {
          const count = parent.activeChildCount;
          if (!Number.isSafeInteger(count) || (count as number) < 0) {
            throw new AssetHierarchyMutationError(
              "failed-precondition", "The new parent child count is invalid.",
              {reasonCode: "asset-hierarchy-child-count-invalid"},
            );
          }
          transaction.set(nodes.doc(desiredParentId!), {
            ...parent,
            activeChildCount: (count as number) + 1,
            version: (parent.version as number) + 1,
            updatedAt: committedAt,
            updatedByUid: actorUid,
            updatedByName: actorName,
            lastMutationId: request.requestId,
          });
        }
      }

    }

    transaction.set(auditRef, {
      schemaVersion: 1,
      auditId,
      entityType: request.nodeId == null ? "asset_class" : "hierarchy_node",
      entityId: request.nodeId ?? request.assetClassId,
      assetClassId: request.assetClassId,
      action,
      reason: request.reason,
      beforeJson: before == null ? null : JSON.stringify(before),
      afterJson: JSON.stringify(nodeSnapshot(after)),
      performedByUid: actorUid,
      performedByName: actorName,
      performedAt: committedAt,
      requestId: request.requestId,
      tagTransferApproved: request.allowTagTransfer,
    });
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      assetClassId: request.assetClassId,
      nodeId: request.nodeId,
      version,
      auditId,
      committedAt,
      committedAtIso,
    });
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      assetClassId: request.assetClassId,
      nodeId: request.nodeId,
      version,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
