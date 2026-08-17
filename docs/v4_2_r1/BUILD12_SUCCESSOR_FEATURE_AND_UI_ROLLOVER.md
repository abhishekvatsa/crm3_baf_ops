# Build 12 successor feature and UI rollover

Status: SOURCE AUTHORIZED; REMOTE RESERVATION, SIGNING, DEPLOYMENT AND DEVICE PROOF PENDING

## Purpose

Build 12 is the first separately numbered candidate intended to carry the
accepted post-Build-11 business and user-interface campaign onto a controlled
device. It exists because installing current source under Build 11's identity
would misrepresent the sealed artifact already in custody.

The frozen source baseline is:

- commit `b020dc639cd0b69bf09808de9f6a750cde38259c`;
- tree `a65ff08db541bea2aa72c6930ead60b430028eea`;
- GitHub Actions run `32062710341`, with all five release-gate jobs passed;
- canonical audit `144/144`.

The candidate identity is:

- version `1.0.0-rc.2+12`;
- release ID `crm3-baf-ops-1.0.0-rc.2-b12`;
- remote reservation `crm3-build-reserved/12`;
- remote built authority `crm3-build-built/12`.

## Included capability campaign

Build 12 carries the merged source for:

- dynamic asset hierarchy, tag ownership and governed asset selection;
- operational assurance requests and maintenance supervision;
- asset condition, down/unfit status and plant overview;
- quality warnings, cycle monitoring and operations disruption handling;
- business-aligned reports and command-centre views;
- inner-cover lifecycle, pool, fabrication provenance and base pairing;
- burner lockout attendance, microamp capture, condition rounds and reliability reporting;
- component replacement and revision history;
- role-aware industrial UI and navigation refresh;
- A-02 through A-05 architecture and persisted-state integrity hardening.

This list identifies included source capability. It does not claim production
deployment or physical-device acceptance before those steps produce exact
evidence.

## Preserved authority

Exact Build 11 remains immutable. Its finalization receipt, package hash,
signing certificate and controlled-pilot promotion remain historically valid
only for that artifact. Build 12 does not broaden Build 11's roster or
distribution scope.

Build 12 begins as a production-signed, non-distributable candidate. Creating
or finalizing it does not authorize pilot handout, public distribution,
production data mutation, App Check activation or an unrestricted plant
release.

## Required sequence

1. Merge the Build 12 source authority only after exact-head CI passes.
2. Deploy the exact successor Functions, Firestore Rules and indexes through
   the governed production path and capture readback against the merged commit.
3. Dispatch the production-signing workflow from exact live `main`, obtain the
   protected-environment approval and atomically consume build number 12.
4. Independently verify and finalize the signed APK/AAB into dual custody.
5. Install the exact signed APK as an in-place upgrade. Uninstall and app-data
   clearing are prohibited.
6. Prove startup, sign-in, local-store migration, sync and representative
   role/business flows, including burner and asset workflows and the refreshed
   UI.
7. Record a separate pilot decision. No distribution follows automatically.

## Device acceptance minimum

The physical-device receipt must bind package hash, version, source commit,
signing certificate and target identity. It must show that pre-upgrade app data
was preserved and that no uninstall or data clear occurred.

At minimum, device validation covers:

- cold and warm start;
- existing approved-user sign-in and profile authority;
- local-store migration and recovery diagnostics;
- manual sync and offline/reconnect behavior;
- role-appropriate navigation and denial behavior;
- asset hierarchy and asset-condition visibility;
- burner lockout creation/attendance, per-burner actions and microamp capture;
- one additional representative business flow for quality, operations support
  or planned maintenance;
- visual checks on the refreshed home, work and reporting surfaces.

Any failed integrity, migration, authority or backend-compatibility check stops
the campaign without clearing the device or weakening source controls.
