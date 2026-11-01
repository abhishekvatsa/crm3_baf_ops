# minimatch compatibility export

This private package delegates matching to the exact registry package
`minimatch@11.0.1`, which fixes GHSA-g3hv-75wg-m249. The npm alias
`minimatch-modern` keeps that upstream package separate from the override.
The wrapper has its own truthful identity, `crm3-minimatch-compat@1.0.0`, so
npm cannot deduplicate its callable API to the registry object's same-version
export. The matching core remains exactly 11.0.1.

The pinned Firebase CLI, test-exclude and Superstatic call the CommonJS export
as a function. readdir-glob uses `Minimatch` and `match()`. The adapter exposes
the upstream callable with its named exports; ESM and type imports retain the
upstream named exports. `defaults()` and matching remain upstream code.
This general adapter preserves minimatch 5/6 and modern named-export semantics.
The sibling `tooling/minimatch-compat.tgz` contains only whitelisted source files
and gives npm a concrete file-provider identity. The two observed minimatch 3
default callers use the separate `minimatch-v3-compat` path adapter.

This is not a recreation of minimatch 3's removed `makeRe()` or parsed-RegExp
internals. The only locked consumer of those internals, glob 7, is replaced by
the separate glob compatibility export backed by patched glob 14.0.2.
