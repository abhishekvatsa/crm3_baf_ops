# Historical catalogue creator compatibility — 27 September 2026

The incremental review of `463fdd4f` correctly identified a compatibility deadlock. A readable historical abnormality type could have an absent/null creator name. The newer mutation validator required that name on every edit, while the existing immutable-creation guard prohibited adding or changing it. Neither preserving the historical absence nor inventing a name could satisfy both rules.

The strict client reader also supports an entirely unknown historical creator pair. Native and online save validation had a connected restriction that rejected that supported representation before using the actual existing record.

## Correction

- New records require a complete creator UID and name.
- Existing records preserve their original creator fields, including supported historical absence/null. A known creator cannot be removed or replaced; an unknown creator cannot be invented.
- Non-null historical fields must remain valid bounded text. Blank names, blank UIDs and names without UIDs remain invalid.
- Every current mutation requires a complete editor, with the editor UID bound to the admitted actor. Native and online repositories validate against the actual retained/server baseline, not a caller's version or synchronization flag.
- Deactivation and soft deletion preserve creation history while recording the current editor/deletion actor. An uncertain retry and accepted replay retain the original command and evidence.

No historical production catalogue row was rewritten, and no production population claim is made. This does not reopen the previously repaired queue ownership, deferred-sync reporting or purge-session findings.

## Evidence

Historical fixtures are seeded directly, rather than created through the new strict creation API. Backend tests exercise absent/null names and entirely unknown creator pairs through editing, deactivation, deletion and replay after later changes. Refusal checks verify unchanged records, audits and receipts. Authenticated emulator requests exercise the exported V2 callable and canonical Firestore readback, including server watermark and update-time stability.

The unchanged backend failed 17 of the 43 new selected regressions. The unchanged client failed 13 of the 24 new repository regressions. The earlier fixture import failure is retained separately and is not counted as behavioral evidence.

Verified after correction:

- Functions build, emitted-output custody and callable/notification inventories passed.
- Full backend host suite: 2,662 tests passed across 83 suites. The 291 emulator-only tests were skipped by this host run and are not counted as executed there.
- Dedicated authenticated callable suite: all seven top-level scenarios passed, with historical lifecycle coverage added inside the existing scenario.
- Firestore Rules suite: 247 tests passed.
- Focused client suite: 139 passed, including 24 new native/online historical-creator regressions, strict readers, retained ownership, immutable recovery retries and the UI convention that failed on `83faaef2`.
- Full Flutter suite: 4,077 passed, with one existing skip. Whole-client analyzer: no issues.
- Canonical source audit: all 153 checks passed, including 434 retained receipt pointers.

The recovery screen now uses the existing branded app-bar component; its UI convention check remains unchanged. A source-presence assertion was updated to require the new actual-baseline validator calls, and date tests compare the original instant in UTC rather than treating equivalent local/UTC representations as different history.

The canonical audit's corresponding source guard also requires both actual-baseline validation calls; no authority, persistence limit or permission was weakened. These source tests do not authorize a merge, production backend deployment, signed release or Play rollout.
