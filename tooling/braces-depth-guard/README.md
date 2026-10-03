# Owned braces depth backport

This private repository package is `@crm3/braces-depth-guard` version `1.0.0`. It is a maintained fork of released `braces` 3.0.3, installed under the dependency key `braces` for the Functions development graph and the governed Firebase CLI graph. It is not an upstream patched release.

[GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) reports stack exhaustion in recursive AST walkers. At review on 3 October 2026, upstream had no patched release. This fork applies the five-file depth patch from [upstream PR 72](https://github.com/micromatch/braces/pull/72), commit `d0d575e55e74a4e0218e5248fafb79efc3e54ebb`, to the exact npm 3.0.3 archive. That PR was still open and unmerged. The original MIT license is retained.

`UPSTREAM_PROVENANCE.json` records the npm archive integrity, original file hashes, owned file hashes, exact upstream patch and deliberate differences. Besides the explicit owned package identity, those differences preserve released `stringify(..., {escapeInvalid: true})` behavior, check fractional parser depth before adding the next level, and reject finite negative depth limits consistently.

## Contract

The default and hard maximum nesting depth is 100. `parse` limits braces and parentheses; `compile`, `expand` and `stringify` independently limit direct AST traversal. The main function and `create` use those guarded entrypoints. A finite nonnegative `maxDepth` can make the limit smaller, never larger than 100; fractional limits act as their floor. Finite negative values throw `RangeError` in the four explicit `parse`, `compile`, `expand` and `stringify` APIs. The inherited main-function and `create` fast path for strings shorter than three characters still returns before option validation; it cannot carry excessive nesting. Non-numeric and nonfinite values use the safe default. Over-limit nesting is rejected with a depth-specific error before stack exhaustion.

Normal APIs, expansion options and released invalid-brace escaping remain compatible. Refusing formerly unsafe extreme nesting is intentional. This patch does not claim a universal bound for expansion cardinality, AST width, malformed cyclic parent links, or every consumer's error handling.

## Required verification

Run `node tools/dependencies/verify_braces_depth_guard.mjs` after installing both dependency graphs. It verifies the exact owned runtime bytes and license, resolves the fork from the actual Functions micromatch and Firebase chokidar consumers, rejects any remaining unowned braces lock entries, exercises public and direct walker depth limits in bounded child processes, and checks normal matching and real filesystem watcher behavior including Firebase's `**/` ignore patterns. The adjacent regression test checks source tampering and the depth/API contract.

Keep strict npm audit enabled with the existing narrow exceptions unchanged. A local owned name may no longer match the upstream advisory lookup; that change is not security evidence. The source-bound behavioral guard is mandatory in addition to the audit. Keep Firebase 15.22.4, basic-ftp 6.2.1 and gRPC 1.14.5; forcing chokidar 4 would remove glob behavior that this Firebase version uses.

Repository maintainers own this backport until an official release fixes the advisory and passes the same compatibility and depth checks. Replacing this package requires reviewing the upstream fix and updating the explicit source hashes. This source preparation does not grant backend deployment, signing or release authority.
