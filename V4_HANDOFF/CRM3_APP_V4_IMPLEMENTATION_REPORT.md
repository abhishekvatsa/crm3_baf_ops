# CRM3 App v4 — Whole-App Reconciliation Implementation Report

## 1. Mandate

v4 was built under one governing rule:

> Preserve the v3.3 server-authoritative workflow architecture. Preserve every legitimate operational capability of the original application. Where old and new authority conflict, migrate the original capability into the v3.3 model and retire or fence the conflicting legacy path.

v4 is therefore not a rollback, compatibility shim or isolated workflow patch. It is the first whole-application reconciliation candidate.

## 2. Scope and delta

- Baseline commit: `deba971729d2787834b818b6585b82285639d463`
- Changed/new files: **91**
- Source additions: **11,024 lines**
- Source deletions: **868 lines**
- No repository, deployment or production mutation was performed.

## 3. Stage results

### Stage 1 — Canonical topology policy

A generated discipline-to-lane model now gives every module an accountable lane:

- Electrical → ELEC
- Mechanical → MECH
- Instrumentation → I&A
- Operations / Shift-in-Charge → OPRN
- EMD → EMD
- Refractory → RED
- Safety / Administration / Shared / legacy Others → SHARED

SHARED is a coordination lane. It does not grant blanket module-edit authority; discipline-specific work and submit roles remain generated from policy.

### Stage 2 — One canonical closure authority

Workflow closure now absorbs the original app's strongest guarantees:

- canonical remote module reread;
- required-module readiness;
- submitted-but-unaccepted rejection;
- evidence completeness;
- closure attestation and hash;
- standard audit record;
- correlated workflow aggregate identity.

The original closure callable is fenced from workflow-schema jobs. Module reopen atomically reactivates its lane. Finalization retry returns the canonical completed result without duplicate terminal effects.

### Stage 3 — Topology and lifecycle projection

- Lane classification derives mandatory lanes from actual modules.
- Module lane identities are repaired transactionally during classification.
- Dependent modules cannot be stranded by lane removal.
- Same-lane generation replacement remaps dependent modules atomically.
- Cancellation projects across execution, lanes, compliance, maintenance, modules, equipment, event and audit.
- Original asset timeline and fleet reporting consume canonical equipment projection.

### Stage 4 — Compliance and maintenance integration

- Every continuation command verifies that compliance belongs to the commanded workflow.
- Completed/cancelled workflows reject further compliance mutation.
- Stored lane, module and maintenance references are revalidated before use.
- Deferred conditions require a real maintenance ticket and condition reference.
- Maintenance model, serializers, pull paths, UI and Rules preserve workflow-owned fields.
- Legacy ticket close/reopen/edit/delete is blocked while workflow-deferred.

### Stage 5 — Operational resilience

- Escalation is paged and each candidate is transactionally re-read before mutation.
- Terminal Tier 3 work exits later sweep queries.
- Deterministic escalation events drive notification delivery.
- Pull failures are isolated and quarantined per document.
- Watermark advancement handles timestamped quarantine safely and holds on unknown timestamp.
- Quarantine is capped and visible to Admin/SI together with unresolved uncertain commands.
- Workflow timeline exposes correlated original execution audits.
- App Check enforcement is an explicit deploy-time choice rather than an accidental permanent default.

### Stage 6 — Persistence and release authority

The package did not contain authentic generated bindings for nine workflow records, and four existing generated schemas were stale. The pinned Flutter/Dart/Isar toolchain was unavailable locally and could not be retrieved.

v4 therefore provides:

- an explicit Isar schema version 3 and reviewed fingerprint;
- deterministic provisional bindings for source completeness;
- additive reconciliation of existing generated schemas;
- a structural source verifier;
- exact pinned-codegen runners for Windows and Unix;
- a production release guard that refuses any provisional marker.

This is intentionally fail-closed. Source completeness is not misrepresented as release authority.

## 4. Validation

### Active tree

- v4 whole-app audit: **21/21 PASS**
- inherited v3.2 audit: **18/18 PASS**
- inherited v3.3 audit: **15/15 PASS**
- Dart structural audit: **PASS across 367 files**
- Isar source verifier: **PASS**
- Isar release verifier: **EXPECTED FAIL-CLOSED**
- policy generation: **byte-stable**
- TypeScript strict compile: **PASS**
- Functions tests: **207 passed / 29 emulator-dependent skipped**

### Independent reconstruction

The exact patch was applied to an untouched detached baseline. All 91 changed/new files were byte-identical and the same audits/tests repeated successfully.

## 5. What v4 does not claim

v4 does not claim:

- authentic Isar code generation;
- Dart/Flutter compilation;
- Flutter test execution;
- Firestore emulator Rules or contention proof;
- Android/Kotlin build proof;
- device or weak-network proof;
- repository integration;
- backend deployment;
- production or pilot readiness.

The residual gate ledger is part of this handoff and is release-blocking.

## 6. Verdict

v4 resolves the principal whole-app contradictions identified in the v3.3 audit while preserving the v3.3 architecture. At source level it establishes one authority model for closure, modules, lanes, cancellation, compliance, maintenance, equipment, audit, escalation and synchronization diagnostics.

The highest remaining risk is now correctly concentrated in authentic persistence generation and runtime proof—not knowingly conflicting business authorities.
