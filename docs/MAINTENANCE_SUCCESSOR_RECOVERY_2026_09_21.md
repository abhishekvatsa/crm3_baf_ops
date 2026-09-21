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

## Bot-review repairs on the maintenance follow-up

The first maintenance PR head passed all five release checks and all four
security checks, but bot review found five real gaps. They were held for repair
rather than treated as closed by CI success.

- Audit adoption now requires a native Firestore `Timestamp` with exact value and
  precision. ISO strings, DateTime objects, numeric substitutes and hidden
  precision cannot authorize adoption.
- The server comparison uses the actual generated maintenance serializer and
  validates every generated property/type. Only device id and sync flag are
  excluded. The proof compares all stored properties against actual Isar export.
- Every unsupported device/server difference has frozen values and an explicit
  retain-device-evidence/keep-server disposition. This is a comparison, not an
  invented claim about who edited a field. Raw evidence is retained in full.
- Review selections and correction-form initial values share current-state
  restrictions. Locked routing, specialist fields and registered labels remain
  retained; ordinary narrative corrections can still proceed.
- First-attempt refusal recognizes 38 traced pre-write error-code/reason pairs.
  A later refusal after an uncertain attempt, mismatched error pairs, replay
  failures, account errors and transport failures do not erase uncertainty.

The complete-field regression reproduced 30 failures before repair and now passes
35 cases, including actual native serialization and unchanged-version races.
The final service suite passes 110 cases; final UI/compatibility tests pass 43
cases (19 review widgets and 24 existing cases). Scoped analysis is clean.
Independent read-only review of the generated comparison found no further
concrete defect. Current inventory checks, fresh bot review and final-head CI
remain required for this repair commit.

Final local verification after all five repairs: current A03/A04/A05 inventories
pass, canonical audit passes 150/150, and focused governance contracts pass31/31.
The only added A05 risk site explicitly preserves uncertainty for unclassified
errors. Previously reviewed schema, extension, catch and timestamp policies are
unchanged. These checks accompany the native and UI results above; fresh hosted
checks and bot review still govern merge.


## Dependent-target follow-up

The next bot review found that known dependent evidence still allowed the UI to
suggest a fresh registered target even though the server necessarily refuses it.
A shared eligibility check now withholds that suggestion and picker in both the
ordinary correction dialog and the successor review. It covers known continuation,
workflow, operational-link, recorded-work, acknowledgement, resolved, specialized
and producer-backed quality states. Malformed present work, metadata, team or
quality evidence also withholds the action; absent legacy metadata remains valid.

The same check runs before target selection and submission. Narrative corrections
remain available. The UI explicitly says that the server checks related records;
it does not infer absence of reverse links or server-only provenance from a local
snapshot. Server dependency checks remain unchanged. Nineteen additional target
cases bring the combined UI/compatibility run to 62 passing tests, with clean
scoped analysis. The preceding head passed all five release jobs and four security
jobs, but this final source still requires its own fresh review and hosted checks.


## Closure qualification and recovery coexist

Strict closure admission now exposes damaged local evidence without hiding the
saved-draft review route. Ordinary lifecycle actions and complete PDF export are
withheld while closure evidence is unreadable; detail and closed-ticket screens
show the retained record and a clear review message. The separate successor
service can still verify original A and fresh server C, compare and archive the
entire damaged B, and perform a reasoned keep-server reconciliation. Two native
missing/malformed-closure cases verify the raw retained archive, and a screen
regression follows the actual detail-to-keep-server path. The combined final
UI, native service and stream run passes 170 tests after explicitly selecting the
existing verified native library. An earlier missing-library setup error was not
a source test result and is not counted as a pass. Fresh hosted checks and bot
review remain required before merge.
