# CRM-III BAF Ops

CRM-III BAF Ops is an offline-aware Flutter/Firebase application for Batch
Annealing Facility (BAF) operations at CRM-III. It covers corrective
maintenance, planned work, governed cross-department workflows, asset
condition, quality assurance and operational reporting, and keeps working on
the shop floor when connectivity is poor.

It supports operational and maintenance assurance. It is **not** a plant
control system (see [Safety boundary](#safety-boundary)).

## Status at a glance

| Item | Current reality |
| --- | --- |
| Latest finalized artifact | Build 30 (`1.0.0-rc.20+30`), signed from `7ed87824`, dual-custodied. Consumed: cannot be rebuilt or reused. |
| Live use | Build 30 published to an **owner-only internal Play test** on 29 Sep 2026. The Play-delivered in-place update from Build 29 to 30 was verified. |
| Deployed backend | 19-Function fleet from `2aa30de5`. Firestore Rules and all 67 indexes are verified live. |
| Current `main` | Source successor of Build 30: tester fixes, inspection v2 readings, Home availability, Inner Cover condition, a dependency and gRPC runtime repair, and the Build 31 business-release path. **No authority to build, deploy or distribute.** |
| Next release | **Build 31**: not yet allocated. Status is `AWAITING_FRESH_GOVERNED_BUILD31_APPROVAL`. `pubspec.yaml` still carries `+30` until a governed allocation. |
| Local store | Isar schema **v12** |
| Wider distribution | Not authorized. App Check/Play Integrity enforcement is deferred under governance and blocks broad distribution until re-armed and proved. |

`release/current-successor-state.json` and `governance/programme-ledger.json`
are the source of truth. Where this README and they disagree, they win.

## What is needed next

To move the current source to a usable release (Build 31):

1. **Finish source review.** Get CI green on exact `main` for the pending
   tester changes, including the Abnormality report, repeated-RA history, Home
   and Inner Cover work.
2. **Decide and deploy the backend.** The Functions tree no longer matches
   deployed `2aa30de5`, because `@grpc/grpc-js` and other dependencies changed.
   This needs a source-specific compatibility decision and a separately
   approved, reviewed backend deployment through the governed Build 31
   business-release path (`tools/release/BUILD31_RELEASE_PATH.md`). The
   development-only compatibility route does not cover this runtime change.
3. **Allocate and construct.** Reserve Build 31 in
   `release/build-number-ledger.json`, bump the version, then run protected
   signing, independent package verification and dual custody.
4. **Validate on devices.** Prove an in-place upgrade from Build 30 without
   data loss. Then run the role, denial, sync, offline/reconnect, revocation
   and mutating business-flow matrix on the exact artifact. For Build 30, the
   mutating flows and the retention of unknown historical drafts are still
   unproved.
5. **Decide on the channel.** Make a separate pilot or Play-track decision.
   Each wider audience needs its own approval, and App Check enforcement
   remains a gate for broad distribution.

## Product scope

- approved-user and role-capability administration;
- corrective issues: acknowledgement, deferment, correction and closure;
- planned-job templates, published versions, executions, modules and dossiers;
- Mech, Elec, Oprn, RED, I&A and shared workflow coordination;
- operational directives, morning review and audit history;
- charge abnormalities, evidence, repeated-RA history and root-cause links;
- inspections, including labelled readings, dates and comparison status;
- governed knowledge and template authoring;
- dynamic asset classes, hierarchy, physical assets, installed components
  (for example Bases and Inner Covers), ownership and tag resolution;
- plant condition and equipment availability by class
  (available/maintenance/down);
- quality-warning lifecycle and monitoring requests;
- utility, crane, transfer-car and other operational disruptions; and
- asset-class, asset and date-filtered operational reports.

The asset hierarchy is a foundation, not a complete asset-integrity programme.
Strategy-derived obligations, document applicability, configuration baselines,
revision-controlled procedures, spares, readiness and cost are planned work
that has not been built.

## Architecture

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter app and Isar-backed offline local custody |
| `functions/src/` | Firebase Functions (TypeScript): authoritative mutations |
| `functions/src/maintenanceWorkflow/` | Maintenance-workflow command system |
| `firestore.rules`, `firestore.indexes.json` | Client data-plane authorization and indexes |
| `governance/` | Programme ledger and generated policy authority |
| `release/` | Release policy, build ledger, approvals and sealed evidence |
| `tools/`, `tool/`, `tooling/` | Audits, release and dev scripts, pinned compat shims |
| `test/`, `integration_test/`, `functions/test/` | Flutter, contract, Rules and Functions tests |
| `public-support/` | Public privacy, support and account-deletion pages for Play |
| `docs/` | Runbooks, remediation records and historical evidence |

Client visibility is not an authorization boundary. Sensitive mutations are
enforced by Firestore Rules or by server-authoritative callables, with
transaction, replay/idempotency and audit controls. Where authority, target
identity or evidence cannot be established, the app fails closed.

## Toolchain

The release policy (`release/production-release-policy.json`) pins:

| Tool | Version |
| --- | --- |
| Flutter / Dart | `3.44.0` / `3.12.0` |
| Isar Community | `3.3.2` |
| Java | `21.0.11+10` |
| Node / npm | `22.23.1` / `10.9.8` |
| Firebase Tools | `15.22.4` |

Do not substitute a different Flutter, Dart or Isar generator when producing
release-authoritative schema output.

## Development

The fast loop runs the real app against local Firebase emulators. See
`docs/DEV_LOOP.md`.

```powershell
pwsh -File tool/dev/emulators.ps1                     # terminal 1
pwsh -File tool/dev/run_dev.ps1 -DeviceId <adb-id>    # terminal 2
```

### Firebase client configuration

`lib/firebase_options.dart` and `android/app/google-services.json` are tracked.
They hold client configuration, not secrets, and release tooling verifies their
identity and hashes (`docs/FIREBASE_CONFIGURATION_CUSTODY.md`). Never commit
service-account credentials, keystores, `.p12` files, passwords or
signing-key properties.

### Isar schema

The contract is schema v12. v11 added durable submissions, and v12 records
their review outcomes. Earlier fingerprints and ordered migrations remain
explicit. After any model change:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
python tools/isar/verify_v4_isar_schema.py --release   # must report v12, release_authority=YES
```

## Validation

Start with the source preflight. It checks the schema, dependency pins,
architecture ownership and evidence taxonomy:

```powershell
python tools/testing/run_source_preflight.py
```

Flutter and audits:

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

Functions, then the governed Rules and Functions emulator suite:

```powershell
Set-Location functions
npm ci
npm test
npm run emulator:test:governed
```

`release_gate.ps1` writes `gate-results.json`. Using a skip switch produces a
partial result. CI workflows live in `.github/workflows/`: release gate,
verification and production artifacts, business private replay, CodeQL, and
`@claude` review.

Bind test counts and pass claims to the exact commit and run. A CI pass, a
DEV build and a distributed release are separate evidence. A green CI run or
an APK filename does not prove production signing or authorization.

## Build and deployment safety

Local analysis, tests and debug builds grant no deployment authority. **Do not
deploy Firebase, modify production data, change IAM or distribute an APK from
an ordinary development command.** Every new artifact must:

1. reserve a new build number under the release policy;
2. bind the exact source, tree, dependencies, Firebase files and signing
   identity;
3. pass clean code generation, analysis, tests and Android packaging;
4. prove upgrade and migration without clearing user data;
5. verify backend and Rules compatibility, deploying only through the governed
   route;
6. pass the role, sync, offline and revocation matrix on the exact artifact;
   and
7. record finalization, custody and readback without rewriting prior history.

## Release history

| Build | Version | Disposition |
| --- | --- | --- |
| 30 | `1.0.0-rc.20+30` | Finalized, consumed. Owner-only internal Play test. Full business-flow acceptance open. |
| 29 | `1.0.0-rc.19+29` | Finalized historical evidence (`770f1745`). |
| 28 | `1.0.0-rc.18+28` | Finalized, non-distributable. Device and pilot validation never closed. |
| 27 | `1.0.0-rc.17+27` | Finalized (`c933ca0a`), approved for a staged pilot of up to 25 users (first stage: 2 users on 2 devices). Consumed. |
| 11 | — | Sealed historical pilot authority for its roster. |

Prior approvals apply only to their exact build. GitHub Releases, Firebase App
Distribution, web, public and unrestricted distribution have never been
authorized.

Historical reconstruction, hardening, rollover and closure records are kept on
purpose in `V4_HANDOFF/`, `V4_1_HANDOFF/`, `V4_2_HANDOFF/`,
`V4_2_R1_HANDOFF/`, `docs/v4*/` and `docs/70I_B*.md`. They explain why each
control exists. They do not replace the current ledger, release policy or
canonical audit.

## Safety boundary

The app supports operational and maintenance assurance. It is not a plant
control system. Safety interlocks, trips, permits, isolations, operating
procedures and competent-person decisions remain authoritative outside the
app. A missing record in the app, such as an unrecorded Inner Cover link, is a
reconciliation warning, not proof of physical plant state.

See `SECURITY.md` for vulnerability reporting.
