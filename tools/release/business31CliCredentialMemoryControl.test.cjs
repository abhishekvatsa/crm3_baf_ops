"use strict";
// The deliberately unfiltered comparison never has a file/console logging sink.
// Its only output is a small boolean/count result; credential-bearing strings remain in memory.
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const REFRESH = "SYNTHETIC_MEMORY_REFRESH_CANARY_31", SECRET = "SYNTHETIC_MEMORY_CLIENT_CANARY_31";
if (process.argv[2] !== "--memory-control-child") {
  const test = require("node:test"), os = require("node:os"), cp = require("node:child_process");
  test("real pinned fetch failure exposes encoded payload only to an in-memory comparison sink", () => {
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "b31-credential-memory-")), env = {};
    for (const key of ["SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT"]) {
      if (process.env[key] !== undefined) env[key] = process.env[key];
    }
    for (const key of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CLOUDSDK_CONFIG", "TEMP", "TMP"]) {
      env[key] = path.join(scratch, key); fs.mkdirSync(env[key]);
    }
    Object.assign(env, { PATH: path.dirname(process.execPath), CI: "true", NO_COLOR: "1", NO_UPDATE_NOTIFIER: "1" });
    const result = cp.spawnSync(process.execPath, [__filename, "--memory-control-child", scratch], {
      cwd: scratch, env, encoding: "utf8", windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024
    });
    const output = result.stdout + result.stderr;
    for (const canary of [REFRESH, SECRET]) {
      assert(!output.includes(canary), "memory-control output contains a synthetic credential");
      assert(!output.includes([...Buffer.from(canary)].join(",")), "memory-control output contains encoded credential bytes");
      assert(!output.includes(Buffer.from(canary).toString("base64")), "memory-control output contains encoded credentials");
    }
    const failureStage = result.stderr.match(/Memory-control regression failed at (initialization|configstore|logger|apiv2-load|actual-auth-refresh|memory-assertions); payload omitted\./)?.[1] ?? "unknown";
    assert.equal(result.status, 0, "bounded memory-control child failed at " + failureStage + " without retaining its payload");
    assert.equal(result.signal, null); assert.equal(result.error, undefined);
    assert.deepEqual(JSON.parse(result.stdout), { ok: true, actualPhysicalAttempts: 1, encodedCanariesObservedInMemory: 2,
      debugCallsReachedPhysicalSinks: 0, networkForwarded: false, realCliEntryInvoked: false });
    const visit = directory => {
      for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
        const file = path.join(directory, item.name);
        if (item.isDirectory()) visit(file);
        else assert(!/\.log$/.test(item.name), "memory control must not create a debug log");
      }
    };
    visit(scratch);
  });
} else {
  let stage = "initialization";
  (async () => {
    const scratch = process.argv[3], cli = path.resolve(__dirname, "../../tooling/firebase-cli/node_modules/firebase-tools");
    const lib = path.join(cli, "lib"), transport = require("./runtimeDeploymentTransportGuard31.cjs");
    const { Writable } = require("node:stream"), https = require("node:https");
    const fence = require("./testdata/business31CliOfflineFence.cjs").installOfflineFence({
      scratch, source: __dirname, cliRoot: path.dirname(cli), readFiles: [process.execPath], event() {}
    });
    // Reuse the existing finite synthetic kernel metadata on Linux as well as Windows.
    const kernel = require("./testdata/business31CliSyntheticKernel.cjs");
    const kernelFile = path.join(scratch, kernel.KERNEL_RELATIVE);
    fs.mkdirSync(path.dirname(kernelFile), { recursive: true });
    fs.writeFileSync(kernelFile, kernel.KERNEL_TEXT, { flag: "wx" });
    const fixture = { path: kernelFile, bytes: Buffer.byteLength(kernel.KERNEL_TEXT),
      sha256: require("node:crypto").createHash("sha256").update(kernel.KERNEL_TEXT).digest("hex").toUpperCase() };
    fs.readFileSync = kernel.createSyntheticKernelReader({ readFileSync: fs.readFileSync, fixture, scratch, event() {} });
    stage = "configstore";
    assert.equal(require(path.join(cli, "package.json")).version, "15.22.4");
    const { configstore } = require(path.join(lib, "configstore.js"));
    assert(path.resolve(configstore.path).startsWith(path.resolve(scratch) + path.sep));
    configstore.set("user", { email: "memory-control@example.invalid" });
    configstore.set("tokens", { refresh_token: REFRESH, access_token: "synthetic-expired", expires_at: 1, scopes: [] });
    process.env.FIREBASE_CLIENT_SECRET = SECRET;
    stage = "logger";
    const { logger } = require(path.join(lib, "logger.js"));
    // No File transport is installed. Silence every ordinary transport, including error logging.
    logger.silent = true;
    const originalDebug = logger.debug;
    const observed = new Set();
    logger.debug = function (message) {
      if (typeof message !== "string" || !message.startsWith("*** [apiv2] error from fetch(")) return;
      for (const match of message.matchAll(/"data"\s*:\s*\[([\d,\s]+)\]/g)) {
        const values = match[1].split(",").map(Number);
        assert(values.every(value => Number.isInteger(value) && value >= 0 && value <= 255));
        const bytes = Buffer.from(values);
        if (bytes.includes(Buffer.from(REFRESH))) observed.add("refresh");
        if (bytes.includes(Buffer.from(SECRET))) observed.add("client");
        bytes.fill(0); values.fill(0);
      }
      // No message, FormData, byte array, token or response is returned, logged or retained.
    };
    let attempts = 0;
    https.request = function (input, options) {
      const effective = transport.effectiveRequest31(input, options, "https:");
      assert.equal(effective.url.href, "https://www.googleapis.com/oauth2/v3/token");
      assert.equal(effective.method, "POST"); assert.equal(++attempts, 1);
      const request = new Writable({ write(_chunk, _encoding, done) { done(); },
        final(done) { done(Error("SYNTHETIC_PHYSICAL_REFRESH_FAILURE")); } });
      request.abort = () => request.destroy(); request.setTimeout = () => request;
      request.setHeader = () => {}; request.getHeader = () => undefined;
      return request;
    };
    const names = Array.from({ length: 19 }, (_, index) => "synthetic" + index);
    const guard = new transport.RuntimeDeploymentTransportGuard31({ names: [names[0]], allNames: names,
      baselineFunctions: {}, phase: "callables" });
    transport.installNetworkBoundary31(guard);
    stage = "apiv2-load";
    const api = require(path.join(lib, "apiv2.js"));
    transport.installApiBoundary31(api.Client, guard, () => { throw Error("No mutation in memory control"); });
    stage = "actual-auth-refresh";
    let refused;
    try { await require(path.join(lib, "auth.js")).getAccessToken(REFRESH, []); }
    catch (error) { refused = error; }
    logger.debug = originalDebug;
    stage = "memory-assertions";
    assert(refused?.message.startsWith("Authentication Error: Your credentials are no longer valid."));
    assert.equal(observed.size, 2, "real pinned fetch catch did not reach the in-memory encoded-payload comparison");
    assert.equal(attempts, 1); assert.deepEqual(fence.denials, []);
    process.stdout.write(JSON.stringify({ ok: true, actualPhysicalAttempts: attempts, encodedCanariesObservedInMemory: observed.size,
      debugCallsReachedPhysicalSinks: 0, networkForwarded: false, realCliEntryInvoked: false }));
    observed.clear();
  })().catch(() => { process.stderr.write("Memory-control regression failed at " + stage + "; payload omitted.\n"); process.exitCode = 1; });
}
