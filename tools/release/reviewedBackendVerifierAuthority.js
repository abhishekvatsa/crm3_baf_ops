"use strict";

// This authorizes a fixed, reviewed verification implementation. It never
// authorizes cloud changes or changes the source being verified.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");

const PROFILE = "observed-cloud-run-http-controls-v1";
const VERIFIER_FILES = Object.freeze([
  "tools/release/reviewedBackendVerifierAuthority.js",
  "tools/release/reviewedBackendControls.js",
  "tools/release/scopedCallableInvokerIamPublic.js",
  "tools/release/scopedCallableInvokerIam.js",
  "tools/release/deploymentFleetContract.js",
  "tools/release/collectProductionGlobalPullBackend.js",
].sort());
const oid = (v) => typeof v === "string" && /^[a-f0-9]{40}$/.test(v);
function need(value, label) {
  if (!value) {
    const error = new Error(`Backend verifier authority: ${label}.`);
    error.code = "VERIFIER_AUTHORITY_REFUSED";
    throw error;
  }
}
function keys(value, expected, label) {
  need(value !== null && typeof value === "object" && !Array.isArray(value) &&
    isDeepStrictEqual(Object.keys(value).sort(), [...expected].sort()), label);
}
function hash(value) {
  need(typeof value === "string" && /^[a-fA-F0-9]{64}$/.test(value), "invalid digest");
  return value.toUpperCase();
}
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
function instant(value) {
  const m = typeof value === "string" && /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  need(m && !m[1].startsWith("0000-"), "invalid UTC timestamp");
  const ms = Date.parse(`${m[1]}Z`);
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 19) === m[1], "invalid UTC calendar");
  return BigInt(ms) * 1000000n + BigInt((m[2] ?? "").padEnd(9, "0"));
}
function normalizeFiles(value) {
  need(Array.isArray(value) && value.length === VERIFIER_FILES.length, "exact verifier file set required");
  const rows = value.map((entry) => {
    keys(entry, ["file", "sha256"], "verifier file entry shape");
    need(VERIFIER_FILES.includes(entry.file), "unsupported verifier file");
    return {file: entry.file, sha256: hash(entry.sha256)};
  }).sort((a, b) => a.file < b.file ? -1 : a.file > b.file ? 1 : 0);
  need(isDeepStrictEqual(rows.map((row) => row.file), [...VERIFIER_FILES]), "duplicate or missing verifier file");
  return rows;
}

function validateVerifierAuthority({repoRoot, verificationAuthority, sourceCommit,
  approvalSha256, observedAtUtc, verifyLoadedFiles = false}) {
  try {
    need(typeof repoRoot === "string" && path.isAbsolute(repoRoot), "repository path required");
    need(oid(sourceCommit) && typeof verifyLoadedFiles === "boolean", "exact source and validation mode required");
    const deploymentHash = hash(approvalSha256), observed = instant(observedAtUtc);
    need(observed <= BigInt(Date.now()) * 1000000n, "future observation refused");
    const a = verificationAuthority;
    keys(a, ["schemaVersion", "profile", "verifierCommit", "verifierFiles", "decision"], "authority shape");
    need(a.schemaVersion === 1 && a.profile === PROFILE && oid(a.verifierCommit), "unsupported verifier profile");
    const files = normalizeFiles(a.verifierFiles);
    keys(a.decision, ["commit", "file", "sha256"], "decision pointer shape");
    need(oid(a.decision.commit) && typeof a.decision.file === "string" &&
      /^release\/approvals\/[A-Za-z0-9][A-Za-z0-9_.-]*\.json$/.test(a.decision.file), "decision custody path invalid");
    const decisionPointer = {...a.decision, sha256: hash(a.decision.sha256)};
    const git = (args) => execFileSync("git", ["--no-replace-objects", "-C", repoRoot, ...args],
      {windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
    const text = (args) => git(args).toString("utf8").trim();
    for (const commit of [sourceCommit, a.verifierCommit, decisionPointer.commit]) {
      need(text(["cat-file", "-t", commit]) === "commit", "authority object is not a commit");
    }
    git(["merge-base", "--is-ancestor", sourceCommit, a.verifierCommit]);
    git(["merge-base", "--is-ancestor", a.verifierCommit, decisionPointer.commit]);
    const blob = (commit, file) => {
      const listing = text(["ls-tree", commit, "--", file]);
      need(/^(?:100644|100755) blob [a-f0-9]{40}\t/.test(listing) &&
        listing.slice(listing.indexOf("\t") + 1) === file, "authority file must be a regular Git blob");
      return git(["show", `${commit}:${file}`]);
    };
    const decisionBytes = blob(decisionPointer.commit, decisionPointer.file);
    need(sha(decisionBytes) === decisionPointer.sha256, "decision bytes differ");
    let decision;
    try { decision = JSON.parse(decisionBytes.toString("utf8")); }
    catch { need(false, "decision JSON invalid"); }
    keys(decision, ["schemaVersion", "evidenceType", "approved", "profile", "sourceCommit",
      "deploymentApprovalSha256", "verifierCommit", "verifierFiles", "decidedAtUtc",
      "authorizationBasis", "cloudMutationAuthorized"], "decision fields invalid");
    need(decision.schemaVersion === 1 && decision.evidenceType === "reviewed-backend-verifier-authorization" &&
      decision.approved === true && decision.profile === PROFILE && decision.sourceCommit === sourceCommit &&
      hash(decision.deploymentApprovalSha256) === deploymentHash && decision.verifierCommit === a.verifierCommit &&
      decision.cloudMutationAuthorized === false && typeof decision.authorizationBasis === "string" &&
      decision.authorizationBasis.trim().length > 0, "decision does not authorize this verification");
    need(isDeepStrictEqual(normalizeFiles(decision.verifierFiles), files), "decision verifier files differ");
    const decided = instant(decision.decidedAtUtc);
    const commitTime = (commit) => {
      const seconds = text(["show", "-s", "--format=%ct", commit]);
      need(/^\d+$/.test(seconds), "invalid commit timestamp");
      return BigInt(seconds) * 1000000000n;
    };
    const sourceTime = commitTime(sourceCommit), verifierTime = commitTime(a.verifierCommit), custodyTime = commitTime(decisionPointer.commit);
    // Git records whole seconds; a decision recorded later within the custody
    // commit's second is supported, while a preceding second is refused.
    need(sourceTime <= verifierTime && verifierTime <= decided && decided < custodyTime + 1000000000n &&
      decided <= observed && custodyTime <= observed,
      "source, verifier, decision, custody and observation chronology differ");
    for (const row of files) {
      const committed = blob(a.verifierCommit, row.file);
      need(sha(committed) === row.sha256, "committed verifier bytes differ");
      if (verifyLoadedFiles) {
        // Bind the directory from which this validator was actually loaded.
        // repoRoot may intentionally be a different deployment checkout.
        const actualPath = path.join(__dirname, path.basename(row.file));
        const before = fs.lstatSync(actualPath, {bigint: true});
        need(before.isFile() && !before.isSymbolicLink(), "loaded verifier must be a regular file");
        const actual = fs.readFileSync(actualPath), after = fs.lstatSync(actualPath, {bigint: true});
        need(before.size === after.size && before.mtimeNs === after.mtimeNs && before.ctimeNs === after.ctimeNs &&
          before.ino === after.ino && BigInt(actual.length) === after.size && sha(actual) === row.sha256,
        "loaded verifier bytes differ");
      }
    }
    return {schemaVersion: 1, profile: PROFILE, verifierCommit: a.verifierCommit,
      verifierFiles: files, decision: decisionPointer};
  } catch (error) {
    if (error?.code === "VERIFIER_AUTHORITY_REFUSED") throw error;
    // Git/filesystem/JSON failures can contain private paths or content.
    need(false, "immutable evidence could not be verified");
  }
}

module.exports = {PROFILE, VERIFIER_FILES, validateVerifierAuthority};
