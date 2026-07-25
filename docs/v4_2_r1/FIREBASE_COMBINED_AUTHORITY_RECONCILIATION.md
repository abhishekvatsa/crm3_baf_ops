# Firebase Combined-Authority Reconciliation for v4.2 R1.16

## Decision

The permanent Firebase Android app now intentionally carries both debug and production signing identities. The current Firebase-generated `google-services.json` is bound by:

- raw SHA-256 `2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B`;
- semantic SHA-256 `A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2`;
- restoration operation `CRM3-FB-RESTORE-001-C1`;
- successful restoration evidence SHA-256 `24C335AF607595363F4C1D9E68B81AC9E558D37FB49263DE16EF87136D58E6CF`.

## Chronology preserved

1. BAF-REF-005 remains the immutable proof that production registration succeeded on 23 June 2026 (`730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A`).
2. The later debug-only configuration (`DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D`) remains preserved as superseded chronology, not current authority.
3. The 24 July additive restoration retained the debug SHA pair and OAuth client while restoring the production SHA pair and historical production OAuth client.
4. The current combined configuration is the only file authorised for repository integration.

## Canonical reconciliation count correction

The existing 410-path reconciliation carried seven disposition-label errors: the canonical and candidate hashes differed, but the rows were labelled `BYTE_IDENTICAL`. The exact row hashes were retained and the labels/counts were corrected from `344 / 66` to `337 BYTE_IDENTICAL / 73 SUCCESSOR_MODIFIED`. The affected paths are:

- `lib/core/services/sync_service.job_modules.dart`
- `test/async_mounted_context_safety_contract_test.dart`
- `test/lifecycle_static_guardrail_contract_test.dart`
- `test/production_release_provenance_contract_test.dart`
- `test/stage2d_source_security_contract_test.dart`
- `tool/test_support/test_isar_core.dart`
- `tools/release/New-ProductionArtifact.ps1`

This is a custody correction only. It does not add source changes beyond those already present in the exact candidate and does not alter the independent Git-normalised integration boundary.

## Integration boundary

This record accompanies the R1.16 source integration. It permits a feature branch, one reviewed commit, push and draft pull request only after the full authoritative laboratory passes. It does not permit merge, tag, Firebase deployment, App Check enforcement, production artifact signing, distribution, or production-data mutation.

## Equipment projection pilot/cutover prerequisite

Workflow mutations must remain disabled for pilot and cutover until the equipment projection is reconciled. An absent `equipment_status` document does not prove that an equipment item has no historical workflows, and a missing individual counter must not be interpreted as zero.

Before enabling workflow mutations, the governed cutover procedure must:

1. enumerate every equipment item referenced by an existing maintenance workflow;
2. run the Admin/SI `reconcileEquipment` command, or an equivalently governed backfill using the same authoritative workflow facts, for every enumerated item;
3. verify that every resulting `equipment_status` document contains all three non-negative safe-integer counters: `activeNonRedMaintenanceCount`, `activeRedWorkCount`, and `awaitingPreparationCount`;
4. compare those counters with the authoritative non-terminal workflow population and resolve every mismatch;
5. retain read-back evidence showing complete coverage and zero unresolved exceptions before the mutation capability is enabled.

The application source enforces this prerequisite at the mutation boundary: missing projections, partial counter sets, malformed counters, and negative counters fail closed. A wholly new equipment item must therefore receive a governed zero-count reconciliation before its first workflow mutation; ordinary job creation cannot initialize an unknown projection.
