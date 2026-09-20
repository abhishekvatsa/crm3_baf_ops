# Maintenance Cadence review — 20 September 2026

Status: verified local repairs; the full audit is NOT closed. No production data, deployment, commit, push or distributable build changed in this pass.

Source evidence: the user's CRM3_Maintenance_Cadence_Final_Review.pdf, HTML and ZIP. Their pinned d038797f snapshot predates some working-tree repairs. Supplied scripts were not executed as instructions.

## Owner decision

Conflicting due dates from same-day evidence require review. The reducer uses the Indian plant day. It preserves both records and withholds a settled next due date. A later unambiguous physical completion may become the new basis without erasing the earlier evidence.

## Implemented

- MC01 containment: overlapping legacy and registered identities qualify both affected counter tracks as identity-review-required. No automatic merge by asset number. Different registered assets with reused numbers remain distinct. This is containment, not completed identity reconciliation.
- MC02: one reducer for normal writes and reclassification. Same-day conflicting deadlines produce a pending marker, reason, null next due date and retained conflict event IDs. A revised source replaces its previous interpretation before reduction. New historical sources preserve date precision and plant timezone.
- MC03: new historical records entered against retired assets persist historical-only applicability in event and source. Rebuilds exclude them and later interpretations retain that exclusion. Existing unmarked rows were not automatically reinterpreted.
- MC04: unknown original completer/closer remains null. Reviewer identity is separate. History groups interpretation revisions under one occurrence, shows older interpretations and distinguishes recorder/performer and historical-only status.
- MC06: plan provenance verifies due-body identity/path, supporting immutable event, current source and recalculated projection. Invalid, conflicting or stale bases are refused. The plan and its audit retain a normalized evidence snapshot and SHA-256. Standalone planning remains available.
- MC07 partial: existing numeric-plan subject review retained; missing Flutter import repaired. Existing retired-asset selector, qualified feed batches and cadence clock retained. Metadata-only confirmation updates now reach all cadence streams; direct server readback rejects pending writes.

## Verification

- Functions production build and emitted-output/callable/notification inventories passed.
- Before the final identity-containment addition: 75 Jest suites / 2,126 tests passed; 19 emulator suites / 198 tests skipped.
- After that addition: 54 focused backend tests passed, including both arrival orders, Indian day boundaries, correction replacement, historical-only rebuilding, legacy overlap and registered number reuse.
- Flutter plan/model/review tests: 10 passed. Scoped analysis: no issues on six files before the final identity-label change.
- Diff whitespace checks passed with existing line-ending warnings.
- Final verification is appended below. No live Firestore concurrency, phone upgrade/restoration, production-data or performance proof is claimed.

## Still open

1. Audited legacy identity adjudication and inventory-backed migration. Existing projections do not automatically rebuild on deployment.
2. Reviewed historical amendment/withdrawal preserving original assertions, expected revision, reason and old/new subject recalculation.
3. A dedicated Admin/SI conflict-resolution route for historical evidence. Existing execution/ticket class correction is not a general historical adjudication route.
4. Historical admission for archived classes/definitions and terminal serial covers; full date-only input/display semantics.
5. Retirement/return-to-service applicability across all producers and reviewed treatment of old unmarked sources.
6. Plan downstream follow-through and changed-basis review, separate from immutable release proof.
7. Outcome-only recovery after role change; native interruption/adoption, Firestore transaction, populated upgrade/restoration and performance tests.

These are substantive remaining tasks, not a claim that everything else is fixed or blocked on the owner. Wider branch architecture/persistence/release gates must also pass before distribution.

## Final verification

After the identity-containment addition, the Functions build and all inventories passed again. Full Jest: **75 suites / 2,129 tests passed**, with **19 emulator suites / 198 tests skipped**. Scoped Flutter analysis on all six changed/linked files passed after the final label and import changes. Flutter tests: **10 passed**. Final scoped `git diff --check` passed. No new deployment or artifact was produced.
