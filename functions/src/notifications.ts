import {canonicalApprovedUserAuthority} from "./userAuthority";

/**
 * Pure notifications logic for breakdown tickets and planned job assignments.
 *
 * This module is deliberately framework-agnostic — it accepts injected
 * Firestore and FCM-like surfaces so it can be unit-tested without the
 * firebase-admin SDK. The Cloud Functions triggers in index.ts adapt
 * the real SDK to these interfaces.
 *
 * Three responsibilities:
 *   1. Resolve which users (by role) should receive a notification.
 *   2. Send via FCM in batches of up to 500.
 *   3. Clear stale FCM tokens reported by FCM as not-registered/invalid.
 */

// ─── Minimal interfaces for testability ──────────────────────────────────────

export interface DocumentSnapshotLike {
  readonly id: string;
  exists?: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface QuerySnapshotLike {
  readonly docs: ReadonlyArray<DocumentSnapshotLike>;
  forEach(callback: (doc: DocumentSnapshotLike) => void): void;
}

export interface DocumentRefLike {
  readonly path?: string;
  get(): Promise<DocumentSnapshotLike>;
  update(data: Record<string, unknown>): Promise<unknown>;
  collection(name: string): CollectionRefLike;
}

export interface TransactionLike {
  get(ref: DocumentRefLike): Promise<DocumentSnapshotLike>;
  update(ref: DocumentRefLike, data: Record<string, unknown>): void;
  delete(ref: DocumentRefLike): void;
}

export interface QueryLike {
  where(field: string, op: string, value: unknown): QueryLike;
  orderBy(field: string, direction: "asc" | "desc"): QueryLike;
  limit(count: number): QueryLike;
  get(): Promise<QuerySnapshotLike>;
}

export interface CollectionRefLike extends QueryLike {
  doc(id: string): DocumentRefLike;
}

export interface FirestoreLike {
  collection(name: string): CollectionRefLike;
  runTransaction<T>(fn: (txn: TransactionLike) => Promise<T>): Promise<T>;
}

export interface FcmSendResponse {
  readonly success: boolean;
  readonly messageId?: string;
  readonly error?: {readonly code: string; readonly message?: string};
}

export interface FcmBatchResponse {
  readonly successCount: number;
  readonly failureCount: number;
  readonly responses: ReadonlyArray<FcmSendResponse>;
}

export interface MessagingLike {
  sendEach(messages: FcmMessage[]): Promise<FcmBatchResponse>;
}

export interface FcmMessage {
  token: string;
  notification: {title: string; body: string};
  data?: Readonly<Record<string, string>>;
  android?: {
    priority?: "high" | "normal";
    notification?: {sound?: string; channelId?: string};
  };
}

// ─── Agency → role mapping ───────────────────────────────────────────────────
//
// `assignedAgencies` on a job_execution stores discipline names sourced from
// the planned-maintenance template editor (see _availableAgencies in
// lib/features/planned_maintenance/presentation/create_template_screen.dart).
// User documents carry role strings from the AppRole enum. The two
// vocabularies don't match — most agencies have no direct role with the
// same string. This table is the single source of truth that bridges them.
//
// Coverage rationale:
//   - The five canonical agencies — electrical, mechanical, instrumentation,
//     refractory, emd — are the only values the current template editor
//     allows users to select.
//   - operations / shiftInCharge / others appear in display/legacy code
//     paths (e.g. _agencyColor in assign_job_screen.dart) and may exist
//     in older template documents created before the canonical list was
//     fixed. They're mapped here for backward compatibility.
//   - shared / safety are NOT agencies — they're module DISCIPLINES
//     (set on job_modules.discipline, not job_executions.assignedAgencies).
//     They will never appear in this lookup; do not add them.
//
// Keep this table in sync with:
//   - The AppRole enum in the Flutter app
//   - _availableAgencies in create_template_screen.dart (canonical source)
//   - The role allowlists in firestore.rules

export const AGENCY_TO_ROLES: Readonly<Record<string, ReadonlyArray<string>>> = {
  // Canonical agencies (selectable in current template editor)
  mechanical: ["seniorMechanical"],
  electrical: ["seniorElectrical"],
  instrumentation: ["seniorInstrumentation"],
  refractory: ["refractory", "seniorRefractory"],
  // TEMP fallback: intentionally over-notifies governance roles until the
  // EMD-specific role is defined. Replace once ops confirms (e.g. "emd" or
  // "seniorEmd"). The decision to over-notify rather than fail silent is
  // deliberate and tracked in the M6+ follow-up issues.
  emd: ["admin", "si"],

  // Legacy / display-only agencies (may exist in older templates)
  operations: ["operations", "shiftSupervisor"],
  shiftInCharge: ["shiftSupervisor"],
  others: ["admin", "si"], // No specific responsible team — route to governance
};

/**
 * Expands a list of agency names into the set of user roles that should be
 * notified. Unknown agencies are silently skipped, but logged by callers
 * so dashboard misconfigurations surface in function logs.
 */
export function agenciesToRoles(
  agencies: ReadonlyArray<string>,
): {roles: string[]; unknownAgencies: string[]} {
  const roleSet = new Set<string>();
  const unknown: string[] = [];
  for (const agency of agencies) {
    const mapped = AGENCY_TO_ROLES[agency];
    if (mapped == null) {
      unknown.push(agency);
      continue;
    }
    for (const role of mapped) roleSet.add(role);
  }
  return {roles: [...roleSet], unknownAgencies: unknown};
}

// ─── Token lookup ────────────────────────────────────────────────────────────

export interface UserTokenLookup {
  uid: string;
  fcmToken: string;
  installationId?: string;
}

export const NOTIFICATION_INSTALLATIONS_COLLECTION =
  "notification_installations";
export const NOTIFICATION_INSTALLATION_SCHEMA_VERSION = 1;
export const MAX_NOTIFICATION_INSTALLATIONS_PER_USER = 8;

const NOTIFICATION_PLATFORMS = new Set([
  "android",
  "ios",
  "macos",
  "windows",
  "linux",
  "fuchsia",
  "web",
]);

function isFirestoreTimestamp(value: unknown): boolean {
  if (typeof value !== "object" || value == null) return false;
  const toMillis = (value as {toMillis?: unknown}).toMillis;
  if (typeof toMillis !== "function") return false;
  try {
    const milliseconds = toMillis.call(value);
    return typeof milliseconds === "number" && Number.isFinite(milliseconds);
  } catch (_) {
    return false;
  }
}

function canonicalInstallationToken(
  data: Record<string, unknown> | undefined,
): string | null {
  if (data == null) return null;
  const keys = Object.keys(data);
  const expectedKeys = new Set([
    "schemaVersion",
    "token",
    "platform",
    "updatedAt",
  ]);
  if (
    keys.length !== expectedKeys.size ||
    keys.some((key) => !expectedKeys.has(key)) ||
    data.schemaVersion !== NOTIFICATION_INSTALLATION_SCHEMA_VERSION ||
    typeof data.token !== "string" ||
    data.token.length === 0 ||
    data.token.length > 4096 ||
    typeof data.platform !== "string" ||
    !NOTIFICATION_PLATFORMS.has(data.platform) ||
    !isFirestoreTimestamp(data.updatedAt)
  ) {
    return null;
  }
  return data.token;
}

async function tokenLookupsForApprovedUser(
  db: FirestoreLike,
  uid: string,
  authorityData: Record<string, unknown>,
): Promise<UserTokenLookup[]> {
  const out: UserTokenLookup[] = [];
  const legacyToken = typeof authorityData.fcmToken === "string" ?
    authorityData.fcmToken :
    null;
  if (legacyToken != null && legacyToken.length > 0) {
    out.push({uid, fcmToken: legacyToken});
  }

  const installations = await db
    .collection("users")
    .doc(uid)
    .collection(NOTIFICATION_INSTALLATIONS_COLLECTION)
    .orderBy("updatedAt", "desc")
    .limit(MAX_NOTIFICATION_INSTALLATIONS_PER_USER)
    .get();
  for (const installation of installations.docs) {
    const token = canonicalInstallationToken(installation.data());
    if (token == null) continue;
    out.push({uid, fcmToken: token, installationId: installation.id});
  }
  return out;
}

/**
 * Returns every bounded installation for approved users holding a requested
 * role. The legacy single-token field remains readable during migration.
 * Token uniqueness is enforced by the sender.
 */
export async function getTokenLookupsForRoles(
  db: FirestoreLike,
  roles: ReadonlyArray<string>,
): Promise<UserTokenLookup[]> {
  if (roles.length === 0) return [];

  const snapshot = await db
    .collection("users")
    .where("isApproved", "==", true)
    .get();

  const eligible: Array<{
    uid: string;
    authorityData: Record<string, unknown>;
  }> = [];
  snapshot.forEach((doc) => {
    const data = doc.data();
    const authority = canonicalApprovedUserAuthority(data);
    if (authority == null) return;
    const hasRole = [...authority.roles].some((role) => roles.includes(role));
    if (!hasRole) return;
    eligible.push({uid: doc.id, authorityData: authority.data});
  });
  return (await Promise.all(eligible.map(({uid, authorityData}) =>
    tokenLookupsForApprovedUser(db, uid, authorityData)
  ))).flat();
}

export async function getTokenLookupsForUser(
  db: FirestoreLike,
  uid: string,
): Promise<UserTokenLookup[]> {
  const result = await db.collection("users").doc(uid).get();
  if (!result.exists) return [];
  const authority = canonicalApprovedUserAuthority(result.data());
  if (authority == null) return [];
  return tokenLookupsForApprovedUser(db, uid, authority.data);
}

// ─── Send + stale-token cleanup ──────────────────────────────────────────────

/**
 * FCM error codes that mean the token is permanently dead and should be
 * cleared from the user record. Transient errors (quota, unavailable) are
 * NOT in this list — we retry those next time naturally.
 *
 * See: https://firebase.google.com/docs/cloud-messaging/manage-tokens
 */
export const FCM_DEAD_TOKEN_CODES: ReadonlyArray<string> = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
];

export interface SendOutcome {
  attempted: number;
  succeeded: number;
  failed: number;
  staleTokensCleared: number;
  unknownAgencies: ReadonlyArray<string>;
}

/**
 * Sends a single notification to a set of users, batching FCM calls at 500,
 * and clears each exact legacy or installation registration reported dead.
 *
 * Returns counts for logging/observability. Never throws on FCM errors;
 * partial failure is normal and acceptable for fan-out notifications.
 */
export async function sendNotification(args: {
  db: FirestoreLike;
  messaging: MessagingLike;
  recipients: ReadonlyArray<UserTokenLookup>;
  title: string;
  body: string;
  unknownAgencies?: ReadonlyArray<string>;
  androidChannelId?: string;
  data?: Readonly<Record<string, string>>;
}): Promise<SendOutcome> {
  const {
    db,
    messaging,
    recipients,
    title,
    body,
    unknownAgencies = [],
    androidChannelId = "crm3_baf_ops",
    data,
  } = args;

  // Deduplicate by token (a shared device should only buzz once), but
  // remember EVERY uid that pointed at that token. The same dead token
  // can exist on multiple user records (shared tablets are common in
  // shift work), and we want to clear it from all of them — not just
  // the first one we saw.
  const tokenToRegistrations = new Map<string, UserTokenLookup[]>();
  for (const r of recipients) {
    const existing = tokenToRegistrations.get(r.fcmToken);
    if (existing == null) {
      tokenToRegistrations.set(r.fcmToken, [r]);
      continue;
    }
    const alreadyPresent = existing.some((registration) =>
      registration.uid === r.uid &&
      registration.installationId === r.installationId
    );
    if (!alreadyPresent) {
      existing.push(r);
    }
  }
  const dedupedTokens = [...tokenToRegistrations.keys()];
  if (dedupedTokens.length === 0) {
    return {
      attempted: 0,
      succeeded: 0,
      failed: 0,
      staleTokensCleared: 0,
      unknownAgencies,
    };
  }

  let succeeded = 0;
  let failed = 0;
  const staleTokens: string[] = [];

  for (let i = 0; i < dedupedTokens.length; i += 500) {
    const batch = dedupedTokens.slice(i, i + 500);
    const messages: FcmMessage[] = batch.map((token) => ({
      token,
      notification: {title, body},
      ...(data == null ? {} : {data}),
      android: {
        priority: "high",
        notification: {sound: "default", channelId: androidChannelId},
      },
    }));

    const response = await messaging.sendEach(messages);
    succeeded += response.successCount;
    failed += response.failureCount;

    response.responses.forEach((resp, idx) => {
      if (resp.success) return;
      const code = resp.error?.code;
      if (code != null && FCM_DEAD_TOKEN_CODES.includes(code)) {
        staleTokens.push(batch[idx]);
      }
    });
  }

  // Clear dead registrations race-safely. The legacy field is nulled only
  // while it still matches, and an installation document is deleted only
  // while that exact installation still carries the rejected token.
  let cleared = 0;
  for (const deadToken of staleTokens) {
    const registrations = tokenToRegistrations.get(deadToken) ?? [];
    for (const registration of registrations) {
      try {
        const didClear = await db.runTransaction(async (txn) => {
          const userRef = db.collection("users").doc(registration.uid);
          const ref = registration.installationId == null ?
            userRef :
            userRef
              .collection(NOTIFICATION_INSTALLATIONS_COLLECTION)
              .doc(registration.installationId);
          const snap = await txn.get(ref);
          if (!snap.exists) return false;
          const current = snap.data();
          if (current == null) return false;
          if (registration.installationId == null) {
            if (current.fcmToken !== deadToken) return false;
            txn.update(ref, {fcmToken: null});
          } else {
            if (current.token !== deadToken) return false;
            txn.delete(ref);
          }
          return true;
        });
        if (didClear) cleared += 1;
      } catch {
        // Swallow: cleanup is opportunistic. Don't fail the trigger.
      }
    }
  }

  return {
    attempted: dedupedTokens.length,
    succeeded,
    failed,
    staleTokensCleared: cleared,
    unknownAgencies,
  };
}

// ─── Notification builders (pure) ────────────────────────────────────────────
//
// Pulled out as pure functions so tests assert on shape without touching FCM.

export function buildTicketCreatedNotification(ticket: Record<string, unknown>): {
  title: string;
  body: string;
  roles: string[];
} {
  const assetType = typeof ticket.assetType === "string" ? ticket.assetType : "";
  const assetNumber = ticket.assetNumber ?? "";
  const description =
    typeof ticket.description === "string" && ticket.description.length > 0
      ? ticket.description
      : "New breakdown";
  const routedTo = typeof ticket.routedTo === "string" ? ticket.routedTo : "";

  const roles = ["admin", "si", "contractSupervisor", "shiftSupervisor"];
  if (routedTo === "refractory") {
    roles.push("refractory", "seniorRefractory");
  }

  return {
    title: `🔴 Breakdown: ${assetType.toUpperCase()} ${assetNumber}`,
    body: `${description} — Routed to ${routedTo.toUpperCase()}`,
    roles,
  };
}

export function buildTicketResolvedNotification(
  after: Record<string, unknown>,
): {title: string; body: string; roles: string[]; loggedByUid: string | null} {
  const assetType = typeof after.assetType === "string" ? after.assetType : "";
  const assetNumber = after.assetNumber ?? "";
  const closedBy =
    typeof after.closedByName === "string" && after.closedByName.length > 0
      ? after.closedByName
      : "Unknown";
  const remarks =
    typeof after.remarks === "string" && after.remarks.length > 0
      ? after.remarks
      : "No remarks";

  return {
    title: `✅ Resolved: ${assetType.toUpperCase()} ${assetNumber}`,
    body: `Closed by ${closedBy} — ${remarks}`,
    roles: ["admin", "si"],
    loggedByUid:
      typeof after.loggedByUid === "string" ? after.loggedByUid : null,
  };
}

export function buildJobAssignedNotification(
  execution: Record<string, unknown>,
): {
  title: string;
  body: string;
  roles: string[];
  unknownAgencies: string[];
} | null {
  const assetType =
    typeof execution.assetType === "string" ? execution.assetType : "";
  const assetNumber = execution.assetNumber ?? "";
  const templateName =
    typeof execution.templateName === "string" && execution.templateName.length > 0
      ? execution.templateName
      : "Planned Job";
  const assignedBy =
    typeof execution.assignedByName === "string" && execution.assignedByName.length > 0
      ? execution.assignedByName
      : "Unknown";
  const rawAgencies = execution.assignedAgencies;
  const agencies = Array.isArray(rawAgencies)
    ? rawAgencies.filter((a): a is string => typeof a === "string")
    : [];

  if (agencies.length === 0) return null;

  const {roles, unknownAgencies} = agenciesToRoles(agencies);

  // Governance fallback: only when mapping produced ZERO roles, route to
  // admin/si so the notification doesn't vanish entirely. Do NOT cc
  // governance on every assignment — that's a separate product decision
  // and would be too noisy (every mechanical, electrical, etc. would buzz
  // every admin). The emd agency intentionally maps to admin/si already
  // via AGENCY_TO_ROLES, so EMD jobs still notify governance through the
  // normal mapping path.
  if (roles.length === 0) {
    for (const fallback of ["admin", "si"]) {
      if (!roles.includes(fallback)) roles.push(fallback);
    }
  }

  return {
    title: `📋 Job Assigned: ${templateName}`,
    body: `Asset: ${assetType.toUpperCase()} ${assetNumber} — Assigned by ${assignedBy}`,
    roles,
    unknownAgencies,
  };
}
