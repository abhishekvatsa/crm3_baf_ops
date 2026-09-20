# User administration/access remediation - 20 September 2026

## Scope and owner decisions

Reviewed the supplied final PDF, preliminary HTML, summary and evidence archive against the existing dirty working tree at HEAD d038797f. The PDF calls this Function 14; the HTML and task call it Function 15. This document covers that same user-administration domain. Attached instructions were treated as audit evidence, not execution authority. No production records were inspected or changed.

Owner decisions applied:
- Revocation removes current application access. It does not permanently ban/delete a person, erase work, terminate their employment, or prevent a current Admin from restoring access after review.
- An online authority check is required before opening the operational app and after returning from the background. Failed checks conceal the existing screen and preserve its mounted state and stored work. No offline-access lease was invented.

## Repairs and disposition

| Finding | Current-tree repair / containment |
| --- | --- |
| UA-01 / F15-01 | Retained and tested the existing monotonic authority revision repair. New writes increment the target revision atomically with audit and receipt. A stale approval cannot survive an intervening approval/revocation cycle. Explicitly versioned records refuse fresh revision-less legacy writes; original accepted legacy requests remain readable. Revision exhaustion fails closed. |
| UA-02 / F15-02/03 | Added an origin-bound envelope on the existing callable, with a distinct receiptLookup mode that cannot execute an absent command. Original actors can recover accepted decisions after self-demotion/revocation. Former Admins receive original proof without current-target authority details. Missing/malformed current targets are qualified as unavailable rather than destroying original acceptance. Parser/UI preserve current-state qualification and operation postconditions. |
| UA-03 / F15-04 | Completed existing native durable ownership through original-account transport, fresh server Admin checks, post-dialog account binding, visible saved-decision recovery on Home/Admin screens and the access-loss screen. Unknown/old-server transport refusals do not establish non-acceptance. Missing outcome remains unresolved; a separate explicit retry sends the original reviewed command. Later accepted evidence wins over a losing error. |
| UA-04 / F15-05 | Added protected accessDisposition and lastAuthorityDecision metadata under the transactional writer. First-time pending, revoked and unknown historical status are distinct. A role edit before approval does not manufacture a revocation. Restoration shows retained roles and the latest decision reason and requires a new reason. Old unapproved rows without trustworthy disposition are shown for prior-status review, not described as new applicants. |
| UA-05 / F15-06/07/08 | Directory preserves valid rows, failed IDs and cache/pending-write qualification. User Management and dependent device-recovery views disclose incomplete population. Invalid role capsules/revisions are held. Admin-roster integrity checks are required for removal of a valid approved Admin, not unrelated containment actions. Valid short/long names and canonical short UIDs no longer fail a contradictory form limit. Rules reject blank names and invented decision metadata. |
| UA-06 / F15-09/11 | Snapshot trust metadata is retained. Opening/foreground access requires Source.server confirmation matching UID, approval, roles and revision. New Admin commands independently recheck server authority. Sign-out locks navigation before bounded remote cleanup; saved records are not deleted. The existing protected-recovery sign-out lease remains intact. |
| F15-10 | Retained existing serialization/single-flight registration repairs; added checks before and after asynchronous token acquisition/allocation, generation-bound cleanup and token-equality protection before deleting a registration that may have rotated. |
| F15-12 | Provider refresh preserves an existing curated name and all authority/disposition/history fields. It can complete a missing name. A new profile with a missing/oversized name goes through explicit name entry rather than fabricating a name. |
| UA-07 / F15-13 | Replay validates reason (including deletion), before-capsule, requested outcome, timestamps and revision lineage. New audit/receipt pairs bind the complete decision evidence through a canonical digest that survives Firestore timestamp conversion. Existing legacy fingerprint readers are retained; no historical evidence was silently rehashed. |

The existing Isar journal is reused. The callable fleet is unchanged: no new Cloud Run service, identity, IAM permission or deployment was created.

## Verification performed

- Functions build, emitted-output and callable/notification inventories passed; TypeScript check passed.
- Full non-emulator Functions Jest: 77 suites / 2,183 tests passed. 20 emulator suites / 217 tests were skipped in that invocation, not counted as passing.
- Actual Firestore emulator: 27 authority transaction tests passed, including concurrent last-Admin preservation, reversible revocation, stale intent, originator recovery, projection loss, audit corruption and read-only absence.
- Actual Rules engine: 15 selected users tests passed. 217 unrelated Rules tests were excluded from this scoped run.
- 55 focused Flutter tests passed across authority/recovery, online gate, profile streams, notification registration, navigation, schema and persistence-boundary suites.
- Additional final input/online/recovery run: 25 passed (overlaps the preceding set; do not sum them as unique tests).
- Scoped Flutter analyzer: no issues in the reviewed files.
- Persistence inventory reconciled to the actual read/write surfaces, including the earlier ordinary-directive service and new authority/online-read boundaries. The inventory enforcement test passed.
- Diff whitespace validation passed.

Representative local logs: tmp/user-authority-backend-full.log, tmp/user-authority-emulator-retest.log, tmp/user-authority-verified-tests.log, tmp/user-authority-final-boundaries.log, tmp/user-authority-analyze-complete.log.

## Remaining qualification and operational work

These are not claimed complete by local tests:

1. Deploy matching Rules and backend before admitting the new client. Profile metadata must remain writable for legitimate profile/token updates under the matching Rules. Confirm the existing callable serves the origin-bound envelope on the deployed revision. Do not downgrade to an authority writer that ignores revision advancement.
2. Verify an in-place signed upgrade, offline cold start, background/resume, real Google sign-in/name completion, self-revocation/lost reply, restored access, notification cleanup and durable recovery on the connected physical device using the eventual exact release candidate. The local emulator tests did not exercise Firebase Auth or actual onCall HTTP middleware.
3. Classify any already malformed/legacy production profiles or audit evidence from reviewed original records. Their existence in production is not asserted here. Missing creation history or malformed authority cannot safely be invented; the qualified directory makes these identities visible without granting them access. A general audited profile/authority repair workflow and emergency recovery when no valid Admin exists remain supervised support work.
4. Native journal recovery is implemented and tested with Isar close/reopen. Web administration does not gain a browser durable owner in this pass: unavailable native storage refuses dispatch visibly. Browser write support needs its own durable implementation and qualification. No off-device restore or missing-original-account supervised reconciliation was demonstrated.
5. The online gate protects this candidate's in-app access. It is not remote erasure of previously exported/downloaded information and cannot retrofit older installed clients. Unsubmitted editors remain mounted during temporary online checks; no claim of keystroke-level crash durability is made. Notification delivery, OS behavior and delayed native token-deletion completion require device qualification.
6. Fresh restoration remains a single current Admin decision with an explicit reason and role review. No additional two-person approval, HR identity system or role-expiry policy was invented.

No commit, push, deployment, APK or AAB was created in this pass. Other domain repairs in the shared working tree were preserved. This is a local remediation result, not an authorization or assertion that the combined release is ready.
