# Build 5 Runtime Validation Adjudication

Date: 2026-07-30

## Purpose

This record adjudicates the sealed Build 5 runtime execution against `P-01`
and `STAGE2D-F3`. It records a completed controlled local installation and
runtime proof; it does not authorize pilot handout, external distribution, or
unrestricted release.

The machine-readable authority is:

`release/evidence/build-5-runtime-validation-adjudication.json`

SHA-256:

`5401E163E7B0942B3B4FAFD810A2BE45492666CB8E750ABB54FC0741091FE551`

## Decisions

| Record | Prior | Adjudicated | Decision |
| --- | --- | --- | --- |
| `P-01` | `SOURCE_IMPLEMENTED` | `CLOSED` | The exact production-signed package completed fresh Google Sign-In and Firebase Authentication after explicit sign-out, proved the approved own-user record, and reached the approved-home gate without a debug-signing fallback. |
| `STAGE2D-F3` | `OPEN` | `CLOSED` | The exact APK hash, package/version/source/certificate binding, and one-target controlled local distribution channel are all proved. |

`STAGE2D-F4` is now the next governed mutation. Pilot handout remains
`NOT_AUTHORIZED`.

## Artifact And Channel

- Application ID: `in.co.sail.bsl.crm3.bafops`
- Version: `1.0.0-rc.1` (`5`)
- APK SHA-256:
  `1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C`
- Production certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`
- Channel: direct ADB from governed local custody
- Target: one named `Pixel_9` AVD on API 36
- Installed package: exact-hash verified and non-debuggable
- External distribution: not performed
- Pilot handout: not performed

The prior debug package and application sandbox were removed before the exact
production-signed APK was installed. This one-target local channel satisfies
F3 custody proof without claiming F4 physical-device evidence.

## Runtime Proof

The governed sequence performed an explicit in-app sign-out, returned to the
signed-out marker, displayed the Google Play Services account chooser, and
completed a fresh Google and Firebase Authentication exchange. A
privacy-minimized diagnostic proved that the selected identity was enabled,
verified and Google-linked and that exactly its own user document was complete,
canonical, email-matched and approved. No other user document was read.

The unchanged signed-in session then reached the approved-home gate. Repository
evidence retains no account email, display name, Firebase uid, raw chooser
hierarchy, or raw profile material.

## Source Remediation Boundary

Build 5 exposed a first-listener race: Firebase Authentication succeeded, but
the first Firestore profile listener ran before a usable ID-token context and
received `permission-denied`. The unchanged signed-in session reached approved
home immediately after relaunch.

PR #77 merged the fail-closed source repair at
`416fe777ffd52162de5666a860e185167ecf9e23`. The profile stream now follows
`idTokenChanges()` and permits only one same-uid retry after a forced token
refresh. A missing user, changed uid, non-permission error, or repeated denial
still fails closed.

Build 5 remains immutable and does not contain that repair. Every future pilot
artifact must be built from source containing PR #77.

## Evidence Custody

- Runtime receipt SHA-256:
  `C83231366BA07870A05CA1F92DD8E62CEEDD12916B36B79E6FDD4042D4DA053E`
- Private evidence inventory SHA-256:
  `90B0E8330BF9B5838CBDD6B47B71025C1A77F5B6599C20B77299CB1D1ACEE5BC`
- Sealed private archive SHA-256:
  `DD11CF79E073C41E339AC683524A0642C21BACA97605D186FD803644B57E0789`

The raw identity-bearing evidence and sealed archive remain outside the
repository. The committed adjudication contains only hashes, non-identifying
runtime invariants, and programme decisions.

## Residual Boundary

The diagnostic read App Check as `UNENFORCED` and found the active Firestore
Rules release was not byte-identical to repository `main`. Those facts remain
explicitly recorded and are not silently treated as fixed by this closure.
They do not negate P-01 or F3 proof, and neither closure authorizes F4, pilot
handout, external distribution, or unrestricted release.
