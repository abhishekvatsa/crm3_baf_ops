export const CALLABLE_SECURITY_CLASSIFICATION = {
  assignPublishedTemplateVersion: "mutating",
  assignPublishedTemplateVersionV2: "mutating",
  beginGlobalPullRun: "read-only",
  completePlannedJobExecution: "mutating",
  executeMaintenanceWorkflowCommand: "mutating",
  executeMaintenanceWorkflowCommandV2: "mutating",
  getBackendReleaseIdentity: "read-only",
  mutateChargeAbnormality: "mutating",
  mutateChargeAbnormalityV2: "mutating",
  mutateAssetHierarchy: "mutating",
  mutateAssetHierarchyV2: "mutating",
  mutateRuntimeJobModulePopulation: "mutating",
  mutateUserAuthority: "mutating",
} as const;

type CallableClassification = typeof CALLABLE_SECURITY_CLASSIFICATION;

export type ExportedCallableName = keyof CallableClassification;

export type MutatingCallableName = {
  [Name in ExportedCallableName]:
    CallableClassification[Name] extends "mutating" ? Name : never;
}[ExportedCallableName];

export type ReadOnlyCallableName = {
  [Name in ExportedCallableName]:
    CallableClassification[Name] extends "read-only" ? Name : never;
}[ExportedCallableName];
