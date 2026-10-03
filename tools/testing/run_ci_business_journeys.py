"""Run the declared Android business journeys against isolated local Firebase.

Use --plan for mutation-free orchestration inspection. Normal execution requires
an Android emulator (never a physical device), refuses ambient cloud credentials,
and starts/stops only its dedicated Firebase processes through emulators:exec.
"""
from __future__ import annotations

import argparse
from contextlib import ExitStack, contextmanager
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance/ci-business-journeys.json"
PROJECT = "demo-crm3-ci-journeys"
DEV_APP = "in.co.sail.bsl.crm3.bafops.dev"
PORTS = (19099, 18080, 15001, 15002, 14400, 14500, 19150, 19299, 19499)
OUTPUT = ROOT / "output/ci-business-journeys"
CLI = ROOT / "tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js"
HTTP_BOUNDARY_COMMAND = ["node", "functions/tools/run_retained_queue_emulator_tests.mjs", "--existing-ci"]
HTTP_BOUNDARY_MARKER = "CF01_HTTP_BOUNDARY_PASS"
RED_PATHS = ("integration_test/dev_required_red_journey_test.dart",
             "integration_test/dev_required_red_resume_journey_test.dart")
RED_RELAY = "tools/testing/required_red_transport_relay.py"
IC_PATHS = ("integration_test/dev_inner_cover_fitness_journey_test.dart",
            "integration_test/dev_withdrawn_inner_cover_journey_test.dart")


def require_red_sequence(journeys):
    selected = [row for row in journeys if row["path"] in RED_PATHS]
    if not selected:
        return
    if ([row["path"] for row in selected] != list(RED_PATHS)
            or [row["preserveAppData"] for row in selected] != [False, True]
            or [row["successMarker"] for row in selected] !=
               ["DEV_REQUIRED_RED_PREPARED", "DEV_REQUIRED_RED_PASS"]):
        raise ValueError("Required RED proof needs the exact prepare/resume pair")
    indexes = [journeys.index(row) for row in selected]
    if indexes[1] != indexes[0] + 1:
        raise ValueError("Required RED resume must immediately follow prepare")


def require_inner_cover_sequence(journeys):
    # Withdrawal consumes the case created and released by the actual fitness
    # journey. Resetting this pair's app data is safe; resetting its backend or
    # substituting a pre-seeded case is not a valid business proof.
    selected = [row for row in journeys if row["path"] in IC_PATHS]
    if not selected:
        return
    if ([row["path"] for row in selected] != list(IC_PATHS)
            or [row["preserveAppData"] for row in selected] != [False, False]
            or [row["successMarker"] for row in selected] !=
               ["DEV_IC_FITNESS_PASS", "DEV_WITHDRAWN_PASS"]
            or [row["actorEmail"] for row in selected] !=
               ["dev.operations@example.invalid", "dev.cf01-b@example.invalid"]):
        raise ValueError("Inner Cover proof needs the exact fitness/withdrawal pair and actors")
    indexes = [journeys.index(row) for row in selected]
    if indexes[1] != indexes[0] + 1:
        raise ValueError("Inner Cover withdrawal must immediately follow fitness")


@contextmanager
def required_red_relay(env):
    """Own only this child; do not attach to an existing relay or reuse evidence."""
    require_isolated_environment(env, inside=True)
    evidence = OUTPUT / "required-red-relay"
    log_path = OUTPUT / "required-red-relay.log"
    if evidence.exists() or log_path.exists():
        raise RuntimeError("Required RED relay evidence already exists; refusing reuse")
    with socket.socket() as probe:
        if probe.connect_ex(("127.0.0.1", 15002)) == 0:
            raise RuntimeError("Required RED relay port is occupied")
    with log_path.open("x", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, RED_RELAY, "--evidence-dir", str(evidence)],
                                   cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while True:
                if process.poll() is not None:
                    raise RuntimeError("Required RED relay exited before readiness")
                lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                ready = [line.removeprefix("REQUIRED_RED_RELAY_READY ") for line in lines
                         if line.startswith("REQUIRED_RED_RELAY_READY ")]
                if ready:
                    expected = {"listen": ["127.0.0.1", 15002], "upstream": ["127.0.0.1", 15001],
                                "project": PROJECT, "businessResponsesFabricated": False}
                    if len(ready) != 1 or json.loads(ready[0]) != expected:
                        raise RuntimeError("Unexpected Required RED relay readiness identity")
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Required RED relay readiness timed out")
                time.sleep(0.1)
            yield process
            if process.poll() is not None:
                raise RuntimeError("Required RED relay exited during the two-process proof")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)




def require_fresh_output():
    # A later attempt must retain the original seed, assertion and result logs.
    # The outer process creates this directory empty; only its child fills it.
    if OUTPUT.exists() and (not OUTPUT.is_dir() or any(OUTPUT.iterdir())):
        raise RuntimeError("Business journey output already contains evidence; use a fresh attempt without overwriting it")


def load_manifest():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest["projectId"] != PROJECT or manifest["schemaVersion"] != 1:
        raise ValueError("Unexpected business-journey project/schema")
    return manifest


def device_id(value):
    if not re.fullmatch(r"emulator-[0-9]+", value):
        raise ValueError("Only an explicit Android emulator ID is allowed")
    return value


def flutter_command(journey, device):
    return ["flutter", "test", journey["path"], "-d", device_id(device),
            # Retain the preceding process's real Isar/session state for the
            # restart journey; explicit per-journey reset is owned below.
            "--no-pub", "--no-uninstall", "--reporter", "expanded",
            "--dart-define=CRM_USE_EMULATORS=true",
            "--dart-define=CRM_EMULATOR_HOST=10.0.2.2",
            f"--dart-define=CRM_DEMO_PROJECT_ID={PROJECT}",
            "--dart-define=CRM_FIRESTORE_EMULATOR_PORT=18080",
            "--dart-define=CRM_AUTH_EMULATOR_PORT=19099",
            f"--dart-define=CRM_FUNCTIONS_EMULATOR_PORT={15002 if journey['path'] in RED_PATHS else 15001}",
            f"--dart-define=CRM_DEV_EMAIL={journey['actorEmail']}",
            f"--dart-define=CRM_DEV_DISPLAY_NAME={journey['actorName']}",
            "--dart-define=CRM_QUALITY_SI_EMAIL=dev.usability-si@example.invalid",
            "--dart-define=CRM_DEV_SECRET=emulator-local-only"]


def flutter_build_command(journey, device):
    defines = [part for part in flutter_command(journey, device) if part.startswith("--dart-define=")]
    return ["flutter", "build", "apk", "--debug", "--no-pub", "--target", journey["path"], *defines,
            # flutter test supplies this itself when building its listener wrapper.
            "--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false"]


def require_isolated_environment(env, *, inside):
    for name in ("GOOGLE_APPLICATION_CREDENTIALS", "FIREBASE_TOKEN"):
        if env.get(name):
            raise ValueError(f"CI journeys refuse ambient {name}")
    home = env.get("HOME") or env.get("USERPROFILE")
    config = Path(env["XDG_CONFIG_HOME"]) if env.get("XDG_CONFIG_HOME") else (
        Path(home) / ".config" if home else None)
    credential_files = []
    # The CLI can create a credential-free preferences file while starting;
    # only the outer admission checks that its pre-existing profile is absent.
    if config and not inside:
        credential_files.append(config / "configstore/firebase-tools.json")
    if home:
        credential_files.append(Path(home) / ".config/gcloud/application_default_credentials.json")
    if env.get("APPDATA"):
        credential_files.append(Path(env["APPDATA"]) / "gcloud/application_default_credentials.json")
    if any(path.is_file() for path in credential_files):
        raise ValueError("Use a credential-free CI/container account; cached cloud credentials are present")
    if env.get("CRM_DEMO_PROJECT_ID", PROJECT) != PROJECT:
        raise ValueError("Refusing a different demo or production project")
    if inside and env.get("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:18080":
        raise ValueError("The dedicated Firestore emulator must be running")
    if inside and env.get("FIREBASE_AUTH_EMULATOR_HOST") != "127.0.0.1:19099":
        raise ValueError("The dedicated Auth emulator must be running")


def run_logged(command, name, timeout, env):
    path = OUTPUT / f"{name}.log"
    print(f"CI business journey: {name}", flush=True)
    with path.open("w", encoding="utf-8") as log:
        executable = shutil.which(command[0], path=env.get("PATH")) or command[0]
        result = subprocess.run([executable, *command[1:]], cwd=ROOT, env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=timeout, check=False)
    text = path.read_text(encoding="utf-8", errors="replace")
    if result.returncode:
        print(text[-12000:], flush=True)
        raise RuntimeError(f"{name} exited {result.returncode}; see {path}")
    return text


def prepare_android_config(root=ROOT):
    target = root / "android/app/src/debug/google-services.json"
    expected = {
        "project_info": {"project_number": "000000000000", "project_id": PROJECT,
                         "storage_bucket": f"{PROJECT}.appspot.com"},
        "client": [{"client_info": {
            "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
            "android_client_info": {"package_name": DEV_APP}},
            "oauth_client": [],
            "api_key": [{"current_key": "AIzaSyDEMOEMULATORONLYNOTAREALKEY000000"}],
            "services": {"appinvite_service": {"other_platform_oauth_client": []}}}],
        "configuration_version": "1",
    }
    if target.exists():
        if json.loads(target.read_text(encoding="utf-8")) != expected:
            raise RuntimeError("Existing Android debug Firebase config differs; refusing overwrite")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("x", encoding="utf-8") as output:
        output.write(json.dumps(expected, indent=2) + "\n")


def require_android_emulator(device):
    qemu = subprocess.check_output(["adb", "-s", device_id(device), "shell", "getprop",
                                    "ro.kernel.qemu"], text=True, timeout=15).strip()
    if qemu != "1":
        raise RuntimeError("Selected device is not an Android emulator")


def clear_ci_app(device):
    # Data clearing is allowed only on the disposable AVD and only for DEV.
    require_android_emulator(device)
    probe = subprocess.run(["adb", "-s", device, "shell", "pm", "path", DEV_APP],
                           capture_output=True, text=True, timeout=15, check=False)
    installed, error = probe.stdout.strip(), probe.stderr.strip()
    # Android returns empty exit 1 when this fresh AVD has no DEV app yet.
    # Only that precise absence (or empty success) is safe to continue past.
    if not installed and not error and probe.returncode in (0, 1):
        return
    if (probe.returncode != 0 or error or not installed
            or any(not line.startswith("package:/") for line in installed.splitlines())):
        raise RuntimeError("Could not verify the disposable DEV package state")
    result = subprocess.check_output(["adb", "-s", device, "shell", "pm", "clear", DEV_APP],
                                     text=True, timeout=15).strip()
    if result != "Success":
        raise RuntimeError("Could not initialize the disposable DEV application")


def prepare_ci_journey(journey, device, env):
    """Install without launching so Android's native permission UI cannot block startup."""
    require_android_emulator(device)
    if env.get("CRM3_DEV_APP") != "true" or env.get("CRM_DEMO_PROJECT_ID") != PROJECT:
        raise RuntimeError("Notification setup requires the isolated DEV build environment")
    sdk = env.get("ANDROID_HOME") or env.get("ANDROID_SDK_ROOT")
    build_tools = Path(sdk) / "build-tools" if sdk else None
    versions = sorted(
        (path for path in build_tools.iterdir() if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", path.name)),
        key=lambda path: tuple(int(part) for part in path.name.split(".")), reverse=True,
    ) if build_tools and build_tools.is_dir() else []
    aapt = next((path / name for path in versions for name in ("aapt", "aapt.exe")
                 if (path / name).is_file()), None)
    if aapt is None:
        raise RuntimeError("Android SDK aapt is required to verify the DEV APK identity")
    run_logged(flutter_build_command(journey, device),
               Path(journey["path"]).stem + "-build", journey["timeoutSeconds"], env)
    apk = ROOT / "build/app/outputs/flutter-apk/app-debug.apk"
    if not apk.is_file():
        raise RuntimeError("The declared DEV journey did not produce its debug APK")
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(apk)],
                                      text=True, timeout=30, stderr=subprocess.STDOUT)
    identities = re.findall(r"^package: name='([^']+)'", badging, re.MULTILINE)
    if identities != [DEV_APP] or "application-debuggable" not in badging.splitlines():
        raise RuntimeError("Refusing to install a package other than the verified debug DEV app")
    clear_ci_app(device)
    try:
        installed = subprocess.check_output(["adb", "-s", device, "install", "-r", "-t", str(apk)],
                                            text=True, timeout=120, stderr=subprocess.STDOUT).strip()
    except subprocess.CalledProcessError as error:
        raise RuntimeError("Verified DEV package installation failed: " +
                           (error.output or "ADB returned no diagnostic output").strip()[-4000:]) from None
    if not installed or installed.splitlines()[-1] != "Success":
        raise RuntimeError("Could not install the verified DEV journey package")
    granted = subprocess.check_output(["adb", "-s", device, "shell", "pm", "grant", DEV_APP,
                                      "android.permission.POST_NOTIFICATIONS"],
                                     text=True, timeout=15, stderr=subprocess.STDOUT).strip()
    if granted:
        raise RuntimeError("Could not grant the DEV app's startup notification permission")
    # Flutter 3.44 test builds its own wrapper and has no prebuilt-APK option.
    # Its ordinary update install retains this same package's permission; the
    # actual startup and all business assertions still run in the real test.


def execute_journeys(device, manifest, env):
    require_red_sequence(manifest["journeys"])
    require_inner_cover_sequence(manifest["journeys"])
    require_fresh_output()
    report = {"project": PROJECT, "physicalDeviceEvidence": False,
              "artifactKind": "CI demo candidate attempt", "productionDistribution": False,
              "attempts": [{"path": row["path"], "status": "untested"} for row in manifest["journeys"]],
              "productionBackendUsed": False, "httpBoundary": {"status": "notRun"},
              "journeys": [], "status": "failed"}
    try:
        run_logged([sys.executable, "tools/testing/seed_ci_business_journeys.py"], "seed", 180, env)
        report["httpBoundary"] = {"status": "failed"}
        boundary = run_logged(HTTP_BOUNDARY_COMMAND, "cf01-http-boundary", 180, env)
        if not re.search(r"^" + HTTP_BOUNDARY_MARKER + r" tests=7 report=.+$", boundary, re.MULTILINE):
            raise RuntimeError("Authenticated CF01 HTTP proof did not provide its verified completion marker")
        report["httpBoundary"] = {"status": "passed", "tests": 7, "log": "cf01-http-boundary.log"}
        with ExitStack() as owned:
            relay = None
            for index, journey in enumerate(manifest["journeys"]):
                attempt = report["attempts"][index]
                attempt["status"] = "failed"
                if journey["path"] == RED_PATHS[0]:
                    relay = owned.enter_context(required_red_relay(env))
                if journey["path"] in RED_PATHS and (relay is None or relay.poll() is not None):
                    raise RuntimeError("Required RED process needs its owned live relay")
                if not journey["preserveAppData"]:
                    prepare_ci_journey(journey, device, env)
                else:
                    # A real new process, retaining the preceding journey's local data.
                    subprocess.run(["adb", "-s", device, "shell", "am", "force-stop", DEV_APP],
                                   timeout=15, check=True)
                started = time.monotonic()
                log = run_logged(flutter_command(journey, device), Path(journey["path"]).stem,
                                 journey["timeoutSeconds"], env)
                if "Uninstalling old version..." in log:
                    raise RuntimeError("Flutter replaced the installed app by uninstalling; data/permission continuity is unproven")
                if journey["successMarker"] not in log:
                    raise RuntimeError("Flutter exited without the journey's canonical-readback completion marker")
                if "dev_planned_work" in journey["path"] and "DEV_PLANNED_UI_PUBLISHED" not in log:
                    raise RuntimeError("Fresh CI planned work must publish through the UI during this run")
                report["journeys"].append({"path": journey["path"], "status": "passed",
                                           "seconds": round(time.monotonic() - started, 2)})
                attempt.update(status="passed", seconds=round(time.monotonic() - started, 2))
        report["status"] = "passed"
    finally:
        (OUTPUT / "result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        try:
            run_logged(["adb", "-s", device, "logcat", "-d", "-t", "2000"], "android-logcat", 20, env)
        except (RuntimeError, subprocess.SubprocessError):
            pass  # Diagnostics cannot turn a failed business journey into success.


def prepare_functions_parameters():
    # Only the dedicated demo Functions child opts in; production stays closed.
    if PROJECT != "demo-crm3-ci-journeys":
        raise RuntimeError("Inspection authoring opt-in is confined to the dedicated demo project")
    params = ROOT / f"functions/.env.{PROJECT}"
    expected = ("CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false\n"
                "CRM_INSPECTION_V2_AUTHORING_ENABLED=true\n")
    if params.exists() and params.read_text(encoding="utf-8") != expected:
        raise RuntimeError("Existing CI Functions parameters differ; refusing overwrite")
    params.write_text(expected, encoding="utf-8")


def main(argv=None):
    # Flutter's failure report includes Unicode. On Windows a legacy console
    # encoding must not hide the original assertion behind an encoding error.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device-id", default="emulator-5554")
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--inside-emulators", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    device = device_id(args.device_id)
    manifest = load_manifest()
    env = {**os.environ, "CRM3_DEV_APP": "true", "CRM_DEMO_PROJECT_ID": PROJECT,
           "CRM_FIRESTORE_EMULATOR": "127.0.0.1:18080"}
    if args.plan:
        require_red_sequence(manifest["journeys"])
        require_inner_cover_sequence(manifest["journeys"])
        print(json.dumps({"artifactKind": "CI demo candidate plan", "productionDistribution": False,
                          "requiredRedRelay": {"command": [sys.executable, RED_RELAY, "--evidence-dir", str(OUTPUT / "required-red-relay")],
                                               "paths": list(RED_PATHS), "port": 15002,
                                               "lifetime": "one owned child across adjacent prepare/resume; no reused evidence"},
                          "innerCoverSequence": {"paths": list(IC_PATHS),
                                                 "backendState": "fitness-created case retained for withdrawal; seed once",
                                                 "appData": "independent DEV sessions; no seeded case or disposition"},
                          "project": PROJECT, "config": manifest["firebaseConfig"],
                          "httpBoundary": {"command": HTTP_BOUNDARY_COMMAND,
                                           "after": "seed", "before": "Android journeys",
                                           "successMarker": HTTP_BOUNDARY_MARKER},
                          "preparations": [{"journey": row["path"],
                                            "steps": ["Verify ro.kernel.qemu=1 and isolated DEV build environment",
                                                      flutter_build_command(row, device),
                                                      f"Verify debug APK identity is exactly {DEV_APP} with SDK aapt",
                                                      f"Clear only {DEV_APP} data if already installed",
                                                      ["adb", "-s", device, "install", "-r", "-t", "build/app/outputs/flutter-apk/app-debug.apk"],
                                                      ["adb", "-s", device, "shell", "pm", "grant", DEV_APP, "android.permission.POST_NOTIFICATIONS"]]}
                                           for row in manifest["journeys"] if not row["preserveAppData"]],
                          "preservedRestart": "Force-stop only before the restart test; never clear, preinstall, or regrant",
                          "commands": [flutter_command(row, device) for row in manifest["journeys"]]}, indent=2))
        return 0
    require_isolated_environment(os.environ, inside=args.inside_emulators)
    require_fresh_output()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.inside_emulators:
        execute_journeys(device, manifest, env)
        return 0
    if not CLI.is_file() or not (ROOT / "functions/lib/index.js").is_file():
        raise RuntimeError("Install the pinned Firebase CLI and build Functions before running")
    for port in PORTS:
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", port)) == 0:
                raise RuntimeError(f"Dedicated CI port {port} is occupied; refusing to attach to another session")
    prepare_android_config()
    prepare_functions_parameters()
    child_args = [sys.executable, "tools/testing/run_ci_business_journeys.py",
                  "--inside-emulators", "--device-id", device]
    child = (subprocess.list2cmdline(child_args) if os.name == "nt"
             else shlex.join(child_args))
    command = ["node", str(CLI), "emulators:exec", "--config", manifest["firebaseConfig"],
               "--project", PROJECT, "--only", "auth,firestore,functions", "--non-interactive", child]
    return subprocess.run(command, cwd=ROOT, env=env, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
