# Cross-Business Offline and Cloud Alignment Audit

Date: 2026-08-23

Status: SOURCE REMEDIATED; SOURCE AND CI EVIDENCE PENDING PR

## Decision

Offline-first behavior may preserve and provisionally display a user's work,
but it must not claim that Firestore accepted the work. Firestore Rules and
governed Cloud Functions remain the final authority.

A local record may become clean only after one of these outcomes:

1. an exact authoritative receipt is applied to the unchanged local record;
2. an exact remote readback matches the complete persisted client payload; or
3. an append-only, deterministic write receives an acknowledged commit.

Permission denial, failed precondition, validation failure, uncertain remote
state, or non-matching readback leaves the source evidence dirty or held.

## Business Sync Inventory

| Surface | Write authority | Convergence rule |
| --- | --- | --- |
| Maintenance issue creation | Governed workflow callable | Apply exact aggregate version and server time from the receipt |
| Maintenance acknowledgement, coordination, resolution, reopen | Governed workflow callable | Replay step must match exact remote outcome; adopt rebased server version before clean |
| Planned job templates | Firestore Rules | Complete persisted payload must match exact readback |
| Planned job executions | Firestore Rules plus governed completion callable | Ordinary changes require exact readback; completion adopts callable evidence |
| Job diary entries | Firestore Rules | Complete persisted payload must match exact readback |
| Job modules | Governed module mutation | Exact client snapshot and authoritative version; modules precede execution closure |
| Template packages | Firestore Rules | Complete persisted payload must match exact readback |
| Template versions | Firestore Rules with governed lifecycle contract | Every draft, update, publish, and archive replay step receives exact readback |
| Template publication audits | Immutable Firestore identity | Full publication evidence must match the remote audit record |
| BAF knowledge rows | Firestore Rules with server timestamps | Apply canonical remote timestamp receipt to the unchanged local row |
| Operational directives | Firestore Rules | Complete persisted payload must match exact readback |
| Abnormality types | Firestore Rules | Complete persisted payload must match exact readback |
| Charge abnormalities | Governed abnormality callable | Governed remote state and version must match |
| Workflow command outbox | Governed workflow callable | Idempotency receipt and uncertain-command retry; projection pull is isolated |
| Audit events | Append-only Firestore record with deterministic ID | Acknowledged idempotent commit; uncertain writes remain dirty for safe retry |

The machine-checked `syncAll()` operation inventory is exact. Adding or
removing a sync operation now requires explicit test adjudication instead of
silently inheriting an unsuitable strategy.

## User-Facing Contract

- Create, edit, publish, archive, reopen, and delete screens await the immediate
  synchronization result when they make a completion claim.
- Messages distinguish `synchronized`, `queued locally`, `queued behind another
  run`, and `server needs attention`.
- A delayed retry is armed before immediate maintenance-issue transport, so a
  weak connection or process exit cannot strand accepted local evidence.
- Approved users can select **Recheck with server** for held records. This runs
  the normal rules and callables again; it does not bypass authority, delete a
  source row, overwrite it, or mark it synchronized merely by releasing a hold.
- The exact unresolved hold remains in place during that recheck. It is
  resolved per record only after an accepted remote write, an authoritative
  callable receipt, or an exact remote readback has been reconciled. A network
  failure, server rejection, conflict, or partial batch failure retains the
  original hold.
- Admin review remains available for diagnostic disposition, but ordinary
  recovery no longer depends on an Admin being present.

There is intentionally no `flush all` action. A blind flush would either lose
unsent plant evidence or bypass the reason the server rejected it. The safe
equivalent is a governed recheck followed by authoritative pull.

## Why Local and Server Validation Differed

The local layer was designed to preserve work while offline. Several screens
mistook successful local persistence or admission to the queue for successful
cloud acceptance. Other paths marked the original local version clean even
when a server replay had committed a higher version.

The corrected boundary is:

```text
local validation = structurally valid provisional command
server validation = authoritative role, state, version, and business policy
UI completion     = only after authoritative acceptance or exact readback
```

The local layer now constructs the same governed command shape before queueing
where that contract exists. It still cannot and must not impersonate live
server facts such as current authority, concurrent version, or deployment
Rules. Those are reconciled rather than guessed.

## Static and Emulator Evidence

Evidence produced against this source tranche:

```text
Flutter analyze:                         no issues
Focused sync and business tests:         87 passed
Full Flutter suite:                   1,182 passed, 1 skipped
Functions Jest:                         553 passed, 80 skipped
Firestore Rules emulator:               180 passed
Governed asset-identity emulator:          3 passed
Governed callable emulator:              80 passed
Canonical R1 audit:                     147 passed, 0 failed
```

The source audit covers all 12 ordinary pending-record counts, the governed
workflow outbox, and append-only audit events. Architecture, persistence,
schema, and decoder manifests were re-armed to the changed source.

## Device Boundary

A fresh debug build installed on the disposable emulator and rendered the
production-branded sign-in screen. The emulator terminated during Google
account handoff, and the physical phone became unauthorized after the ADB
daemon restarted. Therefore an authenticated screen-by-screen device matrix is
not claimed here.

Remaining device work is validation, not a source substitute:

1. authorize the physical phone or stabilize the emulator;
2. install the branch artifact without clearing physical-phone data;
3. exercise representative create, lifecycle, delete, weak-network, lost-
   response, rejection-recheck, and reconnect paths;
4. confirm each screen reports provisional and synchronized outcomes honestly;
5. preserve screenshots and diagnostic exports as device evidence.

No pilot, production deployment, or device-proof closure is claimed by this
source audit alone.
