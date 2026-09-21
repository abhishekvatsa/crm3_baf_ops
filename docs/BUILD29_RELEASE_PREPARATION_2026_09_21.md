# Build 29 release preparation — 21 September 2026

Status: preparation in progress. No Functions or Rules deployment, build-number reservation,
production-signed Build 29, device installation or Play release has been performed
by this preparation. The separate additive index pre-stage is recorded below.

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

The first preparation head `7cfe4ec9` subsequently received a clean bot review and
passed the hosted backend/custody and Rules checks. This is evidence for that head,
not approval of subsequent custody changes.

The original Build 28 six-object private-cloud proof was recovered from its local
custody directory. Its exact SHA-256 is
`2CFC51F7BE04E31413DC11653A031EF8EE108EE2F8530E159BF0B807D31293AA`.
All six primary files/sidecars and all 18 closure-archive entries were independently
checked. The measured construction-only closure is now retained at
`release/evidence/build-28-finalization-closure.json`; it binds the original proof
at `release/evidence/build28-private-gcs-custody-readback.json`. Git attributes
preserve both files' physical bytes. The existing completed-custody validator
accepted the real evidence. No device acceptance or distribution is inferred.

Build 29 has a separate private-backup decision in
`release/approvals/build29-private-cloud-custody-approval.json`, committed as
`53cb4737e87af00b22053d8669661f097b27c18a`. It retains the same private bucket controls
and limits the new prefix to `release-custody/build-29/`. The decision records the
agent's interpretation of the owner's release delegation, not invented
source-specific owner wording. It does not start the pause or authorize a build
without the existing construction checks.

Private-custody support selects separately fixed Build 28 and Build 29 approval
objects. Per-file and aggregate records carry the verified artifact's build number;
the finalizer and completed-custody verifier reject mixed-build proofs. Build 28's
original authority and proof bytes remain intact. Other unapproved numbers,
cross-build prefixes, altered approval objects and weakened bucket controls remain
inadmissible. No backup upload or bucket change is performed by these source edits.

Final local checks passed: 53 private-custody producer/finalizer tests, all eight
current-source authority tests (including 334 completed-custody acceptance and
rejection cases), 31 focused Flutter release-contract tests, the complete production
policy verifier and diff validation. The real historical Build 28 proof remains
accepted unchanged. Independent custody review found no actionable blocker. These
are preparation checks; fresh hosted checks and review must cover the final head.

The complete `61b72c7a` preparation head subsequently passed all five release jobs
and all four language security jobs, and received a clean bot review. Further
deployment/device-tooling changes require another review and check run.

The successor backend verifier also retained Build 28-only approval/CI paths.
Build 29 now has a separate admitted path pair and delegation policy, retaining
the existing source ancestry, committed-byte, predecision exact-main CI and
postdecision deployment chronology requirements. The old path pair remains
unchanged. The new positive regression failed against the original committed
helper; ten focused tests passed after repair, including crossed path/policy/CI
pairs and coherently recommitted invalid evidence. No actual new deployment
decision or deployment is inferred from these synthetic fixtures.

The strict owner-device acceptance path now explicitly admits Build 29 alongside
the unchanged Build 28 contract. It still requires the exact APK, signer,
artifact-derived local schema, preserved approved session, completed idle sync,
strict zero failure counters and the seven measured read-only surfaces. Build 29
additionally binds the actual retained Build 28 closure and nested Build 27 history.
The actual policy-branch tests passed 420 Build 28 and 490 Build 29 cases. This
adds verification support only; no device-acceptance receipt, business-flow pass
or distribution decision is created.

The complete staged-promotion/deployment-authority suite subsequently passed all
118 tests, and the final production policy verifier passed with both new paths.
Independent device-contract and index-evidence review found no blocking defect.

The owner subsequently connected a Samsung SM-G990E running Android 16. Read-only
package inspection found installed version `1.0.0-rc.18+28`; its extracted APK
SHA-256 is `A488857B5740514E2286B550442A0734A53777FF1B672032956D7830AF73D659`,
exactly the retained governed Build 28 APK, and its verified signer is the original
`6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`.
No account identifier or device serial is recorded here. This establishes the
upgrade starting package; it is not a new runtime/business-flow acceptance result.

## Additive index pre-stage

On 21 September at `14:03:33.900897Z`, the agent created the sole missing
source-defined composite index under the owner's build delegation:
`audit_logs` collection scope, `entityType ASC`, `timestamp DESC`. Its resource
ends in `CICAgPi9ipAK`. All original 66 index definitions and resource identities
remain present. At `14:10:12.39Z`, API and CLI observations matched all 67 source
indexes, all READY, with the same eight field overrides and unchanged active Rules.

`release/evidence/build29-audit-index-prestage.json` records the actual decision,
command and readback. This changes indexes only: Functions, Rules, IAM and business
documents were not changed by the operation, and the client pause did not start.
The observation retains its expected preparation-branch/dirty-source and pending
Rules failures; it is not presented as a strict deployment pass. The later
Functions/Rules cohort must freshly observe the indexes already exact and preserve
them; only that later cohort can record that it made no index change.

Normal scheduler/event processing can continue during the planned client-work
pause. The inspected background paths preserve old-reader-compatible business
formats: quality retention does not promote schemas 1/2/3 to 4, escalation adds
only an event payload field accepted by the old readers, and notification/stamp
paths do not invoke the incompatible domain producers. This is not a database
freeze or evidence that old client requests have drained. The affected devices
must remain stopped until admitted after upgrade.

Build 29 version/source metadata can be reviewed before the pause with backend
deployment explicitly pending and artifact construction refused. After deployment,
only the measured backend/readback metadata should change before the protected
artifact run. This reduces work during the pause without bypassing source or
backend checks.

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
3. Deploy the reviewed complete Function fleet and Rules under the agreed window,
   preserving approved identities, access and the prepared indexes. Read back actual
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

## Owner-reported client pause

After being asked explicitly about all current users, including offline phones,
the owner confirmed: "All users are stopped and will wait until the update is
ready". The agent recorded that answer at `2026-09-21T14:41:14Z`; this is the
observation time, not an invented message timestamp or exact pause-start time.
The owner was told to keep users paused until readiness is confirmed.

This supplies the operational cohort-pause attestation. It does not establish
automated device enumeration, network or pending-command drainage, or a database
freeze. Compatible background processing can continue. The release checks,
deployment readback, signed artifact, retained-data upgrade and required runtime
qualification still have to pass before workflows are resumed.

## Final review corrections

The bot review of `654cc40d` identified that a coherent historical Build 28
approval/CI tuple could still authorize newer source. This was reproduced for
the Build 29 baseline, its descendant and a divergent descendant of the old
baseline. Historical Build 28 delegation is now bounded above by its actual
signed source `fc5825875293ac703449002a49799d70a6bf5351`, using Git ancestry.
The actual historical approval and CI remain valid; Build 29 uses its separate
source boundary and approval contract.

A separate deployment rehearsal found that the pinned Functions SDK and Firebase
CLI submit `maxInstanceCount: null` with that field in the update mask for all
19 previously uncapped source definitions. That is a reset request, not proof
that the live limits will be preserved. A fresh read-only observation completed
at `2026-09-21T14:43:54.1909997Z` confirmed a service limit of 20 on all 19 live
services; the 15 older services also have revision limits of 20, while those
fields are absent on the four V2 services.

The source now explicitly declares `maxInstances: 20` on each of the 19 endpoint
definitions. The bounded source verifier admits either the preserved historical
all-omitted configuration or the complete literal-20 successor configuration.
The historical 15-existing/four-new comparison remains historical. The new
deployment must separately prove all 19 existing services retain their effective
limits, identities, access and other governed settings. No capacity increase or
historical reset permission is inherited by this preparation.
