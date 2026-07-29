"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function fail(message) {
  throw new Error(message);
}

function readArg(name) {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) {
    fail(`Missing required argument: ${name}`);
  }
  return process.argv[index + 1];
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex").toUpperCase();
}

function decodeXml(value) {
  return value
    .replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function parseAttributes(tag) {
  const result = {};
  for (const match of tag.matchAll(/([A-Za-z0-9_-]+)="([^"]*)"/g)) {
    result[match[1]] = decodeXml(match[2]);
  }
  return result;
}

function selectedAccountEmail(chooserPath) {
  const xml = fs.readFileSync(chooserPath, "utf8");
  const nodes = [...xml.matchAll(/<node\b[^>]*>/g)]
    .map((match) => parseAttributes(match[0]))
    .filter(
      (attributes) =>
        attributes["resource-id"] ===
        "com.google.android.gms:id/account_name",
    );
  if (nodes.length !== 1) {
    fail(`Expected one selected-account candidate, found ${nodes.length}.`);
  }
  const email = (nodes[0].text || "").trim();
  if (
    email.length === 0 ||
    email.length > 255 ||
    !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)
  ) {
    fail("The selected account does not expose one valid email identifier.");
  }
  return email;
}

function fieldType(value) {
  if (value == null || typeof value !== "object") return "missing";
  return (
    Object.keys(value).find((key) => key.endsWith("Value")) || "unknown"
  );
}

function arrayStrings(field) {
  const values = field?.arrayValue?.values;
  if (!Array.isArray(values)) return null;
  const strings = values.map((value) => value.stringValue);
  return strings.every((value) => typeof value === "string") ? strings : null;
}

async function main() {
  const repositoryRoot = path.resolve(readArg("--repository-root"));
  const chooserPath = path.resolve(readArg("--chooser"));
  const projectId = readArg("--project-id");
  const projectNumber = readArg("--project-number");
  const email = selectedAccountEmail(chooserPath);

  const firebaseToolsRoot = path.join(
    repositoryRoot,
    "tooling",
    "firebase-cli",
    "node_modules",
    "firebase-tools",
    "lib",
  );
  const auth = require(path.join(firebaseToolsRoot, "auth"));
  const api = require(path.join(firebaseToolsRoot, "apiv2"));
  const account = auth.getProjectDefaultAccount(repositoryRoot);
  if (!account) fail("No authenticated Firebase CLI account is available.");
  auth.setActiveAccount({}, account);

  // firebaseauth.users.get is the only additional IAM data permission used.
  const identityClient = new api.Client({
    urlPrefix: "https://identitytoolkit.googleapis.com/v1",
  });
  const lookup = (
    await identityClient.post(`/projects/${projectId}/accounts:lookup`, {
      email: [email],
    })
  ).body;
  const users = Array.isArray(lookup.users) ? lookup.users : [];
  if (users.length !== 1 || typeof users[0].localId !== "string") {
    fail(`Expected one Firebase Auth user, found ${users.length}.`);
  }
  const authUser = users[0];
  const localId = authUser.localId;
  const providers = Array.isArray(authUser.providerUserInfo)
    ? authUser.providerUserInfo
        .map((provider) => provider.providerId)
        .filter((providerId) => typeof providerId === "string")
        .sort()
    : [];

  const firestoreClient = new api.Client({
    urlPrefix: "https://firestore.googleapis.com/v1",
  });
  const document = (
    await firestoreClient.get(
      `/projects/${projectId}/databases/(default)/documents/users/` +
        encodeURIComponent(localId),
    )
  ).body;
  const fields = document.fields || {};
  const fieldNames = Object.keys(fields).sort();
  const allowedFields = [
    "createdAt",
    "email",
    "fcmToken",
    "isApproved",
    "name",
    "photoUrl",
    "roles",
  ];
  const requiredFields = ["createdAt", "email", "isApproved", "name", "roles"];
  const roleValues = arrayStrings(fields.roles);
  const canonicalRoles = new Set([
    "admin",
    "si",
    "contractor",
    "contractSupervisor",
    "shiftSupervisor",
    "seniorMechanical",
    "seniorElectrical",
    "seniorInstrumentation",
    "seniorRefractory",
    "refractory",
    "operations",
  ]);

  const rulesClient = new api.Client({
    urlPrefix: "https://firebaserules.googleapis.com/v1",
  });
  const release = (
    await rulesClient.get(`/projects/${projectId}/releases/cloud.firestore`)
  ).body;
  const ruleset = (await rulesClient.get(`/${release.rulesetName}`)).body;
  const deployedRules =
    ruleset.source.files.find((file) => file.name === "firestore.rules") ||
    ruleset.source.files[0];
  const repositoryRules = fs.readFileSync(
    path.join(repositoryRoot, "firestore.rules"),
    "utf8",
  );

  const appCheckClient = new api.Client({
    urlPrefix: "https://firebaseappcheck.googleapis.com/v1",
  });
  const appCheck = (
    await appCheckClient.get(
      `/projects/${projectNumber}/services/firestore.googleapis.com`,
    )
  ).body;

  const result = {
    schemaVersion: 1,
    evidenceType: "build-5-own-user-profile-diagnostic-core",
    projectId,
    scope: {
      matchedAuthUserCount: users.length,
      ownUserDocumentsRead: 1,
      otherUserDocumentsRead: 0,
      remoteWritesPerformed: 0,
    },
    privacy: {
      accountEmailRetained: false,
      accountDisplayNameRetained: false,
      localIdRetained: false,
    },
    auth: {
      localIdSha256: sha256(localId),
      emailVerified: authUser.emailVerified === true,
      disabled: authUser.disabled === true,
      googleProviderLinked: providers.includes("google.com"),
    },
    ownUserDocument: {
      documentNameSha256: sha256(document.name),
      fieldNames,
      fieldTypes: Object.fromEntries(
        fieldNames.map((name) => [name, fieldType(fields[name])]),
      ),
      requiredFullShapePresent: requiredFields.every((name) =>
        fieldNames.includes(name),
      ),
      onlyGovernedFieldsPresent: fieldNames.every((name) =>
        allowedFields.includes(name),
      ),
      nameIsNonEmptyString:
        typeof fields.name?.stringValue === "string" &&
        fields.name.stringValue.length > 0,
      emailIsNonEmptyString:
        typeof fields.email?.stringValue === "string" &&
        fields.email.stringValue.length > 0,
      emailMatchesAuthIdentity: fields.email?.stringValue === email,
      rolesAreNonEmptyCanonicalStrings:
        roleValues !== null &&
        roleValues.length > 0 &&
        roleValues.every((role) => canonicalRoles.has(role)),
      isApprovedIsBoolean:
        typeof fields.isApproved?.booleanValue === "boolean",
      isApproved: fields.isApproved?.booleanValue === true,
      createdAtIsTimestamp:
        typeof fields.createdAt?.timestampValue === "string",
    },
    controlPlane: {
      activeRulesetName: release.rulesetName,
      activeRulesetCreateTime: ruleset.createTime,
      activeRulesSha256: sha256(deployedRules.content),
      repositoryRulesSha256: sha256(repositoryRules),
      activeRulesByteExactToRepository:
        deployedRules.content === repositoryRules,
      firestoreAppCheckEnforcementMode: appCheck.enforcementMode,
      firestoreAppCheckIsUnenforced:
        appCheck.enforcementMode === "UNENFORCED",
      firestoreAppCheckUpdateTime: appCheck.updateTime,
    },
  };

  process.stdout.write(JSON.stringify(result));
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
