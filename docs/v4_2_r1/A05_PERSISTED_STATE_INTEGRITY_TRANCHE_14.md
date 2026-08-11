# A-05 Persisted-State Integrity Tranche 14

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes the known non-timestamp manufacturing defaults in remote
module-registry family and revision records. It also replaces the incomplete
v1 timestamp inventory with direct strict-reader call-site enforcement. It
does not change the `A-05` ledger status.

## Registry Families

`ModuleRegistryFamily.fromMap` now delegates to a strict remote reader. The
reader verifies that `registryModuleId` matches the Firestore document ID and
requires the persisted module code, title, status, discipline, asset type,
lists, closure flag, publication counter, actors, versions and schema version.
Missing or malformed values are no longer replaced with `MODULE`, `shared`,
`base`, empty lists, false, zero or version 1.

String-list entries retain exact string typing, reject empty and duplicate
entries, and are bounded. Optional pointer fields may be absent, but malformed
present values fail. A family with zero publication history cannot carry a
latest revision or hash pointer.

The existing governed compatibility path remains explicit. A historical
family with a positive latest-published revision number may retain one or both
missing pointer fields so `_ensureLatestPublishedPointers` can resolve and
transactionally repair them from immutable revision history. No counter,
identity or hash is inferred by the reader.

Active families cannot carry retirement state. Retired families require the
retirement timestamp, actor UID and reason. All lifecycle times must remain
inside the creation/update interval.

## Registry Revisions

Every revision read now binds the stored parent registry ID to the Firestore
parent and binds `revisionId` to the revision document ID. Required status,
revision number, JSON snapshots, content hash, lineage, actors, versions and
schema version fail closed when absent or malformed.

The module snapshot and lineage must be JSON objects. Field and checklist
payloads must be arrays of objects, and every entry must reference the same
recognized module identity. String aliases retained by historical snapshots
remain readable, but non-string values are no longer coerced with
`toString()`.

The persisted `mrg1-sha256` hash is recomputed from the three frozen payloads
on every remote decode. A syntactically valid but mismatched hash is rejected
before the revision can participate in optimistic concurrency, publication or
Composer source selection. The clone path uses strict JSON readers and no
longer catches malformed JSON and substitutes empty content.

Draft revisions require revision number zero and no publication or retirement
history. Published and retired revisions require positive numbers and complete
actor/time evidence for each attained lifecycle state. Contradictory or
out-of-order history fails closed.

## Inventory Correction

The former inventory discovered unclassified timestamp risk only inside
`fromMap`, `fromCloudMap` and `fromJson` factories containing three selected
fallback tokens. That could not support its claim of exact coverage. It omitted
strict readers implemented as top-level functions and strict factories that no
longer contained those fallback tokens.

The v2 manifest classifies every direct call to
`readRequiredPersistedDateTime` and `readOptionalPersistedDateTime` in
non-generated Dart source. Each entry records an owner, purpose, authority
boundary, regression witness and re-arm condition. The extractor binds each
call to exactly one declared function body and fails on an unclassified or
multiply owned call.

At this tranche the machine report covers:

- 25 classified readers;
- 75 direct strict-reader calls;
- 36 required timestamp fields;
- 39 optional timestamp fields; and
- zero unclassified or duplicate call sites.

The report separately exposes 35 direct `DateTime` parser and epoch-sentinel
candidates. Those candidates include transport parsing, display containment,
runtime clocks, local generated-record sentinels and possible persisted-state
readers. They are evidence for the remaining behavior-classification work and
are not silently treated as closed by this tranche.

## Containment And Verification

All Firestore registry reads use the strict factories. A malformed family or
revision therefore aborts its transaction, page, source selection or authoring
load before the record is exposed as usable state. Registry Authoring retains
its existing visible governance-repair state and mutation lock when loading
fails.

Focused tests cover exact document and parent identity, required scalar types,
enums, lists, booleans, counters, versions, schema version, pointer
compatibility, JSON roots and entries, module references, canonical hash
matching, lifecycle actors and timelines, model behavior, concurrency and UI
containment.

`A-05` remains open for behavior classification and remediation of the direct
parser/sentinel candidates, the complete non-timestamp persisted parser/catch
inventory, durable counted quarantine and operator repair, and governed
production plus supported-local-generation inventory, reconciliation and
repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, operate a phone or emulator, close a programme gate, close
`A-05`, or authorize pilot handout.
