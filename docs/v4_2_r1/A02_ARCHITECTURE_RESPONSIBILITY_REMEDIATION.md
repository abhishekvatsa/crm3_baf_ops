# A-02 Architecture Responsibility Remediation

Status: CLOSED

Programme adjudication: `FINDING:A-02` is `CLOSED` as of 17 August 2026.
PR #232 exact head `8874c1d4d7b6ad0d07ec7924769c6aa97c76af06`
and admitted-main merge `0c0ddb7219c1043fe3924cd164acf06147d01e34`
share source tree `a6ffe16758711d587a213a85f95bea3f6f1730ad`.

## Scope

This source tranche replaces orientation-by-line-count with an enforceable
inventory of provider and presentation hotspots. The authority is
`governance/a02-architecture-boundaries-v1.json`, discovered and checked by
`tools/v4/a02_architecture_inventory.py`.

The inventory admits a file when it crosses the 1,200-line size threshold,
combines four detected responsibilities at 500 lines or more, combines local
and remote persistence, or performs persistence from presentation. Every
admitted file carries an owner, purpose, observed responsibilities, authority
boundary, persistence ownership, transaction ownership, regression evidence,
growth ceiling, required markers, forbidden markers and a re-arm condition.

The 24 August 2026 authority-lifecycle re-arm re-ran this inventory. It now
classifies 45 hotspots, including the inspection, frequent-issue,
maintenance-intelligence and actor-scoped operational-event workspaces, with
digest
`1A4F1842DBFD26CC273BA7D65E313980DE4FF9D2FE34004F3F89D53B6127E77E`.
The actor-scoped audit screen now remains below every hotspot threshold, so its
temporary bounded-exception declaration was removed.
No presentation surface acquired direct database ownership.

## Decomposition

The maintenance, abnormalities, directives, job-diary, job-module,
planned-maintenance and template-governance providers no longer combine their
local and remote implementations in one source file. Their existing Dart
libraries now expose three explicit units:

- the original root owns repository contracts, shared mapping and Riverpod
  wiring;
- `.local.dart` owns Isar access and local compare-and-apply transactions;
- `.remote.dart` owns Firestore mapping, batches, transactions and replay.

This is a library-preserving extraction: public provider and repository names,
private helper access and runtime selection remain unchanged. The inventory
forbids Firestore from the local parts, Isar transactions from the remote parts,
and implementation classes from returning to the contract roots.

The asset-hierarchy administration tab is also split by UI responsibility into
class/node dialogs, physical-asset registry, installed-component registry and
history, asset editing, component/ownership editing and reason capture. Every
part and the root remain below the governed size threshold.

## Bounded Presentation Surfaces

Remaining large presentation entries are single operational workflows or
already-extracted companion sections. They retain no unregistered transaction
ownership and have individual growth ceilings and regression tests. The
original closure inventory identified three presentation-level persistence
reads as A-03 carryovers. The A-03 source tranche subsequently removed those
reads from presentation, and the current A-02 inventory no longer classifies
the three files as persistence hotspots.

## Enforcement

The inventory fails when a hotspot is unclassified, a declaration becomes
stale, detected responsibilities change, a file exceeds its ceiling, a required
boundary marker disappears, a forbidden marker returns, or named regression
evidence is missing. The canonical audit and Flutter source contract both run
this enforcement.

## Closure Evidence

Exact-head release-gate run `32036713473` and admitted-main run `32037634060`
passed the inventory, canonical audit, complete Flutter suite and all governed
release-gate jobs. The immutable adjudication is recorded in
`release/evidence/a02-architecture-responsibility-source-and-ci-closure.json`.

This remains A-02 source-and-CI closure only. A-03 owns the admitted
repository/service extraction and its separate CI closure evidence. No
production deployment, production-data mutation, device proof, pilot
authorization or distribution authority is claimed.
