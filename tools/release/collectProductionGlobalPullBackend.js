"use strict";

const crypto = require("crypto");
const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const PRODUCTION_PROJECT_ID = "crm3-baf-ops-b8638";
const REGION = "asia-south1";
const CONTRACT_PATH = "runtime_contracts/global_pull_v1";
const PROTOCOL_VERSION = 1;
const PROTOCOL_FINGERPRINT =
  "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321";
const WRITER_VERSION = "global-pull-server-stamp-v1";
const SERVER_STAMP_FIELD = "_globalPullServerUpdatedAt";
const PROMOTION_RELATIVE_PATH =
  "release/approvals/build-8-f4-production-backend-activation-promotion.json";
const RESTORE_RECEIPT_RELATIVE_PATH =
  "release/evidence/production-prelive-restore-pack-seal.json";
const REQUIRED_DEPLOYMENT_PATHS = Object.freeze([
  "firebase.json",
  "firestore.rules",
  "firestore.indexes.json",
  "functions/src/index.ts",
  "functions/src/globalPullServerClock.ts",
  "functions/src/globalPullSecurityConfig.ts",
  "functions/src/callableSecurityConfig.ts",
  "functions/tools/global-pull-server-clock.mjs",
  "functions/package.json",
  "functions/package-lock.json",
  "governance/global-pull-protocol-v1.json",
  "tooling/firebase-cli/package.json",
  "tooling/firebase-cli/package-lock.json",
]);
const COLLECTIONS = Object.freeze([
  "abnormality_types",
  "charge_abnormalities",
  "directives",
  "job_diary_entries",
  "job_executions",
  "job_modules",
  "job_templates",
  "knowledge_base",
  "maintenance_records",
  "template_packages",
  "template_publish_audits",
  "template_versions",
]);
const REQUIRED_FUNCTIONS = Object.freeze({
  beginGlobalPullRun: {
    serviceAccount:
      "crm3-global-pull-reader@crm3-baf-ops-b8638.iam.gserviceaccount.com",
    roles: ["roles/datastore.viewer", "roles/logging.logWriter"],
    kind: "callable",
    timeoutSeconds: 15,
    availableMemoryMb: 256,
    concurrency: 80,
  },
  stampGlobalPullServerClock: {
    serviceAccount:
      "crm3-global-pull-writer@crm3-baf-ops-b8638.iam.gserviceaccount.com",
    roles: [
      "roles/datastore.user",
      "roles/eventarc.eventReceiver",
      "roles/logging.logWriter",
      "roles/run.invoker",
    ],
    kind: "firestore-trigger",
    timeoutSeconds: 60,
    availableMemoryMb: 256,
    concurrency: 80,
  },
});
const FORBIDDEN_RUNTIME_ROLES = new Set([
  "roles/owner",
  "roles/editor",
  "roles/iam.securityAdmin",
  "roles/iam.serviceAccountAdmin",
  "roles/iam.serviceAccountTokenCreator",
]);

function fail(message) {
  throw new Error(message);
}

function readArg(argv, name, {required = true} = {}) {
  const matches = argv
    .map((value, index) => (value === name ? index : -1))
    .filter((index) => index >= 0);
  if (matches.length > 1) fail(`Duplicate argument: ${name}`);
  if (matches.length === 0) {
    if (required) fail(`Missing required argument: ${name}`);
    return null;
  }
  const value = argv[matches[0] + 1];
  if (value == null || value.startsWith("--")) {
    fail(`Missing value for ${name}`);
  }
  return value;
}

function parseArgs(argv) {
  const known = new Set([
    "--mode",
    "--repository-root",
    "--project-id",
    "--promotion",
    "--inventory",
    "--backfill-receipt",
    "--activation-receipt",
    "--source-commit",
    "--output",
  ]);
  for (let index = 0; index < argv.length; index += 2) {
    if (!known.has(argv[index])) fail(`Unknown argument: ${argv[index]}`);
  }
  const mode = readArg(argv, "--mode");
  if (!new Set(["preflight", "readiness"]).has(mode)) {
    fail("--mode must be preflight or readiness.");
  }
  const options = {
    mode,
    repositoryRoot: path.resolve(readArg(argv, "--repository-root")),
    projectId: readArg(argv, "--project-id"),
    promotionPath: path.resolve(readArg(argv, "--promotion")),
    inventoryPath: path.resolve(readArg(argv, "--inventory")),
    backfillReceiptPath: readArg(argv, "--backfill-receipt", {
      required: mode === "readiness",
    }),
    activationReceiptPath: readArg(argv, "--activation-receipt", {
      required: mode === "readiness",
    }),
    sourceCommit: readArg(argv, "--source-commit", {
      required: mode === "readiness",
    }),
    outputPath: path.resolve(readArg(argv, "--output")),
  };
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    fail(`Only the exact production project ${PRODUCTION_PROJECT_ID} is supported.`);
  }
  if (
    options.sourceCommit != null &&
    !/^[0-9a-f]{40}$/.test(options.sourceCommit)
  ) {
    fail("--source-commit must be exactly 40 lowercase hexadecimal characters.");
  }
  return options;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value != null && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256Buffer(value) {
  return crypto.createHash("sha256").update(value).digest("hex").toUpperCase();
}

function sha256Text(value) {
  return sha256Buffer(Buffer.from(value, "utf8"));
}

function fileSha256(filePath) {
  return sha256Buffer(fs.readFileSync(filePath));
}

function sealReceipt(value) {
  return {
    ...value,
    receiptSha256: crypto
      .createHash("sha256")
      .update(canonicalJson(value), "utf8")
      .digest("hex"),
  };
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function verifyReceiptSeal(receipt, label) {
  if (
    receipt == null ||
    typeof receipt !== "object" ||
    Array.isArray(receipt) ||
    !/^[0-9a-f]{64}$/.test(receipt.receiptSha256 ?? "")
  ) {
    fail(`${label} has no valid canonical SHA-256 seal.`);
  }
  const {receiptSha256, ...body} = receipt;
  const calculated = crypto
    .createHash("sha256")
    .update(canonicalJson(body), "utf8")
    .digest("hex");
  if (calculated !== receiptSha256) {
    fail(`${label} canonical SHA-256 seal does not match.`);
  }
}

function isPathInside(parentPath, candidatePath) {
  const relative = path.relative(path.resolve(parentPath), path.resolve(candidatePath));
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function pathsEqual(left, right) {
  const normalizedLeft = path.resolve(left);
  const normalizedRight = path.resolve(right);
  return process.platform === "win32"
    ? normalizedLeft.toLowerCase() === normalizedRight.toLowerCase()
    : normalizedLeft === normalizedRight;
}

function runText(command, args, options = {}) {
  return childProcess
    .execFileSync(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    })
    .trim();
}

function git(repositoryRoot, args) {
  return runText("git", ["-C", repositoryRoot, ...args]);
}

function firebaseJson(repositoryRoot, args) {
  const firebaseBin = path.join(
    repositoryRoot,
    "tooling",
    "firebase-cli",
    "node_modules",
    "firebase-tools",
    "lib",
    "bin",
    "firebase.js",
  );
  const parsed = JSON.parse(
    runText(process.execPath, [firebaseBin, ...args, "--json"], {
      cwd: repositoryRoot,
    }),
  );
  if (parsed.status !== "success") {
    fail(`Firebase CLI readback failed: ${JSON.stringify(parsed.error ?? parsed)}`);
  }
  return parsed.result;
}

function normalizeIndex(index) {
  const resourceNameMatch =
    typeof index.name === "string"
      ? index.name.match(/\/collectionGroups\/([^/]+)\/indexes\/[^/]+$/)
      : null;
  const collectionGroup = index.collectionGroup ?? resourceNameMatch?.[1];
  if (typeof collectionGroup !== "string" || collectionGroup.length === 0) {
    fail("A Firestore index is missing its collection-group identity.");
  }
  return {
    collectionGroup: decodeURIComponent(collectionGroup),
    queryScope: index.queryScope ?? "COLLECTION",
    fields: (index.fields ?? [])
      .filter((field) => field.fieldPath !== "__name__")
      .map((field) => ({
        fieldPath: field.fieldPath,
        ...(field.order == null ? {} : {order: field.order}),
        ...(field.arrayConfig == null ? {} : {arrayConfig: field.arrayConfig}),
        ...(field.vectorConfig == null ? {} : {vectorConfig: field.vectorConfig}),
      })),
  };
}

function normalizedIndexSet(indexes) {
  return indexes.map(normalizeIndex).map(canonicalJson).sort();
}

function indexSetsEqual(left, right) {
  return canonicalJson(normalizedIndexSet(left)) === canonicalJson(normalizedIndexSet(right));
}

function nonNegativeInteger(value) {
  return Number.isInteger(value) && value >= 0;
}

function inventoryShapeValid(value) {
  if (
    value == null ||
    !nonNegativeInteger(value.total) ||
    !nonNegativeInteger(value.stamped) ||
    !nonNegativeInteger(value.missing) ||
    !nonNegativeInteger(value.malformed) ||
    !Array.isArray(value.collections) ||
    value.collections.length !== COLLECTIONS.length
  ) {
    return false;
  }
  const collectionIds = value.collections.map((item) => item.collectionId);
  if (canonicalJson(collectionIds) !== canonicalJson(COLLECTIONS)) return false;
  for (const item of value.collections) {
    if (
      !nonNegativeInteger(item.total) ||
      !nonNegativeInteger(item.stamped) ||
      !nonNegativeInteger(item.missing) ||
      !nonNegativeInteger(item.malformed) ||
      item.stamped + item.missing + item.malformed !== item.total
    ) {
      return false;
    }
  }
  return (
    value.collections.reduce((sum, item) => sum + item.total, 0) ===
      value.total &&
    value.collections.reduce((sum, item) => sum + item.stamped, 0) ===
      value.stamped &&
    value.collections.reduce((sum, item) => sum + item.missing, 0) ===
      value.missing &&
    value.collections.reduce((sum, item) => sum + item.malformed, 0) ===
      value.malformed &&
    value.stamped + value.missing + value.malformed === value.total
  );
}

function backfillUpdateCountsValid(receipt) {
  const updates = receipt?.updatedByCollection;
  if (updates == null || typeof updates !== "object" || Array.isArray(updates)) {
    return false;
  }
  if (!sameStrings(Object.keys(updates), COLLECTIONS)) return false;
  const values = COLLECTIONS.map((collectionId) => updates[collectionId]);
  return (
    values.every(nonNegativeInteger) &&
    nonNegativeInteger(receipt.updated) &&
    values.reduce((sum, value) => sum + value, 0) === receipt.updated
  );
}

function trackedPathManifest(repositoryRoot, pathspec) {
  const relativePaths = git(repositoryRoot, ["ls-files", "--", pathspec])
    .split(/\r?\n/)
    .filter(Boolean)
    .map((relativePath) => relativePath.replaceAll("\\", "/"))
    .sort();
  const entries = relativePaths.map((relativePath) => ({
    path: relativePath,
    sha256: fileSha256(path.join(repositoryRoot, relativePath)),
  }));
  return {
    fileCount: entries.length,
    sha256: sha256Text(canonicalJson(entries)),
  };
}

function httpStatus(error) {
  return (
    error?.status ??
    error?.statusCode ??
    error?.context?.response?.statusCode ??
    error?.context?.response?.status ??
    error?.response?.status
  );
}

function firestoreString(field) {
  return typeof field?.stringValue === "string" ? field.stringValue : null;
}

function firestoreInteger(field) {
  const value = field?.integerValue;
  if (typeof value !== "string" || !/^-?[0-9]+$/.test(value)) return null;
  return Number(value);
}

function firestoreStringArray(field) {
  const values = field?.arrayValue?.values;
  if (!Array.isArray(values)) return null;
  const result = values.map(firestoreString);
  return result.every((value) => value != null) ? result : null;
}

function decodeContract(document) {
  if (document == null) return null;
  const fields = document.fields ?? {};
  return {
    state: firestoreString(fields.state),
    protocolVersion: firestoreInteger(fields.protocolVersion),
    protocolFingerprint: firestoreString(fields.protocolFingerprint),
    writerVersion: firestoreString(fields.writerVersion),
    serverStampField: firestoreString(fields.serverStampField),
    collections: firestoreStringArray(fields.collections),
    activatedAt:
      typeof fields.activatedAt?.timestampValue === "string"
        ? fields.activatedAt.timestampValue
        : null,
    sourceCommit: firestoreString(fields.sourceCommit),
    backfillReceiptSha256: firestoreString(fields.backfillReceiptSha256),
    fieldNames: Object.keys(fields).sort(),
  };
}

function rolesForMember(policy, member) {
  return (policy.bindings ?? [])
    .filter((binding) => (binding.members ?? []).includes(member))
    .map((binding) => binding.role)
    .filter((role) => typeof role === "string")
    .sort();
}

function sameStrings(left, right) {
  return canonicalJson([...left].sort()) === canonicalJson([...right].sort());
}

function protocolReceiptChecks(receipt, expectedType, projectId) {
  verifyReceiptSeal(receipt, expectedType);
  const checks = {
    receiptType: receipt.receiptType === expectedType,
    receiptVersion: receipt.receiptVersion === 1,
    projectId: receipt.projectId === projectId,
    protocolVersion: receipt.protocolVersion === PROTOCOL_VERSION,
    protocolFingerprint: receipt.protocolFingerprint === PROTOCOL_FINGERPRINT,
    writerVersion: receipt.writerVersion === WRITER_VERSION,
    serverStampField: receipt.serverStampField === SERVER_STAMP_FIELD,
    collections:
      canonicalJson(receipt.collections) === canonicalJson(COLLECTIONS),
    privacy:
      receipt.privacy?.documentIdsRetained === false &&
      receipt.privacy?.consoleContainsDocumentIds === false,
  };
  return {
    checks,
    valid: Object.values(checks).every(Boolean),
  };
}

function validatePromotion(repositoryRoot, promotionPath) {
  const expectedPromotionPath = path.join(
    repositoryRoot,
    PROMOTION_RELATIVE_PATH,
  );
  if (!pathsEqual(promotionPath, expectedPromotionPath)) {
    fail(`Only the merged promotion at ${PROMOTION_RELATIVE_PATH} is accepted.`);
  }
  const promotion = readJson(promotionPath);
  const restoreRelativePath = promotion.restoreAuthority?.sealReceiptPath ?? "";
  const restoreReceiptPath = path.join(
    repositoryRoot,
    restoreRelativePath,
  );
  const restorePathExact =
    restoreRelativePath === RESTORE_RECEIPT_RELATIVE_PATH &&
    isPathInside(repositoryRoot, restoreReceiptPath);
  const restoreReceipt = restorePathExact && fs.existsSync(restoreReceiptPath)
    ? readJson(restoreReceiptPath)
    : null;
  const functionsManifest = trackedPathManifest(repositoryRoot, "functions");
  const checks = {
    schemaVersion: promotion.schemaVersion === 1,
    approvalId:
      promotion.approvalId ===
      "CRM3-B8-F4-PRODUCTION-GLOBAL-PULL-ACTIVATION-001",
    approvalClass:
      promotion.approvalClass ===
      "CONTROLLED_PRODUCTION_GLOBAL_PULL_BACKEND_ACTIVATION",
    approvalAuthority:
      promotion.approvalAuthority?.mode === "MERGED_OWNER_SOURCE_APPROVAL" &&
      promotion.approvalAuthority?.repository === "abhishekvatsa/crm3_baf_ops" &&
      promotion.approvalAuthority?.humanApprovalReference ===
        "CODEX_TASK_BUILD8_BACKEND_AND_ADB_APPROVAL_20260803",
    target:
      promotion.target?.environment === "production" &&
      promotion.target?.projectId === PRODUCTION_PROJECT_ID &&
      promotion.target?.projectNumber === "894346496105" &&
      promotion.target?.region === REGION &&
      promotion.target?.firestoreDatabase === "(default)" &&
      promotion.target?.applicationId === "in.co.sail.bsl.crm3.bafops",
    approved: promotion.approved === true,
    baseline:
      promotion.approvalAuthority?.baselineCommit ===
        "731a02980d38e4e3a8f61ff2bca74a1e85771478" &&
      promotion.approvalAuthority?.baselineTree ===
        "8805af93cf0d99d5527a835dcf43fa16d3bfa3f0",
    protocol:
      promotion.sourceAuthority?.protocolVersion === PROTOCOL_VERSION &&
      promotion.sourceAuthority?.protocolFingerprint === PROTOCOL_FINGERPRINT,
    functionsManifest:
      promotion.sourceAuthority?.functionsTrackedFileCount ===
        functionsManifest.fileCount &&
      promotion.sourceAuthority?.functionsTrackedManifestSha256 ===
        functionsManifest.sha256,
    rulesOnly: promotion.authorizedMutations?.firestoreRules === "EXACT_SOURCE_ONLY",
    indexesReadOnly: promotion.authorizedMutations?.firestoreIndexes === "READ_ONLY_PARITY",
    functionsExact:
      canonicalJson(promotion.authorizedMutations?.functions ?? []) ===
        canonicalJson(Object.keys(REQUIRED_FUNCTIONS)) &&
      promotion.authorizedMutations?.functionFleetOutsideNamedScope ===
        "PROHIBITED",
    appCheckDeferred: promotion.authorizedMutations?.appCheck === "PROHIBITED",
    iamMutationProhibited: promotion.authorizedMutations?.iam === "PROHIBITED",
    businessMutationProhibited:
      promotion.authorizedMutations?.businessFields === "PROHIBITED" &&
      promotion.authorizedMutations?.documentCreationDeletionOrLifecycleChange ===
        "PROHIBITED" &&
      promotion.authorizedMutations?.globalPullWatermarkBackfill ===
        "MISSING_FIELD_ONLY" &&
      promotion.authorizedMutations?.runtimeContract ===
        "ONE_CREATE_AT_runtime_contracts/global_pull_v1" &&
      promotion.authorizedMutations?.distribution === "PROHIBITED",
    migrationBoundary:
      promotion.migrationBoundary?.maximumObservedDocuments === 100 &&
      promotion.migrationBoundary?.maximumBackfillUpdates === 50 &&
      promotion.migrationBoundary?.malformedWatermarksAllowed === 0 &&
      promotion.migrationBoundary?.documentIdsMayBeRetained === false &&
      promotion.migrationBoundary?.serverTimestampField === SERVER_STAMP_FIELD &&
      promotion.migrationBoundary?.writePrecondition === "lastUpdateTime" &&
      promotion.migrationBoundary?.contractCreateIsImmutable === true,
    programmeBoundary:
      promotion.programmeBoundary?.stage2dF4ClosureAuthorized === false &&
      promotion.programmeBoundary?.p07ClosureAuthorized === false &&
      promotion.programmeBoundary?.pilotHandoutAuthorized === false &&
      promotion.programmeBoundary?.externalDistributionAuthorized === false,
    restoreReceipt:
      restorePathExact &&
      restoreReceipt != null &&
      fileSha256(restoreReceiptPath) ===
        promotion.restoreAuthority?.sealReceiptSha256 &&
      restoreReceipt.decision === promotion.restoreAuthority?.decision &&
      restoreReceipt.protectedFirestoreExport?.operationState === "SUCCESSFUL" &&
      restoreReceipt.privatePack?.privateCustodyCopyCount >= 2,
    runtimeIdentityPolicy:
      Object.entries(REQUIRED_FUNCTIONS).every(([name, expected]) => {
        const identity = promotion.requiredRuntimeIdentity?.[name];
        return (
          identity?.serviceAccount === expected.serviceAccount &&
          sameStrings(identity?.exactProjectRoles ?? [], expected.roles)
        );
      }) &&
      sameStrings(
        promotion.requiredRuntimeIdentity?.forbiddenRoles ?? [],
        [...FORBIDDEN_RUNTIME_ROLES],
      ),
  };
  const boundFiles = promotion.sourceAuthority?.deploymentFiles ?? [];
  const boundPaths = boundFiles.map((binding) => binding.path);
  const fileChecks = {};
  for (const binding of boundFiles) {
    const candidate = path.join(repositoryRoot, binding.path);
    fileChecks[binding.path] =
      isPathInside(repositoryRoot, candidate) &&
      fs.existsSync(candidate) &&
      fileSha256(candidate) === binding.sha256;
  }
  checks.deploymentFiles =
    sameStrings(boundPaths, REQUIRED_DEPLOYMENT_PATHS) &&
    new Set(boundPaths).size === REQUIRED_DEPLOYMENT_PATHS.length &&
    Object.values(fileChecks).every(Boolean);
  if (!Object.values(checks).every(Boolean)) {
    fail(`Deployment promotion is invalid: ${JSON.stringify({checks, fileChecks})}`);
  }
  return {promotion, checks, fileChecks};
}

async function createApiClients(repositoryRoot) {
  const firebaseToolsLib = path.join(
    repositoryRoot,
    "tooling",
    "firebase-cli",
    "node_modules",
    "firebase-tools",
    "lib",
  );
  const auth = require(path.join(firebaseToolsLib, "auth"));
  const api = require(path.join(firebaseToolsLib, "apiv2"));
  const account = auth.getProjectDefaultAccount(repositoryRoot);
  if (!account) fail("No authenticated Firebase CLI account is available.");
  auth.setActiveAccount({}, account);
  return {
    rules: new api.Client({
      urlPrefix: "https://firebaserules.googleapis.com/v1",
    }),
    firestore: new api.Client({
      urlPrefix: "https://firestore.googleapis.com/v1",
    }),
    resourceManager: new api.Client({
      urlPrefix: "https://cloudresourcemanager.googleapis.com/v1",
    }),
  };
}

async function listCompositeIndexes(firestoreClient, projectId) {
  const indexes = [];
  let pageToken = null;
  do {
    const query = new URLSearchParams();
    if (pageToken != null) query.set("pageToken", pageToken);
    const querySuffix = query.size === 0 ? "" : `?${query.toString()}`;
    const response = (
      await firestoreClient.get(
        `/projects/${projectId}/databases/(default)/` +
          `collectionGroups/-/indexes${querySuffix}`,
      )
    ).body;
    indexes.push(...(response.indexes ?? []));
    pageToken = response.nextPageToken ?? null;
  } while (pageToken != null);
  return indexes;
}

async function collectLiveState(options, promotion) {
  const clients = await createApiClients(options.repositoryRoot);
  const release = (
    await clients.rules.get(
      `/projects/${options.projectId}/releases/cloud.firestore`,
    )
  ).body;
  const ruleset = (await clients.rules.get(`/${release.rulesetName}`)).body;
  const deployedRulesFile =
    ruleset.source.files.find((file) => file.name === "firestore.rules") ??
    ruleset.source.files[0];
  const repositoryRules = fs.readFileSync(
    path.join(options.repositoryRoot, "firestore.rules"),
    "utf8",
  );

  const liveIndexDefinition = firebaseJson(options.repositoryRoot, [
    "firestore:indexes",
    "--project",
    options.projectId,
  ]);
  const sourceIndexDefinition = readJson(
    path.join(options.repositoryRoot, "firestore.indexes.json"),
  );
  const liveIndexes = await listCompositeIndexes(
    clients.firestore,
    options.projectId,
  );
  const sourceIndexes = sourceIndexDefinition.indexes ?? [];
  const liveFieldOverrides = liveIndexDefinition.fieldOverrides ?? [];
  const sourceFieldOverrides = sourceIndexDefinition.fieldOverrides ?? [];

  const liveFunctions = firebaseJson(options.repositoryRoot, [
    "functions:list",
    "--project",
    options.projectId,
  ]);
  const functionEvidence = {};
  for (const [name, expected] of Object.entries(REQUIRED_FUNCTIONS)) {
    const allNameMatches = liveFunctions.filter(
      (candidate) => candidate.id === name,
    );
    const matches = allNameMatches.filter(
      (candidate) => candidate.id === name && candidate.region === REGION,
    );
    const candidate = matches.length === 1 ? matches[0] : null;
    const triggerExact =
      expected.kind === "callable"
        ? candidate?.callableTrigger != null
        : candidate?.eventTrigger?.eventType ===
            "google.cloud.firestore.document.v1.written" &&
          candidate?.eventTrigger?.retry === true &&
          candidate?.eventTrigger?.eventFilterPathPatterns?.document ===
            "{collectionId}/{documentId}";
    functionEvidence[name] = {
      matchCount: matches.length,
      allRegionMatchCount: allNameMatches.length,
      state: candidate?.state ?? null,
      runtime: candidate?.runtime ?? null,
      serviceAccount: candidate?.serviceAccount ?? null,
      sourceHash: candidate?.hash ?? null,
      appCheckParameter:
        candidate?.environmentVariables
          ?.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK ?? null,
      triggerExact,
      exact:
        candidate != null &&
        allNameMatches.length === 1 &&
        candidate.state === "ACTIVE" &&
        candidate.runtime === "nodejs22" &&
        candidate.serviceAccount === expected.serviceAccount &&
        candidate.timeoutSeconds === expected.timeoutSeconds &&
        candidate.availableMemoryMb === expected.availableMemoryMb &&
        candidate.concurrency === expected.concurrency &&
        candidate.environmentVariables
          ?.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK === "false" &&
        triggerExact,
    };
  }

  const iamPolicy = (
    await clients.resourceManager.post(
      `/projects/${options.projectId}:getIamPolicy`,
      {options: {requestedPolicyVersion: 3}},
    )
  ).body;
  const runtimeIdentityEvidence = {};
  for (const [name, expected] of Object.entries(REQUIRED_FUNCTIONS)) {
    const roles = rolesForMember(
      iamPolicy,
      `serviceAccount:${expected.serviceAccount}`,
    );
    const forbiddenRoles = roles.filter((role) => FORBIDDEN_RUNTIME_ROLES.has(role));
    const unexpectedRoles = roles.filter((role) => !expected.roles.includes(role));
    runtimeIdentityEvidence[name] = {
      serviceAccount: expected.serviceAccount,
      roles,
      requiredRoles: expected.roles,
      forbiddenRoles,
      unexpectedRoles,
      exact:
        sameStrings(roles, expected.roles) &&
        forbiddenRoles.length === 0 &&
        unexpectedRoles.length === 0,
    };
  }

  const database = (
    await clients.firestore.get(
      `/projects/${options.projectId}/databases/(default)`,
    )
  ).body;
  let contractDocument = null;
  try {
    contractDocument = (
      await clients.firestore.get(
        `/projects/${options.projectId}/databases/(default)/documents/` +
          CONTRACT_PATH,
      )
    ).body;
  } catch (error) {
    if (httpStatus(error) !== 404) throw error;
  }
  const contract = decodeContract(contractDocument);

  const sourceHashes = Object.fromEntries(
    promotion.sourceAuthority.deploymentFiles.map((binding) => [
      binding.path,
      fileSha256(path.join(options.repositoryRoot, binding.path)),
    ]),
  );
  return {
    firestoreRules: {
      releaseName: release.name ?? `projects/${options.projectId}/releases/cloud.firestore`,
      rulesetName: release.rulesetName,
      rulesetCreateTime: ruleset.createTime,
      activeSha256: sha256Text(deployedRulesFile.content),
      sourceSha256: sha256Text(repositoryRules),
      matchesSource: deployedRulesFile.content === repositoryRules,
    },
    firestoreIndexes: {
      liveCount: liveIndexes.length,
      sourceCount: sourceIndexes.length,
      readyCount: liveIndexes.filter((index) => index.state === "READY").length,
      allReady:
        liveIndexes.length > 0 &&
        liveIndexes.every((index) => index.state === "READY"),
      fieldOverridesMatchSource:
        canonicalJson(liveFieldOverrides) === canonicalJson(sourceFieldOverrides),
      matchesSource:
        indexSetsEqual(liveIndexes, sourceIndexes) &&
        canonicalJson(liveFieldOverrides) === canonicalJson(sourceFieldOverrides),
    },
    functions: {
      liveCount: liveFunctions.length,
      required: functionEvidence,
      requiredFunctionsActive: Object.values(functionEvidence).every(
        (item) => item.exact,
      ),
      requiredFunctionsShareSourceHash:
        new Set(
          Object.values(functionEvidence)
            .map((item) => item.sourceHash)
            .filter(Boolean),
        ).size === 1,
    },
    runtimeIdentities: {
      functions: runtimeIdentityEvidence,
      exact: Object.values(runtimeIdentityEvidence).every((item) => item.exact),
    },
    database: {
      name: database.name,
      locationId: database.locationId,
      type: database.type,
      pointInTimeRecoveryEnablement:
        database.pointInTimeRecoveryEnablement ?? null,
      deleteProtectionState: database.deleteProtectionState ?? null,
    },
    contract,
    sourceHashes,
  };
}

function exactContract(contract, sourceCommit, backfillReceiptSha256) {
  if (contract == null) return false;
  const expectedFields = [
    "activatedAt",
    "backfillReceiptSha256",
    "collections",
    "protocolFingerprint",
    "protocolVersion",
    "serverStampField",
    "sourceCommit",
    "state",
    "writerVersion",
  ];
  return (
    sameStrings(contract.fieldNames, expectedFields) &&
    contract.state === "ACTIVE" &&
    contract.protocolVersion === PROTOCOL_VERSION &&
    contract.protocolFingerprint === PROTOCOL_FINGERPRINT &&
    contract.writerVersion === WRITER_VERSION &&
    contract.serverStampField === SERVER_STAMP_FIELD &&
    canonicalJson(contract.collections) === canonicalJson(COLLECTIONS) &&
    typeof contract.activatedAt === "string" &&
    contract.sourceCommit === sourceCommit &&
    contract.backfillReceiptSha256 === backfillReceiptSha256
  );
}

async function collect(options) {
  if (!fs.existsSync(options.repositoryRoot)) fail("Repository root does not exist.");
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("Backend evidence output must be outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail("Backend evidence output already exists; receipts are append-only.");
  }

  const gitState = {
    branch: git(options.repositoryRoot, ["branch", "--show-current"]),
    commit: git(options.repositoryRoot, ["rev-parse", "HEAD"]),
    tree: git(options.repositoryRoot, ["rev-parse", "HEAD^{tree}"]),
    originMain: git(options.repositoryRoot, ["rev-parse", "origin/main"]),
    trackedStatus: git(options.repositoryRoot, [
      "status",
      "--porcelain",
      "--untracked-files=no",
    ]),
    deploymentInputStatus: git(options.repositoryRoot, [
      "status",
      "--porcelain",
      "--untracked-files=all",
      "--",
      "firebase.json",
      "firestore.rules",
      "firestore.indexes.json",
      "functions",
      "governance/global-pull-protocol-v1.json",
      "tooling/firebase-cli/package.json",
      "tooling/firebase-cli/package-lock.json",
    ]),
  };
  if (
    gitState.branch !== "main" ||
    gitState.commit !== gitState.originMain ||
    gitState.trackedStatus !== "" ||
    gitState.deploymentInputStatus !== ""
  ) {
    fail("Backend evidence requires exact tracked-clean main equal to origin/main.");
  }
  if (options.sourceCommit != null && gitState.commit !== options.sourceCommit) {
    fail("The requested backend source commit is not the exact current main.");
  }

  const promotionEvidence = validatePromotion(
    options.repositoryRoot,
    options.promotionPath,
  );
  if (
    gitState.commit === promotionEvidence.promotion.approvalAuthority.baselineCommit
  ) {
    fail("The production activation promotion is not effective on its baseline.");
  }

  const inventory = readJson(options.inventoryPath);
  const inventoryValidation = protocolReceiptChecks(
    inventory,
    "GLOBAL_PULL_SERVER_CLOCK_INVENTORY",
    options.projectId,
  );
  if (!inventoryValidation.valid || inventory.readOnly !== true) {
    fail("The global-pull inventory receipt is invalid.");
  }
  const limits = promotionEvidence.promotion.migrationBoundary;
  const inventoryShape = inventoryShapeValid(inventory.inventory);
  const inventoryWithinPromotion =
    inventoryShape &&
    inventory.inventory.total <= limits.maximumObservedDocuments &&
    inventory.inventory.missing <= limits.maximumBackfillUpdates &&
    inventory.inventory.malformed === 0 &&
    inventory.inventory.stamped + inventory.inventory.missing ===
      inventory.inventory.total;
  if (!inventoryWithinPromotion) {
    fail("The production inventory exceeds the admitted migration boundary.");
  }

  const live = await collectLiveState(options, promotionEvidence.promotion);
  const commonChecks = {
    indexesExact: live.firestoreIndexes.matchesSource,
    indexesReady: live.firestoreIndexes.allReady,
    requiredFunctionsActive: live.functions.requiredFunctionsActive,
    requiredFunctionsShareSourceHash:
      live.functions.requiredFunctionsShareSourceHash,
    runtimeIdentitiesExact: live.runtimeIdentities.exact,
    inventoryValid: inventoryValidation.valid,
    inventoryWithinPromotion,
  };

  let receiptSpecific;
  let decision;
  if (options.mode === "preflight") {
    const checks = {
      ...commonChecks,
      runtimeContractAbsent: live.contract == null,
    };
    const passed = Object.values(checks).every(Boolean);
    decision = passed
      ? "PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT"
      : "STOP_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT";
    receiptSpecific = {
      checks,
      deploymentRequired: {
        firestoreRules: !live.firestoreRules.matchesSource,
        firestoreIndexes: false,
        functions: Object.keys(REQUIRED_FUNCTIONS),
      },
    };
  } else {
    const backfillReceiptPath = path.resolve(options.backfillReceiptPath);
    const activationReceiptPath = path.resolve(options.activationReceiptPath);
    const backfill = readJson(backfillReceiptPath);
    const activation = readJson(activationReceiptPath);
    const backfillValidation = protocolReceiptChecks(
      backfill,
      "GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED",
      options.projectId,
    );
    const activationValidation = protocolReceiptChecks(
      activation,
      "GLOBAL_PULL_SERVER_CLOCK_ACTIVATION",
      options.projectId,
    );
    const checks = {
      ...commonChecks,
      rulesExact: live.firestoreRules.matchesSource,
      inventoryZeroGap:
        inventory.inventory.missing === 0 &&
        inventory.inventory.malformed === 0,
      backfillReceiptValid:
        backfillValidation.valid &&
        backfill.sourceCommit === options.sourceCommit &&
        inventoryShapeValid(backfill.before) &&
        inventoryShapeValid(backfill.after) &&
        backfillUpdateCountsValid(backfill) &&
        backfill.before?.malformed === 0 &&
        backfill.before?.total <= limits.maximumObservedDocuments &&
        backfill.before?.missing <= limits.maximumBackfillUpdates &&
        backfill.updated === backfill.before?.missing &&
        backfill.updated <= limits.maximumBackfillUpdates &&
        backfill.after?.missing === 0 &&
        backfill.after?.malformed === 0 &&
        backfill.after?.total === backfill.before?.total,
      activationReceiptValid:
        activationValidation.valid &&
        activation.sourceCommit === options.sourceCommit &&
        activation.contractPath === CONTRACT_PATH &&
        typeof activation.activatedAt === "string" &&
        activation.backfillReceiptSha256 === backfill.receiptSha256 &&
        inventoryShapeValid(activation.preActivation) &&
        activation.preActivation?.missing === 0 &&
        activation.preActivation?.malformed === 0,
      runtimeContractExact: exactContract(
        live.contract,
        options.sourceCommit,
        backfill.receiptSha256,
      ),
    };
    const passed = Object.values(checks).every(Boolean);
    decision = passed
      ? "PASS_BUILD8_F4_BACKEND_READY"
      : "STOP_BUILD8_F4_BACKEND_NOT_READY";
    receiptSpecific = {
      checks,
      backfill: {
        fileSha256: fileSha256(backfillReceiptPath),
        receiptSha256: backfill.receiptSha256,
        updated: backfill.updated,
      },
      activation: {
        fileSha256: fileSha256(activationReceiptPath),
        receiptSha256: activation.receiptSha256,
        activatedAt: activation.activatedAt,
      },
    };
  }

  const receipt = sealReceipt({
    schemaVersion: 1,
    evidenceType:
      options.mode === "preflight"
        ? "build-8-production-global-pull-activation-preflight"
        : "build-8-f4-backend-readiness",
    capturedAtUtc: new Date().toISOString(),
    projectId: options.projectId,
    readOnly: true,
    source: {
      repository: "abhishekvatsa/crm3_baf_ops",
      commit: gitState.commit,
      tree: gitState.tree,
      branch: gitState.branch,
      originParityVerified: gitState.commit === gitState.originMain,
      trackedWorktreeClean: gitState.trackedStatus === "",
      deploymentInputsClean: gitState.deploymentInputStatus === "",
    },
    deploymentPromotionSha256: fileSha256(options.promotionPath),
    inventory: {
      fileSha256: fileSha256(options.inventoryPath),
      receiptSha256: inventory.receiptSha256,
      observedAt: inventory.observedAt,
      total: inventory.inventory.total,
      stamped: inventory.inventory.stamped,
      missing: inventory.inventory.missing,
      malformed: inventory.inventory.malformed,
      documentIdsRetained: false,
    },
    live: {
      firestoreRulesMatchesSource: live.firestoreRules.matchesSource,
      firestoreIndexesMatchSource: live.firestoreIndexes.matchesSource,
      requiredFunctionsActive: live.functions.requiredFunctionsActive,
      globalPullContractActive:
        live.contract != null && live.contract.state === "ACTIVE",
      globalPullInventoryZeroGap:
        inventory.inventory.missing === 0 &&
        inventory.inventory.malformed === 0,
      ...live,
    },
    ...receiptSpecific,
    decision,
    programmeBoundary: {
      stage2dF4ClosureAuthorized: false,
      p07ClosureAuthorized: false,
      pilotHandoutAuthorized: false,
      distributionAuthorized: false,
      appCheckActivationPerformed: false,
    },
  });

  fs.mkdirSync(path.dirname(options.outputPath), {recursive: true});
  fs.writeFileSync(options.outputPath, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  process.stdout.write(
    `${JSON.stringify({
      mode: options.mode,
      projectId: options.projectId,
      outputPath: options.outputPath,
      receiptSha256: receipt.receiptSha256,
      decision,
      checks: receiptSpecific.checks,
    }, null, 2)}\n`,
  );
  if (!decision.startsWith("PASS_")) process.exitCode = 2;
  return receipt;
}

async function main() {
  if (process.argv.slice(2).includes("--verify-receipt")) {
    const argv = process.argv.slice(2);
    const known = new Set(["--verify-receipt", "--label"]);
    for (let index = 0; index < argv.length; index += 2) {
      if (!known.has(argv[index])) fail(`Unknown argument: ${argv[index]}`);
    }
    const receiptPath = path.resolve(readArg(argv, "--verify-receipt"));
    const label = readArg(argv, "--label");
    const receipt = readJson(receiptPath);
    verifyReceiptSeal(receipt, label);
    process.stdout.write(
      `${JSON.stringify({
        verified: true,
        label,
        receiptSha256: receipt.receiptSha256,
      })}\n`,
    );
    return receipt;
  }
  return collect(parseArgs(process.argv.slice(2)));
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`PRODUCTION_GLOBAL_PULL_READBACK_FAILED: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  backfillUpdateCountsValid,
  canonicalJson,
  collect,
  collectLiveState,
  decodeContract,
  indexSetsEqual,
  inventoryShapeValid,
  normalizeIndex,
  protocolReceiptChecks,
  sealReceipt,
  trackedPathManifest,
  validatePromotion,
  verifyReceiptSeal,
};
