import {isDeepStrictEqual} from "node:util";

import {
  canonicalApprovedUserAuthority,
  canonicalUserAuthorityDigest,
} from "./userAuthority";

export type GlobalPullJsonMap = {[key: string]: unknown};

export const GLOBAL_PULL_PROTOCOL_VERSION = 1;
export const GLOBAL_PULL_PROTOCOL_FINGERPRINT =
  "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321";
export const GLOBAL_PULL_WRITER_VERSION = "global-pull-server-stamp-v1";
export const GLOBAL_PULL_SERVER_UPDATED_AT_FIELD =
  "_globalPullServerUpdatedAt";
export const GLOBAL_PULL_CONTRACT_PATH = "runtime_contracts/global_pull_v1";
export const GLOBAL_PULL_COLLECTIONS = Object.freeze([
  "abnormality_types",
  "charge_abnormalities",
  "directives",
  "job_diary_entries",
  "job_executions",
  "job_modules",
  "job_templates",
  "knowledge_base",
  "maintenance_records",
  "template_packages",
  "template_publish_audits",
  "template_versions",
] as const);

const GLOBAL_PULL_COLLECTION_SET = new Set<string>(GLOBAL_PULL_COLLECTIONS);
const CONTRACT_KEYS = new Set([
  "state",
  "protocolVersion",
  "protocolFingerprint",
  "writerVersion",
  "serverStampField",
  "collections",
  "activatedAt",
  "sourceCommit",
  "backfillReceiptSha256",
]);
const SOURCE_COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;

export class GlobalPullServerClockError extends Error {
  constructor(
    readonly code:
      | "unauthenticated"
      | "permission-denied"
      | "failed-precondition",
    message: string,
    readonly reason: string,
  ) {
    super(message);
  }
}

interface TimestampLike {
  toDate(): Date;
}

interface ReadSnapshotLike {
  exists: boolean;
  data(): GlobalPullJsonMap | undefined;
}

interface ReadDocumentLike {
  get(): Promise<ReadSnapshotLike>;
}

export interface GlobalPullAuthorityFirestoreLike {
  doc(path: string): ReadDocumentLike;
}

export interface GlobalPullRunAuthorityResult {
  actorUid: string;
  authorityDigest: string;
  protocolVersion: number;
  protocolFingerprint: string;
  writerVersion: string;
  serverStampField: string;
  collections: readonly string[];
  activatedAt: string;
  serverAnchor: string;
}

function isTimestampLike(value: unknown): value is TimestampLike {
  return value != null &&
    typeof value === "object" &&
    typeof (value as TimestampLike).toDate === "function";
}

function requireActiveContract(value: unknown): {
  activatedAt: Date;
} {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull protocol is not activated.",
      "contract-not-object",
    );
  }
  const data = value as GlobalPullJsonMap;
  const keys = Object.keys(data);
  if (
    keys.some((key) => !CONTRACT_KEYS.has(key)) ||
    [...CONTRACT_KEYS].some((key) => !keys.includes(key))
  ) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull protocol contract has an unsupported shape.",
      "contract-invalid-shape",
    );
  }
  if (
    data.state !== "ACTIVE" ||
    data.protocolVersion !== GLOBAL_PULL_PROTOCOL_VERSION ||
    data.protocolFingerprint !== GLOBAL_PULL_PROTOCOL_FINGERPRINT ||
    data.writerVersion !== GLOBAL_PULL_WRITER_VERSION ||
    data.serverStampField !== GLOBAL_PULL_SERVER_UPDATED_AT_FIELD
  ) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull protocol contract is incompatible.",
      "contract-incompatible",
    );
  }
  if (
    !Array.isArray(data.collections) ||
    data.collections.length !== GLOBAL_PULL_COLLECTIONS.length ||
    data.collections.some(
      (value, index) => value !== GLOBAL_PULL_COLLECTIONS[index],
    )
  ) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull collection set is incompatible.",
      "contract-collection-set-mismatch",
    );
  }
  if (
    typeof data.sourceCommit !== "string" ||
    !SOURCE_COMMIT_PATTERN.test(data.sourceCommit) ||
    typeof data.backfillReceiptSha256 !== "string" ||
    !SHA256_PATTERN.test(data.backfillReceiptSha256)
  ) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull activation evidence is malformed.",
      "contract-evidence-invalid",
    );
  }
  if (!isTimestampLike(data.activatedAt)) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull activation timestamp is malformed.",
      "contract-activated-at-invalid",
    );
  }
  const activatedAt = data.activatedAt.toDate();
  if (Number.isNaN(activatedAt.getTime())) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull activation timestamp is malformed.",
      "contract-activated-at-invalid",
    );
  }
  return {activatedAt};
}

export async function beginGlobalPullRunWithDb(args: {
  db: GlobalPullAuthorityFirestoreLike;
  authUid: string | null;
  serverNow: () => Date;
}): Promise<GlobalPullRunAuthorityResult> {
  const uid = args.authUid?.trim() ?? "";
  if (uid.length === 0) {
    throw new GlobalPullServerClockError(
      "unauthenticated",
      "Authentication is required to begin a global pull run.",
      "actor-unauthenticated",
    );
  }

  const actorSnapshot = await args.db.doc(`users/${uid}`).get();
  const authority = canonicalApprovedUserAuthority(
    actorSnapshot.exists ? actorSnapshot.data() : null,
  );
  if (authority == null) {
    throw new GlobalPullServerClockError(
      "permission-denied",
      "Current approved-user authority is required for global pull.",
      "actor-not-approved",
    );
  }

  const contractSnapshot = await args.db.doc(GLOBAL_PULL_CONTRACT_PATH).get();
  const contract = requireActiveContract(
    contractSnapshot.exists ? contractSnapshot.data() : null,
  );
  const serverAnchor = args.serverNow();
  if (
    Number.isNaN(serverAnchor.getTime()) ||
    serverAnchor.getTime() < contract.activatedAt.getTime()
  ) {
    throw new GlobalPullServerClockError(
      "failed-precondition",
      "The global pull server anchor is invalid.",
      "server-anchor-invalid",
    );
  }

  return {
    actorUid: uid,
    authorityDigest: canonicalUserAuthorityDigest({
      isApproved: true,
      roles: authority.roles,
    }),
    protocolVersion: GLOBAL_PULL_PROTOCOL_VERSION,
    protocolFingerprint: GLOBAL_PULL_PROTOCOL_FINGERPRINT,
    writerVersion: GLOBAL_PULL_WRITER_VERSION,
    serverStampField: GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
    collections: GLOBAL_PULL_COLLECTIONS,
    activatedAt: contract.activatedAt.toISOString(),
    serverAnchor: serverAnchor.toISOString(),
  };
}

interface WriteDocumentLike {
  set(data: GlobalPullJsonMap, options?: {merge: boolean}): Promise<unknown>;
}

interface WriteSnapshotLike {
  exists: boolean;
  data(): GlobalPullJsonMap | undefined;
  ref: WriteDocumentLike;
}

export interface GlobalPullWriteChangeLike {
  before: WriteSnapshotLike;
  after: WriteSnapshotLike;
}

export type GlobalPullStampAction =
  | "ignored-collection"
  | "ignored-stamp-only"
  | "stamped"
  | "restored-tombstone"
  | "ignored-empty";

function withoutServerStamp(
  data: GlobalPullJsonMap | undefined,
): GlobalPullJsonMap | undefined {
  if (data == null) return undefined;
  const copy = {...data};
  delete copy[GLOBAL_PULL_SERVER_UPDATED_AT_FIELD];
  return copy;
}

export function shouldStampGlobalPullWrite(
  before: GlobalPullJsonMap | undefined,
  after: GlobalPullJsonMap | undefined,
): boolean {
  if (after == null) return false;
  if (before == null) return true;
  return !isDeepStrictEqual(
    withoutServerStamp(before),
    withoutServerStamp(after),
  );
}

export async function applyGlobalPullServerClock(args: {
  collectionId: string;
  change: GlobalPullWriteChangeLike;
  serverTimestamp: () => unknown;
}): Promise<GlobalPullStampAction> {
  if (!GLOBAL_PULL_COLLECTION_SET.has(args.collectionId)) {
    return "ignored-collection";
  }

  const before = args.change.before.exists ?
    args.change.before.data() :
    undefined;
  const after = args.change.after.exists ?
    args.change.after.data() :
    undefined;

  if (after != null) {
    if (!shouldStampGlobalPullWrite(before, after)) {
      return "ignored-stamp-only";
    }
    await args.change.after.ref.set(
      {[GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: args.serverTimestamp()},
      {merge: true},
    );
    return "stamped";
  }

  if (before == null) return "ignored-empty";
  const timestamp = args.serverTimestamp();
  await args.change.before.ref.set(
    {
      ...before,
      isDeleted: true,
      deletedAt: before.deletedAt ?? timestamp,
      [GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: timestamp,
    },
    {merge: false},
  );
  return "restored-tombstone";
}
