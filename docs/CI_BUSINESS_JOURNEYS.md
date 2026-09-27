# Android business journey CI gate

The `android-emulator` job in `release-gate.yml` retains the C04 app-shell test
and then runs the three suites declared in
`governance/ci-business-journeys.json` against real local Auth, Firestore Rules,
and Functions emulators. The gate is configuration for future CI runs, not a
claim that an unexecuted Android run has passed.

The selected sequence proves abnormality form submission, canonical acceptance,
the linked Quality warning and reopening; a second application process verifies
the accepted local record and session survive without a duplicate; then a clean
DEV installation publishes a fresh reviewed planned template, assigns the exact
asset, records worker responses, submits and independently accepts the module,
adds a diary, closes the lane, and obtains governed server completion. Each
process must exit successfully and emit its post-readback completion marker.
The planned run must also prove publication occurred through its UI in that run.

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

The seed creates synthetic approved Operations, SI, and Contract Supervisor
accounts, complete master data and one draft through SI-authenticated Rules.
Owner authority is used only for synthetic identity/catalogue setup. Publication,
assignment, worker acceptance, and closure are never seeded. A seed marker and
create-only preconditions refuse existing evidence rather than overwriting it.
App data is cleared only for the dedicated DEV package on a verified Android
emulator before independent journeys; it is preserved for the restart check.

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
setup and four separate Flutter integration invocations; each business process
also has its own shorter deadline.

All ten DEV suites are classified in the manifest. The seven excluded files
cover account diagnostic tracing, additional burner or frequent-issue/PDF
fixtures, population-sensitive paging, historical adjudication, and human visual
review. They are not silently included or represented as automated coverage.
The gate does not certify physical-device behavior, production IAM/App Check,
offline network loss, PDF appearance, or production distribution.
