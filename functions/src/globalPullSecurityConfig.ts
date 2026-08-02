import {READ_ONLY_CALLABLE_SECURITY_OPTIONS} from "./callableSecurityConfig";

import {expr, projectID} from "firebase-functions/params";

export const GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID =
  "crm3-global-pull-reader";

export const GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID =
  "crm3-global-pull-writer";

export const GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT =
  expr`${GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID}@${projectID}.iam.gserviceaccount.com`;

export const GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT =
  expr`${GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID}@${projectID}.iam.gserviceaccount.com`;

const PROJECT_ID_PATTERN = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/;

export function globalPullRuntimeServiceAccountsForProject(projectId: string): {
  reader: string;
  writer: string;
} {
  if (!PROJECT_ID_PATTERN.test(projectId)) {
    throw new Error("A canonical Google Cloud project ID is required.");
  }
  return {
    reader:
      `${GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT_ID}@${projectId}` +
      ".iam.gserviceaccount.com",
    writer:
      `${GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT_ID}@${projectId}` +
      ".iam.gserviceaccount.com",
  };
}

export const GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS = {
  ...READ_ONLY_CALLABLE_SECURITY_OPTIONS,
  serviceAccount: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
} as const;

export const GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS = {
  serviceAccount: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
} as const;
