"use strict";
// Test-only cooperative JS boundary, not an OS sandbox. Installed CLI/source are read-only.
const fs = require("node:fs");
const path = require("node:path");
const { fileURLToPath } = require("node:url");
function installOfflineFence({ scratch, source, cliRoot, readFiles, event }) {
  const state = { denials: [] };
  const deny = label => function () {
    state.denials.push(label);
    event({ kind: "DENIED", api: label });
    const error = Error("OFFLINE_BOUNDARY_DENIED: " + label);
    error.code = "OFFLINE_BOUNDARY_DENIED";
    throw error;
  };
  const replace = (object, key, label) => {
    if (typeof object[key] === "function") object[key] = deny(label + "." + key);
  };
  const http = require("node:http"), https = require("node:https"), net = require("node:net");
  const tls = require("node:tls"), dns = require("node:dns"), dgram = require("node:dgram");
  const http2 = require("node:http2"), cp = require("node:child_process");
  const workers = require("node:worker_threads"), cluster = require("node:cluster");
  const inspector = require("node:inspector"), Module = require("node:module");
  for (const [object, label, keys] of [
    [http, "http", ["request", "get", "createServer"]],
    [https, "https", ["request", "get", "createServer"]],
    [net, "net", ["connect", "createConnection", "createServer"]],
    [net.Socket.prototype, "net.Socket", ["connect"]],
    [net.Server.prototype, "net.Server", ["listen"]],
    [tls, "tls", ["connect", "createServer"]],
    [dns, "dns", ["lookup", "lookupService", ...Object.keys(dns).filter(k => k.startsWith("resolve"))]],
    [dns.promises, "dns.promises", ["lookup", "lookupService", ...Object.keys(dns.promises).filter(k => k.startsWith("resolve"))]],
    [dgram, "dgram", ["createSocket"]], [dgram.Socket.prototype, "dgram.Socket", ["bind", "connect", "send"]],
    [http2, "http2", ["connect", "createServer", "createSecureServer"]],
    [cp, "child_process", ["exec", "execSync", "execFile", "execFileSync", "spawn", "spawnSync", "fork"]],
    [cluster, "cluster", ["fork"]], [workers, "worker_threads", ["Worker"]],
    [inspector, "inspector", ["open"]], [process, "process", ["dlopen", "binding", "_linkedBinding"]]
  ]) for (const key of keys) replace(object, key, label);
  for (const C of [dns.Resolver, dns.promises.Resolver]) {
    for (const key of Object.getOwnPropertyNames(C.prototype)) {
      if (key === "lookup" || key === "lookupService" || key.startsWith("resolve")) replace(C.prototype, key, "dns.Resolver");
    }
  }
  for (const key of ["fetch", "WebSocket", "EventSource"]) {
    if (typeof globalThis[key] !== "undefined") globalThis[key] = deny("global." + key);
  }
  const within = (root, file) => {
    const rel = path.relative(root, file);
    return rel === "" || (!path.isAbsolute(rel) && rel !== ".." && !rel.startsWith(".." + path.sep));
  };
  const allowed = new Set(readFiles.map(file => path.resolve(file)));
  const nativeLstat = fs.lstatSync;
  function checked(value, writing) {
    if (value instanceof URL) value = fileURLToPath(value);
    if (Buffer.isBuffer(value)) value = value.toString();
    if (typeof value !== "string") return deny("filesystem.nonPathContentAccess")();
    const file = path.resolve(value);
    if (!(within(scratch, file) || (!writing && (within(source, file) || within(cliRoot, file) || allowed.has(file))))) {
      return deny(writing ? "filesystem.writeOutsideScratch" : "filesystem.readOutsideFixture")();
    }
    // Do not follow a link within an allowed root into an unselected profile or tree.
    let current = path.parse(file).root;
    for (const part of file.slice(current.length).split(path.sep).filter(Boolean)) {
      current = path.join(current, part);
      try { if (nativeLstat(current).isSymbolicLink()) return deny("filesystem.redirect")(); }
      catch (error) { if (error.code === "ENOENT") break; throw error; }
    }
    return value;
  }
  for (const key of ["readFile", "readFileSync", "createReadStream"]) {
    const original = fs[key];
    fs[key] = function (file, ...args) { checked(file, false); return original.call(this, file, ...args); };
  }
  for (const key of ["writeFile", "writeFileSync", "appendFile", "appendFileSync", "createWriteStream",
    "mkdir", "mkdirSync", "mkdtemp", "mkdtempSync", "rm", "rmSync", "rmdir", "rmdirSync", "unlink",
    "unlinkSync", "truncate", "truncateSync", "chmod", "chmodSync", "chown", "chownSync", "utimes", "utimesSync"]) {
    if (typeof fs[key] !== "function") continue;
    const original = fs[key];
    fs[key] = function (file, ...args) { checked(file, true); return original.call(this, file, ...args); };
  }
  for (const key of ["rename", "renameSync", "copyFile", "copyFileSync", "cp", "cpSync"]) {
    const original = fs[key];
    fs[key] = function (from, to, ...args) {
      checked(from, key.startsWith("rename")); checked(to, true);
      return original.call(this, from, to, ...args);
    };
  }
  const writing = flags => typeof flags === "number"
    ? !!(flags & (fs.constants.O_WRONLY | fs.constants.O_RDWR | fs.constants.O_CREAT | fs.constants.O_TRUNC | fs.constants.O_APPEND))
    : !/^r$/.test(flags ?? "r");
  for (const key of ["open", "openSync"]) {
    const original = fs[key];
    fs[key] = function (file, flags, ...args) { checked(file, writing(flags)); return original.call(this, file, flags, ...args); };
  }
  for (const key of ["link", "linkSync", "symlink", "symlinkSync"]) replace(fs, key, "fs");
  const fsp = fs.promises;
  for (const key of ["readFile"]) {
    const original = fsp[key];
    fsp[key] = function (file, ...args) { checked(file, false); return original.call(this, file, ...args); };
  }
  for (const key of ["writeFile", "appendFile", "mkdir", "mkdtemp", "rm", "rmdir", "unlink", "truncate", "chmod", "chown", "utimes"]) {
    const original = fsp[key];
    if (typeof original === "function") fsp[key] = function (file, ...args) { checked(file, true); return original.call(this, file, ...args); };
  }
  for (const key of ["rename", "copyFile", "cp"]) {
    const original = fsp[key];
    fsp[key] = function (from, to, ...args) { checked(from, key === "rename"); checked(to, true); return original.call(this, from, to, ...args); };
  }
  for (const key of ["link", "symlink"]) replace(fsp, key, "fs.promises");
  const originalOpen = fsp.open;
  fsp.open = function (file, flags, ...args) { checked(file, writing(flags)); return originalOpen.call(this, file, flags, ...args); };
  Module.syncBuiltinESMExports();
  event({ kind: "FENCES_INSTALLED", networkForwardingAllowed: false, processCreationAllowed: false,
    workerCreationAllowed: false, credentialProfile: "exclusive-synthetic", kernelSandboxClaimed: false });
  return state;
}
module.exports = { installOfflineFence };