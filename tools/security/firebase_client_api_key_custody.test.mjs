import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { auditSourceCustody } = require("./firebase_client_api_key_custody.cjs");

const webKey = `AIza${"A".repeat(35)}`;
const androidKey = `AIza${"B".repeat(35)}`;
const iosKey = `AIza${"C".repeat(35)}`;

function policy() {
  return {
    schemaVersion: 1,
    policyId: "fixture",
    firebaseProjectId: "fixture-project",
    sourceCustody: {
      allowedTrackedPaths: [
        "android/app/google-services.json",
        "lib/firebase_options.dart",
      ],
      expectedDistinctKeyCount: 3,
      firebaseOptionsOccurrenceCount: 5,
      googleServicesOccurrenceCount: 2,
      googleServicesDistinctKeyCount: 1,
    },
  };
}

function validInputs() {
  return {
    policy: policy(),
    trackedPaths: new Set([
      "android/app/google-services.json",
      "lib/firebase_options.dart",
    ]),
    files: new Map([
      [
        "lib/firebase_options.dart",
        [webKey, androidKey, iosKey, iosKey, webKey]
          .map((key) => `apiKey: '${key}'`)
          .join("\n"),
      ],
      [
        "android/app/google-services.json",
        JSON.stringify({
          client: [
            { api_key: [{ current_key: androidKey }] },
            { api_key: [{ current_key: androidKey }] },
          ],
        }),
      ],
    ]),
  };
}

test("current generated Firebase configuration shape passes without raw values", () => {
  const result = auditSourceCustody(validInputs());
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.evidence.decision, "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY");
  const serialized = JSON.stringify(result.evidence);
  assert.equal(serialized.includes(webKey), false);
  assert.equal(serialized.includes(androidKey), false);
  assert.equal(serialized.includes(iosKey), false);
});

test("a key copied into any additional tracked file fails closed", () => {
  const inputs = validInputs();
  inputs.trackedPaths.add("tools/copied-key.txt");
  inputs.files.set("tools/copied-key.txt", webKey);
  const result = auditSourceCustody(inputs);
  assert.ok(result.failedChecks.includes("keyPathsExact"));
  assert.equal(result.evidence.decision, "HOLD_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY");
});

test("missing generated configuration and cross-platform drift fail closed", () => {
  const missing = validInputs();
  missing.files.delete("android/app/google-services.json");
  const missingResult = auditSourceCustody(missing);
  assert.ok(missingResult.failedChecks.includes("keyPathsExact"));
  assert.ok(missingResult.failedChecks.includes("googleServicesOccurrences"));

  const drift = validInputs();
  const unrelatedKey = `AIza${"D".repeat(35)}`;
  drift.files.set(
    "android/app/google-services.json",
    JSON.stringify({
      client: [
        { api_key: [{ current_key: unrelatedKey }] },
        { api_key: [{ current_key: unrelatedKey }] },
      ],
    }),
  );
  const driftResult = auditSourceCustody(drift);
  assert.ok(driftResult.failedChecks.includes("distinctKeyCount"));
  assert.ok(driftResult.failedChecks.includes("androidKeysBoundToFlutterOptions"));
});
