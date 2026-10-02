import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import {once} from 'node:events';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cliRoot = path.join(root, 'tooling/firebase-cli');
const require = createRequire(path.join(cliRoot, 'package.json'));
const {getUri} = require('get-uri');

async function fixture(t, {listFallback = false, missing = false, denyLogin = false, differentTransferHost = false} = {}) {
  const sockets = new Set();
  const controls = [];
  const listeners = new Set();
  const commands = [];
  const payload = 'function FindProxyForURL() { return "DIRECT"; }\n';
  const track = socket => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    socket.on('error', () => {});
    return socket;
  };
  const server = net.createServer(socket => {
    controls.push(socket);
    track(socket).setEncoding('utf8');
    socket.write('220 local compatibility fixture\r\n');
    let buffer = '';
    let dataConnection;
    let chain = Promise.resolve();
    socket.on('data', text => {
      buffer += text;
      while (buffer.includes('\r\n')) {
        const end = buffer.indexOf('\r\n');
        const command = buffer.slice(0, end);
        buffer = buffer.slice(end + 2);
        commands.push(command);
        chain = chain.then(async () => {
          const verb = command.split(' ')[0];
          if (verb === 'USER') return socket.write(denyLogin ? '530 denied\r\n' : '331 password\r\n');
          if (verb === 'PASS') return socket.write('230 accepted\r\n');
          if (verb === 'FEAT') return socket.write('211-Features\r\n MLST type*;size*;modify*;\r\n211 End\r\n');
          if (verb === 'PWD') return socket.write('257 "/"\r\n');
          if (verb === 'MDTM') return socket.write(missing ? '550 absent\r\n' : listFallback ? '502 unsupported\r\n' : '213 20261001120000\r\n');
          if (verb === 'EPSV' && differentTransferHost) return socket.write('502 unsupported\r\n');
          if (verb === 'EPSV' || verb === 'PASV') {
            const dataServer = net.createServer();
            listeners.add(dataServer);
            dataConnection = once(dataServer, 'connection').then(([connection]) => track(connection));
            dataServer.listen(0, '127.0.0.1');
            await once(dataServer, 'listening');
            const dataPort = dataServer.address().port;
            socket.write(verb === 'EPSV'
              ? `229 Entering Extended Passive Mode (|||${dataPort}|)\r\n`
              : `227 Entering Passive Mode (127,0,0,2,${dataPort >> 8},${dataPort & 255})\r\n`);
            return;
          }
          if (verb === 'RETR' || verb === 'MLSD' || verb === 'LIST') {
            socket.write('150 opening data\r\n');
            const data = await dataConnection;
            data.end(verb === 'RETR' ? payload : `type=file;size=${payload.length};modify=20261001120000; proxy.pac\r\n`);
            await once(data, 'close');
            socket.write('226 transfer complete\r\n');
            return;
          }
          if (verb === 'QUIT') return socket.end('221 goodbye\r\n');
          socket.write('200 okay\r\n');
        }).catch(error => socket.destroy(error));
      }
    });
  });
  t.after(async () => {
    for (const socket of sockets) socket.destroy();
    await Promise.all([...listeners, server].map(listener => new Promise(resolve => listener.close(resolve))));
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return {url: `ftp://test:fixture@127.0.0.1:${server.address().port}/proxy.pac`, commands, payload,
    // basic-ftp closes its control socket after transfer completion; Windows may
    // report ECONNRESET to this fixture server. Wait for close, not a new client
    // operation, after content/cache assertions and the client's transfer reply.
    waitClosed: () => Promise.all(controls.filter(socket => !socket.destroyed)
      .map(socket => new Promise(resolve => socket.once('close', resolve))))};
}

test('CLI FTP dependency retains exact patched registry bytes in every copy', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(cliRoot, 'package.json')));
  const lock = JSON.parse(fs.readFileSync(path.join(cliRoot, 'package-lock.json')));
  assert.equal(packageJson.overrides['basic-ftp'], '6.2.1');
  const copies = Object.entries(lock.packages).filter(([key]) => /(^|\/)node_modules\/basic-ftp$/.test(key));
  assert.ok(copies.length > 0);
  for (const [, entry] of copies) {
    assert.equal(entry.version, '6.2.1');
    assert.equal(entry.resolved, 'https://registry.npmjs.org/basic-ftp/-/basic-ftp-6.2.1.tgz');
    assert.equal(entry.integrity, 'sha512-bK67isD+lKq46AU8vNtjvMaT2ZqAOAmNCbxUHlFBRD4k15NWxyEjmaKtZPlgce58So4BNTjITGQOVTjL9y0ECA==');
  }
  assert.equal(require('basic-ftp/package.json').version, '6.2.1');
  const consumerRequire = createRequire(require.resolve('get-uri'));
  assert.equal(consumerRequire('basic-ftp/package.json').version, '6.2.1');
  for (const rel of ['package-lock.json', 'functions/package-lock.json']) {
    const other = JSON.parse(fs.readFileSync(path.join(root, rel)));
    assert.ok(!Object.keys(other.packages).some(key => /(^|\/)node_modules\/basic-ftp$/.test(key)));
  }
});

test('actual get-uri downloads FTP content and honors unchanged-cache metadata', {timeout: 10000}, async t => {
  const f = await fixture(t);
  const stream = await getUri(f.url);
  let actual = '';
  for await (const chunk of stream) actual += chunk;
  assert.equal(actual, f.payload);
  assert.equal(stream.lastModified.toISOString(), '2026-10-01T12:00:00.000Z');
  await assert.rejects(getUri(f.url, {cache: stream}), {code: 'ENOTMODIFIED'});
  assert.equal(f.commands.filter(command => command.startsWith('RETR ')).length, 1);
  await f.waitClosed();
});

test('actual get-uri retains MLSD fallback when MDTM is unsupported', {timeout: 10000}, async t => {
  const f = await fixture(t, {listFallback: true});
  const stream = await getUri(f.url);
  let actual = '';
  for await (const chunk of stream) actual += chunk;
  assert.equal(actual, f.payload);
  assert.ok(f.commands.some(command => command.startsWith('MLSD')));
  await f.waitClosed();
});

test('FTP keeps the control host when a passive response advertises another host', {timeout: 10000}, async t => {
  const f = await fixture(t, {differentTransferHost: true});
  const stream = await getUri(f.url);
  let actual = '';
  for await (const chunk of stream) actual += chunk;
  assert.equal(actual, f.payload);
  assert.ok(f.commands.includes('PASV'));
  await f.waitClosed();
});

test('FTP missing-file and authentication failures remain refusals', {timeout: 10000}, async t => {
  const absent = await fixture(t, {missing: true});
  await assert.rejects(getUri(absent.url), {code: 'ENOTFOUND'});
  assert.ok(!absent.commands.some(command => command.startsWith('RETR')));
  const denied = await fixture(t, {denyLogin: true});
  await assert.rejects(getUri(denied.url), {code: 530});
  assert.ok(!denied.commands.some(command => command.startsWith('RETR')));
});

test('patched Unix listing parser handles the advisory input within a bounded subprocess', () => {
  const entry = require.resolve('basic-ftp/dist/parseList.js');
  const script = `const {parseList}=require(process.argv[1]); const rows=parseList('-rw-r--r-- 1 '+ 'a '.repeat(65536) +'!\\r\\n-rw-r--r-- 1 owner group 42 Jan 1 2020 good.txt\\r\\n'); if(rows.length!==1||rows[0].name!=='good.txt')process.exit(2);`;
  const result = spawnSync(process.execPath, ['-e', script, entry], {encoding:'utf8', timeout:3000});
  assert.equal(result.error, undefined, result.error?.message);
  assert.equal(result.status, 0, result.stderr);
});
