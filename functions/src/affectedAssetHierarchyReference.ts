import {
  isValidPersistedInstant,
  persistedInstantMillis,
} from "./persistedInstant";

type JsonMap = Record<string, unknown>;

const REFERENCE_FIELDS = new Set([
  "schemaVersion",
  "scope",
  "assetClassId",
  "assetClassCode",
  "assetClassName",
  "nodeId",
  "nodeVersion",
  "nodeName",
  "assetInstanceId",
  "assetInstanceVersion",
  "assetNumber",
  "assetInstanceName",
  "componentInstanceId",
  "componentInstanceVersion",
  "componentTag",
  "hierarchyPath",
  "ownershipStatus",
  "ownerDiscipline",
  "accountableRoleKeys",
  "innerCoverAssociation",
]);

const INNER_COVER_FIELDS = new Set([
  "baseAssetInstanceId",
  "baseAssetNumber",
  "positionState",
  "innerCoverId",
  "innerCoverSerialNumber",
  "linkageId",
  "assignmentVersion",
  "linkedAt",
  "eventAt",
  "confirmedAt",
  "confirmedByUid",
  "confirmedByName",
]);

const isMap = (value: unknown): value is JsonMap =>
  value != null && typeof value === "object" && !Array.isArray(value);

const exactFields = (value: JsonMap, fields: ReadonlySet<string>): boolean => {
  const keys = Object.keys(value);
  return keys.length === fields.size && keys.every((key) => fields.has(key));
};

const text = (value: unknown, maximum = 512): value is string =>
  typeof value === "string" &&
  value.trim().length > 0 &&
  value.trim().length <= maximum;

const optionalText = (value: unknown, maximum = 512): boolean =>
  value == null || text(value, maximum);

const documentId = (value: unknown): value is string =>
  text(value) && value !== "." && value !== ".." && !value.includes("/");

const optionalDocumentId = (value: unknown): boolean =>
  value == null || documentId(value);

const positiveInteger = (value: unknown): value is number =>
  Number.isSafeInteger(value) && (value as number) > 0;

const optionalPositiveInteger = (value: unknown): boolean =>
  value == null || positiveInteger(value);

const instant = (value: unknown): value is string =>
  text(value, 80) && isValidPersistedInstant(value);

const optionalInstant = (value: unknown): boolean =>
  value == null || instant(value);

const validStringList = (
  value: unknown,
  maximumItems: number,
  maximumLength: number,
): value is string[] =>
  Array.isArray(value) &&
  value.length <= maximumItems &&
  value.every((item) => text(item, maximumLength));

const validInnerCoverAssociation = (
  value: unknown,
  assetInstanceId: string,
  assetNumber: number,
): boolean => {
  if (!isMap(value) || !exactFields(value, INNER_COVER_FIELDS)) return false;
  if (value.baseAssetInstanceId !== assetInstanceId ||
      value.baseAssetNumber !== assetNumber ||
      !instant(value.eventAt) ||
      !instant(value.confirmedAt) ||
      !text(value.confirmedByUid) ||
      !text(value.confirmedByName, 500)) {
    return false;
  }
  const eventAt = persistedInstantMillis(value.eventAt);
  const confirmedAt = persistedInstantMillis(value.confirmedAt);
  if (eventAt > confirmedAt || !optionalInstant(value.linkedAt)) return false;
  const linkedAt = value.linkedAt == null ?
    null : persistedInstantMillis(value.linkedAt);
  if (linkedAt != null && (linkedAt > eventAt || linkedAt > confirmedAt)) {
    return false;
  }

  const linkedFieldsComplete =
    documentId(value.innerCoverId) &&
    text(value.innerCoverSerialNumber, 160) &&
    documentId(value.linkageId) &&
    positiveInteger(value.assignmentVersion) &&
    linkedAt != null;
  const linkedFieldsAbsent =
    value.innerCoverId == null &&
    value.innerCoverSerialNumber == null &&
    value.linkageId == null &&
    value.assignmentVersion == null &&
    value.linkedAt == null;
  return (value.positionState === "linked" && linkedFieldsComplete) ||
    (value.positionState === "noneLinked" && linkedFieldsAbsent);
};

export const isValidAffectedAssetHierarchyReference = (
  value: unknown,
  affectedAssetNumber: number,
): value is JsonMap => {
  if (!isMap(value) || !exactFields(value, REFERENCE_FIELDS)) return false;
  try {
    if (Buffer.byteLength(JSON.stringify(value), "utf8") > 32768) return false;
  } catch (_) {
    return false;
  }

  const schemaVersion = value.schemaVersion;
  const scope = value.scope;
  if (!positiveInteger(schemaVersion) ||
      ![2, 3, 4].includes(schemaVersion) ||
      !["physicalAsset", "componentDefinitionOnAsset", "installedComponent"]
        .includes(scope as string) ||
      !documentId(value.assetClassId) ||
      !text(value.assetClassCode, 160) ||
      !text(value.assetClassName, 500) ||
      !documentId(value.nodeId) ||
      !positiveInteger(value.nodeVersion) ||
      !text(value.nodeName, 500) ||
      !documentId(value.assetInstanceId) ||
      !positiveInteger(value.assetInstanceVersion) ||
      value.assetNumber !== affectedAssetNumber ||
      !text(value.assetInstanceName, 500) ||
      !optionalDocumentId(value.componentInstanceId) ||
      !optionalPositiveInteger(value.componentInstanceVersion) ||
      !optionalText(value.componentTag, 160) ||
      !validStringList(value.hierarchyPath, 20, 500) ||
      value.hierarchyPath.length === 0 ||
      !validStringList(value.accountableRoleKeys, 10, 80) ||
      !optionalText(value.ownerDiscipline, 160) ||
      !["unassigned", "provisional", "confirmed"]
        .includes(value.ownershipStatus as string)) {
    return false;
  }

  if ((value.ownershipStatus === "unassigned" &&
       (value.ownerDiscipline != null || value.accountableRoleKeys.length > 0)) ||
      (value.ownershipStatus === "provisional" &&
       value.ownerDiscipline == null && value.accountableRoleKeys.length === 0) ||
      (value.ownershipStatus === "confirmed" &&
       (value.ownerDiscipline == null || value.accountableRoleKeys.length === 0))) {
    return false;
  }

  if (scope === "physicalAsset" &&
      (schemaVersion !== 3 || value.componentInstanceId != null ||
       value.componentInstanceVersion != null || value.componentTag != null)) {
    return false;
  }
  if (scope === "componentDefinitionOnAsset" &&
      (schemaVersion !== 4 || value.componentInstanceId != null ||
       value.componentInstanceVersion != null || value.componentTag != null)) {
    return false;
  }
  if (scope === "installedComponent" &&
      (![2, 3].includes(schemaVersion) || value.componentInstanceId == null ||
       value.componentInstanceVersion == null || value.ownershipStatus !== "confirmed")) {
    return false;
  }

  if (value.innerCoverAssociation == null) {
    return true;
  }
  if (schemaVersion < 3) return false;
  return validInnerCoverAssociation(
    value.innerCoverAssociation,
    value.assetInstanceId,
    affectedAssetNumber,
  );
};
