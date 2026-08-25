import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {FUNCTION_RUNTIME_SERVICE_ACCOUNTS} from "../functionFleetRuntimeIdentity";
import {
  executeIdempotentNotificationEvent,
} from "../notificationEventReceipt";
import type {
  NotificationReceiptFirestoreLike,
  NotificationReceiptRuntime,
} from "../notificationEventReceipt";
import {
  getTokenLookupsForUser,
  getTokenLookupsForRoles,
  sendNotification,
} from "../notifications";
import type {
  FirestoreLike as NotificationFirestoreLike,
  MessagingLike,
  SendOutcome,
} from "../notifications";
import {workflowRecipientRoles} from "./workflowNotificationPolicy";

const REGION = "asia-south1";

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
            const recipients = (await getTokenLookupsForUser(
              notificationDb(db),
              recovery.targetUid,
            )).filter((recipient) =>
              recipient.installationId === recovery.installationId
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
          data: plan.notificationData as Readonly<Record<string, string>>,
        }),
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
