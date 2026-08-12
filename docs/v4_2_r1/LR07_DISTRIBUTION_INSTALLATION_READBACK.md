# LR-07 Distribution and Installation Readback

Status: RE-ARMED - BUILDS 9 AND 10 ARTIFACT CONTAINMENT AND READBACK OPEN

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

- `tools/release/containGitHubProductionArtifacts.js` may delete only exact
  artifact IDs declared in
  `release/lr07-distribution-installation-readback-policy.json`. It requires
  clean merged `main`, exact ledger metadata, an append-only sealed preflight
  receipt and the policy's exact owner-approval phrase at execution. The phrase
  is accepted only by the containment phase and makes accidental invocation
  fail before any deletion. A re-armed preflight may admit already-absent
  historical IDs only when every separately declared required-present ID is
  exact and live. The tool preserves workflow runs, logs, tags,
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

## Completed sequence

1. PR #169 merged the one-day retention, containment and strict-readback source
   after exact-head release-gate run `31087258758`; post-merge run
   `31088013593` also passed all five jobs.
2. Clean merged `main` at `02731af8a79f0da4a731ff9f28eb96df10458eef`
   produced a sealed preflight that observed the five exact artifacts, no
   mismatch and no unexpected production artifact.
3. The owner explicitly approved irreversible deletion of those exact five
   artifact archives. Containment removed all five and no other artifact while
   preserving workflow runs, tags, Releases, repository visibility, source,
   Firebase and the device.
4. Strict post-containment readback observed nine preserved production workflow
   runs, zero live production artifacts, zero artifact bytes and zero GitHub
   Releases. It also re-hashed and semantically validated the exact external
   Build 8 physical installation receipt.
5. The separate closure adjudication admitted the privacy-minimized containment
   and strict-readback records and moved `LR-07` through
   `OPEN -> LIVE_READBACK_PROVED -> CLOSED`.

The collector still does not close `LR-07`; it records facts and requires a
separate adjudication. The repository evidence is:

- `release/evidence/lr07-public-production-artifact-containment.json`
- `release/evidence/lr07-distribution-installation-live-readback.json`
- `release/evidence/lr07-distribution-installation-live-readback-closure.json`

## Current re-arm

Governed Build 9 was finalized from commit
`f51749c3f0200a5a03b065f0644d7759c747de7f` with dual custody and created
production artifact `9116320474`. Device validation then proved that Build 9
crashes before Flutter startup, so the artifact is permanently
non-distributable. The live artifact and the newer finalized build each match
an explicit LR-07 re-arm trigger.

Governed Build 10 then completed the signed CI build from commit
`e6bfa327466ffa99da9519846db7f83401c86c7b` and created production artifact
`9122790773`. Independent package verification passed. Finalization stopped
before either custody directory or the built tag was created because the
source preflight and finalizer compared the environment receipt to different
source anchors. Build 10 is therefore permanently consumed,
finalization-blocked and non-distributable. Its exact failure authority is
`release/evidence/build-10-finalization-block.json`.

The historical Builds 4 through 8 containment, readback and closure evidence
remains valid for the state observed on 2026-08-06. Current LR-07 authority is
OPEN until the Build 9 and Build 10 artifacts are deleted under the updated exact approval
phrase, a clean merged-main strict readback again proves zero live production
artifacts and zero GitHub Releases, and a separate closure adjudication admits
that new evidence. Build 11 construction does not itself close LR-07; any
Build 11 Actions artifact must be added to the same exact containment set.

## Qualification

Artifact deletion is not represented as proof that nobody downloaded a prior
archive. It establishes the current controlled surface and removes continuing
availability. `LR-07` must re-arm if a production artifact or GitHub Release is
created, a new distribution channel or client platform is enabled, another
installation target is admitted, the exact installation evidence becomes
unverifiable, repository visibility or workflow retention changes, or a newer
production build supersedes Build 8.

The historical adjudication closed only the then-observed LR-07 posture. It did
not authorize pilot handout, change Firebase, alter a device, create
distribution authority, or claim that a public artifact was never previously
downloaded. The Builds 9 and 10 re-arm blocks any current LR-07 closure claim until the
new containment and readback sequence completes.
