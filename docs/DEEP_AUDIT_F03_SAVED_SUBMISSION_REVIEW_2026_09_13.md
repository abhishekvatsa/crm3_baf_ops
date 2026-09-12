# F03: saved-submission administrative review

This is candidate source behavior, not evidence of deployment or activation.

The four existing origin-bound V2 callables now expose `savedSubmissionReview.v1`. An approved Admin can inspect retained evidence and make an explicit, reasoned decision. This route does not reconstruct an unknown payload, assign an unknown original actor to the current user, or adopt an unrelated accepted receipt as a successful local submission.

## Decision meanings

| Result | Meaning | Business effects |
| --- | --- | --- |
| Receipt inspection | A supported receipt currently exists, or none was found; no decision is made. | None. |
| `reviewedExisting` | The Admin reviewed the existing receipt evidence against the retained local evidence; the original request now has a permanent accepted-result execution hold. | Does not resend, cancel or adopt the original operation. The hold prevents renewed execution after receipt expiry. |
| `cancelled` | Further execution using the original domain and request ID is permanently fenced after explicit review. | Does not undo any earlier effect and does not prove the request was never accepted. |

Receipt absence alone is insufficient to conclude nonacceptance. Morning Review receipts can expire. Before closing an absent-receipt hold, the Admin must review the retained evidence and relevant business records. Unknown original actors remain `null` in the request and decision.

## Transaction boundary

`withSubmissionRecoveryFence` wraps the database passed into the existing V1 callable implementations. Every recognized original transaction reads a hold for its domain/request ID inside that same transaction, before quota or business writes. V2 business submissions delegate to those V1 implementations. The hold is therefore checked again at the actual write transaction, including for a request that started before administrative finalization. Its outcome distinguishes acceptance from cancellation.

Finalization reads the current approved Admin, existing decision, global hold and receipt in one transaction. Its token binds the reviewer, original actor (including unknown), retained evidence SHA, reason and observed receipt hash or absence. Changed acceptance evidence requires a fresh inspection. A concurrent original commit and finalizer cannot bypass the shared transaction conflict. A live receipt matching an accepted-result hold is expected; a receipt beside a cancellation hold, or a receipt differing from the accepted-result hold, remains an investigation case.

The six review domains are Morning Review, burner evidence (round and directive completion), Inner Cover acceptance, quality-monitoring creation, published-template assignment, and inspection-campaign creation. Either reviewed outcome reserves its ID across the entire existing receipt namespace: changing an Inner Cover, quality or workflow operation cannot reuse it for business execution. This does not enable administrative review of additional operation types.

## Retention, restart and compatibility

Review decisions and fences have no TTL. They are server-owned records; clients, including approved Admin clients, cannot directly read, list, create, update or delete them. The authenticated callable provides the allowed review result.

An exact completed decision can be retrieved by inspection after a lost reply when its matching permanent hold remains valid. The original stored reason is returned unchanged even if a different reason was entered for that inspection. A finalization using a different reason cannot overwrite the decision. This retrieval remains available after the underlying receipt expires and after new finalization is disabled. A prior accepted-result decision missing its matching hold requires specialist reconciliation; it is not silently rewritten or converted into cancellation. Different evidence cannot convert an expired accepted-result hold into a fresh cancellation.

The client stores review outcomes separately from ordinary command acceptance. The new local compatibility floor is 12. A rollback must understand or preserve these local rows and the permanent backend fences; returning to a reader that mistakes administrative review for successful command adoption is not compatible.

## Activation hold

Read-only inspection and retrieval of an already completed matching decision do not require activation. Creating either final outcome requires `submission_recovery_controls/activation`, which defaults to unavailable. The record must identify all six domains, all eight guarded V1/V2 callable names, an exact source commit and evidence SHA, a nonfuture verification time, drained legacy workers, and a rollback that retains both kinds of hold enforcement.

Before enabling that control, separately verify deployment/readback of the complete guarded callable set, actual drain of older workers, release capability responses, retained-data compatibility and compatible rollback custody. A request timeout alone does not prove old code has stopped. A partial deployment or an old unguarded rollback cannot establish permanent review finality. No activation record is created by the implementation or its tests; tests use isolated memory/emulator fixtures only.

## Verification surfaces

- `functions/test/submissionRecovery.test.js`: strict receipt shape, identity, exact wire shape, immutable reason, TTL survival, tamper/collision, activation and lost-response checks.
- Actual existing producer suites feed generated Morning Review v1/v2, round/compliance, Inner Cover, quality, assignment and campaign receipts through administrative inspection. The genuine frozen legacy quality receipt is also retained unchanged.
- `test/fixtures/saved_submission_review_actual_handler.json`: generated by the actual backend review function and consumed by the native service tests; binds the same ordered legacy evidence bytes to exact inspection/finalization responses.
- `functions/test/submissionRecovery.firestoreEmulator.test.js`: real exported V1/V2 refusal, read-only lookup, account rejection, persisted receipt drift and overlapping transactions.
- `test/submission_recovery.rules.test.js`: server-control collection denial for approved Admin, operator and unauthenticated clients.
- Callable inventory admission remains restricted to the exact origin-bound helper, approved-account read, original V1 delegation and centrally validated recovery/lookup callbacks; unsafe variants are rejected.

The retained review hash uses fully tagged canonical nodes, preserving timestamp nanoseconds, dates, arrays, map keys and scalar types. This is a new review protocol. Existing business request fingerprints and historical business receipts are not rewritten.
