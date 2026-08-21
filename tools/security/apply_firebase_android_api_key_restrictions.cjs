"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  applicationRestrictionEntryCounts,
  applicationRestrictionTypes,
  canonicalJson,
  collectSourceBinding,
  listKeyResources,
  normalizedApplicationRestriction,
  sameStrings,
} = require("./collect_firebase_client_api_key_readback.cjs");
const {
  loadPolicy,
  runSourceCustody,
  sha256,
  uniqueSorted,
} = require("./firebase_client_api_key_custody.cjs");

const ANDROID_KEY_DISPLAY_NAME = "Android key (auto created by Firebase)";

function parseArgs(argv) {
  const parsed = { apply: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--apply") {
      parsed.apply = true;
      continue;
    }
    if (argument === "--repository-root" || argument === "--output") {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`${argument} requires a value.`);
      }
      parsed[argument === "--repository-root" ? "repositoryRoot" : "output"] =
        value;
      index += 1;
      continue;
    }
    throw new Error(`Unsupported argument: ${argument}`);
  }
  if (!parsed.repositoryRoot) throw new Error("--repository-root is required.");
  if (!parsed.output) throw new Error("--output is required.");
  return parsed;
}

function normalizedApiTargets(restrictions) {
  return (restrictions.apiTargets ?? [])
    .map((target) => ({
      service: target.service,
      methods: uniqueSorted((target.methods ?? []).map(String)),
    }))
    .sort((left, right) => left.service.localeCompare(right.service));
}

function normalizedRestrictions(restrictions) {
  const normalized = {
    ...JSON.parse(JSON.stringify(restrictions ?? {})),
    apiTargets: normalizedApiTargets(restrictions ?? {}),
  };
  if (normalized.androidKeyRestrictions) {
    normalized.androidKeyRestrictions = normalizedApplicationRestriction(
      "android",
      normalized.androidKeyRestrictions,
    );
  }
  return normalized;
}

function restrictionsSha256(restrictions) {
  return sha256(canonicalJson(normalizedRestrictions(restrictions)));
}

function desiredAndroidRestriction(policy) {
  const campaign = policy.androidPilotHardening ?? {};
  if (campaign.displayName !== ANDROID_KEY_DISPLAY_NAME) {
    throw new Error("Android pilot policy has the wrong key display name.");
  }
  const allowedApplications = campaign.allowedApplications;
  if (!Array.isArray(allowedApplications) || allowedApplications.length !== 2) {
    throw new Error("Android pilot policy must contain exactly two applications.");
  }
  return normalizedApplicationRestriction("android", { allowedApplications });
}

function expectedAndroidRestriction(policy) {
  const expected = (policy.liveReadback?.expectedKeys ?? []).find(
    (entry) => entry.displayName === ANDROID_KEY_DISPLAY_NAME,
  );
  if (!expected || expected.applicationRestrictions?.length !== 1) {
    throw new Error("Live policy has no singular Android restriction contract.");
  }
  const restriction = expected.applicationRestrictions[0];
  if (restriction.type !== "android") {
    throw new Error("Live policy Android key has the wrong restriction type.");
  }
  return restriction;
}

function selectAndroidKey(resources, policy) {
  const active = resources.filter(
    (resource) =>
      !(typeof resource.deleteTime === "string" && resource.deleteTime.length > 0),
  );
  const expectedNames = (policy.liveReadback?.expectedKeys ?? []).map(
    (entry) => entry.displayName,
  );
  if (!sameStrings(active.map((resource) => resource.displayName), expectedNames)) {
    throw new Error("Active API key inventory does not match policy.");
  }
  const matches = active.filter(
    (resource) => resource.displayName === ANDROID_KEY_DISPLAY_NAME,
  );
  if (matches.length !== 1) {
    throw new Error("Android API key inventory is not singular.");
  }
  return matches[0];
}

function createMutationPlan(resources, policy) {
  const resource = selectAndroidKey(resources, policy);
  if (typeof resource.name !== "string" || resource.name.length === 0) {
    throw new Error("Android API key resource has no name.");
  }
  const restrictions = resource.restrictions ?? {};
  if (JSON.stringify(applicationRestrictionTypes(restrictions)) !== '["android"]') {
    throw new Error("Android API key has an unexpected application restriction type.");
  }

  const expectedTargets = policy.liveReadback?.expectedApiTargets ?? [];
  const currentTargets = normalizedApiTargets(restrictions);
  if (
    expectedTargets.length === 0 ||
    !sameStrings(
      currentTargets.map((target) => target.service),
      expectedTargets,
    ) ||
    currentTargets.some((target) => target.methods.length > 0)
  ) {
    throw new Error("Android API targets do not match the governed allowlist.");
  }
  const forbiddenTargets = new Set(
    policy.liveReadback?.forbiddenApiTargets ?? [],
  );
  if (currentTargets.some((target) => forbiddenTargets.has(target.service))) {
    throw new Error("Android API key contains a forbidden API target.");
  }

  const desiredAndroid = desiredAndroidRestriction(policy);
  const desiredRestrictions = JSON.parse(JSON.stringify(restrictions));
  desiredRestrictions.androidKeyRestrictions = desiredAndroid;
  const desiredSummary = applicationRestrictionEntryCounts(desiredRestrictions).find(
    (entry) => entry.type === "android",
  );
  const expectedSummary = expectedAndroidRestriction(policy);
  if (JSON.stringify(desiredSummary) !== JSON.stringify(expectedSummary)) {
    throw new Error("Android pilot policy hash does not match its application list.");
  }

  const currentSummary = applicationRestrictionEntryCounts(restrictions).find(
    (entry) => entry.type === "android",
  );
  const acceptedPreMutationHashes =
    policy.androidPilotHardening?.acceptedPreMutationValueSha256 ?? [];
  if (!acceptedPreMutationHashes.includes(currentSummary?.valueSha256)) {
    throw new Error("Android application restriction is outside the admitted state.");
  }

  return {
    resourceName: resource.name,
    etag: resource.etag,
    originalRestrictions: JSON.parse(JSON.stringify(restrictions)),
    desiredRestrictions,
    originalRestrictionsSha256: restrictionsSha256(restrictions),
    desiredRestrictionsSha256: restrictionsSha256(desiredRestrictions),
    desiredApplicationRestrictionSha256: desiredSummary.valueSha256,
    desiredApplicationCount: desiredSummary.entryCount,
    apiTargetCount: currentTargets.length,
  };
}

function verifyResource(resource, plan) {
  if (
    typeof resource.deleteTime === "string" &&
    resource.deleteTime.length > 0
  ) {
    throw new Error("Android API key became deleted during mutation.");
  }
  if (resource.displayName !== ANDROID_KEY_DISPLAY_NAME) {
    throw new Error("Android API key identity changed during mutation.");
  }
  if (restrictionsSha256(resource.restrictions) !== plan.desiredRestrictionsSha256) {
    throw new Error("Android API key post-readback does not match policy.");
  }
}

function campaignReceipt(plan, sourceBinding, status, rollback) {
  return {
    schemaVersion: 1,
    evidenceType: "firebase-android-api-key-pilot-hardening",
    source: sourceBinding,
    status,
    applicationRestriction: {
      entryCount: plan.desiredApplicationCount,
      valueSha256: plan.desiredApplicationRestrictionSha256,
    },
    restrictions: {
      beforeSha256: plan.originalRestrictionsSha256,
      targetSha256: plan.desiredRestrictionsSha256,
      apiTargetCount: plan.apiTargetCount,
      apiTargetsPreserved: true,
    },
    rollback,
    privacyBoundary: {
      rawKeyValuesRead: false,
      rawKeyValuesRetained: false,
      rawKeyValuesEmitted: false,
      resourceNameRetained: false,
      accountIdentityRetained: false,
    },
  };
}

async function executeCampaign({
  apply,
  listResources,
  patchRestrictions,
  policy,
  readResource,
  sourceBinding,
}) {
  const plan = createMutationPlan(await listResources(), policy);
  if (!apply) {
    return campaignReceipt(plan, sourceBinding, "DRY_RUN_READY", {
      attempted: false,
      succeeded: null,
    });
  }
  if (plan.originalRestrictionsSha256 === plan.desiredRestrictionsSha256) {
    return campaignReceipt(plan, sourceBinding, "ALREADY_COMPLIANT", {
      attempted: false,
      succeeded: null,
    });
  }

  let mutationAttempted = false;
  try {
    mutationAttempted = true;
    await patchRestrictions({
      resourceName: plan.resourceName,
      etag: plan.etag,
      restrictions: plan.desiredRestrictions,
    });
    verifyResource(await readResource(plan.resourceName), plan);
    return campaignReceipt(plan, sourceBinding, "APPLIED_AND_VERIFIED", {
      attempted: false,
      succeeded: null,
    });
  } catch {
    let rollbackAttempted = false;
    let rollbackSucceeded = false;
    if (mutationAttempted) {
      try {
        const current = await readResource(plan.resourceName);
        if (
          restrictionsSha256(current.restrictions) !==
          plan.originalRestrictionsSha256
        ) {
          rollbackAttempted = true;
          await patchRestrictions({
            resourceName: plan.resourceName,
            etag: current.etag,
            restrictions: plan.originalRestrictions,
          });
          const restored = await readResource(plan.resourceName);
          rollbackSucceeded =
            restrictionsSha256(restored.restrictions) ===
            plan.originalRestrictionsSha256;
        } else {
          rollbackSucceeded = true;
        }
      } catch {
        rollbackSucceeded = false;
      }
    }
    const error = new Error(
      rollbackSucceeded
        ? "Android API key mutation failed and original restrictions were verified."
        : "Android API key mutation failed and automatic restoration was not verified.",
    );
    error.receipt = campaignReceipt(plan, sourceBinding, "FAILED", {
      attempted: rollbackAttempted,
      succeeded: rollbackSucceeded,
    });
    throw error;
  }
}

async function waitForOperation(client, operation) {
  let current = operation;
  for (let attempt = 0; attempt < 60 && current?.done !== true; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const response = await client.get(`/${current.name}`);
    current = response.body;
  }
  if (current?.done !== true || current.error) {
    throw new Error("API key update operation did not complete successfully.");
  }
}

function createLiveAdapter(repositoryRoot, projectNumber) {
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
  if (!account) throw new Error("No authenticated Firebase CLI account is available.");
  auth.setActiveAccount({}, account);
  const client = new api.Client({
    urlPrefix: "https://apikeys.googleapis.com/v2",
  });
  return {
    listResources: () => listKeyResources(client, projectNumber),
    readResource: async (resourceName) =>
      (await client.get(`/${resourceName}`)).body,
    patchRestrictions: async ({ resourceName, etag, restrictions }) => {
      const body = { name: resourceName, restrictions };
      if (typeof etag === "string" && etag.length > 0) body.etag = etag;
      const response = await client.patch(`/${resourceName}`, body, {
        queryParams: { updateMask: "restrictions" },
      });
      await waitForOperation(client, response.body);
    },
  };
}

function writeReceipt(output, receipt) {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(
    output,
    `${JSON.stringify({ ...receipt, capturedAtUtc: new Date().toISOString() }, null, 2)}\n`,
    { encoding: "utf8", flag: "wx" },
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repositoryRoot = path.resolve(args.repositoryRoot);
  const output = path.resolve(args.output);
  if (fs.existsSync(output)) throw new Error(`Output already exists: ${output}`);
  const policy = loadPolicy(repositoryRoot);
  const sourceBinding = collectSourceBinding(repositoryRoot);
  const sourceEvidence = runSourceCustody(repositoryRoot);
  if (
    !sourceBinding.governedWorktreeClean ||
    sourceBinding.commit !== sourceBinding.originMain ||
    sourceEvidence.decision !== "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY"
  ) {
    throw new Error("Governed source precheck failed.");
  }
  const adapter = createLiveAdapter(repositoryRoot, policy.projectNumber);
  try {
    const receipt = await executeCampaign({
      apply: args.apply,
      policy,
      sourceBinding,
      ...adapter,
    });
    writeReceipt(output, receipt);
    console.log(JSON.stringify(receipt, null, 2));
  } catch (error) {
    if (error.receipt) writeReceipt(output, error.receipt);
    throw error;
  }
}

module.exports = {
  createMutationPlan,
  executeCampaign,
  normalizedApiTargets,
  normalizedRestrictions,
  parseArgs,
  restrictionsSha256,
  verifyResource,
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
