import {defineBoolean} from "firebase-functions/params";

/**
 * Shared deploy-time gate for every mutating callable.
 *
 * The source default remains false while signed-client App Check coverage,
 * release-signing custody and Play Integrity registration are governed gates.
 */
export const MUTATING_CALLABLE_ENFORCE_APP_CHECK = defineBoolean(
  "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK",
  {
    default: false,
    description:
      "Require valid Firebase App Check tokens for all mutating callables after signed-client readiness is proven.",
  },
);

export const MUTATING_CALLABLE_SECURITY_OPTIONS = {
  enforceAppCheck: MUTATING_CALLABLE_ENFORCE_APP_CHECK,
  consumeAppCheckToken: false,
} as const;

export const READ_ONLY_CALLABLE_SECURITY_OPTIONS = {
  enforceAppCheck: false,
  consumeAppCheckToken: false,
} as const;
