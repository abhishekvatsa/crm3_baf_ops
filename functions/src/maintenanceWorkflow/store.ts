import {JsonMap} from "./types";

export interface DocSnapshot<T extends JsonMap = JsonMap> {
  readonly path: string;
  readonly exists: boolean;
  readonly data: T | null;
}

export interface QueryFilter {
  readonly field: string;
  readonly op: "==" | "in" | "array-contains";
  readonly value: unknown;
}

export interface WorkflowTransaction {
  get<T extends JsonMap = JsonMap>(path: string): Promise<DocSnapshot<T>>;
  query<T extends JsonMap = JsonMap>(collection: string, filters: readonly QueryFilter[]): Promise<readonly DocSnapshot<T>[]>;
  create(path: string, data: JsonMap): void;
  set(path: string, data: JsonMap, merge?: boolean): void;
  update(path: string, data: JsonMap): void;
  delete(path: string): void;
}

export interface WorkflowStore {
  runTransaction<T>(work: (tx: WorkflowTransaction) => Promise<T>): Promise<T>;
}
