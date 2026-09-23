"""Step 2 of the Build 29 cutover: re-pin the artifact baseline to the merge commit.

Run from the repository root, on main, after PR #377 has merged.

Validates by default and prints exactly what it would change. Pass --write to
apply. It never guesses: the merge commit and its tree are read from Git, and
every hash it records is computed from the bytes on disk afterwards.

Why these three files and no others. The contract-test fixes moved test/ off
the approved baseline d513843e, so the policy computed artifact construction
authority as false and the state recorded that truthfully. Once the fixes are
themselves on main, the baseline can name that commit, drift returns to zero,
and construction authority is restored.

  1 build-number-29-successor-approval.json  sourceBaseline -> the merge commit
  2 build-number-ledger.json                 the build 29 versionApprovalDocumentSha256
                                             follows, because rewriting the approval
                                             changes its bytes
  3 current-successor-state.json             artifactConstructionAuthority back to true
                                             and the two rebind statuses back to the
                                             source-authorized forms

None of these is an approved artifact source path, so applying them does not
itself move the baseline.
"""
import collections
import hashlib
import io
import json
import subprocess
import sys

APPROVAL = "release/approvals/build-number-29-successor-approval.json"
LEDGER = "release/build-number-ledger.json"
STATE = "release/current-successor-state.json"
BUILD = 29
REBIND_STATUS = "BUILD29_SOURCE_SUCCESSOR_BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND"
BOUND_STATUS = "BUILD29_SOURCE_AUTHORIZED_BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION"
REBIND_NEXT = "SOURCE_SUCCESSOR_AWAITING_BUILD29_ARTIFACT_SOURCE_REBIND"
BOUND_NEXT = "SOURCE_AUTHORIZED_AWAITING_SIGNED_BUILD29_CONSTRUCTION"

write = "--write" in sys.argv
load = lambda p: json.loads(io.open(p, encoding="utf-8").read(),
                            object_pairs_hook=collections.OrderedDict)
save = lambda p, d: io.open(p, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, indent=2) + "\n")
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest().upper()
git = lambda *a: subprocess.run(["git", *a], capture_output=True, text=True,
                                check=True).stdout.strip()

branch = git("rev-parse", "--abbrev-ref", "HEAD")
if branch != "main":
    raise SystemExit(f"refusing: expected to be on main, found {branch}")
if git("status", "--porcelain"):
    raise SystemExit("refusing: the working tree is not clean")

commit = git("rev-parse", "HEAD")
tree = git("rev-parse", "HEAD^{tree}")

approval = load(APPROVAL)
baseline = approval["sourceBaseline"]
print(f"merge commit      : {commit}")
print(f"merge tree        : {tree}")
print(f"baseline was      : {baseline['commit']}")
if baseline["commit"] == commit:
    raise SystemExit("refusing: the baseline already names this commit")

# The baseline may only move forward to a descendant of the source the backend
# was deployed from; anything else would rebind the artifact to source the
# deployment never saw.
deployed_from = baseline["commit"]
subprocess.run(["git", "merge-base", "--is-ancestor", deployed_from, commit], check=True)
print(f"ancestry          : {deployed_from[:12]} is an ancestor of {commit[:12]}")

# The artifact-relevant trees must be identical, or re-pinning would silently
# adopt application changes that were never approved for this build.
approved_paths = [
    ".firebaserc", ".github/workflows/production-artifact.yml", ".metadata",
    ".npmrc", "analysis_options.yaml", "android", "assets", "firebase.json",
    "firestore.indexes.json", "firestore.rules", "functions", "integration_test",
    "jest.config.js", "lib", "package.json", "package-lock.json", "pubspec.lock",
    "release/approvals/linux-isar-community-core-authority.json",
    "release/github-actions-pins.json", "release_gate.ps1", "test", "tool",
    "tooling", "tools/release",
]
moved = []
for path in approved_paths:
    before = subprocess.run(["git", "rev-parse", f"{deployed_from}:{path}"],
                            capture_output=True, text=True).stdout.strip()
    after = subprocess.run(["git", "rev-parse", f"{commit}:{path}"],
                           capture_output=True, text=True).stdout.strip()
    if before != after:
        moved.append(path)
print(f"artifact paths that moved since the deployed source: "
      f"{', '.join(moved) if moved else 'none'}")
print("  (test/ and tools/release are expected here: the contract fixes and the")
print("   gate diagnostics. Anything under lib/, android/ or functions/ is not,")
print("   and means the build would ship code the backend approval never saw.)")
unexpected = [p for p in moved if p not in ("test", "tools/release")]
if unexpected:
    raise SystemExit(f"refusing: unexpected artifact source movement: {unexpected}")

if not write:
    print("\nVALIDATED ONLY. Re-run with --write to apply.")
    raise SystemExit(0)

baseline["commit"] = commit
baseline["tree"] = tree
save(APPROVAL, approval)
approval_sha = sha(APPROVAL)
print(f"\napproval rewritten, now {approval_sha[:16]}..")

ledger = load(LEDGER)
entry = next(e for e in ledger["entries"] if e.get("buildNumber") == BUILD)
entry["versionApprovalDocumentSha256"] = approval_sha
if "baselineCommit" in entry:
    entry["baselineCommit"] = commit
save(LEDGER, ledger)
print("ledger version approval pin and baseline commit follow the approval")

state = load(STATE)
current = state["authorityPlanes"]["currentSource"]
current["artifactConstructionAuthority"] = True
if state.get("status") == REBIND_STATUS:
    state["status"] = BOUND_STATUS
if state["authorityPlanes"]["nextCandidate"].get("status") == REBIND_NEXT:
    state["authorityPlanes"]["nextCandidate"]["status"] = BOUND_NEXT
save(STATE, state)
print("successor state: construction authority restored, rebind statuses cleared")

print("\nNow run, and all four must pass before committing:")
print("  tools/release/Test-ProductionReleasePolicy.ps1")
print("  tools/release/Test-ProductionReleasePolicy.ps1 -RequireArtifactConstructionAuthority")
print("  python tools/v4/v4_2_r1_canonical_audit.py")
print("  flutter test")
