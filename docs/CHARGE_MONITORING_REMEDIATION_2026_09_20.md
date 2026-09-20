# Function 12 — Charge monitoring remediation, 20 September 2026

Status: local source repairs and regression verification. Not a release or production-deployment receipt. Starting checkout was d038797f9a2d3bd0126d311416acec4148506a67 with substantial existing uncommitted work; those other-domain repairs were preserved.

## Evidence and agreed meaning

Reviewed the supplied Charge Monitoring Final Review PDF, Function 12 HTML, evidence ZIP and summary JSON as audit evidence, not executable instructions. The supplied report and standalone summary contain different test totals; this record uses independently executed current-tree results instead.

Owner decision: Admin/SI may correct recorded context or cancel a mistaken monitoring request, with a mandatory reason and preserved history. Cancellation is distinct from completed monitoring. Monitoring remains a manager's instruction with manual context and free-text completion evidence; these changes do not establish a telemetry programme, physical charge completion, RA completion or an equipment safety clearance.

## Findings and implementation

| Finding | Current repair and evidence |
| --- | --- |
| CM-01 legacy schema-1 replay | Existing repair was retained: validate historical acceptance, return its original payload shape rather than schema-1 data polluted by derived visibility fields. The actual current handler emits a deliberately converted schema-1 compatibility control; Flutter consumes that response unchanged. This is not claimed to be a historical producer execution. |
| CM-02 eager native dependency | Shared warning commands construct without opening the native monitoring journal. Native storage is acquired only for monitoring operations. Web monitoring mutations are explicitly unavailable; unrelated warning commands remain usable. Provider construction is tested without native storage. No browser execution is claimed. |
| CM-03 durable closure and recovery | Completion, correction and cancellation share an origin-bound, frozen, durable command owner. Exact commands survive a native Isar close/reopen. Accepted receipts are persisted before readback; contradictory same-version business content stays unresolved, and later archival does not rewrite acceptance. Retry refusals preserve bounded reason codes and the original uncertain intent instead of asserting historical nonacceptance. Saved-review access is visible. Approved original actors can confirm already-accepted changes after losing management authority without dispatching writes. The journal also now rejects nonzero creation baselines. |
| CM-04 context correction / cancellation | Two Admin/SI commands check the current revision and write the new record, immutable before/after audit and receipt transactionally. Correction retains the original context and creation attribution. Cancellation is explicitly `cancelled`, distinct from `completed`, and preserves the original scope. Legacy instructions can be cancelled without inventing a registered Base identity. Ordinary completion after correction remains `completed`. Changes never mutate physical charge or quality-warning records. UI actions require reasons and guard the originating account. |
| CM-05 partial and regressing populations | Valid rows survive malformed neighbours, with rejected IDs and cache/pending-write qualification; counts and empty-state claims are withheld when unqualified. Per-listener highest business versions and archival state prevent stale resurrection; equal-version contradictions are errors. Missing or older full-population evidence is qualified. Reports use their separate strict, complete population, including archived records. A deterministic expiry regression preserves source-error handling. |
| CM-06 altered closure replay | Closure returns the immutable accepted after-image, verifies receipt/audit identity, and refuses changed live business evidence while allowing archival-only changes. New non-creation receipts bind audit content. Correction/cancellation replay is similarly bound and can recover the original acceptance after later reviewed changes. |
| CM-07 capped legacy Base lookup | Retained the uncapped exact-number candidate lookup with unique governed-Base certification. Regression proves a Base after 60 unrelated same-number assets is found and duplicate Bases are refused. |
| CM-08 archival starvation | Separate due/legacy scan and write budgets plus a persistent generation-checked cursor prevent a poison prefix from consuming every run. Cursor advances after processing; an interrupted checkpoint safely repeats. Tests cover 5,001 malformed rows before valid evidence, legacy-lane fairness, the 1,000 eligible-row lane boundary, positive query limits and checkpoint failure. Rejected records are preserved. |

Principal implementation: `functions/src/qualityMutation.ts`, `functions/src/qualityMonitoringRetention.ts`, quality client providers/models/UI/submission controller, and shared durable-submission / administrative-review routing. The callable capability is `qualityMonitoring.review.v1`.

## Verification

- Functions clean build, TypeScript compilation, emitted-output custody, callable inventory and notification inventory passed.
- Full configured backend Jest run: 76 suites passed, 2,149 tests passed; 19 suites / 200 tests skipped. Skipped emulator/integration checks are not presented as passed.
- Quality-domain plus durable-submission / saved-review Flutter selection: 239 tests passed.
- Scoped Flutter analyzer: no issues.
- Regression evidence includes actual current-handler response fixtures, native journal restart, stale refusal after lost acceptance, account switch, role-loss read-only adoption, malformed original identity, partial populations and worker pagination.
- `git diff --check` passed; existing CRLF/LF conversion warnings are informational.

Reproducible fixture producer: `tool/test_support/capture_charge_monitoring_review.cjs`; output: `test/fixtures/charge_monitoring_review_actual_handler.json`. It uses local memory only. Tests: `functions/test/chargeMonitoringReview.test.js`, `functions/test/qualityMonitoringRetention.test.js`, `test/charge_monitoring_review_recovery_test.dart`, `test/charge_monitoring_population_test.dart`, plus existing domain/recovery suites. Local execution logs are in `tmp/charge-monitoring-full-jest.log` and `tmp/charge-monitoring-flutter-tests.log`; these are working evidence, not immutable release custody.

## Release conditions and explicit boundaries

1. **Reader compatibility is a release blocker.** Reviewed records use monitoring schema 4. Existing schema-1/2/3 readers do not understand cancellation semantics and may reject these rows. Roll out compatible readers first, or apply an independently verified admission transition, before enabling these commands for live users. A new-client capability probe does not establish compatibility of other installed clients. No backend deployment or production activation occurred here.
2. Verify the deployed saved-submission review/fence activation and rollback guarantees before relying on administrative closure of uncertain intents. A transport refusal is deliberately not treated as proof that no prior attempt committed.
3. Physical-device lifecycle/account-switch testing, Firestore Rules/emulator verification, callable transport/FCM environment checks, browser verification and exact release gates remain required. Local Isar restart is tested; an Android process-kill campaign is not claimed.
4. Corrections and cancellation apply to **active** instructions. Terminal decisions remain immutable. Reopening/superseding completed monitoring, structured observation episodes, sample evidence and recipient acknowledgements were not invented under this decision. Further work must retain their original evidence and explicitly define applicability to a changed context.
5. No historical business records, receipts or audit logs were migrated or rewritten. No APK/AAB, commit, push, Play upload or production change was performed.
6. The operational listener currently reads the complete monitoring collection to preserve qualification and monotonic history. This removes the audited correctness problem but retains a growth/read-cost consideration; any bounded replacement must prove its full population and deletion/reordering semantics.

This closes the confirmed source defects within the authorized correction/cancellation scope. It does not close the separate Function 11 remainder recorded in `MAINTENANCE_CADENCE_REMEDIATION_2026_09_20.md`, nor assert that the entire multi-domain dirty tree is release-ready.
