import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {
  validateQualityMonitoringRecord,
} from "./qualityMutation";
import {UserAuthorityJsonMap} from "./userAuthority";

const PAGE_SIZE = 200;
const MAX_PER_SWEEP = 2000;
const MAX_SCAN_PER_SWEEP = 10000;
const MAX_REJECTED_PER_SWEEP = 200;
const TRANSACTION_CONCURRENCY = 20;

export interface QualityMonitoringRetentionResult {
  readonly candidates: number;
  readonly archived: number;
  readonly rejected: number;
  readonly capped: boolean;
}

const timestampMillis = (value: unknown): number | null => {
  if (value instanceof Date) return value.valueOf();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  if (value == null || typeof value !== "object") return null;
  const timestamp = value as {
    toMillis?: () => number;
    toDate?: () => Date;
    seconds?: unknown;
    nanoseconds?: unknown;
  };
  if (typeof timestamp.toMillis === "function") return timestamp.toMillis();
  if (typeof timestamp.toDate === "function") return timestamp.toDate().valueOf();
  if (Number.isSafeInteger(timestamp.seconds) &&
      Number.isSafeInteger(timestamp.nanoseconds)) {
    return (timestamp.seconds as number) * 1000 +
      (timestamp.nanoseconds as number) / 1_000_000;
  }
  return null;
};

export const planQualityMonitoringArchive = (args: {
  readonly data: UserAuthorityJsonMap;
  readonly requestId: string;
  readonly now: Date;
  readonly timestampFromDate?: (date: Date) => unknown;
}): UserAuthorityJsonMap | null => {
  const current = validateQualityMonitoringRecord(args.data, args.requestId);
  if (current.status !== "closed" || current.visibilityState !== "recent") {
    return null;
  }
  const visibleUntilMillis = timestampMillis(current.visibleUntil);
  if (visibleUntilMillis == null || visibleUntilMillis > args.now.valueOf()) {
    return null;
  }
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);
  return {
    schemaVersion: current.schemaVersion === 1 ? 2 : current.schemaVersion,
    visibilityState: "archived",
    visibleUntil: null,
    archivedAt: timestampFromDate(args.now),
  };
};

type ArchiveCursor = {id: string; value?: unknown} | null;
const checkpointPath = "quality-monitoring-archive-v1";

const fetchDue = async (
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp,
): Promise<{refs: admin.firestore.DocumentReference[]; capped: boolean;
  generation: number; cursors: {due: ArchiveCursor; legacy: ArchiveCursor}}> => {
  const checkpoint = (await db.collection("_maintenance_cursors").doc(checkpointPath).get()).data();
  const generation = checkpoint?.generation ?? 0;
  if (!Number.isSafeInteger(generation) || generation < 0) throw new Error("invalid-monitoring-retention-checkpoint");
  const refs: admin.firestore.DocumentReference[] = [];
  const seen = new Set<string>();
  let capped = false;
  const cursors: {due: ArchiveCursor; legacy: ArchiveCursor} = {due: null, legacy: null};
  // Each population gets its own budget and durable cursor. A poison prefix
  // cannot consume every subsequent run or starve the legacy population.
  for (const lane of ["due", "legacy"] as const) {
    let cursor: ArchiveCursor = checkpoint?.[lane] ?? null;
    if (cursor != null && (typeof cursor.id !== "string" || cursor.id.includes("/"))) {
      throw new Error("invalid-monitoring-retention-cursor");
    }
    let scanned = 0;
    let eligible = 0;
    let rejected = 0;
    const scanBudget = MAX_SCAN_PER_SWEEP / 2;
    const writeBudget = MAX_PER_SWEEP / 2;
    while (scanned < scanBudget && eligible < writeBudget) {
      const count = Math.min(PAGE_SIZE, scanBudget - scanned, writeBudget - eligible);
      let query: admin.firestore.Query = lane === "due" ?
        db.collection("quality_monitoring_requests").where("visibleUntil", "<=", now)
          .orderBy("visibleUntil").orderBy(admin.firestore.FieldPath.documentId()) :
        db.collection("quality_monitoring_requests").where("schemaVersion", "==", 1)
          .orderBy(admin.firestore.FieldPath.documentId());
      if (cursor != null) query = lane === "due" ?
        query.startAfter(cursor.value, cursor.id) : query.startAfter(cursor.id);
      const page = await query.limit(count).get();
      for (const snapshot of page.docs) {
        scanned += 1;
        cursor = lane === "due" ? {id: snapshot.id, value: snapshot.data().visibleUntil} : {id: snapshot.id};
        if (seen.has(snapshot.ref.path)) continue;
        seen.add(snapshot.ref.path);
        try {
          if (planQualityMonitoringArchive({data: snapshot.data(), requestId: snapshot.id,
            now: now.toDate()}) == null) continue;
          refs.push(snapshot.ref);
          eligible += 1;
        } catch (_) {
          if (rejected < MAX_REJECTED_PER_SWEEP / 2) {
            refs.push(snapshot.ref);
            rejected += 1;
          }
        }
      }
      if (page.size < count) { cursor = null; break; }
    }
    if (cursor != null) capped = true;
    cursors[lane] = cursor;
  }
  return {refs, capped, generation, cursors};
};

const processCandidate = async (
  db: admin.firestore.Firestore,
  ref: admin.firestore.DocumentReference,
  now: admin.firestore.Timestamp,
): Promise<"archived" | "unchanged" | "rejected"> => {
  try {
    return await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot.exists) return "unchanged";
      const patch = planQualityMonitoringArchive({
        data: snapshot.data() ?? {},
        requestId: snapshot.id,
        now: now.toDate(),
        timestampFromDate: admin.firestore.Timestamp.fromDate,
      });
      if (patch == null) return "unchanged";
      tx.update(ref, patch);
      return "archived";
    });
  } catch (error) {
    logger.error("Quality monitoring retention rejected a due record", {
      requestId: ref.id,
      error,
    });
    return "rejected";
  }
};

export const archiveDueQualityMonitoringRequests = async (args: {
  readonly db: admin.firestore.Firestore;
  readonly now: admin.firestore.Timestamp;
}): Promise<QualityMonitoringRetentionResult> => {
  const fetched = await fetchDue(args.db, args.now);
  const refs = fetched.refs;
  let next = 0;
  let archived = 0;
  let rejected = 0;
  const runners = Array.from(
    {length: Math.min(TRANSACTION_CONCURRENCY, refs.length)},
    async () => {
      while (true) {
        const index = next;
        next += 1;
        if (index >= refs.length) return;
        const outcome = await processCandidate(args.db, refs[index], args.now);
        if (outcome === "archived") archived += 1;
        if (outcome === "rejected") rejected += 1;
      }
    },
  );
  await Promise.all(runners);
  // Advance only after processing. A crashed worker retries its range; an
  // older concurrent worker cannot overwrite a newer worker's checkpoint.
  await args.db.runTransaction(async (tx) => {
    const ref = args.db.collection("_maintenance_cursors").doc(checkpointPath);
    const current = await tx.get(ref);
    if ((current.data()?.generation ?? 0) !== fetched.generation) return;
    tx.set(ref, {schemaVersion: 1, generation: fetched.generation + 1,
      ...fetched.cursors, updatedAt: args.now});
  });
  return {
    candidates: refs.length,
    archived,
    rejected,
    capped: fetched.capped,
  };
};
