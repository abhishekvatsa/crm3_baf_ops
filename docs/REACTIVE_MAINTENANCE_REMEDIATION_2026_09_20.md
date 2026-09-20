# Reactive maintenance review — 20 September 2026

Status: implemented repairs in a shared, uncommitted working tree; **not a release approval**. Starting HEAD: `d038797f9a2d3bd0126d311416acec4148506a67`. Other domain work is ongoing in the same checkout. No production deployment, commit, push, APK, or device acceptance was performed in this pass.

## Sources and business decisions

Reviewed `CRM3_Reactive_Maintenance_Final_Review.pdf`, `Function_08_Reactive_Maintenance_Deep_Audit.html`, and `summary.json` from Downloads against current source and earlier local repairs. The supplied evidence is not one reproducible green run: the PDF describes 70 tests / 62 passing / 8 expected gaps, whereas summary.json describes 69 / 41 / 28 and `exactExpectedFailures: false`. The external runner was not supplied. The results below are our own checks, not a reproduction of that runner.

Confirmed user rule: component and tag identify registered equipment. Protect that identity; Admin/SI may explicitly correct an erroneous target with a reason. Ordinary narrative corrections remain available.

Historical closure amendment is a separate decision from reopening. The outstanding question asks whether Admin/SI may amend a mistaken historical closure while preserving original evidence. No answer has been assumed. The existing four-hour physical-time reopening rule remains unchanged.

## Finding disposition

| Finding | Implemented behavior | Limits / remaining work |
| --- | --- | --- |
| RM01 / F08-05: equipment identity versus editable labels | Ordinary component, subsystem, and tag changes cannot contradict the retained registered reference. Admin/SI correction uses a fresh governed target, reason, server version, and atomic audit; all target display fields change together. Client uses the existing registered component picker. | Current correction is within the same asset and restricted to open, unworked, unlinked standard tickets. Worked, specialized, inspection-linked, event-linked, and continuation-linked tickets are refused explicitly; dependent-record and cross-asset correction journeys remain to be designed and implemented. This finding is **partially closed**, not universally resolved. |
| RM02 / F08-03 / F08-04: continuation | Compare stable physical identity, not mutable registry revision counters. Preserve actual installed-component and Inner Cover linkage. Add linked-work entry route, source/follow-up navigation, native indexed relation reads, and dossier linkage. | Missing or malformed linkage remains visible as incomplete evidence. No automatic replacement of the original concern. |
| RM03 / F08-08: renamed actor replay | Accepted evidence survives a later actor display-name change. Original recorded name remains retained; verified actor identity remains required. | Does not authorize another account to retry the original request. |
| RM04: durable creation ownership | Save and reuse the original command and origin account. Validate the typed receipt before durable settlement, including cached receipts. Preserve later local edits rather than rebuilding the original command from them. No generic-write fallback. | Later draft B is preserved and reported for review after original A is accepted. A dedicated in-app compare/reapply/retain workflow for B remains unfinished; a safe hold is not a complete user recovery journey. |
| RM05: replay evidence integrity | Bind new maintenance audit content to a digest in the independent accepted command receipt. Canonicalize embedded JSON logically; detect changes to fields outside the requested correction too. Strengthen semantic replay checks for legacy receipts. | Legacy receipts without a digest continue through compatibility checks. This does not retroactively create independent cryptographic proof for old records or protect against an actor able to rewrite both authoritative stores. |
| RM06: Others responsibility transfer | Default vendor change is a responsibility transfer, clearing only that lane's acknowledgement/completion while preserving original audit evidence. Explicit Admin/SI label-only correction retains completion. | Generic correction refuses a used department label and directs the operator to lane review. |
| RM07: historical closure correction | Existing closure evidence and four-hour reopening policy preserved. | **Pending business decision and implementation.** No disguised reopening or retrospective overwrite was added. |
| F08-01: direct mutation bypass | Withdrawal is an Admin command with atomic tombstone, audit, version, and receipt. Native pending withdrawals and supported older close/reopen queues use canonical commands and exact readback. Firestore Rules reject direct maintenance updates and direct burner-closure writes. | Rules are local only. Requires coordinated backend/app/Rules rollout and installed-client compatibility validation before production cutover. Unverifiable older queues remain preserved for review. |
| F08-02: attendance mistaken for restoration | Saving a burner attendance that leaves a burner locked out/isolated keeps the issue active. Record separate append-only visit evidence; do not create technical closure or complete the lane. Later repair has distinct revision-scoped action identities. | Attendance history has explicit size/session bounds and refuses unbounded growth; supervised archival is a future operational workflow. |
| F08-06 / F08-07: physical chronology and actor | Validate action physical time bounds; use verified actor for the new attendance contract. Keep physical performance time separate from server recording time. Implicit acknowledgement uses server time. | Legacy command compatibility is retained; not a rewrite of historical records. |
| F08-09: malformed populations | Preserve valid visible ticket rows with incompleteness diagnostics. Condition, report, and continuation reads that require a complete population fail explicitly. Malformed attendance history is visible and refuses dossier export. | Do not interpret an unreadable population as an empty or healthy one. |

## Verification evidence

- Backend TypeScript compilation passed.
- Full ordinary backend Jest run: **72 suites / 2,075 tests passed**. Its 19 emulator-only suites / 193 tests were skipped by that invocation; those are not claimed as passing.
- Root Firestore Rules suite against an isolated local emulator: **219 tests passed**. No production data was used.
- Combined focused Flutter run: **162 tests passed**, covering native command recovery, account boundaries, attendance, closure replay, audit integrity, Rules source contract, dossier, and detail UI.
- Two additional native tests passed: indexed continuation reads exclude withdrawn follow-ups, and accepted original creation preserves newer local edits through restart with an accurate recovery message. The final native acceptance file passed **46/46**, giving **164 distinct passing focused Flutter tests** across these runs.
- Final analyzer after fixing the missing asset-condition provider import and adding the recovery-message regression: **no issues found**.
- A03 persistence boundaries, A04 persisted schemas, and strict persisted timestamp inventory passed on the inspected working tree.
- `git diff --check` passed; existing CRLF normalization warnings are not whitespace errors.

Local reproducibility logs are under ignored `tmp/`: `reactive-backend-full-verified.txt`, `reactive-rules-full.txt`, `reactive-flutter-verified.txt`, `reactive-continuation-test.txt`, `reactive-baseline-final.txt`, `reactive-analyzer-final.txt`, and the `reactive-a*-final/last.json` inventory outputs. These are local observations, not committed release custody or immutable CI evidence.

Whole-tree architectural review is still not green. The last A02 result identifies the concurrently changed planned-maintenance `assign_job_screen.dart` hotspot. The last A05 decoder result identifies template-governance, template-snapshot, and asset-hierarchy decoder fingerprint/catch-policy changes. Their manifests were not broadly refreshed to hide changes requiring review. No caps were increased.

## Release prerequisites and unfinished journeys

1. Complete reviewed recovery for newer local draft B after accepted original A. Preserve the entire draft durably before any server-state adoption, and protect concurrent local edits/account changes.
2. Implement correction of targets with dependent evidence and cross-asset mistakes through a reviewed history-preserving workflow. Do not simply relax the current refusal or relabel prior physical work.
3. Resolve the historical closure-amendment question, then implement and test it separately from recurrence/reopening.
4. Integrate concurrent domain changes and review their inventory changes. Run the consolidated release checks on the actual final commit.
5. Deploy compatible backend behavior before enforcing the new Rules boundary; validate old-client pending queues and the upgrade on a physical device. Then complete Rules readback and the normal build/distribution gates.

The present results justify review of the repairs. They do not justify marking every audit finding closed or declaring the app distributable.
