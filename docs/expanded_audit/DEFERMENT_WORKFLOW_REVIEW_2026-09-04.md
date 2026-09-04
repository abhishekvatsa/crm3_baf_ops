# Deferment and Operations Coordination Review

Date: 4 September 2026

## Verdict

This is not merely a training problem. The local source contained reproducible transition defects, a custom-asset identity omission, notification routing to the wrong side of a handover, and unclear or silent user feedback. These have been corrected and tested locally.

This review does not establish which defect affected each user's production record. No affected production record, delivery log, or physical phone session was inspected in this pass. No deployment, APK construction, installation, data purge, or production repair was performed.

The fixes are in the existing working tree, alongside earlier quality, abnormality, issue-form, and furnace-removal changes. They are not a claim that the installed application or deployed backend already contains these fixes.

## Business Flow

| Step | Responsible side | Meaning |
| --- | --- | --- |
| Accept the maintenance issue | Assigned maintenance lane or an authorized supervisor | The issue must have valid acknowledgement evidence. The selected lane must still have work remaining. |
| Request deferment or Operations support | Receiving maintenance side | A specific charge/activity release condition, or a support request such as crane positioning, is recorded. The issue is held pending that prerequisite. |
| Acknowledge the request | Operations | Receipt is acknowledged. This does not certify completion. |
| Confirm release condition met | Operations or another role already authorized to confirm conditions | For a charge/activity deferment, record what was completed or verified. The hold is released and the requesting side receives completion evidence. Existing policy also permits direct condition confirmation from a raised request. |
| Mark complied | Target lane, normally Operations | For an acknowledged manual support request, report completion with evidence. Maintenance can resume while acceptance is pending. |
| Accept Operations completion | Originating maintenance lane, authorized coordinating supervisor, Admin/SI as applicable | Closes the support obligation. This is separate from resolving the maintenance issue. |
| Return to Operations | Same accepting side | Records the reason, retains the failed completion attempt, and holds the linked work for correction. Operations can report a new completion attempt. |

In the application, Operations can find requests through Work -> Workflow -> Compliance inbox -> For my lane. The requesting side can use Raised by us. The request detail now states whose next action is needed.

### Why one obligation can remain

Operations reporting completion and maintenance accepting completion are different steps. A `complied` request remains an active obligation until acceptance. Merely resolving the related maintenance ticket does not necessarily close that separate handover. A remaining count is therefore not, by itself, evidence of a sync failure.

The corrected UI says that completion was reported and is awaiting the origin's acceptance. It no longer describes a completed legacy request as dormant merely because its original due-condition timestamp was absent.

Ordinary release does not require maintenance to acknowledge the same issue again. If a return for correction actually reopens an already resolved maintenance issue, the existing reopening rules reset lane progress and require the appropriate renewed acknowledgement.

## Findings and Corrections

### 1. Different completion buttons produced different deferment state

Severity: P1. Reproduced before the fix.

An older/current UI could expose both condition confirmation and generic Mark complied for an acknowledged, condition-based request. The generic route omitted condition-confirmation evidence and produced a different maintenance queue state. This could leave a completion looking dormant.

The backend now routes a condition-based Mark complied through the same governed condition-confirmation handler while preserving the older command's receipt shape. The new UI exposes only the condition-confirmation route for these requests. Manual support retains Mark complied. Condition-confirming authority is still checked; permissions were not relaxed indiscriminately.

Source: `functions/src/maintenanceWorkflow/complianceHandlers.ts`; `lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart`.

### 2. An undecided revised condition could be bypassed

Severity: P1. Both completion routes and a late revision decision were reproduced before the fix.

Completion could proceed while a counter-proposal was awaiting decision. A later decision could also supersede an already complied request. Both behaviors bypassed the agreed-condition sequence.

Both completion routes now reject pending revisions. Revision decisions require a raised or acknowledged request. The screen matches those rules. Accepted and rejected revisions were tested through subsequent completion and acceptance. Accepted revisions transfer the ticket's compliance reference; the superseded detail provides a link to the exact agreed successor under the existing access checks.

Source: `functions/src/maintenanceWorkflow/complianceHandlers.ts`; `test/compliance_detail_convergence_test.dart`.

### 3. New holds were accepted from a completed lane

Severity: P2. Reproduced before the fix.

The screen excluded completed lanes, but the backend checked only assignment and acknowledgement. A caller could start a new deferment from a lane whose work was already complete.

The server now also requires that the selected lane is not completed. Invalid requests do not partially create a workflow, obligation, or ticket hold.

Source: `functions/src/maintenanceWorkflow/issueCoordinationHandler.ts`.

### 4. Custom-asset workflow identity was lost

Severity: P1. Confirmed by source tracing and covered by new regression tests.

Issue coordination populated null asset-class and asset-instance identifiers even for governed custom assets. The workflow reader requires those identities for custom assets, making that generated workflow unreadable by the client.

Coordination now retains the paired identifiers from the ticket's governed reference, checks the asset number, and uses the existing identity validator. Missing or malformed custom references are rejected before any hold is created.

This prevents new malformed workflows. It does not retrospectively repair previously created custom-asset workflows; those require a targeted readback and repair assessment.

Source: `functions/src/maintenanceWorkflow/issueCoordinationHandler.ts`; `functions/test/issueCoordinationWorkflow.test.js`.

### 5. Request actions could fail without useful feedback

Severity: P2. Covered by a stale-state/retry widget test.

The detail screen awaited commands without catching failures. Rejected asynchronous actions could produce an unhandled error, and the controls could remain based on old state.

Failures now produce a visible message and invalidate the exact request and workflow reads. Successful commands retain their committed receipt version before refreshing. A refresh control is also available. Testing simulates a different phone advancing the workflow and verifies that the next action uses the newly read version.

The unscoped origin-action UI was also aligned with the server: Admin/SI authority is required there, rather than showing a control to every module supervisor.

Source: `lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart`.

### 6. The form and status presentation encouraged misunderstanding

Severity: P2 usability defects.

Changing between deferment and Operations support overwrote entered title/action text. It now changes only untouched generated defaults. Selecting activity-based release also changes the untouched title so it does not incorrectly refer to cycle completion. Applicable activity/location bounds now match the server validator.

Request details show recorded acknowledgement, completion, correction and acceptance actors/times and notes. Completion and final acceptance have distinct labels. The inbox prioritizes pending acceptance and correction over the old dormant label.

Source: `lib/features/maintenance/domain/issue_coordination_draft.dart`; `lib/features/maintenance/presentation/issue_coordination_dialog.dart`; `lib/features/maintenance_workflow/domain/compliance_visibility_policy.dart`; detail and inbox screens.

### 7. Notifications followed the event actor's lane instead of the handover recipient

Severity: P2. Confirmed by tracing event creation through notification routing; regression tested.

A new issue-coordination event records the originating lane, so routing directly from that field omitted Operations. Completion events recorded the target lane, while returns for correction recorded the originating lane. Consequently, notifications could go to the side that had just acted instead of the side that needed to act next.

The notification handler now reads the exact bound compliance request for recognized handover events. Requests and corrections reach the target; completion reports and proposed revisions reach the origin. Eligible coordinating supervisors are included when the request was raised under supervisory coordination. Missing, deleted, malformed-lane, or differently bound requests are excluded.

This uses one request read per relevant event, preserves audit actor/lane evidence, and leaves the escalation ladder and critical-alarm routing unchanged. Notifications do not grant action permissions. Actual FCM delivery to pilot phones was not tested; ordinary workflow push remains a supplementary signal, not the authoritative workflow list.

Source: `functions/src/maintenanceWorkflow/workflowNotificationPolicy.ts`; `functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts`; `functions/test/workflowNotificationPolicy.test.js`.

## Architecture and Shared Planned Maintenance

- Issue coordination creates a separate workflow and compliance request atomically with the ticket hold. It does not create planned-job lanes or increment equipment maintenance counters.
- Shared compliance handlers also serve planned maintenance. The completion, revision, correction and notification fixes therefore cover shared routes without replacing planned-job closure or RED preparation rules.
- Commands remain server-authoritative and version checked. An exact retry returns its receipt; another phone using an old ticket version cannot create a second hold.
- The existing live workflow mirror covers actionable workflow projections. Tests confirm role-aware visibility, canonical version precedence, account/authority isolation and exclusion of terminal/deleted obligations.
- A detail page uses approved-actor-scoped point reads, not a continuously live stream. Refresh and post-command rereads improve recovery, but a screen left open on another phone can still need refresh. Concurrent actions can legitimately receive a version conflict.
- These findings concern transition semantics, contract alignment, notification recipients and presentation. They are not evidence that replacing Isar alone would fix deferment.

## Verification

| Verification | Result |
| --- | --- |
| Pre-fix transition reproduction | Five new tests failed against the old behavior; five existing tests passed. Retained in `deferment-repro.log`. |
| Complete local backend suite | 54 suites passed, 898 tests passed; 94 emulator-only cases skipped in this ordinary run. |
| Isolated Firestore workflow emulator | 2 suites, 14 tests passed, including the new real-timestamp deferment/correction/acceptance/replay case. |
| Focused Flutter interaction, visibility, freshness and A02/A03 tests | 61 passed. |
| Shared planned-maintenance/domain, authority and UI tests | 104 passed. Some domain tests overlap the focused run; these counts are not a unique-test total. |
| Flutter analyzer | No issues found. |
| Whitespace/conflict-marker diff check | Passed. |

The emulator used the isolated `demo-deferment-review` project. Production was not used. The first emulator attempt exposed missing explicit-null fields in the new test fixture; the fixture was aligned with the actual client command before the successful run. The new stale-submission test was similarly aligned with the existing `aborted` version-conflict contract, without weakening production validation.

Local logs are in `output/quality-abnormality-review-2026-09-04/`: `deferment-repro.log`, `deferment-functions.log`, `deferment-emulator.log`, `deferment-flutter.log`, `deferment-shared-flutter.log`, and `deferment-analyze.log`.

## Remaining Limits and Release Follow-up

1. Identify an affected pilot ticket and compare the canonical ticket, request, workflow, attempts and phone's rejection evidence. This is necessary to distinguish a legitimate acceptance-pending request from a historical malformed or stale projection. Do not purge all unsynced work to diagnose a single obligation.
2. Existing malformed custom workflows or legacy inconsistent requests have not been repaired in production. No blanket migration or evidence deletion is part of this patch.
3. Request/confirmation dialogs still dismiss before the server command completes. Purpose switching preserves typed text, but a rejected submitted command does not yet automatically restore the editing dialog with its notes. The pending command mechanism is separate from user-facing draft restoration.
4. Revised-condition text does not replace the structured original charge/activity reference. That existing limitation needs an explicit product decision if users intend to switch to a different charge or a different typed release condition, rather than amend the completion requirements.
5. Device-to-device navigation and actual push delivery on the pilot's installed APK remain unverified in this pass. Widget and emulator tests are not a physical-phone acceptance claim.
6. A governed backend deployment and a subsequent approved APK containing the UI changes are needed before describing these fixes as delivered to users. No release-state evidence was fabricated or changed. The previously known successor release-state reconciliation issue is outside this deferment fix and was not revalidated here.

Conclusion: the reproduced software failures are corrected locally, and the intended handover is clearer. Specific pilot incidents and release readiness still require their own evidence; neither is inferred merely from these passing tests.
