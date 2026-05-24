# Issue 41 — Remove duplicate `responses` / `responsesJson` payload writes

## Decision

Use `responsesJson` as the canonical Firestore payload for JobExecution and JobModuleInstance response data.

Stop future app writes from duplicating the same response payload into both:

```text
responses      // structured array
responsesJson  // JSON string
```

Keep backward-compatible readers that can still read older Firestore documents containing `responses` arrays.

## Why this is the safest direction

- Isar schema already stores `responsesJson` as the persisted field.
- Existing sync conflict comparison uses `responsesJson`.
- UI copy already describes saved responses as `responsesJson`.
- Existing `fromMap` methods prefer legacy structured `responses` arrays when present, then fall back to `responsesJson`.
- Firestore rules do not require `responses` on create.

## What changed

### `JobModuleInstance.toMap()`

No longer writes `responses`.

Still writes:

```text
responsesJson
```

Still reads legacy `responses` via `fromMap()`.

### `JobExecution.toMap()`

No longer writes `responses`.

Still writes:

```text
responsesJson
```

Still reads legacy `responses` via `fromMap()`.

### `FirestorePlannedRepository.completeExecution(...)`

No longer updates `responses` during direct Firestore completion response writes.

Still updates:

```text
responsesJson
```

## What did not change

- No Isar schema change.
- No Firestore rules change.
- No migration required.
- No reader compatibility loss for older docs.
- No change to module response UI behavior.

## Why Firestore rules were not changed now

Rules still allow `responses` in JobModule update allowlists. That is deliberate backward compatibility for any older client or existing direct write path that still sends the legacy field.

A future cleanup pass may remove `responses` from rules after confirming all deployed clients are upgraded.

## Verification

Run:

```powershell
dart format lib\features\planned_maintenance\data\job_module_model.dart lib\features\planned_maintenance\data\job_template_model.dart lib\features\planned_maintenance\providers\planned_maintenance_provider.dart test\issue_41_response_payload_contract_test.dart
flutter analyze
flutter test test\issue_41_response_payload_contract_test.dart
flutter test test\issue_1_tombstone_conflict_regression_test.dart
```

## Closure condition

Issue 41 is source-level closed when:

1. `flutter analyze` passes.
2. `issue_41_response_payload_contract_test.dart` passes.
3. Existing tombstone conflict regression still passes.
4. A manual module save/submit still shows saved responses in the job module detail screen.


## No legacy client decision

Current project decision: there are no older/parallel app clients that must keep writing the legacy `responses` array.

Therefore this stricter package does both:

1. stops current Dart code from writing `responses`, and
2. tightens Firestore rules so future writes carrying `responses` are rejected.

Existing documents that already contain `responses` remain readable. Dart readers keep a legacy fallback for old stored documents, but `responsesJson` is now the canonical source whenever both fields exist.
