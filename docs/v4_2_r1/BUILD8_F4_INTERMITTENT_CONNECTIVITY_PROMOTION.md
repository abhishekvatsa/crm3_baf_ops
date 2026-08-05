# Build 8 F4 Intermittent-Connectivity Promotion

Status: SOURCE AUTHORIZED; PHYSICAL EXECUTION PENDING

## Basis

Build 8 already has exact-target evidence for approved sign-in, an ordinary
production sync marker, and offline/reconnect recovery. The offline result
restored the device's exact Wi-Fi, mobile-data and airplane-mode state and was
adjudicated as `PASS_BUILD8_F4_OFFLINE_RECONNECT_ADJUDICATED`.

The remaining gate item historically called `weak-network` is narrowed here
to a bounded three-cycle intermittent-connectivity profile. This method tests
repeated transport loss and recovery. It does not claim low bandwidth, added
latency, injected packet loss, or traffic shaping.

## Authorized phase

After this source is merged, an exact successful five-job `release-gate` push
run must exist for the merged commit. Execution must then start from clean
`main` equal to freshly fetched `origin/main` and reverify:

- the sealed Build 8 package, embedded APK, signer and built tag;
- the installed APK and preserved install times on the bound Samsung target;
- the production backend-ready and offline/reconnect adjudications;
- the external offline receipt by SHA-256 and byte length;
- the approved current session; and
- zero pending local business writes and zero unresolved rejections.

The harness runs exactly three cycles. Each cycle disables Wi-Fi and mobile
data while leaving airplane mode unchanged, holds the disconnected state,
rejects a false successful sync, and restores the exact initial transport
state in a `finally` block. Restoration is read back before the next cycle.
After each restoration the harness requires a successful sync and returns to
zero pending writes and zero unresolved rejections.

A `PreflightOnly` mode performs every source, CI, evidence, artifact, signer,
target, installed-app, session and local-diagnostics check without changing
network state. Temporary governed and installed APK copies are covered by the
outer cleanup boundary even when artifact or device preflight stops early.

One privacy-minimized pass or failure receipt is written outside the
repository with create-new semantics. Temporary APK and raw UI files are
removed. Any restoration, source, artifact, receipt, session, duration, or
diagnostic mismatch fails closed and cannot be relabelled as a pass.

## Controlled duration stop

The first merged execution from `e91dedde967fbe79d3f80d3375b299d79d5d8c77`
completed all three cycles and restored exact `Wi-Fi on / mobile data off /
airplane mode off` transport, but correctly stopped because the measured
233.35-second profile exceeded the original 180-second ceiling. The external
820-byte failure receipt remains a failure and is bound by SHA-256
`C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435`.

The original total ceiling was internally inconsistent with three cycles that
each allowed up to 120 seconds for a new recovery sync. The append-only
amendment raises only the total ceiling to 300 seconds, records each cycle's
duration, includes cycle summaries in any duration failure, and requires the
exact prior failure receipt for read-only preflight and retry. This does not
convert the stopped run into a pass or expand runtime or programme authority.

## Boundary

This source does not install, upgrade, clear, downgrade or uninstall the app.
It does not change airplane mode, proxy, DNS, VPN, backend resources, IAM, App
Check, user approval, or roles. It does not create production business data,
authorize pilot handout, distribute Build 8, or close `STAGE2D-F4` or `P-07`.

Revocation and wrong-role evidence remain separate authority-changing phases.
They are not authorized by this promotion and remain outstanding after a
successful intermittent-connectivity result.
