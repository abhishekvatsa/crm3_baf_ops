# Business audit remediation — 8 September 2026

This successor change addresses the confirmed data, retry and reporting failures identified in the supplied audit. It does not alter the already constructed Build 27 APK or turn its physical read-only check into proof of mutating business flows.

## Corrections and business effect

| Finding | Correction | Evidence and remaining limit |
| --- | --- | --- |
| SYNC-01 | A newer server version that conflicts with a later local timestamp becomes explicit reconciliation work. The local record is preserved, the affected cursor does not advance, and sync status/conflict counts show the failure. | Real Isar adapter tests cover 11 domains; coordinator, restart/cursor and live-snapshot tests cover propagation and recovery. This does not invent server lineage for ambiguous legacy rows. |
| CMD-01 | Save the actor's exact incident request, payload and event ID before dispatch; retry that same intent after a lost response or restart. A permanently rejected asset selection receives a committed rejection receipt so corrected input can safely use a new identity. | Storage failure, corruption, account change, response loss, accepted/rejected transaction races and screen retry tests. Only exact server-confirmed outcome evidence releases a saved intent; generic failures retain it. The optional server actor guard prevents a request prepared under one account from being accepted under another. |
| CMD-02 | Confirm historical acceptance from its immutable receipt and audit, even after a later valid change. Never replay the old state over the current record. | Declare → restore → replay declaration, and create → resolve → replay creation; corrupted evidence and revoked authority remain rejected. |
| QLT-01 | Merge warning windows by server revision. Delayed active snapshots cannot resurrect a newer closed warning; contradictory equal revisions and failed windows remain visible as errors. | Window-order, equal-revision, stream recovery and cancellation tests; existing warning producers advance the revision when source evidence changes. |
| RPT-01 | Preserve governed custom-asset identity through quality, abnormality, workflow and compliance joins, including native source records outside the selected reporting period. | Same-number cross-class tests, inconsistent-reference rejection, source-arrival/correction/refresh tests. Missing identity is reported instead of guessed; historical counts still use the selected period. |
| MR-01 | Use a reserved server-authored completion identity and validated native action reference. Keep administrative closure/acceptance separate from technical resolution and capture issue condition separately from lifecycle. | A shared Functions/Flutter completion fixture, public forgery rejection, ordinary completion-looking prose, native condition and administrative-outcome tests. Old completion prose is explicitly unverified. Existing document field sets stay readable by installed clients. |
| MR-02 | Check the projected frozen document size before admitting contributions, with room reserved for finalization fields. | Repeated multibyte contributions are rejected before an accepted session becomes impossible to finalize. The limit still exists; this change makes admission honor it. |
| SEC-03 | Treat narrowly identified ordinary business preconditions separately from abuse anomalies. | Request burst/daily quotas remain active; permission, malformed-request and unknown failures still count. The change is not a blanket exemption for failed preconditions. |
| GOV-01 | Require the five existing GitHub Actions release checks, an up-to-date branch, pull requests and resolved review conversations on `main`; forbid force pushes and deletion, including administrator bypass of these rules. | Applied and read back on 8 September. The reproducible configuration is `governance/main-branch-protection.json`. A separate human approval quorum is not configured. |
| DOC-01 | The Isar Community/schema description was already corrected on PR #358. | Preserve that correction; no database migration or Riverpod upgrade is included here. |

## Findings that need a separate decision or operating proof

| Finding | Disposition and next concrete step |
| --- | --- |
| SYNC-02 | A failed pull domain still stops later domains. Introduce dependency-aware progress and per-domain health together; blindly continuing every domain can combine incompatible snapshots. |
| TIME-01 | Device-clock-dependent reporting/expiry behavior still needs a defined server-time confidence policy and skew tests. This change does not claim to correct phone time. |
| LIF-01 | Replace business decisions based on editable English equipment/action labels with stable semantic identifiers and a reviewed compatibility mapping. |
| LIF-02 | Define one physical action's identity across execution and module sources before deduplicating lifecycle evidence. Similar text alone is not proof of the same action. |
| LIF-03 | Decide how late historical recording relates to current equipment state, then test physical occurrence order separately from receipt order. A blanket timestamp sort is unsafe. |
| NTF-01 | Existing notification uncertainty and replay protection are intentional. Establish the operational response for an uncertain delivery; do not automatically resend potentially delivered notifications. |
| RPT-02 | The integrated report currently requires all its source domains. Independently usable report sections need explicit completeness labels and a source plan. |
| RPT-03 | Current-versus-period labeling already exists. Further management analytics require agreed measures and historical source completeness. |
| AUD-01 | Distinguish attributable client observations from server-certified transitions in audit presentation. Attribution alone does not certify a state change. |
| SEC-04 | Legacy write paths remain for installed clients. Retire them only after retained drafts, pending work and upgrade coverage are accounted for. |
| SEC-01 | App Check enforcement remains under its existing deferral. Establish successful attestation for the actual sideloaded population before changing enforcement. |
| REL-01 | Validate a retained-data upgrade from Build 21 and representative mutating multi-device flows on the exact successor APK. Build 24 → 27 read-only evidence does not substitute for these checks. |
| OPS-01 | Existing backup/PITR and isolated restore evidence should be distinguished from current recovery readiness and recovery of unsent device data. Refresh the operating proof without claiming a backup contains work never synchronized. |
| AUTH-01 | Approved operational read access is a business policy. Define confidentiality boundaries before narrowing shared views or exports. |
| ARCH-01 | Continue defining cross-module business invariants with sequence tests. Source inventories are useful coverage controls, but cannot prove that a business conclusion is correct. |

## Rollout constraints

1. Existing clients may already have advanced cursors past a silently skipped server record. Plan a governed full re-read that preserves local data and surfaces conflicts; merely installing this fix does not guarantee those historical records are revisited.
2. Deploy and verify the compatible backend changes before a successor client starts sending the new optional actor guard or expecting terminal rejection evidence. Existing successful receipt fingerprints and installed-client response shapes must remain compatible.
3. Build 27 remains the exact existing artifact. These application corrections need their own reviewed source, governed successor artifact, backend readback and physical validation.
   Source authority is checked separately from the existing artifact's approval: new application or backend changes cannot inherit Build 27's runtime or distribution approval. Governance-only edits preserve approval when application and backend source still match their measured evidence.
4. No pilot handout, business-data mutation, device-data clearing, database replacement or App Check activation is performed by this remediation.

## Verification record

The original counterexamples were run against the old behavior before implementation. Focused suites then exercised the corrections, including independent review of other agents' changes. Intermediate runs reached 2,016 passing Flutter tests (one source-inventory failure subsequently fixed) and 1,004 passing Functions host tests. These are intermediate results, not final successor approval. Final source verification and PR evidence supersede them.
