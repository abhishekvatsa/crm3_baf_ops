"""Credential-free launcher and synthetic diagnostic tests; no hosted qualification."""
import hashlib
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
import shutil
import stat
from pathlib import Path
import tempfile
import sys
import subprocess
import textwrap
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

    def transport_v2_fixture(self):
        """Synthetic public projections; no original evidence or hosted authority."""
        trust, request, artifact, public, client_input = self.artifact_fixture()
        trust.update(schemaVersion=2, profile=launcher.PROFILE_V2,
                     nodeSha256="A" * 64, gitSha256="B" * 64, launcherSha256="C" * 64,
                     pythonSha256="D" * 64, wifAudience="synthetic-unused-audience")
        trust["verifier"]["files"] = {}
        trust["coreVerifier"] = {"commit": trust["source"]["commit"], "tree": trust["source"]["tree"],
            "files": {"tools/release/" + name: "E" * 64 for name in
                      ("business31BackendAuthority.cjs", "business31BackendClosure.cjs", "backendRuntimeEvidenceAccess31.cjs")}}
        trust["sourceIntegration"] = {"tools/release/business31HostedProtocol.cjs":
            {"mode": "100644", "oid": "8" * 40, "sha256": "F" * 64}}
        core = launcher.core_summary(trust)
        for value in (artifact, public):
            value.update(profile=launcher.PROFILE_V2, coreVerifier=dict(core))
            value["commitments"].update(launcher.transport_commitments(trust))
            value["client"].update(schemaVersion=3, profile="build31-business-client-compatibility-v2", coreVerifier=dict(core))
            value["client"]["policy"].update(schemaVersion=2, profile="build31-business-client-policy-v2", coreVerifier=dict(core))
        return trust, request, artifact, public, client_input

    def test_v2_public_projections_preserve_separate_core_and_outer_identities(self):
        trust, request, artifact, public, client_input = self.transport_v2_fixture()
        self.assertNotEqual(trust["verifier"]["commit"], trust["coreVerifier"]["commit"])
        self.assertEqual(launcher.sanitized_replay_output(self.projection_bytes(artifact), trust, request, client_input),
                         self.projection_bytes(artifact))
        self.assertEqual(launcher.sanitized_client_output(self.projection_bytes(public), trust, request),
                         self.projection_bytes(public))
        self.assertNotIn("files", public["coreVerifier"])
        self.assertNotIn("sourceIntegration", public)

    def test_v2_launch_plan_requires_all_new_helpers_and_independent_client_selection(self):
        trust, _, _, _, _ = self.transport_v2_fixture()
        trust.update(nodeSha256=launcher.digest(self.node), launcherSha256=launcher.digest(FILE),
                     pythonSha256=launcher.digest(Path(sys.executable)))
        names = set(self.data['verifier']['files']) | set(launcher.CLIENT_HELPERS) | set(launcher.V2_REPLAY_HELPERS)
        trust['verifier']['files'] = {name: launcher.digest(FILE.parents[2] / name) for name in names}
        self.data = trust
        self.write_trust()
        with self.assertRaisesRegex(ValueError, 'V2_CLIENT_SELECTION_REQUIRED'):
            self.plan('replay')
        def selected_plan():
            with patch.dict(os.environ, {'GITHUB_TOKEN': 'synthetic',
                    'ACTIONS_ID_TOKEN_REQUEST_URL': 'https://synthetic.actions.githubusercontent.com/token',
                    'ACTIONS_ID_TOKEN_REQUEST_TOKEN': 'synthetic'}):
                return launcher.launch_plan('replay', str(self.node), str(self.trust), self.digest,
                    str(self.input), str(self.root / 'business31-hosted-result.json'), str(self.root),
                    str(self.input), launcher.digest(self.input))
        argv, env = selected_plan()
        self.assertEqual(argv[2], str(FILE.with_name('business31HostedReplay.cjs')))
        self.assertNotIn('NODE_OPTIONS', env)
        original = dict(self.data['verifier']['files'])
        for name in launcher.V2_REPLAY_HELPERS:
            with self.subTest(missing=name):
                self.data['verifier']['files'] = dict(original)
                del self.data['verifier']['files'][name]
                self.write_trust()
                with self.assertRaisesRegex(ValueError, 'REPLAY_PRODUCER'):
                    selected_plan()

    def test_v2_public_route_refuses_mixed_versions_maps_and_core_relabelling(self):
        trust, request, original, _, client_input = self.transport_v2_fixture()
        cases = [(("profile",), launcher.PROFILE_V1),
                 (("coreVerifier", "commit"), trust["verifier"]["commit"]),
                 (("coreVerifier", "files"), trust["coreVerifier"]["files"]),
                 (("commitments", "coreProducerBindingsSha256"), "0" * 64),
                 (("commitments", "sourceIntegrationSha256"), "0" * 64),
                 (("client", "schemaVersion"), 2),
                 (("client", "profile"), "build31-business-client-compatibility-v1"),
                 (("client", "coreVerifier", "tree"), "0" * 40),
                 (("client", "policy", "schemaVersion"), 1),
                 (("client", "policy", "profile"), "build31-business-client-policy-v1"),
                 (("client", "policy", "coreVerifier", "tree"), "0" * 40),
                 (("platform", "workflowCommit"), trust["coreVerifier"]["commit"]),
                 (("limits", "deploymentAuthorized"), True),
                 (("challenge", "purpose"), "construction")]
        for keys, replacement in cases:
            with self.subTest(field=".".join(keys)):
                value = json.loads(json.dumps(original))
                target = value
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = replacement
                with self.assertRaises(ValueError):
                    launcher.sanitized_replay_output(self.projection_bytes(value), trust, request, client_input)

    def test_v2_trust_has_no_legacy_fallback_and_map_changes_invalidate_result(self):
        trust, request, artifact, _, client_input = self.transport_v2_fixture()
        cases = [(('schemaVersion',), 1), (('schemaVersion',), 2.0), (('profile',), launcher.PROFILE_V1),
                 (('coreVerifier', 'commit'), '0' * 40),
                 (('sourceIntegration', 'tools/release/business31HostedProtocol.cjs', 'mode'), '100755'),
                 (('sourceIntegration', 'tools/release/business31HostedProtocol.cjs', 'oid'), '9' * 40),
                 (('coreVerifier', 'files', 'tools/release/business31BackendClosure.cjs'), '0' * 64)]
        for keys, replacement in cases:
            with self.subTest(field=".".join(keys)):
                selected = json.loads(json.dumps(trust))
                target = selected
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = replacement
                with self.assertRaises(ValueError):
                    launcher.sanitized_replay_output(self.projection_bytes(artifact), selected, request, client_input)
        request['schemaVersion'] = 1
        with self.assertRaisesRegex(ValueError, 'V2_CHALLENGE_REQUIRED'):
            launcher.sanitized_replay_output(self.projection_bytes(artifact), trust, request, client_input)

    def workflow_prepare(self, *, legacy=False, chunked=False, expanded=False,
                         raw=None, alter=None, alter_parts=None, expected_hash=None, alter_env=None):
        """Run the actual workflow heredoc; only its Git network edge is inert."""
        workflow = FILE.parents[2] / '.github/workflows/business-private-replay.yml'
        source = workflow.read_text(encoding='utf8')
        for alias in ('TRUST_JSON', 'TRUST_JSON_PART_2', 'TRUST_JSON_PART_3'):
            self.assertIn(alias + ': ${{ vars.BUSINESS31_' + alias + ' }}', source)
        marker = '      - name: Prepare isolated public Git inputs without checking out candidate code\n'
        self.assertEqual(source.count(marker), 1)
        step = source.split(marker, 1)[1].split('\n      - name:', 1)[0]
        self.assertEqual(step.count("$prepare = @'\n"), 1)
        self.assertEqual(step.count("\n          '@\n"), 1)
        body = textwrap.dedent(step.split("$prepare = @'\n", 1)[1].split("\n          '@\n", 1)[0])
        if legacy:
            trust, request, _, _, selected = self.artifact_fixture()
            trust.update(schemaVersion=1, nodeSha256='A' * 64, gitSha256='B' * 64,
                         launcherSha256='C' * 64, pythonSha256='D' * 64)
        else:
            trust, request, _, _, selected = self.transport_v2_fixture()
        sequence = getattr(self, '_workflow_sequence', 0) + 1
        self._workflow_sequence = sequence
        owned = self.root / ('workflow-' + str(sequence)); owned.mkdir()
        git = Path(os.environ.get('BUSINESS31_TEST_GIT',
                   'C:/Program Files/Git/mingw64/bin/git.exe' if os.name == 'nt' else '/usr/bin/git'))
        trust['gitSha256'] = launcher.digest(git)
        trust['pythonSha256'] = launcher.digest(Path(sys.executable))
        trust['launcherSha256'] = launcher.digest(FILE)
        trust['repository']['name'] = 'fixture/repository'
        if alter:
            alter(trust)
        ordinary = json.dumps(trust, separators=(',', ':'))
        value = raw if raw is not None else ordinary[:1] + (' ' * 60000 if expanded else '') + ordinary[1:]
        width = (len(value) + 2) // 3
        parts = [value[:width], value[width:width * 2], value[width * 2:]] if chunked else [value, '', '']
        if alter_parts:
            alter_parts(parts)
        whole = ''.join(parts).encode('utf8')
        public_message = b'synthetic public workflow carrier message'
        selected['selected']['originalMessage'] = {'sha256': hashlib.sha256(public_message).hexdigest().upper(),
                                                   'bytes': len(public_message)}
        import base64
        env = {key: os.environ[key] for key in ('SystemRoot', 'WINDIR', 'COMSPEC', 'PATH', 'PATHEXT', 'LANG', 'LC_ALL')
               if key in os.environ}
        # The Windows workflow forwards these to its pinned Git; Git itself is inert here.
        for key, value in (('SystemRoot', 'C:\\Windows'), ('WINDIR', 'C:\\Windows'),
                           ('COMSPEC', 'C:\\Windows\\System32\\cmd.exe')):
            env.setdefault(key, value)
        env.update(HOME=str(owned), USERPROFILE=str(owned), TMP=str(owned), TEMP=str(owned), RUNNER_TEMP=str(owned),
                   TRUST_JSON=parts[0], TRUST_JSON_PART_2=parts[1], TRUST_JSON_PART_3=parts[2],
                   TRUST_SHA=expected_hash or hashlib.sha256(whole).hexdigest().upper(),
                   SELECTED_V=trust['verifier']['commit'], PYTHON_SHA=launcher.digest(Path(sys.executable)),
                   LAUNCHER_SHA=launcher.digest(FILE), GIT_EXE=str(git), GITHUB_REPOSITORY='fixture/repository',
                   GITHUB_RUN_ID='42', GITHUB_RUN_ATTEMPT='1', GITHUB_OUTPUT=str(owned / 'github-output.txt'),
                   CANDIDATE_REQUEST=json.dumps({key: request[key] for key in
                       ('schemaVersion', 'candidate', 'descriptorPointer', 'challenge')}),
                   MANIFEST_JSON='{"syntheticPublicSourceManifest":true}',
                   CLIENT_SELECTED_JSON=json.dumps(selected['selected']),
                   CLIENT_ORIGINAL_MESSAGE_B64=base64.b64encode(public_message).decode())
        if alter_env:
            alter_env(env)
        script = owned / 'execute-workflow.py'
        payload = owned / 'workflow-source.json'; payload.write_text(json.dumps({'source': body}), encoding='utf8')
        script.write_text(textwrap.dedent('''\
            import json,os,pathlib,subprocess,sys
            source=json.loads(pathlib.Path(sys.argv[1]).read_bytes())['source']
            calls=[]
            def no_wire_or_child(event,arguments):
                if event in ('socket.__new__','socket.connect','subprocess.Popen'):
                    raise AssertionError('Workflow test forbids real network or external Git execution')
            sys.addaudithook(no_wire_or_child)
            def transport_only_git(argv,**options):
                assert isinstance(argv,list) and argv[0]==os.environ['GIT_EXE']
                assert options['stdin']==subprocess.DEVNULL and options['timeout']==300
                assert 'credential.helper=' in argv and 'protocol.allow=never' in argv
                calls.append(argv)
                if 'clone' in argv:
                    assert argv[-2]=='https://github.com/fixture/repository.git'
                    pathlib.Path(argv[-1]).mkdir()
                else:
                    assert 'fetch' in argv or 'update-ref' in argv
                return subprocess.CompletedProcess(argv,0,b'',b'')
            subprocess.run=transport_only_git
            try:
                exec(compile(source,'actual-business-private-replay-workflow.py','exec'),{})
                result={'ok':True,'gitCalls':len(calls)}
            except Exception as error:
                result={'ok':False,'gitCalls':len(calls),'exceptionType':type(error).__name__,'message':str(error)}
            print(json.dumps(result))
            '''), encoding='utf8')
        run = subprocess.run([sys.executable, '-I', '-S', str(script), str(payload)], env=env,
                             stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=30, check=False)
        (owned / 'stdout.txt').write_bytes(run.stdout); (owned / 'stderr.txt').write_bytes(run.stderr)
        # Retain actual child result streams in the outer test log before cleanup.
        sys.stdout.buffer.write(run.stdout); sys.stdout.buffer.flush()
        if run.stderr:
            sys.stderr.buffer.write(run.stderr); sys.stderr.buffer.flush()
        self.assertEqual(run.returncode, 0, run.stderr.decode('utf8', errors='replace'))
        return json.loads(run.stdout), owned / 'business31-private-job', whole, trust

    def test_actual_workflow_python_raw_v1_raw_v2_and_large_v2_chunks_preserve_whole_bytes(self):
        for options in ({'legacy': True}, {}, {'chunked': True, 'expanded': True}):
            with self.subTest(options=options):
                result, directory, whole, trust = self.workflow_prepare(**options)
                self.assertEqual(result, {'ok': True, 'gitCalls': 3})
                self.assertEqual((directory / 'trust.json').read_bytes(), whole)
                self.assertEqual(json.loads((directory / 'trust.json').read_bytes()), trust)
                if options.get('expanded'):
                    self.assertGreater(len(whole), 48000)  # Transport fixture, not operational enrollment.
                client = json.loads((directory / 'client-input.json').read_bytes())
                self.assertEqual(client['schemaVersion'], 1 if options.get('legacy') else 2)

    def test_actual_workflow_python_refuses_bad_chunks_before_git_or_outputs(self):
        cases = [
            {'alter_parts': lambda p: p.__setitem__(0, '')},
            {'alter_parts': lambda p: p.__setitem__(1, '')},
            {'alter_parts': lambda p: p.__setitem__(2, '')},
            {'alter_parts': lambda p: p.__setitem__(1, '\u6f22' * 16001)},
            {'expected_hash': '0' * 64}, {'legacy': True},
            {'raw': '{"schemaVersion":2,'}, {'raw': '[null,{}]'},
            {'alter': lambda t: t.update(schemaVersion=[2])},
            {'alter': lambda t: t.update(profile=[launcher.PROFILE_V2])},
            {'alter': lambda t: t.update(pythonSha256='0' * 64)},
            {'alter': lambda t: t.update(launcherSha256='0' * 64)},
            {'alter': lambda t: t.update(gitSha256='0' * 64)},
            {'alter': lambda t: t['coreVerifier'].update(commit='0' * 40)}]
        for case in cases:
            with self.subTest(case=case):
                result, directory, _, _ = self.workflow_prepare(chunked=True, **case)
                self.assertFalse(result['ok']); self.assertEqual(result['gitCalls'], 0)
                self.assertFalse((directory / 'trust.json').exists())
                self.assertFalse((directory / 'input.json').exists())
        # The whole SHA is checked before JSON parsing, even for malformed input.
        result, _, _, _ = self.workflow_prepare(chunked=True, raw='malformed-json', expected_hash='0' * 64)
        self.assertEqual(result['exceptionType'], 'RuntimeError')
        result, _, _, _ = self.workflow_prepare(raw='')
        self.assertFalse(result['ok']); self.assertEqual(result['gitCalls'], 0)

    def test_actual_workflow_python_bounds_every_carried_value_below_the_windows_variable_limit(self):
        # Windows carries one environment value only up to 32,767 UTF-16 units, so each value the
        # workflow receives through its environment is bounded at 32,000 UTF-8 bytes, inclusive.
        def first_trust_part(size):
            def alter(parts):
                value = ''.join(parts)
                padded = value[:1] + ' ' * (size - 1) + value[1:]
                middle = size + (len(padded) - size) // 2
                parts[:] = [padded[:size], padded[size:middle], padded[middle:]]
            return alter

        def padded_json(key, size):
            def alter(env):
                value = env[key]
                env[key] = value[:1] + ' ' * (size - len(value.encode('utf8'))) + value[1:]
            return alter

        def original_message(size):
            def alter(env):
                message = b'm' * size
                selected = json.loads(env['CLIENT_SELECTED_JSON'])
                selected['originalMessage'] = {'sha256': hashlib.sha256(message).hexdigest().upper(),
                                               'bytes': len(message)}
                env.update(CLIENT_SELECTED_JSON=json.dumps(selected),
                           CLIENT_ORIGINAL_MESSAGE_B64=base64.b64encode(message).decode())
            return alter

        import base64
        cases = [  # (name, options at the bound, options one step over it, Git calls before refusal)
            ('trust part', {'alter_parts': first_trust_part(32000)}, {'alter_parts': first_trust_part(32001)}, 0),
            ('request', {'alter_env': padded_json('CANDIDATE_REQUEST', 32000)},
             {'alter_env': padded_json('CANDIDATE_REQUEST', 32001)}, 0),
            ('manifest', {'alter_env': padded_json('MANIFEST_JSON', 32000)},
             {'alter_env': padded_json('MANIFEST_JSON', 32001)}, 3),
            ('client selection', {'alter_env': padded_json('CLIENT_SELECTED_JSON', 32000)},
             {'alter_env': padded_json('CLIENT_SELECTED_JSON', 32001)}, 3),
            # 24,000 bytes encode to exactly 32,000 base64 characters; 24,001 bytes to 32,004.
            ('original message', {'alter_env': original_message(24000)},
             {'alter_env': original_message(24001)}, 3)]
        for name, at_bound, over_bound, git_calls in cases:
            with self.subTest(value=name, size='at bound'):
                result, directory, whole, _ = self.workflow_prepare(chunked=True, **at_bound)
                self.assertEqual(result, {'ok': True, 'gitCalls': 3})
                self.assertEqual((directory / 'trust.json').read_bytes(), whole)
            with self.subTest(value=name, size='over bound'):
                result, directory, _, _ = self.workflow_prepare(chunked=True, **over_bound)
                self.assertEqual(result, {'ok': False, 'gitCalls': git_calls,
                                          'exceptionType': 'RuntimeError',
                                          'message': 'Hosted input preparation refused'})
                output = directory.parent / 'github-output.txt'
                self.assertFalse(output.exists() and 'candidate=' in output.read_text(encoding='utf8'))
                if git_calls == 0:
                    self.assertFalse((directory / 'trust.json').exists())

    def test_actual_workflow_python_carries_owner_messages_up_to_128_kib_in_bounded_parts(self):
        # The client pipeline accepts owner messages up to 128 KiB; one carried value holds at most 24,000
        # decoded bytes, so the message may arrive in up to six contiguous parts of at most 32,000 bytes each.
        import base64
        names = ['CLIENT_ORIGINAL_MESSAGE_B64'] + ['CLIENT_ORIGINAL_MESSAGE_B64_PART_%d' % n for n in range(2, 7)]

        def raw(size):
            return bytes((index * 7 + 3) % 251 for index in range(size))

        def message(size, split=32000, layout=None):
            def alter(env):
                body = raw(size)
                selected = json.loads(env['CLIENT_SELECTED_JSON'])
                selected['originalMessage'] = {'sha256': hashlib.sha256(body).hexdigest().upper(), 'bytes': len(body)}
                env['CLIENT_SELECTED_JSON'] = json.dumps(selected)
                encoded = base64.b64encode(body).decode()
                parts = [encoded[at:at + split] for at in range(0, len(encoded), split)]
                if layout:
                    parts = layout(parts)
                self.assertLessEqual(len(parts), len(names))
                for name in names:
                    env.pop(name, None)
                env.update(zip(names, parts))
            return alter

        accepted = [('one part, 3,329 bytes', 3329, {}), ('two parts, 24,001 bytes', 24001, {}),
                    ('six parts, exactly 128 KiB', 128 * 1024, {})]
        for name, size, options in accepted:
            with self.subTest(case=name):
                result, directory, _, _ = self.workflow_prepare(chunked=True, alter_env=message(size, **options))
                self.assertEqual(result, {'ok': True, 'gitCalls': 3})
                self.assertEqual((directory / 'original-client-message.bin').read_bytes(), raw(size))
        refused = [('one part over the carried bound', 24001, {'split': 32001}),
                   ('a gap between parts', 24001, {'layout': lambda p: [p[0], '', p[1]]}),
                   ('an empty first part', 3329, {'layout': lambda p: ['', p[0]]}),
                   ('one byte over 128 KiB', 128 * 1024 + 1, {})]
        for name, size, options in refused:
            with self.subTest(case=name):
                result, directory, _, _ = self.workflow_prepare(chunked=True, alter_env=message(size, **options))
                self.assertEqual(result, {'ok': False, 'gitCalls': 3, 'exceptionType': 'RuntimeError',
                                          'message': 'Hosted input preparation refused'})
                self.assertFalse((directory / 'original-client-message.bin').exists())
                output = directory.parent / 'github-output.txt'
                self.assertFalse(output.exists() and 'candidate=' in output.read_text(encoding='utf8'))

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell 7 is required to execute the workflow step')
    def test_actual_cleanup_step_never_launches_the_enrolled_interpreter(self):
        """The always-run cleanup runs only the job's installed, re-pinned Python; never PYTHON_EXE."""
        workflow = FILE.parents[2] / '.github/workflows/business-private-replay.yml'
        source = workflow.read_text(encoding='utf8')
        marker = '      - name: Destroy owned private scratch\n'
        self.assertEqual(source.count(marker), 1)
        step = source.split(marker, 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('        if: always()\n', step)
        self.assertIn('          INSTALLED_PYTHON: ${{ steps.python.outputs.python-path }}\n', step)
        self.assertNotIn('PYTHON_EXE', step)
        script = self.root / 'cleanup-step.ps1'
        script.write_text(textwrap.dedent(step.split('        run: |\n', 1)[1]), encoding='utf8')
        ran = self.root / 'enrolled-interpreter-ran.txt'
        if os.name == 'nt':
            enrolled = self.root / 'enrolled-python.cmd'
            enrolled.write_text('@echo off\r\necho ran> "' + str(ran) + '"\r\n', encoding='utf8')
        else:
            enrolled = self.root / 'enrolled-python'
            enrolled.write_text('#!/bin/sh\necho ran > "' + str(ran) + '"\n', encoding='utf8')
            enrolled.chmod(0o700)
        pinned = launcher.digest(Path(sys.executable))
        # Windows refuses to delete a read-only file, and Git writes its objects, packs and commit-graph files
        # read-only: hosted run 44933552509 failed its cleanup on the prepared clone's commit-graph-chain.
        self.assertIn('              os.chmod(path,stat.S_IWRITE)\n              function(path)\n', step)
        self.assertIn('              shutil.rmtree(root,onexc=writable)\n', step)

        def run(name, scratch, installed, python_sha, read_only):
            temp = self.root / name; temp.mkdir()
            job = temp / 'business31-private-job'
            if scratch:
                (job / 'repository').mkdir(parents=True); (job / 'trust.json').write_bytes(b'{}')
            if read_only:
                for leaf in ('objects/info/commit-graphs/commit-graph-chain', 'objects/pack/pack-synthetic.pack'):
                    file = job / 'repository/.git' / leaf
                    file.parent.mkdir(parents=True, exist_ok=True); file.write_bytes(b'synthetic'); file.chmod(stat.S_IREAD)
            env = {key: os.environ[key] for key in ('SystemRoot', 'WINDIR', 'COMSPEC', 'PATH', 'PATHEXT', 'HOME',
                                                     'USERPROFILE', 'TEMP', 'TMP', 'LANG', 'LC_ALL') if key in os.environ}
            env.update(RUNNER_TEMP=str(temp), INSTALLED_PYTHON=installed, PYTHON_SHA=python_sha, PYTHON_EXE=str(enrolled))
            result = subprocess.run([shutil.which('pwsh'), '-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
                                     ". '" + str(script) + "'"], env=env, stdin=subprocess.DEVNULL,
                                    capture_output=True, timeout=120, check=False)
            return result.returncode, job.exists()

        cases = [  # (name, scratch exists, installed interpreter, enrolled digest, read-only Git files,
                   #  expected success, scratch left)
            ('nothing-prepared', False, '', pinned, False, True, False),
            ('pinned-cleanup', True, sys.executable, pinned, False, True, False),
            ('read-only-git-files', True, sys.executable, pinned, True, True, False),
            ('installed-not-pinned', True, sys.executable, '0' * 64, False, False, True),
            ('no-installed-python', True, '', pinned, False, False, True)]
        for name, scratch, installed, python_sha, read_only, succeeds, left in cases:
            with self.subTest(case=name):
                code, exists = run(name, scratch, installed, python_sha, read_only)
                self.assertEqual(code == 0, succeeds, name)
                self.assertEqual(exists, left, name)
                self.assertFalse(ran.exists(), 'cleanup launched the enrolled interpreter')

    @unittest.skipUnless(shutil.which('git') and shutil.which('node'), 'Git and Node are required')
    def test_checkout_metadata_cleanup_admits_only_inert_leftovers_to_the_trusted_opener(self):
        """actions/checkout leaves .git/config.worktree and gc.auto=0, and the trusted repository opener refuses both: PR
        428's release gate (run 44953500471) refused its business route on exactly this. Both business-route workflows run
        the same cleanup before their business route; it admits that checkout and refuses every other Git state. In the
        release gate it follows the cheap preflight, which must stay the first step after checkout in every job and does
        not read Git state; in the artifact job it follows the checkout directly."""
        marker = '      - name: Remove inert actions/checkout Git metadata\n'
        scripts = []
        for workflow, leading in (('release-gate.yml', ['Checkout', 'Cheap checked-in source preflight (no install or device)']),
                                  ('production-artifact.yml', ['Validate dispatch inputs', 'Checkout exact commit'])):
            source = (FILE.parents[2] / '.github/workflows' / workflow).read_text(encoding='utf8')
            self.assertEqual(source.count(marker), 1, workflow)
            before, step = source.split(marker, 1)
            job_steps = [line[len('      - name: '):] for line in before.rsplit('\n    steps:\n', 1)[1].split('\n')
                         if line.startswith('      - name: ')]
            self.assertEqual(job_steps, leading, workflow + ': cleanup must follow exactly these steps')
            self.assertIn('\n      - name: Prepare independently enrolled business verifier\n', step,
                          workflow + ': cleanup must precede the business route')
            scripts.append(textwrap.dedent(step.split('\n      - name:', 1)[0].split('        run: |\n', 1)[1]))
        self.assertEqual(scripts[0], scripts[1])
        script = self.root / 'checkout-cleanup.sh'
        script.write_bytes(scripts[0].encode('utf8'))
        git = Path(shutil.which('git')).resolve()
        bundled_bash = git.parents[1] / 'bin' / 'bash.exe'
        bash = str(bundled_bash) if os.name == 'nt' and bundled_bash.is_file() else shutil.which('bash')
        self.assertIsNotNone(bash)
        opener = ("const t=require(process.argv[1]);try{t.openTrustedGitRepository31({repositoryRoot:process.argv[2],"
                  "gitExecutable:process.argv[3],gitSha256:process.argv[4]});process.stdout.write('ADMITTED')}"
                  "catch(e){process.stdout.write('REFUSED '+e.message)}")

        def admitted(repo):
            return subprocess.run([shutil.which('node'), '-e', opener, str(FILE.parent / 'business31TrustedInput.cjs'), str(repo), str(git),
                                   launcher.digest(git)], capture_output=True, text=True, timeout=120).stdout

        def run_git(repo, *args):
            subprocess.run([str(git), *args], cwd=repo, check=True, capture_output=True, timeout=120)

        def repository(name, checkout=True, unset_worktree=True):
            repo = self.root / name
            subprocess.run([str(git), 'init', '-q', str(repo)], check=True, capture_output=True, timeout=120)
            run_git(repo, '-c', 'user.email=build31@example.invalid', '-c', 'user.name=build31', 'commit', '-q', '--allow-empty', '-m', 'i')
            run_git(repo, 'remote', 'add', 'origin', 'https://github.com/abhishekvatsa/crm3_baf_ops')
            if checkout:  # exactly what actions/checkout leaves: gc.auto=0, then sparse-checkout disable + unset extension
                run_git(repo, 'config', '--local', 'gc.auto', '0')
                run_git(repo, 'sparse-checkout', 'disable')
                if unset_worktree:
                    run_git(repo, 'config', '--local', '--unset-all', 'extensions.worktreeConfig')
            return repo

        def clean(repo):
            return subprocess.run([bash, str(script)], cwd=repo, capture_output=True, text=True, timeout=120).returncode

        checkout = repository('checkout')
        self.assertTrue((checkout / '.git/config.worktree').is_file())
        self.assertEqual(admitted(checkout), 'REFUSED External or incomplete Git state refused')
        self.assertEqual(clean(checkout), 0)
        self.assertFalse((checkout / '.git/config.worktree').exists())
        self.assertEqual(admitted(checkout), 'ADMITTED')
        pristine = repository('pristine', checkout=False)
        self.assertEqual((clean(pristine), admitted(pristine)), (0, 'ADMITTED'))
        enabled = repository('worktree-config-enabled', unset_worktree=False)
        self.assertEqual(clean(enabled), 1)
        self.assertTrue((enabled / '.git/config.worktree').is_file())
        for name, key, value in (('foreign-config', 'core.hooksPath', 'hooks'), ('other-gc', 'gc.reflogExpire', 'never'),
                                 ('include', 'include.path', 'other.config')):
            with self.subTest(case=name):
                repo = repository(name)
                run_git(repo, 'config', '--local', key, value)
                self.assertEqual(clean(repo), 1, name)
                self.assertTrue(admitted(repo).startswith('REFUSED'), name)

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell 7 is required to execute the workflow step')
    def test_actual_gate_step_binds_the_node_that_runs_when_the_image_ships_another(self):
        """The hosted image has its own Node on PATH besides the pinned one (hosted run 44918864165 died here):
        the gate must bind exactly the first node on PATH, the one that runs, and still refuse any other."""
        workflow = FILE.parents[2] / '.github/workflows/business-private-replay.yml'
        source = workflow.read_text(encoding='utf8')
        marker = '      - name: Require independently selected immutable workflow revision\n'
        self.assertEqual(source.count(marker), 1)
        step = source.split(marker, 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('          INSTALLED_PYTHON: ${{ steps.python.outputs.python-path }}\n', step)
        script = self.root / 'gate-step.ps1'
        script.write_text(textwrap.dedent(step.split('        run: |\n', 1)[1]), encoding='utf8')
        pwsh = shutil.which('pwsh')
        base = {key: os.environ[key] for key in ('SystemRoot', 'WINDIR', 'COMSPEC', 'PATHEXT', 'HOME',
                                                 'USERPROFILE', 'TEMP', 'TMP', 'LANG', 'LC_ALL') if key in os.environ}
        nodes = []
        for name in ('pinned-node', 'image-node'):
            directory = self.root / name
            directory.mkdir()
            node = directory / ('node.exe' if os.name == 'nt' else 'node')
            node.write_bytes(b'never executed by the gate\n')
            node.chmod(0o700)
            nodes.append(node)
        runner_temp = self.root / 'runner-temp'
        runner_temp.mkdir()
        # The pinned MinGit location exactly as PowerShell itself joins and resolves it on this platform.
        created = subprocess.run([pwsh, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
                                  "$p = Join-Path $env:RUNNER_TEMP 'business31-mingit\\ucrt64\\bin\\git.exe'; "
                                  "New-Item -ItemType File -Force -Path $p | Out-Null; [IO.Path]::GetFullPath($p)"],
                                 env=dict(base, PATH=os.environ.get('PATH', ''), RUNNER_TEMP=str(runner_temp)),
                                 stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120, check=True)
        git = created.stdout.strip()
        python = self.root / 'installed-python'
        python.write_bytes(b'pinned interpreter bytes\n')
        digest = launcher.digest(python)

        def gate(node_exe, path_nodes, python_sha):
            env = dict(base, PATH=os.pathsep.join([str(n.parent) for n in path_nodes] + [os.environ.get('PATH', '')]),
                       SELECTED_V='a' * 40, GITHUB_SHA='a' * 40, GITHUB_REF='refs/tags/build31-business-verifier-test',
                       PYTHON_EXE=str(python), INSTALLED_PYTHON=str(python), PYTHON_SHA=python_sha, LAUNCHER_SHA='B' * 64,
                       NODE_EXE=str(node_exe), GIT_EXE=git, RUNNER_TEMP=str(runner_temp))
            result = subprocess.run([pwsh, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', ". '" + str(script) + "'"],
                                    env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=120, check=False)
            return result.returncode

        pinned, image = nodes
        cases = [  # (name, enrolled node, nodes on PATH in order, enrolled Python digest, expected success)
            ('pinned-first-image-second', pinned, [pinned, image], digest, True),
            ('pinned-alone', pinned, [pinned], digest, True),
            ('enrolled-node-is-not-the-one-that-runs', image, [pinned, image], digest, False),
            ('python-digest-differs', pinned, [pinned, image], '0' * 64, False)]
        for name, node_exe, path_nodes, python_sha, succeeds in cases:
            with self.subTest(case=name):
                self.assertEqual(gate(node_exe, path_nodes, python_sha) == 0, succeeds, name)

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

    def staged_child(self, argv, env, owned, verifier_files=None):
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



class DiagnosticFailures(unittest.TestCase):
    """Offline synthetic diagnostics only; no bundle, credential or hosted replay."""
    NODE = os.environ.get('BUSINESS31_TEST_NODE') or shutil.which('node')

    def setUp(self):
        self.assertIsNotNone(self.NODE, 'Node is required for offline diagnostic tests')
        self.temp = tempfile.TemporaryDirectory(prefix='b31-diag-')
        self.root = Path(self.temp.name)
        self.parent = self.root / 'private'; self.parent.mkdir()
        self.output = self.root / 'business31-hosted-result.json'
        self.input = self.root / 'input.json'
        self.input.write_text(json.dumps({'request': {}, 'repositoryRoot': 'synthetic',
                                         'gitExecutable': 'synthetic', 'sourceManifest': {}}), encoding='utf-8')
        self.trust = self.root / 'trust.json'; self.trust.write_text('{}', encoding='utf-8')
        self.args = SimpleNamespace(mode='replay', private_parent=str(self.parent), output=str(self.output),
                                    input=str(self.input), node='synthetic', trust=str(self.trust),
                                    trust_sha256='A' * 64, client_input=None, client_input_sha256=None)
        launcher._reset_failure()

    def tearDown(self):
        self.temp.cleanup()

    def safe_env(self):
        return {k: os.environ[k] for k in ('SystemRoot', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP', 'LANG', 'LC_ALL')
                if k in os.environ}

    def native(self, argv):
        result = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, env=self.safe_env(), timeout=30)
        self.assertLessEqual(len(result.stdout), 65536)
        self.assertLessEqual(len(result.stderr), 65536)
        return result

    def node_script(self, source, *args):
        return self.native([str(self.NODE), '--no-global-search-paths', '-e', source, *map(str, args)])

    @staticmethod
    def record(stage='STS', reason='STS_RESULT', **extra):
        return dict(schemaVersion=1, stage=stage, reason=reason, nativeCode=None,
                    workerExit=None, workerSignal=None, workerCleanupFailed=False,
                    cleanupFailed=False, **extra)

    @staticmethod
    def wire(value):
        return (b'Business hosted replay failed; no result is admissible. ' +
                json.dumps(value, separators=(',', ':')).encode() + b'\n')

    def outer(self):
        raw = launcher._failure_line()
        self.assertLessEqual(len(raw), 512)
        return json.loads(raw.split(b'. ', 1)[1])

    def test_exact_public_refusal_and_unknown_private_text(self):
        for text, expected in [('BUSINESS_HOSTED_NODE_IDENTITY', 'NODE_IDENTITY'),
                               ('BUSINESS_HOSTED_NODE_IDENTITY /private/TOKEN_SENTINEL', 'UNCLASSIFIED'),
                               ('private-path TOKEN_SENTINEL https://private.invalid body stack', 'UNCLASSIFIED')]:
            with self.subTest(expected=expected):
                launcher._reset_failure(); launcher._phase('LAUNCH_PLAN')
                launcher._remember_failure(ValueError(text))
                self.assertEqual(self.outer()['reason'], expected)
                self.assertNotIn(b'TOKEN_SENTINEL', launcher._failure_line())
                self.assertNotIn(b'private.invalid', launcher._failure_line())

    def test_closed_child_record_and_bounded_exit_signal(self):
        value = self.record(); value.update(workerExit=1, workerSignal='SIGKILL', workerCleanupFailed=True)
        launcher._remember_child_record(self.wire(value)); launcher._child_exit(1)
        out = self.outer()
        self.assertEqual((out['stage'], out['reason'], out['childExit'], out['workerExit']), ('STS', 'STS_RESULT', 1, 1))
        self.assertEqual(out['workerSignal'], 'SIGKILL'); self.assertTrue(out['workerCleanupFailed'])
        launcher._child_exit(-9)
        self.assertIsNone(self.outer()['childExit']); self.assertEqual(self.outer()['childSignal'], 9)
        for bad in (True, -128, 4294967296, '1'):
            launcher._reset_failure(); launcher._child_exit(bad)
            self.assertIsNone(self.outer()['childExit']); self.assertIsNone(self.outer()['childSignal'])

    def test_invalid_child_records_do_not_escape(self):
        valid = self.record()
        variants = [b'private TOKEN_SENTINEL', self.wire(valid) + b'EXTRA', b'x' * 513,
                    self.wire(dict(valid, stage=['STS'])), self.wire(dict(valid, reason='STS_RESULT TOKEN_SENTINEL')),
                    self.wire(dict(valid, extra='TOKEN_SENTINEL')), self.wire(dict(valid, workerExit=True)),
                    self.wire(dict(valid, workerExit=-1)), self.wire(dict(valid, workerSignal='TOKEN_SENTINEL')),
                    self.wire(dict(valid, nativeCode=['ENOENT'])), self.wire(dict(valid, cleanupFailed=1)),
                    self.wire(valid).replace(b'{"schemaVersion":1,', b'{"schemaVersion":1,"schemaVersion":1,')]
        for raw in variants:
            with self.subTest(raw_bytes=len(raw)):
                launcher._reset_failure(); launcher._remember_child_record(raw)
                self.assertIsNone(launcher._FAILURE['primary'])
                self.assertNotIn(b'TOKEN_SENTINEL', launcher._failure_line())

    def test_maximum_fixed_record_remains_bounded(self):
        value = self.record(stage=max(launcher._NODE_STAGES, key=len), reason=max(launcher._NODE_REASONS, key=len))
        value.update(nativeCode=max(launcher._NATIVE_CODES, key=len), workerExit=4294967295,
                     workerSignal=max(launcher._SIGNALS, key=len), workerCleanupFailed=True, cleanupFailed=True)
        launcher._remember_child_record(self.wire(value)); launcher._child_exit(4294967295)
        launcher._FAILURE['cleanupFailed'] = True
        self.assertLessEqual(len(launcher._failure_line()), 512)
        self.assertEqual(self.outer()['reason'], value['reason'])

    def run_synthetic(self, *, plan_error=None, child_error=None, sanitizer_error=None, cleanup_error=False):
        native_temp = tempfile.TemporaryDirectory
        class Owned:
            def __init__(self, **kwargs): self.actual = native_temp(**kwargs)
            def __enter__(self): return self.actual.__enter__()
            def __exit__(self, *exc):
                answer = self.actual.__exit__(*exc)
                if cleanup_error: raise OSError('TOKEN_SENTINEL cleanup private path')
                return answer
        def child(argv, env, owned, verifier_files=None):
            if child_error: raise child_error
            launcher._child_exit(0)
            (Path(owned) / 'business31-hosted-result.json').write_bytes(b'{"synthetic":true}\n')
            return b'', b''
        with patch.object(sys, 'platform', 'linux'), patch.object(launcher.tempfile, 'TemporaryDirectory', Owned), \
             patch.object(launcher, 'launch_plan', side_effect=plan_error, return_value=([], {})), \
             patch.object(launcher, 'run_child', side_effect=child), \
             patch.object(launcher, 'sanitized_replay_output', side_effect=sanitizer_error or (lambda raw, *unused: raw)):
            try:
                launcher.execute_launch(self.args)
            except BaseException as error:
                launcher._remember_failure(error)
                return error
        return None

    def test_plan_failure_is_specific_and_cleanup_precedes_refusal(self):
        self.assertIsNotNone(self.run_synthetic(plan_error=ValueError('BUSINESS_HOSTED_NODE_IDENTITY')))
        self.assertEqual((self.outer()['stage'], self.outer()['reason']), ('LAUNCH_PLAN', 'NODE_IDENTITY'))
        self.assertFalse(self.output.exists()); self.assertEqual(list(self.parent.iterdir()), [])

    def test_primary_child_failure_survives_cleanup_failure(self):
        self.assertIsNotNone(self.run_synthetic(child_error=ValueError('BUSINESS_HOSTED_CHILD_TIMEOUT'), cleanup_error=True))
        out = self.outer(); self.assertEqual((out['stage'], out['reason']), ('CHILD_EXECUTION', 'CHILD_TIMEOUT'))
        self.assertTrue(out['cleanupFailed']); self.assertNotIn(b'TOKEN_SENTINEL', launcher._failure_line())
        self.assertFalse(self.output.exists()); self.assertEqual(list(self.parent.iterdir()), [])

    def test_sanitizer_and_cleanup_failure_never_publish(self):
        self.assertIsNotNone(self.run_synthetic(sanitizer_error=ValueError('BUSINESS_HOSTED_REPLAY_OUTPUT_FIELDS')))
        self.assertEqual((self.outer()['stage'], self.outer()['reason'], self.outer()['childExit']),
                         ('RESULT_SANITIZATION', 'REPLAY_OUTPUT_FIELDS', 0))
        self.assertFalse(self.output.exists())
        self.assertIsNotNone(self.run_synthetic(cleanup_error=True))
        self.assertEqual((self.outer()['stage'], self.outer()['reason']), ('PRIVATE_CLEANUP', 'NATIVE_FAILURE'))
        self.assertTrue(self.outer()['cleanupFailed']); self.assertFalse(self.output.exists())

    def test_success_still_publishes_only_after_cleanup(self):
        self.assertIsNone(self.run_synthetic())
        self.assertEqual(self.output.read_bytes(), b'{"synthetic":true}\n')
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_real_python_cli_never_echoes_argument_or_stack(self):
        result = self.native([sys.executable, '-I', '-S', '-B', str(FILE), '--TOKEN_SENTINEL=/private/token'])
        self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout, b'')
        self.assertLessEqual(len(result.stderr), 512); self.assertNotIn(b'TOKEN_SENTINEL', result.stderr)
        self.assertNotIn(b'Traceback', result.stderr)
        self.assertEqual(json.loads(result.stderr.split(b'. ', 1)[1])['reason'], 'CLI')

    def test_real_fresh_node_entry_refuses_with_closed_code(self):
        result = self.native([str(self.NODE), '--no-global-search-paths', str(FILE.with_name('business31HostedReplay.cjs'))])
        self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout, b'')
        value = json.loads(result.stderr.split(b'. ', 1)[1])
        self.assertEqual((value['stage'], value['reason']), ('ENTRY_INPUT', 'CLI'))
        launcher._remember_child_record(result.stderr)
        self.assertEqual(self.outer()['reason'], 'CLI')

    def test_actual_tiny_worker_parent_reporter_python_chain(self):
        source = r'''
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=process.argv[1],owned=process.argv[2],cleanupFailure=process.argv[3]==='true';
const api=require(path.join(root,'business31OriginalPathReplayV2.cjs'));
const actualRead=fs.readFileSync,actualUnlink=fs.unlinkSync;
const binding=Buffer.from('synthetic node identity for the parent unit seam');
fs.readFileSync=function(file,...args){return file===process.execPath?binding:actualRead.call(fs,file,...args);};
if(cleanupFailure)fs.unlinkSync=function(file){if(path.basename(file).startsWith('.business31-core-'))throw Error('TOKEN_SENTINEL cleanup');return actualUnlink(file);};
let failure;try{api.invokeCoreWorker31({workerFile:path.join(root,'business31CoreWorkerV2.cjs'),input:{},ownedDirectory:owned,nodeSha256:crypto.createHash('sha256').update(binding).digest('hex').toUpperCase()});}
catch(error){failure=error.business31Diagnostic;}
if(!failure)throw Error('Expected synthetic closed-input refusal');
const source=actualRead(path.join(root,'business31HostedReplay.cjs'),'utf8');
const code=source.slice(source.indexOf('// Fixed failure metadata only.'),source.indexOf('function measureClient31('));
let output='';const context=vm.createContext({Buffer,fs:{writeSync:(_fd,text)=>{output+=text;return Buffer.byteLength(text);}},process:{stderr:{write:x=>output+=x},exitCode:0}});
vm.runInContext(code+'\nconst synthetic=Error("TOKEN_SENTINEL outer");Object.defineProperty(synthetic,"business31Diagnostic",{value:JSON.parse('+JSON.stringify(JSON.stringify(failure))+')});reportFailure(synthetic);',context);
process.stdout.write(JSON.stringify({failure,wire:output,inputFiles:fs.readdirSync(owned).filter(x=>x.startsWith('.business31-core-'))}));
'''
        for cleanup in (False, True):
            with self.subTest(cleanup=cleanup):
                owned = self.root / ('worker-' + str(cleanup)); owned.mkdir()
                result = self.node_script(source, FILE.parent, owned, str(cleanup).lower())
                self.assertEqual(result.returncode, 0, result.stderr.decode())
                out = json.loads(result.stdout); value = out['failure']
                self.assertEqual((value['stage'], value['reason'], value['workerExit']),
                                 ('WORKER_INPUT', 'WORKER_CLOSED_WORKER_INPUT_REQUIRED', 1))
                self.assertEqual(value['workerCleanupFailed'], cleanup)
                self.assertEqual(len(out['inputFiles']), 1 if cleanup else 0)
                self.assertNotIn('TOKEN_SENTINEL', out['wire'])
                launcher._reset_failure(); launcher._remember_child_record(out['wire'].encode())
                self.assertEqual(self.outer()['stage'], 'WORKER_INPUT')
                self.assertEqual(self.outer()['workerExit'], 1)
                self.assertEqual(self.outer()['workerCleanupFailed'], cleanup)

    def test_worker_exact_public_code_and_near_prefix_suppression(self):
        source = r'''
const fs=require('node:fs'),vm=require('node:vm');const source=fs.readFileSync(process.argv[1],'utf8');
const code=source.slice(source.indexOf('// Only fixed public refusal identifiers'),source.indexOf('function canonical('));
let output='';const context=vm.createContext({Buffer,fs:{writeSync:(_fd,text)=>{output+=text;return Buffer.byteLength(text);}},process:{stderr:{write:x=>output+=x},exitCode:0}});
vm.runInContext(code+'\nreportFailure(Error('+JSON.stringify(process.argv[2])+'));',context);process.stdout.write(output);
'''
        for message, reason in [('Business31 preparation: explicit UTC required', 'M_REFUSAL_001'),
                                ('Business31 preparation: explicit UTC required TOKEN_SENTINEL', 'UNCLASSIFIED')]:
            result = self.node_script(source, FILE.with_name('business31CoreWorkerV2.cjs'), message)
            self.assertEqual(result.returncode, 0); self.assertEqual(result.stderr, b'')
            self.assertNotIn(b'TOKEN_SENTINEL', result.stdout); self.assertLessEqual(len(result.stdout), 512)
            self.assertEqual(json.loads(result.stdout.split(b' ', 1)[1])['reason'], reason)


    def synthetic_run_child(self, code=1, stderr=b'', cleanup_error=False, timeout=False, stdout=b''):
        # Execute production runner logic with deterministic pipe/session adapters.
        # This does not qualify native POSIX selectors or process groups on Windows.
        class Stream:
            def __init__(self, fd): self.fd = fd
            def fileno(self): return self.fd
            def close(self): pass
        class Child:
            stdout = Stream(1); stderr = Stream(2); pid = 123
            def wait(self, **unused): return code
        child = Child(); chunks = {1: [stdout, b''] if stdout else [b''], 2: [stderr, b''] if stderr else [b'']}
        class Selector:
            def __init__(self): self.items = {}
            def __enter__(self): return self
            def __exit__(self, *unused): pass
            def register(self, stream, event): self.items[stream] = event
            def unregister(self, stream): del self.items[stream]
            def get_map(self): return self.items
            def select(self, **unused): return [(SimpleNamespace(fileobj=next(iter(self.items))), None)]
        launcher._reset_failure(); launcher._phase('CHILD_EXECUTION')
        directory = self.root / ('runner-' + str(len(list(self.root.iterdir())))); directory.mkdir()
        def kill(*unused):
            if cleanup_error: raise OSError('TOKEN_SENTINEL kill')
        clock = patch.object(launcher.time, 'monotonic', side_effect=[0, 7201]) if timeout else patch.object(launcher.time, 'monotonic', return_value=1)
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(launcher.subprocess, 'Popen', return_value=child), \
             patch.object(launcher.selectors, 'DefaultSelector', Selector), \
             patch.object(launcher.os, 'read', side_effect=lambda fd, limit: chunks[fd].pop(0)), \
             patch.object(launcher.os, 'killpg', side_effect=kill, create=True), \
             patch.object(launcher.signal, 'SIGKILL', 9, create=True), clock:
            try:
                return launcher.run_child([], {}, directory), None
            except BaseException as error:
                launcher._remember_failure(error)
                return None, error

    def test_runner_failure_record_exit_and_primary_cleanup(self):
        wire = self.wire(self.record())
        _, error = self.synthetic_run_child(stderr=wire, cleanup_error=True)
        self.assertIsNotNone(error)
        out = self.outer()
        self.assertEqual((out['stage'], out['reason'], out['childExit']), ('STS', 'STS_RESULT', 1))
        self.assertTrue(out['cleanupFailed']); self.assertNotIn(b'TOKEN_SENTINEL', launcher._failure_line())
        _, error = self.synthetic_run_child(code=-9)
        self.assertIsNotNone(error); self.assertEqual(self.outer()['childSignal'], 9)
        self.assertEqual(self.outer()['reason'], 'CHILD_FAILURE')

    def test_runner_timeout_output_bound_and_clean_success(self):
        _, error = self.synthetic_run_child(code=-9, timeout=True)
        self.assertIsNotNone(error); self.assertEqual(self.outer()['reason'], 'CHILD_TIMEOUT')
        self.assertEqual(self.outer()['childSignal'], 9)
        _, error = self.synthetic_run_child(stdout=b'x' * (1024 * 1024 + 1))
        self.assertIsNotNone(error); self.assertEqual(self.outer()['reason'], 'CHILD_OUTPUT_BOUND')
        value, error = self.synthetic_run_child(code=0)
        self.assertIsNone(error); self.assertEqual(value, (b'', b''))
        self.assertEqual(self.outer()['childExit'], 0)

    WINDOWS_SUCCESS = dict(status='SUCCESS', exitCode=0, treeComplete=True, outputComplete=True,
                           jobAssigned=True, cleanupErrors=[], failure=None)

    def windows_child(self, result, stdout=b'', stderr=b''):
        # Production Windows dispatch with a stub owned-process supervisor result.
        calls = []

        class Supervisor:
            @staticmethod
            def run_owned_process(**kwargs):
                calls.append(kwargs)
                target = Path(kwargs['output_directory']); target.mkdir()
                (target / 'stdout.bin').write_bytes(stdout); (target / 'stderr.bin').write_bytes(stderr)
                return dict(result)
        launcher._reset_failure(); launcher._phase('CHILD_EXECUTION')
        directory = self.root / ('win-runner-' + str(len(list(self.root.iterdir())))); directory.mkdir()
        with patch.object(sys, 'platform', 'win32'), \
             patch.object(launcher, '_windows_supervisor', return_value=Supervisor):
            try:
                return launcher.run_child(['node.exe', 'entry.cjs'], {'PATH': 'synthetic'}, directory, {}), calls, None
            except BaseException as error:
                launcher._remember_failure(error)
                return None, calls, error

    def test_windows_runner_maps_owned_process_results(self):
        value, calls, error = self.windows_child(self.WINDOWS_SUCCESS, stdout=b'out')
        self.assertIsNone(error); self.assertEqual(value, (b'out', b''))
        call = calls[0]
        self.assertEqual((call['executable'], call['arguments'], call['timeout_seconds'], call['max_output_bytes'],
                          call['environment']), ('node.exe', ['entry.cjs'], 3600, 1024 * 1024, {'PATH': 'synthetic'}))
        self.assertEqual(self.outer()['childExit'], 0)
        _, _, error = self.windows_child(dict(self.WINDOWS_SUCCESS, status='FAILED', exitCode=1, failure='timeout'))
        self.assertIsNotNone(error); self.assertEqual(self.outer()['reason'], 'CHILD_TIMEOUT')
        _, _, error = self.windows_child(dict(self.WINDOWS_SUCCESS, status='FAILED', failure='output-bound-exceeded'))
        self.assertIsNotNone(error); self.assertEqual(self.outer()['reason'], 'CHILD_OUTPUT_BOUND')
        _, _, error = self.windows_child(dict(self.WINDOWS_SUCCESS, status='FAILED', exitCode=1, failure='nonzero-root-exit'),
                                         stderr=self.wire(self.record()))
        out = self.outer()
        self.assertIsNotNone(error); self.assertEqual((out['stage'], out['reason'], out['childExit']), ('STS', 'STS_RESULT', 1))
        _, _, error = self.windows_child(dict(self.WINDOWS_SUCCESS, status='FAILED', failure='cleanup-incomplete',
                                              cleanupErrors=[{'operation': 'pipe-drain'}]))
        out = self.outer()
        self.assertIsNotNone(error); self.assertTrue(out['cleanupFailed']); self.assertEqual(out['reason'], 'CHILD_FAILURE')
        _, _, error = self.windows_child(dict(self.WINDOWS_SUCCESS, treeComplete=False))
        self.assertIsNotNone(error); self.assertEqual(self.outer()['reason'], 'CHILD_FAILURE')

    def test_windows_child_bound_is_the_supervisor_maximum_and_covers_the_core_worker_bound(self):
        # One hosted replay child runs the recorded core worker plus three admissions and client checks.
        # The unchanged recorded supervisor caps any owned process at 3600 s.
        supervisor = FILE.with_name('runtime_supervisor.py').read_text(encoding='utf8')
        self.assertIn('0 < timeout_seconds <= 3600', supervisor)
        self.assertEqual(launcher.WINDOWS_CHILD_SECONDS, 3600)
        replay = FILE.with_name('business31OriginalPathReplayV2.cjs').read_text(encoding='utf8')
        self.assertIn('const WORKER_TIMEOUT_MS=30*60*1000;', replay)
        self.assertGreaterEqual(launcher.WINDOWS_CHILD_SECONDS, 2 * 30 * 60)

    def test_windows_supervisor_requires_trust_pinned_producer(self):
        name = 'tools/release/runtime_supervisor.py'
        actual = hashlib.sha256(FILE.with_name('runtime_supervisor.py').read_bytes()).hexdigest().upper()
        for files in (None, {}, {name: '0' * 64}):
            with self.assertRaisesRegex(ValueError, 'BUSINESS_HOSTED_WINDOWS_SUPERVISOR_PRODUCER'):
                launcher._windows_supervisor(files)
        if os.name == 'nt':
            self.assertTrue(callable(launcher._windows_supervisor({name: actual}).run_owned_process))

    def test_protected_runner_platform_gate_and_windows_trust_rebinding(self):
        with patch.object(sys, 'platform', 'darwin'):
            try:
                launcher.execute_launch(self.args); error = None
            except BaseException as caught:
                error = caught; launcher._remember_failure(caught)
        self.assertIsInstance(error, ValueError)
        self.assertEqual((self.outer()['stage'], self.outer()['reason']), ('INPUT_STAGING', 'PROTECTED_HOSTED_RUNNER_REQUIRED'))
        # On Windows the selected trust commitment is re-measured before the supervisor is selected.
        launcher._reset_failure()
        with patch.object(sys, 'platform', 'win32'), \
             patch.object(launcher, 'launch_plan', return_value=([], {})), \
             patch.object(launcher, '_run_child_windows', side_effect=AssertionError('child must not start')):
            try:
                launcher.execute_launch(self.args); error = None
            except BaseException as caught:
                error = caught; launcher._remember_failure(caught)
        self.assertIsInstance(error, ValueError)
        self.assertEqual((self.outer()['stage'], self.outer()['reason']), ('CHILD_EXECUTION', 'EXTERNAL_CONFIG_COMMITMENT'))
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(os.name == 'nt', 'Windows owned-process supervisor')
    def test_windows_real_owned_child_success_and_bounded_failure(self):
        name = 'tools/release/runtime_supervisor.py'
        files = {name: hashlib.sha256(FILE.with_name('runtime_supervisor.py').read_bytes()).hexdigest().upper()}
        env = {k: os.environ[k] for k in ('SystemRoot', 'WINDIR', 'COMSPEC') if k in os.environ}
        launcher._reset_failure(); launcher._phase('CHILD_EXECUTION')
        owned = self.root / 'win-real-ok'; owned.mkdir()
        with patch.object(sys, 'platform', 'win32'):
            value = launcher.run_child([sys.executable, '-I', '-S', '-c', "import sys; sys.stdout.write('owned-ok')"],
                                       env, owned, files)
        self.assertEqual(value, (b'owned-ok', b''))
        launcher._reset_failure(); launcher._phase('CHILD_EXECUTION')
        owned = self.root / 'win-real-fail'; owned.mkdir()
        code = 'import sys; sys.stderr.buffer.write(' + repr(self.wire(self.record())) + '); sys.exit(3)'
        with patch.object(sys, 'platform', 'win32'), self.assertRaisesRegex(ValueError, 'BUSINESS_HOSTED_CHILD_FAILURE'):
            try:
                launcher.run_child([sys.executable, '-I', '-S', '-c', code], env, owned, files)
            except BaseException as error:
                launcher._remember_failure(error); raise
        out = self.outer()
        self.assertEqual((out['stage'], out['reason'], out['childExit']), ('STS', 'STS_RESULT', 3))

    def test_real_node_native_failure_never_exposes_missing_path(self):
        absent = self.root / 'TOKEN_SENTINEL-absent-trust.json'
        result = self.native([str(self.NODE), '--no-global-search-paths', str(FILE.with_name('business31HostedReplay.cjs')),
                              '--trust', str(absent), '--trust-sha256', 'A' * 64,
                              '--request', str(self.input), '--output', str(self.output)])
        self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout, b'')
        self.assertNotIn(b'TOKEN_SENTINEL', result.stderr); self.assertNotIn(b'Error:', result.stderr)
        value = json.loads(result.stderr.split(b'. ', 1)[1])
        self.assertEqual((value['stage'], value['reason'], value['nativeCode']), ('ENTRY_INPUT', 'NATIVE_FAILURE', 'ENOENT'))

    def test_parent_native_status_signal_and_code_are_finite(self):
        source = r'''
const Module=require('node:module'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=process.argv[1],owned=process.argv[2],scenario=JSON.parse(process.argv[3]);
const originalLoad=Module._load;Module._load=function(name,...rest){if(name==='node:child_process')return{spawnSync:()=>({status:scenario.status,signal:scenario.signal,error:scenario.code?{code:scenario.code,message:'TOKEN_SENTINEL native'}:undefined,stdout:Buffer.alloc(0),stderr:Buffer.from('TOKEN_SENTINEL raw')})};return originalLoad.call(this,name,...rest);};
const api=require(path.join(root,'business31OriginalPathReplayV2.cjs')),actualRead=fs.readFileSync,binding=Buffer.from('synthetic binding');
fs.readFileSync=function(file,...args){return file===process.execPath?binding:actualRead.call(fs,file,...args);};
try{api.invokeCoreWorker31({workerFile:'inert-never-spawned',input:{},ownedDirectory:owned,nodeSha256:crypto.createHash('sha256').update(binding).digest('hex').toUpperCase()});}catch(error){process.stdout.write(JSON.stringify(error.business31Diagnostic));}
'''
        for index, scenario in enumerate([dict(status=None, signal=None, code='ETIMEDOUT'),
                                          dict(status=42, signal='SIGKILL', code=None),
                                          dict(status=True, signal='TOKEN_SENTINEL', code='TOKEN_SENTINEL')]):
            with self.subTest(index=index):
                owned = self.root / ('native-' + str(index)); owned.mkdir()
                result = self.node_script(source, FILE.parent, owned, json.dumps(scenario))
                self.assertEqual(result.returncode, 0, result.stderr.decode()); self.assertEqual(result.stderr, b'')
                self.assertNotIn(b'TOKEN_SENTINEL', result.stdout)
                value = json.loads(result.stdout)
                self.assertEqual(value['workerExit'], 42 if index == 1 else None)
                self.assertEqual(value['workerSignal'], 'SIGKILL' if index == 1 else None)
                self.assertEqual(value['nativeCode'], 'ETIMEDOUT' if index == 0 else None)
                self.assertEqual(list(owned.iterdir()), [])


    def test_python_native_errno_is_fixed_and_message_suppressed(self):
        launcher._phase('RESULT_PUBLICATION')
        launcher._remember_failure(FileNotFoundError(2, 'TOKEN_SENTINEL private path'))
        self.assertEqual((self.outer()['reason'], self.outer()['nativeCode']), ('NATIVE_FAILURE', 'ENOENT'))
        self.assertNotIn(b'TOKEN_SENTINEL', launcher._failure_line())


    def test_total_node_reporters_use_single_data_snapshots(self):
        source = r'''
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const file=process.argv[1],kind=process.argv[2],scenario=process.argv[3],source=fs.readFileSync(file,'utf8');
const begin=kind==='worker'?'// Only fixed public refusal identifiers':'// Fixed failure metadata only.';
const end=kind==='worker'?'function canonical(':'function measureClient31(';
const code=source.slice(source.indexOf(begin),source.indexOf(end));let output='';
const context=vm.createContext({Buffer,fs:{writeSync:(_fd,text)=>{output+=text;return Buffer.byteLength(text);}},process:{exitCode:0}});
vm.runInContext(code,context);
const known=kind==='worker'?'Business core worker v2: exact input binding required':'BUSINESS_HOSTED_CLI';
const setup={
 alternating:'let calls=0;const incoming=Error('+JSON.stringify(known)+');Object.defineProperty(incoming,"code",{get(){calls++;return calls===1?"ENOENT":"TOKEN_SENTINEL";}});',
 getter:'let calls=0;const incoming=Error("unused");Object.defineProperty(incoming,"message",{get(){calls++;throw Error("TOKEN_SENTINEL getter");}});',
 proxy:'let calls=0;const incoming=new Proxy(Error("unused"),{getOwnPropertyDescriptor(){calls++;throw Error("TOKEN_SENTINEL proxy");}});',
 nested:'let calls=0;const incoming=Error("unused");Object.defineProperty(incoming,"business31Diagnostic",{value:new Proxy({},{getPrototypeOf(){calls++;throw Error("TOKEN_SENTINEL prototype");}})});',
 frozen:'let calls=0;const incoming=Object.freeze(Error('+JSON.stringify(known)+'));',
 null:'let calls=0;const incoming=null;',
 primitive:'let calls=0;const incoming="TOKEN_SENTINEL nonerror";',
 serialization:'let calls=0;const incoming=Error('+JSON.stringify(known)+');JSON.stringify=()=>{throw Error("TOKEN_SENTINEL serialization");};'
};
vm.runInContext(setup[scenario]+'reportFailure(incoming);globalThis.callCount=calls;',context);
process.stdout.write(JSON.stringify({wire:output,calls:context.callCount,exitCode:context.process.exitCode}));
'''
        for kind, file in [('hosted', 'business31HostedReplay.cjs'), ('worker', 'business31CoreWorkerV2.cjs')]:
            for scenario in ('alternating', 'getter', 'proxy', 'frozen', 'null', 'primitive', 'serialization'):
                with self.subTest(kind=kind, scenario=scenario):
                    result = self.node_script(source, FILE.with_name(file), kind, scenario)
                    self.assertEqual(result.returncode, 0, result.stderr.decode()); self.assertEqual(result.stderr, b'')
                    out = json.loads(result.stdout); raw = out['wire'].encode()
                    self.assertEqual(out['exitCode'], 1); self.assertLessEqual(len(raw), 512)
                    self.assertNotIn(b'TOKEN_SENTINEL', raw); self.assertNotIn(b'Error:', raw)
                    split = b' ' if kind == 'worker' else b'. '
                    value = json.loads(raw.split(split, 1)[1])
                    if scenario in ('alternating', 'getter'):
                        self.assertEqual(out['calls'], 0); self.assertEqual(value['reason'], 'UNCLASSIFIED')
                    if scenario == 'frozen':
                        self.assertEqual(value['reason'], 'WORKER_EXACT_INPUT_BINDING_REQUIRED' if kind == 'worker' else 'CLI')
                    if scenario in ('null', 'primitive', 'proxy', 'serialization'):
                        self.assertEqual(value['reason'], 'UNCLASSIFIED')
        result = self.node_script(source, FILE.with_name('business31HostedReplay.cjs'), 'hosted', 'nested')
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        out = json.loads(result.stdout)
        self.assertNotIn('TOKEN_SENTINEL', out['wire'])
        self.assertEqual(json.loads(out['wire'].split('. ', 1)[1])['reason'], 'UNCLASSIFIED')

    def test_nested_data_accessor_is_not_reread_or_invoked(self):
        source = r'''
const fs=require('node:fs'),vm=require('node:vm'),source=fs.readFileSync(process.argv[1],'utf8');
const code=source.slice(source.indexOf('// Fixed failure metadata only.'),source.indexOf('function measureClient31('));let output='';
const context=vm.createContext({Buffer,fs:{writeSync:(_fd,text)=>{output+=text;return Buffer.byteLength(text);}},process:{exitCode:0}});
vm.runInContext(code+'\nlet calls=0;const value={schemaVersion:1,stage:"STS",reason:"STS_RESULT",nativeCode:null,workerExit:null,workerSignal:null,workerCleanupFailed:false,cleanupFailed:false};Object.defineProperty(value,"nativeCode",{enumerable:true,get(){calls++;return calls===1?"ENOENT":"TOKEN_SENTINEL";}});const incoming=Error("unused");Object.defineProperty(incoming,"business31Diagnostic",{value});reportFailure(incoming);globalThis.callCount=calls;',context);
process.stdout.write(JSON.stringify({wire:output,calls:context.callCount}));
'''
        result = self.node_script(source, FILE.with_name('business31HostedReplay.cjs'))
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        out = json.loads(result.stdout); self.assertEqual(out['calls'], 0)
        self.assertNotIn('TOKEN_SENTINEL', out['wire'])
        self.assertEqual(json.loads(out['wire'].split('. ', 1)[1])['reason'], 'UNCLASSIFIED')

    def test_parent_owns_wrapper_for_frozen_null_and_hostile_values(self):
        source = r'''
const Module=require('node:module'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=process.argv[1],owned=process.argv[2],scenario=process.argv[3],cleanup=process.argv[4]==='true';let calls=0,incoming;
if(scenario==='frozen')incoming=Object.freeze(Error('Business original-path replay v2: pinned Node changed before worker'));
else if(scenario==='null')incoming=null;
else if(scenario==='string')incoming='TOKEN_SENTINEL primitive';
else if(scenario==='getter'){incoming=Error('unused');Object.defineProperty(incoming,'code',{get(){calls++;throw Error('TOKEN_SENTINEL getter');}});}
else incoming=new Proxy(Error('unused'),{getOwnPropertyDescriptor(){calls++;throw Error('TOKEN_SENTINEL proxy');}});
const originalLoad=Module._load;Module._load=function(name,...rest){if(name==='node:child_process')return{spawnSync:()=>{throw incoming;}};return originalLoad.call(this,name,...rest);};
const api=require(path.join(root,'business31OriginalPathReplayV2.cjs')),actualRead=fs.readFileSync,actualUnlink=fs.unlinkSync,binding=Buffer.from('synthetic binding');
fs.readFileSync=function(file,...args){return file===process.execPath?binding:actualRead.call(fs,file,...args);};
if(cleanup)fs.unlinkSync=function(file){if(path.basename(file).startsWith('.business31-core-'))throw null;return actualUnlink(file);};
try{api.invokeCoreWorker31({workerFile:'never-spawned',input:{},ownedDirectory:owned,nodeSha256:crypto.createHash('sha256').update(binding).digest('hex').toUpperCase()});}
catch(error){process.stdout.write(JSON.stringify({value:error.business31Diagnostic,owned:error!==incoming,calls,remaining:fs.readdirSync(owned).length}));}
'''
        for scenario in ('frozen', 'null', 'string', 'getter', 'proxy'):
            for cleanup in (False, True):
                with self.subTest(scenario=scenario, cleanup=cleanup):
                    owned = self.root / ('hostile-' + scenario + str(cleanup)); owned.mkdir()
                    result = self.node_script(source, FILE.parent, owned, scenario, str(cleanup).lower())
                    self.assertEqual(result.returncode, 0, result.stderr.decode()); self.assertEqual(result.stderr, b'')
                    self.assertNotIn(b'TOKEN_SENTINEL', result.stdout)
                    out = json.loads(result.stdout); self.assertTrue(out['owned'])
                    self.assertEqual(out['value']['workerCleanupFailed'], cleanup)
                    self.assertEqual(out['remaining'], 1 if cleanup else 0)
                    self.assertEqual(out['value']['stage'], 'CORE_WORKER_PROCESS')
                    self.assertEqual(out['value']['reason'], 'ORIGINAL_PINNED_NODE_CHANGED_BEFORE_WORKER' if scenario == 'frozen' else 'UNCLASSIFIED')
                    if scenario == 'getter': self.assertEqual(out['calls'], 0)

    def test_python_hostile_exception_data_and_formatter_failures_are_total(self):
        class Explosive:
            calls = 0
            def __str__(self):
                self.calls += 1
                raise RuntimeError('TOKEN_SENTINEL string')
        value = Explosive(); launcher._remember_failure(ValueError(value))
        self.assertEqual(value.calls, 0); self.assertEqual(self.outer()['reason'], 'UNCLASSIFIED')
        class HostileErrno(OSError):
            calls = 0
            @property
            def errno(self):
                self.calls += 1
                raise RuntimeError('TOKEN_SENTINEL errno')
        error = HostileErrno(2, 'TOKEN_SENTINEL message')
        launcher._reset_failure(); launcher._remember_failure(error)
        self.assertEqual(error.calls, 0); self.assertEqual(self.outer()['nativeCode'], 'ENOENT')
        launcher._FAILURE['primary'] = {'stage': object(), 'reason': 'TOKEN_SENTINEL'}
        raw = launcher._failure_line(); self.assertLessEqual(len(raw), 512); self.assertNotIn(b'TOKEN_SENTINEL', raw)
        writes = []
        with patch.object(launcher, '_remember_failure', side_effect=RuntimeError('TOKEN_SENTINEL formatter')), \
             patch.object(launcher, '_failure_line', side_effect=RuntimeError('TOKEN_SENTINEL serializer')), \
             patch.object(launcher.os, 'write', side_effect=lambda fd, value: writes.append(value)):
            launcher._report_failure(None)
        self.assertEqual(writes, [launcher._FALLBACK_FAILURE])
        with patch.object(launcher.os, 'write', side_effect=OSError('TOKEN_SENTINEL closed pipe')):
            launcher._report_failure(None)

    def test_actual_python_final_except_exits_one_when_formatting_fails(self):
        script = self.root / 'outer-fallback.py'
        script.write_text(textwrap.dedent(r'''
            import importlib.util,pathlib,sys
            file=pathlib.Path(sys.argv[1])
            spec=importlib.util.spec_from_file_location('local_diagnostic_test',file)
            value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value)
            def broken(*args): raise RuntimeError('TOKEN_SENTINEL formatter private path')
            value._remember_failure=broken;value._failure_line=broken
            source=file.read_text();block=source[source.index('if __name__ == "__main__":'):]
            exec(compile(block,'actual-published-except-block','exec'),{'__name__':'__main__','main':broken,'_report_failure':value._report_failure})
        '''), encoding='utf8')
        result = self.native([sys.executable, '-I', '-S', '-B', str(script), str(FILE)])
        self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout, b'')
        self.assertEqual(result.stderr, launcher._FALLBACK_FAILURE)
        self.assertNotIn(b'TOKEN_SENTINEL', result.stderr); self.assertNotIn(b'Traceback', result.stderr)

if __name__ == "__main__":
    unittest.main()
