const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// ── Helper: get FCM tokens for given roles ────────────────────────────────────

async function getTokensForRoles(roles) {
  const snapshot = await db.collection("users")
    .where("isApproved", "==", true)
    .get();

  const tokens = [];
  snapshot.forEach(doc => {
    const user = doc.data();
    const userRoles = user.roles || [];
    const hasRole = userRoles.some(r => roles.includes(r));
    if (hasRole && user.fcmToken) {
      tokens.push(user.fcmToken);
    }
  });
  return tokens;
}

// ── Helper: get FCM token for specific user ───────────────────────────────────

async function getTokenForUser(uid) {
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

// ── Helper: send notifications ────────────────────────────────────────────────

async function sendNotifications(tokens, title, body) {
  if (!tokens || tokens.length === 0) return;

  const unique = [...new Set(tokens)];

  const messages = unique.map(token => ({
    token,
    notification: { title, body },
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "crm3_baf_ops",
      },
    },
  }));

  for (let i = 0; i < messages.length; i += 500) {
    const batch = messages.slice(i, i + 500);
    await getMessaging().sendEach(batch);
  }
}

// ── Trigger 1: Breakdown ticket created ──────────────────────────────────────

exports.onTicketCreated = onDocumentCreated(
  { document: "maintenance_records/{ticketId}", region: "asia-south1" },
  async (event) => {
    const ticket = event.data.data();
    if (!ticket) return;

    const assetLabel = `${(ticket.assetType || "").toUpperCase()} ${ticket.assetNumber}`;
    const description = ticket.description || "New breakdown";
    const routedTo = ticket.routedTo || "";

    const roles = ["admin", "si", "contractSupervisor", "shiftSupervisor"];

    if (routedTo === "refractory") {
      roles.push("refractory", "seniorRefractory");
    }

    const tokens = await getTokensForRoles(roles);

    await sendNotifications(
      tokens,
      `🔴 Breakdown: ${assetLabel}`,
      `${description} — Routed to ${routedTo.toUpperCase()}`
    );
  }
);

// ── Trigger 2: Breakdown ticket resolved ─────────────────────────────────────

exports.onTicketResolved = onDocumentUpdated(
  { document: "maintenance_records/{ticketId}", region: "asia-south1" },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.isResolved === after.isResolved) return;
    if (!after.isResolved) return;

    const assetLabel = `${(after.assetType || "").toUpperCase()} ${after.assetNumber}`;
    const closedBy = after.closedByName || "Unknown";

    const tokens = [];

    if (after.loggedByUid) {
      const token = await getTokenForUser(after.loggedByUid);
      if (token) tokens.push(token);
    }

    const roleTokens = await getTokensForRoles(["admin", "si"]);
    tokens.push(...roleTokens);

    await sendNotifications(
      tokens,
      `✅ Resolved: ${assetLabel}`,
      `Closed by ${closedBy} — ${after.remarks || "No remarks"}`
    );
  }
);

// ── Trigger 3: Planned job assigned ──────────────────────────────────────────

exports.onJobAssigned = onDocumentCreated(
  { document: "job_executions/{executionId}", region: "asia-south1" },
  async (event) => {
    const execution = event.data.data();
    if (!execution) return;

    const assetLabel = `${(execution.assetType || "").toUpperCase()} ${execution.assetNumber}`;
    const templateName = execution.templateName || "Planned Job";
    const agencies = execution.assignedAgencies || [];

    if (agencies.length === 0) return;

    const tokens = await getTokensForRoles(agencies);

    await sendNotifications(
      tokens,
      `📋 Job Assigned: ${templateName}`,
      `Asset: ${assetLabel} — Assigned by ${execution.assignedByName || "Unknown"}`
    );
  }
);