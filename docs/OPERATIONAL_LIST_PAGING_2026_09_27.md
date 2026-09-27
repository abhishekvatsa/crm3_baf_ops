# Operational lists: open by default, explicit batches of 15

Date: 2026-09-27. Changes remain in the shared working tree. No production
deployment, business-data mutation, commit or push was performed for this task.

## Requested behavior and scope

- Main maintenance Issues, Quality warnings, charge Monitoring, per-charge
  abnormality logs, cross-charge abnormality browsing, ordinary Directives,
  and administrative ticket/directive browsers initially display at most 15
  matching records.
- Open is the default. All and the domain's individual status choices retain
  the same limit. Searching or changing status resets the display allowance
  to 15. Each explicit **Show more** adds up to another 15; scrolling alone
  does not add records.
- The separate closed-ticket history screen remains explicitly historical,
  retrieves 15 at a time, and uses the same manual continuation behavior.
- Filtering and stable sorting precede truncation. Display limits do not
  truncate canonical providers, synchronization, totals, or PDF report inputs.
- A warning awaiting adjudication remains open. Acknowledged directives remain
  open until closed. Cancelled monitoring stays distinct from completed work.
- Abnormality records have an RA decision rather than a generic case closure
  field. Their default is explicitly labelled **Open / RA pending** and includes
  decision-pending and RA-required records. All and individual RA statuses
  expose the remaining history; this does not infer warning adjudication from RA.
- Existing action and historical-visibility permissions remain enforced. Admin
  All retains deleted records and diagnostic evidence delivered by its source.

## Verification

Focused screen and adjacent behavior checks passed:

| Slice | Passing checks | Evidence log |
| --- | ---: | --- |
| Issues and closed-ticket history, including authority/recovery adjacency | 32 | `.dart_tool/maintenance-list-paging-adjacent.log` |
| Directives paging, delayed-loading search retention | 5 | `.dart_tool/directives-incremental-list.log` |
| Existing Directives usability and authority | 2 | `.dart_tool/directives-incremental-existing.log` |
| Quality, Monitoring, per-charge abnormalities, live menus and authority | 23 | `output/dev-planned-validation-20260927/quality-list-adjacency-tests.log` |
| Admin list paging and existing mobile usability | 13 | `.dart_tool/admin-business-list-paging-tests.log` |
| Cross-charge abnormalities, full counts, status/search/Clear reset | 2 | `.dart_tool/abnormality-report-paging-tests.log` |

Tests cover 15 -> 30 -> final remainder, explicit continuation, resetting the
allowance, historical action restrictions, incomplete history, and narrow-phone
layout. These are targeted tests, not a claim that the complete release gate ran.
Relevant analyzer checks passed. Final root slice and phone-test analyzer:
`output/dev-list-paging-20260927/final-list-analysis.log`.
An independent read-only review of the changed list behavior found no actionable
regression in filtering order, count preservation, access, historical actions,
or empty/loading behavior. The complete working diff passed `git diff --check`;
Git reported existing line-ending normalization warnings in other changed files.

## Connected phone

Read-only journey: `integration_test/dev_list_paging_test.dart`, separate DEV
package `in.co.sail.bsl.crm3.bafops.dev`, local emulator project
`demo-crm3-baf-ops`, approved synthetic SI account. No records were created for
this check and no production records were changed.

Attempt 02 passed, including teardown (1 minute 25 seconds of test execution):

| View | Full matching count | Initially shown | After one Show more |
| --- | ---: | ---: | ---: |
| Issues Open | 22 | 15 | 22 |
| Issues All | 40 | 15 | 30 |
| Issues Open again | 22 | 15 | 22 |
| Directives Open | 0 | 0 | 0 |
| Directives All | 0 | 0 | 0 |
| Quality warnings Open | 32 | 15 | 30 |
| Quality warnings All | 40 | 15 | 30 |
| Abnormalities Open / RA pending | 6 | 6 | 6 |
| Abnormalities All | 40 | 15 | 30 |

Device evidence: `output/dev-list-paging-20260927/phone-list-paging-02.log`.
The Directives phone checks prove the qualified empty state; populated directive
paging is covered by widget tests. Admin and per-charge/Monitoring paging were
verified by widget tests, not by a separate physical-device journey this time.

Attempt 01 failed because the harness required a footer even for a qualified
empty Directives list. Attempt 02 recognizes the actual qualified-empty UI and
waits for data/status controls. It does not reinterpret an unqualified empty
snapshot as confirmed zero records. Both logs are retained.

The emulator's expected FCM registration error does not establish real-device
push notification readiness. This task verifies list behavior only.

## Delivery boundary

The ordinary DEV app was restored after the test and confirmed foregrounded on
the connected phone. Startup identified `demo-crm3-baf-ops` and local emulator
endpoints. Evidence: `output/dev-list-paging-20260927/restore-normal-dev.log`.

These changes are shared client changes, not DEV-only business logic. Installed
production clients receive them through the next reviewed application update.
Production signing, deployment and distribution were not undertaken here.
