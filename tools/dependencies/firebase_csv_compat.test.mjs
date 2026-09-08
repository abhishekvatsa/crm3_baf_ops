import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cliRoot = path.join(root, 'tooling/firebase-cli');
const require = createRequire(path.join(cliRoot, 'node_modules/firebase-tools/package.json'));
const {parse} = require('csv-parse');

async function collect(text, options) {
  const records = [];
  await pipeline(Readable.from([...Buffer.from(text)].map(byte => Buffer.from([byte]))),
    options === undefined ? parse() : parse(options), async source => {
      for await (const row of source) records.push(row);
    });
  return records;
}

test('Firebase CLI resolves only the patched CSV parser from its locked tooling tree', () => {
  const lock = JSON.parse(fs.readFileSync(path.join(cliRoot, 'package-lock.json')));
  const parsers = Object.entries(lock.packages).filter(([key]) => /node_modules\/csv-parse$/.test(key));
  assert.equal(parsers.length, 1);
  assert.equal(parsers[0][1].version, '7.0.2');
  assert.equal(require.resolve('csv-parse'), path.join(cliRoot, 'node_modules/csv-parse/dist/cjs/index.cjs'));
  const imports = [];
  const lib = path.join(cliRoot, 'node_modules/firebase-tools/lib');
  for (const relative of fs.readdirSync(lib, {recursive: true})) {
    if (!relative.endsWith('.js')) continue;
    if (/require\(["']csv-parse(?:\/[^"']*)?["']\)/.test(fs.readFileSync(path.join(lib, relative), 'utf8'))) {
      imports.push(relative.replaceAll('\\', '/'));
    }
  }
  assert.deepEqual(imports, ['commands/auth-import.js']);
});

test('CSV auth import preserves columns, quoted content, empty fields, and split UTF-8', async () => {
  const {transArrayToUser} = require('firebase-tools/lib/accountImporter');
  const rows = await collect('one,one@example.test,true,,,"Ali, \"\"A\"\"",\r\ntwo,,false,,,"नाम\nSecond line",\r\n');
  assert.deepEqual(rows, [
    ['one', 'one@example.test', 'true', '', '', 'Ali, "A"', ''],
    ['two', '', 'false', '', '', 'नाम\nSecond line', ''],
  ]);
  const users = rows.map(record => transArrayToUser(record.map(value => {
    const text = value.trim().replace(/^["|'](.*)["|']$/, '$1');
    return text === '' ? undefined : text;
  })));
  assert.equal(users[0].localId, 'one');
  assert.equal(users[0].emailVerified, true);
  assert.equal(users[0].displayName, 'Ali, "A"');
  assert.equal(users[1].email, undefined);
  assert.equal(users[1].emailVerified, false);
  assert.equal(users[1].displayName, 'नाम\nSecond line');
  assert.ok(users.every(user => user.error === undefined));
});

test('duplicate hostile column names remain own data properties without replacing prototypes', async () => {
  // GHSA-8cw4-87c7-c6xx: the duplicate-column path must not call __proto__'s setter.
  const [row] = await collect('__proto__,__proto__,constructor,toString\na,b,c,d\n', {
    columns: true, group_columns_by_name: true,
  });
  assert.equal(Object.getPrototypeOf(row), Object.prototype);
  assert.ok(Object.hasOwn(row, '__proto__'));
  assert.deepEqual(row.__proto__, ['a', 'b']);
  assert.equal(row.constructor, 'c');
  assert.equal(row.toString, 'd');
  assert.equal(Object.getPrototypeOf({}), Object.prototype);
});

test('malformed CSV remains a rejected stream', async () => {
  await assert.rejects(collect('one,"unfinished'), {code: 'CSV_QUOTE_NOT_CLOSED'});
});
