"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const API_KEY_SOURCE = "AIza[0-9A-Za-z_-]{35}";

function normalizePath(value) {
  return value.replaceAll("\\", "/");
}

function sha256(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex").toUpperCase();
}

function extractApiKeys(source) {
  return source.match(new RegExp(API_KEY_SOURCE, "g")) ?? [];
}

function uniqueSorted(values) {
  return [...new Set(values)].sort();
}

function listTrackedPaths(repositoryRoot) {
  const output = execFileSync("git", ["ls-files", "-z"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  });
  return new Set(
    output
      .split("\0")
      .filter(Boolean)
      .map(normalizePath),
  );
}

function discoverTrackedKeyPaths(repositoryRoot) {
  let output;
  try {
    output = execFileSync(
      "git",
      ["grep", "-I", "-l", "-z", "-E", API_KEY_SOURCE, "--"],
      { cwd: repositoryRoot, encoding: "utf8" },
    );
  } catch (error) {
    if (error && error.status === 1) return [];
    throw error;
  }
  return output
    .split("\0")
    .filter(Boolean)
    .map(normalizePath)
    .sort();
}

function readRepositoryInputs(repositoryRoot, policy) {
  const trackedPaths = listTrackedPaths(repositoryRoot);
  const keyPaths = discoverTrackedKeyPaths(repositoryRoot);
  const requiredPaths = policy.sourceCustody.allowedTrackedPaths.map(normalizePath);
  const pathsToRead = uniqueSorted([...keyPaths, ...requiredPaths]);
  const files = new Map();
  for (const relativePath of pathsToRead) {
    const absolutePath = path.join(repositoryRoot, relativePath);
    if (fs.existsSync(absolutePath)) {
      files.set(relativePath, fs.readFileSync(absolutePath, "utf8"));
    }
  }
  return { files, trackedPaths };
}

function androidConfigKeys(source) {
  let parsed;
  try {
    parsed = JSON.parse(source);
  } catch {
    return null;
  }
  if (!Array.isArray(parsed.client)) return null;
  const keys = [];
  for (const client of parsed.client) {
    if (!Array.isArray(client.api_key)) return null;
    for (const entry of client.api_key) {
      if (typeof entry.current_key !== "string") return null;
      keys.push(entry.current_key);
    }
  }
  return keys;
}

function auditSourceCustody({ policy, files, trackedPaths }) {
  const sourcePolicy = policy.sourceCustody ?? {};
  const allowedPaths = uniqueSorted(
    (sourcePolicy.allowedTrackedPaths ?? []).map(normalizePath),
  );
  const keyInventory = [];
  for (const [relativePath, source] of files) {
    const keys = extractApiKeys(source);
    if (keys.length > 0) keyInventory.push({ relativePath, keys });
  }

  const discoveredPaths = keyInventory.map((entry) => entry.relativePath).sort();
  const firebaseOptionsPath = "lib/firebase_options.dart";
  const googleServicesPath = "android/app/google-services.json";
  const firebaseOptionsSource = files.get(firebaseOptionsPath) ?? "";
  const googleServicesSource = files.get(googleServicesPath) ?? "";
  const firebaseOptionsKeys = extractApiKeys(firebaseOptionsSource);
  const parsedGoogleServicesKeys = androidConfigKeys(googleServicesSource);
  const googleServicesKeys = parsedGoogleServicesKeys ?? [];
  const allKeys = keyInventory.flatMap((entry) => entry.keys);
  const distinctKeys = uniqueSorted(allKeys);
  const firebaseDistinctKeys = uniqueSorted(firebaseOptionsKeys);
  const googleServicesDistinctKeys = uniqueSorted(googleServicesKeys);

  const checks = {
    schemaVersion: policy.schemaVersion === 1,
    allowedPathPolicy:
      allowedPaths.length === 2 &&
      allowedPaths.includes(firebaseOptionsPath) &&
      allowedPaths.includes(googleServicesPath),
    allowedPathsTracked: allowedPaths.every((entry) => trackedPaths.has(entry)),
    keyPathsExact:
      JSON.stringify(discoveredPaths) === JSON.stringify(allowedPaths),
    firebaseOptionsOccurrences:
      firebaseOptionsKeys.length === sourcePolicy.firebaseOptionsOccurrenceCount,
    googleServicesJsonValid: parsedGoogleServicesKeys !== null,
    googleServicesOccurrences:
      googleServicesKeys.length === sourcePolicy.googleServicesOccurrenceCount,
    googleServicesDistinctKeys:
      googleServicesDistinctKeys.length ===
      sourcePolicy.googleServicesDistinctKeyCount,
    distinctKeyCount: distinctKeys.length === sourcePolicy.expectedDistinctKeyCount,
    androidKeysBoundToFlutterOptions: googleServicesDistinctKeys.every((key) =>
      firebaseDistinctKeys.includes(key),
    ),
  };
  const failedChecks = Object.entries(checks)
    .filter(([, passed]) => !passed)
    .map(([name]) => name);

  const evidence = {
    schemaVersion: 1,
    evidenceType: "firebase-client-api-key-source-custody",
    policyId: policy.policyId,
    firebaseProjectId: policy.firebaseProjectId,
    trackedKeyPaths: discoveredPaths,
    occurrenceCounts: Object.fromEntries(
      keyInventory.map((entry) => [entry.relativePath, entry.keys.length]),
    ),
    distinctKeySha256: distinctKeys.map(sha256).sort(),
    checks,
    privacyBoundary: {
      rawKeyValuesRetained: false,
      rawKeyValuesEmitted: false,
    },
    decision:
      failedChecks.length === 0
        ? "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY"
        : "HOLD_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY",
  };

  return { evidence, failedChecks };
}

function loadPolicy(repositoryRoot) {
  return JSON.parse(
    fs.readFileSync(
      path.join(repositoryRoot, "release", "firebase-client-api-key-policy.json"),
      "utf8",
    ),
  );
}

function runSourceCustody(repositoryRoot) {
  const policy = loadPolicy(repositoryRoot);
  const inputs = readRepositoryInputs(repositoryRoot, policy);
  const result = auditSourceCustody({ policy, ...inputs });
  if (result.failedChecks.length > 0) {
    throw new Error(
      `Firebase client API key source custody failed: ${result.failedChecks.join(", ")}`,
    );
  }
  return result.evidence;
}

module.exports = {
  API_KEY_SOURCE,
  auditSourceCustody,
  extractApiKeys,
  loadPolicy,
  readRepositoryInputs,
  runSourceCustody,
  sha256,
  uniqueSorted,
};

if (require.main === module) {
  try {
    const repositoryRoot = path.resolve(process.argv[2] || process.cwd());
    const evidence = runSourceCustody(repositoryRoot);
    console.log(
      "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY: " +
        `trackedPaths=${evidence.trackedKeyPaths.length} ` +
        `distinctKeys=${evidence.distinctKeySha256.length} rawValuesEmitted=false`,
    );
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
