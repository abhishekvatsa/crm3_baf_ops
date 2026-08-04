"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {
  canonicalJson,
  sealReceipt,
} = require("./collectProductionGlobalPullBackend.js");
const {
  collectSourceBinding,
  isPathInside,
  sha256,
} = require("./collectFirestoreRulesIndexesReadback.js");

const PRODUCTION_PROJECT_ID = "crm3-baf-ops-b8638";
const PRODUCTION_REGION = "asia-south1";
const POLICY_PATH = "release/lr03-lr06-functions-live-readback-policy.json";
const TEMP_PREFIX = "crm3-lr03-lr06-";

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const options = {
    observe: false,
    gcloudCommand: "gcloud",
    tarCommand: "tar",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--observe") {
      options.observe = true;
      continue;
    }
    const fields = {
      "--repository-root": "repositoryRoot",
      "--project-id": "projectId",
      "--region": "region",
      "--output": "outputPath",
      "--gcloud": "gcloudCommand",
      "--tar": "tarCommand",
    };
    const field = fields[argument];
    if (field == null) fail(`Unsupported argument: ${argument}`);
    const value = argv[index + 1];
    if (value == null || value.startsWith("--")) {
      fail(`${argument} requires a value.`);
    }
    options[field] = value;
    index += 1;
  }
  for (const field of ["repositoryRoot", "projectId", "region", "outputPath"]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.outputPath = path.resolve(options.outputPath);
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    fail(`Only the exact production project ${PRODUCTION_PROJECT_ID} is supported.`);
  }
  if (options.region !== PRODUCTION_REGION) {
    fail(`Only the exact production region ${PRODUCTION_REGION} is supported.`);
  }
  return options;
}

function resolveCommand(command, args, platform = process.platform) {
  const platformPath = platform === "win32" ? path.win32 : path;
  if (
    platform !== "win32" ||
    platformPath.basename(command).toLowerCase() !== "gcloud.cmd"
  ) {
    return {command, args, environment: {}};
  }
  const sdkRoot = platformPath.resolve(platformPath.dirname(command), "..");
  return {
    command: platformPath.join(
      sdkRoot,
      "platform",
      "bundledpython",
      "python.exe",
    ),
    args: ["-S", platformPath.join(sdkRoot, "lib", "gcloud.py"), ...args],
    environment: {
      CLOUDSDK_ROOT_DIR: sdkRoot,
      PYTHONHOME: "",
      PATH:
        platformPath.join(sdkRoot, "bin", "sdk") +
        ";" +
        (process.env.PATH ?? ""),
    },
  };
}

function runText(command, args, options = {}) {
  const resolved = resolveCommand(command, args);
  const output = childProcess.execFileSync(resolved.command, resolved.args, {
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
  });
  return options.trim === false ? output : output.trim();
}

function gcloudJson(command, args, repositoryRoot) {
  const raw = runText(command, [...args, "--format=json"], {
    cwd: repositoryRoot,
  });
  try {
    return JSON.parse(raw);
  } catch (error) {
    fail(`gcloud returned malformed JSON: ${error.message}`);
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sortedUnique(values) {
  return [...new Set(values)].sort((left, right) => left.localeCompare(right));
}

function discoverExportNames(sourceText, typescript) {
  const sourceFile = typescript.createSourceFile(
    "index.ts",
    sourceText,
    typescript.ScriptTarget.Latest,
    true,
    typescript.ScriptKind.TS,
  );
  const exports = [];
  const isExported = (node) => {
    const modifiers = typescript.canHaveModifiers(node)
      ? (typescript.getModifiers(node) ?? [])
      : [];
    return modifiers.some(
      (modifier) => modifier.kind === typescript.SyntaxKind.ExportKeyword,
    );
  };
  for (const statement of sourceFile.statements) {
    if (typescript.isVariableStatement(statement) && isExported(statement)) {
      for (const declaration of statement.declarationList.declarations) {
        if (!typescript.isIdentifier(declaration.name)) {
          fail("Functions entrypoint contains an unsupported exported binding pattern.");
        }
        exports.push(declaration.name.text);
      }
      continue;
    }
    if (typescript.isExportDeclaration(statement)) {
      if (
        statement.exportClause == null ||
        !typescript.isNamedExports(statement.exportClause)
      ) {
        fail("Functions entrypoint contains an unsupported wildcard export.");
      }
      for (const element of statement.exportClause.elements) {
        exports.push(element.name.text);
      }
      continue;
    }
    if (
      (typescript.isFunctionDeclaration(statement) ||
        typescript.isClassDeclaration(statement)) &&
      isExported(statement) &&
      statement.name != null
    ) {
      exports.push(statement.name.text);
    }
  }
  const discovered = sortedUnique(exports);
  if (discovered.length !== exports.length) {
    fail("Functions entrypoint contains duplicate exported names.");
  }
  return discovered;
}

function discoverFunctionExports(repositoryRoot) {
  const typescript = require(
    path.join(
      repositoryRoot,
      "functions",
      "node_modules",
      "typescript",
      "lib",
      "typescript.js",
    ),
  );
  return discoverExportNames(
    fs.readFileSync(
      path.join(repositoryRoot, "functions", "src", "index.ts"),
      "utf8",
    ),
    typescript,
  );
}

function packageNameFromPath(packagePath, packageRecord) {
  if (typeof packageRecord?.name === "string" && packageRecord.name.length > 0) {
    return packageRecord.name;
  }
  const marker = "node_modules/";
  const markerIndex = packagePath.lastIndexOf(marker);
  if (markerIndex < 0) return null;
  return packagePath.slice(markerIndex + marker.length);
}

function dependencyInventory(lockfile) {
  const entries = [];
  if (lockfile?.packages != null && typeof lockfile.packages === "object") {
    for (const [packagePath, packageRecord] of Object.entries(lockfile.packages)) {
      if (packagePath === "" || packageRecord == null) continue;
      const name = packageNameFromPath(packagePath, packageRecord);
      const version = packageRecord.version;
      if (name == null || typeof version !== "string") continue;
      entries.push({path: packagePath, name, version});
    }
  } else {
    const visit = (dependencies, parentPath) => {
      if (dependencies == null || typeof dependencies !== "object") return;
      for (const [name, record] of Object.entries(dependencies)) {
        if (record == null || typeof record !== "object") continue;
        const packagePath = `${parentPath}node_modules/${name}`;
        if (typeof record.version === "string") {
          entries.push({path: packagePath, name, version: record.version});
        }
        visit(record.dependencies, `${packagePath}/`);
      }
    };
    visit(lockfile?.dependencies, "");
  }
  return entries.sort((left, right) => {
    const byPath = left.path.localeCompare(right.path);
    return byPath !== 0 ? byPath : left.version.localeCompare(right.version);
  });
}

function summarizePackageState({packageJsonRaw, packageLockRaw, trackedPackages}) {
  const packageJson = JSON.parse(packageJsonRaw);
  const packageLock = JSON.parse(packageLockRaw);
  const inventory = dependencyInventory(packageLock);
  const selectedVersions = {};
  for (const packageName of trackedPackages) {
    selectedVersions[packageName] = sortedUnique(
      inventory
        .filter((entry) => entry.name === packageName)
        .map((entry) => entry.version),
    );
  }
  const declarations = [];
  for (const field of ["dependencies", "devDependencies", "optionalDependencies"]) {
    const values = packageJson[field];
    if (values == null || typeof values !== "object") continue;
    for (const [name, version] of Object.entries(values)) {
      declarations.push({field, name, version});
    }
  }
  declarations.sort((left, right) => {
    const byField = left.field.localeCompare(right.field);
    return byField !== 0 ? byField : left.name.localeCompare(right.name);
  });
  return {
    packageName: typeof packageJson.name === "string" ? packageJson.name : null,
    packageVersion:
      typeof packageJson.version === "string" ? packageJson.version : null,
    nodeEngine:
      typeof packageJson.engines?.node === "string"
        ? packageJson.engines.node
        : null,
    lockfileVersion: packageLock.lockfileVersion ?? null,
    packageManifestSha256: sha256(packageJsonRaw),
    packageLockSha256: sha256(packageLockRaw),
    directDeclarationCount: declarations.length,
    directDeclarationSha256: sha256(canonicalJson(declarations)),
    dependencyPathCount: inventory.length,
    uniqueDependencyNameCount: new Set(inventory.map((entry) => entry.name)).size,
    dependencyInventorySha256: sha256(canonicalJson(inventory)),
    selectedVersions,
  };
}

function extractArchiveJson(tarCommand, archivePath, memberName) {
  const raw = runText(tarCommand, ["-xOf", archivePath, memberName], {
    trim: false,
  });
  try {
    JSON.parse(raw);
  } catch (error) {
    fail(`${memberName} in ${path.basename(archivePath)} is invalid: ${error.message}`);
  }
  return raw;
}

function normalizeFunctionDescriptor(record, projectId, region) {
  const prefix = `projects/${projectId}/locations/${region}/functions/`;
  if (typeof record?.name !== "string" || !record.name.startsWith(prefix)) {
    fail("Deployed Function name is outside the exact project and region.");
  }
  const functionName = record.name.slice(prefix.length);
  if (!/^[A-Za-z][A-Za-z0-9_-]{0,62}$/.test(functionName)) {
    fail(`Deployed Function name is malformed: ${functionName}`);
  }
  const source = record.buildConfig?.sourceProvenance?.resolvedStorageSource;
  if (
    source == null ||
    typeof source.bucket !== "string" ||
    typeof source.object !== "string" ||
    !/^\d+$/.test(String(source.generation ?? ""))
  ) {
    fail(`Function ${functionName} lacks generation-pinned source provenance.`);
  }
  const serviceAccountEmail =
    record.serviceConfig?.serviceAccountEmail ??
    String(record.buildConfig?.serviceAccount ?? "").split("/").at(-1);
  if (
    typeof serviceAccountEmail !== "string" ||
    !serviceAccountEmail.endsWith(".gserviceaccount.com")
  ) {
    fail(`Function ${functionName} lacks a canonical runtime identity.`);
  }
  return {
    name: functionName,
    resourceName: record.name,
    state: record.state ?? null,
    environment: record.environment ?? null,
    runtime: record.buildConfig?.runtime ?? null,
    entryPoint: record.buildConfig?.entryPoint ?? null,
    updateTime: record.updateTime ?? null,
    build: record.buildConfig?.build ?? null,
    firebaseFunctionsHash: record.labels?.["firebase-functions-hash"] ?? null,
    serviceAccountEmail,
    source: {
      bucket: source.bucket,
      object: source.object,
      generation: String(source.generation),
    },
  };
}

function safeRemoveTempDirectory(tempRoot) {
  const resolvedBase = path.resolve(os.tmpdir());
  const resolvedTarget = path.resolve(tempRoot);
  const relative = path.relative(resolvedBase, resolvedTarget);
  if (
    relative.startsWith("..") ||
    path.isAbsolute(relative) ||
    !path.basename(resolvedTarget).startsWith(TEMP_PREFIX)
  ) {
    fail(`Refusing to remove unexpected temporary path: ${resolvedTarget}`);
  }
  fs.rmSync(resolvedTarget, {recursive: true, force: true});
}

function downloadArchiveSummary({
  descriptor,
  index,
  options,
  tempRoot,
  trackedPackages,
}) {
  const archivePath = path.join(
    tempRoot,
    `${String(index).padStart(3, "0")}-${descriptor.name}.zip`,
  );
  const sourceUri = `gs://${descriptor.source.bucket}/${descriptor.source.object}`;
  runText(
    options.gcloudCommand,
    [
      "storage",
      "cp",
      sourceUri,
      archivePath,
      `--if-generation-match=${descriptor.source.generation}`,
      "--quiet",
    ],
    {cwd: options.repositoryRoot},
  );
  const archiveBytes = fs.readFileSync(archivePath);
  const packageJsonRaw = extractArchiveJson(
    options.tarCommand,
    archivePath,
    "package.json",
  );
  const packageLockRaw = extractArchiveJson(
    options.tarCommand,
    archivePath,
    "package-lock.json",
  );
  return {
    ...descriptor,
    sourceArchive: {
      sha256: sha256(archiveBytes),
      bytes: archiveBytes.length,
      generationPinnedDownload: true,
    },
    dependencies: summarizePackageState({
      packageJsonRaw,
      packageLockRaw,
      trackedPackages,
    }),
  };
}

function summarizeIam({iamPolicy, functions, projectNumber}) {
  const runtimeIdentities = sortedUnique(
    functions.map((record) => record.serviceAccountEmail),
  );
  const runtimeIdentitySet = new Set(runtimeIdentities);
  const grantsByIdentity = Object.fromEntries(
    runtimeIdentities.map((identity) => [identity, []]),
  );
  for (const binding of iamPolicy?.bindings ?? []) {
    if (typeof binding?.role !== "string" || !Array.isArray(binding.members)) {
      continue;
    }
    for (const member of binding.members) {
      const prefix = "serviceAccount:";
      if (typeof member !== "string" || !member.startsWith(prefix)) continue;
      const identity = member.slice(prefix.length);
      if (!runtimeIdentitySet.has(identity)) continue;
      grantsByIdentity[identity].push({
        role: binding.role,
        conditional: binding.condition != null,
      });
    }
  }
  const identities = runtimeIdentities.map((email) => ({
    email,
    grants: grantsByIdentity[email].sort((left, right) => {
      const byRole = left.role.localeCompare(right.role);
      return byRole !== 0
        ? byRole
        : Number(left.conditional) - Number(right.conditional);
    }),
  }));
  const defaultComputeServiceAccount =
    `${projectNumber}-compute@developer.gserviceaccount.com`;
  const defaultCompute = identities.find(
    (identity) => identity.email === defaultComputeServiceAccount,
  );
  return {
    policyVersion: iamPolicy?.version ?? null,
    policyEtagSha256:
      typeof iamPolicy?.etag === "string" ? sha256(iamPolicy.etag) : null,
    runtimeIdentityCount: identities.length,
    identities,
    defaultComputeServiceAccount,
    defaultComputeHasUnconditionalEditor:
      defaultCompute?.grants.some(
        (grant) => grant.role === "roles/editor" && grant.conditional === false,
      ) ?? false,
  };
}

function dependencyParity(functions, currentDependencies) {
  return functions.map((record) => ({
    name: record.name,
    inventoryMatchesCurrent:
      record.dependencies.dependencyInventorySha256 ===
      currentDependencies.dependencyInventorySha256,
    selectedVersionsMatchCurrent:
      canonicalJson(record.dependencies.selectedVersions) ===
      canonicalJson(currentDependencies.selectedVersions),
  }));
}

function adjudicateReadback({
  projectId,
  region,
  sourceBefore,
  sourceAfter,
  policy,
  project,
  iam,
  functions,
  currentDependencies,
  discoveredSourceExports,
  observe = false,
}) {
  const actualNames = functions.map((record) => record.name).sort();
  const expectedNames = [...discoveredSourceExports].sort();
  const policyNames = [...policy.sourceFunctionExports].sort();
  const actualSet = new Set(actualNames);
  const expectedSet = new Set(expectedNames);
  const runtimeBindingNames = Object.keys(
    policy.sourceDeclaredRuntimeBindings ?? {},
  ).sort();
  const missingFromLive = expectedNames.filter((name) => !actualSet.has(name));
  const unexpectedLive = actualNames.filter((name) => !expectedSet.has(name));
  const duplicateFunctionNames = actualNames.filter(
    (name, index) => index > 0 && name === actualNames[index - 1],
  );
  const runtimeBindings = Object.entries(
    policy.sourceDeclaredRuntimeBindings ?? {},
  ).map(([name, expectedServiceAccountEmail]) => {
    const deployed = functions.find((record) => record.name === name);
    return {
      name,
      expectedServiceAccountEmail,
      deployedServiceAccountEmail: deployed?.serviceAccountEmail ?? null,
      matches: deployed?.serviceAccountEmail === expectedServiceAccountEmail,
    };
  });
  const defaultComputeFunctionNames = functions
    .filter(
      (record) =>
        record.serviceAccountEmail === iam.defaultComputeServiceAccount,
    )
    .map((record) => record.name)
    .sort();
  const dependencyComparisons = dependencyParity(functions, currentDependencies);
  const dependencyDriftFunctionNames = dependencyComparisons
    .filter(
      (comparison) =>
        !comparison.inventoryMatchesCurrent ||
        !comparison.selectedVersionsMatchCurrent,
    )
    .map((comparison) => comparison.name);
  const broadRuntimeRoleGrants = iam.identities.flatMap((identity) =>
    identity.grants
      .filter(
        (grant) =>
          policy.forbiddenBroadProjectRoles.includes(grant.role) &&
          grant.conditional === false,
      )
      .map((grant) => ({identity: identity.email, role: grant.role})),
  );
  const postureHolds = [];
  if (missingFromLive.length > 0 || unexpectedLive.length > 0) {
    postureHolds.push("deployedFunctionFleetDiffersFromSource");
  }
  if (runtimeBindings.some((binding) => !binding.matches)) {
    postureHolds.push("sourceDeclaredRuntimeBindingNotDeployed");
  }
  if (defaultComputeFunctionNames.length > 0) {
    postureHolds.push("functionsStillUseDefaultComputeIdentity");
  }
  if (broadRuntimeRoleGrants.length > 0) {
    postureHolds.push("runtimeIdentityHasBroadProjectRole");
  }
  if (dependencyDriftFunctionNames.length > 0) {
    postureHolds.push("deployedDependencyInventoryDiffersFromCurrentSource");
  }
  const checks = {
    exactProjectAndRegion:
      projectId === PRODUCTION_PROJECT_ID && region === PRODUCTION_REGION,
    policyMatchesTarget:
      policy.productionProjectId === projectId &&
      policy.productionRegion === region &&
      canonicalJson(policy.gateIds) === canonicalJson(["LR-03", "LR-06"]),
    sourceExportInventoryMatchesPolicy:
      canonicalJson(expectedNames) === canonicalJson(policyNames),
    sourceRuntimeBindingInventoryMatchesPolicy:
      canonicalJson(expectedNames) === canonicalJson(runtimeBindingNames),
    sourceStable:
      sourceBefore.commit === sourceAfter.commit &&
      sourceBefore.tree === sourceAfter.tree,
    governedSourceClean:
      sourceBefore.governedWorktreeClean === true &&
      sourceAfter.governedWorktreeClean === true &&
      sourceBefore.materialChangeCount === 0 &&
      sourceAfter.materialChangeCount === 0,
    sourceBranchMain:
      sourceBefore.branch === "main" && sourceAfter.branch === "main",
    sourceCommitMatchesOriginMain:
      sourceBefore.commit === sourceBefore.originMain &&
      sourceAfter.commit === sourceAfter.originMain,
    projectNumberPresent: /^\d+$/.test(String(project.projectNumber ?? "")),
    iamPolicyMetadataPresent:
      iam.policyVersion != null &&
      /^[0-9A-F]{64}$/.test(iam.policyEtagSha256 ?? ""),
    deployedFunctionsPresent: functions.length > 0,
    deployedFunctionNamesUnique: duplicateFunctionNames.length === 0,
    deployedFunctionsActiveGen2:
      functions.length > 0 &&
      functions.every(
        (record) =>
          record.state === "ACTIVE" && record.environment === "GEN_2",
      ),
    deployedRuntimeIdentitiesPresent:
      functions.length > 0 &&
      functions.every(
        (record) =>
          typeof record.serviceAccountEmail === "string" &&
          record.serviceAccountEmail.endsWith(".gserviceaccount.com"),
      ),
    generationPinnedArchivesComplete:
      functions.length > 0 &&
      functions.every(
        (record) =>
          record.sourceArchive?.generationPinnedDownload === true &&
          /^[0-9A-F]{64}$/.test(record.sourceArchive.sha256) &&
          record.sourceArchive.bytes > 0,
      ),
    dependencySummariesComplete:
      functions.length > 0 &&
      functions.every(
        (record) =>
          /^[0-9A-F]{64}$/.test(
            record.dependencies?.dependencyInventorySha256 ?? "",
          ) && record.dependencies?.dependencyPathCount > 0,
      ),
    runtimeIamReducedToDeployedIdentities:
      iam.runtimeIdentityCount === iam.identities.length &&
      canonicalJson(iam.identities.map((identity) => identity.email).sort()) ===
        canonicalJson(
          sortedUnique(functions.map((record) => record.serviceAccountEmail)),
        ),
  };
  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value === false)
    .map(([name]) => name);
  const decision = observe
    ? "OBSERVE_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK"
    : failedChecks.length === 0
      ? "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK"
      : "HOLD_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK";
  return {
    failedChecks,
    evidence: {
      schemaVersion: 1,
      evidenceType: "functions-iam-dependencies-live-readback",
      mode: observe ? "OBSERVE" : "STRICT",
      projectId,
      region,
      gateIds: ["LR-03", "LR-06"],
      source: {before: sourceBefore, after: sourceAfter},
      commands: [
        {kind: "LOCAL_READ", command: "git status/rev-parse"},
        {kind: "CLI_READ", command: "gcloud projects describe"},
        {kind: "CLI_READ", command: "gcloud projects get-iam-policy"},
        {kind: "CLI_READ", command: "gcloud functions list --v2"},
        {
          kind: "CLI_READ",
          command: "gcloud storage cp --if-generation-match",
          repetition: "once per deployed Function source archive",
        },
        {
          kind: "LOCAL_READ",
          command: "tar -xOf package.json/package-lock.json",
        },
      ],
      outputs: {
        project: {
          projectNumber: String(project.projectNumber),
          lifecycleState: project.lifecycleState ?? null,
        },
        iam,
        discoveredSourceFunctionExports: expectedNames,
        policySourceFunctionExports: policyNames,
        currentSourceDependencies: currentDependencies,
        functions,
      },
      posture: {
        sourceFunctionCount: expectedNames.length,
        deployedFunctionCount: actualNames.length,
        missingFromLive,
        unexpectedLive,
        fleetMatchesSource:
          missingFromLive.length === 0 && unexpectedLive.length === 0,
        sourceDeclaredRuntimeBindings: runtimeBindings,
        defaultComputeFunctionNames,
        broadRuntimeRoleGrants,
        dependencyComparisons,
        dependencyDriftFunctionNames,
        advisoryAssessmentPerformed: false,
        holds: postureHolds,
        decision:
          postureHolds.length === 0
            ? "PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE"
            : "HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE",
      },
      checks,
      failedChecks,
      decision,
      closureScope: {
        liveReadbackGateEvidenceOnly: true,
        gateIds: ["LR-03", "LR-06"],
        s01Closed: false,
        d01Closed: false,
        deploymentAuthorized: false,
        iamRemediationAuthorized: false,
      },
      mutationBoundary: {...policy.mutationBoundary},
      privacyBoundary: {...policy.privacyBoundary},
    },
  };
}

function collectLiveState(options, policy) {
  const discoveredSourceExports = discoverFunctionExports(options.repositoryRoot);
  const project = gcloudJson(
    options.gcloudCommand,
    ["projects", "describe", options.projectId],
    options.repositoryRoot,
  );
  const iamPolicy = gcloudJson(
    options.gcloudCommand,
    ["projects", "get-iam-policy", options.projectId],
    options.repositoryRoot,
  );
  const rawFunctions = gcloudJson(
    options.gcloudCommand,
    [
      "functions",
      "list",
      "--v2",
      `--regions=${options.region}`,
      `--project=${options.projectId}`,
    ],
    options.repositoryRoot,
  );
  if (!Array.isArray(rawFunctions)) fail("gcloud Functions list is not an array.");
  const descriptors = rawFunctions
    .map((record) =>
      normalizeFunctionDescriptor(record, options.projectId, options.region),
    )
    .sort((left, right) => left.name.localeCompare(right.name));
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), TEMP_PREFIX));
  let functions;
  try {
    functions = descriptors.map((descriptor, index) =>
      downloadArchiveSummary({
        descriptor,
        index,
        options,
        tempRoot,
        trackedPackages: policy.trackedRuntimePackages,
      }),
    );
  } finally {
    safeRemoveTempDirectory(tempRoot);
  }
  const currentDependencies = summarizePackageState({
    packageJsonRaw: fs.readFileSync(
      path.join(options.repositoryRoot, "functions", "package.json"),
      "utf8",
    ),
    packageLockRaw: fs.readFileSync(
      path.join(options.repositoryRoot, "functions", "package-lock.json"),
      "utf8",
    ),
    trackedPackages: policy.trackedRuntimePackages,
  });
  const iam = summarizeIam({
    iamPolicy,
    functions,
    projectNumber: String(project.projectNumber ?? ""),
  });
  return {
    project,
    iam,
    functions,
    currentDependencies,
    discoveredSourceExports,
  };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("The append-only readback output must be outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail(`Output already exists: ${options.outputPath}`);
  }
  const policy = readJson(path.join(options.repositoryRoot, POLICY_PATH));
  const sourceBefore = collectSourceBinding(options.repositoryRoot);
  const live = collectLiveState(options, policy);
  const sourceAfter = collectSourceBinding(options.repositoryRoot);
  const result = adjudicateReadback({
    projectId: options.projectId,
    region: options.region,
    sourceBefore,
    sourceAfter,
    policy,
    ...live,
    observe: options.observe,
  });
  const receipt = sealReceipt({
    ...result.evidence,
    capturedAtUtc: new Date().toISOString(),
  });
  fs.mkdirSync(path.dirname(options.outputPath), {recursive: true});
  fs.writeFileSync(options.outputPath, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  process.stdout.write(
    `${JSON.stringify({
      decision: receipt.decision,
      postureDecision: receipt.posture.decision,
      outputPath: options.outputPath,
      receiptSha256: receipt.receiptSha256,
      failedChecks: receipt.failedChecks,
      postureHolds: receipt.posture.holds,
    })}\n`,
  );
  if (!options.observe && result.failedChecks.length > 0) process.exitCode = 1;
}

module.exports = {
  POLICY_PATH,
  PRODUCTION_PROJECT_ID,
  PRODUCTION_REGION,
  adjudicateReadback,
  dependencyInventory,
  discoverExportNames,
  discoverFunctionExports,
  normalizeFunctionDescriptor,
  parseArgs,
  resolveCommand,
  safeRemoveTempDirectory,
  summarizeIam,
  summarizePackageState,
};

if (require.main === module) {
  try {
    main();
  } catch (error) {
    process.stderr.write(
      `FUNCTIONS_IAM_DEPENDENCY_READBACK_FAILED: ${error.message}\n`,
    );
    process.exitCode = 1;
  }
}
