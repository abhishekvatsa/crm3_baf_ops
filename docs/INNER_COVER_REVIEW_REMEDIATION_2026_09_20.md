# Inner Cover review remediation — 20 September 2026

Status: the concrete defects identified in the follow-up review are repaired in the working tree based on `b35df6bd`. This record describes source verification, not a deployed backend or a released Android artifact. Existing uncommitted work in other domains was preserved.

## Corrections

- Transactional custody checks examine all Base-scoped linkage history and surviving installed-profile claims. Closed history cannot hide an active claimant. LINK, TRANSFER, REPLACE and both SWAP destinations reject conflicting or malformed custody; ordinary commands do not choose a winner or repair damaged business records.
- “Start inspection” explicitly defaults to `underInspection` when reacceptance is required and that transition is supported.
- Profile and assignment batches preserve Firestore cache/pending-write metadata. Vacancy and pairing require complete, server-confirmed, reciprocal custody evidence. Missing, orphaned, duplicate or conflicting claims produce unverified totals. Healthy rows remain readable.
- Base and Pool entry points share the same pairing checks. Open forms respond to newly incomplete or changed evidence and recheck their reviewed state before submission.
- Both cover and Base history distinguish physical removal from administrative recording. Decoding rejects impossible removal chronology and retains compatibility with older records that lack an explicit physical removal time. The timestamp inventory includes the new optional field.
- Pending registrations are recoverable without a server profile and remain bound to their original approved account. Account changes during asynchronous listing or readback withhold results.
- Accepted replacement/swap commands confirm both affected cover profiles; fabricated registrations also confirm each affected donor once. Failed readback preserves acceptance for later checking without redispatch. Later legitimate revisions remain valid current views.
- Receipt revision validation, replay normalization and same-ID payload rejection protect the original durable request. Raw fabrication text is validated before conversion.
- Widget fixtures now supply the providers used by the screen. Bulge evidence loading no longer appears as confirmed availability of evidence.

## Verification

| Check | Result |
| --- | --- |
| Backend build, emitted output, callable and notification inventories | Passed |
| Full Functions Jest run | 70 suites / 1,910 tests passed; 17 environment-gated suites / 180 tests skipped in that run |
| Focused Inner Cover backend suite | 103 tests passed |
| Inner Cover and adjacent integrity Firestore emulator suites | 13 tests passed, including missing-assignment/history and concurrent-link regressions |
| Focused Flutter, model, decoder and durable-store suites | 171 tests passed |
| Flutter analyzer | No issues |
| Governed persisted decoder inventory, including timestamp inventory | Passed |
| Diff whitespace check | Passed |

The Flutter run covered `inner_cover_lifecycle_model_test`, `inner_cover_lifecycle_screen_test`, `inner_cover_lifecycle_submission_controller_test`, both Inner Cover acceptance suites, both asset hierarchy model/receipt suites, tolerant decoding and its scope contract, unreadable plant-condition evidence, and the native durable submission repository. Native recovery tests use Windows Isar with database close/reopen and controlled original/replay response ordering; these are not Android process-kill tests.

The Firestore emulator used the cached runtime, localhost port 8187 and synthetic project `demo-crm3-inner-cover`. The launched emulator was stopped and its port verified closed. No production data was used.

## Release boundary

No commit, push, deployment, APK or AAB was performed by this remediation pass. Production remediation of already damaged custody records requires the actual retained evidence and a reviewed correction; the source guards deliberately preserve those conflicts. Physical-device upgrade/business-flow validation and the separate Play distribution work are not established by these source tests.
