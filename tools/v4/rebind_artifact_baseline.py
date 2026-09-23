"""Re-bind the approved artifact baseline as one complete, validated transition.

A cutover that has to change an approved artifact source path withdraws
construction authority, because the source no longer matches the baseline the
version approval selected. Restoring it means selecting a new baseline. That is
a source-approval decision, not a field edit, and it touches five records that
must all agree on the same approval bytes.

Four boundaries, each of which review found missing in an earlier version:

  trusted source inspection
      The protected-path obligations come from the PREVIOUS APPROVED baseline,
      not from the candidate. A candidate that drops a path from its own list
      would otherwise choose the scope it is audited against, and a change
      under a dropped path would never be seen.

  retained decision authority
      The confirmed decision is recorded INTO the approval, so a later reader
      can establish which decision selected this baseline. A transient
      command-line check leaves no such evidence. Application additionally
      requires the target to be merged and to carry its own successful
      post-merge check evidence.

  safe publication
      There is no in-place writer. Three review rounds found one unsafe in a
      different way each time, so the tool now emits a complete proposal to a
      fresh directory and applying it is an ordinary reviewable commit. Git is
      the publication boundary; this tool never writes to the checkout.

  exact lifecycle validation
      The starting and resulting states must be the exact expected values for
      this build, not merely strings carrying or lacking a suffix.

It authorises nothing and changes no active record. Construction remains
subject to the protected workflow and its required reviewer.

Usage
    python tools/v4/rebind_artifact_baseline.py --target-commit <M> \\
        --expected-delta <manifest.json> [--decision <decision.json>] \\
        [--post-merge-evidence <run.json>] [--main-ref origin/main] \
        [--out <fresh directory>]
"""

from __future__ import annotations

import argparse
import hashlib
from datetime import datetime, timezone
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = "release/production-release-policy.json"
LEDGER = "release/build-number-ledger.json"
STATE = "release/current-successor-state.json"
VERSION_POINTER = "release/approvals/version-policy-approval.json"
POLICY_SCRIPT = "tools/release/Test-ProductionReleasePolicy.ps1"
EXPECTED_SLUG = "abhishekvatsa/crm3_baf_ops"
EXPECTED_REMOTES = {
    "https://github.com/abhishekvatsa/crm3_baf_ops.git",
    "https://github.com/abhishekvatsa/crm3_baf_ops",
    "git@github.com:abhishekvatsa/crm3_baf_ops.git",
}
COMMIT = re.compile(r"^[0-9a-f]{40}$")
VERSION_LINE = re.compile(r"^version:[ \t]*(\S+)[ \t]*$", re.MULTILINE)
PATH_LIST = re.compile(r"\$ApprovedArtifactExactSourcePaths\s*=\s*@\((.*?)\n\)", re.DOTALL)


class RebindRefused(Exception):
    """Every refusal, so no caller mistakes one for a soft warning."""


def need(condition: object, message: str) -> None:
    if not condition:
        raise RebindRefused(message)


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), *arguments],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RebindRefused(f"git {' '.join(arguments)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def git_object(commit: str, path: str) -> str | None:
    """The object id at a path, or None when the path is genuinely absent."""
    result = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), "rev-parse", "--verify",
         f"{commit}:{path}"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    stderr = result.stderr.lower()
    if any(hint in stderr for hint in ("does not exist", "unknown revision", "not a valid object")):
        return None
    raise RebindRefused(f"could not read {commit}:{path}: {result.stderr.strip()}")


def git_text(commit: str, path: str) -> str:
    result = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), "show", f"{commit}:{path}"],
        capture_output=True, text=True,
    )
    need(result.returncode == 0, f"could not read {commit}:{path}")
    return result.stdout


def read_json_bytes(data: bytes, label: str) -> dict:
    duplicates: list[str] = []

    def guard(pairs: list[tuple[str, object]]) -> dict:
        names = [name for name, _ in pairs]
        if len(names) != len(set(names)):
            duplicates.append(label)
        return dict(pairs)

    value = json.loads(data.decode("utf-8"), object_pairs_hook=guard)
    need(not duplicates, f"{label} contains duplicate JSON keys")
    need(isinstance(value, dict), f"{label} is not a JSON object")
    return value


def read_record(relative: str) -> tuple[dict, bytes]:
    absolute = ROOT / relative
    need(absolute.is_file(), f"{relative} is missing")
    need(not absolute.is_symlink(), f"{relative} is a symlink")
    data = absolute.read_bytes()
    return read_json_bytes(data, relative), data


def parse_path_list(text: str, label: str) -> list[str]:
    match = PATH_LIST.search(text)
    need(match is not None, f"could not read the approved artifact source paths from {label}")
    paths = re.findall(r"'([^']+)'", match.group(1))
    need(len(paths) >= 10, f"the approved artifact source path list in {label} looks wrong")
    return paths


def normalised_pubspec(text: str, expected_version: str | None) -> str:
    found = VERSION_LINE.findall(text)
    need(len(found) == 1, "the pubspec must declare exactly one version")
    if expected_version is not None:
        need(found[0] == expected_version,
             f"the proposed pubspec declares {found[0]}, expected {expected_version}")
    return VERSION_LINE.sub("version: <normalised>", text)


def utc_instant(value: object) -> datetime | None:
    """An explicit UTC instant, or None. No local times, no bare dates."""
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def serialise(document: dict) -> bytes:
    return (json.dumps(document, indent=2) + "\n").encode("utf-8")


# --------------------------------------------------------------- inspection


def inspect_inputs(target: str, delta_path: str, decision_path: str | None,
                   evidence_path: str | None, main_ref: str) -> dict:
    need(COMMIT.match(target or ""), "the target commit must be 40 hex characters")
    remote = git("remote", "get-url", "origin")
    need(remote in EXPECTED_REMOTES, f"origin is {remote}, which is not the expected repository")
    need(not git("status", "--porcelain"), "the working tree is not clean")

    policy, policy_bytes = read_record(POLICY)
    ledger, ledger_bytes = read_record(LEDGER)
    state, state_bytes = read_record(STATE)
    pointer, pointer_bytes = read_record(VERSION_POINTER)

    build = policy.get("release", {}).get("buildNumber")
    need(isinstance(build, int), "the policy does not record a build number")
    version_policy = policy.get("versionPolicy", {})
    need(version_policy.get("buildNumber") in (None, build),
         "the policy version section names a different build")
    need(pointer.get("buildNumber") == build,
         f"the version pointer names build {pointer.get('buildNumber')}, policy says {build}")

    approval_path = version_policy.get("sourceDocumentFile")
    need(isinstance(approval_path, str), "the policy does not name a source approval")
    approval, approval_bytes = read_record(approval_path)
    current_digest = digest(approval_bytes)
    need(approval.get("approved") is True,
         "the source approval does not record approved true; it cannot authorise a baseline")

    for label, value in (("the policy", version_policy.get("sourceDocumentSha256")),
                         ("the version pointer", pointer.get("sourceDocumentSha256"))):
        need(isinstance(value, str) and value.upper() == current_digest,
             f"{label} does not currently pin the source approval bytes")
    need(pointer.get("sourceDocumentFile") == approval_path,
         "the version pointer names a different source approval than the policy")

    entries = [e for e in ledger.get("entries", []) if e.get("buildNumber") == build]
    need(len(entries) == 1,
         f"expected exactly one ledger entry for build {build}, found {len(entries)}")
    entry = entries[0]
    need(str(entry.get("versionApprovalDocumentSha256", "")).upper() == current_digest,
         "the ledger does not currently pin the source approval bytes")
    need(entry.get("status") == "source-reserved-awaiting-remote-consumption",
         f"the ledger entry is {entry.get('status')}, which is not an unconsumed reservation")
    for consumed in ("githubRunId", "githubArtifactId", "artifactConstructed"):
        need(entry.get(consumed) in (None, False), f"the ledger entry already records {consumed}")

    # Exact lifecycle, not a suffix. A Build 30 status on a Build 29 policy, or a
    # cancelled next candidate, must not pass.
    expected_status = f"BUILD{build}_SOURCE_SUCCESSOR_BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND"
    expected_next = f"SOURCE_SUCCESSOR_AWAITING_BUILD{build}_ARTIFACT_SOURCE_REBIND"
    need(state.get("status") == expected_status,
         f"the successor state is {state.get('status')}, expected {expected_status}")
    planes = state.get("authorityPlanes", {})
    need(planes.get("nextCandidate", {}).get("status") == expected_next,
         f"the next candidate is {planes.get('nextCandidate', {}).get('status')}, expected {expected_next}")
    current_source = planes.get("currentSource", {})
    need(current_source.get("artifactConstructionAuthority") is False,
         "construction authority is already true; there is nothing to re-bind")

    baseline = approval.get("sourceBaseline", {})
    previous = baseline.get("commit")
    need(COMMIT.match(previous or ""), "the approval does not record a baseline commit")
    deployed = planes.get("deployedBackend", {}).get("functionFleetSourceCommit")
    need(COMMIT.match(deployed or ""), "the state does not record a deployed backend source")
    need(previous != target, "the baseline already names the target commit")
    git("merge-base", "--is-ancestor", previous, target)
    need(git("rev-parse", f"{target}^{{commit}}") == target, "the target is not a commit")
    target_tree = git("rev-parse", f"{target}^{{tree}}")

    # The target must actually be on the main line, not a local feature branch.
    need(main_ref.startswith("refs/remotes/") or main_ref.startswith("origin/"),
         f"the main reference {main_ref} is not a remote-tracking reference; "
         "a caller-selected local reference cannot establish the main line")
    main_tip = git("rev-parse", "--verify", main_ref)
    git("merge-base", "--is-ancestor", target, main_tip)

    # The obligations come from the previously approved source. A candidate that
    # narrows its own list must not thereby narrow what is inspected.
    approved_list = parse_path_list(git_text(previous, POLICY_SCRIPT), "the approved baseline")
    candidate_list = parse_path_list(git_text(target, POLICY_SCRIPT), "the target")
    removed = sorted(set(approved_list) - set(candidate_list))
    need(not removed,
         "the target removes protected artifact source paths from the policy: "
         + ", ".join(removed) + "; that is a change to the inspection contract and needs its own review")
    inspect_list = sorted(set(approved_list) | set(candidate_list))

    manifest = json.loads(Path(delta_path).read_text(encoding="utf-8"))
    need(manifest.get("fromCommit") == previous, "the delta manifest names a different previous baseline")
    need(manifest.get("toCommit") == target, "the delta manifest names a different target")
    declared = manifest.get("paths")
    need(isinstance(declared, dict) and declared, "the delta manifest declares no paths")

    observed: dict[str, dict[str, str | None]] = {}
    for path in inspect_list:
        if path == "pubspec.yaml":
            continue
        before, after = git_object(previous, path), git_object(target, path)
        if before != after:
            observed[path] = {"before": before, "after": after}
    need(set(observed) == set(declared),
         "the source delta differs from the manifest: "
         f"observed {sorted(observed)}, declared {sorted(declared)}")
    for path, moved in observed.items():
        stated = declared[path]
        need(stated.get("before") == moved["before"] and stated.get("after") == moved["after"],
             f"{path} moved to object identities the manifest does not declare")
        need(moved["after"] is not None, f"{path} is deleted at the target commit")

    expected_version = (f"{pointer.get('versionName')}+{build}"
                        if pointer.get("versionName") else None)
    before_pubspec = normalised_pubspec(git_text(previous, "pubspec.yaml"), None)
    after_pubspec = normalised_pubspec(git_text(target, "pubspec.yaml"), expected_version)
    need(before_pubspec == after_pubspec, "pubspec.yaml differs beyond its version declaration")

    decision = decision_digest = None
    if decision_path is not None:
        decision_bytes = Path(decision_path).read_bytes()
        decision = read_json_bytes(decision_bytes, "the decision")
        decision_digest = digest(decision_bytes)
        need(decision.get("documentType") == "governed-artifact-source-rebind-decision",
             "the decision document is not an artifact source rebind decision")
        need(decision.get("confirmed") is True, "the rebind decision is not confirmed")
        need(decision.get("previousBaselineCommit") == previous,
             "the decision names a different previous baseline")
        need(decision.get("targetCommit") == target, "the decision names a different target commit")
        need(str(decision.get("sourceApprovalSha256", "")).upper() == current_digest,
             "the decision does not name the source approval bytes it was made against")
        need(decision.get("deployedBackendCommit") == deployed,
             "the decision names a different deployed backend source")
        confirmation = decision.get("ownerConfirmation", {})
        need(isinstance(confirmation, dict), "the decision records no owner confirmation")
        need(confirmation.get("confirmed") is True,
             "the decision's owner confirmation does not record confirmed true, "
             "whatever the top level claims")
        statement = confirmation.get("ownerStatementInOwnWords")
        need(isinstance(statement, str) and statement.strip(),
             "the decision records no owner statement")
        confirmed_at = utc_instant(confirmation.get("confirmedAtUtc"))
        need(confirmed_at is not None,
             "the decision's confirmation time is not an explicit UTC instant")
        need(confirmed_at <= datetime.now(timezone.utc),
             "the decision's confirmation time is in the future")
        custody = decision.get("custodyPath")
        need(isinstance(custody, str) and custody.startswith("release/approvals/")
             and custody.endswith(".json"),
             "the decision does not name a custody path under release/approvals")

    evidence = None
    if evidence_path is not None:
        evidence = json.loads(Path(evidence_path).read_text(encoding="utf-8"))
        need(evidence.get("headSha") == target,
             "the post-merge evidence is for a different commit")
        need(evidence.get("conclusion") == "success",
             f"the post-merge checks concluded {evidence.get('conclusion')}")
        need(evidence.get("status") in (None, "completed"),
             f"the post-merge run is {evidence.get('status')}, not completed")
        need(isinstance(evidence.get("runId"), int),
             "the post-merge evidence records no run identity")
        need(evidence.get("repository") in (None, EXPECTED_SLUG),
             "the post-merge evidence names a different repository")
        need(evidence.get("workflowName") in (None, "release-gate"),
             "the post-merge evidence names a different workflow")
        failed = [job for job in evidence.get("jobs", []) or []
                  if job.get("conclusion") not in (None, "success")]
        need(not failed,
             "the post-merge evidence carries jobs that did not succeed: "
             + ", ".join(sorted(str(job.get("name")) for job in failed)))

    return {
        "build": build, "policy": policy, "ledger": ledger, "state": state,
        "pointer": pointer, "approval": approval, "approvalPath": approval_path,
        "previous": previous, "deployed": deployed, "target": target,
        "targetTree": target_tree, "currentDigest": current_digest,
        "delta": observed, "decision": decision, "decisionPath": decision_path,
        "decisionDigest": decision_digest, "evidence": evidence, "entry": entry,
        "inspectedPaths": inspect_list,
        "expectedStatus": expected_status, "expectedNext": expected_next,
        "priorBytes": {
            approval_path: approval_bytes, POLICY: policy_bytes,
            VERSION_POINTER: pointer_bytes, LEDGER: ledger_bytes, STATE: state_bytes,
        },
    }


# ------------------------------------------------------------------- build


def build_proposal(inputs: dict) -> dict:
    """Pure: validated inputs in, proposed bytes and digests out. Writes nothing."""
    build = inputs["build"]
    approval = json.loads(json.dumps(inputs["approval"]))
    approval["sourceBaseline"]["commit"] = inputs["target"]
    approval["sourceBaseline"]["tree"] = inputs["targetTree"]

    # The decision that selected this baseline is recorded in the document whose
    # baseline moved, so a later reader can establish what authorised it.
    decision = inputs.get("decision")
    if decision is not None:
        confirmation = decision.get("ownerConfirmation", {})
        evidence = inputs.get("evidence")
        approval["artifactBaselineRebind"] = {
            "previousBaselineCommit": inputs["previous"],
            "targetCommit": inputs["target"],
            "decisionFile": Path(inputs["decisionPath"]).name,
            "decisionSha256": inputs["decisionDigest"],
            "decisionCustodyPath": decision.get("custodyPath"),
            "decisionDocumentType": decision.get("documentType"),
            "ownerStatementInOwnWords": confirmation.get("ownerStatementInOwnWords"),
            "confirmedAtUtc": confirmation.get("confirmedAtUtc"),
            "deployedBackendCommitUnchanged": inputs["deployed"],
            "postMergeEvidence": (
                {"runId": evidence.get("runId"), "headSha": evidence.get("headSha"),
                 "conclusion": evidence.get("conclusion")} if evidence else None),
        }
    approval_bytes = serialise(approval)
    approval_digest = digest(approval_bytes)

    policy = json.loads(json.dumps(inputs["policy"]))
    policy["versionPolicy"]["sourceDocumentSha256"] = approval_digest

    pointer = json.loads(json.dumps(inputs["pointer"]))
    pointer["sourceDocumentSha256"] = approval_digest

    ledger = json.loads(json.dumps(inputs["ledger"]))
    for entry in ledger["entries"]:
        if entry.get("buildNumber") == build:
            entry["versionApprovalDocumentSha256"] = approval_digest
            if "baselineCommit" in entry:
                entry["baselineCommit"] = inputs["target"]

    state = json.loads(json.dumps(inputs["state"]))
    state["authorityPlanes"]["currentSource"]["artifactConstructionAuthority"] = True
    state["status"] = f"BUILD{build}_SOURCE_AUTHORIZED_BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION"
    state["authorityPlanes"]["nextCandidate"]["status"] = (
        f"SOURCE_AUTHORIZED_AWAITING_SIGNED_BUILD{build}_CONSTRUCTION")

    return {
        "approvalDigest": approval_digest,
        "decisionRecorded": decision is not None,
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
    expected = proposal["approvalDigest"]
    files = proposal["files"]
    approval_bytes = files[inputs["approvalPath"]]
    need(digest(approval_bytes) == expected, "the proposed approval does not hash to its own digest")

    policy = json.loads(files[POLICY])
    pointer = json.loads(files[VERSION_POINTER])
    ledger = json.loads(files[LEDGER])
    state = json.loads(files[STATE])
    approval = json.loads(approval_bytes)
    build = inputs["build"]

    need(policy["versionPolicy"]["sourceDocumentSha256"] == expected,
         "the proposed policy does not pin the proposed approval")
    need(pointer["sourceDocumentSha256"] == expected,
         "the proposed version pointer does not pin the proposed approval")
    entries = [e for e in ledger["entries"] if e.get("buildNumber") == build]
    need(len(entries) == 1, "the proposed ledger does not hold exactly one entry for the build")
    need(entries[0]["versionApprovalDocumentSha256"] == expected,
         "the proposed ledger does not pin the proposed approval")
    need(approval["sourceBaseline"]["commit"] == inputs["target"],
         "the proposed approval does not select the target commit")
    need(approval.get("approved") is True, "the proposed approval is not approved")

    if inputs.get("decision") is not None:
        # Re-derive every recorded field from the decision itself. Comparing only
        # the digest would accept an annotation whose statement or time had been
        # altered while the digest was left untouched.
        decision = inputs["decision"]
        confirmation = decision.get("ownerConfirmation", {})
        evidence = inputs.get("evidence")
        expected_annotation = {
            "previousBaselineCommit": inputs["previous"],
            "targetCommit": inputs["target"],
            "decisionFile": Path(inputs["decisionPath"]).name,
            "decisionSha256": inputs["decisionDigest"],
            "decisionCustodyPath": decision.get("custodyPath"),
            "decisionDocumentType": decision.get("documentType"),
            "ownerStatementInOwnWords": confirmation.get("ownerStatementInOwnWords"),
            "confirmedAtUtc": confirmation.get("confirmedAtUtc"),
            "deployedBackendCommitUnchanged": inputs["deployed"],
            "postMergeEvidence": (
                {"runId": evidence.get("runId"), "headSha": evidence.get("headSha"),
                 "conclusion": evidence.get("conclusion")} if evidence else None),
        }
        recorded = approval.get("artifactBaselineRebind")
        need(recorded == expected_annotation,
             "the recorded rebind annotation does not match the decision it cites")

    # Exact resulting lifecycle, not merely the absence of a suffix.
    need(state["status"]
         == f"BUILD{build}_SOURCE_AUTHORIZED_BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION",
         f"the proposed state is {state['status']}, which is not the expected resulting state")
    need(state["authorityPlanes"]["nextCandidate"]["status"]
         == f"SOURCE_AUTHORIZED_AWAITING_SIGNED_BUILD{build}_CONSTRUCTION",
         "the proposed next candidate is not the expected resulting state")
    need(state["authorityPlanes"]["currentSource"]["artifactConstructionAuthority"] is True,
         "the proposed state does not restore construction authority")
    need(state["authorityPlanes"]["deployedBackend"]["functionFleetSourceCommit"] == inputs["deployed"],
         "the proposal moved the deployed backend source")


# ------------------------------------------------------------------ publish


def write_proposal(inputs: dict, proposal: dict, out_dir: str) -> dict:
    """Write the complete proposal to a fresh directory. Nothing active is touched.

    Three rounds of review found the in-place writer unsafe in a different way
    each time: stale inputs, partial replacement, failed rollback. Rather than
    patch it again, the writer is gone. The proposal is emitted as files, and
    applying it is an ordinary reviewable commit, which is the publication
    boundary review kept pointing at and which Git already provides.
    """
    destination = Path(out_dir)
    need(not destination.exists() or not any(destination.iterdir()),
         f"{out_dir} already exists and is not empty")
    files: dict[str, str] = {}
    for relative, data in proposal["files"].items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        files[relative] = digest(data)

    # The decision travels with the proposal, at the custody path it names, so
    # applying the proposal commits the decision that authorised it.
    decision = inputs.get("decision")
    if decision is not None:
        custody = decision["custodyPath"]
        decision_bytes = Path(inputs["decisionPath"]).read_bytes()
        target = destination / custody
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(decision_bytes)
        files[custody] = digest(decision_bytes)

    manifest = {
        "schemaVersion": 1,
        "recordType": "artifact-source-rebind-proposal",
        "status": "PROPOSAL_ONLY_NOT_APPLIED",
        "buildNumber": inputs["build"],
        "previousBaselineCommit": inputs["previous"],
        "targetCommit": inputs["target"],
        "targetTree": inputs["targetTree"],
        "deployedBackendCommitUnchanged": inputs["deployed"],
        "sourceApprovalShaBefore": inputs["currentDigest"],
        "sourceApprovalShaAfter": proposal["approvalDigest"],
        "inspectedPaths": inputs["inspectedPaths"],
        "sourceDelta": inputs["delta"],
        "decisionSha256": inputs.get("decisionDigest"),
        "postMergeEvidence": inputs.get("evidence"),
        "expectedPriorSha256": {name: digest(data)
                                for name, data in inputs["priorBytes"].items()},
        "proposedSha256": files,
        "howToApply": [
            "Copy every file in this directory over the checkout, preserving paths.",
            "Confirm git diff shows exactly these paths and nothing else.",
            "Run the production release policy, the strict construction gate, the "
            "canonical audit and the Dart suite.",
            "Commit. The commit is the publication boundary; this tool does not write "
            "to the checkout.",
        ],
    }
    (destination / "PROPOSAL.json").write_bytes(serialise(manifest))
    return manifest


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-commit", required=True)
    parser.add_argument("--expected-delta", required=True)
    parser.add_argument("--decision")
    parser.add_argument("--post-merge-evidence")
    parser.add_argument("--main-ref", default="origin/main")
    parser.add_argument("--out", help="write the complete proposal to this fresh directory")
    options = parser.parse_args(argv)

    try:
        inputs = inspect_inputs(options.target_commit, options.expected_delta,
                                options.decision, options.post_merge_evidence,
                                options.main_ref)
        if options.out:
            need(inputs["decision"] is not None,
                 "emitting a proposal requires the owner-confirmed rebind decision")
            need(inputs["evidence"] is not None,
                 "emitting a proposal requires the target's post-merge check evidence")
        proposal = build_proposal(inputs)
        validate_proposal(inputs, proposal)
        if options.out:
            write_proposal(inputs, proposal, options.out)
    except RebindRefused as refusal:
        print(json.dumps({"status": "REBIND_REFUSED", "reason": str(refusal)}, indent=2))
        return 1

    print(json.dumps({
        "status": "PROPOSAL_WRITTEN" if options.out else "PROPOSAL_VALIDATED",
        "activeRecordsUnchanged": True,
        "noProductionActionPerformed": True,
        "previousBaseline": inputs["previous"],
        "targetBaseline": inputs["target"],
        "deployedBackendUnchanged": inputs["deployed"],
        "approvalSha256": proposal["approvalDigest"],
        "decisionRecordedInApproval": proposal["decisionRecorded"],
        "inspectedPathCount": len(inputs["inspectedPaths"]),
        "recordsProposed": sorted(proposal["files"]),
        "sourceDelta": sorted(inputs["delta"]),
        "outputDirectory": options.out,
    }, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
