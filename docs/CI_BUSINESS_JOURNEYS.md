# Android business journey CI gate

The `android-emulator` job in `release-gate.yml` retains the C04 app-shell test
and then runs the five suites declared in
`governance/ci-business-journeys.json` against real local Auth, Firestore Rules,
and Functions emulators. The gate is configuration for future CI runs, not a
claim that an unexecuted Android run has passed.

After seeding and before any Android business journey, the same isolated
emulators run the authenticated CF01 HTTP boundary suite through
`node functions/tools/run_retained_queue_emulator_tests.mjs --existing-ci`.
It proves all three retained queue commands reject account substitution and
V1 dispatch, accept the original actor once, retain exact replay evidence,
enforce project/payload and current approval checks, and deny direct Rules
writes while retaining approved reads. This mode starts, stops, and resets no
emulators. It accepts only the exact CI demo project and ports below, and emits
`CF01_HTTP_BOUNDARY_PASS` only after its fresh Jest report confirms the exact
seven-test suite passed without failures or skips. A nonzero exit or missing
verified marker stops the Android sequence. Its log and result status are
included in `output/ci-business-journeys`.

The selected sequence proves abnormality form submission, canonical acceptance,
the linked Quality warning and reopening; a second application process verifies
the accepted local record and session survive without a duplicate; then a clean
DEV installation publishes a fresh reviewed planned template, assigns the exact
asset, records worker responses, submits and independently accepts the module,
adds a diary, closes the lane, and obtains governed server completion. Each
process must exit successfully and emit its post-readback completion marker.
The planned run must also prove publication occurred through its UI in that run.
The fourth journey uses two separately authenticated Admin accounts and native
Isar repositories. A saves catalogue, legacy template and existing job work;
B cannot overwrite, send or acknowledge that work. It emits
`DEV_QUEUE_OWNERSHIP_PREPARED` with B still signed in and the original commands
pending, then exits. The runner force-stops only the DEV package without clearing
its data. A fifth journey launches a separate Android process, verifies B and
the same pending rows survived, and proves refusal remains in force. It then
returns to A to resume the original request, including a real accepted server
response deliberately left unacknowledged locally. Exact replay must preserve
the accepted version and receipt time before `DEV_QUEUE_OWNERSHIP_PASS` is emitted.
Both process markers are required in order; neither can substitute for the other.

The fixed project is `demo-crm3-ci-journeys`. Its loopback ports are 19099 (Auth),
18080 (Firestore), 15001 (Functions), 14400 (hub), 14500 (logging), and separate
19150/19299/19499 websocket/event/task ports. The runner
refuses occupied ports, real device IDs, ambient or cached cloud credentials, and another
project. It starts its own emulator processes with the pinned Firebase CLI and
stops them through `emulators:exec`. It neither attaches to nor resets the
interactive `demo-crm3-baf-ops` suite. The Android application uses its DEV ID,
explicit emulator options, and `10.0.2.2` to reach the host.
The runner creates the ignored debug native Firebase configuration for only
this demo project and the DEV package, and refuses to overwrite a different
existing developer configuration.

The seed creates synthetic approved Operations, SI, Contract Supervisor and two Admin
accounts, complete master data and one draft through SI-authenticated Rules.
Owner authority is used only for synthetic identity/catalogue setup. Publication,
assignment, worker acceptance, and closure are never seeded. A seed marker and
create-only preconditions refuse existing evidence rather than overwriting it.
App data is cleared only for the dedicated DEV package on a verified Android
emulator before independent journeys; it is preserved for the restart check.
Every Flutter test uses `--no-uninstall` so teardown preserves that evidence.

Before each independent journey, the runner builds its declared source as a
debug DEV APK with the same emulator/actor defines, checks its exact DEV package
identity and debuggable flag with SDK `aapt`, clears only prior DEV app data,
and installs the APK without launching it. It grants only
`android.permission.POST_NOTIFICATIONS` on that verified emulator. This prevents
the native Android permission dialog from blocking the application's real
awaited startup before Flutter can show sign-in. Failed or unexpected identity,
install, or permission responses stop the run. Flutter 3.44 `test` does not
support a prebuilt binary argument: it still builds and launches its normal
integration listener wrapper from source. This bootstrap does not replace the
application startup, backend transport, or business assertions. If Flutter
falls back to uninstalling an old package, the run fails rather than claiming
data or permission continuity. The separate-process restart gets no bootstrap,
clear, or permission change; it uses only force-stop and the normal update
installation performed by Flutter.

To inspect the commands without starting a device or writing data:

```sh
python3 tools/testing/run_ci_business_journeys.py --plan
```

To reproduce on a fresh disposable Android emulator, install Flutter dependencies,
the pinned `tooling/firebase-cli` dependencies, and Functions dependencies; build
Functions, then run:

```sh
python3 tools/testing/run_ci_business_journeys.py --device-id emulator-5554
```

CI uploads `output/ci-business-journeys` (per-suite logs and result JSON) plus
Firebase/Firestore diagnostics even on failure. No automatic rerun masks a
business failure. The job is bounded to 60 minutes to allow cold Android/backend
setup, three permission-bootstrap debug builds, and six separate Flutter
integration invocations; each business process
also has its own shorter deadline.

All twelve DEV suites are classified in the manifest. The seven excluded files
cover account diagnostic tracing, additional burner or frequent-issue/PDF
fixtures, population-sensitive paging, historical adjudication, and human visual
review. They are not silently included or represented as automated coverage.
The gate does not certify physical-device behavior, production IAM/App Check,
offline network loss, PDF appearance, or production distribution.
