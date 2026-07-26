import {
  assertWorkflowAuthorityScope,
  canonicalWorkflowAuthorityScope,
} from "./commandAuthority";
import {WorkflowTransaction} from "./store";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./types";
import {payloadFingerprint} from "./utils";
import {WorkflowError} from "./errors";

export const receiptPath = (commandId: string): string => `maintenance_workflow_command_receipts/${commandId}`;

export const readExistingReceipt = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
  actor: Actor,
): Promise<WorkflowCommandReceipt | null> => {
  const snap = await tx.get(receiptPath(command.commandId));
  if (!snap.exists || snap.data == null) return null;

  const data = snap.data;
  if (data.receiptSchemaVersion !== 2) {
    const legacy = typeof data.payloadHash === "string" &&
      /^[0-9a-f]{16}$/i.test(data.payloadHash);
    throw new WorkflowError(
      "failed-precondition",
      legacy ?
        "The legacy workflow receipt requires governed reconciliation." :
        "The workflow receipt schema is unsupported or malformed.",
      {
        reasonCode: legacy ?
          "legacy-workflow-receipt-reconciliation-required" :
          "workflow-receipt-schema-unsupported",
        commandId: command.commandId,
      },
    );
  }

  if (typeof data.actorUid !== "string" || data.actorUid.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The workflow receipt owner is malformed.",
      {
        reasonCode: "workflow-receipt-owner-malformed",
        commandId: command.commandId,
      },
    );
  }
  if (data.actorUid !== actor.uid) {
    throw new WorkflowError(
      "permission-denied",
      "The workflow receipt belongs to another actor.",
      {
        reasonCode: "workflow-receipt-owner-mismatch",
        commandId: command.commandId,
      },
    );
  }

  const authorityScope = canonicalWorkflowAuthorityScope(
    data.authorityScope,
  );
  if (authorityScope == null) {
    throw new WorkflowError(
      "failed-precondition",
      "The workflow receipt authority scope is malformed.",
      {
        reasonCode: "workflow-receipt-authority-scope-malformed",
        commandId: command.commandId,
      },
    );
  }
  assertWorkflowAuthorityScope(actor, authorityScope);

  if (data.commandId !== command.commandId ||
      data.commandType !== command.commandType ||
      data.aggregateId !== command.aggregateId) {
    throw new WorkflowError(
      "failed-precondition",
      "The workflow receipt identity is malformed.",
      {
        reasonCode: "workflow-receipt-identity-malformed",
        commandId: command.commandId,
      },
    );
  }

  const expected = payloadFingerprint(command as unknown as JsonMap);
  if (typeof data.payloadFingerprint !== "string" ||
      !/^sha256:[0-9a-f]{64}$/.test(data.payloadFingerprint)) {
    throw new WorkflowError(
      "failed-precondition",
      "The workflow receipt fingerprint is malformed.",
      {
        reasonCode: "workflow-receipt-fingerprint-malformed",
        commandId: command.commandId,
      },
    );
  }
  if (data.payloadFingerprint !== expected) {
    throw new WorkflowError("command-idempotency-conflict", "Command ID was reused with a different payload.");
  }
  if (typeof data.resultKey !== "string" ||
      typeof data.aggregateVersion !== "number" ||
      !Number.isSafeInteger(data.aggregateVersion) ||
      data.result == null ||
      typeof data.result !== "object" ||
      Array.isArray(data.result) ||
      typeof data.appliedAt !== "string") {
    throw new WorkflowError(
      "failed-precondition",
      "The workflow receipt result is malformed.",
      {
        reasonCode: "workflow-receipt-result-malformed",
        commandId: command.commandId,
      },
    );
  }
  return {
    commandId: command.commandId,
    resultKey: data.resultKey,
    aggregateVersion: data.aggregateVersion,
    result: data.result as JsonMap,
    appliedAt: data.appliedAt,
  };
};
