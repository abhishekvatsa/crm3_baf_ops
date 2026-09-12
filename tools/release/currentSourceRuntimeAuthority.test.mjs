import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {createHash} from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

test("canonical backend authority consumes the real delegated proof and retains historical owner restrictions", (t) => {
  const read = (file) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, file), "utf8"));
  const digest = (bytes) => createHash("sha256").update(bytes).digest("hex").toUpperCase();
  const backendFile = "release/evidence/build28-backend-deployment-closure.json";
  const historicalFile = "release/evidence/build27-backend-deployment-closure.json";
  const versionFile = "release/approvals/build-number-27-successor-approval.json";
  const promotionFile = "release/evidence/build-27-staged-controlled-pilot-authorization.json";
  const backend = read(backendFile);
  const historical = read(historicalFile);
  const promotion = read(promotionFile);
  const approval = read(backend.approvalAuthority.file);
  const base = {label: "actual delegated closure", backend, approval, accepted: true};
  const cases = [base, {label: "historical owner closure", backend: historical,
    approval: read(historical.approvalAuthority.file), accepted: true}];
  const change = (label, mutate, original = base) => {
    const row = structuredClone(original);
    row.label = label;
    row.accepted = false;
    mutate(row);
    cases.push(row);
  };
  change("historical owner restrictions still required", (row) => { row.approval.notAuthorized = []; }, cases[1]);
  change("historical owner timestamp still required", (row) => { delete row.backend.authorityChronology.ownerInstructionReceivedAtUtc; }, cases[1]);
  for (const [field, value] of [
    ["delegatedDecisionAtUtc", "2026-09-09T21:00:08Z"],
    ["delegatedDecisionAtUtc", ["2026-09-08T21:00:08Z"]],
    ["delegatedDecisionAtUtc", "2026-09-08T21:00:08+00:00"],
    ["earliestFunctionUpdateTime", "2026-02-30T21:00:08Z"],
    ["latestFunctionUpdateTime", [backend.authorityChronology.latestFunctionUpdateTime]],
    ["allObservedFunctionUpdatesPostdateDelegatedDecision", "true"],
    ["allObservedFunctionUpdatesPostdateDelegatedDecision", false],
    ["deploymentWasRetroactivelyAuthorized", true],
  ]) change(`invalid delegated ${field}: ${JSON.stringify(value)}`, (row) => { row.backend.authorityChronology[field] = value; });
  change("missing delegated time", (row) => { delete row.backend.authorityChronology.delegatedDecisionAtUtc; });
  change("reverse nanosecond order", (row) => {
    row.backend.authorityChronology.earliestFunctionUpdateTime = "2026-09-08T21:23:01.123456789Z";
    row.backend.authorityChronology.latestFunctionUpdateTime = "2026-09-08T21:23:01.123456788Z";
  });
  change("mixed owner and delegated chronology", (row) => {
    row.backend.authorityChronology.ownerInstructionReceivedAtUtc = approval.approvedAtUtc;
  });
  change("c00 cannot fall back to an invented owner instruction", (row) => {
    row.backend.authorityChronology = structuredClone(historical.authorityChronology);
    row.approval = read(historical.approvalAuthority.file);
    row.approval.sourceAuthority = structuredClone(approval.sourceAuthority);
  });
  change("delegated receipt cannot change source", (row) => { row.backend.sourceAuthority.commit = historical.sourceAuthority.commit; });
  change("another real source cannot invent owner approval to bypass custody", (row) => {
    row.backend.sourceAuthority.commit = "2e7f7e8f914e4238d9f1665ba2fd8fce284bb6a9";
    row.approval = read(historical.approvalAuthority.file);
    row.approval.sourceAuthority = structuredClone(row.backend.sourceAuthority);
    row.backend.authorityChronology = {...structuredClone(historical.authorityChronology),
      earliestFunctionUpdateTime: backend.authorityChronology.earliestFunctionUpdateTime,
      latestFunctionUpdateTime: backend.authorityChronology.latestFunctionUpdateTime};
  });
  change("coherently rehashed approval is not immutable custody", (row) => { row.approval.approvalEvidence.agentDecision = "Different deployment scope"; });
  change("receipt approval custody commit cannot change", (row) => { row.backend.approvalAuthority.commit = "0".repeat(40); });
  for (const [field, value] of [["callableCount", 8], ["eventAndProtocolTriggerCount", "5"], ["schedulerCount", [1]]]) {
    change(`invalid delegated scope ${field}`, (row) => { row.backend.deployment[field] = value; });
  }
  change("verified flag cannot replace failed approval", (row) => {
    row.backend.verified = true;
    row.backend.authorityChronology.allObservedFunctionUpdatesPostdateDelegatedDecision = false;
  });
  change("loaded receipt must match verified physical bytes", (row) => { row.loadedMutation = true; });
  change("state digest must match verified physical bytes", (row) => { row.stateHashMutation = true; });
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-canonical-backend-"));
  const copy = (file) => {
    fs.mkdirSync(path.dirname(path.join(fixtureRoot, file)), {recursive: true});
    fs.copyFileSync(path.join(repositoryRoot, file), path.join(fixtureRoot, file));
  };
  try {
    execFileSync("git", ["init", "--quiet", fixtureRoot], {stdio: "pipe", windowsHide: true});
    const objects = execFileSync("git", ["rev-parse", "--path-format=absolute", "--git-path", "objects"], {cwd: repositoryRoot, encoding: "utf8"}).trim();
    fs.mkdirSync(path.join(fixtureRoot, ".git/objects/info"), {recursive: true});
    fs.writeFileSync(path.join(fixtureRoot, ".git/objects/info/alternates"), `${objects.replace(/\\/g, "/")}\n`);
    for (const file of [versionFile, promotionFile, promotion.ownerApproval.receipt,
      promotion.admittedEvidence.deviceAcceptance.receipt, backendFile, historicalFile,
      backend.approvalAuthority.file, historical.approvalAuthority.file,
      ...Object.values(backend.cleanMainLiveReadbacks).map((value) => value.file),
      ...Object.values(historical.cleanMainLiveReadbacks).map((value) => value.file),
      ...["stagedPromotionSourceAuthority", "deploymentFleetContract", "collectProductionGlobalPullBackend",
        "collectFunctionFleetRuntimeIdentityReadback", "collectFunctionsIamDependenciesReadback",
        "collectFirestoreRulesIndexesReadback"].map((name) => `tools/release/${name}.js`)]) copy(file);
    const policy = {firebaseProjectId: "crm3-baf-ops-b8638", versionPolicy: {buildNumber: 27,
      sourceDocumentFile: versionFile, sourceDocumentSha256: digest(fs.readFileSync(path.join(fixtureRoot, versionFile)))},
    finalization: {exactFunctionFleetDeploymentReceiptFile: historicalFile,
      exactFunctionFleetDeploymentReceiptSha256: digest(fs.readFileSync(path.join(fixtureRoot, historicalFile)))},
    postBuildPromotion: {status: "completed-staged-controlled-pilot-only", promotionReceiptFile: promotionFile,
      promotionReceiptSha256: digest(fs.readFileSync(path.join(fixtureRoot, promotionFile)))}};
    fs.writeFileSync(path.join(fixtureRoot, "release/production-release-policy.json"), JSON.stringify(policy));
    fs.writeFileSync(path.join(fixtureRoot, "cases.json"), JSON.stringify(cases));
    fs.writeFileSync(path.join(fixtureRoot, "check.py"), String.raw`
import ast, hashlib, json, pathlib, subprocess, sys
from datetime import datetime
source = pathlib.Path(sys.argv[1])
root = pathlib.Path.cwd()
tree = ast.parse(source.read_text(encoding="utf-8"))
helper = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "current_backend_authority_proof_exact")
proof = next(node for node in tree.body if isinstance(node, ast.Assign) and any(
    isinstance(target, ast.Name) and target.id == "current_backend_immutable_authority_exact" for target in node.targets))
branch = next(node for node in tree.body if isinstance(node, ast.If) and any(
    isinstance(child, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "current_backend_approval_scope_exact" for target in child.targets)
    for child in node.body))
definitions = compile(ast.Module(body=[helper], type_ignores=[]), str(source), "exec")
consumer = compile(ast.Module(body=[proof, branch], type_ignores=[]), str(source), "exec")
original_approvals = {file: (root / file).read_bytes() for file in [
    "release/approvals/build27-backend-deployment-approval.json",
    "release/approvals/build28-backend-deployment-approval.json"]}
rows = []
for case in json.loads((root / "cases.json").read_text(encoding="utf-8")):
    receipt = case["backend"]
    approval = case["approval"]
    approval_file = receipt["approvalAuthority"]["file"]
    approval_bytes = original_approvals[approval_file]
    if json.loads(approval_bytes) != approval:
        approval_bytes = json.dumps(approval).encode("utf-8")
    (root / approval_file).write_bytes(approval_bytes)
    receipt["approvalAuthority"]["sha256"] = hashlib.sha256(approval_bytes).hexdigest().upper()
    receipt_file = "release/current-test-backend.json"
    receipt_bytes = json.dumps(receipt).encode("utf-8")
    (root / receipt_file).write_bytes(receipt_bytes)
    deployed = dict(functionFleetSourceCommit=receipt["sourceAuthority"]["commit"],
        functionFleetEvidenceFile=receipt_file, functionFleetEvidenceSha256=hashlib.sha256(receipt_bytes).hexdigest().upper(),
        deploymentApprovalFile=approval_file, deploymentApprovalSha256=receipt["approvalAuthority"]["sha256"])
    if case.get("stateHashMutation"):
        deployed["functionFleetEvidenceSha256"] = "0" * 64
    (root / "release/current-successor-state.json").write_text(json.dumps(dict(authorityPlanes=dict(deployedBackend=deployed))), encoding="utf-8")
    readback = json.loads((root / receipt["cleanMainLiveReadbacks"]["functionFleet"]["file"]).read_bytes())
    if case.get("loadedMutation"):
        receipt["recordedAtUtc"] = "2026-09-08T23:00:00Z"
    scope = dict(ROOT=root, subprocess=subprocess, hashlib=hashlib, json=json, datetime=datetime,
        current_backend_deployment=receipt, current_deployed_backend=deployed,
        current_backend_deployment_relative=receipt_file, current_backend_approval=approval,
        current_backend_approval_evidence=approval.get("approvalEvidence", {}),
        current_backend_authority_chronology=receipt.get("authorityChronology", {}),
        current_function_readback=readback)
    exec(definitions, scope)
    exec(consumer, scope)
    rows.append(dict(label=case["label"], accepted=scope["current_backend_approval_scope_exact"], expected=case["accepted"]))
    for file, content in original_approvals.items():
        (root / file).write_bytes(content)
print(json.dumps(rows))
`);
    const rows = JSON.parse(execFileSync(process.platform === "win32" ? "python" : "python3", [path.join(fixtureRoot, "check.py"), path.join(repositoryRoot, "tools/v4/v4_2_r1_canonical_audit.py")], {
      cwd: fixtureRoot, encoding: "utf8", windowsHide: true,
    }));
    assert.equal(rows.length, cases.length);
    assert.deepEqual(rows.filter((row) => row.accepted !== row.expected), []);
    t.diagnostic(`${rows.length} actual canonical authority cases with the real shared verifier`);
  } finally {
    assert.equal(path.dirname(path.resolve(fixtureRoot)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-canonical-backend-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});

// Execute the production classifiers against real Git trees without running
// the complete release gate or changing the application's repository.
test("canonical pending Build 28 preserves measured Build 27 labels without inheriting them", () => {
  const read = (file) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, file), "utf8"));
  const policy = read("release/production-release-policy.json");
  const historical = {...policy.finalization, buildNumber: 27};
  const state = read("release/current-successor-state.json").authorityPlanes;
  const device = read("release/evidence/build-27-device-acceptance.json");
  const promotion = read("release/evidence/build-27-staged-controlled-pilot-authorization.json");
  const base = {pending: true, build: 28, latest: 27, finalization: historical,
    policy: {...policy, finalization: {runtimeValidationPassed: false, controlledPilotApproved: false}},
    state, device, promotion, accepted: true};
  const cases = [{...structuredClone(base), label: "pending28 retains proved27"},
    {...structuredClone(base), label: "completed27 unchanged", pending: false, build: 27, policy}];
  const change = (label, mutate) => {
    const row = structuredClone(base);
    Object.assign(row, {label, accepted: false});
    mutate(row);
    cases.push(row);
  };
  change("pending candidate cannot erase prior validation", (row) => { row.state.latestFinalizedArtifact.runtimeValidation = "NOT_ADJUDICATED_FOR_EXACT_BUILD27"; });
  change("pending candidate cannot erase prior pilot", (row) => { row.state.latestFinalizedArtifact.pilotPromotion = "NOT_AUTHORIZED"; });
  change("prior finalization runtime admission required", (row) => { row.finalization.runtimeValidationPassed = false; });
  change("prior finalization pilot admission required", (row) => { row.finalization.controlledPilotApproved = false; });
  change("prior device must name same APK", (row) => { row.device.release.apkSha256 = "0".repeat(64); });
  change("prior device must name same build", (row) => { row.device.release.buildNumber = 28; });
  change("prior promotion must name same build", (row) => { row.promotion.admittedEvidence.governedBuild.buildNumber = 28; });
  change("prior runtime cannot use another acceptance hash", (row) => { row.finalization.deviceAcceptanceReceiptSha256 = "0".repeat(64); });
  const completed = structuredClone(base);
  Object.assign(completed, {label: "completed28 does not inherit27", pending: false, latest: 28});
  completed.state.latestFinalizedArtifact.runtimeValidation = "NOT_ADJUDICATED_FOR_EXACT_BUILD28";
  completed.state.latestFinalizedArtifact.pilotPromotion = "NOT_AUTHORIZED";
  cases.push(completed);
  const script = String.raw`
import ast, hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
source = root / "tools/v4/v4_2_r1_canonical_audit.py"
tree = ast.parse(source.read_text(encoding="utf-8"))
names = {"candidate_runtime_accepted", "candidate_controlled_pilot_approved", "latest_finalized_runtime_accepted", "latest_finalized_controlled_pilot_approved"}
nodes = [node for node in tree.body if (
    isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id in names for target in node.targets)
) or (isinstance(node, ast.If) and any(isinstance(child, ast.Assign) and any(isinstance(target, ast.Name) and target.id in names for target in child.targets) for child in node.body))]
comparisons = [node for node in ast.walk(tree) if isinstance(node, ast.Compare) and
    "current_successor_planes.get('latestFinalizedArtifact'" in ast.unparse(node.left) and
    any(".get('" + field + "')" in ast.unparse(node.left) for field in ["runtimeValidation", "pilotPromotion"])]
assert len(comparisons) == 2
rows = []
for case in json.load(sys.stdin):
    scope = dict(candidate_pending=case["pending"], candidate_build_number=case["build"],
        latest_finalized_build_number=case["latest"], latest_completed_finalization=case["finalization"],
        combined_policy=case["policy"], current_successor_planes=case["state"],
        build27_device_acceptance=case["device"], build27_pilot_promotion=case["promotion"],
        build27_device_acceptance_path=root / "release/evidence/build-27-device-acceptance.json",
        build27_pilot_promotion_path=root / "release/evidence/build-27-staged-controlled-pilot-authorization.json",
        sha=lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper())
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(source), "exec"), scope)
    accepted = all(eval(compile(ast.Expression(body=node), str(source), "eval"), scope) for node in comparisons)
    rows.append(dict(label=case["label"], accepted=accepted, expected=case["accepted"]))
    if case["pending"]:
        assert scope["candidate_runtime_accepted"] is False
        assert scope["candidate_controlled_pilot_approved"] is False
print(json.dumps(rows))
`;
  const rows = JSON.parse(execFileSync(process.platform === "win32" ? "python" : "python3", ["-c", script, repositoryRoot], {
    input: JSON.stringify(cases), encoding: "utf8", windowsHide: true,
  }));
  assert.equal(rows.length, cases.length);
  assert.deepEqual(rows.filter((row) => row.accepted !== row.expected), []);
});

test("source authority follows shipped inputs and backend parity, not governance commits", () => {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-source-authority-"));
  const git = (...args) => execFileSync("git", args, {
    cwd: fixtureRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  const write = (relative, content) => {
    const target = path.join(fixtureRoot, relative);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.writeFileSync(target, content);
  };
  const commit = () => {
    git("add", ".");
    git("-c", "user.name=Source authority fixture", "-c", "user.email=fixture@example.invalid",
      "commit", "--no-gpg-sign", "-m", "fixture");
    return git("rev-parse", "HEAD");
  };
  try {
    git("init", "--quiet");
    const applicationInputs = [
      "android/app/build.gradle.kts", "assets/fixture.txt", "lib/main.dart",
      "pubspec.yaml", "pubspec.lock",
    ];
    for (const input of applicationInputs) write(input, "baseline\n");
    const initial = commit();
    const cases = [{label: "same source", promoted: initial, current: initial, expected: true}];
    for (const input of ["docs/notes.md", "governance/fixture.json", "test/fixture_test.dart",
      "tools/release/fixture.ps1", ".github/workflows/production-artifact.yml"]) {
      write(input, "governance only\n");
    }
    let previous = commit();
    cases.push({label: "governance-only commit", promoted: initial, current: previous, expected: true});
    for (const input of applicationInputs) {
      write(input, "changed\n");
      const changed = commit();
      cases.push({label: input, promoted: previous, current: changed, expected: false});
      previous = changed;
    }
    fs.unlinkSync(path.join(fixtureRoot, "pubspec.lock"));
    const missing = commit();
    cases.push({label: "missing input on both sides", promoted: missing, current: missing, expected: false});
    write("cases.json", JSON.stringify(cases));

    const powershell = String.raw`
param([string]$ProductionSource, [string]$CasesPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ast = [Management.Automation.Language.Parser]::ParseFile($ProductionSource, [ref]$null, [ref]$null)
$assignment = $ast.Find({param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
  $node.Left.Extent.Text -eq '$PromotedApplicationSourcePaths'
}, $false)
Invoke-Expression $assignment.Extent.Text
foreach ($name in @('Get-GitTreeObjectId', 'Test-PromotedApplicationSourceMatches', 'Get-CurrentSourceRuntimeAuthority')) {
  $definition = $ast.Find({param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
  }, $false)
  Invoke-Expression $definition.Extent.Text
}
$rows = foreach ($case in (Get-Content -LiteralPath $CasesPath -Raw | ConvertFrom-Json)) {
  $matches = Test-PromotedApplicationSourceMatches -PromotedCommit $case.promoted -CurrentCommit $case.current
  [ordered]@{
    label = $case.label
    matches = $matches
    approved = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $true -BackendMatchesDeployed $true -ApplicationMatchesPromotedArtifact $matches
    backendDrift = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $true -BackendMatchesDeployed $false -ApplicationMatchesPromotedArtifact $matches
    unapproved = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $false -BackendMatchesDeployed $true -ApplicationMatchesPromotedArtifact $matches
  }
}
$rows | ConvertTo-Json -Depth 4 -Compress
`;
    const python = String.raw`
import ast, json, pathlib, re, subprocess, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
names = {"git_tree_object_id", "promoted_application_source_matches", "current_source_runtime_authority"}
nodes = [node for node in ast.parse(source).body if
    isinstance(node, ast.FunctionDef) and node.name in names or
    isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "PROMOTED_APPLICATION_SOURCE_PATHS" for target in node.targets)]
scope = {"subprocess": subprocess, "re": re, "ROOT": pathlib.Path.cwd()}
exec(compile(ast.Module(body=nodes, type_ignores=[]), sys.argv[1], "exec"), scope)
rows = []
for case in json.loads(pathlib.Path(sys.argv[2]).read_text()):
    matches = scope["promoted_application_source_matches"](case["promoted"], case["current"])
    authority = scope["current_source_runtime_authority"]
    rows.append(dict(label=case["label"], matches=matches, approved=authority(True, True, matches), backendDrift=authority(True, False, matches), unapproved=authority(False, True, matches)))
print(json.dumps(rows))
`;
    write("check.ps1", powershell);
    write("check.py", python);
    const expected = cases.map(({label, expected: matches}) => ({
      label, matches, approved: matches, backendDrift: false, unapproved: false,
    }));
    for (const [executable, args] of [
      ["pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"),
        path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1"), path.join(fixtureRoot, "cases.json")]],
      [process.platform === "win32" ? "python" : "python3", [path.join(fixtureRoot, "check.py"),
        path.join(repositoryRoot, "tools/v4/v4_2_r1_canonical_audit.py"), path.join(fixtureRoot, "cases.json")]],
    ]) {
      const result = execFileSync(executable, args, {cwd: fixtureRoot, encoding: "utf8"});
      assert.deepEqual(JSON.parse(result), expected, executable);
    }
  } finally {
    const parent = path.resolve(os.tmpdir());
    assert.equal(path.dirname(path.resolve(fixtureRoot)), parent);
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-source-authority-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});

test("Build 28 cloud custody consumes all six generation proofs and preserves historical volume custody", (t) => {
  const read = (name) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, name), "utf8"));
  const digest = (value) => createHash("sha256").update(value).digest("hex").toUpperCase();
  const approvalFile = "release/approvals/build28-private-cloud-custody-approval.json";
  const verificationFile = "release/evidence/build28-private-gcs-custody-readback.json";
  const authority = {
    commit: "e1db8eaa4b34c26254d3fd2a4cfc533747e187a4", file: approvalFile,
    sha256: "3DEB2A9E26FCFDBBAC20A591256ABB3A29FA3EBEF75D3A91FDACCEA2BA64FC88",
  };
  const completion = read("release/evidence/build-27-finalization-closure.json");
  const policy = read("release/production-release-policy.json");
  const historical = {label: "historical27", completion: structuredClone(completion), policy: structuredClone(policy), accepted: true};
  Object.assign(completion.release, {buildNumber: 28, versionName: "1.0.0-rc.18", releaseId: "crm3-baf-ops-1.0.0-rc.18-b28"});
  const bucket = "crm3-baf-ops-b8638-firestore-restore";
  const prefix = `gs://${bucket}/release-custody/build-28/fixture-campaign`;
  const controls = {bucket, location: "ASIA-SOUTH1", publicAccessPrevention: "enforced", uniformBucketLevelAccess: true, versioningEnabled: true, publicIamPrincipalsAbsent: true, retentionSeconds: 7776000, softDeleteSeconds: 604800, checkedAtUtc: "2026-09-09T01:00:02Z"};
  const objects = [];
  for (const [purpose, name, target, field, sidecarTarget, sidecarField] of [
    ["productionPackage", `${completion.release.releaseId}-GOVERNED-PACKAGE.zip`, completion.governedPackage, "sha256", completion.governedPackage, "sidecarSha256"],
    ["closurePackage", "CRM_III_BAF_Ops_O1_O5_CLOSURE_20260909_010000.zip", completion.closure, "closurePackageSha256", completion.closure, "closurePackageSidecarSha256"],
    ["custodyRecord", "CRM_III_BAF_Ops_O1_O5_CUSTODY_20260909_010000.json", completion.closure, "custodyRecordSha256", null, null],
  ]) {
    const payload = Buffer.from(`synthetic ${purpose} bytes`);
    const hash = digest(payload);
    target[field] = hash;
    const sidecar = Buffer.from(`${hash}  ${name}\n`);
    if (sidecarTarget) sidecarTarget[sidecarField] = digest(sidecar);
    for (const [entryPurpose, entryName, bytes] of [[purpose, name, payload], [`${purpose}Sidecar`, `${name}.sha256.txt`, sidecar]]) {
      const objectUri = `${prefix}/${entryName}`;
      const generation = String(1788915600000000 + objects.length);
      objects.push({schemaVersion: 1, provider: "gcs", purpose: entryPurpose, buildNumber: 28, bucket, prefix,
        objectName: objectUri.slice(`gs://${bucket}/`.length), objectUri, generation, generationUri: `${objectUri}#${generation}`,
        bytes: bytes.length, sha256: digest(bytes), downloadedBytes: bytes.length, downloadedSha256: digest(bytes),
        createOnly: true, generationPinnedReadback: true, verified: true, verifiedAtUtc: "2026-09-09T01:00:03Z",
        approval: structuredClone(authority), bucketControls: structuredClone(controls)});
    }
  }
  Object.assign(completion.dualCustody, {mode: "local-primary-private-gcs-backup", distinctVolumes: false, independentlyStored: true,
    backupVerification: {file: verificationFile, sha256: "REBOUND_BY_FIXTURE"}});
  const verification = {schemaVersion: 1, evidenceType: "private-gcs-release-custody", mode: "local-primary-private-gcs-backup", buildNumber: 28,
    sourceCommit: completion.sourceAuthority.commit, githubRunId: String(completion.workflow.runId), primaryDirectory: "C:\\OwnerCustody\\Build28",
    backupPrefix: prefix, independentlyStored: true, approval: authority, objects, status: "passed", completedAtUtc: "2026-09-09T01:00:04Z"};
  const base = {label: "complete28", completion, policy, verification, accepted: true};
  const cases = [historical, base];
  const change = (label, edit) => { const row = structuredClone(base); row.label = label; row.accepted = false; edit(row); cases.push(row); };
  const set = (object, field, value) => { const parts = field.split("."); const parent = parts.slice(0, -1).reduce((current, part) => current[part], object); if (value === undefined) delete parent[parts.at(-1)]; else parent[parts.at(-1)] = value; };
  for (const field of ["schemaVersion", "evidenceType", "mode", "buildNumber", "sourceCommit", "githubRunId", "primaryDirectory", "backupPrefix", "independentlyStored", "status", "completedAtUtc"]) {
    for (const value of [undefined, null, [verification[field]]]) change(`manifest ${field}: ${JSON.stringify(value)}`, (row) => set(row.verification, field, value));
  }
  for (const field of ["mode", "independentlyStored", "distinctVolumes", "status", "allFileHashesMatched"]) {
    change(`missing completion custody ${field}`, (row) => delete row.completion.dualCustody[field]);
  }
  change("cloud must not claim distinct volumes", (row) => { row.completion.dualCustody.distinctVolumes = true; });
  change("Build28 cannot strip mode and proof to claim legacy volumes", (row) => {
    delete row.completion.dualCustody.mode;
    delete row.completion.dualCustody.backupVerification;
    row.completion.dualCustody.distinctVolumes = true;
  });
  change("Build28 cannot strip mode and ignore a bad cloud proof", (row) => {
    delete row.completion.dualCustody.mode;
    row.completion.dualCustody.distinctVolumes = true;
    row.tamperVerificationHash = true;
    row.verification.objects = [];
  });
  change("unknown custody mode", (row) => { row.completion.dualCustody.mode = "unknown"; row.completion.dualCustody.distinctVolumes = true; });
  change("wrong readback digest", (row) => { row.tamperVerificationHash = true; });
  change("wrong readback path", (row) => { row.completion.dualCustody.backupVerification.file = "release/evidence/other.json"; });
  change("approval file modified", (row) => { row.tamperApproval = true; });
  change("wrong immutable approval", (row) => { row.verification.approval.commit = "0".repeat(40); });
  change("Build27 cannot use cloud mode", (row) => { row.completion.release.buildNumber = 27; row.verification.buildNumber = 27; });
  change("missing sixth purpose", (row) => row.verification.objects.pop());
  change("duplicate purpose", (row) => { row.verification.objects[5] = structuredClone(row.verification.objects[0]); });
  change("duplicated object identity", (row) => { Object.assign(row.verification.objects[5], {objectName: objects[0].objectName, objectUri: objects[0].objectUri, generationUri: objects[0].generationUri}); });
  for (let index = 0; index < 6; index++) {
    for (const field of ["verified", "createOnly", "generationPinnedReadback"]) change(`proof${index} ${field} false`, (row) => { row.verification.objects[index][field] = false; });
    change(`proof${index} foreign digest`, (row) => { row.verification.objects[index].sha256 = "0".repeat(64); row.verification.objects[index].downloadedSha256 = "0".repeat(64); });
    change(`proof${index} readback mismatch`, (row) => { row.verification.objects[index].downloadedBytes++; });
    change(`proof${index} foreign approval`, (row) => { row.verification.objects[index].approval.sha256 = "0".repeat(64); });
  }
  for (const field of ["schemaVersion", "provider", "purpose", "buildNumber", "bucket", "prefix", "objectName", "objectUri", "generation", "generationUri", "bytes", "sha256", "downloadedBytes", "downloadedSha256", "createOnly", "generationPinnedReadback", "verified", "verifiedAtUtc"]) {
    for (const value of [undefined, [objects[0][field]]]) change(`proof scalar ${field}: ${JSON.stringify(value)}`, (row) => set(row.verification.objects[0], field, value));
  }
  for (const field of Object.keys(controls)) {
    change(`missing bucket control ${field}`, (row) => delete row.verification.objects[0].bucketControls[field]);
    change(`array bucket control ${field}`, (row) => { row.verification.objects[0].bucketControls[field] = [controls[field]]; });
  }
  change("public bucket", (row) => { row.verification.objects[0].bucketControls.publicAccessPrevention = "inherited"; });
  change("shortened retention", (row) => { row.verification.objects[0].bucketControls.retentionSeconds = 1; });
  change("nonzero generation must be string", (row) => { row.verification.objects[0].generation = 1; });
  change("generation zero", (row) => { row.verification.objects[0].generation = "0"; });
  change("unqualified readback", (row) => { row.verification.objects[0].generationUri = row.verification.objects[0].objectUri; });
  change("unfinished manifest", (row) => { row.verification.completedAtUtc = "2026-09-09T01:00:01Z"; });
  change("control inspection after verification", (row) => { row.verification.objects[0].bucketControls.checkedAtUtc = "2026-09-09T01:00:04Z"; });

  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-custody-consumption-"));
  try {
    execFileSync("git", ["init", "--quiet"], {cwd: fixtureRoot});
    const objectRoot = execFileSync("git", ["rev-parse", "--path-format=absolute", "--git-path", "objects"], {cwd: repositoryRoot, encoding: "utf8"}).trim();
    fs.writeFileSync(path.join(fixtureRoot, ".git/objects/info/alternates"), `${objectRoot.replaceAll("\\", "/")}\n`);
    for (const file of [approvalFile, "tools/release/Private-GcsReleaseCustody.ps1"]) {
      fs.mkdirSync(path.dirname(path.join(fixtureRoot, file)), {recursive: true});
      fs.copyFileSync(path.join(repositoryRoot, file), path.join(fixtureRoot, file));
    }
    fs.mkdirSync(path.join(fixtureRoot, "release/evidence"), {recursive: true});
    fs.writeFileSync(path.join(fixtureRoot, "cases.json"), JSON.stringify(cases));
    fs.writeFileSync(path.join(fixtureRoot, "check.ps1"), String.raw`
param([string]$ProductionSource, [string]$ActualRepository)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Get-Location).Path
$ast = [Management.Automation.Language.Parser]::ParseFile($ProductionSource, [ref]$null, [ref]$null)
foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) { Invoke-Expression $definition.Extent.Text }
$guard = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item2.Statements.Count -eq 1 -and $node.Clauses[0].Item2.Statements[0].Extent.Text -eq "throw 'Finalization receipt differs from policy or release boundary.'"}, $true))
if ($guard.Count -ne 1) { throw 'Actual finalization guard must be unique' }
$approvalBytes = [IO.File]::ReadAllBytes((Join-Path $ActualRepository 'release/approvals/build28-private-cloud-custody-approval.json'))
$rows = foreach ($case in (Get-Content cases.json -Raw | ConvertFrom-Json)) {
  [IO.File]::WriteAllBytes((Join-Path $RepositoryRoot 'release/approvals/build28-private-cloud-custody-approval.json'), $approvalBytes)
  $hasCloud = $null -ne $case.PSObject.Properties['verification']
  if ($hasCloud) {
    $case.verification | ConvertTo-Json -Depth 40 | Set-Content 'release/evidence/build28-private-gcs-custody-readback.json' -Encoding utf8
    if ($null -ne $case.completion.dualCustody.PSObject.Properties['backupVerification']) {
      $case.completion.dualCustody.backupVerification.sha256 = Get-Sha256 'release/evidence/build28-private-gcs-custody-readback.json'
    }
    if ($null -ne $case.PSObject.Properties['tamperVerificationHash']) { $case.completion.dualCustody.backupVerification.sha256 = '0' * 64 }
    if ($null -ne $case.PSObject.Properties['tamperApproval']) { Add-Content 'release/approvals/build28-private-cloud-custody-approval.json' ' ' }
  }
  $completionReceiptPath = 'completion.json'
  $case.completion | ConvertTo-Json -Depth 40 | Set-Content $completionReceiptPath -Encoding utf8
  $completionReceipt = Get-Content $completionReceiptPath -Raw | ConvertFrom-Json
  $policy = $case.policy
  $policy.release = $completionReceipt.release
  $currentStagedPilotAuthorized = -not $hasCloud
  $currentBuildNumber = [int]$completionReceipt.release.buildNumber
  $recoveryValid = $true
  $policy.finalization.completionReceiptSha256 = Get-Sha256 $completionReceiptPath
  $policy.finalization.sourceCommit = $completionReceipt.sourceAuthority.commit
  $policy.finalization.githubRunId = $completionReceipt.workflow.runId
  $policy.finalization.governedPackageSha256 = $completionReceipt.governedPackage.sha256
  $policy.finalization.closurePackageSha256 = $completionReceipt.closure.closurePackageSha256
  $policy.finalization.custodyRecordSha256 = $completionReceipt.closure.custodyRecordSha256
  $policy.finalization.controlledPilotApproved = $currentStagedPilotAuthorized
  $accepted = $true; $failure = $null
  try { Invoke-Expression $guard[0].Extent.Text }
  catch { $accepted = $false; $failure = $_.Exception.Message }
  [ordered]@{label = $case.label; accepted = $accepted; expected = $case.accepted; failure = $failure}
}
$rows | ConvertTo-Json -Compress -Depth 4
`);
    const rows = JSON.parse(execFileSync("pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"), path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1"), repositoryRoot], {cwd: fixtureRoot, encoding: "utf8", windowsHide: true, maxBuffer: 4 * 1024 * 1024}));
    assert.equal(rows.length, cases.length);
    assert.deepEqual(rows.filter((row) => row.accepted !== row.expected), []);
    t.diagnostic(`${rows.length} coherently rebound finalization custody cases`);
  } finally {
    assert.equal(path.dirname(path.resolve(fixtureRoot)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-custody-consumption-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});

// Synthetic successor receipts execute the actual acceptance branches. No
// physical result is created or admitted by this test.
test("PowerShell deployment count checks bind each selected source without granting new approval", (t) => {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-source-fleet-count-"));
  const backend = JSON.parse(fs.readFileSync(path.join(repositoryRoot, "release/evidence/build28-backend-deployment-closure.json"), "utf8"));
  const approval = JSON.parse(fs.readFileSync(path.join(repositoryRoot, backend.approvalAuthority.file), "utf8"));
  const currentCommit = execFileSync("git", ["rev-parse", "HEAD"], {cwd: repositoryRoot, encoding: "utf8"}).trim();
  const cases = [];
  for (const [sourceCommit, expectedCount] of [[backend.sourceAuthority.commit, 15], [currentCommit, 19]]) {
    for (const functionCount of [expectedCount, expectedCount === 15 ? 19 : 15, String(expectedCount), [expectedCount], null, true, 0]) {
      cases.push({sourceCommit, functionCount, accepted: functionCount === expectedCount,
        label: `${sourceCommit.slice(0, 8)} count ${JSON.stringify(functionCount)}`});
    }
  }
  try {
    fs.writeFileSync(path.join(fixtureRoot, "fixture.json"), JSON.stringify({backend, approval, cases}));
    fs.writeFileSync(path.join(fixtureRoot, "check.ps1"), String.raw`
param([string]$ProductionSource, [string]$RepositoryRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($ProductionSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Production verifier does not parse' }
foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
  Invoke-Expression $definition.Extent.Text
}
$blocks = foreach ($message in @('Exact Function fleet deployment receipt is incomplete.', 'Current Function fleet deployment authority is incomplete.')) {
  $block = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.IfStatementAst] -and $node.Extent.Text.Contains("throw '$message'")}, $false))
  if ($block.Count -ne 1) { throw "Expected one production count check for $message" }
  $block[0].Extent.Text
}
$assignments = foreach ($name in @('$expectedFunctionFleetContract', '$currentFunctionFleetContract')) {
  $assignment = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq $name}, $false))
  if ($assignment.Count -ne 1) { throw "Expected exact source-bound contract assignment for $name" }
  $assignment[0].Extent.Text
}
$fixture = Get-Content fixture.json -Raw | ConvertFrom-Json
$rows = foreach ($case in $fixture.cases) {
  $functionFleetDeploymentReceipt = $fixture.backend | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $functionFleetDeploymentReceipt.sourceAuthority.commit = $case.sourceCommit
  $functionFleetDeploymentReceipt.deployment.functionCount = $case.functionCount
  $currentFunctionFleetDeploymentReceipt = $functionFleetDeploymentReceipt
  $currentDeploymentApproval = $fixture.approval | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $currentDeploymentApproval.sourceAuthority.commit = $case.sourceCommit
  $currentDeploymentApprovalPath = $functionFleetDeploymentReceipt.approvalAuthority.file
  $currentDeploymentApprovalSha256 = $functionFleetDeploymentReceipt.approvalAuthority.sha256
  $expectedFunctionFleetSourceCommit = $case.sourceCommit
  $expectedFunctionFleetSourceTree = $functionFleetDeploymentReceipt.sourceAuthority.tree
  $expectedFunctionFleetPullRequest = $functionFleetDeploymentReceipt.sourceAuthority.pullRequestNumber
  $currentDeployedBackendAuthority = [pscustomobject]@{functionFleetSourceCommit = $case.sourceCommit}
  $accepted = $true; $failure = $null
  try {
    foreach ($assignment in $assignments) { Invoke-Expression $assignment }
    foreach ($block in $blocks) { Invoke-Expression $block }
  } catch { $accepted = $false; $failure = $_.Exception.Message }
  [ordered]@{label=$case.label; accepted=$accepted; expected=$case.accepted; failure=$failure}
}
$rows | ConvertTo-Json -Depth 4 -Compress
`);
    const rows = JSON.parse(execFileSync("pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"),
      path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1"), repositoryRoot],
    {cwd: fixtureRoot, encoding: "utf8", windowsHide: true, maxBuffer: 4 * 1024 * 1024}));
    assert.equal(rows.length, cases.length);
    assert.deepEqual(rows.filter((row) => row.accepted !== row.expected), []);
    t.diagnostic(`${rows.length} actual count-branch checks; other approval/custody gates are deliberately not bypassed by this isolated test`);
  } finally {
    assert.equal(path.dirname(path.resolve(fixtureRoot)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-source-fleet-count-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});

test("Build 28 owner acceptance binds the exact artifact and rejects unhealthy or broadened evidence", (t) => {
  const read = (name) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, name), "utf8"));
  const originalDevice = read("release/evidence/build-27-device-acceptance.json");
  const originalCompletion = read("release/evidence/build-27-finalization-closure.json");
  const git = (...args) => execFileSync("git", ["--no-replace-objects", "-C", repositoryRoot, ...args],
    {encoding: "utf8", windowsHide: true}).trim();
  const candidateCommit = git("rev-parse", "HEAD");
  const candidateTree = git("rev-parse", `${candidateCommit}^{tree}`);
  const candidateSchema = git("show", `${candidateCommit}:lib/core/services/isar_schema_migration.dart`);
  assert.match(candidateSchema, /static const int currentSchemaVersion = 11;/);
  const schemaFingerprint = [...candidateSchema.match(/static const String currentSchemaFingerprint =([\s\S]*?);/)[1]
    .matchAll(/'([^']+)'/g)].map((part) => part[1]).join("");
  const schemaFingerprintSha256 = createHash("sha256").update(schemaFingerprint, "utf8").digest("hex").toUpperCase();
  const requiredSource = {localStoreSchemaVersion: 11, localStoreSchemaFingerprintSha256: schemaFingerprintSha256};
  const device = structuredClone(originalDevice);
  const completion = structuredClone(originalCompletion);
  Object.assign(completion.release, {
    buildNumber: 28, versionName: "1.0.0-rc.18",
    releaseId: "crm3-baf-ops-1.0.0-rc.18-b28",
  });
  completion.sourceAuthority.commit = candidateCommit;
  completion.sourceAuthority.tree = candidateTree;
  completion.governedPackage.version = "1.0.0-rc.18+28";
  Object.assign(device.release, {
    ...completion.release,
    sourceCommit: completion.sourceAuthority.commit,
    sourceTree: completion.sourceAuthority.tree,
    finalizationReceiptFile: "completion.json",
  });
  Object.assign(device.physicalDevice, {
    priorVersionCode: 27, installedVersionCode: 28,
    installedVersionName: "1.0.0-rc.18",
  });
  device.status = "passed-exact-build28-physical-in-place-authenticated-read-only-surfaces";
  device.releaseBoundary.build27FinalizationReceiptChanged = false;
  device.localStoreMigration.targetSchemaVersion = 11;
  device.localStoreMigration.targetSchemaFingerprintSha256 = schemaFingerprintSha256;
  const base = {
    label: "healthy owner evaluation", device, completion, accepted: true,
    pilot: false, installationAuthorized: true, environmentInstallationAuthorized: true,
    requiredSource,
  };
  const historical = {
    ...structuredClone(base), label: "historical Build 27 unchanged",
    device: originalDevice, completion: originalCompletion, pilot: true,
  };
  const priorSchemaCandidate = structuredClone(base);
  priorSchemaCandidate.label = "schema 10 artifact retains existing evidence shape";
  priorSchemaCandidate.completion.sourceAuthority = structuredClone(originalCompletion.sourceAuthority);
  priorSchemaCandidate.device.release.sourceCommit = originalCompletion.sourceAuthority.commit;
  priorSchemaCandidate.device.release.sourceTree = originalCompletion.sourceAuthority.tree;
  priorSchemaCandidate.device.localStoreMigration = structuredClone(originalDevice.localStoreMigration);
  delete priorSchemaCandidate.requiredSource;
  const withoutMeasuredFingerprint = structuredClone(base);
  withoutMeasuredFingerprint.label = "schema 11 governed open does not require an unavailable device hash";
  delete withoutMeasuredFingerprint.device.localStoreMigration.targetSchemaFingerprintSha256;
  const cases = [historical, priorSchemaCandidate, base, withoutMeasuredFingerprint];
  const change = (label, edit) => {
    const value = structuredClone(base);
    value.label = label;
    value.accepted = false;
    edit(value);
    cases.push(value);
  };
  const set = (object, field, value) => {
    const parts = field.split(".");
    const parent = parts.slice(0, -1).reduce((current, key) => current[key], object);
    if (value === undefined) delete parent[parts.at(-1)];
    else parent[parts.at(-1)] = value;
  };
  for (const value of [undefined, null, false, [], [requiredSource]]) {
    change(`invalid schema requirement object: ${JSON.stringify(value)}`, (row) => set(row, "requiredSource", value));
  }
  for (const value of [undefined, null, "11", 10, 12, false, [11]]) {
    change(`invalid approved schema version: ${JSON.stringify(value)}`, (row) =>
      set(row.requiredSource, "localStoreSchemaVersion", value));
  }
  for (const value of [undefined, null, false, [], [schemaFingerprintSha256], "0".repeat(64), schemaFingerprintSha256.toLowerCase()]) {
    change(`invalid approved schema fingerprint: ${JSON.stringify(value)}`, (row) =>
      set(row.requiredSource, "localStoreSchemaFingerprintSha256", value));
    if (value !== undefined) {
      change(`invalid measured schema fingerprint: ${JSON.stringify(value)}`, (row) =>
        set(row.device, "localStoreMigration.targetSchemaFingerprintSha256", value));
    }
  }
  for (const [field, value] of [
    ["device.localStoreMigration.governedOpenCompleted", false],
    ["device.localStoreMigration.targetSchemaVersion", 10],
    ["device.physicalDevice.exactGovernedApkMatch", false],
    ["requiredSource.localStoreSchemaFingerprintSha256", undefined],
  ]) {
    const row = structuredClone(withoutMeasuredFingerprint);
    row.label = `optional device hash still requires ${field}`;
    row.accepted = false;
    set(row, field, value);
    cases.push(row);
  }
  change("coherent receipt and approval downgrade cannot override schema 11 source", (row) => {
    row.requiredSource.localStoreSchemaVersion = 10;
    row.device.localStoreMigration.targetSchemaVersion = 10;
    delete row.device.localStoreMigration.targetSchemaFingerprintSha256;
  });
  change("coherent receipt and approval fingerprint replacement cannot override source", (row) => {
    row.requiredSource.localStoreSchemaFingerprintSha256 = "0".repeat(64);
    row.device.localStoreMigration.targetSchemaFingerprintSha256 = "0".repeat(64);
  });
  change("artifact source tree must actually resolve", (row) => {
    row.completion.sourceAuthority.tree = "9".repeat(40);
    row.device.release.sourceTree = "9".repeat(40);
  });
  change("unavailable source cannot derive expectations from receipt or approval", (row) => {
    row.completion.sourceAuthority.commit = "8".repeat(40);
    row.device.release.sourceCommit = "8".repeat(40);
  });
  change("old source cannot acquire schema 11 through new declarations", (row) => {
    row.completion.sourceAuthority = structuredClone(originalCompletion.sourceAuthority);
    row.device.release.sourceCommit = originalCompletion.sourceAuthority.commit;
    row.device.release.sourceTree = originalCompletion.sourceAuthority.tree;
  });
  const contradictoryPriorSchema = structuredClone(priorSchemaCandidate);
  contradictoryPriorSchema.label = "present schema 10 fingerprint cannot contradict source";
  contradictoryPriorSchema.accepted = false;
  contradictoryPriorSchema.device.localStoreMigration.targetSchemaFingerprintSha256 = "0".repeat(64);
  cases.push(contradictoryPriorSchema);
  for (const field of [
    "unsyncedRows", "unresolvedRejections", "pushFailed", "fullSyncConflicts",
    "processingErrors", "likelyPermanentRejections", "globalPullConflict",
  ]) {
    for (const value of [1, -1, "0", false, null, [], [0], undefined]) {
      change(`invalid ${field}: ${JSON.stringify(value)}`, (row) =>
        set(row.device, `synchronization.${field}`, value));
    }
  }
  for (const value of [0, -1, 0.5, "2", false, null, [2], undefined]) {
    change(`invalid automatic completion: ${JSON.stringify(value)}`, (row) =>
      set(row.device, "synchronization.automaticStartupSyncPassesObserved", value));
  }
  for (const value of ["running", "error", "IDLE", ["idle"], null, undefined]) {
    change(`incomplete sync: ${JSON.stringify(value)}`, (row) =>
      set(row.device, "synchronization.syncStateAtInventory", value));
  }
  for (const field of [
    "release.releaseId", "release.versionName", "release.applicationId",
    "release.sourceCommit", "release.sourceTree", "release.governedPackageSha256",
    "release.apkSha256", "release.certificateSha256", "release.finalizationReceiptFile",
    "physicalDevice.installedVersionName", "physicalDevice.installationMode",
    "physicalDevice.installationResult", "runtime.coldLaunchResult",
  ]) {
    const valid = field.split(".").reduce((current, key) => current[key], device);
    for (const value of ["wrong", null, [valid], undefined]) {
      change(`wrong identity/result ${field}: ${JSON.stringify(value)}`, (row) =>
        set(row.device, field, value));
    }
  }
  for (const field of ["release.buildNumber", "release.apkSizeBytes", "physicalDevice.installedVersionCode", "physicalDevice.targetCount", "localStoreMigration.targetSchemaVersion"]) {
    const valid = field.split(".").reduce((current, key) => current[key], device);
    for (const value of ["28", false, null, [], [valid], undefined, -1]) {
      change(`invalid integer ${field}: ${JSON.stringify(value)}`, (row) => set(row.device, field, value));
    }
  }
  for (const field of [
    "physicalDevice.exactGovernedApkMatch", "physicalDevice.signerContinuityVerifiedByInPlaceUpdate",
    "physicalDevice.firstInstallTimePreserved", "physicalDevice.applicationDataPreserved",
    "runtime.processRemainedAlive", "runtime.approvedAuthenticatedSessionPreserved",
    "runtime.authenticatedHomeRendered", "localStoreMigration.governedOpenCompleted",
    "localStoreMigration.applicationDataPreserved", "adjudication.physicalInPlaceMigrationPassed",
  ]) {
    for (const value of [false, "true", 1, null, [], [true], undefined]) {
      change(`missing success ${field}: ${JSON.stringify(value)}`, (row) => set(row.device, field, value));
    }
  }
  for (const field of [
    "physicalDevice.applicationDataCleared", "physicalDevice.applicationUninstalled",
    "runtime.androidCrashObserved", "runtime.androidAnrObserved", "runtime.flutterFatalErrorObserved",
    "runtime.firebaseCallableFailureObserved", "runtime.permissionDenialObserved",
    "localStoreMigration.isarOpenFailureObserved", "releaseBoundary.controlledPilotApprovedByThisReceipt",
    "releaseBoundary.pilotHandoutPerformed", "releaseBoundary.unrestrictedDistributionApproved",
    "releaseBoundary.productionBusinessMutationAuthorizedByThisReceipt", "releaseBoundary.firebaseBusinessDataChanged",
    "releaseBoundary.appCheckActivationPerformed", "releaseBoundary.deviceDataClearPerformed",
    "releaseBoundary.build27FinalizationReceiptChanged", "businessMutationBoundary.productionBusinessDataCreatedUpdatedOrDeleted",
  ]) {
    for (const value of [true, "false", 0, null, [], [false], undefined]) {
      change(`adverse boundary ${field}: ${JSON.stringify(value)}`, (row) => set(row.device, field, value));
    }
  }
  change("missing mutation inventory", (row) => { row.device.businessMutationBoundary = {}; });
  change("surface missing", (row) => row.device.validatedReadOnlySurfaces.pop());
  change("surface non-scalar", (row) => { row.device.validatedReadOnlySurfaces[0] = [row.device.validatedReadOnlySurfaces[0]]; });
  change("unapproved installation", (row) => { row.installationAuthorized = false; });
  change("unapproved environment installation", (row) => { row.environmentInstallationAuthorized = false; });
  change("installation approval must be boolean", (row) => { row.installationAuthorized = "true"; });
  change("installation approval cannot be an array", (row) => { row.installationAuthorized = [true]; });
  change("wrong finalization digest", (row) => { row.tamperFinalizationHash = true; });
  change("wrong device-file digest", (row) => { row.tamperDeviceHash = true; });
  for (const field of ["recordedAtUtc", "synchronization.inventoryCapturedAtUtc"]) {
    for (const value of [undefined, null, false, 0, [], ["2026-09-08T13:00:00Z"], "not-a-dateZ", "2026-02-30T13:00:00Z", "2026-09-08T13:00:00", "2026-09-08T13:00:00+05:30"]) {
      change(`invalid evidence timestamp ${field}: ${JSON.stringify(value)}`, (row) => set(row.device, field, value));
    }
  }
  change("both evidence timestamps absent", (row) => {
    delete row.device.recordedAtUtc;
    delete row.device.synchronization.inventoryCapturedAtUtc;
  });
  change("acceptance predates its inventory", (row) => {
    row.device.recordedAtUtc = "2026-09-08T12:43:59Z";
    row.device.synchronization.inventoryCapturedAtUtc = "2026-09-08T12:44:01Z";
  });
  const equalInstants = structuredClone(base);
  equalInstants.label = "acceptance may equal the completed inventory instant";
  equalInstants.device.recordedAtUtc = "2026-09-08T13:00:00Z";
  equalInstants.device.synchronization.inventoryCapturedAtUtc = "2026-09-08T13:00:00Z";
  cases.push(equalInstants);
  change("two phones are not single-owner evidence", (row) => { row.device.physicalDevice.targetCount = 2; });
  change("unproven prior version", (row) => { row.device.physicalDevice.priorVersionCode = 28; });
  change("prior version must be integer", (row) => { row.device.physicalDevice.priorVersionCode = "27"; });

  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-build28-acceptance-"));
  try {
    fs.writeFileSync(path.join(fixtureRoot, "cases.json"), JSON.stringify(cases));
    fs.writeFileSync(path.join(fixtureRoot, "check.ps1"), String.raw`
param([string]$ProductionSource, [string]$RepositoryRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($ProductionSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Production verifier does not parse' }
foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
  Invoke-Expression $definition.Extent.Text
}
foreach ($name in @('$ExpectedBuild18ReadOnlySurfaces', '$ExpectedBuild27ReadOnlySurfaces', '$ExpectedBuild28ReadOnlySurfaces')) {
  $assignment = $ast.Find({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq $name}, $false)
  if ($null -ne $assignment) { Invoke-Expression $assignment.Extent.Text }
}
$branches = foreach ($condition in @('$policy.finalization.runtimeValidationPassed -eq $true', '$policy.finalization.physicalInstallationConditionPassed -eq $true')) {
  $branch = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -eq $condition -and $node.Extent.Text.Contains('physicalDevice')}, $true))
  if ($branch.Count -ne 1) { throw "Expected one live acceptance branch: $condition" }
  $branch[0].Extent.Text
}
$rows = foreach ($case in (Get-Content cases.json -Raw | ConvertFrom-Json)) {
  $completionReceiptPath = 'completion.json'
  $case.completion | ConvertTo-Json -Depth 35 | Set-Content -LiteralPath $completionReceiptPath -Encoding utf8
  $completionReceipt = Get-Content $completionReceiptPath -Raw | ConvertFrom-Json
  $case.device.release.finalizationReceiptSha256 = Get-Sha256 $completionReceiptPath
  if ($null -ne $case.PSObject.Properties['tamperFinalizationHash']) { $case.device.release.finalizationReceiptSha256 = '0' * 64 }
  $case.device | ConvertTo-Json -Depth 35 | Set-Content -LiteralPath 'device.json' -Encoding utf8
  $currentBuildNumber = [int]$completionReceipt.release.buildNumber
  $currentStagedPilotAuthorized = $case.pilot
  $historicalStagedPilotAuthorityPreserved = -not $case.pilot
  $versionSource = [pscustomobject]@{ controls = [pscustomobject]@{ attachedPhoneInPlaceInstallationAuthorized = $case.installationAuthorized } }
  if ($null -ne $case.PSObject.Properties['requiredSource']) {
    $versionSource | Add-Member -NotePropertyName requiredSource -NotePropertyValue $case.requiredSource
  }
  $environmentApproval = [pscustomobject]@{ controls = [pscustomobject]@{ installationApproved = $case.environmentInstallationAuthorized } }
  $policy = [pscustomobject]@{
    release = $completionReceipt.release
    finalization = [pscustomobject]@{
      runtimeValidationPassed = $true
      fullBusinessFlowValidationCompleted = $false
      physicalInstallationConditionPassed = $true
      deviceAcceptanceReceiptFile = 'device.json'
      deviceAcceptanceReceiptSha256 = Get-Sha256 'device.json'
      physicalInstallationReceiptFile = 'device.json'
      physicalInstallationReceiptSha256 = Get-Sha256 'device.json'
      runtimeDisposition = "passed-exact-build$currentBuildNumber-physical-in-place-authenticated-read-only-surfaces"
    }
  }
  if ($null -ne $case.PSObject.Properties['tamperDeviceHash']) { $policy.finalization.deviceAcceptanceReceiptSha256 = '0' * 64 }
  $accepted = $true; $failure = $null
  try { foreach ($branch in $branches) { Invoke-Expression $branch } }
  catch { $accepted = $false; $failure = $_.Exception.Message }
  [ordered]@{ label = $case.label; accepted = $accepted; expected = $case.accepted; failure = $failure }
}
$rows | ConvertTo-Json -Compress -Depth 4
`);
    const rows = JSON.parse(execFileSync("pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"), path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1"), repositoryRoot], {
      cwd: fixtureRoot, encoding: "utf8", windowsHide: true, maxBuffer: 4 * 1024 * 1024,
    }));
    assert.equal(rows.length, cases.length);
    assert.deepEqual(rows.filter((row) => row.accepted !== row.expected), []);
    t.diagnostic(`${rows.length} actual-branch acceptance cases, including the historical Build 27 control`);
  } finally {
    assert.equal(path.dirname(path.resolve(fixtureRoot)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-build28-acceptance-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});
