# v4.2_R1.3 Validation Record

## Accepted defect

R1.1/R1.2 contained three real TypeScript compile errors caused by control-flow narrowing across the centralized authority validator:

- two `TS18048` errors in `functions/src/notifications.ts`;
- one `TS2322` error in `functions/src/runtimeJobModulePopulation.ts`.

## Corrective validation

- The canonical authority result now carries the exact validated document map as `authority.data`.
- Both notification token lookup paths use the validated map.
- Runtime module population returns the validated non-null map.
- The authority regression test proves the validated map is retained.
- A strict targeted TypeScript compile passed for `userAuthority.ts` and `notifications.ts`.
- A strict targeted TypeScript compile passed for `runtimeJobModulePopulation.ts` with only local Node built-in type stubs.
- The laboratory classifies an early compiler failure as `HOLD_FUNCTIONS_TYPECHECK` and seals evidence before exit.
- The complete harness scan contains no unsafe `"$variable:"` interpolation form; the private-registry message uses `${rel}:`.
- A direct runtime smoke test passed for canonical approval, malformed-authority rejection, missing-document handling, role filtering and token lookup.
- A whole-project TypeScript invocation without installed dependencies confirmed the original three source errors are absent; remaining diagnostics were solely expected missing Node/Firebase dependency typings in the packaging environment.

## Static gates

- integrity-sweep unit tests: 3/3 pass;
- v4.2_R1 canonical audit: 22/22 pass;
- v4.2 audit: 17/17 pass;
- v4.1 audit: 9/9 pass;
- whole-app audit: 21/21 pass;
- inherited full-tree audit: 18/18 pass;
- inherited expanded audit: 15/15 pass;
- Dart structural audit: pass across 369 Dart files;
- generated workflow policy check: pass;
- private/internal registry URLs in npm lockfiles: zero.

## Remaining authoritative boundary

The complete dependency-backed Functions compiler/tests, Flutter analysis/tests, authentic Isar generation, emulators and APK build must still execute in the Windows local laboratory. This package does not claim those gates have run here.
