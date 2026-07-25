# v4.2_R1.6 validation record

## Proven from the submitted R1.5 Windows evidence

- Candidate and workspace custody passed.
- Root and Functions installs/audits passed.
- Functions TypeScript compilation passed.
- Firebase CLI lock-policy parsing and all eleven checks passed.
- Firebase CLI installation and exact installed-version assertion passed.
- The strict CLI audit correctly held on `@hono/node-server 1.19.14`.

## R1.6 package-level validation performed here

- bounded package manifest and lock entry agree on `2.0.10`;
- public npm URL and supplied SHA-512 integrity are exact;
- `firebase-tools` remains `15.22.4` and `fast-uri` remains `3.1.4`;
- PowerShell structural scanner passes;
- canonical R1 audit passes;
- inherited audit families pass;
- internal SHA-256 manifest verifies;
- ZIP extraction is byte-identical to the source tree.

## Deliberately not claimed here

This environment did not execute `npm ci`, `npm audit`, the Firebase CLI, Flutter, build_runner, APK construction or emulators. The R1.6 Windows laboratory is authoritative for those gates.
