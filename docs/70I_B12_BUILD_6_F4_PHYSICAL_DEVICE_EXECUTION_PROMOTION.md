# Build 6 F4 Physical-Device Execution Promotion

## Decision

The passing target-discovery receipt is promoted into a one-artifact,
one-physical-device F4 campaign. The promotion is bound to hashes of the ADB
serial and build fingerprint; neither raw identifier is stored in the
repository or campaign receipts.

This promotion authorizes controlled execution. It does not itself create
device evidence, close `STAGE2D-F4` or `P-07`, or authorize pilot handout.

## Exact Authority

- Build 6 governed package SHA-256:
  `E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E`
- Embedded APK SHA-256:
  `01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755`
- Production certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`
- Target-discovery receipt SHA-256:
  `440874E51450BABA99ADD59AB47D19BF8D240F07BE9323373822E2FD81DB2825`
- Target-discovery decision:
  `PASS_BUILD6_F4_PHYSICAL_DEVICE_TARGET_CANDIDATE_READ_ONLY`

The campaign stops if source, artifact, receipt, signer or hashed target no
longer matches.

## Required Matrix

The six ledger dimensions remain individually required:

1. approved sign-in;
2. sync marker;
3. offline/reconnect;
4. weak-network;
5. revocation next-operation denial; and
6. wrong-role denials.

The sync marker is not a synthetic production record. It is a successful
authenticated manual full-sync receipt from the fresh installation, with zero
queued local business writes before and after. This proves the online sync path
without polluting production data.

Offline and intermittent-network exercises must restore the exact prior
Wi-Fi/mobile-data state even if the phase fails. They may not report a false
successful remote mutation while transport is unavailable.

## Identity Separation

Revocation and wrong-role proof require two identities:

- one approved SI, non-admin test subject on the bound physical device; and
- a different approved admin operator using the governed authority writer.

The subject must not be the last approved admin. Its initial approval and exact
role set must be captured before mutation. Revocation, reapproval, temporary
`operations`-only replacement and final exact-role restoration each require a
separate request-bound governed mutation. Direct Firestore authority edits are
not permitted.

If a separate subject and operator cannot be proved, the authority phases stop.
The owner or last-admin identity must not be repurposed merely to complete the
matrix.

## Harness Boundary

`tools/release/Invoke-Build6F4PhysicalDeviceCampaign.ps1` currently governs the
first campaign tranche:

- `Preflight` verifies exact merged source, promotion, discovery receipt,
  artifact, signer and hashed physical target without mutation;
- `Install` installs and launches the exact APK once, verifies the installed
  APK hash and retains no raw UI or target identifiers; and
- `FinalizeInstall` completes evidence only if an interrupted `Install` already
  left the exact APK on the bound target; it never reinstalls or replaces it;
- `BeginApprovedSignIn` opens the Google account chooser while retaining only
  its UI hash and the non-identity application process ID; and
- `CaptureApprovedSignIn` captures a privacy-minimized approved-home receipt
  after the owner selects the controlled SI/non-admin account, and proves that
  the app process did not change between chooser and approved home.

The remaining five dimensions are explicitly left open in the sign-in receipt.
Their evidence capture will proceed only after the installed runtime confirms
the exact app surfaces and the separate subject/operator prerequisite is met.
This prevents an untested automation assumption from acquiring authority over
production identity or business data.

After this promotion is merged to `main`, run the phases in order from a new
private evidence directory outside the repository:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\release\Invoke-Build6F4PhysicalDeviceCampaign.ps1" `
  -Phase Preflight `
  -GovernedPackagePath "<absolute-governed-package-path>" `
  -DiscoveryReceiptPath "<absolute-target-discovery-receipt-path>" `
  -DeviceSerial "<connected-target-serial>" `
  -EvidenceDirectory "<new-private-campaign-directory>"
```

Repeat with `-Phase Install` and then `-Phase BeginApprovedSignIn`. Select the
controlled SI/non-admin account on the phone and run
`-Phase CaptureApprovedSignIn` without relaunching the application. Use
`FinalizeInstall` only to complete evidence after a confirmed interrupted
installation; it is not a general retry path.

## Non-Authority

No receipt from this source tranche may be used to claim `DEVICE_PROVED`, close
`STAGE2D-F4` or `P-07`, authorize pilot handout, distribute Build 6, or alter
Firebase configuration. A later evidence adjudication must verify all six
phase receipts and clean restoration before any ledger transition.
