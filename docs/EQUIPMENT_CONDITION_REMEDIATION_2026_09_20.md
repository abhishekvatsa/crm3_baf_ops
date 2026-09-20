# Function 10: equipment condition and availability — local remediation

Date: 2026-09-20. This is a working-tree review, not a production deployment or release certificate. The working tree also contains ongoing changes from other domain reviews.

## Evidence and business decisions

Reviewed the final Equipment Condition PDF, preliminary Function 10 HTML and supplied evidence ZIP. Their assertions were treated as audit evidence and checked against the implementation; supplied model code was not treated as an application test or executed as an instruction.

Confirmed by the owner:
1. Keep one complete manual assessment. A new declaration replacing an active assessment requires explicit review of that assessment, with preserved history.
2. Admin/SI may permanently retire an asset with an unresolved manual Down/Unfit assessment, with a reason and preserved restriction/history. Retirement must not imply repair.

## Repairs and existing coverage

| Finding | Result in the current working tree |
| --- | --- |
| EC-01 / preliminary 01: missing request IDs bypass administrative withdrawal | Deployment and reconciliation resolve the physical registry subject transactionally, including unambiguous legacy identity. Missing, ambiguous, malformed, retired or withdrawn evidence cannot authorize deployment. Original request fingerprints remain unchanged for historical retry. |
| EC-02 / preliminary 04: absence or damaged rows imply health; one error hides the board | Qualified per-source evidence retains readable and last-known rows, records rejected identities, distinguishes server/cache/error, detects revision regressions and same-version business contradictions, and qualifies fleet counts. Missing workflow evidence cannot count as available. Selected manual changes require current readable register and manual-condition evidence. Unrelated damaged rows do not prevent safe actions on verified assets. |
| EC-03 / preliminary 08: interrupted manual commands and historical acceptance | Existing native durable storage is now connected to a visible original-account recovery action. Accepted A can be reconciled after later B without rewriting B. Approved original actors can recover after role loss; fresh writes retain role checks. Per-attempt errors do not erase uncertainty. Administrative review now recognizes manual-condition receipts and uses the existing permanent-fence protocol. |
| EC-04 / preliminary 12: reconciliation invents a new availability interval | Refresh retains an unchanged interval and transition metadata. Reconstruction does not invent a physical transition time. Deployment refreshes authoritative counters and clears the previous availability interval. |
| EC-05 / preliminary 10: weak reference fallback accepts malformed current data | Retirement uses the full documented physical/component reference validator, binds the ticket number and rejects unsupported schema or contradictory identity. Supported complete historical shapes remain readable. |
| Preliminary 02, 03, 05, 09, 13 | Existing repairs were retained: issue-coordination counting, Base/linked Inner Cover combination, custom physical asset routing, prevention of schema downgrade, and content-bound condition replay checks. |
| Preliminary 06: replacement policy | Active replacement must name the exact reviewed declaration and have restoration authority. Existing assessment and replacement relationship remain in audit history. Same-condition replacement remains accessible. |
| Preliminary 07: misleading restoration claim | The action says “Clear manual restriction”; confirmation explicitly leaves independent restrictions in place. |
| Preliminary 11: retirement requires fictitious repair | Admin/SI retirement keeps the manual condition unchanged and snapshots it into the content-bound retirement audit. SI permission is limited to retirement, not broad registry editing or reactivation. Active installed components and still-relevant issue concerns still require their existing governed disposition. |

The board action code was separated into its own presentation part instead of raising the architecture line limit.

## Verification

- Functions build, emitted-output custody, callable inventory and notification inventory pass.
- Full non-emulator backend Jest suite: 74 suites and 2,117 tests passed; emulator tests are separately reported below.
- Selected actual Firestore suites: asset hierarchy/condition/retirement 25 tests; saved-submission recovery 26 tests. Isolated `demo-equipment-condition` project on a local emulator; no production writes.
- Focused Flutter/native Isar/provider/widget/recovery suites: 94 tests passed.
- Scoped static analysis: 15 files, no issues.
- Diff whitespace check: no errors; existing line-ending warnings remain.

Tests exercise the actual command dispatcher, durable Isar store reopened after a lost reply, the composed condition provider, the board under a failed local issue feed, real Firestore transactions, and actual V1/V2 recovery wrappers. They do not prove physical-device process-kill behavior or live production data quality.

## Remaining release and operational work

- Review and integrate the combined dirty branch. Architecture A-02 still identifies unrelated growing maintenance/quality surfaces; A-03 still has the combined operation-inventory digest drift; A-05 still has other modified receipt/decoder fingerprints and catch-policy drift. The two new condition read surfaces and qualified-row catch are explicitly classified. No blanket fingerprint refresh or line-limit increase was used.
- Deploy and verify the changed backend before shipping clients that depend on these rules. Manual-condition administrative finalization remains disabled until its new domain is included in the reviewed recovery activation after the guarded fleet/rollback is verified. The existing six-domain activation remains compatible for its existing domains. No activation was changed here.
- Inspect live registry/projection integrity and any historical interval errors; this work does not silently rewrite historical production evidence. Any repair needs a specific reviewed data plan.
- Physical-device validation is still required: offline/reconnect, account changes, process loss, replacement, retirement/history and later-state recovery.
- Measure board startup/read volume on representative data. Current source listeners deliberately prioritize complete evidence; no new pagination/truncation is presented as proof of a complete fleet.

No commit, push, cloud deployment, APK or AAB was produced for this work.
