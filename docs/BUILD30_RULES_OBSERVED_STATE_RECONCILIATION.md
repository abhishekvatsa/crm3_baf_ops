# Build 30: verifying a Rules update after a failed CLI acknowledgement

The approved Rules deployment can change the active release even when the pinned Firebase CLI exits with an error. Its release helper catches every update error and attempts to create the existing release, producing a second HTTP 409 error. Retrying with intervening rollbacks does not resolve the evidence problem reliably.

The owner requested a different method. This change adds a separate, read-only acceptance route for the retained Build 30 attempt 13. It does not deploy Rules, change security policy, or convert exit 1 into exit 0. Existing successful-command verification remains in place.

## Required evidence

Acceptance requires the original committed deployment approval and source CI, unchanged approved execution/runtime measurements, the actual failed command and exact project-specific release-conflict output, and the immediately preceding observation of the prior Rules. A fresh, separately committed method decision must bind the reviewed verifier, retained failure, source and exact resulting Ruleset.

The final observation must be collected in STRICT mode after the method decision is committed. It must prove the approved Rules bytes, the expressly accepted Ruleset created during the actual command window, and unchanged ready indexes. Both command-success and reconciliation pointers together are refused. Generic failures, compiler errors, unrelated rulesets, stale observations, altered evidence and unreviewed verifier bytes are refused.

The original private measurements remain intact. A defined public projection replaces only three local filesystem paths with their hashes. All remaining measurement fields are preserved and checked against the failed-command record. The method decision binds the raw and projected hashes following actual derivation and privacy review. Public verification checks the projection and its committed approval; it does not claim to reconstruct private original bytes.

## Release sequencing

1. Review and test the shared verifier, then commit its exact source.
2. Re-derive the retained failed-command evidence and public projection. Review the actual bytes and record the current delegated method decision in a later commit.
3. Collect a fresh STRICT live Rules/index observation and validate the complete backend closure while the deployment checkout and live main remain at the approved backend source.
4. Review and merge the release tooling and backend evidence. Require the resulting exact-main gates before allocating the candidate metadata.
5. Keep backend source custody separate from the later artifact source baseline. Require unchanged business code, Functions, Rules and indexes across that tooling-only transition.

This document is a description of the verification route, not a deployment receipt, an approval, proof of a completed build, or permission to distribute an artifact. Signing, artifact custody and the actual Play-delivered in-place update remain separate acceptance steps.
