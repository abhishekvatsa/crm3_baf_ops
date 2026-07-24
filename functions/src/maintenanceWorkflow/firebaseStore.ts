import * as admin from "firebase-admin";
import {DocSnapshot, QueryFilter, WorkflowStore, WorkflowTransaction} from "./store";
import {JsonMap} from "./types";

const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;
const isTimestampField = (key: string): boolean =>
  key === "timestamp" || (key !== "appliedAt" && (key.endsWith("At") || key.endsWith("Since") || key.endsWith("DueAt")));

const isNativeFirestoreValue = (value: unknown): boolean =>
  value instanceof admin.firestore.Timestamp ||
  value instanceof admin.firestore.GeoPoint ||
  value instanceof admin.firestore.DocumentReference ||
  value instanceof admin.firestore.FieldValue ||
  value instanceof Uint8Array;

const toFirestoreValue = (value: unknown, key = ""): unknown => {
  // Firestore values read from an earlier transaction step must remain native.
  // Recursing into Timestamp/GeoPoint/DocumentReference/FieldValue instances
  // would turn them into ordinary maps and silently corrupt persisted types.
  if (isNativeFirestoreValue(value)) return value;
  if (value instanceof Date) return admin.firestore.Timestamp.fromDate(value);
  if (typeof value === "string" && isTimestampField(key) && ISO_INSTANT.test(value)) {
    return admin.firestore.Timestamp.fromDate(new Date(value));
  }
  if (Array.isArray(value)) return value.map((item) => toFirestoreValue(item));
  if (value != null && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [childKey, child] of Object.entries(value as Record<string, unknown>)) {
      result[childKey] = toFirestoreValue(child, childKey);
    }
    return result;
  }
  return value;
};

const toFirestoreData = (data: JsonMap): admin.firestore.DocumentData =>
  toFirestoreValue(data) as admin.firestore.DocumentData;

/**
 * Test-only visibility for the persistence boundary. Domain handlers keep ISO
 * strings so command receipts and deterministic unit fixtures remain JSON-safe;
 * this adapter is the authoritative point that converts lifecycle deadlines to
 * native Firestore Timestamp values before any create/set/update reaches the DB.
 */
export const workflowFirestoreDataForTest = (
  data: JsonMap,
): admin.firestore.DocumentData => toFirestoreData(data);

class FirebaseTransactionAdapter implements WorkflowTransaction {
  constructor(
    private readonly db: admin.firestore.Firestore,
    private readonly transaction: admin.firestore.Transaction,
  ) {}

  async get<T extends JsonMap = JsonMap>(path: string): Promise<DocSnapshot<T>> {
    const ref = this.db.doc(path);
    const snap = await this.transaction.get(ref);
    return {path, exists: snap.exists, data: snap.exists ? (snap.data() as T) : null};
  }

  async query<T extends JsonMap = JsonMap>(collection: string, filters: readonly QueryFilter[]): Promise<readonly DocSnapshot<T>[]> {
    let query: admin.firestore.Query = this.db.collection(collection);
    for (const filter of filters) query = query.where(filter.field, filter.op, filter.value);
    const snap = await this.transaction.get(query);
    return snap.docs.map((doc) => ({path: doc.ref.path, exists: true, data: doc.data() as T}));
  }

  create(path: string, data: JsonMap): void {
    this.transaction.create(this.db.doc(path), toFirestoreData(data));
  }

  set(path: string, data: JsonMap, merge = false): void {
    this.transaction.set(this.db.doc(path), toFirestoreData(data), merge ? {merge: true} : {});
  }

  update(path: string, data: JsonMap): void {
    this.transaction.update(this.db.doc(path), toFirestoreData(data) as admin.firestore.UpdateData<admin.firestore.DocumentData>);
  }
}

export class FirebaseWorkflowStore implements WorkflowStore {
  constructor(private readonly db: admin.firestore.Firestore) {}

  runTransaction<T>(work: (tx: WorkflowTransaction) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (transaction) => work(new FirebaseTransactionAdapter(this.db, transaction)));
  }
}
