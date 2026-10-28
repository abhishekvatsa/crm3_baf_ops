# Repository-maintained deepmerge prototype guard

This private development/test package starts from the exact CommonJS entry of
upstream `deepmerge` 4.3.1. It rejects the literal `__proto__` key before reading or
assigning it in both object-copy loops. All other bundled runtime code and the
TypeScript declarations remain unchanged.

The package is maintained in this repository as
`@crm3/deepmerge-prototype-guard@4.3.1-b31.1`, intended to satisfy local `deepmerge`
dependencies through an explicit npm override. It is not an official upstream
patched release, a registry publication, or an approved production dependency.

The change follows the two key checks proposed in upstream
[PR 274](https://github.com/TehShrike/deepmerge/pull/274), which was closed without
an official patched release established by the reviewed
[advisory](https://github.com/advisories/GHSA-gcqx-w48m-w2h4).
`UPSTREAM.json` records the original identities and the exact patch lineage.
`patches/forward.patch`, `patches/inverse.patch` and the substitution records make
the change reversible to the original 4048-byte bundle and its full SHA256.
The original MIT license is retained in `license.txt`.

This package is not an npm audit substitute. Its new name alone establishes no
security claim: the changed source bytes, dependency-origin policy, actual local
installation, security/compatibility regressions and full audits must all pass.
It supplies no audit exception, suppression or relaxed threshold.
