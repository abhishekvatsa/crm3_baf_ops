import {expr, projectID} from "firebase-functions/params";

export const FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS = Object.freeze({
  completePlannedJobExecution: "crm3-fn-complete-job",
  assignPublishedTemplateVersion: "crm3-fn-assign-template",
  beginGlobalPullRun: "crm3-global-pull-reader",
  stampGlobalPullServerClock: "crm3-global-pull-writer",
  mutateRuntimeJobModulePopulation: "crm3-fn-runtime-modules",
  getBackendReleaseIdentity: "crm3-backend-identity-runtime",
  mutateUserAuthority: "crm3-fn-user-authority",
  mutateChargeAbnormality: "crm3-fn-charge-abnormality",
  mutateAssetHierarchy: "crm3-fn-asset-hierarchy",
  onTicketCreated: "crm3-fn-ticket-created",
  onTicketResolved: "crm3-fn-ticket-resolved",
  onJobAssigned: "crm3-fn-job-assigned",
  executeMaintenanceWorkflowCommand: "crm3-fn-workflow-command",
  maintenanceWorkflowEscalationSweep: "crm3-fn-workflow-sweep",
  onMaintenanceWorkflowEventCreated: "crm3-fn-workflow-event",
} as const);

export type FunctionRuntimeIdentityName =
  keyof typeof FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS;

export const FUNCTION_RUNTIME_SERVICE_ACCOUNTS = Object.freeze({
  completePlannedJobExecution:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.completePlannedJobExecution}@${projectID}.iam.gserviceaccount.com`,
  assignPublishedTemplateVersion:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.assignPublishedTemplateVersion}@${projectID}.iam.gserviceaccount.com`,
  beginGlobalPullRun:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.beginGlobalPullRun}@${projectID}.iam.gserviceaccount.com`,
  stampGlobalPullServerClock:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.stampGlobalPullServerClock}@${projectID}.iam.gserviceaccount.com`,
  mutateRuntimeJobModulePopulation:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.mutateRuntimeJobModulePopulation}@${projectID}.iam.gserviceaccount.com`,
  getBackendReleaseIdentity:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.getBackendReleaseIdentity}@${projectID}.iam.gserviceaccount.com`,
  mutateUserAuthority:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.mutateUserAuthority}@${projectID}.iam.gserviceaccount.com`,
  mutateChargeAbnormality:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.mutateChargeAbnormality}@${projectID}.iam.gserviceaccount.com`,
  mutateAssetHierarchy:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.mutateAssetHierarchy}@${projectID}.iam.gserviceaccount.com`,
  onTicketCreated:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.onTicketCreated}@${projectID}.iam.gserviceaccount.com`,
  onTicketResolved:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.onTicketResolved}@${projectID}.iam.gserviceaccount.com`,
  onJobAssigned:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.onJobAssigned}@${projectID}.iam.gserviceaccount.com`,
  executeMaintenanceWorkflowCommand:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.executeMaintenanceWorkflowCommand}@${projectID}.iam.gserviceaccount.com`,
  maintenanceWorkflowEscalationSweep:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.maintenanceWorkflowEscalationSweep}@${projectID}.iam.gserviceaccount.com`,
  onMaintenanceWorkflowEventCreated:
    expr`${FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.onMaintenanceWorkflowEventCreated}@${projectID}.iam.gserviceaccount.com`,
} as const);

const PROJECT_ID_PATTERN = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/;

export function functionRuntimeServiceAccountsForProject(
  projectId: string,
): Record<FunctionRuntimeIdentityName, string> {
  if (!PROJECT_ID_PATTERN.test(projectId)) {
    throw new Error("A canonical Google Cloud project ID is required.");
  }
  return Object.fromEntries(
    Object.entries(FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS).map(
      ([name, accountId]) => [
        name,
        `${accountId}@${projectId}.iam.gserviceaccount.com`,
      ],
    ),
  ) as Record<FunctionRuntimeIdentityName, string>;
}
