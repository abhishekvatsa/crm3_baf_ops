import assert from "node:assert/strict";
import fs from "node:fs";
import {createRequire} from "node:module";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  PRODUCTION_PROJECT_ID,
  adjudicateReadback,
  listCompositeIndexes,
  sourceIndexSetBinding,
  summarizeIndexes,
  summarizeRules,
} = require("./collectFirestoreRulesIndexesReadback.js");

const sourceRule = "rules_version = '2';\nservice cloud.firestore { match /x/{id} { allow read: if false; } }\n";
const sourceIndex = {
  collectionGroup: "job_executions",
  queryScope: "COLLECTION",
  fields: [
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ],
};

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

function rulesSummary(activeContent = sourceRule) {
  return summarizeRules({
    projectId: PRODUCTION_PROJECT_ID,
    release: {
      name: `projects/${PRODUCTION_PROJECT_ID}/releases/cloud.firestore`,
      rulesetName: `projects/${PRODUCTION_PROJECT_ID}/rulesets/ruleset-1`,
    },
    ruleset: {
      createTime: "2026-08-04T00:00:00Z",
      source: {files: [{name: "firestore.rules", content: activeContent}]},
    },
    repositoryRules: sourceRule,
  });
}

function indexSummary({cliIndexes, apiIndexes, cliOverrides} = {}) {
  return summarizeIndexes({
    sourceDefinition: {indexes: [sourceIndex], fieldOverrides: []},
    cliDefinition: {
      indexes: cliIndexes ?? [sourceIndex],
      fieldOverrides: cliOverrides ?? [],
    },
    apiIndexes:
      apiIndexes ??
      [
        {
          ...sourceIndex,
          name:
            `projects/${PRODUCTION_PROJECT_ID}/databases/(default)/` +
            "collectionGroups/job_executions/indexes/index-1",
          state: "READY",
        },
      ],
    sourceRaw: JSON.stringify({indexes: [sourceIndex], fieldOverrides: []}),
  });
}

function adjudicate({
  before = sourceBinding(),
  after = sourceBinding(),
  rules = rulesSummary(),
  indexes = indexSummary(),
  observe = false,
} = {}) {
  return adjudicateReadback({
    projectId: PRODUCTION_PROJECT_ID,
    sourceBefore: before,
    sourceAfter: after,
    rules,
    indexes,
    observe,
  });
}

test("strict readback passes only exact Rules, index and main-source parity", () => {
  const result = adjudicate();
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.evidence.decision, "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK");
  assert.equal(result.evidence.outputs.indexes.apiReadyCount, 1);
  assert.equal(result.evidence.mutationBoundary.firestoreDocumentsRead, false);
});

test("Rules byte drift fails closed without retaining Rules content", () => {
  const marker = "LIVE_RULE_DRIFT_MARKER";
  const result = adjudicate({rules: rulesSummary(`${sourceRule}\n// ${marker}`)});
  assert.ok(result.failedChecks.includes("rulesByteExact"));
  assert.equal(result.evidence.decision, "HOLD_FIRESTORE_RULES_INDEXES_LIVE_READBACK");
  assert.equal(JSON.stringify(result.evidence).includes(marker), false);
});

test("CLI or API index drift fails closed", () => {
  const drifted = {...sourceIndex, collectionGroup: "other_collection"};
  const cliDrift = adjudicate({indexes: indexSummary({cliIndexes: [drifted]})});
  assert.ok(cliDrift.failedChecks.includes("cliIndexesMatchSource"));
  assert.ok(cliDrift.failedChecks.includes("apiIndexesMatchCli"));

  const apiDrift = adjudicate({
    indexes: indexSummary({apiIndexes: [{...drifted, state: "READY"}]}),
  });
  assert.ok(apiDrift.failedChecks.includes("apiIndexesMatchSource"));
});

test("source index binding rejects count-preserving identity substitutions", () => {
  const approved = sourceIndexSetBinding([sourceIndex]);
  const substituted = sourceIndexSetBinding([
    {...sourceIndex, collectionGroup: "other_collection"},
  ]);

  assert.equal(approved.count, substituted.count);
  assert.notEqual(approved.indexSetSha256, substituted.indexSetSha256);
  assert.match(approved.indexSetSha256, /^[0-9A-F]{64}$/);
  assert.throws(
    () => sourceIndexSetBinding([]),
    /source Firestore index inventory must be a nonempty array/,
  );
});

test("field-override drift and non-ready indexes fail closed", () => {
  const overrideDrift = adjudicate({
    indexes: indexSummary({
      cliOverrides: [{collectionGroup: "users", fieldPath: "email"}],
    }),
  });
  assert.ok(overrideDrift.failedChecks.includes("fieldOverridesMatchSource"));

  const creating = adjudicate({
    indexes: indexSummary({
      apiIndexes: [{...sourceIndex, state: "CREATING"}],
    }),
  });
  assert.ok(creating.failedChecks.includes("apiIndexesReady"));
});

test("strict readback cannot pass from dirty, detached or stale source", () => {
  const dirty = adjudicate({
    after: sourceBinding({
      governedWorktreeClean: false,
      materialChangeCount: 1,
      materialPathSha256: ["C".repeat(64)],
    }),
  });
  assert.ok(dirty.failedChecks.includes("governedSourceClean"));

  const stale = adjudicate({
    before: sourceBinding({branch: "feature", originMain: "d".repeat(40)}),
    after: sourceBinding({branch: "feature", originMain: "d".repeat(40)}),
  });
  assert.ok(stale.failedChecks.includes("sourceBranchMain"));
  assert.ok(stale.failedChecks.includes("sourceCommitMatchesOriginMain"));
});

test("observation mode reports evidence but can never authorize closure", () => {
  const result = adjudicate({observe: true});
  assert.deepEqual(result.failedChecks, []);
  assert.equal(
    result.evidence.decision,
    "OBSERVE_FIRESTORE_RULES_INDEXES_LIVE_READBACK",
  );
});

test("index pagination uses the API default and only sends continuation tokens", async () => {
  const requests = [];
  const client = {
    async get(endpoint) {
      requests.push(endpoint);
      return requests.length === 1
        ? {body: {indexes: [{name: "first"}], nextPageToken: "next-token"}}
        : {body: {indexes: [{name: "second"}]}};
    },
  };
  const indexes = await listCompositeIndexes(client, PRODUCTION_PROJECT_ID);
  assert.equal(indexes.length, 2);
  assert.deepEqual(requests, [
    `/projects/${PRODUCTION_PROJECT_ID}/databases/(default)/` +
      "collectionGroups/-/indexes",
    `/projects/${PRODUCTION_PROJECT_ID}/databases/(default)/` +
      "collectionGroups/-/indexes?pageToken=next-token",
  ]);
  assert.equal(requests.some((request) => request.includes("pageSize")), false);
});

test("collector source contains no production mutation route", () => {
  const currentFile = fileURLToPath(import.meta.url);
  const source = fs.readFileSync(
    path.join(path.dirname(currentFile), "collectFirestoreRulesIndexesReadback.js"),
    "utf8",
  );
  for (const forbidden of [
    ".post(",
    ".put(",
    ".patch(",
    ".delete(",
    "firebase deploy",
    "firestore:delete",
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
  assert.ok(source.includes("clients.rules.get("));
  assert.ok(source.includes("firestoreClient.get("));
  assert.ok(source.includes('"firestore:indexes"'));
});
