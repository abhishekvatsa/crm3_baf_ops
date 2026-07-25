# CRM3 App v4.2_R1.11 — Evidence Adjudication

The submitted evidence ZIP SHA-256 is:

`67DA45E9A013F31D96928EEF5D65515692F339F97D705F6E993A9BF11AFC0962`

The evidence records PASS for stages 01–28, including:

- all candidate/workspace custody checks;
- three npm installations and zero-vulnerability audits;
- Functions TypeScript compilation;
- Firebase CLI policy, installed-version and load-smoke checks;
- Flutter dependency resolution;
- authentic Isar generation;
- post-codegen custody;
- semantic Isar continuity and release authority;
- all inherited/static audits;
- Functions tests: 237 passed, 29 emulator-dependent skipped.

The sole failed stage was `29_flutter_analyze`, which reported 18 source diagnostics. These findings are accepted. They comprise seven compile/analyzer errors, three warnings and eight infos. R1.12 addresses all 18 without weakening analyzer severity or bypassing the gate.

No remote Git mutation, Firebase deployment, production-data mutation, device uninstall, or device-data clear occurred.
