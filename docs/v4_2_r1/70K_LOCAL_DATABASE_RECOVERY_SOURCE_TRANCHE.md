# 70K Local Database Recovery Source Tranche

Date: 2026-08-11
Base main commit: `f4679ef6b001aa6971f1599a464e0f4d551f17bf`
Authority: source and CI evidence only until the installed-target campaign is
adjudicated

## Scope

This tranche supplies the missing source-side tools and populated database
evidence for `70K-RECOVERY` without weakening the existing P-06 fail-closed
startup handshake.

It does not stamp, adopt, clear, rebuild, or otherwise mutate an installed
store. It does not add a production v2 fingerprint. It does not by itself
authorize pilot handout or close `70K-RECOVERY`.

## Installed-store inventory

`IsarInstalledStoreProvenanceInventory` classifies, without mutation:

- durable store present or absent;
- canonical marker absent, malformed, PREPARED, or COMMITTED;
- legacy marker absent, partial, malformed, or complete;
- recognized current, recognized migration, unsupported, unmarked, residue,
  restart, and recovery-review dispositions.

The classifier treats malformed stored types as startup blockers even when
another marker appears valid. That matches the actual SharedPreferences reader
ordering.

Startup captures this classification before the schema guard can migrate,
commit, or reject the installed store. The Admin/SI Local Diagnostics report
uses that preserved pre-open snapshot, rather than reclassifying only the
post-migration state. Its privacy-safe form exports a SHA-256 digest of the
database-generation identity, never the raw generation identity or raw marker
JSON. The report provider and screen both require approved Admin/SI authority
before local evidence is read.

Canonical recognition covers both the target fingerprint and, for
source-bearing migration origins, the recorded source version and fingerprint.
A current target whose migration ancestry is not repository-proven is blocked
with `stored-schema-fingerprint-unrecognized`, matching production startup.

The startup-failure recovery manifest also carries the preserved privacy-safe
classification. Its existing separate schema-marker snapshot remains
intentionally raw for sealed recovery custody; that raw snapshot is not used by
the Admin/SI privacy-safe diagnostics export.

## Populated migration fixtures

`test/70k_isar_populated_migration_fixture_test.dart` exercises real native
Isar files and populated template, execution, module, and diary rows.

### Repository-proven v1

The fixture reconstructs all 16 v1 collections from
`CANONICAL_ISAR_SCHEMA_BASELINE.json`, including the exact collection,
property, and index IDs captured from commit
`633c58bb0d936011e391b42627f8b8f02c510e95`.

The current app opens that exact on-disk shape with the full v3 schema. It then
runs the production post-open relationship repair and commits canonical
provenance. Assertions prove:

- template, execution, module, and diary rows survive;
- template-to-execution, execution-to-module, and module-to-diary Firestore
  identities remain exact;
- transported local integer links are cleared;
- newly introduced workflow collections open empty;
- the v1 legacy marker is cleared only after COMMITTED is durable.

### Governed v2 boundary

No repository-proven historical v2 fingerprint exists. Production therefore
continues to reject the governed synthetic v2 fixture with
`stored-schema-fingerprint-unrecognized` and performs no canonical write.

The test separately exercises a narrowly scoped, test-only adoption plan over
the populated v2 shape (`v1` base plus workflow control-plane collections).
That rehearsal reaches v3 with rows and relationships intact. Its fingerprint
is not present in `IsarSchemaMigrator.defaultPlan` and is not production
authority.

## Interruption and restart

A durable file-backed marker store and repeated native Isar close/reopen cycles
force the startup sequence to stop and resume at:

1. canonical PREPARED written, before database open;
2. Isar open, before post-open repair;
3. post-open repair durable, before COMMITTED;
4. COMMITTED, followed by another restart.

Every restart creates a new provenance-store instance and reads only durable
state. The database generation remains unchanged, the repeated post-open repair
is idempotent, and COMMITTED appears only after open and repair succeed.

## Backup, rebuild, and generation

The fixture creates a byte-sealed backup of the populated Isar file and durable
marker, then proves:

- deleting the test database and rebuilding empty rotates the generation;
- the rebuilt database contains no inherited rows;
- restoring the sealed copy reproduces every backed-up file hash;
- the restored marker retains the original generation;
- all representative rows and relationships are readable after restore.

All deletion occurs only inside test-created temporary directories.

## Required installed-target evidence

Before closure, a compatible signed build must still be upgraded in place on
every installed target, preserving app data. Each target must export the
privacy-safe inventory and show either canonical-current provenance or enter a
separately governed recovery decision. The campaign must also bind local row
and unsynced counts to successful pull/cloud reconciliation and the existing
production backup/readback evidence.

Until that evidence is admitted, `70K-RECOVERY` and P-06 remain open at their
current deployed-runtime boundaries.
