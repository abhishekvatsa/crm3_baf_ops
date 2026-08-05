import {createHash} from "crypto";

import {
  PersistedWorkPayloadError,
  readFieldDefinitionPayload,
} from "../persistedWorkPayload";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {JsonMap} from "./types";

export interface ResolvedRedSuccessorTemplate {
  readonly packageId: string;
  readonly packageCode: string;
  readonly packageTitle: string;
  readonly versionId: string;
  readonly versionNumber: number;
  readonly versionLabel: string | null;
  readonly contentHash: string;
  readonly templateName: string;
  readonly modules: readonly JsonMap[];
}

const documentId = (path: string): string => path.split("/").at(-1) ?? "";

const text = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const cleaned = value.trim();
  return cleaned.length === 0 ? null : cleaned;
};

const integer = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^-?\d+$/.test(value.trim())) return Number(value);
  return null;
};

const objectList = (value: unknown, field: string): JsonMap[] => {
  let parsed: unknown = value;
  if (typeof value === "string") {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new WorkflowError("red-successor-template-unconfigured", `${field} is not valid JSON.`);
    }
  }
  if (!Array.isArray(parsed)) {
    throw new WorkflowError("red-successor-template-unconfigured", `${field} must contain a JSON array.`);
  }
  return parsed.map((entry, index) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new WorkflowError("red-successor-template-unconfigured", `${field}[${index}] must be an object.`);
    }
    return entry as JsonMap;
  });
};

const objectValue = (value: unknown): JsonMap => {
  let parsed: unknown = value;
  if (typeof value === "string") {
    try {
      parsed = JSON.parse(value);
    } catch {
      return {};
    }
  }
  return parsed != null && typeof parsed === "object" && !Array.isArray(parsed)
    ? parsed as JsonMap
    : {};
};

const firstText = (data: JsonMap, keys: readonly string[]): string | null => {
  for (const key of keys) {
    const value = text(data[key]);
    if (value != null) return value;
  }
  return null;
};

const boolValue = (data: JsonMap, keys: readonly string[], fallback: boolean): boolean => {
  for (const key of keys) {
    if (typeof data[key] === "boolean") return data[key] as boolean;
  }
  return fallback;
};

const stringList = (value: unknown): string[] => Array.isArray(value)
  ? value.map((item) => text(item)).filter((item): item is string => item != null)
  : [];

const moduleCode = (snapshot: JsonMap, index: number): string =>
  firstText(snapshot, ["moduleCode", "code", "templateModuleCode", "moduleId", "id", "key"]) ??
  `RED-${String(index + 1).padStart(2, "0")}`;

const moduleTitle = (snapshot: JsonMap, index: number): string =>
  firstText(snapshot, ["moduleTitle", "title", "name", "label"]) ?? `RED module ${index + 1}`;

const moduleId = (executionId: string, index: number, code: string): string => {
  const digest = createHash("sha256").update(`${executionId}:${index}:${code}`).digest("hex").slice(0, 24);
  return `red_module_${digest}`;
};

const fieldsForModule = (fields: readonly JsonMap[], snapshot: JsonMap, code: string): JsonMap[] => {
  const templateModuleId = firstText(snapshot, ["templateModuleId", "moduleId", "id", "key"]);
  return fields.filter((field) => {
    const fieldCode = firstText(field, ["moduleCode", "ownerModuleCode"]);
    const fieldModuleId = firstText(field, ["templateModuleId", "moduleId", "ownerModuleId"]);
    if (fieldCode != null) return fieldCode === code;
    if (fieldModuleId != null && templateModuleId != null) return fieldModuleId === templateModuleId;
    return fields.length === 1;
  });
};

export const deterministicRedSuccessorIds = (
  parentWorkflowId: string,
  commandId: string,
): {workflowId: string; executionId: string} => {
  const digest = createHash("sha256")
    .update(`${parentWorkflowId}:${commandId}:red-successor`)
    .digest("hex")
    .slice(0, 28);
  const id = `red_${digest}`;
  return {workflowId: id, executionId: id};
};

export const resolveRedSuccessorTemplate = async (
  tx: WorkflowTransaction,
  assetTypeKey: string,
): Promise<ResolvedRedSuccessorTemplate> => {
  const promptRows = await tx.query("equipment_prompt_master", [
    {field: "assetTypeKey", op: "==", value: assetTypeKey},
  ]);
  const templateCodes = [...new Set(promptRows
    .map((row) => row.data)
    .filter((data): data is JsonMap => data != null && data.active === true)
    .map((data) => text(data.redSuccessorTemplateCode))
    .filter((value): value is string => value != null))];
  if (templateCodes.length !== 1) {
    throw new WorkflowError(
      "red-successor-template-unconfigured",
      `Exactly one active RED successor template code is required for ${assetTypeKey}.`,
      {templateCodes},
    );
  }

  const packageRows = await tx.query("template_packages", [
    {field: "packageCode", op: "==", value: templateCodes[0]},
  ]);
  const activePackages = packageRows.filter((row) => {
    const data = row.data;
    return data != null && data.isDeleted !== true && data.lifecycleStatus === "active";
  });
  if (activePackages.length !== 1 || activePackages[0].data == null) {
    throw new WorkflowError(
      "red-successor-template-unconfigured",
      `Exactly one active template package ${templateCodes[0]} is required.`,
    );
  }
  const packageRow = activePackages[0];
  const packageData = packageRow.data!;
  const packageId = documentId(packageRow.path);
  const versionId = text(packageData.activeVersionFirestoreId);
  if (packageId.length === 0 || versionId == null) {
    throw new WorkflowError("red-successor-template-unconfigured", "RED package has no active published version.");
  }

  const versionRow = await tx.get(`template_versions/${versionId}`);
  const versionData = versionRow.data;
  if (!versionRow.exists || versionData == null || versionData.isDeleted === true || versionData.status !== "published") {
    throw new WorkflowError("red-successor-template-unconfigured", "RED successor TemplateVersion is not published.");
  }
  if (text(versionData.packageFirestoreId) !== packageId) {
    throw new WorkflowError("red-successor-template-unconfigured", "RED TemplateVersion package identity is inconsistent.");
  }
  const contentHash = text(versionData.contentHash);
  const versionNumber = integer(versionData.versionNumber);
  if (contentHash == null || versionNumber == null || versionNumber < 1) {
    throw new WorkflowError("red-successor-template-unconfigured", "RED TemplateVersion identity is incomplete.");
  }

  const jobSnapshot = objectValue(versionData.jobTemplateSnapshotJson);
  const snapshots = objectList(versionData.moduleSnapshotsJson, "moduleSnapshotsJson");
  const hasFieldDefinitions = Object.prototype.hasOwnProperty.call(
    versionData,
    "fieldDefinitionsJson",
  );
  if (hasFieldDefinitions && versionData.fieldDefinitionsJson == null) {
    throw new WorkflowError(
      "red-successor-template-unconfigured",
      "fieldDefinitionsJson must contain a JSON array when present.",
      {
        reasonCode: "field-definition-payload-invalid",
        field: "fieldDefinitionsJson",
      },
    );
  }
  const allFields = objectList(
    hasFieldDefinitions ? versionData.fieldDefinitionsJson : "[]",
    "fieldDefinitionsJson",
  );
  if (snapshots.length === 0) {
    throw new WorkflowError("red-successor-template-unconfigured", "RED successor template has no modules.");
  }

  const packageTitle = text(packageData.title) ?? templateCodes[0];
  const templateName = firstText(jobSnapshot, ["jobName", "templateName", "title", "name"]) ?? packageTitle;
  const modules = snapshots.map((snapshot, index) => {
    const code = moduleCode(snapshot, index);
    const candidateFields = fieldsForModule(allFields, snapshot, code);
    let fields: readonly JsonMap[];
    try {
      readFieldDefinitionPayload(JSON.stringify(candidateFields), {
        field: `fieldDefinitionsJson for RED module ${code}`,
      });
      fields = candidateFields;
    } catch (error) {
      if (error instanceof PersistedWorkPayloadError) {
        throw new WorkflowError(
          "red-successor-template-unconfigured",
          `Field definitions for RED module ${code} are invalid.`,
          {
            reasonCode: "field-definition-payload-invalid",
            moduleCode: code,
            field: error.field,
          },
        );
      }
      throw error;
    }
    return {
      templateModuleId: firstText(snapshot, ["templateModuleId", "moduleId", "id", "key"]),
      moduleCode: code,
      moduleTitle: moduleTitle(snapshot, index),
      moduleDescription: firstText(snapshot, ["moduleDescription", "description", "closedDossierOutput"]),
      moduleSnapshotJson: JSON.stringify(snapshot, null, 2),
      fieldDefinitionsJson: JSON.stringify(fields, null, 2),
      useMode: firstText(snapshot, ["useMode", "defaultUseMode"]) ?? "scheduledPM",
      safetyClass: firstText(snapshot, ["safetyClass", "defaultSafetyClass"]) ?? "normal",
      requiredForClosure: boolValue(snapshot, ["requiredForClosure", "requiredForCloseout", "required"], true),
      isRequired: boolValue(snapshot, ["isRequired", "required"], true),
      displayOrder: integer(snapshot.displayOrder ?? snapshot.order ?? snapshot.sequence) ?? index,
      functionalSection: firstText(snapshot, ["functionalSection", "section"]),
      componentGroup: firstText(snapshot, ["componentGroup", "component"]),
      subsystem: firstText(snapshot, ["subsystem", "catalogueArea", "area"]),
      targetRef: firstText(snapshot, ["targetRef"]),
      targetRefs: stringList(snapshot.targetRefs ?? snapshot.targets),
      procedureRefs: stringList(snapshot.procedureRefs ?? snapshot.procedures),
      safetyConfirmations: stringList(snapshot.safetyConfirmations),
      operationalStatePreconditions: stringList(snapshot.operationalStatePreconditions ?? snapshot.preconditions),
      tags: stringList(snapshot.tags),
    };
  });

  return {
    packageId,
    packageCode: templateCodes[0],
    packageTitle,
    versionId,
    versionNumber,
    versionLabel: text(versionData.versionLabel),
    contentHash,
    templateName,
    modules,
  };
};

export const buildRedSuccessorModule = (args: {
  readonly template: ResolvedRedSuccessorTemplate;
  readonly module: JsonMap;
  readonly index: number;
  readonly executionId: string;
  readonly assetTypeKey: string;
  readonly assetNumber: number;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: string;
}): {id: string; data: JsonMap} => {
  const {template, module, index, executionId, assetTypeKey, assetNumber, actorUid, actorName, at} = args;
  const code = text(module.moduleCode) ?? `RED-${index + 1}`;
  const id = moduleId(executionId, index, code);
  return {
    id,
    data: {
      firestoreId: id,
      jobExecutionFirestoreId: executionId,
      jobExecutionLocalId: null,
      templateFirestoreId: template.versionId,
      templateName: template.templateName,
      templatePackageId: template.packageId,
      templateVersionId: template.versionId,
      templateModuleId: module.templateModuleId ?? null,
      moduleCode: code,
      moduleSnapshotJson: module.moduleSnapshotJson ?? "{}",
      fieldDefinitionsJson: module.fieldDefinitionsJson ?? "[]",
      assetType: assetTypeKey,
      assetNumber,
      chargeNoAtEvent: null,
      pairedEquipmentJson: null,
      moduleTitle: module.moduleTitle ?? `RED module ${index + 1}`,
      moduleDescription: module.moduleDescription ?? null,
      status: "notStarted",
      useMode: module.useMode ?? "scheduledPM",
      discipline: "refractory",
      laneKey: "red",
      laneActivationGeneration: 1,
      workflowLaneFirestoreId: `${executionId}_red_1`,
      isOpenForWork: true,
      safetyClass: module.safetyClass ?? "normal",
      isRequired: module.isRequired ?? true,
      requiredForClosure: module.requiredForClosure ?? true,
      addedDuringExecution: false,
      displayOrder: module.displayOrder ?? index,
      functionalSection: module.functionalSection ?? null,
      componentGroup: module.componentGroup ?? null,
      subsystem: module.subsystem ?? null,
      targetRef: module.targetRef ?? null,
      targetRefs: module.targetRefs ?? [],
      procedureRefs: module.procedureRefs ?? [],
      safetyConfirmations: module.safetyConfirmations ?? [],
      tags: [...new Set([...(Array.isArray(module.tags) ? module.tags : []), template.packageCode, code])],
      operationalStatePreconditions: module.operationalStatePreconditions ?? [],
      responsesJson: "[]",
      actionsJson: "[]",
      draftNote: null,
      submissionNote: null,
      acceptanceNote: null,
      reopenReason: null,
      notApplicableReason: null,
      pendingIssue: null,
      requiresFollowUp: false,
      addedByUid: actorUid,
      addedByName: actorName,
      addedAt: at,
      addReason: `RED successor from published ${template.packageCode} v${template.versionNumber}`,
      createdByUid: actorUid,
      createdByName: actorName,
      createdAt: at,
      updatedByUid: actorUid,
      updatedByName: actorName,
      updatedAt: at,
      submittedByUid: null,
      submittedByName: null,
      submittedAt: null,
      acceptedByUid: null,
      acceptedByName: null,
      acceptedAt: null,
      reopenedByUid: null,
      reopenedByName: null,
      reopenedAt: null,
      notApplicableByUid: null,
      notApplicableByName: null,
      notApplicableAt: null,
      isDeleted: false,
      deletedAt: null,
      deletedByUid: null,
      deletedByName: null,
      deleteReason: null,
      version: 1,
      metadataJson: JSON.stringify({
        source: "server_governed_red_successor",
        packageFirestoreId: template.packageId,
        versionFirestoreId: template.versionId,
        contentHash: template.contentHash,
        moduleIndex: index,
      }),
    },
  };
};
