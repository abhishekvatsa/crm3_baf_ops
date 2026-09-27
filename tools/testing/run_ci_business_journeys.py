"""Run the declared Android business journeys against isolated local Firebase.

Use --plan for mutation-free orchestration inspection. Normal execution requires
an Android emulator (never a physical device), refuses ambient cloud credentials,
and starts/stops only its dedicated Firebase processes through emulators:exec.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "governance/ci-business-journeys.json"
PROJECT = "demo-crm3-ci-journeys"
DEV_APP = "in.co.sail.bsl.crm3.bafops.dev"
PORTS = (19099, 18080, 15001, 14400, 14500, 19150, 19299, 19499)
OUTPUT = ROOT / "output/ci-business-journeys"
CLI = ROOT / "tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js"


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
            "--no-pub", "--reporter", "expanded",
            "--dart-define=CRM_USE_EMULATORS=true",
            "--dart-define=CRM_EMULATOR_HOST=10.0.2.2",
            f"--dart-define=CRM_DEMO_PROJECT_ID={PROJECT}",
            "--dart-define=CRM_FIRESTORE_EMULATOR_PORT=18080",
            "--dart-define=CRM_AUTH_EMULATOR_PORT=19099",
            "--dart-define=CRM_FUNCTIONS_EMULATOR_PORT=15001",
            f"--dart-define=CRM_DEV_EMAIL={journey['actorEmail']}",
            f"--dart-define=CRM_DEV_DISPLAY_NAME={journey['actorName']}",
            "--dart-define=CRM_DEV_SECRET=emulator-local-only"]


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
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
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


def clear_ci_app(device):
    # Data clearing is allowed only on the disposable AVD and only for DEV.
    qemu = subprocess.check_output(["adb", "-s", device_id(device), "shell", "getprop",
                                    "ro.kernel.qemu"], text=True, timeout=15).strip()
    if qemu != "1":
        raise RuntimeError("Selected device is not an Android emulator")
    installed = subprocess.check_output(["adb", "-s", device, "shell", "pm", "path", DEV_APP],
                                        text=True, timeout=15).strip()
    if installed:
        result = subprocess.check_output(["adb", "-s", device, "shell", "pm", "clear", DEV_APP],
                                         text=True, timeout=15).strip()
        if result != "Success":
            raise RuntimeError("Could not initialize the disposable DEV application")


def execute_journeys(device, manifest, env):
    report = {"project": PROJECT, "physicalDeviceEvidence": False,
              "productionBackendUsed": False, "journeys": [], "status": "failed"}
    try:
        run_logged([sys.executable, "tools/testing/seed_ci_business_journeys.py"], "seed", 180, env)
        for journey in manifest["journeys"]:
            if not journey["preserveAppData"]:
                clear_ci_app(device)
            else:
                # A real new process, retaining the preceding journey's local data.
                subprocess.run(["adb", "-s", device, "shell", "am", "force-stop", DEV_APP],
                               timeout=15, check=True)
            started = time.monotonic()
            log = run_logged(flutter_command(journey, device), Path(journey["path"]).stem,
                             journey["timeoutSeconds"], env)
            if journey["successMarker"] not in log:
                raise RuntimeError("Flutter exited without the journey's canonical-readback completion marker")
            if "dev_planned_work" in journey["path"] and "DEV_PLANNED_UI_PUBLISHED" not in log:
                raise RuntimeError("Fresh CI planned work must publish through the UI during this run")
            report["journeys"].append({"path": journey["path"], "status": "passed",
                                       "seconds": round(time.monotonic() - started, 2)})
        report["status"] = "passed"
    finally:
        (OUTPUT / "result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        try:
            run_logged(["adb", "-s", device, "logcat", "-d", "-t", "2000"], "android-logcat", 20, env)
        except (RuntimeError, subprocess.SubprocessError):
            pass  # Diagnostics cannot turn a failed business journey into success.


def main(argv=None):
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
        print(json.dumps({"project": PROJECT, "config": manifest["firebaseConfig"],
                          "commands": [flutter_command(row, device) for row in manifest["journeys"]]}, indent=2))
        return 0
    require_isolated_environment(os.environ, inside=args.inside_emulators)
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
    params = ROOT / f"functions/.env.{PROJECT}"
    expected = "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false\n"
    if params.exists() and params.read_text(encoding="utf-8") != expected:
        raise RuntimeError("Existing CI Functions parameters differ; refusing overwrite")
    params.write_text(expected, encoding="utf-8")
    child = shlex.join([sys.executable, "tools/testing/run_ci_business_journeys.py",
                        "--inside-emulators", "--device-id", device])
    command = ["node", str(CLI), "emulators:exec", "--config", manifest["firebaseConfig"],
               "--project", PROJECT, "--only", "auth,firestore,functions", "--non-interactive", child]
    return subprocess.run(command, cwd=ROOT, env=env, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
