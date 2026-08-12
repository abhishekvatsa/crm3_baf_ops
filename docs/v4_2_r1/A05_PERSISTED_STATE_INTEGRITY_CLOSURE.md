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

The separately sealed Build 11 70K/P-06 record supplies the supported local
generation authority. It covers one physical Android target and one Android
virtual target, populated repository-proven migration, every interruption and
restart boundary, byte-sealed backup/restore, database-generation continuity
or rotation, and successful cloud reconciliation with zero unsynced rows and
zero unresolved rejections. Its native store campaign passed 21 tests.

That existing evidence remains authoritative and is not re-created or
reinterpreted by this closure. Its SHA-256 is
`D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0`.

## CI Authority

PR #205 exact-head run `31622397485` and admitted-main post-merge run
`31623568710` each passed all five governed jobs: Flutter host, Functions host,
Firestore Rules and callable emulator, Android emulator integration, and
Android release package with cold-start proof.

The exact closure record is
`release/evidence/a05-persisted-state-integrity-closure.json`.

## Boundary

This record closes only A-05. It performed no production data mutation, Rules
or Functions deployment, new device operation, pilot handout, unrestricted
distribution, or cutover authorization. Existing release and pilot authority
is neither enlarged nor withdrawn.
