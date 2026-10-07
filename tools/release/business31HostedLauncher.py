"""Protected-workflow launcher; no candidate executable or arbitrary callback.

The workflow installation, this Python entry and the expected trust-file digest
must be selected independently before invocation. Hashes do not self-enroll them.
"""
import argparse
from datetime import datetime, timezone
from contextlib import ExitStack
import hashlib
import json
import os
import re
import signal
import selectors
import time
from pathlib import Path
import subprocess
import sys
import tempfile


def need(ok, code):
    if not ok:
        raise ValueError("BUSINESS_HOSTED_" + code)


def regular(value, directory=False):
    p = Path(value)
    need(p.is_absolute(), "ABSOLUTE_PATH")
    for part in (p, *p.parents):
        need(not part.is_symlink(), "PATH_REDIRECT")
        if hasattr(part, "is_junction"):
            need(not part.is_junction(), "PATH_REDIRECT")
    need(p.is_dir() if directory else p.is_file(), "REGULAR_PATH")
    return p


def digest(p):
    h = hashlib.sha256()
    with p.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def bounded_json(p):
    need(p.stat().st_size <= 2 * 1024 * 1024, "JSON_BOUND")
    return json.loads(p.read_bytes())


CLIENT_HELPERS = tuple("tools/release/" + name for name in (
    "business31HostedClient.cjs", "business31ClientCustody.cjs",
    "business31ClientSemantics.cjs", "business31TrustedInput.cjs",
    "business31PrivateDescriptor.cjs", "privateEvidenceBundle31.cjs", "business31ClientPolicy.cjs"))
REPLAY_HELPERS = tuple("tools/release/" + name for name in (
    "business31SourceAdmission.cjs", "business31PrivateDescriptor.cjs", "business31TrustedInput.cjs",
    "privateEvidenceBundle31.cjs", "business31OriginalPathReplay.cjs"))


def read_client_input(file, expected):
    # Both values are selected by the protected parent, outside the candidate.
    need(isinstance(expected, str) and re.fullmatch(r"[A-F0-9]{64}", expected) is not None,
         "CLIENT_INPUT_COMMITMENT")
    file = regular(file)
    need(0 < file.stat().st_size <= 128 * 1024, "CLIENT_INPUT_BOUND")
    raw = file.read_bytes()
    need(hashlib.sha256(raw).hexdigest().upper() == expected, "CLIENT_INPUT_COMMITMENT")
    value = json.loads(raw)
    need(isinstance(value, dict), "CLIENT_INPUT_FIELDS")
    return value


def launch_plan(mode, node, trust_file, trust_sha256, input_file, output, workspace,
                client_input=None, client_input_sha256=None):
    need(sys.flags.isolated == 1 and sys.flags.no_site == 1, "ISOLATED_PYTHON_REQUIRED")
    need(mode in ("replay", "consume"), "MODE")
    trust_file = regular(trust_file)
    need(digest(trust_file) == trust_sha256, "EXTERNAL_CONFIG_COMMITMENT")
    trust = bounded_json(trust_file)
    need(digest(regular(Path(sys.executable).absolute())) == trust["pythonSha256"], "PYTHON_IDENTITY")
    source_root = Path(__file__).resolve().parents[2]
    need(digest(regular(Path(__file__).absolute())) == trust["launcherSha256"], "LAUNCHER_IDENTITY")
    node = regular(node)
    need(digest(node) == trust["nodeSha256"], "NODE_IDENTITY")
    files = trust["verifier"]["files"]
    need(isinstance(files, dict) and 3 <= len(files) <= 256, "VERIFIER_POPULATION")
    for name, expected in files.items():
        parts = name.split("/")
        need(name.startswith("tools/") and all(x not in ("", ".", "..") for x in parts)
             and "\\" not in name and ":" not in name, "PRODUCER_PATH")
        need(digest(regular(source_root.joinpath(*parts))) == expected, "PRODUCER_IDENTITY")
    for name in ("business31HostedProtocol.cjs", "business31HostedReplay.cjs", "business31HostedResult.cjs"):
        need("tools/release/" + name in files, "HOSTED_PRODUCER")
    if mode == "replay":
        need(all(name in files for name in REPLAY_HELPERS), "REPLAY_PRODUCER")
    client_mode = client_input is not None or client_input_sha256 is not None
    if client_mode:
        need(client_input is not None and client_input_sha256 is not None,
             "CLIENT_INPUT_SELECTION")
        read_client_input(client_input, client_input_sha256)
        need(all(name in files for name in CLIENT_HELPERS), "CLIENT_PRODUCER")
    input_file = regular(input_file)
    bounded_json(input_file)
    workspace = regular(workspace, directory=True)
    # Parent is fresh, and child receives only these finite process/platform inputs.
    env = {"PATH": str(node.parent), "HOME": str(workspace), "USERPROFILE": str(workspace),
           "TMP": str(workspace), "TEMP": str(workspace), "TMPDIR": str(workspace),
           "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "GIT_CONFIG_NOSYSTEM": "1",
           "GIT_CONFIG_GLOBAL": "NUL" if os.name == "nt" else "/dev/null",
           "GIT_TERMINAL_PROMPT": "0", "GIT_NO_REPLACE_OBJECTS": "1"}
    if os.name == "nt":
        system = regular(os.environ.get("SystemRoot", ""), directory=True)
        env.update(SystemRoot=str(system), WINDIR=str(system), COMSPEC=str(system / "System32/cmd.exe"))
    for key in (["GITHUB_TOKEN", "ACTIONS_ID_TOKEN_REQUEST_URL", "ACTIONS_ID_TOKEN_REQUEST_TOKEN"]
                if mode == "replay" else ["GITHUB_TOKEN"]):
        value = os.environ.get(key)
        need(isinstance(value, str) and value and "\r" not in value and "\n" not in value, "PLATFORM_INPUT")
        env[key] = value
    entry = source_root / "tools/release" / ("business31HostedReplay.cjs" if mode == "replay" else "business31HostedResult.cjs")
    argv = [str(node), "--no-global-search-paths", str(entry), "--trust", str(trust_file),
            "--trust-sha256", trust_sha256, "--request", str(input_file)]
    if mode == "replay":
        output = Path(output)
        need(output.is_absolute() and output.name == "business31-hosted-result.json" and not output.exists(), "OUTPUT")
        regular(output.parent, directory=True)
        argv += ["--output", str(output)]
    if client_mode:
        argv += ["--client-input", str(client_input), "--client-input-sha256", client_input_sha256]
    return argv, env


def run_child(argv, env, owned):
    # Open private outputs before child creation; every later setup failure enters
    # the same owned-process cleanup path.
    with ExitStack() as resources:
        stdout_file = resources.enter_context(open(Path(owned) / "child.stdout", "xb"))
        stderr_file = resources.enter_context(open(Path(owned) / "child.stderr", "xb"))
        selector = resources.enter_context(selectors.DefaultSelector())
        child = subprocess.Popen(argv, env=env, cwd=owned, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        streams = {child.stdout: stdout_file, child.stderr: stderr_file}
        for stream in streams:
            resources.callback(stream.close)
        counts = {stream: 0 for stream in streams}
        deadline = time.monotonic() + 7200
        try:
            for stream in streams:
                selector.register(stream, selectors.EVENT_READ)
            while selector.get_map():
                need(time.monotonic() < deadline, "CHILD_TIMEOUT")
                for event, _ in selector.select(timeout=min(1, max(0, deadline - time.monotonic()))):
                    chunk = os.read(event.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(event.fileobj)
                        continue
                    counts[event.fileobj] += len(chunk)
                    need(counts[event.fileobj] <= 1024 * 1024, "CHILD_OUTPUT_BOUND")
                    streams[event.fileobj].write(chunk)
            need(child.wait(timeout=max(0.1, deadline - time.monotonic())) == 0, "CHILD_FAILURE")
        finally:
            # Only this new session is addressed. Abrupt launcher/job/host death
            # separately requires destruction of the ephemeral runner.
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            finally:
                child.wait(timeout=30)
    return (Path(owned) / "child.stdout").read_bytes(), (Path(owned) / "child.stderr").read_bytes()


def sanitized_consumer_output(raw, trust, request):
    need(isinstance(raw, bytes) and 0 < len(raw) <= 32768, "CONSUMER_OUTPUT_BOUND")
    value = json.loads(raw)

    def exact(item, fields, code):
        need(isinstance(item, dict) and set(item) == set(fields), code)

    def hex_value(item, length, alphabet):
        return isinstance(item, str) and len(item) == length and all(c in alphabet for c in item)

    def oid(item):
        return hex_value(item, 40, "0123456789abcdef")

    def sha256(item):
        return hex_value(item, 64, "0123456789ABCDEF")

    def identifier(item):
        return (isinstance(item, str) and 1 <= len(item) <= 20 and "1" <= item[0] <= "9"
                and all(c in "0123456789" for c in item))

    exact(value, {"schemaVersion", "profile", "verifier", "source", "candidate", "descriptorPointer",
                  "closurePointer", "commitments", "runId", "runAttempt", "artifactId", "resultSha256",
                  "hostedRecordedReplayResultAuthenticated", "ownerIdentityAuthenticated",
                  "originalProcessExecutionAuthenticated", "deploymentAuthorized", "constructionAuthorized",
                  "distributionAuthorized"}, "CONSUMER_OUTPUT_FIELDS")
    need(type(value["schemaVersion"]) is int and value["schemaVersion"] == 2
         and value["profile"] == trust["profile"] == "build31-business-hosted-recorded-replay-v1",
         "CONSUMER_OUTPUT_VERSION")
    exact(value["verifier"], {"commit", "tree"}, "CONSUMER_VERIFIER_FIELDS")
    exact(value["source"], {"commit", "tree", "functionsTree"}, "CONSUMER_SOURCE_FIELDS")
    exact(value["candidate"], {"commit", "tree", "ref", "kind", "pullRequest"}, "CONSUMER_CANDIDATE_FIELDS")
    need(all(oid(v) for v in value["verifier"].values())
         and all(oid(v) for v in value["source"].values())
         and oid(value["candidate"]["commit"]) and oid(value["candidate"]["tree"]),
         "CONSUMER_SOURCE_IDENTITY")
    candidate = value["candidate"]
    if candidate["kind"] == "main":
        need(candidate["ref"] == "refs/heads/main" and candidate["pullRequest"] is None,
             "CONSUMER_CANDIDATE_ROUTE")
    else:
        pr = candidate["pullRequest"]
        need(candidate["kind"] == "pull_request" and type(pr) is int and 0 < pr <= 9007199254740991
             and candidate["ref"] == f"refs/pull/{pr}/head", "CONSUMER_CANDIDATE_ROUTE")
    need(value["verifier"] == {key: trust["verifier"][key] for key in ("commit", "tree")}
         and value["source"] == trust["source"] and candidate == request["candidate"]
         and value["runId"] == request["runId"] and value["runAttempt"] == request["runAttempt"]
         and value["hostedRecordedReplayResultAuthenticated"] is True, "CONSUMER_OUTPUT_IDENTITY")
    for key, filename in (("descriptorPointer", "release/evidence/build31-business-private-replay.json"),
                          ("closurePointer", "release/evidence/build31-business-backend-deployment-closure.json")):
        pointer = value[key]
        exact(pointer, {"commit", "file", "sha256"}, "CONSUMER_POINTER_FIELDS")
        need(oid(pointer["commit"]) and pointer["file"] == filename and sha256(pointer["sha256"]),
             "CONSUMER_POINTER_IDENTITY")
    need(value["descriptorPointer"] == request["descriptorPointer"], "CONSUMER_DESCRIPTOR_JOIN")
    exact(value["commitments"], {"bundleSha256", "membersSha256", "relocationSha256", "sourceManifestSha256"},
          "CONSUMER_COMMITMENT_FIELDS")
    need(all(sha256(v) for v in value["commitments"].values())
         and value["commitments"]["sourceManifestSha256"] == trust["sourceManifestSha256"],
         "CONSUMER_COMMITMENT_JOIN")
    need(all(value[key] is False for key in ["ownerIdentityAuthenticated", "originalProcessExecutionAuthenticated",
                                           "deploymentAuthorized", "constructionAuthorized", "distributionAuthorized"]), "CONSUMER_AUTHORITY")
    need(all(identifier(value[key]) for key in ("runId", "runAttempt", "artifactId"))
         and sha256(value["resultSha256"]), "CONSUMER_OUTPUT_DIGEST")
    clean = json.dumps(value, separators=(",", ":")).encode() + b"\n"
    need(raw == clean, "EXTRA_CONSUMER_OUTPUT")
    return clean


def sanitized_client_policy(policy, trust, request, client):
    """Closed recorded-data joins, never independent approval or authentication."""
    def exact(item, fields):
        need(isinstance(item, dict) and set(item) == set(fields), "CLIENT_POLICY_FIELDS")

    def digest(item):
        return isinstance(item, str) and re.fullmatch(r"[A-F0-9]{64}", item) is not None

    def pointer(item, file):
        exact(item, ("commit", "file", "sha256"))
        need(isinstance(item["commit"], str) and re.fullmatch(r"[a-f0-9]{40}", item["commit"]) is not None
             and item["file"] == file and digest(item["sha256"]), "CLIENT_POLICY_POINTER")

    flags = ("independentlySelectedInputsAuthenticated", "executingHostAuthenticated", "humanIdentityAuthenticated",
             "trustedClockAuthenticated", "platformIdentityAuthenticated", "privateReplayVerified",
             "credentialAccessAuthorized", "backendDeploymentAuthorized", "constructionAuthorized",
             "signingAuthorized", "distributionAuthorized")
    exact(policy, ("schemaVersion", "profile", "verifier", "source", "candidate", "sourceManifestSha256", "bindings",
                   "descriptorPointer", "closurePointer", "decisionPointer", "release", "appCheck",
                   "policySourceVerified", "appCheckSourcePolicyVerified", *flags))
    need(type(policy["schemaVersion"]) is int and policy["schemaVersion"] == 1
         and policy["profile"] == "build31-business-client-policy-v1"
         and policy["policySourceVerified"] is True and policy["appCheckSourcePolicyVerified"] is True
         and all(policy[key] is False for key in flags), "CLIENT_POLICY_SCOPE")
    need(policy["verifier"] == {key: trust["verifier"][key] for key in ("commit", "tree")}
         and policy["source"] == trust["source"] and policy["candidate"] == request["candidate"]
         and policy["sourceManifestSha256"] == trust["sourceManifestSha256"], "CLIENT_POLICY_SOURCE_JOIN")
    need(type(policy["candidate"].get("pullRequest")) is type(request["candidate"]["pullRequest"]), "CLIENT_POLICY_CANDIDATE_TYPE")
    pointer(policy["descriptorPointer"], "release/evidence/build31-business-private-replay.json")
    pointer(policy["closurePointer"], "release/evidence/build31-business-backend-deployment-closure.json")
    pointer(policy["decisionPointer"], "release/approvals/build31-business-client-compatibility-approval.json")
    need(policy["descriptorPointer"] == request["descriptorPointer"]
         and policy["decisionPointer"] == client["decisionPointer"], "CLIENT_POLICY_POINTER_JOIN")
    paths = {"policy": "release/production-release-policy.json",
             "versionApproval": "release/approvals/version-policy-approval.json",
             "successorApproval": "release/approvals/build-number-31-successor-approval.json",
             "currentSuccessor": "release/current-successor-state.json",
             "appCheckApproval": "release/approvals/build31-app-check-client-approval.json", "pubspec": "pubspec.yaml",
             "backendPolicy": "release/production-release-policy.json",
             "identitySource": "functions/src/stage2dSecurityConfig.ts",
             "rulesReadback": "release/evidence/build30-current-source-firestore-rules-indexes-live-readback.json"}
    exact(policy["bindings"], paths)
    for name, file in paths.items():
        binding = policy["bindings"][name]
        pointer(binding, file)
        commit = trust["source"]["commit"] if name in ("backendPolicy", "identitySource", "rulesReadback") else request["candidate"]["commit"]
        need(binding["commit"] == commit, "CLIENT_POLICY_BINDING_SOURCE")
    identity = client["appCheck"]["identityCallable"]
    need(identity["sourceSha256"] == "1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F"
         and policy["bindings"]["identitySource"]["sha256"] == identity["sourceSha256"]
         and policy["bindings"]["rulesReadback"]["sha256"] == "62A707AC10A76B6C9D6D1466987D558E8C9186602B57E0E75EB760A5F4160CEC",
         "CLIENT_POLICY_PRESERVED_DIGEST")
    release = policy["release"]
    exact(release, ("releaseId", "reservationId", "buildNumber", "versionName", "reservationTag", "builtTag"))
    need(type(release["buildNumber"]) is int and release["buildNumber"] == 31
         and release["releaseId"] == client["appCheck"]["releaseId"]
         and release["reservationId"] == client["appCheck"]["reservationId"]
         and isinstance(release["versionName"], str)
         and re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?", release["versionName"]) is not None
         and release["reservationTag"] == "crm3-build-reserved/31" and release["builtTag"] == "crm3-build-built/31",
         "CLIENT_POLICY_RELEASE")
    expected_app = {"clientEnabled": True, "androidProvider": "playIntegrity", "dartDefine": "true",
                    "approvalFile": paths["appCheckApproval"], "approvalSha256": policy["bindings"]["appCheckApproval"]["sha256"],
                    "backendReceiptFile": policy["closurePointer"]["file"], "backendReceiptSha256": policy["closurePointer"]["sha256"],
                    "serverEnforcementAtBuild": False, "enforcementChangedByBuild": False,
                    "tokenValidationEvidence": "not-proved-by-artifact-construction",
                    "serverEnforcementScopesAtBuild": {"defaultMutatingEnforced": False,
                                                       "identityCallable": identity["name"], "identityCallableEnforced": True,
                                                       "identitySourceFile": identity["sourceFile"], "identitySourceSha256": identity["sourceSha256"]}}
    actual = policy["appCheck"]
    exact(actual, expected_app)
    need(actual == expected_app and actual["clientEnabled"] is True and actual["serverEnforcementAtBuild"] is False
         and actual["enforcementChangedByBuild"] is False
         and actual["serverEnforcementScopesAtBuild"]["defaultMutatingEnforced"] is False
         and actual["serverEnforcementScopesAtBuild"]["identityCallableEnforced"] is True, "CLIENT_POLICY_APPCHECK")


def validate_client_projection(value, trust, request, client_input=None):
    def exact(item, fields, code):
        need(isinstance(item, dict) and set(item) == set(fields), code)

    selected = client_input["selected"] if client_input is not None else None
    client = value["client"]
    verified = ("gitCustodyVerified", "dedicatedOwnerDecisionDeltasVerified",
                "descriptorPreparationVerified", "recordedSemanticsValidated", "appCheckSourcePolicyVerified")
    unverified = ("independentlySelectedInputsAuthenticated",
                  "executingHostAuthenticated", "humanIdentityAuthenticated", "trustedClockAuthenticated",
                  "platformIdentityAuthenticated", "credentialAccessAuthorized", "backendDeploymentAuthorized",
                  "constructionAuthorized", "signingAuthorized", "distributionAuthorized")
    exact(client, ("schemaVersion", "profile", "ownerPointer", "decisionPointer", "originalMessage",
                   "appCheck", "publicClosureRecordedAtUtc", "policy", *verified, *unverified), "CLIENT_OUTPUT_FIELDS")
    need(type(client["schemaVersion"]) is int and client["schemaVersion"] == 2
         and client["profile"] == "build31-business-client-compatibility-v1", "CLIENT_OUTPUT_PROFILE")
    need(all(client[key] is True for key in verified) and all(client[key] is False for key in unverified),
         "CLIENT_OUTPUT_AUTHORITY")
    for name, filename in (("ownerPointer", "build31-business-client-owner-authorization.json"),
                           ("decisionPointer", "build31-business-client-compatibility-approval.json")):
        pointer = client[name]
        exact(pointer, ("commit", "file", "sha256"), "CLIENT_POINTER_FIELDS")
        need(isinstance(pointer["commit"], str) and re.fullmatch(r"[a-f0-9]{40}", pointer["commit"]) is not None
             and pointer["file"] == "release/approvals/" + filename
             and isinstance(pointer["sha256"], str) and re.fullmatch(r"[A-F0-9]{64}", pointer["sha256"]) is not None
             and (selected is None or pointer == selected[name]), "CLIENT_POINTER_JOIN")
    message = client["originalMessage"]
    exact(message, ("sha256", "bytes"), "CLIENT_MESSAGE_FIELDS")
    need(isinstance(message["sha256"], str) and re.fullmatch(r"[A-F0-9]{64}", message["sha256"]) is not None
         and type(message["bytes"]) is int and 0 < message["bytes"] <= 128 * 1024
         and (selected is None or message == selected["originalMessage"]), "CLIENT_MESSAGE_JOIN")
    app_check = client["appCheck"]
    exact(app_check, ("releaseId", "reservationId", "clientEnabled", "androidProvider",
                       "mutatingDefaultEnforced", "identityCallable"), "CLIENT_APPCHECK_FIELDS")
    identity = app_check["identityCallable"]
    exact(identity, ("name", "enforced", "sourceFile", "sourceSha256"), "CLIENT_IDENTITY_FIELDS")
    need(app_check["clientEnabled"] is True and app_check["androidProvider"] == "playIntegrity"
         and app_check["mutatingDefaultEnforced"] is False and identity["name"] == "getBackendReleaseIdentity"
         and identity["enforced"] is True and identity["sourceFile"] == "functions/src/stage2dSecurityConfig.ts"
         and isinstance(identity["sourceSha256"], str)
         and re.fullmatch(r"[A-F0-9]{64}", identity["sourceSha256"]) is not None
         and all(isinstance(app_check[key], str) and 0 < len(app_check[key]) <= 400
                 and app_check[key] == app_check[key].strip()
                 and re.search(r"[\x00-\x1f\x7f]", app_check[key]) is None
                 for key in ("releaseId", "reservationId"))
         and (selected is None or app_check == selected["appCheck"]), "CLIENT_APPCHECK_JOIN")
    timestamp = client["publicClosureRecordedAtUtc"]
    need(isinstance(timestamp, str) and re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,9})?Z", timestamp) is not None,
        "CLIENT_CLOSURE_TIME")
    datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    if selected is not None:
        need(value["source"] == selected["source"]
             and value["commitments"]["sourceManifestSha256"] == selected["sourceManifestSha256"]
             and value["descriptorPointer"] == selected["descriptor"]
             and value["closurePointer"] == selected["backendClosure"], "CLIENT_BACKEND_JOIN")
    need(client["policy"]["closurePointer"] == value["closurePointer"], "CLIENT_POLICY_CLOSURE_JOIN")
    sanitized_client_policy(client["policy"], trust, request, client)


def sanitized_client_output(raw, trust, request, client_input=None):
    """Closed authenticated consumer projection; no raw private evidence."""
    need(isinstance(raw, bytes) and 0 < len(raw) <= 32768, "CLIENT_OUTPUT_BOUND")
    value = json.loads(raw)
    need(isinstance(value, dict) and type(value.get("schemaVersion")) is int
         and value["schemaVersion"] == 3 and "client" in value, "CLIENT_OUTPUT_VERSION")
    if request.get("schemaVersion") == 2:
        bounds = validate_challenge(value.get("challenge"), request)
        need(datetime.now(timezone.utc) <= bounds[1], "CLIENT_CHALLENGE_TIME")
    else:
        need("challenge" not in value, "CLIENT_UNEXPECTED_CHALLENGE")
    base = {key: item for key, item in value.items() if key not in ("client", "challenge")}
    base["schemaVersion"] = 2
    sanitized_consumer_output(json.dumps(base, separators=(",", ":")).encode() + b"\n", trust, request)
    validate_client_projection(value, trust, request, client_input)
    clean = json.dumps(value, separators=(",", ":")).encode() + b"\n"
    need(raw == clean, "EXTRA_CLIENT_OUTPUT")
    return clean

def validate_challenge(value, request):
    need(isinstance(value, dict) and set(value) == {"schemaVersion", "nonce", "purpose", "requestedAtUtc", "expiresAtUtc",
                                                  "requester", "clientSelectionSha256", "fileBindings"}
         and value == request.get("challenge"), "CHALLENGE_JOIN")
    need(type(value["schemaVersion"]) is int and value["schemaVersion"] == 1
         and isinstance(value["nonce"], str) and re.fullmatch(r"[a-f0-9]{64}", value["nonce"]) is not None
         and value["purpose"] in ("policy", "construction", "package-verification")
         and isinstance(value["clientSelectionSha256"], str)
         and re.fullmatch(r"[A-F0-9]{64}", value["clientSelectionSha256"]) is not None, "CHALLENGE_IDENTITY")
    times = []
    for name in ("requestedAtUtc", "expiresAtUtc"):
        wire = value[name]
        need(isinstance(wire, str) and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z", wire) is not None,
             "CHALLENGE_DATE")
        times.append(datetime.fromisoformat(wire.replace("Z", "+00:00")))
    need(0 < (times[1] - times[0]).total_seconds() <= 150 * 60, "CHALLENGE_DURATION")
    who = value["requester"]
    need(isinstance(who, dict) and set(who) == {"kind", "runId", "runAttempt", "invocationId"}
         and isinstance(who["invocationId"], str) and re.fullmatch(r"[a-f0-9]{64}", who["invocationId"]) is not None,
         "CHALLENGE_REQUESTER")
    if who["kind"] == "github-actions":
        need(all(isinstance(who[k], str) and re.fullmatch(r"[1-9][0-9]{0,19}", who[k]) is not None
                 for k in ("runId", "runAttempt")), "CHALLENGE_REQUESTER")
    else:
        need(who["kind"] == "local" and who["runId"] is None and who["runAttempt"] is None, "CHALLENGE_REQUESTER")
    if value["purpose"] == "construction":
        need(request["candidate"]["kind"] == "main" and who["kind"] == "github-actions", "CHALLENGE_CONSTRUCTION")
    files = value["fileBindings"]
    need(isinstance(files, list) and len(files) <= 10, "CHALLENGE_FILES")
    for file in files:
        need(isinstance(file, dict) and set(file) == {"role", "name", "sha256", "bytes"}
             and file["role"] in ("source-archive", "manifest", "package")
             and isinstance(file["name"], str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,179}", file["name"]) is not None
             and ".." not in file["name"] and isinstance(file["sha256"], str)
             and re.fullmatch(r"[A-F0-9]{64}", file["sha256"]) is not None
             and type(file["bytes"]) is int and 0 < file["bytes"] <= 4 * 1024 * 1024 * 1024, "CHALLENGE_FILE")
    need(len({f["name"] for f in files}) == len(files), "CHALLENGE_DUPLICATE")
    if value["purpose"] == "package-verification":
        need(request["candidate"]["kind"] == "main" and sum(f["role"] == "source-archive" for f in files) == 1
             and sum(f["role"] == "manifest" for f in files) == 1 and any(f["role"] == "package" for f in files), "CHALLENGE_PACKAGE")
    else:
        need(not files, "CHALLENGE_UNEXPECTED_FILES")
    return times


def sanitized_replay_output(raw, trust, request, client_input=None):
    need(isinstance(raw, bytes) and 0 < len(raw) <= 32768, "REPLAY_OUTPUT_BOUND")
    value = json.loads(raw)
    version = request.get("schemaVersion")
    expected = {"schemaVersion", "documentType", "profile", "verifier", "source", "candidate", "descriptorPointer",
                "closurePointer", "commitments", "platform", "startedAtUtc", "completedAtUtc", "recordedSemanticsReplayed", "limits"}
    if version == 2:
        expected.update(("challenge", "client"))
    need(type(version) is int and version in (1, 2) and isinstance(value, dict) and set(value) == expected
         and type(value["schemaVersion"]) is int and value["schemaVersion"] == version
         and value["documentType"] == "build31-business-hosted-result"
         and value["profile"] == trust["profile"] == "build31-business-hosted-recorded-replay-v1"
         and value["recordedSemanticsReplayed"] is True, "REPLAY_OUTPUT_FIELDS")
    limits = value["limits"]
    need(isinstance(limits, dict) and set(limits) == {"ownerIdentityAuthenticated", "originalProcessExecutionAuthenticated",
                                                    "deploymentAuthorized", "constructionAuthorized", "distributionAuthorized"}
         and all(item is False for item in limits.values()), "REPLAY_OUTPUT_LIMITS")
    # Reuse only the existing closed identity/commitment contract, internally;
    # this temporary object is never returned as authenticated public evidence.
    projection = {key: value[key] for key in ("profile", "verifier", "source", "candidate", "descriptorPointer", "closurePointer", "commitments")}
    projection.update(schemaVersion=2, runId=request["runId"], runAttempt=request["runAttempt"], artifactId="1",
                      resultSha256=hashlib.sha256(raw).hexdigest().upper(), hostedRecordedReplayResultAuthenticated=True, **limits)
    sanitized_consumer_output(json.dumps(projection, separators=(",", ":")).encode() + b"\n", trust, request)
    need(value["platform"] == {"repositoryId": trust["repository"]["id"], "workflowId": trust["workflow"]["id"],
                               "workflowCommit": trust["verifier"]["commit"], "runId": request["runId"],
                               "runAttempt": request["runAttempt"], "environment": trust["workflow"]["environment"]}, "REPLAY_PLATFORM")
    times = []
    for key in ("startedAtUtc", "completedAtUtc"):
        wire = value[key]
        need(isinstance(wire, str) and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z", wire) is not None, "REPLAY_DATE")
        times.append(datetime.fromisoformat(wire.replace("Z", "+00:00")))
    now = datetime.now(timezone.utc)
    need(times[0] <= times[1] <= now and (now - times[1]).total_seconds() <= trust["maximumResultAgeSeconds"], "REPLAY_TIME")
    if version == 2:
        bounds = validate_challenge(value["challenge"], request)
        need(bounds[0] <= times[0] <= times[1] <= bounds[1] and now <= bounds[1], "REPLAY_CHALLENGE_TIME")
        need(client_input is not None, "REPLAY_CLIENT_SELECTION")
        validate_client_projection(value, trust, request, client_input)
    else:
        need(client_input is None, "REPLAY_UNEXPECTED_CLIENT")
    clean = json.dumps(value, separators=(",", ":")).encode() + b"\n"
    need(clean == raw, "EXTRA_REPLAY_OUTPUT")
    return clean


def execute_launch(args):
    need(sys.platform == "linux", "PROTECTED_LINUX_RUNNER_REQUIRED")
    parent = regular(args.private_parent, directory=True)
    destination = None
    if args.mode == "replay":
        destination = Path(args.output)
        need(destination.is_absolute() and destination.name == "business31-hosted-result.json"
             and not destination.exists(), "OUTPUT")
        regular(destination.parent, directory=True)
    with tempfile.TemporaryDirectory(prefix="business31-launch-", dir=parent) as owned:
        client_input = getattr(args, "client_input", None)
        client_sha256 = getattr(args, "client_input_sha256", None)
        input_file = args.input
        if args.mode == "replay":
            data = bounded_json(regular(args.input))
            need(set(data) == {"request", "repositoryRoot", "gitExecutable", "sourceManifest"}, "LAUNCH_INPUT")
            data["privateParent"] = owned
            input_file = str(Path(owned) / "replay-input.json")
            with open(input_file, "x", encoding="utf8") as stream:
                json.dump(data, stream)
        staged = Path(owned) / "business31-hosted-result.json"
        argv, env = launch_plan(args.mode, args.node, args.trust, args.trust_sha256, input_file, str(staged), owned,
                                client_input, client_sha256)
        # No shell, no inherited preloads/caches, no candidate-selected entry.
        stdout, stderr = run_child(argv, env, owned)
        need(not stderr, "CHILD_DIAGNOSTIC")
        if args.mode == "replay":
            need(not stdout, "UNEXPECTED_REPLAY_OUTPUT")
            regular(staged)
            need(0 < staged.stat().st_size <= 32768, "REPLAY_OUTPUT_BOUND")
            trust = bounded_json(regular(args.trust))
            selected_client = read_client_input(client_input, client_sha256) if client_input is not None else None
            clean = sanitized_replay_output(staged.read_bytes(), trust, data["request"], selected_client)
        else:
            trust = bounded_json(regular(args.trust))
            request = bounded_json(regular(args.input))
            if client_input is None and request.get("schemaVersion") != 2:
                clean = sanitized_consumer_output(stdout, trust, request)
            else:
                selected_client = read_client_input(client_input, client_sha256) if client_input is not None else None
                clean = sanitized_client_output(stdout, trust, request, selected_client)
    # Publish only after private cleanup succeeds, never raw helper diagnostics.
    if destination is not None:
        fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(clean)
        except BaseException:
            destination.unlink()
            raise
    else:
        sys.stdout.buffer.write(clean)


def main():
    need(sys.flags.isolated == 1 and sys.flags.no_site == 1, "ISOLATED_PYTHON_REQUIRED")
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["replay", "consume"], required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--trust", required=True)
    parser.add_argument("--trust-sha256", required=True)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output")
    parser.add_argument("--private-parent", required=True)
    parser.add_argument("--client-input")
    parser.add_argument("--client-input-sha256")
    execute_launch(parser.parse_args())


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        sys.stderr.write("Protected business replay failed; no result is admissible.\n")
        raise SystemExit(1)
