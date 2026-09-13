# Reviewed Firestore Rules deployment evidence — 13 September 2026

The pre-build module-reopen repair requires a narrow Rules change: a currently approved supervisor can read their own immutable server reopen audit by ID. The previous backend closure protocol admitted only deployments whose Rules were already exact. That protocol cannot truthfully certify deployment of changed Rules by retaining its old no-mutation flags.

`tools/release/reviewedFirestoreRulesDeployment.js` adds an offline verifier for an explicitly approved successor Rules-only deployment. It performs no deployment, approval or live collection. Historical approvals and receipts keep their original no-Rules-mutation meaning; this change does not amend or relabel them.

## Required evidence

The new path requires the existing exact-source, immutable approval and five-job post-merge CI authority. Its additional declaration binds the production project, default database, prior Rules identity, new Rules bytes from the exact Git source, complete index/field-override inventory and the approved command checkout. It names a future command evidence file without putting a circular future digest in the approval.

The pre-approval and immediate-before readbacks must be actual OBSERVE receipts. The old active Rules are the sole permitted difference. Every other source, Rules identity, index readiness and field-override check must be explicitly true; missing or null checks cannot pass. No index deployment is admitted.

The command receipt must retain the exact `firestore:rules` invocation, actual zero exit, unambiguous raw CLI JSON, start/completion times, and clean exact-main source observations before and after execution. Its private checkout path is represented in public evidence only by its digest. The raw result must come from the command; copying an expected success object is not evidence.

The final STRICT readback must begin after command completion and prove the active Rules bytes and complete unchanged index/override inventory. The collector now records collection start before any source or network read, as well as completion afterward. The verifier binds those times to immutable approval custody and the closure time, including sub-millisecond ordering, and rejects future or reversed intervals.

Only this fully verified path admits true Rules-deployed/security-Rules-mutated flags. The existing invoker-IAM checks, service-account restrictions, App Check boundary, business-data restrictions and separate artifact/device/promotion requirements remain enforced.

## Verification boundary

Tests use synthetic observations with real Git objects, immutable test approval/CI custody, the actual collectors' adjudicators and the complete production source-authority verifier. They are clearly marked as synthetic and do not establish a real deployment. Negative cases cover scope, target, source, checkout, raw output, custody, chronology, Rules/index drift and false mutation claims; their positive controls must pass before a refusal is counted.

Local verification passed all 102 tests across the complete staged source-authority, Rules/index collector and current-runtime-authority suites, with no failures or skips. The companion helper copies passed 19 separate offline tests and Node/embedded-JavaScript/PowerShell syntax checks. The full generator, deployment command and production closure assembler were not executed with operational inputs. Local logs are retained under `output/build28-release-20260913/` in the isolated preparation checkout.

The companion operator helpers are prepared locally and remain unexecuted. Actual current-source preflight, a concrete deployment decision, immutable custody, execution and final readback are still required. This source change does not authorize a deployment or create a release-ready APK.
