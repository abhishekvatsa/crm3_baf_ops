# Burner and UV review remediation — 20 September 2026

This source review responds to `CRM3_Burner_UV_Final_Review.pdf`, supplied by the owner. The report is evidence, not executable instructions. The starting branch was `claude/quality-case-backend-contract` at `b35df6bdcaf19859755f693ca2d941a0dd591080`, with earlier authorized Inner Cover, alarm, multi-agency and Play preparation changes still uncommitted. Those changes are preserved in the combined PR candidate.

## Repairs

| Finding | Resulting behavior and evidence |
| --- | --- |
| F01 — accepted directive completion cannot replay after a later clear round | Producer and replay share the same disposition projection. Replay preserves the accepted red-hot state instead of assuming every non-restored disposition made it true. Tests cover eight positions and all four dispositions after a later clear round. |
| F02 — copied readings become apparently fresh | Rounds carry field-level source, observer, physical observation time and evidence kind. Partial submissions identify only actually observed fields; other fields inherit their original evidence. Unknown legacy provenance stays unknown. Reports count witnessed surveys separately from partial/directive updates and use each reading's original time. |
| F03 — raw history overrides an installation correction | Current selection uses authoritative current projections. Raw history remains history. Corrected effective time participates in the draft's installation basis, including when the event ID remains unchanged. |
| F04 — edits made during a save cannot safely continue | Drafts retain field revisions and the original submitted snapshot. After acceptance, compatible successor edits rebase to the accepted/current evidence; changed fields or installation evidence require explicit review. The backend transaction verifies installation and open-issue bases. A proven first-attempt refusal releases the refused intent; a refusal after an uncertain prior attempt preserves the original request. |
| F05 — descriptive rename breaks historical replay | Stable asset identity, class and position remain binding. A later display-name change does not rewrite or invalidate historical acceptance. |
| F06 — moving a repeated physical-action ID escapes duplicate checks | Burner and UV action identity is scoped by original source type, parent source and action ID. Position, asset, time and disposition are compared as facts, not used to create a different identity. Contradictions are refused; exact duplicates, distinct parent/action identities and supported legacy records remain compatible. |
| F07 — sparse receipts admit altered inherited evidence | New receipts bind the accepted materialization and retained baseline. Replay compares normalized complete evidence, including untouched readings. Supported legacy replay uses surviving original evidence; missing or corrupted evidence is not retrospectively declared authentic. |
| F08 — installation corrections are volatile and cannot be superseded in the UI | The native durable journal owns the exact original account and command before dispatch. The reviewer can check a saved correction after process loss, including when no new current record is visible. Server readback is required before reconciliation. A complete unbranched correction chain identifies the exact predecessor for another correction; original and effective installation dates are shown separately. Backend replay verifies the original audit fingerprint and full accepted correction while allowing later legitimate current installations. |

The new correction-history read rule permits approved Admin/SI reviewers to read the server-owned correction records. All direct client writes remain denied. This is a source Rules change; it has not been deployed.

## Verification

- Functions build, emitted-output check and backend inventories passed.
- Full Functions host suite: 71 suites / 2,017 tests passed; 18 environment-gated suites / 188 tests were skipped in that host run.
- Four additional Burner transaction tests passed against a local Firestore emulator: actual Timestamp transport and historical replay, changed installation basis, changed issue basis, and competing partial saves.
- Full Firestore Rules suite: 219 tests passed against a local emulator.
- Focused Burner/UV Flutter suite: 80 tests passed. Its environment-dependent bridge HTTP test was skipped in this direct run; it is exercised by the separate bridge contract runner.
- Native correction tests use real Isar database close/reopen with controlled remote outcomes. Readback contract tests invoke the same decoder/verification helper used by the actual repository and reject changed subject, predecessor, reviewer, explanation or chronology.
- Complete combined Flutter run: 2,935 tests passed; its only failure was a stale current-ledger count/digest expectation. After correcting those expectations, all six ledger contracts passed on rerun. No unresolved local test failure remains. The one bridge harness test skipped in the ordinary run was exercised through the separate Node bridge suite.
- Final Flutter analyzer: no issues. Canonical source audit: all 150 checks passed. A02/A03/A04/A05 inventories and test-evidence taxonomy passed.
- Full Node persisted-data sweep/real Dart bridge contracts: 24 tests passed. Play workflow input/ceiling contracts: five tests passed, with two related ledger tests passed. Signing helper scripts parsed and their Java export regression passed using only synthetic keys/passwords; no production secret was read during verification.

The local emulator used synthetic data only and was stopped after these tests. These results do not establish Android process-kill behavior, in-place device upgrades or plant-operation acceptance.

## Activation and remaining boundaries

**Do not deploy the new provenance-producing backend into the existing mixed client fleet.** The `b35df6bd` round decoder has an exact field allowlist and rejects the new provenance fields. Conversely, the new partial editor sends fields the older backend rejects. Source review and push do not establish a compatible production rollout.

An activation plan must first deliver compatible readers while retaining existing write behavior or keeping the new editor disabled, establish that older readers are upgraded or prevented from consuming the new records, and then activate the matching backend and editor together. Existing Inner Cover physical-time changes have their own older-client admission requirement. No automatic fleet gate or staged reader-only build is claimed here. The release owner must verify the actual installed fleet and the exact proposed artifacts before activation.

UV installation-date correction remains an unsupported product operation; this change does not invent a parallel correction protocol or expose a button that cannot complete. Ordinary UV replacement history and current selection are covered. The report's separate operational questions—overlapping directive obligations, whether a UV fault represents physical isolation, and repair of already damaged production evidence—require actual business evidence and explicit policy. No routine command silently closes another obligation, declares physical isolation or rewrites historical business records.

No backend deployment, production-record mutation, signed APK/AAB construction, Play release or distribution is performed by this source remediation. The pending Play preparation and verified original-signing-key custody evidence remain separate from release authorization.
