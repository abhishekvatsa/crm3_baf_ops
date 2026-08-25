"use strict";

const childProcess = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {
  canonicalJson,
  normalizeIndex,
  sealReceipt,
} = require("./collectProductionGlobalPullBackend.js");

const PRODUCTION_PROJECT_ID = "crm3-baf-ops-b8638";
const RULES_RELEASE = `projects/${PRODUCTION_PROJECT_ID}/releases/cloud.firestore`;
const IGNORED_WORKTREE_PREFIXES = Object.freeze([
  ".claude/",
  "output/",
  "tmp/",
]);

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex").toUpperCase();
}

function parseArgs(argv) {
  const options = {observe: false};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--observe") {
      options.observe = true;
      continue;
    }
    const fields = {
      "--repository-root": "repositoryRoot",
      "--project-id": "projectId",
      "--output": "outputPath",
    };
    const field = fields[argument];
    if (field == null) fail(`Unsupported argument: ${argument}`);
    if (options[field] != null) fail(`Duplicate argument: ${argument}`);
    const value = argv[index + 1];
    if (value == null || value.startsWith("--")) {
      fail(`${argument} requires a value.`);
    }
    options[field] = value;
    index += 1;
  }
  for (const field of ["repositoryRoot", "projectId", "outputPath"]) {
    if (options[field] == null) fail(`Missing required argument for ${field}.`);
  }
  options.repositoryRoot = path.resolve(options.repositoryRoot);
  options.outputPath = path.resolve(options.outputPath);
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    fail(`Only the exact production project ${PRODUCTION_PROJECT_ID} is supported.`);
  }
  return options;
}

function isPathInside(parentPath, candidatePath) {
  const relative = path.relative(path.resolve(parentPath), path.resolve(candidatePath));
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function runText(command, args, options = {}) {
  return childProcess
    .execFileSync(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        FIREBASE_CLI_DISABLE_UPDATE_CHECK: "true",
      },
      maxBuffer: 64 * 1024 * 1024,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    })
    .trim();
}

function gitValue(repositoryRoot, args) {
  return runText("git", ["-C", repositoryRoot, ...args]);
}

function collectSourceBinding(repositoryRoot) {
  const statusLines = gitValue(repositoryRoot, [
    "status",
    "--porcelain=v1",
    "--untracked-files=all",
  ])
    .split(/\r?\n/)
    .filter(Boolean);
  const materialPaths = statusLines
    .map((line) => line.slice(3).trim().replaceAll("\\", "/"))
    .filter(
      (relativePath) =>
        !IGNORED_WORKTREE_PREFIXES.some((prefix) => relativePath.startsWith(prefix)),
    );
  let branch = null;
  let originMain = null;
  try {
    branch = gitValue(repositoryRoot, ["symbolic-ref", "--short", "HEAD"]);
  } catch {
    branch = null;
  }
  try {
    originMain = gitValue(repositoryRoot, ["rev-parse", "origin/main"]);
  } catch {
    originMain = null;
  }
  return {
    branch,
    commit: gitValue(repositoryRoot, ["rev-parse", "HEAD"]),
    tree: gitValue(repositoryRoot, ["rev-parse", "HEAD^{tree}"]),
    originMain,
    governedWorktreeClean: materialPaths.length === 0,
    materialChangeCount: materialPaths.length,
    materialPathSha256: materialPaths.map(sha256).sort(),
  };
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

function normalizedIndexSet(indexes) {
  return indexes.map(normalizeIndex).map(canonicalJson).sort();
}

function normalizedObjectSet(values) {
  return values.map(canonicalJson).sort();
}

function setDigest(values) {
  return sha256(canonicalJson(values));
}

function sourceIndexSetBinding(indexes) {
  if (!Array.isArray(indexes) || indexes.length === 0) {
    fail("The source Firestore index inventory must be a nonempty array.");
  }
  const normalized = normalizedIndexSet(indexes);
  return {count: normalized.length, indexSetSha256: setDigest(normalized)};
}

function summarizeRules({projectId, release, ruleset, repositoryRules}) {
  const matchingFiles = (ruleset?.source?.files ?? []).filter(
    (file) => file?.name === "firestore.rules",
  );
  const activeContent = matchingFiles.length === 1 ? matchingFiles[0].content : null;
  return {
    releaseName: release?.name ?? null,
    expectedReleaseName: `projects/${projectId}/releases/cloud.firestore`,
    rulesetName: release?.rulesetName ?? null,
    rulesetCreateTime: ruleset?.createTime ?? null,
    rulesFileMatchCount: matchingFiles.length,
    sourceByteCount: Buffer.byteLength(repositoryRules, "utf8"),
    activeByteCount:
      typeof activeContent === "string"
        ? Buffer.byteLength(activeContent, "utf8")
        : null,
    sourceSha256: sha256(repositoryRules),
    activeSha256: typeof activeContent === "string" ? sha256(activeContent) : null,
    byteExact: activeContent === repositoryRules,
  };
}

function summarizeIndexes({sourceDefinition, cliDefinition, apiIndexes, sourceRaw}) {
  const sourceIndexes = sourceDefinition?.indexes ?? [];
  const cliIndexes = cliDefinition?.indexes ?? [];
  const sourceOverrides = sourceDefinition?.fieldOverrides ?? [];
  const cliOverrides = cliDefinition?.fieldOverrides ?? [];
  const sourceSet = normalizedIndexSet(sourceIndexes);
  const cliSet = normalizedIndexSet(cliIndexes);
  const apiSet = normalizedIndexSet(apiIndexes);
  const sourceOverrideSet = normalizedObjectSet(sourceOverrides);
  const cliOverrideSet = normalizedObjectSet(cliOverrides);
  const states = {};
  for (const index of apiIndexes) {
    const state = typeof index?.state === "string" ? index.state : "MISSING";
    states[state] = (states[state] ?? 0) + 1;
  }
  return {
    sourceFileSha256: sha256(sourceRaw),
    sourceCount: sourceSet.length,
    cliCount: cliSet.length,
    apiCount: apiSet.length,
    apiReadyCount: states.READY ?? 0,
    apiStateCounts: Object.fromEntries(
      Object.entries(states).sort(([left], [right]) => left.localeCompare(right)),
    ),
    sourceSetSha256: setDigest(sourceSet),
    cliSetSha256: setDigest(cliSet),
    apiSetSha256: setDigest(apiSet),
    cliMatchesSource: canonicalJson(cliSet) === canonicalJson(sourceSet),
    apiMatchesSource: canonicalJson(apiSet) === canonicalJson(sourceSet),
    apiMatchesCli: canonicalJson(apiSet) === canonicalJson(cliSet),
    sourceFieldOverrideCount: sourceOverrideSet.length,
    cliFieldOverrideCount: cliOverrideSet.length,
    sourceFieldOverrideSha256: setDigest(sourceOverrideSet),
    cliFieldOverrideSha256: setDigest(cliOverrideSet),
    fieldOverridesMatchSource:
      canonicalJson(cliOverrideSet) === canonicalJson(sourceOverrideSet),
    allApiIndexesReady:
      apiSet.length > 0 && apiIndexes.every((index) => index?.state === "READY"),
  };
}

function adjudicateReadback({
  projectId,
  sourceBefore,
  sourceAfter,
  rules,
  indexes,
  observe,
}) {
  const checks = {
    productionProjectExact: projectId === PRODUCTION_PROJECT_ID,
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
    activeRulesReleaseExact:
      rules.releaseName === rules.expectedReleaseName &&
      rules.releaseName === RULES_RELEASE,
    activeRulesetIdentified:
      typeof rules.rulesetName === "string" &&
      rules.rulesetName.startsWith(`projects/${projectId}/rulesets/`) &&
      typeof rules.rulesetCreateTime === "string",
    rulesFileUnique: rules.rulesFileMatchCount === 1,
    rulesByteExact:
      rules.byteExact &&
      rules.activeSha256 === rules.sourceSha256 &&
      rules.activeByteCount === rules.sourceByteCount,
    sourceIndexesPresent: indexes.sourceCount > 0,
    indexCountsExact:
      indexes.sourceCount === indexes.cliCount &&
      indexes.sourceCount === indexes.apiCount,
    cliIndexesMatchSource:
      indexes.cliMatchesSource &&
      indexes.cliSetSha256 === indexes.sourceSetSha256,
    apiIndexesMatchSource:
      indexes.apiMatchesSource &&
      indexes.apiSetSha256 === indexes.sourceSetSha256,
    apiIndexesMatchCli:
      indexes.apiMatchesCli && indexes.apiSetSha256 === indexes.cliSetSha256,
    apiIndexesReady:
      indexes.allApiIndexesReady &&
      indexes.apiReadyCount === indexes.apiCount,
    fieldOverridesMatchSource:
      indexes.fieldOverridesMatchSource &&
      indexes.sourceFieldOverrideCount === indexes.cliFieldOverrideCount &&
      indexes.sourceFieldOverrideSha256 === indexes.cliFieldOverrideSha256,
  };
  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value === false)
    .map(([name]) => name);
  const decision = observe
    ? "OBSERVE_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
    : failedChecks.length === 0
      ? "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
      : "HOLD_FIRESTORE_RULES_INDEXES_LIVE_READBACK";
  return {
    failedChecks,
    evidence: {
      schemaVersion: 1,
      evidenceType: "firestore-rules-indexes-live-readback",
      mode: observe ? "OBSERVE" : "STRICT",
      projectId,
      source: {
        before: sourceBefore,
        after: sourceAfter,
      },
      commands: [
        {kind: "LOCAL_READ", command: "git status/rev-parse"},
        {kind: "HTTPS_GET", endpoint: `/${RULES_RELEASE}`},
        {kind: "HTTPS_GET", endpoint: "/projects/{project}/rulesets/{ruleset}"},
        {
          kind: "CLI_READ",
          command: `firebase firestore:indexes --project ${projectId} --json`,
        },
        {
          kind: "HTTPS_GET",
          endpoint:
            `/projects/${projectId}/databases/(default)/` +
            "collectionGroups/-/indexes",
          paginated: true,
        },
      ],
      outputs: {rules, indexes},
      checks,
      mutationBoundary: {
        firestoreRulesDeployed: false,
        firestoreIndexesDeployed: false,
        firestoreDocumentsRead: false,
        firestoreDocumentsWritten: false,
        functionsMutated: false,
        iamMutated: false,
        appCheckMutated: false,
        businessDataMutated: false,
      },
      privacyBoundary: {
        rulesContentRetained: false,
        indexDefinitionsRetained: false,
        accountIdentityRetained: false,
        sourceMaterialRepresentedByHashesAndCountsOnly: true,
      },
      failedChecks,
      decision,
    },
  };
}

async function collectLiveState(options) {
  const clients = await createApiClients(options.repositoryRoot);
  const release = (
    await clients.rules.get(`/projects/${options.projectId}/releases/cloud.firestore`)
  ).body;
  const ruleset = (await clients.rules.get(`/${release.rulesetName}`)).body;
  const repositoryRules = fs.readFileSync(
    path.join(options.repositoryRoot, "firestore.rules"),
    "utf8",
  );
  const sourceIndexPath = path.join(
    options.repositoryRoot,
    "firestore.indexes.json",
  );
  const sourceRaw = fs.readFileSync(sourceIndexPath, "utf8");
  const sourceDefinition = JSON.parse(sourceRaw);
  const cliDefinition = firebaseJson(options.repositoryRoot, [
    "firestore:indexes",
    "--project",
    options.projectId,
  ]);
  const apiIndexes = await listCompositeIndexes(
    clients.firestore,
    options.projectId,
  );
  return {
    rules: summarizeRules({
      projectId: options.projectId,
      release,
      ruleset,
      repositoryRules,
    }),
    indexes: summarizeIndexes({
      sourceDefinition,
      cliDefinition,
      apiIndexes,
      sourceRaw,
    }),
  };
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv[0] === "--source-index-set") {
    if (argv.length !== 2) {
      fail("--source-index-set requires exactly one source index file.");
    }
    const source = JSON.parse(fs.readFileSync(path.resolve(argv[1]), "utf8"));
    process.stdout.write(`${JSON.stringify(sourceIndexSetBinding(source.indexes))}\n`);
    return;
  }
  const options = parseArgs(argv);
  if (isPathInside(options.repositoryRoot, options.outputPath)) {
    fail("The append-only readback output must be outside the repository.");
  }
  if (fs.existsSync(options.outputPath)) {
    fail(`Output already exists: ${options.outputPath}`);
  }
  const sourceBefore = collectSourceBinding(options.repositoryRoot);
  const live = await collectLiveState(options);
  const sourceAfter = collectSourceBinding(options.repositoryRoot);
  const result = adjudicateReadback({
    projectId: options.projectId,
    sourceBefore,
    sourceAfter,
    rules: live.rules,
    indexes: live.indexes,
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
      outputPath: options.outputPath,
      receiptSha256: receipt.receiptSha256,
      failedChecks: receipt.failedChecks,
    })}\n`,
  );
  if (!options.observe && result.failedChecks.length > 0) process.exitCode = 1;
}

module.exports = {
  PRODUCTION_PROJECT_ID,
  adjudicateReadback,
  collectSourceBinding,
  isPathInside,
  listCompositeIndexes,
  normalizedIndexSet,
  parseArgs,
  sha256,
  sourceIndexSetBinding,
  summarizeIndexes,
  summarizeRules,
};

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`FIRESTORE_RULES_INDEXES_READBACK_FAILED: ${error.message}\n`);
    process.exitCode = 1;
  });
}
