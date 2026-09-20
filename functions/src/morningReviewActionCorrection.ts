import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import type {MorningReviewFirestoreLike} from "./morningReviewMutation";
import {canonicalApprovedUserAuthority} from "./userAuthority";

type MapValue = {[key: string]: unknown};
type Tx = Parameters<Parameters<MorningReviewFirestoreLike["runTransaction"]>[0]>[0];
export type MorningReviewActionCorrection = {
  kind: "cancel" | "reassign" | "reopen";
  assigneeUid: string | null; assigneeRole: string | null;
};
const ROLES = new Set(["admin", "si", "contractSupervisor", "shiftSupervisor",
  "seniorElectrical", "seniorMechanical", "seniorInstrumentation", "seniorRefractory", "refractory", "operations"]);

export function parseMorningReviewActionCorrection(value: unknown): MorningReviewActionCorrection {
  const fail = (): never => { throw new AssetHierarchyMutationError("invalid-argument", "Choose cancel, reassign or reopen; reassignment requires exactly one approved user or canonical role."); };
  if (value == null || typeof value !== "object" || Array.isArray(value)) return fail();
  const map = value as MapValue;
  if (Object.keys(map).some((key) => !["kind", "assigneeUid", "assigneeRole"].includes(key)) ||
      !["cancel", "reassign", "reopen"].includes(String(map.kind))) return fail();
  const uid = map.assigneeUid ?? null; const role = map.assigneeRole ?? null;
  if (uid != null && (typeof uid !== "string" || uid.trim() !== uid || uid.length === 0 || uid.length > 128 || uid.includes("/"))) return fail();
  if (role != null && (typeof role !== "string" || !ROLES.has(role))) return fail();
  if (map.kind === "reassign" ? (uid == null) === (role == null) : uid != null || role != null) return fail();
  return {kind: map.kind as MorningReviewActionCorrection["kind"], assigneeUid: uid as string | null, assigneeRole: role as string | null};
}

/** Corrections change the current action, never the previously frozen minutes.
 * The before/after evidence and actor are committed atomically with the change. */
export async function correctMorningReviewAction(args: {
  db: MorningReviewFirestoreLike; tx: Tx; actionId: string; sessionId: string;
  expectedVersion: number; requestId: string; reason: string;
  correction: MorningReviewActionCorrection; actorUid: string; actorName: string;
  roles: ReadonlySet<string>; at: unknown; expiresAt: unknown;
}): Promise<{status: string; version: number}> {
  if (!args.roles.has("admin") && !args.roles.has("si")) {
    throw new AssetHierarchyMutationError("permission-denied", "Only Admin or SI can correct a Morning Review action.");
  }
  const ref = args.db.collection("morning_review_actions").doc(args.actionId);
  const snapshot = await args.tx.get(ref);
  if (!("exists" in snapshot) || !snapshot.exists) throw new AssetHierarchyMutationError("not-found", "The action is no longer available for correction.");
  const before = snapshot.data() ?? {};
  if (before.schemaVersion !== 1 || before.actionId !== args.actionId || before.sessionId !== args.sessionId ||
      !Number.isSafeInteger(before.version) || before.version !== args.expectedVersion) {
    throw new AssetHierarchyMutationError("aborted", "The action changed. Read the latest action before correcting it.");
  }
  const {kind, assigneeUid, assigneeRole} = args.correction;
  const active = before.status === "open" || before.status === "accepted";
  if (kind === "reopen" ? !["completed", "cancelled"].includes(String(before.status)) : !active) {
    throw new AssetHierarchyMutationError("failed-precondition", "This correction does not match the action’s current state.");
  }
  let assigneeName: string | null = null;
  if (kind === "reassign" && assigneeUid != null) {
    const user = await args.tx.get(args.db.collection("users").doc(assigneeUid));
    const authority = "exists" in user && user.exists ? canonicalApprovedUserAuthority(user.data()) : null;
    if (authority == null || typeof authority.data.name !== "string" || !authority.data.name.trim() || authority.data.name.trim().length > 160) {
      throw new AssetHierarchyMutationError("failed-precondition", "The selected assignee is not currently approved with a valid name.");
    }
    assigneeName = authority.data.name.trim();
  }
  const auditRef = args.db.collection("morning_review_corrections").doc(args.requestId);
  const prior = await args.tx.get(auditRef);
  if ("exists" in prior && prior.exists) throw new AssetHierarchyMutationError("data-loss", "Correction history exists without its acceptance receipt.");
  const status = kind === "cancel" ? "cancelled" : "open";
  const version = args.expectedVersion + 1;
  const after = {...before, status, version,
    ...(kind === "reassign" ? {assigneeUid, assigneeRole, assigneeName} : {}),
    acceptedAt: null, acceptedByUid: null, acceptedByName: null,
    completedAt: null, completedByUid: null, completedByName: null, completionNote: null,
    cancellation: kind === "cancel" ? {at: args.at, actorUid: args.actorUid, actorName: args.actorName, reason: args.reason} : null,
    updatedAt: args.at, updatedByUid: args.actorUid, updatedByName: args.actorName,
    expiresAt: kind === "cancel" ? args.expiresAt : null, lastMutationId: args.requestId};
  args.tx.set(auditRef, {schemaVersion: 1, requestId: args.requestId, entityType: "action", entityId: args.actionId,
    sessionId: args.sessionId, kind, reason: args.reason, actorUid: args.actorUid, actorName: args.actorName,
    correctedAt: args.at, before, after});
  args.tx.set(ref, after);
  args.tx.set(args.db.collection("morning_review_action_history").doc(args.actionId), after);
  return {status, version};
}
