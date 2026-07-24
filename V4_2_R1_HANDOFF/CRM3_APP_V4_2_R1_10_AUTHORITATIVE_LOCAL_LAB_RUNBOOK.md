# CRM3 v4.2_R1.10 authoritative local-laboratory runbook

## Boundaries

The laboratory operates only in a disposable copy. It performs no Git push, merge, tag, Firebase deployment, production write, application uninstall or device-data clear.

## Purpose of R1.10

R1.10 preserves every R1.9 application byte and aligns stage 20 with the authentic code-generation sequence. The post-codegen canonical audit now exact-binds all 19 generated Isar bindings to hashes captured in the authenticated R1.9 Windows run. It does not silently exclude generated files.

## Invocation

Run the packaged `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1` with:

```powershell
& $Script.FullName `
  -CandidatePath $Candidate.FullName `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -EvidenceRoot "$HOME\Downloads" `
  -RunEmulators `
  -EmulatorPort 8180
```

Expected evidence prefix:

`CRM3_V42_R1_10_CANONICAL_LOCAL_LAB_`

## Next unknown gates

R1.9 proved stages 01–19. R1.10 must still prove stage 20 onward, including the inherited audits, Functions tests, `flutter analyze`, Flutter tests, APK construction and emulator campaign. No result is presumed before execution.
