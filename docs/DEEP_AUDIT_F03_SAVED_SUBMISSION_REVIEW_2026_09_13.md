# F03: saved-submission administrative review

This is candidate source behavior, not evidence of deployment or activation.

The four existing origin-bound V2 callables now expose `savedSubmissionReview.v1`. An approved Admin can inspect retained evidence and make an explicit, reasoned decision. This route does not reconstruct an unknown payload, assign an unknown original actor to the current user, or adopt an unrelated accepted receipt as a successful local submission.

## Decision meanings

| Result | Meaning | Business effects |
| --- | --- | --- |
| Receipt inspection | A supported receipt currently exists, or none was found; no decision is made. | None. |
| `reviewedExisting` | The Admin reviewed the existing receipt evidence against the retained local evidence. | None; does not resend or adopt the original operation. |
| `cancelled` | Further execution using the original domain and request ID is permanently fenced after explicit review. | Does not undo any earlier effect and does not prove the request was never accepted. |

Receipt absence alone is insufficient to conclude nonacceptance. Morning Review receipts can expire. Before closing an absent-receipt hold, the Admin must review the retained evidence and relevant business records. Unknown original actors remain `null` in the request and decision.

## Transaction boundary

`withSubmissionRecoveryFence` wraps the database passed into the existing V1 callable implementations. Every recognized original transaction reads a fence for its domain/request ID inside that same transaction, before quota or business writes. V2 business submissions delegate to those V1 implementations. The fence is therefore checked again at the actual write transaction, including for a request that started before cancellation.

Finalization reads the current approved Admin, existing decision, global fence and receipt in one transaction. Its token binds the reviewer, original actor (including unknown), retained evidence SHA, reason and observed receipt hash or absence. Changed acceptance evidence requires a fresh inspection. A concurrent original commit and cancellation cannot both succeed. A live receipt and fence found together are an investigation hold.

The six review domains are Morning Review, burner evidence (round and directive completion), Inner Cover acceptance, quality-monitoring creation, published-template assignment, and inspection-campaign creation. A cancelled ID is reserved across its entire existing receipt namespace: changing an Inner Cover, quality or workflow operation cannot reuse it to create acceptance beside the fence. This does not enable administrative review of additional operation types.

## Retention, restart and compatibility

Review decisions and fences have no TTL. They are server-owned records; clients, including approved Admin clients, cannot directly read, list, create, update or delete them. The authenticated callable provides the allowed review result.

An exact completed decision can be retrieved by inspection after a lost reply. The original stored reason is returned unchanged even if a different reason was entered for that inspection. A finalization using a different reason cannot overwrite the decision. Decisions remain available after an underlying receipt expires. A later explicit review may fence further execution of the same request without erasing an earlier accepted-history review.

The client stores review outcomes separately from ordinary command acceptance. The new local compatibility floor is 12. A rollback must understand or preserve these local rows and the permanent backend fences; returning to a reader that mistakes administrative review for successful command adoption is not compatible.

## Activation hold

Inspection and review of an existing receipt do not require cancellation activation. Finalizing receipt absence requires `submission_recovery_controls/activation`, which defaults to unavailable. The record must identify all six domains, all eight guarded V1/V2 callable names, an exact source commit and evidence SHA, a nonfuture verification time, drained legacy workers, and a rollback that retains fence enforcement.

Before enabling that control, separately verify deployment/readback of the complete guarded callable set, expiry/drain of older in-flight workers, release capability responses, retained-data compatibility and compatible rollback custody. A partial deployment or an old unguarded rollback cannot establish cancellation finality. No activation record is created by the implementation or its tests; tests use isolated memory/emulator fixtures only.

## Verification surfaces

- `functions/test/submissionRecovery.test.js`: strict receipt shape, identity, exact wire shape, immutable reason, TTL survival, tamper/collision, activation and lost-response checks.
- Actual existing producer suites feed generated Morning Review v1/v2, round/compliance, Inner Cover, quality, assignment and campaign receipts through administrative inspection. The genuine frozen legacy quality receipt is also retained unchanged.
- `test/fixtures/saved_submission_review_actual_handler.json`: generated by the actual backend review function and consumed by the native service tests; binds the same ordered legacy evidence bytes to exact inspection/finalization responses.
- `functions/test/submissionRecovery.firestoreEmulator.test.js`: real exported V1/V2 refusal, read-only lookup, account rejection, persisted receipt drift and overlapping transactions.
- `test/submission_recovery.rules.test.js`: server-control collection denial for approved Admin, operator and unauthenticated clients.
- Callable inventory admission remains restricted to the exact origin-bound helper, approved-account read, original V1 delegation and centrally validated recovery/lookup callbacks; unsafe variants are rejected.

The retained review hash uses fully tagged canonical nodes, preserving timestamp nanoseconds, dates, arrays, map keys and scalar types. This is a new review protocol. Existing business request fingerprints and historical business receipts are not rewritten.
