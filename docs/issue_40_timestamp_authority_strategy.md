# Issue 40 — Timestamp authority strategy

## Current baseline finding

The app currently uses a mixed timestamp model:

1. **Most operational entities use client-authored ISO strings** for `createdAt`, `updatedAt`, and lifecycle timestamps. Examples:
   - `MaintenanceRecord` writes `createdAt` / `updatedAt` as ISO strings in `maintenance_provider.dart`.
   - `JobModuleInstance` writes module lifecycle timestamps as ISO strings in `job_module_model.dart`.
   - Firestore rules for maintenance explicitly require `createdAt is string` and `updatedAt is string`.

2. **BAF Knowledge governance already uses server-authoritative timestamps** in Firestore rules:
   - `knowledge_base.updatedAt == request.time`
   - `knowledge_base.createdAt == request.time` on create
   - `knowledge_base_meta.updatedAt == request.time`

3. **Sync conflict resolution is still mostly based on client values**:
   - `version`
   - client `updatedAt`
   - `isSynced`
   - `isDeleted` / tombstone timestamps

4. **Push sync already detects obvious future-clock drift**, but only as a debug warning, not as an enforceable policy.

## Risk

Client-authored timestamps are operationally useful because they represent the tablet/user-observed time of an action, especially offline. But they should not be treated as server-truth ordering forever.

Plant-floor examples:

- A tablet clock set one day ahead can make one local row look newer than a true remote update.
- A tablet clock set behind can make fresh local evidence look stale.
- Server-side rules currently verify version advancement for many entities, but not bounded client timestamp drift.
- Full conversion to server timestamps would break offline-first evidence semantics if done blindly.

## Decision

Do **not** replace operational timestamps with `FieldValue.serverTimestamp()` everywhere.

Instead, split timestamp meaning into two categories:

### A. Client-observed evidence timestamps

Keep these as the existing domain fields:

- `createdAt`
- `updatedAt`
- `loggedAt`
- `submittedAt`
- `acceptedAt`
- `reopenedAt`
- `closedAt`
- `completedAt`
- `deletedAt`
- `publishedAt` / `retiredAt` when authored offline or in app workflows

These represent what the app/user observed or did. They are part of the offline dossier.

### B. Server-write authority timestamps

Add companion fields later, schema-stage only:

- `serverCreatedAt`
- `serverUpdatedAt`
- `serverDeletedAt` where needed
- `lastServerSeenAt` for pull watermarks / diagnostics

These represent when Firestore accepted or last wrote the row.

## Safe-now position

No immediate Dart/schema patch should be made for Issue 40.

Reason: adding server timestamp companion fields touches:

- Isar schemas and generated `.g.dart`
- Firestore rules
- every `toMap()` / `fromMap()` mapper
- sync conflict policy
- pull watermarks
- emulator tests
- migration/recovery policy for unmanaged tablets

This is schema-stage work, not a quick handoff patch.

## Schema-stage implementation plan

### Stage 1 — Add companion fields to one low-risk entity family

Recommended pilot: `AuditEvent` or `BafKnowledgeRow`, not JobModule.

Why:

- Audit/knowledge are governance/support surfaces.
- JobModule is plant-floor execution evidence and should not be first migration target.

Add:

```text
serverCreatedAt
serverUpdatedAt
lastServerSeenAt
```

Rules:

```text
serverCreatedAt == request.time on create
serverUpdatedAt == request.time on create/update
```

Dart:

- keep existing client `timestamp` / `updatedAt`
- parse server companion fields when present
- never use server companion fields as the only local evidence time

### Stage 2 — Add bounded client timestamp validation

For entities with client ISO strings, Firestore rules can later require client `updatedAt` to be within a bounded window when online writes occur.

Example policy, not immediate code:

```text
client updatedAt must not be more than 10 minutes in the future relative to request.time
```

Caveat: this must be designed carefully for offline sync, because old offline evidence can validly be hours or days old.

### Stage 3 — Update sync conflict policy

Conflict ordering should become:

1. Tombstone/delete policy
2. Version advancement
3. Server companion timestamp if both sides have it
4. Client observed timestamp only as tie-breaker / evidence display
5. Dirty local preservation always wins against destructive overwrite

### Stage 4 — Expand emulator/Dart regression tests

Required tests:

- old offline evidence can still sync later
- future-dated tablet row is flagged/held, not silently accepted
- server companion timestamp is preserved on pull
- local dirty row is not overwritten by server timestamp alone
- tombstone rebase still audits local snapshot

## What not to do

- Do not convert all `updatedAt` fields to `FieldValue.serverTimestamp()` immediately.
- Do not remove client observed timestamps from dossiers.
- Do not use server timestamp alone to overwrite dirty local rows.
- Do not start with JobModule schema unless regression coverage is much wider.
- Do not make timestamp rules stricter without emulator tests for offline delayed sync.

## Recommended next action

Keep Issue 40 as an architecture-stage decision note for now.

Safe next implementation after handoff:

```text
Issue 40A — Add server companion timestamp pilot to AuditEvent or BAF Knowledge only.
```

Only proceed after the team approves a schema-stage migration plan.
