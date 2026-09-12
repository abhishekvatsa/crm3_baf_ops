# Independent audit of merged main `86e06e7b` — 12 September 2026

**Scope:** the three commits merged after the corrected weakness sweep
(`2ae7cbb4`): `dc344469` (199 files), `4cfe5376` (36 files) and `2c2bd374`
(7 files), delivered as PR #362 and PR #363. Checked against their own claims,
the three findings ranked in the sweep, and new failure paths introduced by the
native durable-submission store.

**Nature of work:** read-only source review, independent reruns of the local
gates, and inspection of exact-head CI job steps. No handset (none is attached),
no production read, no deployment, and the Firestore emulator suites were not
rerun. A **derived** failure sequence follows from inspected control flow and was
not executed end to end.

| Class | Meaning |
| --- | --- |
| **Confirmed** | Verified in the exact source, test or CI record |
| **Derived** | Follows from inspected control flow; not executed |
| **Observation** | Measured property offered for judgement |

---

## 1. Verification of the merged work

The PRs' validation claims reproduce exactly.

| Check | Claimed | Independently observed |
| --- | --- | --- |
| Flutter suite | 2,530 passed, 1 skipped | **2,530 passed, 1 skipped, 0 failed**; analyzer clean |
| Functions host | 1,375 Jest + 75 Node | **1,375 passed, 130 skipped, 0 failed**; Node suites 10/10 and 44/44 |
| Canonical audit | 150/150 | **150/150** |
| Exact-main CI | five jobs passed | Run 34708315836 on `86e06e7b`: **all five jobs succeeded** |

**The CI result is materially better than before.** Earlier heads failed the
Flutter host job at step 4 and skipped analysis and tests. On `86e06e7b` every
step ran and succeeded, including the production-policy gate, `flutter analyze`,
the full `flutter test` suite and the no-loss regression spine. Engineering
verification is no longer blocked behind promotion readiness.

### Status of the three sweep findings

| Sweep finding | Status | Evidence |
| --- | --- | --- |
| **Account state** read without distinguishing its cases | **Fixed at the design level; not every site migrated** | New `CurrentActorAccess.resolve` checks `isLoading` and `hasError` *before* `valueOrNull`, and its tests pin the retained-value case: `AsyncError(...).copyWithPrevious(AsyncData(actor))` resolves to `verificationFailed` with no actor. The intake screen now uses it. Unguarded `ref.read(...).value` sites fell from 59 to 29 (§4) |
| **Campaign creation** minted fresh identity on retry | **Fixed** | Command and campaign IDs are frozen in native storage before dispatch; the UI calls `restore()` before offering a new campaign; a test replays the exact envelope and both original IDs after a lost response and a database reopen |
| **Operator messages** expose raw exception text | **Open** | Still 60 text-pattern occurrences; not in scope of these PRs |

---

## 2. Findings

### AU-01 — Intentional safety blocks defer to a review owner that does not exist

**Priority: high · Confirmed mechanism · Derived end-to-end sequence**

The native store deliberately refuses a new submission while any unresolved
submission shares its resource key. That is correct: it stops a replacement from
duplicating work whose outcome is unknown. The defect is that **there is no way
to resolve the blocking row.**

**What the store permits** — `durable_submission_repository.dart`:

- `prepare()` fails `resource-pending` while any row for the key `isUnresolved`,
  which includes `uncertain` and `needsReview`.
- `claim()` refuses `needsReview` outright; `uncertain` can be re-claimed, but
  leaves only by acceptance.
- `cancelNeverSent()` requires `state == intent` and `attemptCount == 0`, so
  anything ever sent cannot be cancelled.
- `markReconciled()` is called only after acceptance, in every owner.
- **No discard, abandon, resolve-review or mark-rejected operation exists
  anywhere in `lib/`, and no admin or diagnostics screen references durable
  submissions.** Only Inner Cover acceptance ever writes `rejected`.

So `needsReview` has **no exit in the codebase**, and `uncertain` exits only when
the server eventually accepts that exact frozen request.

**Blast radius, by resource key:**

| Domain | Resource key | One stuck row blocks |
| --- | --- | --- |
| Morning Review | `morningReview:<actor>` | **Every Morning Review operation** for that operator on that device — `_submitDurable` throws `prior-command-pending` for all of them |
| Published template assignment | `publishedTemplateAssignment:<actor>` | **Every new assignment** by that operator |
| Inspection campaign creation | `inspectionCampaignCreation:<actor>` | **Every new campaign** by that manager — "Create campaign" opens the saved dialog and returns |
| Quality monitoring creation | `qualityMonitoringCreation:<project>:<actor>` | That manager's monitoring creation in the project |
| Burner rounds and compliance | `burnerEvidence:<furnace>` | That furnace's rounds and compliance |
| Inner Cover acceptance | `innerCoverAcceptance:<cover>` | That one cover — and refusals correctly become `rejected`, which unblocks |

**Two routes into a permanent block:**

*Upgrade with unconfirmed Build 27 work.* Quality, assignment and Morning Review
import legacy preference evidence as `needsReview` on the **same per-actor key**
new work uses. The block is intentional and tested —
`'legacy raw evidence stays needsReview and blocks new assignment'` — and the
screen tells the operator the item "is retained for support review". No such
review tool, procedure or role exists. Build 27 removed these entries on success
(`quality_command_service.dart:349`, `published_template_assignment_screen.dart:737`,
`morning_review_command_service.dart:583`), so the affected population is
operators holding work Build 27 never confirmed — which is precisely what the
2026-09-09 network block produces.

*Campaign creation after a definite refusal.* The campaign owner wraps dispatch
in `catch (_)` and records **every** failure as `uncertain`, with the advice to
"check the saved programme to retry the same request". `createInspectionCampaign`
refuses with `failed-precondition` "Inspection definition is missing, inactive or
changed." — reachable simply by an administrator editing the definition while a
manager's request is in flight. The frozen envelope can never succeed, so every
retry produces the same refusal, and the manager cannot create any campaign on
that device. The campaign tests inject a lost response, a failed readback and a
wrong-domain receipt; **none injects a definite server refusal.**

The comment's reasoning is sound as far as it goes — a refusal can follow an
earlier acceptance when permissions change — but Inner Cover acceptance already
shows the distinction can be drawn: it classifies `AssetHierarchyCommandRefused`
as `rejected` and everything else as `uncertain`. Quality, published assignment,
burner and campaign owners do not.

Morning Review's recovery document acknowledges part of this: an uncertain
earlier-day attempt "remains preserved and blocked for review", and there is "no
nonmutating client receipt-lookup endpoint to settle that uncertainty
automatically". It does not say who performs that review, or how.

**Correction before distribution:**

1. A governed review owner: an audited supervisor or support action that resolves
   a blocked row to `reconciled` or `rejected` only after server evidence — a
   receipt readback or proof of absence — and never by deleting local evidence.
2. Classify definite refusals that cannot follow an acceptance as `rejected`, as
   Inner Cover acceptance already does, with a failure-path test per owner.
3. Reconsider per-actor keys for creation domains, where one stuck item currently
   prevents all unrelated new work of that type.

### AU-02 — Saved work never dispatches on its own, and nothing gathers it

**Priority: medium · Confirmed**

No code outside the six owners calls `claim()`, and nothing in startup, sync,
resume or the home screen reads durable submissions. The campaign owner states
the rule directly: "Only an explicit operator check dispatches work."

After a network block, an operator must remember which screens held unconfirmed
work, open each, and press Check. There is no cross-domain list or badge. This is
a deliberate conservative choice, and it survives process death — but combined
with AU-01, an operator who never revisits a screen has no signal that work is
waiting or blocking them.

### AU-03 — Twenty-nine account reads still bypass the new resolver

**Priority: medium · Confirmed at named sites**

`CurrentActorAccess` is correct, but 29 `ref.read(...).value` sites have no nearby
guard. These are sites warranting review, not a defect count. Two illustrate the
remaining shape:

- `executePilotBusinessRecordPurge` refuses with "Fresh Admin authority is
  required for permanent removal" after reading `.value` — which returns a
  **retained** account while verification is failing. The client message
  describes a guarantee the check does not provide.
- Inner Cover assign and delink closures read `.value ?? const []`. When the
  provider errors before its first value, `.value` throws, so the fallback is
  never reached.

**Authorization still holds server-side:** purge requires the `pilotRecord.purge`
capability through the dispatcher's in-transaction authority check, and role
changes re-read the caller and require an approved admin. PR #362 states plainly
that its batches "do not establish that every privileged action in the app has
been reviewed".

### AU-04 — Distribution still depends on one-way and two-sided transitions

**Priority: high for distribution · Confirmed**

- **Schema 11 is one-way for Build 27.** Build 27 source (`c933ca0a`,
  `_validateStoredSchema`) refuses a newer store with
  `stored-schema-newer-than-app`. R04 documents this correctly and forbids
  lowering the marker, clearing storage or uninstalling. The schema-11-compatible
  repair binary it requires does not exist.
- **Four V2 endpoints are not deployed.** Verified exports:
  `executeMaintenanceWorkflowCommandV2`, `mutateAssetHierarchyV2`,
  `mutateChargeAbnormalityV2` (the quality route) and
  `assignPublishedTemplateVersionV2`. A Build 28 client against the deployed
  backend is safe on this point: the capability probe maps `not-found` and
  `unimplemented` to "keep it pending", with no fallback.
- **Finding adjudication remains a two-sided cutover.** Neither ordering is
  compatible; a communicated operator cutover is still required.
- **Backend rollback must retain new receipt readers** — `innercover3`,
  `assetreg4`, `assetreq2`, `qualitycreate2`. No tested rollback artifact exists.
- **Maintenance-ticket creation — the path that failed on 2026-09-09 — is the one
  route without native durable recovery.** R04 says so explicitly.

### AU-05 — Two documents are out of date

**Priority: low · Confirmed**

- `BUILD28_CLIENT_BACKEND_COMPATIBILITY_2026_09_12.md` still states "No new
  callable name … was introduced". R04 supersedes its export section, but the
  advisory carries no pointer forward and never mentions V2 or R04, so a reader
  who opens it first is misinformed.
- `SYSTEM_ASSESSMENT_REMEDIATION_STATUS_2026_09_12.md` says the complete Flutter
  suite "is being repeated"; the PR records the completed 2,530-test pass.

---

## 3. Verified sound

| Area | Evidence |
| --- | --- |
| Retained-value account handling | `CurrentActorAccess.resolve` refuses on loading and error before reading any value; pinned by `copyWithPrevious` tests |
| Campaign identity on retry | Frozen IDs persisted before dispatch; restore precedes creation; replay test preserves both IDs |
| Validation before settlement | Receipt validated against the frozen request in the owner **and** again inside `settleAccepted`'s transaction; legacy and zero-attempt rows refused; a differing acceptance is flagged as a conflict |
| Acceptance precedence | `recordOutcome` returns `alreadyAccepted` for an accepted row; stale claims fenced by token, state and lease |
| Missing V2 backend | Probe holds work pending rather than failing or falling back to V1 |
| Build 27 rollback refusal | R04's claim matches Build 27 source |
| Privileged actions | Purge and role mutation re-verified server-side |
| Inner Cover acceptance | Separates definite refusal (`rejected`) from uncertainty |

---

## 4. Suggested priority

1. **AU-01 review owner and refusal classification** — before any distribution,
   because the upgrade itself can create the blocked rows.
2. **AU-04 repair binary and adjudication cutover plan** — release prerequisites.
3. **AU-02 cross-domain saved-work surface.**
4. **AU-03 remaining sites**, then operator messages.

## 5. Limits

No physical device is attached, so no installed version or signer was read. The
Firestore emulator suites were not rerun here; PR #362 reports 392 emulator checks
passing. AU-01's lock-out sequences follow from inspected source and tests and
were not executed end to end. This audit covers the merged remediation and its
new store; it is not the outstanding whole-application audit.
