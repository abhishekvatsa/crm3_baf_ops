import assert from "node:assert/strict";
import childProcess from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const currentFile = fileURLToPath(import.meta.url);
const repositoryRoot = path.resolve(path.dirname(currentFile), "..", "..");
const source = fs.readFileSync(path.join(
  repositoryRoot,
  "tools",
  "release",
  "Invoke-FunctionFleetRuntimeIdentityCampaign.ps1",
), "utf8");

function extractPowerShellFunction(name) {
  const start = source.indexOf(`function ${name} {`);
  assert.ok(start >= 0, `missing PowerShell function ${name}`);
  let depth = 0;
  for (let index = source.indexOf("{", start); index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(start, index + 1);
  }
  assert.fail(`unterminated PowerShell function ${name}`);
}

test("campaign is exact-target, phased and clean-main bound", () => {
  for (const value of [
    "crm3-baf-ops-b8638",
    "asia-south1",
    "Campaign phases require exact tracked-clean main equal to origin/main.",
    "exact four-job successful post-merge release gate",
  ]) {
    assert.ok(source.includes(value), value);
  }
  for (const phase of [
    "Preflight",
    "Provision",
    "DeployCallables",
    "DeployEvents",
    "DeployScheduler",
    "Finalize",
    "RestoreEditor",
  ]) {
    assert.ok(source.includes(`'${phase}'`), phase);
  }
});

test("scheduler deployment is preceded by a fresh zero-backlog readback", () => {
  const phase = source.slice(source.indexOf("  'DeployScheduler' {"));
  const preflight = phase.indexOf("$schedulerPreflightPath");
  const deploy = phase.indexOf("Invoke-FunctionDeployment -FunctionNames $scheduler");
  assert.ok(preflight >= 0);
  assert.ok(deploy > preflight);
  assert.ok(source.includes("05-scheduler-preflight.json"));
});

test("Editor removal is final, reversible and never coupled to Function deletion", () => {
  const final = source.indexOf("  'Finalize' {");
  const removeEditor = source.indexOf(
    "Remove-ProjectRole -Email $defaultCompute -Role 'roles/editor'",
  );
  const restoreEditor = source.indexOf(
    "Ensure-ProjectRole -Email $defaultCompute -Role 'roles/editor'",
    removeEditor,
  );
  assert.ok(removeEditor > final);
  assert.ok(restoreEditor > removeEditor);
  for (const forbidden of [
    "service-accounts delete",
    "functions delete",
    "firestore:delete",
    "projects delete",
    "appcheck",
  ]) {
    assert.equal(source.toLowerCase().includes(forbidden), false, forbidden);
  }
});

test("deployment preserves the governed App Check deferral and exact cohorts", () => {
  assert.ok(source.includes("CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false"));
  assert.ok(source.includes("Get-FunctionNamesByClass"));
  assert.ok(source.includes("CALLABLE_FIRESTORE_MUTATION"));
  assert.ok(source.includes("FIRESTORE_NOTIFICATION_TRIGGER"));
  assert.ok(source.includes("SCHEDULED_FIRESTORE_MUTATION"));
  assert.ok(source.includes("--non-interactive"));
  assert.equal(source.includes("--force"), false);
});

test("final phase requires both exact IAM and generation-pinned dependency posture", () => {
  assert.ok(source.includes("08-final.json"));
  assert.ok(source.includes("09-lr03-lr06-final.json"));
  assert.ok(source.includes("collectFunctionsIamDependenciesReadback.js"));
  assert.ok(source.includes("PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE"));
});

test("dependency posture gates removal and every post-removal collector failure restores Editor", () => {
  const final = source.slice(source.indexOf("  'Finalize' {"));
  const preFinalDecision = final.indexOf("$preFinalDependencies.posture.decision");
  const removeEditor = final.indexOf(
    "Remove-ProjectRole -Email $defaultCompute -Role 'roles/editor'",
  );
  const finalReadbackCatch = final.indexOf("    } catch {", removeEditor);
  const finalDependencyTry = final.indexOf("    try {", finalReadbackCatch);
  const finalCollector = final.indexOf("$finalDependenciesPath", finalDependencyTry);
  const finalDependencyCatch = final.indexOf("    } catch {", finalCollector);
  const restoreEditor = final.indexOf(
    "Ensure-ProjectRole -Email $defaultCompute -Role 'roles/editor'",
    finalDependencyCatch,
  );
  assert.ok(preFinalDecision >= 0);
  assert.ok(removeEditor > preFinalDecision);
  assert.ok(finalReadbackCatch > removeEditor);
  assert.ok(finalDependencyTry > finalReadbackCatch);
  assert.ok(finalCollector > finalDependencyTry);
  assert.ok(finalDependencyCatch > finalCollector);
  assert.ok(restoreEditor > finalDependencyCatch);
  assert.ok(final.includes(
    "Final dependency readback failed; Default Compute Editor was restored.",
  ));
});

test("strict-mode helpers accept absent optional IAM and policy fields", () => {
  const powershell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  const fixture = `
Set-StrictMode -Version Latest
${extractPowerShellFunction("Test-IsUnconditionalIamBinding")}
${extractPowerShellFunction("Test-RequiresCloudRunServiceRole")}
$absentCondition = [pscustomobject]@{ role = 'roles/viewer' }
$nullCondition = [pscustomobject]@{ role = 'roles/viewer'; condition = $null }
$conditional = [pscustomobject]@{
  role = 'roles/viewer'
  condition = [pscustomobject]@{ expression = 'true' }
}
$withoutRunRole = [pscustomobject]@{ workloadClass = 'CALLABLE' }
$withRunRole = [pscustomobject]@{
  workloadClass = 'EVENT'
  requiredCloudRunServiceRoles = @('roles/run.invoker')
}
if (-not (Test-IsUnconditionalIamBinding -Binding $absentCondition)) { exit 11 }
if (-not (Test-IsUnconditionalIamBinding -Binding $nullCondition)) { exit 12 }
if (Test-IsUnconditionalIamBinding -Binding $conditional) { exit 13 }
if (Test-RequiresCloudRunServiceRole -Binding $withoutRunRole) { exit 14 }
if (-not (Test-RequiresCloudRunServiceRole -Binding $withRunRole)) { exit 15 }
`;
  const result = childProcess.spawnSync(
    powershell,
    ["-NoProfile", "-NonInteractive", "-Command", "-"],
    {input: fixture, encoding: "utf8", timeout: 15000, windowsHide: true},
  );
  assert.equal(
    result.status,
    0,
    `PowerShell fixture failed: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
  );
  assert.equal(
    source.match(/Test-IsUnconditionalIamBinding -Binding \$_/gu)?.length,
    2,
  );
  assert.ok(source.includes(
    "Test-RequiresCloudRunServiceRole -Binding $property.Value",
  ));
});

test("gcloud JSON conversion streams empty and populated collections exactly", () => {
  const powershell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  const fixture = `
Set-StrictMode -Version Latest
${extractPowerShellFunction("ConvertFrom-GcloudJson")}
$empty = @(ConvertFrom-GcloudJson -Raw '[]')
$single = @(ConvertFrom-GcloudJson -Raw '[{"name":"one"}]')
$object = ConvertFrom-GcloudJson -Raw '{"name":"object"}'
if ($empty.Count -ne 0) { exit 21 }
if ($single.Count -ne 1 -or $single[0].name -cne 'one') { exit 22 }
if ($object.name -cne 'object') { exit 23 }
`;
  const result = childProcess.spawnSync(
    powershell,
    ["-NoProfile", "-NonInteractive", "-Command", "-"],
    {input: fixture, encoding: "utf8", timeout: 15000, windowsHide: true},
  );
  assert.equal(
    result.status,
    0,
    `PowerShell JSON fixture failed: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
  );
  assert.ok(source.includes("ConvertFrom-GcloudJson -Raw $raw"));
});

test("deployment cohort selection preserves a singleton as one full name", () => {
  const powershell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  const fixture = `
Set-StrictMode -Version Latest
${extractPowerShellFunction("Get-FunctionNamesByClass")}
$policy = [pscustomobject]@{
  functionBindings = [pscustomobject]@{
    maintenanceWorkflowEscalationSweep = [pscustomobject]@{
      workloadClass = 'SCHEDULED_FIRESTORE_MUTATION'
    }
    beginGlobalPullRun = [pscustomobject]@{
      workloadClass = 'CALLABLE_FIRESTORE_READ_ONLY'
    }
  }
}
$selected = @(Get-FunctionNamesByClass -Classes @('SCHEDULED_FIRESTORE_MUTATION'))
if ($selected.Count -ne 1) { exit 41 }
if ($selected[0] -cne 'maintenanceWorkflowEscalationSweep') { exit 42 }
`;
  const result = childProcess.spawnSync(
    powershell,
    ["-NoProfile", "-NonInteractive", "-Command", "-"],
    {input: fixture, encoding: "utf8", timeout: 15000, windowsHide: true},
  );
  assert.equal(
    result.status,
    0,
    `PowerShell fixture failed: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
  );
  assert.ok(source.includes(
    "$scheduler = @(Get-FunctionNamesByClass -Classes @(",
  ));
});

test("native stderr is governed by exit code and restores stop mode", () => {
  const powershell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  const fixture = `
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
${extractPowerShellFunction("Invoke-ExternalText")}
$successScript = '[Console]::Error.WriteLine("stderr-success"); exit 0'
$success = Invoke-ExternalText -FilePath $env:CRM3_TEST_NATIVE_SHELL -Arguments @(
  '-NoProfile', '-NonInteractive', '-Command', $successScript
)
if ($success -notmatch 'stderr-success') { exit 31 }
if ($ErrorActionPreference -cne 'Stop') { exit 32 }
$failureScript = '[Console]::Error.WriteLine("stderr-failure"); exit 7'
$caught = $false
try {
  Invoke-ExternalText -FilePath $env:CRM3_TEST_NATIVE_SHELL -Arguments @(
    '-NoProfile', '-NonInteractive', '-Command', $failureScript
  ) | Out-Null
} catch {
  $caught = $_.Exception.Message -match 'External command failed \\(7\\)' -and
    $_.Exception.Message -match 'stderr-failure'
}
if (-not $caught) { exit 33 }
if ($ErrorActionPreference -cne 'Stop') { exit 34 }
`;
  const result = childProcess.spawnSync(
    powershell,
    ["-NoProfile", "-NonInteractive", "-Command", "-"],
    {
      input: fixture,
      encoding: "utf8",
      env: {...process.env, CRM3_TEST_NATIVE_SHELL: powershell},
      timeout: 30000,
      windowsHide: true,
    },
  );
  assert.equal(
    result.status,
    0,
    `PowerShell native-command fixture failed: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
  );
});
