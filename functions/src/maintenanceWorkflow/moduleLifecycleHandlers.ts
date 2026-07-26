import {assertExpectedVersion, requireLaneReferenceForWorkflow, requireMutableWorkflow, workflowDocumentPath} from "./documents";
import {mayReopenWorkflowModule} from "./authority";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {executionPath, workflowPath} from "./paths";
import {cleanText, iso, laneKey} from "./utils";

export const reopenWorkflowModule: CommandHandler = async ({tx, command, context}) => {
  if (!mayReopenWorkflowModule(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot reopen workflow modules.");
  }
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const modulePath = workflowDocumentPath(
    "job_modules",
    command.payload.moduleFirestoreId,
    "moduleFirestoreId",
  );
  if (modulePath == null) {
    throw new WorkflowError("invalid-argument", "moduleFirestoreId is required.");
  }
  const module = await tx.get(modulePath);
  if (!module.exists || module.data == null) {
    throw new WorkflowError("not-found", "The workflow module was not found.");
  }
  const executionId = typeof workflow.jobExecutionId === "string" && workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  if (module.data.jobExecutionFirestoreId !== executionId) {
    throw new WorkflowError(
      "failed-precondition",
      "The module belongs to another job execution.",
      {modulePath, executionId, moduleExecutionId: module.data.jobExecutionFirestoreId ?? null},
    );
  }
  if (module.data.isDeleted === true) {
    throw new WorkflowError("failed-precondition", "Deleted module cannot be reopened.");
  }
  const status = String(module.data.status ?? "");
  if (status !== "submitted" && status !== "accepted" && status !== "notApplicable") {
    throw new WorkflowError(
      "failed-precondition",
      "Only submitted, accepted or not-applicable modules may be reopened.",
      {status},
    );
  }
  const key = laneKey(module.data.laneKey, "module.laneKey");
  const lane = await requireLaneReferenceForWorkflow(
    tx,
    module.data.workflowLaneFirestoreId,
    "module.workflowLaneFirestoreId",
    command.aggregateId,
    key,
  );
  if (lane.data.status !== "acknowledged" && lane.data.status !== "closed") {
    throw new WorkflowError(
      "failed-precondition",
      "Module lane must be acknowledged or closed before reopening work.",
      {laneStatus: lane.data.status ?? null},
    );
  }
  const reason = cleanText(command.payload.reason, "reason");
  const execution = await tx.get(executionPath(executionId));
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The original job execution was not found.");
  }
  if (execution.data.isCompleted === true || execution.data.isCancelled === true) {
    throw new WorkflowError("failed-precondition", "Terminal job execution cannot reopen a module.");
  }
  const now = iso(context.serverNow);
  const nextVersion = version + 1;

  // All reads completed. The module and its control-plane lane are reopened
  // atomically, so a closed lane can never hide newly active work.
  if (lane.data.status === "closed") {
    tx.update(lane.path, {
      status: "acknowledged",
      closedByUid: null,
      closedByName: null,
      closedAt: null,
      closeNote: null,
      reopenedByUid: context.actor.uid,
      reopenedByName: context.actor.name,
      reopenedAt: now,
      reopenReason: reason,
      progressRevision: (typeof lane.data.progressRevision === "number" ? lane.data.progressRevision : 0) + 1,
      version: (typeof lane.data.version === "number" ? lane.data.version : 0) + 1,
      updatedAt: now,
    });
  }
  tx.update(modulePath, {
    status: "reopened",
    isOpenForWork: true,
    reopenedByUid: context.actor.uid,
    reopenedByName: context.actor.name,
    reopenedAt: now,
    reopenReason: reason,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    updatedAt: now,
    version: (typeof module.data.version === "number" ? module.data.version : 0) + 1,
  });
  tx.update(workflowPath(command.aggregateId), {
    status: "inProgress",
    version: nextVersion,
    updatedAt: now,
  });
  tx.update(executionPath(executionId), {
    updatedAt: now,
    version: (typeof execution.data.version === "number" ? execution.data.version : 0) + 1,
  });
  tx.set(`audit_logs/workflow_module_reopen_${modulePath.split("/")[1]}_${nextVersion}`, {
    entityType: "jobModule",
    entityId: modulePath.split("/")[1],
    action: "reopen",
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    timestamp: now,
    reason: "workflowModuleReopened",
    reasonNotes: reason,
    summary: "Reopened module and reactivated its governed workflow lane",
    severity: "medium",
    beforeJson: JSON.stringify(module.data),
    afterJson: JSON.stringify({...module.data, status: "reopened", isOpenForWork: true}),
    workflowAggregateId: command.aggregateId,
    laneKey: key,
  }, true);
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "module.reopened",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: key,
    payload: {
      moduleFirestoreId: modulePath.split("/")[1],
      laneReactivated: lane.data.status === "closed",
      reason,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "workflow-module-reopened",
    aggregateVersion: nextVersion,
    result: {
      moduleFirestoreId: modulePath.split("/")[1],
      laneKey: key,
      laneReactivated: lane.data.status === "closed",
    },
  };
};
