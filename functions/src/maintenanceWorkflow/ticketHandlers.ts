import {WorkflowError} from "./errors";
import {HandlerArgs, HandlerResult} from "./handlerTypes";
import {compliancePath, maintenancePath, workflowPath} from "./paths";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./types";
import {cleanText, iso, stableJson} from "./utils";
import {WorkflowTransaction} from "./store";
import {eventPlan} from "./events";
import {isFiveDigitChargeNumber} from "../chargeNumber";
import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {
  maintenanceResolutionHistoryWithCurrentClosure,
} from "./maintenanceBridge";
import {
  createTicketLanePlan,
  requestedTicketLanes,
  TICKET_LANE_FIELDS,
  ticketLanePlan,
  ticketLaneProjection,
  ticketLaneStatus,
} from "./ticketLanePlan";
import {
  applyBurnerBlockLifecycleWritePlan,
  prepareBurnerBlockLifecycleWritePlan,
} from "./burnerBlockLifecycle";
import {
  applyUvDetectorLifecycleWritePlan,
  prepareUvDetectorLifecycleWritePlan,
} from "./uvDetectorLifecycle";

const ROUTES = new Set([
  "operations", "electrical", "mechanical", "instrumentation",
  "refractory", "emd", "shiftInCharge", "others",
]);
const MAINTENANCE_TYPES = new Set([
  "scheduled", "breakdown", "performance", "inspection", "overhaul",
]);
const STATUSES = new Set([
  "open", "acknowledged", "inProgress", "resolved",
  "closedWithoutResolution",
]);
const TERMINAL_TICKET_STATUSES = new Set([
  "resolved", "closedWithoutResolution",
]);
const ADMINISTRATIVE_CLOSURE_DISPOSITIONS = new Set([
  "stillRelevant", "relevanceEnded",
]);
const TERMINAL_COMPLIANCE_STATUSES = new Set([
  "confirmedClosed", "cancelled", "superseded",
]);
const TERMINAL_WORKFLOW_STATUSES = new Set(["completed", "cancelled"]);
const ACTIVE_COMPLIANCE_STATUSES = new Set([
  "raised", "acknowledged", "complied",
]);
const ACTIVE_WORKFLOW_STATUSES = new Set([
  "pendingLaneClassification", "assigned", "partiallyAcknowledged",
  "fullyAcknowledged", "inProgress", "awaitingCompliance",
  "readyForClosure",
]);
const WORKFLOW_QUEUE_STATES = new Set([
  "independent", "deferred", "actionable", "awaitingConfirmation",
  "correctionRequired", "released",
]);
const WORKFLOW_PROJECTION_CORE_FIELDS = [
  "workflowDeferred", "workflowQueueState", "workflowAggregateId",
  "workflowComplianceId", "workflowOriginLaneKey", "workflowTargetLaneKey",
  "workflowConditionTypeKey", "workflowUpdatedAt",
] as const;
const WORKFLOW_PROJECTION_FIELDS = [
  ...WORKFLOW_PROJECTION_CORE_FIELDS,
  "workflowConditionRef", "workflowDeferredAt", "workflowDeferredByUid",
  "workflowDeferredByName", "workflowReactivatedAt",
  "workflowReactivatedByUid", "workflowReactivatedByName",
  "workflowReleasedAt", "workflowReleasedByUid", "workflowReleasedByName",
  "workflowCorrectionReason",
] as const;
const ASSET_TYPES = new Set([
  "base", "furnace", "forceCooler", "innerCover", "governedCustom",
]);
const QUALITY_ASSESSMENTS = new Set(["notSuspected", "suspected"]);
const ABNORMALITY_CATEGORIES = new Set([
  "process", "equipment", "resultQuality", "reannealing", "other",
]);
const ABNORMALITY_SEVERITIES = new Set([
  "low", "medium", "high", "critical",
]);
const BURNER_CYCLE_STAGES = new Set([
  "notRecorded", "purge", "ignition", "firing", "unknown",
]);
const BURNER_OBSERVATIONS = new Set(["seen", "notSeen", "notChecked"]);
const CORRECTABLE_FIELDS = new Set([
  "description", "routedTo", "maintenanceType", "isCritical", "component",
  "subsystem", "tag", "classification", "otherDepartment", "remarks",
  "plantConditionEffect",
]);
const PLANT_CONDITION_EFFECTS = new Set(["unfit", "unavailable"]);
const BURNER_LOCKOUT_CLASSIFICATION = "furnaceBurnerLockout";
const FURNACE_STUCKUP_CLASSIFICATION = "furnaceStuckup";
const BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION =
  "baseInnerCoverUnavailable";
const BASE_INNER_COVER_AVAILABILITY_COMPONENT = "Inner Cover availability";
const BASE_INNER_COVER_AVAILABILITY_SUBSYSTEM =
  "Base / Inner Cover association";
const STUCKUP_CAUSES = new Set([
  "innerCoverBulging",
  "draftSealPlateDamagedOrFallen",
  "insufficientDraftSealClearance",
  "combinedCondition",
  "other",
  "unknown",
]);
const STUCKUP_CONTEXTS = new Set([
  "postAnnealingRemoval",
  "maintenanceMovement",
  "other",
]);
const BURNER_RESOLUTION_OUTCOMES = new Set([
  "returnedToService", "remainsLockedOut", "isolatedForFollowUp",
]);
const BURNER_ACTION_CODES = new Set([
  "feedbackReset", "airLineCleaning", "uvDetectorCleaning", "poking",
  "flameAdjustment", "igniterRodHolderCleaning", "burnerControllerReset",
  "burnerControllerPowerOn", "safetyShutoffValveRelayWork",
  "relay6A6BWork", "igniterRodReplacement", "uvDetectorReplacement",
  "safetyShutoffValveSolenoidWork", "other",
]);
const BURNER_RETURN_TO_SERVICE_ACTIONS = new Set([
  "airLineCleaning", "uvDetectorCleaning", "poking", "flameAdjustment",
  "igniterRodHolderCleaning", "safetyShutoffValveRelayWork",
  "relay6A6BWork", "igniterRodReplacement", "uvDetectorReplacement",
  "safetyShutoffValveSolenoidWork", "other",
]);
const CREATE_TICKET_FIELDS = [
  "schemaVersion", "version", "assetType", "assetNumber", "component",
  "subsystem", "tag", "hierarchyPath", "assetHierarchyRefJson",
  "maintenanceType", "classification", "description", "routedTo",
  "otherDepartment", "isCritical", "startDate", "chargeNoAtEvent",
  "qualityIntentSchemaVersion", "qualityImpactAssessment",
  "qualityWarningReason",
] as const;
const QUALITY_ABNORMALITY_TYPE_FIELD = "qualityAbnormalityTypeId";
const PLANT_CONDITION_EFFECT_FIELD = "plantConditionEffect";
const LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD =
  "issueLaneCompletionEvidence";
const CREATE_BURNER_FIELDS = [
  "burnerLockoutSchemaVersion", "burnerPositions", "burnerCommonMode",
  "burnerCycleStage", "burnerHmiAlarm", "burnerFlameObservation",
  "burnerSparkObservation", "burnerRelightAttempts",
  "burnerRemainsLockedOut", "burnerRedHotPositions",
  "burnerAttendedPositions", "burnerResolutionEvidence",
] as const;
const CREATE_STUCKUP_FIELDS = [
  "furnaceStuckupSchemaVersion", "stuckupBaseNumber",
  "stuckupBaseAssetRefJson", "stuckupSuspectedCause",
  "stuckupOperatingContext",
] as const;
const FREQUENT_ISSUE_SELECTION_FIELD = "frequentIssueSelection";
const FREQUENT_ISSUE_SELECTION_FIELDS = [
  "schemaVersion", "selectionType", "definitionId", "definitionVersion",
  "unlistedReason",
] as const;

const isValidBurnerPositionList = (
  value: unknown,
  allowEmpty: boolean,
): value is number[] => Array.isArray(value) &&
  (allowEmpty || value.length > 0) &&
  value.length <= 8 &&
  new Set(value).size === value.length &&
  value.every((position) => Number.isInteger(position) &&
    position >= 1 && position <= 8);

const auditId = (commandId: string): string =>
  `server_maintenance_ticket_${commandId}`;
const auditPath = (commandId: string): string =>
  `audit_logs/${auditId(commandId)}`;

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "maintenance-ticket-command-shape-invalid", field},
    );
  }
};

const hasLegacyEmptyLaneCompletionEvidence = (input: JsonMap): boolean => {
  if (!Object.prototype.hasOwnProperty.call(
    input,
    LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD,
  )) {
    return false;
  }
  const evidence = input[LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD];
  if (evidence == null || typeof evidence !== "object" ||
      Array.isArray(evidence) || Object.keys(evidence).length !== 0) {
    throw new WorkflowError(
      "invalid-argument",
      "Client-authored lane completion evidence is prohibited.",
      {
        reasonCode:
          "maintenance-ticket-client-completion-evidence-prohibited",
      },
    );
  }
  return true;
};

const record = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be an object.`);
  }
  return value as JsonMap;
};

const optionalText = (
  value: unknown,
  field: string,
  max: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
  }
  const cleaned = value.trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > max) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be at most ${max} characters.`,
    );
  }
  return cleaned;
};

const optionalBoundedText = (
  value: unknown,
  field: string,
  min: number,
  max: number,
): string | null => {
  const cleaned = optionalText(value, field, max);
  if (cleaned != null && cleaned.length < min) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must contain at least ${min} characters.`,
    );
  }
  return cleaned;
};

const boundedText = (
  value: unknown,
  field: string,
  min: number,
  max: number,
): string => {
  const cleaned = cleanText(value, field);
  if (cleaned.length < min || cleaned.length > max) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be between ${min} and ${max} characters.`,
    );
  }
  return cleaned;
};

const instantText = (value: unknown): string | null => {
  if (value == null) return null;
  if (typeof value === "string") return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "object" &&
      "toDate" in value &&
      typeof (value as {toDate?: unknown}).toDate === "function") {
    return (value as {toDate: () => Date}).toDate().toISOString();
  }
  throw new WorkflowError(
    "failed-precondition",
    "Maintenance ticket timestamp evidence is malformed.",
    {reasonCode: "maintenance-ticket-timestamp-invalid"},
  );
};

const requiredInteger = (
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): number => {
  if (!Number.isSafeInteger(value) ||
      (value as number) < minimum || (value as number) > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be an integer between ${minimum} and ${maximum}.`,
    );
  }
  return value as number;
};

const requiredBoolean = (value: unknown, field: string): boolean => {
  if (typeof value !== "boolean") {
    throw new WorkflowError("invalid-argument", `${field} must be boolean.`);
  }
  return value;
};

const optionalStringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  maximumLength: number,
): string[] | null => {
  if (value == null) return null;
  if (!Array.isArray(value) || value.length > maximumItems ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.trim().length > maximumLength)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return value.map((item) => (item as string).trim());
};

const persistedStringList = (
  value: unknown,
  field: string,
  maximumItems = 10,
  maximumLength = 120,
): string[] => optionalStringList(
  value ?? [], field, maximumItems, maximumLength,
) ?? [];

const requiredInstantDate = (value: unknown, field: string): Date => {
  const text = cleanText(value, field);
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be a valid timestamp.`,
      {reasonCode: "maintenance-ticket-resolution-time-invalid", field},
    );
  }
  return parsed;
};

const requiredPersistedInstantDate = (
  value: unknown,
  field: string,
): Date => {
  let parsed: Date | null = null;
  if (value instanceof Date) {
    parsed = value;
  } else if (typeof value === "string" && value.trim().length > 0) {
    parsed = new Date(value);
  } else if (
    value != null &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof (value as {toDate?: unknown}).toDate === "function"
  ) {
    try {
      const converted = (value as {toDate: () => unknown}).toDate();
      if (converted instanceof Date) parsed = converted;
    } catch (_) {
      parsed = null;
    }
  }
  if (parsed == null || Number.isNaN(parsed.getTime())) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket timestamp evidence is malformed.",
      {reasonCode: "maintenance-ticket-timestamp-invalid", field},
    );
  }
  return parsed;
};

const currentMaintenanceEpisodeStart = (ticket: JsonMap): Date => {
  const startedAt = requiredPersistedInstantDate(
    ticket.startDate,
    "ticket.startDate",
  );
  const hasAnyReopenEvidence =
    ticket.reopenedAt != null ||
    ticket.reopenedByUid != null ||
    ticket.reopenedByName != null ||
    ticket.reopenReason != null;
  if (!hasAnyReopenEvidence) return startedAt;
  if (typeof ticket.reopenedByUid !== "string" ||
      ticket.reopenedByUid.trim().length === 0 ||
      typeof ticket.reopenedByName !== "string" ||
      ticket.reopenedByName.trim().length === 0 ||
      ticket.reopenedAt == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket reopening evidence is incomplete.",
      {reasonCode: "maintenance-ticket-reopen-evidence-invalid"},
    );
  }
  const reopenedAt = requiredPersistedInstantDate(
    ticket.reopenedAt,
    "ticket.reopenedAt",
  );
  if (reopenedAt.getTime() < startedAt.getTime()) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket reopening predates the original issue.",
      {reasonCode: "maintenance-ticket-reopen-evidence-invalid"},
    );
  }
  return reopenedAt;
};

const closureActionPayload = (
  value: unknown,
): {readonly text: string; readonly rows: readonly JsonMap[]} => {
  try {
    const parsed = readComponentActionPayload(value, {
      field: "actionsJson",
    });
    return {
      text: parsed.text,
      rows: parsed.rows as readonly JsonMap[],
    };
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new WorkflowError(
        "invalid-argument",
        "actionsJson contains invalid component-action evidence.",
        {
          reasonCode: "maintenance-ticket-resolution-actions-invalid",
          field: error.field,
        },
      );
    }
    throw error;
  }
};

const closureTeams = (
  value: unknown,
  assigned: readonly string[],
): string[] => {
  const requested = optionalStringList(
    value,
    "teamsInvolved",
    ROUTES.size,
    40,
  ) ?? [];
  if (new Set(requested).size !== requested.length ||
      requested.some((team) => !ROUTES.has(team))) {
    throw new WorkflowError(
      "invalid-argument",
      "teamsInvolved must be a unique supported maintenance-team list.",
      {reasonCode: "maintenance-ticket-resolution-teams-invalid"},
    );
  }
  return [...new Set([...assigned, ...requested])];
};

const burnerAttendanceSessionId = (
  ticketId: string,
  burnerPosition: number,
): string => `burner_${ticketId}_${burnerPosition}`;

const burnerResolutionProjection = (
  ticketId: string,
  ticket: JsonMap,
  actions: readonly JsonMap[],
): {readonly attended: number[]; readonly evidence: JsonMap} | null => {
  if (ticket.classification !== BURNER_LOCKOUT_CLASSIFICATION) return null;
  const positions = ticket.burnerPositions;
  if (!isValidBurnerPositionList(positions, false)) {
    throw new WorkflowError(
      "failed-precondition",
      "Saved burner positions need repair before issue closure.",
      {reasonCode: "maintenance-ticket-burner-evidence-invalid"},
    );
  }

  const grouped = new Map<number, {
    outcome: string;
    actionCodes: Set<string>;
    microampReading: number | null;
  }>();
  for (const action of actions) {
    if (action.burnerPosition == null) continue;
    const position = action.burnerPosition;
    const actionCode = action.burnerActionCode;
    const outcome = action.burnerOutcome;
    const reading = action.burnerMicroampReading;
    const normalizedReading = reading == null ? null : reading as number;
    if (!Number.isSafeInteger(position) ||
        !positions.includes(position as number) ||
        action.attendanceSessionId !== burnerAttendanceSessionId(
          ticketId,
          position as number,
        ) ||
        typeof actionCode !== "string" ||
        !BURNER_ACTION_CODES.has(actionCode) ||
        typeof outcome !== "string" ||
        !BURNER_RESOLUTION_OUTCOMES.has(outcome) ||
        (reading != null &&
          (typeof reading !== "number" || !Number.isFinite(reading) ||
            reading < 0 || reading > 1000000))) {
      throw new WorkflowError(
        "invalid-argument",
        "Burner attendance actions contain invalid resolution evidence.",
        {reasonCode: "maintenance-ticket-burner-resolution-invalid"},
      );
    }
    const existing = grouped.get(position as number);
    if (existing != null &&
        (existing.outcome !== outcome ||
          existing.microampReading !== normalizedReading)) {
      throw new WorkflowError(
        "invalid-argument",
        "Burner attendance actions disagree on their terminal outcome.",
        {reasonCode: "maintenance-ticket-burner-resolution-inconsistent"},
      );
    }
    const entry = existing ?? {
      outcome,
      actionCodes: new Set<string>(),
      microampReading: normalizedReading,
    };
    if (entry.actionCodes.has(actionCode)) {
      throw new WorkflowError(
        "invalid-argument",
        "Burner attendance actions contain duplicate work codes.",
        {reasonCode: "maintenance-ticket-burner-resolution-duplicate"},
      );
    }
    entry.actionCodes.add(actionCode);
    grouped.set(position as number, entry);
  }

  const evidence: Record<string, unknown> = {};
  for (const position of positions) {
    const entry = grouped.get(position);
    if (entry == null || entry.actionCodes.size === 0 ||
        (entry.outcome === "returnedToService" &&
          ![...entry.actionCodes].some((code) =>
            BURNER_RETURN_TO_SERVICE_ACTIONS.has(code)))) {
      throw new WorkflowError(
        "failed-precondition",
        `Burner ${position} requires complete terminal work evidence.`,
        {reasonCode: "maintenance-ticket-burner-resolution-incomplete"},
      );
    }
    evidence[String(position)] = {
      outcome: entry.outcome,
      actionCodes: [...entry.actionCodes],
      ...(entry.microampReading == null ? {} : {
        microampReading: entry.microampReading,
      }),
    };
  }
  return {attended: [...positions], evidence: evidence as JsonMap};
};

const parseFrequentIssueSelectionShape = (value: unknown): JsonMap => {
  const selection = record(value, FREQUENT_ISSUE_SELECTION_FIELD);
  exactKeys(
    selection,
    FREQUENT_ISSUE_SELECTION_FIELDS,
    FREQUENT_ISSUE_SELECTION_FIELD,
  );
  if (selection.schemaVersion !== 1 ||
      !["definition", "unlisted"].includes(String(selection.selectionType))) {
    throw new WorkflowError(
      "invalid-argument",
      "The frequent-issue selection is invalid.",
      {reasonCode: "frequent-issue-selection-invalid"},
    );
  }
  if (selection.selectionType === "definition") {
    boundedText(selection.definitionId, "definitionId", 1, 160);
    requiredInteger(
      selection.definitionVersion,
      "definitionVersion",
      1,
      2147483647,
    );
    if (selection.unlistedReason != null) {
      throw new WorkflowError(
        "invalid-argument",
        "A governed frequent issue cannot also contain an unlisted reason.",
      );
    }
  } else {
    if (selection.definitionId != null || selection.definitionVersion != null) {
      throw new WorkflowError(
        "invalid-argument",
        "An unlisted issue cannot claim a governed definition.",
      );
    }
    boundedText(selection.unlistedReason, "unlistedReason", 1, 500);
  }
  return selection;
};

const resolveFrequentIssueSelection = async (args: {
  readonly tx: WorkflowTransaction;
  readonly selection: JsonMap | null;
  readonly assetType: string;
  readonly assetClassId: string;
  readonly componentNodeId: string;
  readonly classification: string | null;
  readonly chargeNoAtEvent: number | null;
  readonly burnerHmiAlarm: string | null;
  readonly isStuckup: boolean;
}): Promise<JsonMap | null> => {
  if (args.selection == null) return null;
  if (args.selection.selectionType === "unlisted") {
    return {
      schemaVersion: 1,
      selectionType: "unlisted",
      definitionId: null,
      definitionVersion: null,
      definitionCode: null,
      definitionTitle: null,
      codeOwnedWorkflowProfile: null,
      unlistedReason: args.selection.unlistedReason as string,
    };
  }
  const definitionId = cleanText(args.selection.definitionId, "definitionId");
  const definitionVersion = requiredInteger(
    args.selection.definitionVersion,
    "definitionVersion",
    1,
    2147483647,
  );
  const snapshot = await args.tx.get(
    `frequent_issue_definitions/${definitionId}`,
  );
  const definition = snapshot.data;
  if (!snapshot.exists || definition == null || definition.schemaVersion !== 1 ||
      definition.definitionId !== definitionId ||
      definition.version !== definitionVersion || definition.status !== "active" ||
      typeof definition.normalizedCode !== "string" ||
      typeof definition.title !== "string" ||
      !Array.isArray(definition.applicableAssetTypeKeys) ||
      !Array.isArray(definition.applicableAssetClassIds) ||
      !Array.isArray(definition.applicableComponentNodeIds) ||
      !Array.isArray(definition.requiredEvidenceFields)) {
    throw new WorkflowError(
      "aborted",
      "The selected frequent issue changed or is no longer active.",
      {reasonCode: "frequent-issue-definition-changed", definitionId},
    );
  }
  const assetApplies = definition.applicableAssetTypeKeys.includes(
    args.assetType,
  ) || definition.applicableAssetClassIds.includes(args.assetClassId);
  const componentApplies = definition.applicableComponentNodeIds.length === 0 ||
    definition.applicableComponentNodeIds.includes(args.componentNodeId);
  if (!assetApplies || !componentApplies) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected frequent issue does not apply to this asset component.",
      {reasonCode: "frequent-issue-definition-out-of-scope", definitionId},
    );
  }
  const profile = definition.codeOwnedWorkflowProfile ?? null;
  if (profile != null &&
      (profile !== "furnaceStuckup" || !args.isStuckup ||
        args.classification !== FURNACE_STUCKUP_CLASSIFICATION)) {
    throw new WorkflowError(
      "failed-precondition",
      "This frequent issue requires its specialized workflow.",
      {reasonCode: "frequent-issue-specialized-workflow-required", definitionId},
    );
  }
  const requiredEvidence = definition.requiredEvidenceFields as unknown[];
  if ((requiredEvidence.includes("chargeNo") && args.chargeNoAtEvent == null) ||
      (requiredEvidence.includes("alarmText") && args.burnerHmiAlarm == null) ||
      (requiredEvidence.includes("operatingContext") && !args.isStuckup) ||
      requiredEvidence.includes("photo") || requiredEvidence.includes("measurement")) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected frequent issue requires evidence not present on this issue.",
      {reasonCode: "frequent-issue-required-evidence-missing", definitionId},
    );
  }
  return {
    schemaVersion: 1,
    selectionType: "definition",
    definitionId,
    definitionVersion,
    definitionCode: definition.normalizedCode as string,
    definitionTitle: definition.title as string,
    codeOwnedWorkflowProfile: profile as string | null,
    unlistedReason: null,
  };
};

const parseIsoInstant = (
  value: unknown,
  field: string,
  serverNow: Date,
): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError("invalid-argument", `${field} is required.`);
  }
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  if (parsed.getTime() > serverNow.getTime() + 5 * 60 * 1000) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} cannot be in the future.`,
      {reasonCode: "maintenance-ticket-start-time-future"},
    );
  }
  return parsed.toISOString();
};

const normalizeTag = (value: string): string =>
  value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");

const optionalStoredText = (
  data: JsonMap,
  field: string,
  maximum: number,
): string | null => optionalText(data[field], field, maximum);

const requiredStoredVersion = (data: JsonMap, field: string): number =>
  requiredInteger(data[field], field, 1, 2147483647);

const requireFreshAssetReference = async (args: {
  tx: WorkflowTransaction;
  raw: unknown;
  assetType: string;
  assetNumber: number;
  tag: string | null;
  startDate: string;
  actor: Actor;
  serverNow: Date;
}): Promise<string> => {
  if (typeof args.raw !== "string" || args.raw.trim().length === 0 ||
      args.raw.length > 12000) {
    throw new WorkflowError(
      "invalid-argument",
      "assetHierarchyRefJson is required.",
      {reasonCode: "maintenance-ticket-asset-reference-required"},
    );
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(args.raw);
  } catch {
    throw new WorkflowError(
      "invalid-argument",
      "The governed asset reference is malformed.",
      {reasonCode: "maintenance-ticket-asset-reference-invalid"},
    );
  }
  const reference = record(parsed, "assetHierarchyRefJson");
  const physicalReference =
    (reference.schemaVersion === 3 && reference.scope === "physicalAsset") ||
    ([2, 3].includes(reference.schemaVersion as number) &&
      reference.scope === "installedComponent");
  const componentDefinitionReference = reference.schemaVersion === 4 &&
    reference.scope === "componentDefinitionOnAsset";
  if (!physicalReference && !componentDefinitionReference) {
    throw new WorkflowError(
      "failed-precondition",
      "The governed asset reference is not an exact physical identity.",
      {reasonCode: "maintenance-ticket-asset-reference-scope-invalid"},
    );
  }
  const classId = boundedText(reference.assetClassId, "assetClassId", 1, 160);
  const scope = reference.scope as
    "physicalAsset" | "componentDefinitionOnAsset" | "installedComponent";
  const assetId = boundedText(
    reference.assetInstanceId,
    "assetInstanceId",
    1,
    160,
  );
  const expectedAssetVersion = requiredInteger(
    reference.assetInstanceVersion,
    "assetInstanceVersion",
    1,
    2147483647,
  );
  const assetClassSnapshot = await args.tx.get(`asset_classes/${classId}`);
  const assetSnapshot = await args.tx.get(`asset_instances/${assetId}`);
  if (!assetClassSnapshot.exists || assetClassSnapshot.data == null ||
      !assetSnapshot.exists || assetSnapshot.data == null) {
    throw new WorkflowError(
      "not-found",
      "The selected governed asset no longer exists.",
      {reasonCode: "maintenance-ticket-governed-asset-not-found"},
    );
  }
  const assetClass = assetClassSnapshot.data;
  const asset = assetSnapshot.data;
  const legacyType = assetClass.legacyAssetTypeKey;
  const classMatches = args.assetType === "innerCover" ?
    legacyType === "base" :
    args.assetType === "governedCustom" ?
      !["base", "furnace", "forceCooler", "innerCover"].includes(
        legacyType as string,
      ) : legacyType === args.assetType;
  if (assetClass.schemaVersion !== 1 ||
      assetClass.assetClassId !== classId || assetClass.status !== "active" ||
      !classMatches || typeof assetClass.code !== "string" ||
      typeof assetClass.name !== "string" ||
      asset.schemaVersion !== 1 || asset.assetInstanceId !== assetId ||
      asset.assetClassId !== classId || asset.status !== "active" ||
      asset.assetNumber !== args.assetNumber ||
      (scope !== "installedComponent" &&
        asset.version !== expectedAssetVersion) ||
      asset.assetClassCode !== assetClass.code ||
      asset.assetClassName !== assetClass.name ||
      typeof asset.name !== "string") {
    throw new WorkflowError(
      "aborted",
      "The selected governed asset changed before the issue was created.",
      {reasonCode: "maintenance-ticket-governed-asset-changed"},
    );
  }

  let innerCoverNodeClassId: string | null = null;
  if (args.assetType === "innerCover") {
    const innerCoverClasses = await args.tx.query("asset_classes", [{
      field: "legacyAssetTypeKey",
      op: "==",
      value: "innerCover",
    }, {
      field: "status",
      op: "==",
      value: "active",
    }]);
    if (innerCoverClasses.length !== 1) {
      throw new WorkflowError(
        "failed-precondition",
        "The active Inner Cover class register is ambiguous.",
        {reasonCode: "maintenance-ticket-inner-cover-class-ambiguous"},
      );
    }
    innerCoverNodeClassId = cleanText(
      innerCoverClasses[0].data?.assetClassId,
      "innerCover.assetClassId",
    );
  }

  let nodeId = assetId;
  let nodeVersion = expectedAssetVersion;
  let nodeName = asset.name as string;
  let componentInstanceId: string | null = null;
  let componentInstanceVersion: number | null = null;
  let componentTag: string | null = null;
  let hierarchyPath = [assetClass.name as string, asset.name as string];
  let ownershipStatus = cleanText(asset.ownershipStatus, "ownershipStatus");
  let ownerDiscipline = optionalStoredText(asset, "ownerDiscipline", 120);
  let accountableRoleKeys = persistedStringList(
    asset.accountableRoleKeys,
    "accountableRoleKeys",
    10,
    80,
  );
  if (scope === "componentDefinitionOnAsset") {
    const referencedNodeId = boundedText(
      reference.nodeId,
      "nodeId",
      1,
      160,
    );
    const referencedNodeVersion = requiredInteger(
      reference.nodeVersion,
      "nodeVersion",
      1,
      2147483647,
    );
    const nodeSnapshot = await args.tx.get(
      `asset_hierarchy_nodes/${referencedNodeId}`,
    );
    const node = nodeSnapshot.data;
    if (!nodeSnapshot.exists || node == null ||
        node.schemaVersion !== 1 || node.nodeId !== referencedNodeId ||
        node.assetClassId !== (innerCoverNodeClassId ?? classId) ||
        node.status !== "active" ||
        node.version !== referencedNodeVersion ||
        !["component", "subcomponent"].includes(node.nodeType as string) ||
        typeof node.name !== "string") {
      throw new WorkflowError(
        "aborted",
        "The selected hierarchy component changed before the issue was created.",
        {reasonCode: "maintenance-ticket-component-definition-changed"},
      );
    }
    nodeId = referencedNodeId;
    nodeVersion = referencedNodeVersion;
    nodeName = node.name as string;
    hierarchyPath = persistedStringList(
      node.hierarchyPath,
      "hierarchyPath",
      20,
      200,
    );
    ownershipStatus = cleanText(node.ownershipStatus, "ownershipStatus");
    ownerDiscipline = optionalStoredText(node, "ownerDiscipline", 120);
    accountableRoleKeys = persistedStringList(
      node.accountableRoleKeys,
      "accountableRoleKeys",
      10,
      80,
    );
    const definitionTag = optionalStoredText(node, "componentTag", 160);
    if (args.tag != null &&
        (definitionTag == null ||
          normalizeTag(args.tag) !== normalizeTag(definitionTag))) {
      throw new WorkflowError(
        "failed-precondition",
        "The equipment tag does not identify the selected hierarchy component on this asset.",
        {reasonCode: "maintenance-ticket-component-definition-tag-invalid"},
      );
    }
  } else if (scope === "installedComponent") {
    componentInstanceId = boundedText(
      reference.componentInstanceId,
      "componentInstanceId",
      1,
      160,
    );
    componentInstanceVersion = requiredInteger(
      reference.componentInstanceVersion,
      "componentInstanceVersion",
      1,
      2147483647,
    );
    const componentSnapshot = await args.tx.get(
      `asset_component_instances/${componentInstanceId}`,
    );
    const component = componentSnapshot.data;
    if (!componentSnapshot.exists || component == null ||
        component.schemaVersion !== 1 ||
        component.componentInstanceId !== componentInstanceId ||
        component.assetClassId !== classId ||
        component.assetInstanceId !== assetId ||
        component.assetNumber !== args.assetNumber ||
        component.status !== "active" ||
        component.version !== componentInstanceVersion ||
        component.assetInstanceVersionAtMutation !== expectedAssetVersion ||
        typeof component.definitionNodeId !== "string" ||
        typeof component.definitionName !== "string" ||
        !Number.isSafeInteger(component.definitionNodeVersion)) {
      throw new WorkflowError(
        "aborted",
        "The selected installed component changed before the issue was created.",
        {reasonCode: "maintenance-ticket-governed-component-changed"},
      );
    }
    componentTag = optionalStoredText(component, "componentTag", 160);
    if (args.tag == null || componentTag == null ||
        normalizeTag(args.tag) !== normalizeTag(componentTag)) {
      throw new WorkflowError(
        "failed-precondition",
        "The issue tag no longer identifies the selected installed component.",
        {reasonCode: "maintenance-ticket-governed-tag-mismatch"},
      );
    }
    nodeId = component.definitionNodeId as string;
    nodeVersion = component.definitionNodeVersion as number;
    nodeName = component.definitionName as string;
    hierarchyPath = persistedStringList(
      component.hierarchyPath,
      "hierarchyPath",
      20,
      200,
    );
    ownershipStatus = cleanText(
      component.ownershipStatus,
      "ownershipStatus",
    );
    ownerDiscipline = optionalStoredText(component, "ownerDiscipline", 120);
    accountableRoleKeys = persistedStringList(
      component.accountableRoleKeys,
      "accountableRoleKeys",
      10,
      80,
    );
  }
  if (!["unassigned", "provisional", "confirmed"].includes(ownershipStatus) ||
      (scope === "installedComponent" && ownershipStatus !== "confirmed")) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected asset ownership evidence is invalid.",
      {reasonCode: "maintenance-ticket-asset-ownership-invalid"},
    );
  }

  let innerCoverAssociation: JsonMap | null = null;
  if (args.assetType === "base" || args.assetType === "innerCover") {
    const assignmentSnapshot = await args.tx.get(
      `base_inner_cover_assignments/${assetId}`,
    );
    if (!assignmentSnapshot.exists || assignmentSnapshot.data == null) {
      if (args.assetType === "innerCover") {
        throw new WorkflowError(
          "failed-precondition",
          "No Inner Cover is currently linked to the selected Base.",
          {reasonCode: "maintenance-ticket-inner-cover-not-linked"},
        );
      }
      innerCoverAssociation = {
        baseAssetInstanceId: assetId,
        baseAssetNumber: args.assetNumber,
        positionState: "noneLinked",
        innerCoverId: null,
        innerCoverSerialNumber: null,
        linkageId: null,
        assignmentVersion: null,
        linkedAt: null,
        eventAt: args.startDate,
        confirmedAt: iso(args.serverNow),
        confirmedByUid: args.actor.uid,
        confirmedByName: args.actor.name,
      };
    } else {
      const assignment = assignmentSnapshot.data;
      const innerCoverId = cleanText(assignment.innerCoverId, "innerCoverId");
      const profileSnapshot = await args.tx.get(
        `inner_cover_profiles/${innerCoverId}`,
      );
      const profile = profileSnapshot.data;
      const linkedAt = instantText(assignment.linkedAt);
      const linkedAtMillis = linkedAt == null ? Number.NaN : Date.parse(linkedAt);
      if (assignment.schemaVersion !== 1 ||
          assignment.baseAssetInstanceId !== assetId ||
          assignment.baseAssetClassId !== classId ||
          assignment.baseAssetNumber !== args.assetNumber ||
          !Number.isSafeInteger(assignment.version) ||
          typeof assignment.linkageId !== "string" ||
          typeof assignment.innerCoverSerialNumber !== "string" ||
          !Number.isFinite(linkedAtMillis) ||
          !profileSnapshot.exists || profile == null ||
          profile.schemaVersion !== 1 || profile.innerCoverId !== innerCoverId ||
          profile.lifecycleState !== "installed" ||
          profile.currentBaseAssetInstanceId !== assetId ||
          profile.currentBaseAssetNumber !== args.assetNumber ||
          profile.currentLinkageId !== assignment.linkageId ||
          profile.serialNumber !== assignment.innerCoverSerialNumber) {
        throw new WorkflowError(
          "failed-precondition",
          "The Base and Inner Cover projections disagree.",
          {reasonCode: "maintenance-ticket-inner-cover-projection-invalid"},
        );
      }
      if (Date.parse(args.startDate) < linkedAtMillis) {
        throw new WorkflowError(
          "failed-precondition",
          "The issue predates the current Inner Cover assignment.",
          {reasonCode: "maintenance-ticket-inner-cover-linkage-after-event"},
        );
      }
      innerCoverAssociation = {
        baseAssetInstanceId: assetId,
        baseAssetNumber: args.assetNumber,
        positionState: "linked",
        innerCoverId,
        innerCoverSerialNumber: assignment.innerCoverSerialNumber as string,
        linkageId: assignment.linkageId as string,
        assignmentVersion: assignment.version as number,
        linkedAt: new Date(linkedAtMillis).toISOString(),
        eventAt: args.startDate,
        confirmedAt: iso(args.serverNow),
        confirmedByUid: args.actor.uid,
        confirmedByName: args.actor.name,
      };
    }
  }

  return stableJson({
    schemaVersion: scope === "componentDefinitionOnAsset" ? 4 : 3,
    scope,
    assetClassId: classId,
    assetClassCode: assetClass.code as string,
    assetClassName: assetClass.name as string,
    nodeId,
    nodeVersion,
    nodeName,
    assetInstanceId: assetId,
    assetInstanceVersion: expectedAssetVersion,
    assetNumber: args.assetNumber,
    assetInstanceName: asset.name as string,
    componentInstanceId,
    componentInstanceVersion,
    componentTag,
    hierarchyPath,
    ownershipStatus,
    ownerDiscipline,
    accountableRoleKeys,
    innerCoverAssociation,
  });
};

const requireBaseVacantAtIssueStart = async (args: {
  tx: WorkflowTransaction;
  baseAssetInstanceId: string;
  baseAssetNumber: number;
  startDate: string;
}): Promise<void> => {
  const eventMillis = Date.parse(args.startDate);
  const linkages = await args.tx.query("inner_cover_linkages", [{
    field: "baseAssetInstanceId",
    op: "==",
    value: args.baseAssetInstanceId,
  }]);
  for (const snapshot of linkages) {
    const linkage = snapshot.data;
    if (!snapshot.exists || linkage == null || linkage.schemaVersion !== 1 ||
        linkage.baseAssetInstanceId !== args.baseAssetInstanceId ||
        linkage.baseAssetNumber !== args.baseAssetNumber ||
        typeof linkage.linkageId !== "string" ||
        snapshot.path !== `inner_cover_linkages/${linkage.linkageId}` ||
        typeof linkage.innerCoverId !== "string" ||
        linkage.innerCoverId.trim().length === 0 ||
        typeof linkage.innerCoverSerialNumber !== "string" ||
        linkage.innerCoverSerialNumber.trim().length === 0 ||
        typeof linkage.active !== "boolean" ||
        !Number.isSafeInteger(linkage.version) ||
        (linkage.version as number) < 1) {
      throw new WorkflowError(
        "failed-precondition",
        "The Base Inner Cover linkage history is malformed.",
        {reasonCode: "maintenance-ticket-inner-cover-history-invalid"},
      );
    }
    const installedAt = requiredPersistedInstantDate(
      linkage.installedAt,
      "innerCoverLinkage.installedAt",
    ).getTime();
    const removedAt = linkage.removedAt == null ? null :
      requiredPersistedInstantDate(
        linkage.removedAt,
        "innerCoverLinkage.removedAt",
      ).getTime();
    if ((linkage.active === true) !== (removedAt == null) ||
        (removedAt != null && removedAt < installedAt)) {
      throw new WorkflowError(
        "failed-precondition",
        "The Base Inner Cover linkage interval is malformed.",
        {reasonCode: "maintenance-ticket-inner-cover-history-invalid"},
      );
    }
    if (linkage.active === true) {
      throw new WorkflowError(
        "failed-precondition",
        "The Base assignment and linkage history disagree.",
        {reasonCode: "maintenance-ticket-inner-cover-state-inconsistent"},
      );
    }
    if (installedAt <= eventMillis &&
        (removedAt == null || eventMillis < removedAt)) {
      throw new WorkflowError(
        "failed-precondition",
        `Inner Cover ${linkage.innerCoverSerialNumber} was linked to this Base at the selected issue time.`,
        {reasonCode: "maintenance-ticket-inner-cover-linked-at-event"},
      );
    }
  }
};

const savedClosureActionPayload = (
  value: unknown,
  field = "work.actionsJson",
): {readonly text: string; readonly rows: readonly JsonMap[]} => {
  try {
    const parsed = readComponentActionPayload(value, {
      field,
      allowMissing: value == null,
    });
    return {
      text: parsed.text,
      rows: parsed.rows as readonly JsonMap[],
    };
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new WorkflowError(
        "failed-precondition",
        "Saved maintenance action evidence needs repair before resolution.",
        {
          reasonCode: "maintenance-ticket-saved-actions-invalid",
          field: error.field,
        },
      );
    }
    throw error;
  }
};

const isBurnerActionEvidence = (row: JsonMap): boolean =>
  row.attendanceSessionId != null || row.burnerActionCode != null ||
  row.burnerOutcome != null || row.burnerMicroampReading != null;

export const canonicalGovernedClosureActions = async (args: {
  tx: WorkflowTransaction;
  existingValue: unknown;
  assetType: unknown;
  assetNumber: unknown;
  workStartedAt: unknown;
  requested: {readonly text: string; readonly rows: readonly JsonMap[]};
  contractVersion: number | null;
  actor: Actor;
  serverNow: Date;
  endDate: Date;
  allowBurnerEvidence?: boolean;
}): Promise<{readonly text: string; readonly rows: readonly JsonMap[]}> => {
  const saved = savedClosureActionPayload(args.existingValue);
  if (args.requested.rows.length < saved.rows.length ||
      saved.rows.some((row, index) =>
        stableJson(row) !== stableJson(args.requested.rows[index]))) {
    throw new WorkflowError(
      "failed-precondition",
      "Existing maintenance action history cannot be removed or changed during resolution.",
      {reasonCode: "maintenance-ticket-action-history-changed"},
    );
  }

  const additions = args.requested.rows.slice(saved.rows.length);
  if (additions.length === 0) return args.requested;
  if (additions.some((row) => !isBurnerActionEvidence(row)) &&
      args.contractVersion !== 1) {
    throw new WorkflowError(
      "failed-precondition",
      "New maintenance actions require the governed asset-target contract.",
      {reasonCode: "maintenance-ticket-action-target-contract-required"},
    );
  }

  const assetType = boundedText(args.assetType, "work.assetType", 1, 80);
  const assetNumber = requiredInteger(
    args.assetNumber,
    "work.assetNumber",
    1,
    2147483647,
  );
  const ticketStart = requiredPersistedInstantDate(
    args.workStartedAt,
    "work.startedAt",
  );
  const canonicalRows: JsonMap[] = [...saved.rows];

  for (const [offset, row] of additions.entries()) {
    if (isBurnerActionEvidence(row)) {
      if (args.allowBurnerEvidence !== true) {
        throw new WorkflowError(
          "failed-precondition",
          "Burner attendance evidence is only valid for a burner-lockout issue.",
          {reasonCode: "maintenance-ticket-burner-action-out-of-scope"},
        );
      }
      canonicalRows.push(row);
      continue;
    }

    const performedAt = requiredPersistedInstantDate(
      row.createdAt,
      `actionsJson[${saved.rows.length + offset}].createdAt`,
    );
    if (performedAt.getTime() < ticketStart.getTime() ||
        performedAt.getTime() > args.endDate.getTime() + 5 * 60 * 1000) {
      throw new WorkflowError(
        "invalid-argument",
        "Maintenance action time must fall within the issue work period.",
        {reasonCode: "maintenance-ticket-action-time-invalid"},
      );
    }
    const rawReference = row.assetHierarchyRef;
    if (rawReference == null || typeof rawReference !== "object" ||
        Array.isArray(rawReference)) {
      throw new WorkflowError(
        "failed-precondition",
        "Each new maintenance action must select a governed component on the work asset.",
        {reasonCode: "maintenance-ticket-action-target-required"},
      );
    }
    const tag = optionalText(row.tag, "tag", 160);
    const canonicalReferenceText = await requireFreshAssetReference({
      tx: args.tx,
      raw: stableJson(rawReference),
      assetType,
      assetNumber,
      tag,
      startDate: performedAt.toISOString(),
      actor: args.actor,
      serverNow: args.serverNow,
    });
    const canonicalReference = record(
      JSON.parse(canonicalReferenceText),
      "assetHierarchyRef",
    );
    const hierarchyPath = persistedStringList(
      canonicalReference.hierarchyPath,
      "assetHierarchyRef.hierarchyPath",
      20,
      200,
    );
    canonicalRows.push({
      ...row,
      asset: canonicalReference.assetInstanceName,
      component: canonicalReference.nodeName,
      hierarchyPath,
      assetHierarchyRef: canonicalReference,
      system: canonicalReference.assetClassName,
      subsystem: hierarchyPath.length > 1 ?
        hierarchyPath[hierarchyPath.length - 2] : null,
      tag: canonicalReference.scope === "componentDefinitionOnAsset" ?
        tag : canonicalReference.componentTag ?? null,
      performedBy: args.actor.name,
    });
  }

  return {text: stableJson(canonicalRows), rows: canonicalRows};
};

const qualityWarningProjection = (args: {
  ticketId: string;
  ticket: JsonMap;
  actor: Actor;
  timestamp: string;
}): JsonMap | null => {
  if (args.ticket.qualityImpactAssessment !== "suspected") return null;
  const warningId = `issue_${args.ticketId}`;
  return {
    schemaVersion: 1,
    warningId,
    sourceType: "issue",
    sourceId: args.ticketId,
    sourceVersion: args.ticket.version as number,
    sourceChargeNo: args.ticket.chargeNoAtEvent as number,
    sourceSummary: args.ticket.description as string,
    sourceSeverity: args.ticket.isCritical === true ? "critical" : "standard",
    warningReason: args.ticket.qualityWarningReason as string,
    affectedAssets: [{
      assetType: args.ticket.assetType as string,
      assetNumber: args.ticket.assetNumber as number,
    }],
    component: args.ticket.component ?? null,
    status: "open",
    closureRequestReason: null,
    closureRequestedAt: null,
    closureRequestedByUid: null,
    closureRequestedByName: null,
    closedAt: null,
    closedByUid: null,
    closedByName: null,
    closureDisposition: null,
    linkedReannealingChargeNos: [],
    decisionReason: null,
    createdAt: args.timestamp,
    createdByUid: args.actor.uid,
    createdByName: args.actor.name,
    updatedAt: args.timestamp,
    updatedByUid: args.actor.uid,
    updatedByName: args.actor.name,
    version: 1,
  };
};

type CanonicalQualityAbnormalityType = {
  readonly id: string;
  readonly code: string;
  readonly title: string;
  readonly category: string;
  readonly severity: string;
};

const canonicalQualityAbnormalityType = (args: {
  snapshot: {readonly exists: boolean; readonly data: JsonMap | null};
  typeId: string;
  assetType: string;
}): CanonicalQualityAbnormalityType => {
  const data = args.snapshot.data;
  if (!args.snapshot.exists || data == null || data.firestoreId !== args.typeId ||
      data.isActive !== true || data.isDeleted !== false) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected abnormality classification is unavailable.",
      {
        reasonCode: "maintenance-ticket-quality-type-unavailable",
        abnormalityTypeId: args.typeId,
      },
    );
  }
  const code = boundedText(data.code, "abnormalityType.code", 1, 160);
  const title = boundedText(data.title, "abnormalityType.title", 1, 500);
  const category = cleanText(data.category, "abnormalityType.category");
  const severity = cleanText(data.severity, "abnormalityType.severity");
  const applicableAssetTypes = optionalStringList(
    data.applicableAssetTypes,
    "abnormalityType.applicableAssetTypes",
    ASSET_TYPES.size,
    40,
  ) ?? [];
  if (!ABNORMALITY_CATEGORIES.has(category) ||
      !ABNORMALITY_SEVERITIES.has(severity) ||
      new Set(applicableAssetTypes).size !== applicableAssetTypes.length ||
      applicableAssetTypes.some((value) => !ASSET_TYPES.has(value)) ||
      (applicableAssetTypes.length > 0 &&
        !applicableAssetTypes.includes(args.assetType))) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected abnormality classification does not apply to this asset.",
      {
        reasonCode: "maintenance-ticket-quality-type-inapplicable",
        abnormalityTypeId: args.typeId,
        assetType: args.assetType,
      },
    );
  }
  return {id: args.typeId, code, title, category, severity};
};

const qualityRootReasonForAsset = (assetType: string): string => {
  switch (assetType) {
  case "base": return "baseRelated";
  case "furnace": return "furnaceRelated";
  case "forceCooler": return "forceCoolerRelated";
  default: return "unknown";
  }
};

const qualityAbnormalityProjection = (args: {
  abnormalityId: string;
  ticketId: string;
  ticket: JsonMap;
  type: CanonicalQualityAbnormalityType;
  actor: Actor;
  timestamp: string;
}): JsonMap => ({
  firestoreId: args.abnormalityId,
  sourceChargeNo: args.ticket.chargeNoAtEvent as number,
  abnormalityTypeId: args.type.id,
  abnormalityTypeTitle: args.type.title,
  abnormalityTypeCode: args.type.code,
  category: args.type.category,
  severity: args.ticket.isCritical === true ? "critical" : args.type.severity,
  affectedAssets: [{
    assetType: args.ticket.assetType as string,
    assetNumber: args.ticket.assetNumber as number,
  }],
  component: args.ticket.component ?? null,
  observedReason: args.ticket.qualityWarningReason as string,
  description: args.ticket.description as string,
  possibleRootReasonCategory: qualityRootReasonForAsset(
    args.ticket.assetType as string,
  ),
  possibleRootReasonNotes: null,
  reannealingStatus: "pendingDecision",
  reannealedToChargeNo: null,
  loggedAt: args.timestamp,
  updatedAt: args.timestamp,
  loggedByUid: args.actor.uid,
  loggedByName: args.actor.name,
  updatedByUid: args.actor.uid,
  updatedByName: args.actor.name,
  linkedTicketFirestoreId: args.ticketId,
  linkedExecutionFirestoreId: null,
  version: 1,
  isDeleted: false,
  deletedAt: null,
  deletedByUid: null,
  deletedByName: null,
  deleteReason: null,
});

const redHotDirectiveProjection = (args: {
  ticketId: string;
  ticket: JsonMap;
  actor: Actor;
  timestamp: string;
}): JsonMap | null => {
  const positions = args.ticket.burnerRedHotPositions;
  if (!Array.isArray(positions) || positions.length === 0) return null;
  const directiveId = `burner_red_hot_${args.ticketId}`;
  const burnerList = positions.map((position) => `B${position}`).join(", ");
  return {
    firestoreId: directiveId,
    title: `Red-hot burner block: ${burnerList}`,
    description:
      `Furnace ${args.ticket.assetNumber} has a reported red-hot burner block ` +
      `at ${burnerList}. I&A must acknowledge, apply the approved plant ` +
      "procedure to take the affected burner position out of firing service, " +
      "and record compliance. This directive does not actuate the PLC.",
    assetType: "furnace",
    assetNumber: args.ticket.assetNumber,
    component: "Burner block",
    subsystem: "Burner system",
    tag: null,
    hierarchyPath: ["Furnace", "Combustion system", "Burner block"],
    directedTo: "seniorInstrumentation",
    status: "open",
    priority: "critical",
    createdByUid: args.actor.uid,
    createdByName: args.actor.name,
    issuedByUid: args.actor.uid,
    issuedByName: args.actor.name,
    issuedAt: args.timestamp,
    isActive: true,
    acknowledgedByUid: null,
    acknowledgedByName: null,
    acknowledgedAt: null,
    closedByUid: null,
    closedByName: null,
    closedAt: null,
    closedWithoutAcknowledgement: false,
    remarks: null,
    linkedMaintenanceFirestoreId: args.ticketId,
    linkedExecutionFirestoreId: null,
    metadataJson: JSON.stringify({
      schemaVersion: 1,
      trigger: "burnerBlockRedHot",
      burnerPositions: positions,
      automaticPlantActuation: false,
    }),
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    createdAt: args.timestamp,
    updatedAt: args.timestamp,
    version: 1,
  };
};

const ticketSnapshot = (ticket: JsonMap): JsonMap => ({
  firestoreId: ticket.firestoreId ?? null,
  version: ticket.version ?? null,
  assetType: ticket.assetType ?? null,
  assetNumber: ticket.assetNumber ?? null,
  maintenanceType: ticket.maintenanceType ?? null,
  description: ticket.description ?? null,
  plantConditionEffect: ticket.plantConditionEffect ?? null,
  routedTo: ticket.routedTo ?? null,
  status: ticket.status ?? null,
  isResolved: ticket.isResolved ?? null,
  isCritical: ticket.isCritical ?? null,
  component: ticket.component ?? null,
  subsystem: ticket.subsystem ?? null,
  tag: ticket.tag ?? null,
  classification: ticket.classification ?? null,
  otherDepartment: ticket.otherDepartment ?? null,
  remarks: ticket.remarks ?? null,
  acknowledgedByUid: ticket.acknowledgedByUid ?? null,
  acknowledgedByName: ticket.acknowledgedByName ?? null,
  acknowledgedAt: instantText(ticket.acknowledgedAt),
  issueLaneSchemaVersion: ticket.issueLaneSchemaVersion ?? null,
  issueLaneRevision: ticket.issueLaneRevision ?? null,
  issueAssignedLanes: ticket.issueAssignedLanes ?? null,
  issueAcknowledgedLanes: ticket.issueAcknowledgedLanes ?? null,
  issueCompletedLanes: ticket.issueCompletedLanes ?? null,
  issueLaneCompletionEvidence: ticket.issueLaneCompletionEvidence ?? null,
  endDate: instantText(ticket.endDate),
  closedByUid: ticket.closedByUid ?? null,
  closedByName: ticket.closedByName ?? null,
  downtimeHours: ticket.downtimeHours ?? null,
  teamsInvolved: ticket.teamsInvolved ?? null,
  actionsJson: ticket.actionsJson ?? null,
  resolutionHistoryJson: ticket.resolutionHistoryJson ?? null,
  reopenedByUid: ticket.reopenedByUid ?? null,
  reopenedByName: ticket.reopenedByName ?? null,
  reopenedAt: instantText(ticket.reopenedAt),
  reopenReason: ticket.reopenReason ?? null,
  burnerAttendedPositions: ticket.burnerAttendedPositions ?? null,
  burnerResolutionEvidence: ticket.burnerResolutionEvidence ?? null,
  workflowDeferred: ticket.workflowDeferred ?? false,
  workflowQueueState: ticket.workflowQueueState ?? null,
  workflowAggregateId: ticket.workflowAggregateId ?? null,
  workflowComplianceId: ticket.workflowComplianceId ?? null,
  issueClosureSchemaVersion: ticket.issueClosureSchemaVersion ?? null,
  issueClosureDisposition: ticket.issueClosureDisposition ?? null,
  issueClosureReason: ticket.issueClosureReason ?? null,
  isDeleted: ticket.isDeleted ?? null,
});

const requireTicket = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
  options: {readonly allowDeferred?: boolean} = {},
): Promise<{ticket: JsonMap; version: number}> => {
  const snapshot = await tx.get(maintenancePath(command.aggregateId));
  if (!snapshot.exists || snapshot.data == null) {
    throw new WorkflowError(
      "not-found",
      "Maintenance ticket was not found.",
      {reasonCode: "maintenance-ticket-not-found"},
    );
  }
  const ticket = snapshot.data;
  const version = ticket.version;
  if (!Number.isSafeInteger(version) || (version as number) < 1 ||
      ticket.firestoreId !== command.aggregateId ||
      typeof ticket.isDeleted !== "boolean" ||
      typeof ticket.isResolved !== "boolean" ||
      (ticket.workflowDeferred != null &&
        typeof ticket.workflowDeferred !== "boolean") ||
      typeof ticket.status !== "string" || !STATUSES.has(ticket.status) ||
      (TERMINAL_TICKET_STATUSES.has(ticket.status as string) !==
        ticket.isResolved)) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket lifecycle evidence is malformed.",
      {reasonCode: "maintenance-ticket-evidence-invalid"},
    );
  }
  if (ticket.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Deleted maintenance tickets cannot be changed.",
      {reasonCode: "maintenance-ticket-deleted"},
    );
  }
  if (ticket.workflowDeferred === true && options.allowDeferred !== true) {
    throw new WorkflowError(
      "failed-precondition",
      "Use the linked compliance request before changing this deferred ticket.",
      {reasonCode: "maintenance-ticket-workflow-deferred"},
    );
  }
  if (version !== command.expectedVersion) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "Maintenance ticket changed before this command was applied.",
      {
        reasonCode: "maintenance-ticket-version-conflict",
        expectedVersion: command.expectedVersion,
        actualVersion: version,
      },
    );
  }
  return {ticket, version: version as number};
};

interface TicketWorkflowProjection {
  readonly projected: boolean;
  readonly queueState: string;
  readonly workflowId: string | null;
  readonly complianceId: string | null;
}

const workflowProjectionError = (field: string): never => {
  throw new WorkflowError(
    "failed-precondition",
    "The issue coordination projection is incomplete or malformed.",
    {
      reasonCode: "maintenance-ticket-coordination-projection-invalid",
      field,
    },
  );
};

const persistedWorkflowText = (
  value: unknown,
  field: string,
  maximumLength: number,
): string => {
  if (typeof value !== "string") return workflowProjectionError(field);
  const cleaned = value.trim();
  if (cleaned.length === 0 || cleaned.length > maximumLength) {
    return workflowProjectionError(field);
  }
  return cleaned;
};

const ticketWorkflowProjection = (
  ticket: JsonMap,
): TicketWorkflowProjection => {
  const owns = (field: string): boolean =>
    Object.prototype.hasOwnProperty.call(ticket, field);
  const presentFields = WORKFLOW_PROJECTION_FIELDS.filter(owns);
  if (presentFields.length === 0) {
    return {
      projected: false,
      queueState: "independent",
      workflowId: null,
      complianceId: null,
    };
  }
  if (presentFields.length === 1 &&
      presentFields[0] === "workflowDeferred" &&
      ticket.workflowDeferred === false) {
    return {
      projected: false,
      queueState: "independent",
      workflowId: null,
      complianceId: null,
    };
  }
  const missingCoreField = WORKFLOW_PROJECTION_CORE_FIELDS.find(
    (field) => !owns(field),
  );
  if (missingCoreField != null) return workflowProjectionError(missingCoreField);
  if (typeof ticket.workflowDeferred !== "boolean") {
    return workflowProjectionError("workflowDeferred");
  }
  const queueState = persistedWorkflowText(
    ticket.workflowQueueState,
    "workflowQueueState",
    80,
  );
  const mustBeDeferred = queueState === "deferred" ||
    queueState === "correctionRequired";
  if (!WORKFLOW_QUEUE_STATES.has(queueState) ||
      ticket.workflowDeferred !== mustBeDeferred) {
    return workflowProjectionError("workflowQueueState");
  }
  const workflowId = persistedWorkflowText(
    ticket.workflowAggregateId,
    "workflowAggregateId",
    200,
  );
  const complianceId = persistedWorkflowText(
    ticket.workflowComplianceId,
    "workflowComplianceId",
    200,
  );
  persistedWorkflowText(ticket.workflowOriginLaneKey, "workflowOriginLaneKey", 80);
  persistedWorkflowText(ticket.workflowTargetLaneKey, "workflowTargetLaneKey", 80);
  persistedWorkflowText(
    ticket.workflowConditionTypeKey,
    "workflowConditionTypeKey",
    80,
  );
  requiredPersistedInstantDate(ticket.workflowUpdatedAt, "workflowUpdatedAt");
  if (ticket.workflowConditionRef != null) {
    persistedWorkflowText(ticket.workflowConditionRef, "workflowConditionRef", 300);
  }
  return {projected: true, queueState, workflowId, complianceId};
};

const requireReleasedTicketCoordination = async (args: {
  tx: WorkflowTransaction;
  ticket: JsonMap;
  ticketId: string;
}): Promise<void> => {
  const projection = ticketWorkflowProjection(args.ticket);
  const {queueState, workflowId, complianceId} = projection;
  if (queueState !== "independent" && queueState !== "released") {
    throw new WorkflowError(
      "failed-precondition",
      "Operations coordination must be completed or cancelled before resolving this issue.",
      {
        reasonCode: "maintenance-ticket-coordination-open",
        queueState,
      },
    );
  }

  const [complianceRows, workflowRows, workflowSnapshot,
    projectedComplianceSnapshot] = await Promise.all([
    args.tx.query("compliance_requests", [
      {
        field: "linkedMaintenanceFirestoreId",
        op: "==",
        value: args.ticketId,
      },
    ]),
    args.tx.query("maintenance_workflows", [
      {
        field: "linkedMaintenanceFirestoreId",
        op: "==",
        value: args.ticketId,
      },
    ]),
    workflowId == null ?
      Promise.resolve(null) : args.tx.get(workflowPath(workflowId)),
    complianceId == null ?
      Promise.resolve(null) : args.tx.get(compliancePath(complianceId)),
  ]);
  if (complianceRows.length > 50 || workflowRows.length > 50) {
    throw new WorkflowError(
      "failed-precondition",
      "Issue coordination history exceeds the governed resolution boundary.",
      {
        reasonCode: "maintenance-ticket-coordination-history-oversized",
        complianceCount: complianceRows.length,
        workflowCount: workflowRows.length,
      },
    );
  }
  const activeComplianceRows = complianceRows.filter((row) =>
    !TERMINAL_COMPLIANCE_STATUSES.has(String(row.data?.status)));
  const activeWorkflowRows = workflowRows.filter((row) =>
    !TERMINAL_WORKFLOW_STATUSES.has(String(row.data?.status)));
  if (activeComplianceRows.length !== 0 || activeWorkflowRows.length !== 0) {
    throw new WorkflowError(
      "failed-precondition",
      "An Operations obligation is still active for this issue.",
      {reasonCode: "maintenance-ticket-coordination-projection-diverged"},
    );
  }
  if (!projection.projected) return;
  if (workflowId == null || complianceId == null ||
      workflowSnapshot?.exists !== true || workflowSnapshot.data == null ||
      projectedComplianceSnapshot?.exists !== true ||
      projectedComplianceSnapshot.data == null ||
      workflowSnapshot.data.workflowKind !== "issueCoordination" ||
      workflowSnapshot.data.linkedMaintenanceFirestoreId !== args.ticketId ||
      projectedComplianceSnapshot.data.linkedWorkflowId !== workflowId ||
      projectedComplianceSnapshot.data.linkedMaintenanceFirestoreId !==
        args.ticketId ||
      !TERMINAL_WORKFLOW_STATUSES.has(String(workflowSnapshot.data.status)) ||
      !TERMINAL_COMPLIANCE_STATUSES.has(
        String(projectedComplianceSnapshot.data.status),
      )) {
    throw new WorkflowError(
      "failed-precondition",
      "Released Operations coordination evidence is incomplete or contradictory.",
      {reasonCode: "maintenance-ticket-coordination-release-invalid"},
    );
  }
};

const requireVacantAudit = async (
  tx: WorkflowTransaction,
  commandId: string,
): Promise<void> => {
  const existing = await tx.get(auditPath(commandId));
  if (existing.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket audit identity is already occupied.",
      {reasonCode: "maintenance-ticket-audit-collision"},
    );
  }
};

const writeAudit = (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  at: Date;
  reason: string;
  summary: string;
  severity: "low" | "medium";
  before: JsonMap;
  after: JsonMap;
  resultVersion: number;
  action?: "create" | "update";
}): string => {
  const id = auditId(args.command.commandId);
  args.tx.create(auditPath(args.command.commandId), {
    schemaVersion: 1,
    auditId: id,
    entityType: "maintenance",
    entityId: args.command.aggregateId,
    action: args.action ?? "update",
    operation: args.command.commandType,
    performedByUid: args.actor.uid,
    performedByName: args.actor.name,
    timestamp: iso(args.at),
    reason: args.command.commandType === "correctMaintenanceTicket" ?
      "manualOverride" : "other",
    reasonNotes: args.reason,
    summary: args.summary,
    severity: args.severity,
    beforeJson: stableJson(args.before),
    afterJson: stableJson(args.after),
    requestId: args.command.commandId,
    resultVersion: args.resultVersion,
  });
  return id;
};

export const createMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["ticket"], "payload");
  if (command.expectedVersion !== 0 || command.aggregateId.length > 160 ||
      command.aggregateId.includes("/")) {
    throw new WorkflowError(
      "invalid-argument",
      "Maintenance ticket creation requires a new valid aggregate identity.",
      {reasonCode: "maintenance-ticket-create-envelope-invalid"},
    );
  }
  const input = record(command.payload.ticket, "ticket");
  const burner = input.classification === BURNER_LOCKOUT_CLASSIFICATION;
  const stuckup = input.classification === FURNACE_STUCKUP_CLASSIFICATION;
  const hasFrequentIssueSelection = Object.prototype.hasOwnProperty.call(
    input,
    FREQUENT_ISSUE_SELECTION_FIELD,
  );
  const hasLanePlan = TICKET_LANE_FIELDS.some((field) =>
    Object.prototype.hasOwnProperty.call(input, field));
  const hasQualityAbnormalityType = Object.prototype.hasOwnProperty.call(
    input,
    QUALITY_ABNORMALITY_TYPE_FIELD,
  );
  const hasPlantConditionEffect = Object.prototype.hasOwnProperty.call(
    input,
    PLANT_CONDITION_EFFECT_FIELD,
  );
  const hasLegacyEmptyCompletionEvidence =
    hasLegacyEmptyLaneCompletionEvidence(input);
  exactKeys(
    input,
    burner ? [...CREATE_TICKET_FIELDS,
      ...(hasQualityAbnormalityType ? [QUALITY_ABNORMALITY_TYPE_FIELD] : []),
      ...(hasPlantConditionEffect ? [PLANT_CONDITION_EFFECT_FIELD] : []),
      ...CREATE_BURNER_FIELDS,
      ...(hasLanePlan ? TICKET_LANE_FIELDS : []),
      ...(hasLegacyEmptyCompletionEvidence ?
        [LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD] : []),
      ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])] :
      stuckup ? [...CREATE_TICKET_FIELDS,
        ...(hasQualityAbnormalityType ? [QUALITY_ABNORMALITY_TYPE_FIELD] : []),
        ...(hasPlantConditionEffect ? [PLANT_CONDITION_EFFECT_FIELD] : []),
        ...CREATE_STUCKUP_FIELDS,
        ...(hasLanePlan ? TICKET_LANE_FIELDS : []),
        ...(hasLegacyEmptyCompletionEvidence ?
          [LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD] : []),
        ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])] :
        [...CREATE_TICKET_FIELDS,
          ...(hasQualityAbnormalityType ? [QUALITY_ABNORMALITY_TYPE_FIELD] : []),
          ...(hasPlantConditionEffect ? [PLANT_CONDITION_EFFECT_FIELD] : []),
          ...(hasLanePlan ? TICKET_LANE_FIELDS : []),
          ...(hasLegacyEmptyCompletionEvidence ?
            [LEGACY_EMPTY_LANE_COMPLETION_EVIDENCE_FIELD] : []),
          ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])],
    "ticket",
  );
  const requestedFrequentIssueSelection = hasFrequentIssueSelection ?
    parseFrequentIssueSelectionShape(input.frequentIssueSelection) : null;
  if (input.schemaVersion !== 1) {
    throw new WorkflowError("invalid-argument", "ticket schemaVersion is unsupported.");
  }
  const version = requiredInteger(input.version, "version", 1, 2147483647);
  if (version !== 1) {
    throw new WorkflowError(
      "invalid-argument",
      "A new maintenance ticket must begin at version 1.",
      {reasonCode: "maintenance-ticket-create-version-invalid"},
    );
  }
  const assetType = cleanText(input.assetType, "assetType");
  if (!ASSET_TYPES.has(assetType)) {
    throw new WorkflowError("invalid-argument", "assetType is unsupported.");
  }
  const assetNumber = requiredInteger(input.assetNumber, "assetNumber", 1, 9999);
  const maintenanceType = cleanText(input.maintenanceType, "maintenanceType");
  if (!MAINTENANCE_TYPES.has(maintenanceType)) {
    throw new WorkflowError("invalid-argument", "maintenanceType is unsupported.");
  }
  const routedTo = cleanText(input.routedTo, "routedTo");
  if (!ROUTES.has(routedTo)) {
    throw new WorkflowError("invalid-argument", "routedTo is unsupported.");
  }
  const lanePlan = createTicketLanePlan(input, routedTo);
  const otherDepartment = optionalBoundedText(
    input.otherDepartment,
    "otherDepartment",
    1,
    80,
  );
  if ((lanePlan.assigned.includes("others")) !== (otherDepartment != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required only when the issue route is Others.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  const component = boundedText(input.component, "component", 1, 120);
  const subsystem = optionalText(input.subsystem, "subsystem", 200);
  const tag = optionalText(input.tag, "tag", 160)?.toUpperCase() ?? null;
  optionalStringList(input.hierarchyPath, "hierarchyPath", 20, 200);
  const classification = optionalText(input.classification, "classification", 120);
  const description = boundedText(input.description, "description", 1, 2000);
  const requestedPlantConditionEffect = hasPlantConditionEffect ?
    cleanText(input.plantConditionEffect, "plantConditionEffect") : null;
  const plantConditionEffect = stuckup ?
    "stuckUp" : requestedPlantConditionEffect ?? "unfit";
  if ((stuckup && requestedPlantConditionEffect != null &&
        requestedPlantConditionEffect !== "stuckUp") ||
      (!stuckup && !PLANT_CONDITION_EFFECTS.has(plantConditionEffect))) {
    throw new WorkflowError(
      "invalid-argument",
      "The maintenance issue Plant Condition effect is invalid.",
      {reasonCode: "maintenance-ticket-plant-condition-effect-invalid"},
    );
  }
  const isCritical = requiredBoolean(input.isCritical, "isCritical");
  const startDate = parseIsoInstant(input.startDate, "startDate", context.serverNow);
  const chargeNoAtEvent = input.chargeNoAtEvent == null ? null :
    requiredInteger(input.chargeNoAtEvent, "chargeNoAtEvent", 10000, 99999);
  if (chargeNoAtEvent != null && !isFiveDigitChargeNumber(chargeNoAtEvent)) {
    throw new WorkflowError(
      "invalid-argument",
      "chargeNoAtEvent must contain exactly five digits.",
      {reasonCode: "charge-number-invalid", field: "chargeNoAtEvent"},
    );
  }
  if ((input.qualityIntentSchemaVersion !== 1 &&
        input.qualityIntentSchemaVersion !== 2) ||
      typeof input.qualityImpactAssessment !== "string" ||
      !QUALITY_ASSESSMENTS.has(input.qualityImpactAssessment)) {
    throw new WorkflowError(
      "invalid-argument",
      "The issue quality assessment is invalid.",
      {reasonCode: "maintenance-ticket-quality-intent-invalid"},
    );
  }
  const qualityWarningReason = optionalText(
    input.qualityWarningReason,
    "qualityWarningReason",
    1000,
  );
  const suspected = input.qualityImpactAssessment === "suspected";
  const qualityAbnormalityTypeId = hasQualityAbnormalityType ?
    optionalBoundedText(
      input.qualityAbnormalityTypeId,
      "qualityAbnormalityTypeId",
      1,
      512,
    ) : null;
  if (suspected ?
    (qualityWarningReason == null ||
      chargeNoAtEvent == null) : qualityWarningReason != null) {
    throw new WorkflowError(
      "invalid-argument",
      "Suspected quality impact requires charge and warning-reason evidence.",
      {reasonCode: "maintenance-ticket-quality-evidence-invalid"},
    );
  }
  if ((input.qualityIntentSchemaVersion === 1 &&
        hasQualityAbnormalityType) ||
      (input.qualityIntentSchemaVersion === 2 &&
        !hasQualityAbnormalityType) ||
      (suspected && (input.qualityIntentSchemaVersion !== 2 ||
        qualityAbnormalityTypeId == null)) ||
      (!suspected && qualityAbnormalityTypeId != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Suspected quality impact requires a governed abnormality classification.",
      {reasonCode: "maintenance-ticket-quality-classification-invalid"},
    );
  }

  const burnerFieldsPresent = CREATE_BURNER_FIELDS.some((field) =>
    Object.prototype.hasOwnProperty.call(input, field));
  let burnerFields: JsonMap = {};
  if (burner) {
    const positions = input.burnerPositions;
    const redHot = input.burnerRedHotPositions;
    if (input.burnerLockoutSchemaVersion !== 1 ||
        assetType !== "furnace" || maintenanceType !== "breakdown" ||
        routedTo !== "instrumentation" ||
        !lanePlan.assigned.includes("instrumentation") ||
        component !== "Burner system" ||
        tag != null || !isValidBurnerPositionList(positions, false) ||
        !isValidBurnerPositionList(redHot, true) ||
        !redHot.every((position) => positions.includes(position)) ||
        typeof input.burnerCommonMode !== "boolean" ||
        (input.burnerCommonMode === true && positions.length < 2) ||
        typeof input.burnerCycleStage !== "string" ||
        !BURNER_CYCLE_STAGES.has(input.burnerCycleStage) ||
        optionalText(input.burnerHmiAlarm, "burnerHmiAlarm", 300) !==
          (input.burnerHmiAlarm ?? null) ||
        typeof input.burnerFlameObservation !== "string" ||
        !BURNER_OBSERVATIONS.has(input.burnerFlameObservation) ||
        typeof input.burnerSparkObservation !== "string" ||
        !BURNER_OBSERVATIONS.has(input.burnerSparkObservation) ||
        !Number.isSafeInteger(input.burnerRelightAttempts) ||
        (input.burnerRelightAttempts as number) < 0 ||
        (input.burnerRelightAttempts as number) > 20 ||
        typeof input.burnerRemainsLockedOut !== "boolean" ||
        !Array.isArray(input.burnerAttendedPositions) ||
        input.burnerAttendedPositions.length !== 0 ||
        input.burnerResolutionEvidence == null ||
        typeof input.burnerResolutionEvidence !== "object" ||
        Array.isArray(input.burnerResolutionEvidence) ||
        Object.keys(input.burnerResolutionEvidence as JsonMap).length !== 0 ||
        (redHot.length > 0 && !isCritical)) {
      throw new WorkflowError(
        "invalid-argument",
        "The burner-lockout issue evidence is invalid.",
        {reasonCode: "maintenance-ticket-burner-evidence-invalid"},
      );
    }
    burnerFields = {
      burnerLockoutSchemaVersion: 1,
      burnerPositions: [...positions],
      burnerCommonMode: input.burnerCommonMode as boolean,
      burnerCycleStage: input.burnerCycleStage as string,
      burnerHmiAlarm: optionalText(input.burnerHmiAlarm, "burnerHmiAlarm", 300),
      burnerFlameObservation: input.burnerFlameObservation as string,
      burnerSparkObservation: input.burnerSparkObservation as string,
      burnerRelightAttempts: input.burnerRelightAttempts as number,
      burnerRemainsLockedOut: input.burnerRemainsLockedOut as boolean,
      burnerRedHotPositions: [...redHot],
      burnerAttendedPositions: [],
      burnerResolutionEvidence: {},
    };
  } else if (burnerFieldsPresent) {
    throw new WorkflowError(
      "invalid-argument",
      "Burner evidence requires the burner-lockout classification.",
      {reasonCode: "maintenance-ticket-burner-evidence-unscoped"},
    );
  }

  const stuckupFieldsPresent = CREATE_STUCKUP_FIELDS.some((field) =>
    Object.prototype.hasOwnProperty.call(input, field));
  let stuckupBaseNumber: number | null = null;
  let stuckupSuspectedCause: string | null = null;
  let stuckupOperatingContext: string | null = null;
  if (stuckup) {
    stuckupBaseNumber = requiredInteger(
      input.stuckupBaseNumber,
      "stuckupBaseNumber",
      1,
      9999,
    );
    stuckupSuspectedCause = cleanText(
      input.stuckupSuspectedCause,
      "stuckupSuspectedCause",
    );
    stuckupOperatingContext = cleanText(
      input.stuckupOperatingContext,
      "stuckupOperatingContext",
    );
    if (input.furnaceStuckupSchemaVersion !== 1 ||
        assetType !== "furnace" || maintenanceType !== "breakdown" ||
        routedTo !== "mechanical" ||
        !lanePlan.assigned.includes("mechanical") ||
        component !== "Furnace / Inner Cover interface" ||
        tag != null || !STUCKUP_CAUSES.has(stuckupSuspectedCause) ||
        !STUCKUP_CONTEXTS.has(stuckupOperatingContext)) {
      throw new WorkflowError(
        "invalid-argument",
        "The Furnace stuck-up issue evidence is invalid.",
        {reasonCode: "maintenance-ticket-stuckup-evidence-invalid"},
      );
    }
  } else if (stuckupFieldsPresent) {
    throw new WorkflowError(
      "invalid-argument",
      "Furnace stuck-up evidence requires its governed classification.",
      {reasonCode: "maintenance-ticket-stuckup-evidence-unscoped"},
    );
  }

  const timestamp = iso(context.serverNow);
  const assetHierarchyRefJson = await requireFreshAssetReference({
    tx,
    raw: input.assetHierarchyRefJson,
    assetType,
    assetNumber,
    tag,
    startDate,
    actor: context.actor,
    serverNow: context.serverNow,
  });
  const canonicalAssetReference = JSON.parse(assetHierarchyRefJson) as JsonMap;
  const baseInnerCoverUnavailable =
    classification === BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION;
  if (baseInnerCoverUnavailable) {
    const association = canonicalAssetReference.innerCoverAssociation;
    const validVacantAssociation = association != null &&
      typeof association === "object" && !Array.isArray(association) &&
      (association as JsonMap).positionState === "noneLinked" &&
      (association as JsonMap).baseAssetInstanceId ===
        canonicalAssetReference.assetInstanceId &&
      (association as JsonMap).baseAssetNumber === assetNumber;
    if (assetType !== "base" ||
        canonicalAssetReference.scope !== "physicalAsset" ||
        component !== BASE_INNER_COVER_AVAILABILITY_COMPONENT ||
        subsystem !== BASE_INNER_COVER_AVAILABILITY_SUBSYSTEM ||
        tag != null || plantConditionEffect !== "unavailable" ||
        hasFrequentIssueSelection || !validVacantAssociation) {
      throw new WorkflowError(
        "failed-precondition",
        "An Inner Cover availability issue requires an exact Base with no Inner Cover currently linked.",
        {reasonCode: "maintenance-ticket-inner-cover-availability-invalid"},
      );
    }
    await requireBaseVacantAtIssueStart({
      tx,
      baseAssetInstanceId: cleanText(
        canonicalAssetReference.assetInstanceId,
        "assetInstanceId",
      ),
      baseAssetNumber: assetNumber,
      startDate,
    });
  }
  const qualityAbnormalityId = suspected ?
    `issue_quality_${command.aggregateId}` : null;
  const warningId = `issue_${command.aggregateId}`;
  const qualityType = suspected ? canonicalQualityAbnormalityType({
    snapshot: await tx.get(
      `abnormality_types/${qualityAbnormalityTypeId as string}`,
    ),
    typeId: qualityAbnormalityTypeId as string,
    assetType,
  }) : null;
  const frequentIssueSelection = await resolveFrequentIssueSelection({
    tx,
    selection: requestedFrequentIssueSelection,
    assetType,
    assetClassId: cleanText(
      canonicalAssetReference.assetClassId,
      "assetClassId",
    ),
    componentNodeId: cleanText(canonicalAssetReference.nodeId, "nodeId"),
    classification,
    chargeNoAtEvent,
    burnerHmiAlarm: burner ?
      optionalText(input.burnerHmiAlarm, "burnerHmiAlarm", 300) : null,
    isStuckup: stuckup,
  });
  const hierarchyPath = persistedStringList(
    canonicalAssetReference.hierarchyPath,
    "hierarchyPath",
    20,
    200,
  );
  let canonicalStuckupBaseReference: string | null = null;
  let stuckupBaseReference: JsonMap | null = null;
  let stuckupInnerCoverAssociation: JsonMap | null = null;
  if (stuckup) {
    canonicalStuckupBaseReference = await requireFreshAssetReference({
      tx,
      raw: input.stuckupBaseAssetRefJson,
      assetType: "base",
      assetNumber: stuckupBaseNumber!,
      tag: null,
      startDate,
      actor: context.actor,
      serverNow: context.serverNow,
    });
    stuckupBaseReference = JSON.parse(
      canonicalStuckupBaseReference,
    ) as JsonMap;
    const association = stuckupBaseReference.innerCoverAssociation;
    if (association == null || typeof association !== "object" ||
        Array.isArray(association) ||
        (association as JsonMap).positionState !== "linked" ||
        typeof (association as JsonMap).innerCoverId !== "string" ||
        typeof (association as JsonMap).innerCoverSerialNumber !== "string") {
      throw new WorkflowError(
        "failed-precondition",
        "A Furnace stuck-up requires the exact Inner Cover currently linked to the Base.",
        {reasonCode: "furnace-stuckup-inner-cover-not-linked"},
      );
    }
    const requestedReference = JSON.parse(
      input.stuckupBaseAssetRefJson as string,
    ) as JsonMap;
    const requestedAssociation = requestedReference.innerCoverAssociation;
    if (requestedAssociation == null ||
        typeof requestedAssociation !== "object" ||
        Array.isArray(requestedAssociation) ||
        (requestedAssociation as JsonMap).positionState !== "linked" ||
        (requestedAssociation as JsonMap).baseAssetInstanceId !==
          (association as JsonMap).baseAssetInstanceId ||
        (requestedAssociation as JsonMap).baseAssetNumber !==
          (association as JsonMap).baseAssetNumber ||
        (requestedAssociation as JsonMap).innerCoverId !==
          (association as JsonMap).innerCoverId ||
        (requestedAssociation as JsonMap).innerCoverSerialNumber !==
          (association as JsonMap).innerCoverSerialNumber ||
        (requestedAssociation as JsonMap).linkageId !==
          (association as JsonMap).linkageId ||
        (requestedAssociation as JsonMap).assignmentVersion !==
          (association as JsonMap).assignmentVersion) {
      throw new WorkflowError(
        "aborted",
        "The Base-to-Inner-Cover pairing changed after physical confirmation. Reconfirm the installed cover before submitting.",
        {reasonCode: "furnace-stuckup-inner-cover-confirmation-stale"},
      );
    }
    stuckupInnerCoverAssociation = association as JsonMap;
  }
  const ticket: JsonMap = {
    firestoreId: command.aggregateId,
    version,
    assetType,
    assetNumber,
    component,
    subsystem,
    tag,
    hierarchyPath,
    assetHierarchyRefJson,
    maintenanceType,
    classification,
    description,
    plantConditionEffect,
    routedTo,
    otherDepartment,
    status: "open",
    isResolved: false,
    isCritical,
    loggedByUid: context.actor.uid,
    loggedByName: context.actor.name,
    reportedBy: context.actor.name,
    acknowledgedByUid: null,
    acknowledgedByName: null,
    acknowledgedAt: null,
    ...ticketLaneProjection(lanePlan),
    closedByUid: null,
    closedByName: null,
    teamsInvolved: [],
    performedBy: null,
    remarks: null,
    startDate,
    endDate: null,
    downtimeHours: null,
    chargeNoAtEvent,
    createdAt: timestamp,
    updatedAt: timestamp,
    metadataJson: null,
    actionsJson: "[]",
    resolutionHistoryJson: "[]",
    qualityIntentSchemaVersion: input.qualityIntentSchemaVersion as number,
    qualityImpactAssessment: input.qualityImpactAssessment as string,
    qualityWarningReason,
    ...(hasQualityAbnormalityType ? {qualityAbnormalityTypeId} : {}),
    qualityAbnormalityId,
    qualityWarningId: suspected ? warningId : null,
    chargeQualityCaseId: suspected ? `issue_${command.aggregateId}` : null,
    ...(frequentIssueSelection == null ? {} : {frequentIssueSelection}),
    ...burnerFields,
    ...(stuckup ? {
      furnaceStuckupSchemaVersion: 1,
      stuckupBaseNumber,
      stuckupBaseAssetRefJson: canonicalStuckupBaseReference,
      stuckupSuspectedCause,
      stuckupOperatingContext,
    } : {}),
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
  };
  const warning = qualityWarningProjection({
    ticketId: command.aggregateId,
    ticket,
    actor: context.actor,
    timestamp,
  });
  const abnormality = qualityType == null || qualityAbnormalityId == null ?
    null : qualityAbnormalityProjection({
      abnormalityId: qualityAbnormalityId,
      ticketId: command.aggregateId,
      ticket,
      type: qualityType,
      actor: context.actor,
      timestamp,
    });
  const directive = redHotDirectiveProjection({
    ticketId: command.aggregateId,
    ticket,
    actor: context.actor,
    timestamp,
  });
  const directiveId = `burner_red_hot_${command.aggregateId}`;
  const reviewQueueId = frequentIssueSelection?.selectionType === "unlisted" ?
    command.aggregateId : null;
  const [
    existingTicket,
    existingWarning,
    existingAbnormality,
    existingDirective,
    existingReview,
  ] =
    await Promise.all([
    tx.get(maintenancePath(command.aggregateId)),
    tx.get(`quality_warnings/${warningId}`),
    tx.get(`charge_abnormalities/issue_quality_${command.aggregateId}`),
    tx.get(`directives/${directiveId}`),
    tx.get(`issue_governance_review_queue/${command.aggregateId}`),
  ]);
  if (existingTicket.exists || existingWarning.exists ||
      existingAbnormality.exists || existingDirective.exists ||
      existingReview.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance issue evidence already exists without this command receipt.",
      {reasonCode: "maintenance-ticket-create-orphan-evidence"},
    );
  }
  await requireVacantAudit(tx, command.commandId);
  let stuckupCaseId: string | null = null;
  if (stuckup) {
    stuckupCaseId = command.aggregateId;
    const furnaceAssetId = cleanText(
      canonicalAssetReference.assetInstanceId,
      "furnace.assetInstanceId",
    );
    const furnaceAssetClassId = cleanText(
      canonicalAssetReference.assetClassId,
      "furnace.assetClassId",
    );
    const baseAssetId = cleanText(
      stuckupBaseReference!.assetInstanceId,
      "base.assetInstanceId",
    );
    const baseAssetClassId = cleanText(
      stuckupBaseReference!.assetClassId,
      "base.assetClassId",
    );
    const innerCoverId = cleanText(
      stuckupInnerCoverAssociation!.innerCoverId,
      "innerCoverId",
    );
    const innerCoverSerialNumber = cleanText(
      stuckupInnerCoverAssociation!.innerCoverSerialNumber,
      "innerCoverSerialNumber",
    );
    const caseDocPath = `furnace_stuckup_cases/${stuckupCaseId}`;
    const baseConstraintId = `${stuckupCaseId}_${baseAssetId}`;
    const furnaceConstraintId = `${stuckupCaseId}_${furnaceAssetId}`;
    const [
      existingCase,
      existingBaseConstraint,
      existingFurnaceConstraint,
      baseCurrent,
      furnaceCurrent,
    ] = await Promise.all([
      tx.get(caseDocPath),
      tx.get(`asset_availability_constraints/${baseConstraintId}`),
      tx.get(`asset_availability_constraints/${furnaceConstraintId}`),
      tx.get(`asset_availability_current/${baseAssetId}`),
      tx.get(`asset_availability_current/${furnaceAssetId}`),
    ]);
    if (existingCase.exists || existingBaseConstraint.exists ||
        existingFurnaceConstraint.exists) {
      throw new WorkflowError(
        "failed-precondition",
        "Furnace stuck-up evidence already exists without this command receipt.",
        {reasonCode: "furnace-stuckup-create-orphan-evidence"},
      );
    }
    for (const current of [baseCurrent, furnaceCurrent]) {
      if (current.exists &&
          (current.data == null || current.data.schemaVersion !== 1 ||
            !Number.isSafeInteger(current.data.version) ||
            (current.data.version as number) < 1 ||
            current.data.availabilityState !== "clear" ||
            current.data.activeConstraintId != null)) {
        throw new WorkflowError(
          "failed-precondition",
          "An affected asset already has an active or malformed availability constraint.",
          {reasonCode: "asset-availability-current-conflict"},
        );
      }
    }
    const stuckupCase: JsonMap = {
      schemaVersion: 1,
      caseId: stuckupCaseId,
      ticketId: command.aggregateId,
      version: 1,
      obstructionStatus: "active",
      adjudicationStatus: "pending",
      suspectedCause: stuckupSuspectedCause,
      confirmedCause: null,
      adjudicationNotes: null,
      conditionDeclarationId: null,
      conditionEvidenceId: null,
      furnaceAssetClassId,
      furnaceAssetInstanceId: furnaceAssetId,
      furnaceAssetNumber: assetNumber,
      furnaceAssetRefJson: assetHierarchyRefJson,
      baseAssetClassId,
      baseAssetInstanceId: baseAssetId,
      baseAssetNumber: stuckupBaseNumber,
      baseAssetRefJson: canonicalStuckupBaseReference,
      innerCoverId,
      innerCoverSerialNumber,
      innerCoverLinkageId: stuckupInnerCoverAssociation!.linkageId,
      innerCoverAssignmentVersion:
        stuckupInnerCoverAssociation!.assignmentVersion,
      operatingContext: stuckupOperatingContext,
      chargeNoAtEvent,
      reportedAt: startDate,
      reportedByUid: context.actor.uid,
      reportedByName: context.actor.name,
      releasedAt: null,
      releasedByUid: null,
      releasedByName: null,
      releaseNotes: null,
      adjudicatedAt: null,
      adjudicatedByUid: null,
      adjudicatedByName: null,
      createdAt: timestamp,
      updatedAt: timestamp,
    };
    tx.create(caseDocPath, stuckupCase);
    const constraint = (args: {
      constraintId: string;
      assetType: string;
      assetClassId: string;
      assetInstanceId: string;
      assetNumber: number;
      counterpartLabel: string;
    }): JsonMap => ({
      schemaVersion: 1,
      constraintId: args.constraintId,
      caseId: stuckupCaseId,
      ticketId: command.aggregateId,
      constraintType: "furnaceStuckup",
      status: "active",
      assetType: args.assetType,
      assetClassId: args.assetClassId,
      assetInstanceId: args.assetInstanceId,
      assetNumber: args.assetNumber,
      counterpartLabel: args.counterpartLabel,
      since: startDate,
      createdAt: timestamp,
      createdByUid: context.actor.uid,
      createdByName: context.actor.name,
      releasedAt: null,
      releasedByUid: null,
      releasedByName: null,
      version: 1,
      updatedAt: timestamp,
    });
    const baseConstraint = constraint({
      constraintId: baseConstraintId,
      assetType: "base",
      assetClassId: baseAssetClassId,
      assetInstanceId: baseAssetId,
      assetNumber: stuckupBaseNumber!,
      counterpartLabel: `Furnace ${assetNumber}`,
    });
    const furnaceConstraint = constraint({
      constraintId: furnaceConstraintId,
      assetType: "furnace",
      assetClassId: furnaceAssetClassId,
      assetInstanceId: furnaceAssetId,
      assetNumber,
      counterpartLabel: `Base ${stuckupBaseNumber}`,
    });
    tx.create(`asset_availability_constraints/${baseConstraintId}`, baseConstraint);
    tx.create(
      `asset_availability_constraints/${furnaceConstraintId}`,
      furnaceConstraint,
    );
    const setCurrent = (args: {
      existing: typeof baseCurrent;
      assetType: string;
      assetClassId: string;
      assetInstanceId: string;
      assetNumber: number;
      constraintId: string;
    }): void => tx.set(`asset_availability_current/${args.assetInstanceId}`, {
      schemaVersion: 1,
      assetType: args.assetType,
      assetClassId: args.assetClassId,
      assetInstanceId: args.assetInstanceId,
      assetNumber: args.assetNumber,
      availabilityState: "temporarilyBlocked",
      activeConstraintId: args.constraintId,
      reasonType: "furnaceStuckup",
      linkedCaseId: stuckupCaseId,
      linkedTicketId: command.aggregateId,
      since: startDate,
      updatedAt: timestamp,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
      version: args.existing.exists ?
        (args.existing.data!.version as number) + 1 : 1,
    });
    setCurrent({
      existing: baseCurrent,
      assetType: "base",
      assetClassId: baseAssetClassId,
      assetInstanceId: baseAssetId,
      assetNumber: stuckupBaseNumber!,
      constraintId: baseConstraintId,
    });
    setCurrent({
      existing: furnaceCurrent,
      assetType: "furnace",
      assetClassId: furnaceAssetClassId,
      assetInstanceId: furnaceAssetId,
      assetNumber,
      constraintId: furnaceConstraintId,
    });
  }
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: "Maintenance issue created through the governed command boundary.",
    summary: "Maintenance issue created",
    severity: isCritical ? "medium" : "low",
    before: {},
    after: ticket,
    resultVersion: version,
    action: "create",
  });
  tx.create(maintenancePath(command.aggregateId), ticket);
  if (reviewQueueId != null) {
    tx.create(`issue_governance_review_queue/${reviewQueueId}`, {
      schemaVersion: 1,
      reviewId: reviewQueueId,
      ticketId: command.aggregateId,
      status: "open",
      assetType,
      assetNumber,
      assetClassId: canonicalAssetReference.assetClassId as string,
      componentNodeId: canonicalAssetReference.nodeId as string,
      component,
      description,
      unlistedReason: frequentIssueSelection!.unlistedReason as string,
      raisedByUid: context.actor.uid,
      raisedByName: context.actor.name,
      raisedAt: timestamp,
      reviewedAt: null,
      reviewedByUid: null,
      reviewedByName: null,
      linkedDefinitionId: null,
    });
  }
  if (warning != null) tx.create(`quality_warnings/${warningId}`, warning);
  if (abnormality != null && qualityAbnormalityId != null) {
    tx.create(`charge_abnormalities/${qualityAbnormalityId}`, abnormality);
  }
  if (directive != null) tx.create(`directives/${directiveId}`, directive);
  return {
    resultKey: "maintenance-ticket-created",
    aggregateVersion: version,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      warningId: warning == null ? null : warningId,
      abnormalityId: qualityAbnormalityId,
      directiveId: directive == null ? null : directiveId,
      stuckupCaseId,
      reviewQueueId,
    },
  };
};

export const acknowledgeMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  const payloadKeys = Object.keys(command.payload);
  if (payloadKeys.length !== 0) exactKeys(command.payload, ["lane"], "payload");
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  const plan = ticketLanePlan(ticket);
  const lane = payloadKeys.length === 0 ? plan.assigned[0] :
    cleanText(command.payload.lane, "lane");
  if (TERMINAL_TICKET_STATUSES.has(String(ticket.status)) ||
      !plan.assigned.includes(lane) ||
      plan.acknowledged.includes(lane)) {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active unacknowledged issue lane can be acknowledged.",
      {reasonCode: "maintenance-ticket-not-open-for-acknowledgement"},
    );
  }
  const nextPlan = {
    ...plan,
    acknowledged: [...plan.acknowledged, lane],
  };
  const nextVersion = version + 1;
  const update: JsonMap = {
    status: ticketLaneStatus(nextPlan),
    ...(plan.acknowledged.length === 0 ? {
      acknowledgedByUid: context.actor.uid,
      acknowledgedByName: context.actor.name,
      acknowledgedAt: iso(context.serverNow),
    } : {}),
    ...ticketLaneProjection(nextPlan),
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: `Maintenance issue lane ${lane} acknowledged by its receiving authority.`,
    summary: `Maintenance issue lane acknowledged: ${lane}`,
    severity: "low",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-acknowledged",
    aggregateVersion: nextVersion,
    result: {ticketId: command.aggregateId, auditId: id, lane},
  };
};

export const completeMaintenanceTicketLane = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["lane"], "payload");
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  const plan = ticketLanePlan(ticket);
  const lane = cleanText(command.payload.lane, "lane");
  if (TERMINAL_TICKET_STATUSES.has(String(ticket.status)) ||
      !plan.assigned.includes(lane) ||
      !plan.acknowledged.includes(lane) || plan.completed.includes(lane)) {
    throw new WorkflowError(
      "failed-precondition",
      "Only an acknowledged active issue lane can be completed.",
      {reasonCode: "maintenance-ticket-lane-not-ready-for-completion"},
    );
  }
  const nextPlan = {
    ...plan,
    completed: [...plan.completed, lane],
    completionEvidence: {
      ...plan.completionEvidence,
      [lane]: {
        completedAt: iso(context.serverNow),
        completedByUid: context.actor.uid,
        completedByName: context.actor.name,
      },
    },
  };
  const nextVersion = version + 1;
  const update: JsonMap = {
    status: ticketLaneStatus(nextPlan),
    ...ticketLaneProjection(nextPlan),
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: `Maintenance issue lane ${lane} marked complete by its closing authority.`,
    summary: `Maintenance issue lane completed: ${lane}`,
    severity: "low",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-lane-completed",
    aggregateVersion: nextVersion,
    result: {ticketId: command.aggregateId, auditId: id, lane},
  };
};

export const resolveMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  const hasActionTargetContract = Object.prototype.hasOwnProperty.call(
    command.payload,
    "actionTargetContractVersion",
  );
  exactKeys(
    command.payload,
    hasActionTargetContract ?
      [
        "endDate", "remarks", "teamsInvolved", "actionsJson",
        "actionTargetContractVersion",
      ] :
      ["endDate", "remarks", "teamsInvolved", "actionsJson"],
    "payload",
  );
  const actionTargetContractVersion = hasActionTargetContract ?
    requiredInteger(
      command.payload.actionTargetContractVersion,
      "actionTargetContractVersion",
      1,
      1,
    ) : null;
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  if (ticket.isResolved === true || ticket.status === "resolved") {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active maintenance issue can be resolved.",
      {reasonCode: "maintenance-ticket-not-open-for-resolution"},
    );
  }
  await requireReleasedTicketCoordination({
    tx,
    ticket,
    ticketId: command.aggregateId,
  });
  const plan = ticketLanePlan(ticket);
  const endDate = requiredInstantDate(command.payload.endDate, "endDate");
  const episodeStartedAt = currentMaintenanceEpisodeStart(ticket);
  if (endDate.getTime() < episodeStartedAt.getTime() ||
      endDate.getTime() > context.serverNow.getTime() + 5 * 60 * 1000) {
    throw new WorkflowError(
      "invalid-argument",
      "Resolution time must be between issue start and current server time.",
      {reasonCode: "maintenance-ticket-resolution-time-invalid"},
    );
  }
  const remarks = boundedText(command.payload.remarks, "remarks", 1, 4000);
  const teamsInvolved = closureTeams(
    command.payload.teamsInvolved,
    plan.assigned,
  );
  const requestedActions = closureActionPayload(command.payload.actionsJson);
  const actions = await canonicalGovernedClosureActions({
    tx,
    existingValue: ticket.actionsJson,
    assetType: ticket.assetType,
    assetNumber: ticket.assetNumber,
    workStartedAt: episodeStartedAt.toISOString(),
    requested: requestedActions,
    contractVersion: actionTargetContractVersion,
    actor: context.actor,
    serverNow: context.serverNow,
    endDate,
    allowBurnerEvidence:
      ticket.classification === BURNER_LOCKOUT_CLASSIFICATION,
  });
  const burner = burnerResolutionProjection(
    command.aggregateId,
    ticket,
    actions.rows,
  );
  if (burner != null && actions.rows.length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-lockout closure requires component-action evidence.",
      {reasonCode: "maintenance-ticket-burner-resolution-incomplete"},
    );
  }
  const lifecycleCompletedAt = endDate.toISOString();
  const burnerBlockLifecyclePlan = await prepareBurnerBlockLifecycleWritePlan({
    tx,
    sourceType: "maintenanceIssue",
    sourceId: command.aggregateId,
    assetType: ticket.assetType,
    assetNumber: ticket.assetNumber,
    actionSources: [{sourceModuleId: null, actionsJson: actions.text}],
    completedAt: lifecycleCompletedAt,
    recordedAt: lifecycleCompletedAt,
    completedBy: context.actor,
    executionLevelMechanicalEvidence: plan.assigned.includes("mechanical"),
  });
  const uvDetectorLifecyclePlan = await prepareUvDetectorLifecycleWritePlan({
    tx,
    sourceType: "maintenanceIssue",
    sourceId: command.aggregateId,
    sourceAssetReferenceJson: ticket.assetHierarchyRefJson,
    assetType: ticket.assetType,
    assetNumber: ticket.assetNumber,
    actionSources: [{sourceModuleId: null, actionsJson: actions.text}],
    completedAt: lifecycleCompletedAt,
    recordedAt: lifecycleCompletedAt,
    completedBy: context.actor,
    executionLevelInstrumentationEvidence:
      plan.assigned.includes("instrumentation"),
  });

  const nextPlan = {
    ...plan,
    acknowledged: [...plan.assigned],
    completed: [...plan.assigned],
    completionEvidence: Object.fromEntries(
      plan.assigned
        .filter((lane) =>
          plan.completionEvidence[lane] != null ||
          !plan.completed.includes(lane))
        .map((lane) => [
          lane,
          plan.completionEvidence[lane] ?? {
            completedAt: iso(context.serverNow),
            completedByUid: context.actor.uid,
            completedByName: context.actor.name,
          },
        ]),
    ),
  };
  const nextVersion = version + 1;
  const updatedAt = iso(context.serverNow);
  const update: JsonMap = {
    isResolved: true,
    status: "resolved",
    endDate: endDate.toISOString(),
    closedByUid: context.actor.uid,
    closedByName: context.actor.name,
    remarks,
    downtimeHours:
      (endDate.getTime() - episodeStartedAt.getTime()) / (60 * 60 * 1000),
    teamsInvolved,
    actionsJson: actions.text,
    ...ticketLaneProjection(nextPlan),
    ...(plan.acknowledged.length === 0 ? {
      acknowledgedByUid: context.actor.uid,
      acknowledgedByName: context.actor.name,
      acknowledgedAt: endDate.toISOString(),
    } : {}),
    ...(burner == null ? {} : {
      burnerAttendedPositions: burner.attended,
      burnerResolutionEvidence: burner.evidence,
    }),
    updatedAt,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: "Maintenance issue resolved through the governed command boundary.",
    summary: `Maintenance issue resolved across ${plan.assigned.length} lane(s)`,
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  applyBurnerBlockLifecycleWritePlan(tx, burnerBlockLifecyclePlan);
  applyUvDetectorLifecycleWritePlan(tx, uvDetectorLifecyclePlan);
  if (burner != null) {
    tx.set(`maintenance_burner_closures/${command.aggregateId}`, {
      firestoreId: command.aggregateId,
      sourceMaintenanceId: command.aggregateId,
      sourceVersion: nextVersion,
      closedByUid: context.actor.uid,
      burnerResolutionEvidence: burner.evidence,
      updatedAt,
    });
  }
  return {
    resultKey: "maintenance-ticket-resolved",
    aggregateVersion: nextVersion,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      completedLanes: [...plan.assigned],
    },
  };
};

export const closeMaintenanceTicketWithoutResolution = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["disposition", "reason"], "payload");
  const disposition = cleanText(command.payload.disposition, "disposition");
  if (!ADMINISTRATIVE_CLOSURE_DISPOSITIONS.has(disposition)) {
    throw new WorkflowError(
      "invalid-argument",
      "Administrative closure disposition is unsupported.",
      {reasonCode: "maintenance-ticket-administrative-closure-disposition-invalid"},
    );
  }
  const reason = boundedText(command.payload.reason, "reason", 1, 2000);
  const {ticket, version} = await requireTicket(tx, command, {
    allowDeferred: true,
  });
  await requireVacantAudit(tx, command.commandId);
  if (ticket.isResolved === true ||
      TERMINAL_TICKET_STATUSES.has(String(ticket.status))) {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active maintenance issue can be closed without resolution.",
      {reasonCode: "maintenance-ticket-not-open-for-administrative-closure"},
    );
  }
  const lanePlan = ticketLanePlan(ticket);
  const episodeStartedAt = currentMaintenanceEpisodeStart(ticket);
  if (context.serverNow.getTime() < episodeStartedAt.getTime()) {
    throw new WorkflowError(
      "failed-precondition",
      "The issue start time is later than the server closure time.",
      {reasonCode: "maintenance-ticket-administrative-closure-time-invalid"},
    );
  }

  const projection = ticketWorkflowProjection(ticket);
  const {queueState, workflowId, complianceId} = projection;
  const [complianceRows, workflowRows, workflowSnapshot,
    projectedComplianceSnapshot] = await Promise.all([
    tx.query("compliance_requests", [
      {
        field: "linkedMaintenanceFirestoreId",
        op: "==",
        value: command.aggregateId,
      },
    ]),
    tx.query("maintenance_workflows", [
      {
        field: "linkedMaintenanceFirestoreId",
        op: "==",
        value: command.aggregateId,
      },
    ]),
    workflowId == null ? Promise.resolve(null) : tx.get(workflowPath(workflowId)),
    complianceId == null ?
      Promise.resolve(null) : tx.get(compliancePath(complianceId)),
  ]);
  if (complianceRows.length > 50 || workflowRows.length > 50) {
    throw new WorkflowError(
      "failed-precondition",
      "Issue coordination history exceeds the governed closure boundary.",
      {
        reasonCode: "maintenance-ticket-coordination-history-oversized",
        complianceCount: complianceRows.length,
        workflowCount: workflowRows.length,
      },
    );
  }
  const activeComplianceRows = complianceRows.filter((row) =>
    !TERMINAL_COMPLIANCE_STATUSES.has(String(row.data?.status)));
  const activeWorkflowRows = workflowRows.filter((row) =>
    !TERMINAL_WORKFLOW_STATUSES.has(String(row.data?.status)));
  const hasActiveQueue = queueState !== "independent" && queueState !== "released";
  let cancelledWorkflowVersion: number | null = null;
  let cancelledComplianceVersion: number | null = null;
  if (hasActiveQueue) {
    if (workflowId == null || complianceId == null ||
        workflowSnapshot?.exists !== true || workflowSnapshot.data == null ||
        projectedComplianceSnapshot?.exists !== true ||
        projectedComplianceSnapshot.data == null ||
        activeComplianceRows.length !== 1 ||
        activeComplianceRows[0].path !== compliancePath(complianceId) ||
        activeWorkflowRows.length !== 1 ||
        activeWorkflowRows[0].path !== workflowPath(workflowId) ||
        projectedComplianceSnapshot.data.linkedWorkflowId !== workflowId ||
        projectedComplianceSnapshot.data.linkedMaintenanceFirestoreId !==
          command.aggregateId ||
        !ACTIVE_COMPLIANCE_STATUSES.has(
          String(projectedComplianceSnapshot.data.status),
        ) ||
        workflowSnapshot.data.workflowKind !== "issueCoordination" ||
        workflowSnapshot.data.linkedMaintenanceFirestoreId !==
          command.aggregateId ||
        workflowSnapshot.data.cancelled !== false ||
        !ACTIVE_WORKFLOW_STATUSES.has(String(workflowSnapshot.data.status)) ||
        !Number.isSafeInteger(workflowSnapshot.data.version) ||
        (workflowSnapshot.data.version as number) < 1 ||
        !Number.isSafeInteger(projectedComplianceSnapshot.data.version) ||
        (projectedComplianceSnapshot.data.version as number) < 1) {
      throw new WorkflowError(
        "failed-precondition",
        "Active Operations coordination is incomplete or contradictory.",
        {reasonCode: "maintenance-ticket-coordination-evidence-invalid"},
      );
    }
    cancelledWorkflowVersion = workflowSnapshot.data.version as number;
    cancelledComplianceVersion =
      projectedComplianceSnapshot.data.version as number;
  } else {
    if (activeComplianceRows.length !== 0 || activeWorkflowRows.length !== 0) {
      throw new WorkflowError(
        "failed-precondition",
        "An unprojected Operations obligation still exists for this issue.",
        {reasonCode: "maintenance-ticket-coordination-projection-diverged"},
      );
    }
    if (projection.projected &&
        (workflowId == null || complianceId == null ||
          workflowSnapshot?.exists !== true || workflowSnapshot.data == null ||
          projectedComplianceSnapshot?.exists !== true ||
          projectedComplianceSnapshot.data == null ||
          workflowSnapshot.data.workflowKind !== "issueCoordination" ||
          workflowSnapshot.data.linkedMaintenanceFirestoreId !==
            command.aggregateId ||
          projectedComplianceSnapshot.data.linkedWorkflowId !== workflowId ||
          projectedComplianceSnapshot.data.linkedMaintenanceFirestoreId !==
            command.aggregateId ||
          !TERMINAL_WORKFLOW_STATUSES.has(
            String(workflowSnapshot.data.status),
          ) ||
          !TERMINAL_COMPLIANCE_STATUSES.has(
            String(projectedComplianceSnapshot.data.status),
          ))) {
      throw new WorkflowError(
        "failed-precondition",
        "Released Operations coordination evidence is incomplete or contradictory.",
        {reasonCode: "maintenance-ticket-coordination-release-invalid"},
      );
    }
  }

  const nextVersion = version + 1;
  const updatedAt = iso(context.serverNow);
  const cancelledCoordination = hasActiveQueue;
  const update: JsonMap = {
    isResolved: true,
    status: "closedWithoutResolution",
    ...ticketLaneProjection(lanePlan),
    endDate: updatedAt,
    closedByUid: context.actor.uid,
    closedByName: context.actor.name,
    downtimeHours:
      (context.serverNow.getTime() - episodeStartedAt.getTime()) /
      (60 * 60 * 1000),
    issueClosureSchemaVersion: 1,
    issueClosureDisposition: disposition,
    issueClosureReason: reason,
    ...(workflowId == null ? {} : {
      workflowDeferred: false,
      workflowQueueState: "released",
      workflowReleasedAt: updatedAt,
      workflowReleasedByUid: context.actor.uid,
      workflowReleasedByName: context.actor.name,
      workflowCorrectionReason: null,
      workflowUpdatedAt: updatedAt,
    }),
    updatedAt,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const updatedTicket = {...ticket, ...update};
  if (workflowId == null) {
    for (const field of WORKFLOW_PROJECTION_FIELDS) delete updatedTicket[field];
  }
  const after = ticketSnapshot(updatedTicket);
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason,
    summary: disposition === "stillRelevant" ?
      "Maintenance issue closed without resolution; relevance retained" :
      "Maintenance issue closed without resolution; relevance ended",
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  if (cancelledCoordination) {
    if (workflowId == null || complianceId == null ||
        workflowSnapshot?.data == null ||
        projectedComplianceSnapshot?.data == null ||
        cancelledWorkflowVersion == null ||
        cancelledComplianceVersion == null) {
      throw new WorkflowError(
        "failed-precondition",
        "Active Operations coordination cannot be cancelled safely.",
        {reasonCode: "maintenance-ticket-coordination-evidence-invalid"},
      );
    }
    tx.update(compliancePath(complianceId), {
      status: "cancelled",
      nextEscalationAt: null,
      cancelledByUid: context.actor.uid,
      cancelledByName: context.actor.name,
      cancelledAt: updatedAt,
      cancellationReason: `Issue closed without resolution: ${reason}`,
      version: cancelledComplianceVersion + 1,
      updatedAt,
    });
    tx.update(workflowPath(workflowId), {
      status: "cancelled",
      cancelled: true,
      cancelledByUid: context.actor.uid,
      cancelledByName: context.actor.name,
      cancelledAt: updatedAt,
      cancellationReason: `Issue closed without resolution: ${reason}`,
      version: cancelledWorkflowVersion + 1,
      updatedAt,
    });
    const event = eventPlan({
      aggregateId: workflowId,
      eventId: command.commandId,
      eventType: "issue.closedWithoutResolution",
      actor: context.actor,
      at: context.serverNow,
      commandId: command.commandId,
      payload: {
        ticketId: command.aggregateId,
        complianceId,
        disposition,
        reason,
      },
    });
    tx.create(event.path, event.data);
  }
  if (workflowId == null) {
    tx.set(maintenancePath(command.aggregateId), updatedTicket);
  } else {
    tx.update(maintenancePath(command.aggregateId), update);
  }
  return {
    resultKey: "maintenance-ticket-closed-without-resolution",
    aggregateVersion: nextVersion,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      disposition,
      cancelledCoordination,
      cancelledWorkflowId: cancelledCoordination ? workflowId : null,
      cancelledComplianceId: cancelledCoordination ? complianceId : null,
    },
  };
};

export const reopenMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["remarks"], "payload");
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  if (ticket.isResolved !== true || ticket.status !== "resolved") {
    throw new WorkflowError(
      "failed-precondition",
      "Only a resolved maintenance issue can be reopened.",
      {reasonCode: "maintenance-ticket-not-closed-for-reopen"},
    );
  }
  const closedAt = requiredPersistedInstantDate(
    ticket.endDate,
    "ticket.endDate",
  );
  const elapsed = context.serverNow.getTime() - closedAt.getTime();
  if (elapsed < 0 || elapsed > 4 * 60 * 60 * 1000) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance issues may be reopened only within four hours of closure.",
      {reasonCode: "maintenance-ticket-reopen-window-expired"},
    );
  }
  const plan = ticketLanePlan(ticket);
  const reopenedPlan = {
    ...plan,
    acknowledged: [] as string[],
    completed: [] as string[],
    completionEvidence: {},
  };
  const remarks = optionalText(command.payload.remarks, "remarks", 4000);
  const resolutionHistoryJson =
    maintenanceResolutionHistoryWithCurrentClosure(ticket, {
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
      reason: remarks,
      byWorkflow: false,
    });
  const nextVersion = version + 1;
  const updatedAt = iso(context.serverNow);
  const update: JsonMap = {
    isResolved: false,
    status: "open",
    ...ticketLaneProjection(reopenedPlan),
    acknowledgedByUid: null,
    acknowledgedByName: null,
    acknowledgedAt: null,
    endDate: null,
    closedByUid: null,
    closedByName: null,
    downtimeHours: null,
    teamsInvolved: [],
    actionsJson: "[]",
    ...(ticket.classification === BURNER_LOCKOUT_CLASSIFICATION ? {
      burnerAttendedPositions: [],
      burnerResolutionEvidence: {},
    } : {}),
    remarks,
    resolutionHistoryJson,
    reopenedByUid: context.actor.uid,
    reopenedByName: context.actor.name,
    reopenedAt: updatedAt,
    reopenReason: remarks,
    updatedAt,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: remarks ?? "Maintenance issue reopened for further work.",
    summary: "Maintenance issue reopened",
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-reopened",
    aggregateVersion: nextVersion,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      assignedLanes: [...plan.assigned],
    },
  };
};

export const reconfigureMaintenanceTicketLanes = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["lanes", "otherDepartment", "reason"], "payload");
  const reason = boundedText(command.payload.reason, "reason", 1, 2000);
  const lanes = requestedTicketLanes(command.payload.lanes);
  const otherDepartment = optionalBoundedText(
    command.payload.otherDepartment,
    "otherDepartment",
    1,
    80,
  );
  if (lanes.includes("others") !== (otherDepartment != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required exactly when Others is an active lane.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  if (TERMINAL_TICKET_STATUSES.has(String(ticket.status))) {
    throw new WorkflowError(
      "failed-precondition",
      "A closed issue cannot have its accountable lanes changed.",
      {reasonCode: "maintenance-ticket-lanes-closed"},
    );
  }
  const queueState = typeof ticket.workflowQueueState === "string" ?
    ticket.workflowQueueState : "independent";
  if (queueState !== "independent" && queueState !== "released") {
    throw new WorkflowError(
      "failed-precondition",
      "Finish or release active Operations coordination before changing lanes.",
      {reasonCode: "maintenance-ticket-lanes-workflow-active"},
    );
  }
  if (ticket.classification === BURNER_LOCKOUT_CLASSIFICATION &&
      (lanes[0] !== "instrumentation" || !lanes.includes("instrumentation"))) {
    throw new WorkflowError(
      "failed-precondition",
      "Burner-lockout issues must retain I&A as their primary lane.",
      {reasonCode: "maintenance-burner-specialization-immutable"},
    );
  }
  if (ticket.classification === FURNACE_STUCKUP_CLASSIFICATION &&
      (lanes[0] !== "mechanical" || !lanes.includes("mechanical"))) {
    throw new WorkflowError(
      "failed-precondition",
      "Furnace stuck-up issues must retain Mechanical as their primary lane.",
      {reasonCode: "maintenance-stuckup-specialization-immutable"},
    );
  }
  const plan = ticketLanePlan(ticket);
  const selected = new Set(lanes);
  const nextPlan = {
    revision: plan.revision + 1,
    assigned: lanes,
    acknowledged: plan.acknowledged.filter((lane) => selected.has(lane)),
    completed: plan.completed.filter((lane) => selected.has(lane)),
    completionEvidence: Object.fromEntries(
      Object.entries(plan.completionEvidence)
        .filter(([lane]) => selected.has(lane) && plan.completed.includes(lane)),
    ),
  };
  if (JSON.stringify(plan.assigned) === JSON.stringify(lanes) &&
      (ticket.otherDepartment ?? null) === otherDepartment) {
    throw new WorkflowError(
      "failed-precondition",
      "The requested lane set does not change the maintenance issue.",
      {reasonCode: "maintenance-ticket-lane-reconfiguration-noop"},
    );
  }
  const nextVersion = version + 1;
  const update: JsonMap = {
    routedTo: lanes[0],
    otherDepartment,
    status: ticketLaneStatus(nextPlan),
    ...ticketLaneProjection(nextPlan),
    ...(nextPlan.acknowledged.length === 0 ? {
      acknowledgedByUid: null,
      acknowledgedByName: null,
      acknowledgedAt: null,
    } : {}),
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason,
    summary: `Maintenance issue lanes changed: ${lanes.join(", ")}`,
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-lanes-reconfigured",
    aggregateVersion: nextVersion,
    result: {ticketId: command.aggregateId, auditId: id, lanes},
  };
};

const normalizeCorrections = (
  raw: JsonMap,
): Readonly<Record<string, string | boolean | null>> => {
  const keys = Object.keys(raw);
  if (keys.length === 0 || keys.some((key) => !CORRECTABLE_FIELDS.has(key))) {
    throw new WorkflowError(
      "invalid-argument",
      "Corrections must contain at least one supported maintenance field.",
      {reasonCode: "maintenance-ticket-corrections-invalid"},
    );
  }
  const corrections: {[key: string]: string | boolean | null} = {};
  for (const key of keys) {
    const value = raw[key];
    switch (key) {
    case "description":
      corrections[key] = boundedText(value, key, 1, 2000);
      break;
    case "routedTo": {
      const route = cleanText(value, key);
      if (!ROUTES.has(route)) {
        throw new WorkflowError("invalid-argument", "routedTo is unsupported.");
      }
      corrections[key] = route;
      break;
    }
    case "maintenanceType": {
      const type = cleanText(value, key);
      if (!MAINTENANCE_TYPES.has(type)) {
        throw new WorkflowError(
          "invalid-argument",
          "maintenanceType is unsupported.",
        );
      }
      corrections[key] = type;
      break;
    }
    case "isCritical":
      if (typeof value !== "boolean") {
        throw new WorkflowError("invalid-argument", "isCritical must be boolean.");
      }
      corrections[key] = value;
      break;
    case "plantConditionEffect": {
      const effect = cleanText(value, key);
      if (!PLANT_CONDITION_EFFECTS.has(effect) && effect !== "stuckUp") {
        throw new WorkflowError(
          "invalid-argument",
          "plantConditionEffect is unsupported.",
        );
      }
      corrections[key] = effect;
      break;
    }
    case "component":
      corrections[key] = boundedText(value, key, 1, 120);
      break;
    case "tag": {
      const text = optionalText(value, key, 80);
      corrections[key] = text?.toUpperCase() ?? null;
      break;
    }
    case "otherDepartment":
      corrections[key] = optionalBoundedText(value, key, 1, 80);
      break;
    case "remarks":
      corrections[key] = optionalText(value, key, 4000);
      break;
    default:
      corrections[key] = optionalText(value, key, 1000);
    }
  }
  return corrections;
};

export const correctMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["corrections", "reason"], "payload");
  const reason = boundedText(command.payload.reason, "reason", 1, 2000);
  const corrections = normalizeCorrections(
    record(command.payload.corrections, "corrections"),
  );
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  const currentLanePlan = ticketLanePlan(ticket, {
    allowOtherDepartmentRepair: true,
  });
  const changed: {[key: string]: string | boolean | null} = {};
  for (const [key, value] of Object.entries(corrections)) {
    if ((ticket[key] ?? null) !== value) changed[key] = value;
  }
  const currentClassification = ticket.classification ?? null;
  const nextClassification = Object.prototype.hasOwnProperty.call(
    changed,
    "classification",
  ) ? changed.classification : currentClassification;
  if (currentClassification !== BURNER_LOCKOUT_CLASSIFICATION &&
      nextClassification === BURNER_LOCKOUT_CLASSIFICATION) {
    throw new WorkflowError(
      "failed-precondition",
      "A standard issue cannot be reclassified as a burner lockout.",
      {reasonCode: "maintenance-burner-specialization-immutable"},
    );
  }
  if (currentClassification === BURNER_LOCKOUT_CLASSIFICATION) {
    const positions = ticket.burnerPositions;
    const redHot = ticket.burnerRedHotPositions;
    if (!isValidBurnerPositionList(positions, false) ||
        !isValidBurnerPositionList(redHot, true) ||
        !redHot.every((position) => positions.includes(position))) {
      throw new WorkflowError(
        "failed-precondition",
        "Burner position evidence is malformed and must be reconciled before correction.",
        {reasonCode: "maintenance-burner-evidence-malformed"},
      );
    }
    const nextRoute = Object.prototype.hasOwnProperty.call(changed, "routedTo") ?
      changed.routedTo : ticket.routedTo;
    const nextType = Object.prototype.hasOwnProperty.call(
      changed,
      "maintenanceType",
    ) ? changed.maintenanceType : ticket.maintenanceType;
    const nextComponent = Object.prototype.hasOwnProperty.call(
      changed,
      "component",
    ) ? changed.component : ticket.component;
    const nextTag = Object.prototype.hasOwnProperty.call(changed, "tag") ?
      changed.tag : ticket.tag ?? null;
    const nextCritical = Object.prototype.hasOwnProperty.call(
      changed,
      "isCritical",
    ) ? changed.isCritical : ticket.isCritical;
    if (nextClassification !== BURNER_LOCKOUT_CLASSIFICATION ||
        nextRoute !== "instrumentation" || nextType !== "breakdown" ||
        nextComponent !== "Burner system" || nextTag != null ||
        (redHot.length > 0 && nextCritical !== true)) {
      throw new WorkflowError(
        "failed-precondition",
        "Burner identity, I&A routing, breakdown type, and red-hot criticality are immutable.",
        {reasonCode: "maintenance-burner-specialization-immutable"},
      );
    }
  }
  if (currentClassification !== FURNACE_STUCKUP_CLASSIFICATION &&
      nextClassification === FURNACE_STUCKUP_CLASSIFICATION) {
    throw new WorkflowError(
      "failed-precondition",
      "A standard issue cannot be reclassified as a Furnace stuck-up.",
      {reasonCode: "maintenance-stuckup-specialization-immutable"},
    );
  }
  if (currentClassification === FURNACE_STUCKUP_CLASSIFICATION) {
    const nextRoute = Object.prototype.hasOwnProperty.call(changed, "routedTo") ?
      changed.routedTo : ticket.routedTo;
    const nextType = Object.prototype.hasOwnProperty.call(
      changed,
      "maintenanceType",
    ) ? changed.maintenanceType : ticket.maintenanceType;
    const nextComponent = Object.prototype.hasOwnProperty.call(
      changed,
      "component",
    ) ? changed.component : ticket.component;
    const nextTag = Object.prototype.hasOwnProperty.call(changed, "tag") ?
      changed.tag : ticket.tag ?? null;
    const nextPlantConditionEffect = Object.prototype.hasOwnProperty.call(
      changed,
      "plantConditionEffect",
    ) ? changed.plantConditionEffect : ticket.plantConditionEffect ?? "stuckUp";
    if (nextClassification !== FURNACE_STUCKUP_CLASSIFICATION ||
        nextRoute !== "mechanical" || nextType !== "breakdown" ||
        nextComponent !== "Furnace / Inner Cover interface" || nextTag != null ||
        nextPlantConditionEffect !== "stuckUp") {
      throw new WorkflowError(
        "failed-precondition",
        "Furnace stuck-up identity, Mechanical routing, and breakdown type are immutable.",
        {reasonCode: "maintenance-stuckup-specialization-immutable"},
      );
    }
  }
  if (currentClassification !== BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION &&
      nextClassification === BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION) {
    throw new WorkflowError(
      "failed-precondition",
      "A standard issue cannot be reclassified as an Inner Cover availability issue.",
      {reasonCode: "maintenance-inner-cover-availability-immutable"},
    );
  }
  if (currentClassification === BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION) {
    const nextComponent = Object.prototype.hasOwnProperty.call(
      changed,
      "component",
    ) ? changed.component : ticket.component;
    const nextSubsystem = Object.prototype.hasOwnProperty.call(
      changed,
      "subsystem",
    ) ? changed.subsystem : ticket.subsystem ?? null;
    const nextTag = Object.prototype.hasOwnProperty.call(changed, "tag") ?
      changed.tag : ticket.tag ?? null;
    const nextPlantConditionEffect = Object.prototype.hasOwnProperty.call(
      changed,
      "plantConditionEffect",
    ) ? changed.plantConditionEffect : ticket.plantConditionEffect ?? null;
    if (nextClassification !== BASE_INNER_COVER_UNAVAILABLE_CLASSIFICATION ||
        ticket.assetType !== "base" ||
        nextComponent !== BASE_INNER_COVER_AVAILABILITY_COMPONENT ||
        nextSubsystem !== BASE_INNER_COVER_AVAILABILITY_SUBSYSTEM ||
        nextTag != null || nextPlantConditionEffect !== "unavailable") {
      throw new WorkflowError(
        "failed-precondition",
        "The Base and Inner Cover availability identity is immutable.",
        {reasonCode: "maintenance-inner-cover-availability-immutable"},
      );
    }
  }
  const nextPlantConditionEffect = Object.prototype.hasOwnProperty.call(
    changed,
    "plantConditionEffect",
  ) ? changed.plantConditionEffect : ticket.plantConditionEffect ??
    (currentClassification === FURNACE_STUCKUP_CLASSIFICATION ?
      "stuckUp" : "unfit");
  if (currentClassification !== FURNACE_STUCKUP_CLASSIFICATION &&
      (typeof nextPlantConditionEffect !== "string" ||
        !PLANT_CONDITION_EFFECTS.has(nextPlantConditionEffect))) {
    throw new WorkflowError(
      "failed-precondition",
      "A standard maintenance issue must remain Unfit or Unavailable.",
      {reasonCode: "maintenance-ticket-plant-condition-effect-invalid"},
    );
  }
  if (Object.prototype.hasOwnProperty.call(changed, "routedTo") &&
      (ticket.status !== "open" ||
        currentLanePlan.acknowledged.length > 0)) {
    throw new WorkflowError(
      "failed-precondition",
      "A ticket route cannot be corrected after acknowledgement or work has started.",
      {reasonCode: "maintenance-ticket-route-locked"},
    );
  }
  const routeChanged = Object.prototype.hasOwnProperty.call(
    changed,
    "routedTo",
  );
  const effectiveRoute = routeChanged ? changed.routedTo : ticket.routedTo;
  if (typeof effectiveRoute !== "string" || !ROUTES.has(effectiveRoute)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required only when the ticket route is Others.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  const effectiveLanes = routeChanged ? [
    effectiveRoute,
    ...currentLanePlan.assigned
      .slice(1)
      .filter((lane) => lane !== effectiveRoute),
  ] : currentLanePlan.assigned;
  const effectiveOtherDepartment = Object.prototype.hasOwnProperty.call(
    changed,
    "otherDepartment",
  ) ? changed.otherDepartment : ticket.otherDepartment ?? null;
  const validOtherDepartment = typeof effectiveOtherDepartment === "string" &&
    effectiveOtherDepartment.trim().length >= 1 &&
    effectiveOtherDepartment.length <= 80;
  if ((effectiveLanes.includes("others") ?
        !validOtherDepartment : effectiveOtherDepartment != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required only when the ticket route is Others.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  if (Object.keys(changed).length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The requested correction does not change the maintenance ticket.",
      {reasonCode: "maintenance-ticket-correction-noop"},
    );
  }
  const nextVersion = version + 1;
  const laneProjectionUpdate = routeChanged ? ticketLaneProjection({
    revision: currentLanePlan.revision + 1,
    assigned: effectiveLanes,
    acknowledged: [],
    completed: [],
    completionEvidence: {},
    }) : {};
  const update: JsonMap = {
    ...changed,
    ...laneProjectionUpdate,
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason,
    summary: `Maintenance ticket corrected: ${Object.keys(changed).sort().join(", ")}`,
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-corrected",
    aggregateVersion: nextVersion,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      correctedFields: Object.keys(changed).sort(),
    },
  };
};

const parsedAuditObject = (value: unknown): JsonMap | null => {
  if (typeof value !== "string") return null;
  try {
    const decoded = JSON.parse(value) as unknown;
    return decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    return null;
  }
};

const sameAuditStringList = (left: unknown, right: unknown): boolean =>
  Array.isArray(left) && Array.isArray(right) &&
  left.length === right.length &&
  left.every((value, index) =>
    typeof value === "string" && value === right[index]);

export const verifyMaintenanceTicketAudit = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  if (args.command.commandType !== "createMaintenanceTicket" &&
      args.command.commandType !== "acknowledgeMaintenanceTicket" &&
      args.command.commandType !== "completeMaintenanceTicketLane" &&
      args.command.commandType !== "reconfigureMaintenanceTicketLanes" &&
      args.command.commandType !== "resolveMaintenanceTicket" &&
      args.command.commandType !== "closeMaintenanceTicketWithoutResolution" &&
      args.command.commandType !== "reopenMaintenanceTicket" &&
      args.command.commandType !== "correctMaintenanceTicket") return;
  const id = auditId(args.command.commandId);
  const audit = await args.tx.get(auditPath(args.command.commandId));
  const data = audit.data;
  const before = parsedAuditObject(data?.beforeJson);
  const after = parsedAuditObject(data?.afterJson);
  if (!audit.exists || data == null ||
      data.schemaVersion !== 1 || data.auditId !== id ||
      data.entityType !== "maintenance" ||
      data.entityId !== args.command.aggregateId ||
      data.operation !== args.command.commandType ||
      data.action !== (args.command.commandType === "createMaintenanceTicket" ?
        "create" : "update") ||
      data.requestId !== args.command.commandId ||
      data.performedByUid !== args.actor.uid ||
      data.resultVersion !== args.receipt.aggregateVersion ||
      args.receipt.result.auditId !== id ||
      before == null || after == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket receipt no longer matches its immutable audit.",
      {reasonCode: "maintenance-ticket-replay-audit-invalid"},
    );
  }
  if (args.command.commandType === "acknowledgeMaintenanceTicket" ||
      args.command.commandType === "completeMaintenanceTicketLane") {
    const resultLane = args.receipt.result.lane;
    const explicitLane = args.command.payload.lane;
    const assigned = after.issueAssignedLanes;
    const expectedLane = typeof explicitLane === "string" ? explicitLane :
      (Array.isArray(assigned) ? assigned[0] : null);
    const acknowledged = after.issueAcknowledgedLanes;
    const completed = after.issueCompletedLanes;
    const legacySingleLaneAcknowledgement =
      args.command.commandType === "acknowledgeMaintenanceTicket" &&
      explicitLane == null && resultLane == null && assigned == null &&
      typeof after.routedTo === "string" &&
      after.status === "acknowledged" &&
      typeof after.acknowledgedByUid === "string" &&
      typeof after.acknowledgedByName === "string" &&
      after.acknowledgedAt != null;
    if (!legacySingleLaneAcknowledgement &&
        (typeof resultLane !== "string" || resultLane !== expectedLane ||
          !Array.isArray(acknowledged) || !acknowledged.includes(resultLane) ||
          (args.command.commandType === "completeMaintenanceTicketLane" &&
            (!Array.isArray(completed) || !completed.includes(resultLane))))) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket lane receipt no longer matches its immutable audit.",
        {reasonCode: "maintenance-ticket-replay-lane-invalid"},
      );
    }
  }
  if (args.command.commandType === "reconfigureMaintenanceTicketLanes" &&
      (!sameAuditStringList(
        args.receipt.result.lanes,
        args.command.payload.lanes,
      ) || !sameAuditStringList(
        after.issueAssignedLanes,
        args.command.payload.lanes,
      ))) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket lane-change receipt no longer matches its immutable audit.",
      {reasonCode: "maintenance-ticket-replay-lanes-invalid"},
    );
  }
  if (args.command.commandType === "resolveMaintenanceTicket") {
    const completed = after.issueCompletedLanes;
    const assigned = after.issueAssignedLanes;
    if (args.receipt.result.ticketId !== args.command.aggregateId ||
        after.status !== "resolved" || after.isResolved !== true ||
        after.closedByUid !== args.actor.uid ||
        after.version !== args.receipt.aggregateVersion ||
        !sameAuditStringList(
          args.receipt.result.completedLanes,
          completed,
        ) || !sameAuditStringList(assigned, completed)) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket resolution receipt no longer matches its immutable audit.",
        {reasonCode: "maintenance-ticket-replay-resolution-invalid"},
      );
    }
  }
  if (args.command.commandType ===
      "closeMaintenanceTicketWithoutResolution") {
    const disposition = cleanText(
      args.command.payload.disposition,
      "disposition",
    );
    const reason = boundedText(
      args.command.payload.reason,
      "reason",
      1,
      2000,
    );
    const cancelledCoordination = args.receipt.result.cancelledCoordination;
    const workflowId = args.receipt.result.cancelledWorkflowId;
    const complianceId = args.receipt.result.cancelledComplianceId;
    if (args.receipt.result.ticketId !== args.command.aggregateId ||
        !ADMINISTRATIVE_CLOSURE_DISPOSITIONS.has(disposition) ||
        after.status !== "closedWithoutResolution" ||
        after.isResolved !== true ||
        after.closedByUid !== args.actor.uid ||
        after.issueClosureSchemaVersion !== 1 ||
        after.issueClosureDisposition !== disposition ||
        after.issueClosureReason !== reason ||
        after.version !== args.receipt.aggregateVersion ||
        typeof cancelledCoordination !== "boolean" ||
        (cancelledCoordination &&
          (typeof workflowId !== "string" ||
            typeof complianceId !== "string")) ||
        (!cancelledCoordination &&
          (workflowId != null || complianceId != null))) {
      throw new WorkflowError(
        "failed-precondition",
        "Administrative issue-closure receipt no longer matches its immutable audit.",
        {reasonCode: "maintenance-ticket-replay-administrative-closure-invalid"},
      );
    }
    if (cancelledCoordination && typeof workflowId === "string" &&
        typeof complianceId === "string") {
      const [workflow, compliance] = await Promise.all([
        args.tx.get(workflowPath(workflowId)),
        args.tx.get(compliancePath(complianceId)),
      ]);
      if (!workflow.exists || workflow.data == null ||
          workflow.data.status !== "cancelled" ||
          workflow.data.cancelledByUid !== args.actor.uid ||
          workflow.data.linkedMaintenanceFirestoreId !==
            args.command.aggregateId ||
          !compliance.exists || compliance.data == null ||
          compliance.data.status !== "cancelled" ||
          compliance.data.cancelledByUid !== args.actor.uid ||
          compliance.data.linkedMaintenanceFirestoreId !==
            args.command.aggregateId) {
        throw new WorkflowError(
          "failed-precondition",
          "Administrative closure no longer has its coordination cancellation evidence.",
          {reasonCode: "maintenance-ticket-replay-coordination-cancellation-invalid"},
        );
      }
    }
  }
  if (args.command.commandType === "reopenMaintenanceTicket") {
    const assigned = after.issueAssignedLanes;
    if (args.receipt.result.ticketId !== args.command.aggregateId ||
        after.status !== "open" || after.isResolved !== false ||
        after.reopenedByUid !== args.actor.uid ||
        after.version !== args.receipt.aggregateVersion ||
        !sameAuditStringList(
          args.receipt.result.assignedLanes,
          assigned,
        ) || !sameAuditStringList(after.issueAcknowledgedLanes, []) ||
        !sameAuditStringList(after.issueCompletedLanes, [])) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket reopen receipt no longer matches its immutable audit.",
        {reasonCode: "maintenance-ticket-replay-reopen-invalid"},
      );
    }
  }
  if (args.command.commandType !== "createMaintenanceTicket") return;
  const ticket = await args.tx.get(maintenancePath(args.command.aggregateId));
  const ticketData = ticket.data;
  if (!ticket.exists || ticketData == null ||
      ticketData.firestoreId !== args.command.aggregateId ||
      ticketData.loggedByUid !== args.actor.uid ||
      instantText(ticketData.createdAt) !== instantText(args.receipt.appliedAt) ||
      args.receipt.result.ticketId !== args.command.aggregateId) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket creation receipt no longer matches its source record.",
      {reasonCode: "maintenance-ticket-create-replay-source-invalid"},
    );
  }
  const warningId = args.receipt.result.warningId;
  const deterministicWarningId = `issue_${args.command.aggregateId}`;
  const warning = await args.tx.get(
    `quality_warnings/${deterministicWarningId}`,
  );
  if (warningId == null && warning.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket warning evidence contradicts its receipt.",
      {reasonCode: "maintenance-ticket-create-replay-warning-invalid"},
    );
  }
  if (warningId != null) {
    if (warningId !== deterministicWarningId) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket warning identity is invalid.",
        {reasonCode: "maintenance-ticket-create-replay-warning-invalid"},
      );
    }
    if (!warning.exists || warning.data == null ||
        warning.data.warningId !== warningId ||
        warning.data.sourceType !== "issue" ||
        warning.data.sourceId !== args.command.aggregateId ||
        warning.data.createdByUid !== args.actor.uid) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket warning evidence is missing or inconsistent.",
        {reasonCode: "maintenance-ticket-create-replay-warning-invalid"},
      );
    }
  }
  const abnormalityId = args.receipt.result.abnormalityId;
  const deterministicAbnormalityId =
    `issue_quality_${args.command.aggregateId}`;
  const abnormality = await args.tx.get(
    `charge_abnormalities/${deterministicAbnormalityId}`,
  );
  if (abnormalityId == null && abnormality.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket abnormality evidence contradicts its receipt.",
      {reasonCode: "maintenance-ticket-create-replay-abnormality-invalid"},
    );
  }
  if (abnormalityId != null) {
    if (abnormalityId !== deterministicAbnormalityId ||
        ticketData.qualityAbnormalityId !== abnormalityId ||
        ticketData.qualityWarningId !== deterministicWarningId ||
        !abnormality.exists || abnormality.data == null ||
        abnormality.data.firestoreId !== abnormalityId ||
        abnormality.data.linkedTicketFirestoreId !== args.command.aggregateId ||
        abnormality.data.sourceChargeNo !== ticketData.chargeNoAtEvent ||
        abnormality.data.loggedByUid !== args.actor.uid) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket abnormality evidence is missing or inconsistent.",
        {reasonCode: "maintenance-ticket-create-replay-abnormality-invalid"},
      );
    }
  }
  const directiveId = args.receipt.result.directiveId;
  const deterministicDirectiveId = `burner_red_hot_${args.command.aggregateId}`;
  const directive = await args.tx.get(`directives/${deterministicDirectiveId}`);
  if (directiveId == null && directive.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket directive evidence contradicts its receipt.",
      {reasonCode: "maintenance-ticket-create-replay-directive-invalid"},
    );
  }
  if (directiveId != null) {
    if (directiveId !== deterministicDirectiveId) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket directive identity is invalid.",
        {reasonCode: "maintenance-ticket-create-replay-directive-invalid"},
      );
    }
    if (!directive.exists || directive.data == null ||
        directive.data.firestoreId !== directiveId ||
        directive.data.linkedMaintenanceFirestoreId !==
          args.command.aggregateId ||
        directive.data.createdByUid !== args.actor.uid) {
      throw new WorkflowError(
        "failed-precondition",
        "Maintenance ticket directive evidence is missing or inconsistent.",
        {reasonCode: "maintenance-ticket-create-replay-directive-invalid"},
      );
    }
  }
  const stuckupCaseId = args.receipt.result.stuckupCaseId;
  const deterministicStuckupCaseId = args.command.aggregateId;
  const stuckupCase = await args.tx.get(
    `furnace_stuckup_cases/${deterministicStuckupCaseId}`,
  );
  if (stuckupCaseId == null && stuckupCase.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket stuck-up evidence contradicts its receipt.",
      {reasonCode: "maintenance-ticket-create-replay-stuckup-invalid"},
    );
  }
  if (stuckupCaseId != null &&
      (stuckupCaseId !== deterministicStuckupCaseId ||
        !stuckupCase.exists || stuckupCase.data == null ||
        stuckupCase.data.ticketId !== args.command.aggregateId ||
        stuckupCase.data.reportedByUid !== args.actor.uid)) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket stuck-up evidence is missing or inconsistent.",
      {reasonCode: "maintenance-ticket-create-replay-stuckup-invalid"},
    );
  }
};
