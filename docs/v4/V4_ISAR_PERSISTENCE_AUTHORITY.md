# v4 Isar Persistence Authority

## Current source-candidate state

v4 adds nine workflow mirror/outbox collections and extends four pre-existing
persistence contracts. The exact project toolchain is pinned to:

- Flutter `3.44.0`
- Dart `3.12.0`
- Isar / isar_generator `3.1.0+1`
- build_runner `2.4.13`

That toolchain was not available in the package-construction environment and
could not be retrieved. The checked-in v4 bindings therefore carry the marker
`PROVISIONAL_V4_ISAR_CODEGEN`.

The provisional bindings are generated deterministically from a constrained
repository-local compiler. They preserve pre-existing schema IDs, append v4
fields, maintain unique-index replacement for workflow identities, and pass the
v4 structural schema verifier. They are not release authority.

## Mandatory conversion to release authority

From the reconciled authoritative repository, run one of:

```powershell
pwsh -NoProfile -File tools/isar/Invoke-V4IsarCodegen.ps1
```

```bash
tools/isar/invoke_v4_isar_codegen.sh
```

The runner verifies the exact Flutter/Dart versions, runs the genuine
build_runner, rejects any remaining provisional marker, then executes Flutter
analysis and the complete Flutter test suite.

## Fail-closed release control

`tools/release/Test-ProductionReleasePolicy.ps1` rejects every production build
while any provisional Isar marker remains. Therefore the v4 source candidate
cannot be promoted merely because its TypeScript and source-only audits pass.

## Schema migration

The application schema marker is v3:

- v1 → v2: workflow collection registration;
- v2 → v3: workflow persistence reconciliation, maintenance bridge fields,
  execution terminal state, and EMD/Refractory persistence.

The pinned generator output and real-device migration must still be proven on a
copy of representative v2 local data before pilot approval.
