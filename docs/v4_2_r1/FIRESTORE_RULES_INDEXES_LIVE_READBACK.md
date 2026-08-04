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

## Closure

Status: **CLOSED** for `LR-02` and `P-04` on 2026-08-04.

PR #130 merged collector head
`8a8525d6080e787aee3480b792411298e6b51cc5` as
`b6f5838360f46d8f164338164f295b93fe3335ad`; both exact trees are
`e9be9938cba1cf9b7d387f04d8f79614d8a1c627`. Pull-request run
`30870605924` and post-merge run `30871016815` passed all four release-gate
jobs.

The strict receipt at
`release/evidence/lr02-p04-firestore-live-readback.json` has file SHA-256
`F2DB0F6491F427636D18E1CC4EF8C95FA03A8B0E738B74E175BF97C8ECC71815`
and canonical receipt SHA-256
`9215a3d8a7f8b273a67d2088fc9d3121da5f6be1ae8972d8526e535b05d4fae4`.
It was captured from clean merged `main` with fetched `origin/main` parity and
no failed checks.

The admitted state is:

- active Rules byte-exact at 136,651 bytes and SHA-256
  `B1B50675EF479CA62E8841DDFF61D4CD7995F1B1C5E8E4A34AD4F2292B18096E`;
- source, pinned-CLI and Firestore-API index counts all 51;
- all 51 API indexes `READY`;
- all three normalized index-set hashes exact;
- zero field overrides on both source and live CLI views.

The receipt performed no Rules/index deployment, Firestore document read or
write, Functions, IAM, App Check, business-data, device, distribution or pilot
mutation. `STAGE2D-F4` remains open and `pilotHandout` remains
`NOT_AUTHORIZED`.
