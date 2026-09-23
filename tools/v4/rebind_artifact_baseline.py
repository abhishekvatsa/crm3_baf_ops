"""Re-bind the approved artifact baseline as one complete, validated transition.

A cutover that has to change an approved artifact source path withdraws
construction authority, because the source no longer matches the baseline the
version approval selected. Restoring it means selecting a new baseline. That is
a source-approval decision, not a field edit, and it touches five records that
must all agree on the same approval bytes.

The first version of this tool changed three records, compared no pubspec, and
wrote the approval before discovering whether the rest of the inputs were
usable. External review reproduced all three defects. This version separates
the work so that nothing is written until the whole transition is known to be
coherent:

    inspect_inputs   load and validate every record, the source delta and the
                     decision; refuse on anything unexpected
    build_proposal   a pure transformation: serialise the approval once, hash
                     those exact bytes once, derive every pointer from that one
                     digest
    validate_proposal re-read the proposal as a consumer would and require the
                     records to agree
    emit_proposal    stage every file, then move them into place, so a refusal
                     cannot leave a partially rebound set of records

It authorises nothing. A successful run reports a validated proposal; actual
construction remains subject to the protected workflow and its reviewer.

Usage
    python tools/v4/rebind_artifact_baseline.py --target-commit <M> \\
        --expected-delta <manifest.json> [--decision <decision.json>] [--write]

Without --write it validates and reports. --write additionally requires the
owner-confirmed rebind decision.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = "release/production-release-policy.json"
LEDGER = "release/build-number-ledger.json"
STATE = "release/current-successor-state.json"
VERSION_POINTER = "release/approvals/version-policy-approval.json"
POLICY_SCRIPT = "tools/release/Test-ProductionReleasePolicy.ps1"
EXPECTED_SLUG = "abhishekvatsa/crm3_baf_ops"
REBIND_SUFFIX = "_AWAITING_ARTIFACT_SOURCE_REBIND"
COMMIT = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9A-Fa-f]{64}$")
VERSION_LINE = re.compile(r"^version:[ \t]*(\S+)[ \t]*$", re.MULTILINE)


class RebindRefused(Exception):
    """Raised for every refusal, so no caller mistakes one for a soft warning."""


def need(condition: object, message: str) -> None:
    if not condition:
        raise RebindRefused(message)


def git(*arguments: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), *arguments],
        capture_output=True, text=True,
    )
    if check and result.returncode != 0:
        raise RebindRefused(
            f"git {' '.join(arguments)} failed: {result.stderr.strip()}"
        )
    return result.stdout.strip()


def git_object(commit: str, path: str) -> str | None:
    """The object id at a path, or None when the path is genuinely absent.

    A failure that is not 'this path does not exist' is a refusal, so a corrupt
    object or the wrong repository cannot be read as an absent path.
    """
    result = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), "rev-parse", "--verify",
         f"{commit}:{path}"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    stderr = result.stderr.lower()
    if "does not exist" in stderr or "unknown revision" in stderr or "not a valid object" in stderr:
        return None
    raise RebindRefused(f"could not read {commit}:{path}: {result.stderr.strip()}")


def git_text(commit: str, path: str) -> str:
    return subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), "show", f"{commit}:{path}"],
        capture_output=True, text=True, check=True,
    ).stdout


def read_json(relative: str) -> dict:
    absolute = ROOT / relative
    need(absolute.is_file(), f"{relative} is missing")
    need(not absolute.is_symlink(), f"{relative} is a symlink")
    text = absolute.read_text(encoding="utf-8")
    keys: list[str] = []

    def duplicate_guard(pairs: list[tuple[str, object]]) -> dict:
        names = [name for name, _ in pairs]
        if len(names) != len(set(names)):
            keys.append("duplicate")
        return dict(pairs)

    value = json.loads(text, object_pairs_hook=duplicate_guard)
    need(not keys, f"{relative} contains duplicate JSON keys")
    need(isinstance(value, dict), f"{relative} is not a JSON object")
    return value


def approved_artifact_paths() -> list[str]:
    """Read the path list from the production policy rather than copying it.

    A copied list silently diverges the first time the policy gains a path.
    """
    text = (ROOT / POLICY_SCRIPT).read_text(encoding="utf-8")
    match = re.search(
        r"\$ApprovedArtifactExactSourcePaths\s*=\s*@\((.*?)\n\)", text, re.DOTALL
    )
    need(match is not None, "could not read the approved artifact source paths")
    paths = re.findall(r"'([^']+)'", match.group(1))
    need(len(paths) >= 10, "the approved artifact source path list looks wrong")
    return paths


def normalised_pubspec(text: str, expected_version: str | None) -> str:
    """The pubspec with only the governed version declaration normalised.

    Mirrors the production verifier: the version may change, nothing else may.
    """
    found = VERSION_LINE.findall(text)
    need(len(found) == 1, "the pubspec must declare exactly one version")
    if expected_version is not None:
        need(
            found[0] == expected_version,
            f"the proposed pubspec declares {found[0]}, expected {expected_version}",
        )
    return VERSION_LINE.sub("version: <normalised>", text)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def serialise(document: dict) -> bytes:
    """One serialisation, used for both the hash and the bytes written."""
    return (json.dumps(document, indent=2) + "\n").encode("utf-8")


# --------------------------------------------------------------- inspection


def inspect_inputs(target: str, delta_path: str, decision_path: str | None) -> dict:
    need(COMMIT.match(target or ""), "the target commit must be 40 hex characters")

    remotes = git("remote", "-v")
    need(EXPECTED_SLUG in remotes, f"this checkout is not {EXPECTED_SLUG}")
    need(not git("status", "--porcelain"), "the working tree is not clean")

    policy = read_json(POLICY)
    ledger = read_json(LEDGER)
    state = read_json(STATE)
    pointer = read_json(VERSION_POINTER)

    build = policy.get("release", {}).get("buildNumber")
    need(isinstance(build, int), "the policy does not record a build number")
    version_policy = policy.get("versionPolicy", {})
    need(
        version_policy.get("buildNumber") in (None, build),
        "the policy version section names a different build",
    )
    need(
        pointer.get("buildNumber") == build,
        f"the version pointer names build {pointer.get('buildNumber')}, policy says {build}",
    )

    approval_path = version_policy.get("sourceDocumentFile")
    need(isinstance(approval_path, str), "the policy does not name a source approval")
    approval = read_json(approval_path)
    approval_bytes = (ROOT / approval_path).read_bytes()
    current_digest = digest(approval_bytes)

    # Every active pointer must currently agree, or the starting state is already
    # incoherent and a re-bind would paper over it.
    for label, value in (
        ("the policy", version_policy.get("sourceDocumentSha256")),
        ("the version pointer", pointer.get("sourceDocumentSha256")),
    ):
        need(
            isinstance(value, str) and value.upper() == current_digest,
            f"{label} does not currently pin the source approval bytes",
        )
    need(
        pointer.get("sourceDocumentFile") == approval_path,
        "the version pointer names a different source approval than the policy",
    )

    entries = [e for e in ledger.get("entries", []) if e.get("buildNumber") == build]
    need(len(entries) == 1, f"expected exactly one ledger entry for build {build}, found {len(entries)}")
    entry = entries[0]
    need(
        str(entry.get("versionApprovalDocumentSha256", "")).upper() == current_digest,
        "the ledger does not currently pin the source approval bytes",
    )
    need(
        entry.get("status") == "source-reserved-awaiting-remote-consumption",
        f"the ledger entry is {entry.get('status')}, which is not an unconsumed reservation",
    )
    for consumed in ("githubRunId", "githubArtifactId", "artifactConstructed"):
        need(entry.get(consumed) in (None, False), f"the ledger entry already records {consumed}")

    # The lifecycle must be the pending rebind state; construction authority is
    # derived, never assumed.
    need(
        str(state.get("status", "")).endswith(REBIND_SUFFIX),
        f"the successor state is {state.get('status')}, not awaiting an artifact source rebind",
    )
    current_source = state.get("authorityPlanes", {}).get("currentSource", {})
    need(
        current_source.get("artifactConstructionAuthority") is False,
        "construction authority is already true; there is nothing to re-bind",
    )

    # A is the previously approved artifact baseline. D is the deployed backend
    # source. They are separate identities and must not be conflated.
    baseline = approval.get("sourceBaseline", {})
    previous = baseline.get("commit")
    need(COMMIT.match(previous or ""), "the approval does not record a baseline commit")
    deployed = state.get("authorityPlanes", {}).get("deployedBackend", {}).get(
        "functionFleetSourceCommit")
    need(COMMIT.match(deployed or ""), "the state does not record a deployed backend source")

    need(previous != target, "the baseline already names the target commit")
    git("merge-base", "--is-ancestor", previous, target)
    need(git("rev-parse", f"{target}^{{commit}}") == target, "the target is not a commit")
    target_tree = git("rev-parse", f"{target}^{{tree}}")

    # The declared delta is the permission. A directory exemption would admit
    # any change inside it, including a replaced gate or a deleted test tree.
    manifest = json.loads(Path(delta_path).read_text(encoding="utf-8"))
    need(manifest.get("fromCommit") == previous, "the delta manifest names a different previous baseline")
    need(manifest.get("toCommit") == target, "the delta manifest names a different target")
    declared = manifest.get("paths")
    need(isinstance(declared, dict) and declared, "the delta manifest declares no paths")

    observed: dict[str, dict[str, str | None]] = {}
    for path in approved_artifact_paths():
        if path == "pubspec.yaml":
            continue
        before, after = git_object(previous, path), git_object(target, path)
        if before != after:
            observed[path] = {"before": before, "after": after}
    need(
        set(observed) == set(declared),
        "the source delta differs from the manifest: "
        f"observed {sorted(observed)}, declared {sorted(declared)}",
    )
    for path, moved in observed.items():
        stated = declared[path]
        need(
            stated.get("before") == moved["before"] and stated.get("after") == moved["after"],
            f"{path} moved to object identities the manifest does not declare",
        )
        need(moved["after"] is not None, f"{path} is deleted at the target commit")

    # pubspec is compared separately, with only the governed version normalised,
    # and before the baseline moves. Afterwards it would compare M with itself.
    expected_version = f"{pointer.get('versionName')}+{build}" if pointer.get("versionName") else None
    before_pubspec = normalised_pubspec(git_text(previous, "pubspec.yaml"), None)
    after_pubspec = normalised_pubspec(git_text(target, "pubspec.yaml"), expected_version)
    need(
        before_pubspec == after_pubspec,
        "pubspec.yaml differs beyond its version declaration",
    )

    decision = None
    if decision_path is not None:
        decision = json.loads(Path(decision_path).read_text(encoding="utf-8"))
        need(
            decision.get("documentType") == "governed-artifact-source-rebind-decision",
            "the decision document is not an artifact source rebind decision",
        )
        need(decision.get("confirmed") is True, "the rebind decision is not confirmed")
        need(decision.get("previousBaselineCommit") == previous, "the decision names a different previous baseline")
        need(decision.get("targetCommit") == target, "the decision names a different target commit")
        need(
            str(decision.get("sourceApprovalSha256", "")).upper() == current_digest,
            "the decision does not name the source approval bytes it was made against",
        )
        need(decision.get("deployedBackendCommit") == deployed,
             "the decision names a different deployed backend source")

    return {
        "build": build, "policy": policy, "ledger": ledger, "state": state,
        "pointer": pointer, "approval": approval, "approvalPath": approval_path,
        "previous": previous, "deployed": deployed, "target": target,
        "targetTree": target_tree, "currentDigest": current_digest,
        "delta": observed, "decision": decision, "entry": entry,
    }


# ------------------------------------------------------------------- build


def build_proposal(inputs: dict) -> dict:
    """Pure: validated inputs in, proposed bytes and digests out. Writes nothing."""
    approval = json.loads(json.dumps(inputs["approval"]))
    approval["sourceBaseline"]["commit"] = inputs["target"]
    approval["sourceBaseline"]["tree"] = inputs["targetTree"]
    approval_bytes = serialise(approval)
    approval_digest = digest(approval_bytes)

    policy = json.loads(json.dumps(inputs["policy"]))
    policy["versionPolicy"]["sourceDocumentSha256"] = approval_digest

    pointer = json.loads(json.dumps(inputs["pointer"]))
    pointer["sourceDocumentSha256"] = approval_digest

    ledger = json.loads(json.dumps(inputs["ledger"]))
    for entry in ledger["entries"]:
        if entry.get("buildNumber") == inputs["build"]:
            entry["versionApprovalDocumentSha256"] = approval_digest
            if "baselineCommit" in entry:
                entry["baselineCommit"] = inputs["target"]

    state = json.loads(json.dumps(inputs["state"]))
    state["authorityPlanes"]["currentSource"]["artifactConstructionAuthority"] = True
    state["status"] = str(state["status"]).replace(
        REBIND_SUFFIX, "_AWAITING_SIGNED_CONSTRUCTION"
    ).replace("_SOURCE_SUCCESSOR_", "_SOURCE_AUTHORIZED_")
    nxt = state["authorityPlanes"]["nextCandidate"]
    nxt["status"] = str(nxt.get("status", "")).replace(
        "SOURCE_SUCCESSOR_AWAITING_BUILD", "SOURCE_AUTHORIZED_AWAITING_SIGNED_BUILD"
    ).replace("_ARTIFACT_SOURCE_REBIND", "_CONSTRUCTION")

    return {
        "approvalDigest": approval_digest,
        "files": {
            inputs["approvalPath"]: approval_bytes,
            POLICY: serialise(policy),
            VERSION_POINTER: serialise(pointer),
            LEDGER: serialise(ledger),
            STATE: serialise(state),
        },
    }


# ---------------------------------------------------------------- validate


def validate_proposal(inputs: dict, proposal: dict) -> None:
    """Read the proposal back as a consumer would, before anything is written."""
    expected = proposal["approvalDigest"]
    files = proposal["files"]
    approval_bytes = files[inputs["approvalPath"]]
    need(digest(approval_bytes) == expected, "the proposed approval does not hash to its own digest")

    policy = json.loads(files[POLICY])
    pointer = json.loads(files[VERSION_POINTER])
    ledger = json.loads(files[LEDGER])
    state = json.loads(files[STATE])

    need(policy["versionPolicy"]["sourceDocumentSha256"] == expected,
         "the proposed policy does not pin the proposed approval")
    need(pointer["sourceDocumentSha256"] == expected,
         "the proposed version pointer does not pin the proposed approval")
    entries = [e for e in ledger["entries"] if e.get("buildNumber") == inputs["build"]]
    need(len(entries) == 1, "the proposed ledger does not hold exactly one entry for the build")
    need(entries[0]["versionApprovalDocumentSha256"] == expected,
         "the proposed ledger does not pin the proposed approval")

    approval = json.loads(approval_bytes)
    need(approval["sourceBaseline"]["commit"] == inputs["target"],
         "the proposed approval does not select the target commit")
    need(state["authorityPlanes"]["currentSource"]["artifactConstructionAuthority"] is True,
         "the proposed state does not restore construction authority")
    need(REBIND_SUFFIX not in str(state.get("status", "")),
         "the proposed state still records an awaited rebind")
    need(REBIND_SUFFIX not in str(state["authorityPlanes"]["nextCandidate"].get("status", "")),
         "the proposed next candidate still records an awaited rebind")

    # The deployed backend identity is not a function of the artifact baseline
    # and must survive the transition untouched.
    need(
        state["authorityPlanes"]["deployedBackend"]["functionFleetSourceCommit"] == inputs["deployed"],
        "the proposal moved the deployed backend source",
    )


# -------------------------------------------------------------------- emit


def emit_proposal(proposal: dict, write: bool) -> None:
    """Stage every file, then move them into place.

    A refusal while staging leaves nothing changed. The moves themselves are
    individually atomic; staging first keeps the window between them small and
    means a validation failure cannot half-apply a transition.
    """
    if not write:
        return
    staged: list[tuple[Path, Path]] = []
    try:
        for relative, data in proposal["files"].items():
            destination = (ROOT / relative).resolve()
            need(
                str(destination).startswith(str(ROOT.resolve()) + os.sep),
                f"{relative} resolves outside the checkout",
            )
            need(not (ROOT / relative).is_symlink(), f"{relative} is a symlink")
            need(destination.is_file(), f"{relative} is not a regular file")
            handle, temporary = tempfile.mkstemp(
                dir=str(destination.parent), prefix=".rebind-", suffix=".tmp"
            )
            with os.fdopen(handle, "wb") as stream:
                stream.write(data)
            staged.append((Path(temporary), destination))
        for temporary, destination in staged:
            os.replace(temporary, destination)
        staged = []
    finally:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-commit", required=True)
    parser.add_argument("--expected-delta", required=True)
    parser.add_argument("--decision")
    parser.add_argument("--write", action="store_true")
    options = parser.parse_args(argv)

    try:
        inputs = inspect_inputs(options.target_commit, options.expected_delta, options.decision)
        if options.write:
            need(inputs["decision"] is not None,
                 "--write requires the owner-confirmed rebind decision")
        proposal = build_proposal(inputs)
        validate_proposal(inputs, proposal)
        emit_proposal(proposal, options.write)
    except RebindRefused as refusal:
        print(json.dumps({"status": "REBIND_REFUSED", "reason": str(refusal)}, indent=2))
        return 1

    print(json.dumps({
        "status": "REBIND_APPLIED" if options.write else "PROPOSAL_VALIDATED",
        "noProductionActionPerformed": True,
        "previousBaseline": inputs["previous"],
        "targetBaseline": inputs["target"],
        "deployedBackendUnchanged": inputs["deployed"],
        "approvalSha256": proposal["approvalDigest"],
        "recordsUpdated": sorted(proposal["files"]),
        "sourceDelta": sorted(inputs["delta"]),
    }, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
