# Build 24 Release Preflight

This records the follow-up to PR #345, after the pilot workflow fixes at
`e4ee3d0f0102ec8b80bfab4b2816186087d57180`. It does not certify an APK,
production deployment, physical-device result, or distribution.

## First CI Result

Release-gate run `33884108568` completed four jobs successfully: Flutter host
checks, Android non-production release packaging/cold start, Android app-shell
emulator integration, and Functions host checks. The Firestore job stopped at
the dependency audit before its emulator suite could run. Its log identifies
the newly reported `qs` vulnerability, not a Firestore regression.

## Security Remediation

- Functions and Firebase CLI now pin `qs` 6.16.0; CLI pins `fast-uri` 3.1.6.
- Firebase CLI remains at 15.22.4. Its streaming JSON dependency is routed
  through a small, local CommonJS adapter to upstream `stream-json` 3.5.0.
  The adapter preserves the five interfaces actually imported by the CLI.
  Parsing and the upstream nesting-depth protection remain upstream code.
- This adapter is tooling-only. Tests check that neither the root nor Functions
  lockfile includes it. It is not an Android dependency.
- Eleven compatibility tests cover the three affected CLI call sites, the
  complete set of imported parser paths, malformed input, and hostile nesting.
  Both normal installation and clean `npm ci --ignore-scripts` passed.
- Root, Functions, and CLI audits each reported zero known vulnerabilities.
  The audit threshold was not lowered and no advisory was suppressed.
- CI and production-policy tooling hashes were updated to the inspected
  lockfile. Seven current-candidate source pins were refreshed; historical
  canonical hashes and deployment receipts were left unchanged.

## Clock-Skew Review

PR review comment `3935053200` correctly identified that a new abnormality from
a phone with a fast clock could become permanently rejected. The server now
returns retryable `unavailable` for this specific future-time condition. The
client also recognizes the equivalent older `failed-precondition` reason as
retryable. Unrelated invalid lifecycle and authorization errors stay durable.

This preserves the original case ID, request identity, and event timestamps.
No future-dated record is committed before the server catches up, and no time
is silently replaced. Tests exercise 1 ms, 2.5 seconds, and 5 minutes of skew:
zero writes on the first attempt, one successful commit after the clock catches
up, and an idempotent retry with no additional writes. The operator receives an
explicit automatic-date/time message. A substantially incorrect phone clock
can still delay synchronization; this change is not arbitrary clock repair or
automatic removal of previously quarantined records.

## Verification

- Functions: 905 host tests passed; their 97 emulator-only cases were run
  separately and all passed.
- Firestore Rules: 218 passed in an isolated `demo-crm3-build24` emulator.
- Governed asset projection reconciliation: 3 emulator tests passed.
- Parser compatibility: 11 passed, including after a clean dependency install.
- Focused Flutter sync-classification regressions: 4 passed.
- Canonical source and authority audit: 149 passed, zero failed.
- Production policy verifier: passed for the honest backend-pending state.
- Complete Flutter suite: 1,833 passed, zero failures, one conditional
  production-envelope bridge test skipped (no authorized bridge connected).
  The run completed in 4 minutes 16 seconds; the skip is not production proof.
- Analyzer: no issues found.

Evidence is retained in `output/build24-release-preflight/`. The emulator ran
against a demo project; no production business records were modified.

## Release Boundary

Build 23 is consumed. Build 24 has not been allocated or constructed. PR #345
must pass review and CI at its final head, followed by post-merge CI. Current
Functions and Rules differ from the deployed backend and require exact-source
governed deployment and strict live readback before constructing the matching
APK. Existing IAM, App Check settings, operational data, and devices remain
unchanged. Physical-device validation and controlled-pilot promotion are
separate from host/emulator evidence.
