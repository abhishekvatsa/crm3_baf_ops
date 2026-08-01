# Build 6 F4 Physical-Device Target Discovery

## Decision

Build 6 may be inspected against one connected physical Android device to
create a privacy-minimized target candidate for the F4 campaign. This tranche
does not authorize installation or F4 execution.

The split is deliberate. A physical-device promotion must be bound to an exact
target, but the target identity cannot be known before a device is connected.
Giving installation authority to an unbound serial would make the channel wider
than the one-device programme boundary.

## Discovery Boundary

`tools/release/Invoke-Build6F4PhysicalDeviceTargetDiscovery.ps1` performs only:

1. exact clean-main and merged-approval verification;
2. governed Build 6 package, APK, package/version and signer verification;
3. one connected target's read-only Android property inventory;
4. independent emulator rejection through QEMU and identity markers;
5. Google Play Services and APK minimum-SDK compatibility checks;
6. confirmation that the CRM-III package is absent; and
7. creation of a privacy-minimized receipt outside the repository.

The receipt stores SHA-256 values for the ADB serial and build fingerprint. It
does not store the raw serial, Android ID, Google account, email, Firebase uid,
or business data.

## Explicit Non-Authority

This discovery step cannot:

- install, replace, remove, launch or clear the application;
- interact with the device UI;
- create Google or Firebase authentication state;
- read or write Firebase or business data;
- mutate approval, revocation or roles;
- close `STAGE2D-F4` or `P-07`; or
- authorize pilot handout or external distribution.

The programme ledger therefore remains unchanged. `STAGE2D-F4` stays `OPEN`,
`nextMutation` stays `STAGE2D-F4`, and pilot handout stays `NOT_AUTHORIZED`.

## Execution Prerequisites

Use one owner-controlled physical Android test device with USB debugging
enabled. The device must expose Google Play Services and must not already have
`in.co.sail.bsl.crm3.bafops` installed. An emulator, a device with an existing
CRM-III package, or an untrusted/unauthorized ADB target is a stopping condition.

The governed Build 6 package remains outside the repository. Evidence must also
be written to a new or empty directory outside the repository.

After this tranche is merged to `main`, run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\release\Invoke-Build6F4PhysicalDeviceTargetDiscovery.ps1" `
  -GovernedPackagePath "<absolute-path-to-build-6-governed-package>" `
  -DeviceSerial "<adb-serial>" `
  -EvidenceDirectory "<private-evidence-directory-outside-repository>"
```

## Next Promotion

A passing receipt is input to a separate owner-reviewed promotion. That later
record must bind the exact hashed device identity, exact Build 6 artifact and
each authorized F4 phase. It must also define the approved sign-in, sync-marker,
offline/reconnect, weak-network, revocation and wrong-role evidence sequence.

No installation or F4 runtime step may begin under this discovery approval.

## Package-Absence Compatibility Correction

The first tracked physical-target invocation stopped safely before producing a
receipt. The exact Build 6 artifact and preliminary physical-device checks had
passed, but Samsung package manager represented the absent CRM-III package as
exit code `1` with empty output. The original harness accepted only exit code
`0`, so it classified absence as unproved.

The amended classifier accepts package absence only when output is empty and
the exit code is either `0` or `1`. It still fails closed when a package path is
returned, when output is nonempty but unrecognized, or when any other exit code
is observed. This is a platform-compatibility correction only; it does not
authorize installation, launch, authentication, remote mutation, F4 execution
or gate closure. The interrupted local directories contain only the extracted
governed APK and create no device evidence.
