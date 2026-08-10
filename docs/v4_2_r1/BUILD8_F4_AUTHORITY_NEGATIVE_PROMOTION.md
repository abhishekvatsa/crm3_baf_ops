# Build 8 F4 authority-negative promotion

## Purpose

`STAGE2D-F4` already has adjudicated physical-device evidence for approved
sign-in, a successful sync marker, offline/reconnect recovery, and the accepted
bounded three-cycle intermittent-connectivity method. This tranche covers only
the two remaining criteria:

1. revocation before the next privileged operation; and
2. wrong-role denial and capability removal.

The collector does not close `STAGE2D-F4` or `P-07`. Its final output is an
append-only evidence set that requires separate adjudication.

## Two-session topology

The subject remains the production-signed Build 8 app on the physical Android
device. It uses an approved SI identity that is not an Admin. A different,
approved Admin identity runs the same byte-exact Build 8 APK on the controlled
emulator and performs authority changes only through **Administration > Users**.
That screen calls the deployed `mutateUserAuthority` function.

This narrow topology supersedes the old Build 6 single-target restriction only
for the Admin operator. It does not authorize a second subject, a different APK,
direct database writes, or distribution.

## Why the wrong-role proof is composite

Build 8 has no harmless SI-only server mutation whose accidental authorization
would be guaranteed to produce no write. Creating a synthetic production record
just to prove rejection would weaken the safety boundary.

The accepted proof therefore combines:

- a physical same-process witness that an SI-to-Operations role change removes
  Administration, Template authoring, Legacy template publisher, Knowledge
  governance, and Support diagnostics; and
- the exact deployed backend regressions proving that Operations is rejected
  from published-template assignment, planned-job completion, and Admin/SI-only
  workflow commands.

This method may establish the F4 wrong-role criterion after adjudication. It may
not be described as a live physical server-mutation denial, because no such
mutation is attempted.

## Execution sequence

Run the collector from clean, freshly fetched `main`, with the physical subject
and emulator operator attached simultaneously. Evidence must be written outside
the repository.

1. `Preflight` verifies both installed APKs byte-for-byte, confirms device
   separation, captures the subject's exact role preimage, checks SI/Admin UI
   separation, and binds a fresh function-fleet readback. The readback must
   retain the deployed Firebase source hash for every authority function so the
   collector can prove that all four surfaces share one admitted deployment.
   Fleet-finalization, function-update and receipt-capture timestamps are
   canonical UTC values parsed independently of the operator machine's locale.
   The simultaneous ADB inventory parses authorized serials independently of
   Windows or Unix line endings. Installed-package paths are retained as an
   explicit collection so a valid single APK cannot collapse into a scalar.
   Capability checks use exact accessibility-label segments; section headings
   such as `Administration and support` cannot satisfy the `Administration`
   command marker.
2. The separate Admin revokes the subject through User Management.
   `CaptureRevoked` must observe **Awaiting Approval** in the original physical
   app process.
3. The Admin approves the subject through a distinct request.
   `CaptureRevocationRestored` must prove the exact role preimage and SI surface
   are restored before the campaign continues.
4. The Admin replaces the subject role set with Operations only.
   `CaptureWrongRole` must observe the role-limited physical UI in the same
   process and bind it to the deployed server-denial witnesses.
5. The Admin restores the exact preflight role set through a distinct request.
   `CaptureFinalRestoration` must prove the full original state is back and the
   operator remains an approved Admin.

The collector refuses to replace an existing pass or failure receipt. Any
failure after preflight requires authority restoration to be verified before a
retry.

## Safety boundary

The tranche forbids direct Firestore/Admin SDK/REST authority writes, synthetic
business records, subject-token minting, raw account or device identifiers,
physical-app force-stop/relaunch/data clear, Firebase deployment, and any final
gate or pilot claim from collector output alone.

The exact authority is
`release/approvals/build-8-f4-authority-negative-promotion.json`; the executable
collector is
`tools/release/Invoke-Build8F4AuthorityNegativeCampaign.ps1`.
