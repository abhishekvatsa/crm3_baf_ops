import {DocSnapshot, QueryFilter, WorkflowStore, WorkflowTransaction} from "./store";
import {JsonMap} from "./types";

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const parentCollection = (path: string): string => path.split("/").slice(0, -1).join("/");

class MemoryTransaction implements WorkflowTransaction {
  readonly writes: Array<() => void> = [];
  private writesStarted = false;
  constructor(private readonly docs: Map<string, JsonMap>) {}

  private assertReadsStillAllowed(): void {
    if (this.writesStarted) {
      throw new Error("firestore-transaction-read-after-write");
    }
  }

  async get<T extends JsonMap = JsonMap>(path: string): Promise<DocSnapshot<T>> {
    this.assertReadsStillAllowed();
    const data = this.docs.get(path);
    return {path, exists: data != null, data: data == null ? null : clone(data as T)};
  }

  async query<T extends JsonMap = JsonMap>(collection: string, filters: readonly QueryFilter[]): Promise<readonly DocSnapshot<T>[]> {
    this.assertReadsStillAllowed();
    const result: DocSnapshot<T>[] = [];
    for (const [path, raw] of this.docs.entries()) {
      if (parentCollection(path) !== collection) continue;
      const matches = filters.every((f) => {
        const value = raw[f.field];
        if (f.op === "==") return value === f.value;
        if (f.op === "in") return Array.isArray(f.value) && f.value.includes(value);
        return Array.isArray(value) && value.includes(f.value);
      });
      if (matches) result.push({path, exists: true, data: clone(raw as T)});
    }
    return result;
  }

  create(path: string, data: JsonMap): void {
    this.writesStarted = true;
    this.writes.push(() => {
      if (this.docs.has(path)) throw new Error(`already-exists:${path}`);
      this.docs.set(path, clone(data));
    });
  }

  set(path: string, data: JsonMap, merge = false): void {
    this.writesStarted = true;
    this.writes.push(() => {
      const prior = this.docs.get(path);
      this.docs.set(path, merge && prior ? {...prior, ...clone(data)} : clone(data));
    });
  }

  update(path: string, data: JsonMap): void {
    this.writesStarted = true;
    this.writes.push(() => {
      const prior = this.docs.get(path);
      if (!prior) throw new Error(`not-found:${path}`);
      this.docs.set(path, {...prior, ...clone(data)});
    });
  }
}

export class MemoryWorkflowStore implements WorkflowStore {
  private readonly docs = new Map<string, JsonMap>();

  seed(path: string, data: JsonMap): void { this.docs.set(path, clone(data)); }
  read(path: string): JsonMap | null { const value = this.docs.get(path); return value ? clone(value) : null; }
  entries(): readonly [string, JsonMap][] { return [...this.docs.entries()].map(([p, d]) => [p, clone(d)] as [string, JsonMap]); }

  async runTransaction<T>(work: (tx: WorkflowTransaction) => Promise<T>): Promise<T> {
    const tx = new MemoryTransaction(this.docs);
    const result = await work(tx);
    for (const write of tx.writes) write();
    return result;
  }
}
