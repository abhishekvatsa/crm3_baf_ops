# A-05 Persisted-State Integrity Tranche 17

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche classifies the complete remaining direct Dart timestamp-parser and
epoch-sentinel surface and removes three weak persisted-input decoders. It does
not change the `A-05` ledger status.

## Strict Decoder Corrections

The shared persisted timestamp reader now supports an explicitly enabled
serialized Firestore timestamp map. A map is valid only when it uses exactly
one supported key pair, supplies both seconds and nanoseconds as integers, and
keeps nanoseconds within the Firestore range. Partial, mixed, fractional,
negative, out-of-range, or otherwise malformed maps fail closed.

Three authority-bearing paths now use the shared reader:

- backend release identity accepts an absent optional deployment time but
  rejects a malformed present value or incomplete serialized timestamp;
- template-version snapshot validation rejects malformed present closure-review
  chronology before publication or assignment; and
- template lifecycle audit reconciliation rejects malformed saved `updatedAt`
  evidence rather than coercing it through `toString()` and `tryParse`.

## Exact Candidate Classification

`governance/a05-direct-timestamp-candidate-classification-v1.json` classifies
all 29 direct parser and epoch-sentinel sites in current non-generated Dart
source into six permitted behavior classes:

- shared strict-reader implementation;
- fail-closed authority parser;
- non-persisted runtime sentinel;
- typed local-storage initializer;
- sort-only null-ordering sentinel; and
- display-only best-effort parser.

`tools/v4/a05_persisted_timestamp_inventory.py` derives each site from source,
assigns a stable per-file expression occurrence, and fails on any unclassified,
duplicate, or stale classification. The current inventory has zero unclassified, duplicate, or stale sites.

The strict-reader manifest now covers 32 readers, 82 direct calls, 41 required
fields, and 41 optional fields. The three added readers are the backend release
identity response, template lifecycle audit snapshot, and template snapshot
closure-review evidence.

## Regression Evidence

Focused tests prove complete serialized timestamp maps decode exactly, malformed
map shapes fail closed, absent optional values remain absent, malformed present
backend and template-snapshot values are rejected, and lifecycle matching is
bound to the shared strict reader without string coercion.

## Remaining A-05 Scope

`A-05` remains open for the complete non-timestamp persisted parser and catch
inventory, any resulting durable repair work, and governed production plus
supported-local-generation inventory, reconciliation, and repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, operate a phone or emulator, close a programme gate, close
`A-05`, or authorize pilot handout.
