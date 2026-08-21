import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const {
  createMutationPlan,
  executeCampaign,
  restrictionsSha256,
} = require("./apply_firebase_android_api_key_restrictions.cjs");

const androidName = "Android key (auto created by Firebase)";
const packageName = "in.co.sail.bsl.crm3.bafops";
const debugSha1 = "30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31";
const productionSha1 = "41C2B828C71683A50EC346D19E1D44048758438D";
const emptyHash = "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A";
const desiredHash = "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692";
const targets = ["firebase.googleapis.com", "identitytoolkit.googleapis.com"];

function policy() {
  return {
    liveReadback: {
      expectedKeys: [
        {
          displayName: androidName,
          applicationRestrictions: [
            { type: "android", entryCount: 2, valueSha256: desiredHash },
          ],
        },
        { displayName: "Browser key (auto created by Firebase)" },
        { displayName: "iOS key (auto created by Firebase)" },
      ],
      expectedApiTargets: targets,
      forbiddenApiTargets: ["generativelanguage.googleapis.com"],
    },
    androidPilotHardening: {
      displayName: androidName,
      allowedApplications: [
        { packageName, sha1Fingerprint: debugSha1 },
        { packageName, sha1Fingerprint: productionSha1 },
      ],
      acceptedPreMutationValueSha256: [emptyHash, desiredHash],
      automaticRollbackOnPostVerificationFailure: true,
    },
  };
}

function resources() {
  const apiTargets = targets.map((service) => ({ service }));
  return [
    {
      name: "projects/123/locations/global/keys/android-private-name",
      displayName: androidName,
      etag: "android-etag",
      restrictions: {
        apiTargets,
        androidKeyRestrictions: {},
      },
    },
    {
      name: "projects/123/locations/global/keys/browser-private-name",
      displayName: "Browser key (auto created by Firebase)",
      restrictions: { apiTargets, browserKeyRestrictions: {} },
    },
    {
      name: "projects/123/locations/global/keys/ios-private-name",
      displayName: "iOS key (auto created by Firebase)",
      restrictions: { apiTargets, iosKeyRestrictions: {} },
    },
  ];
}

function sourceBinding() {
  return {
    commit: "A".repeat(40),
    originMain: "A".repeat(40),
    policySha256: "B".repeat(64),
    governedWorktreeClean: true,
    materialChangeCount: 0,
    materialPathSha256: [],
  };
}

test("mutation plan preserves API targets and binds both approved certificates", () => {
  const plan = createMutationPlan(resources(), policy());
  assert.deepEqual(
    plan.desiredRestrictions.apiTargets,
    targets.map((service) => ({ service })),
  );
  assert.deepEqual(
    plan.desiredRestrictions.androidKeyRestrictions.allowedApplications,
    [
      { packageName, sha1Fingerprint: debugSha1 },
      { packageName, sha1Fingerprint: productionSha1 },
    ],
  );
  assert.equal(plan.desiredApplicationRestrictionSha256, desiredHash);
  const serialized = JSON.stringify(plan);
  assert.equal(serialized.includes("android-private-name"), true);
});

test("wrong package, certificate, or extra application fails before mutation", () => {
  const wrongPackage = policy();
  wrongPackage.androidPilotHardening.allowedApplications[0].packageName =
    "com.example.crm3_baf_ops";
  assert.throws(() => createMutationPlan(resources(), wrongPackage), /policy hash/);

  const wrongCertificate = policy();
  wrongCertificate.androidPilotHardening.allowedApplications[0].sha1Fingerprint =
    "F".repeat(40);
  assert.throws(
    () => createMutationPlan(resources(), wrongCertificate),
    /policy hash/,
  );

  const extraApplication = policy();
  extraApplication.androidPilotHardening.allowedApplications.push({
    packageName,
    sha1Fingerprint: "E".repeat(40),
  });
  assert.throws(
    () => createMutationPlan(resources(), extraApplication),
    /exactly two applications/,
  );
});

test("successful campaign mutates once and emits no resource identity", async () => {
  const inventory = resources();
  let android = structuredClone(inventory[0]);
  let patchCount = 0;
  const receipt = await executeCampaign({
    apply: true,
    listResources: async () => inventory,
    patchRestrictions: async ({ restrictions }) => {
      patchCount += 1;
      android = { ...android, restrictions: structuredClone(restrictions) };
    },
    policy: policy(),
    readResource: async () => android,
    sourceBinding: sourceBinding(),
  });
  assert.equal(receipt.status, "APPLIED_AND_VERIFIED");
  assert.equal(patchCount, 1);
  assert.equal(JSON.stringify(receipt).includes("private-name"), false);
  assert.equal(receipt.privacyBoundary.rawKeyValuesRead, false);
});

test("failed post-readback restores and verifies original restrictions", async () => {
  const inventory = resources();
  let android = structuredClone(inventory[0]);
  const originalHash = restrictionsSha256(android.restrictions);
  let patchCount = 0;
  let readCount = 0;
  await assert.rejects(
    executeCampaign({
      apply: true,
      listResources: async () => inventory,
      patchRestrictions: async ({ restrictions }) => {
        patchCount += 1;
        android = { ...android, restrictions: structuredClone(restrictions) };
      },
      policy: policy(),
      readResource: async () => {
        readCount += 1;
        if (readCount === 1) {
          return {
            ...android,
            restrictions: {
              ...android.restrictions,
              apiTargets: [
                ...android.restrictions.apiTargets,
                { service: "unexpected.googleapis.com" },
              ],
            },
          };
        }
        return android;
      },
      sourceBinding: sourceBinding(),
    }),
    (error) => {
      assert.equal(error.receipt.rollback.attempted, true);
      assert.equal(error.receipt.rollback.succeeded, true);
      return true;
    },
  );
  assert.equal(patchCount, 2);
  assert.equal(restrictionsSha256(android.restrictions), originalHash);
});
