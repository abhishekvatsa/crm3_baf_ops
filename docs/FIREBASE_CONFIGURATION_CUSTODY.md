# Governed Firebase Configuration Custody

## Purpose

This document distinguishes three authentic Firebase Android configuration states and identifies the only current build authority. Configuration changes are custody changes; they do not authorise Firebase deployment, App Check enforcement, production signing, artifact distribution, or production-data mutation.

## Permanent Android app

| Field | Current authority |
|---|---|
| Firebase project | `crm3-baf-ops-b8638` |
| Android package | `in.co.sail.bsl.crm3.bafops` |
| Firebase Android app ID | `1:894346496105:android:fba14febfbbee102e63af8` |
| Debug SHA-1 | `30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31` |
| Debug SHA-256 | `B0B0EF9B348F5D474356AEB79182483B98829012FC25EB3EDCD517D11563C6D5` |
| Debug OAuth client | `894346496105-hmk7941e55ph206e6nr6ifvvqqqf7ee6.apps.googleusercontent.com` |
| Production SHA-1 | `41C2B828C71683A50EC346D19E1D44048758438D` |
| Production SHA-256 | `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C` |
| Production OAuth client | `894346496105-oljmi6mm7o790ue6o7cgcs20cakanjkg.apps.googleusercontent.com` |

Both debug and production signing identities are intentionally retained on the same permanent Firebase Android app.

## Configuration lineage

| State | SHA-256 | Semantic SHA-256 | Disposition |
|---|---|---|---|
| 23 June BAF-REF-005 production registration source | `730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A` | not recorded | Historical authority; proves the original production registration |
| 5–23 July debug-only canonical/live configuration | `DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D` | `8BB5FFA242C09AB10323D9B8F1FF560724B045EC39D2EA565367F057EE49DC1F` | Superseded after additive production-signing restoration |
| Current combined Firebase restoration artifact (UTF-8 CRLF) | `2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B` | `A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2` | Immutable restoration evidence authority |
| Current combined repository Git blob (UTF-8 LF) | `6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7` | `A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2` | **Current repository/build authority** |

The two current hashes are byte-representation variants of the same exact
semantic JSON. Firebase restoration evidence retained CRLF line endings; Git
normalizes the tracked file to LF through `.gitattributes`. Neither hash
authorizes any other content or a manually reconstructed configuration.
The restoration receipt follows the same custody rule: its CRLF evidence hash
is `FAD4C1516BD681E7A6756282B241B52AE54FC1AB9290AA15DC27719925EFBF3B`,
while its LF Git-blob hash is
`CCE70C3FC7E541C72E29F6732502BDF313633B3AF4A49F1923DD2D440AFBEA13`.

## Source authorities

- `release/approvals/firebase-registration-receipt.json` — immutable historical BAF-REF-005 receipt.
- `release/approvals/firebase-production-signing-restoration-receipt.json` — exact restoration receipt from the successful live Firebase evidence.
- `release/production-release-policy.json` — current release-policy binding.
- `docs/v4_2_r1/FIREBASE_COMBINED_AUTHORITY_RECONCILIATION.json` — machine-readable chronology and evidence binding.
- Restoration evidence ZIP SHA-256: `24C335AF607595363F4C1D9E68B81AC9E558D37FB49263DE16EF87136D58E6CF`.

## Restoration and verification procedure

1. For the tracked repository file, require raw SHA-256 `6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7`. For the immutable CRLF restoration artifact, require `2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B`.
2. Verify the permanent package/app identity and both Android OAuth clients.
3. Verify the historical BAF-REF-005 receipt remains unchanged; do not rewrite it to look current.
4. Verify `CRM3-FB-RESTORE-001-C1` and its evidence hash through the current policy and reconciliation record.
5. Run `tools/release/Test-ProductionReleasePolicy.ps1`.
6. Run the authoritative R1 local laboratory with all Flutter, Firestore Rules, governed Functions-emulator, audit and APK gates.

## Prohibited shortcuts

- Do not restore the historical `730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A` file over the combined file.
- Do not revert to the debug-only `DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D` file.
- Do not manually merge or edit OAuth entries.
- Do not remove either debug or production certificate fingerprints.
- Do not enable App Check enforcement or deploy Firebase resources as part of configuration custody.
