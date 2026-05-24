# Issue 33 — Legacy dirty-row reconciliation playbook

## Purpose

Use this when an upgraded tablet contains old local dirty rows that now fail stricter Firestore rules or no longer match cloud state. The goal is to separate stale/test/local-only rows from real plant evidence without silently deleting or marking anything as synced.

## Golden rules

1. Do not uninstall the app or clear app data before recovery review.
2. Do not mark a rejected dirty row as synced unless a matching remote write has actually succeeded.
3. Do not auto-discard local-only evidence.
4. Create/export a recovery package before any destructive local reset/rebuild.
5. Admin/SI owns discard/archive decisions; field users should not decide whether plant evidence is stale.

## Triage categories

### A. Stale test/local demo row

Typical signs:

- asset/job/module is clearly not a real plant-floor record;
- record was created during test/debug use;
- no matching plant job/ticket exists remotely;
- rejection is permanent and unrelated to current active work.

Action:

- capture screenshot/export diagnostics;
- Admin/SI may archive/discard locally after documenting reason;
- do not sync to production cloud.

### B. Real plant evidence blocked by stricter rules

Typical signs:

- record belongs to a real job/ticket/module;
- operator/supervisor recognizes the work;
- contains maintenance/job evidence that is not present in cloud;
- rejection happened after rules/app upgrade.

Action:

- create recovery package first;
- do not discard;
- manually review exact rule rejection;
- either repair the local row shape through a governed recovery tool or re-enter evidence under Admin/SI supervision with audit note.

### C. Duplicate local row where cloud already has correct evidence

Typical signs:

- cloud has a newer/accepted/supervisor-reviewed equivalent;
- local row is old dirty duplicate;
- no unique evidence would be lost.

Action:

- document duplicate relationship;
- Admin/SI may archive local duplicate after recovery package;
- do not push duplicate to production.

### D. Conflict: cloud newer but local dirty row has unique evidence

Typical signs:

- cloud row exists and is newer;
- local row is unsynced and contains additional operator input;
- both sides may be partially correct.

Action:

- preserve both;
- Admin/SI compares before/after snapshots;
- merge manually or create corrected follow-up evidence entry;
- close conflict only after audit note is created.

## Minimum workflow for team handoff

1. Run sync and capture current sync rejection/conflict list.
2. Export/copy local diagnostics or recovery package where available.
3. For each rejected row, classify as A/B/C/D above.
4. For A/C, archive/discard only after Admin/SI sign-off.
5. For B/D, preserve and recover/merge under Admin/SI supervision.
6. Record outcome in audit/ops handoff note.

## What not to build yet

- Do not build automatic dirty-row deletion.
- Do not build automatic remote-over-local rebase for plant evidence.
- Do not loosen Firestore rules to accept malformed legacy rows.
- Do not hide permanent rejections from the sync panel.

## Safe future app support

Later, add an Admin-only review screen for unresolved `SyncRejection` / pull-conflict rows with:

- entity type and entity id;
- local updatedAt/version;
- rejection code/message;
- retry/hold status;
- export diagnostics button;
- archive/discard action gated by Admin/SI confirmation and reason.
