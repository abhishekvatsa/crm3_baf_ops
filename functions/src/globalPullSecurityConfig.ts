import {READ_ONLY_CALLABLE_SECURITY_OPTIONS} from "./callableSecurityConfig";
import {
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS,
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS,
  functionRuntimeServiceAccountsForProject,
} from "./functionFleetRuntimeIdentity";

export const GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID =
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.beginGlobalPullRun;

export const GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID =
  FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.stampGlobalPullServerClock;

export const GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT =
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS.beginGlobalPullRun;

export const GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT =
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS.stampGlobalPullServerClock;

export function globalPullRuntimeServiceAccountsForProject(projectId: string): {
  reader: string;
  writer: string;
} {
  const accounts = functionRuntimeServiceAccountsForProject(projectId);
  return {
    reader: accounts.beginGlobalPullRun,
    writer: accounts.stampGlobalPullServerClock,
  };
}

export const GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS = {
  ...READ_ONLY_CALLABLE_SECURITY_OPTIONS,
  serviceAccount: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
} as const;

export const GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS = {
  serviceAccount: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
} as const;
