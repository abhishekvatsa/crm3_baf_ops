const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const {
  BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS,
  BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT,
  BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT_ID,
  backendIdentityRuntimeServiceAccountForProject,
} = require("../lib/stage2dSecurityConfig");

function readJson(relativePath) {
  return JSON.parse(
    fs.readFileSync(path.resolve(__dirname, "../..", relativePath), "utf8"),
  );
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function recomputeDigest(document, field) {
  const clone = JSON.parse(JSON.stringify(document));
  delete clone[field];
  return crypto
    .createHash("sha256")
    .update(canonicalJson(clone), "utf8")
    .digest("hex")
    .toUpperCase();
}

function validateExactSchema(instance, schema, location = "$") {
  if (Object.prototype.hasOwnProperty.call(schema, "const")) {
    expect(instance).toEqual(schema.const);
  }

  if (schema.type === "object") {
    expect(instance).not.toBeNull();
    expect(Array.isArray(instance)).toBe(false);
    expect(typeof instance).toBe("object");
    expect(schema.additionalProperties).toBe(false);

    const properties = schema.properties || {};
    const keys = Object.keys(properties).sort();
    expect((schema.required || []).slice().sort()).toEqual(keys);
    expect(Object.keys(instance).sort()).toEqual(keys);

    for (const key of keys) {
      validateExactSchema(
        instance[key],
        properties[key],
        `${location}.${key}`,
      );
    }
  } else if (schema.type === "array") {
    expect(Array.isArray(instance)).toBe(true);
    expect(Object.prototype.hasOwnProperty.call(schema, "const")).toBe(true);
  } else if (schema.type === "string") {
    expect(typeof instance).toBe("string");
  } else if (schema.type === "integer") {
    expect(Number.isInteger(instance)).toBe(true);
  } else if (schema.type === "boolean") {
    expect(typeof instance).toBe("boolean");
  } else if (schema.type === "null") {
    expect(instance).toBeNull();
  } else {
    throw new Error(`Unsupported schema type at ${location}: ${schema.type}`);
  }
}

function blockStartingAt(source, marker) {
  const start = source.indexOf(marker);
  if (start < 0) throw new Error(`Missing marker: ${marker}`);
  const open = source.indexOf("{", start);
  if (open < 0) throw new Error(`Missing block for marker: ${marker}`);

  let depth = 0;
  let single = false;
  let double = false;
  let lineComment = false;
  let blockComment = false;
  let escaped = false;

  for (let index = open; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1] || "";

    if (lineComment) {
      if (char === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (!single && !double && char === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (!single && !double && char === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (escaped) {
      escaped = false;
      continue;
    }
    if ((single || double) && char === "\\") {
      escaped = true;
      continue;
    }
    if (!double && char === "'") {
      single = !single;
      continue;
    }
    if (!single && char === '"') {
      double = !double;
      continue;
    }
    if (single || double) continue;

    if (char === "{") depth += 1;
    if (char === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  throw new Error(`Unterminated block: ${marker}`);
}

describe("Stage 2D source security candidate", () => {
  const readiness = readJson(
    "release/stage2d-source-security-readiness-candidate.json",
  );
  const readinessSchema = readJson(
    "release/stage2d-source-security-readiness-v1.schema.json",
  );
  const productionSecurity = readJson(
    "release/backend-security-readiness.prod.json",
  );
  const packageLock = readJson("functions/package-lock.json");
  const rootPackage = readJson("package.json");
  const rootPackageLock = readJson("package-lock.json");
  const functionSource = fs.readFileSync(
    path.resolve(__dirname, "../src/index.ts"),
    "utf8",
  );

  test("binds the identity callable to its target-project identity", () => {
    expect(BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT_ID).toBe(
      "crm3-backend-identity-runtime",
    );
    expect(BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT.toCEL()).toBe(
      "crm3-backend-identity-runtime@{{ params.PROJECT_ID }}" +
      ".iam.gserviceaccount.com",
    );
    expect(backendIdentityRuntimeServiceAccountForProject(
      "crm3-baf-ops-b8638",
    )).toBe(
      "crm3-backend-identity-runtime@" +
      "crm3-baf-ops-b8638.iam.gserviceaccount.com",
    );
    expect(BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS).toEqual({
      enforceAppCheck: true,
      consumeAppCheckToken: false,
      serviceAccount: BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT,
    });

    const identityBlock = blockStartingAt(
      functionSource,
      "export const getBackendReleaseIdentity = onCall(",
    );
    expect(identityBlock).toContain(
      "...BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS",
    );

    for (const callable of [
      "completePlannedJobExecution",
      "assignPublishedTemplateVersion",
      "mutateRuntimeJobModulePopulation",
      "mutateUserAuthority",
      "mutateChargeAbnormality",
    ]) {
      const block = blockStartingAt(
        functionSource,
        `export const ${callable} = onCall(`,
      );
      expect(block).not.toContain(
        "BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS",
      );
      expect(block).toContain("serviceAccount:");
      expect(block).toContain("...MUTATING_CALLABLE_SECURITY_OPTIONS");
    }
  });

  test("remediates deployed and root-tooling high advisory packages", () => {
    const packages = packageLock.packages;
    expect(packages["node_modules/form-data"].version).toBe("2.5.6");
    expect(packages["node_modules/protobufjs"].version).toBe("7.6.5");
    expect(packages["node_modules/@protobufjs/inquire"]).toBeUndefined();

    expect(rootPackage.overrides.protobufjs).toBe("7.6.5");
    expect(rootPackageLock.packages["node_modules/protobufjs"].version)
      .toBe("7.6.5");
    expect(rootPackageLock.packages["node_modules/@protobufjs/inquire"])
      .toBeUndefined();
  });

  test("keeps the production ledger truthful and separate", () => {
    expect(productionSecurity.securityReady).toBe(false);
    expect(productionSecurity.openBlockerCount).toBe(5);
    expect(productionSecurity.dependencyAudit.high).toBe(2);
    expect(productionSecurity.target.revision)
      .toBe("getbackendreleaseidentity-00002-wud");

    expect(readiness.securityReady).toBe(false);
    expect(readiness.currentProductionStateChanged).toBe(false);
    expect(readiness.sourceImplementationComplete).toBe(true);
  });

  test("source-readiness record and exact schema reproduce", () => {
    validateExactSchema(readiness, readinessSchema);
    expect(recomputeDigest(readiness, "sourceReadinessDigest"))
      .toBe(readiness.sourceReadinessDigest);
    expect(readiness.sourceReadinessDigest).toBe(
      "5AB77DD5FF479064CC11AE7D1165682ACE00503F601D9B11C5B19F43C820F547",
    );
  });

  test("does not authorize deployment, IAM, App Check control-plane or writes", () => {
    expect(readiness.mutationAuthorization).toEqual({
      sourceBranchCommitPushDraftPrAuthorizedByCampaign: true,
      firebaseDeploymentAuthorized: false,
      iamMutationAuthorized: false,
      appCheckControlPlaneMutationAuthorized: false,
      firestoreWriteAuthorized: false,
      productionFunctionInvocationAuthorized: false,
    });
    expect(readiness.publicTransport.removalAuthorized).toBe(false);
  });
});
