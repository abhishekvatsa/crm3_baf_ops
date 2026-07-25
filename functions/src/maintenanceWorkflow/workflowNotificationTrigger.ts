import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {
  getTokenLookupsForRoles,
  sendNotification,
} from "../notifications";
import {workflowRecipientRoles} from "./workflowNotificationPolicy";

const REGION = "asia-south1";
const RECEIPT_LEASE_MS = 5 * 60 * 1000;

async function acquireReceiptLease(
  db: admin.firestore.Firestore,
  eventId: string,
): Promise<boolean> {
  const receiptRef = db
    .collection("workflow_notification_receipts")
    .doc(eventId);
  const now = Date.now();

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(receiptRef);
    if (snapshot.exists) {
      const existing = snapshot.data() ?? {};
      if (existing.status === "completed") return false;
      const lease = existing.leaseExpiresAt;
      if (lease instanceof admin.firestore.Timestamp && lease.toMillis() > now) {
        return false;
      }
    }

    transaction.set(
      receiptRef,
      {
        eventId,
        status: "processing",
        leaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          now + RECEIPT_LEASE_MS,
        ),
        attemptCount: admin.firestore.FieldValue.increment(1),
        lastAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return true;
  });
}

export const onMaintenanceWorkflowEventCreated = onDocumentCreated(
  {
    document: "maintenance_workflow_events/{eventId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const eventId = event.params.eventId as string;
    const db = admin.firestore();
    const receiptRef = db
      .collection("workflow_notification_receipts")
      .doc(eventId);

    if (!(await acquireReceiptLease(db, eventId))) return;

    const eventType = String(data.eventType ?? "");
    const laneKey =
      typeof data.laneKey === "string" ? data.laneKey : null;
    const aggregateId = String(data.aggregateId ?? "");
    const payload = data.payload != null && typeof data.payload === "object"
      ? data.payload as Record<string, unknown>
      : {};
    const escalationTier = typeof payload.escalationTier === "number"
      ? payload.escalationTier
      : null;
    const roles = workflowRecipientRoles(eventType, laneKey, escalationTier);
    const isEscalation = eventType.endsWith("Escalated") ||
      eventType === "lane.escalated";
    const isEquipmentEvent = eventType.startsWith("equipment.");
    const assetTypeKey = typeof payload.assetTypeKey === "string"
      ? payload.assetTypeKey
      : null;
    const assetNumber = typeof payload.assetNumber === "number"
      ? payload.assetNumber
      : null;

    try {
      const recipients = await getTokenLookupsForRoles(db, roles);
      const outcome = await sendNotification({
        db,
        messaging: admin.messaging(),
        recipients,
        title: isEscalation
          ? `Maintenance escalation T${escalationTier ?? 1}`
          : "Maintenance workflow update",
        body: isEscalation
          ? `${laneKey?.toUpperCase() ?? "Workflow"} action is overdue`
          : eventType || "Workflow state changed",
        data: {
          route: isEquipmentEvent
            ? "/maintenance-equipment"
            : `/maintenance-workflow/${aggregateId}`,
          destinationType: isEquipmentEvent ? "equipment" : "workflow",
          aggregateId,
          eventId,
          ...(assetTypeKey == null ? {} : {assetTypeKey}),
          ...(assetNumber == null ? {} : {assetNumber: String(assetNumber)}),
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
      });

      await receiptRef.set(
        {
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
          roles,
          recipientCount: outcome.attempted,
          succeededCount: outcome.succeeded,
          failedCount: outcome.failed,
          staleTokensCleared: outcome.staleTokensCleared,
        },
        {merge: true},
      );
      logger.info("Workflow notification processed", {
        eventId,
        recipientCount: outcome.attempted,
        succeededCount: outcome.succeeded,
        failedCount: outcome.failed,
      });
    } catch (error) {
      await receiptRef.set(
        {
          status: "failed",
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
          lastError: error instanceof Error ? error.message : String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      logger.error("Workflow notification failed", {eventId, error});
      throw error;
    }
  },
);
