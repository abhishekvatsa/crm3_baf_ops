import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { auditSourceCustody, extractApiKeys } = require("./firebase_client_api_key_custody.cjs");

const webKey = `AIza${"A".repeat(35)}`;
const androidKey = `AIza${"B".repeat(35)}`;
const iosKey = `AIza${"C".repeat(35)}`;
// Use only the checked-in non-credential fixture; never load production keys.
const emulatorKey = extractApiKeys(readFileSync(
  new URL("../../lib/core/dev/dev_environment.dart", import.meta.url), "utf8",
))[0];
const emulatorPaths = [
  "lib/core/dev/dev_environment.dart",
  "tool/dev/setup_dev.ps1",
  "tools/testing/run_ci_business_journeys.py",
];

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
      ...emulatorPaths,
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
      ...emulatorPaths.map((file) => [file, `emulator fixture: '${emulatorKey}'`]),
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
  assert.equal(serialized.includes(emulatorKey), false);
  assert.deepEqual(result.evidence.emulatorPlaceholderPaths, emulatorPaths);
  assert.deepEqual(result.evidence.emulatorPlaceholderOccurrenceCounts,
    Object.fromEntries(emulatorPaths.map((file) => [file, 1])));
  assert.equal(result.evidence.distinctKeySha256.length, 3);
});

for (const file of emulatorPaths) {
  test(`a production-shaped key copied into ${file} is not exempted`, () => {
    const inputs = validInputs();
    inputs.files.set(file, `${emulatorKey}\n${webKey}`);
    const result = auditSourceCustody(inputs);
    assert.ok(result.failedChecks.includes("keyPathsExact"));
    assert.ok(result.failedChecks.includes("emulatorPlaceholderOccurrences"));
  });

  test(`missing, untracked, replaced and duplicate placeholder fail for ${file}`, () => {
    for (const variant of ["missing", "untracked", "replaced", "duplicate", "extended", "prefixed"]) {
      const inputs = validInputs();
      if (variant === "missing") inputs.files.set(file, "no placeholder");
      if (variant === "untracked") inputs.trackedPaths.delete(file);
      if (variant === "replaced") inputs.files.set(file, `AIza${"D".repeat(35)}`);
      if (variant === "duplicate") inputs.files.set(file, `${emulatorKey}\n${emulatorKey}`);
      if (variant === "extended") inputs.files.set(file, `${emulatorKey}X`);
      if (variant === "prefixed") inputs.files.set(file, `X${emulatorKey}`);
      const result = auditSourceCustody(inputs);
      assert.equal(result.evidence.decision, "HOLD_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY");
      assert.ok(result.failedChecks.includes(variant === "untracked"
        ? "emulatorPlaceholderPathsTracked" : "emulatorPlaceholderOccurrences"));
    }
  });
}

test("the exact placeholder in an unapproved source still fails custody", () => {
  const inputs = validInputs();
  inputs.trackedPaths.add("tool/dev/unapproved_fixture.txt");
  inputs.files.set("tool/dev/unapproved_fixture.txt", emulatorKey);
  const result = auditSourceCustody(inputs);
  assert.ok(result.failedChecks.includes("keyPathsExact"));
  assert.ok(result.failedChecks.includes("distinctKeyCount"));
});

test("the placeholder cannot replace a production key even when counts stay exact", () => {
  const inputs = validInputs();
  for (const file of ["android/app/google-services.json", "lib/firebase_options.dart"]) {
    inputs.files.set(file, inputs.files.get(file).replaceAll(androidKey, emulatorKey));
  }
  const result = auditSourceCustody(inputs);
  assert.equal(result.evidence.checks.distinctKeyCount, true);
  assert.equal(result.evidence.checks.androidKeysBoundToFlutterOptions, true);
  assert.ok(result.failedChecks.includes("emulatorPlaceholderAbsentFromProduction"));
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
