# v4.2_R1.2 Lockfile Registry-Custody Hotfix

## Trigger

The first authoritative Windows laboratory run stopped at `05_root_npm_ci` while attempting to download a package from an internal OpenAI Artifactory hostname. The hostname was embedded in several `resolved` entries in the three committed npm lockfiles.

## Root cause

Dependency remediation performed in the packaging environment rewrote a limited set of lockfile `resolved` URLs to the environment's private registry. Integrity hashes and package versions were not implicated, but the URLs were not portable to the user's machine.

## Correction

- Replaced every private registry prefix in:
  - `package-lock.json`
  - `functions/package-lock.json`
  - `tooling/firebase-cli/package-lock.json`
  with the corresponding public `https://registry.npmjs.org` tarball URL.
- Preserved package versions and `integrity` values.
- Added a pre-install lockfile-custody gate that fails before `npm ci` if the private/internal registry hostname reappears.
- Added bounded npm network retries.
- Added precise outcomes:
  - `HOLD_DEPENDENCY_NETWORK`
  - `HOLD_DEPENDENCY_INSTALL`
  - `HOLD_LOCKFILE_REGISTRY_CONTAMINATION`

## Scope

No Flutter, Dart, Functions, Firestore Rules, workflow, Isar model, Android, Firebase identity, or programme-governance source was changed.

The failed run stopped before dependency installation completed and before Flutter generation, emulator execution, APK build, Git mutation, Firebase deployment, production write, or device action.

## Failure-evidence sealing correction

The failure path now writes the failure status without raising a second terminating `Write-Error`, then seals the evidence ZIP and sidecar before exiting with code 1.
