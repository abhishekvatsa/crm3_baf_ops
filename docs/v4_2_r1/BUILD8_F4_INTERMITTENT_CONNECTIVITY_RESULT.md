# Build 8 F4 Intermittent-Connectivity Result

Status: INTERMITTENT CONNECTIVITY PROVED; F4 REMAINS OPEN

The exact-target Build 8 intermittent-connectivity phase ran from clean merged
`main` at `b0ca32cf492efecd2a6eb58372883f10191eaeb1` after all five jobs in
post-merge release-gate run `31030200224` passed. The external receipt is
bound by SHA-256
`4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC`
and byte length `8119` without retaining its local path or raw device,
account, UI, network-identifier or business data.

## Controlled-stop lineage

The first physical run completed all three cycles and restored the exact
transport state, but its 233.35-second profile exceeded the original
180-second total ceiling. Its failure receipt remains a failure and is bound
by SHA-256
`C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435`.
The admitted amendment changed only the internally inconsistent total ceiling
to 300 seconds. It did not add a cycle, broaden a mutation, authorize a new
target or relabel the failed receipt.

## Observed result

- The production-signed Build 8 APK, signer, package, version and preserved
  install times remained exact.
- The approved session reached the role-appropriate Home surface with no
  forbidden authentication or authority marker.
- Pending local writes and unresolved rejections were `0/0` before the phase.
- Wi-Fi/mobile-data/airplane-mode began as `on/off/off`.
- Three required transport-loss cycles completed in 234.083 seconds, below
  the admitted 300-second ceiling.
- Every disconnected observation timed out without a success marker; no false
  successful sync was reported while all transports were disabled.
- Each cycle restored and read back the exact `on/off/off` transport state.
- Each post-reconnect sync returned `SUCCESS`.
- Pending writes and unresolved rejections remained `0/0` after every cycle
  and after the complete profile.
- The evidence directory retained only the passing receipt. No failure receipt
  or temporary device artifact remained.
- The app was not installed, upgraded, cleared or uninstalled, and no
  production business write was attempted.

The adjudication decision is
`PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_ADJUDICATED`.

## Method qualification

The governed roadmap accepts bounded three-cycle intermittent connectivity as
the F4 weak-network method. This result therefore proves that criterion for
Build 8. It does not claim measured low bandwidth, added latency, injected
packet loss or a bandwidth-throttling result.

## Programme boundary

Approved sign-in, sync marker, offline/reconnect and the accepted weak-network
criterion are now evidenced for Build 8. Revocation next-operation denial and
wrong-role denials remain outstanding. `STAGE2D-F4`, `P-07`, pilot handout and
distribution remain open or unauthorized.
