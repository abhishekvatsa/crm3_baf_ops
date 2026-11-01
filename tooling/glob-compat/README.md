# glob compatibility export

This private package replaces the glob 7 implementation used by Jest 29 and
test-exclude with the exact registry-custodied `glob@14.0.2`, which fixes
GHSA-3g3m-2fjr-6pw4. It never runs the old traversal or minimatch internals.

Only the exact locked Jest 29 and test-exclude 6 parent overrides select this
adapter through the `glob-legacy-compat` direct dependency. Modern glob edges
select registry 14.0.2 directly. The alias `glob-modern` is separate from either
override.

The exact 14.0.2 normal CommonJS and ESM entry points are self-contained
minified bundles. Their integrity-pinned bytes load only Node builtins and
filesystem modules, not their lockfile's minimatch dependency. That unused
metadata edge may inherit either local matcher adapter. Tests pin both normal
export routes and bundle bytes, inspect their loader closure, and exercise
both entries with external package loading refused. The `/raw` export is
outside this claim. The external minimatch 11.0.1 version does not establish
the version of matching code embedded in the glob bundles.

The adapter has its own truthful package identity,
`crm3-glob-legacy-compat@1.0.0`. Its API differs from registry glob, so sharing
the registry name/version would let npm deduplicate a legacy edge to the modern
object export. The matching and traversal core remains exactly 14.0.2.
The sibling `tooling/glob-compat.tgz` contains the whitelisted source files.
Using a local tarball makes npm validate the file provider identity instead of
accepting any non-link provider for a directory override with install-links.

The CommonJS default supports the actual legacy callers: a Node-style callback
for `util.promisify()`, synchronous `sync()`, default English sorting, `nosort`,
and `nonull` including expanded brace alternatives. Windows legacy patterns
default to treating backslashes as path separators. Callback calls return
`undefined`, so Node does not warn about promisifying a Promise-returning
function. Matching, traversal and AbortSignal handling are upstream code.
Only legacy returned strings map Windows separators to `/`, before uniqueness
and sorting. The adapter does not enable glob 14's `posix` option, which can
introduce an extended-device prefix for an absolute Windows path.

Named modern exports are copied from upstream; ESM named exports are upstream
exports. This does not emulate glob 7's EventEmitter `Glob`/`GlobSync` classes
or its internal caches. The integrity-pinned locked consumers do not use those
interfaces. Calling the default without a callback returns a Promise.
The legacy string-returning export rejects `withFileTypes`; callers requesting
Path objects use the unmodified named `glob`/`globSync` upstream exports.
