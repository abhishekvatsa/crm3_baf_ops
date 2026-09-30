import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {createRequire} from 'node:module';
import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cliRoot = path.join(root, 'tooling/firebase-cli');
const require = createRequire(path.join(cliRoot, 'package.json'));
const Chain = require('stream-chain');
const {parser} = require('stream-json');
const Pick = require('stream-json/filters/Pick');
const Filter = require('stream-json/filters/Filter');
const StreamArray = require('stream-json/streamers/StreamArray');
const StreamObject = require('stream-json/streamers/StreamObject');

async function collect(text, transforms) {
  const rows = [];
  const chain = new Chain(transforms);
  await pipeline(Readable.from([text]), chain, async source => {
    for await (const row of source) rows.push(row);
  });
  return rows;
}

test('all installed JSON parser packages resolve the patched upstream or local adapter', () => {
  const lock = JSON.parse(fs.readFileSync(path.join(cliRoot, 'package-lock.json')));
  const entries = Object.entries(lock.packages).filter(([key, value]) =>
    /node_modules\/stream-json(?:-modern)?$/.test(key) || value.name === 'stream-json');
  assert.equal(entries.length, 2);
  for (const [, value] of entries) assert.equal(value.version, '3.5.0');
  assert.equal(lock.packages['node_modules/stream-json'].resolved, 'file:../stream-json-compat');
  assert.equal(lock.packages['node_modules/fast-uri'].version, '3.1.8');
  assert.equal(lock.packages['node_modules/ip-address'].version, '10.7.1');
  assert.equal(lock.packages['node_modules/morgan'].version, '1.12.1');
  assert.equal(lock.packages['node_modules/undici'].version, '8.10.2');
  assert.equal(lock.packages['node_modules/qs'].version, '6.16.0');
  for (const dir of [root, path.join(root, 'functions')]) {
    const otherLock = JSON.parse(fs.readFileSync(path.join(dir, 'package-lock.json')));
    assert.ok(!Object.keys(otherLock.packages).some(key => /stream-json/.test(key)),
      'The parser adapter must remain confined to Firebase CLI tooling');
  }
});

test('URI parsing rejects an unclosed host bracket and retains valid IPv6', () => {
  const uri = require('fast-uri');
  for (const value of ['https://[example.com/', 'http://[127.0.0.1/']) {
    assert.ok(uri.parse(value).error, `Malformed host must be rejected: ${value}`);
  }
  assert.equal(uri.parse('https://[::1]/').error, undefined);
  assert.equal(uri.parse('https://example.com/').host, 'example.com');
});

test('IPv6 classifiers recognize the full link-local and NAT64 local-use ranges', () => {
  const {Address6} = require('ip-address');
  for (const value of ['fe80::1', 'fe81::1', 'febf::1', 'fe80:0:0:1::1']) {
    assert.equal(new Address6(value).isLinkLocal(), true, value);
  }
  for (const value of ['64:ff9b:1::7f00:1', '64:ff9b:1:7f00:0:100::']) {
    assert.equal(new Address6(value).isPrivate(), true, value);
  }
  assert.equal(new Address6('2001:4860:4860::8888').isLinkLocal(), false);
  assert.equal(new Address6('2001:4860:4860::8888').isPrivate(), false);
});

test('quoted access-log tokens cannot inject a new field', () => {
  const morgan = require('morgan');
  const format = morgan.compile('":url"');
  for (const url of ['/demo" forged', '/demo\\" forged', '/demo"\r\nforged']) {
    const line = format(morgan, {url}, {});
    assert.equal(JSON.parse(line), url,
      'The quoted token must remain exactly one escaped field');
  }
  assert.equal(format(morgan, {url: '/demo'}, {}), '"/demo"');
});

test('auth import retains regex selection, array records, and streaming composition', async () => {
  const users = [{localId: 'one'}, {localId: 'two', disabled: true}];
  assert.deepEqual(await collect(JSON.stringify({ignored: {}, users}), [
    Pick.withParser({filter: /^users$/}), StreamArray.streamArray(),
  ]), users.map((value, key) => ({key, value})));
});

test('database import retains filtering and object keys with a custom path separator', async () => {
  assert.deepEqual(await collect('{"data":{"x":{"a":1},"y":[2,3]},"ignore":0}', [
    Filter.withParser({filter: 'data', pathSeparator: '/'}), StreamObject.streamObject(),
  ]), [{key: 'data', value: {x: {a: 1}, y: [2, 3]}}]);
});

test('database import retains its function filter for root imports', async () => {
  assert.deepEqual(await collect('{"one":1,"two":{"three":true}}', [
    Filter.withParser({filter: () => true, pathSeparator: '/'}), StreamObject.streamObject(),
  ]), [{key: 'one', value: 1}, {key: 'two', value: {three: true}}]);
});

test('Next dependency extraction preserves the CLI parser options and named exports', async () => {
  const dependencies = {a: {version: '1.0'}, b: {dependencies: {c: {version: '2.0'}}}};
  assert.deepEqual(await collect(JSON.stringify({name: 'fixture', dependencies}), [
    parser({packValues: false, packKeys: true, streamValues: false}),
    Pick.pick({filter: 'dependencies'}), StreamObject.streamObject(),
  // The CLI deliberately suppresses scalar values; it needs dependency names.
  ]), [{key: 'a', value: {}}, {key: 'b', value: {dependencies: {c: {}}}}]);
});

for (const [name, factory] of [['Pick', Pick], ['Filter', Filter]]) {
  for (const filter of ['data', /^data$/]) {
    test(`${name} rejects hostile nesting for ${typeof filter} filters`, {timeout: 5000}, async () => {
      const nested = '{"meta":'.repeat(1100) + '1' + '}'.repeat(1100);
      await assert.rejects(collect(nested, [factory.withParser({filter})]), /depth/i);
    });
  }
}

test('malformed JSON remains a rejected stream', async () => {
  await assert.rejects(collect('{"users":[', [Pick.withParser({filter: 'users'}), StreamArray.streamArray()]));
});

test('all Firebase CLI JSON imports are known and their modules load without performing operations', () => {
  const supported = new Set(['stream-json', 'stream-json/filters/Pick', 'stream-json/filters/Filter',
    'stream-json/streamers/StreamArray', 'stream-json/streamers/StreamObject']);
  const seen = new Set();
  const lib = path.join(cliRoot, 'node_modules/firebase-tools/lib');
  for (const relative of fs.readdirSync(lib, {recursive: true})) {
    if (!relative.endsWith('.js')) continue;
    const source = fs.readFileSync(path.join(lib, relative), 'utf8');
    for (const match of source.matchAll(/require\(["'](stream-json(?:\/[^"']*)?)["']\)/g)) {
      assert.ok(supported.has(match[1]), `Unreviewed CLI parser import: ${match[1]}`);
      seen.add(match[1]);
    }
  }
  assert.deepEqual(seen, supported);
  const configRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-json-smoke-'));
  const originalConfigRoot = process.env.XDG_CONFIG_HOME;
  process.env.XDG_CONFIG_HOME = configRoot;
  try {
    for (const relative of ['database/import.js', 'commands/auth-import.js', 'frameworks/next/index.js']) {
      assert.doesNotThrow(() => require(path.join(lib, relative)));
    }
  } finally {
    if (originalConfigRoot === undefined) delete process.env.XDG_CONFIG_HOME;
    else process.env.XDG_CONFIG_HOME = originalConfigRoot;
    fs.rmSync(configRoot, {recursive: true, force: true});
  }
});

test('URI scheme-relative hosts normalize percent-encoded uppercase octets',()=> {
  const uri=require('fast-uri');
  assert.equal(uri.parse('//%41.com').host,'a.com');
  assert.equal(uri.equal('//%41.com','//a.com'),true);
  assert.equal(uri.parse('//A.com').host,'a.com');
});
test('IPv4/IPv6 subnet checks reject cross-family coincidences and preserve same-family controls',()=> {
  const {Address4,Address6}=require('ip-address');
  const pairs=[[new Address6('a00::1'),new Address4('10.0.0.0/8')],[new Address4('32.1.13.184'),new Address6('2001:db8::/32')]];
  for(const [host,network]of pairs)for(const method of ['isInSubnet','isHostInSubnet'])assert.equal(host[method](network),false,method);
  assert.equal(new Address4('10.0.0.1').isInSubnet(new Address4('10.0.0.0/8')),true);
  assert.equal(new Address6('2001:db8::1').isInSubnet(new Address6('2001:db8::/32')),true);
  assert.equal(new Address6('::ffff:10.0.0.1').to4().isInSubnet(new Address4('10.0.0.0/8')),true);
});
test('Oversized IPv6 validation rejects with bounded diagnostic rather than echoing the input',()=> {
  const {Address6,AddressError}=require('ip-address');
  let caught;try{new Address6('!'.repeat(5000));}catch(error){caught=error;}
  assert.ok(caught instanceof AddressError);
  assert.ok(caught.message.length<1024,'bounded error message');
  assert.ok((caught.parseMessage??'').length<1024,'bounded HTML diagnostic');
  assert.equal(Address6.isValid('!'.repeat(5000)),false);
  assert.equal(Address6.isValid('2001:db8::1'),true);
});
