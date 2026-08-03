# PR 87-93 Current Integration Package

Status: SOURCE_INTEGRATION_CANDIDATE

Prepared: 2026-08-03

Repository: `abhishekvatsa/crm3_baf_ops`

Baseline: `main` at `58d941c4d1d1123b3af001ae4d2854253e0002c8`

Branch: `codex/pr87-93-current-integration`

## Purpose

This package consolidates the work previously held in PRs #87 through #93 onto
the current Build 7 source base. It preserves each tranche's implementation and
tests while rejecting stale release metadata and recalculating evidence against
the combined current files.

The package is a source-review candidate. It is not a deployment, signed build,
device result, distribution approval or pilot authorization.

## Lineage

| PR | Historical head | Integrated commit(s) | Preserved outcome |
| --- | --- | --- | --- |
| #87 | `2fc0e3f` | `269e911` | Distinct succeeded, failed, queued and throttled sync outcomes |
| #88 | `291b07f` | `619bee9` | Actor-capability UI, governed dossiers and authority-before-read routes |
| #89 | `3533f52` | `544df48`, `dc6b352` | Task-first shell, responsive operational navigation and role records |
| #90 | `1e9c073` | `e24f6f3`, `6baecd5` | CloudEvent-bound notification receipts and uncertain-delivery quarantine |
| #91 | `752417d` | `797ddaa` | One profile permission retry budget per authenticated UID session |
| #92 | `311bb1b` | `07baee1` | Global Isar handle decoupled from `main.dart`; Dart import cycle removed |
| #93 | `5676d75` | `a9aec3a` | `re2` 1.25.2 lock, Node 22.23.1 and npm 10.9.8 release policy |

## Per-PR Integration Decisions

### PR #87

The sync result enum and all call sites were retained. Deferred admission is no
longer presented as failure. R-03 remains source-implemented and gains no device
or deployment evidence from this package.

### PR #88

Equipment, planned-job, abnormality, compliance and privileged-support screens
were retained with role-derived capabilities. Direct-entry routes reject before
starting privileged reads.

### PR #89

The Home, Issues, Work, Directives and More task model was retained, including
responsive navigation, bounded layouts, search, resolved issues, closed job
dossiers, workflow overview and the recent audit log.

### PR #90

All four notification triggers use the shared receipt coordinator. Preparation
failures may retry; completed receipts replay; malformed or stale receipts fail
closed; a dispatch whose outcome is uncertain is quarantined instead of being
sent automatically again. This is an at-most-one automatic dispatch boundary,
not an exactly-once delivery claim.

The Firestore and Functions conflicts were combined with the later global-pull
runtime-identity and compatibility work. Server-only receipt collections remain
client-inaccessible.

### PR #91

The profile-read retry budget now survives same-UID ID-token emissions and resets
only on sign-out or UID change. Wrong-UID, repeated denial and other failures
remain fail closed.

### PR #92

The global Isar dependency moved to `core/persistence/app_database.dart`. The
change does not alter schemas, migration versions, generation IDs or provenance
markers. A Tarjan strongly-connected-component test guards against reintroducing
the import cycle.

### PR #93

The Firebase CLI remains at 15.22.4 while its optional `re2` dependency is pinned
to 1.25.2. The exact release toolchain advances to Node 22.23.1 and npm 10.9.8.
Current Build 7 policy, signing, finalization, recovery and distribution fields
were preserved; no Build 6 policy document was restored.

## Successor Adjustments

Three older audits were corrected after execution exposed stale assumptions:

1. The v4.1 user-write check now recognizes S-04's profile-only Admin update and
   verifies that roles and approval cannot be changed by a client.
2. The whole-app audit expects the current 17-check R-01/R-02 verifier.
3. The maintenance audit verifies R-05's event-bound coordinator and ambiguous
   delivery quarantine instead of the superseded retryable lease.

`analysis_options.yaml` now excludes only `release_output/**`, preventing
preserved historical source snapshots from being analyzed as a second current
application. The evidence itself is unchanged.

## Verification

All results below were produced on the consolidated working tree.

| Check | Result |
| --- | --- |
| Functions clean build and inventory audits | PASS |
| Functions Jest suite | 336 passed; 63 skipped |
| Flutter analyze, exact repository command | PASS, no issues |
| Flutter full test suite | 595 passed |
| Firestore Rules emulator tests | 147 passed |
| Governed Functions emulator tests | 63 passed |
| Notification receipt emulator tranche | PASS within governed suite |
| Root npm audit, low threshold | 0 vulnerabilities |
| Functions npm audit, low threshold | 0 vulnerabilities |
| Governed Firebase CLI npm audit, low threshold | 0 vulnerabilities |
| Production release policy validator | PASS for Build 7; distribution not approved |
| Canonical audit, post-codegen | 93 passed, 0 failed |
| Ultimate audit | 17 passed, 0 failed |
| v4.1 due-diligence audit | 9 passed, 0 failed |
| Whole-app reconciliation audit | 23 passed, 0 failed |
| Maintenance full-tree source audit | 18 passed, 0 failed |
| Expanded implementation audit | 15 passed, 0 failed |
| Dart structural audit | PASS across 411 Dart files |

The local machine's default Node/npm remains 22.15.0/10.9.2. The exact
22.23.1/10.9.8 execution is therefore delegated to exact-head CI and the governed
artifact workflow. Lockfile policy, dependency integrity and advisory queries
were verified locally.

No physical phone was available for this package. No device result is claimed.

## Required Next Evidence

1. Push this exact successor head and obtain all release-gate jobs on that head.
2. Review the aggregate diff rather than merging the seven historical PRs.
3. Close the historical PRs as superseded only after the successor PR exists and
   its lineage is visible.
4. Make an explicit merge decision after CI and human review.
5. Build a new governed signed artifact before any device campaign involving
   these changes.
6. Perform device, backend deployment and distribution work only under their
   existing independent gates.

## Non-Authority Statement

This package does not deploy Firebase Rules or Functions, mutate production,
reuse historical device evidence, authorize distribution, close F4, approve a
pilot handout or approve unrestricted plant release.
