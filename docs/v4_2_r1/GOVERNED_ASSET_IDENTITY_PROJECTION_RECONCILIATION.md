# Governed Asset Identity Projection Reconciliation

## Purpose

Schema-v5 clients require every `governedCustom` workflow and equipment
projection to carry both `assetClassId` and `assetInstanceId`. Earlier versions
could create those projections with only `assetTypeKey` and `assetNumber`.

The local schema migration removes incomplete cached projections and resets the
workflow and equipment pull cursors. Therefore the server collections must be
reconciled before a schema-v5 client is distributed. Otherwise the strict
reader quarantines the legacy server rows and holds the affected collection
watermark.

## Authority Order

1. Deploy the backend that writes and validates class-scoped custom identity.
2. Place assignment, workflow, execution, asset-registry and template-governance
   mutations under a controlled maintenance hold. The transaction source-binds
   all seven evidence collections and aborts on any intervening change.
3. Run the reconciliation tool in `dry-run` mode against the target project.
4. Stop if any evidence is missing, malformed, partial, or ambiguous.
5. Adjudicate blockers using the asset registry and original assignment
   evidence. Never select an asset by asset number alone when several matches
   exist.
6. Run `apply` only from the exact clean `origin/main` commit with the required
   production confirmations.
7. Require a clean post-write readback and the
   `governed_migration_contracts/governed_asset_identity_v1` completion
   marker.
8. Release the mutation hold only after backend and projection readback.
9. Only then authorize distribution of a schema-v5 client.

## Reconciliation Evidence

For each unbound custom workflow the tool requires:

- a valid `jobExecutionId`;
- the linked `job_executions` document;
- exactly one server-only `published_template_assignment_requests` receipt
  linking that execution to a package, version, content hash and publication
  audit;
- the receipt-bound frozen `template_versions` snapshot and its immutable
  `template_publish_audits` publication record;
- an exact match between the receipt and the execution's immutable top-level
  template identity fields;
- an exact registry match for the referenced class and asset number, or the
  exact instance ID carried by an installed-component reference.

Mutable `job_executions.metadataJson` is never assignment authority. The tool
blocks the entire mutation when any workflow cannot be resolved exactly. It
also blocks partial identity pairs, malformed registry rows matching the
target class and number, registry contradictions, malformed counters, stale
current projections, and plans above the single-transaction mutation budget.

## Equipment Projection Treatment

Legacy `equipment_status/governedCustom_<number>` documents are replaced with
class-and-instance-scoped documents. Counters are recomputed from the complete
workflow set. A legacy aggregate may split into several physical projections
only when every contributing workflow has exact identity evidence and the old
aggregate counters match those complete facts. A split is blocked when any
target has no active workflow facts, because the aggregate cannot prove that
target's individual `available` versus `inService` state.

The old projection is deleted in the same Firestore transaction that creates
its replacements and updates the workflows. Before any write, that transaction
rereads every source collection, rebuilds the complete source-bound plan and
requires its hash to equal the dry-run plan. This detects changed evidence and
new matching documents, including registry ambiguity introduced after
preflight. Every entity mutation receives a deterministic
`governed_migration_audits` record.

## Commands

Run the contract tests:

```text
npm run test:governed-asset-identity-reconciliation
```

The governed Firestore emulator suite also exercises the complete transaction,
audit, readback, and idempotent rerun path:

```text
npm run emulator:test:governed
```

Show the exact invocation contract:

```text
node tools/v4/governed_asset_identity_projection_reconciliation.mjs --help
```

Production is dry-run by default. The tool requires a new evidence-output path,
an exact source commit and tree, explicit project confirmation, and the
read-only production flag. Apply additionally requires an exact clean
`origin/main`, the literal mutation confirmation, and the environment token
printed by the help contract.

## Failure Handling

- A dry-run blocker performs no cloud writes.
- A changed document between preflight and transaction aborts all entity and
  audit writes.
- Apply first records a source-bound `prepared` marker. A failed post-write
  readback leaves that marker incomplete.
- Re-running after an interrupted successful entity transaction is safe: the
  inventory must be clean and the exact planned audit count must exist before
  the same marker can advance to `complete`.
- A client that was upgraded before reconciliation must clear its stored
  workflow quarantine and perform a full pull after the server repair.
- The strict client decoder is not relaxed as part of this migration.
