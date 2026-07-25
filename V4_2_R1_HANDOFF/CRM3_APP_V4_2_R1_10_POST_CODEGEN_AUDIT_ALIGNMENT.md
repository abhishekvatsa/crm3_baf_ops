# CRM3 v4.2_R1.10 post-codegen audit alignment

## Scope

R1.10 changes laboratory custody/audit authority only. It does not change Flutter product logic, Functions, Firestore Rules, Isar models, Android configuration, Firebase identity, dependency versions, programme policy or deployment authority.

## Correction

The canonical R1 audit now supports two explicit phases:

- `pristine`: all 410 captured canonical-main paths must match their packaged `candidateSha256` values;
- `post-codegen`: non-generated canonical paths remain pinned to `candidateSha256`, while generated Isar bindings must match the exact authoritative hashes captured after authentic R1.9 Windows code generation.

The new register is:

`docs/v4_2_r1/AUTHORITATIVE_POST_CODEGEN_BINDINGS.json`

It contains all 19 `lib/**/*.g.dart` outputs and is bound to the R1.9 evidence ZIP SHA-256:

`E2A0F3D38C9A0950922A0B5933A435159E5FA950F361BC8C2B8D6ADB3FEB470A`

## Fail-closed properties

R1.10 fails if:

- any non-generated canonical path differs from its intended candidate hash;
- any expected generated binding is absent;
- any generated binding differs from the exact authenticated post-codegen hash;
- the post-codegen register is malformed, incomplete or loses evidence provenance;
- stage 20 is not invoked explicitly after stages 17, 18 and 19 with `--phase post-codegen`.

This is stricter than excluding `.g.dart` files from custody. Regenerated outputs remain exact evidence-bound artifacts.
