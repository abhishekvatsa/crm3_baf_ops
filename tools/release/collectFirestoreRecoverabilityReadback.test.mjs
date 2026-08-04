import assert from "node:assert/strict";
import fs from "node:fs";
import {createRequire} from "node:module";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  PRODUCTION_DATABASE,
  PRODUCTION_LOCATION,
  PRODUCTION_PROJECT_ID,
  adjudicateReadback,
  loadRestoreSeal,
  parseArgs,
  resolveCommand,
  summarizeBackups,
  summarizeDatabase,
  summarizeOperations,
  summarizeSchedules,
} = require("./collectFirestoreRecoverabilityReadback.js");

const currentFile = fileURLToPath(import.meta.url);
const repositoryRoot = path.resolve(path.dirname(currentFile), "..", "..");
const policy = JSON.parse(
  fs.readFileSync(
    path.join(repositoryRoot, "release/lr04-firestore-recoverability-readback-policy.json"),
    "utf8",
  ),
);
const expectedDatabaseName =
  `projects/${PRODUCTION_PROJECT_ID}/databases/${PRODUCTION_DATABASE}`;
const exportType =
  "type.googleapis.com/google.firestore.admin.v1.ExportDocumentsMetadata";
const exportResponseType =
  "type.googleapis.com/google.firestore.admin.v1.ExportDocumentsResponse";

function sourceBinding(overrides = {}) {
  return {
    branch: "main",
    commit: "a".repeat(40),
    tree: "b".repeat(40),
    originMain: "a".repeat(40),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
    ...overrides,
  };
}

function databaseSummary(overrides = {}) {
  return {
    name: expectedDatabaseName,
    locationId: PRODUCTION_LOCATION,
    type: "FIRESTORE_NATIVE",
    databaseEdition: "STANDARD",
    pointInTimeRecoveryEnablement: "POINT_IN_TIME_RECOVERY_DISABLED",
    deleteProtectionState: "DELETE_PROTECTION_DISABLED",
    versionRetentionPeriod: "3600s",
    earliestVersionTime: "2026-08-04T00:00:00Z",
    ...overrides,
  };
}

function scheduleSummary(overrides = {}) {
  return {
    count: 0,
    allNamesTargetDatabase: true,
    recurrenceTypeCounts: {},
    retentionDurations: [],
    ...overrides,
  };
}

function backupSummary(overrides = {}) {
  return {
    count: 0,
    allDatabasesTargetExact: true,
    stateCounts: {},
    latestSnapshotTime: null,
    ...overrides,
  };
}

function operationSummary(overrides = {}) {
  return {
    inventoryLimit: 1000,
    count: 24,
    inventoryBelowLimit: true,
    doneCount: 24,
    errorCount: 0,
    metadataTypeCounts: {IndexOperationMetadata: 23, [exportType]: 1},
    exportOperationCount: 1,
    successfulExportOperationCount: 1,
    importOperationCount: 0,
    successfulImportOperationCount: 0,
    sealedExport: {
      operationNameSha256: "C".repeat(64),
      outputUriPrefixSha256: "D".repeat(64),
      appearsExactlyOnceInHistory: true,
      describedNameMatches: true,
      describedDone: true,
      describedErrorAbsent: true,
      describedOperationState: "SUCCESSFUL",
      describedMetadataType: exportType,
      describedResponseType: exportResponseType,
      describedOutputUriPrefixMatches: true,
      describedEndTimeMatches: true,
      exactSuccessfulExport: true,
    },
    ...overrides,
  };
}

function restoreSealSummary(overrides = {}) {
  return {
    path: "release/evidence/production-prelive-restore-pack-seal.json",
    fileSha256: policy.restoreSeal.sha256,
    expectedFileSha256: policy.restoreSeal.sha256,
    exactFile: true,
    decision: policy.restoreSeal.decision,
    projectId: PRODUCTION_PROJECT_ID,
    region: PRODUCTION_LOCATION,
    operationState: "SUCCESSFUL",
    privateCustodyCopyCount: 2,
    independentVerificationDecision:
      "PASS_INDEPENDENT_RESTORE_PACK_VERIFICATION",
    independentVerificationExact: true,
    mutationBoundaryAllFalse: true,
    ...overrides,
  };
}

function adjudicate(overrides = {}) {
  return adjudicateReadback({
    projectId: PRODUCTION_PROJECT_ID,
    databaseId: PRODUCTION_DATABASE,
    location: PRODUCTION_LOCATION,
    policy,
    sourceBefore: sourceBinding(),
    sourceAfter: sourceBinding(),
    database: databaseSummary(),
    schedules: scheduleSummary(),
    backups: backupSummary(),
    operations: operationSummary(),
    restoreSeal: restoreSealSummary(),
    observe: false,
    ...overrides,
  });
}

test("strict acquisition passes while adverse recoverability posture remains explicit", () => {
  const result = adjudicate();
  assert.deepEqual(result.failedChecks, []);
  assert.equal(
    result.evidence.decision,
    "PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK",
  );
  assert.equal(
    result.evidence.posture.decision,
    "HOLD_FIRESTORE_RECOVERABILITY_POSTURE",
  );
  assert.deepEqual(result.evidence.posture.holds, [
    "pointInTimeRecoveryDisabled",
    "deleteProtectionDisabled",
    "noNativeBackupSchedule",
    "noNativeBackup",
    "noRestoreImportProof",
  ]);
  assert.equal(result.evidence.closureScope.lr04Closed, false);
  assert.equal(result.evidence.closureScope.p05Closed, false);
  assert.equal(result.evidence.closureScope.collectorAuthorizesClosure, false);
});

test("healthy fixture clears every posture hold without weakening acquisition", () => {
  const result = adjudicate({
    database: databaseSummary({
      pointInTimeRecoveryEnablement: "POINT_IN_TIME_RECOVERY_ENABLED",
      deleteProtectionState: "DELETE_PROTECTION_ENABLED",
    }),
    schedules: scheduleSummary({count: 1}),
    backups: backupSummary({count: 1, stateCounts: {READY: 1}}),
    operations: operationSummary({
      importOperationCount: 1,
      successfulImportOperationCount: 1,
    }),
  });
  assert.deepEqual(result.failedChecks, []);
  assert.deepEqual(result.evidence.posture.holds, []);
  assert.equal(
    result.evidence.posture.decision,
    "PASS_FIRESTORE_RECOVERABILITY_POSTURE",
  );
});

test("strict acquisition fails from dirty, detached, stale or changing source", () => {
  const dirty = adjudicate({
    sourceAfter: sourceBinding({governedWorktreeClean: false}),
  });
  assert.ok(dirty.failedChecks.includes("governedSourceClean"));

  const detached = adjudicate({
    sourceBefore: sourceBinding({branch: null}),
  });
  assert.ok(detached.failedChecks.includes("sourceBranchMain"));

  const stale = adjudicate({
    sourceAfter: sourceBinding({originMain: "e".repeat(40)}),
  });
  assert.ok(stale.failedChecks.includes("sourceCommitMatchesOriginMain"));

  const changed = adjudicate({
    sourceAfter: sourceBinding({commit: "f".repeat(40)}),
  });
  assert.ok(changed.failedChecks.includes("sourceBindingStable"));
});

test("wrong project, database or location is rejected before collection", () => {
  const base = [
    "--repository-root",
    repositoryRoot,
    "--project-id",
    PRODUCTION_PROJECT_ID,
    "--database",
    PRODUCTION_DATABASE,
    "--location",
    PRODUCTION_LOCATION,
    "--output",
    path.join(path.dirname(repositoryRoot), "receipt.json"),
  ];
  for (const [flag, value] of [
    ["--project-id", "wrong-project"],
    ["--database", "wrong-database"],
    ["--location", "wrong-location"],
  ]) {
    const args = [...base];
    args[args.indexOf(flag) + 1] = value;
    assert.throws(() => parseArgs(args), /Only the exact production/);
  }
});

test("operation inventory at the configured limit fails closed", () => {
  const result = adjudicate({
    operations: operationSummary({count: 1000, inventoryBelowLimit: false}),
  });
  assert.ok(result.failedChecks.includes("operationInventoryComplete"));
});

test("the exact sealed export must be present and independently reconfirmed", () => {
  const absent = adjudicate({
    operations: operationSummary({
      sealedExport: {
        ...operationSummary().sealedExport,
        appearsExactlyOnceInHistory: false,
      },
    }),
  });
  assert.ok(absent.failedChecks.includes("sealedExportReconfirmed"));

  const driftedSeal = adjudicate({
    restoreSeal: restoreSealSummary({exactFile: false}),
  });
  assert.ok(driftedSeal.failedChecks.includes("restoreSealExact"));
});

test("summaries omit schedule, backup, operation and output identifiers", () => {
  const scheduleName = `${expectedDatabaseName}/backupSchedules/private-schedule`;
  const backupName =
    `projects/${PRODUCTION_PROJECT_ID}/locations/${PRODUCTION_LOCATION}/backups/private-backup`;
  const operationName = `${expectedDatabaseName}/operations/private-operation`;
  const outputPrefix = "gs://private-bucket/private-prefix";
  const schedules = summarizeSchedules(
    [{name: scheduleName, dailyRecurrence: {}, retention: "604800s"}],
    expectedDatabaseName,
  );
  const backups = summarizeBackups(
    [
      {
        name: backupName,
        database: expectedDatabaseName,
        state: "READY",
        snapshotTime: "2026-08-04T00:00:00Z",
      },
    ],
    expectedDatabaseName,
  );
  const describedExport = {
    name: operationName,
    done: true,
    metadata: {
      "@type": exportType,
      operationState: "SUCCESSFUL",
      endTime: "2026-08-04T00:00:00Z",
    },
    response: {"@type": exportResponseType, outputUriPrefix: outputPrefix},
  };
  const operations = summarizeOperations({
    operations: [describedExport],
    describedExport,
    sealedOperationName: operationName,
    sealedOutputUriPrefix: outputPrefix,
    sealedCompletedAtUtc: "2026-08-04T00:00:00Z",
    inventoryLimit: 1000,
  });
  const rendered = JSON.stringify({schedules, backups, operations});
  for (const secret of [scheduleName, backupName, operationName, outputPrefix]) {
    assert.equal(rendered.includes(secret), false, secret);
  }
  assert.match(operations.sealedExport.operationNameSha256, /^[0-9A-F]{64}$/);
  assert.match(operations.sealedExport.outputUriPrefixSha256, /^[0-9A-F]{64}$/);
});

test("database summary drops UID, etag and unrelated service fields", () => {
  const summary = summarizeDatabase({
    name: expectedDatabaseName,
    locationId: PRODUCTION_LOCATION,
    type: "FIRESTORE_NATIVE",
    databaseEdition: "STANDARD",
    pointInTimeRecoveryEnablement: "POINT_IN_TIME_RECOVERY_DISABLED",
    deleteProtectionState: "DELETE_PROTECTION_DISABLED",
    uid: "private-uid",
    etag: "private-etag",
    appEngineIntegrationMode: "DISABLED",
  });
  assert.equal("uid" in summary, false);
  assert.equal("etag" in summary, false);
  assert.equal("appEngineIntegrationMode" in summary, false);
});

test("Windows gcloud uses the bundled Python entrypoint without a shell", () => {
  const resolved = resolveCommand(
    "C:\\sdk\\bin\\gcloud.cmd",
    ["firestore", "databases", "describe"],
    "win32",
  );
  assert.equal(resolved.command, "C:\\sdk\\platform\\bundledpython\\python.exe");
  assert.deepEqual(resolved.args.slice(0, 2), [
    "-S",
    "C:\\sdk\\lib\\gcloud.py",
  ]);
  assert.equal("shell" in resolved, false);
});

test("append-only receipt and mutation-free command boundary are source-enforced", () => {
  const source = fs.readFileSync(
    path.join(path.dirname(currentFile), "collectFirestoreRecoverabilityReadback.js"),
    "utf8",
  );
  for (const forbidden of [
    '"databases",\n      "update"',
    '"schedules",\n      "create"',
    '"schedules",\n      "update"',
    '"schedules",\n      "delete"',
    '"backups",\n      "delete"',
    '"operations",\n      "cancel"',
    "firestore import",
    "firestore export",
    "shell: true",
    "cmd.exe",
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
  for (const required of [
    '"databases",\n      "describe"',
    '"schedules",\n      "list"',
    '"backups",\n      "list"',
    '"operations",\n      "list"',
    '"operations",\n      "describe"',
    'flag: "wx"',
    "The append-only readback output must be outside the repository.",
  ]) {
    assert.ok(source.includes(required), required);
  }
});

test("the governed restore seal is byte-exact and mutation-free", () => {
  const loaded = loadRestoreSeal(repositoryRoot, policy);
  assert.equal(loaded.summary.exactFile, true);
  assert.equal(loaded.summary.fileSha256, policy.restoreSeal.sha256);
  assert.equal(loaded.summary.decision, policy.restoreSeal.decision);
  assert.equal(loaded.summary.mutationBoundaryAllFalse, true);
  assert.equal(loaded.summary.independentVerificationExact, true);
});
