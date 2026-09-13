# A-03 Persistence Boundary Remediation

Status: CLOSED

Programme adjudication: `FINDING:A-03` is closed as of 17 August 2026 by
`PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE`.

## Exact Inventory

`tools/v4/a03_persistence_boundary_inventory.dart` parses every non-generated
Dart library under `lib/` with the analyzer AST. It discovers Firestore and
Isar handles, groups concrete persistence sites by owning operation, and
classifies each operation by store and read, mutation, or lifecycle mode.

The source-implemented inventory contains 484 operations and 1,548 concrete
sites across 44 files. Its stable digest is
`7923E15F9D3DBCD24C84FEBFD053A9056843E64D0BDDA2A484CDFBD826E3B92A`.

Post-closure re-arms on 20-21 August 2026 classified the read-only
`asset_availability_current`, furnace stuck-up/condition, frequent-issue,
maintenance-intelligence, and inspection-programme surfaces under existing
read/repository profiles. A subsequent review correction added the exact remote
maintenance-lifecycle replay readback under the existing repository surface.
This P1 correction also adds atomic local adoption of that verified receipt so
the rebased server version is stored before the row is marked synchronized.
A further cross-business alignment pass adds exact lost-response convergence,
server-timestamp receipt adoption for knowledge rows, and an explicit
ordinary-user server recheck for held records that neither changes nor deletes
source evidence. A late review correction now retains that hold through failed
or uncertain rechecks and resolves it only after authoritative remote
acceptance or exact readback for the same record. The 23 August
reporting-completeness correction also classifies one additional read-only
quality-monitoring query and binds its focused regression. The issue multi-lane
workflow re-arm classifies its additional local reconciliation sites under the
existing maintenance repository boundary. Strict server-readback adoption for
planned executions, runtime modules and charge abnormalities adds two further
compare-and-apply operations under their existing repository adapters. The
event-link authority correction makes three read streams auto-dispose when
their last authorized listener leaves and keys every live cache to the approved
actor UID, including direct approved-account switches; operation and surface
counts do not change, while explicit metadata-aware subscriptions add
three scanned sites and constructor lifecycle plus session scope remain part of
the exact digest. The burner-round report adds one metadata-aware read operation
under its already classified provider surface. Cache-origin snapshots are
admitted only after the same
continuous approved actor and exact query have received server confirmation;
loading, error, revocation, sign-out, or UID change clears that in-memory
trust, while a confirmed same-actor query remains usable offline. The current
actor-scoped compliance lookup now obtains each record through a server-only
point read and permits offline fallback only from an exact record proved during
the same continuous approved-actor session. The cross-device workflow-freshness
correction adds bounded active workflow, lane, and compliance listeners under
the existing live-sync service surface; server-confirmed stale-projection
reconciliation preserves unsynchronized local work and introduces no
presentation-owned persistence. Immediate cross-business synchronization now
classifies pending-write observation, bounded strict remote mirrors, and
account-owned local recovery under three explicit service surfaces. The
recovery service also owns exact, Admin-receipted local tombstone removal;
presentation still owns no persistence. Exact-device administrator recovery adds
one separately classified, regression-covered service that backs up and clears
only the authorized installation's local store before its fresh synchronization;
the administrator screen never owns database access. The manifest refresh
also classifies the critical-alarm repository and provider as remote-read-only
surfaces. Alarm lifecycle commands remain online-only callable operations and
alarm state is deliberately never persisted to Isar; the unbounded active feed
is separate from the bounded recent-history feed so historical volume cannot
displace an active emergency. It preserves every previously registered feature
regression instead of replacing named coverage with a generic test. The
server-governed seven-day retention for closed quality-monitoring requests now
uses one active/recent read stream, removing the former client-clock and bounded
recent-window reads. Complete quality and critical-alarm report feeds retain full history,
bind reads to the current approved actor, and admit offline cache only after the
same query has been server-confirmed in that actor session. The Build 19 device
convergence re-arm adds one server-first maintenance deletion readback operation
and two persistence sites under the existing maintenance remote adapter. The
pilot-data cleanup successor adds exact purge-manifest reads and clean local
tombstone reconciliation under the existing recovery service boundary. The
manifest at that re-arm covered 556 operations and 1,923 sites across 57
surfaces with digest
`E9CC50F967763C2E554BF5BFC83CE07062B7C07ADDC10AE2B0C665F3471CFA6F`;
the original closure evidence remains preserved as historical source and CI
proof.

The 1 September 2026 Morning Review and issue-sync diagnostics re-arm adds the
Morning Review read repository and read-only provider boundaries. The purge
reconciliation follow-up broadens the existing recovery read to synchronized
active copies and adds an evidence-preserving local quarantine write. The
current manifest covers 565 operations and 1,940 sites across 60 surfaces with
digest `8EEF2E38B103F506BBD98BA1EA0F3308065AF5B849D01437B532D98726F39BEA`.
The governed policy is `governance/a03-persistence-boundaries-v1.json`.

## Predictive Audit Re-arm, 2026-09-06

The current governed successor contains 556 operations across 1,923
persistence sites and 61 classified surfaces. Its measured inventory digest is
`7E0E44484E55893F50DC62D1C61A36C6F444729FD847D7B0EDFD71A77773007B`.
The lower operation and site counts are the reviewed result of replacing broad
workflow collection reads and deferred in-memory filtering with scoped Isar
queries, and of consolidating identity-based remote application inside local
transactions. The additional surface is the separated authentication service;
it owns profile mutations while provider wiring remains read-only. Historical
closure counts and receipts above remain unchanged and continue to describe
their original source snapshots. The six additional read sites belong to the
inspection repository's bounded two-pass server read used to construct one
stable audit-dossier snapshot.

The audit fails when the operation digest changes, a persistence-owning file is
unclassified, declared stores or access modes drift, presentation or widget
code gains direct persistence, a mutation is not repository/service owned, a
cross-source path is not repository/service owned, a diagnostic adapter becomes
mutating, or named regression coverage is absent.

## Removed Presentation Access

Five user-facing boundaries were corrected:

- user roster Firestore streaming is owned by `UserDirectoryRepository`, with
  Admin authorization enforced by `UserDirectoryReadService` before the read;
- closed-ticket pagination is owned by `MaintenanceRepository` and
  `ClosedTicketHistoryService`; the Firestore cursor is returned by the same
  page query and is opaque to the screen;
- published-template correction harvesting is owned by
  `KnowledgeCorrectionSourceRepository`, with Admin/SI authorization before
  the remote query;
- sync-rejection reads and local resolution transactions are owned by
  `SyncRejectionService`, which rejects unauthorized mutation before looking up
  the local database;
- Local Diagnostics performs its Admin/SI check before invoking the registered
  `LocalDiagnosticsReadAdapter`; that adapter is privacy-safe, Isar-only, and
  read-only.

No file under a presentation or widget directory now owns direct Firestore or
Isar access.

## Behavioral Preservation

The extracted boundaries retain the existing loading, error, web/offline,
refresh, paging, and denial states. Focused tests prove authorization precedes
the user roster, closed-history, template-correction, and sync-rejection store
access. The diagnostics adapter retains provenance and collection-count output
without acquiring sync, reset, delete, or clean-state behavior.

The A-02 inventory was updated because its three explicit A-03 carryover
hotspots ceased to be mixed-responsibility hotspots after this extraction.
A-02 remains closed and its current machine inventory passes.

## Boundary

PR #234 exact green head `af14218f5281cb210bda5382fbedc5eaa2ca27e8`
merged as `829c87ee07de43846f1d6b5e6d0b1879a3801d93` with identical
tree `0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff`. Exact-head run
`32042648071` and admitted-main run `32043979797` passed all five governed
jobs. The closure is sealed in
`release/evidence/a03-persistence-boundary-source-and-ci-closure.json`.

This closure changes source architecture and evidence only. It performs no
Firebase deployment, production data read or mutation, local data migration,
device validation, distribution action, pilot authorization, or cutover
authorization. Its three ledger re-arm triggers remain binding.

## Pilot Successor Inventory, 2026-09-04

The reviewed successor contains 564 operations across 1,942 persistence sites
and 60 classified surfaces. Its measured inventory digest is
`218B42299EF3F68BE69E5CF9D81B7902CAFEA763A51B80A5A478ED4EF087399C`.
The governed directive acknowledgement now uses field-only transactional writes
instead of the prior batch paths, preserving server-owned timestamps. The
inventory remains exact; no presentation persistence exception was added.
Earlier counts and CI receipts above describe their historical source, not
deployment or release authority for this successor.

## Post-Incident Remediation Re-arm, 2026-09-10

The current governed successor contains 560 operations across 1,946
persistence sites and 61 classified surfaces. Its measured inventory digest is
`308E195FA19CB26ECE40187B18533A3202F2E311FE9C264E06DF8853A73EC75B`.

Four operations were added by the 2026-09-09 sync-incident remediation. Two
belong to the local diagnostics read adapter, which now counts the workflow
command journal: that journal carries no `isSynced` flag, so unfinished
lifecycle commands previously sat behind a reassuring zero dirty-row total and
were invisible to support during the incident. Two belong to the Isar workflow
repository, which now claims a retained command inside the same write
transaction that selects it, so a second execution context cannot replay a
command that is already being sent.

No re-arm trigger fired. No direct Firestore or Isar access was introduced into
presentation code; the recovery package moved to a service for that reason, and
the presentation persistence count remains zero. Both new provider paths are
classified in the governed inventory, inside surfaces that already declare
their stores and modes: the diagnostics adapter remains `isar` read-only under
the registered `diagnostic-read-adapter` profile, and the workflow repository
remains `isar` read and mutating under the `repository` profile. No registered
diagnostic exception became mutating or lost authority-first admission. The
surface count is unchanged because no new surface was introduced.

The frozen source-implemented closure receipt of 484 operations and 1,548 sites
stands unaltered. This entry records classified growth inside already-closed
boundaries; it is not a new closure, and it carries no deployment or release
authority.

## Successor Review Correction Re-arm, 2026-09-10

The current governed successor contains 561 operations across 1,949
persistence sites and 61 classified surfaces. Its measured inventory digest is
`44B79AC49CA95EEB4A65771AFE9CFDFDF041E925BC4F197404DBADF352A99B7E`.

One operation was added: the Isar workflow repository can now read a stored
command receipt. A receipt is authoritative evidence that the server accepted a
command, and the executor consults it before recording a failure. Without that
check, an attempt whose claim had expired could return late with a transport
error and recreate an uncertain-outcome row for work another caller had already
settled, so an accepted command would reappear as unresolved and invite replay.

No re-arm trigger fired. The operation is a classified read inside the existing
`repository` surface, which already declares `isar` with read and mutating
modes. No direct Firestore or Isar access entered presentation code and the
presentation persistence count remains zero. No registered diagnostic exception
became mutating or lost authority-first admission. The surface count is
unchanged at 61.

The frozen source-implemented closure receipt of 484 operations and 1,548 sites
stands unaltered. This entry records classified growth inside already-closed
boundaries; it is not a new closure and carries no deployment or release
authority.

## Atomic Retry Transition Re-arm, 2026-09-10

The current governed successor contains 563 operations across 1,966
persistence sites and 61 classified surfaces. Its measured inventory digest is
`4CEF70398C0559DF2913B29D945A130349BCA5F707355C75F922A47140BDDE8D`.

Two operations were added to the Isar workflow repository. Acceptance and its
retry state now settle in one transaction, so a command is never both accepted
and outstanding. A retry transition now reads the receipt, reads the current
row and writes inside that same transaction, because reading the receipt first
and writing afterwards left the interleaving it was meant to prevent: the read
finds nothing, another caller commits acceptance and clears the row, and the
late write recreates uncertainty for work already applied.

No re-arm trigger fired. Both are classified inside the existing `repository`
surface, which already declares `isar` with read and mutating modes. No direct
Firestore or Isar access entered presentation code and the presentation
persistence count remains zero. No registered diagnostic exception became
mutating or lost authority-first admission. The surface count is unchanged at
61.

The frozen source-implemented closure receipt of 484 operations and 1,548 sites
stands unaltered. This entry records classified growth inside already-closed
boundaries; it is not a new closure and carries no deployment or release
authority.

## Recovery Boundary Re-arm, 2026-09-10

The current governed successor contains 563 operations across 1,967
persistence sites and 61 classified surfaces. Its measured inventory digest is
`FF3CFDE311F9F1F66F35154AAF878D94DA5A71FE1562542DCEB1EE8A1CED1EC5`.

No operation was added. One site was: the retry claim now excludes commands a
run has already handled, because a released command keeps its due time and the
oldest one was otherwise handed back immediately, leaving every command behind
it unattempted.

No re-arm trigger fired. The change is inside the existing `repository`
surface, which already declares `isar` with read and mutating modes.
Presentation persistence remains zero and the surface count is unchanged at 61.
The frozen source-implemented closure receipt of 484 operations and 1,548 sites
stands unaltered.

## Outcome Inventory Re-arm, 2026-09-10

The current governed successor contains 564 operations across 1,970
persistence sites and 61 classified surfaces. Its measured inventory digest is
`618CE2AC84FA29BB2B4644AFFF115EE7F0302610979667B09550687B4E1E25E7`.

One classified read was added: the workflow repository can now report the
command journal by outcome. The existing pending-command query excludes
rejected rows because they are not retryable, which is correct for claiming
and wrong for deciding what a person must still deal with; reusing it let an
operator-facing rejection warning clear on the next quiet run while the
rejected row was still stored.

No re-arm trigger fired. It is an `isar` read inside the existing `repository`
surface, which already declares read and mutating modes. Presentation
persistence remains zero and the surface count is unchanged at 61. The frozen
source-implemented closure receipt of 484 operations and 1,548 sites stands
unaltered.

## Exact subject-read inventory review, 2026-09-12

The current reviewed working tree contains 566 operations across 1,973
persistence sites and the same 61 classified surfaces. Its measured digest is
`D5E75992F5E0C8F37510BCF7F864C3FED1110749F271D94A4CD2C3F7980C12A1`.

The two additional operations are repository reads. The asset hierarchy
repository reads one exact Inner Cover from the server, rejecting missing,
cached, pending-write, wrong-identity or insufficient-version observations.
The maintenance-intelligence repository reads one exact plan from the server
after explicit subject revalidation and strictly decodes it before the caller
checks the confirmed identity and revision. These add one `get()` site and
one `collection()` plus `get()` pair respectively. Both remain inside existing
Firestore/read repository declarations. Rules still require an approved user
for reads and deny direct client writes to both collections.

No database access moved into presentation and no new transaction owner was
admitted. The existing sync service now blocks eligibility when its local hold
collection cannot be read; that changes an existing operation's failure outcome,
not the number of database sites. Its regression proves a persisted contradiction
hold survives reopening and a missing hold collection does not authorize a send.
The historical closure evidence and CI receipts remain unaltered; this review
does not claim a new admitted CI run, deployment or device result.

## 12 September 2026 source re-arm

The current reviewed source inventory contains 585 operations and 2,036 sites
across 66 surfaces. Its digest is
`8F1D606CA2F9D7E1D30C1C13087D02645FA8D4E929D0AB7348582472D79B2510`.
The five added boundaries are the native submission repository and its provider,
the server-only campaign creation reader, atomic published-assignment adoption,
and the server-only quality monitoring reader. Each has the common persistence
contract and relevant recovery regressions. The additions preserve the existing
repository/read-provider profiles; presentation code gains no database writes.
This is current source review and local inventory evidence. The historical CI
closure above is preserved and does not certify this uncommitted change.

## Deep-audit source re-arm, 2026-09-13

The current source inventory passes with 593 operations and 2,073 sites across
68 classified surfaces. Its measured digest is
`71E5D054C25F0657CAACACDD28D740EC0E9040F12EC9D35CAB7BCA9DDEF6B763`.
Compared with the preceding 585-operation inventory, the eight additional
operations and 37 additional sites have explicit purposes:

- The native submission repository adds an authority-gated administrative read
  and an atomic review settlement, with four sites between them. Existing
  acceptance settlement adds one write site to preserve late acceptance and
  review conflict evidence. Reviewed rows retain their original command/source
  bytes and do not invent a legacy actor.
- The inspection repository adds one server-read helper with two sites. It
  rejects cached, pending-write, absent or contradictory physical target
  evidence. The command repeats the subject checks transactionally; this local
  read does not authorize a mutation by itself.
- The native module conflict part owns six operations and 35 sites. These
  replace the former five-site native save operation and add complete preimage
  comparison, current parent checks, actor-scoped retained-draft discovery and
  review, and atomic audit evidence. A refused save is surfaced as a conflict;
  it is not a successful module mutation. Explicit reapplication compares the
  freshly reviewed current row again before writing.

The two new surfaces use the existing repository and repository-adapter
profiles. The former admits Firestore reads only; the latter admits Isar reads
and mutations. No file under a presentation or widget directory acquired a
persistence primitive. Named regressions include the native saved-submission
review suite, the native module conflict/restart suite, its recovery UI suite
and the inspection target-context suite. The digest excludes line numbers, so
it reflects operation identities and persistence sites rather than formatting.

This is classified current-source growth and a passing local inventory. It
does not replace the historical 484-operation closure, assert an admitted CI
run for this working tree, or authorize deployment, device testing or release.

## Prebuild repair inventory addendum, 2026-09-13

This addendum supersedes the earlier current-source totals above. The reviewed
prebuild repair inventory contains 594 operations and 2,076 sites across 70
classified surfaces, with exact digest
`D23545897AC627ECB6F3D8A7DC3CC615519D833D77BB80234E8A5FB4A82B8D96`.
The additional surfaces separate native workflow-module adoption from its
server-only read provider. Native adoption preserves the server revision and
requires the unchanged clean local preimage and current moderation authority;
the provider introduces no presentation-owned persistence. The native saved-work
repository also retains reviewed acceptance and preserves later admitted owners
without granting a second dispatch. Its original actor and receipt checks remain.

The AST inventory reports PASS with zero unclassified operations or presentation
persistence. These are current working-source measurements. The earlier source,
CI, and closure evidence remains historical and does not admit this repair branch
or provide deployment, production reconciliation, or physical-device evidence.
