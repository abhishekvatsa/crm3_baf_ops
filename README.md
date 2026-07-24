# CRM-III BAF Ops — v4.2 Ultimate Successor Trial Candidate

CRM-III BAF Ops is an offline-aware Flutter/Firebase application for CRM-III maintenance, planned-job execution, equipment status, directives, abnormalities, audit and governed maintenance workflow.

This tree is the **v4.2 ultimate successor local-trial candidate**. It preserves the v3.3 server-authoritative workflow architecture and absorbs the original application's valid closure, evidence, audit, maintenance and equipment guarantees into one authority model.

It is **not an authorised production replacement** and must not be merged, deployed or distributed directly from this archive.

## Architectural authority

The v4 control plane is authoritative for workflow-schema jobs:

- command gateway with receipt-first idempotency;
- optimistic aggregate-version concurrency;
- generated Dart/TypeScript/Rules policy;
- discipline lanes, including first-class EMD and Refractory plus governed SHARED coordination;
- compliance, counter-condition and maintenance-ticket deferral;
- RED preparation and equipment projection;
- canonical closure with module/evidence attestation;
- cancellation projection across workflow and original records;
- escalation, notification, quarantine and operational diagnostics.

The original app remains the source of legitimate operational capabilities that must not be lost. Conflicting legacy authority paths are fenced or routed into the v4 authority rather than preserved as equal competing systems.

See:

- `V4_HANDOFF/CRM3_APP_V4_IMPLEMENTATION_REPORT.md`
- `V4_HANDOFF/CRM3_APP_V4_AUTHORITY_MIGRATION_MATRIX.md`
- `V4_HANDOFF/CRM3_APP_V4_RESIDUAL_RUNTIME_GATES.md`
- `docs/V4_1_DUE_DILIGENCE_ADJUDICATION.md`
- `docs/v4_2/PROGRAMME_AUTHORITY.md`
- `docs/v4_2/TOMORROW_LOCAL_TRIAL_RUNBOOK.md`

## Source layout

- `lib/` — Flutter application, local Isar persistence, synchronization and UI.
- `functions/src/maintenanceWorkflow/` — authoritative workflow command system.
- `firestore.rules` — fail-closed client/data-plane rules and workflow policy helpers.
- `firestore.indexes.json` — production index declaration.
- `governance/maintenance_workflow_policy_v1.json` — single policy source.
- `tools/maintenance_workflow/` — policy generation and full-tree source audits.
- `tools/v4/` — whole-app and Dart structural audits.
- `tools/isar/` — provisional schema generation/verification and release refusal.
- `release/` and `tools/release/` — governed production-artifact policy and checks.

## Pinned toolchain

The governed production policy pins:

- Flutter `3.44.0`
- Dart `3.12.0`
- Isar `3.1.0+1`
- Java `21.0.11+10`
- Node `22.15.0`
- npm `10.9.2`
- Firebase Tools `15.22.4`

Do not substitute another Flutter/Dart/Isar generator when approving schema output.

## Required local configuration

The source/evidence handoff deliberately excludes environment-bound Firebase outputs:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

Before any Flutter build, restore the governed files associated with:

- Firebase project: `crm3-baf-ops-b8638`
- Android package: `in.co.sail.bsl.crm3.bafops`
- Android Firebase app ID: `1:894346496105:android:fba14febfbbee102e63af8`

`google-services.json` must match the SHA-256 recorded in `release/production-release-policy.json`. The release scripts fail if package, Firebase app, OAuth certificate or file hash differs. See `docs/FIREBASE_CONFIGURATION_CUSTODY.md`.

## Isar generation boundary

Thirteen checked-in bindings carry `PROVISIONAL_V4_ISAR_CODEGEN`. They make the persistence contract inspectable but are **not authentic pinned `build_runner` output**.

Before build/release authority:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
python tools/isar/verify_v4_isar_schema.py
python tools/isar/verify_v4_isar_schema.py --release
```

The release verifier must pass with zero provisional markers, and generated schema IDs must be reviewed against an authentic current-app database.

## Source-level validation

From the repository root:

```powershell
python tools/v4/whole_app_reconciliation_audit.py
python tools/maintenance_workflow/full_tree_source_audit.py
python tools/expanded_audit/expanded_implementation_audit.py
python tools/isar/verify_v4_isar_schema.py
python tools/v4/dart_structural_audit.py
node tools/maintenance_workflow/generate_policy.mjs
```

Functions:

```powershell
Set-Location functions
npm ci
npm test
```

The v4.2 hardening candidate records 224 executable Functions tests passing and 29 emulator-dependent tests skipped in the available environment. The root, Functions and governed Firebase CLI npm trees each audit at zero known vulnerabilities at packaging time.

## Runtime validation still required

Static success is not replacement authority. The following gates remain mandatory:

1. Reconcile v4.2 against the exact governed repository authority and classify every unique delta. The user-supplied pre-v4 snapshot is already embedded as no-loss and Isar-continuity evidence.
2. Restore and verify governed Firebase configuration.
3. Run authentic Isar generation and a real current-database migration laboratory.
4. Run `flutter analyze` and the full Flutter test suite, including mapper/widget/provider tests.
5. Build Android debug and unsigned release artifacts and inspect package/Firebase identity.
6. Run Firestore Rules and Functions emulator suites, transaction contention and scheduler due-time tests.
7. Run upgrade, weak-network, multi-device, notification, recovery and rollback tests.
8. Complete signing, App Check and controlled-pilot governance; re-run dependency audits on the exact build lockfiles.

## Baseline evidence note

`docs/expanded_audit/CANDIDATE_MANIFEST.json` is retained **historical v3.3 evidence** and therefore names the earlier `c719b63…` baseline. The v4 reconstruction handoff names `deba971729d2787834b818b6585b82285639d463` as its immediate v3.3 baseline. Neither value establishes ancestry to a later live `main`; that is a separate governed repository-reconciliation gate.

## Safety classification

- Successor architecture: **GO**
- Source-level correction and continued development: **GO**
- Direct merge into an unverified current `main`: **NO-GO**
- Flutter/Android build from this archive without governed inputs: **NO-GO**
- Firebase deployment or field distribution: **NO-GO**


## Tomorrow local trial

The guarded trial harness is:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\v4\Invoke-Crm3V42LocalTrial.ps1 `
  -CurrentAppRoot "C:\path\to\current\crm3_baf_ops"
```

It performs authentic code generation, source audits, three dependency audits, Functions tests, Flutter analysis/tests and a debug APK build. It contains no remote repository, backend deployment or production-data action. See `docs/v4_2/TOMORROW_LOCAL_TRIAL_RUNBOOK.md`.

## R1.6 bounded laboratory correction

R1.6 pins `@hono/node-server` 2.0.10, load-smokes the pinned Firebase CLI, and records a tooling-audit hold without suppressing downstream application evidence. Any recorded hold still prohibits an authoritative PASS.

## R1.10 post-codegen audit alignment

R1.10 retains the R1.9 application tree and exact-binds all 19 authentic generated Isar bindings to the authenticated R1.9 Windows code-generation evidence. Stage 20 now runs explicitly in `post-codegen` mode after custody, semantic continuity and release-authority gates. Non-generated canonical paths remain byte-pinned; generated outputs are not broadly excluded.

## R1.11 UTF-8 audit correction

R1.11 made all Python text-file reads and writes explicit UTF-8 so Windows locale defaults cannot crash source audits.

## R1.12 Flutter analyzer correction

R1.12 addresses all 18 diagnostics produced by the authenticated R1.11 Windows `flutter analyze` run: seven errors, three warnings and eight infos. The analyzer remains strict and must pass before Flutter tests, APK construction or emulator authority.

## R1.13 Flutter-test and replay-integrity correction

R1.13 corrects the R1.12 Flutter-test findings without treating them as analyzer regressions. It explicitly clears `isOpenForWork` during offline submit/accept replay, moves five dialog controllers into State ownership, repairs six stale or structurally brittle contracts, and makes Isar test-core custody hermetic and fail-closed. R1.13 remains a local-laboratory candidate until the complete authoritative Windows run passes from pristine packaged bytes.

## R1.14 Rules-emulator and online-lifecycle correction

R1.14 adjudicates the authenticated R1.13 emulator run: 103 of 122 Rules tests passed, ten permitted operations exhausted Firestore's 1,000-expression evaluation budget, and nine job-module positives exposed an omitted persisted `isOpenForWork` field. The correction preserves full user-document and role validation, routes one lifecycle branch per write, caches the module-family publication read, and writes the open-state field in all direct online module transitions. The next authority is a pristine `-RunEmulators` laboratory yielding `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`; this archive is not deployment authority.

## R1.15 maintenance-router Flutter contract correction

R1.15 adjudicates the authenticated R1.14 build run, where 472 Flutter tests completed with one stale structural assertion and the emulator gate was not reached. The R1.14 product source and Firestore Rules are preserved byte-for-byte. The single corrected contract now requires exactly one maintenance update `allow`, proves that it invokes `validMaintenanceUpdate()`, and verifies that the router retains close, reopen, soft-delete and Admin-edit validators without a parallel OR chain. The next authority remains a pristine `-RunEmulators` laboratory yielding `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`.

## R1.16 maintenance-match parser correction

R1.16 adjudicates the authenticated R1.15 run, where 472 Flutter tests passed and one maintenance-router contract failed before the emulator gate. The Rules line was present and unchanged; the test helper began brace search at the marker start and therefore treated the `{docId}` path token as the Rules block. R1.16 changes that helper to search after the complete marker, matching the already-passing expression-budget guard. No Firestore Rules, application, Functions, dependency, Firebase, Android or release-policy bytes are changed. The required next authority remains a pristine `-RunEmulators` laboratory yielding `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`.
