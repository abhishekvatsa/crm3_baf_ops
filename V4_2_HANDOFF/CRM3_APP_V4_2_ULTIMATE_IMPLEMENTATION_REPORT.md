# CRM3 App v4.2 — Ultimate Successor Local-Trial Candidate

## Governing decision

v4.2 is a forward-migration successor candidate. The v3.3/v4 architecture remains the design authority: server commands, receipts, lanes, compliance, RED, equipment projection, canonical closure, cancellation, escalation, notification and quarantine are non-negotiable. The pre-v4 app is used to preserve business capability, security closure, data continuity and recovery evidence; conflicting legacy authority paths are not retained merely to avoid change.

The current installed application remains operationally canonical until governed cutover. This package does not authorise a remote merge, backend deployment, production-data mutation, pilot handout or field distribution.

## Inputs reconciled

- v4.1 due-diligence correction candidate, SHA-256 `5E72E2B220115DBED6A389832CA8363A79CA09BBB43ACF1C7AB9975871C85560`.
- User-supplied current-pre-v4 source snapshot, SHA-256 `84BB9114C05C29777154E5EA7095DFF00850C478A2DB2048FDE5787CD5EB48CC`.
- First v4.1 critique, which correctly identified native Firestore special-value corruption, further user-schema hardening, projection strictness and dependency concerns.
- Deep merged review, which independently confirmed the canonical closure, legacy closure fence, complete ticket-deferral bridge, generated authority and overall v4.1 coherence.

## Material v4.2 corrections

### 1. Firestore persistence boundary

`FirebaseWorkflowStore` now preserves native Admin SDK values before recursive object conversion:

- `Timestamp`
- `GeoPoint`
- `DocumentReference`
- `FieldValue`
- binary/`Uint8Array`

JSON-safe ISO lifecycle values continue to convert to native Firestore Timestamps. Direct tests cover nested values and the three concrete command paths identified during review: maintenance awaiting confirmation, equipment-state preservation and counter-condition successor creation.

### 2. Singular user authority

Approval and role authority now use one schema across callable, Rules and Flutter:

- only `isApproved == true` grants approval;
- roles must be a non-empty list from the canonical role vocabulary;
- legacy `approved`, `status: approved` and singular `role` do not grant authority;
- unknown or malformed roles fail closed rather than becoming Operations;
- Firestore Rules enforce exact fields, types and bounded optional strings.

### 3. Projection containment

Authority-critical workflow projections now reject malformed IDs, statuses, lane keys, asset identity, versions and dates. A malformed document is retained as a per-document quarantine diagnostic while valid siblings continue to synchronize. Missing critical values are no longer rendered as asset `0`, epoch time, empty authority strings or invented default states.

### 4. Dependency trust domains

Narrow lockfile and override remediation was applied without forced major upgrades:

- root application/test tree: 0 known vulnerabilities;
- Functions tree: 0 known vulnerabilities;
- governed Firebase CLI tree: 0 known vulnerabilities.

Firebase CLI policy and lockfile custody now agree on version `15.22.4` and the remediated lockfile hash.

### 5. Programme authority and old-app continuity

A machine-readable successor-programme authority records the migration-first decision. The pre-v4 source reconciliation and all 16 authentic old Isar collection continuity records are embedded. Every pre-existing collection/property/index identity remains stable; the v4 persistence changes are additive.

### 6. Tomorrow trial harness

`tools/v4/Invoke-Crm3V42LocalTrial.ps1` performs a guarded local sequence:

1. candidate manifest verification;
2. governed Firebase input restoration and hash/identity checks;
3. toolchain verification;
4. three npm clean installs and audits;
5. authentic Isar generation;
6. v4.2/v4.1/v4/inherited audits;
7. Isar release-authority verification;
8. Functions build/tests;
9. Flutter analysis and tests;
10. debug APK build;
11. optional isolated-port emulator execution;
12. optional in-place test-device upgrade.

It contains no remote repository, backend deployment, production-data, uninstall or data-clearing action.

## Validation performed in the packaging environment

- v4.2 ultimate audit: 17/17 PASS
- v4.1 due-diligence audit: 9/9 PASS
- v4 whole-app audit: 21/21 PASS
- inherited full-tree audit: 18/18 PASS
- inherited expanded audit: 15/15 PASS
- Dart structural audit: PASS across 369 Dart files
- policy generation: byte-stable
- Isar source verifier: PASS
- Isar release verifier: expected FAIL with 13 provisional bindings
- TypeScript strict compilation: PASS
- Functions: 224 passed / 29 emulator-dependent skipped
- root npm audit: 0 vulnerabilities
- Functions npm audit: 0 vulnerabilities
- governed Firebase CLI npm audit: 0 vulnerabilities

The Firestore emulator executable could not be downloaded in this sandbox, so emulator tests remain a real trial gate rather than being claimed as passing.

## Classification

- Successor architecture: **GO**
- Local build/test trial: **GO, with governed Firebase inputs and pinned toolchain**
- In-place controlled test-device upgrade: **CONDITIONAL GO with backup and no uninstall**
- Direct remote merge: **NO-GO pending repository reconciliation**
- Backend deployment or production mutation: **NO-GO**
- Pilot/field distribution: **NO-GO**
