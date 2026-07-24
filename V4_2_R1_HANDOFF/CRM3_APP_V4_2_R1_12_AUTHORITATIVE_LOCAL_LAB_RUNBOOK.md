# CRM3 App v4.2_R1.12 — Authoritative Local Laboratory

Run the candidate only through the included `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1` companion.

The companion:

- verifies candidate and copied-workspace manifests;
- works only in a disposable workspace;
- performs no Git remote mutation or Firebase deployment;
- runs dependency, compiler, audit, code-generation, custody, analyzer, Flutter-test, APK and optional emulator gates;
- seals evidence before returning PASS, HOLD, or FAIL.

Expected SHA-256 is supplied in the adjacent sidecar. The authoritative run should use Flutter 3.44.0, Dart 3.12.0, Node 22.15.0, npm 10.9.2 and Java 21.0.11.

R1.12 specifically requires `29_flutter_analyze` to pass before Flutter tests or APK construction may proceed.
