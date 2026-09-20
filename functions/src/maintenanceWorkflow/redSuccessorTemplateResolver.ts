import {createHash} from "crypto";

import {
  AssignmentValidationError,
  compilePublishedTemplateRequirements,
  validatePublishedTemplatePublication,
  validatePublishedTemplateTarget,
  revalidatePublishedInstalledComponent,
} from "../publishedTemplateAssignment";
import {WorkflowError} from "./errors";
import {FrozenMaintenanceClass} from "./maintenanceIntelligence";
import {EquipmentIdentity} from "./paths";
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
  readonly publicationAuditId: string;
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

const firstText = (data: Readonly<Record<string, unknown>>, keys: readonly string[]): string | null => {
  for (const key of keys) {
    const value = text(data[key]);
    if (value != null) return value;
  }
  return null;
};

const boolValue = (data: Readonly<Record<string, unknown>>, keys: readonly string[], fallback: boolean): boolean => {
  for (const key of keys) {
    if (typeof data[key] === "boolean") return data[key] as boolean;
  }
  return fallback;
};

const stringList = (value: unknown): string[] => Array.isArray(value)
  ? value.map((item) => text(item)).filter((item): item is string => item != null)
  : [];

const moduleTitle = (snapshot: Readonly<Record<string, unknown>>, index: number): string =>
  firstText(snapshot, ["moduleTitle", "title", "name", "label"]) ?? `RED module ${index + 1}`;

const moduleId = (executionId: string, index: number, code: string): string => {
  const digest = createHash("sha256").update(`${executionId}:${index}:${code}`).digest("hex").slice(0, 24);
  return `red_module_${digest}`;
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
  target: EquipmentIdentity,
): Promise<ResolvedRedSuccessorTemplate> => {
  const {assetTypeKey} = target;
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
  let compiled: ReturnType<typeof compilePublishedTemplateRequirements>;
  let publicationAuditId: string;
  try {
    compiled = compilePublishedTemplateRequirements({
      ...versionData,
      fieldDefinitionsJson: hasFieldDefinitions ? versionData.fieldDefinitionsJson : "[]",
      checklistJson: Object.prototype.hasOwnProperty.call(versionData, "checklistJson") ?
        versionData.checklistJson : "[]",
    });
    const publication = validatePublishedTemplatePublication({
      request: {
        packageId, versionId, expectedVersionNumber: versionNumber,
        expectedContentHash: contentHash,
      },
      packageData,
      versionData,
      enforceClientAppVersion: false,
    });
    const auditRows = await tx.query("template_publish_audits", [
      {field: "versionFirestoreId", op: "==", value: versionId},
    ]);
    publicationAuditId = publication.requireAudit(auditRows.map((row) => ({
      id: documentId(row.path),
      exists: row.exists,
      data: () => row.data ?? undefined,
    }))).id;
    validatePublishedTemplateTarget(versionData, target);
    await revalidatePublishedInstalledComponent(versionData, target, async (path) => {
      const value = await tx.get(path);
      return {id: documentId(path), exists: value.exists, data: () => value.data ?? undefined};
    });
  } catch (error) {
    if (error instanceof AssignmentValidationError) {
      throw new WorkflowError(
        "red-successor-template-unconfigured", error.message, error.details as JsonMap,
      );
    }
    throw error;
  }

  const packageTitle = text(packageData.title) ?? templateCodes[0];
  const templateName = firstText(compiled.jobSnapshot, ["jobName", "templateName", "title", "name"]) ?? packageTitle;
  const modules = compiled.modules.map(({snapshot, code, fields}, index) => {
    const discipline = ["discipline", "defaultDiscipline", "assignedDiscipline", "ownerDiscipline"]
      .map((key) => firstText(snapshot, [key]))
      .find((value) => value != null && value.trim().toLowerCase() !== "refractory");
    if (discipline != null) {
      throw new WorkflowError("red-successor-template-unconfigured",
        "The automatic RED successor requires refractory modules. Publish a compatible package instead of changing its recorded ownership.",
        {reasonCode: "red-successor-discipline-incompatible", moduleCode: code, discipline});
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
    publicationAuditId,
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
  readonly maintenanceClassification?: FrozenMaintenanceClass | null;
  readonly maintenanceClassificationRevision?: number | null;
}): {id: string; data: JsonMap} => {
  const {
    template, module, index, executionId, assetTypeKey, assetNumber,
    actorUid, actorName, at, maintenanceClassification,
    maintenanceClassificationRevision,
  } = args;
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
        ...(maintenanceClassification == null ? {} : {
          maintenanceClassification,
          maintenanceClassificationRevision: maintenanceClassificationRevision ?? 1,
        }),
      }),
    },
  };
};
