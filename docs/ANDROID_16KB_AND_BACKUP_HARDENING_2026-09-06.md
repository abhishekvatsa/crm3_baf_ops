# Android 16 KB and Backup Hardening

## Scope

This successor source removes the two Android packaging defects identified in
the static inspection of Build 25. It does not allocate a build number, use the
production signer, deploy backend services, change App Check, or authorize
distribution.

## Native database package

- `isar_community`, `isar_community_flutter_libs`, and
  `isar_community_generator` are pinned to `3.3.2`.
- The approved package archive SHA-256 is
  `C44340FA38C81EF16D924202D443BBE799CDE4826BE9A31A9DC92EE612E1966F`.
- The Android package libraries for all four ABIs use ELF load alignment
  `0x4000`.
- APK construction now fails unless every native library is uncompressed,
  16 KB ZIP aligned, and has no ELF load segment below 16 KB alignment.
- The gate applies to CI package proof, the local release gate, and governed
  production artifact construction. The production manifest records the exact
  artifact's native-alignment and backup-policy passes for independent review.

Android's current requirement and testing guidance are recorded at
<https://developer.android.com/guide/practices/page-sizes>.

## Existing-phone continuity

The generated identities of all 25 Isar collections in 19 generated files are
unchanged from the exact Build 25 source commit
`c539490d87b6d0bb6dc226e871a95d6b7fc95150`. Generator-version text and
formatting are excluded from that comparison; collection IDs, property IDs and
types, indexes, links, and embedded schemas are not.

The fixture in `test/fixtures/isar_core_upgrade` was populated with the exact
Build 25 Windows native core from `isar_flutter_libs 3.1.0+1`, SHA-256
`5E67863F188C5F9681A37F84F2EB942EAF702509D3F994C0344D5049EBC9E48F`.
The maintained core opens the copied fixture, reads the retained issue and
charge evidence, writes a successor record, closes, reopens, and reads that
successor record. The fixture contains no production data.

## Android backup policy

The compiled application now sets `android:allowBackup="false"` and supplies
rules for both Android 11-and-lower full backup and Android 12+ cloud backup and
device transfer. Every credential, preference, database, internal file, and
external app-file domain is excluded. Artifact construction decodes the
compiled manifest and resources and fails closed if those exclusions are not
present.

Android's backup behavior and configuration guidance are recorded at
<https://developer.android.com/identity/data/autobackup>.

## Qualification boundary

Source analysis, the complete Flutter suite, populated migration tests, schema
identity comparison, and an ephemeral non-production APK/AAB proof pass. A
future candidate still requires clean review and CI, merge to `main`, governed
build-number allocation, production-signed construction, independent artifact
verification, and exact-artifact runtime acceptance. A 16 KB Android device or
emulator test remains part of that exact-build acceptance before distribution.
