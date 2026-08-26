import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {
  buildInspectionTargetPopulation,
  inspectionPopulationCounts,
  inspectionTargetDispositionValues,
  inspectionTargetPopulationJson,
  InspectionTargetDisposition,
  parseInspectionTargetPopulation,
  setInspectionTargetDisposition as applyInspectionTargetDisposition,
} from "./inspectionPopulation";
import {JsonMap, RoleKey} from "./types";
import {
  cleanText,
  intValue,
  iso,
  persistedInstantText,
  stableJson,
} from "./utils";

const campaignPath = (id: string): string => `inspection_campaigns/${id}`;
const campaignAuditPath = (id: string): string => `inspection_campaign_audits/${id}`;
const targetAuditPath = (id: string): string => `inspection_target_audits/${id}`;

const exactKeys = (value: JsonMap, expected: readonly string[], field: string): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "inspection-shape-invalid", field},
    );
  }
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." || parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const boundedText = (
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): string => {
  const parsed = cleanText(value, field);
  if (parsed.length < minimum || parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must contain ${minimum}-${maximum} characters.`,
    );
  }
  return parsed;
};

const stringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  maximumLength: number,
): string[] => {
  if (!Array.isArray(value) || value.length > maximumItems ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.trim().length > maximumLength)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  const parsed = value.map((item) => (item as string).trim());
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("invalid-argument", `${field} contains duplicates.`);
  }
  return parsed;
};

const integerList = (value: unknown, field: string): number[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 500 ||
      value.some((item) => !Number.isSafeInteger(item) || (item as number) < 1)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  const parsed = value as number[];
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("invalid-argument", `${field} contains duplicates.`);
  }
  return [...parsed].sort((left, right) => left - right);
};

const writeAudit = (args: {
  readonly tx: Parameters<CommandHandler>[0]["tx"];
  readonly path: string;
  readonly campaignId: string;
  readonly operation: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: string;
  readonly reason: string;
  readonly before: JsonMap;
  readonly after: JsonMap;
}): void => args.tx.create(args.path, {
  schemaVersion: 1,
  auditId: args.path.split("/").at(-1)!,
  campaignId: args.campaignId,
  operation: args.operation,
  performedByUid: args.actorUid,
  performedByName: args.actorName,
  performedAt: args.at,
  reason: args.reason,
  beforeJson: stableJson(args.before),
  afterJson: stableJson(args.after),
});

export const addInspectionCampaignTargets: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["assetNumbers", "physicalPositionLabels", "reason"], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const assetNumbers = integerList(command.payload.assetNumbers, "assetNumbers");
  const physicalPositions = stringList(
    command.payload.physicalPositionLabels,
    "physicalPositionLabels",
    32,
    80,
  );
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [campaign, audit] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(campaignAuditPath(command.commandId)),
  ]);
  if (!campaign.exists || campaign.data == null ||
      campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  if (!['open', 'paused'].includes(String(campaign.data.status)) || audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active inspection campaign can receive targets.",
    );
  }
  const assetClassId = documentId(campaign.data.assetClassId, "campaign.assetClassId");
  const assetTypeKey = cleanText(campaign.data.assetTypeKey, "campaign.assetTypeKey");
  const rows = await tx.query("asset_instances", [
    {field: "assetClassId", op: "==", value: assetClassId},
  ]);
  const byNumber = new Map<number, (typeof rows)[number]>();
  for (const row of rows) {
    if (row.data?.status !== "active" || !Number.isSafeInteger(row.data.assetNumber) ||
        !assetNumbers.includes(row.data.assetNumber as number)) continue;
    const number = row.data.assetNumber as number;
    if (byNumber.has(number)) {
      throw new WorkflowError(
        "failed-precondition",
        "The governed asset class contains duplicate active asset numbers.",
      );
    }
    byNumber.set(number, row);
  }
  const missing = assetNumbers.filter((number) => !byNumber.has(number));
  if (missing.length > 0) {
    throw new WorkflowError(
      "failed-precondition",
      "One or more added targets are absent or inactive.",
      {reasonCode: "inspection-campaign-assets-missing", missingAssetNumbers: missing},
    );
  }
  const definition = campaign.data.definition;
  if (definition == null || typeof definition !== "object" || Array.isArray(definition)) {
    throw new WorkflowError("failed-precondition", "Campaign definition is malformed.");
  }
  const componentNodeIds = Array.isArray((definition as JsonMap).componentNodeIds) ?
    ((definition as JsonMap).componentNodeIds as readonly unknown[])
      .filter((item): item is string => typeof item === "string") : [];
  const now = iso(context.serverNow);
  const additions = buildInspectionTargetPopulation({
    assetTypeKey,
    assetClassId,
    assets: assetNumbers.map((number) => {
      const data = byNumber.get(number)!.data!;
      if (typeof data.assetInstanceId !== "string" || typeof data.name !== "string" ||
          !Number.isSafeInteger(data.version) || (data.version as number) < 1) {
        throw new WorkflowError(
          "failed-precondition",
          "An added inspection asset has malformed identity.",
        );
      }
      return {
        assetNumber: number,
        assetInstanceId: data.assetInstanceId,
        assetInstanceVersion: data.version as number,
        assetInstanceName: data.name,
      };
    }),
    componentNodeIds,
    physicalPositions,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    addedLater: true,
  });
  const currentTargets = parseInspectionTargetPopulation(campaign.data.targetPopulation);
  const currentKeys = new Set(currentTargets.map((target) => target.targetKey));
  const novel = additions.filter((target) => !currentKeys.has(target.targetKey));
  if (novel.length === 0 || currentTargets.length + novel.length > 500) {
    throw new WorkflowError(
      "failed-precondition",
      novel.length === 0 ?
        "Every requested target already belongs to this campaign." :
        "The campaign target population would exceed its governed limit.",
    );
  }
  const nextTargets = [...currentTargets, ...novel]
    .sort((left, right) => left.targetKey.localeCompare(right.targetKey));
  const priorNumbers = Array.isArray(campaign.data.targetAssetNumbers) ?
    campaign.data.targetAssetNumbers.filter((item): item is number =>
      Number.isSafeInteger(item)) : [];
  const targetAssetNumbers = [...new Set([...priorNumbers, ...assetNumbers])]
    .sort((left, right) => left - right);
  const priorPositions = Array.isArray(campaign.data.physicalPositionLabels) ?
    campaign.data.physicalPositionLabels.filter((item): item is string =>
      typeof item === "string") : [];
  const physicalPositionLabels = [...new Set([...priorPositions, ...physicalPositions])]
    .sort((left, right) => left.localeCompare(right));
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    version: nextVersion,
    targetAssetNumbers,
    physicalPositionLabels,
    expectedPopulation: nextTargets.length,
    targetPopulation: inspectionTargetPopulationJson(nextTargets),
    targetDispositionCounts: inspectionPopulationCounts(nextTargets),
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.update(campaignPath(campaignId), update);
  writeAudit({
    tx,
    path: campaignAuditPath(command.commandId),
    campaignId,
    operation: "add-targets",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: campaign.data,
    after: {...campaign.data, ...update},
  });
  return {
    resultKey: "inspection-campaign-targets-added",
    aggregateVersion: nextVersion,
    result: {
      campaignId,
      addedTargetCount: novel.length,
      expectedPopulation: nextTargets.length,
    },
  };
};

export const setInspectionTargetDisposition: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["targetKey", "disposition", "reason"], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const targetKey = boundedText(command.payload.targetKey, "targetKey", 3, 520);
  const disposition = cleanText(command.payload.disposition, "disposition");
  if (disposition === "observed" ||
      !inspectionTargetDispositionValues.has(disposition as never)) {
    throw new WorkflowError("invalid-argument", "Target disposition is unsupported.");
  }
  const reason = disposition === "pending" ? null :
    boundedText(command.payload.reason, "reason", 5, 500);
  if (disposition === "pending" && command.payload.reason != null &&
      (typeof command.payload.reason !== "string" ||
       command.payload.reason.trim().length > 0)) {
    throw new WorkflowError("invalid-argument", "Pending disposition must not carry a reason.");
  }
  const [campaign, audit] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(targetAuditPath(command.commandId)),
  ]);
  if (!campaign.exists || campaign.data == null ||
      campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  if (!['open', 'paused'].includes(String(campaign.data.status)) || audit.exists) {
    throw new WorkflowError("failed-precondition", "Target disposition cannot be changed now.");
  }
  const targets = parseInspectionTargetPopulation(campaign.data.targetPopulation);
  const beforeTarget = targets.find((target) => target.targetKey === targetKey);
  const now = iso(context.serverNow);
  const updated = applyInspectionTargetDisposition({
    targets,
    targetKey,
    disposition: disposition as Exclude<InspectionTargetDisposition, "observed">,
    reason,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  });
  const afterTarget = updated.find((target) => target.targetKey === targetKey)!;
  if (beforeTarget?.disposition === afterTarget.disposition &&
      beforeTarget.dispositionReason === afterTarget.dispositionReason) {
    throw new WorkflowError("failed-precondition", "Target disposition did not change.");
  }
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    version: nextVersion,
    targetPopulation: inspectionTargetPopulationJson(updated),
    targetDispositionCounts: inspectionPopulationCounts(updated),
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.update(campaignPath(campaignId), update);
  writeAudit({
    tx,
    path: targetAuditPath(command.commandId),
    campaignId,
    operation: `target-${disposition}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason: reason ?? "Return the target to the pending population.",
    before: beforeTarget == null ? {} : {...beforeTarget},
    after: {...afterTarget},
  });
  return {
    resultKey: `inspection-target-${disposition}`,
    aggregateVersion: nextVersion,
    result: {campaignId, targetKey, disposition},
  };
};

const findingObserverAuthorized = (campaign: JsonMap, roles: ReadonlySet<RoleKey>): boolean => {
  if (roles.has("admin") || roles.has("si")) return true;
  const observerRoles = campaign.observerRoleKeys;
  return Array.isArray(observerRoles) &&
    [...roles].some((role) => observerRoles.includes(role));
};

export const verifyInspectionFinding: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, [
    "findingId",
    "observationId",
    "expectedFindingVersion",
    "outcome",
    "reason",
  ], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const findingId = documentId(command.payload.findingId, "findingId");
  const observationId = documentId(command.payload.observationId, "observationId");
  const expectedFindingVersion = intValue(
    command.payload.expectedFindingVersion,
    "expectedFindingVersion",
    1,
  );
  const outcome = cleanText(command.payload.outcome, "outcome");
  if (!["improved", "unchanged", "deteriorated", "resolved", "recurred", "notComparable"]
    .includes(outcome)) {
    throw new WorkflowError("invalid-argument", "Verification outcome is unsupported.");
  }
  const reason = boundedText(command.payload.reason, "reason", 5, 1000);
  const [campaign, finding, observation, verification] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(`inspection_findings/${findingId}`),
    tx.get(`inspection_observations/${observationId}`),
    tx.get(`inspection_verifications/${command.commandId}`),
  ]);
  if (!campaign.exists || campaign.data == null ||
      campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  if (!findingObserverAuthorized(campaign.data, context.actor.roles)) {
    throw new WorkflowError("permission-denied", "Actor cannot verify this finding.");
  }
  if (!finding.exists || finding.data == null || finding.data.campaignId !== campaignId ||
      !observation.exists || observation.data == null ||
      observation.data.campaignId !== campaignId || verification.exists) {
    throw new WorkflowError("failed-precondition", "Finding verification evidence is unavailable.");
  }
  const currentFindingVersion = intValue(
    finding.data.version,
    "finding.version",
    1,
  );
  const verificationCount = intValue(
    finding.data.verificationCount,
    "finding.verificationCount",
  );
  if (currentFindingVersion !== expectedFindingVersion) {
    throw new WorkflowError("aborted", "Inspection finding is missing or changed.");
  }
  const lastVerificationId = finding.data.lastVerificationId;
  const lastVerification = typeof lastVerificationId === "string" ?
    await tx.get(`inspection_verifications/${documentId(
      lastVerificationId,
      "lastVerificationId",
    )}`) : null;
  const priorVerificationIncomplete = verificationCount > 0 &&
    (lastVerification == null || !lastVerification.exists || lastVerification.data == null ||
      lastVerification.data.verificationId !== lastVerificationId ||
      lastVerification.data.findingId !== findingId ||
      lastVerification.data.campaignId !== campaignId ||
      typeof lastVerification.data.observationId !== "string");
  const unexpectedPriorVerification = verificationCount === 0 &&
    (lastVerificationId != null ||
      finding.data.lastVerifiedObservationId != null ||
      finding.data.lastVerificationOutcome != null);
  if (priorVerificationIncomplete || unexpectedPriorVerification) {
    throw new WorkflowError(
      "failed-precondition",
      "Prior inspection verification evidence is incomplete.",
    );
  }
  const latestObservedAt = persistedInstantText(
    finding.data.latestObservedAt,
  );
  const observedAt = persistedInstantText(observation.data.observedAt);
  const firstObservedAt = persistedInstantText(finding.data.firstObservedAt);
  if (finding.data.targetKey !== observation.data.targetKey ||
      finding.data.currentObservationId !== observationId ||
      latestObservedAt == null || observedAt == null || firstObservedAt == null ||
      latestObservedAt !== observedAt ||
      Date.parse(observedAt) <= Date.parse(firstObservedAt)) {
    throw new WorkflowError(
      "failed-precondition",
      "Verification must use the current latest observation of the same governed target.",
    );
  }
  if (finding.data.lastVerifiedObservationId === observationId ||
      lastVerification?.data?.observationId === observationId) {
    throw new WorkflowError(
      "failed-precondition",
      "The current inspection observation already has an authoritative verification decision.",
    );
  }
  if (outcome === "resolved" && observation.data.outOfRange === true) {
    throw new WorkflowError(
      "failed-precondition",
      "An out-of-range observation cannot verify a resolved finding.",
    );
  }
  if (outcome === "resolved" && typeof finding.data.linkedTicketId === "string") {
    const ticket = await tx.get(`maintenance_records/${finding.data.linkedTicketId}`);
    if (!ticket.exists || ticket.data?.isResolved !== true) {
      throw new WorkflowError(
        "failed-precondition",
        "Linked corrective maintenance must be resolved before verification closure.",
      );
    }
  }
  const now = iso(context.serverNow);
  const status = outcome === "resolved" ? "verifiedResolved" :
    outcome === "notComparable" ? "awaitingVerification" : "open";
  const version = currentFindingVersion + 1;
  tx.create(`inspection_verifications/${command.commandId}`, {
    schemaVersion: 1,
    verificationId: command.commandId,
    findingId,
    campaignId,
    observationId,
    outcome,
    reason,
    verifiedAt: now,
    verifiedByUid: context.actor.uid,
    verifiedByName: context.actor.name,
  });
  tx.create(`inspection_finding_events/${command.commandId}`, {
    schemaVersion: 1,
    eventId: command.commandId,
    findingId,
    campaignId,
    operation: "verify",
    previousStatus: finding.data.status,
    resultingStatus: status,
    observationId,
    outcome,
    performedAt: now,
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
  });
  tx.update(`inspection_findings/${findingId}`, {
    version,
    status,
    currentObservationId: observationId,
    latestObservedAt: observation.data.observedAt,
    verificationCount: verificationCount + 1,
    lastVerificationId: command.commandId,
    lastVerifiedObservationId: observationId,
    lastVerificationOutcome: outcome,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  });
  return {
    resultKey: `inspection-finding-${status}`,
    aggregateVersion: command.expectedVersion,
    result: {
      campaignId,
      findingId,
      findingVersion: version,
      observationId,
      outcome,
      status,
    },
  };
};

export const adjudicateInspectionFinding: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["findingId", "status", "reason"], "payload");
  const campaignId = documentId(command.aggregateId, "aggregateId");
  const findingId = documentId(command.payload.findingId, "findingId");
  const status = cleanText(command.payload.status, "status");
  if (!["acceptedCondition", "invalidated", "open"].includes(status)) {
    throw new WorkflowError("invalid-argument", "Finding adjudication status is unsupported.");
  }
  const reason = boundedText(command.payload.reason, "reason", 10, 1000);
  const [campaign, finding, event] = await Promise.all([
    tx.get(campaignPath(campaignId)),
    tx.get(`inspection_findings/${findingId}`),
    tx.get(`inspection_finding_events/${command.commandId}`),
  ]);
  if (!campaign.exists || campaign.data == null ||
      campaign.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "Inspection campaign is missing or changed.");
  }
  if (!finding.exists || finding.data == null || finding.data.campaignId !== campaignId ||
      event.exists || finding.data.status === status) {
    throw new WorkflowError("failed-precondition", "Finding adjudication is not valid.");
  }
  const now = iso(context.serverNow);
  const version = Number(finding.data.version ?? 0) + 1;
  tx.create(`inspection_finding_events/${command.commandId}`, {
    schemaVersion: 1,
    eventId: command.commandId,
    findingId,
    campaignId,
    operation: "adjudicate",
    previousStatus: finding.data.status,
    resultingStatus: status,
    reason,
    performedAt: now,
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
  });
  tx.update(`inspection_findings/${findingId}`, {
    version,
    status,
    adjudicationReason: reason,
    adjudicatedAt: now,
    adjudicatedByUid: context.actor.uid,
    adjudicatedByName: context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  });
  return {
    resultKey: `inspection-finding-${status}`,
    aggregateVersion: command.expectedVersion,
    result: {campaignId, findingId, status},
  };
};
