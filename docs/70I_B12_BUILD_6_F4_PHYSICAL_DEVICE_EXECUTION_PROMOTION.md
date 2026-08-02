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

The approved-sign-in receipt leaves five dimensions open. The merged runtime
has now confirmed the exact approved Home, local diagnostics and manual-sync
surfaces. The sync/network tranche may therefore proceed without granting the
harness authority over user roles or production business writes. Revocation
and wrong-role proof remain a separate subject/operator tranche.

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

## API-Level Binding Compatibility Correction

The first merged `Preflight` invocation stopped before evidence-directory
creation or device mutation. PowerShell 7 treated inline integer casts in the
positional API-level assertion as additional positional arguments. The harness
now resolves both API levels into typed local variables and supplies them to
`Assert-Equal` through named parameters.

This correction does not alter the expected API level, target, artifact,
authorized phases or mutation boundary. No preflight receipt, installation,
launch, authentication session or remote mutation was created by the stopped
invocation.

## Approved Sign-In Runtime Witness

The corrected campaign passed on merged source `0e8599d` and produced private,
privacy-minimized receipts with these seals:

- preflight:
  `AC98C6A5FB48CD8A987AE8E5A93239C29386E0BE916E51BA78710BA257716206`;
- exact install:
  `0884185A8ACAB9BF4E9B099E3451189F296F4FC33A8B1BB7AB67CF7F05634F51`;
- Google chooser:
  `AFA57D945E048F38E59AD9C8D98999C3401C189C60F3FDEC2FA271A83A6D833B`;
- same-process approved sign-in:
  `00F8A27452E27CA38A7D67C452AF53584FFBC617D80A04B69F0C75DBD4BD90A0`.

The final receipt proves the approved Home in the same application process as
the chooser. It retains no email, display name, Firebase uid, access token or
raw UI. Two earlier chooser starts stopped without a receipt: once after the
owner selected the authorized account before attestation, and once while the
device was locked. The owner signed out after the first stop and unlocked after
the second; neither stopped run is relabelled as passing evidence.

## Sync And Network Tranche

The harness now adds four ordered phases:

1. `CaptureSyncBaseline` reads the SI-visible, local-only diagnostics summary
   and stops unless pending local business writes equal zero.
2. `RunSyncMarker` performs one authenticated manual full sync, requires the
   success marker and re-proves zero pending writes without creating a
   synthetic production record.
3. `RunOfflineReconnect` captures Wi-Fi and mobile-data state, disables both,
   exercises manual sync without accepting a disconnected success, restores
   the exact state in `finally`, and requires a successful reconnect sync.
4. `RunWeakNetwork` applies three bounded interruption cycles with at least a
   five-second disconnected hold and ten-second restored hold. The first cycle
   also includes an eight-second sync-observation timeout. Receipts record the
   measured duration of every window, fail on a success observed while
   disconnected, restore the exact state in `finally`, and require a successful
   post-profile sync.

Each phase re-hashes the installed base APK and chains to the prior receipt.
UI evidence is immediately reduced to hashes and known outcome counts. Network
receipts retain only binary transport state; they retain no SSID, carrier,
address or other network identifier. A failed network phase writes a separate
failure receipt and cannot replace it with a pass in the same evidence chain.

After owner-reviewed merge, run the four phases in order against the existing
private campaign directory. Each invocation still requires the exact governed
package, discovery receipt and bound device parameters used above.

These phases can prove three more F4 dimensions, but they cannot close F4.
Revocation and wrong-role evidence still require the separate approved admin
operator, exact initial-role capture, request-bound governed authority writes,
and exact restoration. Pilot handout remains prohibited.

## Approved-Home Automatic-Variable Compatibility Correction

The first merged `CaptureSyncBaseline` invocation stopped during approved-Home
navigation before local diagnostics capture. PowerShell variable names are
case-insensitive, so the helper's local `$home` assignment attempted to replace
the read-only `$HOME` automatic variable. The helper now uses
`$approvedHome`, and the source contract rejects any future assignment to
`$HOME` in the harness.

The stopped invocation ran from merge commit `05f35fc`, with promotion SHA-256
`B7382D737430F428832B59B39DEE0656B3E8993FF861FB4E01A66229F45036CE` and
harness SHA-256
`F417A3BD6EB029B303B29705CED87A0EBBFD2BB9CAE9D05FBB42046721AC7463`.
No sync-baseline or network receipt was created, no transport state or remote
business data was mutated, and no raw identity was retained. The invoking Tee
pipeline returned the error but did not create its intended log file, so a
clearly labelled post-stop adjudication was stored outside the repository with
SHA-256
`63EA1D4BF8A5012A1E98F866D5763AD085AA1F10F41C99A1DFDCF7808CE1517D`.
It is not passing evidence and cannot be relabelled as such.

This compatibility correction does not expand the approved device, artifact,
phases, authority, distribution or pilot boundary. `STAGE2D-F4`, `P-07` and
pilot handout remain open.

## Retained More-Scroll Navigation Compatibility Correction

The corrected baseline then passed with zero unsynced rows and zero unresolved
rejections. Its receipt SHA-256 is
`FF07D7CF1A10204823CD85C939AA569FD793740412837986ED828F18EFCA6CDF`.
The first merged `RunSyncMarker` invocation subsequently stopped during its
pre-sync diagnostics navigation, before opening Support Diagnostics or invoking
manual sync.

The app was on the correct `More` tab with `Support Diagnostics` visible. Its
`ListView` had correctly retained the prior scroll position, so the
top-of-page sentence `Tools, records and administrative access.` was off-screen.
The harness incorrectly required that transient sentence before using the
exact, scroll-capable `Support Diagnostics` tile lookup. The correction removes
only that top-header prerequisite.

Because this additive amendment changes the promotion file hash, the harness
accepts the already passing baseline through one explicit lineage rule: both
its receipt hash and its embedded pre-amendment promotion hash must match the
values above. There is no generic prior-hash fallback, and no future unlisted
promotion lineage is accepted.

The stopped invocation ran from merge commit `feeb7f1`, with promotion SHA-256
`52FFB67CB43F501645F172B851FA3C0E1BBC59AB366CA4C1550EB43134EA92F1` and
harness SHA-256
`F638782278027500593FBACF2EE63480AA2CEE96CB876672CC26F37492073AFC`.
Its durable stderr log SHA-256 is
`C6BBC7F67A0E68D346AE0FE90E4C0D4D4C821476AAB2A932D19A87B22B704D33`.
No sync-marker receipt, manual sync, network-state mutation or remote business
mutation occurred. The temporary diagnostic screenshot was deleted and no raw
UI is retained.

This correction does not expand the approved artifact, target, phases,
authority, distribution or pilot boundary. The stopped attempt is not passing
evidence and cannot be relabelled as such.
