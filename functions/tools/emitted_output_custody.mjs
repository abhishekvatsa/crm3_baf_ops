import fs from "node:fs";
import path from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";
import ts from "typescript";

const TOOL_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
export const functionsRoot = path.resolve(TOOL_DIRECTORY, "..");

function diagnosticText(diagnostic) {
  return ts.flattenDiagnosticMessageText(diagnostic.messageText, "\n");
}

function parseTsconfig(tsconfigPath) {
  const resolvedConfigPath = path.resolve(tsconfigPath);
  const configResult = ts.readConfigFile(resolvedConfigPath, ts.sys.readFile);
  if (configResult.error != null) {
    throw new Error(diagnosticText(configResult.error));
  }

  const parsed = ts.parseJsonConfigFileContent(
    configResult.config,
    ts.sys,
    path.dirname(resolvedConfigPath),
    undefined,
    resolvedConfigPath,
  );
  if (parsed.errors.length > 0) {
    throw new Error(parsed.errors.map(diagnosticText).join("\n"));
  }
  if (parsed.options.outDir == null) {
    throw new Error("TypeScript outDir must be configured for emitted-output custody");
  }
  return parsed;
}

function relativeFile(root, filePath) {
  return path.relative(root, filePath).split(path.sep).join("/");
}

function assertDescendant(root, candidate, label) {
  const relative = path.relative(root, candidate);
  if (
    relative === "" ||
    relative === ".." ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(`${label} must be a child of the Functions root: ${candidate}`);
  }
}

function listFiles(directory, root = directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }

  const files = [];
  for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(entryPath, root));
    } else if (entry.isFile()) {
      files.push(relativeFile(root, entryPath));
    } else {
      throw new Error(`Unsupported emitted-output entry: ${entryPath}`);
    }
  }
  return files.sort();
}

export function inspectExpectedOutput({
  tsconfigPath = path.join(functionsRoot, "tsconfig.json"),
} = {}) {
  const parsed = parseTsconfig(tsconfigPath);
  const root = path.dirname(path.resolve(tsconfigPath));
  const outDir = path.resolve(parsed.options.outDir);
  assertDescendant(root, outDir, "TypeScript outDir");

  const expectedFiles = new Set();
  for (const sourcePath of parsed.fileNames) {
    for (const outputPath of ts.getOutputFileNames(parsed, sourcePath, false)) {
      const resolvedOutputPath = path.resolve(outputPath);
      assertDescendant(outDir, resolvedOutputPath, "Emitted file");
      expectedFiles.add(relativeFile(outDir, resolvedOutputPath));
    }
  }

  return {
    outDir,
    sourceCount: parsed.fileNames.length,
    expectedFiles: [...expectedFiles].sort(),
  };
}

export function auditEmittedOutput(options = {}) {
  const expected = inspectExpectedOutput(options);
  const actualFiles = listFiles(expected.outDir);
  const expectedSet = new Set(expected.expectedFiles);
  const actualSet = new Set(actualFiles);
  const missing = expected.expectedFiles.filter((file) => !actualSet.has(file));
  const orphaned = actualFiles.filter((file) => !expectedSet.has(file));

  if (missing.length > 0 || orphaned.length > 0) {
    const details = [];
    if (missing.length > 0) {
      details.push(`missing emitted files: ${missing.join(", ")}`);
    }
    if (orphaned.length > 0) {
      details.push(`orphaned emitted files: ${orphaned.join(", ")}`);
    }
    throw new Error(details.join("\n"));
  }

  return {
    ...expected,
    actualFiles,
  };
}

export function cleanEmittedOutput({
  tsconfigPath = path.join(functionsRoot, "tsconfig.json"),
} = {}) {
  const expected = inspectExpectedOutput({tsconfigPath});
  const existed = fs.existsSync(expected.outDir);
  fs.rmSync(expected.outDir, {recursive: true, force: true});
  return {
    outDir: expected.outDir,
    existed,
  };
}

function runCli() {
  const command = process.argv[2];
  if (command === "clean") {
    const result = cleanEmittedOutput();
    console.log(
      `PASS_FUNCTIONS_EMIT_CLEAN: removed=${result.existed ? 1 : 0} outDir=lib`,
    );
    return;
  }
  if (command === "audit") {
    const result = auditEmittedOutput();
    console.log(
      "PASS_FUNCTIONS_EMITTED_OUTPUT: " +
        `sources=${result.sourceCount} files=${result.actualFiles.length} outDir=lib`,
    );
    return;
  }
  throw new Error("Usage: node tools/emitted_output_custody.mjs <clean|audit>");
}

if (
  process.argv[1] != null &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  try {
    runCli();
  } catch (error) {
    console.error(`FAIL_FUNCTIONS_EMITTED_OUTPUT: ${error.message}`);
    process.exitCode = 1;
  }
}
