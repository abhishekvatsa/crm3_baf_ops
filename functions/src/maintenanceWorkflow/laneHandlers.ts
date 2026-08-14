import {assertLaneAuthority, mayCancelWorkflow, mayFinalizeLaneSet, mayManageLanePopulation} from "./authority";
import {assertCanonicalLaneClosureReady} from "./canonicalClosure";
import {
  equipmentFactsFromProjection,
  equipmentProjectionWrite,
  projectEquipment,
  withoutWorkflowContribution,
  workflowContribution,
} from "./equipmentFacts";
import {deriveWorkflowStatus} from "./aggregate";
import {assertExpectedVersion, activeLanes, openBlockingCompliance, requireMutableWorkflow, requireWorkflow} from "./documents";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {collectLaneProgressEvidence, hasProtectedProgress} from "./laneProgress";
import {maintenanceProjectionForRelease} from "./maintenanceBridge";
import {laneForModuleDiscipline, legacyAgencyForLane} from "./modulePolicy";
import {
  compliancePath,
  equipmentIdentityFromWorkflow,
  equipmentPathForIdentity,
  executionPath,
  lanePath,
  maintenancePath,
  workflowPath,
} from "./paths";
import {JsonMap, LaneDoc, LaneKey} from "./types";
import {cleanText, iso, laneKey, optionalText, plusMinutes, stringArray} from "./utils";
import {WORKFLOW_CLOCKS_MINUTES} from "./policy.generated";

const laneDocs = async (tx: Parameters<CommandHandler>[0]["tx"], workflowId: string): Promise<readonly LaneDoc[]> => {
  const rows = await tx.query<LaneDoc>("job_lanes", [{field: "workflowId", op: "==", value: workflowId}]);
  return rows.map((r) => r.data).filter((x): x is LaneDoc => x != null);
};

const activeLaneProjection = (lanes: readonly LaneDoc[]): readonly LaneDoc[] =>
  lanes.filter((lane) => lane.status !== "removed" && lane.status !== "terminated");

const assignedAgenciesForLanes = (lanes: readonly LaneDoc[]): readonly string[] => {
  const ordered = [...activeLaneProjection(lanes)].sort((a, b) =>
    (typeof a.displayOrder === "number" ? a.displayOrder : 999) -
    (typeof b.displayOrder === "number" ? b.displayOrder : 999),
  );
  return [...new Set(ordered.map((lane) => legacyAgencyForLane(lane.laneKey as LaneKey)))];
};

const laneReferenceId = (path: string): string => path.split("/").at(-1) ?? path;

const openComplianceStatus = (status: unknown): boolean =>
  status !== "confirmedClosed" && status !== "cancelled" && status !== "superseded";

const complianceReferencesLane = (data: JsonMap, laneDocumentPath: string): boolean => {
  const laneId = laneReferenceId(laneDocumentPath);
  return data.gatesLaneFirestoreId === laneDocumentPath ||
    data.linkedLaneFirestoreId === laneId ||
    data.originLaneFirestoreId === laneId ||
    data.targetLaneFirestoreId === laneId;
};

const executionLaneProjection = (args: {
  readonly execution: JsonMap;
  readonly lanes: readonly LaneDoc[];
  readonly now: string;
  readonly actorUid: string;
  readonly actorName: string;
}): JsonMap => {
  const active = activeLaneProjection(args.lanes);
  return {
    assignedAgencies: assignedAgenciesForLanes(active),
    laneSetVersion: (typeof args.execution.laneSetVersion === "number"
      ? args.execution.laneSetVersion
      : 0) + 1,
    laneSetFinalizedAt: active.length === 0
      ? null
      : args.execution.laneSetFinalizedAt ?? args.now,
    laneSetFinalizedByUid: active.length === 0 ? null : args.actorUid,
    laneSetFinalizedByName: active.length === 0 ? null : args.actorName,
    laneMappingReview: active.length === 0,
    updatedAt: args.now,
    version: (typeof args.execution.version === "number" ? args.execution.version : 0) + 1,
  };
};

export const finalizeLaneSet: CommandHandler = async ({tx, command, context}) => {
  if (!mayFinalizeLaneSet(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot finalise lane sets.");
  }
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (workflow.status !== "pendingLaneClassification") {
    throw new WorkflowError("failed-precondition", "Workflow is not pending lane classification.");
  }
  const requested = [...new Set(
    stringArray(command.payload.laneKeys, "laneKeys").map((value) => laneKey(value)),
  )];
  const executionId = typeof workflow.jobExecutionId === "string" &&
      workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const execution = await tx.get(executionPath(executionId));
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The workflow job execution was not found.");
  }
  const moduleRows = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  if (moduleRows.length > 400) {
    throw new WorkflowError(
      "failed-precondition",
      "Lane-set finalisation exceeds the governed transaction size; administrative reconciliation is required.",
      {moduleCount: moduleRows.length},
    );
  }
  const required = new Set<LaneKey>();
  const moduleLaneUpdates: Array<{
    path: string;
    lane: LaneKey;
    expectedLaneId: string;
    version: number;
  }> = [];
  for (const row of moduleRows) {
    if (row.data == null) continue;
    const canonicalLane = laneForModuleDiscipline(row.data.discipline);
    required.add(canonicalLane);
    const expectedLaneId = `${command.aggregateId}_${canonicalLane}_1`;
    if (
      row.data.laneKey !== canonicalLane ||
      row.data.laneActivationGeneration !== 1 ||
      row.data.workflowLaneFirestoreId !== expectedLaneId
    ) {
      moduleLaneUpdates.push({
        path: row.path,
        lane: canonicalLane,
        expectedLaneId,
        version: typeof row.data.version === "number" ? row.data.version : 0,
      });
    }
  }
  const lanes = [...new Set<LaneKey>([...requested, ...required])];
  if (lanes.length === 0) {
    throw new WorkflowError(
      "invalid-argument",
      "At least one lane is required; the assigned module population contains no accountable lane.",
    );
  }
  const existing = await laneDocs(tx, command.aggregateId);
  if (existing.some((lane) => lane.status !== "removed" && lane.status !== "terminated")) {
    throw new WorkflowError("failed-precondition", "An active lane set already exists.");
  }
  const now = iso(context.serverNow);
  const nextVersion = version + 1;

  // All reads completed. The lane set and original execution projection are
  // now established together, and every existing module is attached to the
  // canonical generation-1 lane dictated by its discipline.
  for (let index = 0; index < lanes.length; index += 1) {
    const key = lanes[index];
    tx.create(lanePath(command.aggregateId, key, 1), {
      workflowId: command.aggregateId,
      jobExecutionId: executionId,
      laneKey: key,
      status: "pending",
      activationGeneration: 1,
      version: 1,
      progressRevision: 0,
      displayOrder: index,
      addedDuringExecution: false,
      addedByUid: context.actor.uid,
      addedByName: context.actor.name,
      addedAt: now,
      acknowledgementDueAt: plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
      ),
      nextEscalationAt: plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
      ),
      createdAt: now,
      updatedAt: now,
    });
    const event = eventPlan({
      aggregateId: command.aggregateId,
      eventId: `${command.commandId}_${key}`,
      eventType: "lane.created",
      actor: context.actor,
      at: context.serverNow,
      commandId: command.commandId,
      laneKey: key,
      payload: {requiredByModulePopulation: required.has(key)},
    });
    tx.create(event.path, event.data);
  }
  for (const update of moduleLaneUpdates) {
    tx.update(update.path, {
      laneKey: update.lane,
      laneActivationGeneration: 1,
      workflowLaneFirestoreId: update.expectedLaneId,
      updatedAt: now,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
      version: update.version + 1,
    });
  }
  tx.update(workflowPath(command.aggregateId), {
    status: "assigned",
    version: nextVersion,
    laneSetVersion: (typeof workflow.laneSetVersion === "number"
      ? workflow.laneSetVersion
      : 0) + 1,
    laneSetFinalizedAt: now,
    laneSetFinalizedByUid: context.actor.uid,
    laneSetFinalizedByName: context.actor.name,
    updatedAt: now,
  });
  tx.update(executionPath(executionId), {
    assignedAgencies: lanes.map(legacyAgencyForLane),
    laneSetVersion: (typeof execution.data.laneSetVersion === "number"
      ? execution.data.laneSetVersion
      : 0) + 1,
    laneSetFinalizedAt: now,
    laneSetFinalizedByUid: context.actor.uid,
    laneSetFinalizedByName: context.actor.name,
    laneMappingReview: false,
    updatedAt: now,
    version: (typeof execution.data.version === "number"
      ? execution.data.version
      : 0) + 1,
  });
  return {
    resultKey: "lane-set-finalized",
    aggregateVersion: nextVersion,
    result: {
      laneKeys: lanes,
      requestedLaneKeys: requested,
      mandatoryLaneKeys: [...required],
      reconciledModuleCount: moduleLaneUpdates.length,
    },
  };
};

export const acknowledgeLane: CommandHandler = async ({tx, command, context}) => {
  const key = laneKey(command.payload.laneKey);
  assertLaneAuthority(context.actor, key, "acknowledge");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (workflow.laneSetFinalizedAt == null) throw new WorkflowError("lane-set-not-finalized", "Lane set is not finalised.");
  const lanes = await laneDocs(tx, command.aggregateId);
  const lane = lanes.find((l) => l.laneKey === key && l.status !== "removed" && l.status !== "terminated");
  if (!lane) throw new WorkflowError("not-found", `Active lane ${key} was not found.`);
  if (lane.status === "closed") throw new WorkflowError("failed-precondition", "Closed lane cannot be acknowledged again.");
  const laneId = lanePath(command.aggregateId, key, lane.activationGeneration ?? 1);
  const blocking = await openBlockingCompliance(tx, command.aggregateId);
  if (key === "red") {
    const unfinishedOtherLanes = lanes.filter((candidate) => candidate.laneKey !== "red" && candidate.status !== "closed");
    if (unfinishedOtherLanes.length > 0) {
      throw new WorkflowError("red-lane-not-ready", "All non-RED lanes must close before the RED lane is acknowledged.", {
        openLaneKeys: unfinishedOtherLanes.map((candidate) => candidate.laneKey ?? "unknown"),
      });
    }
    if (workflow.awaitingPreparation === true || workflow.activeRedWork !== true) {
      throw new WorkflowError("red-preparation-incomplete", "RED work has not been released after preparation.");
    }
    if (lane.gatingComplianceRequestId != null) {
      throw new WorkflowError("blocking-compliance-open", "RED lane is still gated by preparation compliance.");
    }
  }
  const projected = lanes.map((l) => l === lane ? {...l, status: "acknowledged" as const} : l);
  tx.update(laneId, {
    status: "acknowledged",
    version: (lane.version ?? 0) + 1,
    acknowledgedByUid: context.actor.uid,
    acknowledgedByName: context.actor.name,
    acknowledgedAt: iso(context.serverNow),
    nextEscalationAt: null,
    updatedAt: iso(context.serverNow),
  });
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {
    status: deriveWorkflowStatus(projected, blocking.length, false, workflow.cancelled === true),
    version: nextVersion,
    updatedAt: iso(context.serverNow),
  });
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "lane.acknowledged", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: key});
  tx.create(event.path, event.data);
  return {resultKey: "lane-acknowledged", aggregateVersion: nextVersion, result: {laneKey: key}};
};

export const addLane: CommandHandler = async ({tx, command, context}) => {
  if (!mayManageLanePopulation(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot add lanes.");
  }
  const key = laneKey(command.payload.laneKey);
  const reason = cleanText(command.payload.reason, "reason");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const lanes = await laneDocs(tx, command.aggregateId);
  const active = lanes.find((lane) =>
    lane.laneKey === key && lane.status !== "removed" && lane.status !== "terminated",
  );
  if (active) throw new WorkflowError("already-exists", `Lane ${key} is already active.`);
  const executionId = typeof workflow.jobExecutionId === "string" && workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const execution = await tx.get(executionPath(executionId));
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The workflow job execution was not found.");
  }
  const generation = Math.max(
    0,
    ...lanes.filter((lane) => lane.laneKey === key).map((lane) => lane.activationGeneration ?? 1),
  ) + 1;
  const now = iso(context.serverNow);
  const path = lanePath(command.aggregateId, key, generation);
  const newLane: LaneDoc = {
    workflowId: command.aggregateId,
    jobExecutionId: executionId,
    laneKey: key,
    status: "pending",
    activationGeneration: generation,
    version: 1,
    progressRevision: 0,
    displayOrder: Math.max(
      -1,
      ...lanes.map((lane) => typeof lane.displayOrder === "number" ? lane.displayOrder : -1),
    ) + 1,
    addedDuringExecution: true,
    addReason: reason,
    addedByUid: context.actor.uid,
    addedByName: context.actor.name,
    addedAt: now,
    acknowledgementDueAt: plusMinutes(
      context.serverNow,
      WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
    ),
    nextEscalationAt: plusMinutes(
      context.serverNow,
      WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
    ),
    createdAt: now,
    updatedAt: now,
  };
  const projected = [...lanes, newLane];
  const nextVersion = version + 1;

  // All reads completed. Lane topology and the original execution assignment
  // projection advance together.
  tx.create(path, newLane);
  tx.update(workflowPath(command.aggregateId), {
    status: "partiallyAcknowledged",
    version: nextVersion,
    laneSetVersion: (typeof workflow.laneSetVersion === "number" ? workflow.laneSetVersion : 0) + 1,
    laneSetFinalizedAt: workflow.laneSetFinalizedAt ?? now,
    laneSetFinalizedByUid: context.actor.uid,
    laneSetFinalizedByName: context.actor.name,
    updatedAt: now,
  });
  tx.update(executionPath(executionId), executionLaneProjection({
    execution: execution.data,
    lanes: projected,
    now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }));
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "lane.added",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: key,
    payload: {reason, generation},
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "lane-added",
    aggregateVersion: nextVersion,
    result: {laneKey: key, generation},
  };
};

export const removeLane: CommandHandler = async ({tx, command, context}) => {
  if (!mayManageLanePopulation(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot remove lanes.");
  }
  const key = laneKey(command.payload.laneKey);
  const reason = cleanText(command.payload.reason, "reason");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const lanes = await laneDocs(tx, command.aggregateId);
  const lane = lanes.find((candidate) =>
    candidate.laneKey === key && candidate.status !== "removed" && candidate.status !== "terminated",
  );
  if (!lane) throw new WorkflowError("not-found", `Active lane ${key} was not found.`);
  const laneDocumentPath = lanePath(
    command.aggregateId,
    key,
    lane.activationGeneration ?? 1,
  );
  const laneId = laneReferenceId(laneDocumentPath);
  const executionId = typeof workflow.jobExecutionId === "string" && workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const evidence = await collectLaneProgressEvidence(
    tx,
    executionId,
    key,
    lane.status === "acknowledged",
  );
  if (hasProtectedProgress(evidence)) {
    throw new WorkflowError(
      "lane-progress-open",
      "Lane has protected progress and must be terminated instead.",
    );
  }
  const moduleRows = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "workflowLaneFirestoreId", op: "==", value: laneId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  if (moduleRows.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "A lane with active modules cannot be removed.",
      {laneKey: key, moduleCount: moduleRows.length},
    );
  }
  const complianceRows = await tx.query("compliance_requests", [
    {field: "linkedWorkflowId", op: "==", value: command.aggregateId},
  ]);
  const activeCompliance = complianceRows.filter((row) =>
    row.data != null && openComplianceStatus(row.data.status) &&
    complianceReferencesLane(row.data, laneDocumentPath),
  );
  if (activeCompliance.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "A lane referenced by open compliance cannot be removed.",
      {laneKey: key, complianceCount: activeCompliance.length},
    );
  }
  const execution = await tx.get(executionPath(executionId));
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The workflow job execution was not found.");
  }
  const now = iso(context.serverNow);
  const projected = lanes.map((candidate) =>
    candidate === lane ? {...candidate, status: "removed" as const} : candidate,
  );
  const activeAfter = activeLaneProjection(projected);
  const nextVersion = version + 1;

  // All reads completed. The lane and original execution projection are
  // changed in the same transaction.
  tx.update(laneDocumentPath, {
    status: "removed",
    nextEscalationAt: null,
    removedByUid: context.actor.uid,
    removedByName: context.actor.name,
    removedAt: now,
    removeReason: reason,
    version: (lane.version ?? 0) + 1,
    updatedAt: now,
  });
  tx.update(workflowPath(command.aggregateId), {
    status: activeAfter.length === 0
      ? "pendingLaneClassification"
      : deriveWorkflowStatus(projected, 0, false, false),
    version: nextVersion,
    laneSetVersion: (typeof workflow.laneSetVersion === "number" ? workflow.laneSetVersion : 0) + 1,
    laneSetFinalizedAt: activeAfter.length === 0 ? null : workflow.laneSetFinalizedAt ?? now,
    laneSetFinalizedByUid: activeAfter.length === 0 ? null : context.actor.uid,
    laneSetFinalizedByName: activeAfter.length === 0 ? null : context.actor.name,
    updatedAt: now,
  });
  tx.update(executionPath(executionId), executionLaneProjection({
    execution: execution.data,
    lanes: projected,
    now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }));
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "lane.removed",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: key,
    payload: {reason, acknowledged: evidence.acknowledged},
  });
  tx.create(event.path, event.data);
  return {
    resultKey: activeAfter.length === 0
      ? "workflow-requires-reclassification"
      : "lane-removed",
    aggregateVersion: nextVersion,
    result: {laneKey: key},
  };
};

export const terminateLane: CommandHandler = async ({tx, command, context}) => {
  if (!mayManageLanePopulation(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot terminate lanes.");
  }
  const key = laneKey(command.payload.laneKey);
  const reason = cleanText(command.payload.reason, "reason");
  const replacement = command.payload.replacementLaneKey == null
    ? null
    : laneKey(command.payload.replacementLaneKey, "replacementLaneKey");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const lanes = await laneDocs(tx, command.aggregateId);
  const lane = lanes.find((candidate) =>
    candidate.laneKey === key && candidate.status !== "removed" && candidate.status !== "terminated",
  );
  if (!lane) throw new WorkflowError("not-found", `Active lane ${key} was not found.`);
  const oldLanePath = lanePath(command.aggregateId, key, lane.activationGeneration ?? 1);
  const oldLaneId = laneReferenceId(oldLanePath);
  const activeAfterRemoval = lanes.filter((candidate) =>
    candidate !== lane && candidate.status !== "removed" && candidate.status !== "terminated",
  );
  if (activeAfterRemoval.length === 0 && replacement == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Final progressed lane requires a replacement lane or workflow cancellation.",
    );
  }
  if (replacement != null && activeAfterRemoval.some((candidate) => candidate.laneKey === replacement)) {
    throw new WorkflowError("already-exists", "Replacement lane is already active.");
  }
  const executionId = typeof workflow.jobExecutionId === "string" && workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const moduleRows = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "workflowLaneFirestoreId", op: "==", value: oldLaneId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  if (moduleRows.length > 0 && replacement !== key) {
    throw new WorkflowError(
      "failed-precondition",
      "A lane with active modules may only be replaced by a new generation of the same canonical lane.",
      {laneKey: key, replacementLaneKey: replacement, moduleCount: moduleRows.length},
    );
  }
  if (moduleRows.length > 400) {
    throw new WorkflowError(
      "failed-precondition",
      "Lane replacement exceeds the governed transaction size.",
      {moduleCount: moduleRows.length},
    );
  }
  const complianceRows = await tx.query("compliance_requests", [
    {field: "linkedWorkflowId", op: "==", value: command.aggregateId},
  ]);
  const activeCompliance = complianceRows.filter((row) =>
    row.data != null && openComplianceStatus(row.data.status) &&
    complianceReferencesLane(row.data, oldLanePath),
  );
  if (activeCompliance.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "A lane referenced by open compliance cannot be terminated.",
      {laneKey: key, complianceCount: activeCompliance.length},
    );
  }
  const execution = await tx.get(executionPath(executionId));
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The workflow job execution was not found.");
  }
  const generation = replacement == null
    ? null
    : Math.max(
      0,
      ...lanes.filter((candidate) => candidate.laneKey === replacement)
        .map((candidate) => candidate.activationGeneration ?? 1),
    ) + 1;
  const now = iso(context.serverNow);
  const replacementPath = replacement == null || generation == null
    ? null
    : lanePath(command.aggregateId, replacement, generation);
  const replacementLane: LaneDoc | null = replacement == null || generation == null
    ? null
    : {
      workflowId: command.aggregateId,
      jobExecutionId: executionId,
      laneKey: replacement,
      status: "pending",
      activationGeneration: generation,
      version: 1,
      progressRevision: 0,
      displayOrder: typeof lane.displayOrder === "number" ? lane.displayOrder : activeAfterRemoval.length,
      addedDuringExecution: true,
      addReason: `Replacement for terminated ${key}: ${reason}`,
      addedByUid: context.actor.uid,
      addedByName: context.actor.name,
      addedAt: now,
      acknowledgementDueAt: plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
      ),
      nextEscalationAt: plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement,
      ),
      createdAt: now,
      updatedAt: now,
    };
  const projected = lanes.map((candidate) =>
    candidate === lane ? {...candidate, status: "terminated" as const} : candidate,
  );
  if (replacementLane != null) projected.push(replacementLane);
  const nextVersion = version + 1;

  // All reads completed. Termination, optional same-lane generation
  // replacement, module identity migration and execution projection are atomic.
  tx.update(oldLanePath, {
    status: "terminated",
    nextEscalationAt: null,
    terminatedByUid: context.actor.uid,
    terminatedByName: context.actor.name,
    terminatedAt: now,
    terminateReason: reason,
    version: (lane.version ?? 0) + 1,
    updatedAt: now,
  });
  if (replacementLane != null && replacementPath != null && generation != null) {
    tx.create(replacementPath, replacementLane);
    const replacementId = laneReferenceId(replacementPath);
    for (const row of moduleRows) {
      const module = row.data ?? {};
      tx.update(row.path, {
        laneKey: replacement,
        laneActivationGeneration: generation,
        workflowLaneFirestoreId: replacementId,
        updatedAt: now,
        updatedByUid: context.actor.uid,
        updatedByName: context.actor.name,
        version: (typeof module.version === "number" ? module.version : 0) + 1,
      });
    }
  }
  tx.update(workflowPath(command.aggregateId), {
    status: replacement == null ? "inProgress" : "partiallyAcknowledged",
    version: nextVersion,
    laneSetVersion: (typeof workflow.laneSetVersion === "number" ? workflow.laneSetVersion : 0) + 1,
    laneSetFinalizedAt: workflow.laneSetFinalizedAt ?? now,
    laneSetFinalizedByUid: context.actor.uid,
    laneSetFinalizedByName: context.actor.name,
    updatedAt: now,
  });
  tx.update(executionPath(executionId), executionLaneProjection({
    execution: execution.data,
    lanes: projected,
    now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }));
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "lane.terminated",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: key,
    payload: {
      reason,
      replacementLaneKey: replacement,
      replacementGeneration: generation,
      remappedModuleCount: replacement === key ? moduleRows.length : 0,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "lane-terminated",
    aggregateVersion: nextVersion,
    result: {
      laneKey: key,
      replacementLaneKey: replacement,
      replacementGeneration: generation,
      remappedModuleCount: replacement === key ? moduleRows.length : 0,
    },
  };
};

export const closeLane: CommandHandler = async ({tx, command, context}) => {
  const key = laneKey(command.payload.laneKey);
  assertLaneAuthority(context.actor, key, "close");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const lanes = await laneDocs(tx, command.aggregateId);
  const lane = lanes.find((l) => l.laneKey === key && l.status !== "removed" && l.status !== "terminated");
  if (!lane) throw new WorkflowError("not-found", `Active lane ${key} was not found.`);
  if (lane.status !== "acknowledged") throw new WorkflowError("lane-ack-required", "Lane must be acknowledged before closure.");
  const laneDocumentPath = lanePath(command.aggregateId, key, lane.activationGeneration ?? 1);
  const laneReadiness = await assertCanonicalLaneClosureReady({
    tx,
    executionId: workflow.jobExecutionId ?? command.aggregateId,
    workflowLaneFirestoreId: laneDocumentPath.split("/").at(-1) ?? laneDocumentPath,
  });
  const gates = await tx.query("compliance_requests", [
    {field: "gatesLaneFirestoreId", op: "==", value: laneDocumentPath},
  ]);
  const openGate = gates.some((g) => g.data?.status !== "confirmedClosed" && g.data?.status !== "cancelled" && g.data?.status !== "superseded");
  if (openGate) throw new WorkflowError("blocking-compliance-open", "Lane has an unresolved blocking compliance request.");
  const projected = lanes.map((l) => l === lane ? {...l, status: "closed" as const} : l);
  const blocking = await openBlockingCompliance(tx, command.aggregateId);
  tx.update(laneDocumentPath, {
    status: "closed",
    nextEscalationAt: null,
    closedByUid: context.actor.uid,
    closedByName: context.actor.name,
    closedAt: iso(context.serverNow),
    closeNote: optionalText(command.payload.note),
    version: (lane.version ?? 0) + 1,
    updatedAt: iso(context.serverNow),
  });
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {status: deriveWorkflowStatus(projected, blocking.length, false, false), version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "lane.closed", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: key, payload: {note: optionalText(command.payload.note), validatedModuleCount: laneReadiness.moduleCount}});
  tx.create(event.path, event.data);
  return {resultKey: "lane-closed", aggregateVersion: nextVersion, result: {laneKey: key, validatedModuleCount: laneReadiness.moduleCount}};
};

export const cancelWorkflow: CommandHandler = async ({tx, command, context}) => {
  if (!mayCancelWorkflow(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot cancel workflows.");
  }
  const reason = cleanText(command.payload.reason, "reason");
  const workflow = await requireWorkflow(tx, command.aggregateId);
  if (workflow.status === "completed") {
    throw new WorkflowError("failed-precondition", "Completed workflow cannot be cancelled.");
  }
  if (workflow.status === "cancelled" || workflow.cancelled === true) {
    return {
      resultKey: "workflow-already-cancelled",
      aggregateVersion: typeof workflow.version === "number" ? workflow.version : 0,
      result: {
        alreadyCancelled: true,
        reason: typeof workflow.cancellationReason === "string"
          ? workflow.cancellationReason
          : reason,
      },
    };
  }
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const executionId = typeof workflow.jobExecutionId === "string" && workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const executionRef = executionPath(executionId);
  const execution = await tx.get(executionRef);
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "The workflow job execution was not found.");
  }
  const lanes = await tx.query("job_lanes", [
    {field: "workflowId", op: "==", value: command.aggregateId},
  ]);
  const compliance = await tx.query("compliance_requests", [
    {field: "linkedWorkflowId", op: "==", value: command.aggregateId},
  ]);
  const modules = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  const linkedMaintenanceIds = [...new Set(
    compliance
      .map((row) => row.data?.linkedMaintenanceFirestoreId)
      .filter((value): value is string => typeof value === "string" && value.length > 0),
  )];
  const linkedMaintenance = [];
  for (const maintenanceId of linkedMaintenanceIds) {
    linkedMaintenance.push(await tx.get(maintenancePath(maintenanceId)));
  }
  if (lanes.length + compliance.length + modules.length + linkedMaintenance.length > 420) {
    throw new WorkflowError(
      "failed-precondition",
      "Workflow cancellation exceeds the governed transaction size; administrative reconciliation is required.",
      {
        laneCount: lanes.length,
        complianceCount: compliance.length,
        moduleCount: modules.length,
        linkedMaintenanceCount: linkedMaintenance.length,
      },
    );
  }
  const equipmentIdentity = equipmentIdentityFromWorkflow(workflow);
  const {assetTypeKey, assetNumber} = equipmentIdentity;
  const equipmentId = equipmentPathForIdentity(equipmentIdentity);
  const equipment = await tx.get(equipmentId);
  const remainingFacts = withoutWorkflowContribution(
    equipmentFactsFromProjection(equipment.data, equipmentIdentity),
    workflowContribution(workflow),
  );
  const projection = projectEquipment(remainingFacts, false);
  const now = iso(context.serverNow);
  const nextVersion = version + 1;
  const executionVersion = typeof execution.data.version === "number" ? execution.data.version : 0;

  // All reads completed. Cancellation now projects atomically across the
  // workflow control plane and the original planned-maintenance data plane.
  tx.update(workflowPath(command.aggregateId), {
    status: "cancelled",
    cancelled: true,
    activeRedWork: false,
    awaitingPreparation: false,
    cancelledByUid: context.actor.uid,
    cancelledByName: context.actor.name,
    cancelledAt: now,
    cancellationReason: reason,
    version: nextVersion,
    updatedAt: now,
  });
  for (const row of lanes) {
    const lane = row.data ?? {};
    if (lane.status === "removed" || lane.status === "terminated") continue;
    tx.update(row.path, {
      status: "terminated",
      nextEscalationAt: null,
      terminatedByUid: context.actor.uid,
      terminatedByName: context.actor.name,
      terminatedAt: now,
      terminationReason: `Workflow cancelled: ${reason}`,
      version: (typeof lane.version === "number" ? lane.version : 0) + 1,
      updatedAt: now,
    });
  }
  for (const row of compliance) {
    const request = row.data ?? {};
    if (request.status === "confirmedClosed" || request.status === "cancelled" || request.status === "superseded") {
      continue;
    }
    tx.update(row.path, {
      status: "cancelled",
      nextEscalationAt: null,
      cancelledByUid: context.actor.uid,
      cancelledByName: context.actor.name,
      cancelledAt: now,
      cancellationReason: reason,
      version: (typeof request.version === "number" ? request.version : 0) + 1,
      updatedAt: now,
    });
  }
  for (const row of linkedMaintenance) {
    const maintenance = row.data;
    if (maintenance == null || maintenance.workflowAggregateId !== command.aggregateId) continue;
    tx.update(row.path, maintenanceProjectionForRelease({
      maintenance,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
      reason: `Workflow cancelled: ${reason}`,
    }));
  }
  for (const row of modules) {
    const module = row.data ?? {};
    tx.update(row.path, {
      isDeleted: true,
      isOpenForWork: false,
      deletedAt: now,
      deletedByUid: context.actor.uid,
      deletedByName: context.actor.name,
      deleteReason: `Workflow cancelled: ${reason}`,
      updatedAt: now,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
      version: (typeof module.version === "number" ? module.version : 0) + 1,
    });
  }
  const executionUpdate = {
    isCancelled: true,
    cancelledAt: now,
    cancelledByUid: context.actor.uid,
    cancelledByName: context.actor.name,
    cancellationReason: reason,
    assignedAgencies: [],
    updatedAt: now,
    version: executionVersion + 1,
  };
  tx.update(executionRef, executionUpdate);
  tx.set(equipmentId, equipmentProjectionWrite(equipment.data, remainingFacts, projection, {
    assetTypeKey,
    assetNumber,
    assetClassId: equipmentIdentity.assetClassId,
    assetInstanceId: equipmentIdentity.assetInstanceId,
    trigger: `cancel:${command.aggregateId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), true);
  tx.set(`audit_logs/workflow_cancel_${command.aggregateId}_${nextVersion}`, {
    entityType: "execution",
    entityId: executionId,
    action: "cancel",
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    timestamp: now,
    reason: "workflowCancelled",
    reasonNotes: reason,
    summary: "Planned job and maintenance workflow cancelled through unified authority",
    severity: "high",
    beforeJson: JSON.stringify(execution.data),
    afterJson: JSON.stringify({...execution.data, ...executionUpdate}),
    workflowAggregateId: command.aggregateId,
  }, true);
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "workflow.cancelled",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    payload: {
      reason,
      terminatedLaneCount: lanes.filter((row) => row.data?.status !== "removed" && row.data?.status !== "terminated").length,
      cancelledComplianceCount: compliance.filter((row) => !["confirmedClosed", "cancelled", "superseded"].includes(String(row.data?.status))).length,
      releasedMaintenanceCount: linkedMaintenance.filter((row) => row.data?.workflowAggregateId === command.aggregateId).length,
      cancelledModuleCount: modules.length,
      equipmentState: projection.state,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "workflow-cancelled",
    aggregateVersion: nextVersion,
    result: {
      reason,
      cancelledModuleCount: modules.length,
      equipmentState: projection.state,
    },
  };
};
