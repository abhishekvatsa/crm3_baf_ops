# The fast development loop

This restores `run → exercise the real feature → inspect → fix → rerun` so that a
production build is no longer the first place anyone learns whether a feature
works.

The development app is the **real application**: same screens, repositories,
Isar schemas, sync code and callables. Only the backend endpoints and the
installed application id differ.

## First run

```powershell
pwsh -File tool/dev/setup_dev.ps1
```

Writes the local development Firebase override. `run_dev.ps1` does it for you if
the file is missing, so this is only needed if you want it done up front.

## Two terminals

```powershell
# terminal 1 — leave running
pwsh -File tool/dev/emulators.ps1
```

```powershell
# terminal 2
pwsh -File tool/dev/run_dev.ps1
```

Emulator UI: <http://127.0.0.1:4000>

Or without the scripts, setting the development identity yourself:

```bash
CRM3_DEV_APP=true flutter run --dart-define=CRM_USE_EMULATORS=true
```

Hot reload works normally.

## What protects production

**A separate installed app, opt in.** With `CRM3_DEV_APP=true` a debug build
takes `applicationIdSuffix = ".dev"`, so the development app installs as
`in.co.sail.bsl.crm3.bafops.dev` beside the signed production app, labelled
**CRM-III BAF Ops DEV**. It can never overwrite the production app, and you never
have to uninstall production — which would destroy its local records — just to
debug.

The suffix is opt-in rather than automatic for every debug build, because CI
also builds debug: the app-shell integration job and the CodeQL isolated Android
compilation both need the unchanged production id and the Firebase configuration
they already rely on.

This is a build-type suffix, not a product flavor, on purpose. Flavors rename
every Gradle task (`assembleRelease` becomes `assembleProdRelease`), which would
break the governed production-artifact workflow. Release output, application id
and signing are untouched.

**A demo project.** In emulator mode the app boots with `crm3DemoFirebaseOptions`,
whose project id must begin with `demo-`. The emulator suite accepts any project
id, but no real Firebase project is named `demo-…`, so a call that somehow is not
routed to an emulator **fails** instead of quietly reaching production.

**Refusals.** `connectCrm3Emulators()` throws if it is called in a release build,
without the dart-define, or against a non-demo project id.

**Debug-scoped Firebase config, never committed.**
`android/app/src/debug/google-services.json` carries the demo project. It is
gitignored and written locally by `setup_dev.ps1`, because
`tools/security/codeql/prepare_android.py` writes its own isolated override to
that same path inside the CodeQL runner and **refuses to replace an existing
file** — a committed copy breaks that job. The local file lists both the
suffixed and unsuffixed package ids so a debug build works either way. The
production `android/app/google-services.json` is unchanged.

## Physical device vs Android emulator

`run_dev.ps1` runs `adb reverse` for ports 8080, 9099 and 5001, which lets a USB
device reach the emulators on your machine. For the Android emulator you can
instead pass the host explicitly:

```bash
flutter run --dart-define=CRM_USE_EMULATORS=true --dart-define=CRM_EMULATOR_HOST=10.0.2.2
```

## Overridable defines

| Define | Default |
| --- | --- |
| `CRM3_DEV_APP` (environment, not a define) | unset (production identity) |
| `CRM_USE_EMULATORS` | unset (production) |
| `CRM_DEMO_PROJECT_ID` | `demo-crm3-baf-ops` |
| `CRM_EMULATOR_HOST` | `127.0.0.1` |
| `CRM_FIRESTORE_EMULATOR_PORT` | `8080` |
| `CRM_AUTH_EMULATOR_PORT` | `9099` |
| `CRM_FUNCTIONS_EMULATOR_PORT` | `5001` |

## What this does not replace

Debug mode cannot establish every release property. Release builds minify and
shrink resources, and emulators do not reproduce production IAM, App Check,
native sign-in or notification behaviour. Those still need the release-like and
final-device checks that already exist.

The point is not to remove release checks. It is to stop asking them to
compensate for a missing development stage.

## Not yet built

**Seeded fixtures.** The emulator starts empty. Exercising a real abnormality
journey needs approved and unapproved users, operational roles, active
abnormality types, charges and asset hierarchy. Seeding may create records
administratively, but the action under test must then go through normal
application permissions and the actual callable transport — otherwise it is just
another test that bypasses the path being investigated.

**An end-to-end journey test.** The existing
`integration_test/c04_operational_shell_android_test.dart` is a shell test: it
pumps individual screens with every provider overridden to an empty stream, and
asserts the empty state. It is correctly labelled *not physical-device evidence*,
but it cannot show that an operator can complete a task. A journey test must not
replace the repository or the callable with a fake that returns success.
