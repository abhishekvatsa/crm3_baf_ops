# Open PR 87-93 Integration Hold Register

Status: HOLD BY DEFAULT

Owner reaffirmation: 2026-08-02

## Decision

PRs #87 through #93 remain open. Green historical checks, a later PR number,
or presence of their commits in the repository graph does not authorize a
merge. They were intentionally retained outside `main` while the exact signed
Build 6 device campaign establishes its evidence boundary.

No source progress is rejected or reverted. Every head remains an integration
candidate and must be adjudicated individually after its original prerequisite
and current-base compatibility are proved.

## Stack

| PR | Head | Dependency | Current disposition |
| --- | --- | --- | --- |
| #87 | `2fc0e3f` | `main` | HOLD; R-03 source candidate, no device claim |
| #88 | `291b07f` | #87 | HOLD; stacked UI/business alignment |
| #89 | `3533f52` | #88 | HOLD; draft UX restructure, future build/device proof required |
| #90 | `1e9c073` | `main` | HOLD; draft notification receipt control, deployment-sensitive |
| #91 | `752417d` | `main` | HOLD; draft auth-session retry correction, not in Build 6 |
| #92 | `311bb1b` | #89 | HOLD; draft architecture correction on the UX stack |
| #93 | `5676d75` | `main` | HOLD; draft Firebase CLI dependency correction |

## Re-adjudication Rule

An individual PR may move only when all of the following are recorded:

1. why integration is necessary now;
2. whether its original device-evidence prerequisite is complete or genuinely
   inapplicable;
3. exact current-`main` conflict and semantic review;
4. fresh checks on the refreshed exact head;
5. effect on immutable Build 6 evidence and any need for a later signed build;
6. effect on the backend deployment and migration campaign;
7. an explicit merge decision for that PR only.

The stacked chain must preserve order: #87, #88, #89, then #92. Independent
PRs #90, #91 and #93 are not pulled into that chain merely for convenience.

## Boundary

This register does not close, supersede or merge any PR. It does not authorize
a Firebase deployment, production mutation, artifact replacement, new signed
build, distribution, F4 closure or pilot handout.
