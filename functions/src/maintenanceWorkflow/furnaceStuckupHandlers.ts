import {WorkflowError} from "./errors";
import {HandlerArgs, HandlerResult} from "./handlerTypes";
import {DocSnapshot, WorkflowTransaction} from "./store";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./types";
import {cleanText, iso, persistedInstantText, stableJson} from "./utils";

const CAUSES = new Set([
  "innerCoverBulging",
  "draftSealPlateDamagedOrFallen",
  "insufficientDraftSealClearance",
  "combinedCondition",
  "other",
  "inconclusive",
]);

const casePath = (caseId: string): string =>
  `furnace_stuckup_cases/${caseId}`;
const constraintPath = (caseId: string, assetInstanceId: string): string =>
  `asset_availability_constraints/${caseId}_${assetInstanceId}`;
const currentPath = (assetInstanceId: string): string =>
  `asset_availability_current/${assetInstanceId}`;
const auditId = (commandId: string): string =>
  `server_asset_integrity_${commandId}`;
const auditPath = (commandId: string): string =>
  `audit_logs/${auditId(commandId)}`;

const record = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be an object.`);
  }
  return value as JsonMap;
};

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
      {reasonCode: "furnace-stuckup-command-shape-invalid", field},
    );
  }
};

const boundedText = (
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): string => {
  const text = cleanText(value, field);
  if (text.length < minimum || text.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return text;
};

const requiredVersion = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new WorkflowError(
      "failed-precondition",
      `${field} is malformed.`,
      {reasonCode: "furnace-stuckup-version-invalid"},
    );
  }
  return value as number;
};

const requireCase = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
): Promise<{caseData: JsonMap; version: number}> => {
  const snapshot = await tx.get(casePath(command.aggregateId));
  const caseData = snapshot.data;
  if (!snapshot.exists || caseData == null ||
      caseData.schemaVersion !== 1 ||
      caseData.caseId !== command.aggregateId ||
      caseData.ticketId !== command.aggregateId) {
    throw new WorkflowError(
      "not-found",
      "Furnace stuck-up case was not found.",
      {reasonCode: "furnace-stuckup-case-not-found"},
    );
  }
  const version = requiredVersion(caseData.version, "case.version");
  if (version !== command.expectedVersion) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "Furnace stuck-up case changed before this command was applied.",
      {
        reasonCode: "furnace-stuckup-version-conflict",
        expectedVersion: command.expectedVersion,
        actualVersion: version,
      },
    );
  }
  return {caseData, version};
};

const requireVacantAudit = async (
  tx: WorkflowTransaction,
  commandId: string,
): Promise<void> => {
  if ((await tx.get(auditPath(commandId))).exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Asset-integrity audit identity is already occupied.",
      {reasonCode: "asset-integrity-audit-collision"},
    );
  }
};

const writeAudit = (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  at: Date;
  before: JsonMap;
  after: JsonMap;
  summary: string;
  resultVersion: number;
}): string => {
  const id = auditId(args.command.commandId);
  args.tx.create(auditPath(args.command.commandId), {
    schemaVersion: 1,
    auditId: id,
    entityType: "furnaceStuckupCase",
    entityId: args.command.aggregateId,
    action: "update",
    operation: args.command.commandType,
    performedByUid: args.actor.uid,
    performedByName: args.actor.name,
    timestamp: iso(args.at),
    reason: "other",
    reasonNotes: args.summary,
    summary: args.summary,
    severity: "medium",
    beforeJson: stableJson(args.before),
    afterJson: stableJson(args.after),
    requestId: args.command.commandId,
    resultVersion: args.resultVersion,
  });
  return id;
};

const releaseConstraint = (args: {
  tx: WorkflowTransaction;
  caseData: JsonMap;
  assetInstanceId: string;
  constraint: DocSnapshot;
  current: DocSnapshot;
  at: string;
  actor: Actor;
}): void => {
  const constraintId = `${args.caseData.caseId}_${args.assetInstanceId}`;
  const {constraint, current} = args;
  if (!constraint.exists || constraint.data == null ||
      constraint.data.schemaVersion !== 1 ||
      constraint.data.constraintId !== constraintId ||
      constraint.data.caseId !== args.caseData.caseId ||
      constraint.data.assetInstanceId !== args.assetInstanceId ||
      constraint.data.status !== "active" ||
      !current.exists || current.data == null ||
      current.data.schemaVersion !== 1 ||
      current.data.assetInstanceId !== args.assetInstanceId ||
      current.data.activeConstraintId !== constraintId ||
      current.data.availabilityState !== "temporarilyBlocked") {
    throw new WorkflowError(
      "failed-precondition",
      "The active stuck-up availability projection is missing or inconsistent.",
      {reasonCode: "furnace-stuckup-availability-projection-invalid"},
    );
  }
  const currentVersion = requiredVersion(
    current.data.version,
    "availability.version",
  );
  args.tx.update(`asset_availability_constraints/${constraintId}`, {
    status: "released",
    releasedAt: args.at,
    releasedByUid: args.actor.uid,
    releasedByName: args.actor.name,
    updatedAt: args.at,
    version: requiredVersion(constraint.data.version, "constraint.version") + 1,
  });
  args.tx.update(currentPath(args.assetInstanceId), {
    availabilityState: "clear",
    activeConstraintId: null,
    reasonType: null,
    linkedCaseId: null,
    linkedTicketId: null,
    since: null,
    updatedAt: args.at,
    updatedByUid: args.actor.uid,
    updatedByName: args.actor.name,
    version: currentVersion + 1,
  });
};

export const releaseFurnaceStuckup = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["releaseNotes"], "payload");
  const notes = boundedText(command.payload.releaseNotes, "releaseNotes", 1, 1000);
  const {caseData, version} = await requireCase(tx, command);
  if (caseData.obstructionStatus !== "active") {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active physical obstruction can be released.",
      {reasonCode: "furnace-stuckup-already-released"},
    );
  }
  const baseId = boundedText(
    caseData.baseAssetInstanceId,
    "baseAssetInstanceId",
    1,
    160,
  );
  const furnaceId = boundedText(
    caseData.furnaceAssetInstanceId,
    "furnaceAssetInstanceId",
    1,
    160,
  );
  const [
    audit,
    baseConstraint,
    baseCurrent,
    furnaceConstraint,
    furnaceCurrent,
  ] = await Promise.all([
    tx.get(auditPath(command.commandId)),
    tx.get(constraintPath(command.aggregateId, baseId)),
    tx.get(currentPath(baseId)),
    tx.get(constraintPath(command.aggregateId, furnaceId)),
    tx.get(currentPath(furnaceId)),
  ]);
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Asset-integrity audit identity is already occupied.",
      {reasonCode: "asset-integrity-audit-collision"},
    );
  }
  const timestamp = iso(context.serverNow);
  releaseConstraint({
    tx,
    caseData,
    assetInstanceId: baseId,
    constraint: baseConstraint,
    current: baseCurrent,
    at: timestamp,
    actor: context.actor,
  });
  releaseConstraint({
    tx,
    caseData,
    assetInstanceId: furnaceId,
    constraint: furnaceConstraint,
    current: furnaceCurrent,
    at: timestamp,
    actor: context.actor,
  });
  const nextVersion = version + 1;
  const update: JsonMap = {
    obstructionStatus: "released",
    releasedAt: timestamp,
    releasedByUid: context.actor.uid,
    releasedByName: context.actor.name,
    releaseNotes: notes,
    updatedAt: timestamp,
    version: nextVersion,
  };
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    before: caseData,
    after: {...caseData, ...update},
    summary: "Furnace stuck-up physical obstruction released",
    resultVersion: nextVersion,
  });
  tx.update(casePath(command.aggregateId), update);
  return {
    resultKey: "furnace-stuckup-released",
    aggregateVersion: nextVersion,
    result: {caseId: command.aggregateId, auditId: id},
  };
};

export const adjudicateFurnaceStuckup = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["confirmedCause", "adjudicationNotes"], "payload");
  const cause = cleanText(command.payload.confirmedCause, "confirmedCause");
  if (!CAUSES.has(cause)) {
    throw new WorkflowError("invalid-argument", "confirmedCause is unsupported.");
  }
  const notes = boundedText(
    command.payload.adjudicationNotes,
    "adjudicationNotes",
    1,
    2000,
  );
  const {caseData, version} = await requireCase(tx, command);
  if (caseData.adjudicationStatus !== "pending") {
    throw new WorkflowError(
      "failed-precondition",
      "This stuck-up cause has already been adjudicated.",
      {reasonCode: "furnace-stuckup-already-adjudicated"},
    );
  }
  await requireVacantAudit(tx, command.commandId);
  const timestamp = iso(context.serverNow);
  const nextVersion = version + 1;
  const adjudicationStatus = cause === "inconclusive" ?
    "inconclusive" : "confirmed";
  let declarationId: string | null = null;
  let evidenceId: string | null = null;
  if (cause === "innerCoverBulging" || cause === "combinedCondition") {
    const innerCoverId = boundedText(
      caseData.innerCoverId,
      "innerCoverId",
      1,
      160,
    );
    const serial = boundedText(
      caseData.innerCoverSerialNumber,
      "innerCoverSerialNumber",
      1,
      160,
    );
    declarationId = `inner_cover_bulged_${innerCoverId}`;
    evidenceId = `${declarationId}_${command.aggregateId}`;
    const [declaration, evidence] = await Promise.all([
      tx.get(`asset_condition_declarations/${declarationId}`),
      tx.get(`asset_condition_evidence/${evidenceId}`),
    ]);
    if (evidence.exists) {
      throw new WorkflowError(
        "failed-precondition",
        "Bulging evidence already exists without this command receipt.",
        {reasonCode: "furnace-stuckup-condition-evidence-orphan"},
      );
    }
    let declarationVersion = 1;
    let evidenceCount = 1;
    let firstConfirmedAt = timestamp;
    if (declaration.exists) {
      const data = declaration.data;
      const persistedFirstConfirmedAt = persistedInstantText(
        data?.firstConfirmedAt,
      );
      if (data == null || data.schemaVersion !== 1 ||
          data.declarationId !== declarationId ||
          data.conditionType !== "innerCoverBulged" ||
          data.assetType !== "innerCover" ||
          data.assetId !== innerCoverId ||
          data.assetSerialNumber !== serial ||
          data.state !== "confirmed" ||
          !Number.isSafeInteger(data.evidenceCount) ||
          (data.evidenceCount as number) < 1 ||
          persistedFirstConfirmedAt == null) {
        throw new WorkflowError(
          "failed-precondition",
          "The existing Inner Cover condition declaration is malformed.",
          {reasonCode: "inner-cover-bulge-declaration-invalid"},
        );
      }
      declarationVersion = requiredVersion(data.version, "declaration.version") + 1;
      evidenceCount = (data.evidenceCount as number) + 1;
      firstConfirmedAt = persistedFirstConfirmedAt;
    }
    const declarationData: JsonMap = {
      schemaVersion: 1,
      declarationId,
      conditionType: "innerCoverBulged",
      assetType: "innerCover",
      assetId: innerCoverId,
      assetSerialNumber: serial,
      state: "confirmed",
      evidenceCount,
      firstConfirmedAt,
      latestEvidenceAt: timestamp,
      latestEvidenceId: evidenceId,
      latestCaseId: command.aggregateId,
      confirmedByAuthority: "adminOrSI",
      updatedAt: timestamp,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
      version: declarationVersion,
    };
    if (declaration.exists) {
      tx.set(`asset_condition_declarations/${declarationId}`, declarationData);
    } else {
      tx.create(`asset_condition_declarations/${declarationId}`, declarationData);
    }
    tx.create(`asset_condition_evidence/${evidenceId}`, {
      schemaVersion: 1,
      evidenceId,
      declarationId,
      caseId: command.aggregateId,
      ticketId: caseData.ticketId,
      evidenceType: "confirmedFurnaceStuckupCause",
      confirmedCause: cause,
      notes,
      observedAt: caseData.reportedAt,
      confirmedAt: timestamp,
      confirmedByUid: context.actor.uid,
      confirmedByName: context.actor.name,
    });
  }
  const update: JsonMap = {
    adjudicationStatus,
    confirmedCause: cause,
    adjudicationNotes: notes,
    adjudicatedAt: timestamp,
    adjudicatedByUid: context.actor.uid,
    adjudicatedByName: context.actor.name,
    conditionDeclarationId: declarationId,
    conditionEvidenceId: evidenceId,
    updatedAt: timestamp,
    version: nextVersion,
  };
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    before: caseData,
    after: {...caseData, ...update},
    summary: `Furnace stuck-up cause ${adjudicationStatus}`,
    resultVersion: nextVersion,
  });
  tx.update(casePath(command.aggregateId), update);
  return {
    resultKey: "furnace-stuckup-adjudicated",
    aggregateVersion: nextVersion,
    result: {
      caseId: command.aggregateId,
      auditId: id,
      declarationId,
      evidenceId,
    },
  };
};

const parsedObject = (value: unknown): JsonMap | null => {
  if (typeof value !== "string") return null;
  try {
    const decoded = JSON.parse(value) as unknown;
    return decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    return null;
  }
};

export const verifyFurnaceStuckupAudit = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  if (args.command.commandType !== "releaseFurnaceStuckup" &&
      args.command.commandType !== "adjudicateFurnaceStuckup") return;
  const id = auditId(args.command.commandId);
  const audit = await args.tx.get(auditPath(args.command.commandId));
  const data = audit.data;
  const stuckupCase = await args.tx.get(casePath(args.command.aggregateId));
  if (!audit.exists || data == null ||
      data.schemaVersion !== 1 || data.auditId !== id ||
      data.entityType !== "furnaceStuckupCase" ||
      data.entityId !== args.command.aggregateId ||
      data.operation !== args.command.commandType ||
      data.performedByUid !== args.actor.uid ||
      data.requestId !== args.command.commandId ||
      data.resultVersion !== args.receipt.aggregateVersion ||
      args.receipt.result.auditId !== id ||
      parsedObject(data.beforeJson) == null ||
      parsedObject(data.afterJson) == null ||
      !stuckupCase.exists || stuckupCase.data == null ||
      stuckupCase.data.version !== args.receipt.aggregateVersion) {
    throw new WorkflowError(
      "failed-precondition",
      "Furnace stuck-up receipt no longer matches its governed evidence.",
      {reasonCode: "furnace-stuckup-replay-evidence-invalid"},
    );
  }
};

export const furnaceStuckupPaths = {
  casePath,
  constraintPath,
  currentPath,
};
