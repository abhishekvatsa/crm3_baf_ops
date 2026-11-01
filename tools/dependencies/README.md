# Governed dependency compatibility

`npm run test:dependency-compat` verifies the interfaces used by the pinned
Firebase CLI and the other locked dependency trees. These checks perform no
Firebase account import, deployment, or business-data operation.

The Firebase CLI remains at 15.22.4. Its CSV parser is overridden to the upstream
patched `csv-parse@7.0.2` for
[GHSA-8cw4-87c7-c6xx](https://github.com/advisories/GHSA-8cw4-87c7-c6xx).
The CLI's sole CSV consumer is `auth:import`, which uses the CommonJS `parse()`
Node stream with default options. Tests verify that interface, conversion through
the CLI's actual account mapper, malformed input, split UTF-8, and the advisory's
duplicate-column prototype replacement case. The override is confined to CLI
tooling; it does not change the Android app or Functions runtime dependencies.

The locked `glob` and `minimatch` implementations use the exact upstream fixes
14.0.2 and 11.0.1 for
[GHSA-3g3m-2fjr-6pw4](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4) and
[GHSA-g3hv-75wg-m249](https://github.com/advisories/GHSA-g3hv-75wg-m249).
Modern glob consumers retain registry exports. The Jest 29/test-exclude glob 7
edges use a small callback/sync export adapter backed by glob 14.0.2, because
glob 7 relies on minimatch's removed parsed-RegExp internals. Direct legacy
minimatch callers receive a callable export backed by 11.0.1.

The compatibility test checks every installed locked population, callback and
promisify behavior, sorting and nonull, native Windows pattern paths,
test-exclude async/sync enumeration, an actual Functions Jest 29 coverage run
with a glob threshold, and the CLI's readdir-glob and Superstatic callers. It
also checks bounded globparts expansion and no new filesystem traversal after
an in-flight abort, for both glob and globStream. These checks are offline and
do not load a Firebase account or invoke a deployment.

The local wrappers have their own private 1.0.0 package identities. Their
whitelisted source bytes are packed into sibling local tarballs, whose file
provider identity npm validates when install-links is enabled. Tests compare
every tar member with its source without extraction, and inspect actual parent
module resolution rather than assuming a top-level version proves the API.
Exact test-exclude 6 and Firebase 15.22.4 parent overrides select the narrow
minimatch 3 callable adapter, preserving its Windows pattern normalization.
Minimatch 5/6 retain the separate native named-class semantics. The exact glob
14.0.2 normal CJS/ESM minified bundles are self-contained and load only Node
builtins/filesystem modules. Tests verify their export routes, exact package
and bundle hashes, static loader closure, and real entry execution while
refusing external package loads. Their lockfile matcher metadata is reported
as unused and may resolve to either adapter; `/raw` is outside this proof.
The external minimatch version does not prove an embedded matcher version.
