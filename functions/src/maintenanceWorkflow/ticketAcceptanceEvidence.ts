import {createHash} from "crypto";
import {Timestamp} from "firebase-admin/firestore";
import {WorkflowError} from "./errors";
import {WorkflowTransaction} from "./store";
import {JsonMap, WorkflowCommand} from "./types";
import {stableJson} from "./utils";

/** The receipt independently binds the audit accepted in the same transaction.
 * Canonical JSON ordering is representation, while names and business values
 * remain historical evidence. Legacy receipts are never retroactively hashed. */
export function maintenanceAuditDigest(audit: JsonMap): string {
  const canonical = (value: unknown, key = ""): unknown => {
    if (typeof value === "string" && key.endsWith("Json")) {
      try { return canonical(JSON.parse(value)); } catch { return value; }
    }
    if (Array.isArray(value)) return value.map((item) => canonical(item));
    if (value != null && typeof value === "object") return Object.fromEntries(
      Object.entries(value).map(([name, item]) => [name, canonical(item, name)]),
    );
    return value;
  };
  // The workflow adapter stores the audit's ISO timestamp as a native
  // Firestore Timestamp. Normalize only that representation change, retaining
  // the original millisecond precision and every audited business value.
  // A sub-millisecond alteration cannot be rounded into the accepted instant.
  const timestamp = audit.timestamp;
  const canonicalTimestamp = timestamp instanceof Timestamp &&
      timestamp.nanoseconds % 1_000_000 === 0 ? timestamp.toDate().toISOString() :
    timestamp instanceof Date && Number.isFinite(timestamp.getTime()) ?
      timestamp.toISOString() : timestamp;
  return `maintenanceaudit1-sha256:${createHash("sha256")
    .update(stableJson(canonical({...audit, timestamp: canonicalTimestamp}) as JsonMap), "utf8").digest("hex")}`;
}

export function captureMaintenanceAudit(tx: WorkflowTransaction, command: WorkflowCommand): {
  tx: WorkflowTransaction; digest: () => string | null;
} {
  let digest: string | null = null;
  const path = `audit_logs/server_maintenance_ticket_${command.commandId}`;
  return {
    digest: () => digest,
    tx: {
      get: (path) => tx.get(path), query: (collection, filters) => tx.query(collection, filters),
      create: (target, data) => {
        if (target === path) digest = maintenanceAuditDigest(data);
        tx.create(target, data);
      },
      set: (path, data, merge) => tx.set(path, data, merge),
      update: (path, data) => tx.update(path, data), delete: (path) => tx.delete(path),
    },
  };
}

export async function verifyMaintenanceAcceptanceDigest(
  tx: WorkflowTransaction, commandId: string, audit: JsonMap,
): Promise<void> {
  const receipt = await tx.get(`maintenance_workflow_command_receipts/${commandId}`);
  const expected = receipt.data?.maintenanceAuditDigest;
  if (expected !== undefined &&
      (typeof expected !== "string" || expected !== maintenanceAuditDigest(audit))) {
    throw new WorkflowError("failed-precondition",
      "The accepted maintenance evidence differs from its original receipt.",
      {reasonCode: "maintenance-ticket-replay-content-invalid"});
  }
}
