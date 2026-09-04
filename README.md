# CRM-III BAF Ops

CRM-III BAF Ops is an offline-aware Flutter/Firebase application for Batch
Annealing Facility operations, corrective maintenance, planned work, governed
workflows, asset condition, quality assurance and operational reporting.

## Current authority boundary

This repository contains two different kinds of authority that must not be
conflated:

- **Current source:** the latest admitted application, Rules, Functions,
  tests, governance and documentation on `main`.
- **Sealed pilot artifact:** the exact signed Build 11 package, source,
  certificate, backend and roster evidence recorded by the release policy and
  programme ledger.

Build 24 (`1.0.0-rc.14+24`) is source-authorized for governed construction from
the admitted PR 346 baseline `5e5e9d6`, whose exact post-merge CI passed.
All 15 production Functions match the unchanged PR 345 backend source
`a546e73` and passed strict readback with existing IAM preserved. The existing
Firestore Rules and 66 indexes remain unchanged and verified. The owner-approved
staged rollout retains older-phone compatibility; the known legacy direct-write
nested-asset validation gap remains deferred, not resolved.

Build 23 remains production-signed, independently verified, dual-custodied and
finalized non-distributable; its evidence is immutable. Build 24 has not yet been
constructed. Its source approval includes the admitted release-contract
correction; construction still requires exact merged source and clean CI.
No consumed build number may be reused. Exact-package device
acceptance and pilot promotion remain separate decisions after construction.

Authoritative status sources:

- `governance/programme-ledger.json`
- `governance/successor-engineering-rearm-2026-08-16.json`
- `release/current-successor-state.json`
- `release/production-release-policy.json`
- `release/backend-current-state.prod.json` (historic deployed-state capture)
- `docs/v4_2/PROGRAMME_AUTHORITY.md`

The sealed Build 11 decision remains exact to that artifact and roster. A
separate source-and-CI successor campaign was re-armed on 16 August 2026 for
audit remediation, remaining business capability and UI/UX redesign. Any new
artifact requires its own governed reservation, exact signed-device validation
and a separate pilot decision. Unrestricted
distribution remains prohibited, and App Check/Play Integrity activation
remains a governed decision.

## Product scope

The current source includes:

- approved-user and role-capability administration;
- corrective issues, acknowledgement, deferment, correction and closure;
- planned-job templates, published versions, executions, modules and dossiers;
- Mech, Elec, Oprn, RED, I&A and shared workflow coordination;
- operational directives and audit history;
- charge abnormalities, evidence and root-cause-analysis links;
- governed knowledge and template authoring;
- dynamic asset classes, hierarchy nodes, physical assets, installed
  components, ownership and tag resolution;
- plant condition and available/maintenance/down views;
- quality-warning lifecycle and monitoring requests;
- utility, crane, transfer-car and other operational disruptions; and
- asset-class, asset and date-filtered operational reports.

The dynamic asset hierarchy is a foundation, not yet the complete
asset-integrity programme. Strategy-derived obligations, technical-document
applicability, configuration baselines, frozen audit populations,
revision-controlled industrial procedures, graded evidence, spares, readiness
and cost remain separate planned work.

## Architecture

Key boundaries are:

- `lib/` - Flutter application and Isar-backed local custody
- `functions/src/` - Firebase Functions and authoritative mutations
- `functions/src/maintenanceWorkflow/` - maintenance-workflow command system
- `firestore.rules` - client data-plane authorization and validation
- `firestore.indexes.json` - Firestore index declaration
- `governance/` - programme and generated workflow-policy authority
- `release/` - sealed build, runtime and deployment evidence
- `tools/` - source, schema, release and canonical audits
- `test/` and `functions/test/` - Flutter, contract, Rules and Functions tests

Client visibility is not an authorization boundary. Sensitive mutations are
enforced by Firestore Rules or server-authoritative callables with transaction,
replay/idempotency and audit controls.

## Toolchain

The governed production policy pins the release toolchain. Its current core
versions include:

- Flutter `3.44.0`
- Dart `3.12.0`
- Isar `3.1.0+1`
- Java `21.0.11+10`
- Node `22.23.1`
- npm `10.9.8`
- Firebase Tools `15.22.4`

Do not substitute a different Flutter, Dart or Isar generator when producing
release-authoritative schema output.

## Firebase client configuration

The current tracked source includes:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

These are Firebase Android client configuration, not service-account or
signing private keys. Release tooling verifies the intended Firebase project,
Android package, app identity, OAuth certificate bindings and governed file
hashes. Never commit service-account credentials, keystores, `.p12` files,
passwords or signing-key properties.

See `docs/FIREBASE_CONFIGURATION_CUSTODY.md`.

## Isar persistence authority

The current local-store contract is Isar schema v7. Authentic checked-in
generated bindings contain zero `PROVISIONAL_V4_ISAR_CODEGEN` markers. Schema
v5 added governed asset identity to workflow and equipment projections; v6
added operational-event issue-link projections; v7 adds durable maintenance
ticket reopening evidence while retaining explicit v1, v3, v4, v5 and v6
fingerprints and ordered migration steps.

Before any release claim, run:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
python tools/isar/verify_v4_isar_schema.py --release
```

The release verifier must report schema v7, zero provisional bindings and
`release_authority=YES`. Existing-store adoption, migration, quarantine and
recovery evidence remain governed separately from successful code generation.

## Local validation

From the repository root:

```powershell
flutter analyze
flutter test
python tools/v4/whole_app_reconciliation_audit.py
python tools/expanded_audit/expanded_implementation_audit.py
python tools/maintenance_workflow/full_tree_source_audit.py
python tools/v4/dart_structural_audit.py
python tools/isar/verify_v4_isar_schema.py --release
python tools/v4/v4_2_r1_canonical_audit.py
```

Functions unit and emitted-output checks:

```powershell
Set-Location functions
npm ci
npm test
```

Governed Rules and Functions emulator suite:

```powershell
Set-Location functions
npm run emulator:test:governed
```

The scripts print their own exact counts. Do not preserve test totals in a
readiness claim after the source or suite has changed; bind evidence to the
exact commit and run instead.

## Build and deployment safety

Local analysis, tests and debug builds do not grant deployment authority.
Before a successor pilot artifact or backend change:

1. reserve a new build number under the release policy;
2. bind exact source, tree, dependencies, Firebase files and signing identity;
3. run clean code generation, analysis, tests and Android packaging;
4. prove upgrade/migration without clearing supported user data;
5. verify backend and Rules compatibility and perform governed deployment only
   when the relevant checks permit it;
6. exercise the required role, denial, sync, offline/reconnect and revocation
   matrix on the exact artifact; and
7. record finalization, custody and readback without rewriting prior build
   history.

Do not deploy Firebase, modify production data, change IAM or distribute an APK
from an ordinary development command.

## Historical material

The repository intentionally retains historical reconstruction, R1 hardening,
build rollover, device-validation and closure documents. They preserve why a
control exists and the exact evidence that supported an earlier transition.
They are not substitutes for the current programme ledger, release policy or
canonical audit.

Useful starting points:

- `V4_HANDOFF/`
- `docs/v4/`
- `docs/v4_2/`
- `docs/v4_2_r1/`
- `docs/70I_B*.md`
- `docs/DART_IMPORT_CYCLE_CLOSURE.md`

## Safety boundary

The application supports operational and maintenance assurance; it is not a
plant control system. Safety interlocks, trips, permits, isolations, operating
procedures and competent-person decisions remain authoritative outside the app.
Where required authority, target identity, procedure revision or evidence
cannot be established, consequential transitions must fail closed.
