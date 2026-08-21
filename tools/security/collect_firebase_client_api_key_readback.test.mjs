import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { sha256 } = require("./firebase_client_api_key_custody.cjs");
const {
  adjudicateLiveReadback,
  applicationRestrictionEntryCounts,
  privacySafeLiveKey,
} = require("./collect_firebase_client_api_key_readback.cjs");

const rawKeys = [
  `AIza${"A".repeat(35)}`,
  `AIza${"B".repeat(35)}`,
  `AIza${"C".repeat(35)}`,
];
const names = ["Android key", "Browser key", "iOS key"];
const apiTargets = ["firebase.googleapis.com", "identitytoolkit.googleapis.com"];

function policy(expectedTargets = apiTargets) {
  return {
    schemaVersion: 1,
    policyId: "fixture",
    firebaseProjectId: "fixture-project",
    projectNumber: "123",
    liveReadback: {
      expectedKeys: names.map((displayName) => ({
        displayName,
        applicationRestrictions: [],
      })),
      expectedApiTargets: expectedTargets,
      forbiddenApiTargets: ["generativelanguage.googleapis.com"],
    },
  };
}

function sourceEvidence() {
  return {
    decision: "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY",
    distinctKeySha256: rawKeys.map(sha256),
  };
}

function sourceBinding() {
  return {
    commit: "a".repeat(40),
    originMain: "b".repeat(40),
    policySha256: "C".repeat(64),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
  };
}

function liveKeys(services = apiTargets) {
  return rawKeys.map((keyString, index) =>
    privacySafeLiveKey(
      {
        name: `projects/123/locations/global/keys/${index}`,
        displayName: names[index],
        restrictions: {
          apiTargets: services.map((service) => ({ service })),
        },
      },
      keyString,
    ),
  );
}

test("strict live readback binds source hashes and exact API restrictions", () => {
  const result = adjudicateLiveReadback({
    policy: policy(),
    sourceBinding: sourceBinding(),
    sourceEvidence: sourceEvidence(),
    liveKeys: liveKeys(),
    observe: false,
  });
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.evidence.decision, "PASS_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY");
  const serialized = JSON.stringify(result.evidence);
  for (const rawKey of rawKeys) assert.equal(serialized.includes(rawKey), false);
});

test("a non-Firebase target or changed application restriction fails closed", () => {
  const withForbiddenTarget = adjudicateLiveReadback({
    policy: policy(),
    sourceBinding: sourceBinding(),
    sourceEvidence: sourceEvidence(),
    liveKeys: liveKeys([...apiTargets, "generativelanguage.googleapis.com"]),
    observe: false,
  });
  assert.ok(withForbiddenTarget.failedChecks.includes("apiTargetsExact"));
  assert.ok(
    withForbiddenTarget.failedChecks.includes("forbiddenApiTargetsAbsent"),
  );

  const changedApplicationRestriction = liveKeys();
    changedApplicationRestriction[0].applicationRestrictionEntryCounts = [
      { type: "android", entryCount: 1 },
    ];
  const restrictionResult = adjudicateLiveReadback({
    policy: policy(),
    sourceBinding: sourceBinding(),
    sourceEvidence: sourceEvidence(),
    liveKeys: changedApplicationRestriction,
    observe: false,
  });
  assert.ok(
    restrictionResult.failedChecks.includes("applicationRestrictionShapeExact"),
  );

  const sameCountPolicy = policy();
  sameCountPolicy.liveReadback.expectedKeys[0].applicationRestrictions = [
    { type: "android", entryCount: 1, valueSha256: "A".repeat(64) },
  ];
  const sameCountDrift = liveKeys();
  sameCountDrift[0].applicationRestrictionEntryCounts = [
    { type: "android", entryCount: 1, valueSha256: "B".repeat(64) },
  ];
  const sameCountResult = adjudicateLiveReadback({
    policy: sameCountPolicy,
    sourceBinding: sourceBinding(),
    sourceEvidence: sourceEvidence(),
    liveKeys: sameCountDrift,
    observe: false,
  });
  assert.ok(
    sameCountResult.failedChecks.includes("applicationRestrictionShapeExact"),
  );
});

test("strict readback cannot pass from a materially dirty source tree", () => {
  const dirtySource = sourceBinding();
  dirtySource.governedWorktreeClean = false;
  dirtySource.materialChangeCount = 1;
  dirtySource.materialPathSha256 = ["D".repeat(64)];
  const result = adjudicateLiveReadback({
    policy: policy(),
    sourceBinding: dirtySource,
    sourceEvidence: sourceEvidence(),
    liveKeys: liveKeys(),
    observe: false,
  });
  assert.ok(result.failedChecks.includes("governedSourceClean"));
  assert.equal(result.evidence.decision, "HOLD_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY");
});

test("observation mode reports current services without granting PASS", () => {
  const result = adjudicateLiveReadback({
    policy: policy([]),
    sourceBinding: sourceBinding(),
    sourceEvidence: sourceEvidence(),
    liveKeys: liveKeys(),
    observe: true,
  });
  assert.equal(result.evidence.checks.apiTargetsExact, null);
  assert.equal(
    result.evidence.decision,
    "OBSERVE_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY",
  );
});

test("Android restriction hashing normalizes certificate punctuation and ordering", () => {
  const compact = applicationRestrictionEntryCounts({
    androidKeyRestrictions: {
      allowedApplications: [
        {
          packageName: "in.co.sail.bsl.crm3.bafops",
          sha1Fingerprint: "41C2B828C71683A50EC346D19E1D44048758438D",
        },
        {
          packageName: "in.co.sail.bsl.crm3.bafops",
          sha1Fingerprint: "30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31",
        },
      ],
    },
  });
  const punctuated = applicationRestrictionEntryCounts({
    androidKeyRestrictions: {
      allowedApplications: [
        {
          packageName: "in.co.sail.bsl.crm3.bafops",
          sha1Fingerprint:
            "30:B5:8F:0F:39:E1:BA:3C:A6:9F:D9:03:2D:7C:F6:FB:41:EC:8F:31",
        },
        {
          packageName: "in.co.sail.bsl.crm3.bafops",
          sha1Fingerprint:
            "41:C2:B8:28:C7:16:83:A5:0E:C3:46:D1:9E:1D:44:04:87:58:43:8D",
        },
      ],
    },
  });
  assert.deepEqual(compact, punctuated);
  assert.equal(
    compact[0].valueSha256,
    "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692",
  );
});
