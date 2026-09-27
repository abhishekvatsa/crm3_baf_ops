# CF-02 — Verified sync failure isolation

Date: 27 September 2026
Workspace: `claude/dev-loop-seeding`, base `cea553648c81`, with existing local business/UI work preserved.

## What the submitted advice got right

CF-02 was reproducible. The push engine ran the business domains in sequence under one outer rethrowing catch. A batch read, remote lookup or decoding failure could escape a domain and stop later uploads. Because the coordinator awaited that push before pulling, it also skipped the canonical pull and supplemental workflow synchronization.

Existing per-record actor/business checks often already caught their own errors. They were not evidence that every account mismatch caused the batch interruption.

## Necessary qualifications

- The claim that pull can *never* overwrite any unsynced row was too broad. Ordinary maintenance upserts preserve a dirty local row and record the conflict. Authoritative deletion has an existing timestamp-based policy: newer dirty local evidence is retained, while an equal/newer remote tombstone can mark the row deleted and synchronized. This repair preserves that policy and tests both cases.
- A dirty-record conflict can be recorded while the pull cursor commits. Clean-local reconciliation failures and unreadable records have separate cursor-blocking rules. Preserving evidence does not mean every conflict stops the cursor.
- Source review found dirty-row preservation guards for uniquely identified, non-deleted business rows in all twelve canonical pull domains. The executed failed-push/pull preservation scenario specifically uses maintenance records. Knowledge catalogue metadata is replaced separately, and skipped dirty knowledge rows do not contribute to the global conflict count. Supplemental workflow projections and their command journal are separate from this ordinary-row guarantee.
- Knowledge rows have no demonstrated dependency on legacy template upload or publication. They remain an independent stage in their existing chronological position.

## Implemented behavior

Business pushes remain sequential. Each independent stage can proceed after an ordinary failure elsewhere; dependent work stays local if a prerequisite stage throws **or reports a caught record failure/conflict**.

| Work | Dependency retained |
| --- | --- |
| Maintenance tickets | Independent |
| Templates and publication | Templates, then governance; internally versions precede package pointers and publish audits |
| Knowledge rows | Independent |
| Planned jobs | Open execution edits, then diary, modules, then completed closures |
| Directives | Independent |
| Abnormalities | Type catalogue before charge abnormality events |
| Audit events | Independent, with failures reported |

Batch failures appear as bounded failure details, without inventing a permanently rejected business-record identity. Record-level rejection evidence retains its existing ownership and resolution rules. Already-started diagnostic writes are observed before releasing ownership of the run.

The coordinator proceeds to pull after recoverable push failures. Only when the canonical pull completes can it return `partial`; that result remains unsuccessful for existing save/confirmation gates. The interface, manual feedback, health panel and diagnostic export identify **Partly synced**. A subsequent clean run clears that state. Failed pull, invalid authority or unsafe storage still returns `failed`.

The run captures its account/authority generation. Sign-out, another account, revocation, role/revision change, or unconfirmed authentication/authority stops further guarded work. A sign-out/reapproval followed by the same UID cannot revive the earlier run. Typed storage and authentication failures are propagated rather than mistaken for individual record rejections. Ordinary permission denial can still be local to an operation.

Checks cover the push stages, retries, nested audit/knowledge/directive operations, canonical pull boundaries and supplemental workflow paths. Startup waits for verified authority and retries when a cached profile becomes verified, so the stronger admission rule does not strand initial synchronization.

## Evidence and scope

Final verification on the combined local changes:

| Check | Result | Evidence |
| --- | --- | --- |
| Combined 30-file regression run, including all 22 release no-loss spine files | **356/356 passed**, exit 0 | `output/dev-sync-isolation-20260927/final-tests.log`; exact selection in `final-test-manifest.txt` |
| Complete Flutter source/test/integration-source analysis | **No issues found**, exit 0 | `output/dev-sync-isolation-20260927/full-analysis.log` |
| Focused interface and confirmation gates | **58/58 passed** | `output/dev-sync-isolation-20260927/partial-consumer-tests.log` |
| Startup, retry, navigation and async lifecycle checks | **52/52 passed** | `output/dev-sync-isolation-20260927/startup-retry-tests.log` |
| Native pull, supplemental pull and decomposition checks | **74/74 passed** | `output/dev-sync-isolation-20260927/native-workflow-tests.log` |
| Full working-tree whitespace validation | Passed; Git emitted line-ending conversion notices only | `git diff --check` |

The focused counts overlap with the combined run and should not be added into a unique-test total. This is targeted regression verification, not a run of every Flutter test or a production release gate.

The regression scenarios exercise the real push engine, coordinator and native Isar pull with controlled remote repositories. They include an early failed upload followed by a successful independent write; preservation of the exact unsynced maintenance record while a clean record is refreshed; prerequisite failures suppressing closure/event upload; retry cancellation; truthful partial feedback; startup authority transitions; and disposal without later provider access.

The release gate's no-loss spine includes the new isolation, native preservation, coordinator lifetime, account guard, partial presentation, startup authority and workflow retry/pull checks alongside its existing checks.

These are shared application changes, not a DEV-only workaround. They do not change the database format or deploy a backend. No APK/AAB, commit, push, production installation or business-data mutation was performed for this repair. The tests use local synthetic fixtures; they are not a claim that a newly packaged production build was tested on a phone.

An operation already accepted by the server cannot be undone by a client cancellation check. Guards stop subsequent work at the checked boundaries; existing command identities, receipts, conflict preservation and claim leases govern recovery of an in-flight operation.
