import {WorkflowError} from "./errors";
import {HandlerArgs, HandlerResult} from "./handlerTypes";
import {maintenancePath} from "./paths";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./types";
import {cleanText, iso, stableJson} from "./utils";
import {WorkflowTransaction} from "./store";
import {isFiveDigitChargeNumber} from "../chargeNumber";

const ROUTES = new Set([
  "operations", "electrical", "mechanical", "instrumentation",
  "refractory", "emd", "shiftInCharge", "others",
]);
const MAINTENANCE_TYPES = new Set([
  "scheduled", "breakdown", "performance", "inspection", "overhaul",
]);
const STATUSES = new Set(["open", "acknowledged", "inProgress", "resolved"]);
const ASSET_TYPES = new Set([
  "base", "furnace", "forceCooler", "innerCover", "governedCustom",
]);
const QUALITY_ASSESSMENTS = new Set(["notSuspected", "suspected"]);
const BURNER_CYCLE_STAGES = new Set([
  "notRecorded", "purge", "ignition", "firing", "unknown",
]);
const BURNER_OBSERVATIONS = new Set(["seen", "notSeen", "notChecked"]);
const CORRECTABLE_FIELDS = new Set([
  "description", "routedTo", "maintenanceType", "isCritical", "component",
  "subsystem", "tag", "classification", "otherDepartment", "remarks",
]);
const BURNER_LOCKOUT_CLASSIFICATION = "furnaceBurnerLockout";
const FURNACE_STUCKUP_CLASSIFICATION = "furnaceStuckup";
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
const CREATE_TICKET_FIELDS = [
  "schemaVersion", "version", "assetType", "assetNumber", "component",
  "subsystem", "tag", "hierarchyPath", "assetHierarchyRefJson",
  "maintenanceType", "classification", "description", "routedTo",
  "otherDepartment", "isCritical", "startDate", "chargeNoAtEvent",
  "qualityIntentSchemaVersion", "qualityImpactAssessment",
  "qualityWarningReason",
] as const;
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
    boundedText(selection.unlistedReason, "unlistedReason", 5, 500);
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
  const physicalReference = reference.schemaVersion === 3 &&
    (reference.scope === "physicalAsset" ||
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
        typeof node.name !== "string" ||
        node.componentTag != null) {
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
    if (args.tag != null) {
      throw new WorkflowError(
        "failed-precondition",
        "An untagged hierarchy component cannot carry an equipment tag.",
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
      if (assignment.schemaVersion !== 1 ||
          assignment.baseAssetInstanceId !== assetId ||
          assignment.baseAssetClassId !== classId ||
          assignment.baseAssetNumber !== args.assetNumber ||
          !Number.isSafeInteger(assignment.version) ||
          typeof assignment.linkageId !== "string" ||
          typeof assignment.innerCoverSerialNumber !== "string" ||
          instantText(assignment.linkedAt) == null ||
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
      innerCoverAssociation = {
        baseAssetInstanceId: assetId,
        baseAssetNumber: args.assetNumber,
        positionState: "linked",
        innerCoverId,
        innerCoverSerialNumber: assignment.innerCoverSerialNumber as string,
        linkageId: assignment.linkageId as string,
        assignmentVersion: assignment.version as number,
        linkedAt: instantText(assignment.linkedAt),
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
  workflowDeferred: ticket.workflowDeferred ?? false,
  isDeleted: ticket.isDeleted ?? null,
});

const requireTicket = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
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
      ((ticket.status === "resolved") !== ticket.isResolved)) {
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
  if (ticket.workflowDeferred === true) {
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
  exactKeys(
    input,
    burner ? [...CREATE_TICKET_FIELDS, ...CREATE_BURNER_FIELDS,
      ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])] :
      stuckup ? [...CREATE_TICKET_FIELDS, ...CREATE_STUCKUP_FIELDS,
        ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])] :
        [...CREATE_TICKET_FIELDS,
          ...(hasFrequentIssueSelection ? [FREQUENT_ISSUE_SELECTION_FIELD] : [])],
    "ticket",
  );
  const requestedFrequentIssueSelection = hasFrequentIssueSelection ?
    parseFrequentIssueSelectionShape(input.frequentIssueSelection) : null;
  if (input.schemaVersion !== 1) {
    throw new WorkflowError("invalid-argument", "ticket schemaVersion is unsupported.");
  }
  const version = requiredInteger(input.version, "version", 1, 2147483647);
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
  const otherDepartment = optionalText(input.otherDepartment, "otherDepartment", 80);
  if ((routedTo === "others") !== (otherDepartment != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required only when the issue route is Others.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  const component = boundedText(input.component, "component", 2, 120);
  const subsystem = optionalText(input.subsystem, "subsystem", 200);
  const tag = optionalText(input.tag, "tag", 160)?.toUpperCase() ?? null;
  optionalStringList(input.hierarchyPath, "hierarchyPath", 20, 200);
  const classification = optionalText(input.classification, "classification", 120);
  const description = boundedText(input.description, "description", 5, 2000);
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
  if (input.qualityIntentSchemaVersion !== 1 ||
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
  if (suspected ?
    (qualityWarningReason == null || qualityWarningReason.length < 8 ||
      chargeNoAtEvent == null) : qualityWarningReason != null) {
    throw new WorkflowError(
      "invalid-argument",
      "Suspected quality impact requires charge and warning-reason evidence.",
      {reasonCode: "maintenance-ticket-quality-evidence-invalid"},
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
        routedTo !== "instrumentation" || component !== "Burner system" ||
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
    qualityIntentSchemaVersion: 1,
    qualityImpactAssessment: input.qualityImpactAssessment as string,
    qualityWarningReason,
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
  const directive = redHotDirectiveProjection({
    ticketId: command.aggregateId,
    ticket,
    actor: context.actor,
    timestamp,
  });
  const warningId = `issue_${command.aggregateId}`;
  const directiveId = `burner_red_hot_${command.aggregateId}`;
  const reviewQueueId = frequentIssueSelection?.selectionType === "unlisted" ?
    command.aggregateId : null;
  const [existingTicket, existingWarning, existingDirective, existingReview] =
    await Promise.all([
    tx.get(maintenancePath(command.aggregateId)),
    tx.get(`quality_warnings/${warningId}`),
    tx.get(`directives/${directiveId}`),
    tx.get(`issue_governance_review_queue/${command.aggregateId}`),
  ]);
  if (existingTicket.exists || existingWarning.exists || existingDirective.exists ||
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
  if (directive != null) tx.create(`directives/${directiveId}`, directive);
  return {
    resultKey: "maintenance-ticket-created",
    aggregateVersion: version,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      warningId: warning == null ? null : warningId,
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
  exactKeys(command.payload, [], "payload");
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  if (ticket.status !== "open" ||
      ticket.acknowledgedByUid != null ||
      ticket.acknowledgedByName != null ||
      ticket.acknowledgedAt != null) {
    throw new WorkflowError(
      "failed-precondition",
      "Only a clean open maintenance ticket can be acknowledged.",
      {reasonCode: "maintenance-ticket-not-open-for-acknowledgement"},
    );
  }
  const nextVersion = version + 1;
  const update: JsonMap = {
    status: "acknowledged",
    acknowledgedByUid: context.actor.uid,
    acknowledgedByName: context.actor.name,
    acknowledgedAt: iso(context.serverNow),
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
    reason: "Maintenance ticket acknowledged by the accountable receiving authority.",
    summary: "Maintenance ticket acknowledged",
    severity: "low",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-acknowledged",
    aggregateVersion: nextVersion,
    result: {ticketId: command.aggregateId, auditId: id},
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
      corrections[key] = boundedText(value, key, 5, 2000);
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
    case "component":
      corrections[key] = boundedText(value, key, 2, 120);
      break;
    case "tag": {
      const text = optionalText(value, key, 80);
      corrections[key] = text?.toUpperCase() ?? null;
      break;
    }
    case "otherDepartment":
      corrections[key] = optionalText(value, key, 80);
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
  const reason = boundedText(command.payload.reason, "reason", 12, 2000);
  const corrections = normalizeCorrections(
    record(command.payload.corrections, "corrections"),
  );
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
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
  if (Object.prototype.hasOwnProperty.call(changed, "routedTo") &&
      (ticket.status !== "open" ||
        ticket.acknowledgedByUid != null ||
        ticket.acknowledgedByName != null ||
        ticket.acknowledgedAt != null)) {
    throw new WorkflowError(
      "failed-precondition",
      "A ticket route cannot be corrected after acknowledgement or work has started.",
      {reasonCode: "maintenance-ticket-route-locked"},
    );
  }
  const effectiveRoute = changed.routedTo ?? ticket.routedTo;
  const effectiveOtherDepartment = Object.prototype.hasOwnProperty.call(
    changed,
    "otherDepartment",
  ) ? changed.otherDepartment : ticket.otherDepartment ?? null;
  const validOtherDepartment = typeof effectiveOtherDepartment === "string" &&
    effectiveOtherDepartment.trim().length >= 2 &&
    effectiveOtherDepartment.length <= 80;
  if (typeof effectiveRoute !== "string" || !ROUTES.has(effectiveRoute) ||
      (effectiveRoute === "others" ?
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
  const update: JsonMap = {
    ...changed,
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

export const verifyMaintenanceTicketAudit = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  if (args.command.commandType !== "createMaintenanceTicket" &&
      args.command.commandType !== "acknowledgeMaintenanceTicket" &&
      args.command.commandType !== "correctMaintenanceTicket") return;
  const id = auditId(args.command.commandId);
  const audit = await args.tx.get(auditPath(args.command.commandId));
  const data = audit.data;
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
      parsedAuditObject(data.beforeJson) == null ||
      parsedAuditObject(data.afterJson) == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket receipt no longer matches its immutable audit.",
      {reasonCode: "maintenance-ticket-replay-audit-invalid"},
    );
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
