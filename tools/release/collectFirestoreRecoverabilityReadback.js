"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const {sealReceipt} = require("./collectProductionGlobalPullBackend.js");
const {
  collectSourceBinding,
  isPathInside,
  sha256,
} = require("./collectFirestoreRulesIndexesReadback.js");

const PRODUCTION_PROJECT_ID = "crm3-baf-ops-b8638";
const PRODUCTION_DATABASE = "(default)";
const PRODUCTION_LOCATION = "asia-south1";
const POLICY_PATH = "release/lr04-firestore-recoverability-readback-policy.json";
const RESTORE_SEAL_PATH =
  "release/evidence/production-prelive-restore-pack-seal.json";

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const options = {observe: false, gcloudCommand: "gcloud"};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--observe") {
      options.observe = true;
      continue;
    }
    const fields = {
      "--repository-root": "repositoryRoot",
      "--project-id": "projectId",
      "--database": "database",
      "--location": "location",
      "--output": "outputPath",
      "--gcloud": "gcloudCommand",
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
  for (const field of [
    "repositoryRoot",
    "projectId",
    "database",
    "location",
    "outputPath",
  ]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.outputPath = path.resolve(options.outputPath);
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    fail(`Only the exact production project ${PRODUCTION_PROJECT_ID} is supported.`);
  }
  if (options.database !== PRODUCTION_DATABASE) {
    fail(`Only the exact production database ${PRODUCTION_DATABASE} is supported.`);
  }
  if (options.location !== PRODUCTION_LOCATION) {
    fail(`Only the exact production location ${PRODUCTION_LOCATION} is supported.`);
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
  return childProcess
    .execFileSync(resolved.command, resolved.args, {
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
    })
    .trim();
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

function sortedCounts(values) {
  const counts = {};
  for (const value of values) counts[value] = (counts[value] ?? 0) + 1;
  return Object.fromEntries(
    Object.entries(counts).sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  );
}

function hasExactKeys(value, expectedKeys) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  return (
    Object.keys(value).sort().join("\0") ===
    [...expectedKeys].sort().join("\0")
  );
}

function summarizeDatabase(database) {
  return {
    name: typeof database?.name === "string" ? database.name : null,
    locationId:
      typeof database?.locationId === "string" ? database.locationId : null,
    type: typeof database?.type === "string" ? database.type : null,
    databaseEdition:
      typeof database?.databaseEdition === "string"
        ? database.databaseEdition
        : null,
    pointInTimeRecoveryEnablement:
      typeof database?.pointInTimeRecoveryEnablement === "string"
        ? database.pointInTimeRecoveryEnablement
        : null,
    deleteProtectionState:
      typeof database?.deleteProtectionState === "string"
        ? database.deleteProtectionState
        : null,
    versionRetentionPeriod:
      typeof database?.versionRetentionPeriod === "string"
        ? database.versionRetentionPeriod
        : null,
    earliestVersionTime:
      typeof database?.earliestVersionTime === "string"
        ? database.earliestVersionTime
        : null,
  };
}

function summarizeSchedules(schedules, expectedDatabaseName) {
  if (!Array.isArray(schedules)) fail("Backup schedules response is not an array.");
  const recurrenceTypes = [];
  const retentionDurations = [];
  let allNamesTargetDatabase = true;
  for (const schedule of schedules) {
    const name = typeof schedule?.name === "string" ? schedule.name : "";
    allNamesTargetDatabase =
      allNamesTargetDatabase &&
      name.startsWith(`${expectedDatabaseName}/backupSchedules/`);
    if (schedule?.dailyRecurrence != null) recurrenceTypes.push("DAILY");
    else if (schedule?.weeklyRecurrence != null) recurrenceTypes.push("WEEKLY");
    else recurrenceTypes.push("UNKNOWN");
    const retention = schedule?.retention ?? schedule?.retentionPeriod;
    if (typeof retention === "string") retentionDurations.push(retention);
  }
  return {
    count: schedules.length,
    allNamesTargetDatabase,
    recurrenceTypeCounts: sortedCounts(recurrenceTypes),
    retentionDurations: [...new Set(retentionDurations)].sort(),
  };
}

function summarizeBackups(backups, expectedDatabaseName) {
  if (!Array.isArray(backups)) fail("Backups response is not an array.");
  const states = [];
  let allDatabasesTargetExact = true;
  let latestSnapshotTime = null;
  for (const backup of backups) {
    allDatabasesTargetExact =
      allDatabasesTargetExact && backup?.database === expectedDatabaseName;
    states.push(typeof backup?.state === "string" ? backup.state : "MISSING");
    if (
      typeof backup?.snapshotTime === "string" &&
      (latestSnapshotTime == null || backup.snapshotTime > latestSnapshotTime)
    ) {
      latestSnapshotTime = backup.snapshotTime;
    }
  }
  return {
    count: backups.length,
    allDatabasesTargetExact,
    stateCounts: sortedCounts(states),
    latestSnapshotTime,
  };
}

function operationType(operation) {
  return typeof operation?.metadata?.["@type"] === "string"
    ? operation.metadata["@type"]
    : "MISSING";
}

function operationSucceeded(operation) {
  return (
    operation?.done === true &&
    operation?.error == null &&
    operation?.metadata?.operationState === "SUCCESSFUL"
  );
}

function summarizeOperations({
  operations,
  describedExport,
  sealedOperationName,
  sealedOutputUriPrefix,
  sealedCompletedAtUtc,
  inventoryLimit,
}) {
  if (!Array.isArray(operations)) fail("Operations response is not an array.");
  const exportType =
    "type.googleapis.com/google.firestore.admin.v1.ExportDocumentsMetadata";
  const importType =
    "type.googleapis.com/google.firestore.admin.v1.ImportDocumentsMetadata";
  const exportResponseType =
    "type.googleapis.com/google.firestore.admin.v1.ExportDocumentsResponse";
  const importOperations = operations.filter(
    (operation) => operationType(operation) === importType,
  );
  const exportOperations = operations.filter(
    (operation) => operationType(operation) === exportType,
  );
  const sealedHistoryMatches = operations.filter(
    (operation) => operation?.name === sealedOperationName,
  );
  return {
    inventoryLimit,
    count: operations.length,
    inventoryBelowLimit: operations.length < inventoryLimit,
    doneCount: operations.filter((operation) => operation?.done === true).length,
    errorCount: operations.filter((operation) => operation?.error != null).length,
    metadataTypeCounts: sortedCounts(operations.map(operationType)),
    exportOperationCount: exportOperations.length,
    successfulExportOperationCount: exportOperations.filter(operationSucceeded)
      .length,
    importOperationCount: importOperations.length,
    successfulImportOperationCount: importOperations.filter(operationSucceeded)
      .length,
    sealedExport: {
      operationNameSha256: sha256(sealedOperationName),
      outputUriPrefixSha256: sha256(sealedOutputUriPrefix),
      appearsExactlyOnceInHistory: sealedHistoryMatches.length === 1,
      describedNameMatches: describedExport?.name === sealedOperationName,
      describedDone: describedExport?.done === true,
      describedErrorAbsent: describedExport?.error == null,
      describedOperationState:
        describedExport?.metadata?.operationState ?? null,
      describedMetadataType: operationType(describedExport),
      describedResponseType:
        describedExport?.response?.["@type"] ?? null,
      describedOutputUriPrefixMatches:
        describedExport?.response?.outputUriPrefix === sealedOutputUriPrefix,
      describedEndTimeMatches:
        describedExport?.metadata?.endTime === sealedCompletedAtUtc,
      exactSuccessfulExport:
        describedExport?.name === sealedOperationName &&
        operationSucceeded(describedExport) &&
        operationType(describedExport) === exportType &&
        describedExport?.response?.["@type"] === exportResponseType &&
        describedExport?.response?.outputUriPrefix === sealedOutputUriPrefix &&
        describedExport?.metadata?.endTime === sealedCompletedAtUtc,
    },
  };
}

function loadRestoreSeal(repositoryRoot, policy) {
  const sealPath = path.join(repositoryRoot, RESTORE_SEAL_PATH);
  const raw = fs.readFileSync(sealPath);
  const seal = JSON.parse(raw.toString("utf8"));
  const mutationFlags = Object.values(seal?.mutationBoundary ?? {});
  return {
    operationName: seal?.protectedFirestoreExport?.operationName ?? null,
    outputUriPrefix: seal?.protectedFirestoreExport?.outputUriPrefix ?? null,
    completedAtUtc: seal?.protectedFirestoreExport?.completedAtUtc ?? null,
    summary: {
      path: RESTORE_SEAL_PATH,
      fileSha256: sha256(raw),
      expectedFileSha256: policy?.restoreSeal?.sha256 ?? null,
      exactFile:
        sha256(raw) === policy?.restoreSeal?.sha256 &&
        raw.length === policy?.restoreSeal?.bytes,
      decision: seal?.decision ?? null,
      projectId: seal?.protectedFirestoreExport?.projectId ?? null,
      region: seal?.protectedFirestoreExport?.region ?? null,
      operationState:
        seal?.protectedFirestoreExport?.operationState ?? null,
      privateCustodyCopyCount:
        seal?.privatePack?.privateCustodyCopyCount ?? null,
      independentVerificationDecision:
        seal?.independentVerification?.decision ?? null,
      independentVerificationExact:
        seal?.independentVerification?.archiveHashRecalculated === true &&
        seal?.independentVerification?.everyManifestEntryHashAndSizeVerified ===
          true &&
        seal?.independentVerification?.allManagedExportObjectsVerified === true,
      mutationBoundaryAllFalse:
        mutationFlags.length > 0 && mutationFlags.every((value) => value === false),
    },
  };
}

function adjudicateReadback({
  projectId,
  databaseId,
  location,
  policy,
  sourceBefore,
  sourceAfter,
  database,
  schedules,
  backups,
  operations,
  restoreSeal,
  observe,
}) {
  const expectedDatabaseName =
    `projects/${PRODUCTION_PROJECT_ID}/databases/${PRODUCTION_DATABASE}`;
  const mutationKeys = [
    "pointInTimeRecoveryChanged",
    "deleteProtectionChanged",
    "backupScheduleCreatedUpdatedOrDeleted",
    "backupCreatedOrDeleted",
    "firestoreExportOrImportPerformed",
    "firestoreDocumentReadOrWritePerformed",
    "storageObjectReadOrWritePerformed",
    "functionsMutated",
    "iamMutated",
    "billingChanged",
    "businessDataReadOrWritten",
  ];
  const privacyKeys = [
    "operatorAccountIdentityRetained",
    "firestoreDocumentOrBusinessPayloadRetained",
    "databaseUidOrEtagRetained",
    "backupScheduleOrBackupNamesRetained",
    "operationNamesOrOutputPrefixesRetained",
    "privateCustodyPathsRetained",
    "operationalStateRepresentedByCountsStatesHashesAndTimesOnly",
  ];
  const checks = {
    productionTargetExact:
      projectId === PRODUCTION_PROJECT_ID &&
      databaseId === PRODUCTION_DATABASE &&
      location === PRODUCTION_LOCATION,
    policyTargetExact:
      policy?.schemaVersion === 1 &&
      policy?.policyId === "LR04-FIRESTORE-RECOVERABILITY-READBACK-POLICY-V1" &&
      policy?.productionProjectId === projectId &&
      policy?.productionDatabase === databaseId &&
      policy?.productionLocation === location &&
      policy?.operationInventoryLimit === operations.inventoryLimit &&
      JSON.stringify(policy?.gateIds) === JSON.stringify(["LR-04"]) &&
      JSON.stringify(policy?.findingIds) === JSON.stringify(["P-05"]) &&
      policy?.restoreSeal?.path === RESTORE_SEAL_PATH &&
      policy?.restoreSeal?.decision ===
        "PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED_AND_INDEPENDENTLY_VERIFIED" &&
      policy?.postureSemantics?.collectionPassMayContainAdversePosture === true &&
      policy?.postureSemantics
        ?.managedExportIsNotRepresentedAsNativeBackupOrRestoreProof === true &&
      hasExactKeys(policy?.mutationBoundary, mutationKeys) &&
      mutationKeys.every((key) => policy.mutationBoundary[key] === false) &&
      hasExactKeys(policy?.privacyBoundary, privacyKeys) &&
      privacyKeys.slice(0, -1).every(
        (key) => policy.privacyBoundary[key] === false,
      ) &&
      policy?.privacyBoundary
        ?.operationalStateRepresentedByCountsStatesHashesAndTimesOnly === true,
    sourceBranchMain:
      sourceBefore.branch === "main" && sourceAfter.branch === "main",
    sourceCommitMatchesOriginMain:
      sourceBefore.commit === sourceBefore.originMain &&
      sourceAfter.commit === sourceAfter.originMain,
    sourceBindingStable:
      sourceBefore.commit === sourceAfter.commit &&
      sourceBefore.tree === sourceAfter.tree,
    governedSourceClean:
      sourceBefore.governedWorktreeClean && sourceAfter.governedWorktreeClean,
    databaseDescriptorExact:
      database.name === expectedDatabaseName &&
      database.locationId === location &&
      database.type === "FIRESTORE_NATIVE",
    databaseProtectionStatesPresent:
      [
        "POINT_IN_TIME_RECOVERY_ENABLED",
        "POINT_IN_TIME_RECOVERY_DISABLED",
      ].includes(database.pointInTimeRecoveryEnablement) &&
      ["DELETE_PROTECTION_ENABLED", "DELETE_PROTECTION_DISABLED"].includes(
        database.deleteProtectionState,
      ),
    scheduleInventoryTargetExact: schedules.allNamesTargetDatabase,
    backupInventoryTargetExact: backups.allDatabasesTargetExact,
    operationInventoryComplete: operations.inventoryBelowLimit,
    restoreSealExact:
      restoreSeal.exactFile &&
      restoreSeal.decision ===
        "PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED_AND_INDEPENDENTLY_VERIFIED" &&
      restoreSeal.projectId === projectId &&
      restoreSeal.region === location &&
      restoreSeal.operationState === "SUCCESSFUL" &&
      restoreSeal.privateCustodyCopyCount >= 2 &&
      restoreSeal.independentVerificationDecision ===
        "PASS_INDEPENDENT_RESTORE_PACK_VERIFICATION" &&
      restoreSeal.independentVerificationExact &&
      restoreSeal.mutationBoundaryAllFalse,
    sealedExportReconfirmed:
      operations.sealedExport.appearsExactlyOnceInHistory &&
      operations.sealedExport.exactSuccessfulExport,
  };
  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value !== true)
    .map(([name]) => name);
  const holds = [];
  if (
    database.pointInTimeRecoveryEnablement !== "POINT_IN_TIME_RECOVERY_ENABLED"
  ) {
    holds.push("pointInTimeRecoveryDisabled");
  }
  if (database.deleteProtectionState !== "DELETE_PROTECTION_ENABLED") {
    holds.push("deleteProtectionDisabled");
  }
  if (schedules.count === 0) holds.push("noNativeBackupSchedule");
  if (backups.count === 0) holds.push("noNativeBackup");
  if (operations.successfulImportOperationCount === 0) {
    holds.push("noRestoreImportProof");
  }
  const decision = observe
    ? "OBSERVE_FIRESTORE_RECOVERABILITY_LIVE_READBACK"
    : failedChecks.length === 0
      ? "PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK"
      : "HOLD_FIRESTORE_RECOVERABILITY_LIVE_READBACK";
  return {
    failedChecks,
    evidence: {
      schemaVersion: 1,
      evidenceType: "firestore-recoverability-live-readback",
      mode: observe ? "OBSERVE" : "STRICT",
      projectId,
      database: databaseId,
      location,
      gateIds: ["LR-04"],
      findingIds: ["P-05"],
      source: {before: sourceBefore, after: sourceAfter},
      commands: [
        {kind: "LOCAL_READ", command: "git status/rev-parse"},
        {
          kind: "LOCAL_READ",
          command: "read exact sealed production restore-pack receipt",
        },
        {
          kind: "GCLOUD_READ",
          command: "firestore databases describe",
        },
        {
          kind: "GCLOUD_READ",
          command: "firestore backups schedules list",
        },
        {kind: "GCLOUD_READ", command: "firestore backups list"},
        {
          kind: "GCLOUD_READ",
          command: "firestore operations list",
          limit: operations.inventoryLimit,
        },
        {
          kind: "GCLOUD_READ",
          command: "firestore operations describe sealed export",
        },
      ],
      outputs: {database, schedules, backups, operations, restoreSeal},
      posture: {
        holds,
        decision:
          holds.length === 0
            ? "PASS_FIRESTORE_RECOVERABILITY_POSTURE"
            : "HOLD_FIRESTORE_RECOVERABILITY_POSTURE",
      },
      checks,
      failedChecks,
      decision,
      closureScope: {
        lr04Closed: false,
        p05Closed: false,
        collectorAuthorizesClosure: false,
        sourceAndCiOnly: false,
      },
      mutationBoundary: {
        pointInTimeRecoveryChanged: false,
        deleteProtectionChanged: false,
        backupScheduleCreatedUpdatedOrDeleted: false,
        backupCreatedOrDeleted: false,
        firestoreExportOrImportPerformed: false,
        firestoreDocumentReadOrWritePerformed: false,
        storageObjectReadOrWritePerformed: false,
        functionsMutated: false,
        iamMutated: false,
        billingChanged: false,
        businessDataReadOrWritten: false,
      },
      privacyBoundary: {
        operatorAccountIdentityRetained: false,
        firestoreDocumentOrBusinessPayloadRetained: false,
        databaseUidOrEtagRetained: false,
        backupScheduleOrBackupNamesRetained: false,
        operationNamesOrOutputPrefixesRetained: false,
        privateCustodyPathsRetained: false,
        operationalStateRepresentedByCountsStatesHashesAndTimesOnly: true,
      },
    },
  };
}

function collectLiveState(options, policy) {
  const expectedDatabaseName =
    `projects/${options.projectId}/databases/${options.database}`;
  const restoreSeal = loadRestoreSeal(options.repositoryRoot, policy);
  if (
    typeof restoreSeal.operationName !== "string" ||
    typeof restoreSeal.outputUriPrefix !== "string" ||
    typeof restoreSeal.completedAtUtc !== "string"
  ) {
    fail("The sealed restore-pack receipt has incomplete export authority.");
  }
  const common = [`--project=${options.projectId}`];
  const databaseRaw = gcloudJson(
    options.gcloudCommand,
    [
      "firestore",
      "databases",
      "describe",
      `--database=${options.database}`,
      ...common,
    ],
    options.repositoryRoot,
  );
  const schedulesRaw = gcloudJson(
    options.gcloudCommand,
    [
      "firestore",
      "backups",
      "schedules",
      "list",
      `--database=${options.database}`,
      ...common,
    ],
    options.repositoryRoot,
  );
  const backupsRaw = gcloudJson(
    options.gcloudCommand,
    [
      "firestore",
      "backups",
      "list",
      `--location=${options.location}`,
      ...common,
    ],
    options.repositoryRoot,
  );
  const operationLimit = policy.operationInventoryLimit;
  const operationsRaw = gcloudJson(
    options.gcloudCommand,
    [
      "firestore",
      "operations",
      "list",
      `--database=${options.database}`,
      `--limit=${operationLimit}`,
      ...common,
    ],
    options.repositoryRoot,
  );
  const describedExport = gcloudJson(
    options.gcloudCommand,
    [
      "firestore",
      "operations",
      "describe",
      restoreSeal.operationName,
      ...common,
    ],
    options.repositoryRoot,
  );
  return {
    database: summarizeDatabase(databaseRaw),
    schedules: summarizeSchedules(schedulesRaw, expectedDatabaseName),
    backups: summarizeBackups(backupsRaw, expectedDatabaseName),
    operations: summarizeOperations({
      operations: operationsRaw,
      describedExport,
      sealedOperationName: restoreSeal.operationName,
      sealedOutputUriPrefix: restoreSeal.outputUriPrefix,
      sealedCompletedAtUtc: restoreSeal.completedAtUtc,
      inventoryLimit: operationLimit,
    }),
    restoreSeal: restoreSeal.summary,
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
    databaseId: options.database,
    location: options.location,
    policy,
    sourceBefore,
    sourceAfter,
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
  PRODUCTION_DATABASE,
  PRODUCTION_LOCATION,
  PRODUCTION_PROJECT_ID,
  RESTORE_SEAL_PATH,
  adjudicateReadback,
  loadRestoreSeal,
  parseArgs,
  resolveCommand,
  summarizeBackups,
  summarizeDatabase,
  summarizeOperations,
  summarizeSchedules,
};

if (require.main === module) {
  try {
    main();
  } catch (error) {
    process.stderr.write(
      `FIRESTORE_RECOVERABILITY_READBACK_FAILED: ${error.message}\n`,
    );
    process.exitCode = 1;
  }
}
