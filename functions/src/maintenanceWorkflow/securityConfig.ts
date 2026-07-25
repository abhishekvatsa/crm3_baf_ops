import {defineBoolean} from "firebase-functions/params";

/**
 * Deploy-time gate for workflow callable App Check enforcement.
 *
 * It deliberately defaults to false because the canonical Android identity,
 * release signing certificate and Play Integrity registration remain governed
 * preflight items. Production promotion must explicitly set this parameter to
 * true only after the signed client matrix proves App Check activation.
 */
export const WORKFLOW_ENFORCE_APP_CHECK = defineBoolean(
  "CRM3_WORKFLOW_ENFORCE_APP_CHECK",
  {
    default: false,
    description:
      "Require valid Firebase App Check tokens for maintenance workflow commands after signed-client readiness is proven.",
  },
);

export const MAINTENANCE_WORKFLOW_CALLABLE_SECURITY_OPTIONS = {
  enforceAppCheck: WORKFLOW_ENFORCE_APP_CHECK,
  consumeAppCheckToken: false,
} as const;
