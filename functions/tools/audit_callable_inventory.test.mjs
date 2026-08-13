import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  auditCallableInventory,
} from "./audit_callable_inventory.mjs";

test("current exported callable inventory and policy are exact", () => {
  const result = auditCallableInventory();
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.exportedNames, [
    "assignPublishedTemplateVersion",
    "beginGlobalPullRun",
    "completePlannedJobExecution",
    "executeMaintenanceWorkflowCommand",
    "getBackendReleaseIdentity",
    "mutateAssetHierarchy",
    "mutateChargeAbnormality",
    "mutateRuntimeJobModulePopulation",
    "mutateUserAuthority",
  ]);
  assert.deepEqual(result.mutatingNames, [
    "assignPublishedTemplateVersion",
    "completePlannedJobExecution",
    "executeMaintenanceWorkflowCommand",
    "mutateAssetHierarchy",
    "mutateChargeAbnormality",
    "mutateRuntimeJobModulePopulation",
    "mutateUserAuthority",
  ]);
  assert.deepEqual(result.readOnlyNames, [
    "beginGlobalPullRun",
    "getBackendReleaseIdentity",
  ]);
});

test("a newly exported callable is discovered and fails closed", (context) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-callables-"));
  context.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const src = path.join(root, "src");
  fs.mkdirSync(src);
  fs.writeFileSync(
    path.join(root, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {module: "commonjs", target: "es2022"},
      include: ["src"],
    }),
  );
  fs.writeFileSync(
    path.join(src, "callableInventory.ts"),
    [
      "export const CALLABLE_SECURITY_CLASSIFICATION = {",
      '  knownMutation: "mutating",',
      "} as const;",
    ].join("\n"),
  );
  fs.writeFileSync(
    path.join(src, "index.ts"),
    [
      "declare function onCall(options: object, handler: Function): Function;",
      "declare function executeAuthorizedMutation(args: object): unknown;",
      "const MUTATING_CALLABLE_SECURITY_OPTIONS = {};",
      "export const knownMutation = onCall(",
      "  {...MUTATING_CALLABLE_SECURITY_OPTIONS},",
      "  async () => executeAuthorizedMutation({",
      '    callableName: "knownMutation",',
      "  }),",
      ");",
      "export const newlyAddedMutation = onCall({}, async () => null);",
    ].join("\n"),
  );
  const policyPath = path.join(root, "policy.json");
  fs.writeFileSync(
    policyPath,
    JSON.stringify({
      callableAppCheckPolicy: {
        mutatingSecurityOptionsExport:
          "MUTATING_CALLABLE_SECURITY_OPTIONS",
        mutatingCallables: ["knownMutation"],
        readOnlySecurityOptionsByCallable: {},
      },
    }),
  );

  const result = auditCallableInventory({
    tsconfigPath: path.join(root, "tsconfig.json"),
    entrypointPath: path.join(src, "index.ts"),
    classificationPath: path.join(src, "callableInventory.ts"),
    policyPath,
  });
  assert.ok(result.exportedNames.includes("newlyAddedMutation"));
  assert.ok(result.errors.some((error) =>
    error.startsWith("export-classification-mismatch")));
  assert.ok(result.errors.some((error) =>
    error.includes("callable=newlyAddedMutation")));
});

test("a classified mutation cannot bypass security or admission", (context) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-callables-"));
  context.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const src = path.join(root, "src");
  fs.mkdirSync(src);
  fs.writeFileSync(
    path.join(root, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {module: "commonjs", target: "es2022"},
      include: ["src"],
    }),
  );
  fs.writeFileSync(
    path.join(src, "callableInventory.ts"),
    [
      "export const CALLABLE_SECURITY_CLASSIFICATION = {",
      '  bypassAttempt: "mutating",',
      "} as const;",
    ].join("\n"),
  );
  fs.writeFileSync(
    path.join(src, "index.ts"),
    [
      "declare function onCall(options: object, handler: Function): Function;",
      "export const bypassAttempt = onCall({}, async () => null);",
    ].join("\n"),
  );
  const policyPath = path.join(root, "policy.json");
  fs.writeFileSync(
    policyPath,
    JSON.stringify({
      callableAppCheckPolicy: {
        mutatingSecurityOptionsExport:
          "MUTATING_CALLABLE_SECURITY_OPTIONS",
        mutatingCallables: ["bypassAttempt"],
        readOnlySecurityOptionsByCallable: {},
      },
    }),
  );

  const result = auditCallableInventory({
    tsconfigPath: path.join(root, "tsconfig.json"),
    entrypointPath: path.join(src, "index.ts"),
    classificationPath: path.join(src, "callableInventory.ts"),
    policyPath,
  });
  assert.ok(result.errors.includes(
    "callable-security-options-missing callable=bypassAttempt " +
    "expected=MUTATING_CALLABLE_SECURITY_OPTIONS",
  ));
  assert.ok(result.errors.includes(
    "abuse-control-callable-name-missing callable=bypassAttempt",
  ));
  assert.ok(result.errors.includes(
    "abuse-control-admission-missing callable=bypassAttempt",
  ));
});
