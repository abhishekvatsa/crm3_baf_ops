"""Credential-free launcher-plan tests; no spawned Node or hosted qualification."""
import hashlib
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch

FILE = Path(__file__).with_name("business31HostedLauncher.py")
spec = importlib.util.spec_from_file_location("hosted_launcher_under_test", FILE)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LauncherPlan(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="business-hosted-plan-")
        self.root = Path(self.temp.name)
        self.node = self.root / "inert-node-never-executed"
        self.node.write_bytes(b"synthetic executable identity only")
        self.input = self.root / "input.json"
        self.input.write_text("{}", encoding="utf-8")
        self.trust = self.root / "trust.json"
        self.data = {"launcherSha256": launcher.digest(FILE), "pythonSha256": launcher.digest(Path(sys.executable)), "nodeSha256": launcher.digest(self.node),
                     "verifier": {"files": {"tools/release/" + n: launcher.digest(FILE.with_name(n)) for n in
                     ["business31HostedProtocol.cjs", "business31HostedReplay.cjs", "business31HostedResult.cjs"]}}}
        self.data["verifier"]["files"].update({name: launcher.digest(FILE.parents[2] / name) for name in launcher.REPLAY_HELPERS})
        self.write_trust()

    def write_trust(self):
        self.trust.write_text(json.dumps(self.data), encoding="utf-8")
        self.digest = launcher.digest(self.trust)

    def tearDown(self):
        self.temp.cleanup()

    def plan(self, mode="consume"):
        return launcher.launch_plan(mode, str(self.node), str(self.trust), self.digest,
                                    str(self.input), str(self.root / "business31-hosted-result.json"), str(self.root))

    def test_scrubbed_fixed_consumer_arguments(self):
        with patch.dict(os.environ, {"GITHUB_TOKEN": "synthetic", "NODE_OPTIONS": "--require evil",
                                    "NODE_PATH": "evil", "PYTHONPATH": "evil", "GOOGLE_APPLICATION_CREDENTIALS": "evil",
                                    "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "private-unneeded"}):
            argv, env = self.plan()
        self.assertEqual(argv[:3], [str(self.node), "--no-global-search-paths", str(FILE.with_name("business31HostedResult.cjs"))])
        for key in ("NODE_OPTIONS", "NODE_PATH", "PYTHONPATH", "GOOGLE_APPLICATION_CREDENTIALS", "ACTIONS_ID_TOKEN_REQUEST_TOKEN"):
            self.assertNotIn(key, env)

    def test_only_replay_gets_finite_platform_inputs(self):
        with patch.dict(os.environ, {"GITHUB_TOKEN": "synthetic", "ACTIONS_ID_TOKEN_REQUEST_URL": "https://synthetic.actions.githubusercontent.com/token",
                                    "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "synthetic", "CLOUDSDK_AUTH_ACCESS_TOKEN": "excluded"}):
            argv, env = self.plan("replay")
        self.assertTrue(argv[2].endswith("business31HostedReplay.cjs"))
        self.assertNotIn("CLOUDSDK_AUTH_ACCESS_TOKEN", env)
        self.assertEqual(env["ACTIONS_ID_TOKEN_REQUEST_TOKEN"], "synthetic")

    def test_replay_requires_all_five_direct_helper_bindings(self):
        original = dict(self.data["verifier"]["files"])
        for name in launcher.REPLAY_HELPERS:
            with self.subTest(name=name):
                self.data["verifier"]["files"] = dict(original)
                del self.data["verifier"]["files"][name]
                self.write_trust()
                with self.assertRaisesRegex(ValueError, "REPLAY_PRODUCER"):
                    self.plan("replay")

    def test_config_commitment_required(self):
        self.digest = "0" * 64
        with self.assertRaisesRegex(ValueError, "EXTERNAL_CONFIG_COMMITMENT"):
            self.plan()

    def test_wrong_node_identity_refuses(self):
        self.node.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "NODE_IDENTITY"):
            self.plan()

    def test_changed_producer_identity_refuses(self):
        self.data["verifier"]["files"]["tools/release/business31HostedProtocol.cjs"] = "0" * 64
        self.write_trust()
        with self.assertRaisesRegex(ValueError, "PRODUCER_IDENTITY"):
            self.plan()

    def test_unknown_mode_and_relative_input_refuse(self):
        with self.assertRaisesRegex(ValueError, "MODE"):
            self.plan("arbitrary")
        self.input = Path("relative.json")
        with self.assertRaisesRegex(ValueError, "ABSOLUTE_PATH"):
            self.plan()

    def test_isolated_interpreter_required_before_platform_inputs(self):
        with patch.object(sys, "flags", SimpleNamespace(isolated=0, no_site=1)):
            with self.assertRaisesRegex(ValueError, "ISOLATED_PYTHON_REQUIRED"):
                self.plan()

    def test_wrong_python_identity_refuses(self):
        self.data["pythonSha256"] = "0" * 64
        self.write_trust()
        with self.assertRaisesRegex(ValueError, "PYTHON_IDENTITY"):
            self.plan()

    def consumer_fixture(self):
        trust = {"profile": "build31-business-hosted-recorded-replay-v1",
                 "source": {"commit": "a" * 40, "tree": "b" * 40, "functionsTree": "c" * 40},
                 "verifier": {"commit": "d" * 40, "tree": "e" * 40}, "sourceManifestSha256": "A" * 64}
        request = {"candidate": {"commit": "f" * 40, "tree": "1" * 40, "ref": "refs/pull/4/head",
                                 "kind": "pull_request", "pullRequest": 4},
                   "descriptorPointer": {"commit": "2" * 40,
                                         "file": "release/evidence/build31-business-private-replay.json",
                                         "sha256": "B" * 64}, "runId": "42", "runAttempt": "1"}
        value = {"schemaVersion": 2, "profile": trust["profile"],
                 "verifier": dict(trust["verifier"]), "source": dict(trust["source"]),
                 "candidate": dict(request["candidate"]), "descriptorPointer": dict(request["descriptorPointer"]),
                 "closurePointer": {"commit": "3" * 40,
                                    "file": "release/evidence/build31-business-backend-deployment-closure.json",
                                    "sha256": "C" * 64},
                 "commitments": {"bundleSha256": "D" * 64, "membersSha256": "E" * 64,
                                 "relocationSha256": "F" * 64, "sourceManifestSha256": "A" * 64},
                 "runId": "42", "runAttempt": "1", "artifactId": "71", "resultSha256": "D" * 64,
                 "hostedRecordedReplayResultAuthenticated": True,
                 "ownerIdentityAuthenticated": False, "originalProcessExecutionAuthenticated": False,
                 "deploymentAuthorized": False, "constructionAuthorized": False, "distributionAuthorized": False}
        return trust, request, value

    @staticmethod
    def projection_bytes(value):
        return json.dumps(value, separators=(",", ":")).encode("utf-8") + b"\n"

    def test_consumer_publishes_only_exact_sanitized_schema(self):
        trust, request, value = self.consumer_fixture()
        raw = self.projection_bytes(value)
        self.assertEqual(launcher.sanitized_consumer_output(raw, trust, request), raw)
        for altered in (b"private raw\n" + raw, raw + b"private raw", b"\n" + raw):
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                launcher.sanitized_consumer_output(altered, trust, request)

    def test_consumer_accepts_exact_main_selection(self):
        trust, request, value = self.consumer_fixture()
        request["candidate"].update(kind="main", ref="refs/heads/main", pullRequest=None)
        value["candidate"] = dict(request["candidate"])
        raw = self.projection_bytes(value)
        self.assertEqual(launcher.sanitized_consumer_output(raw, trust, request), raw)

    def test_consumer_rejects_version_one_and_missing_or_extra_joins(self):
        trust, request, original = self.consumer_fixture()
        old = {key: val for key, val in original.items() if key not in
               ("verifier", "source", "candidate", "descriptorPointer", "closurePointer", "commitments")}
        old.update(schemaVersion=1, verifierCommit=trust["verifier"]["commit"],
                   sourceCommit=trust["source"]["commit"], candidateCommit=request["candidate"]["commit"])
        with self.assertRaisesRegex(ValueError, "CONSUMER_OUTPUT_FIELDS"):
            launcher.sanitized_consumer_output(self.projection_bytes(old), trust, request)
        for key in ("verifier", "source", "candidate", "descriptorPointer", "closurePointer", "commitments"):
            with self.subTest(missing=key):
                value = dict(original)
                del value[key]
                with self.assertRaisesRegex(ValueError, "CONSUMER_OUTPUT_FIELDS"):
                    launcher.sanitized_consumer_output(self.projection_bytes(value), trust, request)
        value = dict(original, candidateCommit=request["candidate"]["commit"])
        with self.assertRaisesRegex(ValueError, "CONSUMER_OUTPUT_FIELDS"):
            launcher.sanitized_consumer_output(self.projection_bytes(value), trust, request)

    def test_consumer_rejects_changed_selected_joins_and_malformed_commitments(self):
        trust, request, original = self.consumer_fixture()
        cases = [
            (("schemaVersion",), 1, "CONSUMER_OUTPUT_VERSION"),
            (("schemaVersion",), 2.0, "CONSUMER_OUTPUT_VERSION"),
            (("verifier", "tree"), "0" * 40, "CONSUMER_OUTPUT_IDENTITY"),
            (("source", "functionsTree"), "0" * 40, "CONSUMER_OUTPUT_IDENTITY"),
            (("candidate", "tree"), "0" * 40, "CONSUMER_OUTPUT_IDENTITY"),
            (("candidate", "pullRequest"), True, "CONSUMER_CANDIDATE_ROUTE"),
            (("candidate", "ref"), "refs/heads/main", "CONSUMER_CANDIDATE_ROUTE"),
            (("descriptorPointer", "commit"), "0" * 40, "CONSUMER_DESCRIPTOR_JOIN"),
            (("descriptorPointer", "sha256"), "0" * 64, "CONSUMER_DESCRIPTOR_JOIN"),
            (("closurePointer", "file"), "release/evidence/other.json", "CONSUMER_POINTER_IDENTITY"),
            (("closurePointer", "sha256"), "a" * 64, "CONSUMER_POINTER_IDENTITY"),
            (("commitments", "sourceManifestSha256"), "0" * 64, "CONSUMER_COMMITMENT_JOIN"),
            (("commitments", "membersSha256"), "not-a-hash", "CONSUMER_COMMITMENT_JOIN"),
            (("commitments", "rawEvidence"), "private", "CONSUMER_COMMITMENT_FIELDS"),
            (("runId",), "43", "CONSUMER_OUTPUT_IDENTITY"),
            (("runAttempt",), 1, "CONSUMER_OUTPUT_IDENTITY"),
            (("artifactId",), "0", "CONSUMER_OUTPUT_DIGEST"),
            (("artifactId",), "\u0661", "CONSUMER_OUTPUT_DIGEST"),
            (("hostedRecordedReplayResultAuthenticated",), False, "CONSUMER_OUTPUT_IDENTITY")
        ]
        for keys, replacement, error in cases:
            with self.subTest(field=".".join(keys), replacement=replacement):
                value = json.loads(json.dumps(original))
                target = value
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = replacement
                with self.assertRaisesRegex(ValueError, error):
                    launcher.sanitized_consumer_output(self.projection_bytes(value), trust, request)
        for field, missing in (("verifier", "tree"), ("source", "functionsTree"),
                               ("candidate", "ref"), ("closurePointer", "commit"),
                               ("commitments", "relocationSha256")):
            with self.subTest(missing=field + "." + missing):
                value = json.loads(json.dumps(original))
                del value[field][missing]
                with self.assertRaisesRegex(ValueError, "CONSUMER_.*FIELDS"):
                    launcher.sanitized_consumer_output(self.projection_bytes(value), trust, request)

    def test_consumer_rejects_every_authority_elevation(self):
        trust, request, original = self.consumer_fixture()
        for field in ("ownerIdentityAuthenticated", "originalProcessExecutionAuthenticated",
                      "deploymentAuthorized", "constructionAuthorized", "distributionAuthorized"):
            with self.subTest(field=field):
                value = dict(original)
                value[field] = True
                with self.assertRaisesRegex(ValueError, "CONSUMER_AUTHORITY"):
                    launcher.sanitized_consumer_output(self.projection_bytes(value), trust, request)

    def client_plan(self, **changes):
        values = dict(mode="consume", node=str(self.node), trust_file=str(self.trust),
                      trust_sha256=self.digest, input_file=str(self.input),
                      output=str(self.root / "business31-hosted-result.json"), workspace=str(self.root),
                      client_input=str(self.input), client_input_sha256=launcher.digest(self.input))
        values.update(changes)
        return launcher.launch_plan(**values)

    def test_client_selection_is_paired(self):
        for changes in ({"client_input": None}, {"client_input_sha256": None}):
            with self.subTest(changes=changes), self.assertRaisesRegex(ValueError, "CLIENT_INPUT_SELECTION"):
                self.client_plan(**changes)

    def test_client_input_requires_independent_digest_and_complete_helpers(self):
        with self.assertRaisesRegex(ValueError, "CLIENT_INPUT_COMMITMENT"):
            self.client_plan(client_input_sha256="0" * 64)
        with self.assertRaisesRegex(ValueError, "CLIENT_PRODUCER"):
            self.client_plan()
        for name in launcher.CLIENT_HELPERS:
            self.data["verifier"]["files"][name] = launcher.digest(FILE.parents[2] / name)
        self.write_trust()
        with patch.dict(os.environ, {"GITHUB_TOKEN": "synthetic"}):
            argv, env = self.client_plan()
        self.assertEqual(argv[-4:], ["--client-input", str(self.input),
                                     "--client-input-sha256", launcher.digest(self.input)])
        self.assertNotIn("ACTIONS_ID_TOKEN_REQUEST_TOKEN", env)
        with patch.dict(os.environ, {"GITHUB_TOKEN": "synthetic", "ACTIONS_ID_TOKEN_REQUEST_URL": "https://synthetic.actions.githubusercontent.com/token",
                                    "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "synthetic"}):
            replay, replay_env = self.client_plan(mode="replay")
        self.assertEqual(replay[-4:], argv[-4:])
        self.assertEqual(replay_env["ACTIONS_ID_TOKEN_REQUEST_TOKEN"], "synthetic")
        self.input.write_bytes(b'{"changed":true}')
        with self.assertRaisesRegex(ValueError, "CLIENT_INPUT_COMMITMENT"):
            self.client_plan(client_input_sha256=hashlib.sha256(b"{}").hexdigest().upper())

    def client_fixture(self):
        trust, request, value = self.consumer_fixture()
        selected = {"source": dict(trust["source"]), "sourceManifestSha256": trust["sourceManifestSha256"],
                    "descriptor": dict(value["descriptorPointer"]), "backendClosure": dict(value["closurePointer"]),
                    "ownerPointer": {"commit": "4" * 40,
                                     "file": "release/approvals/build31-business-client-owner-authorization.json",
                                     "sha256": "5" * 64},
                    "decisionPointer": {"commit": "6" * 40,
                                        "file": "release/approvals/build31-business-client-compatibility-approval.json",
                                        "sha256": "7" * 64},
                    "originalMessage": {"sha256": "8" * 64, "bytes": 140},
                    "appCheck": {"releaseId": "synthetic-release", "reservationId": "synthetic-reservation",
                                 "clientEnabled": True, "androidProvider": "playIntegrity",
                                 "mutatingDefaultEnforced": False,
                                 "identityCallable": {"name": "getBackendReleaseIdentity", "enforced": True,
                                                      "sourceFile": "functions/src/stage2dSecurityConfig.ts",
                                                      "sourceSha256": "1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F"}}}
        client = {key: json.loads(json.dumps(selected[key])) for key in
                  ("ownerPointer", "decisionPointer", "originalMessage", "appCheck")}
        client.update(schemaVersion=2, profile="build31-business-client-compatibility-v1",
                      publicClosureRecordedAtUtc="2026-01-01T00:00:00Z")
        client.update({key: True for key in ("gitCustodyVerified", "dedicatedOwnerDecisionDeltasVerified",
                                           "descriptorPreparationVerified", "recordedSemanticsValidated", "appCheckSourcePolicyVerified")})
        client.update({key: False for key in ("independentlySelectedInputsAuthenticated",
                                            "executingHostAuthenticated", "humanIdentityAuthenticated",
                                            "trustedClockAuthenticated", "platformIdentityAuthenticated",
                                            "credentialAccessAuthorized", "backendDeploymentAuthorized",
                                            "constructionAuthorized", "signingAuthorized", "distributionAuthorized")})
        paths = {"policy": "release/production-release-policy.json", "versionApproval": "release/approvals/version-policy-approval.json",
                 "successorApproval": "release/approvals/build-number-31-successor-approval.json",
                 "currentSuccessor": "release/current-successor-state.json",
                 "appCheckApproval": "release/approvals/build31-app-check-client-approval.json", "pubspec": "pubspec.yaml",
                 "backendPolicy": "release/production-release-policy.json", "identitySource": "functions/src/stage2dSecurityConfig.ts",
                 "rulesReadback": "release/evidence/build30-current-source-firestore-rules-indexes-live-readback.json"}
        bindings = {name: {"file": file, "sha256": "A" * 64,
                           "commit": trust["source"]["commit"] if name in ("backendPolicy", "identitySource", "rulesReadback") else request["candidate"]["commit"]}
                    for name, file in paths.items()}
        identity = selected["appCheck"]["identityCallable"]
        bindings["identitySource"]["sha256"] = identity["sourceSha256"]
        bindings["rulesReadback"]["sha256"] = "62A707AC10A76B6C9D6D1466987D558E8C9186602B57E0E75EB760A5F4160CEC"
        policy = {"schemaVersion": 1, "profile": "build31-business-client-policy-v1", "verifier": dict(trust["verifier"]),
                  "source": dict(trust["source"]), "candidate": dict(request["candidate"]),
                  "sourceManifestSha256": trust["sourceManifestSha256"], "bindings": bindings,
                  "descriptorPointer": dict(value["descriptorPointer"]), "closurePointer": dict(value["closurePointer"]),
                  "decisionPointer": dict(selected["decisionPointer"]), "policySourceVerified": True, "appCheckSourcePolicyVerified": True,
                  "release": {"releaseId": selected["appCheck"]["releaseId"], "reservationId": selected["appCheck"]["reservationId"],
                              "buildNumber": 31, "versionName": "1.0.1", "reservationTag": "crm3-build-reserved/31", "builtTag": "crm3-build-built/31"},
                  "appCheck": {"clientEnabled": True, "androidProvider": "playIntegrity", "dartDefine": "true",
                               "approvalFile": paths["appCheckApproval"], "approvalSha256": bindings["appCheckApproval"]["sha256"],
                               "backendReceiptFile": value["closurePointer"]["file"], "backendReceiptSha256": value["closurePointer"]["sha256"],
                               "serverEnforcementAtBuild": False, "enforcementChangedByBuild": False,
                               "tokenValidationEvidence": "not-proved-by-artifact-construction",
                               "serverEnforcementScopesAtBuild": {"defaultMutatingEnforced": False, "identityCallable": identity["name"],
                                                                  "identityCallableEnforced": True, "identitySourceFile": identity["sourceFile"],
                                                                  "identitySourceSha256": identity["sourceSha256"]}}}
        policy.update({key: False for key, item in client.items() if item is False})
        policy["privateReplayVerified"] = False
        client["policy"] = policy
        value.update(schemaVersion=3, client=client)
        return trust, request, value, {"selected": selected}

    def test_client_projection_keeps_legacy_mode_separate_and_has_no_raw_message(self):
        trust, request, value, client_input = self.client_fixture()
        raw = self.projection_bytes(value)
        self.assertEqual(launcher.sanitized_client_output(raw, trust, request, client_input), raw)
        with self.assertRaisesRegex(ValueError, "CONSUMER_OUTPUT_FIELDS"):
            launcher.sanitized_consumer_output(raw, trust, request)
        with self.assertRaisesRegex(ValueError, "CLIENT_OUTPUT_FIELDS"):
            value["client"]["originalMessageFile"] = "private/path"
            launcher.sanitized_client_output(self.projection_bytes(value), trust, request, client_input)

    def test_client_projection_refuses_all_claim_elevations_and_changed_joins(self):
        trust, request, original, client_input = self.client_fixture()
        cases = [(("client", key), True) for key, item in original["client"].items() if item is False]
        cases += [(("client", key), False) for key, item in original["client"].items() if item is True]
        cases += [(("client", "ownerPointer", "commit"), "0" * 40),
                  (("client", "decisionPointer", "sha256"), "0" * 64),
                  (("client", "originalMessage", "bytes"), 141),
                  (("client", "originalMessage", "bytes"), True),
                  (("client", "appCheck", "clientEnabled"), False),
                  (("client", "appCheck", "identityCallable", "enforced"), False),
                  (("client", "publicClosureRecordedAtUtc"), "private/path"),
                  (("schemaVersion",), 2), (("schemaVersion",), 3.0),
                  (("closurePointer", "sha256"), "0" * 64)]
        for keys, replacement in cases:
            with self.subTest(field=".".join(keys)):
                value = json.loads(json.dumps(original))
                target = value
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = replacement
                with self.assertRaises(ValueError):
                    launcher.sanitized_client_output(self.projection_bytes(value), trust, request, client_input)

    def test_client_projection_rejects_missing_fields_and_extra_output(self):
        trust, request, original, client_input = self.client_fixture()
        for field in original["client"]:
            with self.subTest(missing=field):
                value = json.loads(json.dumps(original))
                del value["client"][field]
                with self.assertRaisesRegex(ValueError, "CLIENT_OUTPUT_FIELDS"):
                    launcher.sanitized_client_output(self.projection_bytes(value), trust, request, client_input)
        raw = self.projection_bytes(original)
        for changed in (b"\n" + raw, b"private\n" + raw, raw + b"private"):
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                launcher.sanitized_client_output(changed, trust, request, client_input)

    def test_policy_capsule_refuses_changed_sources_bindings_grants_and_boolean_coercion(self):
        trust, request, original, client_input = self.client_fixture()
        cases = [(('source', 'commit'), '0' * 40), (('bindings', 'policy', 'commit'), '0' * 40),
                 (('bindings', 'identitySource', 'sha256'), '0' * 64), (('release', 'buildNumber'), True),
                 (('release', 'reservationId'), 'other'), (('constructionAuthorized',), True),
                 (('appCheck', 'clientEnabled'), 1), (('appCheck', 'serverEnforcementScopesAtBuild', 'identityCallableEnforced'), 1)]
        for keys, replacement in cases:
            with self.subTest(keys=keys):
                value = json.loads(json.dumps(original))
                target = value['client']['policy']
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = replacement
                with self.assertRaises(ValueError):
                    launcher.sanitized_client_output(self.projection_bytes(value), trust, request, client_input)

    def artifact_fixture(self):
        trust, request, projection, client_input = self.client_fixture()
        now = datetime.now(timezone.utc)
        wire = lambda t: t.isoformat(timespec='milliseconds').replace('+00:00', 'Z')
        request.update(schemaVersion=2, challenge={"schemaVersion": 1, "nonce": "a" * 64, "purpose": "policy",
            "requestedAtUtc": wire(now - timedelta(seconds=2)), "expiresAtUtc": wire(now + timedelta(minutes=2)),
            "requester": {"kind": "local", "runId": None, "runAttempt": None, "invocationId": "b" * 64},
            "clientSelectionSha256": "C" * 64, "fileBindings": []})
        trust.update(repository={"id": "1"}, workflow={"id": "2", "environment": "synthetic"}, maximumResultAgeSeconds=3600)
        value = {key: projection[key] for key in ('profile', 'verifier', 'source', 'candidate', 'descriptorPointer', 'closurePointer', 'commitments', 'client')}
        value.update(schemaVersion=2, documentType='build31-business-hosted-result', challenge=request['challenge'],
                     platform={"repositoryId": "1", "workflowId": "2", "workflowCommit": trust['verifier']['commit'],
                               "runId": request['runId'], "runAttempt": request['runAttempt'], "environment": "synthetic"},
                     startedAtUtc=wire(now - timedelta(seconds=1)), completedAtUtc=wire(now), recordedSemanticsReplayed=True,
                     limits={key: False for key in ('ownerIdentityAuthenticated', 'originalProcessExecutionAuthenticated',
                                                   'deploymentAuthorized', 'constructionAuthorized', 'distributionAuthorized')})
        projection['challenge'] = request['challenge']
        return trust, request, value, projection, client_input

    def test_artifact2_and_remote_consumer_need_no_local_message_for_public_validation(self):
        trust, request, value, projection, client_input = self.artifact_fixture()
        raw = self.projection_bytes(value)
        self.assertEqual(launcher.sanitized_replay_output(raw, trust, request, client_input), raw)
        public = self.projection_bytes(projection)
        self.assertEqual(launcher.sanitized_client_output(public, trust, request), public)
        with self.assertRaisesRegex(ValueError, 'REPLAY_CLIENT_SELECTION'):
            launcher.sanitized_replay_output(raw, trust, request)

    def test_artifact2_refuses_challenge_drift_downgrade_and_raw_private_fields(self):
        trust, request, original, projection, client_input = self.artifact_fixture()
        for field, replacement in [('schemaVersion', 1), ('recordedSemanticsReplayed', False),
                                    ('challenge', {**original['challenge'], 'nonce': 'f' * 64}), ('privateRaw', 'forbidden')]:
            with self.subTest(field=field):
                value = {**original, field: replacement}
                with self.assertRaises(ValueError):
                    launcher.sanitized_replay_output(self.projection_bytes(value), trust, request, client_input)

    def test_remote_client_projection_refuses_challenge_expiry_after_consume(self):
        trust, request, _, projection, _ = self.artifact_fixture()
        past = datetime.now(timezone.utc) - timedelta(seconds=1)
        request['challenge']['expiresAtUtc'] = past.isoformat(timespec='milliseconds').replace('+00:00', 'Z')
        with self.assertRaisesRegex(ValueError, 'CLIENT_CHALLENGE_TIME'):
            launcher.sanitized_client_output(self.projection_bytes(projection), trust, request)

    def replay_args(self):
        self.input.write_text(json.dumps({"request": {}, "repositoryRoot": "synthetic",
                                         "gitExecutable": "synthetic", "sourceManifest": {}}), encoding="utf-8")
        return SimpleNamespace(mode="replay", node=str(self.node), trust=str(self.trust),
                               trust_sha256=self.digest, input=str(self.input),
                               output=str(self.root / "business31-hosted-result.json"),
                               private_parent=str(self.root))

    def staged_child(self, argv, env, owned):
        self.assertFalse((self.root / "business31-hosted-result.json").exists())
        (Path(owned) / "business31-hosted-result.json").write_bytes(b'{"synthetic":true}\n')
        return b"", b""

    def test_private_cleanup_failure_never_publishes_replay_result(self):
        args = self.replay_args()
        native_temp = tempfile.TemporaryDirectory

        class CleanupFailure:
            def __init__(self, **kwargs):
                self.actual = native_temp(**kwargs)

            def __enter__(self):
                return self.actual.__enter__()

            def __exit__(self, *exc):
                self.actual.__exit__(*exc)
                raise OSError("synthetic private cleanup failure")

        with patch.object(sys, "platform", "linux"), \
             patch.object(launcher.tempfile, "TemporaryDirectory", CleanupFailure), \
             patch.object(launcher, "launch_plan", return_value=([], {})), \
             patch.object(launcher, "sanitized_replay_output", side_effect=lambda raw, *args: raw), \
             patch.object(launcher, "run_child", side_effect=self.staged_child):
            with self.assertRaisesRegex(OSError, "private cleanup"):
                launcher.execute_launch(args)
        self.assertFalse(Path(args.output).exists())

    def test_success_publishes_only_after_owned_directory_cleanup(self):
        args = self.replay_args()
        with patch.object(sys, "platform", "linux"), \
             patch.object(launcher, "launch_plan", return_value=([], {})), \
             patch.object(launcher, "sanitized_replay_output", side_effect=lambda raw, *args: raw), \
             patch.object(launcher, "run_child", side_effect=self.staged_child):
            launcher.execute_launch(args)
        self.assertEqual(Path(args.output).read_bytes(), b'{"synthetic":true}\n')
        self.assertFalse(list(self.root.glob("business31-launch-*")))


if __name__ == "__main__":
    unittest.main()
