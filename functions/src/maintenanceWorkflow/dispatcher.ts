import {
  assertWorkflowAuthorityScope,
  resolveFreshWorkflowAuthorityScope,
} from "./commandAuthority";
import {payloadFingerprint, iso} from "./utils";
import {WorkflowError} from "./errors";
import {
  Actor,
  CommandContext,
  CommandInvocationContext,
  JsonMap,
  RoleKey,
  StoredWorkflowCommandReceipt,
  WorkflowCommand,
  WorkflowCommandReceipt,
  WorkflowCommandType,
} from "./types";
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
import {canonicalApprovedUserAuthority} from "../userAuthority";
import {
  createMaintenanceTicket,
  acknowledgeMaintenanceTicket,
  correctMaintenanceTicket,
  verifyMaintenanceTicketAudit,
} from "./ticketHandlers";

const handlers: Readonly<Record<WorkflowCommandType, CommandHandler>> = {
  createLegacyWorkflowJob,
  createMaintenanceTicket,
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
  acknowledgeMaintenanceTicket,
  correctMaintenanceTicket,
};

export class MaintenanceWorkflowCommandService {
  constructor(private readonly store: WorkflowStore) {}

  async execute(
    command: WorkflowCommand,
    context: CommandInvocationContext,
  ): Promise<WorkflowCommandReceipt> {
    if (command.commandId.trim().length === 0) throw new WorkflowError("invalid-argument", "commandId is required.");
    if (command.aggregateId.trim().length === 0) throw new WorkflowError("invalid-argument", "aggregateId is required.");
    if (!Number.isSafeInteger(command.expectedVersion) || command.expectedVersion < 0) {
      throw new WorkflowError("invalid-argument", "expectedVersion must be a non-negative integer.");
    }
    const handler = handlers[command.commandType];
    if (!handler) throw new WorkflowError("unsupported-workflow-command", `Unsupported command ${command.commandType}.`);
    return this.store.runTransaction(async (tx) => {
      const actorSnapshot = await tx.get(`users/${context.actor.uid}`);
      if (!actorSnapshot.exists || actorSnapshot.data == null) {
        throw new WorkflowError(
          "permission-denied",
          "Approved user record was not found.",
          {reasonCode: "workflow-actor-authority-missing"},
        );
      }
      const authority = canonicalApprovedUserAuthority(actorSnapshot.data);
      if (authority == null) {
        throw new WorkflowError(
          "permission-denied",
          "User approval or role data is malformed or unsupported.",
          {reasonCode: "workflow-actor-authority-invalid"},
        );
      }
      const storedName = typeof actorSnapshot.data.name === "string" ?
        actorSnapshot.data.name.trim() :
        "";
      const actor: Actor = {
        uid: context.actor.uid,
        name: storedName.length > 0 ? storedName : context.actor.name,
        roles: new Set<RoleKey>([...authority.roles] as RoleKey[]),
      };
      const transactionContext: CommandContext = {
        actor,
        serverNow: context.serverNow,
      };

      const replay = await readExistingReceipt(tx, command, actor);
      if (replay != null) {
        await verifyMaintenanceTicketAudit({tx, command, actor, receipt: replay});
        return replay;
      }
      const authorityScope = await resolveFreshWorkflowAuthorityScope(
        tx,
        command,
      );
      assertWorkflowAuthorityScope(actor, authorityScope);
      const handled = await handler({
        tx,
        command,
        context: transactionContext,
      });
      const receipt: WorkflowCommandReceipt = {
        commandId: command.commandId,
        resultKey: handled.resultKey,
        aggregateVersion: handled.aggregateVersion,
        result: handled.result,
        appliedAt: iso(transactionContext.serverNow),
      };
      const storedReceipt: StoredWorkflowCommandReceipt = {
        receiptSchemaVersion: 2,
        commandId: command.commandId,
        commandType: command.commandType,
        aggregateId: command.aggregateId,
        actorUid: actor.uid,
        authorityScope,
        payloadFingerprint: payloadFingerprint(
          command as unknown as JsonMap,
        ),
        resultKey: receipt.resultKey,
        aggregateVersion: receipt.aggregateVersion,
        result: receipt.result,
        appliedAt: receipt.appliedAt,
      };
      tx.create(
        receiptPath(command.commandId),
        storedReceipt as unknown as JsonMap,
      );
      return receipt;
    });
  }
}
