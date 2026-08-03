import fs from "node:fs";
import path from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";
import ts from "typescript";

const TOOL_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
export const functionsRoot = path.resolve(TOOL_DIRECTORY, "..");
export const repositoryRoot = path.resolve(functionsRoot, "..");

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
  return ts.createProgram({rootNames: parsed.fileNames, options: parsed.options});
}

function unwrapped(expression) {
  let current = expression;
  while (
    ts.isAsExpression(current) ||
    ts.isParenthesizedExpression(current) ||
    ts.isSatisfiesExpression(current)
  ) {
    current = current.expression;
  }
  return current;
}

function calledName(call) {
  const expression = unwrapped(call.expression);
  if (ts.isIdentifier(expression)) return expression.text;
  if (ts.isPropertyAccessExpression(expression)) return expression.name.text;
  return null;
}

function propertyName(property) {
  if (
    ts.isIdentifier(property.name) ||
    ts.isStringLiteral(property.name) ||
    ts.isNumericLiteral(property.name)
  ) {
    return property.name.text;
  }
  return null;
}

function property(object, name) {
  if (!ts.isObjectLiteralExpression(object)) return null;
  return object.properties.find((candidate) =>
    (ts.isPropertyAssignment(candidate) || ts.isMethodDeclaration(candidate)) &&
    propertyName(candidate) === name) ?? null;
}

function callsWithin(node, name) {
  const result = [];
  function visit(candidate) {
    if (ts.isCallExpression(candidate) && calledName(candidate) === name) {
      result.push(candidate);
    }
    ts.forEachChild(candidate, visit);
  }
  visit(node);
  return result;
}

function callsWithinNames(node, names) {
  return [...names].flatMap((name) => callsWithin(node, name));
}

function hasExportModifier(node) {
  return node.modifiers?.some(
    (modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword,
  ) ?? false;
}

function relativeSourcePath(sourceRoot, sourceFile) {
  return path.relative(path.dirname(sourceRoot), sourceFile.fileName)
    .split(path.sep)
    .join("/");
}

function notificationDispatchNames(program, sourceRoot) {
  const names = new Set(["sendNotification"]);
  for (const sourceFile of program.getSourceFiles()) {
    const absolute = path.resolve(sourceFile.fileName);
    if (!absolute.toLowerCase().startsWith(
      `${path.resolve(sourceRoot).toLowerCase()}${path.sep}`,
    )) continue;
    for (const statement of sourceFile.statements) {
      if (!ts.isImportDeclaration(statement) ||
          !ts.isStringLiteral(statement.moduleSpecifier) ||
          !statement.moduleSpecifier.text.endsWith("notifications") ||
          statement.importClause?.namedBindings == null ||
          !ts.isNamedImports(statement.importClause.namedBindings)) {
        continue;
      }
      for (const element of statement.importClause.namedBindings.elements) {
        const importedName = element.propertyName?.text ?? element.name.text;
        if (importedName === "sendNotification") names.add(element.name.text);
      }
    }
  }
  return names;
}

function notificationTriggers(program, sourceRoot, dispatchNames) {
  const triggers = [];
  const ownedSendCalls = new Set();
  for (const sourceFile of program.getSourceFiles()) {
    const absolute = path.resolve(sourceFile.fileName);
    if (!absolute.toLowerCase().startsWith(
      `${path.resolve(sourceRoot).toLowerCase()}${path.sep}`,
    )) continue;

    for (const statement of sourceFile.statements) {
      if (!ts.isVariableStatement(statement) || !hasExportModifier(statement)) {
        continue;
      }
      for (const declaration of statement.declarationList.declarations) {
        if (!ts.isIdentifier(declaration.name) || declaration.initializer == null) {
          continue;
        }
        const initializer = unwrapped(declaration.initializer);
        if (!ts.isCallExpression(initializer) ||
            !["onDocumentCreated", "onDocumentUpdated", "onDocumentWritten"]
              .includes(calledName(initializer))) {
          continue;
        }
        const sendCalls = callsWithinNames(initializer, dispatchNames);
        if (sendCalls.length === 0) continue;
        sendCalls.forEach((call) => ownedSendCalls.add(call));
        triggers.push({
          name: declaration.name.text,
          sourcePath: relativeSourcePath(sourceRoot, sourceFile),
          call: initializer,
          sendCalls,
        });
      }
    }
  }
  return {triggers, ownedSendCalls};
}

function allSourceCalls(program, sourceRoot, names) {
  const calls = [];
  for (const sourceFile of program.getSourceFiles()) {
    const absolute = path.resolve(sourceFile.fileName);
    if (!absolute.toLowerCase().startsWith(
      `${path.resolve(sourceRoot).toLowerCase()}${path.sep}`,
    )) continue;
    calls.push(...callsWithinNames(sourceFile, names));
  }
  return calls;
}

function hasDirectMessagingDispatch(program, sourceRoot) {
  const directMethods = new Set([
    "send",
    "sendEach",
    "sendEachForMulticast",
    "sendMulticast",
    "sendToTopic",
  ]);
  for (const sourceFile of program.getSourceFiles()) {
    const absolute = path.resolve(sourceFile.fileName);
    if (!absolute.toLowerCase().startsWith(
      `${path.resolve(sourceRoot).toLowerCase()}${path.sep}`,
    )) continue;
    let found = false;
    function visit(node) {
      if (ts.isCallExpression(node)) {
        const expression = unwrapped(node.expression);
        if (ts.isPropertyAccessExpression(expression) &&
            directMethods.has(expression.name.text)) {
          const receiver = unwrapped(expression.expression);
          if (ts.isCallExpression(receiver) &&
              ["messaging", "getMessaging"].includes(calledName(receiver))) {
            found = true;
          }
        }
      }
      if (!found) ts.forEachChild(node, visit);
    }
    visit(sourceFile);
    if (found) return true;
  }
  return false;
}

function sortedIdentities(items) {
  return items
    .map(({name, sourcePath}) => `${name}|${sourcePath}`)
    .sort();
}

export function auditNotificationTriggerInventory({
  tsconfigPath = path.join(functionsRoot, "tsconfig.json"),
  sourceRoot = path.join(functionsRoot, "src"),
  policyPath = path.join(
    repositoryRoot,
    "release",
    "r05-notification-trigger-source-policy.json",
  ),
} = {}) {
  const program = createProgram(path.resolve(tsconfigPath));
  const policy = JSON.parse(fs.readFileSync(policyPath, "utf8"));
  const coordinatorName = policy.receiptCoordinator;
  const expected = policy.notificationTriggers;
  if (policy.schemaVersion !== 1 ||
      coordinatorName !== "executeIdempotentNotificationEvent" ||
      policy.receiptCollection !== "notification_event_receipts" ||
      !Array.isArray(expected)) {
    throw new Error("R-05 notification trigger policy is malformed");
  }

  const dispatchNames = notificationDispatchNames(program, sourceRoot);
  const {triggers, ownedSendCalls} = notificationTriggers(
    program,
    sourceRoot,
    dispatchNames,
  );
  const errors = [];
  if (JSON.stringify(sortedIdentities(triggers)) !==
      JSON.stringify(sortedIdentities(expected))) {
    errors.push(
      `notification-trigger-policy-mismatch discovered=${JSON.stringify(
        sortedIdentities(triggers),
      )} expected=${JSON.stringify(sortedIdentities(expected))}`,
    );
  }

  const allSendCalls = allSourceCalls(program, sourceRoot, dispatchNames);
  if (allSendCalls.some((call) => !ownedSendCalls.has(call))) {
    errors.push("unowned-notification-dispatch-call");
  }
  if (hasDirectMessagingDispatch(program, sourceRoot)) {
    errors.push("direct-fcm-dispatch-bypasses-notification-coordinator");
  }

  for (const trigger of triggers) {
    const options = unwrapped(trigger.call.arguments[0]);
    const retry = property(options, "retry");
    if (retry == null ||
        !ts.isPropertyAssignment(retry) ||
        retry.initializer.kind !== ts.SyntaxKind.TrueKeyword) {
      errors.push(`notification-trigger-retry-missing trigger=${trigger.name}`);
    }
    const coordinatorCalls = callsWithin(trigger.call, coordinatorName);
    if (coordinatorCalls.length !== 1) {
      errors.push(`notification-receipt-coordinator-missing trigger=${trigger.name}`);
      continue;
    }
    const coordinator = coordinatorCalls[0];
    const args = unwrapped(coordinator.arguments[0]);
    const eventId = property(args, "cloudEventId");
    const eventIdExpression = eventId != null && ts.isPropertyAssignment(eventId)
      ? unwrapped(eventId.initializer)
      : null;
    if (!ts.isPropertyAccessExpression(eventIdExpression) ||
        !ts.isIdentifier(eventIdExpression.expression) ||
        eventIdExpression.expression.text !== "event" ||
        eventIdExpression.name.text !== "id") {
      errors.push(`notification-cloud-event-identity-missing trigger=${trigger.name}`);
    }
    const dispatchProperty = property(args, "dispatch");
    const dispatchSendCalls = new Set(
      dispatchProperty == null
        ? []
        : callsWithinNames(dispatchProperty, dispatchNames),
    );
    if (!trigger.sendCalls.every((sendCall) => dispatchSendCalls.has(sendCall))) {
      errors.push(`notification-dispatch-outside-receipt-boundary trigger=${trigger.name}`);
    }
  }

  return {
    errors,
    triggerNames: triggers.map((trigger) => trigger.name).sort(),
  };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = auditNotificationTriggerInventory();
  if (result.errors.length > 0) {
    result.errors.forEach((error) => console.error(`FAIL_NOTIFICATION_TRIGGER_INVENTORY: ${error}`));
    process.exitCode = 1;
  } else {
    console.log(
      `PASS_NOTIFICATION_TRIGGER_INVENTORY: triggers=${result.triggerNames.length} ` +
      `names=${result.triggerNames.join(",")}`,
    );
  }
}
