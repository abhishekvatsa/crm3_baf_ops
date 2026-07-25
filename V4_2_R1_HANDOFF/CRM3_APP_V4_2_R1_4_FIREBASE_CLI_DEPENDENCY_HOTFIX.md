# v4.2_R1.4 Firebase CLI Dependency Hotfix

## Scope

R1.4 corrects only the governed Firebase CLI tooling tree that stopped the R1.3 Windows laboratory at `11_firebase_cli_npm_audit`. It does not modify Flutter application source, Functions source, Firestore Rules, Isar models, Android configuration, workflow policy, or deployment authority.

## Evidence accepted from R1.3

The Windows run proved candidate custody, root and Functions dependency installation/audit, and the real Functions TypeScript compiler. It then reported four advisories in the separate Firebase CLI tooling tree: the locked `@hono/node-server` 2.0.5 and `fast-uri` 3.1.3 packages.

## Bounded correction

- `firebase-tools` remains exactly `15.22.4`.
- `@hono/node-server` changes from the explicit 2.0.5 override to 1.19.14. This remains inside the installed MCP SDK's natural `^1.19.9` dependency range rather than forcing a different major line.
- `fast-uri` changes from 3.1.3 to 3.1.4.
- Only `tooling/firebase-cli/package.json` and the two corresponding package entries in its lockfile carry dependency changes.
- Package artifact URLs and SHA-512 integrity values are pinned and checked before installation.

## Gate strengthening

The laboratory now runs, in order:

1. exact Firebase CLI lock-policy verification;
2. `npm ci`;
3. exact installed-version verification;
4. strict `npm audit --audit-level=low`.

Failures are separately classified as:

- `HOLD_FIREBASE_CLI_LOCK_POLICY`;
- `HOLD_FIREBASE_CLI_DEPENDENCY_VERSION`;
- `HOLD_FIREBASE_CLI_DEPENDENCY_AUDIT`.

No audit relaxation or blind `npm audit fix` is used.

## Safety

The laboratory remains disposable and read-only toward the canonical repository and Firebase. No remote Git mutation, Firebase deployment, production write, uninstall, or data clear is authorized.
