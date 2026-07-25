# Clean-Cutover and Rollback Policy

## Data premise

The existing local and backend records were created during development and are not asserted to be site-truth operational data. Therefore, the new architecture is not constrained by preservation of disposable records.

## Initial trial

The first authoritative trial uses:

- authentic code generation;
- full analysis/tests;
- emulator proof;
- a separate Firebase staging project;
- empty new workflow collections and known-good synthetic records;
- fresh installation on a clean test device.

It does not require an in-place upgrade of the old Isar database.

## Safety boundary

Development data may be reset only after:

1. exact Firebase project identity is verified;
2. a read-only collection/document-count and schema inventory is captured;
3. the target is confirmed not to contain site-truth data;
4. deletion/reset is separately and explicitly authorised.

This candidate performs none of those deletions.

## Live-project rollback principle

Before any future live backend mutation:

- tag and fresh-clone/build the pre-successor code baseline;
- capture the deployed Rules and Functions identities;
- take a managed Firestore export;
- rehearse Rules and Functions rollback;
- deploy to staging first;
- use a bounded pilot ring;
- keep client rollout last.

Code rollback does not undo data already written. Data recovery must therefore remain a separate decision using the export, repair scripts or deliberate retention of additive fields.

## Isar generated-position boundary

Authentic `build_runner` output may assign different numeric `PropertySchema.id`
positions when additive fields change generated ordering. Those generated
positions are reported for custody but are not treated as immutable data-field
identity. The continuity gate remains strict on inherited collection identity,
property names and types, and index definitions.

If a later programme phase requires an in-place upgrade of retained local data,
that requirement must be proven with a dedicated old-database-to-successor
migration test. It is not required for the initial clean-cutover pilot.
