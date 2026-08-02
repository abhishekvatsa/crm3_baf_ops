# Build 7 F4 Physical Firestore Compatibility Promotion

## Decision

The finalized Build 7 candidate is promoted to one exact-target compatibility
campaign. The campaign may upgrade the existing Build 6 installation in place,
prove that the stamped knowledge row can be pulled and rendered, and retire
only that controlled row through Knowledge Governance.

This promotion does not activate the global-pull runtime contract, perform a
backfill, deploy Firebase, alter network state, distribute the app, close
`STAGE2D-F4` or `P-07`, or release held pull requests.

The machine-readable authority is
`release/approvals/build-7-f4-firestore-compatibility-promotion.json`.

## Exact Lineage

- source baseline before this promotion:
  `9b6bb0c27f8585470e743f352ccd2922561344a3`;
- finalized Build 7 source:
  `d8619ef1a9c7bf53828523c4bca3efe33e4074f0`;
- governed package SHA-256:
  `D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7`;
- embedded APK SHA-256:
  `EE5B5B7205A37F1FEF1F1B4C98CB1446ED544A123E130D7F3A4134E6A5E6DD56`;
- Build 7 finalization receipt SHA-256:
  `F9788C0DD9BB7DB0B21A43FF461D68CEBC85A2135E16DA68E1ABA8342B1B1337`;
- required installed predecessor APK SHA-256:
  `01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755`;
- production signer certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`.

The target is bound by hashes of its ADB serial and build fingerprint. Raw
identifiers are used only as local invocation inputs and are not written to the
repository or receipts.

## Why This Path

Build 6 successfully created
`knowledge_base/zz-f4-global-pull-compat-v1`. The deployed server-clock trigger
then added a native Firestore `Timestamp`. Build 6 could not JSON-encode that
value while refreshing its local cache. Pull request 111 corrected the decoder,
but the immutable Build 6 package cannot carry the correction.

Build 7 already contains the fix. The campaign opens Template Authoring because
its existing knowledge loader performs the bounded cloud-to-local refresh
without requiring the still-inactive global-pull runtime contract. Knowledge
Governance then proves the exact row is locally renderable before any mutation.

## Ordered Phases

1. `Preflight` verifies exact source, custody, receipts, signer, target and the
   currently installed Build 6. It writes private evidence only.
2. `Upgrade` uses `adb install --no-streaming -r` once, verifies exact Build 7,
   preserves first-install time and requires the approved session to reach Home.
3. `ProveRead` opens Template Authoring, searches for the exact controlled row,
   then proves Knowledge Governance renders it as `active`.
4. `RetireRow` requires the separate passing read receipt, retires only that row
   with the fixed governed reason, and proves the governed update completes and
   the row renders as `retired`.

`FinalizeUpgrade` and `FinalizeRetirement` are evidence-only recovery phases.
They may be used only after the corresponding operation completed but receipt
creation was interrupted. They never reinstall or write the retirement twice.

## Invocation

Run each phase from a new private evidence directory outside the repository,
after this promotion is merged and exact `main` passes CI:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\release\Invoke-Build7F4FirestoreCompatibilityCampaign.ps1" `
  -Phase Preflight `
  -GovernedPackagePath "<absolute-Build-7-governed-package>" `
  -Build6EvidenceDirectory "<absolute-private-Build-6-campaign-directory>" `
  -DeviceSerial "<connected-bound-target>" `
  -EvidenceDirectory "<new-private-Build-7-campaign-directory>"
```

Repeat with `Upgrade`, `ProveRead` and `RetireRow`. Use a Finalize phase only
when the harness explicitly identifies the corresponding interrupted boundary.

## Boundary

The only authorized business-document mutation is the lifecycle update of
`knowledge_base/zz-f4-global-pull-compat-v1` from `active` to `retired`. The
expected governance audit and the trigger's stamp-only follow-up are consequences
of that exact app action; the separate active-row read is the evidence that
native `Timestamp` decoding passed. No second knowledge row, manual global sync, direct
Firestore write, Firebase deployment, backfill, runtime activation, network
profile or distribution action is authorized.

Even a fully passing campaign creates compatibility evidence only. A separate
adjudication must determine what it proves for the wider F4 matrix. Pilot
handout remains prohibited.
