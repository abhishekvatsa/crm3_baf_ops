# Build 8 F4 Offline/Reconnect Result

Status: OFFLINE/RECONNECT PROVED; F4 REMAINS OPEN

The exact-target Build 8 offline/reconnect phase ran from clean merged `main`
at `a9028efc12e83a303acd802fcec4b673ba8b7780` after all four jobs in
post-merge release-gate run `30932769330` passed. The external receipt is
bound by SHA-256
`BE414FFFD556F0F5DEC741BF5598EFC9670524DF6DDCC68833572A192C8A3A77`
without retaining its local path or raw device, account, UI or business data.

## Observed result

- The production-signed Build 8 APK, signer, package, version and preserved
  install times remained exact.
- The approved session reached the role-appropriate Home surface with no
  forbidden authentication or authority marker.
- Pending local writes and unresolved rejections were `0/0` before the phase.
- Wi-Fi/mobile-data/airplane-mode began as `on/off/off`.
- Wi-Fi and mobile data were both disabled for a measured 39.461 seconds.
- The disconnected sync observation timed out without a success marker; no
  false completed mutation was reported.
- The exact `on/off/off` transport state was restored and read back.
- Post-reconnect manual sync returned `SUCCESS`.
- Pending writes and unresolved rejections remained `0/0` afterward.
- No failure receipt or temporary artifact remained, and the app was not
  installed, upgraded, cleared or uninstalled.

The adjudication decision is
`PASS_BUILD8_F4_OFFLINE_RECONNECT_ADJUDICATED`.

## Method qualification

This proves safe offline behavior, exact transport restoration and reconnect
recovery. It does not claim measured low bandwidth, added latency or packet
loss. The repository's next `weak-network` method is more precisely a bounded
three-cycle intermittent-connectivity profile. Its evidence can establish
recovery across repeated transport loss, but must not be described as a
bandwidth-throttling result.

## Programme boundary

Approved sign-in, sync marker and offline/reconnect are now evidenced for
Build 8. Weak/intermittent network, revocation next-operation denial and
wrong-role denial remain outstanding. `STAGE2D-F4`, `P-07`, pilot handout and
distribution remain open or unauthorized.
