"use strict";

// Explicitly read-only Google API collector. This does not run Firebase deploy,
// setIamPolicy, enable an API, create an account, or inspect business documents.
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const {resolveCommand} = require("./collectFunctionsIamDependenciesReadback.js");
const {PROJECT, REGION, hash, sourceScope, createCapture, unavailableRunRegion} = require("./scopedCallableInvokerIam.js");

async function collect(context, phase, read) {
  const {pairs} = sourceScope(context);
  if (!["before", "after"].includes(phase)) throw new Error("Capture phase must be before or after.");
  const raw = {schemaVersion: 1, projectId: PROJECT, region: REGION,
    sourceCommit: context.sourceCommit, approvalSha256: context.approvalSha256,
    startedAtUtc: new Date().toISOString()};
  async function list(url, field, optionalRegion) {
    const rows = []; const entries = []; const seen = new Set(); let token = "";
    do {
      const response = await read(`${url}?pageSize=100${token ? `&pageToken=${encodeURIComponent(token)}` : ""}`);
      if (response.httpStatus !== 200) {
        if (optionalRegion != null && rows.length === 0 && response.httpStatus === 403) {
          unavailableRunRegion(response, optionalRegion, project.projectNumber);
          return {unavailable: response, entries: []};
        }
        throw new Error(`Cannot enumerate ${field}: HTTP ${response.httpStatus}.`);
      }
      const value = JSON.parse(response.bodyText);
      if (value.error || (value.unreachable?.length ?? 0) > 0) throw new Error(`Incomplete ${field} response.`);
      rows.push(response); entries.push(...(value[field] ?? []));
      token = value.nextPageToken ?? "";
      if (typeof token !== "string" || (token && seen.has(token))) throw new Error("Invalid repeated pagination token.");
      if (token) seen.add(token);
    } while (token);
    return {rows, entries};
  }
  // Bounded concurrency avoids serial reads across every supported Run region.
  async function map(rows, action) {
    const result = new Array(rows.length); let next = 0;
    await Promise.all(Array.from({length: Math.min(4, rows.length)}, async () => {
      while (next < rows.length) { const index = next++; result[index] = await action(rows[index]); }
    }));
    return result;
  }
  raw.project = await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`);
  const project = JSON.parse(raw.project.bodyText);
  const normalize = (resource) => resource.replace(`projects/${project.projectNumber}/`, `projects/${PROJECT}/`);
  raw.functions = (await list(`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`, "functions")).rows;
  const locations = await list(`https://run.googleapis.com/v1/projects/${PROJECT}/locations`, "locations");
  raw.runLocations = locations.rows;
  const inventories = await map(locations.entries, async (location) => ({location: location.locationId,
    ...await list(`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${location.locationId}/services`, "services", location.locationId)}));
  raw.runInventories = inventories.map((row) => row.unavailable ? {location: row.location, unavailable: row.unavailable} :
    {location: row.location, pages: row.rows});
  raw.runIam = await map(inventories.flatMap((row) => row.entries), async (service) => {
    const resource = normalize(service.name);
    return {resource, response: await read(`https://run.googleapis.com/v2/${resource}:getIamPolicy?options.requestedPolicyVersion=3`)};
  });
  const accounts = await list(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`, "accounts");
  raw.accounts = accounts.rows;
  raw.accountIam = await map(accounts.entries, async (account) => ({email: account.email,
    response: await read(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${account.email}:getIamPolicy?options.requestedPolicyVersion=3`, "POST")}));
  raw.projectIam = await read(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`, "POST", {options: {requestedPolicyVersion: 3}});
  raw.absence = phase === "before" ? await map([...pairs.values()], async (pair) => ({
    functionName: pair.functionName, serviceResource: pair.serviceResource,
    functionDescribe: await read(`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/${REGION}/functions/${pair.functionName}`),
    serviceDescribe: await read(`https://run.googleapis.com/v2/${pair.serviceResource}`),
  })) : [];
  raw.completedAtUtc = new Date().toISOString();
  return createCapture(context, raw, phase);
}
module.exports = {collect};

if (require.main === module) (async () => {
  const options = {};
  const allowed = new Set(["--repository-root", "--approval", "--approval-sha256", "--source-commit", "--phase", "--output", "--gcloud"]);
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    if (!allowed.has(argv[i]) || !argv[i + 1] || Object.hasOwn(options, argv[i])) throw new Error("Invalid/duplicate collector argument.");
    options[argv[i]] = argv[i + 1];
  }
  const repoRoot = path.resolve(options["--repository-root"]);
  const bytes = fs.readFileSync(options["--approval"]);
  if (hash(bytes) !== options["--approval-sha256"]?.toUpperCase()) throw new Error("Approval physical digest differs.");
  const context = {repoRoot, approval: JSON.parse(bytes), approvalSha256: hash(bytes), sourceCommit: options["--source-commit"]};
  // Validate source and scope before acquiring credentials or reading remotely.
  sourceScope(context);
  if (fs.existsSync(options["--output"])) throw new Error("Refusing to overwrite retained capture.");
  const command = resolveCommand(options["--gcloud"] ?? "gcloud", ["auth", "print-access-token"]);
  let token;
  try {
    token = execFileSync(command.command, command.args, {cwd: repoRoot, encoding: "utf8", windowsHide: true,
      env: {...process.env, ...command.environment, CLOUDSDK_CORE_DISABLE_PROMPTS: "1"}, stdio: ["ignore", "pipe", "pipe"]}).trim();
  } catch { throw new Error("Unable to obtain existing Google read credentials; no IAM collection performed."); }
  if (!token || /\s/.test(token)) throw new Error("Invalid existing Google credentials.");
  const read = async (url, method = "GET", data) => {
    const target = new URL(url);
    if (!["run.googleapis.com", "cloudfunctions.googleapis.com", "iam.googleapis.com", "cloudresourcemanager.googleapis.com"].includes(target.hostname) ||
      (method !== "GET" && !(method === "POST" && (
        (target.hostname === "cloudresourcemanager.googleapis.com" && target.pathname === `/v1/projects/${PROJECT}:getIamPolicy`) ||
        (target.hostname === "iam.googleapis.com" && new RegExp(`^/v1/projects/${PROJECT}/serviceAccounts/[a-zA-Z0-9@._-]+:getIamPolicy$`).test(target.pathname))
      )))) throw new Error("Read outside collector scope refused.");
    const response = await fetch(url, {method, redirect: "error", signal: AbortSignal.timeout(30000),
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"}, body: data ? JSON.stringify(data) : undefined});
    return {url, method, httpStatus: response.status, bodyText: await response.text()};
  };
  const receipt = await collect(context, options["--phase"], read);
  fs.writeFileSync(options["--output"], `${JSON.stringify(receipt, null, 2)}\n`, {flag: "wx"});
  process.stdout.write(`${JSON.stringify({decision: options["--phase"] === "before" ? "PASS_NEW_CALLABLE_INVOKER_IAM_PREFLIGHT" : "PASS_SCOPED_IAM_AFTER_CAPTURE", receiptSha256: receipt.receiptSha256})}\n`);
})().catch((error) => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });
