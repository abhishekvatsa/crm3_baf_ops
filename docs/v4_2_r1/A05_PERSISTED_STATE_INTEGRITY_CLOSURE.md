# A-05 Persisted-State Integrity Closure

Status: CLOSED

Decision: `PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE`

## Finding

A-05 tracked persisted decoders and error paths that could manufacture state,
erase malformed records, or advance synchronization beyond an invalid record.
The highest-risk patterns were current-time, zero, empty-text and default-enum
substitutions, broad JSON coercion, and catches without a durable repair state.

## Source Closure

The final machine inventory covers 39 persisted decoder surfaces, 36 decoder
catch sites, 32 timestamp readers, 28 direct timestamp candidates and 234 risk
candidates. It reports no unclassified file, catch, candidate or stale policy.

Shared strict readers and domain validators now distinguish absent optional
state from malformed present state. Required persisted authority is not
manufactured. Maintenance and workflow synchronization quarantine or reject
malformed records before cursor advancement, and the application exposes a
stable operator repair state.

PR #204 admitted the complete inventory and decoder/containment tranche. PR
#205 admitted the production reconciliation adapter, its authenticated
loopback in-memory Flutter harness, Linux and Windows Flutter-layout support,
CI placement and regression witnesses.

## Production Reconciliation

The governed read-only sweep ran from clean, fetched `main` at commit
`3b517d7d72efb629ace4b7348e6839a60e7f40d0`, tree
`7f003322ed68856c0b941ba276fd6a31aedb986c`, against production project
`crm3-baf-ops-b8638`.

It reported `PASS_A05_READ_ONLY_PRODUCTION_RECONCILIATION` with zero blockers
and zero warnings. All eight populated audit records and the one populated
maintenance record passed the application's real strict readers. The three
user profiles and active runtime contract passed their strict shape checks.
No unknown root collection, uncovered Rules collection, uncovered source
collection, unsupported populated app collection, or populated `revisions`
collection group was found.

Raw document values and identifiers were not written to evidence. The sweep
used an ephemeral HMAC for pseudonyms, transported decoder inputs only over an
authenticated localhost in-memory channel, and had no cloud mutation path.
The governed evidence SHA-256 is
`DC5AEA0FB0694AEA60EC2B4F4E6917E0F2D480FE806C2BC8243056BD5A0B14EB`.

## Local Generations

Current-source local-generation authority is bound to PR #206 head
`7f4bd135393db4f9744c56d3649fb8191b61d564`, tree
`03402bde4eb74491c3268159ea862fbd986ccbee`. In immutable run
`31625578630`, job `94210993855`, the same checkout passed 137 A-05
regressions across 18 files and all four governed local-generation fixtures.
Those fixtures cover populated repository-proven v1-to-v3 migration,
production rejection and isolated adoption of the unadmitted v2 rehearsal,
every PREPARED/open/repair/COMMITTED restart boundary, and byte-sealed
backup/restore with correct database-generation continuity or rotation.

The reader boundary is deliberate. Firestore readers are exercised by their
focused regressions and the read-only production sweep. Local Isar generations
are exercised by their provenance, migration, repair, restart and
backup/restore paths; they are not misrepresented as Firestore documents.

The separately sealed Build 11 70K/P-06 record corroborates that current-source
campaign with installed-store evidence from one physical Android target and
one Android virtual target. It also records successful cloud reconciliation
with zero unsynced rows and zero unresolved rejections, and a 21-test native
store campaign.

That operational evidence remains authoritative and is not re-created or
reinterpreted as current-source proof by this closure. Its SHA-256 is
`D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0`.

## CI Authority

PR #205 exact-head run `31622397485` and admitted-main post-merge run
`31623568710` each passed all five governed jobs: Flutter host, Functions host,
Firestore Rules and callable emulator, Android emulator integration, and
Android release package with cold-start proof.

PR #206 exact-head run `31625578630` separately binds the closure decision to
the remediated source and current-source local-generation revalidation. All
five jobs passed; the Flutter job supplies the 137 A-05 plus four governed
local-generation results described above.

The exact closure record is
`release/evidence/a05-persisted-state-integrity-closure.json`.

## Boundary

This record closes only A-05. It performed no production data mutation, Rules
or Functions deployment, new device operation, pilot handout, unrestricted
distribution, or cutover authorization. Existing release and pilot authority
is neither enlarged nor withdrawn.
