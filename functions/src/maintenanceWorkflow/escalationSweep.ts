import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {FUNCTION_RUNTIME_SERVICE_ACCOUNTS} from "../functionFleetRuntimeIdentity";
import {eventPlan} from "./events";
import {
  escalationEventId,
  escalationEventType,
  nextEscalationAtMillis,
  nextEscalationTier,
} from "./escalationPolicy";
import {Actor, LaneKey} from "./types";

const REGION = "asia-south1";
const PAGE_SIZE = 200;
const MAX_PER_QUERY_PER_SWEEP = 1000;
const TRANSACTION_CONCURRENCY = 20;

const escalationActor: Actor = {
  uid: "system:maintenance-workflow-escalation",
  name: "Maintenance Workflow Escalation",
  roles: new Set(["admin", "si"]),
};

type SourceKind = "laneAcknowledgement" | "complianceAcknowledgement" | "complianceCompletion";

interface EscalationCandidate {
  readonly ref: admin.firestore.DocumentReference;
  readonly kind: SourceKind;
}

const laneKeyOrNull = (value: unknown): LaneKey | null => {
  if (
    value === "elec" || value === "mech" || value === "inst" ||
    value === "oprn" || value === "emd" || value === "red" ||
    value === "shared"
  ) {
    return value;
  }
  return null;
};

const sourceIsStillEligible = (
  kind: SourceKind,
  data: admin.firestore.DocumentData,
  now: admin.firestore.Timestamp,
): boolean => {
  const nextAt = data.nextEscalationAt;
  if (!(nextAt instanceof admin.firestore.Timestamp) || nextAt.toMillis() > now.toMillis()) {
    return false;
  }
  if (kind === "laneAcknowledgement") return data.status === "pending";
  if (kind === "complianceAcknowledgement") return data.status === "raised";
  return data.status === "acknowledged" || data.status === "complied";
};

const identity = (
  ref: admin.firestore.DocumentReference,
  data: admin.firestore.DocumentData,
): {aggregateId: string; laneKey: LaneKey; eventType: string} | null => {
  const isLane = ref.parent.id === "job_lanes";
  const aggregateId = String(
    isLane ? data.workflowId ?? "" : data.linkedWorkflowId ?? "",
  ).trim();
  const laneKey = laneKeyOrNull(isLane ? data.laneKey : data.targetLaneKey);
  if (aggregateId.length === 0 || laneKey == null) {
    logger.warn("Skipping escalation with incomplete workflow identity", {
      collectionId: ref.parent.id,
      documentId: ref.id,
      aggregateId,
      laneKey,
    });
    return null;
  }
  return {
    aggregateId,
    laneKey,
    eventType: escalationEventType(ref.parent.id, String(data.status ?? "")),
  };
};

const fetchEligible = async (
  query: admin.firestore.Query,
  kind: SourceKind,
): Promise<EscalationCandidate[]> => {
  const candidates: EscalationCandidate[] = [];
  let cursor: admin.firestore.QueryDocumentSnapshot | null = null;
  while (candidates.length < MAX_PER_QUERY_PER_SWEEP) {
    let pageQuery = query
      .orderBy("nextEscalationAt")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(Math.min(PAGE_SIZE, MAX_PER_QUERY_PER_SWEEP - candidates.length));
    if (cursor != null) pageQuery = pageQuery.startAfter(cursor);
    const page = await pageQuery.get();
    candidates.push(...page.docs.map((snapshot) => ({ref: snapshot.ref, kind})));
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return candidates;
};

const processCandidate = async (
  db: admin.firestore.Firestore,
  candidate: EscalationCandidate,
  now: admin.firestore.Timestamp,
): Promise<boolean> => db.runTransaction(async (tx) => {
  // Re-read inside the transaction so a lane/compliance row that was closed,
  // acknowledged or otherwise changed after the query cannot be escalated from
  // a stale scheduler snapshot.
  const source = await tx.get(candidate.ref);
  if (!source.exists) return false;
  const data = source.data() ?? {};
  if (!sourceIsStillEligible(candidate.kind, data, now)) return false;

  const last = data.lastEscalatedAt;
  const nextTier = nextEscalationTier({
    currentTier: Number(data.escalationTier ?? 0),
    lastEscalatedAtMillis:
      last instanceof admin.firestore.Timestamp ? last.toMillis() : null,
    nowMillis: now.toMillis(),
  });
  if (nextTier == null) return false;

  const resolvedIdentity = identity(candidate.ref, data);
  if (resolvedIdentity == null) return false;
  const eventId = escalationEventId({
    collectionId: candidate.ref.parent.id,
    documentId: candidate.ref.id,
    tier: nextTier,
  });
  const event = eventPlan({
    aggregateId: resolvedIdentity.aggregateId,
    eventId,
    eventType: resolvedIdentity.eventType,
    actor: escalationActor,
    at: now.toDate(),
    commandId: eventId,
    laneKey: resolvedIdentity.laneKey,
    payload: {
      sourceCollection: candidate.ref.parent.id,
      sourceDocumentId: candidate.ref.id,
      escalationTier: nextTier,
    },
  });
  const eventRef = db.doc(event.path);
  const existingEvent = await tx.get(eventRef);
  if (existingEvent.exists) return false;

  const nextAtMillis = nextEscalationAtMillis({nextTier, nowMillis: now.toMillis()});
  tx.update(candidate.ref, {
    escalationTier: nextTier,
    lastEscalatedAt: now,
    nextEscalationAt:
      nextAtMillis == null
        ? null
        : admin.firestore.Timestamp.fromMillis(nextAtMillis),
    updatedAt: now,
    version: Number(data.version ?? 0) + 1,
  });
  tx.create(eventRef, event.data);
  return true;
});

const runWithConcurrency = async <T>(
  items: readonly T[],
  limit: number,
  worker: (item: T) => Promise<boolean>,
): Promise<number> => {
  let next = 0;
  let changed = 0;
  const runners = Array.from({length: Math.min(limit, items.length)}, async () => {
    while (true) {
      const index = next;
      next += 1;
      if (index >= items.length) return;
      if (await worker(items[index])) changed += 1;
    }
  });
  await Promise.all(runners);
  return changed;
};

export const maintenanceWorkflowEscalationSweep = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 300,
    memory: "512MiB",
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.maintenanceWorkflowEscalationSweep,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const [lanes, complianceAck, complianceDue] = await Promise.all([
      fetchEligible(
        db.collection("job_lanes")
          .where("status", "==", "pending")
          .where("nextEscalationAt", "<=", now),
        "laneAcknowledgement",
      ),
      fetchEligible(
        db.collection("compliance_requests")
          .where("status", "==", "raised")
          .where("nextEscalationAt", "<=", now),
        "complianceAcknowledgement",
      ),
      fetchEligible(
        db.collection("compliance_requests")
          .where("status", "in", ["acknowledged", "complied"])
          .where("nextEscalationAt", "<=", now),
        "complianceCompletion",
      ),
    ]);

    const candidates = [...lanes, ...complianceAck, ...complianceDue];
    const changed = await runWithConcurrency(
      candidates,
      TRANSACTION_CONCURRENCY,
      (candidate) => processCandidate(db, candidate, now),
    );

    logger.info("maintenanceWorkflowEscalationSweep completed", {
      laneCandidates: lanes.length,
      complianceAckCandidates: complianceAck.length,
      complianceDueCandidates: complianceDue.length,
      candidateCount: candidates.length,
      changed,
      cappedQueries: {
        lanes: lanes.length >= MAX_PER_QUERY_PER_SWEEP,
        complianceAck: complianceAck.length >= MAX_PER_QUERY_PER_SWEEP,
        complianceDue: complianceDue.length >= MAX_PER_QUERY_PER_SWEEP,
      },
    });
  },
);
