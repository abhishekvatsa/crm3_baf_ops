# A-05 Persisted-State Integrity Closure

Status: CLOSED

Decision: `PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE`

## Finding

A-05 tracked persisted decoders and error paths that could manufacture state,
erase malformed records, or advance synchronization beyond an invalid record.
The highest-risk patterns were current-time, zero, empty-text and default-enum
substitutions, broad JSON coercion, and catches without a durable repair state.

## Source Closure

The closure-time machine inventory covered 39 persisted decoder surfaces, 36 decoder
catch sites, 32 timestamp readers, 28 direct timestamp candidates and 234 risk
candidates. It reports no unclassified file, catch, candidate or stale policy.

The 21 August 2026 business-function re-arm expands the current inventory to
64 decoder surfaces, 45 decoder catch sites, 64 timestamp readers and 319 risk
candidates. The new asset-availability, Furnace stuck-up, frequent-issue,
maintenance-intelligence and inspection records are explicitly classified;
the current inventories again report no unclassified or stale policy.

The 23 August 2026 issue-workflow re-arm brings the current inventory to 68
decoder surfaces, 44 decoder catch sites, 68 timestamp readers and 348 risk
candidates. It classifies the complete issue-lane topology and refreshes the
resolution-history, closed-ticket display and maintenance replay boundaries.
The prior presentation catch for local downtime parsing was removed because
downtime is now calculated by the governed server command; no decoder catch is
left unclassified or stale.

The same-day cross-business receipt re-arm brings the current inventory to 70
decoder surfaces, 45 decoder catch sites, 69 timestamp readers and 370 risk
candidates. Asset hierarchy, registry, Inner Cover and asset-condition
mutations now require request-bound, versioned, canonical server receipts.
Maintenance-workflow receipts require their exact field set and canonical UTC
application time. Invalid evidence is reported as an uncertain remote outcome
and never manufactures local success. The current inventories again report no
unclassified file, timestamp call, catch site, direct parser or stale policy.

The 24 August 2026 administrative issue-closure and audited terminal-ticket
correction re-arms bring the current inventory to 71 decoder surfaces, 45
decoder catch sites, 69 timestamp readers and 373 risk candidates. The
versioned unresolved-closure disposition and
rationale fail closed when partial or malformed, while unrelated legacy
metadata is retained as opaque evidence during a governed merge. The current
inventories report no unclassified file, catch site, timestamp call, direct
parser or stale policy.

The 25 August 2026 exact-device recovery re-arm, including its restart journal
index, brings the current inventory to 73 decoder surfaces, 48 decoder catch
sites, 69 timestamp readers and 387
risk candidates. The pre-clear journal is request-, user- and
installation-bound; malformed or incomplete journal evidence blocks further
local deletion and preserves the original retained Isar snapshot. Android is
the sole eligible recovery platform until an equally durable implementation is
present elsewhere. Before any deletion is authorized, the Android bridge
synchronizes the retained snapshot file and each directory entry in its
application-private path, while a failed durability confirmation blocks the
reset. On Android restart, sign-out now probes for an active crash-durable
request journal, and listener startup reserves session exit before its first
server poll. The reservation is released only after a successful no-request
check or after the returned request has acquired retained recovery protection;
an unreadable journal state remains fail-closed. After the server accepts a
terminal receipt, the durable journal is atomically renamed and retained as
terminal evidence before sign-out protection ends. A later successful
no-request poll performs the same identity-bound retirement for the narrow
server-commit/local-rename crash window, so historical terminal evidence does
not block an offline sign-out on every future restart. That poll also re-syncs
an already renamed terminal entry before releasing protection, covering a
rename-success/directory-sync-failure restart. Any active journal owned by a
different user or installation remains a blocking inconsistency rather than
being silently ignored. Journal validation runs before both the no-request and
request-returned branches: the exact returned request remains active, while
older same-phone journals are retired only because the server's single-state
contract proves that they are no longer pending or in progress. A revoked or
deregistered phone may receive the terminal no-request result only after the
server revalidates the exact state identity, canonical completion or failure
fields, administrator receipt, original claim audit and matching final audit.
Missing or inconsistent terminal proof therefore retains the local journal and
sign-out protection instead of stranding or silently releasing it. The current
phone-registration wait is also bounded: if registration remains unavailable,
the listener first re-syncs any visible retained terminal-journal directory
entry, then releases the startup reservation only after a fresh local probe
proves that no active recovery journal exists. Terminal sync failure, active or
unreadable journal state remains fail-closed and is retried on a later listener
check, including app resume. The current inventories again report no
unclassified file, catch site, timestamp call, direct parser or stale policy.

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
`ed8b8fb0655d2fb5396f10daecb3e6ab49966342`, tree
`98af51decc0c4b2fe9257d66dcb4de4766aa1cfd`. In immutable run
`31628102225`, job `94219670718`, the same checkout passed 137 A-05
regressions across 18 files and all four governed local-generation fixtures.
Those fixtures cover populated repository-proven v1-to-v3 migration,
production rejection and isolated adoption of the unadmitted v2 rehearsal,
every PREPARED/open/repair/COMMITTED restart boundary, and byte-sealed
backup/restore with correct database-generation continuity or rotation.

The fixture also executes current A-05 local readers against the records after
v1 migration, isolated v2 adoption, and byte-sealed restore. Compatible fields,
responses, module snapshots, and field definitions remain valid. The historical
execution and module action payload lacks the now-required `asset` field; its
raw bytes are retained, a stable invalid repair state is exposed, and any
authoritative action read fails. The disposition is
`PRESERVE_AND_BLOCK_PENDING_REPAIR`; no silent rewrite is performed.

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

PR #206 source-witness run `31628102225` separately binds the closure decision to
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
