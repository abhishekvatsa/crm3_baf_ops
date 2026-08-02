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
