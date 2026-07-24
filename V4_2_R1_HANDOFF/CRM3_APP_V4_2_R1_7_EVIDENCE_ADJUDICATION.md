# v4.2_R1.7 Execution-Evidence Adjudication

## Custody

The submitted evidence archive was:

- `CRM3_V42_R1_7_CANONICAL_LOCAL_LAB_20260722_221849.zip`
- SHA-256: `99583FA64C89320E583FB2B62748BE3C1BCEF3F32657C751D08157B483C3C700`

The sidecar and calculated archive digest matched exactly.

## Proven stages

Stages 01 through 17 passed, including:

- pristine-candidate and disposable-workspace custody;
- all three npm dependency installs and audits;
- Functions TypeScript compilation;
- Firebase CLI lock/version/load gates;
- `flutter pub get`;
- authentic pinned Isar `build_runner` generation;
- post-codegen custody with generated bindings and exact platform registrants classified.

Stage 18 stopped with `FAIL_CANONICAL_ISAR_CONTINUITY`.

## Exact finding

The generated schema retained:

- all 16 inherited collections;
- all inherited collection IDs;
- every inherited property name;
- every inherited property type;
- every inherited index definition.

The only 101 findings were changed generated `PropertySchema.id` positions:

- `JobExecution`: 27
- `TemplateVersion`: 33
- `JobModuleInstance`: 41

All 101 were type-preserving. They arose because additive successor properties changed the generator's property ordering.

## Adjudication

The prior verifier incorrectly treated generated property positions as immutable migration identity. That premise is too strict. Isar's schema contract is name/type based for additive schema migration; generated positions are current-schema serialization coordinates and can be remapped when the database opens.

The project also has a separately approved clean-cutover policy for the initial pilot: fresh installation and a fresh local database. That policy remains in force, but the R1.8 correction does not use it to excuse missing, renamed or type-changed inherited fields.

## Decision

- Authentic Isar generation: **PROVEN PASS**
- Old verifier's 101 numeric-position findings: **REAL BUT MISCLASSIFIED**
- Missing/type-changed inherited properties: **NONE**
- Index or collection identity drift: **NONE**
- R1.7 application source defect established: **NO**
- Required correction: **semantic continuity gate, not a schema rewrite**
