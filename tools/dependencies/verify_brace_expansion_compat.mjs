import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const packageRoots = [
  repositoryRoot,
  path.join(repositoryRoot, 'functions'),
  path.join(repositoryRoot, 'tooling', 'firebase-cli'),
];
const pattern = 'src/{alpha,beta}/**/*.test.js';
const matchingPath = 'src/alpha/unit/example.test.js';
const nonMatchingPath = 'src/gamma/unit/example.test.js';

function packageEntries(packageRoot) {
  const lockPath = path.join(packageRoot, 'package-lock.json');
  const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
  assert.ok(lock.packages, `${lockPath} must contain a packages map`);
  return Object.entries(lock.packages);
}

function loadCommonJs(packageRoot, packageName) {
  const packageRequire = createRequire(path.join(packageRoot, 'package.json'));
  return packageRequire(packageName);
}

for (const packageRoot of packageRoots) {
  const label = path.relative(repositoryRoot, packageRoot) || '.';
  const entries = packageEntries(packageRoot);
  const braceEntries = entries.filter(([lockPath, metadata]) =>
    (lockPath === 'node_modules/brace-expansion'
      || metadata?.name === 'brace-expansion')
  );

  assert.ok(braceEntries.length >= 2, `${label} must lock adapter and upstream`);
  for (const [lockPath, metadata] of braceEntries) {
    assert.equal(
      metadata.version,
      '5.0.12',
      `${label}:${lockPath} must resolve brace-expansion 5.0.12`,
    );
  }

  const commonJsAdapter = loadCommonJs(packageRoot, 'brace-expansion');
  assert.equal(typeof commonJsAdapter, 'function', `${label} CJS adapter`);
  assert.equal(commonJsAdapter.expand, commonJsAdapter, `${label} named expand`);
  assert.deepEqual(commonJsAdapter('a{b,c}d'), ['abd', 'acd'], label);

  // Exercise the installed export selected by consumers in every trust domain.
  const installedEsm = await import(pathToFileURL(
    path.join(packageRoot, 'node_modules/brace-expansion/index.mjs'),
  ));
  assert.equal(installedEsm.default, installedEsm.expand, `${label} installed ESM default`);
  assert.deepEqual(installedEsm.expand('x{1..3}'), ['x1', 'x2', 'x3']);
  assert.equal(installedEsm.EXPANSION_MAX, 100_000);
  assert.deepEqual(installedEsm.expand('{a},b}', {maxRewrites: 0}), ['{a},b}']);
  console.log(`PASS_BRACE_EXPANSION_INSTALLED_ESM_COMPAT: ${label}`);

  // Synchronous hostile-input paths run in a child with a hard deadline, so
  // a recurrence cannot stall the test runner or hide stack exhaustion.
  const packageRequire = createRequire(path.join(packageRoot, 'package.json'));
  const hostileCases = [
    "for(const input of ['{'.repeat(4000)+'a,b'+'}'.repeat(4000),'{a,'.repeat(4500)+'z'+'}'.repeat(4500)]) {const result=expand(input);assert.ok(Array.isArray(result));assert.ok(result.length<=expand.EXPANSION_MAX);}",
    "for(const input of ['{'+'{a},'.repeat(8000)+'b}','{{x},'+'a,'.repeat(130000)+'b}']) {const result=expand(input,{max:10,maxLength:1000000});assert.ok(Array.isArray(result));assert.ok(result.length<=10);}",
    "assert.deepEqual(expand('{a},b}',{maxRewrites:0}),['{a},b}']);assert.ok(Number.isInteger(expand.EXPANSION_MAX_REWRITES));assert.ok(expand.EXPANSION_MAX_REWRITES>0);const result=expand('{a}'+'}'.repeat(16000)+',z}');assert.ok(Array.isArray(result));assert.ok(result.some(x=>x.includes('}')));assert.ok(result.length<=2);",
  ];
  for (const [index, expression] of hostileCases.entries()) {
    const code = `const assert=require('node:assert/strict');const expand=require(process.argv[1]);${expression}`;
    assert.doesNotThrow(() => execFileSync(process.execPath,
      ['-e', code, packageRequire.resolve('brace-expansion')],
      {encoding: 'utf8', timeout: 5000, windowsHide: true, maxBuffer: 1024 * 1024}),
    `${label} bounded hostile-input case ${index + 1}`);
  }
  console.log(`PASS_BRACE_EXPANSION_HOSTILE_INPUTS: ${label} cases=${hostileCases.length}`);

  const minimatchEntries = entries.filter(([lockPath]) =>
    lockPath === 'node_modules/minimatch'
    || lockPath.endsWith('/node_modules/minimatch')
  );
  assert.ok(minimatchEntries.length > 0, `${label} must install minimatch`);

  for (const [lockPath] of minimatchEntries) {
    const minimatchRoot = path.join(packageRoot, ...lockPath.split('/'));
    const minimatchModule = createRequire(
      path.join(minimatchRoot, 'package.json'),
    )(minimatchRoot);
    const minimatch = typeof minimatchModule === 'function'
      ? minimatchModule
      : minimatchModule.minimatch;

    assert.equal(
      typeof minimatch,
      'function',
      `${label}:${lockPath} must expose minimatch`,
    );
    assert.equal(
      minimatch(matchingPath, pattern),
      true,
      `${label}:${lockPath} must expand matching braces`,
    );
    assert.equal(
      minimatch(nonMatchingPath, pattern),
      false,
      `${label}:${lockPath} must reject nonmatching braces`,
    );
  }

  console.log(
    `PASS_BRACE_EXPANSION_COMPAT: ${label} minimatch=${minimatchEntries.length}`,
  );
}

const esmAdapter = await import(pathToFileURL(
  path.join(
    repositoryRoot,
    'tooling',
    'brace-expansion-compat',
    'index.mjs',
  ),
));
assert.equal(esmAdapter.default, esmAdapter.expand, 'ESM default export');
assert.deepEqual(esmAdapter.expand('x{1..3}'), ['x1', 'x2', 'x3']);
assert.equal(esmAdapter.EXPANSION_MAX, 100_000, 'bounded expansion count');
assert.equal(
  esmAdapter.expand('{1..100001}').length,
  esmAdapter.EXPANSION_MAX,
  'oversized expansion must remain bounded',
);
console.log('PASS_BRACE_EXPANSION_ESM_COMPAT');
