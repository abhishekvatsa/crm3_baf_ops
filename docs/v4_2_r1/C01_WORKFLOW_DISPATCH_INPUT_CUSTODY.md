# C-01 Workflow Dispatch Input Custody

Status: CLOSED

Date: 2026-07-27

## Verified finding

The production and verification artifact workflows previously embedded
`workflow_dispatch` values directly in Bash and PowerShell `run` blocks.
GitHub Actions expands those expressions before the shell parses the script, so
a crafted string could alter script source instead of remaining a command
argument. The production path is privileged by its protected signing
environment, release secrets and `contents: write` permission.

## Source correction

Both manual workflows now:

1. map dispatch values into job-scoped `CRM_DISPATCH_*` environment variables;
2. validate those variables before checkout or artifact work;
3. accept only a 40-character hexadecimal commit, a build number from 1 through
   2147483647, and bounded allowlisted release identifiers;
4. pass validated values to scripts through environment-variable arguments;
5. keep dispatch expressions out of every Bash and PowerShell `run` block.

The exact commit remains bound to the refreshed remote `main` head in the
production workflow. Existing policy, signing, reservation, artifact and
distribution boundaries remain unchanged.

## Regression enforcement

`tools/release/workflow_dispatch_input_custody.mjs` parses every manual workflow
as YAML and inspects each structured `run` value. CI fails if either
`inputs.*` or `github.event.inputs.*` appears in script source. Its tests prove
both an unsafe synthetic workflow and the complete current manual-workflow set.

The production policy verifier and the canonical-main audit independently scan
YAML run blocks, enforce the environment-custody markers and reject direct
dispatch interpolation. Existing Flutter release-contract tests also bind the
validation and argument-passing contract.

## Merge and CI evidence

PR #57 merged exact source head
`7b3582768c84fef276b08617212efe1e6a996f38` to main as
`34e8f4a314fcd03991d535d050614b96eeaf3204`. Post-merge release-gate run
`30293820019` passed the Flutter, Firestore Rules and governed emulator, and
Cloud Functions jobs on that exact main commit.

Decision: `PASS_C01_WORKFLOW_DISPATCH_INPUT_CUSTODY`

C-01 is closed as a source-and-CI finding. Any reappearance of direct dispatch
interpolation in script source, weakening of the bounded grammars, removal of
manual-workflow discovery, or loss of either independent audit re-arms it.

## Operational boundary

No production workflow was dispatched. No tag, signing operation, artifact
build, upload, deployment, Firebase mutation or runtime activation occurred.
