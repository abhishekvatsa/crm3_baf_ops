import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  ClosureValidationError,
  completePlannedJobWithDb,
} from "./plannedJobClosure";
import type {FirestoreLike, JsonMap} from "./plannedJobClosure";
import {
  AssignmentValidationError,
  assignPublishedTemplateVersionWithDb,
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
import type {
  BackendIdentityFirestoreLike,
  BackendIdentityJsonMap,
} from "./backendReleaseIdentity";
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

admin.initializeApp();

const NOTIFICATION_REGION = "asia-south1";
const CALLABLE_REGION = "asia-south1";

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
  },
  async (request: CallableRequest<CompletePlannedJobRequest>) => {
    try {
      return await completePlannedJobWithDb({
        db: admin.firestore() as unknown as FirestoreLike,
        authUid: request.auth?.uid ?? null,
        data: (request.data ?? {}) as JsonMap,
        timestampFromDate: (date) => admin.firestore.Timestamp.fromDate(date),
      });
    } catch (error) {
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
  },
  async (
    request: CallableRequest<AssignPublishedTemplateVersionRequest>,
  ) => {
    try {
      return await assignPublishedTemplateVersionWithDb({
        db: admin.firestore() as unknown as AssignmentFirestoreLike,
        authUid: request.auth?.uid ?? null,
        data: (request.data ?? {}) as AssignmentJsonMap,
      });
    } catch (error) {
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
  },
  async (
    request: CallableRequest<MutateRuntimeJobModulePopulationRequest>,
  ) => {
    try {
      return await invokeRuntimeJobModulePopulationCallable({
        db: admin.firestore() as unknown as RuntimePopulationFirestoreLike,
        authUid: request.auth?.uid ?? null,
        data: (request.data ?? {}) as RuntimePopulationJsonMap,
        timestampFromDate: admin.firestore.Timestamp.fromDate,
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
    if (ticket == null) return;
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
    if (execution == null) return;

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
