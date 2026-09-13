# Reviewed Firestore Rules deployment evidence — 13 September 2026

The pre-build module-reopen repair requires a narrow Rules change: a currently approved supervisor can read their own immutable server reopen audit by ID. The previous backend closure protocol admitted only deployments whose Rules were already exact. That protocol cannot truthfully certify deployment of changed Rules by retaining its old no-mutation flags.

`tools/release/reviewedFirestoreRulesDeployment.js` adds an offline verifier for an explicitly approved successor Rules-only deployment. It performs no deployment, approval or live collection. Historical approvals and receipts keep their original no-Rules-mutation meaning; this change does not amend or relabel them.

## Required evidence

The new path requires the existing exact-source, immutable approval and five-job post-merge CI authority. Its additional declaration binds the production project, default database, prior Rules identity, new Rules bytes from the exact Git source, complete index/field-override inventory and the approved command checkout. It names a future command evidence file without putting a circular future digest in the approval.

The pre-approval and immediate-before readbacks must be actual OBSERVE receipts. The old active Rules are the sole permitted difference. Every other source, Rules identity, index readiness and field-override check must be explicitly true; missing or null checks cannot pass. No index deployment is admitted.

The command receipt must retain the exact `firestore:rules` invocation, actual zero exit, unambiguous raw CLI JSON, start/completion times, and clean exact-main source observations before and after execution. Its private checkout path is represented in public evidence only by its digest. The raw result must come from the command; copying an expected success object is not evidence.

The declaration also binds a sealed, completed clean installation of the locked Firebase CLI. A new exact-main checkout must begin with absent CLI dependencies and no ignored or untracked source inputs. The actual installation uses the selected absolute Node and npm entry point, `npm ci`, disabled scripts, copied local package links and disabled global module lookup. The source tree and exact CLI package, lock and npm configuration bytes are bound, including the source authority for the local compatibility adapters and root package. The actual installation output, exit status and timed input/installer measurements must precede the separate approval decision.

The installed dependency tree is measured in full, including copied local packages. Node executable bytes, version and path digest are recorded independently before installation and checked again afterward. Npm's measured tree covers its containing installation `node_modules`, including sibling packages, or its standalone package with absent ancestor lookup directories. Unmeasured higher npm or CLI dependency lookup directories, `NODE_OPTIONS`, `NODE_PATH`, escaping links, unsupported filesystem entries and files changing during measurement are refused. All Node invocations use `--no-global-search-paths`.

Fresh measurements of the same approved source, Node, npm and installed CLI tree must bracket the Rules command. The first must follow the immediate Rules readback and finish before dispatch; the second must follow command completion and precede closure. This closes PR #367's finding that clean tracked Git files and command text alone could admit altered ignored deployment tools. The original defect was reproduced by modifying the ignored installed Firebase entry point while the former verifier continued to pass.

The final STRICT readback must begin after command completion and prove the active Rules bytes and complete unchanged index/override inventory. The collector now records collection start before any source or network read, as well as completion afterward. The verifier binds those times to immutable approval custody and the closure time, including sub-millisecond ordering, and rejects future or reversed intervals.

Only this fully verified path admits true Rules-deployed/security-Rules-mutated flags. The existing invoker-IAM checks, service-account restrictions, App Check boundary, business-data restrictions and separate artifact/device/promotion requirements remain enforced.

## Verification boundary

Tests use synthetic observations with real Git objects, immutable test approval/CI custody, the actual collectors' adjudicators and the complete production source-authority verifier. They are clearly marked as synthetic and do not establish a real deployment. Negative cases cover scope, target, source, checkout, raw output, custody, chronology, Rules/index drift and false mutation claims; their positive controls must pass before a refusal is counted.

Before the runtime-identity follow-up, local verification passed all 102 tests across the complete staged source-authority, Rules/index collector and current-runtime-authority suites, with no failures or skips. The original companion helper copies passed 19 separate offline tests and Node/embedded-JavaScript/PowerShell syntax checks. These earlier counts do not certify the follow-up. Its additional tests measure actual local files and process execution, and exercise stale installations, changed Node/npm/CLI bytes, injection or fallback paths, invalid installation results and timing boundaries. Updated results are retained under `output/build28-release-20260913/` in the isolated preparation checkout.

Historical completed evidence is checked offline from its immutable installation and command witnesses; verification does not read the former operator's Windows paths or claim that today's local runtime proves yesterday's command. This is operational provenance, not hardware attestation or a whole-machine supply-chain assessment. Synthetic fixtures are not an actual npm installation or deployment. The full generator, production command and production closure assembler remain unexecuted with operational inputs.

The companion operator helpers are prepared locally and remain unexecuted. Actual current-source preflight, a concrete deployment decision, immutable custody, execution and final readback are still required. This source change does not authorize a deployment or create a release-ready APK.
