# PR #40 — Published Assignment Concurrency Source Remediation

## Purpose

This change corrects the reproduced race in published-template assignment without changing release identity, signing custody, canonical reconciliation, deployment state, or production data.

## Reproduced defect

The governed pre-fix stress harness executed 325 concurrent assignment iterations and recorded 62 rejected iterations. The failure occurred because a collection query and related writes were performed within the same Firestore transaction while concurrent assignments changed the queried collection.

## Source correction

`functions/src/publishedTemplateAssignment.ts` now derives the equipment-status document identity and performs a point read within the transaction. Workflow facts remain authoritative: the transaction still rejects inconsistent or ineligible equipment state and does not weaken idempotency, referential integrity, or maintenance-workflow projections.

## Regression coverage

The source-specific proof requires all of the following before repository mutation:

- complete Functions build and unit suite with zero failures;
- whole-Functions transaction-scope scan with zero query/write-same-collection findings;
- all 122 Firestore Rules emulator tests;
- all 29 governed Functions emulator tests, including six published-assignment regression cases;
- the same 325-iteration concurrency matrix that previously produced 62 failures, now with zero failures;
- exact four-path diff custody;
- commit and push only to the existing PR #40 branch;
- PR #40 remaining open and draft after push.

## Deliberate exclusions

This source-remediation execution does not inspect, modify, or certify:

- Firebase registration receipts or OAuth/signing policy;
- production-release policy;
- canonical reconciliation manifests;
- Flutter or Android builds;
- release signing, tagging, deployment, App Check, or production data.

Those remain independent PR-ready, merge, release, and deployment gates. Passing this source proof authorizes only a bounded source commit and push to the existing draft PR.

## Residual identical-request transient and bounded retry

The first complete source-only emulator execution proved 122/122 Rules tests and 29/29 governed Functions emulator tests, and reduced the governed stress result from 62/325 failures to 29/325. All 29 residual failures were confined to identical concurrent request IDs and surfaced as Firestore code `3` with the exact message `Transaction is invalid or closed`; all 175 distinct-request iterations passed.

Because the assignment request identity is protected by an atomically written idempotency receipt, the implementation now performs a bounded retry only for that exact transient signature. Unrelated `INVALID_ARGUMENT` failures are never retried, and exhaustion fails closed with `assignment-transaction-retry-exhausted`. Unit tests pin the exact-match, non-match, and exhaustion behaviour; an emulator burst test pins twelve identical concurrent calls to one execution and one equipment projection.

## Unit-suite proof interpretation

The v3 source-only execution returned process exit code 0 with 249 passed, 30 skipped and 279 total tests. The additional skipped item belongs to the emulator-only population and is not a functional failure. The source gate therefore requires zero failures, internally consistent Jest totals and no regression below 249 passed tests; skipped/total categories are retained as evidence rather than frozen as correctness predicates.
