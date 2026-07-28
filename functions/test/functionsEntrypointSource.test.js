const fs = require("fs");
const path = require("path");

const functionsRoot = path.resolve(__dirname, "..");

describe("Functions entrypoint source custody", () => {
  test("package and root compatibility path resolve to one compiled entrypoint", () => {
    const packageJson = JSON.parse(
      fs.readFileSync(path.join(functionsRoot, "package.json"), "utf8"),
    );
    const rootEntrypoint = fs
      .readFileSync(path.join(functionsRoot, "index.js"), "utf8")
      .replace(/\r\n/g, "\n")
      .trim();

    expect(packageJson.main).toBe("lib/index.js");
    expect(rootEntrypoint).toBe(
      '"use strict";\n\nmodule.exports = require("./lib/index.js");',
    );
  });

  test("notification triggers have only the TypeScript implementation", () => {
    const typescriptEntrypoint = fs.readFileSync(
      path.join(functionsRoot, "src", "index.ts"),
      "utf8",
    );

    for (const exportName of [
      "onTicketCreated",
      "onTicketResolved",
      "onJobAssigned",
    ]) {
      expect(typescriptEntrypoint).toContain(`export const ${exportName} =`);
    }
  });
});
