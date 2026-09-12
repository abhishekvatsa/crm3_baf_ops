import {createHash} from "crypto";
import {HttpsError} from "firebase-functions/v2/https";
import {canonicalApprovedUserAuthority} from "./userAuthority";
import {canonicalWorkflowAuthorityScope} from "./maintenanceWorkflow/commandAuthority";
import {isQualityMutationOperation} from "./qualityMutation";
import {isInnerCoverLifecycleOperation} from "./innerCoverLifecycleMutation";

type JsonMap = {[key: string]: unknown};
type Snapshot = {exists: boolean; data(): JsonMap | undefined};
type Ref = {readonly path?: string};
type Transaction = {
  get(ref: Ref): Promise<Snapshot>;
  create(ref: Ref, data: JsonMap): unknown;
};
export type SubmissionRecoveryDb = {
  collection(name: string): {doc(id: string): Ref};
  runTransaction<T>(body: (tx: Transaction) => Promise<T>): Promise<T>;
};

export const SUBMISSION_RECOVERY_PROTOCOL = "savedSubmissionReview.v1";
export const SUBMISSION_RECOVERY_COLLECTIONS = Object.freeze({
  decisions: "submission_recovery_decisions",
  fences: "submission_recovery_fences",
  controls: "submission_recovery_controls",
});
export const SUBMISSION_RECOVERY_DOMAINS = Object.freeze({
  morningReview: {endpoint: "mutateAssetHierarchyV2", receipts: "morning_review_mutation_receipts"},
  burnerEvidence: {endpoint: "mutateAssetHierarchyV2", receipts: "burner_condition_round_receipts"},
  innerCoverAcceptance: {endpoint: "mutateAssetHierarchyV2", receipts: "inner_cover_lifecycle_receipts"},
  qualityMonitoring: {endpoint: "mutateChargeAbnormalityV2", receipts: "quality_mutation_receipts"},
  publishedTemplateAssignment: {endpoint: "assignPublishedTemplateVersionV2", receipts: "published_template_assignment_requests"},
  inspectionCampaign: {endpoint: "executeMaintenanceWorkflowCommandV2", receipts: "maintenance_workflow_command_receipts"},
});
type Domain = keyof typeof SUBMISSION_RECOVERY_DOMAINS;
const GUARDED_CALLABLES = Object.freeze([
  "mutateAssetHierarchy", "mutateAssetHierarchyV2",
  "mutateChargeAbnormality", "mutateChargeAbnormalityV2",
  "assignPublishedTemplateVersion", "assignPublishedTemplateVersionV2",
  "executeMaintenanceWorkflowCommand", "executeMaintenanceWorkflowCommandV2",
]);
const MORNING_STATUSES: {[operation: string]: readonly string[]} = {
  START_MORNING_REVIEW: ["open"], JOIN_MORNING_REVIEW: ["joined"],
  ADD_MORNING_REVIEW_ENTRY: ["recorded"], CREATE_MORNING_REVIEW_ACTION: ["open"],
  ACCEPT_MORNING_REVIEW_ACTION: ["accepted"], COMPLETE_MORNING_REVIEW_ACTION: ["completed"],
  TAKE_OVER_MORNING_REVIEW: ["open"], FINALIZE_MORNING_REVIEW: ["finalized"],
  RECORD_MORNING_REVIEW_NOT_HELD: ["notHeld"], CREATE_MORNING_REVIEW_STANDING_CONCERN: ["active"],
  RESOLVE_MORNING_REVIEW_STANDING_CONCERN: ["resolved"],
  CHECK_MORNING_REVIEW_STANDING_CONCERN: ["complied", "exception"],
  ADD_MORNING_REVIEW_ADDENDUM: ["addendum"],
};
const SHA = /^[0-9a-f]{64}$/;
const text = (value: unknown, max = 256): value is string =>
  typeof value === "string" && value.length > 0 && value.length <= max && value.trim() === value;
const displayText = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0;
const record = (value: unknown): value is JsonMap =>
  value != null && typeof value === "object" && !Array.isArray(value);
const positive = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) > 0;
const fail = (reasonCode: string, message: string): never => {
  throw new HttpsError("failed-precondition", message, {reasonCode});
};
const invalid = (): never => {
  throw new HttpsError("invalid-argument", "The saved-submission review request is invalid.",
    {reasonCode: "submission-recovery-request-invalid"});
};
const malformed = (): never => fail("submission-recovery-receipt-malformed",
  "Existing receipt evidence is malformed or unsupported. Preserve the saved work for investigation.");
const iso = (value: unknown): value is string => {
  if (typeof value !== "string" || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value)) return false;
  const date = new Date(value);
  return Number.isFinite(date.valueOf()) && date.toISOString() === value;
};
const wireInstant = (value: unknown): boolean => typeof value === "string" &&
  /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.(?:\d{3}|\d{6})Z$/.test(value) &&
  iso(`${value.slice(0, 23)}Z`);

// Preserve every stored field and sub-millisecond timestamp in the review hash.
// Never hash Date/Timestamp instances as empty maps or normalize retained bytes.
function canonical(value: unknown, depth = 0): unknown {
  if (depth > 30) return malformed();
  if (value === null) return ["null"];
  if (typeof value === "string" || typeof value === "boolean") return [typeof value, value];
  if (typeof value === "number" && Number.isFinite(value)) return ["number", value];
  if (value instanceof Date) {
    if (!Number.isFinite(value.valueOf())) return malformed();
    return ["date", value.valueOf()];
  }
  if (Array.isArray(value)) return ["array", value.map((item) => canonical(item, depth + 1))];
  if (!record(value)) return malformed();
  if (typeof value.toDate === "function") {
    if (!Number.isSafeInteger(value.seconds) || !Number.isSafeInteger(value.nanoseconds) ||
        Number(value.nanoseconds) < 0 || Number(value.nanoseconds) >= 1e9) return malformed();
    return ["timestamp", value.seconds, value.nanoseconds];
  }
  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) return malformed();
  // Tag every node, including ordinary objects/arrays, so a literal map cannot
  // impersonate typed timestamp evidence. Entry pairs preserve __proto__ keys.
  return ["object", Object.keys(value).sort().map((name) => [name, canonical(value[name], depth + 1)])];
}
export function submissionRecoveryEvidenceHash(value: unknown): string {
  const encoded = JSON.stringify(canonical(value));
  if (Buffer.byteLength(encoded, "utf8") > 1000000) return malformed();
  return createHash("sha256").update(encoded, "utf8").digest("hex");
}
const key = (parts: readonly unknown[]): string => submissionRecoveryEvidenceHash(parts);
export const submissionRecoveryFenceId = (domain: string, requestId: string): string => key([domain, requestId]);

function timestampMatches(value: unknown, expected: string): boolean {
  if (typeof value === "string") return value === expected;
  if (value instanceof Date) return Number.isFinite(value.valueOf()) && value.toISOString() === expected;
  if (record(value) && typeof value.toDate === "function" &&
      Number.isSafeInteger(value.seconds) && Number.isSafeInteger(value.nanoseconds)) {
    return Number(value.nanoseconds) >= 0 && Number(value.nanoseconds) < 1e9 &&
      Number(value.nanoseconds) % 1000000 === 0 &&
      Number(value.seconds) * 1000 + Number(value.nanoseconds) / 1000000 === Date.parse(expected);
  }
  return false;
}

/** Shape/identity evidence for administrative review, NOT payload replay authority. */
function receiptSummary(domain: Domain, requestId: string, originalActorUid: string | null, data: JsonMap): JsonMap {
  if (!text(data.actorUid, 128)) return malformed();
  if (originalActorUid != null && data.actorUid !== originalActorUid) {
    return fail("submission-recovery-original-actor-mismatch", "The receipt belongs to a different original account. Keep this saved work for investigation.");
  }
  let operation: string; let entityId: string; let version: number; let committedAt: string;
  let status: string | null = null;
  const fingerprint = domain === "qualityMonitoring" || domain === "publishedTemplateAssignment" ||
    domain === "inspectionCampaign" ? data.payloadFingerprint : data.fingerprint;
  if (!text(fingerprint, 128)) return malformed();
  if (domain === "inspectionCampaign") {
    if (data.receiptSchemaVersion !== 2 || data.commandId !== requestId ||
        data.commandType !== "createInspectionCampaign" || !/^sha256:[0-9a-f]{64}$/.test(fingerprint) ||
        canonicalWorkflowAuthorityScope(data.authorityScope)?.capability !== "inspectionCampaign.manage" || !text(data.aggregateId) ||
        data.resultKey !== "inspection-campaign-created" || !positive(data.aggregateVersion) ||
        !record(data.result) || data.result.campaignId !== data.aggregateId ||
        data.result.status !== "open" || !text(data.result.definitionCode) ||
        data.aggregateVersion !== 1 || !iso(data.appliedAt)) return malformed();
    operation = data.commandType; entityId = data.aggregateId; version = data.aggregateVersion; committedAt = data.appliedAt;
  } else if (domain === "publishedTemplateAssignment") {
    if (data.schemaVersion !== 1 || data.firestoreId !== requestId || !SHA.test(fingerprint) ||
        !text(data.packageId) || !text(data.versionId) || !positive(data.versionNumber) ||
        !text(data.contentHash) || !/^tg2-sha256:[0-9a-f]{64}$/.test(data.contentHash) ||
        !text(data.executionId) || !text(data.publicationAuditId) || data.status !== "completed" ||
        !Array.isArray(data.moduleIds) || data.moduleIds.length === 0 || data.moduleIds.some((id) => !text(id)) ||
        new Set(data.moduleIds).size !== data.moduleIds.length || !iso(data.assignedAt) ||
        !timestampMatches(data.createdAt, data.assignedAt)) return malformed();
    operation = "assignPublishedTemplateVersion"; entityId = data.executionId;
    version = data.versionNumber; committedAt = data.assignedAt; status = "completed";
  } else {
    if (data.requestId !== requestId) return malformed();
    if (domain === "morningReview") {
      const result = data.result;
      if (data.schemaVersion !== 1 || !/^morningreview[12]-sha256:[0-9a-f]{64}$/.test(fingerprint) ||
          !record(result) || result.requestId !== requestId || !text(result.operation) ||
          Object.keys(result).sort().join() !== ["requestId", "operation", "sessionId", "entityId", "status", "version", "committedAt"].sort().join() ||
          !Object.prototype.hasOwnProperty.call(MORNING_STATUSES, result.operation) ||
          !text(result.status, 80) || !MORNING_STATUSES[result.operation].includes(result.status) ||
          !text(result.sessionId) || !/^\d{4}-\d\d-\d\d$/.test(result.sessionId) ||
          !text(result.entityId) || !positive(result.version) || !iso(result.committedAt) ||
          !timestampMatches(data.committedAt, result.committedAt)) return malformed();
      operation = result.operation; entityId = result.entityId; version = result.version;
      committedAt = result.committedAt; status = String(result.status);
    } else {
      if (!iso(data.committedAtIso) || !timestampMatches(data.committedAt, data.committedAtIso)) return malformed();
      committedAt = data.committedAtIso;
      if (domain === "innerCoverAcceptance") {
        if (data.schemaVersion !== 1 || data.operation !== "ACCEPT_INNER_COVER" ||
            !/^innercover[123]-sha256:[0-9a-f]{64}$/.test(fingerprint) || !text(data.innerCoverId) ||
            !positive(data.version) || data.auditId !== `inner_cover_${requestId}` ||
            (data.secondaryVersion != null && !positive(data.secondaryVersion)) ||
            (fingerprint.startsWith("innercover3-") && (!text(data.auditEvidenceSha256) ||
              !SHA.test(data.auditEvidenceSha256) || !record(data.timestampInstants) ||
              Object.keys(data.timestampInstants).join() !== "inspectedOn" ||
              !wireInstant(data.timestampInstants.inspectedOn)))) return malformed();
        operation = data.operation; entityId = data.innerCoverId; version = data.version;
      } else if (domain === "qualityMonitoring") {
        if (data.schemaVersion !== 1 || data.operation !== "CREATE_QUALITY_MONITORING_REQUEST" ||
            !/^(qualityreq1|qualitycreate2)-sha256:[0-9a-f]{64}$/.test(fingerprint) ||
            !text(data.entityId) || data.resultVersion !== 1 || data.auditId !== `server_quality_${requestId}` ||
            (fingerprint.startsWith("qualitycreate2-") && (data.creationEvidenceVersion !== 2 ||
              !text(data.creationAuditSha256) || !SHA.test(data.creationAuditSha256)))) return malformed();
        operation = data.operation; entityId = data.entityId; version = data.resultVersion;
      } else {
        if (!text(data.assetClassId) || !text(data.assetInstanceId) || data.roundId !== requestId) return malformed();
        if (data.operation === "RECORD_BURNER_CONDITION_ROUND") {
          if (data.schemaVersion !== 1 || !/^burnerround[12]-sha256:[0-9a-f]{64}$/.test(fingerprint) ||
              !positive(data.assetInstanceVersion) || !positive(data.assetNumber) ||
              !displayText(data.assetClassCode) || !displayText(data.assetClassName) ||
              !displayText(data.assetName) || !displayText(data.recordedByName) ||
              !(data.directiveId == null || typeof data.directiveId === "string")) return malformed();
          version = data.assetInstanceVersion;
        } else if (data.operation === "COMPLETE_BURNER_RED_HOT_DIRECTIVE") {
          if (data.schemaVersion !== 2 || !/^burnercompliance1-sha256:[0-9a-f]{64}$/.test(fingerprint) ||
              !text(data.closedDirectiveId) || !positive(data.closedDirectiveVersion) ||
              !(data.newDirectiveId === null || text(data.newDirectiveId))) return malformed();
          version = data.closedDirectiveVersion;
        } else return malformed();
        operation = data.operation; entityId = data.assetInstanceId;
      }
    }
  }
  return {actorUid: data.actorUid, operation, entityId, version, committedAt, status};
}

type ReviewRequest = {
  schemaVersion: 1; phase: "inspect" | "finalize"; domain: Domain; requestId: string;
  evidenceSha256: string; originalActorUid: string | null; reason: string; reviewToken?: string;
};
function parseRequest(raw: unknown, endpoint: string): ReviewRequest {
  if (!record(raw)) return invalid();
  const keys = ["schemaVersion", "phase", "domain", "requestId", "evidenceSha256", "originalActorUid", "reason",
    ...(raw.phase === "finalize" ? ["reviewToken"] : [])];
  if (Object.keys(raw).sort().join() !== keys.sort().join() || raw.schemaVersion !== 1 ||
      (raw.phase !== "inspect" && raw.phase !== "finalize") || !text(raw.domain) ||
      !Object.prototype.hasOwnProperty.call(SUBMISSION_RECOVERY_DOMAINS, raw.domain) ||
      SUBMISSION_RECOVERY_DOMAINS[raw.domain as Domain].endpoint !== endpoint ||
      !text(raw.requestId, 160) || /[\/\x00-\x1f]/.test(raw.requestId) ||
      !text(raw.evidenceSha256) || !SHA.test(raw.evidenceSha256) ||
      !(raw.originalActorUid === null || text(raw.originalActorUid, 128)) ||
      !text(raw.reason, 2000) || raw.reason.length < 8 ||
      (raw.phase === "finalize" && (!text(raw.reviewToken) || !SHA.test(raw.reviewToken)))) return invalid();
  return raw as unknown as ReviewRequest;
}
function validateFence(data: JsonMap, domain: Domain, requestId: string): void {
  const proof = validatedProof(data, true);
  if (data.schemaVersion !== 1 || data.protocol !== SUBMISSION_RECOVERY_PROTOCOL ||
      data.domain !== domain || data.requestId !== requestId || data.outcome !== "cancelled" ||
      !text(data.decisionId) || !SHA.test(data.decisionId) || !iso(data.decidedAt) ||
      !text(data.reviewerUid, 128) || !text(data.evidenceSha256) || !SHA.test(data.evidenceSha256)) {
    fail("submission-recovery-fence-malformed", "The saved-request cancellation evidence needs investigation.");
  }
  if (proof.receiptSha256 !== null || proof.receiptSummary !== null) {
    fail("submission-recovery-fence-malformed", "Cancellation evidence cannot also assert acceptance.");
  }
}

function validatedProof(data: JsonMap, fence = false): JsonMap {
  const keys = ["schemaVersion", "domain", "requestId", "evidenceSha256", "originalActorUid", "reviewerUid", "reason",
    "outcome", "decisionId", "decidedAt", "receiptSha256", "receiptSummary"];
  const storedKeys = [...keys, "proofSha256", ...(fence ? ["protocol"] : [])];
  const proof = Object.fromEntries(keys.map((name) => [name, data[name]]));
  if (Object.keys(data).sort().join() !== storedKeys.sort().join() ||
      data.schemaVersion !== 1 || !text(data.domain) || !text(data.requestId, 160) ||
      !text(data.evidenceSha256) || !SHA.test(data.evidenceSha256) ||
      !(data.originalActorUid === null || text(data.originalActorUid, 128)) ||
      !text(data.reviewerUid, 128) || !text(data.reason, 2000) || data.reason.length < 8 ||
      data.decisionId !== key([data.domain, data.requestId, data.evidenceSha256]) || !iso(data.decidedAt) ||
      data.proofSha256 !== submissionRecoveryEvidenceHash(proof) ||
      (data.outcome !== "cancelled" && data.outcome !== "reviewedExisting") ||
      (data.outcome === "cancelled" && (data.receiptSha256 !== null || data.receiptSummary !== null)) ||
      (data.outcome === "reviewedExisting" && (!text(data.receiptSha256) || !SHA.test(data.receiptSha256) ||
        !record(data.receiptSummary) || !text(data.receiptSummary.actorUid, 128) ||
        !text(data.receiptSummary.operation) || !text(data.receiptSummary.entityId) ||
        !positive(data.receiptSummary.version) || !iso(data.receiptSummary.committedAt)))) {
    fail("submission-recovery-decision-malformed", "Saved review evidence is malformed. Preserve it for investigation.");
  }
  return proof;
}
function requireActivation(data: JsonMap | undefined, now: Date): void {
  const exact = (value: unknown, expected: readonly string[]): boolean => Array.isArray(value) &&
    value.length === expected.length && value.every((item) => typeof item === "string") &&
    [...value].sort().join() === [...expected].sort().join();
  if (data?.schemaVersion !== 1 || data.protocol !== SUBMISSION_RECOVERY_PROTOCOL || data.enabled !== true ||
      !exact(data.domains, Object.keys(SUBMISSION_RECOVERY_DOMAINS)) ||
      !exact(data.guardedCallableNames, GUARDED_CALLABLES) || data.legacyWorkersDrained !== true ||
      data.rollbackRetainsFences !== true || !text(data.sourceCommit) || !/^[0-9a-f]{40}$/.test(data.sourceCommit) ||
      !text(data.evidenceSha256) || !SHA.test(data.evidenceSha256) || !iso(data.verifiedAt) ||
      Date.parse(data.verifiedAt) > now.valueOf()) {
    fail("submission-recovery-finalization-not-activated",
      "Cancellation is unavailable until the guarded backend fleet and compatible rollback have been independently verified.");
  }
}

/** Receipt absence is NOT proof of non-acceptance: historical receipts may expire. */
export async function reviewSavedSubmissionWithDb(args: {
  db: SubmissionRecoveryDb; endpoint: string; authUid: string | null; data: unknown; now?: () => Date;
}): Promise<JsonMap> {
  if (!text(args.authUid, 128)) throw new HttpsError("unauthenticated", "Sign in is required.");
  const reviewerUid = args.authUid;
  const request = parseRequest(args.data, args.endpoint);
  const {domain, requestId, evidenceSha256, originalActorUid, reason} = request;
  const decisionId = key([domain, requestId, evidenceSha256]);
  const binding = {schemaVersion: 1, domain, requestId, evidenceSha256, originalActorUid, reviewerUid, reason};
  return args.db.runTransaction(async (tx) => {
    const user = await tx.get(args.db.collection("users").doc(reviewerUid));
    const authority = user.exists ? canonicalApprovedUserAuthority(user.data()) : null;
    if (authority == null || !authority.roles.has("admin")) {
      throw new HttpsError("permission-denied", "An approved Admin must review saved submissions.");
    }
    const decisionRef = args.db.collection(SUBMISSION_RECOVERY_COLLECTIONS.decisions).doc(decisionId);
    const fenceRef = args.db.collection(SUBMISSION_RECOVERY_COLLECTIONS.fences).doc(submissionRecoveryFenceId(domain, requestId));
    const previous = await tx.get(decisionRef);
    const fence = await tx.get(fenceRef);
    if (fence.exists) validateFence(fence.data() ?? {}, domain, requestId);
    const receipt = await tx.get(args.db.collection(SUBMISSION_RECOVERY_DOMAINS[domain].receipts).doc(requestId));
    const summary = receipt.exists ? receiptSummary(domain, requestId, originalActorUid, receipt.data() ?? {}) : null;
    const receiptSha256 = receipt.exists ? submissionRecoveryEvidenceHash(receipt.data()) : null;
    if (fence.exists && receipt.exists) {
      fail("submission-recovery-receipt-fence-conflict", "Both cancellation and acceptance evidence exist. Keep the saved work for investigation.");
    }
    if (previous.exists) {
      const proof = validatedProof(previous.data() ?? {});
      // Inspection can recover a lost final response without requiring the
      // operator to remember the original reason. The stored reason is returned
      // unchanged; a new finalization still requires its exact original binding.
      const same = Object.entries(binding).every(([name, value]) =>
        (request.phase === "inspect" && name === "reason") || proof[name] === value);
      if (!same || proof.decisionId !== decisionId || !iso(proof.decidedAt) ||
          (proof.outcome !== "cancelled" && proof.outcome !== "reviewedExisting") ||
          (proof.outcome === "cancelled" && (!fence.exists || proof.receiptSha256 !== null)) ||
          (proof.outcome === "reviewedExisting" && (!text(proof.receiptSha256) ||
            !SHA.test(proof.receiptSha256) || !record(proof.receiptSummary) ||
            (receipt.exists && proof.receiptSha256 !== receiptSha256)))) {
        fail("submission-recovery-decision-conflict", "The existing review decision does not match this saved evidence or reviewer. Preserve it for investigation.");
      }
      return proof;
    }
    const reviewToken = key([binding, receiptSha256, fence.exists ? fence.data() : null]);
    if (request.phase === "inspect") return {
      schemaVersion: 1, domain, requestId, evidenceSha256, originalActorUid, reviewerUid, reviewToken,
      observation: receipt.exists ? "receiptPresent" : "receiptAbsent", receiptSha256, receiptSummary: summary};
    if (request.reviewToken !== reviewToken) {
      fail("submission-recovery-observation-changed", "Acceptance evidence changed after review. Inspect the saved request again before deciding.");
    }
    const now = args.now?.() ?? new Date();
    if (!Number.isFinite(now.valueOf())) return invalid();
    if (!receipt.exists) {
      const activation = await tx.get(args.db.collection(SUBMISSION_RECOVERY_COLLECTIONS.controls).doc("activation"));
      requireActivation(activation.exists ? activation.data() : undefined, now);
    }
    const proof = {...binding, outcome: receipt.exists ? "reviewedExisting" : "cancelled",
      decisionId, decidedAt: now.toISOString(), receiptSha256, receiptSummary: summary};
    const storedProof = {...proof, proofSha256: submissionRecoveryEvidenceHash(proof)};
    if (!receipt.exists && !fence.exists) tx.create(fenceRef, {...storedProof, protocol: SUBMISSION_RECOVERY_PROTOCOL});
    tx.create(decisionRef, storedProof);
    return proof;
  });
}

function originalIdentity(endpoint: string, data: unknown): {domain: Domain; requestId: string} | null {
  if (!record(data)) return null;
  let domain: Domain | null = null;
  if (endpoint === "assignPublishedTemplateVersion") domain = "publishedTemplateAssignment";
  // A cancellation reserves the ID throughout its existing receipt namespace.
  // Changing operation must not create acceptance beside the permanent fence.
  // Review admission remains limited to the six supported recovery domains.
  else if (endpoint === "executeMaintenanceWorkflowCommand") domain = "inspectionCampaign";
  else if (endpoint === "mutateChargeAbnormality" && isQualityMutationOperation(data.operation)) domain = "qualityMonitoring";
  else if (endpoint === "mutateAssetHierarchy") {
    if (typeof data.operation === "string" && Object.prototype.hasOwnProperty.call(MORNING_STATUSES, data.operation)) domain = "morningReview";
    else if (data.operation === "RECORD_BURNER_CONDITION_ROUND" || data.operation === "COMPLETE_BURNER_RED_HOT_DIRECTIVE") domain = "burnerEvidence";
    else if (isInnerCoverLifecycleOperation(data.operation)) domain = "innerCoverAcceptance";
  }
  const rawId = domain === "inspectionCampaign" ? data.commandId : data.requestId;
  if (domain == null || typeof rawId !== "string") return null;
  // Match existing V1 parsers' trimming exactly; never inject an origin/payload.
  const requestId = rawId.trim();
  if (!text(requestId, 160) || /[\/\x00-\x1f]/.test(requestId)) return null;
  return {domain, requestId};
}

/**
 * Every original business transaction reads the global fence in that same
 * transaction. A finalizer creating it therefore conflicts with an in-flight
 * original; Firestore retries the loser against the committed winner.
 * This wrapper preserves the concrete Firestore object API and transaction
 * options, and is installed at V1 so both installed V1 and V2 callers use it.
 */
export function withSubmissionRecoveryFence<T extends object>(db: T, endpoint: string, data: unknown): T {
  const identity = originalIdentity(endpoint, data);
  if (identity == null) return db;
  const recoveryDb = db as unknown as SubmissionRecoveryDb;
  return new Proxy(db, {
    get(target, property) {
      if (property === "runTransaction") return (body: (tx: Transaction) => Promise<unknown>, ...options: unknown[]) => {
        const run = Reflect.get(target, property) as (...values: unknown[]) => Promise<unknown>;
        return run.call(target, async (tx: Transaction) => {
          const fence = await tx.get(recoveryDb.collection(SUBMISSION_RECOVERY_COLLECTIONS.fences)
            .doc(submissionRecoveryFenceId(identity.domain, identity.requestId)));
          if (fence.exists) {
            validateFence(fence.data() ?? {}, identity.domain, identity.requestId);
            fail("saved-submission-cancelled", "This original request was cancelled after administrative review. Review the saved work before proceeding.");
          }
          return body(tx);
        }, ...options);
      };
      const value = Reflect.get(target, property, target);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
}
