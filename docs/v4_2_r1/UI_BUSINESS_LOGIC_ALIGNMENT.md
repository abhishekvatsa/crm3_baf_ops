# Cross-App UI and Business-Logic Alignment

Status: SOURCE_IMPLEMENTED

Merge and exact-head CI evidence: PENDING

## Finding

The application had several presentation paths that did not express the
governed business policy already enforced by repositories, callables and
generated role definitions:

- compliance notifications discarded the exact compliance record identifier;
- equipment deployment was offered to actors outside the command role set;
- planned-job mutation controls were visible to read-only actors;
- governed assignments displayed legacy checklist and execution sections;
- abnormality master-data actions were visible to non-Admin users;
- privileged support screens relied on their parent route for access control;
- the More screen exposed a duplicate Charges route that opened Assets.

These were UI authority and workflow-semantic defects. Server and repository
checks remained the final mutation authority, but allowing users to enter
known-denied or semantically incorrect paths produced avoidable failures and
misleading operational state.

## Source Decision

The UI now derives each affected affordance from the same actor capability or
generated workflow command policy used by the governed operation:

| Surface | Alignment |
| --- | --- |
| Compliance notification | Resolves `complianceId` locally, performs one governed pull only when absent, then opens the exact record or an explicit safe fallback |
| Equipment status | Offers deployment only to roles authorized for `deployEquipment`; completion and error outcomes are visible |
| Planned-job dossier | Composes note, module and completion actions from current actor capabilities |
| Governed job detail | Uses module and lane semantics without presenting legacy checklist or execution-summary sections |
| Abnormalities | Keeps reports visible while restricting type management and default seeding to Admin |
| Conflict review | Revalidates Admin authority on direct screen entry before reading conflict data |
| Workflow diagnostics | Revalidates Admin/SI authority and does not start privileged local reads before authorization |
| More navigation | Removes the duplicate Charges-to-Assets route; charge abnormalities remain under Abnormalities |

The guards improve user guidance and direct-entry containment. They do not
replace backend authorization and do not create a client-side authority claim.

## Verification

Local source verification on 2026-07-31:

```text
Flutter analyze:                  no issues
Focused UI alignment suite:       9 passed
Affected workflow regressions:   12 passed
Full Flutter suite:              562 passed
Canonical R1 audit:               85 passed, 0 failed
```

The widget matrix includes read-only and authorized actors, a 320-pixel phone
viewport, a wide viewport, governed completion semantics, abnormality Admin
visibility, and the diagnostics authority-before-read boundary.

## Remaining Boundary

This tranche does not prove the F4 physical-device matrix, move a programme
gate, authorize pilot handout, or alter the production-signed Build 6 already
installed on the governed emulator. Lane-progress explanation, richer support
receipt visibility and the full role/device walkthrough remain separate UI and
operational work.

This branch is stacked on the R-03 source branch. Exact-head CI and merge
evidence remain pending while the upstream pull request and GitHub execution
availability are unresolved.
