import json
import io
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import MagicMock, patch
from contextlib import contextmanager

import run_ci_business_journeys as runner
import seed_ci_business_journeys as seed

HTTP_PROOF = "CF01_HTTP_BOUNDARY_PASS tests=7 report=.dart_tool/cf01-emulator-run/test-report.json\n"


class BusinessJourneyGateTest(unittest.TestCase):
    def test_notification_setup_builds_matching_dev_source_before_install_and_grant(self):
        journey = runner.load_manifest()["journeys"][0]
        events = []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            apk = root / "build/app/outputs/flutter-apk/app-debug.apk"
            apk.parent.mkdir(parents=True)
            apk.write_bytes(b"fixture-apk")
            aapt = root / "sdk/build-tools/36.0.0/aapt"
            aapt.parent.mkdir(parents=True)
            aapt.write_bytes(b"fixture-tool")

            def output(command, **kwargs):
                events.append(command)
                if command[-2:] == ["getprop", "ro.kernel.qemu"]:
                    return "1\n"
                if command[1:3] == ["dump", "badging"]:
                    return f"package: name='{runner.DEV_APP}' versionCode='1'\napplication-debuggable\n"
                if "install" in command:
                    return "Performing Streamed Install\nSuccess\n"
                if "grant" in command:
                    return ""
                raise AssertionError(command)

            with patch.object(runner, "ROOT", root), \
                    patch.object(runner, "run_logged", side_effect=lambda command, *args: events.append(command)), \
                    patch.object(runner, "clear_ci_app", side_effect=lambda _: events.append("clear-dev")), \
                    patch.object(runner.subprocess, "check_output", side_effect=output):
                runner.prepare_ci_journey(journey, "emulator-5554", {
                    "ANDROID_HOME": str(root / "sdk"), "CRM3_DEV_APP": "true",
                    "CRM_DEMO_PROJECT_ID": runner.PROJECT,
                })
            self.assertEqual(events[0][-2:], ["getprop", "ro.kernel.qemu"])
            build = events[1]
            self.assertEqual(build[:3], ["flutter", "build", "apk"])
            self.assertIn("--debug", build)
            self.assertEqual(build[build.index("--target") + 1], journey["path"])
            self.assertIn("--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false", build)
            self.assertEqual([v for v in build if v.startswith("--dart-define=CRM_")],
                             [v for v in runner.flutter_command(journey, "emulator-5554") if v.startswith("--dart-define=")])
            self.assertEqual(events[2][1:3], ["dump", "badging"])
            self.assertEqual(events[3], "clear-dev")
            self.assertEqual(events[4], ["adb", "-s", "emulator-5554", "install", "-r", "-t", str(apk)])
            self.assertEqual(events[5], ["adb", "-s", "emulator-5554", "shell", "pm", "grant",
                                         runner.DEV_APP, "android.permission.POST_NOTIFICATIONS"])

    def test_notification_setup_refuses_physical_device_before_build(self):
        with patch.object(runner.subprocess, "check_output", return_value="0\n"), \
                patch.object(runner, "run_logged") as build, self.assertRaises(RuntimeError):
            runner.prepare_ci_journey(runner.load_manifest()["journeys"][0], "emulator-5554", {})
        build.assert_not_called()

    def test_notification_setup_refuses_unverified_build_environment(self):
        for env in ({}, {"CRM3_DEV_APP": "false", "CRM_DEMO_PROJECT_ID": runner.PROJECT},
                    {"CRM3_DEV_APP": "true", "CRM_DEMO_PROJECT_ID": "production"}):
            with self.subTest(env=env), patch.object(runner.subprocess, "check_output", return_value="1\n"), \
                    patch.object(runner, "run_logged") as build, self.assertRaises(RuntimeError):
                runner.prepare_ci_journey(runner.load_manifest()["journeys"][0], "emulator-5554", env)
            build.assert_not_called()

    def test_notification_setup_identity_install_and_grant_fail_closed(self):
        journey = runner.load_manifest()["journeys"][0]
        valid_badging = f"package: name='{runner.DEV_APP}' versionCode='1'\napplication-debuggable\n"
        for badging, installed, granted, failing_stage in (
                (valid_badging.replace(runner.DEV_APP, "in.co.sail.bsl.crm3.bafops"), "Success", "", "identity"),
                (valid_badging.replace("application-debuggable", ""), "Success", "", "identity"),
                (valid_badging * 2, "Success", "", "identity"),
                (valid_badging, "Failure [INSTALL_FAILED]", "", "install"),
                (valid_badging, subprocess.CalledProcessError(1, ["adb", "install"]), "", "install"),
                (valid_badging, "Success", "Error: permission grant failed", "grant"),
                (valid_badging, "Success", subprocess.CalledProcessError(1, ["adb", "pm", "grant"]), "grant")):
            with self.subTest(stage=failing_stage, badging=badging), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                apk = root / "build/app/outputs/flutter-apk/app-debug.apk"
                apk.parent.mkdir(parents=True)
                apk.write_bytes(b"fixture-apk")
                aapt = root / "sdk/build-tools/36.0.0/aapt"
                aapt.parent.mkdir(parents=True)
                aapt.write_bytes(b"fixture-tool")
                commands = []

                def output(command, **kwargs):
                    commands.append(command)
                    if command[-2:] == ["getprop", "ro.kernel.qemu"]:
                        return "1\n"
                    if command[1:3] == ["dump", "badging"]:
                        return badging
                    if "install" in command:
                        if isinstance(installed, Exception):
                            raise installed
                        return installed
                    if "grant" in command:
                        if isinstance(granted, Exception):
                            raise granted
                        return granted
                    raise AssertionError(command)

                with patch.object(runner, "ROOT", root), patch.object(runner, "run_logged"), \
                        patch.object(runner, "clear_ci_app") as clear, \
                        patch.object(runner.subprocess, "check_output", side_effect=output), \
                        self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                    runner.prepare_ci_journey(journey, "emulator-5554", {
                        "ANDROID_HOME": str(root / "sdk"), "CRM3_DEV_APP": "true",
                        "CRM_DEMO_PROJECT_ID": runner.PROJECT,
                    })
                if failing_stage == "identity":
                    clear.assert_not_called()
                    self.assertFalse(any("install" in command for command in commands))
                if failing_stage != "grant":
                    self.assertFalse(any("grant" in command for command in commands))

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
        # Keep the original seven-journey sequence asserted verbatim.
        manifest["journeys"] = manifest["journeys"][:7]
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            if name == "cf01-http-boundary":
                self.assertEqual(command, ["node", "functions/tools/run_retained_queue_emulator_tests.mjs", "--existing-ci"])
                self.assertEqual(timeout, 180)
            if command[0] == "flutter":
                self.assertIn("--no-uninstall", command)
            return HTTP_PROOF + "DEV_JOURNEY_PASS DEV_RESTART_PASS DEV_PLANNED_UI_PUBLISHED DEV_PLANNED_WORK_PASS DEV_ISSUE_QUALITY_PASS DEV_BURNER_PLANT_PASS DEV_QUEUE_OWNERSHIP_PREPARED DEV_QUEUE_OWNERSHIP_PASS"
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "prepare_ci_journey", side_effect=lambda row, *args: events.append(Path(row["path"]).stem + "-prepare")) as prepare, \
                patch.object(runner.subprocess, "run", side_effect=lambda *args, **kwargs: events.append("force-stop-dev")) as command:
            runner.execute_journeys("emulator-5554", manifest, {})
            self.assertEqual(prepare.call_count, 5)
            self.assertEqual(command.call_count, 2)
            for invocation in command.call_args_list:
                self.assertEqual(invocation.args[0], ["adb", "-s", "emulator-5554", "shell", "am", "force-stop", runner.DEV_APP])
                self.assertEqual(invocation.kwargs, {"timeout": 15, "check": True})
            report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["httpBoundary"], {"status": "passed", "tests": 7, "log": "cf01-http-boundary.log"})
            self.assertEqual(len(report["journeys"]), 7)
            self.assertEqual(events, [
                "seed", "cf01-http-boundary", "dev_abnormality_journey_test-prepare", "dev_abnormality_journey_test",
                "force-stop-dev", "dev_restart_recovery_test",
                "dev_planned_work_journey_test-prepare", "dev_planned_work_journey_test",
                "dev_issue_quality_journey_test-prepare", "dev_issue_quality_journey_test",
                "dev_burner_plant_journey_test-prepare", "dev_burner_plant_journey_test",
                "dev_queue_ownership_journey_test-prepare", "dev_queue_ownership_journey_test",
                "force-stop-dev", "dev_queue_ownership_resume_journey_test", "android-logcat",
            ])

    def test_zero_exit_without_canonical_acceptance_marker_fails_and_stops_later_journeys(self):
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            return HTTP_PROOF if name == "cf01-http-boundary" else "Flutter exited, but no canonical acceptance was observed"
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "prepare_ci_journey"), self.assertRaises(RuntimeError):
            runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
        self.assertNotIn("dev_planned_work_journey_test", events)

    def test_inspection_journey_requires_its_own_real_readback_marker(self):
        rows = runner.load_manifest()["journeys"]
        row = rows[-1]
        self.assertEqual(row["path"], "integration_test/dev_inspection_readings_journey_test.dart")
        self.assertEqual(row["actorEmail"], "dev.cf01-b@example.invalid")
        self.assertFalse(row["preserveAppData"])
        self.assertEqual(row["successMarker"], "DEV_INSPECTION_READINGS_PASS")
        for marker in ("DEV_WITHDRAWN_PASS", row["successMarker"]):
            with self.subTest(marker=marker), tempfile.TemporaryDirectory() as folder, \
                    patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "run_logged", return_value=HTTP_PROOF + marker), \
                    patch.object(runner, "prepare_ci_journey"):
                if marker != row["successMarker"]:
                    with self.assertRaisesRegex(RuntimeError, "completion marker"):
                        runner.execute_journeys("emulator-5554", {"journeys": [row]}, {})
                else:
                    runner.execute_journeys("emulator-5554", {"journeys": [row]}, {})
                result = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
                self.assertEqual(result["status"], "passed" if marker == row["successMarker"] else "failed")

    def test_fresh_planned_gate_cannot_pass_by_reusing_a_pre_published_fixture(self):
        manifest = {"journeys": [next(row for row in runner.load_manifest()["journeys"]
            if row["successMarker"] == "DEV_PLANNED_WORK_PASS")]}
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", return_value=HTTP_PROOF + "DEV_PLANNED_WORK_PASS"), \
                patch.object(runner, "prepare_ci_journey"), self.assertRaisesRegex(RuntimeError, "publish through"):
            runner.execute_journeys("emulator-5554", manifest, {})

    def test_flutter_fallback_uninstall_refuses_false_restart_acceptance(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", return_value=HTTP_PROOF + "Uninstalling old version... DEV_JOURNEY_PASS"), \
                patch.object(runner, "prepare_ci_journey"), self.assertRaisesRegex(RuntimeError, "continuity"):
            runner.execute_journeys("emulator-5554", runner.load_manifest(), {})

    def test_plan_describes_all_permission_bootstraps_without_mutation(self):
        output = io.StringIO()
        with patch("sys.stdout", output), patch.object(runner, "run_logged") as run, \
                patch.object(runner.subprocess, "run") as adb, \
                patch.object(runner.subprocess, "check_output") as probe:
            self.assertEqual(runner.main(["--plan"]), 0)
        run.assert_not_called()
        adb.assert_not_called()
        probe.assert_not_called()
        plan = json.loads(output.getvalue())
        self.assertEqual(plan["httpBoundary"], {
            "command": ["node", "functions/tools/run_retained_queue_emulator_tests.mjs", "--existing-ci"],
            "after": "seed", "before": "Android journeys", "successMarker": "CF01_HTTP_BOUNDARY_PASS",
        })
        self.assertEqual([row["journey"] for row in plan["preparations"]],
                         [row["path"] for row in runner.load_manifest()["journeys"] if not row["preserveAppData"]])
        for row in plan["preparations"]:
            self.assertEqual(row["steps"][-1][-2:], [runner.DEV_APP, "android.permission.POST_NOTIFICATIONS"])
        self.assertEqual(len(plan["commands"]), 12)
        self.assertEqual(plan["requiredRedRelay"]["port"], 15002)
        self.assertFalse(plan["productionDistribution"])

    def test_each_queue_ownership_process_requires_its_own_completion_marker(self):
        journeys = [row for row in runner.load_manifest()["journeys"]
                    if "dev_queue_ownership" in row["path"]]
        self.assertEqual([row["successMarker"] for row in journeys],
                         ["DEV_QUEUE_OWNERSHIP_PREPARED", "DEV_QUEUE_OWNERSHIP_PASS"])
        self.assertEqual([row["preserveAppData"] for row in journeys], [False, True])
        self.assertEqual(journeys[1]["actorEmail"], "dev.cf01-b@example.invalid")
        self.assertEqual(journeys[1]["actorName"], "DEV CF01 Admin B")
        self.assertEqual(journeys[1]["timeoutSeconds"], 600)
        for missing in (0, 1):
            events = []
            def logged(command, name, timeout, env):
                events.append(name)
                for index, row in enumerate(journeys):
                    if name == Path(row["path"]).stem:
                        # The other process's marker cannot substitute for this one.
                        return journeys[1-index]["successMarker"] if index == missing else row["successMarker"]
                return HTTP_PROOF
            with self.subTest(missing=journeys[missing]["successMarker"]), \
                    tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "run_logged", side_effect=logged), \
                    patch.object(runner, "prepare_ci_journey"), \
                    patch.object(runner.subprocess, "run") as restart:
                with self.assertRaisesRegex(RuntimeError, "completion marker"):
                    runner.execute_journeys("emulator-5554", {"journeys": journeys}, {})
                report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "failed")
            self.assertEqual(len(report["journeys"]), missing)
            self.assertEqual(restart.call_count, missing)
            if missing == 0:
                self.assertNotIn("dev_queue_ownership_resume_journey_test", events)

    def test_queue_ownership_actors_are_two_distinct_synthetic_admin_accounts(self):
        accounts = [row for row in seed.ACTORS if row[1].startswith("dev.cf01-")]
        self.assertEqual([row[0] for row in accounts], ["admin", "admin"])
        self.assertEqual({row[1] for row in accounts},
                         {"dev.cf01-a@example.invalid", "dev.cf01-b@example.invalid"})

    def test_http_failure_stops_before_any_android_preparation_or_journey(self):
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            if name == "cf01-http-boundary":
                raise RuntimeError("Authenticated HTTP suite exited 1")
            return ""
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "prepare_ci_journey") as prepare, \
                patch.object(runner.subprocess, "run") as adb:
            with self.assertRaisesRegex(RuntimeError, "HTTP suite exited 1"):
                runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
            report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
        self.assertEqual(events, ["seed", "cf01-http-boundary", "android-logcat"])
        prepare.assert_not_called()
        adb.assert_not_called()
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["httpBoundary"]["status"], "failed")
        self.assertEqual(report["journeys"], [])

    def test_http_zero_exit_missing_or_incomplete_proof_never_admits_android(self):
        for log in ("", "Tests: 7 passed", "CF01_HTTP_BOUNDARY_PASS",
                    "CF01_HTTP_BOUNDARY_PASS tests=6 report=result.json",
                    "unexpected embedded CF01_HTTP_BOUNDARY_PASS tests=7 report=result.json"):
            with self.subTest(log=log), tempfile.TemporaryDirectory() as folder, \
                    patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "run_logged", return_value=log), \
                    patch.object(runner, "prepare_ci_journey") as prepare, \
                    patch.object(runner.subprocess, "run") as adb:
                with self.assertRaisesRegex(RuntimeError, "verified completion marker"):
                    runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
                report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
            prepare.assert_not_called()
            adb.assert_not_called()
            self.assertEqual(report["httpBoundary"]["status"], "failed")
            self.assertEqual(report["journeys"], [])

    def test_seed_failure_never_runs_http_proof_or_android(self):
        events = []
        def logged(command, name, timeout, env):
            events.append(name)
            if name == "seed":
                raise RuntimeError("Seed rejected existing evidence")
            return ""
        with tempfile.TemporaryDirectory() as folder, patch.object(runner, "OUTPUT", Path(folder)), \
                patch.object(runner, "run_logged", side_effect=logged), \
                patch.object(runner, "prepare_ci_journey") as prepare:
            with self.assertRaisesRegex(RuntimeError, "Seed rejected"):
                runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
            report = json.loads((Path(folder) / "result.json").read_text(encoding="utf-8"))
        prepare.assert_not_called()
        self.assertEqual(events, ["seed", "android-logcat"])
        self.assertEqual(report["httpBoundary"]["status"], "notRun")


    def test_required_red_pair_routes_only_its_functions_calls_via_loss_relay(self):
        rows = runner.load_manifest()["journeys"]
        red = [row for row in rows if row["path"] in runner.RED_PATHS]
        self.assertEqual([row["path"] for row in red], list(runner.RED_PATHS))
        self.assertEqual([row["preserveAppData"] for row in red], [False, True])
        self.assertEqual([row["timeoutSeconds"] for row in red], [1200, 900])
        for row in rows:
            port = 15002 if row in red else 15001
            self.assertIn(f"--dart-define=CRM_FUNCTIONS_EMULATOR_PORT={port}",
                          runner.flutter_command(row, "emulator-5554"))
        for invalid in ([red[1]], list(reversed(red)), [red[0], rows[0], red[1]],
                        [dict(red[0], preserveAppData=True), red[1]],
                        [red[0], dict(red[1], successMarker="DEV_REQUIRED_RED_PREPARED")]):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                runner.require_red_sequence(invalid)

    def test_red_relay_spans_both_processes_and_failure_keeps_later_untested(self):
        rows = [row for row in runner.load_manifest()["journeys"] if row["path"] in runner.RED_PATHS]
        for fail_at in (None, 0, 1):
            events = []
            @contextmanager
            def relay(env):
                events.append("relay-start")
                try:
                    yield MagicMock(poll=lambda: None)
                finally:
                    events.append("relay-stop")
            def logged(command, name, timeout, env):
                events.append(name)
                if name == "cf01-http-boundary":
                    return HTTP_PROOF
                for index, row in enumerate(rows):
                    if name == Path(row["path"]).stem:
                        return "missing marker" if fail_at == index else row["successMarker"]
                return ""
            with self.subTest(fail_at=fail_at), tempfile.TemporaryDirectory() as folder, \
                    patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "required_red_relay", side_effect=relay), \
                    patch.object(runner, "prepare_ci_journey") as prepare, \
                    patch.object(runner, "run_logged", side_effect=logged), \
                    patch.object(runner.subprocess, "run") as restart:
                if fail_at is None:
                    runner.execute_journeys("emulator-5554", {"journeys": rows}, {})
                else:
                    with self.assertRaisesRegex(RuntimeError, "completion marker"):
                        runner.execute_journeys("emulator-5554", {"journeys": rows}, {})
                report = json.loads((Path(folder)/"result.json").read_text(encoding="utf-8"))
            self.assertEqual(events.count("relay-start"), 1)
            self.assertEqual(events.count("relay-stop"), 1)
            self.assertEqual(prepare.call_count, 1)
            self.assertEqual(restart.call_count, 0 if fail_at == 0 else 1)
            self.assertEqual([row["status"] for row in report["attempts"]],
                             ["passed", "passed"] if fail_at is None else
                             (["failed", "untested"] if fail_at == 0 else ["passed", "failed"]))
            self.assertFalse(report["productionDistribution"])
            self.assertLess(events.index("relay-start"), events.index(Path(rows[0]["path"]).stem))
            self.assertLess(events.index("relay-stop"), events.index("android-logcat"))

    def test_relay_child_ready_identity_and_owned_cleanup(self):
        isolated = {"FIRESTORE_EMULATOR_HOST":"127.0.0.1:18080", "FIREBASE_AUTH_EMULATOR_HOST":"127.0.0.1:19099"}
        for wrong_identity in (False, True):
            with self.subTest(wrong_identity=wrong_identity), tempfile.TemporaryDirectory() as folder:
                child = MagicMock()
                child.poll.return_value = None
                def start(command, **kwargs):
                    self.assertEqual(command[:2], [runner.sys.executable, runner.RED_RELAY])
                    self.assertEqual(command[2:], ["--evidence-dir", str(Path(folder)/"required-red-relay")])
                    ready = {"listen":["127.0.0.1",15002], "upstream":["127.0.0.1",15001],
                             "project":"production" if wrong_identity else runner.PROJECT,
                             "businessResponsesFabricated":False}
                    kwargs["stdout"].write("REQUIRED_RED_RELAY_READY "+json.dumps(ready)+"\n")
                    kwargs["stdout"].flush()
                    return child
                with patch.object(runner,"OUTPUT",Path(folder)), \
                        patch.object(runner.socket,"socket") as socket, \
                        patch.object(runner.subprocess,"Popen",side_effect=start):
                    socket.return_value.__enter__.return_value.connect_ex.return_value = 1
                    if wrong_identity:
                        with self.assertRaisesRegex(RuntimeError,"readiness identity"):
                            with runner.required_red_relay(isolated):
                                self.fail("wrong relay must not be yielded")
                    else:
                        with self.assertRaisesRegex(RuntimeError,"journey failed"):
                            with runner.required_red_relay(isolated) as yielded:
                                self.assertIs(yielded,child)
                                raise RuntimeError("journey failed")
                    child.terminate.assert_called_once()
                    child.wait.assert_called_once_with(timeout=10)
                    child.kill.assert_not_called()
                    with self.assertRaisesRegex(RuntimeError,"already exists"):
                        with runner.required_red_relay(isolated):
                            self.fail("relay log/evidence cannot be reused")



    def test_inner_cover_pair_requires_actual_fitness_before_withdrawal(self):
        rows = runner.load_manifest()["journeys"]
        ic = [row for row in rows if row["path"] in runner.IC_PATHS]
        self.assertEqual([row["path"] for row in ic], list(runner.IC_PATHS))
        self.assertEqual([row["preserveAppData"] for row in ic], [False, False])
        self.assertEqual([row["actorEmail"] for row in ic],
                         ["dev.operations@example.invalid", "dev.cf01-b@example.invalid"])
        self.assertEqual(len(rows), 12)
        self.assertEqual(len(runner.load_manifest()["excluded"]), 7)
        for invalid in ([ic[1]], list(reversed(ic)), [ic[0], rows[0], ic[1]],
                        [dict(ic[0], preserveAppData=True), ic[1]],
                        [ic[0], dict(ic[1], successMarker="DEV_IC_FITNESS_PASS")],
                        [ic[0], dict(ic[1], actorEmail="dev.operations@example.invalid")]):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                runner.require_inner_cover_sequence(invalid)

    def test_inner_cover_pair_keeps_backend_state_but_requires_both_actual_markers(self):
        rows = [row for row in runner.load_manifest()["journeys"] if row["path"] in runner.IC_PATHS]
        for fail_at in (None, 0, 1):
            events = []
            def logged(command, name, timeout, env):
                events.append(name)
                if name == "cf01-http-boundary":
                    return HTTP_PROOF
                for index, row in enumerate(rows):
                    if name == Path(row["path"]).stem:
                        return rows[1-index]["successMarker"] if fail_at == index else row["successMarker"]
                return ""
            with self.subTest(fail_at=fail_at), tempfile.TemporaryDirectory() as folder, \
                    patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "run_logged", side_effect=logged), \
                    patch.object(runner, "prepare_ci_journey") as prepare, \
                    patch.object(runner, "required_red_relay") as relay, \
                    patch.object(runner.subprocess, "run") as restart:
                if fail_at is None:
                    runner.execute_journeys("emulator-5554", {"journeys": rows}, {})
                else:
                    with self.assertRaisesRegex(RuntimeError, "completion marker"):
                        runner.execute_journeys("emulator-5554", {"journeys": rows}, {})
                report = json.loads((Path(folder)/"result.json").read_text(encoding="utf-8"))
            self.assertEqual(events.count("seed"), 1)
            self.assertEqual(prepare.call_count, 1 if fail_at == 0 else 2)
            restart.assert_not_called()
            relay.assert_not_called()
            self.assertEqual([row["status"] for row in report["attempts"]],
                             ["passed", "passed"] if fail_at is None else
                             (["failed", "untested"] if fail_at == 0 else ["passed", "failed"]))
            if fail_at == 0:
                self.assertNotIn(Path(rows[1]["path"]).stem, events)

    def test_invalid_inner_cover_order_fails_before_seeding_or_android(self):
        ic = [row for row in runner.load_manifest()["journeys"] if row["path"] in runner.IC_PATHS]
        with patch.object(runner, "run_logged") as run, \
                patch.object(runner, "prepare_ci_journey") as prepare:
            with self.assertRaisesRegex(ValueError, "Inner Cover"):
                runner.execute_journeys("emulator-5554", {"journeys": list(reversed(ic))}, {})
        run.assert_not_called()
        prepare.assert_not_called()

    def test_previous_attempt_output_is_preserved_before_seed_or_backend(self):
        for argv in ([], ["--inside-emulators"]):
            with self.subTest(argv=argv), tempfile.TemporaryDirectory() as folder:
                previous = Path(folder)/"seed.log"
                previous.write_bytes(b"original partial fixture failure\n")
                with patch.object(runner, "OUTPUT", Path(folder)), \
                        patch.object(runner, "require_isolated_environment"), \
                        patch.object(runner, "run_logged") as run, \
                        patch.object(runner.subprocess, "run") as backend:
                    with self.assertRaisesRegex(RuntimeError, "already contains evidence"):
                        runner.main(argv)
                run.assert_not_called()
                backend.assert_not_called()
                self.assertEqual(previous.read_bytes(), b"original partial fixture failure\n")
                self.assertEqual([p.name for p in Path(folder).iterdir()], ["seed.log"])

    def test_direct_execution_also_refuses_existing_attempt_results(self):
        with tempfile.TemporaryDirectory() as folder:
            previous = Path(folder)/"result.json"
            previous.write_bytes(b'{"status":"failed"}\n')
            with patch.object(runner, "OUTPUT", Path(folder)), \
                    patch.object(runner, "run_logged") as run, \
                    self.assertRaisesRegex(RuntimeError, "already contains evidence"):
                runner.execute_journeys("emulator-5554", runner.load_manifest(), {})
            run.assert_not_called()
            self.assertEqual(previous.read_bytes(), b'{"status":"failed"}\n')

    def test_output_file_is_refused_without_replacement(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"evidence"
            path.write_bytes(b"preserve")
            with patch.object(runner, "OUTPUT", path), self.assertRaisesRegex(RuntimeError, "already contains evidence"):
                runner.require_fresh_output()
            self.assertEqual(path.read_bytes(), b"preserve")


if __name__ == "__main__":
    unittest.main()
