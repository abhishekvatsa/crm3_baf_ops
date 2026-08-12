# P-06 Isar Provenance and Migration Safety

Status: CLOSED

Merge, deployment, and device evidence: PASSED

Related gate: `70K-RECOVERY` is `CLOSED`

## Finding

The previous pre-open guard treated an existing Isar store with no schema
marker as a known baseline and wrote the current version and fingerprint before
opening the database. It also stored version and fingerprint in separate
SharedPreferences keys and could fill a missing same-version fingerprint.

That behavior did not establish provenance. A marker write could be mistaken
for proof of the existing database's schema, and interruption could leave a
partial marker.

The historical behavior and v1 fingerprint are exact at commit
`33f599d90d3ff1057c3c8dd90f2b0d5f9ee941b7`. Repository history contains no
committed `currentSchemaVersion = 2` marker or exact v2 fingerprint.

## Source Decision

The guard now stores one exact JSON provenance envelope under
`baf_isar_schema_provenance_v1`. Its field set is closed:

```text
markerFormatVersion
state
schemaVersion
schemaFingerprint
databaseGenerationId
origin
sourceSchemaVersion
sourceSchemaFingerprint
```

Unknown, missing, wrong-typed, inconsistent, or unsupported fields fail
closed when durable Isar data exists. Marker persistence must succeed and read
back byte-for-byte.

The lifecycle is two phase:

```text
write PREPARED marker
open Isar
run idempotent post-open repair
write COMMITTED marker
clear legacy split keys
return the open database
```

If open, repair, commit, or legacy cleanup fails, startup closes the database
and enters the existing recovery flow. A target marker is never described as
committed before the open and repair sequence succeeds.

## Open Policy

| Durable store | Marker state | Decision |
| --- | --- | --- |
| absent | no marker | prepare a fresh generation |
| present | no marker | reject before `Isar.open` |
| present | partial legacy marker | reject before `Isar.open` |
| present | malformed canonical marker | reject before `Isar.open` |
| present | complete repository-recognized legacy marker | prepare canonical provenance and run registered steps |
| present | repository-unrecognized fingerprint | reject before `Isar.open` |
| present | matching canonical `PREPARED` | rerun idempotent steps and retry open |
| present | matching canonical `COMMITTED` | open without rewriting generation |
| absent | prior committed or migration-derived marker | create a replacement generation |

Lock-only `.isar.lock` residue is not durable data. A `.isar` or `.isar.tmp`
file is data-bearing and prevents fresh-install treatment.

## Fingerprint Authority

- v1 is accepted only with the exact fingerprint committed in the introducing
  repository revision.
- v2 is not accepted because no exact repository-proven v2 fingerprint exists.
  The code does not invent one from a test fixture or infer one from v3.
- v3 is accepted only with the current exact fingerprint.
- Migration-derived canonical markers must carry a recognized source
  fingerprint as well as the recognized target fingerprint.

Migration steps remain idempotent because a crash can leave `PREPARED` and
cause the same step sequence to run again.

## Database Generation

Every fresh or replacement store receives a UUID database generation. A normal
schema migration preserves that generation. Moving a store aside and opening a
clean store rotates it, even if SharedPreferences still contains the previous
marker.

The generation is local provenance. It is not written to ordinary telemetry.
It is available in the local recovery marker snapshot and is intended to become
the partition key for per-generation synchronization cursors.

## Recovery Evidence

Before startup writes diagnostics or permits a recovery rebuild, it captures
the raw values and stored types of:

```text
baf_isar_schema_provenance_v1
baf_isar_schema_version
baf_isar_schema_fingerprint
```

The snapshot is embedded in startup diagnostics and
`recovery_manifest.json`. The recovery package therefore preserves both the
raw Isar files and the marker evidence observed at failure.

The screen distinguishes provenance rejection from a generic database-open
failure, states that the store was not automatically stamped, and directs the
operator to preserve evidence before governed recovery.

## Verification

Source verification on 2026-07-27:

```text
Focused provenance and startup tests: 40 passed
Flutter analyze:                       no issues
Flutter full test suite:               510 passed
Functions build/non-emulator tests:    308 passed, 54 emulator tests skipped
Firestore Rules suite:                 144 passed
Governed transaction emulator suite:    54 passed
Release Isar schema/provenance audit:  PASS
Whole-app reconciliation source audit: 22 passed
Canonical R1 post-codegen audit:        68 passed
Generated workflow policy check:        PASS
```

The focused matrix covers exact marker shape, wrong storage types, unmarked and
partial existing stores, unsupported fingerprints, committed-source
provenance, write/readback failure, PREPARED restart, missing steps, generation
preservation and rotation, lock-only residue, startup order, and recovery
snapshot custody.

## Historical 70K Boundary

This source tranche prevents future silent adoption. It does not prove the
actual schema or row integrity of already installed stores.

In particular, a complete legacy marker is only compatibility input. Earlier
code could have created that marker after observing an unmarked store, so the
legacy marker alone is not device provenance.

Before pilot or any schema bump, `70K-RECOVERY` still requires:

1. A non-mutating installed-device inventory of absent, partial, complete
   legacy, and canonical markers.
2. Governed classification or correction of every existing unmarked or
   legacy-marked store.
3. Populated representative migration fixtures, including an explicitly
   adopted v2 fixture if v2 support is required.
4. Forced interruption and restart evidence at marker write, Isar open,
   post-open repair, and commit boundaries.
5. Row counts, relationship checks, generation continuity or rotation, backup,
   rebuild, pull, and cloud reconciliation evidence.

## Closure Addendum

PR #193 merged the source controls as
`28cb22064511c1abcb76759cbb302a303427f46f`; pull-request run `31511362504`
and admitted-main run `31512254539` passed all five release-gate jobs.

Finalized signed Build 11 then upgraded one physical Android target and one
Android virtual target in place without uninstall or app-data clear. Both
reported canonical current schema-3 provenance, stable database generation,
zero unsynced rows, zero unresolved rejections, successful reconnect and a
two-file app-native recovery package. The populated physical store preserved
both pre-existing rows across upgrade and restart.

The native 70K campaign passed 21 tests covering populated v1 migration,
fail-closed unknown v2 handling, PREPARED/open/repair/COMMITTED interruption,
byte-sealed backup/restore and generation rotation. Exact closure authority is
`release/evidence/70k-local-database-recovery-closure.json`, SHA-256
`D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0`.

This closes P-06 and `70K-RECOVERY`; it does not authorize pilot handout or
unrestricted distribution. Their re-arm triggers remain authoritative.

## Supersession

This record supersedes the safety claim in
`docs/issue_46_isar_schema_migration_and_input_validation.md` that existing
unmarked stores may be baseline-stamped. That file remains historical evidence
of the behavior that P-06 diagnosed.
