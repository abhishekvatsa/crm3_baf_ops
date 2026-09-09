# Build/Test Dependency Audit Exception, 2026-09-09

## Decision

The release gate assesses runtime dependencies with `--omit=dev` for the root
package and Cloud Functions. That scoping is not an assertion that the omitted
population is safe, so the omitted population is assessed here instead, and the
gate additionally reports it on every run without failing on it.

One advisory is currently open in that population.

| Field | Value |
| --- | --- |
| Advisory | GHSA-2883-xcg3-v3hh |
| Package | `js-yaml` |
| Vulnerable range | `3.0.0 - 3.15.1` |
| Resolved version | `3.15.1` (root and Cloud Functions) |
| Severity | high |
| Populations | root `devDependencies`, Cloud Functions `devDependencies` |
| Owner | Repository owner |
| Review by | 2026-12-09 |

## Reachability

`js-yaml` reaches both roots only through `jest` and its coverage tooling:

    jest -> @jest/core -> @jest/transform -> babel-plugin-istanbul
         -> @istanbuljs/load-nyc-config -> js-yaml

It is a test-time dependency. It is absent from the Flutter application
artifact, and absent from the deployed Cloud Functions runtime, whose deployed
archives are separately proven byte-exact against built source by
`build28-deployed-code-byte-comparison.json`. The advisory describes
CPU exhaustion when parsing adversarial YAML; the only YAML this population
parses is repository-owned coverage configuration, not untrusted input.

That is the reason the exception is bounded, not a claim that the advisory is
harmless in general.

## Why it is not corrected in place

The correction is a one-line override raise, and it was attempted and reverted.
Editing `functions/package.json` changes the `functions` git tree that the
Build 28 backend deployment closure binds through
`sourceAuthority.functionsGitObjectId`. The production release policy gate
correctly rejected the branch with `Current source backend authority differs
from source state`, and the approval's own qualification requires a new
assessed source decision rather than admitting a descendant.

The correction therefore belongs with the next governed backend deployment,
where a fresh approval pins the new commit and function tree. A frozen receipt
preserves history; it does not freeze future engineering, and this exception
exists so the deferral stays visible and dated rather than silent.

## Governed CLI

`tooling/firebase-cli` is audited in full, without `--omit=dev`, because
`firebase-tools` performs production deployments and its dependencies are
production dependencies of that package. Its `hono`, `js-yaml` and `morgan`
advisories were patched through the existing override mechanism rather than
scoped away, and both lockfile hash pins were updated under LF custody.

## Closure

This exception closes when the root and Cloud Functions `devDependencies`
resolve `js-yaml` at `3.15.2` or later under a governed source decision, and
the reporting step records no advisory in the omitted population.
