export const CALLABLE_SECURITY_CLASSIFICATION = {
  assignPublishedTemplateVersion: "mutating",
  beginGlobalPullRun: "read-only",
  completePlannedJobExecution: "mutating",
  executeMaintenanceWorkflowCommand: "mutating",
  getBackendReleaseIdentity: "read-only",
  mutateChargeAbnormality: "mutating",
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
