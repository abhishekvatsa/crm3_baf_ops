# Pinned minimatch 3 callable compatibility

This private adapter is selected only for the observed minimatch 3 default
callers: test-exclude 6 and Firebase CLI 15.22.4 fsAsync. It delegates matching to
exactly `minimatch@11.0.1` through the `minimatch-modern` alias. Its sibling
`tooling/minimatch-v3-compat.tgz` contains only the whitelisted source files.

The callable trims the pattern and, on Windows, maps filename backslashes to
slashes and pattern backslashes to slashes unless `allowWindowsEscape` is true.
That consumed legacy flag is not passed to the modern matcher, whose inverse
flag has different default semantics. The explicit `windowsPathsNoEscape:false`
keeps the already-normalized or intentionally escaped pattern intact.

Named exports remain native upstream exports. This is not a recreation of
minimatch 3's constructor, parsed-RegExp internals or removed `makeRe()` API.
The minimatch 5/6 consumers receive the separate unmodified callable/named
export adapter. Exact glob 14.0.2 normal entry bundles load no external
matcher; their unused lockfile matcher edge may inherit this adapter. Tests
pin and verify those bundled entry points separately; `/raw` is outside that
claim. Every named field exposed by this adapter remains native upstream.
