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
} from "./callableSecurityConfig";
import {
  FUNCTION_RUNTIME_SERVICE_ACCOUNTS,
} from "./functionFleetRuntimeIdentity";
import {
  GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS,
  GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS,
} from "./globalPullSecurityConfig";
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
  ChargeAbnormalityMutationResult,
} from "./chargeAbnormalityMutation";
import {
  isQualityMutationOperation,
  mutateQualityWithDb,
  QualityMutationError,
  userCanMutateQuality,
} from "./qualityMutation";
import type {
  QualityMutationFirestoreLike,
  QualityMutationResult,
} from "./qualityMutation";
import {
  AssetHierarchyMutationError,
  mutateAssetHierarchyWithDb,
  userCanMutateAssetHierarchy,
} from "./assetHierarchyMutation";
import type {
  AssetHierarchyMutationResult,
  AssetHierarchyMutationFirestoreLike,
} from "./assetHierarchyMutation";
import {
  isAssetRegistryOperation,
  mutateAssetRegistryWithDb,
} from "./assetRegistryMutation";
import type {AssetRegistryMutationResult} from "./assetRegistryMutation";
import {
  isInnerCoverLifecycleOperation,
  mutateInnerCoverLifecycleWithDb,
} from "./innerCoverLifecycleMutation";
import type {
  InnerCoverLifecycleMutationResult,
} from "./innerCoverLifecycleMutation";
import {
  isAssetOperationalConditionOperation,
  mutateAssetOperationalConditionWithDb,
  userCanMutateAssetOperationalCondition,
} from "./assetOperationalConditionMutation";
import type {
  AssetOperationalConditionMutationResult,
} from "./assetOperationalConditionMutation";
import {
  isBurnerConditionRoundOperation,
  mutateBurnerConditionRoundWithDb,
  userCanRecordBurnerConditionRound,
} from "./burnerConditionRoundMutation";
import type {
  BurnerConditionRoundMutationResult,
} from "./burnerConditionRoundMutation";
import {
  isOperationalEventOperation,
  mutateOperationalEventWithDb,
  userCanMutateOperationalEvent,
} from "./operationalEventMutation";
import type {
  OperationalEventMutationResult,
} from "./operationalEventMutation";
import {
  isOperationalEventIssueLinkOperation,
  mutateOperationalEventIssueLinkWithDb,
  userCanLinkOperationalEventIssue,
} from "./operationalEventIssueLinkMutation";
import type {
  OperationalEventIssueLinkMutationResult,
} from "./operationalEventIssueLinkMutation";
import {
  DeviceRecoveryMutationError,
  isDeviceRecoveryOperation,
  mutateDeviceRecoveryWithDb,
  userCanMutateDeviceRecovery,
  userCanResumeClaimedDeviceRecovery,
} from "./deviceRecoveryMutation";
import type {DeviceRecoveryMutationResult} from "./deviceRecoveryMutation";
import {
  buildJobAssignedNotification,
  buildTicketCreatedNotification,
  buildTicketLaneAddedNotification,
  buildTicketResolvedNotification,
  getTokenLookupsForUser,
  getTokenLookupsForRoles,
  sendNotification,
} from "./notifications";
import type {
  FirestoreLike as NotifFirestoreLike,
  MessagingLike,
  SendOutcome,
} from "./notifications";
import {
  executeIdempotentNotificationEvent,
} from "./notificationEventReceipt";
import type {
  NotificationEventExecutionResult,
  NotificationReceiptFirestoreLike,
  NotificationReceiptRuntime,
} from "./notificationEventReceipt";
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
import {isAuthorizedPilotRecordPurge} from "./pilotRecordPurge";

admin.initializeApp();

const NOTIFICATION_REGION = "asia-south1";
const CALLABLE_REGION = "asia-south1";

async function executeAuthorizedMutation<T>(args: {
  db: admin.firestore.Firestore;
  authUid: string | null;
  callableName: MutatingCallableName;
  authorize: (userData: {[key: string]: unknown}) =>
    boolean | Promise<boolean>;
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
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.completePlannedJobExecution,
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
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.assignPublishedTemplateVersion,
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
    ...GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS,
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
    ...GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS,
  },
  async (event) => {
    if (event.data == null) return;
    const action = await applyGlobalPullServerClock({
      collectionId: event.params.collectionId,
      change: event.data as unknown as GlobalPullWriteChangeLike,
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp,
      authorizePermanentDelete: (collectionId, before) =>
        isAuthorizedPilotRecordPurge({
          db: admin.firestore(),
          collectionId,
          documentId: event.params.documentId,
          before,
        }),
    });
    if (action === "restored-tombstone") {
      logger.warn("Global pull writer converted a hard delete to a tombstone.", {
        collectionId: event.params.collectionId,
        documentId: event.params.documentId,
      });
    } else if (action === "authorized-permanent-delete") {
      logger.info("Authorized pilot record purge preserved.", {
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
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.mutateRuntimeJobModulePopulation,
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
    serviceAccount: FUNCTION_RUNTIME_SERVICE_ACCOUNTS.mutateUserAuthority,
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

// ─── Callable: atomic charge-abnormality and quality mutation ────────────────

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
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.mutateChargeAbnormality,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<MutateChargeAbnormalityRequest>) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation<
        ChargeAbnormalityMutationResult | QualityMutationResult
      >({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "mutateChargeAbnormality",
        authorize: (userData) =>
          isQualityMutationOperation(request.data?.operation) ?
            userCanMutateQuality(userData, request.data.operation) :
            userCanMutateChargeAbnormality(userData),
        execute: () => isQualityMutationOperation(request.data?.operation) ?
          mutateQualityWithDb({
            db: db as unknown as QualityMutationFirestoreLike,
            authUid: request.auth?.uid ?? null,
            data: request.data ?? {},
            timestampFromDate: admin.firestore.Timestamp.fromDate,
          }) :
          mutateChargeAbnormalityWithDb({
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
      if (error instanceof QualityMutationError) {
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

// ─── Callable: governed asset-hierarchy mutation ────────────────────────────

interface MutateAssetHierarchyRequest {
  [key: string]: unknown;
}

export const mutateAssetHierarchy = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    concurrency: 20,
    serviceAccount: FUNCTION_RUNTIME_SERVICE_ACCOUNTS.mutateAssetHierarchy,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<MutateAssetHierarchyRequest>) => {
    try {
      const db = admin.firestore();
      return await executeAuthorizedMutation<
        AssetHierarchyMutationResult |
        AssetRegistryMutationResult |
        InnerCoverLifecycleMutationResult |
        AssetOperationalConditionMutationResult |
        BurnerConditionRoundMutationResult |
        OperationalEventMutationResult |
        OperationalEventIssueLinkMutationResult |
        DeviceRecoveryMutationResult
      >({
        db,
        authUid: request.auth?.uid ?? null,
        callableName: "mutateAssetHierarchy",
        authorize: (userData) =>
          isDeviceRecoveryOperation(request.data?.operation) ?
            userCanMutateDeviceRecovery(
              userData,
              request.data.operation,
            ) || userCanResumeClaimedDeviceRecovery({
              db,
              actorUid: request.auth?.uid ?? null,
              actorData: userData,
              data: request.data ?? {},
            }) :
          isBurnerConditionRoundOperation(request.data?.operation) ?
            userCanRecordBurnerConditionRound(userData) :
          isOperationalEventIssueLinkOperation(request.data?.operation) ?
            userCanLinkOperationalEventIssue(userData) :
          isOperationalEventOperation(request.data?.operation) ?
            userCanMutateOperationalEvent(userData, request.data.operation) :
          isAssetOperationalConditionOperation(request.data?.operation) ?
            userCanMutateAssetOperationalCondition(
              userData,
              request.data.operation,
            ) :
            userCanMutateAssetHierarchy(userData),
        execute: () => {
          if (isDeviceRecoveryOperation(request.data?.operation)) {
            return mutateDeviceRecoveryWithDb({
              db,
              authUid: request.auth?.uid ?? null,
              data: request.data ?? {},
              timestampFromDate: admin.firestore.Timestamp.fromDate,
            });
          }
          const args = {
            db: db as unknown as AssetHierarchyMutationFirestoreLike,
            authUid: request.auth?.uid ?? null,
            data: request.data ?? {},
            timestampFromDate: admin.firestore.Timestamp.fromDate,
          };
          if (isBurnerConditionRoundOperation(request.data?.operation)) {
            return mutateBurnerConditionRoundWithDb(args);
          }
          if (isOperationalEventIssueLinkOperation(request.data?.operation)) {
            return mutateOperationalEventIssueLinkWithDb(args);
          }
          if (isOperationalEventOperation(request.data?.operation)) {
            return mutateOperationalEventWithDb(args);
          }
          if (isAssetOperationalConditionOperation(request.data?.operation)) {
            return mutateAssetOperationalConditionWithDb(args);
          }
          if (isInnerCoverLifecycleOperation(request.data?.operation)) {
            return mutateInnerCoverLifecycleWithDb(args);
          }
          return isAssetRegistryOperation(request.data?.operation) ?
              mutateAssetRegistryWithDb(args) :
              mutateAssetHierarchyWithDb(args);
        },
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AssetHierarchyMutationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      if (error instanceof DeviceRecoveryMutationError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      logger.error("mutateAssetHierarchy failed", error);
      throw new HttpsError(
        "internal",
        "Server-governed asset-hierarchy mutation failed.",
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

function notificationReceiptRuntime(
  db: NotifFirestoreLike,
): NotificationReceiptRuntime {
  return {
    db: db as unknown as NotificationReceiptFirestoreLike,
    serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
    reportDeliveryUncertain: (signal) => {
      logger.error("Notification delivery requires governed adjudication", signal);
    },
  };
}

function logOutcome(
  fn: string,
  outcome: {
    attempted: number;
    succeeded: number;
    failed: number;
    retryableFailures: number;
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

function logNotificationResult(
  fn: string,
  result: NotificationEventExecutionResult,
): void {
  if (result.kind === "completed") {
    logOutcome(fn, result.outcome);
    return;
  }
  logger.info(`${fn} did not dispatch`, result);
}

export const onTicketCreated = onDocumentCreated(
  {
    document: "maintenance_records/{ticketId}",
    region: NOTIFICATION_REGION,
    retry: true,
    serviceAccount: FUNCTION_RUNTIME_SERVICE_ACCOUNTS.onTicketCreated,
  },
  async (event) => {
    const ticket = event.data?.data();
    if (ticket == null || ticket.isDeleted === true) return;
    const plan = buildTicketCreatedNotification(ticket);
    const db = firestoreAdapter();
    const result = await executeIdempotentNotificationEvent({
      runtime: notificationReceiptRuntime(db),
      triggerName: "onTicketCreated",
      cloudEventId: event.id,
      sourceDocumentPath: `maintenance_records/${event.params.ticketId}`,
      prepare: async () => ({
        recipients: await getTokenLookupsForRoles(db, plan.roles),
      }),
      dispatch: ({recipients}): Promise<SendOutcome> => sendNotification({
        db,
        messaging: messagingAdapter(),
        recipients,
        title: plan.title,
        body: plan.body,
      }),
    });
    logNotificationResult("onTicketCreated", result);
  },
);

export const onTicketResolved = onDocumentUpdated(
  {
    document: "maintenance_records/{ticketId}",
    region: NOTIFICATION_REGION,
    retry: true,
    serviceAccount: FUNCTION_RUNTIME_SERVICE_ACCOUNTS.onTicketResolved,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before == null || after == null) return;
    const resolvedNow = before.isResolved !== after.isResolved &&
      after.isResolved === true;
    const plan = resolvedNow ?
      buildTicketResolvedNotification(after) :
      buildTicketLaneAddedNotification(before, after);
    if (plan == null) return;
    const db = firestoreAdapter();
    const result = await executeIdempotentNotificationEvent({
      runtime: notificationReceiptRuntime(db),
      triggerName: "onTicketResolved",
      cloudEventId: event.id,
      sourceDocumentPath: `maintenance_records/${event.params.ticketId}`,
      prepare: async () => {
        const roleRecipients = await getTokenLookupsForRoles(db, plan.roles);
        const recipients = [...roleRecipients];
        if (plan.loggedByUid != null) {
          const loggedByLookups = await getTokenLookupsForUser(
            db,
            plan.loggedByUid,
          );
          recipients.push(...loggedByLookups);
        }
        return {recipients};
      },
      dispatch: ({recipients}): Promise<SendOutcome> => sendNotification({
        db,
        messaging: messagingAdapter(),
        recipients,
        title: plan.title,
        body: plan.body,
      }),
    });
    logNotificationResult("onTicketResolved", result);
  },
);

export const onJobAssigned = onDocumentCreated(
  {
    document: "job_executions/{executionId}",
    region: NOTIFICATION_REGION,
    retry: true,
    serviceAccount: FUNCTION_RUNTIME_SERVICE_ACCOUNTS.onJobAssigned,
  },
  async (event) => {
    const execution = event.data?.data();
    if (execution == null || execution.isDeleted === true) return;

    const db = firestoreAdapter();
    const result = await executeIdempotentNotificationEvent({
      runtime: notificationReceiptRuntime(db),
      triggerName: "onJobAssigned",
      cloudEventId: event.id,
      sourceDocumentPath: `job_executions/${event.params.executionId}`,
      prepare: async () => {
        const plan = buildJobAssignedNotification(execution);
        if (plan == null) return null;
        return {
          plan,
          recipients: await getTokenLookupsForRoles(db, plan.roles),
        };
      },
      dispatch: ({plan, recipients}): Promise<SendOutcome> => sendNotification({
        db,
        messaging: messagingAdapter(),
        recipients,
        title: plan.title,
        body: plan.body,
        unknownAgencies: plan.unknownAgencies,
      }),
    });
    logNotificationResult("onJobAssigned", result);
  },
);

// ─── Maintenance workflow control plane ───────────────────────────────
export {
  executeMaintenanceWorkflowCommand,
  maintenanceWorkflowEscalationSweep,
  onMaintenanceWorkflowEventCreated,
} from "./maintenanceWorkflow/firebaseExports";
