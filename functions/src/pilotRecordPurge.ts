import {createHash} from "node:crypto";

import {stableJson} from "./stableJson";
import {CommandHandler} from "./maintenanceWorkflow/handlerTypes";
import {WorkflowError} from "./maintenanceWorkflow/errors";
import {
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./maintenanceWorkflow/types";
import {cleanText, intValue, iso} from "./maintenanceWorkflow/utils";

export const PILOT_PURGE_RECEIPT_COLLECTION = "pilot_record_purge_receipts";
export const PILOT_PURGE_RECEIPT_SCHEMA_VERSION = 1;
export const PILOT_PURGE_ALLOWED_COLLECTIONS = Object.freeze([
  "maintenance_records",
  "directives",
  "job_templates",
] as const);

type PilotPurgeCollection = typeof PILOT_PURGE_ALLOWED_COLLECTIONS[number];

const ALLOWED_COLLECTION_SET = new Set<string>(PILOT_PURGE_ALLOWED_COLLECTIONS);
const DOCUMENT_ID_PATTERN = /^[^/.][^/]{0,198}[^/.]$|^[A-Za-z0-9_-]$/;

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (!DOCUMENT_ID_PATTERN.test(parsed) || parsed === "." || parsed === "..") {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const collectionId = (value: unknown): PilotPurgeCollection => {
  const parsed = cleanText(value, "collectionId");
  if (!ALLOWED_COLLECTION_SET.has(parsed)) {
    throw new WorkflowError(
      "invalid-argument",
      "This record family cannot be permanently removed.",
      {reasonCode: "pilot-record-purge-collection-not-allowed"},
    );
  }
  return parsed as PilotPurgeCollection;
};

export const pilotPurgeSourceDigest = (source: unknown): string =>
  createHash("sha256").update(stableJson(source), "utf8").digest("hex");

export const pilotPurgeReceiptId = (
  sourceCollection: string,
  sourceDocumentId: string,
): string => `purge_${createHash("sha256")
  .update(`${sourceCollection}/${sourceDocumentId}`, "utf8")
  .digest("hex")}`;

const requireNoRows = async (
  rows: readonly {path: string}[],
  reasonCode: string,
): Promise<void> => {
  if (rows.length === 0) return;
  throw new WorkflowError(
    "failed-precondition",
    "This record is still referenced by retained business data.",
    {reasonCode, referencePath: rows[0].path},
  );
};

const requireNoDependencies = async (
  args: Parameters<CommandHandler>[0],
  sourceCollection: PilotPurgeCollection,
  sourceDocumentId: string,
): Promise<void> => {
  const {tx} = args;
  if (sourceCollection === "maintenance_records") {
    const [
      directives,
      abnormalities,
      workflows,
      compliance,
      eventLinks,
      events,
      conditions,
      inspectionLinks,
      inspectionFindings,
      cases,
    ] =
      await Promise.all([
        tx.query("directives", [{
          field: "linkedMaintenanceFirestoreId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("charge_abnormalities", [{
          field: "linkedTicketFirestoreId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("maintenance_workflows", [{
          field: "linkedMaintenanceFirestoreId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("compliance_requests", [{
          field: "linkedMaintenanceFirestoreId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("operational_event_issue_links", [{
          field: "issueId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("operational_events", [{
          field: "linkedIssueIds", op: "array-contains", value: sourceDocumentId,
        }]),
        tx.query("asset_operational_conditions", [{
          field: "linkedIssueIds", op: "array-contains", value: sourceDocumentId,
        }]),
        tx.query("inspection_issue_links", [{
          field: "ticketId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("inspection_findings", [{
          field: "linkedTicketId", op: "==", value: sourceDocumentId,
        }]),
        tx.query("furnace_stuckup_cases", [{
          field: "ticketId", op: "==", value: sourceDocumentId,
        }]),
      ]);
    await requireNoRows(directives, "pilot-record-purge-linked-directive");
    await requireNoRows(abnormalities, "pilot-record-purge-linked-abnormality");
    await requireNoRows(workflows, "pilot-record-purge-linked-workflow");
    await requireNoRows(compliance, "pilot-record-purge-linked-compliance");
    await requireNoRows(eventLinks, "pilot-record-purge-linked-event");
    await requireNoRows(events, "pilot-record-purge-linked-event-projection");
    await requireNoRows(conditions, "pilot-record-purge-linked-asset-condition");
    await requireNoRows(inspectionLinks, "pilot-record-purge-linked-inspection");
    await requireNoRows(
      inspectionFindings,
      "pilot-record-purge-linked-inspection-finding",
    );
    await requireNoRows(cases, "pilot-record-purge-linked-stuckup-case");
    for (const path of [
      `quality_warnings/issue_${sourceDocumentId}`,
      `maintenance_burner_closures/${sourceDocumentId}`,
    ]) {
      const dependent = await tx.get(path);
      if (dependent.exists) {
        throw new WorkflowError(
          "failed-precondition",
          "This record is still referenced by retained business data.",
          {reasonCode: "pilot-record-purge-linked-projection", referencePath: path},
        );
      }
    }
    return;
  }

  if (sourceCollection === "job_templates") {
    const [executions, modules, diaryEntries] = await Promise.all([
      tx.query("job_executions", [{
        field: "templateFirestoreId", op: "==", value: sourceDocumentId,
      }]),
      tx.query("job_modules", [{
        field: "templateFirestoreId", op: "==", value: sourceDocumentId,
      }]),
      tx.query("job_diary_entries", [{
        field: "templateFirestoreId", op: "==", value: sourceDocumentId,
      }]),
    ]);
    await requireNoRows(executions, "pilot-record-purge-linked-execution");
    await requireNoRows(modules, "pilot-record-purge-linked-module");
    await requireNoRows(diaryEntries, "pilot-record-purge-linked-diary");
    return;
  }

  if (sourceCollection === "directives") {
    const rounds = await tx.query("burner_condition_rounds", [{
      field: "directiveId", op: "==", value: sourceDocumentId,
    }]);
    await requireNoRows(rounds, "pilot-record-purge-linked-burner-round");
  }
};

export const purgePilotBusinessRecord: CommandHandler = async (args) => {
  const {tx, command, context} = args;
  const sourceCollection = collectionId(command.payload.collectionId);
  const sourceDocumentId = documentId(
    command.payload.documentId,
    "documentId",
  );
  if (command.aggregateId !== sourceDocumentId) {
    throw new WorkflowError(
      "invalid-argument",
      "The purge aggregate identity does not match the source record.",
      {reasonCode: "pilot-record-purge-aggregate-mismatch"},
    );
  }
  const reason = cleanText(command.payload.reason, "reason");
  if (reason.length > 1000) {
    throw new WorkflowError(
      "invalid-argument",
      "The purge reason cannot exceed 1000 characters.",
    );
  }
  const expectedConfirmation = `DELETE ${sourceDocumentId}`;
  if (command.payload.confirmation !== expectedConfirmation) {
    throw new WorkflowError(
      "invalid-argument",
      `Type ${expectedConfirmation} to confirm permanent removal.`,
      {reasonCode: "pilot-record-purge-confirmation-mismatch"},
    );
  }

  const sourcePath = `${sourceCollection}/${sourceDocumentId}`;
  const source = await tx.get(sourcePath);
  if (!source.exists || source.data == null) {
    throw new WorkflowError(
      "not-found",
      "The record selected for permanent removal was not found.",
      {reasonCode: "pilot-record-purge-source-missing"},
    );
  }
  const version = intValue(source.data.version, "source.version", 1);
  if (version !== command.expectedVersion) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "The record changed before permanent removal.",
      {reasonCode: "pilot-record-purge-version-conflict", actualVersion: version},
    );
  }
  if (source.data.isDeleted !== true || source.data.deletedAt == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Only an already-deleted record can be permanently removed.",
      {reasonCode: "pilot-record-purge-soft-delete-required"},
    );
  }
  if (source.data._globalPullServerUpdatedAt == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Wait for the server deletion stamp before permanent removal.",
      {reasonCode: "pilot-record-purge-server-stamp-required"},
    );
  }

  await requireNoDependencies(args, sourceCollection, sourceDocumentId);

  const receiptId = pilotPurgeReceiptId(sourceCollection, sourceDocumentId);
  const receiptPath = `${PILOT_PURGE_RECEIPT_COLLECTION}/${receiptId}`;
  const existingReceipt = await tx.get(receiptPath);
  if (existingReceipt.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "A permanent-removal receipt already exists for this record.",
      {reasonCode: "pilot-record-purge-receipt-already-exists"},
    );
  }

  const sourceDigest = pilotPurgeSourceDigest(source.data);
  tx.create(receiptPath, {
    schemaVersion: PILOT_PURGE_RECEIPT_SCHEMA_VERSION,
    sourceCollection,
    sourceDocumentId,
    sourcePath,
    sourceVersion: version,
    sourceDigest,
    purgedAt: iso(context.serverNow),
    purgedByUid: context.actor.uid,
    purgedByName: context.actor.name,
    reason,
    commandId: command.commandId,
  });
  tx.delete(sourcePath);

  return {
    resultKey: "pilot-record-permanently-removed",
    aggregateVersion: version,
    result: {
      collectionId: sourceCollection,
      documentId: sourceDocumentId,
      purgeReceiptId: receiptId,
      sourceDigest,
    },
  };
};

interface PurgeReceiptSnapshotLike {
  exists: boolean;
  data(): {[key: string]: unknown} | undefined;
}

interface PurgeReceiptDocumentLike {
  get(): Promise<PurgeReceiptSnapshotLike>;
}

export interface PilotPurgeReceiptFirestoreLike {
  doc(path: string): PurgeReceiptDocumentLike;
}

const timestampIsPresent = (value: unknown): boolean => {
  if (typeof value === "string") return Number.isFinite(Date.parse(value));
  if (value == null || typeof value !== "object") return false;
  return typeof (value as {toDate?: unknown}).toDate === "function";
};

export async function isAuthorizedPilotRecordPurge(args: {
  db: PilotPurgeReceiptFirestoreLike;
  collectionId: string;
  documentId: string;
  before: {[key: string]: unknown};
}): Promise<boolean> {
  if (!ALLOWED_COLLECTION_SET.has(args.collectionId)) return false;
  const id = pilotPurgeReceiptId(args.collectionId, args.documentId);
  const receipt = await args.db.doc(
    `${PILOT_PURGE_RECEIPT_COLLECTION}/${id}`,
  ).get();
  const data = receipt.exists ? receipt.data() : undefined;
  if (data == null) return false;
  const keys = Object.keys(data).sort().join(",");
  if (keys !== [
    "commandId", "purgedAt", "purgedByName", "purgedByUid", "reason",
    "schemaVersion", "sourceCollection", "sourceDigest", "sourceDocumentId",
    "sourcePath", "sourceVersion",
  ].sort().join(",")) return false;
  return data.schemaVersion === PILOT_PURGE_RECEIPT_SCHEMA_VERSION &&
    data.sourceCollection === args.collectionId &&
    data.sourceDocumentId === args.documentId &&
    data.sourcePath === `${args.collectionId}/${args.documentId}` &&
    data.sourceVersion === args.before.version &&
    data.sourceDigest === pilotPurgeSourceDigest(args.before) &&
    typeof data.commandId === "string" && data.commandId.trim().length > 0 &&
    typeof data.purgedByUid === "string" && data.purgedByUid.trim().length > 0 &&
    typeof data.purgedByName === "string" && data.purgedByName.trim().length > 0 &&
    typeof data.reason === "string" && data.reason.trim().length > 0 &&
    timestampIsPresent(data.purgedAt);
}

export async function verifyPilotPurgeReplay(args: {
  command: WorkflowCommand;
  actorUid: string;
  receipt: WorkflowCommandReceipt;
  receiptReader: (path: string) => Promise<{exists: boolean; data: JsonMap | null}>;
}): Promise<void> {
  if (args.command.commandType !== "purgePilotBusinessRecord") return;
  const sourceCollection = args.receipt.result.collectionId;
  const sourceDocumentId = args.receipt.result.documentId;
  const receiptId = args.receipt.result.purgeReceiptId;
  const sourceDigest = args.receipt.result.sourceDigest;
  if (typeof sourceCollection !== "string" ||
      !ALLOWED_COLLECTION_SET.has(sourceCollection) ||
      sourceCollection !== args.command.payload.collectionId ||
      typeof sourceDocumentId !== "string" ||
      sourceDocumentId !== args.command.aggregateId ||
      sourceDocumentId !== args.command.payload.documentId ||
      typeof receiptId !== "string" ||
      receiptId !== pilotPurgeReceiptId(sourceCollection, sourceDocumentId) ||
      typeof sourceDigest !== "string" ||
      !/^[0-9a-f]{64}$/.test(sourceDigest)) {
    throw new WorkflowError(
      "failed-precondition",
      "Purge replay evidence is malformed.",
      {reasonCode: "pilot-record-purge-replay-evidence-invalid"},
    );
  }
  const [evidence, source] = await Promise.all([
    args.receiptReader(`${PILOT_PURGE_RECEIPT_COLLECTION}/${receiptId}`),
    args.receiptReader(`${sourceCollection}/${sourceDocumentId}`),
  ]);
  if (!evidence.exists ||
      evidence.data?.schemaVersion !== PILOT_PURGE_RECEIPT_SCHEMA_VERSION ||
      evidence.data?.sourceCollection !== sourceCollection ||
      evidence.data?.sourceDocumentId !== sourceDocumentId ||
      evidence.data?.sourcePath !== `${sourceCollection}/${sourceDocumentId}` ||
      evidence.data?.sourceVersion !== args.receipt.aggregateVersion ||
      evidence.data?.sourceDigest !== sourceDigest ||
      evidence.data?.purgedByUid !== args.actorUid ||
      evidence.data?.commandId !== args.receipt.commandId ||
      source.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Purge replay evidence is missing or inconsistent.",
      {reasonCode: "pilot-record-purge-replay-evidence-invalid"},
    );
  }
}
