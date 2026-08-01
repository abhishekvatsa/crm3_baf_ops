# Firebase CLI re2 Advisory Remediation

## Decision

The governed Firebase CLI dependency domain pins `re2` `1.25.2`. This closes
GHSA-6hxr-mr5r-9836 and GHSA-ff84-5f28-78qj in the tooling lockfile without
changing application or Cloud Functions runtime dependencies.

`re2` `1.25.2` requires Node `22.22.2` or newer. The exact production toolchain
therefore advances from Node `22.15.0` / npm `10.9.2` to the current Node 22 LTS
patch `22.23.1` / npm `10.9.8`. The production workflow, release policy, canonical
laboratory and repository instructions carry the same exact pair.

## Custody

- `tooling/firebase-cli/package.json` owns the `re2` override.
- `tooling/firebase-cli/package-lock.json` binds the public registry URL,
  integrity digest and transitive native-build dependencies.
- The release gate and production policy bind the reviewed lockfile SHA-256.
- The canonical and ultimate audits reject removal or regression of the pin.
- The canonical laboratory checks both the locked and installed package version.

## Verification

The regenerated lockfile reports zero npm audit vulnerabilities. A clean install
under the SHA-256-verified official Node `22.23.1` Windows runtime resolved
`firebase-tools > superstatic > re2@1.25.2`. Runtime checks covered global
empty-pattern matching and an out-of-range sticky match, the two advisory
behavior classes, without reproducing the unsafe payloads on the old binary.

## Release boundary

Existing signed artifacts remain immutable evidence of the toolchain that built
them. This remediation governs future source validation and production builds;
it does not alter the installed Flutter application or retroactively relabel an
existing artifact.
