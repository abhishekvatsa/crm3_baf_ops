# Build 9 Crashlytics startup remediation

Status: **SOURCE REMEDIATED / BUILD 9 NON-DISTRIBUTABLE**

## Runtime finding

Governed Build 9 was constructed and finalized from merge commit
`f51749c3f0200a5a03b065f0644d7759c747de7f`, but its first in-place launch on
the preserved physical-device installation failed before Flutter or the local
database opened. Android recorded `reason=4 (APP CRASH(EXCEPTION))` at
2026-08-12 01:41:37 and again at 01:42:11 local time.

The exception came from `FirebaseInitProvider`: the APK included the
Crashlytics runtime while the Android project did not apply the Crashlytics
Gradle plugin, so no Crashlytics mapping/build identity was generated. Build 9
is therefore disqualified from pilot, migration and distribution evidence. Its
successful construction, signature, finalization and dual custody do not
override the runtime failure.

## Bound evidence

- GitHub production run: `31528293704`
- Governed package SHA-256:
  `4D1EA1781FBAB0E047A1605644E329712E717B66A594147D55095DF21DF9960E`
- Production APK SHA-256:
  `BF1B412BA9A296FE3DE25C714002E0BAD2FB898920BE383712255D8B006670CB`
- Physical target identifier SHA-256:
  `D5BADBAE21E335B1E21A6A694445F3E7A454BFE5525650BFA9E1B1D637523E74`
- Private first-open screenshot: 219,886 bytes, SHA-256
  `D826BD987540C7691D816E90AC66A748ED43817660D2913A7AFDC0AA8F4AA380`
- Private first-open logcat: 340,187 bytes, SHA-256
  `F7B1984481027FF576D5CBCD85015FE232C502DC6A4FE1DBECB4B9644701284A`

The physical app was upgraded with `adb install -r`. Its first-install time and
stored data were retained. No cache or app data was cleared after the failure.

## Source correction

The Android root plugin catalogue now pins
`com.google.firebase.crashlytics` `3.0.7`, and the app module applies that
plugin. The secret-isolated package proof now reads the compiled release APK
and requires exactly one 32-hexadecimal
`com.google.firebase.crashlytics.mapping_file_id` value.

The every-PR Android release job now cold-starts that exact disposable-signed
release APK on a clean API 33 emulator. It fails closed if installation or
launch fails, the process is not alive after eight seconds, Android records an
application exception, or the crash buffer names the package. The proof does
not use production signing credentials, production backend authority, or a
physical device.

Local remediation proof used APK SHA-256
`3442EF1FEEED6323BD3D93F5B56117DBC40010E5DF484A6C02A8574ACF3CF892`.
The package contained the mapping identity, cold-launched successfully, kept
the app process alive and reached the real Google sign-in screen with no
Android exit or crash-buffer record.

## Successor boundary

A separately authorized, production-signed successor build is required. It
must pass the strengthened release gate and then upgrade the preserved Build 9
installation in place. Only that successor may produce installed-store,
migration, reconciliation, recovery or pilot evidence. This remediation does
not close P-06, STAGE2D-F6, or any distribution gate.
