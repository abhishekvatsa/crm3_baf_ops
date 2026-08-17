# A-02 to A-05 Architecture Exit Criteria

## Decision

This record supplies the forcing constraints for architecture findings `A-02`,
`A-03`, `A-04`, and `A-05`. `A-02` and `A-05` are now evidence-closed;
`A-03` and `A-04` remain `OPEN`. No source hotspot count, grep result, partial
remediation tranche, or absence of a known failure is sufficient for closure.

The ledger is the status authority. This document explains the evidence now
required by its `requiredExitEvidence` and `reArmTriggers` fields.

## Evidence Discipline

Inventories must be machine-generated, bound to an exact commit, and classify
behavior rather than merely count filenames or tokens. Text-search counts are
orientation only until the corresponding structured inventory exists.

An exception is admissible only when it names its owner, purpose, authority
boundary, mutability, data scope, regression coverage, and re-arm condition.
Broad exemptions for `metadataJson`, presentation diagnostics, provider files,
or legacy payloads are prohibited.

## A-02 Mixed Responsibilities

Closure requires a complete hotspot inventory and a disposition for every
admitted provider or presentation hotspot. Decomposition must make UI,
orchestration, persistence, and cross-aggregate transaction ownership explicit.
An evidence-bound exception may remain only where extraction would weaken a
real invariant or create greater operational risk.

Regression coverage must preserve authority ordering, loading and error states,
offline behavior, and transaction invariants. The source audit must detect both
new unclassified hotspots and recombination of responsibilities already split.

## A-03 Persistence Boundaries

Closure requires an operation-level inventory of direct Firestore and Isar
access. Presentation-layer access must be removed except for explicitly
registered, authority-gated, read-only diagnostic adapters. Mutations and
cross-source reconciliation belong behind repository or service boundaries.

Tests must prove authorization-before-read, denial behavior, stable loading and
error states, and offline semantics. New direct presentation access or an
unclassified provider persistence path re-arms the finding.

## A-04 Persisted Schema

Closure requires structured classification of persisted dynamic maps and JSON
fields. Schema-bearing payloads need typed or versioned strict decoders and an
explicit compatibility, migration, or reconciliation path. Extension bags must
be bounded and must not carry authority or business invariants.

Before pilot or cutover, a governed read-only inventory must cover production
data and every supported local database generation, with a repair or
reconciliation disposition for incompatible records. A new unclassified field,
an unversioned schema change, or silent malformed-state default re-arms A-04.

## A-05 Manufactured State

Closure requires a complete inventory of persisted-state catches, timestamp
parsers, and fallback sites. Required values may not be manufactured. Optional
values may be absent, but malformed present values must fail closed. Batch and
listener paths must quarantine a bad record or abort safely without advancing a
cursor beyond it, and operators need a stable repair state.

Before pilot or cutover, governed read-only inventory, reconciliation, and
repair evidence must cover production records and supported local generations.
New local-time, zero, empty-text, or default-enum substitution for
authority-bearing persisted state re-arms A-05.

## Transition Boundary

The criteria themselves do not inspect or mutate production data, deploy
backend code or Rules, close a programme gate, change pilot authorization, or
change any finding status. Each closure still requires exact-head pull-request
CI and admitted-main post-merge CI in addition to the evidence listed above.
