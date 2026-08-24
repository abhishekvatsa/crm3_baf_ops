import {WorkflowError} from "./errors";
import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {DocSnapshot} from "./store";
import {
  hasCompleteTicketLaneFields,
  ticketLanePlan,
  ticketLaneProjection,
} from "./ticketLanePlan";
import {JsonMap} from "./types";
import {iso} from "./utils";

const text = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const cleaned = value.trim();
  return cleaned.length === 0 ? null : cleaned;
};

const number = (value: unknown): number | null =>
  typeof value === "number" && Number.isFinite(value) ? value : null;

export const maintenanceVersion = (data: JsonMap | null): number =>
  data != null && typeof data.version === "number" ? data.version : 0;

export const assertMaintenanceBoundToCompliance = (args: {
  readonly maintenance: DocSnapshot;
  readonly workflowId: string;
  readonly complianceId: string;
}): JsonMap => {
  const {maintenance, workflowId, complianceId} = args;
  if (!maintenance.exists || maintenance.data == null) {
    throw new WorkflowError("not-found", "Linked maintenance item was not found.", {
      maintenancePath: maintenance.path,
    });
  }
  const data = maintenance.data;
  const boundWorkflowId = text(data.workflowAggregateId);
  const boundComplianceId = text(data.workflowComplianceId);
  if (boundWorkflowId !== workflowId || boundComplianceId !== complianceId) {
    throw new WorkflowError(
      "failed-precondition",
      "Linked maintenance work is not bound to this workflow compliance request.",
      {
        maintenancePath: maintenance.path,
        workflowId,
        complianceId,
        boundWorkflowId,
        boundComplianceId,
      },
    );
  }
  if (data.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Deleted maintenance work cannot continue through workflow compliance.",
      {maintenancePath: maintenance.path},
    );
  }
  return data;
};

export const assertMaintenanceCanBind = (args: {
  readonly maintenance: DocSnapshot;
  readonly workflowId: string;
  readonly complianceId: string;
  readonly assetTypeKey: string;
  readonly assetNumber: number;
}): JsonMap => {
  const {maintenance, workflowId, complianceId, assetTypeKey, assetNumber} = args;
  if (!maintenance.exists || maintenance.data == null) {
    throw new WorkflowError("not-found", "Linked maintenance item was not found.", {
      maintenancePath: maintenance.path,
    });
  }
  const data = maintenance.data;
  if (data.isDeleted === true) {
    throw new WorkflowError("failed-precondition", "Deleted maintenance work cannot be linked to compliance.");
  }
  if (data.isResolved === true || data.status === "resolved") {
    throw new WorkflowError("failed-precondition", "Resolved maintenance work cannot be newly linked to compliance.");
  }
  if (data.assetType !== assetTypeKey || number(data.assetNumber) !== assetNumber) {
    throw new WorkflowError(
      "failed-precondition",
      "Linked maintenance work belongs to another asset.",
      {
        expectedAssetTypeKey: assetTypeKey,
        expectedAssetNumber: assetNumber,
        actualAssetTypeKey: data.assetType ?? null,
        actualAssetNumber: data.assetNumber ?? null,
      },
    );
  }
  const boundWorkflowId = text(data.workflowAggregateId);
  const boundComplianceId = text(data.workflowComplianceId);
  const state = text(data.workflowQueueState) ?? "independent";
  const released = state === "released" || state === "independent";
  if (!released && (boundWorkflowId !== workflowId || boundComplianceId !== complianceId)) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance work is already controlled by another active workflow compliance request.",
      {boundWorkflowId, boundComplianceId, state},
    );
  }
  return data;
};

const commonProjection = (args: {
  readonly maintenance: JsonMap;
  readonly workflowId: string;
  readonly complianceId: string;
  readonly originLaneKey: string;
  readonly targetLaneKey: string;
  readonly conditionTypeKey: string;
  readonly conditionRef: string | null;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
  readonly queueState: string;
  readonly deferred: boolean;
}): JsonMap => ({
  workflowDeferred: args.deferred,
  workflowQueueState: args.queueState,
  workflowAggregateId: args.workflowId,
  workflowComplianceId: args.complianceId,
  workflowOriginLaneKey: args.originLaneKey,
  workflowTargetLaneKey: args.targetLaneKey,
  workflowConditionTypeKey: args.conditionTypeKey,
  workflowConditionRef: args.conditionRef,
  workflowUpdatedAt: iso(args.at),
  updatedAt: iso(args.at),
  version: maintenanceVersion(args.maintenance) + 1,
});

export const maintenanceProjectionForRaise = (args: {
  readonly maintenance: JsonMap;
  readonly workflowId: string;
  readonly complianceId: string;
  readonly originLaneKey: string;
  readonly targetLaneKey: string;
  readonly conditionTypeKey: string;
  readonly conditionRef: string | null;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
  readonly forceDeferred?: boolean;
}): JsonMap => {
  const deferred = args.forceDeferred ?? args.conditionTypeKey !== "manual";
  return {
    ...commonProjection({
      ...args,
      queueState: deferred ? "deferred" : "actionable",
      deferred,
    }),
    workflowDeferredAt: deferred ? iso(args.at) : null,
    workflowDeferredByUid: deferred ? args.actorUid : null,
    workflowDeferredByName: deferred ? args.actorName : null,
    workflowReactivatedAt: deferred ? null : iso(args.at),
    workflowReactivatedByUid: deferred ? null : args.actorUid,
    workflowReactivatedByName: deferred ? null : args.actorName,
    workflowReleasedAt: null,
    workflowReleasedByUid: null,
    workflowReleasedByName: null,
    workflowCorrectionReason: null,
  };
};

export const maintenanceProjectionForActionable = (args: {
  readonly maintenance: JsonMap;
  readonly targetLaneKey: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
}): JsonMap => ({
  workflowDeferred: false,
  workflowQueueState: "actionable",
  workflowTargetLaneKey: args.targetLaneKey,
  workflowReactivatedAt: iso(args.at),
  workflowReactivatedByUid: args.actorUid,
  workflowReactivatedByName: args.actorName,
  workflowCorrectionReason: null,
  workflowUpdatedAt: iso(args.at),
  updatedAt: iso(args.at),
  version: maintenanceVersion(args.maintenance) + 1,
});

export const maintenanceProjectionForAwaitingConfirmation = (args: {
  readonly maintenance: JsonMap;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
}): JsonMap => ({
  workflowDeferred: false,
  workflowQueueState: "awaitingConfirmation",
  workflowReactivatedAt: args.maintenance.workflowReactivatedAt ?? iso(args.at),
  workflowReactivatedByUid: args.maintenance.workflowReactivatedByUid ?? args.actorUid,
  workflowReactivatedByName: args.maintenance.workflowReactivatedByName ?? args.actorName,
  workflowCorrectionReason: null,
  workflowUpdatedAt: iso(args.at),
  updatedAt: iso(args.at),
  version: maintenanceVersion(args.maintenance) + 1,
});

const maintenanceHistoryError = (field: string): never => {
  throw new WorkflowError(
    "failed-precondition",
    "Saved maintenance resolution history needs repair before workflow correction.",
    {reasonCode: "maintenance-resolution-history-invalid", field},
  );
};

const persistedInstant = (value: unknown, field: string): string => {
  let date: Date | null = null;
  if (value instanceof Date) {
    date = value;
  } else if (typeof value === "string" && value.trim().length > 0) {
    date = new Date(value);
  } else if (
    value != null &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof (value as {toDate?: unknown}).toDate === "function"
  ) {
    try {
      const converted = (value as {toDate: () => unknown}).toDate();
      if (converted instanceof Date) date = converted;
    } catch (_) {
      date = null;
    }
  }
  if (date == null || Number.isNaN(date.getTime())) {
    return maintenanceHistoryError(field);
  }
  return date.toISOString();
};

const optionalHistoryText = (value: unknown, field: string): void => {
  if (value != null && typeof value !== "string") maintenanceHistoryError(field);
};

const historyTeams = (value: unknown, field: string): string[] => {
  if (value == null) return [];
  if (
    !Array.isArray(value) ||
    value.some((item) => typeof item !== "string" || item.trim().length === 0)
  ) {
    return maintenanceHistoryError(field);
  }
  return [...value] as string[];
};

const actionPayloadText = (
  value: unknown,
  field: string,
  allowMissing: boolean,
): string => {
  try {
    return readComponentActionPayload(value, {field, allowMissing}).text;
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      return maintenanceHistoryError(error.field);
    }
    throw error;
  }
};

type ResolutionHistoryReopenEvidence = {
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
  readonly reason: string | null;
  readonly byWorkflow: boolean;
};

const readResolutionHistory = (value: unknown): JsonMap[] => {
  if (value == null) return [];
  if (typeof value !== "string" || value.trim().length === 0) {
    return maintenanceHistoryError("resolutionHistoryJson");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch (_) {
    return maintenanceHistoryError("resolutionHistoryJson");
  }
  if (!Array.isArray(parsed)) {
    return maintenanceHistoryError("resolutionHistoryJson");
  }

  return parsed.map((value, index) => {
    const field = `resolutionHistoryJson[${index}]`;
    if (value == null || typeof value !== "object" || Array.isArray(value)) {
      return maintenanceHistoryError(field);
    }
    const row = value as JsonMap;
    const resolvedAt = persistedInstant(row.resolvedAt, `${field}.resolvedAt`);
    optionalHistoryText(row.resolvedByUid, `${field}.resolvedByUid`);
    optionalHistoryText(row.resolvedByName, `${field}.resolvedByName`);
    optionalHistoryText(row.remarks, `${field}.remarks`);
    optionalHistoryText(row.reopenedByUid, `${field}.reopenedByUid`);
    optionalHistoryText(row.reopenedByName, `${field}.reopenedByName`);
    optionalHistoryText(row.reopenReason, `${field}.reopenReason`);
    if (row.reopenedByWorkflow != null &&
        typeof row.reopenedByWorkflow !== "boolean") {
      return maintenanceHistoryError(`${field}.reopenedByWorkflow`);
    }
    const hasReopeningEvidence = row.reopenedByUid != null ||
      row.reopenedByName != null || row.reopenedAt != null ||
      row.reopenReason != null;
    if (hasReopeningEvidence &&
        (typeof row.reopenedByUid !== "string" ||
          row.reopenedByUid.trim().length === 0 ||
          typeof row.reopenedByName !== "string" ||
          row.reopenedByName.trim().length === 0 ||
          row.reopenedAt == null)) {
      return maintenanceHistoryError(`${field}.reopenedAt`);
    }
    if (row.reopenedAt != null) {
      const reopenedAt = persistedInstant(
        row.reopenedAt,
        `${field}.reopenedAt`,
      );
      if (new Date(reopenedAt).getTime() < new Date(resolvedAt).getTime()) {
        return maintenanceHistoryError(`${field}.reopenedAt`);
      }
    }
    if (
      row.downtimeHours != null &&
      (typeof row.downtimeHours !== "number" ||
        !Number.isFinite(row.downtimeHours))
    ) {
      return maintenanceHistoryError(`${field}.downtimeHours`);
    }
    historyTeams(row.teamsInvolved, `${field}.teamsInvolved`);
    actionPayloadText(
      row.actionsJson,
      `${field}.actionsJson`,
      !Object.prototype.hasOwnProperty.call(row, "actionsJson"),
    );
    return row;
  });
};

export const maintenanceResolutionHistoryWithCurrentClosure = (
  maintenance: JsonMap,
  reopening?: ResolutionHistoryReopenEvidence,
): string => {
  const history = readResolutionHistory(maintenance.resolutionHistoryJson);
  if (maintenance.isResolved === true) {
    if (
      maintenance.downtimeHours != null &&
      (typeof maintenance.downtimeHours !== "number" ||
        !Number.isFinite(maintenance.downtimeHours))
    ) {
      return maintenanceHistoryError("downtimeHours");
    }
    optionalHistoryText(maintenance.closedByUid, "closedByUid");
    optionalHistoryText(maintenance.closedByName, "closedByName");
    optionalHistoryText(maintenance.remarks, "remarks");
    history.push({
      resolvedByUid: maintenance.closedByUid ?? null,
      resolvedByName: maintenance.closedByName ?? null,
      resolvedAt: persistedInstant(maintenance.endDate, "endDate"),
      actionsJson: actionPayloadText(
        maintenance.actionsJson,
        "actionsJson",
        !Object.prototype.hasOwnProperty.call(maintenance, "actionsJson"),
      ),
      remarks: maintenance.remarks ?? null,
      downtimeHours: maintenance.downtimeHours ?? null,
      teamsInvolved: historyTeams(maintenance.teamsInvolved, "teamsInvolved"),
      ...(reopening == null ? {} : {
        reopenedByUid: reopening.actorUid,
        reopenedByName: reopening.actorName,
        reopenedAt: iso(reopening.at),
        reopenReason: reopening.reason,
        ...(reopening.byWorkflow ? {reopenedByWorkflow: true} : {}),
      }),
    });
  }
  return JSON.stringify(history);
};

const maintenanceClosureResetProjection = (maintenance: JsonMap): JsonMap => {
  const laneProjection = hasCompleteTicketLaneFields(maintenance) ? (() => {
    const plan = ticketLanePlan(maintenance);
    return ticketLaneProjection({
      ...plan,
      acknowledged: [],
      completed: [],
    });
  })() : {};
  const burnerProjection =
    maintenance.classification === "furnaceBurnerLockout" ? {
      burnerAttendedPositions: [],
      burnerResolutionEvidence: {},
    } : {};
  return {
    ...laneProjection,
    acknowledgedByUid: null,
    acknowledgedByName: null,
    acknowledgedAt: null,
    ...burnerProjection,
  };
};

export const maintenanceProjectionForCorrection = (args: {
  readonly maintenance: JsonMap;
  readonly reason: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
}): JsonMap => ({
  workflowDeferred: true,
  workflowQueueState: "correctionRequired",
  workflowDeferredAt: iso(args.at),
  workflowDeferredByUid: args.actorUid,
  workflowDeferredByName: args.actorName,
  workflowCorrectionReason: args.reason,
  workflowUpdatedAt: iso(args.at),
  ...(args.maintenance.isResolved === true ? {
    ...maintenanceClosureResetProjection(args.maintenance),
    isResolved: false,
    status: "open",
    endDate: null,
    closedByUid: null,
    closedByName: null,
    downtimeHours: null,
    teamsInvolved: [],
    actionsJson: "[]",
    remarks: args.reason,
    resolutionHistoryJson:
      maintenanceResolutionHistoryWithCurrentClosure(args.maintenance, {
        actorUid: args.actorUid,
        actorName: args.actorName,
        at: args.at,
        reason: args.reason,
        byWorkflow: true,
      }),
  } : {}),
  updatedAt: iso(args.at),
  version: maintenanceVersion(args.maintenance) + 1,
});

export const maintenanceProjectionForRelease = (args: {
  readonly maintenance: JsonMap;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: Date;
  readonly reason?: string;
}): JsonMap => ({
  workflowDeferred: false,
  workflowQueueState: "released",
  workflowReleasedAt: iso(args.at),
  workflowReleasedByUid: args.actorUid,
  workflowReleasedByName: args.actorName,
  workflowCorrectionReason: args.reason ?? null,
  workflowUpdatedAt: iso(args.at),
  updatedAt: iso(args.at),
  version: maintenanceVersion(args.maintenance) + 1,
});
