import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import {verifySource, verifyGraph} from './verify_deepmerge_prototype_guard.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);
const owned = path.join(root, 'tooling/deepmerge-prototype-guard');
const populations = [
  ['owned source', require(path.join(owned, 'index.js'))],
  ...['', 'functions'].map(relative => {
    const population = createRequire(path.join(root, relative, 'package.json'));
    const consumer = createRequire(population.resolve('jest-config/package.json'));
    return [relative || 'root', consumer('deepmerge')];
  }),
];
const attack = () => JSON.parse('{"__proto__":{"isAdmin":true},"safe":1}');
const clean = result => {
  assert.equal(Object.getPrototypeOf(result), Object.prototype);
  assert.equal(Object.hasOwn(result, '__proto__'), false);
  assert.equal(result.isAdmin, undefined);
  assert.equal(Object.prototype.isAdmin, undefined);
  assert.equal(({}).isAdmin, undefined);
};

for (const [name, merge] of populations) {
  test(`${name}: rejects poisoned source for every reported target shape`, () => {
    for (const target of [{}, Object.create(null), null, false, 0, '']) {
      const source = attack();
      const result = merge(target, source);
      clean(result);
      assert.equal(result.safe, 1);
      assert.equal(Object.hasOwn(source, '__proto__'), true, 'caller input is not rewritten');
    }
  });

  test(`${name}: rejects target-copy and nested placeholder poisoning`, () => {
    const target = attack();
    clean(merge(target, {}));
    assert.equal(Object.hasOwn(target, '__proto__'), true);
    for (const placeholder of [null, false, 0, '']) {
      clean(merge({session: placeholder}, {session: attack()}).session);
    }
    clean(merge.all([attack(), {safe: 2}]));
    clean(merge([], [attack()])[0]);
    clean(merge({}, {session: attack()}).session);
  });

  test(`${name}: forbidden getters are never evaluated in either loop`, () => {
    const poisoned = {};
    Object.defineProperty(poisoned, '__proto__', {enumerable: true,
      get() { throw new Error('forbidden getter evaluated'); }});
    clean(merge(poisoned, {}));
    clean(merge(Object.create(null), poisoned));
  });

  test(`${name}: preserves native ordinary keys, symbols, cloning and options`, () => {
    const symbol = Symbol('config');
    const input = {nested: {left: 1}, list: [{a: 1}], [symbol]: {x: 1}};
    const result = merge(input, {nested: {right: 2}, list: [{b: 2}]});
    assert.deepEqual(result, {nested: {left: 1, right: 2}, list: [{a: 1}, {b: 2}], [symbol]: {x: 1}});
    assert.notEqual(result.nested, input.nested);
    assert.notEqual(result.list[0], input.list[0]);
    assert.equal(merge({}, input, {clone: false}).nested, input.nested);
    assert.deepEqual(merge({list: [1]}, {list: [2]}, {arrayMerge: (_a, b) => b}), {list: [2]});
    assert.deepEqual(merge({count: {n: 1}}, {count: {n: 2}}, {
      customMerge: key => key === 'count' ? (a, b) => ({n: a.n + b.n}) : undefined,
    }), {count: {n: 3}});
    const date = new Date('2026-01-01T00:00:00Z'), regex = /test/;
    assert.equal(merge({}, {date}).date, date);
    assert.equal(merge({}, {regex}).regex, regex);
    assert.throws(() => merge.all({}), /first argument should be an array/);
    assert.deepEqual(merge.all([{a: 1}, {b: 2}]), {a: 1, b: 2});
    const ordinary = merge(Object.create(null), {constructor: 'data', prototype: {value: 1}});
    assert.equal(Object.getPrototypeOf(ordinary), Object.prototype);
    assert.deepEqual(ordinary, {constructor: 'data', prototype: {value: 1}});
  });
}

test('both installed Jest populations resolve the exact maintained source', () => {
  verifySource(owned);
  verifyGraph(root, root);
  verifyGraph(root, path.join(root, 'functions'));
});

test('root Jest mergeConfig preserves globals while dropping the poisoned key', () => {
  const rootRequire = createRequire(path.join(root, 'package.json'));
  const {mergeConfig} = rootRequire('jest-config');
  const defaults = {globals: {session: null, enabled: true}, testMatch: ['**/*.test.js']};
  const overrides = {globals: {session: attack(), nested: {value: 2}}};
  const result = mergeConfig(defaults, overrides);
  clean(result.globals.session);
  assert.equal(result.globals.enabled, true);
  assert.deepEqual(result.globals.nested, {value: 2});
  assert.deepEqual(result.testMatch, ['**/*.test.js']);
});

test('source verification rejects changed bytes or an unreviewed runtime file', () => {
  const parent = fs.realpathSync(os.tmpdir());
  const temp = fs.mkdtempSync(path.join(parent, 'deepmerge-source-negative-'));
  assert.equal(path.dirname(temp), parent);
  try {
    fs.cpSync(owned, temp, {recursive: true});
    const entry = path.join(temp, 'index.js');
    const original = fs.readFileSync(entry);
    fs.appendFileSync(entry, '\n// changed\n');
    assert.throws(() => verifySource(temp), /hash/i);
    fs.writeFileSync(entry, original);
    fs.writeFileSync(path.join(temp, 'unexpected.js'), 'module.exports = {};\n');
    assert.throws(() => verifySource(temp), /unreviewed/i);
  } finally {
    assert.equal(path.dirname(fs.realpathSync(temp)), parent);
    fs.rmSync(temp, {recursive: true, force: true});
  }
});

// Resolver-only graphs use owned byte copies and an inert Jest manifest. No
// registry package, package-manager command or synthetic Jest body is executed.
function withGraphFixture(run, functions = false) {
  const parent = fs.realpathSync(os.tmpdir());
  const repository = fs.mkdtempSync(path.join(parent, 'deepmerge-graph-'));
  assert.equal(path.dirname(repository), parent);
  const population = functions ? path.join(repository, 'functions') : repository;
  const spec = functions ? 'file:../tooling/deepmerge-prototype-guard' : 'file:tooling/deepmerge-prototype-guard';
  const copy = target => {
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.cpSync(owned, target, {recursive: true});
  };
  copy(path.join(repository, 'tooling/deepmerge-prototype-guard'));
  copy(path.join(population, 'node_modules/deepmerge'));
  const jest = path.join(population, 'node_modules/jest-config');
  fs.mkdirSync(jest, {recursive: true});
  fs.writeFileSync(path.join(jest, 'package.json'), JSON.stringify({name: 'jest-config', version: '0.0.0-fixture', main: 'index.js'}));
  fs.writeFileSync(path.join(jest, 'index.js'), 'throw Error("resolver fixture must not execute");\n');
  const metadata = {name: 'graph-fixture', version: '1.0.0', devDependencies: {deepmerge: spec}, overrides: {deepmerge: '$deepmerge'}};
  const entry = {name: '@crm3/deepmerge-prototype-guard', version: '4.3.1-b31.1', resolved: spec,
    dev: true, license: 'MIT', engines: {node: '>=0.10.0'}};
  const lock = {name: metadata.name, version: metadata.version, lockfileVersion: 3, packages: {
    '': {name: metadata.name, version: metadata.version, devDependencies: {...metadata.devDependencies}},
    'node_modules/deepmerge': entry,
  }};
  const flush = () => {
    fs.writeFileSync(path.join(population, 'package.json'), JSON.stringify(metadata));
    fs.writeFileSync(path.join(population, 'package-lock.json'), JSON.stringify(lock));
  };
  try {
    flush(); run({repository, population, metadata, lock, entry, copy, jest, flush});
  } finally {
    assert.equal(path.dirname(fs.realpathSync(repository)), parent);
    fs.rmSync(repository, {recursive: true, force: true});
  }
}

for (const functions of [false, true]) test(`exact ${functions ? 'Functions' : 'root'} resolver graph accepts owned copies only`, () => {
  withGraphFixture(f => {
    const result = verifyGraph(f.repository, f.population);
    assert.equal(result.population, functions ? 'functions' : 'root');
    assert.equal(result.installedCopies, 1);
    assert.equal(result.npmAuditSubstitute, false);
  }, functions);
});

for (const [label, mutate, pattern] of [
  ['registry development declaration', f => { f.metadata.devDependencies.deepmerge = '4.3.1'; }, /development local/i],
  ['missing owned override', f => { delete f.metadata.overrides.deepmerge; }, /override/i],
  ['production dependency', f => { f.metadata.dependencies = {deepmerge: '4.3.1'}; }, /production/i],
  ['owned-name production alias', f => { f.metadata.dependencies = {'@crm3/deepmerge-prototype-guard': 'file:tooling/deepmerge-prototype-guard'}; }, /production/i],
  ['optional dependency', f => { f.metadata.optionalDependencies = {deepmerge: '4.3.1'}; }, /optional/i],
  ['bundled development dependency', f => { f.metadata.bundleDependencies = ['deepmerge']; }, /bundled/i],
  ['alternate development alias', f => { f.metadata.devDependencies.other = 'npm:deepmerge@4.3.1'; }, /alias/i],
  ['unbound lock root', f => { f.lock.packages[''].devDependencies.deepmerge = '4.3.1'; }, /development local/i],
  ['production lock root', f => { f.lock.packages[''].dependencies = {deepmerge: '4.3.1'}; }, /production/i],
  ['old upstream lock name', f => { f.entry.name = 'deepmerge'; }, /lock name/i],
  ['unexpected lock version', f => { f.entry.version = '4.3.1'; }, /lock version/i],
  ['registry lock resolution', f => { f.entry.resolved = 'https://registry.npmjs.org/deepmerge/-/deepmerge-4.3.1.tgz'; }, /resolution/i],
  ['production lock entry', f => { f.entry.dev = false; }, /production/i],
  ['linked lock entry', f => { f.entry.link = true; }, /link/i],
  ['unexpected package dependency', f => { f.entry.dependencies = {other: '1.0.0'}; }, /lock fields/i],
  ['hidden old nested entry', f => { f.lock.packages['node_modules/consumer/node_modules/deepmerge'] = {...f.entry, version: '4.3.1'}; }, /lock version/i],
  ['owned-name alternate install', f => { f.lock.packages['node_modules/@crm3/deepmerge-prototype-guard'] = {...f.entry}; }, /alias/i],
  ['owned-name hidden under foreign alias', f => { f.lock.packages['node_modules/other'] = {...f.entry}; }, /alias/i],
  ['parent traversal entry', f => { f.lock.packages['../node_modules/deepmerge'] = {...f.entry}; }, /lock package path/i],
]) test(`dependency graph refuses ${label}`, () => withGraphFixture(f => {
  mutate(f); f.flush();
  assert.throws(() => verifyGraph(f.repository, f.population), pattern);
}));

test('every declared nested owned copy is measured, without broad name-prefix matching', () => withGraphFixture(f => {
  const nested = 'node_modules/consumer/node_modules/deepmerge';
  f.lock.packages[nested] = {...f.entry};
  f.lock.packages['node_modules/deepmerge-unrelated'] = {name: 'deepmerge-unrelated', version: '1.0.0', dev: false};
  f.copy(path.join(f.population, nested)); f.flush();
  assert.equal(verifyGraph(f.repository, f.population).installedCopies, 2);
  fs.appendFileSync(path.join(f.population, nested, 'index.js'), '\n// changed\n');
  assert.throws(() => verifyGraph(f.repository, f.population), /hash/i);
}));

test('Jest cannot resolve an unlocked shadow even when its source bytes are owned', () => withGraphFixture(f => {
  f.copy(path.join(f.jest, 'node_modules/deepmerge'));
  assert.throws(() => verifyGraph(f.repository, f.population), /locked installation/i);
}));

test('exact source population rejects even an unreviewed empty directory', () => withGraphFixture(f => {
  const source = path.join(f.repository, 'tooling/deepmerge-prototype-guard');
  fs.mkdirSync(path.join(source, 'unreviewed'));
  assert.throws(() => verifySource(source), /unreviewed/i);
}));
