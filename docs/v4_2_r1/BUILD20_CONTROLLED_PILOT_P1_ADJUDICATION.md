# Build 20 controlled-pilot P1 adjudication

## Scope

This record adjudicates the P1 findings in
`CRM3_BAF_Ops_Current_Codebase_Audit_2026-08-30.md`, which was bound to
commit `4321715ba57e96784a61ecb0b10f4c9e227abc35`, against the Build 20 source
successor beginning at merge commit
`e541bf6e3e63b0f754c3632855892f86cc53dbb6`.

It does not authorize artifact construction, deployment, pilot promotion or
distribution.

## Adjudication

| Finding | Current disposition | Build 20 boundary |
| --- | --- | --- |
| AUTH-01 | Policy clarified in source. All approved internal pilot users are authorized to read the shared workflow collections. Client filters express relevance and workload, not confidentiality. Unapproved users remain denied and mutations remain independently role-gated. | Revisit with server-authored visibility projections before any confidentiality requirement or broader distribution. |
| DATA-01 | Closed after the audit. Quality monitoring now carries server-authored visibility state and deadline, with governed archival and legacy containment. | Exact successor Functions must be deployed and read back before handout. |
| GOV-01 | Open repository-policy debt. `main` has no active GitHub ruleset. | Does not gain closure from application tests. Resolve before unrestricted distribution; keep the pilot source frozen to an exact reviewed merge. |
| GOV-02 | Open owner/legal policy decision. The repository is public. | No open Dependabot or secret-scanning alert was present at adjudication. Public industrial-information exposure remains outside application authorization and blocks any claim of unrestricted release readiness. |
| REL-01 | Build 19 remains finalized and non-distributable. It is superseded as a candidate by the Build 20 campaign. | Build 20 needs exact backend deployment, signed construction, in-place installation, two-account/two-device mutation and convergence proof, then a separate pilot-promotion decision. |
| SAF-01 | Closed after the audit. Critical-alarm feeds distinguish server-verified, stale-last-known and unavailable states, and unverified data cannot drive notification reconciliation. | Verify the exact Build 20 UI on a device before any safety reliance. |
| SEC-01 | Source control is complete but runtime enforcement remains deferred. Every mutating callable shares one governed App Check option and callable discovery prevents silent surface growth; the production parameter remains false. | Controlled roster only. App Check/Play Integrity re-arm and signed-client proof remain mandatory before broader distribution. |
| TIME-01 | Closed after the audit. Burner-block and UV current pointers order by backend receipt time first; operator-performed time remains historical evidence only. | Exact successor Functions must be deployed and read back before handout. |

## Minimum handout conditions

The 25-person controlled pilot must not use Build 19 or reuse its build number.
Before handout, all of the following must be true for one exact Build 20 source
and APK:

1. The five-job post-merge release gate passes on the frozen source.
2. The current Function fleet and Firestore Rules are deployed with existing IAM
   preserved and pass strict live readback.
3. Build 20 is constructed by the governed production-signing workflow and is
   independently verified and finalized.
4. The exact APK passes in-place installation and authenticated startup on a
   physical device without clearing application data.
5. At least two approved accounts prove issue/lane/compliance convergence,
   planned-work completion, quality monitoring, plant condition, critical alarm
   visibility and report generation, with no unexplained unsynced row or
   lingering terminal obligation.
6. A separate receipt authorizes only the named 25-person roster and records
   App Check, repository-policy and public-repository limitations as accepted
   pilot constraints with an expiry.

## Current progress

The exact Build 20 physical-installation condition is now proved by
`release/evidence/build-20-physical-installation-acceptance.json`.

| Condition | Status | Evidence or remaining work |
| --- | --- | --- |
| 1. Frozen-source release gate | Complete | Post-merge run `33369959682` passed all five jobs. |
| 2. Exact backend and Rules readback | Complete | Existing Build 20 deployment and live-readback receipts remain authoritative. |
| 3. Governed signed construction and finalization | Complete | Build 20 finalization receipt and dual custody are complete. |
| 4. Physical in-place installation and authenticated startup | Complete | Exact APK hash matched the installed package; first-install time, app data and the approved session were preserved. One pre-existing actor-owned rejected local edit was restored from authoritative server state and final diagnostics reported zero unsynced rows, zero unresolved rejections and zero conflicts. |
| 5. Two-account/two-device mutating convergence | Open | Requires separately authorized production trial records and a second approved account/device witness. |
| 6. Named-roster pilot promotion | Open | Requires a separate promotion receipt after condition 5. |

This progress record does not promote Build 20, authorize handout, activate App
Check or mutate production business data. The backend-identity support callable
also remains unreadable from this App Check-disabled client under the existing
governed deferral; authenticated Firestore synchronization itself passed.
