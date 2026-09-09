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

It is a `devDependency` in both roots, so it is not installed into the
production dependency tree that `--omit=dev` audits, and it is not bundled into
the Flutter application artifact. The advisory describes CPU exhaustion when
parsing adversarial YAML; the only YAML this population parses is
repository-owned coverage configuration, not untrusted input.

Two limits on that reasoning, stated deliberately:

The byte-exact archive comparison in `build28-deployed-code-byte-comparison.json`
establishes that the deployed archives match the expected built source. It does
**not** by itself establish the installed runtime dependency population, and it
is not offered here as proof that the parser is unreachable. The reachability
claim rests on the dependency graph and install configuration above, which
should be re-checked rather than assumed at each review.

This is a bounded deferral of one identified advisory, not a claim that the
advisory is harmless in general.

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

## Enforcement

This document is the human record. Its machine-readable counterpart is
`governance/build-test-dependency-audit-exception-v1.json`, and the release gate
runs `tools/dependencies/verify_build_test_dependency_audit.mjs` against it.

The checker resolves findings to advisory identity rather than counting them,
because npm reports one entry per affected package: this single advisory shows
as two vulnerabilities, `js-yaml` and the `@istanbuljs/load-nyc-config` that
depends on it. A count would silently admit a second, unrelated advisory.

It fails the gate on a new advisory, on an advisory appearing in a population
the exception was not recorded for, on an exception past its review date while
still in use, and on an audit that cannot be read. An unavailable assessment is
never treated as a clean one.

## Closure

This exception closes when the root and Cloud Functions `devDependencies`
resolve `js-yaml` at `3.15.2` or later under a governed source decision, and the
checker reports `exception-closable` for both populations.

The review date is an outer bound, not a target. The correction should be taken
at the next appropriate dependency-maintenance change or the review deadline,
whichever comes first.
