# Coordinated release plan — 27 September 2026

This is preparation for one reviewed production candidate, followed first by a controlled Play internal-track update. It records neither a merge, a build-number allocation, a deployment, an App Check activation nor distribution approval. The reviewed business-source baseline is `c76cfa38`, whose ten required checks passed. Public policy/contact UI and release-tool preparation are subsequent changes and need their own final-head review and checks.

## Decisions already established

- Preserve the production package, signing continuity, installed database and pending submissions. Do not clear data, uninstall, replace the key or reuse Build29.
- The publisher/contact details are confirmed in [Play readiness](PLAY_DISTRIBUTION_READINESS_2026_09_27.md). Public privacy, support and account-deletion request pages are now hosted and read back; accessible in-app links are implemented, including before approval. See [public support validation](PLAY_PUBLIC_SUPPORT_VALIDATION_2026_09_27.md). Candidate/device acceptance remains separate. The request route describes actual handling; access suspension is not deletion.
- Use the existing protected production-artifact workflow, independent verification and private custody. Preserve historical approvals and receipts as historical evidence.
- App Check client activation and backend enforcement are separate steps. Collect signed-client evidence before enforcing. No debug attestation provider or debug token belongs in a release.

## Compatibility that determines the order

The current client sends actor/project-bound retained commands for abnormality catalogue changes, legacy template changes and existing execution work. The current Rules deny their older direct-write routes: `abnormality_types` and `job_templates` create/update, and `job_executions` update. The client still uses governed published assignment for new executions. See [CF01 validation](CF01_IMPLEMENTATION_VALIDATION_2026_09_27.md), [Rules](../firestore.rules) and [retained command handling](../functions/src/maintenanceWorkflow/retainedQueueHandlers.ts).

Consequently, deploying these Rules while Build29 users continue ordinary affected edits is not a transparent mixed-version rollout. Conversely, shipping the new client before its V2 handlers exist can strand new submissions until the backend is ready. A green DEV run establishes neither deployed parity nor safe use of old clients against new producers.

The current production construction gate requires exact deployed backend/Rules evidence **before** building. Under that existing policy, the concrete sequence is:

1. Complete preparation and rehearse the exact deployment/build/readback sequence before starting an operational pause.
2. Agree the affected-user roster, pause window and who confirms users have stopped writes. The historical Build29 pause decision is not confirmation of a new window. Include background sync and other supported clients; a stopped screen alone is not a drained client.
3. Capture private before-state evidence and preserve pending local work. Deploy the reviewed Functions cohorts, read them back, then deploy the reviewed Rules and verify Rules/index parity. Preserve IAM and indexes unless a separately reviewed measured change is required.
4. Record actual deployment evidence, complete the exact-source construction gate and build/finalize the candidate once.
5. Admit the small internal-test cohort through an in-place update, verify retained data and business access, then resume only compatible clients. Keep incompatible clients out of affected writes until their update is confirmed.

The pause includes artifact construction and Play processing; no reliable duration is established. **Do not start it until that operational consequence is accepted.** If this duration is unacceptable, prepare a separately reviewed construction-only authority change or proven compatibility bridge before cutover. Neither exists in this plan. Do not silently bypass the current parity gate or temporarily reopen CF01 write bypasses to shorten the window.

## Saved work and recovery

The new native client preserves an unbound old queue row as `legacy-origin-unknown` review evidence; it does not invent its original account from whoever is signed in. Known bound commands keep the original actor, project, payload and request ID through retry and acceptance. See [retained-row service](../lib/core/services/retained_row_mutations.dart) and [retry validation](PR382_RECLAIMED_RETRY_AND_HANDOFF_2026_09_27.md).

Before upgrade, record a privacy-safe inventory of pending work and its known provenance. Do not bulk-flush Build29 queues under the currently signed-in account merely to obtain a zero count. Do not discard held work, rewrite creator identity or manufacture a successful sync. After upgrade, distinguish accepted, still-pending and review-only records; preserve the original local evidence for supervised resolution. The existing Android ownership/restart tests are useful, but are not a substitute for upgrading an actual representative old installation.

The candidate acceptance must cover preserved session/database, a previously saved command, account switch refusal and original-account retry, missing-origin review without loss, ordinary reads, Quality/RA, maintenance/planned work, and a fresh production-authenticated command. Use authorized test records for mutations. A release-channel downgrade or restoring an older backend must not overwrite newly accepted business history or invalidate immutable receipts; stop writes and preserve evidence before a rollback decision.

## App Check preparation and staged enforcement

Source facts:

- [Client bootstrap](../lib/core/security/app_check_bootstrap.dart) defaults `CRM3_APP_CHECK_ENABLED` to false. When explicitly enabled, Android release builds choose Play Integrity; release Windows is refused rather than using a debug provider. Release web requires its configured reCAPTCHA site key.
- [Callable security](../functions/src/callableSecurityConfig.ts) defaults `CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK` to false and leaves token consumption disabled. The existing fleet campaign explicitly deploys that false setting. Product-level Firestore enforcement is separate.
- [Production builder](../tools/release/New-ProductionArtifact.ps1) now requires an explicit, approved Build30 client choice and applies the same `CRM3_APP_CHECK_ENABLED` define to APK and AAB. The package verifier revalidates the source-bound choice and backend setting. Historical Build29 keeps its absent/default-false setting. This records compilation, not successful attestation; enabling server enforcement alone would not fix an unprepared client.

Recommended preparation is to make the final Android candidate capable of sending production Play Integrity tokens, with enforcement unchanged during initial verification. First confirm the Firebase Android registration, actual Play-delivered signing SHA-256, linked Cloud project and supported installation channels. Do not substitute the upload certificate for the delivered app signer. Firebase documents that licensing verdicts depend on Play installation/update, and recognition/device settings differ for Play-only and mixed distribution; choose settings against the measured supported roster, not the assumption that every existing installation came from Play. [Official Play Integrity setup](https://firebase.google.com/docs/app-check/android/play-integrity-provider).

After the signed internal-track client demonstrates valid tokens and successful supported operations, review request metrics and the remaining older-client population. Enable callable enforcement through a separately reviewed deployment and product enforcement through the appropriate Firebase controls, with before/after observations. Missing or invalid tokens are rejected once enforced; product enforcement can take up to 15 minutes. [Callable enforcement](https://firebase.google.com/docs/app-check/cloud-functions), [product enforcement](https://firebase.google.com/docs/app-check/enable-enforcement).

Do not add token-consumption replay protection or new IAM roles as part of basic activation. The app's immutable business-command replay is a different mechanism. Retain the existing broad-distribution App Check gate until its signed-client and enforcement evidence is complete. Internal testing is not a claim that that gate has passed.

## Concrete source-tool preparation before allocation

The source preparation addresses these measured limitations without rewriting historical approvals:

| Area | Current limitation | Necessary preparation |
| --- | --- | --- |
| CI identity | The old `app-shell integration` job name rejected current successful business CI. | Current campaign/Build30 admit only the exact `shell + business integration` five-job set; Build28/29 retain their historical set. |
| Successor backend authority | Only separately fixed Build28/29 protocols existed. | New protocol admits only Build30, requiring fresh matching owner/source/scope/decision/CI and Git policy/pubspec/ledger evidence. Build31 and reuse of Build29 authority remain refused. |
| Private cloud custody | Builds28/29 use fixed approval objects. | New bounded source support requires allocation baseline → fresh approval → artifact source ancestry, identical allocation-ledger bytes and exact approval bytes in the artifact. The finalizer still requires exact clean live-main source. Never reuse an old approval/prefix. |
| Client App Check | A new build silently inherited the disabled default. | Explicit approved choice, shared APK/AAB define, pinned backend setting and independently checked manifest evidence are now required for Build30. Contradictory settings are refused. |
| Exact-artifact acceptance | Existing Build28/29 owner contracts describe ADB in-place installation and read-only validation. They do not establish Play delivery or business-flow acceptance. | After current Console, channel, artifact and retained-work facts are known, select the successor's channel-specific acceptance scope. Preserve historical contracts and receipts; do not turn them into Play proof. |

The device-acceptance helper is **not a pre-construction blocker**: its current-candidate runtime checks run only after completed finalization and a claimed `runtimeValidationPassed` result. Candidate construction has its own exact-source/backend authority gate. A separately authorized internal-track upload can precede device acceptance; pending acceptance must remain explicitly unproved, rather than creating a successful receipt in advance. This distinction does not remove the current distribution restrictions or supply an internal-track release decision.

Actual Play acceptance needs a binding from the finalized AAB and its source to the internal-track release, delivered package/version and measured app-signing certificate. It also needs in-place session/database continuity and before/after accounting for saved work, including unchanged pending envelopes and legitimate review-only records, followed by the authorized business checks. An `adb-install-r-in-place` result is not Play-delivery evidence; neither is a matching sideloaded APK alone. Do not discard or bulk-flush saved work to satisfy the old read-only helper's zero-pending requirement. Determine the concrete successor acceptance contract from the actual candidate and supported installation before implementing a new validator; no such acceptance or new framework is asserted by this preparation.

Keep the build ledger, source version, current release authority and every historical approval untouched until the actual candidate identity is allocated. Prepare and test tool support first. Read the highest consumed Console version and remote reservation/built tags before choosing an unused successor; `30` is the recorded minimum, not a reservation or assurance that it is currently free.

### Fresh records required by the bounded protocol

These are schema requirements, **not completed approvals**. Tool preparation creates none of these files and makes no deployment or distribution decision.

- Backend decision: fixed `build30-current-source-backend-deployment-approval.json` and `build30-current-source-backend-ci.json`, with an independent expected build of 30, coherent source generation 29 or 30, exact merged source/PR/five successful main jobs, and immutable Git custody after the decision. A separately pinned `build30-backend-owner-authorization.json` must have schema 1/type `source-specific-backend-owner-authorization`, actual owner instruction/reference/recording identity and UTC chronology, intended build 30, exact project/region/source commit/tree/functions object, and an `approvedDeployment` object identical to the decision. The historical owner instruction alone is refused. Backend source precedes its approval commit; the later artifact source can then include that evidence without a self-hash cycle.
- Client choice: `production-release-policy.json.appCheckBuild` must contain boolean `clientEnabled`, matching `androidProvider` (`playIntegrity` or `disabled`), fixed `approvalFile` `release/approvals/build30-app-check-client-approval.json` and its SHA-256. That fresh schema-1 approval/type `governed-app-check-client-build-approval` binds intended build, release/reservation, project/application, real approver/reference/UTC decision, client/provider choice, pinned backend receipt hash/source and boolean `serverEnforcementAtBuild`; `enforcementChangeAuthorized` must be false. The source archive contains the approval; the package independently checks the same bytes and emitted define. It explicitly reports token validation as unproved by construction.
- Custody approval remains separate from backend/client choice. A fresh `build30-private-cloud-custody-approval.json` binds the already committed `sourceBaselineCommit`, exact `candidateLedgerGitBlob`, build/release/reservation/campaign and approved private-storage controls. That baseline precedes approval custody, which precedes the artifact source; all three must retain the exact ledger blob and the artifact must retain the exact approval blob. Finalizer inputs `PrivateCustodyApprovalCommit` and `PrivateCustodyApprovalSha256` select that record without weakening its exact-main/source check. This ordering avoids asking a commit to contain its own hash. Retention/storage-charge acceptance needs actual owner authorization; adding a validator does not supply it.

The same App Check validation runs in construction-authority preflight **before** the workflow reserves a build number, again in the builder, and again against the archived bytes during package verification. Missing metadata must fail before avoidable number consumption. These are tool-level checks; no candidate number has been allocated and no production artifact built by this preparation.

## Reviewed tool sequence

These are execution entry points for the release operator, not commands run by this document. Substitute actual reviewed values; do not invent source hashes, decisions, receipt timestamps or successful statuses.

1. Review final source and fresh PR checks, then merge only when authorized. The production workflow requires the exact merged live `main` commit; rerun the required post-merge gates on that commit.
2. Read-only preflight:

   ```powershell
   pwsh -File tools/release/Test-ProductionReleasePolicy.ps1
   pwsh -File tools/release/Test-BackendAuthority.ps1
   node tools/release/collectFirestoreRulesIndexesReadback.js --repository-root <repo> --project-id crm3-baf-ops-b8638 --output <private-before-rules.json> --observe
   node tools/release/collectFunctionFleetRuntimeIdentityReadback.js --phase preflight --repository-root <repo> --project-id crm3-baf-ops-b8638 --region asia-south1 --output <private-before-fleet.json>
   ```

   An observation reporting source/live differences is useful before-state evidence, not a deployment pass. Check exact deployed bundle/configuration, Rules/indexes, IAM and recoverability; historical fleet receipts alone are insufficient after separately authorized production hotfixes.
3. Use `Invoke-FunctionFleetRuntimeIdentityCampaign.ps1` with the exact project confirmation, `-PostMergeRunId`, private external `-EvidenceDirectory` and `-PreserveExistingIam`. Its phases are `Preflight`, `Provision`, `DeployCallables`, `DeployEvents`, `DeployScheduler`, `Finalize`. Review the measured cohort and prepared successor authority before mutation. The preservation option must refuse required IAM drift; do not use `RestoreEditor` as an automatic recovery step. Do not delete an existing `.env` file to make the tool proceed; use the reviewed clean deployment checkout and preserve original environment custody.
4. The reviewed Rules command is the pinned local Firebase CLI targeting **only** `firestore:rules` with the exact project, noninteractive JSON output. `reviewedFirestoreRulesDeployment.js` verifies its evidence; it is not a deployment command. Bind before-state, actual command outcome, after-state and unchanged indexes. A nonzero deployment response can still coincide with a live change: inspect first, retain the real outcome, and do not repeatedly roll production backward/forward just to obtain a successful receipt.
5. Once actual source/backend evidence and candidate records are complete, run `Test-ProductionReleasePolicy.ps1 -RequireArtifactConstructionAuthority`. Its refusal now is expected, not a reason to weaken it.
6. Dispatch `.github/workflows/production-artifact.yml` on `main` with its actual inputs `commit_sha`, `release_id`, `reservation_id`, `approval_reference`, `build_number`. The protected workflow atomically reserves the build number and invokes the CI-only builder. Do not invoke `New-ProductionArtifact.ps1` locally or substitute verification/CI-package APKs.
7. Use `Finalize-ProductionRelease.ps1` with the exact successful run, PR, artifact name and approved independent custody destinations. It verifies the package/sidecar and custody before creating the built tag. Finalization produces a verified **non-distributable** artifact; it does not approve a Play upload or rollout.
8. After the appropriate release decision, upload the exact finalized AAB to Play internal testing. Do not rebuild it for later promotion if its source/configuration remains accepted. Verify the delivered package/version/signer and retained-data update on a representative supported installation, plus Google sign-in, approval, Firestore/callables, notifications and App Check metrics. Only then consider wider testing/distribution and enforcement decisions.

## Remaining concrete inputs

- Current Console identity, highest used versionCode, signing/lineage, app-content tasks and internal-track eligibility; the 20 September observations are historical.
- The affected old-client roster, pending-work review and acceptable pause window. If the pause cannot include build/Play processing, decide and review the alternative construction/compatibility approach before deployment.
- Supported production platforms and installation channels for App Check registration/enforcement. Do not infer that only the connected Android phone needs access.
- A real Google-sign-in reviewer arrangement with appropriate approved access and signed-client verification of the now-hosted public routes. The owner must maintain the documented request-handling procedure.

There is no need to repeat completed business audits solely because older notes contain unfinished historical checklist items. The public routes and bounded release-tool preparation have passed the local checks below. Next come fresh combined-head CI, live Console readback and one coherent source/backend/client execution decision. New concrete failures require correction; historical receipts remain evidence of their own builds.

## Source preparation verification

- Public UI and related shared-client source: full Flutter **4,107 passed, one existing skip**, clean full analysis, and corrected focused help/design/deferral tests **42/42**. See the separate public-page readback note above.
- Canonical audit **153/153**, including **434 retained hash pointers**; evidence taxonomy and ordinary production-policy verification passed. Build29 remains unapproved for distribution. No current release/approval/ledger records changed.
- Explicit client App Check, manifest tampering and pre-reservation file/digest validation: **20/20** pure host tests passed. No tokens were minted and no enforcement setting changed.
- Private custody: all **94 distinct cases** passed across the combined run and a targeted retry. The combined run passed 93 and its large positive integration fixture hit a 30-second child-process timeout on the busy Windows host; only that synthetic test's bounded timeout was raised to 90 seconds. The exact-main positive fixture then passed in 31.9 seconds. Historical controls, all refusal cases, caller binding and recomputed-receipt tamper checks are covered; no cloud calls occurred.
- Deployment campaign tests: **14/14** passed. Focused successor source-authority tests passed **18/18**, covering all 13 new Build30 cases and five representative historical/generation cases. The long full historical Node run was deliberately interrupted on this Windows host; its partial source-authority output is not counted as a pass. The complete suite remains in the existing CI command, now also including both new App Check and successor-custody files.
- Independent reviews found and corrected the initial custody self-hash/caller conflict, then found no remaining blocker in the final scoped source review. No test or gate was weakened to accept a candidate.

These results support source review, not current-head CI, artifact construction, actual Play delivery or business-data acceptance. The new combined commit must pass CI before advancing.

### Subsequent CI and review follow-up

The full `test:distribution-readback-custody` command completed on commit
`718d5da019b3ed1e1fe578f8e27e61e189985714`: **569 tests passed, zero failed** in
[the Cloud Functions host job](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/36329466829/job/108648514818).
This closes the previously incomplete local historical-suite run for that commit;
it does not establish CI acceptance for later source changes.

The same commit's bot review identified two admission defects: superficially
reformatted historical instructions could pass the fresh-owner check, and
placeholder App Check approver/reference values could pass the identity check.
The follow-up compares normalized text only to detect historical reuse, while
preserving exact committed instruction and excerpt bytes, and rejects unfinished
approval identities without rejecting legitimate names that share a prefix.
Regression coverage must exercise committed custody and repository preflight
with recomputed hashes, retain genuine fresh/valid controls, and preserve
Build28/29 behavior. Fresh CI and review remain required after these repairs.

Local repair validation passed **18/18** focused source-authority tests and
**23/23** App Check tests. The latter includes 62 malformed/placeholder values
through the real repository preflight with current hashes, plus six genuine
identity controls. Original-defect and invisible-formatting failures were
reproduced before repair. Independent review found no remaining concrete
finding; syntax and diff checks passed. No approval, ledger, production
configuration, deployment or artifact was changed by this follow-up.

The next review reproduced a punctuation-only reuse of historical owner wording
and separator-free App Check placeholders. The comparison now treats punctuation
and symbol separators consistently, without changing retained evidence bytes or
exact excerpt/hash validation. App Check rejects `TODOAPPROVER`, `TODO123` and
`fixture approval`, with genuine Todo-prefixed names retained. Focused validation
passed **26 source-authority tests**, **23 App Check tests** (78 coherent-hash
negative identity cases and seven genuine pairs), and **18 CodeQL evidence-verifier
tests**. Independent scoped review found no actionable defect.

At `67b78327`, all five release-gate jobs passed; the separate Java/Kotlin CodeQL
job failed before extraction because the runner lacked the CMake 3.22.1 Ninja
executable used by JNI cleanup. Its repair explicitly provisions and executes
CMake/Ninja before the unchanged traced clean/build. Local syntax and extraction
contract checks passed; fresh Linux CI is still required. Main protection's
obsolete Android shell job name was corrected to the current shell-plus-business
job, retaining all five required GitHub Actions checks, strict mode, app IDs and
all other protection settings, with exact readback. No check was removed.
