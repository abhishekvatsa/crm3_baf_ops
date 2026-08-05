# A-05 Persisted-State Integrity Tranche 1

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Decision

This tranche removes a high-risk subset of the state-manufacturing and
state-suppression behavior tracked by `A-05`. It does not close the finding or
change its ledger status. `A-05` remains `OPEN` until the remaining persisted
model and payload paths are remediated and legacy data has an explicit
inventory and repair decision.

The scope of `A-05` is persisted-state decoding and error suppression. A use
of `DateTime.now()` to timestamp a new local action is not, by itself, a
defect. Substituting the current time when an authoritative stored timestamp
is missing or malformed is a defect.

## Strict Reader

`lib/core/serialization/persisted_data_reader.dart` provides stable
`PersistedDataFormatException` failures for required timestamps, strings,
enums, finite numbers, string lists, JSON object lists and optional JSON
objects. It accepts documented legacy representations, such as an audit epoch
timestamp, but does not invent a value when decoding fails.

## Maintenance History

Resolution history is now decoded as a complete JSON object list. Every entry
must contain a valid `resolvedAt`; present fields must have the expected type.
A malformed list, non-object entry, invalid timestamp or wrong-typed field is
not converted to an empty history.

Local and Firestore reopen paths decode the prior list before appending the
new closure. A malformed or absent Firestore history therefore blocks the
update instead of erasing earlier history. No automatic repair, reset or
write-back occurs. Validated raw rows are retained when the new entry is
appended, including unknown legacy extension keys that the current typed model
does not interpret.

The resolution screen represents this state explicitly with a
`Resolution history needs repair` notice, states that no entries were
discarded or replaced, and blocks the resolution command before form or
repository work begins.

## Audit Integrity

Remote audit records now require valid entity identity, action, actor,
severity and timestamp fields. Optional text, enum and before/after snapshots
are accepted only in their declared shapes. Malformed remote audit state is
re-thrown before the native offline fallback, so corruption is not presented
as an empty or merely unavailable remote history.

Local audit snapshot getters no longer catch malformed JSON and return null.
Snapshot setters no longer erase values that cannot be serialized. Callers
receive the decoding or encoding failure.

## Suppressed Cleanup Failure

The sign-out one-shot-sync-marker reset no longer has an empty catch. Failure
is recorded through the privacy-bounded application logger while sign-out
continues.

## Remaining A-05 Scope

The finding remains open for at least these persisted-state families:

- component-action timestamps and broad JSON decoding;
- template fields, validation payloads and job/template response payloads;
- `JobTemplate`, `JobExecution`, template-governance and module-registry
  timestamp fallbacks;
- module-composer payload defaults and silent JSON catches;
- maintenance, planned-work and directive remote-map timestamp fallbacks;
- remote tombstones that substitute local current time for absent deletion
  authority;
- a governed legacy-data inventory, reconciliation procedure and operator
  repair path for records that the stricter readers reject.

These families require separate regression and UI/error-path review. This
tranche must not be used as evidence that every empty catch or persisted
`DateTime.now()` fallback has been removed.

## Reconciliation Label Correction

Refreshing the captured-path hashes exposed five existing disposition-label
errors. Each path has a real source delta from canonical main but was still
labelled `BYTE_IDENTICAL`:

- `lib/features/admin/presentation/local_diagnostics_screen.dart`;
- `lib/features/audit/repositories/audit_repository.dart`;
- `test/issue_1_tombstone_conflict_regression_test.dart`;
- `test/planned_job_server_completion_no_loss_test.dart`;
- `test/runtime_module_population_no_loss_test.dart`.

Their hashes were already distinct. Correcting those labels moves the
aggregate from `262 / 148` to `257 BYTE_IDENTICAL / 153 SUCCESSOR_MODIFIED`.
This tranche also legitimately changes the previously byte-identical audit
event model and admin history writer, so the final aggregate is `255 / 155`.
It does not modify the four non-A-05 source files in the correction list.

## Evidence And Boundary

The focused regression file proves strict timestamp and history parsing,
valid history preservation, audit-record shape rejection, non-erasing local
audit snapshots, visible UI blocking and removal of the named silent catches.
Local pre-pull-request evidence is clean: Flutter analysis reports no issues,
all nine focused regressions pass, the full Flutter suite passes 654 tests,
and the canonical audit passes 113 of 113 checks. The governed pull-request
and admitted-main CI runs remain required before this source tranche is
accepted.

This work does not inspect or mutate production documents, repair legacy
records, deploy Firebase resources, produce physical-device evidence, close a
programme gate, close `A-05`, or authorize pilot handout.
