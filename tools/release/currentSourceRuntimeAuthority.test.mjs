import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
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
