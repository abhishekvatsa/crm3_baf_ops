"use strict";

// This is an allowlisted publication projection, not a replacement for private
// observation validation. Generation consumes the full raw proof and the actual
// generation-pinned custody result. Offline CI can check commitments, not fetch
// or independently re-observe the hidden cloud records.
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual: same} = require("node:util");
const guard = require("./scopedCallableInvokerIam.js");
const {canonicalJson, sealReceipt, verifyReceiptSeal} = require("./collectProductionGlobalPullBackend.js");
const {compareReviewedBackendControls, OBSERVED_CONTROL_MODE} = require("./reviewedBackendControls.js");
const TYPE = "scoped-callable-invoker-iam-public-comparison";
const PASS = "PASS_NEW_CALLABLE_INVOKER_IAM_ONLY";
const BUCKET = "crm3-baf-ops-b8638-firestore-restore";
const CUSTODY_AUTHORITY = Object.freeze({commit: "e1db8eaa4b34c26254d3fd2a4cfc533747e187a4",
  file: "release/approvals/build28-private-cloud-custody-approval.json",
  sha256: "3DEB2A9E26FCFDBBAC20A591256ABB3A29FA3EBEF75D3A91FDACCEA2BA64FC88"});
const QUALIFICATION = "Publication projection generated only after full private IAM and backend-control revalidation and generation-pinned private custody verification. Offline CI validates source, approved scope, chronology, commitment equality and custody attestation; it does not re-read hidden raw responses or independently verify the cloud upload. Hash seals prove integrity, not observation authenticity. Private raw evidence remains available for authorized revalidation. Before/after observations do not exclude transient intervening changes.";
const CONTROL_FLAGS = Object.freeze(["allFunctionMutatingAppCheckParametersFalse", "allMutatingCallableAppCheckEnforcementFalse",
  "existingBackendIdentityAppCheckEnforcementTruePreserved", "existingFunctionEnvironmentVariablesUnchanged",
  "existingRuntimeAndTriggerServiceAccountsUnchanged", "existingIngressSettingsUnchanged", "allFunctionsMatchSourceRuntimeIdentities",
  "allFunctionsActiveGen2", "newFunctionsMatchApprovedSourceOptions", "projectIamBindingsSemanticallyUnchanged"]);
const OBSERVED_CONTROL_FLAGS = Object.freeze([...CONTROL_FLAGS.filter((name) => name !== "existingFunctionEnvironmentVariablesUnchanged"),
  "existingProjectEnvironmentVariablesUnchanged", "reservedHttpSignatureMetadataValidated", "newFunctionEffectiveInstanceCapsValidated"]);
const SOURCE_FILES = Object.freeze(["release/function-fleet-runtime-identity-policy.json", "functions/package.json", "functions/package-lock.json",
  "functions/src/callableSecurityConfig.ts", "functions/src/stage2dSecurityConfig.ts", "functions/src/index.ts",
  "functions/src/maintenanceWorkflow/callable.ts"].sort());
const digest = (value) => guard.hash(canonicalJson(value));
function need(value, message) { if (!value) throw new Error(`Public scoped IAM: ${message}`); }
function keys(value, fields, label) {
  need(value !== null && typeof value === "object" && !Array.isArray(value) &&
    same(Object.keys(value).sort(), [...fields].sort()), `${label} has missing or unsupported fields.`);
}
function hash(value) { need(typeof value === "string" && /^[A-Fa-f0-9]{64}$/.test(value), "invalid SHA-256 commitment."); return value.toUpperCase(); }
function utc(value) {
  const m = typeof value === "string" && /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.(\d{1,9}))?Z$/.exec(value);
  need(m && !m[1].startsWith("0000-"), "invalid UTC timestamp.");
  const seconds = Date.parse(`${m[1]}Z`);
  need(Number.isFinite(seconds) && new Date(seconds).toISOString().slice(0, 19) === m[1], "invalid UTC calendar date.");
  return BigInt(seconds) * 1000000n + BigInt((m[2] ?? "").padEnd(9, "0"));
}
function validateCustody(repoRoot, value) {
  keys(value, ["schemaVersion", "provider", "purpose", "buildNumber", "bucket", "prefix", "objectName", "objectUri", "generation",
    "generationUri", "bytes", "sha256", "downloadedBytes", "downloadedSha256", "createOnly", "generationPinnedReadback", "verified",
    "verifiedAtUtc", "approval", "bucketControls"], "private custody");
  need(value.schemaVersion === 1 && value.provider === "gcs" && value.purpose === "custodyRecord" && value.buildNumber === 28 &&
    value.bucket === BUCKET && typeof value.prefix === "string" &&
    new RegExp(`^gs://${BUCKET}/release-custody/build-28/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`).test(value.prefix), "unapproved private custody destination.");
  const uri = `${value.prefix}/scoped-iam-comparison.json`;
  need(value.objectUri === uri && value.objectName === uri.slice(`gs://${BUCKET}/`.length) &&
    typeof value.generation === "string" && /^[1-9][0-9]*$/.test(value.generation) &&
    value.generationUri === `${uri}#${value.generation}`, "custody object/generation is not exact.");
  need(Number.isSafeInteger(value.bytes) && value.bytes > 0 && value.downloadedBytes === value.bytes &&
    hash(value.sha256) === hash(value.downloadedSha256) && value.createOnly === true &&
    value.generationPinnedReadback === true && value.verified === true, "private generation readback is not verified.");
  need(same(value.approval, CUSTODY_AUTHORITY), "private custody approval differs.");
  const committed = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "show",
    `${CUSTODY_AUTHORITY.commit}:${CUSTODY_AUTHORITY.file}`], {windowsHide: true});
  need(guard.hash(committed) === CUSTODY_AUTHORITY.sha256 &&
    guard.hash(fs.readFileSync(path.join(repoRoot, CUSTODY_AUTHORITY.file))) === CUSTODY_AUTHORITY.sha256,
  "private custody approval is not the exact immutable Git/current object.");
  const c = value.bucketControls;
  keys(c, ["bucket", "location", "publicAccessPrevention", "uniformBucketLevelAccess", "versioningEnabled", "publicIamPrincipalsAbsent",
    "retentionSeconds", "softDeleteSeconds", "checkedAtUtc"], "private bucket control summary");
  need(c.bucket === BUCKET && c.location === "ASIA-SOUTH1" && c.publicAccessPrevention === "enforced" &&
    c.uniformBucketLevelAccess === true && c.versioningEnabled === true && c.publicIamPrincipalsAbsent === true &&
    c.retentionSeconds === 7776000 && c.softDeleteSeconds === 604800 && utc(c.checkedAtUtc) <= utc(value.verifiedAtUtc),
  "private bucket controls differ from approved measured controls.");
}
function captureProjection(capture, excludedFunctions, excludedServices) {
  const m = capture.measurement;
  const without = (value, excluded) => Object.fromEntries(Object.entries(value).filter(([name]) => !excluded.includes(name)));
  return {startedAtUtc: capture.raw.startedAtUtc, completedAtUtc: capture.raw.completedAtUtc,
    captureReceiptSha256: capture.receiptSha256, rawMeasurementSha256: capture.rawMeasurementSha256,
    inventory: {functionCount: Object.keys(m.functions).length, runServiceCount: Object.keys(m.runServices).length,
      serviceAccountCount: Object.keys(m.serviceAccounts).length},
    commitments: {functionsSha256: digest(m.functions), runServicesSha256: digest(m.runServices),
      serviceAccountsSha256: digest(m.serviceAccounts), projectIamSha256: digest(m.projectIam),
      preservedFunctionsSha256: digest(without(m.functions, excludedFunctions)),
      preservedRunServicesSha256: digest(without(m.runServices, excludedServices))}};
}
function sourceControlCommitment(repoRoot, sourceCommit) {
  // The public/offline verifier runs before npm installation. Bind exact source
  // bytes here; only generation invokes the full TypeScript AST/control check.
  need(typeof sourceCommit === "string" && /^[a-f0-9]{40}$/.test(sourceCommit), "exact source commit required.");
  const sourceOptionsFiles = SOURCE_FILES.map((file) => ({file, sha256: guard.hash(execFileSync("git",
    ["--no-replace-objects", "-C", repoRoot, "show", `${sourceCommit}:${file}`], {windowsHide: true}))}));
  return {sourceOptionsSha256: digest(sourceOptionsFiles), sourceOptionsFiles};
}
function createPublicProof(input) {
  try { return createVerifiedPublicProof(input); }
  catch {
    // Nested validators deliberately retain raw request URLs in private error
    // diagnostics. Do not let a caller print those private identities/values.
    throw new Error("Public scoped IAM: private proof, controls or custody verification failed; inspect retained inputs privately.");
  }
}
function createVerifiedPublicProof({rawProofBytes, privateCustody, observedAtUtc, ...context}) {
  need(Buffer.isBuffer(rawProofBytes), "exact retained private proof bytes are required.");
  let raw;
  try { raw = JSON.parse(rawProofBytes.toString("utf8")); }
  catch { throw new Error("Public scoped IAM: malformed private proof JSON; inspect the retained file privately."); }
  guard.validateProof({...context, proof: raw});
  const controls = compareReviewedBackendControls({...context, observedAtUtc, proof: raw});
  validateCustody(context.repoRoot, privateCustody);
  need(privateCustody.bytes === rawProofBytes.length && hash(privateCustody.sha256) === guard.hash(rawProofBytes),
    "private custody does not retain these exact raw proof bytes.");
  const {pairs} = guard.sourceScope(context);
  const additions = [...pairs.values()].sort((a, b) => a.functionName.localeCompare(b.functionName));
  const source = sourceControlCommitment(context.repoRoot, context.sourceCommit);
  need(same([...controls.sourceOptionsFiles].sort((a, b) => a.file.localeCompare(b.file)), source.sourceOptionsFiles),
    "public source commitment omits a file used in private control verification.");
  const observed = context.controlMode === OBSERVED_CONTROL_MODE;
  const result = sealReceipt({schemaVersion: observed ? 3 : 2, evidenceType: TYPE, decision: PASS, projectId: guard.PROJECT, region: guard.REGION,
    sourceCommit: context.sourceCommit, approvalSha256: context.approvalSha256.toUpperCase(), observedAtUtc,
    ...(observed ? {verificationAuthority: context.verificationAuthority} : {}),
    before: captureProjection(raw.before, [], []),
    after: captureProjection(raw.after, additions.map((row) => row.functionName), additions.map((row) => row.serviceResource)),
    unavailableRunRegions: raw.before.measurement.unavailableRunRegions ?? [], newInvokerPolicies: additions,
    controls: {receiptSha256: controls.receiptSha256, functionCount: controls.functionCount,
      existingFunctionCount: controls.existingFunctionCount, newFunctionCount: controls.newFunctionCount,
      ...Object.fromEntries((observed ? OBSERVED_CONTROL_FLAGS : CONTROL_FLAGS).map((name) => [name, controls[name]])),
      ...(observed ? {controlMode: OBSERVED_CONTROL_MODE, reservedHttpSignatureObservations: controls.reservedHttpSignatureObservations,
        newFunctionEffectiveInstanceCaps: controls.newFunctionEffectiveInstanceCaps} : {}),
      ...source},
    privateProofReceiptSha256: raw.receiptSha256, privateCustody,
    qualification: QUALIFICATION,
    coverage: "Project IAM, all project service-account identity/IAM, and every service in successfully observed Run regions are committed in full. Listed unavailable regions are excluded: no absence or unchanged IAM is claimed there. New policy authorization remains limited to the four source-bound services in asia-south1.",
    mutationBoundary: {iamMutated: false, cloudResourcesMutated: false}});
  validatePublicProof({...context, proof: result});
  return result;
}
function validatePublicProof({proof, ...context}) {
  verifyReceiptSeal(proof, "Public scoped IAM comparison");
  const observed = proof.schemaVersion === 3;
  keys(proof, ["schemaVersion", "evidenceType", "decision", "projectId", "region", "sourceCommit", "approvalSha256", "observedAtUtc",
    "before", "after", "unavailableRunRegions", "newInvokerPolicies", "controls", "privateProofReceiptSha256", "privateCustody",
    "qualification", "coverage", "mutationBoundary", "receiptSha256", ...(observed ? ["verificationAuthority"] : [])], "publication proof");
  need((proof.schemaVersion === 2 || observed) && proof.evidenceType === TYPE && proof.decision === PASS && proof.projectId === guard.PROJECT &&
    proof.region === guard.REGION && proof.sourceCommit === context.sourceCommit && hash(proof.approvalSha256) === hash(context.approvalSha256),
  "publication authority differs.");
  const {pairs, fleet, policy} = guard.sourceScope(context);
  need(same(proof.newInvokerPolicies, [...pairs.values()].sort((a, b) => a.functionName.localeCompare(b.functionName))), "new public policies differ from exact approval.");
  for (const [phase, value] of [["before", proof.before], ["after", proof.after]]) {
    keys(value, ["startedAtUtc", "completedAtUtc", "captureReceiptSha256", "rawMeasurementSha256", "inventory", "commitments"], `${phase} observation`);
    need(utc(value.startedAtUtc) <= utc(value.completedAtUtc), "observation interval is reversed.");
    hash(value.captureReceiptSha256); hash(value.rawMeasurementSha256);
    keys(value.inventory, ["functionCount", "runServiceCount", "serviceAccountCount"], `${phase} inventory`);
    for (const n of Object.values(value.inventory)) need(Number.isSafeInteger(n) && n > 0, "invalid inventory count.");
    need(value.inventory.functionCount === (phase === "before" ? fleet.functionCount - 4 : fleet.functionCount) &&
      value.inventory.runServiceCount >= value.inventory.functionCount && value.inventory.serviceAccountCount >= fleet.runtimePrincipalCount,
    "complete observed inventory counts differ from source.");
    keys(value.commitments, ["functionsSha256", "runServicesSha256", "serviceAccountsSha256", "projectIamSha256", "preservedFunctionsSha256", "preservedRunServicesSha256"], `${phase} commitments`);
    Object.values(value.commitments).forEach(hash);
  }
  const a = proof.before, b = proof.after;
  need(utc(a.completedAtUtc) < utc(b.startedAtUtc) && b.inventory.runServiceCount === a.inventory.runServiceCount + 4 &&
    b.inventory.serviceAccountCount === a.inventory.serviceAccountCount, "observation scope/chronology differs.");
  for (const field of ["serviceAccountsSha256", "projectIamSha256", "preservedFunctionsSha256", "preservedRunServicesSha256"])
    need(hash(a.commitments[field]) === hash(b.commitments[field]), "preserved inventory/IAM commitment differs.");
  need(hash(a.commitments.functionsSha256) === hash(a.commitments.preservedFunctionsSha256) &&
    hash(a.commitments.runServicesSha256) === hash(a.commitments.preservedRunServicesSha256), "preflight preservation commitment is incomplete.");
  need(Array.isArray(proof.unavailableRunRegions) && proof.unavailableRunRegions.length <= 1, "unsupported excluded-region scope.");
  for (const row of proof.unavailableRunRegions) {
    keys(row, ["location", "reason", "domain", "consumer"], "excluded region");
    need(row.location === "me-central2" && row.reason === "LOCATION_POLICY_VIOLATED" && row.domain === "googleapis.com" &&
      typeof row.consumer === "string" && /^projects\/[1-9][0-9]*$/.test(row.consumer), "unsupported excluded region/reason.");
  }
  const c = proof.controls;
  const flags = observed ? OBSERVED_CONTROL_FLAGS : CONTROL_FLAGS;
  keys(c, ["receiptSha256", "functionCount", "existingFunctionCount", "newFunctionCount", ...flags, "sourceOptionsSha256", "sourceOptionsFiles",
    ...(observed ? ["controlMode", "reservedHttpSignatureObservations", "newFunctionEffectiveInstanceCaps"] : [])], "control commitments");
  hash(c.receiptSha256);
  need(c.functionCount === 19 && c.existingFunctionCount === 15 && c.newFunctionCount === 4 && flags.every((name) => c[name] === true), "backend controls did not pass.");
  if (observed) {
    need(c.controlMode === OBSERVED_CONTROL_MODE, "unsupported observed control profile.");
    require("./reviewedBackendVerifierAuthority.js").validateVerifierAuthority({repoRoot: context.repoRoot,
      verificationAuthority: proof.verificationAuthority, sourceCommit: context.sourceCommit,
      approvalSha256: context.approvalSha256, observedAtUtc: proof.observedAtUtc});
    validateObservedControlSummary(c, pairs, fleet, policy);
  }
  const source = sourceControlCommitment(context.repoRoot, context.sourceCommit);
  need(same(c.sourceOptionsFiles, source.sourceOptionsFiles) && c.sourceOptionsSha256 === source.sourceOptionsSha256, "control commitments differ from exact source.");
  hash(proof.privateProofReceiptSha256);
  validateCustody(context.repoRoot, proof.privateCustody);
  need(utc(b.completedAtUtc) <= utc(proof.privateCustody.bucketControls.checkedAtUtc) &&
    utc(proof.privateCustody.verifiedAtUtc) <= utc(proof.observedAtUtc) && utc(proof.observedAtUtc) <= BigInt(Date.now()) * 1000000n,
  "private custody/publication predates the observations or is in the future.");
  need(proof.qualification === QUALIFICATION && proof.coverage === "Project IAM, all project service-account identity/IAM, and every service in successfully observed Run regions are committed in full. Listed unavailable regions are excluded: no absence or unchanged IAM is claimed there. New policy authorization remains limited to the four source-bound services in asia-south1." &&
    same(proof.mutationBoundary, {iamMutated: false, cloudResourcesMutated: false}), "publication qualification or own-mutation boundary differs.");
  return {ok: true, decision: PASS};
}
function validateObservedControlSummary(c, pairs, fleet, policy) {
  const names = [...pairs.keys()].sort();
  need(Array.isArray(c.newFunctionEffectiveInstanceCaps) &&
    same(c.newFunctionEffectiveInstanceCaps.map((row) => row.name), names), "new serving-cap inventory differs.");
  for (const row of c.newFunctionEffectiveInstanceCaps) {
    keys(row, ["name", "serviceResource", "serviceUid", "revision", "observedGeneration", "cloudFunctionsMaxInstanceCount",
      "runServiceMaxInstanceCount", "runRevisionMaxInstanceCount", "effectiveMaxInstanceCount", "maximumApprovedBound"], "serving cap");
    need(row.serviceResource === pairs.get(row.name).serviceResource && typeof row.serviceUid === "string" && /^[a-f0-9-]{36}$/.test(row.serviceUid) &&
      typeof row.revision === "string" && row.revision.startsWith(`${row.name.toLowerCase()}-`) && /^[a-z0-9-]+$/.test(row.revision) &&
      typeof row.observedGeneration === "string" && /^[1-9][0-9]*$/.test(row.observedGeneration), "serving identity is not bound.");
    need(Number.isSafeInteger(row.runServiceMaxInstanceCount) && row.runServiceMaxInstanceCount > 0 && row.runServiceMaxInstanceCount <= 100 &&
      row.effectiveMaxInstanceCount === row.runServiceMaxInstanceCount && row.maximumApprovedBound === 100 && row.runRevisionMaxInstanceCount === null &&
      (row.cloudFunctionsMaxInstanceCount === null || row.cloudFunctionsMaxInstanceCount === row.runServiceMaxInstanceCount), "serving cap is absent or contradictory.");
  }
  const observations = c.reservedHttpSignatureObservations;
  need(Array.isArray(observations) && observations.length >= 4 && observations.length <= 19 &&
    same(observations.map((row) => row.name), [...new Set(observations.map((row) => row.name))].sort()), "HTTP metadata inventory differs.");
  const newObserved = [];
  for (const row of observations) {
    keys(row, ["name", "before", "after", "disposition"], "HTTP metadata observation");
    need(row.before === null && (row.after === null || row.after === "http"), "HTTP metadata observation is invalid.");
    if (pairs.has(row.name)) {
      need(row.disposition === "new-http-callable", "new HTTP observation disposition differs.");newObserved.push(row.name);
    } else {
      need(fleet.functionNames.includes(row.name) && /^(?:APP_CHECKED_)?CALLABLE_/.test(policy.functionBindings[row.name].workloadClass) &&
        row.after === "http" && row.disposition === "platform-http-added", "existing HTTP observation is invalid.");
    }
  }
  need(same(newObserved, names), "new HTTP observation coverage is incomplete.");
}
module.exports = {TYPE, createPublicProof, validatePublicProof, validateCustody, OBSERVED_CONTROL_MODE};

if (require.main === module) {
  try {
    const options = {};
    const argv = process.argv.slice(2);
    const required = ["--repository-root", "--approval", "--approval-sha256", "--source-commit", "--private-proof", "--private-custody", "--observed-at-utc", "--output"];
    const allowed = [...required, "--control-mode", "--verification-authority"];
    for (let i = 0; i < argv.length; i += 2) {
      need(allowed.includes(argv[i]) && typeof argv[i + 1] === "string" && !Object.hasOwn(options, argv[i]), "invalid/duplicate argument.");
      options[argv[i]] = argv[i + 1];
    }
    need(required.every((name) => Object.hasOwn(options, name)) &&
      (Object.hasOwn(options, "--control-mode") === Object.hasOwn(options, "--verification-authority")), "all publication inputs are required.");
    const approvalBytes = fs.readFileSync(options["--approval"]);
    need(guard.hash(approvalBytes) === hash(options["--approval-sha256"]), "approval physical hash differs.");
    const result = createPublicProof({repoRoot: path.resolve(options["--repository-root"]), approval: JSON.parse(approvalBytes),
      approvalSha256: options["--approval-sha256"], sourceCommit: options["--source-commit"],
      rawProofBytes: fs.readFileSync(options["--private-proof"]), privateCustody: JSON.parse(fs.readFileSync(options["--private-custody"], "utf8")),
      ...(options["--control-mode"] ? {controlMode: options["--control-mode"], verificationAuthority: JSON.parse(fs.readFileSync(options["--verification-authority"], "utf8"))} : {}),
      observedAtUtc: options["--observed-at-utc"]});
    fs.writeFileSync(options["--output"], `${JSON.stringify(result, null, 2)}\n`, {flag: "wx"});
    process.stdout.write(`${TYPE}: ${result.decision}; ${result.receiptSha256}\n`);
  } catch {
    // JSON and assertion exceptions may quote private environment/policy bytes.
    // Do not send their message/stack to a public deployment transcript.
    process.stderr.write("Public scoped IAM projection did not complete; preserve inputs and inspect them in private custody. Do not admit any incomplete output.\n");
    process.exitCode = 1;
  }
}
