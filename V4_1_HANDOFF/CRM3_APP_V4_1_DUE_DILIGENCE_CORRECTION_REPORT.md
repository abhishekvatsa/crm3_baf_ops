# CRM3 App v4.1 — Due-Diligence Correction Report

## Candidate lineage

- Input: `CRM3_APP_V4_WHOLE_APP_RECONCILIATION_CANDIDATE.zip`
- Verified input ZIP SHA-256: `960891AB01FB59A81258DDA8162D8B372AAA8EFBF3839DEDA1A08B24E479A0FC`
- Output: v4.1 due-diligence correction candidate
- Programme position: principal successor-source candidate; not production replacement authority

## Governing adjudication

The external review was treated as adversarial evidence, not governing programme authority.

The agreed programme direction remains:

1. v3.3/v4 establishes the successor architecture.
2. The current deployed app remains operationally canonical until governed integration.
3. Valid current-app security, operational and release guarantees must be absorbed into v4.
4. Conflicting legacy authority paths do not remain equal authorities merely for compatibility.
5. No direct merge, Firebase deployment, build or distribution is authorised by this source package.

## Findings accepted and corrected

### 1. Firebase Android app identity

`firebase.json` and the startup contract referenced Android app ID `…c320…`, while the permanent registration receipt and release policy referenced `…fba14…`.

v4.1 aligns all source mapping to:

```text
1:894346496105:android:fba14febfbbee102e63af8
```

The governed Firebase files remain externally restored and hash-verified before build.

### 2. Admin user-document schema perimeter

`validAdminUserWrite` required roles and approval fields but did not reject arbitrary extra top-level fields.

v4.1 requires the exact approved schema:

- `name`
- `email`
- `photoUrl`
- `roles`
- `isApproved`
- `fcmToken`
- `createdAt`

It retains protection against an Admin removing their own last Admin authority. Source and emulator test cases are included.

### 3. Compliance Firestore projection

The local compliance record was substantially richer than the Firestore mapper. v4.1 maps the full operational lifecycle, including:

- priority;
- raiser, acknowledgement, compliance and confirmation actors/times;
- notes and attempts;
- due markers;
- counter proposal and decision evidence;
- correction evidence;
- all cross-record links;
- asset/charge context;
- escalation tier and deadlines;
- deletion and metadata fields.

The mapping is exposed through a pure map-to-record seam and a Flutter unit-test source with a realistic full snapshot.

### 4. Operational documentation

The Flutter starter README has been replaced by a whole-app architecture, build, Firebase custody, Isar generation, validation and runtime-gate guide.

## Finding rejected as technically incorrect

### Escalation ISO String versus Firestore Timestamp

The domain helpers return ISO strings deliberately so command payloads, receipts and deterministic unit fixtures remain JSON-safe.

The production workflow persistence boundary is `FirebaseWorkflowStore`. Before every create, set or update it recursively converts ISO values whose field names are lifecycle timestamp fields (`*At`, `*Since`, `*DueAt`) into `admin.firestore.Timestamp`.

Therefore command-created `nextEscalationAt`, `acknowledgementDueAt` and `complianceDueAt` values are stored as native Firestore Timestamps.

v4.1 adds executable tests proving:

- deadline conversion;
- nested timestamp conversion;
- exact instant preservation;
- non-timestamp strings remain strings;
- `appliedAt` remains the receipt-format string by design.

The emulator query proof is still required, but the alleged mixed persistence model is not present in the actual write adapter.

## Review points retained as gates, not source defects

### Current-main reconciliation

The review asserts a later canonical `main @ 633c58bb0d936011e391b42627f8b8f02c510e95`. The connected GitHub integration returned no accessible repository, so that claim could not be independently verified in this environment.

The exact current-main ancestry and no-loss semantic comparison remain mandatory before any merge. This does not invalidate continued successor-source development.

### Firebase build inputs

`lib/firebase_options.dart` and `android/app/google-services.json` remain absent from the evidence package. Their absence is now prominently documented. Build authority remains NO-GO until governed restoration and policy/hash checks pass.

### Isar generation and migration

Thirteen provisional bindings remain deliberately release-blocked. No claim of authentic pinned `build_runner` output or real database migration is made.

### Dependencies

The review's current npm-advisory findings are retained as O-07 remediation input. No uncontrolled lockfile change was attempted without verified resolution and regression proof.

### Flutter/client/runtime proof

A complete compliance mapper test source was added, but Flutter analysis/tests, Rules emulator, Functions emulator, scheduler queries, Android builds, device upgrade and recovery remain open.

## Validation result

- v4.1 due-diligence audit: `9/9 PASS`
- v4 whole-app audit: `21/21 PASS`
- inherited full-tree audit: `18/18 PASS`
- inherited expanded audit: `15/15 PASS`
- Dart structural audit: PASS across `368` files
- Functions TypeScript compile: PASS
- Functions executable tests: `210 passed`
- Emulator-dependent Functions tests: `29 skipped`
- Policy generation parity: PASS
- Isar source verifier: PASS
- Isar release verifier: expected FAIL with `13` provisional bindings

## Final classification

| Use | Decision |
|---|---|
| Continue v4 successor development | GO |
| Use as source for a governed reconciliation branch | CONDITIONAL GO |
| Directly merge into an unverified current main | NO-GO |
| Build without governed Firebase/Isar inputs | NO-GO |
| Deploy or distribute | NO-GO |
