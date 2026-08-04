# Build 8 F4 Sync Marker and Offline/Reconnect

Status: SYNC MARKER PROVED; EXACT-TARGET OFFLINE/RECONNECT PROPOSED

## Sync result

The privacy-minimized physical receipt
`build8-f4-sync-retry-receipt.json` is retained outside the repository. Its
SHA-256 is
`304F9F4D9CBA6DAD71B2FBF9B26B17F32C2830C1AFD74316B283E44A83ED9E8E`.
The repository adjudication binds that exact file without retaining its local
path, device serial, account identity, raw UI or business payload.

The receipt proves that:

- clean `main` matched `origin/main` at
  `4dc54ad6a08029092b4aa90dcebd27b1864e8a6b`;
- post-merge release-gate run `30864309478` passed;
- the production backend remained ready with no missing or malformed
  watermarks;
- the exact production-signed Build 8 APK remained installed on the bound
  physical device;
- the approved session reached its role-appropriate Home surface;
- pending local writes and unresolved rejections were zero before and after;
  and
- ordinary manual sync returned `SUCCESS`.

The adjudication decision is
`PASS_BUILD8_F4_SYNC_MARKER_ADJUDICATED`. This proves the F4 sync-marker
criterion only. It does not close F4 or authorize distribution.

## Offline/reconnect phase

`release/approvals/build-8-f4-offline-reconnect-promotion.json` authorizes one
separate physical phase after merge and one successful four-job post-merge
release-gate run. The harness re-verifies the external sync receipt, backend,
artifact, signer, package, installed APK, target, install times, approved
session and zero local pending-work state before changing transport settings.

The phase captures the current Wi-Fi, mobile-data and airplane-mode values. It
temporarily disables Wi-Fi and mobile data while leaving airplane mode
unchanged, requires the app not to report a false successful sync while fully
disconnected, and restores the exact initial Wi-Fi and mobile-data values in a
`finally` block. Restoration is read back across all three settings before any
pass is possible. After reconnection, the app must complete manual sync and
return to zero pending writes and zero unresolved rejections.

A false offline success, observation failure, restoration failure, imperfect
readback or reconnect failure produces an append-only failure receipt. Such a
receipt cannot be relabelled as a pass.

## Safety boundary

This phase does not install, upgrade, downgrade, uninstall or clear the app. It
does not change airplane mode, proxy, DNS, VPN or traffic shaping; alter the
authentication session; create business data; deploy Firebase resources;
mutate IAM; enable App Check; or distribute Build 8. Raw UI, raw device and
network identifiers, account identity and business payload are not retained.

`STAGE2D-F4`, `P-07`, pilot handout and external distribution remain open or
unauthorized. Weak-network, revocation and wrong-role execution require
separate source authority after this result is independently adjudicated.
