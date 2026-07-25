# v4.2_R1.3 Type-Safe Authority Hotfix

## Scope

This revision corrects three TypeScript compilation errors introduced when backend approval/role validation was centralized in `userAuthority.ts`. It does not expand product behaviour, change Firestore Rules, alter schema contracts, change package versions, or authorize deployment.

## Accepted finding

The runtime authorization logic was fail-closed, but the validator returned only `roles`. TypeScript therefore could not narrow the original possibly undefined/null document value in two consumers:

- `functions/src/notifications.ts`: two `data is possibly undefined` errors;
- `functions/src/runtimeJobModulePopulation.ts`: one nullable map return error.

## Correction

`CanonicalApprovedUserAuthority` now carries the exact document map that passed validation as `authority.data`. Consumers use that validated map for token access and for the non-null runtime-population result. The authority predicate, accepted roles, alias rejection, and runtime decisions are unchanged.

## Gate improvement

The local laboratory now runs a no-emit Functions typecheck immediately after `functions/npm ci`, before Firebase CLI, Flutter, Isar, emulator, or APK work:

```text
08_functions_typecheck
npm run build -- --noEmit --pretty false
```

A compile failure is sealed as `HOLD_FUNCTIONS_TYPECHECK`. The complete Functions test stage remains later and still recompiles before Jest.

## Harness parser custody

A latent PowerShell interpolation defect in the private-registry rejection message (`$rel:`) was also corrected to `${rel}:`. This prevents the harness from failing at parse time before any gate executes.

## Safety

No Git mutation, Firebase deploy, backend write, device install, uninstall, or data clear is included. The candidate remains blocked until the Windows authoritative laboratory executes successfully.
