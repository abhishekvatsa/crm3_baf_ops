# ND-1 / ND-2 Architecture Decision — Ultimate Comprehensive Final Population Fence v3.3.3

**Baseline authority:** `main @ 5cf140656b07edd49ad182a6be9ce70cd8858e69`
**Baseline tree:** `e477ed5bb3f638d046b40a26464d1d9518202fdb`
**Accepted red-state proof:** `CRM_III_BAF_Ops_O08_O09_Tailored_PreFix_Proof_20260624_213242.zip`
**Proof SHA-256:** `CA722DD7FEB2319F1782D67EB0F45BEF591CFDF9DA6D1C9BC4484500EBD7F65F`
**Scope:** O-08 source remediation and O-09 real-emulator/ordinary-CI promotion.
**Final reconciliation authority:** Ultimate Comprehensive Final v3.3.3. The ND-0 evidence SHA-256 is corrected and bound at its full 64 hexadecimal characters in source, runner and package authority. The execution-green v3 runtime/Functions implementation is retained unchanged; the working Comprehensive v3.2 orchestrator is retained; bidirectional workflow/registry parity, duplicate-registry rejection, exact intermediate/final tree authorities, build-number custody, parser-first preflight, current donor custody and captured packaging evidence are additive controls.
**Excluded:** dependency upgrades, App Check enforcement, production artifact issuance, Firebase deployment, physical-device proof, operator acceptance, Isar schema change and broad refactoring.

## 1. Proven defect

The exact baseline permitted a closure-critical runtime module to be accepted after its parent execution was completed and permitted an orphan child whose parent did not exist. The defect is a missing parent–child population invariant, not merely an uncertain query-phantom race.

A complete invariant must also govern population removal, protect the closure evidence from later child mutation and preserve every rejected offline record. A create-only fence would still allow completed-parent/child divergence.

## 2. Selected invariant

Every client-originated mutation that changes active population membership is accepted only when:

- the parent execution exists;
- the parent is not deleted;
- the parent is not completed;
- child mutation and parent population-revision advance occur in one Firestore transaction;
- an immutable deterministic server audit is written in the same transaction;
- exact retries are owner-bound, audit-bound and return immutable mutation evidence;
- the current parent population revision never regresses below that immutable mutation evidence;
- rejection never deletes local evidence or marks it synchronized.

Population-changing operations in this phase are:

- first remote creation of a runtime-added module; and
- soft deletion of an existing remote module.

Ordinary work and lifecycle updates remain field-scoped direct writes while the parent and child are active. They are denied when the parent is missing, deleted or completed, and denied when the child is already deleted. Parent identity, population-defining fields and server-governed mutation evidence are immutable through ordinary updates.

There is no ordinary restore/reactivation operation. Any later restore capability must be introduced as a separately reviewed server-governed population mutation that advances the same parent authority.

## 3. Dedicated population authority

The parent carries server-only:

```text
modulePopulationSchemaVersion = 1
modulePopulationVersion       = non-negative generation
```

The existing client-visible execution `version` is not reused. It already governs client freshness, optimistic concurrency, completion expectations, synchronization and retry. Mixing the two contracts would create unrelated stale-client conflicts.

Governed assignment establishes the initial frozen module population atomically and initializes population generation `1`. Legacy executions with both population fields absent are interpreted as generation `0`; partially present or malformed fields fail closed.

## 4. Server-governed mutation callable

`mutateRuntimeJobModulePopulation` runs in `asia-south1` and supports only:

```text
create | softDelete
```

The callable:

- authenticates and checks approved roles;
- validates the exact client field allow-list and bounded payload shape;
- requires `addedDuringExecution = true` for client-originated create;
- validates collapsed first-sync lifecycle provenance and timestamp order;
- treats actor UIDs as authoritative and binds ordinary actor claims to the uploader;
- permits moderator preservation of another actor's offline evidence only with an explicit preservation reason and dual-identity audit;
- does not silently infer historical authority: cross-actor first-sync records without an explicit moderator preservation decision remain dirty and quarantined;
- validates parent asset and charge identity;
- rejects missing, deleted or completed parent state;
- writes child mutation, parent revision and immutable `audit_logs` evidence atomically;
- reserves deterministic server audit identities and refuses pre-existing collisions;
- validates the matching immutable audit and stored mutation revision before accepting an idempotent replay;
- refuses a replay if the parent population revision has regressed below the immutable mutation revision;
- returns both immutable `acceptedAtPopulationVersion` and current `currentParentPopulationVersion`.

Published-template assignment remains a separate Admin-SDK transaction and cannot be impersonated through this runtime route.

## 5. Closure attestation evolution

The authoritative server closure attestation advances to schema `2` and binds:

```text
modulePopulationVersionAtCompletion
modulePopulationSchemaVersionAtCompletion = 1
```

The local/client preview remains schema `1` because it does not possess authoritative remote population state. Schema `1` is not silently redefined.

Closure fails closed when population metadata is partially present or malformed. It reads and updates the same parent document written by population mutation, forcing Firestore transaction retry under concurrency. If mutation wins, closure re-reads the changed population. If closure wins, later mutation re-reads a completed parent and is rejected.

## 6. Offline and no-loss behaviour

Native authoring remains local-first:

```text
local Isar create/tombstone
→ dirty record
→ server-governed remote mutation
→ mark synchronized only after verified success
```

A durable server rejection:

- does not enter `snapshotsToMark`;
- remains dirty in Isar;
- persists a `SyncRejection` before the sync pass returns;
- is held from automatic repeated retries when classified permanent;
- remains operator-visible and repairable;
- never requires destructive app-data clearing.

A locally created module deleted before ever reaching Firestore is a safe remote no-op. An existing remote module tombstone uses the governed soft-delete transaction.

Lost callable responses are handled explicitly. If the existing remote client-owned snapshot is exactly equivalent, first acceptance is treated as already satisfied rather than issuing a stale same-version direct update. For tombstones, exact equivalence is treated as replay; a divergent authoritative remote tombstone is conflict-audited and reconciled without falsely marking fresher local deletion evidence synchronized.

Cross-actor collapsed offline history is deliberately not auto-promoted by ordinary sync. Until a dedicated moderator-preservation UI is delivered and proven, such records remain dirty/quarantined for controlled review; callable capability alone is not claimed as an operator-complete workflow.

## 7. Firestore rules boundary

The prepared rules:

- deny every direct client module create;
- deny every direct client soft delete;
- require an existing, non-deleted, incomplete parent for every other module update;
- require the existing and proposed child to remain active for ordinary updates;
- freeze parent identity, population-defining fields and server population evidence;
- preserve field-scoped lifecycle role checks;
- reserve `server_module_population_*` audit identities for Admin-SDK transactions;
- preserve Admin-SDK governed assignment.

These restrictive rules are **source-prepared only**. They must not be deployed before the callable is live and a compatible signed client has completed controlled cutover.

## 8. Required proof matrix

The governed suite covers:

- create wins versus closure;
- closure wins versus create;
- soft delete wins versus closure;
- closure wins versus soft delete;
- orphan/deleted/completed parent rejection;
- direct create denial for every client role;
- direct soft-delete denial;
- ordinary update/reopen/submit/accept/not-applicable denial after completion;
- ordinary mutation of a deleted child denied;
- parent identity and server population evidence immutable;
- parent asset/charge mismatch;
- actor spoof rejection and moderator-preservation audit;
- first-sync lifecycle validation;
- exact replay semantics and immutable audit custody;
- parent population-revision regression rejection;
- lost callable response equivalence;
- divergent remote tombstone reconciliation;
- injected transaction failure with no child/parent/audit residue;
- governed assignment atomicity, idempotency and no-mutation rejection;
- assignment compatibility after direct client create is denied;
- executed Isar rejection preservation and awaited `SyncRejection` persistence;
- callable-adapter auth/error translation.

## 9. Deployment and cutover boundary

This source campaign performs no deployment.

Controlled future order:

1. merge verified source after remote clean-install CI;
2. run a read-only production-data preflight over active module/execution links and reconcile, before enforcement, every module with a missing `jobExecutionFirestoreId`, missing parent, deleted/completed-parent inconsistency, malformed population metadata or asset/charge mismatch;
3. deploy callable and closure changes without restrictive rule activation;
4. retain backward compatibility while the compatible client is issued later, after the remaining non-device source campaigns;
5. exercise queued dirty records, lost callable responses, offline creation, weak network and durable rejection on representative devices under O-10/70J;
6. control or retire old direct-create-only clients;
7. deploy restrictive rules;
8. perform production readback, rejection review and post-cutover reconciliation.

Until those steps pass, O-08 status is:

> **SOURCE REMEDIATION VERIFIED — DEPLOYED ENFORCEMENT AND CLIENT CUTOVER OPEN**

## 10. CI and evidence custody

The ordinary PR/main gate uses the repository-governed Firebase CLI, immutable action SHAs and verified Isar native-core custody. Local validation reuses the exact lockfile-governed installed dependency graph and is therefore workstation-custodied, not fully hermetic. Remote clean-install CI remains a separate required confirmation.

The apply runner validates in a disposable detached worktree, creates the exact validated commits there and moves the local feature branch to those same commits only after every gate passes. It verifies the ND-0 and pre-fix archives, patch hashes, build-tag absence, dependency custody, native-core custody, changed-file allowlist, lockfile/generated-source non-drift, full release gate, final tree and diff identity.

No push, pull request, deployment, tag, production workflow or build-number action is permitted by the runner.
