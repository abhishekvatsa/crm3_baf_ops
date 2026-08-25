"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const {
  canonicalJson,
  sealReceipt,
  verifyReceiptSeal,
} = require("./collectProductionGlobalPullBackend.js");
const {
  collectSourceBinding,
  isPathInside,
  sha256,
} = require("./collectFirestoreRulesIndexesReadback.js");
const {
  discoverFunctionExports,
  resolveCommand,
} = require("./collectFunctionsIamDependenciesReadback.js");

const PRODUCTION_PROJECT_ID = "crm3-baf-ops-b8638";
const PRODUCTION_REGION = "asia-south1";
const POLICY_PATH = "release/function-fleet-runtime-identity-policy.json";
const PHASES = new Set([
  "preflight",
  "provisioned",
  "callables",
  "events",
  "fleet",
  "final",
]);
const CALLABLE_CLASSES = new Set([
  "CALLABLE_FIRESTORE_MUTATION",
  "CALLABLE_FIRESTORE_READ_ONLY",
  "APP_CHECKED_CALLABLE_FIRESTORE_READ_ONLY",
]);
const EVENT_CLASSES = new Set([
  "FIRESTORE_NOTIFICATION_TRIGGER",
  "FIRESTORE_PROTOCOL_TRIGGER",
]);
const SCHEDULE_CLASS = "SCHEDULED_FIRESTORE_MUTATION";

function fail(message) {
  throw new Error(message);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sortedUnique(values) {
  return [...new Set(values)].sort((left, right) => left.localeCompare(right));
}

function parseArgs(argv) {
  const options = {gcloudCommand: "gcloud", probeCallables: false};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--probe-callables") {
      options.probeCallables = true;
      continue;
    }
    const fields = {
      "--phase": "phase",
      "--repository-root": "repositoryRoot",
      "--project-id": "projectId",
      "--region": "region",
      "--output": "outputPath",
      "--gcloud": "gcloudCommand",
    };
    const field = fields[argument];
    if (field == null) fail(`Unsupported argument: ${argument}`);
    if (options[field] != null && field !== "gcloudCommand") {
      fail(`Duplicate argument: ${argument}`);
    }
    const value = argv[index + 1];
    if (value == null || value.startsWith("--")) {
      fail(`${argument} requires a value.`);
    }
    options[field] = value;
    index += 1;
  }
  for (const field of [
    "phase",
    "repositoryRoot",
    "projectId",
    "region",
    "outputPath",
  ]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  if (!PHASES.has(options.phase)) fail(`Unsupported phase: ${options.phase}`);
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    fail(`Only production project ${PRODUCTION_PROJECT_ID} is supported.`);
  }
  if (options.region !== PRODUCTION_REGION) {
    fail(`Only production region ${PRODUCTION_REGION} is supported.`);
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.outputPath = path.resolve(options.outputPath);
  return options;
}

function runText(command, args, options = {}) {
  const resolved = resolveCommand(command, args);
  try {
    return childProcess.execFileSync(resolved.command, resolved.args, {
      cwd: options.cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        CLOUDSDK_CORE_DISABLE_PROMPTS: "1",
        CLOUDSDK_CORE_DISABLE_USAGE_REPORTING: "1",
        ...resolved.environment,
      },
      maxBuffer: 64 * 1024 * 1024,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    if (options.allowNotFound) {
      const combined = `${error.stdout ?? ""}\n${error.stderr ?? ""}`;
      if (/NOT_FOUND|not found|does not exist/i.test(combined)) return null;
    }
    throw error;
  }
}

function gcloudJson(command, args, repositoryRoot, options = {}) {
  const raw = runText(command, [...args, "--format=json"], {
    cwd: repositoryRoot,
    allowNotFound: options.allowNotFound,
  });
  if (raw == null) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    fail(`gcloud returned malformed JSON: ${error.message}`);
  }
}

function basename(resourceName) {
  return String(resourceName ?? "").split("/").at(-1) ?? "";
}

function accountEmailMap(policy, projectId) {
  return Object.fromEntries(
    Object.entries(policy.functionBindings).map(([name, binding]) => [
      name,
      `${binding.runtimeServiceAccountId}@${projectId}.iam.gserviceaccount.com`,
    ]),
  );
}

function expandRole(role, projectId) {
  return role.replaceAll("${PROJECT_ID}", projectId);
}

function expectedProjectRoles(policy, projectId) {
  return Object.fromEntries(
    Object.entries(policy.functionBindings).map(([name, binding]) => [
      name,
      sortedUnique(binding.requiredProjectRoles.map((role) =>
        expandRole(role, projectId))),
    ]),
  );
}

function projectRolesByIdentity(iamPolicy, trackedEmails) {
  const tracked = new Set(trackedEmails);
  const result = Object.fromEntries(trackedEmails.map((email) => [email, []]));
  for (const binding of iamPolicy?.bindings ?? []) {
    if (binding.condition != null || typeof binding.role !== "string") continue;
    for (const member of binding.members ?? []) {
      if (typeof member !== "string" || !member.startsWith("serviceAccount:")) {
        continue;
      }
      const email = member.slice("serviceAccount:".length);
      if (tracked.has(email)) result[email].push(binding.role);
    }
  }
  return Object.fromEntries(
    Object.entries(result).map(([email, roles]) => [email, sortedUnique(roles)]),
  );
}

function normalizeFunctions(rawFunctions, projectId, region) {
  const prefix = `projects/${projectId}/locations/${region}/functions/`;
  return rawFunctions.map((record) => {
    if (typeof record?.name !== "string" || !record.name.startsWith(prefix)) {
      fail("A deployed Function is outside the exact project or region.");
    }
    const name = record.name.slice(prefix.length);
    const serviceAccountEmail = record.serviceConfig?.serviceAccountEmail ?? null;
    const runService = basename(record.serviceConfig?.service);
    const uri = record.serviceConfig?.uri ?? null;
    return {
      name,
      state: record.state ?? null,
      environment: record.environment ?? null,
      firebaseFunctionsHash:
        record.labels?.["firebase-functions-hash"] ?? null,
      serviceAccountEmail,
      runService: runService.length === 0 ? null : runService,
      uri: typeof uri === "string" && uri.startsWith("https://") ? uri : null,
      updateTime: record.updateTime ?? null,
    };
  }).sort((left, right) => left.name.localeCompare(right.name));
}

function summarizeServiceAccounts(rawAccounts, trackedEmails) {
  const byEmail = new Map(rawAccounts.map((account) => [account.email, account]));
  return trackedEmails.map((email) => ({
    email,
    exists: byEmail.has(email),
    disabled: byEmail.get(email)?.disabled === true,
  }));
}

function summarizeCustomRole(rawRole, policy, projectId) {
  const expectedName = `projects/${projectId}/roles/${policy.customRoles.notificationSender.roleId}`;
  return {
    exists: rawRole != null,
    name: rawRole?.name ?? expectedName,
    stage: rawRole?.stage ?? null,
    deleted: rawRole?.deleted === true,
    includedPermissions: sortedUnique(rawRole?.includedPermissions ?? []),
  };
}

function summarizeRunPolicy(policy, expectedEmail) {
  const roles = [];
  for (const binding of policy?.bindings ?? []) {
    if (binding.condition != null || typeof binding.role !== "string") continue;
    if ((binding.members ?? []).includes(`serviceAccount:${expectedEmail}`)) {
      roles.push(binding.role);
    }
  }
  return sortedUnique(roles);
}

async function collectBacklog(repositoryRoot, projectId) {
  const admin = require(path.join(
    repositoryRoot,
    "functions",
    "node_modules",
    "firebase-admin",
  ));
  const app = admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  }, `function-fleet-readback-${Date.now()}`);
  try {
    const db = app.firestore();
    const now = admin.firestore.Timestamp.now();
    const [lanes, raised, active] = await Promise.all([
      db.collection("job_lanes")
        .where("status", "==", "pending")
        .where("nextEscalationAt", "<=", now)
        .count().get(),
      db.collection("compliance_requests")
        .where("status", "==", "raised")
        .where("nextEscalationAt", "<=", now)
        .count().get(),
      db.collection("compliance_requests")
        .where("status", "in", ["acknowledged", "complied"])
        .where("nextEscalationAt", "<=", now)
        .count().get(),
    ]);
    const counts = {
      pendingLaneAcknowledgement: lanes.data().count,
      raisedComplianceAcknowledgement: raised.data().count,
      activeComplianceCompletion: active.data().count,
    };
    return {
      observedAtUtc: now.toDate().toISOString(),
      counts,
      total: Object.values(counts).reduce((sum, value) => sum + value, 0),
      documentIdsRetained: false,
      businessPayloadsRetained: false,
    };
  } finally {
    await app.delete();
  }
}

async function probeCallable(record) {
  if (record?.uri == null) {
    return {name: record?.name ?? null, safeNoSuccess: false, reason: "missing-uri"};
  }
  try {
    const response = await fetch(record.uri, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({data: {}}),
      signal: AbortSignal.timeout(15000),
    });
    const text = (await response.text()).slice(0, 4096);
    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }
    const errorStatus = parsed?.error?.status ?? null;
    const returnedData = parsed != null && Object.hasOwn(parsed, "data");
    const reachedCallableProtocol = parsed?.error != null &&
      response.status < 500;
    return {
      name: record.name,
      httpStatus: response.status,
      errorStatus,
      returnedData,
      reachedCallableProtocol,
      safeNoSuccess: !returnedData && reachedCallableProtocol,
    };
  } catch (error) {
    return {
      name: record.name,
      safeNoSuccess: false,
      reason: `probe-failed:${error.name ?? "Error"}`,
    };
  }
}

async function collectLiveState(options, policy) {
  const project = gcloudJson(
    options.gcloudCommand,
    ["projects", "describe", options.projectId],
    options.repositoryRoot,
  );
  const projectNumber = String(project.projectNumber ?? "");
  const emailMap = accountEmailMap(policy, options.projectId);
  const trackedRuntimeEmails = sortedUnique(Object.values(emailMap));
  const defaultCompute = `${projectNumber}-compute@developer.gserviceaccount.com`;
  const iamPolicy = gcloudJson(
    options.gcloudCommand,
    ["projects", "get-iam-policy", options.projectId],
    options.repositoryRoot,
  );
  const rawAccounts = gcloudJson(
    options.gcloudCommand,
    ["iam", "service-accounts", "list", `--project=${options.projectId}`],
    options.repositoryRoot,
  );
  const customRole = gcloudJson(
    options.gcloudCommand,
    [
      "iam", "roles", "describe",
      policy.customRoles.notificationSender.roleId,
      `--project=${options.projectId}`,
    ],
    options.repositoryRoot,
    {allowNotFound: true},
  );
  const rawFunctions = gcloudJson(
    options.gcloudCommand,
    [
      "functions", "list", "--v2",
      `--regions=${options.region}`,
      `--project=${options.projectId}`,
    ],
    options.repositoryRoot,
  );
  if (!Array.isArray(rawFunctions) || !Array.isArray(rawAccounts)) {
    fail("gcloud inventory did not return arrays.");
  }
  const functions = normalizeFunctions(
    rawFunctions,
    options.projectId,
    options.region,
  );
  const functionByName = new Map(functions.map((record) => [record.name, record]));
  const cloudRunBindings = [];
  for (const [name, binding] of Object.entries(policy.functionBindings)) {
    if (binding.requiredCloudRunServiceRoles == null) continue;
    const deployed = functionByName.get(name);
    if (deployed?.runService == null) continue;
    const runPolicy = gcloudJson(
      options.gcloudCommand,
      [
        "run", "services", "get-iam-policy", deployed.runService,
        `--region=${options.region}`,
        `--project=${options.projectId}`,
      ],
      options.repositoryRoot,
    );
    cloudRunBindings.push({
      functionName: name,
      runService: deployed.runService,
      expectedServiceAccountEmail: emailMap[name],
      roles: summarizeRunPolicy(runPolicy, emailMap[name]),
    });
  }
  const schedulerJobs = gcloudJson(
    options.gcloudCommand,
    [
      "scheduler", "jobs", "list",
      `--location=${options.region}`,
      `--project=${options.projectId}`,
    ],
    options.repositoryRoot,
  );
  const scheduleName =
    `firebase-schedule-maintenanceWorkflowEscalationSweep-${options.region}`;
  const scheduler = (schedulerJobs ?? []).find(
    (job) => basename(job.name) === scheduleName,
  );
  const callableNames = Object.entries(policy.functionBindings)
    .filter(([, binding]) => CALLABLE_CLASSES.has(binding.workloadClass))
    .map(([name]) => name)
    .sort();
  const callableProbes = options.probeCallables
    ? await Promise.all(callableNames
      .map((name) => functionByName.get(name))
      .filter(Boolean)
      .map(probeCallable))
    : [];
  return {
    project: {
      projectNumber,
      lifecycleState: project.lifecycleState ?? null,
    },
    emailMap,
    expectedRoles: expectedProjectRoles(policy, options.projectId),
    serviceAccounts: summarizeServiceAccounts(rawAccounts, trackedRuntimeEmails),
    customRole: summarizeCustomRole(customRole, policy, options.projectId),
    projectRoles: projectRolesByIdentity(
      iamPolicy,
      [...trackedRuntimeEmails, defaultCompute],
    ),
    defaultCompute,
    functions,
    cloudRunBindings,
    scheduler: scheduler == null ? null : {
      name: basename(scheduler.name),
      state: scheduler.state ?? null,
      schedule: scheduler.schedule ?? null,
      timeZone: scheduler.timeZone ?? null,
      oidcServiceAccountEmail:
        scheduler.httpTarget?.oidcToken?.serviceAccountEmail ?? null,
      lastAttemptTime: scheduler.lastAttemptTime ?? null,
      statusCode: scheduler.status?.code ?? null,
    },
    backlog: await collectBacklog(options.repositoryRoot, options.projectId),
    callableProbes,
  };
}

function sameValues(left, right) {
  return canonicalJson(left) === canonicalJson(right);
}

function includesAll(actual, expected) {
  const set = new Set(actual);
  return expected.every((value) => set.has(value));
}

function phaseRequiredNames(policy, phase) {
  const entries = Object.entries(policy.functionBindings);
  if (phase === "callables") {
    return entries.filter(([, binding]) => CALLABLE_CLASSES.has(
      binding.workloadClass,
    )).map(([name]) => name).sort();
  }
  if (phase === "events") {
    return entries.filter(([, binding]) => EVENT_CLASSES.has(
      binding.workloadClass,
    ) || CALLABLE_CLASSES.has(binding.workloadClass))
      .map(([name]) => name).sort();
  }
  if (phase === "fleet" || phase === "final") {
    return entries.map(([name]) => name).sort();
  }
  return [];
}

function adjudicateReadback({
  phase,
  projectId,
  region,
  policy,
  sourceBefore,
  sourceAfter,
  discoveredSourceExports,
  live,
  probeCallables,
}) {
  const policyNames = Object.keys(policy.functionBindings).sort();
  const expectedNames = [...discoveredSourceExports].sort();
  const actualNames = live.functions.map((record) => record.name).sort();
  const actualNameSet = new Set(actualNames);
  const requiredNames = phaseRequiredNames(policy, phase);
  const deployedByName = new Map(live.functions.map((record) => [record.name, record]));
  const exactBindingNames = requiredNames.filter((name) => {
    const deployed = deployedByName.get(name);
    return deployed?.state === "ACTIVE" &&
      deployed.environment === "GEN_2" &&
      deployed.serviceAccountEmail === live.emailMap[name];
  });
  const roleNames = Object.keys(live.emailMap);
  const accountByEmail = new Map(
    live.serviceAccounts.map((record) => [record.email, record]),
  );
  const allAccountsReady = roleNames.every((name) => {
    const account = accountByEmail.get(live.emailMap[name]);
    return account?.exists === true && account.disabled === false;
  });
  const customRoleExpected = sortedUnique(
    policy.customRoles.notificationSender.includedPermissions,
  );
  const customRoleReady = live.customRole.exists === true &&
    live.customRole.name ===
      `projects/${projectId}/roles/${policy.customRoles.notificationSender.roleId}` &&
    live.customRole.deleted === false &&
    sameValues(live.customRole.includedPermissions, customRoleExpected);
  const allRequiredRolesPresent = roleNames.every((name) => includesAll(
    live.projectRoles[live.emailMap[name]] ?? [],
    live.expectedRoles[name],
  ));
  const triggerNames = roleNames.filter((name) =>
    policy.functionBindings[name].requiredCloudRunServiceRoles != null);
  const forbiddenRoles = new Set(policy.forbiddenProjectRolesForRuntimeIdentities);
  const broadRuntimeGrants = roleNames.flatMap((name) =>
    (live.projectRoles[live.emailMap[name]] ?? [])
      .filter((role) => forbiddenRoles.has(role))
      .map((role) => ({functionName: name, role})),
  );
  const cloudRunByFunction = new Map(
    live.cloudRunBindings.map((record) => [record.functionName, record]),
  );
  const runBindingsReady = triggerNames.every((name) => {
    if (!requiredNames.includes(name)) return true;
    const observed = cloudRunByFunction.get(name)?.roles ?? [];
    return sameValues(
      observed,
      policy.functionBindings[name].requiredCloudRunServiceRoles,
    );
  });
  const triggerDeploymentInvokerReady = triggerNames.every((name) => {
    const projectInvokerPresent =
      (live.projectRoles[live.emailMap[name]] ?? []).includes("roles/run.invoker");
    const serviceRoles = cloudRunByFunction.get(name)?.roles ?? [];
    return projectInvokerPresent || sameValues(
      serviceRoles,
      policy.functionBindings[name].requiredCloudRunServiceRoles,
    );
  });
  const projectRunInvokerRemoved = triggerNames.every((name) =>
    !(live.projectRoles[live.emailMap[name]] ?? []).includes("roles/run.invoker"));
  const scheduleName = roleNames.find((name) =>
    policy.functionBindings[name].workloadClass === SCHEDULE_CLASS);
  const schedulerReady = scheduleName != null && live.scheduler != null &&
    live.scheduler.state === "ENABLED" &&
    ["every 15 minutes", "*/15 * * * *"].includes(live.scheduler.schedule) &&
    live.scheduler.timeZone === "Asia/Kolkata" &&
    live.scheduler.oidcServiceAccountEmail === live.emailMap[scheduleName] &&
    typeof live.scheduler.lastAttemptTime === "string" &&
    live.scheduler.statusCode == null;
  const exactRuntimeRoles = roleNames.every((name) => sameValues(
    live.projectRoles[live.emailMap[name]] ?? [],
    live.expectedRoles[name],
  ));
  const defaultComputeRoles = live.projectRoles[live.defaultCompute] ?? [];
  const defaultComputeFunctions = live.functions
    .filter((record) => record.serviceAccountEmail === live.defaultCompute)
    .map((record) => record.name);
  const expectedCallableNames = phaseRequiredNames(policy, "callables");
  const callableProbesReady = !probeCallables ||
    (live.callableProbes.length === expectedCallableNames.length &&
      sameValues(
        live.callableProbes.map((record) => record.name).sort(),
        expectedCallableNames,
      ) &&
      live.callableProbes.every((record) => record.safeNoSuccess === true));

  const checks = {
    exactProjectAndRegion:
      projectId === PRODUCTION_PROJECT_ID && region === PRODUCTION_REGION,
    projectActiveAndNumberPresent:
      live.project.lifecycleState === "ACTIVE" && /^\d+$/.test(live.project.projectNumber),
    policyMatchesTarget: policy.productionProjectId === projectId,
    sourceFunctionInventoryMatchesPolicy:
      sameValues(expectedNames, policyNames),
    sourceStable:
      sourceBefore.commit === sourceAfter.commit &&
      sourceBefore.tree === sourceAfter.tree,
    sourceIsCleanMain:
      sourceBefore.branch === "main" &&
      sourceAfter.branch === "main" &&
      sourceBefore.originMain === sourceBefore.commit &&
      sourceAfter.originMain === sourceAfter.commit &&
      sourceBefore.governedWorktreeClean === true &&
      sourceAfter.governedWorktreeClean === true,
    noUnexpectedLiveFunctions:
      actualNames.every((name) => policyNames.includes(name)),
    deployedFunctionsPresent: live.functions.length > 0,
    allObservedFunctionsActiveGen2:
      live.functions.every((record) =>
        record.state === "ACTIVE" && record.environment === "GEN_2"),
  };
  if (phase !== "final") {
    checks.schedulerBacklogZero = live.backlog.total === 0;
  }
  if (phase !== "preflight") {
    const defaultComputeProvisioningPostureValid =
      defaultComputeRoles.includes("roles/editor") ||
      sameValues(defaultComputeRoles, ["roles/cloudbuild.builds.builder"]);
    Object.assign(checks, {
      allRuntimeAccountsReady: allAccountsReady,
      notificationCustomRoleExact: customRoleReady,
      allRequiredProjectRolesPresent: allRequiredRolesPresent,
      noForbiddenRuntimeProjectRoles: broadRuntimeGrants.length === 0,
      defaultComputeProvisioningPostureValid:
        phase === "final" || defaultComputeProvisioningPostureValid,
      defaultComputeBuildRolePresent:
        defaultComputeRoles.includes("roles/cloudbuild.builds.builder"),
    });
  }
  if (phase === "provisioned") {
    checks.triggerDeploymentInvokerReady = triggerDeploymentInvokerReady;
  }
  if (["callables", "events", "fleet", "final"].includes(phase)) {
    Object.assign(checks, {
      requiredFunctionBindingsActive:
        sameValues(exactBindingNames.sort(), requiredNames),
      unauthenticatedCallableProbesDoNotSucceed: callableProbesReady,
    });
  }
  if (["events", "fleet", "final"].includes(phase)) {
    checks.requiredCloudRunInvokerBindingsReady = runBindingsReady;
  }
  if (["fleet", "final"].includes(phase)) {
    Object.assign(checks, {
      completeFleetActive:
        sameValues(actualNames, policyNames) &&
        sameValues(exactBindingNames.sort(), policyNames),
      schedulerControlPlaneReady: schedulerReady,
      temporaryProjectRunInvokerRemoved: projectRunInvokerRemoved,
    });
  }
  if (phase === "final") {
    Object.assign(checks, {
      runtimeProjectRolesExact: exactRuntimeRoles,
      defaultComputeNoLongerRunsFunctions: defaultComputeFunctions.length === 0,
      defaultComputeEditorRemoved: !defaultComputeRoles.includes("roles/editor"),
      defaultComputeRolesReducedToBuildOnly:
        sameValues(defaultComputeRoles, ["roles/cloudbuild.builds.builder"]),
    });
    delete checks.defaultComputeProvisioningPostureValid;
  }

  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value !== true)
    .map(([name]) => name);
  const label = phase.toUpperCase();
  return {
    failedChecks,
    evidence: {
      schemaVersion: 1,
      evidenceType: "function-fleet-runtime-identity-campaign-readback",
      phase: label,
      projectId,
      region,
      source: {before: sourceBefore, after: sourceAfter},
      policy: {
        path: POLICY_PATH,
        policyId: policy.policyId,
        sha256: null,
      },
      outputs: {
        project: live.project,
        serviceAccounts: live.serviceAccounts,
        customRole: live.customRole,
        projectRoles: live.projectRoles,
        defaultCompute: live.defaultCompute,
        functions: live.functions.map(({uri, ...record}) => record),
        cloudRunBindings: live.cloudRunBindings,
        scheduler: live.scheduler,
        schedulerBacklog: live.backlog,
        callableProbes: live.callableProbes,
      },
      posture: {
        expectedFunctionCount: policyNames.length,
        deployedFunctionCount: actualNames.length,
        requiredFunctionNames: requiredNames,
        exactBindingNames: exactBindingNames.sort(),
        defaultComputeFunctionNames: defaultComputeFunctions,
        broadRuntimeProjectGrants: broadRuntimeGrants,
      },
      checks,
      failedChecks,
      decision: failedChecks.length === 0
        ? `PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_${label}`
        : `HOLD_FUNCTION_FLEET_RUNTIME_IDENTITY_${label}`,
      mutationBoundary: {
        controlPlaneMutationPerformed: false,
        firestoreAggregationIsReadOnly: true,
        unauthenticatedCallableProbesPerformed: probeCallables,
        authenticatedBusinessOperationAttempted: false,
        serviceAccountsMutated: false,
        iamMutated: false,
        functionsDeployed: false,
        schedulerInvoked: false,
        firestoreDocumentsWritten: false,
        rulesOrIndexesDeployed: false,
        appCheckMutated: false,
        usersOrBusinessRecordsMutated: false,
      },
      privacyBoundary: {
        firestoreDocumentIdsRetained: false,
        businessPayloadsRetained: false,
        userIdentityRetained: false,
        callableResponseBodiesRetained: false,
      },
    },
  };
}

async function collect(options) {
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("Evidence output must be outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail(`Output already exists: ${options.outputPath}`);
  }
  const policyFile = path.join(options.repositoryRoot, POLICY_PATH);
  const policy = readJson(policyFile);
  const sourceBefore = collectSourceBinding(options.repositoryRoot);
  const live = await collectLiveState(options, policy);
  const sourceAfter = collectSourceBinding(options.repositoryRoot);
  const result = adjudicateReadback({
    phase: options.phase,
    projectId: options.projectId,
    region: options.region,
    policy,
    sourceBefore,
    sourceAfter,
    discoveredSourceExports: discoverFunctionExports(options.repositoryRoot),
    live,
    probeCallables: options.probeCallables,
  });
  result.evidence.policy.sha256 = sha256(fs.readFileSync(policyFile));
  const receipt = sealReceipt({
    ...result.evidence,
    capturedAtUtc: new Date().toISOString(),
  });
  fs.mkdirSync(path.dirname(options.outputPath), {recursive: true});
  fs.writeFileSync(options.outputPath, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  process.stdout.write(`${JSON.stringify({
    decision: receipt.decision,
    outputPath: options.outputPath,
    receiptSha256: receipt.receiptSha256,
    failedChecks: receipt.failedChecks,
  })}\n`);
  if (result.failedChecks.length > 0) process.exitCode = 1;
  return receipt;
}

async function main(argv) {
  if (argv.includes("--verify-receipt")) {
    const receiptIndex = argv.indexOf("--verify-receipt");
    const labelIndex = argv.indexOf("--label");
    if (receiptIndex < 0 || labelIndex < 0) fail("Receipt verification requires a label.");
    const receipt = readJson(path.resolve(argv[receiptIndex + 1]));
    verifyReceiptSeal(receipt, argv[labelIndex + 1]);
    process.stdout.write(`${JSON.stringify({
      verified: true,
      decision: receipt.decision,
      receiptSha256: receipt.receiptSha256,
    })}\n`);
    return receipt;
  }
  return collect(parseArgs(argv));
}

module.exports = {
  CALLABLE_CLASSES,
  EVENT_CLASSES,
  PHASES,
  POLICY_PATH,
  PRODUCTION_PROJECT_ID,
  PRODUCTION_REGION,
  accountEmailMap,
  adjudicateReadback,
  expectedProjectRoles,
  normalizeFunctions,
  parseArgs,
  phaseRequiredNames,
  projectRolesByIdentity,
};

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`FUNCTION_FLEET_RUNTIME_IDENTITY_READBACK_FAILED: ${error.message}\n`);
    process.exitCode = 1;
  });
}
