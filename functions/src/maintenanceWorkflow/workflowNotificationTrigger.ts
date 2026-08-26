import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {deviceRecoveryStateDocumentId} from "../deviceRecoveryMutation";
import {FUNCTION_RUNTIME_SERVICE_ACCOUNTS} from "../functionFleetRuntimeIdentity";
import {
  executeIdempotentNotificationEvent,
} from "../notificationEventReceipt";
import type {
  NotificationReceiptFirestoreLike,
  NotificationReceiptRuntime,
} from "../notificationEventReceipt";
import {
  getTokenLookupForInstallation,
  getTokenLookupsForApprovedUsers,
  getTokenLookupsForRoles,
  sendNotification,
} from "../notifications";
import type {
  FirestoreLike as NotificationFirestoreLike,
  MessagingLike,
  SendOutcome,
  UserTokenLookup,
} from "../notifications";
import {
  isCriticalAlarmEventType,
  isNotifiableCriticalAlarmStatus,
  samePersistedNotificationInstant,
  shouldRetryCriticalAlarmRecipientFailure,
  shouldRetryKnownWorkflowNotificationFailure,
  workflowRecipientRoles,
} from "./workflowNotificationPolicy";

const REGION = "asia-south1";

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null;
  if (candidate == null || typeof candidate.toMillis !== "function") {
    return null;
  }
  const millis = candidate.toMillis();
  return Number.isSafeInteger(millis) && millis >= 0 ? millis : null;
}

function notificationDb(
  db: admin.firestore.Firestore,
): NotificationFirestoreLike {
  return db as unknown as NotificationFirestoreLike;
}

function notificationRuntime(
  db: admin.firestore.Firestore,
): NotificationReceiptRuntime {
  return {
    db: db as unknown as NotificationReceiptFirestoreLike,
    serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
    reportDeliveryUncertain: (signal) => {
      logger.error("Notification delivery requires governed adjudication", signal);
    },
  };
}

interface CriticalAlarmNotificationPlan {
  recipients: ReadonlyArray<UserTokenLookup>;
  title: string;
  body: string;
  notificationData: Readonly<Record<string, string>>;
  androidChannelId: string;
  androidNotificationTag: string;
}

function dedupeCriticalAlarmRecipients(
  recipients: ReadonlyArray<UserTokenLookup>,
): UserTokenLookup[] {
  const byToken = new Map<string, UserTokenLookup>();
  for (const recipient of recipients) {
    if (!byToken.has(recipient.fcmToken)) {
      byToken.set(recipient.fcmToken, recipient);
    }
  }
  return [...byToken.values()];
}

function criticalAlarmRecipientCloudEventId(
  cloudEventId: string,
  fcmToken: string,
): string {
  const recipientDigest = createHash("sha256")
    .update("critical-alarm-recipient-v1\0")
    .update(fcmToken)
    .digest("hex");
  return `${cloudEventId}:recipient:${recipientDigest}`;
}

async function prepareCriticalAlarmNotification(args: {
  db: admin.firestore.Firestore;
  data: admin.firestore.DocumentData;
  sourceEventId: string;
}): Promise<CriticalAlarmNotificationPlan | null> {
  const {db, data, sourceEventId} = args;
  const aggregateId = String(data.aggregateId ?? "");
  const payload = data.payload != null && typeof data.payload === "object" ?
    data.payload as Record<string, unknown> : {};
  const alarmId = typeof payload.alarmId === "string" ? payload.alarmId : "";
  if (alarmId.length === 0 || aggregateId !== alarmId) return null;

  const snapshot = await db.collection("critical_alarms").doc(alarmId).get();
  const alarm = snapshot.data();
  if (!snapshot.exists || alarm?.schemaVersion !== 1 ||
      alarm.alarmId !== alarmId ||
      !isNotifiableCriticalAlarmStatus(alarm.status) ||
      !Number.isSafeInteger(alarm.version) || alarm.version < 1 ||
      alarm.raisedByUid !== data.actorUid ||
      alarm.raisedByName !== data.actorName ||
      !samePersistedNotificationInstant(alarm.raisedAt, data.occurredAt) ||
      !samePersistedNotificationInstant(alarm.createdAt, data.occurredAt) ||
      alarm.alarmTypeKey !== payload.alarmTypeKey ||
      alarm.alarmTypeName !== payload.alarmTypeName ||
      alarm.criticalityKey !== payload.criticalityKey ||
      alarm.criticalityRank !== payload.criticalityRank ||
      alarm.location !== payload.location) {
    logger.warn("Critical alarm notification is stale or invalid", {
      eventId: sourceEventId,
      alarmId,
    });
    return null;
  }

  const recipients = dedupeCriticalAlarmRecipients(
    await getTokenLookupsForApprovedUsers(notificationDb(db)),
  );
  const typeName = typeof alarm.alarmTypeName === "string" ?
    alarm.alarmTypeName : "Critical safety alarm";
  const criticality = alarm.criticalityKey === "highest" ?
    "HIGHEST" : "CRITICAL";
  const location = typeof alarm.location === "string" ?
    alarm.location : "Location not recorded";
  const raiser = typeof alarm.raisedByName === "string" ?
    alarm.raisedByName : "Approved user";
  return {
    recipients,
    title: `${criticality}: ${typeName}`,
    body: `${location} - raised by ${raiser}. Follow the plant emergency procedure.`,
    notificationData: {
      destinationType: "critical_alarm",
      aggregateId: alarmId,
      alarmId,
      alarmTypeKey: String(alarm.alarmTypeKey),
      criticalityKey: String(alarm.criticalityKey),
      eventId: sourceEventId,
    },
    androidChannelId: "crm3_critical_safety",
    androidNotificationTag: `critical-alarm-${alarmId}`,
  };
}

async function processCriticalAlarmRaisedNotification(args: {
  db: admin.firestore.Firestore;
  data: admin.firestore.DocumentData;
  sourceEventId: string;
  cloudEventId: string;
}): Promise<void> {
  const {db, data, sourceEventId, cloudEventId} = args;
  const legacyReceipt = await db.collection("workflow_notification_receipts")
    .doc(sourceEventId)
    .get();
  if (legacyReceipt.exists) {
    logger.warn("Legacy workflow notification receipt quarantined", {
      eventId: sourceEventId,
      cloudEventId,
    });
    return;
  }

  const plan = await prepareCriticalAlarmNotification({db, data, sourceEventId});
  if (plan == null) return;

  const failures: unknown[] = [];
  let completed = 0;
  let skipped = 0;
  for (let offset = 0; offset < plan.recipients.length; offset += 25) {
    const batch = plan.recipients.slice(offset, offset + 25);
    const outcomes = await Promise.allSettled(batch.map(async (recipient) => {
      const recipientPlan: CriticalAlarmNotificationPlan = {
        ...plan,
        recipients: [recipient],
      };
      return executeIdempotentNotificationEvent({
        runtime: notificationRuntime(db),
        triggerName: "onCriticalAlarmRecipientNotification",
        cloudEventId: criticalAlarmRecipientCloudEventId(
          cloudEventId,
          recipient.fcmToken,
        ),
        sourceDocumentPath: `maintenance_workflow_events/${sourceEventId}`,
        prepare: async () => recipientPlan,
        dispatch: (prepared): Promise<SendOutcome> => sendNotification({
          db: notificationDb(db),
          messaging: admin.messaging() as unknown as MessagingLike,
          recipients: prepared.recipients,
          title: prepared.title,
          body: prepared.body,
          data: prepared.notificationData,
          androidChannelId: prepared.androidChannelId,
          androidNotificationTag: prepared.androidNotificationTag,
        }),
        retryKnownFailure: (_prepared, outcome) =>
          shouldRetryCriticalAlarmRecipientFailure(outcome),
      });
    }));
    for (const outcome of outcomes) {
      if (outcome.status === "rejected") {
        failures.push(outcome.reason);
      } else if (outcome.value.kind === "completed") {
        completed += 1;
      } else {
        skipped += 1;
      }
    }
  }

  logger.info("Critical alarm recipient notifications processed", {
    eventId: sourceEventId,
    recipientCount: plan.recipients.length,
    completedCount: completed,
    skippedCount: skipped,
    failedCount: failures.length,
  });
  if (failures.length > 0) throw failures[0];
}

export const onMaintenanceWorkflowEventCreated = onDocumentCreated(
  {
    document: "maintenance_workflow_events/{eventId}",
    region: REGION,
    retry: true,
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.onMaintenanceWorkflowEventCreated,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const sourceEventId = event.params.eventId as string;
    const db = admin.firestore();
    try {
      if (data.eventType === "criticalAlarm.raised") {
        await processCriticalAlarmRaisedNotification({
          db,
          data,
          sourceEventId,
          cloudEventId: event.id,
        });
        return;
      }
      const result = await executeIdempotentNotificationEvent({
        runtime: notificationRuntime(db),
        triggerName: "onMaintenanceWorkflowEventCreated",
        cloudEventId: event.id,
        sourceDocumentPath: `maintenance_workflow_events/${sourceEventId}`,
        prepare: async () => {
          const legacyReceipt = await db
            .collection("workflow_notification_receipts")
            .doc(sourceEventId)
            .get();
          if (legacyReceipt.exists) {
            logger.warn("Legacy workflow notification receipt quarantined", {
              eventId: sourceEventId,
              cloudEventId: event.id,
            });
            return null;
          }

          const eventType = String(data.eventType ?? "");
          const laneKey =
            typeof data.laneKey === "string" ? data.laneKey : null;
          const aggregateId = String(data.aggregateId ?? "");
          const payload = data.payload != null &&
              typeof data.payload === "object"
            ? data.payload as Record<string, unknown>
            : {};
          const escalationTier = typeof payload.escalationTier === "number"
            ? payload.escalationTier
            : null;
          if (eventType === "deviceRecovery.requested") {
            const requestId = typeof payload.deviceRecoveryRequestId === "string" ?
              payload.deviceRecoveryRequestId : "";
            if (requestId.length === 0 || aggregateId !== requestId ||
                sourceEventId !== `device_recovery_${requestId}`) return null;
            const receipt = await db.collection("device_recovery_receipts")
              .doc(requestId)
              .get();
            const recovery = receipt.data();
            if (!receipt.exists || recovery?.schemaVersion !== 1 ||
                recovery.requestId !== requestId ||
                recovery.actorUid !== data.actorUid ||
                typeof recovery.targetUid !== "string" ||
                typeof recovery.installationId !== "string") {
              logger.error("Device recovery notification receipt is invalid", {
                eventId: sourceEventId,
                requestId,
              });
              return null;
            }
            const stateSnapshot = await db
              .collection("device_recovery_requests")
              .doc(deviceRecoveryStateDocumentId(
                recovery.targetUid,
                recovery.installationId,
              ))
              .get();
            const state = stateSnapshot.data();
            const expiresAtMillis = timestampMillis(state?.expiresAt);
            if (!stateSnapshot.exists || state?.schemaVersion !== 1 ||
                state.requestId !== requestId ||
                state.targetUid !== recovery.targetUid ||
                state.installationId !== recovery.installationId ||
                state.status !== "pending" || expiresAtMillis == null ||
                expiresAtMillis <= Date.now()) {
              logger.info("Device recovery notification is no longer active", {
                eventId: sourceEventId,
                requestId,
              });
              return null;
            }
            const recipients = await getTokenLookupForInstallation(
              notificationDb(db),
              recovery.targetUid,
              recovery.installationId,
            );
            return {
              recipients,
              roles: ["target-installation"],
              title: "Administrator requested a device refresh",
              body: "Open CRM-III BAF Ops to back up and refresh this phone.",
              notificationData: {
                destinationType: "admin_device_reset",
                aggregateId: requestId,
                requestId,
                installationId: recovery.installationId,
                eventId: sourceEventId,
              },
            };
          }
          if (isCriticalAlarmEventType(eventType)) return null;
          const roles = workflowRecipientRoles(
            eventType,
            laneKey,
            escalationTier,
          );
          const recipients = await getTokenLookupsForRoles(
            notificationDb(db),
            roles,
          );
          const isEscalation = eventType.endsWith("Escalated") ||
            eventType === "lane.escalated";
          const isEquipmentEvent = eventType.startsWith("equipment.");
          const assetTypeKey = typeof payload.assetTypeKey === "string"
            ? payload.assetTypeKey
            : null;
          const assetNumber = typeof payload.assetNumber === "number"
            ? payload.assetNumber
            : null;
          return {
            recipients,
            roles,
            title: isEscalation
              ? `Maintenance escalation T${escalationTier ?? 1}`
              : "Maintenance workflow update",
            body: isEscalation
              ? `${laneKey?.toUpperCase() ?? "Workflow"} action is overdue`
              : eventType || "Workflow state changed",
            notificationData: {
              route: isEquipmentEvent
                ? "/maintenance-equipment"
                : `/maintenance-workflow/${aggregateId}`,
              destinationType: isEquipmentEvent ? "equipment" : "workflow",
              aggregateId,
              eventId: sourceEventId,
              ...(assetTypeKey == null ? {} : {assetTypeKey}),
              ...(assetNumber == null ? {} : {
                assetNumber: String(assetNumber),
              }),
              ...(laneKey == null ? {} : {laneKey}),
              ...(escalationTier == null ? {} : {
                escalationTier: String(escalationTier),
              }),
              ...(typeof payload.sourceCollection === "string" ? {
                sourceCollection: payload.sourceCollection,
              } : {}),
              ...(typeof payload.sourceDocumentId === "string" ? {
                sourceDocumentId: payload.sourceDocumentId,
              } : {}),
              ...(typeof payload.complianceId === "string" ? {
                complianceId: payload.complianceId,
                sourceCollection: "compliance_requests",
              } : {}),
            },
          };
        },
        dispatch: (plan): Promise<SendOutcome> => sendNotification({
          db: notificationDb(db),
          messaging: admin.messaging() as unknown as MessagingLike,
          recipients: plan.recipients,
          title: plan.title,
          body: plan.body,
          data: plan.notificationData as unknown as Readonly<Record<string, string>>,
        }),
        retryKnownFailure: (_plan, outcome) =>
          shouldRetryKnownWorkflowNotificationFailure(
            data.eventType,
            outcome,
          ),
      });

      if (result.kind === "completed") {
        logger.info("Workflow notification processed", {
          eventId: sourceEventId,
          receiptId: result.receiptId,
          recipientCount: result.outcome.attempted,
          succeededCount: result.outcome.succeeded,
          failedCount: result.outcome.failed,
        });
      } else {
        logger.info("Workflow notification did not dispatch", {
          eventId: sourceEventId,
          ...result,
        });
      }
    } catch (error) {
      logger.error("Workflow notification failed", {
        eventId: sourceEventId,
        cloudEventId: event.id,
        error,
      });
      throw error;
    }
  },
);
