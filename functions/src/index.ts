import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  ClosureValidationError,
  completePlannedJobWithDb,
  userCanComplete,
} from "./plannedJobClosure";
import type {FirestoreLike, JsonMap} from "./plannedJobClosure";
import {
  AssignmentValidationError,
  assignPublishedTemplateVersionWithDb,
  userCanAssignPublishedTemplate,
} from "./publishedTemplateAssignment";
import type {
  AssignmentFirestoreLike,
  AssignmentJsonMap,
} from "./publishedTemplateAssignment";
import type {
  RuntimePopulationFirestoreLike,
  RuntimePopulationJsonMap,
} from "./runtimeJobModulePopulation";
import {
  userCanMutateRuntimeJobModulePopulation,
} from "./runtimeJobModulePopulation";
import {
  invokeRuntimeJobModulePopulationCallable,
} from "./runtimeJobModulePopulationCallable";
import {
  BackendIdentityValidationError,
  backendReleaseEnvironmentFromProcess,
} from "./backendReleaseIdentity";
import {
  getCompositeBackendReleaseIdentityWithDb,
} from "./backendReleaseIdentityComposite";
import {
  BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS,
} from "./stage2dSecurityConfig";
import {
  MUTATING_CALLABLE_SECURITY_OPTIONS,
  READ_ONLY_CALLABLE_SECURITY_OPTIONS,
} from "./callableSecurityConfig";
import type {
  BackendIdentityFirestoreLike,
  BackendIdentityJsonMap,
} from "./backendReleaseIdentity";
import {
  mutateUserAuthorityWithDb,
  UserAuthorityMutationError,
  userCanMutateUserAuthority,
} from "./userAuthorityMutation";
import type {
  UserAuthorityMutationFirestoreLike,
} from "./userAuthorityMutation";
import {
  ChargeAbnormalityMutationError,
  mutateChargeAbnormalityWithDb,
  userCanMutateChargeAbnormality,
} from "./chargeAbnormalityMutation";
import type {
  ChargeAbnormalityMutationFirestoreLike,
} from "./chargeAbnormalityMutation";
import {
  buildJobAssignedNotification,
  buildTicketCreatedNotification,
  buildTicketResolvedNotification,
  getTokenLookupForUser,
  getTokenLookupsForRoles,
  sendNotification,
} from "./notifications";
import type {
  FirestoreLike as NotifFirestoreLike,
  MessagingLike,
} from "./notifications";
import {
  CallableAbuseControlError,
  executeAuthorizedMutationWithAbuseControl,
} from "./callableAbuseControl";
import type {
  CallableAbuseFirestoreLike,
  MutatingCallableName,
} from "./callableAbuseControl";
import {
  applyGlobalPullServerClock,
  beginGlobalPullRunWithDb,
  GlobalPullServerClockError,
} from "./globalPullServerClock";
import type {
  GlobalPullAuthorityFirestoreLike,
  GlobalPullWriteChangeLike,
} from "./globalPullServerClock";

admin.initializeApp();

const NOTIFICATION_REGION = "asia-south1";
const CALLABLE_REGION = "asia-south1";

async function executeAuthorizedMutation<T>(args: {
  db: admin.firestore.Firestore;
  authUid: string | null;
  callableName: MutatingCallableName;
  authorize: (userData: {[key: string]: unknown}) => boolean;
  execute: () => Promise<T>;
}): Promise<T> {
  try {
    return await executeAuthorizedMutationWithAbuseControl({
      db: args.db as unknown as CallableAbuseFirestoreLike,
      actorUid: args.authUid,
      callableName: args.callableName,
      authorize: args.authorize,
      execute: args.execute,
    });
  } catch (error) {
    if (error instanceof CallableAbuseControlError) {
      throw new HttpsError(error.code, error.message, error.details);
    }
    throw error;
  }
}

// ─── Callable: planned-job closure ───────────────────────────────────────────

interface CompletePlannedJobRequest {
  executionId?: unknown;
  completedByUid?: unknown;
  remarks?: unknown;
  teamsInvolved?: unknown;
  responsesJson?: unknown;
  actionsJson?: unknown;
  responses?: unknown;
  actions?: unknown;
  expectedCompletionVersion?: unknown;
}

export const completePlannedJobExecution = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "512MiB",
    concurrency: 20,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<CompletePlannedJobRequest>) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "completePlannedJobExecution",
        authorize: userCanComplete,
        execute: () => completePlannedJobWithDb({
          db: db as unknown as FirestoreLike,
          authUid: request.auth?.uid ?? null,
          data: (request.data ?? {}) as JsonMap,
          timestampFromDate: (date) =>
            admin.firestore.Timestamp.fromDate(date),
        }),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof ClosureValidationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("completePlannedJobExecution failed", error);
      throw new HttpsError(
        "internal",
        "Server-side planned-job completion failed.",
      );
    }
  },
);

// ─── Callable: server-governed published-template assignment ────────────────

interface AssignPublishedTemplateVersionRequest {
  requestId?: unknown;
  packageId?: unknown;
  versionId?: unknown;
  expectedVersionNumber?: unknown;
  expectedContentHash?: unknown;
  assetType?: unknown;
  assetNumber?: unknown;
  chargeNoAtEvent?: unknown;
  remarks?: unknown;
}

export const assignPublishedTemplateVersion = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "512MiB",
    concurrency: 20,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (
    request: CallableRequest<AssignPublishedTemplateVersionRequest>,
  ) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "assignPublishedTemplateVersion",
        authorize: userCanAssignPublishedTemplate,
        execute: () => assignPublishedTemplateVersionWithDb({
          db: db as unknown as AssignmentFirestoreLike,
          authUid: request.auth?.uid ?? null,
          data: (request.data ?? {}) as AssignmentJsonMap,
        }),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AssignmentValidationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("assignPublishedTemplateVersion failed", error);
      throw new HttpsError(
        "internal",
        "Server-governed published-template assignment failed.",
      );
    }
  },
);

// ─── Global pull server clock and bounded-run authority ─────────────────────

export const beginGlobalPullRun = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    concurrency: 80,
    ...READ_ONLY_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<unknown>) => {
    try {
      return await beginGlobalPullRunWithDb({
        db: admin.firestore() as unknown as GlobalPullAuthorityFirestoreLike,
        authUid: request.auth?.uid ?? null,
        serverNow: () => admin.firestore.Timestamp.now().toDate(),
      });
    } catch (error) {
      if (error instanceof GlobalPullServerClockError) {
        throw new HttpsError(error.code, error.message, {
          reason: error.reason,
        });
      }
      logger.error("beginGlobalPullRun failed", error);
      throw new HttpsError(
        "internal",
        "The global pull run could not be authorized.",
      );
    }
  },
);

export const stampGlobalPullServerClock = onDocumentWritten(
  {
    document: "{collectionId}/{documentId}",
    region: CALLABLE_REGION,
    retry: true,
  },
  async (event) => {
    if (event.data == null) return;
    const action = await applyGlobalPullServerClock({
      collectionId: event.params.collectionId,
      change: event.data as unknown as GlobalPullWriteChangeLike,
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp,
    });
    if (action === "restored-tombstone") {
      logger.warn("Global pull writer converted a hard delete to a tombstone.", {
        collectionId: event.params.collectionId,
        documentId: event.params.documentId,
      });
    }
  },
);


// ─── Callable: runtime job-module population mutation ───────────────────────

interface MutateRuntimeJobModulePopulationRequest {
  operation?: unknown;
  module?: unknown;
  preservationReason?: unknown;
}

export const mutateRuntimeJobModulePopulation = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "512MiB",
    concurrency: 20,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (
    request: CallableRequest<MutateRuntimeJobModulePopulationRequest>,
  ) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "mutateRuntimeJobModulePopulation",
        authorize: userCanMutateRuntimeJobModulePopulation,
        execute: () => invokeRuntimeJobModulePopulationCallable({
          db: db as unknown as RuntimePopulationFirestoreLike,
          authUid: request.auth?.uid ?? null,
          data: (request.data ?? {}) as RuntimePopulationJsonMap,
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        }),
      });
    } catch (error) {
      logger.error("mutateRuntimeJobModulePopulation failed", error);
      throw error;
    }
  },
);

// ─── Callable: backend release identity ─────────────────────────────────────

export const getBackendReleaseIdentity = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    concurrency: 40,
    ...BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<BackendIdentityJsonMap>) => {
    try {
      return await getCompositeBackendReleaseIdentityWithDb({
        db: admin.firestore() as unknown as BackendIdentityFirestoreLike,
        authUid: request.auth?.uid ?? null,
        environment: backendReleaseEnvironmentFromProcess(
          process.env,
          admin.app().options.projectId ?? null,
        ),
      });
    } catch (error) {
      if (error instanceof BackendIdentityValidationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("getBackendReleaseIdentity failed", error);
      throw new HttpsError(
        "internal",
        "Backend release identity could not be loaded.",
      );
    }
  },
);

// ─── Callable: atomic user-authority mutation ────────────────────────────────

interface MutateUserAuthorityRequest {
  [key: string]: unknown;
  requestId?: unknown;
  targetUid?: unknown;
  operation?: unknown;
  expectedAuthorityDigest?: unknown;
  roles?: unknown;
  reason?: unknown;
}

export const mutateUserAuthority = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    concurrency: 20,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<MutateUserAuthorityRequest>) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "mutateUserAuthority",
        authorize: userCanMutateUserAuthority,
        execute: () => mutateUserAuthorityWithDb({
          db: db as unknown as UserAuthorityMutationFirestoreLike,
          authUid: request.auth?.uid ?? null,
          data: request.data ?? {},
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        }),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof UserAuthorityMutationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("mutateUserAuthority failed", error);
      throw new HttpsError(
        "internal",
        "Server-governed user-authority mutation failed.",
      );
    }
  },
);

// ─── Callable: atomic charge-abnormality admin mutation ──────────────────────

interface MutateChargeAbnormalityRequest {
  [key: string]: unknown;
  requestId?: unknown;
  abnormalityId?: unknown;
  operation?: unknown;
  expectedVersion?: unknown;
  reason?: unknown;
}

export const mutateChargeAbnormality = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    concurrency: 20,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<MutateChargeAbnormalityRequest>) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "mutateChargeAbnormality",
        authorize: userCanMutateChargeAbnormality,
        execute: () => mutateChargeAbnormalityWithDb({
          db: db as unknown as ChargeAbnormalityMutationFirestoreLike,
          authUid: request.auth?.uid ?? null,
          data: request.data ?? {},
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        }),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof ChargeAbnormalityMutationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("mutateChargeAbnormality failed", error);
      throw new HttpsError(
        "internal",
        "Server-governed charge-abnormality mutation failed.",
      );
    }
  },
);

// ─── Notification triggers ───────────────────────────────────────────────────

function firestoreAdapter(): NotifFirestoreLike {
  // firebase-admin Firestore satisfies our minimal interface at runtime.
  return admin.firestore() as unknown as NotifFirestoreLike;
}

function messagingAdapter(): MessagingLike {
  // firebase-admin Messaging satisfies sendEach at runtime.
  return admin.messaging() as unknown as MessagingLike;
}

function logOutcome(
  fn: string,
  outcome: {
    attempted: number;
    succeeded: number;
    failed: number;
    staleTokensCleared: number;
    unknownAgencies: ReadonlyArray<string>;
  },
): void {
  logger.info(`${fn} delivered`, outcome);
  if (outcome.unknownAgencies.length > 0) {
    logger.warn(`${fn} encountered unknown agencies`, {
      unknownAgencies: outcome.unknownAgencies,
    });
  }
}

export const onTicketCreated = onDocumentCreated(
  {
    document: "maintenance_records/{ticketId}",
    region: NOTIFICATION_REGION,
  },
  async (event) => {
    const ticket = event.data?.data();
    if (ticket == null || ticket.isDeleted === true) return;
    const plan = buildTicketCreatedNotification(ticket);
    const db = firestoreAdapter();
    const recipients = await getTokenLookupsForRoles(db, plan.roles);
    const outcome = await sendNotification({
      db,
      messaging: messagingAdapter(),
      recipients,
      title: plan.title,
      body: plan.body,
    });
    logOutcome("onTicketCreated", outcome);
  },
);

export const onTicketResolved = onDocumentUpdated(
  {
    document: "maintenance_records/{ticketId}",
    region: NOTIFICATION_REGION,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before == null || after == null) return;
    if (before.isResolved === after.isResolved) return;
    if (after.isResolved !== true) return;

    const plan = buildTicketResolvedNotification(after);
    const db = firestoreAdapter();

    const roleRecipients = await getTokenLookupsForRoles(db, plan.roles);
    const recipients = [...roleRecipients];
    if (plan.loggedByUid != null) {
      const loggedByLookup = await getTokenLookupForUser(db, plan.loggedByUid);
      if (loggedByLookup != null) recipients.push(loggedByLookup);
    }

    const outcome = await sendNotification({
      db,
      messaging: messagingAdapter(),
      recipients,
      title: plan.title,
      body: plan.body,
    });
    logOutcome("onTicketResolved", outcome);
  },
);

export const onJobAssigned = onDocumentCreated(
  {
    document: "job_executions/{executionId}",
    region: NOTIFICATION_REGION,
  },
  async (event) => {
    const execution = event.data?.data();
    if (execution == null || execution.isDeleted === true) return;

    const plan = buildJobAssignedNotification(execution);
    if (plan == null) return; // No agencies — nothing to do.

    const db = firestoreAdapter();
    const recipients = await getTokenLookupsForRoles(db, plan.roles);
    const outcome = await sendNotification({
      db,
      messaging: messagingAdapter(),
      recipients,
      title: plan.title,
      body: plan.body,
      unknownAgencies: plan.unknownAgencies,
    });
    logOutcome("onJobAssigned", outcome);
  },
);

// ─── Maintenance workflow control plane ───────────────────────────────
export {
  executeMaintenanceWorkflowCommand,
  maintenanceWorkflowEscalationSweep,
  onMaintenanceWorkflowEventCreated,
} from "./maintenanceWorkflow/firebaseExports";
