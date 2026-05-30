// Rules-unit tests talk to the Firestore emulator over the network.
// Loading/compiling a large security-rules file and clearing data between
// tests can take well over Jest's 5s default, so give hooks and tests headroom.
module.exports = {
  testEnvironment: "node",
  testTimeout: 60000,
  // Scope to the root test/ folder only (excludes functions/test/*).
  testMatch: ["<rootDir>/test/**/*.test.js"],
};
