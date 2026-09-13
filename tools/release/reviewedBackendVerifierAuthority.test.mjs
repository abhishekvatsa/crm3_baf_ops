import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";
import guard from "./reviewedBackendVerifierAuthority.js";

const {PROFILE, VERIFIER_FILES, validateVerifierAuthority} = guard;
const here = path.dirname(fileURLToPath(import.meta.url));
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const copy = (value) => structuredClone(value);
const approvalSha256 = "A".repeat(64);
const decisionFile = "release/approvals/synthetic-verifier-decision.json";
const times = {source: "2026-09-01T00:00:00Z", verifier: "2026-09-01T00:00:01Z",
  decision: "2026-09-01T00:00:02.235Z", custody: "2026-09-01T00:00:03Z", observed: "2026-09-01T00:00:04Z"};

// Real immutable Git objects, isolated from all application/deployment refs.
// No user identities, network, SDK, dependencies, or production receipts.
function fixture(t) {
  const tempParent = fs.realpathSync(os.tmpdir());
  const root = fs.mkdtempSync(path.join(tempParent, "crm3-verifier-authority-test-"));
  const repoRoot = path.join(root, "objects.git");
  t.after(() => {
    const resolved = fs.realpathSync(root);
    assert.equal(path.dirname(resolved), tempParent);
    assert.ok(path.basename(resolved).startsWith("crm3-verifier-authority-test-"));
    fs.rmSync(resolved, {recursive: true});
  });
  const git = (args, input, env = {}) => execFileSync("git", ["--no-replace-objects", "-C", repoRoot, ...args],
    {input, env: {...process.env, ...env}, windowsHide: true, stdio: ["pipe", "pipe", "pipe"]}).toString("utf8").trim();
  execFileSync("git", ["init", "--bare", repoRoot], {windowsHide: true, stdio: "pipe"});
  const blob = (bytes) => git(["hash-object", "-w", "--stdin"], bytes);
  const tree = (entries) => {
    const dirs = new Map(), rows = [];
    for (const [file, item] of Object.entries(entries)) {
      const slash = file.indexOf("/");
      if (slash < 0) rows.push(`${item.mode ?? "100644"} blob ${blob(item.bytes)}\t${file}`);
      else {
        const name = file.slice(0, slash);
        if (!dirs.has(name)) dirs.set(name, {});
        dirs.get(name)[file.slice(slash + 1)] = item;
      }
    }
    for (const [name, children] of dirs) rows.push(`040000 tree ${tree(children)}\t${name}`);
    return git(["mktree"], rows.sort().join("\n") + "\n");
  };
  const commit = (entries, parent, time) => git(["commit-tree", tree(entries), ...(parent ? ["-p", parent] : [])],
    "Synthetic verifier-authority fixture only\n", {
      GIT_AUTHOR_NAME: "Synthetic test", GIT_AUTHOR_EMAIL: "fixture@example.invalid", GIT_AUTHOR_DATE: time,
      GIT_COMMITTER_NAME: "Synthetic test", GIT_COMMITTER_EMAIL: "fixture@example.invalid", GIT_COMMITTER_DATE: time,
    });
  const base = {"README.txt": {bytes: Buffer.from("Synthetic source; not deployed.\n")}};
  const sourceCommit = commit(base, null, times.source);
  const moduleEntries = Object.fromEntries(VERIFIER_FILES.map((file) => [file,
    {bytes: fs.readFileSync(path.join(here, path.basename(file)))}]));
  const entries = {...base, ...moduleEntries};
  const verifierCommit = commit(entries, sourceCommit, times.verifier);
  const verifierFiles = VERIFIER_FILES.map((file) => ({file, sha256: sha(moduleEntries[file].bytes)}));
  const make = ({changeDecision = () => {}, decisionBytes, parent = verifierCommit, custody = times.custody,
    decisionMode = "100644", selectedCommit = verifierCommit, selectedFiles = verifierFiles} = {}) => {
    const decision = {schemaVersion: 1, evidenceType: "reviewed-backend-verifier-authorization", approved: true,
      profile: PROFILE, sourceCommit, deploymentApprovalSha256: approvalSha256, verifierCommit: selectedCommit,
      verifierFiles: copy(selectedFiles), decidedAtUtc: times.decision,
      authorizationBasis: "Synthetic offline test only; no operational authorization.", cloudMutationAuthorized: false};
    changeDecision(decision);
    const bytes = decisionBytes ?? Buffer.from(JSON.stringify(decision));
    const decisionCommit = commit({...entries, [decisionFile]: {bytes, mode: decisionMode}}, parent, custody);
    return {repoRoot, sourceCommit, approvalSha256, observedAtUtc: times.observed,
      verificationAuthority: {schemaVersion: 1, profile: PROFILE, verifierCommit: selectedCommit,
        verifierFiles: copy(selectedFiles), decision: {commit: decisionCommit, file: decisionFile, sha256: sha(bytes)}}};
  };
  return {root, repoRoot, git, make, commit, entries, moduleEntries, sourceCommit, verifierCommit, verifierFiles};
}

function refused(input, pattern = /^Backend verifier authority:/) {
  assert.throws(() => validateVerifierAuthority(input), (error) => {
    assert.equal(error.code, "VERIFIER_AUTHORITY_REFUSED");
    assert.match(error.message, pattern);
    return true;
  });
}

test("offline authority uses exact immutable Git blobs without a current checkout or installed dependencies", (t) => {
  const f = fixture(t), input = f.make();
  assert.equal(fs.existsSync(path.join(f.repoRoot, "tools")), false);
  assert.equal(fs.existsSync(path.join(f.repoRoot, "functions/node_modules")), false);
  const result = validateVerifierAuthority(input);
  assert.deepEqual(result, input.verificationAuthority);
  assert.notEqual(result, input.verificationAuthority);
});

test("generation binds the selected loaded directory, not a different execution repo's tools", (t) => {
  const f = fixture(t), input = f.make(), loaded = path.join(f.root, "selected-tools");
  fs.mkdirSync(loaded);
  fs.mkdirSync(path.join(f.repoRoot, "tools/release"), {recursive: true});
  for (const [file, item] of Object.entries(f.moduleEntries)) {
    fs.writeFileSync(path.join(loaded, path.basename(file)), item.bytes);
    fs.writeFileSync(path.join(f.repoRoot, file), "Deliberately unrelated execution checkout bytes.\n");
  }
  const selected = createRequire(import.meta.url)(path.join(loaded, "reviewedBackendVerifierAuthority.js"));
  assert.deepEqual(selected.validateVerifierAuthority({...input, verifyLoadedFiles: true}), input.verificationAuthority);
  fs.appendFileSync(path.join(loaded, "reviewedBackendControls.js"), "\n// changed after approval\n");
  assert.throws(() => selected.validateVerifierAuthority({...input, verifyLoadedFiles: true}), /loaded verifier bytes differ/);
  // Historical publication remains verifiable using committed bytes only.
  assert.deepEqual(selected.validateVerifierAuthority(input), input.verificationAuthority);
});

test("digests are normalized and verifier rows have one deterministic order", (t) => {
  const f = fixture(t), input = f.make();
  input.verificationAuthority.verifierFiles.reverse();
  for (const row of input.verificationAuthority.verifierFiles) row.sha256 = row.sha256.toLowerCase();
  input.verificationAuthority.decision.sha256 = input.verificationAuthority.decision.sha256.toLowerCase();
  input.approvalSha256 = input.approvalSha256.toLowerCase();
  const result = validateVerifierAuthority(input);
  assert.deepEqual(result.verifierFiles, f.verifierFiles);
  assert.match(result.decision.sha256, /^[A-F0-9]{64}$/);
});

for (const [label, mutate] of [
  ["unsupported profile", (a) => { a.profile = "legacy-unapproved"; }],
  ["extra authority property", (a) => { a.cloudMutationAuthorized = true; }],
  ["missing verifier", (a) => { a.verifierFiles.pop(); }],
  ["duplicate verifier", (a) => { a.verifierFiles[1] = copy(a.verifierFiles[0]); }],
  ["unreviewed seventh file", (a) => { a.verifierFiles.push({file: "tools/release/extra.js", sha256: "B".repeat(64)}); }],
  ["path traversal", (a) => { a.verifierFiles[0].file = "tools/release/../private.js"; }],
  ["unbound file hash", (a) => { a.verifierFiles[0].sha256 = "B".repeat(64); }],
  ["unbound decision hash", (a) => { a.decision.sha256 = "B".repeat(64); }],
  ["decision outside approval custody", (a) => { a.decision.file = "output/private-decision.json"; }],
  ["decision pointer extra keys", (a) => { a.decision.authorized = true; }],
]) {
  test(`refuses ${label}`, (t) => {
    const f = fixture(t), input = f.make();
    mutate(input.verificationAuthority);
    refused(input);
  });
}

for (const [label, mutate] of [
  ["another deployment source", (d) => { d.sourceCommit = "b".repeat(40); }],
  ["another deployment approval", (d) => { d.deploymentApprovalSha256 = "B".repeat(64); }],
  ["another verifier commit", (d) => { d.verifierCommit = "b".repeat(40); }],
  ["another verifier file digest", (d) => { d.verifierFiles[0].sha256 = "B".repeat(64); }],
  ["another decision profile", (d) => { d.profile = "other"; }],
  ["unapproved decision", (d) => { d.approved = false; }],
  ["cloud mutation authorization", (d) => { d.cloudMutationAuthorized = true; }],
  ["empty authorization basis", (d) => { d.authorizationBasis = " \n "; }],
  ["extra decision fields", (d) => { d.unknownAuthority = true; }],
  ["decision before verifier", (d) => { d.decidedAtUtc = times.source; }],
  ["impossible calendar", (d) => { d.decidedAtUtc = "2026-02-30T00:00:00.000Z"; }],
  ["offset timestamp", (d) => { d.decidedAtUtc = "2026-09-01T00:00:02+00:00"; }],
]) {
  test(`refuses immutable decision with ${label}`, (t) => refused(fixture(t).make({changeDecision: mutate})));
}

test("cannot bind a decision from an unrelated branch or a source outside verifier ancestry", (t) => {
  const f = fixture(t), unrelated = f.commit({"unrelated.txt": {bytes: "unrelated"}}, null, times.source);
  refused(f.make({parent: unrelated}));
  const input = f.make();
  input.sourceCommit = unrelated;
  refused(input);
});

test("git commit objects are required and symlink decision blobs are refused", (t) => {
  const f = fixture(t), input = f.make();
  input.verificationAuthority.verifierCommit = f.git(["rev-parse", `${f.verifierCommit}^{tree}`]);
  refused(input, /not a commit/);
  refused(f.make({decisionMode: "120000"}), /regular Git blob/);
});

test("all six actual committed file bytes must match even when decision agrees with the wrong hash", (t) => {
  const f = fixture(t), wrong = copy(f.verifierFiles);
  wrong[0].sha256 = "B".repeat(64);
  refused(f.make({selectedFiles: wrong}), /committed verifier bytes differ/);
});

test("symlink verifier files cannot stand in for the reviewed implementation", (t) => {
  const f = fixture(t), entries = {...f.entries}, file = VERIFIER_FILES[0];
  entries[file] = {bytes: Buffer.from("../../unreviewed.js"), mode: "120000"};
  const selectedCommit = f.commit(entries, f.sourceCommit, times.verifier);
  const selectedFiles = f.verifierFiles.map((row) => row.file === file ? {...row, sha256: sha(entries[file].bytes)} : row);
  refused(f.make({selectedCommit, selectedFiles, parent: selectedCommit}), /regular Git blob/);
});

test("whole-second Git custody supports the same-second real decision without accepting an earlier second", (t) => {
  const f = fixture(t);
  validateVerifierAuthority(f.make({custody: "2026-09-01T00:00:02Z"}));
  refused(f.make({custody: "2026-09-01T00:00:01Z"}), /chronology/);
  const input = f.make({custody: "2026-09-01T00:00:02Z"});
  input.observedAtUtc = "2026-09-01T00:00:02.100Z";
  refused(input, /chronology/);
});

test("future observations and observation before immutable custody are refused", (t) => {
  const f = fixture(t), input = f.make();
  input.observedAtUtc = new Date(Date.now() + 60000).toISOString();
  refused(input, /future observation/);
  input.observedAtUtc = "2026-09-01T00:00:02.500Z";
  refused(input, /chronology/);
});

test("malformed JSON and Git errors never disclose retained private payloads or paths", (t) => {
  const f = fixture(t), canary = "PRIVATE-CANARY-person@example.invalid";
  const malformed = f.make({decisionBytes: Buffer.from(`{"secret":"${canary}", malformed`)});
  for (const input of [malformed, {...f.make(), repoRoot: path.join(f.root, canary)}]) {
    assert.throws(() => validateVerifierAuthority(input), (error) => {
      assert.equal(error.code, "VERIFIER_AUTHORITY_REFUSED");
      assert.equal(error.message.includes(canary), false);
      assert.equal(error.message.includes(f.root), false);
      return true;
    });
  }
});
