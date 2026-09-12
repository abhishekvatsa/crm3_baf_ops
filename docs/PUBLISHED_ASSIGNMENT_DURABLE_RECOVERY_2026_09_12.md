# Published-template assignment saved-request recovery

This source change replaces the assignment screen's hash-only preference retry identity with a complete native submission record. It is a bounded consumer of the shared durable submission journal, not the full Package B maintenance-creation design.

## Saved intent and dispatch

Before a new assignment is dispatched, the app saves the complete `assignPublishedTemplateVersionV2` envelope: protocol version, original account, request ID, published package/version/hash, asset and optional physical identity, source plan/version, charge and remarks. The request ID is also the journal's aggregate identity until the server supplies its execution ID. One unresolved assignment per original account owns `publishedTemplateAssignment:<actorUid>`. Another request ID or changed form cannot replace that owner.

Opening the assignment screen discovers saved work and displays its fixed entries. Opening, refreshing or dismissing the screen does not resend it. **Check saved assignment** explicitly retries the same frozen envelope. The controller requires the approved original account, probes the exact V2 endpoint's capability before claiming an attempt, and checks the account again after asynchronous boundaries. The transport independently compares the frozen origin with the authenticated Firebase UID. The existing V1 service remains available for compatibility; this saved-request path uses V2 and has no second generic executor owner.

**Cancel unsent assignment** is available only for an intent with zero dispatch claims. Once a claim may have reached the server, cancellation cannot prove that no job was created; that request remains available for recovery or review. Editing an unfinished form is not a persistent draft: durability begins when native preparation succeeds.

## Accepted evidence and local adoption

The controller validates the receipt against the frozen request before storing acceptance. It checks the request and execution identity, original actor and assignment timestamp, published version/hash, physical asset, source-plan provenance, publication audit, and every returned module's parent and origin. Only the response's observation flag `idempotentReplay` is normalized to `false`. The stored value is a canonical acceptance receipt, not a byte-for-byte transport capture; authoritative fields are retained.

The receipt is retained as `acceptedPendingAdoption` before local business rows are changed. The execution, all returned modules and the reconciliation marker are then adopted in one Isar transaction. A missing collection, duplicate local identity, conflicting origin or local write failure rolls back that transaction while leaving the earlier accepted receipt available. Retrying an already accepted submission uses its saved receipt without sending the assignment again.

Compatible unsynced or strictly newer local rows are preserved. Clean older rows may advance to the validated returned projection. Clean rows at the same version must agree in their complete persisted business state; JSON object order and equivalent UTC timestamp spelling do not count as disagreements. A same-version conflict stays pending for review. Nested physical-asset and Inner Cover position provenance must also agree. The original account is checked within adoption and after the awaited transaction, so a late account switch cannot receive the old account's successful result.

The assignment handler already replays the original request by returning its current execution and original module identities, without creating another job or rewriting its protected request receipt. Legitimate completion can change the execution's remarks. The V2 parser therefore permits that one difference only for a later completed, active, non-cancelled projection with the same original account and request provenance. Other changed assignment meaning remains an error. Source-plan authority/version guards are preserved; no unsupported released-plan-to-completed transition was introduced.

Adoption of a previously retained receipt is not a fresh Firestore server read. It can restore the accepted baseline while preserving compatible later local work. Ordinary business synchronization remains responsible for later remote changes. This differs from consumers that require a separate exact server subject read before marking reconciliation.

## Historical preference evidence

Old preference strings, including malformed strings and hash-only records, are copied byte-for-byte into review-only native custody. Their original preference keys are retained. The current account determines only the resource where those old keys were found; it is not invented as the original actor of unproven bytes. No frozen legacy payload is reconstructed or silently upgraded to V2.

These legacy rows block a new assignment for that resource until an authorized recovery can establish the original request and outcome. Multiple retained historical slots remain a review issue. There is no operator button to clear or replace this evidence. Support should identify the original account, request, accepted execution/modules and publication/source-plan evidence before defining any remediation; deletion of a preference or native journal row is not an acceptance check.

## Verification and limits

- `test/published_template_assignment_submission_test.dart`: 15 native Isar cases pass, including lost response and reopen, adoption rollback and receipt recovery, newer dirty work, clean same-version agreement/contradiction, legacy exact bytes with unknown actor, frozen payload ownership, capability/account checks and later completion remarks.
- `test/published_template_assignment_origin_bound_test.dart`: six transport/parser cases pass, including the exact V2 envelope, V1 compatibility, actor mismatch, unsupported input and bounded completed-projection validation.
- `test/published_template_assignment_saved_ui_test.dart`: three widget cases pass for fixed entries, no automatic dispatch, original-envelope retries, account masking and leaving while a response is pending. Its in-memory adapter and uncertain transport are UI test tools, not production fallback storage.
- The combined durable core/campaign/assignment regression run passes 90 tests. After replacing an unnecessary transitive equality dependency, the assignment native 15 cases were rerun and passed; scoped analysis of 16 relevant files is clean. Logs are under `build/review-20260912/assignment-durable-final.txt`, `assignment-adopter-final.txt` and `assignment-durable-analyze.txt`.
- `functions/test/publishedTemplateAssignment.test.js`: 51 actual-handler host cases pass. New tests invoke assignment A, seed later permitted completion/module projection fields, then invoke replay A and assert the same identities, later state, unchanged protected receipt and zero replay writes. These tests do not invoke the complete closure-handler journey. The existing assignment backend source was not weakened or changed.

Local database close/reopen tests are not evidence of an Android process-kill, physical-device upgrade, production deployment or production Firestore cache behavior. The new schema and V2 capability deployment/rollback requirements are covered by `docs/SYSTEM_ASSESSMENT_R04_COMPATIBILITY_AND_ROLLBACK_2026_09_12.md`. Release and physical-device validation remain separate gates.
