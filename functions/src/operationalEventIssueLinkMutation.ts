import {createHash} from "crypto";

import {
  AssetHierarchyMutationError,
  AssetHierarchyMutationFirestoreLike,
} from "./assetHierarchyMutation";
import {
  timestampDate,
  validateCurrentEvent,
} from "./operationalEventMutation";
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
type TransactionLike = {
  get: (ref: unknown) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap) => void;
};

export const OPERATIONAL_EVENT_ISSUE_LINK_OPERATION =
  "LINK_OPERATIONAL_EVENT_ISSUE" as const;

export type OperationalEventIssueRelationship =
  | "causedByEvent"
  | "responseToEvent"
  | "affectedByEvent";

interface ParsedRequest {
  requestId: string;
  operation: typeof OPERATIONAL_EVENT_ISSUE_LINK_OPERATION;
  eventId: string;
  issueId: string;
  expectedEventVersion: number;
  expectedIssueVersion: number;
  relationship: OperationalEventIssueRelationship;
  reason: string;
  fingerprint: string;
}

export interface OperationalEventIssueLinkMutationResult {
  ok: true;
  requestId: string;
  operation: typeof OPERATIONAL_EVENT_ISSUE_LINK_OPERATION;
  eventId: string;
  issueId: string;
  linkId: string;
  eventVersion: number;
  issueVersion: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const RELATIONSHIPS = new Set<OperationalEventIssueRelationship>([
  "causedByEvent",
  "responseToEvent",
  "affectedByEvent",
]);
const LINK_ROLES = new Set([
  "admin", "si", "shiftSupervisor", "operations", "contractSupervisor",
]);
const ISSUE_STATUSES = new Set([
  "open", "acknowledged", "inProgress", "resolved",
]);
const MAX_EVENT_LINKS = 100;
const MAX_ISSUE_LINKS = 50;
const LINK_ID = /^event_issue_[0-9a-f]{48}$/;

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-operational-event-issue-link-request", field},
  );
}

function requiredString(value: unknown, field: string, maximum: number): string {
  if (typeof value !== "string") invalid(field, "must be a string");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0 || cleaned.length > maximum) {
    invalid(field, `must contain 1-${maximum} characters`);
  }
  return cleaned;
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is invalid");
  }
  return id;
}

function positiveVersion(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    invalid(field, "must be a positive integer");
  }
  return value as number;
}

export function isOperationalEventIssueLinkOperation(
  value: unknown,
): value is typeof OPERATIONAL_EVENT_ISSUE_LINK_OPERATION {
  return value === OPERATIONAL_EVENT_ISSUE_LINK_OPERATION;
}

export function parseOperationalEventIssueLinkRequest(
  raw: JsonMap,
): ParsedRequest {
  const allowed = new Set([
    "requestId", "operation", "eventId", "issueId", "expectedEventVersion",
    "expectedIssueVersion", "relationship", "reason",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(key, "is unsupported");
  }
  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  if (!isOperationalEventIssueLinkOperation(raw.operation)) {
    invalid("operation", "is unsupported");
  }
  const eventId = requiredString(raw.eventId, "eventId", 64);
  if (!UUID.test(eventId)) invalid("eventId", "must be a canonical UUID");
  const issueId = documentId(raw.issueId, "issueId");
  const relationship = requiredString(
    raw.relationship,
    "relationship",
    32,
  ) as OperationalEventIssueRelationship;
  if (!RELATIONSHIPS.has(relationship)) {
    invalid("relationship", "is unsupported");
  }
  const reason = requiredString(raw.reason, "reason", 1000);
  const request = {
    requestId,
    operation: OPERATIONAL_EVENT_ISSUE_LINK_OPERATION,
    eventId,
    issueId,
    expectedEventVersion: positiveVersion(
      raw.expectedEventVersion,
      "expectedEventVersion",
    ),
    expectedIssueVersion: positiveVersion(
      raw.expectedIssueVersion,
      "expectedIssueVersion",
    ),
    relationship,
    reason,
  };
  const fingerprint = `operationaleventissuelink1-sha256:${createHash("sha256")
    .update(stableJson(request), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

export function userCanLinkOperationalEventIssue(data: JsonMap): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null &&
    [...authority.roles].some((role) => LINK_ROLES.has(role));
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

function record(value: SnapshotLike, label: string): JsonMap {
  const data = value.data();
  if (!value.exists || data == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return data;
}

function actor(value: SnapshotLike): JsonMap {
  const data = record(value, "Operational-event issue-link actor");
  if (!userCanLinkOperationalEventIssue(data)) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Only approved operational or supervisory users can link an issue to an operational event.",
    );
  }
  return data;
}

function actorName(data: JsonMap): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : "Approved user";
}

function maintenanceTimestampDate(value: unknown): Date | null {
  if (typeof value !== "string") return timestampDate(value);
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)?$/.exec(value);
  if (match == null) return null;
  const parts = match.slice(1, 7).map(Number);
  const candidate = new Date(value);
  const calendar = new Date(Date.UTC(
    parts[0], parts[1] - 1, parts[2], parts[3], parts[4], parts[5],
  ));
  if (Number.isNaN(candidate.getTime()) ||
      calendar.getUTCFullYear() !== parts[0] ||
      calendar.getUTCMonth() !== parts[1] - 1 ||
      calendar.getUTCDate() !== parts[2] ||
      calendar.getUTCHours() !== parts[3] ||
      calendar.getUTCMinutes() !== parts[4] ||
      calendar.getUTCSeconds() !== parts[5]) return null;
  return candidate;
}

function boundedIds(
  value: unknown,
  field: string,
  maximum: number,
  reasonCode: string,
): string[] {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > maximum ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.length > 128 ||
        item === "." || item === ".." || item.includes("/")) ||
      new Set(value).size !== value.length) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `The saved ${field} projection is malformed.`,
      {reasonCode, field},
    );
  }
  return [...value] as string[];
}

type IssueEvidence = {
  version: number;
  status: string;
  isResolved: boolean;
  assetType: string;
  assetNumber: number;
  description: string;
  routedTo: string;
  component: string | null;
  subsystem: string | null;
  tag: string | null;
  assetClassId: string | null;
  assetInstanceId: string | null;
  linkIds: string[];
};

function optionalIssueText(
  value: unknown,
  field: string,
  maximum: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string" || value.length > maximum) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `The maintenance issue has malformed ${field} evidence.`,
      {reasonCode: "operational-event-link-issue-malformed", field},
    );
  }
  const cleaned = value.trim();
  return cleaned.length === 0 ? null : cleaned;
}

function assetReference(value: unknown): {
  assetClassId: string | null;
  assetInstanceId: string | null;
} {
  if (value == null) return {assetClassId: null, assetInstanceId: null};
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The maintenance issue has malformed governed asset evidence.",
      {reasonCode: "operational-event-link-issue-asset-reference-malformed"},
    );
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    parsed = null;
  }
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The maintenance issue has malformed governed asset evidence.",
      {reasonCode: "operational-event-link-issue-asset-reference-malformed"},
    );
  }
  const row = parsed as JsonMap;
  const schemaVersion = row.schemaVersion;
  const scope = schemaVersion === 1 ? "definition" : row.scope;
  if (![1, 2, 3].includes(schemaVersion as number) ||
      !["definition", "physicalAsset", "installedComponent"].includes(
        scope as string,
      ) ||
      (scope === "physicalAsset" && schemaVersion !== 3) ||
      typeof row.assetClassId !== "string" ||
      row.assetClassId.trim().length === 0 ||
      (row.assetInstanceId != null &&
        (typeof row.assetInstanceId !== "string" ||
          row.assetInstanceId.trim().length === 0))) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The maintenance issue has malformed governed asset evidence.",
      {reasonCode: "operational-event-link-issue-asset-reference-malformed"},
    );
  }
  return {
    assetClassId: row.assetClassId as string,
    assetInstanceId: row.assetInstanceId as string | null,
  };
}

function validateIssue(data: JsonMap, issueId: string): IssueEvidence {
  const version = data.version;
  const status = data.status;
  const isResolved = data.isResolved;
  const assetType = data.assetType;
  const assetNumber = data.assetNumber;
  const description = data.description;
  const routedTo = data.routedTo;
  if (data.firestoreId !== issueId || !Number.isSafeInteger(version) ||
      (version as number) < 1 || typeof status !== "string" ||
      !ISSUE_STATUSES.has(status) || typeof isResolved !== "boolean" ||
      ((status === "resolved") !== isResolved) || data.isDeleted !== false ||
      typeof assetType !== "string" || assetType.trim().length === 0 ||
      !Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1 ||
      typeof description !== "string" || description.trim().length === 0 ||
      description.length > 4000 || typeof routedTo !== "string" ||
      routedTo.trim().length === 0 ||
      maintenanceTimestampDate(data.startDate) == null ||
      maintenanceTimestampDate(data.createdAt) == null ||
      maintenanceTimestampDate(data.updatedAt) == null) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The maintenance issue is incomplete, deleted, or malformed.",
      {reasonCode: "operational-event-link-issue-malformed", issueId},
    );
  }
  const reference = assetReference(data.assetHierarchyRefJson);
  return {
    version: version as number,
    status,
    isResolved,
    assetType,
    assetNumber: assetNumber as number,
    description: description.trim(),
    routedTo: routedTo.trim(),
    component: optionalIssueText(data.component, "component", 500),
    subsystem: optionalIssueText(data.subsystem, "subsystem", 500),
    tag: optionalIssueText(data.tag, "tag", 200),
    assetClassId: reference.assetClassId,
    assetInstanceId: reference.assetInstanceId,
    linkIds: boundedIds(
      data.operationalEventIssueLinkIds,
      "maintenance operational-event links",
      MAX_ISSUE_LINKS,
      "operational-event-link-issue-projection-malformed",
    ),
  };
}

function validateScope(event: JsonMap, issue: IssueEvidence): void {
  if (event.scope === "plantWide") return;
  if (event.scope === "assetClasses" && issue.assetClassId != null &&
      (event.affectedAssetClassIds as unknown[]).includes(issue.assetClassId)) {
    return;
  }
  if (event.scope === "assets" && issue.assetInstanceId != null &&
      (event.affectedAssetInstanceIds as unknown[]).includes(issue.assetInstanceId)) {
    return;
  }
  throw new AssetHierarchyMutationError(
    "failed-precondition",
    "The issue does not belong to the governed asset scope of this event occurrence.",
    {reasonCode: "operational-event-link-scope-mismatch"},
  );
}

function linkIdentity(eventId: string, startedAt: Date, issueId: string): string {
  const digest = createHash("sha256")
    .update(`${eventId}\n${startedAt.toISOString()}\n${issueId}`, "utf8")
    .digest("hex");
  return `event_issue_${digest.slice(0, 48)}`;
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): OperationalEventIssueLinkMutationResult {
  const committedAt = typeof data.committedAtIso === "string" ?
    new Date(data.committedAtIso) : null;
  const persistedCommittedAt = timestampDate(data.committedAt);
  const expectedAuditId = `operational_event_issue_${request.requestId}`;
  if (data.schemaVersion !== 1 || data.requestId !== request.requestId ||
      data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation || data.eventId !== request.eventId ||
      data.issueId !== request.issueId || typeof data.linkId !== "string" ||
      !LINK_ID.test(data.linkId) || !Number.isSafeInteger(data.eventVersion) ||
      (data.eventVersion as number) < 1 ||
      !Number.isSafeInteger(data.issueVersion) ||
      (data.issueVersion as number) < 1 || data.auditId !== expectedAuditId ||
      committedAt == null || Number.isNaN(committedAt.getTime()) ||
      committedAt.toISOString() !== data.committedAtIso ||
      persistedCommittedAt?.toISOString() !== data.committedAtIso) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The operational-event issue-link receipt is malformed or mismatched.",
      {reasonCode: "operational-event-issue-link-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    eventId: request.eventId,
    issueId: request.issueId,
    linkId: data.linkId as string,
    eventVersion: data.eventVersion as number,
    issueVersion: data.issueVersion as number,
    auditId: data.auditId as string,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

export async function mutateOperationalEventIssueLinkWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<OperationalEventIssueLinkMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before linking an issue to an operational event.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseOperationalEventIssueLinkRequest(args.data);
  const db = args.db;
  const actorRef = db.collection("users").doc(actorUid);
  const eventRef = db.collection("operational_events").doc(request.eventId);
  const issueRef = db.collection("maintenance_records").doc(request.issueId);
  const links = db.collection("operational_event_issue_links");
  const audits = db.collection("operational_event_issue_link_audits");
  const receipts = db.collection("operational_event_issue_link_receipts");
  const auditId = `operational_event_issue_${request.requestId}`;
  const auditRef = audits.doc(auditId);
  const receiptRef = receipts.doc(request.requestId);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  actor(await actorRef.get());

  return db.runTransaction(async (rawTransaction) => {
    const transaction = rawTransaction as unknown as TransactionLike;
    const actorData = actor(asSnapshot(
      await transaction.get(actorRef),
      "Operational-event issue-link actor lookup",
    ));
    const receiptValue = asSnapshot(
      await transaction.get(receiptRef),
      "Operational-event issue-link receipt lookup",
    );
    if (receiptValue.exists) {
      const replay = resultFromReceipt(
        request,
        actorUid,
        receiptValue.data() ?? {},
      );
      const replayLinkRef = links.doc(replay.linkId);
      const auditValue = asSnapshot(
        await transaction.get(auditRef),
        "Operational-event issue-link audit lookup",
      );
      const linkValue = asSnapshot(
        await transaction.get(replayLinkRef),
        "Operational-event issue-link lookup",
      );
      const auditData = record(auditValue, "Recorded issue-link audit");
      const linkData = record(
        linkValue,
        "Recorded operational-event issue link",
      );
      const linkCommittedAt = timestampDate(linkData.linkedAt);
      const auditCommittedAt = timestampDate(auditData.performedAt);
      if (auditData.schemaVersion !== 1 ||
          auditData.auditId !== replay.auditId ||
          auditData.requestId !== request.requestId ||
          auditData.operation !== request.operation ||
          auditData.eventId !== request.eventId ||
          auditData.issueId !== request.issueId ||
          auditData.linkId !== replay.linkId ||
          auditData.relationship !== request.relationship ||
          auditData.reason !== request.reason ||
          auditData.performedByUid !== actorUid ||
          linkData.schemaVersion !== 1 || linkData.linkId !== replay.linkId ||
          linkData.auditId !== replay.auditId ||
          linkData.requestId !== request.requestId ||
          linkData.eventId !== request.eventId ||
          linkData.issueId !== request.issueId ||
          linkData.relationship !== request.relationship ||
          linkData.reason !== request.reason ||
          linkData.linkedByUid !== actorUid ||
          linkCommittedAt?.toISOString() !== replay.committedAt ||
          auditCommittedAt?.toISOString() !== replay.committedAt) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "The issue-link receipt no longer matches its immutable audit and link evidence.",
          {reasonCode: "operational-event-issue-link-replay-evidence-drift"},
        );
      }
      return replay;
    }
    const auditValue = asSnapshot(
      await transaction.get(auditRef),
      "Operational-event issue-link audit lookup",
    );
    const eventValue = asSnapshot(
      await transaction.get(eventRef),
      "Operational-event lookup",
    );
    const issueValue = asSnapshot(
      await transaction.get(issueRef),
      "Maintenance issue lookup",
    );
    const event = record(eventValue, "Operational event");
    const issue = record(issueValue, "Maintenance issue");
    const eventVersion = validateCurrentEvent(event, request.eventId);
    const issueEvidence = validateIssue(issue, request.issueId);
    const startedAt = timestampDate(event.startedAt);
    if (startedAt == null) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "The operational event has malformed occurrence identity.",
        {reasonCode: "operational-event-link-occurrence-malformed"},
      );
    }
    const linkId = linkIdentity(request.eventId, startedAt, request.issueId);
    const linkRef = links.doc(linkId);
    const linkValue = asSnapshot(
      await transaction.get(linkRef),
      "Operational-event issue-link lookup",
    );

    if (auditValue.exists) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "An operational-event issue-link audit exists without its request receipt.",
        {reasonCode: "operational-event-issue-link-orphan-audit"},
      );
    }
    if (linkValue.exists) {
      throw new AssetHierarchyMutationError(
        "already-exists",
        "This issue is already linked to the current event occurrence.",
        {reasonCode: "operational-event-issue-link-already-exists", linkId},
      );
    }
    if (eventVersion !== request.expectedEventVersion ||
        issueEvidence.version !== request.expectedIssueVersion) {
      throw new AssetHierarchyMutationError(
        "aborted",
        "The event or maintenance issue changed before the link was committed.",
        {
          reasonCode: "operational-event-issue-link-version-mismatch",
          currentEventVersion: eventVersion,
          currentIssueVersion: issueEvidence.version,
        },
      );
    }
    validateScope(event, issueEvidence);
    const eventLinkIds = boundedIds(
      event.issueLinkIds,
      "operational-event issue links",
      MAX_EVENT_LINKS,
      "operational-event-link-event-projection-malformed",
    );
    const linkedIssueIds = boundedIds(
      event.linkedIssueIds,
      "operational-event linked issue identities",
      MAX_EVENT_LINKS,
      "operational-event-link-event-projection-malformed",
    );
    if (eventLinkIds.length !== linkedIssueIds.length) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "The saved operational-event issue projections are incomplete.",
        {reasonCode: "operational-event-link-event-projection-malformed"},
      );
    }
    if (linkedIssueIds.includes(request.issueId)) {
      throw new AssetHierarchyMutationError(
        "already-exists",
        "This issue is already linked to the current event occurrence.",
        {reasonCode: "operational-event-issue-link-already-exists", linkId},
      );
    }
    if (eventLinkIds.length >= MAX_EVENT_LINKS ||
        issueEvidence.linkIds.length >= MAX_ISSUE_LINKS) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "The event or issue has reached its governed link limit.",
        {reasonCode: "operational-event-issue-link-limit"},
      );
    }

    const committed = now();
    const committedAt = timestampFromDate(committed);
    const nextEventVersion = eventVersion + 1;
    const nextIssueVersion = issueEvidence.version + 1;
    const nextEventLinkIds = [...eventLinkIds, linkId].sort();
    const nextLinkedIssueIds = [...linkedIssueIds, request.issueId].sort();
    const nextIssueLinkIds = [...issueEvidence.linkIds, linkId].sort();
    const link: JsonMap = {
      schemaVersion: 1,
      linkId,
      requestId: request.requestId,
      auditId,
      eventId: request.eventId,
      eventVersionAtLink: eventVersion,
      eventOccurrenceStartedAt: event.startedAt,
      eventType: event.eventType,
      eventTitle: event.title,
      eventSeverity: event.severity,
      eventScope: event.scope,
      affectedAssetClassIds: event.affectedAssetClassIds,
      affectedAssetInstanceIds: event.affectedAssetInstanceIds,
      issueId: request.issueId,
      issueVersionAtLink: issueEvidence.version,
      issueStatusAtLink: issueEvidence.status,
      issueResolvedAtLink: issueEvidence.isResolved,
      issueAssetType: issueEvidence.assetType,
      issueAssetNumber: issueEvidence.assetNumber,
      issueAssetClassId: issueEvidence.assetClassId,
      issueAssetInstanceId: issueEvidence.assetInstanceId,
      issueDescription: issueEvidence.description,
      issueRoutedTo: issueEvidence.routedTo,
      issueComponent: issueEvidence.component,
      issueSubsystem: issueEvidence.subsystem,
      issueTag: issueEvidence.tag,
      relationship: request.relationship,
      reason: request.reason,
      linkedAt: committedAt,
      linkedByUid: actorUid,
      linkedByName: actorName(actorData),
    };
    const audit: JsonMap = {
      schemaVersion: 1,
      auditId,
      requestId: request.requestId,
      operation: request.operation,
      eventId: request.eventId,
      issueId: request.issueId,
      linkId,
      relationship: request.relationship,
      reason: request.reason,
      beforeEventIssueLinkIds: eventLinkIds,
      afterEventIssueLinkIds: nextEventLinkIds,
      beforeEventLinkedIssueIds: linkedIssueIds,
      afterEventLinkedIssueIds: nextLinkedIssueIds,
      beforeIssueEventLinkIds: issueEvidence.linkIds,
      afterIssueEventLinkIds: nextIssueLinkIds,
      performedAt: committedAt,
      performedByUid: actorUid,
      performedByName: actorName(actorData),
    };
    const receipt: JsonMap = {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      eventId: request.eventId,
      issueId: request.issueId,
      linkId,
      eventVersion: nextEventVersion,
      issueVersion: nextIssueVersion,
      auditId,
      committedAt,
      committedAtIso: committed.toISOString(),
    };
    transaction.set(eventRef as unknown as DocumentRefLike, {
      ...event,
      issueLinkIds: nextEventLinkIds,
      linkedIssueIds: nextLinkedIssueIds,
      version: nextEventVersion,
      updatedAt: committedAt,
      updatedByUid: actorUid,
      updatedByName: actorName(actorData),
      lastMutationId: request.requestId,
    });
    transaction.set(issueRef as unknown as DocumentRefLike, {
      ...issue,
      operationalEventIssueLinkIds: nextIssueLinkIds,
      version: nextIssueVersion,
      updatedAt: committedAt,
    });
    transaction.set(linkRef as unknown as DocumentRefLike, link);
    transaction.set(auditRef as unknown as DocumentRefLike, audit);
    transaction.set(receiptRef as unknown as DocumentRefLike, receipt);
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      eventId: request.eventId,
      issueId: request.issueId,
      linkId,
      eventVersion: nextEventVersion,
      issueVersion: nextIssueVersion,
      auditId,
      committedAt: committed.toISOString(),
      idempotentReplay: false,
    };
  });
}
