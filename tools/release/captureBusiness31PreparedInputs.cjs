"use strict";
// Fixed CAPTURE argv is retained. No recorder/helper/CLI is imported in main
// until the separately selected bootstrap has installed the fresh load guard.
if (require.main === module) {
  const bootstrap = require("./business31CaptureBootstrap.cjs");
  setImmediate(() => bootstrap.runOperationalPhaseMain31(module).catch(error => {
    process.stderr.write("Business cohort failed: " + error.message + "\n");
    process.exitCode = 1;
  }));
} else {
  module.exports = require("./business31CaptureRecorder.cjs");
}
