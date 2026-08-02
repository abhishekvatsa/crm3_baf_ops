# Build 7 F4 Prove-Read Locator Recovery

## Incident

The Build 7 compatibility campaign completed its exact-target preflight and
in-place upgrade. The subsequent `ProveRead` phase stopped before a controlled
row could be searched because Android 16 exposed the `Search rowCode` prompt in
the UIAutomator `hint` attribute. The harness searched only `text` and
`content-desc`, so it raised `Could not find UI control: Search rowCode`.

The failure was source-side harness incompatibility, not an application,
Firestore, authentication or Timestamp failure. No read receipt was created and
no production write occurred.

The first invocation of the merged recovery also stopped before creating its
locator witness. Android resumed the already-open Knowledge Governance route,
while the phase entry point demanded Home immediately after launch. A
privacy-safe diagnostic confirmed the expected application package and
Knowledge Governance screen, with no raw UI retained. Because the locator
witness and read receipt were both absent, this navigation stop did not consume
the one locator retry. The harness now routes every resumed phase through its
existing bounded approved-Home normalizer before continuing.

## Preserved Evidence

The original Build 7 promotion remains byte-for-byte unchanged. Its SHA-256 is
`39818BA2550AB962F87992467D0BD0AD7DD4B1D8CAE6D65CC738B80B6CB689F9`.
The recovery keeps the same private campaign and binds its already passing
receipts:

- preflight receipt SHA-256:
  `11B8AD068F6ED082B7D8FCE430C9A1D0329465DD13E009253E52E13945F8599D`;
- upgrade receipt SHA-256:
  `CB36DBBBACE68175782E55EA7509AF2B91D449D786D7B733A9F6768DFEBFB716`;
- failed harness source:
  `59489c25ff5e43faa6cca2fed6d9de1ff88cd126`;
- exact Build 7 APK SHA-256:
  `EE5B5B7205A37F1FEF1F1B4C98CB1446ED544A123E130D7F3A4134E6A5E6DD56`.

A fresh campaign is impossible without downgrading or reinstalling because the
physical target now correctly carries Build 7. Doing that would discard the
very in-place-upgrade continuity the campaign proved. The separate recovery
authority therefore overrides only the original new-directory requirement for
one read-only locator retry in the existing evidence directory.

## Recovery Contract

The machine-readable amendment is
`release/approvals/build-7-f4-prove-read-locator-recovery.json`. The harness
accepts it only through `RecoverProveReadLocator` and only from merged,
tracked-clean `main` equal to freshly fetched `origin/main`.

Before entering the controlled row identifier, the recovery must reproduce the
structural mismatch and write a privacy-safe witness proving:

- one matching `hint` control exists;
- neither `text` nor `content-desc` contains the marker;
- the old locator cannot resolve the control;
- the corrected locator can resolve it;
- raw UI XML is deleted after its hash is captured.

The corrected search recognizes `text`, `content-desc` or `hint`. The recovery
may navigate read-only app surfaces and create the active-row precondition
receipt. It cannot install an APK, mutate Firestore, retire the row, alter the
backend, or replace any earlier receipt. An existing failure witness or read
receipt causes the single recovery attempt to fail closed.

## Programme Boundary

This correction does not relabel the failed `ProveRead` attempt as passing. It
does not close `STAGE2D-F4` or `P-07`, authorize pilot handout, or release held
pull requests. It does not deploy Firebase resources, backfill production data,
or activate a runtime contract. Specifically, it does not activate the global-pull runtime contract.
A passing recovered read is only the prerequisite for the separately invoked,
one-row governed retirement and later evidence adjudication.
