"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const {
  API_KEY_SOURCE,
  loadPolicy,
  runSourceCustody,
  sha256,
  uniqueSorted,
} = require("./firebase_client_api_key_custody.cjs");

function parseArgs(argv) {
  const parsed = { observe: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--observe") {
      parsed.observe = true;
      continue;
    }
    if (argument === "--repository-root" || argument === "--output") {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`${argument} requires a value.`);
      }
      parsed[argument === "--repository-root" ? "repositoryRoot" : "output"] = value;
      index += 1;
      continue;
    }
    throw new Error(`Unsupported argument: ${argument}`);
  }
  if (!parsed.repositoryRoot) throw new Error("--repository-root is required.");
  if (!parsed.output) throw new Error("--output is required.");
  return parsed;
}

function applicationRestrictionTypes(restrictions) {
  const candidates = [
    ["android", restrictions.androidKeyRestrictions],
    ["browser", restrictions.browserKeyRestrictions],
    ["ios", restrictions.iosKeyRestrictions],
    ["server", restrictions.serverKeyRestrictions],
  ];
  return candidates
    .filter(([, value]) => value && typeof value === "object")
    .map(([name]) => name)
    .sort();
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value).sort(([left], [right]) =>
      left.localeCompare(right),
    );
    return `{${entries
      .map(([key, entry]) => `${JSON.stringify(key)}:${canonicalJson(entry)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function applicationRestrictionEntryCounts(restrictions) {
  const candidates = [
    ["android", restrictions.androidKeyRestrictions, "allowedApplications"],
    ["browser", restrictions.browserKeyRestrictions, "allowedReferrers"],
    ["ios", restrictions.iosKeyRestrictions, "allowedBundleIds"],
    ["server", restrictions.serverKeyRestrictions, "allowedIps"],
  ];
  return candidates
    .filter(([, value]) => value && typeof value === "object")
    .map(([type, value, field]) => ({
      type,
      entryCount: Array.isArray(value[field]) ? value[field].length : 0,
      valueSha256: sha256(canonicalJson(value)),
    }))
    .sort((left, right) => left.type.localeCompare(right.type));
}

function privacySafeLiveKey(resource, keyString) {
  if (typeof resource?.name !== "string" || resource.name.length === 0) {
    throw new Error("API key resource is missing its name.");
  }
  if (typeof resource.displayName !== "string" || resource.displayName.length === 0) {
    throw new Error("API key resource is missing its display name.");
  }
  if (!new RegExp(`^${API_KEY_SOURCE}$`).test(keyString)) {
    throw new Error("API key string has an invalid Firebase client-key shape.");
  }
  const restrictions = resource.restrictions ?? {};
  const apiTargets = (restrictions.apiTargets ?? []).map((target) => {
    if (typeof target?.service !== "string" || target.service.length === 0) {
      throw new Error("API key restriction contains a malformed API target.");
    }
    const methods = Array.isArray(target.methods)
      ? uniqueSorted(target.methods.map(String))
      : [];
    return { service: target.service, methods };
  });
  apiTargets.sort((left, right) => left.service.localeCompare(right.service));
  return {
    resourceNameSha256: sha256(resource.name),
    keyStringSha256: sha256(keyString),
    displayName: resource.displayName,
    apiTargets,
    applicationRestrictionTypes: applicationRestrictionTypes(restrictions),
    applicationRestrictionEntryCounts:
      applicationRestrictionEntryCounts(restrictions),
    deleted: typeof resource.deleteTime === "string" && resource.deleteTime.length > 0,
  };
}

function sameStrings(left, right) {
  return JSON.stringify(uniqueSorted(left)) === JSON.stringify(uniqueSorted(right));
}

function gitValue(repositoryRoot, args) {
  return execFileSync("git", args, {
    cwd: repositoryRoot,
    encoding: "utf8",
  }).trim();
}

function collectSourceBinding(repositoryRoot) {
  const ignoredPrefixes = [".claude/", "output/", "tmp/"];
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
        !ignoredPrefixes.some((prefix) => relativePath.startsWith(prefix)),
    );
  let originMain = null;
  try {
    originMain = gitValue(repositoryRoot, ["rev-parse", "origin/main"]);
  } catch {
    originMain = null;
  }
  const policySource = fs.readFileSync(
    path.join(repositoryRoot, "release", "firebase-client-api-key-policy.json"),
    "utf8",
  );
  return {
    commit: gitValue(repositoryRoot, ["rev-parse", "HEAD"]),
    originMain,
    policySha256: sha256(policySource),
    governedWorktreeClean: materialPaths.length === 0,
    materialChangeCount: materialPaths.length,
    materialPathSha256: materialPaths.map(sha256).sort(),
  };
}

function adjudicateLiveReadback({
  policy,
  sourceBinding,
  sourceEvidence,
  liveKeys,
  observe,
}) {
  const livePolicy = policy.liveReadback ?? {};
  const expectedKeys = livePolicy.expectedKeys ?? [];
  const expectedNames = expectedKeys.map((key) => key.displayName);
  const expectedTargets = livePolicy.expectedApiTargets ?? [];
  const forbiddenTargets = new Set(livePolicy.forbiddenApiTargets ?? []);
  const sourceHashes = sourceEvidence.distinctKeySha256 ?? [];
  const liveHashes = liveKeys.map((key) => key.keyStringSha256);
  const allApiTargets = liveKeys.flatMap((key) =>
    key.apiTargets.map((target) => target.service),
  );

  const checks = {
    schemaVersion: policy.schemaVersion === 1,
    governedSourceClean: observe ? null : sourceBinding.governedWorktreeClean,
    sourceCustody:
      sourceEvidence.decision === "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY",
    keyCount: liveKeys.length === expectedNames.length,
    displayNamesExact: sameStrings(
      liveKeys.map((key) => key.displayName),
      expectedNames,
    ),
    sourceKeySetExact: sameStrings(liveHashes, sourceHashes),
    keysActive: liveKeys.every((key) => !key.deleted),
    apiTargetsExact: observe
      ? null
      : expectedTargets.length > 0 &&
        liveKeys.every((key) =>
          sameStrings(
            key.apiTargets.map((target) => target.service),
            expectedTargets,
          ),
        ),
    apiMethodsUnscoped: liveKeys.every((key) =>
      key.apiTargets.every((target) => target.methods.length === 0),
    ),
    forbiddenApiTargetsAbsent: allApiTargets.every(
      (service) => !forbiddenTargets.has(service),
    ),
    applicationRestrictionShapeExact: liveKeys.every((key) => {
      const expected = expectedKeys.find(
        (entry) => entry.displayName === key.displayName,
      );
      return (
        expected &&
        JSON.stringify(key.applicationRestrictionEntryCounts) ===
          JSON.stringify(expected.applicationRestrictions)
      );
    }),
  };
  const failedChecks = Object.entries(checks)
    .filter(([, value]) => value === false)
    .map(([name]) => name);
  const decision = observe
    ? "OBSERVE_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY"
    : failedChecks.length === 0
      ? "PASS_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY"
      : "HOLD_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY";

  return {
    evidence: {
      schemaVersion: 1,
      evidenceType: "firebase-client-api-key-live-custody",
      policyId: policy.policyId,
      firebaseProjectId: policy.firebaseProjectId,
      projectNumber: policy.projectNumber,
      mode: observe ? "OBSERVE" : "STRICT",
      source: sourceBinding,
      keys: [...liveKeys].sort((left, right) =>
        left.displayName.localeCompare(right.displayName),
      ),
      checks,
      privacyBoundary: {
        clientApiKeyValuesReadForHashBinding: true,
        rawKeyValuesRetained: false,
        rawKeyValuesEmitted: false,
        accountIdentityRetained: false,
      },
      decision,
    },
    failedChecks,
  };
}

async function listKeyResources(client, projectNumber) {
  const resources = [];
  let pageToken = null;
  do {
    const query = new URLSearchParams({ pageSize: "100" });
    if (pageToken) query.set("pageToken", pageToken);
    const response = await client.get(
      `/projects/${projectNumber}/locations/global/keys?${query.toString()}`,
    );
    resources.push(...(response.body.keys ?? []));
    pageToken = response.body.nextPageToken ?? null;
  } while (pageToken);
  return resources;
}

async function collectLiveKeys(repositoryRoot, projectNumber) {
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
  const resources = await listKeyResources(client, projectNumber);
  const keys = [];
  for (const resource of resources) {
    const response = await client.get(`/${resource.name}/keyString`);
    keys.push(privacySafeLiveKey(resource, response.body.keyString));
  }
  return keys;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repositoryRoot = path.resolve(args.repositoryRoot);
  const output = path.resolve(args.output);
  if (fs.existsSync(output)) throw new Error(`Output already exists: ${output}`);
  const policy = loadPolicy(repositoryRoot);
  const sourceBinding = collectSourceBinding(repositoryRoot);
  const sourceEvidence = runSourceCustody(repositoryRoot);
  const liveKeys = await collectLiveKeys(repositoryRoot, policy.projectNumber);
  const result = adjudicateLiveReadback({
    policy,
    sourceBinding,
    sourceEvidence,
    liveKeys,
    observe: args.observe,
  });
  const receipt = {
    ...result.evidence,
    capturedAtUtc: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  console.log(JSON.stringify(receipt, null, 2));
  if (!args.observe && result.failedChecks.length > 0) {
    process.exitCode = 1;
  }
}

module.exports = {
  adjudicateLiveReadback,
  applicationRestrictionEntryCounts,
  applicationRestrictionTypes,
  canonicalJson,
  collectSourceBinding,
  parseArgs,
  privacySafeLiveKey,
  sameStrings,
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
