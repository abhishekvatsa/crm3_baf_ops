# Morning Review saved-command recovery

This implementation retains one unresolved command per original account in the native submission journal. It saves the entire `mutateAssetHierarchyV2` envelope before dispatch, including the original request ID, operation, supplied session and all entered fields. Opening or refreshing Morning Review reads the saved record; only **Check saved change** dispatches another claimed attempt. New changes cannot replace an unresolved command.

A validated acceptance receipt is stored as `acceptedPendingAdoption` before checking its business record. Subsequent checks read the permitted server-side session, participant, entry, action, concern, concern check or finalized document. They do not resend an accepted command or probe its mutation endpoint. Only the non-authoritative `idempotentReplay` response flag is normalized to `false`, so two responses confirming the same acceptance cannot conflict; every authoritative response field is preserved. This stores canonical acceptance evidence, not raw transport bytes. Exact subject identity and immutable accepted evidence are checked; later legitimate versions are supported. The private mutation-receipt collection remains unreadable to the app and is not queried. The original account must still be approved and current before dispatch or adoption. A valid late receipt is saved even if the account changes while the request is in flight.

## Earlier-day opening and not-held requests

`START_MORNING_REVIEW` and `RECORD_MORNING_REVIEW_NOT_HELD` intentionally omit a session ID: the existing server derives the India plant day. The client does not insert a session or version into those frozen commands. Their saved aggregate identity is the request ID until the authoritative receipt identifies the session. The receipt's session must agree with its original server commit day.

An unresolved opening/not-held request is not dispatched after the local India day has changed from its native preparation timestamp. This is a conservative guard against creating a different day's meeting. It uses the device clock, which is not server-time authority; clock problems can therefore require support review. An accepted saved receipt can still be read back and adopted across day changes. A never-claimed intent has an explicit **Cancel unsent change** action; native storage refuses that cancellation once any dispatch claim has occurred. An uncertain earlier-day attempt remains preserved and blocked for review. There is currently no nonmutating client receipt-lookup endpoint to settle that uncertainty automatically.

## Historical preference journals

Exact old preference strings, including malformed strings, are copied into review-only native custody without modifying or deleting their source keys. They are not assigned the currently signed-in account as an invented original owner. The app does not automatically replay or reactivate them. Multiple old unresolved slots remain a review issue rather than being silently reduced to one. Support must determine the original account, exact request, acceptance evidence and business outcome before any future migration or remediation is authorized.

Draft editors retain their fields through account-refresh errors and switches while the form remains open. Submission durability starts when the native journal has successfully saved the command; an unfinished editor is not a persistent draft across process termination.

## Verification

- Native restart/claim/receipt/actor/day-boundary cases run against actual Isar storage.
- `tool/test_support/capture_morning_review_durable_fixtures.cjs` captures all 13 operations from the compiled real server handler using its isolated transaction test harness. `test/fixtures/morning_review_durable_actual_handler.json` records source, compiled-handler and harness hashes, exact receipts and subjects, plus 12 subjects after later legitimate changes. No production calls are made.
- Widget tests verify that screen reconstruction and refresh show saved content without dispatch; an explicit check restores the original submission. Independent editor tests cover account error, account switch and return to the original account.
- No production deployment, data migration, receipt deletion or Rules change is part of this source implementation.
