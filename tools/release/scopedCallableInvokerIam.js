"use strict";

// Evidence validation only. Immutable approval custody remains the calling
// release gate's responsibility; a seal is an integrity digest, not authority.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual: same} = require("node:util");
const {canonicalJson, sealReceipt, verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const {readDeploymentFleetContract} = require("./deploymentFleetContract.js");
const PROJECT = "crm3-baf-ops-b8638";
const REGION = "asia-south1";
const POLICY_PATH = "release/function-fleet-runtime-identity-policy.json";
const NEW_FUNCTIONS = Object.freeze(["assignPublishedTemplateVersionV2",
  "executeMaintenanceWorkflowCommandV2", "mutateAssetHierarchyV2", "mutateChargeAbnormalityV2"]);
const PASS = "PASS_NEW_CALLABLE_INVOKER_IAM_ONLY";
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex").toUpperCase();
const digest = (value) => hash(canonicalJson(value));
function need(value, message) { if (!value) throw new Error(`Scoped invoker IAM: ${message}`); }
function object(value) { return value != null && typeof value === "object" && !Array.isArray(value); }
function hashEqual(a, b) { return typeof a === "string" && typeof b === "string" && /^[a-f0-9]{64}$/i.test(a) && a.toUpperCase() === b.toUpperCase(); }
function instant(value) {
  need(typeof value === "string" && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value) &&
    Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value, "invalid collection timestamp.");
  return Date.parse(value);
}
function commandInstant(value) {
  // PowerShell emits seven fractional digits; do not truncate them to JS
  // milliseconds when bracketing the actual deployment command interval.
  const match = typeof value === "string" && /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  need(match && !match[1].startsWith("0000-"), "invalid UTC command timestamp.");
  const seconds = Date.parse(`${match[1]}Z`);
  need(Number.isFinite(seconds) && new Date(seconds).toISOString().slice(0, 19) === match[1], "invalid UTC command calendar date.");
  return BigInt(seconds) * 1000000n + BigInt((match[2] ?? "").padEnd(9, "0"));
}
function unique(rows, key, label) {
  need(Array.isArray(rows), `${label} is not an array.`);
  const result = new Map();
  for (const row of rows) {
    const id = key(row);
    need(typeof id === "string" && id.length > 0 && !result.has(id), `${label} has missing/duplicate identity.`);
    result.set(id, row);
  }
  return result;
}
function exactKeys(value, keys, label) {
  need(object(value) && same(Object.keys(value).sort(), [...keys].sort()), `${label} has unsupported fields.`);
}
function sourceScope({repoRoot, approval, approvalSha256, sourceCommit}) {
  need(approval?.approved === true && approval.firebaseProjectId === PROJECT && approval.region === REGION &&
    approval.sourceAuthority?.commit === sourceCommit && /^[a-f0-9]{64}$/i.test(approvalSha256 ?? ""), "source-specific approval missing.");
  const fleet = readDeploymentFleetContract(repoRoot, sourceCommit);
  const policy = JSON.parse(execFileSync("git", ["--no-replace-objects", "-C", repoRoot,
    "show", `${sourceCommit}:${POLICY_PATH}`], {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}));
  const scope = approval.approvedDeployment;
  need(fleet.functionCount === 19 && scope?.preserveExistingIamRequired === true &&
    scope.existingDedicatedServiceAccountsRequired === true && scope.appCheckEnforcement === false,
  "current source or preserved IAM scope differs.");
  const pairs = unique(scope.newCallableInvokerPolicies, (row) => row?.functionName, "approved new policies");
  need(same([...pairs.keys()].sort(), NEW_FUNCTIONS), "exact four approved callables required.");
  const services = new Set();
  for (const [name, row] of pairs) {
    exactKeys(row, ["functionName", "serviceResource", "role", "members"], "approved policy");
    need(typeof row.serviceResource === "string" &&
      new RegExp(`^projects/${PROJECT}/locations/${REGION}/services/[a-z][a-z0-9-]{0,62}$`).test(row.serviceResource) &&
      row.serviceResource === `projects/${PROJECT}/locations/${REGION}/services/${name.toLowerCase()}` &&
      !services.has(row.serviceResource) && row.role === "roles/run.invoker" && same(row.members, ["allUsers"]), "invalid approved invoker policy.");
    services.add(row.serviceResource);
    const alias = policy.runtimeIdentityAliases?.[name];
    need(typeof alias === "string" && policy.functionBindings[name]?.workloadClass === "CALLABLE_FIRESTORE_MUTATION" &&
      policy.functionBindings[name].runtimeServiceAccountId === policy.functionBindings[alias]?.runtimeServiceAccountId,
    "new callable does not reuse its source-bound existing runtime identity.");
  }
  return {fleet, pairs, policy};
}
// Preserve every policy field except transport etag and policy syntax version.
// Array order alone is immaterial; conditional bindings/audit configuration and
// unknown policy fields remain in the digest and cannot disappear unnoticed.
function policyValue(policy) {
  need(object(policy), "IAM policy missing.");
  need(policy.version == null || [0, 1, 3].includes(policy.version), "unsupported policy version.");
  need(policy.etag == null || typeof policy.etag === "string", "invalid policy etag.");
  const {etag, version, ...rest} = policy;
  const sort = (value) => Array.isArray(value)
    ? value.map(sort).sort((a, b) => canonicalJson(a).localeCompare(canonicalJson(b)))
    : object(value) ? Object.fromEntries(Object.entries(value).map(([key, child]) => [key, sort(child)])) : value;
  rest.bindings ??= [];
  need(Array.isArray(rest.bindings) && rest.bindings.every((row) => object(row) &&
    typeof row.role === "string" && Array.isArray(row.members) && row.members.every((member) => typeof member === "string")), "malformed IAM binding.");
  return sort(rest);
}
function body(response, url, method = "GET", status = 200) {
  need(response?.url === url && response.method === method && response.httpStatus === status &&
    typeof response.bodyText === "string", `missing successful measured response for ${url}.`);
  let parsed;
  try { parsed = JSON.parse(response.bodyText); } catch { throw new Error("Scoped invoker IAM: malformed raw JSON response."); }
  need(object(parsed), "raw response is not an object.");
  if (status === 404) need(parsed.error?.code === 404 && parsed.error?.status === "NOT_FOUND", "absence must be an actual NOT_FOUND response.");
  else need(parsed.error == null, "API error is not measurement evidence.");
  return parsed;
}
function pages(rows, url, field) {
  need(Array.isArray(rows) && rows.length > 0, `complete ${field} inventory absent.`);
  const result = []; const seen = new Set(); let token = "";
  for (const response of rows) {
    const target = `${url}${url.includes("?") ? "&" : "?"}pageSize=100${token ? `&pageToken=${encodeURIComponent(token)}` : ""}`;
    const value = body(response, target);
    need(value.unreachable == null || (Array.isArray(value.unreachable) && value.unreachable.length === 0), `${field} contains unreachable locations.`);
    need(value[field] == null || Array.isArray(value[field]), `invalid ${field} inventory.`);
    result.push(...(value[field] ?? []));
    token = value.nextPageToken ?? "";
    need(typeof token === "string" && (!token || !seen.has(token)), "invalid/repeated pagination token.");
    if (token) seen.add(token);
    if (!token) need(response === rows.at(-1), "extra inventory page after completed enumeration.");
  }
  need(token === "", `truncated ${field} inventory.`);
  return result;
}
function summarize(raw, context, phase) {
  const {fleet, pairs, policy} = sourceScope(context);
  need(raw?.schemaVersion === 1 && raw.projectId === PROJECT && raw.region === REGION &&
    raw.sourceCommit === context.sourceCommit && hashEqual(raw.approvalSha256, context.approvalSha256), "raw source/approval binding differs.");
  need(instant(raw.startedAtUtc) <= instant(raw.completedAtUtc), "collection chronology reversed.");
  const project = body(raw.project, `https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`);
  need(project.projectId === PROJECT && /^\d+$/.test(String(project.projectNumber ?? "")), "project identity differs.");
  const normalize = (name) => {
    need(typeof name === "string", "resource identity missing.");
    return name.replace(`projects/${project.projectNumber}/`, `projects/${PROJECT}/`);
  };
  const fnRows = pages(raw.functions, `https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`, "functions");
  const functions = unique(fnRows, (row) => normalize(row?.name), "functions");
  const expectedNames = fleet.functionNames.filter((name) => phase !== "before" || !pairs.has(name));
  need(same([...functions.keys()].sort(), expectedNames.map((name) => `projects/${PROJECT}/locations/${REGION}/functions/${name}`).sort()), "complete function inventory differs from approved before/after fleet.");
  const locations = pages(raw.runLocations, `https://run.googleapis.com/v1/projects/${PROJECT}/locations`, "locations");
  const locationNames = unique(locations, (row) => row?.locationId, "Run locations");
  need(locationNames.has(REGION), "production region absent from complete location inventory.");
  const runInventories = unique(raw.runInventories, (row) => row?.location, "regional service inventories");
  need(same([...locationNames.keys()].sort(), [...runInventories.keys()].sort()), "not every Run region was read.");
  const runRows = [];
  for (const [location, row] of runInventories) {
    need(/^[a-z][a-z0-9-]+$/.test(location), "invalid Run region.");
    for (const service of pages(row.pages, `https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location}/services`, "services")) {
      need(normalize(service.name).startsWith(`projects/${PROJECT}/locations/${location}/services/`), "service listed in wrong region.");
      runRows.push(service);
    }
  }
  const runs = unique(runRows, (row) => normalize(row?.name), "Run services");
  const runPolicies = unique(raw.runIam, (row) => row?.resource, "Run IAM responses");
  need(same([...runs.keys()].sort(), [...runPolicies.keys()].sort()), "not every existing Run service policy was read.");
  const runSummary = {};
  for (const [resource, service] of runs) {
    need(typeof service.uid === "string" && service.uid.length > 0 && !service.deleteTime, "service identity/deletion state is unresolved.");
    runSummary[resource] = {uid: service.uid, policy: policyValue(body(runPolicies.get(resource).response,
      `https://run.googleapis.com/v2/${resource}:getIamPolicy?options.requestedPolicyVersion=3`))};
  }
  const accountRows = pages(raw.accounts, `https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`, "accounts");
  const accounts = unique(accountRows, (row) => row?.email, "service accounts");
  const accountPolicies = unique(raw.accountIam, (row) => row?.email, "service account IAM responses");
  need(same([...accounts.keys()].sort(), [...accountPolicies.keys()].sort()), "not every service account policy was read.");
  const accountSummary = {};
  for (const [email, account] of accounts) {
    need(account.projectId === PROJECT && typeof account.uniqueId === "string" && account.uniqueId.length > 0 &&
      /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.gserviceaccount\.com$/.test(email), "account identity malformed.");
    accountSummary[email] = {uniqueId: account.uniqueId, disabled: account.disabled ?? false,
      policy: policyValue(body(accountPolicies.get(email).response,
        `https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${email}:getIamPolicy?options.requestedPolicyVersion=3`, "POST"))};
  }
  const mapping = {};
  for (const [resource, fn] of functions) {
    const name = resource.split("/").at(-1);
    const service = normalize(fn.serviceConfig?.service);
    const account = fn.serviceConfig?.serviceAccountEmail;
    need(runs.has(service) && account === `${policy.functionBindings[name].runtimeServiceAccountId}@${PROJECT}.iam.gserviceaccount.com` &&
      accounts.has(account) && accountSummary[account].disabled === false, "function service or existing runtime account differs.");
    if (pairs.has(name)) need(service === pairs.get(name).serviceResource, "actual new function points to an unapproved service.");
    mapping[name] = service;
  }
  if (phase === "before") {
    const absent = unique(raw.absence, (row) => row?.functionName, "paired absence reads");
    need(same([...absent.keys()].sort(), NEW_FUNCTIONS), "four direct absence reads required.");
    for (const [name, pair] of pairs) {
      need(!runs.has(pair.serviceResource), "approved new service already exists.");
      const row = absent.get(name);
      need(row.serviceResource === pair.serviceResource, "absence service binding differs.");
      body(row.functionDescribe, `https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/${REGION}/functions/${name}`, "GET", 404);
      body(row.serviceDescribe, `https://run.googleapis.com/v2/${pair.serviceResource}`, "GET", 404);
    }
  } else need(Array.isArray(raw.absence) && raw.absence.length === 0, "after capture cannot claim preflight absence.");
  return {functions: mapping, runServices: runSummary, serviceAccounts: accountSummary,
    projectIam: policyValue(body(raw.projectIam, `https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`, "POST"))};
}
function createCapture(context, raw, phase) {
  need(["before", "after"].includes(phase), "unknown capture phase.");
  const measurement = summarize(raw, context, phase);
  return sealReceipt({schemaVersion: 1, evidenceType: "scoped-callable-invoker-iam-capture", phase,
    projectId: PROJECT, region: REGION, sourceCommit: context.sourceCommit,
    approvalSha256: context.approvalSha256.toUpperCase(), rawMeasurementSha256: digest(raw),
    raw, measurement, mutationBoundary: {iamMutated: false, cloudResourcesMutated: false}});
}
function validateCapture(context, capture, phase) {
  verifyReceiptSeal(capture, "Scoped IAM capture");
  const expected = createCapture(context, capture.raw, phase);
  need(same(capture, expected), "capture does not match its raw measurements.");
  return capture;
}
function validateBeforeCapture({capture, ...context}) {
  validateCapture(context, capture, "before");
  return {ok: true, decision: "PASS_NEW_CALLABLE_INVOKER_IAM_PREFLIGHT"};
}
function createProof(context, before, after) {
  validateCapture(context, before, "before"); validateCapture(context, after, "after");
  need(instant(before.raw.completedAtUtc) < instant(after.raw.startedAtUtc), "before/after captures overlap or are reversed.");
  const {pairs} = sourceScope(context);
  const a = before.measurement; const b = after.measurement;
  need(same(a.projectIam, b.projectIam), "project IAM changed.");
  need(same(a.serviceAccounts, b.serviceAccounts), "service-account inventory or IAM changed.");
  const added = Object.keys(b.runServices).filter((name) => !Object.hasOwn(a.runServices, name)).sort();
  need(same(added, [...pairs.values()].map((row) => row.serviceResource).sort()), "service additions differ from exact four approved policies.");
  for (const [resource, value] of Object.entries(a.runServices)) need(same(value, b.runServices[resource]), "pre-existing service identity or IAM changed.");
  for (const [name, service] of Object.entries(a.functions)) need(b.functions[name] === service, "pre-existing function changed its service identity.");
  for (const resource of added) need(same(b.runServices[resource].policy, policyValue({bindings: [{role: "roles/run.invoker", members: ["allUsers"]}]})), "new service has additional/conditional/nonpublic permissions.");
  return sealReceipt({schemaVersion: 1, evidenceType: "scoped-callable-invoker-iam-comparison", decision: PASS,
    projectId: PROJECT, region: REGION, sourceCommit: context.sourceCommit, approvalSha256: context.approvalSha256.toUpperCase(),
    before, after, newServiceResources: added,
    qualification: "Before/after IAM observations; not a continuous audit of transient writes. Raw response bodies retained; no credentials retained.",
    mutationBoundary: {iamMutated: false, cloudResourcesMutated: false}});
}
function validateProof({proof, ...context}) {
  verifyReceiptSeal(proof, "Scoped IAM comparison");
  need(same(proof, createProof(context, proof.before, proof.after)), "comparison differs from independently rederived measurements.");
  return {ok: true, decision: PASS};
}
function readBoundFile(repoRoot, reference) {
  need(typeof reference?.file === "string" && !path.isAbsolute(reference.file) && !path.win32.isAbsolute(reference.file) &&
    !reference.file.includes(":") && !reference.file.split(/[\\/]/).includes(".."), "proof must use a repository-relative custody path.");
  const root = fs.realpathSync(repoRoot); const file = fs.realpathSync(path.resolve(root, reference.file));
  const relative = path.relative(root, file);
  need(relative && relative !== ".." && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), "proof escapes repository custody.");
  const bytes = fs.readFileSync(file);
  need(hashEqual(hash(bytes), reference.physicalSha256), "proof physical digest differs.");
  const proof = JSON.parse(bytes);
  need(hashEqual(proof.receiptSha256, reference.canonicalReceiptSha256), "proof canonical digest differs.");
  return proof;
}
function validateDeploymentIamBoundary({repoRoot, approval, approvalSha256, receipt}) {
  const scope = approval?.approvedDeployment?.newCallableInvokerPolicies;
  const reference = receipt?.deployment?.newCallableInvokerIamEvidence;
  if (scope === undefined && reference === undefined) {
    need(receipt?.controlBoundary?.iamMutated === false, "unscoped IAM mutation is prohibited.");
    return {ok: true, decision: "PASS_NO_IAM_MUTATION"};
  }
  need(receipt?.controlBoundary?.iamMutated === true && scope !== undefined && reference !== undefined &&
    hashEqual(receipt.approvalAuthority?.sha256, approvalSha256), "new IAM creation must be explicitly declared and approved.");
  const proof = readBoundFile(repoRoot, reference);
  const result = validateProof({repoRoot, approval, approvalSha256, sourceCommit: receipt.sourceAuthority?.commit, proof});
  const firstCommand = commandInstant(receipt.deployment.startedAtUtc);
  const lastCommand = commandInstant(receipt.deployment.lastDeploymentCommandCompletedAtUtc);
  need(commandInstant(proof.before.raw.completedAtUtc) < firstCommand && firstCommand <= lastCommand &&
    lastCommand < commandInstant(proof.after.raw.startedAtUtc), "IAM observations do not surround the actual deployment command interval.");
  return result;
}
module.exports = {NEW_FUNCTIONS, PROJECT, REGION, hash, sourceScope, body, pages, createCapture,
  createProof, validateBeforeCapture, validateProof, validateDeploymentIamBoundary, policyValue};

if (require.main === module) {
  try {
    const [mode, ...argv] = process.argv.slice(2); const options = {};
    for (let i = 0; i < argv.length; i += 2) {
      need(/^--[a-z0-9-]+$/.test(argv[i]) && argv[i + 1] && !Object.hasOwn(options, argv[i]), "invalid/duplicate arguments.");
      options[argv[i]] = argv[i + 1];
    }
    const read = (flag) => JSON.parse(fs.readFileSync(options[flag], "utf8"));
    const approvalBytes = fs.readFileSync(options["--approval"]);
    need(hashEqual(hash(approvalBytes), options["--approval-sha256"]), "approval physical hash differs.");
    const context = {repoRoot: path.resolve(options["--repository-root"]), approval: JSON.parse(approvalBytes),
      approvalSha256: options["--approval-sha256"], sourceCommit: options["--source-commit"]};
    let result;
    if (mode === "verify-deployment") result = validateDeploymentIamBoundary({...context, receipt: read("--receipt")});
    else if (mode === "capture") result = createCapture(context, read("--input"), options["--phase"]);
    else if (mode === "compare") result = createProof(context, read("--before"), read("--after"));
    else throw new Error("Expected capture, compare or verify-deployment.");
    if (options["--output"]) fs.writeFileSync(options["--output"], `${JSON.stringify(result, null, 2)}\n`, {flag: "wx"});
    else process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
}
