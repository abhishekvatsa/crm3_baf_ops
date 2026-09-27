import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

import run_ci_business_journeys as runner
import seed_ci_business_journeys as seed


class BusinessJourneyGateTest(unittest.TestCase):
    @staticmethod
    def _adb_output(command, **kwargs):
        if command[-2:] == ["getprop", "ro.kernel.qemu"]:
            return "1\n"
        if command[-3:] == ["pm", "path", runner.DEV_APP]:
            # Real Android reports an absent package as empty exit 1.
            raise subprocess.CalledProcessError(1, command, output="", stderr="")
        if command[-3:] == ["pm", "clear", runner.DEV_APP]:
            return "Success\n"
        raise AssertionError("Unexpected ADB operation")

    def test_fresh_absent_dev_package_does_not_attempt_clear(self):
        for returncode in (0, 1):
            result = subprocess.CompletedProcess([], returncode, stdout="", stderr="")
            with self.subTest(returncode=returncode), \
                    patch.object(runner.subprocess, "check_output", side_effect=self._adb_output) as output, \
                    patch.object(runner.subprocess, "run", return_value=result) as probe:
                runner.clear_ci_app("emulator-5554")
                self.assertEqual(output.call_count, 1)
                probe.assert_called_once_with(
                    ["adb", "-s", "emulator-5554", "shell", "pm", "path", runner.DEV_APP],
                    capture_output=True, text=True, timeout=15, check=False)

    def test_installed_dev_package_clears_only_verified_emulator_dev_app(self):
        result = subprocess.CompletedProcess([], 0, stdout="package:/data/app/dev/base.apk\n", stderr="")
        with patch.object(runner.subprocess, "check_output", side_effect=self._adb_output) as output, \
                patch.object(runner.subprocess, "run", return_value=result):
            runner.clear_ci_app("emulator-5554")
            self.assertEqual(output.call_count, 2)
            self.assertEqual(output.call_args.args[0],
                             ["adb", "-s", "emulator-5554", "shell", "pm", "clear", runner.DEV_APP])

    def test_package_probe_transport_and_unexpected_responses_fail_closed(self):
        for code, stdout, stderr in (
                (1, "", "error: device offline"), (2, "", ""),
                (1, "error: package manager unavailable", ""),
                (0, "unexpected output", ""), (0, "package:", "")):
            result = subprocess.CompletedProcess([], code, stdout=stdout, stderr=stderr)
            with self.subTest(code=code, stdout=stdout, stderr=stderr), \
                    patch.object(runner.subprocess, "check_output", side_effect=self._adb_output) as output, \
                    patch.object(runner.subprocess, "run", return_value=result), \
                    self.assertRaises(RuntimeError):
                runner.clear_ci_app("emulator-5554")
            self.assertEqual(output.call_count, 1)

    def test_package_probe_requires_emulator_before_read_or_clear(self):
        with patch.object(runner.subprocess, "check_output", return_value="0\n"), \
                patch.object(runner.subprocess, "run") as probe, self.assertRaises(RuntimeError):
            runner.clear_ci_app("emulator-5554")
        probe.assert_not_called()

    def test_all_device_probes_have_explicit_scope(self):
        manifest = runner.load_manifest()
        declared = [row["path"] for row in manifest["journeys"] + manifest["excluded"]]
        actual = {path.relative_to(runner.ROOT).as_posix()
                  for path in (runner.ROOT / "integration_test").glob("dev_*_test.dart")}
        self.assertEqual(set(declared), actual)
        self.assertEqual(len(declared), len(set(declared)))
        self.assertTrue(all(row["reason"] for row in manifest["excluded"]))

    def test_refuses_real_device_cloud_credentials_and_wrong_emulator_namespace(self):
        for device in ("physical-device-test", "all", "emulator-5554;echo unsafe"):
            with self.subTest(device=device), self.assertRaises(ValueError):
                runner.device_id(device)
        for env in ({"GOOGLE_APPLICATION_CREDENTIALS": "real.json"},
                    {"FIREBASE_TOKEN": "secret"}, {"CRM_DEMO_PROJECT_ID": "demo-crm3-baf-ops"},
                    {"CRM_DEMO_PROJECT_ID": "production"}):
            with self.subTest(env=list(env)), self.assertRaises(ValueError):
                runner.require_isolated_environment(env, inside=False)
        with self.assertRaises(ValueError):
            runner.require_isolated_environment({"FIRESTORE_EMULATOR_HOST": "127.0.0.1:8080"}, inside=True)
        runner.require_isolated_environment({"FIRESTORE_EMULATOR_HOST": "127.0.0.1:18080",
                                              "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:19099"}, inside=True)

    def test_each_real_flutter_command_has_paired_demo_identity_and_explicit_local_ports(self):
        for row in runner.load_manifest()["journeys"]:
            command = runner.flutter_command(row, "emulator-5554")
            self.assertEqual(command[:3], ["flutter", "test", row["path"]])
            self.assertIn("--dart-define=CRM_USE_EMULATORS=true", command)
            self.assertIn("--dart-define=CRM_DEMO_PROJECT_ID=demo-crm3-ci-journeys", command)
            self.assertIn("--dart-define=CRM_EMULATOR_HOST=10.0.2.2", command)
            self.assertIn("--no-uninstall", command)
            self.assertNotIn("--release", command)

    def test_seed_transport_refuses_production_shared_demo_redirects_and_deletion(self):
        for method, url, data in (
                ("PATCH", "https://firestore.googleapis.com/v1/projects/demo-crm3-ci-journeys", {}),
                ("PATCH", seed.FS.replace(seed.PROJECT, "demo-crm3-baf-ops") + "/x/y", {}),
                ("DELETE", seed.FS + "/x/y", None),
                ("POST", seed.AUTH + "/accounts:signUp?key=emulator", {"targetProjectId": "live"}),
                ("GET", seed.FS + "/x/y#fragment", None)):
            with self.subTest(url=url), self.assertRaises(ValueError):
                seed.validate_request(method, url, data)
        with self.assertRaises(RuntimeError):
            seed.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.com")

    def test_cached_credentials_are_refused_without_reading_their_contents(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / ".config/gcloud/application_default_credentials.json"
            path.parent.mkdir(parents=True)
            path.write_text("must not be parsed", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "cached cloud credentials"):
                runner.require_isolated_environment({"HOME": folder}, inside=False)

    def test_fixtures_are_create_only_and_draft_writes_use_actual_si_credentials(self):
        with patch.object(seed, "request") as request:
            seed.create("abnormality_types/test", {"code": {"stringValue": "TEST"}})
            self.assertTrue(request.call_args.args[1].endswith("?currentDocument.exists=false"))
            transport = seed.DraftTransport({"token": "signed-in-si"})
            with self.assertRaises(ValueError):
                transport.http("PATCH", seed.FS + "/template_versions/v", {}, "owner")
            transport.http("PATCH", seed.FS + "/template_versions/v", {}, "signed-in-si")
            self.assertEqual(request.call_args.args[-1], "signed-in-si")

    def test_existing_ci_evidence_is_never_reset_or_overwritten(self):
        with patch.object(seed, "read", return_value={"startedAt": "earlier"}), \
                patch.object(seed, "create") as create, self.assertRaises(RuntimeError):
            seed.main()
        create.assert_not_called()

    def test_native_config_uses_only_ci_dev_identity_and_never_overwrites_existing_config(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / "android/app/src/debug/google-services.json"
            runner.prepare_android_config(root)
            original = target.read_bytes()
            config = json.loads(original)
            self.assertEqual(config["project_info"]["project_id"], runner.PROJECT)
            self.assertEqual([row["client_info"]["android_client_info"]["package_name"]
                              for row in config["client"]], [runner.DEV_APP])
            runner.prepare_android_config(root)
            self.assertEqual(target.read_bytes(), original)
            target.write_text('{"project_info":{"project_id":"demo-crm3-baf-ops"}}', encoding="utf-8")
            different = target.read_bytes()
            with self.assertRaisesRegex(RuntimeError, "refusing overwrite"):
                runner.prepare_android_config(root)
            self.assertEqual(target.read_bytes(), different)

    def test_full_orchestration_preserves_data_only_for_separate_process_recovery(self):
        manifest = runner.load_manifest()
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            if command[0] == "flutter":
                self.assertIn("--no-uninstall", command)
            return "DEV_JOURNEY_PASS DEV_RESTART_PASS DEV_PLANNED_UI_PUBLISHED DEV_PLANNED_WORK_PASS"
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "clear_ci_app", side_effect=lambda _: events.append("clear-dev")) as clear, \
                patch.object(runner.subprocess, "run", side_effect=lambda *args, **kwargs: events.append("force-stop-dev")) as command:
            runner.execute_journeys("emulator-5554", manifest, {})
            self.assertEqual(clear.call_count, 2)
            command.assert_called_once_with(["adb", "-s", "emulator-5554", "shell", "am",
                                             "force-stop", runner.DEV_APP], timeout=15, check=True)
            report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "passed")
            self.assertEqual(len(report["journeys"]), 3)
            self.assertEqual(events, [
                "seed", "clear-dev", "dev_abnormality_journey_test",
                "force-stop-dev", "dev_restart_recovery_test",
                "clear-dev", "dev_planned_work_journey_test", "android-logcat",
            ])

    def test_zero_exit_without_canonical_acceptance_marker_fails_and_stops_later_journeys(self):
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            return "Flutter exited, but no canonical acceptance was observed"
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "clear_ci_app"), self.assertRaises(RuntimeError):
            runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
        self.assertNotIn("dev_planned_work_journey_test", events)

    def test_fresh_planned_gate_cannot_pass_by_reusing_a_pre_published_fixture(self):
        manifest = {"journeys": [runner.load_manifest()["journeys"][-1]]}
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", return_value="DEV_PLANNED_WORK_PASS"), \
                patch.object(runner, "clear_ci_app"), self.assertRaisesRegex(RuntimeError, "publish through"):
            runner.execute_journeys("emulator-5554", manifest, {})


if __name__ == "__main__":
    unittest.main()
