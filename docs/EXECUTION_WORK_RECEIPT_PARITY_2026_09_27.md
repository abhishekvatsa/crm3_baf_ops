# Execution work storage and receipt parity — 27 September 2026

A fresh PR #382 review of `69580b22` identified a real evidence mismatch. An authenticated `updateJobExecutionWork` request could omit an optional field such as `remarks`. Validation accepted it, the database update replaced the omitted field with null, but the accepted snapshot inherited its previous value. The audit and replay receipt therefore described a different result from the stored record.

The same accepted-snapshot construction could misrepresent pinned fields. A submitted null/default representation can be semantically equivalent for validation, while the physical update correctly preserves the original field. Receipts must preserve that original representation too.

## Repair

Execution updates now include only explicitly supplied WORK fields. Omitted optional fields retain their existing value or absence; explicit null remains an intentional clear. Both the audit and receipt derive from the original canonical snapshot plus exactly that update.

Validation still occurs before constructing the update. Required work fields remain required; omission does not fill them from stored data. Protected assignment metadata, physical equipment identity, actor authority, creation evidence, version and exact command replay remain enforced. The catalogue and legacy-template write paths are unchanged. No production records were edited or deployed by this repair.

Current Flutter serializers supply all seven WORK fields, and native/online receipt comparison decodes canonical records before comparison. Their intended null-clearing behavior and default normalization remain compatible; sparse custom envelopes do not acquire permission to bypass the client receipt checks.

## Verification

- Before repair, the 36 new host cases produced **14 failures and 22 passes**, reproducing both omitted work-field loss and pinned-field receipt drift. After repair, the complete retained-mutation suite passed **257/257**.
- Functions build/type-check, emitted-output verification and callable/notification inventories passed.
- Full backend host suite: **2,735 passed across 83 suites**; **291 emulator-only tests across 25 suites skipped**, not counted as executed.
- Authenticated V2 callable suite: **7/7 scenarios passed**. Added cases cover existing/missing/null optional fields, explicit clearing, pinned default/absence, complete client payloads and five no-write refusals. Canonical data, stored receipts and audit before/after are compared; replay preserves canonical, audit and receipt update times. Dedicated actors keep the existing abuse limits intact.
- Firestore Rules: **247/247 passed**. The isolated runner exited successfully, stopped its own emulators and removed its temporary configuration.
- Existing client retained-work, receipt-adoption, job-module and decoder suites: **50/50 passed**. Client code did not change; the full **4,096-pass, one-skip** Flutter result belongs to the preceding `69580b22` source, rather than a repeated full-client run for this backend-only patch.
- Canonical source audit: **153/153 passed**, including **434 retained receipt pointers**. Independent source/test review found no remaining blocker in the repair.

Diff validation passed. Exact-current-head GitHub acceptance and fresh review remain required after pushing. This note does not establish readiness to deploy, construct a production artifact or distribute through Play.
