import assert from "node:assert/strict";
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
