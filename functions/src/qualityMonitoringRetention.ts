import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {
  validateQualityMonitoringRecord,
} from "./qualityMutation";
import {UserAuthorityJsonMap} from "./userAuthority";

const PAGE_SIZE = 200;
const MAX_PER_SWEEP = 2000;
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
    visibilityState: "archived",
    visibleUntil: null,
    archivedAt: timestampFromDate(args.now),
  };
};

const fetchDue = async (
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp,
): Promise<admin.firestore.DocumentReference[]> => {
  const refs: admin.firestore.DocumentReference[] = [];
  let cursor: admin.firestore.QueryDocumentSnapshot | null = null;
  while (refs.length < MAX_PER_SWEEP) {
    let query = db.collection("quality_monitoring_requests")
      .where("visibleUntil", "<=", now)
      .orderBy("visibleUntil")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(Math.min(PAGE_SIZE, MAX_PER_SWEEP - refs.length));
    if (cursor != null) query = query.startAfter(cursor);
    const page = await query.get();
    refs.push(...page.docs.map((snapshot) => snapshot.ref));
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return refs;
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
  const refs = await fetchDue(args.db, args.now);
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
  return {
    candidates: refs.length,
    archived,
    rejected,
    capped: refs.length >= MAX_PER_SWEEP,
  };
};
