import {HttpsError} from "firebase-functions/v2/https";

import {
  RuntimePopulationValidationError,
  mutateRuntimeJobModulePopulationWithDb,
} from "./runtimeJobModulePopulation";
import type {
  RuntimePopulationFirestoreLike,
  RuntimePopulationJsonMap,
  RuntimePopulationMutationResult,
} from "./runtimeJobModulePopulation";

export type RuntimePopulationTimestampFactory = (date: Date) => unknown;

/**
 * Pure callable adapter used by the exported Firebase function and by the
 * wrapper-level test suite. It proves auth/context translation and stable
 * HttpsError mapping without importing/initializing firebase-admin in tests.
 */
export async function invokeRuntimeJobModulePopulationCallable(args: {
  db: RuntimePopulationFirestoreLike;
  authUid: string | null;
  data: RuntimePopulationJsonMap;
  timestampFromDate: RuntimePopulationTimestampFactory;
}): Promise<RuntimePopulationMutationResult> {
  try {
    return await mutateRuntimeJobModulePopulationWithDb({
      db: args.db,
      authUid: args.authUid,
      data: args.data,
      timestampFromDate: args.timestampFromDate,
    });
  } catch (error) {
    if (error instanceof RuntimePopulationValidationError) {
      throw new HttpsError(error.code, error.message, error.details);
    }
    throw new HttpsError(
      "internal",
      "Server-governed planned-job module population mutation failed.",
    );
  }
}
