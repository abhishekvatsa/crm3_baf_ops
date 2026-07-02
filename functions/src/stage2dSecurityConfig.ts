export const BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT =
  "crm3-backend-identity-runtime@crm3-baf-ops-b8638.iam.gserviceaccount.com";

export const BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS = {
  enforceAppCheck: true,
  consumeAppCheckToken: false,
  serviceAccount: BACKEND_IDENTITY_RUNTIME_SERVICE_ACCOUNT,
} as const;
