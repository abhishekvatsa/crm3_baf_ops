'use strict';
// Unprivileged input checks only. Trusted platform identity and actual private
// replay must be established separately before any credential is acquired.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {isDeepStrictEqual} = require('node:util');
const {TextDecoder} = require('node:util');
const PROFILE = 'build31-business-trusted-input-v1';
const BOOTSTRAP_PATH = 'tools/release/business31TrustedInput.cjs';
const MAX_OUTPUT = 16 * 1024 * 1024;
const MAX_BLOB = 2 * 1024 * 1024;
const BATCH_OBJECTS = 7;
const METADATA_PATHS = Object.freeze([
  'README.md', 'release/production-release-policy.json',
  'release/build-number-ledger.json', 'release/current-successor-state.json',
  'release/approvals/version-policy-approval.json',
  'release/approvals/build-number-31-successor-approval.json',
  'release/approvals/build31-private-cloud-custody-approval.json',
  'release/approvals/build31-app-check-client-approval.json',
  'release/approvals/public-repository-environment-reviewer-approval-build-31.json',
  'release/approvals/build31-business-backend-deployment-approval.json',
  'release/approvals/build31-business-backend-owner-authorization.json',
  'release/evidence/build31-business-backend-main-ci.json',
  'release/evidence/build31-business-backend-main-security.json',
  'release/evidence/build31-business-backend-local-proof.json',
  'release/evidence/build31-business-backend-deployment-closure.json',
  'release/approvals/build31-business-client-compatibility-approval.json',
  'release/approvals/build31-business-client-owner-authorization.json',
  'release/evidence/build31-business-private-replay.json',
]);
function need(value, message) { if (!value) throw new Error(message); }
function hash(bytes) { return crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase(); }
function hex(value, size) { return typeof value === 'string' && new RegExp(`^[0-9a-f]{${size}}$`, 'i').test(value); }
function oid(value) { need(hex(value, 40), 'Exact 40-character Git object required'); return value.toLowerCase(); }
function decode(bytes) { return new TextDecoder('utf-8', {fatal: true}).decode(bytes); }
function exactKeys(value, keys, label) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    isDeepStrictEqual(Object.keys(value).sort(), [...keys].sort()), `${label}: exact keys required`);
}
function safePath(value) {
  need(typeof value === 'string' && value.length > 0 && value.length <= 1024 &&
    !/[\\:\x00-\x1f\x7f<>"|?*]/.test(value) && !value.startsWith('/') &&
    value.split('/').every(part => part && part !== '.' && part !== '..' &&
      !/[. ]$/.test(part) && part.toLowerCase() !== '.git' &&
      !/^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(part)), 'Unsafe Git path');
  return value;
}
function regularAbsolute(value, kind) {
  need(typeof value === 'string' && path.isAbsolute(value), 'Absolute local path required');
  const resolved = path.resolve(value);
  let current = path.parse(resolved).root;
  for (const part of resolved.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    need(!fs.lstatSync(current).isSymbolicLink(), 'Redirected local path refused');
  }
  const stat = fs.lstatSync(resolved);
  need(kind === 'directory' ? stat.isDirectory() : stat.isFile(), `Regular ${kind} required`);
  return resolved;
}
function configBytes(gitDirectory) {
  const file = path.join(gitDirectory, 'config');
  need(fs.statSync(file).size <= 65536, 'Git configuration exceeds bound');
  const bytes = fs.readFileSync(file);
  const text = decode(bytes);
  // A private input repository needs only storage and inert remote/branch
  // declarations. Unknown configuration is refused rather than interpreted.
  let section = '';
  const allowed = {
    core: new Set(['repositoryformatversion', 'filemode', 'bare', 'logallrefupdates', 'symlinks', 'ignorecase', 'longpaths']),
    remote: new Set(['url', 'fetch']), branch: new Set(['remote', 'merge']),
  };
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || /^[#;]/.test(line)) continue;
    const header = /^\[(core|remote|branch)(?:\s+"[^"\\\x00-\x1f]+")?\]$/i.exec(line);
    if (header) { section = header[1].toLowerCase(); continue; }
    const entry = /^([a-z][a-z0-9]*)\s*=\s*([^\r\n]*)$/i.exec(line);
    need(entry && allowed[section]?.has(entry[1].toLowerCase()) && !line.endsWith('\\'), 'Unadmitted Git configuration');
    if (section === 'core' && entry[1].toLowerCase() === 'bare') need(entry[2] === 'false', 'Bare repository refused');
    if (section === 'core' && entry[1].toLowerCase() === 'repositoryformatversion') need(entry[2] === '0', 'Unsupported Git repository format');
  }
  return bytes;
}
function parseBlobBatch31(output, expectedOids) {
  need(Buffer.isBuffer(output) && output.length <= MAX_OUTPUT, 'Batch output exceeds bound');
  need(Array.isArray(expectedOids) && expectedOids.length > 0 && expectedOids.length <= BATCH_OBJECTS &&
    expectedOids.every(value => typeof value === 'string' && /^[0-9a-f]{40}$/.test(value)) &&
    new Set(expectedOids).size === expectedOids.length, 'Exact bounded batch OIDs required');
  const blobs = new Map();
  let offset = 0;
  for (const expected of expectedOids) {
    const end = output.indexOf(10, offset);
    need(end >= offset && end - offset <= 64, 'Batch object header missing or oversized');
    const header = output.subarray(offset, end);
    need(header.every(byte => byte >= 32 && byte <= 126), 'Batch object header is not ASCII');
    const match = /^([0-9a-f]{40}) blob (0|[1-9][0-9]*)$/.exec(header.toString('ascii'));
    need(match && match[1] === expected, 'Batch object identity/type/order differs');
    const size = Number(match[2]);
    need(Number.isSafeInteger(size) && size <= MAX_BLOB, 'Git blob exceeds bound');
    const start = end + 1, finish = start + size;
    need(finish < output.length && output[finish] === 10, 'Batch object body or separator truncated');
    const bytes = Buffer.from(output.subarray(start, finish));
    const actual = crypto.createHash('sha1').update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest('hex');
    need(actual === expected, 'Git blob content hash differs');
    blobs.set(expected, bytes);
    offset = finish + 1;
  }
  need(offset === output.length, 'Trailing batch output refused');
  return blobs;
}
function openTrustedGitRepository31({repositoryRoot, gitExecutable, gitSha256}) {
  const root = regularAbsolute(repositoryRoot, 'directory');
  const executable = regularAbsolute(gitExecutable, 'file');
  need(hex(gitSha256, 64) && hash(fs.readFileSync(executable)) === gitSha256.toUpperCase(), 'Git executable digest differs');
  const gitDirectory = regularAbsolute(path.join(root, '.git'), 'directory');
  function layout() {
    // Includes loose refs/objects: no junction, symlink or special member may
    // redirect any object lookup outside this private, self-contained input.
    let entries = 0;
    const pending = [gitDirectory];
    while (pending.length) {
      const directory = pending.pop();
      for (const row of fs.readdirSync(directory, {withFileTypes: true})) {
        need(++entries <= 100000, 'Git directory population exceeds bound');
        const file = path.join(directory, row.name);
        const stat = fs.lstatSync(file);
        need(!stat.isSymbolicLink() && (stat.isFile() || stat.isDirectory()), 'Git indirection refused');
        if (stat.isDirectory()) pending.push(file);
      }
    }
    for (const relative of ['commondir', 'gitdir', 'objects/info/alternates', 'objects/info/http-alternates', 'info/grafts', 'config.worktree', 'shallow']) {
      need(!fs.existsSync(path.join(gitDirectory, relative)), 'External or incomplete Git state refused');
    }
    return hash(configBytes(gitDirectory));
  }
  const configHash = layout();
  const env = {};
  for (const key of ['SystemRoot', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP', 'PATH', 'PATHEXT', 'LANG', 'LC_ALL']) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  Object.assign(env, {GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
    GIT_TERMINAL_PROMPT: '0', GIT_PAGER: 'cat', GIT_OPTIONAL_LOCKS: '0', GIT_NO_LAZY_FETCH: '1'});
  function git(args, maxBuffer = MAX_OUTPUT, batchInput) {
    if (batchInput !== undefined) {
      need(isDeepStrictEqual(args, ['cat-file', '--batch']) && maxBuffer === MAX_OUTPUT &&
        Buffer.isBuffer(batchInput) && batchInput.length > 0 && batchInput.length <= BATCH_OBJECTS * 41 &&
        /^(?:[0-9a-f]{40}\n){1,7}$/.test(batchInput.toString('ascii')) &&
        batchInput.every(byte => byte === 10 || (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)),
      'Only fixed bounded blob-batch stdin is permitted');
    }
    need(layout() === configHash && hash(fs.readFileSync(executable)) === gitSha256.toUpperCase(), 'Git runtime/configuration changed');
    const result = execFileSync(executable, ['--no-replace-objects', '--no-pager', '--no-optional-locks',
      '-c', 'core.fsmonitor=false', '-c', `core.hooksPath=${path.join(gitDirectory, 'disabled-hooks-31')}`,
      '-c', 'core.untrackedCache=false', '-c', 'core.preloadIndex=false', '-c', 'diff.external=',
      '-c', 'credential.helper=', '-c', 'protocol.allow=never', '-C', root, ...args],
    {env, windowsHide: true, timeout: 30000, maxBuffer,
      stdio: [batchInput === undefined ? 'ignore' : 'pipe', 'pipe', 'pipe'],
      ...(batchInput === undefined ? {} : {input: batchInput})});
    need(layout() === configHash, 'Git configuration changed during read');
    if (batchInput !== undefined) need(hash(fs.readFileSync(executable)) === gitSha256.toUpperCase(), 'Git runtime changed during batch read');
    return result;
  }
  const text = args => decode(git(args)).trim();
  need(path.resolve(text(['rev-parse', '--show-toplevel'])) === root, 'Git root differs');
  need(text(['rev-parse', '--show-object-format']) === 'sha1', 'Unsupported Git object format');
  const issuedSnapshots = new WeakSet();
  function snapshot(commit) {
    commit = oid(commit);
    // Strict object verification is independent of an object's storage filename.
    // The hosting controller must keep this private input repository exclusive.
    git(['fsck', '--full', '--strict', '--no-reflogs', '--no-dangling', commit]);
    need(text(['rev-parse', '--verify', `${commit}^{commit}`]) === commit, 'Commit identity differs');
    const tree = oid(text(['rev-parse', `${commit}^{tree}`]));
    const ancestry = text(['rev-list', '--parents', '-n', '1', commit]).split(' ');
    need(ancestry.shift() === commit, 'Commit ancestry identity differs');
    const parents = ancestry.map(oid);
    const files = Object.create(null);
    const folded = new Map();
    const rows = decode(git(['ls-tree', '-r', '-z', commit])).split('\0');
    need(rows.pop() === '' && rows.length <= 10000, 'Complete bounded tree required');
    for (const row of rows) {
      const match = /^(100644|100755) blob ([0-9a-f]{40})\t([\s\S]+)$/.exec(row);
      need(match, 'Git tree requires regular files only');
      const file = safePath(match[3]);
      const parts = file.split('/');
      for (let count = 1; count <= parts.length; count++) {
        const spelling = parts.slice(0, count).join('/');
        const key = spelling.normalize('NFC').toLowerCase();
        need(!folded.has(key) || folded.get(key) === spelling, 'Git tree path collision');
        folded.set(key, spelling);
      }
      need(!Object.hasOwn(files, file), 'Duplicate Git tree path');
      files[file] = Object.freeze({mode: match[1], oid: match[2]});
    }
    const result = Object.freeze({commit, tree, parents: Object.freeze(parents), files: Object.freeze(files)});
    issuedSnapshots.add(result);
    return result;
  }
  function readBlob(commit, file, maxBytes = MAX_BLOB) {
    const expression = `${oid(commit)}:${safePath(file)}`;
    need(Number.isSafeInteger(maxBytes) && maxBytes > 0 && maxBytes <= MAX_BLOB, 'Blob limit outside fixed bound');
    need(text(['cat-file', '-t', expression]) === 'blob', 'Blob object required');
    const size = Number(text(['cat-file', '-s', expression]));
    need(Number.isSafeInteger(size) && size >= 0 && size <= maxBytes, 'Git blob exceeds bound');
    const bytes = git(['cat-file', 'blob', expression], maxBytes + 1024);
    need(bytes.length === size, 'Git blob size differs');
    const expected = oid(text(['rev-parse', '--verify', expression]));
    const actual = crypto.createHash('sha1').update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest('hex');
    need(actual === expected, 'Git blob content hash differs');
    return bytes;
  }
  function readSnapshotBlobs(snapshot) {
    need(issuedSnapshots.has(snapshot), 'Snapshot was not issued by this repository');
    need(layout() === configHash && hash(fs.readFileSync(executable)) === gitSha256.toUpperCase(), 'Git runtime/configuration changed');
    const names = Object.keys(snapshot.files).sort();
    const unique = [...new Set(names.map(name => snapshot.files[name].oid))];
    const blobs = new Map();
    for (let index = 0; index < unique.length; index += BATCH_OBJECTS) {
      const chunk = unique.slice(index, index + BATCH_OBJECTS);
      const input = Buffer.from(chunk.map(value => value + '\n').join(''), 'ascii');
      const parsed = parseBlobBatch31(git(['cat-file', '--batch'], MAX_OUTPUT, input), chunk);
      for (const [object, bytes] of parsed) blobs.set(object, bytes);
    }
    // No partial population escapes on failure. Equal-content paths receive
    // detached buffers so callers cannot mutate another path through an alias.
    const result = new Map();
    for (const name of names) result.set(name, Buffer.from(blobs.get(snapshot.files[name].oid)));
    return result;
  }
  function requireAncestor(ancestor, descendant) {
    try { git(['merge-base', '--is-ancestor', oid(ancestor), oid(descendant)]); }
    catch (error) { if (error.status === 1) throw new Error('Required Git ancestry absent'); throw error; }
  }
  function readRef(ref) {
    need(typeof ref === 'string' && /^refs\/(?:heads|remotes)\/[A-Za-z0-9][A-Za-z0-9._\/-]*$/.test(ref) &&
      !ref.includes('..') && !ref.endsWith('/') && !ref.endsWith('.lock') && !ref.includes('//'), 'Exact local branch reference required');
    return oid(text(['rev-parse', '--verify', `${ref}^{commit}`]));
  }
  return Object.freeze({snapshot, readBlob, readSnapshotBlobs, requireAncestor, readRef});
}
function boundedJson(bytes) {
  const value = JSON.parse(decode(bytes));
  need(value && typeof value === 'object' && !Array.isArray(value), 'Metadata JSON object required');
  const pending = [[value, 0]]; let nodes = 0;
  while (pending.length) {
    const [item, depth] = pending.pop();
    need(++nodes <= 50000 && depth <= 32, 'Metadata JSON structure exceeds bound');
    if (item && typeof item === 'object') for (const child of Object.values(item)) pending.push([child, depth + 1]);
  }
}
function pubspecBoundary(before, after) {
  const expression = /^version: [0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\+[0-9]+\r?$/gm;
  const oldText = decode(before), newText = decode(after);
  const oldLines = oldText.match(expression), newLines = newText.match(expression);
  need(oldLines?.length === 1 && newLines?.length === 1 && /\+31\r?$/.test(newLines[0]) &&
    oldText.replace(expression, 'version: <bound>') === newText.replace(expression, 'version: <bound>'),
  'Only the Build31 pubspec version line may change');
}
function verifyBusiness31TrustedInput({repositoryRoot, gitExecutable, gitSha256, envelope}) {
  exactKeys(envelope, ['schemaVersion', 'profile', 'verifier', 'source', 'candidate'], 'Input envelope');
  need(envelope.schemaVersion === 1 && envelope.profile === PROFILE, 'Input envelope version/profile differs');
  exactKeys(envelope.verifier, ['commit', 'tree', 'files'], 'Verifier binding');
  exactKeys(envelope.source, ['commit', 'tree'], 'Source binding');
  exactKeys(envelope.candidate, ['commit', 'tree', 'ref'], 'Candidate binding');
  const repository = openTrustedGitRepository31({repositoryRoot, gitExecutable, gitSha256});
  const refBefore = repository.readRef(envelope.candidate.ref);
  const verifier = repository.snapshot(envelope.verifier.commit);
  const source = repository.snapshot(envelope.source.commit);
  const candidate = repository.snapshot(envelope.candidate.commit);
  for (const [actual, declared] of [[verifier, envelope.verifier], [source, envelope.source], [candidate, envelope.candidate]]) {
    need(actual.tree === oid(declared.tree), 'Declared complete tree differs');
  }
  need(refBefore === candidate.commit, 'Candidate reference differs');
  repository.requireAncestor(verifier.commit, source.commit);
  repository.requireAncestor(source.commit, candidate.commit);
  need(source.parents.length === 2, 'Source M requires its normal two-parent merge');
  const bindings = envelope.verifier.files;
  need(bindings && typeof bindings === 'object' && !Array.isArray(bindings) &&
    Object.keys(bindings).length > 0 && Object.keys(bindings).length <= 256 &&
    Object.hasOwn(bindings, BOOTSTRAP_PATH), 'Finite trusted verifier binding required');
  for (const [file, digest] of Object.entries(bindings)) {
    safePath(file); need(hex(digest, 64), 'Verifier digest required');
    const expected = verifier.files[file];
    need(expected && expected.mode === '100644' && isDeepStrictEqual(expected, source.files[file]) &&
      isDeepStrictEqual(expected, candidate.files[file]), 'Trusted verifier source changed');
    need(hash(repository.readBlob(verifier.commit, file)) === digest.toUpperCase(), 'Trusted verifier digest differs');
  }
  need(hash(fs.readFileSync(__filename)) === bindings[BOOTSTRAP_PATH].toUpperCase(), 'Executing bootstrap differs from V');
  const changed = [];
  for (const file of new Set([...Object.keys(source.files), ...Object.keys(candidate.files)])) {
    const before = source.files[file], after = candidate.files[file];
    if (isDeepStrictEqual(before, after)) continue;
    need(after && after.mode === '100644' && (!before || before.mode === '100644'), 'Metadata deletion or mode change refused');
    if (file === 'pubspec.yaml') {
      need(before, 'Existing pubspec required');
      pubspecBoundary(repository.readBlob(source.commit, file), repository.readBlob(candidate.commit, file));
    } else {
      need(METADATA_PATHS.includes(file), `Non-metadata source changed: ${file}`);
      const bytes = repository.readBlob(candidate.commit, file);
      if (file.endsWith('.json')) boundedJson(bytes); else decode(bytes);
    }
    changed.push(file);
  }
  need(repository.readRef(envelope.candidate.ref) === refBefore, 'Candidate reference moved during inspection');
  return Object.freeze({schemaVersion: 1, profile: PROFILE, verifierCommit: verifier.commit,
    sourceCommit: source.commit, sourceTree: source.tree, sourceParents: source.parents,
    candidateCommit: candidate.commit, candidateTree: candidate.tree, candidateParents: candidate.parents,
    fileCount: Object.keys(candidate.files).length, changedPaths: Object.freeze(changed.sort()),
    inputBoundaryVerified: true, metadataContentsValidated: false, platformIdentityAuthenticated: false,
    privateReplayVerified: false, deploymentAuthorized: false, constructionAuthorized: false});
}
module.exports = {openTrustedGitRepository31, verifyBusiness31TrustedInput, parseBlobBatch31, PROFILE, METADATA_PATHS};
