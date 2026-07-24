import {payloadHash, iso} from "./utils";
import {WorkflowError} from "./errors";
import {CommandContext, JsonMap, WorkflowCommand, WorkflowCommandReceipt, WorkflowCommandType} from "./types";
import {WorkflowStore} from "./store";
import {readExistingReceipt, receiptPath} from "./idempotency";
import {CommandHandler} from "./handlerTypes";
import {finalizeLaneSet, acknowledgeLane, addLane, removeLane, terminateLane, closeLane, cancelWorkflow} from "./laneHandlers";
import {raiseCompliance, acknowledgeCompliance, confirmConditionAndReactivate, markComplianceComplied, returnComplianceForCorrection, confirmComplianceClosed, proposeCounterCondition, decideCounterCondition} from "./complianceHandlers";
import {deployEquipment, reconcileEquipment} from "./equipmentHandlers";
import {finalizeJob} from "./finalizeJobHandler";
import {prepareRedLane} from "./redHandlers";
import {createLegacyWorkflowJob} from "./jobCreationHandler";
import {reopenWorkflowModule} from "./moduleLifecycleHandlers";

const handlers: Readonly<Record<WorkflowCommandType, CommandHandler>> = {
  createLegacyWorkflowJob,
  finalizeLaneSet,
  acknowledgeLane,
  addLane,
  removeLane,
  terminateLane,
  closeLane,
  cancelWorkflow,
  raiseCompliance,
  acknowledgeCompliance,
  confirmConditionAndReactivate,
  markComplianceComplied,
  returnComplianceForCorrection,
  confirmComplianceClosed,
  proposeCounterCondition,
  decideCounterCondition,
  prepareRedLane,
  reopenWorkflowModule,
  finalizeJob,
  deployEquipment,
  reconcileEquipment,
};

export class MaintenanceWorkflowCommandService {
  constructor(private readonly store: WorkflowStore) {}

  async execute(command: WorkflowCommand, context: CommandContext): Promise<WorkflowCommandReceipt> {
    if (command.commandId.trim().length === 0) throw new WorkflowError("invalid-argument", "commandId is required.");
    if (command.aggregateId.trim().length === 0) throw new WorkflowError("invalid-argument", "aggregateId is required.");
    if (!Number.isSafeInteger(command.expectedVersion) || command.expectedVersion < 0) {
      throw new WorkflowError("invalid-argument", "expectedVersion must be a non-negative integer.");
    }
    const handler = handlers[command.commandType];
    if (!handler) throw new WorkflowError("unsupported-workflow-command", `Unsupported command ${command.commandType}.`);
    return this.store.runTransaction(async (tx) => {
      const replay = await readExistingReceipt(tx, command);
      if (replay != null) return replay;
      const handled = await handler({tx, command, context});
      const receipt: WorkflowCommandReceipt = {
        commandId: command.commandId,
        payloadHash: payloadHash(command as unknown as JsonMap),
        resultKey: handled.resultKey,
        aggregateVersion: handled.aggregateVersion,
        result: handled.result,
        appliedAt: iso(context.serverNow),
      };
      tx.create(receiptPath(command.commandId), receipt as unknown as JsonMap);
      return receipt;
    });
  }
}
