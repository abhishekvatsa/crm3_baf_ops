# Build 29 release preparation — 21 September 2026

Status: preparation in progress. No production deployment, build-number reservation,
production-signed Build 29, device installation or Play release has been performed
by this preparation.

## Owner decision and source

The owner requested moving toward the build and selected **“Plan a pause and
coordinated update”** when asked how to protect users of older readers. The question
explicitly did not start a pause. A window and confirmation that affected users have
stopped work are still required before the cutover; this document does not invent
either confirmation.

Application baseline is main `a2464d63c797e2e0b511ba3be789e7f5a522c5a4`.
[Release run 35565829917](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/35565829917)
passed all five jobs; [security run 35565830055](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/35565830055)
passed all four languages, including Kotlin. These checks do not certify a later
preparation commit. Final source must receive its own review and checks.

The existing production construction requirement remains: reviewed exact source,
matching deployed backend and Rules/index evidence, protected signing workflow,
independent package verification and custody. No alternate construction mode or
weakened runtime/distribution gate is introduced.

## Measured starting position

| Item | Observation | Consequence |
| --- | --- | --- |
| Previous production artifact | Remote `crm3-build-reserved/28` and `crm3-build-built/28` target `fc5825875293ac703449002a49799d70a6bf5351`; successful production run `34766863364`. | Build 28 is consumed, despite stale source-ledger wording. Reconcile measured completion before rollover. |
| Previous governed package | SHA-256 `3D70CC00A8EEBEECE13C3EEAA4654A774B2DDF7FD4A407B6E4AD838B8F1391BA`, bound by the remote built tag and retained private custody. | Preserve the original evidence; do not relabel it as this candidate. |
| Next production identity | No remote reservation or built tag for 29 was present in the 21 September observation. | Proposed version `1.0.0-rc.19+29`; recheck and atomically reserve through the protected workflow. This document is not a reservation. |
| Existing local version-29 packages | The local APK is signed by `CN=CRM3 CI Package Proof, OU=Non-Production`, certificate SHA-256 `39BC752CF85E55B4ADCCDFA1D8901922F28CD09285464A1C8C6B3011C72B09F6`. | They are test packages, not an upgrade for production installations or evidence of a governed production build. |
| Signing | Play original-key import receipt and existing production identity match SHA-256 `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`. Protected signing environment retains its required reviewer, disabled administrator bypass and four named signing secrets. | No replacement key is needed. A Play-delivered retained-data update remains unproved. |
| Live Functions | All 19 endpoints are ACTIVE; observed updates are from 13 September. Current source retains the same 19 endpoints and 15 runtime principals. | Qualify the complete changed implementation; endpoint presence alone is insufficient. |
| Live Rules | Active SHA-256 `9A64BF17BF0B2B7B5953F845ACE164804A59087C33749F8164B4DD715BC90A13`; candidate `7173B67BCA1627B546C3AA8D6A1CAEBA0378D071C2654B46629D01B6660E2927`. | Reviewed Rules deployment and strict readback required, including R04 owner-only installation point reads. |
| Live indexes | 66 composites, all READY; source has 67. Eight field overrides match. | Add the `audit_logs` composite (`entityType ASC`, `timestamp DESC`) and verify readiness; preserve existing indexes and overrides. |
| Owner phone | ADB returned no connected device during preparation. | Reconnect before the in-place upgrade and device qualification stage. |

Metadata observations and recovered historical custody files are retained privately
under `C:/Users/abhis/Downloads/CRM3_BUILD29_PREPARATION_20260921`. The Rules
collector ran in observation mode from a preparation branch, so its expected
source-main/parity failures are not presented as a passed production readback.
No credentials or business records belong in public release evidence.

The Functions metadata collector completed with
`PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE`. Its observation is not current-source
deployment proof; preparation-branch/working-tree checks were deliberately not
reported as production passes. The ordinary production policy verifier passed.
Its separate `RequireArtifactConstructionAuthority` preflight correctly refused
construction because approved-source and deployed-backend parity are absent.

## Preparation repair and checks

The preserved-pilot authority helper previously selected the separate historical
Build 27 backend only when the candidate number was exactly 28. A Build 29
regression reproduced a false rejection of valid preserved history. Selection
now uses the immutable admitted pilot's build identity for subsequent candidates.
Historical pilot, approved candidate and current backend evidence remain separate.

Independent review additionally found that malformed build selectors could fall
through to historical handling. They now fail before evidence selection. Eleven
focused tests passed, covering valid 27/28/29, candidate/current separation,
coherently altered historical/pilot records, damaged candidate evidence, existing
28 checks and Git replacement protection. Thirteen malformed-selector assertions
are included. Independent final review found no further issue in this narrow
change. An earlier full helper run was stopped after the selector change; it is
not claimed as a complete passing run. Fresh hosted review and checks are required
before merge.

## Compatibility and cutover

The new client is not a fully isolated read-only compatibility release against the
old backend. Some new actions have capability probes, while others require matching
implementations behind an existing endpoint. Do not infer compatibility from the
callable name or an unrelated V2 capability.

Affected old-reader boundaries include Burner round provenance, truthful late
Burner/UV recording, Morning Review cancellation and retained sessions, quality
monitoring schema 4, user-authority recovery envelopes, and revised direct-write
Rules. Saved and uncertain commands must remain retained under their original
account. Updating the app must not clear storage, uninstall the app or manufacture
acceptance of an old request.

1. Finish preparation review, source checks, predecessor reconciliation and exact
   deployment/construction decisions. Preserve a compatible recovery path before
   changing production. Historical approvals remain historical.
2. Agree the pause window and verify affected users have stopped app work. Account
   for pending clients, background workers and the existing scheduler; an operator
   announcement alone is not proof that all writes have stopped.
3. Deploy the reviewed complete Function fleet, Rules and added index under the
   agreed window, preserving approved identities and access. Read back actual
   deployed source, Rules, index readiness, capabilities and runtime settings.
   Do not invoke scheduled work or edit business records merely to obtain proof.
4. Complete the exact-source Build 29 approval/reservation and protected APK/AAB
   build, independent signature/package verification and private dual custody.
   A failed reserved attempt consumes its number.
5. Test the exact production-signed APK as an in-place owner-device upgrade,
   retaining local data and pending work; qualify startup, authentication,
   recovery, notification lifecycle and representative authorized business flows.
6. Verify the supported user cohort has updated before resuming workflows that
   emit incompatible records. Record the actual cohort and evidence, rather than
   assuming a version was installed because a download was offered.
7. Use the same verified AAB for the appropriate Google Play testing track after
   its release requirements are ready. Verify the Play-delivered signer and
   retained-data update. No public rollout or pilot approval follows solely from
   a successful build.

The existing submission-recovery activation record is a separate control. New
domain finalization requires its own compatible callable/worker and recovery
evidence; a fresh binary does not silently activate it.
