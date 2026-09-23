# Release process hardening

Standing requirements adopted after the Build 29 cutover. Each one exists
because it cost real time during that run, and each is written so a future run
can check whether it still holds.

## Why

Three classes of problem dominated the Build 29 cutover. None was a mistake in
the deployment itself; the backend deployed correctly and read back exactly.
All three were about the machinery around it.

1. **Documents drifted apart silently.** Build 28 was recorded as finalized in
   `release/build-number-ledger.json` while `release/lr07-distribution-installation-readback-policy.json`
   and `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json` still named Build 27.
   Nothing failed for an entire build cycle, because no single check compared
   the documents to one another. It surfaced only when Build 29's ledger entry
   made the invariant unsatisfiable.
2. **Gates named the symptom, not the cause.** A failure reading
   `Current source backend authority differs from source state.` covered
   thirty-three separate clauses. Finding which one differed required
   instrumenting a copy of the gate.
3. **A correct production state could not be recorded.** The Firestore Rules
   release-write path returned HTTP 503 while committing the write. The sealed
   recorder requires exit code 0, so a deployment that had in fact succeeded
   could not produce a receipt, and production had to be rolled back and
   forward repeatedly to chase one. Thirteen attempts.

## 1. Authority documents must be compared to each other

`tools/v4/v4_2_r1_canonical_audit.py` carries the check
**"Every authority document agrees on the latest finalized build"**. It derives
the latest dual-custodied build independently from four documents and fails,
naming each disagreeing document and its value, when they differ.

Verified to bite: with LR-07 and the reconciliation snapshot reverted to their
pre-Build-28 state, the check fails with

    disagreement: docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json=27,
    release/build-number-ledger.json=28,
    release/lr07-distribution-installation-readback-policy.json=27,
    release/production-release-policy.json=28

**Standing requirement.** When a generator or a manual step advances one
authority document, it must advance every document that derives from it, or the
cross-document check must be extended to cover the new relationship. A green
generator run is not evidence that the documents agree.

## 2. A failing gate must name the failing clause

The backend-authority gate in `tools/release/Test-ProductionReleasePolicy.ps1`
evaluates thirty-three named clauses individually and reports every one that
differs. The clauses are the original expressions, unchanged; only their
presentation changed. A clause that cannot be evaluated is reported as a
difference rather than crashing the gate, which is stricter than the previous
short-circuiting behaviour.

Verified to bite on four separate mutations, each naming exactly the mutated
clause, and a mutation touching a field read by two clauses names both.

**Standing requirement.** A gate that can fail for more than a handful of
reasons must say which one. When adding a clause to a composite gate, add it as
a named entry. Do not extend a monolithic boolean.

## 3. Recorded hash pointers must still resolve

`tools/v4/v4_2_r1_canonical_audit.py` carries **"Recorded hash pointers at
retained evidence still resolve to those bytes"**. It walks every JSON document
under `release/`, pairs file and hash keys **by name** (`file` + `sha256`,
`<prefix>File` + `<prefix>Sha256`), and verifies each pointer at
`release/evidence/` or `release/approvals/` against the bytes on disk. 420
pointers are covered today. A failure names the origin document, the key and
the target.

Two deliberate exclusions, both justified:

- **Pointers at mutable source are skipped.** Build 8's approval records the
  hash of `firestore.rules` as it was at Build 8. That file has legitimately
  changed since. Sixty-three such pointers exist; treating them as stale pins
  would be wrong, and a check that cried wolf sixty-three times would be turned
  off within a week.
- **A hash recorded from CRLF bytes is accepted**, because it describes the
  same content.

Verified to bite: corrupting a single pin fails the check and names it.

### Finding: one pin is line-ending dependent

`release/production-release-policy.json` records
`restorationReceiptSha256 = FAD4C151...` for
`release/approvals/firebase-production-signing-restoration-receipt.json`. The
file in Git hashes to `CCE70C3F...`; `FAD4C151...` is the hash of the same
content **with CRLF line endings**. The same value appears in
`docs/FIREBASE_CONFIGURATION_CUSTODY.md` and
`docs/v4_2_r1/FIREBASE_COMBINED_AUTHORITY_RECONCILIATION.json`.

Nothing verified this pointer, which is why it survived. It is correct on a
CRLF checkout and wrong on an LF one, so the repository would validate
differently depending on a local Git setting.

**Recommended, not done here:** extend the `-text` attribute coverage in
`.gitattributes` from the Build 28/29 receipt patterns to all of
`release/approvals/` and `release/evidence/`, so physical hashes are stable on
every platform, and then re-record that pin from the LF bytes. This was not
done during the Build 29 cutover because changing normalisation attributes
touches byte custody broadly and deserves its own change.

## 4. Deployed-but-unreceipted deployments (deferred, by decision)

**Status: designed, not implemented. Deliberately deferred past Build 29.**

The problem is real and will recur: a platform API can commit a write and still
return an error to the client, after which the deployment is correct and
unrecordable. Restoring production to chase a receipt disturbs a correct state,
which is the opposite of what the evidence rules are for.

The intended shape, for implementation after Build 29 ships:

- A governed producer emits an additive evidence record, distinct from a
  command receipt, binding: the before-readback; the command process record
  with its actual non-zero exit and error text; a strict after-readback proving
  the live state is byte-exact to the approved source with the index set and
  field overrides unchanged; and the live release's own update time relative to
  the moment the client process exited.
- That record is **not** a substitute for a command receipt. It is admitted
  only under an owner-confirmed amendment naming the specific attempt, in the
  same pattern as the Build 29 preservation adjudication: hash-pinned tools,
  tests, and a bite proof in which each weakened copy fails exactly the test
  aimed at it.
- The existing gates keep requiring a receipt by default. Nothing about this
  path may make an unreceipted deployment the easy route.

**Why it was deferred.** It changes what counts as admissible evidence for a
production deployment. Designing that while still inside the cutover it would
have rescued is when judgement is worst, and a rule written to relieve present
pain is the rule most likely to be too permissive. It is to be designed against
the full Build 29 record — the attempt 5 and attempt 7 records, the release-path
latency probe and the campaign record — which now exists and is not going
anywhere.

## Evidence from the Build 29 run

- `rules-deployment-campaign-record.json` — thirteen attempts, five failing at
  compile, four at ruleset upload, three at release
- `rules-release-path-latency-probe.json` — measured 503-while-committing on
  the release-write path, against a throwaway release that enforces nothing
- `rules-attempt-5-released-without-receipt-record.json` and
  `rules-attempt-7-released-without-receipt-record.json` — the two deployments
  that applied while reporting failure
