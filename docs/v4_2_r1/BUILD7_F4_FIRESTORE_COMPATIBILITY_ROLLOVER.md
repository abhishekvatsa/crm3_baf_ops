# Build 7 F4 Firestore Compatibility Rollover

## Decision

Build 7 is authorized as one production-signed, non-distributable successor to
Build 6. Its sole immediate purpose is to carry the merged Firestore value
normalization fix from pull request 111 into the controlled physical-device
campaign.

This rollover does not authorize distribution, Firebase deployment, production
backfill, global-pull runtime-contract activation or any production data
mutation.

## Why Build 6 Cannot Continue

The exact Build 6 physical-device campaign created the controlled document
`knowledge_base/zz-f4-global-pull-compat-v1` in production. The deployed trigger
then applied a valid Firestore Timestamp in `_globalPullServerUpdatedAt`.

Build 6 subsequently failed while caching that document because the knowledge
decoder passed the native Timestamp into JSON encoding. The source correction
merged through pull request 111 at commit
`53b10006bc8e34240e2ec94b861ef907311071c0` and passed the exact post-merge
GitHub run `30755020315`.

Because signed artifacts are immutable, Build 6 cannot gain that correction.
Using a relaunch, manual document rewrite or backend rollback to manufacture a
pass would invalidate the compatibility evidence.

## Build 7 Boundary

- version name remains `1.0.0-rc.1`;
- build number advances monotonically from 6 to 7;
- Build 6 remains finalized, dual-custodied and permanently consumed;
- Build 7 starts as source-authorized and has no remote reservation until the
  governed workflow creates `crm3-build-reserved/7` atomically;
- the private-repository signing exception is single-build and bound to
  `BAF-REF-003-C6`;
- the four production-signing secret names were observed, but secret values
  were not read;
- any reserved Build 7 failure still consumes number 7.

## Required Sequence

1. Merge the Build 7 authority and pending-state contracts to live `main`.
2. Require the exact post-merge source and CI checks to pass.
3. Dispatch the governed production artifact workflow once with Build 7's exact
   approval reference.
4. Independently verify and dual-custody the signed package before creating the
   built tag.
5. Create and merge a separate exact-package, exact-target Build 7 physical
   execution promotion; this artifact authority does not permit installation or
   production mutation by itself.
6. Install only the verified Build 7 APK on the target bound by that promotion.
7. Use Build 7 to read and retire the controlled synthetic knowledge document
   through the governed application path.
8. Continue the remaining F4 phases only after that compatibility proof passes.

Production backfill and runtime-contract activation remain separate later
decisions. They must not be bundled into artifact construction.

## Build 7 Finalization

Pull request 112 merged the Build 7 authority at
`d8619ef1a9c7bf53828523c4bca3efe33e4074f0`. The exact post-merge release gate
passed before the production workflow was dispatched. GitHub run `30757692948`
then constructed and independently verified the production-signed candidate:

- governed package SHA-256:
  `D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7`;
- APK SHA-256:
  `EE5B5B7205A37F1FEF1F1B4C98CB1446ED544A123E130D7F3A4134E6A5E6DD56`;
- reservation tag object:
  `5e351f0b5acf1f887e14c5ad70c60864a5d6c470`;
- built tag object:
  `b06edcbcd4fdb2d27fc4b844dd16f54340aa0c3d`;
- closure package SHA-256:
  `C15D8655E2F27D0F87BAFEC97A32208926BD62130E268E13945E6C32F2FDD876`;
- dual custody: passed on distinct C: and removable D: volumes.

The primary checkout was intentionally left unchanged because it contained
operator-owned untracked directories. A clean exact-commit worktree was used
instead. The first detached worktree preflight exposed a null branch-name error
in the finalizer; attaching that clean worktree to exact `main` satisfied the
existing policy without changing source. This closure change makes the branch
check null-safe so future detached invocations fail with the intended stable
message.

The first artifact-download attempt then lost its network connection before
package custody or built-tag creation. The unchanged finalizer reused the same
successful GitHub run and artifact name. It verified the same package hash,
completed dual custody and created the built tag without force or workflow
rerun.

Build 7 is finalized but remains non-distributable. No Firebase deployment,
production backfill, runtime-contract activation, production data mutation or
pilot handout is authorized by this closure. Physical execution still requires
a separate promotion bound to the exact package, APK and target device.
