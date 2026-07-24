# CRM3 App v4.2_R1.13 — Authoritative Local Laboratory Runbook

## Preconditions

- Use the pristine R1.13 candidate ZIP and verify its supplied SHA-256 sidecar.
- Use the governed Windows toolchain already pinned by the candidate.
- Provide the exact governed Firebase inputs through `-CurrentAppRoot` or explicit file parameters.
- Do not edit the candidate, reuse an R1.12 workspace, or copy a downloaded Isar DLL manually into the workspace.

## Invocation

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42R1CanonicalLocalLab.ps1" `
  -CandidatePath "." `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -Mode Authoritative
```

Add `-RunEmulators`, `-InstallOnCleanDevice` and `-DeviceId` only when those downstream gates are deliberately authorized and available.

## R1.13 sequence change

After `flutter analyze`, the harness now:

1. runs `30_isar_test_core_custody`;
2. stages and records the exact locked Windows AMD64 `isar.dll`;
3. sets `CRM_ISAR_CORE_PATH` and `CRM_ISAR_CORE_REQUIRED=1` for the test process;
4. runs `31_flutter_tests` with no Isar network fallback;
5. proceeds to APK/emulator/device stages only if all tests pass.

## Acceptance rule

Only a newly sealed `PASS_LOCAL_LAB` package from the pristine R1.13 bytes may authorize the next governed step. A partial pass, diagnostic mode, retained hold, skipped test suite, resumed workspace, or failure followed by manual continuation is not authority.
