import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {PassThrough} from 'node:stream';
import {createInterface} from 'node:readline';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cliRequire = createRequire(path.join(root, 'tooling/firebase-cli/package.json'));
const require = createRequire(cliRequire.resolve('firebase-tools/package.json'));
const {Server} = require('@modelcontextprotocol/sdk/server/index.js');
const {StdioServerTransport} = require('@modelcontextprotocol/sdk/server/stdio.js');
const {SSEServerTransport} = require('@modelcontextprotocol/sdk/server/sse.js');
const types = require('@modelcontextprotocol/sdk/types.js');
const {auth, fetchToken} = require('@modelcontextprotocol/sdk/client/auth.js');
const tool = {name: 'fixture_echo', inputSchema: {type: 'object'}, _meta: {fixture: true}};
const result = {content: [{type: 'text', text: 'fixture-only'}], isError: false};

test('Firebase resolves SDK 1.31.0 and retains its server and OneMCP schema APIs', () => {
  const serverFile = require.resolve('@modelcontextprotocol/sdk/server/index.js');
  const sdkRoot = path.resolve(path.dirname(serverFile), '../../..');
  assert.equal(JSON.parse(fs.readFileSync(path.join(sdkRoot, 'package.json'), 'utf8')).version, '1.31.0');
  assert.equal(require('firebase-tools/package.json').version, '15.22.4');
  for (const member of ['server/index.js', 'server/stdio.js', 'server/sse.js', 'types.js']) {
    assert.equal(require.resolve(`@modelcontextprotocol/sdk/${member}`), path.join(sdkRoot, 'dist/cjs', member));
  }
  assert.equal(typeof SSEServerTransport, 'function');
  const server = new Server({name: 'firebase-fixture', version: '0.3.0'});
  server.registerCapabilities({tools: {listChanged: true}, logging: {}, prompts: {listChanged: true}, resources: {}});
  for (const name of ['ListTools', 'CallTool', 'ListPrompts', 'GetPrompt', 'ListResourceTemplates',
    'ListResources', 'ReadResource', 'SetLevel']) server.setRequestHandler(types[`${name}RequestSchema`], async () => ({}));
  assert.deepEqual(types.ListToolsResultSchema.parse({tools: [tool]}), {tools: [tool]});
  assert.deepEqual(types.CallToolResultSchema.parse(result), result);
  assert.equal(types.ListToolsResultSchema.safeParse({tools: [{name: 7}]}).success, false);
  assert.equal(types.CallToolResultSchema.safeParse({content: [{type: 'text', text: 7}]}).success, false);
});

test('Firebase-style Server exchanges initialize, list and call over genuine stdio streams',
  {timeout: 5000}, async () => {
    const input = new PassThrough();
    const output = new PassThrough();
    const lines = createInterface({input: output});
    const transport = new StdioServerTransport(input, output);
    const server = new Server({name: 'firebase-fixture', version: '0.3.0'});
    const errors = [];
    server.onerror = error => errors.push(error);
    server.registerCapabilities({tools: {listChanged: true}});
    server.setRequestHandler(types.ListToolsRequestSchema, async () => ({tools: [tool]}));
    server.setRequestHandler(types.CallToolRequestSchema, async request => {
      assert.equal(request.params.name, tool.name);
      assert.deepEqual(request.params.arguments, {message: 'fixture-only'});
      return result;
    });
    async function exchange(id, method, params) {
      const reply = once(lines, 'line', {signal: AbortSignal.timeout(2000)});
      const frame = JSON.stringify({jsonrpc: '2.0', id, method, params}) + '\n';
      input.write(frame.slice(0, 7));
      input.write(frame.slice(7));
      const parsed = JSON.parse((await reply)[0]);
      assert.equal(parsed.id, id);
      assert.equal(parsed.jsonrpc, '2.0');
      assert.equal(parsed.error, undefined);
      return parsed.result;
    }
    try {
      // Firebase's logging subclass wraps this hook; retain its callable shape.
      assert.equal(typeof transport._ondata, 'function');
      await server.connect(transport);
      const initialized = await exchange(1, 'initialize', {protocolVersion: types.LATEST_PROTOCOL_VERSION,
        capabilities: {}, clientInfo: {name: 'inert-fixture', version: '1'}});
      assert.equal(initialized.serverInfo.name, 'firebase-fixture');
      assert.equal(initialized.protocolVersion, types.LATEST_PROTOCOL_VERSION);
      input.write(JSON.stringify({jsonrpc: '2.0', method: 'notifications/initialized'}) + '\n');
      assert.deepEqual(await exchange(2, 'tools/list', {}), {tools: [tool]});
      assert.deepEqual(await exchange(3, 'tools/call', {name: tool.name, arguments: {message: 'fixture-only'}}), result);
      assert.deepEqual(errors, []);
    } finally {
      await server.close();
      assert.equal(input.listenerCount('data'), 0);
      lines.close();
      input.destroy();
      output.destroy();
    }
  });

test('issuer-bound OAuth credentials never reach another issuer; same-issuer token flow remains usable',
  {timeout: 5000}, async () => {
    // Synthetic sentinels only. Every fetch is injected; no listener, credentials or network.
    const issuer = 'https://trusted.invalid';
    const other = 'https://other.invalid';
    const metadata = base => ({issuer: base, token_endpoint: `${base}/token`,
      authorization_endpoint: `${base}/authorize`, response_types_supported: ['code'],
      code_challenge_methods_supported: ['S256'], token_endpoint_auth_methods_supported: ['client_secret_post']});
    const calls = [];
    const provider = {clientMetadata: {grant_types: ['client_credentials']},
      clientInformation: () => ({client_id: 'inert-client', client_secret: 'inert-secret', issuer}),
      prepareTokenRequest: () => new URLSearchParams({grant_type: 'client_credentials'})};
    const fetchFn = async (url, options) => {
      calls.push({url: String(url), options});
      assert.equal(String(url), `${issuer}/token`);
      assert.equal(options.method, 'POST');
      return new Response(JSON.stringify({access_token: 'inert-access', token_type: 'Bearer'}),
        {status: 200, headers: {'content-type': 'application/json'}});
    };
    await assert.rejects(fetchToken(provider, other, {metadata: metadata(other), fetchFn}), /bound to authorization server/);
    assert.equal(calls.length, 0, 'issuer mismatch must refuse before even the fake credential send');
    assert.equal((await fetchToken(provider, issuer, {metadata: metadata(issuer), fetchFn})).access_token, 'inert-access');
    assert.equal(calls.length, 1);
    const body = new URLSearchParams(calls[0].options.body);
    assert.equal(body.get('grant_type'), 'client_credentials');
    assert.equal(body.get('client_secret'), 'inert-secret');
    let redirect;
    let verifier;
    const refreshProvider = {redirectUrl: 'https://client.invalid/callback', clientMetadata: {},
      clientInformation: () => ({client_id: 'public-fixture', issuer: other}),
      tokens: () => ({access_token: 'old-inert', token_type: 'Bearer', refresh_token: 'never-send-inert', issuer}),
      discoveryState: () => ({authorizationServerUrl: other, authorizationServerMetadata: metadata(other),
        resourceMetadata: {resource: 'https://resource.invalid/mcp', authorization_servers: [other]}}),
      saveCodeVerifier: value => { verifier = value; }, redirectToAuthorization: value => { redirect = value; }};
    let refreshFetches = 0;
    assert.equal(await auth(refreshProvider, {serverUrl: 'https://resource.invalid/mcp', fetchFn: async () => {
      refreshFetches++; throw new Error('unexpected fetch in mismatched-refresh fixture');
    }}), 'REDIRECT');
    assert.equal(refreshFetches, 0);
    assert.equal(redirect.origin, other);
    assert.ok(verifier.length > 0);
  });
