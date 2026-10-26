"use strict";
// Test-only final local process/socket boundary. The pinned CLI discovery code is unchanged.
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const cp = require("node:child_process"), http = require("node:http"), net = require("node:net"), dns = require("node:dns");
const native = { spawn: cp.spawn, httpRequest: http.request, createServer: net.createServer,
  listen: net.Server.prototype.listen, connect: net.Socket.prototype.connect,
  createConnection: net.createConnection, netConnect: net.connect, lookup: dns.lookup };
const SDK_TEXT = `#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path"),http=require("node:http");
const source=path.resolve(process.argv[2]),scratch=path.resolve(source,"../.."),port=Number(process.env.PORT);
if(process.argv.length!==3||!Number.isInteger(port)||port<8000||port>8999||process.env.FUNCTIONS_CONTROL_API!=="true")throw Error("SYNTHETIC_DISCOVERY_ARGUMENTS");
const manifest=fs.readFileSync(path.join(source,"node_modules/firebase-functions/discovery-manifest.json"));
const state=path.join(scratch,"discovery-process.json");
const save=value=>fs.writeFileSync(state,JSON.stringify({pid:process.pid,port,...value})+"\\n");
for(const mod of [require("node:child_process"),require("node:worker_threads")])for(const key of ["exec","execSync","execFile","execFileSync","spawn","spawnSync","fork","Worker"])if(typeof mod[key]==="function")mod[key]=()=>{throw Error("SYNTHETIC_DISCOVERY_CHILD_PROCESS_DENIED");};
const server=http.createServer((req,res)=>{
 if(req.method!=="GET"||req.headers.authorization||req.headers.cookie){res.writeHead(400);return res.end();}
 if(req.url==="/__/functions.yaml"){res.setHeader("Content-Type","application/json");return res.end(manifest);}
 if(req.url==="/__/quitquitquit"){
  save({stopped:false,shutdownReceived:true});res.setHeader("Connection","close");
  return res.end("{}",()=>server.close(()=>{save({stopped:true,shutdownReceived:true});process.exit(0);}));
 }
 res.writeHead(404);res.end();
});
server.listen(port,"127.0.0.1",()=>save({stopped:false,shutdownReceived:false}));
setTimeout(()=>{throw Error("SYNTHETIC_DISCOVERY_BOUND_EXCEEDED");},30000).unref();
`;

function install({ selection, lib, event, retainOwned }) {
  const bin = path.join(selection.project, "functions/node_modules/.bin/firebase-functions");
  const sourceDirectory = path.join(selection.project, "functions");
  let child = null, exited = false, lease, ownedPort;
  // Only the final physical process selection is adapted: cross-spawn's selected Node
  // interpreter resolves to this already selected executable. No arbitrary process is admitted.
  retainOwned(cp, "spawn", () => {
    cp.spawn = function (command, args, options) {
      assert(["node", process.execPath, bin].includes(command), "unselected discovery executable");
      const expected = command === bin ? [sourceDirectory] : [bin, sourceDirectory];
      assert.deepEqual(args, expected, "unselected discovery argv");
      assert.deepEqual(Object.keys(options).sort(), ["cwd", "env", "stdio"], "unselected discovery process option");
      assert.equal(options.cwd, sourceDirectory);
      assert.deepEqual(options.stdio, ["ignore", "pipe", "pipe"]);
      assert.equal(options.env.FUNCTIONS_CONTROL_API, "true");
      assert(/^[0-9]{4}$/.test(options.env.PORT));
      assert(Number(options.env.PORT) >= 8000 && Number(options.env.PORT) <= 8999);
      assert.equal(child, null, "discovery retry refused");
      ownedPort = Number(options.env.PORT);
      child = native.spawn(process.execPath, [bin, sourceDirectory], { ...options, windowsHide: true });
      event({ kind: "REAL_SYNTHETIC_DISCOVERY_PROCESS_STARTED", phase: selection.phase, pid: child.pid,
        port: Number(options.env.PORT), actualSdkExecuted: false, loopbackOnly: true, externalNetworkForwarded: false });
      child.once("exit", (code, signal) => { exited = true;
        event({ kind: "REAL_SYNTHETIC_DISCOVERY_PROCESS_EXIT", phase: selection.phase, pid: child.pid, code, signal });
        assert.throws(() => process.kill(child.pid, 0), error => error.code === "ESRCH");
        event({ kind: "NO_DISCOVERY_PROCESS_AFTER_EXIT", phase: selection.phase, pid: child.pid, processAbsent: true });
      });
      return child;
    };
  });
  // Real pinned portfinder runs with a declared synthetic loopback-only host topology.
  const portfinder = require(require.resolve("portfinder", { paths: [lib] }));
  retainOwned(portfinder, "_defaultHosts", () => { portfinder._defaultHosts = ["127.0.0.1"]; });
  retainOwned(net, "createServer", () => { net.createServer = native.createServer; });
  retainOwned(net.Server.prototype, "listen", () => {
    net.Server.prototype.listen = function (port, host) {
      assert.equal(child, null, "only pre-discovery portfinder may bind");
      assert(Number.isInteger(port) && port >= 8000 && port <= 8999);
      assert.equal(host, "127.0.0.1");
      return native.listen.apply(this, arguments);
    };
  });
  retainOwned(net.Socket.prototype, "connect", () => { net.Socket.prototype.connect = native.connect; });
  // Current Node's HTTP Agent resolves these exports dynamically. Their actual
  // Socket.connect still passes through the production networkVerified guard.
  retainOwned(net, "createConnection", () => { net.createConnection = native.createConnection; });
  retainOwned(net, "connect", () => { net.connect = native.netConnect; });
  retainOwned(dns, "lookup", () => {
    const denied = dns.lookup;
    dns.lookup = function (host, ...args) {
      if (!["localhost", "127.0.0.1"].includes(host)) return denied.apply(this, arguments);
      const callback = args.at(-1), options = typeof args[0] === "object" ? args[0] : {};
      if (host === "localhost") assert(child && !exited, "localhost lookup requires an owned discovery process");
      queueMicrotask(() => callback(null, options.all ? [{ address: "127.0.0.1", family: 4 }] : "127.0.0.1", 4));
    };
  });
  retainOwned(http, "request", () => {
    http.request = function (input, options) {
      const url = input instanceof URL ? input : typeof input === "string" ? new URL(input) :
        new URL("http://" + input.hostname + (input.port ? ":" + input.port : "") + input.path);
      assert(child && !exited && url.port === String(ownedPort));
      assert(["127.0.0.1", "localhost"].includes(url.hostname));
      assert(["/__/functions.yaml", "/__/quitquitquit"].includes(url.pathname));
      return native.httpRequest.apply(this, arguments);
    };
  });
  return {
    executed() { return child !== null; },
    bindGuard(guard) {
      const { Delegate } = require(path.join(lib, "deploy/functions/runtimes/node/index.js"));
      const transport = require("./runtimeDeploymentTransportGuard31.cjs");
      lease = transport.installDiscoveryLifecycle31({ Delegate, guard, sourceDirectory, projectId: "crm3-baf-ops-b8638" });
    },
    beforeIdentity(guard) {
      guard.assertDiscoveryStopped31();
      assert(child && exited && child.exitCode === 0 && child.signalCode === null);
      const observed = JSON.parse(fs.readFileSync(path.join(selection.scratch, "discovery-process.json")));
      assert.equal(observed.pid, child.pid); assert.equal(observed.stopped, true); assert.equal(observed.shutdownReceived, true);
      assert.throws(() => process.kill(observed.pid, 0), error => error.code === "ESRCH", "discovery process still survives before identity");
      event({ kind: "NO_DISCOVERY_SURVIVOR_BEFORE_IDENTITY", phase: selection.phase, pid: child.pid,
        stopped: true, gracefulShutdownReceived: true, processAbsent: true });
    },
    assertComplete(expected) {
      if (expected) assert(child && exited && child.exitCode === 0 && child.signalCode === null);
      else assert.equal(child, null);
    },
    restore() { if (lease) lease.restore(); }
  };
}
module.exports = { install, SDK_TEXT };
