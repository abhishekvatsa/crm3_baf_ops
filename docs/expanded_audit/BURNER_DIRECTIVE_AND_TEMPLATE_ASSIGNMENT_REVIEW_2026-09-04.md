# Burner directive acknowledgement and template assignment review

## Outcome and limits

Both reported failure mechanisms are verified. Corrections are in the working source and have passed focused client, backend, and database-emulator tests. No production business records were changed, no deployment was performed, and no APK was constructed or installed.

The deleted phone record and its rejection evidence are unavailable. The exact attempted acknowledgement and acknowledging user cannot be reconstructed from the remaining open server records. This report confirms a reproducible defect matching those records, not an invented account of the removed phone's log.

## Read-only production evidence

Readback: 2026-09-04 13:16:50 UTC (18:46:50 IST), project `crm3-baf-ops-b8638`.

- Seven burner-round directives issued by KETAN KUMAR were found, for Furnaces 1, 3, 5, 8, 14, 19, and 20. All seven were open at version 1, with no acknowledgement evidence.
- Their `createdAt` and `issuedAt` fields are native Firestore timestamps, not strings. The global-pull timestamp is also present.
- `equipment_status/furnace_3` is absent.
- The query for `maintenance_workflows` with Furnace/3 returned no rows. This does not mean Furnace 3 has no condition defects or directives; it only establishes the workflow query result.
- Live rules source SHA-256: `9B0A8B0E9F316AE104C0507B70B94C9B7A6F04D379C86A67933CD4FC27CD54DC`.

The diagnostic query was limited to furnace directives (8 returned, below its 200-row bound), retained only Ketan's matches in the evidence output, and inspected Furnace 3's workflow/status records. Credentials were not printed or copied into the evidence.

## 1. Burner acknowledgement

### Confirmed defect

The local repository records the acknowledgement and increments the local version. The previous remote batch adapter then serialized the entire directive. Parsing a server timestamp into Dart DateTime and serializing it with `toIso8601String()` changes its Firestore type from Timestamp to string.

The server's base update check requires `createdAt` to remain identical. Burner-round acknowledgement additionally permits changes only to acknowledgement/lifecycle fields. The full mobile write violates both protections even though the user only pressed Acknowledge.

An isolated local-emulator reproduction used the actual live rules and a copy of Ketan's Furnace 3 directive. The old full-row write was rejected; the field-only acknowledgement was accepted. Creation, issue, and global-pull timestamps remained native and unchanged.

Removing the unsynced phone row stops retrying that row. It does not acknowledge or close the retained server directive. The seven open server records are consistent with that distinction.

### Source correction

- Burner-round acknowledgements use a transaction and an explicit field-only patch.
- The transaction reads the current server directive and verifies source identity, lifecycle, and exact next version before writing.
- An exact lost-response replay performs no second write and does not increase the version again.
- Changed source evidence, another acknowledgement, a closed/deleted server record, or a version mismatch are not silently overwritten or rebased.
- No server security rule or role restriction is relaxed. Burner-round closure remains governed by its compliance route.
- The existing unchanged-snapshot local sync acknowledgement remains in place. The committed version equals the submitted local version; this path does not invent a rebased version and then mark an older local row clean.

Scope: this correction targets server-governed `burner_round_red_hot_...` directives. It is not certification of every ordinary directive edit/closure path.

## 2. Planned assignment from a normal template

### Confirmed defect

The screenshot's `equipmentStateConflict` is the explicit missing-projection guard in legacy-template assignment. The physical asset registry contains the selected furnace, but physical registration and workflow equipment projection are different records. Assignment required the latter to exist beforehand. This made an otherwise valid assignment fail before creating its execution/workflow.

The evidence does not establish why the projection was absent. A never-initialized asset and earlier trial-data cleanup are possible explanations, not confirmed history. The error is not evidence that the selected template is malformed or that the phone lacked connectivity.

### Source correction

- Only a wholly absent projection is reconstructed, using existing server workflow facts inside the assignment transaction.
- Ordinary maintenance, active RED work, and preparation counts are retained. Completed/cancelled and issue-coordination workflows do not count as active planned work.
- Present but incomplete, malformed, or conflicting projections still require explicit reconciliation; absent counters are not silently treated as zero.
- The shared equipment projection and fact range are read before prospective execution/workflow documents. The first implementation's concurrency test exposed a lock-order failure; this ordering corrected it.
- Two simultaneous first assignments preserve both new contributions plus retained RED work. This was repeated three times in the database emulator.
- Retrying an accepted assignment returns its existing receipt without adding a duplicate workflow or incrementing counters again.
- The historical R1.16 reconciliation document now has an explicit dated amendment explaining the narrow absent-projection exception. Existing cutover inventory and damaged-projection protections remain.

## Verification

Final evidence directory: `output/directive-assignment-review-2026-09-04/`.

| Verification | Result | Evidence |
| --- | --- | --- |
| Focused Flutter regression, including A-02/A-03 | 35 passed | `flutter-final.log` |
| Backend workflow, equipment facts, published assignment, source contracts | 129 passed | `functions-final.log` |
| Database workflow/replay tests, including three concurrent-bootstrap runs | 17 passed | `emulator-workflow-final.log` |
| Full root security-rule suites | 218 passed | `rules-full.log` |
| Live-rules/copied-directive reproduction | Old write rejected; patch accepted | `live-rules-reproduction.log` |
| Whole-app analyzer | No issues | `analyze-final.log` |
| Backend compilation and output/authority inventories | Passed | `functions-build.log`, `emulator-workflow-final.log` |
| Whitespace/diff check | Passed | `git diff --check` |

Earlier failing logs are retained as development evidence and are superseded by the explicitly named final logs. The first concurrency failure was fixed, not suppressed. The A-03 inventory digest was updated for the reviewed repository-owned transaction and its contract passed. No test/analyzer/emulator processes remained after verification.

## Delivery still required

The burner correction requires an updated APK. The assignment correction requires a reviewed, governed backend deployment; its existing request format is unchanged. Current distributed phones and the current backend must not be described as repaired by these local changes. Full release qualification, merge, deployment, package construction, and device acceptance are outside this verification pass.
