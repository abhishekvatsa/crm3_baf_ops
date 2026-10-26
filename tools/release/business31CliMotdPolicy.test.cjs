"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const p = require("./runtimeDeploymentTransportGuard31.cjs");
test("cached or newly fetched MOTD cannot require a CLI newer than the pinned version", () => {
  for (const minVersion of ["3.0.5", "15.22.3", "15.22.4", "15.22.4+build.1", "15.22.4-rc.1"]) assert.equal(p.assertMotdVersion31({ minVersion }), true);
  for (const minVersion of ["15.22.5", "15.23.0", "16.0.0", "15.23.0-alpha.1"]) assert.throws(() => p.assertMotdVersion31({ minVersion }), /exceeds pinned CLI/);
  for (const minVersion of ["bad", "15.22", "15.022.4", "15.22.4-01", "15.22.4 || 99", 3, null]) assert.throws(() => p.assertMotdVersion31({ minVersion }));
  assert.equal(p.assertMotdVersion31(null), true); assert.equal(p.assertMotdVersion31({}), true);
  assert.throws(() => p.assertMotdVersion31({}, "99.0.0"), /selected CLI version differs/);
});
test("MOTD freshness matches the pinned CLI strict 24-hour boundary at actual entry", () => {
  const fetched = 100000000, now = fetched + p.ONE_DAY_MS;
  assert.equal(p.inspectMotdCache31({ fetched, minVersion: "3.0.5" }, now - 1).fresh, true);
  assert.equal(p.inspectMotdCache31({ fetched }, now).fresh, false);
  assert.equal(p.inspectMotdCache31({ fetched }, now + 1).fresh, false);
  assert.equal(p.inspectMotdCache31(null, now).fresh, false);
  assert.throws(() => p.inspectMotdCache31({ fetched: now + 1 }, now), /timestamp differs/);
});
test("minimum version comparison follows numeric and prerelease precedence", () => {
  for (const [a,b] of [["3.0.5", "15.22.4"], ["15.22.4-alpha.2", "15.22.4-alpha.10"], ["15.22.4-9", "15.22.4-a"], ["15.22.4-rc.1", "15.22.4"]]) assert.equal(p.compareVersions31(a,b), -1);
});
