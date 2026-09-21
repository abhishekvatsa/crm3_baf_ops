# Maintenance creation successor review — 21 September 2026

This repair closes the confirmed recovery dead end recorded in
`AUDIT_CLOSURE_AND_KOTLIN_2026_09_21.md`. The source baseline is `38a6eeed`.
It does not activate production capabilities or certify a distributable build.

## Defect and resulting behaviour

When original creation A was accepted after local draft B had been edited, sync
correctly retained B rather than overwriting it. However, ordinary correction
required a synced row, so the required review was unreachable. A preserved draft
could remain pending indefinitely.

A dedicated review is now available on the pending maintenance ticket. Admin/SI
can compare the original accepted values, the complete device draft and a fresh
server record C. Selected supported changes use the existing governed correction
command with the supervisor's own account and a mandatory reason. Keeping C is
an explicitly local reconciliation with a reason; it does not invent a remote
command receipt. Unselected and unsupported changes remain in retained evidence
and are not presented as applied.

## Evidence and recovery boundaries

- Original A is read from its immutable accepted native envelope and receipt. The
  supervisor does not replay it or take over the reporter's uncertain command.
- B is a complete native Isar export, including raw JSON and persisted fields,
  rather than a reduced audit map. Review/adoption compares the entire row.
- C comes from the existing strict server-only maintenance reader. A changed
  version or contradictory same-version observation refuses a stale review.
- The distinct correction keeps its original account, command bytes, comparison
  evidence and exact receipt across restart and a lost response. A shared strict
  audit reader validates native Firestore timestamps before exact receipt binding.
- Projection adoption, native review history and owner reconciliation occur in
  one transaction. If newer B2 edits arrive while the correction is in flight,
  the accepted correction is settled and B2 stays unchanged for another review.
- Registered equipment labels are not copied from arbitrary draft text. A wrong
  target requires fresh explicit registered-target selection and existing backend
  dependency checks. Unsupported cross-asset or lifecycle edits remain retained.
- Ordinary synced-only correction guards remain. No backend operation, Firestore
  rule, Isar schema or collection is introduced by this repair.

The local archive is device evidence. This is not an unavailable-account recovery
service, an off-device backup, or permission to rewrite historical audits.

## Verification

The focused integration run passes 85 tests: 23 native real-Isar successor tests,
12 new review UI tests, and 50 original creation/sync compatibility tests. Another
32 existing correction/detail/authority UI tests passed. The nine changed source
and test files passed scoped analysis. Native tests cover hidden field changes,
duplicate rows, stale server reads, account switches, exact retry after restart,
malformed audit evidence including timestamp precision, registered-target labels,
first-attempt definitive refusal versus prior uncertainty, concurrent newer work,
and transaction rollback. They assert that every native schema property is retained.

Independent review found a real adapter mismatch between a native Firestore audit
timestamp and the ISO receipt representation. Shared strict admission and exact
native timestamp comparison repaired it; the regression now uses the actual SDK
Timestamp type and rejects malformed or hidden-precision evidence. The final
bounded independent review reported no further concrete defect. Repository-wide
inventory checks, hosted CI and bot review remain required before merge.

Current integration verification additionally passes all 150 canonical audit
checks and 31 focused governance contracts. Explicit inventory classification
retains all existing decoder and catch policies, all 55 schema fields and the
existing extension/generation protections. Hosted checks and bot review must pass
on the committed head before merge.
