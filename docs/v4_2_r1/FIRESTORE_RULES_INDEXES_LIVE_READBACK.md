# Firestore Rules and indexes live readback

## Scope

This tranche adds a reusable, read-only collector for the production Firestore
Rules release and composite-index state. It does not close `LR-02` or `P-04` by source assertion.
Closure requires a fresh strict receipt captured from merged, clean `main` after
this collector and its CI contract are themselves merged.

## Authority boundary

Strict mode accepts only project `crm3-baf-ops-b8638`, requires `HEAD` to be
`main` and equal to `origin/main`, and checks the governed worktree both before
and after the live calls. Only `.claude/`, `output/`, and `tmp/` are ignored as
known local user workspace paths.

The collector performs these reads:

- active Firebaserules release and ruleset by HTTPS `GET`;
- deployed index definition through the repository-pinned Firebase CLI;
- paginated composite-index state through Firestore HTTPS `GET`.

It does not read Firestore documents. It has no deploy, write, IAM, Functions,
App Check, or business-data mutation route. The append-only output must be
outside the repository.

## Fail-closed comparison

The active Rules file must be byte-identical to `firestore.rules`. Source, CLI,
and API composite-index sets must be semantically identical; source and CLI
field overrides must be identical; and every API index must be `READY`.
Malformed, missing, partially returned, non-ready, dirty-source, detached-head,
or stale-main evidence yields `HOLD_FIRESTORE_RULES_INDEXES_LIVE_READBACK`.

Observation mode always yields
`OBSERVE_FIRESTORE_RULES_INDEXES_LIVE_READBACK`; it cannot authorize closure.
Receipts retain only hashes, counts, state summaries, command/endpoint identity,
timestamps, and the no-mutation boundary. Rules content, index definitions, and
account identity are not retained.

## Post-merge capture

After fetching `origin/main` and checking out clean `main`, the governed command
is:

```text
node tools/release/collectFirestoreRulesIndexesReadback.js --repository-root <repo> --project-id crm3-baf-ops-b8638 --output <outside-repo-json>
```

A strict `PASS` receipt must then be SHA-bound into a separate closure tranche
before either ledger record changes state.
