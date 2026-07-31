# Build 6 F4 Emulator Rehearsal Promotion

## Decision

The finalized Build 6 production-signed APK is promoted to one exact Pixel 9
API 36 Android virtual device for a bounded runtime rehearsal.

This is a post-build promotion because Build 6 finalization deliberately left
the artifact non-distributable. The promotion is bound to the governed package
hash, embedded APK hash, source commit, production signer and the already
governed `Pixel_9` / `emulator-5554` target.

## Purpose

Build 5 exposed a first-listener identity-token race after a fresh production
Google Sign-In. PR 77 corrected the source, and Build 6 is the first finalized
production-signed artifact that contains that correction.

The rehearsal proves that the exact successor artifact can:

1. replace exact Build 5 in place under the same production signer;
2. preserve the existing app sandbox;
3. perform an explicit in-app sign-out;
4. complete a fresh production-certificate Google Sign-In; and
5. reach approved home in the same app process without the prior own-profile
   permission-denied surface.

## Boundary

The emulator is useful for regression proof and validation-harness hardening,
but it is not a physical device. This tranche therefore:

- does not create `DEVICE_PROVED` evidence;
- does not close `STAGE2D-F4` or `P-07`;
- does not create a sync marker or run offline, weak-network, revocation or
  wrong-role mutations;
- does not authorize a physical-device install;
- does not authorize pilot handout or any external distribution; and
- does not deploy or alter Firebase, Rules, Functions, IAM, App Check, roster
  or user authority.

The programme ledger remains unchanged: `STAGE2D-F4` stays `OPEN`,
`nextMutation` stays `STAGE2D-F4`, and pilot handout stays
`NOT_AUTHORIZED`.

## Execution

`tools/release/Invoke-Build6F4EmulatorRehearsal.ps1` fails closed around:

- exact clean `main == origin/main`;
- the merged promotion record;
- governed-package and embedded-APK identity;
- production signer, package and version;
- exact AVD identity and Google Play Services;
- exact installed Build 5 provenance;
- same-signer in-place upgrade only;
- immutable evidence phases; and
- privacy-minimized receipts that retain no account email, display name or
  Firebase uid.

Physical-device promotion and the full F4 matrix remain a separate,
named-target authority tranche.

## Interrupted Upgrade Finalization

The first governed `Upgrade` invocation successfully extracted and verified the
exact embedded APK, completed the same-signer `adb install -r`, verified exact
installed Build 6 and confirmed that the original package first-install time
was preserved. It then stopped before writing `upgrade-receipt.json` because
Android's first UI-automation dump returned no remote file.

Read-only inspection proved version code 6 and the exact APK hash were installed
with the original first-install timestamp. A subsequent UI dump succeeded.

The hash-linked amendment permits only `FinalizeUpgrade` against the exact
interrupted evidence directory. That phase:

- refuses a reinstall, uninstall or data clear;
- re-verifies the extracted and installed APK, package, version and signer;
- requires the preserved first-install timestamp;
- captures the now-available UI state; and
- writes the missing upgrade receipt with explicit recovery lineage.

The incident and recovery do not expand the artifact, target, remote mutation or
programme boundary.
