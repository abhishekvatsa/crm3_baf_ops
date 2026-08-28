import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {frozenMaintenanceClassFromDefinition} from "./maintenanceClassHandlers";
import {
  applyMaintenanceCompletionWritePlan,
  assertMaintenanceClassApplies,
  prepareMaintenanceCompletionWritePlan,
} from "./maintenanceIntelligence";
import {JsonMap} from "./types";
import {cleanText, iso, stableJson} from "./utils";

const recordPath = (id: string): string =>
  `historical_maintenance_records/${id}`;
const auditPath = (commandId: string): string =>
  `historical_maintenance_audits/${commandId}`;
const definitionPath = (id: string): string =>
  `maintenance_class_definitions/${id}`;

const maintainableInnerCoverStates = new Set([
  "available", "reserved", "installed", "awaitingInspection",
  "underInspection", "underRepair", "quarantined",
]);

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
    );
  }
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." ||
      parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const optionalText = (
  value: unknown,
  field: string,
  maximum: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be text or null.`,
    );
  }
  const parsed = value.trim();
  if (parsed.length === 0) return null;
  if (parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} cannot exceed ${maximum} characters.`,
    );
  }
  return parsed;
};

const positiveVersion = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return value as number;
};

const completedAtIso = (value: unknown, serverNow: Date): string => {
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", "completedAt is required.");
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new WorkflowError("invalid-argument", "completedAt is invalid.");
  }
  if (parsed.getTime() > serverNow.getTime() + 5 * 60 * 1000) {
    throw new WorkflowError(
      "invalid-argument",
      "Historical maintenance cannot be dated in the future.",
    );
  }
  return parsed.toISOString();
};

export const recordHistoricalMaintenance: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, [
    "assetTypeKey", "assetNumber", "assetClassId", "assetInstanceId",
    "assetInstanceVersion", "definitionId", "definitionVersion",
    "completedAt", "performedByName", "evidenceNote", "sourceReference",
  ], "payload");
  if (!context.actor.roles.has("admin")) {
    throw new WorkflowError(
      "permission-denied",
      "Only Admin can add previous maintenance records.",
    );
  }
  if (command.expectedVersion !== 0) {
    throw new WorkflowError(
      "failed-precondition",
      "Previous maintenance records are immutable additions.",
    );
  }

  const historicalRecordId = documentId(command.aggregateId, "aggregateId");
  const assetTypeKey = documentId(
    command.payload.assetTypeKey,
    "assetTypeKey",
  );
  const assetClassId = documentId(
    command.payload.assetClassId,
    "assetClassId",
  );
  const assetInstanceId = documentId(
    command.payload.assetInstanceId,
    "assetInstanceId",
  );
  const assetInstanceVersion = positiveVersion(
    command.payload.assetInstanceVersion,
    "assetInstanceVersion",
  );
  const serialInnerCover = assetTypeKey === "innerCover" &&
    command.payload.assetNumber == null;
  const assetNumber = serialInnerCover ? null : command.payload.assetNumber;
  if (!serialInnerCover &&
      (!Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1)) {
    throw new WorkflowError("invalid-argument", "assetNumber is invalid.");
  }
  const definitionId = documentId(
    command.payload.definitionId,
    "definitionId",
  );
  const definitionVersion = positiveVersion(
    command.payload.definitionVersion,
    "definitionVersion",
  );
  const completedAt = completedAtIso(
    command.payload.completedAt,
    context.serverNow,
  );
  const performedByName = optionalText(
    command.payload.performedByName,
    "performedByName",
    160,
  );
  const evidenceNote = optionalText(
    command.payload.evidenceNote,
    "evidenceNote",
    1200,
  );
  if (evidenceNote == null) {
    throw new WorkflowError(
      "invalid-argument",
      "evidenceNote is required.",
    );
  }
  const sourceReference = optionalText(
    command.payload.sourceReference,
    "sourceReference",
    240,
  );

  const [existing, audit, definition, assetClass, asset] = await Promise.all([
    tx.get(recordPath(historicalRecordId)),
    tx.get(auditPath(command.commandId)),
    tx.get(definitionPath(definitionId)),
    tx.get(`asset_classes/${assetClassId}`),
    tx.get(serialInnerCover ?
      `inner_cover_profiles/${assetInstanceId}` :
      `asset_instances/${assetInstanceId}`),
  ]);
  if (existing.exists || audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Previous maintenance evidence already exists without this receipt.",
      {reasonCode: "historical-maintenance-orphan-evidence"},
    );
  }
  if (!definition.exists || definition.data == null ||
      definition.data.status !== "active" ||
      definition.data.version !== definitionVersion) {
    throw new WorkflowError(
      "aborted",
      "The selected maintenance type is missing, inactive or changed.",
      {reasonCode: "historical-maintenance-class-changed"},
    );
  }
  if (!assetClass.exists || assetClass.data == null ||
      assetClass.data.schemaVersion !== 1 ||
      assetClass.data.assetClassId !== assetClassId ||
      assetClass.data.status !== "active" ||
      assetClass.data.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected asset class is missing or inactive.",
    );
  }
  const expectedAssetType = assetClass.data.legacyAssetTypeKey == null ?
    "governedCustom" : assetClass.data.legacyAssetTypeKey;
  if (expectedAssetType !== assetTypeKey) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected asset type and class disagree.",
    );
  }

  const physicalAssetValid = serialInnerCover ?
    asset.exists && asset.data != null && asset.data.schemaVersion === 1 &&
      asset.data.innerCoverId === assetInstanceId &&
      asset.data.assetClassId === assetClassId &&
      asset.data.version === assetInstanceVersion &&
      typeof asset.data.serialNumber === "string" &&
      asset.data.serialNumber.trim().length > 0 &&
      maintainableInnerCoverStates.has(String(asset.data.lifecycleState)) :
    asset.exists && asset.data != null && asset.data.schemaVersion === 1 &&
      asset.data.assetInstanceId === assetInstanceId &&
      asset.data.assetClassId === assetClassId &&
      asset.data.assetNumber === assetNumber &&
      asset.data.version === assetInstanceVersion &&
      asset.data.status === "active" && asset.data.isDeleted !== true &&
      typeof asset.data.name === "string" && asset.data.name.trim().length > 0;
  if (!physicalAssetValid) {
    throw new WorkflowError(
      "aborted",
      "The selected physical asset is missing, inactive or changed.",
      {reasonCode: "historical-maintenance-asset-changed"},
    );
  }

  const assetDisplayName = serialInnerCover ?
    `Inner Cover ${String(asset.data!.serialNumber).trim()}` :
    String(asset.data!.name).trim();
  const classification = frozenMaintenanceClassFromDefinition(
    definition.data,
  );
  const execution: JsonMap = {
    assetTypeKey,
    assetNumber: serialInnerCover ? null : assetNumber as number,
    assetClassId,
    assetInstanceId,
    assetInstanceName: assetDisplayName,
  };
  const identity = {
    assetIdentityKey: `${assetClassId}:${assetInstanceId}`,
    assetTypeKey,
    assetNumber: serialInnerCover ? null : assetNumber as number,
    assetClassId,
    assetInstanceId,
  };
  assertMaintenanceClassApplies(classification, identity);
  const recordedAt = iso(context.serverNow);
  const completion = await prepareMaintenanceCompletionWritePlan({
    tx,
    execution,
    executionId: historicalRecordId,
    sourceType: "historicalMaintenance",
    completedAt,
    completedBy: {uid: null, name: performedByName},
    recordedAt,
    classification,
  });
  if (completion == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Historical maintenance classification was not preserved.",
    );
  }

  const historicalRecord: JsonMap = {
    schemaVersion: 1,
    historicalRecordId,
    version: 1,
    ...identity,
    assetInstanceVersion,
    assetDisplayName,
    maintenanceClass: classification as unknown as JsonMap,
    maintenanceClassDefinitionId: classification.definitionId,
    maintenanceClassDefinitionVersion: classification.definitionVersion,
    maintenanceClassCode: classification.code,
    maintenanceClassTitle: classification.title,
    completedAt,
    datePrecision: "date",
    performedByName,
    evidenceNote,
    sourceReference,
    recordedAt,
    recordedByUid: context.actor.uid,
    recordedByName: context.actor.name,
    completionEventId: completion.eventId,
  };
  applyMaintenanceCompletionWritePlan(tx, completion);
  tx.create(recordPath(historicalRecordId), historicalRecord);
  tx.create(auditPath(command.commandId), {
    schemaVersion: 1,
    auditId: command.commandId,
    historicalRecordId,
    operation: "record-historical-maintenance",
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    performedAt: recordedAt,
    beforeJson: "{}",
    afterJson: stableJson(historicalRecord),
  });
  return {
    resultKey: "historical-maintenance-recorded",
    aggregateVersion: 1,
    result: {
      historicalRecordId,
      completionEventId: completion.eventId,
      maintenanceClassCode: classification.code,
      completionEffectiveAt: completedAt,
    },
  };
};
