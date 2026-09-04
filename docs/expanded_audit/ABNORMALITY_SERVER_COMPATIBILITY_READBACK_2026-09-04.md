# Server Abnormality Compatibility Readback

## Scope and Decision

The owner authorized adjusting existing server abnormalities to the new
contract, rather than delaying for retained phone drafts. The first step was a
read-only, consistent-time inventory. No production document was changed.

The inventory found a code incompatibility, not malformed active asset details.
Rewriting valid server timestamps as text would temporarily conceal it, but the
issue-creation producer would immediately create the same supported native
timestamp shape again. Correct the consumer and response boundary instead.
Existing active cases therefore need no data migration for this finding.

This does not close the independently accepted legacy direct-write nested-asset
validation gap. Repairing existing records cannot validate future old-client
submissions. The unchanged, deployed Rules remain the stage-one contract; a
separately verified tightening remains pending. No phone cleanup was invoked.

## Live Evidence

- Project: `crm3-baf-ops-b8638`, default Firestore database.
- Consistent read time: `2026-09-04T16:10:36.755Z` (21:40:36.755 IST).
- Source baseline: `59923db470067bf97c408e5d6c1318e8e80c61b3`.
- Seven abnormalities: six active and one retained deletion tombstone.
- All seven have one correctly shaped affected asset; none needs list reduction.
- All six active cases have a valid Quality Warning and the matching source
  maintenance ticket. Type records exist, are active, and match their snapshots.
- All seven have a native Firestore `loggedAt`. Some `updatedAt` values are text
  and some native timestamps, as produced by the existing supported workflows.
- Nineteen read requests obtained 24 distinct related documents. No unbounded
  all-collection scan, user inventory, backup restore or production write ran.
- The raw, typed snapshot is retained only under ignored local output, SHA-256
  `DFBB748901D08853C7A835989EA7164AEA86287D3E90313B9B83228959C3D88F`.

The deleted entry's source ticket is also deleted and records the earlier trial
cleanup reason. Its warning is absent. This is retained cleanup evidence, not an
active RA case to resurrect. No warning or lifecycle decision was fabricated.

## Confirmed Defect and Correction

`maintenanceWorkflow/ticketHandlers.ts` creates linked abnormalities with native
server timestamps. `qualityMutation.ts` accepts those and the app's persisted
date reader accepts them. In contrast, `chargeAbnormalityMutation.ts` required
text dates on existing records, rejecting all seven saved shapes at `loggedAt`.

The corrected existing-record validator accepts supported native timestamps,
Date values and legacy/UTC text using the existing shared instant parser. It
retains chronology, actor, asset, link, version, RA and deletion checks.
Untrusted CREATE payloads still require ISO text dates and cannot supply the
server-managed pull timestamp.

Responses convert only top-level timestamp values to ISO text so the Flutter
callable decoder can read them after transport. Timestamp microseconds are
preserved; stored `loggedAt` and server-pull stamps are not rewritten. Fresh
results and exact replay use the same response conversion. Audit snapshots keep
their original saved representation.

Rechecking the identical local snapshot against the corrected validator accepts
all seven record shapes and all six active linked cases. This was an offline
revalidation, not a production repair or proof that new Functions are deployed.

## Verification

- Regression reproduced before the fix with native timestamp-shaped records.
- Abnormality host suite: 53 passed, including seconds, milliseconds,
  microseconds, unchanged persisted evidence and no-write exact replay.
- Local Firestore abnormality suite: 9 passed. The added scenario follows the
  actual Operations RA decision route, then Admin correction and exact replay,
  using real Firestore Timestamp objects. Original stored timestamps survive.
- Focused Flutter receipt and local convergence tests passed; the app retains
  microseconds in the first response and replay.
- Final full Flutter suite: 1,846 passed; one conditional production-bridge test
  skipped. Full host Functions suite: 929 passed; emulator-only suites are not
  counted as host passes. The nine targeted emulator tests ran separately.
- Full analyzer clean; canonical source/authority audit 149 passed, zero failed.
- Malformed timestamp parts and timestamp objects in untrusted CREATE payloads
  remain rejected. Existing actor, version, linked-case and RA tests remain in
  place; no permission was broadened.

The first emulator test draft incorrectly used the Admin-only correction route
as Operations, then lacked the required deterministic linked-case ID. Both
fixtures were corrected to follow the real routes; production permissions and
identity checks were not weakened to make tests pass.

At the time of this readback, all five CI jobs on baseline `59923db` had passed,
but that result does not certify this subsequent local correction. Merge,
deployment and APK construction remain gated on the updated source checks.

Local evidence: `output/build24-release-preflight/abnormality-server-audit-*`,
`server-abnormality-emulator.log`, `server-abnormality-flutter.log`, and
`server-abnormality-functions-all.log`, plus the full Flutter, analyzer and
canonical `server-abnormality-*` logs. Raw records must not be committed.

The revalidation JSON explicitly identifies the source commit as a baseline,
and binds the uncommitted corrected validator by SHA-256
`DFFEF25FA241211B0B0F55A04A62061FE2C09E744AE351C205806F2592719512`.
This separates the live snapshot's acquisition source from the later local
validator used to prove that data rewriting is unnecessary for active cases.
