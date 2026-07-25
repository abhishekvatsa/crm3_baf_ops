# v4.2 Critique Adjudication

## First critique

| Finding | Adjudication | v4.2 treatment |
|---|---|---|
| Native Firestore Timestamp flattened by generic recursion | Valid and critical | Fixed at common persistence boundary; native special types preserved; direct command-path tests added |
| User optional-field and role validation incomplete | Valid | Exact Rules shape, bounds and canonical role vocabulary; server/client fail closed |
| Live legacy user documents may contain extra keys | Valid deployment concern | Remains a readback/migration preflight before Rules deployment; no deployment authorised here |
| Authority-critical projection defaults can hide corruption | Valid | Critical fields now throw and enter per-document quarantine |
| Dependency advisories | Valid at review time | Root, Functions and Firebase CLI trees remediated to zero known advisories at packaging time |
| Exact Git-main ancestry absent | Valid integration gate | Not treated as a reason to stop successor development; mandatory before remote merge |
| Existing programme ledger should subordinate v4 to Stage 2D | Not accepted as design direction | Explicit user agreement makes v4.2 the source-migration authority; current app remains operational until cutover |
| Isar generation/migration/Flutter/emulator/device proof open | Valid | Remain fail-closed trial and cutover gates |

## Deep merged review

The deep review’s principal positive findings are retained:

- legacy closure cannot bypass workflow closure;
- both closure regimes share the canonical readiness/attestation implementation;
- 21-command client/server parity is exact;
- ticket deferral is complete end to end;
- policy generation retires cross-language authority drift;
- App Check is staged honestly rather than enabled before signed-client readiness.

Its statement that committed generated files prove authentic code generation is not adopted as release authority. Thirteen files remain explicitly provisional until the pinned toolchain regenerates them and the release verifier passes.

## Governing synthesis

The critiques improve v4; they do not reverse it. Old-app mechanisms are adapted only when they carry a legitimate capability, security guarantee or migration requirement. Avoiding change is not an architectural objective.
