# Android business journey CI gate

The `android-emulator` job in `release-gate.yml` retains the C04 app-shell test
and then runs the eleven suites declared in
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
The fourth journey raises two maintenance-origin Quality cases on one charge,
records physical RA for one, and obtains separate SI adjudications with the
exact entered reasons preserved. It also logs two distinct direct abnormalities
on that charge, with and without completed RA. Canonical readback checks the
selected historical RA instant, process/result classification, independent open
cases and preservation of the unresolved physical maintenance records.

The fifth journey creates a fresh eight-position burner survey. I&A responds to
one resulting directive; the next round must attribute that fresh position and
retain the other seven positions' original evidence and unresolved UV condition.
It checks that no component installation was invented, the original survey is
unchanged, and Home/plant totals match the canonical physical population.

The sixth journey uses two separately authenticated Admin accounts and native
Isar repositories. A saves catalogue, legacy template and existing job work;
B cannot overwrite, send or acknowledge that work. It emits
`DEV_QUEUE_OWNERSHIP_PREPARED` with B still signed in and the original commands
pending, then exits. The runner force-stops only the DEV package without clearing
its data. A seventh journey launches a separate Android process, verifies B and
the same pending rows survived, and proves refusal remains in force. It then
returns to A to resume the original request, including a real accepted server
response deliberately left unacknowledged locally. Exact replay must preserve
the accepted version and receipt time before `DEV_QUEUE_OWNERSHIP_PASS` is emitted.
Both process markers are required in order; neither can substitute for the other.

The eighth and ninth journeys are the required-RED prepare/resume pair. Their
fresh synthetic parent/successor drafts must be published and assigned through
the actual UI; RED=yes and role handoffs are not seeded. A single owned Python
relay on 15002 forwards to Functions 15001 and withholds only one independently
validated successful compliance response. It preserves the original request
and response hashes; no accepted response is manufactured. Prepare requires
the native journal to remain unsettled, the actual server acknowledgement and
no second UI command. Resume retains app data, verifies the separate process
and saved session, releases only that exact command and requires identical
receipt replay before the remaining UI handoffs. Both distinct completion
markers are required in adjacent order. Relay evidence is create-only, and
only the runner's child process is stopped. These are configured checks until
an actual run completes; source presence is not a passing business proof.

The tenth and eleventh journeys are the Inner Cover fitness/withdrawal pair.
Setup supplies fourteen explicitly synthetic inventory/projection/link records:
Base 101 and Base 102 with distinct serial covers. These represent pre-existing
installed inventory; they do not prove real lifecycle registration or earlier
acceptance. The actual fitness journey creates the issue through the Operations
form, obtains separate SI confirmation and physical release, then verifies the
exact cover and linked Base retain the assessment hold. Its completion marker
must precede the withdrawal journey, which signs in as the separate Admin and
uses the real issue-deletion form. It delinks the cover and obtains a fresh
acceptance through the lifecycle UI, verifies that acceptance alone does not
settle the old concern, and then explicitly records the audited disposition.
The original withdrawn issue and bulge history, and the unrelated cover, must
remain unchanged. No stuck-up case, issue, release or disposition is seeded.
The runner enforces adjacent order and exact actor/marker identities. Each IC
journey uses a fresh DEV app session, while their backend state is retained.
The updated Functions handler must be compiled before these journeys run.

The result JSON labels each declared journey passed, failed, or untested, and
labels the run a CI demo candidate attempt. Build output and test success do
not establish signing, production release, physical acceptance or distribution.

The fixed project is `demo-crm3-ci-journeys`. Its loopback ports are 19099 (Auth),
18080 (Firestore), 15001 (Functions), 14400 (hub), 14500 (logging), and separate
19150/19299/19499 websocket/event/task ports. Port 15002 is the fixed loopback receipt-loss relay used only by the required-RED pair. The runner
refuses occupied ports, real device IDs, ambient or cached cloud credentials, and another
project. It starts its own emulator processes with the pinned Firebase CLI and
stops them through `emulators:exec`. It neither attaches to nor resets the
interactive `demo-crm3-baf-ops` suite. The Android application uses its DEV ID,
explicit emulator options, and `10.0.2.2` to reach the host.
The runner creates the ignored debug native Firebase configuration for only
this demo project and the DEV package, and refuses to overwrite a different
existing developer configuration.

The seed creates synthetic approved Operations, SI, Contract Supervisor, senior
Instrumentation, Refractory, senior Electrical and two Admin accounts, complete master data and three drafts
through SI-authenticated Rules.
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
business failure. An existing non-empty journey output directory is rejected
before seeding or starting the backend, preserving the original attempt logs.
Use a new disposable checkout/output attempt rather than deleting old evidence.
The job is bounded to 60 minutes to allow cold Android/backend
setup, eight permission-bootstrap debug builds, and twelve separate Flutter
integration invocations; each business process
also has its own shorter deadline.

All eighteen DEV suites are classified in the manifest: eleven selected and
seven explicitly excluded. The additional upgrade prepare/resume probes require
an independently bound baseline427 APK and a different candidate APK, the same
DEV package/signing, real main-store saves and an actual controlled network cut.
They are excluded because a same-source CI restart cannot establish an upgrade. The excluded files cover account diagnostic
tracing, frequent-issue/PDF fixtures, population-sensitive paging, historical
adjudication, human visual review, and the separate two-build upgrade pair.
Source configuration does not replace actual completion of any selected journey.
The gate does not certify physical-device behavior, production IAM/App Check,
offline network loss, PDF appearance, or production distribution.
