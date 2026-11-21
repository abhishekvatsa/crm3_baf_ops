"""Protected-workflow launcher; no candidate executable or arbitrary callback.

The workflow installation, this Python entry and the expected trust-file digest
must be selected independently before invocation. Hashes do not self-enroll them.
"""
import argparse
from datetime import datetime, timezone
from contextlib import ExitStack
import hashlib
import importlib.util
import json
import os
import re
import signal
import selectors
import time
from pathlib import Path
import subprocess
import errno
import sys
import tempfile


# Failure records contain only literal enums, bounded native integers and booleans.
_NODE_STAGES = frozenset(["ENTRY_INPUT","ADMISSION_INITIAL","CLIENT_INITIAL","PLATFORM_INITIAL","OIDC","ADMISSION_RECHECK","STS","BUNDLE_DOWNLOAD","ORIGINAL_REPLAY","ADMISSION_FINAL","CLIENT_RECHECK","PLATFORM_FINAL","CLIENT_FINAL","RESULT_VALIDATION","PRIVATE_CLEANUP","RESULT_STAGING","WORKER_ENTRY","WORKER_INPUT","WORKER_RUNTIME","WORKER_INVENTORY","WORKER_RELOCATION","WORKER_CORE_BINDING","WORKER_CORE_LOAD","WORKER_RELOCATION_CONTEXT","WORKER_GIT","WORKER_BACKEND_CLOSURE","WORKER_RESULT","WORKER_FINAL_INVENTORY","WORKER_FINAL_RUNTIME","WORKER_OUTPUT","CORE_WORKER_PREPARE","CORE_WORKER_PROCESS","CORE_WORKER_RESULT","CORE_WORKER_INPUT_CLEANUP"])
_NODE_REASONS = frozenset(["ABSOLUTE_PATH","ADMISSION_CHANGED","ADMITTED_CORE_VERIFIER","ADMITTED_PRODUCERS","ADMITTED_SOURCE","ADMITTED_SOURCE_INTEGRATION","ADMITTED_VERIFIER","ARTIFACT_BOUND","ARTIFACT_DIGEST","ARTIFACT_IDENTITY","ARTIFACT_POPULATION","ARTIFACT_REDIRECT","ARTIFACT_RUN","ARTIFACT_STORAGE_ORIGIN","ARTIFACT_TIME","CALLER_OPTIONS","CANDIDATE","CANDIDATE_ID","CHALLENGE","CHALLENGE_CURRENT","CHALLENGE_DATE","CHALLENGE_DUPLICATE_FILE","CHALLENGE_DURATION","CHALLENGE_FILE","CHALLENGE_FILES","CHALLENGE_IDENTITY","CHALLENGE_INVOCATION","CHALLENGE_PACKAGE_FILES","CHALLENGE_REQUESTER","CHALLENGE_UNEXPECTED_FILES","CLEANUP_OWNERSHIP","CLI","CLIENT_GIT","CLIENT_INPUT_BOUND","CLIENT_INPUT_COMMITMENT","CLIENT_MEASUREMENT_CHANGED","CLIENT_PRODUCER","CLIENT_REPOSITORY","CLIENT_REQUEST_MODE","CLIENT_SELECTED_COMMITMENT","CONFIG_DIGEST","CONSTRUCTION_REQUESTER","CORE_MEMBER","CORE_NODE22","CORE_POPULATION","CORE_ROUTE","CORE_SOURCE","CORE_VERIFIER","DESCRIPTOR_POINTER","EXECUTING_PRODUCER","EXTERNAL_CONFIG_COMMITMENT","FINAL_ADMISSION_CHANGED","FINAL_CLIENT_MEASUREMENT_CHANGED","GITHUB_PATH","GIT_IDENTITY","HTTPS_ENDPOINT","INPUT_BOUNDARY","JOB_IDENTITY","JOB_POPULATION","JOB_STATE","JSON_BOUND","JSON_COMPLEXITY","LIVE_REPOSITORY","LOCAL_INPUT","MAIN_REQUEST","M_REFUSAL_001","M_REFUSAL_002","M_REFUSAL_003","M_REFUSAL_004","M_REFUSAL_005","M_REFUSAL_006","M_REFUSAL_007","M_REFUSAL_008","M_REFUSAL_009","M_REFUSAL_010","M_REFUSAL_011","M_REFUSAL_012","M_REFUSAL_013","M_REFUSAL_014","M_REFUSAL_015","M_REFUSAL_016","M_REFUSAL_017","M_REFUSAL_018","M_REFUSAL_019","M_REFUSAL_020","M_REFUSAL_021","M_REFUSAL_022","M_REFUSAL_023","M_REFUSAL_024","M_REFUSAL_025","M_REFUSAL_026","M_REFUSAL_027","M_REFUSAL_028","M_REFUSAL_029","M_REFUSAL_030","M_REFUSAL_031","M_REFUSAL_032","M_REFUSAL_033","M_REFUSAL_034","M_REFUSAL_035","M_REFUSAL_036","M_REFUSAL_037","M_REFUSAL_038","M_REFUSAL_039","M_REFUSAL_040","M_REFUSAL_041","M_REFUSAL_042","M_REFUSAL_043","M_REFUSAL_044","M_REFUSAL_045","M_REFUSAL_046","M_REFUSAL_047","M_REFUSAL_048","M_REFUSAL_049","M_REFUSAL_050","M_REFUSAL_051","M_REFUSAL_052","M_REFUSAL_053","M_REFUSAL_054","M_REFUSAL_055","M_REFUSAL_056","M_REFUSAL_057","M_REFUSAL_058","M_REFUSAL_059","M_REFUSAL_060","M_REFUSAL_061","M_REFUSAL_062","M_REFUSAL_063","M_REFUSAL_064","M_REFUSAL_065","M_REFUSAL_066","M_REFUSAL_067","M_REFUSAL_068","M_REFUSAL_069","M_REFUSAL_070","M_REFUSAL_071","M_REFUSAL_072","M_REFUSAL_073","M_REFUSAL_074","M_REFUSAL_075","M_REFUSAL_076","M_REFUSAL_077","M_REFUSAL_078","M_REFUSAL_079","M_REFUSAL_080","M_REFUSAL_081","M_REFUSAL_082","M_REFUSAL_083","M_REFUSAL_084","M_REFUSAL_085","M_REFUSAL_086","M_REFUSAL_087","M_REFUSAL_088","M_REFUSAL_089","M_REFUSAL_090","M_REFUSAL_091","M_REFUSAL_092","M_REFUSAL_093","M_REFUSAL_094","M_REFUSAL_095","M_REFUSAL_096","M_REFUSAL_097","M_REFUSAL_098","M_REFUSAL_099","M_REFUSAL_100","M_REFUSAL_101","M_REFUSAL_102","M_REFUSAL_103","M_REFUSAL_104","M_REFUSAL_105","M_REFUSAL_106","M_REFUSAL_107","M_REFUSAL_108","M_REFUSAL_109","M_REFUSAL_110","M_REFUSAL_111","M_REFUSAL_112","M_REFUSAL_113","M_REFUSAL_114","M_REFUSAL_115","M_REFUSAL_116","M_REFUSAL_117","M_REFUSAL_118","M_REFUSAL_119","M_REFUSAL_120","M_REFUSAL_121","M_REFUSAL_122","M_REFUSAL_123","M_REFUSAL_124","M_REFUSAL_125","M_REFUSAL_126","M_REFUSAL_127","M_REFUSAL_128","M_REFUSAL_129","M_REFUSAL_130","M_REFUSAL_131","M_REFUSAL_132","M_REFUSAL_133","M_REFUSAL_134","M_REFUSAL_135","M_REFUSAL_136","M_REFUSAL_137","M_REFUSAL_138","M_REFUSAL_139","M_REFUSAL_140","M_REFUSAL_141","M_REFUSAL_142","M_REFUSAL_143","M_REFUSAL_144","M_REFUSAL_145","M_REFUSAL_146","M_REFUSAL_147","M_REFUSAL_148","M_REFUSAL_149","M_REFUSAL_150","M_REFUSAL_151","M_REFUSAL_152","M_REFUSAL_153","M_REFUSAL_154","M_REFUSAL_155","M_REFUSAL_156","M_REFUSAL_157","M_REFUSAL_158","M_REFUSAL_159","M_REFUSAL_160","M_REFUSAL_161","M_REFUSAL_162","M_REFUSAL_163","M_REFUSAL_164","M_REFUSAL_165","M_REFUSAL_166","M_REFUSAL_167","M_REFUSAL_168","M_REFUSAL_169","M_REFUSAL_170","M_REFUSAL_171","M_REFUSAL_172","M_REFUSAL_173","M_REFUSAL_174","M_REFUSAL_175","M_REFUSAL_176","M_REFUSAL_177","M_REFUSAL_178","M_REFUSAL_179","M_REFUSAL_180","M_REFUSAL_181","M_REFUSAL_182","M_REFUSAL_183","M_REFUSAL_184","M_REFUSAL_185","M_REFUSAL_186","M_REFUSAL_187","M_REFUSAL_188","M_REFUSAL_189","M_REFUSAL_190","M_REFUSAL_191","M_REFUSAL_192","M_REFUSAL_193","M_REFUSAL_194","M_REFUSAL_195","M_REFUSAL_196","M_REFUSAL_197","M_REFUSAL_198","M_REFUSAL_199","M_REFUSAL_200","M_REFUSAL_201","M_REFUSAL_202","M_REFUSAL_203","M_REFUSAL_204","M_REFUSAL_205","M_REFUSAL_206","M_REFUSAL_207","M_REFUSAL_208","M_REFUSAL_209","M_REFUSAL_210","M_REFUSAL_211","M_REFUSAL_212","M_REFUSAL_213","M_REFUSAL_214","M_REFUSAL_215","M_REFUSAL_216","M_REFUSAL_217","M_REFUSAL_218","M_REFUSAL_219","M_REFUSAL_220","M_REFUSAL_221","M_REFUSAL_222","M_REFUSAL_223","M_REFUSAL_224","M_REFUSAL_225","M_REFUSAL_226","M_REFUSAL_227","M_REFUSAL_228","M_REFUSAL_229","M_REFUSAL_230","M_REFUSAL_231","M_REFUSAL_232","M_REFUSAL_233","M_REFUSAL_234","M_REFUSAL_235","NATIVE_FAILURE","NODE_IDENTITY","OIDC_ACTOR","OIDC_ALGORITHM","OIDC_BOUND","OIDC_FORMAT","OIDC_HEADER","OIDC_KEY","OIDC_KEYS","OIDC_REQUEST_ORIGIN","OIDC_RESPONSE","OIDC_SIGNATURE","OIDC_TIME","ORIGINAL_BOUNDED_CLEAN_WORKER_RESULT_REQUIRED","ORIGINAL_BOUNDED_EXISTING_BUNDLE_BYTES_REQUIRED","ORIGINAL_BOUNDED_WORKER_METADATA_REQUIRED","ORIGINAL_CANDIDATE_MOVED_DURING_REPLAY","ORIGINAL_CLOSED_OFFLINE_INPUT_REQUIRED","ORIGINAL_COMPLETE_EXTRACTED_POPULATION_DIFFERS","ORIGINAL_CORE_CLOSURE_SOURCE_CUSTODY_DIFFERS","ORIGINAL_DESCRIPTOR_CHANGED","ORIGINAL_EXACT_PINNED_NODE22_IDENTITY_REQUIRED","ORIGINAL_EXPLICIT_CALLER_CLOCK_REQUIRED","ORIGINAL_FRESH_RECORDED_CORE_WORKER_FAILED","ORIGINAL_OUTER_HELPER_BYTES_DIFFER","ORIGINAL_OUTER_HELPER_NOT_SELECTED","ORIGINAL_OUTER_HELPER_REDIRECTS","ORIGINAL_PINNED_NODE22_REQUIRED","ORIGINAL_PINNED_NODE_CHANGED_BEFORE_WORKER","ORIGINAL_PRIVATE_EVIDENCE_CHANGED_DURING_REPLAY","ORIGINAL_RUNTIME_CHANGED_DURING_REPLAY","ORIGINAL_SELECTED_RUNTIME_DIFFERS","ORIGINAL_SOURCE_MANIFEST_OBJECT_DIFFERS","ORIGINAL_WORKER_COMMITMENTS_DIFFER","ORIGINAL_WORKER_RESULT_PROFILE_AUTHORITY_DIFFERS","PARSE_REFUSAL","PATH_REDIRECT","PR_REQUEST","REGULAR_PATH","REPLAY_CLOSURE","REPLAY_DESCRIPTOR","REPLAY_INCOMPLETE","REPLAY_PRODUCER","REPLAY_SOURCE","REPOSITORY","REQUEST","REQUEST_ID","RESULT_AGE","RESULT_CHALLENGE","RESULT_CHALLENGE_TIME","RESULT_CLIENT_CLOSURE","RESULT_CLIENT_CORE","RESULT_CLOSURE","RESULT_COMMITMENTS","RESULT_CORE_VERIFIER","RESULT_DATE","RESULT_DESCRIPTOR","RESULT_DESTINATION","RESULT_FIELDS","RESULT_JOB_TIME","RESULT_LIMITS","RESULT_M","RESULT_PLATFORM","RESULT_POLICY_CORE","RESULT_PROFILE","RESULT_S","RESULT_TIME","RESULT_TRANSPORT_COMMITMENT","RESULT_V","RUN_ACTOR","RUN_ORIGIN","RUN_STATE","SOURCE","SOURCE_ID","SOURCE_INTEGRATION","SOURCE_INTEGRATION_BINDING","SOURCE_INTEGRATION_PATH","SOURCE_MANIFEST","STALE_MAIN","STALE_OR_FORK_PR","STS_RESULT","TOKEN_UNAVAILABLE","TRANSPORT_ACTUAL_EXPANDED_POPULATION_DIFFERS","TRANSPORT_AUTHENTICATED_EXACT_GENERATION_EVIDENCE_READ_FAILED","TRANSPORT_AUTHORIZED_PRIVATE_EVIDENCE_READ_CREDENTIAL_IS_UNAVAILABLE","TRANSPORT_COMPRESSED_PRIVATE_MEMBER_SIZE_DIGEST_ENCODING_DIFFERS","TRANSPORT_EXPANDED_PRIVATE_MEMBER_SIZE_DIGEST_DIFFERS","TRANSPORT_EXPANDED_PRIVATE_POPULATION_DIFFERS_FROM_IMMUTABLE_DESCRIPTOR","TRANSPORT_EXPANDED_PRIVATE_POPULATION_EXCEEDS_ITS_FIXED_BOUND","TRANSPORT_GIT_REFS_MUST_REMAIN_A_DIRECTORY","TRANSPORT_GOOGLE_GENERATION_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","TRANSPORT_GOOGLE_OBJECT_METADATA_DIFFERS_FROM_IMMUTABLE_GENERATION","TRANSPORT_INVALID_BOUNDED_PRIVATE_MEMBER_ENCODING","TRANSPORT_INVALID_BUNDLE_COMMITMENT","TRANSPORT_INVALID_EXPANDED_PRIVATE_BUNDLE_BOUND","TRANSPORT_INVALID_IMMUTABLE_SOURCE_IDENTITY","TRANSPORT_INVALID_PRIVATE_MEMBER_POPULATION","TRANSPORT_ORIGINAL_PATH_RELOCATION_COMMITMENTS_DIFFER","TRANSPORT_PRIVATE_BUNDLE_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","TRANSPORT_PRIVATE_BUNDLE_SOURCE_DIFFERS","TRANSPORT_PRIVATE_CUSTODY_MUST_NAME_ONE_BOUNDED_EXACT_GENERATION","TRANSPORT_PRIVATE_EXTRACTION_DID_NOT_PRESERVE_EXACT_REGULAR_FILE_BYTES","TRANSPORT_PRIVATE_EXTRACTION_PARENT_MUST_NOT_BE_A_SYMLINK","TRANSPORT_PRIVATE_EXTRACTION_REQUIRES_A_FRESH_ABSOLUTE_DIRECTORY","TRANSPORT_PRIVATE_MEMBER_ESCAPES_EXTRACTION","TRANSPORT_PRIVATE_MEMBER_FILE_DIRECTORY_COLLISION","TRANSPORT_PRIVATE_MEMBER_INVENTORY_CARDINALITY_DIFFERS","TRANSPORT_PRIVATE_MEMBER_INVENTORY_DIFFERS","TRANSPORT_PRIVATE_MEMBER_PATH_PREFIX_CASE_COLLISION","TRANSPORT_PRIVATE_MEMBER_TRAVERSES_SYMLINK","TRANSPORT_PRIVATE_TRANSPORT_DESCRIPTOR_REQUIRED","TRANSPORT_REPEATED_OR_CASE_COLLIDING_PRIVATE_MEMBER","TRANSPORT_SUCCESSOR_TRANSPORT_IS_BUSINESS_ONLY","TRANSPORT_UNSAFE_PORTABLE_MEMBER_PATH","TRANSPORT_UNSUPPORTED_EVIDENCE_HOST_PATH","TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_KIND","TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_NO_ENCODING_FALLBACK_IS_PERMITTED","TRUST_DIGEST","TRUST_FIELDS","TRUST_PROFILE","UNCLASSIFIED","V2_CHALLENGE_REQUIRED","VERIFIER","VERIFIER_MEMBER","VERIFIER_POPULATION","WIF_AUDIENCE","WORKER_ABSOLUTE_PHYSICAL_PATH_REQUIRED","WORKER_BUNDLE_REDIRECTS","WORKER_CLOSED_WORKER_INPUT_REQUIRED","WORKER_COMPLETE_EXTRACTED_INVENTORY_DIFFERS","WORKER_COMPLETE_INVENTORY_CARDINALITY_DIFFERS","WORKER_EXACT_INPUT_BINDING_REQUIRED","WORKER_FINITE_RECORDED_PRODUCER_MAP_REQUIRED","WORKER_FINITE_REGULAR_BUNDLE_POPULATION_REQUIRED","WORKER_FIXED_FRESH_PROCESS_FLAGS_REQUIRED","WORKER_LOADER_ENVIRONMENT_REFUSED","WORKER_MEMBER_CASE_COLLISION","WORKER_MEMBER_CHANGED_DURING_INVENTORY","WORKER_MEMBER_PREFIX_COLLISION","WORKER_ORIGINAL_PATH_REMAINS_AVAILABLE","WORKER_PHYSICAL_PATH_IDENTITY_DIFFERS","WORKER_PHYSICAL_PATH_REDIRECTS","WORKER_PINNED_NODE22_REQUIRED","WORKER_PRIVATE_POPULATION_CHANGED_DURING_CORE_REPLAY","WORKER_RECORDED_CLOSURE_SUBSET_DIFFERS","WORKER_RECORDED_CORE_SOURCE_DIFFERS","WORKER_RECORDED_HELPER_NOT_SELECTED","WORKER_RECORDED_PRODUCER_BINDING_INVALID","WORKER_REGULAR_PHYSICAL_PATH_REQUIRED","WORKER_RELOCATION_COMMITMENT_DIFFERS","WORKER_RUNTIME_CHANGED_DURING_CORE_REPLAY","WORKER_SAFE_MEMBER_REQUIRED","WORKER_SELECTED_RUNTIME_CHANGED","WORKER_SOURCE_MANIFEST_COMMITMENT_DIFFERS","WORKER_UNCHANGED_CORE_REPLAY_INCOMPLETE","WORKER_UNCHANGED_MEMBER_EXPANDED_BYTE_CAP_EXCEEDED","WORKER_UNIQUE_ORIGINAL_ROLE_ROOT_REQUIRED","WORKER_WORKER_INPUT_CHANGED","WORKER_WORKER_METADATA_BOUND_EXCEEDED","WORKER_WORKER_PROFILE_DIFFERS","WORKER_WORKER_RESULT_BOUND_EXCEEDED","WORKFLOW","WORKFLOW_AUTHORITY","WORKFLOW_ID","ZIP_CENTRAL","ZIP_CONTENT","ZIP_DATA_DESCRIPTOR","ZIP_DIRECTORY","ZIP_FLAGS","ZIP_LOCAL","ZIP_LOCAL_CONTENT","ZIP_LOCAL_NAME","ZIP_MEMBER","ZIP_NAME"])
_NATIVE_CODES = frozenset(["EACCES","EAGAIN","EBADF","EBUSY","ECHILD","ECONNREFUSED","ECONNRESET","EEXIST","EFAULT","EFBIG","EINTR","EINVAL","EIO","EISDIR","EMFILE","ENAMETOOLONG","ENFILE","ENOENT","ENOMEM","ENOSPC","ENOTDIR","ENOTEMPTY","ENOTSUP","EPERM","EPIPE","ETIMEDOUT","ERR_BUFFER_TOO_LARGE","ERR_FS_FILE_TOO_LARGE","ERR_INVALID_ARG_TYPE","ERR_OUT_OF_RANGE","ENOBUFS"])
_SIGNALS = frozenset(["SIGABRT","SIGALRM","SIGBUS","SIGFPE","SIGHUP","SIGILL","SIGINT","SIGKILL","SIGPIPE","SIGQUIT","SIGSEGV","SIGTERM","SIGTRAP"])
_NATIVE_ERRNOS = {getattr(errno, name): name for name in _NATIVE_CODES if hasattr(errno, name)}
_OWN_REFUSALS = {"BUSINESS_HOSTED_" + code: code for code in ["ABSOLUTE_PATH","CHALLENGE_CONSTRUCTION","CHALLENGE_DATE","CHALLENGE_DUPLICATE","CHALLENGE_DURATION","CHALLENGE_FILE","CHALLENGE_FILES","CHALLENGE_IDENTITY","CHALLENGE_JOIN","CHALLENGE_PACKAGE","CHALLENGE_REQUESTER","CHALLENGE_UNEXPECTED_FILES","CHILD_DIAGNOSTIC","CHILD_FAILURE","CHILD_OUTPUT_BOUND","CHILD_TIMEOUT","CLI","CLIENT_APPCHECK_FIELDS","CLIENT_APPCHECK_JOIN","CLIENT_BACKEND_JOIN","CLIENT_CHALLENGE_TIME","CLIENT_CLOSURE_TIME","CLIENT_CORE_FIELDS","CLIENT_CORE_JOIN","CLIENT_IDENTITY_FIELDS","CLIENT_INPUT_BOUND","CLIENT_INPUT_COMMITMENT","CLIENT_INPUT_FIELDS","CLIENT_INPUT_SELECTION","CLIENT_MESSAGE_FIELDS","CLIENT_MESSAGE_JOIN","CLIENT_OUTPUT_AUTHORITY","CLIENT_OUTPUT_BOUND","CLIENT_OUTPUT_FIELDS","CLIENT_OUTPUT_PROFILE","CLIENT_OUTPUT_VERSION","CLIENT_POINTER_FIELDS","CLIENT_POINTER_JOIN","CLIENT_POLICY_APPCHECK","CLIENT_POLICY_BINDING_SOURCE","CLIENT_POLICY_CANDIDATE_TYPE","CLIENT_POLICY_CLOSURE_JOIN","CLIENT_POLICY_CORE_JOIN","CLIENT_POLICY_FIELDS","CLIENT_POLICY_POINTER","CLIENT_POLICY_POINTER_JOIN","CLIENT_POLICY_PRESERVED_DIGEST","CLIENT_POLICY_RELEASE","CLIENT_POLICY_SCOPE","CLIENT_POLICY_SOURCE_JOIN","CLIENT_PRODUCER","CLIENT_UNEXPECTED_CHALLENGE","CONSUMER_AUTHORITY","CONSUMER_CANDIDATE_FIELDS","CONSUMER_CANDIDATE_ROUTE","CONSUMER_COMMITMENT_FIELDS","CONSUMER_COMMITMENT_JOIN","CONSUMER_CORE_FIELDS","CONSUMER_CORE_JOIN","CONSUMER_DESCRIPTOR_JOIN","CONSUMER_OUTPUT_BOUND","CONSUMER_OUTPUT_DIGEST","CONSUMER_OUTPUT_FIELDS","CONSUMER_OUTPUT_IDENTITY","CONSUMER_OUTPUT_VERSION","CONSUMER_POINTER_FIELDS","CONSUMER_POINTER_IDENTITY","CONSUMER_SOURCE_FIELDS","CONSUMER_SOURCE_IDENTITY","CONSUMER_TRANSPORT_COMMITMENT","CONSUMER_VERIFIER_FIELDS","CORE_MEMBER","CORE_POPULATION","CORE_SOURCE","EXTERNAL_CONFIG_COMMITMENT","EXTRA_CLIENT_OUTPUT","EXTRA_CONSUMER_OUTPUT","EXTRA_REPLAY_OUTPUT","HOSTED_PRODUCER","ISOLATED_PYTHON_REQUIRED","JSON_BOUND","LAUNCHER_IDENTITY","LAUNCH_INPUT","MODE","NODE_IDENTITY","OUTPUT","PATH_REDIRECT","PLATFORM_INPUT","PRODUCER_IDENTITY","PRODUCER_PATH","PROTECTED_HOSTED_RUNNER_REQUIRED","PYTHON_IDENTITY","REGULAR_PATH","REPLAY_CHALLENGE_TIME","REPLAY_CLIENT_SELECTION","REPLAY_DATE","REPLAY_OUTPUT_BOUND","REPLAY_OUTPUT_FIELDS","REPLAY_OUTPUT_LIMITS","REPLAY_PLATFORM","REPLAY_PRODUCER","REPLAY_TIME","REPLAY_UNEXPECTED_CLIENT","SOURCE_INTEGRATION","SOURCE_INTEGRATION_BINDING","SOURCE_INTEGRATION_PATH","TRUST_FIELDS","TRUST_PROFILE","UNEXPECTED_REPLAY_OUTPUT","V2_CHALLENGE_REQUIRED","V2_CLIENT_SELECTION_REQUIRED","VERIFIER_POPULATION","WINDOWS_SUPERVISOR_PRODUCER"]}
_FAILURE = {}

def _reset_failure():
    _FAILURE.clear()
    _FAILURE.update(stage="ENTRY_INPUT", primary=None, childExit=None, childSignal=None,
                    nativeCode=None, workerExit=None, workerSignal=None, workerCleanupFailed=False,
                    cleanupFailed=False, childCleanupFailed=False)

def _phase(value):
    _FAILURE["stage"] = value

def _remember_failure(error):
    if _FAILURE["primary"] is not None:
        return
    try:
        reason = "UNCLASSIFIED"
        if type(error) is ValueError:
            args = BaseException.args.__get__(error, ValueError)
            if type(args) is tuple and len(args) == 1 and type(args[0]) is str:
                reason = _OWN_REFUSALS.get(args[0], "UNCLASSIFIED")
        if isinstance(error, (TimeoutError, subprocess.TimeoutExpired)):
            reason = "TIMEOUT"
        elif isinstance(error, OSError):
            reason = "NATIVE_FAILURE"
            number = OSError.errno.__get__(error, OSError)
            _FAILURE["nativeCode"] = _NATIVE_ERRNOS.get(number) if type(number) is int else None
        _FAILURE["primary"] = {"stage": _FAILURE["stage"], "reason": reason}
    except BaseException:
        _FAILURE["primary"] = {"stage": "ENTRY_INPUT", "reason": "UNCLASSIFIED"}
        _FAILURE["nativeCode"] = None

def _child_exit(code):
    if type(code) is int and -127 <= code <= 4294967295:
        _FAILURE["childExit"] = code if code >= 0 else None
        _FAILURE["childSignal"] = -code if code < 0 else None

def _remember_child_record(raw):
    prefix = b"Business hosted replay failed; no result is admissible. "
    if not isinstance(raw, bytes) or not 0 < len(raw) <= 512 or not raw.startswith(prefix):
        return
    try:
        payload = raw[len(prefix):]
        value = json.loads(payload)
        if (not isinstance(value, dict) or set(value) != {"schemaVersion", "stage", "reason", "nativeCode", "workerExit", "workerSignal", "workerCleanupFailed", "cleanupFailed"}
                or type(value["schemaVersion"]) is not int or value["schemaVersion"] != 1
                or value["stage"] not in _NODE_STAGES or value["reason"] not in _NODE_REASONS
                or (value["nativeCode"] is not None and value["nativeCode"] not in _NATIVE_CODES)
                or (value["workerExit"] is not None and (type(value["workerExit"]) is not int or not 0 <= value["workerExit"] <= 4294967295))
                or (value["workerSignal"] is not None and value["workerSignal"] not in _SIGNALS)
                or type(value["workerCleanupFailed"]) is not bool
                or type(value["cleanupFailed"]) is not bool
                or json.dumps(value, separators=(",", ":")).encode("ascii") + b"\n" != payload):
            return
        if _FAILURE["primary"] is None:
            _FAILURE["primary"] = {"stage": value["stage"], "reason": value["reason"]}
        _FAILURE["childCleanupFailed"] = value["cleanupFailed"]
        for key in ("nativeCode", "workerExit", "workerSignal", "workerCleanupFailed"):
            _FAILURE[key] = value[key]
    except (ValueError, TypeError, UnicodeError):
        return

_FALLBACK_FAILURE = b'Protected business replay failed; no result is admissible. {"schemaVersion":1,"stage":"ENTRY_INPUT","reason":"UNCLASSIFIED","nativeCode":null,"childExit":null,"childSignal":null,"workerExit":null,"workerSignal":null,"workerCleanupFailed":false,"cleanupFailed":false,"childCleanupFailed":false}\n'

def _failure_line():
    try:
        selected = _FAILURE["primary"] or {"stage": _FAILURE["stage"], "reason": "UNCLASSIFIED"}
        value = {"schemaVersion": 1, **selected,
                 **{key: _FAILURE[key] for key in ("nativeCode", "childExit", "childSignal", "workerExit", "workerSignal", "workerCleanupFailed", "cleanupFailed", "childCleanupFailed")}}
        raw = b"Protected business replay failed; no result is admissible. " + json.dumps(value, separators=(",", ":")).encode("ascii") + b"\n"
        return raw if len(raw) <= 512 else _FALLBACK_FAILURE
    except BaseException:
        return _FALLBACK_FAILURE

def _report_failure(error):
    raw = _FALLBACK_FAILURE
    try:
        _remember_failure(error)
        candidate = _failure_line()
        if type(candidate) is bytes and 0 < len(candidate) <= 512:
            raw = candidate
    except BaseException:
        pass
    try:
        os.write(2, raw)
    except BaseException:
        pass

def _refuse_arguments(_message):
    raise ValueError("BUSINESS_HOSTED_CLI")

_reset_failure()


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
PROFILE_V1 = "build31-business-hosted-recorded-replay-v1"
PROFILE_V2 = "build31-business-hosted-recorded-replay-v2"
V2_CLIENT_HELPERS = tuple("tools/release/" + name for name in (
    "business31TrustedInputV2.cjs", "business31PrivateDescriptorV2.cjs", "privateEvidenceBundle31V2.cjs"))
V2_REPLAY_HELPERS = V2_CLIENT_HELPERS + tuple("tools/release/" + name for name in (
    "business31OriginalPathReplayV2.cjs", "business31CoreWorkerV2.cjs"))


def transport_v2(trust):
    selected = (trust.get("schemaVersion") == 2 or trust.get("profile") == PROFILE_V2
                or "coreVerifier" in trust or "sourceIntegration" in trust)
    if not selected:
        return False
    need(type(trust.get("schemaVersion")) is int and trust["schemaVersion"] == 2
         and trust.get("profile") == PROFILE_V2, "TRUST_PROFILE")
    need(set(trust) == {"schemaVersion", "profile", "repository", "workflow", "verifier", "source",
                        "sourceManifestSha256", "nodeSha256", "gitSha256", "launcherSha256", "pythonSha256",
                        "wifAudience", "maximumResultAgeSeconds", "coreVerifier", "sourceIntegration"}, "TRUST_FIELDS")
    core = trust["coreVerifier"]
    need(isinstance(core, dict) and set(core) == {"commit", "tree", "files"}
         and core["commit"] == trust["source"]["commit"] and core["tree"] == trust["source"]["tree"]
         and trust["verifier"]["commit"] != core["commit"], "CORE_SOURCE")
    files = core["files"]
    need(isinstance(files, dict) and 0 < len(files) <= 256
         and all("tools/release/" + name in files for name in
                 ("business31BackendAuthority.cjs", "business31BackendClosure.cjs", "backendRuntimeEvidenceAccess31.cjs")),
         "CORE_POPULATION")
    for name, expected in files.items():
        need(isinstance(name, str) and name.startswith("tools/") and "\\" not in name and ":" not in name
             and all(part not in ("", ".", "..") for part in name.split("/"))
             and isinstance(expected, str) and re.fullmatch(r"[A-F0-9]{64}", expected) is not None, "CORE_MEMBER")
    integration = trust["sourceIntegration"]
    need(isinstance(integration, dict) and 0 < len(integration) <= 256, "SOURCE_INTEGRATION")
    for name, binding in integration.items():
        need(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_+./-]+", name) is not None
             and all(part not in ("", ".", "..") for part in name.split("/")), "SOURCE_INTEGRATION_PATH")
        need(isinstance(binding, dict) and set(binding) == {"mode", "oid", "sha256"}
             and binding["mode"] == "100644" and isinstance(binding["oid"], str)
             and re.fullmatch(r"[a-f0-9]{40}", binding["oid"]) is not None
             and isinstance(binding["sha256"], str) and re.fullmatch(r"[A-F0-9]{64}", binding["sha256"]) is not None,
             "SOURCE_INTEGRATION_BINDING")
    return True


def core_summary(trust):
    return {key: trust["coreVerifier"][key] for key in ("commit", "tree")}


def transport_commitments(trust):
    return {name: hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest().upper()
            for name, value in (("coreProducerBindingsSha256", trust["coreVerifier"]["files"]),
                                ("sourceIntegrationSha256", trust["sourceIntegration"]))}


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
    v2 = transport_v2(trust)
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
        need(all(name in files for name in REPLAY_HELPERS + (V2_REPLAY_HELPERS if v2 else ())), "REPLAY_PRODUCER")
    client_mode = client_input is not None or client_input_sha256 is not None
    need(not v2 or mode != "replay" or client_mode, "V2_CLIENT_SELECTION_REQUIRED")
    if client_mode:
        need(client_input is not None and client_input_sha256 is not None,
             "CLIENT_INPUT_SELECTION")
        read_client_input(client_input, client_input_sha256)
        need(all(name in files for name in CLIENT_HELPERS + (V2_CLIENT_HELPERS if v2 else ())), "CLIENT_PRODUCER")
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


WINDOWS_SUPERVISOR = "tools/release/runtime_supervisor.py"
# The recorded supervisor's maximum (runtime_supervisor.py refuses more and must stay unchanged). One replay
# runs three admissions, three client measurements, the download and the core worker bounded at 30 minutes.
WINDOWS_CHILD_SECONDS = 3600


def _windows_supervisor(verifier_files):
    # The unchanged trust-selected Windows owned-process supervisor: suspended
    # creation inside a kill-on-close job, bounded drained pipes, whole-tree exit.
    need(isinstance(verifier_files, dict) and WINDOWS_SUPERVISOR in verifier_files, "WINDOWS_SUPERVISOR_PRODUCER")
    path = Path(__file__).resolve().parents[2].joinpath(*WINDOWS_SUPERVISOR.split("/"))
    need(digest(regular(path)) == verifier_files[WINDOWS_SUPERVISOR], "WINDOWS_SUPERVISOR_PRODUCER")
    spec = importlib.util.spec_from_file_location("business31_hosted_windows_supervisor", path)
    need(spec is not None and spec.loader is not None, "WINDOWS_SUPERVISOR_PRODUCER")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    need(callable(getattr(module, "run_owned_process", None)), "WINDOWS_SUPERVISOR_PRODUCER")
    return module


def _run_child_windows(argv, env, owned, verifier_files):
    supervisor = _windows_supervisor(verifier_files)
    target = Path(owned) / "child-process"
    try:
        result = supervisor.run_owned_process(
            executable=argv[0], arguments=list(argv[1:]), cwd=str(owned), environment=dict(env),
            output_directory=str(target), timeout_seconds=WINDOWS_CHILD_SECONDS,
            max_output_bytes=1024 * 1024, cleanup_seconds=30)
        need(isinstance(result, dict), "CHILD_FAILURE")
        outputs = {}
        for name in ("stdout", "stderr"):
            stream = target / (name + ".bin")
            outputs[name] = stream.read_bytes() if stream.is_file() else b""
        code = result.get("exitCode")
        _child_exit(code)
        if result.get("cleanupErrors") or (result.get("jobAssigned") and not result.get("treeComplete")):
            _FAILURE["cleanupFailed"] = True
        if code != 0 and len(outputs["stderr"]) <= 512:
            _remember_child_record(outputs["stderr"])
        failure = result.get("failure")
        need(failure != "timeout", "CHILD_TIMEOUT")
        need(failure != "output-bound-exceeded", "CHILD_OUTPUT_BOUND")
        need(result.get("status") == "SUCCESS" and code == 0 and result.get("treeComplete") is True
             and result.get("outputComplete") is True, "CHILD_FAILURE")
    except BaseException as error:
        _remember_failure(error)
        raise
    return outputs["stdout"], outputs["stderr"]


def run_child(argv, env, owned, verifier_files=None):
    if sys.platform == "win32":
        return _run_child_windows(argv, env, owned, verifier_files)
    return _run_child_posix(argv, env, owned)


def _run_child_posix(argv, env, owned):
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
        stderr_preview = bytearray()
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
                    if event.fileobj is child.stderr:
                        if counts[event.fileobj] <= 512:
                            stderr_preview.extend(chunk)
                        else:
                            stderr_preview.clear()
            code = child.wait(timeout=max(0.1, deadline - time.monotonic()))
            _child_exit(code)
            if code != 0 and counts[child.stderr] <= 512:
                _remember_child_record(bytes(stderr_preview))
            need(code == 0, "CHILD_FAILURE")
        except BaseException as error:
            _remember_failure(error)
            raise
        finally:
            # Only this new session is addressed. Abrupt launcher/job/host death
            # separately requires destruction of the ephemeral runner.
            try:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                finally:
                    _child_exit(child.wait(timeout=30))
            except BaseException as error:
                _FAILURE["cleanupFailed"] = True
                _remember_failure(error)
                raise
    return (Path(owned) / "child.stdout").read_bytes(), (Path(owned) / "child.stderr").read_bytes()


def sanitized_consumer_output(raw, trust, request):
    need(isinstance(raw, bytes) and 0 < len(raw) <= 32768, "CONSUMER_OUTPUT_BOUND")
    value = json.loads(raw)
    v2 = transport_v2(trust)
    if v2:
        need(type(request.get("schemaVersion")) is int and request["schemaVersion"] == 2, "V2_CHALLENGE_REQUIRED")

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
                  "distributionAuthorized"} | ({"coreVerifier"} if v2 else set()), "CONSUMER_OUTPUT_FIELDS")
    need(type(value["schemaVersion"]) is int and value["schemaVersion"] == 2
         and value["profile"] == trust["profile"] == (PROFILE_V2 if v2 else PROFILE_V1),
         "CONSUMER_OUTPUT_VERSION")
    exact(value["verifier"], {"commit", "tree"}, "CONSUMER_VERIFIER_FIELDS")
    exact(value["source"], {"commit", "tree", "functionsTree"}, "CONSUMER_SOURCE_FIELDS")
    if v2:
        exact(value["coreVerifier"], {"commit", "tree"}, "CONSUMER_CORE_FIELDS")
        need(value["coreVerifier"] == core_summary(trust), "CONSUMER_CORE_JOIN")
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
    exact(value["commitments"], {"bundleSha256", "membersSha256", "relocationSha256", "sourceManifestSha256"}
          | ({"coreProducerBindingsSha256", "sourceIntegrationSha256"} if v2 else set()),
          "CONSUMER_COMMITMENT_FIELDS")
    need(all(sha256(v) for v in value["commitments"].values())
         and value["commitments"]["sourceManifestSha256"] == trust["sourceManifestSha256"],
         "CONSUMER_COMMITMENT_JOIN")
    if v2:
        need(all(value["commitments"][key] == expected for key, expected in transport_commitments(trust).items()),
             "CONSUMER_TRANSPORT_COMMITMENT")
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
    v2 = transport_v2(trust)
    exact(policy, ("schemaVersion", "profile", "verifier", "source", "candidate", "sourceManifestSha256", "bindings",
                   "descriptorPointer", "closurePointer", "decisionPointer", "release", "appCheck",
                   "policySourceVerified", "appCheckSourcePolicyVerified", *flags, *(("coreVerifier",) if v2 else ())))
    need(type(policy["schemaVersion"]) is int and policy["schemaVersion"] == (2 if v2 else 1)
         and policy["profile"] == ("build31-business-client-policy-v2" if v2 else "build31-business-client-policy-v1")
         and policy["policySourceVerified"] is True and policy["appCheckSourcePolicyVerified"] is True
         and all(policy[key] is False for key in flags), "CLIENT_POLICY_SCOPE")
    if v2:
        exact(policy["coreVerifier"], ("commit", "tree"))
        need(policy["coreVerifier"] == core_summary(trust), "CLIENT_POLICY_CORE_JOIN")
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
    v2 = transport_v2(trust)
    client = value["client"]
    verified = ("gitCustodyVerified", "dedicatedOwnerDecisionDeltasVerified",
                "descriptorPreparationVerified", "recordedSemanticsValidated", "appCheckSourcePolicyVerified")
    unverified = ("independentlySelectedInputsAuthenticated",
                  "executingHostAuthenticated", "humanIdentityAuthenticated", "trustedClockAuthenticated",
                  "platformIdentityAuthenticated", "credentialAccessAuthorized", "backendDeploymentAuthorized",
                  "constructionAuthorized", "signingAuthorized", "distributionAuthorized")
    exact(client, ("schemaVersion", "profile", "ownerPointer", "decisionPointer", "originalMessage",
                   "appCheck", "publicClosureRecordedAtUtc", "policy", *verified, *unverified,
                   *(("coreVerifier",) if v2 else ())), "CLIENT_OUTPUT_FIELDS")
    need(type(client["schemaVersion"]) is int and client["schemaVersion"] == (3 if v2 else 2)
         and client["profile"] == ("build31-business-client-compatibility-v2" if v2 else "build31-business-client-compatibility-v1"), "CLIENT_OUTPUT_PROFILE")
    if v2:
        exact(client["coreVerifier"], ("commit", "tree"), "CLIENT_CORE_FIELDS")
        need(client["coreVerifier"] == core_summary(trust), "CLIENT_CORE_JOIN")
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
    v2 = transport_v2(trust)
    version = request.get("schemaVersion")
    expected = {"schemaVersion", "documentType", "profile", "verifier", "source", "candidate", "descriptorPointer",
                "closurePointer", "commitments", "platform", "startedAtUtc", "completedAtUtc", "recordedSemanticsReplayed", "limits"}
    if version == 2:
        expected.update(("challenge", "client"))
    if v2:
        need(type(version) is int and version == 2, "V2_CHALLENGE_REQUIRED")
        expected.add("coreVerifier")
    need(type(version) is int and version in (1, 2) and isinstance(value, dict) and set(value) == expected
         and type(value["schemaVersion"]) is int and value["schemaVersion"] == version
         and value["documentType"] == "build31-business-hosted-result"
         and value["profile"] == trust["profile"] == (PROFILE_V2 if v2 else PROFILE_V1)
         and value["recordedSemanticsReplayed"] is True, "REPLAY_OUTPUT_FIELDS")
    limits = value["limits"]
    need(isinstance(limits, dict) and set(limits) == {"ownerIdentityAuthenticated", "originalProcessExecutionAuthenticated",
                                                    "deploymentAuthorized", "constructionAuthorized", "distributionAuthorized"}
         and all(item is False for item in limits.values()), "REPLAY_OUTPUT_LIMITS")
    # Reuse only the existing closed identity/commitment contract, internally;
    # this temporary object is never returned as authenticated public evidence.
    projection = {key: value[key] for key in ("profile", "verifier", "source", "candidate", "descriptorPointer", "closurePointer", "commitments")}
    if v2:
        projection["coreVerifier"] = value["coreVerifier"]
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
    _reset_failure()
    _phase("INPUT_STAGING")
    # Linux, or Windows for evidence recorded on Windows (the recorded core's
    # relocation path layer is only complete for its own host convention).
    need(sys.platform in ("linux", "win32"), "PROTECTED_HOSTED_RUNNER_REQUIRED")
    parent = regular(args.private_parent, directory=True)
    destination = None
    if args.mode == "replay":
        destination = Path(args.output)
        need(destination.is_absolute() and destination.name == "business31-hosted-result.json"
             and not destination.exists(), "OUTPUT")
        regular(destination.parent, directory=True)
    body_error = None
    entered = False
    _phase("PRIVATE_SCRATCH")
    try:
        with tempfile.TemporaryDirectory(prefix="business31-launch-", dir=parent) as owned:
            entered = True
            try:
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
                _phase("LAUNCH_PLAN")
                argv, env = launch_plan(args.mode, args.node, args.trust, args.trust_sha256, input_file, str(staged), owned,
                                        client_input, client_sha256)
                # No shell, no inherited preloads/caches, no candidate-selected entry.
                _phase("CHILD_EXECUTION")
                verifier_files = None
                if sys.platform == "win32":
                    need(digest(regular(args.trust)) == args.trust_sha256, "EXTERNAL_CONFIG_COMMITMENT")
                    verifier_files = bounded_json(regular(args.trust))["verifier"]["files"]
                stdout, stderr = run_child(argv, env, owned, verifier_files)
                _phase("STDIO_GATE")
                need(not stderr, "CHILD_DIAGNOSTIC")
                _phase("RESULT_SANITIZATION")
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
            except BaseException as error:
                body_error = error
                _remember_failure(error)
                raise
            finally:
                _phase("PRIVATE_CLEANUP")
    except BaseException as error:
        if entered and error is not body_error:
            _FAILURE["cleanupFailed"] = True
        _remember_failure(error)
        raise
    # Publish only after private cleanup succeeds, never raw helper diagnostics.
    _phase("RESULT_PUBLICATION")
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
    parser = argparse.ArgumentParser(add_help=False)
    parser.error = _refuse_arguments
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
    except BaseException as error:
        _report_failure(error)
        raise SystemExit(1)
