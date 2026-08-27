import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {CRITICAL_ALARM_DEFINITIONS} from "./policy.generated";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
  WorkflowCommandType,
} from "./types";
import {WorkflowTransaction} from "./store";
import {
  cleanText,
  intValue,
  iso,
  persistedInstantText,
  stableJson,
} from "./utils";

const ALARM_STATUSES = new Set([
  "raised", "supportConfirmed", "resolved", "withdrawnInError",
]);
const CONTACT_STATUSES = new Set(["active", "retired"]);
const DEFINITION_STATUSES = new Set(["active", "retired"]);
const CONTACT_KINDS = new Set(["mobile", "landline", "plantExtension"]);
const SUPPORT_BASES = new Set([
  "supportDispatched", "supportAlreadyPresent", "raiserContactedDirectly",
]);
const ALARM_FIELDS = [
  "schemaVersion", "alarmId", "alarmTypeKey", "alarmTypeName",
  "criticalityKey", "criticalityRank", "status", "version", "location",
  "assetTypeKey", "assetNumber", "details", "detailsPending",
  "raisedByUid", "raisedByName", "raisedAt", "detailsProvidedByUid",
  "detailsProvidedByName", "detailsProvidedAt", "supportBasis",
  "supportNote", "supportConfirmedByUid", "supportConfirmedByName",
  "supportConfirmedAt", "resolutionSummary", "resolvedByUid",
  "resolvedByName", "resolvedAt", "withdrawalReason", "withdrawnByUid",
  "withdrawnByName", "withdrawnAt", "createdAt", "updatedAt",
] as const;
const CONTACT_FIELDS = [
  "schemaVersion", "contactId", "version", "status", "label",
  "contactKind", "dialValue", "alarmTypeKeys", "priority", "notes",
  "createdAt", "createdByUid", "createdByName", "updatedAt",
  "updatedByUid", "updatedByName",
] as const;
const DEFINITION_FIELDS = [
  "schemaVersion", "definitionId", "version", "status", "name",
  "criticalityKey", "criticalityRank", "createdAt", "createdByUid",
  "createdByName", "updatedAt", "updatedByUid", "updatedByName",
] as const;
const ALARM_COMMANDS = new Set<WorkflowCommandType>([
  "raiseCriticalAlarm", "provideCriticalAlarmDetails",
  "confirmCriticalAlarmSupport", "resolveCriticalAlarm",
  "withdrawCriticalAlarmInError",
]);
const CONTACT_COMMANDS = new Set<WorkflowCommandType>([
  "upsertCriticalAlarmContact", "setCriticalAlarmContactStatus",
]);
const DEFINITION_COMMANDS = new Set<WorkflowCommandType>([
  "upsertCriticalAlarmDefinition", "setCriticalAlarmDefinitionStatus",
]);
const OPERATION_BY_COMMAND: Partial<Record<WorkflowCommandType, string>> = {
  raiseCriticalAlarm: "raise",
  provideCriticalAlarmDetails: "provide-details",
  confirmCriticalAlarmSupport: "confirm-support",
  resolveCriticalAlarm: "resolve",
  withdrawCriticalAlarmInError: "withdraw-in-error",
  upsertCriticalAlarmContact: "create-contact",
  setCriticalAlarmContactStatus: "retired-contact",
  upsertCriticalAlarmDefinition: "create-definition",
  setCriticalAlarmDefinitionStatus: "retired-definition",
};
const RESULT_KEY_BY_COMMAND: Partial<Record<WorkflowCommandType, string>> = {
  raiseCriticalAlarm: "critical-alarm-raised",
  provideCriticalAlarmDetails: "critical-alarm-details-provided",
  confirmCriticalAlarmSupport: "critical-alarm-support-confirmed",
  resolveCriticalAlarm: "critical-alarm-resolved",
  withdrawCriticalAlarmInError: "critical-alarm-withdrawn-in-error",
};
const EVENT_TYPE_BY_COMMAND: Partial<Record<WorkflowCommandType, string>> = {
  raiseCriticalAlarm: "criticalAlarm.raised",
  provideCriticalAlarmDetails: "criticalAlarm.detailsProvided",
  confirmCriticalAlarmSupport: "criticalAlarm.supportConfirmed",
  resolveCriticalAlarm: "criticalAlarm.resolved",
  withdrawCriticalAlarmInError: "criticalAlarm.withdrawnInError",
};

const alarmPath = (id: string): string => `critical_alarms/${id}`;
const contactPath = (id: string): string => `critical_alarm_contacts/${id}`;
const definitionPath = (id: string): string =>
  `critical_alarm_definitions/${id}`;
const alarmAuditPath = (commandId: string): string =>
  `critical_alarm_audits/${commandId}`;
const contactAuditPath = (commandId: string): string =>
  `critical_alarm_contact_audits/${commandId}`;
const definitionAuditPath = (commandId: string): string =>
  `critical_alarm_definition_audits/${commandId}`;

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "critical-alarm-shape-invalid", field},
    );
  }
};

const record = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be an object.`);
  }
  return value as JsonMap;
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." ||
      parsed.includes("/")) {
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

const optionalText = (
  value: unknown,
  field: string,
  maximum: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
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

const choice = (
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string => {
  const parsed = cleanText(value, field);
  if (!allowed.has(parsed)) {
    throw new WorkflowError("invalid-argument", `${field} is unsupported.`);
  }
  return parsed;
};

const baselineAlarmDefinition = (value: unknown) => {
  const key = cleanText(value, "alarmTypeKey");
  const definition = CRITICAL_ALARM_DEFINITIONS[key];
  return {key, definition};
};

const hasExactKeys = (
  value: JsonMap,
  expected: readonly string[],
): boolean => Object.keys(value).sort().join(",") ===
  [...expected].sort().join(",");

const isStoredText = (
  value: unknown,
  minimum: number,
  maximum: number,
): value is string => typeof value === "string" &&
  value === value.trim() && value.length >= minimum && value.length <= maximum;

const isIsoInstant = (value: unknown): value is string => {
  if (typeof value !== "string") return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString() === value;
};

const normalizeStoredInstants = (
  data: JsonMap,
  fields: readonly string[],
  malformed: () => never,
): JsonMap => {
  const normalized = {...data};
  for (const field of fields) {
    if (normalized[field] == null) continue;
    const text = persistedInstantText(normalized[field]);
    if (text == null) malformed();
    normalized[field] = text;
  }
  return normalized;
};

const allNull = (data: JsonMap, fields: readonly string[]): boolean =>
  fields.every((field) => data[field] === null);

const occursBetween = (
  value: unknown,
  earliest: unknown,
  latest: unknown,
): boolean => isIsoInstant(value) && isIsoInstant(earliest) &&
  isIsoInstant(latest) && Date.parse(value) >= Date.parse(earliest) &&
  Date.parse(value) <= Date.parse(latest);

const failMalformedAlarm = (): never => {
  throw new WorkflowError(
    "failed-precondition",
    "The critical-alarm record is malformed.",
    {reasonCode: "critical-alarm-record-malformed"},
  );
};

const normalizedAlarm = (data: JsonMap): JsonMap => normalizeStoredInstants(
  data,
  [
    "raisedAt", "detailsProvidedAt", "supportConfirmedAt", "resolvedAt",
    "withdrawnAt", "createdAt", "updatedAt",
  ],
  failMalformedAlarm,
);

const assertCanonicalAlarm = (data: JsonMap, alarmId: string): void => {
  const criticalityValid =
    (data.criticalityKey === "highest" && data.criticalityRank === 1) ||
    (data.criticalityKey === "critical" && data.criticalityRank === 2);
  const assetAbsent = data.assetTypeKey === null && data.assetNumber === null;
  const assetComplete = isStoredText(data.assetTypeKey, 1, 80) &&
    Number.isSafeInteger(data.assetNumber) && (data.assetNumber as number) >= 1;
  const detailEvidenceFields = [
    "detailsProvidedByUid", "detailsProvidedByName", "detailsProvidedAt",
  ] as const;
  const detailsAbsent = data.details === null && data.detailsPending === true &&
    allNull(data, detailEvidenceFields);
  const detailsComplete = isStoredText(data.details, 5, 2000) &&
    data.detailsPending === false &&
    isStoredText(data.detailsProvidedByUid, 1, 256) &&
    isStoredText(data.detailsProvidedByName, 1, 256) &&
    isIsoInstant(data.detailsProvidedAt);
  const supportFields = [
    "supportBasis", "supportNote", "supportConfirmedByUid",
    "supportConfirmedByName", "supportConfirmedAt",
  ] as const;
  const supportAbsent = allNull(data, supportFields);
  const supportComplete = typeof data.supportBasis === "string" &&
    SUPPORT_BASES.has(data.supportBasis) &&
    isStoredText(data.supportNote, 5, 1000) &&
    isStoredText(data.supportConfirmedByUid, 1, 256) &&
    isStoredText(data.supportConfirmedByName, 1, 256) &&
    isIsoInstant(data.supportConfirmedAt);
  const resolutionFields = [
    "resolutionSummary", "resolvedByUid", "resolvedByName", "resolvedAt",
  ] as const;
  const resolutionAbsent = allNull(data, resolutionFields);
  const resolutionComplete = isStoredText(data.resolutionSummary, 5, 2000) &&
    isStoredText(data.resolvedByUid, 1, 256) &&
    isStoredText(data.resolvedByName, 1, 256) && isIsoInstant(data.resolvedAt);
  const withdrawalFields = [
    "withdrawalReason", "withdrawnByUid", "withdrawnByName", "withdrawnAt",
  ] as const;
  const withdrawalAbsent = allNull(data, withdrawalFields);
  const withdrawalComplete = isStoredText(data.withdrawalReason, 5, 1000) &&
    isStoredText(data.withdrawnByUid, 1, 256) &&
    isStoredText(data.withdrawnByName, 1, 256) && isIsoInstant(data.withdrawnAt);
  const lifecycleValid = data.status === "raised" ?
    supportAbsent && resolutionAbsent && withdrawalAbsent :
    data.status === "supportConfirmed" ?
      supportComplete && resolutionAbsent && withdrawalAbsent :
      data.status === "resolved" ?
        supportComplete && resolutionComplete && withdrawalAbsent :
        data.status === "withdrawnInError" ?
          (supportAbsent || supportComplete) && resolutionAbsent &&
            withdrawalComplete : false;
  const chronologyValid = data.raisedAt === data.createdAt &&
    occursBetween(data.updatedAt, data.createdAt, data.updatedAt) &&
    (detailsAbsent || occursBetween(
      data.detailsProvidedAt,
      data.raisedAt,
      data.updatedAt,
    )) &&
    (supportAbsent || occursBetween(
      data.supportConfirmedAt,
      data.raisedAt,
      data.updatedAt,
    )) &&
    (resolutionAbsent || (
      occursBetween(data.resolvedAt, data.supportConfirmedAt, data.updatedAt)
    )) &&
    (withdrawalAbsent || (
      occursBetween(data.withdrawnAt, data.raisedAt, data.updatedAt) &&
      (supportAbsent || occursBetween(
        data.withdrawnAt,
        data.supportConfirmedAt,
        data.updatedAt,
      ))
    ));
  if (!hasExactKeys(data, ALARM_FIELDS) || data.schemaVersion !== 1 ||
      data.alarmId !== alarmId ||
      !isStoredText(data.alarmTypeKey, 1, 160) ||
      !isStoredText(data.alarmTypeName, 2, 120) || !criticalityValid ||
      typeof data.status !== "string" || !ALARM_STATUSES.has(data.status) ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1 ||
      !isStoredText(data.location, 2, 160) ||
      (!assetAbsent && !assetComplete) ||
      (!detailsAbsent && !detailsComplete) ||
      !isStoredText(data.raisedByUid, 1, 256) ||
      !isStoredText(data.raisedByName, 1, 256) ||
      !isIsoInstant(data.raisedAt) || !isIsoInstant(data.createdAt) ||
      !isIsoInstant(data.updatedAt) ||
      !chronologyValid || !lifecycleValid) {
    failMalformedAlarm();
  }
};

const failMalformedContact = (): never => {
  throw new WorkflowError(
    "failed-precondition",
    "The critical-alarm contact is malformed.",
    {reasonCode: "critical-alarm-contact-malformed"},
  );
};

const normalizedContact = (data: JsonMap): JsonMap => normalizeStoredInstants(
  data,
  ["createdAt", "updatedAt"],
  failMalformedContact,
);

const assertCanonicalContact = (data: JsonMap, contactId: string): void => {
  const keys = data.alarmTypeKeys;
  const kind = data.contactKind;
  const dial = data.dialValue;
  const dialValid = typeof dial === "string" &&
    (kind === "plantExtension" ? /^\d{2,8}$/.test(dial) :
      /^\+?\d{5,15}$/.test(dial));
  if (!hasExactKeys(data, CONTACT_FIELDS) || data.schemaVersion !== 1 ||
      data.contactId !== contactId ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1 ||
      typeof data.status !== "string" || !CONTACT_STATUSES.has(data.status) ||
      !isStoredText(data.label, 2, 120) ||
      typeof kind !== "string" || !CONTACT_KINDS.has(kind) || !dialValid ||
      !Array.isArray(keys) || keys.length < 1 || keys.length > 20 ||
      keys.some((key) => !isStoredText(key, 1, 160)) ||
      new Set(keys).size !== keys.length ||
      !Number.isSafeInteger(data.priority) || (data.priority as number) < 1 ||
      (data.priority as number) > 99 ||
      !(data.notes === null || isStoredText(data.notes, 1, 500)) ||
      !isIsoInstant(data.createdAt) || !isIsoInstant(data.updatedAt) ||
      !isStoredText(data.createdByUid, 1, 256) ||
      !isStoredText(data.createdByName, 1, 256) ||
      !isStoredText(data.updatedByUid, 1, 256) ||
      !isStoredText(data.updatedByName, 1, 256) ||
      Date.parse(data.updatedAt as string) < Date.parse(data.createdAt as string)) {
    failMalformedContact();
  }
};

const failMalformedDefinition = (): never => {
  throw new WorkflowError(
    "failed-precondition",
    "The critical-alarm definition is malformed.",
    {reasonCode: "critical-alarm-definition-malformed"},
  );
};

const normalizedDefinition = (data: JsonMap): JsonMap =>
  normalizeStoredInstants(
    data,
    ["createdAt", "updatedAt"],
    failMalformedDefinition,
  );

const assertCanonicalDefinition = (
  data: JsonMap,
  definitionId: string,
): void => {
  const criticalityValid =
    (data.criticalityKey === "highest" && data.criticalityRank === 1) ||
    (data.criticalityKey === "critical" && data.criticalityRank === 2);
  if (!hasExactKeys(data, DEFINITION_FIELDS) || data.schemaVersion !== 1 ||
      data.definitionId !== definitionId ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1 ||
      typeof data.status !== "string" ||
      !DEFINITION_STATUSES.has(data.status) ||
      !isStoredText(data.name, 2, 120) || !criticalityValid ||
      !isIsoInstant(data.createdAt) || !isIsoInstant(data.updatedAt) ||
      !isStoredText(data.createdByUid, 1, 256) ||
      !isStoredText(data.createdByName, 1, 256) ||
      !isStoredText(data.updatedByUid, 1, 256) ||
      !isStoredText(data.updatedByName, 1, 256) ||
      Date.parse(data.updatedAt as string) <
        Date.parse(data.createdAt as string)) {
    failMalformedDefinition();
  }
};

const activeAlarmDefinition = async (
  tx: WorkflowTransaction,
  value: unknown,
): Promise<Readonly<{
  key: string;
  name: string;
  criticalityKey: "highest" | "critical";
  criticalityRank: number;
}>> => {
  const {key, definition: baseline} = baselineAlarmDefinition(value);
  const snapshot = await tx.get(definitionPath(key));
  if (!snapshot.exists) {
    if (baseline == null) {
      throw new WorkflowError(
        "invalid-argument",
        "alarmTypeKey is not in the governed critical-alarm catalogue.",
        {reasonCode: "critical-alarm-type-unsupported"},
      );
    }
    return baseline;
  }
  if (snapshot.data == null) failMalformedDefinition();
  const data = normalizedDefinition(snapshot.data as JsonMap);
  assertCanonicalDefinition(data, key);
  if (data.status !== "active") {
    throw new WorkflowError(
      "failed-precondition",
      "The selected critical-alarm reason is retired.",
      {reasonCode: "critical-alarm-type-retired"},
    );
  }
  return {
    key,
    name: data.name as string,
    criticalityKey: data.criticalityKey as "highest" | "critical",
    criticalityRank: data.criticalityRank as number,
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

const replayInvalid = (): never => {
  throw new WorkflowError(
    "failed-precondition",
    "Critical-safety receipt no longer matches its governed evidence.",
    {reasonCode: "critical-alarm-replay-evidence-invalid"},
  );
};

export const verifyCriticalAlarmReplay = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  const isAlarm = ALARM_COMMANDS.has(args.command.commandType);
  const isContact = CONTACT_COMMANDS.has(args.command.commandType);
  const isDefinition = DEFINITION_COMMANDS.has(args.command.commandType);
  if (!isAlarm && !isContact && !isDefinition) return;
  const auditCollection = isAlarm ?
    "critical_alarm_audits" : isContact ?
      "critical_alarm_contact_audits" :
      "critical_alarm_definition_audits";
  const audit = await args.tx.get(
    `${auditCollection}/${args.command.commandId}`,
  );
  const data = audit.data;
  const before = parsedAuditObject(data?.beforeJson);
  const after = parsedAuditObject(data?.afterJson);
  const expectedOperation = OPERATION_BY_COMMAND[args.command.commandType];
  const expectedResultKey = RESULT_KEY_BY_COMMAND[args.command.commandType];
  if (!audit.exists || data == null || before == null || after == null) {
    replayInvalid();
  }
  const auditData = data as JsonMap;
  const afterData = after as JsonMap;
  if (auditData.schemaVersion !== 1 ||
      auditData.auditId !== args.command.commandId ||
      auditData.aggregateId !== args.command.aggregateId ||
      auditData.performedByUid !== args.actor.uid ||
      persistedInstantText(auditData.performedAt) !== args.receipt.appliedAt ||
      afterData.version !== args.receipt.aggregateVersion ||
      args.receipt.commandId !== args.command.commandId ||
      (expectedResultKey != null &&
        args.receipt.resultKey !== expectedResultKey)) {
    replayInvalid();
  }
  if (args.command.commandType === "upsertCriticalAlarmContact") {
    const expectedDynamicOperation = args.command.expectedVersion === 0 ?
      "create-contact" : "update-contact";
    const expectedDynamicResult = args.command.expectedVersion === 0 ?
      "critical-alarm-contact-created" : "critical-alarm-contact-updated";
    if (auditData.operation !== expectedDynamicOperation ||
        args.receipt.resultKey !== expectedDynamicResult) replayInvalid();
  } else if (args.command.commandType === "setCriticalAlarmContactStatus") {
    const requestedStatus = args.command.payload.status;
    if (typeof requestedStatus !== "string" ||
        auditData.operation !== `${requestedStatus}-contact` ||
        args.receipt.resultKey !== `critical-alarm-contact-${requestedStatus}`) {
      replayInvalid();
    }
  } else if (args.command.commandType === "upsertCriticalAlarmDefinition") {
    const expectedDynamicOperation = args.command.expectedVersion === 0 ?
      "create-definition" : "update-definition";
    const expectedDynamicResult = args.command.expectedVersion === 0 ?
      "critical-alarm-definition-created" :
      "critical-alarm-definition-updated";
    if (auditData.operation !== expectedDynamicOperation ||
        args.receipt.resultKey !== expectedDynamicResult) replayInvalid();
  } else if (
    args.command.commandType === "setCriticalAlarmDefinitionStatus"
  ) {
    const requestedStatus = args.command.payload.status;
    if (typeof requestedStatus !== "string" ||
        auditData.operation !== `${requestedStatus}-definition` ||
        args.receipt.resultKey !==
          `critical-alarm-definition-${requestedStatus}`) {
      replayInvalid();
    }
  } else if (auditData.operation !== expectedOperation) {
    replayInvalid();
  }

  const identityResult = isAlarm ?
    args.receipt.result.alarmId : isContact ?
      args.receipt.result.contactId : args.receipt.result.definitionId;
  const expectedStatus = args.receipt.result.status;
  if (identityResult !== args.command.aggregateId ||
      expectedStatus !== afterData.status) replayInvalid();
  if (isAlarm) assertCanonicalAlarm(afterData, args.command.aggregateId);
  else if (isContact) {
    assertCanonicalContact(afterData, args.command.aggregateId);
  } else {
    assertCanonicalDefinition(afterData, args.command.aggregateId);
  }

  const current = await args.tx.get(
    isAlarm ? alarmPath(args.command.aggregateId) :
      isContact ? contactPath(args.command.aggregateId) :
        definitionPath(args.command.aggregateId),
  );
  if (!current.exists || current.data == null ||
      !Number.isSafeInteger(current.data.version) ||
      (current.data.version as number) < args.receipt.aggregateVersion) {
    replayInvalid();
  }
  const currentData = isAlarm ?
    normalizedAlarm(current.data as JsonMap) :
    isContact ? normalizedContact(current.data as JsonMap) :
      normalizedDefinition(current.data as JsonMap);
  if (isAlarm) assertCanonicalAlarm(currentData, args.command.aggregateId);
  else if (isContact) {
    assertCanonicalContact(currentData, args.command.aggregateId);
  } else {
    assertCanonicalDefinition(currentData, args.command.aggregateId);
  }

  if (isAlarm) {
    const event = await args.tx.get(
      `maintenance_workflow_events/${args.command.commandId}`,
    );
    const eventData = event.data;
    if (!event.exists || eventData == null ||
        eventData.aggregateId !== args.command.aggregateId ||
        eventData.commandId !== args.command.commandId ||
        eventData.actorUid !== args.actor.uid ||
        persistedInstantText(eventData.occurredAt) !== args.receipt.appliedAt ||
        eventData.eventType !== EVENT_TYPE_BY_COMMAND[args.command.commandType]) {
      replayInvalid();
    }
  }
};

const assertVersion = (data: JsonMap, expected: number): number => {
  if (!Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new WorkflowError(
      "failed-precondition",
      "The critical-alarm record is malformed.",
      {reasonCode: "critical-alarm-record-malformed"},
    );
  }
  if (data.version !== expected) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "The critical alarm changed before this request.",
      {reasonCode: "critical-alarm-version-conflict"},
    );
  }
  return expected;
};

const requireAlarm = async (
  tx: Parameters<CommandHandler>[0]["tx"],
  alarmId: string,
): Promise<JsonMap> => {
  const snapshot = await tx.get(alarmPath(alarmId));
  if (!snapshot.exists || snapshot.data == null) {
    throw new WorkflowError("not-found", "Critical alarm was not found.");
  }
  const data = normalizedAlarm(snapshot.data);
  assertCanonicalAlarm(data, alarmId);
  return data;
};

const requireVacantAudit = async (
  tx: Parameters<CommandHandler>[0]["tx"],
  path: string,
): Promise<void> => {
  if ((await tx.get(path)).exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Critical-alarm audit evidence exists without its command receipt.",
      {reasonCode: "critical-alarm-audit-orphan"},
    );
  }
};

const writeAudit = (args: {
  tx: Parameters<CommandHandler>[0]["tx"];
  path: string;
  commandId: string;
  aggregateId: string;
  operation: string;
  actorUid: string;
  actorName: string;
  at: string;
  reason: string;
  before: JsonMap;
  after: JsonMap;
}): void => args.tx.create(args.path, {
  schemaVersion: 1,
  auditId: args.commandId,
  aggregateId: args.aggregateId,
  operation: args.operation,
  performedByUid: args.actorUid,
  performedByName: args.actorName,
  performedAt: args.at,
  reason: args.reason,
  beforeJson: stableJson(args.before),
  afterJson: stableJson(args.after),
});

const alarmEvent = (args: {
  tx: Parameters<CommandHandler>[0]["tx"];
  commandId: string;
  alarmId: string;
  eventType: string;
  context: Parameters<CommandHandler>[0]["context"];
  alarm: JsonMap;
}): void => {
  const plan = eventPlan({
    aggregateId: args.alarmId,
    eventId: args.commandId,
    eventType: args.eventType,
    actor: args.context.actor,
    at: args.context.serverNow,
    commandId: args.commandId,
    payload: {
      alarmId: args.alarmId,
      alarmTypeKey: args.alarm.alarmTypeKey,
      alarmTypeName: args.alarm.alarmTypeName,
      criticalityKey: args.alarm.criticalityKey,
      criticalityRank: args.alarm.criticalityRank,
      status: args.alarm.status,
      location: args.alarm.location,
      detailsPending: args.alarm.detailsPending,
    },
  });
  args.tx.create(plan.path, plan.data);
};

export const raiseCriticalAlarm: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, [
    "alarmTypeKey", "location", "assetTypeKey", "assetNumber", "initialDetails",
  ], "payload");
  const alarmId = documentId(command.aggregateId, "aggregateId");
  if (command.expectedVersion !== 0) {
    throw new WorkflowError(
      "invalid-argument",
      "A new critical alarm must use expectedVersion 0.",
    );
  }
  const definition = await activeAlarmDefinition(
    tx,
    command.payload.alarmTypeKey,
  );
  const location = boundedText(command.payload.location, "location", 2, 160);
  const details = optionalText(
    command.payload.initialDetails,
    "initialDetails",
    2000,
  );
  if (details != null && details.length < 5) {
    throw new WorkflowError(
      "invalid-argument",
      "initialDetails must contain at least 5 characters when supplied.",
    );
  }
  const assetTypeKey = optionalText(
    command.payload.assetTypeKey,
    "assetTypeKey",
    80,
  );
  const rawAssetNumber = command.payload.assetNumber;
  const assetNumber = rawAssetNumber == null ? null :
    intValue(rawAssetNumber, "assetNumber", 1);
  if ((assetTypeKey == null) !== (assetNumber == null)) {
    throw new WorkflowError(
      "invalid-argument",
      "assetTypeKey and assetNumber must be supplied together.",
    );
  }
  const [current] = await Promise.all([
    tx.get(alarmPath(alarmId)),
    requireVacantAudit(tx, alarmAuditPath(command.commandId)),
  ]);
  if (current.exists) {
    throw new WorkflowError("already-exists", "Critical alarm already exists.");
  }
  const now = iso(context.serverNow);
  const after: JsonMap = {
    schemaVersion: 1,
    alarmId,
    alarmTypeKey: definition.key,
    alarmTypeName: definition.name,
    criticalityKey: definition.criticalityKey,
    criticalityRank: definition.criticalityRank,
    status: "raised",
    version: 1,
    location,
    assetTypeKey,
    assetNumber,
    details,
    detailsPending: details == null,
    raisedByUid: context.actor.uid,
    raisedByName: context.actor.name,
    raisedAt: now,
    detailsProvidedByUid: details == null ? null : context.actor.uid,
    detailsProvidedByName: details == null ? null : context.actor.name,
    detailsProvidedAt: details == null ? null : now,
    supportBasis: null,
    supportNote: null,
    supportConfirmedByUid: null,
    supportConfirmedByName: null,
    supportConfirmedAt: null,
    resolutionSummary: null,
    resolvedByUid: null,
    resolvedByName: null,
    resolvedAt: null,
    withdrawalReason: null,
    withdrawnByUid: null,
    withdrawnByName: null,
    withdrawnAt: null,
    createdAt: now,
    updatedAt: now,
  };
  assertCanonicalAlarm(after, alarmId);
  tx.create(alarmPath(alarmId), after);
  writeAudit({
    tx,
    path: alarmAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: alarmId,
    operation: "raise",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason: details ?? `${definition.name} alarm raised at ${location}`,
    before: {},
    after,
  });
  alarmEvent({
    tx,
    commandId: command.commandId,
    alarmId,
    eventType: "criticalAlarm.raised",
    context,
    alarm: after,
  });
  return {
    resultKey: "critical-alarm-raised",
    aggregateVersion: 1,
    result: {alarmId, status: "raised", detailsPending: details == null},
  };
};

export const provideCriticalAlarmDetails: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["details"], "payload");
  const alarmId = documentId(command.aggregateId, "aggregateId");
  const details = boundedText(command.payload.details, "details", 5, 2000);
  const [current] = await Promise.all([
    requireAlarm(tx, alarmId),
    requireVacantAudit(tx, alarmAuditPath(command.commandId)),
  ]);
  const version = assertVersion(current, command.expectedVersion);
  if (current.status === "resolved" || current.status === "withdrawnInError") {
    throw new WorkflowError(
      "failed-precondition",
      "A terminal critical alarm cannot receive new details.",
    );
  }
  const mayEdit = current.raisedByUid === context.actor.uid ||
    context.actor.roles.has("admin") || context.actor.roles.has("si");
  if (!mayEdit) {
    throw new WorkflowError(
      "permission-denied",
      "Only the raiser, Admin or SI may provide critical-alarm details.",
    );
  }
  const now = iso(context.serverNow);
  const update: JsonMap = {
    details,
    detailsPending: false,
    detailsProvidedByUid: context.actor.uid,
    detailsProvidedByName: context.actor.name,
    detailsProvidedAt: now,
    version: version + 1,
    updatedAt: now,
  };
  const after = {...current, ...update};
  assertCanonicalAlarm(after, alarmId);
  tx.update(alarmPath(alarmId), update);
  writeAudit({
    tx,
    path: alarmAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: alarmId,
    operation: "provide-details",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason: details,
    before: current,
    after,
  });
  alarmEvent({
    tx,
    commandId: command.commandId,
    alarmId,
    eventType: "criticalAlarm.detailsProvided",
    context,
    alarm: after,
  });
  return {
    resultKey: "critical-alarm-details-provided",
    aggregateVersion: version + 1,
    result: {alarmId, status: current.status, detailsPending: false},
  };
};

export const confirmCriticalAlarmSupport: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["basis", "responderNote", "details"], "payload");
  const alarmId = documentId(command.aggregateId, "aggregateId");
  const basis = choice(command.payload.basis, "basis", SUPPORT_BASES);
  const note = boundedText(command.payload.responderNote, "responderNote", 5, 1000);
  const suppliedDetails = optionalText(command.payload.details, "details", 2000);
  if (suppliedDetails != null && suppliedDetails.length < 5) {
    throw new WorkflowError(
      "invalid-argument",
      "details must contain at least 5 characters when supplied.",
    );
  }
  const [current] = await Promise.all([
    requireAlarm(tx, alarmId),
    requireVacantAudit(tx, alarmAuditPath(command.commandId)),
  ]);
  const version = assertVersion(current, command.expectedVersion);
  if (current.status !== "raised") {
    throw new WorkflowError(
      "failed-precondition",
      "Support can be confirmed only for a raised critical alarm.",
    );
  }
  if (current.detailsPending === true && suppliedDetails == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Critical-alarm details are required before support is confirmed.",
      {reasonCode: "critical-alarm-details-required"},
    );
  }
  const now = iso(context.serverNow);
  const details = suppliedDetails ?? current.details;
  const update: JsonMap = {
    status: "supportConfirmed",
    supportBasis: basis,
    supportNote: note,
    supportConfirmedByUid: context.actor.uid,
    supportConfirmedByName: context.actor.name,
    supportConfirmedAt: now,
    details,
    detailsPending: false,
    detailsProvidedByUid: suppliedDetails == null ?
      current.detailsProvidedByUid : context.actor.uid,
    detailsProvidedByName: suppliedDetails == null ?
      current.detailsProvidedByName : context.actor.name,
    detailsProvidedAt: suppliedDetails == null ?
      current.detailsProvidedAt : now,
    version: version + 1,
    updatedAt: now,
  };
  const after = {...current, ...update};
  assertCanonicalAlarm(after, alarmId);
  tx.update(alarmPath(alarmId), update);
  writeAudit({
    tx,
    path: alarmAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: alarmId,
    operation: "confirm-support",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason: note,
    before: current,
    after,
  });
  alarmEvent({
    tx,
    commandId: command.commandId,
    alarmId,
    eventType: "criticalAlarm.supportConfirmed",
    context,
    alarm: after,
  });
  return {
    resultKey: "critical-alarm-support-confirmed",
    aggregateVersion: version + 1,
    result: {alarmId, status: "supportConfirmed"},
  };
};

export const resolveCriticalAlarm: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["resolutionSummary"], "payload");
  const alarmId = documentId(command.aggregateId, "aggregateId");
  const summary = boundedText(
    command.payload.resolutionSummary,
    "resolutionSummary",
    5,
    2000,
  );
  const [current] = await Promise.all([
    requireAlarm(tx, alarmId),
    requireVacantAudit(tx, alarmAuditPath(command.commandId)),
  ]);
  const version = assertVersion(current, command.expectedVersion);
  if (current.status !== "supportConfirmed") {
    throw new WorkflowError(
      "failed-precondition",
      "Only a support-confirmed critical alarm may be resolved.",
    );
  }
  const now = iso(context.serverNow);
  const update: JsonMap = {
    status: "resolved",
    resolutionSummary: summary,
    resolvedByUid: context.actor.uid,
    resolvedByName: context.actor.name,
    resolvedAt: now,
    version: version + 1,
    updatedAt: now,
  };
  const after = {...current, ...update};
  assertCanonicalAlarm(after, alarmId);
  tx.update(alarmPath(alarmId), update);
  writeAudit({
    tx,
    path: alarmAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: alarmId,
    operation: "resolve",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason: summary,
    before: current,
    after,
  });
  alarmEvent({
    tx,
    commandId: command.commandId,
    alarmId,
    eventType: "criticalAlarm.resolved",
    context,
    alarm: after,
  });
  return {
    resultKey: "critical-alarm-resolved",
    aggregateVersion: version + 1,
    result: {alarmId, status: "resolved"},
  };
};

export const withdrawCriticalAlarmInError: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["reason"], "payload");
  const alarmId = documentId(command.aggregateId, "aggregateId");
  const reason = boundedText(command.payload.reason, "reason", 5, 1000);
  const [current] = await Promise.all([
    requireAlarm(tx, alarmId),
    requireVacantAudit(tx, alarmAuditPath(command.commandId)),
  ]);
  const version = assertVersion(current, command.expectedVersion);
  if (current.status !== "raised" && current.status !== "supportConfirmed") {
    throw new WorkflowError(
      "failed-precondition",
      "Only an active critical alarm may be withdrawn in error.",
    );
  }
  const mayWithdraw = current.raisedByUid === context.actor.uid ||
    context.actor.roles.has("admin") || context.actor.roles.has("si");
  if (!mayWithdraw) {
    throw new WorkflowError(
      "permission-denied",
      "Only the raiser, Admin or SI may withdraw this alarm in error.",
    );
  }
  const now = iso(context.serverNow);
  const update: JsonMap = {
    status: "withdrawnInError",
    withdrawalReason: reason,
    withdrawnByUid: context.actor.uid,
    withdrawnByName: context.actor.name,
    withdrawnAt: now,
    version: version + 1,
    updatedAt: now,
  };
  const after = {...current, ...update};
  assertCanonicalAlarm(after, alarmId);
  tx.update(alarmPath(alarmId), update);
  writeAudit({
    tx,
    path: alarmAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: alarmId,
    operation: "withdraw-in-error",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current,
    after,
  });
  alarmEvent({
    tx,
    commandId: command.commandId,
    alarmId,
    eventType: "criticalAlarm.withdrawnInError",
    context,
    alarm: after,
  });
  return {
    resultKey: "critical-alarm-withdrawn-in-error",
    aggregateVersion: version + 1,
    result: {alarmId, status: "withdrawnInError"},
  };
};

const parseAlarmTypeKeys = (value: unknown): string[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 20) {
    throw new WorkflowError(
      "invalid-argument",
      "contact.alarmTypeKeys must contain 1-20 alarm types.",
    );
  }
  const keys = value.map((entry, index) =>
    documentId(entry, `contact.alarmTypeKeys[${index}]`));
  if (new Set(keys).size !== keys.length) {
    throw new WorkflowError(
      "invalid-argument",
      "contact.alarmTypeKeys contains duplicates.",
    );
  }
  return [...keys].sort();
};

const normalizedDialValue = (value: unknown, kind: string): string => {
  const raw = boundedText(value, "contact.dialValue", 2, 40);
  const normalized = raw.replace(/[\s().-]/g, "");
  const valid = kind === "plantExtension" ?
    /^\d{2,8}$/.test(normalized) : /^\+?\d{5,15}$/.test(normalized);
  if (!valid) {
    throw new WorkflowError(
      "invalid-argument",
      "contact.dialValue is not valid for the selected contact kind.",
      {reasonCode: "critical-alarm-contact-number-invalid"},
    );
  }
  return normalized;
};

export const upsertCriticalAlarmContact: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["contact", "reason"], "payload");
  const contactId = documentId(command.aggregateId, "aggregateId");
  const data = record(command.payload.contact, "contact");
  exactKeys(data, [
    "schemaVersion", "label", "contactKind", "dialValue",
    "alarmTypeKeys", "priority", "notes",
  ], "contact");
  if (data.schemaVersion !== 1) {
    throw new WorkflowError("invalid-argument", "contact.schemaVersion is unsupported.");
  }
  const kind = choice(data.contactKind, "contact.contactKind", CONTACT_KINDS);
  const contact = {
    label: boundedText(data.label, "contact.label", 2, 120),
    contactKind: kind,
    dialValue: normalizedDialValue(data.dialValue, kind),
    alarmTypeKeys: parseAlarmTypeKeys(data.alarmTypeKeys),
    priority: intValue(data.priority, "contact.priority", 1),
    notes: optionalText(data.notes, "contact.notes", 500),
  };
  await Promise.all(
    contact.alarmTypeKeys.map((key) => activeAlarmDefinition(tx, key)),
  );
  if (contact.priority > 99) {
    throw new WorkflowError("invalid-argument", "contact.priority cannot exceed 99.");
  }
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current] = await Promise.all([
    tx.get(contactPath(contactId)),
    requireVacantAudit(tx, contactAuditPath(command.commandId)),
  ]);
  const currentData = current.exists && current.data != null ?
    normalizedContact(current.data as JsonMap) : null;
  const currentVersion = currentData != null ?
    (() => {
      assertCanonicalContact(currentData, contactId);
      return assertVersion(currentData, command.expectedVersion);
    })() : 0;
  if (!current.exists && command.expectedVersion !== 0) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "Critical-alarm contact version changed.",
      {reasonCode: "critical-alarm-version-conflict"},
    );
  }
  const now = iso(context.serverNow);
  const after: JsonMap = {
    schemaVersion: 1,
    contactId,
    version: currentVersion + 1,
    status: currentData?.status === "retired" ? "retired" : "active",
    ...contact,
    createdAt: currentData?.createdAt ?? now,
    createdByUid: currentData?.createdByUid ?? context.actor.uid,
    createdByName: currentData?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  assertCanonicalContact(after, contactId);
  if (current.exists) tx.update(contactPath(contactId), after);
  else tx.create(contactPath(contactId), after);
  writeAudit({
    tx,
    path: contactAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: contactId,
    operation: current.exists ? "update-contact" : "create-contact",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: currentData ?? {},
    after,
  });
  return {
    resultKey: current.exists ?
      "critical-alarm-contact-updated" : "critical-alarm-contact-created",
    aggregateVersion: currentVersion + 1,
    result: {contactId, status: after.status},
  };
};

export const setCriticalAlarmContactStatus: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const contactId = documentId(command.aggregateId, "aggregateId");
  const status = choice(command.payload.status, "status", CONTACT_STATUSES);
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current] = await Promise.all([
    tx.get(contactPath(contactId)),
    requireVacantAudit(tx, contactAuditPath(command.commandId)),
  ]);
  if (!current.exists || current.data == null ||
      current.data.schemaVersion !== 1 || current.data.contactId !== contactId) {
    throw new WorkflowError("not-found", "Critical-alarm contact was not found.");
  }
  const currentData = normalizedContact(current.data);
  assertCanonicalContact(currentData, contactId);
  const version = assertVersion(currentData, command.expectedVersion);
  if (currentData.status === status) {
    throw new WorkflowError("failed-precondition", `Contact is already ${status}.`);
  }
  const now = iso(context.serverNow);
  const update: JsonMap = {
    status,
    version: version + 1,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  const after = {...currentData, ...update};
  assertCanonicalContact(after, contactId);
  tx.update(contactPath(contactId), update);
  writeAudit({
    tx,
    path: contactAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: contactId,
    operation: `${status}-contact`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: currentData,
    after,
  });
  return {
    resultKey: `critical-alarm-contact-${status}`,
    aggregateVersion: version + 1,
    result: {contactId, status},
  };
};

const definitionInput = (value: unknown): Readonly<{
  name: string;
  criticalityKey: "highest" | "critical";
  criticalityRank: number;
}> => {
  const data = record(value, "definition");
  exactKeys(
    data,
    ["schemaVersion", "name", "criticalityKey", "criticalityRank"],
    "definition",
  );
  if (data.schemaVersion !== 1) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.schemaVersion is unsupported.",
    );
  }
  const criticalityKey = choice(
    data.criticalityKey,
    "definition.criticalityKey",
    new Set(["highest", "critical"]),
  ) as "highest" | "critical";
  const criticalityRank = intValue(
    data.criticalityRank,
    "definition.criticalityRank",
    1,
  );
  if (!((criticalityKey === "highest" && criticalityRank === 1) ||
      (criticalityKey === "critical" && criticalityRank === 2))) {
    throw new WorkflowError(
      "invalid-argument",
      "Definition criticality and rank do not match.",
      {reasonCode: "critical-alarm-definition-criticality-invalid"},
    );
  }
  return {
    name: boundedText(data.name, "definition.name", 2, 120),
    criticalityKey,
    criticalityRank,
  };
};

export const upsertCriticalAlarmDefinition: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["definition", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const input = definitionInput(command.payload.definition);
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    requireVacantAudit(tx, definitionAuditPath(command.commandId)),
  ]);
  const currentData = current.exists && current.data != null ?
    normalizedDefinition(current.data as JsonMap) : null;
  if (current.exists && currentData == null) failMalformedDefinition();
  if (currentData != null) {
    assertCanonicalDefinition(currentData, definitionId);
    if (currentData.version !== command.expectedVersion) {
      throw new WorkflowError(
        "workflow-version-conflict",
        "Critical-alarm definition version changed.",
        {reasonCode: "critical-alarm-version-conflict"},
      );
    }
  } else if (command.expectedVersion !== 0) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "Critical-alarm definition version changed.",
      {reasonCode: "critical-alarm-version-conflict"},
    );
  }
  const now = iso(context.serverNow);
  const version = currentData == null ? 1 :
    (currentData.version as number) + 1;
  const after: JsonMap = {
    schemaVersion: 1,
    definitionId,
    version,
    status: currentData?.status === "retired" ? "retired" : "active",
    ...input,
    createdAt: currentData?.createdAt ?? now,
    createdByUid: currentData?.createdByUid ?? context.actor.uid,
    createdByName: currentData?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  assertCanonicalDefinition(after, definitionId);
  if (current.exists) tx.update(definitionPath(definitionId), after);
  else tx.create(definitionPath(definitionId), after);
  writeAudit({
    tx,
    path: definitionAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: definitionId,
    operation: current.exists ? "update-definition" : "create-definition",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: currentData ?? {},
    after,
  });
  return {
    resultKey: current.exists ?
      "critical-alarm-definition-updated" :
      "critical-alarm-definition-created",
    aggregateVersion: version,
    result: {definitionId, status: after.status},
  };
};

export const setCriticalAlarmDefinitionStatus: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const status = choice(
    command.payload.status,
    "status",
    DEFINITION_STATUSES,
  );
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    requireVacantAudit(tx, definitionAuditPath(command.commandId)),
  ]);
  let currentData: JsonMap | null = null;
  if (current.exists) {
    if (current.data == null) failMalformedDefinition();
    currentData = normalizedDefinition(current.data as JsonMap);
    assertCanonicalDefinition(currentData, definitionId);
    if (currentData.version !== command.expectedVersion) {
      throw new WorkflowError(
        "workflow-version-conflict",
        "Critical-alarm definition version changed.",
        {reasonCode: "critical-alarm-version-conflict"},
      );
    }
    if (currentData.status === status) {
      throw new WorkflowError(
        "failed-precondition",
        `Alarm reason is already ${status}.`,
      );
    }
  } else {
    const baseline = CRITICAL_ALARM_DEFINITIONS[definitionId];
    if (baseline == null) {
      throw new WorkflowError(
        "not-found",
        "Critical-alarm definition was not found.",
      );
    }
    if (command.expectedVersion !== 0) {
      throw new WorkflowError(
        "workflow-version-conflict",
        "Critical-alarm definition version changed.",
        {reasonCode: "critical-alarm-version-conflict"},
      );
    }
    if (status === "active") {
      throw new WorkflowError(
        "failed-precondition",
        "Alarm reason is already active.",
      );
    }
  }
  const now = iso(context.serverNow);
  const baseline = CRITICAL_ALARM_DEFINITIONS[definitionId];
  const after: JsonMap = currentData == null ? {
    schemaVersion: 1,
    definitionId,
    version: 1,
    status,
    name: baseline.name,
    criticalityKey: baseline.criticalityKey,
    criticalityRank: baseline.criticalityRank,
    createdAt: now,
    createdByUid: context.actor.uid,
    createdByName: context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  } : {
    ...currentData,
    status,
    version: (currentData.version as number) + 1,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  assertCanonicalDefinition(after, definitionId);
  if (current.exists) {
    tx.update(definitionPath(definitionId), {
      status,
      version: after.version,
      updatedAt: now,
      updatedByUid: context.actor.uid,
      updatedByName: context.actor.name,
    });
  } else {
    tx.create(definitionPath(definitionId), after);
  }
  writeAudit({
    tx,
    path: definitionAuditPath(command.commandId),
    commandId: command.commandId,
    aggregateId: definitionId,
    operation: `${status}-definition`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: currentData ?? {},
    after,
  });
  return {
    resultKey: `critical-alarm-definition-${status}`,
    aggregateVersion: after.version as number,
    result: {definitionId, status},
  };
};
