import fs from "node:fs";
import path from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";
import ts from "typescript";

const TOOL_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
export const functionsRoot = path.resolve(TOOL_DIRECTORY, "..");
export const repositoryRoot = path.resolve(functionsRoot, "..");

function sourceFile(program, sourcePath) {
  const expected = path.resolve(sourcePath).toLowerCase();
  const match = program.getSourceFiles().find(
    (candidate) => path.resolve(candidate.fileName).toLowerCase() === expected,
  );
  if (match == null) {
    throw new Error(`Source file is outside the TypeScript program: ${sourcePath}`);
  }
  return match;
}

function createProgram(tsconfigPath) {
  const configResult = ts.readConfigFile(tsconfigPath, ts.sys.readFile);
  if (configResult.error != null) {
    throw new Error(ts.flattenDiagnosticMessageText(
      configResult.error.messageText,
      "\n",
    ));
  }
  const parsed = ts.parseJsonConfigFileContent(
    configResult.config,
    ts.sys,
    path.dirname(tsconfigPath),
  );
  if (parsed.errors.length > 0) {
    throw new Error(parsed.errors.map((diagnostic) =>
      ts.flattenDiagnosticMessageText(diagnostic.messageText, "\n")).join("\n"));
  }
  return ts.createProgram({
    rootNames: parsed.fileNames,
    options: parsed.options,
  });
}

function resolvedSymbol(checker, symbol) {
  let current = symbol;
  const seen = new Set();
  while ((current.flags & ts.SymbolFlags.Alias) !== 0) {
    if (seen.has(current)) break;
    seen.add(current);
    const next = checker.getAliasedSymbol(current);
    if (next === current) break;
    current = next;
  }
  return current;
}

function unwrappedExpression(expression) {
  let current = expression;
  while (
    ts.isAsExpression(current)
    || ts.isParenthesizedExpression(current)
    || ts.isSatisfiesExpression(current)
  ) {
    current = current.expression;
  }
  return current;
}

function variableDeclaration(symbol) {
  const candidates = [
    symbol.valueDeclaration,
    ...(symbol.getDeclarations() ?? []),
  ];
  return candidates.find((declaration) =>
    declaration != null && ts.isVariableDeclaration(declaration));
}

function callExpressionForSymbol(symbol) {
  const declaration = variableDeclaration(symbol);
  if (declaration?.initializer == null) return null;
  const initializer = unwrappedExpression(declaration.initializer);
  if (!ts.isCallExpression(initializer)) return null;
  const calledName = ts.isIdentifier(initializer.expression)
    ? initializer.expression.text
    : ts.isPropertyAccessExpression(initializer.expression)
      ? initializer.expression.name.text
      : null;
  if (calledName !== "onCall") return null;
  return {declaration, initializer};
}

function propertyName(property) {
  if (
    ts.isIdentifier(property.name)
    || ts.isStringLiteral(property.name)
    || ts.isNumericLiteral(property.name)
  ) {
    return property.name.text;
  }
  return null;
}

function classificationFromSource(program, classificationPath) {
  const source = sourceFile(program, classificationPath);
  for (const statement of source.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      if (
        !ts.isIdentifier(declaration.name)
        || declaration.name.text !== "CALLABLE_SECURITY_CLASSIFICATION"
        || declaration.initializer == null
      ) {
        continue;
      }
      const initializer = unwrappedExpression(declaration.initializer);
      if (!ts.isObjectLiteralExpression(initializer)) {
        throw new Error(
          "CALLABLE_SECURITY_CLASSIFICATION must be an object literal",
        );
      }
      const result = new Map();
      for (const property of initializer.properties) {
        if (
          !ts.isPropertyAssignment(property)
          || !ts.isStringLiteral(property.initializer)
        ) {
          throw new Error(
            "Callable classification entries must be string properties",
          );
        }
        const name = propertyName(property);
        if (name == null || result.has(name)) {
          throw new Error("Callable classification names must be unique");
        }
        result.set(name, property.initializer.text);
      }
      return result;
    }
  }
  throw new Error("CALLABLE_SECURITY_CLASSIFICATION was not found");
}

function exportedOnCallDeclarations(program, entrypointPath) {
  const source = sourceFile(program, entrypointPath);
  const checker = program.getTypeChecker();
  const moduleSymbol = checker.getSymbolAtLocation(source);
  if (moduleSymbol == null) {
    throw new Error(`Entrypoint has no module symbol: ${entrypointPath}`);
  }

  const result = new Map();
  for (const exported of checker.getExportsOfModule(moduleSymbol)) {
    const symbol = resolvedSymbol(checker, exported);
    const call = callExpressionForSymbol(symbol);
    if (call == null) continue;
    result.set(exported.name, call);
  }
  return result;
}

function optionSpreads(call) {
  const options = call.initializer.arguments[0];
  if (options == null || !ts.isObjectLiteralExpression(options)) return [];
  return options.properties
    .filter(ts.isSpreadAssignment)
    .map((property) => property.expression.getText());
}

function containsCallableName(call, callableName) {
  let found = false;
  function visit(node) {
    if (
      ts.isPropertyAssignment(node)
      && propertyName(node) === "callableName"
      && ts.isStringLiteral(node.initializer)
      && node.initializer.text === callableName
    ) {
      found = true;
    }
    if (!found) ts.forEachChild(node, visit);
  }
  visit(call.initializer);
  return found;
}

function calledFunctions(call) {
  const names = new Set();
  function visit(node) {
    if (ts.isCallExpression(node)) {
      if (ts.isIdentifier(node.expression)) {
        names.add(node.expression.text);
      } else if (ts.isPropertyAccessExpression(node.expression)) {
        names.add(node.expression.name.text);
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(call.initializer);
  return names;
}

function sorted(values) {
  return [...values].sort();
}

function sameValues(left, right) {
  return JSON.stringify(sorted(left)) === JSON.stringify(sorted(right));
}

export function auditCallableInventory({
  tsconfigPath = path.join(functionsRoot, "tsconfig.json"),
  entrypointPath = path.join(functionsRoot, "src", "index.ts"),
  classificationPath = path.join(
    functionsRoot,
    "src",
    "callableInventory.ts",
  ),
  policyPath = path.join(
    repositoryRoot,
    "release",
    "s02-callable-app-check-source-policy.json",
  ),
} = {}) {
  const program = createProgram(path.resolve(tsconfigPath));
  const exported = exportedOnCallDeclarations(program, entrypointPath);
  const classification = classificationFromSource(
    program,
    classificationPath,
  );
  const policyDocument = JSON.parse(fs.readFileSync(policyPath, "utf8"));
  const policy = policyDocument.callableAppCheckPolicy;
  if (policy == null || typeof policy !== "object") {
    throw new Error("Governed callableAppCheckPolicy is missing");
  }

  const errors = [];
  const exportedNames = sorted(exported.keys());
  const classifiedNames = sorted(classification.keys());
  if (!sameValues(exportedNames, classifiedNames)) {
    errors.push(
      `export-classification-mismatch exported=${exportedNames.join(",")} ` +
      `classified=${classifiedNames.join(",")}`,
    );
  }

  const invalidKinds = [...classification.entries()]
    .filter(([, kind]) => kind !== "mutating" && kind !== "read-only")
    .map(([name, kind]) => `${name}:${kind}`);
  if (invalidKinds.length > 0) {
    errors.push(`invalid-classifications ${invalidKinds.join(",")}`);
  }

  const mutatingNames = sorted(
    [...classification.entries()]
      .filter(([, kind]) => kind === "mutating")
      .map(([name]) => name),
  );
  const readOnlyNames = sorted(
    [...classification.entries()]
      .filter(([, kind]) => kind === "read-only")
      .map(([name]) => name),
  );
  if (!sameValues(mutatingNames, policy.mutatingCallables ?? [])) {
    errors.push("governed-mutating-inventory-mismatch");
  }
  if (
    !sameValues(
      readOnlyNames,
      Object.keys(policy.readOnlySecurityOptionsByCallable ?? {}),
    )
  ) {
    errors.push("governed-read-only-inventory-mismatch");
  }

  const allPolicyOptionNames = new Set([
    policy.mutatingSecurityOptionsExport,
    ...Object.values(policy.readOnlySecurityOptionsByCallable ?? {}),
  ]);
  for (const [name, call] of exported.entries()) {
    const kind = classification.get(name);
    const expectedOptions = kind === "mutating"
      ? policy.mutatingSecurityOptionsExport
      : policy.readOnlySecurityOptionsByCallable?.[name];
    const spreads = optionSpreads(call);
    if (typeof expectedOptions !== "string" || !spreads.includes(expectedOptions)) {
      errors.push(
        `callable-security-options-missing callable=${name} ` +
        `expected=${String(expectedOptions)}`,
      );
    }
    const conflicting = spreads.filter(
      (spread) => allPolicyOptionNames.has(spread) && spread !== expectedOptions,
    );
    if (conflicting.length > 0) {
      errors.push(
        `callable-security-options-conflict callable=${name} ` +
        `spreads=${conflicting.join(",")}`,
      );
    }
    if (kind === "mutating") {
      if (!containsCallableName(call, name)) {
        errors.push(`abuse-control-callable-name-missing callable=${name}`);
      }
      const calls = calledFunctions(call);
      if (
        !calls.has("executeAuthorizedMutation")
        && !calls.has("executeWithCallableAbuseControl")
      ) {
        errors.push(`abuse-control-admission-missing callable=${name}`);
      }
    }
  }

  return {
    errors,
    exportedNames,
    mutatingNames,
    readOnlyNames,
  };
}

function main() {
  const result = auditCallableInventory();
  if (result.errors.length > 0) {
    result.errors.forEach((error) =>
      console.error(`CALLABLE_INVENTORY_ERROR: ${error}`));
    process.exitCode = 1;
    return;
  }
  console.log(
    `PASS_CALLABLE_SECURITY_INVENTORY: exported=${result.exportedNames.length} ` +
    `mutating=${result.mutatingNames.length} ` +
    `readOnly=${result.readOnlyNames.length}`,
  );
}

if (
  process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main();
}
