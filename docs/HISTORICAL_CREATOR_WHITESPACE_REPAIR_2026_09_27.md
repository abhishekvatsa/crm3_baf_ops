# Historical creator whitespace compatibility — 27 September 2026

PR #382's earlier missing/null historical-creator repair remains valid. A subsequent review identified a separate round-trip defect: readers trim nonblank creator text, but the backend compared the submitted normalized value with raw historical text. Reader-valid catalogue records could therefore be displayed yet not edited, deactivated or soft-deleted. The same comparison affected legacy templates. A clean native Isar catalogue row could also fail its local immutable-creator check before submission.

## Correction

- Existing creator identities compare using the corresponding reader's semantics: surrounding whitespace is ignored; case and actual identity remain significant. Only the legacy-template reader treats blank text as null.
- Accepted records retain the original server creator text. Legacy templates also retain exact null values and field absence, preventing a caller from replacing unknown history with equivalent blank text.
- Existing trimmed text must remain within the reader's bounds. Catalogue blank fields and names without UIDs remain invalid. New-record actor admission, current editor attribution, creation time, version and role restrictions are unchanged.
- The native catalogue validator applies the same comparison to its actual retained baseline. Native and online receipt adoption already compares decoded records, so raw historical server text remains compatible with the normalized local model.
- The original submitted command is not mutated. Its fingerprint, accepted audit record and receipt remain consistent, including replay after subsequent canonical changes. SI still cannot delete a template.

The repair does not rewrite production history or scan production rows for cosmetic normalization.

## Verification

Before repair, focused backend runs reproduced the padded catalogue and template failures. An intermediate implementation exposed a second preservation edge: two regression cases proved that original null/omitted template fields could become newly supplied blank text. Both failed before the final restoration correction. The clean client baseline produced 31 passes and one failure in the raw-Isar historical lifecycle; the earlier fixture-error run was retained separately and is not behavioral evidence.

Final source verification:

- Functions build/type-check, emitted-output check and callable/notification inventories passed.
- Full backend host suite: **2,699 passed across 83 suites**. Its **291 emulator-only tests across 25 suites were skipped**, not counted as executed.
- Authenticated V2 callable suite: **7/7 top-level scenarios passed**, expanded with padded catalogue and padded/blank/null/omitted template histories, lifecycle changes, canonical/audit/receipt readback, exact replay, update-time checks and no-write refusals. Dedicated synthetic actors preserve the existing abuse limits.
- Firestore Rules suite: **247/247 passed** in the same isolated demo run. The runner shut down its own emulators and removed its temporary configuration.
- Catalogue native/online repository suite: **32/32 passed**, including eight new cases. These use real Isar/journals and a replaced remote transport; the separate authenticated suite establishes the server boundary.
- Full Flutter suite, including the recent compact ticket headers and Control navigation: **4,096 passed, one existing skip**.
- Whole-client analyzer: **no issues**. Canonical source audit: **153/153 passed**, including **434 retained receipt pointers**. Diff whitespace validation passed.
- Independent source review found no remaining blocker in the final patch. The new backend host regressions total 37.

These results establish local source verification. The exact pushed revision still needs its complete GitHub checks and review. They do not establish a new signed artifact, deployment, Play-delivered update or distribution approval. PR #382 remains draft.
