import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  auditNotificationTriggerInventory,
} from "./audit_notification_trigger_inventory.mjs";

function fixture(context, source, triggers = [
  {name: "knownNotification", sourcePath: "src/index.ts"},
], delegatedReceiptDispatchers = []) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-notifications-"));
  context.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const src = path.join(root, "src");
  fs.mkdirSync(src);
  fs.writeFileSync(
    path.join(root, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {module: "commonjs", target: "es2022"},
      include: ["src"],
    }),
  );
  fs.writeFileSync(path.join(src, "index.ts"), source);
  const policyPath = path.join(root, "policy.json");
  fs.writeFileSync(policyPath, JSON.stringify({
    schemaVersion: 1,
    receiptCoordinator: "executeIdempotentNotificationEvent",
    receiptCollection: "notification_event_receipts",
    delegatedReceiptDispatchers,
    notificationTriggers: triggers,
  }));
  return {
    tsconfigPath: path.join(root, "tsconfig.json"),
    sourceRoot: src,
    policyPath,
  };
}

const declarations = [
  "declare function onDocumentCreated(options: object, handler: Function): Function;",
  "declare function sendNotification(args: object): Promise<object>;",
  "declare function executeIdempotentNotificationEvent(args: object): Promise<object>;",
].join("\n");

const governedTrigger = [
  "export const knownNotification = onDocumentCreated(",
  "  {document: 'items/{id}', retry: true},",
  "  async (event: any) => executeIdempotentNotificationEvent({",
  "    cloudEventId: event.id,",
  "    prepare: async () => ({ready: true}),",
  "    dispatch: async () => sendNotification({}),",
  "  }),",
  ");",
].join("\n");

test("current notification trigger inventory is exact", () => {
  const result = auditNotificationTriggerInventory();
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.triggerNames, [
    "onJobAssigned",
    "onMaintenanceWorkflowEventCreated",
    "onTicketCreated",
    "onTicketResolved",
  ]);
});

test("a newly added notification trigger is discovered and fails closed", (context) => {
  const options = fixture(context, [
    declarations,
    governedTrigger,
    "export const newNotification = onDocumentCreated(",
    "  {document: 'new/{id}'},",
    "  async () => sendNotification({}),",
    ");",
  ].join("\n"));
  const result = auditNotificationTriggerInventory(options);
  assert.ok(result.triggerNames.includes("newNotification"));
  assert.ok(result.errors.some((error) =>
    error.startsWith("notification-trigger-policy-mismatch")));
  assert.ok(result.errors.includes(
    "notification-trigger-retry-missing trigger=newNotification",
  ));
  assert.ok(result.errors.includes(
    "notification-receipt-coordinator-missing trigger=newNotification",
  ));
});

test("FCM dispatch cannot sit outside the receipt dispatch callback", (context) => {
  const options = fixture(context, [
    declarations,
    "export const knownNotification = onDocumentCreated(",
    "  {document: 'items/{id}', retry: true},",
    "  async (event: any) => {",
    "    await executeIdempotentNotificationEvent({",
    "      cloudEventId: event.id,",
    "      prepare: async () => ({ready: true}),",
    "      dispatch: async () => ({attempted: 0}),",
    "    });",
    "    await sendNotification({});",
    "  },",
    ");",
  ].join("\n"));
  const result = auditNotificationTriggerInventory(options);
  assert.ok(result.errors.includes(
    "notification-dispatch-outside-receipt-boundary trigger=knownNotification",
  ));
});

test("an explicitly owned per-recipient dispatcher remains receipt-bound", (context) => {
  const delegated = [{
    name: "deliverRecipients",
    triggerName: "knownNotification",
    sourcePath: "src/index.ts",
    cloudEventIdDeriver: "recipientEventId",
  }];
  const options = fixture(context, [
    declarations,
    "function recipientEventId(eventId: string, token: string) {",
    "  return `${eventId}:${token}`;",
    "}",
    "async function deliverRecipients(args: any) {",
    "  return executeIdempotentNotificationEvent({",
    "    cloudEventId: recipientEventId(args.cloudEventId, 'token'),",
    "    prepare: async () => ({ready: true}),",
    "    dispatch: async () => sendNotification({}),",
    "  });",
    "}",
    "export const knownNotification = onDocumentCreated(",
    "  {document: 'items/{id}', retry: true},",
    "  async (event: any) => {",
    "    await deliverRecipients({cloudEventId: event.id});",
    "    return executeIdempotentNotificationEvent({",
    "      cloudEventId: event.id,",
    "      prepare: async () => ({ready: true}),",
    "      dispatch: async () => sendNotification({}),",
    "    });",
    "  },",
    ");",
  ].join("\n"), undefined, delegated);
  const result = auditNotificationTriggerInventory(options);
  assert.deepEqual(result.errors, []);
});

test("a delegated dispatcher cannot escape its receipt or raw-copy event identity", (context) => {
  const delegated = [{
    name: "deliverRecipients",
    triggerName: "knownNotification",
    sourcePath: "src/index.ts",
    cloudEventIdDeriver: "recipientEventId",
  }];
  const options = fixture(context, [
    declarations,
    "async function deliverRecipients(args: any) {",
    "  await executeIdempotentNotificationEvent({",
    "    cloudEventId: args.cloudEventId,",
    "    prepare: async () => ({ready: true}),",
    "    dispatch: async () => ({attempted: 0}),",
    "  });",
    "  return sendNotification({});",
    "}",
    "export const knownNotification = onDocumentCreated(",
    "  {document: 'items/{id}', retry: true},",
    "  async (event: any) => {",
    "    await deliverRecipients({cloudEventId: event.id});",
    "    return executeIdempotentNotificationEvent({",
    "      cloudEventId: event.id,",
    "      prepare: async () => ({ready: true}),",
    "      dispatch: async () => sendNotification({}),",
    "    });",
    "  },",
    ");",
  ].join("\n"), undefined, delegated);
  const result = auditNotificationTriggerInventory(options);
  assert.ok(result.errors.includes(
    "delegated-notification-identity-deriver-missing helper=deliverRecipients",
  ));
  assert.ok(result.errors.includes(
    "delegated-notification-dispatch-outside-receipt helper=deliverRecipients",
  ));
  assert.ok(result.errors.includes("unowned-notification-dispatch-call"));
});

test("unowned helper and direct Admin FCM dispatches fail closed", (context) => {
  const options = fixture(context, [
    declarations,
    "declare const admin: any;",
    governedTrigger,
    "async function bypass() {",
    "  await sendNotification({});",
    "  await admin.messaging().send({});",
    "}",
  ].join("\n"));
  const result = auditNotificationTriggerInventory(options);
  assert.ok(result.errors.includes("unowned-notification-dispatch-call"));
  assert.ok(result.errors.includes(
    "direct-fcm-dispatch-bypasses-notification-coordinator",
  ));
});

test("an aliased notification dispatcher remains discoverable", (context) => {
  const options = fixture(context, [
    "declare function onDocumentCreated(options: object, handler: Function): Function;",
    "declare function executeIdempotentNotificationEvent(args: object): Promise<object>;",
    "import {sendNotification as deliver} from './notifications';",
    "export const knownNotification = onDocumentCreated(",
    "  {document: 'items/{id}'},",
    "  async () => deliver({}),",
    ");",
  ].join("\n"));
  fs.writeFileSync(
    path.join(options.sourceRoot, "notifications.ts"),
    "export async function sendNotification(_: object) { return {}; }",
  );
  const result = auditNotificationTriggerInventory(options);
  assert.deepEqual(result.triggerNames, ["knownNotification"]);
  assert.ok(result.errors.includes(
    "notification-trigger-retry-missing trigger=knownNotification",
  ));
  assert.ok(result.errors.includes(
    "notification-receipt-coordinator-missing trigger=knownNotification",
  ));
});
