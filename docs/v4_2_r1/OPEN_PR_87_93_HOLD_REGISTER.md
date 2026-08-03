# PR 87-93 Consolidated Integration Register

Status: CONSOLIDATED SOURCE CANDIDATE

Re-adjudicated: 2026-08-03

Current-base authority: `main` at `58d941c4d1d1123b3af001ae4d2854253e0002c8`

Integration branch: `codex/pr87-93-current-integration`

## Decision

The original Build 6 hold prevented stale source from being merged while device
evidence and later Build 7 recovery work were changing the release boundary.
That hold is no longer being used as a reason to strand valid source work.

PRs #87 through #93 have now been re-adjudicated against current Build 7
`main` and assembled into one successor source candidate. The original PRs are
not merged by this action. They remain historical review records until the
successor candidate receives exact-head CI and an explicit merge decision.

## Integrated Stack

| PR | Historical head | Current integration commit(s) | Disposition |
| --- | --- | --- | --- |
| #87 | `2fc0e3f` | `269e911` | Retained; R-03 source semantics |
| #88 | `291b07f` | `619bee9` | Retained; UI/business alignment |
| #89 | `3533f52` | `544df48`, `dc6b352` | Retained; task-first UX and role records |
| #90 | `1e9c073` | `e24f6f3`, `6baecd5` | Retained; notification event receipts |
| #91 | `752417d` | `797ddaa` | Retained; auth-session retry binding |
| #92 | `311bb1b` | `07baee1` | Retained; Dart import-cycle removal |
| #93 | `5676d75` | `a9aec3a` | Retained; Firebase CLI advisory remediation |

The dependent order was preserved as #87, #88, #89, then #92. The independent
#90, #91 and #93 tranches were applied only after that stack was coherent.

## Current-Base Adjustments

1. Build 7 release, signing, custody and recovery records were preserved.
2. Reconciliation hashes and counts were rebound to the combined current files.
3. Notification changes were merged with the newer global-pull function and
   Firestore work rather than choosing either historical side.
4. The older v4.1, whole-app and maintenance audits were updated to the current
   S-04, R-01/R-02 and R-05 successor contracts.
5. Preserved `release_output` snapshots were excluded from live Flutter analysis
   without deleting or altering those evidence files.

## Evidence Boundary

Fresh local source, unit and emulator verification is recorded in
`PR87_93_CURRENT_INTEGRATION_PACKAGE.md`. Exact-head GitHub CI remains required
before a merge decision.

No phone was available for this integration. That does not block source review,
but every future signed artifact carrying these changes requires its own device
and distribution evidence. Historical Build 5, Build 6 and Build 7 evidence is
not reassigned to this source candidate.

## Boundary

This register does not authorize a Firebase deployment, production mutation,
artifact replacement, new signed build, controlled distribution, F4 closure,
pilot handout or unrestricted release.
