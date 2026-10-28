import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const OWNER = '@crm3/deepmerge-prototype-guard';
const VERSION = '4.3.1-b31.1';
const ORIGINAL = '2E5160F84A1141BD927264AFE4D15766F1E6CF07DAEF182B37FF53FEA121DE7D';
const EXPECTED_FILES = Object.freeze({
  'index.d.ts': ['146BA4B99C5FEB82663E17A671BF9F53BB39C704CD76345D6C5A801C26372F44', 823],
  'index.js': ['976C91F003A1FC609EBE2017BABDA35EB15DCB972C4BC868637626D3850C2756', 4117],
  'license.txt': ['6CFC4687CB2F2D86F4A77E6B526290D3878E5E512F3FEC2F4CB36A9CB36F798B', 1116],
  'package.json': ['6EB4AF902B1B4EFA3DD749E16ECDA9895BE19D9CE8715B048443F5E33C917755', 436],
  'patches/EXACT_INVERSE_SUBSTITUTIONS.json': ['179D39A031ADAFD9465C380045BF384724A20F070F15A87A76E117074975F98D', 797],
  'patches/EXACT_SUBSTITUTIONS.json': ['996054A9CC8A0C011C44869735B7DE2D906BD800D630AD0A3FBE6801672178D9', 797],
  'patches/forward.patch': ['366B8A4C87EA42DEA26DDBF7353E86EA25F139C1952B487BBA2BA5C8EFCF9864', 459],
  'patches/inverse.patch': ['AA9F14F4BDEBEA2A52F991648885A5207A73D20870CAA8DC3646647C39E6DECD', 459],
  'README.md': ['906C30FE7B87F199F929FAECF848A6FE9B18A99FF76F2B58BCE038F7724D4F59', 1487],
  'UPSTREAM.json': ['C700F1C827091DCF04C872C2D5BB0182F56D60E9113B06A99D45A21591783C2E', 3786],
});
const sha = bytes => createHash('sha256').update(bytes).digest('hex').toUpperCase();
const inside = (root, file) => {
  const relative = path.relative(root, file);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`));
};
function directory(file) {
  const absolute = path.resolve(file);
  let current = path.parse(absolute).root;
  for (const part of absolute.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    const stat = fs.lstatSync(current);
    assert.ok(!stat.isSymbolicLink() && stat.isDirectory(), `Directory link/non-directory refused: ${current}`);
  }
  return fs.realpathSync(absolute);
}
function bytes(file) {
  const before = fs.lstatSync(file, {bigint: true});
  assert.ok(before.isFile() && !before.isSymbolicLink() && before.nlink === 1n, `Regular unlinked source file required: ${file}`);
  assert.ok(before.size <= 8n * 1024n * 1024n, `Source/graph file exceeds bound: ${file}`);
  const value = fs.readFileSync(file), after = fs.lstatSync(file, {bigint: true});
  for (const field of ['dev', 'ino', 'size', 'mtimeNs', 'ctimeNs', 'nlink']) assert.equal(after[field], before[field], `Source changed: ${file}`);
  assert.equal(BigInt(value.length), before.size, `Source length changed: ${file}`);
  return value;
}
const json = file => JSON.parse(bytes(file).toString('utf8'));
function substitute(input, rows) {
  let output = input;
  for (const row of rows) {
    assert.equal(row.occurrences, 1, 'One exact reviewed substitution required');
    assert.equal(output.split(row.before).length - 1, 1, 'Exact substitution occurrence differs');
    output = output.replace(row.before, row.after);
  }
  return output;
}

export function verifySource(packageDirectory) {
  const root = directory(packageDirectory), found = [], captured = new Map();
  function walk(current, prefix = '') {
    for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      assert.ok(!entry.isSymbolicLink(), `Unreviewed source link: ${relative}`);
      if (entry.isDirectory()) {
        assert.equal(relative, 'patches', `Unreviewed source directory: ${relative}`);
        walk(path.join(current, entry.name), relative);
      } else {
        assert.ok(entry.isFile() && Object.hasOwn(EXPECTED_FILES, relative), `Unreviewed source file: ${relative}`);
        const value = bytes(path.join(current, entry.name)), [digest, size] = EXPECTED_FILES[relative];
        assert.equal(sha(value), digest, `Reviewed source hash differs: ${relative}`);
        assert.equal(value.length, size, `Reviewed source length differs: ${relative}`);
        found.push(relative); captured.set(relative, value);
      }
    }
  }
  walk(root);
  assert.deepEqual(found.sort(), Object.keys(EXPECTED_FILES).sort(), 'Exact ten reviewed source files required');
  const metadata = JSON.parse(captured.get('package.json'));
  assert.equal(metadata.name, OWNER); assert.equal(metadata.version, VERSION); assert.equal(metadata.private, true);
  assert.equal(metadata.main, 'index.js'); assert.equal(metadata.types, 'index.d.ts');
  const upstream = JSON.parse(captured.get('UPSTREAM.json'));
  assert.equal(upstream.productionDependencyAllowed, false);
  assert.equal(upstream.packageIdentity.officialUpstreamPatchedRelease, false);
  const forward = JSON.parse(captured.get('patches/EXACT_SUBSTITUTIONS.json'));
  const inverse = JSON.parse(captured.get('patches/EXACT_INVERSE_SUBSTITUTIONS.json'));
  assert.equal(forward.substitutions.length, 2); assert.equal(inverse.substitutions.length, 2);
  assert.equal(forward.source.sha256, ORIGINAL); assert.equal(inverse.target.sha256, ORIGINAL);
  const changed = captured.get('index.js').toString('utf8');
  const original = Buffer.from(substitute(changed, inverse.substitutions));
  assert.equal(original.length, 4048, 'Exact inverse original length differs');
  assert.equal(sha(original), ORIGINAL, 'Exact inverse original hash differs');
  assert.equal(substitute(original.toString('utf8'), forward.substitutions), changed, 'Exact forward source differs');
  assert.equal((changed.match(/key === '__proto__'/g) ?? []).length, 2, 'Exactly two literal prototype refusals required');
  return root;
}

const names = new Set(['deepmerge', OWNER]);
function dependencyReference(name, value) {
  return names.has(name) || (typeof value === 'string' &&
    (/^npm:(?:deepmerge|@crm3\/deepmerge-prototype-guard)(?:@|$)/.test(value) ||
      value === 'file:tooling/deepmerge-prototype-guard' || value === 'file:../tooling/deepmerge-prototype-guard'));
}
function developmentOnly(metadata, expected) {
  assert.equal(metadata.devDependencies?.deepmerge, expected, 'Exact development local deepmerge dependency required');
  for (const kind of ['dependencies', 'optionalDependencies', 'peerDependencies']) {
    for (const [name, value] of Object.entries(metadata[kind] ?? {})) {
      assert.ok(!dependencyReference(name, value), `Production/optional/peer deepmerge dependency refused: ${kind}.${name}`);
    }
  }
  for (const [name, value] of Object.entries(metadata.devDependencies ?? {})) {
    if (name !== 'deepmerge') assert.ok(!dependencyReference(name, value), `Unexpected deepmerge development alias: ${name}`);
  }
  for (const kind of ['bundleDependencies', 'bundledDependencies']) {
    const selected = metadata[kind];
    assert.ok(selected !== true && !(Array.isArray(selected) && selected.some(name => names.has(name))),
      `Bundled development deepmerge dependency refused: ${kind}`);
  }
}
function installName(key) {
  assert.ok(typeof key === 'string' && !key.includes('\\') && !key.includes(':') &&
    key.split('/').every(part => part && part !== '.' && part !== '..'), `Unexpected lock package path: ${key}`);
  assert.ok(/^node_modules\/(?:@[^/]+\/)?[^/]+(?:\/node_modules\/(?:@[^/]+\/)?[^/]+)*$/.test(key), `Unexpected deepmerge lock entry: ${key}`);
  return key.slice(key.lastIndexOf('node_modules/') + 'node_modules/'.length);
}

export function verifyGraph(repository, populationDirectory) {
  const root = directory(repository), population = directory(populationDirectory);
  assert.ok(population === root || population === path.join(root, 'functions'), 'Only root and Functions development populations are selected');
  const owned = verifySource(path.join(root, 'tooling/deepmerge-prototype-guard'));
  const expected = population === root ? 'file:tooling/deepmerge-prototype-guard' : 'file:../tooling/deepmerge-prototype-guard';
  const metadata = json(path.join(population, 'package.json')), lock = json(path.join(population, 'package-lock.json'));
  developmentOnly(metadata, expected);
  assert.equal(metadata.overrides?.deepmerge, '$deepmerge', 'Owned $deepmerge override is mandatory');
  assert.equal(directory(path.resolve(population, expected.slice(5))), owned, 'Local dependency must select this repository owner');
  assert.equal(lock.lockfileVersion, 3, 'Exact npm lockfile v3 required');
  assert.ok(lock.packages && !Array.isArray(lock.packages) && typeof lock.packages === 'object', 'Lock packages required');
  const lockRoot = lock.packages[''];
  assert.ok(lockRoot && typeof lockRoot === 'object', 'Lock root binding required');
  developmentOnly(lockRoot, expected);
  assert.equal(lockRoot.name, metadata.name, 'Lock root package name differs');
  assert.equal(lockRoot.version, metadata.version, 'Lock root package version differs');
  const entries = Object.entries(lock.packages).filter(([key, value]) =>
    /(?:^|\/)node_modules\/(?:deepmerge|@crm3\/deepmerge-prototype-guard)$/.test(key) || names.has(value?.name));
  assert.ok(entries.some(([key]) => key === 'node_modules/deepmerge'), 'Direct owned deepmerge lock entry required');
  const installedEntries = [];
  for (const [key, value] of entries) {
    assert.equal(installName(key), 'deepmerge', `Unexpected owned-name/foreign install alias: ${key}`);
    assert.ok(value && typeof value === 'object' && !Array.isArray(value), `Deepmerge lock entry object required: ${key}`);
    assert.deepEqual(Object.keys(value).sort(), ['dev', 'engines', 'license', 'name', 'resolved', 'version'], `Unexpected/link deepmerge lock fields: ${key}`);
    assert.equal(value.name, OWNER, `Unowned deepmerge lock name: ${key}`);
    assert.equal(value.version, VERSION, `Unreviewed deepmerge lock version: ${key}`);
    assert.equal(value.resolved, expected, `Registry/unexpected deepmerge resolution: ${key}`);
    assert.equal(value.dev, true, `Production deepmerge lock entry: ${key}`);
    assert.equal(value.license, 'MIT'); assert.deepEqual(value.engines, {node: '>=0.10.0'});
    const installed = directory(path.resolve(population, key));
    assert.ok(inside(root, installed), `Owned installed package escaped repository: ${key}`);
    verifySource(installed);
    installedEntries.push(path.join(installed, 'index.js'));
  }
  const caller = createRequire(path.join(population, 'package.json'));
  const jestManifest = caller.resolve('jest-config/package.json');
  assert.ok(inside(path.join(population, 'node_modules'), jestManifest), 'Each population must resolve its own installed Jest config');
  directory(path.dirname(jestManifest)); bytes(jestManifest);
  const resolved = [caller.resolve('deepmerge'), createRequire(jestManifest).resolve('deepmerge')];
  for (const entry of resolved) {
    const installed = verifySource(path.dirname(entry));
    assert.ok(inside(root, installed), 'Jest/direct deepmerge entry escaped repository');
    assert.ok(installedEntries.includes(path.join(installed, 'index.js')) && path.resolve(entry) === path.join(installed, 'index.js'),
      'Jest/direct entry must match an exact owned locked installation');
  }
  return {population: population === root ? 'root' : 'functions', installedCopies: installedEntries.length,
    jestDeepmergeEntry: resolved[1], npmAuditSubstitute: false};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2] ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  console.log(JSON.stringify({status: 'passed exact deepmerge repair source, development graphs and installed Jest resolution',
    populations: [verifyGraph(root, root), verifyGraph(root, path.join(root, 'functions'))], npmAuditSubstitute: false}));
}
