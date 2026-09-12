"use strict";

const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");

const POLICY_PATH = "release/function-fleet-runtime-identity-policy.json";
const CLASSES = Object.freeze({
  CALLABLE_FIRESTORE_MUTATION: "callableCount",
  CALLABLE_FIRESTORE_READ_ONLY: "callableCount",
  APP_CHECKED_CALLABLE_FIRESTORE_READ_ONLY: "callableCount",
  FIRESTORE_NOTIFICATION_TRIGGER: "eventAndProtocolTriggerCount",
  FIRESTORE_PROTOCOL_TRIGGER: "eventAndProtocolTriggerCount",
  SCHEDULED_FIRESTORE_MUTATION: "schedulerCount",
});

// This describes the selected Git source. It grants no deployment authority;
// the caller must still verify the independently admitted approval and receipts.
function readDeploymentFleetContract(repoRoot, sourceCommit) {
  if (typeof sourceCommit !== "string" || !/^[0-9a-f]{40}$/i.test(sourceCommit)) {
    throw new Error("Deployment fleet: an exact source commit is required.");
  }
  const raw = execFileSync("git", ["--no-replace-objects", "-C", repoRoot,
    "show", `${sourceCommit}:${POLICY_PATH}`],
  {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
  const policy = JSON.parse(raw);
  if (policy.schemaVersion !== 1 || policy.productionProjectId !== "crm3-baf-ops-b8638" ||
      !policy.functionBindings || Array.isArray(policy.functionBindings) ||
      typeof policy.functionBindings !== "object") {
    throw new Error("Deployment fleet: invalid source policy.");
  }
  const functionNames = Object.keys(policy.functionBindings).sort();
  const counts = {functionCount: functionNames.length, callableCount: 0,
    eventAndProtocolTriggerCount: 0, schedulerCount: 0};
  const principals = new Set();
  if (functionNames.length === 0) throw new Error("Deployment fleet: source policy is empty.");
  for (const name of functionNames) {
    const binding = policy.functionBindings[name];
    const kind = binding && !Array.isArray(binding) &&
      typeof binding.workloadClass === "string" && Object.hasOwn(CLASSES, binding.workloadClass)
      ? CLASSES[binding.workloadClass] : null;
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(name) || !kind ||
        typeof binding.runtimeServiceAccountId !== "string" ||
        !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(binding.runtimeServiceAccountId)) {
      throw new Error(`Deployment fleet: invalid binding for ${name}.`);
    }
    counts[kind] += 1;
    principals.add(binding.runtimeServiceAccountId);
  }
  return {sourceCommit, functionNames, ...counts, runtimePrincipalCount: principals.size};
}

function deploymentCountsMatch(contract, value) {
  return ["functionCount", "callableCount", "eventAndProtocolTriggerCount", "schedulerCount"]
    .every((field) => Number.isSafeInteger(value?.[field]) && value[field] === contract[field]);
}

function measuredFunctionNamesMatch(contract, records) {
  return Array.isArray(records) && records.every((record) => typeof record?.name === "string") &&
    isDeepStrictEqual(records.map((record) => record.name).sort(), contract.functionNames);
}

module.exports = {readDeploymentFleetContract, deploymentCountsMatch, measuredFunctionNamesMatch};

if (require.main === module) {
  try {
    const [repoRoot, sourceCommit, ...extra] = process.argv.slice(2);
    if (!repoRoot || extra.length) throw new Error("Expected repository root and exact source commit.");
    process.stdout.write(`${JSON.stringify(readDeploymentFleetContract(repoRoot, sourceCommit))}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
