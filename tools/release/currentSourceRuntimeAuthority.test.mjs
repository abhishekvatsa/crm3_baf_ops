import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {createHash} from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

// Execute the production classifiers against real Git trees without running
// the complete release gate or changing the application's repository.
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
test("Build 28 owner acceptance binds the exact artifact and rejects unhealthy or broadened evidence", (t) => {
  const read = (name) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, name), "utf8"));
  const originalDevice = read("release/evidence/build-27-device-acceptance.json");
  const originalCompletion = read("release/evidence/build-27-finalization-closure.json");
  const device = structuredClone(originalDevice);
  const completion = structuredClone(originalCompletion);
  Object.assign(completion.release, {
    buildNumber: 28, versionName: "1.0.0-rc.18",
    releaseId: "crm3-baf-ops-1.0.0-rc.18-b28",
  });
  completion.sourceAuthority.commit = "8".repeat(40);
  completion.sourceAuthority.tree = "9".repeat(40);
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
  const base = {
    label: "healthy owner evaluation", device, completion, accepted: true,
    pilot: false, installationAuthorized: true, environmentInstallationAuthorized: true,
  };
  const historical = {
    ...structuredClone(base), label: "historical Build 27 unchanged",
    device: originalDevice, completion: originalCompletion, pilot: true,
  };
  const cases = [historical, base];
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
param([string]$ProductionSource)
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
    const rows = JSON.parse(execFileSync("pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"), path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1")], {
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
