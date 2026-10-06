import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import {parseWorkflow} from '../release/workflow_dispatch_input_custody.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

for (const [label, directory] of [['root', root], ['Functions', path.join(root, 'functions')]]) {
  const require = createRequire(path.join(directory, 'package.json'));
  const yaml = require('js-yaml');

  test(`${label}: exact YAML4 graph removes the vulnerable sprintf dependency`, () => {
    const lock = JSON.parse(fs.readFileSync(path.join(directory, 'package-lock.json'), 'utf8'));
    const entries = Object.entries(lock.packages);
    const copies = entries.filter(([name]) => /(?:^|\/)node_modules\/js-yaml$/.test(name));
    assert.ok(copies.length > 0);
    for (const [, metadata] of copies) assert.equal(metadata.version, '4.3.2');
    assert.equal(require('js-yaml/package.json').version, '4.3.2');
    assert.ok(!entries.some(([name, metadata]) =>
      /(?:^|\/)node_modules\/sprintf-js$/.test(name) || metadata.name === 'sprintf-js'));
    const coverageRequire = createRequire(require.resolve('@istanbuljs/load-nyc-config'));
    assert.equal(coverageRequire.resolve('js-yaml'), require.resolve('js-yaml'));
    assert.equal(coverageRequire('js-yaml/package.json').version, '4.3.2');
    const value = {include: ['src/**/*.js'], all: true, branches: 85};
    assert.deepEqual(yaml.load(yaml.dump(value)), value);
  });

  test(`${label}: actual coverage loader preserves YAML extends, aliases and array fields`, async t => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-yaml-coverage-'));
    t.diagnostic(`Retained YAML fixture: ${fixture}`);
    fs.writeFileSync(path.join(fixture, 'package.json'), '{"name":"yaml-coverage-fixture","private":true}\n', {flag: 'wx'});
    fs.writeFileSync(path.join(fixture, 'base.yml'), [
      'all: true',
      'include: &paths',
      '  - src/**/*.js',
      'exclude: *paths',
      'extension: .js',
      'exclude-after-remap: true',
      '',
    ].join('\n'), {flag: 'wx'});
    fs.writeFileSync(path.join(fixture, '.nycrc.yml'), [
      'extends: ./base.yml',
      'reporter: [text, json-summary]',
      'check-coverage: true',
      'branches: 85',
      '',
    ].join('\n'), {flag: 'wx'});
    const {loadNycConfig} = require('@istanbuljs/load-nyc-config');
    const config = await loadNycConfig({cwd: fixture, nycrcPath: '.nycrc.yml'});
    assert.deepEqual(config, {
      cwd: fixture,
      reporter: ['text', 'json-summary'],
      checkCoverage: true,
      branches: 85,
      all: true,
      include: ['src/**/*.js'],
      exclude: ['src/**/*.js'],
      extension: ['.js'],
      excludeAfterRemap: true,
    });
  });

  test(`${label}: official YAML CLI retains help, version and both stdin conversions`, {timeout: 15000}, () => {
    const cli = path.join(path.dirname(require.resolve('js-yaml/package.json')), 'bin/js-yaml.js');
    const env = {};
    for (const key of ['SystemRoot', 'WINDIR', 'PATH', 'TEMP', 'TMP', 'LANG']) {
      if (process.env[key] !== undefined) env[key] = process.env[key];
    }
    const run = (args, input = '') => {
      const result = spawnSync(process.execPath, [cli, ...args], {
        cwd: directory, env, input, encoding: 'utf8', timeout: 3000,
        maxBuffer: 1024 * 1024, windowsHide: true,
      });
      assert.equal(result.error, undefined);
      assert.equal(result.signal, null);
      return result;
    };
    const version = run(['--version']);
    assert.equal(version.status, 0);
    assert.equal(version.stdout.trim(), '4.3.2');
    assert.equal(version.stderr, '');
    const help = run(['--help']);
    assert.equal(help.status, 0);
    assert.match(help.stdout, /usage: js-yaml/);
    assert.match(help.stdout, /--compact/);
    assert.match(help.stdout, /--trace/);
    const fromYaml = run(['-j'], 'enabled: true\nitems: [one, two]\n');
    assert.equal(fromYaml.status, 0);
    assert.deepEqual(JSON.parse(fromYaml.stdout), {enabled: true, items: ['one', 'two']});
    const fromJson = run([], '{"enabled":true,"items":["one","two"]}');
    assert.equal(fromJson.status, 0);
    assert.deepEqual(yaml.load(fromJson.stdout), {enabled: true, items: ['one', 'two']});
    const invalid = run(['--compact'], 'items: [unterminated\n');
    assert.equal(invalid.status, 1);
    assert.equal(invalid.stdout, '');
    assert.match(invalid.stderr, /YAMLException/);
  });

  test(`${label}: YAML4 refuses unsafe JavaScript tags without evaluating them`, () => {
    for (const value of [
      'value: !!js/function "function () { return 1; }"',
      'value: !!js/regexp /example/',
      'value: !!js/undefined ""',
    ]) {
      assert.throws(() => yaml.load(value), /unknown tag/);
    }
  });
}

test('workflow parser retains explicit JSON schema scalar and merge-key semantics', () => {
  const parsed = parseWorkflow([
    'on:',
    '  workflow_dispatch: {}',
    'date: 2026-10-06',
    'enabled: true',
    'count: 3',
    'defaults: &defaults',
    '  retries: 2',
    'job:',
    '  <<: *defaults',
  ].join('\n'));
  assert.deepEqual(parsed.on, {workflow_dispatch: {}});
  assert.equal(parsed.date, '2026-10-06', 'JSON schema must not construct a Date');
  assert.equal(parsed.enabled, true);
  assert.equal(parsed.count, 3);
  assert.deepEqual(parsed.job, {'<<': {retries: 2}}, 'JSON schema must not enable YAML merge types');
});

test('workflow parser retains mapping and schema restrictions after YAML4 migration', () => {
  for (const source of ['null', '- one\n- two', 'plain scalar']) {
    assert.throws(() => parseWorkflow(source), /must contain a YAML mapping/);
  }
  for (const source of [
    'value: !!timestamp 2026-10-06',
    'value: !!js/function "function () { return 1; }"',
    'value: !!js/regexp /example/',
    'value: !!js/undefined ""',
  ]) {
    assert.throws(() => parseWorkflow(source), /unknown tag/);
  }
});
