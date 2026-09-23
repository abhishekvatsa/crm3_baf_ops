# Build cutover runbook

Written immediately after the Build 29 cutover, from what that run actually
required rather than from what the tooling appears to require. Read the traps
first; most of the time lost on Build 29 went to three of them.

## Traps, in the order they bite

**Gates read committed objects, not your working tree.** `Test-ProductionReleasePolicy.ps1`
compares the approved baseline against `HEAD` using `git rev-parse` and
`git show`. Applying the metadata overlay to disk and running the gate proves
nothing; it will keep passing on the old committed state and then fail the
moment you commit. Commit first, then run the gate.

**`test/`, `tool/`, `tools/release/`, `lib/`, `android/`, `functions/` and
`tooling/` are approved artifact source paths.** Changing any of them moves the
source away from the approved baseline, `ArtifactSourceMatchesApproval` goes
false, and construction authority is withdrawn. This is why a one-line contract
test fix is not a small change during a cutover. `docs/`, `tools/v4/` and
`release/` (except two named files) are outside that set, meaning they do not
move the artifact baseline.

**That is not the same as harmless.** Two questions are separate: does the file
affect constructed artifact inputs, and does it influence release decisions or
evidence? A no to the first does not imply a no to the second. The rebind
helper written during this cutover lived outside the artifact source paths and
changed approval state; it was withdrawn after review found it produced an
incoherent transition. Tools that touch authority records need reviewed
identities even when they cannot change the application binary.

**The baseline must already contain any `test/` change you need.** A commit
whose tests expect the new metadata cannot be green until the metadata lands,
and the metadata cannot be construction-authorized until the baseline contains
the tests. Resolve it with the two-step in "Re-binding the artifact baseline",
not by weakening the tests.

**A failed deployment may already be live.** The Firestore Rules release-write
path returns HTTP 503 while committing the write. Twice on Build 29 the release
applied while the CLI reported failure, once 1.26 seconds *after* the process
had exited. Always read the live release back before concluding anything from
an exit code.

**Health-probing the platform does not predict the deploy.** The sealed command
spends 70 to 90 seconds on runtime measurement, source verification and its
before-readback before the CLI's first call, which is longer than the
endpoint's state lasts. Three probe-gated attempts still failed at compile.
Probe the release-write path if you want to understand the platform; do not
gate on it.

**Do not read this as licence to retry through production.** The standing rule
is: preserve the failed command's evidence, establish what is actually live,
and resolve that uncertainty before any further mutation. Do not roll back or
redeploy a correct live state merely to obtain exit code zero. Build 29 did
restore and retry, and that is precisely the cost the deferred
deployed-but-unreceipted evidence path exists to remove.

**Generators do not advance every document they invalidate.** The metadata
generators move the ledger and `finalization.priorCompletedBuild` but not the
LR-07 containment list or the reconciliation snapshot. The canonical audit now
carries "Every authority document agrees on the latest finalized build", which
catches this class; if it fires, suspect the *previous* build's containment,
not the current build.

**Derive archive numbers from disk.** A retry loop that assumes its own attempt
number will mislabel evidence the first time an archive already exists. Take
one past the highest `rules-attempt-N-*` directory present.

**Evidence is create-only.** Nothing is edited or deleted. A wrong record is
corrected by an additive successor record that states what the original got
wrong and what still stands.

## Order of operations

1. **Freeze.** Merge the source PR to main and record its commit, tree,
   functions tree, PR number and the green exact-main release-gate run id.
   Everything downstream binds to these.
2. **Backend approval custody.** A committed approval naming the freeze, with
   its CI evidence, before anything is deployed.
3. **Deploy, by cohort.** callables, then events, then fleet, then rules, each
   through the sealed cohort script with `-Execute`, each producing its own
   attempt, command, measurement and completion records. Inspect the result of
   one before starting the next.
4. **Readback.** Fleet runtime identity, IAM dependencies, and rules/indexes,
   all live and strict.
5. **Deployed code archives.** The step that establishes *which code is
   running*; `imageUri` alone does not.
6. **Preservation.** Control comparison before and after. If the sealed
   comparator refuses a legitimate redeploy, see the adjudication pattern in
   `tmp/build29-preparation/preservation-adjudication/README.md`: an
   owner-confirmed amendment with hash-pinned tools, tests and a bite proof,
   never a bypass.
7. **Custody and projection.** Private proof to the owner's own bucket,
   generation-pinned and verified by round trip; public projection carrying no
   identities.
8. **Closure.** Assembles the whole record and re-runs the committed boundary
   validators.
9. **Metadata.** Generate the pending overlay, complete it against the measured
   closure, verify the overlay, apply, commit, then run the gates.
10. **Re-bind the artifact baseline** if step 9 required any artifact-source
    change.
11. **Artifact.** Dispatch the protected workflow; it halts for the required
    reviewer. Verify package identity, certificate and custody before install.
12. **Install and qualify** on the phone, in place, preserving data.

## Re-binding the artifact baseline

Needed whenever the cutover had to change an approved artifact source path,
which in practice means whenever a governance contract test had to move.

The canonical audit already defines the intermediate state; use it rather than
inventing one.

- **Step 1** lands the source change together with the metadata, and records
  `BUILD<n>_SOURCE_SUCCESSOR_BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND`
  with `artifactConstructionAuthority` false. This is truthful: the source has
  drifted from the approved baseline, so construction is not authorized. CI is
  green here because the policy computes the same false.
- **Step 2**, after that merges, points the approval's `sourceBaseline` at the
  merge commit, follows it with the ledger's `versionApprovalDocumentSha256`,
  and restores construction authority. Drift returns to zero.

**Five records participate in a re-bind, not three.** Rewriting the approval
changes its bytes, so every active pointer at it must follow the same digest:

| Record | What moves |
| --- | --- |
| `release/approvals/build-number-29-successor-approval.json` | `sourceBaseline` commit and tree |
| `release/production-release-policy.json` | `versionPolicy.sourceDocumentSha256` |
| `release/approvals/version-policy-approval.json` | `sourceDocumentSha256` |
| `release/build-number-ledger.json` | the build's `versionApprovalDocumentSha256` |
| `release/current-successor-state.json` | construction authority and the rebind statuses |

`tools/v4/rebind_artifact_baseline.py` performs this as one validated
transition: it inspects every record, the source delta and the decision before
building anything, serialises the approval once and derives every pointer from
that single digest, re-reads the proposal as a consumer would, and only then
stages and moves the files. Without `--write` it validates and reports; it
authorises nothing either way.

**A re-bind needs its own decision.** The existing source approval recorded a
decision made against the previous baseline. Repointing `sourceBaseline` without
a new decision would make that earlier timestamp appear to authorise source that
did not exist when it was made. `--write` therefore requires an owner-confirmed
decision recording `documentType`
`governed-artifact-source-rebind-decision`, `confirmed`, the previous baseline
commit, the target commit, the source approval digest it was made against, and
the deployed backend commit, which the re-bind must leave untouched.

**Permission is the exact reviewed delta, not a directory.** The tool requires a
manifest naming each moved path with its before and after object identities, and
refuses anything the manifest does not declare — an unreviewed change to a gate
under `tools/release/`, or a deleted test tree, is refused even though both sit
inside otherwise permitted directories.

Compare the previous baseline against the proposed one **before** adopting it,
including `pubspec.yaml` with only the governed version declaration normalized:
once the new commit is the baseline, comparing it against itself proves
nothing. The canonical checks "Recorded hash pointers at retained evidence
still resolve to those bytes" and "The ledger version approval pin matches the
approval the policy names" refuse an incoherent result, but they catch it after
the fact; the transition should be validated in full before anything is
written.

## What only the owner can do

- Confirm an amendment, in their own words, before any step relies on it
- Approve the protected environment deployment; admins cannot bypass it
- Approve an artifact deletion phrase, which is re-keyed whenever containment
  advances to a newer artifact
- Push, and merge to main

Everything else can be prepared, validated and shown for confirmation first.

## Where things live

- Execution checkout: a clean copy at the exact freeze, outside the authority
  checkout, with dependencies absent until the freeze is known
- Evidence root: a private campaign directory outside both checkouts
- Sealed helpers: `tmp/build29-preparation/backend-execution/`, byte-pinned by
  inventory and verified at run time
- Process requirements adopted after this run:
  `docs/RELEASE_PROCESS_HARDENING.md`
