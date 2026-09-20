# Remaining business functions: source review and repairs

Date: 20 September 2026. Starting HEAD: `d038797f9a2d3bd0126d311416acec4148506a67`.

The three supplied HTML audits were treated as evidence to verify against the working tree, not as instructions or proof that every reported defect still existed. This pass preserved the extensive uncommitted domain repairs already present. It adds source repairs and local verification; it does not certify deployed behaviour, a release artifact, or physical-device acceptance.

## Owner decisions applied

- Physical jobs may close with unresolved diary blockers. Notes remain available for follow-up and reasoned disposition; their review never reopens physical work.
- Administratively closed issues marked `stillRelevant` remain in management attention independently of the report period. The existing audited end-relevance operation removes that relevance explicitly; technical resolution is not invented.

## Function 16: asset register and physical component identity

| Finding | Current disposition |
|---|---|
| F16-01 modern replacement evidence | Existing schema-4 evidence admission retained and covered by the current backend suite. |
| F16-02 cross-class node identity | Existing mutation/replay class binding retained. |
| F16-03 populated-class migration mapping | Existing restriction against changing operational meaning retained. |
| F16-04 installation chronology | Existing future/replacement-order checks retained; actual installation-date changes now also respect reciprocal predecessor/successor chronology. Unchanged dates do not block unrelated detail edits on legacy lineage, and linked dates cannot be erased. |
| F16-05 historical installation correction | Added Admin correction of manufacturer, model, serial and actual installation time. The original component identity, tag, definition, ownership, service state, lineage and current replacement are preserved. Version review, chronology checks and content-bound audit/replay apply. This does not reactivate a replaced component. |
| F16-06 grouping-node installation | Existing physical-component kind admission retained. |
| F16-07 provisional tag claims | Existing strict reader accepts legitimate provisional/unassigned ownership and rejects unknown authority values. Updated an obsolete regression that required rejection of a legitimate state. |
| F16-08 reviewed tag owner version | Existing owner-version check retained. Current Dart request fixture now includes the new optional review field; the installed-client legacy fixture remains unchanged. |
| F16-09 interrupted ordinary registry commands | Added native durable original-account request storage, exact-envelope retry, receipt validation and a visible saved-change route. One unresolved registry operation blocks a fresh UUID from bypassing an uncertain creation/replacement. A typed post-replay business refusal releases the slot while retaining its details. |
| F16-10 second transfer refusal | Existing second-attempt error handling retained. |
| F16-11 displaced tag-source audit | Existing replay evidence binding retained. |
| F16-12 retired selector membership | Existing preservation of the selected historical identity retained. |
| F16-13 malformed population | Existing strict/fail-closed population behaviour retained. A partial valid-row browser with a dedicated malformed-record review queue has not been added. |

Registry durability is admitted only when the backend advertises `assetRegistry.durable.v1`. The source capability is implemented but has not been deployed in this pass. The browser has no durable registry journal and therefore refuses these writes. Historical same-account recovery after role loss and supervised unavailable-account/off-device recovery need further work; saved evidence is retained rather than reassigned or silently abandoned.

## Function 14: reports and fleet status

| Finding | Current disposition |
|---|---|
| F14-01 unknown condition | Existing explicit unknown/unreadable condition treatment retained. |
| F14-02 unreadable planned execution | Existing coverage accounting retained; native report coverage now follows the execution stream rather than a one-shot future. |
| F14-03 legacy date representation | Existing complete report-only loading and supported legacy date treatment retained. |
| F14-04 serial Inner Cover identity | Existing linked-job association retained; maintenance ticket filtering now also uses the retained historical Inner Cover association. |
| F14-05 current obligations vs period | Open quality warnings, charge-monitoring requests and critical alarms remain current obligations outside the historical date window. Completed populations retain period filtering. |
| F14-06 period event semantics | Existing period-bounded reopen counts retained. Dossier membership still uses the broad start/end cohort; complete historical action/closure throughput and active-episode population separation are not claimed complete. |
| F14-07 live abnormality input | Existing reactive source retained. |
| F14-08 hidden due-evidence warning | Incomplete due evidence is disclosed independently of the selected executive section. |
| F14-09 unbounded metric flex | Removed the expanding spacer from the unconstrained metric layout. |
| F14-10 missing selected identity | Preserve the requested selection and refuse an unavailable identity instead of broadening report scope. |
| F14-11 reproducibility | Each export receives a distinct UUID, including exports at the same instant. Provenance explicitly states independent source updates and no certified common cutoff. A reproducible source-version manifest/common snapshot is still open. |
| F14-12 physical identity/continuation | Tables retain stable asset identity and repeat identity on continuation chunks; retained cover associations are labelled. |
| F14-13 unresolved relevance | Dedicated retained-follow-up population is independent of the historical window and respects the selected equipment identity. Explicit end-relevance remains the governing exit. |
| F14-14 source isolation/scale | Still open: the aggregate report depends on all source families, section selection is not a query plan, and some complete report populations remain unbounded. A missing source prevents an authoritative aggregate rather than being silently treated as empty. |
| F14-15 plant days | Report periods are half-open plant-calendar days in Asia/Kolkata (UTC+05:30); PDF event formatting uses that timezone. Broader application-wide timezone conversion is outside this repair. |

The pure report builder was separated from provider orchestration without changing its public entry point. This is a responsibility extraction, not a claim that the report source architecture has been redesigned.

## Knowledge governance, diary, audit, cleanup and notifications

| Findings | Repair and remaining limit |
|---|---|
| KG-01 / KG-02 | Untouched embedded seeds cannot outrank governed version-one rows; authoritative full pulls prune only untouched absent seeds. Dirty drafts survive. A withdrawn web catalogue does not resurrect embedded guidance. |
| KG-03 | Typed preset editing preserves field keys, types, units, options, sources and evidence requirements rather than reducing fields to labels. Structured preset changes appear in review diffs. |
| KG-04 / KG-05 | Imported rows bind the reviewed source version and exact preimage. Strict reader/save admission rejects malformed fields and duplicate codes. CSV lists use JSON arrays, preserve commas and retain documented legacy semicolon input. |
| KG-06 | Explicit cloud acceptance checks the reviewed cloud version and exact local draft within the local transaction, archives the displaced draft, and adopts the authoritative row. Cloud publication and local readback are checked separately. |
| KG-07 | Missing metadata is labelled unverified, including native governed rows with no metadata. UI does not claim an edition certificate. A row-membership/version edition manifest is still open. |
| JD-01 / JD-04 | Post-closure notes and reasoned follow-up disposition are available without changing job closure. Open/carried-forward blockers cannot drop their follow-up flag. |
| JD-02 / JD-03 | Consecutive offline edits preserve the original reviewed server version. Server transaction compares that baseline; missing edits cannot become creates and tombstoned/conflicting entries are refused. |
| JD-05 | Rules bind parent/equipment/module scope, shape, actor, enums and follow-up invariants. The same transaction must carry an audit whose before/after maps exactly match the document transition. |
| JD-06 | Removed the eight-note presentation cap; malformed diary data produces a visible failure rather than silently disappearing. |
| AU-01 | Governed knowledge row and standard audit are written in one transaction. Legacy dirty auto-push no longer publishes an unreviewed row; it retains the draft unless the server already has the exact accepted content. |
| AU-02 | Diary audit records retain complete note/context snapshots, with atomic local capture and exact remote before/after binding. |
| AU-03 | SI can read the scoped knowledge audit population; retrieval does not silently fall back to a partial local history. Timeline displays actual differences. Historical seed audit format is preserved and is not migrated or represented as a certified edition. |
| RC-01 | Existing retained-continuation purge dependencies preserved. |
| RC-02 | Purged identity fences added to legacy directive/template creates and maintenance ticket creation, including nested burner directive creation. |
| RC-03 / RC-04 | Existing original-review-proof adoption and terminal reset-request replay repairs preserved. |
| NT-01 | Known zero/partial/ambiguous ordinary delivery outcomes now require Admin adjudication and retain a review-required disposition. Per-recipient ordinary retry and a named resolution UI are still open; this pass does not claim delivery recovery is complete. |
| NT-02 | Existing current-obligation checks retained; delayed escalation wording explicitly describes the historical observation. A final database-to-FCM race remains. |
| NT-03 | Existing five-minute transport TTL retained. Transport acceptance is not device delivery or human acknowledgement; physical-device delivery qualification remains required. |

## Verification and source governance

- Full Functions unit run: 77 suites, 2,195 passed; 20 emulator-only suites / 217 cases skipped in that unit invocation.
- Firestore Rules emulator: 238 passed, including post-closure diary, stale-base refusal, exact audit state binding and purge fencing.
- Asset-registry Firestore emulator: 25 passed after updating reviewed-owner/date fixtures and repairing unchanged-date compatibility.
- The final backend suite includes three added chronology regressions: unchanged-date detail edits with an undated predecessor remain possible; date removal/change without proved history is refused. The intentional historical-fixture capture remains skipped.
- New native registry/knowledge recovery and cross-runtime request tests: 12 passed. Includes process/storage reopen, same-account ownership, ambiguous duplicate prevention, cloud/local changes after review, draft preservation, seed authority and CSV semantics.
- Full Flutter suite: 3,075 passed, one skipped. No test failures remain in the completed full run.
- Full Flutter analyzer: no issues found.
- Whitespace validation passed. No source-control commit, push, production mutation, APK or AAB was created by this pass.

A-02 growth was reviewed file by file; existing responsibility restrictions remain, three newly detected surfaces have explicit ownership and regressions, and the report builder/diary review were extracted. A-03 tracks 619 operations and 2,166 sites across the existing 77 classified surfaces. A-04 retains 55 fields and its extension policy, while inheriting the current 109 A-05 decoder surfaces. Rules bytes were normalized to the repository-required LF before hashing, preventing Windows-to-CI hash drift. Only derived current-source release bindings were refreshed for pending Rules/index deployment. Historical deployment receipts, signed approvals and custody hashes were not rewritten.

## Remaining release work

This source pass is not a claim that all three audits are closed. The open report/query architecture, edition proof, period-throughput semantics, registry recovery limitations and ordinary notification adjudication items above remain explicit. Coordinate backend capability, Rules/index rollout and installed-client compatibility before activating new write paths. The exact final source still needs independent PR review, CI/release gates and representative physical-device in-place upgrade/business-flow validation before distribution.
