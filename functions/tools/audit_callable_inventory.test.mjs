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
    "assignPublishedTemplateVersionV2",
    "beginGlobalPullRun",
    "completePlannedJobExecution",
    "executeMaintenanceWorkflowCommand",
    "executeMaintenanceWorkflowCommandV2",
    "getBackendReleaseIdentity",
    "mutateAssetHierarchy",
    "mutateAssetHierarchyV2",
    "mutateChargeAbnormality",
    "mutateChargeAbnormalityV2",
    "mutateRuntimeJobModulePopulation",
    "mutateUserAuthority",
  ]);
  assert.deepEqual(result.mutatingNames, [
    "assignPublishedTemplateVersion",
    "assignPublishedTemplateVersionV2",
    "completePlannedJobExecution",
    "executeMaintenanceWorkflowCommand",
    "executeMaintenanceWorkflowCommandV2",
    "mutateAssetHierarchy",
    "mutateAssetHierarchyV2",
    "mutateChargeAbnormality",
    "mutateChargeAbnormalityV2",
    "mutateRuntimeJobModulePopulation",
    "mutateUserAuthority",
  ]);
  assert.deepEqual(result.readOnlyNames, [
    "beginGlobalPullRun",
    "getBackendReleaseIdentity",
  ]);
});

for (const alteration of ["none", "no-guard", "wrong-target", "changed-auth", "changed-data", "forged-approval", "local-fake-guard"]) {
  test(`origin-bound delegation inventory rejects unsafe variant: ${alteration}`, (context) => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-callable-origin-"));
    context.after(() => fs.rmSync(root, {recursive: true, force: true}));
    const src = path.join(root, "src"); fs.mkdirSync(src);
    fs.writeFileSync(path.join(root, "tsconfig.json"), JSON.stringify({
      compilerOptions: {module: "commonjs", target: "es2022"}, include: ["src"],
    }));
    fs.copyFileSync(new URL("../src/originBoundCallableProtocol.ts", import.meta.url),
      path.join(src, "originBoundCallableProtocol.ts"));
    fs.writeFileSync(path.join(src, "callableInventory.ts"), `export const CALLABLE_SECURITY_CLASSIFICATION = {
      mutateAssetHierarchy: "mutating", mutateAssetHierarchyV2: "mutating",
    } as const;`);
    let wrapper = `async (request: any) => executeOriginBoundCallable({
      callableName: "mutateAssetHierarchyV2", authUid: request.auth?.uid ?? null, data: request.data,
      readActor: async (uid) => (await admin.firestore().collection("users").doc(uid).get()).data() ?? null,
      execute: async (payload) => mutateAssetHierarchy.run({...request, data: payload}),
    })`;
    if (alteration === "no-guard") wrapper = "async (request: any) => mutateAssetHierarchy.run(request)";
    if (alteration === "wrong-target") wrapper = wrapper.replace("mutateAssetHierarchy.run", "anotherCallable.run");
    if (alteration === "changed-auth") wrapper = wrapper.replace("...request, data: payload", '...request, auth: {uid: "admin"}, data: payload');
    if (alteration === "changed-data") wrapper = wrapper.replace("data: payload", "data: request.data");
    if (alteration === "forged-approval") wrapper = wrapper.replace('(await admin.firestore().collection("users").doc(uid).get()).data() ?? null', '{isApproved: true, roles: ["admin"]}');
    const helperBinding = alteration === "local-fake-guard" ?
      "declare function executeOriginBoundCallable(args: object): Promise<unknown>;" :
      'import {executeOriginBoundCallable} from "./originBoundCallableProtocol";';
    fs.writeFileSync(path.join(src, "index.ts"), `${helperBinding}
      declare function onCall(options: object, handler: Function): any;
      declare function executeAuthorizedMutation(args: object): Promise<unknown>;
      declare const admin: any; declare const anotherCallable: any;
      const MUTATING_CALLABLE_SECURITY_OPTIONS = {};
      export const mutateAssetHierarchy = onCall({...MUTATING_CALLABLE_SECURITY_OPTIONS},
        async () => executeAuthorizedMutation({callableName: "mutateAssetHierarchy"}));
      export const mutateAssetHierarchyV2 = onCall({...MUTATING_CALLABLE_SECURITY_OPTIONS}, ${wrapper});
    `);
    const policyPath = path.join(root, "policy.json");
    fs.writeFileSync(policyPath, JSON.stringify({callableAppCheckPolicy: {
      mutatingSecurityOptionsExport: "MUTATING_CALLABLE_SECURITY_OPTIONS",
      mutatingCallables: ["mutateAssetHierarchy", "mutateAssetHierarchyV2"],
      readOnlySecurityOptionsByCallable: {},
    }}));
    const result = auditCallableInventory({tsconfigPath: path.join(root, "tsconfig.json"),
      entrypointPath: path.join(src, "index.ts"), classificationPath: path.join(src, "callableInventory.ts"), policyPath});
    if (alteration === "none") assert.deepEqual(result.errors, []);
    else assert.ok(result.errors.includes("abuse-control-admission-missing callable=mutateAssetHierarchyV2"), result.errors.join("\n"));
  });
}

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
