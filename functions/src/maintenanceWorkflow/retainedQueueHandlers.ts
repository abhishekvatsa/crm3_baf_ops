import {createHash} from "crypto";
import {persistedInstantMillis} from "../persistedInstant";
import {stableJson} from "../stableJson";
import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {WorkflowTransaction} from "./store";
import {Actor, CommandInvocationContext, JsonMap, JsonValue, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {payloadFingerprint} from "./utils";

const COLLECTIONS = {
  upsertAbnormalityType: "abnormality_types",
  upsertLegacyJobTemplate: "job_templates",
  updateJobExecutionWork: "job_executions",
} as const;
const AUDIT_ENTITIES = {
  upsertAbnormalityType: "abnormality_type",
  upsertLegacyJobTemplate: "job_template",
  updateJobExecutionWork: "job_execution",
} as const;
export const isRetainedQueueCommand = (type: string): type is keyof typeof COLLECTIONS =>
  Object.prototype.hasOwnProperty.call(COLLECTIONS, type);
const fail = (message: string, code: "invalid-argument" | "permission-denied" | "failed-precondition" = "invalid-argument"): never => {
  throw new WorkflowError(code, message, {reasonCode: "retained-queue-mutation-invalid"});
};

/** Admission belongs before receipt lookup, including an already accepted ID. */
export function assertRetainedQueueAdmission(command: WorkflowCommand, context: CommandInvocationContext): void {
  if (!isRetainedQueueCommand(command.commandType)) return;
  if (context.originBoundProtocolVersion !== 2) {
    throw new WorkflowError("failed-precondition", "This mutation requires the origin-bound V2 endpoint.",
      {reasonCode: "retained-queue-v2-required"});
  }
  if (!context.projectId || command.payload.projectId !== context.projectId) {
    throw new WorkflowError("permission-denied", "The saved mutation belongs to another project.",
      {reasonCode: "retained-queue-project-mismatch"});
  }
  if (Object.keys(command.payload).sort().join(",") !== "projectId,record") {
    fail("The retained mutation payload must contain only projectId and record.");
  }
}

const COMMON = "firestoreId version createdAt updatedAt isDeleted deletedAt deletedByUid deletedByName deleteReason";
const TYPE = `${COMMON} code title description category severity applicableAssetTypes suggestsReannealing isActive createdByUid createdByName lastEditedByUid lastEditedByName`.split(" ");
const TEMPLATE = `${COMMON} jobName description applicableAssetType assignedAgencies component subsystem hierarchyPath assetHierarchyRefJson fields fieldsJson createdByUid createdByName isActive isDeprecated metadataJson`.split(" ");
const EXECUTION = `${COMMON} templateFirestoreId templateName templatePackageId templateVersionId templateVersionNumber templateVersionLabel templateContentHash templatePackageCode assetType assetNumber isCompleted isCancelled cancelledAt cancelledByUid cancelledByName cancellationReason assignedByUid assignedByName assignedAgencies workflowSchemaVersion laneSetVersion laneSetFinalizedAt laneSetFinalizedByUid laneSetFinalizedByName laneMappingReview parentExecutionFirestoreId spawnedRedExecutionFirestoreId redAnswerJson completedByUid completedByName remarks teamsInvolved chargeNoAtEvent responsesJson actionsJson metadataJson completedAt`.split(" ");
const WORK = new Set("remarks teamsInvolved responsesJson actionsJson metadataJson updatedAt version".split(" "));
const ASSETS = ["base", "furnace", "forceCooler", "innerCover", "governedCustom"];
type Mutable = {[key: string]: JsonValue | undefined};
const object = (value: unknown): value is JsonMap => value != null && typeof value === "object" && !Array.isArray(value);
function text(value: unknown, field: string, limit: number, optional = false): void {
  if (optional && value == null) return;
  if (typeof value !== "string" || !value.trim() || value.length > limit) fail(`${field} is invalid.`);
}
function strings(value: unknown, field: string): void {
  if (!Array.isArray(value) || value.length > 100 || value.some((item) => typeof item !== "string" || !item.trim() || item.length > 500)) fail(`${field} is invalid.`);
}
function choice(value: unknown, field: string, allowed: string[]): void {
  if (typeof value !== "string" || !allowed.includes(value)) fail(`${field} is invalid.`);
}
function json(value: unknown, field: string, array = false, optional = false): unknown {
  if (optional && value == null) return null;
  if (typeof value !== "string" || value.length > 180000) return fail(`${field} is invalid.`);
  let parsed: unknown;
  try { parsed = JSON.parse(value); } catch { return fail(`${field} is malformed JSON.`); }
  if (array ? !Array.isArray(parsed) || parsed.some((item) => !object(item)) : !object(parsed)) fail(`${field} has invalid structure.`);
  return parsed;
}

/** Canonical microsecond wire is stable through native receipt persistence.
 * Legacy zone-free persisted strings mean India plant time, never host time. */
export function retainedQueueInstant(value: unknown): string {
  const millis = persistedInstantMillis(value);
  if (!Number.isFinite(millis)) return fail("A retained mutation timestamp is invalid.");
  let micros = 0;
  if (typeof value === "string") {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(?:Z|([+-])(\d{2}):(\d{2}))?$/.exec(value);
    if (!match) return fail("A retained mutation timestamp has unsupported precision or format.");
    const [year, month, day, hour, minute, second] = match.slice(1, 7).map(Number);
    const calendar = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
    if (year < 100 || calendar.getUTCFullYear() !== year || calendar.getUTCMonth() !== month - 1 ||
      calendar.getUTCDate() !== day || hour > 23 || minute > 59 || second > 59 ||
      Number(match[9] ?? 0) > 23 || Number(match[10] ?? 0) > 59) return fail("A retained mutation calendar date is invalid.");
    micros = Number((match[7] ?? "").padEnd(6, "0").slice(3));
  } else if (value != null && typeof value === "object" && !(value instanceof Date)) {
    const stamp = value as Record<string, unknown>;
    const nanos = stamp.nanoseconds ?? stamp._nanoseconds;
    if (!Number.isSafeInteger(nanos) || (nanos as number) % 1000 !== 0) return fail("Submicrosecond evidence requires review.");
    micros = Math.floor((nanos as number) / 1000) % 1000;
  }
  return new Date(Math.floor(millis)).toISOString().replace(/(\.\d{3})Z$/, `$1${String(micros).padStart(3, "0")}Z`);
}
function canonical(value: unknown, key = "", depth = 0): JsonValue {
  if (value == null) return null;
  if (depth === 1 && (key.endsWith("At") || key.endsWith("Since"))) return retainedQueueInstant(value);
  if (Array.isArray(value)) return value.map((item) => canonical(item, "", depth + 1));
  if (object(value)) return Object.fromEntries(Object.entries(value)
    .filter(([field]) => depth !== 0 || !field.startsWith("_globalPull"))
    .map(([field, item]) => [field, canonical(item, field, depth + 1)]));
  if (typeof value === "string" || typeof value === "boolean" || typeof value === "number" && Number.isFinite(value)) return value;
  return fail("Mutation evidence must be JSON-safe.");
}
function record(raw: unknown, fields: string[], command: WorkflowCommand): Mutable {
  if (!object(raw) || Object.keys(raw).some((field) => !fields.includes(field)) ||
      Buffer.byteLength(JSON.stringify(raw), "utf8") > 200000) return fail("Mutation record fields or size are invalid.");
  const result = canonical(raw) as Mutable;
  if (result.firestoreId !== command.aggregateId || result.version !== command.expectedVersion + 1 || !Number.isSafeInteger(result.version) ||
      typeof result.isDeleted !== "boolean") fail("Mutation identity or next version is invalid.");
  const created = retainedQueueInstant(result.createdAt), updated = retainedQueueInstant(result.updatedAt);
  if (updated < created || result.deletedAt != null && (result.deletedAt < created || result.deletedAt > updated)) fail("Mutation timestamps are inconsistent.");
  if (result.isDeleted) {
    retainedQueueInstant(result.deletedAt);
    text(result.deletedByUid, "deletedByUid", 512);
  } else if (["deletedAt", "deletedByUid", "deletedByName", "deleteReason"].some((field) => result[field] != null)) fail("Active record contains deletion evidence.");
  for (const field of ["deletedByName", "deleteReason"]) text(result[field], field, 2000, true);
  return result;
}
function validateType(data: Mutable, actor: Actor, before: JsonMap | null): void {
  text(data.code, "code", 160); text(data.title, "title", 500); text(data.description, "description", 4000, true);
  choice(data.category, "category", ["process", "equipment", "resultQuality", "reannealing", "other"]);
  choice(data.severity, "severity", ["low", "medium", "high", "critical"]);
  strings(data.applicableAssetTypes, "applicableAssetTypes");
  const assets = data.applicableAssetTypes as string[];
  if (assets.length > 5 || new Set(assets).size !== assets.length || assets.some((asset) => !ASSETS.includes(asset))) fail("Invalid applicable asset types.");
  if (typeof data.suggestsReannealing !== "boolean" || typeof data.isActive !== "boolean" || data.isDeleted && data.isActive) fail("Invalid catalogue state.");
  text(data.createdByUid, "createdByUid", 512);
  for (const field of ["createdByName", "lastEditedByName"]) text(data[field], field, 500, true);
  if (data.lastEditedByUid !== actor.uid || before == null && data.createdByUid !== actor.uid) fail("Catalogue mutation actor does not match the origin.", "permission-denied");
}
function validateTemplate(data: Mutable, actor: Actor, before: JsonMap | null): void {
  text(data.jobName, "jobName", 500); text(data.description, "description", 20000, true);
  choice(data.applicableAssetType, "applicableAssetType", ASSETS);
  strings(data.assignedAgencies, "assignedAgencies");
  if (data.hierarchyPath != null) strings(data.hierarchyPath, "hierarchyPath");
  for (const field of ["component", "subsystem", "createdByUid", "createdByName"]) text(data[field], field, 500, true);
  const fields = json(data.fieldsJson, "fieldsJson", true);
  if (!Array.isArray(data.fields) || stableJson(fields) !== stableJson(data.fields)) fail("Template field representations disagree.");
  json(data.metadataJson, "metadataJson", false, true);
  json(data.assetHierarchyRefJson, "assetHierarchyRefJson", false, true);
  if (typeof data.isActive !== "boolean" || typeof data.isDeprecated !== "boolean") fail("Invalid template state.");
  if (before == null && data.createdByUid !== actor.uid) fail("Template creator must be the origin actor.", "permission-denied");
  if (data.isDeleted && !actor.roles.has("admin")) fail("Only Admin may write a deleted template.", "permission-denied");
  if (before?.isDeleted === true && data.isDeleted !== true) fail("Deleted legacy templates cannot be restored.", "failed-precondition");
}
function validateExecution(data: Mutable, before: JsonMap): void {
  if (before.isDeleted !== false || before.isCompleted !== false || before.isCancelled === true ||
      data.isDeleted !== false || data.isCompleted !== false || data.isCancelled === true) fail("Only an existing open execution may receive work edits.", "failed-precondition");
  strings(data.teamsInvolved, "teamsInvolved"); text(data.remarks, "remarks", 20000, true);
  json(data.responsesJson, "responsesJson", true); json(data.actionsJson, "actionsJson", true);
  json(data.metadataJson, "metadataJson", false, true);
  const defaults: JsonMap = {assignedAgencies: [], isCancelled: false, workflowSchemaVersion: 0,
    laneSetVersion: 0, laneMappingReview: false};
  for (const field of EXECUTION.filter((field) => !WORK.has(field))) {
    if (stableJson(data[field] ?? defaults[field] ?? null) !== stableJson(before[field] ?? defaults[field] ?? null)) {
      fail(`Execution ${field} is pinned and cannot be changed by a work command.`, "permission-denied");
    }
  }
}

const auditPath = (id: string): string => `audit_logs/server_cf01_${id}`;
const apply: CommandHandler = async ({tx, command, context}) => {
  if (!isRetainedQueueCommand(command.commandType)) return fail("Unsupported retained mutation.");
  const collection = COLLECTIONS[command.commandType], path = `${collection}/${command.aggregateId}`;
  const existing = await tx.get(path);
  const before = existing.data == null ? null : canonical(existing.data) as JsonMap;
  const purge = await tx.get(`pilot_record_purge_manifests/purge_${createHash("sha256").update(path).digest("hex")}`);
  if (purge.exists) fail("A permanently removed identity cannot be recreated.", "failed-precondition");
  if (existing.exists ? before?.version !== command.expectedVersion : command.expectedVersion !== 0) {
    throw new WorkflowError("workflow-version-conflict", "The saved mutation is based on a different record version.",
      {expectedVersion: command.expectedVersion, currentVersion: before?.version ?? 0});
  }
  const fields = collection === "abnormality_types" ? TYPE : collection === "job_templates" ? TEMPLATE : EXECUTION;
  const candidate = record(command.payload.record, fields, command);
  if (before != null) {
    if (candidate.createdAt !== before.createdAt || (collection !== "job_executions" &&
      ((candidate.createdByUid ?? null) !== (before.createdByUid ?? null) ||
       (candidate.createdByName ?? null) !== (before.createdByName ?? null)))) fail("Original creation evidence cannot be changed.", "permission-denied");
    if ((candidate.updatedAt as string) < (before.updatedAt as string)) fail("A mutation cannot move the record clock backwards.");
  }
  if (candidate.isDeleted && candidate.deletedByUid !== context.actor.uid) fail("Deletion actor must match the origin.", "permission-denied");
  if (collection === "abnormality_types") validateType(candidate, context.actor, before);
  else if (collection === "job_templates") {
    if (before == null && candidate.isDeleted) fail("A new template cannot be deleted.");
    validateTemplate(candidate, context.actor, before);
  } else {
    if (before == null) fail("Execution work commands cannot create assignments.", "failed-precondition");
    validateExecution(candidate, before!);
  }
  const accepted: Mutable = {...(before ?? {}), ...candidate};
  if (collection === "job_executions") {
    // Preserve native/original pinned fields on disk, including server fields.
    const update = Object.fromEntries([...WORK].map((key) => [key, candidate[key] ?? null]));
    tx.update(path, update);
  } else tx.set(path, candidate, true);
  tx.create(auditPath(command.commandId), {
    entityType: AUDIT_ENTITIES[command.commandType], entityId: command.aggregateId,
    action: candidate.isDeleted ? "delete" : before == null ? "create" : "update", severity: "low",
    performedByUid: context.actor.uid, performedByName: context.actor.name,
    timestamp: context.serverNow.toISOString(), commandId: command.commandId,
    projectId: command.payload.projectId, payloadFingerprint: payloadFingerprint(command as unknown as JsonMap),
    beforeJson: before == null ? null : stableJson(before), afterJson: stableJson(accepted),
    summary: "Applied retained actor-owned mutation",
  });
  return {resultKey: "retained-queue-mutation-applied", aggregateVersion: command.expectedVersion + 1,
    result: {collection, recordId: command.aggregateId, record: accepted}};
};
export const upsertAbnormalityType = apply;
export const upsertLegacyJobTemplate = apply;
export const updateJobExecutionWork = apply;

export async function verifyRetainedQueueReplay(tx: WorkflowTransaction, command: WorkflowCommand, actor: Actor, receipt: WorkflowCommandReceipt): Promise<void> {
  if (!isRetainedQueueCommand(command.commandType)) return;
  const audit = (await tx.get(auditPath(command.commandId))).data;
  const expectedAction = (command.payload.record as JsonMap).isDeleted ? "delete" :
    command.expectedVersion === 0 ? "create" : "update";
  if (receipt.resultKey !== "retained-queue-mutation-applied" || receipt.aggregateVersion !== command.expectedVersion + 1 ||
      receipt.result.collection !== COLLECTIONS[command.commandType] || receipt.result.recordId !== command.aggregateId ||
      !object(receipt.result.record) || audit == null || audit.performedByUid !== actor.uid ||
      audit.entityType !== AUDIT_ENTITIES[command.commandType] || audit.entityId !== command.aggregateId ||
      audit.severity !== "low" || audit.action !== expectedAction ||
      persistedInstantMillis(audit.timestamp) !== Date.parse(receipt.appliedAt) ||
      audit.commandId !== command.commandId || audit.projectId !== command.payload.projectId ||
      audit.payloadFingerprint !== payloadFingerprint(command as unknown as JsonMap) || audit.afterJson !== stableJson(receipt.result.record)) {
    fail("The accepted mutation receipt does not match its retained audit evidence.", "failed-precondition");
  }
}
