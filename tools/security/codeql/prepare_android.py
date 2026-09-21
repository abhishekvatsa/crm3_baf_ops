"""Prepare a disposable CI debug build without production signing or Firebase."""

import json
import os
from pathlib import Path
import shutil


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("This preparation is restricted to disposable GitHub runners.")
    if os.environ.get("CRM3_CI_PACKAGE_PROOF") != "true":
        raise SystemExit("Isolated CI configuration is required.")
    root = Path(__file__).resolve().parents[3]
    flutter_command = shutil.which("flutter")
    if not flutter_command:
        raise SystemExit("Flutter is not installed.")
    flutter = Path(flutter_command).resolve().parent.parent
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    if not sdk.is_dir() or not (flutter / "packages/flutter_tools").is_dir():
        raise SystemExit("Android or Flutter SDK is unavailable.")
    # flutter pub get may already have generated this ephemeral file.
    (root / "android/local.properties").write_text(
        f"sdk.dir={sdk.as_posix()}\nflutter.sdk={flutter.as_posix()}\n",
        encoding="utf-8",
    )
    target = root / "android/app/src/debug/google-services.json"
    if target.exists():
        raise SystemExit("Refusing to replace an existing debug Firebase override.")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({
        "project_info": {
            "project_number": "999999999999",
            "project_id": "crm3-ci-package-proof-isolated",
            "storage_bucket": "crm3-ci-package-proof-isolated.invalid",
        },
        "client": [{
            "client_info": {
                "mobilesdk_app_id": "1:999999999999:android:0000000000000000000000",
                "android_client_info": {"package_name": "in.co.sail.bsl.crm3.bafops"},
            },
            "oauth_client": [],
            "api_key": [{"current_key": "crm3-ci-package-proof-no-api-access"}],
            "services": {"appinvite_service": {"other_platform_oauth_client": []}},
        }],
        "configuration_version": "1",
    }, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
