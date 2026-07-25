# CRM3 App v4.2_R1.14 — Validation Boundary

## Proven in the packaging environment

- R1.13 evidence hash and failure stage independently verified.
- Exact 19-failure classification established from the sealed emulator log.
- Direct online job-module transition parity statically verified.
- Full approved-user document validation retained.
- Firestore transition routing and single-family-read structure verified.
- Rules/test field parity verified.
- Python source audits, structural audits, policy generation and manifest/reconstruction checks executed.

## Not proven in the packaging environment

The packaging environment has no Flutter SDK and cannot reach npm/Firebase artifact services. It therefore cannot claim:

- Firestore Rules compilation by the emulator;
- the 122 Rules tests passing;
- governed Functions emulator tests passing;
- `flutter analyze` or the complete Flutter suite passing after R1.14;
- APK construction.

Those claims require the fresh Windows authoritative run in the R1.14 runbook.

## Release boundary

R1.14 is a local-laboratory candidate only. No Git integration, Rules deployment, Functions deployment, signing, device installation or production authorization is implied.
