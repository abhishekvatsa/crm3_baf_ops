# PBA-04: matching acceptance after saved-work review

Current source repair, 13 September 2026. This note describes local behavior and completed host verification. It does not authorize or report production recovery activation, an APK build, or a physical-device test.

## Confirmed defect and repair

The repository at `30330c72ca2a92cb0a485e0ced7e3c21f0479292` turned every valid late acceptance after a saved-work review into `reviewConflict`, including confirmation of the same accepted result. The native regression executes that actual older repository and reproduces the false conflict.

A matching confirmation now becomes `acceptedPendingAdoption`. It retains the original frozen envelope and actor, the complete administrative decisions, every already-retained late receipt, and the canonical domain receipt. Cancellation, a different original actor/result/version/time/status, a conflicting retained server receipt hash, invalid prior receipt evidence, and unknown legacy origin remain blocked.

Settlement still requires the exact frozen-envelope checksum and the domain's existing synchronous receipt validator. It then compares all six server review summary fields, requires exclusively consistent `reviewedExisting` decisions, and revalidates each retained late receipt. The private server receipt hash covers a richer stored document than the callable response, so it is not compared with a hash of the transport response. It must remain consistent across retained administrative decisions. This comparison permits the domain's authoritative readback to proceed; it does not substitute for that readback or prove every submitted business field from the abbreviated summary alone.

## Storage and older-reader behavior

There are no new native columns, enum states, schema version, or migration changes. The existing receipt column stores a strictly typed `acceptedAfterSavedSubmissionReview` capsule containing the review history and canonical receipt JSON. Its native checksum binds the complete capsule. The current immutable view exposes the domain receipt and its own checksum to existing controllers, plus `reviewHistoryJson`; reconciliation therefore checks the exposed receipt checksum. Duplicate settlement compares the exposed receipt, not the capsule bytes.

The executable compatibility fixture is `tool/test_support/legacy_v12_durable_submission_repository.dart`. It is the repository from the exact commit above, with only its class name and relative import/export paths adapted so it can execute beside the current repository. A read-only comparison against that Git object verified these are the only source changes; the original LF source SHA-256 is `f6f38a8a0b910e8c7be4753cc459b3df1aa53b4dbdb404fdb6751b77b5ca9714`. Its imported schema fields and state meanings are unchanged. Native tests show that this reader retains the capsule as accepted and unresolved, returns no dispatch grant, rejects a replacement owner, and cannot pass the capsule through the existing strict Inner Cover domain decoder. It also refuses to overwrite it with a subsequent ordinary receipt. With two pending owners it conservatively refuses discovery. Compatibility here means retained evidence and refusal, not older-reader support for completing the new recovery path.

## A reviewed release followed by later saved work

A consistent confirmation must not manufacture a conflict merely because review of A already permitted B to be saved. The repository uses its existing native allocation invariant, not wall-clock timestamps:

- Only `prepare` creates ordinary native rows, under a serialized transaction which refuses an existing unresolved owner. IDs are auto-incremented there and never changed, deleted, or reinserted by a production repository path.
- The only other insertion API imports explicitly marked legacy evidence. It is excluded from this ordering proof.
- A nonlegacy row with the retained matching review history cannot have been reviewed after rejection, cancellation, or reconciliation: `settleReview` refuses those terminal states, and a terminal claim cannot rearm it. An ordinary row with a later native ID could therefore only have been admitted after that row's reviewed release.

Discovery presents the earlier confirmed acceptance first. Its exact domain readback and local adoption may complete while later ordinary work remains intact. Later claim/adoption attempts wait with `prior-acceptance-pending`; their original state, token, envelope, and receipt are preserved. Once the earlier adoption completes, the later owner resumes normally. An already in-flight reply remains retainable. Earlier ordinary owners, imported legacy neighbours, unreadable data, and contradictory reviews do not qualify.

This inference depends on preserving the documented insertion/retention invariant. Any future nonlegacy import, ID reassignment, deletion/reinsertion, or general terminal rearm API must revisit it. A later row that an older reader already moved to `needsReview` keeps that state: its former state is not reconstructed. Current authoritative readback and each domain's existing adoption checks remain responsible for preserving later server and local business changes.

## Completed evidence

`build/review-20260913/pba04-native-second.txt` records **94 passing tests**: 21 new native recovery cases, seven domain-summary contract cases, and 66 existing review/store regressions. The initial run had one test assertion comparing a raw Isar local-time value to UTC; normalization corrected the assertion without changing runtime behavior.

The final seven-item scoped analyzer is clean (`pba04-analyze-final.txt`). Reviewed current A05 timestamp/decoder and A04 inherited-schema inventories pass (`pba04-timestamps-final.json`, `pba04-decoders-final.json`, `pba04-a04-final.json`); direct and wrapper-only decoder boundaries are classified explicitly. A02 also passes without raising file ceilings (`pba04-a02-readonly.json`). These are current-source checks, not replacements for the combined release gates.

The native cases cover matching and mismatching confirmation, cancellation, original actor/envelope refusal, conflicting server hashes, damaged retained receipts, failed adoption/restart, capsule integrity, older-reader behavior, and earlier/legacy neighbours. They also exercise A reviewed → B unsent or claimed → delayed matching A → restart → A adoption → unchanged B continuation.

The actual campaign controller runs against a capable idempotent server double and real Isar. A is reviewed while its accepted reply is delayed; B is then independently accepted; A's server projection advances to version 2. After both results are retained and the database is reopened, the controller adopts current A and then B without another dispatch or capability probe. There are exactly two creations and two sends. This proves the client/controller/native path, not Firebase callable execution, production authorization, worker drainage, or phone behavior. The seven mapping tests exercise the six review domains, including assignment request-versus-execution identity and both burner version contracts; they are summary contract tests, not independent domain acceptance validators.

Recovery finalization remains subject to the existing separate deployment, worker-drain, rollback, and activation requirements.
