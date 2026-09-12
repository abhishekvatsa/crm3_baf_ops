# Inspection physical-subject and follow-up repairs

This records the F01/F02 source repairs against the 12 September deep audit. No release artifact, deployment, installation or business-data migration is claimed.

## Corrective work identifies the physical subject

The shared backend predicate in `inspectionPhysicalSubject.ts` is applied when linking an issue and when making a **new** resolved-finding verification. Numbered/custom assets require the same canonical class and instance identity. Inner Covers require the original ticket association's cover ID and serial; its Base is historical context. A ticket for another cover that previously occupied the same Base is refused. The same cover's canonical repair can remain relevant after relocation, provided both original snapshots are internally consistent. Missing or malformed historical identity requires review, without guessing from the number.

The actual canonical maintenance-ticket producer is exercised by the tests. Administrative closure, deleted/unresolved tickets and malformed identity still fail the existing meaningful corrective-completion boundary. Previously accepted same-command receipts remain replayable; the patch does not rewrite earlier links, receipts, findings or chronology.

## Explicit context review preserves the original campaign

`revalidateInspectionTargetContext` permits an approved campaign manager to review the same physical asset after a registry revision or the same Inner Cover after relocation. It checks the frozen definition's exact scope, active original component/class, original physical ID/serial, the campaign version, the prior review revision and the exact server context shown to the manager. `reviewerUid` is frozen in the command and must equal the authenticated reviewer, including when the normal workflow journal retries an uncertain request.

The new client checks the fresh `inspectionTargetContextRevalidation.v1` capability before dispatch. Unsupported deployment, account verification failure or account switch withholds the command. The dialog retains the submitted ID and payload on an uncertain result; no new retry owner is introduced. The ordinary online workflow executor remains responsible for retaining uncertain commands.

The original target/key, campaign definition/baseline and readings remain intact. A separate immutable `inspection_target_audits` record binds the successor's reviewer, reason and context. Later observations must specify the approved review revision and carry its audit ID; missing or changed audit evidence blocks them. The original latest-reading pointer survives a review, so an earlier historical reading cannot replace the later current evidence. A relocated reading cannot predate its recorded installation.

This is not a serial-change mechanism, automatic rebinding, acceptance of unresolved repair, or automatic migration of legacy evidence. Users of the campaign must upgrade before its first review: Build 27 cannot perform reviewed follow-up and cannot decode a relocated review-aware observation. Capability presence proves backend support, not fleet adoption.

## Corrections retain the recorded historical context

The final PR review identified a missing distinction: correcting the current
certified reading after a later context review must retain that reading's
recorded installation. Applying the campaign's latest context could reject its
original observation time or attribute the correction to a different linkage.

The command still supplies the current campaign/context revision as a
concurrency precondition. The server derives the correction's physical context
from the superseded immutable observation and the original campaign baseline
or that observation's authenticated historical review audit. It retains the
original linkage, context revision, audit and component metadata. A historical
Inner Cover installation may now be inactive; its durable identity and
installation/removal interval must still validate both the original and
corrected event time. Missing or contradictory evidence remains refused.
The current-certified-reading and correction-permission checks remain in force.
The campaign's latest reviewed context and superseded observation remain intact.

The editor starts with the original observation time, labels its original
location and preserves the recorded component name/version/path even if the
current component was renamed or retired. Production decoder/report tests use
an actual workflow-handler-produced correction from review revision 1 while
the campaign is at revision 2, including revision 0 history. The 23 screen tests
and 11 decoder/context/explicit-selection tests pass; scoped analysis is clean.

The real Firestore emulator also exposed the existing context-audit comparison
of a native `performedAt` Timestamp with a parsed ISO string. The correction
normalizes persisted instants before comparison, including the observation's
`linkedAt`, while retaining the exact identity and audit checks. Memory-only
fixtures did not expose that storage representation difference.

Final focused backend evidence: **88 host tests and 18 real Firestore emulator
tests passed**, including four new native-storage/history cases. Logs are
`build/review-20260912/inspection-correction-host-final.txt` and
`build/review-20260912/inspection-correction-emulator-final.txt`. The earlier
native failure is retained in `inspection-correction-emulator-before.txt` in
the same directory. The emitted-source/callable/notification inventories and
Functions build pass. This is emulator evidence, not a production deployment.

Observation draft serialization and its existing dialog/dispatch function now
share a small companion part. The editor and parent screen remain below their
unchanged architecture limits (1,477/1,550 and 2,456/2,500 lines). A02 passes;
all 34 affected Flutter checks pass after extraction, with clean analysis.

## Verification scope

`functions/test/inspectionPhysicalContext.test.js` executes the compiled workflow handlers and a real registry create/update using one transactional document store. It covers the adverse reading → canonical ticket → actual resolution → close → registry revision → reopen → refused stale reading → manager review → follow-up → same-finding verification journey. Installed-cover cases prove original serial continuity across Base relocation and refusal of a different serial, stale review/version, wrong host, incompatible definition, retired component, missing/tampered audit and pre-installation reading. Existing inspection campaign tests retain their historical receipt replay control.

Flutter model/reader/UI tests cover unchanged original target decoding, exact reviewed context, malformed/rebound evidence, server-only original-serial lookup, mandatory reason, fresh capability checks, frozen ambiguous retries, and account changes across asynchronous lookup/capability checks. Model, report and existing audit-board regressions are included. These are local host/widget tests; real production concurrency, device lifecycle and the exact eventual APK remain separate release gates.
