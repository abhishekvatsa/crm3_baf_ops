# v4.2_R1.5 Firebase CLI Lock-Policy Parser Hotfix

## Evidence accepted

The authoritative R1.4 Windows run passed candidate/workspace custody, integrity tests, root dependency installation and audit, Functions dependency installation, real TypeScript compilation, and Functions audit. It stopped at `10_firebase_cli_lock_policy` before evaluating any policy check.

The exact error was:

```text
The provided JSON includes a property whose name is an empty string, this is only supported using the -AsHashTable switch.
```

npm package-lock v2/v3 represents the root package under `packages[""]`. PowerShell `ConvertFrom-Json` cannot materialize that key as a PSCustomObject property; `-AsHashTable` is required.

## Bounded correction

Only laboratory/audit/runbook source changes:

- parse `tooling/firebase-cli/package-lock.json` using `ConvertFrom-Json -AsHashTable`;
- make `Get-JsonPropertyValue` support both `IDictionary` and PSCustomObject values;
- retrieve the lockfile `packages` map and all package fields through the shared accessor;
- fail closed if the lockfile lacks a `packages` map;
- add a packaging-time regression assertion for the empty-key-safe parser;
- advance laboratory evidence naming to R1.5.

No Flutter, Functions, Rules, Isar, Android, dependency, lockfile, workflow-policy, programme-ledger, Firebase configuration, or release-authority source changed from R1.4.

## Authority boundary

The packaging environment has no PowerShell runtime and therefore does not claim a PowerShell execution pass. The corrected Windows R1.5 laboratory must execute the gate and continue into dependency, Flutter, Isar, APK and emulator stages.
