# CRM-III BAF Ops

CRM-III BAF Ops is an offline-aware Flutter/Firebase application for Batch
Annealing Facility operations, corrective maintenance, planned work, governed
workflows, asset condition, quality assurance and operational reporting.

## Current authority boundary

This repository contains two different kinds of authority that must not be
conflated:

- **Current source:** the latest admitted application, Rules, Functions,
  tests, governance and documentation on `main`.
- **Preserved staged pilot artifact:** the exact signed Build 27 package, source,
  certificate, backend, device-acceptance and promotion evidence recorded by
  the release policy. The earlier Build 11 authority remains historical.

Build 27 (`1.0.0-rc.17+27`) was constructed from exact merged source
`c933ca0a`, independently verified, and finalized into dual custody. Its
governed package SHA-256 is
`BCA671188C2CDA1298E415A4DF0EBD30DDA694A23DFEB27BF1D669A6956E2B42`.
The 15-Function fleet was deployed with existing IAM preserved and App Check
enforcement unchanged, then passed strict live readback. The unchanged
Firestore Rules and 66-index set were verified exact without redeployment. The
scheduled Function was not manually invoked, and no production business record
was changed or deleted.

Build 27 is an immutable production-signed candidate approved for a staged,
direct-custody controlled pilot of no more than 25 approved users. One exact
physical in-place upgrade and the reviewed read-side interactions passed. The
first handout stage is limited to two approved users on two named devices;
mutating business-flow convergence must be gathered there before expansion.
Every handout requires a privacy-safe receipt. Build 27 is consumed and cannot
be reused. Its artifact, device acceptance and pilot approval remain historical.

Build 30 (`1.0.0-rc.20+30`) is the latest finalized artifact. Protected
signing completed from merged source `7ed87824` in production run `36577226874`.
Independent finalization retained the exact package and all six private-cloud
custody proofs. Build 30 is consumed and cannot be rebuilt or reused. Its
19-Function backend and Firestore Rules remain verified against deployed source
`2aa30de5`, with all 67 indexes ready. Original failed commands and prior
source, custody and approval decisions remain preserved.

After finalization, a separate delegated decision authorized owner-only internal
Play testing. The exact AAB was published on 29 September 2026, and an actual
Play-delivered in-place update from 29 to 30 was verified. The original signer,
installation identity and observed current data were preserved. Retention of
all unknown historical drafts and full live business-flow acceptance remain
unproved. These later observations do not rewrite the finalization-time
non-distribution flags or grant public distribution authority.

The working source batches Home, Inner Cover condition and related tester
experience corrections for the next governed release. Build 31 is an
unallocated working label: fresh source review, exact-main checks, a
source-specific compatibility decision, version allocation, custody, signing
and channel approval remain required. Current modified source has no artifact
construction or distribution authority. A missing recorded Inner Cover link is
a reconciliation warning, not proof that a Base is physically without a cover.

The dependency repair includes the Functions runtime dependency `@grpc/grpc-js`,
as well as development-tool dependencies. The current Functions tree therefore
differs from deployed `2aa30de5`; that deployed fleet and its historical receipts
remain unchanged. The existing development-only compatibility route does not
admit this runtime change. Construction remains disabled pending a separately
authorized and reviewed backend deployment route and source-specific decision.
Local repair and testing do not authorize deployment or distribution.

The pending tester source also makes Abnormality report totals actionable and
shows repeated RA as a connected history of recorded old/new charge links.
Undated stages use the plant's lower-charge-number-first convention; missing
RA dates remain unrecorded. Shared Bases or nearby charge numbers do not create
links, and conflicting branches are shown for reconciliation. A completed
entry does not imply that the whole charge history is closed. Diagnostics in
an App Check-disabled build explain that backend verification is unavailable
while keeping local reports usable; enabled builds retain bounded checks.
These changes still require final CI and installed-device acceptance.

Build 29 (`1.0.0-rc.19+29`), constructed from `770f1745`, remains historical
finalized evidence with its original custody and acceptance boundaries intact.

Build 28 (`1.0.0-rc.18+28`) was constructed and dual-custodied as a
non-distributable finalized artifact. Its exact-device and business-flow
validation and its pilot promotion remain open.

Authoritative status sources:

- `governance/programme-ledger.json`
- `governance/successor-engineering-rearm-2026-08-16.json`
- `release/current-successor-state.json`
- `release/production-release-policy.json`
- `release/backend-current-state.prod.json` (historic deployed-state capture)
- `docs/v4_2/PROGRAMME_AUTHORITY.md`

The sealed Build 11 decision remains exact historical authority for that
artifact and roster. A
separate source-and-CI successor campaign was re-armed on 16 August 2026 for
audit remediation, remaining business capability and UI/UX redesign. Any new
artifact requires its own governed reservation, exact signed-device validation
and a separate pilot decision. Build 27 now has that bounded decision. GitHub
Release, Firebase App Distribution, web, public and unrestricted distribution
are not authorized by those historical pilot records. Build 30's separately
authorized owner-only internal Play release does not authorize a wider audience
or this modified source. App Check/Play Integrity changes remain governed.

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
- Isar Community `3.3.2`
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

The current local-store contract is Isar schema v12. Authentic checked-in
generated bindings contain zero `PROVISIONAL_V4_ISAR_CODEGEN` markers. Schema
v8 added originating-user evidence to synchronization rejections, v9 added the
maintenance-derived Plant Condition effect, and v10 added its durable
contribution index. Schema v11 added durable submissions; v12 records their
review outcomes without letting older readers misinterpret that evidence.
Earlier governed fingerprints and ordered migration steps
remain explicit.

Before any release claim, run:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
python tools/isar/verify_v4_isar_schema.py --release
```

The release verifier must report schema v12, zero provisional bindings and
`release_authority=YES`. Existing-store adoption, migration, quarantine and
recovery evidence remain governed separately from successful code generation.

## Local validation

`python tools/testing/run_source_preflight.py` checks the committed schema,
dependency pins, architecture ownership and evidence taxonomy before expensive
work. Each of the five CI jobs runs it independently and still must pass its
complete job. The separate A03 persistence audit needs Dart analyzer packages:
the three Flutter jobs and local runner run it after dependency resolution,
before analysis, code generation, emulator startup or packaging. Source-only
preflight does not claim that dependency-aware check ran. The focused
no-loss run repeats a subset of the full Flutter suite; its passes are not
additional unique tests.

`release_gate.ps1` writes `gate-results.json` with passed, failed, skipped and
untested groups (and non-blocking formatting warnings). Skip switches produce a
partial result. A CI attempt, an isolated DEV candidate build and a distributed
release are separate evidence: neither CI success nor an APK filename establishes
production signing, distribution or release authorization.

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
