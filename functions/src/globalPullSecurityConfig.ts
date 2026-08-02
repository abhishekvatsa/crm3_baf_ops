import {READ_ONLY_CALLABLE_SECURITY_OPTIONS} from "./callableSecurityConfig";

export const GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT =
  "crm3-global-pull-reader@crm3-baf-ops-b8638.iam.gserviceaccount.com";

export const GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT =
  "crm3-global-pull-writer@crm3-baf-ops-b8638.iam.gserviceaccount.com";

export const GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS = {
  ...READ_ONLY_CALLABLE_SECURITY_OPTIONS,
  serviceAccount: GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT,
} as const;

export const GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS = {
  serviceAccount: GLOBAL_PULL_WRITER_RUNTIME_SERVICE_ACCOUNT,
} as const;
