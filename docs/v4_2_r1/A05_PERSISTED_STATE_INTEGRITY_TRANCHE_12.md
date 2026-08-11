# A-05 Persisted-State Integrity Tranche 12

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes the known abnormality-type and charge-abnormality
persisted-decoder gap. It also removes adjacent local save helpers that
manufactured required business state from uninitialized models. It does not
change the `A-05` ledger status.

The reviewed source surfaces are:

- `abnormality_types/{documentId}` Firestore listeners, point reads and
  global-pull pages;
- `charge_abnormalities/{documentId}` Firestore listeners, callable response
  evidence, point reads and global-pull pages;
- embedded affected-asset arrays and local Isar JSON payloads;
- local abnormality type and charge-abnormality save/update entry points; and
- timestamp-inventory, tombstone and focused persisted-integrity regressions.

## Persisted Contract

Both model factories now delegate to one strict abnormality reader. The reader
requires embedded document identity, required business text, exact enum names,
boolean values, positive integer versions and charge numbers, required
timestamps and deletion state. The embedded `firestoreId` must match the
Firestore document ID. Unknown enums, scalar coercions, blank required text,
wrong present optional types and over-limit strings fail with
`PersistedDataFormatException`.

Abnormality types require category, severity, applicable-asset list,
re-annealing suggestion, active/deleted state, creation/update timestamps and
a positive version. Applicable asset types must be exact enum values without
duplicates. Actor display names cannot exist without their UID authority.

Charge abnormalities require their source charge, canonical type identity,
title and code, category, severity, affected-asset list, observation, root
reason category, re-annealing status, logger/updater authority,
logged/update timestamps and a positive version. Optional descriptive and link
fields may be absent; malformed present values are not treated as absence.

## Embedded Assets

Every affected asset must be an object containing only `assetType` and
`assetNumber`. Asset types use exact persisted enum names and asset numbers are
positive integers. The list is limited to 50 entries and duplicate
type/number identities fail closed. Alias strings, numeric strings, malformed
items, extra fields and non-list roots are rejected.

Local `affectedAssetsJson` may initialize empty only when absent, blank or the
canonical empty array. Malformed JSON and malformed present entries are no
longer converted to an empty asset list.

## Lifecycle And Timeline

Type `updatedAt` cannot precede `createdAt`. Charge `updatedAt` cannot precede
`loggedAt`. A present deletion time must stay within the corresponding record
timeline.

Lifecycle state is validated rather than repaired:

- deleted abnormality types are inactive, carry authoritative `deletedAt`,
  and identify the deleting UID;
- non-deleted types carry no deletion metadata;
- completed re-annealing and a positive target charge are present together;
- the re-annealed charge differs from the source charge;
- deleted charge abnormalities carry authoritative deletion time, UID, actor
  name and reason; and
- active charge abnormalities carry no deletion metadata.

## Local Save Boundary

The Isar and Firestore repository save/update methods previously called
helpers that caught uninitialized fields and supplied UUID-derived codes,
`Untitled Abnormality`, `UNKNOWN`, `No reason recorded`, local clock values or
version 1. Those helpers are removed.

Supported UI creation and seed paths already initialize the required fields.
Repository entry points now trim ordinary user text and validate required
identity, actor, timestamp, version, asset, re-annealing and deletion state.
Invalid or uninitialized local models fail before local or remote persistence.
UUID assignment for a genuinely new record remains the identity-generation
step and does not manufacture business content.

## Containment

Firestore listeners and point reads decode before records reach the UI.
Callable mutation responses use the same strict charge-abnormality factory
before returned evidence is admitted. Global-pull pages decode every document
before returning a page, so malformed source data aborts the domain before
local insert/update and before the global cursor commit.

The machine-generated timestamp inventory remains at 13 decoder surfaces, 19
required timestamp fields and 21 optional timestamp fields. Its two
abnormality entries are rebound to the full strict reader while retaining the
existing timestamp value objects.

Focused regressions cover every required authority field, document identity,
unknown enums, number/boolean coercion, malformed optional values, affected
asset structure and cardinality, duplicate assets, actor linkage, reversed
timelines, re-annealing contradictions, complete and incomplete tombstones,
local JSON suppression, factory delegation and removal of local manufactured
defaults.

`A-05` remains open for the remaining non-timestamp persisted parser/catch
inventory, durable counted quarantine and operator repair, and governed
production plus supported-local-generation inventory, reconciliation and
repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, alter PITR or backup settings, operate a phone, close a
programme gate, close `A-05`, or authorize pilot handout.
