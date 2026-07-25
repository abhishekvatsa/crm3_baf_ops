# v4.2_R1.4 Validation Record

## Accepted execution evidence

The R1.3 Windows evidence package proved:

- pristine and disposable-copy custody;
- root dependency install and zero-advisory audit;
- Functions dependency install and zero-advisory audit;
- real Functions TypeScript compilation;
- Firebase CLI dependency installation.

It stopped at the Firebase CLI audit, which reported the locked `@hono/node-server` 2.0.5 and `fast-uri` 3.1.3 packages.

## R1.4 bounded correction

- `firebase-tools` remains pinned at 15.22.4.
- `@hono/node-server` is declared and locked at 1.19.14 with exact public-registry URL and SHA-512 integrity.
- `fast-uri` is declared and locked at 3.1.4 with exact public-registry URL and SHA-512 integrity.
- The installed MCP SDK continues to request `@hono/node-server` through `^1.19.9`.
- Root and Functions lockfiles are byte-identical to R1.3.
- Flutter, Functions, Rules, Isar, Android and governance product source are byte-identical to R1.3.
- The R1.3 type-safe authority correction is retained unchanged.

## Static validation completed in packaging environment

- v4.2_R1 canonical audit: 25/25 pass;
- v4.2 ultimate audit: 17/17 pass;
- v4.1 due-diligence audit: 9/9 pass;
- whole-app reconciliation audit: 21/21 pass;
- inherited full-tree audit: 18/18 pass;
- inherited expanded audit: 15/15 pass;
- Dart structural audit: pass over 369 Dart files;
- integrity-sweep unit tests: 3/3 pass;
- generated workflow policy check: pass;
- all 410 canonical-main captured paths present and package-pinned;
- private/internal registry URLs in npm lockfiles: zero;
- PowerShell delimiter/interpolation structural scan: pass;
- deployment/destructive command scan: pass.

## Authoritative boundary

The packaging environment cannot execute PowerShell or complete a public-registry `npm ci`/`npm audit`. Therefore it does not claim that the tooling advisory is closed merely from lockfile construction. The exact Windows R1.4 laboratory must prove:

1. Firebase CLI lock-policy PASS;
2. dependency installation PASS;
3. exact installed-version PASS;
4. strict audit PASS;
5. all later Flutter, Isar, Functions-test, APK and emulator gates.
