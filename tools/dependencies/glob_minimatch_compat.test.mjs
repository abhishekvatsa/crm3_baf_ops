import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath, pathToFileURL } from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scopes = [root, path.join(root, 'functions'), path.join(root, 'tooling/firebase-cli')];
const normalized = value => value.replace(/\\/g, '/');
const {loadPinnedFilter, uploadIgnoreStrings, listNativeFiles} = createRequire(import.meta.url)('./firebase_upload_filter_fixture.cjs');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-glob-compat-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(directory)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(directory).startsWith('crm3-glob-compat-'));
    assert.equal(fs.lstatSync(directory).isSymbolicLink(), false);
    fs.rmSync(directory, {recursive: true});
  });
  for (const name of ['src/alpha.js', 'src/Beta.js', 'src/zeta.js', 'src/ignored.js',
    'src/.hidden.js', 'test/skipped.js', 'node_modules/pkg/skipped.js']) {
    const filename = path.join(directory, name);
    fs.mkdirSync(path.dirname(filename), {recursive: true});
    fs.writeFileSync(filename, 'module.exports = 1;\n');
  }
  return directory;
}

function installedRequire(scope) {
  return createRequire(path.join(scope, 'package.json'));
}

function assertInstalledAdapter(consumer, dependency, sourceName) {
  const source = path.join(root, 'tooling', sourceName);
  const metadata = JSON.parse(fs.readFileSync(path.join(source, 'package.json'), 'utf8'));
  const installed = path.dirname(consumer.resolve(`${dependency}/package.json`));
  for (const name of ['package.json', ...metadata.files]) {
    assert.deepEqual(fs.readFileSync(path.join(installed, name)), fs.readFileSync(path.join(source, name)),
      `${dependency} installed source ${name}`);
  }
}

// Exact normal exports from the integrity-checked glob 14.0.2 registry archive.
// This finite proof does not cover /raw or infer an embedded matcher version.
const glob14 = {
  'package.json': 'E4CE88C70993AB99E6DE06671345C22D0306ABEF0FF62FB81C227BB2DD3A4CF2',
  'dist/commonjs/index.min.js': 'F32848848F1B4A52AE62F1EC4D209B69A825CE7FDF5735B1E3237E2202A03604',
  'dist/esm/index.min.js': '399221C4E0D6FF9994D284C9402105738721572D9F8532C94649826FF5C7E207',
};
const bundleLoads = ['node:diagnostics_channel', 'node:events', 'node:stream',
  'node:string_decoder', 'node:path', 'node:url', 'node:url', 'fs', 'node:fs', 'node:fs/promises'];
const checkedGlobBundles = new Map();

function assertGlob14Bundles(packageFile) {
  const directory = path.dirname(packageFile);
  if (checkedGlobBundles.has(directory)) return checkedGlobBundles.get(directory);
  const parser = createRequire(installedRequire(root).resolve('@babel/core/package.json'))('@babel/parser');
  const metadata = JSON.parse(fs.readFileSync(packageFile, 'utf8'));
  assert.equal(metadata.name, 'glob');
  assert.equal(metadata.version, '14.0.2');
  assert.equal(metadata.main, './dist/commonjs/index.min.js');
  assert.equal(metadata.exports['.'].require.default, './dist/commonjs/index.min.js');
  assert.equal(metadata.exports['.'].import.default, './dist/esm/index.min.js');
  const entries = {};
  for (const [relative, expected] of Object.entries(glob14)) {
    const filename = path.join(directory, relative);
    const bytes = fs.readFileSync(filename);
    assert.equal(createHash('sha256').update(bytes).digest('hex').toUpperCase(), expected, filename);
    if (relative === 'package.json') continue;
    const esm = relative.includes('/esm/');
    const ast = parser.parse(bytes.toString('utf8'), {sourceType: esm ? 'module' : 'script'});
    const loads = [];
    function visit(node, parent) {
      if (!node || typeof node !== 'object') return;
      if (Array.isArray(node)) {for (const item of node) visit(item, parent); return;}
      assert.notEqual(node.type, 'ImportExpression', 'no dynamic import in exact normal bundles');
      if (node.type === 'ImportDeclaration') {
        assert.equal(esm, true);
        assert.equal(node.source.type, 'StringLiteral');
        loads.push(node.source.value);
      }
      if (node.type === 'Identifier' && node.name === 'require') {
        assert.equal(esm, false);
        assert.equal(parent?.type, 'CallExpression');
        assert.equal(parent.callee, node, 'no require aliases or require.resolve');
        assert.equal(parent.arguments.length, 1);
        assert.equal(parent.arguments[0].type, 'StringLiteral');
        loads.push(parent.arguments[0].value);
      }
      if (node.type === 'Identifier' && ['eval', 'Function', 'createRequire'].includes(node.name)) {
        assert.fail(`Unexpected loader/code-generation identifier: ${node.name}`);
      }
      if (node.type === 'CallExpression') assert.notEqual(node.callee.type, 'Import');
      if (node.type === 'Identifier' && node.name === 'module') {
        assert.equal(parent?.type, 'MemberExpression');
        assert.equal(parent.object, node);
        assert.equal(parent.computed, false);
        assert.equal(parent.property.name, 'exports');
      }
      for (const [key, value] of Object.entries(node)) {
        if (!['loc', 'start', 'end', 'extra', 'comments', 'tokens'].includes(key)) visit(value, node);
      }
    }
    visit(ast, null);
    assert.deepEqual(loads.sort(), [...bundleLoads].sort(), 'exact literal builtin loader closure');
    entries[esm ? 'esm' : 'cjs'] = filename;
  }
  checkedGlobBundles.set(directory, entries);
  console.log('PASS_GLOB14_NORMAL_BUNDLE_SOURCE ' + JSON.stringify({packageFile, ...entries,
    packageVersion: '14.0.2', loaderClosure: '10 literal Node builtin imports per bundle',
    minimatchLockMetadata: 'UNUSED', excludedRoute: '/raw'}));
  return entries;
}

for (const scope of scopes) {
  const label = path.relative(root, scope) || '.';
  test(`${label}: every locked glob/minimatch implementation is the exact patched version`, () => {
    const packages = JSON.parse(fs.readFileSync(path.join(scope, 'package-lock.json'), 'utf8')).packages;
    for (const [name, version] of [['glob', '14.0.2'], ['minimatch', '11.0.1']]) {
      const rows = Object.entries(packages).filter(([key, value]) =>
        key.includes('node_modules/') && (value.name === name
          || new RegExp(`(?:^|/)node_modules/${name}(?:-modern|-legacy-compat|-v3-compat)?$`).test(key)));
      assert.ok(rows.length > 0, `${label} must lock ${name}`);
      for (const [key, value] of rows) {
        if (name === 'glob' && value.name === 'crm3-glob-legacy-compat') {
          assert.equal(value.version, '1.0.0', `${label}:${key} adapter identity`);
          assert.equal(value.dependencies['glob-modern'], 'npm:glob@14.0.2');
          assert.equal(value.dependencies['minimatch-modern'], 'npm:minimatch@11.0.1');
        } else if (name === 'minimatch'
          && ['crm3-minimatch-compat', 'crm3-minimatch-v3-compat'].includes(value.name)) {
          assert.equal(value.version, '1.0.0', `${label}:${key} adapter identity`);
          assert.equal(value.dependencies['minimatch-modern'], 'npm:minimatch@11.0.1');
        } else {
          assert.equal(value.version, version, `${label}:${key}`);
        }
        assert.equal(value.link, undefined, `${label}:${key} must be materialized`);
        if (name === 'glob' && value.name !== 'crm3-glob-legacy-compat') {
          assertGlob14Bundles(path.join(scope, key, 'package.json'));
        }
      }
    }
    for (const [key, value] of Object.entries(packages)) {
      if (value.dependencies?.minimatch && key.includes('node_modules/')) {
        const consumer = createRequire(path.join(scope, key, 'package.json'));
        const metadata = consumer('minimatch/package.json');
        const parent = JSON.parse(fs.readFileSync(path.join(scope, key, 'package.json'), 'utf8'));
        const unused = parent.name === 'glob' && parent.version === '14.0.2';
        const legacy = /^\^3\./.test(value.dependencies.minimatch);
        if (unused) {
          assertGlob14Bundles(path.join(scope, key, 'package.json'));
          assert.ok(['crm3-minimatch-v3-compat', 'crm3-minimatch-compat'].includes(metadata.name));
        } else {
          assert.equal(metadata.name, legacy ? 'crm3-minimatch-v3-compat' : 'crm3-minimatch-compat',
            `${key} actual minimatch parent`);
        }
        assertInstalledAdapter(consumer, 'minimatch', metadata.name === 'crm3-minimatch-v3-compat'
          ? 'minimatch-v3-compat' : 'minimatch-compat');
        assert.equal(metadata.version, '1.0.0');
        if (!unused) assert.equal(typeof consumer('minimatch'), 'function', `${key} callable minimatch`);
        const upstream = createRequire(consumer.resolve('minimatch/package.json'));
        assert.equal(upstream('minimatch-modern/package.json').version, '11.0.1');
        console.log('PASS_DEPENDENCY_PARENT_RESOLUTION ' + JSON.stringify({scope: label,
          parent: key, dependency: 'minimatch', requestedRange: value.dependencies.minimatch,
          resolvedEntry: consumer.resolve('minimatch'), resolvedPackage: consumer.resolve('minimatch/package.json'),
          provider: metadata.name, providerVersion: metadata.version, coreVersion: '11.0.1',
          role: unused ? 'UNUSED_GLOB14_LOCK_METADATA' : legacy ? 'v3-callable' : 'general-native',
          callable: unused ? null : typeof consumer('minimatch') === 'function',
          namedClass: unused ? null : typeof consumer('minimatch').Minimatch}));
      }
      const range = value.dependencies?.glob;
      if (!range || !key.includes('node_modules/')) continue;
      const consumer = createRequire(path.join(scope, key, 'package.json'));
      const metadata = consumer('glob/package.json');
      if (/^\^7\./.test(range)) {
        assert.equal(metadata.name, 'crm3-glob-legacy-compat');
        assert.equal(metadata.version, '1.0.0');
        assert.equal(typeof consumer('glob'), 'function', `${key} legacy callback export`);
        assert.equal(metadata.dependencies['glob-modern'], 'npm:glob@14.0.2');
        assertInstalledAdapter(consumer, 'glob', 'glob-compat');
      } else {
        assert.equal(metadata.name, 'glob');
        assert.equal(metadata.version, '14.0.2');
        assert.equal(metadata.dependencies['glob-modern'], undefined, `${key} retains registry glob`);
        assert.equal(consumer.resolve('glob'), assertGlob14Bundles(consumer.resolve('glob/package.json')).cjs,
          `${key} actual consumer selects the normal bundled entry, never /raw`);
        assert.equal(typeof consumer('glob').glob, 'function');
      }
      console.log('PASS_DEPENDENCY_PARENT_RESOLUTION ' + JSON.stringify({scope: label,
        parent: key, dependency: 'glob', requestedRange: range,
        resolvedEntry: consumer.resolve('glob'), resolvedPackage: consumer.resolve('glob/package.json'),
        provider: metadata.name, providerVersion: metadata.version, coreVersion: '14.0.2',
        role: /^\^7\./.test(range) ? 'legacy-callback-sync' : 'native',
        callable: typeof consumer('glob') === 'function',
        namedGlob: typeof consumer('glob').glob, sync: typeof consumer('glob').sync}));
    }
  });

  test(`${label}: minimatch callable, defaults, class and ESM exports use patched upstream`, async () => {
    const require = installedRequire(scope);
    const mm = require('minimatch');
    assertInstalledAdapter(require, 'minimatch', 'minimatch-compat');
    assert.equal(require('minimatch/package.json').name, 'crm3-minimatch-compat');
    assert.equal(require('minimatch/package.json').version, '1.0.0');
    const upstreamRequire = createRequire(require.resolve('minimatch/package.json'));
    assert.equal(upstreamRequire('minimatch-modern/package.json').name, 'minimatch');
    assert.equal(upstreamRequire('minimatch-modern/package.json').version, '11.0.1');
    const upstream = upstreamRequire('minimatch-modern');
    assert.equal(typeof mm, 'function');
    assert.equal(mm.minimatch, mm);
    for (const key of Object.keys(upstream)) assert.equal(mm[key], upstream[key], key);
    assert.equal(mm('src/alpha.js', 'src/{alpha,beta}.js'), true);
    assert.equal(mm('src/other.js', 'src/{alpha,beta}.js'), false);
    assert.equal(mm('literal[0].js', 'literal\\[0\\].js'), true, '5/6 escaped patterns stay escaped');
    assert.equal(mm(path.join('src', '.hidden.js'), '*.js', {dot: true, matchBase: true}), true);
    const defaults = mm.defaults({nocase: true, dot: true});
    assert.equal(defaults('src/.HIDDEN.JS', '**/*.js'), true);
    assert.equal(defaults('src/A.JS', '**/*.js', {nocase: false}), false);
    assert.equal(new defaults.Minimatch('**/*.js').match('src/A.JS'), true);
    assert.deepEqual(['a.js', 'b.txt'].filter(defaults.filter('*.JS')), ['a.js']);
    assert.equal(new (mm.Minimatch.defaults({nocase: true}))('*.JS').match('a.js'), true);
    const esm = await import(pathToFileURL(path.join(path.dirname(require.resolve('minimatch/package.json')), 'index.mjs')));
    assert.equal(esm.default, esm.minimatch);
    assert.equal(esm.default.Minimatch, esm.Minimatch);
    assert.equal(esm.default.GLOBSTAR, esm.GLOBSTAR);
    assert.equal(esm.default.defaults, esm.defaults);
    assert.equal(esm.minimatch('x.js', '*.js'), true);
    assert.equal(esm.escape('a*b'), 'a\\*b');
  });

  test(`${label}: exact v3 callable consumers retain native Windows pattern normalization`, () => {
    const require = installedRequire(scope);
    const mm = require('minimatch-v3-compat');
    assertInstalledAdapter(require, 'minimatch-v3-compat', 'minimatch-v3-compat');
    assert.equal(require('minimatch-v3-compat/package.json').name, 'crm3-minimatch-v3-compat');
    assert.equal(require('minimatch-v3-compat/package.json').version, '1.0.0');
    const upstream = createRequire(require.resolve('minimatch-v3-compat/package.json'));
    assert.equal(upstream('minimatch-modern/package.json').version, '11.0.1');
    assert.equal(mm('src/file.js', ' src/*.js '), true, 'v3 pattern trim');
    const filename = path.join(os.tmpdir(), 'crm3-native-pattern', 'nested', 'file.js');
    const pattern = path.join(os.tmpdir(), 'crm3-native-pattern', '**', '*.js');
    assert.equal(mm(filename, pattern, {dot: true}), true);
    assert.equal(mm('literal[0].js', 'literal\\[0\\].js', {allowWindowsEscape: true}), true);
    assert.equal(mm('literal[0].js', 'literal\\[0\\].js'), process.platform !== 'win32');
  });
}

test('every installed glob 14 normal CJS/ESM bundle runs with external packages refused', t => {
  const directory = fixture(t);
  const packages = new Set();
  for (const scope of scopes) {
    const locked = JSON.parse(fs.readFileSync(path.join(scope, 'package-lock.json'), 'utf8')).packages;
    for (const [key, value] of Object.entries(locked)) {
      if (!key.includes('node_modules/') || value.version !== '14.0.2') continue;
      const filename = path.join(scope, key, 'package.json');
      const metadata = JSON.parse(fs.readFileSync(filename, 'utf8'));
      if (metadata.name === 'glob') packages.add(filename);
    }
  }
  assert.ok(packages.size >= scopes.length);
  const driver = String.raw`
    import assert from 'node:assert/strict';
    import {createRequire, registerHooks, isBuiltin} from 'node:module';
    import {pathToFileURL} from 'node:url';
    import path from 'node:path';
    const [cjs, esm, cwd] = process.argv.slice(1);
    const entryUrls = new Set([pathToFileURL(cjs).href, pathToFileURL(esm).href]);
    const entrySpecifiers = new Set([cjs, esm, ...entryUrls]);
    const builtins = new Set(['node:diagnostics_channel', 'node:events', 'node:stream',
      'node:string_decoder', 'node:path', 'node:url', 'node:fs', 'node:fs/promises']);
    const canonical = name => name.startsWith('node:') ? name : 'node:' + name;
    const observed = [];
    let denied = 0;
    registerHooks({
      resolve(specifier, context, nextResolve) {
        if (!(isBuiltin(specifier) && builtins.has(canonical(specifier)))
          && !entrySpecifiers.has(specifier)) {
          denied++;
          throw new Error('External package refused: ' + specifier);
        }
        const result = nextResolve(specifier, context);
        assert.ok(entryUrls.has(result.url)
          || (isBuiltin(result.url) && builtins.has(canonical(result.url))));
        observed.push({specifier, url: result.url});
        return result;
      },
      load(url, context, nextLoad) {
        assert.ok(entryUrls.has(url) || (isBuiltin(url) && builtins.has(canonical(url))));
        return nextLoad(url, context);
      },
    });
    const require = createRequire(import.meta.url);
    assert.throws(() => require('minimatch'), /External package refused/);
    await assert.rejects(import('minimatch'), /External package refused/);
    assert.equal(denied, 2, 'both CJS and ESM negative loader cases are refused');
    const before = denied;
    const commonjs = require(cjs);
    const module = await import(pathToFileURL(esm).href);
    const expected = ['.hidden.js', 'Beta.js', 'alpha.js', 'zeta.js']
      .map(name => path.join('src', name)).sort();
    for (const api of [commonjs, module]) {
      assert.equal(typeof api.Glob, 'function');
      assert.equal(typeof api.globSync, 'function');
      const result = api.globSync('src/*.js', {cwd, nodir: true, dot: true, ignore: ['**/ignored.js']});
      assert.deepEqual(result.sort(), expected);
      assert.deepEqual(new api.Glob('src/*.js', {cwd, nodir: true, dot: true,
        ignore: ['**/ignored.js']}).walkSync().sort(), expected);
    }
    assert.equal(denied, before, 'normal bundle execution made no refused loader request');
    assert.ok(observed.some(row => row.url === pathToFileURL(cjs).href));
    assert.ok(observed.some(row => row.url === pathToFileURL(esm).href));
    console.log(JSON.stringify({normalEntries: [...entryUrls], observed,
      expectedFenceRefusals: 2, bundleExecutionRefusals: denied - before}));
  `;
  for (const packageFile of packages) {
    const entries = assertGlob14Bundles(packageFile);
    const output = execFileSync(process.execPath,
      ['--input-type=module', '-e', driver, entries.cjs, entries.esm, directory],
      {cwd: directory, encoding: 'utf8', timeout: 10000, maxBuffer: 1024 * 1024});
    const result = JSON.parse(output.trim());
    assert.equal(result.expectedFenceRefusals, 2);
    assert.equal(result.bundleExecutionRefusals, 0);
    console.log('PASS_GLOB14_NORMAL_BUNDLE_RUNTIME ' + JSON.stringify({packageFile, ...result}));
  }
});

test('all local adapter archives contain exactly the frozen source bytes', async () => {
  const {t: list} = installedRequire(path.join(root, 'tooling/firebase-cli'))('tar');
  for (const name of ['glob-compat', 'minimatch-compat', 'minimatch-v3-compat']) {
    const source = path.join(root, 'tooling', name);
    const metadata = JSON.parse(fs.readFileSync(path.join(source, 'package.json'), 'utf8'));
    const files = ['package.json', ...metadata.files];
    const expected = new Map(files.map(file => [`package/${file}`, fs.readFileSync(path.join(source, file))]));
    const entries = new Set();
    const pending = [];
    await list({file: path.join(root, 'tooling', `${name}.tgz`), strict: true,
      onReadEntry(entry) {
        assert.equal(entry.type, 'File', 'only whitelisted regular files are packed');
        assert.ok(expected.has(entry.path), `Unlisted archive member: ${entry.path}`);
        assert.equal(entries.has(entry.path), false, 'no repeated archive member');
        entries.add(entry.path);
        const wanted = expected.get(entry.path);
        assert.equal(entry.size, wanted.length);
        assert.equal(entry.mode & 0o777, 0o644);
        pending.push(new Promise((resolve, reject) => {
          const chunks = [];
          entry.on('data', chunk => chunks.push(chunk));
          entry.on('error', reject);
          entry.on('end', () => {
            try {assert.deepEqual(Buffer.concat(chunks), wanted); resolve();} catch (error) {reject(error);}
          });
        }));
      }});
    await Promise.all(pending);
    assert.deepEqual([...entries].sort(), [...expected.keys()].sort());
  }
});

for (const scope of scopes.slice(0, 2)) {
  const label = path.relative(root, scope) || '.';
  test(`${label}: legacy glob supports callback, promisify, sorting, nonull and native Windows patterns`, async t => {
    const directory = fixture(t);
    const require = installedRequire(scope);
    const glob = require('glob-legacy-compat');
    assertInstalledAdapter(require, 'glob-legacy-compat', 'glob-compat');
    const upstreamRequire = createRequire(require.resolve('glob-legacy-compat/package.json'));
    assert.equal(require('glob-legacy-compat/package.json').name, 'crm3-glob-legacy-compat');
    assert.equal(require('glob-legacy-compat/package.json').version, '1.0.0');
    assert.equal(upstreamRequire('glob-modern/package.json').name, 'glob');
    assert.equal(upstreamRequire('glob-modern/package.json').version, '14.0.2');
    assert.equal(upstreamRequire.resolve('glob-modern'),
      assertGlob14Bundles(upstreamRequire.resolve('glob-modern/package.json')).cjs,
      'legacy adapter actual alias selects the normal bundled entry, never /raw');
    console.log('PASS_DEPENDENCY_PARENT_RESOLUTION ' + JSON.stringify({scope: label,
      parent: require.resolve('glob-legacy-compat/package.json'), dependency: 'glob-modern',
      requestedRange: 'npm:glob@14.0.2', resolvedEntry: upstreamRequire.resolve('glob-modern'),
      resolvedPackage: upstreamRequire.resolve('glob-modern/package.json'),
      provider: 'glob', providerVersion: '14.0.2', coreVersion: '14.0.2', role: 'native-bundled-alias'}));
    const upstream = upstreamRequire('glob-modern');
    assert.equal(glob.glob, upstream.glob);
    assert.equal(glob.globSync, upstream.globSync);
    assert.equal(glob.Glob, upstream.Glob);
    const opts = {cwd: directory, nodir: true, dot: true, ignore: ['**/ignored.js', '**/node_modules/**']};
    const expected = ['src/.hidden.js', 'src/alpha.js', 'src/Beta.js', 'src/zeta.js'];
    assert.deepEqual(glob.sync('src/*.js', opts), expected);
    const unsorted = upstream.globSync('src/*.js', {...opts, windowsPathsNoEscape: process.platform === 'win32'});
    assert.deepEqual(glob.sync('src/*.js', {...opts, nosort: true}), unsorted.map(normalized));
    assert.deepEqual(glob.sync('src/{alpha,missing}.js', {...opts, nonull: true}), ['src/alpha.js', 'src/missing.js']);
    assert.deepEqual(await promisify(glob)('src/*.js', opts), expected);
    assert.deepEqual(promisify(glob).sync('src/*.js', opts), expected);
    let calls = 0;
    await new Promise((resolve, reject) => {
      const returned = glob('src/*.js', opts, (error, matches) => {
        calls++;
        if (error) return reject(error);
        try {assert.deepEqual(matches, expected); resolve();} catch (cause) {reject(cause);}
      });
      assert.equal(returned, undefined);
    });
    assert.equal(calls, 1);
    assert.deepEqual(glob.sync(path.join(directory, 'src', '*.js'), {nodir: true}),
      ['alpha.js', 'Beta.js', 'ignored.js', 'zeta.js'].map(name => normalized(path.join(directory, 'src', name))));
    assert.throws(() => glob.sync('*.js', () => {}), /callback provided/);
    assert.throws(() => glob.sync('*.js', {withFileTypes: true}), /Use named glob/);
    let errorCalls = 0;
    await new Promise(resolve => glob(42, {}, error => {
      errorCalls++;
      assert.ok(error instanceof Error);
      resolve();
    }));
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(errorCalls, 1);
  });

  test(`${label}: actual test-exclude 6 async/sync consumers enumerate the same coverage files`, async t => {
    const directory = fixture(t);
    const require = installedRequire(scope);
    const TestExclude = require('test-exclude');
    const exclude = new TestExclude({cwd: directory, include: ['src/**'], exclude: ['**/ignored.js'], extension: ['.js']});
    const expected = ['src/.hidden.js', 'src/alpha.js', 'src/Beta.js', 'src/zeta.js'];
    assert.deepEqual(exclude.globSync(), expected);
    assert.deepEqual(await exclude.glob(), expected);
    assert.equal(exclude.shouldInstrument(path.join(directory, 'src/alpha.js')), true);
    assert.equal(exclude.shouldInstrument(path.join(directory, 'src/ignored.js')), false);
  });
}

test('Functions Jest 29 runs its actual coverage reporter with a glob threshold', t => {
  const directory = fixture(t);
  const scope = path.join(root, 'functions');
  const require = installedRequire(scope);
  assert.equal(require('jest/package.json').version, '29.7.0');
  fs.writeFileSync(path.join(directory, 'src/value.cjs'), 'exports.add = (a, b) => a + b;\n');
  fs.writeFileSync(path.join(directory, 'case.test.cjs'),
    "const {add}=require('./src/value.cjs');test('covered',()=>expect(add(2,3)).toBe(5));\n");
  const coverageDirectory = path.join(directory, 'coverage');
  const config = {rootDir: directory, testMatch: ['<rootDir>/case.test.cjs'], transform: {},
    collectCoverageFrom: ['src/value.cjs'], coverageDirectory,
    coverageReporters: ['json-summary'],
    coverageThreshold: {[normalized(path.join(directory, 'src/*.cjs'))]: {lines: 100, statements: 100}}};
  execFileSync(process.execPath, [require.resolve('jest/bin/jest'), '--runInBand', '--coverage',
    '--config', JSON.stringify(config)],
  {cwd: directory, timeout: 60000, maxBuffer: 4 * 1024 * 1024, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
  const summary = JSON.parse(fs.readFileSync(path.join(coverageDirectory, 'coverage-summary.json'), 'utf8'));
  assert.equal(summary.total.lines.pct, 100);
  assert.equal(summary.total.statements.pct, 100);
});

test('actual CLI readdir-glob and Superstatic consumers retain matching and exclusion', async t => {
  const directory = fixture(t);
  const require = installedRequire(path.join(root, 'tooling/firebase-cli'));
  const readdir = require('readdir-glob');
  const files = await new Promise((resolve, reject) => readdir(directory,
    {pattern: '**/*.js', dot: true, nodir: true, ignore: '**/ignored.js', skip: ['node_modules', 'test']},
    (error, matches) => error ? reject(error) : resolve(matches)));
  assert.deepEqual(files.map(normalized).sort(), ['src/.hidden.js', 'src/Beta.js', 'src/alpha.js', 'src/zeta.js'].sort());
  const {configMatcher} = require('superstatic/lib/utils/patterns');
  assert.equal(configMatcher('/assets/example.js', {source: '/assets/**'}), true);
  assert.equal(configMatcher('/elsewhere/example.js', {source: '/assets/**'}), false);
  assert.equal(configMatcher('/.well-known/file', {source: '/.well-known/**'}), true);
  assert.equal(configMatcher('/assets/literal[0].js', {source: '/assets/literal\\[0\\].js'}), true);
});

test('actual Functions upload filter excludes configured files at every directory depth', async t => {
  const directory = fixture(t);
  const cliRoot = path.join(root, 'tooling/firebase-cli');
  const require = installedRequire(cliRoot);
  const actualParent = createRequire(require.resolve('firebase-tools/lib/fsAsync.js'));
  assert.equal(actualParent('minimatch/package.json').name, 'crm3-minimatch-v3-compat');
  assert.equal(actualParent('minimatch/package.json').version, '1.0.0');
  assert.equal(typeof actualParent('minimatch'), 'function');
  const counts = {readdir: 0, stat: 0, contentReads: 0};
  for (const name of ['.keep', '.env.production', '.env.demo-unit', 'notes.local',
    '.runtimeconfig.json', 'firebase-debug.log', 'firebase-debug.12.log',
    'nested/keep.js', 'nested/.hidden', 'nested/.env.demo-test', 'nested/config.local',
    'nested/firebase-debug.34.log', 'nested/.runtimeconfig.json',
    'nested/node_modules/pkg/skip.js', 'nested/.git/skip.js']) {
    const filename = path.join(directory, name);
    fs.mkdirSync(path.dirname(filename), {recursive: true});
    fs.writeFileSync(filename, 'synthetic filter fixture\n');
  }
  const filter = loadPinnedFilter(cliRoot, actualParent('minimatch'), counts);
  const files = await listNativeFiles(filter, directory, uploadIgnoreStrings(root, cliRoot));
  const selected = files.map(file => normalized(path.relative(directory, file.name))).sort();
  assert.deepEqual(selected, ['.env.production', '.keep', 'nested/.hidden', 'nested/keep.js',
    'src/.hidden.js', 'src/Beta.js', 'src/alpha.js', 'src/ignored.js', 'src/zeta.js', 'test/skipped.js'].sort());
  assert.equal(counts.contentReads, 0);
  assert.ok(files.every(file => path.isAbsolute(file.name) && Number.isInteger(file.mode)));
});

test('patched minimatch bounds globparts amplification at optimization level 2', () => {
  const require = installedRequire(path.join(root, 'tooling/firebase-cli'));
  const code = `const assert=require('node:assert/strict');const mm=require(process.argv[1]);
    const m=new mm.Minimatch(process.argv[2],{optimizationLevel:2,braceExpandMax:64});
    assert.ok(m.globParts.length>0);assert.ok(m.globParts.length<=64);`;
  execFileSync(process.execPath, ['-e', code, require.resolve('minimatch'),
    'a/**/../b/'.repeat(18) + 'target.js'],
  {timeout: 5000, maxBuffer: 1024 * 1024, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
});

for (const mode of ['glob', 'globStream']) {
  test(`patched ${mode} stops filesystem traversal after in-flight cancellation`, async t => {
    const directory = fixture(t);
    const require = installedRequire(path.join(root, 'tooling/firebase-cli'));
    const glob = require('glob');
    const controller = new AbortController();
    const reason = new Error('controlled traversal cancellation');
    let reads = 0;
    let atAbort;
    const abortOnce = () => {
      if (!controller.signal.aborted) {atAbort = reads; controller.abort(reason);}
    };
    const wrappedFs = {...fs, readdir(...args) {
      reads++;
      const callback = args.pop();
      fs.readdir(...args, (error, entries) => {
        abortOnce();
        callback(error, entries);
      });
    }, promises: {...fs.promises, async readdir(...args) {
      reads++;
      const entries = await fs.promises.readdir(...args);
      abortOnce();
      return entries;
    }}};
    const options = {cwd: directory, fs: wrappedFs, signal: controller.signal};
    await assert.rejects(async () => {
      if (mode === 'glob') await glob.glob('**/*', options);
      else for await (const unused of glob.globStream('**/*', options)) void unused;
    }, /controlled traversal cancellation/);
    assert.ok(atAbort > 0);
    await new Promise(resolve => setTimeout(resolve, 50));
    assert.equal(reads, atAbort, 'no filesystem reads may start after cancellation');
  });
}
