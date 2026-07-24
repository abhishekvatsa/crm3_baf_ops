# CRM3 App v4.2_R1.6 — Firebase CLI Hono and Parallel Verdict Hotfix

## Evidence basis

The R1.5 Windows evidence passed steps 01–12 and stopped at the strict Firebase CLI audit. The audit identified `@hono/node-server <2.0.5` through `@modelcontextprotocol/sdk`. R1.3 had separately shown the WebSocket-handshake advisory affecting `2.0.0` through `2.0.9`. The common patched floor is therefore `2.0.10`.

## Bounded source correction

- `firebase-tools` remains `15.22.4`.
- `fast-uri` remains `3.1.4`.
- `@hono/node-server` override changes from `1.19.14` to `2.0.10`.
- The tooling lock entry is pinned to the public npm tarball and exact SHA-512 integrity.
- The MCP SDK declared range `^1.19.9` is still recorded; the forced major override is therefore explicitly load-smoked before emulator use.

## Laboratory structure correction

The Firebase CLI audit remains a mandatory authoritative gate, but its verdict is recorded without stopping downstream application evidence. A recorded advisory hold:

- does not become PASS;
- remains in `trial-result.json` under `recordedHolds`;
- makes the final status HOLD even if Flutter, Isar, APK and emulator gates pass;
- never authorizes Firebase deployment or production writes.

This prevents external advisory churn from suppressing information about the application while retaining strict release governance.

## No product expansion

No Flutter, Functions, Rules, Isar, Android, Firebase identity, workflow-policy, programme-ledger or release-authority behaviour changed.
