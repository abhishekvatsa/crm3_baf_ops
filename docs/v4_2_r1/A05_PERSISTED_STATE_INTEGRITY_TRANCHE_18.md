# A-05 Persisted-State Integrity Tranche 18

Status: OPEN - SOURCE CLOSURE AWAITING OPERATIONAL EVIDENCE

## Scope

This tranche completes the machine-generated non-timestamp decoder and catch
inventory, remediates the remaining authority-bearing decoder surfaces, and
adds the read-only production reconciliation gate required for final closure.
It does not change the `A-05` ledger status because production evidence must be
captured from clean, admitted `main` after this source is merged.

## Exact Inventory

`governance/a05-persisted-decoder-surface-v1.json` and
`tools/v4/a05_persisted_decoder_inventory.py` now govern:

- 39 strict-reader or raw-JSON decoder surfaces, including presentation code;
- 36 structurally discovered decoder-bearing catch sites across domain,
  service, provider and presentation code;
- all 32 strict timestamp readers inherited from the v2 timestamp inventory;
- every catch site's authority boundary, mutability, malformed disposition,
  regression witness and re-arm condition; and
- exact risk fingerprints that fail when a decoder, catch, fallback, enum
  default, zero/empty substitution or string coercion changes.

The inventory fails on a newly discovered decoder file, an unclassified catch,
a stale policy, a timestamp inventory failure or a changed source fingerprint.
Bounded exceptions remain explicit and fingerprinted, including non-mutating
correction discovery, opaque legacy closure metadata preservation,
display-only rendering, pre-mutation form validation and command error
presentation. Malformed local module snapshots are not an exception: they now
produce visible repair state and disable module work mutations.

## Decoder Corrections

The shared strict readers and model-specific validators now reject malformed
required or present optional state across maintenance records, workflows,
planned templates, executions, modules, diary records, template governance,
module registry content, assignment idempotency receipts and knowledge import.

The immutable template snapshot contract validates required template identity,
module and field linkage, enum aliases, scalar types, lists and closure-review
chronology. Fresh local Composer creation is an explicit authoring boundary;
saved authoring drafts permit empty module/field collections but still require
real template identity, while published assignment snapshots require populated
and assignment-valid collections.

Maintenance pull and workflow pull keep malformed records in counted durable
repair state and do not advance a cursor past an invalid or unrecorded boundary.
Existing corrupt quarantine also blocks advancement until an authorized,
explicit local repair action clears that quarantine alone.

## Production Reconciliation Gate

`tools/v4/a05_production_persisted_integrity_sweep.mjs` is read-only and has no
cloud mutation path. Production execution requires clean fetched `main`, exact
commit and tree expectations, exact project confirmation, no emulator host, a
privacy HMAC key and a new evidence path.

The sweep enumerates every registered root collection and the `revisions` and
`notification_installations` collection groups. Before any cloud read, it
also extracts collection literals and named collection constants from all
non-generated app and Functions source and fails if the registry omits one.
It validates `users` and the active global-pull runtime contract exactly.
Unknown live collections fail coverage closed. Any app-decoded operational record produces a pseudonymized
reconciliation hold so that it must be passed through the supported Dart
reader and repair path before closure. Server-only receipts are counted and
explicitly excluded from app-decoder evidence.

This conservative boundary makes an empty operational collection a positive
statement that no historical record requires repair; it never treats an
uninspected nonempty collection as clean.

## Regression Evidence

Focused tests cover malformed required and optional fields, canonical/legacy
discrimination, strict snapshot identity, fresh versus recovered authoring,
durable quarantine ordering, response and receipt integrity, collection
registry coverage, production custody and privacy-safe reconciliation holds.
The complete Flutter suite, Functions suite, governed emulator suites,
canonical audit, exact-head pull-request CI and admitted-main post-merge CI
remain required evidence.

## Remaining A-05 Scope

`A-05` remains open only for source admission, the governed read-only
production sweep, supported-local-generation evidence binding, final ledger
adjudication and admitted-main CI. The production sweep must report zero
blocking findings; otherwise the finding remains open for the identified
reconciliation or repair.

This tranche does not mutate production documents, deploy Firebase Rules or
Functions, operate a phone, close a programme gate, close `A-05`, or authorize
pilot handout.
