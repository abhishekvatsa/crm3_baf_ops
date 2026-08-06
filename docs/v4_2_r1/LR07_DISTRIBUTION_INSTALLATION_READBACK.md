# LR-07 Distribution and Installation Readback

Status: SOURCE CONTAINMENT PROPOSED; LIVE ARTIFACT DELETION AND STRICT READBACK PENDING

## Live finding

The repository is intentionally public so its GitHub Actions execution is not
charged against the private-repository allowance. GitHub permits signed-in
users with repository read access to download retained workflow artifacts. A
public repository therefore makes retained production artifacts available
beyond the sealed internal roster even when no GitHub Release exists.

Read-only inventory on 2026-08-06 found five live production-artifact archives,
for consumed Builds 4 through 8, with a combined size of 765,143,034 bytes. The
repository-level artifact and log retention setting was 90 days. All five
records matched exact build-ledger IDs, names, sizes, digests, workflow runs and
source commits. Builds 5 through 8 were finalized as non-distributable with
dual custody. Build 4 was consumed, independently verified, non-distributable
and finalization-blocked. No GitHub Release existed.

The archives contain governed production packages, including signed APK and
AAB outputs. The workflow is secret-isolated and does not upload signing keys
or passwords, but public artifact availability is still broader than the
declared distribution boundary. `LR-07` therefore cannot close while any such
archive remains live.

## Source containment

The production workflow now assigns its governed package the minimum supported
one-day artifact retention. The release gate executes unit tests for both new
LR-07 tools:

- `tools/release/containGitHubProductionArtifacts.js` may delete only the five
  exact artifact IDs declared in
  `release/lr07-distribution-installation-readback-policy.json`. It requires
  clean merged `main`, exact ledger metadata, an append-only sealed preflight
  receipt and the policy's exact owner-approval phrase at execution. The phrase
  is accepted only by the containment phase and makes accidental invocation
  fail before any deletion. The tool preserves workflow runs, logs, tags,
  Releases, repository visibility and source.
- `tools/release/collectDistributionInstallationReadback.js` is read-only. It
  enumerates every GitHub Release, every Actions artifact and every production
  workflow run. Artifacts are classified by their originating workflow run,
  not by a mutable filename prefix. It verifies the current public-repository
  declaration, checks the one-day workflow retention, binds the exact Build 8
  finalization evidence and re-hashes the external physical installation
  receipt.

The external Build 8 receipt remains present outside the repository. Its
8,119-byte file re-hashes to
`4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC`,
matching the admitted adjudication. It proves the production signer, version 8
APK hash, physical target and approved session without retaining raw device or
account identity.

## Exact sequence

1. Merge this source tranche after exact-head CI and require a successful
   post-merge release-gate run.
2. From clean `main` equal to `origin/main`, create the append-only containment
   preflight receipt. It must observe all five exact artifacts and no extras.
3. Obtain explicit owner approval for irreversible deletion of those five
   artifact archives, then supply the policy's exact approval phrase to the
   containment command.
4. Run the containment phase. It is retry-safe for an already absent expected
   artifact, rejects any changed or unexpected production artifact, and passes
   only when a complete post-delete inventory is empty.
5. Run strict LR-07 readback with the exact external Build 8 installation
   receipt. Zero live production artifacts and zero GitHub Releases are
   mandatory.
6. Admit the sealed containment and readback receipts through a separate
   closure change. Only that adjudication may move `LR-07` to `CLOSED`.

## Qualification

Artifact deletion is not represented as proof that nobody downloaded a prior
archive. It establishes the current controlled surface and removes continuing
availability. `LR-07` must re-arm if a production artifact or GitHub Release is
created, a new distribution channel or client platform is enabled, another
installation target is admitted, the exact installation evidence becomes
unverifiable, repository visibility or workflow retention changes, or a newer
production build supersedes Build 8.

This source tranche does not close `LR-07`, `STAGE2D-F4`, `P-07`, `P-05` or
`70K-RECOVERY`; authorize pilot handout; change Firebase; alter a device; or
claim that a public artifact was never previously downloaded.
