import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {MaintenanceWorkflowCommandService} from "./dispatcher";
import {WorkflowError} from "./errors";
import {FirebaseWorkflowStore} from "./firebaseStore";
import {MUTATING_CALLABLE_SECURITY_OPTIONS} from "../callableSecurityConfig";
import {FUNCTION_RUNTIME_SERVICE_ACCOUNTS} from "../functionFleetRuntimeIdentity";
import {canonicalApprovedUserAuthority} from "../userAuthority";
import {
  CallableAbuseControlError,
  executeWithCallableAbuseControl,
} from "../callableAbuseControl";
import type {
  CallableAbuseFirestoreLike,
} from "../callableAbuseControl";
import {
  Actor,
  CommandActorIdentity,
  JsonMap,
  RoleKey,
  WorkflowCommand,
  WorkflowCommandType,
} from "./types";

const CALLABLE_REGION = "asia-south1";
const commandTypes = new Set<WorkflowCommandType>([
  "createLegacyWorkflowJob",
  "finalizeLaneSet", "acknowledgeLane", "addLane", "removeLane",
  "terminateLane", "closeLane", "cancelWorkflow", "raiseCompliance",
  "acknowledgeCompliance", "confirmConditionAndReactivate",
  "markComplianceComplied", "returnComplianceForCorrection",
  "confirmComplianceClosed", "proposeCounterCondition",
  "decideCounterCondition", "prepareRedLane", "reopenWorkflowModule", "finalizeJob", "deployEquipment",
  "reconcileEquipment",
]);

const parseCommand = (raw: unknown): WorkflowCommand => {
  const data = (raw ?? {}) as Record<string, unknown>;
  if (typeof data.commandId !== "string" ||
      typeof data.commandType !== "string" ||
      !commandTypes.has(data.commandType as WorkflowCommandType) ||
      typeof data.aggregateId !== "string" ||
      typeof data.expectedVersion !== "number" ||
      !Number.isSafeInteger(data.expectedVersion) ||
      data.expectedVersion < 0 ||
      data.payload == null || typeof data.payload !== "object" || Array.isArray(data.payload)) {
    throw new HttpsError("invalid-argument", "Workflow command envelope is invalid.");
  }
  return {
    commandId: data.commandId.trim(),
    commandType: data.commandType as WorkflowCommandType,
    aggregateId: data.aggregateId.trim(),
    expectedVersion: data.expectedVersion,
    payload: data.payload as JsonMap,
  };
};

export const workflowActorFromUserDataForTest = (
  data: Record<string, unknown>,
  uid: string,
  tokenName?: string,
): Actor => {
  // v4.2 has one approval schema. Legacy aliases such as `approved`,
  // `status: approved`, or singular `role` are intentionally not authority.
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null) {
    throw new HttpsError(
      "permission-denied",
      "User approval or role data is malformed or unsupported.",
    );
  }
  const roles = new Set<RoleKey>([...authority.roles] as RoleKey[]);
  const storedName = typeof data.name === "string" ? data.name.trim() : "";
  return {
    uid,
    name: storedName.length > 0 ? storedName : tokenName?.trim() || uid,
    roles,
  };
};

const actorFromRequest = async (
  request: CallableRequest<unknown>,
  db: admin.firestore.Firestore,
): Promise<CommandActorIdentity> => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) throw new HttpsError("permission-denied", "Approved user record was not found.");
  const authorizedActor = workflowActorFromUserDataForTest(
    snap.data() ?? {},
    uid,
    request.auth?.token.name?.toString(),
  );
  return {
    uid: authorizedActor.uid,
    name: authorizedActor.name,
  };
};

const toHttpsError = (error: WorkflowError): HttpsError => {
  const nativeCodes = new Set([
    "invalid-argument", "unauthenticated", "permission-denied", "not-found",
    "already-exists", "failed-precondition", "aborted",
  ]);
  const code = error.code === "workflow-version-conflict" || error.code === "command-idempotency-conflict"
    ? "aborted"
    : error.code === "unsupported-workflow-command"
      ? "unimplemented"
      : nativeCodes.has(error.code)
        ? error.code as "invalid-argument" | "unauthenticated" | "permission-denied" | "not-found" | "already-exists" | "failed-precondition" | "aborted"
        : error.code === "unauthorized-represented-lane"
          ? "permission-denied"
          : "failed-precondition";
  return new HttpsError(code, error.message, {workflowCode: error.code, ...error.details});
};

export const executeMaintenanceWorkflowCommand = onCall(
  {
    region: CALLABLE_REGION,
    timeoutSeconds: 60,
    memory: "512MiB",
    concurrency: 20,
    serviceAccount:
      FUNCTION_RUNTIME_SERVICE_ACCOUNTS.executeMaintenanceWorkflowCommand,
    ...MUTATING_CALLABLE_SECURITY_OPTIONS,
  },
  async (request: CallableRequest<unknown>) => {
    const db = admin.firestore();
    try {
      const actor = await actorFromRequest(request, db);
      return await executeWithCallableAbuseControl({
        db: db as unknown as CallableAbuseFirestoreLike,
        actorUid: actor.uid,
        callableName: "executeMaintenanceWorkflowCommand",
        execute: async () => {
          const command = parseCommand(request.data);
          const service = new MaintenanceWorkflowCommandService(
            new FirebaseWorkflowStore(db),
          );
          return service.execute(command, {actor, serverNow: new Date()});
        },
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof CallableAbuseControlError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      if (error instanceof WorkflowError) throw toHttpsError(error);
      logger.error("executeMaintenanceWorkflowCommand failed", error);
      throw new HttpsError("internal", "Maintenance workflow command failed.");
    }
  },
);
