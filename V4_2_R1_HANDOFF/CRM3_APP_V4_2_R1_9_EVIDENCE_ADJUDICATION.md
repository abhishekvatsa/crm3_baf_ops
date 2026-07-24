# CRM3 v4.2_R1.9 execution-evidence adjudication

## Custody

Submitted evidence package:

`CRM3_V42_R1_9_CANONICAL_LOCAL_LAB_20260722_230652.zip`

SHA-256:

`E2A0F3D38C9A0950922A0B5933A435159E5FA950F361BC8C2B8D6ADB3FEB470A`

The external sidecar matched the submitted ZIP.

## Proven execution

Stages 01 through 19 passed on the pinned Windows toolchain. This proves, among other gates:

- Functions dependencies installed and TypeScript compiled;
- Firebase CLI lock policy, installation, load smoke and strict audit passed;
- Flutter dependency resolution passed;
- authentic Isar `build_runner` generation passed;
- post-codegen custody passed with no handwritten or governed-source drift;
- semantic Isar continuity passed with 101 generated property-position changes reported and zero semantic failures;
- Isar release verification passed with zero provisional bindings.

## Exact stage-20 failure

`20_v42_r1_audit` reported `missing=0 drift=5` because it compared the post-codegen workspace against pre-codegen `candidateSha256` values in `CANONICAL_MAIN_RECONCILIATION.json`.

The five paths were generated bindings:

- `lib/features/maintenance/data/maintenance_model.g.dart`
- `lib/features/planned_maintenance/data/job_diary_model.g.dart`
- `lib/features/planned_maintenance/data/job_module_model.g.dart`
- `lib/features/planned_maintenance/data/job_template_model.g.dart`
- `lib/features/planned_maintenance/data/template_governance_model.g.dart`

The pristine R1.9 package matched all 410 intended candidate hashes. The mismatches appeared only after successful authentic generation. Stage 17 had already classified generated binding changes and rejected handwritten drift.

## Ruling

This was an audit-phase baseline defect, not application-source drift. The correct fix is not a broad exemption. R1.10 binds post-codegen audit authority to exact generated hashes captured from this authenticated run while continuing to byte-pin every non-generated canonical path.
