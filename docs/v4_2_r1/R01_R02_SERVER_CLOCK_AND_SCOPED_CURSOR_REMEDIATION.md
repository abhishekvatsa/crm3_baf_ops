# R-01/R-02 Server Clock and Scoped Cursor Remediation

Status: CLOSED

Source merge and CI evidence: COMPLETE

Deployment, backfill, activation, and device evidence: PENDING

Findings:

- `R-01`: client-time delta cursor can permanently miss slow-clock writes.
- `R-02`: one global cursor is not partitioned by domain, user, or database
  generation.

## Finding

The prior global pull used each record's client-authored `updatedAt` and stored
one SharedPreferences value named `last_global_pull`. The next token was the
maximum observed client timestamp minus five minutes.

That design had two independent correctness defects:

1. A slow client could create a record behind the retained overlap forever.
2. One token crossed collection, actor, authority, and local-database
   boundaries. A successful subset could also advance the token past a failed
   subset.

The overlap reduced likelihood but did not establish a watermark.

## Source Decision

Protocol v1 is bound by
`governance/global-pull-protocol-v1.json`. Its fingerprint is the lowercase
SHA-256 of canonical JSON for `fingerprintedContract`:

```text
cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321
```

The exact pull set is:

```text
abnormality_types
charge_abnormalities
directives
job_diary_entries
job_executions
job_modules
job_templates
knowledge_base
maintenance_records
template_packages
template_publish_audits
template_versions
```

The source implements one retrying top-level Firestore trigger. It writes the
reserved `_globalPullServerUpdatedAt` field after every create or substantive
update in that set. A trigger-only stamp update is ignored to prevent
recursion. A hard delete is restored as a stamped soft tombstone.
Restored maintenance and job-execution tombstones are explicitly excluded from
new-ticket and new-assignment notification triggers. Template publish-audit
tombstones are applied to existing local evidence with fresher-unsynced
protection, are never inserted as phantom local records, and are excluded from
normal audit reads.

The callable and stamp trigger use separate dedicated runtime identities. The
callable identity is limited to Datastore Viewer and Logs Writer; the trigger
identity has Datastore User and Logs Writer plus the Eventarc Event Receiver and
Cloud Run Invoker roles required for authenticated event delivery. Neither
source binding uses the default Compute service account, and the two-function
rollout does not authorize any change to the existing deployed Function fleet
or its still-open S-01 campaign.

Firestore Rules prevent clients from supplying the reserved field on create or
changing/removing it on update. Client update paths already denied by Rules
remain denied rather than receiving a redundant guard.

## Run Window

An authenticated callable reads the current approved-user authority and an
exact `ACTIVE` runtime contract. It returns:

```text
actor UID
canonical authority digest
protocol identity
activation time
one server-side upper anchor
```

Every domain in that run uses:

```text
_globalPullServerUpdatedAt >= prior domain cursor
_globalPullServerUpdatedAt <= shared server anchor
order by _globalPullServerUpdatedAt
```

The lower bound is deliberately inclusive. Boundary records can be processed
again, but equal-timestamp records cannot fall between runs. The cursor advances
to the shared server anchor, not to the greatest record timestamp.

A source write committed before an anchor but stamped after it receives a stamp
after that anchor and is discovered by the next run. This removes dependence on
the originating device clock.

## Run Envelope

The client stores one exact JSON envelope under:

```text
baf_global_pull_cursor_v1:<actorUid>:<databaseGenerationId>
```

The envelope binds:

```text
PREPARED or COMMITTED state
actor UID
authority digest
P-06 database generation UUID
protocol version and fingerprint
run UUID
shared server anchor
all twelve domain cursors and completion flags
```

Unknown, missing, partial, wrong-typed, malformed, incompatible, or regressing
values fail closed. The complete domain set is mandatory. An actor change
during a domain run is detected before that domain cursor advances. An
authority-digest change resets all domains instead of reusing prior visibility.

Each clean domain completion is persisted and read back exactly. An interrupted
`PREPARED` run resumes the same anchor and skips only domains already durably
completed. A run becomes `COMMITTED` only after all domains complete.

The old `last_global_pull` value is never treated as a trusted lower bound. Its
presence forces a full reconciliation, and it is removed only after the fully
committed replacement envelope has been written and read back.

SharedPreferences is deliberate for this tranche. The envelope is bound to the
P-06 database generation without introducing an Isar schema bump while
`70K-RECOVERY` remains open.

## Activation Gate

The compatible client cannot begin a run until
`runtime_contracts/global_pull_v1` is `ACTIVE` with the exact protocol,
source-commit, activation-time, and backfill-receipt evidence.

`functions/tools/global-pull-server-clock.mjs` provides three modes:

| Mode | Mutation | Required controls |
| --- | --- | --- |
| `inventory` | none | explicit project; default mode; count-only evidence unless document-ID diagnostics are explicitly requested to an exclusive output file |
| `backfill` | stamps missing fields | matching project confirmation, operator, exact source commit, exclusive receipt path |
| `activate` | creates runtime contract | all backfill controls, sealed matching receipt, fresh zero-gap inventory |

All three modes emit privacy-safe, count-only evidence by default. Backfill and
activation never retain document IDs. The optional `--include-document-ids`
diagnostic is limited to read-only inventory, requires an exclusive output
file, and still keeps console output count-only. It is intended only for a
separately admitted malformed-record adjudication; ordinary readiness evidence
must leave it disabled.

Backfill scans every document in every protocol collection. It refuses to
start if any existing stamp is malformed, stamps only missing values with a
server timestamp and update-time precondition, then repeats the full inventory.
The receipt is emitted only when missing and malformed counts are both zero and
the write count exactly equals the preflight missing count.

Activation verifies the receipt seal, project, source commit, protocol, and
zero-gap result. It then performs a fresh inventory and creates the runtime
contract only if no contract already exists. This tool never overwrites or
repairs an existing contract.

## Required Rollout Order

This order is mandatory:

1. Merge the exact source head with green CI.
2. Create and read back the two exact dedicated runtime identities with only
   the roles in `release/global-pull-runtime-identity-policy.json`.
3. Deploy and read back the admitted Firestore Rules, callable, and retrying
   stamp trigger while leaving the runtime contract absent.
4. Prove legacy-client create/update compatibility after a server stamp exists,
   including overwrite-style writes.
5. Run read-only inventory and adjudicate every malformed value.
6. Run governed backfill while the stamp trigger is active.
7. Verify the sealed zero-gap receipt and repeat inventory.
8. Activate the exact runtime contract.
9. Deploy the compatible client to a controlled canary.
10. Prove first-run full reconciliation, interrupted-run resume, actor and
   generation isolation, tombstone discovery, and subsequent bounded pulls.

Backfill before the trigger is active is unsafe because concurrent writes could
recreate an unstamped gap. Deploying the compatible client before activation is
also prohibited because the client intentionally fails closed.

## Verification

Source verification on 2026-07-27:

```text
Focused cursor/pull/tombstone/ledger:      40 passed
Full Flutter test suite:                  524 passed
Flutter analyze:                           no issues
Full Functions unit suite:                314 passed, 56 skipped
Firestore Rules emulator suite:           145 passed
Governed Firestore emulator suite:         56 passed
Cross-layer protocol source audit:         15 passed
Whole-app reconciliation audit:            23 passed
Canonical audit, post-codegen phase:       69 passed
Pinned Isar release authority:             PASS
Generated workflow-policy parity:          PASS
```

The emulator proves that malformed stamps prevent every backfill write and that
a sealed, zero-gap backfill receipt is required before immutable protocol
activation.

## Merge and CI Evidence

PR #55 merged exact source head
`f356835d08711e804de5f591f12794079f064024`, tree
`f1f5feea68f712ef4ee5e281a4f26790d2d4d2a3`, to main as
`1bf9f1e3f181e73d9cbf7ee49a14704269ef081b` with the identical tree.

Post-merge release-gate run `30282720232` passed on that exact main commit:

```text
Flutter analyze + tests + no-loss spine:          PASS
Firestore Rules + governed transaction emulator: PASS
Cloud Functions build + test:                     PASS
```

Decision:
`PASS_R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_CLOSURE`

R-01 and R-02 are closed under their `SOURCE_AND_CI` authority. Any loss of
the server-authored discovery clock, inclusive bounded window, exact
actor/authority/database-generation cursor envelope, immutable activation
gate, or corresponding regression evidence re-arms the applicable finding.

## Operational Boundary

Source-and-CI closure means the diagnosed source defects are corrected and
their exact-head merge evidence is complete. It is not a deployment, live
backfill, runtime activation, device-proof, pilot, or cutover claim.

Until the remaining rollout order is evidenced:

```text
R-01 source-and-CI finding: closed
R-02 source-and-CI finding: closed
runtime contract:           inactive
pilot/cutover authorization: prohibited
```
