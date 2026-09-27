# Independent review response — 27 September 2026

This records source review and local verification. It is not a production release,
deployment, installed-build, or distribution approval.

## Confirmed findings and repairs

- **Screen-owned database access:** the cause-link lookup moved from the
  abnormality assessment dialog to a dedicated evidence reader. Its authority,
  catalogue completeness and source-record checks remain required. The new Base /
  Inner Cover report reader is explicitly classified as a read-only persistence
  boundary. Existing authority classifications and architecture ceilings were
  preserved when refreshing the measured inventories.
- **Business journeys absent from CI:** the Android gate now declares real local
  Firebase journeys for abnormality/Quality acceptance, a separate application
  process restart, and fresh planned publication through assignment and final
  closure. The fixture uses a dedicated `demo-` project and disposable Android
  emulator. It does not pre-create the acceptance or closure being asserted.
  Seven other DEV probes remain outside this automated gate, with explicit
  reasons in `governance/ci-business-journeys.json`. Wiring and seed validation
  do not establish a successful Android CI run; that result must come from CI.
- **CF-03, audit-history completeness:** failed server reads no longer return a
  bare local list that can be mistaken for complete history. The repository
  requires server reads and reports a typed incomplete result retaining saved
  rows. Entity, recent-event and conflict screens show the incomplete-history
  warning and Retry. No saved rows produces an unavailable state, not an assertion
  that no history exists. Malformed persisted audit evidence remains an error.
- **Additional backend validation:** enum coercion could accept JSON arrays as
  valid labels while persisting the arrays themselves. Observation kind,
  assessment, post-RA result and linked process category now reject these values
  before mutation. Four negative mutation regressions cover the defect.

## Qualified claims

- The "sign-in brick" description conflates an unchecked optional display-field
  cast with intentional refusal of malformed authority. The optional decision
  reason now uses the strict persisted-string reader instead of an unchecked
  cast. Invalid approval, role or revision data must still prevent access. The
  existing access gate conceals protected content and offers retry/sign-out;
  a resolved signed-out session reaches sign-in. The source repair does not
  silently repair damaged production profiles.
- The backend is not wholly untested against Firestore: this pass ran **245 tests
  across 22 actual emulator suites**, in addition to **2,444 host tests across
  81 suites** and **81 auxiliary Node tests**. This is not a claim that every
  possible backend write and failure interleaving has emulator coverage.
- The CF-02 **356-test** result is focused sync evidence. The complete Flutter
  suite is a separate gate. Run lifetime protection also does not by itself prove
  original-account ownership of every historical queued record.
- **CF-01 remains open:** source review confirms permitted cross-account replay
  paths for abnormality type edits, legacy job templates and existing execution
  work updates. Other command journals and several domain replay paths already
  check the original actor. See `CF01_QUEUE_OWNERSHIP_FINDINGS_2026_09_27.md` for
  the bounded findings and required repair. Do not infer a universal closure
  from the session-guard tests. This source push is a **draft review**, not a
  merge or release recommendation.

## Commit and review scope

The backend was saved separately as `8afa441c`. Shared client changes are
interdependent: the new sync outcome, strict data readers, reports and UI
consumers must be reviewed together. DEV infrastructure and CI wiring are a
separate commit so their execution boundaries can be inspected independently.

## Final local verification

- Whole-app analysis (`lib`, `test`, `integration_test`): no issues.
- Complete Flutter run: **3,911 passed, one skipped, four failed**. The failures
  were the earlier A-04 inventory snapshot, a directive-dialog source assertion,
  duplicate current-inventory ledger assertions, and stale deployment-status
  labels. After their repairs, **all 36 tests in the four affected suites passed**.
  No application or Functions runtime code changed after the complete run.
- The new audit-history, UI, startup and profile regression batch passed **50/50**.
- Source inventory mutation contracts passed **24/24**; artifact rebind tool
  contracts passed **48/48**. These exercise the tools, not artifact promotion.
- CI orchestration safety passed **11/11**, workflow custody **8/8**, and a focused
  source-custody test passed. The isolated synthetic seed and authenticated
  callable-readiness probe also passed. Android CI execution remains pending.

The mutable current-source index had retained three exact-deployment labels from
the earlier source. They now truthfully say `SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT`
and the corresponding pending-deployment summary. This downgrades the current
source's readiness claim. Every historical receipt/hash and every authorization
boolean remains unchanged. It is not a rebind or a deployment.

Start a code review with the CF-02 report, the six business/visual validation
documents, the new cause-evidence reader, the audit-history regression, and the
explicit CI journey manifest. Generated local logs and real operational/device
identifiers are excluded from the public source changes.

Before any new production build, run the full release procedure against its exact
source and backend state, establish the required artifact binding, and validate
the exact signed artifact and upgrade path. Historical release authority and
artifact hashes must not be rewritten merely to make current source checks pass.
