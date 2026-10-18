"use strict";
const test = require("node:test");
const driver = require("./testdata/business31CliDeployDriver.cjs");
// This is a real CLI routing regression. Preparation's body and all release calls are outside its scope.
let run;
test.before(() => { run = driver.createRun("prepare-entry"); });
test.after(() => { if (run) driver.assertPopulationUnchanged(run); });
for (const phase of driver.PHASES) {
  test("real guarded firebase deploy reaches prepare for exact " + phase + " filter offline", () => {
    const report = driver.runSample(run, phase);
    driver.assertPrepareSample(report);
  });
}