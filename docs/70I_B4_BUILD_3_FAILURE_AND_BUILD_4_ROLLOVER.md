# 70I-B4 Build 3 Failure and Build 4 Rollover

## Decision

Android build number 3 is permanently consumed. Build number 4 is the next
approved production-candidate construction attempt.

This record does not approve Firebase deployment, controlled-pilot
distribution, or unrestricted plant release.

## Consumed build 3

- GitHub run: `30397899144`
- Run URL:
  `https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/30397899144`
- Exact commit: `a808376dbc4d2e4b198127e2d66fc698daac800e`
- Reservation tag: `crm3-build-reserved/3`
- Reservation tag object: `43b6bc2da1beb7f90bc8f3bc82ebc961a5fc48d6`
- Result: failure
- Failed step: `Build once and independently verify`
- Production keystore restored: yes
- Production-signed APK constructed: yes
- Production-signed AAB constructed: yes
- Independent package verification completed: no
- Governed package uploaded: no
- Built tag created: no

The source release gate, clean Android dependency preflight, atomic build-number
reservation, production keystore restoration, bundletool and approved Linux
Isar-core checks all passed. The production-signed APK and AAB then built.

Independent package verification failed when PowerShell executed a
line-broken property-comparison invocation:

```powershell
Where-Object reservationId -eq
  [string]$manifest.versionPolicy.reservationId
```

PowerShell treated `-eq` as lacking its required value. The upload step was
skipped, no governed package left GitHub Actions, and no distribution occurred.

The reservation tag remains authoritative. Build number 3 must never be reused.

## Corrected boundary

The verifier now selects ledger records through a script-block comparison in a
reusable function. Its self-test executes that exact function with deterministic
fixture records.

The source production-policy validator invokes the verifier self-test. The
protected production workflow already executes the policy validator before
build-number reservation, and the pull-request release gate now runs the same
policy path. The specific runtime defect that consumed build 3 must therefore
fail in source CI and again before any future reservation.

## Build 4 authority

- Version: `1.0.0-rc.1+4`
- Release ID: `crm3-baf-ops-1.0.0-rc.1-b4`
- Reservation ID: `crm3-baf-ops-o1-o5-v4-a808376-b4-4`
- Reservation tag: `crm3-build-reserved/4`
- Built tag: `crm3-build-built/4`
- Approval: `release/approvals/build-number-4-rollover-approval.json`

The build-4 reservation tag does not exist until the protected workflow creates
it after this source repair is merged to exact live `main`.
