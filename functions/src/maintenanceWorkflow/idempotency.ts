import {WorkflowTransaction} from "./store";
import {JsonMap, WorkflowCommand, WorkflowCommandReceipt} from "./types";
import {payloadHash} from "./utils";
import {WorkflowError} from "./errors";

export const receiptPath = (commandId: string): string => `maintenance_workflow_command_receipts/${commandId}`;

export const readExistingReceipt = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
): Promise<WorkflowCommandReceipt | null> => {
  const snap = await tx.get(receiptPath(command.commandId));
  if (!snap.exists || snap.data == null) return null;
  const expected = payloadHash(command as unknown as JsonMap);
  if (snap.data.payloadHash !== expected) {
    throw new WorkflowError("command-idempotency-conflict", "Command ID was reused with a different payload.");
  }
  return snap.data as unknown as WorkflowCommandReceipt;
};
