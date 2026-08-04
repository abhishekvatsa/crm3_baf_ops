import {
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS,
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS,
  functionRuntimeServiceAccountsForProject,
} from "./functionFleetRuntimeIdentity";

export const BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT_ID =
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.getBackendReleaseIdentity;

export const BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT =
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS.getBackendReleaseIdentity;

export function backendIdentityRuntimeServiceAccountForProject(
  projectId: string,
): string {
  return functionRuntimeServiceAccountsForProject(projectId)
    .getBackendReleaseIdentity;
}

export const BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS = {
  enforceAppCheck: true,
  consumeAppCheckToken: false,
  serviceAccount: BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT,
} as const;
