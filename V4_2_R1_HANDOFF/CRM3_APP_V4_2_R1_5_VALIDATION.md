# v4.2_R1.5 Validation Record

## R1.4 execution adjudication

The submitted evidence ZIP and sidecar matched exactly. The trial status was `HOLD_FIREBASE_CLI_LOCK_POLICY`. Steps 01–09 passed, including real Functions TypeScript compilation and zero-advisory root/Functions audits. Step 10 failed while parsing the npm lockfile and did not evaluate its eleven dependency-policy checks.

## Accepted root cause

The critic's parser diagnosis is accepted because it is directly confirmed by both the R1.4 transcript and source:

- `package-lock.json` contains `packages[""]`;
- R1.4 used `ConvertFrom-Json` without `-AsHashTable`;
- PowerShell 7.6.4 reported the exact empty-property-name error.

## Static validation completed for R1.5

- JSON-equivalent evaluation of all eleven Firebase CLI lock-policy checks: PASS;
- package lock contains the empty-string root key: confirmed;
- harness uses `ConvertFrom-Json -AsHashTable`: confirmed;
- dictionary/object accessor regression check: PASS;
- direct `$lock.packages` access: absent;
- all product and dependency files compared with R1.4: byte-identical;
- canonical R1 audit, inherited audits and structural scans: PASS;
- internal SHA-256 manifest and ZIP integrity: PASS.

## Unclaimed gates

PowerShell runtime execution, Firebase CLI installation/version/audit, Flutter dependency resolution, authentic Isar generation, Flutter analysis/tests, APK construction and emulators remain unclaimed until the Windows R1.5 run completes.
