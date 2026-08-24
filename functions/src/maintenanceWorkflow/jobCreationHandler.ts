import {mayFinalizeLaneSet} from "./authority";
import {
  equipmentFactsFromProjection,
  equipmentProjectionWrite,
  projectEquipment,
  withWorkflowContribution,
} from "./equipmentFacts";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {
  equipmentIdentity,
  equipmentPathForIdentity,
  executionPath,
  workflowPath,
} from "./paths";
import {DocSnapshot, WorkflowTransaction} from "./store";
import {JsonMap} from "./types";
import {cleanText, intValue, iso, optionalText} from "./utils";
import {isFiveDigitChargeNumber} from "../chargeNumber";

const assignmentSchemaVersion = 2;
const assetTypes = new Set([
  "base",
  "furnace",
  "forceCooler",
  "innerCover",
  "governedCustom",
]);

type TemplateHierarchyTarget = {
  readonly scope: "definition" | "physicalAsset" | "installedComponent";
  readonly assetClassId: string;
  readonly assetInstanceId: string | null;
  readonly assetNumber: number | null;
};

type InnerCoverPosition = {
  readonly baseAssetInstanceId: string;
  readonly baseAssetClassId: string;
  readonly baseAssetNumber: number;
  readonly innerCoverId: string;
  readonly innerCoverSerialNumber: string;
  readonly linkageId: string;
  readonly assignmentVersion: number;
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed === "." || parsed === ".." || parsed.includes("/")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be a Firestore document ID.`,
    );
  }
  return parsed;
};

const storedDocumentId = (value: unknown, field: string): string => {
  try {
    return documentId(value, field);
  } catch (_) {
    throw new WorkflowError(
      "failed-precondition",
      `Stored ${field} is malformed.`,
      {reasonCode: "legacy-assignment-authority-malformed", field},
    );
  }
};

const storedPositiveInt = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new WorkflowError(
      "failed-precondition",
      `Stored ${field} is malformed.`,
      {reasonCode: "legacy-assignment-authority-malformed", field},
    );
  }
  return value as number;
};

const storedText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      `Stored ${field} is malformed.`,
      {reasonCode: "legacy-assignment-authority-malformed", field},
    );
  }
  return value.trim();
};

const storedStringArray = (value: unknown, field: string): string[] => {
  if (!Array.isArray(value)) {
    throw new WorkflowError(
      "failed-precondition",
      `Stored ${field} is malformed.`,
      {reasonCode: "legacy-assignment-authority-malformed", field},
    );
  }
  return value.map((item, index) => storedText(item, `${field}[${index}]`));
};

const pathDocumentId = (path: string): string => path.split("/").pop() ?? path;

const validAssetNumber = (assetType: string, number: number): boolean => {
  if (assetType === "base") return (number >= 101 && number <= 124) || (number >= 201 && number <= 223);
  if (assetType === "furnace") return number >= 1 && number <= 26;
  if (assetType === "forceCooler") return number >= 1 && number <= 25;
  if (assetType === "innerCover") return (number >= 101 && number <= 124) || (number >= 201 && number <= 223);
  if (assetType === "governedCustom") return number > 0;
  return false;
};

const invalidHierarchyReference = (detail: string): never => {
  throw new WorkflowError(
    "failed-precondition",
    `The saved template hierarchy reference is ${detail}.`,
    {reasonCode: "legacy-template-hierarchy-reference-invalid"},
  );
};

const hierarchyText = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim().length === 0) {
    return invalidHierarchyReference(`missing ${field}`);
  }
  return value.trim();
};

const optionalHierarchyText = (
  value: unknown,
  field: string,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  return value.trim();
};

const hierarchyDocumentId = (value: unknown, field: string): string => {
  const parsed = hierarchyText(value, field);
  if (parsed === "." || parsed === ".." || parsed.includes("/")) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  return parsed;
};

const optionalHierarchyDocumentId = (
  value: unknown,
  field: string,
): string | null => value == null ? null : hierarchyDocumentId(value, field);

const hierarchyPositiveInt = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  return value as number;
};

const optionalHierarchyPositiveInt = (
  value: unknown,
  field: string,
): number | null => value == null ? null : hierarchyPositiveInt(value, field);

const hierarchyStringList = (
  value: unknown,
  field: string,
): string[] => {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  return value.map((item, index) =>
    hierarchyText(item, `${field}[${index}]`),
  );
};

const hierarchyInstant = (value: unknown, field: string): number => {
  if (typeof value !== "string" || value.trim().length === 0) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  const parsed = Date.parse(value.trim());
  if (Number.isNaN(parsed)) {
    return invalidHierarchyReference(`invalid at ${field}`);
  }
  return parsed;
};

const validateHierarchyOwnership = (
  reference: JsonMap,
  scope: string,
): void => {
  const ownershipStatus = reference.ownershipStatus;
  const ownerDiscipline = optionalHierarchyText(
    reference.ownerDiscipline,
    "ownerDiscipline",
  );
  const accountableRoleKeys = hierarchyStringList(
    reference.accountableRoleKeys,
    "accountableRoleKeys",
  );
  if (accountableRoleKeys.length > 10 ||
      accountableRoleKeys.some((role) => role.length > 80)) {
    invalidHierarchyReference("invalid at accountableRoleKeys");
  }
  if (ownershipStatus !== "unassigned" &&
      ownershipStatus !== "provisional" &&
      ownershipStatus !== "confirmed") {
    invalidHierarchyReference("invalid at ownershipStatus");
  }
  if (ownershipStatus === "unassigned" &&
      (ownerDiscipline != null || accountableRoleKeys.length > 0)) {
    invalidHierarchyReference("inconsistent at ownershipStatus");
  }
  if (ownershipStatus === "provisional" &&
      ownerDiscipline == null && accountableRoleKeys.length === 0) {
    invalidHierarchyReference("incomplete at ownershipStatus");
  }
  if (ownershipStatus === "confirmed" &&
      (ownerDiscipline == null || accountableRoleKeys.length === 0)) {
    invalidHierarchyReference("incomplete at ownershipStatus");
  }
  if (scope === "installedComponent" && ownershipStatus !== "confirmed") {
    invalidHierarchyReference("invalid at installed-component ownership");
  }
};

const validateHierarchyInnerCover = (
  reference: JsonMap,
  schemaVersion: number,
  scope: string,
  assetInstanceId: string | null,
  assetNumber: number | null,
): void => {
  if (reference.innerCoverAssociation == null) return;
  const raw = reference.innerCoverAssociation;
  if (schemaVersion !== 3 || scope === "definition" || raw == null ||
      typeof raw !== "object" || Array.isArray(raw)) {
    invalidHierarchyReference("invalid at innerCoverAssociation");
  }
  const association = raw as JsonMap;
  const baseAssetInstanceId = hierarchyDocumentId(
    association.baseAssetInstanceId,
    "innerCoverAssociation.baseAssetInstanceId",
  );
  const baseAssetNumber = hierarchyPositiveInt(
    association.baseAssetNumber,
    "innerCoverAssociation.baseAssetNumber",
  );
  const positionState = association.positionState;
  const innerCoverId = optionalHierarchyDocumentId(
    association.innerCoverId,
    "innerCoverAssociation.innerCoverId",
  );
  const serial = optionalHierarchyText(
    association.innerCoverSerialNumber,
    "innerCoverAssociation.innerCoverSerialNumber",
  );
  const linkageId = optionalHierarchyDocumentId(
    association.linkageId,
    "innerCoverAssociation.linkageId",
  );
  const assignmentVersion = optionalHierarchyPositiveInt(
    association.assignmentVersion,
    "innerCoverAssociation.assignmentVersion",
  );
  const linkedAt = association.linkedAt == null ? null : hierarchyInstant(
    association.linkedAt,
    "innerCoverAssociation.linkedAt",
  );
  const completeLink = innerCoverId != null && serial != null &&
    linkageId != null && assignmentVersion != null && linkedAt != null;
  const absentLink = innerCoverId == null && serial == null &&
    linkageId == null && assignmentVersion == null && linkedAt == null;
  if ((positionState === "linked" && !completeLink) ||
      (positionState === "noneLinked" && !absentLink) ||
      (positionState !== "linked" && positionState !== "noneLinked")) {
    invalidHierarchyReference("inconsistent at innerCoverAssociation.positionState");
  }
  const eventAt = hierarchyInstant(
    association.eventAt,
    "innerCoverAssociation.eventAt",
  );
  const confirmedAt = hierarchyInstant(
    association.confirmedAt,
    "innerCoverAssociation.confirmedAt",
  );
  hierarchyText(
    association.confirmedByUid,
    "innerCoverAssociation.confirmedByUid",
  );
  hierarchyText(
    association.confirmedByName,
    "innerCoverAssociation.confirmedByName",
  );
  if (baseAssetInstanceId !== assetInstanceId ||
      baseAssetNumber !== assetNumber || eventAt > confirmedAt ||
      (linkedAt != null && linkedAt > confirmedAt)) {
    invalidHierarchyReference("inconsistent at innerCoverAssociation");
  }
};

const hierarchyTarget = (raw: unknown): TemplateHierarchyTarget | null => {
  if (raw == null) return null;
  if (typeof raw !== "string" || raw.trim().length === 0) {
    return invalidHierarchyReference("malformed");
  }
  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch (_) {
    return invalidHierarchyReference("malformed");
  }
  if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) {
    return invalidHierarchyReference("malformed");
  }
  const reference = decoded as JsonMap;
  const schemaVersion = reference.schemaVersion;
  if (!Number.isSafeInteger(schemaVersion) ||
      (schemaVersion !== 1 && schemaVersion !== 2 && schemaVersion !== 3)) {
    return invalidHierarchyReference("using an unsupported schema");
  }
  const scope = schemaVersion === 1 ? "definition" : reference.scope;
  if (scope !== "definition" &&
      scope !== "physicalAsset" &&
      scope !== "installedComponent") {
    return invalidHierarchyReference("invalid at scope");
  }
  if (scope === "physicalAsset" && schemaVersion !== 3) {
    return invalidHierarchyReference("invalid at physical-asset schema");
  }
  const assetClassId = hierarchyDocumentId(
    reference.assetClassId,
    "assetClassId",
  );
  hierarchyText(reference.assetClassCode, "assetClassCode");
  hierarchyText(reference.assetClassName, "assetClassName");
  hierarchyDocumentId(reference.nodeId, "nodeId");
  hierarchyPositiveInt(reference.nodeVersion, "nodeVersion");
  hierarchyText(reference.nodeName, "nodeName");
  const assetInstanceId = optionalHierarchyDocumentId(
    reference.assetInstanceId,
    "assetInstanceId",
  );
  const assetInstanceVersion = optionalHierarchyPositiveInt(
    reference.assetInstanceVersion,
    "assetInstanceVersion",
  );
  const assetNumber = optionalHierarchyPositiveInt(
    reference.assetNumber,
    "assetNumber",
  );
  const assetInstanceName = optionalHierarchyText(
    reference.assetInstanceName,
    "assetInstanceName",
  );
  const componentInstanceId = optionalHierarchyDocumentId(
    reference.componentInstanceId,
    "componentInstanceId",
  );
  const componentInstanceVersion = optionalHierarchyPositiveInt(
    reference.componentInstanceVersion,
    "componentInstanceVersion",
  );
  optionalHierarchyText(reference.componentTag, "componentTag");
  hierarchyStringList(reference.hierarchyPath, "hierarchyPath");
  validateHierarchyOwnership(reference, scope);
  if (scope === "physicalAsset" &&
      (assetInstanceId == null || assetInstanceVersion == null ||
       assetNumber == null || assetInstanceName == null ||
       componentInstanceId != null || componentInstanceVersion != null)) {
    return invalidHierarchyReference("incomplete at physical-asset identity");
  }
  if (scope === "installedComponent" &&
      (assetInstanceId == null || assetInstanceVersion == null ||
       assetNumber == null || assetInstanceName == null ||
       componentInstanceId == null || componentInstanceVersion == null)) {
    return invalidHierarchyReference("incomplete at installed-component identity");
  }
  validateHierarchyInnerCover(
    reference,
    schemaVersion as number,
    scope,
    assetInstanceId,
    assetNumber,
  );
  return {scope, assetClassId, assetInstanceId, assetNumber};
};

const validateAssetClass = (
  snapshot: DocSnapshot,
  expectedClassId: string,
  expectedLegacyKey: string | null,
): void => {
  if (!snapshot.exists || snapshot.data == null) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected governed asset class does not exist.",
      {reasonCode: "legacy-assignment-asset-class-not-found"},
    );
  }
  const data = snapshot.data;
  const rowId = pathDocumentId(snapshot.path);
  const embeddedId = storedDocumentId(data.assetClassId, "asset class identity");
  const legacyKey = optionalText(data.legacyAssetTypeKey);
  if (data.schemaVersion !== 1 ||
      rowId !== expectedClassId ||
      embeddedId !== expectedClassId ||
      data.status !== "active" ||
      data.isDeleted === true ||
      legacyKey !== expectedLegacyKey) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected governed asset class is not an active compatible assignment target.",
      {reasonCode: "legacy-assignment-asset-class-invalid"},
    );
  }
};

const resolveAssetClass = async (
  tx: WorkflowTransaction,
  assetTypeKey: string,
  selectedClassId: string,
): Promise<void> => {
  const expectedLegacyKey = assetTypeKey === "governedCustom" ? null :
    assetTypeKey === "innerCover" ? "base" : assetTypeKey;
  if (expectedLegacyKey == null) {
    validateAssetClass(
      await tx.get(`asset_classes/${selectedClassId}`),
      selectedClassId,
      null,
    );
    return;
  }
  const matches = await tx.query("asset_classes", [{
    field: "legacyAssetTypeKey",
    op: "==",
    value: expectedLegacyKey,
  }]);
  for (const row of matches) {
    const data = row.data ?? {};
    if (data.schemaVersion !== 1 ||
        (data.status !== "active" && data.status !== "retired") ||
        optionalText(data.legacyAssetTypeKey) !== expectedLegacyKey ||
        (data.isDeleted != null && typeof data.isDeleted !== "boolean")) {
      throw new WorkflowError(
        "failed-precondition",
        "A governed asset class matching this template is malformed.",
        {reasonCode: "legacy-assignment-asset-class-invalid"},
      );
    }
  }
  const active = matches.filter((row) =>
    row.data?.status === "active" && row.data?.isDeleted !== true,
  );
  if (active.length !== 1) {
    throw new WorkflowError(
      "failed-precondition",
      active.length === 0 ?
        "No active governed asset class matches this template." :
        "More than one active governed asset class matches this template.",
      {
        reasonCode: active.length === 0 ?
          "legacy-assignment-asset-class-not-found" :
          "legacy-assignment-asset-class-ambiguous",
      },
    );
  }
  validateAssetClass(active[0], selectedClassId, expectedLegacyKey);
};

const resolveAssetInstance = async (
  tx: WorkflowTransaction,
  assetTypeKey: string,
  selectedClassId: string,
  selectedInstanceId: string,
): Promise<number> => {
  const snapshot = await tx.get(`asset_instances/${selectedInstanceId}`);
  if (!snapshot.exists || snapshot.data == null) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected governed physical asset does not exist.",
      {reasonCode: "legacy-assignment-asset-instance-not-found"},
    );
  }
  const data = snapshot.data;
  const embeddedId = storedDocumentId(data.assetInstanceId, "asset instance identity");
  const classId = storedDocumentId(data.assetClassId, "asset instance class identity");
  const assetNumber = storedPositiveInt(data.assetNumber, "asset instance number");
  const version = storedPositiveInt(data.version, "asset instance version");
  if (data.schemaVersion !== 1 ||
      pathDocumentId(snapshot.path) !== selectedInstanceId ||
      embeddedId !== selectedInstanceId ||
      classId !== selectedClassId ||
      data.status !== "active" ||
      data.isDeleted === true ||
      version < 1 ||
      !validAssetNumber(assetTypeKey, assetNumber)) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected governed physical asset is not an active compatible assignment target.",
      {reasonCode: "legacy-assignment-asset-instance-invalid"},
    );
  }
  return assetNumber;
};

const resolveInnerCoverPosition = async (
  tx: WorkflowTransaction,
  baseAssetClassId: string,
  baseAssetInstanceId: string,
  baseAssetNumber: number,
): Promise<InnerCoverPosition> => {
  const assignment = await tx.get(
    `base_inner_cover_assignments/${baseAssetInstanceId}`,
  );
  if (!assignment.exists || assignment.data == null) {
    throw new WorkflowError(
      "failed-precondition",
      "No Inner Cover is currently linked to the selected Base.",
      {reasonCode: "inner-cover-assignment-missing"},
    );
  }
  const data = assignment.data;
  const position: InnerCoverPosition = {
    baseAssetInstanceId: storedDocumentId(
      data.baseAssetInstanceId,
      "Inner Cover assignment Base identity",
    ),
    baseAssetClassId: storedDocumentId(
      data.baseAssetClassId,
      "Inner Cover assignment Base class",
    ),
    baseAssetNumber: storedPositiveInt(
      data.baseAssetNumber,
      "Inner Cover assignment Base number",
    ),
    innerCoverId: storedDocumentId(data.innerCoverId, "Inner Cover identity"),
    innerCoverSerialNumber: storedText(
      data.innerCoverSerialNumber,
      "Inner Cover serial number",
    ),
    linkageId: storedDocumentId(data.linkageId, "Inner Cover linkage identity"),
    assignmentVersion: storedPositiveInt(
      data.version,
      "Inner Cover assignment version",
    ),
  };
  if (data.schemaVersion !== 1 ||
      pathDocumentId(assignment.path) !== baseAssetInstanceId ||
      position.baseAssetInstanceId !== baseAssetInstanceId ||
      position.baseAssetClassId !== baseAssetClassId ||
      position.baseAssetNumber !== baseAssetNumber) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected Base and its Inner Cover assignment disagree.",
      {reasonCode: "inner-cover-assignment-mismatch"},
    );
  }
  const profile = await tx.get(`inner_cover_profiles/${position.innerCoverId}`);
  const profileData = profile.data;
  if (!profile.exists || profileData == null ||
      profileData.schemaVersion !== 1 ||
      pathDocumentId(profile.path) !== position.innerCoverId ||
      profileData.innerCoverId !== position.innerCoverId ||
      profileData.serialNumber !== position.innerCoverSerialNumber ||
      profileData.lifecycleState !== "installed" ||
      profileData.currentBaseAssetInstanceId !== position.baseAssetInstanceId ||
      profileData.currentBaseAssetNumber !== position.baseAssetNumber ||
      profileData.currentLinkageId !== position.linkageId) {
    throw new WorkflowError(
      "failed-precondition",
      "The Base and linked Inner Cover profile disagree.",
      {reasonCode: "inner-cover-profile-mismatch"},
    );
  }
  return position;
};

export const createLegacyWorkflowJob: CommandHandler = async ({tx, command, context}) => {
  if (!mayFinalizeLaneSet(context.actor)) {
    throw new WorkflowError("permission-denied", "Only Admin, SI or Contract Supervisor may create an unclassified workflow job.");
  }
  if (command.expectedVersion !== 0) {
    throw new WorkflowError("workflow-version-conflict", "New workflow job creation must start at version zero.");
  }
  if (intValue(command.payload.assignmentSchemaVersion, "assignmentSchemaVersion", 2) !== assignmentSchemaVersion) {
    throw new WorkflowError("invalid-argument", "Unsupported planned-work assignment schema.");
  }
  for (const serverOwnedField of [
    "templateName",
    "assetTypeKey",
    "assetNumber",
    "assignedAgencies",
  ]) {
    if (Object.prototype.hasOwnProperty.call(command.payload, serverOwnedField)) {
      throw new WorkflowError(
        "invalid-argument",
        `${serverOwnedField} is server-derived and must not be supplied.`,
        {reasonCode: "legacy-assignment-server-owned-field", field: serverOwnedField},
      );
    }
  }
  const executionId = documentId(command.payload.executionId, "executionId");
  if (executionId !== command.aggregateId) {
    throw new WorkflowError("invalid-argument", "Execution identity must equal the aggregate identity.");
  }
  const templateFirestoreId = documentId(
    command.payload.templateFirestoreId,
    "templateFirestoreId",
  );
  const expectedTemplateVersion = intValue(
    command.payload.expectedTemplateVersion,
    "expectedTemplateVersion",
    1,
  );
  const assetClassId = documentId(command.payload.assetClassId, "assetClassId");
  const assetInstanceId = documentId(
    command.payload.assetInstanceId,
    "assetInstanceId",
  );
  const chargeNoAtEvent = command.payload.chargeNoAtEvent == null ? null :
    intValue(command.payload.chargeNoAtEvent, "chargeNoAtEvent", 10000);
  if (chargeNoAtEvent != null && !isFiveDigitChargeNumber(chargeNoAtEvent)) {
    throw new WorkflowError(
      "invalid-argument",
      "chargeNoAtEvent must contain exactly five digits.",
      {reasonCode: "charge-number-invalid", field: "chargeNoAtEvent"},
    );
  }
  const remarks = optionalText(command.payload.remarks);

  const templateSnapshot = await tx.get(`job_templates/${templateFirestoreId}`);
  if (!templateSnapshot.exists || templateSnapshot.data == null) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected job template no longer exists.",
      {reasonCode: "legacy-template-not-found"},
    );
  }
  const templateData = templateSnapshot.data;
  const storedTemplateId = storedDocumentId(
    templateData.firestoreId,
    "template identity",
  );
  const templateVersion = storedPositiveInt(templateData.version, "template version");
  const templateName = storedText(templateData.jobName, "template name");
  const assetTypeKey = storedText(
    templateData.applicableAssetType,
    "template asset type",
  );
  if (storedTemplateId !== templateFirestoreId ||
      pathDocumentId(templateSnapshot.path) !== templateFirestoreId ||
      templateData.isActive !== true ||
      templateData.isDeprecated !== false ||
      templateData.isDeleted !== false) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected job template is not active and assignable.",
      {reasonCode: "legacy-template-not-assignable"},
    );
  }
  if (templateVersion !== expectedTemplateVersion) {
    throw new WorkflowError(
      "aborted",
      "The job template changed. Sync and review it before assigning.",
      {reasonCode: "legacy-template-version-changed"},
    );
  }
  if (!assetTypes.has(assetTypeKey)) {
    throw new WorkflowError(
      "failed-precondition",
      "The saved job template has an unsupported asset type.",
      {reasonCode: "legacy-template-asset-type-invalid"},
    );
  }
  const assignedAgencies = storedStringArray(
    templateData.assignedAgencies ?? [],
    "template assignedAgencies",
  );
  const templateHierarchy = hierarchyTarget(templateData.assetHierarchyRefJson);
  if (assetTypeKey === "governedCustom" && templateHierarchy == null) {
    throw new WorkflowError(
      "failed-precondition",
      "A governed custom template requires an exact asset-class reference.",
      {reasonCode: "legacy-template-hierarchy-reference-required"},
    );
  }
  if (assetTypeKey === "innerCover" && templateHierarchy != null) {
    if (templateHierarchy.scope !== "definition") {
      throw new WorkflowError(
        "failed-precondition",
        "Inner Cover templates must target a class definition and resolve the current Base position at assignment time.",
        {reasonCode: "legacy-template-inner-cover-target-invalid"},
      );
    }
    validateAssetClass(
      await tx.get(`asset_classes/${templateHierarchy.assetClassId}`),
      templateHierarchy.assetClassId,
      "innerCover",
    );
  }
  if (assetTypeKey !== "innerCover" &&
      templateHierarchy != null &&
      templateHierarchy.assetClassId !== assetClassId) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected physical asset is outside the template asset class.",
      {reasonCode: "legacy-template-asset-class-mismatch"},
    );
  }
  if (templateHierarchy?.assetInstanceId != null &&
      templateHierarchy?.assetInstanceId !== assetInstanceId) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected physical asset differs from the template's fixed target.",
      {reasonCode: "legacy-template-asset-instance-mismatch"},
    );
  }

  await resolveAssetClass(tx, assetTypeKey, assetClassId);
  const assetNumber = await resolveAssetInstance(
    tx,
    assetTypeKey,
    assetClassId,
    assetInstanceId,
  );
  if (templateHierarchy?.assetNumber != null &&
      templateHierarchy.assetNumber !== assetNumber) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected physical asset number differs from the template's fixed target.",
      {reasonCode: "legacy-template-asset-number-mismatch"},
    );
  }
  const innerCoverPosition = assetTypeKey === "innerCover" ?
    await resolveInnerCoverPosition(
      tx,
      assetClassId,
      assetInstanceId,
      assetNumber,
    ) : null;
  const identity = equipmentIdentity(
    assetTypeKey,
    assetNumber,
    assetClassId,
    assetInstanceId,
  );

  const executionRef = executionPath(executionId);
  const aggregateRef = workflowPath(executionId);
  const equipmentRef = equipmentPathForIdentity(identity);
  const existingExecution = await tx.get(executionRef);
  const existingWorkflow = await tx.get(aggregateRef);
  const currentEquipment = await tx.get(equipmentRef);
  const existingFacts = equipmentFactsFromProjection(
    currentEquipment.data,
    identity,
  );
  if (existingExecution.exists || existingWorkflow.exists) {
    throw new WorkflowError("already-exists", "A job or workflow already uses this identity.");
  }

  const now = iso(context.serverNow);
  const facts = withWorkflowContribution(existingFacts, "nonRed");
  const equipment = projectEquipment(facts, false);
  const templateHierarchyJson = optionalText(templateData.assetHierarchyRefJson);
  tx.create(executionRef, {
    firestoreId: executionId,
    templateFirestoreId,
    templateName,
    assetType: assetTypeKey,
    assetNumber,
    assetClassId,
    assetInstanceId,
    isCompleted: false,
    isCancelled: false,
    assignedByUid: context.actor.uid,
    assignedByName: context.actor.name,
    assignedAgencies,
    chargeNoAtEvent,
    remarks,
    teamsInvolved: [],
    responsesJson: "[]",
    actionsJson: "[]",
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    laneMappingReview: assignedAgencies.length > 0,
    version: 1,
    metadataJson: JSON.stringify({
      source: "server_governed_legacy_template_assignment",
      assignmentSchemaVersion,
      assignmentAssetIdentity: {
        assetClassId,
        assetInstanceId,
        assetNumber,
      },
      ...(innerCoverPosition == null ? {} : {
        assignmentInnerCoverPosition: innerCoverPosition,
      }),
      jobTemplateSnapshot: {
        firestoreId: templateFirestoreId,
        version: templateVersion,
        jobName: templateName,
        applicableAssetType: assetTypeKey,
        assignedAgencies,
        assetHierarchyRefJson: templateHierarchyJson,
      },
    }),
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  });
  tx.create(aggregateRef, {
    jobExecutionId: executionId,
    assetTypeKey,
    assetNumber,
    assetClassId,
    assetInstanceId,
    ...(innerCoverPosition == null ? {} : {
      innerCoverId: innerCoverPosition.innerCoverId,
      innerCoverSerialNumber: innerCoverPosition.innerCoverSerialNumber,
      innerCoverLinkageId: innerCoverPosition.linkageId,
      innerCoverAssignmentVersion: innerCoverPosition.assignmentVersion,
    }),
    status: "pendingLaneClassification",
    version: 1,
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    activeRedWork: false,
    awaitingPreparation: false,
    cancelled: false,
    createdByUid: context.actor.uid,
    createdByName: context.actor.name,
    createdAt: now,
    updatedAt: now,
  });
  tx.set(equipmentRef, equipmentProjectionWrite(currentEquipment.data, facts, equipment, {
    assetTypeKey,
    assetNumber,
    assetClassId,
    assetInstanceId,
    trigger: `jobCreated:${executionId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), true);
  const event = eventPlan({
    aggregateId: executionId,
    eventId: command.commandId,
    eventType: "workflow.jobCreatedPendingClassification",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    payload: {
      templateFirestoreId,
      templateName,
      templateVersion,
      assetTypeKey,
      assetNumber,
      assetClassId,
      assetInstanceId,
      assignedAgencies,
      ...(innerCoverPosition == null ? {} : {
        innerCoverId: innerCoverPosition.innerCoverId,
        innerCoverSerialNumber: innerCoverPosition.innerCoverSerialNumber,
        innerCoverLinkageId: innerCoverPosition.linkageId,
        innerCoverAssignmentVersion: innerCoverPosition.assignmentVersion,
      }),
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "workflow-job-created",
    aggregateVersion: 1,
    result: {
      executionId,
      workflowId: executionId,
      status: "pendingLaneClassification",
      equipmentState: equipment.state,
      assetClassId,
      assetInstanceId,
      assetNumber,
    },
  };
};
