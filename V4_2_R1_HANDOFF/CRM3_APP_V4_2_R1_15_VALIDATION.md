# CRM3 App v4.2_R1.15 — Validation Boundary

## Proven in the packaging environment

- R1.14 evidence ZIP and sidecar hash match.
- R1.14 evidence candidate manifest exactly matches the supplied R1.14 candidate.
- The sole Flutter failure is the obsolete four-allow maintenance Rules expectation.
- R1.14 product source and Firestore Rules remain unchanged.
- The replacement contract requires one routed update and all four governed validators.
- Python source audits, structural audits, policy generation, reconstruction and package-manifest checks execute successfully.

## Not proven in the packaging environment

The packaging environment has no Flutter SDK or Firebase emulator. It cannot claim:

- the complete Flutter suite passes after R1.15;
- Firestore Rules compile in the emulator;
- 122/122 Rules tests pass;
- governed Functions emulator suites pass;
- APK construction passes.

These claims require the fresh Windows authoritative run with `-RunEmulators`.

## Release boundary

R1.15 is a local-laboratory candidate only. It creates no Git integration, Firebase deployment, signing, device installation or production authority.
