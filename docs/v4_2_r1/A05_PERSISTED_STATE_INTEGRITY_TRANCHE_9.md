# A-05 Persisted-State Integrity Tranche 9

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche replaces the remaining confirmed operational timestamp
substitutions with strict persisted-data readers. It does not close `A-05`:
non-timestamp parser and fallback classification, BAF knowledge-record
decoding, durable operator repair, and governed production and supported-local
reconciliation remain outstanding.

## Exact Inventory

`governance/a05-persisted-timestamp-surface-v1.json` classifies the admitted
timestamp surface by decoder, reader, required fields, and optional fields.
`tools/v4/a05_persisted_timestamp_inventory.py` derives the inventory from the
current source, records the exact Git commit and source-file SHA-256 values,
and fails when:

- a classified decoder or reader disappears;
- a required or optional field changes classification;
- a decoder stops binding a classified field from its strict reader;
- local-clock, permissive `_parseTimestamp`, or inline `DateTime.tryParse`
  logic returns to a classified decoder; or
- a new `fromMap` timestamp-risk site appears without classification.

The inventory contains nine persisted decoder surfaces: eight remote record
decoders and the nested template closure-review parser. It covers 15 required
timestamps and 19 optional timestamps. The eighth remote decoder,
`WorkflowCommandReceipt.fromMap`, was discovered by the generated inventory;
it was absent from the earlier seven-decoder review count.

## Source Boundary

The source change establishes these invariants:

1. Abnormality types require `createdAt` and `updatedAt`; charge abnormalities
   require `loggedAt` and `updatedAt`.
2. Job templates, executions, diary entries, modules, and operational
   directives require their own `createdAt` and `updatedAt` values.
3. Workflow command receipts require `appliedAt`; a missing or malformed value
   no longer becomes Unix epoch.
4. Deletion, lifecycle, completion, acknowledgement, submission, acceptance,
   reopen, and related optional timestamps may be absent. A present value must
   decode successfully.
5. A nested template closure-review confirmation time may be absent, but a
   malformed present value cannot be erased before top-level reconciliation.
6. Firestore `Timestamp`, `DateTime`, and parseable timestamp strings remain
   accepted and retain their exact instant. Arbitrary objects exposing
   `toDate()` are rejected.
7. All seven duplicated permissive `_parseTimestamp` helpers are removed from
   the classified model and provider files.

## Compatibility And Containment

Records missing a newly required timestamp or carrying a malformed present
optional timestamp now fail closed. They require governed inventory and repair;
the client does not infer one historical time from another, device receipt
time, or Unix epoch.

Existing repository, listener, synchronization, and UI error boundaries remain
responsible for containing decoder failures. This tranche preserves the
existing cursor non-commit and visible repair/error regressions, but does not
claim that every incompatible production or local record has been inventoried
or repaired.

## Verification

Focused tests cover accepted timestamp representations, every required field,
every optional field, nested closure-review parsing, exact workflow receipt
time, and compatibility with authoritative tombstone checks. The canonical
audit invokes the generated inventory so an unclassified `fromMap` timestamp
risk or a rebinding of any classified field fails CI.

Local verification before publication produced:

- generated inventory: 9 surfaces, 15 required fields, 19 optional fields,
  zero unclassified `fromMap` timestamp-risk sites;
- focused timestamp, governance, and tombstone suite: 14 passed;
- `flutter analyze`: no issues;
- complete Flutter suite: 727 passed;
- canonical source and governance audit: 118 of 118 passed.

Pull-request exact-head CI and admitted-main post-merge CI remain required
before this tranche is accepted as merged source evidence.

## Remaining A-05 Scope

`A-05` remains open for the complete non-timestamp persisted parser/fallback
inventory, BAF knowledge-record strict decoding, durable quarantine and
operator repair, and governed production and supported-local-generation
reconciliation.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, alter PITR, backup, or deletion-protection settings,
produce physical-device evidence, close a programme gate, close `A-05`, or
authorize pilot handout.
