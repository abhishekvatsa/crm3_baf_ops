import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  auditEmittedOutput,
  cleanEmittedOutput,
  inspectExpectedOutput,
} from "./emitted_output_custody.mjs";

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-functions-emit-"));
  fs.mkdirSync(path.join(root, "src", "nested"), {recursive: true});
  fs.writeFileSync(
    path.join(root, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {
        module: "commonjs",
        outDir: "lib",
        sourceMap: true,
        target: "es2022",
      },
      include: ["src"],
    }),
  );
  fs.writeFileSync(path.join(root, "src", "alpha.ts"), "export const alpha = 1;\n");
  fs.writeFileSync(
    path.join(root, "src", "nested", "beta.ts"),
    "export const beta = 2;\n",
  );
  return {
    root,
    tsconfigPath: path.join(root, "tsconfig.json"),
  };
}

function materializeExpected(tsconfigPath) {
  const expected = inspectExpectedOutput({tsconfigPath});
  for (const relativePath of expected.expectedFiles) {
    const outputPath = path.join(expected.outDir, relativePath);
    fs.mkdirSync(path.dirname(outputPath), {recursive: true});
    fs.writeFileSync(outputPath, `${relativePath}\n`);
  }
  return expected;
}

test("exact emitted output passes for every configured TypeScript source", (t) => {
  const current = fixture();
  t.after(() => fs.rmSync(current.root, {recursive: true, force: true}));
  const expected = materializeExpected(current.tsconfigPath);

  const result = auditEmittedOutput({tsconfigPath: current.tsconfigPath});

  assert.equal(result.sourceCount, 2);
  assert.deepEqual(result.actualFiles, expected.expectedFiles);
  assert.equal(result.actualFiles.length, 4);
});

test("a deleted source cannot leave orphaned JavaScript or source maps", (t) => {
  const current = fixture();
  t.after(() => fs.rmSync(current.root, {recursive: true, force: true}));
  materializeExpected(current.tsconfigPath);
  fs.rmSync(path.join(current.root, "src", "nested", "beta.ts"));

  assert.throws(
    () => auditEmittedOutput({tsconfigPath: current.tsconfigPath}),
    (error) =>
      error.message.includes("orphaned emitted files") &&
      error.message.includes("nested/beta.js") &&
      error.message.includes("nested/beta.js.map"),
  );
});

test("a missing emitted file fails correspondence", (t) => {
  const current = fixture();
  t.after(() => fs.rmSync(current.root, {recursive: true, force: true}));
  const expected = materializeExpected(current.tsconfigPath);
  fs.rmSync(path.join(expected.outDir, "alpha.js"));

  assert.throws(
    () => auditEmittedOutput({tsconfigPath: current.tsconfigPath}),
    /missing emitted files: alpha\.js/,
  );
});

test("clean removes the complete configured output directory", (t) => {
  const current = fixture();
  t.after(() => fs.rmSync(current.root, {recursive: true, force: true}));
  const expected = materializeExpected(current.tsconfigPath);
  fs.writeFileSync(path.join(expected.outDir, "stale.js"), "stale\n");

  const result = cleanEmittedOutput({tsconfigPath: current.tsconfigPath});

  assert.equal(result.existed, true);
  assert.equal(fs.existsSync(expected.outDir), false);
});
